import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_floor_drain.dart';
import '../models/architect_contour.dart';
import '../rendering/architect_path_solid.dart';

double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
String _key(Offset p) =>
    '${p.dx.toStringAsFixed(5)},${p.dy.toStringAsFixed(5)}';

class ArchitectDrainTriangle {
  final Offset a, b, c;
  final double za, zb, zc;
  const ArchitectDrainTriangle(
    this.a,
    this.b,
    this.c,
    this.za,
    this.zb,
    this.zc,
  );
  double get area => _cross(b - a, c - a).abs() / 2;
  Offset get centre => (a + b + c) / 3;
  Offset get gradient {
    final u = b - a, v = c - a, d = _cross(u, v);
    if (d.abs() < 1e-14) return Offset.zero;
    return Offset(
      ((zb - za) * v.dy - (zc - za) * u.dy) / d,
      (u.dx * (zc - za) - v.dx * (zb - za)) / d,
    );
  }

  double height(Offset p) =>
      za + gradient.dx * (p.dx - a.dx) + gradient.dy * (p.dy - a.dy);
  bool contains(Offset p) {
    final d = _cross(b - a, c - a);
    if (d.abs() < 1e-14) return false;
    final u = _cross(p - a, c - a) / d;
    final v = _cross(b - a, p - a) / d;
    return u >= -1e-7 && v >= -1e-7 && u + v <= 1 + 1e-7;
  }
}

/// A conforming piecewise-planar floor, shared by plan, mesh and section.
/// The grade is sampled only at construction vertices; intermediate heights
/// and arrows come from the actual planes rather than a separate radial field.
class ArchitectDrainSurface {
  final List<ArchitectDrainTriangle> triangles;
  final List<(Offset, Offset)> folds;
  final List<(Offset, Offset)> boundary;
  final bool drainsContinuously;
  const ArchitectDrainSurface(
    this.triangles,
    this.folds,
    this.boundary,
    this.drainsContinuously,
  );
  static final _cache = Expando<ArchitectDrainSurface>();
  static ArchitectDrainSurface of(ArchitectFloorDrain drain) =>
      _cache[drain] ??= _build(drain);

  double? heightAt(Offset p) {
    for (final t in triangles) {
      if (t.contains(p)) return math.max(0, t.height(p));
    }
    return null;
  }

  Offset? downhill(Offset p) {
    for (final t in triangles) {
      if (t.contains(p)) {
        final g = t.gradient;
        return g.distance < 1e-10 ? null : -g / g.distance;
      }
    }
    return null;
  }

  /// Continuous cut segments, in the same plan coordinates as the surface.
  List<(Offset, Offset, double, double)> section(Offset a, Offset b) {
    final result = <(Offset, Offset, double, double)>[];
    final d = b - a;
    for (final t in triangles) {
      final hits = <double>[];
      if (t.contains(a)) hits.add(0);
      if (t.contains(b)) hits.add(1);
      for (final (p, q) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        final v = q - p, det = _cross(d, v);
        if (det.abs() < 1e-12) continue;
        final u = _cross(p - a, v) / det, w = _cross(p - a, d) / det;
        if (u >= -1e-8 && u <= 1 + 1e-8 && w >= -1e-8 && w <= 1 + 1e-8)
          hits.add(u.clamp(0, 1));
      }
      if (hits.length < 2) continue;
      hits.sort();
      final p = a + d * hits.first, q = a + d * hits.last;
      if ((q - p).distance > 1e-7) result.add((p, q, t.height(p), t.height(q)));
    }
    return result;
  }

  static List<Offset> grate(ArchitectFloorDrain d) {
    if (!d.isLinear)
      return [
        for (var i = 0; i < 24; i++)
          d.position +
              Offset(math.cos(i * math.pi / 12), math.sin(i * math.pi / 12)) *
                  d.halfWidth,
      ];
    final u = d.axisDirection, n = Offset(-u.dy, u.dx);
    final (a, b) = d.axis;
    return [
      a - n * d.halfWidth,
      b - n * d.halfWidth,
      b + n * d.halfWidth,
      a + n * d.halfWidth,
    ];
  }

