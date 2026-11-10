import 'architect_selection_painter.dart';
import 'architect_roof_drainage_painter.dart';
import '../models/architect_line_style.dart';
import '../services/architect_polyline_editing.dart';
import '../models/architect_hatch_pattern.dart';
import 'architect_clearance_badge_layout.dart';
import 'architect_floor_drain_painter_helper.dart';
import 'architect_vector_scene.dart';
import '../models/architect_wall_type.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'architect_canvas_palette.dart';
import 'architect_elevation_markers.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../models/architect_column.dart';
import 'architect_elements_painter_helper.dart';
import 'architect_polygon_painter.dart';
import '../models/architect_elements.dart';
import 'architect_grid_axis_painter_helper.dart';
import 'architect_zone_painter_helper.dart';
import 'architect_scene_geometry.dart';
import 'architect_wall_network.dart';
import 'architect_wall_exterior_painter.dart';
import 'architect_wall_layers.dart';
import 'architect_wall_hatch.dart';
import '../models/architect_wall.dart';
import '../models/architect_door.dart';
import '../models/architect_window.dart';
import 'architect_dimension_layout.dart';
import '../services/architect_selection.dart';
import '../services/architect_decorative_geometry.dart';
import '../services/architect_wall_relations.dart';
import '../services/architect_wall_overshoot_detector.dart';
import '../models/architect_overhang.dart';
import '../services/architect_overhang_detector.dart';
import 'architect_overhang_painter_helper.dart';
import '../services/architect_roof_tool.dart';
import '../services/architect_landscape_tool.dart';
import '../services/architect_drag_controller.dart';
import 'architect_drag_painter_helper.dart';
import 'architect_landscape_painter_helper.dart';
import 'architect_service_plan_painter.dart';
import 'architect_roof_painter_helper.dart';
import 'architect_railing_geometry.dart';

// ============================================================================
// MASTER ARCHITECT 2D PAINTER LLM SEARCH INDEX & TABLE OF CONTENTS
// ============================================================================
// COMPANION MAP: See 'architect_2d_painter.index.md' for full method & class directory.
// QUICK GREP:   grep "=== SECTION: [SEC-" or grep "--- SUBSECTION: [TAG:"
//
// [SEC-01-ENUMS]   L66-L125     : [TAG:ARCH_PAINTER_ENUMS] Declarations: `ArchitectPaintLayer`, `ArchitectTool`, `WallDraftingM
// [SEC-02-STATE]   L126-L387    : [TAG:ARCH_PAINTER_STATE] `Architect2dPainter` state fields (111 fields: `_project`, `_visible
// [SEC-03-PAINT]   L388-L734    : [TAG:ARCH_PAINTER_PAINT_RENDER] Canvas Painting & Geometry Rendering: `_paint`, `paint` (2 methods)
// [SEC-04-CORE]    L735-L825    : [TAG:ARCH_PAINTER_CORE_LOGIC] Core Operations & Helpers: `_filterElements` (1 methods)
// [SEC-05-PAINT]   L826-L1011   : [TAG:ARCH_PAINTER_DRAW_SELECTED] Canvas Painting & Geometry Rendering: `_drawSelectedElement`, `_draw
// [SEC-06-WALLS]   L1012-L1226  : [TAG:ARCH_PAINTER_WALL_OPS] Wall Drafting, Splitting & Joints: `_drawPolygonEditing`, `_drawNewP
// [SEC-07-GRIDS]   L1227-L1388  : [TAG:ARCH_PAINTER_GRID_AXES] Grid Axes, Alignment & Snapping: `_drawDraftingGrid`, `_drawGridAxes
// [SEC-08-WALLS]   L1389-L1556  : [TAG:ARCH_PAINTER_DRAW_WALLS] Wall Drafting, Splitting & Joints: `_drawWalls`, `_drawWallLayers` (
// [SEC-09-PAINT]   L1557-L2260  : [TAG:ARCH_PAINTER_DRAW_ACTIVE] Canvas Painting & Geometry Rendering: `_drawActiveDrafting`, `_drawD
// [SEC-10-CORE]    L2261-L2302  : [TAG:ARCH_PAINTER_SHOULD_REPAINT] Core Operations & Helpers: `shouldRepaint` (1 methods)
// ============================================================================


// === SECTION: [SEC-01-ENUMS] ENUMS & CONFIGURATION TYPES ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_ENUMS] Declarations: `ArchitectPaintLayer`, `ArchitectTool`, `WallDrafti ---
enum ArchitectPaintLayer { all, model, interaction }

enum ArchitectTool {
  select,
  drag,
  axis,
  zone,
  zoneTable,
  wall,
  door,
  window,
  column,
  beam,
  slab,
  roof,
  opening,
  stair,
  component,
  dimension,
  level,
  text,
  cadLine,
  cadRect,
  cadCircle,
  cadArc,
  mask,
  leader,
  spline,
  cadEllipse,
  roofSlope,
  measure,
  hatch,
  floorDrain,
  section,
  elevation,
  pan,
  services,
  decorativeProfile,
  decorativeFrame,
  decorativeArc,
  decorativeVoid,
  decorativeLibrary,
  cadUnderlay,
  rasterUnderlay,
  terrain,
  contour,
  pathway,
  vegetation,
  siteFence,
  street;

  bool get isLandscapeTool =>
      this == terrain ||
      this == contour ||
      this == pathway ||
      this == vegetation ||
      this == siteFence ||
      this == street;

  bool get usesComponent => this == component || this == services;

  bool get isUnderlayTool => this == cadUnderlay || this == rasterUnderlay;

  bool get isDecorativeTool =>
      this == decorativeProfile ||
      this == decorativeFrame ||
      this == decorativeArc ||
      this == decorativeVoid ||
      this == decorativeLibrary;
}

enum WallDraftingMode { singleLine, chained }

// === SECTION: [SEC-02-STATE] ARCHITECT2DPAINTER STATE & FIELDS ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_STATE] `Architect2dPainter` state fields (111 fields: `_project`, `_visi ---
/// High-performance 2D architectural floor plan painter.
class Architect2dPainter extends CustomPainter {
  final ArchitectProject _project;
  ArchitectProject? _visibleProject;
  ArchitectProject get project => _visibleProject ?? _project;
  final BimViewportController? viewport;
  final ArchitectPaintLayer layer;
  final bool paintGrid;
  /// Publication can share physical wall geometry between annotation scales.
  final ArchitectWallLayers? publicationWallLayers;
  final String? drawingViewKey;
  final ArchitectCanvasPalette palette;
  final AppLocalizations? l10n;
  final ArchitectTool activeTool;
  final OpeningType activeOpeningType;
  final bool showServiceProjections;
  final ArchitectLineStyle activeCadLineStyle;
  final List<ArchitectMaterialLayer> activeWallLayers;
  final Offset? activeWallArcEnd;
  final double? activeWallArcBulge;
  final bool activeWallCurved;
  final Offset? activeDraftStart;
  final Offset? activeDraftEnd;
  final ArchitectStair? stairPreview;
  final double activeWallThickness;
  final WallReferenceLine activeWallReference;
  final String? activeWallTypeId;
  final ArchitectRailingDesign? activeWallRailing;
  final double? activeWallHeight;
  final WallExteriorSide activeWallExteriorSide;
  final bool activeWallIsExterior, activeWallSideManual;
  final Set<String> wallExteriorReviewIds;
  final double? activeWallInsulation;
  final bool showWallCursor;
  final (Offset, Offset)? wallCutGuideLine;
  final Offset? wallCutAnchor;
  final (Offset, Offset)? wallCutLine;
  final Offset? mirrorAnchor;
  final (Offset, Offset)? mirrorAxisLine;
  final Offset? splitPoint1;
  final (Offset, Offset)? splitPerpendicularGuide;
  final (Offset, Offset)? splitCutLine;
  final (Offset, Offset)? wallJoinLeaderLine;
  final ArchitectWallTrimSpan? wallTrimSpan;
  final List<ArchitectWallClearance> wallClearances;
  final List<ArchitectOpeningClearance> openingClearances;
  final bool showOpeningClearanceBadges;
  final ArchitectDoor? doorPreview;
  final ArchitectWindow? windowPreview;
  final Set<String> selectedElementIds;
  final bool selectionPreviewActive;
  final Set<String> selectionPreviewIds, selectionPreviewAddedIds, selectionPreviewRemovedIds;
  final bool marqueeContained;
  final Offset? marqueeCandidate;
  final Path? dimensionWallObstacles;
  final String? activeSnapLabel;
  final String? selectedElementId;
  final String? selectedZoneId;
  final ArchitectZoneCategory? activeZoneCategory;
  final int? draggingVertexIndex;
  final Offset? draggingVertexPoint;
  final int? mergeCandidateIndex;
  final List<(Offset, Offset)> magneticGuides;
  final List<Offset> midpointHints;
  final double _zoomScale;
  double get zoomScale => viewport?.scale ?? _zoomScale;

  /// Clamped scale for auxiliary drafting indicators (dots, handles, ticks, badges)
  /// so they never dynamically enlarge in model/world space when zooming out.
  static const double minDraftingScale = 80.0;
  double get draftingScale => math.max(zoomScale, minDraftingScale);
  final Offset? cursorPosition;
  final ArchitectColumn? columnPreview;

  // Dynamic Grid Axis state
  final String? selectedAxisId;
  final StructuralGridAxis? draggedAxisSnapshot;
  final bool isDraggingAxisHandle;
  final bool isMovingAxis;
  final StructuralGridAxis? moveOriginalAxis;
  final Offset? moveCurrentDelta;
  final StructuralGridAxis? axisOffsetPreview;
  final Offset? axisDraftStart;
  final Offset? axisDraftEnd;
  final String? axisDraftSnapLabel;

  // Point-by-point zone drafting
  final List<Offset> zoneDraftingPoints;
  final Offset? zoneDraftingCandidate;
  final (Offset, Offset)? zoneOrthoGuide;
  final String? zoneOrthoLabel;
  final bool isZoneClosingSnap;
  final bool isZoneDraftingSelfIntersecting;
  final String? zoneCloseLabel;
  final String? zoneCategoryName;

  // Edge extrusion preview
  final List<Offset>? zoneExtrudePreviewPolygon;
  final Offset? zoneExtrudeV1;
  final Offset? zoneExtrudeV2;
  final Offset? zoneExtrudeNormal;
  final double? zoneExtrudeDistance;
  final bool isZoneExtrudeSelfIntersecting;

  // Zone Editing and Fast Rectangle Preview
  final List<Offset> zonePreviewRectangle;
  final List<Offset>? zoneEditingPolygon;

