import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_network.dart';
import 'architect_special_wall_geometry.dart';
import 'architect_mesh_section.dart';
import 'architect_path_solid.dart';
import '../services/architect_slab_geometry.dart';
import '../services/architect_roof_geometry.dart';
import '../services/architect_roof_junctions.dart';

/// Insulation follows the explicit exterior side. All layers share the same
/// reference and physical core junctions, including after an orientation flip.
class ArchitectWallLayers {
  late final Map<(ArchitectMaterial, ArchitectLayerRole), Path>
  materialContours = () {
    final result = <(ArchitectMaterial, ArchitectLayerRole), Path>{};
    for (final region in materials) {
      final key = (region.layer.material, region.layer.role);
      result[key] = result.containsKey(key)
          ? Path.combine(PathOperation.union, result[key]!, region.path)
          : region.path;
    }
    return result;
  }();
  final List<ArchitectWallMaterialRegion> materials;
  final Path body;
  final Path core;
  final Path insulation;
  final Path uncutBody;
  final List<ArchitectWall> walls;
  final Map<String, Path> coreRegions;
  ArchitectWallLayers(
    this.body,
    this.core,
    this.insulation, {
    Path? uncutBody,
    this.walls = const [],
    this.coreRegions = const {},
    this.materials = const [],
  }) : uncutBody = uncutBody ?? Path();
  static final _cache = Expando<ArchitectWallLayers>();
  static final _defaults = {
    for (final type in ArchitectWallType.standardCatalog()) type.id: type,
  };

  static ArchitectWallLayers forProject(ArchitectProject project) =>
      _cache[project] ??= build(
        project.activeStorey.walls,
        project.wallTypes,
        cutPlaneHeight: project.activeStorey.cutPlaneHeight,
        storeyElevation: project.activeStorey.elevation,
        storey: project.activeStorey,
        project: project,
      );

