import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';

/// Screen-space overlay painter for active CAD measurements (Distance, Area, Angle, Radius, Annotation)
/// and saved annotations.
///
/// Because this is drawn in screen coordinates (logical pixels) above InteractiveViewer,
/// all lines, vertex pins, and text badges render at 100% crisp vector sharpness (never blurry),
/// badges are always mathematically centered without metric distortion, and normal-based
/// positioning prevents the badge from colliding with or intersecting the dimension line.
class DxfMeasurementCanvasPainter extends CustomPainter {
  final DxfMeasurement? measurement;
  final DxfUnit unit;
  final Offset Function(Offset cadPoint) cadToScreen;
  final Offset? candidateCadPoint;
  final List<DxfAnnotation> annotations;

  const DxfMeasurementCanvasPainter({
    required this.measurement,
    required this.unit,
    required this.cadToScreen,
    this.candidateCadPoint,
    this.annotations = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (annotations.isNotEmpty) {
      _drawSavedAnnotations(canvas);
    }

    if (measurement == null) return;

    switch (measurement!.tool) {
      case DxfMeasureTool.distance:
        _drawDistanceMeasurement(canvas);
        break;
      case DxfMeasureTool.area:
        _drawAreaMeasurement(canvas);
        break;
      case DxfMeasureTool.angle:
        _drawAngleMeasurement(canvas);
        break;
      case DxfMeasureTool.radius:
        _drawRadiusMeasurement(canvas);
        break;
      case DxfMeasureTool.annotation:
        _drawAnnotationPreview(canvas);
        break;
    }
  }

  // ==========================================
  // 1. Distance Measurement
  // ==========================================
  void _drawDistanceMeasurement(Canvas canvas) {
    final m = measurement!;
    if (m.p1Cad == null) return;

    final p1 = cadToScreen(m.p1Cad!);
    const accentColor = Color(0xFFFF5252);

    _drawPin(canvas, p1, accentColor);

    if (m.p2Cad != null) {
      final p2 = cadToScreen(m.p2Cad!);
      _drawPin(canvas, p2, accentColor);

      // Confirmed measurement line
      final linePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawLine(p1, p2, linePaint);

      // Distance Badge positioned along the perpendicular normal of the line
      final mid = (p1 + p2) / 2.0;
      final delta = p2 - p1;
      final dist = delta.distance;

      Offset normal;
      if (dist > 1e-3) {
        final u = delta / dist;
        normal = Offset(-u.dy, u.dx);
        // Ensure normal prefers pointing upward (or leftward if horizontal)
        if (normal.dy > 0 || (normal.dy == 0 && normal.dx < 0)) {
          normal = -normal;
        }
      } else {
        normal = const Offset(0, -1);
      }

      final badgeCenter = mid + normal * 20.0;
      final distVal = m.distance ?? 0.0;
      _drawScreenBadge(
        canvas: canvas,
        center: badgeCenter,
        text: 'L: ${DxfMath.formatDistance(distVal, unit: unit)} m',
        accentColor: accentColor,
      );
    } else if (candidateCadPoint != null) {
      // Live rubberband line to finger/cursor while placing 2nd point
      final candScreen = cadToScreen(candidateCadPoint!);
      final previewPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawLine(p1, candScreen, previewPaint);

      final liveDist = (candidateCadPoint! - m.p1Cad!).distance;
      final mid = (p1 + candScreen) / 2.0;
      final delta = candScreen - p1;
      final dist = delta.distance;

      Offset normal;
      if (dist > 1e-3) {
        final u = delta / dist;
        normal = Offset(-u.dy, u.dx);
        if (normal.dy > 0 || (normal.dy == 0 && normal.dx < 0)) {
          normal = -normal;
        }
      } else {
        normal = const Offset(0, -1);
      }

      final badgeCenter = mid + normal * 18.0;
      _drawScreenBadge(
        canvas: canvas,
        center: badgeCenter,
        text: 'L: ${DxfMath.formatDistance(liveDist, unit: unit)} m',
        accentColor: accentColor.withValues(alpha: 0.85),
      );
    }
  }

  // ==========================================
  // 2. Area Measurement
  // ==========================================
  void _drawAreaMeasurement(Canvas canvas) {
    final m = measurement!;
    if (m.areaPoints.isEmpty) return;

    const accentColor = Color(0xFF00E5FF);
    final pts = m.areaPoints.map(cadToScreen).toList();

    // Include candidate CAD point while finger moves/drags
    final candScreen = (candidateCadPoint != null && !m.isAreaClosed)
        ? cadToScreen(candidateCadPoint!)
        : null;

    final displayPts = List<Offset>.from(pts);
    if (candScreen != null && (pts.isEmpty || (candScreen - pts.last).distanceSquared > 1.0)) {
      displayPts.add(candScreen);
    }

    // 1. Shaded polygon fill if >= 3 points
    if (displayPts.length >= 3) {
      final fillPath = Path()..moveTo(displayPts.first.dx, displayPts.first.dy);
      for (int i = 1; i < displayPts.length; i++) {
        fillPath.lineTo(displayPts[i].dx, displayPts[i].dy);
      }
      fillPath.close();

      final fillPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Subtle diagonal CAD hatch lines inside polygon
      final bounds = fillPath.getBounds();
      if (bounds.width > 0 && bounds.height > 0) {
        final hatchPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.20)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        const double hatchStep = 18.0;

        canvas.save();
        canvas.clipPath(fillPath);
        for (double x = bounds.left - bounds.height; x <= bounds.right; x += hatchStep) {
          canvas.drawLine(
            Offset(x, bounds.bottom),
            Offset(x + bounds.height, bounds.top),
            hatchPaint,
          );
        }
        canvas.restore();
      }
    }

    // 2. Boundary outlines
    if (pts.length >= 2) {
      final outlinePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        outlinePath.lineTo(pts[i].dx, pts[i].dy);
      }
      final outlinePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(outlinePath, outlinePaint);
    }

