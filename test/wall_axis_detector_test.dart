import 'dart:math' as math;
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

    test('7. applyToDocument isolates WALLS_250 layer and keeps CAD underlay clean for interactive StructuralGridAxis', () {
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

      // Verify original clutter layers are hidden
      expect(doc.layers['0']?.isVisible, isFalse);
      expect(doc.layers['FURNITURE']?.isVisible, isFalse);

      // Verify WALLS_250 exists and is visible with heavy lineweight
      expect(doc.layers.containsKey('WALLS_250'), isTrue);
      expect(doc.layers['WALLS_250']?.isVisible, isTrue);
      expect(doc.layers['WALLS_250']?.customLineweight, 0.70);

      // Verify wall entities were added to WALLS_250
      final wallEntities = doc.entities.where((e) => e.layer == 'WALLS_250').toList();
      expect(wallEntities.isNotEmpty, isTrue);

      // Verify CAD underlay does NOT contain static axis entities (no fake CAD lines)
      final axisEntities = doc.entities.where((e) => e.layer == 'AXIS').toList();
      expect(axisEntities.isEmpty, isTrue);

      // Instead, dynamic interactive StructuralGridAxis elements are generated for the BIM module
      final dynamicAxes = WallAxisDetector.convertToStructuralGridAxes(
        result.snappedCenterlines,
        isBulgarian: true,
        scale: result.detectedScale,
      );
      expect(dynamicAxes.isNotEmpty, isTrue);
      expect(dynamicAxes.first.bubbleAtStart, isTrue);
      expect(dynamicAxes.first.bubbleAtEnd, isTrue);
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

    test('14. Multi-line window clusters (dense parallel lines: frame, sash, glass, sill) are rejected by intermediate line filtering and do not outrank real walls', () {
      final wallLayer = DxfLayer(name: 'стени', colorIndex: 7);

      // Real 250mm solid wall: two faces at y=0 and y=250, length 5000mm, color 7
      final wallA = const DxfLine(
        p1: Offset(0, 0),
        p2: Offset(5000, 0),
        layer: 'стени',
        colorIndex: 7,
      );
      final wallB = const DxfLine(
        p1: Offset(0, 250),
        p2: Offset(5000, 250),
        layer: 'стени',
        colorIndex: 7,
      );

      // Perpendicular wall corner to provide building layout
      final wallVertA = const DxfLine(
        p1: Offset(0, 0),
        p2: Offset(0, 4000),
        layer: 'стени',
        colorIndex: 7,
      );
      final wallVertB = const DxfLine(
        p1: Offset(250, 250),
        p2: Offset(250, 4000),
        layer: 'стени',
        colorIndex: 7,
      );

      // Window opening cluster in color 30: 6 parallel lines close to each other
      // y = 1000, 1050, 1100, 1150, 1200, 1250 (outer sill to inner frame = 250mm apart, but has 4 intermediate lines!)
      final windowLines = <DxfLine>[];
      for (double y = 1000; y <= 1250; y += 50) {
        windowLines.add(
          DxfLine(
            p1: Offset(1000, y),
            p2: Offset(3000, y),
            layer: 'стени',
            colorIndex: 30,
          ),
        );
      }

      final doc = _createTestDoc(
        layers: {'стени': wallLayer},
        entities: [wallA, wallB, wallVertA, wallVertB, ...windowLines],
        bounds: const Rect.fromLTWH(0, 0, 5000, 4000),
      );

      final result = WallAxisDetector.detect(doc);

      expect(result.hasWallsFound, isTrue);
      // Real walls (color 7) must win over window lines (color 30)
      expect(result.bestGroup?.colorIndex, 7);
      expect(result.bestGroup?.layerName, 'стени');

      // The window cluster in color 30 should have 0 pairs because all pairs spanning 200-250mm
      // contain intermediate parallel lines between them.
      final windowGroup = result.evaluatedGroups.where((g) => g.colorIndex == 30).firstOrNull;
      expect(windowGroup, isNull);

      // Verified: 0 window contour lines in detected wall contours
      for (final seg in result.wallContourSegments) {
        expect(seg.$1.dy != 1000 && seg.$1.dy != 1250, isTrue);
      }
    });

    test('15. convertToStructuralGridAxes ensures interior short walls extend across the full building envelope with aligned external bubbles', () {
      final centerlines = <(Offset, Offset)>[
        // Outer horizontal walls: from X = 0 to 10000, along Y = 0 and Y = 8000
        (const Offset(0, 0), const Offset(10000, 0)),
        (const Offset(0, 8000), const Offset(10000, 8000)),
        // Outer vertical walls: from Y = 0 to 8000, along X = 0 and X = 10000
        (const Offset(0, 0), const Offset(0, 8000)),
        (const Offset(10000, 0), const Offset(10000, 8000)),
        // Short interior wall: along Y = 3500, only 3m long from X = 3000 to X = 6000
        (const Offset(3000, 3500), const Offset(6000, 3500)),
      ];

      final axes = WallAxisDetector.convertToStructuralGridAxes(
        centerlines,
        isBulgarian: true,
        scale: 1.0, // mm
        extensionM: 1.50, // 1.5m = 1500mm
      );

      // Total 3 horizontal axes (Y=0, Y=3500, Y=8000) and 2 vertical axes (X=0, X=10000)
      expect(axes.length, 5);

      final horizontalAxes = axes.where((a) => a.direction.dx.abs() > a.direction.dy.abs()).toList();
      expect(horizontalAxes.length, 3);

      // The interior axis along Y=3500 must span the FULL building width (0 - 1500 to 10000 + 1500 = -1500 to 11500),
      // exactly matching the outer horizontal axes, instead of terminating inside rooms at 1500 and 7500.
      final interiorAxis = horizontalAxes.firstWhere((a) => (a.start.dy - 3500).abs() < 50);
      expect(interiorAxis.start.dx, closeTo(-1500.0, 1.0));
      expect(interiorAxis.end.dx, closeTo(11500.0, 1.0));

      for (final hAxis in horizontalAxes) {
        expect(hAxis.start.dx, closeTo(-1500.0, 1.0), reason: 'All horizontal start bubbles must be aligned outside the building on the left');
        expect(hAxis.end.dx, closeTo(11500.0, 1.0), reason: 'All horizontal end bubbles must be aligned outside the building on the right');
        expect(hAxis.bubbleAtStart, isTrue);
        expect(hAxis.bubbleAtEnd, isTrue);
      }

      final verticalAxes = axes.where((a) => a.direction.dy.abs() > a.direction.dx.abs()).toList();
      expect(verticalAxes.length, 2);

      for (final vAxis in verticalAxes) {
        expect(vAxis.start.dy, closeTo(-1500.0, 1.0), reason: 'All vertical bottom bubbles must be aligned outside the building at the bottom');
        expect(vAxis.end.dy, closeTo(9500.0, 1.0), reason: 'All vertical top bubbles must be aligned outside the building at the top');
        expect(vAxis.bubbleAtStart, isTrue);
        expect(vAxis.bubbleAtEnd, isTrue);
      }
    });

    test('16. Generated StructuralGridAxis elements are fully interactive and can calculate geometric intersections', () {
      final centerlines = <(Offset, Offset)>[
        (const Offset(0, 0), const Offset(6000, 0)),
        (const Offset(2000, 0), const Offset(2000, 4000)),
      ];

      final axes = WallAxisDetector.convertToStructuralGridAxes(
        centerlines,
        isBulgarian: true,
        scale: 1.0,
        extensionM: 1.0,
      );

      expect(axes.length, 2);
      final axisH = axes.firstWhere((a) => a.direction.dx.abs() > a.direction.dy.abs());
      final axisV = axes.firstWhere((a) => a.direction.dy.abs() > a.direction.dx.abs());

      // Should find intersection at (2000, 0) for column/shear wall placement
      final intersection = axisH.intersectionWith(axisV);
      expect(intersection, isNotNull);
      expect(intersection!.dx, closeTo(2000.0, 1.0));
      expect(intersection.dy, closeTo(0.0, 1.0));
    });

    test('17. WallAxisDetector automatically caps open wall ends at door and window openings with transverse closure segments', () {
      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 7);
      final doc = _createTestDoc(
        layers: {'WALLS': wallLayer},
        entities: const [
          // Horizontal pier 1: from X = 0 to X = 2000 (meets vertical wall at corner X = 0)
          DxfLine(p1: Offset(0, 0), p2: Offset(2000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 250), p2: Offset(2000, 250), layer: 'WALLS'),

          // Horizontal pier 2: from X = 3200 to X = 5000 (window opening between 2000 and 3200)
          DxfLine(p1: Offset(3200, 0), p2: Offset(5000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(3200, 250), p2: Offset(5000, 250), layer: 'WALLS'),

          // Vertical wall meeting horizontal pier 1 at L-corner at X = 0, Y = 0
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 3000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 250), p2: Offset(250, 3000), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 5000, 3000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);

      final contours = result.wallContourSegments;
      expect(contours.isNotEmpty, isTrue);

      // Helper to check if a transverse vertical cap segment exists near a given X coordinate
      bool hasVerticalCapNear(double targetX) {
        return contours.any((seg) {
          final x1 = seg.$1.dx;
          final x2 = seg.$2.dx;
          final y1 = seg.$1.dy;
          final y2 = seg.$2.dy;
          // Must be roughly vertical (x1 ~= x2) at targetX and span roughly y = [0, 250]
          return (x1 - targetX).abs() <= 20.0 &&
              (x2 - targetX).abs() <= 20.0 &&
              (math.min(y1, y2) - 0.0).abs() <= 20.0 &&
              (math.max(y1, y2) - 250.0).abs() <= 20.0;
        });
      }

      // 1. Window jamb at X = 2000 MUST be closed with a cap
      expect(hasVerticalCapNear(2000.0), isTrue, reason: 'Window opening start at X=2000 must be closed with an end cap');

      // 2. Window jamb at X = 3200 MUST be closed with a cap
      expect(hasVerticalCapNear(3200.0), isTrue, reason: 'Window opening end at X=3200 must be closed with an end cap');

      // 3. Free wall end at X = 5000 MUST be closed with a cap
      expect(hasVerticalCapNear(5000.0), isTrue, reason: 'Free wall end at X=5000 must be closed with an end cap');

      // 4. L-corner at X = 0 must NOT have a transverse cap cutting across the corner
      expect(hasVerticalCapNear(0.0), isFalse, reason: 'L-corner must remain open to connect cleanly with intersecting wall');

      // 5. In WALLS_250 layer, applyToDocument creates these closure segments
      WallAxisDetector.applyToDocument(doc, result);
      final wall250Entities = doc.entities.where((e) => e.layer == 'WALLS_250').toList();
      final hasCapInDoc = wall250Entities.any((e) {
        if (e is! DxfLine) return false;
        return (e.p1.dx - 2000.0).abs() <= 20.0 && (e.p2.dx - 2000.0).abs() <= 20.0;
      });
      expect(hasCapInDoc, isTrue, reason: 'WALLS_250 layer in DXF document must contain the jamb cap line');
    });

    test('18. Dynamic BIM Grid Axis generation: CAD underlay has no static axes, axes are generated as live StructuralGridAxis elements', () {
      final doc = _createTestDoc(
        layers: {
          'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7, isVisible: true),
        },
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(6000, 0), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 250), p2: Offset(6000, 250), layer: 'WALLS'),
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 5000), layer: 'WALLS'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 5000), layer: 'WALLS'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 6000, 5000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);

      // Clean walls in CAD underlay
      WallAxisDetector.applyToDocument(doc, result);

      // Verify CAD underlay does NOT have fake static CAD axis lines
      final underlayAxisEnts = doc.entities.where((e) => e.layer == 'AXIS').toList();
      expect(underlayAxisEnts.isEmpty, isTrue, reason: 'Underlay must not have static CAD axes');

      // Generate dynamic BIM elements
      final dynamicAxes = WallAxisDetector.convertToStructuralGridAxes(
        result.snappedCenterlines,
        isBulgarian: true,
        scale: result.detectedScale,
      );
      expect(dynamicAxes.length, 2);

      final hAxis = dynamicAxes.firstWhere((a) => (a.start.dy - a.end.dy).abs() < 1.0);
      final vAxis = dynamicAxes.firstWhere((a) => (a.start.dx - a.end.dx).abs() < 1.0);

      // Verify dynamic BIM element characteristics (interactive bubbles, geometric checks)
      expect(hAxis.bubbleAtStart, isTrue);
      expect(hAxis.bubbleAtEnd, isTrue);
      expect(vAxis.bubbleAtStart, isTrue);
      expect(vAxis.bubbleAtEnd, isTrue);

      // Verify intersection calculation (live BIM element capability)
      final intersection = hAxis.intersectionWith(vAxis);
      expect(intersection, isNotNull);
      expect(intersection!.dx, closeTo(125.0, 1.0));
      expect(intersection.dy, closeTo(125.0, 1.0));

      // Verify distance hit testing (for live user selection)
      expect(hAxis.distanceToSegment(const Offset(3000, 125)), closeTo(0.0, 1.0));
      expect(hAxis.distanceToSegment(const Offset(3000, 1000)), closeTo(875.0, 1.0));
    });

    test('19. Closure lines are recorded into the original wall layer so walls are closed in the architectural underlay', () {
      final doc = _createTestDoc(
        layers: {
          'стени': DxfLayer(name: 'стени', colorIndex: 7, isVisible: true),
        },
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(4000, 0), layer: 'стени'),
          DxfLine(p1: Offset(0, 250), p2: Offset(4000, 250), layer: 'стени'),
        ],
        bounds: const Rect.fromLTWH(0, 0, 4000, 250),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.closureSegments.isNotEmpty, isTrue);

      WallAxisDetector.applyToDocument(doc, result);

      // Verify transverse closing caps were injected directly into layer 'стени'
      final steniClosingLines = doc.entities
          .where((e) => e.layer == 'стени' && e is DxfLine)
          .cast<DxfLine>()
          .where((l) => (l.p1.dx - l.p2.dx).abs() < 1.0 && (l.p1.dy - l.p2.dy).abs() >= 200.0)
          .toList();

      expect(
        steniClosingLines.isNotEmpty,
        isTrue,
        reason: 'Original wall layer "стени" must receive transverse end cap lines',
      );
      expect(steniClosingLines.first.colorIndex, 7);
    });

    test('20. Angled walls (e.g. 45 degrees) are detected at their authentic angle and generate angled StructuralGridAxis', () {
      final sqrt2 = math.sqrt(2.0);
      final normalOffset = 250.0 / sqrt2; // 250mm wall thickness along normal (-1/sqrt2, 1/sqrt2)

      // 45 degree wall with 250mm thickness and length ~4.24m (3000 x 3000)
      final wallLayer = DxfLayer(name: 'WALL_ANGLED', colorIndex: 7, isVisible: true);
      final line1 = const DxfLine(
        p1: Offset(0, 0),
        p2: Offset(3000, 3000),
        layer: 'WALL_ANGLED',
      );
      final line2 = DxfLine(
        p1: Offset(-normalOffset, normalOffset),
        p2: Offset(3000 - normalOffset, 3000 + normalOffset),
        layer: 'WALL_ANGLED',
      );

      final doc = _createTestDoc(
        layers: {'WALL_ANGLED': wallLayer},
        entities: [line1, line2],
        bounds: Rect.fromLTRB(-normalOffset, 0, 3000, 3000 + normalOffset),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.snappedCenterlines.length, 1);

      final centerline = result.snappedCenterlines.first;
      final angle = math.atan2(centerline.$2.dy - centerline.$1.dy, centerline.$2.dx - centerline.$1.dx);
      // Angle should be exactly 45 degrees (pi / 4)
      expect(angle, closeTo(math.pi / 4.0, 0.05));

      final axes = WallAxisDetector.convertToStructuralGridAxes(
        result.snappedCenterlines,
        isBulgarian: true,
        scale: result.detectedScale,
      );
      expect(axes.length, 1);

      final axis = axes.first;
      final axisAngle = axis.angleRad;
      // Axis preserves authentic 45 degree angle without snapping to orthogonal
      expect(axisAngle, closeTo(math.pi / 4.0, 0.05));
      expect(axis.bubbleAtStart, isTrue);
      expect(axis.bubbleAtEnd, isTrue);
    });

    test('21. Architect using 0.35mm or 0.40mm lineweight: structural walls & columns are detected, thin lines are excluded', () {
      final doc = _createTestDoc(
        layers: {
          '01_BRICK_35': DxfLayer(name: '01_BRICK_35', colorIndex: 1, customLineweight: 0.35, isVisible: true),
          '02_PARTITION_25': DxfLayer(name: '02_PARTITION_25', colorIndex: 2, customLineweight: 0.25, isVisible: true),
          '03_INSUL_15': DxfLayer(name: '03_INSUL_15', colorIndex: 3, customLineweight: 0.15, isVisible: true),
          '04_FURN_13': DxfLayer(name: '04_FURN_13', colorIndex: 4, customLineweight: 0.13, isVisible: true),
        },
        entities: const [
          // 250mm structural masonry (0.35mm lineweight)
          DxfLine(p1: Offset(0, 0), p2: Offset(5000, 0), layer: '01_BRICK_35'),
          DxfLine(p1: Offset(0, 250), p2: Offset(5000, 250), layer: '01_BRICK_35'),
          DxfLine(p1: Offset(0, 0), p2: Offset(0, 4000), layer: '01_BRICK_35'),
          DxfLine(p1: Offset(250, 0), p2: Offset(250, 4000), layer: '01_BRICK_35'),

          // 120mm interior partition wall (0.25mm lineweight)
          DxfLine(p1: Offset(2000, 250), p2: Offset(2000, 3000), layer: '02_PARTITION_25'),
          DxfLine(p1: Offset(2120, 250), p2: Offset(2120, 3000), layer: '02_PARTITION_25'),

          // Insulation lines (0.15mm lineweight) - should be excluded
          DxfLine(p1: Offset(-100, 0), p2: Offset(-100, 4000), layer: '03_INSUL_15'),
          DxfLine(p1: Offset(-200, 0), p2: Offset(-200, 4000), layer: '03_INSUL_15'),

          // Furniture lines (0.13mm lineweight) - should be excluded
          DxfLine(p1: Offset(500, 500), p2: Offset(1500, 500), layer: '04_FURN_13'),
          DxfLine(p1: Offset(500, 750), p2: Offset(1500, 750), layer: '04_FURN_13'),
        ],
        bounds: const Rect.fromLTWH(-200, 0, 5200, 4000),
      );

      final result = WallAxisDetector.detect(doc);
      expect(result.hasWallsFound, isTrue);
      expect(result.bestGroup?.layerName, '01_BRICK_35');

      // Thin layers must NOT be active wall groups
      final activeLayerNames = result.selectedWallPairs.map((p) => p.segmentA.sourceLayer).toSet();
      expect(activeLayerNames.contains('01_BRICK_35'), isTrue);
      expect(activeLayerNames.contains('03_INSUL_15'), isFalse);
      expect(activeLayerNames.contains('04_FURN_13'), isFalse);
    });
  });
}
