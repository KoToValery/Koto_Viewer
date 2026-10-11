import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import 'architect_elements_painter_helper.dart';
import 'architect_grid_axis_painter_helper.dart';
import 'architect_zone_painter_helper.dart';

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

enum WallDraftingMode {
  singleLine,
  chained,
}

/// High-performance 2D architectural floor plan painter.
class Architect2dPainter extends CustomPainter {
  final ArchitectProject project;
  final ArchitectTool activeTool;
  final Offset? activeDraftStart;
  final Offset? activeDraftEnd;
  final double activeWallThickness;
  final String? activeSnapLabel;
  final String? selectedElementId;
  final String? selectedZoneId;
  final ArchitectZoneCategory? activeZoneCategory;
  final int? draggingVertexIndex;
  final Offset? draggingVertexPoint;
  final int? mergeCandidateIndex;
  final List<(Offset, Offset)> magneticGuides;
  final double zoomScale;
  final Offset? cursorPosition;

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

  const Architect2dPainter({
    required this.project,
    required this.activeTool,
    this.activeDraftStart,
    this.activeDraftEnd,
    this.activeWallThickness = 0.25,
    this.activeSnapLabel,
    this.selectedElementId,
    this.selectedZoneId,
    this.activeZoneCategory,
    this.draggingVertexIndex,
    this.draggingVertexPoint,
    this.mergeCandidateIndex,
    this.magneticGuides = const [],
    this.zoomScale = 1.0,
    this.cursorPosition,
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (underlayDoc != null) {
      ArchitectElementsPainterHelper.drawUnderlay(
        canvas: canvas,
        underlayDoc: underlayDoc,
        zoomScale: zoomScale,
        layerVisibility: underlayLayerVisibility,
      );
    }
    _drawDraftingGrid(canvas, size);
    _drawGridAxes(canvas);
    ArchitectElementsPainterHelper.drawSlabs(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    _drawZones(canvas);
    ArchitectElementsPainterHelper.drawBeams(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    _drawWalls(canvas);
    ArchitectElementsPainterHelper.drawColumns(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    ArchitectElementsPainterHelper.drawOpenings(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    ArchitectElementsPainterHelper.drawStairs(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    ArchitectElementsPainterHelper.drawCadPrimitives(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    _drawActiveDrafting(canvas);
    ArchitectElementsPainterHelper.drawActiveElementsDrafting(
      canvas: canvas,
      activeTool: activeTool,
      draftStart: activeDraftStart,
      draftEnd: activeDraftEnd,
      zoomScale: zoomScale,
    );
    ArchitectElementsPainterHelper.drawDimensions(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    ArchitectElementsPainterHelper.drawElevationMarkers(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
    ArchitectElementsPainterHelper.drawAnnotations(
      canvas: canvas,
      storey: project.activeStorey,
      zoomScale: zoomScale,
      selectedElementId: selectedElementId,
    );
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

  void _drawZones(Canvas canvas) {
    ArchitectZonePainterHelper.drawZones(
      canvas: canvas,
      project: project,
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

    // Draw grid lines at 1.0 meter and 5.0 meter intervals
    const gridRange = 40.0; // +/- 40 meters
    for (double i = -gridRange; i <= gridRange; i += 1.0) {
      final isMajor = (i.round() % 5 == 0);
      final p = isMajor ? majorGridPaint : gridPaint;
      canvas.drawLine(Offset(i, -gridRange), Offset(i, gridRange), p);
      canvas.drawLine(Offset(-gridRange, i), Offset(gridRange, i), p);
    }
  }

  // ===========================================================================
  // 2. STRUCTURAL GRID AXES
  // ===========================================================================

  void _drawGridAxes(Canvas canvas) {
    ArchitectGridAxisPainterHelper.drawAxes(
      canvas: canvas,
      project: project,
      zoomScale: zoomScale,
      selectedAxisId: selectedAxisId,
      draggedAxisSnapshot: draggedAxisSnapshot,
      isDraggingHandle: isDraggingAxisHandle,
      isMovingAxis: isMovingAxis,
      moveOriginalAxis: moveOriginalAxis,
      moveCurrentDelta: moveCurrentDelta,
      offsetPreview: axisOffsetPreview,
      draftStart: axisDraftStart,
      draftEnd: axisDraftEnd,
      draftSnapLabel: axisDraftSnapLabel,
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

      canvas.drawPath(path, wallFillPaint);
      canvas.drawPath(path, borderPaint);

      // Draw all hosted Doors
      for (final door in wall.doors) {
        door.paint2D(
          canvas: canvas,
          wallStart: wall.startPoint,
          wallEnd: wall.endPoint,
          wallThickness: wall.thickness,
          zoomScale: zoomScale,
          isSelected: door.id == selectedElementId,
        );
      }

      // Draw all hosted Windows
      for (final window in wall.windows) {
        window.paint2D(
          canvas: canvas,
          wallStart: wall.startPoint,
          wallEnd: wall.endPoint,
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

      final u = delta / dist;
      final n = Offset(-u.dy, u.dx) * (activeWallThickness / 2.0);

      final corners = [
        p1 - n,
        p2 - n,
        p2 + n,
        p1 + n,
      ];

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
            ? '${dist.toStringAsFixed(2)} m  ($activeSnapLabel)'
            : '${dist.toStringAsFixed(2)} m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.0,
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
  bool shouldRepaint(covariant Architect2dPainter oldDelegate) => true;
}
