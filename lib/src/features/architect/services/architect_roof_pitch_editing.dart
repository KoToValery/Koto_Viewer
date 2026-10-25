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
    if (source.isMansard) {
      // Across a fold, changing the lower pitch also changes the vertical layer
      // thickness. Solve the actual exterior surface instead of assuming one
      // straight slope; an axis and control above the fold edit the upper pitch.
      final upper =
          source.signedDistanceFromEaves(pivot) >
              source.effectiveBreakDistance &&
          source.signedDistanceFromEaves(control) >
              source.effectiveBreakDistance;
      ArchitectRoofPlane at(double angle) {
        final candidate = source.copyWith(
          slopeDegrees: upper ? source.slopeDegrees : angle,
          upperSlopeDegrees: upper ? angle : source.upperSlopeDegrees,
          attachToWalls: false,
          placementResolved: true,
        );
        return candidate.copyWith(
          baseElevationOffset:
              candidate.baseElevationOffset +
              fixed -
              candidate.topElevationAt(pivot),
        );
      }

      final originalAngle = upper
          ? source.upperSlopeDegrees
          : source.slopeDegrees;
      double? low, high;
      var closest = double.infinity;
      for (var a = 0.0; a < 80; a += 2) {
        final first = at(a).topElevationAt(control) - targetTopElevation;
        final last = at(a + 2).topElevationAt(control) - targetTopElevation;
        if (first * last <= 0 && (a + 1 - originalAngle).abs() < closest) {
          low = a;
          high = a + 2;
          closest = (a + 1 - originalAngle).abs();
        }
      }
      if (low == null || high == null) {
        throw ArgumentError('Invalid roof pitch');
      }
      for (var i = 0; i < 48; i++) {
        final middle = (low! + high!) / 2;
        final error = at(middle).topElevationAt(control) - targetTopElevation;
        if ((at(low).topElevationAt(control) - targetTopElevation) * error <=
            0) {
          high = middle;
        } else {
          low = middle;
        }
      }
      return at((low! + high!) / 2);
    }
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
