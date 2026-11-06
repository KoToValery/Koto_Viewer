import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/components/definitions/service_components.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_service_plan_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/architect/services/architect_service_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'architect_services_test.dart' as fixtures;

ArchitectProject building(
  ServiceComponentKind kind, {
  Map<String, dynamic> parameters = const {},
  bool roofOnOtherLevel = false,
}) {
  final source = fixtures.placed(kind, parameters: parameters);
  final roof = ArchitectRoofPlane(
    id: 'roof',
    storeyId: roofOnOtherLevel ? 'upper' : 'roof-level',
    points: fixtures.box(0, 0, 6, 6),
    slopeDegrees: 0,
    baseElevationOffset: 0,
    eavesOverhang: 0,
  );
  return fixtures.projectOf([
    ArchitectStorey(
      id: 'basement',
      name: '',
      elevation: -2.8,
      slabs: [
        ArchitectSlab(id: 'slab-base', polygon: fixtures.box(0, 0, 6, 6)),
      ],
    ),
    ArchitectStorey(id: 'ground', name: '', components: [source]),
    ArchitectStorey(
      id: 'upper',
      name: '',
      elevation: 2.8,
      roofs: roofOnOtherLevel ? [roof.copyWith(baseElevationOffset: 2.8)] : [],
      slabs: [
        ArchitectSlab(id: 'slab-upper', polygon: fixtures.box(0, 0, 6, 6)),
      ],
    ),
    ArchitectStorey(
      id: 'roof-level',
      name: '',
      elevation: 5.6,
      isRoof: true,
      roofs: roofOnOtherLevel ? [] : [roof],
    ),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in [
    ServiceComponentKind.ventSingle,
    ServiceComponentKind.ventDouble,
    ServiceComponentKind.compactVent,
    ServiceComponentKind.combinedRiser,
    ServiceComponentKind.sewer,
    ServiceComponentKind.vent,
    ServiceComponentKind.chimney,
  ]) {
    test(
      '${kind.name} crosses all levels and pierces the roof from one source',
      () {
        final project = building(kind);
        final owner = project.storeys[1], source = owner.components.single;
        final saved = jsonEncode(project.toJson());
        expect(
          ArchitectServiceGeometry.baseElevation(project, owner, source),
          -2.8,
        );
        for (final floor in project.storeys) {
          final symbols = ArchitectServiceGeometry.componentsOnLevel(
            project,
            floor,
          ).toList();
          expect(symbols.map((c) => c.id), contains(source.id));
        }
        final roofFloor = project.storeys.last, roof = roofFloor.roofs.single;
        final highest = source.worldPolygonCorners
            .map((p) => roofFloor.elevation + roof.topElevationAt(p))
            .reduce(math.max);
        final top = ArchitectServiceGeometry.topElevation(
          project,
          owner,
          source,
        );
        expect(top, greaterThanOrEqualTo(highest + .5 - .00001));
        final cut = ArchitectRoofJunctions.of(
          roofFloor,
          project: project,
        ).footprint(roof);
        expect(cut.contains(source.worldBoundingRect.center), isFalse);
        expect(
          ArchitectServiceGeometry.flashing(project, owner, source),
          isNotEmpty,
        );
        for (final floor in [project.storeys.first, project.storeys[2]]) {
          expect(
            ArchitectSlabGeometry.contains(
              floor,
              floor.slabs.single,
              source.worldBoundingRect.center,
              project: project,
            ),
            isFalse,
          );
        }
        expect(jsonEncode(project.toJson()), saved);
        expect(project.storeys.expand((s) => s.components).length, 1);
        final sources = <Triangle3D, String>{};
        Architect3dBuilder.buildProjectMesh(
          project,
          previewGeometry: false,
          sources: sources,
        );
        final count = sources.values.where((id) => id == source.id).length;
        final params = ArchitectServiceGeometry.parameters(
          project,
          owner,
          source,
        );
        final expected =
            ServiceComponentDefinition(
              kind,
            ).resolveGeometry(params).mesh3d.triangles.length +
            ArchitectServiceGeometry.flashing(project, owner, source).length +
            ArchitectServiceGeometry.terminal(project, owner, source).length;
        expect(
          count,
          expected,
          reason: 'Plans must not duplicate the 3D stack',
        );
      },
    );
  }

  test(
    'Roof lines show existing holes even when the planes belong to another level',
    () {
      final project = building(
        ServiceComponentKind.vent,
        roofOnOtherLevel: true,
      );
      final c = project.storeys[1].components.single;
      final level = project.storeys.last;
      expect(level.roofs, isEmpty);
      expect(
        ArchitectServiceGeometry.componentsOnLevel(project, level).single.id,
        c.id,
      );
      final canvas = ArchitectVectorCanvas();
      ArchitectServicePlanPainter.roofOpenings(
        canvas: canvas,
        project: project,
        storey: level,
        scale: 80,
        palette: const ArchitectCanvasPalette.light(),
      );
      final operations = canvas.operations
          .whereType<ArchitectVectorPath>()
          .toList();
      expect(
        operations.where(
          (p) => p.role == 'serviceRoofOpenings' && p.sources.contains(c.id),
        ),
        isNotEmpty,
      );
      expect(
        operations.any(
          (p) =>
              p.fill &&
              p.color == const Color(0xffffffff) &&
              p.path.contains(c.worldBoundingRect.center),
        ),
        isTrue,
      );
      expect(canvas.operations.whereType<ArchitectVectorText>(), isEmpty);
      final floorCanvas = ArchitectVectorCanvas();
      ArchitectElementsPainterHelper.drawComponents(
        canvas: floorCanvas,
        storey: project.storeys[2],
        project: project.copyWith(activeStoreyId: project.storeys[1].id),
        zoomScale: 80,
        layerVisible: false,
      );
      expect(
        floorCanvas.operations.whereType<ArchitectVectorPath>(),
        isNotEmpty,
      );
    },
  );

  test('Roof slope badge avoids a stack placed at the roof centroid', () {
    var project = building(ServiceComponentKind.chimney);
    project = project.copyWith(
      storeys: [
        for (final floor in project.storeys)
          if (floor.id == 'ground')
            floor.copyWith(
              components: [
                floor.components.single.copyWith(position: const Offset(3, 3)),
              ],
            )
          else
            floor,
      ],
    );
    final roofFloor = project.storeys.last;
    final canvas = ArchitectVectorCanvas();
    ArchitectTextScope(project.document, 'plan:roof', 100, 80).run(
      () => ArchitectRoofPainterHelper.paintRoofs(
        canvas: canvas,
        storey: roofFloor,
        project: project,
        scale: 80,
        selectedIds: {},
      ),
    );
    final badge = canvas.operations.whereType<ArchitectVectorText>().single;
    final hole = ArchitectServiceGeometry.penetrations(
      project,
      roofFloor,
      roofFloor.roofs.single,
    ).single.opening.getBounds();
    expect(badge.bounds.overlaps(hole), isFalse);
    final recorder = PictureRecorder();
    ArchitectTextScope(project.document, 'plan:roof', 100, 80).run(
      () => ArchitectRoofPainterHelper.paintRoofs(
        canvas: Canvas(recorder),
        storey: roofFloor,
        project: project,
        scale: 80,
        selectedIds: {},
      ),
    );
    recorder.endRecording().dispose();
    expect(
      ArchitectRoofPainterHelper.hitTestSlopeIndicator(
        roofFloor.roofs.single,
        badge.bounds.center,
        scale: 80,
        storey: roofFloor,
        project: project,
      ),
      isTrue,
    );
  });

  test('Dense roof outlets leave a clear position for the slope badge', () {
    var project = building(ServiceComponentKind.chimney);
    project = project.copyWith(
      storeys: [
        for (final floor in project.storeys)
          if (floor.id == 'ground')
            floor.copyWith(
              components: [
                fixtures
                    .placed(
                      ServiceComponentKind.ventDouble,
                      position: const Offset(1.2, 1.2),
                    )
                    .copyWith(id: 'v'),
                fixtures
                    .placed(
                      ServiceComponentKind.sewer,
                      position: const Offset(3, 1.2),
                    )
                    .copyWith(id: 's'),
                fixtures
                    .placed(
                      ServiceComponentKind.chimney,
                      position: const Offset(1.2, 3),
                    )
                    .copyWith(id: 'c'),
                fixtures
                    .placed(
                      ServiceComponentKind.fireplace,
                      position: const Offset(3, 3),
                    )
                    .copyWith(id: 'f'),
              ],
            )
          else if (floor.isRoof)
            floor.copyWith(
              roofs: [
                floor.roofs.single.copyWith(
                  points: fixtures.box(0, 0, 5, 5),
                  slopeDegrees: 18,
                ),
              ],
            )
          else
            floor,
      ],
    );
    final floor = project.storeys.last;
    final canvas = ArchitectVectorCanvas();
    ArchitectTextScope(project.document, 'plan:roof', 100, 80).run(
      () => ArchitectRoofPainterHelper.paintRoofs(
        canvas: canvas,
        storey: floor,
        project: project,
        scale: 80,
        selectedIds: {},
      ),
    );
    final badge = canvas.operations.whereType<ArchitectVectorText>().single;
    for (final p in ArchitectServiceGeometry.penetrations(
      project,
      floor,
      floor.roofs.single,
    )) {
      expect(
        badge.bounds.overlaps(p.opening.getBounds()),
        isFalse,
        reason: p.component.id,
      );
    }
  });

  test('Move, hide, delete and Undo update every plan and penetration', () {
    final original = building(ServiceComponentKind.chimney);
    final owner = original.storeys[1], source = owner.components.single;
    final controller = ArchitectCommandController(original);
    addTearDown(controller.dispose);
    final initial = controller.project;
    final movedOwner = owner.copyWith(
      components: [source.copyWith(position: const Offset(4, 4))],
    );
    controller.commit(
      initial.copyWith(
        storeys: [
          for (final s in initial.storeys)
            if (s.id == owner.id) movedOwner else s,
        ],
      ),
    );
    for (final floor in controller.project.storeys) {
      expect(
        ArchitectServiceGeometry.componentsOnLevel(
          controller.project,
          floor,
        ).single.position,
        const Offset(4, 4),
      );
    }
    final roofFloor = controller.project.storeys.last,
        roof = roofFloor.roofs.single;
    var path = ArchitectRoofJunctions.of(
      roofFloor,
      project: controller.project,
    ).footprint(roof);
    expect(path.contains(source.worldBoundingRect.center), isTrue);
    final moved = controller.project.storeys[1].components.single;
    expect(path.contains(moved.worldBoundingRect.center), isFalse);
    controller.undo();
    expect(
      controller.project.storeys[1].components.single.position,
      source.position,
    );
    for (final hidden in [true, false]) {
      final changed = initial.copyWith(
        storeys: [
          for (final s in initial.storeys)
            if (s.id == owner.id)
              s.copyWith(
                components: hidden ? [source.copyWith(isVisible: false)] : [],
              )
            else
              s,
        ],
      );
      for (final floor in changed.storeys) {
        expect(
          ArchitectServiceGeometry.componentsOnLevel(changed, floor),
          isEmpty,
        );
      }
      path = ArchitectRoofJunctions.of(
        changed.storeys.last,
        project: changed,
      ).footprint(roof);
      expect(path.contains(source.worldBoundingRect.center), isTrue);
    }
    final restored = ArchitectProject.fromJson(
      jsonDecode(jsonEncode(initial.toJson())),
    );
    expect(restored.storeys.expand((s) => s.components).length, 1);
    expect(
      ArchitectServiceGeometry.componentsOnLevel(
        restored,
        restored.storeys.last,
      ),
      hasLength(1),
    );
  });

  test(
    'Placement-only and fixed-height overrides retain their real vertical range',
    () {
      final project = building(
        ServiceComponentKind.sewer,
        parameters: {'allStoreys': false, 'autoHeight': false, 'height': 1.2},
      );
      expect(
        ArchitectServiceGeometry.componentsOnLevel(
          project,
          project.storeys.first,
        ),
        isEmpty,
      );
      expect(
        ArchitectServiceGeometry.componentsOnLevel(project, project.storeys[1]),
        hasLength(1),
      );
      expect(
        ArchitectServiceGeometry.componentsOnLevel(project, project.storeys[2]),
        isEmpty,
      );
      expect(
        ArchitectServiceGeometry.componentsOnLevel(
          project,
          project.storeys.last,
        ),
        isEmpty,
      );
      expect(
        ArchitectServiceGeometry.penetrations(
          project,
          project.storeys.last,
          project.storeys.last.roofs.single,
        ),
        isEmpty,
      );
    },
  );

  test(
    'Fireplace stays on its placement level while only the flue crosses upper floors',
    () {
      final project = building(ServiceComponentKind.fireplace);
      final owner = project.storeys[1], c = owner.components.single;
      expect(
        ArchitectServiceGeometry.componentsOnLevel(
          project,
          project.storeys.first,
        ),
        isEmpty,
      );
      final onGround = ArchitectServiceGeometry.componentsOnLevel(
        project,
        owner,
      ).single;
      final onUpper = ArchitectServiceGeometry.componentsOnLevel(
        project,
        project.storeys[2],
      ).single;
      final onRoof = ArchitectServiceGeometry.componentsOnLevel(
        project,
        project.storeys.last,
      ).single;
      expect(onGround.definitionId, 'service_fireplace');
      expect(onUpper.definitionId, 'service_chimney');
      expect(onRoof.width, .36);
      final holes = ArchitectSlabGeometry.holes(
        project.storeys[2],
        project.storeys[2].slabs.single,
        project: project,
      );
      expect(holes, hasLength(1));
      expect(
        (Path()..addPolygon(holes.single, true)).getBounds().width,
        closeTo(.55, 1e-6),
      );
      final parameters = ArchitectServiceGeometry.parameters(project, owner, c);
      expect(parameters['stackHeight'], greaterThan(3));
      final mesh = ServiceComponentDefinition(
        ServiceComponentKind.fireplace,
      ).resolveGeometry(parameters).mesh3d;
      final bodyCut = ArchitectMeshSection.horizontal(mesh.triangles, 1);
      expect(
        bodyCut.contains(const Offset(0, .35)),
        isFalse,
        reason: 'Open combustion chamber',
      );
      final flueCut = ArchitectMeshSection.horizontal(mesh.triangles, 3);
      expect(
        flueCut.contains(const Offset(0, .18)),
        isFalse,
        reason: 'Open flue',
      );
      expect(
        flueCut.contains(const Offset(.17, .18)),
        isTrue,
        reason: 'Chimney casing',
      );
      expect(mesh.bounds.max.z, greaterThan(6));
      final roof = project.storeys.last.roofs.single;
      final penetration = ArchitectServiceGeometry.penetrations(
        project,
        project.storeys.last,
        roof,
      ).single;
      expect(penetration.footprint.getBounds().width, closeTo(.36, 1e-6));
    },
  );

  test('Combined plumbing does not expose its water pipes above the roof', () {
    final project = building(ServiceComponentKind.combinedRiser);
    final owner = project.storeys[1], c = owner.components.single;
    final params = ArchitectServiceGeometry.parameters(project, owner, c);
    expect(params['waterHeight'], lessThan(params['height']));
    final floorSymbol = ArchitectServiceGeometry.componentsOnLevel(
      project,
      owner,
    ).single;
    final roofSymbol = ArchitectServiceGeometry.componentsOnLevel(
      project,
      project.storeys.last,
    ).single;
    final definition = ServiceComponentDefinition(
      ServiceComponentKind.combinedRiser,
    );
    expect(
      definition
          .resolveGeometry(floorSymbol.parameters)
          .block2d
          .detailPaths
          .length,
      greaterThan(
        definition
            .resolveGeometry(roofSymbol.parameters)
            .block2d
            .detailPaths
            .length,
      ),
    );
  });
}
