import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/rendering/architect_elements_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_underlay_painter.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';

class CountingCanvas implements Canvas {
  int lines = 0;
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DxfDocument document(List<DxfEntity> entities, Rect bounds) => DxfDocument(
  entities: entities,
  layers: {'lines': DxfLayer(name: 'lines')},
  blocks: {},
  bounds: bounds,
  entityStats: {},
  headerVars: {},
);

void main() {
  test(
    'Column text remains a readable pixel-sized label at different camera scales',
    () async {
      for (final scale in [40.0, 160.0]) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder)
          ..translate(250, 250)
          ..scale(scale);
        const column = ArchitectColumn(
          id: 'col',
          position: Offset.zero,
          width: .4,
          depth: .4,
        );
        column.paint2D(canvas: canvas, zoomScale: scale);
        final picture = recorder.endRecording();
        final image = await picture.toImage(500, 500);
        final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
        var left = 500, right = 0;
        for (var y = 235; y < 265; y++) {
          for (var x = 0; x < 500; x++) {
            final offset = (y * 500 + x) * 4;
            if (data.getUint8(offset) == 255 &&
                data.getUint8(offset + 1) == 255 &&
                data.getUint8(offset + 2) == 255 &&
                data.getUint8(offset + 3) > 128) {
              if (x < left) left = x;
              if (x > right) right = x;
            }
          }
        }
        expect(right, greaterThan(left));
        expect(right - left, lessThan(80));
        image.dispose();
        picture.dispose();
      }
    },
  );

  test(
    '10,000-entity underlay renders only geometry intersecting the camera',
    () {
      final doc = document([
        for (var x = 0; x < 100; x++)
          for (var y = 0; y < 100; y++)
            DxfLine(
              layer: 'lines',
              p1: Offset(x * 10, y * 10),
              p2: Offset(x * 10 + 1, y * 10 + 1),
            ),
      ], const Rect.fromLTWH(0, 0, 1000, 1000));
      final canvas = CountingCanvas();
      ArchitectElementsPainterHelper.drawUnderlay(
        canvas: canvas,
        underlayDoc: doc,
        zoomScale: 40,
        layerVisibility: {},
        visibleRect: const Rect.fromLTWH(20, 20, 50, 50),
      );
      expect(canvas.lines, greaterThan(0));
      expect(canvas.lines, lessThan(100));
    },
  );

  test(
    'Millimetre underlay is rendered at its metre position after origin rebasing',
    () async {
      final viewport = BimViewportController();
      addTearDown(viewport.dispose);
      viewport.resize(const Size(400, 400));
      viewport.fit(const Rect.fromLTWH(0, 0, 10, 10), padding: 40);
      final doc = document([
        DxfLine(
          layer: 'lines',
          p1: const Offset(11000, 22000),
          p2: const Offset(13000, 22000),
        ),
      ], const Rect.fromLTWH(10000, 20000, 10000, 10000));
      final painter = ArchitectUnderlayPainter(
        document: doc,
        viewport: viewport,
        frame: const BimCoordinateFrame(
          origin: Offset(10000, 20000),
          unitsPerMeter: 1000,
        ),
        visibility: {},
      );
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), const Size(400, 400));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 400);
      final pixels = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
      final screen = viewport.toScreen(const Offset(2, 2));
      var alpha = 0;
      for (var y = screen.dy.floor() - 1; y <= screen.dy.ceil() + 1; y++) {
        alpha += pixels.getUint8((y * 400 + screen.dx.round()) * 4 + 3);
      }
      expect(alpha, greaterThan(0));
      image.dispose();
      picture.dispose();
    },
  );
}
