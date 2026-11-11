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
///    - Small snapped/free target ring.
///    - One lightweight badge for distance, angle, and snap feedback.
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
      if (dragController.isSnapped &&
          dragController.currentPointModel != null) {
        final pt = dragController.currentPointModel!;
        final ringPaint = Paint()
          ..color = const Color(0xFF00E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / draftingScale;
        final glowPaint = Paint()
          ..color = const Color(0xFF00E676).withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(pt, 9.0 / draftingScale, glowPaint);
        canvas.drawCircle(pt, 9.0 / draftingScale, ringPaint);
        canvas.drawCircle(
          pt,
          2.5 / draftingScale,
          Paint()..color = Colors.white,
        );

        final label =
            dragController.currentSnapLabel != null && localizeSnap != null
            ? localizeSnap(dragController.currentSnapLabel!) ??
                  dragController.currentSnapLabel!
            : dragController.currentSnapLabel;
        if (label != null && dragController.currentSnapLabel != 'Grip') {
          _drawBadge(canvas, pt, label, zoomScale, palette);
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
          _drawDashedLine(
            canvas,
            guide.$1,
            guide.$2,
            guidePaint,
            6.0 / zoomScale,
            4.0 / zoomScale,
          );
        }
      }

      // 2. Rubber-band leader line
      final rubberBandPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / zoomScale;
      canvas.drawLine(base, target, rubberBandPaint);

      // 3. Anchor marker at base point (amber gold)
      final anchorOuter = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / zoomScale;
      final anchorFill = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(base, 6.0 / zoomScale, anchorFill);
      canvas.drawCircle(base, 6.0 / zoomScale, anchorOuter);
      canvas.drawCircle(base, 2.5 / zoomScale, Paint()..color = Colors.white);

      // 4. Target marker (green if snapped, cyan if free)
      final isSnapped = dragController.isSnapped;
      final targetRing = Paint()
        ..color = isSnapped ? const Color(0xFF279A83) : const Color(0xFF399AA7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / zoomScale;
      final targetGlow = Paint()
        ..color =
            (isSnapped ? const Color(0xFF00E676) : const Color(0xFF00E5FF))
                .withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(target, 7.0 / zoomScale, targetGlow);
      canvas.drawCircle(target, 7.0 / zoomScale, targetRing);
      canvas.drawCircle(target, 2.5 / zoomScale, Paint()..color = Colors.white);

      // One badge prevents snap text and the displacement from overlapping on
      // short moves. Angular snap values already appear in the measurement.
      final dist = dragController.distanceMeters;
      final showDistance = dist * zoomScale > 3;
      final angle = '${dragController.angleDeg.toStringAsFixed(0)}°';
      final rawSnap = isSnapped ? dragController.currentSnapLabel : null;
      final parts = <String>[
        if (showDistance) ...['${dist.toStringAsFixed(2)} m', angle],
        if (rawSnap != null && (!showDistance || rawSnap != angle))
          localizeSnap?.call(rawSnap) ?? rawSnap,
      ];
      if (parts.isNotEmpty) {
        _drawBadge(
          canvas,
          showDistance ? (base + target) / 2 : target,
          parts.join(' · '),
          zoomScale,
          palette,
          beside:
              showDistance &&
              (target - base).dy.abs() > (target - base).dx.abs(),
        );
      }
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
      Paint()..color = const Color(0xF7FFFFFF),
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
    double scale,
    ArchitectCanvasPalette palette, {
    bool beside = false,
  }) {
    final safe = canvas.getLocalClipBounds().deflate(4 / scale);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: palette.isDark
              ? const Color(0xFFEDF2F4)
              : const Color(0xFF34424C),
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, math.min(240, safe.width * scale - 14)));

    final padH = 7.0 / scale;
    final padV = 4.0 / scale;
    final bw = tp.width / scale + padH * 2;
    final bh = tp.height / scale + padV * 2;
    var proposed = Rect.fromLTWH(
      beside ? modelPoint.dx + 12 / scale : modelPoint.dx - bw / 2,
      beside ? modelPoint.dy - bh / 2 : modelPoint.dy - bh - 12 / scale,
      bw,
      bh,
    );
    if (beside && proposed.right > safe.right) {
      proposed = proposed.shift(Offset(-bw - 24 / scale, 0));
    }
    final badgeRect = Rect.fromLTWH(
      proposed.left.clamp(safe.left, math.max(safe.left, safe.right - bw)),
      proposed.top.clamp(safe.top, math.max(safe.top, safe.bottom - bh)),
      bw,
      bh,
    );

    final bgPaint = Paint()
      ..color = palette.isDark
          ? const Color(0xF0272F36)
          : const Color(0xF8FFFFFF)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = palette.isDark
          ? const Color(0xFF52606A)
          : const Color(0xFFD8E0E4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 / scale;

    final rrect = RRect.fromRectAndRadius(
      badgeRect,
      Radius.circular(5.0 / scale),
    );
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
