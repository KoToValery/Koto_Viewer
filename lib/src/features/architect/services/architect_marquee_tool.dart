import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_contour.dart';
import 'architect_selection.dart';

/// Geometry mode for the architectural selection marquee tool.
enum ArchitectSelectMode {
  /// 2-point / drag rectangular marquee frame.
  rectangle,

  /// Point-by-point arbitrary polygonal marquee contour.
  polygon,
}

enum ArchitectSelectionOperation { replace, add, remove }

enum ArchitectSelectionRelation { crossing, contained }

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
    if (points.isNotEmpty &&
        (pt - points.last).distance < BimPolygonGeometry.epsilon) {
      return;
    }
    points.add(pt);
    candidatePoint = null;
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
      final p2 = points.length >= 2 ? points[1] : (candidatePoint ?? p1);
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
          (candidatePoint! - points.last).distance >
              BimPolygonGeometry.epsilon) {
        res.add(candidatePoint!);
      }
      return res;
    }
  }

  /// Commit from the actual final pick, never from a stale hover candidate.
  List<Offset> finish({Offset? rectangleEnd}) {
    if (points.isEmpty) return const [];
    final List<Offset> polygon;
    if (mode == ArchitectSelectMode.rectangle) {
      final end =
          rectangleEnd ?? (points.length > 1 ? points[1] : candidatePoint);
      if (end == null) return const [];
      final rect = Rect.fromPoints(points.first, end);
      polygon = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
      ];
    } else {
      polygon = List.of(points);
    }
    return BimPolygonGeometry.valid(polygon) ? polygon : const [];
  }

  static Set<String> combine(
    Set<String> current,
    Set<String> hits,
    ArchitectSelectionOperation operation,
  ) => switch (operation) {
    ArchitectSelectionOperation.replace => Set.of(hits),
    ArchitectSelectionOperation.add => {...current, ...hits},
    ArchitectSelectionOperation.remove => Set.of(current)..removeAll(hits),
  };

  static Set<String> evaluateSelection({
    required ArchitectStorey storey,
    required ArchitectProject project,
    required List<Offset> polygon,
    bool includeComponents = true,
    ArchitectSelectionRelation relation = ArchitectSelectionRelation.crossing,
  }) {
    if (!BimPolygonGeometry.valid(polygon)) return const {};
    final selected = <String>{};
    final marquee = Path()..addPolygon(polygon, true);
    final bounds = marquee.getBounds();
    bool inside(Offset p) =>
        marquee.contains(p) ||
        List.generate(
          polygon.length,
          (i) =>
              (p -
                      BimLineGeometry.closest(
                        p,
                        polygon[i],
                        polygon[(i + 1) % polygon.length],
                      ))
                  .distance <=
              1e-7,
        ).any((hit) => hit);
    bool segment(Offset a, Offset b) {
      if (relation == ArchitectSelectionRelation.contained) {
        if (!inside(a) || !inside(b)) return false;
        final cuts = <double>[0, 1];
        for (var i = 0; i < polygon.length; i++) {
          final hit = BimLineGeometry.intersection(
            a,
            b,
            polygon[i],
            polygon[(i + 1) % polygon.length],
            firstFinite: true,
            secondFinite: true,
          );
          if (hit != null) cuts.add(BimLineGeometry.parameter(hit, a, b));
          if ((polygon[i] - BimLineGeometry.closest(polygon[i], a, b))
                  .distance <=
              1e-7) {
            cuts.add(BimLineGeometry.parameter(polygon[i], a, b));
          }
        }
        cuts.sort();
        for (var i = 1; i < cuts.length; i++) {
          if (!inside(a + (b - a) * ((cuts[i - 1] + cuts[i]) / 2))) {
            return false;
          }
        }
        return true;
      }
      if (inside(a) || inside(b)) return true;
      for (var i = 0; i < polygon.length; i++) {
        if (BimPolygonGeometry.segmentsIntersect(
          a,
          b,
          polygon[i],
          polygon[(i + 1) % polygon.length],
        )) {
          return true;
        }
      }
      return false;
    }

    bool region(Path path) {
      final shapeBounds = path.getBounds();
      if (!bounds.overlaps(shapeBounds) ||
          !path.computeMetrics().any(
            (m) => m.length > BimPolygonGeometry.epsilon,
          )) {
        return false;
      }
      final operation = relation == ArchitectSelectionRelation.contained
          ? PathOperation.difference
          : PathOperation.intersect;
      final hasRegion = Path.combine(
        operation,
        relation == ArchitectSelectionRelation.contained ? path : marquee,
        relation == ArchitectSelectionRelation.contained ? marquee : path,
      ).computeMetrics().any((m) => m.length > 1e-7);
      return relation == ArchitectSelectionRelation.contained
          ? !hasRegion
          : hasRegion;
    }

    bool contour(List<Offset> outer, [List<List<Offset>> holes = const []]) =>
        region(ArchitectContour.path(outer, holes));

    for (final wall in storey.walls) {
      if (contour(wall.polygonCorners)) selected.add(wall.id);
      // Hosted openings are picked by their own footprint, not by their host.
      for (final door in wall.doors) {
        if (region(
          ArchitectSelection.openingOutline(wall, door.offsetRatio, door.width),
        )) {
          selected.add(door.id);
        }
      }
      for (final window in wall.windows) {
        if (region(
          ArchitectSelection.openingOutline(
            wall,
            window.offsetRatio,
            window.width,
          ),
        )) {
          selected.add(window.id);
        }
      }
    }
    for (final column in storey.columns) {
      if (region(ArchitectSelection.columnOutline(column))) {
        selected.add(column.id);
      }
    }
    for (final beam in storey.beams) {
      if (contour(beam.polygonCorners)) selected.add(beam.id);
    }
    for (final slab in storey.slabs) {
      if (contour(slab.polygon, slab.holes)) selected.add(slab.id);
    }
    for (final roof in storey.roofs) {
      if (contour(roof.points, roof.holes)) selected.add(roof.id);
    }
    for (final zone in storey.zones) {
      if (contour(zone.polygon)) selected.add(zone.id);
    }
    for (final primitive in storey.cadPrimitives) {
      if (primitive.type == CadPrimitiveType.line ||
          primitive.type == CadPrimitiveType.polyline) {
        final points = primitive.linePoints;
        final hits = [for (var i = 1; i < points.length; i++)
          segment(points[i - 1], points[i])];
        if (relation == ArchitectSelectionRelation.contained
            ? hits.every((hit) => hit)
            : hits.any((hit) => hit)) {
          selected.add(primitive.id);
        }
      } else if (primitive.isPolygon) {
        if (contour(primitive.polygonCorners, primitive.holes)) {
          selected.add(primitive.id);
        }
      } else if (primitive.type == CadPrimitiveType.circle) {
        if (region(
          Path()..addOval(
            Rect.fromCircle(
              center: primitive.startPoint,
              radius: (primitive.endPoint - primitive.startPoint).distance,
            ),
          ),
        )) {
          selected.add(primitive.id);
        }
      }
    }
    for (final opening in storey.openings) {
      if (contour(opening.boundary)) selected.add(opening.id);
    }
    for (final dimension in storey.dimensions) {
      final hit = relation == ArchitectSelectionRelation.contained
          ? dimension.anchors.every((a) => inside(a.point)) &&
                segment(dimension.lineStart, dimension.lineEnd)
          : dimension.anchors.any((a) => inside(a.point)) ||
                segment(dimension.lineStart, dimension.lineEnd);
      if (hit) selected.add(dimension.id);
    }
    for (final axis in project.gridAxes) {
      if (segment(axis.start, axis.end)) selected.add(axis.id);
    }
    for (final section in project.sections) {
      if (relation == ArchitectSelectionRelation.contained
          ? section.segments.every((s) => segment(s.start, s.end))
          : section.segments.any((s) => segment(s.start, s.end))) {
        selected.add(section.id);
      }
    }
    for (final elevation in project.elevations) {
      if (relation == ArchitectSelectionRelation.contained
          ? elevation.segments.every((s) => segment(s.start, s.end))
          : elevation.segments.any((s) => segment(s.start, s.end))) {
        selected.add(elevation.id);
      }
    }
    for (final drain in storey.floorDrains) {
      if (contour(drain.polygon, drain.holes)) selected.add(drain.id);
    }
    if (includeComponents) {
      for (final component in storey.components.where((c) => c.isVisible)) {
        if (contour(component.worldPolygonCorners)) selected.add(component.id);
      }
    }
    for (final stair in storey.stairs) {
      if (region(stair.plan.path)) selected.add(stair.id);
    }
    return selected;
  }
}
