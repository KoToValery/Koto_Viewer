// === SECTION: TABLE OF CONTENTS ===
// 1. ArchitectRoofBar (Compact mobile HUD bar for roof drafting, Auto-Roof, slope, overhang & eaves switching)

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_tool.dart';

// === SECTION: ARCHITECT ROOF BAR ===

class ArchitectRoofBar extends StatelessWidget {
  final ArchitectRoofTool tool;
  final ArchitectRoofPlane? selectedRoof;
  final int? selectedEdgeIndex;
  final ValueChanged<AutoRoofType> onAutoRoof;
  final VoidCallback onOpenLayersDialog;
  final VoidCallback? onSwitchEavesEdge;
  final VoidCallback? onFlipSlopeDirection;
  final VoidCallback? onSetSelectedEdgeAsEaves;
  final ValueChanged<double>? onSelectedRoofSlopeChanged;
  final ValueChanged<double>? onSelectedRoofOverhangChanged;
  final VoidCallback? onFinishPolygon;
  final VoidCallback? onUndoDraftPoint;
  final VoidCallback? onCancelDraft;

  const ArchitectRoofBar({
    super.key,
    required this.tool,
    this.selectedRoof,
    this.selectedEdgeIndex,
    required this.onAutoRoof,
    required this.onOpenLayersDialog,
    this.onSwitchEavesEdge,
    this.onFlipSlopeDirection,
    this.onSetSelectedEdgeAsEaves,
    this.onSelectedRoofSlopeChanged,
    this.onSelectedRoofOverhangChanged,
    this.onFinishPolygon,
    this.onUndoDraftPoint,
    this.onCancelDraft,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final roof = selectedRoof;
    final currentSlope = roof?.slopeDegrees ?? tool.slopeDegrees;
    final currentOverhang = roof?.eavesOverhang ?? tool.eavesOverhang;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          key: const ValueKey('architect-roof-bar'),
          color: const Color(0xEE1E242C),
          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          shadowColor: Colors.black54,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (roof == null) ...[
                    // Draw mode toggle: Rect vs Poly
                    ChoiceChip(
                      key: const ValueKey('roof-mode-rect'),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.crop_landscape_rounded, size: 15),
                      label: Text(l.architectRoofDrawRect),
                      selected: tool.drawMode == RoofDrawMode.rectangle,
                      onSelected: (sel) {
                        if (sel) tool.setDrawMode(RoofDrawMode.rectangle);
                      },
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      key: const ValueKey('roof-mode-poly'),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.pentagon_outlined, size: 15),
                      label: Text(l.architectRoofDrawPoly),
                      selected: tool.drawMode == RoofDrawMode.polygon,
                      onSelected: (sel) {
                        if (sel) tool.setDrawMode(RoofDrawMode.polygon);
                      },
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      key: const ValueKey('roof-mode-multipitch'),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.polyline_rounded, size: 15),
                      label: Text(l.architectRoofDrawMultiPitch),
                      selected: tool.drawMode == RoofDrawMode.multiPitch,
                      onSelected: (sel) {
                        if (sel) tool.setDrawMode(RoofDrawMode.multiPitch);
                      },
                    ),
                    const SizedBox(width: 6),

