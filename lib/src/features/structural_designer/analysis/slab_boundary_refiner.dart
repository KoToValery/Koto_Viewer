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
    double scale,
  ) {
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
      return _cross(u, v).abs() < 1e-4 &&
          _cross(b.$1 - a.$1, u).abs() < 0.1 * scale;
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
    if (runs.length < 3 || runs.length > 2000) return null;
    final result = <Offset>[];
    for (var i = 0; i < runs.length; i++) {
      final previous = edges[runs[(i + runs.length - 1) % runs.length].$1],
          current = edges[runs[i].$1];
      final u = previous.$2 - previous.$1, v = current.$2 - current.$1;
      final denominator = _cross(u, v);
      if (denominator.abs() < 1e-9 * u.distance * v.distance) return null;
      final intersection =
          previous.$1 + u * (_cross(current.$1 - previous.$1, v) / denominator);
      if ((intersection - raster[runs[i].$2]).distance > 3 * cell) return null;
      result.add(intersection);
    }
    // Reject collapsed edges and new intersections rather than emit a shifted
    // or topologically different approximation.
    for (var i = 0; i < result.length; i++) {
      final a = result[i], b = result[(i + 1) % result.length], u = b - a;
      if (u.distance < 0.01 * scale) return null;
      for (var j = i + 2; j < result.length; j++) {
        if (i == 0 && j == result.length - 1) continue;
        final c = result[j],
            v = result[(j + 1) % result.length] - c,
            denominator = _cross(u, v);
        if (denominator.abs() < 1e-9 * u.distance * v.distance) continue;
        final t = _cross(c - a, v) / denominator,
            s = _cross(c - a, u) / denominator;
        if (t > 1e-8 && t < 1 - 1e-8 && s > 1e-8 && s < 1 - 1e-8) return null;
      }
    }
    return result;
  }
}
