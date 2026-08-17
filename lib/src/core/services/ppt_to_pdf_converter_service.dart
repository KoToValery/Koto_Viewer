import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/pptx_viewer/models/pptx_models.dart';
import '../../features/pptx_viewer/parser/ppt_parser.dart';
import '../../features/pptx_viewer/parser/pptx_parser.dart';

/// Exception thrown when PPT/PPTX to PDF conversion fails.
class PptConversionException implements Exception {
  final String message;
  final dynamic cause;

  const PptConversionException(this.message, {this.cause});

  @override
  String toString() => cause != null ? '$message ($cause)' : message;
}

/// Service to seamlessly convert PowerPoint presentations (.ppt / .pptx) to high-fidelity Landscape PDF documents.
class PptToPdfConverterService {
  static const String _cacheFolder = 'ppt_pdf_cache';

  /// Converts a `.pptx` or `.ppt` file to a cached Landscape PDF file and returns its absolute path.
  /// Reuses cached PDF if the source file has not changed.
  static Future<String> convertToPdf(
    String pptFilePath, {
    bool forceReconvert = false,
  }) async {
    final pptFile = File(pptFilePath);
    if (!await pptFile.exists()) {
      throw PptConversionException('Presentation file does not exist: $pptFilePath');
    }

    final stat = await pptFile.stat();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final fileName = pptFilePath.split(Platform.pathSeparator).last;
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    final cachedFileName = '${baseName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_v1.pdf';
    final targetPdfPath = '${cacheDir.path}${Platform.pathSeparator}$cachedFileName';
    final targetPdfFile = File(targetPdfPath);

    if (!forceReconvert &&
        await targetPdfFile.exists() &&
        await targetPdfFile.length() > 200) {
      debugPrint('PptToPdfConverterService: Reusing cached presentation PDF -> $targetPdfPath');
      return targetPdfPath;
    }

    // Read bytes and parse presentation structure
    final Uint8List bytes = await pptFile.readAsBytes();
    final lower = pptFilePath.toLowerCase();
    PptxPresentation presentation;

    try {
      if (lower.endsWith('.pptx') ||
          lower.endsWith('.ppsx') ||
          (bytes.length >= 4 &&
              bytes[0] == 0x50 &&
              bytes[1] == 0x4B &&
              bytes[2] == 0x03 &&
              bytes[3] == 0x04)) {
        presentation = PptxParser.parse(bytes);
      } else {
        presentation = PptParser.parse(bytes);
      }
    } catch (e) {
      try {
        presentation = PptParser.parse(bytes);
      } catch (inner) {
        throw PptConversionException('Failed to parse PowerPoint presentation: $e', cause: inner);
      }
    }

    // Generate Landscape PDF
    final Uint8List pdfBytes = await generatePdfFromPresentation(presentation, title: baseName);

    await targetPdfFile.writeAsBytes(pdfBytes, flush: true);
    debugPrint('PptToPdfConverterService: Generated Presentation PDF -> $targetPdfPath (${pdfBytes.length} bytes)');
    return targetPdfPath;
  }

  /// Generates a Landscape PDF byte array from a parsed [PptxPresentation].
  static Future<Uint8List> generatePdfFromPresentation(
    PptxPresentation presentation, {
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
      theme = pw.ThemeData.base();
    }

    final pdf = pw.Document(theme: theme);
    final totalSlides = presentation.slideCount;

    if (totalSlides == 0) {
      // Empty presentation fallback
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Center(
              child: pw.Text(
                'Empty Presentation',
                style: const pw.TextStyle(fontSize: 20, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );
      return await pdf.save();
    }

    for (int i = 0; i < totalSlides; i++) {
      final slide = presentation.slides[i];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Slide Header / Title Bar
                  if (slide.title != null && slide.title!.isNotEmpty) ...[
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 4,
                          height: 24,
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFD24726), // PPT Accent Coral
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            slide.title!,
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColors.grey200, thickness: 1),
                    pw.SizedBox(height: 14),
                  ] else ...[
                    pw.SizedBox(height: 10),
                  ],

                  // Slide Content Area (Shapes, Text, Tables)
                  pw.Expanded(
                    child: pw.ListView(
                      children: [
                        for (final shape in slide.shapes) ...[
                          for (final para in shape.paragraphs) ...[
                            _buildSlideParagraph(para),
                          ],
                          pw.SizedBox(height: 8),
                        ],
                        for (final table in slide.tables) ...[
                          _buildSlideTable(table),
                          pw.SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),

                  // Slide Footer Strip
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (title != null && title.isNotEmpty)
                        pw.Text(
                          title,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500,
                          ),
                        )
                      else
                        pw.SizedBox(),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(10),
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        child: pw.Text(
                          'Slide ${slide.slideNumber} / $totalSlides',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  static pw.Widget _buildSlideParagraph(PptxParagraph paragraph) {
    final spans = paragraph.runs.map((run) {
      PdfColor? color;
      if (run.color != null) {
        color = PdfColor.fromInt(run.color!.toARGB32());
      }

      return pw.TextSpan(
        text: run.text,
        style: pw.TextStyle(
          fontSize: (run.fontSize ?? 13.0).clamp(9.0, 24.0),
          fontWeight: run.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: run.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
          decoration: run.isUnderline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          color: color ?? PdfColors.blueGrey800,
        ),
      );
    }).toList();

    final leftIndent = paragraph.bulletLevel * 18.0 + (paragraph.isBullet ? 14.0 : 0.0);

    if (paragraph.isBullet) {
      return pw.Padding(
        padding: pw.EdgeInsets.only(left: leftIndent, bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 5, right: 8),
              width: 5,
              height: 5,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFD24726),
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
      padding: pw.EdgeInsets.only(left: leftIndent, bottom: 6),
      child: pw.RichText(
        textAlign: _convertTextAlign(paragraph.alignment),
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  static pw.Widget _buildSlideTable(PptxTable table) {
    if (table.rows.isEmpty) return pw.SizedBox();

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
        children: table.rows.map((row) {
          return pw.TableRow(
            children: row.cells.map((cell) {
              PdfColor? bg;
              if (cell.backgroundColor != null) {
                bg = PdfColor.fromInt(cell.backgroundColor!.toARGB32());
              }

              return pw.Container(
                color: bg,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: cell.paragraphs.map(_buildSlideParagraph).toList(),
                ),
              );
            }).toList(),
          );
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

  /// Clears temporary converted presentation PDF files.
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('PptToPdfConverterService: Error clearing cache: $e');
    }
  }
}
