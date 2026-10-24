// === SECTION: FLOOR DRAIN BAR ===
// Compact one-row control for the drain tool: shape, fall, size and (while
// outlining) the floor source with undo / confirm / cancel.

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_floor_drain.dart';
import '../services/architect_floor_drain_geometry.dart';

class ArchitectFloorDrainBar extends StatelessWidget {
  final ArchitectDrainShape shape;
  final double size;
  final double width;
  final double slopePercent;
  final Set<ArchitectDrainIssue> issues;

  /// Null while editing a placed drain (no floor source / drafting buttons).
  final bool? fromRoom;
  final int pointCount;
  final ValueChanged<ArchitectDrainShape> onShape;
  final ValueChanged<double> onSize;
  final ValueChanged<double> onWidth;
  final ValueChanged<double> onSlope;
  final ValueChanged<bool>? onFromRoom;
  final VoidCallback? onUndo;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ArchitectFloorDrainBar({
    super.key,
    required this.shape,
    required this.size,
    required this.width,
    required this.slopePercent,
    required this.onShape,
    required this.onSize,
    required this.onWidth,
    required this.onSlope,
    this.issues = const {},
    this.fromRoom,
    this.pointCount = 0,
    this.onFromRoom,
    this.onUndo,
    this.onConfirm,
    this.onCancel,
  });

  bool get _linear => shape == ArchitectDrainShape.linear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.sizeOf(context).width;
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
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: l.architectDrainHint,
                  child: const Icon(Icons.water_drop_outlined, size: 18),
                ),
                const SizedBox(width: 6),
                SegmentedButton<ArchitectDrainShape>(
                  key: const ValueKey('drain-shape'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  segments: [
                    ButtonSegment(
                      value: ArchitectDrainShape.round,
                      label: Text(l.architectDrainRound),
                    ),
                    ButtonSegment(
                      value: ArchitectDrainShape.linear,
                      label: Text(l.architectDrainLinear),
                    ),
                  ],
                  selected: {shape},
                  onSelectionChanged: (s) => onShape(s.first),
                ),
                _stepper(
                  key: 'drain-slope',
                  tooltip: l.architectDrainSlope,
                  text: '${_fmt(slopePercent)}%',
                  onMinus: () => onSlope(
                    (slopePercent - 0.5).clamp(
                      ArchitectDrainDefaults.slopeMin,
                      ArchitectDrainDefaults.slopeMax,
                    ),
                  ),
                  onPlus: () => onSlope(
                    (slopePercent + 0.5).clamp(
                      ArchitectDrainDefaults.slopeMin,
                      ArchitectDrainDefaults.slopeMax,
                    ),
                  ),
                ),
                _stepper(
                  key: 'drain-size',
                  tooltip: _linear
                      ? l.architectDrainLength
                      : l.architectDrainDiameter,
                  text: '${_cm(size)} cm',
                  onMinus: () => onSize(_stepSize(-1)),
                  onPlus: () => onSize(_stepSize(1)),
                ),
                if (_linear)
                  _stepper(
                    key: 'drain-width',
                    tooltip: l.architectDrainWidth,
                    text: '${_cm(width)} cm',
                    onMinus: () => onWidth(
                      (width - 0.01).clamp(
                        ArchitectDrainDefaults.linearWidthMin,
                        ArchitectDrainDefaults.linearWidthMax,
                      ),
                    ),
                    onPlus: () => onWidth(
                      (width + 0.01).clamp(
                        ArchitectDrainDefaults.linearWidthMin,
                        ArchitectDrainDefaults.linearWidthMax,
                      ),
                    ),
                  ),
                if (fromRoom != null && onFromRoom != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: SegmentedButton<bool>(
                      key: const ValueKey('drain-source'),
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l.architectDrainOutline),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l.architectDrainFromRoom),
                        ),
                      ],
                      selected: {fromRoom!},
                      onSelectionChanged: (s) => onFromRoom!(s.first),
                    ),
                  ),
                if (issues.isNotEmpty)
                  Tooltip(
                    message: [
                      if (issues.contains(ArchitectDrainIssue.outsideFloor))
                        l.architectDrainOutsideFloor,
                      if (issues.contains(ArchitectDrainIssue.nearDoor))
                        l.architectDrainNearDoor,
                    ].join('\n'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Color(0xFFFFB74D),
                      ),
                    ),
                  ),
                if (onUndo != null)
                  IconButton(
                    key: const ValueKey('drain-undo'),
                    tooltip: l.undoAction,
                    icon: const Icon(Icons.undo),
                    onPressed: pointCount == 0 ? null : onUndo,
                  ),
                if (onConfirm != null)
                  IconButton(
                    key: const ValueKey('drain-confirm'),
                    tooltip: l.architectToolFloorDrain,
                    icon: const Icon(Icons.check),
                    color: const Color(0xFF66BB6A),
                    onPressed: pointCount >= 3 ? onConfirm : null,
                  ),
                if (onCancel != null)
                  IconButton(
                    key: const ValueKey('drain-cancel'),
                    tooltip: l.cancel,
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _stepSize(int direction) {
    final step = _linear ? 0.10 : 0.01;
    final min = _linear
        ? ArchitectDrainDefaults.linearMin
        : ArchitectDrainDefaults.roundMin;
    final max = _linear
        ? ArchitectDrainDefaults.linearMax
        : ArchitectDrainDefaults.roundMax;
    return (size + direction * step).clamp(min, max);
  }

  Widget _stepper({
    required String key,
    required String tooltip,
    required String text,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) => Tooltip(
    message: tooltip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('$key-minus'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 18),
          onPressed: onMinus,
        ),
        Text(text, style: const TextStyle(fontSize: 12)),
        IconButton(
          key: ValueKey('$key-plus'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 18),
          onPressed: onPlus,
        ),
      ],
    ),
  );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  static String _cm(double metres) => (metres * 100).round().toString();
}
