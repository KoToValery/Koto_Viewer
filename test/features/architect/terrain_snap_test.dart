import 'package:flutter/material.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  group('Terrain & Site Plan snapping to structural and landscape elements', () {
    test(
      'Site plan snaps to exterior wall finish, slabs, columns, beams, stairs, and overhangs',
      () {
        final ground = ArchitectStorey(
          id: 'ground',
          name: '±0.00',
          elevation: 0.0,
          height: 3.0,
          walls: const [
            ArchitectWall(
              id: 'w_north',
              startPoint: Offset(0, 0),
              endPoint: Offset(8, 0),
              thickness: 0.37,
              layers: [
                ArchitectMaterialLayer(
                  id: 'eps',
                  material: ArchitectMaterial.eps,
                  role: ArchitectLayerRole.insulation,
                  thickness: 0.12,
                ),
                ArchitectMaterialLayer(
                  id: 'brick',
                  material: ArchitectMaterial.brick,
                  role: ArchitectLayerRole.core,
                  thickness: 0.25,
                ),
              ],
            ),
          ],
          slabs: const [
            ArchitectSlab(
              id: 'slab_terrace',
              polygon: [
                Offset(0, 0),
                Offset(8, 0),
                Offset(8, -3),
                Offset(0, -3),
              ],
              holes: [
                [
                  Offset(2, -1),
                  Offset(4, -1),
                  Offset(4, -2),
                  Offset(2, -2),
                ],
              ],
            ),
          ],
          columns: const [
            ArchitectColumn(
              id: 'col_porch',
              position: Offset(10, -2),
              width: 0.4,
              depth: 0.4,
            ),
          ],
          beams: const [
            ArchitectBeam(
              id: 'beam_canopy',
              startPoint: Offset(8, -2),
              endPoint: Offset(10, -2),
              width: 0.3,
            ),
          ],
          stairs: const [
            ArchitectStair(
              id: 'stair_entry',
              startPoint: Offset(3, -3),
              endPoint: Offset(3, -4.5),
              width: 1.5,
            ),
          ],
        );

        final upper = ArchitectStorey(
          id: 'upper',
          name: '+3.00',
          elevation: 3.0,
          height: 2.8,
          zones: [
            ArchitectZone(
              id: 'balcony_upper',
              name: 'Balcony',
              category: ArchitectZoneCategory.terrace,
              polygon: const [
                Offset(1, 0),
                Offset(5, 0),
                Offset(5, 2),
                Offset(1, 2),
              ],
            ),
          ],
        );

        final base = ArchitectProject(
          id: 'p_site_struct',
          name: 'Site Structural Snap',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          storeys: [ground, upper],
          activeStoreyId: 'ground',
        ).ensureSiteStorey();
        final onSite = base.copyWith(activeStoreyId: base.siteStorey!.id);

        // Exterior wall finish corner (half thickness = 0.185 above y=0)
        final wallFinishCorner = ground.walls.single.polygonCorners.first;
        final snapWall = ArchitectSnapHelper.snapFree(
          rawPoint: wallFinishCorner + const Offset(0.05, 0.04),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapWall.isSnapped, isTrue);
        expect((snapWall.point - wallFinishCorner).distance, lessThan(1e-6));

        // Ground slab corner & hole corner
        final snapSlab = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(8.04, -2.95),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapSlab.isSnapped, isTrue);
        expect((snapSlab.point - const Offset(8, -3)).distance, lessThan(1e-6));

        final snapSlabHole = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(2.03, -1.96),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapSlabHole.isSnapped, isTrue);
        expect((snapSlabHole.point - const Offset(2, -2)).distance, lessThan(1e-6));

        // Column corner & beam endpoint
        final snapCol = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(10.22, -1.78),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapCol.isSnapped, isTrue);
        expect((snapCol.point - const Offset(10.2, -1.8)).distance, lessThan(1e-6));

        // Beam centerline endpoint
        final snapBeam = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(8.03, -2.02),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapBeam.isSnapped, isTrue);
        expect((snapBeam.point - const Offset(8, -2)).distance, lessThan(1e-6));

        // Stair footprint corner
        final snapStair = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(3.72, -4.46),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapStair.isSnapped, isTrue);
        expect((snapStair.point - const Offset(3.75, -4.5)).distance, lessThan(1e-6));

        // Upper overhang corner
        final snapOverhang = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(4.96, 1.95),
          project: onSite,
          tolerance: 0.15,
        );
        expect(snapOverhang.isSnapped, isTrue);
        expect((snapOverhang.point - const Offset(5, 2)).distance, lessThan(1e-6));
      },
    );

    test('Site plan snaps to ground slab even before any walls exist', () {
      const ground = ArchitectStorey(
        id: 'ground',
        name: '±0.00',
        elevation: 0.0,
        height: 3.0,
        slabs: [
          ArchitectSlab(
            id: 'slab_only',
            polygon: [
              Offset(-2, -2),
              Offset(4, -2),
              Offset(4, 3),
              Offset(-2, 3),
            ],
          ),
        ],
      );
      final base = ArchitectProject(
        id: 'p_slab_only',
        name: 'Slab Only',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: const [ground],
        activeStoreyId: 'ground',
      ).ensureSiteStorey();
      final onSite = base.copyWith(activeStoreyId: base.siteStorey!.id);

      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: const Offset(4.04, 2.96),
        project: onSite,
        tolerance: 0.15,
      );
      expect(snap.isSnapped, isTrue);
      expect((snap.point - const Offset(4, 3)).distance, lessThan(1e-6));
    });

    test(
      'Site plan snaps to pathways, streets, site fences, vegetation, and terrain spots/contours',
      () {
        final starter = ArchitectProject.starterWithCatalog(
          name: 'Landscape Snap',
          storeyCount: 1,
        );
        final site = starter.siteStorey!.copyWith(
          pathways: const [
            ArchitectPathway(
              id: 'path_1',
              points: [Offset(0, 6), Offset(8, 6)],
              width: 1.6,
              curbMode: ArchitectPathwayCurbMode.both,
              curbWidth: 0.15,
            ),
          ],
          streets: const [
            ArchitectStreet(
              id: 'st_1',
              points: [Offset(-10, -8), Offset(12, -8)],
              roadWidth: 6.0,
              curbWidth: 0.2,
              hasLeftSidewalk: true,
              leftSidewalkWidth: 1.5,
              hasRightSidewalk: false,
            ),
          ],
          siteFences: const [
            ArchitectSiteFence(
              id: 'fence_1',
              points: [Offset(-6, -2), Offset(-6, 2)],
              thickness: 0.30,
              pierSpacing: 2.0,
            ),
          ],
          vegetation: const [
            ArchitectVegetationItem(
              id: 'tree_1',
              species: ArchitectPlantSpecies.deciduousCanopy,
              position: Offset(15, 3),
              crownDiameter: 4.0,
            ),
            ArchitectVegetationItem(
              id: 'hedge_1',
              species: ArchitectPlantSpecies.trimmedHedge,
              position: Offset(-3, 2),
              hedgePoints: [Offset(-3, 2), Offset(-3, 7)],
              hedgeWidth: 0.60,
            ),
          ],
        );

        final project = starter.updateStorey(site).copyWith(
          activeStoreyId: site.id,
          gridAxes: const [],
          existingTerrain: const ArchitectTerrainSurface(
            state: ArchitectTerrainState.existing,
            contours: [
              ArchitectTerrainContour(
                id: 'cnt_spline',
                points: [Offset(-5, 12), Offset(0, 14), Offset(5, 12)],
                elevation: 1.0,
                isSpline: true,
              ),
            ],
            spots: [
              ArchitectTerrainSpot(
                id: 'spot_1',
                position: Offset(2, 6),
                elevation: 0.5,
              ),
            ],
          ),
        );

        // Pathway centerline vertex
        final snapPathVertex = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(0.03, 6.03),
          project: project,
          tolerance: 0.15,
        );
        expect(snapPathVertex.isSnapped, isTrue);
        expect((snapPathVertex.point - const Offset(0, 6)).distance, lessThan(1e-6));

        // Pathway outer curb corner: halfW (0.8) + curbWidth (0.15) = 0.95 above y=6 -> y=6.95
        final snapPathCurb = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(8.02, 6.93),
          project: project,
          tolerance: 0.15,
        );
        expect(snapPathCurb.isSnapped, isTrue);
        expect((snapPathCurb.point - const Offset(8, 6.95)).distance, lessThan(1e-6));

        // Street left sidewalk outer edge: y = -8 + 3.0 + 0.2 + 1.5 = -3.3
        final snapSidewalk = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(2.0, -3.27),
          project: project,
          tolerance: 0.15,
        );
        expect(snapSidewalk.isSnapped, isTrue);
        expect((snapSidewalk.point - const Offset(2.0, -3.3)).distance, lessThan(1e-6));

        // Fence pier center at (-6, 0)
        final snapFencePier = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(-5.97, 0.02),
          project: project,
          tolerance: 0.15,
        );
        expect(snapFencePier.isSnapped, isTrue);
        expect((snapFencePier.point - const Offset(-6, 0)).distance, lessThan(1e-6));

        // Tree crown center & east quadrant (17, 3)
        final snapTreeCenter = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(15.03, 2.97),
          project: project,
          tolerance: 0.15,
        );
        expect(snapTreeCenter.isSnapped, isTrue);
        expect((snapTreeCenter.point - const Offset(15, 3)).distance, lessThan(1e-6));

        final snapTreeQuad = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(16.97, 3.02),
          project: project,
          tolerance: 0.15,
        );
        expect(snapTreeQuad.isSnapped, isTrue);
        expect((snapTreeQuad.point - const Offset(17, 3)).distance, lessThan(1e-6));

        // Hedge corner (-3 + 0.3, 2)
        final snapHedge = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(-2.68, 2.02),
          project: project,
          tolerance: 0.15,
        );
        expect(snapHedge.isSnapped, isTrue);
        expect((snapHedge.point - const Offset(-2.7, 2)).distance, lessThan(1e-6));

        // Spot elevation at (2, 6) lies on pathway centerline edge, so Point must win over Edge
        final snapSpot = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(2.03, 6.02),
          project: project,
          tolerance: 0.15,
        );
        expect(snapSpot.isSnapped, isTrue);
        expect(snapSpot.snapLabel, 'Point');
        expect((snapSpot.point - const Offset(2, 6)).distance, lessThan(1e-6));

        // Spline contour sampled curve point at control point (0, 14)
        final snapContour = ArchitectSnapHelper.snapFree(
          rawPoint: const Offset(0.02, 14.03),
          project: project,
          tolerance: 0.15,
        );
        expect(snapContour.isSnapped, isTrue);
        expect((snapContour.point - const Offset(0, 14)).distance, lessThan(1e-6));
      },
    );

    testWidgets(
      'Terrain drafting snaps accurately to ground slab, wall, and pathway corners without ortho override',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final starter = ArchitectProject.starterWithCatalog(
          name: 'Terrain Snap Widget Test',
          storeyCount: 1,
          groundHeight: 3,
          typicalHeight: 3,
        );
        final ground = starter.storeys
            .firstWhere((s) => s.isBuildingStorey)
            .copyWith(
          walls: const [
            ArchitectWall(
              id: 'w1',
              startPoint: Offset(0, 0),
              endPoint: Offset(4, 0),
              thickness: 0.25,
            ),
          ],
          slabs: const [
            ArchitectSlab(
              id: 'slab1',
              polygon: [
                Offset(0, 0),
                Offset(4, 0),
                Offset(4, 4),
                Offset(0, 4),
              ],
            ),
          ],
        );
        final site = starter.siteStorey!.copyWith(
          pathways: const [
            ArchitectPathway(
              id: 'path1',
              points: [Offset(4, 4.15), Offset(8, 4.15)],
              width: 1.0,
              curbMode: ArchitectPathwayCurbMode.none,
            ),
          ],
        );
        final project = starter
            .updateStorey(ground)
            .updateStorey(site)
            .copyWith(activeStoreyId: site.id);

        final model = ArchitectCommandController(project);
        addTearDown(model.dispose);
        await workspace.open(tester, model);

        await tester.tap(find.byKey(const ValueKey('architect-tool-category')));
        await tester.pumpAndSettle();
        final landscapeCat = find.byKey(
          const ValueKey('architect-category-landscape'),
        );
        await tester.ensureVisible(landscapeCat);
        await tester.tap(landscapeCat);
        await tester.pumpAndSettle();

        // Point 1: near slab corner (0, 0)
        await workspace.wallTap(tester, const Offset(0.05, 0.05));
        // Point 2: near wall exterior corner (4, -0.125) — close to y=0 ortho from (0,0),
        // must snap to the wall exterior corner rather than getting pulled to y=0!
        await workspace.wallTap(tester, const Offset(4.02, -0.11));
        // Point 3: near pathway start vertex (4, 4.15) — close to x=4 ortho,
        // must snap to (4, 4.15) rather than getting overwritten!
        await workspace.wallTap(tester, const Offset(4.03, 4.13));
        // Point 4: near slab corner (0, 4)
        await workspace.wallTap(tester, const Offset(-0.04, 3.98));
        // Close back to Point 1 (0, 0)
        await workspace.wallTap(tester, const Offset(0.05, 0.05));
        await tester.pumpAndSettle();

        expect(model.project.existingTerrain.boundaries, hasLength(1));
        final poly = model.project.existingTerrain.boundaries.single.polygon;
        expect(poly, hasLength(4));
        expect((poly[0] - const Offset(0, 0)).distance, lessThan(1e-4));
        expect((poly[1] - const Offset(4, -0.125)).distance, lessThan(1e-4));
        expect((poly[2] - const Offset(4, 4.15)).distance, lessThan(1e-4));
        expect((poly[3] - const Offset(0, 4)).distance, lessThan(1e-4));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
