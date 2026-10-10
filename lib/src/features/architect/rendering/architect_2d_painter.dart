import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import 'architect_zone_painter_helper.dart';

enum ArchitectTool {
  select,
  zone,
  wall,
  door,
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawDraftingGrid(canvas, size);
    _drawGridAxes(canvas);
    _drawZones(canvas);
    _drawWalls(canvas);
    _drawActiveDrafting(canvas);
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
    );
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
    if (project.gridAxes.isEmpty) return;

    final axisLinePaint = Paint()
      ..color = const Color(0xFFC62828).withValues(alpha: 0.75)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    final bubbleBg = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;

    final bubbleBorder = Paint()
      ..color = const Color(0xFFC62828)
      ..strokeWidth = 1.2 / zoomScale
      ..style = PaintingStyle.stroke;

    final double bubbleR = 12.0 / zoomScale;

    for (final axis in project.gridAxes) {
      // Dash-dot architectural axis line
      _drawDashDotLine(canvas, axis.start, axis.end, axisLinePaint);

      // Bubble helper
      void drawBubble(Offset center) {
        canvas.drawCircle(center, bubbleR, bubbleBg);
        canvas.drawCircle(center, bubbleR, bubbleBorder);

        final tp = TextPainter(
          text: TextSpan(
            text: axis.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5 / zoomScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }

      if (axis.bubbleAtStart) drawBubble(axis.start);
      if (axis.bubbleAtEnd) drawBubble(axis.end);
    }
  }

  void _drawDashDotLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final d = p2 - p1;
    final total = d.distance;
    if (total < 1e-4) return;
    final u = d / total;

    final dash = 12.0 / zoomScale;
    final gap = 4.0 / zoomScale;
    final dot = 2.0 / zoomScale;

    double cur = 0;
    while (cur < total) {
      final segEnd = (cur + dash).clamp(0.0, total);
      canvas.drawLine(p1 + u * cur, p1 + u * segEnd, paint);
      cur += dash + gap;
      if (cur >= total) break;
      final dotEnd = (cur + dot).clamp(0.0, total);
      canvas.drawLine(p1 + u * cur, p1 + u * dotEnd, paint);
      cur += dot + gap;
    }
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
