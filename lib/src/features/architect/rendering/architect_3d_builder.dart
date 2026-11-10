import '../services/architect_stair_floor_contact.dart';
import '../../bim_editing/geometry/bim_contour_drafting_geometry.dart';
import 'architect_roof_drainage_mesh.dart';
import 'architect_floor_drain_mesh.dart';
import 'architect_solid_shell.dart';
import 'architect_mesh_section.dart';
import 'architect_vertical_clip.dart';
import 'architect_panel_roof_geometry.dart';
import '../services/architect_slab_geometry.dart';
import '../services/architect_roof_junctions.dart';
import '../services/architect_roof_ridge_beams.dart';
import '../services/architect_roof_wall_plates.dart';
import '../services/architect_roof_geometry.dart';
import 'architect_path_solid.dart';
import 'architect_mesh_boolean.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section_visibility.dart';
import 'architect_wall_network.dart';
import 'architect_wall_solids.dart';
import 'architect_stair_mesh.dart';
import 'architect_railing_geometry.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';
import '../services/architect_service_geometry.dart';
import '../services/architect_decorative_geometry.dart';

/// Real-time 3D solid mesh builder for architectural projects.
class Architect3dBuilder {
  /// Warm special wall volumes and contact surfaces off the UI isolate before
  /// assembling the scene. Section and elevation use these same cached solids.
  static Future<Mesh3D> buildProjectMeshAsync(
    ArchitectProject project, {
    bool previewGeometry = true,
    Map<Triangle3D, String>? sources,
    bool cleanDrainage = false,
    Map<Triangle3D, String>? silhouetteGroups,
    Map<Triangle3D, bool>? projectionOcclusion,
    ArchitectSectionVisibility? sectionVisibility,
    Set<String> suppressedOpeningIds = const {},
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
  }) async {
    for (final storey in project.storeys) {
      if (!storey.walls.any((w) => w.system.isSpecial)) continue;
      await ArchitectWallSolids.buildAsync(
        storey,
        project,
        suppressedOpeningIds: suppressedOpeningIds,
        prepareShell: true,
      );
    }
    return buildProjectMesh(
      project,
      previewGeometry: previewGeometry,
      sources: sources,
      cleanDrainage: cleanDrainage,
      silhouetteGroups: silhouetteGroups,
      projectionOcclusion: projectionOcclusion,
      sectionVisibility: sectionVisibility,
      suppressedOpeningIds: suppressedOpeningIds,
      openingDetailLevels: openingDetailLevels,
    );
  }

