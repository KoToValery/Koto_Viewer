import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Presentation only: every entry keeps the workspace's existing command.
class ArchitectSelectionAction {
  final String id, label;
  final String? commandId;
  final String? tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final Widget? button;
  final List<ArchitectSelectionAction> children;
  final bool primary;
  final double desktopWidth;

  const ArchitectSelectionAction({
    required this.id,
    required this.label,
    required this.icon,
    this.commandId,
    this.tooltip,
    this.onPressed,
    this.button,
    this.children = const [],
    this.primary = false,
    this.desktopWidth = 26,
  });
}

/// Phones expose frequent actions with finger-sized targets and one overflow.
/// Desktop retains the complete strip and its nested wall menu.
class ArchitectSelectionActionBar extends StatelessWidget {
  final List<ArchitectSelectionAction> actions;
  final int count;
  final bool showClear, showCount, menuOnly;
  final VoidCallback? onAction;

  const ArchitectSelectionActionBar({
    super.key,
    required this.actions,
    required this.count,
    this.showClear = true,
    this.showCount = true,
    this.menuOnly = false,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final colors = Theme.of(context).colorScheme;
    final visible = actions.where(
      (action) =>
          !compact || showClear || action.id != 'architect-clear-selection',
    );

    List<ArchitectSelectionAction> flatten(
      Iterable<ArchitectSelectionAction> entries,
    ) => [
      for (final entry in entries)
        if (entry.children.isNotEmpty) ...entry.children else entry,
    ];

    Widget menu(List<ArchitectSelectionAction> entries, {String? id}) {
      final commands = <String, ArchitectSelectionAction>{};
      for (final entry in entries) {
        commands.putIfAbsent(entry.commandId ?? entry.id, () => entry);
      }
      final byId = {for (final entry in commands.values) entry.id: entry};
      return SizedBox(
        key: compact ? const ValueKey('architect-selection-more') : null,
        width: compact ? 44 : 48,
        height: compact ? 44 : 40,
        child: PopupMenuButton<String>(
          key: ValueKey(id ?? 'architect-selection-overflow'),
          tooltip: context.l10n.contextMenuMore,
          padding: EdgeInsets.zero,
          icon: AppIcon(
            AppIconId.moreHorizontal,
            color: compact ? colors.onSurface : Colors.white70,
          ),
          constraints: BoxConstraints(
            minWidth: 180,
            maxWidth: (MediaQuery.sizeOf(context).width - 24)
                .clamp(180, 320)
                .toDouble(),
          ),
          onSelected: (value) {
            onAction?.call();
            byId[value]?.onPressed?.call();
          },
          itemBuilder: (_) => [
            for (final entry in byId.values)
              PopupMenuItem<String>(
                key: ValueKey(entry.id),
                value: entry.id,
                enabled: entry.onPressed != null,
                child: Row(
                  children: [
                    if (entry.icon case AppIcon(:final id, :final size))
                      AppIcon(id, size: size, color: colors.onSurface)
                    else if (entry.icon case Icon(:final icon, :final size))
                      AppIcon.fromMaterial(icon, size: size, color: colors.onSurface,
                      )
                    else
                      entry.icon,
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.label)),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    Widget button(ArchitectSelectionAction action) {
      if (action.button != null) return action.button!;
      if (action.children.isNotEmpty) {
        return menu(action.children, id: action.id);
      }
      return IconButton(
        key: ValueKey(action.id),
        tooltip: action.tooltip ?? action.label,
        constraints: BoxConstraints.tightFor(
          width: compact ? 44 : action.desktopWidth,
          height: compact ? 44 : 40,
        ),
        padding: EdgeInsets.zero,
        onPressed: action.onPressed,
        icon: action.icon,
      );
    }

    if (compact && menuOnly) return menu(flatten(visible));
    final secondary = flatten(visible.where((entry) => !entry.primary));
    final linearMenu = actions
        .where((entry) => entry.id == 'architect-wall-actions')
        .firstOrNull;
    final children = compact
        ? <Widget>[
            if (showCount)
              Tooltip(
                message: context.l10n.architectSelectionCount(count),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 40),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$count',
                        key: const ValueKey('architect-selection-action-count'),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final entry in visible.where((entry) => entry.primary))
              button(entry),
            if (secondary.isNotEmpty) menu(secondary, id: linearMenu?.id),
          ]
        : [for (final entry in visible) button(entry)];

    return Material(
      key: const ValueKey('architect-selection-bar'),
      color: compact ? colors.surfaceContainerHigh : const Color(0xFF1E1E26),
      shape: compact
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colors.outlineVariant),
            )
          : const Border(top: BorderSide(color: Colors.white12)),
      child: IconButtonTheme(
        data: const IconButtonThemeData(
          style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
