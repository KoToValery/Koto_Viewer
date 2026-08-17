import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/docx_viewer/models/docx_models.dart';
import '../../features/docx_viewer/parser/doc_parser.dart';
import '../../features/docx_viewer/parser/docx_parser.dart';

/// Exception thrown when DOC/DOCX to PDF conversion fails.
class DocConversionException implements Exception {
  final String message;
  final dynamic cause;

  const DocConversionException(this.message, {this.cause});

  @override
  String toString() => cause != null ? '$message ($cause)' : message;
}

/// Service to seamlessly convert Microsoft Word documents (.doc / .docx) to high-fidelity PDF documents.
class DocToPdfConverterService {
  static const String _cacheFolder = 'doc_pdf_cache';

  /// Converts a `.doc` or `.docx` file to a cached PDF file and returns its absolute path.
  /// Reuses cached PDF if the source file has not changed.
  static Future<String> convertToPdf(
    String docFilePath, {
    bool forceReconvert = false,
  }) async {
    final docFile = File(docFilePath);
    if (!await docFile.exists()) {
      throw DocConversionException('Document file does not exist: $docFilePath');
    }

    final stat = await docFile.stat();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final fileName = docFilePath.split(Platform.pathSeparator).last;
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    final cachedFileName = '${baseName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_v3.pdf';
    final targetPdfPath = '${cacheDir.path}${Platform.pathSeparator}$cachedFileName';
    final targetPdfFile = File(targetPdfPath);

    if (!forceReconvert &&
        await targetPdfFile.exists() &&
        await targetPdfFile.length() > 200) {
      debugPrint('DocToPdfConverterService: Reusing cached PDF -> $targetPdfPath');
      return targetPdfPath;
    }

    // Read bytes and parse document structure
    final Uint8List bytes = await docFile.readAsBytes();
    final lower = docFilePath.toLowerCase();
    DocxDocument document;

    try {
      if (lower.endsWith('.docx') ||
          (bytes.length >= 4 &&
              bytes[0] == 0x50 &&
              bytes[1] == 0x4B &&
              bytes[2] == 0x03 &&
              bytes[3] == 0x04)) {
        document = DocxParser.parse(bytes);
      } else {
        document = DocParser.parse(bytes);
      }
    } catch (e) {
      // If docx parser fails, try fallback DocParser
      try {
        document = DocParser.parse(bytes);
      } catch (inner) {
        throw DocConversionException('Failed to parse Word document: $e', cause: inner);
      }
    }

    // Generate PDF
    final Uint8List pdfBytes = await generatePdfFromDocument(document, title: baseName);

    await targetPdfFile.writeAsBytes(pdfBytes, flush: true);
    debugPrint('DocToPdfConverterService: Generated PDF -> $targetPdfPath (${pdfBytes.length} bytes)');
    return targetPdfPath;
  }

  /// Generates a PDF byte array from a parsed [DocxDocument].
  static Future<Uint8List> generatePdfFromDocument(
    DocxDocument document, {
    String? title,
  }) async {
    pw.ThemeData theme;
    try {
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();
      final fontItalic = await PdfGoogleFonts.robotoItalic();
      final fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();

      theme = pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      );
    } catch (_) {
      // Graceful fallback if offline without cached fonts
      theme = pw.ThemeData.base();
    }

