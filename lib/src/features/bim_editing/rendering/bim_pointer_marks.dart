import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BimSnapGlyph {
  endpoint,
  intersection,
  midpoint,
  center,
  nearest,
  perpendicular,
  point,
}

/// Screen-space marks are shared; native adapters supply transformed geometry
/// and localized dimension text. Navigation never alters model coordinates.
class BimPointerMarks {
  static void touchAndStem(
    Canvas canvas,
    Offset touchPos,
    Offset effectiveTip,
    Color themeColor,
  ) {
    // 1. Touch Anchor Circle directly beneath user's finger
    final touchFill = Paint()
      ..color = themeColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final touchBorder = Paint()
      ..color = themeColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final touchDot = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(touchPos, 18, touchFill);
    canvas.drawCircle(touchPos, 18, touchBorder);
    canvas.drawCircle(touchPos, 3.5, touchDot);

    // One reference point connects the finger, ghost and committed geometry.
    final guideConnectionPoint = effectiveTip;

    final stemPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final delta = guideConnectionPoint - touchPos;
    final dist = delta.distance;
    if (dist > 18.0) {
      final startPt = touchPos + delta * (18.0 / dist);
      final stemPath = Path()
        ..moveTo(startPt.dx, startPt.dy)
        ..lineTo(guideConnectionPoint.dx, guideConnectionPoint.dy);
      canvas.drawPath(stemPath, stemPaint);
    }

    // Subtle precision crosshair at the offset aim point
    final crossPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawLine(
      guideConnectionPoint.translate(-9, 0),
      guideConnectionPoint.translate(9, 0),
      crossPaint,
    );
    canvas.drawLine(
      guideConnectionPoint.translate(0, -9),
      guideConnectionPoint.translate(0, 9),
      crossPaint,
    );

    // Aim point / dot directly in front of the selection line
    canvas.drawCircle(
      guideConnectionPoint,
      4.0,
      Paint()..color = themeColor,
    );
    canvas.drawCircle(
      guideConnectionPoint,
      4.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  /// Unified offset leader handle: element target point, connecting leader stem,
  /// and outward touch grip ending with an inner/outer circle and central dot.
  static void offsetLeaderHandle(
    Canvas canvas,
    Offset elementPoint,
    Offset handlePoint,
    Color color, {
    double scale = 1.0,
    bool isScreenSpace = false,
  }) {
    final s = isScreenSpace ? 1.0 : scale;
    final strokeW = 1.2 / s;
    final stemPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke;

    // Leader line connecting element point to touch handle
    canvas.drawLine(elementPoint, handlePoint, stemPaint);

    // Target point on the element
    canvas.drawCircle(elementPoint, 3.5 / s, Paint()..color = color);

    // Outer touch grip circle
    canvas.drawCircle(
      handlePoint,
      6.0 / s,
      Paint()..color = const Color(0xFF1E1E26),
    );
    canvas.drawCircle(
      handlePoint,
      6.0 / s,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / s,
    );
    // Center dot in handle
    canvas.drawCircle(handlePoint, 2.5 / s, Paint()..color = color);
  }

  static void ghost(Canvas canvas, List<Offset> polygon, Color color) {
    final path = Path()..addPolygon(polygon, true);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .22));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  static void snap(
    Canvas canvas,
    Offset pos,
    BimSnapGlyph type,
    Color color, {
    double strokeWidth = 2.0,
    bool measurementParallel = false,
  }) {
    final snapPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    const double s = 8.0;
    switch (type) {
      case BimSnapGlyph.intersection:
        canvas.drawLine(
          pos - const Offset(7, 7),
          pos + const Offset(7, 7),
          snapPaint,
        );
        canvas.drawLine(
          pos - const Offset(7, -7),
          pos + const Offset(7, -7),
          snapPaint,
        );
        break;
      case BimSnapGlyph.endpoint:
        canvas.drawRect(
          Rect.fromCenter(center: pos, width: s * 2, height: s * 2),
          snapPaint,
        );
        break;
      case BimSnapGlyph.midpoint:
        final path = Path()
          ..moveTo(pos.dx, pos.dy - s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..lineTo(pos.dx - s, pos.dy + s)
          ..close();
        canvas.drawPath(path, snapPaint);
        break;
      case BimSnapGlyph.center:
        canvas.drawCircle(pos, s, snapPaint);
        break;
      case BimSnapGlyph.nearest:
        // Hourglass shape
        final path = Path()
          ..moveTo(pos.dx - s, pos.dy - s)
          ..lineTo(pos.dx + s, pos.dy - s)
          ..lineTo(pos.dx - s, pos.dy + s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..close();
        canvas.drawPath(path, snapPaint);
        break;
      case BimSnapGlyph.perpendicular:
        if (measurementParallel) {
          canvas.drawLine(
            pos + const Offset(-5, 7),
            pos + const Offset(1, -7),
            snapPaint,
          );
          canvas.drawLine(
            pos + const Offset(1, 7),
            pos + const Offset(7, -7),
            snapPaint,
          );
        } else {
          final perpPaint = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          const double sp = 4.5;
          canvas.drawPath(
            Path()
              ..moveTo(pos.dx - sp, pos.dy - sp)
              ..lineTo(pos.dx - sp, pos.dy + sp)
              ..lineTo(pos.dx + sp, pos.dy + sp)
              ..moveTo(pos.dx - sp, pos.dy)
              ..lineTo(pos.dx, pos.dy)
              ..lineTo(pos.dx, pos.dy + sp),
            perpPaint,
          );
        }
        break;
      default:
        canvas.drawCircle(pos, s, snapPaint);
    }
  }

  static void dimension(
    Canvas canvas,
    Offset p1,
    Offset p2,
    String text, {
    Offset? badgeCenter,
    Size? viewport,
  }) {
    final mid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    Offset offsetMid = mid;
    if (len > 1e-4) {
      final nx = -dy / len * 22.0;
      final ny = dx / len * 22.0;
      offsetMid = Offset(mid.dx + nx, mid.dy + ny);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (badgeCenter != null && viewport != null) {
      offsetMid = Offset(
        badgeCenter.dx.clamp(
          tp.width / 2 + 8,
          math.max(tp.width / 2 + 8, viewport.width - tp.width / 2 - 8),
        ),
        badgeCenter.dy.clamp(
          tp.height / 2 + 8,
          math.max(tp.height / 2 + 8, viewport.height - tp.height / 2 - 8),
        ),
      );
    }

    final badgeOffset = Offset(
      offsetMid.dx - tp.width / 2.0,
      offsetMid.dy - tp.height / 2.0,
    );

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        badgeOffset.dx - 6,
        badgeOffset.dy - 3,
        tp.width + 12,
        tp.height + 6,
      ),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = const Color(0xE61A1C23);
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);
    tp.paint(canvas, badgeOffset);
  }
}
