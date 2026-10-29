import 'dart:math' as math;
import 'dart:ui';
import 'package:clipper2/clipper2.dart' as clip;
import '../../dxf_3d_viewer/models/mesh_3d.dart';

/// Extrudes boolean-clean paths, including holes and disconnected contours.
/// Vertical decomposition avoids bridging a hole with an arbitrary diagonal.
class ArchitectPathSolid {
  static List<List<Offset>> contours(Path path, {double tolerance = .000001}) {
    final result = <List<Offset>>[];
    for (final metric in path.computeMetrics()) {
      final points = <Offset>[];
      Offset at(double s) => metric.getTangentForOffset(s)!.position;
      void flatten(double a, double b, int depth) {
        final p = at(a), q = at(b), delta = q - p;
        final length = delta.distance;
        double error(Offset r) => length < 1e-12
            ? (r - p).distance
            : ((r - p).dx * delta.dy - (r - p).dy * delta.dx).abs() / length;
        final samples = [
          at(a + (b - a) * .25),
          at((a + b) / 2),
          at(a + (b - a) * .75),
        ];
        if (depth >= 14 ||
            ((b - a - length).abs() < tolerance &&
                samples.every((r) => error(r) < tolerance))) {
          points.add(p);
          return;
        }
        final ta = metric.getTangentForOffset(a)!,
            tb = metric.getTangentForOffset(b)!;
        final cross = ta.vector.dx * tb.vector.dy - ta.vector.dy * tb.vector.dx;
        if (cross.abs() > 1e-9) {
          final d = q - p;
          final along = (d.dx * tb.vector.dy - d.dy * tb.vector.dx) / cross;
          final corner = p + ta.vector * along;
          Offset predicted(double distance) => distance <= along
              ? p + ta.vector * distance
              : corner + tb.vector * (distance - along);
          if (along >= 0 &&
              ((corner - p).distance + (q - corner).distance - (b - a)).abs() <
                  tolerance &&
              [
                for (var k = 0; k < 3; k++)
                  (samples[k] - predicted((b - a) * (k + 1) / 4)).distance,
              ].every((e) => e < tolerance)) {
            points.addAll([p, corner]);
            return;
          }
        }
        final m = (a + b) / 2;
        flatten(a, m, depth + 1);
        flatten(m, b, depth + 1);
      }

      flatten(0, metric.length, 0);
      points.add(at(metric.length));
      final clean = <Offset>[];
      for (final p in points) {
        if (clean.isEmpty || (p - clean.last).distance > tolerance) {
          clean.add(p);
        }
        while (clean.length >= 3) {
          final a = clean[clean.length - 3],
              b = clean[clean.length - 2],
              c = clean.last;
          final ab = b - a, bc = c - b;
          if ((ab.dx * bc.dy - ab.dy * bc.dx).abs() >
                  tolerance * math.max(ab.distance, bc.distance) ||
              ab.dx * bc.dx + ab.dy * bc.dy < 0) {
            break;
          }
          clean.removeAt(clean.length - 2);
        }
      }
      if (clean.length > 1 && (clean.last - clean.first).distance < tolerance) {
        clean.removeLast();
      }
      if (clean.length >= 3) result.add(clean);
    }
    return result;
  }

  static List<Triangle3D> extrude(
    Path path,
    double bottom,
    double top,
    Color color, {
    double contourTolerance = .000001,
    bool compactCaps = false,
  }) {
    if (top - bottom < 1e-8) return const [];
    return between(
      path,
      (_) => bottom,
      (_) => top,
      color,
      contourTolerance: contourTolerance,
      compactCaps: compactCaps,
    );
  }

