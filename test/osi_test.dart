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

  test('parses axis markers (ATTDEF / ATTRIB) in osi.dwg correctly', () async {
    final osiDwg = File(r'C:\Users\Creator\Dropbox\test_files\osi.dwg');
    if (!osiDwg.existsSync()) return;

    final dxfPath = await DwgConverterService.convertDwgToDxf(osiDwg.path);
    final doc = await DxfParser.parseFromFile(File(dxfPath));

    final axisTexts = <String>[];
    for (final block in doc.blocks.values) {
      if (block.name.contains('Standard grid marker')) {
        for (final entity in block.entities) {
          if (entity is DxfText) {
            axisTexts.add(entity.text.trim());
          }
        }
      }
    }

    print('Found axis marker texts: $axisTexts');
    expect(axisTexts, contains('A'));
    expect(axisTexts, contains('B'));
    expect(axisTexts, contains('C'));
    expect(axisTexts, contains('1'));
    expect(axisTexts, contains('2'));
    expect(axisTexts, contains('3'));
  });
}
