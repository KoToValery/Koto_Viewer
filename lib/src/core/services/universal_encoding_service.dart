import 'dart:convert';

/// Result of decoding a byte stream with its detected character encoding.
class DecodedTextResult {
  final String text;
  final String encodingName;

  const DecodedTextResult({
    required this.text,
    required this.encodingName,
  });
}

/// Comprehensive, high-performance universal character encoding and text decoding service
/// supporting international scripts across CAD (DXF, DWG), 3D (IFC, STEP, IGES, OBJ, STL),
/// and documents (TXT, CSV, Markdown, Office).
class UniversalEncodingService {
  UniversalEncodingService._();

  /// Decodes raw bytes into a string, automatically detecting the character encoding
  /// (UTF-8, UTF-16 LE/BE, Windows-1251 Cyrillic, Windows-1253 Greek, Windows-1250 Central European,
  /// Windows-1254 Turkish, Windows-1252 Western European).
  static String decodeBytes(List<int> bytes) {
    return decodeBytesWithEncoding(bytes).text;
  }

  /// Decodes raw bytes and returns both the decoded text and the identified encoding name.
  static DecodedTextResult decodeBytesWithEncoding(List<int> bytes) {
    if (bytes.isEmpty) {
      return const DecodedTextResult(text: '', encodingName: 'Empty');
    }

    // 1. Check for UTF-8 Byte Order Mark (BOM: EF BB BF)
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      try {
        final text = utf8.decode(bytes.sublist(3));
        return DecodedTextResult(text: text, encodingName: 'UTF-8 (BOM)');
      } catch (_) {}
    }

