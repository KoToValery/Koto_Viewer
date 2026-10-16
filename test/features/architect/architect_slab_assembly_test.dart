import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_assemblies.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_geometry.dart';

const footprint = [Offset(0, 0), Offset(10, 0), Offset(10, 4), Offset(0, 4)];
const slab = ArchitectSlab(id: 'slab', polygon: footprint, thickness: .2);
const cut = ArchitectSection(
  id: 'section',
  start: Offset(-1, 2),
  end: Offset(11, 2),
);

ArchitectProject slabProject({
  ArchitectSlab plate = slab,
  ArchitectSlabAssembly? assembly,
  List<ArchitectOpening> openings = const [],
  double elevation = 0,
  List<ArchitectSlab>? slabs,
  List<ArchitectWall> walls = const [],
}) => ArchitectProject(
  id: 'p',
  name: 'Test',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  slabAssemblies: [?assembly],
  storeys: [
    ArchitectStorey(
      id: 's',
      name: 'Storey',
      elevation: elevation,
      slabs:
          slabs ??
          [assembly == null ? plate : plate.copyWith(assemblyId: assembly.id)],
      openings: openings,
      walls: walls,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all nine catalogs validate with stable language-independent data', () {
    expect(ArchitectSlabCatalog.presets, hasLength(9));
    for (final a in ArchitectSlabCatalog.presets) {
      a.validate();
      expect(ArchitectSlabAssembly.fromJson(a.toJson()).toJson(), a.toJson());
      expect(a.customName, isEmpty);
    }
    final basement = ArchitectSlabCatalog.preset(SlabUsage.basement);
    expect(
      basement.above.where((l) => l.material == SlabMaterial.xps),
      isEmpty,
    );
    expect(
      basement.below
          .singleWhere((l) => l.material == SlabMaterial.xps)
          .thickness,
      .05,
    );
  });

  test('legacy slabs remain bare with unchanged concrete datum', () {
    final restored = ArchitectSlab.fromJson({
      'id': 'old',
      'polygon': [],
      'thickness': .16,
    });
    expect(restored.assemblyId, isNull);
    expect(restored.coreTopOffset, 0);
    final json = slabProject().toJson()
      ..remove('slabAssemblies')
      ..remove('sections')
      ..remove('slabCompositionNumbers');
    final project = ArchitectProject.fromJson(json);
    final surface = ArchitectSlabGeometry.surfaces(
      project,
      project.activeStorey,
      project.activeStorey.slabs.first,
    );
    expect(surface, hasLength(1));
    expect(surface.single.topAt(Offset.zero), 0);
    expect(surface.single.bottomAt(Offset.zero), -.2);
  });

  test(
    'shared edits update all linked plates and onlyThis detaches a copy',
    () {
      final a = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
      var p = slabProject(
        assembly: a,
        slabs: [
          slab.copyWith(assemblyId: a.id),
          slab.copyWith(id: 'other', assemblyId: a.id, thickness: .25),
        ],
      );
      final modified = a.copyWith(
        above: [a.above.first.copyWith(thickness: .04), ...a.above.skip(1)],
      );
      p = ArchitectSlabAssemblies.assign(
        p,
        's',
        'slab',
        modified,
        onlyThis: false,
        thickness: .2,
        coreTopOffset: -.1,
      );
      expect(p.slabAssemblies, hasLength(1));
      expect(
        ArchitectSlabAssemblies.of(
          p,
          p.activeStorey.slabs.last,
        )!.above.first.thickness,
        .04,
      );
      expect(p.activeStorey.slabs.last.thickness, .25);
      p = ArchitectSlabAssemblies.assign(
        p,
        's',
        'slab',
        a,
        onlyThis: true,
        thickness: .2,
        coreTopOffset: -.1,
      );
      expect(p.slabAssemblies, hasLength(2));
      expect(
        p.activeStorey.slabs.first.assemblyId,
        isNot(p.activeStorey.slabs.last.assemblyId),
      );
      expect(
        ArchitectSlabAssemblies.of(
          p,
          p.activeStorey.slabs.last,
        )!.above.first.thickness,
        .04,
      );
    },
  );

  test('existing project assembly can be assigned to another bare slab', () {
    final a = ArchitectSlabCatalog.preset(SlabUsage.basement);
    final p = slabProject(
      assembly: a,
      slabs: [
        slab,
        slab.copyWith(id: 'other', assemblyId: a.id),
      ],
    );
    final next = ArchitectSlabAssemblies.assign(
      p,
      's',
      slab.id,
      a,
      onlyThis: false,
      thickness: .2,
      coreTopOffset: 0,
    );
    expect(next.activeStorey.slabs.map((s) => s.assemblyId).toSet(), {a.id});
    expect(next.slabAssemblies, hasLength(1));
  });

  test(
    'content numbers share across copied types but distinguish concrete thickness',
    () {
      final a = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
      final clone = a.copyWith(id: 'copy', customName: 'User name');
      var p = slabProject(
        assembly: a,
        slabs: [
          slab.copyWith(assemblyId: a.id),
          slab.copyWith(id: 'copy-slab', assemblyId: clone.id),
          slab.copyWith(id: 'thick', assemblyId: a.id, thickness: .25),
        ],
      ).copyWith(slabAssemblies: [a, clone]);
      p = ArchitectSlabAssemblies.resolve(p);
      final plates = p.activeStorey.slabs;
      expect(
        ArchitectSlabAssemblies.number(p, plates[0]),
        ArchitectSlabAssemblies.number(p, plates[1]),
      );
      expect(
        ArchitectSlabAssemblies.number(p, plates[0]),
        isNot(ArchitectSlabAssemblies.number(p, plates[2])),
      );
      final registry = Map.of(p.slabCompositionNumbers);
      p = ArchitectSlabAssemblies.assign(
        p,
        's',
        slab.id,
        a.copyWith(above: a.above.skip(1).toList()),
        onlyThis: false,
        thickness: .2,
        coreTopOffset: 0,
      );
      for (final e in registry.entries) {
        expect(p.slabCompositionNumbers[e.key], e.value);
      }
    },
  );

  test('2% wedge over 10 m varies 200 mm and concrete top stays fixed', () {
    final a = ArchitectSlabCatalog.preset(SlabUsage.warmRoof);
    final p = slabProject(
      assembly: a,
      plate: slab.copyWith(slopeDirection: 0, coreTopOffset: -.12),
      elevation: 5,
    );
    final surfaces = ArchitectSlabGeometry.surfaces(
      p,
      p.activeStorey,
      p.activeStorey.slabs.first,
    );
    final wedge = surfaces.singleWhere((s) => s.layer.slopePercent > 0);
    expect(wedge.thicknessAt(const Offset(10, 2)), closeTo(.03, 1e-9));
    expect(wedge.thicknessAt(const Offset(0, 2)), closeTo(.23, 1e-9));
    final concrete = surfaces.singleWhere((s) => s.layer.id == 'core');
    expect(concrete.topAt(Offset.zero), closeTo(4.88, 1e-9));
    expect(concrete.topAt(const Offset(10, 2)), closeTo(4.88, 1e-9));
    final other = slabProject(
      assembly: a,
      plate: slab.copyWith(slopeDirection: math.pi),
    );
    final opposite = ArchitectSlabGeometry.surfaces(
      other,
      other.activeStorey,
      other.activeStorey.slabs.first,
    ).singleWhere((s) => s.layer.slopePercent > 0);
    expect(opposite.thicknessAt(const Offset(0, 2)), closeTo(.03, 1e-9));
  });

  test(
    'rejects multiple wedges, lower wedges, missing directions and invalid dimensions',
    () {
      final roof = ArchitectSlabCatalog.preset(SlabUsage.warmRoof);
      final wedge = roof.above.last;
      expect(
        () => roof.copyWith(below: [wedge]).validate(),
        throwsArgumentError,
      );
      expect(
        () => roof
            .copyWith(
              above: [
                wedge,
                wedge.copyWith(id: 'second'),
              ],
            )
            .validate(),
        throwsArgumentError,
      );
      expect(
        () => roof
            .copyWith(above: [wedge.copyWith(thickness: double.nan)])
            .validate(),
        throwsArgumentError,
      );
      expect(
        () => ArchitectSlabAssemblies.resolve(slabProject(assembly: roof)),
        throwsArgumentError,
      );
    },
  );

  test('opening splits section and removes same area from 3D footprint', () {
    final p = slabProject(
      openings: [
        const ArchitectOpening(
          id: 'hole',
          boundary: [Offset(4, 1), Offset(6, 1), Offset(6, 3), Offset(4, 3)],
        ),
      ],
    );
    expect(ArchitectSlabGeometry.intervals(p.activeStorey, slab, cut), [
      (1.0, 5.0),
      (7.0, 11.0),
    ]);
    double area(List<Offset> poly) {
      var sum = 0.0;
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i], b = poly[(i + 1) % poly.length];
        sum += a.dx * b.dy - a.dy * b.dx;
      }
      return sum.abs() / 2;
    }

    final pieces = ArchitectSlabGeometry.footprint(p.activeStorey, slab);
    expect(pieces.fold(0.0, (a, poly) => a + area(poly)), closeTo(36, 1e-8));
    expect(
      pieces.any(
        (poly) => ArchitectSlabGeometry.inside(poly, const Offset(5, 2)),
      ),
      isFalse,
    );
  });

  test(
    'concave outline returns disjoint strips and oblique cuts retain local heights',
    () {
      final plate = slab.copyWith(
        polygon: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 4),
          Offset(6, 4),
          Offset(6, 1),
          Offset(4, 1),
          Offset(4, 4),
          Offset(0, 4),
        ],
      );
      final p = slabProject(plate: plate);
      expect(ArchitectSlabGeometry.intervals(p.activeStorey, plate, cut), [
        (1.0, 5.0),
        (7.0, 11.0),
      ]);
      final roof = ArchitectSlabCatalog.preset(SlabUsage.warmRoof);
      final r = slabProject(
        assembly: roof,
        plate: slab.copyWith(slopeDirection: 0),
      );
      final diagonal = cut.copyWith(
        start: const Offset(0, 0),
        end: const Offset(10, 4),
      );
      final geometry = ArchitectBuildingSection.build(r, diagonal);
      expect(geometry.regions.where((r) => r.slab), hasLength(6));
      expect(
        geometry.regions
            .where((r) => r.material == SlabMaterial.concrete)
            .single
            .path
            .contains(const Offset(2, -.1)),
        isTrue,
      );
    },
  );

  test(
    'wall section keeps the window void rather than filling the whole wall',
    () {
      final wall = ArchitectWall(
        id: 'w',
        startPoint: const Offset(0, 2),
        endPoint: const Offset(10, 2),
        height: 3,
        windows: [
          const ArchitectWindow(
            id: 'window',
            wallId: 'w',
            uuid: 'u',
            offsetRatio: .5,
            width: 2,
            height: 1.2,
            sillHeight: 1,
          ),
        ],
      );
      final p = slabProject(slabs: [], walls: [wall]);
      final geometry = ArchitectBuildingSection.build(p, cut);
      expect(geometry.regions, isNotEmpty);
      expect(
        geometry.regions.any((r) => r.path.contains(const Offset(2, 1.5))),
        isTrue,
      );
      expect(
        geometry.regions.any((r) => r.path.contains(const Offset(6, 2.6))),
        isTrue,
      );
    },
  );

  test(
    'saved detail tracks updates, loses deleted source, restores via undo and survives JSON',
    () {
      final assembly = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
      final detail = const ArchitectSlabDetail(
        id: 'd',
        slabId: 'slab',
        station: 3,
        fallbackElevation: .1,
      );
      final p = slabProject(assembly: assembly).copyWith(
        sections: [
          cut.copyWith(details: [detail]),
        ],
      );
      final controller = ArchitectCommandController(p);
      addTearDown(controller.dispose);
      final changed = assembly.copyWith(
        above: [
          assembly.above.first.copyWith(thickness: .03),
          ...assembly.above.skip(1),
        ],
      );
      controller.commit(
        ArchitectSlabAssemblies.assign(
          controller.project,
          's',
          slab.id,
          changed,
          onlyThis: false,
          thickness: .25,
          coreTopOffset: -.1,
        ),
      );
      final saved = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(controller.project.toJson()))
            as Map<String, dynamic>,
      );
      expect(saved.toJson(), controller.project.toJson());
      final source = ArchitectBuildingSection.source(
        saved,
        saved.sections.single,
        saved.sections.single.details.single,
      )!;
      expect(source.slab.thickness, .25);
      expect(
        ArchitectSlabAssemblies.of(saved, source.slab)!.above.first.thickness,
        .03,
      );
      controller.commit(
        controller.project.updateActiveStorey(
          controller.project.activeStorey.copyWith(slabs: []),
        ),
      );
      expect(
        ArchitectBuildingSection.source(controller.project, cut, detail),
        isNull,
      );
      controller.undo();
      expect(
        ArchitectBuildingSection.source(controller.project, cut, detail),
        isNotNull,
      );
      controller.undo();
      expect(controller.project.activeStorey.slabs.single.thickness, .2);
      controller.redo();
      expect(controller.project.activeStorey.slabs.single.thickness, .25);
      final moved = cut.copyWith(
        start: const Offset(-1, 20),
        end: const Offset(11, 20),
      );
      expect(
        ArchitectBuildingSection.source(controller.project, moved, detail),
        isNull,
      );
    },
  );

  test(
    'personal library retains copies without changing project types',
    () async {
      SharedPreferences.setMockInitialValues({});
      final a = ArchitectSlabCatalog.preset(SlabUsage.foundation);
      expect(await ArchitectSlabLibrary.save(a), isTrue);
      expect((await ArchitectSlabLibrary.load()).single.toJson(), a.toJson());
      expect(
        await ArchitectSlabLibrary.save(a.copyWith(customName: 'Custom')),
        isTrue,
      );
      expect(await ArchitectSlabLibrary.load(), hasLength(1));
    },
  );

  test('slab rotations carry the fall direction with the footprint', () {
    final s = slab.copyWith(slopeDirection: .3);
    final result = ArchitectElementTool().rotateElementById(
      slabProject(plate: s).activeStorey,
      s.id,
    );
    expect(result.slabs.single.slopeDirection, closeTo(.3 + math.pi / 2, 1e-9));
  });

  test(
    'section keeps distinct storey elevations and rotated column geometry',
    () {
      final lower = slabProject().activeStorey;
      final upper = lower.copyWith(
        id: 'upper',
        elevation: 3,
        slabs: [slab.copyWith(id: 'upper-slab')],
        columns: [
          const ArchitectColumn(
            id: 'c',
            position: Offset(5, 2),
            width: 2,
            depth: .4,
            rotationDeg: 90,
            height: 2,
            baseOffset: .1,
          ),
        ],
      );
      final p = slabProject().copyWith(storeys: [lower, upper]);
      final geometry = ArchitectBuildingSection.build(p, cut);
      expect(
        geometry.regions
            .singleWhere((r) => r.sourceId == 'upper-slab')
            .path
            .contains(const Offset(3, 2.9)),
        isTrue,
      );
      expect(
        geometry.regions
            .singleWhere((r) => r.sourceId == 'slab')
            .path
            .contains(const Offset(3, -.1)),
        isTrue,
      );
      final column = geometry.regions
          .singleWhere((r) => r.sourceId == 'c')
          .path
          .getBounds();
      // Skia paths store coordinates with single-precision accuracy.
      expect(column.width, closeTo(.4, 1e-6));
      expect(column.top, closeTo(3.1, 1e-6));
      expect(column.bottom, closeTo(5.1, 1e-6));
    },
  );

  test(
    'finish packages replace adhesive and wet membrane without losing thermal layers',
    () {
      final a = ArchitectSlabCatalog.preset(SlabUsage.foundation);
      final old = [
        ...ArchitectSlabCatalog.finish(wet: true),
        ...a.above.where((l) => !l.finishPackage),
      ];
      final parquet = [
        ...ArchitectSlabCatalog.finish(parquet: true),
        ...old.where((l) => !l.finishPackage),
      ];
      final changed = a.copyWith(above: parquet);
      changed.validate();
      expect(
        changed.above.any((l) => l.material == SlabMaterial.tileAdhesive),
        isFalse,
      );
      expect(
        changed.above
            .singleWhere((l) => l.material == SlabMaterial.floorInsulation)
            .thickness,
        .1,
      );
      expect(changed.below, a.below);
      expect(changed.above.where((l) => l.finishPackage), hasLength(2));
    },
  );
}
