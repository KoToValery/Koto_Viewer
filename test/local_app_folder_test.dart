import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:kotoview/src/core/services/file_source_service.dart';
import 'package:kotoview/src/core/services/local_server_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;

  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('koto_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Local App Folder & FileSourceMode tests', () {
    test('FileSourceMode.localFolder can be saved and retrieved', () async {
      await FileSourceService.setSourceMode(FileSourceMode.localFolder);
      final mode = await FileSourceService.getSourceMode();
      expect(mode, equals(FileSourceMode.localFolder));
      expect(mode.key, equals('localFolder'));
      expect(mode.label, equals('Uploaded Files'));
    });

    test('LocalServerService and FileSourceService use the same dedicated app upload folder', () async {
      final uploadDir = await LocalServerService.getUploadDirectory();
      final localAppDir = await FileSourceService.getLocalAppDirectory();

      expect(uploadDir.path, equals(localAppDir.path));
      expect(uploadDir.existsSync(), isTrue);
      expect(uploadDir.path, contains('KoToViewer'));
      expect(uploadDir.path, contains('Uploads'));
    });

    test('getPdfFilesForCurrentSource in localFolder mode lists files from the local directory', () async {
      await FileSourceService.setSourceMode(FileSourceMode.localFolder);
      final uploadDir = await FileSourceService.getLocalAppDirectory();

      // Create a test file in uploadDir
      final testFile = File('${uploadDir.path}${Platform.pathSeparator}test_drawing.dxf');
      testFile.writeAsStringSync('0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF');

      final files = await FileSourceService.getPdfFilesForCurrentSource();
      expect(files.length, equals(1));
      expect(files.first.name, equals('test_drawing.dxf'));
      expect(files.first.path, equals(testFile.path));
    });
  });
}
