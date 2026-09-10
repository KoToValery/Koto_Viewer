import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_ocr_service.dart';

void main() {
  test('PdfOcrService.cleanReflowText fixes all forms of hyphenation and square-with-x', () {
    // Standard hyphen wrapped across lines
    expect(PdfOcrService.cleanReflowText('пре-\nнесена'), equals('пренесена'));
    expect(PdfOcrService.cleanReflowText('пре- \n несена'), equals('пренесена'));
    expect(PdfOcrService.cleanReflowText('пре-\r\nнесена'), equals('пренесена'));

    // Embedded soft hyphen inside whole word on single line
    expect(PdfOcrService.cleanReflowText('литера\u00ADтура'), equals('литература'));

    // Embedded replacement char (tofu square with X) inside word on single line
    expect(PdfOcrService.cleanReflowText('литера\uFFFDтура'), equals('литература'));

    // Embedded non-breaking hyphen inside word
    expect(PdfOcrService.cleanReflowText('литера\u2011тура'), equals('литература'));

    // Embedded PUA character (custom PDF font hyphen)
    expect(PdfOcrService.cleanReflowText('литера\uE042тура'), equals('литература'));

    // Embedded literal square/ballot box with X
    expect(PdfOcrService.cleanReflowText('литера☒тура'), equals('литература'));
    expect(PdfOcrService.cleanReflowText('литера⌧тура'), equals('литература'));
    expect(PdfOcrService.cleanReflowText('литера□тура'), equals('литература'));

    // Embedded not-sign (Windows-1251 hyphen mapping)
    expect(PdfOcrService.cleanReflowText('литера\u00ACтура'), equals('литература'));

    // Compound word on same line preserved with regular hyphen
    expect(PdfOcrService.cleanReflowText('по-малко и най-добър'), equals('по-малко и най-добър'));
    expect(PdfOcrService.cleanReflowText('COVID-19'), equals('COVID-19'));
    expect(PdfOcrService.cleanReflowText('state-of-the-art'), equals('state-of-the-art'));
  });
}
