// === SECTION: ARCHITECTURAL TOOL PALETTE BAR ===
import 'package:flutter/material.dart';
import 'architect_wall_type_label.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_wall_type.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';

/// Responsive bottom bar for architectural drafting tools and contextual sub-options.
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
  final List<ArchitectWallType>? wallTypes;
  final ArchitectWallType? activeWallType;
  final ValueChanged<ArchitectWallType>? onWallTypeSelected;

  // Door options
  final double doorWidth;
  final ValueChanged<double> onDoorWidthChanged;
  final double doorHeight;
  final ValueChanged<double> onDoorHeightChanged;
  final double doorSill;
  final ValueChanged<double> onDoorSillChanged;
  final bool isHingeLeft;
  final ValueChanged<bool> onHingeSideChanged;

  // Window options
  final double windowWidth;
  final ValueChanged<double>? onWindowWidthChanged;
  final double windowHeight;
  final ValueChanged<double>? onWindowHeightChanged;
  final double windowSill;
  final ValueChanged<double>? onWindowSillChanged;

  // Column options
  final ColumnShape columnShape;
  final ValueChanged<ColumnShape>? onColumnShapeChanged;
  final double columnWidth;
  final ValueChanged<double>? onColumnWidthChanged;
  final double columnDepth;
  final ValueChanged<double>? onColumnDepthChanged;

  // Beam options
  final double beamWidth;
  final ValueChanged<double>? onBeamWidthChanged;
  final double beamDepth;
  final ValueChanged<double>? onBeamDepthChanged;

  // Stair options
  final double stairWidth;
  final ValueChanged<double>? onStairWidthChanged;
  final int stairSteps;
  final ValueChanged<int>? onStairStepsChanged;

  // Opening options
  final OpeningType openingType;
  final ValueChanged<OpeningType>? onOpeningTypeChanged;

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
    this.wallTypes,
    this.activeWallType,
    this.onWallTypeSelected,
    required this.doorWidth,
    required this.onDoorWidthChanged,
    required this.doorHeight,
    required this.onDoorHeightChanged,
    required this.doorSill,
    required this.onDoorSillChanged,
    required this.isHingeLeft,
    required this.onHingeSideChanged,
    this.windowWidth = 1.20,
    this.onWindowWidthChanged,
    this.windowHeight = 1.40,
    this.onWindowHeightChanged,
    this.windowSill = 0.85,
    this.onWindowSillChanged,
    this.columnShape = ColumnShape.rectangular,
    this.onColumnShapeChanged,
    this.columnWidth = 0.25,
    this.onColumnWidthChanged,
    this.columnDepth = 0.25,
    this.onColumnDepthChanged,
    this.beamWidth = 0.25,
    this.onBeamWidthChanged,
    this.beamDepth = 0.50,
    this.onBeamDepthChanged,
    this.stairWidth = 1.10,
    this.onStairWidthChanged,
    this.stairSteps = 16,
    this.onStairStepsChanged,
    this.openingType = OpeningType.shaft,
    this.onOpeningTypeChanged,
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
              _buildDoorSubBar(context)
            else if (activeTool == ArchitectTool.window)
              _buildWindowSubBar(context)
            else if (activeTool == ArchitectTool.column)
              _buildColumnSubBar(context)
            else if (activeTool == ArchitectTool.beam)
              _buildBeamSubBar(context)
            else if (activeTool == ArchitectTool.stair)
              _buildStairSubBar(context)
            else if (activeTool == ArchitectTool.opening)
              _buildOpeningSubBar(context),

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
                    tool: ArchitectTool.window,
                    icon: Icons.window_rounded,
                    label: l10n.architectToolWindow,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.column,
                    icon: Icons.view_column_rounded,
                    label: l10n.architectToolColumn,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.beam,
                    icon: Icons.horizontal_rule_rounded,
                    label: l10n.architectToolBeam,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.slab,
                    icon: Icons.layers_rounded,
                    label: l10n.architectToolSlab,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.opening,
                    icon: Icons.crop_free_rounded,
                    label: l10n.architectToolOpening,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.stair,
                    icon: Icons.stairs_rounded,
                    label: l10n.architectToolStair,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.zone,
                    icon: Icons.space_dashboard_rounded,
                    label: l10n.architectToolZone,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.dimension,
                    icon: Icons.straighten_rounded,
                    label: l10n.architectToolDimension,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.level,
                    icon: Icons.change_history_rounded,
                    label: l10n.architectToolLevel,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.text,
                    icon: Icons.title_rounded,
                    label: l10n.architectToolText,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.cadLine,
                    icon: Icons.timeline_rounded,
                    label: l10n.architectToolCadLine,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.cadRect,
                    icon: Icons.crop_square_rounded,
                    label: l10n.architectToolCadRect,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.cadCircle,
                    icon: Icons.radio_button_unchecked_rounded,
                    label: l10n.architectToolCadCircle,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.axis,
                    icon: Icons.grid_on_rounded,
                    label: l10n.architectToolAxis,
                  ),
                  _buildToolButton(
                    tool: ArchitectTool.measure,
                    icon: Icons.square_foot_rounded,
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12.5,
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
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectWallThickness,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          if (wallTypes != null && wallTypes!.isNotEmpty)
            for (final wt in wallTypes!)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  avatar: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: wt.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  label: Text(wt.compactLabel(l10n)),
                  selected:
                      activeWallType?.id == wt.id ||
                      (activeWallType == null &&
                          (wallThickness - wt.totalThickness).abs() < 1e-3),
                  onSelected: (sel) {
                    if (sel) {
                      onWallTypeSelected?.call(wt);
                      onWallThicknessChanged(wt.totalThickness);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                ),
              )
          else
            for (final t in [0.12, 0.15, 0.20, 0.25, 0.38])
              Padding(
                padding: const EdgeInsets.only(right: 4),
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
          ChoiceChip(
            avatar: const Icon(Icons.show_chart_rounded, size: 14),
            label: Text(l10n.architectWallSingle),
            selected: wallMode == WallDraftingMode.singleLine,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.singleLine);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            avatar: const Icon(Icons.linear_scale_rounded, size: 14),
            label: Text(l10n.architectWallChained),
            selected: wallMode == WallDraftingMode.chained,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.chained);
            },
            visualDensity: VisualDensity.compact,
          ),
          if (isChainingWall && onFinishChainedWall != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              backgroundColor: const Color(0xFF00E5FF),
              avatar: const Icon(
                Icons.check_rounded,
                size: 14,
                color: Colors.black,
              ),
              label: Text(
                l10n.architectFinishChained,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onFinishChainedWall,
              visualDensity: VisualDensity.compact,
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
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectDoorWidth,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final w in [0.70, 0.80, 0.90, 1.00, 1.20])
            Padding(
              padding: const EdgeInsets.only(right: 4),
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
          ChoiceChip(
            label: Text(
              isHingeLeft
                  ? l10n.architectDoorHingeLeft
                  : l10n.architectDoorHingeRight,
            ),
            selected: true,
            onSelected: (_) => onHingeSideChanged(!isHingeLeft),
            avatar: const Icon(Icons.swap_horiz_rounded, size: 14),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectWindowWidth,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final w in [0.60, 0.90, 1.20, 1.40, 1.80, 2.00])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${(w * 100).round()} cm'),
                selected: (windowWidth - w).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onWindowWidthChanged?.call(w);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectWindowSill,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final s in [0.00, 0.85, 0.90])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(s == 0.0 ? '0' : '${(s * 100).round()} cm'),
                selected: (windowSill - s).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onWindowSillChanged?.call(s);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColumnSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.crop_square_rounded, size: 14),
            label: Text(l10n.architectColumnRect),
            selected: columnShape == ColumnShape.rectangular,
            onSelected: (sel) {
              if (sel) onColumnShapeChanged?.call(ColumnShape.rectangular);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            avatar: const Icon(Icons.circle_outlined, size: 14),
            label: Text(l10n.architectColumnCircle),
            selected: columnShape == ColumnShape.circular,
            onSelected: (sel) {
              if (sel) onColumnShapeChanged?.call(ColumnShape.circular);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectColumnSize,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final sz in [0.25, 0.30, 0.40])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${(sz * 100).round()} cm'),
                selected: (columnWidth - sz).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) {
                    onColumnWidthChanged?.call(sz);
                    onColumnDepthChanged?.call(sz);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBeamSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectBeamSize,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final sz in [(0.25, 0.40), (0.25, 0.50), (0.25, 0.60)])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(
                  '${(sz.$1 * 100).round()}x${(sz.$2 * 100).round()} cm',
                ),
                selected:
                    (beamWidth - sz.$1).abs() < 1e-3 &&
                    (beamDepth - sz.$2).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) {
                    onBeamWidthChanged?.call(sz.$1);
                    onBeamDepthChanged?.call(sz.$2);
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStairSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectStairWidth,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final w in [1.00, 1.10, 1.20])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${(w * 100).round()} cm'),
                selected: (stairWidth - w).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onStairWidthChanged?.call(w);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectStairSteps,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final n in [14, 16, 18])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('$n'),
                selected: stairSteps == n,
                onSelected: (sel) {
                  if (sel) onStairStepsChanged?.call(n);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpeningSubBar(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        ChoiceChip(
          avatar: const Icon(Icons.crop_square_rounded, size: 14),
          label: Text(l10n.architectOpeningShaft),
          selected: openingType == OpeningType.shaft,
          onSelected: (sel) {
            if (sel) onOpeningTypeChanged?.call(OpeningType.shaft);
          },
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          avatar: const Icon(Icons.fullscreen_exit_rounded, size: 14),
          label: Text(l10n.architectOpeningVoid),
          selected: openingType == OpeningType.floorVoid,
          onSelected: (sel) {
            if (sel) onOpeningTypeChanged?.call(OpeningType.floorVoid);
          },
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildZoneSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
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
