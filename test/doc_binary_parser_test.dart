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

    test('parses RTF .doc format with Cyrillic escapes and strips field codes', () {
      // RTF with title, field instruction {\*\fldinst PAGE \* MERGEFORMAT} and result {\fldrslt 1}
      final rtfString = r'{\rtf1\ansi\ansicpg1251\deff0'
          r'{\fonttbl{\f0\fnil\fcharset204 Arial;}}'
          r'{\field{\*\fldinst PAGE \* MERGEFORMAT}{\fldrslt 1}}'
          r'\viewkind4\uc1\pard\lang1026\b\f0\fs28 Обяснителна записка\b0\par'
          r'\fs20 Настоящият проект съдържа архитектурни чертежи.\par}';
      final bytes = Uint8List.fromList(utf8.encode(rtfString));

      final doc = DocParser.parse(bytes);
      expect(doc.blocks.length >= 2, true);
      expect((doc.blocks[0] as DocxParagraph).plainText, contains('Обяснителна записка'));
      expect((doc.blocks[1] as DocxParagraph).plainText, contains('архитектурни чертежи'));

      // Ensure no field code leaked
      for (final block in doc.blocks) {
        if (block is DocxParagraph) {
          expect(block.plainText.contains('MERGEFORMAT'), false);
          expect(block.plainText.contains('fldinst'), false);
        }
      }
    });

    test('parses RTF tables into DocxTable with rows and cells', () {
      final rtfTable = r'{\rtf1\ansi\deff0'
          r'\trowd\cellx2000\cellx4000'
          r'\intbl №\cell\intbl Име\cell\row'
          r'\trowd\cellx2000\cellx4000'
          r'\intbl 1\cell\intbl Валери\cell\row'
          r'\pard Край на документа\par}';
      final bytes = Uint8List.fromList(utf8.encode(rtfTable));

      final doc = DocParser.parse(bytes);
      expect(doc.tableCount, 1);
      final table = doc.blocks.whereType<DocxTable>().first;
      expect(table.rowCount, 2);
      expect(table.rows[0].cells[0].plainText, '№');
      expect(table.rows[0].cells[1].plainText, 'Име');
      expect(table.rows[1].cells[0].plainText, '1');
      expect(table.rows[1].cells[1].plainText, 'Валери');
    });

    test('parses OLE CFBF binary stream text, strips field codes and reconstructs tables', () {
      // Simulate binary OLE header and WordDocument stream with UTF-16LE text and table cells (0x07)
      final header = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

      // Document text containing a title, table with 0x07 cells, and Word field 0x13..0x14..0x15
      final textParts = [
        'Архитектурна записка\r',
        'Колона 1\x07Колона 2\x07\r',
        'Стойност A\x07Стойност B\x07\r',
        '\x13PAGE \\* MERGEFORMAT\x141\x15\r',
        'Край\r',
      ];

      final utf16Bytes = <int>[];
      for (final part in textParts) {
        for (final codeUnit in part.codeUnits) {
          utf16Bytes.add(codeUnit & 0xFF);
          utf16Bytes.add((codeUnit >> 8) & 0xFF);
        }
      }

      final fullBytes = Uint8List.fromList([
        ...header,
        ...List.filled(504, 0), // pad header to 512 bytes sector
        ...utf16Bytes,
      ]);

      final doc = DocParser.parse(fullBytes);
      expect(doc.blocks.isNotEmpty, true);
      expect(doc.blocks[0] is DocxParagraph, true);
      expect((doc.blocks[0] as DocxParagraph).plainText, contains('Архитектурна записка'));

      // Check table reconstructed
      expect(doc.tableCount, 1);
      final table = doc.blocks.whereType<DocxTable>().first;
      expect(table.rowCount, 2);
      expect(table.rows[0].cells[0].plainText, 'Колона 1');
      expect(table.rows[0].cells[1].plainText, 'Колона 2');

      // Verify no PAGE \* MERGEFORMAT field instructions
      for (final block in doc.blocks) {
        if (block is DocxParagraph) {
          expect(block.plainText.contains('MERGEFORMAT'), false);
        }
      }
    });

    test('parses 8-bit CP1251 multi-page Word .doc binary streams', () {
      final header = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

      // Build 8-bit CP1251 bytes:
      // 'Страница 1: Обяснителна записка\rСтраница 2: Таблични данни\rСтраница 3: Заключение\r'
      final cp1251Bytes = <int>[];
      final rawLines = [
        'Страница 1: Обяснителна записка\r',
        'Страница 2: Таблични данни\r',
        'Страница 3: Заключение\r',
      ];
      for (final line in rawLines) {
        for (final codeUnit in line.codeUnits) {
          if (codeUnit >= 0x0410 && codeUnit <= 0x044F) {
            cp1251Bytes.add(0xC0 + (codeUnit - 0x0410));
          } else {
            cp1251Bytes.add(codeUnit);
          }
        }
      }

      final fullBytes = Uint8List.fromList([
        ...header,
        ...List.filled(504, 0),
        ...cp1251Bytes,
      ]);

      final doc = DocParser.parse(fullBytes);
      expect(doc.paragraphCount, 3);
      expect((doc.blocks[0] as DocxParagraph).plainText, contains('Страница 1'));
      expect((doc.blocks[1] as DocxParagraph).plainText, contains('Страница 2'));
      expect((doc.blocks[2] as DocxParagraph).plainText, contains('Страница 3'));
    });

    test('cleanWordText utility cleans stray field and style noise', () {
      final dirtyText = 'PAGE \\* MERGEFORMAT 123 Table Normal';
      final cleaned = DocParser.cleanWordText(dirtyText);
      expect(cleaned.contains('MERGEFORMAT'), false);
      expect(cleaned.contains('PAGE'), false);
    });
  });
}