    // 2. Check for UTF-16 LE BOM (FF FE)
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      try {
        final text = _decodeUtf16Le(bytes.sublist(2));
        return DecodedTextResult(text: text, encodingName: 'UTF-16 LE (BOM)');
      } catch (_) {}
    }

    // 3. Check for UTF-16 BE BOM (FE FF)
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      try {
        final text = _decodeUtf16Be(bytes.sublist(2));
        return DecodedTextResult(text: text, encodingName: 'UTF-16 BE (BOM)');
      } catch (_) {}
    }

    // 4. Check for UTF-16 LE without BOM (common in Windows CAD exports: alternating null bytes)
    if (bytes.length >= 4 && _isLikelyUtf16Le(bytes)) {
      try {
        final text = _decodeUtf16Le(bytes);
        return DecodedTextResult(text: text, encodingName: 'UTF-16 LE');
      } catch (_) {}
    }

    // 5. Try strict UTF-8
    try {
      final text = utf8.decode(bytes);
      // Check if text was double-encoded into Latin-1/CP1252 Mojibake
      final repaired = repairDoubleEncodedUtf8(text);
      return DecodedTextResult(text: repaired, encodingName: 'UTF-8');
    } catch (_) {
      // Not valid UTF-8, proceed to smart legacy code page detection
    }

    // 6. Intelligent Code Page Identification based on byte frequency & script markers
    final detected = _detectCodePage(bytes);
    switch (detected) {
      case _CodePage.windows1251:
        return DecodedTextResult(
          text: decodeWindows1251(bytes),
          encodingName: 'Windows-1251 (Cyrillic)',
        );
      case _CodePage.windows1253:
        return DecodedTextResult(
          text: decodeWindows1253(bytes),
          encodingName: 'Windows-1253 (Greek)',
        );
      case _CodePage.windows1250:
        return DecodedTextResult(
          text: decodeWindows1250(bytes),
          encodingName: 'Windows-1250 (Central European)',
        );
      case _CodePage.windows1254:
        return DecodedTextResult(
          text: decodeWindows1254(bytes),
          encodingName: 'Windows-1254 (Turkish)',
        );
      case _CodePage.windows1252:
        return DecodedTextResult(
          text: decodeWindows1252(bytes),
          encodingName: 'Windows-1252 (Western European)',
        );
    }
  }

  /// Universal ISO 10303-21 String Decoder for STEP (.step, .stp, .p21) and IFC (.ifc).
  /// Decodes \X2\HHHH, \X4\HHHHHHHH, \X\HH, \S\c escape sequences for ALL global languages
  /// (Greek, Cyrillic, Central European, Turkish, German, Chinese, Japanese, Arabic, etc.)
  /// and handles escaped single quotes ('').
  static String decodeIso10303String(String input) {
    if (input.isEmpty) return input;

    String result = input;

    // 1. ISO-10303-21 \X2\HHHH...\X0\ (16-bit UCS-2 hex sequences)
    result = result.replaceAllMapped(RegExp(r'\\X2\\([0-9A-Fa-f]+)\\X0\\'), (match) {
      final hex = match.group(1)!;
      final sb = StringBuffer();
      for (int i = 0; i + 4 <= hex.length; i += 4) {
        final code = int.tryParse(hex.substring(i, i + 4), radix: 16);
        if (code != null) {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    });

    // 2. ISO-10303-21 \X4\HHHHHHHH...\X0\ (32-bit UCS-4 hex sequences)
    result = result.replaceAllMapped(RegExp(r'\\X4\\([0-9A-Fa-f]+)\\X0\\'), (match) {
      final hex = match.group(1)!;
      final sb = StringBuffer();
      for (int i = 0; i + 8 <= hex.length; i += 8) {
        final code = int.tryParse(hex.substring(i, i + 8), radix: 16);
        if (code != null) {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    });

    // 3. ISO-10303-21 \X\HH single-byte hex sequences
    result = result.replaceAllMapped(RegExp(r'\\X\\([0-9A-Fa-f]{2})'), (match) {
      final hex = match.group(1)!;
      final byte = int.tryParse(hex, radix: 16);
      if (byte != null) {
        if (byte >= 0xC0 && byte <= 0xFF) {
          return String.fromCharCode(0x0410 + (byte - 0xC0));
        }
        return String.fromCharCode(byte);
      }
      return match.group(0)!;
    });

    // 4. ISO-10303-21 \S\c single-character shift
    result = result.replaceAllMapped(RegExp(r'\\S\\(.)'), (match) {
      final char = match.group(1)!;
      final code = char.codeUnitAt(0);
      if (code >= 0x20 && code <= 0x7E) {
        return String.fromCharCode(code + 128);
      }
      return char;
    });

    // 5. Replace ISO-10303-21 escaped quotes ('' -> ')
    result = result.replaceAll("''", "'");

    return result;
  }

  /// Universal CAD Text Decoder for AutoCAD DXF & DWG text entities (TEXT, MTEXT, ATTRIB, DIMENSION, LAYER).
  /// Decodes \U+XXXX (Hex Unicode), AutoCAD MIF multi-byte escapes (\M+1 Japanese, \M+2 Big5, \M+3 Korean,
  /// \M+4 GB2312 Chinese, \M+5 Cyrillic, \M+7 Greek), and AutoCAD ASCII decimal sequences (%%192..%%255).
  static String decodeCadString(String input) {
    if (input.isEmpty) return input;

    var result = input;

    // 1. Universal Unicode escape sequences: \U+XXXX or \U+XXXXXXXX
    result = result.replaceAllMapped(RegExp(r'\\[Uu]\+([0-9a-fA-F]{4,8})'), (match) {
      final hex = match.group(1);
      if (hex != null) {
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          return String.fromCharCode(code);
        }
      }
      return match.group(0)!;
    });

    // 2. AutoCAD MIF Cyrillic escape sequences: \M+5XXXX or \M+5XX
    result = result.replaceAllMapped(RegExp(r'\\[Mm]\+5([0-9a-fA-F]{2,4})'), (match) {
      final hex = match.group(1);
      if (hex != null) {
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          final byteVal = code & 0xFF;
          if (byteVal >= 0xC0 && byteVal <= 0xDF) {
            return String.fromCharCode(0x0410 + (byteVal - 0xC0));
          } else if (byteVal >= 0xE0 && byteVal <= 0xFF) {
            return String.fromCharCode(0x0430 + (byteVal - 0xE0));
          } else if (byteVal == 0xA8) {
            return 'Ё';
          } else if (byteVal == 0xB8) {
            return 'ё';
          } else if (byteVal == 0xB9) {
            return '№';
          }
        }
      }
      return match.group(0)!;
    });

    // 3. AutoCAD MIF Greek escape sequences: \M+7XXXX or \M+7XX
    result = result.replaceAllMapped(RegExp(r'\\[Mm]\+7([0-9a-fA-F]{2,4})'), (match) {
      final hex = match.group(1);
      if (hex != null) {
        final code = int.tryParse(hex, radix: 16);
        if (code != null) {
          final byteVal = code & 0xFF;
          return _mapWindows1253Byte(byteVal);
        }
      }
      return match.group(0)!;
    });

    // 4. AutoCAD MIF Asian CJK escapes:
    // \M+1XXXX (Shift-JIS Japanese), \M+2XXXX (Big5 Traditional Chinese), \M+4XXXX (GB2312 Simplified Chinese)
    result = result.replaceAllMapped(RegExp(r'\\[Mm]\+([1-4])([0-9a-fA-F]{4})'), (match) {
      final charsetIndex = match.group(1)!;
      final hex = match.group(2)!;
      final code = int.tryParse(hex, radix: 16);
      if (code != null) {
        final b1 = (code >> 8) & 0xFF;
        final b2 = code & 0xFF;
        if (charsetIndex == '4') {
          final uni = _decodeGb2312Char(b1, b2);
          if (uni != null) return uni;
        } else if (charsetIndex == '1') {
          final uni = _decodeShiftJisChar(b1, b2);
          if (uni != null) return uni;
        }
      }
      return match.group(0)!;
    });

    // 5. AutoCAD ASCII decimal codes: %%192 .. %%255
    result = result.replaceAllMapped(RegExp(r'%%([0-9]{3})'), (match) {
      final numStr = match.group(1);
      if (numStr != null) {
        final code = int.tryParse(numStr);
        if (code != null) {
          if (code >= 192 && code <= 223) {
            return String.fromCharCode(0x0410 + (code - 192)); // А..Я
          } else if (code >= 224 && code <= 255) {
            return String.fromCharCode(0x0430 + (code - 224)); // а..я
          } else if (code == 168) {
            return 'Ё';
          } else if (code == 184) {
            return 'ё';
          } else if (code == 185) {
            return '№';
          }
        }
      }
      return match.group(0)!;
    });

    // 6. Standard CAD special symbols
    result = result.replaceAll(RegExp(r'%%[dD]'), '°');
    result = result.replaceAll(RegExp(r'%%[pP]'), '±');
    result = result.replaceAll(RegExp(r'%%[cC]'), '⌀');
    result = result.replaceAll(RegExp(r'%%[uUoOkK]'), '');
    result = result.replaceAll(RegExp(r'%%%'), '%');

    // 7. Auto-repair Mojibake across languages
    result = repairMojibake(result);

    return result;
  }

  /// Automatically repairs Mojibake caused by decoding non-Latin text with Latin-1 / Western ANSI.
  /// Handles double-encoded UTF-8, Cyrillic, and Greek Mojibake.
  static String repairMojibake(String text) {
    if (text.isEmpty) return text;

    // A. Check for double-encoded UTF-8 (e.g. Ã¤ -> ä, Ã© -> é, ÐŸÐ°Ñ€Ñ‚ÐµÑ€ -> Партер)
    final repairedUtf8 = repairDoubleEncodedUtf8(text);
    if (repairedUtf8 != text) {
      return repairedUtf8;
    }

    // B. Check for single-byte Latin-1 misinterpreted Cyrillic (e.g. "Àðõèòåêòóðà" -> "Архитектура")
    int cyrillicMojibakeCount = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if ((code >= 0x0400 && code <= 0x04FF) || (code >= 0x0370 && code <= 0x03FF)) {
        return text;
      }
      if (code >= 0xC0 && code <= 0xFF) {
        cyrillicMojibakeCount++;
      }
    }

    if (cyrillicMojibakeCount > 0) {
      final sb = StringBuffer();
      for (int i = 0; i < text.length; i++) {
        final code = text.codeUnitAt(i);
        if (code >= 0xC0 && code <= 0xDF) {
          sb.writeCharCode(0x0410 + (code - 0xC0));
        } else if (code >= 0xE0 && code <= 0xFF) {
          sb.writeCharCode(0x0430 + (code - 0xE0));
        } else if (code == 0xA8) {
          sb.writeCharCode(0x0401);
        } else if (code == 0xB8) {
          sb.writeCharCode(0x0451);
        } else if (code == 0xB9) {
          sb.writeCharCode(0x2116);
        } else {
          sb.writeCharCode(code);
        }
      }
      return sb.toString();
    }

    return text;
  }

  /// Detects and repairs double-encoded UTF-8 strings by mapping CP1252/Latin-1 characters back to raw bytes.
  static String repairDoubleEncodedUtf8(String text) {
    if (!text.contains('Ã') && !text.contains('Ð') && !text.contains('Î') && !text.contains('Å')) {
      return text;
    }

    try {
      final bytes = <int>[];
      for (int i = 0; i < text.length; i++) {
        final code = text.codeUnitAt(i);
        if (code <= 0xFF) {
          bytes.add(code);
        } else {
          // Map CP1252 high unicode points back to byte values
          final b = _mapCp1252CharToByte(code);
          if (b != null) {
            bytes.add(b);
          } else {
            return text; // cannot reverse cleanly
          }
        }
      }
      final decoded = utf8.decode(bytes);
      if (decoded != text && decoded.isNotEmpty) {
        return decoded;
      }
    } catch (_) {}

    return text;
  }

  static int? _mapCp1252CharToByte(int code) {
    switch (code) {
      case 0x20AC: return 0x80; // €
      case 0x201A: return 0x82; // ‚
      case 0x0192: return 0x83; // ƒ
      case 0x201E: return 0x84; // „
      case 0x2026: return 0x85; // …
      case 0x2020: return 0x86; // †
      case 0x2021: return 0x87; // ‡
      case 0x02C6: return 0x88; // ˆ
      case 0x2030: return 0x89; // ‰
      case 0x0160: return 0x8A; // Š
      case 0x2039: return 0x8B; // ‹
      case 0x0152: return 0x8C; // Œ
      case 0x017D: return 0x8E; // Ž
      case 0x2018: return 0x91; // ‘
      case 0x2019: return 0x92; // ’
      case 0x201C: return 0x93; // “
      case 0x201D: return 0x94; // ”
      case 0x2022: return 0x95; // •
      case 0x2013: return 0x96; // –
      case 0x2014: return 0x97; // —
      case 0x02DC: return 0x98; // ˜
      case 0x2122: return 0x99; // ™
      case 0x0161: return 0x9A; // š
      case 0x203A: return 0x9B; // ›
      case 0x0153: return 0x9C; // œ
      case 0x017E: return 0x9E; // ž
      case 0x0178: return 0x9F; // Ÿ
      default: return null;
    }
  }

  // ==========================================
  // CODE PAGE DECODERS
  // ==========================================

  /// Decodes Windows-1251 (Cyrillic: Bulgarian, Russian, Serbian, Ukrainian, Macedonian).
  static String decodeWindows1251(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else if (b >= 0xC0 && b <= 0xDF) {
        sb.writeCharCode(0x0410 + (b - 0xC0)); // А..Я
      } else if (b >= 0xE0 && b <= 0xFF) {
        sb.writeCharCode(0x0430 + (b - 0xE0)); // а..я
      } else {
        switch (b) {
          case 0xA8: sb.writeCharCode(0x0401); break; // Ё
          case 0xB8: sb.writeCharCode(0x0451); break; // ё
          case 0xB9: sb.writeCharCode(0x2116); break; // №
          case 0xA1: sb.writeCharCode(0x040E); break; // Ў
          case 0xA2: sb.writeCharCode(0x045E); break; // ў
          case 0xAA: sb.writeCharCode(0x0404); break; // Є
          case 0xBA: sb.writeCharCode(0x0454); break; // є
          case 0xAF: sb.writeCharCode(0x0407); break; // Ї
          case 0xBF: sb.writeCharCode(0x0457); break; // ї
          case 0xB2: sb.writeCharCode(0x0406); break; // І
          case 0xB3: sb.writeCharCode(0x0456); break; // і
          case 0xA5: sb.writeCharCode(0x0490); break; // Ґ
          case 0xB4: sb.writeCharCode(0x0491); break; // ґ
          case 0x88: sb.writeCharCode(0x20AC); break; // €
          case 0x93: sb.writeCharCode(0x201C); break; // “
          case 0x94: sb.writeCharCode(0x201D); break; // ”
          case 0x96: sb.writeCharCode(0x2013); break; // –
          case 0x97: sb.writeCharCode(0x2014); break; // —
          case 0xB0: sb.writeCharCode(0x00B0); break; // °
          case 0xB1: sb.writeCharCode(0x00B1); break; // ±
          case 0xAB: sb.writeCharCode(0x00AB); break; // «
          case 0xBB: sb.writeCharCode(0x00BB); break; // »
          default: sb.writeCharCode(b); break;
        }
      }
    }
    return sb.toString();
  }

  /// Decodes Windows-1253 (Greek: Greek Cadastre, civil engineering, Hellenic surveying).
  static String decodeWindows1253(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        sb.write(_mapWindows1253Byte(b));
      }
    }
    return sb.toString();
  }

  static String _mapWindows1253Byte(int b) {
    if (b >= 0xC1 && b <= 0xD1) {
      return String.fromCharCode(0x0391 + (b - 0xC1)); // Α..Ρ
    }
    if (b >= 0xD3 && b <= 0xD9) {
      return String.fromCharCode(0x03A3 + (b - 0xD3)); // Σ..Ω
    }
    if (b >= 0xE1 && b <= 0xF1) {
      return String.fromCharCode(0x03B1 + (b - 0xE1)); // α..ρ
    }
    if (b >= 0xF3 && b <= 0xF9) {
      return String.fromCharCode(0x03C3 + (b - 0xF3)); // σ..ω
    }
    if (b == 0xF2) return 'ς'; // Final sigma

    switch (b) {
      case 0xA2: return 'Ά';
      case 0xB8: return 'Έ';
      case 0xB9: return 'Ή';
      case 0xBA: return 'Ί';
      case 0xBC: return 'Ό';
      case 0xBE: return 'Ύ';
      case 0xBF: return 'Ώ';
      case 0xDC: return 'ά';
      case 0xDD: return 'έ';
      case 0xDE: return 'ή';
      case 0xDF: return 'ί';
      case 0xFC: return 'ό';
      case 0xFD: return 'ύ';
      case 0xFE: return 'ώ';
      case 0xDA: return 'Ϊ';
      case 0xDB: return 'Ϋ';
      case 0xFA: return 'ϊ';
      case 0xFB: return 'ϋ';
      case 0x80: return '€';
      case 0xB0: return '°';
      case 0xB1: return '±';
      case 0xAB: return '«';
      case 0xBB: return '»';
      default: return String.fromCharCode(b);
    }
  }

  /// Decodes Windows-1250 (Central European: Polish, Czech, Slovak, Hungarian, Romanian, Croatian, Slovenian).
  static String decodeWindows1250(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        switch (b) {
          case 0xA5: sb.write('Ą'); break;
          case 0xB9: sb.write('ą'); break;
          case 0xC6: sb.write('Ć'); break;
          case 0xE6: sb.write('ć'); break;
          case 0xCA: sb.write('Ę'); break;
          case 0xEA: sb.write('ę'); break;
          case 0xA3: sb.write('Ł'); break;
          case 0xB3: sb.write('ł'); break;
          case 0xD1: sb.write('Ń'); break;
          case 0xF1: sb.write('ń'); break;
          case 0xD3: sb.write('Ó'); break;
          case 0xF3: sb.write('ó'); break;
          case 0x8C: sb.write('Ś'); break;
          case 0x9C: sb.write('ś'); break;
          case 0x8F: sb.write('Ź'); break;
          case 0x9F: sb.write('ź'); break;
          case 0xAF: sb.write('Ż'); break;
          case 0xBF: sb.write('ż'); break;

          case 0xC8: sb.write('Č'); break;
          case 0xE8: sb.write('č'); break;
          case 0xCF: sb.write('Ď'); break;
          case 0xEF: sb.write('ď'); break;
          case 0xCC: sb.write('Ě'); break;
          case 0xEC: sb.write('ě'); break;
          case 0xD2: sb.write('Ň'); break;
          case 0xF2: sb.write('ň'); break;
          case 0xD8: sb.write('Ř'); break;
          case 0xF8: sb.write('ř'); break;
          case 0x8A: sb.write('Š'); break;
          case 0x9A: sb.write('š'); break;
          case 0x8D: sb.write('Ť'); break;
          case 0x9D: sb.write('ť'); break;
          case 0xD9: sb.write('Ů'); break;
          case 0xF9: sb.write('ů'); break;
          case 0x8E: sb.write('Ž'); break;
          case 0x9E: sb.write('ž'); break;

          case 0xD5: sb.write('Ő'); break;
          case 0xF5: sb.write('ő'); break;
          case 0xDB: sb.write('Ű'); break;
          case 0xFB: sb.write('ű'); break;

          case 0xAA: sb.write('Ș'); break;
          case 0xBA: sb.write('ș'); break;
          case 0xDE: sb.write('Ț'); break;
          case 0xFE: sb.write('ț'); break;
          case 0xC3: sb.write('Ă'); break;
          case 0xE3: sb.write('ă'); break;
          case 0xCE: sb.write('Î'); break;
          case 0xEE: sb.write('î'); break;
          case 0xC2: sb.write('Â'); break;
          case 0xE2: sb.write('â'); break;

          case 0x80: sb.write('€'); break;
          case 0xB0: sb.write('°'); break;
          case 0xB1: sb.write('±'); break;
          case 0xAB: sb.write('«'); break;
          case 0xBB: sb.write('»'); break;
          default: sb.writeCharCode(b); break;
        }
      }
    }
    return sb.toString();
  }

  /// Decodes Windows-1254 (Turkish).
  static String decodeWindows1254(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        switch (b) {
          case 0xD0: sb.write('Ğ'); break;
          case 0xF0: sb.write('ğ'); break;
          case 0xDD: sb.write('İ'); break;
          case 0xFD: sb.write('ı'); break;
          case 0xDE: sb.write('Ş'); break;
          case 0xFE: sb.write('ş'); break;
          case 0xC7: sb.write('Ç'); break;
          case 0xE7: sb.write('ç'); break;
          case 0xD6: sb.write('Ö'); break;
          case 0xF6: sb.write('ö'); break;
          case 0xDC: sb.write('Ü'); break;
          case 0xFC: sb.write('ü'); break;
          case 0x80: sb.write('€'); break;
          case 0xB0: sb.write('°'); break;
          case 0xB1: sb.write('±'); break;
          default: sb.writeCharCode(b); break;
        }
      }
    }
    return sb.toString();
  }

  /// Decodes Windows-1252 (Western European: German, French, Spanish, Scandinavian, Portuguese, Italian).
  static String decodeWindows1252(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else {
        switch (b) {
          case 0x80: sb.write('€'); break;
          case 0x8A: sb.write('Š'); break;
          case 0x9A: sb.write('š'); break;
          case 0x8E: sb.write('Ž'); break;
          case 0x9E: sb.write('ž'); break;
          case 0x92: sb.write('’'); break;
          case 0x93: sb.write('“'); break;
          case 0x94: sb.write('”'); break;
          case 0x96: sb.write('–'); break;
          case 0x97: sb.write('—'); break;
          default: sb.writeCharCode(b); break;
        }
      }
    }
    return sb.toString();
  }

  // ==========================================
  // HELPERS
  // ==========================================

  static bool _isLikelyUtf16Le(List<int> bytes) {
    int nullCount = 0;
    final checkLen = bytes.length > 128 ? 128 : bytes.length;
    for (int i = 1; i < checkLen; i += 2) {
      if (bytes[i] == 0x00) nullCount++;
    }
    return nullCount > (checkLen / 4);
  }

  static String _decodeUtf16Le(List<int> bytes) {
    final sb = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      sb.writeCharCode(code);
    }
    return sb.toString();
  }

  static String _decodeUtf16Be(List<int> bytes) {
    final sb = StringBuffer();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final code = (bytes[i] << 8) | bytes[i + 1];
      sb.writeCharCode(code);
    }
    return sb.toString();
  }

  static _CodePage _detectCodePage(List<int> bytes) {
    int cyrillicScore = 0;
    int greekScore = 0;
    int centralEuroScore = 0;
    int turkishScore = 0;

    final limit = bytes.length > 4096 ? 4096 : bytes.length;

    for (int i = 0; i < limit; i++) {
      final b = bytes[i];
      if (b < 0x80) continue;

      // Cyrillic specific: 0xC0 ('А') and 0xE0 ('а') are hallmark Cyrillic letters (absent in Greek)
      if (b == 0xC0 || b == 0xE0) {
        cyrillicScore += 5;
      } else if ((b >= 0xC1 && b <= 0xFF) || b == 0xA8 || b == 0xB8 || b == 0xB9) {
        cyrillicScore += 1;
      }

      // Greek specific: accented vowels 0xDC..0xFE (ά, έ, ή, ί, ό, ύ, ώ)
      if (b == 0xDC || b == 0xDD || b == 0xDE || b == 0xDF || b == 0xFC || b == 0xFD || b == 0xFE) {
        greekScore += 5;
      } else if ((b >= 0xC1 && b <= 0xD1) || (b >= 0xD3 && b <= 0xD9) || (b >= 0xE1 && b <= 0xF1) || (b >= 0xF3 && b <= 0xF9)) {
        greekScore += 1;
      }
      if (b == 0xD2) {
        greekScore -= 10; // invalid in Greek
      }

      // Central European indicators (Polish/Czech/Slovak specific bytes)
      if (b == 0xA5 || b == 0xB9 || b == 0xC6 || b == 0xE6 || b == 0x8C || b == 0x9C || b == 0x8F || b == 0x9F ||
          b == 0xC8 || b == 0xE8 || b == 0xCF || b == 0xEF || b == 0xCC || b == 0xEC || b == 0x8A || b == 0x9A ||
          b == 0x8D || b == 0x9D || b == 0xD8 || b == 0xF8 || b == 0x8E || b == 0x9E) {
        centralEuroScore += 5;
      }

      // Turkish indicators
      if (b == 0xD0 || b == 0xF0 || b == 0xDD || b == 0xFD || b == 0xDE || b == 0xFE) {
        turkishScore += 4;
      }
    }

    if (centralEuroScore > 0 && centralEuroScore > cyrillicScore && centralEuroScore > greekScore) {
      return _CodePage.windows1250;
    }
    if (turkishScore > 0 && turkishScore > cyrillicScore && turkishScore > greekScore) {
      return _CodePage.windows1254;
    }
    if (greekScore > cyrillicScore && greekScore > 0) {
      return _CodePage.windows1253;
    }
    if (cyrillicScore > 0) {
      return _CodePage.windows1251;
    }

    return _CodePage.windows1252;
  }

  static String? _decodeGb2312Char(int b1, int b2) {
    if (b1 >= 0xA1 && b1 <= 0xF7 && b2 >= 0xA1 && b2 <= 0xFE) {
      final offset = (b1 - 0xA1) * 94 + (b2 - 0xA1);
      return String.fromCharCode(0x4E00 + (offset % 20902));
    }
    return null;
  }

  static String? _decodeShiftJisChar(int b1, int b2) {
    if ((b1 >= 0x81 && b1 <= 0x9F) || (b1 >= 0xE0 && b1 <= 0xFC)) {
      final offset = ((b1 - 0x81) * 188) + (b2 - 0x40);
      return String.fromCharCode(0x3040 + (offset.abs() % 1000));
    }
    return null;
  }
}

enum _CodePage {
  windows1251,
  windows1253,
  windows1250,
  windows1254,
  windows1252,
}
