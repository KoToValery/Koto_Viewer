import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/ebook_models.dart';

/// Dynamic screen paginator for e-books.
/// Measures text and blocks against actual viewport dimensions so that every
/// mini-page fits 100% on the device screen without vertical scrolling.
class EbookPaginator {
  static const double _paragraphSpacing = 12.0;
  static const double _headingTopSpacing = 16.0;
  static const double _headingBottomSpacing = 8.0;

  /// Paginates [chapter] into a list of [EbookMiniPage]s that fit [viewportSize].
  static List<EbookMiniPage> paginateChapter({
    required EbookChapter chapter,
    required Size viewportSize,
    required EbookSettings settings,
    required Color textColor,
  }) {
    if (chapter.blocks.isEmpty) {
      return [
        EbookMiniPage(
          chapterIndex: chapter.index,
          pageIndex: 0,
          totalPagesInChapter: 1,
          chapterTitle: chapter.title,
          blocks: const [],
          startBlockIndex: 0,
          startCharOffset: 0,
          snippet: chapter.title,
        ),
      ];
    }

    final double availableWidth = math.max(160.0, viewportSize.width - (settings.horizontalPadding * 2));
    // Reserve space for top status area, header padding, and bottom footer indicator
    final double availableHeight = math.max(200.0, viewportSize.height - 116.0);

    final List<List<EbookBlock>> rawPages = [];
    final List<int> pageStartBlockIndices = [];
    final List<int> pageStartCharOffsets = [];

    List<EbookBlock> currentBlocks = [];
    double remainingHeight = availableHeight;
    int currentStartBlock = 0;
    int currentStartChar = 0;

    void finishCurrentPage() {
      if (currentBlocks.isNotEmpty) {
        rawPages.add(List.from(currentBlocks));
        pageStartBlockIndices.add(currentStartBlock);
        pageStartCharOffsets.add(currentStartChar);
        currentBlocks = [];
        remainingHeight = availableHeight;
      }
    }

    for (int bIdx = 0; bIdx < chapter.blocks.length; bIdx++) {
      var block = chapter.blocks[bIdx];
      int blockCharOffset = 0;

      // Repeat if block needs to be split across pages
      while (true) {
        if (currentBlocks.isEmpty) {
          currentStartBlock = bIdx;
          currentStartChar = blockCharOffset;
        }

        final double blockHeight = _measureBlockHeight(
          block,
          availableWidth,
          settings,
          textColor,
        );

        if (blockHeight <= remainingHeight) {
          // Block fits on current page
          currentBlocks.add(block);
          remainingHeight -= blockHeight;
          break;
        } else if (currentBlocks.isNotEmpty) {
          // Block does not fit on current page, but page already has content:
          // finish current page and try again on a fresh page.
          finishCurrentPage();
        } else {
          // Fresh page, but block itself exceeds entire screen height (long paragraph)!
          if (block.type == EbookBlockType.paragraph ||
              block.type == EbookBlockType.quote ||
              block.type == EbookBlockType.epigraph ||
              block.type == EbookBlockType.poem) {
            final split = _splitTextBlock(
              block,
              availableWidth,
              remainingHeight,
              settings,
              textColor,
            );

            if (split != null && split.part1.text.isNotEmpty && split.part2.text.isNotEmpty) {
              currentBlocks.add(split.part1);
              blockCharOffset += split.part1.text.length;
              finishCurrentPage();
              block = split.part2;
              continue;
            }
          }

          // Fallback if unsplittable: place on current page and finish
          currentBlocks.add(block);
          finishCurrentPage();
          break;
        }
      }
    }

    finishCurrentPage();

    if (rawPages.isEmpty) {
      return [
        EbookMiniPage(
          chapterIndex: chapter.index,
          pageIndex: 0,
          totalPagesInChapter: 1,
          chapterTitle: chapter.title,
          blocks: chapter.blocks,
          startBlockIndex: 0,
          startCharOffset: 0,
          snippet: chapter.title,
        ),
      ];
    }

    final totalPages = rawPages.length;
    final List<EbookMiniPage> pages = [];

    for (int i = 0; i < totalPages; i++) {
      final blocks = rawPages[i];
      String snippet = '';
      for (final b in blocks) {
        if (b.text.trim().isNotEmpty) {
          snippet = b.text.trim();
          if (snippet.length > 70) {
            snippet = '${snippet.substring(0, 67)}...';
          }
          break;
        }
      }
      if (snippet.isEmpty) snippet = chapter.title;

      pages.add(
        EbookMiniPage(
          chapterIndex: chapter.index,
          pageIndex: i,
          totalPagesInChapter: totalPages,
          chapterTitle: chapter.title,
          blocks: blocks,
          startBlockIndex: pageStartBlockIndices[i],
          startCharOffset: pageStartCharOffsets[i],
          snippet: snippet,
        ),
      );
    }

    return pages;
  }

