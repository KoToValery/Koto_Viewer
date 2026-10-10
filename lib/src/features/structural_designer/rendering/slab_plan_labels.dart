import 'dart:ui';
import '../models/structural_element.dart';

class SlabPlanLabel {
  final StoreyLevel owner;
  final StructuralSlab slab;
  final Rect rect;
  final Offset anchor;
  final bool reference, floor;
  const SlabPlanLabel(
    this.owner,
    this.slab,
    this.rect,
    this.anchor,
    this.reference,
    this.floor,
  );
}

/// Shared drawing and hit geometry: a badge always identifies its actual owner.
class SlabPlanLabels {
  static List<SlabPlanLabel> layout({
    required StoreyLevel current,
    StoreyLevel? lower,
    StoreyLevel? upper,
    required Offset Function(Offset) project,
    double zoom = 1,
    String? selectedId,
  }) {
    final sources =
        <(StoreyLevel, StructuralSlab, bool, bool)>[
          for (final slab in current.slabs)
            (current, slab, false, slab.isFloorSlab),
          if (lower != null)
            for (final slab in lower.slabs) (lower, slab, true, true),
          if (upper != null)
            for (final slab in upper.slabs) (upper, slab, true, false),
        ]..sort((a, b) {
          final ap = !a.$3 && a.$2.id == selectedId
              ? 0
              : a.$3
              ? 2
              : 1;
          final bp = !b.$3 && b.$2.id == selectedId
              ? 0
              : b.$3
              ? 2
              : 1;
          return ap != bp
              ? ap.compareTo(bp)
              : '${a.$1.id}/${a.$2.id}'.compareTo('${b.$1.id}/${b.$2.id}');
        });
    final labels = <SlabPlanLabel>[];
    for (final source in sources) {
      if (source.$2.polygon.length < 3) continue;
      final anchor = project(source.$2.centroid);
      var rect = Rect.fromCenter(
        center: anchor,
        width: 126 / zoom,
        height: 52 / zoom,
      );
      while (labels.any((l) => l.rect.inflate(4 / zoom).overlaps(rect))) {
        rect = rect.shift(Offset(0, 60 / zoom));
      }
      labels.add(
        SlabPlanLabel(source.$1, source.$2, rect, anchor, source.$3, source.$4),
      );
    }
    return labels;
  }
}
