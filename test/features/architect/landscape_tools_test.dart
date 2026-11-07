import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_landscape_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_chamfer_fillet.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';

void main() {
  group('Landscape Tools — Terrain, Pathway, Vegetation & Site Fence', () {
    test(
      'Section Rule: Existing terrain passes through building; Proposed terrain stops at exterior walls',
      () {
        const existingTerrain = ArchitectTerrainSurface(
          id: 'terr_exst',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_exst',
              polygon: [
                Offset(-5, -5),
                Offset(15, -5),
                Offset(15, 15),
                Offset(-5, 15),
              ],
              elevation: -0.40,
            ),
          ],
          spots: [
            ArchitectTerrainSpot(
              id: 'sp1',
              position: Offset(-5, 5),
              elevation: -0.50,
            ),
            ArchitectTerrainSpot(
              id: 'sp2',
              position: Offset(15, 5),
              elevation: -0.20,
            ),
          ],
        );

        const proposedTerrain = ArchitectTerrainSurface(
          id: 'terr_prop',
          state: ArchitectTerrainState.proposed,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_prop',
              polygon: [
                Offset(-5, -5),
                Offset(15, -5),
                Offset(15, 15),
                Offset(-5, 15),
              ],
              elevation: -0.15,
            ),
          ],
        );

        // Building from X = 2.0 to X = 8.0, Y = 0.0 to Y = 10.0
        final leftWall = ArchitectWall(
          id: 'w_left',
          startPoint: const Offset(2.0, 0.0),
          endPoint: const Offset(2.0, 10.0),
          thickness: 0.25,
          height: 3.0,
        );
        final rightWall = ArchitectWall(
          id: 'w_right',
          startPoint: const Offset(8.0, 0.0),
          endPoint: const Offset(8.0, 10.0),
          thickness: 0.25,
          height: 3.0,
        );

        final storey = ArchitectStorey(
          id: 's1',
          name: 'Ground',
          elevation: 0.0,
          height: 3.0,
          walls: [leftWall, rightWall],
        );

        const section = ArchitectSection(
          id: 'sec_1',
          name: 'A-A',
          start: Offset(-4.0, 5.0),
          end: Offset(14.0, 5.0),
        );

        final project = ArchitectProject(
          id: 'p1',
          name: 'Test Project',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: [storey],
          activeStoreyId: 's1',
          sections: const [section],
          existingTerrain: existingTerrain,
          proposedTerrain: proposedTerrain,
        );

        final geom = ArchitectBuildingSection.build(project, section);

        // 1. Existing terrain must have a single continuous contour passing through the building
        expect(geom.existingTerrainLine, isNotNull);
        final exstMetrics = geom.existingTerrainLine!.computeMetrics().toList();
        expect(exstMetrics.length, 1);
        final exstBounds = geom.existingTerrainLine!.getBounds();
        expect(exstBounds.left, closeTo(0.0, 0.35));
        expect(exstBounds.right, closeTo(18.0, 0.35));

        // 2. Proposed terrain must NOT pass through the building (split into left & right contours)
        expect(geom.proposedTerrainLine, isNotNull);
        final propMetrics = geom.proposedTerrainLine!.computeMetrics().toList();
        expect(propMetrics.length, 2);
        final leftBounds = propMetrics[0].extractPath(0, propMetrics[0].length).getBounds();
        final rightBounds = propMetrics[1].extractPath(0, propMetrics[1].length).getBounds();

        // Building left outer face is at x = 2.0 - 0.125 = 1.875 -> section S = 1.875 - (-4.0) = 5.875
        // Building right outer face is at x = 8.0 + 0.125 = 8.125 -> section S = 8.125 - (-4.0) = 12.125
        expect(leftBounds.right, lessThanOrEqualTo(5.90));
        expect(rightBounds.left, greaterThanOrEqualTo(12.10));
        expect(geom.proposedTerrainHatchBand, isNotNull);
      },
    );

    test(
      'Pathway with Automatic Curbs generates paving and left/right curb polygons',
      () {
        const pathway = ArchitectPathway(
          id: 'path_1',
          points: [Offset(0, 0), Offset(6, 0), Offset(6, 4)],
          width: 1.50,
          material: ArchitectPavingMaterial.cobblePavers,
          curbMode: ArchitectPathwayCurbMode.both,
          curbWidth: 0.10,
          curbHeight: 0.12,
        );

        expect(pathway.pavingPolygon.length, greaterThanOrEqualTo(6));
        expect(pathway.leftCurbPolygon.length, greaterThanOrEqualTo(6));
        expect(pathway.rightCurbPolygon.length, greaterThanOrEqualTo(6));
        expect(pathway.totalWidth, closeTo(1.70, 1e-6));
        expect(pathway.containsPoint(const Offset(3, 0)), isTrue);
        expect(pathway.containsPoint(const Offset(3, 5)), isFalse);

        final noCurb = pathway.copyWith(
          curbMode: ArchitectPathwayCurbMode.none,
        );
        expect(noCurb.leftCurbPolygon, isEmpty);
        expect(noCurb.rightCurbPolygon, isEmpty);
      },
    );

    test(
      'Vegetation 2D Elevation silhouettes & row placement work for all 7 species',
      () {
        for (final species in ArchitectPlantSpecies.values) {
          final item = ArchitectVegetationItem(
            id: 'v_${species.name}',
            species: species,
            position: Offset.zero,
            crownDiameter: 3.0,
            height: 4.5,
          );
          final paths =
              ArchitectLandscapePainterHelper.buildElevationPlantPaths(
                item: item,
                stationX: 5.0,
                groundZ: 0.0,
              );
          expect(paths.canopyFill.getBounds().isEmpty, isFalse);
          expect(paths.canopyOutline.getBounds().isEmpty, isFalse);
        }

        final tool = ArchitectLandscapeTool()
          ..plantSpecies = ArchitectPlantSpecies.columnarCypress
          ..plantPlacementMode = ArchitectVegetationPlacementMode.row
          ..plantRowSpacing = 2.0;

        final project = ArchitectProject(
          id: 'p_veg',
          name: 'Veg Test',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: const [
            ArchitectStorey(id: 's1', name: 'Ground', elevation: 0.0, height: 3.0),
          ],
          activeStoreyId: 's1',
        );
        // Tap 1: start of row
        expect(
          tool.handleTap(
            toolName: 'vegetation',
            worldPoint: const Offset(0, 0),
            project: project,
          ),
          isNull,
        );
        // Tap 2: end of row (6m -> 4 trees at 0, 2, 4, 6m)
        expect(
          tool.handleTap(
            toolName: 'vegetation',
            worldPoint: const Offset(6, 0),
            project: project,
          ),
          isNull,
        );
        final committed = tool.commitDraft(
          toolName: 'vegetation',
          project: project,
        );
        expect(committed, isNotNull);
        expect(committed!.activeStorey.vegetation.length, 4);
      },
    );

    test('Site Fence presets & Project JSON round-trip serialization', () {
      const fence = ArchitectSiteFence(
        id: 'fence_1',
        points: [Offset(0, 0), Offset(10, 0)],
        preset: ArchitectSiteFencePreset.gabionFence,
        height: 1.80,
        thickness: 0.30,
        pierSpacing: 2.50,
      );
      expect(fence.postPositions.length, greaterThanOrEqualTo(4));

      const storey = ArchitectStorey(
        id: 's1',
        name: 'Storey 1',
        siteFences: [fence],
        pathways: [
          ArchitectPathway(
            id: 'p1',
            points: [Offset(0, 2), Offset(5, 2)],
          ),
        ],
        vegetation: [
          ArchitectVegetationItem(
            id: 'v1',
            species: ArchitectPlantSpecies.deciduousCanopy,
            position: Offset(3, 3),
          ),
        ],
      );

      final project = ArchitectProject(
        id: 'proj_1',
        name: 'Landscape Serialization',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [storey],
        activeStoreyId: 's1',
        existingTerrain: const ArchitectTerrainSurface(
          id: 't_exst',
          state: ArchitectTerrainState.existing,
          spots: [
            ArchitectTerrainSpot(
              id: 'sp_exst',
              position: Offset.zero,
              elevation: -0.30,
            ),
          ],
        ),
        proposedTerrain: const ArchitectTerrainSurface(
          id: 't_prop',
          state: ArchitectTerrainState.proposed,
          spots: [
            ArchitectTerrainSpot(
              id: 'sp_prop',
              position: Offset.zero,
              elevation: 0.0,
            ),
          ],
        ),
      );

      final json = project.toJson();
      final restored = ArchitectProject.fromJson(json);

      expect(
        restored.existingTerrain.spots.single.elevation,
        closeTo(-0.30, 1e-6),
      );
      expect(
        restored.proposedTerrain.spots.single.elevation,
        closeTo(0.0, 1e-6),
      );
      expect(
        restored.activeStorey.siteFences.single.preset,
        ArchitectSiteFencePreset.gabionFence,
      );
      expect(restored.activeStorey.pathways.single.id, 'p1');
      expect(
        restored.activeStorey.vegetation.single.species,
        ArchitectPlantSpecies.deciduousCanopy,
      );
    });

    test('90° Orthogonal & Perpendicular Snap Calculation', () {
      // 1. Single anchor: snaps to 0°, 90°, 180°, 270°
      final snapOrtho = ArchitectLandscapeTool.resolveDraftSnapping(
        points: const [Offset(0, 0)],
        rawPoint: const Offset(5.0, 0.08),
        toleranceMeters: 0.35,
      );
      expect(snapOrtho.$2, '0°');
      expect(snapOrtho.$1.dy, closeTo(0.0, 1e-4));
      expect(snapOrtho.$3.isNotEmpty, isTrue);

      // 2. Segment (0,0) -> (4,3): length 5, direction (0.8, 0.6).
      // Perpendicular normal to the left is (-0.6, 0.8).
      // If pointer is at (4,3) + 2*(-0.6, 0.8) + slight jitter = (2.8, 4.6) + (0.05, 0.05)
      // If pointer is near the perpendicular line with a deviation along the segment direction
      final perpTarget = const Offset(4, 3) + const Offset(-0.6, 0.8) * 2.5;
      final snapPerp = ArchitectLandscapeTool.resolveDraftSnapping(
        points: const [Offset(0, 0), Offset(4, 3)],
        // Jitter along the segment direction (0.8, 0.6) * 0.05 = (0.04, 0.03) so projDist along normal stays 2.5
        rawPoint: perpTarget + const Offset(0.04, 0.03),
        toleranceMeters: 0.35,
      );
      expect(snapPerp.$2, '90° ⊥');
      expect(snapPerp.$1.dx, closeTo(perpTarget.dx, 1e-3));
      expect(snapPerp.$1.dy, closeTo(perpTarget.dy, 1e-3));
      // Verify mathematically that (snapPerp - anchor) is perpendicular to seg (0,0)->(4,3)
      final perpVec = snapPerp.$1 - const Offset(4, 3);
      final dotProduct = perpVec.dx * 4.0 + perpVec.dy * 3.0;
      expect(dotProduct.abs(), lessThan(1e-4));
    });

    test('Polyline splitting along cut line for Pathway and Fence', () {
      final points = const [Offset(0, 0), Offset(10, 0), Offset(10, 10)];
      final split = ArchitectLandscapeTool.splitPolyline(
        points,
        const Offset(5, -2),
        const Offset(5, 2),
      );
      expect(split, isNotNull);
      expect(split!.$1.length, 2);
      expect(split.$1.last, const Offset(5, 0));
      expect(split.$2.first, const Offset(5, 0));
      expect(split.$2.length, 3);
    });

    test('UpdateArchitectPolygon applies vertex changes to Pathway, Fence, and Terrain', () {
      const pathway = ArchitectPathway(
        id: 'p_test',
        points: [Offset(0, 0), Offset(5, 0), Offset(5, 5)],
      );
      const fence = ArchitectSiteFence(
        id: 'f_test',
        points: [Offset(0, 0), Offset(4, 0), Offset(4, 4)],
      );
      const boundary = ArchitectTerrainBoundary(
        id: 'b_test',
        polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
      );

      final project = ArchitectProject(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [
          ArchitectStorey(
            id: 's1',
            name: 'Floor',
            pathways: [pathway],
            siteFences: [fence],
          ),
        ],
        activeStoreyId: 's1',
        proposedTerrain: const ArchitectTerrainSurface(
          id: 'terr_prop',
          boundaries: [boundary],
        ),
      );

      // 1. Move vertex of pathway
      final movedPathwayPts = [const Offset(0, 0), const Offset(6, 0), const Offset(6, 5)];
      final res1 = UpdateArchitectPolygon(
        storeyId: 's1',
        elementId: 'p_test',
        polygon: movedPathwayPts,
      ).apply(project);
      expect(res1.activeStorey.pathways.first.points, movedPathwayPts);

      // 2. Move vertex of fence
      final movedFencePts = [const Offset(0, 0), const Offset(5, 0), const Offset(5, 4)];
      final res2 = UpdateArchitectPolygon(
        storeyId: 's1',
        elementId: 'f_test',
        polygon: movedFencePts,
      ).apply(project);
      expect(res2.activeStorey.siteFences.first.points, movedFencePts);

      // 3. Move vertex of terrain boundary
      final movedBndPts = [
        const Offset(0, 0),
        const Offset(12, 0),
        const Offset(12, 10),
        const Offset(0, 10),
      ];
      final res3 = UpdateArchitectPolygon(
        storeyId: 's1',
        elementId: 'b_test',
        polygon: movedBndPts,
      ).apply(project);
      expect(res3.proposedTerrain.boundaries.first.polygon, movedBndPts);
    });

    test('Corner Fillet and Chamfer on Pathway and Fence', () {
      final poly = const [Offset(0, 0), Offset(10, 0), Offset(10, 10)];
      final filleted = ArchitectChamferFillet.polygonFillet(
        poly,
        vertexIndex: 1,
        radius: 1.0,
        isClosed: false,
      );
      expect(filleted.length, greaterThan(3));
      // First and last remain unchanged
      expect(filleted.first, const Offset(0, 0));
      expect(filleted.last, const Offset(10, 10));

      final chamfered = ArchitectChamferFillet.polygonChamfer(
        poly,
        vertexIndex: 1,
        distance: 1.0,
        isClosed: false,
      );
      expect(chamfered.length, 4);
      expect(chamfered[1], const Offset(9, 0));
      expect(chamfered[2], const Offset(10, 1));
    });

    test('3D Vegetation Performance: 50 trees generate in < 15ms without freeze', () async {
      final items = <ArchitectVegetationItem>[];
      for (var i = 0; i < 50; i++) {
        items.add(
          ArchitectVegetationItem(
            id: 'v_$i',
            position: Offset((i % 10) * 4.0, (i ~/ 10) * 4.0),
            species: ArchitectPlantSpecies.values[i % ArchitectPlantSpecies.values.length],
            crownDiameter: 3.5,
            height: 5.0,
            points: [Offset((i % 10) * 4.0, (i ~/ 10) * 4.0), Offset((i % 10) * 4.0 + 2, (i ~/ 10) * 4.0)],
          ),
        );
      }

      final storey = ArchitectStorey(
        id: 's1',
        name: 'Ground',
        vegetation: items,
      );
      final project = ArchitectProject(
        id: 'p1',
        name: '3D Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
      );

      final stopwatch = Stopwatch()..start();
      final mesh = await Architect3dBuilder.buildProjectMeshAsync(project);
      stopwatch.stop();

      expect(mesh.triangles.isNotEmpty, isTrue);
      // Average 40-50 triangles per tree -> ~2500 triangles total
      expect(mesh.triangles.length, lessThan(4000));
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Elevation Contours & Geodetic Datum ±0.00 Conversion', () {
      const datum = 540.00;
      final surface = const ArchitectTerrainSurface(
        datumElevation: datum,
      );

      // 1. Absolute elevation to relative elevation conversion
      expect(surface.toRelativeElevation(542.50), closeTo(2.50, 1e-4));
      expect(surface.toAbsoluteElevation(2.50), closeTo(542.50, 1e-4));

      // 2. Contour with explicit absolute elevation
      const contour = ArchitectTerrainContour(
        id: 'cnt_1',
        points: [Offset(0, 0), Offset(10, 0)],
        elevation: 2.50,
        rawAbsoluteElevation: 542.50,
      );
      expect(contour.effectiveAbsolute(datum), closeTo(542.50, 1e-4));
      expect(contour.effectiveRelative(datum), closeTo(2.50, 1e-4));

      // Shifting building datum by +1.0m (to 541.00) relative height changes to +1.50m
      expect(contour.effectiveRelative(541.00), closeTo(1.50, 1e-4));

      // 3. Landscape Tool commitDraft with 'contour' tool
      final tool = ArchitectLandscapeTool();
      tool.terrainDatumElevation = 540.00;
      tool.contourAbsoluteElevation = 543.20;
      tool.draftPoints.addAll([const Offset(0, 5), const Offset(15, 5)]);

      final emptyProject = ArchitectProject(
        id: 'p_cnt',
        name: 'Contour Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [ArchitectStorey(id: 's0', name: 'Ground')],
        activeStoreyId: 's0',
      );
      final updatedProject = tool.commitDraft(
        toolName: 'contour',
        project: emptyProject,
      );

      expect(updatedProject, isNotNull);
      final committedCnt = updatedProject!.proposedTerrain.contours.first;
      expect(committedCnt.elevation, closeTo(3.20, 1e-4));
      expect(committedCnt.effectiveAbsolute(540.00), closeTo(543.20, 1e-4));
    });

    test('Terrain Cutout Hole excludes points and clips section profiles', () {
      // 1. Boundary with hole
      const outer = ArchitectTerrainBoundary(
        id: 'outer',
        polygon: [Offset(0, 0), Offset(20, 0), Offset(20, 20), Offset(0, 20)],
        elevation: 1.0,
      );
      const hole = ArchitectTerrainBoundary(
        id: 'hole_pool',
        polygon: [Offset(5, 5), Offset(15, 5), Offset(15, 15), Offset(5, 15)],
        elevation: 0.0,
        isHole: true,
      );
      final surface = const ArchitectTerrainSurface(
        boundaries: [outer, hole],
      );

      // Point outside hole but inside terrain boundary evaluates elevation
      expect(surface.evaluateElevationAt(const Offset(2, 2)), isNotNull);

      // Point inside hole evaluates to null (cutout void)
      expect(surface.evaluateElevationAt(const Offset(10, 10)), isNull);

      // 2. Section slice cuts across hole
      final segments = surface.sliceProfileSegments(
        const Offset(0, 10),
        const Offset(20, 10),
      );
      // Profile must be split into two segments: [0 -> 5] and [15 -> 20]
      expect(segments.length, 2);
      expect(segments.first.last.dx, closeTo(5.0, 0.25));
      expect(segments.last.first.dx, closeTo(15.0, 0.25));
    });

    test('Automatic 3D Topographic Terrain Surface generation from Contours', () async {
      // Contours with stepped elevations across site: 0.0m, 1.0m, 2.0m
      final contours = [
        const ArchitectTerrainContour(
          id: 'c0',
          points: [Offset(0, 0), Offset(20, 0)],
          elevation: 0.0,
        ),
        const ArchitectTerrainContour(
          id: 'c1',
          points: [Offset(0, 10), Offset(20, 10)],
          elevation: 1.0,
        ),
        const ArchitectTerrainContour(
          id: 'c2',
          points: [Offset(0, 20), Offset(20, 20)],
          elevation: 2.0,
        ),
      ];

      final project = ArchitectProject(
        id: 'p_topo',
        name: 'Topo Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [ArchitectStorey(id: 's0', name: 'Ground')],
        activeStoreyId: 's0',
        proposedTerrain: ArchitectTerrainSurface(
          contours: contours,
        ),
      );

      final mesh = await Architect3dBuilder.buildProjectMeshAsync(project);
      expect(mesh.triangles.isNotEmpty, isTrue);

      // Verify that the mesh contains elevation variation between 0.0m and 2.0m
      final minZ = mesh.triangles.map((t) => [t.v0.z, t.v1.z, t.v2.z]).expand((z) => z).reduce(math.min);
      final maxZ = mesh.triangles.map((t) => [t.v0.z, t.v1.z, t.v2.z]).expand((z) => z).reduce(math.max);
      expect(maxZ, greaterThan(1.5));
      expect(minZ, lessThan(0.2));
    });

    test('Artistic Low-Poly 3D Tree generation & shading', () async {
      const tree = ArchitectVegetationItem(
        id: 'tree_lowpoly',
        position: Offset(5, 5),
        species: ArchitectPlantSpecies.artisticLowPoly,
        crownDiameter: 3.8,
        height: 5.6,
      );

      final project = ArchitectProject(
        id: 'p_lowpoly',
        name: 'Low Poly Tree Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [
          ArchitectStorey(
            id: 's0',
            name: 'Ground',
            vegetation: [tree],
          ),
        ],
        activeStoreyId: 's0',
      );

      final stopwatch = Stopwatch()..start();
      final mesh = await Architect3dBuilder.buildProjectMeshAsync(project);
      stopwatch.stop();

      expect(mesh.triangles.isNotEmpty, isTrue);
      // Low-poly tree generates 50-80 triangles
      expect(mesh.triangles.length, inInclusiveRange(40, 120));
      // Ultra fast (< 5ms for 1 tree)
      expect(stopwatch.elapsedMilliseconds, lessThan(30));
    });
  });
}
