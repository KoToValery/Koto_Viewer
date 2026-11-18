import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const run = bool.fromEnvironment('RUN_DIRECT_DWG_INTEGRATION');
  late Directory temp;
  late PathProviderPlatform previous;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dwg_direct_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temp.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await temp.delete(recursive: true);
  });
  for (final name in ['0', 'C', '3.30', '1', '2', 'text', 'text_wrap']) {
    test(
      'direct DWG objects match existing viewer geometry: $name',
      () async {
        final input = await File(
          'test_files/$name.dwg',
        ).copy('${temp.path}/Чертеж 🏠.dwg');
        // The actual public loading API must select native reading before any
        // converted-file or KCAD cache path, including pre-existing stale caches.
        final actual = await DxfParser.parseFromFile(input);
        expect(
          await Directory('${temp.path}/dwg_cache').exists(),
          isFalse,
          reason: 'Direct DWG opening must not create intermediate CAD files',
        );
        expect(temp.listSync().whereType<File>().length, 1);
        // DXF is a test oracle only, after the no-intermediate assertion above.
        final oraclePath = await DwgConverterService.convertDwgToDxf(
          input.path,
          backend: DwgConversionBackend.acadrust,
          forceReconvert: true,
        );
        final expected = DxfParser.parseString(
          UniversalEncodingService.decodeBytes(
            await File(oraclePath).readAsBytes(),
          ),
        );
        expect(actual.entityStats, expected.entityStats);
        expect(actual.layers.keys.toSet(), expected.layers.keys.toSet());
        expect(actual.blocks.keys.toSet(), expected.blocks.keys.toSet());
        expect(actual.bounds.left, closeTo(expected.bounds.left, .001));
        expect(actual.bounds.top, closeTo(expected.bounds.top, .001));
        expect(actual.bounds.right, closeTo(expected.bounds.right, .001));
        expect(actual.bounds.bottom, closeTo(expected.bounds.bottom, .001));
        _compare(
          actual.entities,
          expected.entities,
          actual.blocks,
          expected.blocks,
        );
        for (final block in expected.blocks.entries) {
          _compare(
            actual.blocks[block.key]!.entities,
            block.value.entities,
            actual.blocks,
            expected.blocks,
          );
        }
      },
      skip:
          !run ||
          !Platform.isWindows ||
          !File('test_files/$name.dwg').existsSync(),
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  test(
    'corrupt DWG is rejected without creating converted files',
    () async {
      final input = await File('${temp.path}/bad.dwg').writeAsString('not DWG');
      await expectLater(
        DwgReaderService.read(input.path),
        throwsA(isA<FormatException>()),
      );
      expect(temp.listSync().length, 1);
    },
    skip: !run || !Platform.isWindows,
  );
}

void _compare(
  List<DxfEntity> actual,
  List<DxfEntity> expected,
  Map<String, DxfBlock> actualBlocks,
  Map<String, DxfBlock> expectedBlocks,
) {
  expect(actual.length, expected.length);
  for (var i = 0; i < expected.length; i++) {
    final a = actual[i], b = expected[i];
    expect(a.typeName, b.typeName, reason: 'entity $i');
    expect(a.layer, b.layer, reason: 'entity $i ${a.typeName}');
    final ar = a.getBoundingBox(actualBlocks),
        br = b.getBoundingBox(expectedBlocks);
    if (ar != null && br != null) {
      expect(
        ar.left,
        closeTo(br.left, .001),
        reason: 'entity $i ${a.typeName} left',
      );
      expect(
        ar.top,
        closeTo(br.top, .001),
        reason: 'entity $i ${a.typeName} top',
      );
      expect(
        ar.right,
        closeTo(br.right, .001),
        reason: 'entity $i ${a.typeName} right',
      );
      expect(
        ar.bottom,
        closeTo(br.bottom, .001),
        reason: 'entity $i ${a.typeName} bottom',
      );
    }
    if (a is DxfMText && b is DxfMText) {
      expect(a.cleanText, b.cleanText);
      expect(a.height, closeTo(b.height, .001));
      expect(a.attachmentPoint, b.attachmentPoint);
    }
    if (a is DxfText && b is DxfText) {
      expect(a.text, b.text);
      expect(a.height, closeTo(b.height, .001));
    }
    if (a is DxfInsert && b is DxfInsert) {
      expect(a.blockName, b.blockName);
      expect(a.attributeMap, b.attributeMap);
    }
  }
}