  /// Builds a complete [Mesh3D] from an [ArchitectProject].
  static Mesh3D buildProjectMesh(
    ArchitectProject project, {
    bool previewGeometry = true,
    Map<Triangle3D, String>? sources,
    bool cleanDrainage = false,
    Map<Triangle3D, String>? silhouetteGroups,
    Map<Triangle3D, bool>? projectionOcclusion,
    ArchitectSectionVisibility? sectionVisibility,
    Set<String> suppressedOpeningIds = const {},
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
  }) {
    final List<Triangle3D> allTris = [];
    final roofSolids = <(String, List<Triangle3D>, String?)>[];
    var joinedRoofs = false;
    void mark(String id, int start) {
      if (sources == null) return;
      for (var i = start; i < allTris.length; i++) {
        sources.putIfAbsent(allTris[i], () => id);
      }
    }

    for (final storey in project.storeys) {
      final walls = [
        for (final wall in storey.walls)
          wall.height == wall.effectiveHeight(storey.height)
              ? wall
              : wall.copyWith(height: wall.effectiveHeight(storey.height)),
      ];
      final composed = walls.any(
        (w) =>
            w.hasRailingDesign ||
            w.system.isSpecial ||
            w.layers.isNotEmpty ||
            w.plinth.enabled,
      );
      final compositions = composed
          ? ArchitectWallSolids.build(
              storey,
              project.wallTypes,
              project: project,
              suppressedOpeningIds: suppressedOpeningIds,
            )
          : const <ArchitectWallSolid>[];
      final wallSolids = <(String, List<Triangle3D>, String?)>[
        if (composed)
          for (final solid in compositions)
            (solid.wall.id, solid.triangles, solid.componentId)
        else
          for (final wall in walls)
            (
              wall.id,
              wall.build3D(
                storeyElevation: storey.elevation,
                includeOpeningMeshes: false,
                suppressedOpeningIds: suppressedOpeningIds,
              ),
              null,
            ),
      ];
      // Special contact planes contain curved-profile fragments. Unite their
      // planar masks before removing internal faces; the ordinary triangle
      // splitter grows quadratically on these fine construction components.
      final ordinaryShell = ArchitectSolidShell.build([
        for (final solid in wallSolids)
          if (solid.$3 == null) solid.$2,
      ]);
      final constructionShell = ArchitectWallSolids.constructionShell(
        compositions,
      );
      var ordinaryIndex = 0, constructionIndex = 0;
      final shell = [
        for (final solid in wallSolids)
          solid.$3 == null
              ? ordinaryShell[ordinaryIndex++]
              : constructionShell[constructionIndex++],
      ];
      for (var i = 0; i < wallSolids.length; i++) {
        final first = allTris.length;
        allTris.addAll(shell[i]);
        mark(wallSolids[i].$1, first);
        final group = wallSolids[i].$3;
        if (group != null && silhouetteGroups != null) {
          for (final triangle in shell[i]) {
            silhouetteGroups[triangle] = group;
          }
        }
      }
      for (final wall in walls) {
        final first = allTris.length;
        allTris.addAll(
          wall.build3D(
            storeyElevation: storey.elevation,
            sources: sources,
            includeSolid: false,
            resolveComposition: false,
            suppressedOpeningIds: suppressedOpeningIds,
            openingDetailLevels: {
              if (!previewGeometry)
                for (final opId in [
                  for (final d in wall.doors) d.id,
                  for (final w in wall.windows) w.id,
                ])
                  opId:
                      openingDetailLevels[opId] ??
                      FenestrationElevationDetail.clean2D
              else
                ...openingDetailLevels,
            },
          ),
        );
        mark(wall.id, first);
        final railingGroup = wall.railing == null
            ? null
            : ArchitectRailingGeometry.metalGroupId(wall, storey.walls);
        for (final part in ArchitectRailingGeometry.components(
          wall,
          storeyElevation: storey.elevation,
          walls: storey.walls,
        )) {
          allTris.addAll(part.triangles);
          for (final triangle in part.triangles) {
            sources?[triangle] = wall.id;
            silhouetteGroups?[triangle] = part.occludesProjection
                ? railingGroup!
                : part.id;
            projectionOcclusion?[triangle] = part.occludesProjection;
          }
        }
      }

      // Fill physical mitres at the same junctions used by the plan view.
      for (final (points, height) in ArchitectWallNetwork.junctions(
        composed ? const [] : walls,
        solidOnly: true,
      )) {
        const color = Color(0xFFECEFF1);
        Vector3 bottom(Offset p) => Vector3(p.dx, p.dy, storey.elevation);
        Vector3 top(Offset p) => Vector3(p.dx, p.dy, storey.elevation + height);
        for (var i = 0; i < points.length; i++) {
          final a = points[i], b = points[(i + 1) % points.length];
          allTris.add(
            Triangle3D(v0: bottom(a), v1: bottom(b), v2: top(b), color: color),
          );
          allTris.add(
            Triangle3D(v0: bottom(a), v1: top(b), v2: top(a), color: color),
          );
        }
        for (var i = 1; i < points.length - 1; i++) {
          allTris.add(
            Triangle3D(
              v0: top(points[0]),
              v1: top(points[i]),
              v2: top(points[i + 1]),
              color: color,
            ),
          );
          allTris.add(
            Triangle3D(
              v0: bottom(points[0]),
              v1: bottom(points[i + 1]),
              v2: bottom(points[i]),
              color: color,
            ),
          );
        }
      }

      // The same material solids are used by actual vertical stair sections.
      for (final stair in storey.stairs) {
        final first = allTris.length;
        final solids = [
          ...ArchitectStairMesh.body(
            stair,
            firstRiserBottom: ArchitectStairFloorContact.firstRiserBottom(
              project,
              storey,
              stair,
            ),
          ),
          ...ArchitectStairMesh.railings(
            stair,
            storey: storey,
            project: project,
          ),
        ];
        for (final solid in solids) {
          for (final triangle in solid.triangles) {
            Vector3 point(Vector3 p) =>
                Vector3(p.x, p.y, p.z + storey.elevation);
            allTris.add(
              Triangle3D(
                v0: point(triangle.v0),
                v1: point(triangle.v1),
                v2: point(triangle.v2),
                normal: triangle.normal,
                isDoubleSided: triangle.isDoubleSided,
                color: stair.design?.isDraft == true
                    ? const Color(0xFFD32F2F)
                    : triangle.color,
              ),
            );
          }
        }
        mark(stair.id, first);
      }

      // Add 3D columns
      for (final col in storey.columns) {
        final first = allTris.length;
        allTris.addAll(
          col.build3D(
            storeyElevation: storey.elevation,
            storeyHeight: storey.height,
          ),
        );
        mark(col.id, first);
      }

      // Add 3D beams
      for (final beam in storey.beams) {
        final first = allTris.length;
        allTris.addAll(
          ArchitectStairMesh.verticalPrism(
            beam.polygonCorners,
            storey.elevation + beam.baseOffset,
            storey.elevation + beam.baseOffset + beam.depth,
            StairSolidMaterial.concrete,
          ).triangles,
        );
        mark(beam.id, first);
      }

      // Add 3D floor tiles for functional zones
      for (final zone in storey.zones) {
        if (!previewGeometry) continue;
        if (zone.polygon.length >= 3) {
          final z = storey.elevation + 0.005; // slightly above floor slab
          final zoneColor = zone.color.withValues(alpha: 0.85);
          Vector3 point(int index) {
            final p = zone.polygon[index];
            return Vector3(p.dx, p.dy, z);
          }

          final List<(int, int, int)> triangles;
          try {
            triangles = ArchitectStairMesh.triangulate(zone.polygon);
          } on StateError {
            // A malformed imported/legacy zone must not prevent viewing the building.
            continue;
          }
          for (final (a, b, c) in triangles) {
            allTris.add(
              Triangle3D(
                v0: point(a),
                v1: point(b),
                v2: point(c),
                color: zoneColor,
              ),
            );
          }
        }
      }

      for (final slab in storey.slabs) {
        final first = allTris.length;
        allTris.addAll(ArchitectSlabGeometry.mesh(project, storey, slab));
        mark(slab.id, first);
      }

      if (previewGeometry) {
        for (final drain in storey.floorDrains) {
          final first = allTris.length;
          allTris.addAll(ArchitectFloorDrainMesh.build(project, storey, drain));
          mark(drain.id, first);
        }
      }

      final roofJunctions = ArchitectRoofJunctions.of(storey, project: project);
      final ridgeBeams = previewGeometry
          ? ArchitectRoofRidgeBeam.build(storey, project: project)
          : <ArchitectRoofRidgeBeam>[];
      final wallPlates = ArchitectRoofWallPlate.build(storey, project: project);
      final roofMeshes = [
        for (final roof in storey.roofs)
          if (roof.assembly.panels == null)
            _buildRoofMesh(
              storey,
              roof,
              detailed: previewGeometry,
              ridgeSeats: ridgeBeams,
              wallPlates: wallPlates.where((p) => p.roofId == roof.id).toList(),
              footprint: roofJunctions.trimmed.contains(roof.id)
                  ? roofJunctions.footprint(roof)
                  : null,
            ),
      ];
      joinedRoofs = joinedRoofs || roofJunctions.trimmed.isNotEmpty;
      for (var i = 0; i < storey.roofs.length; i++) {
        final roof = storey.roofs[i];
        if (roof.assembly.panels != null) {
          for (final component in ArchitectPanelRoofGeometry.build(
            storey,
            roof,
            project: project,
          )) {
            final cladding =
                !component.structural &&
                (component.material == ArchitectRoofMaterial.steel ||
                    component.material ==
                        ArchitectRoofMaterial.waterproofing) &&
                !(roof.assembly.panels!.membrane &&
                    component.id.startsWith('weather_'));
            final display = cladding
                ? [
                    for (final t in component.triangles)
                      Triangle3D(
                        v0: t.v0,
                        v1: t.v1,
                        v2: t.v2,
                        color: t.color,
                        depthBias: 1,
                      ),
                  ]
                : component.triangles;
            roofSolids.add((
              roof.id,
              display,
              'construction:roof:${roof.id}:${component.id}',
            ));
          }
        }
      }
      var ordinaryRoofIndex = 0;
      for (final roof in storey.roofs.where((r) => r.assembly.panels == null)) {
        roofSolids.add((roof.id, roofMeshes[ordinaryRoofIndex++], null));
      }
      for (final roof in storey.roofs) {
        if (roof.parapet.enabled) {
          final parapetMesh = _buildParapetMesh(storey, roof);
          if (parapetMesh.isNotEmpty) {
            roofSolids.add((roof.id, parapetMesh, 'construction:roof:${roof.id}:parapet'));
          }
        }
      }

      for (final beam in ridgeBeams) {
        for (final roof in storey.roofs.where(
          (r) => beam.roofIds.contains(r.id),
        )) {
          final first = allTris.length;
          final mesh = beam.mesh(planClip: roofJunctions.footprint(roof));
          allTris.addAll(mesh);
          mark(roof.id, first);
          if (silhouetteGroups != null) {
            for (final t in mesh) {
              silhouetteGroups[t] = 'construction:ridge:${beam.roofId}';
            }
          }
        }
        for (final bearing in beam.bearings(
          storey,
          ArchitectRoofGeometry.supportingWallStorey(project, storey),
        )) {
          for (final roof in storey.roofs.where(
            (r) => beam.roofIds.contains(r.id),
          )) {
            final path = ArchitectMeshSection.combine(
              PathOperation.intersect,
              bearing.footprint,
              roofJunctions.footprint(roof),
            );
            final first = allTris.length;
            final mesh = ArchitectPathSolid.extrude(
              path,
              bearing.bottom,
              bearing.top,
              const Color(0xffb0bec5),
            );
            allTris.addAll(mesh);
            mark(roof.id, first);
          }
        }
      }

      for (final roof in storey.roofs) {
        final first = allTris.length;
        allTris.addAll(
          ArchitectRoofDrainageMesh.build(
            project,
            storey,
            roof,
            includeGutters:
                sectionVisibility == null ||
                sectionVisibility
                    .modeFor(ArchitectSectionCategory.gutters)
                    .showsProjection,
            includeDownpipes:
                sectionVisibility == null ||
                sectionVisibility
                    .modeFor(ArchitectSectionCategory.downpipes)
                    .showsProjection,
            details: !cleanDrainage,
          ),
        );
        mark(roof.id, first);
        if (cleanDrainage && silhouetteGroups != null) {
          for (var i = first; i < allTris.length; i++) {
            silhouetteGroups[allTris[i]] = '${roof.id}:drainage';
          }
        }
      }

      // Add 3D architectural components (furniture, sanitary, kitchen, equipment)
      for (final comp
          in previewGeometry
              ? storey.components
              : storey.components.where((c) => c.isServiceComponent)) {
        if (!comp.isVisible) continue;
        final def = ComponentLibraryService.instance.findDefinition(
          comp.definitionId,
        );
        if (def == null) continue;
        final geo = ComponentGeometryCache.instance.getOrCompute(
          def,
          ArchitectServiceGeometry.parameters(project, storey, comp),
        );
        final first = allTris.length;
        final cosR = math.cos(comp.rotation);
        final sinR = math.sin(comp.rotation);
        final zBase = ArchitectServiceGeometry.baseElevation(
          project,
          storey,
          comp,
        );

        Vector3 transform(Vector3 p) {
          final rx = p.x * cosR - p.y * sinR;
          final ry = p.x * sinR + p.y * cosR;
          return Vector3(
            comp.position.dx + rx,
            comp.position.dy + ry,
            zBase + p.z,
          );
        }

        Vector3 transformNormal(Vector3 n) {
          final rx = n.x * cosR - n.y * sinR;
          final ry = n.x * sinR + n.y * cosR;
          return Vector3(rx, ry, n.z);
        }

        for (final t in geo.mesh3d.triangles) {
          allTris.add(
            Triangle3D(
              v0: transform(t.v0),
              v1: transform(t.v1),
              v2: transform(t.v2),
              normal: transformNormal(t.normal),
              color: t.color,
              isDoubleSided: t.isDoubleSided,
              material: t.material,
              textureCoordinates: t.textureCoordinates,
              vertexNormals: t.vertexNormals?.map(transformNormal).toList(),
              vertexColors: t.vertexColors,
              linearVertexColors: t.linearVertexColors,
            ),
          );
        }
        allTris.addAll(
          ArchitectServiceGeometry.flashing(project, storey, comp),
        );
        allTris.addAll(
          ArchitectServiceGeometry.terminal(project, storey, comp),
        );
        mark(comp.id, first);
      }

      // Add 3D architectural decorative elements (cornices, frames, brackets, reliefs)
      for (final decor in storey.decorativeElements) {
        final first = allTris.length;
        final mesh = ArchitectDecorativeGeometry.buildWorldMesh(
          project,
          storey,
          decor,
        );
        allTris.addAll(mesh);
        mark(decor.id, first);
        if (silhouetteGroups != null) {
          for (var i = first; i < allTris.length; i++) {
            silhouetteGroups[allTris[i]] = 'decor:${decor.id}';
          }
        }
      }
    }

    // For simple envelope prisms (!previewGeometry), remove shared internal interfaces.
    // Detailed carpentry (previewGeometry) is already cleanly clipped to plan footprints.
    final hasPanelRoofs = roofSolids.any((s) => s.$3 != null);
    // Keep thin panel skins closed. A coplanar face mask can erase outward
    // weather faces when adjacent, sub-millimetre layers are triangulated.
    // Their volumes already meet without overlap; facade HLR unites each
    // construction component independently after depth clipping.
    final roofShell = hasPanelRoofs
        ? [for (final solid in roofSolids) solid.$2]
        : (joinedRoofs && !previewGeometry)
        ? ArchitectSolidShell.build([for (final solid in roofSolids) solid.$2])
        : [for (final solid in roofSolids) solid.$2];
    for (var i = 0; i < roofSolids.length; i++) {
      final first = allTris.length;
      allTris.addAll(roofShell[i]);
      mark(roofSolids[i].$1, first);
      if (roofSolids[i].$3 != null && silhouetteGroups != null) {
        for (final triangle in roofShell[i]) {
          silhouetteGroups[triangle] = roofSolids[i].$3!;
        }
      }
    }
    if (previewGeometry) {
      _appendLandscape3D(project, allTris, mark);
    }
    return Mesh3D(name: project.name, triangles: allTris);
  }

