import 'dart:math' as math;
import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../services/architect_interaction_mode.dart';
// === SECTION: ARCHITECTURAL TOOL PALETTE BAR ===
import 'package:flutter/material.dart';
import 'architect_wall_type_label.dart';
import 'architect_wall_type_picker.dart';
import '../models/architect_project.dart' show ArchitectUnit;
import '../services/architect_stair_rules.dart';
import 'architect_stair_labels.dart';
import 'architect_component_labels.dart';
import '../components/definitions/service_components.dart';
import 'component_dimensions_dialog.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../models/architect_column.dart';
import '../models/architect_decorative_element.dart';
import '../models/architect_elements.dart';
import 'architect_decorative_bar.dart';
import '../models/architect_wall_type.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import '../models/architect_fenestration_style.dart';
import '../models/architect_door.dart';
import '../models/architect_window.dart';
import '../services/fenestration_library_service.dart';
import 'fenestration_preview.dart';
import '../rendering/architect_2d_painter.dart';

import "../services/component_library_service.dart";

import 'architect_tool_catalog.dart';
export 'architect_tool_catalog.dart' show ArchitectToolCategory;

// ============================================================================
// MASTER ARCHITECT TOOL PALETTE LLM SEARCH INDEX & TABLE OF CONTENTS
// ============================================================================
// COMPANION MAP: See 'architect_tool_palette.index.md' for reference patterns and symbols.
// QUICK NAV: Use rg -n on a [TAG:...] anchor or concrete class/method name from the companion map.
//
// [SEC-01-WIDGET]  [TAG:ARCH_PALETTE_WIDGET] Declarations: `ArchitectToolPalette`
// [SEC-02-STATE]   [TAG:ARCH_PALETTE_STATE] `_ArchitectToolPaletteState` state fields (51 fields: `category`, `c
// [SEC-03-BUILD]   [TAG:ARCH_PALETTE_BUILD_LAYOUT] Widget Build & HUD Layout: `build`, `_buildToolButton` (2 methods)
// [SEC-04-WALLS]   [TAG:ARCH_PALETTE_WALL_OPS] Wall Drafting, Splitting & Joints: `_buildWallSubBar`, `_chooseWallT
// [SEC-05-OPENINGS] [TAG:ARCH_PALETTE_FENEST_OPENINGS] Doors, Windows & Openings: `_buildWindowSubBar`, `_buildDoorSubBar` 
// [SEC-06-BUILD]   [TAG:ARCH_PALETTE_COMPONENT_SUB] Widget Build & HUD Layout: `_buildComponentSubBar`, `_buildColumnSub
// [SEC-07-OPENINGS] [TAG:ARCH_PALETTE_OPENING_SUB] Doors, Windows & Openings: `_buildOpeningSubBar`, `_buildZoneSubBar`
// [SEC-08-HITS]    [TAG:ARCH_PALETTE_HIT_TESTING] Hit Testing & Candidate Picking: `_showStylePicker`, `_buildViewsSub
// ============================================================================

// === SECTION: [SEC-01-WIDGET] WIDGET DECLARATIONS & PUBLIC API ===
// --- SUBSECTION: [TAG:ARCH_PALETTE_WIDGET] Declarations: `ArchitectToolPalette` ---
enum ArchitectSiteAction { underlay, align, cadVisibility, parcel, setback, terrain, contours }

/// Responsive bottom bar for architectural drafting tools and contextual sub-options.
class ArchitectToolPalette extends StatefulWidget {
  final ArchitectTool activeTool;
  final bool drawingOnly;
  final bool sitePlan;
  final ValueChanged<ArchitectSiteAction>? onSiteAction;
  final bool canAlignSite, hasSiteParcel;
  final bool canEditSiteCadVisibility;
  final int viewSwitchEpoch;
  final ArchitectInteractionMode? interactionMode;
  final ArchitectTool? selectionTool;
  final VoidCallback? onDrawSelection;
  final VoidCallback? onSelectAll;
  final VoidCallback? onFindAndSelect;
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
  final ValueChanged<ArchitectWallType>? onCreateWallVariant;
  final VoidCallback? onManageWallTypes;
  final ValueChanged<ArchitectWallType>? onDeleteWallType;
  final String wallProjectId;
  final ArchitectUnit wallUnit;

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
  final bool doorHasCasing;
  final ValueChanged<bool>? onDoorHasCasingChanged;
  final ArchitectDoor? selectedDoor;

  // Window options
  final double windowWidth;
  final ValueChanged<double>? onWindowWidthChanged;
  final double windowHeight;
  final ValueChanged<double>? onWindowHeightChanged;
  final double windowSill;
  final ValueChanged<double>? onWindowSillChanged;
  final bool windowHasCasing;
  final ValueChanged<bool>? onWindowHasCasingChanged;
  final bool? windowIsFlipped;
  final ValueChanged<bool>? onWindowFlippedChanged;
  final ArchitectWindow? selectedWindow;

  // Column options
  final ArchitectColumn? selectedColumn;
  final ColumnShape columnShape;
  final ValueChanged<ColumnShape>? onColumnShapeChanged;
  final double columnWidth;
  final ValueChanged<double>? onColumnWidthChanged;
  final double columnDepth;
  final ValueChanged<double>? onColumnDepthChanged;
  final double? columnHeight;
  final ValueChanged<double>? onColumnHeightChanged;
  final double columnBaseOffset;
  final ValueChanged<double>? onColumnBaseOffsetChanged;
  final double activeStoreyHeight;

  // Beam options
  final ArchitectBeam? selectedBeam;
  final double beamWidth;
  final ValueChanged<double>? onBeamWidthChanged;
  final double beamDepth;
  final ValueChanged<double>? onBeamDepthChanged;
  final double beamBaseOffset;
  final ValueChanged<double>? onBeamBaseOffsetChanged;
  final double beamSlopeDegrees;
  final ValueChanged<double>? onBeamSlopeChanged;

  // Stair options
  final ArchitectStair? selectedStair;
  final ArchitectStairDesign stairDesign;
  final ValueChanged<StairShape>? onStairShapeChanged;
  final VoidCallback? onStairProperties;
  final VoidCallback? onFreeStair;
  final double stairWidth;
  final ValueChanged<double>? onStairWidthChanged;
  final int stairSteps;
  final ValueChanged<int>? onStairStepsChanged;
  final ValueChanged<double>? onStairTotalWidthChanged;
  final ValueChanged<double>? onStairOuterDiameterChanged;
  final ValueChanged<double>? onStairLandingDepthChanged;
  final ValueChanged<double>? onStairLandingOffsetChanged;
  final ValueChanged<double>? onStairRiseChanged;
  final ValueChanged<double>? onStairGoingChanged;
  final ValueChanged<double>? onStairRiserChanged;
  final ValueChanged<bool>? onStairTurnChanged;

  // Opening options
  final OpeningType openingType;
  final ValueChanged<OpeningType>? onOpeningTypeChanged;

  // Decorative 3D options
  final double decorativeDepth;
  final ValueChanged<double>? onDecorativeDepthChanged;
  final double decorativeSpanLength;
  final ValueChanged<double>? onDecorativeSpanLengthChanged;
  final double decorativeFrameWidth;
  final ValueChanged<double>? onDecorativeFrameWidthChanged;
  final double decorativeNormalOffset;
  final ValueChanged<double>? onDecorativeNormalOffsetChanged;
  final ArchitectDecorativeMaterial decorativeMaterial;
  final ValueChanged<ArchitectDecorativeMaterial>? onDecorativeMaterialChanged;
  final ArchitectDecorativeElement? activeDecorativePreset;
  final ValueChanged<ArchitectDecorativeElement?>? onDecorativePresetChanged;
  final bool showDecorativeOnPlan;
  final ValueChanged<bool>? onShowDecorativeOnPlanChanged;
  final VoidCallback? onOpenDecorativeStudio;
  final bool selectedTerrain;
  final Widget? landscapeBar;

