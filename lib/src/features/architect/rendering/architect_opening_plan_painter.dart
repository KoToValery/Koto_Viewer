import '../models/architect_document.dart';
import '../../bim_editing/properties/bim_distance_unit.dart';
import 'architect_vector_scene.dart';
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
    String? elementId,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool isSelected = false,
    bool outsideWall = false,
  }) {
    final scope = ArchitectTextScope.current;
    final annotationId = elementId ?? specId;
    final dimensionFontScale = scope == null
        ? null
        : scope.fontSize(annotationId, ArchitectAnnotationRole.opening) / 10;
    final symbolFontScale = scope == null
        ? null
        : scope.fontSize(annotationId, ArchitectAnnotationRole.opening) / 14;
    final halfThick = wallThickness / 2;
    final n = normal;
    final dimLinePaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(Colors.black87)
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;

    final wCm =
        ArchitectTextScope.current?.number(width) ??
        BimDistanceUnit.trimZeros((width * 100).toStringAsFixed(1));
    final hCm =
        ArchitectTextScope.current?.number(height) ??
        BimDistanceUnit.trimZeros((height * 100).toStringAsFixed(1));
    final sillCm =
        ArchitectTextScope.current?.number(sillHeight) ??
        BimDistanceUnit.trimZeros((sillHeight * 100).toStringAsFixed(1));

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

    final tpWidth = ArchitectTextPainter(
      elementId: annotationId,
      role: ArchitectAnnotationRole.opening,
      modelScale: dimensionFontScale,
      text: TextSpan(text: wCm, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final tpHeight = ArchitectTextPainter(
      elementId: annotationId,
      role: ArchitectAnnotationRole.opening,
      modelScale: dimensionFontScale,
      text: TextSpan(text: hCm, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final dimTextScale = dimensionFontScale ?? .10 / tpWidth.height;
    final numberWidth = math.max(tpWidth.width, tpHeight.width) * dimTextScale;
    final labelOffset = outsideWall ? halfThick + 0.08 + numberWidth / 2 : 0.0;
    final extDist = outsideWall
        ? halfThick + 0.16 + numberWidth
        : halfThick + extension;
    final dimStart = centerPos - n * (halfThick + 0.08);
    final dimEnd = centerPos + n * extDist;
    canvas.drawLine(dimStart, dimEnd, dimLinePaint);
    final labelPos = centerPos + n * labelOffset;

    canvas.save();
    canvas.translate(labelPos.dx, labelPos.dy);
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
    if (sillHeight > 0 && !outsideWall) {
      final tpSill = ArchitectTextPainter(
        elementId: annotationId,
        role: ArchitectAnnotationRole.opening,
        modelScale: dimensionFontScale,
        text: TextSpan(text: 'h=$sillCm', style: textStyle),
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

    if (outsideWall && sillHeight > 0) {
      final sill = ArchitectTextPainter(
        elementId: annotationId,
        role: ArchitectAnnotationRole.opening,
        modelScale: dimensionFontScale,
        text: TextSpan(text: 'h=$sillCm', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final sillScale = dimensionFontScale ?? .10 / sill.height;
      final pos = centerPos - n * (halfThick + 0.08 + .05);
      var angle = math.atan2(-n.dx, n.dy);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle <= -math.pi / 2) angle += math.pi;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.scale(sillScale);
      sill.paint(canvas, Offset(-sill.width / 2, -sill.height / 2));
      canvas.restore();
    }

    // Text ID inside circle (measured first so the circle tightly wraps it).
    final idPainter = ArchitectTextPainter(
      elementId: annotationId,
      role: ArchitectAnnotationRole.opening,
      modelScale: symbolFontScale,
      text: TextSpan(
        text: specId,
        style: TextStyle(
          color: isSelected
              ? const Color(0xFF00E5FF)
              : palette.foreground(Colors.black),
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Arial',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final idScale = symbolFontScale ?? .10 / idPainter.height;
    final textW = idPainter.width * idScale;
    final visualH = scope == null
        ? idPainter.height * idScale * ArchitectDrawingScale.fontCapRatio
        : scope.height(annotationId, ArchitectAnnotationRole.opening);
    final cornerPad = scope == null
        ? 0.025
        : ArchitectDrawingScale(scope.denominator).paperToModel(0.35);
    final badgeR = Offset(textW / 2, visualH / 2).distance + cornerPad;
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

    final idMetrics = idPainter.computeLineMetrics();
    final idCenterY = idMetrics.isNotEmpty
        ? idMetrics.first.baseline - (visualH / idScale) / 2
        : idPainter.height / 2.0;
    canvas.save();
    canvas.translate(badgeCenter.dx, badgeCenter.dy);
    canvas.scale(idScale);
    idPainter.paint(
      canvas,
      Offset(-idPainter.width / 2.0, -idCenterY),
    );
    canvas.restore();
  }

  static bool containsPoint(
    Offset point, {
    required Offset center,
    required Offset normal,
    required double wallThickness,
    required double tolerance,
    double? width,
    double? height,
    bool outsideWall = false,
    double sillHeight = 0,
  }) {
    final delta = point - center;
    final along = delta.dx * normal.dx + delta.dy * normal.dy;
    final across = delta.dx * normal.dy - delta.dy * normal.dx;
    final half = wallThickness / 2;
    var reach = extension;
    if (outsideWall && width != null && height != null) {
      final numbers = ArchitectTextPainter(
        text: TextSpan(
          text: '${(width * 100).round()}\n${(height * 100).round()}',
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Arial',
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      reach = .16 + numbers.width * .20 / numbers.height;
    }
    if (outsideWall && sillHeight > .001) {
      final sill = ArchitectTextPainter(
        text: TextSpan(
          text: 'h=${(sillHeight * 100).round()}',
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'Arial',
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (along >= -half - .18 - tolerance &&
          along <= -half - .08 + tolerance &&
          across.abs() <= sill.width * .05 / sill.height + tolerance) {
        return true;
      }
    }
    final badge = center + normal * (half + reach + badgeRadius);
    if ((point - badge).distance <= badgeRadius + tolerance) return true;
    return along >= -half - 0.08 - tolerance &&
        along <= half + reach + tolerance &&
        across.abs() <= 0.15 + tolerance;
  }

  static void _paintWallFaceLines({
    required Canvas canvas,
    required Offset center,
    required Offset direction,
    required Offset normal,
    required double halfSpanLength,
    required double wallThickness,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    required bool isSelected,
  }) {
    if (halfSpanLength <= 0.005) return;
    final projection = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF546E7A))
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;
    final halfSpan = direction * halfSpanLength;
    for (final sign in [-1.0, 1.0]) {
      final face = center + normal * (sign * wallThickness / 2);
      canvas.drawLine(face - halfSpan, face + halfSpan, projection);
    }
  }

  /// Threshold / step lines across a door opening in 2D plan when [sillHeight] > 0.
  static void paintDoorStep({
    required Canvas canvas,
    required Offset center,
    required Offset direction,
    required Offset normal,
    required double width,
    required double frameThickness,
    required double wallThickness,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    required double sillHeight,
    bool isSelected = false,
  }) {
    if (sillHeight <= 0.001) return;
    _paintWallFaceLines(
      canvas: canvas,
      center: center,
      direction: direction,
      normal: normal,
      halfSpanLength: math.max(0.0, width / 2 - frameThickness),
      wallThickness: wallThickness,
      zoomScale: zoomScale,
      palette: palette,
      isSelected: isSelected,
    );
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
    required double sillHeight,
    bool isSelected = false,
  }) {
    if (sillHeight <= .001) return;
    _paintWallFaceLines(
      canvas: canvas,
      center: center,
      direction: direction,
      normal: exteriorNormal,
      halfSpanLength: width / 2,
      wallThickness: wallThickness,
      zoomScale: zoomScale,
      palette: palette,
      isSelected: isSelected,
    );
    final projection = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF546E7A))
      ..strokeWidth = .8 / zoomScale
      ..style = PaintingStyle.stroke;
    final ledge = center + exteriorNormal * (wallThickness / 2 + 0.04);
    final end = direction * (width / 2 + 0.05);
    for (final sign in [-1.0, 1.0]) {
      final point = ledge + end * sign;
      canvas.drawLine(point, point - exteriorNormal * .04, projection);
    }
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

  /// A closed pane with glazing beads and, for an operable pane, sash end caps.
  static void paintWindowPane({
    required Canvas canvas,
    required Offset left,
    required Offset right,
    required Offset direction,
    required Offset normal,
    required double frameDepth,
    required double glazingThickness,
    required bool openable,
    bool glazed = true,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool isSelected = false,
  }) {
    final length = (right - left).distance;
    if (length < .01) return;
    final cap = openable ? math.min(.025, length / 4) : 0.0;
    final depth = math.min(frameDepth / 2, .03);
    final frame = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF37474F))
      ..strokeWidth = 1 / zoomScale
      ..style = PaintingStyle.stroke;
    if (openable) {
      for (final (point, sign) in [(left, 1.0), (right, -1.0)]) {
        final a = point - normal * depth, b = point + normal * depth;
        final across = direction * (sign * cap);
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo((b + across).dx, (b + across).dy)
            ..lineTo((a + across).dx, (a + across).dy)
            ..close(),
          frame,
        );
      }
      for (final sign in [-1.0, 1.0]) {
        canvas.drawLine(
          left + normal * (sign * depth),
          right + normal * (sign * depth),
          frame,
        );
      }
    }
    if (!glazed) {
      final a = left - normal * depth, b = right - normal * depth;
      final c = right + normal * depth, d = left + normal * depth;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        frame,
      );
      return;
    }
    final glass = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF0288D1))
      ..strokeWidth = .8 / zoomScale;
    for (final sign in [-1.0, 1.0]) {
      final shift = normal * (sign * glazingThickness / 2);
      canvas.drawLine(
        left + direction * cap + shift,
        right - direction * cap + shift,
        glass,
      );
    }
  }
}
