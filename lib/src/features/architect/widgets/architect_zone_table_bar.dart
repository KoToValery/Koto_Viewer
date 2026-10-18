import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_TABLE_BAR ===
//    - ArchitectZoneTableBar (StatelessWidget)
//      * HUD bar for placing and managing the room finish schedule on the drawing
// =============================================================================

// === SECTION: ZONE_TABLE_BAR ===

/// Floating architectural HUD bar displayed when the Zone Table tool is active.
/// Guides the user to click on the drawing to place or reposition the compact room table,
/// or remove it from the active storey.
class ArchitectZoneTableBar extends StatelessWidget {
  final bool isTablePlaced;
  final VoidCallback onBackToZones;
  final VoidCallback onOpenScheduleDialog;
  final VoidCallback onRemoveTable;
  final VoidCallback onClose;

  const ArchitectZoneTableBar({
    super.key,
    required this.isTablePlaced,
    required this.onBackToZones,
    required this.onOpenScheduleDialog,
    required this.onRemoveTable,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE161A26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Title, Hint & Actions Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0x3300E5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF00E5FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.architectZoneTableBarTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isTablePlaced
                          ? l10n.architectZoneTableBarMoveHint
                          : l10n.architectZoneTableBarHint,
                      style: TextStyle(
                        color: isTablePlaced
                            ? const Color(0xFF00E676)
                            : const Color(0xFF00E5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action: Full Schedule Dialog
              IconButton(
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
                tooltip: l10n.architectZoneScheduleTitle,
                onPressed: onOpenScheduleDialog,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // Action: Remove Table if placed
              if (isTablePlaced) ...[
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: l10n.architectZoneTableRemove,
                  onPressed: onRemoveTable,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],

              // Action: Return to Zones
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  backgroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.space_dashboard_rounded, size: 14),
                label: Text(
                  l10n.architectZoneTableBackToZones,
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: onBackToZones,
              ),
              const SizedBox(width: 4),

              // Close
              IconButton(
                tooltip: l10n.close,
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
