import 'package:flutter/material.dart';

import '../services/architect_polygon_editor.dart';

/// Edge grips share the polygon editor's direct and displaced touch targets.
class ArchitectUnderlayCropOverlay extends StatelessWidget {
  final List<Offset> polygon;
  final double scale, handleLength;
  final Offset translation;
  final int? activeEdge;
  final bool invalid;
  const ArchitectUnderlayCropOverlay({
    super.key,
    required this.polygon,
    required this.scale,
    required this.translation,
    required this.handleLength,
    this.activeEdge,
    this.invalid = false,
  });

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
    Offset screen(Offset point) => point * data.scale + data.translation;
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
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
