import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import 'structural_pointer_painter.dart';

/// 2D CustomPainter that renders structural elements, ghost storeys (ArchiCAD Trace Reference),
/// interactive drawing previews, and cantilever warning zones projected onto CAD scene coordinates.
class Structural2dPainter extends CustomPainter {
  final StoreyLevel currentStorey;
  final StoreyLevel? ghostStorey;
  final List<CantileverZone> cantileverZones;
  final bool showCantileverHeatmap;
  final StructuralDrawTool activeTool;
  final StructuralColumn? previewColumn;
  final Offset? previewColumnPos;
  final Offset? wallStartPos;
  final Offset? currentCursorCad;
  final Offset? slabStartCornerCad;
  final List<Offset> slabPointsInProgress;
  final SlabEdgeGripInfo? extrudingGrip;
  final double? extrusionDistance;
  final String? selectedColumnId;
  final String? selectedShearWallId;
  final StructuralColumn? movingColumn;
  final Offset? movingColumnPos;
  final String? selectedSlabId;
  final int? draggingSlabVertexIndex;
  final Offset? draggingSlabVertexPos;
  final int? mergeCandidateVertexIndex;
  final double cadUnitsPerMeter;
  final double zoomScale;
  final Offset Function(Offset) cadToScene;
  final double cadScale;

  const Structural2dPainter({
    required this.currentStorey,
    this.ghostStorey,
    this.cantileverZones = const [],
    this.showCantileverHeatmap = true,
    this.activeTool = StructuralDrawTool.select,
    this.previewColumn,
    this.previewColumnPos,
    this.wallStartPos,
    this.currentCursorCad,
    this.slabStartCornerCad,
    this.slabPointsInProgress = const [],
    this.extrudingGrip,
    this.extrusionDistance,
    this.selectedColumnId,
    this.selectedShearWallId,
    this.movingColumn,
    this.movingColumnPos,
    this.selectedSlabId,
    this.draggingSlabVertexIndex,
    this.draggingSlabVertexPos,
    this.mergeCandidateVertexIndex,
    this.cadUnitsPerMeter = 1.0,
    this.zoomScale = 1.0,
    required this.cadToScene,
    required this.cadScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Ghost Storey (Trace Reference underlay) if enabled
    if (ghostStorey != null) {
      _drawGhostStorey(canvas, ghostStorey!);
    }

    // 2. Draw Active Storey Slabs
    for (final slab in currentStorey.slabs) {
      _drawSlab(canvas, slab, isGhost: false);
    }

    // 3. Draw Active Storey Shear Walls
    for (final wall in currentStorey.shearWalls) {
      _drawShearWall(canvas, wall, isGhost: false);
    }

    // 4. Draw Active Storey Columns
    for (final col in currentStorey.columns) {
      _drawColumn(canvas, col, isGhost: false);
    }

    // 5. Draw Interactive In-Progress Elements
    _drawInteractivePreview(canvas);

    // 5b. Draw live edge extrusion preview if dragging a midpoint grip
    if (extrudingGrip != null && extrusionDistance != null) {
      _drawEdgeExtrusionPreview(canvas, extrudingGrip!, extrusionDistance!);
    }

    // 6. Draw Cantilever Overhangs & Warning Zones (Heatmap)
    if (showCantileverHeatmap && cantileverZones.isNotEmpty) {
      _drawCantileverOverlays(canvas);
    }
  }

  void _drawGhostStorey(Canvas canvas, StoreyLevel ghost) {
    for (final slab in ghost.slabs) {
      _drawSlab(canvas, slab, isGhost: true);
    }
    for (final wall in ghost.shearWalls) {
      _drawShearWall(canvas, wall, isGhost: true);
    }
    for (final col in ghost.columns) {
      _drawColumn(canvas, col, isGhost: true);
    }
  }

  void _drawSlab(Canvas canvas, StructuralSlab slab, {required bool isGhost}) {
    if (slab.polygon.length < 3) return;

    final isSelected = !isGhost && (slab.id == selectedSlabId);
    List<Offset> polygon = slab.polygon;
    if (isSelected &&
        draggingSlabVertexIndex != null &&
        draggingSlabVertexPos != null &&
        draggingSlabVertexIndex! < polygon.length) {
      polygon = List<Offset>.from(polygon);
      polygon[draggingSlabVertexIndex!] = draggingSlabVertexPos!;
    }

    final pts = polygon.map(cadToScene).toList();
    final path = Path();
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    // Subtract openings
    for (final op in slab.openings) {
      if (op.length >= 3) {
        final opPts = op.map(cadToScene).toList();
        final opPath = Path();
        opPath.moveTo(opPts.first.dx, opPts.first.dy);
        for (int i = 1; i < opPts.length; i++) {
          opPath.lineTo(opPts[i].dx, opPts[i].dy);
        }
        opPath.close();
        path.addPath(opPath, Offset.zero);
      }
    }

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x1A90CAF9)
          : (isSelected ? const Color(0x3D7C4DFF) : const Color(0x2803A9F4))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x6664B5F6)
          : (isSelected ? const Color(0xFFB388FF) : const Color(0xFF0288D1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isGhost
          ? (1.0 / zoomScale)
          : (isSelected ? (2.5 / zoomScale) : (2.0 / zoomScale));

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // If selected, draw corner vertex handles
    if (isSelected) {
      _drawSlabVertexHandles(canvas, polygon);
    }

    // Draw midpoint edge grips for slabs on active storey
    if (!isGhost) {
      _drawSlabEdgeGrips(canvas, slab);
    }
  }

  void _drawSlabVertexHandles(Canvas canvas, List<Offset> polygon) {
    final double radius = 6.0 / zoomScale;
    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;

    final candidateFill = Paint()
      ..color = const Color(0x55F44336)
      ..style = PaintingStyle.fill;
    final candidateStroke = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / zoomScale;

    for (int i = 0; i < polygon.length; i++) {
      final scenePt = cadToScene(polygon[i]);
      if (mergeCandidateVertexIndex == i) {
        // Highlight merge candidate with glowing red target
        canvas.drawCircle(scenePt, radius * 1.8, candidateFill);
        canvas.drawCircle(scenePt, radius * 1.8, candidateStroke);
      }

      if (draggingSlabVertexIndex == i) {
        // Active dragging vertex
        final activeFill = Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scenePt, radius * 1.3, activeFill);
        canvas.drawCircle(scenePt, radius * 1.3, handleStroke);
      } else {
        canvas.drawCircle(scenePt, radius, handleFill);
        canvas.drawCircle(scenePt, radius, handleStroke);
      }
    }
  }