  const ArchitectToolPalette({
    super.key,
    this.zonePresets = const ArchitectZonePresets(),
    required this.activeTool,
    this.drawingOnly = false,
    this.sitePlan = false,
    this.onSiteAction,
    this.canAlignSite = false,
    this.canEditSiteCadVisibility = false,
    this.hasSiteParcel = false,
    this.viewSwitchEpoch = 0,
    this.interactionMode,
    this.selectionTool,
    this.onDrawSelection,
    this.onSelectAll,
    this.onFindAndSelect,
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
    this.onCreateWallVariant,
    this.onManageWallTypes,
    this.onDeleteWallType,
    this.wallProjectId = '',
    this.wallUnit = ArchitectUnit.centimeters,
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
    this.doorHasCasing = false,
    this.onDoorHasCasingChanged,
    this.selectedDoor,
    this.windowWidth = 1.20,
    this.onWindowWidthChanged,
    this.windowHeight = 1.40,
    this.onWindowHeightChanged,
    this.windowSill = 0.90,
    this.onWindowSillChanged,
    this.windowHasCasing = false,
    this.onWindowHasCasingChanged,
    this.windowIsFlipped,
    this.onWindowFlippedChanged,
    this.selectedWindow,
    this.selectedColumn,
    this.columnShape = ColumnShape.rectangular,
    this.onColumnShapeChanged,
    this.columnWidth = 0.25,
    this.onColumnWidthChanged,
    this.columnDepth = 0.25,
    this.onColumnDepthChanged,
    this.columnHeight,
    this.onColumnHeightChanged,
    this.columnBaseOffset = 0.0,
    this.onColumnBaseOffsetChanged,
    this.activeStoreyHeight = 3.0,
    this.selectedBeam,
    this.beamWidth = 0.25,
    this.onBeamWidthChanged,
    this.beamDepth = 0.50,
    this.onBeamDepthChanged,
    this.beamBaseOffset = 2.20,
    this.onBeamBaseOffsetChanged,
    this.beamSlopeDegrees = 0.0,
    this.onBeamSlopeChanged,
    this.selectedStair,
    this.stairDesign = const ArchitectStairDesign(),
    this.onStairShapeChanged,
    this.onStairProperties,
    this.onFreeStair,
    this.stairWidth = 1.00,
    this.onStairWidthChanged,
    this.stairSteps = 16,
    this.onStairStepsChanged,
    this.onStairTotalWidthChanged,
    this.onStairOuterDiameterChanged,
    this.onStairLandingDepthChanged,
    this.onStairLandingOffsetChanged,
    this.onStairRiseChanged,
    this.onStairGoingChanged,
    this.onStairRiserChanged,
    this.onStairTurnChanged,
    this.openingType = OpeningType.shaft,
    this.onOpeningTypeChanged,
    this.decorativeDepth = 0.05,
    this.onDecorativeDepthChanged,
    this.decorativeSpanLength = 2.00,
    this.onDecorativeSpanLengthChanged,
    this.decorativeFrameWidth = 0.12,
    this.onDecorativeFrameWidthChanged,
    this.decorativeNormalOffset = 0.0,
    this.onDecorativeNormalOffsetChanged,
    this.decorativeMaterial = ArchitectDecorativeMaterial.eps,
    this.onDecorativeMaterialChanged,
    this.activeDecorativePreset,
    this.onDecorativePresetChanged,
    this.showDecorativeOnPlan = false,
    this.onShowDecorativeOnPlanChanged,
    this.onOpenDecorativeStudio,
    this.selectedTerrain = false,
    this.landscapeBar,
  });

  @override
  State<ArchitectToolPalette> createState() => _ArchitectToolPaletteState();
}

