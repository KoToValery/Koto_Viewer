import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/seismic_slab_load.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/widgets/seismic_load_dialog.dart';

StructuralSlab slab(String id, double x, {SeismicSlabLoad? load}) =>
    StructuralSlab(
      id: id,
      polygon: [Offset(x, 0), Offset(x + 2, 0), Offset(x + 2, 2), Offset(x, 2)],
      seismicLoad: load,
    );
StructuralProject project(List<StructuralSlab> slabs) => StructuralProject(
  storeys: [StoreyLevel(id: 'f', name: 'Floor', slabs: slabs)],
);
void main() {
  test('legacy project inherits surface loads and participation 0.3', () {
    final p = project([
      slab('a', 0),
    ]).copyWith(deadLoadSuperimposed: 3, liveLoad: 4);
    final restored = StructuralProject.fromJson(
      jsonDecode(jsonEncode(p.toJson())),
    );
    final s = restored.storeys.single.slabs.single;
    expect(s.seismicLoad, isNull);
    expect(
      s.effectiveSeismicLoad(restored).weightKnM2(.2),
      closeTo(9.2, 1e-12),
    );
  });
  test(
    'override survives JSON and geometry edits; reset restores inheritance',
    () {
      final original = slab(
        'a',
        0,
        load: const SeismicSlabLoad(
          permanentKnM2: 4,
          variableKnM2: 5,
          participation: .6,
        ),
      );
      final restored = StructuralSlab.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      ).copyWith(thickness: .3);
      expect(restored.seismicLoad!.weightKnM2(restored.thickness), 14.5);
      expect(restored.copyWith(clearSeismicLoad: true).seismicLoad, isNull);
    },
  );
  test('CM and polar radius use identical per-slab weights', () {
    final p = project([
      slab(
        'a',
        0,
        load: const SeismicSlabLoad(
          permanentKnM2: 0,
          variableKnM2: 0,
          participation: 0,
        ),
      ),
      slab(
        'b',
        2,
        load: const SeismicSlabLoad(
          permanentKnM2: 5,
          variableKnM2: 10,
          participation: .5,
        ),
      ),
    ]);
    final c = SeismicAnalysisCalculator.analyzeProject(p).storeyChecks.single;
    // Equal 4m2 rectangles, weights 20 and 60 kN, centres (1,1)/(3,1).
    expect(c.centerOfMassCad!.dx, closeTo(2.5, 1e-12));
    final expectedJ = 20 * (2 / 3 + 1.5 * 1.5) + 60 * (2 / 3 + .5 * .5);
    expect(c.massRadiusOfGyration, closeTo(math.sqrt(expectedJ / 80), 1e-12));
  });
  test('invalid coefficients and nonfinite loads withhold mass results', () {
    for (final load in [
      const SeismicSlabLoad(
        permanentKnM2: -1,
        variableKnM2: 2,
        participation: .3,
      ),
      const SeismicSlabLoad(
        permanentKnM2: 1,
        variableKnM2: double.infinity,
        participation: .3,
      ),
      const SeismicSlabLoad(
        permanentKnM2: 1,
        variableKnM2: 2,
        participation: 1.1,
      ),
      const SeismicSlabLoad(
        permanentKnM2: 1,
        variableKnM2: 2,
        participation: double.nan,
      ),
    ]) {
      final c = SeismicAnalysisCalculator.analyzeProject(
        project([slab('a', 0, load: load)]),
      ).storeyChecks.single;
      expect(c.invalidMassLoads, isTrue);
      expect(c.centerOfMassCad, isNull);
      expect(c.eccentricityM, isNull);
    }
  });
  test('invalid regional load does not contaminate the other region', () {
    final p = project([
      slab(
        'a',
        0,
        load: const SeismicSlabLoad(
          permanentKnM2: -1,
          variableKnM2: 0,
          participation: 0,
        ),
      ),
      slab('b', 10),
    ]);
    final regions = SeismicAnalysisCalculator.analyzeProject(
      p,
    ).storeyChecks.single.diaphragmRegions;
    expect(regions.first.check!.invalidMassLoads, isTrue);
    expect(regions.last.check!.invalidMassLoads, isFalse);
    expect(regions.last.check!.centerOfMassCad!.dx, 11);
  });
  for (final lang in ['bg', 'en']) {
    testWidgets(
      'load editor validates and saves decimal comma on mobile: $lang',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        StructuralProject? saved;
        final strings = await AppLocalizations.delegate.load(Locale(lang));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showDialog<StructuralProject>(
                      context: context,
                      builder: (_) =>
                          SeismicLoadDialog(project: project([slab('a', 0)])),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('seismic-load-2')),
          '2',
        );
        await tester.tap(find.text(strings.applyAction));
        await tester.pumpAndSettle();
        expect(saved, isNull);
        expect(find.text(strings.seismicInvalidMassLoads), findsOneWidget);
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(find.byKey(const ValueKey('seismic-load-2'))).controller!.text, '0.3');
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('seismic-load-2')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('seismic-load-2')),
          '0,6',
        );
        await tester.tap(find.text(strings.applyAction));
        await tester.pumpAndSettle();
        expect(
          saved!.storeys.single.slabs.single.seismicLoad!.participation,
          .6,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
