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

  const ArchitectGridAxisBar({
    super.key,
    required this.tool,
    required this.axisCount,
    required this.onResequence,
    required this.onAlignAll,
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
          // Tool indicator icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.grid_on_rounded,
              color: Color(0xFFFF5252),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Title & prompt
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.architectToolAxis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$axisCount',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  l10n.architectAxisDrawPrompt,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Action 1: Resequence all axes
          InkWell(
            onTap: onResequence,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.format_list_numbered_rounded,
                    size: 14,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.resequenceGridAxesAction,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Action 2: Align all axes
          InkWell(
            onTap: onAlignAll,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.align_horizontal_left_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.alignGridAxesAction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
