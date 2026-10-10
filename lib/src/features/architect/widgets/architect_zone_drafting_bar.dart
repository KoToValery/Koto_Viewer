import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../services/architect_zone_tool.dart';

/// Floating architectural HUD bar displayed during active point-by-point zone drafting.
/// Shows live vertex count, active segment length/angle, live area, self-intersection warnings,
/// and quick actions to close, undo, or cancel drafting.
class ArchitectZoneDraftingBar extends StatelessWidget {
  final ArchitectZoneTool tool;
  final ArchitectZoneCategory category;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onCancel;

  const ArchitectZoneDraftingBar({
    super.key,
    required this.tool,
    required this.category,
    required this.onClose,
    required this.onUndo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSelfIntersecting =
        tool.pointStatus == ZoneDraftingPointStatus.selfIntersects;
    final canClose = tool.canCloseDraft && !isSelfIntersecting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xF21C1E28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelfIntersecting
              ? const Color(0xFFFF5252)
              : category.color.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner if self-intersecting
          if (isSelfIntersecting)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FF5252),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF5252),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.architectZoneSelfIntersectError,
                        style: const TextStyle(
                          color: Color(0xFFFF5252),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main metrics and controls row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: category.color.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon, size: 14, color: category.color),
                      const SizedBox(width: 4),
                      Text(
                        category.defaultBgName,
                        style: TextStyle(
                          color: category.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Points count badge
                _buildMetricChip(
                  icon: Icons.scatter_plot_rounded,
                  label: l10n.architectZonePointsCount(tool.draftPointCount),
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 6),

                // Active Segment length badge
                if (tool.activeSegmentLength != null) ...[
                  _buildMetricChip(
                    icon: Icons.straighten_rounded,
                    label:
                        '${tool.activeSegmentLength!.toStringAsFixed(2)} m',
                    subLabel: tool.orthoLabel,
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(width: 6),
                ],

                // Live area badge (when >= 2 points)
                if (tool.draftPointCount >= 2) ...[
                  _buildMetricChip(
                    icon: Icons.crop_free_rounded,
                    label: '${tool.liveArea.toStringAsFixed(1)} m²',
                    color: const Color(0xFF69F0AE),
                  ),
                  const SizedBox(width: 10),
                ],

                // Action: Close Zone (Finish)
                ElevatedButton.icon(
                  onPressed: canClose ? onClose : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    l10n.architectZoneClose,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Action: Undo last point
                OutlinedButton.icon(
                  onPressed: tool.draftPointCount > 1 ? onUndo : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB74D),
                    side: BorderSide(
                      color: tool.draftPointCount > 1
                          ? const Color(0xFFFFB74D)
                          : Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 15),
                  label: Text(
                    l10n.architectZoneUndoPoint,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 6),

                // Action: Cancel
                IconButton(
                  tooltip: l10n.architectZoneCancelDraft,
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    String? subLabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x6610121A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
