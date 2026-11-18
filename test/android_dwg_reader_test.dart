import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';
import 'package:kotoview/src/core/services/dwg_reader_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = AcadrustConverterService.androidChannel;
  const source = '/data/user/0/com.koto.kotoviewer/cache/+-0,00 Worksheet.dwg';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'reads original Android DWG object stream without conversion requests',
    () async {
      final calls = <MethodCall>[];
      final bytes = Uint8List.fromList([123, 125]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return bytes;
      });
      expect(await DwgReaderService.readAndroidObjectStream(source), bytes);
      expect(calls.single.method, 'readDwg');
      expect(calls.single.arguments, {'inputPath': source});
    },
  );

  for (final failure in {
    'DWG_READER_UNAVAILABLE': (-97, 'dlopen failed: library missing'),
    'DWG_JNI_FAILED': (-99, 'No implementation found for native method'),
    'DWG_DECODE_FAILED': (-3, 'Permission denied (os error 13)'),
  }.entries) {
    test(
      'retains ${failure.key} native status and cause for phone logs',
      () async {
        var requests = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          requests++;
          throw PlatformException(
            code: failure.key,
            details: {
              'nativeStatus': failure.value.$1,
              'nativeMessage': failure.value.$2,
            },
          );
        });
        await expectLater(
          DwgReaderService.readAndroidObjectStream(source),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'message', contains(failure.key))
                .having(
                  (e) => e.toString(),
                  'logged status',
                  contains('${failure.value.$1}'),
                )
                .having(
                  (e) => e.toString(),
                  'logged cause',
                  contains(failure.value.$2),
                ),
          ),
        );
        expect(
          requests,
          1,
          reason: 'A native failure must not start a DXF fallback',
        );
      },
    );
  }

  test(
    'preserves platform initialization failures before the worker starts',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'DWG_READ_FAILED',
          message: 'Too many open files',
        );
      });
      await expectLater(
        DwgReaderService.readAndroidObjectStream(source),
        throwsA(
          isA<FormatException>().having(
            (e) => e.toString(),
            'platform cause',
            contains('Too many open files'),
          ),
        ),
      );
    },
  );

  test('preserves isolated worker memory errors', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'OOM_KILLED');
    });
    await expectLater(
      DwgReaderService.readAndroidObjectStream(source),
      throwsA(isA<DwgMemoryLimitException>()),
    );
  });
}
