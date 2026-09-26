import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/project_bundle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProjectBundleService Category Classification Tests', () {
    test('classifies video formats correctly', () {
      expect(ProjectBundleService.classifyCategory('walkthrough.mp4'), ProjectItemCategory.video);
      expect(ProjectBundleService.classifyCategory('site_drone.mov'), ProjectItemCategory.video);
      expect(ProjectBundleService.classifyCategory('render.mkv'), ProjectItemCategory.video);
      expect(ProjectBundleService.classifyCategory('animation.webm'), ProjectItemCategory.video);
      expect(ProjectBundleService.classifyCategory('old_clip.avi'), ProjectItemCategory.video);
    });

    test('classifies CAD and drawing formats correctly', () {
      expect(ProjectBundleService.classifyCategory('floorplan.dwg'), ProjectItemCategory.drawing);
      expect(ProjectBundleService.classifyCategory('facade.dxf'), ProjectItemCategory.drawing);
      expect(ProjectBundleService.classifyCategory('permits.pdf'), ProjectItemCategory.drawing);
      expect(ProjectBundleService.classifyCategory('diagram.svg'), ProjectItemCategory.drawing);
    });

    test('classifies 3D models correctly', () {
      expect(ProjectBundleService.classifyCategory('building.glb'), ProjectItemCategory.model3d);
      expect(ProjectBundleService.classifyCategory('interior.gltf'), ProjectItemCategory.model3d);
      expect(ProjectBundleService.classifyCategory('structure.ifc'), ProjectItemCategory.model3d);
      expect(ProjectBundleService.classifyCategory('part.step'), ProjectItemCategory.model3d);
      expect(ProjectBundleService.classifyCategory('sculpt.obj'), ProjectItemCategory.model3d);
    });

    test('classifies images and renders correctly', () {
      expect(ProjectBundleService.classifyCategory('render_01.jpg'), ProjectItemCategory.image);
      expect(ProjectBundleService.classifyCategory('facade_sunset.png'), ProjectItemCategory.image);
      expect(ProjectBundleService.classifyCategory('moodboard.webp'), ProjectItemCategory.image);
    });

    test('classifies documents correctly', () {
      expect(ProjectBundleService.classifyCategory('budget.xlsx'), ProjectItemCategory.document);
      expect(ProjectBundleService.classifyCategory('specs.docx'), ProjectItemCategory.document);
      expect(ProjectBundleService.classifyCategory('pitch.pptx'), ProjectItemCategory.document);
      expect(ProjectBundleService.classifyCategory('notes.txt'), ProjectItemCategory.document);
    });
  });

  group('Presentation Order Extraction Tests', () {
    test('extracts leading numbers properly', () {
      expect(ProjectBundleService.extractPresentationOrder('01_concept.pdf'), 1);
      expect(ProjectBundleService.extractPresentationOrder('02-facade.jpg'), 2);
      expect(ProjectBundleService.extractPresentationOrder('3.flythrough.mp4'), 3);
      expect(ProjectBundleService.extractPresentationOrder('12_section.dwg'), 12);
      expect(ProjectBundleService.extractPresentationOrder('random_name.mp4'), 999999);
    });
  });

  group('Project Archive Inspection & Extraction Tests', () {
    late Directory tempDir;
    late String zipPath;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('koto_test_project_');
      zipPath = '${tempDir.path}${Platform.pathSeparator}Villa_Koto.zip';

      // Build an in-memory zip containing architectural deliverables
      final archive = Archive();
      archive.addFile(ArchiveFile('01_FloorPlan.pdf', 10, Uint8List.fromList([1, 2, 3, 4])));
      archive.addFile(ArchiveFile('02_Flythrough.mp4', 20, Uint8List.fromList([5, 6, 7, 8])));
      archive.addFile(ArchiveFile('03_FacadeRender.jpg', 15, Uint8List.fromList([9, 10, 11])));
      archive.addFile(ArchiveFile('04_Model.glb', 30, Uint8List.fromList([12, 13, 14, 15])));

      final encoded = ZipEncoder().encode(archive);
      await File(zipPath).writeAsBytes(encoded!);
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('detects project bundle correctly', () {
      expect(ProjectBundleService.isProjectBundle(zipPath), isTrue);
    });

    test('inspects bundle metadata and files', () async {
      final info = await ProjectBundleService.inspectBundle(zipPath);
      expect(info.projectName, 'Villa_Koto');
      expect(info.totalFiles, 4);

      // Verify category filtering
      final videos = info.getFilesByCategory(ProjectItemCategory.video);
      expect(videos.length, 1);
      expect(videos.first.fileName, '02_Flythrough.mp4');

      final drawings = info.getFilesByCategory(ProjectItemCategory.drawing);
      expect(drawings.length, 1);
      expect(drawings.first.fileName, '01_FloorPlan.pdf');

      final models = info.getFilesByCategory(ProjectItemCategory.model3d);
      expect(models.length, 1);
      expect(models.first.fileName, '04_Model.glb');

      final images = info.getFilesByCategory(ProjectItemCategory.image);
      expect(images.length, 1);
      expect(images.first.fileName, '03_FacadeRender.jpg');

      // Verify files are initially grouped by category:
      // Videos (Flythrough) -> Drawings (FloorPlan) -> 3D Models (Model) -> Images (FacadeRender)
      expect(info.files[0].fileName, '02_Flythrough.mp4');
      expect(info.files[0].category, ProjectItemCategory.video);
      expect(info.files[1].fileName, '01_FloorPlan.pdf');
      expect(info.files[1].category, ProjectItemCategory.drawing);
      expect(info.files[2].fileName, '04_Model.glb');
      expect(info.files[2].category, ProjectItemCategory.model3d);
      expect(info.files[3].fileName, '03_FacadeRender.jpg');
      expect(info.files[3].category, ProjectItemCategory.image);
    });

    test('extracts single file on-demand', () async {
      final extracted = await ProjectBundleService.extractFile(zipPath, '02_Flythrough.mp4');
      final file = File(extracted);
      expect(await file.exists(), isTrue);
      expect(file.path.endsWith('02_Flythrough.mp4'), isTrue);
    });

    test('persists and restores custom presentation order across inspectBundle calls', () async {
      SharedPreferences.setMockInitialValues({});

      // First inspect: default category order
      final info1 = await ProjectBundleService.inspectBundle(zipPath);
      expect(info1.files.first.fileName, '02_Flythrough.mp4');

      // User reorders: puts FacadeRender first, then Model, then FloorPlan, then Flythrough
      final customOrder = [
        '03_FacadeRender.jpg',
        '04_Model.glb',
        '01_FloorPlan.pdf',
        '02_Flythrough.mp4',
      ];
      await ProjectBundleService.savePresentationOrder(zipPath, customOrder);

      // Verify loadPresentationOrder
      final loadedOrder = await ProjectBundleService.loadPresentationOrder(zipPath);
      expect(loadedOrder, customOrder);

      // Second inspect: should restore custom order!
      final info2 = await ProjectBundleService.inspectBundle(zipPath);
      expect(info2.files[0].fileName, '03_FacadeRender.jpg');
      expect(info2.files[1].fileName, '04_Model.glb');
      expect(info2.files[2].fileName, '01_FloorPlan.pdf');
      expect(info2.files[3].fileName, '02_Flythrough.mp4');

      // Clear presentation order reverts to category order
      await ProjectBundleService.clearPresentationOrder(zipPath);
      final info3 = await ProjectBundleService.inspectBundle(zipPath);
      expect(info3.files.first.fileName, '02_Flythrough.mp4');
    });

    test('reordering files preserves paths and enables opening every item in any order', () async {
      // Create a zip with subfolders having same-named files
      final subZipPath = '${tempDir.path}${Platform.pathSeparator}Nested_Project.zip';
      final archive = Archive();
      archive.addFile(ArchiveFile('part1/render.jpg', 3, Uint8List.fromList([1, 2, 3])));
      archive.addFile(ArchiveFile('part2/render.jpg', 4, Uint8List.fromList([4, 5, 6, 7])));
      archive.addFile(ArchiveFile('videos/intro.mp4', 3, Uint8List.fromList([8, 9, 10])));
      await File(subZipPath).writeAsBytes(ZipEncoder().encode(archive)!);

      final bundle = await ProjectBundleService.inspectBundle(subZipPath);
      expect(bundle.files.length, 3);

      // Reorder items in reverse order
      final reorderedPaths = bundle.files.reversed.map((f) => f.internalPath).toList();
      await ProjectBundleService.savePresentationOrder(subZipPath, reorderedPaths);

      final reloadedBundle = await ProjectBundleService.inspectBundle(subZipPath);
      expect(reloadedBundle.files.map((f) => f.internalPath).toList(), reorderedPaths);

      // Verify that every reordered file can be extracted to distinct paths without collision or loss
      final extractedPaths = <String>{};
      for (final fileEntry in reloadedBundle.files) {
        final path = await ProjectBundleService.extractFile(subZipPath, fileEntry.internalPath);
        final file = File(path);
        expect(await file.exists(), isTrue);
        expect(await file.length(), fileEntry.uncompressedSize);
        extractedPaths.add(path);
      }

      // All extracted paths must be distinct (part1/render.jpg and part2/render.jpg never collide)
      expect(extractedPaths.length, 3);
    });

    test('isProjectBundle returns false for PCB ZIP archives containing mixed 3D/BOM/image media', () async {
      final pcbZipPath = '${tempDir.path}${Platform.pathSeparator}PCB_Board_Production.zip';
      final pcbArchive = Archive();
      pcbArchive.addFile(ArchiveFile('Top_Layer.gtl', 20, Uint8List.fromList([1, 2, 3])));
      pcbArchive.addFile(ArchiveFile('Holes.drl', 15, Uint8List.fromList([4, 5])));
      pcbArchive.addFile(ArchiveFile('pcb_model.step', 50, Uint8List.fromList([6, 7, 8])));
      pcbArchive.addFile(ArchiveFile('pcb_render.png', 30, Uint8List.fromList([9, 10])));
      pcbArchive.addFile(ArchiveFile('bom.csv', 25, Uint8List.fromList([11, 12])));
      await File(pcbZipPath).writeAsBytes(ZipEncoder().encode(pcbArchive)!);

      expect(ProjectBundleService.isProjectBundle(pcbZipPath), isFalse);
    });
  });

  group('Presentation File Hiding & Skipping Tests', () {
    test('ProjectBundleInfo calculates visible and hidden files accurately', () {
      final f1 = ProjectFileEntry(
        internalPath: '01.mp4',
        fileName: '01.mp4',
        uncompressedSize: 100,
        category: ProjectItemCategory.video,
        fileType: KotoFileType.video,
        presentationOrder: 1,
      );
      final f2 = ProjectFileEntry(
        internalPath: '02.dwg',
        fileName: '02.dwg',
        uncompressedSize: 200,
        category: ProjectItemCategory.drawing,
        fileType: KotoFileType.dwg,
        presentationOrder: 2,
        isHidden: true,
      );
      final f3 = ProjectFileEntry(
        internalPath: '03.glb',
        fileName: '03.glb',
        uncompressedSize: 300,
        category: ProjectItemCategory.model3d,
        fileType: KotoFileType.glb,
        presentationOrder: 3,
      );
      final f4 = ProjectFileEntry(
        internalPath: '04.jpg',
        fileName: '04.jpg',
        uncompressedSize: 400,
        category: ProjectItemCategory.image,
        fileType: KotoFileType.image,
        presentationOrder: 4,
        isHidden: true,
      );

      final bundle = ProjectBundleInfo(
        archivePath: '/test/proj.zip',
        projectName: 'Test Project',
        totalFiles: 4,
        totalSizeBytes: 1000,
        files: [f1, f2, f3, f4],
      );

      expect(bundle.totalFiles, 4);
      expect(bundle.visibleFilesCount, 2);
      expect(bundle.hiddenFilesCount, 2);
      expect(bundle.visibleFiles.map((f) => f.fileName).toList(), ['01.mp4', '03.glb']);

      // getNextVisibleIndex skips hidden files
      expect(bundle.getNextVisibleIndex(0), 2); // skips f2 (index 1), returns f3 (index 2)
      expect(bundle.getNextVisibleIndex(1), 2); // from hidden f2, next visible is f3 (index 2)
      expect(bundle.getNextVisibleIndex(2), isNull); // after f3, f4 is hidden, so null
      expect(bundle.getNextVisibleIndex(3), isNull);

      // getPreviousVisibleIndex skips hidden files
      expect(bundle.getPreviousVisibleIndex(3), 2); // skips f4, returns f3 (index 2)
      expect(bundle.getPreviousVisibleIndex(2), 0); // skips f2 (index 1), returns f1 (index 0)
      expect(bundle.getPreviousVisibleIndex(1), 0);
      expect(bundle.getPreviousVisibleIndex(0), isNull);
    });

    test('persists and restores hidden files in ProjectBundleService', () async {
      SharedPreferences.setMockInitialValues({});
      const archivePath = 'C:/test/archive.zip';

      await ProjectBundleService.saveHiddenFiles(archivePath, {'file1.pdf', 'file2.jpg'});
      final loaded = await ProjectBundleService.loadHiddenFiles(archivePath);

      expect(loaded.contains('file1.pdf'), isTrue);
      expect(loaded.contains('file2.jpg'), isTrue);
      expect(loaded.contains('file3.png'), isFalse);

      await ProjectBundleService.clearHiddenFiles(archivePath);
      final emptyLoaded = await ProjectBundleService.loadHiddenFiles(archivePath);
      expect(emptyLoaded.isEmpty, isTrue);
    });

    test('toggleFileHidden and unhideAllFiles update model and preferences', () async {
      SharedPreferences.setMockInitialValues({});
      const archivePath = 'C:/test/my_bundle.zip';

      final entry1 = ProjectFileEntry(
        internalPath: 'sub/01.pdf',
        fileName: '01.pdf',
        uncompressedSize: 50,
        category: ProjectItemCategory.drawing,
        fileType: KotoFileType.pdf,
        presentationOrder: 1,
      );
      final entry2 = ProjectFileEntry(
        internalPath: '02.jpg',
        fileName: '02.jpg',
        uncompressedSize: 80,
        category: ProjectItemCategory.image,
        fileType: KotoFileType.image,
        presentationOrder: 2,
      );

      // Toggle entry1 to hidden
      await ProjectBundleService.toggleFileHidden(archivePath, entry1, true);
      expect(entry1.isHidden, isTrue);

      var hiddenSet = await ProjectBundleService.loadHiddenFiles(archivePath);
      expect(hiddenSet.contains('sub/01.pdf'), isTrue);

      // Toggle entry1 back to visible
      await ProjectBundleService.toggleFileHidden(archivePath, entry1, false);
      expect(entry1.isHidden, isFalse);

      hiddenSet = await ProjectBundleService.loadHiddenFiles(archivePath);
      expect(hiddenSet.contains('sub/01.pdf'), isFalse);

      // Hide both, then unhide all
      await ProjectBundleService.toggleFileHidden(archivePath, entry1, true);
      await ProjectBundleService.toggleFileHidden(archivePath, entry2, true);
      expect(entry1.isHidden, isTrue);
      expect(entry2.isHidden, isTrue);

      await ProjectBundleService.unhideAllFiles(archivePath, [entry1, entry2]);
      expect(entry1.isHidden, isFalse);
      expect(entry2.isHidden, isFalse);

      hiddenSet = await ProjectBundleService.loadHiddenFiles(archivePath);
      expect(hiddenSet.isEmpty, isTrue);
    });
  });

  group('KotoFileType and Category Extensions', () {
    test('PdfItem detects video and project files', () {
      final videoItem = PdfItem.fromPath('C:/projects/render.mp4');
      expect(videoItem.fileType, KotoFileType.video);
      expect(videoItem.isVideo, isTrue);
      expect(videoItem.category, FileCategory.video);

      final projectItem = PdfItem.fromPath('C:/projects/house.kpack');
      expect(projectItem.fileType, KotoFileType.project);
      expect(projectItem.isProject, isTrue);
    });
  });
}

