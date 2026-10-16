import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../rendering/architect_3d_builder.dart';

/// Vector hidden-surface removal, independent of screen resolution. Coplanar
/// triangles (including separate wall segments/storeys) are united before any
/// outlines are drawn, eliminating tessellation and boolean-cut seams.
class ArchitectBuildingElevation {
  final List<Path> faces;
  final Rect bounds;
  const ArchitectBuildingElevation(this.faces, this.bounds);

  static ArchitectBuildingElevation build(
    ArchitectProject project,
    ArchitectElevation view,
  ) => fromTriangles(
    Architect3dBuilder.buildProjectMesh(
      project,
      previewGeometry: false,
    ).triangles,
    view,
  );

  static ArchitectBuildingElevation fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view,
  ) {
    if (view.length < .01) {
      return const ArchitectBuildingElevation([], Rect.fromLTWH(-1, 0, 2, 3));
    }
    final groups = <String, _ElevationPlane>{};
    final right = view.right, forward = view.viewDirection;
    Vector3 project(Vector3 v) {
      final p = Offset(v.x, v.y) - view.centre;
      return Vector3(
        p.dx * right.dx + p.dy * right.dy,
        v.z,
        p.dx * forward.dx + p.dy * forward.dy,
      );
    }

    for (final triangle in triangles) {
      final a = project(triangle.v0),
          b = project(triangle.v1),
          c = project(triangle.v2);
      final normal = (b - a).cross(c - a);
      // Edge-on faces have no projected area.
      if (normal.z.abs() < 1e-10) continue;
      final u = -normal.x / normal.z, v = -normal.y / normal.z;
      final w = a.z - u * a.x - v * a.y;
      var polygon = _clip3([a, b, c], (p) => p.z);
      polygon = _clip3(polygon, (p) => p.x + view.length / 2);
      polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
      if (polygon.length < 3) continue;
      final path = Path()
        ..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true);
      if (path.getBounds().isEmpty) continue;
      // Keep material boundaries (e.g. a flush window frame) while removing
      // triangle edges and construction seams within one finish.
      final key =
          '${(u * 1e6).round()}:${(v * 1e6).round()}:${(w * 1e6).round()}:${triangle.color?.toARGB32()}';
      final plane = groups[key];
      if (plane == null) {
        groups[key] = _ElevationPlane(u, v, w, path);
      } else {
        plane.path = Path.combine(PathOperation.union, plane.path, path);
      }
    }
    final faces = <Path>[];
    Rect? bounds;
    for (final face in groups.values) {
      var visible = face.path;
      final box = face.path.getBounds();
      for (final other in groups.values) {
        if (identical(face, other)) continue;
        final overlap = box.intersect(other.path.getBounds());
        if (overlap.isEmpty) continue;
        // Keep the portion where the other plane is strictly closer to the
        // marker. This handles sloping/intersecting faces without painter-sort
        // artifacts. Equal-depth surfaces do not hide one another.
        final mask = _clip3([
          Vector3(overlap.left, overlap.top, 0),
          Vector3(overlap.right, overlap.top, 0),
          Vector3(overlap.right, overlap.bottom, 0),
          Vector3(overlap.left, overlap.bottom, 0),
        ], (p) => face.depth(p.x, p.y) - other.depth(p.x, p.y) - 1e-7);
        if (mask.length < 3) continue;
        final nearer = Path.combine(
          PathOperation.intersect,
          other.path,
          Path()..addPolygon([for (final p in mask) Offset(p.x, p.y)], true),
        );
        visible = Path.combine(PathOperation.difference, visible, nearer);
        if (visible.getBounds().isEmpty) break;
      }
      if (visible.getBounds().isEmpty) continue;
      faces.add(visible);
      bounds =
          bounds?.expandToInclude(visible.getBounds()) ?? visible.getBounds();
    }
    return ArchitectBuildingElevation(
      faces,
      bounds ??
          Rect.fromLTWH(-view.length / 2, 0, math.max(.01, view.length), 3),
    );
  }

  /// Sutherland–Hodgman clipping against an affine half-space.
  static List<Vector3> _clip3(
    List<Vector3> input,
    double Function(Vector3) distance,
  ) {
    final output = <Vector3>[];
    if (input.isEmpty) return output;
    var previous = input.last;
    var dp = distance(previous);
    for (final current in input) {
      final dc = distance(current);
      if ((dc >= 0) != (dp >= 0)) {
        output.add(previous + (current - previous) * (dp / (dp - dc)));
      }
      if (dc >= 0) output.add(current);
      previous = current;
      dp = dc;
    }
    return output;
  }
}

class _ElevationPlane {
  final double u, v, w;
  Path path;
  _ElevationPlane(this.u, this.v, this.w, this.path);
  double depth(double x, double z) => u * x + v * z + w;
}
