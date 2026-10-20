import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: CANDIDATE_MODELS ===
//    - ZoneMergeCandidate
// 2. === SECTION: OCCUPANCY_GRID_ROOM_DETECTOR ===
//    - ArchitectRoomDetector:
//      * detectRoomPolygon (1-click room boundary extraction)
//      * detectMergedZones (wall removal merge candidate detection)
//      * traceBoundaryLoop (connected component perimeter tracing)
//      * douglasPeucker (contour simplification)
//      * snapContourToWalls (CAD-level inner wall face projection)
// =============================================================================

// === SECTION: CANDIDATE_MODELS ===

/// Candidate pair of zones that now occupy the same enclosed room
/// following the removal or displacement of a partition wall.
class ZoneMergeCandidate {
  final ArchitectZone zoneA;
  final ArchitectZone zoneB;
  final List<Offset> mergedPolygon;

  const ZoneMergeCandidate({
    required this.zoneA,
    required this.zoneB,
    required this.mergedPolygon,
  });
}

// === SECTION: OCCUPANCY_GRID_ROOM_DETECTOR ===

/// High-performance geometric room boundary detector.
/// Uses 2D spatial discretization (occupancy grid flood-fill), boundary tracing,
/// Douglas-Peucker simplification, and CAD-exact wall face projection.
class ArchitectRoomDetector {
  /// Restores the full room boundary, including legacy zones without a seed.
  /// Never changes the mode if the room leaks to the exterior.
  static ArchitectZone? automaticZone(
    ArchitectZone zone,
    List<ArchitectWall> walls,
  ) {
    final seed = zone.interiorPoint;
    if (seed == null) return null;
    final polygon = detectRoomPolygon(seedPoint: seed, walls: walls);
    if (polygon == null) return null;
    return zone.copyWith(
      polygon: polygon,
      seedPoint: seed,
      isAutoBoundary: true,
    );
  }

