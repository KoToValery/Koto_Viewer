import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/staircase_inventory.dart';
import 'package:kotoview/src/features/structural_designer/analysis/support_placement_rules.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_geometry_units.dart';
import 'package:kotoview/src/features/structural_designer/analysis/initial_scheme_generator.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'package:kotoview/src/features/structural_designer/models/slab_topology.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/widgets/staircase_setup_dialog.dart';
import 'initial_scheme_generator_test.dart' as scheme;

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
const core = StaircaseCore(
  id: 'A',
  name: 'A',
  startStoreyId: 'g',
  endStoreyId: 'f2',
);
StructuralProject building({bool secondHole = true, bool groundZone = true}) {
  final zone = box(2, 2, 3, 4);
  StructuralSlab plate(String id, {bool hole = false}) => StructuralSlab(
    id: id,
    isFloorSlab: true,
    polygon: box(0, 0, 12, 12),
    openings: hole ? [box(3, 3, 1, 2)] : [],
    openingTypes: hole ? [SlabOpeningType.staircase] : [],
  );
  return StructuralProject(
    staircaseReviewComplete: true,
    staircases: [core],
    storeys: [
      StoreyLevel(
        id: 'f2',
        name: 'last arrival',
        elevation: 5.6,
        slabs: [plate('s2', hole: secondHole)],
        staircaseZones: {'A': zone},
      ),
      StoreyLevel(
        id: 'g',
        name: 'ground',
        slabs: [plate('sg')],
        staircaseZones: groundZone ? {'A': zone} : {},
      ),
      StoreyLevel(
        id: 'roof',
        name: 'roof',
        elevation: 8.4,
        slabs: [plate('sr')],
      ),
      StoreyLevel(
        id: 'f1',
        name: 'middle',
        elevation: 2.8,
        slabs: [plate('s1', hole: true)],
        staircaseZones: {'A': zone},
      ),
    ],
    activeStoreyIndex: 1,
  );
}