  static ArchitectWallLayers build(
    List<ArchitectWall> walls,
    List<ArchitectWallType> types, {
    double cutPlaneHeight = 1.20,
    double storeyElevation = 0,
    ArchitectStorey? storey,
    ArchitectProject? project,
  }) {
    if (walls.any((w) => w.system.isSpecial)) {
      final ordinary = build(
        walls.where((w) => !w.system.isSpecial).toList(),
        types,
        cutPlaneHeight: cutPlaneHeight,
        storeyElevation: storeyElevation,
      );
      var body = ordinary.body,
          core = ordinary.core,
          uncut = ordinary.uncutBody;
      final materials = [...ordinary.materials],
          owners = {...ordinary.coreRegions};
      final floor =
          storey ??
          ArchitectStorey(
            id: 'wall-preview',
            name: '',
            elevation: storeyElevation,
            walls: walls,
          );
      var claimedLogs = Path(), logObstacles = ordinary.body;
      final cutZ = storeyElevation + cutPlaneHeight;
      if (walls.any((w) => w.system.isLog)) {
        for (final column in floor.columns) {
          if (cutPlaneHeight <= column.baseOffset ||
              cutPlaneHeight >=
                  column.baseOffset + (column.height ?? floor.height)) {
            continue;
          }
          logObstacles = Path.combine(
            PathOperation.union,
            logObstacles,
            ArchitectMeshSection.horizontal(
              column.build3D(
                storeyElevation: floor.elevation,
                storeyHeight: floor.height,
              ),
              cutZ,
            ),
          );
        }
        if (project != null) {
          for (final level in project.storeys) {
            for (final slab in level.slabs) {
              var footprint = Path()..addPolygon(slab.polygon, true);
              for (final opening in level.openings) {
                footprint = Path.combine(
                  PathOperation.difference,
                  footprint,
                  Path()..addPolygon(opening.boundary, true),
                );
              }
              for (final hole in slab.holes) {
                footprint = Path.combine(
                  PathOperation.difference,
                  footprint,
                  Path()..addPolygon(hole, true),
                );
              }
              for (final surface in ArchitectSlabGeometry.surfaces(
                project,
                level,
                slab,
              )) {
                if (!slab.polygon.any((p) => surface.bottomAt(p) < cutZ) ||
                    !slab.polygon.any((p) => surface.topAt(p) > cutZ)) {
                  continue;
                }
                logObstacles = Path.combine(
                  PathOperation.union,
                  logObstacles,
                  ArchitectMeshSection.horizontal(
                    ArchitectPathSolid.between(
                      footprint,
                      surface.bottomAt,
                      surface.topAt,
                      ArchitectMaterial.timber.color,
                    ),
                    cutZ,
                  ),
                );
              }
            }
            if (level.id != floor.id &&
                ArchitectRoofGeometry.supportingWallStorey(
                      project,
                      level,
                    )?.id !=
                    floor.id) {
              continue;
            }
            for (final roof in level.roofs) {
              double underside(Offset p) =>
                  level.elevation + roof.undersideElevationAt(p);
              if (!roof.points.any((p) => underside(p) < cutZ)) continue;
              var top = cutZ + 10;
              for (final p in roof.points) {
                if (underside(p) + 10 > top) top = underside(p) + 10;
              }
              logObstacles = Path.combine(
                PathOperation.union,
                logObstacles,
                ArchitectMeshSection.horizontal(
                  ArchitectPathSolid.between(
                    ArchitectRoofJunctions.of(
                      level,
                      project: project,
                    ).footprint(roof),
                    underside,
                    (_) => top,
                    ArchitectMaterial.timber.color,
                  ),
                  cutZ,
                ),
              );
            }
          }
        }
      }
      // A plan describes the nominal log diameter. Slicing alternating round
      // courses gives different chord widths and can hit a tangency exactly;
      // reserve that physical cut for sections and use a clean envelope here.
      for (final wall in walls.where((w) => w.system.isLog)) {
        final outline = Path()
          ..addPolygon(
            ArchitectSpecialWallGeometry.physicalPlanCorners(wall, walls),
            true,
          );
        if (!wall.isCutAt(cutPlaneHeight)) {
          uncut = Path.combine(PathOperation.union, uncut, outline);
          continue;
        }
        var path = Path.combine(
          PathOperation.difference,
          outline,
          wall.openingCutoutAt(cutPlaneHeight - wall.baseOffset),
        );
        path = Path.combine(PathOperation.difference, path, logObstacles);
        path = Path.combine(PathOperation.difference, path, claimedLogs);
        claimedLogs = Path.combine(PathOperation.union, claimedLogs, path);
        body = Path.combine(PathOperation.union, body, path);
        core = Path.combine(PathOperation.union, core, path);
        owners[wall.id] = path;
        materials.add(
          ArchitectWallMaterialRegion(wall, wall.resolvedLayers.first, path),
        );
      }
      for (final component
          in floor.walls.any((w) => w.system.isFrame || w.system.isPanel)
              ? ArchitectSpecialWallGeometry.build(floor, project: project)
              : <ArchitectWallComponent>[]) {
        if (!walls.any((w) => w.id == component.wall.id)) continue;
        final wall = component.wall;
        if (wall.system.isLog) continue;
        if (wall.isCutAt(cutPlaneHeight)) {
          var path = component.at(storeyElevation + cutPlaneHeight);
          // Existing masonry owns its region at a mixed contact; never paint
          // two hatches over the same material section.
          path = Path.combine(PathOperation.difference, path, body);
          body = Path.combine(PathOperation.union, body, path);
          if (component.layer.role == ArchitectLayerRole.core) {
            core = Path.combine(PathOperation.union, core, path);
          }
          owners[wall.id] = Path.combine(
            PathOperation.union,
            owners[wall.id] ?? Path(),
            path,
          );
          materials.add(
            ArchitectWallMaterialRegion(wall, component.layer, path),
          );
        } else {
          final projection = Path();
          for (final t in component.triangles) {
            final points = [
              Offset(t.v0.x, t.v0.y),
              Offset(t.v1.x, t.v1.y),
              Offset(t.v2.x, t.v2.y),
            ];
            final a = points[1] - points[0], b = points[2] - points[0];
            if ((a.dx * b.dy - a.dy * b.dx).abs() > 1e-12) {
              projection.addPolygon(
                a.dx * b.dy - a.dy * b.dx > 0
                    ? points
                    : points.reversed.toList(),
                true,
              );
            }
          }
          uncut = Path.combine(PathOperation.union, uncut, projection);
        }
      }
      return ArchitectWallLayers(
        body,
        core,
        ordinary.insulation,
        uncutBody: Path.combine(PathOperation.difference, uncut, body),
        walls: walls.where((w) => w.isCutAt(cutPlaneHeight)).toList(),
        coreRegions: owners,
        materials: materials,
      );
    }
    final catalog = {..._defaults, for (final type in types) type.id: type};
    final cutWalls = walls.where((w) => w.isCutAt(cutPlaneHeight)).toList();
    final uncutWalls = walls.where((w) => !w.isCutAt(cutPlaneHeight)).toList();

    final faces = <String, (double, double)>{};
    for (final wall in cutWalls) {
      final type = catalog[wall.wallTypeId];
      final insulation =
          (wall.insulationThicknessOverride ??
                  type?.insulationThickness ??
                  wall.insulationThickness)
              .clamp(0.0, (wall.thickness - .001).clamp(0.0, double.infinity));
      final offset =
          wall.centerOffset.dx * wall.normalVector.dx +
          wall.centerOffset.dy * wall.normalVector.dy;
      final outside = wall.layers.isEmpty ? insulation : wall.exteriorBuildUp;
      final inside = wall.layers.isEmpty ? 0.0 : wall.interiorBuildUp;
      faces[wall.id] = (
        offset -
            wall.thickness / 2 +
            (wall.exteriorSign < 0 ? outside : inside),
        offset +
            wall.thickness / 2 -
            (wall.exteriorSign > 0 ? outside : inside),
      );
    }
    var body = ArchitectWallNetwork.body(cutWalls);
    var core = ArchitectWallNetwork.body(cutWalls, faceOffsets: faces);
    for (final wall in cutWalls.where((w) => w.isCurved)) {
      final holes = wall.openingCutoutAt(cutPlaneHeight - wall.baseOffset);
      body = Path.combine(PathOperation.difference, body, holes);
      core = Path.combine(PathOperation.difference, core, holes);
    }
    final rawUncutBody = ArchitectWallNetwork.body(uncutWalls);
    final uncutBody = Path.combine(
      PathOperation.difference,
      rawUncutBody,
      body,
    );

    return ArchitectWallLayers(
      body,
      core,
      Path.combine(PathOperation.difference, body, core),
      uncutBody: uncutBody,
      walls: cutWalls,
      coreRegions: _partitionCores(cutWalls, faces, core),
      materials: _materialRegions(
        cutWalls,
        body,
        core,
        faces,
        storeyElevation + cutPlaneHeight,
      ),
    );
  }

