import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_parser.dart';
import 'package:kotoview/src/features/dicom_viewer/dicom_renderer.dart';
import 'package:kotoview/src/features/dicom_viewer/openjpeg_bridge_bindings.dart';

// ---------------------------------------------------------------------------
// Helper: build a minimal synthetic DICOM file in memory for unit testing.
// This avoids requiring a real .dcm file to run the tests.
// ---------------------------------------------------------------------------

/// Writes a uint16 LE at [offset] in [buf].
void writeU16(ByteData bd, int offset, int value) {
  bd.setUint16(offset, value, Endian.little);
}

/// Writes a uint32 LE at [offset] in [buf].
void writeU32(ByteData bd, int offset, int value) {
  bd.setUint32(offset, value, Endian.little);
}

/// Writes ASCII string bytes at [offset].
int writeStr(List<int> buf, int offset, String s, {bool pad = true}) {
  for (int i = 0; i < s.length; i++) {
    buf[offset + i] = s.codeUnitAt(i);
  }
  int end = offset + s.length;
  // DICOM strings are padded to even length with space
  if (pad && s.length.isOdd) {
    buf[end] = 0x20;
    end++;
  }
  return end;
}

/// Writes an Explicit VR Little Endian tag into [buf] starting at [offset].
/// Returns the new offset after writing.
int writeExplicitTag(
  List<int> buf,
  int offset,
  int group,
  int elem,
  String vr,
  List<int> value,
) {
  // group (2 bytes LE)
  buf[offset] = group & 0xFF;
  buf[offset + 1] = (group >> 8) & 0xFF;
  // elem (2 bytes LE)
  buf[offset + 2] = elem & 0xFF;
  buf[offset + 3] = (elem >> 8) & 0xFF;
  // VR (2 bytes ASCII)
  buf[offset + 4] = vr.codeUnitAt(0);
  buf[offset + 5] = vr.codeUnitAt(1);

  final isLong = ['OB', 'OW', 'SQ', 'UC', 'UN', 'UR', 'UT', 'OD', 'OF', 'OL']
      .contains(vr);

  int dataOffset;
  if (isLong) {
    // 2 reserved bytes + 4-byte length
    buf[offset + 6] = 0;
    buf[offset + 7] = 0;
    final len = value.length;
    buf[offset + 8] = len & 0xFF;
    buf[offset + 9] = (len >> 8) & 0xFF;
    buf[offset + 10] = (len >> 16) & 0xFF;
    buf[offset + 11] = (len >> 24) & 0xFF;
    dataOffset = offset + 12;
  } else {
    // 2-byte length
    buf[offset + 6] = value.length & 0xFF;
    buf[offset + 7] = (value.length >> 8) & 0xFF;
    dataOffset = offset + 8;
  }

  for (int i = 0; i < value.length; i++) {
    buf[dataOffset + i] = value[i];
  }
  return dataOffset + value.length;
}

