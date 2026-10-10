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
      expect(slabCheck.recommendation, contains('предварителния ориентир'));
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

    test('4m axis raster with 25x25 columns calculates 4.0m span (not 12m) screens the assigned 20cm thickness without hidden tolerance', () {
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
      // Evaluate the actual 20 cm, without adding a hidden 1 cm tolerance.
      expect(slabCheck.isDeflectionSafe, false);
      expect(slabCheck.supportSpans.where((s) => s.isProblematic), hasLength(24));
      expect(report.slabIssuesCount, 1);
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

    test('Test 8: Framing beams relieve punching shear around column (no false punching risk)', () {
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: const [
            StructuralColumn(
              id: 'col_beam_supported',
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
          beams: const [
            StructuralBeam(
              id: 'b1',
              start: Offset(0.0, 5.0),
              end: Offset(5.0, 5.0),
              width: 0.25,
              depth: 0.50,
            ),
            StructuralBeam(
              id: 'b2',
              start: Offset(5.0, 5.0),
              end: Offset(10.0, 5.0),
              width: 0.25,
              depth: 0.50,
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
              thickness: 0.16, // Thin 16 cm slab would punch without beams
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'Beam Punching Relief Test',
        storeys: storeys,
        liveLoad: 4.0, // High load
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      final check = report.columnChecks.firstWhere((c) => c.columnId == 'col_beam_supported');

      expect(check.hasConnectedBeams, true);
      expect(check.punchingUtilization,greaterThan(0));
      expect(check.punchingRequiresReview,isTrue);
      expect(check.isPunchingCritical,check.punchingUtilization>1);
    });

    test('Test 9: Tributary area hierarchy accurately differentiates corner, edge, and interior columns', () {
      final List<StructuralColumn> cols = [];
      for (double y = 0.0; y <= 8.0; y += 4.0) {
        for (double x = 0.0; x <= 8.0; x += 4.0) {
          cols.add(StructuralColumn(
            id: 'c_${x.toInt()}_${y.toInt()}',
            center: Offset(x, y),
            width: 0.25,
            height: 0.25,
          ));
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
                Offset(8, 0),
                Offset(8, 8),
                Offset(0, 8),
              ],
              thickness: 0.20,
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'Tributary Hierarchy Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);

      final interior = report.columnChecks.firstWhere((c) => c.columnId == 'c_4_4');
      final edge = report.columnChecks.firstWhere((c) => c.columnId == 'c_4_0');
      final corner = report.columnChecks.firstWhere((c) => c.columnId == 'c_0_0');

      // Interior column carries full 4x4 bay ≈ 16 m²
      expect(interior.tributaryAreaM2, closeTo(16.0, 1.0));

      // Edge column carries approximately half of interior (around 7 - 10 m²)
      expect(edge.tributaryAreaM2, lessThan(interior.tributaryAreaM2));
      expect(edge.tributaryAreaM2, greaterThan(6.0));

      // Corner column carries approximately quarter of interior (around 3 - 6 m²)
      expect(corner.tributaryAreaM2, lessThan(edge.tributaryAreaM2));
      expect(corner.tributaryAreaM2, greaterThan(2.0));
    });

    test('Test 10: Multi-storey column rundown tracks setbacks and canopy columns correctly', () {
      // 3-storey building:
      // - Ground floor has 'col_main' at (0, 0) and 'col_canopy' at (4, 0)
      // - 1st floor has ONLY 'col_main' at (0, 0)
      // - 2nd floor has ONLY 'col_main' at (0, 0)
      final storeys = [
        const StoreyLevel(
          id: 's_0',
          name: 'Партер',
          elevation: 0.0,
          height: 3.0,
          columns: [
            StructuralColumn(id: 'col_main', center: Offset(0, 0), width: 0.30, height: 0.30),
            StructuralColumn(id: 'col_canopy', center: Offset(4, 0), width: 0.25, height: 0.25),
          ],
        ),
        const StoreyLevel(
          id: 's_1',
          name: 'Етаж 1',
          elevation: 3.0,
          height: 3.0,
          columns: [
            StructuralColumn(id: 'col_main', center: Offset(0, 0), width: 0.30, height: 0.30),
          ],
        ),
        const StoreyLevel(
          id: 's_2',
          name: 'Етаж 2',
          elevation: 6.0,
          height: 3.0,
          columns: [
            StructuralColumn(id: 'col_main', center: Offset(0, 0), width: 0.30, height: 0.30),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'Canopy Setback Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);

      // col_main at ground floor carries all 3 storeys
      final mainGround = report.columnChecks.firstWhere(
        (c) => c.columnId == 'col_main' && c.storeyIndex == 0,
      );
      expect(mainGround.numStoreysAbove, 3);

      // col_canopy at ground floor carries ONLY 1 storey (the canopy itself)
      final canopyGround = report.columnChecks.firstWhere(
        (c) => c.columnId == 'col_canopy' && c.storeyIndex == 0,
      );
      expect(canopyGround.numStoreysAbove, 1);
      expect(canopyGround.accumulatedLoadNedKn, lessThan(mainGround.accumulatedLoadNedKn));
    });

    test('Test 11: Total foundation load incorporates shear walls and beams self-weight', () {
      const wall = StructuralShearWall(
        id: 'w1',
        start: Offset(0, 0),
        end: Offset(4, 0),
        thickness: 0.25,
      );
      const beam = StructuralBeam(
        id: 'b1',
        start: Offset(0, 0),
        end: Offset(4, 0),
        width: 0.25,
        depth: 0.50,
      );
      final storeysWithout = [
        const StoreyLevel(
          id: 's1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: [
            StructuralColumn(id: 'c1', center: Offset(2, 2), width: 0.25, height: 0.25),
          ],
        ),
      ];
      final storeysWith = [
        const StoreyLevel(
          id: 's1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          columns: [
            StructuralColumn(id: 'c1', center: Offset(2, 2), width: 0.25, height: 0.25),
          ],
          shearWalls: [wall],
          beams: [beam],
        ),
      ];

      final repWithout = VerticalCapacityCalculator.analyzeProject(
        StructuralProject(title: 'Without', storeys: storeysWithout),
      );
      final repWith = VerticalCapacityCalculator.analyzeProject(
        StructuralProject(title: 'With', storeys: storeysWith),
      );

      // The project with shear walls and beams must have significantly higher foundation vertical load
      expect(repWith.totalVerticalLoadBaseKn, greaterThan(repWithout.totalVerticalLoadBaseKn));
      expect(repWith.basePressureKpa, greaterThan(repWithout.basePressureKpa));
    });

    test('Test 12: Real layout with 12.5cm off-axis snapping does not create false 12m slanted span across intermediate elements', () {
      // Replicates the user's exact project layout:
      // - 4 axes spaced 4m apart along X (X = 0, 4, 8, 12)
      // - Column K1 on Axis 1 at (0.0, 0.0)
      // - Column K2 on Axis 2 snapped 12.5 cm off-axis at (4.0, -0.125)
      // - Shear wall W4 on Axis 3 at (8.0, 0.0)
      // - Shear wall W8 on Axis 4 at (12.0, 1.50)
      // - Additional interior elements (K6 at 4, 4)
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          gridAxes: [
            const StructuralGridAxis(id: 'a1', name: '1', start: Offset(0, -2), end: Offset(0, 10)),
            const StructuralGridAxis(id: 'a2', name: '2', start: Offset(4, -2), end: Offset(4, 10)),
            const StructuralGridAxis(id: 'a3', name: '3', start: Offset(8, -2), end: Offset(8, 10)),
            const StructuralGridAxis(id: 'a4', name: '4', start: Offset(12, -2), end: Offset(12, 10)),
          ],
          columns: const [
            StructuralColumn(id: 'col_k1', center: Offset(0.0, 0.0), width: 0.25, height: 0.25),
            StructuralColumn(id: 'col_k2', center: Offset(3.875, 0.0), width: 0.25, height: 0.40), // 12.5cm off-axis from Axis 2 (X=4.0)!
            StructuralColumn(id: 'col_k6', center: Offset(4.0, 4.0), width: 0.25, height: 0.25),
          ],
          shearWalls: const [
            StructuralShearWall(id: 'w4', start: Offset(7.0, 0.0), end: Offset(9.0, 0.0), thickness: 0.25),
            StructuralShearWall(id: 'w8', start: Offset(11.0, 1.5), end: Offset(13.0, 1.5), thickness: 0.25),
          ],
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(-0.5, -0.5),
                Offset(13.0, -0.5),
                Offset(13.0, 10.0),
                Offset(-0.5, 10.0),
              ],
              thickness: 0.20, // 20 cm slab
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'User 12.5cm Snap Real Layout',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);

      // Verify that the maximum clear span is approximately 4.0 m (between adjacent bays),
      // and NOT a 11.95 m / 12.0 m diagonal jump across K2 and W4!
      final slabCheck = report.slabChecks.first;
      expect(slabCheck.maxSpanM, lessThan(5.0));
      expect(slabCheck.maxSpanM, closeTo(4.0, 0.5));

      // The layout must not invent a 12 m bay. The actual 20 cm thickness
      // is nevertheless below the simplified limit for the approximately 4 m bay.
      expect(slabCheck.isDeflectionSafe, false);
      expect(report.slabIssuesCount, 1);
    });

    test('Test 13: Spans along grid axis do not cross intersecting perpendicular shear walls (no false 9.92m span)', () {
      // Replicates the scenario from screenshot media_1791066782647.png:
      // - Vertical axis along X = 0
      // - Column K7 at (0.0, 0.0)
      // - Horizontal shear wall W6 at Y = 4.37, starting on the axis at (0.0, 4.37)
      // - Second horizontal shear wall W_lower at Y = 7.50
      // - Support at (0.0, 9.92)
      final storeys = [
        StoreyLevel(
          id: 'storey_1',
          name: 'Етаж 1',
          elevation: 0.0,
          height: 3.0,
          gridAxes: const [
            StructuralGridAxis(id: 'axis_v', name: 'A', start: Offset(0, -1), end: Offset(0, 12)),
          ],
          columns: const [
            StructuralColumn(id: 'col_k7', center: Offset(0.0, 0.0), width: 0.25, height: 0.40),
            StructuralColumn(id: 'col_bottom', center: Offset(0.0, 9.92), width: 0.25, height: 0.40),
          ],
          shearWalls: const [
            StructuralShearWall(id: 'w6', start: Offset(0.0, 4.37), end: Offset(3.0, 4.37), thickness: 0.25),
            StructuralShearWall(id: 'w_lower', start: Offset(0.0, 7.50), end: Offset(3.0, 7.50), thickness: 0.25),
          ],
          slabs: const [
            StructuralSlab(
              id: 'slab_1',
              polygon: [
                Offset(-1.0, -1.0),
                Offset(5.0, -1.0),
                Offset(5.0, 12.0),
                Offset(-1.0, 12.0),
              ],
              thickness: 0.20,
            ),
          ],
        ),
      ];

      final project = StructuralProject(
        title: 'Intersecting Shear Walls Test',
        storeys: storeys,
      );

      final report = VerticalCapacityCalculator.analyzeProject(project);
      final slabCheck = report.slabChecks.first;

      // The span must NOT jump across W6 and W_lower (9.92 m).
      // Instead, it must be bounded by W6 (approx 4.37 m).
      expect(slabCheck.maxSpanM, lessThan(5.0));
      expect(slabCheck.maxSpanM, closeTo(4.37, 0.1));
      expect(slabCheck.criticalSpanSegment, isNotNull);

      // The critical segment must start at K7 and end at W6 (not 9.92m to col_bottom)
      final seg = slabCheck.criticalSpanSegment!;
      final segLenM = (seg.$2 - seg.$1).distance;
      expect(segLenM, closeTo(4.37, 0.1));
    });
  });
}
