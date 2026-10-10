import 'dart:math' as math;
import 'dart:ui';
import '../models/dxf_models.dart';

/// Local straight CAD geometry, including visible, transformed block children.
class DxfSegmentSnap {
  static List<(Offset, Offset)> nearby({
    required DxfDocument document,
    required Offset point,
    required double radius,
    bool continuousOnly = false,
  }) {
    if (!radius.isFinite || radius <= 0) return [];
    final query = Rect.fromCircle(center: point, radius: radius);
    final result = <(Offset, Offset)>[];
    var visited = 0, tested = 0;
    void add(Offset a, Offset b) {
      if (++tested > 8000 ||
          result.length >= 256 ||
          (b - a).distanceSquared < 1e-18) {
        return;
      }
      final d = b - a;
      final t =
          (((point - a).dx * d.dx + (point - a).dy * d.dy) / d.distanceSquared)
              .clamp(0.0, 1.0);
      if ((point - a - d * t).distance <= radius) result.add((a, b));
    }

    void visit(
      DxfEntity e,
      Offset Function(Offset) transform,
      String inheritedLayer,
      String inheritedType,
      int depth,
    ) {
      if (++visited > 8000 ||
          depth > 8 ||
          result.length >= 256 ||
          e.isPaperSpace) {
        return;
      }
      final layer = e.layer == '0' ? inheritedLayer : e.layer;
      if (document.layers[layer]?.isVisible == false) {
        return;
      }
      var type = (e.lineType ?? 'BYLAYER').toUpperCase();
      if (type == 'BYBLOCK') type = inheritedType;
      if (type == 'BYLAYER') {
        type = (document.layers[layer]?.lineType ?? 'CONTINUOUS').toUpperCase();
      }
      if (e is DxfInsert) {
        final block = document.blocks[e.blockName];
        if (block == null) return;
        final angle = e.rotationDeg * math.pi / 180;
        Offset child(Offset p) {
          final local = p - block.basePoint;
          final x = local.dx * e.scaleX, y = local.dy * e.scaleY;
          return transform(
            e.insertPoint +
                Offset(
                  x * math.cos(angle) - y * math.sin(angle),
                  x * math.sin(angle) + y * math.cos(angle),
                ),
          );
        }

        for (final entity in block.entities) {
          visit(entity, child, layer, type, depth + 1);
        }
        return;
      }
      if (continuousOnly && type != 'CONTINUOUS' && type.isNotEmpty) {
        return;
      }
      if (e is DxfLine) {
        add(transform(e.p1), transform(e.p2));
      } else if (e is DxfLwPolyline || e is DxfPolyline) {
        final (vertices, closed) = e is DxfLwPolyline
            ? (e.vertices, e.isClosed)
            : ((e as DxfPolyline).vertices, e.isClosed);
        final count = vertices.length - (closed ? 0 : 1);
        for (
          var i = 0;
          i < count && tested < 8000 && result.length < 256;
          i++
        ) {
          final a = vertices[i], b = vertices[(i + 1) % vertices.length];
          if (a.bulge.abs() < 1e-10) {
            add(transform(a.offset), transform(b.offset));
          }
        }
      }
    }

    final entities =
        document.spatialIndex?.query(query) ??
        document.layoutEntities['Model'] ??
        document.entities;
    for (final e in entities) {
      visit(e, (p) => p, '0', 'CONTINUOUS', 0);
    }
    return result;
  }

  /// Finite segment intersections; parallel lines and extensions do not snap.
  static Offset? intersection((Offset, Offset) first, (Offset, Offset) second) {
    final a = first.$1, b = second.$1, u = first.$2 - a, v = second.$2 - b;
    double cross(Offset x, Offset y) => x.dx * y.dy - x.dy * y.dx;
    final den = cross(u, v);
    if (den.abs() <= 1e-10 * u.distance * v.distance) return null;
    final t = cross(b - a, v) / den, s = cross(b - a, u) / den;
    if (t < -1e-9 || t > 1 + 1e-9 || s < -1e-9 || s > 1 + 1e-9) return null;
    return a + u * t;
  }

  static Offset? nearestIntersection({
    required DxfDocument document,
    required Offset point,
    required double tolerance,
  }) {
    final segments = nearby(
      document: document,
      point: point,
      radius: tolerance,
    );
    Offset? result;
    var best = tolerance;
    for (var i = 0; i < segments.length; i++) {
      for (var j = i + 1; j < segments.length; j++) {
        final p = intersection(segments[i], segments[j]);
        if (p == null) continue;
        final distance = (p - point).distance;
        if (distance <= best) {
          best = distance;
          result = p;
        }
      }
    }
    return result;
  }
}
