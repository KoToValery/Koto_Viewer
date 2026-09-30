import 'package:flutter/material.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/structural_element.dart';

/// Interactive tool modes for structural drawing.
enum StructuralDrawTool {
  select('Избор', Icons.near_me_rounded),
  column('Колона', Icons.view_column_rounded),
  shearWall('Шайба', Icons.line_weight_rounded),
  slab('Плоча', Icons.crop_square_rounded),
  slabOpening('Отвор', Icons.tab_unselected_rounded);

  final String label;
  final IconData icon;
  const StructuralDrawTool(this.label, this.icon);
}

/// Custom screen-space painter for the offset pointer, stem guideline,
/// CAD snap icon, and real-time element preview above the user's finger.
class StructuralPointerPainter extends CustomPainter {
  final Offset touchPos;
  final Offset targetPos;
  final Offset? snappedPos;
  final DxfSnapType? snapType;
  final StructuralDrawTool activeTool;
  final StructuralColumn? previewColumn;
  final Offset? wallStartPos;
  final List<Offset>? slabPoints;
  final double scale;

  const StructuralPointerPainter({
    required this.touchPos,
    required this.targetPos,
    this.snappedPos,
    this.snapType,
    required this.activeTool,
    this.previewColumn,
    this.wallStartPos,
    this.slabPoints,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveTip = snappedPos ?? targetPos;
    final bool isSnapped = snappedPos != null;

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

    // 2. Guideline Stem connecting finger to the offset target apex
    final double stemTopY = effectiveTip.dy + 12.0;
    final stemPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..isAntiAlias = true;

    final stemPath = Path()
      ..moveTo(touchPos.dx, touchPos.dy - 18)
      ..lineTo(effectiveTip.dx, stemTopY);

    canvas.drawPath(stemPath, glowPaint);
    canvas.drawPath(stemPath, stemPaint);

    // 3. Pointer Apex (Target Arrow)
    final arrowPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final arrowPath = Path()
      ..moveTo(effectiveTip.dx, effectiveTip.dy)
      ..lineTo(effectiveTip.dx + 8, effectiveTip.dy + 12)
      ..lineTo(effectiveTip.dx, effectiveTip.dy + 9)
      ..lineTo(effectiveTip.dx - 8, effectiveTip.dy + 12)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);

    // 4. Snap Marker & Text Badge
    if (isSnapped && snapType != null) {
      _drawSnapIndicator(canvas, effectiveTip, snapType!, themeColor);
    }

    // 5. Element Dimensions & Tool Preview Tag
    _drawPreviewTag(canvas, effectiveTip, isSnapped, themeColor);
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

  void _drawPreviewTag(
      Canvas canvas, Offset pos, bool isSnapped, Color color) {
    String text = '';
    if (activeTool == StructuralDrawTool.column && previewColumn != null) {
      final wCm = (previewColumn!.width * 100).round();
      final hCm = (previewColumn!.height * 100).round();
      text = previewColumn!.shape == ColumnShape.circular
          ? 'Колона Ø$wCm cm'
          : 'Колона $wCm x $hCm cm';
    } else if (activeTool == StructuralDrawTool.shearWall) {
      if (wallStartPos != null) {
        text = 'Шайба: край на стена';
      } else {
        text = 'Шайба: начало на стена';
      }
    } else if (activeTool == StructuralDrawTool.slab) {
      final count = slabPoints?.length ?? 0;
      text = 'Плоча: точка ${count + 1}';
    }

    if (text.isEmpty) return;

    if (isSnapped && snapType != null) {
      text = '$text (${snapType!.label})';
    }

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xCC000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeOffset = Offset(
      pos.dx - tp.width / 2.0,
      pos.dy - 26.0,
    );

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeOffset.dx - 6, badgeOffset.dy - 3, tp.width + 12, tp.height + 6),
      const Radius.circular(6),
    );

    final bgPaint = Paint()..color = const Color(0xE61E1E1E);
    final borderPaint = Paint()
      ..color = color
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
        oldDelegate.snapType != snapType ||
        oldDelegate.activeTool != activeTool ||
        oldDelegate.previewColumn != previewColumn ||
        oldDelegate.wallStartPos != wallStartPos ||
        oldDelegate.slabPoints != slabPoints;
  }
}