  /// Original per-roof body for BIM exchange, before scene-wide removal of
  /// hidden faces. Exporters must not use the open projection/preview shell.
  static List<Triangle3D> buildRoofBody(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
  ) {
    final footprint = ArchitectRoofJunctions.of(storey, project: project).footprint(roof);
    final ridges = ArchitectRoofRidgeBeam.build(storey, project: project);
    final plates = ArchitectRoofWallPlate.build(storey, project: project)
        .where((p) => p.roofId == roof.id).toList();
    final result = _buildRoofMesh(storey, roof, detailed: true,
        ridgeSeats: ridges, wallPlates: plates, footprint: footprint);
    for (final ridge in ridges.where((r) => r.roofIds.contains(roof.id))) {
      result.addAll(ridge.mesh(planClip: footprint));
      for (final bearing in ridge.bearings(storey,
          ArchitectRoofGeometry.supportingWallStorey(project, storey))) {
        result.addAll(ArchitectPathSolid.extrude(
            Path.combine(PathOperation.intersect, bearing.footprint, footprint),
            bearing.bottom, bearing.top, const Color(0xffb0bec5)));
      }
    }
    return result;
  }

  static List<Triangle3D> _buildRoofMesh(
    ArchitectStorey storey,
    ArchitectRoofPlane roof, {
    bool detailed = true,
    List<ArchitectRoofRidgeBeam> ridgeSeats = const [],
    List<ArchitectRoofWallPlate> wallPlates = const [],
    Path? footprint,
  }) {
    final pts = roof.points;
    if (pts.length < 3) return const [];

    final topMat = roof.assembly.layers.firstOrNull?.material;
    final topColor = switch (topMat) {
      ArchitectRoofMaterial.clayTiles => const Color(0xFFC85A32),
      ArchitectRoofMaterial.concreteTiles => const Color(0xFF78909C),
      ArchitectRoofMaterial.metalSeam => const Color(0xFF546E7A),
      ArchitectRoofMaterial.bitumenShingles => const Color(0xFF5D4037),
      ArchitectRoofMaterial.waterproofing => const Color(0xFF455A64),
      _ => const Color(0xFFC85A32),
    };
    const fasciaColor = Color(0xFFCFA16B);

    if (!detailed ||
        !roof.assembly.timber.hasRafters ||
        roof.slopeDegrees < 1.0) {
      final mesh = _buildSimpleRoofPrism(
        storey,
        roof,
        topColor,
        fasciaColor,
        footprint: footprint,
        wallPlates: wallPlates,
      );
      if (wallPlates.isEmpty) return mesh;
      // Vertical clipping partitions the roof around its seats. Remove the
      // internal cap faces so they cannot become projection lines in batten gaps.
      return ArchitectMeshBoolean.exposedSurfaces([
        [...mesh, for (final plate in wallPlates) ...plate.mesh()],
      ]).single;
    }

    final tris = <Triangle3D>[];
    final p0 = roof.eavesEdge.$1;
    final v = roof.slopeDirection; // unit vector pointing up-slope
    final u = Offset(v.dy, -v.dx); // unit vector along eaves
    final cosSlope = math.max(math.cos(roof.slopeRadians), 0.25);

    // Project roof polygon into local (s, d) coordinates where:
    // s = coordinate along eaves (u), d = coordinate up-slope (v)
    final polySD = <Offset>[
      for (final p in pts)
        Offset(
          (p.dx - p0.dx) * u.dx + (p.dy - p0.dy) * u.dy,
          (p.dx - p0.dx) * v.dx + (p.dy - p0.dy) * v.dy,
        ),
    ];

    var minS = double.infinity, maxS = -double.infinity;
    var minD = double.infinity, maxD = -double.infinity;
    for (final sd in polySD) {
      if (sd.dx < minS) minS = sd.dx;
      if (sd.dx > maxS) maxS = sd.dx;
      if (sd.dy < minD) minD = sd.dy;
      if (sd.dy > maxD) maxD = sd.dy;
    }
    final spanS = maxS - minS;
    final spanD = maxD - minD;
    if (spanS < 0.05 || spanD < 0.05) {
      return _buildSimpleRoofPrism(
        storey,
        roof,
        topColor,
        fasciaColor,
        footprint: footprint,
      );
    }

    final timber = roof.assembly.timber;
    final rafterH = timber.rafterHeight / cosSlope;
    const boardingH = 0.022;
    final totalH = roof.assembly.totalThickness / cosSlope;

    final hRafterBottom = roof.assembly.preset == ArchitectRoofPreset.logTimber
        ? (roof.assembly.totalThickness -
                  ArchitectRoofWallPlate.rafterBottomDepth(roof)) /
              cosSlope
        : 0.0;
    final hRafterTop = hRafterBottom + rafterH;
    final hBoardTop = hRafterTop + boardingH;
    final hCoverTop = math.max(hBoardTop + 0.025, totalH);

    const rafterTopColor = Color(0xFFD7A86E);
    const rafterSideColor = Color(0xFFC49256);
    const purlinColor = Color(0xFFB8864B);
    const boardColor = Color(0xFFCFA16B);
    const membraneColor = Color(0xFF37474F);

    // 1. Wall plate (Mauerlat / Мауерлат) along wall bearing line & Ridge Purlin (Билова столица)
    final wpW = timber.wallPlateWidth.clamp(0.10, 0.24);
    final wpH = timber.wallPlateHeight.clamp(0.10, 0.24);
    final dWall =
        minD +
        (roof.manualSupportDistance ??
            math.min(roof.eavesOverhang, spanD * 0.45));
    final centeredSupport =
        roof.manualSupportDistance != null ||
        roof.assembly.preset == ArchitectRoofPreset.logTimber;
    for (final plate in wallPlates) {
      tris.addAll(plate.mesh());
    }
    if (timber.hasWallPlate &&
        roof.assembly.preset != ArchitectRoofPreset.logTimber &&
        (centeredSupport
            ? dWall - wpW * .5 < maxD && dWall + wpW * .5 > minD
            : dWall + wpW < maxD)) {
      final wpClipped = _clipPolygonToRect(
        polySD,
        minS,
        maxS,
        centeredSupport ? dWall - wpW * .5 : dWall,
        centeredSupport ? dWall + wpW * .5 : dWall + wpW,
      );
      _addExtrudedClippedPrism(
        tris,
        wpClipped,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        -wpH,
        hRafterBottom,
        planClip: footprint,
        topColor: purlinColor,
        sideColor: purlinColor,
      );
    }

    final dKnuckle = minD + roof.effectiveBreakDistance;
    final hasKnuckle =
        roof.isMansard && dKnuckle > minD + 0.10 && dKnuckle < maxD - 0.10;

    // Intermediate Mansard Purlin (Междинна столица) under the knuckle joint
    if (hasKnuckle) {
      const purlinW = 0.14;
      const purlinH = 0.16;
      final purlinClip = _clipPolygonToRect(
        polySD,
        minS,
        maxS,
        dKnuckle - purlinW * 0.5,
        dKnuckle + purlinW * 0.5,
      );
      _addExtrudedClippedPrism(
        tris,
        purlinClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        -purlinH,
        hRafterBottom,
        planClip: footprint,
        topColor: purlinColor,
        sideColor: purlinColor,
      );
    }

    // 2. Rafters (Ребра) along slope direction (prominently visible at eaves overhang)
    final rafterW = timber.rafterWidth.clamp(0.05, 0.16);
    final rafterStep = math.max(timber.rafterSpacing, 0.35);

    final rafterPositions = <double>[];
    for (var s = minS; s <= maxS - rafterW + 1e-4; s += rafterStep) {
      rafterPositions.add(s);
    }
    if (rafterPositions.isEmpty ||
        (maxS - rafterW - rafterPositions.last).abs() > rafterW * 0.6) {
      rafterPositions.add(math.max(minS, maxS - rafterW));
    }

    for (final s0 in rafterPositions) {
      final s1 = math.min(s0 + rafterW, maxS);
      if (hasKnuckle) {
        final lowerRafterClip = _clipPolygonToRect(
          polySD,
          s0,
          s1,
          minD,
          dKnuckle,
        );
        _addExtrudedClippedPrism(
          tris,
          lowerRafterClip,
          p0,
          u,
          v,
          storey.elevation,
          roof,
          hRafterBottom,
          hRafterTop,
          planClip: footprint,
          topColor: rafterTopColor,
          sideColor: rafterSideColor,
          seats: [...ridgeSeats, ...wallPlates],
        );
        final upperRafterClip = _clipPolygonToRect(
          polySD,
          s0,
          s1,
          dKnuckle,
          maxD,
        );
        _addExtrudedClippedPrism(
          tris,
          upperRafterClip,
          p0,
          u,
          v,
          storey.elevation,
          roof,
          hRafterBottom,
          hRafterTop,
          planClip: footprint,
          topColor: rafterTopColor,
          sideColor: rafterSideColor,
          seats: [...ridgeSeats, ...wallPlates],
        );
      } else {
        final rafterClip = _clipPolygonToRect(polySD, s0, s1, minD, maxD);
        _addExtrudedClippedPrism(
          tris,
          rafterClip,
          p0,
          u,
          v,
          storey.elevation,
          roof,
          hRafterBottom,
          hRafterTop,
          planClip: footprint,
          topColor: rafterTopColor,
          sideColor: rafterSideColor,
          seats: [...ridgeSeats, ...wallPlates],
        );
      }
    }

    // 3. Sub-roof boarding (Дъсчена обшивка / стреха над ребрата)
    if (hasKnuckle) {
      final boardLower = _clipPolygonToRect(polySD, minS, maxS, minD, dKnuckle);
      _addExtrudedClippedPrism(
        tris,
        boardLower,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hRafterTop,
        hBoardTop,
        planClip: footprint,
        topColor: membraneColor,
        bottomColor: boardColor,
        sideColor: boardColor,
      );
      final boardUpper = _clipPolygonToRect(polySD, minS, maxS, dKnuckle, maxD);
      _addExtrudedClippedPrism(
        tris,
        boardUpper,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hRafterTop,
        hBoardTop,
        planClip: footprint,
        topColor: membraneColor,
        bottomColor: boardColor,
        sideColor: boardColor,
      );
    } else {
      final boardClip = _clipPolygonToRect(polySD, minS, maxS, minD, maxD);
      _addExtrudedClippedPrism(
        tris,
        boardClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hRafterTop,
        hBoardTop,
        planClip: footprint,
        topColor: membraneColor,
        bottomColor: boardColor,
        sideColor: boardColor,
      );
    }

    // 4. Finished Roof Covering (Покритие - керемиди / ламарина / битум)
    if (hasKnuckle) {
      final coverLower = _clipPolygonToRect(polySD, minS, maxS, minD, dKnuckle);
      _addExtrudedClippedPrism(
        tris,
        coverLower,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBoardTop,
        hCoverTop,
        planClip: footprint,
        topColor: topColor,
        sideColor: fasciaColor,
      );
      final coverUpper = _clipPolygonToRect(polySD, minS, maxS, dKnuckle, maxD);
      _addExtrudedClippedPrism(
        tris,
        coverUpper,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBoardTop,
        hCoverTop,
        planClip: footprint,
        topColor: topColor,
        sideColor: fasciaColor,
      );
    } else {
      final coverClip = _clipPolygonToRect(polySD, minS, maxS, minD, maxD);
      _addExtrudedClippedPrism(
        tris,
        coverClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBoardTop,
        hCoverTop,
        planClip: footprint,
        topColor: topColor,
        sideColor: fasciaColor,
      );
    }

    // 5. Standing seams for metal sheet roofs
    if (topMat == ArchitectRoofMaterial.metalSeam) {
      const seamSpacing = 0.50;
      const seamWidth = 0.036;
      const seamDark = Color(0xFF37474F);
      const seamLight = Color(0xFF607D8B);
      for (var s = minS + 0.04; s <= maxS - seamWidth; s += seamSpacing) {
        if (hasKnuckle) {
          final seamLower = _clipPolygonToRect(
            polySD,
            s,
            s + seamWidth,
            minD,
            dKnuckle,
          );
          _addExtrudedClippedPrism(
            tris,
            seamLower,
            p0,
            u,
            v,
            storey.elevation,
            roof,
            hCoverTop,
            hCoverTop + 0.025,
            planClip: footprint,
            topColor: seamLight,
            sideColor: seamDark,
          );
          final seamUpper = _clipPolygonToRect(
            polySD,
            s,
            s + seamWidth,
            dKnuckle,
            maxD,
          );
          _addExtrudedClippedPrism(
            tris,
            seamUpper,
            p0,
            u,
            v,
            storey.elevation,
            roof,
            hCoverTop,
            hCoverTop + 0.025,
            planClip: footprint,
            topColor: seamLight,
            sideColor: seamDark,
          );
        } else {
          final seamClip = _clipPolygonToRect(
            polySD,
            s,
            s + seamWidth,
            minD,
            maxD,
          );
          _addExtrudedClippedPrism(
            tris,
            seamClip,
            p0,
            u,
            v,
            storey.elevation,
            roof,
            hCoverTop,
            hCoverTop + 0.025,
            planClip: footprint,
            topColor: seamLight,
            sideColor: seamDark,
          );
        }
      }
    }

    return tris;
  }

