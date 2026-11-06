import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_railing_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_room_detector.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

ArchitectWall railing(ArchitectRailingKind kind) => ArchitectWall(
  id: 'rail',
  startPoint: Offset.zero,
  endPoint: const Offset(3, 0),
  thickness: .12,
  height: 1.05,
  parapet: true,
  followStoreyHeight: false,
  railing: ArchitectRailingDesign.preset(kind),
);

ArchitectProject project(List<ArchitectWall> walls) => ArchitectProject(
  id: 'p',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: [ArchitectStorey(id: 's', name: '', walls: walls)],
  activeStoreyId: 's',
);

Iterable<Vector3> vertices(Iterable<Triangle3D> triangles) =>
    triangles.expand((t) => [t.v0, t.v1, t.v2]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('plan/3D reuse immutable components until neighbours change', () {
    final wall = railing(ArchitectRailingKind.glassPosts);
    final walls = [wall];
    final first = ArchitectRailingGeometry.components(wall, walls: walls);
    expect(
      identical(first, ArchitectRailingGeometry.components(wall, walls: walls)),
      isTrue,
    );
    expect(
      identical(
        first.first.plan,
        ArchitectRailingGeometry.planPaths(wall, walls: walls).first,
      ),
      isTrue,
    );
    expect(
      identical(
        first,
        ArchitectRailingGeometry.components(wall, walls: [wall]),
      ),
      isFalse,
    );
  });
  test('only dimensions used by the chosen construction are validated', () {
    expect(
      () => const ArchitectRailingDesign(
        kind: ArchitectRailingKind.solidCap,
        glassThickness: -1,
        infillSpacing: -1,
        handrailDiameter: -1,
      ).validate(1.05),
      returnsNormally,
    );
    expect(
      () => const ArchitectRailingDesign(
        kind: ArchitectRailingKind.glassChannel,
        glassThickness: .08,
        channelWidth: .06,
      ).validate(1.05),
      throwsArgumentError,
    );
    expect(
      () => const ArchitectRailingDesign(
        kind: ArchitectRailingKind.verticalBars,
        bottomGap: 1.04,
      ).validate(1.05),
      throwsArgumentError,
    );
  });
  test(
    'side-mounted stainless stays outside and is anchored below the solid top',
    () {
      final top = railing(ArchitectRailingKind.solidStainless);
      final side = top.copyWith(
        railing: top.railing!.copyWith(mounting: ArchitectRailingMount.side),
      );
      final parts = ArchitectRailingGeometry.components(side);
      final rail = parts.firstWhere((p) => p.id.endsWith(':handrail'));
      expect(rail.plan.getBounds().center.dy, closeTo(.08, 1e-6));
      final post = parts.firstWhere((p) => p.id.contains(':post:'));
      expect(
        vertices(post.triangles).map((p) => p.z).reduce(math.min),
        closeTo(.78, 1e-9),
      );
      expect(side.solidBodyHeight, closeTo(.9, 1e-9));
    },
  );
  test(
    'posts meet the round rail underside without a gap or overlapping volume',
    () {
      final wall = railing(ArchitectRailingKind.solidStainless);
      final post = ArchitectRailingGeometry.components(
        wall,
      ).firstWhere((p) => p.id.contains(':post:'));
      final nearTop = ArchitectMeshSection.horizontal(post.triangles, 1.015);
      expect(nearTop.contains(const Offset(.01, .018)), isTrue);
      expect(nearTop.contains(const Offset(.01, 0)), isFalse);
    },
  );
  test(
    'legacy finish remains a full solid with identical round-trip geometry',
    () {
      const wall = ArchitectWall(
        id: 'old',
        startPoint: Offset.zero,
        endPoint: Offset(3, 0),
        thickness: .12,
        height: 1.05,
        parapetFinish: ParapetFinish.handrailPipes,
      );
      final restored = ArchitectWall.fromJson(
        jsonDecode(jsonEncode(wall.toJson())),
      );
      expect(restored.railing, isNull);
      expect(restored.solidBodyHeight, 1.05);
      expect(
        restored.build3D(storeyElevation: 0).length,
        wall.build3D(storeyElevation: 0).length,
      );
      expect(ArchitectRailingGeometry.components(restored), isEmpty);
    },
  );

  for (final kind in ArchitectRailingKind.values) {
    test('${kind.name} round-trips and has bounded real geometry', () {
      final wall = railing(kind);
      wall.validateGeometry();
      final restored = ArchitectWall.fromJson(
        jsonDecode(jsonEncode(wall.toJson())),
      );
      expect(restored.railing!.toJson(), wall.railing!.toJson());
      final parts = ArchitectRailingGeometry.components(
        restored,
        storeyElevation: 3,
      );
      expect(parts, isNotEmpty);
      final zs = vertices(parts.expand((p) => p.triangles)).map((p) => p.z);
      expect(zs.reduce(math.max), closeTo(4.05, 1e-9));
      expect(zs.reduce(math.min), greaterThanOrEqualTo(3));
      expect(
        vertices(
          parts.expand((p) => p.triangles),
        ).every((p) => p.x.isFinite && p.y.isFinite && p.z.isFinite),
        isTrue,
      );
      expect(wall.copyWith(clearRailing: true).railing, isNull);
      final type = ArchitectWallType(
        id: 't',
        name: '',
        usage: WallUsage.parapet,
        totalThickness: .12,
        customHeight: 1.05,
        railing: wall.railing,
      );
      expect(
        ArchitectWallType.fromJson(type.toJson()).railing!.toJson(),
        wall.railing!.toJson(),
      );
      expect(type.copyWith(clearRailing: true).railing, isNull);
      final p = project([wall]);
      final solids = ArchitectWallSolids.build(
        p.activeStorey,
        p.wallTypes,
        project: p,
      );
      if (wall.isOpenRailing) {
        expect(solids, isEmpty);
        expect(wall.resolvedLayers, isEmpty);
        expect(type.resolvedLayers, isEmpty);
        expect(wall.materialSlices(0), isEmpty);
        expect(
          ArchitectWallLayers.build([wall], []).uncutBody.getBounds().isEmpty,
          isTrue,
        );
        expect(ArchitectWallNetwork.body([wall]).getBounds().isEmpty, isTrue);
        expect(wall.canHostOpenings, isFalse);
      } else {
        expect(solids, isNotEmpty);
        expect(
          solids.map((s) => s.top).reduce(math.max),
          closeTo(wall.solidBodyHeight, 1e-9),
        );
      }
      final policies = <Triangle3D, bool>{};
      final mesh = Architect3dBuilder.buildProjectMesh(
        p,
        projectionOcclusion: policies,
      );
      expect(mesh.triangles, isNotEmpty);
      expect(policies.values.contains(false), wall.railing!.isGlass);
    });
  }

  test(
    'glass outlines do not hide a real wall behind; opaque rail still does',
    () async {
      final glassWall = railing(ArchitectRailingKind.glassChannel);
      const rear = ArchitectWall(
        id: 'rear',
        startPoint: Offset(.2, 1),
        endPoint: Offset(2.8, 1),
        thickness: .1,
        height: .8,
        followStoreyHeight: false,
      );
      const view = ArchitectElevation(
        id: 'v',
        start: Offset(-1, -1),
        end: Offset(4, -1),
      );
      final geometry = ArchitectBuildingElevation.build(
        project([glassWall, rear]),
        view,
      );
      expect(
        geometry.elementPaths['rear']!.contains(const Offset(0, .5)),
        isTrue,
      );
      expect(geometry.elementPaths['rail'], isNotNull);
      final asynchronous = await ArchitectBuildingElevation.buildAsync(
        project([glassWall, rear]),
        view,
      );
      expect(
        asynchronous.elementPaths['rear']!.contains(const Offset(0, .5)),
        isTrue,
      );
      final opaque = ArchitectBuildingElevation.build(
        project([glassWall.copyWith(clearRailing: true), rear]),
        view,
      );
      expect(
        opaque.elementPaths['rear']?.contains(const Offset(0, .5)) ?? false,
        isFalse,
      );
    },
  );

  test(
    'glass section retains actual pane thickness and its non-occlusion policy',
    () {
      final p = project([railing(ArchitectRailingKind.glassChannel)]);
      final section = ArchitectBuildingSection.build(
        p,
        const ArchitectSection(
          id: 's',
          start: Offset(1.5, -1),
          end: Offset(1.5, 1),
        ),
      );
      final panes = section.regions
          .where((r) => !r.occludesProjection)
          .toList();
      expect(panes, isNotEmpty);
      expect(panes.every((r) => !r.drawHatch && !r.mergeOutline), isTrue);
      expect(panes.first.path.getBounds().width, closeTo(.02, 1e-6));
      expect(
        section
            .forView(
              const ArchitectSection(
                id: 's',
                start: Offset(1.5, -1),
                end: Offset(1.5, 1),
              ),
            )
            .regions
            .any((r) => !r.occludesProjection),
        isTrue,
      );
    },
  );

  test('an open railing loop cannot create a ghost room', () {
    final base = railing(ArchitectRailingKind.verticalBars);
    final walls = [
      base,
      base.copyWith(
        id: 'b',
        startPoint: const Offset(3, 0),
        endPoint: const Offset(3, 3),
      ),
      base.copyWith(
        id: 'c',
        startPoint: const Offset(3, 3),
        endPoint: const Offset(0, 3),
      ),
      base.copyWith(
        id: 'd',
        startPoint: const Offset(0, 3),
        endPoint: Offset.zero,
      ),
    ];
    expect(
      ArchitectRoomDetector.detectRoomPolygon(
        seedPoint: const Offset(1, 1),
        walls: walls,
      ),
      isNull,
    );
    expect(ArchitectWallNetwork.junctions(walls), isEmpty);
  });

  for (final reference in [WallReferenceLine.inner, WallReferenceLine.outer]) {
    for (final curved in [false, true]) {
      test(
        '$reference physical rail centres meet at ${curved ? 'line/arc' : 'L'} joint',
        () {
          final a = railing(
            ArchitectRailingKind.verticalBars,
          ).copyWith(referenceLine: reference);
          final b = a.copyWith(
            id: 'z',
            startPoint: const Offset(3, 0),
            endPoint: const Offset(3, 3),
            arcBulge: curved ? .3 : 0,
          );
          final walls = [a, b];
          final partsA = ArchitectRailingGeometry.components(a, walls: walls);
          final partsB = ArchitectRailingGeometry.components(b, walls: walls);
          final endPost = partsA.where((p) => p.id.contains(':post:')).last;
          final joint = endPost.plan.getBounds().center;
          if (!curved) {
            final shift = reference == WallReferenceLine.outer ? -.06 : .06;
            expect((joint - Offset(3 - shift, shift)).distance, lessThan(1e-6));
          } else {
            expect(
              (joint - b.arc!.center).distance,
              closeTo(
                b.arc!.radius - b.arc!.bulge.sign * b.centerLineOffset,
                1e-6,
              ),
            );
          }
          List<Vector3> ring(List<ArchitectRailingComponent> parts) {
            final rail = parts.firstWhere((p) => p.id.endsWith(':handrail'));
            final unique = <(int, int, int), Vector3>{};
            for (final p in vertices(rail.triangles)) {
              if ((Offset(p.x, p.y) - joint).distance < .04) {
                unique[(
                      (p.x * 1e8).round(),
                      (p.y * 1e8).round(),
                      (p.z * 1e8).round(),
                    )] =
                    p;
              }
            }
            return unique.values.toList();
          }

          final first = ring(partsA), second = ring(partsB);
          expect(first.length, 12);
          expect(second.length, 12);
          expect(
            first.every((p) => second.any((q) => (p - q).length < 1e-7)),
            isTrue,
          );
          expect(partsB.any((p) => p.id.endsWith(':post:0')), isFalse);
        },
      );
    }
  }

  test('parallel separated physical paths retain both real end posts', () {
    final a = railing(
      ArchitectRailingKind.verticalBars,
    ).copyWith(referenceLine: WallReferenceLine.outer);
    final b = a.copyWith(
      id: 'z',
      startPoint: const Offset(3, 0),
      endPoint: const Offset(6, 0),
      exteriorSide: WallExteriorSide.right,
    );
    final walls = [a, b];
    final aParts = ArchitectRailingGeometry.components(a, walls: walls);
    final bParts = ArchitectRailingGeometry.components(b, walls: walls);
    expect(aParts.any((p) => p.id.endsWith(':post:3')), isTrue);
    expect(bParts.any((p) => p.id.endsWith(':post:0')), isTrue);
    expect(
      ArchitectRailingGeometry.metalGroupId(a, walls),
      isNot(ArchitectRailingGeometry.metalGroupId(b, walls)),
    );
  });

  test(
    'corner owns one post; miter rings meet and curved paths stay finite',
    () {
      final a = railing(ArchitectRailingKind.verticalBars);
      final b = a.copyWith(
        id: 'z',
        startPoint: const Offset(3, 0),
        endPoint: const Offset(3, 3),
      );
      final parts = [
        ...ArchitectRailingGeometry.components(a, walls: [a, b]),
        ...ArchitectRailingGeometry.components(b, walls: [a, b]),
      ];
      final cornerPosts = parts.where(
        (p) => p.id.contains(':post:') && p.plan.contains(const Offset(3, 0)),
      );
      expect(cornerPosts.length, 1);
      final rails = parts.where((p) => p.id.endsWith(':handrail')).toList();
      final left = vertices(
        rails[0].triangles,
      ).where((p) => (p.x - 3).abs() < .04 && p.y.abs() < .04).toList();
      final right = vertices(
        rails[1].triangles,
      ).where((p) => (p.x - 3).abs() < .04 && p.y.abs() < .04).toList();
      expect(
        left.every((p) => right.any((q) => (p - q).length < 1e-8)),
        isTrue,
      );
      final curved = a.copyWith(arcBulge: .3);
      final curveParts = ArchitectRailingGeometry.components(curved);
      expect(
        vertices(
          curveParts.expand((p) => p.triangles),
        ).every((p) => p.x.isFinite && p.y.isFinite),
        isTrue,
      );
    },
  );
}
