import 'dart:typed_data';
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

/// Border line styles in Word documents.
enum DocxLineStyle {
  none,
  single,
  double,
  dashed,
  dotted,
  thick,
  wave,
}

/// Border configuration for a table or cell side.
class DocxBorder {
  final bool hasBorder;
  final Color color;
  final double width;
  final DocxLineStyle style;

  const DocxBorder({
    this.hasBorder = true,
    this.color = const Color(0xFF000000),
    this.width = 1.0,
    this.style = DocxLineStyle.single,
  });

  static const DocxBorder none = DocxBorder(hasBorder: false, width: 0, style: DocxLineStyle.none);

  BorderSide toBorderSide({double zoomScale = 1.0}) {
    if (!hasBorder || width <= 0 || style == DocxLineStyle.none) return BorderSide.none;
    return BorderSide(
      color: color,
      width: (width * zoomScale).clamp(0.5, 6.0),
      style: BorderStyle.solid,
    );
  }
}

/// Table borders (outer and inner grid lines).
class DocxTableBorders {
  final DocxBorder? top;
  final DocxBorder? bottom;
  final DocxBorder? left;
  final DocxBorder? right;
  final DocxBorder? insideH;
  final DocxBorder? insideV;

  const DocxTableBorders({
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.insideH,
    this.insideV,
  });

  bool get hasAnyBorder =>
      (top?.hasBorder ?? false) ||
      (bottom?.hasBorder ?? false) ||
      (left?.hasBorder ?? false) ||
      (right?.hasBorder ?? false) ||
      (insideH?.hasBorder ?? false) ||
      (insideV?.hasBorder ?? false);

  TableBorder toTableBorder({Color defaultColor = const Color(0xFFCBD5E1), double zoomScale = 1.0}) {
    return TableBorder(
      top: top?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      bottom: bottom?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      left: left?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      right: right?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      horizontalInside: insideH?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      verticalInside: insideV?.toBorderSide(zoomScale: zoomScale) ?? BorderSide.none,
      borderRadius: BorderRadius.circular(2),
    );
  }
}

/// Cell-specific border overrides.
class DocxCellBorders {
  final DocxBorder? top;
  final DocxBorder? bottom;
  final DocxBorder? left;
  final DocxBorder? right;

  const DocxCellBorders({
    this.top,
    this.bottom,
    this.left,
    this.right,
  });
}

/// Vector Line or Rectangle drawn on the page canvas (e.g. framing lines).
class DocxDrawingShape {
  final Offset from;
  final Offset to;
  final Color color;
  final double strokeWidth;
  final bool isLine;
  final Rect? rect;
  final Color? fillColor;

  const DocxDrawingShape({
    required this.from,
    required this.to,
    this.color = const Color(0xFF008080), // Teal
    this.strokeWidth = 1.0,
    this.isLine = true,
    this.rect,
    this.fillColor,
  });
}

/// Page geometry and margins configuration.
class DocxPageSettings {
  final double widthPt;
  final double heightPt;
  final bool isLandscape;
  final EdgeInsets margins;
  final String paperName;
  final List<DocxDrawingShape> pageShapes;

  const DocxPageSettings({
    this.widthPt = 595.3, // A4 width: 210mm (~595.3 pt)
    this.heightPt = 841.9, // A4 height: 297mm (~841.9 pt)
    this.isLandscape = false,
    this.margins = const EdgeInsets.symmetric(horizontal: 54, vertical: 54), // ~1 inch / 20mm
    this.paperName = 'A4',
    this.pageShapes = const [],
  });

  /// True aspect ratio (width / height). For A4 portrait = ~0.707.
  double get aspectRatio => widthPt > 0 && heightPt > 0 ? (widthPt / heightPt) : 0.707;

  /// Printable/content width inside margins.
  double get contentWidthPt => (widthPt - margins.horizontal).clamp(100.0, widthPt);

  /// Printable/content height inside margins.
  double get contentHeightPt => (heightPt - margins.vertical).clamp(100.0, heightPt);
}

/// Abstract base class for content blocks in a DOCX document.
abstract class DocxBlock {
  const DocxBlock();
}

/// Image block embedded in the document.
class DocxImageBlock extends DocxBlock {
  final Uint8List imageBytes;
  final double? widthPt;
  final double? heightPt;
  final Alignment alignment;

  const DocxImageBlock({
    required this.imageBytes,
    this.widthPt,
    this.heightPt,
    this.alignment = Alignment.centerLeft,
  });
}

