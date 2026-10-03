import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/vertical_capacity_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/vertical_capacity_models.dart';

void main() {
  group('Eurocode 2 (EC2) Vertical Gravitational Capacity & Crushing Tests', () {
    test('Concrete grade f_ck parsing', () {
      expect(VerticalCapacityCalculator.parseConcreteFck('C25/30'), 25.0);
      expect(VerticalCapacityCalculator.parseConcreteFck('C30/37'), 30.0);
      expect(VerticalCapacityCalculator.parseConcreteFck('C20/25'), 20.0);
      expect(VerticalCapacityCalculator.parseConcreteFck('C35/45'), 35.0);
      expect(VerticalCapacityCalculator.parseConcreteFck('unknown'), 25.0);
    });

    test('Column cross-sectional area calculations for various shapes', () {
      const scale = 1.0;

      // 1. Rectangular 25x25 cm
      const col25x25 = StructuralColumn(
        id: 'c1',
        center: Offset(0, 0),
        width: 0.25,
        height: 0.25,
        shape: ColumnShape.rectangular,
      );
      expect(
        VerticalCapacityCalculator.getColumnAreaM2(col25x25, scale),
        closeTo(0.0625, 1e-4),
      );

      // 2. Rectangular 40x40 cm
      const col40x40 = StructuralColumn(
        id: 'c2',
        center: Offset(0, 0),
        width: 0.40,
        height: 0.40,
        shape: ColumnShape.rectangular,
      );
      expect(
        VerticalCapacityCalculator.getColumnAreaM2(col40x40, scale),
        closeTo(0.1600, 1e-4),
      );

      // 3. L-shape 50x50/25 cm
      const colLShape = StructuralColumn(
        id: 'c3',
        center: Offset(0, 0),
        width: 0.50,
        height: 0.50,
        thickness: 0.25,
        shape: ColumnShape.lShape,
      );
      // Area = 0.50 * 0.25 + (0.50 - 0.25) * 0.25 = 0.125 + 0.0625 = 0.1875 m²
      expect(
        VerticalCapacityCalculator.getColumnAreaM2(colLShape, scale),
        closeTo(0.1875, 1e-4),
      );
    });

    test('Multi-storey load accumulation flags 25x25 cm column crushing under 5 storeys', () {
      // Create a 5-storey building
      // Each storey has a 25x25 column at (5, 5) with surrounding supports at 5m grid spacing
      // creating tributary area ~ 25 m²
      final List<StoreyLevel> storeys = [];
      for (int i = 1; i <= 5; i++) {
        storeys.add(StoreyLevel(
          id: 'storey_$i',
          name: 'Етаж $i',
          elevation: (i - 1) * 3.0,
          height: 3.0,
          columns: [
            const StructuralColumn(
              id: 'col_c3',
              center: Offset(5.0, 5.0),
              width: 0.25,
              height: 0.25,
              shape: ColumnShape.rectangular,
            ),
            const StructuralColumn(
              id: 'col_corner',
              center: Offset(0.0, 0.0),
              width: 0.25,
              height: 0.25,
              shape: ColumnShape.rectangular,
            ),
            const StructuralColumn(
              id: 'col_edge',
              center: Offset(10.0, 5.0),
              width: 0.25,
              height: 0.25,
              shape: ColumnShape.rectangular,
            ),
          ],
          slabs: [
            const StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(0, 0),
                Offset(10, 0),
                Offset(10, 10),
                Offset(0, 10),
              ],
              thickness: 0.20,
            ),
          ],
        ));
      }

      final project = StructuralProject(
        title: '5-Storey Test Building',
        concreteGrade: 'C25/30',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);

      // Verify overall report
      expect(report.columnChecks.isNotEmpty, true);
      expect(report.totalVerticalLoadBaseKn, greaterThan(1000.0));
      expect(report.basePressureKpa, greaterThan(10.0));

      // Find Ground Floor (Етаж 1) check for col_c3
      final groundColCheck = report.columnChecks.firstWhere(
        (c) => c.columnId == 'col_c3' && c.storeyIndex == 0,
      );

      // Col carries 5 storeys
      expect(groundColCheck.numStoreysAbove, 5);

      // For 25x25 cm column:
      // Ac = 0.0625 m²
      // fcd = 14.17 MPa, fyd = 434.78 MPa, rho = 1%
      // Nrd ≈ 0.80 * (0.0625 * 14.17 * 1000 + 0.000625 * 434.78 * 1000) ≈ 850-925 kN
      expect(groundColCheck.axialCapacityNrdKn, closeTo(925.0, 100.0));

      // Tributary load from 5 floors: Ned > 1300 kN
      expect(groundColCheck.accumulatedLoadNedKn, greaterThan(groundColCheck.axialCapacityNrdKn));
      expect(groundColCheck.axialUtilization, greaterThan(1.0));
      expect(groundColCheck.status, VerticalCapacityStatus.critical);

      // Required minimum section for 5 storeys must be >= 40x40 cm
      expect(groundColCheck.minRequiredSectionCm, contains('40x40 cm'));

      // Architect-facing Bulgarian recommendation must clearly state column cannot be 25x25
      // and requires minimum 40x40 cm (or shear wall 25x60)
      expect(
        groundColCheck.architectRecommendation,
        contains('не може да е 25x25 cm, трябва да е минимум'),
      );
      expect(
        groundColCheck.architectRecommendation,
        contains('за да носи 5 етажа'),
      );

      // Check Top Floor (Етаж 5) for col_c3
      final topColCheck = report.columnChecks.firstWhere(
        (c) => c.columnId == 'col_c3' && c.storeyIndex == 4,
      );
      expect(topColCheck.numStoreysAbove, 1);
      expect(topColCheck.accumulatedLoadNedKn, lessThan(groundColCheck.accumulatedLoadNedKn));
      expect(topColCheck.axialUtilization, lessThan(0.60));
      expect(topColCheck.isAxiallyOverloaded, false);
      expect(topColCheck.accumulatedLoadNedKn, closeTo(groundColCheck.accumulatedLoadNedKn / 5.0, 50.0));
    });

    test('Slab deflection check according to EC2 §7.4 identifies thin slab with large span', () {
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: const [
            StructuralColumn(
              id: 'c1',
              center: Offset(0.0, 0.0),
              width: 0.40,
              height: 0.40,
            ),
            StructuralColumn(
              id: 'c2',
              center: Offset(6.60, 0.0), // Span = 6.60 m
              width: 0.40,
              height: 0.40,
            ),
          ],
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(0, 0),
                Offset(7, 0),
                Offset(7, 7),
                Offset(0, 7),
              ],
              thickness: 0.18, // 18 cm slab for 6.6m span is too thin without beams
            ),
          ],
          beams: const [], // Flat slab
        ),
      ];

      final project = StructuralProject(
        title: 'Deflection Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      expect(report.slabChecks.length, 1);

      final slabCheck = report.slabChecks.first;
      expect(slabCheck.maxSpanM, closeTo(6.60, 0.1));
      // Basic ratio for flat slab is 22 -> d_req = 6.6 / 22 = 0.30 m -> h_req >= 0.33 m
      expect(slabCheck.recommendedMinThicknessM, greaterThan(0.25));
      expect(slabCheck.isDeflectionSafe, false);
      expect(slabCheck.recommendation, contains('провисне недопустимо'));
    });

    test('Punching shear check according to EC2 §6.4 detects shear risk', () {
      // Column with high shear load and small slab thickness
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: const [
            StructuralColumn(
              id: 'c_interior',
              center: Offset(5.0, 5.0),
              width: 0.25,
              height: 0.25,
            ),
            StructuralColumn(
              id: 'c_left',
              center: Offset(0.0, 5.0),
              width: 0.25,
              height: 0.25,
            ),
            StructuralColumn(
              id: 'c_right',
              center: Offset(10.0, 5.0),
              width: 0.25,
              height: 0.25,
            ),
          ],
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(0, 0),
                Offset(10, 0),
                Offset(10, 10),
                Offset(0, 10),
              ],
              thickness: 0.16, // Very thin 16 cm slab
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'Punching Test',
        storeys: storeys,
        liveLoad: 4.0, // High live load
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      expect(report.columnChecks.isNotEmpty, true);

      final interiorCheck = report.columnChecks.firstWhere(
        (c) => c.columnId == 'c_interior',
      );
      expect(interiorCheck.punchingShearStressVedMpa, greaterThan(0.0));
      expect(interiorCheck.punchingShearResistanceVrdMpa, greaterThan(0.0));
    });

    test('4m axis raster with 25x25 columns calculates 4.0m span (not 12m) and confirms 20cm slab is safe', () {
      // 4 axes spaced 4m apart along X (0, 4, 8, 12) and 4 axes along Y (0, 4, 8, 12)
      // Total 16 columns 25x25 on every intersection
      final List<StructuralColumn> cols = [];
      int idx = 1;
      for (double y = 0.0; y <= 12.0; y += 4.0) {
        for (double x = 0.0; x <= 12.0; x += 4.0) {
          cols.add(StructuralColumn(
            id: 'col_$idx',
            name: 'К$idx',
            center: Offset(x, y),
            width: 0.25,
            height: 0.25,
            shape: ColumnShape.rectangular,
          ));
          idx++;
        }
      }

      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: cols,
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(0, 0),
                Offset(12, 0),
                Offset(12, 12),
                Offset(0, 12),
              ],
              thickness: 0.20, // 20 cm flat slab
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: '4m Grid Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      expect(report.slabChecks.isNotEmpty, true);

      final slabCheck = report.slabChecks.first;

      // Span must be 4.00 m, NOT 12.00 m!
      expect(slabCheck.maxSpanM, closeTo(4.00, 0.05));
      expect(slabCheck.criticalSpanSegment, isNotNull);

      // Distance of critical span segment must be 4.0 m
      final seg = slabCheck.criticalSpanSegment!;
      expect((seg.$2 - seg.$1).distance, closeTo(4.00, 0.05));

      // Recommended minimum thickness for 4m flat slab:
      // d_req = 4.0 / 22 = 0.1818 m -> h_req = 0.1818 + 0.03 = 0.21 m (21 cm)
      // Since 20 cm is within 1 cm of 21 cm, 20 cm is safe!
      expect(slabCheck.isDeflectionSafe, true);
      expect(slabCheck.recommendation, contains('напълно достатъчна'));

      // Slabs has no issues, so slabIssuesCount is 0
      expect(report.slabIssuesCount, 0);
    });

    test('Large 6.5m clear span with 20cm slab flags warning and populates criticalSpanSegment', () {
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: const [
            StructuralColumn(
              id: 'c1',
              center: Offset(0.0, 0.0),
              width: 0.30,
              height: 0.30,
            ),
            StructuralColumn(
              id: 'c2',
              center: Offset(6.50, 0.0),
              width: 0.30,
              height: 0.30,
            ),
          ],
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(0, 0),
                Offset(7, 0),
                Offset(7, 5),
                Offset(0, 5),
              ],
              thickness: 0.20, // 20 cm slab for 6.5m span is insufficient
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: '6.5m Span Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      final slabCheck = report.slabChecks.first;

      expect(slabCheck.maxSpanM, closeTo(6.50, 0.05));
      expect(slabCheck.isDeflectionSafe, false);
      expect(slabCheck.criticalSpanSegment, isNotNull);
      expect(report.slabIssuesCount, 1);
      expect(report.totalAlertCount, greaterThanOrEqualTo(1));
      expect(report.overallStatus, isNot(VerticalCapacityStatus.safe));
    });
  });
}
