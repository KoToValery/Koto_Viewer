import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_layout_properties.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/seismic_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/widgets/seismic_analysis_sheet.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_polygon_distance.dart';

List<Offset> box(double x, double y, double w, double h) => [
  Offset(x, y),
  Offset(x + w, y),
  Offset(x + w, y + h),
  Offset(x, y + h),
];
void main() {
  test('polygon separation detects crossings, containment and circles', () {
    expect(
      StructuralPolygonDistance.between(box(0, 0, 1, 1), box(1.2, 0, 1, 1)),
      closeTo(.2, 1e-10),
    );
    expect(
      StructuralPolygonDistance.between(box(0, 0, 10, 10), box(2, 2, 1, 1)),
      0,
    );
    expect(
      StructuralPolygonDistance.between(
        box(-3, -.2, 6, .4),
        box(-.2, -3, .4, 6),
      ),
      0,
    );
    expect(
      StructuralPolygonDistance.toCircle(
        box(0, 0, 2, 2),
        const Offset(3, 1),
        .4,
      ),
      closeTo(.6, 1e-10),
    );
  });
  test(
    'large stair opening uses nearest boundary, not centroid; walls participate',
    () {
      final opening = box(2, 2, 6, 6);
      final floor = StoreyLevel(
        id: 'f',
        name: 'f',
        slabs: [
          StructuralSlab(
            id: 's',
            polygon: box(0, 0, 12, 12),
            openings: [opening],
          ),
        ],
        columns: const [
          StructuralColumn(
            id: 'c',
            center: Offset(8.3, 5),
            width: .4,
            height: .4,
          ),
        ],
      );
      final report = SeismicAnalysisCalculator.analyzeProject(
        StructuralProject(storeys: [floor]),
      );
      expect(
        report.openingChecks.single.distanceToSupportM,
        closeTo(.1, 1e-10),
      );
      expect(report.openingChecks.single.isTooClose, isTrue);
      final withWall = floor.copyWith(
        columns: [],
        shearWalls: const [
          StructuralShearWall(
            id: 'w',
            start: Offset(8.4, 3),
            end: Offset(8.4, 7),
            thickness: .2,
          ),
        ],
      );
      final wallReport = SeismicAnalysisCalculator.analyzeProject(
        StructuralProject(storeys: [withWall]),
      );
      expect(
        wallReport.openingChecks.single.distanceToSupportM,
        closeTo(.3, 1e-10),
      );
      expect(wallReport.openingChecks.single.isTooClose, isTrue);
    },
  );
  test('opening without supports is explicitly unevaluated', () async {
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'f',
            name: 'f',
            slabs: [
              StructuralSlab(
                id: 's',
                polygon: box(0, 0, 10, 10),
                openings: [box(2, 2, 2, 2)],
              ),
            ],
          ),
        ],
      ),
    );
    final strings = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      report.openingChecks.single.localizedRecommendation(strings),
      strings.seismicOpeningNotEvaluated,
    );
  });
  test('no 10 percent relaxation for a symmetric layout', () {
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'f',
            name: 'f',
            slabs: [StructuralSlab(id: 's', polygon: box(-5, -5, 10, 10))],
            columns: [
              for (final x in [-2.7, 2.7])
                for (final y in [-2.7, 2.7])
                  StructuralColumn(
                    id: '$x,$y',
                    center: Offset(x, y),
                    width: .3,
                    height: .3,
                  ),
            ],
          ),
        ],
      ),
    );
    final check = report.storeyChecks.single;
    expect(check.torsionalRadiusX, closeTo(math.sqrt(2 * 2.7 * 2.7), 1e-10));
    expect(
      check.torsionalRadiusX,
      greaterThan(.9 * check.massRadiusOfGyration),
    );
    expect(check.torsionalRadiusX, lessThan(check.massRadiusOfGyration));
    expect(check.isTorsionallySensitive, isTrue);
    expect(check.isTorsionallyStiff, isFalse);
  });
  for (final language in ['bg', 'en']) {
    testWidgets(
      'unavailable result shows no invented eccentricity: $language',
      (tester) async {
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
                slabs: [StructuralSlab(id: 's', polygon: box(0, 0, 10, 10))],
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: SeismicAnalysisSheet(report: report),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.seismicRigidityUnavailable), findsOneWidget);
        expect(find.textContaining('0.00 m'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'rectangle integrals are analytical and translation/winding/unit invariant',
    () {
      for (final scale in [.001, 1.0, 1000.0]) {
        final shift = Offset(123456 * scale, -765432 * scale);
        final ring = box(0, 0, 10, 6).map((p) => p * scale + shift).toList();
        for (final points in [ring, ring.reversed.toList()]) {
          final m = PolygonMassIntegrals.integrate(points, shift, scale);
          expect(m.area, closeTo(60, 1e-6));
          expect(m.firstX / m.area, closeTo(5, 1e-7));
          expect(m.firstY / m.area, closeTo(3, 1e-7));
          expect(m.polar, closeTo(60 * (100 + 36) / 3, 1e-4));
        }
      }
    },
  );
  test('off-centre opening changes both CM and actual polar radius', () {
    final slab = StructuralSlab(
      id: 's',
      polygon: box(0, 0, 10, 10),
      openings: [box(6, 2, 4, 6)],
    );
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(id: 'f', name: 'floor', slabs: [slab]),
        ],
      ),
    );
    final check = report.storeyChecks.single;
    // Rectangle minus hole: A=76, first moment X=500-24*8=308.
    final cx = 308 / 76;
    final rawJ = 100 * 200 / 3 - 24 * ((16 + 36) / 12 + 64 + 25);
    final radius = math.sqrt(rawJ / 76 - cx * cx - 25);
    expect(check.centerOfMassCad!.dx, closeTo(cx, 1e-10));
    expect(check.massRadiusOfGyration, closeTo(radius, 1e-10));
    expect(check.centerOfRigidityCad, isNull);
    expect(check.eccentricityM, isNull);
    expect(check.hasLateralStiffness, isFalse);
    expect(report.overallRisk, SeismicRiskLevel.warning);
  });
  test('four equal supports: torsional layout index has m6 units', () {
    final result = LayoutRigidity.calculate([
      for (final x in [-3.0, 3.0])
        for (final y in [-4.0, 4.0]) LayoutSupport(Offset(x, y), 2, 2, 0),
    ])!;
    expect(result.center.distance, closeTo(0, 1e-12));
    expect(result.kx, 8);
    expect(result.torsion, 200); // 4 * 2 * (3²+4²).
    expect(math.sqrt(result.torsion / result.ky), 5);
  });
  test(
    'coupled rotated supports preserve CR and torsional index under rotation',
    () {
      final baseline = [
        LayoutSupport.rotated(const Offset(1, 2), 8, 2, .2),
        LayoutSupport.rotated(const Offset(6, 5), 4, 1, -.4),
        LayoutSupport.rotated(const Offset(-2, 7), 3, 1, .7),
      ];
      const a = .63;
      Offset rotate(Offset p) => Offset(
        p.dx * math.cos(a) - p.dy * math.sin(a),
        p.dx * math.sin(a) + p.dy * math.cos(a),
      );
      final rotated = [
        LayoutSupport.rotated(rotate(const Offset(1, 2)), 8, 2, .2 + a),
        LayoutSupport.rotated(rotate(const Offset(6, 5)), 4, 1, -.4 + a),
        LayoutSupport.rotated(rotate(const Offset(-2, 7)), 3, 1, .7 + a),
      ];
      final first = LayoutRigidity.calculate(baseline)!;
      final second = LayoutRigidity.calculate(rotated)!;
      expect((second.center - rotate(first.center)).distance, lessThan(1e-10));
      expect(second.torsion, closeTo(first.torsion, 1e-10));
    },
  );
  test(
    'missing and singular models cannot manufacture a centre of rigidity',
    () {
      expect(LayoutRigidity.calculate([]), isNull);
      expect(
        LayoutRigidity.calculate([const LayoutSupport(Offset.zero, 1, 1, 1)]),
        isNull,
      );
    },
  );
  test('unsupported L sections explicitly withhold stiffness evaluation', () {
    final report = SeismicAnalysisCalculator.analyzeProject(
      StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'f',
            name: 'f',
            slabs: [StructuralSlab(id: 's', polygon: box(0, 0, 10, 10))],
            columns: const [
              StructuralColumn(
                id: 'l',
                center: Offset(5, 5),
                shape: ColumnShape.lShape,
                width: .6,
                height: .6,
                thickness: .2,
              ),
            ],
          ),
        ],
      ),
    );
    expect(report.storeyChecks.single.hasLateralStiffness, isFalse);
    expect(report.storeyChecks.single.centerOfRigidityCad, isNull);
  });
}
