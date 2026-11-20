import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_contour.dart';
import '../models/architect_project.dart';
import '../services/architect_ceiling_geometry.dart';
import 'architect_canvas_palette.dart';
import 'architect_vector_scene.dart';

/// 2D canvas painter helper for suspended ceilings (Armstrong & Gypsum board),
/// Armstrong origin handles, ceiling drafting previews, and upper beam context.
class ArchitectCeilingPainterHelper {
  ArchitectCeilingPainterHelper._();

  static void drawCeilings({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
    Set<String> selectedElementIds = const {},
    AppLocalizations? l10n,
  }) {
    final fillArmstrong = Paint()
      ..color = palette.isDark
          ? const Color(0x1800E5FF)
          : const Color(0x0D00838F)
      ..style = PaintingStyle.fill;
    final fillGypsum = Paint()
      ..color = palette.isDark
          ? const Color(0x1480CBC4)
          : const Color(0x0A37474F)
      ..style = PaintingStyle.fill;
    final fillSelected = Paint()
      ..color = const Color(0x2600E5FF)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = palette.foreground(const Color(0xFF006064))
      ..strokeWidth = 1.35 / zoomScale
      ..style = PaintingStyle.stroke;
    final selectedBorderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.4 / zoomScale
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = palette.isDark
          ? const Color(0x66B2EBF2)
          : const Color(0x5537474F)
      ..strokeWidth = 0.65 / zoomScale
      ..style = PaintingStyle.stroke;

    final holeCrossPaint = Paint()
      ..color = palette.foreground(const Color(0x66455A64))
      ..strokeWidth = 0.7 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final ceiling in storey.ceilings) {
      if (ceiling.polygon.length < 3) continue;
      architectDrawingSources(canvas, {ceiling.id}, 'ceilings');

      final isSelected =
          ceiling.id == selectedElementId ||
          selectedElementIds.contains(ceiling.id);

      final path = ArchitectContour.path(
        ceiling.polygon,
        ceiling.holes,
        bulges: ceiling.bulges,
      );

      canvas.drawPath(
        path,
        isSelected
            ? fillSelected
            : (ceiling.type == SuspendedCeilingType.armstrong
                  ? fillArmstrong
                  : fillGypsum),
      );

      if (ceiling.type == SuspendedCeilingType.armstrong) {
        final gridLines = ArchitectCeilingGeometry.armstrongGridLines(ceiling);
        for (final (a, b) in gridLines) {
          canvas.drawLine(a, b, gridPaint);
        }
      }

      canvas.drawPath(path, isSelected ? selectedBorderPaint : borderPaint);

      // Draw crisp cutout markers on holes.
      for (final hole in ceiling.holes) {
        if (hole.length < 3) continue;
        if (hole.length == 4) {
          canvas.drawLine(hole[0], hole[2], holeCrossPaint);
          canvas.drawLine(hole[1], hole[3], holeCrossPaint);
        }
      }

      // Draw Armstrong grid origin grip when selected.
      if (isSelected && ceiling.type == SuspendedCeilingType.armstrong) {
        final origin = ceiling.gridOrigin ?? ceiling.centroid;
        final draftingScale = math.max(zoomScale, 80.0);
        final r = 6.5 / draftingScale;
        final cosA = math.cos(ceiling.gridAngle);
        final sinA = math.sin(ceiling.gridAngle);
        final u = Offset(cosA, sinA) * (r * 1.6);
        final v = Offset(-sinA, cosA) * (r * 1.6);
        final originPaint = Paint()
          ..color = const Color(0xFFFFAB00)
          ..strokeWidth = 1.8 / draftingScale
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(origin, r, Paint()..color = const Color(0xFF1E1E26));
        canvas.drawCircle(origin, r, originPaint);
        canvas.drawLine(origin - u, origin + u, originPaint);
        canvas.drawLine(origin - v, origin + v, originPaint);
      }

      // Designation & elevation readout (print-first).
      if ((ceiling.showLabel || ceiling.showElevationMarker) &&
          (ArchitectTextScope.current != null || zoomScale > 10.0)) {
        final metrics = ArchitectCeilingGeometry.computeMetrics(
          project,
          storey,
          ceiling,
        );
        final lines = <String>[];
        if (ceiling.showLabel) {
          if (ceiling.label.trim().isNotEmpty) {
            lines.add(ceiling.label.trim());
          } else if (ceiling.type == SuspendedCeilingType.armstrong) {
            final wCm = (ceiling.tileWidth * 100).round();
            final lCm = (ceiling.tileLength * 100).round();
            final base = l10n?.architectCeilingArmstrong ?? 'Armstrong';
            lines.add('$base $wCm×$lCm');
          } else {
            lines.add(l10n?.architectCeilingGypsum ?? 'Gypsum board');
          }
        }
        if (ceiling.showElevationMarker) {
          final elev = project.formatLevel(metrics.ceilingElevation);
          final clearH = project.formatLength(metrics.clearHeight);
          final warn = metrics.hasAnyConflict ? ' ⚠' : '';
          lines.add('$elev · H=$clearH$warn');
        }
        if (lines.isNotEmpty) {
          final c = ceiling.centroid;
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.scale(ArchitectPaperStyle.annotationScale);
          final text = lines.join('\n');
          final tp = ArchitectTextPainter(
            elementId: ceiling.id,
            role: ArchitectAnnotationRole.ordinary,
            modelScale: ArchitectPaperStyle.annotationScale,
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: metrics.hasAnyConflict && ArchitectTextScope.current == null
                    ? const Color(0xFFD97706)
                    : palette.foreground(const Color(0xFF004D40)),
                fontFamily: 'ArchitectNoto',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout();

          if (ArchitectTextScope.current == null) {
            final bgRect = Rect.fromCenter(
              center: Offset.zero,
              width: tp.width + 8,
              height: tp.height + 4,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
              Paint()
                ..color = palette.isDark
                    ? const Color(0xCC1E1E26)
                    : const Color(0xDDFFFFFF),
            );
          }
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }
      }
    }
  }

  /// Draws beams from the upper storey that hang below the upper floor level,
  /// supplementing the current storey's overhead beams in ceiling/MEP plans.
  static void drawUpperBeamsOverlay({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double zoomScale,
  }) {
    final upper = ArchitectCeilingGeometry.upperStoreyOf(project, storey);
    if (upper == null) return;
    final beamPaint = Paint()
      ..color = palette.foreground(const Color(0x88455A64))
      ..strokeWidth = ArchitectLineWeights.overhead / zoomScale
      ..style = PaintingStyle.stroke;

    for (final beam in upper.beams) {
      if (beam.minBottomOffset >= 0) continue;
      final corners = beam.polygonCorners;
      final path = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();
      _drawDashedPath(canvas, path, beamPaint, zoomScale);
    }
  }

  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double zoomScale,
  ) {
    final dash = 6.0 / math.max(zoomScale, 40.0);
    final gap = 4.0 / math.max(zoomScale, 40.0);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist += dash + gap;
      }
    }
  }
}
