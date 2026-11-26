import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';
import 'package:kotoview/src/core/services/dwg_converter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DWG File Support Tests', () {
    test('PdfItem correctly identifies .dwg file types', () {
      final dwgItem = PdfItem(
        path: '/storage/emulated/0/Download/drawing.dwg',
        name: 'drawing.dwg',
        sizeInBytes: 1024,
        lastOpened: DateTime.now(),
      );

      final upperDwgItem = PdfItem(
        path: '/storage/emulated/0/Download/PLAN_2024.DWG',
        name: 'PLAN_2024.DWG',
        sizeInBytes: 2048,
        lastOpened: DateTime.now(),
      );

      final dxfItem = PdfItem(
        path: '/storage/emulated/0/Download/cad.dxf',
        name: 'cad.dxf',
        sizeInBytes: 512,
        lastOpened: DateTime.now(),
      );

      final pdfItem = PdfItem(
        path: '/storage/emulated/0/Download/doc.pdf',
        name: 'doc.pdf',
        sizeInBytes: 4096,
        lastOpened: DateTime.now(),
      );

      expect(dwgItem.fileType, equals(KotoFileType.dwg));
      expect(dwgItem.isCad, isTrue);
      expect(dwgItem.fileExtension, equals('dwg'));

      expect(upperDwgItem.fileType, equals(KotoFileType.dwg));
      expect(upperDwgItem.isCad, isTrue);

      expect(dxfItem.fileType, equals(KotoFileType.dxf));
      expect(dxfItem.isCad, isTrue);

      expect(pdfItem.fileType, equals(KotoFileType.pdf));
      expect(pdfItem.isCad, isFalse);
    });

    test('DwgConverterService throws DwgConversionException for non-existent file', () async {
      expect(
        () => DwgConverterService.convertDwgToDxf('/non/existent/path/drawing.dwg'),
        throwsA(isA<DwgConversionException>()),
      );
    });

    test('DwgConverterService isNativeSupported returns true on Windows with bundled tool', () {
      expect(DwgConverterService.isNativeSupported, isTrue);
    });
  });

  group('DWG Converter Cache Pruning Tests', () {
    late Directory tempTestDir;

    setUp(() async {
      tempTestDir = await Directory.systemTemp.createTemp('dwg_test_');
    });

    tearDown(() async {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    });

    test('pruneCache evicts files exceeding maxSizeBytes and older than maxAge', () async {
      final file1 = File('${tempTestDir.path}/old_v3.dxf');
      final file2 = File('${tempTestDir.path}/new1_v3.dxf');
      final file3 = File('${tempTestDir.path}/new2_v3.dxf');

      await file1.writeAsString('a' * 1000);
      await file2.writeAsString('b' * 1000);
      await file3.writeAsString('c' * 1000);

      final oldTime = DateTime.now().subtract(const Duration(days: 10));
      await file1.setLastModified(oldTime);

      // Max age 7 days -> file1 should be pruned
      await DwgConverterService.pruneCache(
        maxSizeBytes: 5000,
        maxAge: const Duration(days: 7),
        customCacheDir: tempTestDir,
      );

      expect(await file1.exists(), isFalse);
      expect(await file2.exists(), isTrue);
      expect(await file3.exists(), isTrue);

      // Size-based LRU eviction: set maxSizeBytes = 1500 (file2 + file3 = 2000 > 1500)
      await file2.setLastModified(DateTime.now().subtract(const Duration(hours: 2)));
      await file3.setLastModified(DateTime.now());

      await DwgConverterService.pruneCache(
        maxSizeBytes: 1500,
        maxAge: const Duration(days: 7),
        customCacheDir: tempTestDir,
      );

      // Oldest (file2) should be evicted
      expect(await file2.exists(), isFalse);
      expect(await file3.exists(), isTrue);
    });
  });
}
