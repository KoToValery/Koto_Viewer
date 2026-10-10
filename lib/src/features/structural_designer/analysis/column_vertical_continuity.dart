import 'dart:math' as math;
import '../models/structural_element.dart';
import 'slab_contact_geometry.dart';
import 'support_placement_rules.dart';

/// Full upper-section coverage by actual lower columns/walls. A nearby centre
/// does not demonstrate direct support; a transfer beam needs separate analysis.
class ColumnVerticalContinuity {
  final double? coverage;
  const ColumnVerticalContinuity(this.coverage);
  bool get isContinuous => coverage != null && coverage! >= 1 - 1e-7;
  static ColumnVerticalContinuity evaluate(
    StructuralColumn upper,
    StoreyLevel lower,
    double scale,
  ) {
    if (!scale.isFinite ||
        scale <= 0 ||
        !upper.width.isFinite ||
        upper.width <= 0 ||
        !upper.height.isFinite ||
        upper.height <= 0) {
      return const ColumnVerticalContinuity(null);
    }
    for (final c in lower.columns) {
      if (c.shape == upper.shape &&
          (c.center - upper.center).distance < 1e-7 * scale &&
          (c.width - upper.width).abs() < 1e-7 * scale &&
          (c.height - upper.height).abs() < 1e-7 * scale &&
          (c.rotationRad - upper.rotationRad).abs() < 1e-8 &&
          (c.thickness - upper.thickness).abs() < 1e-7 * scale) {
        return const ColumnVerticalContinuity(1);
      }
    }
    final polygon = SupportPlacementRules.columnFootprint(upper);
    final area = StructuralSlab.calculateArea(polygon) / (scale * scale);
    if (!area.isFinite || area <= 1e-10) {
      return const ColumnVerticalContinuity(null);
    }
    final contact = SlabContactGeometry.measure(polygon, [
      for (final c in lower.columns)
        StructuralSlab(
          id: c.id,
          polygon: SlabContactGeometry.columnFootprint(c),
        ),
      for (final w in lower.shearWalls)
        StructuralSlab(id: w.id, polygon: w.polygonVertices),
    ], scale);
    return ColumnVerticalContinuity(
      contact == null ? null : math.min(1, contact.areaM2 / area),
    );
  }
}
