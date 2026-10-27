import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'architect_canvas_palette.dart';

/// Selection is a display overlay with constant screen-space line weights.
class ArchitectSelectionPainter {
  static Color accent(ArchitectCanvasPalette palette) =>
      palette.isDark ? const Color(0xFF59E6FF) : const Color(0xFF006E91);
  static Color halo(ArchitectCanvasPalette palette) =>
      palette.isDark ? const Color(0xFF101418) : Colors.white;
  static void outline(
    Canvas canvas,
    Path path,
    double scale,
    ArchitectCanvasPalette palette,
  ) {
    canvas.drawPath(
      path,
      Paint()
        ..color = halo(palette)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5 / scale,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent(palette)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / scale,
    );
  }

  static void _dashed(Canvas canvas, Path path, Paint paint, double scale) {
    for (final metric in path.computeMetrics()) {
      for (
        var position = 0.0;
        position < metric.length;
        position += 12 / scale
      ) {
        canvas.drawPath(
          metric.extractPath(
            position,
            math.min(position + 8 / scale, metric.length),
          ),
          paint,
        );
      }
    }
  }

  static void preview(
    Canvas canvas,
    Path path,
    double scale,
    ArchitectCanvasPalette palette, {
    bool removed = false,
  }) {
    final color = removed
        ? (palette.isDark ? const Color(0xFFFFBF69) : const Color(0xFF9B4300))
        : accent(palette);
    canvas.drawPath(
      path,
      Paint()
        ..color = halo(palette)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5 / scale,
    );
    _dashed(
      canvas,
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / scale,
      scale,
    );
    final marker = path.getBounds().topRight + Offset(7, -7) / scale;
    canvas.drawCircle(marker, 7 / scale, Paint()..color = halo(palette));
    final pen = Paint()
      ..color = color
      ..strokeWidth = 2 / scale;
    canvas.drawLine(
      marker - Offset(4, 0) / scale,
      marker + Offset(4, 0) / scale,
      pen,
    );
    if (!removed) {
      canvas.drawLine(
        marker - Offset(0, 4) / scale,
        marker + Offset(0, 4) / scale,
        pen,
      );
    }
  }

  static void marquee(
    Canvas canvas,
    List<Offset> polygon,
    List<Offset> points,
    double scale,
    ArchitectCanvasPalette palette, {
    bool contained = false,
    Offset? candidate,
  }) {
    if (polygon.length < 2) return;
    final path = Path()..addPolygon(polygon, polygon.length >= 3);
    if (polygon.length >= 3) {
      canvas.drawPath(
        path,
        Paint()..color = accent(palette).withValues(alpha: .09),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = halo(palette)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 / scale,
    );
    final pen = Paint()
      ..color = accent(palette)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale;
    if (contained) {
      canvas.drawPath(path, pen);
    } else {
      _dashed(canvas, path, pen, scale);
    }
    if (candidate != null &&
        !polygon.contains(candidate) &&
        points.isNotEmpty) {
      final guide = Path()
        ..moveTo(points.last.dx, points.last.dy)
        ..lineTo(candidate.dx, candidate.dy)
        ..lineTo(points.first.dx, points.first.dy);
      _dashed(
        canvas,
        guide,
        Paint()
          ..color = accent(palette).withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
        scale,
      );
    }
    for (final point in points) {
      canvas.drawCircle(point, 5 / scale, Paint()..color = halo(palette));
      canvas.drawCircle(
        point,
        4 / scale,
        Paint()
          ..color = accent(palette)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale,
      );
    }
  }
}