    // 2b. Rubberband line to candidate point
    if (candScreen != null && pts.isNotEmpty) {
      final rubberPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(pts.last, candScreen, rubberPaint);

      if (displayPts.length >= 3) {
        final previewClosePaint = Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawLine(candScreen, pts.first, previewClosePaint);
      }
    }

    // Closing boundary back to start when >= 3 points
    if (pts.length >= 3) {
      final isFinal = m.isAreaClosed;
      final closeLinePaint = Paint()
        ..color = isFinal ? accentColor : accentColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFinal ? 2.4 : 1.6;
      canvas.drawLine(pts.last, pts.first, closeLinePaint);
    }

    // 3. Numbered Vertex Pins (1, 2, 3...)
    for (int i = 0; i < pts.length; i++) {
      final pos = pts[i];
      const double radius = 9.5;

      // Outer glow and border
      final pinPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      final pinBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(pos, radius, pinPaint);
      canvas.drawCircle(pos, radius, pinBorderPaint);

      // Centered number inside pin
      final numPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Color(0xFF0A0A0A),
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numPainter.paint(canvas, pos - Offset(numPainter.width / 2.0, numPainter.height / 2.0));
    }

    // 4. Centroid Result Badge (real-time live area & perimeter)
    final calcCadPts = (displayPts.length > pts.length && candidateCadPoint != null)
        ? [...m.areaPoints, candidateCadPoint!]
        : m.areaPoints;

