import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_terrain_tin.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

void main() {
  group('Package 3 — Constrained Delaunay TIN & 3D Terrain Mesh', () {
    test(
      'preserves exact contour Z and interpolates planar slopes without IDW cratering',
      () {
        const surface = ArchitectTerrainSurface(
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'outer',
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
              id: 'c1',
              points: [Offset(0, 4), Offset(20, 4)],
              elevation: 0.0,
            ),
            ArchitectTerrainContour(
              id: 'c2',
              points: [Offset(0, 16), Offset(20, 16)],
              elevation: 3.0,
            ),
          ],
        );

        final tin = ArchitectTerrainTin.of(surface);
        expect(tin, isNotNull);
        expect(tin!.triangles, isNotEmpty);

        expect(surface.evaluateElevationAt(const Offset(10, 4))!, closeTo(0.0, 1e-4));
        expect(surface.evaluateElevationAt(const Offset(10, 16))!, closeTo(3.0, 1e-4));
        // Quarter, half, three-quarter linear slope between y=4 (z=0) and y=16 (z=3).
        expect(surface.evaluateElevationAt(const Offset(10, 7))!, closeTo(0.75, 1e-3));
        expect(surface.evaluateElevationAt(const Offset(10, 10))!, closeTo(1.50, 1e-3));
        expect(surface.evaluateElevationAt(const Offset(10, 13))!, closeTo(2.25, 1e-3));
      },
    );

    test(
      'autoInterpolateElevation handles large Gauss-Kruger CAD coordinates accurately',
      () {
        const origin = Offset(450000.0, 4700000.0);
        final surface = ArchitectTerrainSurface(
          state: ArchitectTerrainState.existing,
          datumElevation: 540.0,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'outer',
              polygon: [
                origin + const Offset(0, 0),
                origin + const Offset(30, 0),
                origin + const Offset(30, 30),
                origin + const Offset(0, 30),
              ],
              autoInterpolateElevation: true,
            ),
          ],
          contours: [
            ArchitectTerrainContour(
              id: 'c1',
              points: [origin + const Offset(0, 5), origin + const Offset(30, 5)],
              elevation: 1.0,
              rawAbsoluteElevation: 541.0,
            ),
            ArchitectTerrainContour(
              id: 'c2',
              points: [origin + const Offset(0, 25), origin + const Offset(30, 25)],
              elevation: 5.0,
              rawAbsoluteElevation: 545.0,
            ),
          ],
        );

        final zMid = surface.evaluateElevationAt(origin + const Offset(15, 15));
        expect(zMid, isNotNull);
        expect(zMid!, closeTo(3.0, 1e-3));
      },
    );

    test(
      'honors flat grading pads and excavation cutout holes in 2D and 3D',
      () {
        const surface = ArchitectTerrainSurface(
          state: ArchitectTerrainState.proposed,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'outer',
              polygon: [
                Offset(0, 0),
                Offset(20, 0),
                Offset(20, 20),
                Offset(0, 20),
              ],
              autoInterpolateElevation: true,
            ),
            ArchitectTerrainBoundary(
              id: 'pad',
              polygon: [
                Offset(2, 6),
                Offset(8, 6),
                Offset(8, 14),
                Offset(2, 14),
              ],
              elevation: 2.5,
              isFlatPad: true,
            ),
            ArchitectTerrainBoundary(
              id: 'hole',
              polygon: [
                Offset(12, 8),
                Offset(16, 8),
                Offset(16, 12),
                Offset(12, 12),
              ],
              isHole: true,
            ),
          ],
          contours: [
            ArchitectTerrainContour(
              id: 'c1',
              points: [Offset(0, 2), Offset(20, 2)],
              elevation: 0.0,
            ),
            ArchitectTerrainContour(
              id: 'c2',
              points: [Offset(0, 18), Offset(20, 18)],
              elevation: 4.0,
            ),
          ],
        );

        expect(surface.evaluateElevationAt(const Offset(5, 10)), closeTo(2.5, 1e-4));
        expect(surface.evaluateElevationAt(const Offset(14, 10)), isNull);

        final mesh = ArchitectTerrainTin.buildMesh3D(
          surface,
          buildingCutouts: const [],
          topColor: const Color(0xFF7FA66C),
          sideColor: const Color(0xFF8B6F4E),
          bottomColor: const Color(0xFF6E553A),
        );
        expect(mesh, isNotEmpty);

        // No top triangle centroid should fall inside the excavation hole.
        for (final tri in mesh) {
          if (tri.color != const Color(0xFF7FA66C)) continue;
          final cx = (tri.v0.x + tri.v1.x + tri.v2.x) / 3.0;
          final cy = (tri.v0.y + tri.v1.y + tri.v2.y) / 3.0;
          final inHole = cx > 12.01 && cx < 15.99 && cy > 8.01 && cy < 11.99;
          expect(inHole, isFalse);
        }
      },
    );

    test(
      'sliceProfileSegments yields exact piecewise-linear slopes across TIN edges',
      () {
        const surface = ArchitectTerrainSurface(
          state: ArchitectTerrainState.existing,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'outer',
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
              id: 'c1',
              points: [Offset(0, 4), Offset(20, 4)],
              elevation: 1.0,
            ),
            ArchitectTerrainContour(
              id: 'c2',
              points: [Offset(0, 12), Offset(20, 12)],
              elevation: 3.0,
            ),
          ],
        );

        final segments = surface.sliceProfileSegments(
          const Offset(10, 4),
          const Offset(10, 12),
        );
        expect(segments, hasLength(1));
        final profile = segments.single;
        expect(profile.first.dx, closeTo(0.0, 1e-4));
        expect(profile.first.dy, closeTo(1.0, 1e-3));
        expect(profile.last.dx, closeTo(8.0, 1e-4));
        expect(profile.last.dy, closeTo(3.0, 1e-3));
        for (final p in profile) {
          expect(p.dy, closeTo(1.0 + 0.25 * p.dx, 1e-3));
        }
      },
    );

    test(
      'Architect3dBuilder generates TIN terrain mesh excluding ground-floor slab footprint',
      () async {
        final base = ArchitectProject.starterWithCatalog(
          name: '3D TIN Cutout Test',
          storeyCount: 1,
        );
        final groundStorey = base.storeys
            .firstWhere((s) => s.isBuildingStorey)
            .copyWith(
              slabs: const [
                ArchitectSlab(
                  id: 'gf_slab',
                  polygon: [
                    Offset(6, 6),
                    Offset(14, 6),
                    Offset(14, 14),
                    Offset(6, 14),
                  ],
                ),
              ],
            );
        final updatedStoreys = [
          for (final s in base.storeys)
            if (s.id == groundStorey.id) groundStorey else s,
        ];
        final project = base.copyWith(
          storeys: updatedStoreys,
          proposedTerrain: const ArchitectTerrainSurface(
            state: ArchitectTerrainState.proposed,
            boundaries: [
              ArchitectTerrainBoundary(
                id: 'site',
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
                id: 'c1',
                points: [Offset(0, 2), Offset(20, 2)],
                elevation: -0.2,
              ),
              ArchitectTerrainContour(
                id: 'c2',
                points: [Offset(0, 18), Offset(20, 18)],
                elevation: 1.8,
              ),
            ],
          ),
        );

        final sources = <Triangle3D, String>{};
        await Architect3dBuilder.buildProjectMeshAsync(
          project,
          sources: sources,
        );
        final terrainTris = sources.entries
            .where((e) => e.value == 'terrain_proposed')
            .map((e) => e.key)
            .toList();
        expect(terrainTris, isNotEmpty);

        // No terrain top/bottom triangle centroid may lie inside the slab [6..14]x[6..14].
        for (final tri in terrainTris) {
          final cx = (tri.v0.x + tri.v1.x + tri.v2.x) / 3.0;
          final cy = (tri.v0.y + tri.v1.y + tri.v2.y) / 3.0;
          final insideSlab =
              cx > 6.01 && cx < 13.99 && cy > 6.01 && cy < 13.99;
          expect(insideSlab, isFalse);
        }
      },
    );
  });
}