  static List<ArchitectWallMaterialRegion> _materialRegions(
    List<ArchitectWall> walls,
    Path body,
    Path core,
    Map<String, (double, double)> coreFaces,
    double elevation,
  ) {
    final result = <ArchitectWallMaterialRegion>[];
    var claimed = Path();
    final coreOwners = _partitionCores(walls, coreFaces, core);
    final groups =
        <
          String,
          List<(ArchitectWall, ArchitectMaterialLayer, double, double)>
        >{};
    for (final wall in walls) {
      final layers = wall.resolvedLayers;
      final firstCore = layers.indexWhere(
        (l) => l.role == ArchitectLayerRole.core,
      );
      final offset =
          wall.centerOffset.dx * wall.normalVector.dx +
          wall.centerOffset.dy * wall.normalVector.dy;
      var cursor = 0.0;
      for (var i = 0; i < layers.length; i++) {
        var layer = layers[i];
        if (wall.plinth.enabled &&
            wall.isExterior &&
            i < firstCore &&
            elevation >= wall.plinth.baseElevation &&
            elevation < wall.plinth.baseElevation + wall.plinth.height) {
          layer = layer.copyWith(
            material: layer.role == ArchitectLayerRole.insulation
                ? ArchitectMaterial.xps
                : wall.plinth.finish,
          );
        }
        final a = offset + wall.exteriorSign * (wall.thickness / 2 - cursor);
        final b = a - wall.exteriorSign * layer.thickness;
        final key =
            '${layer.role.name}:${layer.material.name}:${i < firstCore ? 'out' : 'in'}:${layers.take(i).where((l) => l.material == layer.material && l.role == layer.role).length}';
        groups.putIfAbsent(key, () => []).add((
          wall,
          layer,
          a < b ? a : b,
          a > b ? a : b,
        ));
        cursor += layer.thickness;
      }
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => a.first.$2.role.index.compareTo(b.first.$2.role.index));
    for (final group in ordered) {
      final list = [for (final e in group) e.$1];
      final faces = {for (final e in group) e.$1.id: (e.$3, e.$4)};
      final raw = ArchitectWallNetwork.body(list, faceOffsets: faces);
      final owners = _partitionCores(list, faces, raw);
      for (final entry in group) {
        var region = Path.combine(
          PathOperation.intersect,
          owners[entry.$1.id]!,
          body,
        );
        if (entry.$2.role == ArchitectLayerRole.core) {
          region = Path.combine(
            PathOperation.intersect,
            region,
            coreOwners[entry.$1.id]!,
          );
        } else {
          region = Path.combine(PathOperation.difference, region, core);
        }
        region = Path.combine(PathOperation.difference, region, claimed);
        claimed = Path.combine(PathOperation.union, claimed, region);
        result.add(ArchitectWallMaterialRegion(entry.$1, entry.$2, region));
      }
    }
    // Resolve residual joint wedges to their physical wall owner; never overlap a core.
    final fullFaces = {
      for (final w in walls)
        w.id: (
          (w.centerOffset.dx * w.normalVector.dx +
                  w.centerOffset.dy * w.normalVector.dy) -
              w.thickness / 2,
          (w.centerOffset.dx * w.normalVector.dx +
                  w.centerOffset.dy * w.normalVector.dy) +
              w.thickness / 2,
        ),
    };
    final owners = _partitionCores(walls, fullFaces, body);
    for (final wall in walls) {
      final rest = Path.combine(
        PathOperation.difference,
        owners[wall.id]!,
        claimed,
      );
      if (rest.getBounds().isEmpty) continue;
      final layer = wall.resolvedLayers.first;
      result.add(ArchitectWallMaterialRegion(wall, layer, rest));
      claimed = Path.combine(PathOperation.union, claimed, rest);
    }
    return result;
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
      regions[wall.id] = ArchitectWallNetwork.polygon(
        wall.facePolygon(low, high),
      );
    }
    for (var i = 0; i < walls.length; i++) {
      final a = walls[i];
      for (final b in walls.skip(i + 1)) {
        if (!(ArchitectWallNetwork.polygon(a.polygonCorners).getBounds())
            .inflate(a.thickness * 4)
            .overlaps(
              ArchitectWallNetwork.polygon(
                b.polygonCorners,
              ).getBounds().inflate(b.thickness * 4),
            )) {
          continue;
        }
        final node = a.intersections(b, finite: false).firstOrNull;
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

class ArchitectWallMaterialRegion {
  final ArchitectWall wall;
  final ArchitectMaterialLayer layer;
  final Path path;
  const ArchitectWallMaterialRegion(this.wall, this.layer, this.path);
}
