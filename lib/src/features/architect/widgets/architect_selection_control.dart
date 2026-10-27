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
    Widget action(
      String key,
      String tooltip,
      IconData icon,
      VoidCallback? callback,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      color: colors.onSurface,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      onPressed: callback,
      icon: Icon(icon, size: 22),
    );
    String operationLabel(ArchitectSelectionOperation? value) =>
        switch (value) {
          ArchitectSelectionOperation.replace => l.architectSelectReplace,
          ArchitectSelectionOperation.add => l.architectSelectAdd,
          ArchitectSelectionOperation.remove => l.architectSelectRemove,
          null => l.architectSelectionMulti,
        };
    IconData operationIcon(ArchitectSelectionOperation? value) =>
        switch (value) {
          ArchitectSelectionOperation.replace => Icons.select_all,
          ArchitectSelectionOperation.add => Icons.add_box_outlined,
          ArchitectSelectionOperation.remove =>
            Icons.indeterminate_check_box_outlined,
          null => Icons.library_add_check_outlined,
        };
    final effectiveCount = previewCount ?? count;
    Widget countBadge() => Tooltip(
      message: previewCount == null
          ? l.architectSelectionCount(count)
          : l.architectSelectPreviewCount(effectiveCount),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                  Icon(
                                    value == ArchitectSelectMode.rectangle
                                        ? Icons.rectangle_outlined
                                        : Icons.polyline_rounded,
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
                  icon: Icon(
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
                        child: Text(
                          operationLabel(value),
                          style: TextStyle(color: colors.onSurface),
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
                  icon: Icon(
                    relation == ArchitectSelectionRelation.contained
                        ? Icons.crop_free
                        : Icons.filter_center_focus,
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
                        child: Text(
                          value == ArchitectSelectionRelation.contained
                              ? l.architectSelectContained
                              : l.architectSelectCrossing,
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                  ],
                ),
              countBadge(),
              action(
                'architect-selection-control-clear',
                l.architectSelectionClear,
                Icons.deselect_outlined,
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
                      child: Icon(
                        mode == ArchitectSelectMode.rectangle
                            ? Icons.rectangle_outlined
                            : Icons.polyline_rounded,
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
                  Icons.undo_rounded,
                  canUndo ? onUndo : null,
                ),
              action(
                'architect-select-cancel',
                l.cancel,
                Icons.close_rounded,
                onCancel,
              ),
              if (mode == ArchitectSelectMode.polygon)
                action(
                  'architect-select-finish',
                  l.architectSelectFinish,
                  Icons.check_circle_outline,
                  canFinish ? onFinish : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
