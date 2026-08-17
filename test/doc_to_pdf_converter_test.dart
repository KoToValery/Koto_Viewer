import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/services/doc_to_pdf_converter_service.dart';
import 'package:kotoview/src/features/docx_viewer/models/docx_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocToPdfConverterService Tests', () {
    test('generatePdfFromDocument creates valid PDF bytes', () async {
      final docx = DocxDocument(
        blocks: [
          const DocxParagraph(
            runs: [DocxRun(text: 'Справка за проект (Project Report)', isBold: true)],
            headingLevel: DocxHeadingLevel.title,
          ),
          const DocxParagraph(
            runs: [
              DocxRun(text: 'Това е официален документ, генериран директно в PDF формат.'),
            ],
          ),
          const DocxTable(
            rows: [
              DocxTableRow(
                cells: [
                  DocxTableCell(paragraphs: [
                    DocxParagraph(runs: [DocxRun(text: '№', isBold: true)])
                  ]),
                  DocxTableCell(paragraphs: [
                    DocxParagraph(runs: [DocxRun(text: 'Наименование', isBold: true)])
                  ]),
                ],
              ),
              DocxTableRow(
                cells: [
                  DocxTableCell(paragraphs: [
                    DocxParagraph(runs: [DocxRun(text: '1')])
                  ]),
                  DocxTableCell(paragraphs: [
                    DocxParagraph(runs: [DocxRun(text: 'Архитектурен чертеж')])
                  ]),
                ],
              ),
            ],
          ),
        ],
      );

      final pdfBytes = await DocToPdfConverterService.generatePdfFromDocument(
        docx,
        title: 'Project Report',
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });
  });
}
