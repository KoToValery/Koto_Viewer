import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/services/file_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FileSourceService folder names persistence tests', () {
    test('setCustomFolderName and getCustomFolderNames persist correctly', () async {
      final initial = await FileSourceService.getCustomFolderNames();
      expect(initial, isEmpty);

      const path1 = 'content://com.google.android.apps.docs.storage/tree/acc%3D10...';
      await FileSourceService.setCustomFolderName(path1, 'My Drive Folder');

      final updated = await FileSourceService.getCustomFolderNames();
      expect(updated[path1], equals('My Drive Folder'));
    });

    test('addCustomFolder stores displayName when provided', () async {
      const path2 = 'content://com.custom/tree/12345';
      await FileSourceService.addCustomFolder(path2, displayName: 'Work Projects');

      final list = await FileSourceService.getCustomFolderList();
      expect(list.contains(path2), isTrue);

      final names = await FileSourceService.getCustomFolderNames();
      expect(names[path2], equals('Work Projects'));
    });

    test('removeCustomFolder removes path from list and from names map', () async {
      const path3 = 'content://com.test/tree/999';
      await FileSourceService.addCustomFolder(path3, displayName: 'Temporary Folder');

      var names = await FileSourceService.getCustomFolderNames();
      expect(names.containsKey(path3), isTrue);

      await FileSourceService.removeCustomFolder(path3);

      final list = await FileSourceService.getCustomFolderList();
      expect(list.contains(path3), isFalse);

      names = await FileSourceService.getCustomFolderNames();
      expect(names.containsKey(path3), isFalse);
    });
  });
}
