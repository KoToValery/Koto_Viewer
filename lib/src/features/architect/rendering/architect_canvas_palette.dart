import 'package:flutter/material.dart';

/// Display colours only; switching the canvas never changes element data.
class ArchitectCanvasPalette {
  final bool isDark;
  const ArchitectCanvasPalette.light() : isDark = false;
  const ArchitectCanvasPalette.dark() : isDark = true;

  Color get background =>
      isDark ? const Color(0xFF14171A) : const Color(0xFFF3F5F7);
  Color get grid => isDark ? Colors.white : Colors.black;
  Color get underlay =>
      isDark ? const Color(0x805CD6E0) : const Color(0x3A00838F);

  /// Keep the hue and opacity while lifting dark line/text colours on dark CAD,
  /// and darkening excessively bright colours on light CAD so elements never blend with the base.
  Color foreground(Color color) {
    if (isDark) {
      if (color.computeLuminance() >= .4) return color;
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness(.75).toColor();
    } else {
      if (color.computeLuminance() <= .75) return color;
      final hsl = HSLColor.fromColor(color);
      return hsl.withLightness(.35).toColor();
    }
  }
}

/// Standard lineweights for architectural drafting according to ISO 128 / BIM conventions.
class ArchitectLineWeights {
  ArchitectLineWeights._();

  /// Heavy stroke for cut structural core (bearing walls, structural columns, shear walls).
  static const double cutHeavy = 2.2;

  /// Medium stroke for uncut elements in projection (parapets, slab edges, door swings, stairs).
  static const double projection = 1.2;

  /// Thin stroke for secondary cut layers (insulation boundary, casing, plaster).
  static const double cutThin = 0.8;

  /// Very thin / hairline for hatches, grid axes, dimension witness lines, annotations.
  static const double hairline = 0.5;

  /// Stroke for overhead elements above the cut plane (beams, ceiling voids).
  static const double overhead = 1.0;
}
