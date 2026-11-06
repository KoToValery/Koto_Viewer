import 'dart:ui';
import 'package:flutter/painting.dart' show TextStyle, FontWeight, TextPainter, TextSpan, TextDirection;
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
      final isInternal = route.pipe.isInternal ||
          roof.drainage.position == ArchitectGutterPosition.internal;

      if (isInternal) {
        // Internal roof drain inlet sump / воронка
        final inlet = points.first;
        final r = route.pipe.diameter / 2;
        final sumpPaint = Paint()
          ..color = const Color(0xFF263238)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 / scale;
        final d = r * 0.7071;
        canvas.drawLine(inlet - Offset(d, d), inlet + Offset(d, d), sumpPaint);
        canvas.drawLine(inlet - Offset(-d, d), inlet + Offset(-d, d), sumpPaint);
        canvas.drawCircle(inlet, r, sumpPaint);
        canvas.drawCircle(inlet, r * 1.5, sumpPaint);

        if (scale > 15.0) {
          final mm = (route.pipe.diameter * 1000).round();
          final tp = TextPainter(
            text: TextSpan(
              text: 'ВТ ∅$mm',
              style: TextStyle(
                color: const Color(0xFF263238),
                fontSize: 10.0 / scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, inlet + Offset(r * 1.6, -tp.height / 2));
        }
      } else {
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

  /// Renders internal downpipe (ВТ ∅110) vertical penetrations on intermediate floor plans.
  static void paintStoreyPenetrations(
    Canvas canvas,
    ArchitectProject project,
    ArchitectStorey activeStorey,
    double scale,
  ) {
    if (activeStorey.isRoof) return;
    final higherStoreys = project.storeys
        .where((s) => s.elevation > activeStorey.elevation)
        .toList();
    if (higherStoreys.isEmpty) return;

    for (final higher in higherStoreys) {
      for (final roof in higher.roofs) {
        if (!roof.drainage.showDownpipes) continue;
        final (ea, eb) = roof.eavesEdge;
        final len = (eb - ea).distance;
        if (len < 1e-4) continue;
        final n = roof.slopeDirection;
        final gOffset = ArchitectRoofDrainageGeometry.gutterOffset(roof);

        for (final pipe in roof.drainage.downpipes) {
          if (!pipe.visible) continue;
          final isInternal = pipe.isInternal ||
              roof.drainage.position == ArchitectGutterPosition.internal;
          if (!isInternal) continue;
          if (activeStorey.elevation < pipe.outletElevation - 0.5) continue;

          final edgePt = ea + (eb - ea) * (pipe.offset / len).clamp(0.0, 1.0);
          final pos = edgePt - n * gOffset;
          final r = pipe.diameter / 2;

          // Standard architectural penetration symbol (ВТ ∅110)
          final ink = Paint()
            ..color = const Color(0xFF1E1E26)
            ..strokeWidth = 1.0 / scale
            ..style = PaintingStyle.stroke;
          final fill = Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(pos, r, fill);
          canvas.drawCircle(pos, r, ink);

          // Diagonal cross
          final d = r * 0.7071;
          canvas.drawLine(pos - Offset(d, d), pos + Offset(d, d), ink);
          canvas.drawLine(pos - Offset(-d, d), pos + Offset(-d, d), ink);

          // Text label ВТ ∅110
          if (scale > 15.0) {
            final mm = (pipe.diameter * 1000).round();
            final textPainter = TextPainter(
              text: TextSpan(
                text: 'ВТ ∅$mm',
                style: TextStyle(
                  color: const Color(0xFF1E1E26),
                  fontSize: 10.0 / scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            textPainter.paint(
              canvas,
              pos + Offset(r + 2.0 / scale, -textPainter.height / 2),
            );
          }
        }
      }
    }
  }
}
