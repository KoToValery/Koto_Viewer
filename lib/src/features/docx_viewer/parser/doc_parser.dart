import 'dart:convert';
import 'dart:typed_data';
import '../models/docx_models.dart';
import 'docx_parser.dart';

/// Pure-Dart Word 97-2003 (.doc), RTF, and text parser with table reconstruction and metadata stripping.
class DocParser {
  /// Parses raw bytes of a `.doc` / `.rtf` file into a structured [DocxDocument].
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
      } catch (_) {}
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

  // ===========================================================================
  // RTF Parser with Table support & Field Code filtering
  // ===========================================================================

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
    final StringBuffer currentCellOrPara = StringBuffer();
    final List<DocxTableCell> currentRowCells = [];
    final List<DocxTableRow> currentTableRows = [];

    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    int i = 0;
    int skipGroupDepth = 0;

    void flushCurrentTable() {
      if (currentRowCells.isNotEmpty) {
        currentTableRows.add(DocxTableRow(cells: List.from(currentRowCells)));
        currentRowCells.clear();
      }
      if (currentTableRows.isNotEmpty) {
        blocks.add(DocxTable(rows: List.from(currentTableRows)));
        currentTableRows.clear();
      }
    }

    void flushCurrentPara() {
      final text = cleanWordText(currentCellOrPara.toString());
      currentCellOrPara.clear();
      if (text.isNotEmpty) {
        flushCurrentTable();
        blocks.add(
          DocxParagraph(
            runs: [
              DocxRun(
                text: text,
                isBold: isBold,
                isItalic: isItalic,
                isUnderline: isUnderline,
              ),
            ],
          ),
        );
      }
    }

    while (i < rawString.length) {
      final char = rawString[i];

      if (char == '{') {
        i++;
        if (skipGroupDepth > 0) {
          skipGroupDepth++;
          continue;
        }

        // Check if group is a metadata/header destination group to skip
        if (i < rawString.length && rawString[i] == '\\') {
          final start = i + 1;
          int end = start;
          if (end < rawString.length && rawString[end] == '*') {
            // Destination group {\* ...
            skipGroupDepth = 1;
            i = end + 1;
            continue;
          }

          while (end < rawString.length && _isAlpha(rawString[end])) {
            end++;
          }
          final groupName = rawString.substring(start, end).toLowerCase();

          if (groupName == 'fonttbl' ||
              groupName == 'colortbl' ||
              groupName == 'stylesheet' ||
              groupName == 'info' ||
              groupName == 'generator' ||
              groupName == 'pict' ||
              groupName == 'object' ||
              groupName == 'fldinst' ||
              groupName == 'datastore' ||
              groupName == 'themedata' ||
              groupName == 'colorschememapping' ||
              groupName == 'latentstyles' ||
              groupName == 'header' ||
              groupName == 'footer' ||
              groupName == 'headerl' ||
              groupName == 'headerr' ||
              groupName == 'footerl' ||
              groupName == 'footerr' ||
              groupName == 'panose') {
            skipGroupDepth = 1;
            i = end;
            continue;
          }
        }
        continue;
      } else if (char == '}') {
        if (skipGroupDepth > 0) {
          skipGroupDepth--;
          i++;
          continue;
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
              currentCellOrPara.write(_decodeCp1251Byte(byteVal));
            }
            i += 3;
            continue;
          }
        } else if (rawString[i] == 'u' &&
            i + 1 < rawString.length &&
            _isDigitOrMinus(rawString[i + 1])) {
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
            currentCellOrPara.write(String.fromCharCode(validCode));
          }
          if (i < rawString.length && rawString[i] == '?') {
            i++;
          }
          continue;
        } else {
          // General control word \par, \cell, \row, \b, \i, \trowd, etc.
          final start = i;
          while (i < rawString.length && _isAlpha(rawString[i])) {
            i++;
          }
          final word = rawString.substring(start, i).toLowerCase();

          // Skip trailing optional number or space
          while (i < rawString.length &&
              (_isDigit(rawString[i]) || rawString[i] == '-')) {
            i++;
          }
          if (i < rawString.length && rawString[i] == ' ') {
            i++;
          }

          if (word == 'par' || word == 'line') {
            flushCurrentPara();
          } else if (word == 'cell') {
            // End of table cell
            final cellText = cleanWordText(currentCellOrPara.toString());
            currentCellOrPara.clear();
            currentRowCells.add(
              DocxTableCell(
                paragraphs: [
                  DocxParagraph(
                    runs: [
                      DocxRun(
                        text: cellText,
                        isBold: isBold,
                        isItalic: isItalic,
                        isUnderline: isUnderline,
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else if (word == 'row') {
            // End of table row
            if (currentRowCells.isNotEmpty) {
              currentTableRows.add(DocxTableRow(cells: List.from(currentRowCells)));
              currentRowCells.clear();
            }
          } else if (word == 'trowd') {
            // Start of table row properties
            if (currentCellOrPara.isNotEmpty) {
              flushCurrentPara();
            }
          } else if (word == 'b') {
            isBold = true;
          } else if (word == 'b0') {
            isBold = false;
          } else if (word == 'i') {
            isItalic = true;
          } else if (word == 'i0') {
            isItalic = false;
          } else if (word == 'ul') {
            isUnderline = true;
          } else if (word == 'ulnone') {
            isUnderline = false;
          } else if (word == 'tab') {
            currentCellOrPara.write('    ');
          }
          continue;
        }
      } else if (char == '\r' || char == '\n') {
        i++;
      } else {
        currentCellOrPara.write(char);
        i++;
      }
    }

    if (currentCellOrPara.isNotEmpty) {
      flushCurrentPara();
    }
    flushCurrentTable();

    if (blocks.isEmpty) {
      return _parsePlainText(bytes);
    }

    return DocxDocument(blocks: blocks);
  }

  // ===========================================================================
  // Word 97-2003 (.doc) OLE Compound File Parser with Tables & FIB
  // ===========================================================================

  static DocxDocument _parseOleDoc(Uint8List bytes) {
    // 1. Attempt to parse WordDocument stream using FIB (File Information Block)
    try {
      final docFromFib = _parseOleDocViaFib(bytes);
      if (docFromFib != null && docFromFib.blocks.isNotEmpty) {
        return docFromFib;
      }
    } catch (_) {}

    // 2. Fallback: Parse with state machine (filters field instructions & groups cells into tables)
    return _parseOleDocStreamStateMachine(bytes);
  }

  /// Extracts the main text stream from the WordDocument stream using FIB parameters.
  static DocxDocument? _parseOleDocViaFib(Uint8List bytes) {
    // Locate WordDocument stream inside OLE Compound File
    final wordDocOffset = _findWordDocumentStreamOffset(bytes);
    if (wordDocOffset < 0 || wordDocOffset + 0x68 > bytes.length) {
      return null;
    }

    final fibOffset = wordDocOffset;
    final wIdent = bytes[fibOffset] | (bytes[fibOffset + 1] << 8);
    if (wIdent != 0xA5EC) {
      return null;
    }

    // fcMin: offset in bytes where text characters start
    final fcMin = bytes[fibOffset + 0x18] |
        (bytes[fibOffset + 0x19] << 8) |
        (bytes[fibOffset + 0x1A] << 16) |
        (bytes[fibOffset + 0x1B] << 24);

    // ccpText: character count of main document text
    final ccpText = bytes[fibOffset + 0x4C] |
        (bytes[fibOffset + 0x4D] << 8) |
        (bytes[fibOffset + 0x4E] << 16) |
        (bytes[fibOffset + 0x4F] << 24);

    if (ccpText <= 0 || ccpText > 5000000) {
      return null;
    }

    final textStartOffset = wordDocOffset + (fcMin > 0 && fcMin < bytes.length ? fcMin : 512);
    final textSlice = bytes.sublist(
      textStartOffset.clamp(0, bytes.length),
      (textStartOffset + ccpText * 2).clamp(0, bytes.length),
    );

    return _parseTextStreamIntoBlocks(textSlice);
  }

  /// Finds the offset of the WordDocument stream inside the OLE file.
  static int _findWordDocumentStreamOffset(Uint8List bytes) {
    // In standard Word files, WordDocument is at offset 512 (sector 0) or preceded by directory
    if (bytes.length > 514 && (bytes[512] | (bytes[513] << 8)) == 0xA5EC) {
      return 512;
    }
    // Search for FIB magic 0xA5EC on 512-byte sector boundaries
    for (int offset = 512; offset < bytes.length - 2; offset += 512) {
      if ((bytes[offset] | (bytes[offset + 1] << 8)) == 0xA5EC) {
        return offset;
      }
    }
    return -1;
  }

  /// Parses text bytes with Word control characters into paragraphs and tables.
  static DocxDocument _parseOleDocStreamStateMachine(Uint8List bytes) {
    return _parseTextStreamIntoBlocks(bytes, startOffset: 512);
  }

  static DocxDocument _parseTextStreamIntoBlocks(
    Uint8List bytes, {
    int startOffset = 0,
  }) {
    final List<DocxBlock> blocks = [];
    final StringBuffer currentCellOrPara = StringBuffer();
    final List<DocxTableCell> currentRowCells = [];
    final List<DocxTableRow> currentTableRows = [];

    // State machine flags
    int fieldDepth = 0;
    bool inFieldInstruction = false; // between 0x13 and 0x14

    void flushCurrentTable() {
      if (currentRowCells.isNotEmpty) {
        currentTableRows.add(DocxTableRow(cells: List.from(currentRowCells)));
        currentRowCells.clear();
      }
      if (currentTableRows.isNotEmpty) {
        blocks.add(DocxTable(rows: List.from(currentTableRows)));
        currentTableRows.clear();
      }
    }

    void flushCurrentPara() {
      final text = cleanWordText(currentCellOrPara.toString());
      currentCellOrPara.clear();
      if (text.isNotEmpty && !_isStyleOrNoise(text)) {
        flushCurrentTable();
        blocks.add(DocxParagraph(runs: [DocxRun(text: text)]));
      }
    }

    int i = startOffset;
    while (i < bytes.length - 1) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);

      // Word Field handling
      if (codeUnit == 0x13) {
        // Field Start {
        fieldDepth++;
        inFieldInstruction = true;
        i += 2;
        continue;
      } else if (codeUnit == 0x14) {
        // Field Separator (instruction ended, result begins)
        inFieldInstruction = false;
        i += 2;
        continue;
      } else if (codeUnit == 0x15) {
        // Field End }
        if (fieldDepth > 0) fieldDepth--;
        inFieldInstruction = false;
        i += 2;
        continue;
      }

      // If inside field instruction (e.g. PAGE \* MERGEFORMAT), ignore characters
      if (inFieldInstruction) {
        i += 2;
        continue;
      }

      // Table cell delimiter (0x07 = ASCII Bell / Cell Mark)
      if (codeUnit == 0x07) {
        final cellText = cleanWordText(currentCellOrPara.toString());
        currentCellOrPara.clear();
        currentRowCells.add(
          DocxTableCell(
            paragraphs: [
              DocxParagraph(runs: [DocxRun(text: cellText)]),
            ],
          ),
        );
        i += 2;
        continue;
      }

      // Paragraph / Row delimiter (0x0D = \r)
      if (codeUnit == 0x0D || codeUnit == 0x0C) {
        if (currentRowCells.isNotEmpty) {
          // Table row completed
          currentTableRows.add(DocxTableRow(cells: List.from(currentRowCells)));
          currentRowCells.clear();
        } else {
          flushCurrentPara();
        }
        i += 2;
        continue;
      }

      if (_isValidDocCharCode(codeUnit)) {
        currentCellOrPara.write(String.fromCharCode(codeUnit));
        i += 2;
      } else {
        if (currentCellOrPara.length > 2) {
          flushCurrentPara();
        } else {
          currentCellOrPara.clear();
        }
        i += 2;
      }
    }

    if (currentCellOrPara.isNotEmpty) {
      flushCurrentPara();
    }
    flushCurrentTable();

    // If UTF-16LE yielded no blocks, try 8-bit text streams (CP1251)
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
      final cleaned = cleanWordText(line);
      if (cleaned.isNotEmpty && !_isStyleOrNoise(cleaned)) {
        blocks.add(DocxParagraph(runs: [DocxRun(text: cleaned)]));
      }
    }

    return DocxDocument(blocks: blocks);
  }

  // ===========================================================================
  // Text Cleaning & Word Field / Style Filter Utilities
  // ===========================================================================

  /// Strips Word field codes (e.g. `PAGE \* MERGEFORMAT`), style names, and binary artifacts.
  static String cleanWordText(String text) {
    if (text.isEmpty) return '';

    var cleaned = text;

    // 1. Strip Word field instructions & format switches
    cleaned = cleaned.replaceAll(
      RegExp(r'PAGE\s*\\\*?\s*MERGEFORMAT\w*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'NUMPAGES\s*\\\*?\s*MERGEFORMAT\w*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\\\*?\s*MERGEFORMAT\w*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\\\*?\s*CHARFORMAT\w*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(PAGE|NUMPAGES|DATE|TIME|TOC|HYPERLINK|FILENAME|AUTHOR|TITLE|SUBJECT|MERGEFORMAT|FORMTEXT|FORMDROPDOWN|FORMCHECKBOX|NOTEREF|PAGEREF|STYLEREF|AUTOTEXT|AUTONUM|DOCPROPERTY|DOCVARIABLE|SECTIONPAGES|SECTION)\b\s*(\\\*?\s*\w+)*',
        caseSensitive: false,
      ),
      '',
    );

    // 2. Strip stray style names if they appear alone in a cell or paragraph
    cleaned = cleaned.replaceAll(
      RegExp(r'^(Table Normal|Normal Table|Table Grid|Default Paragraph Font)$', caseSensitive: false),
      '',
    );

    // 3. Strip unprintable control characters (except tab)
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

    // 4. Normalize spaces
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{3,}'), '    ');

    return cleaned.trim();
  }

  static bool _isStyleOrNoise(String text) {
    final lower = text.toLowerCase();
    if (lower == 'table normal' ||
        lower == 'normal table' ||
        lower == 'table grid' ||
        lower == 'default paragraph font' ||
        lower.startsWith('normal.dot') ||
        lower.startsWith('microsoft word') ||
        lower.contains('root entry') ||
        lower.contains('worddocument') ||
        lower.contains('summaryinformation') ||
        lower.contains('compobj')) {
      return true;
    }
    return false;
  }

  static bool _isValidDocCharCode(int code) {
    if (code >= 32 && code <= 126) return true; // Standard ASCII
    if (code >= 0x0400 && code <= 0x04FF) return true; // Cyrillic
    if (code >= 0x0370 && code <= 0x03FF) return true; // Greek
    if (code >= 0x00A0 && code <= 0x024F) return true; // Latin Extended
    if (code == 9 || code == 10 || code == 13) return true; // Whitespace
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
