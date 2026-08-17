import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// CustomPainter for Gerber RS-274X and Excellon Drill files with PCB substrate rendering.
class PcbPainter extends CustomPainter {
  final PcbDocument document;
  final PcbTheme theme;
  final bool showGrid;
  final double scaleFactor;

  const PcbPainter({
    required this.document,
    required this.theme,
    this.showGrid = true,
    this.scaleFactor = 10.0, // 1 mm = 10 canvas pixels
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = document.boundingBox;
    const margin = 20.0;

    final double boardW = bounds.widthMm * scaleFactor;
    final double boardH = bounds.heightMm * scaleFactor;

    // 1. Draw PCB Substrate Board with realistic rounded edge
    final boardRect = Rect.fromLTWH(margin, margin, boardW, boardH);
    final substratePaint = Paint()
      ..color = theme.substrate
      ..style = PaintingStyle.fill;
    final boardRRect = RRect.fromRectAndRadius(boardRect, const Radius.circular(6));
    canvas.drawRRect(boardRRect, substratePaint);

    // Board outline stroke
    final boardOutlinePaint = Paint()
      ..color = theme.outline.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(boardRRect, boardOutlinePaint);

    // 2. Draw Measurement Grid
    if (showGrid) {
      _drawGrid(canvas, boardRect, scaleFactor);
    }

    // Coordinate mapping function: (x_mm, y_mm) -> (canvas_x, canvas_y)
    Offset mapPoint(Offset p) {
      final x = margin + (p.dx - bounds.minX) * scaleFactor;
      final y = margin + (bounds.maxY - p.dy) * scaleFactor; // Invert Y
      return Offset(x, y);
    }

    final activeColor = _resolveLayerColor(document.layerType, theme);

    // 3. Draw Gerber Elements (Tracks, Arcs, Pads, Regions)
    for (final cmd in document.commands) {
      if (!cmd.isDark) continue;

      switch (cmd.type) {
        // Line Track
        case PcbCommandType.line:
          final p1 = mapPoint(cmd.p1);
          final p2 = mapPoint(cmd.p2!);
          final widthPx = math.max(1.0, (cmd.aperture?.dimX ?? 0.2) * scaleFactor);

          final trackPaint = Paint()
            ..color = activeColor
            ..strokeWidth = widthPx
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1, p2, trackPaint);
          break;

        // Circular Arc Track
        case PcbCommandType.arc:
          final center = mapPoint(cmd.center!);
          final radPx = (cmd.radius ?? 1.0) * scaleFactor;
          final widthPx = math.max(1.0, (cmd.aperture?.dimX ?? 0.2) * scaleFactor);

          final arcPaint = Paint()
            ..color = activeColor
            ..strokeWidth = widthPx
            ..style = PaintingStyle.stroke;

          final sweep = cmd.endAngle! - cmd.startAngle!;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radPx),
            -cmd.startAngle!, // Invert for screen space
            -sweep,
            false,
            arcPaint,
          );
          break;

        // Flash Pad
        case PcbCommandType.flash:
          final pos = mapPoint(cmd.p1);
          final ap = cmd.aperture;
          final apType = ap?.type ?? PcbApertureType.circle;

          final padPaint = Paint()
            ..color = activeColor
            ..style = PaintingStyle.fill;

          if (apType == PcbApertureType.circle) {
            final radiusPx = ((ap?.dimX ?? 1.0) / 2.0) * scaleFactor;
            canvas.drawCircle(pos, math.max(1.5, radiusPx), padPaint);
          } else if (apType == PcbApertureType.rectangle) {
            final wPx = (ap?.dimX ?? 1.0) * scaleFactor;
            final hPx = (ap?.dimY ?? 1.0) * scaleFactor;
            canvas.drawRect(
              Rect.fromCenter(center: pos, width: wPx, height: hPx),
              padPaint,
            );
          } else if (apType == PcbApertureType.obround) {
            final wPx = (ap?.dimX ?? 1.5) * scaleFactor;
            final hPx = (ap?.dimY ?? 1.0) * scaleFactor;
            final r = math.min(wPx, hPx) / 2.0;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: pos, width: wPx, height: hPx),
                Radius.circular(r),
              ),
              padPaint,
            );
          } else {
            final radiusPx = ((ap?.dimX ?? 1.0) / 2.0) * scaleFactor;
            canvas.drawCircle(pos, math.max(1.5, radiusPx), padPaint);
          }
          break;

        // Copper Pour / Polygon Region
        case PcbCommandType.region:
          if (cmd.regionPoints != null && cmd.regionPoints!.length >= 3) {
            final path = Path();
            final first = mapPoint(cmd.regionPoints!.first);
            path.moveTo(first.dx, first.dy);
            for (int i = 1; i < cmd.regionPoints!.length; i++) {
              final pt = mapPoint(cmd.regionPoints![i]);
              path.lineTo(pt.dx, pt.dy);
            }
            path.close();

            final regionPaint = Paint()
              ..color = activeColor.withValues(alpha: 0.88)
              ..style = PaintingStyle.fill;
            canvas.drawPath(path, regionPaint);
          }
          break;
      }
    }

    // 4. Draw Drill Holes
    for (final hole in document.drillHoles) {
      final pos = mapPoint(hole.position);
      final radiusPx = (hole.diameterMm / 2.0) * scaleFactor;

      // Annular copper ring around hole
      final ringPaint = Paint()
        ..color = theme.copper
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, 0.4 * scaleFactor);
      canvas.drawCircle(pos, radiusPx + (0.2 * scaleFactor), ringPaint);

      // Dark drilled hole center
      final holePaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, math.max(1.0, radiusPx), holePaint);
    }
  }

  void _drawGrid(Canvas canvas, Rect boardRect, double scale) {
    final minorGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    final majorGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;

    final step1mm = 1.0 * scale; // 1mm grid
    final step10mm = 10.0 * scale; // 10mm grid

    // Minor lines (1 mm)
    for (double x = boardRect.left; x <= boardRect.right; x += step1mm) {
      canvas.drawLine(Offset(x, boardRect.top), Offset(x, boardRect.bottom), minorGridPaint);
    }
    for (double y = boardRect.top; y <= boardRect.bottom; y += step1mm) {
      canvas.drawLine(Offset(boardRect.left, y), Offset(boardRect.right, y), minorGridPaint);
    }

    // Major lines (10 mm)
    for (double x = boardRect.left; x <= boardRect.right; x += step10mm) {
      canvas.drawLine(Offset(x, boardRect.top), Offset(x, boardRect.bottom), majorGridPaint);
    }
    for (double y = boardRect.top; y <= boardRect.bottom; y += step10mm) {
      canvas.drawLine(Offset(boardRect.left, y), Offset(boardRect.right, y), majorGridPaint);
    }
  }

  Color _resolveLayerColor(PcbLayerType layerType, PcbTheme theme) {
    switch (layerType) {
      case PcbLayerType.copperTop:
      case PcbLayerType.copperBottom:
        return theme.copper;
      case PcbLayerType.solderMaskTop:
      case PcbLayerType.solderMaskBottom:
        return theme.mask;
      case PcbLayerType.silkscreenTop:
      case PcbLayerType.silkscreenBottom:
        return theme.silk;
      case PcbLayerType.edgeCuts:
        return theme.outline;
      case PcbLayerType.drill:
        return theme.copper;
      case PcbLayerType.generic:
        return theme.copper;
    }
  }

  @override
  bool shouldRepaint(covariant PcbPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.scaleFactor != scaleFactor;
  }
}
