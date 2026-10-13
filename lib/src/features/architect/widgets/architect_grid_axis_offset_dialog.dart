// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. ARCHITECT GRID AXIS OFFSET DIALOG (SHOW FUNCTION & WIDGET)
// 3. DELETE PREVIOUS AXIS CONFIRMATION DIALOG
// ===================================

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_axis.dart';
import '../../bim_editing/widgets/bim_offset_dialog.dart';

/// The shared compact dialog enters a distance; direction comes from canvas.
Future<void> showArchitectGridAxisOffsetDialog({
  required BuildContext context,
  required double unitToMeters,
  required String unitSymbol,
  required void Function(double distance) onStartDragMode,
}) async {
  final distance = await showBimOffsetDialog(
    context,
    unitToMeters: unitToMeters,
    unitSymbol: unitSymbol,
    inputKey: const ValueKey('architect-offset-distance'),
  );
  if (distance != null && context.mounted) onStartDragMode(distance);
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
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF00E5FF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.offsetCreatedTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
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
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            l10n.deletePrevious,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}
