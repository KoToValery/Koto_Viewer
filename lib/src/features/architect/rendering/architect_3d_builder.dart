import 'architect_solid_shell.dart';
import '../services/architect_slab_geometry.dart';
import '../services/architect_roof_junctions.dart';
import 'architect_path_solid.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import 'architect_wall_network.dart';
import 'architect_wall_solids.dart';
import 'architect_stair_mesh.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';

/// Real-time 3D solid mesh builder for architectural projects.
class Architect3dBuilder {
  /// Builds a complete [Mesh3D] from an [ArchitectProject].
  static Mesh3D buildProjectMesh(
    ArchitectProject project, {
    bool previewGeometry = true,
    Map<Triangle3D, String>? sources,
  }) {
    final List<Triangle3D> allTris = [];
    final roofSolids = <(String, List<Triangle3D>)>[];
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
        (w) => w.layers.isNotEmpty || w.plinth.enabled || w.isCurved,
      );
      final wallSolids = <(String, List<Triangle3D>)>[
        if (composed)
          for (final solid in ArchitectWallSolids.build(
            storey,
            project.wallTypes,
            project: project,
          ))
            (solid.wall.id, solid.triangles)
        else
          for (final wall in walls)
            (
              wall.id,
              wall.build3D(
                storeyElevation: storey.elevation,
                includeOpeningMeshes: false,
              ),
            ),
      ];
      final shell = ArchitectSolidShell.build([
        for (final solid in wallSolids) solid.$2,
      ]);
      for (var i = 0; i < wallSolids.length; i++) {
        final first = allTris.length;
        allTris.addAll(shell[i]);
        mark(wallSolids[i].$1, first);
      }
      for (final wall in walls) {
        final first = allTris.length;
        allTris.addAll(
          wall.build3D(
            storeyElevation: storey.elevation,
            sources: sources,
            includeSolid: false,
            resolveComposition: false,
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

      final roofJunctions = ArchitectRoofJunctions.of(storey, project: project);
      final roofMeshes = [
        for (final roof in storey.roofs)
          _buildRoofMesh(
            storey,
            roof,
            detailed: previewGeometry,
            footprint: roofJunctions.trimmed.contains(roof.id)
                ? roofJunctions.footprint(roof)
                : null,
          ),
      ];
      joinedRoofs = joinedRoofs || roofJunctions.trimmed.isNotEmpty;
      for (var i = 0; i < storey.roofs.length; i++) {
        roofSolids.add((storey.roofs[i].id, roofMeshes[i]));
      }

      // Add 3D architectural components (furniture, sanitary, kitchen, equipment)
      for (final comp in storey.components) {
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

    // Roofs on different storeys can meet at the same physical elevation.
    // Remove their shared interfaces together, keeping per-roof source IDs.
    final roofShell = joinedRoofs
        ? ArchitectSolidShell.build([for (final solid in roofSolids) solid.$2])
        : [for (final solid in roofSolids) solid.$2];
    for (var i = 0; i < roofSolids.length; i++) {
      final first = allTris.length;
      allTris.addAll(roofShell[i]);
      mark(roofSolids[i].$1, first);
    }
    return Mesh3D(name: project.name, triangles: allTris);
  }

  static List<Triangle3D> _buildRoofMesh(
    ArchitectStorey storey,
    ArchitectRoofPlane roof, {
    bool detailed = true,
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
    final counterBattenH =
        math.max(timber.counterBattenHeight, 0.03) / cosSlope;
    final battenH = math.max(timber.battenHeight, 0.03) / cosSlope;
    final coveringH = math.max(
      (roof.assembly.totalThickness / cosSlope) -
          (rafterH + boardingH + counterBattenH + battenH),
      0.035 / cosSlope,
    );

    final hRafterBottom = 0.0;
    final hRafterTop = rafterH;
    final hBoardTop = hRafterTop + boardingH;
    final hCounterTop = hBoardTop + counterBattenH;
    final hBattenTop = hCounterTop + battenH;
    final hCoverTop = hBattenTop + coveringH;

    const rafterTopColor = Color(0xFFD7A86E);
    const rafterSideColor = Color(0xFFC49256);
    const purlinColor = Color(0xFFB8864B);
    const boardColor = Color(0xFFCFA16B);
    const membraneColor = Color(0xFF37474F);
    const insulationColor = Color(0xFFE6C86E);
    const counterBattenColor = Color(0xFFDEB887);
    const battenColor = Color(0xFFE6C28B);

    // 1. Wall plate (Mauerlat / Мауерлат) along wall bearing line & Ridge Purlin (Билова столица)
    final wpW = timber.wallPlateWidth.clamp(0.10, 0.24);
    final wpH = timber.wallPlateHeight.clamp(0.10, 0.24);
    final dWall =
        minD +
        (roof.manualSupportDistance ??
            math.min(roof.eavesOverhang, spanD * 0.45));
    if (timber.hasWallPlate &&
        (roof.manualSupportDistance != null
            ? dWall - wpW * .5 < maxD && dWall + wpW * .5 > minD
            : dWall + wpW < maxD)) {
      final wpClipped = _clipPolygonToRect(
        polySD,
        minS,
        maxS,
        roof.manualSupportDistance != null ? dWall - wpW * .5 : dWall,
        roof.manualSupportDistance != null ? dWall + wpW * .5 : dWall + wpW,
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
    if (spanD > wpW * 2.5) {
      final dRidge = maxD - wpW;
      final ridgeClipped = _clipPolygonToRect(polySD, minS, maxS, dRidge, maxD);
      _addExtrudedClippedPrism(
        tris,
        ridgeClipped,
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

    // 2. Rafters (Ребра) & Counter-battens (Контралетви) along slope direction
    final rafterW = timber.rafterWidth.clamp(0.05, 0.16);
    final rafterStep = math.max(timber.rafterSpacing, 0.35);
    final cbW = timber.counterBattenWidth.clamp(0.04, rafterW);

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
      );

      // Counter-batten (Контралетва) directly on top of the rafter line
      final cbS0 = s0 + (rafterW - cbW) * 0.5;
      final cbS1 = math.min(cbS0 + cbW, maxS);
      final cbClip = _clipPolygonToRect(polySD, cbS0, cbS1, minD, maxD);
      _addExtrudedClippedPrism(
        tris,
        cbClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBoardTop,
        hCounterTop,
        planClip: footprint,
        topColor: counterBattenColor,
        sideColor: rafterSideColor,
      );
    }

    // 3. Thermal insulation between rafters (inward of wall bearing line so eaves rafters stay exposed)
    final hasInsulation = roof.assembly.layers.any(
      (l) => l.material == ArchitectRoofMaterial.mineralWool,
    );
    if (hasInsulation && dWall < maxD - 0.1) {
      for (var i = 0; i < rafterPositions.length - 1; i++) {
        final bayS0 = rafterPositions[i] + rafterW + 0.005;
        final bayS1 = rafterPositions[i + 1] - 0.005;
        if (bayS1 <= bayS0) continue;
        final insClip = _clipPolygonToRect(polySD, bayS0, bayS1, dWall, maxD);
        _addExtrudedClippedPrism(
          tris,
          insClip,
          p0,
          u,
          v,
          storey.elevation,
          roof,
          hRafterBottom + rafterH * 0.12,
          hRafterTop * 0.94,
          planClip: footprint,
          topColor: insulationColor,
          sideColor: insulationColor,
        );
      }
    }

    // Stepped constructive reveal on the last verge strip so rafters, boarding,
    // counter-battens, and battens remain visible from above as well as from below.
    final revealSpanS = spanS > 1.6
        ? math.min(rafterStep * 0.85, spanS * 0.22)
        : 0.0;
    final boardMaxS = maxS - revealSpanS * 0.35;
    final coverMaxS = maxS - revealSpanS;
    final coverMinD = minD + math.min(0.06, spanD * 0.04);

    // 4. Sub-roof boarding + waterproofing membrane (Обшивка + Мембрана)
    final boardClip = _clipPolygonToRect(polySD, minS, boardMaxS, minD, maxD);
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

    // 5. Battens (Летви) perpendicular to slope
    final battenW = timber.battenWidth.clamp(0.03, 0.08);
    final battenStep = math.max(timber.battenSpacing, 0.22);
    final battenPositions = <double>[];
    for (var d = minD; d <= maxD - battenW + 1e-4; d += battenStep) {
      battenPositions.add(d);
    }
    if (battenPositions.isEmpty ||
        (maxD - battenW - battenPositions.last).abs() > battenW * 0.6) {
      battenPositions.add(math.max(minD, maxD - battenW));
    }

    for (final d0 in battenPositions) {
      final d1 = math.min(d0 + battenW, maxD);
      final battenClip = _clipPolygonToRect(polySD, minS, maxS, d0, d1);
      _addExtrudedClippedPrism(
        tris,
        battenClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hCounterTop,
        hBattenTop,
        planClip: footprint,
        topColor: battenColor,
        sideColor: rafterSideColor,
      );
    }

    // 6. 3D Profiled Covering: Tiles (Керемиди) or Profiled Metal (Профилирана ламарина)
    if (topMat == ArchitectRoofMaterial.metalSeam) {
      // Base metal pan sheet
      final panH = math.max(coveringH * 0.28, 0.010);
      final sheetClip = _clipPolygonToRect(
        polySD,
        minS,
        coverMaxS,
        coverMinD,
        maxD,
      );
      _addExtrudedClippedPrism(
        tris,
        sheetClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBattenTop,
        hBattenTop + panH,
        planClip: footprint,
        topColor: topColor,
        sideColor: const Color(0xFF37474F),
      );

      // Raised standing seams / corrugated ribs along slope
      const seamSpacing = 0.50;
      const seamWidth = 0.036;
      const seamDark = Color(0xFF37474F);
      const seamLight = Color(0xFF607D8B);
      for (var s = minS + 0.04; s <= coverMaxS - seamWidth; s += seamSpacing) {
        final seamClip = _clipPolygonToRect(
          polySD,
          s,
          s + seamWidth,
          coverMinD,
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
          hBattenTop + panH,
          hCoverTop,
          planClip: footprint,
          topColor: seamLight,
          sideColor: seamDark,
        );
      }
    } else if (topMat == ArchitectRoofMaterial.clayTiles ||
        topMat == ArchitectRoofMaterial.concreteTiles ||
        topMat == ArchitectRoofMaterial.bitumenShingles) {
      final shadeDark = Color.lerp(topColor, Colors.black, 0.22)!;
      final shadeLight = Color.lerp(topColor, Colors.white, 0.12)!;
      final courseCount = battenPositions.length;

      // Stepped overlapping tile courses along each batten row
      for (var i = 0; i < courseCount; i++) {
        final dStart = math.max(battenPositions[i], coverMinD);
        final dEnd = (i + 1 < courseCount)
            ? math.min(battenPositions[i + 1] + battenW * 0.45, maxD)
            : maxD;
        if (dEnd <= dStart + 0.01) continue;

        final courseClip = _clipPolygonToRect(
          polySD,
          minS,
          coverMaxS,
          dStart,
          dEnd,
        );
        final courseColor = i.isEven ? topColor : shadeLight;
        _addExtrudedClippedPrism(
          tris,
          courseClip,
          p0,
          u,
          v,
          storey.elevation,
          roof,
          hBattenTop,
          hBattenTop + coveringH * 0.62,
          planClip: footprint,
          topColor: courseColor,
          sideColor: shadeDark,
        );
      }

      // 3D longitudinal tile wave crests (профил на керемидите)
      if (topMat != ArchitectRoofMaterial.bitumenShingles) {
        const tilePitchS = 0.28;
        const crestWidth = 0.075;
        for (
          var s = minS + 0.05;
          s <= coverMaxS - crestWidth;
          s += tilePitchS
        ) {
          final crestClip = _clipPolygonToRect(
            polySD,
            s,
            s + crestWidth,
            coverMinD,
            maxD,
          );
          _addExtrudedClippedPrism(
            tris,
            crestClip,
            p0,
            u,
            v,
            storey.elevation,
            roof,
            hBattenTop + coveringH * 0.62,
            hCoverTop,
            planClip: footprint,
            topColor: shadeLight,
            sideColor: shadeDark,
          );
        }
      }
    } else {
      final coverClip = _clipPolygonToRect(
        polySD,
        minS,
        coverMaxS,
        coverMinD,
        maxD,
      );
      _addExtrudedClippedPrism(
        tris,
        coverClip,
        p0,
        u,
        v,
        storey.elevation,
        roof,
        hBattenTop,
        hCoverTop,
        planClip: footprint,
        topColor: topColor,
        sideColor: fasciaColor,
      );
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
    return current.length >= 3 ? current : const [];
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
  }) {
    if (clippedSD.length < 3 || hTop <= hBottom) return;
    final botClr = bottomColor ?? sideColor;
    Offset toWorld2D(Offset sd) => Offset(
      p0.dx + u.dx * sd.dx + v.dx * sd.dy,
      p0.dy + u.dy * sd.dx + v.dy * sd.dy,
    );
    if (planClip != null) {
      final footprint = Path.combine(
        PathOperation.intersect,
        planClip,
        Path()..addPolygon(clippedSD.map(toWorld2D).toList(), true),
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
    for (final sd in clippedSD) {
      final p = toWorld2D(sd);
      final baseZ = storeyElevation + roof.undersideElevationAt(p);
      botVerts.add(Vector3(p.dx, p.dy, baseZ + hBottom));
      topVerts.add(Vector3(p.dx, p.dy, baseZ + hTop));
    }

    final v0T = topVerts[0];
    final v0B = botVerts[0];
    for (var i = 1; i < clippedSD.length - 1; i++) {
      tris.add(
        Triangle3D(
          v0: v0T,
          v1: topVerts[i],
          v2: topVerts[i + 1],
          color: topColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: v0B,
          v1: botVerts[i + 1],
          v2: botVerts[i],
          color: botClr,
          isDoubleSided: true,
        ),
      );
    }

    for (var i = 0; i < clippedSD.length; i++) {
      final next = (i + 1) % clippedSD.length;
      final aB = botVerts[i], bB = botVerts[next];
      final aT = topVerts[i], bT = topVerts[next];
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bB,
          v2: bT,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bT,
          v2: aT,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
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
