import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../rendering/architect_3d_builder.dart';
import 'architect_elevation_symbols.dart';

/// Vector hidden-surface removal, independent of screen resolution. Coplanar
/// triangles (including separate wall segments/storeys) are united before any
/// outlines are drawn, eliminating tessellation and boolean-cut seams.
class ArchitectBuildingElevation {
  final List<Path> faces;
  final Rect bounds;
  final Map<String, Path> elementPaths;
  final List<({Path lines, Path clip})> operations;
  final List<ArchitectElevationSlope> slopes;
  const ArchitectBuildingElevation(
    this.faces,
    this.bounds, {
    this.elementPaths = const {},
    this.operations = const [],
    this.slopes = const [],
  });

  static ArchitectBuildingElevation build(
    ArchitectProject project,
    ArchitectElevation view,
  ) {
    final sources = <Triangle3D, String>{};
    final mesh = Architect3dBuilder.buildProjectMesh(
      project,
      previewGeometry: false,
      sources: sources,
    );
    return _fromTriangles(
      mesh.triangles,
      view,
      sources: sources,
      project: project,
    );
  }

  static ArchitectBuildingElevation fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
  }) => _fromTriangles(triangles, view, sources: sources);

  static ArchitectBuildingElevation _fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
    ArchitectProject? project,
  }) {
    if (view.length < .01) {
      return const ArchitectBuildingElevation([], Rect.fromLTWH(-1, 0, 2, 3));
    }
    final groups = <String, _ElevationPlane>{};
    final right = view.right, forward = view.viewDirection;
    Vector3 projectVector(Vector3 v) {
      final p = Offset(v.x, v.y) - view.centre;
      return Vector3(
        p.dx * right.dx + p.dy * right.dy,
        v.z,
        p.dx * forward.dx + p.dy * forward.dy,
      );
    }

    for (final triangle in triangles) {
      final a = projectVector(triangle.v0),
          b = projectVector(triangle.v1),
          c = projectVector(triangle.v2);
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
      final id = sources[triangle];
      if (id != null) {
        final group = groups[key]!;
        group.sources[id] = group.sources.containsKey(id)
            ? Path.combine(PathOperation.union, group.sources[id]!, path)
            : path;
      }
    }
    final faces = <Path>[];
    Rect? bounds;
    final elementPaths = <String, Path>{};
    Path visiblePart(_ElevationPlane face, {String? ignoreSource}) {
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
        final occluder =
            ignoreSource != null && other.sources.containsKey(ignoreSource)
            ? Path.combine(
                PathOperation.difference,
                other.path,
                other.sources[ignoreSource]!,
              )
            : other.path;
        final nearer = Path.combine(
          PathOperation.intersect,
          occluder,
          Path()..addPolygon([for (final p in mask) Offset(p.x, p.y)], true),
        );
        visible = Path.combine(PathOperation.difference, visible, nearer);
        if (visible.getBounds().isEmpty) break;
      }
      return visible;
    }

    for (final face in groups.values) {
      final visible = visiblePart(face);
      if (visible.getBounds().isEmpty) continue;
      faces.add(visible);
      for (final entry in face.sources.entries) {
        final hit = Path.combine(PathOperation.intersect, visible, entry.value);
        if (hit.getBounds().isEmpty) continue;
        elementPaths[entry.key] = elementPaths.containsKey(entry.key)
            ? Path.combine(PathOperation.union, elementPaths[entry.key]!, hit)
            : hit;
      }
      bounds =
          bounds?.expandToInclude(visible.getBounds()) ?? visible.getBounds();
    }
    final operations = <({Path lines, Path clip})>[];
    if (project != null) {
      for (final operation in ArchitectElevationOperation.build(
        project,
        view,
      )) {
        final a = operation.aperture[0], b = operation.aperture[1];
        if ((b.x - a.x).abs() < 1e-6) continue;
        final u = (b.z - a.z) / (b.x - a.x);
        var polygon = _clip3(operation.aperture, (p) => p.z);
        polygon = _clip3(polygon, (p) => p.x + view.length / 2);
        polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
        if (polygon.length < 3) continue;
        final plane = _ElevationPlane(
          u,
          0,
          a.z - u * a.x,
          Path()..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true),
        );
        final visible = visiblePart(plane, ignoreSource: operation.id);
        if (!visible.getBounds().isEmpty) {
          operations.add((lines: operation.lines, clip: visible));
          // Empty apertures of open doors remain selectable, but a foreground
          // solid still masks them just like the operation indication.
          elementPaths[operation.id] = elementPaths.containsKey(operation.id)
              ? Path.combine(
                  PathOperation.union,
                  elementPaths[operation.id]!,
                  visible,
                )
              : visible;
        }
      }
    }
    final slopes = project == null
        ? <ArchitectElevationSlope>[]
        : ArchitectElevationSlope.build(project, view, elementPaths);
    for (final slope in slopes) {
      final arrowBounds = Rect.fromPoints(slope.start, slope.end).inflate(.25);
      bounds = bounds?.expandToInclude(arrowBounds) ?? arrowBounds;
    }
    return ArchitectBuildingElevation(
      faces,
      bounds ??
          Rect.fromLTWH(-view.length / 2, 0, math.max(.01, view.length), 3),
      elementPaths: elementPaths,
      operations: operations,
      slopes: slopes,
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
  final sources = <String, Path>{};
  _ElevationPlane(this.u, this.v, this.w, this.path);
  double depth(double x, double z) => u * x + v * z + w;
}
