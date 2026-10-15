import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../models/architect_elements.dart';
import '../services/architect_dimension_chain.dart';

class ArchitectDimensionEditHandle {
  final ArchitectDimensionEditPoint reference;
  final Rect rect;
  final bool canRemove;
  const ArchitectDimensionEditHandle(this.reference, this.rect, this.canRemove);
}

/// Small visible marks with larger touch targets, shown only while editing a chain.
class ArchitectDimensionEditOverlay extends StatelessWidget {
  final List<ArchitectDimensionEditHandle> handles;
  final ValueChanged<ArchitectDimensionEditPoint> onRemove;
  const ArchitectDimensionEditOverlay({
    super.key,
    required this.handles,
    required this.onRemove,
  });

  static List<ArchitectDimensionEditHandle> layout({
    required ArchitectDimension dimension,
    required BimViewportController viewport,
    List<Rect> excluded = const [],
  }) {
    if (viewport.size.shortestSide < 40) return const [];
    final origin = viewport.toScreen(dimension.lineStart);
    final normal =
        viewport.toScreen(dimension.lineStart + dimension.normal) - origin;
    final inward =
        normal / normal.distance * (dimension.offsetDistance < 0 ? 1 : -1);
    final bounds = Offset.zero & viewport.size;
    final handles = <ArchitectDimensionEditHandle>[];
    for (final reference in ArchitectDimensionChain.editPoints(dimension)) {
      final point = viewport.toScreen(reference.point);
      if (!bounds.inflate(18).contains(point)) continue;
      var center = point + inward * 22;
      Rect target(Offset p) => Rect.fromCenter(
        center: Offset(
          p.dx.clamp(18, viewport.size.width - 18),
          p.dy.clamp(18, viewport.size.height - 18),
        ),
        width: 36,
        height: 36,
      );
      var rect = target(center);
      for (
        var step = 0;
        step < 12 &&
            (handles.any((h) => h.rect.overlaps(rect)) ||
                excluded.any((r) => r.overlaps(rect)));
        step++
      ) {
        center += inward * 36;
        rect = target(center);
      }
      if (handles.any((h) => h.rect.overlaps(rect)) ||
          excluded.any((r) => r.overlaps(rect))) {
        continue;
      }
      handles.add(
        ArchitectDimensionEditHandle(
          reference,
          rect,
          ArchitectDimensionChain.removeAnchors(
                dimension,
                reference.anchorIndices,
              ) !=
              null,
        ),
      );
    }
    return handles;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final handle in handles)
        Positioned.fromRect(
          rect: handle.rect,
          child: IconButton(
            key: ValueKey('architect-dimension-remove-${handle.reference.id}'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: handle.canRemove
                ? context.l10n.architectDimensionRemoveReference
                : context.l10n.architectDimensionKeepReferences,
            onPressed: handle.canRemove
                ? () => onRemove(handle.reference)
                : null,
            icon: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: handle.canRemove
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE0E0E0),
                border: Border.all(
                  color: handle.canRemove
                      ? const Color(0xFFC62828)
                      : Colors.grey,
                ),
              ),
              child: Icon(
                Icons.remove,
                size: 13,
                color: handle.canRemove ? const Color(0xFFC62828) : Colors.grey,
              ),
            ),
          ),
        ),
    ],
  );
}
