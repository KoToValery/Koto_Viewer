import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// Multi-Layer Composite CustomPainter for complete PCB projects.
class PcbMultiLayerPainter extends CustomPainter {
  final PcbProject project;
  final PcbTheme theme;
  final bool showGrid;
  final double scaleFactor;

  const PcbMultiLayerPainter({
    required this.project,
    required this.theme,
    this.showGrid = true,
    this.scaleFactor = 10.0, // 1 mm = 10 canvas pixels
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = project.boundingBox;
    const margin = 24.0;

    final double boardW = math.max(10.0, bounds.widthMm * scaleFactor);
    final double boardH = math.max(10.0, bounds.heightMm * scaleFactor);

    // 1. Draw Substrate Board (FR4 / Matte / Color)
    final boardRect = Rect.fromLTWH(margin, margin, boardW, boardH);
    final substratePaint = Paint()
      ..color = theme.substrate
      ..style = PaintingStyle.fill;
    final boardRRect = RRect.fromRectAndRadius(boardRect, const Radius.circular(8));
    canvas.drawRRect(boardRRect, substratePaint);

    // Board outline
    final boardOutlinePaint = Paint()
      ..color = theme.outline.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(boardRRect, boardOutlinePaint);

    // 2. Draw Measurement Grid
    if (showGrid) {
      _drawGrid(canvas, boardRect, scaleFactor);
    }

    final isBottomView = project.viewSide == PcbViewSide.bottom;

    // Filter layers based on current view side (Top, Bottom, or Composite)
    final List<PcbLayerItem> activeLayers = [];
    for (final layer in project.layers) {
      if (!layer.isVisible) continue;
      final lowerName = layer.fileName.toLowerCase();

      if (project.viewSide == PcbViewSide.top) {
        if (layer.type == PcbLayerType.copperBottom ||
            layer.type == PcbLayerType.solderMaskBottom ||
            layer.type == PcbLayerType.silkscreenBottom ||
            (layer.type == PcbLayerType.generic && (lowerName.contains('bot') || lowerName.contains('bottom')))) {
          continue; // Skip bottom layers in Top view
        }
      } else if (project.viewSide == PcbViewSide.bottom) {
        if (layer.type == PcbLayerType.copperTop ||
            layer.type == PcbLayerType.solderMaskTop ||
            layer.type == PcbLayerType.silkscreenTop ||
            (layer.type == PcbLayerType.generic && (lowerName.contains('top') || lowerName.contains('front')))) {
          continue; // Skip top layers in Bottom view
        }
      }
      activeLayers.add(layer);
    }

    // Sort by render order
    activeLayers.sort((a, b) => a.order.compareTo(b.order));

    canvas.save();
    if (isBottomView) {
      // Mirror X across the board center for realistic bottom inspection
      canvas.translate(margin * 2 + boardW, 0);
      canvas.scale(-1.0, 1.0);
    }

    // Coordinate mapping: (x_mm, y_mm) -> (canvas_x, canvas_y)
    Offset mapPoint(Offset p) {
      final x = margin + (p.dx - bounds.minX) * scaleFactor;
      final y = margin + (bounds.maxY - p.dy) * scaleFactor; // Invert Y (CAD Y up -> Canvas Y down)
      return Offset(x, y);
    }

    // 3. Render all active layers
    for (final layer in activeLayers) {
      final layerColor = layer.customColor ?? _resolveLayerColor(layer.type, theme, project.viewSide);
      final effectiveColor = layerColor.withValues(alpha: layerColor.a * layer.opacity);

      _renderLayer(
        canvas: canvas,
        document: layer.document,
        color: effectiveColor,
        mapPoint: mapPoint,
        scaleFactor: scaleFactor,
      );
    }

    canvas.restore();
  }

  void _renderLayer({
    required Canvas canvas,
    required PcbDocument document,
    required Color color,
    required Offset Function(Offset) mapPoint,
    required double scaleFactor,
  }) {
    final isDrillLayer = document.layerType == PcbLayerType.drill;
    final hasClearPolarity = document.commands.any((c) => !c.isDark);
    if (hasClearPolarity) {
      canvas.saveLayer(null, Paint());
    }

    // 1. Draw Gerber Commands (Tracks, Arcs, Pads, Regions)
    for (final cmd in document.commands) {
      final isClear = !cmd.isDark;
      final cmdColor = isClear ? const Color(0xFF000000) : color;
      final blend = isClear ? BlendMode.clear : BlendMode.srcOver;

      switch (cmd.type) {
        case PcbCommandType.line:
          final p1 = mapPoint(cmd.p1);
          final p2 = mapPoint(cmd.p2!);
          final widthPx = math.max(0.5, (cmd.aperture?.dimX ?? 0.25) * scaleFactor);

          final trackPaint = Paint()
            ..color = cmdColor
            ..blendMode = blend
            ..strokeWidth = widthPx
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1, p2, trackPaint);
          break;

        case PcbCommandType.arc:
          final center = mapPoint(cmd.center!);
          final radPx = (cmd.radius ?? 1.0) * scaleFactor;
          final widthPx = math.max(0.5, (cmd.aperture?.dimX ?? 0.25) * scaleFactor);

          final arcPaint = Paint()
            ..color = cmdColor
            ..blendMode = blend
            ..strokeWidth = widthPx
            ..style = PaintingStyle.stroke;

          final sweep = cmd.endAngle! - cmd.startAngle!;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radPx),
            -cmd.startAngle!,
            -sweep,
            false,
            arcPaint,
          );
          break;

        case PcbCommandType.flash:
          final pos = mapPoint(cmd.p1);
          final ap = cmd.aperture;
          final apType = ap?.type ?? PcbApertureType.circle;

          if (isDrillLayer) {
            final radiusPx = math.max(1.0, ((ap?.dimX ?? 0.8) / 2.0) * scaleFactor);
            // Annular copper ring
            final ringPaint = Paint()
              ..color = theme.copper.withValues(alpha: 0.9)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(pos, math.max(radiusPx + 1.8, 2.5), ringPaint);
            // Dark hole center
            final holePaint = Paint()
              ..color = const Color(0xFF0A0A0A)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(pos, radiusPx, holePaint);
          } else {
            final padPaint = Paint()
              ..color = cmdColor
              ..blendMode = blend
              ..style = PaintingStyle.fill;

            if (ap?.polygonPoints != null && ap!.polygonPoints!.isNotEmpty) {
              final path = Path();
              final first = ap.polygonPoints!.first;
              path.moveTo(pos.dx + first.dx * scaleFactor, pos.dy - first.dy * scaleFactor);
              for (int i = 1; i < ap.polygonPoints!.length; i++) {
                final pt = ap.polygonPoints![i];
                path.lineTo(pos.dx + pt.dx * scaleFactor, pos.dy - pt.dy * scaleFactor);
              }
              path.close();
              canvas.drawPath(path, padPaint);
            } else if (apType == PcbApertureType.circle) {
              final radiusPx = ((ap?.dimX ?? 1.0) / 2.0) * scaleFactor;
              canvas.drawCircle(pos, math.max(0.8, radiusPx), padPaint);
            } else if (apType == PcbApertureType.rectangle) {
              final wPx = (ap?.dimX ?? 1.0) * scaleFactor;
              final hPx = (ap?.dimY ?? 1.0) * scaleFactor;
              canvas.drawRect(
                Rect.fromCenter(center: pos, width: wPx, height: hPx),
                padPaint,
              );
            } else if (apType == PcbApertureType.obround) {
              final wPx = (ap?.dimX ?? 1.5) * scaleFactor;
              final hPx = (ap?.dimY ?? 1.0) * scaleFactor;
              final r = math.min(wPx, hPx) / 2.0;
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromCenter(center: pos, width: wPx, height: hPx),
                  Radius.circular(r),
                ),
                padPaint,
              );
            } else {
              final radiusPx = ((ap?.dimX ?? 1.0) / 2.0) * scaleFactor;
              canvas.drawCircle(pos, math.max(0.8, radiusPx), padPaint);
            }
          }
          break;

        case PcbCommandType.region:
          final regionPaint = Paint()
            ..color = cmdColor
            ..blendMode = blend
            ..style = PaintingStyle.fill;

          final path = Path()..fillType = PathFillType.evenOdd;
          if (cmd.regionContours != null && cmd.regionContours!.isNotEmpty) {
            for (final contour in cmd.regionContours!) {
              if (contour.length < 2) continue;
              final first = mapPoint(contour.first);
              path.moveTo(first.dx, first.dy);
              for (int i = 1; i < contour.length; i++) {
                final pt = mapPoint(contour[i]);
                path.lineTo(pt.dx, pt.dy);
              }
              path.close();
            }
            canvas.drawPath(path, regionPaint);
          } else if (cmd.regionPoints != null && cmd.regionPoints!.length >= 3) {
            final first = mapPoint(cmd.regionPoints!.first);
            path.moveTo(first.dx, first.dy);
            for (int i = 1; i < cmd.regionPoints!.length; i++) {
              final pt = mapPoint(cmd.regionPoints![i]);
              path.lineTo(pt.dx, pt.dy);
            }
            path.close();
            canvas.drawPath(path, regionPaint);
          }
          break;
      }
    }

    if (hasClearPolarity) {
      canvas.restore();
    }

    // 2. Draw Drill Holes with annular copper ring & dark through-hole
    for (final hole in document.drillHoles) {
      final pos = mapPoint(hole.position);
      final radiusPx = (hole.diameterMm / 2.0) * scaleFactor;

      // Annular gold copper ring
      final ringPaint = Paint()
        ..color = const Color(0xFFFFA000).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, math.max(radiusPx + 1.8, 2.5), ringPaint);

      // Dark hole center
      final holePaint = Paint()
        ..color = const Color(0xFF0A0A0A)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, math.max(radiusPx, 1.2), holePaint);
    }
  }

  void _drawGrid(Canvas canvas, Rect boardRect, double scale) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    final majorGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 0.8;

    // 1 mm minor grid, 10 mm major grid
    const double stepMm = 1.0;
    const double majorStepMm = 10.0;
    final double stepPx = stepMm * scale;
    final double majorStepPx = majorStepMm * scale;

    if (stepPx >= 4.0) {
      for (double x = boardRect.left; x <= boardRect.right; x += stepPx) {
        canvas.drawLine(Offset(x, boardRect.top), Offset(x, boardRect.bottom), gridPaint);
      }
      for (double y = boardRect.top; y <= boardRect.bottom; y += stepPx) {
        canvas.drawLine(Offset(boardRect.left, y), Offset(boardRect.right, y), gridPaint);
      }
    }

    for (double x = boardRect.left; x <= boardRect.right; x += majorStepPx) {
      canvas.drawLine(Offset(x, boardRect.top), Offset(x, boardRect.bottom), majorGridPaint);
    }
    for (double y = boardRect.top; y <= boardRect.bottom; y += majorStepPx) {
      canvas.drawLine(Offset(boardRect.left, y), Offset(boardRect.right, y), majorGridPaint);
    }
  }

  Color _resolveLayerColor(PcbLayerType type, PcbTheme theme, PcbViewSide viewSide) {
    switch (type) {
      case PcbLayerType.copperTop:
        return const Color(0xFFD32F2F); // Standard Red for Top Copper (tracks, pads, pours)
      case PcbLayerType.copperBottom:
        return const Color(0xFF1976D2); // Standard Blue for Bottom Copper (tracks, pads, pours)
      case PcbLayerType.solderMaskTop:
      case PcbLayerType.solderMaskBottom:
        return const Color(0xFF8B5CF6).withValues(alpha: 0.35); // Translucent mask
      case PcbLayerType.silkscreenTop:
        return Colors.white;
      case PcbLayerType.silkscreenBottom:
        return const Color(0xFF90CAF9);
      case PcbLayerType.edgeCuts:
        return const Color(0xFFFACC15); // Yellow outline
      case PcbLayerType.drill:
        return const Color(0xFFFFA000); // Gold annular ring
      case PcbLayerType.generic:
        return const Color(0xFFD32F2F);
    }
  }

  @override
  bool shouldRepaint(covariant PcbMultiLayerPainter oldDelegate) {
    return oldDelegate.project != project ||
        oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.scaleFactor != scaleFactor ||
        oldDelegate.project.viewSide != project.viewSide;
  }
}
