import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_roof_geometry.dart';
import '../services/architect_roof_junctions.dart';
import '../services/architect_slab_geometry.dart';
import '../services/architect_wall_connection_policy.dart';
import '../services/architect_panel_supports.dart';
import 'architect_mesh_boolean.dart';
import 'architect_path_solid.dart';
import 'architect_mesh_section.dart';
import 'architect_wall_solids.dart';
import 'architect_panel_roof_geometry.dart';

class ArchitectWallComponent {
  final ArchitectWall wall;
  final String id;
  final ArchitectMaterialLayer layer;
  final List<Triangle3D> triangles;
  const ArchitectWallComponent(this.wall, this.id, this.layer, this.triangles);
  BoundingBox3D get bounds => BoundingBox3D.fromPoints([
    for (final t in triangles) ...[t.v0, t.v1, t.v2],
  ]);

  /// Horizontal slicing uses the same closed solids as the vertical sections.
  Path at(double z) {
    return ArchitectMeshSection.horizontal(triangles, z);
  }
}

class ArchitectLogWallLayout {
  final ArchitectWall wall;
  final double phase, from, to;
  const ArchitectLogWallLayout(this.wall, this.phase, this.from, this.to);
}

/// Montage nodes stay fixed. All end extensions are derived physical geometry.
class ArchitectSpecialWallGeometry {
  static List<Offset> physicalPlanCorners(
    ArchitectWall wall,
    List<ArchitectWall> walls,
  ) {
    if (!wall.system.isLog) return wall.polygonCorners;
    final layout = logLayouts(walls)[wall.id];
    if (layout == null) return wall.polygonCorners;
    final a = wall.centerStart + wall.unitVector * layout.from,
        b = wall.centerStart + wall.unitVector * layout.to,
        n = wall.normalVector * wall.thickness / 2;
    return [a - n, b - n, b + n, a + n];
  }

  static bool containsPlanPoint(
    ArchitectWall wall,
    List<ArchitectWall> walls,
    Offset point,
  ) {
    if (wall.containsPoint(point)) return true;
    return wall.system.isLog &&
        (Path()..addPolygon(physicalPlanCorners(wall, walls), true)).contains(
          point,
        );
  }

  static final _cache =
      Expando<Map<ArchitectStorey, List<ArchitectWallComponent>>>();

  static bool compatibleLogs(ArchitectWall a, ArchitectWall b) =>
      ArchitectWallConnectionPolicy.compatibleLogs(a, b);

  static Offset? joint(ArchitectWall a, ArchitectWall b) {
    return ArchitectWallConnectionPolicy.joint(a, b);
  }

