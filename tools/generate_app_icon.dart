import 'dart:io';
import 'package:image/image.dart';

const int iconSize = 1024;
const int pdfBoxWidth = 520;
const int pdfBoxHeight = 700;
const int radius = 60;

// Color helpers (bitwise operations for 32-bit ARGB)
int _r(int c) => (c >> 16) & 0xFF;
int _g(int c) => (c >> 8) & 0xFF;
int _b(int c) => c & 0xFF;
int _a(int c) => (c >> 24) & 0xFF;
int _argb(int a, int r, int g, int b) =>
    ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);

/// Linearly interpolate between two colors.
int lerpColor(int c1, int c2, double t) {
  final r1 = _r(c1);
  final g1 = _g(c1);
  final b1 = _b(c1);
  final a1 = _a(c1);

  final r2 = _r(c2);
  final g2 = _g(c2);
  final b2 = _b(c2);
  final a2 = _a(c2);

  final r = (r1 + (r2 - r1) * t).round().clamp(0, 255);
  final g = (g1 + (g2 - g1) * t).round().clamp(0, 255);
  final b = (b1 + (b2 - b1) * t).round().clamp(0, 255);
  final a = (a1 + (a2 - a1) * t).round().clamp(0, 255);

  return _argb(a, r, g, b);
}

/// Draw a vertical gradient background.
void drawGradientBackground(Image img, int topColor, int bottomColor) {
  for (int y = 0; y < img.height; y++) {
    final t = y / (img.height - 1);
    final color = lerpColor(topColor, bottomColor, t);
    final cr = _r(color);
    final cg = _g(color);
    final cb = _b(color);
    final ca = _a(color);
    for (int x = 0; x < img.width; x++) {
      img.setPixelRgba(x, y, cr, cg, cb, ca);
    }
  }
}

/// Draw a rounded rectangle filled with [color].
void drawRoundedRect(
  Image img,
  int x,
  int y,
  int w,
  int h,
  int radius,
  int color,
) {
  final cr = _r(color);
  final cg = _g(color);
  final cb = _b(color);
  final ca = _a(color);

  // Center fill
  for (int py = y + radius; py < y + h - radius; py++) {
    for (int px = x; px < x + w; px++) {
      img.setPixelRgba(px, py, cr, cg, cb, ca);
    }
  }

  // Top strip (no corners)
  for (int py = y; py < y + radius; py++) {
    for (int px = x + radius; px < x + w - radius; px++) {
      img.setPixelRgba(px, py, cr, cg, cb, ca);
    }
  }

  // Bottom strip (no corners)
  for (int py = y + h - radius; py < y + h; py++) {
    for (int px = x + radius; px < x + w - radius; px++) {
      img.setPixelRgba(px, py, cr, cg, cb, ca);
    }
  }

  // Left strip
  for (int py = y + radius; py < y + h - radius; py++) {
    for (int px = x; px < x + radius; px++) {
      img.setPixelRgba(px, py, cr, cg, cb, ca);
    }
  }

  // Right strip
  for (int py = y + radius; py < y + h - radius; py++) {
    for (int px = x + w - radius; px < x + w; px++) {
      img.setPixelRgba(px, py, cr, cg, cb, ca);
    }
  }

  // Four corners
  drawCircleCorner(img, x + radius, y + radius, radius, color, 2); // top-left
  drawCircleCorner(
    img,
    x + w - radius - 1,
    y + radius,
    radius,
    color,
    3,
  ); // top-right
  drawCircleCorner(
    img,
    x + radius,
    y + h - radius - 1,
    radius,
    color,
    0,
  ); // bottom-left
  drawCircleCorner(
    img,
    x + w - radius - 1,
    y + h - radius - 1,
    radius,
    color,
    1,
  ); // bottom-right
}

/// Draw a quarter of a circle for rounded corners.
void drawCircleCorner(
  Image img,
  int cx,
  int cy,
  int r,
  int color,
  int quadrant,
) {
  final cr = _r(color);
  final cg = _g(color);
  final cb = _b(color);
  final ca = _a(color);

  for (int y = -r; y <= r; y++) {
    for (int x = -r; x <= r; x++) {
      final dist = x * x + y * y;
      if (dist <= r * r) {
        bool inside = false;
        switch (quadrant) {
          case 0:
            inside = (x <= 0 && y >= 0);
            break;
          case 1:
            inside = (x >= 0 && y >= 0);
            break;
          case 2:
            inside = (x <= 0 && y <= 0);
            break;
          case 3:
            inside = (x >= 0 && y <= 0);
            break;
        }
        if (inside) {
          final px = cx + x;
          final py = cy + y;
          if (px >= 0 && px < img.width && py >= 0 && py < img.height) {
            img.setPixelRgba(px, py, cr, cg, cb, ca);
          }
        }
      }
    }
  }
}

/// Draw a thick horizontal or vertical line.
void drawThickLine(
  Image img,
  int x1,
  int y1,
  int x2,
  int y2,
  int thickness,
  int color,
) {
  final cr = _r(color);
  final cg = _g(color);
  final cb = _b(color);
  final ca = _a(color);

  if (y1 == y2) {
    for (int py = y1 - thickness ~/ 2; py <= y1 + thickness ~/ 2; py++) {
      for (int px = x1; px <= x2; px++) {
        if (px >= 0 && px < img.width && py >= 0 && py < img.height) {
          img.setPixelRgba(px, py, cr, cg, cb, ca);
        }
      }
    }
  } else if (x1 == x2) {
    for (int px = x1 - thickness ~/ 2; px <= x1 + thickness ~/ 2; px++) {
      for (int py = y1; py <= y2; py++) {
        if (px >= 0 && px < img.width && py >= 0 && py < img.height) {
          img.setPixelRgba(px, py, cr, cg, cb, ca);
        }
      }
    }
  }
}

