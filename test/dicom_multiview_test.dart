import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_geometry.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_models.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_parser.dart';

void main() {
  group('Dicom Multi-Viewport & Localizer Synchronization', () {
    test('DicomViewportLayout correctly determines grid dimensions', () {
      expect(DicomViewportLayout.single.totalViewports, 1);
      expect(DicomViewportLayout.splitVertical.totalViewports, 2);
      expect(DicomViewportLayout.splitHorizontal.totalViewports, 2);
      expect(DicomViewportLayout.grid2x2.totalViewports, 4);
    });

    test('DicomViewportState maintains independent slice, windowing, and color', () {
      final vp1 = DicomViewportState(
        viewportIndex: 0,
        seriesIndex: 0,
        sliceIndex: 5,
        windowCenter: 40,
        windowWidth: 400,
      );

      final vp2 = DicomViewportState(
        viewportIndex: 1,
        seriesIndex: 1,
        sliceIndex: 12,
        windowCenter: 300,
        windowWidth: 1500,
      );

      expect(vp1.accentColor, DicomViewportColors.palette[0]);
      expect(vp2.accentColor, DicomViewportColors.palette[1]);
      expect(vp1.sliceIndex, 5);
      expect(vp2.sliceIndex, 12);
      expect(vp1.windowCenter, 40);
      expect(vp2.windowCenter, 300);
    });

    test('Dynamic reference line recalculation when slice changes', () {
      // Axial CT series with 30 slices (Z spacing = 5 mm, Z starts at 0 mm)
      // Coronal series at Y = 100 mm (Z starts at 150 mm)
      DicomHeader createAxialHeader(double z) {
        return DicomHeader(
          imagePositionPatient: [0.0, 0.0, z],
          imageOrientationPatient: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
          pixelSpacing: [1.0, 1.0],
          rows: 512,
          columns: 512,
          seriesDescription: 'Axial CT',
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

      final coronalHeader = DicomHeader(
        imagePositionPatient: [0.0, 100.0, 150.0],
        imageOrientationPatient: [1.0, 0.0, 0.0, 0.0, 0.0, -1.0],
        pixelSpacing: [1.0, 1.0],
        rows: 512,
        columns: 512,
        seriesDescription: 'Coronal Reconstruction',
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

      // Slice at Z = 50: on coronal image, y = 150 - 50 = 100
      final line1 = DicomGeometry.calculateIntersection(
        targetHeader: coronalHeader,
        sourceHeader: createAxialHeader(50.0),
        sourceSliceIndex: 10,
        sourceTotalSlices: 30,
      );
      expect(line1, isNotNull);
      expect(line1!.start.dy, closeTo(100.0, 0.01));

      // Slice moved to Z = 70: on coronal image, y = 150 - 70 = 80 (shifted upwards!)
      final line2 = DicomGeometry.calculateIntersection(
        targetHeader: coronalHeader,
        sourceHeader: createAxialHeader(70.0),
        sourceSliceIndex: 14,
        sourceTotalSlices: 30,
      );
      expect(line2, isNotNull);
      expect(line2!.start.dy, closeTo(80.0, 0.01));

      // Slice moved to Z = 20: on coronal image, y = 150 - 20 = 130 (shifted downwards!)
      final line3 = DicomGeometry.calculateIntersection(
        targetHeader: coronalHeader,
        sourceHeader: createAxialHeader(20.0),
        sourceSliceIndex: 4,
        sourceTotalSlices: 30,
      );
      expect(line3, isNotNull);
      expect(line3!.start.dy, closeTo(130.0, 0.01));
    });
  });
}
