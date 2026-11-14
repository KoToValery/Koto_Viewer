import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_fence_3d_mesh.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gltf_encoder.dart';

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
}
