import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_connection_policy.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_exterior_resolver.dart';

ArchitectWall wall(String id, Offset a, Offset b) => ArchitectWall(
  id: id,
  startPoint: a,
  endPoint: b,
  parapet: false,
  wallTypeId: 'ext_25_brick',
  location: ArchitectWallLocation.exterior,
);
List<ArchitectWall> rectangle({
  Offset shift = Offset.zero,
  String prefix = '',
}) {
  final p = [
    Offset.zero,
    const Offset(6, 0),
    const Offset(6, 4),
    const Offset(0, 4),
  ];
  return [
    for (var i = 0; i < 4; i++)
      wall('$prefix$i', p[i] + shift, p[(i + 1) % 4] + shift),
  ];
}

ArchitectProject project(List<ArchitectWall> walls) =>
    ArchitectProject.starterWithCatalog(name: 'test', storeyCount: 1).copyWith(
      activeStoreyId: 's',
      storeys: [ArchitectStorey(id: 's', name: 's', walls: walls)],
    );

void main() {
  test('Panels and frames resolve independently of their preset location', () {
    for (final kind in [
      ArchitectWallSystemKind.sandwichPanels,
      ArchitectWallSystemKind.studFrame,
    ]) {
      final type = ArchitectWallType.standardCatalog(
        includeSpecial: true,
      ).firstWhere((t) => t.system.kind == kind);
      final input = rectangle()
          .map(
            (w) => w.copyWith(
              system: type.system,
              layers: type.resolvedLayers,
              thickness: type.totalThickness,
              location: type.resolvedLocation,
            ),
          )
          .toList();
      final floor = ArchitectWallExteriorResolver.resolveStorey(
        project(input).activeStorey,
      );
      expect(
        floor.walls.every(
          (w) =>
              w.isExterior &&
              w.exteriorResolved &&
              w.exteriorSide == WallExteriorSide.right,
        ),
        isTrue,
        reason: '$kind',
      );
      for (var i = 0; i < input.length; i++) {
        expect(
          (input[i].coreCenterStart - floor.walls[i].coreCenterStart).distance,
          lessThan(1e-7),
        );
      }
    }
  });

  test(
    'Rectangle recognizes both location and side regardless of drawing order',
    () {
      final random = math.Random(14);
      for (var run = 0; run < 12; run++) {
        final input =
            rectangle()
                .map(
                  (w) => random.nextBool()
                      ? w.copyWith(
                          startPoint: w.endPoint,
                          endPoint: w.startPoint,
                        )
                      : w,
                )
                .toList()
              ..shuffle(random);
        final result = ArchitectWallExteriorResolver.resolveStorey(
          project(input).activeStorey,
        );
        for (final w in result.walls) {
          expect(w.isExterior, isTrue);
          expect(w.exteriorResolved, isTrue);
          final outward = w.centerPointAt(.5) - const Offset(3, 2);
          expect(
            outward.dx * w.exteriorNormal.dx + outward.dy * w.exteriorNormal.dy,
            greaterThan(1),
          );
        }
      }
    },
  );

  test(
    'T junctions and dangling partitions become interior without room labels',
    () {
      for (final end in [const Offset(3, 4), const Offset(3, 2)]) {
        final input = [
          ...rectangle(),
          wall('partition', const Offset(3, 0), end),
        ];
        final result = ArchitectWallExteriorResolver.resolveStorey(
          project(input).activeStorey,
        );
        expect(result.walls.last.isInterior, isTrue);
        expect(result.walls.last.exteriorResolved, isTrue);
        expect(
          result.walls.take(4).every((w) => w.isExterior && w.exteriorResolved),
          isTrue,
        );
      }
    },
  );

  test('Concave contours do not use a centroid to choose the outside', () {
    final points = [
      Offset.zero,
      const Offset(6, 0),
      const Offset(6, 2),
      const Offset(2, 2),
      const Offset(2, 6),
      const Offset(0, 6),
    ];
    final input = [
      for (var i = 0; i < points.length; i++)
        wall('$i', points[i], points[(i + 1) % points.length]),
    ];
    final result = ArchitectWallExteriorResolver.resolveStorey(
      project(input).activeStorey,
    );
    expect(
      result.walls.every(
        (w) => w.exteriorResolved && w.exteriorSide == WallExteriorSide.right,
      ),
      isTrue,
    );
  });

  test('Open contours and real gaps do not manufacture exterior direction', () {
    for (final input in [
      rectangle().take(3).toList(),
      [
        rectangle()[0].copyWith(endPoint: const Offset(5.4, 0)),
        ...rectangle().skip(1),
      ],
      [wall('free', Offset.zero, const Offset(5, 0))],
    ]) {
      final result = ArchitectWallExteriorResolver.resolveStorey(
        project(input).activeStorey,
      );
      expect(
        result.walls.every(
          (w) => !w.exteriorResolved && w.exteriorSide == WallExteriorSide.left,
        ),
        isTrue,
      );
    }
  });

  test(
    'A wall crossing the envelope stays unresolved instead of splitting',
    () {
      final input = [
        ...rectangle(),
        wall('mixed', const Offset(3, -2), const Offset(3, 2)),
      ];
      final result = ArchitectWallExteriorResolver.resolveStorey(
        project(input).activeStorey,
      );
      expect(result.walls.last.exteriorResolved, isFalse);
      expect(result.walls.length, 5);
    },
  );

  test('Disconnected buildings and nested rooms use all bounded faces', () {
    final inner = [
      wall('a', const Offset(1, 1), const Offset(2, 1)),
      wall('b', const Offset(2, 1), const Offset(2, 2)),
      wall('c', const Offset(2, 2), const Offset(1, 2)),
      wall('d', const Offset(1, 2), const Offset(1, 1)),
    ];
    final input = [
      ...rectangle(),
      ...rectangle(shift: const Offset(10, 0), prefix: 'other'),
      ...inner,
    ];
    final result = ArchitectWallExteriorResolver.resolveStorey(
      project(input).activeStorey,
    );
    expect(
      result.walls.take(8).every((w) => w.isExterior && w.exteriorResolved),
      isTrue,
    );
    expect(
      result.walls.skip(8).every((w) => w.isInterior && w.exteriorResolved),
      isTrue,
    );
  });

  test(
    'Curved contours resolve and flipping retains the physical core arc',
    () {
      final curved = wall('arc', Offset.zero, const Offset(4, 0)).copyWith(
        arcBulge: 1,
        layers: const [
          ArchitectMaterialLayer(
            id: 'ins',
            material: ArchitectMaterial.eps,
            role: ArchitectLayerRole.insulation,
            thickness: .12,
          ),
          ArchitectMaterialLayer(
            id: 'core',
            material: ArchitectMaterial.brick,
            role: ArchitectLayerRole.core,
            thickness: .25,
          ),
        ],
        thickness: .37,
      );
      final offset =
          curved.centerLineOffset -
          curved.exteriorSign * curved.coreAsymmetry / 2;
      final close = wall('close', curved.coreCenterEnd, curved.coreCenterStart);
      final result = ArchitectWallExteriorResolver.resolveStorey(
        project([curved, close]).activeStorey,
      );
      final next = result.walls.first;
      expect(next.exteriorResolved, isTrue);
      expect(next.exteriorSide, WallExteriorSide.right);
      final newOffset =
          next.centerLineOffset - next.exteriorSign * next.coreAsymmetry / 2;
      for (final t in [0.0, .25, .5, .75, 1.0]) {
        expect(
          (curved.arc!.pointAt(t, leftOffset: offset) -
                  next.arc!.pointAt(t, leftOffset: newOffset))
              .distance,
          lessThan(1e-7),
        );
      }
    },
  );

  for (final reference in WallReferenceLine.values) {
    test(
      'Automatic orientation keeps the core and openings fixed: $reference',
      () {
        final input = rectangle().map((w) {
          var a = w.copyWith(
            referenceLine: reference,
            thickness: .37,
            layers: const [
              ArchitectMaterialLayer(
                id: 'ins',
                material: ArchitectMaterial.eps,
                role: ArchitectLayerRole.insulation,
                thickness: .12,
              ),
              ArchitectMaterialLayer(
                id: 'core',
                material: ArchitectMaterial.brick,
                role: ArchitectLayerRole.core,
                thickness: .25,
              ),
            ],
          );
          final shift = w.startPoint - a.coreCenterStart;
          a = a.copyWith(
            startPoint: a.startPoint + shift,
            endPoint: a.endPoint + shift,
          );
          return a.addDoor(
            ArchitectDoor(
              id: 'door${w.id}',
              wallId: w.id,
              offsetRatio: .5,
              uuid: 'door${w.id}',
            ),
          );
        }).toList();
        final result = ArchitectWallExteriorResolver.resolveStorey(
          project(input).activeStorey,
        );
        for (var i = 0; i < input.length; i++) {
          final a = input[i], b = result.walls[i];
          expect(b.exteriorSide, WallExteriorSide.right);
          expect(
            (a.coreCenterStart - b.coreCenterStart).distance,
            lessThan(1e-8),
          );
          expect((a.coreCenterEnd - b.coreCenterEnd).distance, lessThan(1e-8));
          expect(b.doors.single.toJson(), a.doors.single.toJson());
        }
      },
    );
  }

  test(
    'Log tails do not change the envelope or make facade ends unresolved',
    () {
      const tail = .30;
      final input =
          [
                wall('0', const Offset(-tail, 0), const Offset(6 + tail, 0)),
                wall('1', const Offset(6, -tail), const Offset(6, 4 + tail)),
                wall('2', const Offset(6 + tail, 4), const Offset(-tail, 4)),
                wall('3', const Offset(0, 4 + tail), const Offset(0, -tail)),
              ]
              .map(
                (w) => w.copyWith(
                  thickness: .24,
                  system: const ArchitectWallSystem(
                    kind: ArchitectWallSystemKind.roundLogs,
                  ),
                  systemPlacement: const ArchitectWallSystemPlacement(
                    startTail: .18,
                    endTail: .18,
                  ),
                  layers: const [
                    ArchitectMaterialLayer(
                      id: 'core',
                      material: ArchitectMaterial.timber,
                      role: ArchitectLayerRole.core,
                      thickness: .24,
                    ),
                  ],
                ),
              )
              .toList();
      final result = ArchitectWallExteriorResolver.resolveStorey(
        project(input).activeStorey,
      );
      expect(
        result.walls.every(
          (w) => w.exteriorResolved && w.exteriorSide == WallExteriorSide.right,
        ),
        isTrue,
      );
    },
  );

  test(
    'Connected reference corners resolve even when finish offsets separate core end caps',
    () {
      for (final ref in [WallReferenceLine.inner, WallReferenceLine.outer]) {
        final input = rectangle()
            .map(
              (w) => w.copyWith(
                referenceLine: ref,
                thickness: .37,
                layers: const [
                  ArchitectMaterialLayer(
                    id: 'ins',
                    material: ArchitectMaterial.eps,
                    role: ArchitectLayerRole.insulation,
                    thickness: .12,
                  ),
                  ArchitectMaterialLayer(
                    id: 'core',
                    material: ArchitectMaterial.brick,
                    role: ArchitectLayerRole.core,
                    thickness: .25,
                  ),
                ],
              ),
            )
            .toList();
        final result = ArchitectWallExteriorResolver.resolveStorey(
          project(input).activeStorey,
        );
        expect(
          result.walls.every((w) => w.exteriorResolved && w.isExterior),
          isTrue,
          reason: '$ref',
        );
        final again = ArchitectWallExteriorResolver.resolveStorey(
          result.copyWith(walls: [...result.walls]),
        );
        expect(
          again.walls.every((w) => w.exteriorResolved && w.isExterior),
          isTrue,
        );
        final layers = ArchitectWallLayers.build(
          again.walls,
          ArchitectWallType.standardCatalog(),
        );
        for (var i = 0; i < again.walls.length; i++) {
          final coreNode = ArchitectWallConnectionPolicy.coreJunction(
            again.walls[i],
            again.walls[(i + 1) % again.walls.length],
          );
          expect(coreNode, isNotNull);
          expect(layers.core.contains(coreNode!), isTrue, reason: '$ref / $i');
        }
        for (var i = 0; i < input.length; i++) {
          expect(
            (input[i].coreCenterStart - result.walls[i].coreCenterStart)
                .distance,
            lessThan(1e-7),
          );
        }
      }
    },
  );

  test('Closure and all automatic changes share one history entry', () {
    final input = rectangle();
    final controller = ArchitectCommandController(
      project(input.take(3).toList()),
    );
    addTearDown(controller.dispose);
    final before = controller.project;
    controller.execute(CreateArchitectWall(storeyId: 's', wall: input.last));
    final closed = controller.project;
    expect(closed.activeStorey.walls.every((w) => w.exteriorResolved), isTrue);
    expect(controller.undoCount, 1);
    controller.undo();
    expect(identical(controller.project, before), isTrue);
    controller.redo();
    expect(identical(controller.project, closed), isTrue);
  });

  test(
    'Manual location and side are independent and survive edits and saving',
    () {
      final controller = ArchitectCommandController(
        project(rectangle().take(3).toList()),
      );
      addTearDown(controller.dispose);
      controller.execute(
        CreateArchitectWall(storeyId: 's', wall: rectangle().last),
      );
      controller.execute(
        const MirrorArchitectWalls(storeyId: 's', wallIds: {'0'}),
      );
      expect(
        controller.project.activeStorey.walls.first.exteriorSideMode,
        WallResolutionMode.manual,
      );
      controller.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'0'},
          textValues: {'location': 'interior'},
        ),
      );
      var w = controller.project.activeStorey.walls.first;
      expect(w.isInterior, isTrue);
      expect(w.locationMode, WallResolutionMode.manual);
      expect(w.exteriorSide, WallExteriorSide.left);
      controller.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'0'},
          textValues: {'locationMode': 'automatic'},
        ),
      );
      w = controller.project.activeStorey.walls.first;
      expect(w.isExterior, isTrue);
      expect(w.exteriorSide, WallExteriorSide.left);
      controller.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'0'},
          textValues: {'exteriorSideMode': 'automatic'},
        ),
      );
      w = controller.project.activeStorey.walls.first;
      expect(w.exteriorSide, WallExteriorSide.right);
      final saved = ArchitectProject.fromJson(controller.project.toJson());
      expect(saved.activeStorey.walls.first.toJson(), w.toJson());
    },
  );

  test(
    'A newly completed outer envelope reclassifies earlier automatic walls',
    () {
      final inner = rectangle(prefix: 'inner')
          .map(
            (w) => w.copyWith(
              startPoint: w.startPoint * .3 + const Offset(1, 1),
              endPoint: w.endPoint * .3 + const Offset(1, 1),
            ),
          )
          .toList();
      final controller = ArchitectCommandController(project([]));
      addTearDown(controller.dispose);
      controller.executeBatch([
        for (final w in inner) CreateArchitectWall(storeyId: 's', wall: w),
      ]);
      expect(
        controller.project.activeStorey.walls.every((w) => w.isExterior),
        isTrue,
      );
      controller.executeBatch([
        for (final w in rectangle())
          CreateArchitectWall(storeyId: 's', wall: w),
      ]);
      expect(
        controller.project.activeStorey.walls
            .take(4)
            .every((w) => w.isInterior),
        isTrue,
      );
      expect(
        controller.project.activeStorey.walls
            .skip(4)
            .every((w) => w.isExterior),
        isTrue,
      );
    },
  );

  test(
    'Manual courtyard facades survive automatic analysis and serialization',
    () {
      final inner = rectangle(prefix: 'court')
          .map(
            (w) => w.copyWith(
              startPoint: w.startPoint * .3 + const Offset(1, 1),
              endPoint: w.endPoint * .3 + const Offset(1, 1),
              locationMode: WallResolutionMode.manual,
              exteriorSideMode: WallResolutionMode.manual,
              exteriorSide: WallExteriorSide.left,
            ),
          )
          .toList();
      final floor = ArchitectWallExteriorResolver.resolveStorey(
        project([...rectangle(), ...inner]).activeStorey,
      );
      for (final w in floor.walls.skip(4)) {
        final restored = ArchitectWall.fromJson(w.toJson());
        expect(restored.isExterior, isTrue);
        expect(restored.exteriorSide, WallExteriorSide.left);
        expect(restored.locationMode, WallResolutionMode.manual);
        expect(restored.exteriorSideMode, WallResolutionMode.manual);
      }
    },
  );

  test('Split, mirror and duplicate retain independent manual modes', () {
    final source = wall('w', Offset.zero, const Offset(6, 0)).copyWith(
      locationMode: WallResolutionMode.manual,
      exteriorSideMode: WallResolutionMode.manual,
    );
    final controller = ArchitectCommandController(project([source]));
    addTearDown(controller.dispose);
    controller.execute(
      const SplitArchitectWall(
        storeyId: 's',
        wallId: 'w',
        newWallId: 'part',
        ratio: .5,
      ),
    );
    controller.execute(
      const MirrorArchitectElements(
        storeyId: 's',
        elementIds: {'part'},
        origin: Offset.zero,
        direction: Offset(1, 0),
        isDuplicate: true,
        idMap: {'part': 'copy'},
      ),
    );
    for (final w in controller.project.activeStorey.walls) {
      expect(w.locationMode, WallResolutionMode.manual);
      expect(w.exteriorSideMode, WallResolutionMode.manual);
    }
    expect(
      controller.project.activeStorey.walls.last.exteriorSide,
      WallExteriorSide.right,
    );
  });

  test(
    'New interior presets have explicit materials and no bearing metadata',
    () {
      final types = ArchitectWallType.standardCatalog(includeSpecial: true);
      final brick = types.firstWhere((t) => t.id == 'int_25_brick');
      final aerated = types.firstWhere((t) => t.id == 'int_10_aerated');
      expect(brick.resolvedLocation, ArchitectWallLocation.interior);
      expect(brick.resolvedLayers.single.material, ArchitectMaterial.brick);
      expect(brick.totalThickness, .25);
      expect(aerated.resolvedLocation, ArchitectWallLocation.interior);
      expect(
        aerated.resolvedLayers.single.material,
        ArchitectMaterial.aeratedConcrete,
      );
      expect(aerated.totalThickness, .1);
      for (final t in types) {
        expect(t.toJson().containsKey('loadBearing'), isFalse);
        expect(
          ArchitectWallType.fromJson(
            t.toJson(),
          ).resolvedLayers.map((l) => l.toJson()),
          t.resolvedLayers.map((l) => l.toJson()),
        );
      }
      expect(
        wall(
          'w',
          Offset.zero,
          const Offset(1, 0),
        ).toJson().containsKey('loadBearing'),
        isFalse,
      );
    },
  );
}