  void _drawSlabEdgeGrips(Canvas canvas, StructuralSlab slab) {
    final grips = slab.edgeGrips;
    if (grips.isEmpty) return;

    final double radius = 4.5 / zoomScale;
    final gripFill = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final gripBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoomScale;

    for (final grip in grips) {
      if (extrudingGrip != null &&
          extrudingGrip!.edgeIndex == grip.edgeIndex &&
          (extrudingGrip!.midpoint - grip.midpoint).distance < 1e-4) {
        continue;
      }
      final sceneMid = cadToScene(grip.midpoint);
      canvas.drawCircle(sceneMid, radius, gripFill);
      canvas.drawCircle(sceneMid, radius, gripBorder);
    }
  }

  void _drawEdgeExtrusionPreview(
      Canvas canvas, SlabEdgeGripInfo grip, double d) {
    final v1 = grip.v1;
    final v2 = grip.v2;
    final normal = grip.normal;
    final vNew1 = v1 + normal * d;
    final vNew2 = v2 + normal * d;
    final midNew = grip.midpoint + normal * d;

    final sV1 = cadToScene(v1);
    final sV2 = cadToScene(v2);
    final sNew1 = cadToScene(vNew1);
    final sNew2 = cadToScene(vNew2);
    final sMidNew = cadToScene(midNew);

    // Translucent fill for extruded region
    final fillPath = Path()
      ..moveTo(sV1.dx, sV1.dy)
      ..lineTo(sNew1.dx, sNew1.dy)
      ..lineTo(sNew2.dx, sNew2.dy)
      ..lineTo(sV2.dx, sV2.dy)
      ..close();

    final fillPaint = Paint()
      ..color = const Color(0x3800E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Original edge (dimmed line showing existing baseline)
    final ghostEdgePaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawLine(sV1, sV2, ghostEdgePaint);

    // Perpendicular side connection lines
    final sidePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;
    canvas.drawLine(sV1, sNew1, sidePaint);
    canvas.drawLine(sV2, sNew2, sidePaint);

    // Parallel extruded front edge
    final frontPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / zoomScale;
    canvas.drawLine(sNew1, sNew2, frontPaint);

    // New corner vertex dots
    final vDotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final dotRadius = 4.0 / zoomScale;
    canvas.drawCircle(sNew1, dotRadius, vDotPaint);
    canvas.drawCircle(sNew2, dotRadius, vDotPaint);

    // Existing corner dots (anchors that stay in place)
    final anchorPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawCircle(sV1, dotRadius, anchorPaint);
    canvas.drawCircle(sV2, dotRadius, anchorPaint);

    // Midpoint active grip handle with glowing ring
    final gripRadius = 5.5 / zoomScale;
    final gripPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;
    canvas.drawCircle(sMidNew, gripRadius, gripPaint);
    canvas.drawCircle(sMidNew, gripRadius + 3.0 / zoomScale, ringPaint);

    // Distance badge text
    final distText = '${d.abs().toStringAsFixed(2)} m';
    final textSpan = TextSpan(
      text: distText,
      style: TextStyle(
        color: Colors.white,
        fontSize: (11.0 / zoomScale).clamp(8.0, 16.0),
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeOffset = sMidNew + Offset(12.0 / zoomScale, -12.0 / zoomScale);
    final bgRect = Rect.fromLTWH(
      badgeOffset.dx - 4.0 / zoomScale,
      badgeOffset.dy - 2.0 / zoomScale,
      textPainter.width + 8.0 / zoomScale,
      textPainter.height + 4.0 / zoomScale,
    );
    final badgeBgPaint = Paint()
      ..color = const Color(0xCC000000)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(4.0 / zoomScale)),
      badgeBgPaint,
    );
    textPainter.paint(canvas, badgeOffset);
  }

  void _drawShearWall(Canvas canvas, StructuralShearWall wall,
      {required bool isGhost}) {
    final pts = wall.polygonVertices.map(cadToScene).toList();
    if (pts.length < 4) return;
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x4D78909C)
          : const Color(0xE637474F)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x8090A4AE)
          : const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoomScale;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Leading reference line on the left edge of the wall
    final leadingLinePaint = Paint()
      ..color = isGhost ? const Color(0x40FFFFFF) : const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;
    canvas.drawLine(cadToScene(wall.start), cadToScene(wall.end), leadingLinePaint);

