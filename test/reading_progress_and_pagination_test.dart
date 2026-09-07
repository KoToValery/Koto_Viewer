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
  });
}
