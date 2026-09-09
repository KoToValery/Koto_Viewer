import 'dart:typed_data';

// ---------------------------------------------------------------------------
// DICOM Transfer Syntax UIDs (NEMA PS3.5 Annex A)
// ---------------------------------------------------------------------------
class DicomTransferSyntax {
  static const String implicitVrLittleEndian = '1.2.840.10008.1.2';
  static const String explicitVrLittleEndian = '1.2.840.10008.1.2.1';
  static const String explicitVrBigEndian = '1.2.840.10008.1.2.2';
  static const String jpegBaseline = '1.2.840.10008.1.2.4.50';
  static const String jpegExtended = '1.2.840.10008.1.2.4.51';
  static const String jpegLossless = '1.2.840.10008.1.2.4.70';
  static const String jpegLsLossless = '1.2.840.10008.1.2.4.80';
  static const String jpegLsNearLossless = '1.2.840.10008.1.2.4.81';
  static const String jpeg2000Lossless = '1.2.840.10008.1.2.4.90';
  static const String jpeg2000Lossy = '1.2.840.10008.1.2.4.91';
  static const String rleLossless = '1.2.840.10008.1.2.5';

  static String humanReadable(String uid) {
    switch (uid) {
      case implicitVrLittleEndian:
        return 'Implicit VR Little Endian (uncompressed)';
      case explicitVrLittleEndian:
        return 'Explicit VR Little Endian (uncompressed)';
      case explicitVrBigEndian:
        return 'Explicit VR Big Endian (uncompressed)';
      case jpegBaseline:
        return 'JPEG Baseline (lossy)';
      case jpegExtended:
        return 'JPEG Extended (lossy)';
      case jpegLossless:
        return 'JPEG Lossless';
      case jpegLsLossless:
        return 'JPEG-LS Lossless';
      case jpegLsNearLossless:
        return 'JPEG-LS Near-lossless';
      case jpeg2000Lossless:
        return 'JPEG 2000 Lossless';
      case jpeg2000Lossy:
        return 'JPEG 2000 Lossy';
      case rleLossless:
        return 'RLE Lossless';
      default:
        return uid;
    }
  }

  static bool isUncompressed(String uid) =>
      uid == implicitVrLittleEndian ||
      uid == explicitVrLittleEndian ||
      uid == explicitVrBigEndian;

  static bool isJpegBaseline(String uid) =>
      uid == jpegBaseline || uid == jpegExtended;

  static bool isJpeg2000(String uid) =>
      uid == jpeg2000Lossless || uid == jpeg2000Lossy;

  static bool isRle(String uid) => uid == rleLossless;

  static bool isJpegLossless(String uid) =>
      uid == jpegLossless || uid == jpegLsLossless || uid == jpegLsNearLossless;
}

// ---------------------------------------------------------------------------
// DicomHeader — all parsed metadata
// ---------------------------------------------------------------------------
class DicomHeader {
  final String? patientName;
  final String? patientId;
  final String? patientBirthDate;
  final String? patientSex;
  final String? modality;
  final String? studyDate;
  final String? studyDescription;
  final String? seriesDescription;
  final String? institutionName;
  final String? manufacturer;
  final int rows;
  final int columns;
  final int bitsAllocated;
  final int bitsStored;
  final int highBit;
  final int pixelRepresentation; // 0 = unsigned, 1 = signed (two's complement)
  final String photometricInterpretation;
  final int samplesPerPixel;
  final double? windowCenter;
  final double? windowWidth;
  final double? rescaleIntercept;
  final double? rescaleSlope;
  final int numberOfFrames;
  final String transferSyntaxUID;

  /// Byte offset of the pixel data VALUE inside the file.
  final int pixelDataOffset;

  /// Total length in bytes of the pixel data (may be 0xFFFFFFFF for encapsulated).
  final int pixelDataLength;

