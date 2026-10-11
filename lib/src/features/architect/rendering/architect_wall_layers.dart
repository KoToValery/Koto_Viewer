import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_network.dart';

/// Insulation is on the left of the drawing direction. All layers retain the
/// original reference nodes, so their faces share the same mitred junctions.
class ArchitectWallLayers {
  final Path body;
  final Path core;
  final Path insulation;
  const ArchitectWallLayers(this.body, this.core, this.insulation);
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
      final insulation = (type?.insulationThickness ?? 0).clamp(
        0.0,
        (wall.thickness - .001).clamp(0.0, double.infinity),
      );
      final offset =
          wall.centerOffset.dx * wall.normalVector.dx +
          wall.centerOffset.dy * wall.normalVector.dy;
      faces[wall.id] = (
        offset - wall.thickness / 2,
        offset + wall.thickness / 2 - insulation,
      );
    }
    final body = ArchitectWallNetwork.body(walls);
    final core = ArchitectWallNetwork.body(walls, faceOffsets: faces);
    return ArchitectWallLayers(
      body,
      core,
      Path.combine(PathOperation.difference, body, core),
    );
  }
}
