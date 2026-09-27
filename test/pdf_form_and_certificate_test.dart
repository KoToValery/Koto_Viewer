import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/pdf_viewer/models/pdf_form_models.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_certificate_service.dart';
import 'package:kotoview/src/features/pdf_viewer/services/pdf_form_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('PdfFormService creates, extracts and saves form values', () async {
    final doc = PdfDocument();
    final page = doc.pages.add();

    final textBox = PdfTextBoxField(page, 'applicantName', Rect.fromLTWH(50, 50, 200, 25));
    textBox.text = 'John Doe';
    textBox.tooltip = 'Applicant Name';
    doc.form.fields.add(textBox);

    final checkBox = PdfCheckBoxField(page, 'isAgreed', Rect.fromLTWH(50, 90, 20, 20));
    checkBox.isChecked = false;
    checkBox.tooltip = 'Agreement';
    doc.form.fields.add(checkBox);

    final tempFile = File('${Directory.systemTemp.path}/test_form_service.pdf');
    await tempFile.writeAsBytes(doc.saveSync());
    doc.dispose();

    // Check hasFormFields
    final hasFields = await PdfFormService.hasFormFields(tempFile.path);
    expect(hasFields, isTrue);

    // Extract fields
    final fields = await PdfFormService.extractFormFields(tempFile.path);
    expect(fields.length, 2);
    expect(fields[0].name, 'applicantName');
    expect(fields[0].value, 'John Doe');
    expect(fields[0].type, PdfFieldType.text);
    expect(fields[1].name, 'isAgreed');
    expect(fields[1].value, false);
    expect(fields[1].type, PdfFieldType.checkbox);

    // Modify fields
    fields[0].value = 'Alice Smith';
    fields[1].value = true;

    // Save with flatten = false
    await PdfFormService.saveFormValues(
      sourcePath: tempFile.path,
      fields: fields,
      flatten: false,
    );

    // Re-extract to verify changes
    final updatedFields = await PdfFormService.extractFormFields(tempFile.path);
    expect(updatedFields[0].value, 'Alice Smith');
    expect(updatedFields[1].value, true);

    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  test('PdfCertificateService detects signature fields and certificates', () async {
    final doc = PdfDocument();
    final page = doc.pages.add();

    final sigField = PdfSignatureField(page, 'AuthorSignature', bounds: Rect.fromLTWH(50, 150, 200, 50));
    sigField.tooltip = 'Approved by Officer';
    doc.form.fields.add(sigField);

    final tempFile = File('${Directory.systemTemp.path}/test_sig_service.pdf');
    await tempFile.writeAsBytes(doc.saveSync());
    doc.dispose();

    final hasSig = await PdfCertificateService.hasSignatures(tempFile.path);
    expect(hasSig, isTrue);

    final certs = await PdfCertificateService.extractCertificates(tempFile.path);
    expect(certs.isNotEmpty, isTrue);
    expect(certs.first.signerName, 'AuthorSignature');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });
}
