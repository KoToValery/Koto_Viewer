// === SECTION: ARCHITECTURAL TOOL PALETTE BAR ===
import 'package:flutter/material.dart';
import 'architect_wall_type_label.dart';
import 'architect_stair_labels.dart';
import 'architect_component_labels.dart';
import 'component_dimensions_dialog.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_wall_type.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../rendering/architect_2d_painter.dart';

import "../services/component_library_service.dart";

enum ArchitectToolCategory {
  plan,
  build,
  structure,
  furnishing,
  views,
  annotations,
  drawing;

  String label(AppLocalizations l) => switch (this) {
    plan => l.architectCategoryPlan,
    build => l.architectCategoryBuild,
    structure => l.architectCategoryStructure,
    furnishing => l.architectFurnishing,
    views => l.architectCategoryViews,
    annotations => l.architectCategoryAnnotations,
    drawing => l.architectCategoryDrawing,
  };

  static ArchitectToolCategory of(ArchitectTool tool) => switch (tool) {
    ArchitectTool.select ||
    ArchitectTool.zone ||
    ArchitectTool.zoneTable ||
    ArchitectTool.axis => plan,
    ArchitectTool.wall ||
    ArchitectTool.door ||
    ArchitectTool.window ||
    ArchitectTool.opening ||
    ArchitectTool.stair => build,
    ArchitectTool.component => furnishing,
    ArchitectTool.column ||
    ArchitectTool.beam ||
    ArchitectTool.slab ||
    ArchitectTool.floorDrain ||
    ArchitectTool.roof => structure,
    ArchitectTool.section ||
    ArchitectTool.elevation => views,
    ArchitectTool.dimension ||
    ArchitectTool.level ||
    ArchitectTool.text ||
    ArchitectTool.measure => annotations,
    ArchitectTool.cadLine ||
    ArchitectTool.cadRect ||
    ArchitectTool.hatch ||
    ArchitectTool.cadCircle => drawing,
  };
}

/// Responsive bottom bar for architectural drafting tools and contextual sub-options.
class ArchitectToolPalette extends StatefulWidget {
  final ArchitectTool activeTool;
  final bool drawingOnly;
  final VoidCallback? onTerrain;
  final ValueChanged<ArchitectTool> onToolChanged;
  final bool multiSelect;
  final VoidCallback? onToggleMultiSelect;

  // Fenestration (Window & Door Editor) options
  final VoidCallback? onCreateFenestration;
  final ArchitectFenestrationStyle? activeWindowStyle;
  final ArchitectFenestrationStyle? activeDoorStyle;
  final ValueChanged<ArchitectFenestrationStyle>? onWindowStyleSelected;
  final ValueChanged<ArchitectFenestrationStyle>? onDoorStyleSelected;

  // Zone options
  final ArchitectZonePresets zonePresets;
  final ArchitectZoneCategory activeZoneCategory;
  final ValueChanged<ArchitectZoneCategory> onZoneCategoryChanged;

  // Wall options
  final double wallThickness;
  final ValueChanged<double> onWallThicknessChanged;
  final WallDraftingMode wallMode;
  final ValueChanged<WallDraftingMode> onWallModeChanged;
  final bool curvedWall;
  final VoidCallback? onArcWallSelected;
  final bool isChainingWall;
  final VoidCallback? onFinishChainedWall;
  final List<ArchitectWallType>? wallTypes;
  final ArchitectWallType? activeWallType;
  final ValueChanged<ArchitectWallType>? onWallTypeSelected;

  // Door options
  final double componentRotation;
  final VoidCallback? onRotateComponent;
  final VoidCallback? onOpenComponentLibrary;
  final VoidCallback? onOpenComponentStudio;
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

