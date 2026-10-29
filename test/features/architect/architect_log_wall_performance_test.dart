import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'architect_special_wall_systems_test.dart' as systems;

ArchitectProject attachedLogProject() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_log_walls_2026_10_28.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compact caps retain concavities, holes and disconnected regions', () {
    final shape = Path()
      ..fillType = PathFillType.evenOdd
      ..addPolygon(const [
        Offset(0, 0),
        Offset(3, 0),
        Offset(3, 1),
        Offset(1, 1),
        Offset(1, 3),
        Offset(0, 3),
      ], true)
      ..addRect(const Rect.fromLTWH(.2, .2, .4, .4))
      ..addRect(const Rect.fromLTWH(5, 0, 1, 1));
    final solid = ArchitectPathSolid.extrude(
      shape,
      0,
      2,
      const Color(0xff888888),
      compactCaps: true,
    );
    expect(systems.volume(solid), closeTo((5 - .16 + 1) * 2, 1e-6));
    expect(systems.inside(solid, const Vector3(.4, .4, 1)), isFalse);
    expect(systems.inside(solid, const Vector3(2, 2, 1)), isFalse);
    expect(systems.inside(solid, const Vector3(.8, 2, 1)), isTrue);
    expect(systems.inside(solid, const Vector3(5.5, .5, 1)), isTrue);
    final simple = ArchitectPathSolid.extrude(
      Path()..addPolygon(const [
        Offset(0, 0),
        Offset(3, 0),
        Offset(3, 1),
        Offset(1, 1),
        Offset(1, 3),
        Offset(0, 3),
      ], true),
      0,
      2,
      const Color(0xff888888),
      compactCaps: true,
    );
    expect(simple.length, 20); // Six edges, four triangles at each end.
    expect(systems.volume(simple), closeTo(10, 1e-6));
  });

  test(
    'attached log house prepares smaller closed volumes without blocking timers',
    () async {
      final project = attachedLogProject();
      final floor = project.storeys.firstWhere((s) => s.walls.isNotEmpty);
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => ticks++,
      );
      late List<ArchitectWallComponent> components;
      try {
        components = await ArchitectSpecialWallGeometry.buildAsync(
          floor,
          project: project,
        );
      } finally {
        timer.cancel();
      }
      expect(
        ticks,
        greaterThan(3),
        reason: 'Cold saddle cuts must allow UI events while the worker runs',
      );
      expect(components.length, 58);
      expect(
        components.fold<int>(0, (n, c) => n + c.triangles.length),
        lessThan(40000),
        reason:
            'The attached house previously created 82,069 construction triangles',
      );
      expect(
        identical(
          components,
          ArchitectSpecialWallGeometry.build(floor, project: project),
        ),
        isTrue,
      );
      for (final c in components) {
        expect(systems.volume(c.triangles), greaterThan(1e-7));
        expect(
          c.at((c.bounds.min.z + c.bounds.max.z) / 2).getBounds().isEmpty,
          isFalse,
          reason:
              '${c.wall.id}:${c.id} must remain a sliceable closed component',
        );
      }
      final mesh = await Architect3dBuilder.buildProjectMeshAsync(
        project,
        previewGeometry: false,
      );
      expect(mesh.triangles.length, lessThan(50000));
    },
  );

  test(
    'cached opening variants preserve real log apertures and new model revisions',
    () async {
      final wall = systems
          .special(
            'log',
            ArchitectWallSystemKind.roundLogs,
            Offset.zero,
            const Offset(3, 0),
            height: 1.5,
          )
          .copyWith(
            doors: const [
              ArchitectDoor(
                id: 'door',
                wallId: 'log',
                offsetRatio: .5,
                width: .8,
                height: 1,
                uuid: 'door',
              ),
            ],
          );
      final project = systems.project([wall]);
      final floor = project.activeStorey;
      final actual = await ArchitectWallSolids.buildAsync(floor, project);
      final filled = await ArchitectWallSolids.buildAsync(
        floor,
        project,
        suppressedOpeningIds: {'door'},
      );
      final sectionVariant = await ArchitectWallSolids.buildAsync(
        floor,
        project,
        suppressedOpeningIds: {'door'},
        specialSuppressedOpeningIds: {},
      );
      bool contains(List<ArchitectWallSolid> solids, Vector3 p) =>
          solids.any((s) => systems.inside(s.triangles, p));
      const sample = Vector3(1.5, 0, .5);
      expect(contains(actual, sample), isFalse);
      expect(contains(filled, sample), isTrue);
      expect(contains(sectionVariant, sample), isFalse);
      expect(
        identical(
          actual,
          ArchitectWallSolids.build(floor, project.wallTypes, project: project),
        ),
        isTrue,
      );
      final revised = project.copyWith(
        storeys: [
          floor.copyWith(walls: [wall.copyWith(height: .4, doors: [])]),
        ],
      );
      final shortened = await ArchitectWallSolids.buildAsync(
        revised.activeStorey,
        revised,
      );
      expect(
        shortened.map((s) => s.top),
        everyElement(lessThanOrEqualTo(.400001)),
      );
    },
  );

  test(
    'cold asynchronous attached section matches publication and keeps event processing alive',
    () async {
      final project = attachedLogProject(),
          cut = attachedLogProject().sections.single;
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => ticks++,
      );
      late ArchitectBuildingSection asynchronous;
      try {
        asynchronous = await ArchitectBuildingSection.buildAsync(project, cut);
      } finally {
        timer.cancel();
      }
      expect(ticks, greaterThan(5));
      final synchronous = ArchitectBuildingSection.build(project, cut);
      expect(asynchronous.bounds, synchronous.bounds);
      expect(asynchronous.regions.length, synchronous.regions.length);
      expect(
        asynchronous.background!.faces.length,
        synchronous.background!.faces.length,
      );
      expect(
        asynchronous.elementPaths.keys.toSet(),
        synchronous.elementPaths.keys.toSet(),
      );
      for (var i = 0; i < synchronous.regions.length; i++) {
        final a = asynchronous.regions[i], b = synchronous.regions[i];
        expect(a.sourceId, b.sourceId);
        expect(a.material, b.material);
        expect(a.path.getBounds(), b.path.getBounds());
      }
    },
  );
}
