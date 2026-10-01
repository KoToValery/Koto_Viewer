import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/structural_element.dart';

/// Interactive tool modes for structural drawing.
enum StructuralDrawTool {
  select(Icons.pan_tool_rounded),
  column(Icons.view_column_rounded),
  shearWall(Icons.line_weight_rounded),
  slab(Icons.crop_square_rounded),
  slabOpening(Icons.tab_unselected_rounded);

  final IconData icon;
  const StructuralDrawTool(this.icon);

  String label(AppLocalizations l10n) {
    switch (this) {
      case StructuralDrawTool.select:
        return l10n.toolNavigation;
      case StructuralDrawTool.column:
        return l10n.toolColumn;
      case StructuralDrawTool.shearWall:
        return l10n.toolShearWall;
      case StructuralDrawTool.slab:
        return l10n.toolSlab;
      case StructuralDrawTool.slabOpening:
        return l10n.toolOpening;
    }
  }
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
  final Offset? slabStartCornerPos;
  final List<Offset>? slabPoints;
  final double scale;
  final AppLocalizations? l10n;

  const StructuralPointerPainter({
    required this.touchPos,
    required this.targetPos,
    this.snappedPos,
    this.snapType,
    required this.activeTool,
    this.previewColumn,
    this.wallStartPos,
    this.slabStartCornerPos,
    this.slabPoints,
    this.scale = 1.0,
    this.l10n,
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

    // 5. Draw Element Footprint Silhouette at the Pointer Apex
    if (activeTool == StructuralDrawTool.column && previewColumn != null) {
      _drawColumnFootprint(canvas, effectiveTip, themeColor);
    } else if (activeTool == StructuralDrawTool.slab && slabStartCornerPos != null) {
      // Live rectangular slab preview on pointer overlay
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

    // 6. Element Dimensions & Tool Preview Tag
    _drawPreviewTag(canvas, effectiveTip, isSnapped, themeColor);
  }

  void _drawColumnFootprint(Canvas canvas, Offset tip, Color color) {
    final double wScreen = math.max(previewColumn!.width * 45.0, 16.0);
    final double hScreen = math.max(previewColumn!.height * 45.0, 16.0);

    final footFill = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final footBorder = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final anchorDot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (previewColumn!.shape == ColumnShape.circular) {
      final double r = wScreen / 2.0;
      final center = Offset(tip.dx + r, tip.dy + r);
      canvas.drawCircle(center, r, footFill);
      canvas.drawCircle(center, r, footBorder);
      // Small center cross
      canvas.drawLine(Offset(center.dx - 4, center.dy), Offset(center.dx + 4, center.dy), footBorder);
      canvas.drawLine(Offset(center.dx, center.dy - 4), Offset(center.dx, center.dy + 4), footBorder);
      // Top-Left anchor marker dot
      canvas.drawCircle(tip, 3.5, anchorDot);
    } else {
      // Top-Left anchor: Rect starts from tip (top-left)
      final rect = Rect.fromLTWH(tip.dx, tip.dy, wScreen, hScreen);
      canvas.drawRect(rect, footFill);
      canvas.drawRect(rect, footBorder);
      // Small center cross
      final center = rect.center;
      canvas.drawLine(Offset(center.dx - 4, center.dy), Offset(center.dx + 4, center.dy), footBorder);
      canvas.drawLine(Offset(center.dx, center.dy - 4), Offset(center.dx, center.dy + 4), footBorder);
      // Top-Left anchor marker dot
      canvas.drawCircle(tip, 3.5, anchorDot);
    }
  }

  String _getSnapTypeLabel(DxfSnapType type) {
    if (l10n != null) {
      switch (type) {
        case DxfSnapType.endpoint:
          return l10n!.snapEndpoint;
        case DxfSnapType.midpoint:
          return l10n!.snapMidpoint;
        case DxfSnapType.center:
          return l10n!.snapCenter;
        case DxfSnapType.nearest:
          return l10n!.snapNearest;
        case DxfSnapType.perpendicular:
          return l10n!.snapPerpendicular;
        case DxfSnapType.point:
          return l10n!.snapPoint;
      }
    }
    switch (type) {
      case DxfSnapType.endpoint:
        return 'Endpoint';
      case DxfSnapType.midpoint:
        return 'Midpoint';
      case DxfSnapType.center:
        return 'Center';
      case DxfSnapType.nearest:
        return 'Nearest';
      case DxfSnapType.perpendicular:
        return 'Perpendicular';
      case DxfSnapType.point:
        return 'Point';
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

  void _drawPreviewTag(
      Canvas canvas, Offset pos, bool isSnapped, Color color) {
    String text = '';
    if (activeTool == StructuralDrawTool.column && previewColumn != null) {
      final wCm = (previewColumn!.width * 100).round();
      final hCm = (previewColumn!.height * 100).round();
      if (l10n != null) {
        text = previewColumn!.shape == ColumnShape.circular
            ? l10n!.previewCircularColumnTag(wCm)
            : l10n!.previewColumnTag(wCm, hCm);
      } else {
        text = previewColumn!.shape == ColumnShape.circular
            ? 'Column Ø$wCm cm'
            : 'Column $wCm x $hCm cm';
      }
    } else if (activeTool == StructuralDrawTool.shearWall) {
      if (wallStartPos != null) {
        text = l10n?.previewWallEndTag ?? 'Shear Wall: end point';
      } else {
        text = l10n?.previewWallStartTag ?? 'Shear Wall: start point';
      }
    } else if (activeTool == StructuralDrawTool.slab) {
      if (slabStartCornerPos != null) {
        text = l10n?.previewSlabCorner2Tag ?? 'Slab: pick opposite corner';
      } else {
        text = l10n?.previewSlabCorner1Tag ?? 'Slab: pick 1st corner';
      }
    }

    if (text.isEmpty) return;

    if (isSnapped && snapType != null) {
      text = '$text (${_getSnapTypeLabel(snapType!)})';
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
        oldDelegate.slabStartCornerPos != slabStartCornerPos ||
        oldDelegate.slabPoints != slabPoints;
  }
}
