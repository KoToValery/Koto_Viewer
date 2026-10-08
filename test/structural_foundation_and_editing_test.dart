import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/models/wall_axis_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';

void main() {
  group('Structural Foundation & Grid Axes Instances Tests', () {
    test('1. Default strip footings (ивични основи) at ground level ±0.00', () {
      final groundStorey = StoreyLevel(
        id: 'storey_1',
        name: 'Етаж 1 (Кота ±0.00)',
        elevation: 0.0,
        height: 2.80,
        columns: const [
          StructuralColumn(
            id: 'col_1',
            name: 'К1',
            center: Offset(0, 0),
            width: 0.25,
            height: 0.25,
          ),
          StructuralColumn(
            id: 'col_2',
            name: 'К2',
            center: Offset(4.0, 0),
            width: 0.25,
            height: 0.25,
          ),
        ],
        shearWalls: const [
          StructuralShearWall(
            id: 'wall_1',
            name: 'Ш1',
            start: Offset(0, 4.0),
            end: Offset(2.5, 4.0),
            thickness: 0.25,
          ),
        ],
      );

      final project = StructuralProject(
        storeys: [groundStorey],
        foundationType: FoundationType.stripFooting,
      );

      expect(project.hasBasement, isFalse);

      final strips = project.computeDefaultStripFoundations(groundStorey, cadUnitsPerMeter: 1.0);
      expect(strips.isNotEmpty, isTrue);

      // Verify strip footing polygons are valid 4-point quadrilaterals
      for (final strip in strips) {
        expect(strip.length, equals(4));
        expect(StructuralSlab.calculateArea(strip), greaterThan(0.0));
      }
    });

    test('2. Default mat foundation (фундаментна плоча) calculation', () {
      final groundStorey = StoreyLevel(
        id: 'storey_1',
        name: 'Етаж 1 (Кота ±0.00)',
        elevation: 0.0,
        height: 2.80,
        columns: const [
          StructuralColumn(
            id: 'col_1',
            center: Offset(0, 0),
            width: 0.25,
            height: 0.25,
          ),
          StructuralColumn(
            id: 'col_2',
            center: Offset(5.0, 0),
            width: 0.25,
            height: 0.25,
          ),
          StructuralColumn(
            id: 'col_3',
            center: Offset(5.0, 4.0),
            width: 0.25,
            height: 0.25,
          ),
          StructuralColumn(
            id: 'col_4',
            center: Offset(0, 4.0),
            width: 0.25,
            height: 0.25,
          ),
        ],
      );

      final project = StructuralProject(
        storeys: [groundStorey],
        foundationType: FoundationType.matFoundation,
      );

      final mat = project.computeDefaultMatFoundation(groundStorey, marginMeters: 0.50);
      expect(mat, isNotNull);
      expect(mat!.polygon.length, greaterThanOrEqualTo(4));
      // Base bounding area should exceed 5x4 = 20 m² due to 0.5m margin
      expect(mat.netArea, greaterThan(20.0));
      expect(mat.thickness, equals(0.50));
    });

    test('3. Project-wide Grid Axes as instances across all storeys', () {
      const axis1 = StructuralGridAxis(
        id: 'axis_1',
        name: '1',
        start: Offset(0, -2),
        end: Offset(0, 10),
      );
      const axis2 = StructuralGridAxis(
        id: 'axis_2',
        name: '2',
        start: Offset(4, -2),
        end: Offset(4, 10),
      );

      final storey1 = StoreyLevel(
        id: 'storey_1',
        name: 'Етаж 1 (±0.00)',
        elevation: 0.0,
        gridAxes: const [axis1, axis2],
      );
      final storey2 = StoreyLevel(
        id: 'storey_2',
        name: 'Етаж 2 (+2.80)',
        elevation: 2.80,
        gridAxes: const [axis1, axis2],
      );

      var project = StructuralProject(
        storeys: [storey1, storey2],
        gridAxes: const [axis1, axis2],
      );

      expect(project.effectiveGridAxes.length, equals(2));

      // Deleting axis 2 on the project level updates all storeys
      project = project.copyWithGridAxes([axis1]);
      expect(project.effectiveGridAxes.length, equals(1));
      expect(project.storeys[0].gridAxes.length, equals(1));
      expect(project.storeys[1].gridAxes.length, equals(1));
      expect(project.storeys[0].gridAxes.first.id, equals('axis_1'));
      expect(project.storeys[1].gridAxes.first.id, equals('axis_1'));
    });

    test('4. Slab edge extrusion keeps original vertices in place and inserts two new vertices', () {
      const initialSlab = StructuralSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),   // V0
          Offset(4, 0),   // V1 (edge index 1: from V1 to V2)
          Offset(4, 4),   // V2
          Offset(0, 4),   // V3
        ],
      );

      // Extrude edge 1 (from (4,0) to (4,4)) outward by 1.5m (+X normal)
      final extruded = initialSlab.extrudeEdgeParallel(
        edgeIndex: 1,
        distance: 1.5,
      );

      // Polygon now has 6 vertices (4 original + 2 new)
      expect(extruded.polygon.length, equals(6));

      // Original V0 and V1 remain at their exact coordinates
      expect(extruded.polygon[0], equals(const Offset(0, 0)));
      expect(extruded.polygon[1], equals(const Offset(4, 0)));

      // New extruded vertices are inserted immediately after V1
      expect(extruded.polygon[2].dx, closeTo(5.5, 0.01));
      expect(extruded.polygon[2].dy, closeTo(0.0, 0.01));

      expect(extruded.polygon[3].dx, closeTo(5.5, 0.01));
      expect(extruded.polygon[3].dy, closeTo(4.0, 0.01));

      // Original V2 and V3 follow and remain at their exact coordinates
      expect(extruded.polygon[4], equals(const Offset(4, 4)));
      expect(extruded.polygon[5], equals(const Offset(0, 4)));
    });

    test('5. Strip foundations scaling does not explode at cm scale (100 units/m)', () {
      // In cm: a 25x30cm column has width=25, height=30
      const scaleCm = 100.0;
      final groundStorey = StoreyLevel(
        id: 'storey_cm',
        name: 'Floor ±0.00',
        elevation: 0.0,
        height: 280.0,
        columns: const [
          StructuralColumn(
            id: 'c1',
            center: Offset(100, 100),
            width: 25.0,
            height: 30.0,
          ),
        ],
        shearWalls: const [
          StructuralShearWall(
            id: 'w1',
            start: Offset(200, 100),
            end: Offset(350, 100),
            thickness: 25.0,
          ),
        ],
      );

      final project = StructuralProject(
        storeys: [groundStorey],
        foundationType: FoundationType.stripFooting,
      );

      final strips = project.computeDefaultStripFoundations(groundStorey, cadUnitsPerMeter: scaleCm);
      expect(strips.length, equals(2)); // 1 wall strip + 1 col pad

      // Wall strip: 60cm wide (halfW = 30cm) -> width in Y is 60cm
      final wallStrip = strips[0];
      final wallMinY = wallStrip.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final wallMaxY = wallStrip.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      expect(wallMaxY - wallMinY, closeTo(60.0, 0.1));

      // Column pad: 75x80cm -> width in X is 75cm, height in Y is 80cm
      final colPad = strips[1];
      final colMinX = colPad.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final colMaxX = colPad.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final colMinY = colPad.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final colMaxY = colPad.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      expect(colMaxX - colMinX, closeTo(75.0, 0.1));
      expect(colMaxY - colMinY, closeTo(80.0, 0.1));
    });

    test('6. WallAxisDetector.computeClosureSegmentsForPairs returns perpendicular jamb caps', () {
      // Wall pair: horizontal wall of length 200, thickness 25
      const segA = WallSegment(
        start: Offset(0, 0),
        end: Offset(200, 0),
        angleRad: 0.0,
        offsetFromOrigin: 0.0,
        length: 200.0,
        sourceLayer: 'WALL',
      );
      const segB = WallSegment(
        start: Offset(0, 25),
        end: Offset(200, 25),
        angleRad: 0.0,
        offsetFromOrigin: 25.0,
        length: 200.0,
        sourceLayer: 'WALL',
      );
      const pair = WallPairCandidate(
        segmentA: segA,
        segmentB: segB,
        perpendicularDistance: 25.0,
        overlapLength: 200.0,
        centerlineStart: Offset(0, 12.5),
        centerlineEnd: Offset(200, 12.5),
      );

      final caps = WallAxisDetector.computeClosureSegmentsForPairs([pair]);
      // Should have 2 closure caps (one at start x=0, one at end x=200)
      expect(caps.length, equals(2));
      for (final cap in caps) {
        // Vertical jamb lines across thickness 25
        expect((cap.$1 - cap.$2).distance, closeTo(25.0, 0.01));
      }
    });
  });
}
