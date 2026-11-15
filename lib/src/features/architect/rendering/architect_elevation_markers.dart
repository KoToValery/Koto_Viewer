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
  Set<String> selectedIds = const {},
  String? fontFamily,
}) {
  void label(String value, Offset point, {Color? ink, String id = 'north'}) {
    final text = ArchitectTextPainter(
      elementId: id,
      role: ArchitectAnnotationRole.section,
      modelScale: 1,
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
        point.dx - text.width / 2 - 1 / scale,
        point.dy - .5 / scale,
        text.width + 2 / scale,
        text.height + 1 / scale,
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
    if (e.length < .01) continue;
    final symbolScale = ArchitectTextScope.current == null
        ? scale
        : 11 /
              ArchitectTextScope.current!.height(
                e.id,
                ArchitectAnnotationRole.section,
              );
    final isSelected = selected == e.id || selectedIds.contains(e.id);
    final ink = isSelected ? const Color(0xFF00E5FF) : color;
    final paint = Paint()
      ..color = ink
      ..strokeWidth = (isSelected ? 2.5 : 1.2) / symbolScale;
    final marker = Path()
      ..moveTo(e.segments.first.start.dx, e.segments.first.start.dy);
    for (final s in e.segments) {
      marker
        ..lineTo(s.start.dx, s.start.dy)
        ..lineTo(s.end.dx, s.end.dy);
    }
    canvas.drawPath(marker, paint..style = PaintingStyle.stroke);
    final middle = e.segments.lastWhere((s) => s.station <= e.length / 2);
    final centre = middle.start + e.axis * (e.length / 2 - middle.station);
    final tip = centre + e.viewDirection * (20 / symbolScale);
    canvas.drawLine(centre, tip, paint);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (tip -
                  e.viewDirection * (8 / symbolScale) +
                  e.axis * (5 / symbolScale))
              .dx,
          (tip -
                  e.viewDirection * (8 / symbolScale) +
                  e.axis * (5 / symbolScale))
              .dy,
        )
        ..lineTo(
          (tip -
                  e.viewDirection * (8 / symbolScale) -
                  e.axis * (5 / symbolScale))
              .dx,
          (tip -
                  e.viewDirection * (8 / symbolScale) -
                  e.axis * (5 / symbolScale))
              .dy,
        )
        ..close(),
      Paint()..color = ink,
    );
    canvas.drawCircle(e.segments.first.start, (isSelected ? 4.0 : 3.0) / symbolScale, paint..style = PaintingStyle.fill);
    canvas.drawCircle(e.segments.last.end, (isSelected ? 4.0 : 3.0) / symbolScale, paint);
    label(
      architectElevationLabel(l, e, project.northSymbol?.angle ?? 0),
      centre - e.viewDirection * (22 / symbolScale),
      ink: ink,
      id: e.id,
    );
  }
  for (var i = 0; i < project.sections.length; i++) {
    final s = project.sections[i];
    if (s.length < .01) continue;
    final sectionScale = ArchitectTextScope.current == null
        ? scale
        : 11 /
              ArchitectTextScope.current!.height(
                s.id,
                ArchitectAnnotationRole.section,
              );
    final isSelected = selected == s.id || selectedIds.contains(s.id);
    final ink = isSelected ? const Color(0xFF00E5FF) : color;
    final segments = s.segments;
    final path = Path()
      ..moveTo(segments.first.start.dx, segments.first.start.dy);
    for (final part in segments) {
      path
        ..lineTo(part.start.dx, part.start.dy)
        ..lineTo(part.end.dx, part.end.dy);
    }
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSelected ? 2.5 : 1.2) / sectionScale;
    canvas.drawPath(path, paint);
    for (final p in [segments.first.start, segments.last.end]) {
      final tip = p + s.viewDirection * (18 / sectionScale);
      canvas.drawLine(p, tip, paint);
      final headPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (tip -
                  s.viewDirection * (6 / sectionScale) +
                  s.axis * (4 / sectionScale))
              .dx,
          (tip -
                  s.viewDirection * (6 / sectionScale) +
                  s.axis * (4 / sectionScale))
              .dy,
        )
        ..lineTo(
          (tip -
                  s.viewDirection * (6 / sectionScale) -
                  s.axis * (4 / sectionScale))
              .dx,
          (tip -
                  s.viewDirection * (6 / sectionScale) -
                  s.axis * (4 / sectionScale))
              .dy,
        )
        ..close();
      canvas.drawPath(headPath, Paint()..color = ink);
    }
    canvas.drawCircle(
      segments.first.start,
      (isSelected ? 4.0 : 3.0) / sectionScale,
      Paint()..color = ink,
    );
    canvas.drawCircle(
      segments.last.end,
      (isSelected ? 4.0 : 3.0) / sectionScale,
      Paint()..color = ink,
    );
    label(
      s.name.isEmpty ? l.architectSectionNumber(i + 1) : s.name,
      segments.first.start - s.viewDirection * (20 / sectionScale),
      ink: ink,
      id: s.id,
    );
  }
  final north = project.northSymbol;
  if (north == null) return;
  final symbolScale = ArchitectTextScope.current == null
      ? scale
      : 11 /
            ArchitectTextScope.current!.height(
              'north',
              ArchitectAnnotationRole.section,
            );
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
