import 'package:flutter/material.dart';

/// Single vector stroke in an HPGL plotter drawing.
class HpglElement {
  final List<Offset> points;
  final Color color;
  final double lineWidth;
  final bool isClosed;
  final bool isFilled;

  const HpglElement({
    required this.points,
    required this.color,
    this.lineWidth = 1.0,
    this.isClosed = false,
    this.isFilled = false,
  });
}

/// Bounding box for HPGL drawings in plotter units.
class HpglBoundingBox {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const HpglBoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  double get width => (maxX - minX).abs();
  double get height => (maxY - minY).abs();

  static const HpglBoundingBox defaultBox = HpglBoundingBox(
    minX: 0,
    minY: 0,
    maxX: 10000,
    maxY: 8000,
  );
}

/// Complete parsed HPGL Plotter Document.
class HpglDocument {
  final String fileName;
  final List<HpglElement> elements;
  final HpglBoundingBox boundingBox;
  final int penCount;

  const HpglDocument({
    required this.fileName,
    required this.elements,
    required this.boundingBox,
    this.penCount = 1,
  });

  int get totalPoints => elements.fold(0, (sum, el) => sum + el.points.length);
}

/// Standard HPGL Pen Color Palette.
class HpglPenPalette {
  static const List<Color> standardPens = [
    Colors.white70,         // Pen 0 (default / background pen)
    Color(0xFF38BDF8),      // Pen 1: Cyan / Light Blue
    Color(0xFFEF4444),      // Pen 2: Red
    Color(0xFF22C55E),      // Pen 3: Green
    Color(0xFFF59E0B),      // Pen 4: Yellow / Amber
    Color(0xFFA855F7),      // Pen 5: Magenta / Purple
    Color(0xFF3B82F6),      // Pen 6: Dark Blue
    Color(0xFFF97316),      // Pen 7: Orange
    Color(0xFF94A3B8),      // Pen 8: Grey
  ];

  static Color getPenColor(int penNumber, bool isDark) {
    if (penNumber == 0) {
      return isDark ? Colors.white70 : Colors.black87;
    }
    final index = penNumber % standardPens.length;
    final c = standardPens[index];
    if (!isDark && c == Colors.white70) return Colors.black87;
    return c;
  }
}
