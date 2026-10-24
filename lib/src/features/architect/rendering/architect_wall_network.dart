import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_wall.dart';
import 'architect_path_solid.dart';

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
    final juncs = junctions(walls, faceOffsets: faceOffsets);
    var result = Path();
    for (final wall in walls) {
      if (wall.length < 1e-6) continue;
      final (low, high) = _faces(wall, faceOffsets);
      var from = 0.0;
      var to = 1.0;
      if (faceOffsets != null && !wall.isCurved) {
        for (final other in walls) {
          if (other == wall || other.isCurved) continue;
          final node = intersection(
            wall.startPoint,
            wall.endPoint,
            other.startPoint,
            other.endPoint,
          );
          if (node == null) continue;
          final isStart = (node - wall.startPoint).distance < 1e-4;
          final isEnd = (node - wall.endPoint).distance < 1e-4;
          if (!isStart && !isEnd) continue;

          final fa = _faces(wall, faceOffsets), fb = _faces(other, faceOffsets);
          final juncPoints = <Offset>[];
          for (final sa in [fa.$1, fa.$2]) {
            for (final sb in [fb.$1, fb.$2]) {
              final p = intersection(
                wall.startPoint + wall.normalVector * sa,
                wall.endPoint + wall.normalVector * sa,
                other.startPoint + other.normalVector * sb,
                other.endPoint + other.normalVector * sb,
              );
              if (p != null) juncPoints.add(p);
            }
          }
          if (juncPoints.length != 4) continue;
          double along(Offset p) {
            final d = p - wall.startPoint;
            return d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
          }

          final alongs = juncPoints.map(along).toList();
          final minP = alongs.reduce(math.min);
          final maxP = alongs.reduce(math.max);
          if (isEnd && wall.length > maxP + 1e-4) {
            to = math.min(to, (maxP / wall.length).clamp(0.0, 1.0));
          }
          if (isStart && 0 < minP - 1e-4) {
            from = math.max(from, (minP / wall.length).clamp(0.0, 1.0));
          }
        }
      }
      result = Path.combine(
        PathOperation.union,
        result,
        polygon(wall.facePolygon(low, high, from: from, to: to)),
      );
    }
    for (final junction in juncs) {
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
        if (a.isCurved || b.isCurved) {
          final nodes = a.intersections(b);
          // An endpoint on a face still joins even if the saved references differ.
          for (final p in [a.startPoint, a.endPoint]) {
            if (b.containsPoint(p, tolerance: .0001) &&
                !nodes.any((n) => (n - p).distance < .0001)) {
              nodes.add(p);
            }
          }
          for (final p in [b.startPoint, b.endPoint]) {
            if (a.containsPoint(p, tolerance: .0001) &&
                !nodes.any((n) => (n - p).distance < .0001)) {
              nodes.add(p);
            }
          }
          for (final node in nodes) {
            if (!a.connectsAt(node) || !b.connectsAt(node)) continue;
            final fa = _faces(a, faceOffsets), fb = _faces(b, faceOffsets);
            final reach = math.max(a.thickness, b.thickness) * 3;
            Path extended(ArchitectWall w, (double, double) faces) {
              final extra = math.min(reach / w.length, .3);
              return polygon(
                w.facePolygon(faces.$1, faces.$2, from: -extra, to: 1 + extra),
              );
            }

            final joint = Path.combine(
              PathOperation.intersect,
              Path.combine(
                PathOperation.intersect,
                extended(a, fa),
                extended(b, fb),
              ),
              Path()..addRect(Rect.fromCircle(center: node, radius: reach)),
            );
            for (final contour in ArchitectPathSolid.contours(joint)) {
              result.add((contour, math.min(a.height, b.height)));
            }
          }
          continue;
        }
        final node = intersection(
          a.startPoint,
          a.endPoint,
          b.startPoint,
          b.endPoint,
        );
        if (node == null || !a.connectsAt(node) || !b.connectsAt(node)) {
          continue;
        }
        bool inside(ArchitectWall wall, Offset p) {
          final d = p - wall.centerStart;
          final along = d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
          final across =
              (d.dx * wall.normalVector.dx + d.dy * wall.normalVector.dy).abs();
          return wall.connectsAt(p) &&
              along >= -1e-8 &&
              along <= wall.length + 1e-8 &&
              across <= wall.thickness / 2 + 1e-8;
        }

        final finiteNode = intersection(
          a.startPoint,
          a.endPoint,
          b.startPoint,
          b.endPoint,
          finite: true,
        );
        if (finiteNode == null &&
            ![
              if (a.connectStart) (a.startPoint, b),
              if (a.connectEnd) (a.endPoint, b),
              if (b.connectStart) (b.startPoint, a),
              if (b.connectEnd) (b.endPoint, a),
            ].any((contact) => inside(contact.$2, contact.$1))) {
          continue;
        }
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
          for (final wall in [a, b]) {
            double along(Offset p) {
              final d = p - wall.startPoint;
              return d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
            }

            final alongs = points.map(along).toList();
            final minP = alongs.reduce(math.min);
            final maxP = alongs.reduce(math.max);
            final face = _faces(wall, faceOffsets);
            if (wall.length < minP - 1e-8) {
              final cap = wall.endPoint;
              points.addAll([
                cap + wall.normalVector * face.$1,
                cap + wall.normalVector * face.$2,
              ]);
            } else if (0 > maxP + 1e-8) {
              final cap = wall.startPoint;
              points.addAll([
                cap + wall.normalVector * face.$1,
                cap + wall.normalVector * face.$2,
              ]);
            }
          }
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
    return BimLineGeometry.intersection(
      a,
      endA,
      b,
      endB,
      firstFinite: finite,
      secondFinite: finite,
    );
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
