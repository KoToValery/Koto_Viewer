import 'dart:ui';
import 'dart:math' as math;
import '../models/structural_element.dart';

/// A shared axis matches an alignment, never merely a nearby wall or label.
class ProjectGridAxes {
  static bool sameAlignment(
    StructuralGridAxis a,
    StructuralGridAxis b,
    double unitsPerMeter,
  ) {
    if (a.length <= 0 ||
        b.length <= 0 ||
        !unitsPerMeter.isFinite ||
        unitsPerMeter <= 0) {
      return false;
    }
    if (!a.isParallelTo(b, toleranceRad: .001)) return false;
    final tolerance = .005 * unitsPerMeter;
    // Infinite lines allow reversed/different drawing extents. Checking both
    // endpoints prevents slightly converging long axes being merged.
    return (a.projectPoint(b.start) - b.start).distance <= tolerance &&
        (a.projectPoint(b.end) - b.end).distance <= tolerance &&
        (b.projectPoint(a.start) - a.start).distance <= tolerance &&
        (b.projectPoint(a.end) - a.end).distance <= tolerance;
  }

  static List<StructuralGridAxis> merge(
    Iterable<StructuralGridAxis> input,
    double unitsPerMeter, {
    required bool isBulgarian,
    Set<String> preserveExtents = const {},
  }) {
    final axes = <StructuralGridAxis>[];
    for (final axis in input) {
      final index = axes.indexWhere(
        (a) => sameAlignment(a, axis, unitsPerMeter),
      );
      if (index < 0) {
        axes.add(axis);
        continue;
      }
      final current = axes[index];
      // A manually shared/legacy global axis remains global.
      final sources =
          current.sourceStoreyIds.isEmpty || axis.sourceStoreyIds.isEmpty
                ? <String>[]
                : {...current.sourceStoreyIds, ...axis.sourceStoreyIds}.toList()
            ..sort();
      var shared = current.copyWith(sourceStoreyIds: sources);
      if (!preserveExtents.contains(current.id) &&
          current.id.startsWith('bim_axis_') &&
          axis.id.startsWith('bim_axis_')) {
        final u = current.direction;
        double along(Offset p) =>
            (p - current.start).dx * u.dx + (p - current.start).dy * u.dy;
        final values = [0.0, current.length, along(axis.start), along(axis.end)]
          ..sort();
        shared = shared.copyWith(
          start: current.start + u * values.first,
          end: current.start + u * values.last,
        );
      }
      axes[index] = shared;
    }
    return resequenceGridAxes(
      alignExtents(axes, preserveExtents: preserveExtents),
      isBulgarian: isBulgarian,
    );
  }

  static List<StructuralGridAxis> alignExtents(
    List<StructuralGridAxis> axes, {
    Set<String> preserveExtents = const {},
  }) {
    final result = axes.toList(), used = <int>{};
    bool automatic(StructuralGridAxis a) =>
        a.id.startsWith('bim_axis_') || a.id.startsWith('axis_auto_');
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    for (var i = 0; i < axes.length; i++) {
      if (used.contains(i) ||
          !automatic(axes[i]) ||
          preserveExtents.contains(axes[i].id)) {
        continue;
      }
      final u = axes[i].direction;
      final group = [
        for (var j = i; j < axes.length; j++)
          if (automatic(axes[j]) &&
              !preserveExtents.contains(axes[j].id) &&
              axes[i].isParallelTo(axes[j], toleranceRad: .001))
            j,
      ];
      if (group.length < 2) continue;
      var lo = double.infinity, hi = -double.infinity;
      for (final j in group) {
        used.add(j);
        for (final p in [axes[j].start, axes[j].end]) {
          lo = math.min(lo, dot(p, u));
          hi = math.max(hi, dot(p, u));
        }
      }
      for (final j in group) {
        final axis = axes[j], v = axis.direction, den = dot(v, u);
        if (den.abs() < .9) continue;
        final a = axis.start + v * ((lo - dot(axis.start, u)) / den);
        final b = axis.start + v * ((hi - dot(axis.start, u)) / den);
        result[j] = axis.copyWith(start: den > 0 ? a : b, end: den > 0 ? b : a);
      }
    }
    return result;
  }
}
