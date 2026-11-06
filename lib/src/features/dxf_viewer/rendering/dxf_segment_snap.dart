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
    Map<String, bool> layerVisibility = const {},
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
      if (document.layers[layer]?.isVisible == false ||
          layerVisibility[layer] == false) {
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

  /// Infinite line intersection between two segments that do not physically touch.
  /// Returns null if parallel, coincident, or if the intersection is already finite on both segments.
  static ({Offset point, (Offset, Offset)? guide1, (Offset, Offset)? guide2})?
      extendedIntersection(
    (Offset, Offset) first,
    (Offset, Offset) second, {
    double maxExtension = 25.0,
  }) {
    final a = first.$1, b = second.$1, u = first.$2 - a, v = second.$2 - b;
    double cross(Offset x, Offset y) => x.dx * y.dy - x.dy * y.dx;
    final den = cross(u, v);
    final lenU = u.distance;
    final lenV = v.distance;
    if (lenU < 1e-6 || lenV < 1e-6 || den.abs() <= 1e-4 * lenU * lenV) {
      return null;
    }
    final t = cross(b - a, v) / den;
    final s = cross(b - a, u) / den;

    final onFirst = t >= -1e-5 && t <= 1 + 1e-5;
    final onSecond = s >= -1e-5 && s <= 1 + 1e-5;
    if (onFirst && onSecond) return null;

    final pt = a + u * t;

    final distToFirst = onFirst
        ? 0.0
        : (t < 0 ? (pt - a).distance : (pt - first.$2).distance);
    final distToSecond = onSecond
        ? 0.0
        : (s < 0 ? (pt - b).distance : (pt - second.$2).distance);

    if (distToFirst > maxExtension || distToSecond > maxExtension) {
      return null;
    }

    final guide1 = onFirst ? null : (t < 0 ? (a, pt) : (first.$2, pt));
    final guide2 = onSecond ? null : (s < 0 ? (b, pt) : (second.$2, pt));

    return (point: pt, guide1: guide1, guide2: guide2);
  }

  static ({Offset point, (Offset, Offset)? guide1, (Offset, Offset)? guide2})?
      nearestExtendedIntersection({
    required DxfDocument document,
    required Offset point,
    required double tolerance,
    double? maxExtension,
    Map<String, bool> layerVisibility = const {},
  }) {
    final effectiveMaxExt = maxExtension ?? math.max(25.0, tolerance * 15.0);
    final segments = nearby(
      document: document,
      point: point,
      radius: effectiveMaxExt,
      layerVisibility: layerVisibility,
    );
    ({Offset point, (Offset, Offset)? guide1, (Offset, Offset)? guide2})? result;
    var best = tolerance;
    for (var i = 0; i < segments.length; i++) {
      final s1 = segments[i];
      final u = s1.$2 - s1.$1;
      final lenSq1 = u.dx * u.dx + u.dy * u.dy;
      if (lenSq1 < 1e-8) continue;
      final cross1 =
          ((point.dx - s1.$1.dx) * u.dy - (point.dy - s1.$1.dy) * u.dx).abs();
      if (cross1 * cross1 > tolerance * tolerance * lenSq1) continue;

      for (var j = i + 1; j < segments.length; j++) {
        final s2 = segments[j];
        final v = s2.$2 - s2.$1;
        final lenSq2 = v.dx * v.dx + v.dy * v.dy;
        if (lenSq2 < 1e-8) continue;
        final cross2 =
            ((point.dx - s2.$1.dx) * v.dy - (point.dy - s2.$1.dy) * v.dx).abs();
        if (cross2 * cross2 > tolerance * tolerance * lenSq2) continue;

        final ext = extendedIntersection(s1, s2, maxExtension: effectiveMaxExt);
        if (ext == null) continue;
        final distance = (ext.point - point).distance;
        if (distance <= best) {
          best = distance;
          result = ext;
        }
      }
    }
    return result;
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