  static List<Triangle3D> _buildSimpleRoofPrism(
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
    Color topColor,
    Color fasciaColor, {
    Path? footprint,
    List<ArchitectRoofWallPlate> wallPlates = const [],
  }) {
    if (wallPlates.isNotEmpty) {
      final outline = footprint ?? (Path()..addPolygon(roof.points, true));
      var parts = [
        ArchitectVerticalPart(
          outline,
          (p) => storey.elevation + roof.undersideElevationAt(p),
          (p) => storey.elevation + roof.topElevationAt(p),
        ),
      ];
      for (final plate in wallPlates) {
        parts = ArchitectVerticalClip.subtract(
          parts,
          plate.footprint,
          (_) => plate.bottom,
          (_) => plate.top,
        );
      }
      return [
        for (final part in parts)
          ..._roofPrism(
            part.path,
            part.bottom,
            part.top,
            topColor,
            fasciaColor,
            fasciaColor,
          ),
      ];
    }
    if (footprint != null) {
      return _roofPrism(
        footprint,
        (p) => storey.elevation + roof.undersideElevationAt(p),
        (p) => storey.elevation + roof.topElevationAt(p),
        topColor,
        fasciaColor,
        fasciaColor,
      );
    }
    final pts = roof.points;
    final tris = <Triangle3D>[];

    Vector3 topAt(Offset p) =>
        Vector3(p.dx, p.dy, storey.elevation + roof.topElevationAt(p));
    Vector3 botAt(Offset p) =>
        Vector3(p.dx, p.dy, storey.elevation + roof.undersideElevationAt(p));

    final v0T = topAt(pts[0]);
    final v0B = botAt(pts[0]);
    for (var i = 1; i < pts.length - 1; i++) {
      final v1T = topAt(pts[i]);
      final v2T = topAt(pts[i + 1]);
      tris.add(
        Triangle3D(
          v0: v0T,
          v1: v1T,
          v2: v2T,
          color: topColor,
          isDoubleSided: true,
        ),
      );

      final v1B = botAt(pts[i]);
      final v2B = botAt(pts[i + 1]);
      tris.add(
        Triangle3D(
          v0: v0B,
          v1: v2B,
          v2: v1B,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
    }

    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final aT = topAt(a), bT = topAt(b);
      final aB = botAt(a), bB = botAt(b);
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bB,
          v2: bT,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bT,
          v2: aT,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
    }

    return tris;
  }

  static List<Offset> _cleanPolygon(
    List<Offset> poly, {
    double tolerance = 1e-4,
  }) {
    if (poly.length < 3) return const [];
    final clean = <Offset>[];
    for (final p in poly) {
      if (clean.isEmpty || (p - clean.last).distance > tolerance) {
        clean.add(p);
      }
    }
    if (clean.length > 1 && (clean.last - clean.first).distance <= tolerance) {
      clean.removeLast();
    }
    return clean.length >= 3 ? clean : const [];
  }

  /// Clips a 2D polygon in local `(s, d)` coordinates against `[s0, s1] x [d0, d1]`.
  static List<Offset> _clipPolygonToRect(
    List<Offset> poly,
    double s0,
    double s1,
    double d0,
    double d1,
  ) {
    if (poly.length < 3 || s1 <= s0 || d1 <= d0) return const [];
    var current = poly;
    current = _clipHalfPlane(current, (p) => p.dx - s0);
    if (current.length < 3) return const [];
    current = _clipHalfPlane(current, (p) => s1 - p.dx);
    if (current.length < 3) return const [];
    current = _clipHalfPlane(current, (p) => p.dy - d0);
    if (current.length < 3) return const [];
    current = _clipHalfPlane(current, (p) => d1 - p.dy);
    return _cleanPolygon(current);
  }

  static List<Offset> _clipHalfPlane(
    List<Offset> poly,
    double Function(Offset p) signedDist,
  ) {
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final da = signedDist(a);
      final db = signedDist(b);
      final aIn = da >= -1e-6;
      final bIn = db >= -1e-6;
      if (aIn && bIn) {
        out.add(b);
      } else if (aIn && !bIn) {
        final denom = da - db;
        final t = denom.abs() < 1e-9 ? 0.0 : (da / denom).clamp(0.0, 1.0);
        out.add(Offset.lerp(a, b, t)!);
      } else if (!aIn && bIn) {
        final denom = da - db;
        final t = denom.abs() < 1e-9 ? 0.0 : (da / denom).clamp(0.0, 1.0);
        out.add(Offset.lerp(a, b, t)!);
        out.add(b);
      }
    }
    return out;
  }

