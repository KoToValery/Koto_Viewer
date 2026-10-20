import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import '../services/architect_zone_tool.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ZONE_DRAFTING_BAR ===
//    - ArchitectZoneDraftingBar (StatelessWidget)
//      * Mode toggle: Auto (1-Click) vs Manual (Points)
//      * Room category preset dropdown selector (Space-efficient, localized)
//      * Schedule table & place table actions
//      * Live manual drafting metrics (points, length, live area, undo, finish)
// =============================================================================

// === SECTION: ZONE_DRAFTING_BAR ===

/// Floating architectural HUD bar displayed when the Zone / Rooms tool is active.
/// Optimized for mobile screens with zero horizontal overflow:
/// - Mode toggle: Auto 1-click room detection vs Manual point-by-point
/// - Predefined room presets in a compact dropdown menu (zero hardcoded names)
/// - One-tap access to Room Schedule table and drawing placement
class ArchitectZoneDraftingBar extends StatelessWidget {
  final ArchitectZoneTool tool;
  final ArchitectZonePresets zonePresets;
  final ArchitectZoneCategory category;
  final ValueChanged<ArchitectZoneCategory>? onCategoryChanged;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback? onOpenScheduleTable;
  final VoidCallback? onPlaceTable;

  const ArchitectZoneDraftingBar({
    super.key,
    this.zonePresets = const ArchitectZonePresets(),
    required this.tool,
    required this.category,
    this.onCategoryChanged,
    required this.onClose,
    required this.onUndo,
    required this.onCancel,
    this.onOpenScheduleTable,
    this.onPlaceTable,
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
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xF21C1E28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelfIntersecting
              ? const Color(0xFFFF5252)
              : category.color.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Row: Mode Toggle + Category Dropdown + Schedule & Close Actions
          Row(
            children: [
              // Mode Toggle (Auto 1-Click vs Manual)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      icon: Icons.auto_awesome_rounded,
                      label: l10n.architectZoneModeAuto,
                      isSelected: isAuto,
                      selectedColor: const Color(0xFF00E5FF),
                      onTap: () {
                        tool.placementMode =
                            ArchitectZonePlacementMode.autoClick;
                      },
                    ),
                    _buildModeButton(
                      icon: Icons.touch_app_outlined,
                      label: l10n.architectZoneModeManual,
                      isSelected: !isAuto,
                      selectedColor: const Color(0xFFFFB74D),
                      onTap: () {
                        tool.placementMode =
                            ArchitectZonePlacementMode.manualPoints;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Category Selector Dropdown (Compact, space-efficient, zero hardcoded names)
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: category.color.withValues(alpha: 0.5),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ArchitectZoneCategory>(
                      value: category,
                      isDense: true,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E2230),
                      borderRadius: BorderRadius.circular(10),
                      icon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      items: ArchitectZoneCategory.values.map((cat) {
                        return DropdownMenuItem<ArchitectZoneCategory>(
                          value: cat,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.icon, size: 15, color: cat.color),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  zonePresets.categoryName(cat, l10n),
                                  style: TextStyle(
                                    color: cat == category
                                        ? cat.color
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newCat) {
                        if (newCat != null) {
                          onCategoryChanged?.call(newCat);
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Open Schedule Dialog action
              if (onOpenScheduleTable != null)
                IconButton(
                  tooltip: l10n.architectZoneScheduleTitle,
                  icon: const Icon(
                    Icons.table_chart_rounded,
                    color: Color(0xFF38BDF8),
                    size: 19,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenScheduleTable,
                ),

              // Place Table on canvas action
              if (onPlaceTable != null)
                IconButton(
                  tooltip: l10n.architectZoneTableActionPlace,
                  icon: const Icon(
                    Icons.table_view_rounded,
                    color: Color(0xFF00E5FF),
                    size: 19,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: onPlaceTable,
                ),

              // Cancel drafting / exit
              IconButton(
                tooltip: l10n.architectZoneCancelDraft,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 19,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: onCancel,
              ),
            ],
          ),

          const SizedBox(height: 5),

          // 2. Sub-Row: Guidance or Live Manual Drafting Controls
          if (isSelfIntersecting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x33FF5252),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF5252),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      l10n.architectZoneSelfIntersectError,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else if (isAuto)
            // Auto Mode Prompt Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x2200E5FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x4400E5FF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.ads_click_rounded,
                    color: Color(0xFF00E5FF),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.architectZoneAutoPrompt,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            // Manual Mode: Points counter, segment length, live area, Undo, Finish
            Row(
              children: [
                _buildMetricChip(
                  icon: Icons.scatter_plot_rounded,
                  label: '${tool.draftPointCount}',
                  color: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 4),

                if (tool.activeSegmentLength != null) ...[
                  _buildMetricChip(
                    icon: Icons.straighten_rounded,
                    label: '${tool.activeSegmentLength!.toStringAsFixed(2)} m',
                    subLabel: tool.orthoLabel,
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(width: 4),
                ],

                if (tool.draftPointCount >= 2) ...[
                  _buildMetricChip(
                    icon: Icons.crop_free_rounded,
                    label: '${tool.liveArea.toStringAsFixed(1)} m²',
                    color: const Color(0xFF69F0AE),
                  ),
                  const SizedBox(width: 4),
                ],

                const Spacer(),

                // Undo point button
                IconButton(
                  tooltip: l10n.architectZoneUndoPoint,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  color: tool.draftPointCount > 0
                      ? const Color(0xFFFFB74D)
                      : Colors.white24,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: tool.draftPointCount > 0 ? onUndo : null,
                ),
                const SizedBox(width: 6),

                // Finish / Close zone button
                InkWell(
                  onTap: canClose ? onClose : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: canClose
                          ? const Color(0xFF00E676)
                          : const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: canClose ? Colors.black : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.architectZoneClose,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: canClose ? Colors.black : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? selectedColor : Colors.white60,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedColor : Colors.white70,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x6610121A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subLabel != null) ...[
            const SizedBox(width: 2),
            Text(
              subLabel,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
