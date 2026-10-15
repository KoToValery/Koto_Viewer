import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../models/architect_elements.dart';

import '../models/architect_project.dart';

class DimensionTier {
  final int tierIndex; // 1 = structural/base, 2 = openings, 3 = overall
  final List<Offset> points;
  final List<(Offset, Offset)> segments;
  final (Offset, Offset) line;
  const DimensionTier({
    required this.tierIndex,
    required this.points,
    required this.segments,
    required this.line,
  });
}

class ArchitectDimensionLayout {
  static List<(Offset, Offset)> witnessSegments(
    ArchitectDimension dimension,
    List<DimensionTier> tiers, {
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) {
    final n = dimension.normal;
    final extension = n * dimensionScale.paperToModel(1);
    // Independent short strokes at each row; never bridge back to the wall.
    return [
      for (final tier in tiers)
        for (final point in tier.points) (point - extension, point + extension),
    ];
  }

  static (Offset, Offset)? overallSegment(
    ArchitectDimension dimension,
    double scale, {
    bool hasOpenings = false,
  }) {
    if (dimension.style != ArchitectDimensionStyle.exterior ||
        !dimension.showOverall ||
        dimension.dimensionPoints.length < 3) {
      return null;
    }
    final outward = dimension.normal * (dimension.offsetDistance < 0 ? -1 : 1);
    final rowSpacing = math.max(.45, 36 / scale);
    final shift = outward * (hasOpenings ? rowSpacing * 2 : rowSpacing);
    return (dimension.lineStart + shift, dimension.lineEnd + shift);
  }

  static List<DimensionTier> layoutTiers({
    required ArchitectDimension dimension,
    required double scale,
    ArchitectStorey? storey,
  }) {
    if (dimension.length < 1e-4) return const [];
    final u = dimension.unitVector;
    final n = dimension.normal;
    final outward = n * (dimension.offsetDistance < 0 ? -1 : 1);
    final rowSpacing = math.max(.45, 36 / scale);

    final openingAnchors = dimension.anchors
        .where((a) => a.feature == 'opening')
        .toList();
    final hasOpenings =
        dimension.style == ArchitectDimensionStyle.exterior &&
        openingAnchors.isNotEmpty;

    final tiers = <DimensionTier>[];

    // --- Tier 1: Base / Structural row ---
    final basePoints = <Offset>[];
    if (hasOpenings) {
      final structuralAnchors = dimension.anchors
          .where((a) => a.feature != 'opening')
          .toList();
      if (structuralAnchors.length >= 2) {
        final origin = dimension.startPoint;
        final values = structuralAnchors.map((a) {
          final d = a.point - origin;
          return d.dx * u.dx + d.dy * u.dy;
        }).toList()..sort();
        final unique = <double>[];
        for (final v in values) {
          if (unique.isEmpty || (v - unique.last).abs() > 1e-6) {
            unique.add(v);
          }
        }
        basePoints.addAll(unique.map((t) => dimension.lineStart + u * t));
      }
    }
    if (basePoints.length < 2) {
      basePoints.clear();
      basePoints.addAll(dimension.dimensionPoints);
    }

    if (basePoints.length >= 2) {
      tiers.add(
        DimensionTier(
          tierIndex: 1,
          points: basePoints,
          line: (basePoints.first, basePoints.last),
          segments: [
            for (var i = 0; i < basePoints.length - 1; i++)
              (basePoints[i], basePoints[i + 1]),
          ],
        ),
      );
    }

    // --- Tier 2: Openings row (starts from exterior corner of containing wall) ---
    if (hasOpenings) {
      final lineStart2 = dimension.lineStart + outward * rowSpacing;
      final hostWall = storey?.walls.where((w) {
        return w.doors.any(
              (d) => openingAnchors.any((a) => a.elementId == d.id),
            ) ||
            w.windows.any(
              (win) => openingAnchors.any((a) => a.elementId == win.id),
            );
      }).firstOrNull;

      final openingPoints = <Offset>[];
      final origin = dimension.startPoint;

      if (hostWall != null) {
        final corner1 =
            hostWall.coreCenterStart +
            hostWall.exteriorNormal * (hostWall.coreThickness / 2);
        final corner2 =
            hostWall.coreCenterEnd +
            hostWall.exteriorNormal * (hostWall.coreThickness / 2);

        final rawPoints = <Offset>[
          corner1,
          corner2,
          for (final a in openingAnchors) a.point,
        ];
        final values = rawPoints.map((p) {
          final d = p - origin;
          return d.dx * u.dx + d.dy * u.dy;
        }).toList()..sort();

        final unique = <double>[];
        for (final v in values) {
          if (unique.isEmpty || (v - unique.last).abs() > 1e-6) {
            unique.add(v);
          }
        }
        openingPoints.addAll(unique.map((t) => lineStart2 + u * t));
      } else {
        final values = openingAnchors.map((a) {
          final d = a.point - origin;
          return d.dx * u.dx + d.dy * u.dy;
        }).toList()..sort();
        final unique = <double>[];
        for (final v in values) {
          if (unique.isEmpty || (v - unique.last).abs() > 1e-6) {
            unique.add(v);
          }
        }
        openingPoints.addAll(unique.map((t) => lineStart2 + u * t));
      }

      if (openingPoints.length >= 2) {
        tiers.add(
          DimensionTier(
            tierIndex: 2,
            points: openingPoints,
            line: (openingPoints.first, openingPoints.last),
            segments: [
              for (var i = 0; i < openingPoints.length - 1; i++)
                (openingPoints[i], openingPoints[i + 1]),
            ],
          ),
        );
      }
    }

    // --- Tier 3: Overall row ---
    final overall = overallSegment(dimension, scale, hasOpenings: hasOpenings);
    if (overall != null) {
      tiers.add(
        DimensionTier(
          tierIndex: 3,
          points: [overall.$1, overall.$2],
          line: overall,
          segments: [overall],
        ),
      );
    }

    return tiers;
  }

  static Offset clearTextPosition(
    Offset preferred,
    Size pixels,
    double scale,
    Offset normal,
    Path obstacles, {
    Rect? visibleBounds,
  }) {
    bool clear(Offset center) =>
        (visibleBounds == null || visibleBounds.contains(center)) &&
        Path.combine(
          PathOperation.intersect,
          obstacles,
          Path()..addRect(
            Rect.fromCenter(
              center: center,
              width: pixels.width / scale,
              height: pixels.height / scale,
            ),
          ),
        ).computeMetrics().isEmpty;
    if (clear(preferred)) return preferred;
    final bounds = obstacles.getBounds();
    final limit =
        (math.max(bounds.width, bounds.height) * scale / 12).ceil() + 40;
    for (var step = 1; step <= limit; step++) {
      for (final sign in [1.0, -1.0]) {
        final candidate = preferred + normal * (step * 12 / scale * sign);
        if (clear(candidate)) return candidate;
      }
    }
    return visibleBounds != null
        ? preferred
        : preferred + normal * (limit * 24 / scale);
  }

  /// Axis-aligned screen text stays clear of a wall at every angle and zoom.
  static Rect wallBadge(
    ArchitectWall wall,
    Size pixels,
    double scale, {
    Path? obstacles,
  }) {
    final n = wall.exteriorNormal;
    final halfWidth = pixels.width / scale / 2,
        halfHeight = pixels.height / scale / 2;
    final support = n.dx.abs() * halfWidth + n.dy.abs() * halfHeight;
    final midpoint = (wall.centerStart + wall.centerEnd) / 2;
    final path = obstacles ?? (Path()..addPolygon(wall.polygonCorners, true));
    Rect candidate(double sign, int step) => Rect.fromCenter(
      center:
          midpoint +
          n * sign * (wall.thickness / 2 + support + (8 + step * 12) / scale),
      width: pixels.width / scale,
      height: pixels.height / scale,
    );
    for (var step = 0; step < 40; step++) {
      for (final sign in [1.0, -1.0]) {
        final rect = candidate(sign, step);
        final overlap = Path.combine(
          PathOperation.intersect,
          path,
          Path()..addRect(rect),
        );
        if (overlap.computeMetrics().isEmpty) return rect;
      }
    }
    // Dense drawings: go beyond the complete network bounds.
    final bounds = path.getBounds();
    return candidate(
      1,
      (math.max(bounds.width, bounds.height) * scale / 12).ceil() + 40,
    );
  }
}
