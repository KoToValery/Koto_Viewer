import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_quadtree.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';

void main() {
  group('DxfQuadTree Spatial Index Tests', () {
    test('Correctly indexes and queries 10,000 synthetic CAD entities', () {
      final List<DxfEntity> entities = [];

      // Generate a 100x100 grid of lines across a 10,000 x 10,000 mm workspace
      for (int i = 0; i < 100; i++) {
        for (int j = 0; j < 100; j++) {
          final x = i * 100.0;
          final y = j * 100.0;
          entities.add(DxfLine(
            p1: Offset(x, y),
            p2: Offset(x + 50.0, y + 50.0),
          ));
        }
      }

      final tree = DxfQuadTree.build(
        entities,
        const {},
        const Rect.fromLTWH(0, 0, 10000, 10000),
      );

      expect(tree.bounds.width, greaterThanOrEqualTo(10000));

      // Query small 250x250 window around (500, 500)
      final stopwatch = Stopwatch()..start();
      final results = tree.query(const Rect.fromLTWH(500, 500, 250, 250));
      stopwatch.stop();

      // Query should be lightning fast (< 10ms in debug)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));

      // Verify that results only contain entities intersecting the window
      expect(results.isNotEmpty, isTrue);
      expect(results.length, lessThan(50)); // Out of 10,000, only ~12-25 should match!

      for (final e in results) {
        final box = e.getBoundingBox(const {});
        expect(box, isNotNull);
        expect(box!.overlaps(const Rect.fromLTWH(500, 500, 250, 250)), isTrue);
      }
    });

    test('Excludes entities outside the query window', () {
      final line1 = DxfLine(p1: const Offset(10, 10), p2: const Offset(20, 20));
      final line2 = DxfLine(p1: const Offset(5000, 5000), p2: const Offset(5050, 5050));
      final circle = DxfCircle(center: const Offset(15, 15), radius: 5);

      final tree = DxfQuadTree.build(
        [line1, line2, circle],
        const {},
        const Rect.fromLTWH(0, 0, 6000, 6000),
      );

      final queryResult = tree.query(const Rect.fromLTWH(0, 0, 50, 50));
      expect(queryResult.contains(line1), isTrue);
      expect(queryResult.contains(circle), isTrue);
      expect(queryResult.contains(line2), isFalse);
    });

    test('DxfParser automatically builds spatialIndex upon parsing', () {
      const dxfContent = '''0
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
11
100.0
21
100.0
0
CIRCLE
8
0
10
50.0
20
50.0
40
25.0
0
ENDSEC
0
EOF
''';

      final doc = DxfParser.parseString(dxfContent);
      expect(doc.spatialIndex, isNotNull);

      final hits = doc.spatialIndex!.query(const Rect.fromLTWH(40, 40, 20, 20));
      expect(hits.length, greaterThanOrEqualTo(1));
    });

    test('DxfSnapHelper leverages spatialIndex for instant snapping', () {
      final line1 = DxfLine(p1: const Offset(0, 0), p2: const Offset(100, 0));
      final circle1 = DxfCircle(center: const Offset(50, 50), radius: 20);

      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0', colorIndex: 7)},
        blocks: {},
        entities: [line1, circle1],
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );

      // Build spatial index
      doc.orBuildSpatialIndex;
      expect(doc.spatialIndex, isNotNull);

      // Snap near endpoint (0, 0)
      final snap = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(1.0, 1.0),
        toleranceCad: 5.0,
      );

      expect(snap, isNotNull);
      expect(snap!.point, const Offset(0, 0));
      expect(snap.type, DxfSnapType.endpoint);

      // Find closest circle/arc
      final circleMatch = DxfSnapHelper.findClosestCircleOrArc(
        document: doc,
        cadPoint: const Offset(50, 69.5),
        toleranceCad: 5.0,
      );

      expect(circleMatch, isNotNull);
      expect(circleMatch!.center, const Offset(50, 50));
      expect(circleMatch.radius, 20.0);
    });

    test('Background isolate parseFromFile loads and indexes DXF file', () async {
      final tempDir = await Directory.systemTemp.createTemp('dxf_iso_');
      final testFile = File('${tempDir.path}/test_isolate.dxf');

      // Create valid DXF file
      final buffer = StringBuffer('''0
SECTION
2
ENTITIES
''');
      for (int i = 0; i < 500; i++) {
        buffer.write('''0
LINE
8
0
10
${i * 10}.0
20
0.0
11
${i * 10 + 5}.0
21
5.0
''');
      }
      buffer.write('''0
ENDSEC
0
EOF
''');

      await testFile.writeAsString(buffer.toString());

      final doc = await DxfParser.parseFromFile(testFile);
      expect(doc, isNotNull);
      expect(doc.entities.length, 500);
      expect(doc.spatialIndex, isNotNull);

      // Verify spatial query works on the isolate-parsed document
      final queried = doc.spatialIndex!.query(const Rect.fromLTWH(0, 0, 50, 50));
      expect(queried.isNotEmpty, isTrue);

      await tempDir.delete(recursive: true);
    });

    test('DxfSnapHelper.hitTestEntity identifies clicked entity and respects layer visibility', () {
      final wallLine = DxfLine(
        p1: const Offset(0, 0),
        p2: const Offset(100, 0),
        layer: 'WALLS',
      );
      final pipeCircle = DxfCircle(
        center: const Offset(50, 50),
        radius: 10,
        layer: 'PIPES',
      );

      final wallLayer = DxfLayer(name: 'WALLS', colorIndex: 1, isVisible: true);
      final pipeLayer = DxfLayer(name: 'PIPES', colorIndex: 4, isVisible: true);

      final doc = DxfDocument(
        layers: {'WALLS': wallLayer, 'PIPES': pipeLayer},
        blocks: {},
        entities: [wallLine, pipeCircle],
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: {},
      );
      doc.orBuildSpatialIndex;

      // 1. Hit-test wall line near (50, 0.5)
      final hit1 = DxfSnapHelper.hitTestEntity(
        document: doc,
        cadPoint: const Offset(50, 0.5),
        toleranceCad: 2.0,
      );
      expect(hit1, isNotNull);
      expect(hit1, equals(wallLine));
      expect(hit1!.layer, 'WALLS');

      // 2. Hit-test pipe circle near circumference (50, 60.2)
      final hit2 = DxfSnapHelper.hitTestEntity(
        document: doc,
        cadPoint: const Offset(50, 60.2),
        toleranceCad: 2.0,
      );
      expect(hit2, isNotNull);
      expect(hit2, equals(pipeCircle));
      expect(hit2!.layer, 'PIPES');

      // 3. Out of range hit test returns null
      final hitMiss = DxfSnapHelper.hitTestEntity(
        document: doc,
        cadPoint: const Offset(20, 80),
        toleranceCad: 2.0,
      );
      expect(hitMiss, isNull);

      // 4. Hide PIPES layer and re-test: should ignore hidden entity
      pipeLayer.isVisible = false;
      final hitHidden = DxfSnapHelper.hitTestEntity(
        document: doc,
        cadPoint: const Offset(50, 60.2),
        toleranceCad: 2.0,
      );
      expect(hitHidden, isNull);
    });
  });
}