  // Zone Schedule Table
  final String? selectedZoneTableId;
  final bool isZoneTableSelected;
  final Offset? zoneTableDragPreviewOrigin;

  // CAD Underlay state
  final DxfDocument? underlayDoc;
  final Map<String, bool> underlayLayerVisibility;

  // Slab drafting state
  final List<Offset> slabDraftPoints;
  final ArchitectHatchPattern activeHatchPattern;
  final int activeHatchColorValue;
  final Offset? slabCandidatePoint;
  final ArchitectRoofTool? roofTool;
  final ArchitectLandscapeTool? landscapeTool;
  final ArchitectDragController? dragController;
  final String? Function(String)? localizeSnap;
  final bool polygonEditInvalid;
  final int? polygonEditHoleIndex;
  final (Offset, Offset)? polygonLeaderLine;
  final double handleOffsetLength;
  final (Offset, Offset)? wallEndpointLeaderLine;
  final Offset? newPointCandidate;
  final Offset? newPointHandleOffset;
  final bool newPointValid;
  final (Offset, Offset)? newPointLeaderLine;
  final ArchitectWallOvershoot? activeOvershoot;
  final List<ArchitectOverhang>? upperOverhangs;
  final bool showUpperOverhangs;
  final bool showFurniture;
  final ArchitectComponentInstance? componentPreview;
  final List<Offset> marqueePoints;
  final List<Offset> marqueePolygon;

  Architect2dPainter({
    required ArchitectProject project,
    this.viewport,
    this.l10n,
    this.layer = ArchitectPaintLayer.all,
    this.paintGrid = true,
    this.publicationWallLayers,
    this.drawingViewKey,
    this.palette = const ArchitectCanvasPalette.light(),
    this.activeOvershoot,
    this.upperOverhangs,
    this.showUpperOverhangs = true,
    this.showFurniture = true,
    this.dragController,
    this.localizeSnap,
    this.componentPreview,
    this.marqueePoints = const [],
    this.marqueePolygon = const [],
    required this.activeTool,
    this.activeOpeningType = OpeningType.shaft,
    this.showServiceProjections = true,
    this.activeCadLineStyle = ArchitectLineStyle.solid,
    this.activeWallLayers = const [],
    this.activeWallArcEnd,
    this.activeWallArcBulge,
    this.activeWallCurved = false,
    this.activeDraftStart,
    this.activeDraftEnd,
    this.stairPreview,
    this.activeWallThickness = 0.25,
    this.activeWallReference = WallReferenceLine.center,
    this.activeWallTypeId,
    this.activeWallRailing,
    this.activeWallHeight,
    this.activeWallExteriorSide = WallExteriorSide.left,
    this.activeWallIsExterior = true,
    this.activeWallSideManual = false,
    this.wallExteriorReviewIds = const {},
    this.activeWallInsulation,
    this.showWallCursor = true,
    this.wallCutGuideLine,
    this.wallCutAnchor,
    this.wallCutLine,
    this.mirrorAnchor,
    this.mirrorAxisLine,
    this.splitPoint1,
    this.splitPerpendicularGuide,
    this.splitCutLine,
    this.wallJoinLeaderLine,
    this.wallTrimSpan,
    this.wallClearances = const [],
    this.openingClearances = const [],
    this.showOpeningClearanceBadges = false,
    this.doorPreview,
    this.windowPreview,
    this.selectedElementIds = const {},
    this.selectionPreviewActive=false,
    this.selectionPreviewIds=const {},this.selectionPreviewAddedIds=const {},this.selectionPreviewRemovedIds=const {},
    this.marqueeContained=false,this.marqueeCandidate,
    this.dimensionWallObstacles,
    this.activeSnapLabel,
    this.selectedElementId,
    this.selectedZoneId,
    this.activeZoneCategory,
    this.draggingVertexIndex,
    this.draggingVertexPoint,
    this.mergeCandidateIndex,
    this.magneticGuides = const [],
    this.midpointHints = const [],
    double zoomScale = 1.0,
    this.cursorPosition,
    this.columnPreview,
    this.selectedAxisId,
    this.draggedAxisSnapshot,
    this.isDraggingAxisHandle = false,
    this.isMovingAxis = false,
    this.moveOriginalAxis,
    this.moveCurrentDelta,
    this.axisOffsetPreview,
    this.axisDraftStart,
    this.axisDraftEnd,
    this.axisDraftSnapLabel,
    this.zoneDraftingPoints = const [],
    this.zoneDraftingCandidate,
    this.zoneOrthoGuide,
    this.zoneOrthoLabel,
    this.isZoneClosingSnap = false,
    this.isZoneDraftingSelfIntersecting = false,
    this.zoneCloseLabel,
    this.zoneCategoryName,
    this.zoneExtrudePreviewPolygon,

    this.zoneExtrudeV1,
    this.zoneExtrudeV2,
    this.zoneExtrudeNormal,
    this.zoneExtrudeDistance,
    this.isZoneExtrudeSelfIntersecting = false,
    this.zonePreviewRectangle = const [],
    this.zoneEditingPolygon,
    this.isZoneTableSelected = false,
    this.selectedZoneTableId,
    this.zoneTableDragPreviewOrigin,
    this.underlayDoc,
    this.underlayLayerVisibility = const {},
    this.slabDraftPoints = const [],
    this.activeHatchPattern = ArchitectHatchPattern.diagonal,
    this.activeHatchColorValue = 0xFF424242,
    this.slabCandidatePoint,
    this.roofTool,
    this.landscapeTool,
    this.polygonEditInvalid = false,
    this.polygonEditHoleIndex,
    this.polygonLeaderLine,
    this.handleOffsetLength = 50.0,
    this.wallEndpointLeaderLine,
    this.newPointCandidate,
    this.newPointHandleOffset,
    this.newPointValid = true,
    this.newPointLeaderLine,
  }) : _project = project,
       _zoomScale = zoomScale,
       super(repaint: viewport);

// === SECTION: [SEC-03-PAINT] CANVAS PAINTING & GEOMETRY RENDERING ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_PAINT_RENDER] Canvas Painting & Geometry Rendering: `_paint`, `paint` (2 method ---
  @override
  void paint(Canvas canvas, Size size) {
    if (ArchitectTextScope.current == null) {
      final key = drawingViewKey ?? 'plan:${_project.activeStoreyId}';
      final denominator = _project.document.viewScales[key] ?? _project.dimensionScale.denominator;
      ArchitectTextScope(_project.document, key, denominator, zoomScale, units: _project.units, decimals: _project.distanceDecimals, levelUnits: _project.levelUnits, levelDecimals: _project.levelDecimals).run(() => _paint(canvas, size));
    } else { _paint(canvas, size); }
  }
  void _paint(Canvas canvas, Size size) {
    canvas.save();
    if (viewport != null) {
      canvas.translate(viewport!.translation.dx, viewport!.translation.dy);
      canvas.scale(zoomScale);
    }
    // Interaction renders the selected objects even while their preview moves
    // outside the original bounds. The static layer is culled to the camera.
    _visibleProject =
        viewport != null && layer != ArchitectPaintLayer.interaction
        ? ArchitectSceneGeometry.visible(
            _project,
            viewport!.visibleRect,
            zoomScale,
          )
        : null;
    if (layer != ArchitectPaintLayer.interaction) {
      if (underlayDoc != null) {
        ArchitectElementsPainterHelper.drawUnderlay(
          palette: palette,
          canvas: canvas,
          underlayDoc: underlayDoc,
          zoomScale: zoomScale,
          layerVisibility: underlayLayerVisibility,
        );
      }
      if (paintGrid) _drawDraftingGrid(canvas, size);
      ArchitectLandscapePainterHelper.drawTerrain(
        canvas: canvas,
        project: _project,
        zoomScale: zoomScale,
        selectedIds: {...selectedElementIds, ?selectedElementId},
        palette: palette,
      );
      ArchitectLandscapePainterHelper.drawPathways(
        canvas: canvas,
        project: _project,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedIds: {...selectedElementIds, ?selectedElementId},
        palette: palette,
      );
      ArchitectLandscapePainterHelper.drawStreets(
        canvas: canvas,
        project: _project,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedIds: {...selectedElementIds, ?selectedElementId},
        palette: palette,
      );
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas, storey: _elementLayerStorey, zoomScale: zoomScale,
        palette: palette, dimensionScale: _project.dimensionScale,
        selectedElementId: null, hatchesOnly: true,
      );
      _drawGridAxes(canvas);
      ArchitectElementsPainterHelper.drawSlabs(
        project: _project,
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      _drawZones(canvas);
      ArchitectFloorDrainPainterHelper.draw(
        canvas: canvas,
        storey: _elementLayerStorey,
        walls: _project.activeStorey.walls,
        zoomScale: zoomScale,
        palette: palette,
      );
      _drawZoneSchedule(canvas);
      ArchitectLandscapePainterHelper.drawSiteFences(
        canvas: canvas,
        project: _project,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedIds: {...selectedElementIds, ?selectedElementId},
        palette: palette,
      );
      ArchitectLandscapePainterHelper.drawVegetation(
        canvas: canvas,
        project: _project,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedIds: {...selectedElementIds, ?selectedElementId},
        palette: palette,
      );
      if (showUpperOverhangs) {
        ArchitectOverhangPainterHelper.drawOverhangs(
          canvas: canvas,
          palette: palette,
          overhangs:
              upperOverhangs ?? ArchitectOverhangDetector.forProject(_project),
          zoomScale: zoomScale,
          l10n: l10n,
          selectedElementId: selectedElementId,
        );
      }
      ArchitectElementsPainterHelper.drawBeams(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      _drawWalls(canvas);
      ArchitectElementsPainterHelper.drawColumns(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawOpenings(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawStairs(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
        project: _project, l10n: l10n, dimensionScale: _project.dimensionScale,
      );
      if (_project.activeStorey.isRoof) {
        ArchitectRoofPainterHelper.drawSupportingWallUnderlay(
          canvas: canvas,
          project: _project,
          palette: palette,
          scale: zoomScale,
        );
        final lowerStoreys = _project.storeys
            .where((s) => s.id != _project.activeStorey.id && s.roofs.isNotEmpty);
        for (final lower in lowerStoreys) {
          ArchitectRoofPainterHelper.paintRoofs(
            canvas: canvas,
            storey: lower,
            project: _project,
            scale: zoomScale,
            selectedIds: selectedElementIds,
            isLowerLevel: true,
          );
        }
      }
      if (!_project.activeStorey.isRoof) {
        ArchitectRoofPainterHelper.paintOverhead(canvas: canvas, project: _project,
          scale: zoomScale, color: palette.foreground(Colors.black));
        ArchitectRoofDrainagePainter.paintStoreyPenetrations(
          canvas,
          _project,
          _elementLayerStorey,
          zoomScale,
        );
      }
      ArchitectRoofPainterHelper.paintRoofs(
        canvas: canvas,
        storey: _elementLayerStorey,
        project: _project,
        scale: zoomScale,
        selectedIds: {
          ...selectedElementIds,
          ?selectedElementId,
        },
      );
      ArchitectElementsPainterHelper.drawCadPrimitives(
        hatchesOnly: false,
        dimensionScale: _project.dimensionScale,
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      if (showServiceProjections) {
        ArchitectServicePlanPainter.roofOpenings(
          canvas: canvas, project: _project, storey: _elementLayerStorey,
          scale: zoomScale, palette: palette,
        );
      }
      ArchitectElementsPainterHelper.drawComponents(
        project: showServiceProjections ? _project : null,
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
        selectedElementIds: selectedElementIds,
        layerVisible: showFurniture,
      );
      if (componentPreview != null) {
        ArchitectElementsPainterHelper.drawComponents(
          palette: palette,
          canvas: canvas,
          storey: ArchitectStorey(id: "preview", name: "preview", components: [componentPreview!]),
          zoomScale: zoomScale,
          selectedElementId: componentPreview!.id,
          layerVisible: true,
        );
      }
      _drawDecorativeElements(canvas, _elementLayerStorey);
    }
    if (layer != ArchitectPaintLayer.model) {
      if (layer == ArchitectPaintLayer.interaction) {
        _drawGridAxes(canvas);
        _drawZones(canvas);
        _drawZoneSchedule(canvas);
        _drawSelectedElement(canvas);
      }
      if(marqueePoints.isEmpty) _drawPolygonEditing(canvas);
      _drawWallEndpointLeaderLine(canvas);
      _drawActiveDrafting(canvas);
      final directionIds = newPointCandidate != null ? const <String>{}
          : {...wallExteriorReviewIds, ...selectedElementIds, ?selectedElementId};
      for (final wall in project.activeStorey.walls) {
        if (directionIds.contains(wall.id)) {
          ArchitectWallExteriorPainter.draw(canvas, wall, zoomScale,
            palette.foreground(Colors.black87));
        }
      }
      for(final id in newPointCandidate != null ? const <String>[]
          : selectionPreviewActive?selectionPreviewIds:selectedElementIds) {
        final outline=ArchitectSelection.outline(project,id);
        if(selectionPreviewActive && selectionPreviewAddedIds.contains(id)) {
          ArchitectSelectionPainter.preview(canvas,outline,zoomScale,palette);
        } else {
          ArchitectSelectionPainter.outline(canvas,outline,zoomScale,palette);
        }
      }
      if(selectionPreviewActive) {
        for(final id in selectionPreviewRemovedIds) {
          ArchitectSelectionPainter.preview(canvas,ArchitectSelection.outline(project,id),zoomScale,palette,removed:true);
        }
      }
      ArchitectElementsPainterHelper.drawActiveElementsDrafting(
        canvas: canvas,
        activeTool: activeTool,
        openingType: activeOpeningType,
        draftStart: activeDraftStart,
        draftEnd: activeDraftEnd,
        stairPreview: stairPreview,
        stairStorey: _project.activeStorey, stairProject: _project,
        zoomScale: zoomScale,
        unit: _project.units,
        decimals: _project.distanceDecimals,
        lineStyle: activeCadLineStyle,
        dimensionScale: _project.dimensionScale,
      );
    }
    if (layer != ArchitectPaintLayer.interaction) {
      ArchitectElementsPainterHelper.drawDimensions(
        dimensionStorey: _project.activeStorey,
        gridAxes: _project.gridAxes,
        unit: _project.units,
        decimals: _project.distanceDecimals,
        dimensionScale: _project.dimensionScale,
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
        wallObstacles:
            dimensionWallObstacles ??
            ArchitectWallNetwork.body(_project.activeStorey.walls),
      );
      ArchitectElementsPainterHelper.drawElevationMarkers(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawAnnotations(
        palette: palette,
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      if (l10n != null) {
        drawArchitectElevationMarkers(canvas, _project, zoomScale, palette.foreground(Colors.black87), l10n!, selected: selectedElementId, selectedIds: selectedElementIds);
      }
    }
    if (layer != ArchitectPaintLayer.model) {
      ArchitectGridAxisPainterHelper.drawNeighborDistances(
        canvas: canvas,
        project: _project,
        selectedAxisId: selectedAxisId,
        zoomScale: zoomScale,
        palette: palette,
        visibleRect: viewport?.visibleRect,
      );
      if (activeTool == ArchitectTool.hatch && slabDraftPoints.length >= 2 &&
          (slabCandidatePoint != null || slabDraftPoints.length >= 3)) {
        final points = [...slabDraftPoints, ?slabCandidatePoint];
        final bounds = ArchitectSceneGeometry.boundsOf(points);
        ArchitectElementsPainterHelper.drawCadPrimitives(canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', cadPrimitives: [
            ArchitectCadPrimitive(id: 'hatch-preview', type: CadPrimitiveType.hatch,
              startPoint: bounds.topLeft, endPoint: bounds.bottomRight,
              polygon: points, hatchPattern: activeHatchPattern, colorValue: activeHatchColorValue),
          ]), zoomScale: zoomScale, dimensionScale: _project.dimensionScale);
      }
      if (activeTool == ArchitectTool.mask && slabDraftPoints.length >= 2 &&
          (slabCandidatePoint != null || slabDraftPoints.length >= 3)) {
        final points = [...slabDraftPoints, ?slabCandidatePoint];
        final bounds = ArchitectSceneGeometry.boundsOf(points);
        ArchitectElementsPainterHelper.drawCadPrimitives(canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', cadPrimitives: [
            ArchitectCadPrimitive(id: 'mask-preview', type: CadPrimitiveType.mask,
              startPoint: bounds.topLeft, endPoint: bounds.bottomRight,
              polygon: points, maskBorder: true),
          ]), zoomScale: zoomScale, dimensionScale: _project.dimensionScale);
      }
      if (activeTool == ArchitectTool.spline && slabDraftPoints.isNotEmpty && slabCandidatePoint != null) {
        final isNearStart = slabDraftPoints.length >= 3 &&
            (slabCandidatePoint! - slabDraftPoints.first).distance <= (18.0 / zoomScale).clamp(0.05, 0.35);
        final points = isNearStart ? slabDraftPoints : [...slabDraftPoints, slabCandidatePoint!];
        final bounds = ArchitectSceneGeometry.boundsOf(points);
        ArchitectElementsPainterHelper.drawCadPrimitives(canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', cadPrimitives: [
            ArchitectCadPrimitive(id: 'spline-preview', type: CadPrimitiveType.spline,
              startPoint: bounds.topLeft, endPoint: bounds.bottomRight,
              polygon: points, closed: isNearStart, colorValue: 0xFF00E5FF, lineStyle: ArchitectLineStyle.dashed),
          ]), zoomScale: zoomScale, dimensionScale: _project.dimensionScale);
      }
      ArchitectElementsPainterHelper.drawSlabDrafting(
        canvas: canvas,
        points: slabDraftPoints,
        candidatePoint: slabCandidatePoint,
        zoomScale: zoomScale,
      );
      if (roofTool != null) {
        ArchitectRoofPainterHelper.paintDraftRoof(
          canvas: canvas,
          roofTool: roofTool!,
          scale: zoomScale,
          units: _project.units,
          decimals: _project.distanceDecimals,
        );
      }
      _drawZoneDrafting(canvas);
      _drawZoneExtrudePreview(canvas);
      ArchitectZonePainterHelper.drawMagneticGuides(
        canvas: canvas,
        guides: magneticGuides,
        zoomScale: zoomScale,
      );
      for (final midpoint in midpointHints) {
        final r = 5 / zoomScale;
        final mark = Path()
          ..moveTo(midpoint.dx, midpoint.dy - r)
          ..lineTo(midpoint.dx + r, midpoint.dy + r)
          ..lineTo(midpoint.dx - r, midpoint.dy + r)
          ..close();
        canvas.drawPath(mark, Paint()..color = palette.background);
        canvas.drawPath(
          mark,
          Paint()
            ..color = palette.foreground(const Color(0xFF00796B))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / zoomScale,
        );
      }
      // This marker must remain above general cursor and selection graphics.
      _drawNewPointPreview(canvas);
      if (dragController != null) {
        ArchitectDragPainterHelper.drawDragInteraction(
          canvas: canvas,
          dragController: dragController!,
          zoomScale: zoomScale,
          palette: palette,
          localizeSnap: localizeSnap,
        );
      }
    }
    canvas.restore();
  }

