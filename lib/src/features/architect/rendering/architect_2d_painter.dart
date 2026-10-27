import 'architect_selection_painter.dart';
import '../models/architect_line_style.dart';
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
import 'architect_wall_layers.dart';
import 'architect_wall_hatch.dart';
import '../models/architect_wall.dart';
import '../models/architect_door.dart';
import '../models/architect_window.dart';
import 'architect_dimension_layout.dart';
import '../services/architect_selection.dart';
import '../services/architect_wall_relations.dart';
import '../services/architect_wall_overshoot_detector.dart';
import '../models/architect_overhang.dart';
import '../services/architect_overhang_detector.dart';
import 'architect_overhang_painter_helper.dart';
import '../services/architect_roof_tool.dart';
import 'architect_roof_painter_helper.dart';

enum ArchitectPaintLayer { all, model, interaction }

enum ArchitectTool {
  select,
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
  measure,
  hatch,
  floorDrain,
  section,
  elevation,
  pan,
}

enum WallDraftingMode { singleLine, chained }

/// High-performance 2D architectural floor plan painter.
class Architect2dPainter extends CustomPainter {
  final ArchitectProject _project;
  ArchitectProject? _visibleProject;
  ArchitectProject get project => _visibleProject ?? _project;
  final BimViewportController? viewport;
  final ArchitectPaintLayer layer;
  final bool paintGrid;
  final String? drawingViewKey;
  final ArchitectCanvasPalette palette;
  final AppLocalizations? l10n;
  final ArchitectTool activeTool;
  final ArchitectLineStyle activeCadLineStyle;
  final List<ArchitectMaterialLayer> activeWallLayers;
  final Offset? activeWallArcEnd;
  final Offset? activeDraftStart;
  final Offset? activeDraftEnd;
  final ArchitectStair? stairPreview;
  final double activeWallThickness;
  final WallReferenceLine activeWallReference;
  final String? activeWallTypeId;
  final WallExteriorSide activeWallExteriorSide;
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
  final bool polygonEditInvalid;
  final int? polygonEditHoleIndex;
  final (Offset, Offset)? polygonLeaderLine;
  final double handleOffsetLength;
  final (Offset, Offset)? wallEndpointLeaderLine;
  final Offset? newPointCandidate;
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
    this.drawingViewKey,
    this.palette = const ArchitectCanvasPalette.light(),
    this.activeOvershoot,
    this.upperOverhangs,
    this.showUpperOverhangs = true,
    this.showFurniture = true,
    this.componentPreview,
    this.marqueePoints = const [],
    this.marqueePolygon = const [],
    required this.activeTool,
    this.activeCadLineStyle = ArchitectLineStyle.solid,
    this.activeWallLayers = const [],
    this.activeWallArcEnd,
    this.activeDraftStart,
    this.activeDraftEnd,
    this.stairPreview,
    this.activeWallThickness = 0.25,
    this.activeWallReference = WallReferenceLine.center,
    this.activeWallTypeId,
    this.activeWallExteriorSide = WallExteriorSide.left,
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
    this.polygonEditInvalid = false,
    this.polygonEditHoleIndex,
    this.polygonLeaderLine,
    this.handleOffsetLength = 50.0,
    this.wallEndpointLeaderLine,
    this.newPointCandidate,
    this.newPointLeaderLine,
  }) : _project = project,
       _zoomScale = zoomScale,
       super(repaint: viewport);

  @override
  void paint(Canvas canvas, Size size) {
    if (ArchitectTextScope.current == null) {
      final key = drawingViewKey ?? 'plan:${_project.activeStoreyId}';
      final denominator = _project.document.viewScales[key] ?? _project.dimensionScale.denominator;
      ArchitectTextScope(_project.document, key, denominator, zoomScale, units: _project.units, decimals: _project.distanceDecimals).run(() => _paint(canvas, size));
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
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas, storey: _elementLayerStorey, zoomScale: zoomScale,
        palette: palette, dimensionScale: _project.dimensionScale,
        selectedElementId: null, hatchesOnly: true,
      );
      _drawGridAxes(canvas);
      ArchitectElementsPainterHelper.drawSlabs(
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
      ArchitectElementsPainterHelper.drawComponents(
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
      _drawNewPointPreview(canvas);
      _drawActiveDrafting(canvas);
      for(final id in selectionPreviewActive?selectionPreviewIds:selectedElementIds) {
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
    }
    canvas.restore();
  }

  ArchitectStorey get _elementLayerStorey =>
      _filterElements(project.activeStorey, selectedOnly: false);

  ArchitectStorey _filterElements(
    ArchitectStorey storey, {
    required bool selectedOnly,
  }) {
    if (!selectedOnly &&
        (layer != ArchitectPaintLayer.model || selectedElementId == null)) {
      return storey;
    }
    bool keep(String id) =>
        selectedOnly ? id == selectedElementId : id != selectedElementId;
    return storey.copyWith(
      walls: storey.walls.where((e) => keep(e.id)).toList(),
      columns: storey.columns.where((e) => keep(e.id)).toList(),
      beams: storey.beams.where((e) => keep(e.id)).toList(),
      slabs: storey.slabs.where((e) => keep(e.id)).toList(),
      roofs: storey.roofs.where((e) => keep(e.id)).toList(),
      openings: storey.openings.where((e) => keep(e.id)).toList(),
      stairs: storey.stairs.where((e) => keep(e.id)).toList(),
      dimensions: storey.dimensions.where((e) => keep(e.id)).toList(),
      annotations: storey.annotations.where((e) => keep(e.id)).toList(),
      elevationMarkers: storey.elevationMarkers
          .where((e) => keep(e.id))
          .toList(),
      cadPrimitives: storey.cadPrimitives.where((e) => keep(e.id) || (!selectedOnly && e.type == CadPrimitiveType.hatch)).toList(),
      floorDrains: storey.floorDrains.where((e) => keep(e.id)).toList(),
      zones: selectedOnly ? [] : storey.zones,
    );
  }

  void _drawSelectedElement(Canvas canvas) {
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
      _drawSelectedWallHandles(canvas, wall);
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
      paintGrid: false,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    ).paint(canvas, Size.zero);
  }

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
    final draftingScale = math.max(zoomScale, 80.0);
    const candidateColor = Color(0xFF00E5FF);

    if (newPointLeaderLine != null) {
      final (from, to) = newPointLeaderLine!;
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

    // Direct candidate point dot
    canvas.drawCircle(
      newPointCandidate!,
      5.0 / draftingScale,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(
      newPointCandidate!,
      4.0 / draftingScale,
      Paint()..color = candidateColor,
    );
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

  void _drawZoneSchedule(Canvas canvas) {
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

  void _drawWalls(Canvas canvas) {
    final activeStorey = project.activeStorey;

    architectDrawingSources(canvas, activeStorey.walls.map((w) => w.id), 'wall');
    final wallBorderPaint = Paint()
      ..color = palette.foreground(const Color(0xFF212121))
      ..strokeWidth = ArchitectLineWeights.cutHeavy / zoomScale
      ..style = PaintingStyle.stroke;

    final layers = ArchitectWallLayers.forProject(_project);
    _drawWallLayers(canvas, layers, wallBorderPaint);
    final midDotPaint = Paint()
      ..color = const Color(0x99B0BEC5)
      ..style = PaintingStyle.fill;
    final midBorderPaint = Paint()
      ..color = palette.foreground(const Color(0x66000000))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / draftingScale;

    for (final wall in activeStorey.walls) {
      final isSelected =
          wall.id == selectedElementId || selectedElementIds.contains(wall.id);
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

  void _drawActiveDrafting(Canvas canvas) {
    for (final gap in wallClearances) {
      final wall = project.activeStorey.walls.firstWhere(
        (w) => w.id == gap.wallId,
      );
      final direction = gap.end - gap.start;
      final tick =
          (direction.distance < 1e-8
              ? wall.unitVector
              : Offset(-direction.dy, direction.dx) / direction.distance) *
          (4 / draftingScale);
      final paint = Paint()
        ..color = palette.foreground(const Color(0xFF008C9E))
        ..strokeWidth = 1 / draftingScale;
      canvas.drawLine(gap.start, gap.end, paint);
      for (final point in [gap.start, gap.end]) {
        canvas.drawLine(point - tick, point + tick, paint);
      }
      if (gap.atStart != null) {
        final dotRadius = 7 / draftingScale;
        canvas.drawCircle(
          gap.start,
          dotRadius,
          Paint()..color = const Color(0xFFFFB74D),
        );
        if (dotRadius * zoomScale >= 4.5) {
          final marker = ArchitectTextPainter(
            text: TextSpan(
              text: gap.atStart! ? '1' : '2',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
                fontSize: 10 / draftingScale,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          marker.paint(
            canvas,
            gap.start - Offset(marker.width / 2, marker.height / 2),
          );
        }
      }
    }

    if (doorPreview != null) {
      final hostWall = _project.activeStorey.walls
          .where((w) => w.id == doorPreview!.wallId)
          .firstOrNull;
      if (hostWall != null) {
        doorPreview!.paint2D(
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
    if (cursorPosition != null &&
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
    if (activeTool == ArchitectTool.wall &&
        cursorPosition != null &&
        showWallCursor) {
      final target = activeDraftEnd ?? cursorPosition!;
      final paint = Paint()
        ..color = activeSnapLabel == null ? Colors.orange : Colors.cyan
        ..strokeWidth = 1.5 / draftingScale
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(target, 5 / draftingScale, paint);
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
        layers:activeWallLayers,
        arcBulge:activeWallArcEnd==null?0:ArchitectWallArc.through(p1,p2,activeDraftEnd!),
        startPoint: p1,
        endPoint: p2,
        thickness: activeWallThickness,
        referenceLine: activeWallReference,
        wallTypeId: activeWallTypeId,
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

      canvas.drawCircle(
        p1,
        3 / draftingScale,
        Paint()..color = Colors.orangeAccent,
      );
      canvas.drawCircle(p2, 2 / draftingScale, Paint()..color = Colors.cyanAccent);
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
      underlayDoc != oldDelegate.underlayDoc;
}
