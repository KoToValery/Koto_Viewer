import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'dart:ui';
import 'package:clipper2/clipper2.dart' as clip;
import 'architect_path_solid.dart';

/// Local solid differences for construction components. BSP planes are kept in
/// double precision; cut faces inherit the subject material. Inputs are closed,
/// outward-oriented solids, never a concatenation of overlapping components.
class ArchitectMeshBoolean {
  /// Remove opposite coplanar contact faces from the display mesh. Unlike a
  /// solid difference this keeps each construction component's closed volume
  /// intact for sections. Polygon masks are united once per plane, avoiding
  /// the repeated triangle splitting of the ordinary prism shell pass.
  static List<List<Triangle3D>> exposedSurfaces(List<List<Triangle3D>> solids) {
    final planes = <(int, int, int, int), List<_ContactPlane>>{};
    for (var i = 0; i < solids.length; i++) {
      for (final t in solids[i]) {
        final cross = (t.v1 - t.v0).cross(t.v2 - t.v0);
        if (cross.length < 1e-12) continue;
        final n = cross / cross.length;
        final first = n.x.abs() > 1e-7
            ? n.x
            : n.y.abs() > 1e-7
            ? n.y
            : n.z;
        final canonical = first < 0 ? -n : n, d = canonical.dot(t.v0);
        final key = (
          (canonical.x * 1e4).round(),
          (canonical.y * 1e4).round(),
          (canonical.z * 1e4).round(),
          (d * 1e4).round(),
        );
        final bucket = planes.putIfAbsent(key, () => []);
        var plane = bucket
            .where((p) => p.frame.matches(t, tolerance: 1e-5))
            .firstOrNull;
        if (plane == null) {
          plane = _ContactPlane(canonical, d);
          bucket.add(plane);
        }
        plane.faces
            .putIfAbsent((i, first > 0), () => _FaceMesh(n, n.dot(t.v0)))
            .triangles
            .add(t);
      }
    }
    final result = [for (final _ in solids) <Triangle3D>[]];
    for (final bucket in planes.values) {
      for (final plane in bucket) {
        List<List<clip.PointD>> unite(bool side) {
          final paths = [
            for (final e in plane.faces.entries)
              if (e.key.$2 == side) ...e.value.polygons(),
          ];
          if (paths.isEmpty) return [];
          return (clip.ClipperD(roundingDecimalPrecision: 7)
                    ..addSubjects(paths))
                  .executeClosed(clip.ClipType.union, clip.FillRule.nonZero) ??
              (throw StateError('Construction contact union failed'));
        }

        final front = unite(true), back = unite(false);
        for (final e in plane.faces.entries) {
          final opposite = e.key.$2 ? back : front;
          result[e.key.$1].addAll(
            opposite.isEmpty
                ? e.value.triangles
                : e.value.merge(cutters: opposite),
          );
        }
      }
    }
    return result;
  }

  /// Reunite BSP fragments on the same physical face before slicing or hidden
  /// surface removal. This removes numerical seams and avoids thousands of
  /// skinny, coincident cap triangles without changing the construction shape.
  static List<Triangle3D> simplify(List<Triangle3D> mesh) {
    final groups = <(int, int, int, int, bool), List<_FaceMesh>>{};
    for (final triangle in mesh) {
      final cross = (triangle.v1 - triangle.v0).cross(
        triangle.v2 - triangle.v0,
      );
      if (cross.length < 1e-12) continue;
      final n = cross / cross.length;
      final first = n.x.abs() > 1e-7
          ? n.x
          : n.y.abs() > 1e-7
          ? n.y
          : n.z;
      final canonical = first < 0 ? -n : n, dist = canonical.dot(triangle.v0);
      final key = (
        (canonical.x * 1e6).round(),
        (canonical.y * 1e6).round(),
        (canonical.z * 1e6).round(),
        (dist * 1e6).round(),
        first > 0,
      );
      final bucket = groups.putIfAbsent(key, () => []);
      var group = bucket.where((g) => g.matches(triangle)).firstOrNull;
      if (group == null) {
        group = _FaceMesh(n, n.dot(triangle.v0));
        bucket.add(group);
      }
      group.triangles.add(triangle);
    }
    return [
      for (final bucket in groups.values)
        for (final group in bucket) ...group.merge(),
    ];
  }

