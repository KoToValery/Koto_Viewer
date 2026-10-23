import 'dart:ui';
import '../models/architect_project.dart';
import '../services/architect_roof_drainage_geometry.dart';

class ArchitectRoofDrainagePainter {
  static void paint(
    Canvas canvas,
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
    double scale,
  ) {
    final geometry = ArchitectRoofDrainageGeometry.build(project, storey, roof);
    final ink = Paint()
      ..color = const Color(0xff51585c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8 / scale;
    for (final run in geometry.gutters) {
      final delta = run.end - run.start;
      if (delta.distance < 1e-6) continue;
      final side =
          Offset(-delta.dy, delta.dx) /
          delta.distance *
          roof.drainage.gutterWidth /
          2;
      canvas.drawPath(
        Path()..addPolygon([
          run.start + side,
          run.end + side,
          run.end - side,
          run.start - side,
        ], true),
        ink,
      );
    }
    for (final route in geometry.routes) {
      if (route.status != ArchitectDownpipeStatus.ready) continue;
      final points = [for (final p in route.points) Offset(p.x, p.y)];
      // An open pipe mouth and the two physical sides of the inclined offsets.
      final side =
          Offset(-route.inward.dy, route.inward.dx) * route.pipe.diameter / 2;
      for (final sign in [-1, 1]) {
        canvas.drawPath(
          Path()..addPolygon([
            for (final p in points) p + side * sign.toDouble(),
          ], false),
          ink,
        );
      }
      canvas.drawCircle(points.first, route.pipe.diameter / 2, ink);
      canvas.drawCircle(points.last, route.pipe.diameter / 2, ink);
    }
  }
}
