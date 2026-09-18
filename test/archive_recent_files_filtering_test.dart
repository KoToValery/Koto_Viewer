import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/recent_files_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Archive Recent Files Filtering Tests', () {
    test('isArchiveExtractedPath correctly identifies extracted paths', () {
      expect(RecentFilesService.isArchiveExtractedPath(r'C:\Users\App\AppData\Local\Temp\koto_extracted\schematic.pdf'), isTrue);
      expect(RecentFilesService.isArchiveExtractedPath('/data/user/0/com.koto/cache/koto_extracted/board.step'), isTrue);
      expect(RecentFilesService.isArchiveExtractedPath('/tmp/extracted_files/report.txt'), isTrue);
      expect(RecentFilesService.isArchiveExtractedPath('/cache/koto_dicom_123/slice.dcm'), isTrue);
      expect(RecentFilesService.isArchiveExtractedPath('/tmp/zip_temp/data.csv'), isTrue);

      // Normal archive and document files MUST NOT be treated as extracted
      expect(RecentFilesService.isArchiveExtractedPath(r'C:\Downloads\Arduino_Uno_R3.zip'), isFalse);
      expect(RecentFilesService.isArchiveExtractedPath('/storage/emulated/0/Download/project.kicad_pcb'), isFalse);
      expect(RecentFilesService.isArchiveExtractedPath('/documents/manual.pdf'), isFalse);
    });

    test('addRecentFile ignores extracted subfiles but adds main archive', () async {
      final archiveItem = PdfItem(
        path: '/storage/emulated/0/Download/my_hardware_project.zip',
        name: 'my_hardware_project.zip',
        sizeInBytes: 1024000,
        lastOpened: DateTime.now(),
      );

      final extractedSubfile = PdfItem(
        path: '/data/user/0/com.koto/cache/koto_extracted/schematic.pdf',
        name: 'schematic.pdf',
        sizeInBytes: 52000,
        lastOpened: DateTime.now(),
      );

      // Add main archive
      await RecentFilesService.addRecentFile(archiveItem);
      // Attempt to add extracted subfile
      await RecentFilesService.addRecentFile(extractedSubfile);

      final recent = await RecentFilesService.getRecentFiles();

      expect(recent.length, equals(1));
      expect(recent.first.path, equals(archiveItem.path));
      expect(recent.first.name, equals('my_hardware_project.zip'));
    });

    test('getRecentFiles automatically cleans up any legacy extracted subfiles from prefs', () async {
      final prefs = await SharedPreferences.getInstance();

      final archiveItem = PdfItem(
        path: '/storage/my_project.zip',
        name: 'my_project.zip',
        sizeInBytes: 5000,
        lastOpened: DateTime.now(),
      );

      final oldExtractedItem = PdfItem(
        path: '/cache/koto_extracted/legacy_sheet.pdf',
        name: 'legacy_sheet.pdf',
        sizeInBytes: 1000,
        lastOpened: DateTime.now(),
      );

      await prefs.setStringList('koto_recent_files', [
        oldExtractedItem.toJson(),
        archiveItem.toJson(),
      ]);

      final recent = await RecentFilesService.getRecentFiles();

      expect(recent.length, equals(1));
      expect(recent.first.name, equals('my_project.zip'));

      // Verify that prefs were sanitized
      final rawPrefsList = prefs.getStringList('koto_recent_files');
      expect(rawPrefsList?.length, equals(1));
    });
  });
}
