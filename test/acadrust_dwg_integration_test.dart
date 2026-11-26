import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/parser/dxf_parser.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void _comparePoint(Offset? actual, Offset? expected) {
  if (expected == null) {
    expect(actual, isNull);
  } else {
    expect(actual, isNotNull);
    expect(actual!.dx, closeTo(expected.dx, .001));
    expect(actual.dy, closeTo(expected.dy, .001));
  }
}

void _compareEntities(
  List<DxfEntity> actual,
  List<DxfEntity> expected,
  Map<String, DxfBlock> actualBlocks,
  Map<String, DxfBlock> expectedBlocks,
) {
  expect(actual.length, expected.length);
  for (var i = 0; i < expected.length; i++) {
    final a = actual[i], b = expected[i];
    expect(a.typeName, b.typeName, reason: 'entity $i');
    expect(a.layer, b.layer, reason: 'entity $i');
    expect(a.isPaperSpace, b.isPaperSpace, reason: 'entity $i');
    final aBounds = a.getBoundingBox(actualBlocks);
    final bBounds = b.getBoundingBox(expectedBlocks);
    _comparePoint(aBounds?.topLeft, bBounds?.topLeft);
    _comparePoint(aBounds?.bottomRight, bBounds?.bottomRight);
    if (a is DxfLine && b is DxfLine) {
      _comparePoint(a.p1, b.p1);
      _comparePoint(a.p2, b.p2);
    } else if (a is DxfText && b is DxfText) {
      expect(a.text, b.text);
      expect(a.height, closeTo(b.height, .001));
      expect(a.hAlign, b.hAlign);
      expect(a.vAlign, b.vAlign);
      _comparePoint(a.insertPoint, b.insertPoint);
      _comparePoint(a.alignPoint, b.alignPoint);
    } else if (a is DxfMText && b is DxfMText) {
      expect(a.cleanText, b.cleanText);
      expect(a.height, closeTo(b.height, .001));
      expect(a.attachmentPoint, b.attachmentPoint);
      expect(a.rotationDeg, closeTo(b.rotationDeg, .001));
      _comparePoint(a.insertPoint, b.insertPoint);
    } else if (a is DxfInsert && b is DxfInsert) {
      expect(a.blockName, b.blockName);
      expect(a.attributeMap, b.attributeMap);
      expect(a.scaleX, closeTo(b.scaleX, 1e-6));
      expect(a.scaleY, closeTo(b.scaleY, 1e-6));
      expect(a.rotationDeg, closeTo(b.rotationDeg, .001));
    } else if (a is DxfDimension && b is DxfDimension) {
      expect(a.dimType, b.dimType);
      expect(a.textOverride, b.textOverride);
      _comparePoint(a.defPoint1, b.defPoint1);
      _comparePoint(a.defPoint2, b.defPoint2);
      _comparePoint(a.defPoint3, b.defPoint3);
      _comparePoint(a.textPoint, b.textPoint);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_ACADRUST_INTEGRATION');
  late Directory temp;
  late PathProviderPlatform previous;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('koto_dwg_compare_');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await temp.delete(recursive: true);
  });

  test(
    'failed acadrust conversion throws DwgConversionException without fallback',
    () async {
      expect(AcadrustConverterService.isAvailable, isTrue);
      final input = File('test_files/C.dwg');
      var attempts = 0;
      await expectLater(
        () => DwgConverterService.convertDwgToDxf(
          input.path,
          acadrustProcessRunner: (_, arguments) async {
            attempts++;
            await File(arguments.last).writeAsString('partial output');
            return ProcessResult(1, 1, '', 'simulated parser failure');
          },
        ),
        throwsA(isA<DwgConversionException>()),
      );
      expect(attempts, 1);
      final primaryPath = await DwgConverterService.convertDwgToDxf(input.path);
      expect(primaryPath, endsWith('_v7.dxf'));
    },
    skip: !enabled || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final name in ['0', 'C', '3.30', '1', '2', 'text', 'text_wrap']) {
    final fixture = File('test_files/$name.dwg');
    test(
      'acadrust DWG conversion: $name.dwg',
      () async {
        expect(
          AcadrustConverterService.findExecutable(),
          isNotNull,
          reason: 'Run tools/build_acadrust.ps1 first',
        );
        // Exercise Unicode input paths in the real Windows executable too.
        final folder = await Directory(
          '${temp.path}/Чертежи с интервали',
        ).create();
        final input = await fixture.copy('${folder.path}/етаж.dwg');
        final path = await DwgConverterService.convertDwgToDxf(
          input.path,
          forceReconvert: true,
        );
        final rustText = UniversalEncodingService.decodeBytes(
          await File(path).readAsBytes(),
        );
        expect(rustText, contains('KOTO_DWG_CONVERTER:acadrust-0.6.8'));
        expect(path, endsWith('_v7.dxf'));
        final rust = DxfParser.parseString(rustText);
        expect(rust.entities, isNotEmpty);
        expect(rust.layers, isNotEmpty);
        expect(rust.bounds.isFinite, isTrue);
        if (name == 'C') {
          expect(rust.blocks, contains('квадратура_3_1'));
        }
        debugPrint(
          '$name.dwg: acadrust=${rust.entities.length}/${rust.blocks.length}/${rust.layers.length}; '
          'types=${rust.entityStats}; bounds=${rust.bounds}',
        );
        const androidOutputs = String.fromEnvironment(
          'ACADRUST_ANDROID_DXF_DIR',
        );
        if (androidOutputs.isNotEmpty) {
          final androidFile = File('$androidOutputs/$name.dwg 🏠.dxf');
          expect(
            await androidFile.exists(),
            isTrue,
            reason: 'Run tools/test_acadrust_android.ps1 first',
          );
          final android = DxfParser.parseString(
            UniversalEncodingService.decodeBytes(
              await androidFile.readAsBytes(),
            ),
          );
          expect(android.entityStats, rust.entityStats);
          expect(android.layers.keys.toSet(), rust.layers.keys.toSet());
          expect(android.blocks.keys.toSet(), rust.blocks.keys.toSet());
          _compareEntities(
            android.entities,
            rust.entities,
            android.blocks,
            rust.blocks,
          );
          for (final block in rust.blocks.entries) {
            _compareEntities(
              android.blocks[block.key]!.entities,
              block.value.entities,
              android.blocks,
              rust.blocks,
            );
          }
          for (final layer in rust.layers.entries) {
            expect(android.layers[layer.key]!.isVisible, layer.value.isVisible);
            expect(android.layers[layer.key]!.isFrozen, layer.value.isFrozen);
          }
        }
        final cached = await DwgConverterService.convertDwgToDxf(input.path);
        expect(cached, path);
      },
      skip: !enabled || !Platform.isWindows || !fixture.existsSync(),
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
