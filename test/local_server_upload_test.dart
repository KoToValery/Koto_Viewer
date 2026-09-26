import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/services/local_server_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  group('LocalServerService Upload & Receive Tests', () {
    tearDown(() async {
      await LocalServerService.stopServer();
    });

    test('getUploadDirectory returns an existing directory', () async {
      final dir = await LocalServerService.getUploadDirectory();
      expect(dir.existsSync(), isTrue);
    });

    test('startReceiveServer starts in receive mode and handles streamed upload', () async {
      final url = await LocalServerService.startReceiveServer(
        shutdownTimeout: const Duration(minutes: 5),
      );

      // In environments with no active Wi-Fi, URL might be null
      if (url == null) {
        expect(LocalServerService.isRunning, isFalse);
        return;
      }

      expect(LocalServerService.isRunning, isTrue);
      expect(LocalServerService.isReceiveMode, isTrue);

      final completer = Completer<File>();
      final sub = LocalServerService.onFileReceived.listen((file) {
        if (!completer.isCompleted) {
          completer.complete(file);
        }
      });

      // Prepare simulated 1 MB presentation zip payload
      final fakeBytes = Uint8List(1024 * 1024);
      for (var i = 0; i < fakeBytes.length; i++) {
        fakeBytes[i] = i % 256;
      }

      final uploadUri = Uri.parse('$url/upload?filename=test_presentation.zip');
      final response = await http.post(
        uploadUri,
        body: fakeBytes,
        headers: {
          'Content-Type': 'application/octet-stream',
          'X-File-Name': 'test_presentation.zip',
        },
      );

      expect(response.statusCode, 200);

      final receivedFile = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(receivedFile.existsSync(), isTrue);
      expect(receivedFile.lengthSync(), fakeBytes.length);
      expect(receivedFile.path.endsWith('.zip'), isTrue);

      // Clean up test file
      if (receivedFile.existsSync()) {
        await receivedFile.delete();
      }

      await sub.cancel();
      await LocalServerService.stopServer();
      expect(LocalServerService.isRunning, isFalse);
    });
  });
}