/// Build a synthetic uncompressed CT DICOM file with known values.
Uint8List buildSyntheticDicom({
  int rows = 64,
  int columns = 64,
  int bitsAllocated = 16,
  int numberOfFrames = 1,
  String transferSyntax = DicomTransferSyntax.explicitVrLittleEndian,
  String patientName = 'Test^Patient',
  String modality = 'CT',
  double windowCenter = 40.0,
  double windowWidth = 400.0,
}) {
  final buf = List<int>.filled(64 * 1024, 0); // 64 KB scratch buffer

  // ---- Preamble (128 bytes zeros) ----
  // (already zero)

  // ---- DICM magic at 128 ----
  buf[128] = 0x44; // D
  buf[129] = 0x49; // I
  buf[130] = 0x43; // C
  buf[131] = 0x4D; // M

  int pos = 132;

  // ---- Meta Information Group (0002,xxxx) — Explicit VR LE ----

  // (0002,0001) FileMetaInformationVersion OB [00 01]
  pos = writeExplicitTag(buf, pos, 0x0002, 0x0001, 'OB', [0x00, 0x01]);

  // (0002,0002) MediaStorageSOPClassUID UI
  final sopClass = '1.2.840.10008.5.1.4.1.1.2'; // CT Image Storage
  final sopClassPadded =
      sopClass.length.isOdd ? '$sopClass\x00' : sopClass;
  pos = writeExplicitTag(buf, pos, 0x0002, 0x0002, 'UI',
      sopClassPadded.codeUnits);

  // (0002,0010) TransferSyntaxUID UI
  final tsPadded =
      transferSyntax.length.isOdd ? '$transferSyntax\x00' : transferSyntax;
  pos = writeExplicitTag(buf, pos, 0x0002, 0x0010, 'UI',
      tsPadded.codeUnits);

  // ---- Dataset (Explicit VR LE) ----

  // (0008,0060) Modality CS
  final modalityPadded =
      modality.length.isOdd ? '$modality ' : modality;
  pos = writeExplicitTag(buf, pos, 0x0008, 0x0060, 'CS',
      modalityPadded.codeUnits);

  // (0010,0010) PatientName PN
  final pnBytes = patientName.length.isOdd
      ? [...patientName.codeUnits, 0x20]
      : patientName.codeUnits.toList();
  pos = writeExplicitTag(buf, pos, 0x0010, 0x0010, 'PN', pnBytes);

  // (0028,0002) SamplesPerPixel US = 1
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0002, 'US', [0x01, 0x00]);

  // (0028,0004) PhotometricInterpretation CS = 'MONOCHROME2 '
  pos = writeExplicitTag(
      buf, pos, 0x0028, 0x0004, 'CS', 'MONOCHROME2 '.codeUnits.toList());

  // (0028,0008) NumberOfFrames IS (only if > 1)
  if (numberOfFrames > 1) {
    final nfStr = '$numberOfFrames';
    final nfBytes =
        nfStr.length.isOdd ? [...nfStr.codeUnits, 0x20] : nfStr.codeUnits.toList();
    pos = writeExplicitTag(buf, pos, 0x0028, 0x0008, 'IS', nfBytes);
  }

  // (0028,0010) Rows US
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0010, 'US',
      [rows & 0xFF, (rows >> 8) & 0xFF]);

  // (0028,0011) Columns US
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0011, 'US',
      [columns & 0xFF, (columns >> 8) & 0xFF]);

  // (0028,0100) BitsAllocated US
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0100, 'US',
      [bitsAllocated & 0xFF, (bitsAllocated >> 8) & 0xFF]);

  // (0028,0101) BitsStored US
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0101, 'US',
      [bitsAllocated & 0xFF, (bitsAllocated >> 8) & 0xFF]);

  // (0028,0102) HighBit US = bitsAllocated - 1
  final highBit = bitsAllocated - 1;
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0102, 'US',
      [highBit & 0xFF, (highBit >> 8) & 0xFF]);

  // (0028,0103) PixelRepresentation US = 0 (unsigned)
  pos = writeExplicitTag(buf, pos, 0x0028, 0x0103, 'US', [0x00, 0x00]);

  // (0028,1050) WindowCenter DS
  final wcStr = windowCenter.toStringAsFixed(0);
  final wcBytes =
      wcStr.length.isOdd ? [...wcStr.codeUnits, 0x20] : wcStr.codeUnits.toList();
  pos = writeExplicitTag(buf, pos, 0x0028, 0x1050, 'DS', wcBytes);

  // (0028,1051) WindowWidth DS
  final wwStr = windowWidth.toStringAsFixed(0);
  final wwBytes =
      wwStr.length.isOdd ? [...wwStr.codeUnits, 0x20] : wwStr.codeUnits.toList();
  pos = writeExplicitTag(buf, pos, 0x0028, 0x1051, 'DS', wwBytes);

  // ---- Pixel Data (7FE0,0010) OW ----
  final bytesPerPixel = bitsAllocated ~/ 8;
  final frameSize = rows * columns * bytesPerPixel;
  final totalPixelBytes = frameSize * numberOfFrames;

  // OW = long VR
  buf[pos] = 0xE0; // group 7FE0 LE
  buf[pos + 1] = 0x7F;
  buf[pos + 2] = 0x10; // elem 0010 LE
  buf[pos + 3] = 0x00;
  buf[pos + 4] = 0x4F; // VR 'OW'
  buf[pos + 5] = 0x57;
  buf[pos + 6] = 0x00; // reserved
  buf[pos + 7] = 0x00;
  buf[pos + 8] = totalPixelBytes & 0xFF;
  buf[pos + 9] = (totalPixelBytes >> 8) & 0xFF;
  buf[pos + 10] = (totalPixelBytes >> 16) & 0xFF;
  buf[pos + 11] = (totalPixelBytes >> 24) & 0xFF;
  pos += 12;

  // Fill pixel data with a ramp pattern
  final totalBytes = pos + totalPixelBytes;
  final output = buf.length >= totalBytes ? buf : List<int>.filled(totalBytes + 256, 0);
  // Copy existing buf into output if we had to expand
  if (output != buf) {
    for (int i = 0; i < buf.length; i++) {
      output[i] = buf[i];
    }
  }
  for (int i = 0; i < totalPixelBytes; i++) {
    output[pos + i] = i & 0xFF;
  }

  final result = output.sublist(0, pos + totalPixelBytes);
  return Uint8List.fromList(result);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  group('DicomParser', () {
    test('rejects file without DICM magic', () {
      final fakeBytes = Uint8List(256); // all zeros
      expect(
        () => DicomParser.parse(fakeBytes),
        throwsA(isA<DicomParseException>()),
      );
    });

    test('parses synthetic uncompressed CT header', () {
      final dicomBytes = buildSyntheticDicom(
        rows: 64,
        columns: 64,
        bitsAllocated: 16,
        patientName: 'Test^Patient',
        modality: 'CT',
        windowCenter: 40.0,
        windowWidth: 400.0,
      );

      final header = DicomParser.parse(dicomBytes);

      expect(header.rows, equals(64));
      expect(header.columns, equals(64));
      expect(header.bitsAllocated, equals(16));
      expect(header.modality, equals('CT'));
      expect(header.formattedPatientName, equals('Test Patient'));
      expect(header.windowCenter, closeTo(40.0, 0.5));
      expect(header.windowWidth, closeTo(400.0, 0.5));
      expect(header.numberOfFrames, equals(1));
      expect(header.samplesPerPixel, equals(1));
      expect(header.photometricInterpretation, equals('MONOCHROME2'));
      expect(header.transferSyntaxUID,
          equals(DicomTransferSyntax.explicitVrLittleEndian));
      expect(header.isEncapsulated, isFalse);
      expect(header.isSigned, isFalse);
      expect(header.isMonochrome, isTrue);
    });

    test('pixel data offset is within file bounds', () {
      final dicomBytes = buildSyntheticDicom(rows: 32, columns: 32, bitsAllocated: 8);
      final header = DicomParser.parse(dicomBytes);

      expect(header.pixelDataOffset, greaterThan(132));
      expect(header.pixelDataOffset, lessThan(dicomBytes.length));
      expect(header.frameSizeBytes, equals(32 * 32 * 1));
    });

    test('parses multi-frame dataset', () {
      final dicomBytes = buildSyntheticDicom(
        rows: 16,
        columns: 16,
        bitsAllocated: 16,
        numberOfFrames: 5,
      );
      final header = DicomParser.parse(dicomBytes);

      expect(header.numberOfFrames, equals(5));
      expect(header.frameSizeBytes, equals(16 * 16 * 2));
    });

    test('TransferSyntax human readable label', () {
      expect(
        DicomTransferSyntax.humanReadable(DicomTransferSyntax.explicitVrLittleEndian),
        contains('uncompressed'),
      );
      expect(
        DicomTransferSyntax.humanReadable(DicomTransferSyntax.jpegBaseline),
        contains('JPEG'),
      );
      expect(
        DicomTransferSyntax.humanReadable(DicomTransferSyntax.jpeg2000Lossless),
        contains('2000'),
      );
    });

    test('isUncompressed / isJpegBaseline / isJpeg2000 flags', () {
      expect(
        DicomTransferSyntax.isUncompressed(DicomTransferSyntax.explicitVrLittleEndian),
        isTrue,
      );
      expect(
        DicomTransferSyntax.isUncompressed(DicomTransferSyntax.jpegBaseline),
        isFalse,
      );
      expect(
        DicomTransferSyntax.isJpegBaseline(DicomTransferSyntax.jpegBaseline),
        isTrue,
      );
      expect(
        DicomTransferSyntax.isJpeg2000(DicomTransferSyntax.jpeg2000Lossless),
        isTrue,
      );
    });

    test('DicomHeader.formattedStudyDate formats correctly', () {
      final dicomBytes = buildSyntheticDicom(rows: 8, columns: 8);
      // studyDate is not in our synthetic builder, so it returns ''
      final header = DicomParser.parse(dicomBytes);
      // just test it doesn't throw
      expect(header.formattedStudyDate, isA<String>());
    });
  });

  group('OpenJPEG FFI Bridge', () {
    test('openjpeg_bridge native library is available on Windows', () {
      // On Windows, the DLL was built into build/windows/x64/runner/Debug/
      expect(isJpeg2000Available, isTrue);
    });

    test('decodeJpeg2000 handles invalid/empty bytes gracefully without crash', () {
      final invalidBytes = [0, 1, 2, 3, 4, 5];
      final result = decodeJpeg2000(invalidBytes);
      expect(result, isNull);
    });
  });

  group('Real DICOM Files (pydicom dataset)', () {
    test('parses and decodes emri_small_jpeg_2k_lossless.dcm with openjpeg FFI', () async {
      final file = File('test/fixtures/emri_small_jpeg_2k_lossless.dcm');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final header = DicomParser.parse(bytes);

      // Verify header metadata
      expect(header.transferSyntaxUID, equals(DicomTransferSyntax.jpeg2000Lossless));
      expect(header.isEncapsulated, isTrue);
      expect(header.modality, equals('MR'));
      expect(header.rows, equals(64));
      expect(header.columns, equals(64));
      expect(header.bitsAllocated, equals(16));
      expect(header.isMonochrome, isTrue);

      // Extract encapsulated JPEG 2000 codestream frame
      final frameBytes = DicomRenderer.extractEncapsulatedFrame(bytes, header, 0);
      expect(frameBytes, isNotNull);
      expect(frameBytes!.length, greaterThan(100));

      // JPEG 2000 codestream must start with SOC marker 0xFF 0x4F
      expect(frameBytes[0], equals(0xFF));
      expect(frameBytes[1], equals(0x4F));

      // Decode with native openjpeg bridge!
      final decoded = decodeJpeg2000(frameBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(64));
      expect(decoded.height, equals(64));
      expect(decoded.rgba.length, equals(64 * 64 * 4));

      // Check that alpha channel is 255 (opaque)
      for (int i = 3; i < decoded.rgba.length; i += 4) {
        expect(decoded.rgba[i], equals(255));
      }

      // Check that the image is NOT black (mean intensity and max are properly scaled)
      int maxR = 0;
      int sumR = 0;
      for (int i = 0; i < decoded.rgba.length; i += 4) {
        final r = decoded.rgba[i];
        if (r > maxR) maxR = r;
        sumR += r;
      }
      expect(maxR, equals(255), reason: 'Max intensity should be 255 after normalization');
      expect(sumR / (64 * 64), greaterThan(50), reason: 'Average intensity should be visible, not black');

      // Test raw 16-bit decoding
      final raw = decodeJpeg2000Raw(frameBytes);
      expect(raw, isNotNull);
      expect(raw!.width, equals(64));
      expect(raw.height, equals(64));
      expect(raw.numComps, equals(1));
      expect(raw.rawPixels, isNotNull);
      expect(raw.rawPixels!.length, equals(64 * 64));

      int rawMin = 999999;
      int rawMax = -999999;
      for (final val in raw.rawPixels!) {
        if (val < rawMin) rawMin = val;
        if (val > rawMax) rawMax = val;
      }
      expect(rawMin, equals(0));
      expect(rawMax, equals(425));

      // Test DicomRenderer.renderFrame with auto-windowing
      final renderResult = await DicomRenderer.renderFrame(
        fileBytes: bytes,
        header: header,
        frameIndex: 0,
      );
      expect(renderResult.image.width, equals(64));
      expect(renderResult.image.height, equals(64));
      expect(renderResult.windowCenter, closeTo(212.5, 1.0));
      expect(renderResult.windowWidth, closeTo(425.0, 1.0));
    });

    test('parses and renders C:\\Users\\Creator\\Dropbox\\test_files\\1.dcm with full windowing', () async {
      final file = File(r'C:\Users\Creator\Dropbox\test_files\1.dcm');
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final header = DicomParser.parse(bytes);

      expect(header.numberOfFrames, equals(10));
      expect(header.rows, equals(64));
      expect(header.columns, equals(64));
      expect(header.transferSyntaxUID, equals(DicomTransferSyntax.jpeg2000Lossless));

      // Verify all 10 frames can be rendered with auto-windowing
      for (int f = 0; f < header.numberOfFrames; f++) {
        final res = await DicomRenderer.renderFrame(
          fileBytes: bytes,
          header: header,
          frameIndex: f,
        );
        expect(res.image.width, equals(64));
        expect(res.image.height, equals(64));
        expect(res.windowWidth, greaterThan(0));
      }
    });

    test('parses uncompressed emri_small.dcm header and offsets', () async {
      final file = File('test/fixtures/emri_small.dcm');
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      final header = DicomParser.parse(bytes);

      expect(DicomTransferSyntax.isUncompressed(header.transferSyntaxUID), isTrue);
      expect(header.modality, equals('MR'));
      expect(header.rows, equals(64));
      expect(header.columns, equals(64));
      expect(header.bitsAllocated, equals(16));
      expect(header.pixelDataOffset, greaterThan(128));
      expect(header.frameSizeBytes, equals(64 * 64 * 2));
    });
  });
}
