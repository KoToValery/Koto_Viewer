import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';

/// Plan solids are joined by their physical faces, not by axis position.
class ArchitectWallNetwork {
  static final _cache = Expando<Path>();
  static Path polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static (double, double) _faces(
    ArchitectWall wall,
    Map<String, (double, double)>? faceOffsets,
  ) {
    final offset =
        wall.centerOffset.dx * wall.normalVector.dx +
        wall.centerOffset.dy * wall.normalVector.dy;
    return faceOffsets?[wall.id] ??
        (offset - wall.thickness / 2, offset + wall.thickness / 2);
  }

  static Path body(
    List<ArchitectWall> walls, {
    Map<String, (double, double)>? faceOffsets,
  }) {
    final cached = faceOffsets == null ? _cache[walls] : null;
    if (cached != null) return cached;
    var result = Path();
    for (final wall in walls) {
      if (wall.length < 1e-6) continue;
      final (low, high) = _faces(wall, faceOffsets);
      final n = wall.normalVector;
      result = Path.combine(
        PathOperation.union,
        result,
        polygon([
          wall.startPoint + n * low,
          wall.endPoint + n * low,
          wall.endPoint + n * high,
          wall.startPoint + n * high,
        ]),
      );
    }
    for (final junction in junctions(walls, faceOffsets: faceOffsets)) {
      result = Path.combine(PathOperation.union, result, polygon(junction.$1));
    }
    if (faceOffsets == null) _cache[walls] = result;
    return result;
  }

  /// Convex face intersection closes mitres and end-to-body junctions.
  /// The lower height owns the shared solid when wall heights differ.
  static List<(List<Offset>, double)> junctions(
    List<ArchitectWall> walls, {
    bool solidOnly = false,
    Map<String, (double, double)>? faceOffsets,
  }) {
    final result = <(List<Offset>, double)>[];
    for (var i = 0; i < walls.length; i++) {
      final a = walls[i];
      for (final b in walls.skip(i + 1)) {
        // Only a real finite reference-line junction can extend the bodies.
        final node = intersection(
          a.startPoint,
          a.endPoint,
          b.startPoint,
          b.endPoint,
          finite: true,
        );
        if (node == null) continue;
        if (solidOnly &&
            [a, b].every(
              (w) =>
                  (node - w.startPoint).distance > 1e-8 &&
                  (node - w.endPoint).distance > 1e-8,
            )) {
          continue;
        }
        final points = <Offset>[];
        final fa = _faces(a, faceOffsets), fb = _faces(b, faceOffsets);
        for (final sa in [fa.$1, fa.$2]) {
          for (final sb in [fb.$1, fb.$2]) {
            final p = intersection(
              a.startPoint + a.normalVector * sa,
              a.endPoint + a.normalVector * sa,
              b.startPoint + b.normalVector * sb,
              b.endPoint + b.normalVector * sb,
            );
            if (p != null) points.add(p);
          }
        }
        // Bound acute mitres; avoid long spikes at nearly parallel walls.
        if (points.length != 4) continue;
        // A layer need not contain its reference node (an edge reference may
        // lie in the insulation). Extend its end faces to the shared mitre.
        if (faceOffsets != null) {
          points.addAll([
            node + a.normalVector * fa.$1,
            node + a.normalVector * fa.$2,
            node + b.normalVector * fb.$1,
            node + b.normalVector * fb.$2,
          ]);
          final hull = _hull(points);
          points
            ..clear()
            ..addAll(hull);
        }
        final limit = 4 * math.max(a.thickness, b.thickness);
        if (points.any((p) => (p - node).distance > limit)) {
          final bounded = points
              .where((p) => (p - node).distance <= limit)
              .toList();
          for (final w in [a, b]) {
            final face = _faces(w, faceOffsets);
            bounded.addAll([
              node + w.normalVector * face.$1,
              node + w.normalVector * face.$2,
            ]);
          }
          points.clear();
          points.addAll(_hull(bounded));
        }
        final center =
            points.reduce((a, b) => a + b) / points.length.toDouble();
        // Never fill a hosted door/window cutout with a junction prism.
        if (solidOnly &&
            [a, b].any((w) {
              double along(Offset p) =>
                  (p - w.centerStart).dx * w.unitVector.dx +
                  (p - w.centerStart).dy * w.unitVector.dy;
              final minimum = points.map(along).reduce(math.min);
              final maximum = points.map(along).reduce(math.max);
              return [
                ...w.doors.map((o) => (o.offsetRatio, o.width)),
                ...w.windows.map((o) => (o.offsetRatio, o.width)),
              ].any(
                (o) =>
                    o.$1 * w.length + o.$2 / 2 > minimum &&
                    o.$1 * w.length - o.$2 / 2 < maximum,
              );
            })) {
          continue;
        }
        points.sort(
          (a, b) => math
              .atan2(a.dy - center.dy, a.dx - center.dx)
              .compareTo(math.atan2(b.dy - center.dy, b.dx - center.dx)),
        );
        result.add((points, math.min(a.height, b.height)));
      }
    }
    return result;
  }

  static Offset? intersection(
    Offset a,
    Offset endA,
    Offset b,
    Offset endB, {
    bool finite = false,
  }) {
    final u = endA - a, v = endB - b;
    double cross(Offset x, Offset y) => x.dx * y.dy - x.dy * y.dx;
    final den = cross(u, v);
    if (den.abs() <= 1e-10 * u.distance * v.distance) return null;
    final t = cross(b - a, v) / den, s = cross(b - a, u) / den;
    if (finite && (t < -1e-8 || t > 1 + 1e-8 || s < -1e-8 || s > 1 + 1e-8)) {
      return null;
    }
    return a + u * t;
  }

  static List<Offset> _hull(List<Offset> points) {
    final sorted = points.toSet().toList()
      ..sort(
        (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx),
      );
    if (sorted.length <= 2) return sorted;
    double cross(Offset a, Offset b, Offset c) =>
        (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    List<Offset> half(Iterable<Offset> values) {
      final result = <Offset>[];
      for (final p in values) {
        while (result.length >= 2 &&
            cross(result[result.length - 2], result.last, p) <= 0) {
          result.removeLast();
        }
        result.add(p);
      }
      return result..removeLast();
    }

    return [...half(sorted), ...half(sorted.reversed)];
  }
}
