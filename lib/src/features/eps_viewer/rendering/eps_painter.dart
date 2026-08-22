import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/eps_models.dart';

/// CustomPainter that renders EPS Vector Paths with PostScript coordinate inversion and rotation.
class EpsPainter extends CustomPainter {
  final EpsDocument document;
  final EpsCanvasTheme theme;
  final bool showGrid;
  final int rotationQuarterTurns; // 0, 1, 2, 3 (0°, 90°, 180°, 270°)
  final bool flipHorizontal;
  final bool flipVertical;

  const EpsPainter({
    required this.document,
    required this.theme,
    this.showGrid = true,
    this.rotationQuarterTurns = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = document.metadata.boundingBox;
    final double rawW = bounds.width > 0 ? bounds.width : size.width;
    final double rawH = bounds.height > 0 ? bounds.height : size.height;

    final isRotated90or270 = rotationQuarterTurns % 2 != 0;
    final double docW = isRotated90or270 ? rawH : rawW;
    final double docH = isRotated90or270 ? rawW : rawH;

    // Draw Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, docW, docH),
      Paint()..color = theme.background,
    );

    // Draw CAD Grid
    if (showGrid) {
      _drawGrid(canvas, docW, docH);
    }

    canvas.save();
    // Apply rotation & flip transformation around center if specified
    if (rotationQuarterTurns != 0 || flipHorizontal || flipVertical) {
      canvas.translate(docW / 2, docH / 2);
      if (rotationQuarterTurns != 0) {
        canvas.rotate(rotationQuarterTurns * math.pi / 2);
      }
      if (flipHorizontal) canvas.scale(-1, 1);
      if (flipVertical) canvas.scale(1, -1);
      canvas.translate(-rawW / 2, -rawH / 2);
    }

    // PostScript coordinate mapper:
    // px -> px - minX
    // py -> maxY - py (flip Y-axis)
    Offset mapPoint(Offset psPt) {
      final x = psPt.dx - bounds.minX;
      final y = bounds.maxY - psPt.dy;
      return Offset(x, y);
    }

    // Draw Paths
    for (final epsPath in document.paths) {
      final path = Path();
      bool hasMove = false;

      for (final cmd in epsPath.commands) {
        switch (cmd.type) {
          case EpsCommandType.moveTo:
            final pt = mapPoint(cmd.p1);
            path.moveTo(pt.dx, pt.dy);
            hasMove = true;
            break;

          case EpsCommandType.lineTo:
            final pt = mapPoint(cmd.p1);
            if (!hasMove) {
              path.moveTo(pt.dx, pt.dy);
              hasMove = true;
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
            break;

          case EpsCommandType.cubicCurveTo:
            final p1 = mapPoint(cmd.p1);
            final p2 = mapPoint(cmd.p2!);
            final p3 = mapPoint(cmd.p3!);
            if (!hasMove) {
              path.moveTo(p1.dx, p1.dy);
              hasMove = true;
            }
            path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
            break;

          case EpsCommandType.closePath:
            path.close();
            break;
        }
      }

      // 1. Fill
      if (epsPath.fillColor != null) {
        final fillPaint = Paint()
          ..color = _adaptColorForTheme(epsPath.fillColor!, theme)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);
      }

      // 2. Stroke
      if (epsPath.strokeColor != null) {
        final strokePaint = Paint()
          ..color = _adaptColorForTheme(epsPath.strokeColor!, theme)
          ..strokeWidth = math.max(0.75, epsPath.strokeWidth)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, strokePaint);
      }
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, double w, double h) {
    final gridPaint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 0.5;

    const double step = 36.0; // 0.5 inch in points

    for (double x = 0; x <= w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y <= h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  Color _adaptColorForTheme(Color color, EpsCanvasTheme theme) {
    if (theme.isDark && color.computeLuminance() < 0.08) {
      return Colors.white70;
    }
    if (!theme.isDark && color.computeLuminance() > 0.92) {
      return Colors.black87;
    }
    return color;
  }

  @override
  bool shouldRepaint(covariant EpsPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.rotationQuarterTurns != rotationQuarterTurns ||
        oldDelegate.flipHorizontal != flipHorizontal ||
        oldDelegate.flipVertical != flipVertical;
  }
}
