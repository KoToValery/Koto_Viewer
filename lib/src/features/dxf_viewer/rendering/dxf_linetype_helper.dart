import 'dart:math' as math;
import 'dart:ui';

/// Helper for resolving and generating dashed, dotted, and dash-dot CAD linetypes.
class DxfLinetypeHelper {
  /// Standard CAD and ArchiCAD Linetype pattern definitions in drawing units/points:
  /// Pattern elements: positive numbers = dash/dot length, space length.
  static const List<double> dashedPattern = [12.0, 6.0];
  static const List<double> dottedPattern = [2.0, 4.5];
  static const List<double> dashDotPattern = [14.0, 4.5, 2.5, 4.5];
  static const List<double> dashDotDotPattern = [14.0, 4.0, 2.5, 3.5, 2.5, 4.0];
  static const List<double> centerPattern = [18.0, 4.5, 4.5, 4.5];
  static const List<double> phantomPattern = [20.0, 4.5, 4.5, 3.5, 4.5, 4.5];
  static const List<double> hiddenPattern = [6.0, 3.5];
  static const List<double> borderPattern = [16.0, 4.0, 16.0, 4.0, 3.0, 4.0];
  static const List<double> zigzagPattern = [12.0, 5.0];

  /// Resolves effective linetype pattern from entity linetype, layer linetype, and DXF table LTYPE definitions.
  /// Returns null for solid/continuous lines.
  static List<double>? resolvePattern(
    String? lineType, {
    String? layerLineType,
    Map<String, List<double>>? customLineTypes,
  }) {
    String? raw = lineType?.trim();
    if (raw == null || raw.isEmpty || raw.toUpperCase() == 'BYLAYER' || raw.toUpperCase() == 'BYBLOCK') {
      raw = layerLineType?.trim();
    }
    if (raw == null || raw.isEmpty) return null;

    final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (norm == 'continuous' || norm == 'solid' || norm == 'bylayer' || norm == 'byblock') {
      return null;
    }

    // 1. Check if exact custom linetype is defined in DXF document table
    if (customLineTypes != null && customLineTypes.isNotEmpty) {
      if (customLineTypes.containsKey(raw)) return customLineTypes[raw];
      if (customLineTypes.containsKey(raw.toUpperCase())) return customLineTypes[raw.toUpperCase()];
      for (final entry in customLineTypes.entries) {
        if (entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') == norm) {
          return entry.value;
        }
      }
    }

    // 2. Dash-Dot-Dot / Divide (тире-точка-точка / двойна точка)
    if (norm.contains('dashdotdot') ||
        norm.contains('dash2dot') ||
        norm.contains('dot2dash') ||
        norm.contains('divide') ||
        norm.contains('acadiso05') ||
        norm.contains('acadiso12')) {
      return dashDotDotPattern;
    }

    // 3. Dash-Dot / Dot & Dashed / Chain (тире-точка / точка и къса линия)
    if (norm.contains('dashdot') ||
        norm.contains('dotdash') ||
        norm.contains('dotdashed') ||
        norm.contains('chain') ||
        norm.contains('acadiso04') ||
        norm.contains('acadiso11')) {
      return dashDotPattern;
    }

    // 4. Centerline / Osova (осова линия - дълго тире и късо тире)
    if (norm.contains('center') || norm.contains('osova') || norm.contains('acadiso08') || norm.contains('acadiso14')) {
      return centerPattern;
    }

    // 5. Phantom (фантомна линия)
    if (norm.contains('phantom') || norm.contains('acadiso10') || norm.contains('acadiso15')) {
      return phantomPattern;
    }

    // 6. Hidden line (скрит контур - къси тирета)
    if (norm.contains('hidden') || norm.contains('acadiso06')) {
      return hiddenPattern;
    }

    // 7. Border line (гранична линия)
    if (norm.contains('border') || norm.contains('acadiso09')) {
      return borderPattern;
    }

    // 8. Dashed (прекъсната линия - стандартни тирета)
    if (norm.contains('dash') || norm.contains('acadiso02') || norm.contains('acadiso03') || norm.contains('acadiso13')) {
      return dashedPattern;
    }

    // 9. Dotted / Punktir (пунктир)
    if (norm.contains('dot') || norm.contains('punkt') || norm.contains('point') || norm.contains('acadiso07') || norm.contains('acadiso01')) {
      return dottedPattern;
    }

    if (norm.contains('zigzag')) {
      return zigzagPattern;
    }

    return dashedPattern; // Default fallback for any non-continuous broken line
  }

  /// Converts a continuous [Path] into a dashed/dotted [Path] based on [pattern].
  static Path createDashedPath(
    Path sourcePath,
    List<double> pattern, {
    double scale = 1.0,
  }) {
    if (pattern.isEmpty) return sourcePath;
    final effectiveScale = scale > 0 ? scale : 1.0;

    final dashedPath = Path();
    for (final metric in sourcePath.computeMetrics()) {
      double distance = 0.0;
      int patternIndex = 0;
      bool draw = true;

      while (distance < metric.length) {
        final length = pattern[patternIndex % pattern.length] * effectiveScale;
        final nextDistance = math.min(distance + length, metric.length);

        if (draw && nextDistance > distance) {
          dashedPath.addPath(
            metric.extractPath(distance, nextDistance),
            Offset.zero,
          );
        }

        distance = nextDistance;
        draw = !draw;
        patternIndex++;
      }
    }
    return dashedPath;
  }

  /// Creates a dashed [Path] directly from a 2D line segment [p1] -> [p2].
  static Path createDashedLine(
    Offset p1,
    Offset p2,
    List<double> pattern, {
    double scale = 1.0,
  }) {
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy);
    return createDashedPath(path, pattern, scale: scale);
  }
}