void main() {
  test(
    'unsorted arrival floors are checked, solid ground and roof stay uncut',
    () {
      final p = building(),
          result = StaircaseInventory.evaluate(p, 1, requireReview: true);
      expect(result.ready, isTrue);
      expect(result.openings.map((r) => r.arrivalStoreyId), ['f1', 'f2']);
      expect(result.openings.map((r) => r.ownerStoreyId), ['f1', 'f2']);
      expect(p.storeys[1].slabs.single.openings, isEmpty);
      expect(p.storeys[2].slabs.single.openings, isEmpty);
      expect(
        StaircaseInventory.evaluate(
          building(secondHole: false),
          1,
        ).gaps.single.storeyId,
        'f2',
      );
    },
  );
  test('ground flight reservation is required without cutting its floor', () {
    final result = StaircaseInventory.evaluate(building(groundZone: false), 1);
    expect(result.gaps.single.requirement, StaircaseRequirement.circulation);
    expect(result.gaps.single.storeyId, 'g');
  });
  test(
    'an opening must match its own staircase and not be shared by two cores',
    () {
      var p = building();
      p = p.copyWith(
        staircases: [
          core,
          core.copyWith(name: 'other'),
        ],
      );
      expect(
        StaircaseInventory.evaluate(
          p,
          1,
        ).gaps.any((g) => g.requirement == StaircaseRequirement.scope),
        isTrue,
      );
      const b = StaircaseCore(
        id: 'B',
        name: 'B',
        startStoreyId: 'g',
        endStoreyId: 'f2',
      );
      p = building().copyWith(
        staircases: [core, b],
        storeys: [
          for (final s in building().storeys)
            s.copyWith(
              staircaseZones: {...s.staircaseZones, 'B': box(2, 2, 3, 4)},
            ),
        ],
      );
      expect(
        StaircaseInventory.evaluate(p, 1).gaps
            .where((g) => g.requirement == StaircaseRequirement.opening)
            .length,
        2,
      );
      p = building().copyWith(
        storeys: [
          for (final s in building().storeys)
            if (s.id == 'f2')
              s.copyWith(staircaseZones: {'A': box(7, 7, 3, 3)})
            else
              s,
        ],
      );
      expect(
        StaircaseInventory.evaluate(p, 1).gaps.single.requirement,
        StaircaseRequirement.opening,
      );
    },
  );
  test('explicit no-stairs review and deleted scope levels', () {
    expect(
      StaircaseInventory.evaluate(
        const StructuralProject(),
        1,
        requireReview: true,
      ).ready,
      isFalse,
    );
    expect(
      StaircaseInventory.evaluate(
        const StructuralProject(staircaseReviewComplete: true),
        1,
        requireReview: true,
      ).ready,
      isTrue,
    );
    final p = building();
    expect(
      StaircaseInventory.evaluate(
        p.copyWith(storeys: p.storeys.where((s) => s.id != 'f2').toList()),
        1,
      ).ready,
      isFalse,
    );
    final roof = p.storeys
        .singleWhere((s) => s.id == 'roof')
        .copyWith(staircaseZones: {'A': box(2, 2, 3, 4)});
    expect(p.staircaseZonesFor(roof), isEmpty);
  });
  test(
    'JSON persistence and metre conversion preserve independent circulation polygons',
    () {
      final p = building();
      final restored = StructuralProject.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      );
      expect(restored.staircaseReviewComplete, isTrue);
      expect(restored.staircases.single.endStoreyId, 'f2');
      expect(
        restored.storeys[1].staircaseZones['A'],
        p.storeys[1].staircaseZones['A'],
      );
      final metres = const StructuralGeometryUnits(
        100,
        Offset.zero,
      ).project(restored);
      expect(
        metres.storeys[1].staircaseZones['A']!.first,
        const Offset(.02, .02),
      );
      expect(metres.staircases.single.startStoreyId, 'g');
    },
  );
  test(
    'support policy reserves complete polygon footprint including touching boundaries',
    () {
      final floor = building().storeys[1];
      expect(
        SupportPlacementRules.circulationFits(box(2.5, 2.5, .3, .3), floor, 1),
        isFalse,
      );
      expect(
        SupportPlacementRules.circulationFits(box(1.7, 3, .3, .3), floor, 1),
        isFalse,
      );
      expect(
        SupportPlacementRules.circulationFits(box(1, 1, .3, .3), floor, 1),
        isTrue,
      );
    },
  );
  test(
    'generated and optimized supports respect zones at cm scale, missing upper hole blocks generation',
    () {
      final (fixture, runs) = scheme.fixture(scale: 100);
      const scope = StaircaseCore(
        id: 'A',
        name: 'A',
        startStoreyId: 'f',
        endStoreyId: 'upper',
      );
      final zone = box(960, 100, 80, 1400);
      final ground = fixture.activeStorey.copyWith(staircaseZones: {'A': zone});
      final upper = StoreyLevel(
        id: 'upper',
        name: 'upper',
        elevation: 3,
        slabs: [
          StructuralSlab(
            id: 'top',
            isFloorSlab: true,
            polygon: box(0, 0, 2000, 1600),
            openings: [box(980, 200, 40, 100)],
            openingTypes: [SlabOpeningType.staircase],
          ),
        ],
        staircaseZones: {'A': zone},
      );
      final source = fixture.copyWith(
        storeys: [ground, upper],
        staircases: [scope],
        staircaseReviewComplete: true,
      );
      final result = InitialSchemeGenerator.generate(
        project: source,
        sourceProject: source,
        wallPairs: runs,
        scale: 100,
        options: const InitialSchemeOptions(
          maxSearchEvaluations: 40,
          searchVariants: 2,
        ),
      );
      expect(result.isEmpty, isFalse);
      for (final c in result.columns) {
        expect(
          SupportPlacementRules.circulationFits(c.polygonVertices, ground, 100),
          isTrue,
        );
      }
      for (final w in result.walls) {
        expect(
          SupportPlacementRules.circulationFits(w.polygonVertices, ground, 100),
          isTrue,
        );
      }
      final broken = source.copyWith(
        storeys: [
          ground,
          upper.copyWith(slabs: []),
        ],
      );
      expect(
        InitialSchemeGenerator.generate(
          project: source,
          sourceProject: broken,
          wallPairs: runs,
          scale: 100,
        ).isEmpty,
        isTrue,
      );
    },
  );
  test(
    'legacy ceiling opening retains its actual lower owner without cutting the roof',
    () {
      final p = building();
      final ground = p.storeys[1].copyWith(
        slabs: [
          p.storeys[3].slabs.single.copyWith(id: 'legacy', isFloorSlab: false),
        ],
      );
      final legacy = p.copyWith(
        storeys: [
          p.storeys[0],
          ground,
          p.storeys[2],
          p.storeys[3].copyWith(slabs: []),
        ],
      );
      final result = StaircaseInventory.evaluate(legacy, 1);
      expect(result.ready, isTrue);
      expect(result.openings.first.arrivalStoreyId, 'f1');
      expect(result.openings.first.ownerStoreyId, 'g');
    },
  );
  test(
    'wrong concrete level and existing supports in the circulation region block generation',
    () {
      final p = building();
      final wrong = p.copyWith(
        storeys: [
          for (final s in p.storeys)
            if (s.id == 'f2')
              s.copyWith(slabs: [s.slabs.single.copyWith(topElevation: 7)])
            else
              s,
        ],
      );
      expect(
        StaircaseInventory.evaluate(wrong, 1).gaps.single.requirement,
        StaircaseRequirement.opening,
      );
      final conflict = p.copyWith(
        storeys: [
          for (final s in p.storeys)
            if (s.id == 'g')
              s.copyWith(
                columns: [
                  const StructuralColumn(id: 'blocked', center: Offset(3, 3)),
                ],
              )
            else
              s,
        ],
      );
      expect(
        StaircaseInventory.evaluate(conflict, 1).gaps.single.requirement,
        StaircaseRequirement.support,
      );
    },
  );
  test('an offset upper stair zone blocks continuation of a lower support', () {
    const stair = StaircaseCore(
      id: 'A',
      name: 'A',
      startStoreyId: 'g',
      endStoreyId: 'u',
    );
    final upper = StoreyLevel(
      id: 'u',
      name: 'u',
      elevation: 2.8,
      staircaseZones: {'A': box(8, 2, 3, 4)},
      slabs: [
        StructuralSlab(
          id: 'arrival',
          isFloorSlab: true,
          polygon: box(0, 0, 12, 12),
          openings: [box(8.5, 3, 1, 2)],
          openingTypes: [SlabOpeningType.staircase],
        ),
        StructuralSlab(id: 'roof', polygon: box(0, 0, 12, 12)),
      ],
    );
    final source = StructuralProject(
      staircaseReviewComplete: true,
      staircases: [stair],
      activeStoreyIndex: 1,
      storeys: [
        StoreyLevel(
          id: 'g',
          name: 'g',
          staircaseZones: {'A': box(2, 2, 3, 4)},
          columns: [const StructuralColumn(id: 'c', center: Offset(9, 3))],
        ),
        upper,
      ],
    );
    expect(StaircaseInventory.evaluate(source, 1).ready, isTrue);
    final proposal = InitialSchemeGenerator.generate(
      project: source.copyWith(storeys: source.ceilingStoreys),
      sourceProject: source,
      wallPairs: [scheme.pair(const Offset(9, 1), const Offset(9, 11), 1)],
      scale: 1,
    );
    expect(proposal.columns, isEmpty);
    expect(proposal.rejectionReasons['staircase'], 1);
  });
  for (final lang in ['bg', 'en']) {
    testWidgets('setup mobile dialog targets actual owner floors: $lang', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l = await AppLocalizations.delegate.load(Locale(lang));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: StaircaseSetupDialog(
              project: building(secondHole: false),
              scale: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.staircaseOpeningMissing), findsOneWidget);
      expect(find.text(l.staircaseOpeningReady), findsOneWidget);
      expect(find.text(l.staircaseDrawOpening), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'invalid circulation geometry is rejected independently of slab cuts',
    () {
      final bad = [
        const Offset(0, 0),
        const Offset(2, 2),
        const Offset(2, 0),
        const Offset(0, 2),
      ];
      expect(StaircaseInventory.validZone(bad, 1), isFalse);
      expect(
        SlabTopologyAnalyzer.analyze(building().storeys[1].slabs, 1).issue,
        SlabTopologyIssue.none,
      );
    },
  );
}