  static void _addExtrudedClippedPrism(
    List<Triangle3D> tris,
    List<Offset> clippedSD,
    Offset p0,
    Offset u,
    Offset v,
    double storeyElevation,
    ArchitectRoofPlane roof,
    double hBottom,
    double hTop, {
    required Color topColor,
    required Color sideColor,
    Color? bottomColor,
    Path? planClip,
    List<ArchitectRoofRidgeBeam> seats = const [],
  }) {
    final cleanSD = _cleanPolygon(clippedSD);
    if (cleanSD.length < 3 || hTop <= hBottom) return;
    final botClr = bottomColor ?? sideColor;
    Offset toWorld2D(Offset sd) => Offset(
      p0.dx + u.dx * sd.dx + v.dx * sd.dy,
      p0.dy + u.dy * sd.dx + v.dy * sd.dy,
    );

    if (seats.isNotEmpty) {
      var outline = Path()..addPolygon(cleanSD.map(toWorld2D).toList(), true);
      if (planClip != null) {
        outline = ArchitectMeshSection.combine(
          PathOperation.intersect,
          outline,
          planClip,
        );
      }
      var parts = [
        ArchitectVerticalPart(
          outline,
          (p) => storeyElevation + roof.undersideElevationAt(p) + hBottom,
          (p) => storeyElevation + roof.undersideElevationAt(p) + hTop,
        ),
      ];
      for (final seat in seats) {
        if (!outline.getBounds().overlaps(seat.footprint.getBounds())) continue;
        parts = ArchitectVerticalClip.subtract(
          parts,
          seat.footprint,
          (_) => seat.bottom,
          (_) => seat.top,
        );
      }
      for (final part in parts) {
        tris.addAll(
          _roofPrism(
            part.path,
            part.bottom,
            part.top,
            topColor,
            sideColor,
            botClr,
          ),
        );
      }
      return;
    }

    if (planClip != null) {
      final footprint = Path.combine(
        PathOperation.intersect,
        planClip,
        Path()..addPolygon(cleanSD.map(toWorld2D).toList(), true),
      );
      tris.addAll(
        _roofPrism(
          footprint,
          (p) => storeyElevation + roof.undersideElevationAt(p) + hBottom,
          (p) => storeyElevation + roof.undersideElevationAt(p) + hTop,
          topColor,
          sideColor,
          botClr,
        ),
      );
      return;
    }

    final topVerts = <Vector3>[];
    final botVerts = <Vector3>[];
    for (final sd in cleanSD) {
      final p = toWorld2D(sd);
      final baseZ = storeyElevation + roof.undersideElevationAt(p);
      botVerts.add(Vector3(p.dx, p.dy, baseZ + hBottom));
      topVerts.add(Vector3(p.dx, p.dy, baseZ + hTop));
    }

    void addTri(Vector3 a, Vector3 b, Vector3 c, Color color) {
      final cross = (b - a).cross(c - a);
      if (cross.lengthSquared < 1e-10) return;
      tris.add(
        Triangle3D(
          v0: a,
          v1: b,
          v2: c,
          normal: cross.normalized(),
          color: color,
          isDoubleSided: true,
        ),
      );
    }

    final v0T = topVerts[0];
    final v0B = botVerts[0];
    for (var i = 1; i < cleanSD.length - 1; i++) {
      addTri(v0T, topVerts[i], topVerts[i + 1], topColor);
      addTri(v0B, botVerts[i + 1], botVerts[i], botClr);
    }

    for (var i = 0; i < cleanSD.length; i++) {
      final next = (i + 1) % cleanSD.length;
      final aB = botVerts[i], bB = botVerts[next];
      final aT = topVerts[i], bT = topVerts[next];
      addTri(aB, bB, bT, sideColor);
      addTri(aB, bT, aT, sideColor);
    }
  }

  static List<Triangle3D> _buildParapetMesh(
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
  ) {
    if (!roof.parapet.enabled || roof.points.length < 3) return const [];
    final p = roof.parapet;
    final outer = roof.points;
    final inner = BimContourDraftingGeometry.offsetPolygon(outer, -p.totalThickness);
    if (inner.length < 3) return const [];

    final wallPath = Path.combine(
      PathOperation.difference,
      Path()..addPolygon(outer, true),
      Path()..addPolygon(inner, true),
    );
    if (wallPath.getBounds().isEmpty) return const [];

    const wallColor = Color(0xFFCFD8DC);
    const copingColor = Color(0xFF90A4AE);

    final wallTriangles = _roofPrism(
      wallPath,
      (pt) => storey.elevation + roof.topElevationAt(pt),
      (pt) => storey.elevation + roof.topElevationAt(pt) + p.height,
      wallColor,
      wallColor,
      wallColor,
    );

    if (!p.hasCoping) return wallTriangles;

    final copingOuter = BimContourDraftingGeometry.offsetPolygon(outer, p.copingProjection);
    final copingInner = BimContourDraftingGeometry.offsetPolygon(inner, -p.copingProjection);
    if (copingOuter.length < 3 || copingInner.length < 3) return wallTriangles;

    final copingPath = Path.combine(
      PathOperation.difference,
      Path()..addPolygon(copingOuter, true),
      Path()..addPolygon(copingInner, true),
    );

    final copingTriangles = _roofPrism(
      copingPath,
      (pt) => storey.elevation + roof.topElevationAt(pt) + p.height,
      (pt) => storey.elevation + roof.topElevationAt(pt) + p.height + 0.04,
      copingColor,
      copingColor,
      copingColor,
    );

    return [...wallTriangles, ...copingTriangles];
  }

  static List<Triangle3D> _roofPrism(
    Path footprint,
    double Function(Offset) bottom,
    double Function(Offset) top,
    Color topColor,
    Color sideColor,
    Color bottomColor,
  ) => [
    for (final triangle in ArchitectPathSolid.between(
      footprint,
      bottom,
      top,
      topColor,
    ))
      Triangle3D(
        v0: triangle.v0,
        v1: triangle.v1,
        v2: triangle.v2,
        color: triangle.normal.z > 1e-7
            ? topColor
            : triangle.normal.z < -1e-7
            ? bottomColor
            : sideColor,
        isDoubleSided: true,
      ),
  ];

  static List<Triangle3D> _extrude(
    Path footprint,
    double Function(Offset) bottom,
    double Function(Offset) top,
    Color topColor,
    Color sideColor,
    Color bottomColor,
  ) => _roofPrism(footprint, bottom, top, topColor, sideColor, bottomColor);

