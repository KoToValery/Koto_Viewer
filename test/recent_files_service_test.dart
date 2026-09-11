import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/recent_files_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecentFilesService Tests', () {
    test('addRecentFile adds item and notifies recentFilesNotifier', () async {
      int notifications = 0;
      void listener() => notifications++;
      RecentFilesService.recentFilesNotifier.addListener(listener);

      final item = PdfItem(
        path: '/test/document.pdf',
        name: 'document.pdf',
        sizeInBytes: 1024,
        lastOpened: DateTime.now(),
      );

      await RecentFilesService.addRecentFile(item);

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent.length, equals(1));
      expect(recent.first.path, equals('/test/document.pdf'));
      expect(notifications, equals(1));

      RecentFilesService.recentFilesNotifier.removeListener(listener);
    });

    test('removeRecentFile removes item and notifies recentFilesNotifier', () async {
      final item1 = PdfItem(
        path: '/test/file1.dwg',
        name: 'file1.dwg',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );
      final item2 = PdfItem(
        path: '/test/file2.pptx',
        name: 'file2.pptx',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );

      await RecentFilesService.addRecentFile(item1);
      await RecentFilesService.addRecentFile(item2);

      int notifications = 0;
      void listener() => notifications++;
      RecentFilesService.recentFilesNotifier.addListener(listener);

      await RecentFilesService.removeRecentFile('/test/file1.dwg');

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent.length, equals(1));
      expect(recent.first.path, equals('/test/file2.pptx'));
      expect(notifications, equals(1));

      RecentFilesService.recentFilesNotifier.removeListener(listener);
    });

    test('clearAll removes all items and notifies recentFilesNotifier', () async {
      final item = PdfItem(
        path: '/test/file.pdf',
        name: 'file.pdf',
        sizeInBytes: 100,
        lastOpened: DateTime.now(),
      );
      await RecentFilesService.addRecentFile(item);

      int notifications = 0;
      void listener() => notifications++;
      RecentFilesService.recentFilesNotifier.addListener(listener);

      await RecentFilesService.clearAll();

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent, isEmpty);
      expect(notifications, equals(1));

      RecentFilesService.recentFilesNotifier.removeListener(listener);
    });

    test('addRecentFile enforces maximum of 25 items', () async {
      for (int i = 0; i < 30; i++) {
        await RecentFilesService.addRecentFile(
          PdfItem(
            path: '/test/file_$i.pdf',
            name: 'file_$i.pdf',
            sizeInBytes: i * 10,
            lastOpened: DateTime.now().add(Duration(seconds: i)),
          ),
        );
      }

      final recent = await RecentFilesService.getRecentFiles();
      expect(recent.length, equals(25));
      expect(recent.first.path, equals('/test/file_29.pdf'));
    });
  });
}