    if (calcCadPts.length >= 3) {
      final double area = DxfMath.calculatePolygonArea(calcCadPts);
      final double perim = DxfMath.calculatePolygonPerimeter(calcCadPts, isClosed: true);
      final Offset centroidCad = DxfMath.calculatePolygonCentroid(calcCadPts);
      final Offset centroidScreen = cadToScreen(centroidCad);

      _drawScreenBadge(
        canvas: canvas,
        center: centroidScreen,
        text: 'S = ${DxfMath.formatArea(area, unit: unit)}',
        subText: 'P = ${DxfMath.formatDistance(perim, unit: unit)} m',
        accentColor: accentColor,
      );
    }
  }

  // ==========================================
  // 3. Angle Measurement
  // ==========================================
  void _drawAngleMeasurement(Canvas canvas) {
    final m = measurement!;
    if (m.angleVertex == null) return;

    const accentColor = Color(0xFFFFB300);
    final v = cadToScreen(m.angleVertex!);

    _drawPin(canvas, v, accentColor, radius: 6.0);

    final rayPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    Offset? p1;
    Offset? p2;

    if (m.angleP1 != null) {
      p1 = cadToScreen(m.angleP1!);
      canvas.drawLine(v, p1, rayPaint);
      _drawPin(canvas, p1, accentColor, radius: 4.5);
    }

    if (m.angleP2 != null) {
      p2 = cadToScreen(m.angleP2!);
      canvas.drawLine(v, p2, rayPaint);
      _drawPin(canvas, p2, accentColor, radius: 4.5);
    } else if (p1 != null && candidateCadPoint != null) {
      // Candidate arm 2 preview
      final candScreen = cadToScreen(candidateCadPoint!);
      final previewPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawLine(v, candScreen, previewPaint);
      p2 = candScreen;
    }

    if (p1 != null && p2 != null) {
      final double dx1 = p1.dx - v.dx;
      final double dy1 = p1.dy - v.dy;
      final double dx2 = p2.dx - v.dx;
      final double dy2 = p2.dy - v.dy;

      final double a1 = math.atan2(dy1, dx1);
      final double a2 = math.atan2(dy2, dx2);
      double sweep = a2 - a1;
      while (sweep <= -math.pi) {
        sweep += 2 * math.pi;
      }
      while (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }

      double angleDeg = sweep.abs() * 180.0 / math.pi;
      if (m.angleP1 != null && m.angleP2 != null) {
        angleDeg = DxfMath.calculateAngleBetweenVectors(
          m.angleVertex!,
          m.angleP1!,
          m.angleP2!,
        );
      }

      const double arcRadius = 36.0;
      final arcRect = Rect.fromCircle(center: v, radius: arcRadius);

      final arcPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      final sectorPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;

      final sectorPath = Path()
        ..moveTo(v.dx, v.dy)
        ..arcTo(arcRect, a1, sweep, false)
        ..close();

      canvas.drawPath(sectorPath, sectorPaint);
      canvas.drawArc(arcRect, a1, sweep, false, arcPaint);

      final double midAngle = a1 + sweep / 2.0;
      final Offset badgePos = v +
          Offset(math.cos(midAngle), math.sin(midAngle)) * (arcRadius + 22.0);

      _drawScreenBadge(
        canvas: canvas,
        center: badgePos,
        text: '∠ = ${angleDeg.toStringAsFixed(1)}°',
        accentColor: accentColor,
      );
    }
  }

  // ==========================================
  // 4. Radius / Diameter Measurement
  // ==========================================
  void _drawRadiusMeasurement(Canvas canvas) {
    final m = measurement!;
    const accentColor = Color(0xFF00E676);

    // If points collected prior to 3-point solve
    if (m.circleCenter == null) {
      for (final pt in m.circlePoints) {
        final cPt = cadToScreen(pt);
        _drawPin(canvas, cPt, accentColor, radius: 5.0);
      }
      return;
    }

    final c = cadToScreen(m.circleCenter!);

    // Calculate screen radius using CAD radius
    final Offset sampleCad = m.circlePoints.isNotEmpty
        ? m.circlePoints.first
        : (m.circleCenter! + Offset(m.radius!, 0));
    final Offset sampleScreen = cadToScreen(sampleCad);
    final double screenRadius = (sampleScreen - c).distance;

    // 1. Highlight circle contour
    final circlePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(c, screenRadius, circlePaint);

    // 2. Center Crosshairs (+)
    const double crossLen = 9.0;
    final crossPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(c - const Offset(crossLen, 0), c + const Offset(crossLen, 0), crossPaint);
    canvas.drawLine(c - const Offset(0, crossLen), c + const Offset(0, crossLen), crossPaint);

    // 3. Radial leader line from center to edge
    Offset dir = const Offset(0.7071, -0.7071);
    if ((sampleScreen - c).distance > 1e-4) {
      dir = (sampleScreen - c) / (sampleScreen - c).distance;
    }
    final edgePt = c + dir * screenRadius;

    final leaderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawLine(c, edgePt, leaderPaint);
    _drawPin(canvas, edgePt, accentColor, radius: 4.5);

    // 4. Dimension Badge
    final mid = (c + edgePt) / 2.0;
    final normal = Offset(-dir.dy, dir.dx);
    final badgeCenter = mid + normal * 18.0;

    final String sub = 'Ø = ${DxfMath.formatDistance(m.radius! * 2.0, unit: unit)} m${m.isArc && m.arcLength != null ? ' • Arc: ${DxfMath.formatDistance(m.arcLength!, unit: unit)} m' : ''}';

    _drawScreenBadge(
      canvas: canvas,
      center: badgeCenter,
      text: 'R = ${DxfMath.formatDistance(m.radius!, unit: unit)} m',
      subText: sub,
      accentColor: accentColor,
    );
  }

  // ==========================================
  // 5. Annotation Leader Preview
  // ==========================================
  void _drawAnnotationPreview(Canvas canvas) {
    final m = measurement!;
    if (m.annotationTip == null) return;
    const color = Color(0xFFFF4081);

    final tip = cadToScreen(m.annotationTip!);
    _drawPin(canvas, tip, color, radius: 5.5);

    if (m.annotationTextPos != null) {
      final textPos = cadToScreen(m.annotationTextPos!);
      _drawSingleLeaderAnnotation(
        canvas: canvas,
        tip: tip,
        textPos: textPos,
        text: m.annotationText ?? 'Tap to place note',
        color: color,
      );
    }
  }

  // ==========================================
  // 6. Saved Annotations
  // ==========================================
  void _drawSavedAnnotations(Canvas canvas) {
    for (final anno in annotations) {
      final tip = cadToScreen(anno.arrowTipCad);
      final textPos = cadToScreen(anno.textPosCad);
      _drawSingleLeaderAnnotation(
        canvas: canvas,
        tip: tip,
        textPos: textPos,
        text: anno.text,
        color: anno.color,
      );
    }
  }

  void _drawSingleLeaderAnnotation({
    required Canvas canvas,
    required Offset tip,
    required Offset textPos,
    required String text,
    required Color color,
  }) {
    final delta = textPos - tip;
    final dist = delta.distance;

    final leaderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const double arrowLen = 14.0;
    const double arrowWidth = 7.0;

    if (dist > 1e-3) {
      final u = delta / dist;
      final normal = Offset(-u.dy, u.dx);
      final pLeft = tip + u * arrowLen + normal * (arrowWidth / 2.0);
      final pRight = tip + u * arrowLen - normal * (arrowWidth / 2.0);

      final arrowPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(pLeft.dx, pLeft.dy)
        ..lineTo(pRight.dx, pRight.dy)
        ..close();

      canvas.drawPath(arrowPath, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawLine(tip + u * (arrowLen * 0.85), textPos, leaderPaint);
    } else {
      _drawPin(canvas, tip, color, radius: 4.0);
    }

    final bool isRight = textPos.dx >= tip.dx;
    const double shoulderLen = 22.0;
    final shoulderEnd = textPos + Offset(isRight ? shoulderLen : -shoulderLen, 0);
    canvas.drawLine(textPos, shoulderEnd, leaderPaint);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout();

    const double padH = 8.0;
    const double padV = 4.5;
    final badgeW = titlePainter.width + padH * 2;
    final badgeH = titlePainter.height + padV * 2;

    final double badgeLeft = isRight ? textPos.dx + 4.0 : textPos.dx - badgeW - 4.0;
    final double badgeTop = textPos.dy - badgeH - 2.0;
    final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect.shift(const Offset(0, 2)), const Radius.circular(6)),
      shadowPaint,
    );

    final bgPaint = Paint()
      ..color = const Color(0xF2141C2B)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(6));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    titlePainter.paint(canvas, Offset(badgeLeft + padH, badgeTop + padV));
  }

  // ==========================================
  // Helper: Vector-Sharp, Centered HUD Badge
  // ==========================================
  void _drawScreenBadge({
    required Canvas canvas,
    required Offset center,
    required String text,
    String? subText,
    required Color accentColor,
  }) {
    final titlePainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    TextPainter? subPainter;
    if (subText != null && subText.isNotEmpty) {
      subPainter = TextPainter(
        text: TextSpan(
          text: subText,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.0,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    final double contentW = math.max(titlePainter.width, subPainter?.width ?? 0.0);
    const double padH = 9.0;
    const double padV = 5.0;
    const double lineSpacing = 2.5;

    final double totalTextH = titlePainter.height + (subPainter != null ? subPainter.height + lineSpacing : 0.0);
    final double badgeW = contentW + padH * 2;
    final double badgeH = totalTextH + padV * 2;

    final bubbleRect = Rect.fromCenter(
      center: center,
      width: badgeW,
      height: badgeH,
    );

    // Subtle drop shadow for legibility over dense CAD lines
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubbleRect.shift(const Offset(0, 2)), const Radius.circular(8)),
      shadowPaint,
    );

    final bgPaint = Paint()
      ..color = const Color(0xF2141C2B)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rrect = RRect.fromRectAndRadius(bubbleRect, const Radius.circular(8));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Horizontally and vertically centered text layout
    final double startY = center.dy - totalTextH / 2.0;
    final double titleX = center.dx - titlePainter.width / 2.0;
    titlePainter.paint(canvas, Offset(titleX, startY));

    if (subPainter != null) {
      final double subX = center.dx - subPainter.width / 2.0;
      subPainter.paint(canvas, Offset(subX, startY + titlePainter.height + lineSpacing));
    }
  }

  void _drawPin(Canvas canvas, Offset pos, Color color, {double radius = 5.0}) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(pos, radius + 3.0, glowPaint);
    canvas.drawCircle(pos, radius, fillPaint);
    canvas.drawCircle(pos, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant DxfMeasurementCanvasPainter oldDelegate) {
    return oldDelegate.measurement != measurement ||
        oldDelegate.unit != unit ||
        oldDelegate.candidateCadPoint != candidateCadPoint ||
        oldDelegate.annotations != annotations;
  }
}
