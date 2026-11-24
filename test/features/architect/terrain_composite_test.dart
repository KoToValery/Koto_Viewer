import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_landscape_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_terrain_composite.dart';

void main() {
  group('ArchitectTerrainComposite — Local Grading, 3D Cutout & Filtered Profiles', () {
    ArchitectProject makeProject({
      ArchitectTerrainSurface existing = const ArchitectTerrainSurface(
        state: ArchitectTerrainState.existing,
      ),
      ArchitectTerrainSurface proposed = const ArchitectTerrainSurface(
        state: ArchitectTerrainState.proposed,
      ),
      List<ArchitectWall> walls = const [],
    }) {
      final storey = ArchitectStorey(
        id: 's1',
        name: 'Ground',
        elevation: 0.0,
        height: 3.0,
        walls: walls,
      );
      return ArchitectProject(
        id: 'comp_test',
        name: 'Composite Test',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        storeys: [storey],
        activeStoreyId: 's1',
        existingTerrain: existing,
        proposedTerrain: proposed,
      );
    }

    test('boundary edgeTransition defaults and JSON roundtrip', () {
      const autoOuter = ArchitectTerrainBoundary(
        id: 'b_auto',
        polygon: [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
        autoInterpolateElevation: true,
      );
      expect(
        autoOuter.effectiveEdgeTransition,
        ArchitectTerrainEdgeTransition.matchExisting,
      );

      const flatPad = ArchitectTerrainBoundary(
        id: 'b_pad',
        polygon: [Offset(2, 2), Offset(6, 2), Offset(6, 6), Offset(2, 6)],
        elevation: 1.0,
        isFlatPad: true,
      );
      expect(
        flatPad.effectiveEdgeTransition,
        ArchitectTerrainEdgeTransition.retainingWall,
      );

      final slopedPad = flatPad.copyWith(
        edgeTransition: ArchitectTerrainEdgeTransition.slope,
        slopeRatio: 2.0,
      );
      final restored = ArchitectTerrainBoundary.fromJson(slopedPad.toJson());
      expect(restored.edgeTransition, ArchitectTerrainEdgeTransition.slope);
      expect(
        restored.effectiveEdgeTransition,
        ArchitectTerrainEdgeTransition.slope,
      );
      expect(restored.slopeRatio, closeTo(2.0, 1e-6));
    });

    test(
      'local Proposed zone cuts Existing in 3D without overlapping triangles and matches seam Z',
      () {
        const existing = ArchitectTerrainSurface(
          id: 'ex',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_ex',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 20),
                Offset(0, 20),
              ],
              autoInterpolateElevation: true,
            ),
          ],
          contours: [
            ArchitectTerrainContour(
              id: 'c0',
              points: [Offset(0, 0), Offset(20, 0)],
              elevation: 0.0,
            ),
            ArchitectTerrainContour(
              id: 'c1',
              points: [Offset(0, 20), Offset(20, 20)],
              elevation: 4.0,
            ),
          ],
        );

        const proposed = ArchitectTerrainSurface(
          id: 'pr',
          state: ArchitectTerrainState.proposed,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_local',
              polygon: [
                Offset(6, 6),
                Offset(14, 6),
                Offset(14, 14),
                Offset(6, 14),
              ],
              autoInterpolateElevation: true,
            ),
          ],
          spots: [
            ArchitectTerrainSpot(
              id: 'sp_peak',
              position: Offset(10, 10),
              elevation: 3.5,
            ),
          ],
        );

        final project = makeProject(existing: existing, proposed: proposed);

        // Outside local zone -> exact existing slope (y=10 => z=2.0)
        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            project,
            const Offset(2, 10),
          ),
          closeTo(2.0, 0.02),
        );
        // Seam vertices match existing slope smoothly
        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            project,
            const Offset(6, 10),
          ),
          closeTo(2.0, 0.05),
        );
        // Inside local zone -> proposed peak
        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            project,
            const Offset(10, 10),
          ),
          closeTo(3.5, 0.02),
        );

        // 3D composite mesh: single watertight surface with ZERO overlapping top triangles
        const topColor = Color(0xFF7FA66C);
        final tris = ArchitectTerrainComposite.buildCompositeMesh3D(
          project,
          buildingCutouts: const [],
          topColor: topColor,
          sideColor: const Color(0xFF8B6F4E),
          bottomColor: const Color(0xFF6E553A),
        );
        final topTris = tris.where((t) => t.color == topColor).toList();
        expect(topTris, isNotEmpty);

        // No two top triangles may overlap at the same XY centroid
        for (var i = 0; i < topTris.length; i++) {
          final a = topTris[i];
          final gx = (a.v0.x + a.v1.x + a.v2.x) / 3.0;
          final gy = (a.v0.y + a.v1.y + a.v2.y) / 3.0;
          var covering = 0;
          for (final b in topTris) {
            if (_pointInTriXY(gx, gy, b.v0.x, b.v0.y, b.v1.x, b.v1.y, b.v2.x, b.v2.y)) {
              covering++;
            }
          }
          expect(
            covering,
            1,
            reason: 'Top surface triangle $i centroid ($gx, $gy) overlapped $covering times',
          );
        }
      },
    );

    test(
      'standalone Proposed Flat pad supports default retainingWall and optional batter slope',
      () {
        const existing = ArchitectTerrainSurface(
          id: 'ex',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_ex',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 20),
                Offset(0, 20),
              ],
              elevation: 0.0,
            ),
          ],
        );

        const padRetaining = ArchitectTerrainBoundary(
          id: 'pad_1',
          polygon: [
            Offset(7, 7),
            Offset(13, 7),
            Offset(13, 13),
            Offset(7, 13),
          ],
          elevation: 1.0,
          isFlatPad: true,
        );

        final retainingProject = makeProject(
          existing: existing,
          proposed: const ArchitectTerrainSurface(
            id: 'pr',
            state: ArchitectTerrainState.proposed,
            boundaries: [padRetaining],
          ),
        );

        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            retainingProject,
            const Offset(6.5, 10),
          ),
          closeTo(0.0, 1e-3),
        );
        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            retainingProject,
            const Offset(10, 10),
          ),
          closeTo(1.0, 1e-3),
        );

        const wallColor = Color(0xFF9E9A92);
        final retainingMesh = ArchitectTerrainComposite.buildCompositeMesh3D(
          retainingProject,
          buildingCutouts: const [],
          topColor: const Color(0xFF7FA66C),
          sideColor: const Color(0xFF8B6F4E),
          bottomColor: const Color(0xFF6E553A),
          retainingWallColor: wallColor,
        );
        final wallTris = retainingMesh.where((t) => t.color == wallColor).toList();
        expect(wallTris.length, greaterThanOrEqualTo(8));

        // Switch the same pad to batter slope 1:1.5
        final slopedProject = makeProject(
          existing: existing,
          proposed: ArchitectTerrainSurface(
            id: 'pr_slope',
            state: ArchitectTerrainState.proposed,
            boundaries: [
              padRetaining.copyWith(
                edgeTransition: ArchitectTerrainEdgeTransition.slope,
                slopeRatio: 1.5,
              ),
            ],
          ),
        );
        final zones = ArchitectTerrainComposite.resolveModificationZones(slopedProject);
        expect(zones, hasLength(1));
        expect(zones.single.hasDaylightRing, isTrue);

        // Midpoint of 1.5m batter slope around x=7 (at x=6.25) should slope near +0.50m
        final zBatter = ArchitectTerrainComposite.evaluateFinalElevationAt(
          slopedProject,
          const Offset(6.25, 10),
        );
        expect(zBatter, isNotNull);
        expect(zBatter!, closeTo(0.50, 0.08));

        // Outside daylight ring (x=4.0) stays at existing 0.0m
        expect(
          ArchitectTerrainComposite.evaluateFinalElevationAt(
            slopedProject,
            const Offset(4.0, 10),
          ),
          closeTo(0.0, 1e-3),
        );
      },
    );

    test(
      'Section filters dashed Existing line to differing regions only (no duplicate lines in unchanged spans)',
      () {
        const existing = ArchitectTerrainSurface(
          id: 'ex',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_ex',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 10),
                Offset(0, 10),
              ],
              elevation: 0.0,
            ),
          ],
        );
        final cloned = ArchitectLandscapeTool.cloneExistingToProposed(
          makeProject(existing: existing),
        );
        // Add a local flat pad only in X = 8..12 on the cloned Proposed surface
        final withLocalPad = cloned.copyWith(
          proposedTerrain: cloned.proposedTerrain.copyWith(
            boundaries: [
              ...cloned.proposedTerrain.boundaries,
              const ArchitectTerrainBoundary(
                id: 'pad_mid',
                polygon: [
                  Offset(8, 2),
                  Offset(12, 2),
                  Offset(12, 8),
                  Offset(8, 8),
                ],
                elevation: 1.0,
                isFlatPad: true,
              ),
            ],
          ),
        );

        const section = ArchitectSection(
          id: 'sec_diff',
          name: 'A-A',
          start: Offset(0, 5),
          end: Offset(20, 5),
        );
        final geom = ArchitectBuildingSection.build(withLocalPad, section);

        expect(geom.proposedTerrainLine, isNotNull);
        final propBounds = geom.proposedTerrainLine!.getBounds();
        expect(propBounds.left, closeTo(0.0, 0.2));
        expect(propBounds.right, closeTo(20.0, 0.2));

        // Dashed existing line must NOT overlap unchanged X = 0..8 or X = 12..20
        expect(geom.existingTerrainLine, isNotNull);
        final exMetrics = geom.existingTerrainLine!.computeMetrics().toList();
        expect(exMetrics, hasLength(1));
        final exBounds = geom.existingTerrainLine!.getBounds();
        expect(exBounds.left, greaterThanOrEqualTo(7.5));
        expect(exBounds.right, lessThanOrEqualTo(12.5));
      },
    );

    test(
      'Section with Existing-only terrain draws solid ground outside building and dashed line only under building',
      () {
        const existing = ArchitectTerrainSurface(
          id: 'ex_only',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_ex',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 10),
                Offset(0, 10),
              ],
              elevation: -0.20,
            ),
          ],
        );
        final walls = [
          ArchitectWall(
            id: 'w1',
            startPoint: const Offset(6, 0),
            endPoint: const Offset(6, 10),
            thickness: 0.25,
            height: 3.0,
          ),
          ArchitectWall(
            id: 'w2',
            startPoint: const Offset(14, 0),
            endPoint: const Offset(14, 10),
            thickness: 0.25,
            height: 3.0,
          ),
        ];
        final project = makeProject(existing: existing, walls: walls);
        const section = ArchitectSection(
          id: 'sec_ex_only',
          name: 'B-B',
          start: Offset(0, 5),
          end: Offset(20, 5),
        );
        final geom = ArchitectBuildingSection.build(project, section);

        // Solid final ground stops at building walls (2 segments: left & right)
        expect(geom.proposedTerrainLine, isNotNull);
        expect(geom.proposedTerrainLine!.computeMetrics().length, 2);
        expect(geom.proposedTerrainHatchBand, isNotNull);

        // Dashed existing ground appears ONLY under the building excavation (X ~ 5.875..14.125)
        expect(geom.existingTerrainLine, isNotNull);
        final exBounds = geom.existingTerrainLine!.getBounds();
        expect(exBounds.left, closeTo(5.875, 0.25));
        expect(exBounds.right, closeTo(14.125, 0.25));
      },
    );

    test(
      'Elevation emits separate dashed existing segments only where elevation differs',
      () {
        const existing = ArchitectTerrainSurface(
          id: 'ex',
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'b_ex',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 10),
                Offset(0, 10),
              ],
              elevation: 0.0,
            ),
          ],
        );
        const proposed = ArchitectTerrainSurface(
          id: 'pr',
          state: ArchitectTerrainState.proposed,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'pad_left',
              polygon: [
                Offset(2, 0),
                Offset(6, 0),
                Offset(6, 10),
                Offset(2, 10),
              ],
              elevation: 0.8,
              isFlatPad: true,
            ),
            ArchitectTerrainBoundary(
              id: 'pad_right',
              polygon: [
                Offset(14, 0),
                Offset(18, 0),
                Offset(18, 10),
                Offset(14, 10),
              ],
              elevation: -0.6,
              isFlatPad: true,
            ),
          ],
        );

        final project = makeProject(existing: existing, proposed: proposed);
        const view = ArchitectElevation(
          id: 'elv_1',
          start: Offset(0, 5),
          end: Offset(20, 5),
        );
        final base = ArchitectBuildingElevation(
          const [],
          const Rect.fromLTRB(-10, 0, 10, 4),
        );
        final geom = ArchitectBuildingElevation.withTerrain(
          base,
          view,
          project: project,
        );

        // Solid final ground spans full elevation width without throwing monotonic validation error
        expect(geom.terrain.length, greaterThanOrEqualTo(4));
        // Exactly 2 separate dashed existing segments (left pad & right pad), nothing in unchanged middle
        expect(geom.existingTerrainSegments, hasLength(2));
        expect(geom.existingTerrainSegments.first.first.dx, closeTo(-8.0, 0.2));
        expect(geom.existingTerrainSegments.first.last.dx, closeTo(-4.0, 0.2));
        expect(geom.existingTerrainSegments.last.first.dx, closeTo(4.0, 0.2));
        expect(geom.existingTerrainSegments.last.last.dx, closeTo(8.0, 0.2));
      },
    );
  });
}

bool _pointInTriXY(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  final denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
  if (denom.abs() < 1e-12) return false;
  final w0 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / denom;
  final w1 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / denom;
  final w2 = 1.0 - w0 - w1;
  return w0 >= -1e-4 && w1 >= -1e-4 && w2 >= -1e-4;
}