/// Draw pixel-art letter.
void drawPattern(
  Image img,
  int x,
  int y,
  int pixelSize,
  List<List<int>> pattern,
  int color,
) {
  final cr = _r(color);
  final cg = _g(color);
  final cb = _b(color);
  final ca = _a(color);
  for (int row = 0; row < pattern.length; row++) {
    for (int col = 0; col < pattern[row].length; col++) {
      if (pattern[row][col] == 1) {
        for (int dy = 0; dy < pixelSize; dy++) {
          for (int dx = 0; dx < pixelSize; dx++) {
            final px = x + col * pixelSize + dx;
            final py = y + row * pixelSize + dy;
            if (px >= 0 && px < img.width && py >= 0 && py < img.height) {
              img.setPixelRgba(px, py, cr, cg, cb, ca);
            }
          }
        }
      }
    }
  }
}

// Letter patterns (6 rows x 3 cols)
const letterP = [
  [1, 1, 0],
  [1, 0, 1],
  [1, 1, 0],
  [1, 0, 0],
  [1, 0, 0],
  [1, 0, 0],
];
const letterD = [
  [1, 1, 0],
  [1, 0, 1],
  [1, 0, 1],
  [1, 0, 1],
  [1, 0, 1],
  [1, 1, 0],
];
const letterF = [
  [1, 1, 1],
  [1, 0, 0],
  [1, 1, 0],
  [1, 0, 0],
  [1, 0, 0],
  [1, 0, 0],
];

void main() {
  final outputDir = Directory('assets/icons');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Colors
  const topColor = 0xFF4F46E5; // Indigo
  const bottomColor = 0xFF7C3AED; // Purple
  const whiteColor = 0xFFFFFFFF;
  const accentColor = 0xFFEEF2FF; // Very light indigo

  // Shared coordinates
  final boxX = (iconSize - pdfBoxWidth) ~/ 2;
  final boxY = (iconSize - pdfBoxHeight) ~/ 2;
  const foldSize = 110;
  const pixelSize = 38;
  const totalWidth = 3 * 3 * pixelSize + 2 * pixelSize;
  final textX = boxX + (pdfBoxWidth - totalWidth) ~/ 2;
  final textY = boxY + 80;

  final lineYStart = boxY + 260;
  const lineGap = 70;
  final leftMargin = boxX + 90;
  final rightMargin = boxX + pdfBoxWidth - 90;
  final shortRight = boxX + pdfBoxWidth - 200;

  final acr = _r(accentColor);
  final acg = _g(accentColor);
  final acb = _b(accentColor);
  final aca = _a(accentColor);

  // Helper: draws the PDF content onto a given image
  void drawPdfContent(Image img) {
    // Draw rounded white PDF box
    drawRoundedRect(
      img,
      boxX,
      boxY,
      pdfBoxWidth,
      pdfBoxHeight,
      radius,
      whiteColor,
    );

    // Draw fold diagonal line
    for (int i = 0; i < foldSize; i++) {
      final px = boxX + pdfBoxWidth - foldSize + i;
      final py = boxY + (foldSize - i);
      if (px >= 0 && px < img.width && py >= 0 && py < img.height) {
        img.setPixelRgba(px, py, acr, acg, acb, aca);
      }
    }

    // Draw horizontal lines (like text content)
    drawThickLine(
      img,
      leftMargin,
      lineYStart,
      shortRight,
      lineYStart,
      26,
      accentColor,
    );
    drawThickLine(
      img,
      leftMargin,
      lineYStart + lineGap,
      rightMargin,
      lineYStart + lineGap,
      26,
      accentColor,
    );
    drawThickLine(
      img,
      leftMargin,
      lineYStart + lineGap * 2,
      shortRight,
      lineYStart + lineGap * 2,
      26,
      accentColor,
    );
    drawThickLine(
      img,
      leftMargin,
      lineYStart + lineGap * 3,
      rightMargin - 80,
      lineYStart + lineGap * 3,
      26,
      accentColor,
    );

    // Draw "PDF" letters
    drawPattern(img, textX, textY, pixelSize, letterP, topColor);
    drawPattern(
      img,
      textX + 3 * pixelSize + pixelSize,
      textY,
      pixelSize,
      letterD,
      topColor,
    );
    drawPattern(
      img,
      textX + 2 * (3 * pixelSize + pixelSize),
      textY,
      pixelSize,
      letterF,
      topColor,
    );
  }

  // -------------------- app_icon.png (full icon) --------------------
  print('🔨 Generating app_icon.png (1024x1024)...');
  final fullIcon = Image(width: iconSize, height: iconSize);
  drawGradientBackground(fullIcon, topColor, bottomColor);
  drawPdfContent(fullIcon);

  final fullIconPng = encodePng(fullIcon);
  final outFile = File('${outputDir.path}/app_icon.png');
  outFile.writeAsBytesSync(fullIconPng);
  print('✅ Saved ${outFile.path} (${outFile.lengthSync()} bytes)');

  // -------------------- app_icon_foreground.png --------------------
  print('🔨 Generating app_icon_foreground.png (1024x1024)...');
  final fgIcon = Image(width: iconSize, height: iconSize);
  drawPdfContent(fgIcon);

  final fgIconPng = encodePng(fgIcon);
  final fgFile = File('${outputDir.path}/app_icon_foreground.png');
  fgFile.writeAsBytesSync(fgIconPng);
  print('✅ Saved ${fgFile.path} (${fgFile.lengthSync()} bytes)');

  print('\n🎉 Icons generated successfully!');
}
