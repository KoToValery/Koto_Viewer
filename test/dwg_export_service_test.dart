import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/acadrust_converter_service.dart';
import 'package:kotoview/src/core/services/dwg_export_service.dart';

Uint8List _dwg() => Uint8List(128)..setRange(0, 6, 'AC1032'.codeUnits);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = AcadrustConverterService.androidChannel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'Android passes publication bytes to the isolated writer and returns DWG',
    () async {
      final input = Uint8List(2 * 1024 * 1024);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'writeDwg');
        expect(call.arguments['dxfBytes'], input);
        expect(call.arguments['jobId'], isNotEmpty);
        expect((call.arguments as Map).containsKey('inputPath'), isFalse);
        return _dwg();
      });
      expect(await DwgExportService.encodeAndroid(input), _dwg());
    },
  );

  test('a renamed DXF cannot be published as a DWG', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => Uint8List.fromList('0\nSECTION\n${'DXF' * 40}'.codeUnits),
    );
    await expectLater(
      DwgExportService.encodeAndroid(Uint8List(1)),
      throwsFormatException,
    );
  });

  test('native writer failures retain their cause', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'DWG_WRITE_FAILED',
        details: {'nativeMessage': 'Unsupported CAD geometry'},
      );
    });
    await expectLater(
      DwgExportService.encodeAndroid(Uint8List(1)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'cause',
          contains('Unsupported CAD geometry'),
        ),
      ),
    );
  });

  test(
    'cancelling exports cancels the native job rather than publishing bytes',
    () async {
      final native = Completer<Uint8List>();
      var cancelled = false;
      String? job;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'writeDwg') {
          job = call.arguments['jobId'];
          cancelled = true;
          return native.future;
        }
        expect(call.method, 'cancelDwgExport');
        expect(call.arguments['jobId'], job);
        native.completeError(PlatformException(code: 'DWG_EXPORT_CANCELLED'));
        return null;
      });
      await expectLater(
        DwgExportService.encodeAndroid(
          Uint8List(1),
          isCancelled: () => cancelled,
        ),
        throwsA(isA<DwgExportCancelled>()),
      );
    },
  );
}
