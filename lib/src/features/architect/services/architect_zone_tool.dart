import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_zone_snap.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ORTHO_GUIDES_AND_STATUS_ENUMS ===
//    - ArchitectOrthoType
//    - ArchitectOrthoSnapResult
//    - ZoneDraftingPointStatus
//    - ArchitectZoneDraftMode (polyline, rectangle)
//
// 2. === SECTION: GEOMETRY_AND_MATH_ENGINE ===
//    - ArchitectZoneGeometry:
//      * linesIntersect, segmentIntersectsChain, calculateArea, calculateCentroid
//      * cleanPolygon (orphan/collinear point removal)
//      * rotatePolygon, translatePolygon, offsetPolygon, rayIntersection
//      * alignPolygonToNearest2D (GPS_Mapping 90°/5° squarify algorithm)
//      * extrudeEdge (edge midpoint step/niche extrusion)
//      * calculateOrthoSnap
//
// 3. === SECTION: ZONE_TOOL_CONTROLLER ===
//    - ArchitectZoneTool (ChangeNotifier):
//      * Drafting State & Methods (zero-lag point-by-point, quick rectangle)
//      * Edge Extrusion State & Methods
//      * GPS_Mapping-style Zone Edit & Transform Mode:
//        - autoAlignZone (90° squarify) & undoAutoAlignZone
//        - rotation slider & ±15°/±90° steps
//        - move whole zone mode
//        - offset boundary expand/shrink
//        - full undo/redo stack
// =============================================================================

// === SECTION: ORTHO_GUIDES_AND_STATUS_ENUMS ===

/// Orthogonal guide orientation for vector-style alignment.
enum ArchitectOrthoType {
  none,
  horizontal,
  vertical,
  diagonal45,
}

/// Result of orthogonal straightening snap relative to an anchor vertex.
class ArchitectOrthoSnapResult {
  final Offset point;
  final bool isSnapped;
  final ArchitectOrthoType type;
  final (Offset, Offset)? guideLine;
  final double angleDeg;

  const ArchitectOrthoSnapResult({
    required this.point,
    required this.isSnapped,
    required this.type,
    this.guideLine,
    this.angleDeg = 0.0,
  });
}

/// Status of candidate point during point-by-point drawing.
enum ZoneDraftingPointStatus {
  valid,
  closeTarget,
  selfIntersects,
  tooClose,
}

/// Mode of zone creation: freeform point-by-point or 2-click rectangle.
enum ArchitectZoneDraftMode {
  polyline,
  rectangle,
}

// === SECTION: GEOMETRY_AND_MATH_ENGINE ===

/// Mathematical & geometric operations for architectural functional zones:
/// orphan vertex reduction, self-intersection avoidance, edge extrusion,
/// and vector-style orthogonal straightening guides.
class ArchitectZoneGeometry {
  /// Robust segment-segment intersection test with tolerance.
  static bool linesIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double ccw(Offset a, Offset b, Offset c) =>
        (c.dy - a.dy) * (b.dx - a.dx) - (b.dy - a.dy) * (c.dx - a.dx);

    final d1 = ccw(p3, p4, p1);
    final d2 = ccw(p3, p4, p2);
    final d3 = ccw(p1, p2, p3);
    final d4 = ccw(p1, p2, p4);

    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// Checks if polygon has any self-intersecting boundary edges.
  static bool hasSelfIntersections(List<Offset> polygon) {
    final n = polygon.length;
    if (n < 4) return false;

    for (int i = 0; i < n; i++) {
      final a1 = polygon[i];
      final a2 = polygon[(i + 1) % n];
      for (int j = i + 2; j < n; j++) {
        if (i == 0 && j == n - 1) continue;
        final b1 = polygon[j];
        final b2 = polygon[(j + 1) % n];
        if (linesIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// Tests if candidate segment [from, to] intersects any edge of an open chain [chain].
  static bool segmentIntersectsChain(
    Offset from,
    Offset to,
    List<Offset> chain, {
    bool isClosing = false,
  }) {
    if (chain.length < 2) return false;
    final segLen = (to - from).distance;
    if (segLen < 1e-4) return false;

    final limit = isClosing ? chain.length : chain.length - 1;
    for (int i = 0; i < limit; i++) {
      final p1 = chain[i];
      final p2 = chain[(i + 1) % chain.length];

      // Exclude shared endpoints
      if ((p1 - from).distance < 1e-3 ||
          (p2 - from).distance < 1e-3 ||
          (p1 - to).distance < 1e-3 ||
          (p2 - to).distance < 1e-3) {
        continue;
      }

      if (linesIntersect(from, to, p1, p2)) {
        return true;
      }
    }
    return false;
  }

  /// Cleans polygon by removing:
  /// 1. Duplicate vertices closer than [minDistance] (default 5 cm).
  /// 2. Collinear / orphan vertices sitting along straight lines.
  /// 3. Acute needle fold-backs / spikes.
  /// 4. Non-adjacent pinch loops.
  static List<Offset> cleanPolygon(
    List<Offset> polygon, {
    double minDistance = 0.05,
    double minCollinearDistance = 0.02,
  }) {
    final nonNanPts = polygon
        .where((p) => p.dx.isFinite && p.dy.isFinite)
        .toList();

    if (nonNanPts.length < 3) return nonNanPts;

    final validPts = List<Offset>.from(nonNanPts);
    bool changed = true;
    int maxPasses = 15;

    while (changed && validPts.length > 3 && maxPasses-- > 0) {
      changed = false;

      // 1. Collapse adjacent duplicate points (< minDistance)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final next = (i + 1) % validPts.length;
        if ((validPts[i] - validPts[next]).distance < minDistance) {
          validPts.removeAt(next);
          changed = true;
          break;
        }
      }
      if (changed) continue;

      // 2. Remove collinear points (orphan points sitting on straight edges)
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        final prev = (i - 1 + validPts.length) % validPts.length;
        final next = (i + 1) % validPts.length;
        final v1 = validPts[i] - validPts[prev];
        final v2 = validPts[next] - validPts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;

        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);

          final chord = validPts[next] - validPts[prev];
          final chordLen = chord.distance;
          final double distToChord;
          if (chordLen > 1e-4) {
            final t = (((validPts[i].dx - validPts[prev].dx) * chord.dx +
                        (validPts[i].dy - validPts[prev].dy) * chord.dy) /
                    (chordLen * chordLen))
                .clamp(0.0, 1.0);
            final proj = validPts[prev] + chord * t;
            distToChord = (validPts[i] - proj).distance;
          } else {
            distToChord = (validPts[i] - validPts[prev]).distance;
          }

          // Collinear redundant vertex
          if ((cross.abs() < 0.04 && dot > 0.96) ||
              (distToChord < minCollinearDistance && dot > 0.5)) {
            validPts.removeAt(i);
            changed = true;
            break;
          }

          // Acute needle fold-back / spike
          if (cross.abs() < 0.08 && dot < -0.85) {
            validPts.removeAt(i);
            changed = true;
            break;
          }

          // Slit where chord is almost closed
          if (chordLen < minDistance * 1.5 && dot < -0.5) {
            validPts.removeAt(i);
            changed = true;
            break;
          }
        }
      }
      if (changed) continue;

      // 3. Non-adjacent pinch duplicate collapse
      for (int i = 0; i < validPts.length && validPts.length > 3; i++) {
        for (int j = i + 2; j < validPts.length; j++) {
          if (i == 0 && j == validPts.length - 1) continue;
          if ((validPts[i] - validPts[j]).distance < minDistance) {
            final loop1Len = j - i;
            final loop2Len = validPts.length - loop1Len;
            if (loop1Len <= loop2Len) {
              validPts.removeRange(i + 1, j + 1);
            } else {
              validPts.removeRange(j + 1, validPts.length);
              validPts.removeRange(0, i);
            }
            changed = true;
            break;
          }
        }
        if (changed) break;
      }
    }

    return validPts;
  }

