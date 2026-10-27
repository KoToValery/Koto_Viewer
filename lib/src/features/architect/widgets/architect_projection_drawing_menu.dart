import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../rendering/architect_2d_painter.dart';

/// Routes projection drafting to the shared workspace and its view history.
class ArchitectProjectionDrawingMenu extends StatelessWidget {
  final ValueChanged<ArchitectTool> onSelected;
  final VoidCallback? onTerrain;
  const ArchitectProjectionDrawingMenu({
    super.key,
    required this.onSelected,
    this.onTerrain,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tools = {
      ArchitectTool.select: (Icons.near_me_outlined, l.architectToolSelect),
      ArchitectTool.cadLine: (Icons.show_chart, l.architectToolCadLine),
      ArchitectTool.cadRect: (Icons.crop_square, l.architectToolCadRect),
      ArchitectTool.hatch: (Icons.texture, l.architectToolHatch),
      ArchitectTool.cadCircle: (
        Icons.circle_outlined,
        l.architectToolCadCircle,
      ),
      ArchitectTool.text: (Icons.title, l.architectToolText),
      ArchitectTool.dimension: (Icons.straighten, l.architectToolDimension),
      ArchitectTool.level: (Icons.height, l.architectToolLevel),
      ArchitectTool.measure: (Icons.square_foot, l.architectToolMeasure),
    };
    return PopupMenuButton<String>(
      key: const ValueKey('architect-projection-drawing-tools'),
      tooltip: l.architectCategoryDrawing,
      icon: const Icon(Icons.edit_outlined),
      onSelected: (value) {
        if (value == 'terrain') {
          onTerrain?.call();
        } else {
          onSelected(ArchitectTool.values.byName(value));
        }
      },
      itemBuilder: (_) => [
        for (final entry in tools.entries)
          PopupMenuItem(
            value: entry.key.name,
            child: Row(
              children: [
                Icon(entry.value.$1, size: 20),
                const SizedBox(width: 8),
                Text(entry.value.$2),
              ],
            ),
          ),
        if (onTerrain != null)
          PopupMenuItem(
            value: 'terrain',
            child: Row(
              children: [
                const Icon(Icons.landscape_outlined, size: 20),
                const SizedBox(width: 8),
                Text(l.architectTerrain),
              ],
            ),
          ),
      ],
    );
  }
}
