import 'package:flutter/material.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import 'structural_pointer_painter.dart';

/// 2D CustomPainter that renders structural elements, ghost storeys (ArchiCAD Trace Reference),
/// interactive drawing previews, and cantilever warning zones in CAD coordinates.
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
  final List<Offset> slabPointsInProgress;
  final double zoomScale;

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
    this.slabPointsInProgress = const [],
    this.zoomScale = 1.0,
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

    final path = Path();
    path.moveTo(slab.polygon.first.dx, slab.polygon.first.dy);
    for (int i = 1; i < slab.polygon.length; i++) {
      path.lineTo(slab.polygon[i].dx, slab.polygon[i].dy);
    }
    path.close();

    // Subtract openings
    for (final op in slab.openings) {
      if (op.length >= 3) {
        final opPath = Path();
        opPath.moveTo(op.first.dx, op.first.dy);
        for (int i = 1; i < op.length; i++) {
          opPath.lineTo(op[i].dx, op[i].dy);
        }
        opPath.close();
        path.addPath(opPath, Offset.zero);
      }
    }

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x1A90CAF9)
          : const Color(0x2803A9F4)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x6664B5F6)
          : const Color(0xFF0288D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isGhost ? (1.0 / zoomScale) : (2.0 / zoomScale);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawShearWall(Canvas canvas, StructuralShearWall wall,
      {required bool isGhost}) {
    final pts = wall.polygonVertices;
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

    // Centerline
    final centerLinePaint = Paint()
      ..color = isGhost ? const Color(0x40FFFFFF) : const Color(0x99FFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    canvas.drawLine(wall.start, wall.end, centerLinePaint);
  }

  void _drawColumn(Canvas canvas, StructuralColumn col,
      {required bool isGhost}) {
    final pts = col.polygonVertices;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x4D64B5F6)
          : const Color(0xF01565C0)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x8090CAF9)
          : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoomScale;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Centroid crossmark
    final crossPaint = Paint()
      ..color = isGhost ? const Color(0x40FFFFFF) : const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / zoomScale;

    const double s = 0.08;
    canvas.drawLine(
      Offset(col.center.dx - s, col.center.dy),
      Offset(col.center.dx + s, col.center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(col.center.dx, col.center.dy - s),
      Offset(col.center.dx, col.center.dy + s),
      crossPaint,
    );
  }

  void _drawInteractivePreview(Canvas canvas) {
    if (activeTool == StructuralDrawTool.column &&
        previewColumn != null &&
        previewColumnPos != null) {
      final col = previewColumn!.copyWith(center: previewColumnPos!);
      final pts = col.polygonVertices;
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
    } else if (activeTool == StructuralDrawTool.shearWall &&
        wallStartPos != null &&
        currentCursorCad != null) {
      final previewWall = StructuralShearWall(
        id: 'preview',
        start: wallStartPos!,
        end: currentCursorCad!,
        thickness: 0.25,
      );
      final pts = previewWall.polygonVertices;
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
      canvas.drawLine(wallStartPos!, currentCursorCad!, pBorder);
    } else if (activeTool == StructuralDrawTool.slab &&
        slabPointsInProgress.isNotEmpty) {
      final slabPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;

      for (int i = 0; i < slabPointsInProgress.length - 1; i++) {
        canvas.drawLine(
            slabPointsInProgress[i], slabPointsInProgress[i + 1], slabPaint);
      }
      if (currentCursorCad != null) {
        canvas.drawLine(
            slabPointsInProgress.last, currentCursorCad!, slabPaint);
      }

      // Vertex markers
      final vDot = Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.fill;
      for (final p in slabPointsInProgress) {
        canvas.drawCircle(p, 4.0 / zoomScale, vDot);
      }
    }
  }

  void _drawCantileverOverlays(Canvas canvas) {
    for (final zone in cantileverZones) {
      final Color color = zone.riskLevel.color;
      final Color fill = zone.riskLevel.fillColor;

      // Draw overhang span line from support to tip
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;

      canvas.drawLine(zone.supportEdgeStart, zone.overhangTip, linePaint);

      // Tip indicator
      final tipPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(zone.overhangTip, 6.0 / zoomScale, tipPaint);

      if (zone.isCorner) {
        // Draw corner triangle
        final cornerPath = Path()
          ..moveTo(zone.supportEdgeStart.dx, zone.supportEdgeStart.dy)
          ..lineTo(zone.supportEdgeEnd.dx, zone.supportEdgeEnd.dy)
          ..lineTo(zone.overhangTip.dx, zone.overhangTip.dy)
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
        canvas.drawCircle(zone.overhangTip, 10.0 / zoomScale, cornerRing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant Structural2dPainter oldDelegate) {
    return true;
  }
}
