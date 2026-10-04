import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';

DxfDocument _createTestDoc({
  required Map<String, DxfLayer> layers,
  required List<DxfEntity> entities,
  Rect bounds = const Rect.fromLTWH(0, 0, 1000, 1000),
}) {
  return DxfDocument(
    layers: Map<String, DxfLayer>.from(layers),
    blocks: const {},
    entities: List<DxfEntity>.from(entities),
    headerVars: const {},
    bounds: bounds,
    entityStats: const {},
  );
}

void main() {
  group('WallAxisDetector Tests', () {
    test('1. Simple 250mm parallel wall lines in mm scale generates centerline axis at 125mm', () {
      final wallLayer = DxfLayer(name: 'A-WALL', colorIndex: 1); // Red
      final line1 = const DxfLine(
        p1: Offset(0, 0),
        p2: Offset(6000, 0),
        layer: 'A-WALL',
      );
      final line2 = const DxfLine(
        p1: Offset(0, 250),
        p2: Offset(6000, 250),
        layer: 'A-WALL',
      );

      final doc = _createTestDoc(
        layers: {'A-WALL': wallLayer},
        entities: [line1, line2],
        bounds: const Rect.fromLTWH(0, 0, 6000, 250),
      );

      final result = WallAxisDetector.detect(doc);

      expect(result.hasWallsFound, isTrue);
      expect(result.detectedUnitName, 'mm');
      expect(result.bestGroup?.layerName, 'A-WALL');
      expect(result.bestGroup?.pairCount, 1);
      expect(result.snappedCenterlines.length, 1);

      final axis = result.snappedCenterlines.first;
      // Centerline should be at y=125
      expect(axis.$1.dy, closeTo(125.0, 1.0));
      expect(axis.$2.dy, closeTo(125.0, 1.0));
      expect(axis.$1.dx, closeTo(0.0, 1.0));
      expect(axis.$2.dx, closeTo(6000.0, 1.0));
    });

    test('2. Scale auto-detection handles centimeters (25 units) and meters (0.25 units)', () {
      // Centimeters test: 25 units apart
      final cmDoc = _createTestDoc(
        layers: {'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7)},
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(500, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 25), p2: Offset(500, 25), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 500, 25),
      );

      final cmResult = WallAxisDetector.detect(cmDoc);
      expect(cmResult.hasWallsFound, isTrue);
      expect(cmResult.detectedUnitName, 'cm');
      expect(cmResult.snappedCenterlines.first.$1.dy, closeTo(12.5, 0.5));

      // Meters test: 0.25 units apart
      final mDoc = _createTestDoc(
        layers: {'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7)},
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(10, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 0.25), p2: Offset(10, 0.25), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 10, 0.25),
      );

      final mResult = WallAxisDetector.detect(mDoc);
      expect(mResult.hasWallsFound, isTrue);
      expect(mResult.detectedUnitName, 'm');
      expect(mResult.snappedCenterlines.first.$1.dy, closeTo(0.125, 0.005));
    });

    test('3. Separates masonry from insulation and hatches in same or different layers by (Layer, Color)', () {
      final layer0 = DxfLayer(name: '0', colorIndex: 7);

      final brickLine1 = const DxfLine(
        p1: Offset(0, 100),
        p2: Offset(8000, 100),
        layer: '0',
        colorIndex: 1, // Red
      );
      final brickLine2 = const DxfLine(
        p1: Offset(0, 350),
        p2: Offset(8000, 350),
        layer: '0',
        colorIndex: 1, // Red (250mm distance from brickLine1)
      );

      final insulationLine = const DxfLine(
        p1: Offset(0, 0),
        p2: Offset(8000, 0),
        layer: '0',
        colorIndex: 4, // Cyan (100mm from brickLine1)
      );

      final hatch1 = const DxfLine(
        p1: Offset(0, 10),
        p2: Offset(8000, 10),
        layer: '0',
        colorIndex: 3, // Green
      );
      final hatch2 = const DxfLine(
        p1: Offset(0, 60),
        p2: Offset(8000, 60),
        layer: '0',
        colorIndex: 3, // Green (50mm spacing)
      );

      final doc = _createTestDoc(
        layers: {'0': layer0},
        entities: [brickLine1, brickLine2, insulationLine, hatch1, hatch2],
        bounds: const Rect.fromLTWH(0, 0, 8000, 400),
      );

      final result = WallAxisDetector.detect(doc);

      expect(result.hasWallsFound, isTrue);
      // Winning group must be Layer '0' with color 1 (Red masonry)
      expect(result.bestGroup?.layerName, '0');
      expect(result.bestGroup?.colorIndex, 1);
      expect(result.bestGroup?.pairCount, 1);
      // Axis is at midpoint of 100 and 350 -> y = 225
      expect(result.snappedCenterlines.first.$1.dy, closeTo(225.0, 1.0));
    });

    test('4. Bridges collinear door and window gaps up to 2.50m into a continuous axis', () {
      final seg1A = const DxfLine(p1: Offset(0, 0), p2: Offset(2000, 0), layer: 'WALL');
      final seg1B = const DxfLine(p1: Offset(0, 250), p2: Offset(2000, 250), layer: 'WALL');

      final seg2A = const DxfLine(p1: Offset(3000, 0), p2: Offset(6000, 0), layer: 'WALL');
      final seg2B = const DxfLine(p1: Offset(3000, 250), p2: Offset(6000, 250), layer: 'WALL');

      final doc = _createTestDoc(
        layers: {'WALL': DxfLayer(name: 'WALL', colorIndex: 7)},
        entities: [seg1A, seg1B, seg2A, seg2B],
        bounds: const Rect.fromLTWH(0, 0, 6000, 250),
      );

      final result = WallAxisDetector.detect(doc);

      // Raw centerlines were 2 separate segments
      expect(result.rawCenterlines.length, 2);
      // Bridged centerlines should merge across the 1000mm door into 1 continuous segment
      expect(result.bridgedCenterlines.length, 1);
      expect(result.snappedCenterlines.length, 1);

      final mergedAxis = result.snappedCenterlines.first;
      expect(mergedAxis.$1.dx, closeTo(0.0, 1.0));
      expect(mergedAxis.$2.dx, closeTo(6000.0, 1.0));
      expect(mergedAxis.$1.dy, closeTo(125.0, 1.0));
    });

    test('5. Topological snapping: L-corner extension and T-junction intersection', () {
      final h1 = const DxfLine(p1: Offset(250, 0), p2: Offset(4000, 0), layer: 'WALL');
      final h2 = const DxfLine(p1: Offset(250, 250), p2: Offset(4000, 250), layer: 'WALL');

      final v1 = const DxfLine(p1: Offset(0, 250), p2: Offset(0, 4000), layer: 'WALL');
      final v2 = const DxfLine(p1: Offset(250, 250), p2: Offset(250, 4000), layer: 'WALL');

      final doc = _createTestDoc(
        layers: {'WALL': DxfLayer(name: 'WALL', colorIndex: 7)},
        entities: [h1, h2, v1, v2],
        bounds: const Rect.fromLTWH(0, 0, 4000, 4000),
      );

      final result = WallAxisDetector.detect(doc);

      expect(result.snappedCenterlines.length, 2);
      final axisH = result.snappedCenterlines.firstWhere((a) => (a.$1.dy - a.$2.dy).abs() < 1.0);
      final axisV = result.snappedCenterlines.firstWhere((a) => (a.$1.dx - a.$2.dx).abs() < 1.0);

      // Both should meet at (125, 125)
      expect(axisH.$1.dx, closeTo(125.0, 2.0));
      expect(axisH.$1.dy, closeTo(125.0, 2.0));
      expect(axisV.$1.dx, closeTo(125.0, 2.0));
      expect(axisV.$1.dy, closeTo(125.0, 2.0));
    });

    test('6. Preserves short walls (50 cm offset for staircase niche)', () {
      final line1 = const DxfLine(p1: Offset(0, 0), p2: Offset(500, 0), layer: 'WALL');
      final line2 = const DxfLine(p1: Offset(0, 250), p2: Offset(500, 250), layer: 'WALL');

      final doc = _createTestDoc(
        layers: {'WALL': DxfLayer(name: 'WALL', colorIndex: 7)},
        entities: [line1, line2],
        bounds: const Rect.fromLTWH(0, 0, 500, 250),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.snappedCenterlines.length, 1);
      expect((result.snappedCenterlines.first.$2.dx - result.snappedCenterlines.first.$1.dx).abs(), closeTo(500.0, 1.0));
    });

    test('7. applyToDocument injects WALLS_250 and AXIS layers and hides original layers', () {
      final doc = _createTestDoc(
        layers: {
          '0': DxfLayer(name: '0', colorIndex: 7, isVisible: true),
          'FURNITURE': DxfLayer(name: 'FURNITURE', colorIndex: 3, isVisible: true),
        },
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(5000, 0), layer: '0'),
          DxfLine(p1: Offset(0, 250), p2: Offset(5000, 250), layer: '0'),
          DxfLine(p1: Offset(1000, 1000), p2: Offset(2000, 1000), layer: 'FURNITURE'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 5000, 1000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);

      WallAxisDetector.applyToDocument(doc, result);

      // Verify original layers are hidden
      expect(doc.layers['0']?.isVisible, isFalse);
      expect(doc.layers['FURNITURE']?.isVisible, isFalse);

      // Verify WALLS_250 and AXIS layers exist and are visible
      expect(doc.layers.containsKey('WALLS_250'), isTrue);
      expect(doc.layers['WALLS_250']?.isVisible, isTrue);
      expect(doc.layers.containsKey('AXIS'), isTrue);
      expect(doc.layers['AXIS']?.isVisible, isTrue);
      expect(doc.layers['AXIS']?.colorIndex, 1); // Red
      expect(doc.layers['AXIS']?.lineType, 'DASHED');

      // Verify entities in AXIS and WALLS_250 were added
      final axisEntities = doc.entities.where((e) => e.layer == 'AXIS').toList();
      final wallEntities = doc.entities.where((e) => e.layer == 'WALLS_250').toList();
      expect(axisEntities.isNotEmpty, isTrue);
      expect(wallEntities.isNotEmpty, isTrue);
      expect(axisEntities.first.lineType, 'DASHED');
    });

    test('8. Handles LWPOLYLINE and closed rectangular rooms', () {
      final outerPoly = DxfLwPolyline(
        vertices: const [
          DxfPolylineVertex(x: 0, y: 0),
          DxfPolylineVertex(x: 5000, y: 0),
          DxfPolylineVertex(x: 5000, y: 4000),
          DxfPolylineVertex(x: 0, y: 4000),
        ],
        isClosed: true,
        layer: 'WALLS',
      );
      final innerPoly = DxfLwPolyline(
        vertices: const [
          DxfPolylineVertex(x: 250, y: 250),
          DxfPolylineVertex(x: 4750, y: 250),
          DxfPolylineVertex(x: 4750, y: 3750),
          DxfPolylineVertex(x: 250, y: 3750),
        ],
        isClosed: true,
        layer: 'WALLS',
      );

      final doc = _createTestDoc(
        layers: {'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7)},
        entities: [outerPoly, innerPoly],
        bounds: const Rect.fromLTWH(0, 0, 5000, 4000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.bestGroup?.pairCount, greaterThanOrEqualTo(4));
      expect(result.snappedCenterlines.length, greaterThanOrEqualTo(4));
    });
  });
}
