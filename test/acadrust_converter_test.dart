import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/features/dxf_viewer/binary/kcad_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late File input;
  late File output;
  late PathProviderPlatform previousPathProvider;
  final completeDxf =
      '999\n${'comment ' * 20}\n'
      '0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('koto_acadrust_test_');
    final unicode = await Directory(
      '${temp.path}/Чертежи с интервали',
    ).create();
    input = await File('${unicode.path}/етаж.dwg').writeAsString('source');
    output = File('${temp.path}/cached.dxf');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await temp.delete(recursive: true);
  });

  test(
    'passes Unicode paths as arguments and publishes a complete result',
    () async {
      expect(
        await AcadrustConverterService.convert(
          executable: 'converter.exe',
          input: input,
          output: output,
          processRunner: (executable, arguments) async {
            expect(arguments.first, input.absolute.path);
            expect(arguments.last, isNot(output.path));
            await File(arguments.last).writeAsString(completeDxf);
            return ProcessResult(1, 0, '', '');
          },
        ),
        isTrue,
      );
      expect(await output.readAsString(), completeDxf);
      expect(await input.readAsString(), 'source');
      expect(temp.listSync().whereType<Directory>().length, 1);
    },
  );

  for (final failure in ['nonzero', 'truncated', 'missing', 'timeout']) {
    test(
      '$failure leaves the previous cache intact and cleans staged files',
      () async {
        await output.writeAsString('previous cache');
        expect(
          await AcadrustConverterService.convert(
            executable: 'converter.exe',
            input: input,
            output: output,
            processRunner: (_, arguments) async {
              if (failure == 'timeout') throw TimeoutException('test');
              if (failure != 'missing') {
                await File(arguments.last).writeAsString(
                  failure == 'truncated'
                      ? '0\nSECTION\n${'x' * 200}'
                      : completeDxf,
                );
              }
              return ProcessResult(
                1,
                failure == 'nonzero' ? 1 : 0,
                '',
                'failed',
              );
            },
          ),
          isFalse,
        );
        expect(await output.readAsString(), 'previous cache');
        expect(temp.listSync().whereType<Directory>().length, 1);
      },
    );
  }

  test('unavailable executable fails cleanly', () async {
    expect(
      await AcadrustConverterService.convert(
        executable: '${temp.path}/missing.exe',
        input: input,
        output: output,
      ),
      isFalse,
    );
    expect(await output.exists(), isFalse);
  });

  test(
    'accepts padded DXF group codes and CRLF from the native writer',
    () async {
      await output.writeAsString(
        completeDxf.replaceAll('0\n', '  0\n').replaceAll('\n', '\r\n'),
      );
      expect(await AcadrustConverterService.isCompleteDxf(output), isTrue);
    },
  );

  test(
    'KCAD caches distinguish engines and keep preferred instant-open key',
    () async {
      final hash = 'a' * 64;
      final legacy = File('${temp.path}/${hash}_v6.dxf');
      final rust = File('${temp.path}/${hash}_v7.dxf');
      final legacyKey = await KcadService.getCachePath(
        legacy,
        originalFile: input,
      );
      final rustKey = await KcadService.getCachePath(rust, originalFile: input);
      final preferredKey = await KcadService.getCachePath(input);
      expect(legacyKey, contains('_c6_'));
      expect(rustKey, contains('_c7_'));
      expect(legacyKey, isNot(rustKey));
      expect(
        preferredKey,
        DwgConverterService.cacheVersion == 7 ? rustKey : legacyKey,
      );
    },
  );

  test(
    'clearCacheForFile removes both backend revisions and companion KCAD',
    () async {
      final hash = (await sha256.bind(input.openRead()).first).toString();
      final cache = await Directory('${temp.path}/dwg_cache').create();
      final names = ['${hash}_v6.dxf', '${hash}_v7.dxf', '${hash}_c7_v2.kcad'];
      for (final name in [...names, 'unrelated_v7.dxf']) {
        await File('${cache.path}/$name').writeAsString('cache');
      }
      await DwgConverterService.clearCacheForFile(input.path);
      for (final name in names) {
        expect(await File('${cache.path}/$name').exists(), isFalse);
      }
      expect(await File('${cache.path}/unrelated_v7.dxf').exists(), isTrue);
    },
  );
}
