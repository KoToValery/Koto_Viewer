import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/services/reading_progress_service.dart';
import 'package:kotoview/src/features/ebook_viewer/models/ebook_models.dart';
import 'package:kotoview/src/features/ebook_viewer/parser/ebook_paginator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingProgressService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and restores ReadingProgress with exact mini-page and block offset', () async {
      const filePath = '/storage/books/test_book.epub';

      await ReadingProgressService.saveProgress(
        filePath,
        page: 5,
        chapter: 2,
        miniPage: 3,
        blockIndex: 7,
        charOffset: 42,
        progressFraction: 0.35,
        scrollOffset: 120.5,
      );

      final loaded = await ReadingProgressService.getProgress(filePath);
      expect(loaded, isNotNull);
      expect(loaded!.page, equals(5));
      expect(loaded.chapter, equals(2));
      expect(loaded.miniPage, equals(3));
      expect(loaded.blockIndex, equals(7));
      expect(loaded.charOffset, equals(42));
      expect(loaded.progressFraction, closeTo(0.35, 0.001));
      expect(loaded.scrollOffset, closeTo(120.5, 0.001));
    });

    test('Returns null for unknown file path', () async {
      final loaded = await ReadingProgressService.getProgress('/storage/books/nonexistent.epub');
      expect(loaded, isNull);
    });

    test('Adds, retrieves, and removes bookmarks', () async {
      const filePath = '/storage/books/test_comic.cbz';

      final bookmark1 = BookmarkItem(
        id: 'bm_1',
        page: 12,
        label: 'Page 12',
        snippet: 'Chapter 2 opening panel',
        createdAt: DateTime.now(),
      );

      final bookmark2 = BookmarkItem(
        id: 'bm_2',
        page: 25,
        chapter: 3,
        miniPage: 2,
        label: 'Page 25',
        snippet: 'Important dialogue clue',
        createdAt: DateTime.now(),
      );

      await ReadingProgressService.addBookmark(filePath, bookmark1);
      await ReadingProgressService.addBookmark(filePath, bookmark2);

      var bookmarks = await ReadingProgressService.getBookmarks(filePath);
      expect(bookmarks.length, equals(2));
      // Latest bookmark is at index 0
      expect(bookmarks[0].id, equals('bm_2'));
      expect(bookmarks[1].id, equals('bm_1'));
      expect(bookmarks[0].chapter, equals(3));
      expect(bookmarks[0].miniPage, equals(2));

      // Remove bm_1
      await ReadingProgressService.removeBookmark(filePath, 'bm_1');
      bookmarks = await ReadingProgressService.getBookmarks(filePath);
      expect(bookmarks.length, equals(1));
      expect(bookmarks[0].id, equals('bm_2'));

      // Clear all progress and bookmarks
      await ReadingProgressService.clear(filePath);
      bookmarks = await ReadingProgressService.getBookmarks(filePath);
      expect(bookmarks, isEmpty);
      expect(await ReadingProgressService.getProgress(filePath), isNull);
    });
  });

  group('EbookPaginator Dynamic Pagination Tests', () {
    test('Paginates empty or single-block chapter cleanly', () {
      const emptyChapter = EbookChapter(
        index: 0,
        title: 'Empty',
        rawText: '',
        blocks: [],
        wordCount: 0,
      );

      final emptyPages = EbookPaginator.paginateChapter(
        chapter: emptyChapter,
        viewportSize: const Size(400, 600),
        settings: const EbookSettings(),
        textColor: Colors.black,
      );
      expect(emptyPages.length, equals(1));
      expect(emptyPages[0].blocks, isEmpty);

      const singleBlockChapter = EbookChapter(
        index: 1,
        title: 'Short Chapter',
        rawText: 'Chapter 1: The Beginning\nThis is a short introductory paragraph.',
        blocks: [
          EbookBlock(
            type: EbookBlockType.heading1,
            text: 'Chapter 1: The Beginning',
          ),
          EbookBlock(
            type: EbookBlockType.paragraph,
            text: 'This is a short introductory paragraph.',
          ),
        ],
        wordCount: 10,
      );

      final pages = EbookPaginator.paginateChapter(
        chapter: singleBlockChapter,
        viewportSize: const Size(400, 600),
        settings: const EbookSettings(),
        textColor: Colors.black,
      );
      expect(pages.isNotEmpty, isTrue);
      expect(pages.first.blocks.length, equals(2));
    });

    test('Paginates long multi-paragraph chapter into multiple screen-sized mini-pages', () {
      final longText = List.generate(50, (i) => 'Paragraph $i: ' + ('Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 5)).toList();

      final chapter = EbookChapter(
        index: 0,
        title: 'Long Chapter',
        rawText: longText.join('\n\n'),
        blocks: longText.map((p) => EbookBlock(type: EbookBlockType.paragraph, text: p)).toList(),
        wordCount: 1500,
      );

      final pages = EbookPaginator.paginateChapter(
        chapter: chapter,
        viewportSize: const Size(360, 640),
        settings: const EbookSettings(fontSize: 18.0),
        textColor: Colors.black,
      );

      expect(pages.length, greaterThan(5));
      for (final p in pages) {
        expect(p.blocks.isNotEmpty, isTrue);
      }
    });

    test('findMiniPageIndex correctly finds page for blockIndex and charOffset', () {
      final chapter = EbookChapter(
        index: 0,
        title: 'Test Navigation',
        rawText: 'Test Navigation',
        blocks: [
          const EbookBlock(type: EbookBlockType.heading1, text: 'Title'),
          const EbookBlock(type: EbookBlockType.paragraph, text: 'First paragraph with some text.'),
          EbookBlock(type: EbookBlockType.paragraph, text: 'Second very long paragraph. ' * 30),
          const EbookBlock(type: EbookBlockType.paragraph, text: 'Third concluding paragraph.'),
        ],
        wordCount: 150,
      );

      final pages = EbookPaginator.paginateChapter(
        chapter: chapter,
        viewportSize: const Size(360, 500),
        settings: const EbookSettings(fontSize: 16.0),
        textColor: Colors.black,
      );

      // Block 0 should be on page 0
      final page0 = EbookPaginator.findMiniPageIndex(pages, blockIndex: 0, charOffset: 0);
      expect(page0, equals(0));

      // The last block should be on the last page or near the end
      final lastPage = EbookPaginator.findMiniPageIndex(
        pages,
        blockIndex: 3,
        charOffset: 0,
      );
      expect(lastPage, greaterThan(0));
      expect(lastPage, lessThanOrEqualTo(pages.length - 1));
    });

    test('paginateChapterWithAnchor preserves top line across normal and fullscreen viewports', () {
      // Setup chapter with 20 distinct paragraphs
      final paragraphs = List.generate(
        20,
        (i) => 'Paragraph $i: Line of text about topic $i with some more details to ensure decent length.',
      );

      final chapter = EbookChapter(
        index: 0,
        title: 'Anchor Test',
        rawText: paragraphs.join('\n\n'),
        blocks: paragraphs.map((p) => EbookBlock(type: EbookBlockType.paragraph, text: p)).toList(),
        wordCount: 300,
      );

      const normalViewport = Size(360, 500); // Normal mode (with app bar, bottom bar, status bar)
      const fullscreenViewport = Size(360, 750); // Fullscreen mode (immersive, more vertical space)
      const settings = EbookSettings(fontSize: 16.0);

      // 1. Initial pagination in normal mode
      final normalResult = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: normalViewport,
        settings: settings,
        textColor: Colors.black,
      );
      expect(normalResult.pages.length, greaterThan(3));

      // Assume reader is on Page 2 in normal mode
      const readingPageIndex = 2;
      final curPage = normalResult.pages[readingPageIndex];
      final anchorBlock = curPage.startBlockIndex;
      final anchorChar = curPage.startCharOffset;
      final topSnippet = curPage.snippet;

      // 2. Toggle to FULLSCREEN mode: paginate with current top line anchor
      final fullscreenResult = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: fullscreenViewport,
        settings: settings,
        textColor: Colors.black,
        anchorBlockIndex: anchorBlock,
        anchorCharOffset: anchorChar,
      );

      final fsAnchorPage = fullscreenResult.pages[fullscreenResult.anchorPageIndex];

      // Verify the new fullscreen page starts with the EXACT same top line anchor
      expect(fsAnchorPage.startBlockIndex, equals(anchorBlock));
      expect(fsAnchorPage.startCharOffset, equals(anchorChar));
      expect(fsAnchorPage.snippet, equals(topSnippet));

      // Verify preceding pages exist if anchor was not on block 0
      if (anchorBlock > 0) {
        expect(fullscreenResult.anchorPageIndex, greaterThan(0));
        // The preceding page should end before the anchor page begins
        final prevFsPage = fullscreenResult.pages[fullscreenResult.anchorPageIndex - 1];
        expect(prevFsPage.startBlockIndex, lessThanOrEqualTo(anchorBlock));
      }

      // 3. Toggle back to NORMAL mode from fullscreen: paginate with fs top line anchor
      final normalRestored = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: normalViewport,
        settings: settings,
        textColor: Colors.black,
        anchorBlockIndex: fsAnchorPage.startBlockIndex,
        anchorCharOffset: fsAnchorPage.startCharOffset,
      );

      final restoredPage = normalRestored.pages[normalRestored.anchorPageIndex];
      expect(restoredPage.startBlockIndex, equals(anchorBlock));
      expect(restoredPage.startCharOffset, equals(anchorChar));
      expect(restoredPage.snippet, equals(topSnippet));
    });

    test('Multiple chapters paginate consistently for seamless swiping', () {
      final ch1 = EbookChapter(
        index: 0,
        title: 'Chapter 1',
        rawText: 'Text 1',
        blocks: List.generate(10, (i) => EbookBlock(type: EbookBlockType.paragraph, text: 'Ch 1 Para $i ' * 10)),
        wordCount: 100,
      );

      final ch2 = EbookChapter(
        index: 1,
        title: 'Chapter 2',
        rawText: 'Text 2',
        blocks: List.generate(10, (i) => EbookBlock(type: EbookBlockType.paragraph, text: 'Ch 2 Para $i ' * 10)),
        wordCount: 100,
      );

      const viewport = Size(360, 600);
      const settings = EbookSettings();

      final pagesCh1 = EbookPaginator.paginateChapter(
        chapter: ch1,
        viewportSize: viewport,
        settings: settings,
        textColor: Colors.black,
      );

      final pagesCh2 = EbookPaginator.paginateChapter(
        chapter: ch2,
        viewportSize: viewport,
        settings: settings,
        textColor: Colors.black,
      );

      expect(pagesCh1.isNotEmpty, isTrue);
      expect(pagesCh2.isNotEmpty, isTrue);
      expect(pagesCh1.first.chapterIndex, equals(0));
      expect(pagesCh2.first.chapterIndex, equals(1));
      expect(pagesCh1.last.pageIndex, equals(pagesCh1.length - 1));
      expect(pagesCh2.first.pageIndex, equals(0));
    });
  });
}
