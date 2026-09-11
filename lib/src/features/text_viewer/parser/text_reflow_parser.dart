import '../models/text_reflow_models.dart';

/// Intelligent plain text parser for e-book reflow.
/// Converts raw text lines into structured chapters and paragraphs,
/// unwrapping hard-wrapped lines while preserving dialogues, headings, and poetry.
class TextReflowParser {
  const TextReflowParser._();

  static final RegExp _chapterHeadingRegex = RegExp(
    r'^\s*(?:ГЛАВА|ЧАСТ|РАЗДЕЛ|КНИГА|CHAPTER|PART|BOOK|SECTION|ACT|SCENE)(?:[\s:.-]|$)',
    caseSensitive: false,
  );

  static final RegExp _romanNumeralRegex = RegExp(
    r'^\s*([IVXLCDM]{1,8})[\.:]?\s*$',
  );

  static final RegExp _markdownHeaderRegex = RegExp(
    r'^\s*(#{1,3})\s+(.+)$',
  );

  static final RegExp _dividerRegex = RegExp(
    r'^\s*(\*{3,}|-{3,}|_{3,}|~{3,}|={3,}|\*\s+\*\s+\*)\s*$',
  );

  static final RegExp _dialogueStartRegex = RegExp(
    r'^\s*([—–―-]\s+|«|„|"[A-Za-zА-Яа-я])',
  );

  /// Parses [fullText] into a list of [TextReflowChapter]s.
  static List<TextReflowChapter> parse(String fullText, {String defaultTitle = 'Document'}) {
    if (fullText.trim().isEmpty) {
      return [
        TextReflowChapter(
          index: 0,
          title: defaultTitle,
          rawText: '',
          blocks: const [],
          wordCount: 0,
        ),
      ];
    }

    final rawLines = fullText.split(RegExp(r'\r?\n'));
    final List<_RawChapterData> rawChapters = [];

    String currentChapterTitle = '';
    List<String> currentChapterLines = [];

    bool isFirstBlock = true;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        currentChapterLines.add(line);
        continue;
      }

      // Check for chapter title
      String? detectedTitle;
      final mdMatch = _markdownHeaderRegex.firstMatch(trimmed);
      if (mdMatch != null) {
        detectedTitle = mdMatch.group(2)!.trim();
      } else if (_chapterHeadingRegex.hasMatch(trimmed) && trimmed.length <= 90) {
        detectedTitle = trimmed;
      } else if (_romanNumeralRegex.hasMatch(trimmed) && trimmed.length <= 10) {
        // Only consider roman numerals if preceded or followed by empty lines
        final prevEmpty = i == 0 || rawLines[i - 1].trim().isEmpty;
        final nextEmpty = i == rawLines.length - 1 || rawLines[i + 1].trim().isEmpty;
        if (prevEmpty && nextEmpty) {
          detectedTitle = 'Chapter $trimmed';
        }
      }

      if (detectedTitle != null) {
        if (currentChapterLines.isNotEmpty && !isFirstBlock) {
          rawChapters.add(_RawChapterData(
            title: currentChapterTitle.isNotEmpty ? currentChapterTitle : (rawChapters.isEmpty ? defaultTitle : 'Chapter ${rawChapters.length + 1}'),
            lines: List.from(currentChapterLines),
          ));
          currentChapterLines.clear();
        }
        currentChapterTitle = detectedTitle;
        isFirstBlock = false;
        continue;
      }

