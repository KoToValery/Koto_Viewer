import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_network.dart';

/// Insulation follows the explicit exterior side. All layers retain the
/// original reference nodes, so their faces share the same mitred junctions.
class ArchitectWallLayers {
  final Path body;
  final Path core;
  final Path insulation;
  final List<ArchitectWall> walls;
  final Map<String, Path> coreRegions;
  const ArchitectWallLayers(
    this.body,
    this.core,
    this.insulation, {
    this.walls = const [],
    this.coreRegions = const {},
  });
  static final _cache = Expando<ArchitectWallLayers>();
  static final _defaults = {
    for (final type in ArchitectWallType.standardCatalog()) type.id: type,
  };

  static ArchitectWallLayers forProject(ArchitectProject project) =>
      _cache[project] ??= build(project.activeStorey.walls, project.wallTypes);

  static ArchitectWallLayers build(
    List<ArchitectWall> walls,
    List<ArchitectWallType> types,
  ) {
    final catalog = {..._defaults, for (final type in types) type.id: type};
    final faces = <String, (double, double)>{};
    for (final wall in walls) {
      final type = catalog[wall.wallTypeId];
      final insulation =
          (wall.insulationThicknessOverride ??
                  type?.insulationThickness ??
                  wall.insulationThickness)
              .clamp(0.0, (wall.thickness - .001).clamp(0.0, double.infinity));
      final offset =
          wall.centerOffset.dx * wall.normalVector.dx +
          wall.centerOffset.dy * wall.normalVector.dy;
      faces[wall.id] = (
        offset - wall.thickness / 2 + (wall.exteriorSign < 0 ? insulation : 0),
        offset + wall.thickness / 2 - (wall.exteriorSign > 0 ? insulation : 0),
      );
    }
    final body = ArchitectWallNetwork.body(walls);
    final core = ArchitectWallNetwork.body(walls, faceOffsets: faces);
    return ArchitectWallLayers(
      body,
      core,
      Path.combine(PathOperation.difference, body, core),
      walls: walls,
      coreRegions: _partitionCores(walls, faces, core),
    );
  }

  /// Give each wall its own hatch region. At a junction, the angular bisector
  /// separates the two materials; a stable ID order resolves triple overlaps.
  static Map<String, Path> _partitionCores(
    List<ArchitectWall> walls,
    Map<String, (double, double)> faces,
    Path core,
  ) {
    final regions = <String, Path>{};
    for (final wall in walls) {
      final (low, high) = faces[wall.id]!;
      regions[wall.id] = ArchitectWallNetwork.polygon([
        wall.startPoint + wall.normalVector * low,
        wall.endPoint + wall.normalVector * low,
        wall.endPoint + wall.normalVector * high,
        wall.startPoint + wall.normalVector * high,
      ]);
    }
    for (var i = 0; i < walls.length; i++) {
      final a = walls[i];
      for (final b in walls.skip(i + 1)) {
        if (!Rect.fromPoints(a.startPoint, a.endPoint)
            .inflate(a.thickness * 4)
            .overlaps(
              Rect.fromPoints(
                b.startPoint,
                b.endPoint,
              ).inflate(b.thickness * 4),
            )) {
          continue;
        }
        final node = ArchitectWallNetwork.intersection(
          a.startPoint,
          a.endPoint,
          b.startPoint,
          b.endPoint,
        );
        if (node == null) continue;
        for (final (polygon, _) in ArchitectWallNetwork.junctions([
          a,
          b,
        ], faceOffsets: faces)) {
          Offset ray(ArchitectWall wall) {
            final direction = (wall.startPoint + wall.endPoint) / 2 - node;
            return direction.distance < 1e-8
                ? wall.unitVector
                : direction / direction.distance;
          }

          final normal = ray(a) - ray(b);
          if (normal.distance < 1e-8) continue;
          final joint = ArchitectWallNetwork.polygon(polygon);
          for (final (wall, sign) in [(a, 1.0), (b, -1.0)]) {
            final part = _halfPlane(polygon, node, normal * sign);
            regions[wall.id] = Path.combine(
              PathOperation.union,
              Path.combine(PathOperation.difference, regions[wall.id]!, joint),
              ArchitectWallNetwork.polygon(part),
            );
          }
        }
      }
    }
    var claimed = Path();
    final result = <String, Path>{};
    final ordered = [...walls]..sort((a, b) => a.id.compareTo(b.id));
    for (final wall in ordered) {
      final region = Path.combine(
        PathOperation.difference,
        Path.combine(PathOperation.intersect, regions[wall.id]!, core),
        claimed,
      );
      result[wall.id] = region;
      claimed = Path.combine(PathOperation.union, claimed, region);
    }
    if (ordered.isNotEmpty) {
      final rest = Path.combine(PathOperation.difference, core, claimed);
      result[ordered.first.id] = Path.combine(
        PathOperation.union,
        result[ordered.first.id]!,
        rest,
      );
    }
    return result;
  }

  static List<Offset> _halfPlane(
    List<Offset> polygon,
    Offset node,
    Offset normal,
  ) {
    final result = <Offset>[];
    double distance(Offset p) =>
        (p - node).dx * normal.dx + (p - node).dy * normal.dy;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final da = distance(a), db = distance(b);
      if (da >= 0) result.add(a);
      if ((da >= 0) != (db >= 0)) result.add(a + (b - a) * (da / (da - db)));
    }
    return result;
  }
}
