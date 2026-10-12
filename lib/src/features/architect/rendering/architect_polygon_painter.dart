import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../services/architect_polygon_geometry.dart';
import 'architect_dimension_layout.dart';

/// The same handles and segment dimensions for CAD contours and slabs.
class ArchitectPolygonPainter {
  static const vertexColor = Color(0xFF00BCD4), edgeColor = Color(0xFFFF9800);
  static void draw({
    required Canvas canvas,
    required List<Offset> polygon,
    required double scale,
    required ArchitectUnit unit,
    bool handles = false,
    bool invalid = false,
    Path? obstacles,
  }) {
    if (polygon.length < 3) return;
    if (invalid) {
      canvas.drawPath(
        Path()..addPolygon(polygon, true),
        Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / scale,
      );
    }
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final n = ArchitectPolygonGeometry.normal(polygon, i);
      dimension(canvas, a, b, n, scale, unit, obstacles: obstacles);
      if (handles) {
        canvas.drawCircle(a, 3 / scale, Paint()..color = vertexColor);
        canvas.drawCircle((a + b) / 2, 3 / scale, Paint()..color = edgeColor);
      }
    }
  }

  static void dimension(
    Canvas canvas,
    Offset a,
    Offset b,
    Offset normal,
    double scale,
    ArchitectUnit unit, {
    Path? obstacles,
  }) {
    final delta = b - a;
    if (delta.distance < .001) return;
    final u = delta / delta.distance;
    final text =
        '${unit.toUnit(delta.distance).toStringAsFixed(2)} ${unit.symbol}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF006064),
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var center = (a + b) / 2 + normal * (18 / scale);
    if (obstacles != null) {
      center = ArchitectDimensionLayout.clearTextPosition(
        center,
        Size(
          tp.width * u.dx.abs() + tp.height * u.dy.abs() + 8,
          tp.width * u.dy.abs() + tp.height * u.dx.abs() + 8,
        ),
        scale,
        normal,
        obstacles,
      );
    }
    var angle = math.atan2(u.dy, u.dx);
    if (angle > math.pi / 2 || angle < -math.pi / 2) angle += math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(1 / scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: tp.width + 6,
          height: tp.height + 4,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xF5FFFFFF),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}
