import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/ppt_to_pdf_converter_service.dart';
import 'package:kotoview/src/features/pptx_viewer/models/pptx_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PptToPdfConverterService Tests', () {
    test('generates valid Landscape PDF from PptxPresentation', () async {
      final presentation = PptxPresentation(
        slides: [
          const PptxSlide(
            slideNumber: 1,
            title: 'KotoView Presentation',
            shapes: [
              PptxShape(
                paragraphs: [
                  PptxParagraph(
                    runs: [
                      PptxRun(text: 'Универсален преглед на документи и чертежи', isBold: true),
                    ],
                  ),
                  PptxParagraph(
                    runs: [
                      PptxRun(text: 'Поддържа PDF, CAD, 3D, DOCX, PPTX, RTF.'),
                    ],
                    isBullet: true,
                  ),
                ],
              ),
            ],
          ),
          const PptxSlide(
            slideNumber: 2,
            title: 'Таблица с формати',
            shapes: [],
            tables: [
              PptxTable(
                rows: [
                  PptxTableRow(
                    cells: [
                      PptxTableCell(
                        paragraphs: [PptxParagraph(runs: [PptxRun(text: 'Категория', isBold: true)])],
                      ),
                      PptxTableCell(
                        paragraphs: [PptxParagraph(runs: [PptxRun(text: 'Разширения', isBold: true)])],
                      ),
                    ],
                  ),
                  PptxTableRow(
                    cells: [
                      PptxTableCell(
                        paragraphs: [PptxParagraph(runs: [PptxRun(text: 'Презентации')])],
                      ),
                      PptxTableCell(
                        paragraphs: [PptxParagraph(runs: [PptxRun(text: '.pptx, .ppt')])],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final Uint8List pdfBytes = await PptToPdfConverterService.generatePdfFromPresentation(
        presentation,
        title: 'KotoView Overview',
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });
  });
}