  static List<Triangle3D> between(
    Path path,
    double Function(Offset) bottom,
    double Function(Offset) top,
    Color color, {
    double contourTolerance = .000001,
    bool compactCaps = false,
  }) {
    final loops = contours(path, tolerance: contourTolerance),
        tris = <Triangle3D>[];
    Vector3 v(Offset p, double z) => Vector3(p.dx, p.dy, z);
    void triangle(
      Offset a,
      Offset b,
      Offset c,
      double Function(Offset) z, {
      bool reverse = false,
    }) {
      final cross = (b - a).dx * (c - a).dy - (b - a).dy * (c - a).dx;
      if (cross.abs() < 1e-12) return;
      final flip = (cross < 0) != reverse;
      tris.add(
        Triangle3D(
          v0: v(a, z(a)),
          v1: v(flip ? c : b, z(flip ? c : b)),
          v2: v(flip ? b : c, z(flip ? b : c)),
          color: color,
        ),
      );
    }

    for (final loop in loops) {
      // Determine orientation in double precision. Path.contains stores its
      // probe as float32: a sub-micron probe can round onto the edge and flip
      // a wall face inward, especially away from the model origin.
      final edge = loop[1] - loop[0];
      final probe =
          (loop[0] + loop[1]) / 2 +
          Offset(-edge.dy, edge.dx) / edge.distance * .0000001;
      final insideLeft = _contains(loops, probe, path.fillType);
      for (var i = 0; i < loop.length; i++) {
        final a = loop[i], b = loop[(i + 1) % loop.length];
        final p = insideLeft ? a : b, q = insideLeft ? b : a;
        tris.add(
          Triangle3D(
            v0: v(p, bottom(p)),
            v1: v(q, bottom(q)),
            v2: v(q, top(q)),
            color: color,
          ),
        );
        tris.add(
          Triangle3D(
            v0: v(p, bottom(p)),
            v1: v(q, top(q)),
            v2: v(p, top(p)),
            color: color,
          ),
        );
      }
    }
    // A simple end face needs n-2 triangles. Vertical decomposition inserts a
    // strip at every X coordinate and multiplies the caps of notched logs.
    // Keep the existing hole-aware decomposition for compound contours.
    for (final (a, b, c) in triangulateContours(
      loops,
      fillType: path.fillType,
      compact: compactCaps,
    )) {
      triangle(a, b, c, bottom, reverse: true);
      triangle(a, b, c, top);
    }
    return tris;
  }

  /// Pure double-precision cap triangulation, also safe in a worker isolate.
  /// Unlike a temporary Flutter Path, this preserves coplanar mesh seams.
  static List<(Offset, Offset, Offset)> triangulateContours(
    List<List<Offset>> loops, {
    PathFillType fillType = PathFillType.nonZero,
    bool compact = true,
  }) {
    // Clipper can retain repeated or almost collinear seam vertices. Remove
    // those in double precision before ear clipping, as Path contours do.
    if (compact) {
      loops = [
        for (final loop in loops) _cleanContour(loop),
      ].where((loop) => loop.length >= 3).toList();
    }
    // Canonical winding distinguishes holes from disconnected outer contours,
    // including even-odd holes whose input winding matches their parent.
    if (compact && loops.length > 1) {
      final engine = clip.ClipperD(roundingDecimalPrecision: 7)
        ..preserveCollinear = false
        ..addSubjects([
          for (final loop in loops)
            [for (final p in loop) clip.PointD(p.dx, p.dy)],
        ]);
      final normalized = engine.executeClosed(
        clip.ClipType.union,
        fillType == PathFillType.evenOdd
            ? clip.FillRule.evenOdd
            : clip.FillRule.nonZero,
      );
      if (normalized == null) throw StateError('Construction cap union failed');
      loops = [
        for (final loop in normalized)
          _cleanContour([for (final p in loop) Offset(p.x, p.y)]),
      ].where((loop) => loop.length >= 3).toList();
      fillType = PathFillType.nonZero;
    }
    double area(List<Offset> loop) {
      var value = 0.0;
      for (var i = 1; i + 1 < loop.length; i++) {
        final a = loop[i] - loop.first, b = loop[i + 1] - loop.first;
        value += a.dx * b.dy - a.dy * b.dx;
      }
      return value;
    }

    // Disconnected contours do not need strips through every other member.
    if (compact &&
        loops.isNotEmpty &&
        loops.every((loop) => area(loop).sign == area(loops.first).sign)) {
      final caps = [for (final loop in loops) _triangulate(loop)];
      if (caps.every((cap) => cap != null)) {
        return [for (final cap in caps) ...cap!];
      }
    }
    final edges = <(Offset, Offset)>[
      for (final loop in loops)
        for (var i = 0; i < loop.length; i++)
          (loop[i], loop[(i + 1) % loop.length]),
    ];
    final result = <(Offset, Offset, Offset)>[];
    void triangle(Offset a, Offset b, Offset c) {
      final ab = b - a, ac = c - a;
      final cross = ab.dx * ac.dy - ab.dy * ac.dx;
      if (cross.abs() >= 1e-12) {
        result.add(cross > 0 ? (a, b, c) : (a, c, b));
      }
    }

    final xs = edges.expand((e) => [e.$1.dx, e.$2.dx]).toSet().toList()..sort();
    for (var i = 0; i + 1 < xs.length; i++) {
      final x0 = xs[i], x1 = xs[i + 1], mid = (x0 + x1) / 2;
      if (x1 - x0 < 1e-9) continue;
      double y((Offset, Offset) e, double x) =>
          e.$1.dy + (e.$2.dy - e.$1.dy) * (x - e.$1.dx) / (e.$2.dx - e.$1.dx);
      final crossing =
          edges
              .where(
                (e) =>
                    mid > math.min(e.$1.dx, e.$2.dx) &&
                    mid < math.max(e.$1.dx, e.$2.dx),
              )
              .toList()
            ..sort((a, b) => y(a, mid).compareTo(y(b, mid)));
      for (var j = 0; j + 1 < crossing.length; j++) {
        final low = crossing[j], high = crossing[j + 1];
        if (!_contains(
          loops,
          Offset(mid, (y(low, mid) + y(high, mid)) / 2),
          fillType,
        )) {
          continue;
        }
        final a = Offset(x0, y(low, x0)),
            b = Offset(x1, y(low, x1)),
            c = Offset(x1, y(high, x1)),
            d = Offset(x0, y(high, x0));
        triangle(a, b, c);
        triangle(a, c, d);
      }
    }
    return result;
  }

