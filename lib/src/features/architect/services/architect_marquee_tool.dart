import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';

/// Geometry mode for the architectural selection marquee tool.
enum ArchitectSelectMode {
  /// 2-point / drag rectangular marquee frame.
  rectangle,

  /// Point-by-point arbitrary polygonal marquee contour.
  polygon,
}

/// Controller and geometric evaluator for Archicad-style marquee area selection.
class ArchitectMarqueeTool {
  ArchitectSelectMode mode = ArchitectSelectMode.rectangle;

  /// Committed draft points for polygonal selection, or [start, end] for rectangular selection.
  final List<Offset> points = [];

  /// Live candidate point from cursor movement.
  Offset? candidatePoint;

  bool get isDrafting => points.isNotEmpty;

  void setMode(ArchitectSelectMode newMode) {
    if (mode != newMode) {
      mode = newMode;
      cancel();
    }
  }

  void addPoint(Offset pt) {
    if (points.isNotEmpty && (pt - points.last).distance < 0.05) return;
    points.add(pt);
  }

  void updateCandidate(Offset pt) {
    candidatePoint = pt;
  }

  void removeLastPoint() {
    if (points.isNotEmpty) {
      points.removeLast();
      if (points.isEmpty) candidatePoint = null;
    }
  }

  void cancel() {
    points.clear();
    candidatePoint = null;
  }

  /// Evaluates the closed 2D polygon of the current marquee preview.
  List<Offset> get previewPolygon {
    if (points.isEmpty) return const [];
    if (mode == ArchitectSelectMode.rectangle) {
      final p1 = points.first;
      final p2 = candidatePoint ?? (points.length >= 2 ? points[1] : p1);
      final minX = math.min(p1.dx, p2.dx);
      final maxX = math.max(p1.dx, p2.dx);
      final minY = math.min(p1.dy, p2.dy);
      final maxY = math.max(p1.dy, p2.dy);
      return [
        Offset(minX, minY),
        Offset(maxX, minY),
        Offset(maxX, maxY),
        Offset(minX, maxY),
      ];
    } else {
      final res = List<Offset>.from(points);
      if (candidatePoint != null &&
          (candidatePoint! - points.last).distance > 0.05) {
        res.add(candidatePoint!);
      }
      return res;
    }
  }

  /// Evaluates which elements on [storey] and [project] lie inside or intersect [polygon].
  static Set<String> evaluateSelection({
    required ArchitectStorey storey,
    required ArchitectProject project,
    required List<Offset> polygon,
  }) {
    if (polygon.length < 3) return const {};
    final selectedIds = <String>{};

    bool ptInside(Offset pt) => BimPolygonGeometry.contains(polygon, pt);

    bool segmentIntersects(Offset a, Offset b) {
      if (ptInside(a) || ptInside(b)) return true;
      for (int i = 0; i < polygon.length; i++) {
        final e1 = polygon[i];
        final e2 = polygon[(i + 1) % polygon.length];
        if (BimLineGeometry.intersection(a, b, e1, e2,
                firstFinite: true, secondFinite: true) !=
            null) {
          return true;
        }
      }
      return false;
    }

    bool polyIntersects(List<Offset> poly) {
      if (poly.isEmpty) return false;
      for (final pt in poly) {
        if (ptInside(pt)) return true;
      }
      for (int i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        for (int j = 0; j < polygon.length; j++) {
          final e1 = polygon[j];
          final e2 = polygon[(j + 1) % polygon.length];
          if (BimLineGeometry.intersection(a, b, e1, e2,
                  firstFinite: true, secondFinite: true) !=
              null) {
            return true;
          }
        }
      }
      // Marquee is completely inside the element's polygon
      if (BimPolygonGeometry.contains(poly, polygon.first)) return true;
      return false;
    }

    // 1. Walls
    for (final wall in storey.walls) {
      if (segmentIntersects(wall.startPoint, wall.endPoint) ||
          polyIntersects(wall.polygonCorners)) {
        selectedIds.add(wall.id);
        for (final d in wall.doors) {
          selectedIds.add(d.id);
        }
        for (final w in wall.windows) {
          selectedIds.add(w.id);
        }
      }
    }

    // 2. Columns
    for (final col in storey.columns) {
      final rect = Rect.fromCenter(
        center: col.position,
        width: col.width,
        height: col.depth,
      );
      if (ptInside(col.position) ||
          polyIntersects([
            rect.topLeft,
            rect.topRight,
            rect.bottomRight,
            rect.bottomLeft,
          ])) {
        selectedIds.add(col.id);
      }
    }

    // 3. Beams
    for (final beam in storey.beams) {
      if (segmentIntersects(beam.startPoint, beam.endPoint)) {
        selectedIds.add(beam.id);
      }
    }

    // 4. Slabs
    for (final slab in storey.slabs) {
      if (polyIntersects(slab.polygon)) {
        selectedIds.add(slab.id);
      }
    }

    // 5. Roofs
    for (final roof in storey.roofs) {
      if (polyIntersects(roof.points)) {
        selectedIds.add(roof.id);
      }
    }

    // 6. Zones
    for (final zone in storey.zones) {
      if (polyIntersects(zone.polygon) || ptInside(zone.centroid)) {
        selectedIds.add(zone.id);
      }
    }

    // 7. CAD Primitives (lines, rectangles, circles, hatches, text)
    for (final prim in storey.cadPrimitives) {
      if (prim.type == CadPrimitiveType.line) {
        if (segmentIntersects(prim.startPoint, prim.endPoint)) {
          selectedIds.add(prim.id);
        }
      } else if (prim.isPolygon) {
        if (polyIntersects(prim.polygonCorners)) {
          selectedIds.add(prim.id);
        }
      } else {
        if (ptInside(prim.startPoint) || ptInside(prim.endPoint)) {
          selectedIds.add(prim.id);
        }
      }
    }

    // 8. Dimensions
    for (final dim in storey.dimensions) {
      if (dim.anchors.any((a) => ptInside(a.point)) ||
          segmentIntersects(dim.startPoint, dim.endPoint) ||
          segmentIntersects(dim.lineStart, dim.lineEnd)) {
        selectedIds.add(dim.id);
      }
    }

    // 9. Grid axes
    for (final axis in project.gridAxes) {
      if (segmentIntersects(axis.start, axis.end)) {
        selectedIds.add(axis.id);
      }
    }

    // 10. Sections & Elevations
    for (final s in project.sections) {
      if (segmentIntersects(s.start, s.end)) {
        selectedIds.add(s.id);
      }
    }
    for (final e in project.elevations) {
      if (segmentIntersects(e.start, e.end)) {
        selectedIds.add(e.id);
      }
    }

    // 11. Floor drains
    for (final d in storey.floorDrains) {
      if (ptInside(d.position) || polyIntersects(d.polygon)) {
        selectedIds.add(d.id);
      }
    }

    // 12. Components / furniture
    for (final c in storey.components) {
      if (ptInside(c.position)) {
        selectedIds.add(c.id);
      }
    }

    // 13. Stairs
    for (final st in storey.stairs) {
      if (segmentIntersects(st.startPoint, st.endPoint)) {
        selectedIds.add(st.id);
      }
    }

    return selectedIds;
  }
}
