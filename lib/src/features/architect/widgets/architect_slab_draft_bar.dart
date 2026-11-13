import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Compact manual contour actions; all geometry remains in the workspace.
class ArchitectSlabDraftBar extends StatelessWidget {
  final int pointCount;
  final bool canFinish;
  final VoidCallback onUndo, onFinish, onCancel, onProperties;
  const ArchitectSlabDraftBar({
    super.key,
    required this.pointCount,
    required this.canFinish,
    required this.onUndo,
    required this.onFinish,
    required this.onCancel,
    required this.onProperties,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, colors = Theme.of(context).colorScheme;
    Widget action(
      String key,
      String tooltip,
      AppIconId icon,
      VoidCallback? onPressed,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: AppIcon(icon, size: 20),
    );
    return Material(
      color: colors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action(
            'slab-draft-properties',
            l.architectProperties,
            AppIconId.properties,
            onProperties,
          ),
          if (pointCount > 0) ...[
            action('slab-draft-undo', l.undoAction, AppIconId.undo, onUndo),
            action(
              'slab-draft-finish',
              l.applyAction,
              AppIconId.confirm,
              canFinish ? onFinish : null,
            ),
            action('slab-draft-cancel', l.cancel, AppIconId.close, onCancel),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l.architectToolSlab),
            ),
        ],
      ),
    );
  }
}
