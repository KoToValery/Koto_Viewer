import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kotoview/src/features/text_viewer/models/text_reflow_models.dart';
import 'package:kotoview/src/features/text_viewer/parser/text_reflow_parser.dart';
import 'package:kotoview/src/features/text_viewer/parser/text_reflow_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Text Reflow Models & Settings Tests', () {
    test('Default settings initialize with expected values', () {
      const settings = TextReflowSettings();
      expect(settings.fontSize, 17.0);
      expect(settings.lineHeight, 1.6);
      expect(settings.theme, TextReflowTheme.sepia);
      expect(settings.font, TextReflowFont.serif);
      expect(settings.mode, TextReflowMode.paginated);
      expect(settings.textAlign, TextAlign.left);
    });

    test('copyWith updates settings correctly', () {
      const settings = TextReflowSettings();
      final updated = settings.copyWith(
        fontSize: 21.0,
        theme: TextReflowTheme.dark,
        font: TextReflowFont.sans,
        mode: TextReflowMode.continuous,
        textAlign: TextAlign.justify,
      );

      expect(updated.fontSize, 21.0);
      expect(updated.theme, TextReflowTheme.dark);
      expect(updated.font, TextReflowFont.sans);
      expect(updated.mode, TextReflowMode.continuous);
      expect(updated.textAlign, TextAlign.justify);
      // Unchanged
      expect(updated.lineHeight, 1.6);
      expect(updated.horizontalPadding, 20.0);
    });

    test('Theme extensions return appropriate colors and labels', () {
      expect(TextReflowTheme.light.label, 'Light Paper');
      expect(TextReflowTheme.sepia.label, 'Warm Sepia');
      expect(TextReflowTheme.dark.label, 'Dark Charcoal');
      expect(TextReflowTheme.amoled.label, 'Pure Black');

      expect(TextReflowTheme.sepia.backgroundColor, const Color(0xFFF4ECD8));
      expect(TextReflowTheme.amoled.backgroundColor, const Color(0xFF000000));
      expect(TextReflowTheme.light.textColor, const Color(0xFF262626));
      expect(TextReflowTheme.dark.textColor, const Color(0xFFE2E8F0));
    });

    test('Font extension produces valid TextStyle for Latin and Cyrillic', () {
      for (final font in TextReflowFont.values) {
        final style = font.getTextStyle(
          fontSize: 18.0,
          color: Colors.black,
          height: 1.5,
        );
        expect(style.fontSize, isNotNull);
        expect(style.color, Colors.black);
      }
    });
  });

  group('TextReflowParser Tests', () {
    test('Parses empty text cleanly', () {
      final chapters = TextReflowParser.parse('');
      expect(chapters.length, 1);
      expect(chapters.first.blocks, isEmpty);
    });

    test('Unwraps hard-wrapped lines inside paragraphs', () {
      const rawText = '''
Това беше прекрасна утрин в планината, когато
слънцето бавно се издигаше над върховете. Всичко наоколо
беше тихо и спокойно.

След малко обаче се чу шум откъм гората.
''';

      final chapters = TextReflowParser.parse(rawText);
      expect(chapters.length, 1);
      expect(chapters.first.blocks.length, 2);

      expect(
        chapters.first.blocks[0].text,
        'Това беше прекрасна утрин в планината, когато слънцето бавно се издигаше над върховете. Всичко наоколо беше тихо и спокойно.',
      );
      expect(
        chapters.first.blocks[1].text,
        'След малко обаче се чу шум откъм гората.',
      );
    });

    test('Handles hyphenated line wrapping correctly', () {
      const rawText = '''
Това е изключител-
но интересна книга.
''';

      final chapters = TextReflowParser.parse(rawText);
      expect(chapters.first.blocks.length, 1);
      expect(chapters.first.blocks[0].text, 'Това е изключително интересна книга.');
    });

    test('Preserves dialogue dashes on new lines', () {
      const rawText = '''
Той погледна към нея и попита:
— Къде отиваш толкова рано?
— В библиотеката — отвърна тя с усмивка.
''';

      final chapters = TextReflowParser.parse(rawText);
      expect(chapters.first.blocks.length, 3);
      expect(chapters.first.blocks[1].text.startsWith('— Къде'), isTrue);
      expect(chapters.first.blocks[2].text.startsWith('— В библиотеката'), isTrue);
    });

    test('Detects Cyrillic and Latin chapter headings', () {
      const rawBook = '''
ГЛАВА ПЪРВА
Началото на приключението започна тук.

Глава 2: Пътят напред
Те вървяха цял ден през гората.

Chapter 3
The final destination was reached.
''';

      final chapters = TextReflowParser.parse(rawBook);
      expect(chapters.length, 3);
      expect(chapters[0].title.contains('ГЛАВА ПЪРВА'), isTrue);
      expect(chapters[1].title.contains('Глава 2'), isTrue);
      expect(chapters[2].title.contains('Chapter 3'), isTrue);
    });

    test('Detects markdown headings and divider stars', () {
      const raw = '''
# Първа глава
Текст на първа глава.

* * *

Втори параграф след разделител.
''';

      final chapters = TextReflowParser.parse(raw);
      expect(chapters.length, 1);
      expect(chapters[0].title, 'Първа глава');
      expect(chapters[0].blocks.any((b) => b.type == TextReflowBlockType.divider), isTrue);
    });
  });

  group('TextReflowPaginator Tests', () {
    test('Paginates empty or single-block chapter cleanly', () {
      const emptyChapter = TextReflowChapter(
        index: 0,
        title: 'Empty',
        rawText: '',
        blocks: [],
        wordCount: 0,
      );

      final emptyPages = TextReflowPaginator.paginateChapter(
        chapter: emptyChapter,
        viewportSize: const Size(400, 600),
        settings: const TextReflowSettings(),
        textColor: Colors.black,
      );
      expect(emptyPages.length, 1);
      expect(emptyPages[0].blocks, isEmpty);

      const singleBlockChapter = TextReflowChapter(
        index: 1,
        title: 'Intro',
        rawText: 'Intro text here.',
        blocks: [
          TextReflowBlock(type: TextReflowBlockType.paragraph, text: 'Intro text here.'),
        ],
        wordCount: 3,
      );

      final pages = TextReflowPaginator.paginateChapter(
        chapter: singleBlockChapter,
        viewportSize: const Size(400, 600),
        settings: const TextReflowSettings(),
        textColor: Colors.black,
      );
      expect(pages.length, 1);
      expect(pages[0].blocks.length, 1);
    });

    test('Paginates multi-paragraph text across multiple mini-pages', () {
      final paragraphs = List.generate(
        35,
        (i) => TextReflowBlock(
          type: TextReflowBlockType.paragraph,
          text: 'Параграф $i: ${'Това е примерен текст за тестване на пагинацията на книги на кирилица. ' * 4}',
        ),
      );

      final chapter = TextReflowChapter(
        index: 0,
        title: 'Глава 1',
        rawText: paragraphs.map((p) => p.text).join('\n\n'),
        blocks: paragraphs,
        wordCount: 1200,
      );

      final pages = TextReflowPaginator.paginateChapter(
        chapter: chapter,
        viewportSize: const Size(360, 600),
        settings: const TextReflowSettings(fontSize: 18.0),
        textColor: Colors.black,
      );

      expect(pages.length, greaterThan(3));
      for (final p in pages) {
        expect(p.blocks.isNotEmpty, isTrue);
        expect(p.chapterTitle, 'Глава 1');
      }
    });

    test('paginateChapterWithAnchor preserves reading position anchor', () {
      final paragraphs = List.generate(
        25,
        (i) => TextReflowBlock(
          type: TextReflowBlockType.paragraph,
          text: 'Paragraph $i: Text content for testing anchor stability across screen resizes and rotations.',
        ),
      );

      final chapter = TextReflowChapter(
        index: 0,
        title: 'Anchor Chapter',
        rawText: paragraphs.map((p) => p.text).join('\n\n'),
        blocks: paragraphs,
        wordCount: 500,
      );

      const normalViewport = Size(360, 500);
      const fsViewport = Size(360, 750);
      const settings = TextReflowSettings(fontSize: 16.0);

      final normalResult = TextReflowPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: normalViewport,
        settings: settings,
        textColor: Colors.black,
      );

      // Reader is on page 2
      final curPage = normalResult.pages[2];
      final anchorBlock = curPage.startBlockIndex;
      final anchorChar = curPage.startCharOffset;

      final fsResult = TextReflowPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: fsViewport,
        settings: settings,
        textColor: Colors.black,
        anchorBlockIndex: anchorBlock,
        anchorCharOffset: anchorChar,
      );

      final fsPage = fsResult.pages[fsResult.anchorPageIndex];
      expect(fsPage.startBlockIndex, anchorBlock);
      expect(fsPage.startCharOffset, anchorChar);
    });
  });
}
