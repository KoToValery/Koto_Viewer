import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_viewport_picture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reuses visible drawing regions and invalidates changed layer content', () async {
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

    final shifted = painter(visible: viewport.shift(const Offset(20, 0)), scale: 1.02);
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
  });
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
