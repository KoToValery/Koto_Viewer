// === SECTION: TABLE OF CONTENTS ===
// 1. RE-EXPORTS (BIM GRID AXIS ENGINE)
// 2. ARCHITECT GRID AXIS EXTENSIONS & HELPERS
// ===================================

import 'dart:ui';
import 'dart:math' as math;
import '../../structural_designer/models/structural_element.dart';

// === SECTION: RE-EXPORTS ===
export '../../structural_designer/models/structural_element.dart'
    show StructuralGridAxis, resequenceGridAxes;
export '../../structural_designer/analysis/project_grid_axes.dart'
    show ProjectGridAxes;

// === SECTION: ARCHITECT GRID AXIS EXTENSIONS & HELPERS ===

/// Architectural extension methods for [StructuralGridAxis].
extension ArchitectGridAxisX on StructuralGridAxis {
  /// Whether this axis is predominantly vertical (angle closer to 90° or 270°).
  bool get isVertical {
    final a = angleRad;
    return math.cos(a).abs() <= math.sin(a).abs();
  }

  /// Formatted length in meters with two decimal places.
  String get formattedLengthMeters => '${length.toStringAsFixed(2)} m';

  /// Returns perpendicular offset vector by [distanceMeters] and [directionSign].
  /// [directionSign]: +1 or -1.
  Offset computeOffsetVector(double distanceMeters, double directionSign) {
    final n = normal;
    if (isVertical) {
      final double sign = n.dx > 0
          ? (directionSign > 0 ? 1.0 : -1.0)
          : (directionSign > 0 ? -1.0 : 1.0);
      return n * (distanceMeters * sign);
    } else {
      final double sign = n.dy > 0
          ? (directionSign > 0 ? 1.0 : -1.0)
          : (directionSign > 0 ? -1.0 : 1.0);
      return n * (distanceMeters * sign);
    }
  }
}