  /// Calculates net area using Shoelace formula.
  static double calculateArea(List<Offset> polygon) {
    if (polygon.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return sum.abs() / 2.0;
  }

  /// Calculates outward normal unit vector for edge [edgeIndex] of [polygon].
  static Offset calculateOutwardNormal(List<Offset> polygon, int edgeIndex) {
    final n = polygon.length;
    if (n < 3 || edgeIndex < 0 || edgeIndex >= n) return const Offset(0, 1);

    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final edge = v2 - v1;
    final len = edge.distance;
    if (len < 1e-6) return const Offset(0, 1);

    final u = edge / len;

    // Determine CCW orientation via signed Shoelace area
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
      final pA = polygon[i];
      final pB = polygon[(i + 1) % n];
      sum += (pA.dx * pB.dy - pB.dx * pA.dy);
    }
    final isCCW = sum > 0;
    return isCCW ? Offset(u.dy, -u.dx) : Offset(-u.dy, u.dx);
  }

  /// Extrudes the segment from [edgeIndex] to [edgeIndex + 1] outward/inward by [distance].
  /// Preserves the original vertices v1 and v2, and inserts two new vertices [vNew1, vNew2]
  /// forming an architectural step / niche.
  /// Strictly prevents self-intersections and micro-distance degenerate vertices.
  static List<Offset>? extrudeEdge({
    required List<Offset> polygon,
    required int edgeIndex,
    required double distance,
    double minDistance = 0.05,
  }) {
    final n = polygon.length;
    if (n < 3 || edgeIndex < 0 || edgeIndex >= n) return null;
    if (distance.abs() < 1e-3) return polygon;

    final v1 = polygon[edgeIndex];
    final v2 = polygon[(edgeIndex + 1) % n];
    final normal = calculateOutwardNormal(polygon, edgeIndex);

    final vNew1 = v1 + normal * distance;
    final vNew2 = v2 + normal * distance;

    if ((vNew1 - v1).distance < minDistance ||
        (vNew2 - v2).distance < minDistance) {
      return polygon;
    }

    final newPts = List<Offset>.from(polygon);
    newPts.insertAll(edgeIndex + 1, [vNew1, vNew2]);

    if (hasSelfIntersections(newPts)) {
      return null;
    }

    if (calculateArea(newPts) < 1e-4) {
      return null;
    }

    return newPts;
  }

  /// Calculates vector-style orthogonal straightening guide line relative to [anchor].
  /// Snaps to exact horizontal (0°/180°) or vertical (90°/270°) if within [snapAngleToleranceDeg].
  static ArchitectOrthoSnapResult calculateOrthoSnap({
    required Offset anchor,
    required Offset raw,
    double snapAngleToleranceDeg = 6.0,
    double guideLineLength = 25.0,
  }) {
    final delta = raw - anchor;
    final dist = delta.distance;
    if (dist < 1e-3) {
      return ArchitectOrthoSnapResult(
        point: raw,
        isSnapped: false,
        type: ArchitectOrthoType.none,
      );
    }

    final angleRad = math.atan2(delta.dy, delta.dx);
    final angleDeg = angleRad * 180.0 / math.pi;
    final absAngleDeg = angleDeg.abs();

    // Horizontal check: near 0° or 180°
    final isNear0 = absAngleDeg <= snapAngleToleranceDeg;
    final isNear180 = (absAngleDeg - 180.0).abs() <= snapAngleToleranceDeg;
    if (isNear0 || isNear180) {
      final snapped = Offset(raw.dx, anchor.dy);
      final guide = (
        Offset(anchor.dx - guideLineLength, anchor.dy),
        Offset(anchor.dx + guideLineLength, anchor.dy),
      );
      return ArchitectOrthoSnapResult(
        point: snapped,
        isSnapped: true,
        type: ArchitectOrthoType.horizontal,
        guideLine: guide,
        angleDeg: isNear0 ? 0.0 : 180.0,
      );
    }

    // Vertical check: near 90° or -90° (270°)
    final isNear90 = (angleDeg - 90.0).abs() <= snapAngleToleranceDeg;
    final isNearMinus90 = (angleDeg + 90.0).abs() <= snapAngleToleranceDeg;
    if (isNear90 || isNearMinus90) {
      final snapped = Offset(anchor.dx, raw.dy);
      final guide = (
        Offset(anchor.dx, anchor.dy - guideLineLength),
        Offset(anchor.dx, anchor.dy + guideLineLength),
      );
      return ArchitectOrthoSnapResult(
        point: snapped,
        isSnapped: true,
        type: ArchitectOrthoType.vertical,
        guideLine: guide,
        angleDeg: isNear90 ? 90.0 : -90.0,
      );
    }

    return ArchitectOrthoSnapResult(
      point: raw,
      isSnapped: false,
      type: ArchitectOrthoType.none,
      angleDeg: angleDeg,
    );
  }

