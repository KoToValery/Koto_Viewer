import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../rendering/architect_canvas_palette.dart';
import '../services/architect_drag_controller.dart';

/// Renders the visual feedback for the interactive Drag (Влачене) tool:
/// 1. In [pickingBasePoint]:
///    - Offset leader line with touch grip point ("изнесена линия с точка").
///    - Hover snap indicator & badge on the selected element.
/// 2. In [draggingToTarget]:
///    - Gold/amber anchor marker at the locked base point.
///    - Cyan/green rubber-band displacement line.
///    - Snapped/free target ring with pulse glow and snap label badge.
///    - Real-time length & angle badge (`L=...m  ...°`).
///    - Magnetic alignment guide lines.
class ArchitectDragPainterHelper {
  static void drawDragInteraction({
    required Canvas canvas,
    required ArchitectDragController dragController,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    String? Function(String)? localizeSnap,
  }) {
    if (dragController.isIdle) return;

    final draftingScale = math.max(zoomScale, 80.0);

    // -------------------------------------------------------------
    // PHASE 1: PICKING BASE POINT
    // -------------------------------------------------------------
    if (dragController.isPickingBasePoint) {
      // 1. Draw default offset leader handle if present
      final anchor = dragController.defaultHandleAnchor;
      final grip = dragController.defaultHandleGrip;
      if (anchor != null && grip != null) {
        final bgLeader = Paint()
          ..color = const Color(0x66000000)
          ..strokeWidth = 2.6 / draftingScale
          ..style = PaintingStyle.stroke;
        final leader = Paint()
          ..color = const Color(0xFFFFB300)
          ..strokeWidth = 1.6 / draftingScale
          ..style = PaintingStyle.stroke;

        canvas.drawLine(anchor, grip, bgLeader);
        canvas.drawLine(anchor, grip, leader);

        // Center dot on element anchor
        canvas.drawCircle(
          anchor,
          3.5 / draftingScale,
          Paint()..color = const Color(0xFFFFB300),
        );

        // Touch grip dot
        _drawTouchGrip(canvas, grip, draftingScale, const Color(0xFFFFB300));
      }

      // 2. Draw hover snap point on element if hovering near snap
      if (dragController.isSnapped && dragController.currentPointModel != null) {
        final pt = dragController.currentPointModel!;
        final ringPaint = Paint()
          ..color = const Color(0xFF00E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / draftingScale;
        final glowPaint = Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(pt, 9.0 / draftingScale, glowPaint);
        canvas.drawCircle(pt, 9.0 / draftingScale, ringPaint);
        canvas.drawCircle(pt, 2.5 / draftingScale, Paint()..color = Colors.white);

        final label = dragController.currentSnapLabel != null && localizeSnap != null
            ? localizeSnap(dragController.currentSnapLabel!) ?? dragController.currentSnapLabel!
            : dragController.currentSnapLabel;
        if (label != null) {
          _drawBadge(canvas, pt, label, const Color(0xFF00E676), zoomScale);
        }
      }
      return;
    }

    // -------------------------------------------------------------
    // PHASE 2: DRAGGING TO TARGET
    // -------------------------------------------------------------
    if (dragController.isDraggingToTarget &&
        dragController.basePointModel != null &&
        dragController.currentPointModel != null) {
      final base = dragController.basePointModel!;
      final target = dragController.currentPointModel!;

      // 1. Draw magnetic alignment guide lines
      if (dragController.magneticGuides.isNotEmpty) {
        final guidePaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 / draftingScale;
        for (final guide in dragController.magneticGuides) {
          _drawDashedLine(canvas, guide.$1, guide.$2, guidePaint, 6.0 / zoomScale, 4.0 / zoomScale);
        }
      }

      // 2. Rubber-band leader line
      final rubberBandPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;
      canvas.drawLine(base, target, rubberBandPaint);

      // 3. Anchor marker at base point (amber gold)
      final anchorOuter = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / zoomScale;
      final anchorFill = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(base, 8.0 / zoomScale, anchorFill);
      canvas.drawCircle(base, 8.0 / zoomScale, anchorOuter);
      canvas.drawCircle(base, 2.5 / zoomScale, Paint()..color = Colors.white);

      // 4. Target marker (green if snapped, cyan if free)
      final isSnapped = dragController.isSnapped;
      final targetRing = Paint()
        ..color = isSnapped ? const Color(0xFF00E676) : const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / zoomScale;
      final targetGlow = Paint()
        ..color = (isSnapped ? const Color(0xFF00E676) : const Color(0xFF00E5FF))
            .withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, 10.0 / zoomScale, targetGlow);
      canvas.drawCircle(target, 10.0 / zoomScale, targetRing);
      canvas.drawCircle(target, 2.5 / zoomScale, Paint()..color = Colors.white);

      // 5. Target snap label badge
      if (isSnapped && dragController.currentSnapLabel != null) {
        final label = localizeSnap != null
            ? localizeSnap(dragController.currentSnapLabel!) ?? dragController.currentSnapLabel!
            : dragController.currentSnapLabel!;
        _drawBadge(canvas, target, label, const Color(0xFF00E676), zoomScale);
      }

      // 6. Dimension & angle badge at midpoint of rubber-band line
      final mid = Offset((base.dx + target.dx) / 2, (base.dy + target.dy) / 2);
      final dist = dragController.distanceMeters;
      final deg = dragController.angleDeg;
      final distText = 'L=${dist.toStringAsFixed(2)}m  ${deg.toStringAsFixed(0)}°';
      _drawBadge(canvas, mid, distText, const Color(0xFFFFB300), zoomScale);
    }
  }

  static void _drawTouchGrip(
    Canvas canvas,
    Offset handle,
    double draftingScale,
    Color color,
  ) {
    canvas.drawCircle(
      handle,
      6.0 / draftingScale,
      Paint()..color = const Color(0xFF1E1E26),
    );
    canvas.drawCircle(
      handle,
      6.0 / draftingScale,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 / draftingScale,
    );
    canvas.drawCircle(handle, 2.5 / draftingScale, Paint()..color = color);
  }

  static void _drawBadge(
    Canvas canvas,
    Offset modelPoint,
    String text,
    Color accentColor,
    double scale,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 5.0 / scale;
    final padV = 3.0 / scale;
    final bw = tp.width / scale + padH * 2;
    final bh = tp.height / scale + padV * 2;
    final badgeRect = Rect.fromLTWH(
      modelPoint.dx - bw / 2,
      modelPoint.dy - bh - 12.0 / scale,
      bw,
      bh,
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF1E242C).withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    final rrect = RRect.fromRectAndRadius(badgeRect, Radius.circular(3.0 / scale));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    canvas.save();
    canvas.translate(badgeRect.left + padH, badgeRect.top + padV);
    canvas.scale(1.0 / scale);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return;
    final double ux = dx / dist;
    final double uy = dy / dist;
    double current = 0.0;
    while (current < dist) {
      final double seg = math.min(dashWidth, dist - current);
      canvas.drawLine(
        Offset(p1.dx + ux * current, p1.dy + uy * current),
        Offset(p1.dx + ux * (current + seg), p1.dy + uy * (current + seg)),
        paint,
      );
      current += dashWidth + dashSpace;
    }
  }
}
