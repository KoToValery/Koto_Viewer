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

    test('9. Correctly prioritizes real walls over border/title block (антетка) lines', () {
      // Border layer has lines separated by 250mm
      final border1 = const DxfLine(p1: Offset(0, 0), p2: Offset(10000, 0), layer: 'АНТЕТКА');
      final border2 = const DxfLine(p1: Offset(0, 250), p2: Offset(10000, 250), layer: 'АНТЕТКА');

      // Wall layer has rooms with both horizontal and vertical walls (250mm)
      final wallH1 = const DxfLine(p1: Offset(1000, 1000), p2: Offset(8000, 1000), layer: 'СТЕНО');
      final wallH2 = const DxfLine(p1: Offset(1000, 1250), p2: Offset(8000, 1250), layer: 'СТЕНО');
      final wallV1 = const DxfLine(p1: Offset(1000, 1000), p2: Offset(1000, 6000), layer: 'СТЕНО');
      final wallV2 = const DxfLine(p1: Offset(1250, 1000), p2: Offset(1250, 6000), layer: 'СТЕНО');
      final wallV3 = const DxfLine(p1: Offset(8000, 1000), p2: Offset(8000, 6000), layer: 'СТЕНО');
      final wallV4 = const DxfLine(p1: Offset(7750, 1000), p2: Offset(7750, 6000), layer: 'СТЕНО');

      final doc = _createTestDoc(
        layers: {
          'АНТЕТКА': DxfLayer(name: 'АНТЕТКА', colorIndex: 7),
          'СТЕНО': DxfLayer(name: 'СТЕНО', colorIndex: 1),
        },
        entities: [border1, border2, wallH1, wallH2, wallV1, wallV2, wallV3, wallV4],
        bounds: const Rect.fromLTWH(0, 0, 10000, 6000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      // The winning group must be the real wall layer 'СТЕНО', not the title block 'АНТЕТКА'
      expect(result.bestGroup?.layerName, 'СТЕНО');
    });

    test('10. Extracts and detects walls defined inside block instances (DxfInsert)', () {
      final block = DxfBlock(
        name: 'WALLS_PLAN',
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(6000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(6000, 250), layer: 'WALLS'),
        ],
      );

      final insert = const DxfInsert(
        blockName: 'WALLS_PLAN',
        insertPoint: Offset(500, 500),
        layer: 'A-ARCH',
      );

      final doc = DxfDocument(
        layers: {'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7)},
        blocks: {'WALLS_PLAN': block},
        entities: [insert],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 8000, 4000),
        entityStats: const {},
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.bestGroup?.layerName, 'WALLS');
      expect(result.snappedCenterlines.length, 1);
      // Centerline should be at y = 500 + 125 = 625
      expect(result.snappedCenterlines.first.$1.dy, closeTo(625.0, 1.0));
    });

    test('11. convertToStructuralGridAxes merges collinear centerlines into continuous StructuralGridAxis and extends ends', () {
      final centerlines = <(Offset, Offset)>[
        // Collinear horizontal segments along y = 1000 with a 3m gap between them
        (const Offset(0, 1000), const Offset(2000, 1000)),
        (const Offset(5000, 1000), const Offset(7000, 1000)),
        // A second parallel horizontal alignment along y = 4000
        (const Offset(0, 4000), const Offset(7000, 4000)),
        // A vertical alignment along x = 0
        (const Offset(0, 1000), const Offset(0, 4000)),
      ];

      final axes = WallAxisDetector.convertToStructuralGridAxes(
        centerlines,
        isBulgarian: true,
        scale: 1.0, // mm scale
        extensionM: 1.20, // 1.2m = 1200mm
      );

      // Should merge the two collinear segments along y = 1000 into 1 axis,
      // resulting in total 2 horizontal axes and 1 vertical axis = 3 axes
      expect(axes.length, 3);

      final horizontal = axes.where((a) => a.direction.dx.abs() > a.direction.dy.abs()).toList();
      final vertical = axes.where((a) => a.direction.dy.abs() > a.direction.dx.abs()).toList();

      expect(horizontal.length, 2);
      expect(vertical.length, 1);

      // Names should be sequenced (vertical numbers "1", horizontal letters "А", "Б")
      expect(vertical.first.name, '1');
      expect(horizontal.first.name, 'А');
      expect(horizontal.last.name, 'Б');

      // The merged axis along y=1000 should extend from 0 - 1200 = -1200 to 7000 + 1200 = 8200
      final mergedAxis = horizontal.firstWhere((a) => (a.start.dy - 1000).abs() < 50);
      expect(mergedAxis.start.dx, closeTo(-1200.0, 1.0));
      expect(mergedAxis.end.dx, closeTo(8200.0, 1.0));
      expect(mergedAxis.bubbleAtStart, isTrue);
      expect(mergedAxis.bubbleAtEnd, isTrue);
    });

    test('12. DxfDocument infers layer defaultEntityLineweight from entity lineweights when layer lineweight is null', () {
      final layerWalls = DxfLayer(name: 'WALLS', colorIndex: 7);
      final layerDims = DxfLayer(name: 'DIMS', colorIndex: 7);

      final entities = <DxfEntity>[
        // Entities on WALLS with explicit lineweight 0.30 mm
        DxfLine(p1: Offset.zero, p2: const Offset(100, 0), layer: 'WALLS', lineWeight: 0.30),
        DxfLine(p1: const Offset(100, 0), p2: const Offset(200, 0), layer: 'WALLS', lineWeight: 0.30),
        // Entities on DIMS with explicit lineweight 0.13 mm
        DxfLine(p1: Offset.zero, p2: const Offset(0, 100), layer: 'DIMS', lineWeight: 0.13),
      ];

      final doc = DxfDocument(
        layers: {'WALLS': layerWalls, 'DIMS': layerDims},
        blocks: const {},
        entities: entities,
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 200, 100),
        entityStats: const {},
      );

      expect(doc.layers['WALLS']?.effectiveLineweight, closeTo(0.30, 1e-4));
      expect(doc.layers['DIMS']?.effectiveLineweight, closeTo(0.13, 1e-4));
    });

    test('13. WallAxisDetector detects 20 cm concrete and 30 cm plastered walls with wide tolerance', () {
      // 200 mm concrete shear wall
      final lineConcreteA = const DxfLine(p1: Offset(0, 0), p2: Offset(4000, 0), layer: 'WALL_CONCRETE', colorIndex: 3);
      final lineConcreteB = const DxfLine(p1: Offset(0, 200), p2: Offset(4000, 200), layer: 'WALL_CONCRETE', colorIndex: 3);

      // 300 mm plastered wall
      final linePlasterA = const DxfLine(p1: Offset(0, 2000), p2: Offset(4000, 2000), layer: 'WALL_PLASTER', colorIndex: 5);
      final linePlasterB = const DxfLine(p1: Offset(0, 2300), p2: Offset(4000, 2300), layer: 'WALL_PLASTER', colorIndex: 5);

      final doc = DxfDocument(
        layers: {
          'WALL_CONCRETE': DxfLayer(name: 'WALL_CONCRETE', colorIndex: 3),
          'WALL_PLASTER': DxfLayer(name: 'WALL_PLASTER', colorIndex: 5),
        },
        blocks: const {},
        entities: [lineConcreteA, lineConcreteB, linePlasterA, linePlasterB],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 4000, 2500),
        entityStats: const {},
      );

      final result = WallAxisDetector.detect(
        doc,
        targetThicknessMm: 250.0,
        thicknessToleranceMm: 55.0, // 195 to 305 mm
      );

      expect(result.hasWallsFound, isTrue);
      // Both the 200mm and 300mm pairs should be detected
      final totalPairs = result.evaluatedGroups.fold<int>(0, (sum, g) => sum + g.pairCount);
      expect(totalPairs, 2);
    });
  });
}
