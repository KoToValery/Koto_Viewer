import 'dart:math' as math;
import 'dart:ui';
import 'package:clipper2/clipper2.dart' as clip;
import '../../bim_editing/geometry/bim_polygon_geometry.dart';

/// A walking route through the actual clear landing, including concave turns.
/// Insets also test connectivity through narrow necks away from the entry ports.
class ArchitectStairLandingPath {
  static bool contains(List<Offset> polygon, Offset p) {
    if (BimPolygonGeometry.contains(polygon, p)) return true;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], v = polygon[(i + 1) % polygon.length] - a;
      final t = v.distanceSquared < 1e-18
          ? 0.0
          : (BimPolygonGeometry.dot(p - a, v) / v.distanceSquared).clamp(
              0.0,
              1.0,
            );
      if ((p - a - v * t).distance < 1e-7) return true;
    }
    return false;
  }

  static bool visible(List<Offset> polygon, Offset a, Offset b) {
    if (!contains(polygon, a) || !contains(polygon, b)) return false;
    final u = b - a, ts = <double>[0, 1];
    for (var i = 0; i < polygon.length; i++) {
      final c = polygon[i], v = polygon[(i + 1) % polygon.length] - c;
      final den = BimPolygonGeometry.cross(u, v);
      if (den.abs() < 1e-14) continue;
      final t = BimPolygonGeometry.cross(c - a, v) / den;
      final s = BimPolygonGeometry.cross(c - a, u) / den;
      if (t > 0 && t < 1 && s >= 0 && s <= 1) ts.add(t);
    }
    ts.sort();
    for (var i = 1; i < ts.length; i++) {
      if (!contains(polygon, a + u * ((ts[i] + ts[i - 1]) / 2))) return false;
    }
    return true;
  }

  static List<Offset> route(
    List<Offset> polygon,
    Offset start,
    Offset end, {
    double width = 0,
    Offset incoming = Offset.zero,
    Offset outgoing = Offset.zero,
  }) {
    if (width > 0) {
      final radius = math.max(0.0, width / 2 - 1e-6);
      final ordered = BimPolygonGeometry.signedArea(polygon) < 0
          ? polygon.reversed
          : polygon;
      final inset = clip.Clipper.inflatePathsD(
        paths: [ordered.map((p) => clip.PointD(p.dx, p.dy)).toList()],
        delta: -radius,
        joinType: clip.JoinType.miter,
        endType: clip.EndType.polygon,
        precision: 7,
      );
      final a = start + incoming * radius, b = end - outgoing * radius;
      for (final contour in inset) {
        final p = contour.map((q) => Offset(q.x, q.y)).toList();
        final middle = route(p, a, b);
        if (middle.isNotEmpty) return [start, ...middle, end];
      }
      return [];
    }
    if (polygon.length < 3 ||
        !contains(polygon, start) ||
        !contains(polygon, end))
      return [];
    if (visible(polygon, start, end)) return [start, end];
    final sign = BimPolygonGeometry.signedArea(polygon).sign;
    final nodes = [
      start,
      end,
      for (var i = 0; i < polygon.length; i++)
        if (BimPolygonGeometry.cross(
                  polygon[i] -
                      polygon[(i - 1 + polygon.length) % polygon.length],
                  polygon[(i + 1) % polygon.length] - polygon[i],
                ) *
                sign <
            -1e-12)
          polygon[i],
    ];
    final distances = List.filled(nodes.length, double.infinity),
        previous = List.filled(nodes.length, -1);
    final visited = <int>{};
    distances[0] = 0;
    while (visited.length < nodes.length) {
      int? nearest;
      for (var i = 0; i < nodes.length; i++) {
        if (!visited.contains(i) &&
            distances[i].isFinite &&
            (nearest == null ||
                distances[i] + (nodes[i] - end).distance <
                    distances[nearest] + (nodes[nearest] - end).distance))
          nearest = i;
      }
      if (nearest == null) break;
      if (nearest == 1) {
        final result = <Offset>[];
        for (var i = 1; i >= 0; i = previous[i]) {
          result.add(nodes[i]);
        }
        return result.reversed.toList();
      }
      visited.add(nearest);
      for (var i = 0; i < nodes.length; i++) {
        if (visited.contains(i)) continue;
        final distance =
            distances[nearest] + (nodes[i] - nodes[nearest]).distance;
        if (distance < distances[i] &&
            visible(polygon, nodes[nearest], nodes[i])) {
          distances[i] = distance;
          previous[i] = nearest;
        }
      }
    }
    return [];
  }
}
