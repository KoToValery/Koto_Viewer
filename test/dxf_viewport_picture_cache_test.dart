import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_math.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_viewport_picture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reuses visible drawing regions and invalidates changed layer content',
    () async {
      const bounds = Rect.fromLTWH(0, 0, 1000, 1000);
      const viewport = Rect.fromLTWH(20, 20, 900, 900);
      final layer = DxfLayer(name: '0');
      final doc = DxfDocument(
        layers: {'0': layer},
        blocks: {},
        entities: const [DxfLine(p1: Offset(100, 100), p2: Offset(800, 800))],
        headerVars: {},
        bounds: bounds,
        entityStats: {},
      );
      final cache = DxfViewportPictureCache();
      addTearDown(cache.dispose);

      DxfPainter painter({
        Rect visible = viewport,
        double scale = 1,
        int revision = 0,
        bool retain = true,
      }) => DxfPainter(
        document: doc,
        theme: DxfCanvasTheme.darkCad,
        showGrid: false,
        visibleCadRect: visible,
        currentScale: scale,
        revision: revision,
        viewportPictures: retain ? cache : null,
      );

      final first = painter();
      final original = await _pixels(first);
      expect(original, await _pixels(painter(retain: false)));
      expect(cache.recordings, 1);

      final shifted = painter(
        visible: viewport.shift(const Offset(20, 0)),
        scale: 1.02,
      );
      expect(shifted.shouldRepaint(first), isFalse);
      expect(await _pixels(shifted), original);
      expect(cache.recordings, 1);

      final zoomed = painter(scale: 2);
      expect(zoomed.shouldRepaint(shifted), isTrue);
      await _pixels(zoomed);
      expect(cache.recordings, 2);
      expect(await _pixels(painter()), original);
      expect(cache.recordings, 2);

      layer.isVisible = false;
      final hidden = painter(revision: 1);
      expect(hidden.shouldRepaint(first), isTrue);
      expect((await _pixels(hidden)).every((value) => value == 0), isTrue);
      expect(cache.recordings, 3);
    },
  );

  test('retains block paths by their complete scene transform', () {
    final block = DxfBlock(
      name: 'detail',
      entities: List.generate(
        12,
        (i) =>
            DxfLine(p1: Offset(i.toDouble(), 0), p2: Offset(i.toDouble(), 10)),
      ),
    );
    final source = block.compiled.subpaths.single;
    expect(source.pointCount, 24);

    final cache = DxfViewportPictureCache();
    addTearDown(cache.dispose);
    DxfAffineMatrix placement(double x) => DxfAffineMatrix.forInsert(
      scaleX: -2,
      scaleY: 3,
      rotationDeg: 28,
      canvasOrigin: Offset(x, 40),
      fitScale: 2,
    );

    final path = cache.blockPaths.obtain(source, placement(80));
    expect(cache.blockPaths.obtain(source, placement(80)), same(path));
    final moved = cache.blockPaths.obtain(source, placement(90));
    expect(moved, isNot(same(path)));
    expect(moved.getBounds().left, closeTo(path.getBounds().left + 10, 0.001));

    cache.dispose();
    expect(cache.blockPaths.obtain(source, placement(80)), isNot(same(path)));
  });

  test(
    'keeps nested block geometry and lineweights across zoom bands',
    () async {
      const bounds = Rect.fromLTWH(0, 0, 200, 200);
      final layer = DxfLayer(name: 'detail', colorIndex: 2);
      final document = DxfDocument(
        layers: {layer.name: layer},
        blocks: {
          'leaf': DxfBlock(
            name: 'leaf',
            basePoint: const Offset(4, 10),
            entities: List.generate(
              12,
              (i) => DxfLine(
                p1: Offset(4 + i * 2.0, 10),
                p2: Offset(4 + i * 2.0, 20),
                layer: layer.name,
              ),
            ),
          ),
          'parent': DxfBlock(
            name: 'parent',
            entities: const [
              DxfInsert(
                blockName: 'leaf',
                insertPoint: Offset(8, 16),
                scaleX: -1.2,
                scaleY: 2.0,
                rotationDeg: 15,
                colCount: 2,
                colSpacing: 35,
              ),
            ],
          ),
        },
        entities: const [
          DxfInsert(
            blockName: 'parent',
            insertPoint: Offset(88, 80),
            rotationDeg: 25,
          ),
        ],
        headerVars: {},
        bounds: bounds,
        entityStats: {},
      );
      final cache = DxfViewportPictureCache();
      addTearDown(cache.dispose);
      Future<Uint8List> pixels(
        double scale, {
        bool retained = true,
        int revision = 0,
      }) => _pixels(
        DxfPainter(
          document: document,
          theme: DxfCanvasTheme.darkCad,
          visibleCadRect: bounds,
          showGrid: false,
          currentScale: scale,
          viewportPictures: retained ? cache : null,
          revision: revision,
        ),
      );

      expect((await pixels(1)).any((value) => value != 0), isTrue);
      final detail = await pixels(2);
      expect(detail, await pixels(2, retained: false));
      expect(cache.recordings, 2);
      layer.customLineweight = 0.70;
      final thicker = await pixels(2, revision: 1);
      expect(thicker, isNot(detail));
      expect(thicker, await pixels(2, retained: false));
    },
  );
}

Future<Uint8List> _pixels(DxfPainter painter) async {
  const size = Size(200, 200);
  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(200, 200);
    try {
      final data = (await image.toByteData())!;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
