import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../models/architect_column.dart';
import 'architect_elements_painter_helper.dart';
import 'architect_grid_axis_painter_helper.dart';
import 'architect_zone_painter_helper.dart';
import 'architect_scene_geometry.dart';
import 'architect_wall_network.dart';
import '../models/architect_wall.dart';

enum ArchitectPaintLayer { all, model, interaction }

enum ArchitectTool {
  select,
  axis,
  zone,
  wall,
  door,
  window,
  column,
  beam,
  slab,
  opening,
  stair,
  dimension,
  level,
  text,
  cadLine,
  cadRect,
  cadCircle,
  measure,
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
  final ArchitectTool activeTool;
  final Offset? activeDraftStart;
  final Offset? activeDraftEnd;
  final double activeWallThickness;
  final WallReferenceLine activeWallReference;
  final String? activeSnapLabel;
  final String? selectedElementId;
  final String? selectedZoneId;
  final ArchitectZoneCategory? activeZoneCategory;
  final int? draggingVertexIndex;
  final Offset? draggingVertexPoint;
  final int? mergeCandidateIndex;
  final List<(Offset, Offset)> magneticGuides;
  final double _zoomScale;
  double get zoomScale => viewport?.scale ?? _zoomScale;
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
  final bool isMoveWholeZoneMode;
  final double zoneMoveDistanceMeters;

  // CAD Underlay state
  final DxfDocument? underlayDoc;
  final Map<String, bool> underlayLayerVisibility;

  // Slab drafting state
  final List<Offset> slabDraftPoints;
  final Offset? slabCandidatePoint;

  Architect2dPainter({
    required ArchitectProject project,
    this.viewport,
    this.layer = ArchitectPaintLayer.all,
    this.paintGrid = true,
    required this.activeTool,
    this.activeDraftStart,
    this.activeDraftEnd,
    this.activeWallThickness = 0.25,
    this.activeWallReference = WallReferenceLine.center,
    this.activeSnapLabel,
    this.selectedElementId,
    this.selectedZoneId,
    this.activeZoneCategory,
    this.draggingVertexIndex,
    this.draggingVertexPoint,
    this.mergeCandidateIndex,
    this.magneticGuides = const [],
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
    this.zoneExtrudePreviewPolygon,
    this.zoneExtrudeV1,
    this.zoneExtrudeV2,
    this.zoneExtrudeNormal,
    this.zoneExtrudeDistance,
    this.isZoneExtrudeSelfIntersecting = false,
    this.zonePreviewRectangle = const [],
    this.zoneEditingPolygon,
    this.isMoveWholeZoneMode = false,
    this.zoneMoveDistanceMeters = 0.0,
    this.underlayDoc,
    this.underlayLayerVisibility = const {},
    this.slabDraftPoints = const [],
    this.slabCandidatePoint,
  }) : _project = project,
       _zoomScale = zoomScale,
       super(repaint: viewport);

