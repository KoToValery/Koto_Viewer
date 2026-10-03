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
  measure(Icons.straighten_rounded);

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
    }
  }
}

/// Custom screen-space painter for the offset pointer, stem guideline,
/// CAD snap icon, and real-time element preview above the user's finger.
class StructuralPointerPainter extends CustomPainter {
  final Offset touchPos;
  final Offset targetPos;
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
  final Offset? measureStartPos;
  final String? liveDimensionText;
  final double scale;
  final AppLocalizations? l10n;

  const StructuralPointerPainter({
    required this.touchPos,
    required this.targetPos,
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
    this.measureStartPos,
    this.liveDimensionText,
    this.scale = 1.0,
    this.l10n,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveTip = snappedPos ?? targetPos;
    final bool isSnapped = (snappedPositions != null && snappedPositions!.isNotEmpty) || snappedPos != null;

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

    // 2. Guideline Stem connecting finger to the offset target
    final stemPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final stemPath = Path()
      ..moveTo(touchPos.dx, touchPos.dy - 18)
      ..lineTo(effectiveTip.dx, effectiveTip.dy);

    canvas.drawPath(stemPath, stemPaint);

    // 3. Snap Markers at all snapped positions (supports simultaneous multi-point snap)
    if (snappedPositions != null && snappedPositions!.isNotEmpty) {
      for (final sPos in snappedPositions!) {
        _drawSnapIndicator(canvas, sPos, snapType ?? DxfSnapType.endpoint, themeColor);
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

        final bool isClose = slabPoints!.length >= 3 &&
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

    // 4b. Live rectangular opening preview on pointer overlay (if drawing slab opening)
    if (activeTool == StructuralDrawTool.slabOpening) {
      final opFill = Paint()
        ..color = const Color(0x33FF9800)
        ..style = PaintingStyle.fill;
      final opBorder = Paint()
        ..color = const Color(0xFFFF9800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      if (openingStartCornerPos != null) {
        final rect = Rect.fromPoints(openingStartCornerPos!, effectiveTip);
        canvas.drawRect(rect, opFill);
        canvas.drawRect(rect, opBorder);
        // Architectural X cross
        canvas.drawLine(rect.topLeft, rect.bottomRight, opBorder);
        canvas.drawLine(rect.topRight, rect.bottomLeft, opBorder);
      } else if (previewOpeningPolygon != null && previewOpeningPolygon!.length >= 3) {
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
          canvas.drawLine(effectiveTip + previewOpeningPolygon![0], effectiveTip + previewOpeningPolygon![2], opBorder);
          canvas.drawLine(effectiveTip + previewOpeningPolygon![1], effectiveTip + previewOpeningPolygon![3], opBorder);
        }
      } else if (previewOpeningSize != null) {
        final rect = Rect.fromCenter(
          center: effectiveTip,
          width: previewOpeningSize!.width,
          height: previewOpeningSize!.height,
        );
        canvas.drawRect(rect, opFill);
        canvas.drawRect(rect, opBorder);
        canvas.drawLine(rect.topLeft, rect.bottomRight, opBorder);
        canvas.drawLine(rect.topRight, rect.bottomLeft, opBorder);
      }
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
          final t1 = Offset(p.dx + (nx + ux) * tickSize * 0.7, p.dy + (ny + uy) * tickSize * 0.7);
          final t2 = Offset(p.dx - (nx + ux) * tickSize * 0.7, p.dy - (ny + uy) * tickSize * 0.7);
          canvas.drawLine(t1, t2, measurePaint..strokeWidth = 2.5);
        }
        drawTick(p1);
        drawTick(p2);
      }
    }

    // 5. Dimension badge snapped to 10 cm (when drawing wall, beam, slab, custom opening, or measuring)
    if (liveDimensionText != null) {
      final startPos = wallStartPos ?? beamStartPos ?? slabStartCornerPos ?? openingStartCornerPos ?? measureStartPos;
      if (startPos != null) {
        _drawDimensionBadge(canvas, startPos, effectiveTip, liveDimensionText!);
      }
    }
  }





  void _drawSnapIndicator(
      Canvas canvas, Offset pos, DxfSnapType type, Color color) {
    final snapPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double s = 8.0;
    switch (type) {
      case DxfSnapType.endpoint:
        canvas.drawRect(
            Rect.fromCenter(center: pos, width: s * 2, height: s * 2),
            snapPaint);
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

  void _drawDimensionBadge(
      Canvas canvas, Offset p1, Offset p2, String text) {
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
      Rect.fromLTWH(badgeOffset.dx - 6, badgeOffset.dy - 3, tp.width + 12, tp.height + 6),
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

  @override
  bool shouldRepaint(covariant StructuralPointerPainter oldDelegate) {
    return oldDelegate.touchPos != touchPos ||
        oldDelegate.targetPos != targetPos ||
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
        oldDelegate.liveDimensionText != liveDimensionText;
  }
}
