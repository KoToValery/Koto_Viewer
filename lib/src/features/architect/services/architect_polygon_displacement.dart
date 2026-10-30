import 'dart:ui';

import 'architect_polygon_geometry.dart';

/// A drag fixes the direction; keypad values always refer to its original path.
class ArchitectPolygonDisplacement {
  ArchitectPolygonDisplacement._({
    required this.polygon,
    required this.index,
    required this.edge,
    required this.mode,
    required this.origin,
    required this.direction,
    required this.distance,
  });

  final List<Offset> polygon;
  final int index;
  final bool edge;
  final ArchitectPolygonEdgeMode mode;
  final Offset origin, direction;
  final double distance;

  static ArchitectPolygonDisplacement? fromDrag({
    required List<Offset> polygon,
    required int index,
    required bool edge,
    required Offset target,
    required ArchitectPolygonEdgeMode mode,
  }) {
    if (index < 0 ||
        index >= polygon.length ||
        !ArchitectPolygonGeometry.valid(polygon)) {
      return null;
    }
    final origin = edge
        ? (polygon[index] + polygon[(index + 1) % polygon.length]) / 2
        : polygon[index];
    final delta = target - origin;
    if (!delta.distance.isFinite ||
        delta.distance <= ArchitectPolygonGeometry.epsilon) {
      return null;
    }
    final direction = edge
        ? ArchitectPolygonGeometry.normal(polygon, index)
        : delta / delta.distance;
    final distance = edge
        ? ArchitectPolygonGeometry.dot(delta, direction)
        : delta.distance;
    if (distance.abs() <= ArchitectPolygonGeometry.epsilon) return null;
    return ArchitectPolygonDisplacement._(
      polygon: List.unmodifiable(polygon),
      index: index,
      edge: edge,
      mode: mode,
      origin: origin,
      direction: direction,
      distance: distance,
    );
  }

  Offset target(double meters) => origin + direction * meters;

  List<Offset>? atDistance(double meters) {
    if (!meters.isFinite) return null;
    if (meters.abs() <= ArchitectPolygonGeometry.epsilon) {
      return List.of(polygon);
    }
    return edge
        ? ArchitectPolygonGeometry.offsetEdge(
            polygon,
            index,
            meters,
            mode: mode,
          )
        : ArchitectPolygonGeometry.moveVertex(polygon, index, target(meters));
  }
}