  static Map<String, ArchitectLogWallLayout> logLayouts(
    List<ArchitectWall> walls,
  ) {
    final logs = walls.where((w) => w.system.isLog).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final phases = <String, double>{};
    final edges = <String, List<(String, bool)>>{
      for (final w in logs) w.id: [],
    };
    for (var i = 0; i < logs.length; i++) {
      final a = logs[i];
      for (final b in logs.skip(i + 1)) {
        if (!compatibleLogs(a, b)) continue;
        final dot =
            (a.unitVector.dx * b.unitVector.dx +
                    a.unitVector.dy * b.unitVector.dy)
                .abs();
        final perpendicular = dot < 1e-5 && joint(a, b) != null;
        final collinear =
            dot > 1 - 1e-5 &&
            ((a.centerStart - b.centerStart).dx * a.normalVector.dx +
                        (a.centerStart - b.centerStart).dy * a.normalVector.dy)
                    .abs() <
                1e-5 &&
            [a.centerStart, a.centerEnd].any(
              (p) => [
                b.centerStart,
                b.centerEnd,
              ].any((q) => (p - q).distance < .001),
            );
        if (!perpendicular && !collinear) continue;
        edges[a.id]!.add((b.id, perpendicular));
        edges[b.id]!.add((a.id, perpendicular));
      }
    }
    // Explicit instance phases take precedence; otherwise an existing stable ID
    // anchors each connected component. Direction and world rotation do not.
    final roots = [
      ...logs.where((w) => w.systemPlacement.coursePhase != null),
      ...logs,
    ];
    for (final root in roots) {
      if (phases.containsKey(root.id)) continue;
      phases[root.id] = root.systemPlacement.coursePhase ?? 0;
      final queue = [root.id];
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final id = queue[cursor];
        for (final edge in edges[id]!) {
          final expected = (phases[id]! + (edge.$2 ? .5 : 0)) % 1;
          if (phases.containsKey(edge.$1)) {
            if ((phases[edge.$1]! - expected).abs() > 1e-5) {
              throw ArgumentError('Incompatible log course phases');
            }
          } else {
            phases[edge.$1] = expected;
            queue.add(edge.$1);
          }
        }
      }
    }
    return {
      for (final a in logs)
        a.id: () {
          var from = 0.0, to = a.length;
          for (final b in logs) {
            if (a.id == b.id || !compatibleLogs(a, b)) continue;
            if ((a.unitVector.dx * b.unitVector.dx +
                        a.unitVector.dy * b.unitVector.dy)
                    .abs() >
                1e-5) {
              continue;
            }
            final p = joint(a, b);
            if (p == null) continue;
            final d = p - a.centerStart,
                station = d.dx * a.unitVector.dx + d.dy * a.unitVector.dy;
            final near = a.thickness + b.thickness + .001;
            if (station.abs() < near && a.connectStart) {
              from = math.min(
                from,
                station -
                    b.thickness / 2 -
                    (a.systemPlacement.startTail ??
                        a.thickness * a.system.tailFactor),
              );
            }
            if ((station - a.length).abs() < near && a.connectEnd) {
              to = math.max(
                to,
                station +
                    b.thickness / 2 +
                    (a.systemPlacement.endTail ??
                        a.thickness * a.system.tailFactor),
              );
            }
          }
          return ArchitectLogWallLayout(a, phases[a.id]!, from, to);
        }(),
    };
  }

  static List<ArchitectWallComponent> build(
    ArchitectStorey storey, {
    ArchitectProject? project,
    Set<String> suppressedOpeningIds = const {},
  }) {
    if (!storey.walls.any((w) => w.system.isSpecial)) return const [];
    final cacheable = project != null && suppressedOpeningIds.isEmpty;
    if (cacheable) {
      final cached = _cache[project]?[storey];
      if (cached != null) return cached;
    }
    final layouts = logLayouts(storey.walls),
        result = <ArchitectWallComponent>[];
    final roofs = [
      if (project != null)
        for (final floor in project.storeys)
          if (floor.id == storey.id ||
              ArchitectRoofGeometry.supportingWallStorey(project, floor)?.id ==
                  storey.id)
            for (final roof in floor.roofs) (floor, roof),
    ];
    var roofFootprint = Path();
    for (final (floor, roof) in roofs) {
      roofFootprint = Path.combine(
        PathOperation.union,
        roofFootprint,
        ArchitectRoofJunctions.of(floor, project: project).footprint(roof),
      );
    }
    final rawLogs = <(ArchitectWall, double, List<Triangle3D>)>[];
    for (final original in storey.walls.where((w) => w.system.isSpecial)) {
      var height = original.effectiveHeight(storey.height);
      if (!original.system.isLog && original.followStoreyHeight) {
        for (final (floor, roof) in roofs) {
          for (final point in roof.points) {
            height = math.max(
              height,
              floor.elevation +
                  (roof.assembly.panels!=null && original.system.isPanel
                    ?ArchitectPanelRoofGeometry.panelUnderside(roof,point):roof.undersideElevationAt(point)) -
                  storey.elevation -
                  original.baseOffset,
            );
          }
        }
      }
      final wall = original.copyWith(height: height);
      wall.validateGeometry();
      final z0 = storey.elevation + wall.baseOffset, z1 = z0 + wall.height;
      var frameFrom = 0.0, frameTo = wall.length;
      if (wall.system.isFrame) {
        for (final other in storey.walls.where(
          (w) => w.system.isFrame && w.id != wall.id,
        )) {
          final node = joint(wall, other);
          if (node == null ||
              (wall.unitVector.dx * other.unitVector.dx +
                          wall.unitVector.dy * other.unitVector.dy)
                      .abs() >
                  1e-5) {
            continue;
          }
          final station =
              (node - wall.centerStart).dx * wall.unitVector.dx +
              (node - wall.centerStart).dy * wall.unitVector.dy;
          if (station.abs() < .001) frameFrom = -other.thickness / 2;
          if ((station - wall.length).abs() < .001) {
            frameTo = wall.length + other.thickness / 2;
          }
        }
      }
      final components = <ArchitectWallComponent>[];
      void append(
        String id,
        ArchitectMaterialLayer layer,
        List<Triangle3D> mesh,
      ) {
        if ((wall.system.isFrame || wall.system.isPanel) &&
            layer.material == ArchitectMaterial.steel) {
          for (final previous in components.where(
            (c) => c.layer.material == ArchitectMaterial.steel,
          )) {
            mesh = ArchitectMeshBoolean.subtract(mesh, previous.triangles);
          }
        }
        mesh = [
          for (final t in mesh)
            Triangle3D(
              v0: t.v0,
              v1: t.v1,
              v2: t.v2,
              color: layer.material.color,
            ),
        ];
        if (mesh.isNotEmpty) {
          components.add(ArchitectWallComponent(wall, id, layer, mesh));
        }
      }

      if (wall.system.isLog) {
        final layout = layouts[wall.id]!,
            r = wall.thickness / 2,
            h = wall.system.pitch(wall.thickness);
        final count = (wall.height / h).ceil() + 1;
        for (var row = 0; row < count; row++) {
          final center = z0 + (row + layout.phase) * h;
          if (center - r >= z1 - 1e-8) break;
          final circle = _circle(r, center), previous = _circle(r, center - h);
          var profile = Path.combine(
            PathOperation.difference,
            circle,
            previous,
          );
          profile = Path.combine(
            PathOperation.intersect,
            profile,
            Path()..addRect(Rect.fromLTRB(-r - 1, z0, r + 1, z1)),
          );
          final raw = _along(wall, circle, layout.from, layout.to);
          rawLogs.add((wall, center, raw));
          append(
            'log_$row',
            wall.resolvedLayers.first,
            _along(wall, profile, layout.from, layout.to),
          );
        }
        if (wall.system.openingCasing) {
          final width = wall.system.casingWidth,
              layer = wall.resolvedLayers.first;
          for (final op in _openings(wall, suppressedOpeningIds)) {
            for (final (a, b) in [
              (op.$1 - width, op.$1),
              (op.$2, op.$2 + width),
            ]) {
              append(
                'casing_${op.$1}_$a',
                layer,
                _band(wall, a, b, -r, r, z0 + op.$3, z0 + op.$4 + width),
              );
            }
            append(
              'casing_header_${op.$1}',
              layer,
              _band(wall, op.$1, op.$2, -r, r, z0 + op.$4, z0 + op.$4 + width),
            );
          }
        }
      } else {
        final core = wall.resolvedLayers
            .where((l) => l.role == ArchitectLayerRole.core)
            .toList();
        var cursor = 0.0;
        double frameLow = 0, frameHigh = 0;
        for (final layer in wall.resolvedLayers) {
          final high = wall.thickness / 2 - cursor,
              low = high - layer.thickness;
          if (wall.system.isFrame && layer.role == ArchitectLayerRole.core) {
            frameLow = low;
            frameHigh = high;
          } else {
            if (wall.system.isPanel) {
              final extent = wall.system.horizontalPanels
                  ? wall.height
                  : wall.length;
              for (
                var s = 0.0;
                s < extent - 1e-8;
                s += wall.system.panelModule
              ) {
                final end = math.min(extent, s + wall.system.panelModule);
                append(
                  '${layer.id}_panel_$s',
                  layer,
                  _band(
                    wall,
                    wall.system.horizontalPanels ? 0 : s,
                    wall.system.horizontalPanels ? wall.length : end,
                    low,
                    high,
                    wall.system.horizontalPanels ? z0 + s : z0,
                    wall.system.horizontalPanels ? z0 + end : z1,
                  ),
                );
              }
            } else {
              append(
                layer.id,
                layer,
                _band(wall, frameFrom, frameTo, low, high, z0, z1),
              );
            }
          }
          cursor += layer.thickness;
        }
        if (wall.system.isPanel) {
          frameHigh = wall.thickness / 2 - cursor;
          frameLow = frameHigh - wall.system.supportDepth;
        }
        final depth = frameHigh - frameLow;
        if (depth > .001) {
          final metal = ArchitectMaterialLayer(
            id: 'steel',
            material: ArchitectMaterial.steel,
            role: ArchitectLayerRole.core,
            thickness: wall.system.metalThickness,
          );
          final t = wall.system.metalThickness, width = wall.system.studWidth;
          final stations = <double>{frameFrom, frameTo - width};
          for (
            var s = wall.system.studSpacing;
            s < wall.length - width;
            s += wall.system.studSpacing
          ) {
            stations.add(s);
          }
          for (final op in _openings(wall, suppressedOpeningIds)) {
            stations.addAll([op.$1 - width, op.$2]);
          }
          if (wall.system.isFrame) {
            for (final station in stations.where(
              (s) => s >= frameFrom && s + width <= frameTo + .00001,
            )) {
              final profile = Path()
                ..addRect(
                  Rect.fromLTRB(station, frameLow, station + t, frameHigh),
                )
                ..addRect(
                  Rect.fromLTRB(
                    station,
                    frameLow,
                    station + width,
                    frameLow + t,
                  ),
                )
                ..addRect(
                  Rect.fromLTRB(
                    station,
                    frameHigh - t,
                    station + width,
                    frameHigh,
                  ),
                );
              append(
                'stud_$station',
                metal,
                _vertical(wall, profile, z0 + t, z1 - t),
              );
            }
            for (final (base, top) in [(z0, z0 + width), (z1 - width, z1)]) {
              // U track: horizontal web with two vertical flanges.
              append(
                'track_${base}_web',
                metal,
                _band(
                  wall,
                  frameFrom,
                  frameTo,
                  frameLow,
                  frameHigh,
                  base == z0 ? base : top - t,
                  base == z0 ? base + t : top,
                ),
              );
              for (final side in [frameLow, frameHigh - t]) {
                append(
                  'track_${base}_$side',
                  metal,
                  _band(
                    wall,
                    frameFrom,
                    frameTo,
                    side,
                    side + t,
                    base == z0 ? base + t : base,
                    base == z0 ? top : top - t,
                  ),
                );
              }
            }
            for (final op in _openings(wall, suppressedOpeningIds)) {
              final bottom = z0 + op.$4, top = math.min(z1, bottom + width);
              if (top <= bottom) continue;
              append(
                'header_${op.$1}',
                metal,
                _band(
                  wall,
                  op.$1,
                  op.$2,
                  frameLow,
                  frameHigh,
                  bottom,
                  bottom + t,
                ),
              );
              for (final side in [frameLow, frameHigh - t]) {
                append(
                  'header_${op.$1}_$side',
                  metal,
                  _band(wall, op.$1, op.$2, side, side + t, bottom + t, top),
                );
              }
            }
            final woolDepth = math.min(depth, wall.system.insulationDepth);
            if (woolDepth > 0 && core.isNotEmpty) {
              var wool = _band(
                wall,
                frameFrom,
                frameTo,
                frameLow,
                frameLow + woolDepth,
                z0 + t,
                z1 - t,
              );
              // Metal owns its volume; insulation fills the remaining cavity.
              for (final c in components.where(
                (c) => c.layer.material == ArchitectMaterial.steel,
              )) {
                wool = ArchitectMeshBoolean.subtract(wool, c.triangles);
              }
              append(
                'wool',
                ArchitectMaterialLayer(
                  id: 'wool',
                  material: ArchitectMaterial.stoneWool,
                  role: ArchitectLayerRole.insulation,
                  thickness: woolDepth,
                ),
                wool,
              );
            }
          } else {
            // Rails run perpendicular to the panel laying direction.
            final horizontal = !wall.system.horizontalPanels;
            final extent = horizontal ? wall.height : wall.length;
            final supports = storey.columns
                .where((c) => wall.systemPlacement.columnIds.contains(c.id))
                .toList();
            final railStations = <double>{};
            if (!horizontal && supports.isNotEmpty) {
              for (final c in supports) {
                railStations.add(
                  ArchitectPanelSupports.dot(
                    c.position - wall.centerStart,
                    wall.unitVector,
                  ).clamp(0, math.max(0, wall.length - width)),
                );
              }
            } else {
              for (
                var s = 0.0;
                s < extent - .001;
                s += wall.system.studSpacing
              ) {
                railStations.add(s);
              }
            }
            for (final s in railStations) {
              final a = horizontal ? 0.0 : s,
                  b = horizontal
                      ? wall.length
                      : math.min(wall.length, s + width);
              final bottom = horizontal ? z0 + s : z0,
                  top = horizontal ? math.min(z1, bottom + width) : z1;
              var rail = _band(wall, a, b, frameLow, frameHigh, bottom, top);
              if (depth > 2 * t && top - bottom > 2 * t && b - a > 2 * t) {
                rail = ArchitectMeshBoolean.subtract(
                  rail,
                  _band(
                    wall,
                    horizontal ? a - .001 : a + t,
                    horizontal ? b + .001 : b - t,
                    frameLow + t,
                    frameHigh - t,
                    horizontal ? bottom + t : bottom - .001,
                    horizontal ? top - t : top + .001,
                  ),
                );
              }
              append('rail_$s', metal, rail);
              if (wall.system.panelMount == ArchitectPanelMount.inFront) {
                for (final column in supports) {
                  final station = ArchitectPanelSupports.dot(
                    column.position - wall.centerStart,
                    wall.unitVector,
                  );
                  if (!horizontal &&
                      (station - (a + b) / 2).abs() > width + column.width) {
                    continue;
                  }
                  final face = ArchitectPanelSupports.corners(column)
                      .map(
                        (p) => ArchitectPanelSupports.dot(
                          p - wall.centerStart,
                          wall.exteriorNormal,
                        ),
                      )
                      .reduce(math.max);
                  if (face >= frameLow - 1e-6) continue;
                  final left = (station - width / 2)
                          .clamp(0, wall.length)
                          .toDouble(),
                      right = (station + width / 2)
                          .clamp(0, wall.length)
                          .toDouble();
                  if (right - left < .001) continue;
                  final levels = horizontal
                      ? [bottom + t]
                      : [z0 + width, z1 - width];
                  for (final level in levels) {
                    append(
                      'bracket_${column.id}_${s}_$level',
                      metal,
                      _band(
                        wall,
                        left,
                        right,
                        face,
                        frameHigh,
                        level - t,
                        level,
                      ),
                    );
                    append(
                      'bracket_flange_${column.id}_${s}_$level',
                      metal,
                      _band(
                        wall,
                        left,
                        right,
                        face,
                        face + t,
                        level,
                        math.min(z1, level + width),
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      }
      for (final c in components) {
        var mesh = c.triangles;
        for (final op in _openings(wall, suppressedOpeningIds)) {
          final log = wall.system.isLog && c.id.startsWith('log_');
          final casing = log && wall.system.openingCasing
              ? wall.system.casingWidth
              : 0.0;
          mesh = ArchitectMeshBoolean.subtract(
            mesh,
            _band(
              wall,
              op.$1 - casing,
              op.$2 + casing,
              -wall.thickness,
              wall.thickness,
              z0 + op.$3,
              z0 + op.$4 + casing + (log ? wall.system.settlementAllowance : 0),
            ),
          );
        }
        result.add(ArchitectWallComponent(wall, c.id, c.layer, mesh));
      }
    }
    // Lower courses own saddle contact volumes. A nominal cylinder is used as
    // the cutter so a previously cut notch cannot leave a crossing wood sliver.
    final notched = <ArchitectWallComponent>[];
    for (final c in result) {
      var mesh = c.triangles;
      final original = storey.walls.firstWhere((w) => w.id == c.wall.id);
      final nominalTop =
          storey.elevation +
          original.baseOffset +
          original.effectiveHeight(storey.height);
      if (!c.wall.system.isLog &&
          original.followStoreyHeight &&
          c.bounds.max.z > nominalTop + 1e-6) {
        final box = Rect.fromLTRB(
          c.bounds.min.x,
          c.bounds.min.y,
          c.bounds.max.x,
          c.bounds.max.y,
        ).inflate(.01);
        final outside = Path.combine(
          PathOperation.difference,
          Path()..addRect(box),
          roofFootprint,
        );
        mesh = ArchitectMeshBoolean.subtract(
          mesh,
          ArchitectPathSolid.extrude(
            outside,
            nominalTop,
            c.bounds.max.z + 1,
            c.layer.material.color,
          ),
        );
      }
      if (c.wall.system.isLog && c.id.startsWith('log_')) {
        final row = int.parse(c.id.substring(4)), layout = layouts[c.wall.id]!;
        final center =
            storey.elevation +
            c.wall.baseOffset +
            (row + layout.phase) * c.wall.system.pitch(c.wall.thickness);
        for (final other in rawLogs) {
          if (other.$1.id == c.wall.id ||
              !compatibleLogs(c.wall, other.$1) ||
              joint(c.wall, other.$1) == null ||
              other.$2 >= center - 1e-7 ||
              center - other.$2 >= c.wall.thickness - 1e-7) {
            continue;
          }
          mesh = ArchitectMeshBoolean.subtract(mesh, other.$3);
        }
      }
      if (project != null) {
        for (final floor in project.storeys) {
          for (final slab in floor.slabs) {
            var slabPath = Path()..addPolygon(slab.polygon, true);
            for (final opening in floor.openings) {
              slabPath = Path.combine(
                PathOperation.difference,
                slabPath,
                Path()..addPolygon(opening.boundary, true),
              );
            }
            for (final surface in ArchitectSlabGeometry.surfaces(
              project,
              floor,
              slab,
            )) {
              mesh = ArchitectMeshBoolean.subtract(
                mesh,
                ArchitectPathSolid.between(
                  slabPath,
                  surface.bottomAt,
                  surface.topAt,
                  c.layer.material.color,
                ),
              );
            }
          }
          if (floor.id != storey.id &&
              ArchitectRoofGeometry.supportingWallStorey(project, floor)?.id !=
                  storey.id) {
            continue;
          }
          for (final roof in floor.roofs) {
            if(c.wall.system.isPanel&&roof.assembly.panels!=null) {
              for(final member in ArchitectPanelRoofGeometry.build(floor,roof,project:project)
                .where((m)=>m.structural)) {
                mesh=ArchitectMeshBoolean.subtract(mesh,member.triangles);
              }
            }
            if (c.wall.system.isLog &&
                roof.assembly.preset == ArchitectRoofPreset.logTimber &&
                roof.assembly.timber.hasWallPlate) {
              final line = ArchitectRoofGeometry.wallBearingLine(roof);
              if (line != null && (line.$2 - line.$1).distance > 1e-6) {
                final u = (line.$2 - line.$1) / (line.$2 - line.$1).distance;
                final n =
                    Offset(-u.dy, u.dx) *
                    roof.assembly.timber.wallPlateWidth /
                    2;
                final outline = Path.combine(
                  PathOperation.intersect,
                  Path()..addPolygon([
                    line.$1 - n,
                    line.$2 - n,
                    line.$2 + n,
                    line.$1 + n,
                  ], true),
                  ArchitectRoofJunctions.of(
                    floor,
                    project: project,
                  ).footprint(roof),
                );
                mesh = ArchitectMeshBoolean.subtract(
                  mesh,
                  ArchitectPathSolid.between(
                    outline,
                    (p) =>
                        floor.elevation +
                        roof.undersideElevationAt(p) -
                        roof.assembly.timber.wallPlateHeight,
                    (p) => floor.elevation + roof.undersideElevationAt(p),
                    c.layer.material.color,
                  ),
                );
              }
            }
            mesh = ArchitectMeshBoolean.subtract(
              mesh,
              ArchitectPathSolid.between(
                ArchitectRoofJunctions.of(
                  floor,
                  project: project,
                ).footprint(roof),
                (p) => floor.elevation + (c.wall.system.isPanel && roof.assembly.panels!=null
                  ?ArchitectPanelRoofGeometry.panelUnderside(roof,p):roof.undersideElevationAt(p)),
                (_) =>
                    storey.elevation + c.wall.baseOffset + c.wall.height + 10,
                c.layer.material.color,
              ),
            );
          }
        }
      }
      if (mesh.isNotEmpty) {
        notched.add(ArchitectWallComponent(c.wall, c.id, c.layer, mesh));
      }
    }
    // Resolve mixed contacts from the same ordinary solids used elsewhere.
    // The recursive call contains no special walls and exits this builder.
    final ordinary = storey.walls.where((w) => !w.system.isSpecial).toList();
    final obstacles = ordinary.isEmpty
        ? <ArchitectWallSolid>[]
        : ArchitectWallSolids.build(
            storey.copyWith(walls: ordinary),
            project?.wallTypes ?? [],
            project: project,
            suppressedOpeningIds: suppressedOpeningIds,
          );
    int priority(ArchitectWallComponent c) => c.wall.system.isLog
        ? 0
        : c.layer.material == ArchitectMaterial.steel
        ? 1
        : c.layer.role == ArchitectLayerRole.finish
        ? 2
        : 3;
    notched.sort((a, b) {
      final p = priority(a).compareTo(priority(b));
      return p != 0
          ? p
          : '${a.wall.id}:${a.id}'.compareTo('${b.wall.id}:${b.id}');
    });
    final clean = <ArchitectWallComponent>[];
    final columns = [
      for (final column in storey.columns)
        column.build3D(
          storeyElevation: storey.elevation,
          storeyHeight: storey.height,
        ),
    ];
    for (final c in notched) {
      var mesh = c.triangles;
      for (final column in columns) {
        mesh = ArchitectMeshBoolean.subtract(mesh, column);
      }
      for (final obstacle in obstacles) {
        if (c.bounds.max.z < obstacle.bottom || c.bounds.min.z > obstacle.top) {
          continue;
        }
        mesh = ArchitectMeshBoolean.subtract(mesh, obstacle.triangles);
      }
      if (!c.wall.system.isLog) {
        for (final previous in clean) {
          if (previous.wall.id == c.wall.id ||
              !c.bounds.intersects(previous.bounds)) {
            continue;
          }
          mesh = ArchitectMeshBoolean.subtract(mesh, previous.triangles);
        }
      }
      if (mesh.isNotEmpty) {
        clean.add(
          ArchitectWallComponent(
            c.wall,
            c.id,
            c.layer,
            ArchitectMeshBoolean.simplify(mesh),
          ),
        );
      }
    }
    if (cacheable) (_cache[project] ??= {})[storey] = clean;
    return clean;
  }

  static Path _circle(double r, double z) => Path()
    ..addPolygon([
      for (var i = 0; i < 48; i++)
        Offset(
          r * math.cos(i * 2 * math.pi / 48),
          z + r * math.sin(i * 2 * math.pi / 48),
        ),
    ], true);

  static List<Triangle3D> _along(
    ArchitectWall wall,
    Path profile,
    double from,
    double to,
  ) {
    Vector3 map(Vector3 v) {
      final p =
          wall.centerStart + wall.normalVector * v.x + wall.unitVector * v.z;
      return Vector3(p.dx, p.dy, v.y);
    }

    return [
      for (final t in ArchitectPathSolid.extrude(
        profile,
        from,
        to,
        ArchitectMaterial.timber.color,
      ))
        Triangle3D(v0: map(t.v0), v1: map(t.v1), v2: map(t.v2), color: t.color),
    ];
  }

  static List<Triangle3D> _vertical(
    ArchitectWall wall,
    Path local,
    double bottom,
    double top,
  ) {
    Vector3 map(Vector3 v) {
      final p =
          wall.centerStart + wall.unitVector * v.x + wall.exteriorNormal * v.y;
      return Vector3(p.dx, p.dy, v.z);
    }

    final reverse = wall.exteriorSign < 0;
    return [
      for (final t in ArchitectPathSolid.extrude(
        local,
        bottom,
        top,
        ArchitectMaterial.steel.color,
      ))
        Triangle3D(
          v0: map(t.v0),
          v1: map(reverse ? t.v2 : t.v1),
          v2: map(reverse ? t.v1 : t.v2),
          color: t.color,
        ),
    ];
  }

  static List<Triangle3D> _band(
    ArchitectWall wall,
    double from,
    double to,
    double low,
    double high,
    double bottom,
    double top,
  ) => _vertical(
    wall,
    Path()..addRect(Rect.fromLTRB(from, low, to, high)),
    bottom,
    top,
  );

  static List<(double, double, double, double)> _openings(
    ArchitectWall wall,
    Set<String> suppressed,
  ) => [
    for (final d in wall.doors.where((d) => !suppressed.contains(d.id)))
      (
        d.offsetRatio * wall.length - d.width / 2,
        d.offsetRatio * wall.length + d.width / 2,
        d.sillHeight,
        d.sillHeight + d.height,
      ),
    for (final w in wall.windows.where((w) => !suppressed.contains(w.id)))
      (
        w.offsetRatio * wall.length - w.width / 2,
        w.offsetRatio * wall.length + w.width / 2,
        w.sillHeight,
        w.sillHeight + w.height,
      ),
  ];
}
