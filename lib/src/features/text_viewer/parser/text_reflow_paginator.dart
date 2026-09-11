import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/text_reflow_models.dart';

/// Dynamic screen paginator for plain text reflow.
/// Measures text and paragraphs against actual device viewport dimensions,
/// ensuring every mini-page fits 100% on screen without vertical overflow.
class TextReflowPaginator {
  static const double _paragraphSpacing = 12.0;
  static const double _headingSpacing = 16.0;

  /// Paginates [chapter] into a list of [TextReflowPage]s that fit [viewportSize].
  static TextReflowPaginationResult paginateChapterWithAnchor({
    required TextReflowChapter chapter,
    required Size viewportSize,
    required TextReflowSettings settings,
    required Color textColor,
    int? anchorBlockIndex,
    int? anchorCharOffset,
  }) {
    if (chapter.blocks.isEmpty) {
      return TextReflowPaginationResult(
        pages: [
          TextReflowPage(
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
    // Reserve space for top status area, header padding, and bottom discrete footer
    final double availableHeight = math.max(200.0, viewportSize.height - 110.0);

    // Normalize anchor
    int safeAnchorBlock = (anchorBlockIndex ?? 0).clamp(0, chapter.blocks.length - 1);
    final anchorBlock = chapter.blocks[safeAnchorBlock];
    int safeAnchorChar = (anchorCharOffset ?? 0).clamp(0, anchorBlock.text.length);

    if (safeAnchorChar >= anchorBlock.text.length && anchorBlock.text.isNotEmpty) {
      if (safeAnchorBlock + 1 < chapter.blocks.length) {
        safeAnchorBlock++;
        safeAnchorChar = 0;
      }
    }

    // Measure chapter title header height for the very first page
    final double titleHeight;
    if (chapter.title.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: chapter.title,
          style: settings.font.getTextStyle(
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

    // -------------------------------------------------------------
    // 1. FORWARD PAGINATION (from safeAnchorBlock, safeAnchorChar to end)
    // -------------------------------------------------------------
    final List<List<TextReflowBlock>> forwardRawPages = [];
    final List<int> forwardStartBlocks = [];
    final List<int> forwardStartChars = [];

    List<TextReflowBlock> currentBlocks = [];
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

      TextReflowBlock block;
      if (bIdx == safeAnchorBlock && safeAnchorChar > 0) {
        block = TextReflowBlock(
          type: origBlock.type,
          text: origBlock.text.substring(safeAnchorChar),
          isBold: origBlock.isBold,
          isItalic: origBlock.isItalic,
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
          // Fresh page, block exceeds screen height: split paragraph
          if (block.type == TextReflowBlockType.paragraph ||
              block.type == TextReflowBlockType.quote) {
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
    // 2. BACKWARD PAGINATION (preceding content before anchor)
    // -------------------------------------------------------------
    final List<List<TextReflowBlock>> backwardRawPages = [];
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
          block: TextReflowBlock(
            type: b.type,
            text: prefixText,
            isBold: b.isBold,
            isItalic: b.isItalic,
          ),
        ));
      }
    }

    if (fragments.isNotEmpty) {
      List<TextReflowBlock> curPageBlocks = [];
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
            if (fragment.block.type == TextReflowBlockType.paragraph ||
                fragment.block.type == TextReflowBlockType.quote) {
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

    final reversedBackwardRaw = backwardRawPages.reversed.toList();
    final reversedBackwardBlocks = backwardStartBlocks.reversed.toList();
    final reversedBackwardChars = backwardStartChars.reversed.toList();

    final int anchorPageIndex = reversedBackwardRaw.length;

    final allRawPages = [...reversedBackwardRaw, ...forwardRawPages];
    final allStartBlocks = [...reversedBackwardBlocks, ...forwardStartBlocks];
    final allStartChars = [...reversedBackwardChars, ...forwardStartChars];

    if (allRawPages.isEmpty) {
      return TextReflowPaginationResult(
        pages: [
          TextReflowPage(
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
    final List<TextReflowPage> pages = [];

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
        TextReflowPage(
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

    return TextReflowPaginationResult(
      pages: pages,
      anchorPageIndex: anchorPageIndex.clamp(0, pages.length - 1),
    );
  }

  /// Simple forward pagination without anchor.
  static List<TextReflowPage> paginateChapter({
    required TextReflowChapter chapter,
    required Size viewportSize,
    required TextReflowSettings settings,
    required Color textColor,
  }) {
    return paginateChapterWithAnchor(
      chapter: chapter,
      viewportSize: viewportSize,
      settings: settings,
      textColor: textColor,
    ).pages;
  }

  static double _measureBlockHeight(
    TextReflowBlock block,
    double availableWidth,
    TextReflowSettings settings,
    Color textColor,
  ) {
    switch (block.type) {
      case TextReflowBlockType.heading1:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.font.getTextStyle(
              fontSize: settings.fontSize * 1.35,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: availableWidth);
        return painter.height + _headingSpacing * 2;

      case TextReflowBlockType.heading2:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.font.getTextStyle(
              fontSize: settings.fontSize * 1.2,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: availableWidth);
        return painter.height + _headingSpacing;

      case TextReflowBlockType.heading3:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.font.getTextStyle(
              fontSize: settings.fontSize * 1.08,
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: availableWidth);
        return painter.height + 12.0;

      case TextReflowBlockType.paragraph:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.font.getTextStyle(
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

      case TextReflowBlockType.quote:
        final painter = TextPainter(
          text: TextSpan(
            text: block.text,
            style: settings.font.getTextStyle(
              fontSize: settings.fontSize * 0.95,
              color: textColor,
              height: settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        )..layout(maxWidth: math.max(50.0, availableWidth - 24.0));
        return painter.height + 16.0;

      case TextReflowBlockType.divider:
        return 28.0;
    }
  }

  static _TextSplitResult? _splitTextBlock(
    TextReflowBlock block,
    double availableWidth,
    double targetHeight,
    TextReflowSettings settings,
    Color textColor,
  ) {
    if (block.text.length < 20) return null;

    final style = settings.font.getTextStyle(
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

    int safeCut = block.text.lastIndexOf(RegExp(r'\s'), cutOffset);
    if (safeCut <= 15) {
      safeCut = cutOffset;
    }

    final text1 = block.text.substring(0, safeCut).trimRight();
    final text2 = block.text.substring(safeCut).trimLeft();

    if (text1.isEmpty || text2.isEmpty) return null;

    return _TextSplitResult(
      part1: TextReflowBlock(
        type: block.type,
        text: text1,
        isBold: block.isBold,
        isItalic: block.isItalic,
      ),
      part2: TextReflowBlock(
        type: block.type,
        text: text2,
        isBold: block.isBold,
        isItalic: block.isItalic,
      ),
    );
  }

  static _TextSplitResult? _splitTextBlockFromBottom(
    TextReflowBlock block,
    double availableWidth,
    double targetBottomHeight,
    TextReflowSettings settings,
    Color textColor,
  ) {
    if (block.text.length < 20) return null;

    final style = settings.font.getTextStyle(
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
    if (topCutHeight <= 0 || topCutHeight >= totalH) {
      return null;
    }

    final pos = painter.getPositionForOffset(Offset(availableWidth, topCutHeight));
    int cutOffset = pos.offset;

    if (cutOffset <= 0 || cutOffset >= block.text.length) {
      cutOffset = (block.text.length * (topCutHeight / totalH)).clamp(10, block.text.length - 10).toInt();
    }

    int safeCut = block.text.indexOf(RegExp(r'\s'), cutOffset);
    if (safeCut == -1 || safeCut >= block.text.length - 10) {
      final backCut = block.text.lastIndexOf(RegExp(r'\s'), cutOffset);
      safeCut = (backCut > 10) ? backCut : cutOffset;
    }

    final text1 = block.text.substring(0, safeCut).trimRight();
    final text2 = block.text.substring(safeCut).trimLeft();

    if (text1.isEmpty || text2.isEmpty) return null;

    return _TextSplitResult(
      part1: TextReflowBlock(
        type: block.type,
        text: text1,
        isBold: block.isBold,
        isItalic: block.isItalic,
      ),
      part2: TextReflowBlock(
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
  final TextReflowBlock block;

  const _PrecedingFragment({
    required this.blockIndex,
    required this.charOffset,
    required this.block,
  });
}

class _TextSplitResult {
  final TextReflowBlock part1;
  final TextReflowBlock part2;

  const _TextSplitResult({
    required this.part1,
    required this.part2,
  });
}