  final ArchitectStairDesign stairDesign;
  final ValueChanged<StairShape>? onStairShapeChanged;
  final VoidCallback? onStairProperties;

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
    this.zonePresets = const ArchitectZonePresets(),
    required this.activeTool,
    this.drawingOnly = false,
    this.onTerrain,
    required this.onToolChanged,
    this.multiSelect = false,
    this.onToggleMultiSelect,
    this.activeZoneCategory = ArchitectZoneCategory.living,
    required this.onZoneCategoryChanged,
    required this.wallThickness,
    required this.onWallThicknessChanged,
    required this.wallMode,
    required this.onWallModeChanged,
    this.curvedWall = false,
    this.onArcWallSelected,
    this.isChainingWall = false,
    this.onFinishChainedWall,
    this.wallTypes,
    this.activeWallType,
    this.onWallTypeSelected,
    this.onCreateFenestration,
    this.activeWindowStyle,
    this.activeDoorStyle,
    this.onWindowStyleSelected,
    this.onDoorStyleSelected,
    this.componentRotation = 0.0,
    this.onRotateComponent,
    this.onOpenComponentLibrary,
    this.onOpenComponentStudio,
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
    this.stairDesign = const ArchitectStairDesign(),
    this.onStairShapeChanged,
    this.onStairProperties,
    this.stairWidth = 1.10,
    this.onStairWidthChanged,
    this.stairSteps = 16,
    this.onStairStepsChanged,
    this.openingType = OpeningType.shaft,
    this.onOpeningTypeChanged,
  });

  @override
  State<ArchitectToolPalette> createState() => _ArchitectToolPaletteState();
}

class _ArchitectToolPaletteState extends State<ArchitectToolPalette> {
  late ArchitectToolCategory category = ArchitectToolCategory.of(
    widget.drawingOnly ? ArchitectTool.cadLine : widget.activeTool,
  );

