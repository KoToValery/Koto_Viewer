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
    var cleaned = rawText
        .replaceAll('\u00AD', '') // Soft hyphen (renders as tofu square with X)
        .replaceAll('\uFEFF', '') // Zero-width no-break space
        .replaceAll('\u200B', '') // Zero-width space
        .replaceAll('\u200C', '') // Zero-width non-joiner
        .replaceAll('\u200D', '') // Zero-width joiner
        .replaceAll('\u001F', ''); // Unit separator

    // Line-break hyphenation for Latin, Cyrillic, Greek, and all Unicode alphabets
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\p{L}\p{N}]+)[-\u2010\u2011\u2013\u2212\uFFFD]\s*[\r\n]+\s*([\p{L}\p{N}]+)', unicode: true),
      (m) => '${m[1]}${m[2]}',
    );

    // Embedded replacement char (tofu square with X) inside a word
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([\p{L}\p{N}])[\uFFFD]([\p{L}\p{N}])', unicode: true),
      (m) => '${m[1]}${m[2]}',
    );

    cleaned = cleaned.replaceAll('\uFFFD', '');
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1E]'), '');
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
