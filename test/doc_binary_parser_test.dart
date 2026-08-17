import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/docx_viewer/models/docx_models.dart';
import 'package:kotoview/src/features/docx_viewer/parser/doc_parser.dart';

void main() {
  group('DocParser (Binary .DOC, RTF, and Fallback) Tests', () {
    test('parses plain text / utf8 fallback .doc', () {
      final text = 'Здравейте, това е тестов Word документ.';
      final bytes = Uint8List.fromList(utf8.encode(text));

      final doc = DocParser.parse(bytes);
      expect(doc.blocks.isNotEmpty, true);
      expect(doc.blocks.first is DocxParagraph, true);
      expect((doc.blocks.first as DocxParagraph).plainText, contains('Здравейте'));
    });

    test('parses RTF .doc format with Cyrillic escapes', () {
      // Simple RTF with title and paragraph
      final rtfString = r'{\rtf1\ansi\ansicpg1251\deff0'
          r'{\fonttbl{\f0\fnil\fcharset204 Arial;}}'
          r'\viewkind4\uc1\pard\lang1026\b\f0\fs28 Заглавие на документа\b0\par'
          r'\fs20 Това е втори параграф от документа.\par}';
      final bytes = Uint8List.fromList(utf8.encode(rtfString));

      final doc = DocParser.parse(bytes);
      expect(doc.blocks.length >= 2, true);
      expect((doc.blocks[0] as DocxParagraph).plainText, contains('Заглавие на документа'));
      expect((doc.blocks[1] as DocxParagraph).plainText, contains('Това е втори параграф'));
    });

    test('parses OLE CFBF binary stream text', () {
      // Simulate binary OLE header and WordDocument stream with UTF-16LE Cyrillic
      final header = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
      final cyrillicText = 'Тестови данни от Word 97-2003';
      final utf16Bytes = <int>[];
      for (final codeUnit in cyrillicText.codeUnits) {
        utf16Bytes.add(codeUnit & 0xFF);
        utf16Bytes.add((codeUnit >> 8) & 0xFF);
      }

      final fullBytes = Uint8List.fromList([
        ...header,
        ...List.filled(504, 0), // pad header to 512 bytes sector
        ...utf16Bytes,
      ]);

      final doc = DocParser.parse(fullBytes);
      expect(doc.blocks.isNotEmpty, true);
      expect((doc.blocks.first as DocxParagraph).plainText, contains('Тестови данни'));
    });
  });
}
