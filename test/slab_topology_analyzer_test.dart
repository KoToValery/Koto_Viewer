import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/slab_topology_analyzer.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/slab_topology.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/widgets/seismic_analysis_sheet.dart';

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
StructuralSlab slab(List<Offset> p, {List<List<Offset>> holes = const []}) =>
    StructuralSlab(id: 's', polygon: p, openings: holes);

void main() {
  test('common edges join transitively regardless of input order', () {
    final result = SlabTopologyAnalyzer.analyze([
      slab(box(0, 0, 2, 2)),
      slab(box(4, 0, 2, 2)),
      slab(box(2, 0, 2, 2)),
    ], 1);
    expect(result.issue, SlabTopologyIssue.none);
    expect(result.regionCount, 1);
  });
  test('point contact and a 1mm gap do not join regions', () {
    for (final second in [box(2, 2, 2, 2), box(2.001, 0, 2, 2)]) {
      final result = SlabTopologyAnalyzer.analyze([
        slab(box(0, 0, 2, 2)),
        slab(second),
      ], 1);
      expect(result.issue, SlabTopologyIssue.separateRegions);
      expect(result.regionCount, 2);
    }
  });
  test('duplicate, crossing and contained slabs are overlap conflicts', () {
    for (final second in [box(0, 0, 4, 4), box(1, 1, 1, 1), box(-1, 1, 6, 1)]) {
      expect(
        SlabTopologyAnalyzer.analyze([
          slab(box(0, 0, 4, 4)),
          slab(second),
        ], 1).issue,
        SlabTopologyIssue.overlappingSlabs,
      );
    }
  });
  test(
    'an island inside a hole is separate; infill sharing its boundary joins',
    () {
      final outer = slab(box(0, 0, 10, 10), holes: [box(2, 2, 6, 6)]);
      expect(
        SlabTopologyAnalyzer.analyze([outer, slab(box(3, 3, 4, 4))], 1).issue,
        SlabTopologyIssue.separateRegions,
      );
      expect(
        SlabTopologyAnalyzer.analyze([outer, slab(box(2, 2, 6, 6))], 1).issue,
        SlabTopologyIssue.none,
      );
    },
  );
  test('overlapping, outside and boundary-touching holes are rejected', () {
    for (final holes in [
      [box(1, 1, 3, 3), box(2, 2, 3, 3)],
      [box(8, 8, 4, 4)],
      [box(0, 2, 3, 3)],
      [box(1, 1, 2, 2), box(3, 1, 2, 2)],
    ]) {
      expect(
        SlabTopologyAnalyzer.analyze([
          slab(box(0, 0, 10, 10), holes: holes),
        ], 1).issue,
        SlabTopologyIssue.invalidGeometry,
      );
    }
  });
  test('self-crossing and backtracking contours are rejected', () {
    for (final ring in [
      [
        const Offset(0, 0),
        const Offset(3, 2),
        const Offset(0, 2),
        const Offset(2, 0),
      ],
      [
        const Offset(0, 0),
        const Offset(4, 0),
        const Offset(2, 0),
        const Offset(2, 4),
        const Offset(0, 4),
      ],
    ]) {
      expect(
        SlabTopologyAnalyzer.analyze([slab(ring)], 1).issue,
        SlabTopologyIssue.invalidGeometry,
      );
    }
  });
  test('closed rings and collinear forward vertices remain valid', () {
    expect(
      SlabTopologyAnalyzer.analyze([
        slab([
          const Offset(0, 0),
          const Offset(1, 0),
          const Offset(2, 0),
          const Offset(2, 2),
          const Offset(0, 2),
          const Offset(0, 0),
        ]),
      ], 1).issue,
      SlabTopologyIssue.none,
    );
  });
  test('rotation, winding, units and translation preserve topology', () {
    for (final scale in [1.0, 1000.0]) {
      Offset transform(Offset p) =>
          const Offset(1e7, -2e7) +
          Offset(
                p.dx * math.cos(.7) - p.dy * math.sin(.7),
                p.dx * math.sin(.7) + p.dy * math.cos(.7),
              ) *
              scale;
      final floors = [
        box(0, 0, 2, 2),
        box(2, 0, 2, 2),
      ].map((r) => slab(r.reversed.map(transform).toList())).toList();
      expect(
        SlabTopologyAnalyzer.analyze(floors, scale).issue,
        SlabTopologyIssue.none,
      );
    }
  });
  test('excessive geometry yields explicit computation limit', () {
    final floors = [for (var i = 0; i < 101; i++) slab(box(i * 2, 0, 1, 1))];
    expect(
      SlabTopologyAnalyzer.analyze(floors, 1).issue,
      SlabTopologyIssue.computationLimit,
    );
  });
  for (final conflict in [
    SlabTopologyIssue.separateRegions,
    SlabTopologyIssue.overlappingSlabs,
  ]) {
    test(
      'calculator withholds shared centres and soft-storey result: $conflict',
      () {
        final floors = [
          slab(box(0, 0, 4, 4)),
          slab(
            box(conflict == SlabTopologyIssue.separateRegions ? 8 : 2, 0, 4, 4),
          ),
        ];
        final report = SeismicAnalysisCalculator.analyzeProject(
          StructuralProject(
            storeys: [
              StoreyLevel(
                id: 'f',
                name: 'f',
                slabs: floors,
                columns: const [
                  StructuralColumn(
                    id: 'c',
                    center: Offset(1, 1),
                    width: .4,
                    height: .4,
                  ),
                ],
              ),
            ],
          ),
        );
        final check = report.storeyChecks.single;
        expect(check.slabTopology.issue, conflict);
        expect(check.hasLateralStiffness, isFalse);
        expect(check.centerOfMassCad, isNull);
        expect(check.centerOfRigidityCad, isNull);
        expect(check.eccentricityM, isNull);
        expect(check.stiffnessRatioToAbove, isNull);
      },
    );
  }
  for (final language in ['bg', 'en']) {
    testWidgets('separate-region explanation fits mobile: $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = SeismicAnalysisCalculator.analyzeProject(
        StructuralProject(
          storeys: [
            StoreyLevel(
              id: 'f',
              name: 'f',
              slabs: [slab(box(0, 0, 4, 4)), slab(box(8, 0, 4, 4))],
            ),
          ],
        ),
      );
      final strings = await AppLocalizations.delegate.load(Locale(language));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SeismicAnalysisSheet(report: report)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.seismicSeparateRegions(2)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
