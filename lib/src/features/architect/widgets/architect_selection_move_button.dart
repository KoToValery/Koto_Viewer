import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

enum ArchitectSelectionMoveAction { free, transverse, offset, stop }

/// Keeps precise and constrained movement under the same selection action.
class ArchitectSelectionMoveButton extends StatelessWidget {
  final bool active;
  final bool transverse;
  final bool supportsTransverse;
  final ValueChanged<ArchitectSelectionMoveAction> onSelected;

  const ArchitectSelectionMoveButton({
    super.key,
    required this.active,
    required this.transverse,
    required this.supportsTransverse,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = Icon(
      active && transverse ? Icons.swap_vert : Icons.open_with,
      size: 18,
      color: active
          ? Colors.amber
          : compact
          ? Theme.of(context).colorScheme.onSurface
          : Colors.white70,
    );
    if (!supportsTransverse) {
      return IconButton(
        key: const ValueKey('architect-selection-move'),
        constraints: BoxConstraints.tightFor(
          width: compact ? 44 : 26,
          height: compact ? 44 : 40,
        ),
        padding: EdgeInsets.zero,
        tooltip: l.architectSelectionMove,
        icon: icon,
        onPressed: () => onSelected(
          active
              ? ArchitectSelectionMoveAction.stop
              : ArchitectSelectionMoveAction.free,
        ),
      );
    }
    return PopupMenuButton<ArchitectSelectionMoveAction>(
      key: const ValueKey('architect-selection-move'),
      tooltip: l.architectMoveHelp,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          key: const ValueKey('architect-move-free'),
          value: ArchitectSelectionMoveAction.free,
          checked: active && !transverse,
          child: Text(l.architectMoveFree),
        ),
        CheckedPopupMenuItem(
          key: const ValueKey('architect-move-transverse'),
          value: ArchitectSelectionMoveAction.transverse,
          checked: active && transverse,
          child: Text(l.architectMoveTransverse),
        ),
        PopupMenuItem(
          key: const ValueKey('architect-move-offset'),
          value: ArchitectSelectionMoveAction.offset,
          child: Text(l.architectMoveOffset),
        ),
        if (active)
          PopupMenuItem(
            key: const ValueKey('architect-move-stop'),
            value: ArchitectSelectionMoveAction.stop,
            child: Text(l.architectMoveStop),
          ),
      ],
      child: SizedBox(
        width: compact ? 44 : 26,
        height: compact ? 44 : 40,
        child: Center(child: icon),
      ),
    );
  }
}
