import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../models/docx_models.dart';

/// Pure-Dart Word Document (.docx) Parser.
class DocxParser {
  /// Parses bytes of a .docx file into a structured [DocxDocument].
  static DocxDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXmlFile = archive.findFile('word/document.xml');

    if (documentXmlFile == null) {
      throw Exception('Invalid DOCX format: word/document.xml missing.');
    }

    final xmlString = utf8.decode(documentXmlFile.content as List<int>);
    final documentXml = xml.XmlDocument.parse(xmlString);

    final bodyElement = documentXml.findAllElements('w:body').firstOrNull;
    if (bodyElement == null) {
      return const DocxDocument(blocks: []);
    }

    final List<DocxBlock> blocks = [];

    for (final child in bodyElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'p') {
        final paragraph = _parseParagraph(child);
        if (paragraph.runs.isNotEmpty || paragraph.headingLevel != DocxHeadingLevel.none) {
          blocks.add(paragraph);
        }
      } else if (child.name.local == 'tbl') {
        final table = _parseTable(child);
        if (table.rows.isNotEmpty) {
          blocks.add(table);
        }
      }
    }

    return DocxDocument(blocks: blocks);
  }

  static DocxParagraph _parseParagraph(xml.XmlElement pElement) {
    final pPr = pElement.findElements('w:pPr').firstOrNull;

    DocxHeadingLevel heading = DocxHeadingLevel.none;
    bool isBullet = false;
    TextAlign align = TextAlign.start;

    if (pPr != null) {
      // 1. Heading style
      final pStyle = pPr.findElements('w:pStyle').firstOrNull;
      if (pStyle != null) {
        final val = (pStyle.getAttribute('w:val') ?? '').toLowerCase();
        if (val.contains('title')) {
          heading = DocxHeadingLevel.title;
        } else if (val.contains('heading 1') || val == 'heading1' || val == '1') {
          heading = DocxHeadingLevel.h1;
        } else if (val.contains('heading 2') || val == 'heading2' || val == '2') {
          heading = DocxHeadingLevel.h2;
        } else if (val.contains('heading 3') || val == 'heading3' || val == '3') {
          heading = DocxHeadingLevel.h3;
        } else if (val.contains('heading 4') || val == 'heading4' || val == '4') {
          heading = DocxHeadingLevel.h4;
        } else if (val.contains('heading 5') || val == 'heading5' || val == '5') {
          heading = DocxHeadingLevel.h5;
        } else if (val.contains('heading 6') || val == 'heading6' || val == '6') {
          heading = DocxHeadingLevel.h6;
        }
      }

      // 2. Bullet / Numbered list
      if (pPr.findElements('w:numPr').isNotEmpty) {
        isBullet = true;
      }

      // 3. Alignment
      final jc = pPr.findElements('w:jc').firstOrNull;
      if (jc != null) {
        final val = (jc.getAttribute('w:val') ?? '').toLowerCase();
        if (val == 'center') {
          align = TextAlign.center;
        } else if (val == 'right') {
          align = TextAlign.right;
        } else if (val == 'both' || val == 'justify') {
          align = TextAlign.justify;
        }
      }
    }

    final List<DocxRun> runs = [];

    for (final child in pElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'r') {
        final run = _parseRun(child);
        if (run.text.isNotEmpty) {
          runs.add(run);
        }
      } else if (child.name.local == 'hyperlink') {
        for (final r in child.findElements('w:r')) {
          final run = _parseRun(r, overrideColor: const Color(0xFF2563EB), isUnderline: true);
          if (run.text.isNotEmpty) {
            runs.add(run);
          }
        }
      }
    }

    return DocxParagraph(
      runs: runs,
      headingLevel: heading,
      isBullet: isBullet,
      alignment: align,
    );
  }

  static DocxRun _parseRun(
    xml.XmlElement rElement, {
    Color? overrideColor,
    bool? isUnderline,
  }) {
    final rPr = rElement.findElements('w:rPr').firstOrNull;

    bool bold = false;
    bool italic = false;
    bool underline = isUnderline ?? false;
    bool strike = false;
    Color? color = overrideColor;
    double? fontSize;

    if (rPr != null) {
      if (rPr.findElements('w:b').isNotEmpty) {
        final b = rPr.findElements('w:b').first;
        final val = b.getAttribute('w:val');
        bold = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:i').isNotEmpty) {
        final i = rPr.findElements('w:i').first;
        final val = i.getAttribute('w:val');
        italic = (val == null || val == '1' || val == 'true');
      }
      if (rPr.findElements('w:u').isNotEmpty) {
        final u = rPr.findElements('w:u').first;
        final val = u.getAttribute('w:val');
        underline = (val == null || val != 'none');
      }
      if (rPr.findElements('w:strike').isNotEmpty) {
        strike = true;
      }

      // Text Color
      final colorElem = rPr.findElements('w:color').firstOrNull;
      if (colorElem != null && overrideColor == null) {
        final hex = colorElem.getAttribute('w:val');
        if (hex != null && hex.length == 6) {
          final intVal = int.tryParse(hex, radix: 16);
          if (intVal != null && intVal != 0x000000) {
            color = Color(0xFF000000 | intVal);
          }
        }
      }

      // Font Size in half-points (e.g. 24 = 12pt)
      final szElem = rPr.findElements('w:sz').firstOrNull;
      if (szElem != null) {
        final halfPts = double.tryParse(szElem.getAttribute('w:val') ?? '');
        if (halfPts != null && halfPts > 0) {
          fontSize = halfPts / 2.0;
        }
      }
    }

    final textBuffer = StringBuffer();
    for (final child in rElement.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 't') {
        textBuffer.write(child.innerText);
      } else if (child.name.local == 'tab') {
        textBuffer.write('    ');
      } else if (child.name.local == 'br') {
        textBuffer.write('\n');
      }
    }

    return DocxRun(
      text: textBuffer.toString(),
      isBold: bold,
      isItalic: italic,
      isUnderline: underline,
      isStrike: strike,
      color: color,
      fontSize: fontSize,
    );
  }

  static DocxTable _parseTable(xml.XmlElement tblElement) {
    final List<DocxTableRow> rows = [];

    for (final tr in tblElement.findElements('w:tr')) {
      final List<DocxTableCell> cells = [];
      for (final tc in tr.findElements('w:tc')) {
        final List<DocxParagraph> cellParagraphs = [];
        for (final p in tc.findElements('w:p')) {
          cellParagraphs.add(_parseParagraph(p));
        }

        Color? cellBg;
        final tcPr = tc.findElements('w:tcPr').firstOrNull;
        if (tcPr != null) {
          final shd = tcPr.findElements('w:shd').firstOrNull;
          if (shd != null) {
            final hex = shd.getAttribute('w:fill');
            if (hex != null && hex.length == 6 && hex.toLowerCase() != 'auto') {
              final intVal = int.tryParse(hex, radix: 16);
              if (intVal != null) {
                cellBg = Color(0xFF000000 | intVal);
              }
            }
          }
        }

        cells.add(DocxTableCell(paragraphs: cellParagraphs, backgroundColor: cellBg));
      }
      rows.add(DocxTableRow(cells: cells));
    }

    return DocxTable(rows: rows);
  }
}
