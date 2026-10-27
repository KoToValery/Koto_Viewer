import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../rendering/architect_stair_mesh.dart';
import '../models/architect_elevation.dart';
import 'architect_building_elevation.dart';
import 'architect_stair_geometry.dart';

class ArchitectStairSection {
  final Offset origin, axis;
  final Map<StairSolidMaterial, Path> regions;
  final Rect bounds;

  /// Visible faces behind the plane; drawn as thin, unhatched outlines.
  final List<Path> projection;
  const ArchitectStairSection(
    this.origin,
    this.axis,
    this.regions,
    this.bounds, {
    this.projection = const [],
  });
  bool get isEmpty => regions.values.every((p) => p.getBounds().isEmpty);

  /// Intersect closed material solids with a vertical plane, not a flattened
  /// walking-line diagram. This also handles transverse/oblique/spiral cuts.
  static ArchitectStairSection build(
    List<StairSolid> solids,
    Offset origin,
    Offset direction, {
    double endpointTolerance = 1e-6,
    bool includeProjection = false,
  }) {
    if (!endpointTolerance.isFinite ||
        endpointTolerance <= 0 ||
        !direction.dx.isFinite ||
        !direction.dy.isFinite ||
        direction.distance < 1e-9) {
      throw ArgumentError('Section direction is missing');
    }
    final axis = direction / direction.distance;
    final normal = Offset(-axis.dy, axis.dx),
        regions = <StairSolidMaterial, Path>{};
    double distance(Vector3 p) =>
        ArchitectStairGeometry.dot(Offset(p.x, p.y) - origin, normal);
    Offset project(Vector3 p) => Offset(
      ArchitectStairGeometry.dot(Offset(p.x, p.y) - origin, axis),
      p.z,
    );
    // Rounding alone splits coincident endpoints on opposite sides of a bin
    // boundary. Weld neighbouring bins by distance before stitching contours.
    final vertices = <(int, int), List<({Offset point, String id})>>{};
    var vertexCount = 0;
    String key(Offset p) {
      final x = (p.dx / endpointTolerance).floor();
      final y = (p.dy / endpointTolerance).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final vertex
              in vertices[(x + dx, y + dy)] ??
                  <({Offset point, String id})>[]) {
            if ((p - vertex.point).distanceSquared <=
                endpointTolerance * endpointTolerance) {
              return vertex.id;
            }
          }
        }
      }
      final id = '${vertexCount++}';
      (vertices[(x, y)] ??= []).add((point: p, id: id));
      return id;
    }

    void add(StairSolidMaterial material, List<Offset> polygon) {
      if (polygon.length < 3) return;
      final path = Path()..addPolygon(polygon, true);
      regions[material] = Path.combine(
        PathOperation.union,
        regions[material] ?? Path(),
        path,
      );
    }

    for (final solid in solids) {
      final segments = <(Offset, Offset)>[], seen = <String>{};
      for (final face in solid.triangles) {
        final vertices = [face.v0, face.v1, face.v2];
        final distances = vertices.map(distance).toList();
        if (distances.every((v) => v.abs() < 1e-8)) {
          add(solid.material, vertices.map(project).toList());
          continue;
        }
        final points = <Vector3>[];
        void point(Vector3 p) {
          if (points.every((q) => p.distanceTo(q) > 1e-7)) points.add(p);
        }

        for (var i = 0; i < 3; i++) {
          final j = (i + 1) % 3, a = distances[i], b = distances[j];
          if (a.abs() < 1e-8) point(vertices[i]);
          if (a * b < -1e-16) {
            point(vertices[i] + (vertices[j] - vertices[i]) * (a / (a - b)));
          }
        }
        if (points.length != 2) continue;
        final a = project(points[0]), b = project(points[1]);
        if ((a - b).distance < 1e-7) continue;
        final names = [key(a), key(b)]..sort();
        if (seen.add(names.join(':'))) segments.add((a, b));
      }
      final links = <String, List<int>>{};
      for (var i = 0; i < segments.length; i++) {
        for (final p in [segments[i].$1, segments[i].$2]) {
          (links[key(p)] ??= []).add(i);
        }
      }
      final used = <int>{};
      for (var seed = 0; seed < segments.length; seed++) {
        if (used.contains(seed)) continue;
        used.add(seed);
        final points = <Offset>[segments[seed].$1, segments[seed].$2];
        while (key(points.first) != key(points.last)) {
          final next = (links[key(points.last)] ?? [])
              .where((i) => !used.contains(i))
              .firstOrNull;
          if (next == null) break;
          used.add(next);
          final segment = segments[next];
          points.add(
            key(segment.$1) == key(points.last) ? segment.$2 : segment.$1,
          );
        }
        if (key(points.first) == key(points.last)) add(solid.material, points);
      }
    }
    // Finish and treads own the visible face. A railing or support meeting
    // another material must not leave overlapping hatches in the cut.
    var occupied = Path();
    for (final material in [
      StairSolidMaterial.finish,
      StairSolidMaterial.timber,
      StairSolidMaterial.metal,
      StairSolidMaterial.concrete,
    ]) {
      final region = regions[material];
      if (region == null) continue;
      regions[material] = Path.combine(
        PathOperation.difference,
        region,
        occupied,
      );
      occupied = Path.combine(PathOperation.union, occupied, region);
    }
    Rect? bounds;
    for (final path in regions.values) {
      if (path.getBounds().isEmpty) continue;
      bounds = bounds == null
          ? path.getBounds()
          : bounds.expandToInclude(path.getBounds());
    }
    final projection = <Path>[];
    if (includeProjection && bounds != null) {
      var left = bounds.left, right = bounds.right;
      final triangles = [for (final solid in solids) ...solid.triangles];
      for (final t in triangles) {
        for (final p in [t.v0, t.v1, t.v2]) {
          final x = project(p).dx;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
      final middle = (left + right) / 2;
      // Reuse the building elevation's hidden-surface removal. Projecting all
      // triangle edges would expose tessellation and the far side's guard.
      final visible = ArchitectBuildingElevation.fromTriangles(
        triangles,
        ArchitectElevation(
          id: 'stair-section',
          start: origin + axis * (left - .01),
          end: origin + axis * (right + .01),
        ),
      );
      for (final face in visible.faces) {
        final path = face.shift(Offset(middle, 0));
        projection.add(path);
        bounds = bounds!.expandToInclude(path.getBounds());
      }
    }
    return ArchitectStairSection(
      origin,
      axis,
      regions,
      bounds ?? Rect.zero,
      projection: projection,
    );
  }
}
