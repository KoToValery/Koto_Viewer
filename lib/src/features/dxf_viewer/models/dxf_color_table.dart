import 'package:flutter/material.dart';

/// AutoCAD Color Index (ACI) lookup table and color resolution utilities.
class DxfColorTable {
  const DxfColorTable._();

  /// Standard AutoCAD 256 Color Palette (0 = BYBLOCK, 1-255 = ACI, 256 = BYLAYER)
  static final List<Color> aciColors = _generateAciTable();

  static List<Color> _generateAciTable() {
    final list = List<Color>.filled(256, Colors.white);

    // 0: ByBlock (placeholder, black/white default)
    list[0] = const Color(0xFFFFFFFF);

    // 1-9: Standard primary CAD colors
    list[1] = const Color(0xFFFF0000); // Red
    list[2] = const Color(0xFFFFFF00); // Yellow
    list[3] = const Color(0xFF00FF00); // Green
    list[4] = const Color(0xFF00FFFF); // Cyan
    list[5] = const Color(0xFF0000FF); // Blue
    list[6] = const Color(0xFFFF00FF); // Magenta
    list[7] = const Color(0xFFFFFFFF); // White / Black
    list[8] = const Color(0xFF808080); // Dark Gray
    list[9] = const Color(0xFFC0C0C0); // Light Gray

    // 10-249: 24 hues with 5 lightness/saturation variations each (10 levels per hue)
    const hues = 24;
    for (int hueIdx = 0; hueIdx < hues; hueIdx++) {
      final double hue = (hueIdx * 15.0); // 0, 15, 30 ... 345 degrees
      for (int shade = 0; shade < 10; shade++) {
        final int index = 10 + (hueIdx * 10) + shade;
        if (index > 249) break;

        double s = 1.0;
        double v = 1.0;

        switch (shade) {
          case 0:
            s = 1.0;
            v = 1.0;
            break;
          case 1:
            s = 0.8;
            v = 1.0;
            break;
          case 2:
            s = 0.6;
            v = 1.0;
            break;
          case 3:
            s = 0.4;
            v = 1.0;
            break;
          case 4:
            s = 0.2;
            v = 1.0;
            break;
          case 5:
            s = 1.0;
            v = 0.8;
            break;
          case 6:
            s = 0.8;
            v = 0.8;
            break;
          case 7:
            s = 0.6;
            v = 0.8;
            break;
          case 8:
            s = 0.4;
            v = 0.6;
            break;
          case 9:
            s = 0.2;
            v = 0.4;
            break;
        }

        list[index] = HSVColor.fromAHSV(1.0, hue, s, v).toColor();
      }
    }

    // 250-255: Grayscale shades
    list[250] = const Color(0xFF333333);
    list[251] = const Color(0xFF5B5B5B);
    list[252] = const Color(0xFF848484);
    list[253] = const Color(0xFFADADAD);
    list[254] = const Color(0xFFD6D6D6);
    list[255] = const Color(0xFFFFFFFF);

    return List.unmodifiable(list);
  }

  /// Resolves an entity's color given its color index, optional TrueColor,
  /// layer color, block color, and whether the canvas background is dark.
  static Color resolveColor({
    int? colorIndex,
    int? trueColor,
    Color? layerColor,
    Color? blockColor,
    bool isDarkBackground = true,
  }) {
    // 1. TrueColor (Group 420): 24-bit integer 0xRRGGBB
    if (trueColor != null && trueColor > 0) {
      final int rgb = trueColor & 0x00FFFFFF;
      final color = Color(0xFF000000 | rgb);
      return _ensureContrast(color, isDarkBackground);
    }

    // 2. Color Index
    final int idx = colorIndex ?? 256;

    // 256: ByLayer
    if (idx == 256) {
      final base = layerColor ?? (isDarkBackground ? Colors.white : Colors.black);
      return _ensureContrast(base, isDarkBackground);
    }

    // 0: ByBlock
    if (idx == 0) {
      final base = blockColor ?? (isDarkBackground ? Colors.white : Colors.black);
      return _ensureContrast(base, isDarkBackground);
    }

    // Negative index: Layer is turned OFF in DXF, but if entity has negative color, treat as absolute
    final int absIdx = idx.abs();

    // Color 7: Special CAD color (White on dark background, Black on light background)
    if (absIdx == 7) {
      return isDarkBackground ? Colors.white : const Color(0xFF1A1A1A);
    }

    if (absIdx >= 1 && absIdx <= 255) {
      final color = aciColors[absIdx];
      return _ensureContrast(color, isDarkBackground);
    }

    return isDarkBackground ? Colors.white : Colors.black;
  }

  /// Ensure color is visible against the background without washing out CAD hues.
  static Color _ensureContrast(Color color, bool isDarkBg) {
    if (isDarkBg) {
      // If dark background and color is almost pitch black, brighten it
      if (color.r < 0.14 && color.g < 0.14 && color.b < 0.14) {
        return const Color(0xFFE0E0E0);
      }
    } else {
      // If light background and color is almost white, darken it
      if (color.r > 0.94 && color.g > 0.94 && color.b > 0.94) {
        return const Color(0xFF1E1E1E);
      }
    }
    return color;
  }
}
