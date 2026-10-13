import 'dart:math' as math;
import 'dart:ui';
import '../geometry/bim_grid_axis.dart';

/// Axis editing geometry. Hosts convert CAD units at their boundary and retain
/// the native document's ownership, naming and persistence policies.
class BimAxisOperations {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static Offset offsetNormal(BimGridAxis axis) {
    final n = axis.normal;
    return n.dx.abs() >= n.dy.abs() ? (n.dx < 0 ? -n : n) : (n.dy < 0 ? -n : n);
  }

  static double offsetSign(
    BimGridAxis axis,
    Offset point, {
    double previous = 1,
  }) {
    final side = dot(point - (axis.start + axis.end) / 2, offsetNormal(axis));
    return side.abs() < 1e-9 ? previous : (side > 0 ? 1 : -1);
  }

  static Offset offsetVector(BimGridAxis axis, double distance, double sign) {
    if (!distance.isFinite ||
        distance <= 0 ||
        !sign.isFinite ||
        sign == 0 ||
        axis.length < 1e-9) {
      throw ArgumentError('Invalid axis offset');
    }
    return offsetNormal(axis) * distance * (sign > 0 ? 1 : -1);
  }

  static BimGridAxis offset(BimGridAxis axis, double distance, double sign) {
    final delta = offsetVector(axis, distance, sign);
    return axis.copyWith(start: axis.start + delta, end: axis.end + delta);
  }

  static List<BimGridAxis> alignParallel(
    List<BimGridAxis> axes,
    BimGridAxis reference,
  ) => [
    for (final axis in axes)
      if (axis.id == reference.id)
        reference
      else if (axis.length >= .001 &&
          axis.isParallelTo(reference, toleranceRad: .01))
        axis.alignWith(reference)
      else
        axis,
  ];
  static BimGridAxis alignNew(
    BimGridAxis axis,
    List<BimGridAxis> axes, {
    double toleranceRad = .01,
  }) {
    if (axis.length < .30) return axis;
    final references =
        axes
            .where(
              (a) =>
                  a.length >= .001 &&
                  a.isParallelTo(axis, toleranceRad: toleranceRad),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return references.isEmpty ? axis : axis.alignWith(references.first);
  }

  static BimGridAxis handlePreview({
    required BimGridAxis original,
    required bool startHandle,
    required Offset point,
    required List<BimGridAxis> axes,
    required double captureRadius,
    double minimumLength = .30,
  }) {
    final projection = original.projectPoint(point), u = original.direction;
    var candidate = projection, best = captureRadius + 1e-9;
    final ordered = axes.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final other in ordered) {
      if (other.id == original.id ||
          !original.isParallelTo(other, toleranceRad: .05)) {
        continue;
      }
      final sameDirection = dot(u, other.direction) >= 0;
      final extent = startHandle == sameDirection ? other.start : other.end;
      final aligned = original.start + u * dot(extent - original.start, u);
      final correction = (projection - aligned).distance;
      if (correction < best) {
        best = correction;
        candidate = aligned;
      }
    }
    final along = dot(candidate - original.start, u);
    candidate =
        original.start +
        u *
            (startHandle
                ? math.min(along, original.length - minimumLength)
                : math.max(along, minimumLength));
    return startHandle
        ? original.copyWith(start: candidate)
        : original.copyWith(end: candidate);
  }

  static Offset movingDelta({
    required BimGridAxis original,
    required Offset delta,
    required List<BimGridAxis> axes,
    required double captureRadius,
  }) {
    var candidate = delta, best = captureRadius + 1e-9;
    final ordered = axes.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final other in ordered) {
      if (other.id == original.id ||
          !original.isParallelTo(other, toleranceRad: .05)) {
        continue;
      }
      final distance = dot(
        original.start + delta - other.start,
        original.normal,
      );
      if (distance.abs() < best) {
        best = distance.abs();
        candidate = delta - original.normal * distance;
      }
    }
    return candidate;
  }
}
