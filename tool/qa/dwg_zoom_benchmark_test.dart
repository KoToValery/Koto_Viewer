import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_viewport_picture_cache.dart';

// Opt-in local benchmark; no proprietary drawing is checked into the repository.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const input = String.fromEnvironment('DWG_ZOOM_INPUT');
  const output = String.fromEnvironment('DWG_ZOOM_OUTPUT');
  const region = String.fromEnvironment('DWG_ZOOM_REGION');
  const configuredInteractiveHatches = bool.fromEnvironment(
    'DWG_ZOOM_INTERACTIVE_HATCHES',
  );
  const compareHatches = bool.fromEnvironment('DWG_ZOOM_COMPARE_HATCHES');
  const retainPictures = bool.fromEnvironment('DWG_ZOOM_RETAIN_PICTURES');
  const requestedRepeats = int.fromEnvironment(
    'DWG_ZOOM_REPEATS',
    defaultValue: 4,
  );
  final repeats = requestedRepeats.clamp(2, 12);
  final hatchModes = compareHatches
      ? const [false, true]
      : [configuredInteractiveHatches];
  for (final interactiveHatches in hatchModes) {
    final mode = interactiveHatches ? 'interactive' : 'detailed';
    final outputDirectory = compareHatches && output.isNotEmpty
        ? '$output/$mode'
        : output;
    test(
      compareHatches
          ? 'DWG zoom paint and raster benchmark ($mode)'
          : 'DWG zoom paint and raster benchmark',
      () async {
        final cache = retainPictures ? DxfViewportPictureCache() : null;
        if (cache != null) addTearDown(cache.dispose);
        final openClock = Stopwatch()..start();
        final doc = await DwgReaderService.read(input);
        openClock.stop();
        // Optional CAD x,y,width gives a repeatable, close-up drawing comparison.
        final crop = region.isEmpty ? null : region.split(',').map(double.parse).toList();
        if (crop != null && outputDirectory.isNotEmpty) await _loadWindowsFonts();
        final size = crop == null ? const Size(390, 800) : const Size(960, 520);
        final fit = math.min(
          (size.width - 64) / doc.bounds.width,
          (size.height - 64) / doc.bounds.height,
        );
        // ignore: avoid_print
        print(
          'DWG_ZOOM openMs=${openClock.elapsedMicroseconds / 1000} '
          'interactiveHatches=$interactiveHatches repeats=$repeats',
        );
        // ignore: avoid_print
        print('DWG_ZOOM bounds=${doc.bounds} stats=${doc.entityStats}');
        final center = crop == null ? doc.bounds.center : Offset(crop[0], crop[1]);
        final zooms = crop == null
            ? [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, if (retainPictures) 1.0]
            : [size.width / (fit * crop[2])];
        final delta = center - doc.bounds.center;
        for (final zoom in zooms) {
          final recordingsBefore = cache?.recordings ?? 0;
          final visible = Rect.fromCenter(
            center: center,
            width: size.width / (fit * zoom),
            height: size.height / (fit * zoom),
          );
          final paints = <double>[];
          final rasters = <double>[];
          var peakPictureBytes = 0;
          for (var run = 0; run < repeats; run++) {
            final rec = PictureRecorder();
            final canvas = Canvas(rec)..clipRect(Offset.zero & size);
            canvas.translate(size.width / 2, size.height / 2);
            canvas.scale(zoom);
            canvas.translate(-size.width / 2 - delta.dx * fit, -size.height / 2 + delta.dy * fit);
            final painter = DxfPainter(
              document: doc,
              theme: DxfCanvasTheme.darkCad,
              currentScale: zoom,
              visibleCadRect: visible,
              showGrid: false,
              interactiveHatches: interactiveHatches,
              viewportPictures: cache,
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
            peakPictureBytes = math.max(
              peakPictureBytes,
              picture.approximateBytesUsed,
            );
            if (run == repeats - 1 && outputDirectory.isNotEmpty) {
              await Directory(outputDirectory).create(recursive: true);
              final png = await image.toByteData(format: ImageByteFormat.png);
              await File(
                '$outputDirectory/zoom_${zoom.toInt()}.png',
              ).writeAsBytes(
                png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
              );
            }
            paints.add(paintMs);
            rasters.add(rasterMs);
            image.dispose();
            picture.dispose();
          }
          final firstPaintMs = paints.removeAt(0);
          final firstRasterMs = rasters.removeAt(0);
          // ignore: avoid_print
          print(
            'DWG_ZOOM zoom=$zoom paintMs=${_median(paints)} rasterMs=${_median(rasters)} '
            'firstPaintMs=$firstPaintMs firstRasterMs=$firstRasterMs '
            'recordings=${(cache?.recordings ?? 0) - recordingsBefore} retained=$retainPictures '
            'peakPictureBytes=$peakPictureBytes hatchMode=$mode ${DxfPainter.lastStats}',
          );
        }
      },
      skip: input.isEmpty || !Platform.isWindows,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}

Future<void> _loadWindowsFonts() async {
  final windows = Platform.environment['WINDIR'];
  if (windows == null) return;
  const fonts = {'Arial': 'arial.ttf', 'Arial Narrow': 'arialn.ttf'};
  for (final entry in fonts.entries) {
    final file = File('$windows/Fonts/${entry.value}');
    if (!await file.exists()) continue;
    await (FontLoader(entry.key)
          ..addFont(file.readAsBytes().then(ByteData.sublistView)))
        .load();
  }
}

double _median(List<double> samples) {
  samples.sort();
  final center = samples.length ~/ 2;
  return samples.length.isOdd
      ? samples[center]
      : (samples[center - 1] + samples[center]) / 2;
}
