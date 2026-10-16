import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../rendering/architect_stair_mesh.dart';
import 'architect_stair_geometry.dart';

class ArchitectStairSection {
  final Offset origin, axis;
  final Map<StairSolidMaterial, Path> regions;
  final Rect bounds;
  const ArchitectStairSection(this.origin, this.axis, this.regions, this.bounds);
  bool get isEmpty => regions.values.every((p) => p.getBounds().isEmpty);

  /// Intersect closed material solids with a vertical plane, not a flattened
  /// walking-line diagram. This also handles transverse/oblique/spiral cuts.
  static ArchitectStairSection build(List<StairSolid> solids, Offset origin, Offset direction) {
    final axis = direction / direction.distance;
    final normal = Offset(-axis.dy, axis.dx), regions = <StairSolidMaterial, Path>{};
    double distance(Vector3 p) => ArchitectStairGeometry.dot(Offset(p.x, p.y) - origin, normal);
    Offset project(Vector3 p) => Offset(ArchitectStairGeometry.dot(Offset(p.x, p.y) - origin, axis), p.z);
    String key(Offset p) => '${(p.dx * 1e6).round()},${(p.dy * 1e6).round()}';
    void add(StairSolidMaterial material, List<Offset> polygon) {
      if (polygon.length < 3) return;
      final path = Path()..addPolygon(polygon, true);
      regions[material] = Path.combine(PathOperation.union, regions[material] ?? Path(), path);
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
          if (a * b < -1e-16) point(vertices[i] + (vertices[j] - vertices[i]) * (a / (a - b)));
        }
        if (points.length != 2) continue;
        final a = project(points[0]), b = project(points[1]);
        if ((a - b).distance < 1e-7) continue;
        final names = [key(a), key(b)]..sort();
        if (seen.add(names.join(':'))) segments.add((a, b));
      }
      final links = <String, List<int>>{};
      for (var i = 0; i < segments.length; i++) {
        for (final p in [segments[i].$1, segments[i].$2]) (links[key(p)] ??= []).add(i);
      }
      final used = <int>{};
      for (var seed = 0; seed < segments.length; seed++) {
        if (used.contains(seed)) continue;
        used.add(seed);
        final points = <Offset>[segments[seed].$1, segments[seed].$2];
        while (key(points.first) != key(points.last)) {
          final next = (links[key(points.last)] ?? []).where((i) => !used.contains(i)).firstOrNull;
          if (next == null) break;
          used.add(next);
          final segment = segments[next];
          points.add(key(segment.$1) == key(points.last) ? segment.$2 : segment.$1);
        }
        if (key(points.first) == key(points.last)) add(solid.material, points);
      }
    }
    final concrete = regions[StairSolidMaterial.concrete], finish = regions[StairSolidMaterial.finish];
    if (concrete != null && finish != null) {
      regions[StairSolidMaterial.concrete] = Path.combine(PathOperation.difference, concrete, finish);
    }
    Rect? bounds;
    for (final path in regions.values) {
      if (path.getBounds().isEmpty) continue;
      bounds = bounds == null ? path.getBounds() : bounds.expandToInclude(path.getBounds());
    }
    return ArchitectStairSection(origin, axis, regions, bounds ?? Rect.zero);
  }
}
