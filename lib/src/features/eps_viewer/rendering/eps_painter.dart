import 'package:flutter/material.dart';
import '../models/eps_models.dart';

/// CustomPainter that renders EPS Vector Paths with PostScript coordinate inversion.
class EpsPainter extends CustomPainter {
  final EpsDocument document;
  final EpsCanvasTheme theme;
  final bool showGrid;

  const EpsPainter({
    required this.document,
    required this.theme,
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = document.metadata.boundingBox;
    final double docW = bounds.width > 0 ? bounds.width : size.width;
    final double docH = bounds.height > 0 ? bounds.height : size.height;

    // Draw Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, docW, docH),
      Paint()..color = theme.background,
    );

    // Draw CAD Grid
    if (showGrid) {
      _drawGrid(canvas, docW, docH);
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
          ..strokeWidth = mathMax(0.75, epsPath.strokeWidth)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, strokePaint);
      }
    }
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
    // If black on dark background, brighten to white/light-grey
    if (theme.isDark && color.computeLuminance() < 0.08) {
      return Colors.white70;
    }
    // If white on light background, darken to dark-grey/black
    if (!theme.isDark && color.computeLuminance() > 0.92) {
      return Colors.black87;
    }
    return color;
  }

  double mathMax(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant EpsPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid;
  }
}