  ArchitectStorey get _elementLayerStorey =>
      _filterElements(project.activeStorey, selectedOnly: false);

// === SECTION: [SEC-04-CORE] CORE OPERATIONS & HELPERS ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_CORE_LOGIC] Core Operations & Helpers: `_filterElements` (1 methods) ---
  ArchitectStorey _filterElements(
    ArchitectStorey storey, {
    required bool selectedOnly,
  }) {
    bool isVisible(String id, String defaultLayerId) =>
        project.isElementVisible(id, defaultLayerId);

    bool keep(String id, String defaultLayerId) {
      if (!isVisible(id, defaultLayerId)) return false;
      if (selectedOnly) return id == selectedElementId;
      if (layer == ArchitectPaintLayer.model && selectedElementId != null) {
        return id != selectedElementId;
      }
      return true;
    }

    final doorsVisible = project.isLayerVisible(ArchitectLayer.doorLayerId);
    final windowsVisible = project.isLayerVisible(ArchitectLayer.windowLayerId);

    return storey.copyWith(
      walls: storey.walls
          .where((e) => keep(e.id, ArchitectLayer.wallLayerId))
          .map((w) {
            if (!doorsVisible || !windowsVisible) {
              return w.copyWith(
                doors: doorsVisible ? w.doors : const [],
                windows: windowsVisible ? w.windows : const [],
              );
          }
            return w;
        })
          .toList(),
      columns: storey.columns
          .where((e) => keep(e.id, ArchitectLayer.columnLayerId))
          .toList(),
      beams: storey.beams
          .where((e) => keep(e.id, ArchitectLayer.beamLayerId))
          .toList(),
      slabs: storey.slabs
          .where((e) => keep(e.id, ArchitectLayer.slabLayerId))
          .toList(),
      roofs: storey.roofs
          .where((e) => keep(e.id, ArchitectLayer.roofLayerId))
          .toList(),
      openings: storey.openings
          .where((e) => keep(e.id, ArchitectLayer.slabLayerId))
          .toList(),
      stairs: storey.stairs
          .where((e) => keep(e.id, ArchitectLayer.stairLayerId))
          .toList(),
      dimensions: storey.dimensions
          .where((e) => keep(e.id, ArchitectLayer.dimensionLayerId))
          .toList(),
      annotations: storey.annotations
          .where((e) => keep(e.id, ArchitectLayer.textLayerId))
          .toList(),
      elevationMarkers: storey.elevationMarkers
          .where((e) => keep(e.id, ArchitectLayer.textLayerId))
          .toList(),
      cadPrimitives: storey.cadPrimitives
          .where((e) {
            final defLayer = e.type == CadPrimitiveType.hatch
                ? ArchitectLayer.hatchLayerId
                : ArchitectLayer.cadLayerId;
            if (!isVisible(e.id, defLayer)) return false;
            if (selectedOnly) return e.id == selectedElementId;
            if (layer == ArchitectPaintLayer.model && selectedElementId != null) {
              return e.id != selectedElementId || e.type == CadPrimitiveType.hatch;
          }
            return true;
        })
          .toList(),
      floorDrains: storey.floorDrains
          .where((e) => keep(e.id, ArchitectLayer.drainageLayerId))
          .toList(),
      decorativeElements: storey.decorativeElements
          .where((e) => keep(e.id, ArchitectLayer.wallLayerId))
          .toList(),
      components: storey.components
          .where((e) => keep(e.id, ArchitectLayer.furnitureLayerId))
          .toList(),
      zones: selectedOnly
          ? []
          : storey.zones
              .where((e) => isVisible(e.id, ArchitectLayer.zoneLayerId))
              .toList(),
    );
  }

// === SECTION: [SEC-05-PAINT] CANVAS PAINTING & GEOMETRY RENDERING ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_DRAW_SELECTED] Canvas Painting & Geometry Rendering: `_drawSelectedElement`, `_d ---
  void _drawSelectedElement(Canvas canvas) {
    if (newPointCandidate != null) return;
    if (selectedElementId == null) return;
    final walls = project.activeStorey.walls.where(
      (w) => w.id == selectedElementId,
    );
    if (walls.isNotEmpty) {
      final wall = walls.first;
      canvas.drawLine(
        wall.startPoint,
        wall.endPoint,
        Paint()
          ..color = Colors.cyan
          ..strokeWidth = 2 / zoomScale,
      );
      if (newPointCandidate == null) _drawSelectedWallHandles(canvas, wall);
      return;
    }
    final selected = _filterElements(project.activeStorey, selectedOnly: true);
    if (selected.floorDrains.isNotEmpty) {
      ArchitectFloorDrainPainterHelper.draw(
        canvas: canvas,
        storey: selected,
        walls: _project.activeStorey.walls,
        zoomScale: zoomScale,
        palette: palette,
        selectedIds: {selectedElementId!},
      );
      for (final drain in selected.floorDrains) {
        ArchitectFloorDrainPainterHelper.drawHandles(
          canvas: canvas,
          drain: drain,
          zoomScale: zoomScale,
          handleOffsetLength: handleOffsetLength,
        );
      }
      return;
    }
    if (selected.slabs.isNotEmpty) {
      ArchitectElementsPainterHelper.drawSlabs(
        palette: palette,
        canvas: canvas,
        storey: selected,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      return;
    }
    if (selected.roofs.isNotEmpty) {
      ArchitectRoofPainterHelper.paintRoofs(
        canvas: canvas,
        storey: selected,
        project: _project,
        scale: zoomScale,
        selectedIds: {selectedElementId!},
      );
      return;
    }
    if (selected.decorativeElements.isNotEmpty) {
      _drawDecorativeElements(canvas, selected);
      return;
    }
    final polyline = selected.cadPrimitives
        .where((p) => p.type == CadPrimitiveType.polyline || p.type == CadPrimitiveType.spline).firstOrNull;
    if (polyline != null && (!polyline.isClosedPolyline || polyline.type == CadPrimitiveType.spline)) {
      ArchitectElementsPainterHelper.drawCadPrimitives(
        dimensionScale: _project.dimensionScale,
        palette: palette,
        canvas: canvas,
        storey: selected,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      if (marqueePoints.isEmpty) {
        final points = polyline.type == CadPrimitiveType.spline ? (polyline.polygon ?? polyline.linePoints) : polyline.linePoints;
        final scale = math.max(zoomScale, 80.0);
        const color = Color(0xFF00BCD4);
        if (polyline.type != CadPrimitiveType.spline) {
        for(var i=0;i+1<points.length;i++) {
          final mid=(points[i]+points[i+1])/2;
          canvas.drawCircle(mid,3.5/scale,Paint()..color=const Color(0xFFFF9800));
          if(handleOffsetLength>0) {
            final grip=ArchitectPolylineEditing.edgeHandle(points,i,zoomScale,handleOffsetLength);
            canvas.drawLine(mid,grip,Paint()..color=const Color(0xFFFF9800)..strokeWidth=1/scale);
            _drawTouchGrip(canvas,grip,scale,const Color(0xFFFF9800));
        }
        }
        }
        for (var i = 0; i < points.length; i++) {
          canvas.drawCircle(points[i], 3.5 / scale, Paint()..color = color);
          if (handleOffsetLength <= 0) continue;
          final handle = ArchitectPolylineEditing.handle(
              points, i, zoomScale, handleOffsetLength);
          canvas.drawLine(points[i], handle, Paint()
            ..color = const Color(0xFF00E5FF)
            ..strokeWidth = 1.6 / scale);
          _drawTouchGrip(canvas, handle, scale, color);
        }
      }
      return;
    }
    final selectedLine = selected.cadPrimitives
        .where((p) => p.type == CadPrimitiveType.line)
        .firstOrNull;
    if (selectedLine != null) {
      ArchitectElementsPainterHelper.drawCadPrimitives(
        dimensionScale: _project.dimensionScale,
        palette: palette,
        canvas: canvas,
        storey: selected,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      _drawSelectedWallHandles(
        canvas,
        ArchitectWall(
          id: selectedLine.id,
          startPoint: selectedLine.startPoint,
          endPoint: selectedLine.endPoint,
          thickness: .001,
        ),
      );
      return;
    }
    if (selected.cadPrimitives.any((p) => p.isPolygon)) {
      ArchitectElementsPainterHelper.drawCadPrimitives(
        hatchSelectionOnly: true,
        dimensionScale: _project.dimensionScale,
        palette: palette,
        canvas: canvas,
        storey: selected,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      return;
    }
    Architect2dPainter(
      palette: palette,
      project: project.updateActiveStorey(selected).copyWithGridAxes([]),
      dimensionWallObstacles: ArchitectWallNetwork.body(
        _project.activeStorey.walls,
      ),
      activeTool: ArchitectTool.select,
      showServiceProjections: false,
      paintGrid: false,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    ).paint(canvas, Size.zero);
  }

  void _drawDecorativeElements(Canvas canvas, ArchitectStorey storey) {
    final draftingScale = math.max(zoomScale, 40.0);
    for (final decor in storey.decorativeElements) {
      final isSelected =
          decor.id == selectedElementId ||
          selectedElementIds.contains(decor.id);
      if (!decor.showOnPlan &&
          !_project.showDecorativeOnPlan &&
          !activeTool.isDecorativeTool &&
          !isSelected) {
        continue;
      }
      final footprint = ArchitectDecorativeGeometry.planFootprintPath(decor);
      final fillColor = isSelected
          ? const Color(0x2400BCD4)
          : const Color(0x0D607D8B);
      canvas.drawPath(footprint, Paint()..color = fillColor);
      final strokePaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00BCD4)
            : palette.foreground(const Color(0xFF546E7A))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 1.8 : 1.0) / draftingScale;
      for (final metric in footprint.computeMetrics()) {
        double d = 0.0;
        final dash = 6.0 / draftingScale;
        final gap = 4.0 / draftingScale;
        while (d < metric.length) {
          final next = math.min(d + dash, metric.length);
          canvas.drawPath(metric.extractPath(d, next), strokePaint);
          d = next + gap;
        }
      }
    }
  }

// === SECTION: [SEC-06-WALLS] WALL DRAFTING, SPLITTING & JOINTS ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_WALL_OPS] Wall Drafting, Splitting & Joints: `_drawPolygonEditing`, `_drawN ---
  void _drawSelectedWallHandles(Canvas canvas, ArchitectWall wall) {
    if(marqueePoints.isNotEmpty) return;
    final draftingScale = math.max(zoomScale, 80.0);
    const vertexColor = Color(0xFF00BCD4);

    // Direct endpoint dots
    for (final point in [wall.startPoint, wall.endPoint]) {
      canvas.drawCircle(point, 3.5 / draftingScale, Paint()..color = vertexColor);
    }

    if (handleOffsetLength > 0) {
      final uStart = wall.tangentAt(0);
      final uEnd = wall.tangentAt(1);
      final clearance = handleOffsetLength / zoomScale;
      final startHandle = wall.startPoint - uStart * clearance;
      final endHandle = wall.endPoint + uEnd * clearance;

      final bgLeaderPaint = Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 2.6 / draftingScale
        ..style = PaintingStyle.stroke;
      final leaderPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 1.6 / draftingScale
        ..style = PaintingStyle.stroke;

      // Start handle leader & touch grip
      canvas.drawLine(wall.startPoint, startHandle, bgLeaderPaint);
      canvas.drawLine(wall.startPoint, startHandle, leaderPaint);
      _drawTouchGrip(canvas, startHandle, draftingScale, vertexColor);

      // End handle leader & touch grip
      canvas.drawLine(wall.endPoint, endHandle, bgLeaderPaint);
      canvas.drawLine(wall.endPoint, endHandle, leaderPaint);
      _drawTouchGrip(canvas, endHandle, draftingScale, vertexColor);
    }
  }

  void _drawTouchGrip(
    Canvas canvas,
    Offset handle,
    double draftingScale,
    Color color,
  ) {
    canvas.drawCircle(
      handle,
      5.5 / draftingScale,
      Paint()..color = const Color(0xFF1E1E26),
    );
    canvas.drawCircle(
      handle,
      5.5 / draftingScale,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / draftingScale,
    );
    canvas.drawCircle(handle, 2.5 / draftingScale, Paint()..color = color);
  }

  void _drawWallEndpointLeaderLine(Canvas canvas) {
    if (wallEndpointLeaderLine == null) return;
    final draftingScale = math.max(zoomScale, 80.0);
    final (from, to) = wallEndpointLeaderLine!;
    final leaderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / draftingScale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, leaderPaint);
    canvas.drawCircle(
      from,
      3.5 / draftingScale,
      Paint()..color = const Color(0xFF00E5FF),
    );
    canvas.drawCircle(
      to,
      8.0 / draftingScale,
      Paint()..color = const Color(0x3300E5FF),
    );
    canvas.drawCircle(
      to,
      5.5 / draftingScale,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 / draftingScale,
    );
    canvas.drawCircle(
      to,
      3.0 / draftingScale,
      Paint()..color = const Color(0xFF00E5FF),
    );
  }

  void _drawNewPointPreview(Canvas canvas) {
    if (newPointCandidate == null) return;
    final draftingScale = zoomScale;
    final candidateColor = newPointValid
        ? const Color(0xFF006E91) : const Color(0xFFB3261E);

    if (newPointLeaderLine != null) {
      final from = newPointCandidate!;
      final to = newPointHandleOffset == null ? newPointLeaderLine!.$2
          : from + newPointHandleOffset! / zoomScale;
      final bgLeaderPaint = Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = 2.6 / draftingScale
        ..style = PaintingStyle.stroke;
      final leaderPaint = Paint()
        ..color = candidateColor
        ..strokeWidth = 1.6 / draftingScale
        ..style = PaintingStyle.stroke;

      canvas.drawLine(from, to, bgLeaderPaint);
      canvas.drawLine(from, to, leaderPaint);
      _drawTouchGrip(canvas, to, draftingScale, candidateColor);
    }

    // A white knockout and crosshair remain legible on either canvas palette.
    canvas.drawCircle(
      newPointCandidate!,
      8.0 / draftingScale,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      newPointCandidate!,
      7.0 / draftingScale,
      Paint()..color = candidateColor..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / draftingScale,
    );
    final center = newPointCandidate!;
    final line = Paint()..color = candidateColor..strokeWidth = 1.5 / draftingScale;
    final radius = (newPointValid ? 11.0 : 4.0) / draftingScale;
    if (newPointValid) {
      canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), line);
      canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), line);
      canvas.drawCircle(center, 2.0 / draftingScale, Paint()..color = candidateColor);
    } else {
      canvas.drawLine(center - Offset(radius, radius), center + Offset(radius, radius), line);
      canvas.drawLine(center - Offset(radius, -radius), center + Offset(radius, -radius), line);
    }
  }

  void _drawPolygonEditing(Canvas canvas) {
    final targetId = selectedElementId ?? selectedZoneId;
    if (targetId == null) return;
    List<Offset>? polygon;
    List<List<Offset>> holes = const [];
    for (final p in _project.activeStorey.cadPrimitives) {
      if (p.id == targetId && p.isPolygon) {
        polygon = p.polygonCorners;
        holes = p.holes;
      }
    }
    for (final slab in _project.activeStorey.slabs) {
      if (slab.id == targetId) { polygon = slab.polygon; holes = slab.holes; }
    }
    for (final roof in _project.activeStorey.roofs) {
      if (roof.id == targetId) { polygon = roof.points; holes = roof.holes; }
    }
    for (final zone in _project.activeStorey.zones) {
      if (zone.id == targetId && !zone.isAutoBoundary) polygon = zone.polygon;
    }
    for (final opening in _project.activeStorey.openings) {
      if (opening.id == targetId) polygon = opening.boundary;
    }
    for (final drain in _project.activeStorey.floorDrains) {
      if (drain.id == targetId) { polygon = drain.polygon; holes = drain.holes; }
    }
    if (polygon == null) return;
    ArchitectPolygonPainter.draw(
      canvas: canvas,
      polygon: polygon,
      scale: zoomScale,
      unit: _project.units,
      decimals: _project.distanceDecimals,
      handles: true,
      invalid: polygonEditInvalid && polygonEditHoleIndex == null,
      leaderLine: polygonEditHoleIndex == null ? polygonLeaderLine : null,
      offsetLengthPx: handleOffsetLength,
      obstacles:
          dimensionWallObstacles ??
          ArchitectWallNetwork.body(_project.activeStorey.walls),
    );
    for (var i = 0; i < holes.length; i++) {
      ArchitectPolygonPainter.draw(
        canvas: canvas, polygon: holes[i], scale: zoomScale,
        unit: _project.units, decimals: _project.distanceDecimals,
        handles: true,
        invalid: polygonEditInvalid && polygonEditHoleIndex == i,
        leaderLine: polygonEditHoleIndex == i ? polygonLeaderLine : null,
        offsetLengthPx: handleOffsetLength,
        obstacles: dimensionWallObstacles ?? ArchitectWallNetwork.body(_project.activeStorey.walls),
      );
    }
  }

  void _drawZones(Canvas canvas) {
    ArchitectZonePainterHelper.drawZones(
      palette: palette,
      canvas: canvas,
      project: _zoneLayerProject,
      zoomScale: zoomScale,
      selectedZoneId: selectedZoneId,
      draggingVertexIndex: draggingVertexIndex,
      draggingVertexPoint: draggingVertexPoint,
      mergeCandidateIndex: mergeCandidateIndex,
      extrudePreviewPolygon: zoneExtrudePreviewPolygon,
      isExtrudeSelfIntersecting: isZoneExtrudeSelfIntersecting,
      editingPolygon: zoneEditingPolygon,
    );
  }

