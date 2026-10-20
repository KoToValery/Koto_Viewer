import 'dart:ui';

import '../../dxf_3d_viewer/models/mesh_3d.dart';

/// Removes the shared, oppositely facing interfaces of touching wall solids.
/// Material volumes remain available separately for sections and quantities.
class ArchitectSolidShell {
  static List<List<Triangle3D>> build(List<List<Triangle3D>> solids) {
    final result = [for (final _ in solids) <Triangle3D>[]];
    final planes = <(int, int, int, int), List<_PlaneFaces>>{};
    for (var i = 0; i < solids.length; i++) {
      for (final triangle in solids[i]) {
        if (triangle.area < 1e-12) continue;
        final n = triangle.normal;
        final first = n.x.abs() > 1e-7
            ? n.x
            : n.y.abs() > 1e-7
            ? n.y
            : n.z;
        final normal = first < 0 ? n * -1 : n;
        final distance = normal.dot(triangle.v0);
        final key = (
          (normal.x * 1e4).round(),
          (normal.y * 1e4).round(),
          (normal.z * 1e4).round(),
          (distance * 1e4).round(),
        );
        final bucket = planes.putIfAbsent(key, () => []);
        var plane = bucket.where((p) => p.matches(triangle)).firstOrNull;
        if (plane == null) {
          plane = _PlaneFaces(normal, distance);
          bucket.add(plane);
        }
        plane.add(i, triangle, first > 0);
      }
    }
    for (final bucket in planes.values) {
      for (final plane in bucket) {
        plane.exposed(result);
      }
    }
    return result;
  }
}

class _PlaneFaces {
  final Vector3 normal;
  final double distance;
  final int axis;
  final faces = <(int, Triangle3D, bool, List<Offset>, Rect)>[];

  _PlaneFaces(this.normal, this.distance)
    : axis =
          normal.x.abs() >= normal.y.abs() && normal.x.abs() >= normal.z.abs()
          ? 0
          : normal.y.abs() >= normal.z.abs()
          ? 1
          : 2;

  bool matches(Triangle3D t) =>
      [t.v0, t.v1, t.v2].every((p) => (normal.dot(p) - distance).abs() < 1e-5);

  Offset project(Vector3 p) => switch (axis) {
    0 => Offset(p.y, p.z),
    1 => Offset(p.x, p.z),
    _ => Offset(p.x, p.y),
  };

  Vector3 lift(Offset p) => switch (axis) {
    0 => Vector3(
      (distance - normal.y * p.dx - normal.z * p.dy) / normal.x,
      p.dx,
      p.dy,
    ),
    1 => Vector3(
      p.dx,
      (distance - normal.x * p.dx - normal.z * p.dy) / normal.y,
      p.dy,
    ),
    _ => Vector3(
      p.dx,
      p.dy,
      (distance - normal.x * p.dx - normal.y * p.dy) / normal.z,
    ),
  };

  void add(int solid, Triangle3D triangle, bool front) {
    final points = [
      project(triangle.v0),
      project(triangle.v1),
      project(triangle.v2),
    ];
    final cross =
        (points[1] - points[0]).dx * (points[2] - points[0]).dy -
        (points[1] - points[0]).dy * (points[2] - points[0]).dx;
    final polygon = cross < 0 ? points.reversed.toList() : points;
    faces.add((solid, triangle, front, polygon, _bounds(polygon)));
  }

  static Rect _bounds(List<Offset> polygon) {
    var bounds = Rect.fromPoints(polygon.first, polygon.first);
    for (final point in polygon.skip(1)) {
      bounds = bounds.expandToInclude(Rect.fromPoints(point, point));
    }
    return bounds;
  }

  /// Splits convex polygons in double precision. Subtracting a mask assembled
  /// from float32 triangles can invert nearly coincident diagonal boundaries.
  static List<Offset> _halfPlane(
    List<Offset> polygon,
    Offset a,
    Offset b,
    bool inside,
  ) {
    final edge = b - a;
    final length = edge.distance;
    double side(Offset p) {
      final distance = ((p - a).dx * edge.dy - (p - a).dy * edge.dx) / length;
      return distance.abs() < 1e-6 ? 0 : distance;
    }

    final result = <Offset>[];
    for (var i = 0; i < polygon.length; i++) {
      final p = polygon[i], q = polygon[(i + 1) % polygon.length];
      final dp = side(p), dq = side(q);
      if (inside ? dp <= 0 : dp >= 0) result.add(p);
      if ((dp < 0 && dq > 0) || (dp > 0 && dq < 0)) {
        result.add(p + (q - p) * (dp / (dp - dq)));
      }
    }
    return result;
  }

  static Iterable<List<Offset>> _subtract(
    List<Offset> polygon,
    List<Offset> cutter,
  ) sync* {
    var remainder = polygon;
    for (var i = 0; i < cutter.length; i++) {
      final a = cutter[i], b = cutter[(i + 1) % cutter.length];
      final outside = _halfPlane(remainder, a, b, false);
      if (outside.length >= 3) yield outside;
      remainder = _halfPlane(remainder, a, b, true);
      if (remainder.length < 3) return;
    }
  }

  void exposed(List<List<Triangle3D>> result) {
    final sides = [
      faces.where((f) => !f.$3).toList(),
      faces.where((f) => f.$3).toList(),
    ];
    for (final (solid, triangle, front, polygon, bounds) in faces) {
      var fragments = [polygon];
      for (final other in sides[front ? 0 : 1]) {
        if (!bounds.overlaps(other.$5)) continue;
        fragments = [
          for (final fragment in fragments)
            if (_bounds(fragment).overlaps(other.$5))
              ..._subtract(fragment, other.$4)
            else
              fragment,
        ];
        if (fragments.isEmpty) break;
      }
      for (final fragment in fragments) {
        final p = lift(fragment.first);
        for (var i = 1; i + 1 < fragment.length; i++) {
          final q = lift(fragment[i]), r = lift(fragment[i + 1]);
          final cross = (q - p).cross(r - p);
          if (cross.lengthSquared < 1e-20) continue;
          final flip = cross.dot(triangle.normal) < 0;
          result[solid].add(
            Triangle3D(
              v0: p,
              v1: flip ? r : q,
              v2: flip ? q : r,
              color: triangle.color,
              isDoubleSided: triangle.isDoubleSided,
            ),
          );
        }
      }
    }
  }
}
