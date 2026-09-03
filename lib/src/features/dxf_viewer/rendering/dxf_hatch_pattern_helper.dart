import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_models.dart';

/// Helper to resolve and manage CAD hatch pattern lines.
/// When a DXF / DWG hatch does not have embedded pattern definition lines (group 78),
/// this helper provides standard AutoCAD / ISO .pat definitions.
class DxfHatchPatternHelper {
  const DxfHatchPatternHelper._();

  /// Resolves the list of pattern lines to render for [hatch].
  /// If the hatch contains embedded pattern lines from the CAD export, they are returned directly.
  /// Otherwise, standard pattern definitions are resolved by pattern name, with angle and scale applied.
  static List<DxfHatchPatternLine> resolvePatternLines(
    DxfHatch hatch, {
    Offset fallbackOrigin = Offset.zero,
    double defaultScale = 1.0,
  }) {
    // 1. Embedded definition lines take highest priority (standard in Archicad DWG / LibreDWG exports)
    if (hatch.patternLines != null && hatch.patternLines!.isNotEmpty) {
      return hatch.patternLines!;
    }

    final name = hatch.patternName.trim().toUpperCase();
    final double scale = (hatch.patternScale > 0 ? hatch.patternScale : 1.0) * defaultScale;
    final double angleDeg = hatch.patternAngle;

    return _generateFallbackPattern(name, angleDeg, scale, fallbackOrigin);
  }

  static List<DxfHatchPatternLine> _generateFallbackPattern(
    String name,
    double angleDeg,
    double scale,
    Offset origin,
  ) {
    if (name.contains('ANSI31') || name.contains('LINE') || name.contains('HATCH') || name.contains('DIAGONAL')) {
      return _createParallelPattern(
        angleDeg: 45.0 + angleDeg,
        spacing: 3.175 * scale,
        origin: origin,
      );
    }

    if (name.contains('ANSI32')) {
      // Double diagonal lines
      final spacing = 9.525 * scale;
      final shift = 1.5 * scale;
      final lines = <DxfHatchPatternLine>[];
      lines.addAll(_createParallelPattern(angleDeg: 45.0 + angleDeg, spacing: spacing, origin: origin));
      lines.addAll(_createParallelPattern(
        angleDeg: 45.0 + angleDeg,
        spacing: spacing,
        origin: origin + _rotate(Offset(-shift * 0.7071, shift * 0.7071), angleDeg),
      ));
      return lines;
    }

    if (name.contains('ANSI33') || name.contains('SOLID___DASHED')) {
      // Alternating solid and dashed lines
      final spacing = 6.35 * scale;
      final shift = 3.175 * scale;
      final lines = <DxfHatchPatternLine>[];
      lines.addAll(_createParallelPattern(angleDeg: 45.0 + angleDeg, spacing: spacing, origin: origin));
      lines.addAll(_createParallelPattern(
        angleDeg: 45.0 + angleDeg,
        spacing: spacing,
        origin: origin + _rotate(Offset(-shift * 0.7071, shift * 0.7071), angleDeg),
        dashes: [3.175 * scale, -1.5875 * scale],
      ));
      return lines;
    }

    if (name.contains('ANSI37') || name.contains('CROSS') || name.contains('GRID') || name.contains('NET')) {
      // Cross / Grid diagonal lines
      final spacing = 4.0 * scale;
      final lines = <DxfHatchPatternLine>[];
      lines.addAll(_createParallelPattern(angleDeg: 45.0 + angleDeg, spacing: spacing, origin: origin));
      lines.addAll(_createParallelPattern(angleDeg: 135.0 + angleDeg, spacing: spacing, origin: origin));
      return lines;
    }

    if (name.contains('BRICK') || name.contains('AR-B')) {
      // Running bond masonry pattern (Standard ISO/AutoCAD brick: 250 x 65 mm courses)
      final courseH = 65.0 * scale;
      final brickL = 250.0 * scale;
      final lines = <DxfHatchPatternLine>[];

      // Horizontal bed joints
      lines.addAll(_createParallelPattern(
        angleDeg: 0.0 + angleDeg,
        spacing: courseH,
        origin: origin,
      ));

      // Vertical head joints (alternating every course by brickL / 2)
      final double jointAngle = 90.0 + angleDeg;
      final offsetVec = _rotate(Offset(-courseH, courseH), angleDeg);

      lines.add(DxfHatchPatternLine(
        angle: jointAngle,
        basePoint: origin,
        offset: Offset(offsetVec.dx, brickL),
        dashes: [courseH, -courseH],
      ));

      lines.add(DxfHatchPatternLine(
        angle: jointAngle,
        basePoint: origin + _rotate(Offset(brickL / 2.0, courseH), angleDeg),
        offset: Offset(offsetVec.dx, brickL),
        dashes: [courseH, -courseH],
      ));

      return lines;
    }

    if (name.contains('PLANK') || name.contains('FLOOR') || name.contains('HORIZ')) {
      return _createParallelPattern(
        angleDeg: 0.0 + angleDeg,
        spacing: 20.0 * scale,
        origin: origin,
      );
    }

    if (name.contains('VERT')) {
      return _createParallelPattern(
        angleDeg: 90.0 + angleDeg,
        spacing: 20.0 * scale,
        origin: origin,
      );
    }

    if (name.contains('INSUL') || name.contains('BATT') || name.contains('STYROFOAM')) {
      final spacing = 15.0 * scale;
      final lines = <DxfHatchPatternLine>[];
      lines.addAll(_createParallelPattern(angleDeg: 60.0 + angleDeg, spacing: spacing, origin: origin));
      lines.addAll(_createParallelPattern(angleDeg: 120.0 + angleDeg, spacing: spacing, origin: origin));
      return lines;
    }

    if (name.contains('EARTH') || name.contains('SOIL')) {
      final spacing = 20.0 * scale;
      return _createParallelPattern(
        angleDeg: 45.0 + angleDeg,
        spacing: spacing,
        origin: origin,
        dashes: [10.0 * scale, -5.0 * scale],
      );
    }

    // Standard fallback: 45° parallel lines
    return _createParallelPattern(
      angleDeg: 45.0 + angleDeg,
      spacing: 8.0 * scale,
      origin: origin,
    );
  }

  /// Creates a single family of parallel hatch lines at [angleDeg] with perpendicular distance [spacing].
  static List<DxfHatchPatternLine> _createParallelPattern({
    required double angleDeg,
    required double spacing,
    required Offset origin,
    List<double> dashes = const [],
  }) {
    final rad = angleDeg * math.pi / 180.0;
    // Normal vector perpendicular to line direction in CAD coords (-sin, cos)
    final normX = -math.sin(rad);
    final normY = math.cos(rad);
    final offsetVec = Offset(normX * spacing, normY * spacing);

    return [
      DxfHatchPatternLine(
        angle: angleDeg,
        basePoint: origin,
        offset: offsetVec,
        dashes: dashes,
      ),
    ];
  }

  static Offset _rotate(Offset pt, double angleDeg) {
    if (angleDeg == 0) return pt;
    final rad = angleDeg * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);
    return Offset(pt.dx * cosA - pt.dy * sinA, pt.dx * sinA + pt.dy * cosA);
  }
}
