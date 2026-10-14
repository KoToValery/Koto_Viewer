// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. ARCHITECT GRID AXIS DRAFTING BAR (WIDGET)
// ===================================

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_grid_axis_tool.dart';

// === SECTION: ARCHITECT GRID AXIS DRAFTING BAR ===

/// Responsive floating HUD bar displayed while the Axis tool is active.
/// Provides quick access to re-sequencing, extent alignment, and status.
class ArchitectGridAxisBar extends StatelessWidget {
  final ArchitectGridAxisTool tool;
  final int axisCount;
  final VoidCallback onResequence;
  final VoidCallback onAlignAll;
  final VoidCallback? onGenerateFromWalls;

  const ArchitectGridAxisBar({
    super.key,
    required this.tool,
    required this.axisCount,
    required this.onResequence,
    required this.onAlignAll,
    this.onGenerateFromWalls,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tool,
      builder: (context, child) => _buildContents(context),
    );
  }

  Widget _buildContents(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC62828).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: l10n.architectAxisDrawPrompt,
              child: Row(
                children: [
                  const Icon(
                    Icons.grid_on_rounded,
                    color: Color(0xFFFF5252),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.architectToolAxis,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$axisCount',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          if (onGenerateFromWalls != null)
            IconButton(
              key: const ValueKey('architect-axes-from-walls'),
              tooltip: l10n.architectAxesFromWallsHelp,
              icon: const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
              onPressed: onGenerateFromWalls,
            ),
          IconButton(
            key: const ValueKey('architect-axes-resequence'),
            tooltip: l10n.resequenceGridAxesAction,
            icon: const Icon(
              Icons.format_list_numbered_rounded,
              color: Colors.cyanAccent,
            ),
            onPressed: onResequence,
          ),
          IconButton(
            key: const ValueKey('architect-axes-align'),
            tooltip: l10n.alignGridAxesAction,
            icon: const Icon(
              Icons.align_horizontal_left_rounded,
              color: Colors.white70,
            ),
            onPressed: onAlignAll,
          ),
        ],
      ),
    );
  }
}
