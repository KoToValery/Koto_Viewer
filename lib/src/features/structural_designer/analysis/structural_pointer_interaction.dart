import 'dart:math' as math;
import 'dart:ui';

/// Screen-space capture limits, independent of zoom and CAD units.
class StructuralPointerInteraction {
  static const touchClearancePx = 64.0;
  static double snapToleranceCad({
    required bool isMouse,
    required double pixelsPerCadUnit,
    required double cadUnitsPerMeter,
  }) => math.min(
    (isMouse ? 8.0 : 12.0) / pixelsPerCadUnit,
    .20 * cadUnitsPerMeter,
  );

  static Offset placementTarget(Offset pointer, {required bool isMouse}) =>
      isMouse ? pointer : pointer - const Offset(0, touchClearancePx);

  /// Preserve the CAD-space grab vector; press alone never relocates an element.
  static Offset grabOffset(Offset elementCenter, Offset pointerCad) =>
      elementCenter - pointerCad;
  static Offset dragTarget(Offset pointerCad, Offset grabOffset) =>
      pointerCad + grabOffset;

  static bool accepts(
    Offset rawCenter,
    Offset proposedCenter,
    double tolerance,
  ) => (proposedCenter - rawCenter).distance <= tolerance + 1e-8;
}
