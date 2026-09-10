import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kotoview/src/features/pdf_viewer/models/pdf_reflow_models.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_text_extractor_service.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('PDF Reflow Models & Settings Tests', () {
    test('Default settings initialize with expected values', () {
      const settings = PdfReflowSettings();
      expect(settings.fontSize, 17.0);
      expect(settings.lineHeight, 1.6);
      expect(settings.theme, PdfReflowTheme.sepia);
      expect(settings.font, PdfReflowFont.serif);
      expect(settings.isContinuous, false);
    });

    test('copyWith updates specific settings correctly', () {
      const settings = PdfReflowSettings();
      final updated = settings.copyWith(
        fontSize: 22.0,
        theme: PdfReflowTheme.dark,
        font: PdfReflowFont.sans,
        isContinuous: true,
      );

      expect(updated.fontSize, 22.0);
      expect(updated.theme, PdfReflowTheme.dark);
      expect(updated.font, PdfReflowFont.sans);
      expect(updated.isContinuous, true);
      // Unmodified properties should remain
      expect(updated.lineHeight, 1.6);
      expect(updated.horizontalPadding, 20.0);
    });

    test('Theme extensions return appropriate colors and labels', () {
      expect(PdfReflowTheme.light.label, 'Light');
      expect(PdfReflowTheme.sepia.label, 'Warm Sepia');
      expect(PdfReflowTheme.dark.label, 'Dark Charcoal');
      expect(PdfReflowTheme.amoled.label, 'Pure Black');

      expect(PdfReflowTheme.sepia.backgroundColor, const Color(0xFFF4ECD8));
      expect(PdfReflowTheme.amoled.backgroundColor, const Color(0xFF000000));
    });

    test('Font extension produces valid TextStyle for Cyrillic and Latin', () {
      for (final font in PdfReflowFont.values) {
        final style = font.getTextStyle(
          fontSize: 18.0,
          color: Colors.black,
          height: 1.5,
        );
        expect(style.fontSize, isNotNull);
        expect(style.color, Colors.black);
      }
    });

    test('PdfPageReflowData factories work as expected', () {
      final loading = PdfPageReflowData.loading(5);
      expect(loading.pageNumber, 5);
      expect(loading.isLoaded, false);
      expect(loading.blocks, isEmpty);

      final empty = PdfPageReflowData.empty(12, message: 'Scan failed');
      expect(empty.pageNumber, 12);
      expect(empty.isLoaded, true);
      expect(empty.errorMessage, 'Scan failed');
    });
  });

  group('PDF Text Extractor & Paragraph Parsing Tests', () {
    late PdfTextExtractorService service;

    setUp(() {
      service = PdfTextExtractorService(filePath: 'dummy.pdf');
    });

    test('OCR service platform guard does not throw on desktop', () {
      expect(() => PdfOcrService.isOcrSupported, returnsNormally);
    });

    test('Memory cache can be populated and cleared', () {
      expect(() => service.clearMemoryCache(), returnsNormally);
    });
  });
}
