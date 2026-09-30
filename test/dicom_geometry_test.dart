import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_geometry.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_parser.dart';

void main() {
  group('DicomVector3 operations', () {
    test('vector arithmetic and dot/cross product', () {
      const v1 = DicomVector3(1, 0, 0);
      const v2 = DicomVector3(0, 1, 0);

      expect(v1.dot(v2), 0.0);
      final cross = v1.cross(v2);
      expect(cross.x, 0.0);
      expect(cross.y, 0.0);
      expect(cross.z, 1.0);
      expect(cross.length, 1.0);

      final vSum = v1 + v2;
      expect(vSum.x, 1.0);
      expect(vSum.y, 1.0);
      expect(vSum.length, closeTo(1.4142, 0.001));
    });
  });

  group('DicomGeometry 3D Plane Intersections', () {
    // Helper to construct a synthetic DicomHeader with geometric tags
    DicomHeader createHeader({
      required List<double> position,
      required List<double> orientation,
      required List<double> spacing,
      int rows = 512,
      int columns = 512,
      String? seriesDescription,
    }) {
      return DicomHeader(
        imagePositionPatient: position,
        imageOrientationPatient: orientation,
        pixelSpacing: spacing,
        rows: rows,
        columns: columns,
        seriesDescription: seriesDescription,
        bitsAllocated: 16,
        bitsStored: 12,
        highBit: 11,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        numberOfFrames: 1,
        transferSyntaxUID: DicomTransferSyntax.explicitVrLittleEndian,
        pixelDataOffset: 0,
        pixelDataLength: 0,
      );
    }

    test('Axial and Coronal orthogonal planes intersection', () {
      // Axial Slice at Z = 50 mm
      // Standard Axial: u = [1, 0, 0], v = [0, 1, 0], normal = [0, 0, 1]
      final axialHeader = createHeader(
        position: [0.0, 0.0, 50.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0], // rowSpacing = 1, colSpacing = 1
        rows: 512,
        columns: 512,
        seriesDescription: 'Axial CT',
      );

      // Coronal Slice at Y = 100 mm
      // Standard Coronal: u = [1, 0, 0], v = [0, 0, -1], normal = [0, 1, 0]
      // Top of coronal image is at Z = 150 mm, bottom is at Z = 150 - 512 = -362 mm
      final coronalHeader = createHeader(
        position: [0.0, 100.0, 150.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 0.0, -1.0],
        spacing: [1.0, 1.0],
        rows: 512,
        columns: 512,
        seriesDescription: 'Coronal Reconstruction',
      );

      // 1. Project Axial slice onto Coronal image
      // On coronal image, Z = 50 is at distance (150 - 50) = 100 pixels down from top!
      // Therefore, the axial reference line on coronal should be horizontal at Y = 100.
      final lineOnCoronal = DicomGeometry.calculateIntersection(
        targetHeader: coronalHeader,
        sourceHeader: axialHeader,
        sourceSliceIndex: 15,
        sourceTotalSlices: 30,
      );

      expect(lineOnCoronal, isNotNull);
      expect(lineOnCoronal!.start.dy, closeTo(100.0, 0.01));
      expect(lineOnCoronal.end.dy, closeTo(100.0, 0.01));
      expect(lineOnCoronal.start.dx, closeTo(0.0, 0.01));
      expect(lineOnCoronal.end.dx, closeTo(512.0, 0.01));

      // 2. Project Coronal slice onto Axial image
      // Coronal plane is Y = 100 mm. On axial image (origin Y = 0, v = [0, 1, 0]),
      // Y = 100 is at distance (100 - 0) = 100 pixels down from top!
      // Therefore, the coronal reference line on axial should be horizontal at Y = 100.
      final lineOnAxial = DicomGeometry.calculateIntersection(
        targetHeader: axialHeader,
        sourceHeader: coronalHeader,
        sourceSliceIndex: 10,
        sourceTotalSlices: 25,
      );

      expect(lineOnAxial, isNotNull);
      expect(lineOnAxial!.start.dy, closeTo(100.0, 0.01));
      expect(lineOnAxial.end.dy, closeTo(100.0, 0.01));
      expect(lineOnAxial.start.dx, closeTo(0.0, 0.01));
      expect(lineOnAxial.end.dx, closeTo(512.0, 0.01));
    });

    test('Parallel slices return null (no intersection line across image)', () {
      final axial1 = createHeader(
        position: [0.0, 0.0, 50.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0],
      );

      final axial2 = createHeader(
        position: [0.0, 0.0, 55.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0],
      );

      expect(DicomGeometry.arePlanesParallel(axial1, axial2), isTrue);

      final line = DicomGeometry.calculateIntersection(
        targetHeader: axial1,
        sourceHeader: axial2,
        sourceSliceIndex: 1,
        sourceTotalSlices: 2,
      );

      expect(line, isNull);
    });

    test('Oblique slice produces angled reference line', () {
      final axial = createHeader(
        position: [0.0, 0.0, 0.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0],
      );

      // 45-degree oblique slice
      final oblique = createHeader(
        position: [0.0, 0.0, 0.0],
        orientation: [0.707106, 0.0, 0.707106, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0],
      );

      final line = DicomGeometry.calculateIntersection(
        targetHeader: axial,
        sourceHeader: oblique,
        sourceSliceIndex: 0,
        sourceTotalSlices: 1,
      );

      expect(line, isNotNull);
      // Line should be vertical (or at x=0) because oblique plane intersects axial at x=0
      expect(line!.start.dx, closeTo(0.0, 0.1));
      expect(line.end.dx, closeTo(0.0, 0.1));
    });

    test('Missing geometry tags returns null safely without throwing', () {
      final incompleteHeader = DicomHeader(
        rows: 512,
        columns: 512,
        bitsAllocated: 16,
        bitsStored: 12,
        highBit: 11,
        pixelRepresentation: 0,
        photometricInterpretation: 'MONOCHROME2',
        samplesPerPixel: 1,
        numberOfFrames: 1,
        transferSyntaxUID: DicomTransferSyntax.explicitVrLittleEndian,
        pixelDataOffset: 0,
        pixelDataLength: 0,
      );

      final validHeader = createHeader(
        position: [0.0, 0.0, 0.0],
        orientation: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        spacing: [1.0, 1.0],
      );

      expect(
        DicomGeometry.calculateIntersection(
          targetHeader: incompleteHeader,
          sourceHeader: validHeader,
          sourceSliceIndex: 0,
          sourceTotalSlices: 1,
        ),
        isNull,
      );

      expect(
        DicomGeometry.calculateIntersection(
          targetHeader: validHeader,
          sourceHeader: incompleteHeader,
          sourceSliceIndex: 0,
          sourceTotalSlices: 1,
        ),
        isNull,
      );
    });
  });
}
