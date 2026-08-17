import 'dart:math' as math;

/// 3D Vector representation with mathematical operations.
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  static const Vector3 zero = Vector3(0, 0, 0);

  Vector3 operator +(Vector3 v) => Vector3(x + v.x, y + v.y, z + v.z);
  Vector3 operator -(Vector3 v) => Vector3(x - v.x, y - v.y, z - v.z);
  Vector3 operator *(double s) => Vector3(x * s, y * s, z * s);
  Vector3 operator /(double s) => Vector3(x / s, y / s, z / s);
  Vector3 operator -() => Vector3(-x, -y, -z);

  double dot(Vector3 v) => x * v.x + y * v.y + z * v.z;

  Vector3 cross(Vector3 v) => Vector3(
        y * v.z - z * v.y,
        z * v.x - x * v.z,
        x * v.y - y * v.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3 normalized() {
    final len = length;
    if (len < 1e-9) return zero;
    return Vector3(x / len, y / len, z / len);
  }

  double distanceTo(Vector3 v) => (this - v).length;

  @override
  String toString() => 'Vector3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// 3D Axis-Aligned Bounding Box.
class BoundingBox3D {
  final Vector3 min;
  final Vector3 max;

  const BoundingBox3D({required this.min, required this.max});

  double get sizeX => max.x - min.x;
  double get sizeY => max.y - min.y;
  double get sizeZ => max.z - min.z;

  Vector3 get center => Vector3(
        (min.x + max.x) / 2.0,
        (min.y + max.y) / 2.0,
        (min.z + max.z) / 2.0,
      );

  double get maxDimension => math.max(sizeX, math.max(sizeY, sizeZ));
  double get diagonal => math.sqrt(sizeX * sizeX + sizeY * sizeY + sizeZ * sizeZ);

  static BoundingBox3D fromPoints(List<Vector3> points) {
    if (points.isEmpty) {
      return const BoundingBox3D(min: Vector3.zero, max: Vector3.zero);
    }
    double minX = points[0].x, maxX = points[0].x;
    double minY = points[0].y, maxY = points[0].y;
    double minZ = points[0].z, maxZ = points[0].z;

    for (int i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }

    return BoundingBox3D(
      min: Vector3(minX, minY, minZ),
      max: Vector3(maxX, maxY, maxZ),
    );
  }
}

/// Single 3D Triangle face in a 3D mesh.
class Triangle3D {
  final Vector3 v0;
  final Vector3 v1;
  final Vector3 v2;
  final Vector3 normal;

  Triangle3D({
    required this.v0,
    required this.v1,
    required this.v2,
    Vector3? normal,
  }) : normal = normal ?? _calculateNormal(v0, v1, v2);

  static Vector3 _calculateNormal(Vector3 a, Vector3 b, Vector3 c) {
    final edge1 = b - a;
    final edge2 = c - a;
    return edge1.cross(edge2).normalized();
  }

  Vector3 get centroid => (v0 + v1 + v2) / 3.0;

  double get area {
    final edge1 = v1 - v0;
    final edge2 = v2 - v0;
    return edge1.cross(edge2).length * 0.5;
  }

  /// Signed volume of the tetrahedron formed by origin and triangle
  double get signedVolume => v0.dot(v1.cross(v2)) / 6.0;
}

/// Representation of a complete 3D Mesh.
class Mesh3D {
  final String name;
  final List<Triangle3D> triangles;
  final BoundingBox3D bounds;
  final double surfaceArea;
  final double volume;

  Mesh3D({
    required this.name,
    required this.triangles,
    BoundingBox3D? bounds,
    double? surfaceArea,
    double? volume,
  })  : bounds = bounds ?? _computeBounds(triangles),
        surfaceArea = surfaceArea ?? _computeSurfaceArea(triangles),
        volume = volume ?? _computeVolume(triangles);

  static BoundingBox3D _computeBounds(List<Triangle3D> tris) {
    if (tris.isEmpty) {
      return const BoundingBox3D(min: Vector3.zero, max: Vector3.zero);
    }
    double minX = tris[0].v0.x, maxX = tris[0].v0.x;
    double minY = tris[0].v0.y, maxY = tris[0].v0.y;
    double minZ = tris[0].v0.z, maxZ = tris[0].v0.z;

    for (final t in tris) {
      for (final v in [t.v0, t.v1, t.v2]) {
        if (v.x < minX) minX = v.x;
        if (v.x > maxX) maxX = v.x;
        if (v.y < minY) minY = v.y;
        if (v.y > maxY) maxY = v.y;
        if (v.z < minZ) minZ = v.z;
        if (v.z > maxZ) maxZ = v.z;
      }
    }

    return BoundingBox3D(
      min: Vector3(minX, minY, minZ),
      max: Vector3(maxX, maxY, maxZ),
    );
  }

  static double _computeSurfaceArea(List<Triangle3D> tris) {
    double total = 0;
    for (final t in tris) {
      total += t.area;
    }
    return total;
  }

  static double _computeVolume(List<Triangle3D> tris) {
    double total = 0;
    for (final t in tris) {
      total += t.signedVolume;
    }
    return total.abs();
  }

  int get triangleCount => triangles.length;
  int get vertexCount => triangles.length * 3;
}