      currentChapterLines.add(line);
      isFirstBlock = false;
    }

    if (currentChapterLines.isNotEmpty) {
      rawChapters.add(_RawChapterData(
        title: currentChapterTitle.isNotEmpty ? currentChapterTitle : (rawChapters.isEmpty ? defaultTitle : 'Chapter ${rawChapters.length + 1}'),
        lines: List.from(currentChapterLines),
      ));
    }

    // If no chapters were detected or only 1 huge chapter > 3500 words,
    // subdivide into logical sections for snappy pagination and navigation
    final List<TextReflowChapter> finalChapters = [];

    if (rawChapters.length == 1 && _countWordsInLines(rawChapters.first.lines) > 4000) {
      final subChapters = _splitLargeChapterIntoSections(rawChapters.first, defaultTitle);
      for (int cIdx = 0; cIdx < subChapters.length; cIdx++) {
        final sc = subChapters[cIdx];
        final blocks = _parseLinesIntoBlocks(sc.lines);
        final raw = sc.lines.join('\n');
        finalChapters.add(TextReflowChapter(
          index: cIdx,
          title: sc.title,
          rawText: raw,
          blocks: blocks,
          wordCount: _countWords(raw),
        ));
      }
    } else {
      for (int cIdx = 0; cIdx < rawChapters.length; cIdx++) {
        final ch = rawChapters[cIdx];
        final blocks = _parseLinesIntoBlocks(ch.lines);
        final raw = ch.lines.join('\n');
        finalChapters.add(TextReflowChapter(
          index: cIdx,
          title: ch.title,
          rawText: raw,
          blocks: blocks,
          wordCount: _countWords(raw),
        ));
      }
    }

    if (finalChapters.isEmpty) {
      finalChapters.add(TextReflowChapter(
        index: 0,
        title: defaultTitle,
        rawText: fullText,
        blocks: _parseLinesIntoBlocks(rawLines),
        wordCount: _countWords(fullText),
      ));
    }

    return finalChapters;
  }

  /// Converts a group of lines into structured [TextReflowBlock]s.
  /// Unwraps soft line-breaks inside paragraphs while preserving blank lines and dialogue.
  static List<TextReflowBlock> _parseLinesIntoBlocks(List<String> lines) {
    final List<TextReflowBlock> blocks = [];
    final List<String> currentParagraphLines = [];

    void flushParagraph() {
      if (currentParagraphLines.isEmpty) return;

      final joined = _unwrapParagraphLines(currentParagraphLines);
      if (joined.trim().isNotEmpty) {
        // Detect subheadings or special blocks
        if (_dividerRegex.hasMatch(joined.trim())) {
          blocks.add(const TextReflowBlock(
            type: TextReflowBlockType.divider,
            text: '• • •',
          ));
        } else if (joined.trim().startsWith('>')) {
          blocks.add(TextReflowBlock(
            type: TextReflowBlockType.quote,
            text: joined.replaceFirst(RegExp(r'^\s*>\s*'), '').trim(),
            isItalic: true,
          ));
        } else {
          blocks.add(TextReflowBlock(
            type: TextReflowBlockType.paragraph,
            text: joined.trim(),
          ));
        }
      }
      currentParagraphLines.clear();
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      if (_dividerRegex.hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(const TextReflowBlock(
          type: TextReflowBlockType.divider,
          text: '• • •',
        ));
        continue;
      }

      // Check if this line starts a new dialogue dash
      if (_dialogueStartRegex.hasMatch(trimmed) && currentParagraphLines.isNotEmpty) {
        flushParagraph();
      }

      currentParagraphLines.add(line);
    }

    flushParagraph();
    return blocks;
  }

  /// Unwraps lines belonging to a single paragraph.
  /// Handles hyphenated line endings (e.g. 'com- \n puter' -> 'computer').
  static String _unwrapParagraphLines(List<String> lines) {
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines.first.trim();

    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (buffer.isEmpty) {
        buffer.write(line);
      } else {
        final currentStr = buffer.toString();
        // Check for hyphenation wrap at the end of previous line
        if (currentStr.endsWith('-') && !currentStr.endsWith(' -') && !currentStr.endsWith('--')) {
          // Check if it's a word-break hyphen (e.g. 'exam-' followed by 'ple')
          final beforeHyphen = currentStr.substring(0, currentStr.length - 1);
          buffer.clear();
          buffer.write(beforeHyphen);
          buffer.write(line);
        } else {
          buffer.write(' ');
          buffer.write(line);
        }
      }
    }
    return buffer.toString();
  }

  static List<_RawChapterData> _splitLargeChapterIntoSections(_RawChapterData large, String defaultTitle) {
    final List<_RawChapterData> result = [];
    final List<String> currentSectionLines = [];
    int currentWords = 0;
    const int targetWordsPerSection = 2500;

    for (final line in large.lines) {
      currentSectionLines.add(line);
      final wordsInLine = line.trim().isEmpty ? 0 : line.trim().split(RegExp(r'\s+')).length;
      currentWords += wordsInLine;

      if (currentWords >= targetWordsPerSection && line.trim().isEmpty) {
        final sectionIndex = result.length + 1;
        result.add(_RawChapterData(
          title: '${large.title} • Part $sectionIndex',
          lines: List.from(currentSectionLines),
        ));
        currentSectionLines.clear();
        currentWords = 0;
      }
    }

    if (currentSectionLines.isNotEmpty) {
      if (result.isEmpty) {
        result.add(large);
      } else {
        final sectionIndex = result.length + 1;
        result.add(_RawChapterData(
          title: '${large.title} • Part $sectionIndex',
          lines: List.from(currentSectionLines),
        ));
      }
    }

    return result;
  }

  static int _countWordsInLines(List<String> lines) {
    int count = 0;
    for (final l in lines) {
      if (l.trim().isNotEmpty) {
        count += l.trim().split(RegExp(r'\s+')).length;
      }
    }
    return count;
  }

  static int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}

class _RawChapterData {
  final String title;
  final List<String> lines;

  const _RawChapterData({
    required this.title,
    required this.lines,
  });
}
