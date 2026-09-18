import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/pdf_item.dart';

void main() {
  group('FileCategory Tests', () {
    test('Classifies DICOM files as medical', () {
      final dcm = PdfItem.fromPath('/path/to/scan.dcm');
      final dicom = PdfItem.fromPath('/path/to/study.dicom');

      expect(dcm.category, equals(FileCategory.medical));
      expect(dicom.category, equals(FileCategory.medical));
      expect(FileCategory.medical.label, equals('Medical (DICOM)'));
      expect(FileCategory.medical.shortLabel, equals('Medical'));
    });

    test('Classifies image files as images', () {
      final png = PdfItem.fromPath('/path/to/photo.png');
      final jpg = PdfItem.fromPath('/path/to/image.jpg');
      final webp = PdfItem.fromPath('/path/to/graphic.webp');

      expect(png.category, equals(FileCategory.images));
      expect(jpg.category, equals(FileCategory.images));
      expect(webp.category, equals(FileCategory.images));
      expect(FileCategory.images.label, equals('Images'));
      expect(FileCategory.images.shortLabel, equals('Images'));
    });

    test('Classifies standard CAD and route files correctly', () {
      final dxf = PdfItem.fromPath('/path/to/drawing.dxf');
      final gpx = PdfItem.fromPath('/path/to/track.gpx');
      final stl = PdfItem.fromPath('/path/to/model.stl');

      expect(dxf.category, equals(FileCategory.cad2d));
      expect(gpx.category, equals(FileCategory.routes));
      expect(stl.category, equals(FileCategory.cad3d));
    });
  });
}
