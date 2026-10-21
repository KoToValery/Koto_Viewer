import 'architect_vector_scene.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../widgets/architect_elevation_labels.dart';

/// Paints in plan metres, with constant screen-size arrows and labels.
void drawArchitectElevationMarkers(
  Canvas canvas,
  ArchitectProject project,
  double scale,
  Color color,
  AppLocalizations l, {
  String? selected,
  String? fontFamily,
}) {
  void label(String value, Offset point, {Color? ink, String id = 'north'}) {
    final text = ArchitectTextPainter(elementId: id, role: ArchitectAnnotationRole.symbol, modelScale: 1,
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 11 / scale,
          color: ink ?? color,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRect(
      Rect.fromLTWH(
        point.dx - text.width / 2 - 2 / scale,
        point.dy - 1 / scale,
        text.width + 4 / scale,
        text.height + 2 / scale,
      ),
      Paint()
        ..color =
            ((ink ?? color).computeLuminance() > .5
                    ? const Color(0xff14171a)
                    : Colors.white)
                .withValues(alpha: .9),
    );
    text.paint(canvas, point - Offset(text.width / 2, 0));
  }

  for (final e in project.elevations) {
    final symbolScale = ArchitectTextScope.current == null ? scale : 11 / ArchitectTextScope.current!.height(e.id, ArchitectAnnotationRole.symbol);
    final ink = selected == e.id ? Colors.blue : color;
    final paint = Paint()
      ..color = ink
      ..strokeWidth = (selected == e.id ? 2 : 1) / symbolScale;
    canvas.drawLine(e.start, e.end, paint);
    final tip = e.centre + e.viewDirection * (16 / symbolScale);
    canvas.drawLine(e.centre, tip, paint);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (tip - e.viewDirection * (6 / symbolScale) + e.axis * (4 / symbolScale)).dx,
          (tip - e.viewDirection * (6 / symbolScale) + e.axis * (4 / symbolScale)).dy,
        )
        ..lineTo(
          (tip - e.viewDirection * (6 / symbolScale) - e.axis * (4 / symbolScale)).dx,
          (tip - e.viewDirection * (6 / symbolScale) - e.axis * (4 / symbolScale)).dy,
        )
        ..close(),
      Paint()..color = ink,
    );
    canvas.drawCircle(e.start, 3 / symbolScale, paint);
    canvas.drawCircle(e.end, 3 / symbolScale, paint);
    label(
      architectElevationLabel(l, e, project.northSymbol?.angle ?? 0),
      e.centre - e.viewDirection * (22 / symbolScale),
      ink: ink,
      id: e.id,
    );
  }
  final north = project.northSymbol;
  if (north == null) return;
  final symbolScale = ArchitectTextScope.current == null ? scale : 11 / ArchitectTextScope.current!.height('north', ArchitectAnnotationRole.symbol);
  final p = north.position, d = north.direction;
  final side = Offset(-d.dy, d.dx);
  final tip = p + d * (23 / symbolScale);
  canvas.drawCircle(
    p,
    15 / symbolScale,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / symbolScale,
  );
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        (p - d * (12 / symbolScale) + side * (7 / symbolScale)).dx,
        (p - d * (12 / symbolScale) + side * (7 / symbolScale)).dy,
      )
      ..lineTo(p.dx, p.dy)
      ..lineTo(
        (p - d * (12 / symbolScale) - side * (7 / symbolScale)).dx,
        (p - d * (12 / symbolScale) - side * (7 / symbolScale)).dy,
      )
      ..close(),
    Paint()..color = color,
  );
  label(l.architectNorthSymbolLetter, p + d * (44 / symbolScale));
}
