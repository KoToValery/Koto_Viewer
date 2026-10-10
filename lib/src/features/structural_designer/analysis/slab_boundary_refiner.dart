import 'dart:math' as math;
import 'dart:ui';

/// Raster cells decide topology only. Final edges lie on footprint support
/// lines, and corners are their intersections, with no cell-size offset.
class SlabBoundaryRefiner {
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double _distance(Offset p, Offset a, Offset b) {
    final d = b - a;
    if (d.distanceSquared == 0) return (p - a).distance;
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared)
        .clamp(0.0, 1.0);
    return (p - a - d * t).distance;
  }

  static List<Offset>? refine(
    List<Offset> raster,
    List<List<Offset>> footprints,
    double cell,
    double scale, {
    Set<String>? diagnostics,
  }) {
    final edges = <(Offset, Offset)>[];
    for (final polygon in footprints) {
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i], b = polygon[(i + 1) % polygon.length];
        if ((b - a).distance > scale * 0.01) edges.add((a, b));
      }
    }
    // Prefer a long face over a short mitre at equal endpoint distance.
    edges.sort(
      (a, b) => (b.$2 - b.$1).distanceSquared.compareTo(
        (a.$2 - a.$1).distanceSquared,
      ),
    );
    bool same(int i, int j) {
      final a = edges[i],
          b = edges[j],
          u = (a.$2 - a.$1) / (a.$2 - a.$1).distance,
          v = (b.$2 - b.$1) / (b.$2 - b.$1).distance;
      return _cross(u, v).abs() < 1e-3 &&
          _cross(b.$1 - a.$1, u).abs() <= math.max(0.5 * cell, 25.0 * scale);
    }

    final runs = <(int, int)>[];
    var comparisons = 0;
    for (var i = 0; i < raster.length; i++) {
      final mid = (raster[i] + raster[(i + 1) % raster.length]) / 2;
      var selected = -1, best = double.infinity;
      for (var j = 0; j < edges.length; j++) {
        if (++comparisons > 8000000) return null;
        final e = edges[j];
        if (mid.dx < math.min(e.$1.dx, e.$2.dx) - 2 * cell ||
            mid.dx > math.max(e.$1.dx, e.$2.dx) + 2 * cell ||
            mid.dy < math.min(e.$1.dy, e.$2.dy) - 2 * cell ||
            mid.dy > math.max(e.$1.dy, e.$2.dy) + 2 * cell) {
          continue;
        }
        final distance = _distance(mid, e.$1, e.$2);
        if (distance < best - scale * 0.001) {
          best = distance;
          selected = j;
        }
      }
      if (selected < 0 || best > 2 * cell) return null;
      if (runs.isEmpty || !same(runs.last.$1, selected)) {
        runs.add((selected, i));
      }
    }
    // Merge any adjacent collinear runs (including wrap-around)
    var changed = true;
    while (changed && runs.length > 2) {
      changed = false;
      for (var i = 0; i < runs.length; i++) {
        final nextIdx = (i + 1) % runs.length;
        if (same(runs[i].$1, runs[nextIdx].$1)) {
          runs.removeAt(nextIdx);
          changed = true;
          break;
        }
      }
    }
    // Merge any consecutive runs that are parallel so denominator won't collapse
    var changedParallel = true;
    while (changedParallel && runs.length > 2) {
      changedParallel = false;
      for (var i = 0; i < runs.length; i++) {
        final nextIdx = (i + 1) % runs.length;
        final e1 = edges[runs[i].$1];
        final e2 = edges[runs[nextIdx].$1];
        final u = e1.$2 - e1.$1;
        final v = e2.$2 - e2.$1;
        if (_cross(u, v).abs() < 1e-4 * u.distance * v.distance) {
          runs.removeAt(nextIdx);
          changedParallel = true;
          break;
        }
      }
    }
    if (runs.length < 3 || runs.length > 2000) return null;
    var result = <Offset>[];
    for (var i = 0; i < runs.length; i++) {
      final previous = edges[runs[(i + runs.length - 1) % runs.length].$1],
          current = edges[runs[i].$1];
      final u = previous.$2 - previous.$1, v = current.$2 - current.$1;
      final denominator = _cross(u, v);
      if (denominator.abs() < 1e-9 * u.distance * v.distance) return null;
      final intersection =
          previous.$1 + u * (_cross(current.$1 - previous.$1, v) / denominator);
      // A raster run starts where nearest-face ownership changes, not at
      // the exact corner. At a mitre this transition is farther from the
      // intersection than at a right angle. Bound by the intersection angle
      // and still require the corner to lie close to the local raster boundary.
      final cosine =
          (u.dx * v.dx + u.dy * v.dy).abs() / (u.distance * v.distance);
      final sinHalf = math.sqrt((1 - cosine.clamp(0.0, 1.0)) / 2);
      final allowance = math.min(
        10 * cell,
        math.max(3 * cell, 2 * cell / sinHalf),
      );
      final transition = runs[i].$2;
      if ((intersection - raster[transition]).distance > allowance) return null;
      final reach = (allowance / cell).ceil() + 2;
      var boundaryDistance = double.infinity;
      for (var k = -reach; k <= reach; k++) {
        final index = (transition + k) % raster.length;
        boundaryDistance = math.min(
          boundaryDistance,
          _distance(
            intersection,
            raster[index],
            raster[(index + 1) % raster.length],
          ),
        );
      }
      if (boundaryDistance > allowance) return null;
      result.add(intersection);
    }
    // Cell padding can attach an exterior column or wall spur at one vertex.
    // Keep the actual slab region, excluding only a sub-minimum lobe whose
    // exact source boundary has a point contact. Larger contacts stay unresolved.
    // Coincident intersections can arise from quantized KCAD support lines.
    // Remove only numerically zero-length edges before checking topology.
    final epsilon = .00001 * scale;
    final cleaned = <Offset>[];
    for (final p in result) {
      if (cleaned.isEmpty || (p - cleaned.last).distance > epsilon) {
        cleaned.add(p);
      }
    }
    if (cleaned.length > 1 &&
        (cleaned.first - cleaned.last).distance <= epsilon) {
      cleaned.removeLast();
    }
    final pruned = _removePointContactArtifacts(cleaned, scale);
    if (pruned == null) return null;
    if (pruned.length != cleaned.length) {
      diagnostics?.add('discardedPointContactArtifacts');
    }
    result = pruned;
    return _simple(result, scale) ? result : null;
  }

  static double _area(List<Offset> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      sum += _cross(
        ring[i] - ring.first,
        ring[(i + 1) % ring.length] - ring.first,
      );
    }
    return sum.abs() / 2;
  }

  static List<Offset>? _removePointContactArtifacts(
    List<Offset> ring,
    double scale,
  ) {
    final epsilon = .00001 * scale;
    var result = ring;
    while (true) {
      var changed = false;
      for (var i = 0; i < result.length && !changed; i++) {
        for (var j = i + 2; j < result.length; j++) {
          if (i == 0 && j == result.length - 1) continue;
          if ((result[i] - result[j]).distance > epsilon) continue;
          final a = result.sublist(i, j);
          final b = [...result.sublist(j), ...result.sublist(0, i)];
          if (a.length < 3 || b.length < 3) return null;
          final areaA = _area(a), areaB = _area(b);
          // Match the raster stage's 1 m² minimum enclosed region.
          if (math.min(areaA, areaB) >= 1000000 * scale * scale) return null;
          result = areaA > areaB ? a : b;
          changed = true;
          break;
        }
      }
      if (!changed) return result;
    }
  }

  static bool _simple(List<Offset> result, double scale) {
    final epsilon = .00001 * scale;
    if (result.length < 3 || _area(result) <= epsilon * epsilon) return false;
    for (var i = 0; i < result.length; i++) {
      final a = result[i], b = result[(i + 1) % result.length], u = b - a;
      final next = result[(i + 2) % result.length];
      if (u.distance < epsilon ||
          _distance(next, a, b) <= epsilon ||
          _distance(a, b, next) <= epsilon) {
        return false;
      }
      for (var j = i + 2; j < result.length; j++) {
        if (i == 0 && j == result.length - 1) continue;
        final c = result[j], d = result[(j + 1) % result.length], v = d - c;
        if ([
          _distance(a, c, d),
          _distance(b, c, d),
          _distance(c, a, b),
          _distance(d, a, b),
        ].any((d) => d <= epsilon)) {
          return false;
        }
        final denominator = _cross(u, v);
        if (denominator.abs() < 1e-9 * u.distance * v.distance) continue;
        final t = _cross(c - a, v) / denominator,
            s = _cross(c - a, u) / denominator;
        if (t >= 0 && t <= 1 && s >= 0 && s <= 1) return false;
      }
    }
    return true;
  }
}
