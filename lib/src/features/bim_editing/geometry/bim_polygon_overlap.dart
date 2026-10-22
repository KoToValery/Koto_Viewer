import 'dart:ui';

import 'bim_polygon_geometry.dart';

/// Exact overlap of simple, possibly concave, straight-edged contours.
///
/// A signed triangle fan represents a polygon even when some fan triangles lie
/// outside a concave boundary. Intersecting the fans and summing signed areas
/// cancels those exterior parts without sampling or approximating the contour.
class BimPolygonOverlap {
  final Rect bounds;
  final double area;
  final List<({List<Offset> points, double sign, Rect bounds})> _fan;

  BimPolygonOverlap(List<Offset> polygon)
    : bounds = _bounds(polygon),
      area = BimPolygonGeometry.signedArea(polygon).abs(),
      _fan = _triangles(polygon);

  static Rect _bounds(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points.skip(1)) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static List<({List<Offset> points, double sign, Rect bounds})> _triangles(
    List<Offset> polygon,
  ) {
    if (polygon.length < 3 ||
        polygon.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      return [];
    }
    final orientation = BimPolygonGeometry.signedArea(polygon).sign;
    if (orientation == 0) return [];
    final result = <({List<Offset> points, double sign, Rect bounds})>[];
    for (var i = 1; i < polygon.length - 1; i++) {
      final cross = BimPolygonGeometry.cross(
        polygon[i] - polygon.first,
        polygon[i + 1] - polygon.first,
      );
      if (cross.abs() <= 1e-12) continue;
      final points = cross > 0
          ? [polygon.first, polygon[i], polygon[i + 1]]
          : [polygon.first, polygon[i + 1], polygon[i]];
      result.add((
        points: points,
        sign: cross.sign * orientation,
        bounds: _bounds(points),
      ));
    }
    return result;
  }

  double intersectionArea(BimPolygonOverlap other) {
    if (!bounds.overlaps(other.bounds) ||
        !area.isFinite ||
        !other.area.isFinite ||
        area <= 1e-12 ||
        other.area <= 1e-12) {
      return 0;
    }
    var sum = 0.0, compensation = 0.0;
    for (final a in _fan) {
      for (final b in other._fan) {
        if (!a.bounds.overlaps(b.bounds)) continue;
        var clipped = a.points;
        for (var edge = 0; edge < 3 && clipped.isNotEmpty; edge++) {
          final start = b.points[edge];
          final direction = b.points[(edge + 1) % 3] - start;
          final output = <Offset>[];
          var previous = clipped.last;
          var previousSide = BimPolygonGeometry.cross(
            direction,
            previous - start,
          );
          for (final point in clipped) {
            final side = BimPolygonGeometry.cross(direction, point - start);
            if ((side >= 0) != (previousSide >= 0)) {
              output.add(
                previous +
                    (point - previous) * (previousSide / (previousSide - side)),
              );
            }
            if (side >= 0) output.add(point);
            previous = point;
            previousSide = side;
          }
          clipped = output;
        }
        final term =
            BimPolygonGeometry.signedArea(clipped).abs() * a.sign * b.sign -
            compensation;
        final next = sum + term;
        compensation = (next - sum) - term;
        sum = next;
      }
    }
    final maximum = area < other.area ? area : other.area;
    return sum.clamp(0.0, maximum);
  }
}
