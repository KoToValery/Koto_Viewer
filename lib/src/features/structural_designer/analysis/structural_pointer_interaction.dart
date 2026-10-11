import 'dart:ui';
import '../../bim_projects/models/bim_coordinate_frame.dart';

/// Screen-space capture limits, independent of zoom and CAD units.
class StructuralPointerInteraction {
  static const touchClearancePx = 64.0;
  static double snapToleranceCad({
    required bool isMouse,
    required double pixelsPerCadUnit,
    required double cadUnitsPerMeter,
  }) => BimPrecisionPolicy.captureTolerance(
    pixelsPerUnit: pixelsPerCadUnit,
    unitsPerMeter: cadUnitsPerMeter,
    pixels: isMouse ? 8 : 12,
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
