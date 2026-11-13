import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../models/architect_project.dart';

/// Non-destructive visibility queries in architectural model metres.
class ArchitectUnderlayClip {
  static List<Offset>? of(ArchitectProject project) {
    final config = project.cadUnderlayForStorey(project.activeStoreyId);
    return config != null && config.hasActiveMask ? config.maskPolygon : null;
  }

  static bool contains(List<Offset>? polygon, Offset point) {
    if (polygon == null || polygon.length < 3) return true;
    for (var i = 0; i < polygon.length; i++) {
      if ((BimLineGeometry.closest(
                    point,
                    polygon[i],
                    polygon[(i + 1) % polygon.length],
                  ) -
                  point)
              .distanceSquared <=
          1e-14) {
        return true;
      }
    }
    return BimPolygonGeometry.contains(polygon, point);
  }

  /// Split at the mask boundary, including concave masks and boundary segments.
  static Iterable<(Offset, Offset)> segments(
    Iterable<(Offset, Offset)> edges,
    List<Offset>? polygon,
  ) sync* {
    if (polygon == null || polygon.length < 3) {
      yield* edges;
      return;
    }
    for (final edge in edges) {
      final a = edge.$1, u = edge.$2 - a;
      if (u.distanceSquared < 1e-18) continue;
      final cuts = <double>[0, 1];
      for (var i = 0; i < polygon.length; i++) {
        final b = polygon[i], v = polygon[(i + 1) % polygon.length] - b;
        final den = BimPolygonGeometry.cross(u, v);
        if (den.abs() < 1e-12) continue;
        final t = BimPolygonGeometry.cross(b - a, v) / den;
        final s = BimPolygonGeometry.cross(b - a, u) / den;
        if (t > 0 && t < 1 && s >= -1e-9 && s <= 1 + 1e-9) cuts.add(t);
      }
      cuts.sort();
      for (var i = 1; i < cuts.length; i++) {
        if (cuts[i] - cuts[i - 1] < 1e-10) continue;
        if (contains(polygon, a + u * ((cuts[i - 1] + cuts[i]) / 2))) {
          yield (a + u * cuts[i - 1], a + u * cuts[i]);
        }
      }
    }
  }
}
