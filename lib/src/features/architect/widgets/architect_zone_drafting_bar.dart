import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../services/architect_zone_tool.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_DRAFTING_BAR ===
//    - ArchitectZoneDraftingBar (StatelessWidget)
//      * Mode selector (Auto 1-click vs Manual point-by-point like slab)
//      * Live metrics (points count, length, area)
//      * Guidance prompt banner & self-intersection warning
//      * Schedule table button & quick actions
// =============================================================================

// === SECTION: ZONE_DRAFTING_BAR ===

/// Floating architectural HUD bar displayed when the Zone tool is active.
/// Supports 1-click auto-detection (default) and point-by-point slab-style drafting,
/// real-time metrics, room schedule access, and drafting actions.
class ArchitectZoneDraftingBar extends StatelessWidget {
  final ArchitectZoneTool tool;
  final ArchitectZoneCategory category;
  final ValueChanged<ArchitectZoneCategory>? onCategoryChanged;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback? onOpenScheduleTable;

  const ArchitectZoneDraftingBar({
    super.key,
    required this.tool,
    required this.category,
    this.onCategoryChanged,
    required this.onClose,
    required this.onUndo,
    required this.onCancel,
    this.onOpenScheduleTable,
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
    final isAuto = tool.placementMode == ArchitectZonePlacementMode.autoClick;
    final isSelfIntersecting =
        tool.pointStatus == ZoneDraftingPointStatus.selfIntersects;
    final canClose = tool.canCloseDraft && !isSelfIntersecting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          // 1. Top Row: Mode Selection (Auto 1-Click vs Manual) & Schedule Button
          Row(
            children: [
              // Auto vs Manual Mode Chips
              ChoiceChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: Text(
                  l10n.architectZoneModeAuto,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                selected: isAuto,
                selectedColor: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                onSelected: (sel) {
                  if (sel) {
                    tool.placementMode = ArchitectZonePlacementMode.autoClick;
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                avatar: const Icon(Icons.touch_app_outlined, size: 14),
                label: Text(
                  l10n.architectZoneModeManual,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                selected: !isAuto,
                selectedColor: const Color(0xFFFFB74D).withValues(alpha: 0.25),
                onSelected: (sel) {
                  if (sel) {
                    tool.placementMode = ArchitectZonePlacementMode.manualPoints;
                  }
                },
                visualDensity: VisualDensity.compact,
              ),

              const Spacer(),

              // Schedule Table button
              if (onOpenScheduleTable != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: Text(
                    l10n.architectZoneScheduleTitle,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onOpenScheduleTable,
                ),

              // Cancel button
              IconButton(
                tooltip: l10n.architectZoneCancelDraft,
                onPressed: onCancel,
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

          const SizedBox(height: 6),

          // 2. Guidance prompt banner
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
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isAuto
                      ? const Color(0x2600E5FF)
                      : (tool.draftPointCount == 0
                          ? category.color.withValues(alpha: 0.18)
                          : const Color(0x3300E5FF)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAuto
                        ? const Color(0x5500E5FF)
                        : (tool.draftPointCount == 0
                            ? category.color.withValues(alpha: 0.4)
                            : const Color(0x5500E5FF)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAuto
                          ? Icons.ads_click_rounded
                          : (tool.draftPointCount == 0
                              ? Icons.touch_app_rounded
                              : (canClose
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.edit_location_alt_rounded)),
                      color: isAuto
                          ? const Color(0xFF00E5FF)
                          : (tool.draftPointCount == 0
                              ? category.color
                              : (canClose
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFF00E5FF))),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAuto
                            ? l10n.architectZoneAutoPrompt
                            : (tool.draftPointCount == 0
                                ? l10n.architectZoneTapFirstPoint
                                : (canClose
                                    ? l10n.architectZonePointSnapStart
                                    : l10n.architectZoneNextPointPrompt(
                                        tool.draftPointCount + 1,
                                      ))),
                        style: TextStyle(
                          color: isAuto
                              ? const Color(0xFF00E5FF)
                              : (tool.draftPointCount == 0
                                  ? Colors.white
                                  : (canClose
                                      ? const Color(0xFF00E676)
                                      : Colors.white)),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Category & Metrics & Actions Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                        category.localizedName(l10n),
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

                // Manual point-by-point metrics & controls (like Slab element)
                if (!isAuto) ...[
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
                      label: '${tool.activeSegmentLength!.toStringAsFixed(2)} m',
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
                    const SizedBox(width: 8),
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
                    onPressed: tool.draftPointCount > 0 ? onUndo : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB74D),
                      side: BorderSide(
                        color: tool.draftPointCount > 0
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
                ],
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
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(width: 3),
            Text(
              subLabel,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