  static List<Triangle3D> subtract(
    List<Triangle3D> subject,
    List<Triangle3D> cutter,
  ) {
    if (subject.isEmpty || cutter.isEmpty) return subject;
    BoundingBox3D bounds(List<Triangle3D> mesh) => BoundingBox3D.fromPoints([
      for (final t in mesh) ...[t.v0, t.v1, t.v2],
    ]);
    final sa = bounds(subject), sb = bounds(cutter);
    if (!sa.intersects(sb) ||
        (sa.max.x < sb.max.x ? sa.max.x : sb.max.x) -
                (sa.min.x > sb.min.x ? sa.min.x : sb.min.x) <
            1e-8 ||
        (sa.max.y < sb.max.y ? sa.max.y : sb.max.y) -
                (sa.min.y > sb.min.y ? sa.min.y : sb.min.y) <
            1e-8 ||
        (sa.max.z < sb.max.z ? sa.max.z : sb.max.z) -
                (sa.min.z > sb.min.z ? sa.min.z : sb.min.z) <
            1e-8) {
      return subject;
    }
    List<_Polygon> polygons(List<Triangle3D> mesh) => [
      for (final t in mesh)
        if ((t.v1 - t.v0).cross(t.v2 - t.v0).length > 1e-12)
          _Polygon([t.v0, t.v1, t.v2]),
    ];
    final a = _Node(polygons(subject)), b = _Node(polygons(cutter));
    a.invert();
    a.clipTo(b);
    b.clipTo(a);
    b.invert();
    b.clipTo(a);
    b.invert();
    a.build(b.all());
    a.invert();
    return [
      for (final polygon in a.all())
        for (var i = 1; i + 1 < polygon.vertices.length; i++)
          if ((polygon.vertices[i] - polygon.vertices.first)
                  .cross(polygon.vertices[i + 1] - polygon.vertices.first)
                  .length >
              1e-12)
            Triangle3D(
              v0: polygon.vertices.first,
              v1: polygon.vertices[i],
              v2: polygon.vertices[i + 1],
              color: subject.first.color,
            ),
    ];
  }
}

class _ContactPlane {
  final _FaceMesh frame;
  final faces = <(int, bool), _FaceMesh>{};
  _ContactPlane(Vector3 n, double d) : frame = _FaceMesh(n, d);
}

class _FaceMesh {
  final Vector3 normal;
  final double distance;
  final triangles = <Triangle3D>[];
  late final int axis =
      normal.x.abs() >= normal.y.abs() && normal.x.abs() >= normal.z.abs()
      ? 0
      : normal.y.abs() >= normal.z.abs()
      ? 1
      : 2;
  _FaceMesh(this.normal, this.distance);
  bool matches(Triangle3D t, {double tolerance = 1e-7}) => [
    t.v0,
    t.v1,
    t.v2,
  ].every((v) => (normal.dot(v) - distance).abs() < tolerance);
  Offset project(Vector3 v) => switch (axis) {
    0 => Offset(v.y, v.z),
    1 => Offset(v.x, v.z),
    _ => Offset(v.x, v.y),
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
  List<List<clip.PointD>> polygons() {
    final polygons = <List<clip.PointD>>[];
    for (final t in triangles) {
      final pts = [project(t.v0), project(t.v1), project(t.v2)];
      final a = pts[1] - pts[0], b = pts[2] - pts[0];
      polygons.add([
        for (final p in a.dx * b.dy - a.dy * b.dx > 0 ? pts : pts.reversed)
          clip.PointD(p.dx, p.dy),
      ]);
    }
    return polygons;
  }

  List<Triangle3D> merge({List<List<clip.PointD>> cutters = const []}) {
    if (triangles.length < 8 && cutters.isEmpty) return triangles;
    final engine = clip.ClipperD(roundingDecimalPrecision: 7)
      ..preserveCollinear = false
      ..addSubjects(polygons());
    if (cutters.isNotEmpty) engine.addClips(cutters);
    final contours = engine.executeClosed(
      cutters.isEmpty ? clip.ClipType.union : clip.ClipType.difference,
      clip.FillRule.nonZero,
    );
    if (contours == null) throw StateError('Construction face union failed');
    // Triangulate numerical contours directly: no float32 Path round-trip and
    // no unused side/bottom faces. This operation can run in a worker isolate.
    final origin = project(triangles.first.v0);
    final loops = [
      for (final loop in contours)
        [for (final p in loop) Offset(p.x, p.y) - origin],
    ];
    final color = triangles.first.color;
    final result = <Triangle3D>[];
    for (final (p, q, r) in ArchitectPathSolid.triangulateContours(loops)) {
      final a = lift(p + origin), b = lift(q + origin), c = lift(r + origin);
      final flip = (b - a).cross(c - a).dot(normal) < 0;
      result.add(
        Triangle3D(v0: a, v1: flip ? c : b, v2: flip ? b : c, color: color),
      );
    }
    return result;
  }
}

class _Polygon {
  List<Vector3> vertices;
  late Vector3 normal;
  late double distance;
  _Polygon(this.vertices) {
    final cross = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]);
    // Vector3.normalized() intentionally zeros vectors shorter than 1e-9.
    // Boolean fragments can have a smaller area and still define a real plane.
    normal = cross / cross.length;
    distance = normal.dot(vertices[0]);
  }
  void flip() {
    vertices = vertices.reversed.toList();
    normal = -normal;
    distance = -distance;
  }
}

