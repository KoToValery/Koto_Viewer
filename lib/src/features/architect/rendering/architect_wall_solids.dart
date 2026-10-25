import '../services/architect_roof_junctions.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../services/architect_slab_geometry.dart';
import '../services/architect_roof_geometry.dart';
import 'architect_vertical_clip.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_path_solid.dart';
import 'architect_wall_layers.dart';

class ArchitectWallSolid {
  final ArchitectWall wall;
  final ArchitectMaterialLayer layer;
  final Path path;
  final double bottom, top;
  final List<Triangle3D> triangles;
  const ArchitectWallSolid(
    this.wall,
    this.layer,
    this.path,
    this.bottom,
    this.top,
    this.triangles,
  );
}

/// The plan's material ownership is extruded between actual vertical events.
/// Shared material volumes never overlap at L/T/X junctions.
class ArchitectWallSolids {
  static final _cache =
      Expando<Map<ArchitectStorey, List<ArchitectWallSolid>>>();
  static List<ArchitectWallSolid> build(
    ArchitectStorey storey,
    List<ArchitectWallType> types, {
    ArchitectProject? project,
    Set<String> suppressedOpeningIds = const {},
  }) {
    final cacheable =
        suppressedOpeningIds.isEmpty &&
        project != null &&
        identical(types, project.wallTypes);
    if (cacheable) {
      final cached = _cache[project]?[storey];
      if (cached != null) return cached;
    }
    final roofFloors = [
      storey,
      if (project != null)
        for (final floor in project.storeys)
          if (floor.id != storey.id &&
              floor.roofs.isNotEmpty &&
              ArchitectRoofGeometry.supportingWallStorey(project, floor)?.id ==
                  storey.id)
            floor,
    ];
    final roofEnvelopes = [
      for (final floor in roofFloors)
        for (final roof in floor.roofs) (floor, roof),
    ];
    final nominalTops = {
      for (final w in storey.walls)
        w.id:
            storey.elevation + w.baseOffset + w.effectiveHeight(storey.height),
    };
    final walls = [
      for (final w in storey.walls)
        () {
          var height = w.effectiveHeight(storey.height);
          if (w.followStoreyHeight && !w.isParapet) {
            for (final (floor, roof) in roofEnvelopes) {
              for (final point in roof.points) {
                height = math.max(
                  height,
                  floor.elevation +
                      roof.undersideElevationAt(point) -
                      storey.elevation -
                      w.baseOffset,
                );
              }
            }
          }
          return w.copyWith(height: height, followStoreyHeight: false);
        }(),
    ];
    var roofFootprint = Path();
    for (final (floor, roof) in roofEnvelopes) {
      roofFootprint = Path.combine(
        PathOperation.union,
        roofFootprint,
        ArchitectRoofJunctions.of(floor, project: project).footprint(roof),
      );
    }
    final slabs = <(Path, SlabLayerSurface)>[];
    if (project != null) {
      for (final floor in project.storeys) {
        for (final slab in floor.slabs) {
          var path = Path()..addPolygon(slab.polygon, true);
          for (final opening in floor.openings) {
            path = Path.combine(
              PathOperation.difference,
              path,
              Path()..addPolygon(opening.boundary, true),
            );
          }
          for (final surface in ArchitectSlabGeometry.surfaces(
            project,
            floor,
            slab,
          )) {
            slabs.add((path, surface));
          }
        }
      }
    }
    final breaks = <double>{};
    for (final wall in walls) {
      final bottom = storey.elevation + wall.baseOffset,
          top = bottom + wall.height;
      breaks.addAll([bottom, top, nominalTops[wall.id]!]);
      if (wall.plinth.enabled) {
        for (final z in [
          wall.plinth.baseElevation,
          wall.plinth.baseElevation + wall.plinth.height,
        ]) {
          if (z > bottom && z < top) breaks.add(z);
        }
      }
      for (final op in [
        ...wall.doors
            .where((o) => !suppressedOpeningIds.contains(o.id))
            .map((o) => (o.sillHeight, o.height)),
        ...wall.windows
            .where((o) => !suppressedOpeningIds.contains(o.id))
            .map((o) => (o.sillHeight, o.height)),
      ]) {
        for (final z in [bottom + op.$1, bottom + op.$1 + op.$2]) {
          if (z > bottom && z < top) breaks.add(z);
        }
      }
    }
    final levels = breaks.toList()..sort(), result = <ArchitectWallSolid>[];
    for (var i = 0; i + 1 < levels.length; i++) {
      final bottom = levels[i], top = levels[i + 1], mid = (bottom + top) / 2;
      if (top - bottom < 1e-8) continue;
      final active = [
        for (final w in walls)
          if (mid > storey.elevation + w.baseOffset &&
              mid < storey.elevation + w.baseOffset + w.height)
            w.copyWith(cutDisplayMode: ArchitectCutDisplayMode.cut),
      ];
      final layers = ArchitectWallLayers.build(
        active,
        types,
        storeyElevation: storey.elevation,
        cutPlaneHeight: mid - storey.elevation,
      );
      final holes = <String, Path>{};
      for (final w in active) {
        final path = w.openingCutoutAt(
          mid - storey.elevation - w.baseOffset,
          suppressedOpeningIds: suppressedOpeningIds,
        );
        holes[w.id] = path;
      }
      for (final region in layers.materials) {
        final path = Path.combine(
          PathOperation.difference,
          region.path,
          holes[region.wall.id]!,
        );
        if (path.getBounds().isEmpty) continue;
        final wall = region.wall, plinth = wall.plinth;
        var footprint = path;
        if (mid > nominalTops[wall.id]! + .000001) {
          footprint = Path.combine(
            PathOperation.intersect,
            footprint,
            roofFootprint,
          );
        }
        var parts = [
          ArchitectVerticalPart(footprint, (_) => bottom, (_) => top),
        ];
        for (final (outline, surface) in slabs) {
          parts = ArchitectVerticalClip.subtract(
            parts,
            outline,
            surface.bottomAt,
            surface.topAt,
          );
        }
        for (final (floor, roof) in roofEnvelopes) {
          parts = ArchitectVerticalClip.subtract(
            parts,
            ArchitectRoofJunctions.of(floor, project: project).footprint(roof),
            (p) => floor.elevation + roof.undersideElevationAt(p),
            (p) => floor.elevation + roof.topElevationAt(p),
            removeAbove: true,
          );
        }
        final color = wall.layers.isEmpty && !plinth.enabled
            ? const Color(0xFFECEFF1)
            : region.layer.material.color;
        // Each clipped part is a closed solid. Keep it separate so vertical
        // sections do not trace through shared internal faces and lose masonry.
        for (final part in parts) {
          final tris = ArchitectPathSolid.between(
            part.path,
            part.bottom,
            part.top,
            color,
          );

          final exteriorLayer = wall.resolvedLayers.first;
          // With no explicit render skin, the finish is a surface treatment;
          // it must not turn the insulation or masonry volume into stone.
          if (wall.isExterior &&
              plinth.enabled &&
              mid >= plinth.baseElevation &&
              mid < plinth.baseElevation + plinth.height &&
              region.layer.id == exteriorLayer.id &&
              exteriorLayer.role != ArchitectLayerRole.finish) {
            final plane =
                wall.centerStart + wall.exteriorNormal * (wall.thickness / 2);
            for (var j = 0; j < tris.length; j++) {
              final t = tris[j];
              bool onFace(Vector3 p) {
                if (wall.isCurved) {
                  return ((Offset(p.x, p.y) - wall.arc!.center).distance -
                              (wall.arc!.radius -
                                  wall.arcBulge.sign *
                                      (wall.centerLineOffset +
                                          wall.exteriorSign *
                                              wall.thickness /
                                              2)))
                          .abs() <
                      .0001;
                }
                return ((Offset(p.x, p.y) - plane).dx * wall.exteriorNormal.dx +
                            (Offset(p.x, p.y) - plane).dy *
                                wall.exteriorNormal.dy)
                        .abs() <
                    .00001;
              }

              if ([t.v0, t.v1, t.v2].every(onFace)) {
                tris[j] = Triangle3D(
                  v0: t.v0,
                  v1: t.v1,
                  v2: t.v2,
                  color: plinth.finish.color,
                );
              }
            }
          }
          if (tris.isEmpty) continue;
          result.add(
            ArchitectWallSolid(
              wall,
              region.layer,
              part.path,
              bottom,
              top,
              tris,
            ),
          );
        }
      }
    }
    if (cacheable) {
      (_cache[project] ??=
              <ArchitectStorey, List<ArchitectWallSolid>>{})[storey] =
          result;
    }
    return result;
  }
}