  const DicomHeader({
    this.patientName,
    this.patientId,
    this.patientBirthDate,
    this.patientSex,
    this.modality,
    this.studyDate,
    this.studyDescription,
    this.seriesDescription,
    this.institutionName,
    this.manufacturer,
    required this.rows,
    required this.columns,
    required this.bitsAllocated,
    required this.bitsStored,
    required this.highBit,
    required this.pixelRepresentation,
    required this.photometricInterpretation,
    required this.samplesPerPixel,
    this.windowCenter,
    this.windowWidth,
    this.rescaleIntercept,
    this.rescaleSlope,
    required this.numberOfFrames,
    required this.transferSyntaxUID,
    required this.pixelDataOffset,
    required this.pixelDataLength,
  });

  bool get isEncapsulated => !DicomTransferSyntax.isUncompressed(transferSyntaxUID);
  bool get isSigned => pixelRepresentation == 1;
  bool get isMonochrome =>
      photometricInterpretation == 'MONOCHROME1' ||
      photometricInterpretation == 'MONOCHROME2';
  bool get isMonochrome1 => photometricInterpretation == 'MONOCHROME1';
  bool get isRgb =>
      photometricInterpretation == 'RGB' ||
      photometricInterpretation == 'YBR_FULL' ||
      photometricInterpretation == 'YBR_FULL_422';

  /// Bytes per pixel per sample
  int get bytesPerSample => (bitsAllocated + 7) >> 3;

  /// Bytes per single frame
  int get frameSizeBytes => rows * columns * bytesPerSample * samplesPerPixel;

  String get transferSyntaxLabel =>
      DicomTransferSyntax.humanReadable(transferSyntaxUID);

  /// Human-readable patient name (DICOM uses ^ as separator)
  String get formattedPatientName {
    if (patientName == null || patientName!.isEmpty) return 'Unknown';
    return patientName!.replaceAll('^', ' ').trim();
  }

  String get formattedStudyDate {
    if (studyDate == null || studyDate!.length < 8) return studyDate ?? '';
    // YYYYMMDD → YYYY-MM-DD
    return '${studyDate!.substring(0, 4)}-'
        '${studyDate!.substring(4, 6)}-'
        '${studyDate!.substring(6, 8)}';
  }
}

// ---------------------------------------------------------------------------
// Parser exception
// ---------------------------------------------------------------------------
class DicomParseException implements Exception {
  final String message;
  const DicomParseException(this.message);
  @override
  String toString() => 'DicomParseException: $message';
}

// ---------------------------------------------------------------------------
// _ByteReader — lightweight sequential reader over Uint8List
// ---------------------------------------------------------------------------
class _ByteReader {
  final Uint8List _bytes;
  int _pos = 0;
  bool _bigEndian = false;

  _ByteReader(this._bytes);

  int get position => _pos;
  int get length => _bytes.length;
  bool get isAtEnd => _pos >= _bytes.length;

  void seek(int pos) {
    if (pos < 0 || pos > _bytes.length) {
      throw DicomParseException('Seek out of bounds: $pos (length=${_bytes.length})');
    }
    _pos = pos;
  }

  void skip(int n) {
    _pos += n;
    if (_pos > _bytes.length) _pos = _bytes.length;
  }

  int readUint8() {
    if (_pos >= _bytes.length) throw DicomParseException('Unexpected end of file at $_pos');
    return _bytes[_pos++];
  }

  int readUint16() {
    if (_pos + 2 > _bytes.length) throw DicomParseException('Unexpected end of file at $_pos');
    final lo = _bytes[_pos];
    final hi = _bytes[_pos + 1];
    _pos += 2;
    return _bigEndian ? (hi | (lo << 8)) : (lo | (hi << 8));
  }

  int readUint32() {
    if (_pos + 4 > _bytes.length) throw DicomParseException('Unexpected end of file at $_pos');
    final b0 = _bytes[_pos];
    final b1 = _bytes[_pos + 1];
    final b2 = _bytes[_pos + 2];
    final b3 = _bytes[_pos + 3];
    _pos += 4;
    if (_bigEndian) {
      return (b3 | (b2 << 8) | (b1 << 16) | (b0 << 24)) & 0xFFFFFFFF;
    } else {
      return (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) & 0xFFFFFFFF;
    }
  }

