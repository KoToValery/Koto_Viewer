import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_underlay_models.dart';
import 'architect_canvas_palette.dart';
import 'architect_elements_painter_helper.dart';

/// Independent background layer rendering Raster Underlays (`A-RAST`),
/// CAD Xref Underlays (`A-XREF`), and Geodetic Contours & Spot Elevations (`G-TOPO`).
class ArchitectUnderlayPainter extends CustomPainter {
  final DxfDocument? document;
  final ArchitectCanvasPalette palette;
  final BimCoordinateFrame frame;
  final BimViewportController viewport;
  final Map<String, bool> visibility;
  final List<ArchitectRasterUnderlay> rasterUnderlays;
  final Map<String, ui.Image> rasterImages;
  final String? selectedRasterId;
  final bool showRasterLayer;
  final bool showGeodesyLayer;
  final List<ArchitectGeodeticContour> geodeticContours;
  final List<ArchitectGeodeticPoint> geodeticPoints;
  final Offset? calibrationP1;
  final Offset? calibrationP2;
  final Offset? calibrationCursor;
  final ArchitectCadUnderlayConfig? cadConfig;
  final List<Offset>? maskDraftPoints;
  final bool isMaskDrafting;

  ArchitectUnderlayPainter({
    required this.document,
    this.palette = const ArchitectCanvasPalette.light(),
    required this.frame,
    required this.viewport,
    required this.visibility,
    this.rasterUnderlays = const [],
    this.rasterImages = const {},
    this.selectedRasterId,
    this.showRasterLayer = true,
    this.showGeodesyLayer = true,
    this.geodeticContours = const [],
    this.geodeticPoints = const [],
    this.calibrationP1,
    this.calibrationP2,
    this.calibrationCursor,
    this.cadConfig,
    this.maskDraftPoints,
    this.isMaskDrafting = false,
  }) : super(repaint: viewport);

