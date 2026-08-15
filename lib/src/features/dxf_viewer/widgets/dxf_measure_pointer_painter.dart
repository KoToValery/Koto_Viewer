import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../rendering/dxf_math.dart';
import '../rendering/dxf_snap_helper.dart';

/// Screen-space overlay painter for the Offset Snapping Target Pointer during measurement.
class DxfMeasurePointerPainter extends CustomPainter {
  final Offset touchPos;
  final Offset targetPos;
  final Offset? snappedPos;
  final DxfSnapType? snapType;
  final Offset currentCadCoord;
  final Offset? p1CadCoord;
  final bool isSettingSecondPoint;

  const DxfMeasurePointerPainter({
    required this.touchPos,
    required this.targetPos,
    this.snappedPos,
    this.snapType,
    required this.currentCadCoord,
    this.p1CadCoord,
    this.isSettingSecondPoint = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveTip = snappedPos ?? targetPos;
    final bool isSnapped = snappedPos != null;

    final baseColor = isSnapped ? const Color(0xFF00E5FF) : const Color(0xFFFF5252);
    final glowColor = baseColor.withValues(alpha: 0.35);

    // 1. Draw Touch Anchor (under the user's finger)
    final touchAnchorPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final touchBorderPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final touchCenterPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(touchPos, 18, touchAnchorPaint);
    canvas.drawCircle(touchPos, 18, touchBorderPaint);
    canvas.drawCircle(touchPos, 3.5, touchCenterPaint);

    // 2. Draw Sleek Guideline Stem (connecting touch anchor to target apex)
    final stemPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final glowStemPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..isAntiAlias = true;

    // Stem path with slight taper from finger up to target
    final stemPath = Path()
      ..moveTo(touchPos.dx, touchPos.dy - 18)
      ..lineTo(effectiveTip.dx, effectiveTip.dy + 14);

    canvas.drawPath(stemPath, glowStemPaint);
    canvas.drawPath(stemPath, stemPaint);

    // 3. Draw Sharp Pointer Apex (Остър ъгъл / Стрелка)
    final arrowPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final arrowStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    const double arrowW = 10.0;
    const double arrowH = 16.0;

    final apexPath = Path()
      ..moveTo(effectiveTip.dx, effectiveTip.dy) // Sharp tip pointing UP
      ..lineTo(effectiveTip.dx + arrowW, effectiveTip.dy + arrowH)
      ..lineTo(effectiveTip.dx, effectiveTip.dy + arrowH * 0.7)
      ..lineTo(effectiveTip.dx - arrowW, effectiveTip.dy + arrowH)
      ..close();

    canvas.drawPath(apexPath, arrowPaint);
    canvas.drawPath(apexPath, arrowStrokePaint);

    // 4. Draw Snap Marker & Magnetism Halo if snapped
    if (isSnapped) {
      _drawSnapIndicator(canvas, effectiveTip, snapType ?? DxfSnapType.endpoint);
    } else {
      // Precision crosshairs at tip
      final crossPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(effectiveTip.dx - 6, effectiveTip.dy), Offset(effectiveTip.dx + 6, effectiveTip.dy), crossPaint);
      canvas.drawLine(Offset(effectiveTip.dx, effectiveTip.dy - 6), Offset(effectiveTip.dx, effectiveTip.dy + 6), crossPaint);
    }

    // 5. Draw Floating HUD Badge near the apex
    _drawHudBadge(canvas, effectiveTip, isSnapped);
  }

  void _drawSnapIndicator(Canvas canvas, Offset pos, DxfSnapType type) {
    const double snapSize = 14.0;

    final snapHaloPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final snapLinePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    switch (type) {
      case DxfSnapType.endpoint:
      case DxfSnapType.point:
        // Diamond ◇
        final diamond = Path()
          ..moveTo(pos.dx, pos.dy - snapSize)
          ..lineTo(pos.dx + snapSize, pos.dy)
          ..lineTo(pos.dx, pos.dy + snapSize)
          ..lineTo(pos.dx - snapSize, pos.dy)
          ..close();
        canvas.drawPath(diamond, snapHaloPaint);
        canvas.drawPath(diamond, snapLinePaint);
        break;

      case DxfSnapType.midpoint:
        // Triangle △
        final triangle = Path()
          ..moveTo(pos.dx, pos.dy - snapSize)
          ..lineTo(pos.dx + snapSize, pos.dy + snapSize * 0.8)
          ..lineTo(pos.dx - snapSize, pos.dy + snapSize * 0.8)
          ..close();
        canvas.drawPath(triangle, snapHaloPaint);
        canvas.drawPath(triangle, snapLinePaint);
        break;

      case DxfSnapType.center:
        // Concentric Circles ⊙
        canvas.drawCircle(pos, snapSize, snapHaloPaint);
        canvas.drawCircle(pos, snapSize, snapLinePaint);
        canvas.drawCircle(pos, 3.0, Paint()..color = const Color(0xFF00E5FF)..style = PaintingStyle.fill);
        break;
    }
  }

  void _drawHudBadge(Canvas canvas, Offset tipPos, bool isSnapped) {
    String titleText = isSettingSecondPoint ? '2-ра точка' : '1-ва точка';
    if (isSnapped && snapType != null) {
      switch (snapType!) {
        case DxfSnapType.endpoint:
          titleText += ' • Връх';
          break;
        case DxfSnapType.midpoint:
          titleText += ' • Среда';
          break;
        case DxfSnapType.center:
          titleText += ' • Център';
          break;
        case DxfSnapType.point:
          titleText += ' • Точка';
          break;
      }
    }

    String subText = 'X: ${DxfMath.formatDistance(currentCadCoord.dx)}  Y: ${DxfMath.formatDistance(currentCadCoord.dy)}';
    if (isSettingSecondPoint && p1CadCoord != null) {
      final double liveDist = (currentCadCoord - p1CadCoord!).distance;
      subText = 'L = ${DxfMath.formatDistance(liveDist)} m  |  $subText';
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: titleText,
        style: TextStyle(
          color: isSnapped ? const Color(0xFF00E5FF) : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final subPainter = TextPainter(
      text: TextSpan(
        text: subText,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double badgeW = math.max(titlePainter.width, subPainter.width) + 16.0;
    const double badgeH = 34.0;

    // Position badge to the right-top of the tip, flipped if near right edge
    double badgeX = tipPos.dx + 16;
    if (badgeX + badgeW > 380) {
      badgeX = tipPos.dx - badgeW - 16;
    }
    final double badgeY = tipPos.dy - badgeH - 8;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
      const Radius.circular(8),
    );

    final bgPaint = Paint()
      ..color = const Color(0xEE141C2B)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = (isSnapped ? const Color(0xFF00E5FF) : const Color(0xFFFF5252)).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(badgeRect, bgPaint);
    canvas.drawRRect(badgeRect, borderPaint);

    titlePainter.paint(canvas, Offset(badgeX + 8, badgeY + 4));
    subPainter.paint(canvas, Offset(badgeX + 8, badgeY + 18));
  }

  @override
  bool shouldRepaint(covariant DxfMeasurePointerPainter oldDelegate) {
    return oldDelegate.touchPos != touchPos ||
        oldDelegate.targetPos != targetPos ||
        oldDelegate.snappedPos != snappedPos ||
        oldDelegate.snapType != snapType ||
        oldDelegate.currentCadCoord != currentCadCoord ||
        oldDelegate.p1CadCoord != p1CadCoord ||
        oldDelegate.isSettingSecondPoint != isSettingSecondPoint;
  }
}
