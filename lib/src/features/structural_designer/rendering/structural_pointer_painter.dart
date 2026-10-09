import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/structural_element.dart';

/// Interactive tool modes for structural drawing.
enum StructuralDrawTool {
  select(Icons.pan_tool_rounded),
  gridAxis(Icons.grid_3x3_rounded),
  column(Icons.view_column_rounded),
  shearWall(Icons.line_weight_rounded),
  beam(Icons.horizontal_rule_rounded),
  slab(Icons.crop_square_rounded),
  slabOpening(Icons.tab_unselected_rounded),
  measure(Icons.straighten_rounded),
  layers(Icons.layers_rounded);

  final IconData icon;
  const StructuralDrawTool(this.icon);

  String label(AppLocalizations l10n) {
    switch (this) {
      case StructuralDrawTool.select:
        return l10n.toolNavigation;
      case StructuralDrawTool.gridAxis:
        return l10n.toolGridAxis;
      case StructuralDrawTool.column:
        return l10n.toolColumn;
      case StructuralDrawTool.shearWall:
        return l10n.toolShearWall;
      case StructuralDrawTool.beam:
        return l10n.toolBeam;
      case StructuralDrawTool.slab:
        return l10n.toolSlab;
      case StructuralDrawTool.slabOpening:
        return l10n.toolOpening;
      case StructuralDrawTool.measure:
        return l10n.toolMeasure;
      case StructuralDrawTool.layers:
        return l10n.layersTabTitle;
    }
  }
}

/// Custom screen-space painter for the offset pointer, stem guideline,
/// CAD snap icon, and real-time element preview above the user's finger.
class StructuralPointerPainter extends CustomPainter {
  final Offset touchPos;
  final Offset targetPos;
  final Offset? placementPos;
  final List<Offset>? previewElementPolygon;
  final bool showDetailLoupe;
  final Offset? snappedPos;
  final List<Offset>? snappedPositions;
  final DxfSnapType? snapType;
  final StructuralDrawTool activeTool;
  final StructuralColumn? previewColumn;
  final Offset? wallStartPos;
  final Offset? beamStartPos;
  final Offset? slabStartCornerPos;
  final Offset? openingStartCornerPos;
  final Size? previewOpeningSize;
  final List<Offset>? previewOpeningPolygon;
  final List<Offset>? slabPoints;
  final List<Offset>? openingPoints;
  final SlabOpeningType? activeOpeningType;
  final Offset? measureStartPos;
  final double? previewWallLengthScreen;
  final double? previewWallThicknessScreen;
  final double? previewWallRotationRad;
  final String? liveDimensionText;
  final double scale;
  final AppLocalizations? l10n;

  const StructuralPointerPainter({
    required this.touchPos,
    required this.targetPos,
    this.placementPos,
    this.previewElementPolygon,
    this.showDetailLoupe = false,
    this.snappedPos,
    this.snappedPositions,
    this.snapType,
    required this.activeTool,
    this.previewColumn,
    this.wallStartPos,
    this.beamStartPos,
    this.slabStartCornerPos,
    this.openingStartCornerPos,
    this.previewOpeningSize,
    this.previewOpeningPolygon,
    this.slabPoints,
    this.openingPoints,
    this.activeOpeningType,
    this.measureStartPos,
    this.previewWallLengthScreen,
    this.previewWallThicknessScreen,
    this.previewWallRotationRad,
    this.liveDimensionText,
    this.scale = 1.0,
    this.l10n,
  });

  /// Element reference point and snap marker are deliberately independent.
  Offset get effectivePlacementPosition =>
      placementPos ?? snappedPos ?? targetPos;

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveTip = effectivePlacementPosition;
    final bool isSnapped =
        (snappedPositions != null && snappedPositions!.isNotEmpty) ||
        snappedPos != null;

