import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_vector_scene.dart';

/// The same measured, rotated outline is used for ink, picking and selection.
class ArchitectAnnotationLayout {
  static final _outlines = Expando<Map<double, Path>>();
  static ArchitectTextPainter painter(ArchitectAnnotation a, {Color? color}) =>
      ArchitectTextPainter(
        elementId: a.id,
        modelScale: 1,
        textAlign: a.alignment,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: a.text,
          style: TextStyle(
            fontFamily: 'ArchitectNoto',
            fontSize: a.fontSize,
            color: color ?? Color(a.colorValue),
            fontWeight:
                FontWeight.values[(a.fontWeight ~/ 100 - 1).clamp(0, 8)],
            fontStyle: a.italic ? FontStyle.italic : FontStyle.normal,
            decoration: a.underline
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      )..layout();

  static Path outline(ArchitectAnnotation a, {ArchitectProject? project}) {
    Path measure() {
      final height =
          ArchitectTextScope.current?.fontSize(
            a.id,
            ArchitectAnnotationRole.ordinary,
          ) ??
          a.fontSize;
      final cache = _outlines[a] ??= <double, Path>{};
      if (cache.containsKey(height)) return cache[height]!;
      final text = painter(a);
      final angle = a.rotationDeg * math.pi / 180;
      Offset world(Offset p) =>
          a.position +
          Offset(
            p.dx * math.cos(angle) - p.dy * math.sin(angle),
            p.dx * math.sin(angle) + p.dy * math.cos(angle),
          );
      final rect = Offset.zero & text.size;
      return cache[height] = Path()
        ..addPolygon(
          [
            rect.topLeft,
            rect.topRight,
            rect.bottomRight,
            rect.bottomLeft,
          ].map(world).toList(),
          true,
        );
    }

    if (ArchitectTextScope.current != null || project == null) return measure();
    final id = project.activeStoreyId;
    final key = id.startsWith('view:')
        ? project.document.viewScales.keys
                  .where((k) => k.endsWith(':${id.substring(5)}'))
                  .firstOrNull ??
              'elevation:${id.substring(5)}'
        : 'plan:$id';
    return ArchitectTextScope(
      project.document,
      key,
      project.document.viewScales[key] ?? project.dimensionScale.denominator,
      1,
    ).run(measure);
  }
}
