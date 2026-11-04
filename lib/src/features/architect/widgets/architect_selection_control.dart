import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_marquee_tool.dart';

/// Compact, theme-aware selection controls shared by every selected element.
class ArchitectSelectionControl extends StatelessWidget {
  final ArchitectSelectMode mode;
  final bool drafting, canFinish, canUndo;
  final int count;
  final ValueChanged<ArchitectSelectMode> onMode;
  final VoidCallback onFinish, onUndo, onCancel, onClear;
  final ArchitectSelectionOperation? operation;
  final ArchitectSelectionRelation relation;
  final ValueChanged<ArchitectSelectionOperation>? onOperation;
  final ValueChanged<ArchitectSelectionRelation>? onRelation;
  final int? previewCount;
  const ArchitectSelectionControl({
    super.key,
    required this.mode,
    required this.drafting,
    required this.canFinish,
    required this.canUndo,
    required this.count,
    required this.onMode,
    required this.onFinish,
    required this.onUndo,
    required this.onCancel,
    required this.onClear,
    this.operation = ArchitectSelectionOperation.replace,
    this.relation = ArchitectSelectionRelation.crossing,
    this.onOperation,
    this.onRelation,
    this.previewCount,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 600;
    Widget action(
      String key,
      String tooltip,
      AppIconId icon,
      VoidCallback? callback,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      color: colors.onSurface,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: callback,
      icon: AppIcon(icon, size: 22),
    );
    String operationLabel(ArchitectSelectionOperation? value) =>
        switch (value) {
          ArchitectSelectionOperation.replace => l.architectSelectReplace,
          ArchitectSelectionOperation.add => l.architectSelectAdd,
          ArchitectSelectionOperation.remove => l.architectSelectRemove,
          null => l.architectSelectionMulti,
        };
    AppIconId operationIcon(ArchitectSelectionOperation? value) =>
        switch (value) {
          ArchitectSelectionOperation.replace => AppIconId.selectAll,
          ArchitectSelectionOperation.add => AppIconId.addBox,
          ArchitectSelectionOperation.remove => AppIconId.removeBox,
          null => AppIconId.multiSelect,
        };
    final effectiveCount = previewCount ?? count;
    Widget countBadge() => Tooltip(
      message: previewCount == null
          ? l.architectSelectionCount(count)
          : l.architectSelectPreviewCount(effectiveCount),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 40 : double.infinity),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$effectiveCount',
              key: const ValueKey('architect-selection-control-count'),
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
    return Material(
      key: const ValueKey('architect-selection-controls'),
      color: colors.surfaceContainerHigh,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            if (!drafting) ...[
              if (compact)
                Expanded(
                  child: PopupMenuButton<ArchitectSelectMode>(
                    key: const ValueKey('architect-selection-shape'),
                    initialValue: mode,
                    tooltip: mode == ArchitectSelectMode.rectangle
                        ? l.architectSelectRectangleHint
                        : l.architectSelectPolygonHint,
                    onSelected: onMode,
                    itemBuilder: (_) => [
                      for (final value in ArchitectSelectMode.values)
                        CheckedPopupMenuItem(
                          key: ValueKey(
                            'architect-selection-mode-${value.name}',
                          ),
                          value: value,
                          checked: mode == value,
                          child: AppMenuLabel(
                            icon: value == ArchitectSelectMode.rectangle
                                ? AppIconId.rectangle
                                : AppIconId.polygon,
                            child: Text(
                            value == ArchitectSelectMode.rectangle
                                ? l.architectSelectModeRect
                                : l.architectSelectModePolygon,
                            ),
                          ),
                        ),
                    ],
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            mode == ArchitectSelectMode.rectangle
                                ? AppIconId.rectangle
                                : AppIconId.polyline,
                            size: 18,
                            color: colors.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              mode == ArchitectSelectMode.rectangle
                                  ? l.architectSelectModeRect
                                  : l.architectSelectModePolygon,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          AppIcon(
                            AppIconId.expandMore,
                            size: 18,
                            color: colors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      for (final value in ArchitectSelectMode.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Tooltip(
                              message: value == ArchitectSelectMode.rectangle
                                  ? l.architectSelectRectangleHint
                                  : l.architectSelectPolygonHint,
                              child: TextButton(
                                key: ValueKey(
                                  'architect-selection-mode-${value.name}',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.onSurface,
                                  backgroundColor: mode == value
                                      ? colors.surfaceContainerHighest
                                      : colors.surfaceContainerHigh,
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: mode == value
                                          ? colors.onSurface
                                          : colors.outline,
                                      width: mode == value ? 2 : 1,
                                    ),
                                  ),
                                ),
                                onPressed: () => onMode(value),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(
                                      value == ArchitectSelectMode.rectangle
                                          ? AppIconId.rectangle
                                          : AppIconId.polyline,
                                      size: 18,
                                    ),
                                    Text(
                                      value == ArchitectSelectMode.rectangle
                                          ? l.architectSelectModeRect
                                          : l.architectSelectModePolygon,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: mode == value
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (onOperation != null)
                PopupMenuButton<ArchitectSelectionOperation>(
                  key: const ValueKey('architect-selection-operation'),
                  initialValue: operation,
                  tooltip: operationLabel(operation),
                  color: colors.surfaceContainerHigh,
                  constraints: const BoxConstraints(minWidth: 160),
                  icon: AppIcon(
                    operationIcon(operation),
                    color: colors.onSurface,
                    size: 22,
                  ),
                  onSelected: onOperation,
                  itemBuilder: (_) => [
                    for (final value in ArchitectSelectionOperation.values)
                      CheckedPopupMenuItem(
                        key: ValueKey(
                          'architect-selection-operation-${value.name}',
                        ),
                        value: value,
                        checked: operation == value,
                        child: AppMenuLabel(
                          icon: operationIcon(value),
                          child: Text(
                          operationLabel(value),
                          style: TextStyle(color: colors.onSurface),
                          ),
                        ),
                      ),
                  ],
                ),
              if (onRelation != null)
                PopupMenuButton<ArchitectSelectionRelation>(
                  key: const ValueKey('architect-selection-relation'),
                  initialValue: relation,
                  tooltip: relation == ArchitectSelectionRelation.contained
                      ? l.architectSelectContainedHelp
                      : l.architectSelectCrossingHelp,
                  color: colors.surfaceContainerHigh,
                  icon: AppIcon(
                    relation == ArchitectSelectionRelation.contained
                        ? AppIconId.opening
                        : AppIconId.fitView,
                    color: colors.onSurface,
                    size: 22,
                  ),
                  onSelected: onRelation,
                  itemBuilder: (_) => [
                    for (final value in ArchitectSelectionRelation.values)
                      CheckedPopupMenuItem(
                        key: ValueKey(
                          'architect-selection-relation-${value.name}',
                        ),
                        value: value,
                        checked: relation == value,
                        child: AppMenuLabel(
                          icon: value == ArchitectSelectionRelation.contained
                              ? AppIconId.selectionContained
                              : AppIconId.selectionCrossing,
                          child: Text(
                          value == ArchitectSelectionRelation.contained
                              ? l.architectSelectContained
                              : l.architectSelectCrossing,
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                      ),
                  ],
                ),
              countBadge(),
              action(
                'architect-selection-control-clear',
                l.architectSelectionClear,
                AppIconId.deselect,
                count == 0 ? null : onClear,
              ),
            ] else ...[
              Expanded(
                child: Row(
                  children: [
                    Tooltip(
                      message: mode == ArchitectSelectMode.rectangle
                          ? l.architectSelectModeRect
                          : l.architectSelectModePolygon,
                      child: AppIcon(
                        mode == ArchitectSelectMode.rectangle
                            ? AppIconId.rectangle
                            : AppIconId.polyline,
                        color: colors.onSurface,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        operationLabel(operation),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurface, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              countBadge(),
              if (mode == ArchitectSelectMode.polygon)
                action(
                  'architect-select-undo',
                  l.undoPoint,
                  AppIconId.undo,
                  canUndo ? onUndo : null,
                ),
              action(
                'architect-select-cancel',
                l.cancel,
                AppIconId.close,
                onCancel,
              ),
              if (mode == ArchitectSelectMode.polygon)
                action(
                  'architect-select-finish',
                  l.architectSelectFinish,
                  AppIconId.checkCircle,
                  canFinish ? onFinish : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