  /// Computes the arithmetic centroid (center of mass) of polygon vertices.
  static Offset calculateCentroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double sumX = 0.0;
    double sumY = 0.0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  /// Rotates a list of [points] by [angleDeg] around [center] (defaults to centroid).
  static List<Offset> rotatePolygon(
    List<Offset> points,
    double angleDeg, [
    Offset? center,
  ]) {
    if (points.isEmpty || angleDeg.abs() < 1e-4) return points;
    final c = center ?? calculateCentroid(points);
    final rad = angleDeg * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

    return points.map((p) {
      final dx = p.dx - c.dx;
      final dy = p.dy - c.dy;
      final rx = c.dx + dx * cosA - dy * sinA;
      final ry = c.dy + dx * sinA + dy * cosA;
      return Offset(rx, ry);
    }).toList();
  }

  /// Translates all polygon vertices by [delta].
  static List<Offset> translatePolygon(List<Offset> points, Offset delta) {
    if (delta == Offset.zero || points.isEmpty) return points;
    return points.map((p) => p + delta).toList();
  }

  /// Calculates intersection of two infinite rays in 2D Cartesian plane.
  static Offset? rayIntersection(
    Offset p1,
    double angleDeg1,
    Offset p2,
    double angleDeg2,
  ) {
    final rad1 = angleDeg1 * math.pi / 180.0;
    final rad2 = angleDeg2 * math.pi / 180.0;
    final v1 = Offset(math.cos(rad1), math.sin(rad1));
    final v2 = Offset(math.cos(rad2), math.sin(rad2));

    final det = v1.dx * v2.dy - v1.dy * v2.dx;
    if (det.abs() < 1e-4) return null;

    final dp = p2 - p1;
    final t = (dp.dx * v2.dy - dp.dy * v2.dx) / det;
    return p1 + v1 * t;
  }