// === SECTION: [SEC-07-GRIDS] GRID AXES, ALIGNMENT & SNAPPING ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_GRID_AXES] Grid Axes, Alignment & Snapping: `_drawDraftingGrid`, `_drawGridA ---
  void _drawZoneSchedule(Canvas canvas) {
    if (!_project.isLayerVisible(ArchitectLayer.zoneLayerId)) return;
    final isDraggingOrGhostingTable =
        zoneTableDragPreviewOrigin != null ||
        (activeTool == ArchitectTool.zoneTable && cursorPosition != null);

    final shouldDrawTableInThisLayer =
        layer == ArchitectPaintLayer.all ||
        (layer == ArchitectPaintLayer.interaction &&
            (isDraggingOrGhostingTable || isZoneTableSelected)) ||
        (layer == ArchitectPaintLayer.model &&
            !isDraggingOrGhostingTable &&
            !isZoneTableSelected);

    if (!shouldDrawTableInThisLayer) return;

    ArchitectZonePainterHelper.drawZoneSchedule(
      palette: palette,
      canvas: canvas,
      storey: _project.activeStorey,
      zoomScale: zoomScale,
      isTableSelected: isZoneTableSelected,
      selectedTableId: selectedZoneTableId,
      tableDragPreviewOrigin: zoneTableDragPreviewOrigin,
      tableGhostOrigin:
          activeTool == ArchitectTool.zoneTable ? cursorPosition : null,
      l10n: l10n,
    );
  }

  ArchitectProject get _zoneLayerProject {
    if (layer == ArchitectPaintLayer.all) return project;
    final zones = project.activeStorey.zones
        .where(
          (z) => layer == ArchitectPaintLayer.interaction
              ? z.id == selectedZoneId
              : z.id != selectedZoneId,
        )
        .toList();
    return project.updateActiveStorey(
      project.activeStorey.copyWith(zones: zones),
    );
  }

  void _drawZoneDrafting(Canvas canvas) {
    if (activeTool == ArchitectTool.zone && zoneDraftingPoints.isNotEmpty) {
      ArchitectElementsPainterHelper.drawSlabDrafting(
        canvas: canvas,
        points: zoneDraftingPoints,
        candidatePoint: zoneDraftingCandidate,
        zoomScale: zoomScale,
      );
    }
  }

  void _drawZoneExtrudePreview(Canvas canvas) {
    if (zoneExtrudeV1 != null &&
        zoneExtrudeV2 != null &&
        zoneExtrudeNormal != null &&
        zoneExtrudeDistance != null) {
      ArchitectZonePainterHelper.drawEdgeExtrudePreview(
        canvas: canvas,
        v1: zoneExtrudeV1!,
        v2: zoneExtrudeV2!,
        normal: zoneExtrudeNormal!,
        distance: zoneExtrudeDistance!,
        zoomScale: zoomScale,
        isSelfIntersecting: isZoneExtrudeSelfIntersecting,
      );
    }
  }

  // ===========================================================================
  // 1. DRAFTING GRID
  // ===========================================================================

  void _drawDraftingGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.grid.withValues(alpha: palette.isDark ? 0.08 : 0.09)
      ..strokeWidth = 0.6 / zoomScale;

    final majorGridPaint = Paint()
      ..color = palette.grid.withValues(alpha: palette.isDark ? 0.18 : 0.18)
      ..strokeWidth = 1.2 / zoomScale;

    final view = viewport?.visibleRect ?? const Rect.fromLTRB(-40, -40, 40, 40);
    final exponent = (math.log(24 / zoomScale) / math.ln10).floor();
    final base = math.pow(10, exponent).toDouble();
    final step = [
      base,
      base * 2,
      base * 5,
      base * 10,
    ].firstWhere((s) => s * zoomScale >= 24);
    for (
      var x = (view.left / step).floor();
      x <= (view.right / step).ceil();
      x++
    ) {
      canvas.drawLine(
        Offset(x * step, view.top),
        Offset(x * step, view.bottom),
        x % 5 == 0 ? majorGridPaint : gridPaint,
      );
    }
    for (
      var y = (view.top / step).floor();
      y <= (view.bottom / step).ceil();
      y++
    ) {
      canvas.drawLine(
        Offset(view.left, y * step),
        Offset(view.right, y * step),
        y % 5 == 0 ? majorGridPaint : gridPaint,
      );
    }
  }

  // ===========================================================================
  // 2. STRUCTURAL GRID AXES
  // ===========================================================================

  void _drawGridAxes(Canvas canvas) {
    if (!project.isLayerVisible(ArchitectLayer.gridLayerId)) return;
    ArchitectGridAxisPainterHelper.drawAxes(
      palette: palette,
      canvas: canvas,
      project: layer == ArchitectPaintLayer.all
          ? project
          : project.copyWithGridAxes(
              project.gridAxes
                  .where(
                    (a) => layer == ArchitectPaintLayer.interaction
                        ? a.id == selectedAxisId
                        : a.id != selectedAxisId,
                  )
                  .toList(),
            ),
      zoomScale: zoomScale,
      selectedAxisId: selectedAxisId,
      draggedAxisSnapshot: draggedAxisSnapshot,
      isDraggingHandle: isDraggingAxisHandle,
      isMovingAxis: isMovingAxis,
      moveOriginalAxis: moveOriginalAxis,
      moveCurrentDelta: moveCurrentDelta,
      offsetPreview: layer == ArchitectPaintLayer.model
          ? null
          : axisOffsetPreview,
      draftStart: layer == ArchitectPaintLayer.model ? null : axisDraftStart,
      draftEnd: layer == ArchitectPaintLayer.model ? null : axisDraftEnd,
      draftSnapLabel: layer == ArchitectPaintLayer.model
          ? null
          : axisDraftSnapLabel,
    );
  }

  // ===========================================================================
  // 3. WALLS & DOORS
  // ===========================================================================

