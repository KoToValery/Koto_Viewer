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

        // Clean up hyphenated line breaks (e.g. "com- \n puter" -> "computer")
        final cleanedText = rawBlockText
            .replaceAll(RegExp(r'(\w+)-\s*\n\s*(\w+)'), r'$1$2')
            .replaceAll(RegExp(r'\n+'), ' ')
            .trim();

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

  /// Closes and frees OCR engine resources.
  static Future<void> dispose() async {
    if (_recognizer != null) {
      await _recognizer!.close();
      _recognizer = null;
    }
  }
}
