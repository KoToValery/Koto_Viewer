import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../services/architect_stair_geometry.dart';
import '../services/architect_stair_railings.dart';
import '../widgets/architect_stair_labels.dart';
import 'architect_stair_mesh.dart';

class ArchitectStairPlanPainter {
  static void dashed(Canvas canvas, Path path, Paint paint, double scale) {
    final dash = 5 / scale, gap = 3 / scale;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        canvas.drawPath(metric.extractPath(start, math.min(start + dash, metric.length)), paint);
      }
    }
  }

  static void draw({required Canvas canvas, required ArchitectStair stair,
    required double scale, required Color color, Color background = Colors.white,
    double? cutHeight, ArchitectStorey? storey, ArchitectProject? project,
    AppLocalizations? l10n, bool labels = true,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100}) {
    final plan = stair.plan, d = stair.design;
    final geometry = ArchitectStairGeometry.of(stair);
    final cut = geometry.cut(cutHeight ?? double.infinity);
    final stroke = Paint()..color = color..strokeWidth = 1.2 / scale..style = PaintingStyle.stroke;
    final thin = Paint()..color = color..strokeWidth = .8 / scale..style = PaintingStyle.stroke;
    if (!cut.below.getBounds().isEmpty) {
      canvas.drawPath(cut.below, Paint()..color = color.withValues(alpha: .035));
      canvas.drawPath(cut.below, stroke);
    }
    dashed(canvas, cut.above, thin, scale);
    for (var i = 0; i < plan.nosings.length; i++) {
      final (a, b) = plan.nosings[i];
      final path = Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy);
      if (d != null && (i + 1) * d.riser > (cutHeight ?? double.infinity) + 1e-8) {
        dashed(canvas, path, thin, scale);
      } else { canvas.drawPath(path, thin); }
    }
    final points = plan.walkingLine;
    if (points.length >= 2) {
      // The ascent symbol stays continuous and readable over the dashed steps.
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, thin);
      final radius = (stair.width * .055 * scale).clamp(4.5, 8.0) / scale;
      canvas.drawCircle(points.first, radius, Paint()..color = background);
      canvas.drawCircle(points.first, radius, stroke);
      final end = points.last, delta = end - points[points.length - 2];
      if (delta.distance > 1e-8) {
        final u = delta / delta.distance, n = Offset(-u.dy, u.dx);
        final size = math.min(.18, stair.width * .18);
        canvas.drawLine(end, end - u * size + n * size / 2, stroke);
        canvas.drawLine(end, end - u * size - n * size / 2, stroke);
      }
    }
    if (d != null && d.showRailing) {
      final floor = storey ?? const ArchitectStorey(id: 'preview', name: '');
      for (final path in ArchitectStairRailings.build(stair, storey: floor, project: project)) {
        final base = ArchitectStairMesh.simplify(path.base);
        for (var i = 0; i < base.length - 1; i++) {
          final p = base[i], q = base[i + 1];
          final a = Offset(p.x, p.y), b = Offset(q.x, q.y), v = b - a;
          if (v.distance < 1e-8) continue;
          final offsets = path.wallMounted ? [Offset.zero] : [Offset.zero, Offset(-v.dy, v.dx) / v.distance * .025];
          for (final offset in offsets) {
            final line = Path()..moveTo(a.dx + offset.dx, a.dy + offset.dy)..lineTo(b.dx + offset.dx, b.dy + offset.dy);
            if ((p.z + q.z) / 2 > (cutHeight ?? double.infinity) + 1e-8) {
              dashed(canvas, line, thin, scale);
            } else { canvas.drawPath(line, thin); }
          }
        }
      }
    }
    if (cut.crossing != null) {
      final (a, b) = cut.crossing!;
      final index = ((cutHeight ?? 0) / d!.riser).floor().clamp(0, d.risers - 1);
      Offset direction;
      if (geometry.flights.isNotEmpty) {
        direction = geometry.flights.firstWhere((f) => index >= f.firstRiser && index < f.firstRiser + f.count).axis;
      } else {
        final other = plan.nosings[index == d.risers - 1 ? index - 1 : index + 1];
        final delta = index == d.risers - 1 ? a + b - other.$1 - other.$2 : other.$1 + other.$2 - a - b;
        direction = delta / delta.distance;
      }
      for (final shift in [-.045, .045]) {
        final start = a + direction * (shift - .10), end = b + direction * (shift + .10);
        canvas.drawLine(start, end, Paint()..color = background..strokeWidth = 4 / scale);
        canvas.drawLine(start, end, stroke..strokeWidth = 1.5 / scale);
      }
    }
    if (d != null && d.showLabel && labels && l10n != null) {
      final text = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center,
        text: TextSpan(text: stairPlanLabel(l10n, stair), style: TextStyle(
          fontFamily: 'Roboto', color: color,
          fontSize: (dimensionScale.textHeight * scale).clamp(10.0, 18.0), height: 1.15)))..layout();
      canvas.save();
      canvas.translate(plan.bounds.bottomCenter.dx, plan.bounds.bottom + .16);
      canvas.scale(1 / scale);
      final rect = Rect.fromLTWH(-text.width / 2 - 3, -2, text.width + 6, text.height + 4);
      canvas.drawRect(rect, Paint()..color = background.withValues(alpha: .94));
      text.paint(canvas, Offset(-text.width / 2, 0));
      canvas.restore();
    }
  }
}
