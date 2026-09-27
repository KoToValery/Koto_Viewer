import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pdf_form_models.dart';

class PdfFormService {
  /// Quick check if the PDF contains any AcroForm fields.
  static Future<bool> hasFormFields(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final count = doc.form.fields.count;
      doc.dispose();
      return count > 0;
    } catch (e) {
      debugPrint('PdfFormService.hasFormFields error: $e');
      return false;
    }
  }

  /// Extracts all editable AcroForm fields from the PDF.
  static Future<List<PdfFormFieldModel>> extractFormFields(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return [];
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final fields = <PdfFormFieldModel>[];

      for (int i = 0; i < doc.form.fields.count; i++) {
        final field = doc.form.fields[i];
        final name = field.name ?? 'field_$i';
        final tooltip = field.tooltip.isNotEmpty ? field.tooltip : null;
        final readOnly = field.readOnly;
        int pageIndex = 0;
        try {
          if (field.page != null) {
            final idx = doc.pages.indexOf(field.page!);
            if (idx >= 0) pageIndex = idx;
          }
        } catch (_) {}

        if (field is PdfTextBoxField) {
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.text,
            pageIndex: pageIndex,
            readOnly: readOnly,
            isMultiline: field.multiline,
            value: field.text,
          ));
        } else if (field is PdfCheckBoxField) {
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.checkbox,
            pageIndex: pageIndex,
            readOnly: readOnly,
            value: field.isChecked,
          ));
        } else if (field is PdfRadioButtonListField) {
          final options = <String>[];
          for (int j = 0; j < field.items.count; j++) {
            final item = field.items[j];
            options.add(item.value);
          }
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.radio,
            pageIndex: pageIndex,
            readOnly: readOnly,
            options: options,
            value: field.selectedValue.isNotEmpty ? field.selectedValue : (options.isNotEmpty ? options.first : null),
          ));
        } else if (field is PdfComboBoxField) {
          final options = <String>[];
          for (int j = 0; j < field.items.count; j++) {
            final item = field.items[j];
            options.add(item.text);
          }
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.combobox,
            pageIndex: pageIndex,
            readOnly: readOnly,
            options: options,
            value: field.selectedValue.isNotEmpty ? field.selectedValue : (options.isNotEmpty ? options.first : null),
          ));
        } else if (field is PdfListBoxField) {
          final options = <String>[];
          for (int j = 0; j < field.items.count; j++) {
            final item = field.items[j];
            options.add(item.text);
          }
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.listbox,
            pageIndex: pageIndex,
            readOnly: readOnly,
            options: options,
            value: field.selectedValues,
          ));
        } else if (field is PdfSignatureField) {
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip ?? 'Signature Field',
            type: PdfFieldType.signature,
            pageIndex: pageIndex,
            readOnly: true,
            value: 'Signature',
          ));
        } else {
          fields.add(PdfFormFieldModel(
            name: name,
            tooltip: tooltip,
            type: PdfFieldType.other,
            pageIndex: pageIndex,
            readOnly: readOnly,
          ));
        }
      }

      doc.dispose();
      return fields;
    } catch (e, stack) {
      debugPrint('PdfFormService.extractFormFields error: $e\n$stack');
      return [];
    }
  }

  /// Saves updated field values back to the document.
  /// If [flatten] is true, fields are converted into permanent content.
  static Future<String> saveFormValues({
    required String sourcePath,
    required List<PdfFormFieldModel> fields,
    String? targetPath,
    bool flatten = false,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('PDF file not found', sourcePath);
    }
    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);

    final fieldMap = {for (final f in fields) f.name: f};

    for (int i = 0; i < doc.form.fields.count; i++) {
      final field = doc.form.fields[i];
      final name = field.name ?? 'field_$i';
      final model = fieldMap[name];
      if (model == null || model.readOnly) continue;

      try {
        if (field is PdfTextBoxField) {
          field.text = model.value?.toString() ?? '';
        } else if (field is PdfCheckBoxField) {
          field.isChecked = model.value == true;
        } else if (field is PdfRadioButtonListField) {
          if (model.value != null && model.value.toString().isNotEmpty) {
            field.selectedValue = model.value.toString();
          }
        } else if (field is PdfComboBoxField) {
          if (model.value != null && model.value.toString().isNotEmpty) {
            field.selectedValue = model.value.toString();
          }
        } else if (field is PdfListBoxField) {
          if (model.value is List) {
            field.selectedValues = List<String>.from(model.value as List);
          }
        }
      } catch (e) {
        debugPrint('Error updating field $name: $e');
      }
    }

    if (flatten) {
      try {
        doc.form.flattenAllFields();
      } catch (e) {
        debugPrint('Error flattening form fields: $e');
      }
    }

    final outBytes = doc.saveSync();
    doc.dispose();

    final destination = targetPath ?? sourcePath;
    final outFile = File(destination);
    await outFile.writeAsBytes(outBytes, flush: true);
    return destination;
  }
}
