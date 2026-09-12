import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/android_saf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidSafService folder naming and detection tests', () {
    test('isOpaqueProviderId correctly detects Google Drive, UUID, and hash IDs', () {
      expect(AndroidSafService.isOpaqueProviderId('acc=10;doc=encoded=um5REvj7L4d26J_kR8a0'), isTrue);
      expect(AndroidSafService.isOpaqueProviderId('acc=10;doc=encoded=9iUL83bX-2kL'), isTrue);
      expect(AndroidSafService.isOpaqueProviderId('doc=encoded=ASZ12345'), isTrue);
      expect(AndroidSafService.isOpaqueProviderId('373a94fc-5181-4bc4-a2f2-b21a8d115e5c'), isTrue);
      expect(AndroidSafService.isOpaqueProviderId('msf:12345'), isTrue);
      expect(AndroidSafService.isOpaqueProviderId('0123456789abcdef0123456789abcdef'), isTrue);

      expect(AndroidSafService.isOpaqueProviderId('Download'), isFalse);
      expect(AndroidSafService.isOpaqueProviderId('Documents'), isFalse);
      expect(AndroidSafService.isOpaqueProviderId('Чертежи'), isFalse);
      expect(AndroidSafService.isOpaqueProviderId('My Invoices 2026'), isFalse);
      expect(AndroidSafService.isOpaqueProviderId('Projects'), isFalse);
    });

    test('folderNameFromSafUri handles Google Drive and UUID URIs gracefully', () {
      final gDriveUri = 'content://com.google.android.apps.docs.storage/tree/acc%3D10%3Bdoc%3Dencoded%3Dum5REvj7L4d26J_kR8a0';
      final gDriveName = AndroidSafService.folderNameFromSafUri(gDriveUri);
      expect(gDriveName, equals('Google Drive Folder'));

      final uuidUri = 'content://com.custom.provider/tree/373a94fc-5181-4bc4-a2f2-b21a8d115e5c';
      final uuidName = AndroidSafService.folderNameFromSafUri(uuidUri);
      expect(uuidName, equals('Custom Folder'));
    });

    test('folderNameFromSafUri extracts clean names from standard ExternalStorage URIs', () {
      final downloadUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload';
      expect(AndroidSafService.folderNameFromSafUri(downloadUri), equals('Download'));

      final cyrillicUri = 'content://com.android.externalstorage.documents/tree/primary%3A%D0%A7%D0%B5%D1%80%D1%82%D0%B5%D0%B6%D0%B8';
      expect(AndroidSafService.folderNameFromSafUri(cyrillicUri), equals('Чертежи'));

      final rootUri = 'content://com.android.externalstorage.documents/tree/primary%3A';
      expect(AndroidSafService.folderNameFromSafUri(rootUri), equals('Internal Storage'));

      final nestedUri = 'content://com.android.externalstorage.documents/tree/primary%3AWork%2FArchitectural';
      expect(AndroidSafService.folderNameFromSafUri(nestedUri), equals('Architectural'));
    });

    test('folderSubtitleFromSafUri returns user-friendly provider names', () {
      expect(
        AndroidSafService.folderSubtitleFromSafUri('content://com.google.android.apps.docs.storage/tree/acc%3D10...'),
        equals('Google Drive'),
      );
      expect(
        AndroidSafService.folderSubtitleFromSafUri('content://com.android.externalstorage.documents/tree/primary%3ADownload'),
        equals('Internal Storage'),
      );
      expect(
        AndroidSafService.folderSubtitleFromSafUri('content://com.android.providers.downloads.documents/tree/downloads'),
        equals('Downloads'),
      );
    });
  });
}
