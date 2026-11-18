import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

// Opt-in local benchmark; no proprietary drawing is checked into the repository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const input = String.fromEnvironment('DWG_ZOOM_INPUT');
  const output = String.fromEnvironment('DWG_ZOOM_OUTPUT');
  test(
    'DWG zoom paint and raster benchmark',
    () async {
      final doc = await DwgReaderService.read(input);
      const size = Size(390, 800);
      final fit = math.min(
        (size.width - 64) / doc.bounds.width,
        (size.height - 64) / doc.bounds.height,
      );
      // ignore: avoid_print
      print('DWG_ZOOM bounds=${doc.bounds} stats=${doc.entityStats}');
      for (final zoom in [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]) {
        final visible = Rect.fromCenter(
          center: doc.bounds.center,
          width: size.width / (fit * zoom),
          height: size.height / (fit * zoom),
        );
        final paints = <double>[], rasters = <double>[];
        for (var run = 0; run < 4; run++) {
          final rec = PictureRecorder();
          final canvas = Canvas(rec)..clipRect(Offset.zero & size);
          canvas.translate(size.width / 2, size.height / 2);
          canvas.scale(zoom);
          canvas.translate(-size.width / 2, -size.height / 2);
          final painter = DxfPainter(
            document: doc,
            theme: DxfCanvasTheme.darkCad,
            currentScale: zoom,
            visibleCadRect: visible,
            showGrid: false,
          );
          final clock = Stopwatch()..start();
          painter.paint(canvas, size);
          final picture = rec.endRecording();
          final paintMs = clock.elapsedMicroseconds / 1000;
          clock.reset();
          final image = await picture.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          final rasterMs = clock.elapsedMicroseconds / 1000;
          if (run == 3 && output.isNotEmpty) {
            await Directory(output).create(recursive: true);
            final png = await image.toByteData(format: ImageByteFormat.png);
            await File('$output/zoom_${zoom.toInt()}.png').writeAsBytes(
              png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
          }
          if (run > 0) {
            paints.add(paintMs);
            rasters.add(rasterMs);
          }
          image.dispose();
          picture.dispose();
        }
        paints.sort();
        rasters.sort();
        // ignore: avoid_print
        print(
          'DWG_ZOOM zoom=$zoom paintMs=${paints[1]} rasterMs=${rasters[1]} ${DxfPainter.lastStats}',
        );
      }
    },
    skip: input.isEmpty || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
