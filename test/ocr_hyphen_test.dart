import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_ocr_service.dart';

void main() {
  test('PdfOcrService.cleanReflowText fixes Cyrillic hyphenation and tofu square-with-x', () {
    expect(PdfOcrService.cleanReflowText('пре-\nнесена'), equals('пренесена'));
    expect(PdfOcrService.cleanReflowText('пре-\r\nнесена'), equals('пренесена'));
    expect(PdfOcrService.cleanReflowText('литера\u00ADтура'), equals('литература'));
    expect(PdfOcrService.cleanReflowText('литера\uFFFDтура'), equals('литература'));
    expect(PdfOcrService.cleanReflowText('инфор\u001Fмация'), equals('информация'));
    expect(PdfOcrService.cleanReflowText('по-малко и най-добър'), equals('по-малко и най-добър'));
    expect(PdfOcrService.cleanReflowText('connec-\ntion'), equals('connection'));
    expect(PdfOcrService.cleanReflowText('state-of-the-art'), equals('state-of-the-art'));
  });
}
