import 'dart:math' as math;
import 'dart:ui';

/// Helper for resolving, normalizing, and generating dashed, dotted, and dash-dot CAD linetypes.
class DxfLinetypeHelper {
  /// Standard CAD and ArchiCAD Linetype pattern definitions in drawing units/points:
  /// Pattern elements: positive numbers = dash/dot length, space length.
  static const List<double> dashedPattern = [12.0, 6.0];
  static const List<double> dottedPattern = [2.2, 4.5];
  static const List<double> longDashedPattern = [22.0, 8.0];
  static const List<double> dashDotPattern = [14.0, 4.5, 2.5, 4.5];
  static const List<double> dashDotDotPattern = [14.0, 4.0, 2.5, 3.5, 2.5, 4.0];
  static const List<double> centerPattern = [18.0, 4.5, 4.5, 4.5];
  static const List<double> phantomPattern = [20.0, 4.5, 4.5, 3.5, 4.5, 4.5];
  static const List<double> hiddenPattern = [6.0, 3.5];
  static const List<double> borderPattern = [16.0, 4.0, 16.0, 4.0, 3.0, 4.0];
  static const List<double> zigzagPattern = [12.0, 5.0];

  /// Normalizes custom DXF table patterns (especially Archicad exports scaled to 1:50/1:100/1:500/1:1000)
  /// so that dashes, dots, and spaces are visually crisp, balanced, and consistent on screen.
  static List<double> normalizePattern(List<double> pattern) {
    if (pattern.isEmpty) return pattern;

    // 1. Detect pure or predominantly dotted patterns (where positive elements are dots <= 2.5)
    // E.g., Archicad LTYPE007 [1.8, 50.0, 1.8, 50.0], Dense Dotted [1.8, 88.19], or [0.0, 50.0]
    bool isPureDotted = true;
    for (int i = 0; i < pattern.length; i += 2) {
      if (pattern[i] > 2.5) {
        isPureDotted = false;
        break;
      }
    }

    if (isPureDotted) {
      // Check if spaces are oversized due to CAD/Archicad drawing scale
      bool hasOversizedSpaces = false;
      for (int i = 1; i < pattern.length; i += 2) {
        if (pattern[i] >= 12.0) {
          hasOversizedSpaces = true;
          break;
        }
      }

      if (hasOversizedSpaces) {
        double avgSpace = 0;
        int spaceCount = 0;
        for (int i = 1; i < pattern.length; i += 2) {
          avgSpace += pattern[i];
          spaceCount++;
        }
        avgSpace = spaceCount > 0 ? avgSpace / spaceCount : 1.0;

        final normalized = <double>[];
        for (int i = 0; i < pattern.length; i++) {
          if (i % 2 == 0) {
            normalized.add(2.2); // Crisp screen dot
          } else {
            final relativeRatio = pattern[i] / avgSpace;
            normalized.add((4.5 * relativeRatio).clamp(2.5, 10.0));
          }
        }
        return normalized;
      }

      // If spaces are already small, ensure dots are at least 1.8 - 2.2 px
      return pattern.map((v) => v <= 0.5 ? 2.0 : v).toList();
    }

    // 2. Scale oversized CAD model-space patterns (total length > 55.0 from Archicad scale)
    final double totalLength = pattern.fold<double>(0.0, (sum, val) => sum + val);

    if (totalLength > 55.0) {
      final double targetCycle = pattern.length <= 2
          ? 20.0
          : (pattern.length <= 4 ? 28.0 : 38.0);
      final double scaleFactor = targetCycle / totalLength;

      final normalized = <double>[];
      for (int i = 0; i < pattern.length; i++) {
        final scaled = pattern[i] * scaleFactor;
        if (i % 2 == 0) {
          if (pattern[i] <= 2.5) {
            normalized.add(2.2);
          } else {
            normalized.add(math.max(scaled, 1.8));
          }
        } else {
          normalized.add(math.max(scaled, 2.0));
        }
      }
      return normalized;
    }

    // 3. Scale undersized imperial AutoCAD patterns (total length < 4.0 in inches)
    if (totalLength < 4.0 && totalLength > 0) {
      return pattern.map((v) => v * 25.4).toList();
    }

    return pattern;
  }

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

    final norm = raw.toLowerCase().replaceAll(RegExp(r'[^\p{L}0-9]', unicode: true), '');
    if (norm == 'continuous' ||
        norm == 'solid' ||
        norm == 'bylayer' ||
        norm == 'byblock' ||
        norm == 'непрекъсната' ||
        norm == 'плътна') {
      return null;
    }