  @override
  void paint(Canvas canvas, Size size) {
    final hasCad = document != null;
    final hasRaster = showRasterLayer && rasterUnderlays.isNotEmpty;
    final hasTopo =
        showGeodesyLayer &&
        (geodeticContours.isNotEmpty || geodeticPoints.isNotEmpty);
    final hasCalibration = calibrationP1 != null || calibrationCursor != null;
    final hasMaskDraft =
        isMaskDrafting && maskDraftPoints != null && maskDraftPoints!.isNotEmpty;

    if (!hasCad &&
        !hasRaster &&
        !hasTopo &&
        !hasCalibration &&
        !hasMaskDraft) {
      return;
    }

    // 1. Paint Raster Underlays (A-RAST) in model space
    if (hasRaster) {
      canvas.save();
      canvas.translate(viewport.translation.dx, viewport.translation.dy);
      canvas.scale(viewport.scale);

      for (final raster in rasterUnderlays) {
        if (!raster.visible) continue;
        final img = rasterImages[raster.id];
        if (img == null) continue;

        canvas.save();
        if (raster.hasActiveMask) {
          final clipPath = Path()
            ..moveTo(
              raster.maskPolygon!.first.dx,
              raster.maskPolygon!.first.dy,
            );
          for (var i = 1; i < raster.maskPolygon!.length; i++) {
            clipPath.lineTo(
              raster.maskPolygon![i].dx,
              raster.maskPolygon![i].dy,
            );
          }
          clipPath.close();
          canvas.clipPath(clipPath);
        }

        canvas.translate(raster.position.dx, raster.position.dy);
        if (raster.rotationRad.abs() > 1e-7) {
          canvas.rotate(raster.rotationRad);
        }
        final srcRect = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final dstRect = Rect.fromLTWH(
          0,
          0,
          raster.widthMeters,
          raster.heightMeters,
        );
        final imgPaint = Paint()
          ..color = Color.fromRGBO(
            255,
            255,
            255,
            raster.opacity.clamp(0.05, 1.0),
          )
          ..filterQuality = FilterQuality.medium;
        canvas.drawImageRect(img, srcRect, dstRect, imgPaint);

        if (raster.id == selectedRasterId) {
          final borderPaint = Paint()
            ..color = const Color(0xFF0288D1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / viewport.scale;
          canvas.drawRect(dstRect, borderPaint);
        }
        canvas.restore();

        // Draw mask boundary outline
        if (raster.hasActiveMask &&
            (raster.id == selectedRasterId || isMaskDrafting)) {
          final maskPath = Path()
            ..moveTo(
              raster.maskPolygon!.first.dx,
              raster.maskPolygon!.first.dy,
            );
          for (var i = 1; i < raster.maskPolygon!.length; i++) {
            maskPath.lineTo(
              raster.maskPolygon![i].dx,
              raster.maskPolygon![i].dy,
            );
          }
          maskPath.close();
          final maskPaint = Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3 / viewport.scale;
          canvas.drawPath(maskPath, maskPaint);
        }
      }
      canvas.restore();
    }

    // 2. Paint CAD Xref Underlay (A-XREF)
    if (hasCad) {
      canvas.save();
      canvas.translate(viewport.translation.dx, viewport.translation.dy);
      canvas.scale(viewport.scale);

      final hasCadMask = cadConfig?.hasActiveMask ?? false;
      if (hasCadMask) {
        canvas.save();
        final clipPath = Path()
          ..moveTo(
            cadConfig!.maskPolygon!.first.dx,
            cadConfig!.maskPolygon!.first.dy,
          );
        for (var i = 1; i < cadConfig!.maskPolygon!.length; i++) {
          clipPath.lineTo(
            cadConfig!.maskPolygon![i].dx,
            cadConfig!.maskPolygon![i].dy,
          );
        }
        clipPath.close();
        canvas.clipPath(clipPath);
      }

      canvas.save();
      canvas.scale(1.0 / frame.unitsPerMeter);
      canvas.translate(-frame.origin.dx, -frame.origin.dy);
      ArchitectElementsPainterHelper.drawUnderlay(
        canvas: canvas,
        palette: palette,
        underlayDoc: document,
        zoomScale: viewport.scale / frame.unitsPerMeter,
        layerVisibility: visibility,
        visibleRect: frame
            .rectToCad(viewport.visibleRect)
            .inflate(2 * frame.unitsPerMeter / viewport.scale),
      );
      canvas.restore();

      if (hasCadMask) {
        canvas.restore(); // restore clip
        final maskPath = Path()
          ..moveTo(
            cadConfig!.maskPolygon!.first.dx,
            cadConfig!.maskPolygon!.first.dy,
          );
        for (var i = 1; i < cadConfig!.maskPolygon!.length; i++) {
          maskPath.lineTo(
            cadConfig!.maskPolygon![i].dx,
            cadConfig!.maskPolygon![i].dy,
          );
        }
        maskPath.close();
        final maskPaint = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 / viewport.scale;
        canvas.drawPath(maskPath, maskPaint);
      }

      canvas.restore();
    }

    // 3. Paint Geodetic Contours & Spot Elevations (G-TOPO) - Print-First Style
    if (hasTopo) {
      _paintGeodesyLayer(canvas);
    }

    // 4. Paint 2-Point Calibration Overlay & Precision Magnifier Loupe
    if (hasCalibration) {
      _paintCalibrationOverlay(canvas, size);
    }

    // 5. Paint Mask Drafting Preview
    if (hasMaskDraft) {
      _paintMaskDraft(canvas);
    }
  }

  void _paintMaskDraft(Canvas canvas) {
    if (maskDraftPoints == null || maskDraftPoints!.isEmpty) return;

    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);

    final previewPath = Path()
      ..moveTo(maskDraftPoints!.first.dx, maskDraftPoints!.first.dy);
    for (var i = 1; i < maskDraftPoints!.length; i++) {
      previewPath.lineTo(maskDraftPoints![i].dx, maskDraftPoints![i].dy);
    }
    if (maskDraftPoints!.length >= 3) {
      previewPath.close();
      final fillPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(previewPath, fillPaint);
    }
    final strokePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / viewport.scale;
    canvas.drawPath(previewPath, strokePaint);

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / viewport.scale;
    for (final pt in maskDraftPoints!) {
      canvas.drawCircle(pt, 4.0 / viewport.scale, handlePaint);
      canvas.drawCircle(pt, 4.0 / viewport.scale, handleBorder);
    }
    canvas.restore();
  }

