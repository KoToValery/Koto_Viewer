import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/comic_viewer/models/comic_models.dart';
import 'package:kotoview/src/features/comic_viewer/parser/comic_parser.dart';
import 'package:kotoview/src/features/comic_viewer/widgets/comic_autoplay_bar.dart';
import 'package:kotoview/src/features/comic_viewer/widgets/comic_page_item.dart';

void main() {
  group('Comic Book Model & File Identification Tests', () {
    test('PdfItem correctly identifies .cbz, .cbr, and .cbt files', () {
      final cbzItem = PdfItem(
        path: '/storage/comics/Batman_Issue_01.cbz',
        name: 'Batman_Issue_01.cbz',
        sizeInBytes: 1024 * 1024,
        lastOpened: DateTime.now(),
      );
      expect(cbzItem.fileType, equals(KotoFileType.cbz));
      expect(cbzItem.isComic, isTrue);
      expect(cbzItem.category, equals(FileCategory.documents));

      final cbrItem = PdfItem(
        path: '/storage/comics/SpiderMan.CBR',
        name: 'SpiderMan.CBR',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );
      expect(cbrItem.fileType, equals(KotoFileType.cbr));
      expect(cbrItem.isComic, isTrue);

      final cbtItem = PdfItem(
        path: '/storage/comics/OnePiece.cbt',
        name: 'OnePiece.cbt',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );
      expect(cbtItem.fileType, equals(KotoFileType.cbt));
      expect(cbtItem.isComic, isTrue);
    });

    test('ComicReadingMode labels and shortLabels', () {
      expect(ComicReadingMode.leftToRight.shortLabel, equals('LTR'));
      expect(ComicReadingMode.rightToLeft.shortLabel, equals('Manga'));
      expect(ComicReadingMode.verticalContinuous.shortLabel, equals('Webtoon'));
    });
  });

  group('ComicParser Archive & Metadata Tests', () {
    test('Parses CBZ archive with natural page ordering and skips hidden files', () {
      final archive = Archive();

      // Add dummy files out of order
      final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      archive.addFile(ArchiveFile('page_10.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_2.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_1.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('__MACOSX/._page_1.png', 4, [0, 0, 0, 0]));
      archive.addFile(ArchiveFile('.DS_Store', 4, [0, 0, 0, 0]));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final comic = ComicParser.parseFromBytes(
        zipBytes,
        fileName: 'Hero_Adventures_01.cbz',
        filePath: '/test/Hero_Adventures_01.cbz',
      );

      expect(comic.title, equals('Hero Adventures 01'));
      expect(comic.pageCount, equals(3));
      expect(comic.pages[0].fileName, equals('page_1.png'));
      expect(comic.pages[1].fileName, equals('page_2.png'));
      expect(comic.pages[2].fileName, equals('page_10.png'));
    });

    test('Parses ComicInfo.xml metadata correctly including Manga mode flag', () {
      final archive = Archive();

      const comicInfoXml = '''<?xml version="1.0"?>
<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>The Final Battle</Title>
  <Series>Cyber Samurai</Series>
  <Number>42</Number>
  <Summary>The heroes confront the cyber dragon in Neo Tokyo.</Summary>
  <Writer>Stan Lee</Writer>
  <Penciller>Jack Kirby</Penciller>
  <Genre>Sci-Fi / Action</Genre>
  <Year>2026</Year>
  <Month>8</Month>
  <Publisher>Koto Comics</Publisher>
  <Manga>YesAndRightToLeft</Manga>
</ComicInfo>''';

      final dummyJpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      archive.addFile(ArchiveFile('ComicInfo.xml', utf8.encode(comicInfoXml).length, utf8.encode(comicInfoXml)));
      archive.addFile(ArchiveFile('001.jpg', dummyJpg.length, dummyJpg));
      archive.addFile(ArchiveFile('002.jpg', dummyJpg.length, dummyJpg));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final comic = ComicParser.parseFromBytes(
        zipBytes,
        fileName: 'Cyber_Samurai_42.cbz',
        filePath: '/test/Cyber_Samurai_42.cbz',
      );

      expect(comic.title, equals('The Final Battle'));
      expect(comic.metadata.series, equals('Cyber Samurai'));
      expect(comic.metadata.number, equals('42'));
      expect(comic.metadata.writer, equals('Stan Lee'));
      expect(comic.metadata.penciller, equals('Jack Kirby'));
      expect(comic.metadata.year, equals(2026));
      expect(comic.metadata.month, equals(8));
      expect(comic.metadata.publisher, equals('Koto Comics'));
      expect(comic.metadata.isManga, isTrue);
      expect(comic.pageCount, equals(2));
    });

    test('ComicParser reports progressive extraction updates via onProgress callback', () {
      final archive = Archive();
      final dummyPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      archive.addFile(ArchiveFile('page_1.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_2.png', dummyPng.length, dummyPng));
      archive.addFile(ArchiveFile('page_3.png', dummyPng.length, dummyPng));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
      final List<ComicParseProgress> progressList = [];

      final comic = ComicParser.parseFromBytes(
        zipBytes,
        fileName: 'SpiderMan.cbz',
        filePath: '/test/SpiderMan.cbz',
        onProgress: (p) => progressList.add(p),
      );

      expect(comic.pageCount, equals(3));
      expect(progressList, isNotEmpty);
      expect(progressList.first.progress, greaterThanOrEqualTo(0.20));
      expect(progressList.last.progress, greaterThanOrEqualTo(0.95));
      expect(progressList.any((p) => p.currentPage == 1 && p.totalPages == 3), isTrue);
      expect(progressList.any((p) => p.currentPage == 3 && p.totalPages == 3), isTrue);
    });

    test('ComicParser throws descriptive exception when encountering RAR5 (.cbr) archive', () {
      // RAR5 magic signature: 52 61 72 21 1A 07 01 00
      final rar5Bytes = Uint8List.fromList([
        0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00, 0x00, 0x01, 0x02, 0x03,
      ]);

      expect(
        () => ComicParser.parseFromBytes(
          rar5Bytes,
          fileName: 'Manga_Volume1.cbr',
          filePath: '/test/Manga_Volume1.cbr',
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('RAR5') &&
              e.toString().contains('.cbz (ZIP)')),
        ),
      );
    });

    test('ComicParser throws descriptive exception when encountering legacy RAR archive', () {
      // Legacy RAR magic signature: 52 61 72 21 1A 07 00
      final rar4Bytes = Uint8List.fromList([
        0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00, 0x00, 0x01, 0x02,
      ]);

      expect(
        () => ComicParser.parseFromBytes(
          rar4Bytes,
          fileName: 'Batman.cbr',
          filePath: '/test/Batman.cbr',
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('RAR') &&
              e.toString().contains('.cbz (ZIP)')),
        ),
      );
    });
  });

  group('ComicFitMode & Zoom Best Practice Tests', () {
    test('ComicFitMode values, labels, and boxFits', () {
      expect(ComicFitMode.fitWidth.label, equals('Fit Width'));
      expect(ComicFitMode.fitWidth.boxFit, equals(BoxFit.fitWidth));

      expect(ComicFitMode.fitPage.label, equals('Fit Page'));
      expect(ComicFitMode.fitPage.boxFit, equals(BoxFit.contain));

      expect(ComicFitMode.fitHeight.label, equals('Fit Height'));
      expect(ComicFitMode.fitHeight.boxFit, equals(BoxFit.fitHeight));
    });
  });

  group('ComicPageItem Widget & Gesture Navigation Tests', () {
    final dummyPng = Uint8List.fromList([
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

    testWidgets('3-Zone Tap Navigation correctly detects Left, Center, and Right zones', (tester) async {
      int leftTaps = 0;
      int centerTaps = 0;
      int rightTaps = 0;

      final page = ComicPage(pageIndex: 0, fileName: 'p1.png', bytes: dummyPng);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ComicPageItem(
                page: page,
                onLeftTap: () => leftTaps++,
                onCenterTap: () => centerTaps++,
                onRightTap: () => rightTaps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Left zone (x = 100, which is 12.5% of 800 width, < 25%)
      await tester.tapAt(const Offset(100, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(0));
      expect(rightTaps, equals(0));

      // Tap on Right zone (x = 700, which is 87.5% of 800 width, > 75%)
      await tester.tapAt(const Offset(700, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(0));
      expect(rightTaps, equals(1));

      // Tap on Center zone (x = 400, which is 50% of 800 width)
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(leftTaps, equals(1));
      expect(centerTaps, equals(1));
      expect(rightTaps, equals(1));
    });

    testWidgets('Double-tap zooms in smoothly and subsequent double-tap resets zoom', (tester) async {
      double lastZoom = 1.0;
      ComicPageController? controller;

      final page = ComicPage(pageIndex: 0, fileName: 'p1.png', bytes: dummyPng);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ComicPageItem(
                page: page,
                onZoomChanged: (z) => lastZoom = z,
                onControllerCreated: (c) => controller = c,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller, isNotNull);
      expect(controller!.getScale(), equals(1.0));

      // Double-tap at center
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      // Zoom should now be > 1.05 (target 2.5)
      expect(lastZoom, greaterThan(1.5));
      expect(controller!.getScale(), greaterThan(1.5));

      // Double tap again to reset
      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();

      expect(lastZoom, closeTo(1.0, 0.05));
      expect(controller!.getScale(), closeTo(1.0, 0.05));
    });

    testWidgets('Programmatic zoomIn and resetZoom work via ComicPageController', (tester) async {
      ComicPageController? controller;

      final page = ComicPage(pageIndex: 0, fileName: 'p1.png', bytes: dummyPng);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ComicPageItem(
                page: page,
                onControllerCreated: (c) => controller = c,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller, isNotNull);

      // Programmatic zoom in (+0.5x)
      controller!.zoomIn();
      await tester.pumpAndSettle();
      expect(controller!.getScale(), closeTo(1.5, 0.05));

      // Reset zoom
      controller!.resetZoom();
      await tester.pumpAndSettle();
      expect(controller!.getScale(), closeTo(1.0, 0.05));
    });
  });

  group('ComicAutoplayConfig Tests', () {
    test('Default values are correct', () {
      const config = ComicAutoplayConfig();
      expect(config.intervalSeconds, equals(5.0));
      expect(config.webtoonScrollSpeed, equals(60.0));
      expect(config.loop, isFalse);
      expect(config.pauseOnZoom, isTrue);
    });

    test('copyWith updates properties properly', () {
      const config = ComicAutoplayConfig();
      final updated = config.copyWith(
        intervalSeconds: 8.0,
        webtoonScrollSpeed: 100.0,
        loop: true,
        pauseOnZoom: false,
      );
      expect(updated.intervalSeconds, equals(8.0));
      expect(updated.webtoonScrollSpeed, equals(100.0));
      expect(updated.loop, isTrue);
      expect(updated.pauseOnZoom, isFalse);
    });

    test('Serialization to/from JSON matches', () {
      const config = ComicAutoplayConfig(
        intervalSeconds: 10.0,
        webtoonScrollSpeed: 85.0,
        loop: true,
        pauseOnZoom: false,
      );
      final json = config.toJson();
      final deserialized = ComicAutoplayConfig.fromJson(json);
      expect(deserialized, equals(config));
      expect(deserialized.hashCode, equals(config.hashCode));
    });
  });

  group('ComicAutoplayBar Widget Tests', () {
    testWidgets('Renders Play/Pause buttons and triggers callbacks', (tester) async {
      bool playPauseToggled = false;
      bool previousTapped = false;
      bool nextTapped = false;
      bool loopToggled = false;
      bool settingsOpened = false;
      bool closed = false;
      double? updatedInterval;

      final progressNotifier = ValueNotifier<double>(0.4);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ComicAutoplayBar(
              isPlaying: true,
              isPaused: false,
              isPausedForZoom: false,
              isWebtoon: false,
              config: const ComicAutoplayConfig(intervalSeconds: 5.0),
              progressNotifier: progressNotifier,
              onTogglePlayPause: () => playPauseToggled = true,
              onPrevious: () => previousTapped = true,
              onNext: () => nextTapped = true,
              onToggleLoop: () => loopToggled = true,
              onIntervalChanged: (val) => updatedInterval = val,
              onScrollSpeedChanged: (_) {},
              onOpenSettings: () => settingsOpened = true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5s'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(playPauseToggled, isTrue);

      // Tap Skip Next
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(nextTapped, isTrue);

      // Tap Skip Previous
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(previousTapped, isTrue);

      // Tap Loop
      await tester.tap(find.byIcon(Icons.repeat_rounded));
      expect(loopToggled, isTrue);

      // Tap Settings
      await tester.tap(find.byIcon(Icons.tune_rounded));
      expect(settingsOpened, isTrue);

      // Tap Close
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);

      // Tap '+' to step interval
      await tester.tap(find.byIcon(Icons.add));
      expect(updatedInterval, equals(6.0));

      // Tap '-' to step interval
      await tester.tap(find.byIcon(Icons.remove));
      expect(updatedInterval, equals(4.0));
    });

    testWidgets('Shows Webtoon speed stepper and hides prev/next buttons in Webtoon mode', (tester) async {
      double? updatedSpeed;
      final progressNotifier = ValueNotifier<double>(0.0);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ComicAutoplayBar(
              isPlaying: true,
              isPaused: true,
              isPausedForZoom: false,
              isWebtoon: true,
              config: const ComicAutoplayConfig(webtoonScrollSpeed: 60.0),
              progressNotifier: progressNotifier,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onToggleLoop: () {},
              onIntervalChanged: (_) {},
              onScrollSpeedChanged: (val) => updatedSpeed = val,
              onOpenSettings: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('60 px/s'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      // Tap '+' to step speed
      await tester.tap(find.byIcon(Icons.add));
      expect(updatedSpeed, equals(70.0));
    });

    testWidgets('Shows zoom paused indicator when isPausedForZoom is true', (tester) async {
      final progressNotifier = ValueNotifier<double>(0.5);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ComicAutoplayBar(
              isPlaying: true,
              isPaused: false,
              isPausedForZoom: true,
              isWebtoon: false,
              config: const ComicAutoplayConfig(),
              progressNotifier: progressNotifier,
              onTogglePlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onToggleLoop: () {},
              onIntervalChanged: (_) {},
              onScrollSpeedChanged: (_) {},
              onOpenSettings: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.text('Paused (Zoomed)'), findsOneWidget);
    });
  });

  group('ComicAutoplaySettingsSheet Widget Tests', () {
    testWidgets('Adjusts page duration preset chip and toggles loop', (tester) async {
      ComicAutoplayConfig? updatedConfig;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ComicAutoplaySettingsSheet(
              initialConfig: const ComicAutoplayConfig(intervalSeconds: 5.0, loop: false),
              isWebtoon: false,
              onConfigChanged: (cfg) => updatedConfig = cfg,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Autoplay Settings'), findsOneWidget);
      expect(find.text('Page Duration'), findsOneWidget);
      expect(find.text('Loop from Beginning'), findsOneWidget);
      expect(find.text('Pause when Zoomed'), findsOneWidget);

      // Tap preset chip '8s'
      await tester.tap(find.text('8s'));
      await tester.pumpAndSettle();
      expect(updatedConfig?.intervalSeconds, equals(8.0));

      // Toggle Loop switch
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(updatedConfig?.loop, isTrue);
    });
  });

  group('Comic Autoplay Localization Tests', () {
    test('English localization contains all autoplay strings', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.comicAutoplay, equals('Autoplay'));
      expect(l10n.comicAutoplayStart, equals('Start Autoplay'));
      expect(l10n.comicAutoplayPause, equals('Pause Autoplay'));
      expect(l10n.comicAutoplayResume, equals('Resume Autoplay'));
      expect(l10n.comicAutoplayStop, equals('Stop Autoplay'));
      expect(l10n.comicAutoplaySettings, equals('Autoplay Settings'));
      expect(l10n.comicAutoplaySeconds(5), equals('5s'));
      expect(l10n.comicAutoplaySpeedPx(60), equals('60 px/s'));
      expect(l10n.comicAutoplayLoop, equals('Loop from Beginning'));
      expect(l10n.comicAutoplayPauseOnZoom, equals('Pause when Zoomed'));
      expect(l10n.comicAutoplayEndReached, equals('Reached the end of the comic.'));
      expect(l10n.comicAutoplayPausedForZoom, equals('Paused (Zoomed)'));
    });

    test('Bulgarian localization contains translated autoplay strings', () {
      final l10n = lookupAppLocalizations(const Locale('bg'));
      expect(l10n.comicAutoplay, equals('Автоматично прелистване'));
      expect(l10n.comicAutoplayStart, equals('Старт на автоматично прелистване'));
      expect(l10n.comicAutoplayPause, equals('Пауза на прелистването'));
      expect(l10n.comicAutoplayResume, equals('Възобнови прелистването'));
      expect(l10n.comicAutoplayStop, equals('Спри автоматичното прелистване'));
      expect(l10n.comicAutoplaySettings, equals('Настройки за автоматично прелистване'));
      expect(l10n.comicAutoplaySeconds(5), equals('5 сек.'));
      expect(l10n.comicAutoplaySpeedPx(60), equals('60 px/сек.'));
      expect(l10n.comicAutoplayLoop, equals('Повторение от началото'));
      expect(l10n.comicAutoplayPauseOnZoom, equals('Пауза при мащабиране'));
      expect(l10n.comicAutoplayEndReached, equals('Достигнат е краят на комикса.'));
      expect(l10n.comicAutoplayPausedForZoom, equals('Пауза (Мащабирано)'));
    });
  });
}

