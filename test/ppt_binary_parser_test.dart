import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pptx_viewer/parser/ppt_parser.dart';

void main() {
  group('PptParser (Binary .PPT & Fallback) Tests', () {
    test('parses plain text fallback presentation into slides', () {
      final text = 'Въведение в KotoView\n'
          'Мощен файлов четец за Flutter\n'
          'Поддръжка на CAD и 3D\n'
          'PDF и офис формати\n'
          'Архитектурен модул\n'
          'BGS2005 Кадастрални координати\n'
          'Автоматично разпознаване на слоеве';

      final bytes = Uint8List.fromList(utf8.encode(text));
      final presentation = PptParser.parse(bytes);

      expect(presentation.slideCount >= 2, true);
      expect(presentation.slides[0].title, 'Въведение в KotoView');
      expect(presentation.slides[0].shapes.isNotEmpty, true);
      expect(presentation.slides[1].title, 'Архитектурен модул');
    });

    test('parses binary OLE Compound PowerPoint stream', () {
      final header = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
      final titleText = 'Слайд 1: Генерален план';
      final bodyText = 'Точки и геодезически измервания';

      final utf16Bytes = <int>[];
      for (final codeUnit in titleText.codeUnits) {
        utf16Bytes.add(codeUnit & 0xFF);
        utf16Bytes.add((codeUnit >> 8) & 0xFF);
      }
      utf16Bytes.add(0x0D);
      utf16Bytes.add(0x00);
      for (final codeUnit in bodyText.codeUnits) {
        utf16Bytes.add(codeUnit & 0xFF);
        utf16Bytes.add((codeUnit >> 8) & 0xFF);
      }

      final fullBytes = Uint8List.fromList([
        ...header,
        ...List.filled(504, 0),
        ...utf16Bytes,
      ]);

      final presentation = PptParser.parse(fullBytes);
      expect(presentation.slideCount >= 1, true);
      expect(presentation.slides[0].title, contains('Слайд 1'));
      expect(presentation.slides[0].shapes[0].plainText, contains('Точки и геодезически'));
    });
  });
}
