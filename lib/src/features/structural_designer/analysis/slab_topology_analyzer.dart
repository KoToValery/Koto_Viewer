import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/slab_topology.dart';
import 'slab_contact_geometry.dart';
import 'structural_polygon_distance.dart';

/// Conservative precondition for the single-diaphragm mass/stiffness model.
/// Openings must be strictly inside, simple and mutually disjoint. A common
/// edge joins slab regions geometrically; point contacts and gaps do not.
/// Connection detailing, narrow necks and diaphragm flexibility need analysis.
class SlabTopologyAnalyzer {
  static const _eps = 1e-8; // metres; numerical tolerance, not a snap distance
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  static double _edgeDistance(Offset a, Offset b, Offset c, Offset d) {
    final u = b - a, v = d - c, den = _cross(u, v);
    if (den != 0) {
      final t = _cross(c - a, v) / den, s = _cross(c - a, u) / den;
      if (t >= 0 && t <= 1 && s >= 0 && s <= 1) return 0;
    }
    return [
      StructuralPolygonDistance.pointToSegment(a, c, d),
      StructuralPolygonDistance.pointToSegment(b, c, d),
      StructuralPolygonDistance.pointToSegment(c, a, b),
      StructuralPolygonDistance.pointToSegment(d, a, b),
    ].reduce(math.min);
  }

  static bool _boundariesTouch(List<Offset> a, List<Offset> b) {
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        if (_edgeDistance(
              a[i],
              a[(i + 1) % a.length],
              b[j],
              b[(j + 1) % b.length],
            ) <=
            _eps) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _simple(List<Offset> r) {
    if (r.length < 3 || r.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      return false;
    }
    double twiceArea = 0;
    for (var i = 0; i < r.length; i++) {
      final a = r[i], b = r[(i + 1) % r.length], c = r[(i + 2) % r.length];
      if ((b - a).distance <= _eps) return false;
      // Reject backtracking adjacent edges, but allow collinear forward vertices.
      if (StructuralPolygonDistance.pointToSegment(c, a, b) <= _eps ||
          StructuralPolygonDistance.pointToSegment(a, b, c) <= _eps) {
        return false;
      }
      twiceArea += _cross(a - r.first, b - r.first);
      for (var j = i + 1; j < r.length; j++) {
        if (j == i + 1 || (i == 0 && j == r.length - 1)) continue;
        if (_edgeDistance(a, b, r[j], r[(j + 1) % r.length]) <= _eps) {
          return false;
        }
      }
    }
    return twiceArea.abs() > 1e-10;
  }

  static bool _commonEdge(List<Offset> a, List<Offset> b) {
    for (var i = 0; i < a.length; i++) {
      final p = a[i], u = a[(i + 1) % a.length] - p, length = u.distance;
      final axis = u / length;
      for (var j = 0; j < b.length; j++) {
        final c = b[j] - p, d = b[(j + 1) % b.length] - p;
        if (_cross(axis, c).abs() > _eps || _cross(axis, d).abs() > _eps) {
          continue;
        }
        final x = c.dx * axis.dx + c.dy * axis.dy,
            y = d.dx * axis.dx + d.dy * axis.dy;
        if (math.min(length, math.max(x, y)) - math.max(0, math.min(x, y)) >
            _eps) {
          return true;
        }
      }
    }
    return false;
  }

  static SlabTopology analyze(List<StructuralSlab> slabs, double scale) {
    const invalid = SlabTopology(SlabTopologyIssue.invalidGeometry, 0);
    const limit = SlabTopology(SlabTopologyIssue.computationLimit, 0);
    if (!scale.isFinite || scale <= 0) return invalid;
    if (slabs.isEmpty) return const SlabTopology(SlabTopologyIssue.none, 0);
    if (slabs.length > 100 ||
        slabs.fold<int>(
              0,
              (n, s) =>
                  n +
                  s.polygon.length +
                  s.openings.fold<int>(0, (m, r) => m + r.length),
            ) >
            1200) {
      return limit;
    }
    if (slabs.first.polygon.isEmpty) return invalid;
    final origin = slabs.first.polygon.first;
    List<Offset> local(List<Offset> r) {
      final points = r.map((p) => (p - origin) / scale).toList();
      // Explicit closing vertex is a common valid CAD representation.
      if (points.length > 1 && (points.first - points.last).distance <= _eps) {
        points.removeLast();
      }
      return points;
    }

    final floors = <StructuralSlab>[];
    for (final slab in slabs) {
      final outer = local(slab.polygon),
          holes = slab.openings.map(local).toList();
      if (!_simple(outer)) return invalid;
      for (var i = 0; i < holes.length; i++) {
        final hole = holes[i];
        if (!_simple(hole) ||
            !StructuralPolygonDistance.inside(hole.first, outer) ||
            _boundariesTouch(hole, outer)) {
          return invalid;
        }
        for (var j = 0; j < i; j++) {
          if (StructuralPolygonDistance.between(hole, holes[j]) <= _eps) {
            return invalid;
          }
        }
      }
      floors.add(StructuralSlab(id: slab.id, polygon: outer, openings: holes));
    }
    final parents = List.generate(floors.length, (i) => i);
    int root(int i) {
      while (parents[i] != i) {
        i = parents[i];
      }
      return i;
    }

    for (var i = 0; i < floors.length; i++) {
      for (var j = 0; j < i; j++) {
        final a = floors[i], b = floors[j];
        final outer = SlabContactGeometry.measure(a.polygon, [b], 1);
        if (outer == null) return limit;
        var overlap = outer.areaM2;
        for (final hole in a.openings) {
          final cut = SlabContactGeometry.measure(hole, [b], 1);
          if (cut == null) return limit;
          overlap -= cut.areaM2;
        }
        if (overlap > 1e-10) {
          return const SlabTopology(SlabTopologyIssue.overlappingSlabs, 0);
        }
        // Include hole edges: an infill slab can share their boundary.
        final joined = [a.polygon, ...a.openings].any(
          (ra) => [b.polygon, ...b.openings].any((rb) => _commonEdge(ra, rb)),
        );
        if (joined) parents[root(i)] = root(j);
      }
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < floors.length; i++) {
      groups.putIfAbsent(root(i), () => []).add(i);
    }
    final regions = groups.values.map((r) => List<int>.unmodifiable(r)).toList();
    final count = regions.length;
    return SlabTopology(
      count > 1 ? SlabTopologyIssue.separateRegions : SlabTopologyIssue.none,
      count,
      regions: List.unmodifiable(regions),
    );
  }
}
