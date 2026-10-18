import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'architect_canvas_palette.dart';

/// Shared model-space opening dimensions and specification badge for plan views.
/// Text sizes follow the architectural door symbol at every zoom level.
class ArchitectOpeningPlanPainter {
  ArchitectOpeningPlanPainter._();

  static const badgeRadius = 0.16;
  static const extension = 0.22;

  static void paint({
    required Canvas canvas,
    required Offset centerPos,
    required Offset normal,
    required double wallThickness,
    required double width,
    required double height,
    required double sillHeight,
    required String specId,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool isSelected = false,
  }) {
    final halfThick = wallThickness / 2;
    final n = normal;
    final dimLinePaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(Colors.black87)
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;

    // Dimension line and text follow door.dxf New_razmer.
    // Transverse dimension line passing perpendicularly through center of opening
    const badgeR = badgeRadius;
    final extDist = halfThick + extension;
    final dimStart = centerPos - n * (halfThick + 0.08);
    final dimEnd = centerPos + n * extDist;
    canvas.drawLine(dimStart, dimEnd, dimLinePaint);

    final wCm = (width * 100).round();
    final hCm = (height * 100).round();
    final sillCm = (sillHeight * 100).round();

    // Paint dimension numbers on both sides of the transverse line, parallel to the line
    // Static architectural size in model space: does not balloon up upon zoom-out
    final textStyle = TextStyle(
      color: isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(Colors.black),
      fontSize: 10.0,
      fontWeight: FontWeight.bold,
      fontFamily: 'Arial',
      height: 1.0,
    );

    final tpWidth = TextPainter(
      text: TextSpan(text: '$wCm', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final tpHeight = TextPainter(
      text: TextSpan(text: '$hCm', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Static model height ~0.10m (10 cm text height)
    final dimTextScale = 0.10 / tpWidth.height;

    canvas.save();
    canvas.translate(centerPos.dx, centerPos.dy);
    double dimAngle = math.atan2(n.dy, n.dx);
    if (dimAngle > math.pi / 2) {
      dimAngle -= math.pi;
    } else if (dimAngle <= -math.pi / 2) {
      dimAngle += math.pi;
    }
    canvas.rotate(dimAngle);
    canvas.scale(dimTextScale);

    // Position above and below the dimension line
    tpWidth.paint(canvas, Offset(-tpWidth.width / 2.0, -tpWidth.height - 2.0));
    tpHeight.paint(canvas, Offset(-tpHeight.width / 2.0, 3.0));

    // Sill height text if > 0 (e.g. h=15)
    if (sillCm > 0) {
      final tpSill = TextPainter(
        text: TextSpan(
          text: 'h=$sillCm',
          style: TextStyle(
            color: palette.foreground(const Color(0xFF00838F)),
            fontSize: 9.0,
            fontWeight: FontWeight.w600,
            fontFamily: 'Arial',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpSill.paint(
        canvas,
        Offset(
          math.max(tpWidth.width, tpHeight.width) / 2.0 + 4.0,
          -tpSill.height / 2.0,
        ),
      );
    }
    canvas.restore();

    // Specification circle badge follows door.dxf New_ID.
    // Positioned at the end of the extended dimension line touching circumference.
    // Static in model coordinates: never balloons up upon zoom-out.
    // Circle interior is transparent (outline only, no solid hatch).
    final badgeCenter = centerPos + n * (extDist + badgeR);

    // Circle border (outline only, transparent interior)
    canvas.drawCircle(
      badgeCenter,
      badgeR,
      Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(const Color(0xFF263238))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 1.6 : 1.0) / zoomScale,
    );

    // Text ID inside circle (static ~0.14m height)
    final idPainter = TextPainter(
      text: TextSpan(
        text: specId,
        style: TextStyle(
          color: isSelected
              ? const Color(0xFF00E5FF)
              : palette.foreground(Colors.black),
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Arial',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final idScale = 0.14 / idPainter.height;
    canvas.save();
    canvas.translate(badgeCenter.dx, badgeCenter.dy);
    canvas.scale(idScale);
    idPainter.paint(
      canvas,
      Offset(-idPainter.width / 2.0, -idPainter.height / 2.0),
    );
    canvas.restore();
  }

  static bool containsPoint(
    Offset point, {
    required Offset center,
    required Offset normal,
    required double wallThickness,
    required double tolerance,
  }) {
    final delta = point - center;
    final along = delta.dx * normal.dx + delta.dy * normal.dy;
    final across = delta.dx * normal.dy - delta.dy * normal.dx;
    final half = wallThickness / 2;
    final badge = center + normal * (half + extension + badgeRadius);
    if ((point - badge).distance <= badgeRadius + tolerance) return true;
    return along >= -half - 0.08 - tolerance &&
        along <= half + extension + tolerance &&
        across.abs() <= 0.15 + tolerance;
  }

  /// Thin exterior ledge, 4 cm in front of the wall and 5 cm past each jamb.
  static void paintWindowSill({
    required Canvas canvas,
    required Offset center,
    required Offset direction,
    required Offset exteriorNormal,
    required double width,
    required double wallThickness,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool isSelected = false,
  }) {
    final ledge = center + exteriorNormal * (wallThickness / 2 + 0.04);
    final end = direction * (width / 2 + 0.05);
    canvas.drawLine(
      ledge - end,
      ledge + end,
      Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(const Color(0xFF78909C))
        ..strokeWidth = 0.8 / zoomScale
        ..style = PaintingStyle.stroke,
    );
  }
}
