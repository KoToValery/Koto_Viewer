import 'dart:convert';
import 'dart:typed_data';
import '../models/pptx_models.dart';
import 'pptx_parser.dart';

/// Pure-Dart legacy PowerPoint 97-2003 (.ppt) Presentation Parser.
class PptParser {
  /// Parses bytes of a `.ppt` file into a structured [PptxPresentation].
  static PptxPresentation parse(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const PptxPresentation(slides: []);
    }

    // 1. Check if this is a .pptx masquerading as .ppt (Zip PK\x03\x04 signature)
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      try {
        return PptxParser.parse(bytes);
      } catch (_) {}
    }

    // 2. Check for OLE Compound File signature
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1) {
      return _parseOlePpt(bytes);
    }

    // 3. Fallback: Plain text / lines
    return _parsePlainTextPpt(bytes);
  }

  static PptxPresentation _parseOlePpt(Uint8List bytes) {
    final List<List<String>> slideTextGroups = [];
    List<String> currentSlideTexts = [];
    final StringBuffer currentRun = StringBuffer();

    // 1. Try UTF-16LE extraction
    int i = 512; // Skip standard OLE 512-byte header
    while (i < bytes.length - 1) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);

      if (codeUnit == 0x0D || codeUnit == 0x07 || codeUnit == 0x0C || codeUnit == 0x0A) {
        final text = currentRun.toString().trim();
        if (text.length >= 2 && !_isNoise(text)) {
          currentSlideTexts.add(text);
          if (currentSlideTexts.length >= 5 || codeUnit == 0x0C) {
            slideTextGroups.add(List.from(currentSlideTexts));
            currentSlideTexts.clear();
          }
        }
        currentRun.clear();
        i += 2;
      } else if (_isValidCharCode(codeUnit)) {
        currentRun.write(String.fromCharCode(codeUnit));
        i += 2;
      } else {
        if (currentRun.length >= 3) {
          final text = currentRun.toString().trim();
          if (!_isNoise(text)) {
            currentSlideTexts.add(text);
          }
        }
        currentRun.clear();
        i += 2;
      }
    }

    if (currentRun.length >= 2) {
      final text = currentRun.toString().trim();
      if (!_isNoise(text)) {
        currentSlideTexts.add(text);
      }
    }

    if (currentSlideTexts.isNotEmpty) {
      slideTextGroups.add(currentSlideTexts);
    }

    // 2. If UTF-16LE yielded no groups, try 8-bit text streams (CP1251 / Latin1)
    if (slideTextGroups.isEmpty) {
      currentSlideTexts = [];
      currentRun.clear();
      for (int b = 512; b < bytes.length; b++) {
        final byte = bytes[b];
        if (byte == 0x0D || byte == 0x0A || byte == 0x0C) {
          final text = currentRun.toString().trim();
          if (text.length >= 2 && !_isNoise(text)) {
            currentSlideTexts.add(text);
            if (currentSlideTexts.length >= 5 || byte == 0x0C) {
              slideTextGroups.add(List.from(currentSlideTexts));
              currentSlideTexts.clear();
            }
          }
          currentRun.clear();
        } else if ((byte >= 32 && byte <= 126) || (byte >= 0xC0 && byte <= 0xFF)) {
          // CP1251 Cyrillic or ASCII
          if (byte >= 0xC0 && byte <= 0xFF) {
            // Map CP1251 byte to unicode
            currentRun.write(String.fromCharCode(0x0410 + (byte - 0xC0)));
          } else {
            currentRun.write(String.fromCharCode(byte));
          }
        } else {
          if (currentRun.length >= 3) {
            final text = currentRun.toString().trim();
            if (!_isNoise(text)) {
              currentSlideTexts.add(text);
            }
          }
          currentRun.clear();
        }
      }

      if (currentRun.length >= 2) {
        final text = currentRun.toString().trim();
        if (!_isNoise(text)) {
          currentSlideTexts.add(text);
        }
      }

      if (currentSlideTexts.isNotEmpty) {
        slideTextGroups.add(currentSlideTexts);
      }
    }

    final List<PptxSlide> slides = [];
    for (int s = 0; s < slideTextGroups.length; s++) {
      final texts = slideTextGroups[s];
      final title = texts.isNotEmpty ? texts.first : 'Slide ${s + 1}';
      final bodyTexts = texts.length > 1 ? texts.sublist(1) : <String>[];

      final List<PptxParagraph> paragraphs = bodyTexts.map((t) {
        return PptxParagraph(
          runs: [PptxRun(text: t)],
          isBullet: true,
        );
      }).toList();

      slides.add(
        PptxSlide(
          slideNumber: s + 1,
          title: title,
          shapes: [
            PptxShape(paragraphs: paragraphs),
          ],
        ),
      );
    }

    return PptxPresentation(slides: slides);
  }

  static PptxPresentation _parsePlainTextPpt(Uint8List bytes) {
    String decoded;
    try {
      decoded = utf8.decode(bytes);
    } catch (_) {
      decoded = latin1.decode(bytes);
    }

    final lines = decoded
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const PptxPresentation(slides: []);
    }

    // Group every 4 lines into a slide
    final List<PptxSlide> slides = [];
    int slideIndex = 1;

    for (int i = 0; i < lines.length; i += 4) {
      final chunk = lines.sublist(i, (i + 4 < lines.length) ? i + 4 : lines.length);
      final title = chunk.first;
      final body = chunk.length > 1 ? chunk.sublist(1) : <String>[];

      slides.add(
        PptxSlide(
          slideNumber: slideIndex++,
          title: title,
          shapes: [
            PptxShape(
              paragraphs: body.map((b) => PptxParagraph(runs: [PptxRun(text: b)], isBullet: true)).toList(),
            ),
          ],
        ),
      );
    }

    return PptxPresentation(slides: slides);
  }

  static bool _isValidCharCode(int code) {
    if (code >= 32 && code <= 126) return true; // Standard ASCII
    if (code >= 0x0400 && code <= 0x04FF) return true; // Cyrillic
    if (code >= 0x0370 && code <= 0x03FF) return true; // Greek
    if (code >= 0x00A0 && code <= 0x024F) return true; // Latin Extended
    if (code == 9 || code == 10 || code == 13) return true;
    return false;
  }

  static bool _isNoise(String text) {
    if (text.startsWith('PowerPoint Document') ||
        text.startsWith('Current User') ||
        text.contains('Root Entry') ||
        text.contains('SummaryInformation')) {
      return true;
    }
    return false;
  }
}
