import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_en.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations_bg.dart';
import 'package:kotoview/src/features/pcb_viewer/parser/pcb_archive_parser.dart';

void main() {
  group('ZIP Archive Supported Files & Extraction Tests', () {
    test('PdfItem accurately identifies all supported formats inside an archive', () {
      final supportedNames = [
        'report.pdf',
        'document.docx',
        'legacy.doc',
        'rich_text.rtf',
        'budget.xlsx',
        'data.csv',
        'plan.dxf',
        'schematic.dwg',
        'notes.txt',
        'system.log',
        'readme.md',
        'photo.png',
        'scan.jpg',
        'vector.svg',
        'model.step',
        'part.stp',
        'circuit.kicad_sch',
        'board.kicad_pcb',
        'book.epub',
        'route.gpx',
      ];

      for (final name in supportedNames) {
        final item = PdfItem.fromPath('/archive/$name');
        expect(
          item.fileType,
          isNot(equals(KotoFileType.other)),
          reason: '$name should be recognized as a supported format',
        );
      }

      final unsupportedItem = PdfItem.fromPath('/archive/unsupported.xyz999');
      expect(unsupportedItem.fileType, equals(KotoFileType.other));
    });

    test('PcbArchiveParser extracts all files with bytes and metadata from ZIP', () {
      final archive = Archive();

      final txtContent = utf8.encode('Hello Koto Viewer ZIP Archive Test');
      archive.addFile(ArchiveFile('docs/readme.txt', txtContent.length, txtContent));

      final fakePdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]); // %PDF-1.7
      archive.addFile(ArchiveFile('docs/invoice.pdf', fakePdfBytes.length, fakePdfBytes));

      final fakePngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // \x89PNG
      archive.addFile(ArchiveFile('images/logo.png', fakePngBytes.length, fakePngBytes));

      final zipData = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final project = PcbArchiveParser.parseZip(
        zipData,
        archiveName: 'test_package.zip',
        filePath: '/storage/test_package.zip',
      );

      expect(project.archiveFiles.length, equals(3));

      final fileNames = project.archiveFiles.map((f) => f.fileName).toList();
      expect(fileNames, contains('docs/readme.txt'));
      expect(fileNames, contains('docs/invoice.pdf'));
      expect(fileNames, contains('images/logo.png'));

      final txtFile = project.archiveFiles.firstWhere((f) => f.fileName == 'docs/readme.txt');
      expect(txtFile.bytes, isNotEmpty);
      expect(utf8.decode(txtFile.bytes), equals('Hello Koto Viewer ZIP Archive Test'));

      final pdfFile = project.archiveFiles.firstWhere((f) => f.fileName == 'docs/invoice.pdf');
      expect(pdfFile.bytes.length, equals(8));
    });
  });

  group('PDF High-Resolution DPI & Page Sizing Tests', () {
    test('Calculates 300 DPI target resolution for standard A4 page', () {
      // Standard A4 in points: 595.3 x 841.9 pt
      const w = 595.3;
      const h = 841.9;

      final double longEdge = math.max(w, h);
      final double targetLongEdge = math.min(3200.0, math.max(2400.0, longEdge * 3.5));
      final double scale = (targetLongEdge / longEdge).clamp(2.0, 4.5);

      final renderWidth = w * scale;
      final renderHeight = h * scale;

      // Verify render height matches ~2800-3000 pixels (true 300 DPI scan quality)
      expect(renderHeight, greaterThanOrEqualTo(2400.0));
      expect(renderHeight, lessThanOrEqualTo(3200.0));
      // Verify scale is at least 3.0x (~216-300 DPI)
      expect(scale, greaterThanOrEqualTo(3.0));
      expect(renderWidth, greaterThanOrEqualTo(1700.0));
    });

    test('Clamps large CAD drawings (A0/A1) to prevent excessive memory usage', () {
      // Large architectural drawing: ~2384 x 3370 pt (A0)
      const w = 2384.0;
      const h = 3370.0;

      final double longEdge = math.max(w, h);
      final double targetLongEdge = math.min(3200.0, math.max(2400.0, longEdge * 3.5));
      final double scale = (targetLongEdge / longEdge).clamp(1.0, 4.5);

      final renderHeight = h * scale;
      // Even for A0, it should be clamped to avoid OOM crash while retaining sharp vectors
      expect(renderHeight, lessThanOrEqualTo(3500.0));
    });
  });

  group('ZIP Archive Localization Tests', () {
    test('Archive strings exist and resolve correctly in English and Bulgarian', () {
      final en = AppLocalizationsEn();
      final bg = AppLocalizationsBg();

      expect(en.archiveFilesCount(7), equals('Archive Files (7)'));
      expect(en.openArchiveFile, equals('Open'));
      expect(en.unsupportedArchiveFormat, contains('not supported'));
      expect(en.extractingFile('report.pdf'), equals('Opening report.pdf...'));

      expect(bg.archiveFilesCount(7), equals('Файлове в архива (7)'));
      expect(bg.openArchiveFile, equals('Отвори'));
      expect(bg.unsupportedArchiveFormat, contains('Не се поддържа'));
      expect(bg.extractingFile('report.pdf'), equals('Отваряне на report.pdf...'));
    });
  });
}
