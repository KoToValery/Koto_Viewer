import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/seismic_analysis_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/seismic_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  group('Eurocode 8 (EC8) Seismic Concept, Torsion & Regularity Tests', () {
    test('1. Symmetric structure: CM and CR coincide with zero eccentricity', () {
      // 10m x 10m floor with symmetric columns and walls
      const scale = 50.0;
      final slab = StructuralSlab(
        id: 'slab1',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        thickness: 0.20,
      );

      // Two identical shear walls symmetrically placed at x=100 and x=400
      final wallLeft = StructuralShearWall(
        id: 'w1',
        start: const Offset(100, 100),
        end: const Offset(100, 400),
        thickness: 0.25 * scale,
      );
      final wallRight = StructuralShearWall(
        id: 'w2',
        start: const Offset(400, 100),
        end: const Offset(400, 400),
        thickness: 0.25 * scale,
      );

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        shearWalls: [wallLeft, wallRight],
        columns: const [],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Symmetric Building',
        storeys: [storey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );

      expect(report.storeyChecks.length, 1);
      final check = report.storeyChecks.first;

      // CM and CR should have practically identical X coordinate (~250 CAD)
      expect(check.centerOfMassCad.dx, closeTo(250.0, 1.0));
      expect(check.centerOfRigidityCad.dx, closeTo(250.0, 1.0));
      expect(check.eccentricityM.dx, closeTo(0.0, 0.05));
      expect(check.isTorsionallySensitive, isFalse);
    });

    test('2. Torsional sensitivity and eccentricity when shear wall is placed on one edge', () {
      const scale = 50.0;
      final slab = StructuralSlab(
        id: 'slab1',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        thickness: 0.20,
      );

      // Heavy shear wall only on the East edge (x=480), oriented along Y
      final heavyWallEast = StructuralShearWall(
        id: 'wEast',
        start: const Offset(480, 50),
        end: const Offset(480, 450),
        thickness: 0.25 * scale,
      );

      // Light column on the West side
      final colWest = StructuralColumn(
        id: 'colWest',
        center: const Offset(50, 250),
        width: 0.25 * scale,
        height: 0.25 * scale,
        shape: ColumnShape.rectangular,
      );

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        shearWalls: [heavyWallEast],
        columns: [colWest],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Asymmetric Building',
        storeys: [storey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );
      final check = report.storeyChecks.first;

      // CR should be pulled toward x=480 (East side)
      expect(check.centerOfRigidityCad.dx, greaterThan(400.0));
      // CM is near the center, slightly shifted towards wall due to wall weight (~288 CAD)
      expect(check.centerOfMassCad.dx, closeTo(290.0, 40.0));

      // Significant eccentricity e_x > 2.0 m
      expect(check.eccentricityM.dx, greaterThan(2.0));
      // Eccentricity ratio e / L > 15% -> torsionally sensitive!
      expect(check.eccentricityRatioX, greaterThan(0.15));
      expect(check.isTorsionallySensitive, isTrue);
      expect(report.hasTorsionalSensitivity, isTrue);

      // Recommendation should suggest adding walls on the West side to balance CR
      expect(check.architectRecommendation, contains('запад'));
    });

    test('3. Shear wall ratio check (EC8 & BG norms >= 1.0% floor area)', () {
      const scale = 50.0;
      // 10m x 10m = 100 m² floor
      final slab = StructuralSlab(
        id: 'slab1',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        thickness: 0.20,
      );

      // Wall length = 4.0 m, thickness = 0.25 m -> Area = 1.0 m² (1.0% of 100 m²)
      final wallX = StructuralShearWall(
        id: 'wx',
        start: const Offset(100, 250),
        end: const Offset(300, 250), // length = 200 cad = 4.0 m
        thickness: 0.25 * scale,
      );

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        shearWalls: [wallX],
        columns: const [],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Wall Ratio Test',
        storeys: [storey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );
      final check = report.storeyChecks.first;

      // Wall is in X direction
      expect(check.wallRatioX, closeTo(1.0, 0.05));
      expect(check.isWallCoverageSufficientX, isTrue);

      // No wall in Y direction -> deficit
      expect(check.wallRatioY, 0.0);
      expect(check.isWallCoverageSufficientY, isFalse);
      expect(report.hasWallDeficit, isTrue);
    });

    test('4. Floating (transfer) column detection (EC8 §4.2.3.3)', () {
      const scale = 50.0;
      final slab = StructuralSlab(
        id: 'slab',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        thickness: 0.20,
      );

      // Ground floor with column C_ground at (250, 250)
      final colGround = StructuralColumn(
        id: 'col_g1',
        center: const Offset(250, 250),
        width: 0.30 * scale,
        height: 0.30 * scale,
        shape: ColumnShape.rectangular,
      );

      final storeyGround = StoreyLevel(
        id: 's0',
        name: 'Партер',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        columns: [colGround],
        shearWalls: const [],
        beams: const [],
      );

      // 1st Floor has continuous column C1 at (250, 250) and floating column C2 at (400, 400)
      final colContinuous = StructuralColumn(
        id: 'col_c1',
        center: const Offset(250, 250),
        width: 0.30 * scale,
        height: 0.30 * scale,
        shape: ColumnShape.rectangular,
      );
      final colFloating = StructuralColumn(
        id: 'col_floating',
        center: const Offset(400, 400),
        width: 0.30 * scale,
        height: 0.30 * scale,
        shape: ColumnShape.rectangular,
      );

      final storeyUpper = StoreyLevel(
        id: 's1',
        name: 'Етаж 1',
        elevation: 3.0,
        height: 3.0,
        slabs: [slab],
        columns: [colContinuous, colFloating],
        shearWalls: const [],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Transfer Column Project',
        storeys: [storeyGround, storeyUpper],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );

      // Ground floor has 0 floating columns
      expect(report.storeyChecks[0].floatingColumnIds.isEmpty, isTrue);

      // Upper floor has 1 floating column (col_floating)
      final upperCheck = report.storeyChecks[1];
      expect(upperCheck.floatingColumnIds.length, 1);
      expect(upperCheck.floatingColumnIds.first, 'col_floating');
      expect(upperCheck.riskLevel, SeismicRiskLevel.critical);
      expect(report.totalFloatingColumnsCount, 1);
      expect(report.overallRisk, SeismicRiskLevel.critical);
    });

    test('5. Soft Storey (Мек етаж) detection', () {
      const scale = 50.0;
      final slab = StructuralSlab(
        id: 'slab',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        thickness: 0.20,
      );

      // Ground floor (open garage / pilotis) with only 2 slender columns
      final groundCol1 = StructuralColumn(
        id: 'cg1',
        center: const Offset(100, 250),
        width: 0.25 * scale,
        height: 0.25 * scale,
        shape: ColumnShape.rectangular,
      );
      final groundCol2 = StructuralColumn(
        id: 'cg2',
        center: const Offset(400, 250),
        width: 0.25 * scale,
        height: 0.25 * scale,
        shape: ColumnShape.rectangular,
      );

      final groundStorey = StoreyLevel(
        id: 's0',
        name: 'Партер',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        columns: [groundCol1, groundCol2],
        shearWalls: const [],
        beams: const [],
      );

      // Upper floor with heavy shear walls (much higher stiffness)
      final upperWall1 = StructuralShearWall(
        id: 'uw1',
        start: const Offset(100, 100),
        end: const Offset(100, 400),
        thickness: 0.25 * scale,
      );
      final upperWall2 = StructuralShearWall(
        id: 'uw2',
        start: const Offset(400, 100),
        end: const Offset(400, 400),
        thickness: 0.25 * scale,
      );

      final upperStorey = StoreyLevel(
        id: 's1',
        name: 'Етаж 1',
        elevation: 3.0,
        height: 3.0,
        slabs: [slab],
        columns: [groundCol1, groundCol2],
        shearWalls: [upperWall1, upperWall2],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Soft Storey Building',
        storeys: [groundStorey, upperStorey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );

      // Ground storey stiffness should be < 70% of upper storey stiffness
      final groundCheck = report.storeyChecks[0];
      expect(groundCheck.isSoftStorey, isTrue);
      expect(report.hasSoftStorey, isTrue);
      expect(groundCheck.riskLevel, SeismicRiskLevel.critical);
      expect(groundCheck.architectRecommendation, contains('МЕК ЕТАЖ'));
    });

    test('6. Preliminary Beam Sizing (EC2 / EC8 h >= L/12)', () {
      const scale = 50.0;
      // Beam 1: L = 6.0 m (start: 100, 100, end: 400, 100 at scale 50 -> 300 / 50 = 6.0m), depth = 0.40 m -> Under-sized (min is 6.0 / 12 = 0.50 m)
      const undersizedBeam = StructuralBeam(
        id: 'b1',
        start: Offset(100, 100),
        end: Offset(400, 100),
        width: 0.25,
        depth: 0.40,
      );

      // Beam 2: L = 6.0 m, depth = 0.50 m -> Adequate
      const adequateBeam = StructuralBeam(
        id: 'b2',
        start: Offset(100, 200),
        end: Offset(400, 200),
        width: 0.25,
        depth: 0.50,
      );

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: const [],
        columns: const [],
        shearWalls: const [],
        beams: const [undersizedBeam, adequateBeam],
      );

      final project = StructuralProject(
        title: 'Beam Sizing Project',
        storeys: [storey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );
      expect(report.beamChecks.length, 2);

      final check1 = report.beamChecks[0];
      expect(check1.spanM, closeTo(6.0, 0.05));
      expect(check1.recommendedMinDepthM, closeTo(0.50, 0.01));
      expect(check1.isDepthSufficient, isFalse);

      final check2 = report.beamChecks[1];
      expect(check2.isDepthSufficient, isTrue);
    });

    test('7. Opening proximity to columns (< 4d ~ 0.70m warning)', () {
      const scale = 50.0;
      // Slab with opening near column
      const openingNearCol = [
        Offset(220, 220),
        Offset(240, 220),
        Offset(240, 240),
        Offset(220, 240),
      ];

      final slab = StructuralSlab(
        id: 'slab1',
        polygon: const [
          Offset(0, 0),
          Offset(500, 0),
          Offset(500, 500),
          Offset(0, 500),
        ],
        openings: const [openingNearCol],
        thickness: 0.20,
      );

      // Column at (250, 250) -> Distance to opening polygon centroid (230, 230) is ~0.56 m < 0.70 m
      final col = StructuralColumn(
        id: 'col1',
        center: const Offset(250, 250),
        width: 0.30 * scale,
        height: 0.30 * scale,
        shape: ColumnShape.rectangular,
      );

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        elevation: 0.0,
        height: 3.0,
        slabs: [slab],
        columns: [col],
        shearWalls: const [],
        beams: const [],
      );

      final project = StructuralProject(
        title: 'Opening Proximity Project',
        storeys: [storey],
      );

      final report = SeismicAnalysisCalculator.analyzeProject(
        project,
        cadUnitsPerMeter: scale,
      );
      expect(report.openingChecks.length, 1);
      final opCheck = report.openingChecks.first;
      expect(opCheck.isTooClose, isTrue);
      expect(opCheck.nearestSupportName, isNotNull);
    });
  });
}