    final pdf = pw.Document(theme: theme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        header: (context) {
          if (title != null && title.isNotEmpty && context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                title,
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey600,
                ),
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];

          for (final block in document.blocks) {
            if (block is DocxParagraph) {
              final widget = _buildParagraphWidget(block);
              if (widget != null) widgets.add(widget);
            } else if (block is DocxTable) {
              final widget = _buildTableWidget(block);
              if (widget != null) widgets.add(widget);
            }
          }

          if (widgets.isEmpty) {
            widgets.add(
              pw.Paragraph(
                text: 'Empty document.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget? _buildParagraphWidget(DocxParagraph paragraph) {
    if (paragraph.runs.isEmpty) {
      return pw.SizedBox(height: 8);
    }

    // Heading styles
    if (paragraph.headingLevel != DocxHeadingLevel.none) {
      double fontSize = 14;
      double topMargin = 12;
      double bottomMargin = 6;

      switch (paragraph.headingLevel) {
        case DocxHeadingLevel.title:
          fontSize = 20;
          topMargin = 0;
          bottomMargin = 14;
          break;
        case DocxHeadingLevel.h1:
          fontSize = 16;
          topMargin = 14;
          bottomMargin = 8;
          break;
        case DocxHeadingLevel.h2:
          fontSize = 14;
          topMargin = 12;
          bottomMargin = 6;
          break;
        case DocxHeadingLevel.h3:
        case DocxHeadingLevel.h4:
        case DocxHeadingLevel.h5:
        case DocxHeadingLevel.h6:
          fontSize = 12.5;
          topMargin = 10;
          bottomMargin = 4;
          break;
        case DocxHeadingLevel.none:
          break;
      }

      return pw.Container(
        margin: pw.EdgeInsets.only(top: topMargin, bottom: bottomMargin),
        child: pw.Text(
          paragraph.plainText,
          textAlign: _convertTextAlign(paragraph.alignment),
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      );
    }

    // Bullet item or standard paragraph
    final cleanedRuns = paragraph.runs.map((run) {
      final cleanedText = DocParser.cleanWordText(run.text);
      return DocxRun(
        text: cleanedText,
        isBold: run.isBold,
        isItalic: run.isItalic,
        isUnderline: run.isUnderline,
        isStrike: run.isStrike,
        color: run.color,
        fontSize: run.fontSize,
      );
    }).where((r) => r.text.isNotEmpty).toList();

    if (cleanedRuns.isEmpty) {
      return null;
    }

    final spans = cleanedRuns.map((run) {
      PdfColor? pdfColor;
      if (run.color != null) {
        pdfColor = PdfColor.fromInt(run.color!.toARGB32());
      }

      return pw.TextSpan(
        text: run.text,
        style: pw.TextStyle(
          fontSize: run.fontSize ?? 10.5,
          fontWeight: run.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: run.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          decoration: run.isUnderline
              ? pw.TextDecoration.underline
              : run.isStrike
                  ? pw.TextDecoration.lineThrough
                  : pw.TextDecoration.none,
          color: pdfColor ?? PdfColors.black,
        ),
      );
    }).toList();

    if (paragraph.isBullet) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 14, bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, right: 6),
              width: 4,
              height: 4,
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(
              child: pw.RichText(
                textAlign: _convertTextAlign(paragraph.alignment),
                text: pw.TextSpan(children: spans),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        textAlign: _convertTextAlign(paragraph.alignment),
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  static pw.Widget? _buildTableWidget(DocxTable table) {
    if (table.rows.isEmpty) return null;

    // Calculate maximum columns across all rows to prevent table misalignment
    int maxCols = 0;
    for (final row in table.rows) {
      if (row.cells.length > maxCols) {
        maxCols = row.cells.length;
      }
    }
    if (maxCols == 0) return null;

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: table.rows.map((row) {
          final rowChildren = <pw.Widget>[];

          for (int c = 0; c < maxCols; c++) {
            if (c < row.cells.length) {
              final cell = row.cells[c];
              PdfColor? cellBg;
              if (cell.backgroundColor != null) {
                cellBg = PdfColor.fromInt(cell.backgroundColor!.toARGB32());
              }

              final cellParagraphWidgets = cell.paragraphs
                  .map((p) => _buildParagraphWidget(p))
                  .whereType<pw.Widget>()
                  .toList();

              rowChildren.add(
                pw.Container(
                  color: cellBg,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: cellParagraphWidgets.isNotEmpty
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: cellParagraphWidgets,
                        )
                      : pw.SizedBox(height: 12),
                ),
              );
            } else {
              // Pad with empty cell if row is shorter than maxCols
              rowChildren.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: pw.SizedBox(height: 12),
                ),
              );
            }
          }

          return pw.TableRow(children: rowChildren);
        }).toList(),
      ),
    );
  }

  static pw.TextAlign _convertTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return pw.TextAlign.center;
      case TextAlign.right:
      case TextAlign.end:
        return pw.TextAlign.right;
      case TextAlign.justify:
        return pw.TextAlign.justify;
      case TextAlign.left:
      case TextAlign.start:
      default:
        return pw.TextAlign.left;
    }
  }

  /// Clears temporary converted PDF files.
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('DocToPdfConverterService: Error clearing cache: $e');
    }
  }
}
