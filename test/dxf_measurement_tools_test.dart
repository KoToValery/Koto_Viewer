import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dxf_exporter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/dxf_viewer/widgets/dxf_measurement_canvas_painter.dart';

void main() {
  group('DXF Area Measurement Tests', () {
    test('Calculates area of a 10x20 rectangle correctly', () {
      final rectPoints = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 20),
        const Offset(0, 20),
      ];

      final area = DxfMath.calculatePolygonArea(rectPoints);
      final perim = DxfMath.calculatePolygonPerimeter(rectPoints, isClosed: true);

      expect(area, closeTo(200.0, 1e-6));
      expect(perim, closeTo(60.0, 1e-6));
    });

    test('Calculates area of a right triangle (base=6, height=8)', () {
      final triangle = [
        const Offset(0, 0),
        const Offset(6, 0),
        const Offset(0, 8),
      ];

      final area = DxfMath.calculatePolygonArea(triangle);
      final perim = DxfMath.calculatePolygonPerimeter(triangle, isClosed: true);

      expect(area, closeTo(24.0, 1e-6));
      expect(perim, closeTo(24.0, 1e-6));
    });

    test('Calculates polygon centroid accurately', () {
      final rectPoints = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 20),
        const Offset(0, 20),
      ];

      final centroid = DxfMath.calculatePolygonCentroid(rectPoints);
      expect(centroid.dx, closeTo(5.0, 1e-5));
      expect(centroid.dy, closeTo(10.0, 1e-5));
    });

    test('Handles edge cases (empty or less than 3 points)', () {
      expect(DxfMath.calculatePolygonArea([]), 0.0);
      expect(DxfMath.calculatePolygonArea([const Offset(1, 1)]), 0.0);
      expect(DxfMath.calculatePolygonArea([const Offset(1, 1), const Offset(2, 2)]), 0.0);
    });

    test('Formats area string properly in English units', () {
      expect(DxfMath.formatArea(25.5), '25.500 m²');
      expect(DxfMath.formatArea(150.25), '150.25 m²');
      expect(DxfMath.formatArea(25000.0), contains('25000.0 m² (2.50 ha)'));
    });
  });

  group('DXF Angle Measurement Tests', () {
    test('Calculates perpendicular 90 degree angle', () {
      const vertex = Offset(0, 0);
      const p1 = Offset(10, 0);
      const p2 = Offset(0, 10);

      final angle = DxfMath.calculateAngleBetweenVectors(vertex, p1, p2);
      expect(angle, closeTo(90.0, 1e-5));
    });

    test('Calculates 45 degree angle', () {
      const vertex = Offset(0, 0);
      const p1 = Offset(10, 0);
      const p2 = Offset(10, 10);

      final angle = DxfMath.calculateAngleBetweenVectors(vertex, p1, p2);
      expect(angle, closeTo(45.0, 1e-5));
    });

    test('Calculates 180 degree collinear opposing angle', () {
      const vertex = Offset(0, 0);
      const p1 = Offset(10, 0);
      const p2 = Offset(-10, 0);

      final angle = DxfMath.calculateAngleBetweenVectors(vertex, p1, p2);
      expect(angle, closeTo(180.0, 1e-5));
    });

    test('Returns 0 for coincident points or zero vectors', () {
      const vertex = Offset(0, 0);
      const p1 = Offset(0, 0);
      const p2 = Offset(10, 0);

      final angle = DxfMath.calculateAngleBetweenVectors(vertex, p1, p2);
      expect(angle, 0.0);
    });
  });

  group('DXF Radius and Diameter Measurement Tests', () {
    test('Calculates circumcircle passing through 3 points on radius 5 circle', () {
      const p1 = Offset(5, 0);
      const p2 = Offset(0, 5);
      const p3 = Offset(-5, 0);

      final result = DxfMath.circleFrom3Points(p1, p2, p3);
      expect(result, isNotNull);
      expect(result!.center.dx, closeTo(0.0, 1e-5));
      expect(result.center.dy, closeTo(0.0, 1e-5));
      expect(result.radius, closeTo(5.0, 1e-5));
    });

    test('Returns null for collinear points when solving circle', () {
      const p1 = Offset(0, 0);
      const p2 = Offset(5, 5);
      const p3 = Offset(10, 10);

      final result = DxfMath.circleFrom3Points(p1, p2, p3);
      expect(result, isNull);
    });

    test('Direct detection of DxfCircle via findClosestCircleOrArc', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          DxfCircle(
            center: const Offset(100, 100),
            radius: 25.0,
            layer: '0',
          ),
          DxfArc(
            center: const Offset(200, 200),
            radius: 40.0,
            startAngleDeg: 0,
            endAngleDeg: 90,
            layer: '0',
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 300, 300),
        entityStats: {},
      );

      final circleHit = DxfSnapHelper.findClosestCircleOrArc(
        document: doc,
        cadPoint: const Offset(124, 100),
        toleranceCad: 5.0,
      );

      expect(circleHit, isNotNull);
      expect(circleHit!.isArc, isFalse);
      expect(circleHit.center, const Offset(100, 100));
      expect(circleHit.radius, 25.0);

      final arcX = 200.0 + 40.0 * math.cos(math.pi / 4.0);
      final arcY = 200.0 + 40.0 * math.sin(math.pi / 4.0);

      final arcHit = DxfSnapHelper.findClosestCircleOrArc(
        document: doc,
        cadPoint: Offset(arcX + 1.0, arcY - 1.0),
        toleranceCad: 5.0,
      );

      expect(arcHit, isNotNull);
      expect(arcHit!.isArc, isTrue);
      expect(arcHit.center, const Offset(200, 200));
      expect(arcHit.radius, 40.0);
      expect(arcHit.arcLength, closeTo(40.0 * (math.pi / 2.0), 1e-4));
    });
  });

  group('DxfMeasurement Multi-tool Model Tests', () {
    test('Supports all 4 tools with respective getters', () {
      final mDist = DxfMeasurement(
        tool: DxfMeasureTool.distance,
        p1Cad: const Offset(0, 0),
        p2Cad: const Offset(3, 4),
      );
      expect(mDist.distance, 5.0);
      expect(mDist.deltaX, 3.0);
      expect(mDist.deltaY, 4.0);

      final mArea = DxfMeasurement(
        tool: DxfMeasureTool.area,
        areaPoints: [
          const Offset(0, 0),
          const Offset(10, 0),
          const Offset(10, 10),
          const Offset(0, 10),
        ],
      );
      expect(mArea.area, 100.0);
      expect(mArea.perimeter, 40.0);

      final mAngle = DxfMeasurement(
        tool: DxfMeasureTool.angle,
        angleVertex: const Offset(0, 0),
        angleP1: const Offset(10, 0),
        angleP2: const Offset(0, 10),
      );
      expect(mAngle.angleDegrees, closeTo(90.0, 1e-5));

      final mRadius = DxfMeasurement(
        tool: DxfMeasureTool.radius,
        circleCenter: const Offset(50, 50),
        radius: 12.5,
      );
      expect(mRadius.radius, 12.5);
      expect(mRadius.diameter, 25.0);
    });
  });

  group('DxfAnnotation Model & JSON Persistence', () {
    test('Serializes and deserializes DxfAnnotation correctly', () {
      final anno = DxfAnnotation(
        id: 'anno_test_1',
        arrowTipCad: const Offset(12.5, 34.8),
        textPosCad: const Offset(50.0, 60.0),
        text: 'Relocate column 20cm north',
        colorValue: 0xFFFFD600,
        createdAt: DateTime(2026, 8, 26, 22, 0),
      );

      final json = anno.toJson();
      final restored = DxfAnnotation.fromJson(json);

      expect(restored.id, 'anno_test_1');
      expect(restored.arrowTipCad, const Offset(12.5, 34.8));
      expect(restored.textPosCad, const Offset(50.0, 60.0));
      expect(restored.text, 'Relocate column 20cm north');
      expect(restored.colorValue, 0xFFFFD600);
      expect(restored.color, const Color(0xFFFFD600));
    });
  });

  group('DxfExporterService DXF Ingestion & Re-parsing', () {
    test('Exports annotations as valid DXF LEADER and MTEXT entities readable by DxfParser', () async {
      final tempDir = await Directory.systemTemp.createTemp('dxf_test_');
      final originalFile = File('${tempDir.path}/base.dxf');
      final outputFile = File('${tempDir.path}/annotated.dxf');

      // Minimal valid DXF
      await originalFile.writeAsString('''0
SECTION
2
ENTITIES
0
LINE
8
0
10
0.0
20
0.0
30
0.0
11
100.0
21
100.0
31
0.0
0
ENDSEC
0
EOF
''');

      final annotations = [
        DxfAnnotation(
          id: 'anno_1',
          arrowTipCad: const Offset(50.0, 50.0),
          textPosCad: const Offset(70.0, 80.0),
          text: 'Verify opening width',
          colorValue: 0xFFFF5252, // Red
          createdAt: DateTime.now(),
        ),
      ];

      await DxfExporterService.saveDxfWithAnnotations(
        originalFile: originalFile,
        annotations: annotations,
        outputFile: outputFile,
      );

      expect(await outputFile.exists(), isTrue);
      final exportedContent = await outputFile.readAsString();

      expect(exportedContent, contains('LEADER'));
      expect(exportedContent, contains('MTEXT'));
      expect(exportedContent, contains('MARKUP'));
      expect(exportedContent, contains('Verify opening width'));

      // Re-parse with DxfParser to confirm valid CAD structures
      final doc = DxfParser.parseString(exportedContent);
      final leaders = doc.entities.whereType<DxfLeader>().toList();
      final mtexts = doc.entities.whereType<DxfMText>().toList();

      expect(leaders.length, 1);
      expect(leaders.first.layer, 'MARKUP');
      expect(leaders.first.vertices.first.dx, closeTo(50.0, 1e-4));
      expect(leaders.first.vertices.first.dy, closeTo(50.0, 1e-4));

      expect(mtexts.length, 1);
      expect(mtexts.first.layer, 'MARKUP');
      expect(mtexts.first.cleanText, contains('Verify opening width'));

      await tempDir.delete(recursive: true);
    });
  });

  group('DxfMeasurement Initial Click & Point Transitions', () {
    test('Initial click on Distance tool sets p1Cad when freshly initialized', () {
      // Represents the state when entering measure mode:
      var measurement = const DxfMeasurement(tool: DxfMeasureTool.distance);
      expect(measurement.p1Cad, isNull);
      expect(measurement.p2Cad, isNull);

      const firstPoint = Offset(10.0, 20.0);
      const secondPoint = Offset(30.0, 40.0);

      // 1st click
      if (measurement.tool != DxfMeasureTool.distance ||
          measurement.p1Cad == null ||
          measurement.p2Cad != null) {
        measurement = DxfMeasurement(
          tool: DxfMeasureTool.distance,
          p1Cad: firstPoint,
        );
      } else {
        measurement = DxfMeasurement(
          tool: DxfMeasureTool.distance,
          p1Cad: measurement.p1Cad,
          p2Cad: firstPoint,
        );
      }

      expect(measurement.p1Cad, firstPoint, reason: 'First click must set p1Cad, not be ignored!');
      expect(measurement.p2Cad, isNull);

      // 2nd click
      if (measurement.tool != DxfMeasureTool.distance ||
          measurement.p1Cad == null ||
          measurement.p2Cad != null) {
        measurement = DxfMeasurement(
          tool: DxfMeasureTool.distance,
          p1Cad: secondPoint,
        );
      } else {
        measurement = DxfMeasurement(
          tool: DxfMeasureTool.distance,
          p1Cad: measurement.p1Cad,
          p2Cad: secondPoint,
        );
      }

      expect(measurement.p1Cad, firstPoint);
      expect(measurement.p2Cad, secondPoint);
      expect(measurement.distance, closeTo(28.28427, 1e-4));
    });
  });

  group('DxfMeasurementCanvasPainter Screen-Space Rendering Tests', () {
    testWidgets('Paints distance measurement with perpendicular centered badge', (tester) async {
      final m = DxfMeasurement(
        tool: DxfMeasureTool.distance,
        p1Cad: const Offset(10, 10),
        p2Cad: const Offset(10, 50), // Vertical line
      );

      final painter = DxfMeasurementCanvasPainter(
        measurement: m,
        unit: DxfUnit.meters,
        cadToScreen: (pt) => Offset(pt.dx * 2.0, pt.dy * 2.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: painter,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Paints area polygon with centered centroid badge and vertex pins', (tester) async {
      final m = DxfMeasurement(
        tool: DxfMeasureTool.area,
        areaPoints: const [
          Offset(10, 10),
          Offset(60, 10),
          Offset(60, 40),
          Offset(10, 40),
        ],
        isAreaClosed: true,
      );

      final painter = DxfMeasurementCanvasPainter(
        measurement: m,
        unit: DxfUnit.meters,
        cadToScreen: (pt) => Offset(pt.dx * 2.0, pt.dy * 2.0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: painter,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Paints angle and radius measurements with centered badges without error', (tester) async {
      final mAngle = DxfMeasurement(
        tool: DxfMeasureTool.angle,
        angleVertex: const Offset(50, 50),
        angleP1: const Offset(100, 50),
        angleP2: const Offset(50, 100),
      );

      final mRadius = DxfMeasurement(
        tool: DxfMeasureTool.radius,
        circleCenter: const Offset(50, 50),
        radius: 25.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CustomPaint(
                  size: const Size(400, 400),
                  painter: DxfMeasurementCanvasPainter(
                    measurement: mAngle,
                    unit: DxfUnit.meters,
                    cadToScreen: (pt) => pt,
                  ),
                ),
                CustomPaint(
                  size: const Size(400, 400),
                  painter: DxfMeasurementCanvasPainter(
                    measurement: mRadius,
                    unit: DxfUnit.meters,
                    cadToScreen: (pt) => pt,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
