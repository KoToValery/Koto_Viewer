import 'package:flutter/material.dart';

/// Heading levels in Word documents.
enum DocxHeadingLevel {
  title,
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  none,
}

/// Abstract base class for content blocks in a DOCX document.
abstract class DocxBlock {
  const DocxBlock();
}

/// Styled text run within a paragraph.
class DocxRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final Color? color;
  final double? fontSize;

  const DocxRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.color,
    this.fontSize,
  });
}

/// Paragraph block with styled runs, heading level, and list status.
class DocxParagraph extends DocxBlock {
  final List<DocxRun> runs;
  final DocxHeadingLevel headingLevel;
  final bool isBullet;
  final TextAlign alignment;

  const DocxParagraph({
    required this.runs,
    this.headingLevel = DocxHeadingLevel.none,
    this.isBullet = false,
    this.alignment = TextAlign.start,
  });

  String get plainText => runs.map((r) => r.text).join();
}

/// Single table cell.
class DocxTableCell {
  final List<DocxParagraph> paragraphs;
  final Color? backgroundColor;

  const DocxTableCell({
    required this.paragraphs,
    this.backgroundColor,
  });

  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}

/// Single table row.
class DocxTableRow {
  final List<DocxTableCell> cells;

  const DocxTableRow({required this.cells});
}

/// Table block consisting of rows and cells.
class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;

  const DocxTable({required this.rows});

  int get rowCount => rows.length;
  int get columnCount => rows.isEmpty ? 0 : rows.first.cells.length;
}

/// Complete parsed Word document representation.
class DocxDocument {
  final List<DocxBlock> blocks;

  const DocxDocument({required this.blocks});

  int get paragraphCount => blocks.whereType<DocxParagraph>().length;
  int get tableCount => blocks.whereType<DocxTable>().length;

  int get headingCount => blocks
      .whereType<DocxParagraph>()
      .where((p) => p.headingLevel != DocxHeadingLevel.none)
      .length;

  int get wordCount {
    int count = 0;
    for (final block in blocks) {
      if (block is DocxParagraph) {
        final text = block.plainText.trim();
        if (text.isNotEmpty) {
          count += text.split(RegExp(r'\s+')).length;
        }
      } else if (block is DocxTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            final text = cell.plainText.trim();
            if (text.isNotEmpty) {
              count += text.split(RegExp(r'\s+')).length;
            }
          }
        }
      }
    }
    return count;
  }
}
