import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/cdr_document.dart';

/// Pure-Dart Parser for CorelDRAW (.cdr) vector graphics files.
/// Supports both modern ZIP-based containers (CorelDRAW X4 to 2024+)
/// and legacy RIFF containers (CorelDRAW v3 to v13 / X3).
class CdrParser {
  /// Parses a CorelDRAW (.cdr) file from raw bytes.
  static CdrDocument parse(Uint8List bytes, {int fileSizeBytes = 0}) {
    if (bytes.length < 16) {
      throw const FormatException('File is too small to be a valid CorelDRAW (.cdr) file.');
    }

    final effectiveSize = fileSizeBytes > 0 ? fileSizeBytes : bytes.length;

    // 1. Check for Modern ZIP-based CorelDRAW container (PK\x03\x04)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      return _parseModernZipCdr(bytes, effectiveSize);
    }

    // 2. Check for Legacy RIFF CorelDRAW container (RIFF....CDR.)
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return _parseLegacyRiffCdr(bytes, effectiveSize);
    }

    throw const FormatException(
      'Unrecognized CorelDRAW format. File must be a valid modern CorelDRAW package (ZIP) or legacy RIFF container.',
    );
  }

  /// Parses modern CorelDRAW X4+ ZIP container.
  static CdrDocument _parseModernZipCdr(Uint8List bytes, int fileSizeBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw FormatException('Failed to decompress CorelDRAW archive: $e');
    }

    // Locate preview thumbnail image
    ArchiveFile? thumbnailFile;
    const candidatePaths = [
      'metadata/thumbnails/thumbnail.png',
      'previews/thumbnail.png',
      'thumbnail.png',
      'previews/thumbnail.bmp',
      'metadata/thumbnails/thumbnail.bmp',
      'thumbnail.bmp',
    ];

    for (final path in candidatePaths) {
      thumbnailFile = archive.findFile(path);
      if (thumbnailFile != null && thumbnailFile.content.isNotEmpty) {
        break;
      }
    }

    // Fallback: search for any PNG or BMP in the archive
    if (thumbnailFile == null) {
      for (final f in archive.files) {
        final lower = f.name.toLowerCase();
        if ((lower.endsWith('.png') || lower.endsWith('.bmp') || lower.endsWith('.jpg')) &&
            f.content.isNotEmpty) {
          thumbnailFile = f;
          break;
        }
      }
    }

    if (thumbnailFile == null) {
      throw const FormatException(
        'CorelDRAW file does not contain an embedded preview image or was saved without thumbnail preview.',
      );
    }

    final Uint8List imgBytes = Uint8List.fromList(thumbnailFile.content as List<int>);

    // Parse metadata XML if present
    String generator = 'CorelDRAW Graphics';
    String? title;
    int pageCount = 1;

    final metaFile = archive.findFile('metadata/metadata.xml') ?? archive.findFile('metadata.xml');
    if (metaFile != null && metaFile.content.isNotEmpty) {
      try {
        final xmlStr = utf8.decode(metaFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(xmlStr);

        // Generator / Version
        final genElem = doc.findAllElements('generator').firstOrNull ??
            doc.findAllElements('creator').firstOrNull;
        if (genElem != null && genElem.innerText.trim().isNotEmpty) {
          generator = genElem.innerText.trim();
        }

        // Title
        final titleElem = doc.findAllElements('title').firstOrNull;
        if (titleElem != null && titleElem.innerText.trim().isNotEmpty) {
          title = titleElem.innerText.trim();
        }

        // Page Count
        final pageElem = doc.findAllElements('pageCount').firstOrNull ??
            doc.findAllElements('pages').firstOrNull;
        if (pageElem != null) {
          pageCount = int.tryParse(pageElem.innerText.trim()) ?? 1;
        }
      } catch (_) {}
    }

    // Extract image dimensions
    final (int? width, int? height) = _extractImageDimensions(imgBytes);

    return CdrDocument(
      imageBytes: imgBytes,
      width: width,
      height: height,
      generator: generator,
      title: title,
      pageCount: pageCount,
      fileSizeBytes: fileSizeBytes,
      isZipBased: true,
    );
  }

  /// Parses legacy CorelDRAW (v3 to v13 / X3) RIFF container.
  static CdrDocument _parseLegacyRiffCdr(Uint8List bytes, int fileSizeBytes) {
    if (bytes.length < 12) {
      throw const FormatException('Invalid RIFF header length.');
    }

    final riffType = String.fromCharCodes(bytes.sublist(8, 12));
    if (!riffType.startsWith('CDR')) {
      throw FormatException('RIFF container is not a CorelDRAW document (Type: $riffType).');
    }

    // Identify version from RIFF 4CC
    String generator;
    switch (riffType) {
      case 'CDR ':
        generator = 'CorelDRAW v3';
        break;
      case 'CDR4':
        generator = 'CorelDRAW v4';
        break;
      case 'CDR5':
        generator = 'CorelDRAW v5';
        break;
      case 'CDR6':
        generator = 'CorelDRAW v6';
        break;
      case 'CDR7':
        generator = 'CorelDRAW v7';
        break;
      case 'CDR8':
        generator = 'CorelDRAW v8';
        break;
      case 'CDR9':
        generator = 'CorelDRAW v9';
        break;
      case 'CDRA':
        generator = 'CorelDRAW 10';
        break;
      case 'CDRB':
        generator = 'CorelDRAW 11';
        break;
      case 'CDRC':
        generator = 'CorelDRAW 12';
        break;
      case 'CDRD':
        generator = 'CorelDRAW X3 (v13)';
        break;
      default:
        generator = 'CorelDRAW Legacy ($riffType)';
        break;
    }

    // Search for DISP or BMP chunk containing DIB bitmap
    Uint8List? dibBytes;
    int offset = 12;
    final byteData = ByteData.sublistView(bytes);

    while (offset + 8 <= bytes.length) {
      final chunkTag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);
      final dataStart = offset + 8;
      final dataEnd = dataStart + chunkSize;

      if (dataEnd > bytes.length) break;

      if (chunkTag == 'DISP' || chunkTag == 'bmp ' || chunkTag == 'BMP ') {
        // Look for BITMAPINFOHEADER (0x28 0x00 0x00 0x00) inside the chunk
        for (int i = dataStart; i <= dataEnd - 40; i++) {
          if (byteData.getUint32(i, Endian.little) == 40) {
            // Found BITMAPINFOHEADER!
            dibBytes = bytes.sublist(i, dataEnd);
            break;
          }
        }
        if (dibBytes != null) break;
      }

      // Word alignment padding for RIFF chunks
      offset = dataEnd + (chunkSize % 2);
    }

    if (dibBytes == null) {
      throw FormatException(
        'Legacy $generator file has no embedded preview thumbnail.',
      );
    }

    // Convert DIB to standard BMP format by prepending 14-byte BITMAPFILEHEADER
    final bmpBytes = _convertDibToBmp(dibBytes);
    final (int? width, int? height) = _extractImageDimensions(bmpBytes);

    return CdrDocument(
      imageBytes: bmpBytes,
      width: width,
      height: height,
      generator: generator,
      title: null,
      pageCount: 1,
      fileSizeBytes: fileSizeBytes,
      isZipBased: false,
    );
  }

  /// Converts Windows DIB (Device Independent Bitmap) bytes to a standard BMP file byte array.
  static Uint8List _convertDibToBmp(Uint8List dib) {
    if (dib.length < 40) return dib;

    final dibBd = ByteData.sublistView(dib);
    final headerSize = dibBd.getUint32(0, Endian.little);
    final bpp = dibBd.getUint16(14, Endian.little);
    final colorsUsed = dibBd.getUint32(32, Endian.little);

    // Calculate color table size if indexed
    int paletteSize = 0;
    if (bpp <= 8) {
      final numColors = colorsUsed > 0 ? colorsUsed : (1 << bpp);
      paletteSize = numColors * 4;
    }

    final pixelOffset = 14 + headerSize + paletteSize;
    final totalFileSize = 14 + dib.length;

    final bmp = Uint8List(totalFileSize);
    final bmpBd = ByteData.sublistView(bmp);

    // BITMAPFILEHEADER (14 bytes)
    bmp[0] = 0x42; // "B"
    bmp[1] = 0x4D; // "M"
    bmpBd.setUint32(2, totalFileSize, Endian.little);
    bmpBd.setUint16(6, 0, Endian.little); // Reserved
    bmpBd.setUint16(8, 0, Endian.little); // Reserved
    bmpBd.setUint32(10, pixelOffset, Endian.little); // Offset to image bits

    // Copy DIB data after header
    bmp.setRange(14, totalFileSize, dib);

    return bmp;
  }

  /// Extracts width and height from PNG or BMP header bytes.
  static (int?, int?) _extractImageDimensions(Uint8List bytes) {
    if (bytes.length >= 24) {
      final bd = ByteData.sublistView(bytes);

      // PNG: Width at byte 16, Height at byte 20 (big-endian 32-bit int)
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        final w = bd.getUint32(16, Endian.big);
        final h = bd.getUint32(20, Endian.big);
        return (w > 0 ? w : null, h > 0 ? h : null);
      }

      // BMP: Width at byte 18, Height at byte 22 (little-endian 32-bit int)
      if (bytes[0] == 0x42 && bytes[1] == 0x4D && bytes.length >= 26) {
        final w = bd.getInt32(18, Endian.little).abs();
        final h = bd.getInt32(22, Endian.little).abs();
        return (w > 0 ? w : null, h > 0 ? h : null);
      }
    }
    return (null, null);
  }
}