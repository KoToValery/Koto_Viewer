// Standalone test entry point: stdout markers are consumed by the ADB harness.
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';

/// Dedicated headless test entry point. No product controls or UI strings.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const input = '/data/user/0/com.koto.kotoviewer/files/acadrust_test/C.dwg';
  try {
    final document = await DwgReaderService.read(input);
    if (document.entities.length != 527 || document.blocks.length != 108) {
      throw StateError('Unexpected native object counts');
    }
    if (!document.blocks.containsKey('квадратура_3_1')) {
      throw StateError('Cyrillic block name was lost');
    }
    final file = File(input);
    if (!await file.exists()) throw StateError('Source DWG disappeared');
    print(
      'DWG_DIRECT_SMOKE_PASS entities=${document.entities.length} blocks=${document.blocks.length}',
    );
  } catch (error, stack) {
    print('DWG_DIRECT_SMOKE_FAILED $error\n$stack');
  }
}