  void _paintGeodesyLayer(Canvas canvas) {
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);

    final isDark = palette.isDark;
    final majorColor = isDark
        ? const Color(0xFFD7B899)
        : const Color(0xFF6D4C41);
    final minorColor = isDark
        ? const Color(0xFF9E8672).withValues(alpha: 0.72)
        : const Color(0xFF8D6E63).withValues(alpha: 0.68);
    final spotColor = isDark
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF37474F);

    final majorPaint = Paint()
      ..color = majorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 / viewport.scale;

    final minorPaint = Paint()
      ..color = minorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75 / viewport.scale;

    for (final contour in geodeticContours) {
      if (contour.points.length < 2) continue;
      final path = Path()
        ..moveTo(contour.points.first.dx, contour.points.first.dy);
      for (var i = 1; i < contour.points.length; i++) {
        path.lineTo(contour.points[i].dx, contour.points[i].dy);
      }
      if (contour.closed) path.close();
      canvas.drawPath(path, contour.isMajor ? majorPaint : minorPaint);

      // Draw elevation label on major contours (or when zoomed in sufficiently)
      if ((contour.isMajor || viewport.scale >= 25.0) &&
          viewport.scale >= 6.0 &&
          contour.points.length >= 2) {
        final midIdx = contour.points.length ~/ 2;
        final pA = contour.points[(midIdx - 1).clamp(0, contour.points.length - 1)];
        final pB = contour.points[midIdx];
        final mid = Offset((pA.dx + pB.dx) * 0.5, (pA.dy + pB.dy) * 0.5);
        var angle = math.atan2(pB.dy - pA.dy, pB.dx - pA.dx);
        if (angle > math.pi / 2) angle -= math.pi;
        if (angle < -math.pi / 2) angle += math.pi;

        final label = contour.elevation.toStringAsFixed(2);
        final fontSize = (10.5 / viewport.scale).clamp(0.08, 1.2);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: majorColor,
              fontSize: fontSize,
              fontWeight: contour.isMajor ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        canvas.rotate(angle);
        final bgRect = Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 2.0 / viewport.scale,
          height: tp.height,
        );
        canvas.drawRect(
          bgRect,
          Paint()..color = palette.background.withValues(alpha: 0.88),
        );
        tp.paint(canvas, Offset(-tp.width * 0.5, -tp.height * 0.5));
        canvas.restore();
      }
    }

    // Spot elevations (+ tick and elevation text)
    if (viewport.scale >= 8.0 && geodeticPoints.isNotEmpty) {
      final tickHalf = (3.5 / viewport.scale).clamp(0.05, 0.45);
      final tickPaint = Paint()
        ..color = spotColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / viewport.scale;
      final fontSize = (10.0 / viewport.scale).clamp(0.07, 1.0);

      for (final pt in geodeticPoints) {
        final pos = pt.position;
        canvas.drawLine(
          Offset(pos.dx - tickHalf, pos.dy),
          Offset(pos.dx + tickHalf, pos.dy),
          tickPaint,
        );
        canvas.drawLine(
          Offset(pos.dx, pos.dy - tickHalf),
          Offset(pos.dx, pos.dy + tickHalf),
          tickPaint,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: pt.elevation.toStringAsFixed(2),
            style: TextStyle(
              color: spotColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(pos.dx + tickHalf * 1.3, pos.dy - tp.height * 0.5),
        );
      }
    }

    canvas.restore();
  }

  void _paintCalibrationOverlay(Canvas canvas, Size size) {
    final p1Screen = calibrationP1 != null
        ? calibrationP1! * viewport.scale + viewport.translation
        : null;
    final p2Screen = calibrationP2 != null
        ? calibrationP2! * viewport.scale + viewport.translation
        : (calibrationCursor != null
              ? calibrationCursor! * viewport.scale + viewport.translation
              : null);

    final accentColor = const Color(0xFFD84315);
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (p1Screen != null && p2Screen != null) {
      canvas.drawLine(p1Screen, p2Screen, linePaint);
    }
    if (p1Screen != null) {
      _drawCalibrationCrosshair(canvas, p1Screen, 'P1', accentColor);
    }
    if (p2Screen != null) {
      _drawCalibrationCrosshair(canvas, p2Screen, 'P2', accentColor);
    }

    // Draw Magnifier Loupe in top-right when cursor is over a raster underlay
    final cursorModel = calibrationCursor;
    if (cursorModel != null && selectedRasterId != null) {
      final raster = rasterUnderlays
          .where((r) => r.id == selectedRasterId)
          .firstOrNull;
      final img = raster != null ? rasterImages[raster.id] : null;
      if (raster != null && img != null && raster.containsLocalPoint(cursorModel)) {
        final px = raster.localToPixel(cursorModel);
        const loupeRadius = 54.0;
        final loupeCenter = Offset(size.width - loupeRadius - 20, loupeRadius + 68);
        const sampleHalfPx = 28.0;
        final srcRect = Rect.fromLTRB(
          (px.dx - sampleHalfPx).clamp(0.0, img.width.toDouble()),
          (px.dy - sampleHalfPx).clamp(0.0, img.height.toDouble()),
          (px.dx + sampleHalfPx).clamp(0.0, img.width.toDouble()),
          (px.dy + sampleHalfPx).clamp(0.0, img.height.toDouble()),
        );
        final dstRect = Rect.fromCircle(
          center: loupeCenter,
          radius: loupeRadius,
        );

        canvas.save();
        canvas.clipPath(Path()..addOval(dstRect));
        canvas.drawRect(dstRect, Paint()..color = Colors.white);
        canvas.drawImageRect(
          img,
          srcRect,
          dstRect,
          Paint()..filterQuality = FilterQuality.none,
        );
        // Crosshair inside loupe
        final chPaint = Paint()
          ..color = accentColor
          ..strokeWidth = 1.25;
        canvas.drawLine(
          Offset(loupeCenter.dx - loupeRadius, loupeCenter.dy),
          Offset(loupeCenter.dx + loupeRadius, loupeCenter.dy),
          chPaint,
        );
        canvas.drawLine(
          Offset(loupeCenter.dx, loupeCenter.dy - loupeRadius),
          Offset(loupeCenter.dx, loupeCenter.dy + loupeRadius),
          chPaint,
        );
        canvas.restore();

        canvas.drawCircle(
          loupeCenter,
          loupeRadius,
          Paint()
            ..color = accentColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }
  }

  void _drawCalibrationCrosshair(
    Canvas canvas,
    Offset screenPos,
    String label,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(screenPos, 7.0, paint);
    canvas.drawLine(
      Offset(screenPos.dx - 12, screenPos.dy),
      Offset(screenPos.dx + 12, screenPos.dy),
      paint,
    );
    canvas.drawLine(
      Offset(screenPos.dx, screenPos.dy - 12),
      Offset(screenPos.dx, screenPos.dy + 12),
      paint,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(screenPos.dx + 9, screenPos.dy - 18));
  }

  @override
  bool shouldRepaint(covariant ArchitectUnderlayPainter oldDelegate) =>
      palette.isDark != oldDelegate.palette.isDark ||
      document != oldDelegate.document ||
      frame != oldDelegate.frame ||
      viewport != oldDelegate.viewport ||
      !mapEquals(visibility, oldDelegate.visibility) ||
      !listEquals(rasterUnderlays, oldDelegate.rasterUnderlays) ||
      rasterImages.length != oldDelegate.rasterImages.length ||
      selectedRasterId != oldDelegate.selectedRasterId ||
      showRasterLayer != oldDelegate.showRasterLayer ||
      showGeodesyLayer != oldDelegate.showGeodesyLayer ||
      !listEquals(geodeticContours, oldDelegate.geodeticContours) ||
      !listEquals(geodeticPoints, oldDelegate.geodeticPoints) ||
      calibrationP1 != oldDelegate.calibrationP1 ||
      calibrationP2 != oldDelegate.calibrationP2 ||
      calibrationCursor != oldDelegate.calibrationCursor ||
      cadConfig != oldDelegate.cadConfig ||
      isMaskDrafting != oldDelegate.isMaskDrafting ||
      !listEquals(maskDraftPoints, oldDelegate.maskDraftPoints);
}
