import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/file_source_service.dart';
import 'package:kotoview/src/features/cdr_viewer/parser/cdr_parser.dart';

void main() {
  group('CorelDRAW (.cdr) Parser & Integration Tests', () {
    test('PdfItem & FileSourceService recognize .cdr vector files', () {
      final item = PdfItem(
        path: 'C:/Designs/billboard.cdr',
        name: 'billboard.cdr',
        sizeInBytes: 1048576,
        lastOpened: DateTime.now(),
      );

      expect(item.fileType, KotoFileType.cdr);
      expect(item.isCdr, isTrue);
      expect(item.isVector, isTrue);
      expect(item.category, FileCategory.cad2d);
      expect(FileSourceService.isSupportedFile('C:/Designs/billboard.cdr'), isTrue);
      expect(FileSourceService.isSupportedFile('C:/Designs/LOGO.CDR'), isTrue);
    });

    test('Parses modern ZIP-based CorelDRAW (.cdr) container with PNG preview and metadata', () {
      // 1. Construct minimal valid PNG image bytes (1x1 pixel)
      final pngHeader = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
        0x00, 0x00, 0x00, 0x0D, // IHDR chunk length (13)
        0x49, 0x48, 0x44, 0x52, // "IHDR"
        0x00, 0x00, 0x03, 0x20, // Width: 800 px (big-endian uint32)
        0x00, 0x00, 0x02, 0x58, // Height: 600 px (big-endian uint32)
        0x08, 0x06, 0x00, 0x00, 0x00, // bit depth, color type, compression, filter, interlace
        0x5D, 0x28, 0x15, 0x44, // CRC
      ];
      final pngBytes = Uint8List.fromList(pngHeader);

      // 2. Construct CorelDRAW metadata XML
      const metadataXml = '''<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <generator>CorelDRAW 2022 (64-Bit)</generator>
  <title>Билборд Център 4x3</title>
  <pageCount>2</pageCount>
</metadata>''';
      final xmlBytes = utf8.encode(metadataXml);

      // 3. Assemble modern ZIP-based .cdr archive
      final archive = Archive();
      archive.addFile(ArchiveFile('metadata/thumbnails/thumbnail.png', pngBytes.length, pngBytes));
      archive.addFile(ArchiveFile('metadata/metadata.xml', xmlBytes.length, xmlBytes));

      final cdrZipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      // 4. Parse with CdrParser
      final doc = CdrParser.parse(cdrZipBytes, fileSizeBytes: cdrZipBytes.length);

      expect(doc.isZipBased, isTrue);
      expect(doc.generator, 'CorelDRAW 2022 (64-Bit)');
      expect(doc.title, 'Билборд Център 4x3');
      expect(doc.pageCount, 2);
      expect(doc.width, 800);
      expect(doc.height, 600);
      expect(doc.formattedDimensions, '800 × 600 px');
      expect(doc.imageBytes.length, pngBytes.length);
    });

    test('Parses legacy RIFF CorelDRAW (.cdr) container and converts DISP DIB to BMP', () {
      // 1. Create a 40-byte BITMAPINFOHEADER DIB
      final dib = Uint8List(40 + 16);
      final dibBd = ByteData.sublistView(dib);
      dibBd.setUint32(0, 40, Endian.little);  // biSize = 40
      dibBd.setInt32(4, 640, Endian.little);  // biWidth = 640
      dibBd.setInt32(8, 480, Endian.little);  // biHeight = 480
      dibBd.setUint16(12, 1, Endian.little);  // biPlanes = 1
      dibBd.setUint16(14, 32, Endian.little); // biBitCount = 32 (ARGB)

      // 2. Assemble RIFF chunk: DISP chunk containing the DIB
      final dispChunk = BytesBuilder();
      dispChunk.add('DISP'.codeUnits);
      final dispSizeBd = ByteData(4);
      dispSizeBd.setUint32(0, dib.length, Endian.little);
      dispChunk.add(dispSizeBd.buffer.asUint8List());
      dispChunk.add(dib);

      // 3. Assemble outer RIFF container with CDRD (CorelDRAW X3)
      final riffBuilder = BytesBuilder();
      riffBuilder.add('RIFF'.codeUnits);
      final riffSizeBd = ByteData(4);
      final dispBytes = dispChunk.toBytes();
      riffSizeBd.setUint32(0, 4 + dispBytes.length, Endian.little);
      riffBuilder.add(riffSizeBd.buffer.asUint8List());
      riffBuilder.add('CDRD'.codeUnits); // Form Type: CorelDRAW X3 (v13)
      riffBuilder.add(dispBytes);

      final riffCdrBytes = riffBuilder.toBytes();

      // 4. Parse with CdrParser
      final doc = CdrParser.parse(riffCdrBytes, fileSizeBytes: riffCdrBytes.length);

      expect(doc.isZipBased, isFalse);
      expect(doc.generator, 'CorelDRAW X3 (v13)');
      expect(doc.width, 640);
      expect(doc.height, 480);
      expect(doc.formattedDimensions, '640 × 480 px');

      // The extracted image should be a valid BMP starting with "BM"
      expect(doc.imageBytes[0], 0x42); // "B"
      expect(doc.imageBytes[1], 0x4D); // "M"
    });

    test('Throws informative FormatException on corrupted or non-CDR files', () {
      final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
      expect(() => CdrParser.parse(invalidBytes), throwsFormatException);
    });
  });
}