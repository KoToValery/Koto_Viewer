import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_models.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_parser.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_study_loader.dart';

import 'dicom_parser_test.dart';

void main() {
  group('DicomParser.isDicom validation', () {
    test('detects standard DICOM with DICM magic', () {
      final bytes = Uint8List(140);
      bytes[128] = 0x44; // 'D'
      bytes[129] = 0x49; // 'I'
      bytes[130] = 0x43; // 'C'
      bytes[131] = 0x4D; // 'M'

      expect(DicomParser.isDicom(bytes), isTrue);
    });

    test('detects preamble-less DICOM (group 0x0008 at byte 0)', () {
      final bytes = Uint8List(20);
      bytes[0] = 0x08;
      bytes[1] == 0x00;

      expect(DicomParser.isDicom(bytes), isTrue);
    });

    test('rejects arbitrary non-DICOM bytes', () {
      final bytes = Uint8List(200);
      bytes[0] = 0xFF;
      bytes[1] = 0xD8; // JPEG magic
      expect(DicomParser.isDicom(bytes), isFalse);
    });
  });

  group('DicomMeasurement caliper calculation', () {
    test('calculates physical distance in millimeters with PixelSpacing', () {
      // 100 pixels horizontal, 0.5 mm per pixel = 50.0 mm
      final m = DicomMeasurement(
        start: const Offset(0, 0),
        end: const Offset(100, 0),
        pixelSpacingRow: 0.5,
        pixelSpacingCol: 0.5,
      );

      expect(m.isCalibrated, isTrue);
      expect(m.distance, closeTo(50.0, 0.001));
      expect(m.formattedDistance, '50.0 mm');
    });

    test('calculates 2D diagonal distance with non-square spacing', () {
      // 30 px col (dx=30 * 0.5 = 15mm), 40 px row (dy=40 * 0.5 = 20mm) -> hypotenuse = 25mm
      final m = DicomMeasurement(
        start: const Offset(10, 10),
        end: const Offset(40, 50),
        pixelSpacingRow: 0.5,
        pixelSpacingCol: 0.5,
      );

      expect(m.distance, closeTo(25.0, 0.001));
      expect(m.formattedDistance, '25.0 mm');
    });

    test('falls back to pixels when uncalibrated', () {
      final m = DicomMeasurement(
        start: const Offset(0, 0),
        end: const Offset(30, 40),
        pixelSpacingRow: null,
        pixelSpacingCol: null,
      );

      expect(m.isCalibrated, isFalse);
      expect(m.distance, closeTo(50.0, 0.001));
      expect(m.formattedDistance, '50 px');
    });
  });

  group('DicomStudyLoader & Series Sorting', () {
    test('DicomStudyLoader.isDicomZip detects zip with .dcm file', () {
      final archive = Archive();
      final dicomBytes = buildSyntheticDicom(patientName: 'Zip^Patient');
      archive.addFile(ArchiveFile('CT_001.dcm', dicomBytes.length, dicomBytes));

      final zipBytes = ZipEncoder().encode(archive);
      expect(zipBytes, isNotNull);

      expect(DicomStudyLoader.isDicomZipBytes(Uint8List.fromList(zipBytes!)), isTrue);
    });

    test('DicomStudyLoader.isDicomZip detects zip with extensionless DICOM file', () {
      final archive = Archive();
      final dicomBytes = buildSyntheticDicom(patientName: 'Zip^Patient');
      // File named just numeric ID without extension
      archive.addFile(ArchiveFile('1.2.840.113619.2.1', dicomBytes.length, dicomBytes));

      final zipBytes = ZipEncoder().encode(archive);
      expect(zipBytes, isNotNull);

      expect(DicomStudyLoader.isDicomZipBytes(Uint8List.fromList(zipBytes!)), isTrue);
    });

    test('DicomStudyLoader.isDicomZip rejects non-DICOM zip', () {
      final archive = Archive();
      archive.addFile(ArchiveFile('readme.txt', 11, 'Hello World'.codeUnits));

      final zipBytes = ZipEncoder().encode(archive);
      expect(zipBytes, isNotNull);

      expect(DicomStudyLoader.isDicomZipBytes(Uint8List.fromList(zipBytes!)), isFalse);
    });

    test('Loads and sorts multiple slices from a directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('koto_test_study_');
      try {
        // Write 3 slices with different Instance Numbers out of order
        final slice3 = buildSyntheticDicom(patientName: 'Study^Patient');
        final slice1 = buildSyntheticDicom(patientName: 'Study^Patient');
        final slice2 = buildSyntheticDicom(patientName: 'Study^Patient');

        File('${tempDir.path}/slice_c.dcm').writeAsBytesSync(slice3);
        File('${tempDir.path}/slice_a.dcm').writeAsBytesSync(slice1);
        File('${tempDir.path}/slice_b.dcm').writeAsBytesSync(slice2);

        final study = await DicomStudyLoader.load(tempDir.path);

        expect(study.patientName, contains('Study Patient'));
        expect(study.series.isNotEmpty, isTrue);
        expect(study.series.first.sliceCount, 3);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