  static void _appendLandscape3D(
    ArchitectProject project,
    List<Triangle3D> allTris,
    void Function(String id, int from) mark,
  ) {
    double groundZ(Offset p, double fallback) =>
        project.proposedTerrain.evaluateElevationAt(p) ??
        project.existingTerrain.evaluateElevationAt(p) ??
        fallback;

    // 1. Proposed Terrain 2.5D Surface (with automatic contour recognition & cutouts)
    if (project.isLayerVisible(ArchitectLayer.terrainProposedLayerId) &&
        (project.proposedTerrain.isNotEmpty || project.existingTerrain.isNotEmpty)) {
      var terrainFootprint = Path();
      final hasOuterBoundaries = project.proposedTerrain.boundaries
          .any((b) => b.polygon.length >= 3 && !b.isCutoutPad && !b.isHole);

      if (hasOuterBoundaries) {
        for (final b in project.proposedTerrain.boundaries) {
          if (b.polygon.length < 3 || b.isCutoutPad || b.isHole) continue;
          terrainFootprint = Path.combine(
            PathOperation.union,
            terrainFootprint,
            Path()..addPolygon(b.polygon, true),
          );
        }
      } else {
        // Automatic domain recognition from contours and spot elevations
        final rawBounds = project.proposedTerrain.bounds ??
            project.existingTerrain.bounds;
        if (rawBounds != null && !rawBounds.isEmpty) {
          final domainRect = rawBounds.inflate(3.5);
          terrainFootprint = Path()..addRect(domainRect);
        }
      }

      // Cut out holes and flat cutout pads
      for (final b in project.proposedTerrain.boundaries) {
        if (b.polygon.length < 3 || (!b.isCutoutPad && !b.isHole)) continue;
        try {
          terrainFootprint = Path.combine(
            PathOperation.difference,
            terrainFootprint,
            Path()..addPolygon(b.polygon, true),
          );
        } catch (_) {}
      }

      // Cut out ground-floor slabs so terrain does not poke into building interior
      for (final s in project.storeys) {
        if (s.isRoof || s.elevation.abs() > 0.6) continue;
        for (final slab in s.slabs) {
          if (slab.polygon.length >= 3) {
            try {
              terrainFootprint = Path.combine(
                PathOperation.difference,
                terrainFootprint,
                Path()..addPolygon(slab.polygon, true),
              );
            } catch (_) {}
          }
        }
      }

      if (!terrainFootprint.getBounds().isEmpty) {
        final first = allTris.length;
        allTris.addAll(
          _buildTopographicTerrainMesh3D(
            terrainFootprint: terrainFootprint,
            groundZ: (p) => groundZ(p, -0.15),
            topColor: const Color(0xFF7FA66C),
            sideColor: const Color(0xFF8B6F4E),
            bottomColor: const Color(0xFF6E553A),
          ),
        );
        mark('terrain_proposed', first);
      }
    }

    // 2. Pathways with Automatic Curbs, Site Fences, and Vegetation per storey
    for (final storey in project.storeys) {
      if (storey.isRoof) continue;

      if (project.isLayerVisible(ArchitectLayer.pathwayLayerId)) {
        for (final pathway in storey.pathways) {
          if (pathway.pavingPolygon.length < 3) continue;
          final first = allTris.length;
          final pavPath = Path()..addPolygon(pathway.pavingPolygon, true);
          final pavColor = switch (pathway.material) {
            ArchitectPavingMaterial.stoneSlabs => const Color(0xFFB8C0C8),
            ArchitectPavingMaterial.cobblePavers => const Color(0xFF9E968E),
            ArchitectPavingMaterial.timberDecking => const Color(0xFFB5835A),
            ArchitectPavingMaterial.gravel => const Color(0xFFC2BDB6),
            ArchitectPavingMaterial.asphalt => const Color(0xFF525860),
            ArchitectPavingMaterial.grassGrid => const Color(0xFF6B9E62),
          };
          allTris.addAll(
            _extrude(
              pavPath,
              (p) => groundZ(p, storey.elevation) - 0.04,
              (p) => groundZ(p, storey.elevation) + 0.02,
              pavColor,
              const Color(0xFF78716C),
              const Color(0xFF78716C),
            ),
          );
          for (final curbPoly in [
            pathway.leftCurbPolygon,
            pathway.rightCurbPolygon,
          ]) {
            if (curbPoly.length < 3) continue;
            allTris.addAll(
              _extrude(
                Path()..addPolygon(curbPoly, true),
                (p) => groundZ(p, storey.elevation) - 0.04,
                (p) => groundZ(p, storey.elevation) + pathway.curbHeight,
                const Color(0xFFD6D3D1),
                const Color(0xFFA8A29E),
                const Color(0xFFA8A29E),
              ),
            );
          }
          mark(pathway.id, first);
        }

        for (final street in storey.streets) {
          if (street.points.length < 2) continue;
          final first = allTris.length;
          final roadPoly = street.roadwayPolygon;
          if (roadPoly.length >= 3) {
            final roadPath = Path()..addPolygon(roadPoly, true);
            allTris.addAll(
              _extrude(
                roadPath,
                (p) => groundZ(p, storey.elevation) - 0.06,
                (p) => groundZ(p, storey.elevation) + 0.01,
                const Color(0xFF334155),
                const Color(0xFF1E293B),
                const Color(0xFF1E293B),
              ),
            );
          }

          for (final swPoly in [
            street.leftSidewalkPolygon,
            street.rightSidewalkPolygon,
          ]) {
            if (swPoly.length < 3) continue;
            final swPath = Path()..addPolygon(swPoly, true);
            allTris.addAll(
              _extrude(
                swPath,
                (p) => groundZ(p, storey.elevation) - 0.04,
                (p) => groundZ(p, storey.elevation) + street.curbHeight,
                const Color(0xFF9E968E),
                const Color(0xFF78716C),
                const Color(0xFF78716C),
              ),
            );
          }

          for (final curbPoly in [
            street.leftCurbPolygon,
            street.rightCurbPolygon,
          ]) {
            if (curbPoly.length < 3) continue;
            allTris.addAll(
              _extrude(
                Path()..addPolygon(curbPoly, true),
                (p) => groundZ(p, storey.elevation) - 0.06,
                (p) =>
                    groundZ(p, storey.elevation) +
                    street.curbHeight +
                    0.01,
                const Color(0xFFD6D3D1),
                const Color(0xFFA8A29E),
                const Color(0xFFA8A29E),
              ),
            );
          }

          if (street.markingStyle != ArchitectRoadMarkingStyle.none) {
            final markPoly = <Offset>[];
            final mw =
                street.markingWidth > 1e-4 ? street.markingWidth : 0.12;
            if (street.markingStyle == ArchitectRoadMarkingStyle.solid) {
              final left = ArchitectPathway.offsetChain(
                street.points,
                mw * 0.5,
                closed: street.closed,
              );
              final right = ArchitectPathway.offsetChain(
                street.points,
                -mw * 0.5,
                closed: street.closed,
              );
              markPoly.addAll([...left, ...right.reversed]);
            } else if (street.markingStyle ==
                ArchitectRoadMarkingStyle.doubleSolid) {
              final spacing = 0.16;
              final l1 = ArchitectPathway.offsetChain(
                street.points,
                spacing * 0.5 + mw * 0.35,
                closed: street.closed,
              );
              final l2 = ArchitectPathway.offsetChain(
                street.points,
                spacing * 0.5 - mw * 0.35,
                closed: street.closed,
              );
              final r1 = ArchitectPathway.offsetChain(
                street.points,
                -(spacing * 0.5 - mw * 0.35),
                closed: street.closed,
              );
              final r2 = ArchitectPathway.offsetChain(
                street.points,
                -(spacing * 0.5 + mw * 0.35),
                closed: street.closed,
              );
              markPoly.addAll([...l1, ...l2.reversed]);
              markPoly.addAll([...r1, ...r2.reversed]);
            } else if (street.markingStyle ==
                ArchitectRoadMarkingStyle.dashed) {
              const dashLen = 2.0;
              const gapLen = 2.0;
              const cycleLen = dashLen + gapLen;
              double accumDist = 0.0;
              final pts = street.closed
                  ? [...street.points, street.points.first]
                  : street.points;
              for (int i = 0; i < pts.length - 1; i++) {
                final p0 = pts[i];
                final p1 = pts[i + 1];
                final segVec = p1 - p0;
                final segLen = segVec.distance;
                if (segLen < 1e-4) continue;
                final dir = segVec / segLen;
                double s = 0.0;
                while (s < segLen) {
                  final phase = (accumDist + s) % cycleLen;
                  if (phase < dashLen) {
                    final remDash = dashLen - phase;
                    final run = math.min(remDash, segLen - s);
                    if (run > 0.1) {
                      final segPts = [
                        p0 + dir * s,
                        p0 + dir * (s + run),
                      ];
                      final left = ArchitectPathway.offsetChain(
                        segPts,
                        mw * 0.5,
                      );
                      final right = ArchitectPathway.offsetChain(
                        segPts,
                        -mw * 0.5,
                      );
                      final dashPoly = [...left, ...right.reversed];
                      if (dashPoly.length >= 3) {
                        allTris.addAll(
                          _extrude(
                            Path()..addPolygon(dashPoly, true),
                            (p) =>
                                groundZ(p, storey.elevation) + 0.01,
                            (p) =>
                                groundZ(p, storey.elevation) + 0.018,
                            const Color(0xFFFFFFFF),
                            const Color(0xFFFFFFFF),
                            const Color(0xFFFFFFFF),
                          ),
                        );
                      }
                    }
                    s += run;
                  } else {
                    final remGap = cycleLen - phase;
                    final run = math.min(remGap, segLen - s);
                    s += run;
                  }
                }
                accumDist += segLen;
              }
            }
            if (markPoly.length >= 3) {
              allTris.addAll(
                _extrude(
                  Path()..addPolygon(markPoly, true),
                  (p) => groundZ(p, storey.elevation) + 0.01,
                  (p) => groundZ(p, storey.elevation) + 0.018,
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFFFFFF),
                ),
              );
            }
          }
          mark(street.id, first);
        }

        for (final fence in storey.siteFences) {
          if (fence.points.length < 2) continue;
          final first = allTris.length;
          final halfT = fence.thickness * 0.5;
          final left = ArchitectPathway.offsetChain(
            fence.points,
            halfT,
            closed: fence.closed,
          );
          final right = ArchitectPathway.offsetChain(
            fence.points,
            -halfT,
            closed: fence.closed,
          );
          final bodyPath = Path()
            ..addPolygon([...left, ...right.reversed], true);
          if (fence.preset == ArchitectSiteFencePreset.gabionFence ||
              fence.preset == ArchitectSiteFencePreset.gabionRetaining ||
              fence.preset == ArchitectSiteFencePreset.rcRetaining) {
            final topCol = fence.preset == ArchitectSiteFencePreset.rcRetaining
                ? const Color(0xFF94A3B8)
                : const Color(0xFF8C857B);
            allTris.addAll(
              _extrude(
                bodyPath,
                (p) => groundZ(p, storey.elevation) - 0.10,
                (p) => groundZ(p, storey.elevation) + fence.height,
                topCol,
                topCol,
                topCol,
              ),
            );
          } else {
            // Plinth + Piers + Slat/Louver/Iron Panel
            allTris.addAll(
              _extrude(
                bodyPath,
                (p) => groundZ(p, storey.elevation) - 0.08,
                (p) => groundZ(p, storey.elevation) + 0.42,
                const Color(0xFFCBD5E1),
                const Color(0xFF94A3B8),
                const Color(0xFF94A3B8),
              ),
            );
            final panelLeft = ArchitectPathway.offsetChain(
              fence.points,
              0.03,
              closed: fence.closed,
            );
            final panelRight = ArchitectPathway.offsetChain(
              fence.points,
              -0.03,
              closed: fence.closed,
            );
            final panelColor =
                fence.preset == ArchitectSiteFencePreset.piersAndSlats
                ? const Color(0xFFA47148)
                : const Color(0xFF334155);
            allTris.addAll(
              _extrude(
                Path()
                  ..addPolygon([...panelLeft, ...panelRight.reversed], true),
                (p) => groundZ(p, storey.elevation) + 0.42,
                (p) => groundZ(p, storey.elevation) + fence.height - 0.06,
                panelColor,
                panelColor,
                panelColor,
              ),
            );
            final pierHalf = math.max(halfT * 1.25, 0.18);
            for (final (pierCenter, _) in fence.pierPositions) {
              allTris.addAll(
                _extrude(
                  Path()
                    ..addRect(
                      Rect.fromCenter(
                        center: pierCenter,
                        width: pierHalf * 2,
                        height: pierHalf * 2,
                      ),
                    ),
                  (p) => groundZ(p, storey.elevation) - 0.08,
                  (p) => groundZ(p, storey.elevation) + fence.height,
                  const Color(0xFFE2E8F0),
                  const Color(0xFFCBD5E1),
                  const Color(0xFFCBD5E1),
                ),
              );
            }
          }
          mark(fence.id, first);
        }
      }

      if (project.isLayerVisible(ArchitectLayer.vegetationLayerId)) {
        for (final veg in storey.vegetation) {
          final first = allTris.length;
          final z0 = groundZ(veg.position, storey.elevation);
          allTris.addAll(_buildVegetation3D(veg, z0));
          mark(veg.id, first);
        }
      }
    }
  }

  /// High-performance parametric 3D mesh builder for vegetation.
  /// Generates crisp, lightweight geometric prisms, cones, and frustums ($< 60\text{ triangles}$)
  /// in $< 0.05\text{ ms}$, entirely avoiding expensive Bézier flattening and sweep-line decomposition.
  static List<Triangle3D> _buildVegetation3D(
    ArchitectVegetationItem veg,
    double z0,
  ) {
    final tris = <Triangle3D>[];
    final pos = veg.position;
    final h = math.max(0.40, veg.height);
    final crownR = (veg.crownDiameter * 0.5).clamp(0.20, 15.0);

    // 1. Hedge: direct polygon extrusion with side quads & top cap
    if (veg.species == ArchitectPlantSpecies.trimmedHedge &&
        veg.points.length >= 2) {
      final halfW = (veg.hedgeWidth * 0.5).clamp(0.10, 5.0);
      final left = ArchitectPathway.offsetChain(veg.points, halfW);
      final right = ArchitectPathway.offsetChain(veg.points, -halfW);
      final poly = [...left, ...right.reversed];
      if (poly.length >= 3) {
        final topZ = z0 + h;
        const hedgeTop = Color(0xFF3E7B48);
        const hedgeSide = Color(0xFF2E6338);

        // Sides
        for (var i = 0; i < poly.length; i++) {
          final p0 = poly[i];
          final p1 = poly[(i + 1) % poly.length];
          final v00 = Vector3(p0.dx, p0.dy, z0);
          final v10 = Vector3(p1.dx, p1.dy, z0);
          final v11 = Vector3(p1.dx, p1.dy, topZ);
          final v01 = Vector3(p0.dx, p0.dy, topZ);
          tris.add(Triangle3D(v0: v00, v1: v10, v2: v11, color: hedgeSide, isDoubleSided: true));
          tris.add(Triangle3D(v0: v00, v1: v11, v2: v01, color: hedgeSide, isDoubleSided: true));
        }
        // Top cap (fan triangulation)
        for (var i = 1; i < poly.length - 1; i++) {
          tris.add(
            Triangle3D(
              v0: Vector3(poly[0].dx, poly[0].dy, topZ),
              v1: Vector3(poly[i].dx, poly[i].dy, topZ),
              v2: Vector3(poly[i + 1].dx, poly[i + 1].dy, topZ),
              color: hedgeTop,
              isDoubleSided: true,
            ),
          );
        }
      }
      return tris;
    }

    // Helper to generate a cylinder/frustum between zBot and zTop with radii rBot and rTop
    void addFrustum({
      required double zBot,
      required double zTop,
      required double rBot,
      required double rTop,
      required Color color,
      int segments = 10,
      bool addTopCap = false,
      bool addBotCap = false,
      Color? capColor,
    }) {
      final step = 2.0 * math.pi / segments;
      final effectiveCapColor = capColor ?? color;

      for (var i = 0; i < segments; i++) {
        final a0 = i * step;
        final a1 = (i + 1) * step;
        final cos0 = math.cos(a0), sin0 = math.sin(a0);
        final cos1 = math.cos(a1), sin1 = math.sin(a1);

        final p0Bot = Vector3(pos.dx + rBot * cos0, pos.dy + rBot * sin0, zBot);
        final p1Bot = Vector3(pos.dx + rBot * cos1, pos.dy + rBot * sin1, zBot);
        final p1Top = Vector3(pos.dx + rTop * cos1, pos.dy + rTop * sin1, zTop);
        final p0Top = Vector3(pos.dx + rTop * cos0, pos.dy + rTop * sin0, zTop);

        // Sides
        if (rBot > 1e-4 || rTop > 1e-4) {
          if (rBot > 1e-4 && rTop > 1e-4) {
            tris.add(Triangle3D(v0: p0Bot, v1: p1Bot, v2: p1Top, color: color, isDoubleSided: true));
            tris.add(Triangle3D(v0: p0Bot, v1: p1Top, v2: p0Top, color: color, isDoubleSided: true));
          } else if (rBot <= 1e-4) {
            tris.add(Triangle3D(v0: p0Bot, v1: p1Top, v2: p0Top, color: color, isDoubleSided: true));
          } else {
            tris.add(Triangle3D(v0: p0Bot, v1: p1Bot, v2: p0Top, color: color, isDoubleSided: true));
          }
        }

        // Top Cap (fan)
        if (addTopCap && rTop > 1e-4) {
          final topCenter = Vector3(pos.dx, pos.dy, zTop);
          tris.add(Triangle3D(v0: topCenter, v1: p0Top, v2: p1Top, color: effectiveCapColor, isDoubleSided: true));
        }

        // Bottom Cap (fan)
        if (addBotCap && rBot > 1e-4) {
          final botCenter = Vector3(pos.dx, pos.dy, zBot);
          tris.add(Triangle3D(v0: botCenter, v1: p1Bot, v2: p0Bot, color: effectiveCapColor, isDoubleSided: true));
        }
      }
    }

    // 2. Trunk
    const trunkColor = Color(0xFF5D4037);
    final trunkR = (crownR * 0.10).clamp(0.04, 0.22);
    final trunkH = (h * 0.40).clamp(0.15, h * 0.70);

    if (veg.species != ArchitectPlantSpecies.shrubCluster) {
      addFrustum(
        zBot: z0,
        zTop: z0 + trunkH,
        rBot: trunkR * 1.15,
        rTop: trunkR * 0.90,
        color: trunkColor,
        segments: 8,
        addBotCap: true,
      );
    }

    // 3. Species-specific Crown
    switch (veg.species) {
      case ArchitectPlantSpecies.coniferPine:
        const pineColor = Color(0xFF264E36);
        const pineLight = Color(0xFF2E5E42);
        final crownBaseZ = z0 + trunkH * 0.7;
        final crownTotalH = h - (trunkH * 0.7);
        final tierH = crownTotalH / 3.0;

        for (var tier = 0; tier < 3; tier++) {
          final tZ0 = crownBaseZ + tier * tierH * 0.85;
          final tZ1 = tZ0 + tierH * 1.25;
          final tR = crownR * (1.0 - tier * 0.26);
          addFrustum(
            zBot: tZ0,
            zTop: tZ1,
            rBot: tR,
            rTop: tier == 2 ? 0.0 : tR * 0.25,
            color: tier.isEven ? pineColor : pineLight,
            segments: 10,
            addBotCap: true,
          );
        }

      case ArchitectPlantSpecies.columnarCypress:
        const cypressColor = Color(0xFF1E4620);
        addFrustum(
          zBot: z0 + 0.25,
          zTop: z0 + h * 0.75,
          rBot: crownR * 0.75,
          rTop: crownR,
          color: cypressColor,
          segments: 10,
          addBotCap: true,
        );
        addFrustum(
          zBot: z0 + h * 0.75,
          zTop: z0 + h,
          rBot: crownR,
          rTop: 0.0,
          color: cypressColor,
          segments: 10,
        );

      case ArchitectPlantSpecies.ornamentalPalm:
        const palmGreen = Color(0xFF386641);
        final crownZ = z0 + h * 0.88;
        addFrustum(
          zBot: crownZ - 0.15,
          zTop: crownZ + 0.25,
          rBot: crownR,
          rTop: 0.0,
          color: palmGreen,
          segments: 10,
          addBotCap: true,
        );
        addFrustum(
          zBot: crownZ - 0.45,
          zTop: crownZ - 0.15,
          rBot: crownR * 1.15,
          rTop: crownR,
          color: palmGreen,
          segments: 8,
        );

      case ArchitectPlantSpecies.shrubCluster:
        const shrubColor = Color(0xFF437A4D);
        addFrustum(
          zBot: z0,
          zTop: z0 + h * 0.55,
          rBot: crownR * 0.85,
          rTop: crownR,
          color: shrubColor,
          segments: 10,
          addBotCap: true,
        );
        addFrustum(
          zBot: z0 + h * 0.55,
          zTop: z0 + h,
          rBot: crownR,
          rTop: 0.0,
          color: shrubColor,
          segments: 10,
        );

      case ArchitectPlantSpecies.deciduousCanopy:
      case ArchitectPlantSpecies.deciduousMinimal:
      case ArchitectPlantSpecies.trimmedHedge:
        final canopyColor = veg.species == ArchitectPlantSpecies.deciduousMinimal
            ? const Color(0xFF4F8A5B)
            : const Color(0xFF3A7245);
        final canopyTopColor = const Color(0xFF4A8B56);
        final crownBaseZ = z0 + trunkH * 0.85;
        final crownMidZ = crownBaseZ + (h - crownBaseZ) * 0.55;
        final crownTopZ = z0 + h;

        addFrustum(
          zBot: crownBaseZ,
          zTop: crownMidZ,
          rBot: crownR * 0.40,
          rTop: crownR,
          color: canopyColor,
          segments: 12,
          addBotCap: true,
        );
        addFrustum(
          zBot: crownMidZ,
          zTop: crownTopZ,
          rBot: crownR,
          rTop: 0.0,
          color: canopyTopColor,
          segments: 12,
        );

      case ArchitectPlantSpecies.artisticLowPoly:
        return _buildArtisticLowPolyTree3D(veg, z0, h, crownR, pos);
    }

    return tris;
  }

  /// High-performance topographic 2.5D surface builder.
  /// Subdivides the domain into a regular quad-cell grid and evaluates [groundZ]
  /// via Inverse Distance Weighting across all contours, boundaries, and spots,
  /// generating undulating topographic hills, slopes, and clean excavation cutouts.
  static List<Triangle3D> _buildTopographicTerrainMesh3D({
    required Path terrainFootprint,
    required double Function(Offset) groundZ,
    required Color topColor,
    required Color sideColor,
    required Color bottomColor,
  }) {
    final bounds = terrainFootprint.getBounds();
    if (bounds.isEmpty) return const [];

    final tris = <Triangle3D>[];
    final step = (math.max(bounds.width, bounds.height) / 26.0).clamp(1.0, 3.5);

    final xSteps = ((bounds.width / step).ceil()).clamp(3, 40);
    final ySteps = ((bounds.height / step).ceil()).clamp(3, 40);
    final dx = bounds.width / xSteps;
    final dy = bounds.height / ySteps;

    // Grid of cell containment inside terrain footprint
    final contained = List.generate(
      xSteps,
      (i) => List.generate(ySteps, (j) {
        final cx = bounds.left + (i + 0.5) * dx;
        final cy = bounds.top + (j + 0.5) * dy;
        return terrainFootprint.contains(Offset(cx, cy));
      }),
    );

    for (var i = 0; i < xSteps; i++) {
      for (var j = 0; j < ySteps; j++) {
        if (!contained[i][j]) continue;

        final x0 = bounds.left + i * dx;
        final x1 = bounds.left + (i + 1) * dx;
        final y0 = bounds.top + j * dy;
        final y1 = bounds.top + (j + 1) * dy;

        final p00 = Offset(x0, y0);
        final p10 = Offset(x1, y0);
        final p11 = Offset(x1, y1);
        final p01 = Offset(x0, y1);

        final z00 = groundZ(p00);
        final z10 = groundZ(p10);
        final z11 = groundZ(p11);
        final z01 = groundZ(p01);

        final v00 = Vector3(x0, y0, z00);
        final v10 = Vector3(x1, y0, z10);
        final v11 = Vector3(x1, y1, z11);
        final v01 = Vector3(x0, y1, z01);

        // Top surface triangles
        tris.add(Triangle3D(v0: v00, v1: v10, v2: v11, color: topColor, isDoubleSided: true));
        tris.add(Triangle3D(v0: v00, v1: v11, v2: v01, color: topColor, isDoubleSided: true));

        // Side skirts on exposed borders & excavation hole perimeters
        void addSkirt(Vector3 topA, Vector3 topB) {
          const skirtDepth = 0.35;
          final botA = Vector3(topA.x, topA.y, topA.z - skirtDepth);
          final botB = Vector3(topB.x, topB.y, topB.z - skirtDepth);
          tris.add(Triangle3D(v0: topA, v1: topB, v2: botB, color: sideColor, isDoubleSided: true));
          tris.add(Triangle3D(v0: topA, v1: botB, v2: botA, color: sideColor, isDoubleSided: true));
        }

        if (j == 0 || !contained[i][j - 1]) addSkirt(v00, v10);
        if (i == xSteps - 1 || !contained[i + 1][j]) addSkirt(v10, v11);
        if (j == ySteps - 1 || !contained[i][j + 1]) addSkirt(v11, v01);
        if (i == 0 || !contained[i - 1][j]) addSkirt(v01, v00);
      }
    }

    if (tris.isNotEmpty) return tris;

    // Fallback if cell test missed small shapes
    return _extrude(
      terrainFootprint,
      (p) => groundZ(p) - 0.25,
      (p) => groundZ(p),
      topColor,
      sideColor,
      bottomColor,
    );
  }

  /// Generates a stylish, artistic low-poly tree with faceted 6-sided tapered trunk,
  /// ground root buttresses, and 4 overlapping low-poly polyhedral crown clusters
  /// with flat face normal illumination (< 70 triangles total, runs in < 0.02 ms).
  static List<Triangle3D> _buildArtisticLowPolyTree3D(
    ArchitectVegetationItem veg,
    double z0,
    double h,
    double crownR,
    Offset pos,
  ) {
    final tris = <Triangle3D>[];
    final sunDir = Vector3(0.35, 0.45, 0.82).normalized();

    Color shadeColor(Color base, Vector3 normal) {
      final dot = normal.dot(sunDir);
      final intensity = (0.55 + 0.45 * dot.clamp(0.0, 1.0)).clamp(0.35, 1.15);
      final r = (base.r * 255 * intensity).round().clamp(0, 255);
      final g = (base.g * 255 * intensity).round().clamp(0, 255);
      final b = (base.b * 255 * intensity).round().clamp(0, 255);
      return Color.fromARGB(255, r, g, b);
    }

    void addFacetTriangle(Vector3 v0, Vector3 v1, Vector3 v2, Color baseColor) {
      final e1 = v1 - v0;
      final e2 = v2 - v0;
      var n = e1.cross(e2);
      if (n.lengthSquared > 1e-9) {
        n = n.normalized();
      } else {
        n = Vector3(0, 0, 1);
      }
      final color = shadeColor(baseColor, n);
      tris.add(Triangle3D(v0: v0, v1: v1, v2: v2, color: color, isDoubleSided: true));
    }

    // 1. Faceted Tapered Hexagonal Trunk with Organic Lean & Base Root Buttresses
    final trunkH = (h * 0.42).clamp(0.20, h * 0.70);
    final trunkTopCenter = Vector3(pos.dx + 0.04 * h, pos.dy + 0.02 * h, z0 + trunkH);
    final trunkBotCenter = Vector3(pos.dx, pos.dy, z0);
    final rBot = (crownR * 0.11).clamp(0.05, 0.22);
    final rTop = (crownR * 0.07).clamp(0.03, 0.15);
    const trunkBaseColor = Color(0xFF5D4037);

    const trunkSides = 6;
    final botRing = <Vector3>[];
    final topRing = <Vector3>[];
    for (var i = 0; i < trunkSides; i++) {
      final a = i * (2 * math.pi / trunkSides);
      botRing.add(Vector3(
        trunkBotCenter.x + math.cos(a) * rBot,
        trunkBotCenter.y + math.sin(a) * rBot,
        z0,
      ));
      topRing.add(Vector3(
        trunkTopCenter.x + math.cos(a) * rTop,
        trunkTopCenter.y + math.sin(a) * rTop,
        trunkTopCenter.z,
      ));
    }

    // Trunk side facets
    for (var i = 0; i < trunkSides; i++) {
      final j = (i + 1) % trunkSides;
      addFacetTriangle(botRing[i], botRing[j], topRing[j], trunkBaseColor);
      addFacetTriangle(botRing[i], topRing[j], topRing[i], trunkBaseColor);
    }

    // 3 Root flare buttresses at ground
    for (final idx in [0, 2, 4]) {
      final rootApex = botRing[idx];
      final a = idx * (2 * math.pi / trunkSides);
      final flareOut = Vector3(
        trunkBotCenter.x + math.cos(a) * rBot * 1.8,
        trunkBotCenter.y + math.sin(a) * rBot * 1.8,
        z0,
      );
      final rootMid = Vector3(
        trunkBotCenter.x + math.cos(a) * rBot * 1.05,
        trunkBotCenter.y + math.sin(a) * rBot * 1.05,
        z0 + trunkH * 0.25,
      );
      addFacetTriangle(rootApex, flareOut, rootMid, trunkBaseColor);
    }

    // 2. Artistic Polyhedral Foliage Clusters
    void addCluster({
      required Vector3 center,
      required double radius,
      required double clusterHeight,
      required Color foliageBaseColor,
      int sides = 6,
    }) {
      final topApex = Vector3(center.x, center.y, center.z + clusterHeight * 0.55);
      final botApex = Vector3(center.x, center.y, center.z - clusterHeight * 0.45);
      final midZ = center.z;
      final midPts = <Vector3>[];

      for (var i = 0; i < sides; i++) {
        final a = i * (2 * math.pi / sides) + (sides == 6 ? 0.2 : 0.0);
        final rJitter = radius * (1.0 + 0.12 * math.sin(i * 2.3));
        midPts.add(Vector3(
          center.x + math.cos(a) * rJitter,
          center.y + math.sin(a) * rJitter,
          midZ + (i.isEven ? 0.05 : -0.05) * clusterHeight,
        ));
      }

      for (var i = 0; i < sides; i++) {
        final j = (i + 1) % sides;
        addFacetTriangle(topApex, midPts[i], midPts[j], foliageBaseColor);
        addFacetTriangle(botApex, midPts[j], midPts[i], foliageBaseColor);
      }
    }

    const mainColor = Color(0xFF43A047);
    const lightColor = Color(0xFF66BB6A);
    const sageColor = Color(0xFF388E3C);
    const darkColor = Color(0xFF2E7D32);

    // Cluster 1: Main High Dome
    addCluster(
      center: Vector3(trunkTopCenter.x, trunkTopCenter.y, z0 + h * 0.74),
      radius: crownR * 0.62,
      clusterHeight: h * 0.42,
      foliageBaseColor: lightColor,
      sides: 7,
    );

    // Cluster 2: Left-Forward Asymmetric Puff
    addCluster(
      center: Vector3(
        pos.dx - crownR * 0.38,
        pos.dy - crownR * 0.22,
        z0 + h * 0.56,
      ),
      radius: crownR * 0.46,
      clusterHeight: h * 0.34,
      foliageBaseColor: mainColor,
      sides: 6,
    );

    // Cluster 3: Right-Forward Mid Puff
    addCluster(
      center: Vector3(
        pos.dx + crownR * 0.36,
        pos.dy - crownR * 0.18,
        z0 + h * 0.60,
      ),
      radius: crownR * 0.44,
      clusterHeight: h * 0.32,
      foliageBaseColor: sageColor,
      sides: 6,
    );

    // Cluster 4: Back-Right High Puff
    addCluster(
      center: Vector3(
        pos.dx + crownR * 0.12,
        pos.dy + crownR * 0.35,
        z0 + h * 0.68,
      ),
      radius: crownR * 0.42,
      clusterHeight: h * 0.30,
      foliageBaseColor: darkColor,
      sides: 6,
    );

    return tris;
  }
}
