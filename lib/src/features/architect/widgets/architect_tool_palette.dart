import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';

/// Responsive bottom bar for active architectural drafting tools and contextual sub-options.
class ArchitectToolPalette extends StatelessWidget {
  final ArchitectTool activeTool;
  final ValueChanged<ArchitectTool> onToolChanged;

  // Zone options
  final ArchitectZoneCategory activeZoneCategory;
  final ValueChanged<ArchitectZoneCategory> onZoneCategoryChanged;

  // Wall options
  final double wallThickness;
  final ValueChanged<double> onWallThicknessChanged;
  final WallDraftingMode wallMode;
  final ValueChanged<WallDraftingMode> onWallModeChanged;
  final bool isChainingWall;
  final VoidCallback? onFinishChainedWall;

  // Door options
  final double doorWidth;
  final ValueChanged<double> onDoorWidthChanged;
  final double doorHeight;
  final ValueChanged<double> onDoorHeightChanged;
  final double doorSill;
  final ValueChanged<double> onDoorSillChanged;
  final bool isHingeLeft;
  final ValueChanged<bool> onHingeSideChanged;

  const ArchitectToolPalette({
    super.key,
    required this.activeTool,
    required this.onToolChanged,
    this.activeZoneCategory = ArchitectZoneCategory.living,
    required this.onZoneCategoryChanged,
    required this.wallThickness,
    required this.onWallThicknessChanged,
    required this.wallMode,
    required this.onWallModeChanged,
    this.isChainingWall = false,
    this.onFinishChainedWall,
    required this.doorWidth,
    required this.onDoorWidthChanged,
    required this.doorHeight,
    required this.onDoorHeightChanged,
    required this.doorSill,
    required this.onDoorSillChanged,
    required this.isHingeLeft,
    required this.onHingeSideChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF5181A22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contextual Sub-bar for Active Tool parameters
            if (activeTool == ArchitectTool.zone)
              _buildZoneSubBar(context)
            else if (activeTool == ArchitectTool.wall)
              _buildWallSubBar(context)
            else if (activeTool == ArchitectTool.door)
              _buildDoorSubBar(context),

            const SizedBox(height: 6),

            // Main Tools Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildToolButton(
                    tool: ArchitectTool.select,
                    icon: Icons.pan_tool_rounded,
                    label: l10n.architectToolSelect,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.zone,
                    icon: Icons.space_dashboard_rounded,
                    label: l10n.architectToolZone,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.wall,
                    icon: Icons.line_weight_rounded,
                    label: l10n.architectToolWall,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.door,
                    icon: Icons.meeting_room_rounded,
                    label: l10n.architectToolDoor,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.measure,
                    icon: Icons.straighten_rounded,
                    label: l10n.architectToolMeasure,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required ArchitectTool tool,
    required IconData icon,
    required String label,
  }) {
    final isSelected = activeTool == tool;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: isSelected
            ? const Color(0xFF00E5FF).withValues(alpha: 0.22)
            : const Color(0xFF262630),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => onToolChanged(tool),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.12),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWallSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Wall Thickness Chips
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectWallThickness,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          for (final t in [0.12, 0.25, 0.38])
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text('${(t * 100).round()} cm'),
                selected: (wallThickness - t).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onWallThicknessChanged(t);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 8),
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 8),

          // Single vs Chained Mode
          ChoiceChip(
            label: Text(l10n.architectWallSingle),
            selected: wallMode == WallDraftingMode.singleLine,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.singleLine);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 5),
          ChoiceChip(
            label: Text(l10n.architectWallChained),
            selected: wallMode == WallDraftingMode.chained,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.chained);
            },
            visualDensity: VisualDensity.compact,
          ),

          if (isChainingWall && onFinishChainedWall != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(l10n.architectFinishChained),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onFinishChainedWall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoorSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Prompt Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x3300E5FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00E5FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 14,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.architectDoorSelectWallPrompt,
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Width Presets
          for (final w in [0.80, 0.90, 1.00])
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text('${(w * 100).round()} cm'),
                selected: (doorWidth - w).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onDoorWidthChanged(w);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 6),

          // Sill Presets (0 vs 15cm)
          ChoiceChip(
            label: const Text('hp = 0'),
            selected: doorSill == 0.0,
            onSelected: (sel) {
              if (sel) onDoorSillChanged(0.0);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 5),
          ChoiceChip(
            label: const Text('h = 15 cm'),
            selected: doorSill == 0.15,
            onSelected: (sel) {
              if (sel) onDoorSillChanged(0.15);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),

          // Hinge Side
          ChoiceChip(
            label: Text(isHingeLeft
                ? l10n.architectDoorHingeLeft
                : l10n.architectDoorHingeRight),
            selected: true,
            onSelected: (_) => onHingeSideChanged(!isHingeLeft),
            avatar: const Icon(Icons.swap_horiz_rounded, size: 14),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Point-by-point prompt badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33FFA726),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFFA726)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.polyline_rounded,
                  size: 14,
                  color: Color(0xFFFFA726),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.architectZoneDrawPrompt,
                  style: const TextStyle(
                    color: Color(0xFFFFA726),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Zone category selection chips
          for (final cat in ArchitectZoneCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                avatar: Icon(cat.icon, size: 14, color: cat.color),
                label: Text(cat.defaultBgName),
                selected: activeZoneCategory == cat,
                onSelected: (sel) {
                  if (sel) onZoneCategoryChanged(cat);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
