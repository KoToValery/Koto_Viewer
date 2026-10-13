import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_polygon_geometry.dart';

/// A perpendicular distance from a movable edge to a fixed parallel edge.
class ArchitectPolygonDistance {
  final String referenceId;
  final int referenceEdge, edge, side;
  final double distance;
  final Offset start, end, normal;
  const ArchitectPolygonDistance({
    required this.referenceId,
    required this.referenceEdge,
    required this.edge,
    required this.side,
    required this.distance,
    required this.start,
    required this.end,
    required this.normal,
  });

  String get key => '$referenceId-$referenceEdge';

  /// The entered value is the resulting distance, rather than a displacement.
  List<Offset>? setDistance(
    List<Offset> polygon,
    double value, {
    ArchitectPolygonEdgeMode mode = ArchitectPolygonEdgeMode.pull,
  }) {
    if (!value.isFinite || value < .001) return null;
    return ArchitectPolygonGeometry.offsetEdge(
      polygon,
      edge,
      side * (distance - value),
      mode: mode,
    );
  }
}

class ArchitectPolygonDimensions {
  static int? hitEdge(List<Offset> polygon, Offset point, double tolerance) {
    int? hit;
    var best = tolerance;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], delta = polygon[(i + 1) % polygon.length] - a;
      if (delta.distance < 1e-8) continue;
      final t =
          (ArchitectPolygonGeometry.dot(point - a, delta) /
                  delta.distanceSquared)
              .clamp(0.0, 1.0);
      final distance = (point - a - delta * t).distance;
      if (distance <= best) {
        best = distance;
        hit = i;
      }
    }
    return hit;
  }

  /// The nearest opposite contour edge and the nearest facing external edge.
  /// Walls contribute their finished faces, independent of their reference line.
  static List<ArchitectPolygonDistance> nearest({
    required String elementId,
    required List<Offset> polygon,
    required int edge,
    required ArchitectStorey storey,
  }) {
    if (edge < 0 || edge >= polygon.length) return [];
    final a = polygon[edge], b = polygon[(edge + 1) % polygon.length];
    final length = (b - a).distance;
    if (length < .001) return [];
    final u = (b - a) / length;
    final normal = ArchitectPolygonGeometry.normal(polygon, edge);
    ArchitectPolygonDistance? inside, outside;

    void inspect(String id, List<Offset> contour, bool internal) {
      for (var j = 0; j < contour.length; j++) {
        if (internal && j == edge) continue;
        final c = contour[j], d = contour[(j + 1) % contour.length];
        final delta = d - c;
        if (delta.distance < .001 ||
            ArchitectPolygonGeometry.cross(u, delta / delta.distance).abs() >
                1e-7 ||
            ArchitectPolygonGeometry.dot(
                  normal,
                  ArchitectPolygonGeometry.normal(contour, j),
                ) >
                -.999999) {
          continue;
        }
        final cAlong = ArchitectPolygonGeometry.dot(c - a, u);
        final dAlong = ArchitectPolygonGeometry.dot(d - a, u);
        final low = math.max(0.0, math.min(cAlong, dAlong));
        final high = math.min(length, math.max(cAlong, dAlong));
        if (high - low < .001) continue;
        final signed = ArchitectPolygonGeometry.dot(c - a, normal);
        if (internal ? signed >= -.001 : signed < .001) continue;
        final distance = signed.abs();
        final previous = internal ? inside : outside;
        if (previous != null && previous.distance <= distance) continue;
        final start = a + u * ((low + high) / 2);
        final dimension = ArchitectPolygonDistance(
          referenceId: id,
          referenceEdge: j,
          edge: edge,
          side: internal ? -1 : 1,
          distance: distance,
          start: start,
          end: start + normal * signed,
          normal: normal,
        );
        if (internal) {
          inside = dimension;
        } else {
          outside = dimension;
        }
      }
    }

    inspect(elementId, polygon, true);
    for (final wall in storey.walls) {
      inspect(wall.id, wall.polygonCorners, false);
    }
    for (final slab in storey.slabs) {
      if (slab.id != elementId) inspect(slab.id, slab.polygon, false);
    }
    for (final primitive in storey.cadPrimitives) {
      if (primitive.id != elementId &&
          primitive.type == CadPrimitiveType.rect) {
        inspect(primitive.id, primitive.polygonCorners, false);
      }
    }
    return [if (inside != null) inside!, if (outside != null) outside!];
  }
}
