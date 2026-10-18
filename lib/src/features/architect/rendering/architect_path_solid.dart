import 'dart:math' as math;
import 'dart:ui';
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
        if (depth >= 28 ||
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
    Color color,
  ) {
    if (top - bottom < 1e-8) return const [];
    return between(path, (_) => bottom, (_) => top, color);
  }

  static List<Triangle3D> between(
    Path path,
    double Function(Offset) bottom,
    double Function(Offset) top,
    Color color,
  ) {
    final loops = contours(path), tris = <Triangle3D>[];
    final edges = <(Offset, Offset)>[];
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
      for (var i = 0; i < loop.length; i++) {
        final a = loop[i], b = loop[(i + 1) % loop.length];
        edges.add((a, b));
        final d = b - a, n = Offset(-d.dy, d.dx) / d.distance;
        final insideLeft = path.contains((a + b) / 2 + n * .0000001);
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
        if (!path.contains(Offset(mid, (y(low, mid) + y(high, mid)) / 2))) {
          continue;
        }
        final a = Offset(x0, y(low, x0)),
            b = Offset(x1, y(low, x1)),
            c = Offset(x1, y(high, x1)),
            d = Offset(x0, y(high, x0));
        for (final z in [bottom, top]) {
          triangle(a, b, c, z, reverse: z == bottom);
          triangle(a, c, d, z, reverse: z == bottom);
        }
      }
    }
    return tris;
  }
}