                    // Auto-Roof menu button
                    PopupMenuButton<AutoRoofType>(
                      key: const ValueKey('roof-auto-menu'),
                      tooltip: l.architectRoofAuto,
                      color: const Color(0xFF262A34),
                      onSelected: onAutoRoof,
                      itemBuilder: (_) => [
                        for (final type in AutoRoofType.values)
                          PopupMenuItem(
                            key: ValueKey('roof-auto-${type.name}'),
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  switch (type) {
                                    AutoRoofType.gable => Icons.roofing_rounded,
                                    AutoRoofType.hip => Icons.change_history_rounded,
                                    AutoRoofType.shed => Icons.signal_cellular_4_bar_rounded,
                                    AutoRoofType.flat => Icons.horizontal_rule_rounded,
                                  },
                                  size: 18,
                                  color: const Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type.label(l),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_fix_high_rounded,
                              size: 15,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l.architectRoofAuto,
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: Color(0xFF00E5FF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    if (selectedEdgeIndex != null &&
                        (selectedEdgeIndex != roof.safeEavesEdgeIndex ||
                            roof.reverseSlope)) ...[
                      Tooltip(
                        message: l.architectRoofSetEavesHereTooltip,
                        child: ActionChip(
                          key: const ValueKey('roof-set-eaves-edge'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0x3300E676),
                          side: const BorderSide(color: Color(0xFF00E676)),
                          avatar: const Icon(
                            Icons.south_rounded,
                            size: 15,
                            color: Color(0xFF00E676),
                          ),
                          label: Text(
                            l.architectRoofSetEavesHere,
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: onSetSelectedEdgeAsEaves,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Selected roof: Rotate / Switch Eaves Edge button
                    Tooltip(
                      message: l.architectRoofSwitchEavesTooltip,
                      child: ActionChip(
                        key: const ValueKey('roof-switch-eaves'),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(
                          Icons.rotate_right_rounded,
                          size: 15,
                          color: Color(0xFF00E5FF),
                        ),
                        label: Text(l.architectRoofRotateSlope),
                        onPressed: onSwitchEavesEdge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Selected roof: Flip Slope 180° button
                    Tooltip(
                      message: l.architectRoofFlipSlopeTooltip,
                      child: ActionChip(
                        key: const ValueKey('roof-flip-slope'),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(
                          Icons.swap_vert_rounded,
                          size: 15,
                          color: Colors.amberAccent,
                        ),
                        label: Text(l.architectRoofFlipSlope),
                        onPressed: onFlipSlopeDirection,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (roof != null && roof.roofGroupId != null) ...[
                    Tooltip(
                      message: l.architectRoofLinkedSlopesTooltip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x3300E5FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00E5FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.link, size: 13, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 4),
                            Text(
                              l.architectRoofLinkedSlopes,
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Slope popup selector
                  PopupMenuButton<double>(
                    key: const ValueKey('roof-slope-menu'),
                    tooltip: l.architectRoofSlope,
                    color: const Color(0xFF262A34),
                    onSelected: (deg) {
                      if (roof != null) {
                        onSelectedRoofSlopeChanged?.call(deg);
                      } else {
                        tool.setSlopeDegrees(deg);
                      }
                    },
                    itemBuilder: (_) => [
                      for (final deg in [2.0, 12.0, 18.0, 22.0, 26.0, 30.0, 35.0, 45.0])
                        PopupMenuItem(
                          value: deg,
                          child: Text(
                            '${deg.toStringAsFixed(0)}°',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262A34),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.show_chart_rounded,
                            size: 14,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${l.architectRoofSlope} ${currentSlope.toStringAsFixed(0)}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Overhang popup selector
                  PopupMenuButton<double>(
                    key: const ValueKey('roof-overhang-menu'),
                    tooltip: l.architectRoofOverhang,
                    color: const Color(0xFF262A34),
                    onSelected: (overhang) {
                      if (roof != null) {
                        onSelectedRoofOverhangChanged?.call(overhang);
                      } else {
                        tool.setEavesOverhang(overhang);
                      }
                    },
                    itemBuilder: (_) => [
                      for (final ov in [0.0, 0.30, 0.40, 0.50, 0.60, 0.80, 1.00])
                        PopupMenuItem(
                          value: ov,
                          child: Text(
                            '${(ov * 100).round()} cm',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262A34),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.straighten_rounded,
                            size: 14,
                            color: Colors.cyanAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${l.architectRoofOverhang} ${(currentOverhang * 100).round()} cm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Layers & Timber Carpentry dialog button
                  ActionChip(
                    key: const ValueKey('roof-open-layers'),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(
                      Icons.carpenter_rounded,
                      size: 15,
                      color: Color(0xFFFFB74D),
                    ),
                    label: Text(l.architectRoofLayersShort),
                    onPressed: onOpenLayersDialog,
                  ),

                  // Polygon drafting controls when active
                  if (roof == null && tool.isDrafting) ...[
                    const SizedBox(width: 6),
                    if (tool.drawMode == RoofDrawMode.polygon &&
                        tool.draftPoints.length >= 3)
                      ActionChip(
                        key: const ValueKey('roof-poly-finish'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF2E7D32),
                        avatar: const Icon(
                          Icons.check,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: Text(
                          l.architectDimensionFinish,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: onFinishPolygon,
                      ),
                    IconButton(
                      key: const ValueKey('roof-draft-undo'),
                      visualDensity: VisualDensity.compact,
                      tooltip: l.architectZoneUndoAction,
                      icon: const Icon(
                        Icons.undo,
                        size: 18,
                        color: Colors.white70,
                      ),
                      onPressed: onUndoDraftPoint,
                    ),
                    IconButton(
                      key: const ValueKey('roof-draft-cancel'),
                      visualDensity: VisualDensity.compact,
                      tooltip: l.cancel,
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: onCancelDraft,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