  static ArchitectDrainSurface _build(ArchitectFloorDrain d) {
    if (d.polygon.length < 3)
      return const ArchitectDrainSurface([], [], [], false);
    double grade(Offset p) {
      final (a, b) = d.axis;
      final ab = b - a;
      final u = ab.distanceSquared < 1e-12
          ? 0.0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
                .clamp(0.0, 1.0);
      return math.max(0.0, (p - a - ab * u).distance - d.halfWidth) *
          d.slopePercent /
          100;
    }

    Offset nearest(Offset p) {
      final (a, b) = d.axis;
      final ab = b - a;
      if (ab.distanceSquared < 1e-12) return a;
      final u = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
          .clamp(0.0, 1.0);
      return a + ab * u;
    }

    final floor = ArchitectContour.path(d.polygon, d.holes);
    final gratePath = Path()..addPolygon(grate(d), true);
    final domain = Path.combine(PathOperation.difference, floor, gratePath);
    final cells = <ArchitectDrainTriangle>[];
    var fallback = false;
    var covered = Path();
    var overlap = false;
    void cell(Offset a, Offset b, Offset c) {
      if (_cross(b - a, c - a).abs() < 1e-10) return;
      final raw = Path()..addPolygon([a, b, c], true);
      final clipped = Path.combine(PathOperation.intersect, raw, domain);
      final intersection = Path.combine(
        PathOperation.intersect,
        clipped,
        covered,
      );
      if (ArchitectPathSolid.contours(
        intersection,
      ).any((r) => ArchitectContour.area([r]) > 1e-7))
        overlap = true;
      final unique = Path.combine(PathOperation.difference, clipped, covered);
      final plane = ArchitectDrainTriangle(
        a,
        b,
        c,
        grade(a),
        grade(b),
        grade(c),
      );
      for (final (p, q, r) in ArchitectPathSolid.triangulateContours(
        ArchitectPathSolid.contours(unique),
        fillType: PathFillType.evenOdd,
      )) {
        cells.add(
          ArchitectDrainTriangle(
            p,
            q,
            r,
            plane.height(p),
            plane.height(q),
            plane.height(r),
          ),
        );
      }
      covered = Path.combine(PathOperation.union, covered, clipped);
    }

    for (var i = 0; i < d.polygon.length; i++) {
      final a = d.polygon[i], b = d.polygon[(i + 1) % d.polygon.length];
      final p = nearest(a), q = nearest(b);
      cell(p, a, b);
      cell(p, b, q);
    }
    final missing = Path.combine(PathOperation.difference, domain, covered);
    final missingLoops = ArchitectPathSolid.contours(missing);
    if (overlap || missingLoops.any((r) => ArchitectContour.area([r]) > 1e-7)) {
      // Concave outlines and islands require triangulation of the actual domain.
      // Never fan across a wall or bridge an opening.
      fallback = true;
      cells.clear();
      for (final (a, b, c) in ArchitectPathSolid.triangulateContours(
        ArchitectPathSolid.contours(domain),
        fillType: PathFillType.evenOdd,
      )) {
        cells.add(
          ArchitectDrainTriangle(a, b, c, grade(a), grade(b), grade(c)),
        );
      }
    }
    // Split T junctions before assigning elevations, so both sides of each seam
    // contain identical vertices and interpolate identical shared edges.
    final vertices = <String, Offset>{};
    for (final t in cells) {
      for (final p in [t.a, t.b, t.c]) {
        vertices[_key(p)] = p;
      }
    }
    final triangles = <ArchitectDrainTriangle>[];
    void triangle(
      Offset a,
      Offset b,
      Offset c,
      double za,
      double zb,
      double zc,
    ) {
      final t = ArchitectDrainTriangle(a, b, c, za, zb, zc);
      final longest = math.max(
        (a - b).distance,
        math.max((b - c).distance, (c - a).distance),
      );
      if (t.area > 1e-10 && 2 * t.area / longest > 1e-6) triangles.add(t);
    }

    for (final original in cells) {
      final a = original.a, b = original.b, c = original.c;
      double zAt(Offset p) => fallback ? grade(p) : original.height(p);
      final ring = <Offset>[];
      for (final (p, q) in [(a, b), (b, c), (c, a)]) {
        final v = q - p, len = v.distanceSquared;
        final nodes =
            vertices.values.where((r) {
              final t = ((r - p).dx * v.dx + (r - p).dy * v.dy) / len;
              return t > 1e-7 &&
                  t < 1 - 1e-7 &&
                  _cross(r - p, v).abs() < 1e-7 * v.distance;
            }).toList()..sort(
              (x, y) =>
                  ((x - p).distanceSquared).compareTo((y - p).distanceSquared),
            );
        ring.add(p);
        for (final node in nodes) {
          if ((ring.last - node).distance > 1e-7 && (node - q).distance > 1e-7)
            ring.add(node);
        }
      }
      if (ring.length == 3) {
        triangle(a, b, c, zAt(a), zAt(b), zAt(c));
        continue;
      }
      final centre = (a + b + c) / 3;
      final z = original.height(centre);
      for (var i = 0; i < ring.length; i++) {
        final p = ring[i], q = ring[(i + 1) % ring.length];
        triangle(centre, p, q, z, zAt(p), zAt(q));
      }
    }
    final edges = <String, List<(ArchitectDrainTriangle, Offset, Offset)>>{};
    for (final t in triangles) {
      for (final (a, b) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        final keys = [_key(a), _key(b)]..sort();
        if (keys.first == keys.last) continue;
        (edges[keys.join('/')] ??= []).add((t, a, b));
      }
    }
    final folds = <(Offset, Offset)>[], boundary = <(Offset, Offset)>[];
    var valid = triangles.isNotEmpty;
    for (final e in edges.values) {
      if (e.length == 1) {
        boundary.add((e.first.$2, e.first.$3));
      } else if (e.length == 2) {
        if ((e[0].$1.gradient - e[1].$1.gradient).distance > 1e-6)
          folds.add((e.first.$2, e.first.$3));
      } else {
        valid = false;
      }
    }
    // Flat patches away from the outlet cannot honestly claim drainage.
    if (triangles.any((t) => t.gradient.distance < 1e-8 && t.za > 1e-5))
      valid = false;
    // A descending edge path must exist from every construction vertex to the
    // grate. This also catches isolated basins behind concave edges or islands.
    final graph = <String, Set<String>>{},
        levels = <String, double>{},
        nodes = <String, Offset>{};
    for (final t in triangles) {
      for (final (p, z) in [(t.a, t.za), (t.b, t.zb), (t.c, t.zc)]) {
        final key = _key(p);
        nodes[key] = p;
        levels[key] = math.min(levels[key] ?? z, z);
      }
      for (final (a, b) in [(t.a, t.b), (t.b, t.c), (t.c, t.a)]) {
        final ka = _key(a), kb = _key(b);
        (graph[ka] ??= {}).add(kb);
        (graph[kb] ??= {}).add(ka);
      }
    }
    final grateRing = grate(d);
    double distanceToEdge(Offset p, Offset a, Offset b) {
      final v = b - a;
      final t = (((p - a).dx * v.dx + (p - a).dy * v.dy) / v.distanceSquared)
          .clamp(0.0, 1.0);
      return (p - a - v * t).distance;
    }

    final reached = <String>{};
    final queue = <String>[];
    for (final entry in nodes.entries) {
      if (gratePath.contains(entry.value) ||
          List.generate(
            grateRing.length,
            (i) => distanceToEdge(
              entry.value,
              grateRing[i],
              grateRing[(i + 1) % grateRing.length],
            ),
          ).any((v) => v < 2e-5)) {
        reached.add(entry.key);
        queue.add(entry.key);
      }
    }
    for (var i = 0; i < queue.length; i++) {
      final current = queue[i];
      for (final neighbor in graph[current] ?? <String>{}) {
        if (!reached.contains(neighbor) &&
            levels[neighbor]! >= levels[current]! - 1e-7) {
          reached.add(neighbor);
          queue.add(neighbor);
        }
      }
    }
    if (reached.length != nodes.length) valid = false;
    return ArchitectDrainSurface(
      List.unmodifiable(triangles),
      List.unmodifiable(folds),
      List.unmodifiable(boundary),
      valid,
    );
  }
}