  /// Read VR string (2 ASCII chars)
  String readVR() {
    if (_pos + 2 > _bytes.length) throw DicomParseException('Unexpected end of file reading VR at $_pos');
    final c1 = _bytes[_pos];
    final c2 = _bytes[_pos + 1];
    _pos += 2;
    return String.fromCharCodes([c1, c2]);
  }

  Uint8List readBytes(int n) {
    if (n <= 0) return Uint8List(0);
    final end = _pos + n;
    if (end > _bytes.length) {
      // Return what we have
      final slice = _bytes.sublist(_pos, _bytes.length);
      _pos = _bytes.length;
      return slice;
    }
    final slice = _bytes.sublist(_pos, end);
    _pos = end;
    return slice;
  }

  String readString(int n) {
    final bytes = readBytes(n);
    // DICOM strings are padded with space or null; trim trailing
    var s = String.fromCharCodes(bytes);
    return s.trimRight().replaceAll('\x00', '').trim();
  }

  Uint8List peekBytes(int n) {
    final end = (_pos + n).clamp(0, _bytes.length);
    return _bytes.sublist(_pos, end);
  }
}

// ---------------------------------------------------------------------------
// Main parser
// ---------------------------------------------------------------------------
class DicomParser {
  /// Parse the header from raw file bytes.
  /// Throws [DicomParseException] if the file is not valid DICOM.
  static DicomHeader parse(Uint8List bytes) {
    final r = _ByteReader(bytes);

    // ---- Validate DICM magic (PS3.10 §7.1) ----
    if (bytes.length < 132) {
      throw DicomParseException('File too small to be DICOM (${bytes.length} bytes)');
    }
    final magic = bytes.sublist(128, 132);
    if (magic[0] != 0x44 || magic[1] != 0x49 || magic[2] != 0x43 || magic[3] != 0x4D) {
      throw DicomParseException(
          'Not a valid DICOM file — missing DICM magic at offset 128. '
          'Got: ${magic.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }

    r.seek(132);

    // ---- Parse Meta Information Group (0002,xxxx) ----
    // Always Explicit VR Little Endian, regardless of dataset transfer syntax
    String transferSyntaxUID = DicomTransferSyntax.explicitVrLittleEndian;

    while (!r.isAtEnd) {
      if (r.position + 4 > r.length) break;

      final group = _readUint16LE(bytes, r.position);
      if (group != 0x0002) break; // meta group ends

      r.skip(2);
      final elem = _readUint16LE(bytes, r.position);
      r.skip(2);

      final vr = r.readVR();
      int length;
      if (_isLongVr(vr)) {
        r.skip(2); // reserved
        length = _readUint32LE(bytes, r.position);
        r.skip(4);
      } else {
        length = _readUint16LE(bytes, r.position);
        r.skip(2);
      }

      final tag = (group << 16) | elem;

      if (length == 0xFFFFFFFF) {
        // Undefined length — skip (rare in meta)
        break;
      }

      if (tag == 0x00020010) {
        // TransferSyntaxUID
        transferSyntaxUID = r.readString(length);
      } else {
        r.skip(length);
      }
    }

    // ---- Switch to dataset transfer syntax ----
    final isImplicit = transferSyntaxUID == DicomTransferSyntax.implicitVrLittleEndian;
    final isBigEndian = transferSyntaxUID == DicomTransferSyntax.explicitVrBigEndian;
    r._bigEndian = isBigEndian;

    // ---- Parse Dataset ----
    String? patientName;
    String? patientId;
    String? patientBirthDate;
    String? patientSex;
    String? modality;
    String? studyDate;
    String? studyDescription;
    String? seriesDescription;
    String? institutionName;
    String? manufacturer;
    int rows = 0;
    int columns = 0;
    int bitsAllocated = 16;
    int bitsStored = 16;
    int highBit = 15;
    int pixelRepresentation = 0;
    String photometricInterpretation = 'MONOCHROME2';
    int samplesPerPixel = 1;
    double? windowCenter;
    double? windowWidth;
    double? rescaleIntercept;
    double? rescaleSlope;
    int numberOfFrames = 1;
    int pixelDataOffset = 0;
    int pixelDataLength = 0;

    while (!r.isAtEnd) {
      if (r.position + 4 > r.length) break;

      final group = r.readUint16();
      final elem = r.readUint16();
      final tag = (group << 16) | elem;

      // Skip group length tags (gggg,0000) — they're obsolete but harmless
      if (elem == 0x0000 && !isImplicit) {
        // explicit: still has VR
        final vr = r.readVR();
        int len;
        if (_isLongVr(vr)) {
          r.skip(2);
          len = r.readUint32();
        } else {
          len = r.readUint16();
        }
        r.skip(len);
        continue;
      }

      // Handle Sequence Delimiter and Item tags
      if (tag == 0xFFFEE00D || tag == 0xFFFEE0DD) {
        r.skip(4); // length (always 0)
        continue;
      }
      if (tag == 0xFFFEE000) {
        // Item
        final itemLen = r.readUint32();
        if (itemLen == 0xFFFFFFFF) continue; // undefined length item
        r.skip(itemLen);
        continue;
      }

      String vr;
      int length;

      if (isImplicit) {
        // Implicit VR — no VR field, length is always 32-bit
        vr = _implicitVrForTag(group, elem);
        length = r.readUint32();
      } else {
        vr = r.readVR();
        if (_isLongVr(vr)) {
          r.skip(2); // reserved
          length = r.readUint32();
        } else {
          length = r.readUint16();
        }
      }

      // PixelData (7FE0,0010) — record offset then stop deep parsing
      if (tag == 0x7FE00010) {
        pixelDataOffset = r.position;
        pixelDataLength = length;
        break;
      }

      // Skip undefined length (sequences) gracefully
      if (length == 0xFFFFFFFF) {
        // We can't easily skip without parsing — just stop here;
        // pixel data tag parsing requires we reach it
        // Try to find pixel data tag manually
        _findPixelDataManually(bytes, r, result: (offset, len) {
          pixelDataOffset = offset;
          pixelDataLength = len;
        });
        break;
      }

      if (length == 0) continue;

      // Guard against corrupt length
      if (r.position + length > r.length) {
        // Clamp and skip remainder
        break;
      }

      switch (tag) {
        case 0x00100010:
          patientName = r.readString(length);
          break;
        case 0x00100020:
          patientId = r.readString(length);
          break;
        case 0x00100030:
          patientBirthDate = r.readString(length);
          break;
        case 0x00100040:
          patientSex = r.readString(length);
          break;
        case 0x00080060:
          modality = r.readString(length);
          break;
        case 0x00080020:
          studyDate = r.readString(length);
          break;
        case 0x00081030:
          studyDescription = r.readString(length);
          break;
        case 0x0008103E:
          seriesDescription = r.readString(length);
          break;
        case 0x00080080:
          institutionName = r.readString(length);
          break;
        case 0x00080070:
          manufacturer = r.readString(length);
          break;
        case 0x00280010:
          rows = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280011:
          columns = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280100:
          bitsAllocated = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280101:
          bitsStored = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280102:
          highBit = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280103:
          pixelRepresentation = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00280004:
          photometricInterpretation = r.readString(length);
          break;
        case 0x00280002:
          samplesPerPixel = _readUint16FromBytes(bytes, r.position, isBigEndian);
          r.skip(length);
          break;
        case 0x00281050:
          windowCenter = _parseDS(r.readString(length));
          break;
        case 0x00281051:
          windowWidth = _parseDS(r.readString(length));
          break;
        case 0x00281052:
          rescaleIntercept = _parseDS(r.readString(length));
          break;
        case 0x00281053:
          rescaleSlope = _parseDS(r.readString(length));
          break;
        case 0x00280008:
          final nfStr = r.readString(length);
          numberOfFrames = int.tryParse(nfStr.trim()) ?? 1;
          break;
        default:
          r.skip(length);
      }
    }

    if (rows == 0 || columns == 0) {
      throw DicomParseException(
          'Could not find image dimensions (Rows=$rows, Columns=$columns). '
          'File may be a DICOM SR or other non-image IOD.');
    }

    return DicomHeader(
      patientName: patientName,
      patientId: patientId,
      patientBirthDate: patientBirthDate,
      patientSex: patientSex,
      modality: modality,
      studyDate: studyDate,
      studyDescription: studyDescription,
      seriesDescription: seriesDescription,
      institutionName: institutionName,
      manufacturer: manufacturer,
      rows: rows,
      columns: columns,
      bitsAllocated: bitsAllocated,
      bitsStored: bitsStored,
      highBit: highBit,
      pixelRepresentation: pixelRepresentation,
      photometricInterpretation: photometricInterpretation,
      samplesPerPixel: samplesPerPixel,
      windowCenter: windowCenter,
      windowWidth: windowWidth,
      rescaleIntercept: rescaleIntercept,
      rescaleSlope: rescaleSlope,
      numberOfFrames: numberOfFrames,
      transferSyntaxUID: transferSyntaxUID,
      pixelDataOffset: pixelDataOffset,
      pixelDataLength: pixelDataLength,
    );
  }

  // ---- Helpers ----

  static int _readUint16LE(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) return 0;
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _readUint32LE(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return (bytes[offset] |
            (bytes[offset + 1] << 8) |
            (bytes[offset + 2] << 16) |
            (bytes[offset + 3] << 24)) &
        0xFFFFFFFF;
  }

  static int _readUint16FromBytes(Uint8List bytes, int offset, bool bigEndian) {
    if (offset + 2 > bytes.length) return 0;
    if (bigEndian) {
      return (bytes[offset] << 8) | bytes[offset + 1];
    }
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  /// VRs that use a 4-byte length field (preceded by 2 reserved bytes)
  static bool _isLongVr(String vr) {
    switch (vr) {
      case 'OB':
      case 'OD':
      case 'OF':
      case 'OL':
      case 'OW':
      case 'SQ':
      case 'UC':
      case 'UN':
      case 'UR':
      case 'UT':
        return true;
      default:
        return false;
    }
  }

  /// Best-guess VR for implicit VR transfer syntax
  static String _implicitVrForTag(int group, int elem) {
    final tag = (group << 16) | elem;
    switch (tag) {
      case 0x00280010:
      case 0x00280011:
      case 0x00280100:
      case 0x00280101:
      case 0x00280102:
      case 0x00280103:
      case 0x00280002:
        return 'US';
      case 0x7FE00010:
        return 'OW';
      default:
        return 'UN';
    }
  }

  /// Parse DICOM DS (Decimal String) — may contain multiple values separated by backslash
  static double? _parseDS(String s) {
    if (s.isEmpty) return null;
    // Take first value if multi-valued
    final parts = s.split('\\');
    return double.tryParse(parts.first.trim());
  }

  /// Brute-force search for (7FE0,0010) pixel data tag when sequences make
  /// sequential parsing too complex.
  static void _findPixelDataManually(
    Uint8List bytes,
    _ByteReader r, {
    required void Function(int offset, int length) result,
  }) {
    // Search for tag bytes: E0 7F 10 00 (LE) or 7F E0 00 10 (LE group/elem)
    // In LE: group=7FE0 → bytes [E0,7F], elem=0010 → bytes [10,00]
    final searchFrom = r.position;
    for (int i = searchFrom; i < bytes.length - 8; i++) {
      if (bytes[i] == 0xE0 &&
          bytes[i + 1] == 0x7F &&
          bytes[i + 2] == 0x10 &&
          bytes[i + 3] == 0x00) {
        // Check VR (may be OB or OW)
        int headerSize;
        if (i + 8 < bytes.length) {
          final vrBytes = [bytes[i + 4], bytes[i + 5]];
          final vrStr = String.fromCharCodes(vrBytes);
          if (vrStr == 'OB' || vrStr == 'OW') {
            // Explicit VR: skip VR (2) + reserved (2) = 4 bytes, then 4-byte length
            headerSize = 4 + 2 + 2 + 4;
            final len = _readUint32LE(bytes, i + 8);
            result(i + headerSize, len);
          } else {
            // Implicit — 4-byte length follows tag directly
            headerSize = 4 + 4;
            final len = _readUint32LE(bytes, i + 4);
            result(i + headerSize, len);
          }
        }
        return;
      }
    }
  }
}