// === SECTION: [SEC-02-STATE] ARCHITECTTOOLPALETTESTATE STATE & FIELDS ===
// --- SUBSECTION: [TAG:ARCH_PALETTE_STATE] `_ArchitectToolPaletteState` state fields (51 fields: `category`, `colors`, `activeTool`, `mode`, `onToolChanged`) ---
class _ArchitectToolPaletteState extends State<ArchitectToolPalette> {
  ArchitectToolCategory category = ArchitectToolCategory.selection;
  ColorScheme get colors => Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    category = ArchitectToolCategory.of(widget.activeTool);
    if (widget.sitePlan &&
        (widget.activeTool == ArchitectTool.pan ||
            widget.activeTool == ArchitectTool.select)) {
      category = ArchitectToolCategory.underlays;
    }
    if (widget.drawingOnly && !category.availableInDrawing) {
      category = ArchitectToolCategory.drawing;
    }
  }

  Future<void> _browseTools() async {
    final result = await showModalBottomSheet<ArchitectToolChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .90,
        child: ArchitectToolBrowser(
          category: category,
          activeTool: activeTool,
          drawingOnly: widget.drawingOnly,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => category = result.category);
    if (result.tool != null) {
      widget.onToolChanged(result.tool!);
      if (result.tool!.usesComponent && result.tool != activeTool) {
        widget.onOpenComponentLibrary?.call();
      } else if (result.tool == ArchitectTool.decorativeLibrary) {
        widget.onOpenDecorativeStudio?.call();
      }
    } else if (result.category == ArchitectToolCategory.furnishing) {
      widget.onToolChanged(ArchitectTool.component);
      if (activeTool != ArchitectTool.component) {
        widget.onOpenComponentLibrary?.call();
      }
    } else if (result.category == ArchitectToolCategory.decorative &&
        !activeTool.isDecorativeTool) {
      widget.onToolChanged(ArchitectTool.decorativeProfile);
    } else if (result.category == ArchitectToolCategory.underlays &&
        !activeTool.isUnderlayTool) {
      widget.onToolChanged(ArchitectTool.cadUnderlay);
    } else if (result.category == ArchitectToolCategory.landscape &&
        !activeTool.isLandscapeTool) {
      widget.onToolChanged(ArchitectTool.terrain);
    } else if (ArchitectToolCategory.of(activeTool) != category &&
        mode == ArchitectInteractionMode.drawing) {
      widget.onToolChanged(ArchitectTool.pan);
    }
  }

  @override
  void didUpdateWidget(ArchitectToolPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    final enteredSitePlan =
        widget.sitePlan &&
        (!oldWidget.sitePlan ||
            oldWidget.drawingOnly ||
            widget.viewSwitchEpoch != oldWidget.viewSwitchEpoch) &&
        !widget.drawingOnly;
    final leftSitePlan = !widget.sitePlan && oldWidget.sitePlan;
    if (widget.activeTool != oldWidget.activeTool &&
        widget.activeTool != ArchitectTool.pan &&
        widget.activeTool != ArchitectTool.select) {
      category = ArchitectToolCategory.of(widget.activeTool);
    } else if (enteredSitePlan &&
        (widget.activeTool == ArchitectTool.pan ||
            widget.activeTool == ArchitectTool.select)) {
      category = ArchitectToolCategory.underlays;
    } else if (leftSitePlan &&
        (category == ArchitectToolCategory.underlays ||
            category == ArchitectToolCategory.landscape) &&
        (widget.activeTool == ArchitectTool.pan ||
            widget.activeTool == ArchitectTool.select)) {
      category = ArchitectToolCategory.of(widget.activeTool);
    }
    if (widget.drawingOnly && !category.availableInDrawing) {
      category = ArchitectToolCategory.drawing;
    }
  }

  ArchitectTool get activeTool => widget.activeTool;
  ArchitectInteractionMode get mode =>
      widget.interactionMode ??
      (widget.multiSelect
          ? ArchitectInteractionMode.multiSelect
          : activeTool == ArchitectTool.pan
          ? ArchitectInteractionMode.navigation
          : activeTool == ArchitectTool.select
          ? ArchitectInteractionMode.singleSelect
          : ArchitectInteractionMode.drawing);

  Widget _siteMenu(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<ArchitectSiteAction>(
      key: const ValueKey('architect-site-menu'),
      tooltip: l.architectSitePlan,
      onSelected: widget.onSiteAction,
      itemBuilder: (_) => [
        PopupMenuItem(value: ArchitectSiteAction.underlay, child: Text(l.architectSiteUnderlay)),
        PopupMenuItem(value: ArchitectSiteAction.align, enabled: widget.canAlignSite,
          child: Text(l.architectSiteAlign)),
        PopupMenuItem(value: ArchitectSiteAction.cadVisibility,
          enabled: widget.canEditSiteCadVisibility,
          child: Text(l.architectSiteHideFromPlan)),
        PopupMenuItem(value: ArchitectSiteAction.parcel, child: Text(l.architectSiteParcel)),
        PopupMenuItem(value: ArchitectSiteAction.setback, enabled: widget.hasSiteParcel,
          child: Text(l.architectSiteSetback)),
        const PopupMenuDivider(),
        PopupMenuItem(value: ArchitectSiteAction.terrain, child: Text(l.architectToolTerrain)),
        PopupMenuItem(value: ArchitectSiteAction.contours, child: Text(l.architectToolContour)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(l.architectSitePlan, style: Theme.of(context).textTheme.labelLarge),
          const Icon(Icons.expand_more, size: 18),
        ]),
      ),
    );
  }
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
  double? get columnHeight => widget.columnHeight;
  ValueChanged<double>? get onColumnHeightChanged =>
      widget.onColumnHeightChanged;
  double get columnBaseOffset => widget.columnBaseOffset;
  ValueChanged<double>? get onColumnBaseOffsetChanged =>
      widget.onColumnBaseOffsetChanged;
  double get beamWidth => widget.beamWidth;
  ValueChanged<double>? get onBeamWidthChanged => widget.onBeamWidthChanged;
  double get beamDepth => widget.beamDepth;
  ValueChanged<double>? get onBeamDepthChanged => widget.onBeamDepthChanged;
  double get beamBaseOffset => widget.beamBaseOffset;
  ValueChanged<double>? get onBeamBaseOffsetChanged =>
      widget.onBeamBaseOffsetChanged;
  double get beamSlopeDegrees => widget.beamSlopeDegrees;
  ValueChanged<double>? get onBeamSlopeChanged => widget.onBeamSlopeChanged;
  double get stairWidth => widget.stairWidth;
  ValueChanged<double>? get onStairWidthChanged => widget.onStairWidthChanged;
  int get stairSteps => widget.stairSteps;
  ValueChanged<int>? get onStairStepsChanged => widget.onStairStepsChanged;
  OpeningType get openingType => widget.openingType;
  ValueChanged<OpeningType>? get onOpeningTypeChanged =>
      widget.onOpeningTypeChanged;

  // === SECTION: [SEC-03-BUILD] WIDGET BUILD & HUD LAYOUT ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_BUILD_LAYOUT] Widget Build & HUD Layout: `build`, `_buildToolButton` (2 methods) ---
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compactComponents =
        activeTool == ArchitectTool.component &&
        mode == ArchitectInteractionMode.drawing &&
        category == ArchitectToolCategory.furnishing;

    return Theme(
      data: Theme.of(context),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: colors.outlineVariant),
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
              if (mode == ArchitectInteractionMode.drawing ||
                  widget.selectedDoor != null ||
                  widget.selectedWindow != null ||
                  widget.selectedColumn != null ||
                  widget.selectedBeam != null ||
                  widget.selectedStair != null ||
                  widget.selectedTerrain) ...[
                // Contextual Sub-bar for Active Tool parameters or Selection
                if (widget.selectedDoor != null ||
                    activeTool == ArchitectTool.door)
                  _buildDoorSubBar(context)
                else if (widget.selectedWindow != null ||
                    activeTool == ArchitectTool.window)
                  _buildWindowSubBar(context)
                else if (widget.selectedColumn != null)
                  _buildColumnSubBar(context)
                else if (widget.selectedBeam != null)
                  _buildBeamSubBar(context)
                else if (widget.selectedStair != null)
                  _buildStairSubBar(context)
                else if (widget.selectedTerrain && widget.landscapeBar != null)
                  widget.landscapeBar!
                else if (activeTool == ArchitectTool.zone)
                  _buildZoneSubBar(context)
                else if (activeTool == ArchitectTool.wall)
                  _buildWallSubBar(context)
                else if (activeTool == ArchitectTool.column)
                  _buildColumnSubBar(context)
                else if (activeTool == ArchitectTool.beam)
                  _buildBeamSubBar(context)
                else if (activeTool == ArchitectTool.stair)
                  _buildStairSubBar(context)
                else if (activeTool.usesComponent && !compactComponents)
                  _buildComponentSubBar(context)
                else if (activeTool == ArchitectTool.opening)
                  _buildOpeningSubBar(context)
                else if (activeTool.isDecorativeTool)
                  _buildDecorativeSubBar(context)
                else if (activeTool.isLandscapeTool &&
                    widget.landscapeBar != null)
                  widget.landscapeBar!
                else if (activeTool == ArchitectTool.section ||
                    activeTool == ArchitectTool.elevation)
                  _buildViewsSubBar(context),
              ],
              const SizedBox(height: 6),

              Row(
                children: [
                  if (widget.sitePlan && widget.onSiteAction != null) ...[
                    _siteMenu(context),
                    IconButton(
                      key: const ValueKey('architect-tool-category'),
                      tooltip: l10n.architectToolCategories,
                      onPressed: _browseTools,
                      icon: AppIcon(category.iconId, size: 20),
                    ),
                  ] else TextButton(
                    key: const ValueKey('architect-tool-category'),
                    onPressed: _browseTools,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Tooltip(
                      message: l10n.architectToolCategories,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (compactComponents &&
                              MediaQuery.sizeOf(context).width < 600)
                            AppIcon(
                              category.iconId,
                              size: 20,
                              color: colors.primary,
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                category.label(l10n),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          AppIcon(
                            AppIconId.expandMore,
                            color: colors.onSurfaceVariant,
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
                                    ArchitectToolCategory.selection) ...[
                                  _buildToolButton(
                                    tool: ArchitectTool.pan,
                                    icon: AppIconId.pan,
                                    label: l10n.architectToolPan,
                                    iconOnly:
                                        MediaQuery.sizeOf(context).width < 600,
                                  ),
                                  _buildToolButton(
                                    tool: ArchitectTool.select,
                                    icon: AppIconId.select,
                                    label: l10n.architectToolSelect,
                                    iconOnly:
                                        widget.onSelectAll != null &&
                                        MediaQuery.sizeOf(context).width < 600,
                                    selected:
                                        mode ==
                                        ArchitectInteractionMode.singleSelect,
                                  ),
                                  if (widget.onToggleMultiSelect != null)
                                    _buildToolButton(
                                      tool: ArchitectTool.select,
                                      buttonKey: 'architect-multi-select',
                                      icon: AppIconId.multiSelect,
                                      label: l10n.architectSelectionMulti,
                                      iconOnly:
                                          widget.onSelectAll != null &&
                                          MediaQuery.sizeOf(context).width <
                                              600,
                                      selected:
                                          mode ==
                                          ArchitectInteractionMode.multiSelect,
                                      onPressed: widget.onToggleMultiSelect,
                                    ),
                                  if (widget.onSelectAll != null)
                                    _buildToolButton(
                                      tool: ArchitectTool.select,
                                      buttonKey: 'architect-select-all',
                                      icon: AppIconId.selectAll,
                                      label: l10n.architectSelectAll,
                                      iconOnly:
                                          MediaQuery.sizeOf(context).width <
                                          600,
                                      tooltip: l10n.architectSelectSimilarHelp,
                                      selected: false,
                                      onPressed: widget.onSelectAll,
                                    ),
                                  if (widget.onFindAndSelect != null)
                                    _buildToolButton(
                                      tool: ArchitectTool.select,
                                      buttonKey: 'architect-find-and-select',
                                      icon: AppIconId.filter,
                                      label: l10n.architectFindAndSelect,
                                      iconOnly:
                                          MediaQuery.sizeOf(context).width <
                                          600,
                                      tooltip: l10n.architectFindAndSelectHelp,
                                      selected: false,
                                      onPressed: widget.onFindAndSelect,
                                    ),
                                  if (widget.selectionTool != null &&
                                      widget.onDrawSelection != null)
                                    _buildDrawingShortcut(
                                      context,
                                      widget.selectionTool!,
                                    ),
                                ],
                                if (category == ArchitectToolCategory.stairs)
                                  ..._buildStairShapeButtons(context)
                                else if (category !=
                                    ArchitectToolCategory.selection)
                                  for (final tool in category.tools)
                                    _buildToolButton(
                                      tool: tool,
                                      icon: tool.presentation(l10n).$1,
                                      label: tool.presentation(l10n).$2,
                                    ),
                                if (category == ArchitectToolCategory.drawing &&
                                    widget.onTerrain != null)
                                  IconButton(
                                    key: const ValueKey(
                                      'architect-tool-terrain',
                                    ),
                                    tooltip: l10n.architectTerrain,
                                    onPressed: widget.onTerrain,
                                    icon: AppIcon(
                                      AppIconId.terrain,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (category != ArchitectToolCategory.selection)
                    _buildToolButton(
                      tool: ArchitectTool.pan,
                      icon: AppIconId.pan,
                      label: l10n.architectToolPan,
                      iconOnly: true,
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
    required AppIconId icon,
    required String label,
    String? buttonKey,
    bool? selected,
    VoidCallback? onPressed,
    bool iconOnly = false,
    String? tooltip,
  }) {
    final isSelected = selected ?? activeTool == tool;
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
      child: Tooltip(
        message: tooltip ?? label,
        child: Material(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.22)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey(buttonKey ?? 'architect-tool-${tool.name}'),
            onTap:
                onPressed ??
                () {
                  if (isSelected &&
                      (tool.usesComponent ||
                          mode != ArchitectInteractionMode.contextEdit)) {
                    onToolChanged(ArchitectTool.pan);
                  } else {
                    onToolChanged(tool);
                    if (tool.usesComponent) {
                      widget.onOpenComponentLibrary?.call();
                    } else if (tool == ArchitectTool.decorativeLibrary) {
                      widget.onOpenDecorativeStudio?.call();
                    }
                  }
                },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.symmetric(
                horizontal: iconOnly
                    ? 10
                    : compact
                    ? 4
                    : 13,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.12),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  if (!iconOnly) ...[
                    SizedBox(width: compact ? 5 : 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12.5,
                      ),
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

  // === SECTION: [SEC-04-WALLS] WALL DRAFTING, SPLITTING & JOINTS ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_WALL_OPS] Wall Drafting, Splitting & Joints: `_buildWallSubBar`, `_chooseWallType`, `_buildDrawingShortcut` (3 methods) ---
  Widget _buildDrawingShortcut(BuildContext context, ArchitectTool tool) {
    final l = context.l10n;
    final (icon, label) = tool.presentation(l);
    return _buildToolButton(
      tool: tool,
      icon: icon,
      label: label,
      buttonKey: 'architect-draw-selection',
      selected: mode == ArchitectInteractionMode.drawing && activeTool == tool,
      onPressed: widget.onDrawSelection,
      tooltip: l.architectDrawSelectedType(label),
    );
  }

  Future<void> _chooseWallType() async {
    if (wallTypes == null || wallTypes!.isEmpty) return;
    final result = await showArchitectWallTypePicker(
      context,
      types: wallTypes!,
      activeType: activeWallType ?? wallTypes!.first,
      projectId: widget.wallProjectId,
      unit: widget.wallUnit,
      allowVariant: widget.onCreateWallVariant != null,
      allowManage: widget.onManageWallTypes != null,
      onDelete: widget.onDeleteWallType,
    );
    if (!mounted || result == null) return;
    switch (result.action) {
      case ArchitectWallPickerAction.select:
        onWallTypeSelected?.call(result.type);
        onWallThicknessChanged(result.type.totalThickness);
      case ArchitectWallPickerAction.variant:
        widget.onCreateWallVariant?.call(result.type);
      case ArchitectWallPickerAction.manage:
        widget.onManageWallTypes?.call();
    }
  }

  Widget _buildWallSubBar(BuildContext context) {
    final l = context.l10n;
    final type = activeWallType ?? wallTypes?.firstOrNull;
    final mode = widget.curvedWall
        ? l.wallArcMode
        : wallMode == WallDraftingMode.chained
        ? l.architectWallChained
        : l.architectWallSingle;
    return Row(
      children: [
        if (type != null)
          Expanded(
            child: Tooltip(
              message: type.compositionLabel(l, widget.wallUnit),
              child: OutlinedButton(
                key: const ValueKey('architect-wall-type-picker'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 44),
                ),
                onPressed: _chooseWallType,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.catalogLabel(l, widget.wallUnit),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppIcon(AppIconId.expandLess, size: 18),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          key: const ValueKey('wall-drawing-mode'),
          tooltip: l.wallDrawingMode,
          onSelected: (value) {
            if (value == 'arc') {
              widget.onArcWallSelected?.call();
            } else {
              onWallModeChanged(
                value == 'chain'
                    ? WallDraftingMode.chained
                    : WallDraftingMode.singleLine,
              );
            }
          },
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'single',
              checked:
                  !widget.curvedWall && wallMode == WallDraftingMode.singleLine,
              child: AppMenuLabel(
                icon: AppIconId.line,
                child: Text(l.architectWallSingle),
              ),
            ),
            CheckedPopupMenuItem(
              value: 'chain',
              checked:
                  !widget.curvedWall && wallMode == WallDraftingMode.chained,
              child: AppMenuLabel(
                icon: AppIconId.polyline,
                child: Text(l.architectWallChained),
              ),
            ),
            if (widget.onArcWallSelected != null)
              CheckedPopupMenuItem(
                key: const ValueKey('architect-wall-arc-mode'),
                value: 'arc',
                checked: widget.curvedWall,
                child: AppMenuLabel(
                  icon: AppIconId.arc,
                  child: Text(l.wallArcMode),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mode, style: TextStyle(color: colors.onSurfaceVariant)),
                AppIcon(
                  AppIconId.expandMore,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (type != null && widget.onCreateWallVariant != null)
          IconButton(
            key: const ValueKey('wall-draft-layers'),
            tooltip: l.wallNewVariant,
            onPressed: () => widget.onCreateWallVariant!(type),
            icon: AppIcon(AppIconId.layers),
          ),
        if (!widget.curvedWall && isChainingWall && onFinishChainedWall != null)
          IconButton(
            tooltip: l.architectFinishChained,
            onPressed: onFinishChainedWall,
            icon: AppIcon(AppIconId.confirm),
          ),
      ],
    );
  }

  // === SECTION: [SEC-05-OPENINGS] DOORS, WINDOWS & OPENINGS ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_FENEST_OPENINGS] Doors, Windows & Openings: `_buildWindowSubBar`, `_buildDoorSubBar` (2 methods) ---
  Widget _buildNumericKeypadChip({
    Key? key,
    required String label,
    required double displayValue,
    required String unitLabel,
    String? chipSuffix,
    int decimals = 1,
    required double min,
    required double max,
    bool allowNegative = false,
    bool warning = false,
    String? warningTooltip,
    required ValueChanged<double>? onChanged,
  }) {
    final l10n = context.l10n;
    final formatted = ArchitectUnit.trimZeros(
      displayValue.toStringAsFixed(decimals),
    );
    final suffix = chipSuffix ?? ' $unitLabel';
    final chip = ActionChip(
      key: key,
      side: warning ? BorderSide(color: colors.error, width: 1.3) : null,
      backgroundColor: warning
          ? colors.errorContainer.withValues(alpha: 0.72)
          : null,
      label: warning
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: colors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '$formatted$suffix',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text('$formatted$suffix'),
      onPressed: onChanged == null
          ? null
          : () async {
              final entered = await BimNumericKeypad.showInputDialog(
                context,
                title: label,
                initialText: formatted,
                unitLabel: unitLabel,
                decimals: decimals,
                allowNegative: allowNegative,
                min: min,
                max: max,
                cancelLabel: l10n.cancel,
                applyLabel: l10n.applyAction,
              );
              if (entered != null) {
                onChanged(entered);
              }
            },
      visualDensity: VisualDensity.compact,
    );
    if (warning && warningTooltip != null) {
      return Tooltip(message: warningTooltip, child: chip);
    }
    return chip;
  }

  Widget _buildOpeningDimensionChip({
    Key? key,
    required String label,
    required double valueMeters,
    required double minCm,
    required double maxCm,
    bool allowNegative = false,
    bool warning = false,
    String? warningTooltip,
    required ValueChanged<double>? onChangedMeters,
  }) => _buildNumericKeypadChip(
    key: key,
    label: label,
    displayValue: valueMeters * 100,
    unitLabel: 'cm',
    min: minCm,
    max: maxCm,
    allowNegative: allowNegative,
    warning: warning,
    warningTooltip: warningTooltip,
    onChanged: onChangedMeters == null
        ? null
        : (entered) => onChangedMeters(entered / 100.0),
  );

  Widget _buildOpeningDimensionLabel(String text) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Text(
      text,
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
  );

  Widget _buildOpeningDimensionsRow(
    List<
      ({
        Key key,
        String label,
        double valueMeters,
        double minCm,
        double maxCm,
        ValueChanged<double>? onChangedMeters,
      })
    >
    fields,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          _buildOpeningDimensionLabel(fields[i].label),
          _buildOpeningDimensionChip(
            key: fields[i].key,
            label: fields[i].label,
            valueMeters: fields[i].valueMeters,
            minCm: fields[i].minCm,
            maxCm: fields[i].maxCm,
            onChangedMeters: fields[i].onChangedMeters,
          ),
        ],
      ],
    ),
  );

  Widget _buildDoorSubBar(BuildContext context) {
    final l10n = context.l10n;
    final effectiveDoorStyle =
        widget.selectedDoor?.resolvedStyle ?? activeDoorStyle;
    final effectiveWidth = widget.selectedDoor?.width ?? doorWidth;
    final effectiveHeight = widget.selectedDoor?.height ?? doorHeight;
    final effectiveSill = widget.selectedDoor?.sillHeight ?? doorSill;
    final effectiveHingeLeft = widget.selectedDoor?.isHingeLeft ?? isHingeLeft;
    final effectiveCasing =
        widget.selectedDoor?.effectiveHasCasing ?? widget.doorHasCasing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ROW 1: Actions, Preset, Swing/Hinge, Casing
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (onCreateFenestration != null) ...[
                ActionChip(
                  avatar: AppIcon(
                    AppIconId.addCircle,
                    size: 14,
                    color: colors.primary,
                  ),
                  label: Text(
                    l10n.architectFenestrationCreateNew,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.primary,
                    ),
                  ),
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  side: BorderSide(color: colors.primary),
                  onPressed: onCreateFenestration,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              if (effectiveDoorStyle != null) ...[
                ActionChip(
                  avatar: AppIcon(
                    AppIconId.door,
                    size: 14,
                    color: colors.primary,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        effectiveDoorStyle.localizedName(l10n),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        AppIconId.expandMore,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onPressed: () =>
                      _showStylePicker(context, FenestrationKind.door),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              ChoiceChip(
                label: Text(
                  effectiveHingeLeft
                      ? l10n.architectDoorHingeLeft
                      : l10n.architectDoorHingeRight,
                ),
                selected: true,
                onSelected: (_) => onHingeSideChanged(!effectiveHingeLeft),
                avatar: const AppIcon(AppIconId.swapHorizontal, size: 14),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.architectDoorCasing),
                selected: effectiveCasing,
                onSelected: (val) => widget.onDoorHasCasingChanged?.call(val),
                avatar: AppIcon(
                  effectiveCasing ? AppIconId.checkCircle : AppIconId.radioOff,
                  size: 14,
                  color: effectiveCasing
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ROW 2: Width, Height, Sill (direct value input)
        _buildOpeningDimensionsRow([
          (
            key: const ValueKey('door-width-input'),
            label: l10n.architectDoorWidth,
            valueMeters: effectiveWidth,
            minCm: 30,
            maxCm: 600,
            onChangedMeters: onDoorWidthChanged,
          ),
          (
            key: const ValueKey('door-height-input'),
            label: l10n.architectDoorHeight,
            valueMeters: effectiveHeight,
            minCm: 100,
            maxCm: 500,
            onChangedMeters: onDoorHeightChanged,
          ),
          (
            key: const ValueKey('door-sill-input'),
            label: l10n.architectDoorSill,
            valueMeters: effectiveSill,
            minCm: 0,
            maxCm: 300,
            onChangedMeters: onDoorSillChanged,
          ),
        ]),
      ],
    );
  }

  Widget _buildWindowSubBar(BuildContext context) {
    final l10n = context.l10n;
    final effectiveWindowStyle =
        widget.selectedWindow?.resolvedStyle ?? activeWindowStyle;
    final effectiveWidth = widget.selectedWindow?.width ?? windowWidth;
    final effectiveHeight = widget.selectedWindow?.height ?? windowHeight;
    final effectiveSill = widget.selectedWindow?.sillHeight ?? windowSill;
    final effectiveFlipped =
        widget.selectedWindow?.isFlipped ?? (widget.windowIsFlipped ?? false);
    final effectiveCasing =
        widget.selectedWindow?.effectiveHasCasing ?? widget.windowHasCasing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ROW 1: Actions, Preset, Casing, Flip
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              if (onCreateFenestration != null) ...[
                ActionChip(
                  avatar: AppIcon(
                    AppIconId.addCircle,
                    size: 14,
                    color: colors.primary,
                  ),
                  label: Text(
                    l10n.architectFenestrationCreateNew,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.primary,
                    ),
                  ),
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  side: BorderSide(color: colors.primary),
                  onPressed: onCreateFenestration,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              if (effectiveWindowStyle != null) ...[
                ActionChip(
                  avatar: AppIcon(
                    AppIconId.window,
                    size: 14,
                    color: colors.primary,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        effectiveWindowStyle.localizedName(l10n),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        AppIconId.expandMore,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onPressed: () =>
                      _showStylePicker(context, FenestrationKind.window),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              FilterChip(
                label: Text(l10n.architectDoorCasing),
                selected: effectiveCasing,
                onSelected: (val) => widget.onWindowHasCasingChanged?.call(val),
                avatar: AppIcon(
                  effectiveCasing ? AppIconId.checkCircle : AppIconId.radioOff,
                  size: 14,
                  color: effectiveCasing
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(l10n.architectWindowFlipSide),
                selected: effectiveFlipped,
                onSelected: (val) => widget.onWindowFlippedChanged?.call(val),
                avatar: const AppIcon(AppIconId.swapHorizontal, size: 14),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ROW 2: Width, Height, Sill (direct value input)
        _buildOpeningDimensionsRow([
          (
            key: const ValueKey('window-width-input'),
            label: l10n.architectWindowWidth,
            valueMeters: effectiveWidth,
            minCm: 20,
            maxCm: 1000,
            onChangedMeters: onWindowWidthChanged,
          ),
          (
            key: const ValueKey('window-height-input'),
            label: l10n.architectWindowHeight,
            valueMeters: effectiveHeight,
            minCm: 20,
            maxCm: 500,
            onChangedMeters: onWindowHeightChanged,
          ),
          (
            key: const ValueKey('window-sill-input'),
            label: l10n.architectWindowSill,
            valueMeters: effectiveSill,
            minCm: 0,
            maxCm: 300,
            onChangedMeters: onWindowSillChanged,
          ),
        ]),
      ],
    );
  }

  // === SECTION: [SEC-06-BUILD] WIDGET BUILD & HUD LAYOUT ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_COMPONENT_SUB] Widget Build & HUD Layout: `_buildComponentSubBar`, `_buildColumnSubBar`, `_buildStairSubBar`, `_buildBeamSubBar` (4 methods) ---
  Widget _buildColumnSubBar(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.selectedColumn;
    final effectiveShape = selected?.shape ?? columnShape;
    final effectiveWidth = selected?.width ?? columnWidth;
    final effectiveDepth = selected?.depth ?? columnDepth;
    final effectiveHeight =
        selected?.height ?? columnHeight ?? widget.activeStoreyHeight;
    final effectiveBaseOffset = selected?.baseOffset ?? columnBaseOffset;
    final isCircular = effectiveShape == ColumnShape.circular;
    final widthLabel =
        isCircular ? l10n.propertiesDiameter : l10n.architectPropertyWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('column-shape-rect'),
            avatar: AppIcon(AppIconId.rectangle, size: 14),
            label: Text(l10n.architectColumnRect),
            selected: !isCircular,
            onSelected: (sel) {
              if (sel) onColumnShapeChanged?.call(ColumnShape.rectangular);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            key: const ValueKey('column-shape-circle'),
            avatar: AppIcon(AppIconId.radioOff, size: 14),
            label: Text(l10n.architectColumnCircle),
            selected: isCircular,
            onSelected: (sel) {
              if (sel) onColumnShapeChanged?.call(ColumnShape.circular);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(widthLabel),
          _buildOpeningDimensionChip(
            key: const ValueKey('column-width-input'),
            label: widthLabel,
            valueMeters: effectiveWidth,
            minCm: 5,
            maxCm: 500,
            onChangedMeters: onColumnWidthChanged,
          ),
          if (!isCircular) ...[
            const SizedBox(width: 10),
            _buildOpeningDimensionLabel(l10n.architectPropertyDepth),
            _buildOpeningDimensionChip(
              key: const ValueKey('column-depth-input'),
              label: l10n.architectPropertyDepth,
              valueMeters: effectiveDepth,
              minCm: 5,
              maxCm: 500,
              onChangedMeters: onColumnDepthChanged,
            ),
          ],
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l10n.architectPropertyHeight),
          _buildOpeningDimensionChip(
            key: const ValueKey('column-height-input'),
            label: l10n.architectPropertyHeight,
            valueMeters: effectiveHeight,
            minCm: 30,
            maxCm: 2000,
            onChangedMeters: onColumnHeightChanged,
          ),
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l10n.architectColumnBaseOffset),
          _buildOpeningDimensionChip(
            key: const ValueKey('column-base-offset-input'),
            label: l10n.architectColumnBaseOffset,
            valueMeters: effectiveBaseOffset,
            minCm: -1000,
            maxCm: 1000,
            allowNegative: true,
            onChangedMeters: onColumnBaseOffsetChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBeamSubBar(BuildContext context) {
    final l10n = context.l10n;
    final selected = widget.selectedBeam;
    final effectiveWidth = selected?.width ?? beamWidth;
    final effectiveDepth = selected?.depth ?? beamDepth;
    final effectiveBaseOffset = selected?.baseOffset ?? beamBaseOffset;
    final effectiveSlopeDegrees = selected?.slopeDegrees ?? beamSlopeDegrees;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildOpeningDimensionLabel(l10n.architectPropertyWidth),
          _buildOpeningDimensionChip(
            key: const ValueKey('beam-width-input'),
            label: l10n.architectPropertyWidth,
            valueMeters: effectiveWidth,
            minCm: 5,
            maxCm: 500,
            onChangedMeters: onBeamWidthChanged,
          ),
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l10n.architectPropertyDepth),
          _buildOpeningDimensionChip(
            key: const ValueKey('beam-depth-input'),
            label: l10n.architectPropertyDepth,
            valueMeters: effectiveDepth,
            minCm: 5,
            maxCm: 500,
            onChangedMeters: onBeamDepthChanged,
          ),
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l10n.architectColumnBaseOffset),
          _buildOpeningDimensionChip(
            key: const ValueKey('beam-base-offset-input'),
            label: l10n.architectColumnBaseOffset,
            valueMeters: effectiveBaseOffset,
            minCm: -1000,
            maxCm: 1000,
            allowNegative: true,
            onChangedMeters: onBeamBaseOffsetChanged,
          ),
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l10n.propertiesSlope),
          _buildNumericKeypadChip(
            key: const ValueKey('beam-slope-input'),
            label: l10n.propertiesSlope,
            displayValue: effectiveSlopeDegrees,
            unitLabel: '°',
            chipSuffix: '°',
            min: -75,
            max: 75,
            allowNegative: true,
            onChanged: onBeamSlopeChanged,
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
          if (activeTool == ArchitectTool.component)
            _buildToolButton(
              tool: ArchitectTool.component,
              icon: AppIconId.component,
              label: l.architectToolComponent,
              tooltip: l.architectComponentPlacementHelp,
            ),
          Tooltip(
            message: '${l.architectLibrary}: ${componentLabel(l, activeDef)}',
            child: IconButton(
              key: const ValueKey('component-tool-library-btn'),
              icon: AppIcon(AppIconId.library, size: 20, color: colors.primary),
              onPressed: widget.onOpenComponentLibrary,
            ),
          ),
          Tooltip(
            message:
                activeTool == ArchitectTool.services &&
                    ServiceComponentDefinition.continuousIds.contains(
                      activeDef.id,
                    ) &&
                    activeParams['autoHeight'] != false
                ? '${componentDimensionCm(w)}×${componentDimensionCm(d)} cm • ${l.architectServiceAutoHeight}'
                : '${componentDimensionCm(w)}×${componentDimensionCm(d)}×${componentDimensionCm(h)} cm',
            child: TextButton.icon(
              key: const ValueKey('component-tool-size-btn'),
              icon: AppIcon(AppIconId.measure, size: 18),
              label: Text(l.architectPropertySize),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
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
            icon: AppIcon(
              AppIconId.rotate,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            onPressed: widget.onRotateComponent,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStairShapeButtons(BuildContext context) {
    final l = context.l10n;
    final effectiveDesign = widget.selectedStair?.design ?? widget.stairDesign;
    final effectiveShape = effectiveDesign.layout == null
        ? effectiveDesign.shape
        : null;
    AppIconId iconForShape(StairShape shape) => switch (shape) {
      StairShape.straight => AppIconId.stairs,
      StairShape.quarterTurn => AppIconId.turnRight,
      StairShape.halfTurn => AppIconId.swapHorizontal,
      StairShape.spiral => AppIconId.rotate,
      StairShape.spiralOverlap => AppIconId.rotateLeft,
    };
    return [
      for (final shape in StairShape.values)
        KeyedSubtree(
          key: ValueKey('stair-shape-${shape.name}'),
          child: _buildToolButton(
            tool: ArchitectTool.stair,
            buttonKey: shape == effectiveDesign.shape
                ? 'architect-tool-stair'
                : 'stair-shape-btn-${shape.name}',
            icon: iconForShape(shape),
            label: stairShapeLabel(l, shape),
            selected:
                (widget.selectedStair != null ||
                    activeTool == ArchitectTool.stair) &&
                effectiveShape == shape,
            onPressed: () {
              final isCurrentlySelected =
                  widget.selectedStair != null && effectiveShape == shape;
              final isCurrentlyDrawingThis =
                  widget.selectedStair == null &&
                  activeTool == ArchitectTool.stair &&
                  effectiveShape == shape;
              if (isCurrentlyDrawingThis &&
                  mode != ArchitectInteractionMode.contextEdit) {
                onToolChanged(ArchitectTool.pan);
                return;
              }
              if (isCurrentlySelected) return;
              widget.onStairShapeChanged?.call(shape);
              if (widget.selectedStair == null &&
                  activeTool != ArchitectTool.stair) {
                onToolChanged(ArchitectTool.stair);
              }
            },
          ),
        ),
      if (widget.onFreeStair != null)
        _buildToolButton(
          tool: ArchitectTool.stair,
          buttonKey: 'stair-tool-freeform',
          icon: AppIconId.polyline,
          label: l.stairCustom,
          selected:
              widget.selectedStair != null && effectiveDesign.layout != null,
          onPressed: widget.onFreeStair,
        ),
    ];
  }

  Widget _buildStairSubBar(BuildContext context) {
    final l = context.l10n;
    final selected = widget.selectedStair;
    final effectiveWidth = selected?.width ?? stairWidth;
    final effectiveDesign = selected?.design ?? widget.stairDesign;
    final hasCustomLayout = effectiveDesign.layout != null;
    final showFlightWidth =
        !hasCustomLayout || effectiveDesign.layout!.flights.isNotEmpty;
    final showTotalWidth =
        !hasCustomLayout &&
        effectiveDesign.shape == StairShape.halfTurn &&
        !effectiveDesign.hasWinders;
    final showOuterDiameter = !hasCustomLayout && effectiveDesign.isSpiral;
    final showLandingDepth =
        !hasCustomLayout &&
        !effectiveDesign.isSpiral &&
        !effectiveDesign.hasWinders &&
        effectiveDesign.flightCount > 1;
    final showLandingOffset =
        !hasCustomLayout &&
        (effectiveDesign.shape == StairShape.quarterTurn ||
            effectiveDesign.shape == StairShape.halfTurn) &&
        !effectiveDesign.hasWinders;
    final showGoing = !effectiveDesign.isSpiral;

    ({double length, double width})? overallPlanSize() {
      try {
        final plan = ArchitectStairPlan.build(
          start: Offset.zero,
          direction: const Offset(1, 0),
          width: effectiveWidth,
          design: effectiveDesign,
        );
        final size = plan.bounds.size;
        return (length: size.width, width: size.height);
      } on ArgumentError {
        return null;
      }
    }

    final overall = (!hasCustomLayout && !showTotalWidth && !showOuterDiameter)
        ? overallPlanSize()
        : null;
    final riserWarning = ArchitectStairRules.isRiserOutOfRange(
      effectiveDesign.riser,
    );
    final riserWarnText = riserWarning ? stairRiserRangeWarningText(l) : null;
    final wellGapText =
        '${ArchitectUnit.trimZeros((effectiveDesign.wellGap(effectiveWidth) * 100).toStringAsFixed(1))} cm';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (showFlightWidth) ...[
            _buildOpeningDimensionLabel(l.stairQuickFlightWidth),
            _buildOpeningDimensionChip(
              key: const ValueKey('stair-width-input'),
              label: l.stairClearWidth,
              valueMeters: effectiveWidth,
              minCm: 40,
              maxCm: 1000,
              onChangedMeters: widget.onStairWidthChanged,
            ),
          ],
          if (showTotalWidth) ...[
            const SizedBox(width: 10),
            _buildOpeningDimensionLabel(l.stairQuickTotalWidth),
            _buildOpeningDimensionChip(
              key: const ValueKey('stair-total-width-input'),
              label: l.stairTotalWidth,
              valueMeters: effectiveDesign.effectiveTotalWidth(effectiveWidth),
              minCm: (2 * effectiveWidth * 100).ceilToDouble(),
              maxCm: 2000,
              onChangedMeters: widget.onStairTotalWidthChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                l.stairQuickWellGap(wellGapText),
                key: const ValueKey('stair-well-gap'),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
          if (showOuterDiameter) ...[
            const SizedBox(width: 10),
            _buildOpeningDimensionLabel(l.stairQuickOuterDiameter),
            _buildOpeningDimensionChip(
              key: const ValueKey('stair-outer-diameter-input'),
              label: l.stairQuickOuterDiameter,
              valueMeters: 2 * (effectiveDesign.innerRadius + effectiveWidth),
              minCm: ((2 * effectiveWidth + 0.10) * 100).ceilToDouble(),
              maxCm: 3000,
              onChangedMeters: widget.onStairOuterDiameterChanged,
            ),
          ],
          if (showLandingDepth) ...[
            const SizedBox(width: 10),
            _buildOpeningDimensionLabel(l.stairQuickLanding),
            _buildOpeningDimensionChip(
              key: const ValueKey('stair-landing-depth-input'),
              label: l.stairLanding,
              valueMeters: math.max(effectiveWidth, effectiveDesign.landingDepth),
              minCm: (effectiveWidth * 100).ceilToDouble(),
              maxCm: 1000,
              onChangedMeters: widget.onStairLandingDepthChanged,
            ),
          ],
          if (showLandingOffset) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: l.stairLandingOffsetHelp,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOpeningDimensionLabel(l.stairQuickLandingOffset),
                  _buildOpeningDimensionChip(
                    key: const ValueKey('stair-landing-offset-input'),
                    label: l.stairLandingOffset,
                    valueMeters: effectiveDesign.landingStepOffset,
                    minCm: 0,
                    maxCm: 100,
                    onChangedMeters: widget.onStairLandingOffsetChanged,
                  ),
                ],
              ),
            ),
          ],
          if (showFlightWidth || showTotalWidth || showOuterDiameter)
            const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l.stairQuickHeight),
          _buildOpeningDimensionChip(
            key: const ValueKey('stair-rise-input'),
            label: l.stairRise,
            valueMeters: effectiveDesign.rise,
            minCm: 30,
            maxCm: 3000,
            onChangedMeters: widget.onStairRiseChanged,
          ),
          if (showGoing) ...[
            const SizedBox(width: 10),
            _buildOpeningDimensionLabel(l.stairQuickTread),
            _buildOpeningDimensionChip(
              key: const ValueKey('stair-going-input'),
              label: l.stairGoing,
              valueMeters: effectiveDesign.going,
              minCm: 15,
              maxCm: 100,
              onChangedMeters: widget.onStairGoingChanged,
            ),
          ],
          const SizedBox(width: 10),
          _buildOpeningDimensionLabel(l.stairQuickRiser),
          _buildOpeningDimensionChip(
            key: const ValueKey('stair-riser-input'),
            label: l.stairRiser,
            valueMeters: effectiveDesign.riser,
            minCm: 8,
            maxCm: 30,
            warning: riserWarning,
            warningTooltip: riserWarnText,
            onChangedMeters: widget.onStairRiserChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              l.stairQuickStepsCount(effectiveDesign.risers),
              key: const ValueKey('stair-risers-count'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
          if (overall != null) ...[
            const SizedBox(width: 10),
            Text(
              '${l.stairQuickTotalWidth}: '
              '${(overall.length * 100).round()}×${(overall.width * 100).round()} cm',
              key: const ValueKey('stair-overall-size'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (!hasCustomLayout &&
              effectiveDesign.shape != StairShape.straight &&
              widget.onStairTurnChanged != null) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('stair-tool-turn'),
              tooltip: effectiveDesign.turnLeft
                  ? l.stairTurnRight
                  : l.stairTurnLeft,
              icon: AppIcon(
                effectiveDesign.turnLeft
                    ? AppIconId.turnLeft
                    : AppIconId.turnRight,
                color: colors.onSurfaceVariant,
              ),
              onPressed: () =>
                  widget.onStairTurnChanged?.call(!effectiveDesign.turnLeft),
            ),
          ],
          IconButton(
            key: const ValueKey('stair-tool-properties'),
            tooltip: l.architectProperties,
            icon: AppIcon(AppIconId.properties, color: colors.onSurfaceVariant),
            onPressed: widget.onStairProperties,
          ),
          Tooltip(
            message: l.stairPlaceHelp,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: AppIcon(
                AppIconId.help,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === SECTION: [SEC-07-OPENINGS] DOORS, WINDOWS & OPENINGS ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_OPENING_SUB] Doors, Windows & Openings: `_buildOpeningSubBar`, `_buildZoneSubBar` (2 methods) ---
  Widget _buildOpeningSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            avatar: AppIcon(AppIconId.rectangle, size: 14),
            label: Text(l10n.architectOpeningShaft),
            selected: openingType == OpeningType.shaft,
            onSelected: (sel) {
              if (sel) onOpeningTypeChanged?.call(OpeningType.shaft);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            avatar: AppIcon(AppIconId.exitFullscreen, size: 14),
            label: Text(l10n.architectOpeningVoid),
            selected: openingType == OpeningType.floorVoid,
            onSelected: (sel) {
              if (sel) onOpeningTypeChanged?.call(OpeningType.floorVoid);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: l10n.architectOpeningCircularHelp,
            child: ChoiceChip(
              key: const ValueKey('opening-circular'),
              avatar: const AppIcon(AppIconId.radioOff, size: 14),
              label: Text(l10n.architectOpeningCircular),
              selected: openingType == OpeningType.circular,
              onSelected: (selected) {
                if (selected) onOpeningTypeChanged?.call(OpeningType.circular);
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneSubBar(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: 240,
      child: DropdownButton<ArchitectZoneCategory>(
        dropdownColor: colors.surfaceContainerHigh,
        style: TextStyle(color: colors.onSurface, fontSize: 13),
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

  // === SECTION: [SEC-08-HITS] HIT TESTING & CANDIDATE PICKING ===
  // --- SUBSECTION: [TAG:ARCH_PALETTE_HIT_TESTING] Hit Testing & Candidate Picking: `_showStylePicker`, `_buildViewsSubBar`, `_buildDecorativeSubBar` (3 methods) ---
  void _showStylePicker(BuildContext context, FenestrationKind kind) {
    final l10n = context.l10n;
    final styles = FenestrationLibraryService.instance.getStylesForKind(kind);
    final activeStyle = kind == FenestrationKind.door
        ? (widget.selectedDoor?.resolvedStyle ?? activeDoorStyle)
        : (widget.selectedWindow?.resolvedStyle ?? activeWindowStyle);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
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
                    AppIcon(
                      kind == FenestrationKind.door
                          ? AppIconId.door
                          : AppIconId.window,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.architectFenestrationSelectStyle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (onCreateFenestration != null)
                      TextButton.icon(
                        icon: AppIcon(AppIconId.add, size: 16),
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
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: FenestrationPreview(style: s),
                      ),
                      title: Text(
                        s.localizedName(l10n),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: s.hasCasing
                          ? Text(
                              l10n.architectFenestrationCasing,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              s.isPreset
                                  ? l10n.architectFenestrationPreset
                                  : l10n.architectFenestrationCustom,
                              style: TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          if (!s.isPreset)
                            IconButton(
                              icon: AppIcon(
                                AppIconId.delete,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: l10n.delete,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dialogCtx) => architectAlertDialog(
                                    title: Text(
                                      l10n.architectFenestrationDelete,
                                    ),
                                    content: Text(
                                      l10n.architectFenestrationDeleteConfirm(
                                        s.localizedName(l10n),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await FenestrationLibraryService.instance
                                      .deleteStyle(s.id);
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.architectFenestrationDeleteSuccess,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
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

  Widget _buildDecorativeSubBar(BuildContext context) {
    return ArchitectDecorativeBar(
      activeTool: activeTool,
      unit: widget.wallUnit,
      depth: widget.decorativeDepth,
      spanLength: widget.decorativeSpanLength,
      frameWidth: widget.decorativeFrameWidth,
      normalOffset: widget.decorativeNormalOffset,
      material: widget.decorativeMaterial,
      activePreset: widget.activeDecorativePreset,
      showOnPlan: widget.showDecorativeOnPlan,
      onDepthChanged: widget.onDecorativeDepthChanged,
      onSpanLengthChanged: widget.onDecorativeSpanLengthChanged,
      onFrameWidthChanged: widget.onDecorativeFrameWidthChanged,
      onNormalOffsetChanged: widget.onDecorativeNormalOffsetChanged,
      onMaterialChanged: widget.onDecorativeMaterialChanged,
      onPresetChanged: widget.onDecorativePresetChanged,
      onShowOnPlanChanged: widget.onShowDecorativeOnPlanChanged,
      onOpenStudio: widget.onOpenDecorativeStudio,
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
          AppIcon(
            isSection ? AppIconId.section : AppIconId.building,
            color: colors.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isSection ? l10n.architectSectionHint : l10n.architectElevationHint,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
