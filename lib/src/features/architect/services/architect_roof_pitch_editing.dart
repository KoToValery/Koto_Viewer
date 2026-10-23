import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_roof.dart';

/// Rotation about a chosen horizontal axis parallel to the roof's eaves.
/// The exterior surface on that axis stays fixed, including layer thickness.
class ArchitectRoofPitchEditing {
  static ArchitectRoofPlane rotate(
    ArchitectRoofPlane source, {
    required Offset pivot,
    required Offset control,
    required double targetTopElevation,
  }) {
    final run =
        source.signedDistanceFromEaves(control) -
        source.signedDistanceFromEaves(pivot);
    if (run.abs() < .01 || !targetTopElevation.isFinite) {
      throw ArgumentError('Invalid roof control');
    }
    final fixed = source.topElevationAt(pivot);
    final gradient = (targetTopElevation - fixed) / run;
    final angle = math.atan(gradient) * 180 / math.pi;
    if (!angle.isFinite || angle < 0 || angle > 80) {
      throw ArgumentError('Invalid roof pitch');
    }
    final next = source.copyWith(
      slopeDegrees: angle,
      attachToWalls: false,
      placementResolved: true,
    );
    return next.copyWith(
      baseElevationOffset:
          next.baseElevationOffset + fixed - next.topElevationAt(pivot),
    );
  }
}
