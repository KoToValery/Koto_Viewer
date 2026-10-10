import 'dart:ui';
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
      if (current.id.startsWith('bim_axis_') &&
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
    return resequenceGridAxes(axes, isBulgarian: isBulgarian);
  }
}
