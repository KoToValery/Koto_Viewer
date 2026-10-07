import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/widgets/seismic_analysis_sheet.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_vertical_continuity.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

StructuralShearWall wall(double a, double b, {double y = 0, double t = .2}) =>
    StructuralShearWall(
      id: 'w',
      name: 'W1',
      start: Offset(a, y),
      end: Offset(b, y),
      thickness: t,
    );
void main() {
  for (final language in ['bg', 'en']) {
    testWidgets('wall continuity appears on mobile regularity tab: $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final report = SeismicAnalysisCalculator.analyzeProject(
        StructuralProject(
          storeys: [
            StoreyLevel(id: 'lower', name: 'Lower', shearWalls: [wall(4, 6)]),
            StoreyLevel(
              id: 'upper',
              name: 'Upper',
              elevation: 3,
              shearWalls: [wall(0, 10)],
            ),
          ],
        ),
      );
      final strings = await AppLocalizations.delegate.load(Locale(language));
      (String, String, bool)? located;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SeismicAnalysisSheet(
              report: report,
              onLocateElement: (s, e, w) => located = (s, e, w),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(strings.seismicTabRegularity));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.seismicTabRegularity));
      await tester.pumpAndSettle();
      expect(
        find.text(strings.seismicWallContinuityItem('Upper', 'W1', '20.0%')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final target = find.text(
        strings.seismicWallContinuityItem('Upper', 'W1', '20.0%'),
      );
      await tester.ensureVisible(target);
      await tester.tap(target);
      expect(located, ('upper', 'w', true));
    });
  }
  test('short wall below same midpoint covers only its actual footprint', () {
    final c = WallVerticalContinuity.evaluate(wall(0, 10), [wall(4, 6)], 1);
    expect(c.coverage, closeTo(.2, 1e-10));
    expect(c.isContinuous, isFalse);
  });
  test('transverse wall through midpoint is not a vertical continuation', () {
    final c = WallVerticalContinuity.evaluate(wall(0, 10), [
      const StructuralShearWall(
        id: 'cross',
        start: Offset(5, -5),
        end: Offset(5, 5),
        thickness: .2,
      ),
    ], 1);
    expect(c.coverage, 0);
  });
  test('offset and reduced thickness are reflected in coverage', () {
    expect(
      WallVerticalContinuity.evaluate(wall(0, 10), [
        wall(0, 10, y: .1),
      ], 1).coverage,
      closeTo(.5, 1e-10),
    );
    expect(
      WallVerticalContinuity.evaluate(wall(0, 10), [
        wall(0, 10, t: .1),
      ], 1).coverage,
      closeTo(.5, 1e-10),
    );
    expect(
      WallVerticalContinuity.evaluate(wall(0, 10), [
        wall(0, 10, y: .21),
      ], 1).coverage,
      0,
    );
  });
  test(
    'lower wall union supports segmented continuation without double counting',
    () {
      final c = WallVerticalContinuity.evaluate(wall(0, 10), [
        wall(0, 6),
        wall(10, 4),
      ], 1);
      expect(c.coverage, closeTo(1, 1e-10));
      expect(c.isContinuous, isTrue);
    },
  );
  test('face reference and flipping use the actual footprint', () {
    final upper = wall(
      0,
      10,
    ).copyWith(referenceLine: ShearWallReferenceLine.leftFace);
    expect(
      WallVerticalContinuity.evaluate(upper, [upper], 1).isContinuous,
      isTrue,
    );
    expect(
      WallVerticalContinuity.evaluate(upper, [
        upper.copyWith(isFlipped: true),
      ], 1).coverage,
      0,
    );
  });
  test('scale and reversed direction preserve continuity', () {
    expect(
      WallVerticalContinuity.evaluate(wall(0, 10000, t: 200), [
        wall(10000, 0, t: 200),
      ], 1000).isContinuous,
      isTrue,
    );
  });
  test('invalid geometry is unknown, empty lower level is absent', () {
    expect(WallVerticalContinuity.evaluate(wall(0, 0), [], 1).coverage, isNull);
    expect(
      WallVerticalContinuity.evaluate(wall(0, 10), [wall(0, 0)], 1).coverage,
      isNull,
    );
    expect(WallVerticalContinuity.evaluate(wall(0, 10), [], 1).coverage, 0);
  });
  test(
    'wall checks work without slabs and preserve existing floating-column count',
    () {
      final p = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'lower',
            name: 'Lower',
            shearWalls: [wall(4, 6)],
            columns: const [StructuralColumn(id: 'lc', center: Offset(0, 2))],
          ),
          StoreyLevel(
            id: 'upper',
            name: 'Upper',
            elevation: 3,
            shearWalls: [wall(0, 10)],
            columns: const [
              StructuralColumn(id: 'supported', center: Offset(0, 2)),
              StructuralColumn(id: 'floating', center: Offset(20, 2)),
            ],
          ),
        ],
      );
      final report = SeismicAnalysisCalculator.analyzeProject(p);
      expect(report.totalFloatingColumnsCount, 1);
      expect(report.storeyChecks.last.floatingColumnIds, ['floating']);
      expect(report.totalDiscontinuousWallsCount, 1);
      expect(report.storeyChecks.last.discontinuousWallIds, ['w']);
      expect(
        report.storeyChecks.last.wallVerticalChecks.single.coverage,
        closeTo(.2, 1e-10),
      );
      expect(report.storeyChecks.first.wallVerticalChecks, isEmpty);
    },
  );
}
