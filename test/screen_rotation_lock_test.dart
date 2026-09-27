import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/comic_viewer/comic_viewer_screen.dart';
import 'package:kotoview/src/features/text_viewer/text_viewer_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Uint8List createDummyPng() {
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
  }

  String createTestComic(Directory tempDir) {
    final filePath = '${tempDir.path}/test_comic.cbz';
    final dummyPng = createDummyPng();
    final archive = Archive();
    archive.addFile(ArchiveFile('p01.png', dummyPng.length, dummyPng));
    archive.addFile(ArchiveFile('p02.png', dummyPng.length, dummyPng));
    final zipBytes = ZipEncoder().encode(archive)!;
    File(filePath).writeAsBytesSync(zipBytes);
    return filePath;
  }

  group('Screen Rotation Lock & Fullscreen Localization Tests', () {
    test('English localizations provide expected labels', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.fullscreen, equals('Fullscreen'));
      expect(l10n.exitFullscreen, equals('Exit Fullscreen'));
      expect(l10n.lockRotation, equals('Lock Rotation'));
      expect(l10n.unlockRotation, equals('Unlock Rotation'));
      expect(l10n.rotationLocked, equals('Screen rotation locked'));
      expect(l10n.rotationUnlocked, equals('Auto-rotation restored'));
    });

    test('Bulgarian localizations provide expected labels', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('bg'));
      expect(l10n.fullscreen, equals('Цял екран'));
      expect(l10n.exitFullscreen, equals('Изход от цял екран'));
      expect(l10n.lockRotation, equals('Заключване на завъртането'));
      expect(l10n.unlockRotation, equals('Отключване на завъртането'));
      expect(l10n.rotationLocked, equals('Завъртането на екрана е заключено'));
      expect(l10n.rotationUnlocked, equals('Автоматичното завъртане е възстановено'));
    });
  });

  group('ComicViewerScreen Fullscreen & Rotation Lock Tests', () {
    testWidgets('Toggles fullscreen and controls rotation lock in fullscreen mode', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('comic_rotation_test');
      final filePath = createTestComic(tempDir);

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ComicViewerScreen(filePath: filePath),
          ),
        );

        // Wait until comic loads
        for (int i = 0; i < 40; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
          if (find.byIcon(Icons.fullscreen).evaluate().isNotEmpty) {
            break;
          }
        }

        // Verify the Fullscreen button is visible in the command bar
        final fullscreenBtn = find.byTooltip('Fullscreen');
        expect(fullscreenBtn, findsOneWidget);

        // Before entering fullscreen: floating exit fullscreen and rotation lock buttons should NOT be present
        expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
        expect(find.byIcon(Icons.screen_rotation), findsNothing);
        expect(find.byIcon(Icons.screen_lock_rotation), findsNothing);

        // Enter fullscreen via toolbar button
        await tester.tap(fullscreenBtn);
        await tester.pumpAndSettle();

        // Now in fullscreen: Exit Fullscreen button and Screen Rotation button are visible!
        expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);

        // Tap rotation lock button to lock rotation
        final lockRotationBtn = find.byTooltip('Lock Rotation');
        expect(lockRotationBtn, findsOneWidget);
        await tester.tap(lockRotationBtn);
        await tester.pump();

        // Icon should switch to screen_lock_rotation and tooltip to Unlock Rotation
        expect(find.byIcon(Icons.screen_lock_rotation), findsOneWidget);
        expect(find.byTooltip('Unlock Rotation'), findsOneWidget);
        expect(find.text('Screen rotation locked'), findsOneWidget);

        // Tap again to unlock rotation
        await tester.tap(find.byTooltip('Unlock Rotation'));
        await tester.pump();

        // Icon should switch back to screen_rotation
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
        expect(find.byTooltip('Lock Rotation'), findsOneWidget);
        expect(find.text('Auto-rotation restored'), findsOneWidget);

        // Tap Exit Fullscreen button
        final exitFullscreenBtn = find.byTooltip('Exit Fullscreen');
        expect(exitFullscreenBtn, findsOneWidget);
        await tester.tap(exitFullscreenBtn);
        await tester.pumpAndSettle();

        // Should return to normal view with command bar
        expect(find.byTooltip('Fullscreen'), findsOneWidget);
        expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
        expect(find.byIcon(Icons.screen_rotation), findsNothing);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('TextViewerScreen rotation lock in fullscreen mode', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tempDir = Directory.systemTemp.createTempSync('text_rotation_test');
      final textFile = File('${tempDir.path}/sample.txt');
      textFile.writeAsStringSync('Line 1: Hello World\nLine 2: Reader mode testing\nLine 3: Orientation test\n');

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TextViewerScreen(filePath: textFile.path),
          ),
        );

        // Wait until text loads
        for (int i = 0; i < 40; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
          if (find.textContaining('Hello World').evaluate().isNotEmpty) {
            break;
          }
        }

        final fullscreenBtn = find.byTooltip('Fullscreen');
        expect(fullscreenBtn, findsOneWidget);

        // Ensure visible in horizontal scroll and enter fullscreen
        await tester.ensureVisible(fullscreenBtn);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(fullscreenBtn);
        await tester.pump(const Duration(milliseconds: 200));

        // Verify rotation lock & exit buttons are visible
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);
        expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

        // Lock rotation
        await tester.tap(find.byTooltip('Lock Rotation'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.screen_lock_rotation), findsOneWidget);

        // Unlock rotation
        await tester.tap(find.byTooltip('Unlock Rotation'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.screen_rotation), findsOneWidget);

        // Exit fullscreen
        await tester.tap(find.byTooltip('Exit Fullscreen'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
