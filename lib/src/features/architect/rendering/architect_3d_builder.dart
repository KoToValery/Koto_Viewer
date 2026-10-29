import 'architect_roof_drainage_mesh.dart';
import 'architect_floor_drain_mesh.dart';
import 'architect_solid_shell.dart';
import 'architect_mesh_section.dart';
import 'architect_vertical_clip.dart';
import 'architect_panel_roof_geometry.dart';
import '../services/architect_slab_geometry.dart';
import '../services/architect_roof_junctions.dart';
import '../services/architect_roof_ridge_beams.dart';
import '../services/architect_roof_geometry.dart';
import 'architect_path_solid.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section_visibility.dart';
import 'architect_wall_network.dart';
import 'architect_wall_solids.dart';
import 'architect_stair_mesh.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';

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
          wall.copyWith(height: wall.effectiveHeight(storey.height)),
      ];
      final composed = walls.any(
        (w) =>
            w.system.isSpecial ||
            w.layers.isNotEmpty ||
            w.plinth.enabled ||
            w.isCurved,
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
          ...ArchitectStairMesh.body(stair),
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
      final roofMeshes = [
        for (final roof in storey.roofs)
          if (roof.assembly.panels == null)
            _buildRoofMesh(
              storey,
              roof,
              detailed: previewGeometry,
              ridgeSeats: ridgeBeams,
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
              : const <ArchitectComponentInstance>[]) {
        if (!comp.isVisible) continue;
        final def = ComponentLibraryService.instance.findDefinition(
          comp.definitionId,
        );
        if (def == null) continue;
        final geo = ComponentGeometryCache.instance.getOrCompute(
          def,
          comp.parameters,
        );
        final first = allTris.length;
        final cosR = math.cos(comp.rotation);
        final sinR = math.sin(comp.rotation);
        final zBase = storey.elevation + comp.elevationOffset;

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
        mark(comp.id, first);
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
    return Mesh3D(name: project.name, triangles: allTris);
  }

  static List<Triangle3D> _buildRoofMesh(
    ArchitectStorey storey,
    ArchitectRoofPlane roof, {
    bool detailed = true,
    List<ArchitectRoofRidgeBeam> ridgeSeats = const [],
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
      return _buildSimpleRoofPrism(
        storey,
        roof,
        topColor,
        fasciaColor,
        footprint: footprint,
      );
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

    final hRafterBottom = 0.0;
    final hRafterTop = rafterH;
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
    if (timber.hasWallPlate &&
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
          seats: ridgeSeats,
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
          seats: ridgeSeats,
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
          seats: ridgeSeats,
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
  }) {
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
}