class _Node {
  static const epsilon = 1e-7;
  Vector3? normal;
  double distance = 0;
  List<_Polygon> polygons = [];
  _Node? front, back;
  _Node([List<_Polygon> input = const []]) {
    build(input);
  }
  void split(
    _Polygon polygon,
    List<_Polygon> coplanarFront,
    List<_Polygon> coplanarBack,
    List<_Polygon> inFront,
    List<_Polygon> behind,
  ) {
    var type = 0;
    final types = <int>[];
    for (final v in polygon.vertices) {
      final t = normal!.dot(v) - distance;
      final side = t < -epsilon
          ? 2
          : t > epsilon
          ? 1
          : 0;
      type |= side;
      types.add(side);
    }
    if (type == 0) {
      (normal!.dot(polygon.normal) > 0 ? coplanarFront : coplanarBack).add(
        polygon,
      );
    } else if (type == 1) {
      inFront.add(polygon);
    } else if (type == 2) {
      behind.add(polygon);
    } else {
      final f = <Vector3>[], b = <Vector3>[];
      for (var i = 0; i < polygon.vertices.length; i++) {
        final j = (i + 1) % polygon.vertices.length,
            ti = types[i],
            tj = types[j];
        final vi = polygon.vertices[i], vj = polygon.vertices[j];
        if (ti != 2) f.add(vi);
        if (ti != 1) b.add(vi);
        if ((ti | tj) == 3) {
          final t = (distance - normal!.dot(vi)) / normal!.dot(vj - vi);
          final v = vi + (vj - vi) * t;
          f.add(v);
          b.add(v);
        }
      }
      void append(List<Vector3> points, List<_Polygon> result) {
        final clean = <Vector3>[];
        for (final p in points) {
          if (clean.isEmpty || (clean.last - p).length > 1e-9) clean.add(p);
        }
        if (clean.length > 2 && (clean.first - clean.last).length < 1e-9) {
          clean.removeLast();
        }
        if (clean.length < 3) return;
        // Splits can leave collinear leading vertices; discard those before
        // deriving the polygon plane, otherwise a zero normal corrupts the BSP.
        while (clean.length > 2 &&
            (clean[1] - clean[0]).cross(clean[2] - clean[0]).length < 1e-12) {
          clean.removeAt(1);
        }
        if (clean.length >= 3) result.add(_Polygon(clean));
      }

      append(f, inFront);
      append(b, behind);
    }
  }

  void invert() {
    for (final p in polygons) {
      p.flip();
    }
    if (normal != null) normal = -normal!;
    distance = -distance;
    front?.invert();
    back?.invert();
    final swap = front;
    front = back;
    back = swap;
  }

  List<_Polygon> clip(List<_Polygon> input) {
    if (normal == null) return [...input];
    var f = <_Polygon>[], b = <_Polygon>[];
    for (final p in input) {
      split(p, f, b, f, b);
    }
    if (front != null) f = front!.clip(f);
    b = back != null ? back!.clip(b) : [];
    return [...f, ...b];
  }

  void clipTo(_Node other) {
    polygons = other.clip(polygons);
    front?.clipTo(other);
    back?.clipTo(other);
  }

  List<_Polygon> all() => [...polygons, ...?front?.all(), ...?back?.all()];
  void build(List<_Polygon> input) {
    if (input.isEmpty) return;
    if (normal == null) {
      normal = input.first.normal;
      distance = input.first.distance;
    }
    final f = <_Polygon>[], b = <_Polygon>[];
    for (final p in input) {
      split(p, polygons, polygons, f, b);
    }
    if (f.isNotEmpty) {
      (front ??= _Node()).build(f);
    }
    if (b.isNotEmpty) {
      (back ??= _Node()).build(b);
    }
  }
}
