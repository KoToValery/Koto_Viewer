import 'package:flutter/material.dart';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../rendering/architect_dynamic_dimension_layout.dart';

/// Temporary editing dimensions; never sent to the publication scene.
class ArchitectDynamicDimensionPainter extends CustomPainter {
  final List<ArchitectDynamicDimensionLayout> dimensions;
  const ArchitectDynamicDimensionPainter(this.dimensions);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final dim in dimensions) {
      final paint = Paint()
        ..color = dim.active ? const Color(0xff006e91) : const Color(0xff545b62)
        ..strokeWidth = dim.active ? 1.2 : .85
        ..style = PaintingStyle.stroke;
      void line(Offset a, Offset b, {bool continued = false}) {
        final clipped = BimLineGeometry.visibleSegment(a, b, dim.viewport);
        if (clipped == null) return;
        canvas.drawLine(clipped.$1, clipped.$2, paint);
        if (continued && (b - a).distance > 1e-6) {
          final u = (b - a) / (b - a).distance;
          final n = Offset(-u.dy, u.dx);
          if (!dim.viewport.contains(a)) {
            canvas.drawLine(clipped.$1, clipped.$1 + u * 7 + n * 3, paint);
            canvas.drawLine(clipped.$1, clipped.$1 + u * 7 - n * 3, paint);
          }
          if (!dim.viewport.contains(b)) {
            canvas.drawLine(clipped.$2, clipped.$2 - u * 7 + n * 3, paint);
            canvas.drawLine(clipped.$2, clipped.$2 - u * 7 - n * 3, paint);
          }
        }
      }

      final delta = dim.end - dim.start;
      final u = delta.distance < 1e-8
          ? const Offset(1, 0)
          : delta / delta.distance;
      final n = Offset(-u.dy, u.dx);
      line(dim.start, dim.end, continued: true);
      for (final (point, end) in [
        (dim.measuredStart, dim.start),
        (dim.measuredEnd, dim.end),
      ]) {
        final witness = end - point;
        final axis = witness.distance < 1e-8 ? n : witness / witness.distance;
        line(point + axis * 2, end + axis * 4);
        // A clipped boundary is a continuation, never an artificial endpoint.
        if (dim.viewport.contains(end)) {
          line(end - (u + n) * 3, end + (u + n) * 3);
        }
        if (dim.viewport.contains(point)) {
          canvas.drawCircle(point, 2, Paint()..color = Colors.white);
          canvas.drawCircle(point, 2, paint);
          if (dim.active) line(point - n * 8, point + n * 8);
        }
      }
      if (dim.hasLeader) {
        line(dim.label.center, dim.labelAnchor, continued: true);
      }
      if (dim.endpoint != null && dim.viewport.contains(dim.measuredStart)) {
        final p = dim.measuredStart;
        canvas.drawCircle(p, 7, Paint()..color = Colors.white);
        canvas.drawCircle(p, 7, paint);
        final tp = TextPainter(
          text: TextSpan(
            text: '${dim.endpoint}',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectDynamicDimensionPainter oldDelegate) =>
      oldDelegate.dimensions != dimensions;
}