/// Header Box with Company Logo + Text + Divider Rule.
class DocxHeaderBox extends DocxBlock {
  final Uint8List? logoBytes;
  final double? logoWidthPt;
  final double? logoHeightPt;
  final List<String> headerLines;

  const DocxHeaderBox({
    this.logoBytes,
    this.logoWidthPt,
    this.logoHeightPt,
    this.headerLines = const [],
  });
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
  final String? fontFamily;
  final bool isTab;

  const DocxRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.color,
    this.fontSize,
    this.fontFamily,
    this.isTab = false,
  });
}

/// Paragraph block with styled runs, heading level, spacing, and list status.
class DocxParagraph extends DocxBlock {
  final List<DocxRun> runs;
  final DocxHeadingLevel headingLevel;
  final bool isBullet;
  final String? listPrefix;
  final TextAlign alignment;
  final double spaceBefore;
  final double spaceAfter;
  final double? lineSpacing;
  final double indentLeft;
  final double indentRight;
  final double indentFirstLine;
  final List<double> tabPositions;
  final bool isPageBreak;
  final DocxBorder? bottomBorder;
  final DocxImageBlock? imageBlock;
  final DocxHeaderBox? headerBox;

  const DocxParagraph({
    required this.runs,
    this.headingLevel = DocxHeadingLevel.none,
    this.isBullet = false,
    this.listPrefix,
    this.alignment = TextAlign.start,
    this.spaceBefore = 0.0,
    this.spaceAfter = 3.0,
    this.lineSpacing,
    this.indentLeft = 0.0,
    this.indentRight = 0.0,
    this.indentFirstLine = 0.0,
    this.tabPositions = const [],
    this.isPageBreak = false,
    this.bottomBorder,
    this.imageBlock,
    this.headerBox,
  });

  String get plainText => runs.map((r) => r.text).join();
}

/// Single table cell.
class DocxTableCell {
  final List<DocxParagraph> paragraphs;
  final Color? backgroundColor;
  final double? widthPt;
  final int colSpan;
  final int rowSpan;
  final Alignment verticalAlignment;
  final DocxCellBorders? borders;
  final EdgeInsets? padding;

  const DocxTableCell({
    required this.paragraphs,
    this.backgroundColor,
    this.widthPt,
    this.colSpan = 1,
    this.rowSpan = 1,
    this.verticalAlignment = Alignment.topLeft,
    this.borders,
    this.padding,
  });

  String get plainText => paragraphs.map((p) => p.plainText).join('\n');
}

/// Single table row.
class DocxTableRow {
  final List<DocxTableCell> cells;
  final double? heightPt;
  final bool isHeader;

  const DocxTableRow({
    required this.cells,
    this.heightPt,
    this.isHeader = false,
  });
}

/// Table block consisting of rows and cells.
class DocxTable extends DocxBlock {
  final List<DocxTableRow> rows;
  final List<double> columnWidths;
  final DocxTableBorders? borders;
  final double? totalWidthPt;
  final TextAlign alignment;

  const DocxTable({
    required this.rows,
    this.columnWidths = const [],
    this.borders,
    this.totalWidthPt,
    this.alignment = TextAlign.start,
  });

  int get rowCount => rows.length;
  int get columnCount =>
      columnWidths.isNotEmpty
          ? columnWidths.length
          : (rows.isEmpty ? 0 : rows.first.cells.length);

  bool get hasAnyBorder {
    if (borders != null && borders!.hasAnyBorder) return true;
    for (final r in rows) {
      for (final c in r.cells) {
        if (c.borders != null) {
          if ((c.borders!.top?.hasBorder ?? false) ||
              (c.borders!.bottom?.hasBorder ?? false) ||
              (c.borders!.left?.hasBorder ?? false) ||
              (c.borders!.right?.hasBorder ?? false)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}

/// A parsed document page containing its specific blocks and settings.
class DocxPage {
  final int pageNumber;
  final DocxPageSettings settings;
  final List<DocxBlock> blocks;

  const DocxPage({
    required this.pageNumber,
    required this.settings,
    required this.blocks,
  });
}

/// Complete parsed Word document representation.
class DocxDocument {
  final List<DocxBlock> blocks;
  final DocxPageSettings pageSettings;
  final List<DocxPage> pages;
  final Map<String, Uint8List> images;

  const DocxDocument({
    required this.blocks,
    this.pageSettings = const DocxPageSettings(),
    this.pages = const [],
    this.images = const {},
  });

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
