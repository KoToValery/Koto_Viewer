import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/architect_polygon_editor.dart';

/// Edge grips share the polygon editor's direct and displaced touch targets.
class ArchitectUnderlayCropOverlay extends StatelessWidget {
  final List<Offset> polygon;
  final double scale, handleLength, rotation;
  final Offset translation;
  final int? activeEdge;
  final bool invalid;
  final bool canMove;
  final bool moving;
  const ArchitectUnderlayCropOverlay({
    super.key,
    required this.polygon,
    required this.scale,
    required this.translation,
    required this.handleLength,
    this.rotation = 0,
    this.activeEdge,
    this.invalid = false,
    this.canMove = false,
    this.moving = false,
  });

  /// Geometric bounding-box center of the visible underlay polygon.
  static Offset? centerPoint(List<Offset> polygon) {
    if (polygon.isEmpty) return null;
    var minX = polygon.first.dx;
    var maxX = polygon.first.dx;
    var minY = polygon.first.dy;
    var maxY = polygon.first.dy;
    for (final p in polygon.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  /// Renders the circular 4-arrow free-move handle shared by underlays and terrain.
  static void paintCenterMoveHandle(
    Canvas canvas,
    Offset center, {
    bool moving = false,
  }) {
    final radius = moving ? 12.0 : 10.0;
    final strokeColor = moving
        ? const Color(0xff0288d1)
        : const Color(0xff555555);
    final moveStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = moving ? 1.8 : 1.3;
    canvas.drawCircle(
      center + const Offset(0, 1),
      radius,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, moveStroke);
    const arm = 5.5;
    const tip = 2.0;
    canvas.drawLine(
      center - const Offset(arm, 0),
      center + const Offset(arm, 0),
      moveStroke,
    );
    canvas.drawLine(
      center - const Offset(0, arm),
      center + const Offset(0, arm),
      moveStroke,
    );
    for (final dir in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      final head = center + dir * arm;
      final perp = Offset(-dir.dy, dir.dx) * tip;
      final back = head - dir * tip;
      canvas.drawLine(head, back + perp, moveStroke);
      canvas.drawLine(head, back - perp, moveStroke);
    }
  }

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _CropPainter(this)));
}

class _CropPainter extends CustomPainter {
  final ArchitectUnderlayCropOverlay data;
  _CropPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    final p = data.polygon;
    if (p.length < 3 || data.scale <= 0) return;
    Offset screen(Offset point) {
      final scaled = point * data.scale;
      if (data.rotation == 0) return scaled + data.translation;
      final c = math.cos(data.rotation), s = math.sin(data.rotation);
      return Offset(
        scaled.dx * c - scaled.dy * s,
        scaled.dx * s + scaled.dy * c,
      ) + data.translation;
    }
    final line = Paint()
      ..color = (data.invalid
          ? const Color(0xffb3261e)
          : const Color(0xff555555))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addPolygon(p.map(screen).toList(), true);
    canvas.drawPath(path, line);
    for (var i = 0; i < p.length; i++) {
      final midpoint = screen((p[i] + p[(i + 1) % p.length]) / 2);
      final grip = screen(
        ArchitectPolygonEditor.offsetEdgeHandle(
          p,
          i,
          data.scale,
          data.handleLength,
        ),
      );
      if (data.handleLength > 0) canvas.drawLine(midpoint, grip, line);
      for (final point in [midpoint, if (data.handleLength > 0) grip]) {
        canvas.drawCircle(
          point,
          data.activeEdge == i ? 6 : 5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(point, data.activeEdge == i ? 6 : 5, line);
      }
    }
    final centerModel = data.canMove
        ? ArchitectUnderlayCropOverlay.centerPoint(p)
        : null;
    if (centerModel != null) {
      ArchitectUnderlayCropOverlay.paintCenterMoveHandle(
        canvas,
        screen(centerModel),
        moving: data.moving,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
