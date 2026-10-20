import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_solids.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';

const composition = ArchitectWallType(
  id: 'layered',
  name: 'Custom',
  usage: WallUsage.exterior,
  totalThickness: .395,
  location: ArchitectWallLocation.exterior,
  layers: [
    ArchitectMaterialLayer(
      id: 'render',
      material: ArchitectMaterial.render,
      role: ArchitectLayerRole.finish,
      thickness: .01,
    ),
    ArchitectMaterialLayer(
      id: 'eps',
      material: ArchitectMaterial.eps,
      role: ArchitectLayerRole.insulation,
      thickness: .12,
    ),
    ArchitectMaterialLayer(
      id: 'brick',
      material: ArchitectMaterial.brick,
      role: ArchitectLayerRole.core,
      thickness: .25,
    ),
    ArchitectMaterialLayer(
      id: 'plaster',
      material: ArchitectMaterial.plaster,
      role: ArchitectLayerRole.finish,
      thickness: .015,
    ),
  ],
);
ArchitectWall wall(String id, Offset a, Offset b) => ArchitectWall(
  id: id,
  startPoint: a,
  endPoint: b,
  wallTypeId: composition.id,
  layers: composition.layers,
  thickness: composition.totalThickness,
  location: composition.resolvedLocation,
);
ArchitectProject project(List<ArchitectWall> walls) => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: [ArchitectStorey(id: 's', name: '0', walls: walls)],
  activeStoreyId: 's',
  wallTypes: [composition],
);
double area(Path path) {
  var result = 0.0;
  for (final t in ArchitectPathSolid.extrude(
    path,
    0,
    1,
    const Color(0xffaaaaaa),
  )) {
    if ([t.v0, t.v1, t.v2].every((v) => v.z == 1)) {
      result +=
          ((t.v1.x - t.v0.x) * (t.v2.y - t.v0.y) -
                  (t.v1.y - t.v0.y) * (t.v2.x - t.v0.x))
              .abs() /
          2;
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Three metre walls retain every height band in a transverse section',
    () {
      final walls = [
        for (var i = 0; i < 4; i++)
          wall('wall-$i', Offset(0, i * 2), Offset(4, i * 2)).copyWith(
            plinth: const ArchitectWallPlinth(enabled: true, height: .85),
            windows: i != 2
                ? []
                : [
                    const ArchitectWindow(
                      id: 'window',
                      uuid: 'window',
                      wallId: 'wall-2',
                      offsetRatio: .5,
                      width: 1.2,
                      height: 1.2,
                      sillHeight: .85,
                    ),
                  ],
          ),
      ];
      final p = project(walls);
      final next = p.copyWith(storeys: [p.activeStorey.copyWith(height: 3)]);
      for (final x in [1.0, 2.0, 3.0]) {
        final section = ArchitectBuildingSection.build(
          next,
          ArchitectSection(id: 'cut', start: Offset(x, -1), end: Offset(x, 7)),
        );
        for (final w in walls) {
          final path = section.elementPaths[w.id]!;
          expect(path.getBounds().top, closeTo(0, 1e-5));
          expect(
            path.getBounds().bottom,
            closeTo(3, 1e-5),
            reason: '${w.id} at $x',
          );
          for (final z in [.4, 2.5, 2.9]) {
            expect(
              path.contains(Offset(w.startPoint.dy + 1, z)),
              isTrue,
              reason: '${w.id} at $x, height $z',
            );
          }
        }
      }
    },
  );
  test(
    'Legacy override is promoted without changing core or adding finishes',
    () {
      const old = ArchitectWall(
        id: 'old',
        startPoint: Offset.zero,
        endPoint: Offset(4, 0),
        thickness: .42,
        wallTypeId: 'ext_25_12_eps',
        insulationThicknessOverride: .17,
        referenceLine: WallReferenceLine.outer,
      );
      final type = composition.copyWith(layers: old.resolvedLayers);
      final next = SetArchitectWallComposition(
        type: type,
        storeyId: 's',
        wallIds: {'old'},
      ).apply(project([old])).activeStorey.walls.single;
      expect(next.thickness, old.thickness);
      expect(next.coreThickness, closeTo(.25, 1e-10));
      expect(next.coreCenterStart, old.coreCenterStart);
      expect(next.layers.length, 2);
      final reopened = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(project([next]).toJson()))
            as Map<String, dynamic>,
      );
      expect(reopened.activeStorey.walls.single.toJson(), next.toJson());
    },
  );
  test('Changing finishes keeps a core-centred reference fixed', () {
    final original = wall('w', Offset.zero, const Offset(4, 0));
    final thicker = composition.copyWith(
      layers: [
        composition.layers[0],
        composition.layers[1].copyWith(thickness: .2),
        ...composition.layers.skip(2),
      ],
    );
    final next = SetArchitectWallComposition(
      type: thicker,
      storeyId: 's',
      wallIds: {'w'},
    ).apply(project([original])).activeStorey.walls.single;
    expect(next.coreCenterStart, original.coreCenterStart);
    expect(next.coreCenterEnd, original.coreCenterEnd);
    expect(next.thickness, closeTo(.475, 1e-10));
  });
  test(
    'Type edit crosses storeys, local edit and plinth remain instance-local',
    () {
      final a = wall('a', Offset.zero, const Offset(4, 0)).copyWith(
        plinth: const ArchitectWallPlinth(
          enabled: true,
          height: .6,
          finish: ArchitectMaterial.stone,
        ),
      );
      final b = wall(
        'b',
        const Offset(0, 3),
        const Offset(4, 3),
      ).copyWith(plinth: const ArchitectWallPlinth(enabled: false, height: .8));
      final p = project([a, b]);
      final edited = SetArchitectWallComposition(
        type: composition.copyWith(
          id: 'local',
          layers: [
            ...composition.layers.take(3),
            composition.layers.last.copyWith(thickness: .02),
          ],
        ),
        storeyId: 's',
        wallIds: {'a'},
      ).apply(p);
      expect(edited.activeStorey.walls.last, same(b));
      final mixed = SetArchitectWallComposition(
        type: composition,
        preserveComposition: true,
        storeyId: 's',
        wallIds: {'a', 'b'},
        plinthPatch: const ArchitectWallPlinthPatch(
          finish: ArchitectMaterial.tile,
        ),
      ).apply(p);
      expect(mixed.activeStorey.walls.first.plinth.height, .6);
      expect(mixed.activeStorey.walls.first.plinth.enabled, isTrue);
      expect(mixed.activeStorey.walls.last.plinth.height, .8);
      expect(mixed.activeStorey.walls.last.plinth.enabled, isFalse);
      expect(
        mixed.activeStorey.walls.last.plinth.finish,
        ArchitectMaterial.tile,
      );
      final floors = p.copyWith(
        storeys: [
          p.activeStorey,
          ArchitectStorey(
            id: 'upper',
            name: '1',
            elevation: 3,
            walls: [a.copyWith(id: 'upper-wall')],
          ),
        ],
      );
      final changed = SetArchitectWallComposition(
        type: composition.copyWith(loadBearing: true),
        replaceTypeId: composition.id,
      ).apply(floors);
      expect(
        changed.storeys.every((s) => s.walls.every((w) => w.loadBearing)),
        isTrue,
      );
      expect(changed.activeStorey.walls.first.plinth.height, .6);
    },
  );
  test('Deletion of a used type requires a real replacement', () {
    final p = project([wall('w', Offset.zero, const Offset(4, 0))]);
    expect(
      () => DeleteArchitectWallType(composition.id).apply(p),
      throwsArgumentError,
    );
    final replacement = composition.copyWith(
      id: 'replacement',
      location: ArchitectWallLocation.interior,
    );
    final next = DeleteArchitectWallType(
      composition.id,
      replacementId: replacement.id,
    ).apply(p.copyWith(wallTypes: [composition, replacement]));
    expect(next.wallTypes.single.id, replacement.id);
    expect(next.activeStorey.walls.single.wallTypeId, replacement.id);
  });
  for (final layout in ['L', 'T', 'X', 'acute']) {
    test(
      'Material volumes cover the joined $layout body once, without overlaps',
      () {
        final walls = [
          wall('a', Offset.zero, const Offset(4, 0)),
          wall(
            'b',
            layout == 'L' ? const Offset(4, 0) : const Offset(2, 0),
            layout == 'acute'
                ? const Offset(4, 3)
                : layout == 'L'
                ? const Offset(4, 3)
                : const Offset(2, 3),
          ),
          if (layout == 'X') wall('c', const Offset(2, 0), const Offset(2, -3)),
        ];
        final layers = ArchitectWallLayers.build(walls, [composition]);
        var merged = Path();
        for (final r in layers.materials) {
          merged = Path.combine(PathOperation.union, merged, r.path);
        }
        expect(
          area(Path.combine(PathOperation.difference, layers.body, merged)),
          lessThan(.00001),
        );
        expect(
          layers.materials.fold(0.0, (v, r) => v + area(r.path)),
          closeTo(area(layers.body), .00002),
        );
        for (var i = 0; i < layers.materials.length; i++) {
          for (final b in layers.materials.skip(i + 1)) {
            expect(
              area(
                Path.combine(
                  PathOperation.intersect,
                  layers.materials[i].path,
                  b.path,
                ),
              ),
              lessThan(.000001),
            );
          }
        }
        final solids = ArchitectWallSolids.build(project(walls).activeStorey, [
          composition,
        ]);
        expect(solids, isNotEmpty);
        expect(solids.every((s) => s.triangles.isNotEmpty), isTrue);
        expect(
          solids.fold(0.0, (v, s) => v + area(s.path) * (s.top - s.bottom)),
          closeTo(area(layers.body) * 2.8, .0001),
        );
      },
    );
  }
  test('Plinth replaces the outer layers only on its own wall and below H', () {
    final a = wall('a', Offset.zero, const Offset(4, 0)).copyWith(
      plinth: const ArchitectWallPlinth(
        enabled: true,
        height: .5,
        finish: ArchitectMaterial.stone,
      ),
    );
    final b = wall('b', const Offset(0, 3), const Offset(4, 3));
    final solids = ArchitectWallSolids.build(project([a, b]).activeStorey, [
      composition,
    ]);
    expect(
      solids
          .where(
            (s) =>
                s.wall.id == 'a' && s.layer.material == ArchitectMaterial.xps,
          )
          .every((s) => s.top <= .5),
      isTrue,
    );
    expect(
      solids.any(
        (s) => s.wall.id == 'a' && s.layer.material == ArchitectMaterial.stone,
      ),
      isTrue,
    );
    expect(
      solids.any(
        (s) =>
            s.wall.id == 'b' &&
            [
              ArchitectMaterial.xps,
              ArchitectMaterial.stone,
            ].contains(s.layer.material),
      ),
      isFalse,
    );
  });
  test('A window cuts every physical layer at the correct height', () {
    final a = wall('a', Offset.zero, const Offset(4, 0)).copyWith(
      windows: [
        const ArchitectWindow(
          id: 'window',
          wallId: 'a',
          uuid: 'window',
          offsetRatio: .5,
          width: 1,
          height: 1,
          sillHeight: 1,
        ),
      ],
    );
    final solids = ArchitectWallSolids.build(project([a]).activeStorey, [
      composition,
    ]);
    for (final s in solids) {
      if (s.bottom >= 1 && s.top <= 2) {
        expect(s.path.contains(const Offset(2, 0)), isFalse);
      }
    }
    expect(
      solids.fold(0.0, (v, s) => v + area(s.path) * (s.top - s.bottom)),
      closeTo(4 * .395 * 2.8 - 1 * .395, .00002),
    );
  });
  test('Path extrusion caps a courtyard without filling its hole', () {
    final p = Path.combine(
      PathOperation.difference,
      Path()..addRect(const Rect.fromLTWH(0, 0, 5, 5)),
      Path()..addRect(const Rect.fromLTWH(1, 1, 3, 3)),
    );
    final mesh = ArchitectPathSolid.extrude(p, 0, 3, const Color(0xffaaaaaa));
    var capArea = 0.0;
    for (final t in mesh) {
      if ([t.v0, t.v1, t.v2].every((v) => (v.z - 3).abs() < 1e-8)) {
        final a = Offset(t.v0.x, t.v0.y),
            b = Offset(t.v1.x, t.v1.y),
            c = Offset(t.v2.x, t.v2.y);
        expect(p.contains((a + b + c) / 3), isTrue);
        capArea +=
            ((b - a).dx * (c - a).dy - (b - a).dy * (c - a).dx).abs() / 2;
      }
    }
    expect(capArea, closeTo(16, .00001));
  });
  test(
    'Equal materials publish one contour without ownership or height-band seams',
    () {
      final a = wall('a', Offset.zero, const Offset(4, 0));
      final b = wall('b', const Offset(4, 0), const Offset(4, 3));
      final plan = ArchitectWallLayers.build([a, b], [composition]);
      final core =
          plan.materialContours[(
            ArchitectMaterial.brick,
            ArchitectLayerRole.core,
          )]!;
      expect(core.computeMetrics().length, 1);
      expect(area(core), closeTo(area(plan.core), .00001));
      final host = a.copyWith(
        windows: [
          const ArchitectWindow(
            id: 'win',
            uuid: 'win',
            wallId: 'a',
            offsetRatio: .25,
            width: .6,
            height: 1.2,
            sillHeight: .8,
          ),
        ],
      );
      final section = ArchitectBuildingSection.build(
        project([host]),
        const ArchitectSection(
          id: 'cut',
          name: 'A',
          start: Offset(3, -1),
          end: Offset(3, 1),
        ),
      );
      expect(section.drawingRegions.length, lessThan(section.regions.length));
      expect(
        section.drawingRegions.every(
          (r) => (r.path.getBounds().height - 2.8).abs() < .00001,
        ),
        isTrue,
      );
      expect(section.elementPaths.keys, contains('a'));
    },
  );
  test(
    'A real upper slab trims the wall solids at its underside in 3D and section',
    () {
      final w = wall('w', Offset.zero, const Offset(4, 0));
      final p = project([w]);
      final floor = p.activeStorey.copyWith(
        slabs: [
          const ArchitectSlab(
            id: 'slab',
            polygon: [
              Offset(-1, -1),
              Offset(5, -1),
              Offset(5, 1),
              Offset(-1, 1),
            ],
            coreTopOffset: 2.8,
            thickness: .2,
          ),
        ],
      );
      final next = p.copyWith(storeys: [floor]);
      final solids = ArchitectWallSolids.build(floor, [
        composition,
      ], project: next);
      expect(
        solids
            .expand((s) => s.triangles)
            .expand((t) => [t.v0, t.v1, t.v2])
            .every((v) => v.z <= 2.600001),
        isTrue,
      );
      final cut = ArchitectSection(
        id: 'cut',
        name: 'A',
        start: const Offset(2, -1),
        end: const Offset(2, 1),
      );
      final section = ArchitectBuildingSection.build(next, cut);
      final walls = section.regions.where((r) => r.sourceId == 'w').toList();
      expect(walls, isNotEmpty);
      expect(walls.every((r) => r.path.getBounds().bottom <= 2.600001), isTrue);
    },
  );
  test(
    'A pitched roof caps each material at the same actual sloping underside',
    () {
      final w = wall('w', Offset.zero, const Offset(4, 0));
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 's',
        points: const [
          Offset(-1, -1),
          Offset(-1, 1),
          Offset(5, 1),
          Offset(5, -1),
        ],
        eavesEdgeIndex: 0,
        slopeDegrees: 12,
        baseElevationOffset: 2.4,
        eavesOverhang: 0,
        attachToWalls: false,
        placementResolved: true,
      );
      final floor = project([w]).activeStorey.copyWith(roofs: [roof]);
      final p = project([w]).copyWith(storeys: [floor]);
      final tris = ArchitectWallSolids.build(floor, [
        composition,
      ], project: p).expand((s) => s.triangles).toList();
      expect(tris, isNotEmpty);
      for (final v in tris.expand((t) => [t.v0, t.v1, t.v2])) {
        expect(
          v.z,
          lessThanOrEqualTo(
            roof.undersideElevationAt(Offset(v.x, v.y)) + .000001,
          ),
        );
      }
      expect(tris.any((t) => [t.v0, t.v1, t.v2].any((v) => v.z > 2.8)), isTrue);
    },
  );
}