  @override
  void paint(Canvas canvas, Size size) {
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
          canvas: canvas,
          underlayDoc: underlayDoc,
          zoomScale: zoomScale,
          layerVisibility: underlayLayerVisibility,
        );
      }
      if (paintGrid) _drawDraftingGrid(canvas, size);
      _drawGridAxes(canvas);
      ArchitectElementsPainterHelper.drawSlabs(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      _drawZones(canvas);
      ArchitectElementsPainterHelper.drawBeams(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      _drawWalls(canvas);
      ArchitectElementsPainterHelper.drawColumns(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawOpenings(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawStairs(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawCadPrimitives(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
    }
    if (layer != ArchitectPaintLayer.model) {
      if (layer == ArchitectPaintLayer.interaction) {
        _drawGridAxes(canvas);
        _drawZones(canvas);
        _drawSelectedElement(canvas);
      }
      _drawActiveDrafting(canvas);
      ArchitectElementsPainterHelper.drawActiveElementsDrafting(
        canvas: canvas,
        activeTool: activeTool,
        draftStart: activeDraftStart,
        draftEnd: activeDraftEnd,
        zoomScale: zoomScale,
      );
    }
    if (layer != ArchitectPaintLayer.interaction) {
      ArchitectElementsPainterHelper.drawDimensions(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawElevationMarkers(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
      ArchitectElementsPainterHelper.drawAnnotations(
        canvas: canvas,
        storey: _elementLayerStorey,
        zoomScale: zoomScale,
        selectedElementId: selectedElementId,
      );
    }
    if (layer != ArchitectPaintLayer.model) {
      ArchitectElementsPainterHelper.drawSlabDrafting(
        canvas: canvas,
        points: slabDraftPoints,
        candidatePoint: slabCandidatePoint,
        zoomScale: zoomScale,
      );
      _drawZoneDrafting(canvas);
      _drawZoneExtrudePreview(canvas);
      ArchitectZonePainterHelper.drawMagneticGuides(
        canvas: canvas,
        guides: magneticGuides,
        zoomScale: zoomScale,
      );
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
      openings: storey.openings.where((e) => keep(e.id)).toList(),
      stairs: storey.stairs.where((e) => keep(e.id)).toList(),
      dimensions: storey.dimensions.where((e) => keep(e.id)).toList(),
      annotations: storey.annotations.where((e) => keep(e.id)).toList(),
      elevationMarkers: storey.elevationMarkers
          .where((e) => keep(e.id))
          .toList(),
      cadPrimitives: storey.cadPrimitives.where((e) => keep(e.id)).toList(),
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
      for (final point in [wall.startPoint, wall.endPoint]) {
        canvas.drawCircle(point, 7 / zoomScale, Paint()..color = Colors.cyan);
      }
      return;
    }
    final selected = _filterElements(project.activeStorey, selectedOnly: true);
    Architect2dPainter(
      project: project.updateActiveStorey(selected).copyWithGridAxes([]),
      activeTool: ArchitectTool.select,
      paintGrid: false,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    ).paint(canvas, Size.zero);
  }

  void _drawZones(Canvas canvas) {
    ArchitectZonePainterHelper.drawZones(
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
      isMoveWholeZoneMode: isMoveWholeZoneMode,
      moveDistanceMeters: zoneMoveDistanceMeters,
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
      ArchitectZonePainterHelper.drawPointByPointDrafting(
        canvas: canvas,
        points: zoneDraftingPoints,
        candidatePoint: zoneDraftingCandidate,
        category: activeZoneCategory ?? ArchitectZoneCategory.living,
        zoomScale: zoomScale,
        orthoGuide: zoneOrthoGuide,
        orthoLabel: zoneOrthoLabel,
        isClosingSnap: isZoneClosingSnap,
        isSelfIntersecting: isZoneDraftingSelfIntersecting,
        closeLabel: zoneCloseLabel,
        previewRectangle: zonePreviewRectangle,
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
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 0.5 / zoomScale;

    final majorGridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.0 / zoomScale;

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

    final wallFillPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final wallBorderPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    final body = ArchitectWallNetwork.body(_project.activeStorey.walls);
    canvas.drawPath(body, wallFillPaint);
    canvas.save();
    canvas.clipPath(body);
    final bounds = body.getBounds().intersect(canvas.getLocalClipBounds());
    final spacing = math.max(.12, 8 / zoomScale);
    final hatch = Paint()
      ..color = const Color(0xFF9EA5AC)
      ..strokeWidth = .6 / zoomScale;
    for (
      double x = ((bounds.left - bounds.height) / spacing).floor() * spacing;
      x < bounds.right;
      x += spacing
    ) {
      canvas.drawLine(
        Offset(x, bounds.bottom),
        Offset(x + bounds.height, bounds.top),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawPath(body, wallBorderPaint);
    for (final wall in activeStorey.walls) {
      final isSelected = wall.id == selectedElementId;
      final borderPaint = isSelected
          ? (Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 2.5 / zoomScale
              ..style = PaintingStyle.stroke)
          : wallBorderPaint;

      // Draw Wall Body
      final corners = wall.polygonCorners;
      final path = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();

      if (isSelected) {
        canvas.drawPath(path, borderPaint);
        for (final point in [wall.startPoint, wall.endPoint]) {
          canvas.drawCircle(point, 7 / zoomScale, Paint()..color = Colors.cyan);
        }
      }

      // Draw all hosted Doors
      for (final door in wall.doors) {
        door.paint2D(
          canvas: canvas,
          wallStart: wall.centerStart,
          wallEnd: wall.centerEnd,
          wallThickness: wall.thickness,
          zoomScale: zoomScale,
          isSelected: door.id == selectedElementId,
        );
      }

      // Draw all hosted Windows
      for (final window in wall.windows) {
        window.paint2D(
          canvas: canvas,
          wallStart: wall.centerStart,
          wallEnd: wall.centerEnd,
          wallThickness: wall.thickness,
          zoomScale: zoomScale,
          isSelected: window.id == selectedElementId,
        );
      }
    }
  }

  // ===========================================================================
  // 4. ACTIVE DRAFTING INTERACTION
  // ===========================================================================

  void _drawActiveDrafting(Canvas canvas) {
    if (activeTool == ArchitectTool.wall && cursorPosition != null) {
      final target = activeDraftEnd ?? cursorPosition!;
      final paint = Paint()
        ..color = activeSnapLabel == null ? Colors.orange : Colors.cyan
        ..strokeWidth = 1.5 / zoomScale
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(target, 7 / zoomScale, paint);
      canvas.drawLine(
        target - Offset(12 / zoomScale, 0),
        target + Offset(12 / zoomScale, 0),
        paint,
      );
      canvas.drawLine(
        target - Offset(0, 12 / zoomScale),
        target + Offset(0, 12 / zoomScale),
        paint,
      );
    }
    if (activeTool == ArchitectTool.column && columnPreview != null) {
      ArchitectElementsPainterHelper.drawColumns(
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
        zoomScale: zoomScale,
      );
      return;
    }

    if (activeTool == ArchitectTool.wall &&
        activeDraftStart != null &&
        activeDraftEnd != null) {
      final p1 = activeDraftStart!;
      final p2 = activeDraftEnd!;
      final delta = p2 - p1;
      final dist = delta.distance;
      if (dist < 1e-4) return;

      final corners = ArchitectWall(
        id: 'preview',
        startPoint: p1,
        endPoint: p2,
        thickness: activeWallThickness,
        referenceLine: activeWallReference,
      ).polygonCorners;

      // Preview wall body
      final previewPath = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();

      canvas.drawPath(
        previewPath,
        Paint()
          ..color = const Color(0x3300E5FF)
          ..style = PaintingStyle.fill,
      );

      canvas.drawPath(
        previewPath,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 1.8 / zoomScale
          ..style = PaintingStyle.stroke,
      );

      // Baseline guideline
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = const Color(0xFFFFD600)
          ..strokeWidth = 1.0 / zoomScale
          ..style = PaintingStyle.stroke,
      );

      // End snap point target
      canvas.drawCircle(
        p2,
        5.0 / zoomScale,
        Paint()..color = const Color(0xFFFFD600),
      );

      // Dimensional length badge floating in the middle
      final mid = (p1 + p2) / 2.0;
      final textSpan = TextSpan(
        text: activeSnapLabel != null
            ? '${project.units.format(dist, decimals: 3)}  ($activeSnapLabel)'
            : project.units.format(dist, decimals: 3),
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
        ),
      );

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(1.0 / zoomScale);

      final badgeRect = Rect.fromLTWH(
        -tp.width / 2 - 6,
        -tp.height / 2 - 18,
        tp.width + 12,
        tp.height + 6,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
        Paint()..color = const Color(0xDD1E1E24),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 - 15));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant Architect2dPainter oldDelegate) =>
      layer != oldDelegate.layer ||
      layer != ArchitectPaintLayer.model ||
      !identical(_project, oldDelegate._project) ||
      viewport != oldDelegate.viewport ||
      selectedZoneId != oldDelegate.selectedZoneId ||
      selectedAxisId != oldDelegate.selectedAxisId ||
      selectedElementId != oldDelegate.selectedElementId ||
      _zoomScale != oldDelegate._zoomScale ||
      underlayDoc != oldDelegate.underlayDoc;
}
