import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/project_bundle_service.dart';
import 'package:kotoview/src/core/services/project_bundle_preload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectBundlePreloadService Tests', () {
    tearDown(() {
      ProjectBundlePreloadService.cancel();
    });

    test('startPreloading ignores bundles without DWG files', () {
      final bundle = ProjectBundleInfo(
        archivePath: 'dummy.zip',
        projectName: 'No DWG Project',
        totalFiles: 2,
        totalSizeBytes: 3072,
        files: [
          ProjectFileEntry(
            fileName: 'video.mp4',
            internalPath: 'video.mp4',
            uncompressedSize: 1024,
            category: ProjectItemCategory.video,
            fileType: KotoFileType.video,
            presentationOrder: 1,
          ),
          ProjectFileEntry(
            fileName: 'doc.pdf',
            internalPath: 'doc.pdf',
            uncompressedSize: 2048,
            category: ProjectItemCategory.document,
            fileType: KotoFileType.pdf,
            presentationOrder: 2,
          ),
        ],
      );

      // Should return without error or queuing
      ProjectBundlePreloadService.startPreloading(bundle);
      ProjectBundlePreloadService.cancel();
    });

    test('startPreloading and cancel execute gracefully with DWG entries', () {
      final bundle = ProjectBundleInfo(
        archivePath: 'dummy.zip',
        projectName: 'DWG Project',
        totalFiles: 2,
        totalSizeBytes: 11000,
        files: [
          ProjectFileEntry(
            fileName: 'floorplan.dwg',
            internalPath: 'plans/floorplan.dwg',
            uncompressedSize: 5000,
            category: ProjectItemCategory.drawing,
            fileType: KotoFileType.dwg,
            presentationOrder: 1,
          ),
          ProjectFileEntry(
            fileName: 'facade.dwg',
            internalPath: 'plans/facade.dwg',
            uncompressedSize: 6000,
            category: ProjectItemCategory.drawing,
            fileType: KotoFileType.dwg,
            presentationOrder: 2,
          ),
        ],
      );

      ProjectBundlePreloadService.startPreloading(bundle);
      // Immediately cancel
      ProjectBundlePreloadService.cancel();
    });
  });
}
