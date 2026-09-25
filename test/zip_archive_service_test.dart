import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/zip_archive_service.dart';

void main() {
  test('ZipArchiveService correctly decodes CP866 Cyrillic ZIP entry names', () {
    const zipPath = r'C:\Users\Creator\Dropbox\test_files\Yoga.zip';
    final archive = ZipArchiveService.openFromPath(zipPath);
    expect(archive.length, 8);

    final names = archive.files.map((f) => f.name).toList();
    print('Decoded names: $names');

    // Must contain Cyrillic names correctly decoded from CP866
    expect(names.any((n) => n.contains('Йога')), isTrue,
        reason: 'Expected at least one entry with "Йога" in the name');
    expect(names.any((n) => n == 'Йога.pdf'), isTrue,
        reason: 'Expected entry "Йога.pdf"');
    expect(names.any((n) => n.contains('Йога_Photo')), isTrue,
        reason: 'Expected entries with "Йога_Photo"');

    // ASCII entries should remain unchanged
    expect(names.any((n) => n.contains('-3.50 Worksheet (8).dwg')), isTrue);
    expect(names.any((n) => n.contains('0.00 Worksheet (7).dwg')), isTrue);

    // Content should still be readable after decoding
    final pdf = archive.files.firstWhere((f) => f.name == 'Йога.pdf');
    expect(pdf.size, 2799210);
    final header = String.fromCharCodes((pdf.content as List<int>).take(5));
    expect(header, '%PDF-');
  });
}
