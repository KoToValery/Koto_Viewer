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
  });
}
