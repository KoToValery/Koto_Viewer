import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as xl;
import 'package:archive/archive.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/docx_viewer/models/docx_models.dart';
import 'package:kotoview/src/features/docx_viewer/parser/docx_parser.dart';

void main() {
  group('Document & Spreadsheet File Type Tests', () {
    test('PdfItem correctly identifies .xlsx and .xls spreadsheets', () {
      final xlsxItem = PdfItem(
        path: '/storage/emulated/0/Download/КС_Митови_Бл_Чуката.xlsx',
        name: 'КС_Митови_Бл_Чуката.xlsx',
        sizeInBytes: 102400,
        lastOpened: DateTime.now(),
      );
      expect(xlsxItem.fileType, equals(KotoFileType.xlsx));
      expect(xlsxItem.isXlsx, isTrue);
      expect(xlsxItem.isCad, isFalse);

      final xlsItem = PdfItem(
        path: '/storage/emulated/0/Download/Report.xls',
        name: 'Report.xls',
        sizeInBytes: 51200,
        lastOpened: DateTime.now(),
      );
      expect(xlsItem.fileType, equals(KotoFileType.xlsx));
      expect(xlsItem.isXlsx, isTrue);
    });

    test('PdfItem correctly identifies .txt, .log, and .csv text files', () {
      final txtItem = PdfItem(
        path: '/storage/emulated/0/Download/coordinates_bgs2005.txt',
        name: 'coordinates_bgs2005.txt',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );
      expect(txtItem.fileType, equals(KotoFileType.txt));
      expect(txtItem.isTxt, isTrue);
      expect(txtItem.isTextDoc, isTrue);

      final logItem = PdfItem(
        path: '/storage/emulated/0/Download/gps_survey.log',
        name: 'gps_survey.log',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );
      expect(logItem.fileType, equals(KotoFileType.txt));

      final csvItem = PdfItem(
        path: '/storage/emulated/0/Download/points.csv',
        name: 'points.csv',
        sizeInBytes: 3072,
        lastOpened: DateTime.now(),
      );
      expect(csvItem.fileType, equals(KotoFileType.txt));
    });

    test('PdfItem correctly identifies .md and .markdown files', () {
      final mdItem = PdfItem(
        path: '/storage/emulated/0/Download/README.md',
        name: 'README.md',
        sizeInBytes: 1500,
        lastOpened: DateTime.now(),
      );
      expect(mdItem.fileType, equals(KotoFileType.md));
      expect(mdItem.isMd, isTrue);
      expect(mdItem.isTextDoc, isTrue);

      final markdownItem = PdfItem(
        path: '/storage/emulated/0/Download/spec.markdown',
        name: 'spec.markdown',
        sizeInBytes: 2500,
        lastOpened: DateTime.now(),
      );
      expect(markdownItem.fileType, equals(KotoFileType.md));
    });

    test('PdfItem correctly identifies .docx Word documents', () {
      final docxItem = PdfItem(
        path: 'E:/OneDrive - Пирин Дизайн Студио/РАБОТНИ_облак/ТЕМПЛЕЙТ_ПАПКИ/ДОКУМЕНТИ/ЧЕЛЕН ЛИСТ.docx',
        name: 'ЧЕЛЕН ЛИСТ.docx',
        sizeInBytes: 15000,
        lastOpened: DateTime.now(),
      );
      expect(docxItem.fileType, equals(KotoFileType.docx));
      expect(docxItem.isDocx, isTrue);
      expect(docxItem.isTextDoc, isTrue);
    });
  });

  group('DOCX Parser & Page Geometry Tests', () {
    test('DocxPageSettings correctly models standard A4 Portrait', () {
      const a4 = DocxPageSettings(
        widthPt: 595.3,
        heightPt: 841.9,
        isLandscape: false,
        paperName: 'A4',
      );
      expect(a4.aspectRatio, closeTo(0.707, 0.01));
      expect(a4.isLandscape, isFalse);
      expect(a4.paperName, equals('A4'));
      expect(a4.contentWidthPt, greaterThan(400));
    });

    test('Parses DOCX document XML with A4 Portrait and Tables with Borders', () {
      const documentXmlContent = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Title"/>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="32"/>
        </w:rPr>
        <w:t>ЧЕЛЕН ЛИСТ - ОБЕКТ</w:t>
      </w:r>
    </w:p>
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="9000" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/>
          <w:left w:val="single" w:sz="8" w:space="0" w:color="000000"/>
          <w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/>
          <w:right w:val="single" w:sz="8" w:space="0" w:color="000000"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CCCCCC"/>
        </w:tblBorders>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="3000"/>
        <w:gridCol w:w="6000"/>
      </w:tblGrid>
      <w:tr>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="3000" w:type="dxa"/>
            <w:shd w:val="clear" w:color="auto" w:fill="F1F5F9"/>
          </w:tcPr>
          <w:p>
            <w:r><w:rPr><w:b/></w:rPr><w:t>Проектант:</w:t></w:r>
          </w:p>
        </w:tc>
        <w:tc>
          <w:tcPr>
            <w:tcW w:w="6000" w:type="dxa"/>
          </w:tcPr>
          <w:p>
            <w:r><w:t>инж. Иван Иванов</w:t></w:r>
          </w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838" w:orient="portrait"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>
''';

      // Create a mock docx in memory (zip with word/document.xml)
      final archive = Archive();
      final xmlBytes = utf8.encode(documentXmlContent);
      archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final zipEncoder = ZipEncoder();
      final docxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      final doc = DocxParser.parse(docxBytes);
      expect(doc, isNotNull);
      expect(doc.paragraphCount, equals(1));
      expect(doc.tableCount, equals(1));

      // Check page settings (A4 Portrait = 11906 / 20 = 595.3 pt, 16838 / 20 = 841.9 pt)
      expect(doc.pageSettings.widthPt, closeTo(595.3, 0.5));
      expect(doc.pageSettings.heightPt, closeTo(841.9, 0.5));
      expect(doc.pageSettings.isLandscape, isFalse);
      expect(doc.pageSettings.paperName, equals('A4'));
      expect(doc.pageSettings.margins.left, equals(72.0)); // 1440 / 20 = 72 pt (1 inch)

      // Check table properties
      final table = doc.blocks.whereType<DocxTable>().first;
      expect(table.columnWidths.length, equals(2));
      expect(table.columnWidths[0], equals(150.0)); // 3000 / 20 = 150 pt
      expect(table.columnWidths[1], equals(300.0)); // 6000 / 20 = 300 pt
      expect(table.borders, isNotNull);
      expect(table.borders!.top?.hasBorder, isTrue);
      expect(table.borders!.top?.width, equals(1.0)); // 8 / 8 = 1.0 pt
    });

    test('Parses paragraph-level formatting fallbacks and table row heights', () {
      const xmlStr = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:rPr>
          <w:sz w:val="48"/>
          <w:rFonts w:ascii="Tahoma"/>
        </w:rPr>
      </w:pPr>
      <w:r><w:t>ОБЕКТ:</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:trPr><w:trHeight w:val="1094"/></w:trPr>
        <w:tc>
          <w:tcPr><w:tcW w:w="886" w:type="dxa"/></w:tcPr>
          <w:p><w:r><w:t>1.</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
''';
      final archive = Archive();
      final xmlBytes = utf8.encode(xmlStr);
      archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final doc = DocxParser.parse(docxBytes);
      final p = doc.blocks.whereType<DocxParagraph>().first;
      expect(p.runs.first.fontSize, equals(24.0)); // 48 / 2 = 24 pt fallback
      expect(p.runs.first.fontFamily, equals('Tahoma'));

      final tbl = doc.blocks.whereType<DocxTable>().first;
      expect(tbl.rows.first.heightPt, closeTo(54.7, 0.1)); // 1094 / 20 = 54.7 pt
    });

    test('Parses paragraph alignments, indents, and style inheritance correctly', () {
      const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:pPr>
      <w:jc w:val="both"/>
    </w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="CustomHeading">
    <w:name w:val="CustomHeading"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:ind w:left="360" w:right="180"/>
    </w:pPr>
  </w:style>
</w:styles>''';

      const docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="CustomHeading"/>
      </w:pPr>
      <w:r><w:t>ДОГОВОР</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:jc w:val="right"/>
        <w:ind w:firstLine="720"/>
      </w:pPr>
      <w:r><w:t>Десен текст</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:ind w:hanging="360"/>
      </w:pPr>
      <w:r><w:t>Окачен отстъп</w:t></w:r>
    </w:p>
  </w:body>
</w:document>''';

      final archive = Archive();
      final sBytes = utf8.encode(stylesXml);
      final dBytes = utf8.encode(docXml);
      archive.addFile(ArchiveFile('word/styles.xml', sBytes.length, sBytes));
      archive.addFile(ArchiveFile('word/document.xml', dBytes.length, dBytes));
      final zipEncoder = ZipEncoder();
      final docxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      final doc = DocxParser.parse(docxBytes);
      expect(doc.blocks.length, equals(3));

      final p0 = doc.blocks[0] as DocxParagraph;
      expect(p0.plainText, equals('ДОГОВОР'));
      expect(p0.alignment, equals(TextAlign.center));
      expect(p0.indentLeft, equals(18.0)); // 360 / 20
      expect(p0.indentRight, equals(9.0)); // 180 / 20

      final p1 = doc.blocks[1] as DocxParagraph;
      expect(p1.plainText, equals('Десен текст'));
      expect(p1.alignment, equals(TextAlign.right));
      expect(p1.indentFirstLine, equals(36.0)); // 720 / 20

      final p2 = doc.blocks[2] as DocxParagraph;
      expect(p2.plainText, equals('Окачен отстъп'));
      expect(p2.indentFirstLine, equals(-18.0)); // -360 / 20
    });

    test('Correctly identifies borderless tables for signature layout', () {
      const borderlessTblXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:jc w:val="center"/>
      </w:tblPr>
      <w:tr>
        <w:tc>
          <w:p><w:r><w:t>ИЗПЪЛНИТЕЛ</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:p><w:r><w:t>ВЪЗЛОЖИТЕЛ</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';

      final archive = Archive();
      final dBytes = utf8.encode(borderlessTblXml);
      archive.addFile(ArchiveFile('word/document.xml', dBytes.length, dBytes));
      final zipEncoder = ZipEncoder();
      final docxBytes = Uint8List.fromList(zipEncoder.encode(archive)!);

      final doc = DocxParser.parse(docxBytes);
      final tbl = doc.blocks.whereType<DocxTable>().first;
      expect(tbl.hasAnyBorder, isFalse);
      expect(tbl.borders, isNull);
    });
  });

  group('Excel Parser & Cyrillic Handling Tests', () {
    test('Encodes and decodes multi-sheet Excel workbook with Cyrillic text', () {
      final excel = xl.Excel.createExcel();
      excel.rename('Sheet1', 'Архитектура');
      final archSheet = excel['Архитектура'];

      // Row 0: Headers
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          xl.TextCellValue('Поз.');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          xl.TextCellValue('Описание на СМР');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          xl.TextCellValue('Мярка');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          xl.DoubleCellValue(4.5);

      // Row 1: Item
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
          xl.TextCellValue('1.1');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value =
          xl.TextCellValue('Доставка и монтаж на PVC тръби ф 160 мм');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value =
          xl.TextCellValue('мл.');
      archSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value =
          xl.DoubleCellValue(120.0);

      // Add second sheet: 'ВиК СГРАДА'
      final vikSheet = excel['ВиК СГРАДА'];
      vikSheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          xl.TextCellValue('Водопроводна инсталация');

      final encodedBytes = excel.encode();
      expect(encodedBytes, isNotNull);
      expect(encodedBytes!.isNotEmpty, isTrue);

      // Decode back
      final decodedExcel = xl.Excel.decodeBytes(encodedBytes);
      expect(decodedExcel.tables.keys.contains('Архитектура'), isTrue);
      expect(decodedExcel.tables.keys.contains('ВиК СГРАДА'), isTrue);

      final decodedArch = decodedExcel.tables['Архитектура']!;
      expect(decodedArch.maxRows, greaterThanOrEqualTo(2));
      expect(decodedArch.maxColumns, greaterThanOrEqualTo(4));

      final descCell = decodedArch.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1));
      expect((descCell.value as xl.TextCellValue).value.text, contains('PVC тръби ф 160 мм'));
    });
  });

  group('Text & Markdown Reading Tests', () {
    test('Decodes Cyrillic UTF-8 text with coordinates', () {
      const text = '''
# КООРДИНАТЕН РЕГИСТЪР - ОБЕКТ: БЛ. ЧУКАТА
# Точка, X (север), Y (изток), H (височина)
101, 4725134.55, 345678.90, 120.45
102, 4725140.20, 345690.15, 121.00
103, 4725165.80, 345710.40, 121.80
''';

      final bytes = utf8.encode(text);
      final decoded = utf8.decode(bytes);
      final lines = decoded.trim().split(RegExp(r'\r?\n'));

      expect(lines.length, greaterThan(3));
      expect(lines[0], contains('КООРДИНАТЕН РЕГИСТЪР'));
      expect(lines[1], contains('Точка, X (север)'));
      expect(lines[2], contains('4725134.55'));
    });
  });
}
