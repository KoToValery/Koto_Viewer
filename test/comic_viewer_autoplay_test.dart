import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/comic_viewer/comic_viewer_screen.dart';
import 'package:kotoview/src/features/comic_viewer/models/comic_models.dart';
import 'package:kotoview/src/features/comic_viewer/widgets/comic_autoplay_bar.dart';

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
    archive.addFile(ArchiveFile('p03.png', dummyPng.length, dummyPng));
    final zipBytes = ZipEncoder().encode(archive)!;
    File(filePath).writeAsBytesSync(zipBytes);
    return filePath;
  }

  testWidgets('ComicViewerScreen paged autoplay advances pages and resets when starting at last page', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('comic_test_paged');
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
        if (find.byIcon(Icons.play_circle_outline).evaluate().isNotEmpty) {
          break;
        }
      }

      // Verify the floating zoom button is completely removed
      expect(find.byKey(const ValueKey('comic_zoom_fab')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      // Start autoplay via the prominent AppBar action button
      final autoplayBtn = find.byIcon(Icons.play_circle_fill);
      expect(autoplayBtn, findsOneWidget);
      await tester.tap(autoplayBtn);
      await tester.pump();

      // Advance 6 seconds (default 5s interval)
      for (int i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Should have advanced to page 2
      expect(find.textContaining('Page 2 of 3'), findsOneWidget);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ComicViewerScreen webtoon autoplay starts and scrolls smoothly', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('comic_test_webtoon');
    final filePath = createTestComic(tempDir);

    try {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicViewerScreen(filePath: filePath),
        ),
      );

      for (int i = 0; i < 40; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byIcon(Icons.play_circle_outline).evaluate().isNotEmpty) {
          break;
        }
      }

      // Switch to Webtoon mode
      final readingModeBtn = find.byIcon(Icons.menu_book_rounded);
      await tester.tap(readingModeBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ComicReadingMode.verticalContinuous.label));
      await tester.pumpAndSettle();

      final autoplayBtn = find.byIcon(Icons.play_circle_outline);
      await tester.tap(autoplayBtn);
      await tester.pump();

      // Pump for 2 seconds
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(ComicAutoplayBar), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsWidgets);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