  /// Detects the enclosed room polygon around [seedPoint] bounded by [walls].
  /// Returns null if the space is unbounded (open to exterior) or too small.
  static List<Offset>? detectRoomPolygon({
    required Offset seedPoint,
    required List<ArchitectWall> walls,
    double targetCellSize = 0.05, // 5 cm grid resolution
  }) {
    if (walls.length < 3) return null;

    // 1. Calculate bounding box of all walls
    double minX = walls.first.polygonCorners.first.dx;
    double maxX = minX;
    double minY = walls.first.polygonCorners.first.dy;
    double maxY = minY;

    for (final wall in walls) {
      for (final p in wall.polygonCorners) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    // Expand bounding box by 1.5 m padding
    const padding = 1.5;
    minX -= padding;
    maxX += padding;
    minY -= padding;
    maxY += padding;

    final spanX = maxX - minX;
    final spanY = maxY - minY;
    if (spanX <= 0.5 || spanY <= 0.5) return null;

    // Dynamically adjust cell size to prevent oversized grids
    double cellSize = targetCellSize;
    int gridW = (spanX / cellSize).ceil() + 1;
    int gridH = (spanY / cellSize).ceil() + 1;
    const maxDimension = 1200;
    if (gridW > maxDimension || gridH > maxDimension) {
      cellSize = math.max(spanX, spanY) / maxDimension;
      gridW = (spanX / cellSize).ceil() + 1;
      gridH = (spanY / cellSize).ceil() + 1;
    }

    final totalCells = gridW * gridH;
    final grid = Uint8List(totalCells);

    // 2. Rasterize wall polygons into the occupancy grid
    for (final wall in walls) {
      final corners = wall.polygonCorners;
      if (corners.length < 3) continue;

      double wMinX = corners.first.dx;
      double wMaxX = wMinX;
      double wMinY = corners.first.dy;
      double wMaxY = wMinY;
      for (final p in corners) {
        if (p.dx < wMinX) wMinX = p.dx;
        if (p.dx > wMaxX) wMaxX = p.dx;
        if (p.dy < wMinY) wMinY = p.dy;
        if (p.dy > wMaxY) wMaxY = p.dy;
      }

      final startGx = math.max(0, ((wMinX - minX) / cellSize).floor());
      final endGx = math.min(gridW - 1, ((wMaxX - minX) / cellSize).ceil());
      final startGy = math.max(0, ((wMinY - minY) / cellSize).floor());
      final endGy = math.min(gridH - 1, ((wMaxY - minY) / cellSize).ceil());

      for (int gy = startGy; gy <= endGy; gy++) {
        final cy = minY + (gy + 0.5) * cellSize;
        final rowOffset = gy * gridW;
        for (int gx = startGx; gx <= endGx; gx++) {
          final cx = minX + (gx + 0.5) * cellSize;
          if (_pointInPolygon(Offset(cx, cy), corners)) {
            grid[rowOffset + gx] = 1; // Mark occupied / wall
          }
        }
      }
    }

    // 3. Resolve seed cell
    int seedGx = ((seedPoint.dx - minX) / cellSize).floor();
    int seedGy = ((seedPoint.dy - minY) / cellSize).floor();

    if (seedGx < 0 || seedGx >= gridW || seedGy < 0 || seedGy >= gridH) {
      return null;
    }

    // If seed point is directly on/inside a wall, search nearest free neighbor
    if (grid[seedGy * gridW + seedGx] != 0) {
      int? foundGx, foundGy;
      double bestDistSq = double.infinity;
      const searchRadius = 6; // up to 30 cm search
      for (int dy = -searchRadius; dy <= searchRadius; dy++) {
        final ny = seedGy + dy;
        if (ny < 0 || ny >= gridH) continue;
        for (int dx = -searchRadius; dx <= searchRadius; dx++) {
          final nx = seedGx + dx;
          if (nx < 0 || nx >= gridW) continue;
          if (grid[ny * gridW + nx] == 0) {
            final distSq = (dx * dx + dy * dy).toDouble();
            if (distSq < bestDistSq) {
              bestDistSq = distSq;
              foundGx = nx;
              foundGy = ny;
            }
          }
        }
      }
      if (foundGx == null || foundGy == null) return null;
      seedGx = foundGx;
      seedGy = foundGy;
    }

    // 4. BFS Flood Fill from Seed Cell
    final visited = Uint8List(totalCells);
    final queue = Int32List(totalCells);
    int head = 0;
    int tail = 0;

    final seedIdx = seedGy * gridW + seedGx;
    visited[seedIdx] = 1;
    queue[tail++] = seedIdx;

    bool touchesOuterBoundary = false;
    int roomCellCount = 0;

    while (head < tail) {
      final cur = queue[head++];
      roomCellCount++;
      final cy = cur ~/ gridW;
      final cx = cur % gridW;

      // Leak check: touching grid perimeter means room is open to exterior
      if (cx <= 1 || cx >= gridW - 2 || cy <= 1 || cy >= gridH - 2) {
        touchesOuterBoundary = true;
        break;
      }

      // 4-connected flood fill
      // Right
      int nIdx = cur + 1;
      if (grid[nIdx] == 0 && visited[nIdx] == 0) {
        visited[nIdx] = 1;
        queue[tail++] = nIdx;
      }
      // Left
      nIdx = cur - 1;
      if (grid[nIdx] == 0 && visited[nIdx] == 0) {
        visited[nIdx] = 1;
        queue[tail++] = nIdx;
      }
      // Down
      nIdx = cur + gridW;
      if (grid[nIdx] == 0 && visited[nIdx] == 0) {
        visited[nIdx] = 1;
        queue[tail++] = nIdx;
      }
      // Up
      nIdx = cur - gridW;
      if (grid[nIdx] == 0 && visited[nIdx] == 0) {
        visited[nIdx] = 1;
        queue[tail++] = nIdx;
      }
    }

    if (touchesOuterBoundary) return null;
    final estimatedArea = roomCellCount * cellSize * cellSize;
    if (estimatedArea < 0.40) return null; // Minimum sensible room area

    // 5. Extract Outer Boundary Contour
    final rawContour = _extractBoundaryLoop(
      visited: visited,
      gridW: gridW,
      gridH: gridH,
      minX: minX,
      minY: minY,
      cellSize: cellSize,
    );
    if (rawContour == null || rawContour.length < 3) return null;

    // 6. Simplify Contour via Douglas-Peucker
    final simplified = _douglasPeucker(rawContour, cellSize * 1.4);
    if (simplified.length < 3) return null;

    // 7. Snap Simplified Segments to Actual Wall Inner Faces
    final snapped = _snapContourToWalls(simplified, walls);
    if (snapped.length >= 3 && _polygonArea(snapped) >= 0.40) {
      return snapped;
    }

    return simplified;
  }

  /// Checks if removing a wall caused two auto-boundary zones to merge into one space.
  static ZoneMergeCandidate? detectMergedZones({
    required List<ArchitectZone> existingZones,
    required List<ArchitectWall> remainingWalls,
  }) {
    final autoZones = existingZones.where((z) => z.isAutoBoundary).toList();
    if (autoZones.length < 2) return null;

    for (int i = 0; i < autoZones.length; i++) {
      final zA = autoZones[i];
      final seedA = zA.seedPoint ?? zA.centroid;
      final roomPoly = detectRoomPolygon(
        seedPoint: seedA,
        walls: remainingWalls,
      );
      if (roomPoly == null || roomPoly.length < 3) continue;

      for (int j = i + 1; j < autoZones.length; j++) {
        final zB = autoZones[j];
        final seedB = zB.seedPoint ?? zB.centroid;
        if (_pointInPolygon(seedB, roomPoly)) {
          // Zone A and Zone B now reside within the exact same enclosed room!
          return ZoneMergeCandidate(
            zoneA: zA,
            zoneB: zB,
            mergedPolygon: roomPoly,
          );
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // GEOMETRIC HELPERS
  // ---------------------------------------------------------------------------

  /// Traces the directed boundary edges of the connected components and returns
  /// the closed perimeter loop with the largest enclosed area.
  static List<Offset>? _extractBoundaryLoop({
    required Uint8List visited,
    required int gridW,
    required int gridH,
    required double minX,
    required double minY,
    required double cellSize,
  }) {
    // Map directed edges from Start Node (gx, gy) -> End Node (gx, gy)
    final edges = <int, int>{};
    int nodeKey(int x, int y) => y * (gridW + 1) + x;

    for (int y = 0; y < gridH; y++) {
      final rOffset = y * gridW;
      for (int x = 0; x < gridW; x++) {
        if (visited[rOffset + x] != 1) continue;

        // Top edge
        if (y == 0 || visited[(y - 1) * gridW + x] != 1) {
          edges[nodeKey(x, y)] = nodeKey(x + 1, y);
        }
        // Right edge
        if (x == gridW - 1 || visited[rOffset + x + 1] != 1) {
          edges[nodeKey(x + 1, y)] = nodeKey(x + 1, y + 1);
        }
        // Bottom edge
        if (y == gridH - 1 || visited[(y + 1) * gridW + x] != 1) {
          edges[nodeKey(x + 1, y + 1)] = nodeKey(x, y + 1);
        }
        // Left edge
        if (x == 0 || visited[rOffset + x - 1] != 1) {
          edges[nodeKey(x, y + 1)] = nodeKey(x, y);
        }
      }
    }

    if (edges.isEmpty) return null;

    // Follow cycles and pick the one with largest area
    final visitedStart = <int>{};
    List<Offset>? bestLoop;
    double bestArea = 0.0;

    for (final startKey in edges.keys) {
      if (visitedStart.contains(startKey)) continue;

      final currentLoop = <Offset>[];
      int cur = startKey;
      bool closed = false;

      while (true) {
        visitedStart.add(cur);
        final gx = cur % (gridW + 1);
        final gy = cur ~/ (gridW + 1);
        currentLoop.add(Offset(minX + gx * cellSize, minY + gy * cellSize));

        final next = edges[cur];
        if (next == null) break;
        if (next == startKey) {
          closed = true;
          break;
        }
        if (visitedStart.contains(next) || currentLoop.length > edges.length) {
          break;
        }
        cur = next;
      }

      if (closed && currentLoop.length >= 3) {
        final a = _polygonArea(currentLoop);
        if (a > bestArea) {
          bestArea = a;
          bestLoop = currentLoop;
        }
      }
    }

    return bestLoop;
  }

  /// Classic Douglas-Peucker polyline simplification.
  static List<Offset> _douglasPeucker(List<Offset> points, double epsilon) {
    if (points.length <= 3) return points;

    // Remove collinear sequential points
    final cleaned = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final cur = points[i];
      final next = points[(i + 1) % points.length];
      final v1 = cur - prev;
      final v2 = next - cur;
      final cross = (v1.dx * v2.dy - v1.dy * v2.dx).abs();
      if (cross > 1e-4) {
        cleaned.add(cur);
      }
    }
    if (cleaned.length <= 3) return cleaned;

    List<Offset> simplifySection(int startIdx, int endIdx) {
      double maxDist = 0.0;
      int index = -1;
      final p1 = cleaned[startIdx];
      final p2 = cleaned[endIdx];

      for (int i = startIdx + 1; i < endIdx; i++) {
        final d = _perpendicularDistance(cleaned[i], p1, p2);
        if (d > maxDist) {
          maxDist = d;
          index = i;
        }
      }

      if (maxDist > epsilon && index != -1) {
        final rec1 = simplifySection(startIdx, index);
        final rec2 = simplifySection(index, endIdx);
        return [...rec1.take(rec1.length - 1), ...rec2];
      } else {
        return [p1, p2];
      }
    }

    final n = cleaned.length;
    // Find point farthest from point 0 to split polygon in two halves
    double maxD = 0.0;
    int splitIdx = n ~/ 2;
    for (int i = 1; i < n; i++) {
      final d = (cleaned[i] - cleaned[0]).distance;
      if (d > maxD) {
        maxD = d;
        splitIdx = i;
      }
    }

    final half1 = simplifySection(0, splitIdx);
    final half2 = simplifySection(splitIdx, n - 1);
    final result = [...half1.take(half1.length - 1), ...half2];

    return result.length >= 3 ? result : cleaned;
  }

  /// Snaps polygon edges to the nearest parallel inner faces of surrounding walls.
  static List<Offset> _snapContourToWalls(
    List<Offset> polygon,
    List<ArchitectWall> walls, {
    double snapDistance = 0.20,
  }) {
    if (polygon.length < 3) return polygon;

    // Collect all wall boundary line segments
    final wallSegments = <(Offset, Offset)>[];
    for (final wall in walls) {
      final c = wall.polygonCorners;
      for (int i = 0; i < c.length; i++) {
        wallSegments.add((c[i], c[(i + 1) % c.length]));
      }
    }

    final n = polygon.length;
    final snappedLines = <(Offset, Offset)>[];

    for (int i = 0; i < n; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % n];
      final d = p2 - p1;
      final len = d.distance;
      if (len < 1e-4) {
        snappedLines.add((p1, p2));
        continue;
      }
      final u = d / len;

      (Offset, Offset)? bestWallSeg;
      double minPerpDist = snapDistance;

      for (final ws in wallSegments) {
        final wd = ws.$2 - ws.$1;
        final wLen = wd.distance;
        if (wLen < 1e-4) continue;
        final wu = wd / wLen;

        // Check if nearly parallel (dot product close to 1 or -1)
        final dot = (u.dx * wu.dx + u.dy * wu.dy).abs();
        if (dot >= 0.95) {
          final mid = (p1 + p2) * 0.5;
          final perpDist = _perpendicularDistance(mid, ws.$1, ws.$2);
          if (perpDist < minPerpDist) {
            minPerpDist = perpDist;
            bestWallSeg = ws;
          }
        }
      }

      if (bestWallSeg != null) {
        // Project edge onto this wall segment's infinite line
        final proj1 = _projectPointOnLine(p1, bestWallSeg.$1, bestWallSeg.$2);
        final proj2 = _projectPointOnLine(p2, bestWallSeg.$1, bestWallSeg.$2);
        snappedLines.add((proj1, proj2));
      } else {
        snappedLines.add((p1, p2));
      }
    }

    // Intersect consecutive snapped lines to form clean corners
    final result = <Offset>[];
    for (int i = 0; i < n; i++) {
      final lineA = snappedLines[(i - 1 + n) % n];
      final lineB = snappedLines[i];
      final corner = _lineIntersection(lineA.$1, lineA.$2, lineB.$1, lineB.$2);
      if (corner != null &&
          (corner - polygon[i]).distance < snapDistance * 1.5) {
        result.add(corner);
      } else {
        result.add(polygon[i]);
      }
    }

    return result;
  }

  static double _perpendicularDistance(Offset pt, Offset lineA, Offset lineB) {
    final d = lineB - lineA;
    final len = d.distance;
    if (len < 1e-6) return (pt - lineA).distance;
    return ((d.dx * (lineA.dy - pt.dy) - d.dy * (lineA.dx - pt.dx)).abs()) /
        len;
  }

  static Offset _projectPointOnLine(Offset pt, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-9) return a;
    final t = ((pt.dx - a.dx) * ab.dx + (pt.dy - a.dy) * ab.dy) / lenSq;
    return Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
  }

  static Offset? _lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denom = d1.dx * d2.dy - d1.dy * d2.dx;
    if (denom.abs() < 1e-6) return null;
    final d3 = p1 - p3;
    final t = (d2.dx * d3.dy - d2.dy * d3.dx) / denom;
    return Offset(p1.dx + t * d1.dx, p1.dy + t * d1.dy);
  }

  static double _polygonArea(List<Offset> poly) {
    if (poly.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return sum.abs() / 2.0;
  }

  static bool _pointInPolygon(Offset pt, List<Offset> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final pi = poly[i];
      final pj = poly[j];
      final intersect =
          ((pi.dy > pt.dy) != (pj.dy > pt.dy)) &&
          (pt.dx < (pj.dx - pi.dx) * (pt.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
