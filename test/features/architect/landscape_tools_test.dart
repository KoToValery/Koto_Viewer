import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_landscape_models.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_landscape_painter_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';

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
  });
}
