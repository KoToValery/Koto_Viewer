import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';

/// Snap point type for CAD snapping.
enum DxfSnapType {
  endpoint(label: 'Endpoint'),
  midpoint(label: 'Midpoint'),
  center(label: 'Center'),
  point(label: 'Point');

  final String label;
  const DxfSnapType({required this.label});
}

/// Result of a CAD snap query.
class DxfSnapResult {
  final Offset point;
  final DxfSnapType type;
  final double distance;

  const DxfSnapResult({
    required this.point,
    required this.type,
    required this.distance,
  });
}

/// High-performance spatial helper to snap CAD cursor to geometric vertices and landmarks.
class DxfSnapHelper {
  const DxfSnapHelper._();

  /// Searches for the closest CAD vertex/landmark within [toleranceCad] distance of [cadPoint].
  static DxfSnapResult? findSnapPoint({
    required DxfDocument document,
    required Offset cadPoint,
    required double toleranceCad,
  }) {
    if (toleranceCad <= 0) return null;

    DxfSnapResult? bestSnap;
    double minDistanceSq = toleranceCad * toleranceCad;

    void testPoint(Offset p, DxfSnapType type) {
      final dx = p.dx - cadPoint.dx;
      final dy = p.dy - cadPoint.dy;
      final distSq = dx * dx + dy * dy;

      if (distSq <= minDistanceSq) {
        minDistanceSq = distSq;
        bestSnap = DxfSnapResult(
          point: p,
          type: type,
          distance: math.sqrt(distSq),
        );
      }
    }

    // Iterate through all visible entities
    for (final entity in document.entities) {
      final layer = document.layers[entity.layer];
      if (layer != null && !layer.isVisible) continue;

      if (entity is DxfLine) {
        testPoint(entity.p1, DxfSnapType.endpoint);
        testPoint(entity.p2, DxfSnapType.endpoint);
        testPoint(Offset((entity.p1.dx + entity.p2.dx) / 2, (entity.p1.dy + entity.p2.dy) / 2), DxfSnapType.midpoint);
      } else if (entity is DxfPoint) {
        testPoint(entity.point, DxfSnapType.point);
      } else if (entity is DxfCircle) {
        testPoint(entity.center, DxfSnapType.center);
      } else if (entity is DxfArc) {
        testPoint(entity.center, DxfSnapType.center);
        final rad1 = entity.startAngleDeg * math.pi / 180.0;
        final rad2 = entity.endAngleDeg * math.pi / 180.0;
        final pStart = Offset(entity.center.dx + entity.radius * math.cos(rad1), entity.center.dy + entity.radius * math.sin(rad1));
        final pEnd = Offset(entity.center.dx + entity.radius * math.cos(rad2), entity.center.dy + entity.radius * math.sin(rad2));
        testPoint(pStart, DxfSnapType.endpoint);
        testPoint(pEnd, DxfSnapType.endpoint);
      } else if (entity is DxfEllipse) {
        testPoint(entity.center, DxfSnapType.center);
      } else if (entity is DxfLwPolyline) {
        final vertices = entity.vertices;
        final count = vertices.length;
        for (int i = 0; i < count; i++) {
          final v1 = vertices[i];
          testPoint(v1.offset, DxfSnapType.endpoint);

          if (i + 1 < count || entity.isClosed) {
            final v2 = vertices[(i + 1) % count];
            testPoint(Offset((v1.x + v2.x) / 2, (v1.y + v2.y) / 2), DxfSnapType.midpoint);
          }
        }
      } else if (entity is DxfPolyline) {
        final vertices = entity.vertices;
        final count = vertices.length;
        for (int i = 0; i < count; i++) {
          final v1 = vertices[i];
          testPoint(v1.offset, DxfSnapType.endpoint);

          if (i + 1 < count || entity.isClosed) {
            final v2 = vertices[(i + 1) % count];
            testPoint(Offset((v1.x + v2.x) / 2, (v1.y + v2.y) / 2), DxfSnapType.midpoint);
          }
        }
      } else if (entity is DxfSpline) {
        for (final p in entity.controlPoints) {
          testPoint(p, DxfSnapType.endpoint);
        }
        for (final p in entity.fitPoints) {
          testPoint(p, DxfSnapType.endpoint);
        }
      } else if (entity is DxfSolid) {
        testPoint(entity.p0, DxfSnapType.endpoint);
        testPoint(entity.p1, DxfSnapType.endpoint);
        testPoint(entity.p2, DxfSnapType.endpoint);
        testPoint(entity.p3, DxfSnapType.endpoint);
      } else if (entity is DxfLeader) {
        for (final p in entity.vertices) {
          testPoint(p, DxfSnapType.endpoint);
        }
      } else if (entity is DxfInsert) {
        testPoint(entity.insertPoint, DxfSnapType.point);
      }
    }

    return bestSnap;
  }
}
