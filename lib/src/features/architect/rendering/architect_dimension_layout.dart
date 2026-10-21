import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../models/architect_elements.dart';
import '../models/architect_grid_axis.dart';
import '../services/architect_dimension_chain.dart';

import '../models/architect_project.dart';
import 'architect_vector_scene.dart';

class DimensionTier {
  final int tierIndex; // 1 = openings, 2 = wall sections, 3 = overall, 4 = axes
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
  /// Resolve the same annotation profile for painting, drafting and picking.
  /// Camera zoom only magnifies this model-space layout.
  static double rowSpacingFor(
    ArchitectDimension dimension, {
    ArchitectDimensionScale? dimensionScale,
    ArchitectDocument? document,
    String? viewKey,
  }) {
    final scope = ArchitectTextScope.current;
    final doc = document ?? scope?.document ?? const ArchitectDocument();
    final view = viewKey ?? scope?.view ?? '';
    final denominator = document == null && scope != null
        ? scope.denominator
        : doc.viewScales[view] ?? dimensionScale?.denominator ?? 100;
    final height = doc.textMm(
      view,
      dimension.id,
      ArchitectAnnotationRole.dimension,
      denominator,
    );
    final lines = dimension.customText?.split('\n').length ?? 1;
    return ArchitectDrawingScale(denominator).dimensionRowSpacing(height) *
        lines;
  }

  /// Resolve finish picks against the real wall faces, without changing the
  /// saved snap point or moving the positioned dimension line.
  static ({Offset core, Offset finish}) _wallReference(
    Offset point,
    Offset direction,
    List<ArchitectWall> walls,
  ) {
    ({Offset core, Offset finish}) result = (core: point, finish: point);
    var bestAlignment = 1e-6;
    for (final wall in walls) {
      if (wall.isCurved || wall.length < 1e-6) continue;
      final n = wall.exteriorNormal;
      final alignment = ArchitectDimensionChain.dot(direction, n);
      if (alignment.abs() <= bestAlignment) continue;
      final along = ArchitectDimensionChain.dot(
        point - wall.centerStart,
        wall.unitVector,
      );
      // Joined corners can extend past the individual wall rectangle.
      if (along < -wall.thickness - 1e-6 ||
          along > wall.length + wall.thickness + 1e-6) {
        continue;
      }
      for (final side in [-1.0, 1.0]) {
        final core = wall.coreCenterStart + n * (wall.coreThickness / 2 * side);
        final finish = wall.centerStart + n * (wall.thickness / 2 * side);
        final toCore = ArchitectDimensionChain.dot(core - point, n);
        final toFinish = ArchitectDimensionChain.dot(finish - point, n);
        if (math.min(toCore.abs(), toFinish.abs()) > 1e-6 &&
            toCore * toFinish > 0) {
          continue;
        }
        bestAlignment = alignment.abs();
        result = (
          core: point + direction * (toCore / alignment),
          finish: point + direction * (toFinish / alignment),
        );
      }
    }
    return result;
  }

  /// Keep vertical text readable from the right, regardless of pick direction.
  static double textAngle(Offset direction) {
    var angle = math.atan2(direction.dy, direction.dx);
    if (angle >= math.pi / 2 - 1e-9) angle -= math.pi;
    if (angle < -math.pi / 2 - 1e-9) angle += math.pi;
    return angle;
  }

