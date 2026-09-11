import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/file_opener_service.dart';
import 'package:kotoview/src/core/services/recent_files_service.dart';

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
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('file_opener_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('FileOpenerService Tests', () {
    testWidgets('Non-existent file returns false, shows SnackBar, and cleans recent files',
        (WidgetTester tester) async {
      final nonExistentPath = '${tempDir.path}/ghost.pdf';
      await RecentFilesService.addRecentFile(
        PdfItem(
          path: nonExistentPath,
          name: 'ghost.pdf',
          sizeInBytes: 123,
          lastOpened: DateTime.now(),
        ),
      );

      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      bool? result;
      await tester.runAsync(() async {
        result = await FileOpenerService.openFile(
          context: tester.element(find.byType(SizedBox)),
          filePath: nonExistentPath,
        );
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isFalse);
      expect(find.text('File does not exist.'), findsOneWidget);

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent.any((f) => f.path == nonExistentPath), isFalse);

      messengerKey.currentState?.clearSnackBars();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Unsupported file format returns false and displays warning SnackBar',
        (WidgetTester tester) async {
      final unsupportedFile = File('${tempDir.path}/test.unknown_format');
      unsupportedFile.writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);

      await RecentFilesService.addRecentFile(
        PdfItem(
          path: unsupportedFile.path,
          name: 'test.unknown_format',
          sizeInBytes: 4,
          lastOpened: DateTime.now(),
        ),
      );

      final messengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );

      bool? result;
      await tester.runAsync(() async {
        result = await FileOpenerService.openFile(
          context: tester.element(find.byType(SizedBox)),
          filePath: unsupportedFile.path,
        );
      });

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isFalse);
      expect(find.text('Unsupported file format: test.unknown_format'), findsOneWidget);

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent.any((f) => f.path == unsupportedFile.path), isFalse);

      messengerKey.currentState?.clearSnackBars();
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