  /// Straightens polygon corners and wall alignments to exact 90° (and 45°/5°),
  /// ported from the battle-tested GPS_Mapping alignment engine into 2D Cartesian space.
  /// Rectangles become perfectly orthogonal; complex rooms snap corners to 90°.
  /// Centroid is preserved to prevent spatial drift.
  static List<Offset> alignPolygonToNearest2D(
    List<Offset> points, {
    bool isClosed = true,
  }) {
    if (points.length < 3) return List.from(points);

    // 1. Specialized 4-point rectangle / square orthogonalizer
    if (isClosed && points.length == 4) {
      final p0 = points[0];
      final p1 = points[1];
      final p2 = points[2];
      final p3 = points[3];

      final v01 = p1 - p0;
      double baseBearing = math.atan2(v01.dy, v01.dx) * 180.0 / math.pi;
      if (baseBearing < 0) baseBearing += 360.0;

      // Snap base orientation to nearest 90° or 5°
      double nearest90 = (baseBearing / 90.0).round() * 90.0;
      if (nearest90 >= 360.0) nearest90 -= 360.0;
      double diff90 = (baseBearing - nearest90).abs();
      if (diff90 > 180.0) diff90 = 360.0 - diff90;

      if (diff90 <= 12.0) {
        baseBearing = nearest90;
      } else {
        double nearest5 = (baseBearing / 5.0).round() * 5.0;
        if (nearest5 >= 360.0) nearest5 -= 360.0;
        double diff5 = (baseBearing - nearest5).abs();
        if (diff5 > 180.0) diff5 = 360.0 - diff5;
        if (diff5 <= 4.0) baseBearing = nearest5;
      }

      // Detect turning direction (CW vs CCW)
      final cross = (p1.dx - p0.dx) * (p2.dy - p1.dy) - (p1.dy - p0.dy) * (p2.dx - p1.dx);
      final turnAngle = cross < 0 ? -90.0 : 90.0;

      final d01 = (p1 - p0).distance;
      final d12 = (p2 - p1).distance;
      final d23 = (p3 - p2).distance;
      final d30 = (p0 - p3).distance;

      // Average opposite lengths and round to clean 5 cm increments
      double length = ((d01 + d23) / 2.0);
      length = (length * 20.0).round() / 20.0;
      if (length < 0.20) length = 0.20;

      double width = ((d12 + d30) / 2.0);
      width = (width * 20.0).round() / 20.0;
      if (width < 0.20) width = 0.20;

      final b1 = baseBearing;
      final b2 = (b1 + turnAngle) % 360.0;
      final b3 = (b2 + turnAngle) % 360.0;

      Offset step(Offset from, double deg, double dist) {
        final r = deg * math.pi / 180.0;
        return from + Offset(math.cos(r) * dist, math.sin(r) * dist);
      }

      final ap0 = p0;
      final ap1 = step(ap0, b1, length);
      final ap2 = step(ap1, b2, width);
      final ap3 = step(ap2, b3, length);

      final origCenter = calculateCentroid(points);
      final alignedCenter = calculateCentroid([ap0, ap1, ap2, ap3]);
      final shift = origCenter - alignedCenter;

      return [
        ap0 + shift,
        ap1 + shift,
        ap2 + shift,
        ap3 + shift,
      ];
    }

    // 2. Multi-point polygon alignment (L-shaped, T-shaped, arbitrary polyline)
    final aligned = <Offset>[points.first];
    double? firstAlignedBearing;
    double? prevAlignedBearing;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final delta = p2 - p1;
      double dist = delta.distance;
      dist = (dist * 20.0).round() / 20.0;
      if (dist < 0.05) dist = 0.05;

      double bearing = math.atan2(delta.dy, delta.dx) * 180.0 / math.pi;
      if (bearing < 0) bearing += 360.0;

      double targetAngle;
      if (prevAlignedBearing == null) {
        targetAngle = bearing;
        double n90 = (targetAngle / 90.0).round() * 90.0;
        if (n90 >= 360.0) n90 -= 360.0;
        double d90 = (targetAngle - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        if (d90 <= 12.0) {
          targetAngle = n90;
        } else {
          double n45 = (targetAngle / 45.0).round() * 45.0;
          if (n45 >= 360.0) n45 -= 360.0;
          double d45 = (targetAngle - n45).abs();
          if (d45 > 180.0) d45 = 360.0 - d45;
          if (d45 <= 6.0) targetAngle = n45;
        }
        firstAlignedBearing = targetAngle;
      } else {
        double relAngle = (bearing - prevAlignedBearing) % 360.0;
        if (relAngle < 0) relAngle += 360.0;

        double snappedRel = relAngle;
        double n90 = (relAngle / 90.0).round() * 90.0;
        double d90 = (relAngle - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        if (d90 <= 12.0) {
          snappedRel = n90;
        } else {
          double n45 = (relAngle / 45.0).round() * 45.0;
          double d45 = (relAngle - n45).abs();
          if (d45 > 180.0) d45 = 360.0 - d45;
          if (d45 <= 6.0) snappedRel = n45;
        }
        targetAngle = (prevAlignedBearing + snappedRel) % 360.0;
      }

      // Closing segment ray intersection for closed polygons
      if (isClosed && points.length > 3 && i == points.length - 2 && firstAlignedBearing != null) {
        final closingDelta = points.last - points.first;
        double closingBearing = math.atan2(closingDelta.dy, closingDelta.dx) * 180.0 / math.pi;
        if (closingBearing < 0) closingBearing += 360.0;

        double relClosing = (closingBearing - firstAlignedBearing) % 360.0;
        if (relClosing < 0) relClosing += 360.0;
        double n90 = (relClosing / 90.0).round() * 90.0;
        double d90 = (relClosing - n90).abs();
        if (d90 > 180.0) d90 = 360.0 - d90;

        double snappedRelClosing = d90 <= 12.0 ? n90 : relClosing;
        double targetClosing = (firstAlignedBearing + snappedRelClosing) % 360.0;

        final isect = rayIntersection(aligned.last, targetAngle, points.first, targetClosing);
        if (isect != null && (isect - aligned.last).distance < dist * 2.5) {
          aligned.add(isect);
          prevAlignedBearing = targetAngle;
          continue;
        }
      }

      prevAlignedBearing = targetAngle;
      final rad = targetAngle * math.pi / 180.0;
      final nextPt = aligned.last + Offset(math.cos(rad) * dist, math.sin(rad) * dist);
      aligned.add(nextPt);
    }

    if (isClosed && aligned.length >= 3) {
      final origCenter = calculateCentroid(points);
      final alignedCenter = calculateCentroid(aligned);
      final shift = origCenter - alignedCenter;
      return aligned.map((p) => p + shift).toList();
    }
    return aligned;
  }

  /// Offsets polygon boundary outward (positive distance) or inward (negative distance).
  static List<Offset> offsetPolygon(List<Offset> polygon, double distance) {
    final n = polygon.length;
    if (n < 3 || distance.abs() < 1e-4) return polygon;

    final normals = <Offset>[];
    for (int i = 0; i < n; i++) {
      normals.add(calculateOutwardNormal(polygon, i));
    }

    final newPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final prevEdge = (i - 1 + n) % n;
      final currEdge = i;
      final n1 = normals[prevEdge];
      final n2 = normals[currEdge];

      final pPrev = polygon[prevEdge] + n1 * distance;
      final v1 = polygon[i] - polygon[prevEdge];
      final pCurr = polygon[currEdge] + n2 * distance;
      final v2 = polygon[(currEdge + 1) % n] - polygon[currEdge];

      final det = v1.dx * v2.dy - v1.dy * v2.dx;
      if (det.abs() > 1e-4) {
        final dp = pCurr - pPrev;
        final t = (dp.dx * v2.dy - dp.dy * v2.dx) / det;
        newPts.add(pPrev + v1 * t);
      } else {
        newPts.add(polygon[i] + (n1 + n2) / 2.0 * distance);
      }
    }

    if (hasSelfIntersections(newPts) || calculateArea(newPts) < 0.1) {
      return polygon;
    }
    return newPts;
  }
}

// === SECTION: ZONE_TOOL_CONTROLLER ===

