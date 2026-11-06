import 'package:kotoview/src/core/icons/app_icon.dart';
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
      ArchitectTool.select: (AppIconId.select, l.architectToolSelect),
      ArchitectTool.cadLine: (AppIconId.line, l.architectToolCadLine),
      ArchitectTool.cadRect: (AppIconId.rectangle, l.architectToolCadRect),
      ArchitectTool.hatch: (AppIconId.hatch, l.architectToolHatch),
      ArchitectTool.cadCircle: (AppIconId.radioOff,
        l.architectToolCadCircle),
      ArchitectTool.text: (AppIconId.text, l.architectToolText),
      ArchitectTool.dimension: (AppIconId.measure, l.architectToolDimension),
      ArchitectTool.level: (AppIconId.level, l.architectToolLevel),
      ArchitectTool.measure: (AppIconId.measure, l.architectToolMeasure),
    };
    return PopupMenuButton<String>(
      key: const ValueKey('architect-projection-drawing-tools'),
      tooltip: l.architectCategoryDrawing,
      icon: const AppIcon(AppIconId.edit),
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
                AppIcon(entry.value.$1, size: 20),
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
                const AppIcon(AppIconId.terrain, size: 20),
                const SizedBox(width: 8),
                Text(l.architectTerrain),
              ],
            ),
          ),
      ],
    );
  }
}