  static List<Offset> _cleanContour(List<Offset> loop) {
    const tolerance = 1e-7;
    final clean = <Offset>[];
    for (final p in loop) {
      if (clean.isEmpty || (p - clean.last).distance > tolerance) clean.add(p);
    }
    if (clean.length > 1 && (clean.first - clean.last).distance < tolerance) {
      clean.removeLast();
    }
    var changed = true;
    while (changed && clean.length > 3) {
      changed = false;
      for (var i = 0; i < clean.length; i++) {
        final a = clean[(i + clean.length - 1) % clean.length],
            b = clean[i],
            c = clean[(i + 1) % clean.length];
        final ab = b - a, bc = c - b;
        if ((ab.dx * bc.dy - ab.dy * bc.dx).abs() <=
                tolerance * math.max(ab.distance, bc.distance) &&
            ab.dx * bc.dx + ab.dy * bc.dy >= 0) {
          clean.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return clean;
  }

  static List<(Offset, Offset, Offset)>? _triangulate(List<Offset> polygon) {
    if (polygon.length < 3 || polygon.length > 1024) return null;
    double cross(Offset a, Offset b, Offset c) =>
        (b - a).dx * (c - a).dy - (b - a).dy * (c - a).dx;
    var area = 0.0;
    for (var i = 1; i + 1 < polygon.length; i++) {
      area += cross(polygon.first, polygon[i], polygon[i + 1]);
    }
    if (area.abs() < 1e-12) return null;
    final ids = List<int>.generate(polygon.length, (i) => i);
    if (area < 0) ids.setAll(0, ids.reversed.toList());
    final result = <(Offset, Offset, Offset)>[];
    while (ids.length > 3) {
      var found = false;
      for (var i = 0; i < ids.length; i++) {
        final ia = ids[(i + ids.length - 1) % ids.length],
            ib = ids[i],
            ic = ids[(i + 1) % ids.length];
        final a = polygon[ia], b = polygon[ib], c = polygon[ic];
        if (cross(a, b, c) <= 1e-12) continue;
        if (ids.any(
          (id) =>
              id != ia &&
              id != ib &&
              id != ic &&
              cross(a, b, polygon[id]) >= -1e-12 &&
              cross(b, c, polygon[id]) >= -1e-12 &&
              cross(c, a, polygon[id]) >= -1e-12,
        )) {
          continue;
        }
        result.add((a, b, c));
        ids.removeAt(i);
        found = true;
        break;
      }
      if (!found) return null;
    }
    result.add((polygon[ids[0]], polygon[ids[1]], polygon[ids[2]]));
    final covered = result.fold<double>(
      0,
      (sum, t) => sum + cross(t.$1, t.$2, t.$3).abs(),
    );
    if ((covered - area.abs()).abs() > math.max(1e-10, area.abs() * 1e-7)) {
      return null;
    }
    return result;
  }

  static bool _contains(
    List<List<Offset>> loops,
    Offset point,
    PathFillType fillType,
  ) {
    var winding = 0;
    for (final loop in loops) {
      for (var i = 0; i < loop.length; i++) {
        final a = loop[i], b = loop[(i + 1) % loop.length];
        final cross =
            (b.dx - a.dx) * (point.dy - a.dy) -
            (b.dy - a.dy) * (point.dx - a.dx);
        if (a.dy <= point.dy && b.dy > point.dy && cross > 0) winding++;
        if (a.dy > point.dy && b.dy <= point.dy && cross < 0) winding--;
      }
    }
    return fillType == PathFillType.evenOdd ? winding.isOdd : winding != 0;
  }
}