  /// Short insulation labels sit beyond the end ticks on the same row instead
  /// of overlapping their ticks or the main core dimension text.
  static Offset segmentTextCenter({
    required DimensionTier tier,
    required int segmentIndex,
    required Offset direction,
    required double textWidth,
    required double clearance,
  }) {
    final segment = tier.segments[segmentIndex];
    final center = (segment.$1 + segment.$2) / 2;
    if (tier.tierIndex != 3 ||
        tier.segments.length < 2 ||
        (segment.$2 - segment.$1).distance >= textWidth + clearance * 2) {
      return center;
    }
    if (segmentIndex == 0) {
      return segment.$1 - direction * (textWidth / 2 + clearance);
    }
    if (segmentIndex == tier.segments.length - 1) {
      return segment.$2 + direction * (textWidth / 2 + clearance);
    }
    return center;
  }

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
    ArchitectDimensionScale? dimensionScale,
    ArchitectDocument? document,
    String? viewKey,
  }) {
    if (dimension.style != ArchitectDimensionStyle.exterior ||
        !dimension.showOverall ||
        dimension.dimensionPoints.length < 2) {
      return null;
    }
    final outward = dimension.normal * (dimension.offsetDistance < 0 ? -1 : 1);
    final rowSpacing = rowSpacingFor(
      dimension,
      dimensionScale: dimensionScale,
      document: document,
      viewKey: viewKey,
    );
    final shift = outward * (hasOpenings ? rowSpacing * 2 : rowSpacing);
    return (dimension.lineStart + shift, dimension.lineEnd + shift);
  }

  static List<DimensionTier> layoutTiers({
    required ArchitectDimension dimension,
    required double scale,
    ArchitectStorey? storey,
    List<StructuralGridAxis> gridAxes = const [],
    ArchitectDimensionScale? dimensionScale,
    ArchitectDocument? document,
    String? viewKey,
  }) {
    if (dimension.length < 1e-4) return const [];
    final u = dimension.unitVector;
    final outward = dimension.normal * (dimension.offsetDistance < 0 ? -1 : 1);
    double along(Offset p) =>
        ArchitectDimensionChain.dot(p - dimension.startPoint, u);
    final tiers = <DimensionTier>[];
    final rowSpacing = rowSpacingFor(
      dimension,
      dimensionScale: dimensionScale,
      document: document,
      viewKey: viewKey,
    );

    void row(int tier, Iterable<double> positions) {
      final values = positions.toList()..sort();
      final unique = <double>[];
      for (final value in values) {
        if (unique.isEmpty || (value - unique.last).abs() > 1e-6) {
          unique.add(value);
        }
      }
      if (unique.length < 2) return;
      final origin =
          dimension.lineStart + outward * (tiers.length * rowSpacing);
      final points = [for (final value in unique) origin + u * value];
      tiers.add(
        DimensionTier(
          tierIndex: tier,
          points: points,
          line: (points.first, points.last),
          segments: [
            for (var i = 1; i < points.length; i++) (points[i - 1], points[i]),
          ],
        ),
      );
    }

    if (dimension.style != ArchitectDimensionStyle.exterior) {
      row(1, dimension.witnessPoints.map(along));
      return tiers;
    }

    final references = [
      if (!dimension.isChain)
        for (final point in [dimension.startPoint, dimension.endPoint])
          _wallReference(point, u, storey?.walls ?? const []),
      for (final anchor in dimension.anchors)
        if (anchor.feature != 'opening')
          _wallReference(anchor.point, u, storey?.walls ?? const []),
    ];
    if (references.length < 2) {
      references.addAll([
        (core: dimension.startPoint, finish: dimension.startPoint),
        (core: dimension.endPoint, finish: dimension.endPoint),
      ]);
    }
    final corePositions = references.map((r) => along(r.core)).toList()..sort();
    final low = corePositions.first, high = corePositions.last;
    final finishLow = references
        .where((r) => (along(r.core) - low).abs() < 1e-6)
        .map((r) => math.min(low, along(r.finish)))
        .reduce(math.min);
    final finishHigh = references
        .where((r) => (along(r.core) - high).abs() < 1e-6)
        .map((r) => math.max(high, along(r.finish)))
        .reduce(math.max);
    bool inSpan(double t) => t >= low - 1e-6 && t <= high + 1e-6;
    final structural = List<double>.of(corePositions);
    final openings = [
      for (final a in dimension.anchors)
        if (a.feature == 'opening') along(a.point),
    ];

    // Only parallel walls behind the placed line can belong to this facade.
    // At each opening, the nearest wall masks openings on walls behind it.
    final candidates = <ArchitectWall>[
      for (final wall in storey?.walls ?? const <ArchitectWall>[])
        if (!wall.isCurved &&
            ArchitectDimensionChain.dot(wall.unitVector, u).abs() > .9999 &&
            math.max(along(wall.coreCenterStart), along(wall.coreCenterEnd)) >=
                low - 1e-6 &&
            math.min(along(wall.coreCenterStart), along(wall.coreCenterEnd)) <=
                high + 1e-6 &&
            ArchitectDimensionChain.dot(
                  dimension.lineStart - wall.coreCenterStart,
                  outward,
                ) >=
                -1e-6)
          wall,
    ];
    double depth(ArchitectWall wall) =>
        ArchitectDimensionChain.dot(
          dimension.lineStart - wall.coreCenterStart,
          outward,
        ) -
        wall.coreThickness / 2;
    bool visibleAt(ArchitectWall wall, double position) => !candidates.any(
      (other) =>
          other.id != wall.id &&
          depth(other) < depth(wall) - 1e-6 &&
          position >
              math.min(
                    along(other.coreCenterStart),
                    along(other.coreCenterEnd),
                  ) +
                  1e-6 &&
          position <
              math.max(
                    along(other.coreCenterStart),
                    along(other.coreCenterEnd),
                  ) -
                  1e-6,
    );
    for (final wall in candidates) {
      final start = along(wall.coreCenterStart),
          end = along(wall.coreCenterEnd);
      final middle =
          (math.max(low, math.min(start, end)) +
              math.min(high, math.max(start, end))) /
          2;
      if (visibleAt(wall, middle)) {
        // Centerline ends at wall junctions must not add tiny duplicate spans
        // beside the already selected wall faces.
        for (final position in [start, end]) {
          if (inSpan(position) &&
              !structural.any(
                (p) => (p - position).abs() <= wall.coreThickness / 2 + 1e-6,
              )) {
            structural.add(position);
          }
        }
      }
      for (final opening in [
        ...wall.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...wall.windows.map((w) => (w.id, w.offsetRatio, w.width)),
      ]) {
        final center = along(
          wall.centerStart + wall.unitVector * (opening.$2 * wall.length),
        );
        final half = opening.$3 / 2;
        if (!inSpan(center - half) ||
            !inSpan(center + half) ||
            !visibleAt(wall, center)) {
          continue;
        }
        openings.addAll(
          ArchitectDimensionChain.openingAnchors(
            wall,
            opening.$1,
          ).map((a) => along(a.point)),
        );
      }
    }

    if (openings.isNotEmpty) row(1, [low, ...openings, high]);
    row(2, structural);
    if (dimension.showOverall) row(3, [finishLow, low, high, finishHigh]);

    // Grid axes are infinite references; only the perpendicular family in the
    // measured span contributes to the outermost row.
    final axisPositions = <double>[];
    for (final axis in gridAxes) {
      if (axis.length < 1e-6 ||
          ArchitectDimensionChain.dot(axis.direction, u).abs() > 1e-4) {
        continue;
      }
      final position = along(axis.start);
      if (inSpan(position)) axisPositions.add(position);
    }
    row(4, axisPositions);
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
    final midpoint = wall.centerPointAt(.5);
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
