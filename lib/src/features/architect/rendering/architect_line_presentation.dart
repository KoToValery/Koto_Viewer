import 'dart:ui';

import '../models/architect_document.dart';
import 'architect_vector_scene.dart';

/// Editing uses logical pixels; vector recording/publication uses paper units.
class ArchitectLinePresentation {
  static bool get publication =>
      ArchitectTextScope.current?.publication ?? false;
  static bool paper(Canvas? canvas) =>
      publication || canvas is ArchitectVectorCanvas;

  static double patternUnits(
    double zoomScale,
    double paperUnitsPerMm, {
    Canvas? canvas,
  }) => paper(canvas) ? paperUnitsPerMm : (96 / 25.4) / zoomScale;

  static double stroke(
    double zoomScale,
    double paperMm, {
    double pixels = 1.2,
    Canvas? canvas,
    int denominator = 100,
  }) => paper(canvas)
      ? ArchitectDrawingScale(
          ArchitectTextScope.current?.denominator ?? denominator,
        ).paperToModel(paperMm)
      : pixels / zoomScale;
}
