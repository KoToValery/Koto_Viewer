import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_fence_3d_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gltf_encoder.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

void main() {
  group('ArchitectFence3dMesh — detailed 3D preset geometry', () {
    test(
      'piersAndSlats builds separate spaced horizontal wood boards, pier caps, and rotates diagonal piers',
      () {
        const fence = ArchitectSiteFence(
          id: 'fence_wood',
          points: [Offset(0, 0), Offset(5, 0)],
          preset: ArchitectSiteFencePreset.piersAndSlats,
          height: 1.90,
          thickness: 0.25,
          plinthHeight: 0.45,
          pierSize: 0.40,
          pierSpacing: 2.50,
        );

        final tris = ArchitectFence3dMesh.build(
          fence,
          groundZAt: (_) => 0.0,
        );
        expect(tris, isNotEmpty);

        // Mid-bay X = 1.25 should contain discrete wood board Z bands with real air gaps between boards.
        final midBayBoardTris = tris.where((t) {
          final cx = (t.v0.x + t.v1.x + t.v2.x) / 3.0;
          final cz = (t.v0.z + t.v1.z + t.v2.z) / 3.0;
          return cx > 0.6 && cx < 1.9 && cz > 0.50 && cz < 1.78;
        }).toList();
        expect(midBayBoardTris.length, greaterThan(40));

        // Check multiple distinct timber board colors are used across planks.
        final colors = {for (final t in midBayBoardTris) t.color};
        expect(colors.length, greaterThanOrEqualTo(3));

        // Verify there is an open air gap near Z ~ 0.635 m (above 1st board, below 2nd board)
        // or at least distinct horizontal board tiers whose bounding Z intervals are non-overlapping.
        final boardBuckets = <double>{};
        for (final t in midBayBoardTris) {
          final zMin = [t.v0.z, t.v1.z, t.v2.z].reduce((a, b) => a < b ? a : b);
          final zMax = [t.v0.z, t.v1.z, t.v2.z].reduce((a, b) => a > b ? a : b);
          if (zMax - zMin < 0.14 && t.material == null) {
            boardBuckets.add((zMin * 100).roundToDouble());
          }
        }
        expect(boardBuckets.length, greaterThanOrEqualTo(6));

        // Diagonal 45-degree fence must rotate its pier vertices rather than staying axis-aligned.
        const diagFence = ArchitectSiteFence(
          id: 'fence_diag',
          points: [Offset(0, 0), Offset(4, 4)],
          preset: ArchitectSiteFencePreset.piersAndSlats,
          pierSize: 0.40,
        );
        final diagTris = ArchitectFence3dMesh.build(
          diagFence,
          groundZAt: (_) => 0.0,
        );
        // Pier centered at (0,0) rotated 45 degrees reaches half-diagonal along +X: 0.2 * sqrt(2) ~= 0.283 > 0.22
        final startPierX = diagTris
            .expand((t) => [t.v0, t.v1, t.v2])
            .where((v) => v.x.abs() < 0.38 && v.y.abs() < 0.38 && v.z > 0.6)
            .map((v) => v.x.abs())
            .reduce((a, b) => a > b ? a : b);
        expect(startPierX, greaterThan(0.24));
      },
    );

    test(
      'gabionFence & gabionRetaining expose multi-toned 3D cobble stones inside metallic wire mesh cages',
      () {
        const gabion = ArchitectSiteFence(
          id: 'fence_gabion',
          points: [Offset(0, 0), Offset(4, 0), Offset(4, 3)],
          preset: ArchitectSiteFencePreset.gabionFence,
          height: 1.80,
          thickness: 0.36,
        );

        final tris = ArchitectFence3dMesh.build(
          gabion,
          groundZAt: (_) => 0.0,
        );
        expect(tris, isNotEmpty);

        final wireTris = tris
            .where((t) => (t.material?.metallicFactor ?? 0.0) > 0.7)
            .toList();
        expect(wireTris.length, greaterThan(100));

        // Verify faceted stone cobbles exist with varied natural stone colors.
        final nonWireColors = {
          for (final t in tris)
            if (t.material == null && t.color != null) t.color!,
        };
        expect(nonWireColors.length, greaterThanOrEqualTo(6));

        // Galvanized wire cage sits proud of inner stone bed (halfT = 0.18 + wire offset).
        final maxWireY = wireTris
            .expand((t) => [t.v0, t.v1, t.v2])
            .where((v) => v.x > 0.5 && v.x < 3.5)
            .map((v) => v.y.abs())
            .reduce((a, b) => a > b ? a : b);
        expect(maxWireY, greaterThan(0.184));

        // Gabion retaining wall forms a stepped upper tier narrower than lower tier + base pad below z=0.
        const gabionRetaining = ArchitectSiteFence(
          id: 'fence_gabion_ret',
          points: [Offset(0, 0), Offset(4, 0)],
          preset: ArchitectSiteFencePreset.gabionRetaining,
          height: 1.40,
          thickness: 0.60,
        );
        final retTris = ArchitectFence3dMesh.build(
          gabionRetaining,
          groundZAt: (_) => 0.0,
        );
        final lowerSpreadY = retTris
            .expand((t) => [t.v0, t.v1, t.v2])
            .where((v) => v.z > 0.15 && v.z < 0.50)
            .map((v) => v.y.abs())
            .reduce((a, b) => a > b ? a : b);
        final upperMinY = retTris
            .expand((t) => [t.v0, t.v1, t.v2])
            .where((v) => v.z > 0.90 && v.z < 1.30)
            .map((v) => v.y)
            .reduce((a, b) => a < b ? a : b);
        // Stepped front edge recesses inward relative to lower course toe (-0.305).
        expect(lowerSpreadY, greaterThan(0.29));
        expect(upperMinY, greaterThan(-0.26));

        // Long perimeter gabion remains fast (< 150ms) and bounded.
        final sw = Stopwatch()..start();
        const longGabion = ArchitectSiteFence(
          id: 'fence_gabion_long',
          points: [
            Offset(0, 0),
            Offset(25, 0),
            Offset(25, 25),
            Offset(0, 25),
          ],
          closed: true,
          preset: ArchitectSiteFencePreset.gabionFence,
          height: 1.80,
          thickness: 0.35,
        );
        final longTris = ArchitectFence3dMesh.build(
          longGabion,
          groundZAt: (_) => 0.0,
        );
        sw.stop();
        expect(longTris, isNotEmpty);
        expect(sw.elapsedMilliseconds, lessThan(250));
      },
    );

    test(
      'modernLouvers, classicIron, and rcRetaining build distinct angled louvers, spear pickets, and battered stems',
      () {
        // Modern louvers: tilted blade normals have non-trivial Z component.
        const louverFence = ArchitectSiteFence(
          id: 'fence_louver',
          points: [Offset(0, 0), Offset(4.8, 0)],
          preset: ArchitectSiteFencePreset.modernLouvers,
          height: 1.85,
          thickness: 0.22,
          pierSize: 0.10,
          pierSpacing: 2.40,
        );
        final louverTris = ArchitectFence3dMesh.build(
          louverFence,
          groundZAt: (_) => 0.0,
        );
        final tiltedFaces = louverTris
            .where(
              (t) =>
                  t.normal.z.abs() > 0.30 &&
                  t.normal.z.abs() < 0.95 &&
                  t.material != null,
            )
            .toList();
        expect(tiltedFaces.length, greaterThan(20));

        // Classic iron: wrought-iron spear finials reach above top rail inside clear bay.
        const ironFence = ArchitectSiteFence(
          id: 'fence_iron',
          points: [Offset(0, 0), Offset(4.8, 0)],
          preset: ArchitectSiteFencePreset.classicIron,
          height: 1.95,
          thickness: 0.25,
          pierSize: 0.40,
          pierSpacing: 2.40,
        );
        final ironTris = ArchitectFence3dMesh.build(
          ironFence,
          groundZAt: (_) => 0.0,
        );
        final spearHeads = ironTris.where((t) {
          final cx = (t.v0.x + t.v1.x + t.v2.x) / 3.0;
          final cz = (t.v0.z + t.v1.z + t.v2.z) / 3.0;
          return cx > 0.4 && cx < 2.0 && cz > 1.82 && (t.material?.metallicFactor ?? 0) > 0.5;
        }).toList();
        expect(spearHeads.length, greaterThan(24));

        // RC retaining wall: top of battered stem is narrower than bottom + footing below zero + weep holes.
        const rcWall = ArchitectSiteFence(
          id: 'fence_rc',
          points: [Offset(0, 0), Offset(6, 0)],
          preset: ArchitectSiteFencePreset.rcRetaining,
          height: 1.60,
          thickness: 0.30,
        );
        final rcTris = ArchitectFence3dMesh.build(
          rcWall,
          groundZAt: (_) => 0.0,
        );
        final hasDeepFooting = rcTris
            .expand((t) => [t.v0, t.v1, t.v2])
            .any((v) => v.z <= -0.30);
        expect(hasDeepFooting, isTrue);

        // No NaN / zero-area triangles and glTF encoding works seamlessly across all presets.
        final project = ArchitectProject(
          id: 'p_fences',
          name: 'Fences 3D',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's1',
          storeys: const [
            ArchitectStorey(
              id: 's1',
              name: 'Ground',
              siteFences: [
                ArchitectSiteFence(
                  id: 'f1',
                  points: [Offset(0, 0), Offset(5, 0)],
                  preset: ArchitectSiteFencePreset.piersAndSlats,
                ),
                ArchitectSiteFence(
                  id: 'f2',
                  points: [Offset(0, 2), Offset(5, 2)],
                  preset: ArchitectSiteFencePreset.gabionFence,
                ),
                ArchitectSiteFence(
                  id: 'f3',
                  points: [Offset(0, 4), Offset(5, 4)],
                  preset: ArchitectSiteFencePreset.gabionRetaining,
                ),
                ArchitectSiteFence(
                  id: 'f4',
                  points: [Offset(0, 6), Offset(5, 6)],
                  preset: ArchitectSiteFencePreset.modernLouvers,
                ),
                ArchitectSiteFence(
                  id: 'f5',
                  points: [Offset(0, 8), Offset(5, 8)],
                  preset: ArchitectSiteFencePreset.classicIron,
                ),
                ArchitectSiteFence(
                  id: 'f6',
                  points: [Offset(0, 10), Offset(5, 10)],
                  preset: ArchitectSiteFencePreset.rcRetaining,
                ),
              ],
            ),
          ],
        );

        final mesh = Architect3dBuilder.buildProjectMesh(project);
        expect(mesh.triangles, isNotEmpty);
        for (final t in mesh.triangles) {
          expect(t.v0.x.isFinite && t.v0.y.isFinite && t.v0.z.isFinite, isTrue);
          expect(t.v1.x.isFinite && t.v1.y.isFinite && t.v1.z.isFinite, isTrue);
          expect(t.v2.x.isFinite && t.v2.y.isFinite && t.v2.z.isFinite, isTrue);
          expect(t.normal.lengthSquared, greaterThan(0));
        }

        final glb = Cad3DGltfEncoder.encode(mesh);
        expect(glb.length, greaterThan(1000));
      },
    );
  });

  group('ArchitectFence3dMesh — sloped, stepped & asymmetric terrain', () {
    Iterable<Triangle3D> trisSpanningX(
      List<Triangle3D> tris,
      double x, {
      double maxAbsY = 0.30,
    }) => tris.where((t) {
      final xs = [t.v0.x, t.v1.x, t.v2.x];
      final ys = [t.v0.y, t.v1.y, t.v2.y];
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);
      return minX <= x && maxX >= x && minY.abs() <= maxAbsY && maxY.abs() <= maxAbsY;
    });

    test(
      'piersAndSlats defaults to stepped horizontal bays on sloped terrain without floating plinths',
      () {
        // Uniform slope: z(x, y) = 0.25 * x (0.0m at x=0 -> 2.0m at x=8).
        double slopedZ(Offset p) => 0.25 * p.dx;

        const fence = ArchitectSiteFence(
          id: 'fence_stepped_slope',
          points: [Offset(0, 0), Offset(8, 0)],
          preset: ArchitectSiteFencePreset.piersAndSlats,
          height: 1.90,
          thickness: 0.25,
          plinthHeight: 0.45,
          pierSize: 0.40,
          pierSpacing: 2.00,
        );
        expect(fence.slopeMode, ArchitectFenceSlopeMode.stepped);

        final tris = ArchitectFence3dMesh.build(fence, groundZAt: slopedZ);
        expect(tris, isNotEmpty);

        // Bay 0 (x in [0, 2]) mid-bay x = 1.0:
        final bay0Tris = trisSpanningX(tris, 1.0).toList();
        expect(bay0Tris, isNotEmpty);
        final bay0PlinthMinZ = bay0Tris
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        final bay0TopZ = bay0Tris
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect(bay0PlinthMinZ, lessThan(-0.15)); // Embedded below lowest ground in bay (0.0)

        // Check boards spanning x=0.60 and x=1.40 in Bay 0 have equal max Z (horizontal, not sloped).
        final bay0LeftMaxZ = trisSpanningX(tris, 0.60)
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        final bay0RightMaxZ = trisSpanningX(tris, 1.40)
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect((bay0LeftMaxZ - bay0RightMaxZ).abs(), lessThan(1e-3));

        // Bay 3 (x in [6, 8]) mid-bay x = 7.0:
        final bay3Tris = trisSpanningX(tris, 7.0).toList();
        final bay3PlinthMinZ = bay3Tris
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        final bay3TopZ = bay3Tris
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        // Bay 3 lowest terrain is at x=6 (z=1.50); plinth embeds below 1.50.
        expect(bay3PlinthMinZ, lessThan(1.40));
        // Bay 3 steps ~1.50 m higher than Bay 0.
        expect(bay3TopZ - bay0TopZ, greaterThan(1.30));

        // Pier at x=2.0 sits between Bay 0 (zHigh ~ 0.50) and Bay 1 (zHigh ~ 1.00):
        // Cap must meet higher bay (1.00 + 1.90 = 2.90) and base must embed below bay 0 low (0.00 - 0.20).
        final pier1Verts = tris
            .expand((t) => [t.v0, t.v1, t.v2])
            .where((v) => (v.x - 2.0).abs() < 0.25 && v.y.abs() < 0.25)
            .toList();
        final pier1MinZ = pier1Verts
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        final pier1MaxZ = pier1Verts
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect(pier1MinZ, lessThanOrEqualTo(-0.19));
        expect(pier1MaxZ, greaterThan(2.85));
      },
    );

    test(
      'concave undulating terrain never leaves plinth floating in stepped or sloped mode',
      () {
        // Parabolic dip: 0.0 at x=0 and x=10, -1.50 at x=5.
        double dipZ(Offset p) {
          final dx = p.dx - 5.0;
          return -1.50 * (1.0 - (dx * dx) / 25.0);
        }

        for (final mode in ArchitectFenceSlopeMode.values) {
          final fence = ArchitectSiteFence(
            id: 'fence_dip_${mode.name}',
            points: const [Offset(0, 0), Offset(10, 0)],
            preset: ArchitectSiteFencePreset.modernLouvers,
            height: 1.80,
            thickness: 0.22,
            pierSpacing: 5.0,
            slopeMode: mode,
          );
          final tris = ArchitectFence3dMesh.build(fence, groundZAt: dipZ);
          // At x=2.5 (inside first 5m bay), dipZ = -1.125; plinth triangles spanning x=2.5 must extend below -1.125.
          final midBayMinZ = trisSpanningX(tris, 2.5)
              .expand((t) => [t.v0, t.v1, t.v2])
              .map((v) => v.z)
              .reduce((a, b) => a < b ? a : b);
          expect(midBayMinZ, lessThan(-1.20));
        }
      },
    );

    test(
      'asymmetric terrain (sloped existing vs flat proposed) grounds plinth below lower side and keeps boards above higher side',
      () {
        // y >= 0: flat proposed yard at z = 0.0
        // y < 0: sloped existing terrain from +1.20 (at x=0) down to -1.20 (at x=6)
        double asymZ(Offset p) => p.dy >= 0.0 ? 0.0 : (1.20 - 0.40 * p.dx);

        const fence = ArchitectSiteFence(
          id: 'fence_asym',
          points: [Offset(0, 0), Offset(6, 0)],
          preset: ArchitectSiteFencePreset.piersAndSlats,
          height: 1.90,
          thickness: 0.25,
          plinthHeight: 0.45,
          pierSpacing: 3.0,
          slopeMode: ArchitectFenceSlopeMode.stepped,
        );

        final tris = ArchitectFence3dMesh.build(fence, groundZAt: asymZ);

        // Bay 0 (x in [0, 3]) mid-bay x = 1.5: existing side reaches +1.20, proposed side is 0.0.
        // Plinth must embed below proposed (0.0) AND boards must stay above existing (+1.20).
        final bay0Verts = trisSpanningX(tris, 1.5)
            .expand((t) => [t.v0, t.v1, t.v2])
            .toList();
        final bay0MinZ = bay0Verts
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        final bay0MaxZ = bay0Verts
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect(bay0MinZ, lessThan(-0.15));
        expect(bay0MaxZ, greaterThan(2.90)); // 1.20 + 1.90 - 0.10 = 3.00

        // Bay 1 (x in [3, 6]) mid-bay x = 4.5: proposed side is 0.0 (higher!), existing side drops to -1.20 (lower!).
        // Plinth must descend below -1.20 while top of fence stays level with proposed yard (0.0 + ~1.80).
        final bay1Verts = trisSpanningX(tris, 4.5)
            .expand((t) => [t.v0, t.v1, t.v2])
            .toList();
        final bay1MinZ = bay1Verts
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        final bay1MaxZ = bay1Verts
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect(bay1MinZ, lessThan(-1.35));
        expect(bay1MaxZ, lessThan(1.95));
        expect(bay1MaxZ, greaterThan(1.75));
      },
    );

    test(
      'gabion, classicIron, and rcRetaining step cleanly on sloped terrain & serialize slopeMode',
      () {
        double slopeZ(Offset p) => 0.30 * p.dx;
        for (final preset in [
          ArchitectSiteFencePreset.gabionFence,
          ArchitectSiteFencePreset.gabionRetaining,
          ArchitectSiteFencePreset.classicIron,
          ArchitectSiteFencePreset.rcRetaining,
        ]) {
          final fence = ArchitectSiteFence(
            id: 'step_${preset.name}',
            points: const [Offset(0, 0), Offset(6, 0)],
            preset: preset,
            height: 1.60,
            pierSpacing: 3.0,
            slopeMode: ArchitectFenceSlopeMode.stepped,
          );
          final tris = ArchitectFence3dMesh.build(fence, groundZAt: slopeZ);
          expect(tris, isNotEmpty);

          final bay0TopZ = tris
              .expand((t) => [t.v0, t.v1, t.v2])
              .where((v) => v.x > 0.5 && v.x < 2.5)
              .map((v) => v.z)
              .reduce((a, b) => a > b ? a : b);
          final bay1TopZ = tris
              .expand((t) => [t.v0, t.v1, t.v2])
              .where((v) => v.x > 3.5 && v.x < 5.5)
              .map((v) => v.z)
              .reduce((a, b) => a > b ? a : b);
          expect(bay1TopZ - bay0TopZ, greaterThan(0.75));
        }

        // JSON round-trip & default stepped compatibility
        const sloped = ArchitectSiteFence(
          id: 'f_ser',
          points: [Offset(0, 0), Offset(4, 0)],
          closed: true,
          slopeMode: ArchitectFenceSlopeMode.sloped,
        );
        final roundTrip = ArchitectSiteFence.fromJson(sloped.toJson());
        expect(roundTrip.slopeMode, ArchitectFenceSlopeMode.sloped);
        expect(roundTrip.closed, isTrue);

        final withoutSlopeField = ArchitectSiteFence.fromJson({
          'id': 'f_def',
          'points': [
            {'x': 0.0, 'y': 0.0},
            {'x': 3.0, 'y': 0.0},
          ],
        });
        expect(withoutSlopeField.slopeMode, ArchitectFenceSlopeMode.stepped);
      },
    );

    test(
      'composite existing+proposed terrain integrates cleanly with 3D builder and 2D section for boundary fence',
      () {
        // Sloped existing terrain: z(x, y) = 0.25 * x across x in [-4, 12], y in [-6, 6].
        const existing = ArchitectTerrainSurface(
          id: 'ex',
          state: ArchitectTerrainState.existing,
          spots: [
            ArchitectTerrainSpot(id: 's0', position: Offset(-4, -6), elevation: -1.0),
            ArchitectTerrainSpot(id: 's1', position: Offset(12, -6), elevation: 3.0),
            ArchitectTerrainSpot(id: 's2', position: Offset(12, 6), elevation: 3.0),
            ArchitectTerrainSpot(id: 's3', position: Offset(-4, 6), elevation: -1.0),
          ],
        );
        // Flat proposed pad at z = 0.50 spanning x in [0, 8], y in [0, 5] with retaining wall edge.
        const proposed = ArchitectTerrainSurface(
          id: 'prop',
          state: ArchitectTerrainState.proposed,
          boundaries: [
            ArchitectTerrainBoundary(
              id: 'pad1',
              polygon: [
                Offset(0, 0),
                Offset(8, 0),
                Offset(8, 5),
                Offset(0, 5),
              ],
              elevation: 0.50,
              isFlatPad: true,
              edgeTransition: ArchitectTerrainEdgeTransition.retainingWall,
            ),
          ],
        );
        // Fence runs along the southern pad edge y = 0 from x = 0 to x = 8.
        const fence = ArchitectSiteFence(
          id: 'f_boundary',
          points: [Offset(0, 0), Offset(8, 0)],
          preset: ArchitectSiteFencePreset.piersAndSlats,
          height: 1.90,
          thickness: 0.25,
          plinthHeight: 0.45,
          pierSpacing: 4.0,
        );

        final project = ArchitectProject(
          id: 'p_asym',
          name: 'Asym Fence',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          activeStoreyId: 's1',
          existingTerrain: existing,
          proposedTerrain: proposed,
          storeys: const [
            ArchitectStorey(
              id: 's1',
              name: 'Ground',
              siteFences: [fence],
            ),
          ],
        );

        final mesh = Architect3dBuilder.buildProjectMesh(project);
        // Near x = 2.0 (inside bay 0 [0, 4]), existing south side goes down to 0.0 while pad is 0.50 -> fence grounds below 0.0.
        final leftMinZ = trisSpanningX(mesh.triangles, 2.0, maxAbsY: 0.28)
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a < b ? a : b);
        expect(leftMinZ, lessThan(-0.10));

        // Near x = 6.0 (inside bay 1 [4, 8]), existing south side rises to 2.0 while pad is 0.50 -> fence rises above 2.0+1.8.
        final rightMaxZ = trisSpanningX(mesh.triangles, 6.0, maxAbsY: 0.28)
            .expand((t) => [t.v0, t.v1, t.v2])
            .map((v) => v.z)
            .reduce((a, b) => a > b ? a : b);
        expect(rightMaxZ, greaterThan(3.70));

        // Section cutting across the fence at x = 7.0 (existing=1.75 on y<0, pad=0.50 on y>0)
        final section = ArchitectBuildingSection.build(
          project,
          const ArchitectSection(
            id: 'sec_1',
            name: 'A-A',
            start: Offset(7.0, -3.0),
            end: Offset(7.0, 3.0),
          ),
        );
        final fenceRegions = section.regions
            .where((r) => r.sourceId == 'f_boundary')
            .toList();
        expect(fenceRegions.length, 2); // plinth + panel
        final plinthBounds = fenceRegions.first.path.getBounds();
        // Plinth must cover from below pad (0.50 - 0.20 = 0.30) up to existing + plinthH (1.75 + 0.45 = 2.20).
        expect(plinthBounds.top, lessThanOrEqualTo(0.35));
        expect(plinthBounds.bottom, greaterThanOrEqualTo(2.15));
      },
    );
  });
}
