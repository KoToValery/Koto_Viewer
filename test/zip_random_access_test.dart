import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/zip_archive_service.dart';

void main() {
  test('Central Directory reader on Yoga.zip', () async {
    const zipPath = r'C:\Users\Creator\Dropbox\test_files\Yoga.zip';
    if (!File(zipPath).existsSync()) {
      print('Skipping test, Yoga.zip not found');
      return;
    }

    final entries = await ZipArchiveService.readCentralDirectory(zipPath);
    expect(entries.length, 8);

    final names = entries.map((e) => e.name).toList();
    print('Central Directory entries: $names');

    expect(names.any((n) => n.contains('Йога')), isTrue);
    expect(names.any((n) => n == 'Йога.pdf'), isTrue);
    expect(names.any((n) => n == '0_Йога_център.mp4'), isTrue);

    // Test extracting a single file via random access
    final tempDir = Directory.systemTemp.createTempSync('zip_test_');
    try {
      final pdfEntry = entries.firstWhere((e) => e.name == 'Йога.pdf');
      final targetPdf = File('${tempDir.path}/extracted_yoga.pdf');

      await ZipArchiveService.extractEntryToFile(
        zipPath: zipPath,
        entry: pdfEntry,
        targetFile: targetPdf,
      );

      expect(targetPdf.existsSync(), isTrue);
      expect(targetPdf.lengthSync(), pdfEntry.uncompressedSize);

      final header = targetPdf.readAsBytesSync().sublist(0, 5);
      expect(String.fromCharCodes(header), '%PDF-');
      print('Successfully extracted ${targetPdf.path} (${targetPdf.lengthSync()} bytes) without reading entire zip!');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