    final Color themeColor = isSnapped
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFFB300);

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

    final stemPath = Path()
      ..moveTo(touchPos.dx, touchPos.dy - 18)
      ..lineTo(guideConnectionPoint.dx, guideConnectionPoint.dy);

    canvas.drawPath(stemPath, stemPaint);

    // 3. Snap Markers at all snapped positions (supports simultaneous multi-point snap)
    if (snappedPositions != null && snappedPositions!.isNotEmpty) {
      for (final sPos in snappedPositions!) {
        _drawSnapIndicator(
          canvas,
          sPos,
          snapType ?? DxfSnapType.endpoint,
          themeColor,
        );
      }
    } else if (isSnapped && snapType != null) {
      _drawSnapIndicator(canvas, effectiveTip, snapType!, themeColor);
    }

    // 4. Live slab preview on pointer overlay (point-by-point drawing)
    if (activeTool == StructuralDrawTool.slab) {
      if (slabPoints != null && slabPoints!.isNotEmpty) {
        final slabBorder = Paint()
          ..color = themeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (int i = 0; i < slabPoints!.length - 1; i++) {
          canvas.drawLine(slabPoints![i], slabPoints![i + 1], slabBorder);
        }

        final bool isClose =
            slabPoints!.length >= 3 &&
            (effectiveTip - slabPoints!.first).distance <= 24.0;

        if (isClose) {
          final closeLine = Paint()
            ..color = const Color(0xFF00E676)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawLine(slabPoints!.last, slabPoints!.first, closeLine);

          final closeRing = Paint()
            ..color = const Color(0xFF00E676)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawCircle(slabPoints!.first, 8.0, closeRing);
        } else {
          canvas.drawLine(slabPoints!.last, effectiveTip, slabBorder);
        }

        final vDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        for (final p in slabPoints!) {
          canvas.drawCircle(p, 4.0, vDot);
        }
      } else if (slabStartCornerPos != null) {
        final rect = Rect.fromPoints(slabStartCornerPos!, effectiveTip);
        final slabFill = Paint()
          ..color = themeColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill;
        final slabBorder = Paint()
          ..color = themeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawRect(rect, slabFill);
        canvas.drawRect(rect, slabBorder);
      }
    }

    // 4b. Live opening preview on pointer overlay (if drawing slab opening)
    if (activeTool == StructuralDrawTool.slabOpening) {
      final Color opColor;
      switch (activeOpeningType) {
        case SlabOpeningType.staircase:
          opColor = const Color(0xFF00B0FF);
          break;
        case SlabOpeningType.elevator:
          opColor = const Color(0xFF7C4DFF);
          break;
        case SlabOpeningType.shaft:
        case SlabOpeningType.custom:
        default:
          opColor = const Color(0xFFFF9800);
          break;
      }

      if (openingPoints != null && openingPoints!.isNotEmpty) {
        final opBorder = Paint()
          ..color = opColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (int i = 0; i < openingPoints!.length - 1; i++) {
          canvas.drawLine(openingPoints![i], openingPoints![i + 1], opBorder);
        }

        final bool isClose =
            openingPoints!.length >= 3 &&
            (effectiveTip - openingPoints!.first).distance <= 24.0;

        if (isClose) {
          final closeLine = Paint()
            ..color = const Color(0xFF00E676)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawLine(openingPoints!.last, openingPoints!.first, closeLine);

          final closeRing = Paint()
            ..color = const Color(0xFF00E676)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5;
          canvas.drawCircle(openingPoints!.first, 8.0, closeRing);
        } else {
          canvas.drawLine(openingPoints!.last, effectiveTip, opBorder);
        }

        final vDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        for (final p in openingPoints!) {
          canvas.drawCircle(p, 4.0, vDot);
        }
      } else if (previewOpeningPolygon != null &&
          previewOpeningPolygon!.length >= 3) {
        final opFill = Paint()
          ..color = opColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        final opBorder = Paint()
          ..color = opColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final path = Path();
        for (int i = 0; i < previewOpeningPolygon!.length; i++) {
          final pt = effectiveTip + previewOpeningPolygon![i];
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, opFill);
        canvas.drawPath(path, opBorder);
        if (previewOpeningPolygon!.length >= 4) {
          canvas.drawLine(
            effectiveTip + previewOpeningPolygon![0],
            effectiveTip + previewOpeningPolygon![2],
            opBorder,
          );
          canvas.drawLine(
            effectiveTip + previewOpeningPolygon![1],
            effectiveTip + previewOpeningPolygon![3],
            opBorder,
          );
        }
      } else if (openingStartCornerPos != null) {
        final opFill = Paint()
          ..color = opColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        final opBorder = Paint()
          ..color = opColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final rect = Rect.fromPoints(openingStartCornerPos!, effectiveTip);
        canvas.drawRect(rect, opFill);
        canvas.drawRect(rect, opBorder);

        if (activeOpeningType == SlabOpeningType.staircase) {
          final p1 = rect.topLeft;
          final p2 = rect.topRight;
          final p3 = rect.bottomRight;
          final p4 = rect.bottomLeft;
          _drawStaircaseTreads(canvas, [p1, p2, p3, p4], opBorder);
        } else {
          canvas.drawLine(rect.topLeft, rect.bottomRight, opBorder);
          canvas.drawLine(rect.topRight, rect.bottomLeft, opBorder);
        }
      }
    }

    // 4d. Live shear wall preview on pointer overlay (clearly visible above finger)
    if (previewElementPolygon == null &&
        activeTool == StructuralDrawTool.shearWall &&
        previewWallLengthScreen != null) {
      final wallFill = Paint()
        ..color = themeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final wallBorder = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final rot = previewWallRotationRad ?? 0.0;
      final u = Offset(math.cos(rot), math.sin(rot));
      final n = Offset(-u.dy, u.dx);
      final halfLen = previewWallLengthScreen! / 2.0;
      final halfThick = (previewWallThicknessScreen ?? 10.0) / 2.0;

      final p1 = effectiveTip - u * halfLen - n * halfThick;
      final p2 = effectiveTip + u * halfLen - n * halfThick;
      final p3 = effectiveTip + u * halfLen + n * halfThick;
      final p4 = effectiveTip - u * halfLen + n * halfThick;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, wallFill);
      canvas.drawPath(path, wallBorder);
      canvas.drawLine(
        effectiveTip - u * halfLen,
        effectiveTip + u * halfLen,
        wallBorder,
      );
    }

    // 4e. Live column preview on pointer overlay
    if (previewElementPolygon == null &&
        activeTool == StructuralDrawTool.column &&
        previewColumn != null) {
      final colFill = Paint()
        ..color = themeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final colBorder = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final model = previewColumn!.copyWith(
        center: Offset.zero,
        width: previewColumn!.width * scale,
        height: previewColumn!.height * scale,
        thickness: previewColumn!.thickness * scale,
      );
      final polygon = model.polygonVertices
          .map((p) => effectiveTip + Offset(p.dx, -p.dy))
          .toList();
      final path = Path()..addPolygon(polygon, true);
      canvas.drawPath(path, colFill);
      canvas.drawPath(path, colBorder);
    }
    if (previewElementPolygon != null && previewElementPolygon!.length >= 3) {
      final path = Path()..addPolygon(previewElementPolygon!, true);
      canvas.drawPath(path, Paint()..color = themeColor.withValues(alpha: .22));
      canvas.drawPath(
        path,
        Paint()
          ..color = themeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (activeTool == StructuralDrawTool.column ||
        activeTool == StructuralDrawTool.shearWall) {
      final cross = Paint()
        ..color = themeColor
        ..strokeWidth = 1.5;
      canvas.drawCircle(effectiveTip, 3, Paint()..color = Colors.white);
      canvas.drawLine(
        effectiveTip - const Offset(7, 0),
        effectiveTip + const Offset(7, 0),
        cross,
      );
      canvas.drawLine(
        effectiveTip - const Offset(0, 7),
        effectiveTip + const Offset(0, 7),
        cross,
      );
    }
    if (showDetailLoupe &&
        previewElementPolygon != null &&
        (effectiveTip - touchPos).distance < 36 &&
        size.width >= 110 &&
        size.height >= 110) {
      _drawDetailLoupe(canvas, size, effectiveTip, themeColor);
    }

    // 4c. Active measurement ruler line and architectural ticks
    if (activeTool == StructuralDrawTool.measure && measureStartPos != null) {
      final p1 = measureStartPos!;
      final p2 = effectiveTip;
      final measurePaint = Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(p1, p2, measurePaint);

      // Draw architectural 45-degree slash ticks at ends
      const tickSize = 8.0;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 1e-4) {
        final ux = dx / len;
        final uy = dy / len;
        final nx = -uy;
        final ny = ux;

        void drawTick(Offset p) {
          final t1 = Offset(
            p.dx + (nx + ux) * tickSize * 0.7,
            p.dy + (ny + uy) * tickSize * 0.7,
          );
          final t2 = Offset(
            p.dx - (nx + ux) * tickSize * 0.7,
            p.dy - (ny + uy) * tickSize * 0.7,
          );
          canvas.drawLine(t1, t2, measurePaint..strokeWidth = 2.5);
        }

        drawTick(p1);
        drawTick(p2);
      }
    }

    // 5. Dimension badge (when drawing wall, beam, slab, custom opening, column/wall axis snap, or measuring)
    if (liveDimensionText != null) {
      final startPos =
          wallStartPos ??
          beamStartPos ??
          slabStartCornerPos ??
          openingStartCornerPos ??
          measureStartPos;
      if (startPos != null) {
        _drawDimensionBadge(canvas, startPos, effectiveTip, liveDimensionText!);
      } else {
        // Floating badge directly above element when positioning along an axis
        _drawDimensionBadge(
          canvas,
          effectiveTip,
          Offset(effectiveTip.dx, effectiveTip.dy - 35.0),
          liveDimensionText!,
        );
      }
    }
  }

  void _drawDetailLoupe(Canvas canvas, Size size, Offset center, Color color) {
    const radius = 42.0;
    final location = Offset(
      touchPos.dx.clamp(radius + 8, size.width - radius - 8).toDouble(),
      (touchPos.dy - 100)
          .clamp(radius + 8, size.height - radius - 8)
          .toDouble(),
    );
    canvas.drawCircle(
      location,
      radius,
      Paint()..color = const Color(0xF5FFFFFF),
    );
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: location, radius: radius - 2)),
    );
    canvas.translate(location.dx, location.dy);
    canvas.scale(2);
    canvas.translate(-center.dx, -center.dy);
    final path = Path()..addPolygon(previewElementPolygon!, true);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .22));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final point in snappedPositions ?? <Offset>[]) {
      _drawSnapIndicator(canvas, point, snapType ?? DxfSnapType.nearest, color);
    }
    canvas.drawLine(
      center - const Offset(5, 0),
      center + const Offset(5, 0),
      Paint()
        ..color = color
        ..strokeWidth = .7,
    );
    canvas.drawLine(
      center - const Offset(0, 5),
      center + const Offset(0, 5),
      Paint()
        ..color = color
        ..strokeWidth = .7,
    );
    canvas.restore();
    canvas.drawCircle(
      location,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final label = TextPainter(
      text: const TextSpan(
        text: '×2',
        style: TextStyle(color: Colors.black87, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, location + const Offset(24, -34));
  }

  void _drawSnapIndicator(
    Canvas canvas,
    Offset pos,
    DxfSnapType type,
    Color color,
  ) {
    final snapPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double s = 8.0;
    switch (type) {
      case DxfSnapType.endpoint:
        canvas.drawRect(
          Rect.fromCenter(center: pos, width: s * 2, height: s * 2),
          snapPaint,
        );
        break;
      case DxfSnapType.midpoint:
        final path = Path()
          ..moveTo(pos.dx, pos.dy - s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..lineTo(pos.dx - s, pos.dy + s)
          ..close();
        canvas.drawPath(path, snapPaint);
        break;
      case DxfSnapType.center:
        canvas.drawCircle(pos, s, snapPaint);
        break;
      case DxfSnapType.nearest:
        // Hourglass shape
        final path = Path()
          ..moveTo(pos.dx - s, pos.dy - s)
          ..lineTo(pos.dx + s, pos.dy - s)
          ..lineTo(pos.dx - s, pos.dy + s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..close();
        canvas.drawPath(path, snapPaint);
        break;
      default:
        canvas.drawCircle(pos, s, snapPaint);
    }
  }

  void _drawDimensionBadge(Canvas canvas, Offset p1, Offset p2, String text) {
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

  void _drawStaircaseTreads(
    Canvas canvas,
    List<Offset> opPts,
    Paint borderPaint,
  ) {
    if (opPts.length < 4) return;
    final treadPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final d1 = (opPts[1] - opPts[0]).distance;
    final d2 = (opPts[3] - opPts[0]).distance;

    final Offset pA0, pA1, pB0, pB1;
    if (d2 >= d1) {
      pA0 = opPts[0];
      pA1 = opPts[3];
      pB0 = opPts[1];
      pB1 = opPts[2];
    } else {
      pA0 = opPts[0];
      pA1 = opPts[1];
      pB0 = opPts[3];
      pB1 = opPts[2];
    }

    const int numTreads = 9;
    for (int i = 1; i < numTreads; i++) {
      final t = i / numTreads;
      final ptA = Offset.lerp(pA0, pA1, t)!;
      final ptB = Offset.lerp(pB0, pB1, t)!;
      canvas.drawLine(ptA, ptB, treadPaint);
    }

    final startMid = Offset.lerp(pA0, pB0, 0.5)!;
    final endMid = Offset.lerp(pA1, pB1, 0.5)!;
    final arrowStart = Offset.lerp(startMid, endMid, 0.2)!;
    final arrowEnd = Offset.lerp(startMid, endMid, 0.8)!;
    final arrowDir = arrowEnd - arrowStart;
    final arrowLen = arrowDir.distance;
    if (arrowLen > 10.0) {
      final u = arrowDir / arrowLen;
      final normal = Offset(-u.dy, u.dx);
      final arrowPaint = Paint()
        ..color = borderPaint.color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(arrowStart, 2.5, Paint()..color = borderPaint.color);
      canvas.drawLine(arrowStart, arrowEnd, arrowPaint);
      const double headLen = 6.0;
      const double headWidth = 3.5;
      final headLeft = arrowEnd - u * headLen + normal * headWidth;
      final headRight = arrowEnd - u * headLen - normal * headWidth;
      canvas.drawLine(arrowEnd, headLeft, arrowPaint);
      canvas.drawLine(arrowEnd, headRight, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StructuralPointerPainter oldDelegate) {
    return oldDelegate.touchPos != touchPos ||
        oldDelegate.targetPos != targetPos ||
        oldDelegate.placementPos != placementPos ||
        oldDelegate.previewElementPolygon != previewElementPolygon ||
        oldDelegate.showDetailLoupe != showDetailLoupe ||
        oldDelegate.snappedPos != snappedPos ||
        oldDelegate.snappedPositions != snappedPositions ||
        oldDelegate.snapType != snapType ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.previewColumn != previewColumn ||
        oldDelegate.wallStartPos != wallStartPos ||
        oldDelegate.beamStartPos != beamStartPos ||
        oldDelegate.slabStartCornerPos != slabStartCornerPos ||
        oldDelegate.openingStartCornerPos != openingStartCornerPos ||
        oldDelegate.previewOpeningSize != previewOpeningSize ||
        oldDelegate.previewOpeningPolygon != previewOpeningPolygon ||
        oldDelegate.slabPoints != slabPoints ||
        oldDelegate.openingPoints != openingPoints ||
        oldDelegate.activeOpeningType != activeOpeningType ||
        oldDelegate.previewWallLengthScreen != previewWallLengthScreen ||
        oldDelegate.previewWallThicknessScreen != previewWallThicknessScreen ||
        oldDelegate.previewWallRotationRad != previewWallRotationRad ||
        oldDelegate.liveDimensionText != liveDimensionText;
  }
}
