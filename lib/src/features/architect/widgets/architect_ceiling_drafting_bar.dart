import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_ceiling_geometry.dart';

/// Compact horizontally-scrollable toolbar for drafting a suspended ceiling
/// (Room auto-detect or Polygon) and quick-editing a selected ceiling.
class ArchitectCeilingDraftingBar extends StatelessWidget {
  final SuspendedCeilingType type;
  final bool fromRoom;
  final double dropFromUpperSlab;
  final int pointCount;
  final bool canFinish;
  final ArchitectSuspendedCeiling? selected;
  final CeilingElevationMetrics? metrics;
  final bool pickingGridOrigin;
  final ValueChanged<SuspendedCeilingType> onTypeChanged;
  final ValueChanged<bool> onFromRoomChanged;
  final ValueChanged<double> onDropChanged;
  final VoidCallback onProperties;
  final VoidCallback? onCenterGrid;
  final VoidCallback? onTogglePickOrigin;
  final VoidCallback? onUndo;
  final VoidCallback? onFinish;
  final VoidCallback? onCancel;

  const ArchitectCeilingDraftingBar({
    super.key,
    required this.type,
    required this.fromRoom,
    required this.dropFromUpperSlab,
    this.pointCount = 0,
    this.canFinish = false,
    this.selected,
    this.metrics,
    this.pickingGridOrigin = false,
    required this.onTypeChanged,
    required this.onFromRoomChanged,
    required this.onDropChanged,
    required this.onProperties,
    this.onCenterGrid,
    this.onTogglePickOrigin,
    this.onUndo,
    this.onFinish,
    this.onCancel,
  });

  Widget _stepper({
    required String key,
    required String tooltip,
    required String text,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    bool warn = false,
  }) => Row(
    key: ValueKey(key),
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 34, height: 38),
        padding: EdgeInsets.zero,
        onPressed: onMinus,
        icon: const Icon(Icons.remove, size: 16),
      ),
      Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (warn) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Color(0xFFFFB300),
                ),
                const SizedBox(width: 3),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: warn ? const Color(0xFFFFD54F) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: tooltip,
        constraints: const BoxConstraints.tightFor(width: 34, height: 38),
        padding: EdgeInsets.zero,
        onPressed: onPlus,
        icon: const Icon(Icons.add, size: 16),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.sizeOf(context).width;
    final effectiveType = selected?.type ?? type;
    final effectiveDrop = selected?.dropFromUpperSlab ?? dropFromUpperSlab;
    final dropCm = (effectiveDrop * 100).round();
    final clearText = metrics == null
        ? 'Δh=${dropCm}cm'
        : 'Δh=${dropCm}cm · H=${metrics!.clearHeight.toStringAsFixed(2)}m';

    return Material(
      color: const Color(0xEE1E242C),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screen - 16),
        child: Theme(
          data: ThemeData.dark(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(
                  AppIconId.layoutGrid,
                  size: 18,
                  color: Colors.cyanAccent,
                ),
                const SizedBox(width: 6),
                SegmentedButton<SuspendedCeilingType>(
                  key: const ValueKey('ceiling-type-toggle'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: SuspendedCeilingType.armstrong,
                      label: Text(
                        l.architectCeilingArmstrong,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    ButtonSegment(
                      value: SuspendedCeilingType.gypsumBoard,
                      label: Text(
                        l.architectCeilingGypsum,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  selected: {effectiveType},
                  onSelectionChanged: (s) => onTypeChanged(s.first),
                ),
                if (selected == null) ...[
                  const SizedBox(width: 6),
                  SegmentedButton<bool>(
                    key: const ValueKey('ceiling-mode-toggle'),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(
                          l.architectCeilingModeRoom,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(
                          l.architectCeilingModePolygon,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: {fromRoom},
                    onSelectionChanged: (s) => onFromRoomChanged(s.first),
                  ),
                ],
                const SizedBox(width: 4),
                _stepper(
                  key: 'ceiling-drop-stepper',
                  tooltip: l.architectCeilingDropLabel,
                  text: clearText,
                  warn: metrics?.hasAnyConflict ?? false,
                  onMinus: () =>
                      onDropChanged((effectiveDrop - 0.05).clamp(0.05, 2.0)),
                  onPlus: () =>
                      onDropChanged((effectiveDrop + 0.05).clamp(0.05, 2.0)),
                ),
                if (selected != null &&
                    effectiveType == SuspendedCeilingType.armstrong) ...[
                  IconButton(
                    key: const ValueKey('ceiling-center-grid'),
                    tooltip: l.architectCeilingCenterGrid,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onCenterGrid,
                    icon: const AppIcon(
                      AppIconId.alignCenter,
                      size: 18,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('ceiling-pick-origin'),
                    tooltip: l.architectCeilingPickOrigin,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onTogglePickOrigin,
                    icon: Icon(
                      Icons.gps_fixed_rounded,
                      size: 18,
                      color: pickingGridOrigin
                          ? const Color(0xFFFFAB00)
                          : Colors.white70,
                    ),
                  ),
                ],
                IconButton(
                  key: const ValueKey('ceiling-draft-properties'),
                  tooltip: l.architectProperties,
                  constraints: const BoxConstraints.tightFor(
                    width: 38,
                    height: 38,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onProperties,
                  icon: const AppIcon(AppIconId.properties, size: 18),
                ),
                if (selected == null && !fromRoom && pointCount > 0) ...[
                  IconButton(
                    key: const ValueKey('ceiling-draft-undo'),
                    tooltip: l.undoAction,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onUndo,
                    icon: const AppIcon(AppIconId.undo, size: 18),
                  ),
                  IconButton(
                    key: const ValueKey('ceiling-draft-finish'),
                    tooltip: l.applyAction,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: canFinish ? onFinish : null,
                    icon: AppIcon(
                      AppIconId.confirm,
                      size: 18,
                      color: canFinish ? const Color(0xFF22C55E) : null,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('ceiling-draft-cancel'),
                    tooltip: l.cancel,
                    constraints: const BoxConstraints.tightFor(
                      width: 38,
                      height: 38,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onCancel,
                    icon: const AppIcon(AppIconId.close, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
