// Standalone test entry point: stdout markers are consumed by the ADB harness.
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';

/// Dedicated headless test entry point. No product controls or UI strings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const phoneRepro = bool.fromEnvironment('DWG_PHONE_REPRO');
  const directory = phoneRepro
      ? '/data/user/0/com.koto.kotoviewer/cache/phone_repro'
      : '/data/user/0/com.koto.kotoviewer/files/acadrust_test';
  final fixtures = phoneRepro
      ? {
          'C.dwg': (527, 108),
          '+-0,00 Worksheet.dwg': (2778, 138),
          'К1_ситуация Worksheet.dwg': (3034, 45),
        }
      : {'C.dwg': (527, 108)};
  try {
    for (final fixture in fixtures.entries) {
      final input = '$directory/${fixture.key}';
      final document = await DwgReaderService.read(input);
      if (document.entities.length != fixture.value.$1 ||
          document.blocks.length != fixture.value.$2) {
        throw StateError('Unexpected native object counts: ${fixture.key}');
      }
      if (fixture.key == 'C.dwg' &&
          !document.blocks.containsKey('квадратура_3_1')) {
        throw StateError('Cyrillic block name was lost');
      }
      if (!await File(input).exists())
        throw StateError('Source DWG disappeared');
      print(
        'DWG_DIRECT_SMOKE_PASS file=${fixture.key} entities=${document.entities.length} blocks=${document.blocks.length}',
      );
    }
    if (phoneRepro) {
      final invalid = await File('$directory/bad.dwg').writeAsString('not DWG');
      var rejected = false;
      try {
        await DwgReaderService.read(invalid.path);
      } on FormatException catch (error) {
        rejected =
            error.message.contains('DWG_DECODE_FAILED') &&
            error.toString().contains('Unsupported CAD version');
      } finally {
        await invalid.delete();
      }
      if (!rejected)
        throw StateError('Native diagnostic did not reach Flutter');
      final outputs = Directory(directory).listSync().whereType<File>();
      if (outputs.length != fixtures.length ||
          outputs.any((f) => !f.path.endsWith('.dwg'))) {
        throw StateError('Unexpected intermediate file in source directory');
      }
      print(
        'DWG_DIRECT_PHONE_REPRO_PASS original_files=${fixtures.length} native_diagnostics=true intermediates=0',
      );
    }
  } catch (error, stack) {
    print('DWG_DIRECT_SMOKE_FAILED $error\n$stack');
  }
}
