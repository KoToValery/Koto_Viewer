import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/slab_topology.dart';
import '../analysis/slab_topology_analyzer.dart';

/// Parallel edge correction. Positive distances expand the selected ring.
/// Exact shared edges move atomically; ambiguous partial junctions are rejected.
class SlabEdgeOffset {
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double _area(List<Offset> p) {
    var result = 0.0;
    for (var i = 0; i < p.length; i++) {
      result += _cross(p[i] - p.first, p[(i + 1) % p.length] - p.first);
    }
    return result / 2;
  }

  static List<StructuralSlab>? move({
    required List<StructuralSlab> slabs,
    required String slabId,
    required int edge,
    required double metres,
    required double scale,
  }) {
    if (!metres.isFinite || !scale.isFinite || scale <= 0) return null;
    final index = slabs.indexWhere((s) => s.id == slabId);
    if (index < 0 || slabs.where((s) => s.id == slabId).length != 1) {
      return null;
    }
    final p = slabs[index].polygon;
    if (p.length < 3 || edge < 0 || edge >= p.length) return null;
    final tolerance = 1e-8 * scale;
    final a = p[edge], b = p[(edge + 1) % p.length], u = b - a;
    if (u.distance <= tolerance) return null;
    final unit = u / u.distance;
    final shift =
        Offset(unit.dy, -unit.dx) * (metres * scale * (_area(p) > 0 ? 1 : -1));
    final targets = <int, int>{index: edge};
    for (var k = 0; k < slabs.length; k++) {
      if (k == index) continue;
      final q = slabs[k].polygon;
      for (var j = 0; j < q.length; j++) {
        final c = q[j], d = q[(j + 1) % q.length];
        if (_cross(unit, c - a).abs() > tolerance ||
            _cross(unit, d - a).abs() > tolerance) {
          continue;
        }
        final x = (c - a).dx * unit.dx + (c - a).dy * unit.dy;
        final y = (d - a).dx * unit.dx + (d - a).dy * unit.dy;
        if (math.min(u.distance, math.max(x, y)) -
                math.max(0, math.min(x, y)) <=
            tolerance) {
          continue;
        }
        final same =
            (a - c).distance <= tolerance && (b - d).distance <= tolerance;
        final reverse =
            (a - d).distance <= tolerance && (b - c).distance <= tolerance;
        if ((!same && !reverse) || targets.containsKey(k)) return null;
        targets[k] = j;
      }
    }
    final before = SlabTopologyAnalyzer.analyze(slabs, scale);
    if (before.issue != SlabTopologyIssue.none &&
        before.issue != SlabTopologyIssue.separateRegions) {
      return null;
    }
    final result = List<StructuralSlab>.of(slabs);
    for (final entry in targets.entries) {
      final source = slabs[entry.key];
      final q = List<Offset>.of(source.polygon);
      final j = entry.value, next = (j + 1) % q.length;
      final prev = q[(j + q.length - 1) % q.length];
      final after = q[(j + 2) % q.length];
      Offset? intersect(Offset origin, Offset direction) {
        final den = _cross(direction, unit);
        if (den.abs() <= 1e-10 * direction.distance) return null;
        return origin + direction * (_cross(a + shift - origin, unit) / den);
      }

      final start = intersect(prev, q[j] - prev);
      final end = intersect(after, q[next] - after);
      if (start == null || end == null) return null;
      // Do not move a corner shared with an edge outside this transaction.
      for (var k = 0; k < slabs.length; k++) {
        if (targets.containsKey(k)) continue;
        for (final corner in slabs[k].polygon) {
          if ((corner - q[j]).distance <= tolerance ||
              (corner - q[next]).distance <= tolerance) {
            return null;
          }
        }
      }
      q[j] = start;
      q[next] = end;
      if (_area(q) * _area(source.polygon) <= 0) return null;
      result[entry.key] = source.copyWith(polygon: q);
    }
    // Both owners must still have precisely the same complete common edge.
    for (final entry in targets.entries) {
      if (entry.key == index) continue;
      final main = result[index].polygon, other = result[entry.key].polygon;
      final x = main[edge], y = main[(edge + 1) % main.length];
      final c = other[entry.value], d = other[(entry.value + 1) % other.length];
      if (!(((x - c).distance <= tolerance && (y - d).distance <= tolerance) ||
          ((x - d).distance <= tolerance && (y - c).distance <= tolerance))) {
        return null;
      }
    }
    final topology = SlabTopologyAnalyzer.analyze(result, scale);
    if (topology.issue != SlabTopologyIssue.none &&
        topology.issue != SlabTopologyIssue.separateRegions) {
      return null;
    }
    // Do not silently disconnect another boundary of a moved slab.
    for (final region in before.regions) {
      if (!topology.regions.any((after) => region.every(after.contains))) {
        return null;
      }
    }
    return result;
  }
}