// === SECTION: [SEC-08-WALLS] WALL DRAFTING, SPLITTING & JOINTS ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_DRAW_WALLS] Wall Drafting, Splitting & Joints: `_drawWalls`, `_drawWallLayers ---
  void _drawWalls(Canvas canvas) {
    final activeStorey = project.activeStorey;

    architectDrawingSources(canvas, activeStorey.walls.map((w) => w.id), 'wall');
    final wallBorderPaint = Paint()
      ..color = palette.foreground(const Color(0xFF212121))
      ..strokeWidth = ArchitectLineWeights.cutHeavy / zoomScale
      ..style = PaintingStyle.stroke;

    final layers = publicationWallLayers ?? ArchitectWallLayers.forProject(_project);
    _drawWallLayers(canvas, layers, wallBorderPaint);
    final midDotPaint = Paint()
      ..color = const Color(0x99B0BEC5)
      ..style = PaintingStyle.fill;
    final midBorderPaint = Paint()
      ..color = palette.foreground(const Color(0x66000000))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / draftingScale;

    for (final wall in activeStorey.walls) {
      if (wall.railing != null) {
        final railingPaint = Paint()
          ..color = palette.foreground(const Color(0xff424242))
          ..strokeWidth = ArchitectLineWeights.cutThin / zoomScale
          ..style = PaintingStyle.stroke;
        for (final path in ArchitectRailingGeometry.planPaths(wall, walls: activeStorey.walls)) {
          canvas.drawPath(path, railingPaint);
        }
      }
      final isSelected =
          newPointCandidate == null &&
          (wall.id == selectedElementId || selectedElementIds.contains(wall.id));
      final borderPaint = isSelected
          ? (Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 2.5 / zoomScale
              ..style = PaintingStyle.stroke)
          : wallBorderPaint;

      if (isSelected) {
        canvas.drawPath(
          wall.system.isSpecial
              ? layers.coreRegions[wall.id] ??
                    ArchitectWallNetwork.polygon(wall.polygonCorners)
              : ArchitectWallNetwork.polygon(wall.polygonCorners),
          borderPaint,
        );
        for (final point in [wall.startPoint, wall.endPoint]) {
          canvas.drawCircle(
            point,
            6.0 / draftingScale,
            Paint()..color = Colors.black45,
          );
          canvas.drawCircle(
            point,
            4.5 / draftingScale,
            Paint()
              ..color = const Color(0xFF00E5FF)
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            point,
            4.5 / draftingScale,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1.6 / draftingScale
              ..style = PaintingStyle.stroke,
          );
          canvas.drawCircle(
            point,
            1.6 / draftingScale,
            Paint()..color = Colors.white,
          );
        }
      }

      // Unobtrusive midpoint edit handle for extrusion/step move
      final midPoint = wall.referencePointAt(.5);
      canvas.drawCircle(midPoint, 3.2 / draftingScale, midDotPaint);
      canvas.drawCircle(midPoint, 3.2 / draftingScale, midBorderPaint);

      for (final door in wall.doors) {
        door.paint2D(
          cutPlaneHeight: project.activeStorey.cutPlaneHeight,
          palette: palette,
          canvas: canvas,
          wallGeometryProvided:wall.isCurved || wall.system.isSpecial,
          wallStart: wall.openingAxis(door.offsetRatio).$1,
          wallEnd: wall.openingAxis(door.offsetRatio).$2,
          wallThickness: wall.thickness,
          coreThickness: wall.coreThickness,
          coreCenterShift: -wall.exteriorSign*wall.coreAsymmetry/2,
          insulationThickness: wall.insulationThickness,
          exteriorSign: wall.exteriorSign.toDouble(),
          zoomScale: zoomScale,
          isSelected: door.id == selectedElementId,
        );
      }
      for (final window in wall.windows) {
        window.paint2D(
          cutPlaneHeight: project.activeStorey.cutPlaneHeight,
          palette: palette,
          canvas: canvas,
          wallGeometryProvided:wall.isCurved || wall.system.isSpecial,
          wallStart: wall.openingAxis(window.offsetRatio).$1,
          wallEnd: wall.openingAxis(window.offsetRatio).$2,
          wallThickness: wall.thickness,
          coreThickness: wall.coreThickness,
          coreCenterShift: -wall.exteriorSign*wall.coreAsymmetry/2,
          insulationThickness: wall.insulationThickness,
          exteriorSign: wall.exteriorSign.toDouble(),
          zoomScale: zoomScale,
          isSelected: window.id == selectedElementId,
        );
      }
    }
  }

  void _drawWallLayers(
    Canvas canvas,
    ArchitectWallLayers layers,
    Paint border, {
    Color hatchColor = const Color(0xFF9EA5AC),
  }) {
    // Thin outer insulation outline for cut walls (0.8 px)
    canvas.drawPath(
      layers.body,
      Paint()
        ..color = border.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ArchitectLineWeights.cutThin / zoomScale,
    );
    for (final wall in layers.walls) {
      final region = layers.coreRegions[wall.id];
      if (region != null && wall.layers.isEmpty && !wall.plinth.enabled) {
        ArchitectWallHatch.paint(canvas, wall, region, zoomScale, hatchColor);
      }
    }
    for(final material in layers.materials.where((r)=>r.wall.layers.isNotEmpty||r.wall.plinth.enabled)) {
      final region=material.path;
      if(material.layer.role==ArchitectLayerRole.core) {
        ArchitectWallHatch.paint(canvas,material.wall,region,zoomScale,hatchColor,material:WallCoreMaterial.values.where((m)=>m.name==material.layer.material.name).firstOrNull);
      }
    }
    for(final contour in layers.materialContours.values) {
      canvas.drawPath(contour,Paint()..color=border.color..style=PaintingStyle.stroke..strokeWidth=ArchitectLineWeights.cutThin/zoomScale);
    }
    // Thick boundary encloses only the cut core (2.2 px)
    canvas.drawPath(layers.core, border);

    // Medium/thin line for uncut / projection walls (parapets, etc.) (1.2 px)
    if (layers.uncutBody.computeMetrics().isNotEmpty) {
      canvas.drawPath(
        layers.uncutBody,
        Paint()
          ..color = border.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = ArchitectLineWeights.projection / zoomScale,
      );
    }
  }

  // ===========================================================================
  // 4. ACTIVE DRAFTING INTERACTION
  // ===========================================================================

