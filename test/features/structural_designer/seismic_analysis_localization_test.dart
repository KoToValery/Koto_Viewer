import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/l10n_extensions.dart';
import 'package:kotoview/src/features/structural_designer/models/seismic_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/vertical_capacity_models.dart';
import 'package:kotoview/src/features/structural_designer/widgets/seismic_analysis_sheet.dart';
import 'package:kotoview/src/features/structural_designer/widgets/vertical_capacity_sheet.dart';

void main() {
  group('Seismic & Vertical Capacity Localization and Overflow Tests', () {
    test('StoreySeismicCheck localizedRecommendation produces localized strings', () async {
      final l10nBg = await AppLocalizations.delegate.load(const Locale('bg'));
      final l10nEn = await AppLocalizations.delegate.load(const Locale('en'));

      const checkTorsion = StoreySeismicCheck(
        storeyId: 's1',
        storeyName: 'Storey 1',
        storeyIndex: 0,
        centerOfMassCad: Offset(5, 5),
        centerOfRigidityCad: Offset(2, 5),
        eccentricityM: Offset(3, 0),
        dimensionXM: 20,
        dimensionYM: 20,
        eccentricityRatioX: 0.15,
        eccentricityRatioY: 0.0,
        isTorsionallySensitive: true,
        wallAreaXM2: 1.0,
        wallAreaYM2: 1.0,
        floorAreaM2: 200,
        wallRatioX: 0.5,
        wallRatioY: 0.5,
        isWallCoverageSufficientX: false,
        isWallCoverageSufficientY: false,
        floatingColumnIds: ['c1'],
        floatingColumnNames: ['C1'],
        discontinuousWallIds: [],
        lateralStiffnessIndex: 1000,
        isSoftStorey: true,
        riskLevel: SeismicRiskLevel.critical,
        architectRecommendation: '',
      );

      final recBg = checkTorsion.localizedRecommendation(l10nBg);
      final recEn = checkTorsion.localizedRecommendation(l10nEn);

      expect(recBg, contains('НАСАДЕНИ'));
      expect(recBg, contains('МЕК ЕТАЖ'));
      expect(recBg, contains('Силно усукване'));

      expect(recEn, contains('FLOATING'));
      expect(recEn, contains('SOFT STOREY'));
      expect(recEn, contains('High torsional sensitivity'));

      const checkNoSlab = StoreySeismicCheck(
        storeyId: 's_no_slab',
        storeyName: 'Storey 0',
        storeyIndex: 0,
        hasSlabDiaphragm: false,
        dimensionXM: 0,
        dimensionYM: 0,
        eccentricityRatioX: 0,
        eccentricityRatioY: 0,
        isTorsionallySensitive: false,
        wallAreaXM2: 0,
        wallAreaYM2: 0,
        floorAreaM2: 0,
        wallRatioX: 0,
        wallRatioY: 0,
        isWallCoverageSufficientX: false,
        isWallCoverageSufficientY: false,
        floatingColumnIds: [],
        floatingColumnNames: [],
        discontinuousWallIds: [],
        lateralStiffnessIndex: 0,
        isSoftStorey: false,
        riskLevel: SeismicRiskLevel.warning,
        architectRecommendation: '',
      );

      final noSlabBg = checkNoSlab.localizedRecommendation(l10nBg);
      final noSlabEn = checkNoSlab.localizedRecommendation(l10nEn);
      expect(noSlabBg, contains('Липсва подова плоча'));
      expect(noSlabEn, contains('No floor slab'));
    });

    testWidgets('SeismicAnalysisSheet renders on narrow mobile screen without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const report = SeismicAnalysisReport(
        storeyChecks: [
          StoreySeismicCheck(
            storeyId: 's1',
            storeyName: 'Storey 1 (Elev. +0.00)',
            storeyIndex: 0,
            centerOfMassCad: Offset(5, 5),
            centerOfRigidityCad: Offset(4, 4),
            eccentricityM: Offset(1.16, 0.68),
            dimensionXM: 12.0,
            dimensionYM: 10.0,
            eccentricityRatioX: 0.09,
            eccentricityRatioY: 0.06,
            isTorsionallySensitive: false,
            wallAreaXM2: 0.0,
            wallAreaYM2: 0.0,
            floorAreaM2: 120.0,
            wallRatioX: 0.0,
            wallRatioY: 0.0,
            isWallCoverageSufficientX: false,
            isWallCoverageSufficientY: false,
            floatingColumnIds: [],
            floatingColumnNames: [],
            discontinuousWallIds: [],
            lateralStiffnessIndex: 500,
            isSoftStorey: false,
            riskLevel: SeismicRiskLevel.warning,
            architectRecommendation: '',
          ),
        ],
        beamChecks: [],
        openingChecks: [],
        totalFloatingColumnsCount: 0,
        totalDiscontinuousWallsCount: 0,
        hasTorsionalSensitivity: false,
        hasSoftStorey: false,
        hasWallDeficit: true,
        maxEccentricityRatio: 0.09,
        overallRisk: SeismicRiskLevel.warning,
      );

      FlutterErrorDetails? caughtDetails;
      FlutterError.onError = (details) {
        caughtDetails = details;
        FlutterError.dumpErrorToConsole(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SeismicAnalysisSheet(report: report),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      if (exception != null) {
        debugPrint('CAUGHT EXCEPTION: $exception');
        if (caughtDetails != null) {
          debugPrint('DETAILS: ${caughtDetails!.toString()}');
        }
      }
      expect(exception, isNull);

      // Verify localized Bulgarian strings appear
      expect(find.text('Макс. ексц.'), findsOneWidget);
      expect(find.text('Усукване'), findsOneWidget);
      expect(find.text('Насадени колони'), findsOneWidget);
      expect(find.text('Шайби (EC8)'), findsOneWidget);
      expect(find.text('Баланс (CM/CR)'), findsOneWidget);
      expect(find.text('Шайби (%)'), findsOneWidget);
      expect(find.text('Регулярност'), findsOneWidget);
      expect(find.text('Греди/Отвори'), findsOneWidget);
      expect(find.text('Балансирана'), findsOneWidget);
    });

    testWidgets('SeismicAnalysisSheet renders in English on narrow mobile screen without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const report = SeismicAnalysisReport(
        storeyChecks: [
          StoreySeismicCheck(
            storeyId: 's1',
            storeyName: 'Storey 1 (Elev. +0.00)',
            storeyIndex: 0,
            centerOfMassCad: Offset(5, 5),
            centerOfRigidityCad: Offset(4, 4),
            eccentricityM: Offset(1.16, 0.68),
            dimensionXM: 12.0,
            dimensionYM: 10.0,
            eccentricityRatioX: 0.09,
            eccentricityRatioY: 0.06,
            isTorsionallySensitive: false,
            wallAreaXM2: 0.0,
            wallAreaYM2: 0.0,
            floorAreaM2: 120.0,
            wallRatioX: 0.0,
            wallRatioY: 0.0,
            isWallCoverageSufficientX: false,
            isWallCoverageSufficientY: false,
            floatingColumnIds: [],
            floatingColumnNames: [],
            discontinuousWallIds: [],
            lateralStiffnessIndex: 500,
            isSoftStorey: false,
            riskLevel: SeismicRiskLevel.warning,
            architectRecommendation: '',
          ),
        ],
        beamChecks: [],
        openingChecks: [],
        totalFloatingColumnsCount: 0,
        totalDiscontinuousWallsCount: 0,
        hasTorsionalSensitivity: false,
        hasSoftStorey: false,
        hasWallDeficit: true,
        maxEccentricityRatio: 0.09,
        overallRisk: SeismicRiskLevel.warning,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SeismicAnalysisSheet(report: report),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Max. Ecc.'), findsOneWidget);
      expect(find.text('Torsion'), findsOneWidget);
      expect(find.text('Floating Cols'), findsOneWidget);
      expect(find.text('Shear Walls (EC8)'), findsOneWidget);
      expect(find.text('Balance (CM/CR)'), findsOneWidget);
      expect(find.text('Walls (%)'), findsOneWidget);
      expect(find.text('Regularity'), findsOneWidget);
      expect(find.text('Beams/Openings'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
    });

    testWidgets('VerticalCapacitySheet renders on narrow screen without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const col = ColumnVerticalCheck(
        columnId: 'col_1',
        columnName: 'C1',
        storeyId: 's1',
        storeyName: 'Ground Floor',
        storeyIndex: 0,
        numStoreysAbove: 2,
        center: Offset(5, 5),
        shape: ColumnShape.rectangular,
        widthM: 0.30,
        heightM: 0.30,
        crossSectionAreaM2: 0.09,
        tributaryAreaM2: 25.0,
        accumulatedLoadNedKn: 450.0,
        floorShearForceVedKn: 225.0,
        axialCapacityNrdKn: 1200.0,
        axialUtilization: 0.375,
        punchingShearStressVedMpa: 0.45,
        punchingShearResistanceVrdMpa: 0.65,
        punchingUtilization: 0.69,
        status: VerticalCapacityStatus.safe,
        minRequiredSectionCm: '25x25 cm',
        architectRecommendation: '',
      );

      final report = VerticalCapacityReport(
        totalVerticalLoadBaseKn: 1200.0,
        basePressureKpa: 150.0,
        footprintAreaM2: 100.0,
        columnChecks: [col],
        slabChecks: [],
        criticalColumnsCount: 0,
        warningColumnsCount: 0,
        punchingRiskCount: 0,
        maxAxialUtilization: 0.375,
        maxPunchingUtilization: 0.69,
        overallStatus: VerticalCapacityStatus.safe,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('bg'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VerticalCapacitySheet(report: report),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Базисен натиск'), findsOneWidget);
      expect(find.text('Колони (1)'), findsOneWidget);
    });
  });
}
