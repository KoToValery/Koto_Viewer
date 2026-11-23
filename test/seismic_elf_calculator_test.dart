import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/load_rundown.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_elf_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/element_check_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

Offset _rot(Offset p, double a) => Offset(
  p.dx * math.cos(a) - p.dy * math.sin(a),
  p.dx * math.sin(a) + p.dy * math.cos(a),
);

StructuralProject _wallBuilding({
  int storeys = 4,
  double height = 3.0,
  double width = 12.0,
  double depth = 10.0,
  double wallLengthX = 3.0,
  double wallLengthY = 3.0,
  double? agR = 0.23,
  double facade = 3.5,
  double angleRad = 0.0,
  double scale = 1.0,
  Offset shift = Offset.zero,
  bool eccentricNorthWall = false,
  bool includeLColumn = false,
}) {
  Offset tr(Offset p) => _rot(p, angleRad) * scale + shift;

  final slabPoly = [
    tr(Offset.zero),
    tr(Offset(width, 0)),
    tr(Offset(width, depth)),
    tr(Offset(0, depth)),
  ];

  // Two X-walls (south y=0.2, north y=depth-0.2) and two Y-walls (west x=0.2, east x=width-0.2).
  // When eccentricNorthWall is true, north wall is longer (shifts CR toward +Y,
  // so CM lies closer to the south wall -> south wall must get higher shear!).
  final northLen = eccentricNorthWall ? wallLengthX * 1.8 : wallLengthX;

  return StructuralProject(
    concreteGrade: 'C25/30',
    concreteE: 31000,
    deadLoadSuperimposed: 1.5,
    liveLoad: 2.0,
    facadeWallLoad: facade,
    designParameters: agR == null
        ? null
        : ProjectDesignParameters(
            agR: agR,
            soilType: SeismicSoilType.b,
            importanceClass: SeismicImportanceClass.ii,
            driftCategory: DriftDamageCategory.brittle,
          ),
    storeys: [
      for (var k = 0; k < storeys; k++)
        StoreyLevel(
          id: 's$k',
          name: 'S$k',
          elevation: k * height,
          height: height,
          slabs: [StructuralSlab(id: 'sl$k', polygon: slabPoly, thickness: 0.20)],
          columns: [
            if (includeLColumn)
              StructuralColumn(
                id: 'colL_$k',
                center: tr(Offset(width / 2, depth / 2)),
                shape: ColumnShape.lShape,
                width: 0.60 * scale,
                height: 0.60 * scale,
                thickness: 0.25 * scale,
                rotationRad: angleRad,
              ),
          ],
          shearWalls: [
            StructuralShearWall(
              id: 'wx_south_$k',
              start: tr(Offset((width - wallLengthX) / 2, 0.2)),
              end: tr(Offset((width + wallLengthX) / 2, 0.2)),
              thickness: 0.25 * scale,
            ),
            StructuralShearWall(
              id: 'wx_north_$k',
              start: tr(Offset((width - northLen) / 2, depth - 0.2)),
              end: tr(Offset((width + northLen) / 2, depth - 0.2)),
              thickness: 0.25 * scale,
            ),
            StructuralShearWall(
              id: 'wy_west_$k',
              start: tr(Offset(0.2, (depth - wallLengthY) / 2)),
              end: tr(Offset(0.2, (depth + wallLengthY) / 2)),
              thickness: 0.25 * scale,
            ),
            StructuralShearWall(
              id: 'wy_east_$k',
              start: tr(Offset(width - 0.2, (depth - wallLengthY) / 2)),
              end: tr(Offset(width - 0.2, (depth + wallLengthY) / 2)),
              thickness: 0.25 * scale,
            ),
          ],
        ),
    ],
  );
}

