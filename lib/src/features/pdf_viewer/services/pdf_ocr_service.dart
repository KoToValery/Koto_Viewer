import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_reflow_models.dart';

/// Service for Optical Character Recognition (OCR) on scanned PDF pages.
/// Runs locally on-device without external servers or fees.
class PdfOcrService {
  static TextRecognizer? _recognizer;

  static TextRecognizer _getRecognizer() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Whether OCR is supported on the current running platform.
  static bool get isOcrSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Performs OCR on a rendered [PdfPage].
  /// Renders the page at high resolution, passes to on-device OCR engine,
  /// and structures the output into paragraphs.
  static Future<List<PdfReflowBlock>> performOcrOnPage(PdfPage page) async {
    if (!isOcrSupported) {
      debugPrint('[PdfOcrService] OCR is not supported on desktop/web platforms.');
      return [
        const PdfReflowBlock(
          text: 'This page is a scanned image. On-device OCR is supported on mobile devices (Android / iOS).',
          isHeading: false,
          isOcr: true,
        ),
      ];
    }

    File? tempImageFile;
    PdfImage? pdfImage;

    try {
      // Render page at high quality (2.5x scaling for sharp character recognition)
      final renderScale = 2.5;
      final targetWidth = (page.width * renderScale).toInt().clamp(1200, 2400);
      final targetHeight = (page.height * renderScale).toInt().clamp(1600, 3400);

      pdfImage = await page.render(
        fullWidth: targetWidth.toDouble(),
        fullHeight: targetHeight.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );

      if (pdfImage == null) {
        return const [];
      }

      // Convert BGRA raw buffer into JPEG for ML Kit
      final convertedImage = img.Image.fromBytes(
        width: pdfImage.width,
        height: pdfImage.height,
        bytes: pdfImage.pixels.buffer,
        order: img.ChannelOrder.bgra,
      );

      final tempDir = await getTemporaryDirectory();
      tempImageFile = File('${tempDir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await tempImageFile.writeAsBytes(img.encodeJpg(convertedImage, quality: 88));

      // Process via Google ML Kit
      final inputImage = InputImage.fromFile(tempImageFile);
      final recognizer = _getRecognizer();
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);

      final blocks = <PdfReflowBlock>[];
      for (final textBlock in recognizedText.blocks) {
        final rawBlockText = textBlock.text.trim();
        if (rawBlockText.isEmpty) continue;

        final cleanedText = cleanReflowText(rawBlockText);

        if (cleanedText.isNotEmpty) {
          // Detect short uppercase or title-like lines as headings
          final isHeading = cleanedText.length < 50 &&
              (cleanedText == cleanedText.toUpperCase() || cleanedText.endsWith(':'));

          blocks.add(PdfReflowBlock(
            text: cleanedText,
            isHeading: isHeading,
            isOcr: true,
          ));
        }
      }

      return blocks;
    } catch (e, stack) {
      debugPrint('[PdfOcrService] Error during OCR: $e\n$stack');
      return [
        PdfReflowBlock(
          text: 'Error recognizing text on this scanned page: $e',
          isHeading: false,
          isOcr: true,
        ),
      ];
    } finally {
      pdfImage?.dispose();
      if (tempImageFile != null && await tempImageFile.exists()) {
        try {
          await tempImageFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Cleans up raw OCR / PDF extracted text:
  /// - Removes soft hyphens (\u00AD), zero-width characters, and replacement chars (\uFFFD)
  ///   which otherwise render as a missing-glyph square-with-x ([x]) in many fonts.
  /// - Joins words split across lines by a hyphen for both Cyrillic and Latin alphabets.
  /// - Collapses intra-paragraph newlines and extra whitespaces.
  static String cleanReflowText(String rawText) {
    if (rawText.isEmpty) return rawText;

    var cleaned = rawText;

    // 1. Remove Soft Hyphen (U+00AD), Unit Separator (U+001F), Zero-Width chars,
    // and BOM which render as a missing-glyph square-with-x ([x]) or tofu in Flutter/Android.
    cleaned = cleaned
        .replaceAll('\u00AD', '') // Soft Hyphen (SHY)
        .replaceAll('\u001F', '') // Unit Separator
        .replaceAll('\uFEFF', '') // Zero-width no-break space
        .replaceAll('\u200B', '') // Zero-width space
        .replaceAll('\u200C', '') // Zero-width non-joiner
        .replaceAll('\u200D', '') // Zero-width joiner
        .replaceAll('\u2060', ''); // Word joiner

    // 2. Fix line-break hyphenation: e.g. "пре- \n несена" or "пре-\nнесена"
    // Supports any dash/hyphen variant (-, \u2010, \u2011, \u2012, \u2013, \u2014, \u2212, \uFFFD, \u00AC)
    // Matches any Unicode letter in any alphabet (Cyrillic, Latin, Greek, etc.)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\p{L}\p{N}]+)\s*[-\u2010\u2011\u2012\u2013\u2014\u2212\uFFFD\u00AC]\s*[\r\n]+\s*([\p{L}\p{N}]+)', unicode: true),
      (m) => '${m[1]}${m[2]}',
    );

    // 3. Fix words that were ALREADY joined on a single line by OCR or PDF text extraction,
    // but have an embedded soft hyphen / tofu / non-breaking hyphen / replacement char / PUA char / square symbol:
    // e.g. "прене\uFFFDсена" -> "пренесена", "литера\u2011тура" -> "литература", "дума\u00ACта" -> "думата"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\p{L}\p{N}])\s*[\u2010\u2011\uFFFD\u00AC\uE000-\uF8FF\u2300-\u23FF\u25A0-\u26FF\u001F]\s*([\p{L}\p{N}])', unicode: true),
      (m) => '${m[1]}${m[2]}',
    );

    // 4. Remove all remaining replacement chars (U+FFFD), PUA chars (U+E000-U+F8FF),
    // and geometric / box tofu symbols (U+2300-U+26FF like ⌧, ☒, □)
    cleaned = cleaned
        .replaceAll('\uFFFD', '')
        .replaceAll('\u00AC', '')
        .replaceAll(RegExp(r'[\uE000-\uF8FF]'), '')
        .replaceAll(RegExp(r'[\u2327\u2610\u2612\u25A0-\u25FF]'), '');

    // 5. Replace obscure non-breaking hyphens with standard ASCII hyphen '-'
    cleaned = cleaned
        .replaceAll('\u2010', '-')
        .replaceAll('\u2011', '-')
        .replaceAll('\uFE63', '-')
        .replaceAll('\uFF0D', '-');

    // 6. Remove non-printable ASCII/C0/C1 control characters (keep \n, \r, \t)
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]'), '');

    // 7. Collapse newlines and multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'[\r\n]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();

    return cleaned;
  }

  /// Closes and frees OCR engine resources.
  static Future<void> dispose() async {
    if (_recognizer != null) {
      await _recognizer!.close();
      _recognizer = null;
    }
  }
}
