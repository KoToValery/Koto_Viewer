import 'dart:ui';
import 'bim_polygon_geometry.dart';

/// Exact parallel edges with mitered corners, preserving vertex/edge indices.
/// A collapsed, reversed or intersecting result is rejected, never repaired by
/// silently returning the source or deleting parts of the contour.
class BimOffsetGeometry {
  static List<Offset> ring(List<Offset> points, double outward) {
    if (!outward.isFinite || !BimPolygonGeometry.valid(points)) {
      throw ArgumentError('Invalid offset contour');
    }
    final n = points.length;
    final shifted = <Offset>[];
    for (var i = 0; i < n; i++) {
      final previous = (i + n - 1) % n;
      final u = points[i] - points[previous];
      final v = points[(i + 1) % n] - points[i];
      final a =
          points[i] + BimPolygonGeometry.normal(points, previous) * outward;
      final b = points[i] + BimPolygonGeometry.normal(points, i) * outward;
      final den = BimPolygonGeometry.cross(u, v);
      final Offset p;
      if (den.abs() <= 1e-10 * u.distance * v.distance) {
        if (BimPolygonGeometry.dot(u, v) <= 0) {
          throw ArgumentError('Backtracking offset contour');
        }
        p = (a + b) / 2;
      } else {
        p = a + u * (BimPolygonGeometry.cross(b - a, v) / den);
      }
      if ((p - points[i]).distance > outward.abs() * 50 + 1e-7) {
        throw ArgumentError('Offset corner is too acute');
      }
      shifted.add(p);
    }
    for (var i = 0; i < n; i++) {
      if (BimPolygonGeometry.dot(
            shifted[(i + 1) % n] - shifted[i],
            points[(i + 1) % n] - points[i],
          ) <=
          1e-9) {
        throw ArgumentError('Offset edge collapsed');
      }
    }
    if (!BimPolygonGeometry.valid(shifted) ||
        BimPolygonGeometry.signedArea(shifted) *
                BimPolygonGeometry.signedArea(points) <=
            0) {
      throw ArgumentError('Offset contour intersects or collapses');
    }
    return shifted;
  }
}
