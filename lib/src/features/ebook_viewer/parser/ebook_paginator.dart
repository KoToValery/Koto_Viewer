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

  /// Paginates [chapter] into pages with an anchor block & character offset.
  /// The resulting page at [anchorPageIndex] will start with the exact content at
  /// [anchorBlockIndex, anchorCharOffset] at the top of the screen.
  static EbookPaginationResult paginateChapterWithAnchor({
    required EbookChapter chapter,
    required Size viewportSize,
    required EbookSettings settings,
    required Color textColor,
    int? anchorBlockIndex,
    int? anchorCharOffset,
  }) {
    if (chapter.blocks.isEmpty) {
      return EbookPaginationResult(
        pages: [
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
        ],
        anchorPageIndex: 0,
      );
    }

    final double availableWidth = math.max(160.0, viewportSize.width - (settings.horizontalPadding * 2));
    // Reserve space for top status area, header padding, and bottom footer indicator
    final double availableHeight = math.max(200.0, viewportSize.height - 116.0);

    // Normalize anchor
    int safeAnchorBlock = (anchorBlockIndex ?? 0).clamp(0, chapter.blocks.length - 1);
    final anchorBlock = chapter.blocks[safeAnchorBlock];
    int safeAnchorChar = (anchorCharOffset ?? 0).clamp(0, anchorBlock.text.length);

    // If anchor char is at or beyond the text length of the block, advance to next block if possible
    if (safeAnchorChar >= anchorBlock.text.length && anchorBlock.text.isNotEmpty) {
      if (safeAnchorBlock + 1 < chapter.blocks.length) {
        safeAnchorBlock++;
        safeAnchorChar = 0;
      }
    }

    // -------------------------------------------------------------
    // 1. FORWARD PAGINATION (from safeAnchorBlock, safeAnchorChar to end)
    // -------------------------------------------------------------
    final double titleHeight;
    if (chapter.title.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: chapter.title,
          style: settings.fontFamily.getTextStyle(
            fontSize: settings.fontSize * 1.3,
            color: textColor,
            height: 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: availableWidth);
      titleHeight = painter.height + 24.0;
    } else {
      titleHeight = 0.0;
    }

    final List<List<EbookBlock>> forwardRawPages = [];
    final List<int> forwardStartBlocks = [];
    final List<int> forwardStartChars = [];

    List<EbookBlock> currentBlocks = [];
    final bool isAnchorAtBeginning = (safeAnchorBlock == 0 && safeAnchorChar == 0);
    double remainingHeight = isAnchorAtBeginning
        ? math.max(100.0, availableHeight - titleHeight)
        : availableHeight;
    int currentStartBlock = safeAnchorBlock;
    int currentStartChar = safeAnchorChar;

    void finishForwardPage() {
      if (currentBlocks.isNotEmpty) {
        forwardRawPages.add(List.from(currentBlocks));
        forwardStartBlocks.add(currentStartBlock);
        forwardStartChars.add(currentStartChar);
        currentBlocks = [];
        remainingHeight = availableHeight;
      }
    }

    for (int bIdx = safeAnchorBlock; bIdx < chapter.blocks.length; bIdx++) {
      var origBlock = chapter.blocks[bIdx];
      int blockCharOffset = (bIdx == safeAnchorBlock) ? safeAnchorChar : 0;

      EbookBlock block;
      if (bIdx == safeAnchorBlock && safeAnchorChar > 0) {
        block = EbookBlock(
          type: origBlock.type,
          text: origBlock.text.substring(safeAnchorChar),
          isBold: origBlock.isBold,
          isItalic: origBlock.isItalic,
          imageBytes: origBlock.imageBytes,
          imageKey: origBlock.imageKey,
        );
      } else {
        block = origBlock;
      }

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
          currentBlocks.add(block);
          remainingHeight -= blockHeight;
          break;
        } else if (currentBlocks.isNotEmpty) {
          finishForwardPage();
        } else {
          // Fresh page, block exceeds screen height
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
              finishForwardPage();
              block = split.part2;
              continue;
            }
          }

          currentBlocks.add(block);
          finishForwardPage();
          break;
        }
      }
    }

    finishForwardPage();

    // -------------------------------------------------------------
    // 2. BACKWARD PAGINATION (preceding content before safeAnchorBlock, safeAnchorChar)
    // -------------------------------------------------------------
    final List<List<EbookBlock>> backwardRawPages = [];
    final List<int> backwardStartBlocks = [];
    final List<int> backwardStartChars = [];

    final List<_PrecedingFragment> fragments = [];
    for (int i = 0; i < safeAnchorBlock; i++) {
      fragments.add(_PrecedingFragment(
        blockIndex: i,
        charOffset: 0,
        block: chapter.blocks[i],
      ));
    }
    if (safeAnchorChar > 0 && safeAnchorBlock < chapter.blocks.length) {
      final b = chapter.blocks[safeAnchorBlock];
      final prefixText = b.text.substring(0, math.min(safeAnchorChar, b.text.length));
      if (prefixText.isNotEmpty) {
        fragments.add(_PrecedingFragment(
          blockIndex: safeAnchorBlock,
          charOffset: 0,
          block: EbookBlock(
            type: b.type,
            text: prefixText,
            isBold: b.isBold,
            isItalic: b.isItalic,
            imageBytes: b.imageBytes,
            imageKey: b.imageKey,
          ),
        ));
      }
    }

    if (fragments.isNotEmpty) {
      List<EbookBlock> curPageBlocks = [];
      int curPageStartBlock = 0;
      int curPageStartChar = 0;
      double curRemainingHeight = availableHeight;

      void finishBackwardPage() {
        if (curPageBlocks.isNotEmpty) {
          backwardRawPages.add(List.from(curPageBlocks));
          backwardStartBlocks.add(curPageStartBlock);
          backwardStartChars.add(curPageStartChar);
          curPageBlocks = [];
          curRemainingHeight = availableHeight;
        }
      }

      while (fragments.isNotEmpty) {
        var fragment = fragments.removeLast();

        while (true) {
          final double h = _measureBlockHeight(
            fragment.block,
            availableWidth,
            settings,
            textColor,
          );

          if (h <= curRemainingHeight) {
            curPageBlocks.insert(0, fragment.block);
            curPageStartBlock = fragment.blockIndex;
            curPageStartChar = fragment.charOffset;
            curRemainingHeight -= h;
            break;
          } else if (curPageBlocks.isNotEmpty) {
            finishBackwardPage();
          } else {
            // Fresh page, block exceeds screen height
            if (fragment.block.type == EbookBlockType.paragraph ||
                fragment.block.type == EbookBlockType.quote ||
                fragment.block.type == EbookBlockType.epigraph ||
                fragment.block.type == EbookBlockType.poem) {
              final split = _splitTextBlockFromBottom(
                fragment.block,
                availableWidth,
                curRemainingHeight,
                settings,
                textColor,
              );

              if (split != null && split.part1.text.isNotEmpty && split.part2.text.isNotEmpty) {
                curPageBlocks.insert(0, split.part2);
                curPageStartBlock = fragment.blockIndex;
                curPageStartChar = fragment.charOffset + split.part1.text.length;
                finishBackwardPage();

                // Put the remaining top part back into fragments to continue
                fragment = _PrecedingFragment(
                  blockIndex: fragment.blockIndex,
                  charOffset: fragment.charOffset,
                  block: split.part1,
                );
                continue;
              }
            }

            curPageBlocks.insert(0, fragment.block);
            curPageStartBlock = fragment.blockIndex;
            curPageStartChar = fragment.charOffset;
            finishBackwardPage();
            break;
          }
        }
      }

      finishBackwardPage();
    }

    // backwardRawPages was collected from anchor backwards, so reverse to chronological order
    final reversedBackwardRaw = backwardRawPages.reversed.toList();
    final reversedBackwardBlocks = backwardStartBlocks.reversed.toList();
    final reversedBackwardChars = backwardStartChars.reversed.toList();

    final int anchorPageIndex = reversedBackwardRaw.length;

    final allRawPages = [...reversedBackwardRaw, ...forwardRawPages];
    final allStartBlocks = [...reversedBackwardBlocks, ...forwardStartBlocks];
    final allStartChars = [...reversedBackwardChars, ...forwardStartChars];

    if (allRawPages.isEmpty) {
      return EbookPaginationResult(
        pages: [
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
        ],
        anchorPageIndex: 0,
      );
    }

    final totalPages = allRawPages.length;
    final List<EbookMiniPage> pages = [];

    for (int i = 0; i < totalPages; i++) {
      final blocks = allRawPages[i];
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
          startBlockIndex: allStartBlocks[i],
          startCharOffset: allStartChars[i],
          snippet: snippet,
        ),
      );
    }

    return EbookPaginationResult(
      pages: pages,
      anchorPageIndex: anchorPageIndex.clamp(0, pages.length - 1),
    );
  }

  /// Paginates [chapter] into a list of [EbookMiniPage]s that fit [viewportSize].
  static List<EbookMiniPage> paginateChapter({
    required EbookChapter chapter,
    required Size viewportSize,
    required EbookSettings settings,
    required Color textColor,
    int? anchorBlockIndex,
    int? anchorCharOffset,
  }) {
    return paginateChapterWithAnchor(
      chapter: chapter,
      viewportSize: viewportSize,
      settings: settings,
      textColor: textColor,
      anchorBlockIndex: anchorBlockIndex,
      anchorCharOffset: anchorCharOffset,
    ).pages;
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
      safeCut = cutOffset;
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

  static _TextSplitResult? _splitTextBlockFromBottom(
    EbookBlock block,
    double availableWidth,
    double targetBottomHeight,
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

    final totalH = painter.height;
    final topCutHeight = totalH - (targetBottomHeight - _paragraphSpacing);
    if (topCutHeight <= 0) {
      // The entire block fits in targetBottomHeight
      return null;
    }
    if (topCutHeight >= totalH) {
      return null;
    }

    final pos = painter.getPositionForOffset(Offset(availableWidth, topCutHeight));
    int cutOffset = pos.offset;

    if (cutOffset <= 0 || cutOffset >= block.text.length) {
      cutOffset = (block.text.length * (topCutHeight / totalH)).clamp(10, block.text.length - 10).toInt();
    }

    // Since part2 must fit inside targetBottomHeight, cutting forward (>= cutOffset)
    // ensures part2 is shorter than or equal to targetBottomHeight
    int safeCut = block.text.indexOf(RegExp(r'\s'), cutOffset);
    if (safeCut == -1 || safeCut >= block.text.length - 10) {
      final backCut = block.text.lastIndexOf(RegExp(r'\s'), cutOffset);
      if (backCut > 10) {
        safeCut = backCut;
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

class _PrecedingFragment {
  final int blockIndex;
  final int charOffset;
  final EbookBlock block;

  const _PrecedingFragment({
    required this.blockIndex,
    required this.charOffset,
    required this.block,
  });
}

class _TextSplitResult {
  final EbookBlock part1;
  final EbookBlock part2;
  const _TextSplitResult({required this.part1, required this.part2});
}

/// Result of paginating a chapter with an anchor.
/// [anchorPageIndex] points directly to the page starting with the requested anchor block/character.
class EbookPaginationResult {
  final List<EbookMiniPage> pages;
  final int anchorPageIndex;

  const EbookPaginationResult({
    required this.pages,
    required this.anchorPageIndex,
  });
}