  @override
  void didUpdateWidget(ArchitectToolPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drawingOnly &&
        category != ArchitectToolCategory.annotations &&
        category != ArchitectToolCategory.drawing) {
      category = ArchitectToolCategory.drawing;
    }
    if (widget.activeTool != oldWidget.activeTool &&
        widget.activeTool != ArchitectTool.select) {
      category = ArchitectToolCategory.of(widget.activeTool);
    }
  }

  ArchitectTool get activeTool => widget.activeTool;
  ValueChanged<ArchitectTool> get onToolChanged => widget.onToolChanged;
  VoidCallback? get onCreateFenestration => widget.onCreateFenestration;
  ArchitectFenestrationStyle? get activeWindowStyle => widget.activeWindowStyle;
  ArchitectFenestrationStyle? get activeDoorStyle => widget.activeDoorStyle;
  ValueChanged<ArchitectFenestrationStyle>? get onWindowStyleSelected =>
      widget.onWindowStyleSelected;
  ValueChanged<ArchitectFenestrationStyle>? get onDoorStyleSelected =>
      widget.onDoorStyleSelected;
  ArchitectZoneCategory get activeZoneCategory => widget.activeZoneCategory;
  ValueChanged<ArchitectZoneCategory> get onZoneCategoryChanged =>
      widget.onZoneCategoryChanged;
  double get wallThickness => widget.wallThickness;
  ValueChanged<double> get onWallThicknessChanged =>
      widget.onWallThicknessChanged;
  WallDraftingMode get wallMode => widget.wallMode;
  ValueChanged<WallDraftingMode> get onWallModeChanged =>
      widget.onWallModeChanged;
  bool get isChainingWall => widget.isChainingWall;
  VoidCallback? get onFinishChainedWall => widget.onFinishChainedWall;
  List<ArchitectWallType>? get wallTypes => widget.wallTypes;
  ArchitectWallType? get activeWallType => widget.activeWallType;
  ValueChanged<ArchitectWallType>? get onWallTypeSelected =>
      widget.onWallTypeSelected;
  double get doorWidth => widget.doorWidth;
  ValueChanged<double> get onDoorWidthChanged => widget.onDoorWidthChanged;
  double get doorHeight => widget.doorHeight;
  ValueChanged<double> get onDoorHeightChanged => widget.onDoorHeightChanged;
  double get doorSill => widget.doorSill;
  ValueChanged<double> get onDoorSillChanged => widget.onDoorSillChanged;
  bool get isHingeLeft => widget.isHingeLeft;
  ValueChanged<bool> get onHingeSideChanged => widget.onHingeSideChanged;
  double get windowWidth => widget.windowWidth;
  ValueChanged<double>? get onWindowWidthChanged => widget.onWindowWidthChanged;
  double get windowHeight => widget.windowHeight;
  ValueChanged<double>? get onWindowHeightChanged =>
      widget.onWindowHeightChanged;
  double get windowSill => widget.windowSill;
  ValueChanged<double>? get onWindowSillChanged => widget.onWindowSillChanged;
  ColumnShape get columnShape => widget.columnShape;
  ValueChanged<ColumnShape>? get onColumnShapeChanged =>
      widget.onColumnShapeChanged;
  double get columnWidth => widget.columnWidth;
  ValueChanged<double>? get onColumnWidthChanged => widget.onColumnWidthChanged;
  double get columnDepth => widget.columnDepth;
  ValueChanged<double>? get onColumnDepthChanged => widget.onColumnDepthChanged;
  double get beamWidth => widget.beamWidth;
  ValueChanged<double>? get onBeamWidthChanged => widget.onBeamWidthChanged;
  double get beamDepth => widget.beamDepth;
  ValueChanged<double>? get onBeamDepthChanged => widget.onBeamDepthChanged;
  double get stairWidth => widget.stairWidth;
  ValueChanged<double>? get onStairWidthChanged => widget.onStairWidthChanged;
  int get stairSteps => widget.stairSteps;
  ValueChanged<int>? get onStairStepsChanged => widget.onStairStepsChanged;
  OpeningType get openingType => widget.openingType;
  ValueChanged<OpeningType>? get onOpeningTypeChanged =>
      widget.onOpeningTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compactComponents =
        activeTool == ArchitectTool.component &&
        category == ArchitectToolCategory.furnishing;

    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF262630),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF5181A22),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: Colors.white12),
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
              else if (activeTool == ArchitectTool.component &&
                  !compactComponents)
                _buildComponentSubBar(context)
              else if (activeTool == ArchitectTool.opening)
                _buildOpeningSubBar(context)
              else if (activeTool == ArchitectTool.section || activeTool == ArchitectTool.elevation)
                _buildViewsSubBar(context),

              const SizedBox(height: 6),

              Row(
                children: [
                  IconButton(
                    key: const ValueKey('architect-tool-select'),
                    tooltip: l10n.architectToolSelect,
                    onPressed: () => onToolChanged(ArchitectTool.select),
                    icon: Icon(
                      Icons.pan_tool_rounded,
                      color: activeTool == ArchitectTool.select
                          ? Colors.cyanAccent
                          : Colors.white70,
                    ),
                  ),
                  if (widget.onToggleMultiSelect != null)
                    IconButton(
                      key: const ValueKey('architect-multi-select'),
                      tooltip: l10n.architectSelectionMulti,
                      isSelected: widget.multiSelect,
                      onPressed: widget.onToggleMultiSelect,
                      icon: Icon(
                        Icons.library_add_check_outlined,
                        color: widget.multiSelect
                            ? Colors.amber
                            : Colors.white70,
                      ),
                    ),
                  PopupMenuButton<ArchitectToolCategory>(
                    key: const ValueKey('architect-tool-category'),
                    tooltip: l10n.architectToolCategories,
                    initialValue: category,
                    onSelected: (value) {
                      setState(() => category = value);
                      if (value == ArchitectToolCategory.furnishing) {
                        widget.onToolChanged(ArchitectTool.component);
                        widget.onOpenComponentLibrary?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      for (final value in ArchitectToolCategory.values.where(
                        (c) =>
                            !widget.drawingOnly ||
                            c == ArchitectToolCategory.annotations ||
                            c == ArchitectToolCategory.drawing,
                      ))
                        PopupMenuItem(
                          value: value,
                          key: ValueKey('architect-category-${value.name}'),
                          child: Text(value.label(l10n)),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (compactComponents &&
                              MediaQuery.sizeOf(context).width < 600)
                            const Icon(
                              Icons.chair_outlined,
                              color: Colors.white70,
                              size: 20,
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 92),
                              child: Text(
                                category.label(l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: compactComponents
                        ? KeyedSubtree(
                            key: ValueKey('architect-tools-${category.name}'),
                            child: _buildComponentSubBar(context),
                          )
                        : SingleChildScrollView(
                            key: ValueKey('architect-tools-${category.name}'),
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.wall,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.wall,
                                    icon: Icons.line_weight_rounded,
                                    label: l10n.architectToolWall,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.door,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.door,
                                    icon: Icons.meeting_room_rounded,
                                    label: l10n.architectToolDoor,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.window,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.window,
                                    icon: Icons.window_rounded,
                                    label: l10n.architectToolWindow,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.column,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.column,
                                    icon: Icons.view_column_rounded,
                                    label: l10n.architectToolColumn,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.beam,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.beam,
                                    icon: Icons.horizontal_rule_rounded,
                                    label: l10n.architectToolBeam,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.slab,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.slab,
                                    icon: Icons.layers_rounded,
                                    label: l10n.architectToolSlab,
                                  ),
                                if (category == ArchitectToolCategory.structure ||
                                    category == ArchitectToolCategory.build)
                                  _buildToolButton(
                                    tool: ArchitectTool.floorDrain,
                                    icon: Icons.water_drop_outlined,
                                    label: l10n.architectToolFloorDrain,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.roof,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.roof,
                                    icon: Icons.roofing_rounded,
                                    label: l10n.architectToolRoof,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.opening,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.opening,
                                    icon: Icons.crop_free_rounded,
                                    label: l10n.architectToolOpening,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.stair,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.stair,
                                    icon: Icons.stairs_rounded,
                                    label: l10n.architectToolStair,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.component,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.component,
                                    icon: Icons.chair_outlined,
                                    label: l10n.architectLibrary,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.zone,
                                    )) ...[
                                  _buildToolButton(
                                    tool: ArchitectTool.zone,
                                    icon: Icons.space_dashboard_rounded,
                                    label: l10n.architectToolZone,
                                  ),
                                  _buildToolButton(
                                    tool: ArchitectTool.zoneTable,
                                    icon: Icons.table_chart_rounded,
                                    label: l10n.architectToolZoneTable,
                                  ),
                                ],
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.dimension,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.dimension,
                                    icon: Icons.straighten_rounded,
                                    label: l10n.architectToolDimension,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.level,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.level,
                                    icon: Icons.change_history_rounded,
                                    label: l10n.architectToolLevel,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.text,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.text,
                                    icon: Icons.title_rounded,
                                    label: l10n.architectToolText,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.cadLine,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.cadLine,
                                    icon: Icons.timeline_rounded,
                                    label: l10n.architectToolCadLine,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.cadRect,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.cadRect,
                                    icon: Icons.crop_square_rounded,
                                    label: l10n.architectToolCadRect,
                                  ),
                                if (category == ArchitectToolCategory.drawing && widget.onTerrain != null)
                                  IconButton(key:const ValueKey('architect-tool-terrain'),
                                    tooltip:l10n.architectTerrain, onPressed:widget.onTerrain,
                                    icon:const Icon(Icons.landscape_outlined,color:Colors.white70)),
                                if (category == ArchitectToolCategory.drawing)
                                  _buildToolButton(tool: ArchitectTool.hatch,
                                    icon: Icons.texture_rounded,
                                    label: l10n.architectToolHatch),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.cadCircle,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.cadCircle,
                                    icon: Icons.radio_button_unchecked_rounded,
                                    label: l10n.architectToolCadCircle,
                                  ),
                                if (category == ArchitectToolCategory.views) ...[
                                  _buildToolButton(
                                    tool: ArchitectTool.section,
                                    icon: Icons.splitscreen_outlined,
                                    label: l10n.architectToolSection,
                                  ),
                                  _buildToolButton(
                                    tool: ArchitectTool.elevation,
                                    icon: Icons.apartment,
                                    label: l10n.architectToolElevation,
                                  ),
                                ],
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.axis,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.axis,
                                    icon: Icons.grid_on_rounded,
                                    label: l10n.architectToolAxis,
                                  ),
                                if (category ==
                                    ArchitectToolCategory.of(
                                      ArchitectTool.measure,
                                    ))
                                  _buildToolButton(
                                    tool: ArchitectTool.measure,
                                    icon: Icons.square_foot_rounded,
                                    label: l10n.architectToolMeasure,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
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
          key: ValueKey('architect-tool-${tool.name}'),
          onTap: () {
            if (isSelected) {
              onToolChanged(ArchitectTool.select);
            } else {
              onToolChanged(tool);
              if (tool == ArchitectTool.component) {
                widget.onOpenComponentLibrary?.call();
              }
            }
          },
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
    final curvedWall = widget.curvedWall;
    final onArcWallSelected = widget.onArcWallSelected;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (wallTypes != null && wallTypes!.isNotEmpty)
            PopupMenuButton<ArchitectWallType>(
              key: const ValueKey('architect-wall-type-picker'),
              tooltip: (activeWallType ?? wallTypes!.first).pickerHelp(l10n),
              position: PopupMenuPosition.over,
              // The bottom toolbar anchors the list above the selected type.
              offset: Offset(0, -(wallTypes!.length * 48.0 + 16)),
              color: const Color(0xFF282B34),
              onSelected: (type) {
                onWallTypeSelected?.call(type);
                onWallThicknessChanged(type.totalThickness);
              },
              itemBuilder: (_) => [
                for (final type in wallTypes!)
                  PopupMenuItem(
                    key: ValueKey('architect-wall-type-${type.id}'),
                    value: type,
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: type.color),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Tooltip(
                            message: type.pickerHelp(l10n),
                            child: Text(
                              type.compactLabel(l10n),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        if (type.id == activeWallType?.id) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.check, size: 18, color: Colors.cyan),
                        ],
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF282B34),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: (activeWallType ?? wallTypes!.first).color,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        (activeWallType ?? wallTypes!.first).compactLabel(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_less,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.show_chart_rounded, size: 14),
            label: Text(l10n.architectWallSingle),
            selected: !curvedWall && wallMode == WallDraftingMode.singleLine,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.singleLine);
            },
            visualDensity: VisualDensity.compact,
          ),
          if (onArcWallSelected != null) ...[
            const SizedBox(width: 4),
            ChoiceChip(
              key: const ValueKey('architect-wall-arc-mode'),
              avatar: const Icon(Icons.rounded_corner, size: 14),
              label: Text(l10n.wallArcMode),
              selected: curvedWall,
              onSelected: (selected) {
                if (selected) onArcWallSelected();
              },
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(width: 4),
          ChoiceChip(
            avatar: const Icon(Icons.linear_scale_rounded, size: 14),
            label: Text(l10n.architectWallChained),
            selected: !curvedWall && wallMode == WallDraftingMode.chained,
            onSelected: (sel) {
              if (sel) onWallModeChanged(WallDraftingMode.chained);
            },
            visualDensity: VisualDensity.compact,
          ),
          if (!curvedWall && isChainingWall && onFinishChainedWall != null) ...[
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
          if (onCreateFenestration != null) ...[
            ActionChip(
              avatar: const Icon(
                Icons.add_circle_outline_rounded,
                size: 14,
                color: Color(0xFF00E5FF),
              ),
              label: Text(
                l10n.architectFenestrationCreateNew,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF00E5FF),
                ),
              ),
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              side: const BorderSide(color: Color(0xFF00E5FF)),
              onPressed: onCreateFenestration,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
          if (activeDoorStyle != null) ...[
            ActionChip(
              avatar: const Icon(
                Icons.door_front_door_rounded,
                size: 14,
                color: Color(0xFF00E5FF),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeDoorStyle!.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
              onPressed: () => _showStylePicker(context, FenestrationKind.door),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
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
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              l10n.architectDoorHeight,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final h in [2.00, 2.10])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${(h * 100).round()} cm'),
                selected: (doorHeight - h).abs() < 1e-3,
                onSelected: (sel) {
                  if (sel) onDoorHeightChanged(h);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: Text(l10n.architectDoorSillNone),
            selected: doorSill == 0.0,
            onSelected: (sel) {
              if (sel) onDoorSillChanged(0.0);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 5),
          ChoiceChip(
            label: Text(l10n.architectDoorSillStep),
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
          if (onCreateFenestration != null) ...[
            ActionChip(
              avatar: const Icon(
                Icons.add_circle_outline_rounded,
                size: 14,
                color: Color(0xFF00E5FF),
              ),
              label: Text(
                l10n.architectFenestrationCreateNew,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF00E5FF),
                ),
              ),
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              side: const BorderSide(color: Color(0xFF00E5FF)),
              onPressed: onCreateFenestration,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
          if (activeWindowStyle != null) ...[
            ActionChip(
              avatar: const Icon(
                Icons.window_rounded,
                size: 14,
                color: Color(0xFF00E5FF),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeWindowStyle!.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 14,
                    color: Colors.white70,
                  ),
                ],
              ),
              onPressed: () =>
                  _showStylePicker(context, FenestrationKind.window),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
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

  Widget _buildComponentSubBar(BuildContext context) {
    final l = context.l10n;
    final activeDef = ComponentLibraryService.instance.activeDefinition;
    final activeParams = ComponentLibraryService.instance.activeParameters;
    final w = (activeParams["width"] as num?)?.toDouble() ?? 0.80;
    final d = (activeParams["depth"] as num?)?.toDouble() ?? 0.60;
    final h = (activeParams["height"] as num?)?.toDouble() ?? 0.80;
    final deg =
        (widget.componentRotation * 180 / 3.141592653589793).round() % 360;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width < 600 ? 110 : 220,
            ),
            child: OutlinedButton.icon(
              key: const ValueKey("component-tool-library-btn"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              icon: const Icon(Icons.widgets_outlined, size: 16),
              label: Text(
                componentLabel(l, activeDef),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: widget.onOpenComponentLibrary,
            ),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            key: const ValueKey("component-tool-floor-drain-btn"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
            icon: const Icon(
              Icons.water_drop_outlined,
              size: 16,
              color: Color(0xFF00E5FF),
            ),
            label: Text(
              l.architectToolFloorDrain,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => widget.onToolChanged(ArchitectTool.floorDrain),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message:
                '${(w * 100).round()}×${(d * 100).round()}×${(h * 100).round()} cm',
            child: TextButton.icon(
              key: const ValueKey('component-tool-size-btn'),
              icon: const Icon(Icons.straighten, size: 18),
              label: Text(l.architectPropertySize),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () async {
                final values = await ComponentDimensionsDialog.show(
                  context,
                  activeDef,
                  activeParams,
                );
                if (values != null) {
                  ComponentLibraryService.instance.setActiveParameters(values);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey("component-tool-rotate-btn"),
            tooltip: '${l.architectComponentRotateBtn} ($deg°)',
            icon: const Icon(
              Icons.rotate_right,
              size: 18,
              color: Colors.white70,
            ),
            onPressed: widget.onRotateComponent,
          ),
        ],
      ),
    );
  }

  Widget _buildStairSubBar(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          DropdownButton<StairShape>(
            key: const ValueKey('stair-tool-shape'),
            value: widget.stairDesign.shape,
            dropdownColor: const Color(0xFF1E242C),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: [
              for (final shape in StairShape.values)
                DropdownMenuItem(
                  value: shape,
                  child: Text(stairShapeLabel(l, shape)),
                ),
            ],
            onChanged: (shape) {
              if (shape != null) widget.onStairShapeChanged?.call(shape);
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${(stairWidth * 100).round()} cm',
            style: const TextStyle(color: Colors.white70),
          ),
          IconButton(
            key: const ValueKey('stair-tool-properties'),
            tooltip: l.architectProperties,
            icon: const Icon(Icons.tune, color: Colors.white70),
            onPressed: widget.onStairProperties,
          ),
          Tooltip(
            message: l.stairPlaceHelp,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.help_outline, size: 18, color: Colors.white70),
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

    return SizedBox(
      width: 240,
      child: DropdownButton<ArchitectZoneCategory>(
        dropdownColor: const Color(0xFF1E2230),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        value: activeZoneCategory,
        isExpanded: true,
        items: [
          for (final category in ArchitectZoneCategory.values)
            DropdownMenuItem(
              value: category,
              child: Text(
                widget.zonePresets.categoryName(category, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (category) {
          if (category != null) onZoneCategoryChanged(category);
        },
      ),
    );
  }

  void _showStylePicker(BuildContext context, FenestrationKind kind) {
    final l10n = context.l10n;
    final styles = FenestrationLibraryService.instance.getStylesForKind(kind);
    final activeStyle = kind == FenestrationKind.door
        ? activeDoorStyle
        : activeWindowStyle;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      kind == FenestrationKind.door
                          ? Icons.door_front_door_rounded
                          : Icons.window_rounded,
                      color: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.architectFenestrationSelectStyle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (onCreateFenestration != null)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.architectFenestrationCreateNew),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onCreateFenestration!();
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: styles.length,
                  itemBuilder: (ctx, i) {
                    final s = styles[i];
                    final isSelected = activeStyle?.id == s.id;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isSelected
                            ? const Color(0xFF00E5FF)
                            : Colors.white54,
                      ),
                      title: Text(
                        s.localizedName(l10n),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${(s.defaultWidth * 100).round()} × ${(s.defaultHeight * 100).round()} cm'
                        '${s.hasCasing ? ' • ${l10n.architectFenestrationCasing}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                      trailing: Chip(
                        label: Text(
                          s.isPreset
                              ? l10n.architectFenestrationPreset
                              : l10n.architectFenestrationCustom,
                          style: const TextStyle(fontSize: 10),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (kind == FenestrationKind.door) {
                          onDoorStyleSelected?.call(s);
                        } else {
                          onWindowStyleSelected?.call(s);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewsSubBar(BuildContext context) {
    final l10n = context.l10n;
    final isSection = activeTool == ArchitectTool.section;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSection ? Icons.splitscreen_outlined : Icons.apartment,
            color: const Color(0xFF00E5FF),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isSection ? l10n.architectSectionHint : l10n.architectElevationHint,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
