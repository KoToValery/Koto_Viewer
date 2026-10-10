import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'vertical_capacity_calculator.dart';

/// Recomputes only active-storey spacing, never the whole building, during drag.
/// Pan/zoom/repaint with an unchanged project and preview reuse the same result.
class SupportSpanFeedbackCache {
  Object? _key;
  List<SupportSpanCheck> _checks = const [];
  List<SupportSpanCheck> evaluate(
    StructuralProject project,
    double scale, {
    StructuralColumn? previewColumn,
    StructuralShearWall? previewWall,
  }) {
    final key = (
      project,
      scale,
      previewColumn == null
          ? null
          : (
              previewColumn.id,
              previewColumn.center,
              previewColumn.width,
              previewColumn.height,
              previewColumn.rotationRad,
              previewColumn.shape,
              previewColumn.thickness,
              previewColumn.isMirrored,
            ),
      previewWall == null
          ? null
          : (
              previewWall.id,
              previewWall.start,
              previewWall.end,
              previewWall.thickness,
              previewWall.referenceLine,
              previewWall.isFlipped,
            ),
    );
    if (key == _key) return _checks;
    final current = project.supportedStoreyFor(project.activeStorey);
    final floor = current.copyWith(
      gridAxes: project.effectiveGridAxes,
      columns: previewColumn == null
          ? current.columns
          : [
              ...current.columns.where((c) => c.id != previewColumn.id),
              previewColumn,
            ],
      shearWalls: previewWall == null
          ? current.shearWalls
          : [
              ...current.shearWalls.where((w) => w.id != previewWall.id),
              previewWall,
            ],
    );
    _checks = VerticalCapacityCalculator.evaluateSupportSpans(floor, scale);
    _key = key;
    return _checks;
  }
}