    // 1. Check if exact custom linetype is defined in DXF document table
    if (customLineTypes != null && customLineTypes.isNotEmpty) {
      List<double>? customPattern;
      if (customLineTypes.containsKey(raw)) {
        customPattern = customLineTypes[raw];
      } else if (customLineTypes.containsKey(raw.toUpperCase())) {
        customPattern = customLineTypes[raw.toUpperCase()];
      } else {
        for (final entry in customLineTypes.entries) {
          final entryNorm = entry.key.toLowerCase().replaceAll(RegExp(r'[^\p{L}0-9]', unicode: true), '');
          if (entryNorm == norm) {
            customPattern = entry.value;
            break;
          }
        }
      }
      if (customPattern != null && customPattern.isNotEmpty) {
        return normalizePattern(customPattern);
      }
    }

    // 2. Dash-Dot-Dot / Divide pattern (including Archicad LTYPE009)
    if (norm.contains('dashdotdot') ||
        norm.contains('dash2dot') ||
        norm.contains('dot2dash') ||
        norm.contains('divide') ||
        norm.contains('двойнаточк') ||
        norm.contains('дветочки') ||
        norm.contains('acadiso05') ||
        norm.contains('acadiso12') ||
        norm == 'ltype009') {
      return dashDotDotPattern;
    }

    // 3. Dash-Dot / Dot & Dashed / Chain pattern
    if (norm.contains('dashdot') ||
        norm.contains('dotdash') ||
        norm.contains('dotdashed') ||
        norm.contains('chain') ||
        norm.contains('штрихпункт') ||
        norm.contains('тиреточка') ||
        norm.contains('чертаиточка') ||
        norm.contains('точкаитире') ||
        norm.contains('acadiso04') ||
        norm.contains('acadiso11')) {
      return dashDotPattern;
    }

    // 4. Centerline / Center pattern (including Archicad LTYPE006, LTYPE008)
    if (norm.contains('center') ||
        norm.contains('osova') ||
        norm.contains('осов') ||
        norm.contains('осев') ||
        norm.contains('цент') ||
        norm.contains('acadiso08') ||
        norm.contains('acadiso14') ||
        norm == 'ltype006' ||
        norm == 'ltype008') {
      return centerPattern;
    }

    // 5. Long Dashed pattern (including Archicad LTYPE005)
    if (norm.contains('longdash') ||
        norm.contains('дългапрекъснат') ||
        norm.contains('дългичерти') ||
        norm == 'ltype005') {
      return longDashedPattern;
    }

    // 6. Phantom line pattern
    if (norm.contains('phantom') || norm.contains('acadiso10') || norm.contains('acadiso15')) {
      return phantomPattern;
    }

    // 7. Hidden / Short Dashed line pattern (including Archicad LTYPE004, LTYPE010)
    if (norm.contains('hidden') ||
        norm.contains('shortdash') ||
        norm.contains('късапрекъснат') ||
        norm.contains('скрит') ||
        norm.contains('acadiso06') ||
        norm == 'ltype004' ||
        norm == 'ltype010') {
      return hiddenPattern;
    }

    // 8. Border line pattern
    if (norm.contains('border') || norm.contains('границ') || norm.contains('acadiso09')) {
      return borderPattern;
    }

    // 9. Dashed line pattern (including Archicad LTYPE003)
    if (norm.contains('dash') ||
        norm.contains('прекъснат') ||
        norm.contains('штрих') ||
        norm.contains('чертичк') ||
        norm.contains('acadiso02') ||
        norm.contains('acadiso03') ||
        norm.contains('acadiso13') ||
        norm == 'ltype003') {
      return dashedPattern;
    }

    // 10. Dotted / Dot / Punktir pattern (including Archicad LTYPE002, LTYPE007)
    if (norm.contains('dot') ||
        norm.contains('punkt') ||
        norm.contains('пункт') ||
        norm.contains('точк') ||
        norm.contains('point') ||
        norm.contains('acadiso07') ||
        norm.contains('acadiso01') ||
        norm == 'ltype002' ||
        norm == 'ltype007') {
      return dottedPattern;
    }

    // 11. Zigzag / Insulation / Batting
    if (norm.contains('zigzag') || norm.contains('зигзаг') || norm.contains('batting') || norm.contains('изолаци')) {
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