/// Unified state and operation manager for architectural functional zones.
/// Combines point-by-point polyline drafting, interactive edge midpoint extrusion,
/// and geometric safety validations into a cohesive, single tool unit.
class ArchitectZoneTool extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Drafting Mode & Fast Rectangle State
  // ---------------------------------------------------------------------------
  ArchitectZoneDraftMode _draftMode = ArchitectZoneDraftMode.polyline;
  ArchitectZoneDraftMode get draftMode => _draftMode;
  set draftMode(ArchitectZoneDraftMode mode) {
    if (_draftMode != mode) {
      _draftMode = mode;
      cancelDrafting();
    }
  }

  // ---------------------------------------------------------------------------
  // Drafting State (Point-by-point creation)
  // ---------------------------------------------------------------------------
  final List<Offset> _draftPoints = [];
  Offset? _candidatePoint;
  Offset? _snappedPoint;
  (Offset, Offset)? _orthoGuide;
  String? _orthoLabel;
  List<(Offset, Offset)> _magneticGuides = [];
  bool _isClosingSnap = false;
  ZoneDraftingPointStatus _pointStatus = ZoneDraftingPointStatus.valid;

  // ---------------------------------------------------------------------------
  // GPS_Mapping-style Zone Edit & Transform State
  // ---------------------------------------------------------------------------
  ArchitectZone? _editingZone;
  List<Offset>? _editingPolygon;
  List<Offset>? _preAlignBackupPolygon;
  final List<List<Offset>> _editUndoStack = [];
  final List<List<Offset>> _editRedoStack = [];
  double _editRotationSlider = 0.0;
  double _lastAppliedRotationSlider = 0.0;
  bool _isMoveWholeZoneMode = false;
  Offset? _moveStartPoint;
  List<Offset>? _moveStartPolygon;
  double _moveDistanceMeters = 0.0;

  // ---------------------------------------------------------------------------
  // Edge Extrusion State (Midpoint handle drag)
  // ---------------------------------------------------------------------------
  ArchitectZone? _extrudeTargetZone;
  int? _extrudeEdgeIndex;
  Offset? _extrudeV1;
  Offset? _extrudeV2;
  Offset? _extrudeMidInitial;
  Offset? _extrudeNormal;
  double _extrudeDistance = 0.0;
  List<Offset>? _extrudePreviewPolygon;
  bool _isExtrudeSelfIntersecting = false;

  // ---------------------------------------------------------------------------
  // Drafting Getters
  // ---------------------------------------------------------------------------
  List<Offset> get draftPoints => List.unmodifiable(_draftPoints);
  List<Offset> get points => List.unmodifiable(_draftPoints);
  int get draftPointCount => _draftPoints.length;
  int get pointCount => _draftPoints.length;
  bool get isDrafting => _draftPoints.isNotEmpty;
  bool get canCloseDraft {
    if (_draftMode == ArchitectZoneDraftMode.rectangle) {
      if (_draftPoints.length >= 3) return true;
      if (_draftPoints.length == 1 && candidatePoint != null) {
        final p0 = _draftPoints[0];
        final p2 = candidatePoint!;
        return (p2.dx - p0.dx).abs() >= 0.15 && (p2.dy - p0.dy).abs() >= 0.15;
      }
      return false;
    }
    return _draftPoints.length >= 3;
  }
  bool get canClose => canCloseDraft;
  Offset? get candidatePoint => _snappedPoint ?? _candidatePoint;
  Offset? get rawCandidatePoint => _candidatePoint;
  (Offset, Offset)? get orthoGuide => _orthoGuide;
  String? get orthoLabel => _orthoLabel;
  List<(Offset, Offset)> get magneticGuides => _magneticGuides;
  bool get isClosingSnap => _isClosingSnap;
  ZoneDraftingPointStatus get pointStatus => _pointStatus;

  List<Offset> get previewRectangle {
    if (_draftMode != ArchitectZoneDraftMode.rectangle ||
        _draftPoints.length != 1 ||
        candidatePoint == null) {
      return const [];
    }
    final p0 = _draftPoints[0];
    final p2 = candidatePoint!;
    final p1 = Offset(p2.dx, p0.dy);
    final p3 = Offset(p0.dx, p2.dy);
    return [p0, p1, p2, p3];
  }

  double? get activeSegmentLength {
    if (_draftPoints.isEmpty || candidatePoint == null) return null;
    return (candidatePoint! - _draftPoints.last).distance;
  }

  double? get activeSegmentAngleDeg {
    if (_draftPoints.isEmpty || candidatePoint == null) return null;
    final d = candidatePoint! - _draftPoints.last;
    if (d.distance < 1e-4) return 0.0;
    return math.atan2(d.dy, d.dx) * 180.0 / math.pi;
  }

  double get livePerimeter {
    if (_draftPoints.isEmpty) return 0.0;
    if (_draftMode == ArchitectZoneDraftMode.rectangle && candidatePoint != null) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      return 2.0 * ((p2.dx - p0.dx).abs() + (p2.dy - p0.dy).abs());
    }
    double perim = 0.0;
    for (int i = 0; i < _draftPoints.length - 1; i++) {
      perim += (_draftPoints[i + 1] - _draftPoints[i]).distance;
    }
    if (candidatePoint != null) {
      perim += (candidatePoint! - _draftPoints.last).distance;
      if (_draftPoints.length >= 2) {
        perim += (candidatePoint! - _draftPoints.first).distance;
      }
    }
    return perim;
  }

  double get liveArea {
    if (_draftPoints.isEmpty || candidatePoint == null) return 0.0;
    if (_draftMode == ArchitectZoneDraftMode.rectangle) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      return (p2.dx - p0.dx).abs() * (p2.dy - p0.dy).abs();
    }
    if (_draftPoints.length < 2) return 0.0;
    final testPoly = [..._draftPoints, candidatePoint!];
    return ArchitectZoneGeometry.calculateArea(testPoly);
  }

  // ---------------------------------------------------------------------------
  // Extrusion Getters
  // ---------------------------------------------------------------------------
  bool get isExtruding => _extrudeEdgeIndex != null && _extrudeTargetZone != null;
  int? get extrudeEdgeIndex => _extrudeEdgeIndex;
  double get extrudeDistance => _extrudeDistance;
  double get activeDistance => _extrudeDistance;
  List<Offset>? get extrudePreviewPolygon => _extrudePreviewPolygon;
  List<Offset>? get previewPolygon => _extrudePreviewPolygon;
  bool get isExtrudeSelfIntersecting => _isExtrudeSelfIntersecting;
  bool get isSelfIntersecting => _isExtrudeSelfIntersecting;
  Offset? get extrudeNormal => _extrudeNormal;
  Offset? get normal => _extrudeNormal;
  Offset? get extrudeV1 => _extrudeV1;
  Offset? get v1 => _extrudeV1;
  Offset? get extrudeV2 => _extrudeV2;
  Offset? get v2 => _extrudeV2;
  Offset? get extrudeMidInitial => _extrudeMidInitial;

  // ---------------------------------------------------------------------------
  // GPS_Mapping-style Edit & Transform Getters
  // ---------------------------------------------------------------------------
  bool get isEditingZone => _editingZone != null;
  ArchitectZone? get editingZone => _editingZone;
  List<Offset>? get editingPolygon => _editingPolygon;
  bool get canUndoAutoAlign => _preAlignBackupPolygon != null;
  bool get canUndoEdit => _editUndoStack.isNotEmpty;
  bool get canRedoEdit => _editRedoStack.isNotEmpty;
  double get editRotationSlider => _editRotationSlider;
  bool get isMoveWholeZoneMode => _isMoveWholeZoneMode;
  double get moveDistanceMeters => _moveDistanceMeters;

  /// General flag for whether tool has an active modal interaction.
  bool get isInteracting => isDrafting || isExtruding || isMoveWholeZoneMode;

  // Convenient aliases
  void start(Offset startPoint) => startDrafting(startPoint);
  bool addPoint(Offset point) => addDraftingPoint(point);
  void undoLastPoint() => undoDraftingPoint();
  void cancel() => cancelDrafting();
  ArchitectZone? commit({
    required ArchitectZoneCategory category,
    required String defaultName,
  }) =>
      commitDrafting(category: category, defaultName: defaultName);
  void updatePointer({
    required Offset rawModelPoint,
    required ArchitectProject project,
    required double currentScale,
  }) =>
      updateDraftingPointer(
        rawModelPoint: rawModelPoint,
        project: project,
        currentScale: currentScale,
      );

  // ---------------------------------------------------------------------------
  // Drafting Methods
  // ---------------------------------------------------------------------------

  void startDrafting(Offset startPoint) {
    cancelExtrude();
    _draftPoints.clear();
    _draftPoints.add(startPoint);
    _candidatePoint = startPoint;
    _snappedPoint = startPoint;
    _orthoGuide = null;
    _orthoLabel = null;
    _magneticGuides = [];
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  void updateDraftingPointer({
    required Offset rawModelPoint,
    required ArchitectProject project,
    required double currentScale,
  }) {
    if (!isDrafting) return;

    if (_candidatePoint != null && (rawModelPoint - _candidatePoint!).distance < 0.02) {
      return;
    }

    _candidatePoint = rawModelPoint;
    final lastPoint = _draftPoints.last;
    final snapTolerance = 14.0 / currentScale;

    // 1. Closing snap to first point
    if (_draftPoints.length >= 3) {
      final firstPoint = _draftPoints.first;
      if ((rawModelPoint - firstPoint).distance <= snapTolerance * 1.5) {
        _snappedPoint = firstPoint;
        _isClosingSnap = true;
        _orthoGuide = null;
        _orthoLabel = null;
        _magneticGuides = [];
        _pointStatus = ZoneDraftingPointStatus.closeTarget;
        notifyListeners();
        return;
      }
    }
    _isClosingSnap = false;

    // 2. Structural & zone magnetic snapping
    final zoneSnap = ArchitectZoneSnap.snap(
      raw: rawModelPoint,
      project: project,
      tolerance: snapTolerance,
    );

    Offset candidate = zoneSnap.isSnapped ? zoneSnap.point : rawModelPoint;
    _magneticGuides = zoneSnap.magneticGuides;

    // 3. Orthogonal straightening guide relative to previous point
    final orthoResult = ArchitectZoneGeometry.calculateOrthoSnap(
      anchor: lastPoint,
      raw: candidate,
      snapAngleToleranceDeg: 7.0,
    );

    if (orthoResult.isSnapped) {
      candidate = orthoResult.point;
      _orthoGuide = orthoResult.guideLine;
      _orthoLabel = orthoResult.type == ArchitectOrthoType.horizontal
          ? '0°'
          : '90°';
    } else {
      _orthoGuide = null;
      _orthoLabel = null;
    }

    _snappedPoint = candidate;

    // 4. Validate candidate against self-intersections
    final isIntersecting = ArchitectZoneGeometry.segmentIntersectsChain(
      lastPoint,
      candidate,
      _draftPoints,
    );

    if (isIntersecting) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
    } else if ((candidate - lastPoint).distance < 0.15) {
      _pointStatus = ZoneDraftingPointStatus.tooClose;
    } else {
      _pointStatus = ZoneDraftingPointStatus.valid;
    }

    notifyListeners();
  }

  bool addDraftingPoint(Offset point) {
    if (!isDrafting) {
      startDrafting(point);
      return true;
    }

    if (_draftMode == ArchitectZoneDraftMode.rectangle && _draftPoints.length == 1) {
      final p0 = _draftPoints[0];
      final p2 = point;
      if ((p2.dx - p0.dx).abs() < 0.1 || (p2.dy - p0.dy).abs() < 0.1) {
        return false;
      }
      final p1 = Offset(p2.dx, p0.dy);
      final p3 = Offset(p0.dx, p2.dy);
      _draftPoints.clear();
      _draftPoints.addAll([p0, p1, p2, p3]);
      _candidatePoint = p2;
      _snappedPoint = p2;
      _pointStatus = ZoneDraftingPointStatus.valid;
      notifyListeners();
      return true;
    }

    if (_draftPoints.length >= 3) {
      final distToStart = (point - _draftPoints.first).distance;
      if (_isClosingSnap || distToStart <= 0.35) {
        return true;
      }
    }

    if ((point - _draftPoints.last).distance < 0.15) {
      return false;
    }

    if (ArchitectZoneGeometry.segmentIntersectsChain(
        _draftPoints.last, point, _draftPoints)) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return false;
    }

    _draftPoints.add(point);
    _candidatePoint = point;
    _snappedPoint = point;
    _orthoGuide = null;
    _orthoLabel = null;
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
    return true;
  }

  void undoDraftingPoint() {
    if (_draftPoints.isEmpty) return;
    _draftPoints.removeLast();
    if (_draftPoints.isNotEmpty) {
      _candidatePoint = _draftPoints.last;
      _snappedPoint = _draftPoints.last;
    } else {
      cancelDrafting();
      return;
    }
    _orthoGuide = null;
    _orthoLabel = null;
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  void cancelDrafting() {
    _draftPoints.clear();
    _candidatePoint = null;
    _snappedPoint = null;
    _orthoGuide = null;
    _orthoLabel = null;
    _magneticGuides = [];
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  ArchitectZone? commitDrafting({
    required ArchitectZoneCategory category,
    required String defaultName,
  }) {
    if (_draftMode == ArchitectZoneDraftMode.rectangle &&
        _draftPoints.length == 1 &&
        candidatePoint != null) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      if ((p2.dx - p0.dx).abs() >= 0.1 && (p2.dy - p0.dy).abs() >= 0.1) {
        final p1 = Offset(p2.dx, p0.dy);
        final p3 = Offset(p0.dx, p2.dy);
        _draftPoints.clear();
        _draftPoints.addAll([p0, p1, p2, p3]);
      }
    }

    if (_draftPoints.length < 3) return null;

    if (ArchitectZoneGeometry.segmentIntersectsChain(
      _draftPoints.last,
      _draftPoints.first,
      _draftPoints,
      isClosing: true,
    )) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return null;
    }

    final cleaned = ArchitectZoneGeometry.cleanPolygon(
      _draftPoints,
      minDistance: 0.05,
      minCollinearDistance: 0.02,
    );

    if (cleaned.length < 3) return null;

    if (ArchitectZoneGeometry.hasSelfIntersections(cleaned)) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newZone = ArchitectZone(
      id: 'zone_$now',
      name: defaultName,
      category: category,
      polygon: cleaned,
    );

    cancelDrafting();
    return newZone;
  }

  // ---------------------------------------------------------------------------
  // Extrusion Methods
  // ---------------------------------------------------------------------------

  bool startExtrude({
    required ArchitectZone zone,
    required int edgeIndex,
    required Offset pointerModel,
  }) {
    cancelDrafting();
    final poly = zone.polygon;
    final n = poly.length;
    if (edgeIndex < 0 || edgeIndex >= n) return false;

    _extrudeTargetZone = zone;
    _extrudeEdgeIndex = edgeIndex;
    _extrudeV1 = poly[edgeIndex];
    _extrudeV2 = poly[(edgeIndex + 1) % n];
    _extrudeMidInitial = (_extrudeV1! + _extrudeV2!) / 2.0;
    _extrudeNormal = ArchitectZoneGeometry.calculateOutwardNormal(poly, edgeIndex);
    _extrudeDistance = 0.0;
    _extrudePreviewPolygon = List<Offset>.from(poly);
    _isExtrudeSelfIntersecting = false;
    notifyListeners();
    return true;
  }

  void updateExtrudePointer(Offset pointerModel) {
    if (!isExtruding || _extrudeNormal == null || _extrudeMidInitial == null) {
      return;
    }

    final delta = pointerModel - _extrudeMidInitial!;
    final dist = delta.dx * _extrudeNormal!.dx + delta.dy * _extrudeNormal!.dy;
    _extrudeDistance = dist;

    final poly = _extrudeTargetZone!.polygon;
    final n = poly.length;
    final vNew1 = _extrudeV1! + _extrudeNormal! * dist;
    final vNew2 = _extrudeV2! + _extrudeNormal! * dist;

    final testPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      testPts.add(poly[i]);
      if (i == _extrudeEdgeIndex) {
        testPts.add(vNew1);
        testPts.add(vNew2);
      }
    }

    _isExtrudeSelfIntersecting = ArchitectZoneGeometry.hasSelfIntersections(testPts);
    _extrudePreviewPolygon = testPts;
    notifyListeners();
  }

  (ArchitectZone, int cleanedCount)? commitExtrude() {
    if (!isExtruding || _extrudeTargetZone == null || _extrudeEdgeIndex == null) {
      cancelExtrude();
      return null;
    }

    if (_extrudeDistance.abs() < 0.05) {
      cancelExtrude();
      return null;
    }

    final poly = _extrudeTargetZone!.polygon;
    final rawCount = poly.length + 2;
    final extruded = ArchitectZoneGeometry.extrudeEdge(
      polygon: poly,
      edgeIndex: _extrudeEdgeIndex!,
      distance: _extrudeDistance,
      minDistance: 0.05,
    );

    if (extruded == null) {
      cancelExtrude();
      return null;
    }

    final cleanedCount = rawCount - extruded.length;
    final updatedZone = _extrudeTargetZone!.copyWith(polygon: extruded);
    cancelExtrude();
    return (updatedZone, cleanedCount > 0 ? cleanedCount : 0);
  }

  void cancelExtrude() {
    _extrudeTargetZone = null;
    _extrudeEdgeIndex = null;
    _extrudeV1 = null;
    _extrudeV2 = null;
    _extrudeMidInitial = null;
    _extrudeNormal = null;
    _extrudeDistance = 0.0;
    _extrudePreviewPolygon = null;
    _isExtrudeSelfIntersecting = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GPS_Mapping-style Zone Edit & Transform Methods
  // ---------------------------------------------------------------------------

  /// Initiates interactive edit mode for an existing zone.
  void startEditingZone(ArchitectZone zone) {
    cancelDrafting();
    cancelExtrude();
    _editingZone = zone;
    _editingPolygon = List<Offset>.from(zone.polygon);
    _preAlignBackupPolygon = null;
    _editUndoStack.clear();
    _editRedoStack.clear();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    _isMoveWholeZoneMode = false;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  void _pushEditUndo() {
    if (_editingPolygon == null) return;
    _editUndoStack.add(List<Offset>.from(_editingPolygon!));
    if (_editUndoStack.length > 25) {
      _editUndoStack.removeAt(0);
    }
    _editRedoStack.clear();
  }

  void undoEditAction() {
    if (_editUndoStack.isEmpty || _editingPolygon == null) return;
    _editRedoStack.add(List<Offset>.from(_editingPolygon!));
    _editingPolygon = _editUndoStack.removeLast();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  void redoEditAction() {
    if (_editRedoStack.isEmpty || _editingPolygon == null) return;
    _editUndoStack.add(List<Offset>.from(_editingPolygon!));
    _editingPolygon = _editRedoStack.removeLast();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  /// Automatically squares all corners of the editing polygon to 90° (and closes at 90°),
  /// preserving centroid and area scale (GPS_Mapping squarify algorithm).
  bool autoAlignZone() {
    if (_editingPolygon == null || _editingPolygon!.length < 3) return false;
    final aligned = ArchitectZoneGeometry.alignPolygonToNearest2D(_editingPolygon!);
    if (aligned.length != _editingPolygon!.length) return false;

    bool changed = false;
    for (int i = 0; i < aligned.length; i++) {
      if ((aligned[i] - _editingPolygon![i]).distance > 0.005) {
        changed = true;
        break;
      }
    }
    if (!changed) return false;

    _pushEditUndo();
    _preAlignBackupPolygon = List<Offset>.from(_editingPolygon!);
    _editingPolygon = aligned;
    notifyListeners();
    return true;
  }

  /// Reverts the 90° straightening operation.
  bool undoAutoAlignZone() {
    if (_preAlignBackupPolygon == null || _editingPolygon == null) return false;
    _pushEditUndo();
    _editingPolygon = List<Offset>.from(_preAlignBackupPolygon!);
    _preAlignBackupPolygon = null;
    notifyListeners();
    return true;
  }

  /// Live updates polygon rotation using centroid-based rotation matrix.
  void setRotationSlider(double angleDeg) {
    if (_editingPolygon == null) return;
    final delta = angleDeg - _lastAppliedRotationSlider;
    _editRotationSlider = angleDeg;
    if (delta.abs() > 0.01) {
      final centroid = ArchitectZoneGeometry.calculateCentroid(_editingPolygon!);
      _editingPolygon = ArchitectZoneGeometry.rotatePolygon(_editingPolygon!, delta, centroid);
      _lastAppliedRotationSlider = angleDeg;
      notifyListeners();
    }
  }

  /// Finalizes rotation slider drag gesture and creates an undo restore point.
  void finishRotationSlider() {
    if (_editingPolygon == null) return;
    if (_lastAppliedRotationSlider.abs() > 0.1) {
      _pushEditUndo();
    }
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  /// Incremental rotation step (e.g. ±15°, ±90°).
  void applyRotationStep(double stepDeg) {
    if (_editingPolygon == null) return;
    _pushEditUndo();
    final centroid = ArchitectZoneGeometry.calculateCentroid(_editingPolygon!);
    _editingPolygon = ArchitectZoneGeometry.rotatePolygon(_editingPolygon!, stepDeg, centroid);
    notifyListeners();
  }

  /// Boundary offset step (in meters, e.g. ±0.20m).
  void applyOffsetStep(double distanceMeters) {
    if (_editingPolygon == null) return;
    _pushEditUndo();
    _editingPolygon = ArchitectZoneGeometry.offsetPolygon(_editingPolygon!, distanceMeters);
    notifyListeners();
  }

  /// Toggles whole zone translation drag mode.
  void toggleMoveWholeZoneMode() {
    _isMoveWholeZoneMode = !_isMoveWholeZoneMode;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  void startMovingZone(Offset modelPoint) {
    if (!_isMoveWholeZoneMode || _editingPolygon == null) return;
    _moveStartPoint = modelPoint;
    _moveStartPolygon = List<Offset>.from(_editingPolygon!);
    _moveDistanceMeters = 0.0;
  }

  void updateMovingZone(Offset modelPoint) {
    if (!_isMoveWholeZoneMode || _moveStartPoint == null || _moveStartPolygon == null) return;
    final delta = modelPoint - _moveStartPoint!;
    _moveDistanceMeters = delta.distance;
    _editingPolygon = ArchitectZoneGeometry.translatePolygon(_moveStartPolygon!, delta);
    notifyListeners();
  }

  void finishMovingZone() {
    if (_moveStartPolygon != null && _editingPolygon != null) {
      if (_moveDistanceMeters > 0.02) {
        _editUndoStack.add(_moveStartPolygon!);
        _editRedoStack.clear();
      }
    }
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  void dragEditingVertex(int index, Offset newPos) {
    if (_editingPolygon == null || index < 0 || index >= _editingPolygon!.length) return;
    _pushEditUndo();
    _editingPolygon![index] = newPos;
    notifyListeners();
  }

  /// Finalizes edit mode and returns the updated zone with cleaned polygon.
  ArchitectZone? commitEditingZone() {
    if (_editingZone == null || _editingPolygon == null) return null;
    final cleaned = ArchitectZoneGeometry.cleanPolygon(
      _editingPolygon!,
      minDistance: 0.05,
      minCollinearDistance: 0.02,
    );
    if (cleaned.length < 3 || ArchitectZoneGeometry.hasSelfIntersections(cleaned)) {
      return null;
    }
    final updated = _editingZone!.copyWith(polygon: cleaned);
    cancelEditingZone();
    return updated;
  }

  /// Cancels edit mode without saving changes.
  void cancelEditingZone() {
    _editingZone = null;
    _editingPolygon = null;
    _preAlignBackupPolygon = null;
    _editUndoStack.clear();
    _editRedoStack.clear();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    _isMoveWholeZoneMode = false;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  /// Cancels drafting, extrusion, and edit operations.
  void cancelAll() {
    cancelDrafting();
    cancelExtrude();
    cancelEditingZone();
  }
}
