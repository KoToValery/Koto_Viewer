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

  /// Keep the hue and opacity while lifting dark line/text colours on dark CAD.
  Color foreground(Color color) {
    if (!isDark || color.computeLuminance() >= .4) return color;
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(.75).toColor();
  }
}
