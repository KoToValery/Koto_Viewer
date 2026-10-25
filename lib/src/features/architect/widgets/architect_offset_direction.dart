import 'package:flutter/material.dart';

class ArchitectOffsetDirectionPainter extends CustomPainter {
  final Offset start, side;
  final Color color;
  ArchitectOffsetDirectionPainter({
    required this.start,
    required this.side,
    required this.color,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final delta = side - start;
    if (delta.distance < 1) return;
    final u = delta / delta.distance, n = Offset(-u.dy, u.dx);
    final end = start + u * delta.distance.clamp(30.0, 90.0);
    canvas.clipRect(Offset.zero & size);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy)
      ..moveTo((end - u * 11 + n * 6).dx, (end - u * 11 + n * 6).dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo((end - u * 11 - n * 6).dx, (end - u * 11 - n * 6).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ArchitectOffsetDirectionPainter old) =>
      start != old.start || side != old.side || color != old.color;
}
