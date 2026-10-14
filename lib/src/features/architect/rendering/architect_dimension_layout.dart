import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../models/architect_elements.dart';

class ArchitectDimensionLayout {
  static (Offset, Offset)? overallSegment(
    ArchitectDimension dimension,
    double scale,
  ) {
    if (!dimension.showOverall || dimension.dimensionPoints.length < 3) {
      return null;
    }
    final outward = dimension.normal * (dimension.offsetDistance < 0 ? -1 : 1);
    final shift = outward * math.max(.35, 28 / scale);
    return (dimension.lineStart + shift, dimension.lineEnd + shift);
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
