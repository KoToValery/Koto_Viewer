import 'package:flutter/painting.dart';
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
  static const fontSize = 10.5;

  static String caption(StoreyLevel owner, StructuralSlab slab) {
    final z = owner.structuralElevationFor(slab);
    final sign = z > 0
        ? '+'
        : z == 0
        ? '±'
        : '';
    return '$sign${z.toStringAsFixed(2)} · ${(slab.thickness * 100).round()} cm';
  }

  static List<SlabPlanLabel> layout({
    required StoreyLevel current,
    StoreyLevel? lower,
    StoreyLevel? upper,
    required Offset Function(Offset) project,
    double zoom = 1,
    String? selectedId,
    bool showFloorSlabs = false,
  }) {
    final sources =
        <(StoreyLevel, StructuralSlab, bool, bool)>[
          for (final slab in current.slabs)
            if (!slab.isFloorSlab || showFloorSlabs) (current, slab, false, false),
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
      final text = TextPainter(
        text: TextSpan(
          text: caption(source.$1, source.$2),
          style: const TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var rect = Rect.fromCenter(
        center: anchor,
        width: (text.width + 10) / zoom,
        height: (text.height + 6) / zoom,
      );
      while (labels.any((l) => l.rect.inflate(4 / zoom).overlaps(rect))) {
        rect = rect.shift(Offset(0, rect.height + 4 / zoom));
      }
      labels.add(
        SlabPlanLabel(source.$1, source.$2, rect, anchor, source.$3, source.$4),
      );
    }
    return labels;
  }
}
