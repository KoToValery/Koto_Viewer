// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. ARCHITECT GRID AXIS OFFSET DIALOG (SHOW FUNCTION & WIDGET)
// 3. DELETE PREVIOUS AXIS CONFIRMATION DIALOG
// ===================================

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_axis.dart';

// === SECTION: SHOW FUNCTION & OFFSET DIALOG ===

/// Displays an interactive offset dialog for duplicating or moving [axis] by distance and direction.
Future<void> showArchitectGridAxisOffsetDialog({
  required BuildContext context,
  required StructuralGridAxis axis,
  required double initialDistance,
  required void Function(double distance, double directionSign) onApplyOffset,
  required void Function(double distance) onStartDragMode,
}) async {
  final controller = TextEditingController(text: initialDistance.toStringAsFixed(2));
  final isVertical = axis.isVertical;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final l10n = dialogCtx.l10n;
          double currentDist = double.tryParse(controller.text) ?? initialDistance;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.straighten_rounded, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.offsetWithDuplication(l10n.gridAxisTitle(axis.name)),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Distance input
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: l10n.distanceMeters,
                      labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                      suffixText: 'm',
                      suffixStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2)),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setDialogState(() {
                          currentDist = parsed;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Quick distance chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0].map((d) {
                      final isSel = (currentDist - d).abs() < 1e-3;
                      return ChoiceChip(
                        label: Text('${d.toStringAsFixed(1)} m'),
                        selected: isSel,
                        selectedColor: const Color(0xFF00E5FF),
                        backgroundColor: Colors.white12,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) {
                          controller.text = d.toStringAsFixed(2);
                          setDialogState(() {
                            currentDist = d;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Direction prompt
                  Text(
                    l10n.duplicationDirection,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Direction buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: const Color(0xFF00E5FF),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                            ),
                          ),
                          icon: Icon(isVertical ? Icons.arrow_back_rounded : Icons.arrow_upward_rounded, size: 16),
                          label: Text(
                            isVertical ? l10n.directionLeft : l10n.directionUp,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            final d = double.tryParse(controller.text) ?? currentDist;
                            Navigator.of(dialogCtx).pop();
                            onApplyOffset(d, isVertical ? -1.0 : 1.0);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: const Color(0xFF00E5FF),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                            ),
                          ),
                          icon: Icon(isVertical ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded, size: 16),
                          label: Text(
                            isVertical ? l10n.directionRight : l10n.directionDown,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            final d = double.tryParse(controller.text) ?? currentDist;
                            Navigator.of(dialogCtx).pop();
                            onApplyOffset(d, isVertical ? 1.0 : -1.0);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Drag mode button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.touch_app_outlined, size: 16),
                    label: Text(
                      l10n.specifyDirectionByDrag,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      final d = double.tryParse(controller.text) ?? currentDist;
                      Navigator.of(dialogCtx).pop();
                      onStartDragMode(d);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      );
    },
  );
}

// === SECTION: DELETE PREVIOUS AXIS CONFIRMATION DIALOG ===

/// Prompts whether to keep both axes or delete the original axis after duplication.
Future<bool> promptDeletePreviousAxisDialog({
  required BuildContext context,
  required StructuralGridAxis previousAxis,
}) async {
  final l10n = context.l10n;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF00E5FF), size: 20),
          const SizedBox(width: 8),
          Text(l10n.offsetCreatedTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: Text(
        l10n.deletePreviousAxisPrompt(previousAxis.name),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            l10n.keepBoth,
            style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.deletePrevious, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  return result ?? false;
}
