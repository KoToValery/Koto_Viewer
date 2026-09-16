import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  test('inspect VP.dwg parsed document', () async {
    final vpDwg = File(r'C:\Users\Creator\Dropbox\test_files\VP.dwg');
    if (!vpDwg.existsSync()) return;

    final dxfPath = await DwgConverterService.convertDwgToDxf(vpDwg.path);
    final doc = await DxfParser.parseFromFile(File(dxfPath));

    print('=== PARSED LAYERS ===');
    for (final l in doc.layers.values) {
      print('Layer: ${l.name} | isVisible: ${l.isVisible} | isFrozen: ${l.isFrozen}');
    }

    print('\n=== PARSED BLOCKS ===');
    for (final b in doc.blocks.values) {
      print('Block: ${b.name} (${b.entities.length} entities)');
      for (final e in b.entities) {
        if (e is DxfMText) {
          print('  -> MText: "${e.cleanText}" on layer "${e.layer}"');
        } else if (e is DxfText) {
          print('  -> Text: "${e.text}" on layer "${e.layer}"');
        }
      }
    }

    print('\n=== PARSED ENTITIES ===');
    for (final e in doc.entities) {
      if (e is DxfInsert) {
        print('Insert: block "${e.blockName}" on layer "${e.layer}" at ${e.insertPoint}');
      } else if (e is DxfMText) {
        print('MText: "${e.cleanText}" on layer "${e.layer}" at ${e.insertPoint}');
      } else if (e is DxfText) {
        print('Text: "${e.text}" on layer "${e.layer}" at ${e.insertPoint}');
      }
    }
  });
}
