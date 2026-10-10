import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import 'slab_topology_analyzer.dart';
import 'structural_polygon_distance.dart';

class SlabContactMeasure {
  final double areaM2;
  final double projectedLengthM;
  final Offset centroidCad;
  const SlabContactMeasure(
    this.areaM2,
    this.projectedLengthM,
    this.centroidCad,
  );
}

/// Positive-area contact with the union of slab polygons minus their openings.
/// Sweep breakpoints include all edge intersections, so linear polygon edges
/// are integrated exactly (up to floating-point roundoff), without raster cells.
/// Contact is geometric evidence only, not proof of force-transfer capacity.
class SlabContactGeometry {
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static List<(double, double)> _union(List<(double, double)> intervals) {
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    final result = <(double, double)>[];
    for (final interval in intervals) {
      if (result.isEmpty || interval.$1 > result.last.$2) {
        result.add(interval);
      } else {
        result[result.length - 1] = (
          result.last.$1,
          math.max(result.last.$2, interval.$2),
        );
      }
    }
    return result;
  }

  static List<(double, double)> _slice(List<Offset> ring, double x) {
    final ys = <double>[];
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      if ((a.dx > x) != (b.dx > x)) {
        ys.add(a.dy + (b.dy - a.dy) * (x - a.dx) / (b.dx - a.dx));
      }
    }
    ys.sort();
    return [for (var i = 0; i + 1 < ys.length; i += 2) (ys[i], ys[i + 1])];
  }

  static List<(double, double)> _subtract(
    List<(double, double)> base,
    List<(double, double)> holes,
  ) {
    var result = base;
    for (final hole in holes) {
      final next = <(double, double)>[];
      for (final a in result) {
        if (hole.$2 <= a.$1 || hole.$1 >= a.$2) {
          next.add(a);
          continue;
        }
        if (hole.$1 > a.$1) next.add((a.$1, hole.$1));
        if (hole.$2 < a.$2) next.add((hole.$2, a.$2));
      }
      result = next;
    }
    return result;
  }

  static List<Offset> columnFootprint(StructuralColumn column) {
    if (column.shape != ColumnShape.circular) return column.polygonVertices;
    // Rendering uses 12 sides; use a much finer inscribed contact approximation.
    return [
      for (var i = 0; i < 256; i++)
        column.center +
            Offset(
                  math.cos(2 * math.pi * i / 256),
                  math.sin(2 * math.pi * i / 256),
                ) *
                column.width /
                2,
    ];
  }

  static SlabContactMeasure? columnContact(
    StructuralColumn column,
    List<StructuralSlab> slabs,
    double scale,
  ) {
    if (column.width <= 0 ||
        column.height <= 0 ||
        (column.shape == ColumnShape.lShape &&
            (column.thickness <= 0 ||
                column.thickness >= math.min(column.width, column.height)))) {
      return null;
    }
    // A full circle strictly inside one valid plate has exact area/centroid.
    // Reserve polygon sweeping and bracketing for partial/ambiguous contact.
    if (column.shape == ColumnShape.circular &&
        slabs.length == 1 &&
        scale.isFinite &&
        scale > 0 &&
        column.width.isFinite &&
        SlabTopologyAnalyzer.analyze(slabs, scale).allowsSingleDiaphragm) {
      final slab = slabs.single, radius = column.width / 2;
      final rings = [slab.polygon, ...slab.openings];
      final contained =
          StructuralPolygonDistance.inside(column.center, slab.polygon) &&
          !slab.openings.any(
            (h) => StructuralPolygonDistance.inside(column.center, h),
          ) &&
          rings.every(
            (ring) => List.generate(
              ring.length,
              (i) =>
                  StructuralPolygonDistance.pointToSegment(
                    column.center,
                    ring[i],
                    ring[(i + 1) % ring.length],
                  ) >
                  radius + 1e-8 * scale,
            ).every((v) => v),
          );
      if (contained) {
        return SlabContactMeasure(
          math.pi * radius * radius / (scale * scale),
          2 * radius / scale,
          column.center,
        );
      }
    }
    final result = measure(columnFootprint(column), slabs, scale);
    if (result == null ||
        result.areaM2 > 1e-10 ||
        column.shape != ColumnShape.circular) {
      return result;
    }
    // Bracket circular contact between inscribed/circumscribed 256-gons.
    // Ambiguous boundary slivers are unevaluated, not silently disconnected.
    final outside = measure(
      columnFootprint(
        column.copyWith(width: column.width / math.cos(math.pi / 256)),
      ),
      slabs,
      scale,
    );
    return outside == null || outside.areaM2 > 1e-10 ? null : result;
  }

  static SlabContactMeasure? measure(
    List<Offset> footprint,
    List<StructuralSlab> slabs,
    double scale, {
    Offset direction = const Offset(1, 0),
  }) {
    if (footprint.length < 3 ||
        !scale.isFinite ||
        scale <= 0 ||
        direction.distance == 0) {
      return null;
    }
    final origin = footprint.first, u = direction / direction.distance;
    final v = Offset(-u.dy, u.dx);
    Offset local(Offset p) {
      final d = (p - origin) / scale;
      return Offset(d.dx * u.dx + d.dy * u.dy, d.dx * v.dx + d.dy * v.dy);
    }

    final support = footprint.map(local).toList();
    if (support.any((p) => !p.dx.isFinite || !p.dy.isFinite)) return null;
    final lo = support.map((p) => p.dx).reduce(math.min),
        hi = support.map((p) => p.dx).reduce(math.max);
    final floor = <List<List<Offset>>>[];
    for (final slab in slabs) {
      if (slab.polygon.length < 3) return null;
      final rings = [
        slab.polygon,
        ...slab.openings,
      ].map((r) => r.map(local).toList()).toList();
      if (rings.any(
        (r) => r.length < 3 || r.any((p) => !p.dx.isFinite || !p.dy.isFinite),
      )) {
        return null;
      }
      final minX = rings.first.map((p) => p.dx).reduce(math.min);
      final maxX = rings.first.map((p) => p.dx).reduce(math.max);
      if (maxX > lo && minX < hi) floor.add(rings);
    }
    final rings = [support, ...floor.expand((s) => s)];
    final edges = <(Offset, Offset, int)>[];
    final cuts = <double>{lo, hi};
    if (rings.fold<int>(0, (n, r) => n + r.length) > 2400) return null;
    for (var ringIndex = 0; ringIndex < rings.length; ringIndex++) {
      final ring = rings[ringIndex];
      double signedArea = 0;
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i], b = ring[(i + 1) % ring.length];
        signedArea += _cross(a - ring.first, b - ring.first);
        if (a.dx > lo && a.dx < hi) cuts.add(a.dx);
        if (math.max(a.dx, b.dx) >= lo && math.min(a.dx, b.dx) <= hi) {
          edges.add((a, b, ringIndex));
        }
      }
      if (signedArea.abs() < 1e-12) return null;
    }
    if (edges.length > 1200) return null;
    for (var i = 0; i < edges.length; i++) {
      final (a, b, owner) = edges[i];
      final d = b - a;
      for (var j = i + 1; j < edges.length; j++) {
        final (c, e, other) = edges[j];
        final f = e - c;
        final den = _cross(d, f);
        if (den.abs() < 1e-14 * d.distance * f.distance || den == 0) continue;
        final t = _cross(c - a, f) / den, s = _cross(c - a, d) / den;
        if (t > 0 && t < 1 && s > 0 && s < 1) {
          if (owner == other &&
              t > 1e-10 &&
              t < 1 - 1e-10 &&
              s > 1e-10 &&
              s < 1 - 1e-10) {
            return null;
          }
          final x = a.dx + d.dx * t;
          if (x > lo && x < hi) cuts.add(x);
        }
      }
    }
    List<(double, double)> contact(double x) {
      final intervals = <(double, double)>[];
      for (final slab in floor) {
        intervals.addAll(
          _subtract(
            _slice(slab.first, x),
            _union(slab.skip(1).expand((r) => _slice(r, x)).toList()),
          ),
        );
      }
      final merged = _union(intervals), result = <(double, double)>[];
      for (final a in _slice(support, x)) {
        for (final b in merged) {
          final lower = math.max(a.$1, b.$1), upper = math.min(a.$2, b.$2);
          if (upper > lower) result.add((lower, upper));
        }
      }
      return _union(result);
    }

    final xs = cuts.toList()..sort();
    if (xs.length > 4096 || xs.length * edges.length > 2000000) return null;
    double area = 0, mx = 0, my = 0, length = 0;
    for (var i = 1; i < xs.length; i++) {
      final width = xs[i] - xs[i - 1];
      if (width <= 1e-10) continue;
      final middle = (xs[i] + xs[i - 1]) / 2;
      if (contact(middle).any((r) => r.$2 - r.$1 > 1e-10)) length += width;
      for (final sign in [-1, 1]) {
        final x = middle + sign * width / (2 * math.sqrt(3));
        for (final r in contact(x)) {
          final h = r.$2 - r.$1, weight = width / 2;
          area += h * weight;
          mx += x * h * weight;
          my += (r.$2 * r.$2 - r.$1 * r.$1) / 2 * weight;
        }
      }
    }
    return SlabContactMeasure(
      area,
      length,
      area > 1e-12
          ? origin + (u * (mx / area) + v * (my / area)) * scale
          : origin,
    );
  }
}