void main() {
  group('SeismicElfCalculator', () {
    test('results are strictly invariant under rotation, translation and units', () {
      final base = SeismicElfCalculator.analyze(
        _wallBuilding(eccentricNorthWall: true, includeLColumn: true),
        cadUnitsPerMeter: 1.0,
      );
      final rotatedCm = SeismicElfCalculator.analyze(
        _wallBuilding(
          eccentricNorthWall: true,
          includeLColumn: true,
          angleRad: 0.645, // ~37 degrees
          scale: 100.0,
          shift: const Offset(25000, -14000),
        ),
        cadUnitsPerMeter: 100.0,
      );

      expect(base.isConfigured, isTrue);
      expect(rotatedCm.isConfigured, isTrue);
      expect(rotatedCm.totalMassTonnes, closeTo(base.totalMassTonnes, 1e-4));
      expect(rotatedCm.period1S, closeTo(base.period1S, 1e-6));
      expect(rotatedCm.period2S, closeTo(base.period2S, 1e-6));
      expect(rotatedCm.baseShear1Kn, closeTo(base.baseShear1Kn, 1e-3));
      expect(rotatedCm.baseShear2Kn, closeTo(base.baseShear2Kn, 1e-3));

      final tBase = base.storeys.first.torsion;
      final tRot = rotatedCm.storeys.first.torsion;
      expect(tBase.isEvaluated, isTrue);
      expect(tRot.isEvaluated, isTrue);
      expect(tRot.lsM, closeTo(tBase.lsM, 1e-5));
      expect(tRot.r1M, closeTo(tBase.r1M, 1e-5));
      expect(tRot.r2M, closeTo(tBase.r2M, 1e-5));
      expect(tRot.eccentricityRatio, closeTo(tBase.eccentricityRatio, 1e-5));
      expect(tRot.flexibilityRatio, closeTo(tBase.flexibilityRatio, 1e-5));

      for (final entry in base.wallShearChecks.entries) {
        final other = rotatedCm.wallShearChecks[entry.key]!;
        expect(other.demand, closeTo(entry.value.demand, 1e-2));
        expect(other.capacity, closeTo(entry.value.capacity, 1e-3));
      }
      expect(
        rotatedCm.storeys.first.driftCheck.demand,
        closeTo(base.storeys.first.driftCheck.demand, 1e-4),
      );
    });

    test('symmetric building has zero eccentricity and equal opposite wall shears', () {
      final report = SeismicElfCalculator.analyze(
        _wallBuilding(storeys: 3, wallLengthX: 3.0, wallLengthY: 2.5),
        cadUnitsPerMeter: 1.0,
      );
      final ground = report.storeys.first;
      expect(ground.torsion.e1M, closeTo(0.0, 1e-6));
      expect(ground.torsion.e2M, closeTo(0.0, 1e-6));
      expect(ground.torsion.isTorsionallyFlexible, isFalse);

      final south = report.wallShearChecks['s0/wx_south_0']!;
      final north = report.wallShearChecks['s0/wx_north_0']!;
      expect(south.demand, closeTo(north.demand, 1e-4));
      // Accidental torsion + DCM magnification means demand exceeds 1.5 * V/2.
      expect(south.demand, greaterThan(0.75 * report.baseShear1Kn));
    });

    test('eccentric mass amplifies shear on the wall on the CM side', () {
      // Equal north & south walls; large opening on the north half shifts CM
      // south -> south wall must attract strictly more seismic shear than north.
      final base = _wallBuilding(storeys: 3, wallLengthX: 3.0, wallLengthY: 3.0);
      final withNorthOpening = base.copyWith(
        storeys: [
          for (final s in base.storeys)
            s.copyWith(
              slabs: [
                s.slabs.first.copyWith(
                  openings: const [
                    [Offset(2, 6), Offset(10, 6), Offset(10, 9.5), Offset(2, 9.5)],
                  ],
                ),
              ],
            ),
        ],
      );
      final report = SeismicElfCalculator.analyze(
        withNorthOpening,
        cadUnitsPerMeter: 1.0,
      );
      final south = report.wallShearChecks['s0/wx_south_0']!;
      final north = report.wallShearChecks['s0/wx_north_0']!;
      expect(south.demand, greaterThan(north.demand));
      expect(report.storeys.first.torsion.e1M + report.storeys.first.torsion.e2M,
          greaterThan(0.5));
    });

    test('perimeter facade load increases floor mass and mass radius l_s', () {
      final withoutFacade = SeismicElfCalculator.analyze(
        _wallBuilding(facade: 0.0),
        cadUnitsPerMeter: 1.0,
      );
      final withFacade = SeismicElfCalculator.analyze(
        _wallBuilding(facade: 6.0),
        cadUnitsPerMeter: 1.0,
      );
      expect(withFacade.totalMassTonnes, greaterThan(withoutFacade.totalMassTonnes));
      expect(
        withFacade.storeys.first.torsion.lsM,
        greaterThan(withoutFacade.storeys.first.torsion.lsM),
      );
    });

    test('unconfigured a_gR computes torsion without inventing seismic shear', () {
      final report = SeismicElfCalculator.analyze(
        _wallBuilding(agR: null),
        cadUnitsPerMeter: 1.0,
      );
      expect(report.isConfigured, isFalse);
      expect(report.issues, contains(SeismicApplicabilityIssue.notConfigured));
      expect(report.wallShearChecks, isEmpty);
      expect(report.storeys.first.driftCheck.isDetermined, isFalse);
      expect(report.storeys.first.torsion.isEvaluated, isTrue);
    });

    test('taller building increases base shear and wall shear utilization', () {
      final low = SeismicElfCalculator.analyze(
        _wallBuilding(storeys: 2, wallLengthX: 3.0, wallLengthY: 3.0),
        cadUnitsPerMeter: 1.0,
      );
      final tall = SeismicElfCalculator.analyze(
        _wallBuilding(storeys: 8, wallLengthX: 3.0, wallLengthY: 3.0),
        cadUnitsPerMeter: 1.0,
      );
      // 8 storeys has longer T1 on the EC8 descending branch + lambda = 0.85,
      // yet total base shear and wall demand are still much higher than 2 storeys.
      expect(tall.baseShear1Kn, greaterThan(low.baseShear1Kn * 1.5));
      expect(
        tall.wallShearChecks['s0/wx_south_0']!.utilization,
        greaterThan(low.wallShearChecks['s0/wx_south_0']!.utilization * 1.5),
      );
    });

    test('LoadRundown merges wall seismic shear and drift into wall ElementUtilization', () {
      final project = _wallBuilding(storeys: 3, agR: 0.27);
      final report = LoadRundown.analyze(
        project,
        cadUnitsPerMeter: 1.0,
        spacingM: LoadRundown.fullSpacingM,
        isFullCheck: true,
      );
      expect(report.isFullCheck, isTrue);
      expect(report.seismic?.isConfigured, isTrue);
      final wall = report.element('s0', 'wx_south_0')!;
      expect(wall.check(CheckKind.wallSeismicShear)?.isDetermined, isTrue);
      expect(wall.check(CheckKind.storeyDrift)?.isDetermined, isTrue);
    });
  });
}