    final isSelected = !isGhost && (wall.id == selectedShearWallId);
    if (isSelected) {
      final selectHalo = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawPath(path, selectHalo);

      final handlePaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final handleSize = 3.5 / zoomScale;
      for (final pt in pts) {
        canvas.drawRect(
          Rect.fromCenter(center: pt, width: handleSize * 2, height: handleSize * 2),
          handlePaint,
        );
      }
    }
  }

  void _drawColumn(Canvas canvas, StructuralColumn col,
      {required bool isGhost}) {
    final pts = col.polygonVertices.map(cadToScene).toList();
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final bool isMovingThis = movingColumn != null && movingColumn!.id == col.id;
    final bool isSelected = !isGhost && (col.id == selectedColumnId);

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x4D64B5F6)
          : isMovingThis
              ? const Color(0x331565C0)
              : const Color(0xF01565C0)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x8090CAF9)
          : isMovingThis
              ? const Color(0x66FFFFFF)
              : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Selected highlight halo & corner grip handles
    if (isSelected && !isMovingThis) {
      final selectHalo = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawPath(path, selectHalo);

      final handlePaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final handleSize = 3.5 / zoomScale;
      for (final pt in pts) {
        canvas.drawRect(
          Rect.fromCenter(center: pt, width: handleSize * 2, height: handleSize * 2),
          handlePaint,
        );
      }
    }

    // Centroid crossmark
    final crossPaint = Paint()
      ..color = isGhost
          ? const Color(0x40FFFFFF)
          : isMovingThis
              ? const Color(0x40FFFFFF)
              : const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;

    final centerScene = cadToScene(col.center);
    final double crossLen = (math.min(col.width, col.height) * cadScale * 0.25)
        .clamp(3.0 / zoomScale, 14.0 / zoomScale);
    canvas.drawLine(
      Offset(centerScene.dx - crossLen, centerScene.dy),
      Offset(centerScene.dx + crossLen, centerScene.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(centerScene.dx, centerScene.dy - crossLen),
      Offset(centerScene.dx, centerScene.dy + crossLen),
      crossPaint,
    );
  }

  void _drawInteractivePreview(Canvas canvas) {
    // 1. Moving column live preview (anchored at Top-Left)
    if (movingColumn != null && movingColumnPos != null) {
      final center = Offset(
        movingColumnPos!.dx + movingColumn!.width / 2.0,
        movingColumnPos!.dy - movingColumn!.height / 2.0,
      );
      final col = movingColumn!.copyWith(center: center);
      final pts = col.polygonVertices.map(cadToScene).toList();
      if (pts.isNotEmpty) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final movingFill = Paint()
          ..color = const Color(0x99FFB300)
          ..style = PaintingStyle.fill;
        final movingBorder = Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / zoomScale;

        canvas.drawPath(path, movingFill);
        canvas.drawPath(path, movingBorder);
      }
    }

    // 2. New column placement live preview (anchored at Top-Left)
    if (activeTool == StructuralDrawTool.column &&
        previewColumn != null &&
        previewColumnPos != null &&
        movingColumn == null) {
      // Top-Left anchor:
      // In CAD (Y up), top-left is (previewColumnPos.dx, previewColumnPos.dy),
      // so center is (previewColumnPos.dx + previewColumn.width / 2.0, previewColumnPos.dy - previewColumn.height / 2.0).
      final center = Offset(
        previewColumnPos!.dx + previewColumn!.width / 2.0,
        previewColumnPos!.dy - previewColumn!.height / 2.0,
      );
      final col = previewColumn!.copyWith(center: center);
      final pts = col.polygonVertices.map(cadToScene).toList();
      if (pts.isNotEmpty) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final previewFill = Paint()
          ..color = const Color(0x8000E5FF)
          ..style = PaintingStyle.fill;
        final previewBorder = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, previewFill);
        canvas.drawPath(path, previewBorder);
      }
    } else if (activeTool == StructuralDrawTool.shearWall &&
        wallStartPos != null &&
        currentCursorCad != null) {
      final previewWall = StructuralShearWall(
        id: 'preview',
        start: wallStartPos!,
        end: currentCursorCad!,
        thickness: 0.25,
      );
      final pts = previewWall.polygonVertices.map(cadToScene).toList();
      if (pts.length >= 4) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final pFill = Paint()
          ..color = const Color(0x66FFB300)
          ..style = PaintingStyle.fill;
        final pBorder = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, pFill);
        canvas.drawPath(path, pBorder);
        canvas.drawLine(
            cadToScene(wallStartPos!), cadToScene(currentCursorCad!), pBorder);
      }
    } else if (activeTool == StructuralDrawTool.slab) {
      if (slabStartCornerCad != null && currentCursorCad != null) {
        // Live rectangular slab preview
        final c1 = slabStartCornerCad!;
        final c2 = currentCursorCad!;
        final minX = math.min(c1.dx, c2.dx);
        final maxX = math.max(c1.dx, c2.dx);
        final minY = math.min(c1.dy, c2.dy);
        final maxY = math.max(c1.dy, c2.dy);

        final p1 = cadToScene(Offset(minX, maxY));
        final p2 = cadToScene(Offset(maxX, maxY));
        final p3 = cadToScene(Offset(maxX, minY));
        final p4 = cadToScene(Offset(minX, minY));

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();

        final slabFill = Paint()
          ..color = const Color(0x3300E5FF)
          ..style = PaintingStyle.fill;
        final slabBorder = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, slabFill);
        canvas.drawPath(path, slabBorder);

        // 4 corner dots
        final cornerDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        final rDot = 4.0 / zoomScale;
        canvas.drawCircle(p1, rDot, cornerDot);
        canvas.drawCircle(p2, rDot, cornerDot);
        canvas.drawCircle(p3, rDot, cornerDot);
        canvas.drawCircle(p4, rDot, cornerDot);

        // Midpoint dots preview
        final midDot = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.fill;
        final m1 = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final m2 = Offset((p2.dx + p3.dx) / 2, (p2.dy + p3.dy) / 2);
        final m3 = Offset((p3.dx + p4.dx) / 2, (p3.dy + p4.dy) / 2);
        final m4 = Offset((p4.dx + p1.dx) / 2, (p4.dy + p1.dy) / 2);
        canvas.drawCircle(m1, rDot, midDot);
        canvas.drawCircle(m2, rDot, midDot);
        canvas.drawCircle(m3, rDot, midDot);
        canvas.drawCircle(m4, rDot, midDot);
      } else if (slabPointsInProgress.isNotEmpty) {
        final slabPaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        final pts = slabPointsInProgress.map(cadToScene).toList();
        for (int i = 0; i < pts.length - 1; i++) {
          canvas.drawLine(pts[i], pts[i + 1], slabPaint);
        }
        if (currentCursorCad != null) {
          canvas.drawLine(pts.last, cadToScene(currentCursorCad!), slabPaint);
        }

        final vDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        for (final p in pts) {
          canvas.drawCircle(p, 4.0 / zoomScale, vDot);
        }
      }
    }
  }

  void _drawCantileverOverlays(Canvas canvas) {
    for (final zone in cantileverZones) {
      final Color color = zone.riskLevel.color;
      final Color fill = zone.riskLevel.fillColor;

      final s = cadToScene(zone.supportEdgeStart);
      final e = cadToScene(zone.supportEdgeEnd);
      final tip = cadToScene(zone.overhangTip);

      // Draw overhang span line from support to tip
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;

      canvas.drawLine(s, tip, linePaint);

      // Tip indicator
      final tipPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tip, 6.0 / zoomScale, tipPaint);

      if (zone.isCorner) {
        // Draw corner triangle
        final cornerPath = Path()
          ..moveTo(s.dx, s.dy)
          ..lineTo(e.dx, e.dy)
          ..lineTo(tip.dx, tip.dy)
          ..close();

        final cornerFill = Paint()
          ..color = fill
          ..style = PaintingStyle.fill;
        canvas.drawPath(cornerPath, cornerFill);

        // Corner warning badge
        final cornerRing = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;
        canvas.drawCircle(tip, 10.0 / zoomScale, cornerRing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Structural2dPainter oldDelegate) {
    return true;
  }
}
