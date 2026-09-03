import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// Styled text run in a presentation slide.
class PptxRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? color;
  final double? fontSize;

  const PptxRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.color,
    this.fontSize,
  });
}

/// Paragraph of text in a slide shape.
class PptxParagraph {
  final List<PptxRun> runs;
  final bool isBullet;
  final int bulletLevel;
  final TextAlign alignment;

  const PptxParagraph({
    required this.runs,
    this.isBullet = false,
    this.bulletLevel = 0,
    this.alignment = TextAlign.start,
  });

  String get plainText => runs.map((r) => r.text).join();
}

/// Text box or shape on a slide.
class PptxShape {
  final String? name;
  final bool isTitle;
  final List<PptxParagraph> paragraphs;

  const PptxShape({
    this.name,
    this.isTitle = false,
    required this.paragraphs,
  });

  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}

/// Embedded image on a slide.
class PptxImage {
  /// Raw bytes of the image (PNG / JPEG / etc.)
  final Uint8List bytes;

  const PptxImage({required this.bytes});
}

/// Table cell in a presentation slide.
class PptxTableCell {
  final List<PptxParagraph> paragraphs;
  final Color? backgroundColor;

  const PptxTableCell({
    required this.paragraphs,
    this.backgroundColor,
  });

  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}

/// Table row in a presentation slide.
class PptxTableRow {
  final List<PptxTableCell> cells;

  const PptxTableRow({required this.cells});
}

/// Table on a slide.
class PptxTable {
  final List<PptxTableRow> rows;

  const PptxTable({required this.rows});

  int get rowCount => rows.length;
  int get colCount => rows.isEmpty ? 0 : rows.first.cells.length;
}

/// Single presentation slide.
class PptxSlide {
  final int slideNumber;
  final String? title;
  final List<PptxShape> shapes;
  final List<PptxTable> tables;
  final List<PptxImage> images;

  const PptxSlide({
    required this.slideNumber,
    this.title,
    required this.shapes,
    this.tables = const [],
    this.images = const [],
  });

  bool get isEmpty =>
      shapes.isEmpty &&
      tables.isEmpty &&
      images.isEmpty &&
      (title == null || title!.isEmpty);
}

/// Complete presentation representation.
class PptxPresentation {
  final List<PptxSlide> slides;

  const PptxPresentation({required this.slides});

  int get slideCount => slides.length;
}
