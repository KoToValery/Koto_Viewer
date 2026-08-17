import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as xl;
import 'package:kotoview/src/core/models/pdf_item.dart';

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
