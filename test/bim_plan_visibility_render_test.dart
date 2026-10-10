import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';

Future<ByteData> raster(
  WidgetTester tester,
  CustomPainter painter,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  late ByteData pixels;
  await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  picture.dispose();
  return pixels;
}

void main() {
  testWidgets(
    'normal BIM plan paints only ceiling; floor edit paints only current floor',
    (tester) async {
      const floor = StoreyLevel(
        id: 'f',
        name: 'Floor',
        elevation: 2.8,
        slabs: [
          StructuralSlab(
            id: 'floor',
            isFloorSlab: true,
            polygon: [Offset(1, 1), Offset(3, 1), Offset(3, 3), Offset(1, 3)],
          ),
        ],
      );
      const ceiling = StoreyLevel(
        id: 'c',
        name: 'Ceiling',
        elevation: 5.6,
        slabs: [
          StructuralSlab(
            id: 'ceiling',
            isFloorSlab: true,
            polygon: [Offset(4, 1), Offset(6, 1), Offset(6, 3), Offset(4, 3)],
          ),
        ],
      );
      for (final editing in [false, true]) {
        final p = Structural2dPainter(
          currentStorey: floor,
          ceilingSlabStorey: ceiling,
          showFloorSlabs: editing,
          selectedSlabId: editing ? 'floor' : null,
          hasBasement: true,
          showSlabSpanOverlay: false,
          showCantileverHeatmap: false,
          cadToScene: (p) => p * 20,
          cadScale: 20,
        );
        final pixels = await raster(tester, p, 160, 100);
        int alpha(int x, int y) => pixels.getUint8((y * 160 + x) * 4 + 3);
        expect(alpha(20, 40), editing ? greaterThan(100) : 0);
        expect(alpha(80, 40), editing ? 0 : greaterThan(100));
      }
    },
  );
  testWidgets(
    'filtered wall pen remains white and thick while architecture is thin grey',
    (tester) async {
      final d = DxfDocument(
        entities: const [
          DxfLine(layer: 'BIM_Walls', p1: Offset(10, 25), p2: Offset(90, 25)),
          DxfLine(
            layer: 'architecture',
            p1: Offset(10, 75),
            p2: Offset(90, 75),
            colorIndex: 1,
            lineWeight: .7,
          ),
        ],
        layers: {
          'BIM_Walls': DxfLayer(
            name: 'BIM_Walls',
            colorIndex: 7,
            customLineweight: .30,
          ),
          'architecture': DxfLayer(name: 'architecture'),
        },
        blocks: {},
        headerVars: {},
        entityStats: {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
      );
      final pixels = await raster(
        tester,
        DxfPainter(
          document: d,
          theme: DxfCanvasTheme.darkCad,
          showGrid: false,
          drawingColorOverride: const Color(0xFF92979C),
          drawingStrokeWidthOverride: .8,
          originalStyleLayers: const {'BIM_Walls'},
        ),
        200,
        200,
      );
      int red(int y) => pixels.getUint8((y * 200 + 100) * 4);
      expect(red(134), greaterThan(220));
      expect(red(133), greaterThan(180));
      expect(red(66), lessThan(180));
      expect(red(65), lessThan(100));
    },
  );
}
