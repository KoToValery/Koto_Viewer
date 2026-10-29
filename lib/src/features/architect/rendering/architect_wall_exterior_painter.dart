import 'dart:ui';
import '../models/architect_wall.dart';

/// Editing overlay only: no annotation entities or export geometry are created.
class ArchitectWallExteriorPainter {
  static void draw(
    Canvas canvas,
    ArchitectWall wall,
    double scale,
    Color color, {
    bool? provisional,
  }) {
    if (!wall.isExterior || wall.isParapet) return;
    final n = wall.normalAt(.5) * wall.exteriorSign;
    final face = wall.centerPointAt(.5) + n * (wall.thickness / 2);
    final start = face + n * (5 / scale), end = start + n * (18 / scale);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25 / scale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dashed =
        provisional ??
        (!wall.exteriorResolved &&
            wall.exteriorSideMode != WallResolutionMode.manual);
    if (dashed) {
      for (var i = 0; i < 18; i += 6) {
        canvas.drawLine(
          start + n * (i / scale),
          start + n * ((i + 3) / scale),
          paint,
        );
      }
    } else {
      canvas.drawLine(start, end, paint);
    }
    final u = wall.tangentAt(.5), back = end - n * (5 / scale);
    canvas.drawPath(
      Path()
        ..moveTo((back - u * (3 / scale)).dx, (back - u * (3 / scale)).dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo((back + u * (3 / scale)).dx, (back + u * (3 / scale)).dy),
      paint,
    );
  }
}