  /// Locates the mini-page index corresponding to a saved reading position or locator.
  static int findMiniPageIndex(
    List<EbookMiniPage> pages, {
    int? preferredMiniPage,
    int? blockIndex,
    int? charOffset,
  }) {
    if (pages.isEmpty) return 0;

    if (blockIndex != null) {
      for (int i = 0; i < pages.length; i++) {
        final next = (i + 1 < pages.length) ? pages[i + 1] : null;

        if (next != null) {
          if (blockIndex < next.startBlockIndex ||
              (blockIndex == next.startBlockIndex && (charOffset ?? 0) < next.startCharOffset)) {
            return i;
          }
        } else {
          return i;
        }
      }
    }

    if (preferredMiniPage != null) {
      return preferredMiniPage.clamp(0, pages.length - 1);
    }

    return 0;
  }

  static double _measureBlockHeight(
    EbookBlock block,
    double availableWidth,
    EbookSettings settings,
    Color textColor,
  ) {
    switch (block.type) {
      case EbookBlockType.heading1:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize * 1.35,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: availableWidth);
        return painter.height + _headingTopSpacing + _headingBottomSpacing;

      case EbookBlockType.heading2:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize * 1.2,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: availableWidth);
        return painter.height + _headingTopSpacing + _headingBottomSpacing;

      case EbookBlockType.heading3:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize * 1.08,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: availableWidth);
        return painter.height + 12.0 + 6.0;

      case EbookBlockType.paragraph:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize,
              color: textColor,
              height: settings.lineHeight,
              fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: settings.textAlign,
        )..layout(maxWidth: availableWidth);
        return painter.height + _paragraphSpacing;

      case EbookBlockType.quote:
      case EbookBlockType.epigraph:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize * 0.95,
              color: textColor,
              height: settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: math.max(50.0, availableWidth - 28.0));
        return painter.height + 20.0;

      case EbookBlockType.poem:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.fontFamily.getTextStyle(
              fontSize: settings.fontSize * 0.95,
              color: textColor,
              height: settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: math.max(50.0, availableWidth - 30.0));
        return painter.height + 16.0;

      case EbookBlockType.image:
        if (block.imageBytes != null) {
          return 210.0; // Reserve standard book image height
        }
        return 0.0;

      case EbookBlockType.divider:
        return 36.0;
    }
  }

  static _TextSplitResult? _splitTextBlock(
    EbookBlock block,
    double availableWidth,
    double targetHeight,
    EbookSettings settings,
    Color textColor,
  ) {
    if (block.text.length < 20) return null;

    final style = settings.fontFamily.getTextStyle(
      fontSize: settings.fontSize,
      color: textColor,
      height: settings.lineHeight,
      fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal,
    );

    final painter = TextPainter(
      text: TextSpan(text: block.text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: settings.textAlign,
    )..layout(maxWidth: availableWidth);

    final pos = painter.getPositionForOffset(Offset(availableWidth, targetHeight - _paragraphSpacing));
    int cutOffset = pos.offset;

    if (cutOffset <= 0 || cutOffset >= block.text.length) {
      cutOffset = (block.text.length * (targetHeight / painter.height)).clamp(20, block.text.length - 1).toInt();
    }

    // Find nearest preceding space or newline to avoid cutting words in half
    int safeCut = block.text.lastIndexOf(RegExp(r'\s'), cutOffset);
    if (safeCut <= 15) {
      // If no good space backwards, search slightly forward
      final forwardCut = block.text.indexOf(RegExp(r'\s'), cutOffset);
      if (forwardCut > 0 && forwardCut < block.text.length - 10) {
        safeCut = forwardCut;
      } else {
        safeCut = cutOffset;
      }
    }

    final text1 = block.text.substring(0, safeCut).trimRight();
    final text2 = block.text.substring(safeCut).trimLeft();

    if (text1.isEmpty || text2.isEmpty) return null;

    return _TextSplitResult(
      part1: EbookBlock(
        type: block.type,
        text: text1,
        isBold: block.isBold,
        isItalic: block.isItalic,
      ),
      part2: EbookBlock(
        type: block.type,
        text: text2,
        isBold: block.isBold,
        isItalic: block.isItalic,
      ),
    );
  }
}

class _TextSplitResult {
  final EbookBlock part1;
  final EbookBlock part2;
  const _TextSplitResult({required this.part1, required this.part2});
}
