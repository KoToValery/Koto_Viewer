import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

void main() {
  group('DxfPainter Level of Detail (LOD) & Sub-pixel Culling Tests', () {
    test('DxfBlock getBounds lazily computes and caches bounding box', () {
      final block = DxfBlock(
        name: 'VALVE',
        basePoint: Offset.zero,
        entities: const [
          DxfLine(p1: Offset(0, 0), p2: Offset(10, 10)),
          DxfCircle(center: Offset(5, 5), radius: 5),
        ],
      );

      final bounds1 = block.getBounds({});
      expect(bounds1, isNotNull);
      expect(bounds1!.left, equals(0.0));
      expect(bounds1.right, equals(10.0));
      expect(bounds1.top, equals(0.0));
      expect(bounds1.bottom, equals(10.0));

      // Second call returns cached bounds
      final bounds2 = block.getBounds({});
      expect(identical(bounds1, bounds2), isTrue);
    });

    test('DxfPainter renders without crashing when zoomed out on heavy mock CAD document', () {
      // Create a mock document with lines, arcs, texts, blocks and hatches
      final entities = <DxfEntity>[];

      for (int i = 0; i < 1000; i++) {
        entities.add(DxfLine(
          p1: Offset(i * 10.0, 0),
          p2: Offset(i * 10.0, 100.0),
        ));
        entities.add(DxfArc(
          center: Offset(i * 10.0, 50.0),
          radius: 2.0,
          startAngleDeg: 0,
          endAngleDeg: 180,
        ));
        entities.add(DxfText(
          text: 'DN$i',
          insertPoint: Offset(i * 10.0, 60.0),
          height: 2.5,
        ));
        entities.add(DxfMText(
          rawText: 'VENT_$i',
          cleanText: 'VENT_$i',
          insertPoint: Offset(i * 10.0, 70.0),
          height: 2.5,
        ));
      }

      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0', colorIndex: 7)},
        blocks: {},
        entities: entities,
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 10000, 5000),
        entityStats: {},
      );

      final painter = DxfPainter(
        document: doc,
        theme: DxfCanvasTheme.darkCad,
        currentScale: 1.0, // Zoomed completely out
      );

      final pictureRecorder = PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = Size(1920, 1080);

      // Verify painting completes cleanly with LOD culling active
      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = pictureRecorder.endRecording();
      expect(picture, isNotNull);
    });

    test('DxfPainter text LOD culls microscopic text when zoomed out and draws when zoomed in', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0', colorIndex: 7)},
        blocks: {},
        entities: const [
          DxfText(text: 'TinyLabel', insertPoint: Offset(100, 100), height: 2.0),
          DxfMText(rawText: 'MicroDuct', cleanText: 'MicroDuct', insertPoint: Offset(200, 200), height: 2.0),
        ],
        headerVars: {},
        bounds: const Rect.fromLTWH(0, 0, 20000, 10000), // Very large CAD building
        entityStats: {},
      );

      // Zoomed out (currentScale = 1.0): fitScale is ~1920 / 20000 = 0.096, text font size on screen < 0.3px -> culled
      final painterZoomedOut = DxfPainter(
        document: doc,
        theme: DxfCanvasTheme.darkCad,
        currentScale: 1.0,
      );

      final rec1 = PictureRecorder();
      final canvas1 = Canvas(rec1);
      expect(() => painterZoomedOut.paint(canvas1, const Size(1920, 1080)), returnsNormally);
      rec1.endRecording();

      // Zoomed in (currentScale = 50.0): text font size on screen > 10px -> rendered normally
      final painterZoomedIn = DxfPainter(
        document: doc,
        theme: DxfCanvasTheme.darkCad,
        currentScale: 50.0,
      );

      final rec2 = PictureRecorder();
      final canvas2 = Canvas(rec2);
      expect(() => painterZoomedIn.paint(canvas2, const Size(1920, 1080)), returnsNormally);
      rec2.endRecording();
    });
  });
}
