import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'universal_encoding_service.dart';

/// Centralised ZIP-reading utility that correctly handles non-UTF-8 filenames
/// (CP866 DOS Cyrillic, Windows-1251, Windows-1252, etc.).
///
/// **Why this exists:**
/// The `archive` package's [InputFileStream] reads file data lazily from disk and
/// calls `Utf8Decoder().convert(bytes)` without a catch block in [InputFileStream.readString].
/// This causes a [FormatException] ("Unexpected extension byte") when a ZIP archive
/// contains entry names encoded in legacy single-byte code pages (e.g. CP866 — the
/// DOS Cyrillic encoding used by Windows ZIP tools when the entry name is not flagged
/// as UTF-8 via bit 11 of the general-purpose bit flag).
///
/// The in-memory [InputStream] (used by [ZipDecoder.decodeBytes]) does have a
/// `try/catch` that falls back to `String.fromCharCodes`, so it does not throw.
/// However the fallback still produces mojibake (garbled text) because the raw bytes
/// are simply cast to Latin-1 code-points.
///
/// This service fixes both issues:
/// 1. Always reads the file into memory with [File.readAsBytesSync] and decodes with
///    [ZipDecoder.decodeBytes], so no [FormatException] is thrown.
/// 2. After decoding, every entry name is passed through [fixZipEntryName], which
///    detects and converts CP866 / Windows-1251 / Windows-1251 byte sequences to
///    proper Unicode strings.
class ZipArchiveService {
  const ZipArchiveService._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Reads a ZIP file from [filePath] and returns an [Archive] with correctly
  /// decoded entry names. Throws the same exceptions as [File.readAsBytesSync]
  /// and [ZipDecoder.decodeBytes] on malformed data.
  static Archive openFromPath(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    return openFromBytes(bytes);
  }

  /// Decodes a ZIP from [bytes] and returns an [Archive] with correctly decoded
  /// entry names.
  static Archive openFromBytes(Uint8List bytes, {bool verify = false}) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: verify);
    _fixArchiveNames(archive);
    return archive;
  }

  /// Decodes a ZIP from a [List<int>] and returns an [Archive] with correctly
  /// decoded entry names.
  static Archive openFromList(List<int> bytes, {bool verify = false}) {
    return openFromBytes(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      verify: verify,
    );
  }

  // ---------------------------------------------------------------------------
  // Entry-name decoding
  // ---------------------------------------------------------------------------

  /// Attempts to decode a raw ZIP entry name that may be encoded in CP866, CP1251,
  /// or another single-byte legacy code page instead of UTF-8.
  ///
  /// Rules applied in order:
  /// 1. If all code units are ≤ 0x7F (pure ASCII) → return as-is.
  /// 2. If any code unit is > 0xFF, the archive library already decoded the name
  ///    as valid UTF-8 (code units are Unicode scalar values) → return as-is.
  /// 3. Otherwise, reconstruct the raw byte sequence from the code units
  ///    (the archive library used `String.fromCharCodes` on the raw bytes, so each
  ///    code unit equals the original byte value) and then:
  ///    a. Try strict UTF-8.
  ///    b. Try CP866 (DOS Cyrillic) – the most common encoding in ZIP files
  ///       created by Russian/Bulgarian Windows tools.
  ///    c. Try Windows-1251 (Windows Cyrillic).
  ///    d. Fall through to [UniversalEncodingService.decodeBytesWithEncoding]
  ///       for automatic detection of other scripts (Greek, Central European, etc.).
  static String fixZipEntryName(String rawName) {
    // 1. Pure ASCII – nothing to do.
    final codeUnits = rawName.codeUnits;
    if (codeUnits.every((c) => c <= 0x7F)) return rawName;

    // 2. Contains a code unit > 0xFF → the archive library already decoded this
    //    as real UTF-8 multi-byte character. Keep it as-is.
    if (codeUnits.any((c) => c > 0xFF)) return rawName;

    // 3. Recover raw bytes and re-decode.
    final bytes = Uint8List.fromList(codeUnits);

    // a. Try strict UTF-8 first (handles archives that are already UTF-8 but the
    //    fallback path was used due to a different error).
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Not valid UTF-8.
    }

    // b. Try CP866 (DOS Cyrillic).
    final cp866 = _decodeCp866(bytes);
    if (_containsCyrillic(cp866)) return cp866;

    // c. Try Windows-1251 (Windows Cyrillic).
    final cp1251 = UniversalEncodingService.decodeWindows1251(bytes);
    if (_containsCyrillic(cp1251)) return cp1251;

    // d. Universal detection (Greek, Central European, Turkish, Western European).
    return UniversalEncodingService.decodeBytes(bytes);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _fixArchiveNames(Archive archive) {
    for (final file in archive.files) {
      file.name = fixZipEntryName(file.name);
    }
  }

  /// Returns true if [s] contains at least one Cyrillic character.
  static bool _containsCyrillic(String s) {
    for (final c in s.codeUnits) {
      if (c >= 0x0400 && c <= 0x04FF) return true;
    }
    return false;
  }

  /// Full CP866 (DOS Cyrillic / OEM 866) decoder.
  /// Reference: https://en.wikipedia.org/wiki/Code_page_866
  static String _decodeCp866(List<int> bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        buf.writeCharCode(b);
      } else if (b >= 0x80 && b <= 0x9F) {
        // А (0x0410) .. Я (0x042F)  [capital letters, first half]
        buf.writeCharCode(0x0410 + (b - 0x80));
      } else if (b >= 0xA0 && b <= 0xAF) {
        // а (0x0430) .. п (0x043F)  [small letters, first 16]
        buf.writeCharCode(0x0430 + (b - 0xA0));
      } else if (b >= 0xE0 && b <= 0xEF) {
        // р (0x0440) .. я (0x044F)  [small letters, last 16]
        buf.writeCharCode(0x0440 + (b - 0xE0));
      } else if (b == 0xF0) {
        buf.writeCharCode(0x0401); // Ё
      } else if (b == 0xF1) {
        buf.writeCharCode(0x0451); // ё
      } else if (b == 0xF2) {
        buf.writeCharCode(0x0404); // Є  (Ukrainian)
      } else if (b == 0xF3) {
        buf.writeCharCode(0x0454); // є
      } else if (b == 0xF4) {
        buf.writeCharCode(0x0407); // Ї
      } else if (b == 0xF5) {
        buf.writeCharCode(0x0457); // ї
      } else if (b == 0xF6) {
        buf.writeCharCode(0x0406); // І
      } else if (b == 0xF7) {
        buf.writeCharCode(0x0456); // і
      } else {
        // Pseudographics and other CP866 symbols: keep as-is (not Cyrillic).
        buf.writeCharCode(b);
      }
    }
    return buf.toString();
  }
}
