import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/project_bundle_service.dart';

void main() {
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
    });

    test('extracts single file on-demand', () async {
      final extracted = await ProjectBundleService.extractFile(zipPath, '02_Flythrough.mp4');
      final file = File(extracted);
      expect(await file.exists(), isTrue);
      expect(file.path.endsWith('02_Flythrough.mp4'), isTrue);
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
