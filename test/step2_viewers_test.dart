import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/features/docx_viewer/models/docx_models.dart';
import 'package:kotoview/src/features/docx_viewer/parser/docx_parser.dart';
import 'package:kotoview/src/features/eps_viewer/models/eps_models.dart';
import 'package:kotoview/src/features/eps_viewer/parser/eps_parser.dart';

void main() {
  group('Step 2: File Type Identification Tests', () {
    test('PdfItem correctly identifies .docx and .doc files', () {
      final docxItem = PdfItem(
        path: '/storage/emulated/0/Download/Обяснителна_записка.docx',
        name: 'Обяснителна_записка.docx',
        sizeInBytes: 24576,
        lastOpened: DateTime.now(),
      );
      expect(docxItem.fileType, equals(KotoFileType.docx));
      expect(docxItem.isDocx, isTrue);
      expect(docxItem.isTextDoc, isTrue);

      final docItem = PdfItem(
        path: '/storage/emulated/0/Download/Contract.doc',
        name: 'Contract.doc',
        sizeInBytes: 30000,
        lastOpened: DateTime.now(),
      );
      expect(docItem.fileType, equals(KotoFileType.docx));
      expect(docItem.isDocx, isTrue);
    });

    test('PdfItem correctly identifies .eps vector files', () {
      final epsItem = PdfItem(
        path: '/storage/emulated/0/Download/cadastral_logo.eps',
        name: 'cadastral_logo.eps',
        sizeInBytes: 45000,
        lastOpened: DateTime.now(),
      );
      expect(epsItem.fileType, equals(KotoFileType.eps));
      expect(epsItem.isEps, isTrue);
      expect(epsItem.isVector, isTrue);
    });
  });

  group('DocxParser Tests', () {
    test('Parses Word XML structure with headings, formatted runs, and tables', () {
      const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
      </w:pPr>
      <w:r>
        <w:t>ОБЯСНИТЕЛНА ЗАПИСКА</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:rPr>
          <w:b/>
        </w:rPr>
        <w:t>Обект: </w:t>
      </w:r>
      <w:r>
        <w:rPr>
          <w:i/>
        </w:rPr>
        <w:t>Жилищна сграда в гр. София</w:t>
      </w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc>
          <w:p>
            <w:r><w:t>Показател</w:t></w:r>
          </w:p>
        </w:tc>
        <w:tc>
          <w:p>
            <w:r><w:t>Стойност</w:t></w:r>
          </w:p>
        </w:tc>
      </w:tr>
      <w:tr>
        <w:tc>
          <w:p>
            <w:r><w:t>РЗП</w:t></w:r>
          </w:p>
        </w:tc>
        <w:tc>
          <w:p>
            <w:r><w:t>1450.00 кв.м</w:t></w:r>
          </w:p>
        </w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';

      // Pack into in-memory zip archive
      final archive = Archive();
      final xmlBytes = utf8.encode(documentXml);
      archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final doc = DocxParser.parse(zipBytes);

      expect(doc.blocks.length, equals(3));
      expect(doc.paragraphCount, equals(2));
      expect(doc.tableCount, equals(1));
      expect(doc.headingCount, equals(1));

      final h1 = doc.blocks[0] as DocxParagraph;
      expect(h1.headingLevel, equals(DocxHeadingLevel.h1));
      expect(h1.plainText, equals('ОБЯСНИТЕЛНА ЗАПИСКА'));

      final p2 = doc.blocks[1] as DocxParagraph;
      expect(p2.runs.length, equals(2));
      expect(p2.runs[0].isBold, isTrue);
      expect(p2.runs[1].isItalic, isTrue);
      expect(p2.plainText, contains('Жилищна сграда в гр. София'));

      final tbl = doc.blocks[2] as DocxTable;
      expect(tbl.rowCount, equals(2));
      expect(tbl.columnCount, equals(2));
      expect(tbl.rows[1].cells[1].plainText, equals('1450.00 кв.м'));
    });
  });

  group('EpsParser Vector Tests', () {
    test('Parses ASCII EPS with BoundingBox and PostScript vector path operators', () {
      const psContent = '''%!PS-Adobe-3.0 EPSF-3.0
%%BoundingBox: 0 0 500 400
%%HiResBoundingBox: 0.0 0.0 500.0 400.0
%%Title: Cadastral Boundary Plan
%%Creator: Koto CAD Exporter
%%CreationDate: 2026-08-17

% Draw a blue border rectangle
0.0 0.2 0.8 setrgbcolor
2 setlinewidth
newpath
50 50 moveto
450 50 lineto
450 350 lineto
50 350 lineto
closepath
stroke

% Draw a filled red circle approximation with bezier curves
1.0 0.0 0.0 setrgbcolor
newpath
250 200 moveto
250 250 300 250 300 200 curveto
300 150 250 150 250 200 curveto
closepath
fill
%%EOF
''';

      final bytes = Uint8List.fromList(utf8.encode(psContent));
      final doc = EpsParser.parse(bytes);

      expect(doc.metadata.boundingBox.width, equals(500.0));
      expect(doc.metadata.boundingBox.height, equals(400.0));
      expect(doc.metadata.title, equals('Cadastral Boundary Plan'));
      expect(doc.metadata.creator, equals('Koto CAD Exporter'));

      expect(doc.paths.length, equals(2));

      // First path: stroke rectangle
      final strokePath = doc.paths[0];
      expect(strokePath.strokeColor, isNotNull);
      expect(strokePath.strokeWidth, equals(2.0));
      expect(strokePath.commands.length, equals(5)); // moveto, 3 lineto, closepath
      expect(strokePath.commands.first.type, equals(EpsCommandType.moveTo));
      expect(strokePath.commands.last.type, equals(EpsCommandType.closePath));

      // Second path: filled circle
      final fillPath = doc.paths[1];
      expect(fillPath.fillColor, isNotNull);
      expect(fillPath.commands.length, equals(4)); // moveto, 2 curveto, closepath
      expect(fillPath.commands[1].type, equals(EpsCommandType.cubicCurveTo));
    });

    test('Parses Binary DOS EPS header correctly', () {
      const psContent = '''%!PS-Adobe-3.0 EPSF-3.0
%%BoundingBox: 10 20 210 220
newpath
10 20 moveto
210 220 lineto
stroke
%%EOF
''';

      final psBytes = utf8.encode(psContent);
      const headerLength = 30;
      final totalBytes = Uint8List(headerLength + psBytes.length);

      // DOS EPS Magic: 0xC5D0D3C6
      totalBytes[0] = 0xC5;
      totalBytes[1] = 0xD0;
      totalBytes[2] = 0xD3;
      totalBytes[3] = 0xC6;

      // PS Offset = 30 (little-endian uint32)
      final byteData = ByteData.sublistView(totalBytes);
      byteData.setUint32(4, headerLength, Endian.little);
      byteData.setUint32(8, psBytes.length, Endian.little);

      // Copy PS bytes after header
      totalBytes.setRange(headerLength, headerLength + psBytes.length, psBytes);

      final doc = EpsParser.parse(totalBytes);
      expect(doc.metadata.boundingBox.minX, equals(10.0));
      expect(doc.metadata.boundingBox.minY, equals(20.0));
      expect(doc.metadata.boundingBox.maxX, equals(210.0));
      expect(doc.metadata.boundingBox.maxY, equals(220.0));
      expect(doc.paths.length, equals(1));
    });
  });
}
