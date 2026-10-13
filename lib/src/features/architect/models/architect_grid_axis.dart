// === SECTION: TABLE OF CONTENTS ===
// 1. RE-EXPORTS (BIM GRID AXIS ENGINE)
// 2. ARCHITECT GRID AXIS EXTENSIONS & HELPERS
// ===================================

import 'dart:ui';
import '../../bim_editing/operations/bim_axis_operations.dart';
import '../../structural_designer/models/structural_element.dart';

// === SECTION: RE-EXPORTS ===
export '../../structural_designer/models/structural_element.dart'
    show StructuralGridAxis, resequenceGridAxes;
export '../../structural_designer/analysis/project_grid_axes.dart'
    show ProjectGridAxes;

// === SECTION: ARCHITECT GRID AXIS EXTENSIONS & HELPERS ===

/// Architectural extension methods for [StructuralGridAxis].
extension ArchitectGridAxisX on StructuralGridAxis {
  /// Formatted length in meters with two decimal places.
  String get formattedLengthMeters => '${length.toStringAsFixed(2)} m';

  /// Returns perpendicular offset vector by [distanceMeters] and [directionSign].
  /// [directionSign]: +1 or -1.
  Offset computeOffsetVector(double distanceMeters, double directionSign) {
    return BimAxisOperations.offsetVector(this, distanceMeters, directionSign);
  }
}
