import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = AcadrustConverterService.androidChannel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temp;
  late File input;
  late File output;
  final completeDxf =
      '999\n${'comment ' * 20}\n0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('android_acadrust_test_');
    input = await File('${temp.path}/Чертеж 🏠.dwg').writeAsString('DWG');
    output = File('${temp.path}/cache.dxf');
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  test(
    'requests Rust only in the isolated service and publishes staged DXF',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'convertDwg');
        final arguments = call.arguments as Map;
        expect(arguments['backend'], 'acadrust');
        expect(arguments['inputPath'], input.absolute.path);
        expect(arguments['outputPath'], isNot(output.path));
        await File(
          arguments['outputPath'] as String,
        ).writeAsString(completeDxf);
        return 0;
      });
      expect(
        await AcadrustConverterService.convertAndroid(
          input: input,
          output: output,
        ),
        isTrue,
      );
      expect(await output.readAsString(), completeDxf);
      expect(temp.listSync().whereType<Directory>(), isEmpty);
    },
  );

  for (final result in [-97, -3, 0]) {
    test(
      'unavailable, failed or truncated JNI output preserves cache ($result)',
      () async {
        await output.writeAsString('previous cache');
        messenger.setMockMethodCallHandler(channel, (call) async {
          await File(
            (call.arguments as Map)['outputPath'] as String,
          ).writeAsString('partial');
          return result;
        });
        expect(
          await AcadrustConverterService.convertAndroid(
            input: input,
            output: output,
          ),
          isFalse,
        );
        expect(await output.readAsString(), 'previous cache');
        expect(temp.listSync().whereType<Directory>(), isEmpty);
      },
    );
  }

  for (final code in ['OOM_KILLED', 'CONVERSION_TIMEOUT', 'BIND_FAILED']) {
    test(
      'preserves $code for the coordinator and removes staged files',
      () async {
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: code);
        });
        await expectLater(
          AcadrustConverterService.convertAndroid(input: input, output: output),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              code,
            ),
          ),
        );
        expect(await output.exists(), isFalse);
        expect(temp.listSync().whereType<Directory>(), isEmpty);
      },
    );
  }
}