// === SECTION: [SEC-09-PAINT] CANVAS PAINTING & GEOMETRY RENDERING ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_DRAW_ACTIVE] Canvas Painting & Geometry Rendering: `_drawActiveDrafting`, `_dr ---
  void _drawActiveDrafting(Canvas canvas) {
    // Wall dimensions and their editable labels share one screen-space layout.
    // The workspace interaction overlay paints both witnesses and dimensions.
    if (doorPreview != null) {
      final hostWall = _project.activeStorey.walls
          .where((w) => w.id == doorPreview!.wallId)
          .firstOrNull;
      if (hostWall != null) {
        doorPreview!.paint2D(
          cutPlaneHeight: project.activeStorey.cutPlaneHeight,
          palette: palette,
          canvas: canvas,
          wallStart: hostWall.openingAxis(doorPreview!.offsetRatio).$1,
          wallEnd: hostWall.openingAxis(doorPreview!.offsetRatio).$2,
          wallThickness: hostWall.thickness,
          coreThickness: hostWall.coreThickness,
          coreCenterShift: -hostWall.exteriorSign*hostWall.coreAsymmetry/2,
          insulationThickness: hostWall.insulationThickness,
          exteriorSign: hostWall.exteriorSign.toDouble(),
          zoomScale: zoomScale,
          isSelected: true,
        );
      }
    }
    if (windowPreview != null) {
      final hostWall = _project.activeStorey.walls
          .where((w) => w.id == windowPreview!.wallId)
          .firstOrNull;
      if (hostWall != null) {
        windowPreview!.paint2D(
          cutPlaneHeight: project.activeStorey.cutPlaneHeight,
          palette: palette,
          canvas: canvas,
          wallStart: hostWall.openingAxis(windowPreview!.offsetRatio).$1,
          wallEnd: hostWall.openingAxis(windowPreview!.offsetRatio).$2,
          wallThickness: hostWall.thickness,
          coreThickness: hostWall.coreThickness,
          coreCenterShift: -hostWall.exteriorSign*hostWall.coreAsymmetry/2,
          insulationThickness: hostWall.insulationThickness,
          exteriorSign: hostWall.exteriorSign.toDouble(),
          zoomScale: zoomScale,
          isSelected: true,
        );
      }
    }

    for (final gap in openingClearances) {
      final hostWall = _project.activeStorey.walls
          .where((w) => w.id == gap.wallId)
          .firstOrNull;
      if (hostWall == null) continue;
      final lineColor = palette.foreground(const Color(0xFF424A52));
      final witnessPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.55)
        ..strokeWidth = 0.85 / draftingScale;
      canvas.drawLine(gap.referencePoint, gap.start, witnessPaint);
      canvas.drawLine(gap.jambPoint, gap.end, witnessPaint);

      final direction = gap.end - gap.start;
      final tick =
          (direction.distance < 1e-8
              ? hostWall.normalVector
              : Offset(-direction.dy, direction.dx) / direction.distance) *
          .04;
      final dimPaint = Paint()
        ..color = lineColor
        ..strokeWidth = (gap.isModularSnap ? 1.5 : 1.1) / draftingScale;
      canvas.drawLine(gap.start, gap.end, dimPaint);
      for (final point in [gap.start, gap.end]) {
        canvas.drawLine(point - tick, point + tick, dimPaint);
      }
      if (showOpeningClearanceBadges && gap.distance >= 0.01) {
        final tp = ArchitectTextPainter(
          text: TextSpan(
            text: _project.formatLength(gap.distance),
            style: TextStyle(
              color: const Color(0xFF20252A),
              fontFamily: 'Roboto',
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(gap.midpoint.dx, gap.midpoint.dy);
        canvas.scale(1.0 / ArchitectClearanceBadgeLayout.openingReferenceScale);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 12,
          height: tp.height + 6,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = Colors.white,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFF78818A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
    if (activeOvershoot != null) {
      final stubStart = activeOvershoot!.intersectionPoint;
      final stubEnd = activeOvershoot!.stubPoint;
      _drawDashedLine(
        canvas,
        stubStart,
        stubEnd,
        Paint()
          ..color = Colors.amberAccent
          ..strokeWidth = 2.5 / draftingScale,
        draftingScale,
      );
      canvas.drawCircle(
        stubStart,
        4.0 / draftingScale,
        Paint()..color = Colors.amberAccent,
      );
      canvas.drawCircle(
        stubEnd,
        2.5 / draftingScale,
        Paint()..color = Colors.amberAccent,
      );
    }
    if (wallJoinLeaderLine != null) {
      final (from, to) = wallJoinLeaderLine!;
      final linePaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 2.0 / draftingScale
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, from, to, linePaint, draftingScale);
      canvas.drawCircle(
        from,
        4.0 / draftingScale,
        Paint()..color = const Color(0xFF00E5FF),
      );
      final handleRadius = 13.0 / draftingScale;
      canvas.drawCircle(
        to,
        handleRadius,
        Paint()..color = const Color(0x3300E5FF),
      );
      canvas.drawCircle(
        to,
        handleRadius,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 / draftingScale,
      );
      final plusPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0 / draftingScale
        ..strokeCap = StrokeCap.round;
      final arm = 5.5 / draftingScale;
      canvas.drawLine(
        Offset(to.dx - arm, to.dy),
        Offset(to.dx + arm, to.dy),
        plusPaint,
      );
      canvas.drawLine(
        Offset(to.dx, to.dy - arm),
        Offset(to.dx, to.dy + arm),
        plusPaint,
      );
    }
    if (wallTrimSpan != null) {
      final span = wallTrimSpan!;
      final preview = span.wall.copyWith(
        startPoint:
            span.wall.startPoint +
            span.wall.unitVector * (span.from * span.wall.length),
        endPoint:
            span.wall.startPoint +
            span.wall.unitVector * (span.to * span.wall.length),
      );
      canvas.drawPath(
        ArchitectWallNetwork.polygon(preview.polygonCorners),
        Paint()..color = Colors.redAccent.withValues(alpha: .25),
      );
      canvas.drawLine(
        span.start,
        span.end,
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 2 / draftingScale,
      );
      for (final point in [span.start, span.end]) {
        canvas.drawCircle(
          point,
          3 / draftingScale,
          Paint()..color = Colors.redAccent,
        );
      }
    }
    if (wallCutGuideLine != null) {
      _drawDashedLine(
        canvas,
        wallCutGuideLine!.$1,
        wallCutGuideLine!.$2,
        Paint()
          ..color = const Color(0xFFFF9100)
          ..strokeWidth = 1.8 / draftingScale,
        draftingScale,
      );
    }
    if (wallCutAnchor != null) {
      canvas.drawCircle(
        wallCutAnchor!,
        5 / draftingScale,
        Paint()
          ..color = const Color(0xFFFF9100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / draftingScale,
      );
      canvas.drawCircle(
        wallCutAnchor!,
        2.5 / draftingScale,
        Paint()..color = const Color(0xFFFF9100),
      );
    }
    if (wallCutLine != null) {
      _drawDashedLine(
        canvas,
        wallCutLine!.$1,
        wallCutLine!.$2,
        Paint()
          ..color = const Color(0xFFFF3D00)
          ..strokeWidth = 2.0 / draftingScale,
        draftingScale,
      );
      canvas.drawCircle(
        wallCutLine!.$1,
        4 / draftingScale,
        Paint()..color = const Color(0xFFFF3D00),
      );
      canvas.drawCircle(
        wallCutLine!.$2,
        3 / draftingScale,
        Paint()
          ..color = const Color(0xFFFF3D00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / draftingScale,
      );
    }
    if (mirrorAxisLine != null) {
      _drawDashedLine(
        canvas,
        mirrorAxisLine!.$1,
        mirrorAxisLine!.$2,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 1.8 / draftingScale,
        draftingScale,
      );
    }
    if (mirrorAnchor != null) {
      canvas.drawCircle(
        mirrorAnchor!,
        5.5 / draftingScale,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 / draftingScale,
      );
      canvas.drawCircle(
        mirrorAnchor!,
        2.5 / draftingScale,
        Paint()..color = const Color(0xFF00E5FF),
      );
    }
    if (splitPerpendicularGuide != null) {
      _drawDashedLine(
        canvas,
        splitPerpendicularGuide!.$1,
        splitPerpendicularGuide!.$2,
        Paint()
          ..color = const Color(0x9900E5FF)
          ..strokeWidth = 1.5 / draftingScale,
        draftingScale,
      );
    }
    if (splitCutLine != null) {
      _drawDashedLine(
        canvas,
        splitCutLine!.$1,
        splitCutLine!.$2,
        Paint()
          ..color = const Color(0xFFFF9100)
          ..strokeWidth = 2.0 / draftingScale,
        draftingScale,
      );
      canvas.drawCircle(
        splitCutLine!.$1,
        4.5 / draftingScale,
        Paint()..color = const Color(0xFFFF9100),
      );
      canvas.drawCircle(
        splitCutLine!.$2,
        4.5 / draftingScale,
        Paint()..color = const Color(0xFFFF9100),
      );
    } else if (splitPoint1 != null) {
      canvas.drawCircle(
        splitPoint1!,
        5.5 / draftingScale,
        Paint()
          ..color = const Color(0xFFFF9100)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 / draftingScale,
      );
      canvas.drawCircle(
        splitPoint1!,
        2.5 / draftingScale,
        Paint()..color = const Color(0xFFFF9100),
      );
    }
    if (newPointCandidate == null && cursorPosition != null &&
        (activeTool == ArchitectTool.wall ||
            activeTool == ArchitectTool.cadLine ||
            activeTool == ArchitectTool.select ||
            activeTool == ArchitectTool.dimension)) {
      // Exact aim point sits at the tip, ahead of the offset pointer/ruler.
      final aim = activeDraftEnd ?? cursorPosition!;
      canvas.drawCircle(
        aim,
        3.5 / draftingScale,
        Paint()..color = const Color(0xFF00E5FF),
      );
      canvas.drawCircle(
        aim,
        3.5 / draftingScale,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 / draftingScale,
      );
    }
    // --- CLEAR, NEAT PLACEMENT POINTS DURING DRAFTING ---
    if (activeDraftStart != null) {
      _drawDraftMarker(
        canvas,
        activeDraftStart!,
        draftingScale: draftingScale,
        isStart: true,
      );
    }

    if (slabDraftPoints.isNotEmpty) {
      _drawDraftMarker(
        canvas,
        slabDraftPoints.first,
        draftingScale: draftingScale,
        isStart: true,
      );
      for (int i = 1; i < slabDraftPoints.length; i++) {
        _drawDraftMarker(
          canvas,
          slabDraftPoints[i],
          draftingScale: draftingScale,
          isStart: false,
        );
      }
    }

    if (marqueePoints.isNotEmpty) {
      ArchitectSelectionPainter.marquee(canvas, marqueePolygon, marqueePoints, zoomScale, palette,
        contained:marqueeContained,candidate:marqueeCandidate);
    }
    if (newPointCandidate == null && activeTool == ArchitectTool.wall &&
        cursorPosition != null &&
        showWallCursor) {
      final target = activeDraftEnd ?? cursorPosition!;
      final paint = Paint()
        ..color = activeSnapLabel == null ? Colors.orange : Colors.cyan
        ..strokeWidth = 1.5 / draftingScale
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(target, 5 / draftingScale, paint);
    }
    if (activeTool.isLandscapeTool && landscapeTool != null) {
      final lt = landscapeTool!;
      ArchitectLandscapePainterHelper.drawActiveLandscapeDraft(
        canvas: canvas,
        draftPoints: lt.draftPoints,
        cursorWorld: activeDraftEnd ?? cursorPosition,
        zoomScale: zoomScale,
        accentColor: switch (activeTool) {
          ArchitectTool.terrain =>
            lt.terrainState == ArchitectTerrainState.proposed
                ? const Color(0xFF15803D)
                : const Color(0xFF92400E),
          ArchitectTool.pathway => const Color(0xFF0284C7),
          ArchitectTool.street => const Color(0xFF475569),
          ArchitectTool.vegetation => const Color(0xFF16A34A),
          ArchitectTool.siteFence => const Color(0xFFB45309),
          _ => const Color(0xFF2563EB),
        },
        previewWidth: switch (activeTool) {
          ArchitectTool.street => lt.streetRoadWidth,
          ArchitectTool.pathway => lt.pathwayWidth,
          ArchitectTool.siteFence => lt.fenceThickness,
          ArchitectTool.vegetation
              when lt.plantSpecies == ArchitectPlantSpecies.trimmedHedge =>
            lt.hedgeWidth,
          _ => 0.0,
        },
        showCurbs:
            (activeTool == ArchitectTool.pathway &&
                lt.pathwayCurbMode != ArchitectPathwayCurbMode.none) ||
            activeTool == ArchitectTool.street,
        curbWidth: activeTool == ArchitectTool.street
            ? lt.streetCurbWidth
            : lt.pathwayCurbWidth,
        previewRadius:
            activeTool == ArchitectTool.vegetation &&
                lt.plantPlacementMode ==
                    ArchitectVegetationPlacementMode.single &&
                lt.plantSpecies != ArchitectPlantSpecies.trimmedHedge
            ? lt.plantCrownDiameter * 0.5
            : null,
      );
    }
    if (activeTool == ArchitectTool.column && columnPreview != null) {
      ArchitectElementsPainterHelper.drawColumns(
        palette: palette,
        canvas: canvas,
        storey: project.activeStorey.copyWith(columns: [columnPreview!]),
        zoomScale: zoomScale,
        selectedElementId: columnPreview!.id,
      );
    }
    if (activeTool == ArchitectTool.zone &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      ArchitectZonePainterHelper.drawActiveZoneDrag(
        canvas: canvas,
        start: activeDraftStart!,
        end: activeDraftEnd!,
        category: activeZoneCategory ?? ArchitectZoneCategory.living,
        categoryName: zoneCategoryName,
        zoomScale: zoomScale,
      );

      return;
    }

    if (activeTool == ArchitectTool.wall &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      final p1 = activeDraftStart!;
      final p2 = activeWallArcEnd??activeDraftEnd!;
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist < 1e-4) return;

      final wall = ArchitectWall(
        id: 'preview',
        location: activeWallIsExterior ? ArchitectWallLocation.exterior : ArchitectWallLocation.interior,
        layers:activeWallLayers,
        arcBulge:activeWallArcEnd==null?0:activeWallArcBulge ?? ArchitectWallArc.through(p1,p2,activeDraftEnd!),
        startPoint: p1,
        endPoint: p2,
        thickness: activeWallThickness,
        referenceLine: activeWallReference,
        wallTypeId: activeWallTypeId,
        railing: activeWallRailing,
        height: activeWallHeight ?? project.activeStorey.height,
        exteriorSide: activeWallExteriorSide,
        insulationThicknessOverride: activeWallInsulation,
      );
      _drawWallLayers(
        canvas,
        ArchitectWallLayers.build([wall], _project.wallTypes),
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 1.8 / zoomScale
          ..style = PaintingStyle.stroke,
        hatchColor: const Color(0xFF00B8CC),
      );
      if (wall.railing != null) {
        for (final path in ArchitectRailingGeometry.planPaths(wall)) {
          canvas.drawPath(path, Paint()..color = const Color(0xff006e91)
            ..strokeWidth = ArchitectLineWeights.cutThin / zoomScale
            ..style = PaintingStyle.stroke);
        }
      }
      ArchitectWallExteriorPainter.draw(canvas, wall, zoomScale,
        palette.foreground(Colors.black87), provisional: !activeWallSideManual);

      canvas.drawCircle(
        p1,
        3 / draftingScale,
        Paint()..color = Colors.orangeAccent,
      );
      canvas.drawCircle(p2, 2 / draftingScale, Paint()..color = Colors.cyanAccent);
      // The interactive overlay owns the rise/radius dimension for arc drafts.
      if (activeWallCurved || activeWallArcEnd != null) return;
      // Keep a single target marker and a length-only badge outside the body.
      final textSpan = TextSpan(
        text: project.formatLength(wall.length),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
        ),
      );

      final tp = ArchitectTextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      final badge = ArchitectDimensionLayout.wallBadge(
        wall,
        Size(tp.width + 12, tp.height + 6),
        zoomScale,
        obstacles: Path.combine(
          PathOperation.union,
          ArchitectWallNetwork.body(_project.activeStorey.walls),
          Path()..addPolygon(wall.polygonCorners, true),
        ),
      );
      canvas.save();
      canvas.translate(badge.center.dx, badge.center.dy);
      canvas.scale(1.0 / zoomScale);
      final badgeRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 12,
        height: tp.height + 6,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
        Paint()..color = const Color(0xDD1E1E24),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    if ((activeTool == ArchitectTool.cadLine || activeTool == ArchitectTool.cadArc) &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      final p1 = activeDraftStart!;
      final p2 = activeWallArcEnd ?? activeDraftEnd!;
      final delta = p2 - p1;
      if (delta.distance >= 1e-4) {
        final bulge = activeWallArcEnd == null
            ? 0.0
            : activeWallArcBulge ?? ArchitectWallArc.through(p1, p2, activeDraftEnd!);
        final prim = ArchitectCadPrimitive(
          id: 'cad-preview',
          type: (activeTool == ArchitectTool.cadArc || bulge.abs() > 1e-6)
              ? CadPrimitiveType.arc
              : CadPrimitiveType.line,
          startPoint: p1,
          endPoint: p2,
          arcBulge: bulge,
          colorValue: 0xFF00E5FF,
          lineStyle: ArchitectLineStyle.dashed,
        );
        ArchitectElementsPainterHelper.drawCadPrimitives(
          canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', cadPrimitives: [prim]),
          zoomScale: zoomScale,
          dimensionScale: _project.dimensionScale,
        );
      }
    }

    if (activeTool == ArchitectTool.cadEllipse &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      final center = activeDraftStart!;
      final delta = activeDraftEnd! - center;
      final rx = delta.distance;
      if (rx >= 1e-4) {
        final ry = rx * 0.6;
        final rot = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
        final prim = ArchitectCadPrimitive(
          id: 'ellipse-preview',
          type: CadPrimitiveType.ellipse,
          startPoint: center - Offset(rx, ry),
          endPoint: center + Offset(rx, ry),
          radiusX: rx,
          radiusY: ry,
          rotationDeg: rot,
          colorValue: 0xFF00E5FF,
          lineStyle: ArchitectLineStyle.dashed,
        );
        ArchitectElementsPainterHelper.drawCadPrimitives(
          canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', cadPrimitives: [prim]),
          zoomScale: zoomScale,
          dimensionScale: _project.dimensionScale,
        );
      }
    }

    if (activeTool == ArchitectTool.leader &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      final p1 = activeDraftStart!;
      final p2 = activeDraftEnd!;
      if ((p2 - p1).distance >= 1e-4) {
        final annot = ArchitectAnnotation(
          id: 'leader-preview',
          position: p2,
          text: '',
          hasLeader: true,
          leaderArrowPoint: p1,
          leaderLandingPoint: p2,
          leaderLandingLength: 0.30,
        );
        ArchitectElementsPainterHelper.drawAnnotations(
          palette: palette,
          canvas: canvas,
          storey: ArchitectStorey(id: 'preview', name: '', annotations: [annot]),
          zoomScale: zoomScale,
        );
      }
    }

    if (activeTool == ArchitectTool.roofSlope && cursorPosition != null) {
      for (final plane in _project.activeStorey.roofs) {
        if (plane.containsPoint(cursorPosition!)) {
          final arrow = ArchitectRoofSlopeArrow(
            id: 'preview-arrow',
            roofPlaneId: plane.id,
            position: cursorPosition!,
            direction: RoofSlopeDirection.downslope,
            format: RoofSlopeFormat.percent,
          );
          ArchitectRoofPainterHelper.drawPlacedSlopeArrow(
            canvas: canvas,
            roof: plane,
            arrow: arrow,
            scale: zoomScale,
            color: const Color(0xFF00E5FF),
          );
          break;
        }
      }
    }
  }

  static void _drawDraftMarker(
    Canvas canvas,
    Offset point, {
    required double draftingScale,
    bool isStart = true,
    Color? color,
  }) {
    final primary = color ??
        (isStart ? const Color(0xFF00E5FF) : const Color(0xFFFFB300));

    if (isStart) {
      // 1. Soft orienting aura
      canvas.drawCircle(
        point,
        7.5 / draftingScale,
        Paint()
          ..color = primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      // 2. High-contrast dark outer rim
      canvas.drawCircle(
        point,
        5.5 / draftingScale,
        Paint()
          ..color = const Color(0xDE000000)
          ..strokeWidth = 2.4 / draftingScale
          ..style = PaintingStyle.stroke,
      );
      // 3. Crisp vibrant ring
      canvas.drawCircle(
        point,
        4.8 / draftingScale,
        Paint()
          ..color = primary
          ..strokeWidth = 1.6 / draftingScale
          ..style = PaintingStyle.stroke,
      );
      // 4. Solid core with pinpoint white center dot
      canvas.drawCircle(
        point,
        2.8 / draftingScale,
        Paint()..color = primary,
      );
      canvas.drawCircle(
        point,
        1.3 / draftingScale,
        Paint()..color = Colors.white,
      );
    } else {
      // Intermediate vertex node (neat, compact, dual-tone)
      canvas.drawCircle(
        point,
        4.2 / draftingScale,
        Paint()
          ..color = const Color(0xDE000000)
          ..strokeWidth = 2.0 / draftingScale
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        point,
        3.4 / draftingScale,
        Paint()..color = primary,
      );
      canvas.drawCircle(
        point,
        1.2 / draftingScale,
        Paint()..color = Colors.white,
      );
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double zoomScale,
  ) {
    final diff = p2 - p1;
    final totalLen = diff.distance;
    if (totalLen <= 0.0001) return;
    final dir = diff / totalLen;
    final effectiveScale = math.max(zoomScale, minDraftingScale);
    final dashLen = 8.0 / effectiveScale;
    final gapLen = 5.0 / effectiveScale;
    double current = 0.0;
    while (current < totalLen) {
      final next = math.min(current + dashLen, totalLen);
      canvas.drawLine(p1 + dir * current, p1 + dir * next, paint);
      current += dashLen + gapLen;
    }
  }

// === SECTION: [SEC-10-CORE] CORE OPERATIONS & HELPERS ===
// --- SUBSECTION: [TAG:ARCH_PAINTER_SHOULD_REPAINT] Core Operations & Helpers: `shouldRepaint` (1 methods) ---
  @override
  bool shouldRepaint(covariant Architect2dPainter oldDelegate) =>
      l10n != oldDelegate.l10n ||
      palette.isDark != oldDelegate.palette.isDark ||
      layer != oldDelegate.layer ||
      layer != ArchitectPaintLayer.model ||
      !identical(_project, oldDelegate._project) ||
      viewport != oldDelegate.viewport ||
      selectedZoneId != oldDelegate.selectedZoneId ||
      selectedAxisId != oldDelegate.selectedAxisId ||
      selectedElementId != oldDelegate.selectedElementId ||
      doorPreview != oldDelegate.doorPreview ||
      windowPreview != oldDelegate.windowPreview ||
      openingClearances != oldDelegate.openingClearances ||
      showOpeningClearanceBadges != oldDelegate.showOpeningClearanceBadges ||
      polygonLeaderLine != oldDelegate.polygonLeaderLine ||
      wallEndpointLeaderLine != oldDelegate.wallEndpointLeaderLine ||
      newPointCandidate != oldDelegate.newPointCandidate ||
      newPointHandleOffset != oldDelegate.newPointHandleOffset ||
      newPointValid != oldDelegate.newPointValid ||
      newPointLeaderLine != oldDelegate.newPointLeaderLine ||
      handleOffsetLength != oldDelegate.handleOffsetLength ||
      wallCutGuideLine != oldDelegate.wallCutGuideLine ||
      wallCutAnchor != oldDelegate.wallCutAnchor ||
      wallCutLine != oldDelegate.wallCutLine ||
      mirrorAnchor != oldDelegate.mirrorAnchor ||
      mirrorAxisLine != oldDelegate.mirrorAxisLine ||
      splitPoint1 != oldDelegate.splitPoint1 ||
      splitPerpendicularGuide != oldDelegate.splitPerpendicularGuide ||
      splitCutLine != oldDelegate.splitCutLine ||
      activeOvershoot != oldDelegate.activeOvershoot ||
      showUpperOverhangs != oldDelegate.showUpperOverhangs ||
      showFurniture != oldDelegate.showFurniture ||
      componentPreview != oldDelegate.componentPreview ||
      upperOverhangs != oldDelegate.upperOverhangs ||
      isZoneTableSelected != oldDelegate.isZoneTableSelected ||
      zoneTableDragPreviewOrigin != oldDelegate.zoneTableDragPreviewOrigin ||
      _zoomScale != oldDelegate._zoomScale ||
      underlayDoc != oldDelegate.underlayDoc ||
      dragController != oldDelegate.dragController ||
      localizeSnap != oldDelegate.localizeSnap;
}
