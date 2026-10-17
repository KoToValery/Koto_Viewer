import 'dart:math' as math;
import '../models/mesh_3d.dart';

typedef _PointKey = (int, int, int);
typedef _EdgeKey = (_PointKey, _PointKey);

/// Boundary, material and crease edges. Coplanar tessellation stays invisible.
/// Masks use bits 1/2/4 for v0-v1/v1-v2/v2-v0, respectively.
class Cad3DFeatureEdges {
  static final _cache = Expando<Map<Triangle3D, int>>();

  static Map<Triangle3D, int> masks(
    List<Triangle3D> triangles,
    double dimension,
  ) {
    final cached = _cache[triangles];
    if (cached != null) return cached;
    final epsilon = math.max(dimension, 1e-4) * 1e-8;
    _PointKey point(Vector3 p) => (
      (p.x / epsilon).round(),
      (p.y / epsilon).round(),
      (p.z / epsilon).round(),
    );
    int compare(_PointKey a, _PointKey b) {
      var result = a.$1.compareTo(b.$1);
      if (result == 0) result = a.$2.compareTo(b.$2);
      if (result == 0) result = a.$3.compareTo(b.$3);
      return result;
    }

    final edges = <_EdgeKey, List<(Triangle3D, int)>>{};
    final normals = <Triangle3D, Vector3>{};
    final masks = <Triangle3D, int>{};
    for (final triangle in triangles) {
      masks[triangle] = 0;
      normals[triangle] = (triangle.v1 - triangle.v0)
          .cross(triangle.v2 - triangle.v0)
          .normalized();
      final points = [
        point(triangle.v0),
        point(triangle.v1),
        point(triangle.v2),
      ];
      for (var i = 0; i < 3; i++) {
        final a = points[i], b = points[(i + 1) % 3];
        if (a == b) continue;
        final key = compare(a, b) < 0 ? (a, b) : (b, a);
        (edges[key] ??= []).add((triangle, 1 << i));
      }
    }
    const creaseCos = .9396926208; // 20 degrees
    for (final uses in edges.values) {
      final visible =
          uses.length != 2 ||
          uses[0].$1.color != uses[1].$1.color ||
          normals[uses[0].$1]!.dot(normals[uses[1].$1]!).abs() < creaseCos;
      if (!visible) continue;
      for (final (triangle, bit) in uses) {
        masks[triangle] = masks[triangle]! | bit;
      }
    }
    _cache[triangles] = masks;
    return masks;
  }
}
