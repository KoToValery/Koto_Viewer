import 'dart:convert';
import 'dart:typed_data';
import '../models/docx_models.dart';
import 'docx_parser.dart';

/// Pure-Dart Word 97-2003 (.doc), RTF, and text parser.
class DocParser {
  /// Parses raw bytes of a `.doc` file into a structured [DocxDocument].
  static DocxDocument parse(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const DocxDocument(blocks: []);
    }

    // 1. Check if this is a .docx masquerading as .doc (Zip signature PK\x03\x04)
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      try {
        return DocxParser.parse(bytes);
      } catch (_) {
        // Fall back to general parser if docx parsing fails
      }
    }

    // 2. Check for RTF signature: {\rtf
    final prefix = String.fromCharCodes(bytes.take(20));
    if (prefix.startsWith(r'{\rtf')) {
      return _parseRtf(bytes);
    }

    // 3. Check for OLE Compound File signature: D0 CF 11 E0 A1 B1 1A E1
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1) {
      return _parseOleDoc(bytes);
    }

    // 4. Fallback: Treat as plain text / UTF-8 / CP1251
    return _parsePlainText(bytes);
  }

  static DocxDocument _parseRtf(Uint8List bytes) {
    String rawString;
    try {
      rawString = utf8.decode(bytes);
    } catch (_) {
      try {
        rawString = _decodeCp1251(bytes);
      } catch (_) {
        rawString = latin1.decode(bytes);
      }
    }

    final List<DocxBlock> blocks = [];
    final StringBuffer currentParagraph = StringBuffer();
    bool isBold = false;
    bool isItalic = false;
    int i = 0;
    int skipGroupDepth = 0;

    while (i < rawString.length) {
      final char = rawString[i];

      if (char == '{') {
        i++;
        // Check if group is a metadata/header destination group (e.g. {\fonttbl, {\colortbl, {\*, etc.)
        if (i < rawString.length && rawString[i] == '\\') {
          final start = i + 1;
          int end = start;
          while (end < rawString.length && _isAlpha(rawString[end])) {
            end++;
          }
          final groupName = rawString.substring(start, end).toLowerCase();
          if (groupName == '*' ||
              groupName == 'fonttbl' ||
              groupName == 'colortbl' ||
              groupName == 'stylesheet' ||
              groupName == 'info' ||
              groupName == 'generator') {
            skipGroupDepth++;
            i = end;
            continue;
          }
        }
        continue;
      } else if (char == '}') {
        if (skipGroupDepth > 0) {
          skipGroupDepth--;
        }
        i++;
        continue;
      }

      if (skipGroupDepth > 0) {
        i++;
        continue;
      }

      if (char == '\\') {
        i++;
        if (i >= rawString.length) break;

        // Check for special escapes like \'xx or \uN
        if (rawString[i] == "'") {
          // Hex byte e.g. \'e0 (Windows-1251 / ANSI char)
          if (i + 2 < rawString.length) {
            final hex = rawString.substring(i + 1, i + 3);
            final byteVal = int.tryParse(hex, radix: 16);
            if (byteVal != null) {
              currentParagraph.write(_decodeCp1251Byte(byteVal));
            }
            i += 3;
            continue;
          }
        } else if (rawString[i] == 'u' && i + 1 < rawString.length && _isDigitOrMinus(rawString[i + 1])) {
          // Unicode escape \u1024?
          i++;
          final start = i;
          while (i < rawString.length && _isDigitOrMinus(rawString[i])) {
            i++;
          }
          final numStr = rawString.substring(start, i);
          final codePoint = int.tryParse(numStr);
          if (codePoint != null) {
            final validCode = codePoint < 0 ? codePoint + 65536 : codePoint;
            currentParagraph.write(String.fromCharCode(validCode));
          }
          // RTF often follows \uN with a fallback char (skip space or next char)
          if (i < rawString.length && rawString[i] == '?') {
            i++;
          }
          continue;
        } else {
          // General control word \par, \b, \i, etc.
          final start = i;
          while (i < rawString.length && _isAlpha(rawString[i])) {
            i++;
          }
          final word = rawString.substring(start, i).toLowerCase();

          // Skip trailing optional number or space
          while (i < rawString.length && (_isDigit(rawString[i]) || rawString[i] == '-')) {
            i++;
          }
          if (i < rawString.length && rawString[i] == ' ') {
            i++;
          }

          if (word == 'par' || word == 'line') {
            final text = currentParagraph.toString().trim();
            if (text.isNotEmpty) {
              blocks.add(DocxParagraph(runs: [
                DocxRun(text: text, isBold: isBold, isItalic: isItalic),
              ]));
              currentParagraph.clear();
            }
          } else if (word == 'b') {
            isBold = true;
          } else if (word == 'b0') {
            isBold = false;
          } else if (word == 'i') {
            isItalic = true;
          } else if (word == 'i0') {
            isItalic = false;
          } else if (word == 'tab') {
            currentParagraph.write('    ');
          }
          continue;
        }
      } else if (char == '\r' || char == '\n') {
        i++;
      } else {
        currentParagraph.write(char);
        i++;
      }
    }

    final remaining = currentParagraph.toString().trim();
    if (remaining.isNotEmpty) {
      blocks.add(DocxParagraph(runs: [DocxRun(text: remaining)]));
    }

    if (blocks.isEmpty) {
      return _parsePlainText(bytes);
    }

    return DocxDocument(blocks: blocks);
  }

  static DocxDocument _parseOleDoc(Uint8List bytes) {
    // In Word 97-2003 OLE Compound Files, extract UTF-16LE text runs and 8-bit text
    final List<DocxBlock> blocks = [];
    final List<String> extractedParagraphs = [];

    // Scan for runs of valid UTF-16LE characters (Latin, Cyrillic, Numbers, Punctuation)
    final StringBuffer currentPara = StringBuffer();

    int i = 512; // Skip standard OLE 512-byte header
    while (i < bytes.length - 1) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);

      if (codeUnit == 0x0D || codeUnit == 0x07 || codeUnit == 0x0C) {
        // Paragraph / cell break
        final str = currentPara.toString().trim();
        if (str.length > 2) {
          extractedParagraphs.add(str);
        }
        currentPara.clear();
        i += 2;
      } else if (_isValidDocCharCode(codeUnit)) {
        currentPara.write(String.fromCharCode(codeUnit));
        i += 2;
      } else {
        if (currentPara.length > 3) {
          extractedParagraphs.add(currentPara.toString().trim());
          currentPara.clear();
        } else {
          currentPara.clear();
        }
        i += 2;
      }
    }

    final lastStr = currentPara.toString().trim();
    if (lastStr.length > 2) {
      extractedParagraphs.add(lastStr);
    }

    // Filter noise and deduplicate consecutive identical runs
    String lastAdded = '';
    for (final text in extractedParagraphs) {
      if (text.isNotEmpty && text != lastAdded && !_isNoise(text)) {
        blocks.add(DocxParagraph(runs: [DocxRun(text: text)]));
        lastAdded = text;
      }
    }

    if (blocks.isEmpty) {
      return _parsePlainText(bytes);
    }

    return DocxDocument(blocks: blocks);
  }

  static DocxDocument _parsePlainText(Uint8List bytes) {
    String decoded;
    try {
      decoded = utf8.decode(bytes);
    } catch (_) {
      try {
        decoded = _decodeCp1251(bytes);
      } catch (_) {
        decoded = latin1.decode(bytes);
      }
    }

    final lines = decoded.split(RegExp(r'\r?\n'));
    final List<DocxBlock> blocks = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        blocks.add(DocxParagraph(runs: [DocxRun(text: trimmed)]));
      }
    }

    return DocxDocument(blocks: blocks);
  }

  static bool _isValidDocCharCode(int code) {
    if (code >= 32 && code <= 126) return true; // Standard ASCII
    if (code >= 0x0400 && code <= 0x04FF) return true; // Cyrillic
    if (code >= 0x0370 && code <= 0x03FF) return true; // Greek
    if (code >= 0x00A0 && code <= 0x024F) return true; // Latin Extended
    if (code == 9 || code == 10 || code == 13) return true; // Whitespace
    return false;
  }

  static bool _isNoise(String text) {
    // If text contains mostly non-printable or system metadata signatures
    if (text.startsWith('Normal.dot') ||
        text.startsWith('Microsoft Word') ||
        text.contains('Root Entry') ||
        text.contains('WordDocument')) {
      return true;
    }
    return false;
  }

  static String _decodeCp1251(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(_decodeCp1251Byte(b));
    }
    return buffer.toString();
  }

  static String _decodeCp1251Byte(int b) {
    if (b < 128) return String.fromCharCode(b);
    if (b >= 192 && b <= 255) {
      // Cyrillic uppercase and lowercase in CP1251
      return String.fromCharCode(0x0410 + (b - 192));
    }
    switch (b) {
      case 168: return 'Ё';
      case 184: return 'ё';
      case 170: return 'Є';
      case 186: return 'є';
      case 175: return 'Ї';
      case 191: return 'ї';
      case 178: return 'І';
      case 179: return 'і';
      case 180: return 'ґ';
      case 165: return 'Ґ';
      case 130: return '‚';
      case 132: return '„';
      case 133: return '…';
      case 145: return '‘';
      case 146: return '’';
      case 147: return '“';
      case 148: return '”';
      case 150: return '–';
      case 151: return '—';
      case 160: return ' ';
      case 185: return '№';
      default: return String.fromCharCode(b);
    }
  }

  static bool _isAlpha(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  static bool _isDigitOrMinus(String ch) {
    if (ch == '-') return true;
    return _isDigit(ch);
  }
}
