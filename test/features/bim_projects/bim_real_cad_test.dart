import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';

/// Opt-in: these local reference drawings are not shipped with every checkout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('BIM_REAL_CAD');
  test(
    'Local real CAD conversion and load measurements',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path,
          );
      final reports = <Map<String, Object?>>[];
      for (final path in [
        'test_files/Archicad_export.dwg',
        'test_files/OVK_converted.dxf',
        'test_files/930_ovk.dxf',
      ]) {
        final source = File(path);
        expect(await source.exists(), isTrue, reason: path);
        final timer = Stopwatch()..start();
        final result = await BimUnderlayConversionService.convert(source);
        final conversionMs = timer.elapsedMilliseconds;
        try {
          timer.reset();
          final doc = await KcadService.loadKcadFile(result.kcadFile);
          final loadMs = timer.elapsedMilliseconds;
          timer.reset();
          final again = await KcadService.loadKcadFile(result.kcadFile);
          final repeatedLoadMs = timer.elapsedMilliseconds;
          expect(again.entities.length, doc.entities.length);
          expect(BimUnderlayMetadata.read(doc), isNotNull);
          final generated = BimUnderlayMetadata.generatedLayers(doc);
          final report = <String, Object?>{
            'source': path,
            'sourceBytes': await source.length(),
            'conversionMs': conversionMs,
            'loadMs': loadMs,
            'repeatedLoadMs': repeatedLoadMs,
            'entities': doc.entities.length,
            'generatedEntities': doc.entities
                .where((e) => generated.contains(e.layer))
                .length,
            'axes': BimUnderlayMetadata.axes(doc).length,
            'slabGapHypotheses':
                (BimUnderlayMetadata.read(doc)?['slabEnvelope']?['assumedGaps']
                        as List?)
                    ?.length,
            'slabRegions':
                (BimUnderlayMetadata.read(doc)?['slabEnvelope']?['regions']
                        as List?)
                    ?.length,
            'slabSkippedRegions': BimUnderlayMetadata.read(
              doc,
            )?['slabEnvelope']?['skippedRegions'],
            'slabEnvelopeStatus': BimUnderlayMetadata.read(
              doc,
            )?['slabEnvelope']?['status'],
            'slabEnvelopeDiagnostics': BimUnderlayMetadata.read(
              doc,
            )?['slabEnvelope']?['diagnostics'],
            'slabEnvelopeContours':
                (BimUnderlayMetadata.read(doc)?['slabEnvelope']?['contours']
                        as List?)
                    ?.length,
            'kcadBytes': await result.kcadFile.length(),
          };
          reports.add(report);
          // ignore: avoid_print
          print(jsonEncode(report));
          await File(
            'docs/bim_underlay_validation.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(reports));
        } finally {
          await result.dispose();
        }
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
