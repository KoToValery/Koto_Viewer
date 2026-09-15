import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_painter.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String tempPath;
  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('el_dwg_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('Convert and verify el.dwg layer states and text rendering', () async {
    const dwgPath = r'C:\Users\Creator\Dropbox\test_files\el.dwg';
    final dwgFile = File(dwgPath);
    if (!dwgFile.existsSync()) {
      print('el.dwg not found, skipping integration test');
      return;
    }

    final dxfPath = await DwgConverterService.convertDwgToDxf(dwgPath, forceReconvert: true);
    final dxfFile = File(dxfPath);
    expect(dxfFile.existsSync(), isTrue);

    // Verify KOTO_DWG_LAYERS comment is present in the DXF file header
    final headerBytes = await dxfFile.openRead(0, 4096).first;
    final headerStr = latin1.decode(headerBytes);
    expect(headerStr.contains('KOTO_DWG_LAYERS:'), isTrue, reason: 'KOTO_DWG_LAYERS should be injected by dwglayers');
    expect(headerStr.contains('fill=-'), isTrue, reason: 'fill layer must be off');
    expect(
      headerStr.contains('${Uri.encodeComponent('размери')}=-') || headerStr.contains('размери=-'),
      isTrue,
      reason: 'размери layer must be off in header comment',
    );

    // Parse with DxfParser
    final doc = await DxfParser.parseFromFile(dxfFile);

    // Verify layer visibilities match AutoCAD
    expect(doc.layers.containsKey('fill'), isTrue);
    expect(doc.layers['fill']!.isVisible, isFalse, reason: 'fill must be hidden');

    expect(doc.layers.containsKey('размери'), isTrue);
    expect(doc.layers['размери']!.isVisible, isFalse, reason: 'размери must be hidden');

    expect(doc.layers.containsKey('Elektro'), isTrue);
    expect(doc.layers['Elektro']!.isVisible, isTrue, reason: 'Elektro must be visible');

    expect(doc.layers.containsKey('антетка'), isTrue);
    expect(doc.layers['антетка']!.isVisible, isTrue, reason: 'антетка must be visible');

    // Verify MTEXT height for "слаботокова инсталация"
    final mtexts = doc.entities.whereType<DxfMText>().toList();
    final slabText = mtexts.firstWhere((m) => m.cleanText.contains('слаботокова'));
    expect(slabText.height, equals(40.0));

    final effectiveHeight = DxfPainter.getEffectiveTextHeight(slabText.height, slabText.style, doc);
    expect(effectiveHeight, equals(40.0), reason: 'Effective height should be 40.0, NOT scaled 12x to 480.0');

    // Verify MTEXT for "КОТА +/-0.00"
    final kotaText = mtexts.firstWhere((m) => m.cleanText.contains('КОТА'));
    expect(kotaText.height, equals(40.0));
    final kotaHeight = DxfPainter.getEffectiveTextHeight(kotaText.height, kotaText.style, doc);
    expect(kotaHeight, equals(40.0));

    print('✓ All el.dwg layer states and text scaling verified successfully!');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
