import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/load_rundown.dart';
import 'package:kotoview/src/features/structural_designer/models/element_check_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/widgets/building_check_summary_sheet.dart';
import 'package:kotoview/src/features/structural_designer/widgets/project_design_parameters_sheet.dart';

Widget _host(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
);

void main() {
  group('ProjectDesignParameters', () {
    test('JSON round-trip and backward compatibility when missing', () {
      const p = ProjectDesignParameters(
        agR: 0.27,
        importanceClass: SeismicImportanceClass.iii,
        soilType: SeismicSoilType.c,
        spectrumType: SeismicSpectrumType.type1,
        systemOverride: SeismicSystemKind.dual,
        behaviorFactorQ: 2.5,
        driftCategory: DriftDamageCategory.ductile,
      );
      final project = const StructuralProject().copyWith(designParameters: p);
      final decoded = StructuralProject.fromJson(project.toJson());
      expect(decoded.designParameters?.agR, 0.27);
      expect(decoded.designParameters?.importanceClass, SeismicImportanceClass.iii);
      expect(decoded.designParameters?.soilType, SeismicSoilType.c);
      expect(decoded.designParameters?.systemOverride, SeismicSystemKind.dual);
      expect(decoded.designParameters?.behaviorFactorQ, 2.5);
      expect(decoded.designParameters?.driftCategory, DriftDamageCategory.ductile);

      // Legacy JSON without designParameters decodes to null (never invents a_gR).
      final legacyJson = project.toJson()..remove('designParameters');
      final legacy = StructuralProject.fromJson(legacyJson);
      expect(legacy.designParameters, isNull);
    });

    test('EC8 design spectrum matches analytical branches and lower bound', () {
      const p = ProjectDesignParameters(
        agR: 0.20,
        soilType: SeismicSoilType.b, // S=1.2, TB=0.15, TC=0.50, TD=2.0
        importanceClass: SeismicImportanceClass.ii,
      );
      final ag = 0.20 * 9.81;
      // Plateau TB <= T <= TC: a_g * S * 2.5 / q
      expect(
        p.designSpectrumMs2(0.30, SeismicSystemKind.wall),
        closeTo(ag * 1.2 * 2.5 / 3.0, 1e-6),
      );
      // Descending branch TC < T <= TD
      expect(
        p.designSpectrumMs2(1.00, SeismicSystemKind.wall),
        closeTo(ag * 1.2 * 2.5 / 3.0 * (0.50 / 1.00), 1e-6),
      );
      // Long period floor beta * a_g
      expect(
        p.designSpectrumMs2(5.00, SeismicSystemKind.wall),
        closeTo(0.20 * ag, 1e-6),
      );
      // Unconfigured returns NaN
      expect(
        const ProjectDesignParameters()
            .designSpectrumMs2(0.30, SeismicSystemKind.wall)
            .isNaN,
        isTrue,
      );
    });
  });

  for (final locale in const [Locale('en'), Locale('bg')]) {
    testWidgets(
      'ProjectDesignParametersSheet renders without overflow on 320px phone (${locale.languageCode})',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        StructuralProject? applied;
        await tester.pumpWidget(
          _host(
            locale,
            ProjectDesignParametersSheet(
              project: const StructuralProject(),
              onApply: (p) => applied = p,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('0.23g'));
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(locale);
        await tester.tap(find.text(l10n.designParamsApply));
        await tester.pumpAndSettle();

        expect(applied?.designParameters?.agR, closeTo(0.23, 1e-6));
      },
    );

    testWidgets(
      'BuildingCheckSummarySheet renders without overflow on 320px phone (${locale.languageCode})',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final project = StructuralProject(
          designParameters: const ProjectDesignParameters(agR: 0.23),
          storeys: [
            StoreyLevel(
              id: 's0',
              name: '±0.00',
              height: 3.0,
              slabs: const [
                StructuralSlab(
                  id: 'sl0',
                  polygon: [
                    Offset(0, 0),
                    Offset(8, 0),
                    Offset(8, 6),
                    Offset(0, 6),
                  ],
                ),
              ],
              columns: const [
                StructuralColumn(id: 'c1', name: 'К1', center: Offset(0.2, 0.2)),
                StructuralColumn(id: 'c2', name: 'К2', center: Offset(7.8, 0.2)),
                StructuralColumn(id: 'c3', name: 'К3', center: Offset(7.8, 5.8)),
                StructuralColumn(id: 'c4', name: 'К4', center: Offset(0.2, 5.8)),
              ],
              shearWalls: const [
                StructuralShearWall(
                  id: 'w1',
                  name: 'Ш1',
                  start: Offset(2, 0.2),
                  end: Offset(5, 0.2),
                ),
                StructuralShearWall(
                  id: 'w2',
                  name: 'Ш2',
                  start: Offset(0.2, 2),
                  end: Offset(0.2, 4.5),
                ),
              ],
            ),
          ],
        );
        final report = LoadRundown.analyze(project, cadUnitsPerMeter: 1.0);
        var fullCalled = false;

        await tester.pumpWidget(
          _host(
            locale,
            BuildingCheckSummarySheet(
              project: project,
              report: report,
              isRunning: false,
              isStale: false,
              onRunFullCheck: () => fullCalled = true,
              onEditParameters: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(find.text(l10n.checkBuildingTitle), findsOneWidget);
        await tester.tap(find.text(l10n.checkRunFullButton));
        await tester.pumpAndSettle();
        expect(fullCalled, isTrue);
      },
    );
  }
}
