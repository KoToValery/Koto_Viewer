import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/pdf_form_models.dart';
import '../services/pdf_form_service.dart';

class PdfFormFillSheet extends StatefulWidget {
  final String filePath;
  final List<PdfFormFieldModel> initialFields;
  final VoidCallback onSaved;

  const PdfFormFillSheet({
    super.key,
    required this.filePath,
    required this.initialFields,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required String filePath,
    required List<PdfFormFieldModel> initialFields,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PdfFormFillSheet(
        filePath: filePath,
        initialFields: initialFields,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<PdfFormFillSheet> createState() => _PdfFormFillSheetState();
}

class _PdfFormFillSheetState extends State<PdfFormFillSheet> {
  late List<PdfFormFieldModel> _fields;
  final Map<String, TextEditingController> _textControllers = {};
  bool _flattenOnSave = false;
  bool _isSaving = false;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _fields = widget.initialFields.map((f) => f.copyWith()).toList();
    for (final field in _fields) {
      if (field.type == PdfFieldType.text) {
        _textControllers[field.name] = TextEditingController(
          text: field.value?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncValuesFromControllers() {
    for (final field in _fields) {
      if (field.type == PdfFieldType.text && _textControllers.containsKey(field.name)) {
        field.value = _textControllers[field.name]!.text;
      }
    }
  }

  Future<void> _handleSave({bool saveAsNewFile = false}) async {
    _syncValuesFromControllers();
    setState(() => _isSaving = true);

    try {
      String? targetPath;
      if (saveAsNewFile) {
        final originalExt = widget.filePath.split('.').last;
        final baseName = widget.filePath.split(Platform.pathSeparator).last.replaceAll('.$originalExt', '');
        final suggestedName = '${baseName}_filled.$originalExt';

        targetPath = await FilePicker.platform.saveFile(
          dialogTitle: context.l10n.pdfFormSaveAsCopy,
          fileName: suggestedName,
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (targetPath == null) {
          // User cancelled file picker
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

      await PdfFormService.saveFormValues(
        sourcePath: widget.filePath,
        fields: _fields,
        targetPath: targetPath,
        flatten: _flattenOnSave,
      );

      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pdfFormSaved),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    final filteredFields = _fields.where((f) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return f.displayName.toLowerCase().contains(q) || f.name.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_note, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.pdfFormFilling,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.pdfFormFieldsCount(_fields.length),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search filter if more than 5 fields
            if (_fields.length > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.search,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val.trim()),
                ),
              ),

            const Divider(height: 16),

            // Form fields list
            Expanded(
              child: filteredFields.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.pdfNoFormFields,
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filteredFields.length,
                      itemBuilder: (context, index) {
                        final field = filteredFields[index];
                        return _buildFieldWidget(field, theme);
                      },
                    ),
            ),

            const Divider(height: 1),

            // Flatten Switcher & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flatten option
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _flattenOnSave = !_flattenOnSave),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _flattenOnSave,
                            onChanged: (val) => setState(() => _flattenOnSave = val ?? false),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.pdfFormFlatten,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  l10n.pdfFormFlattenTooltip,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action buttons
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleSave(saveAsNewFile: true),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(l10n.pdfFormSaveAsCopy, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleSave(saveAsNewFile: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(l10n.pdfFormSaveOverwrite, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldWidget(PdfFormFieldModel field, ThemeData theme) {
    switch (field.type) {
      case PdfFieldType.text:
        final controller = _textControllers[field.name];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      field.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  if (field.readOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Read-only', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: controller,
                readOnly: field.readOnly,
                maxLines: field.isMultiline ? 3 : 1,
                decoration: InputDecoration(
                  hintText: field.tooltip ?? field.name,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        );

      case PdfFieldType.checkbox:
        final isChecked = field.value == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            title: Text(field.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            subtitle: field.tooltip != null && field.tooltip != field.displayName ? Text(field.tooltip!) : null,
            value: isChecked,
            contentPadding: EdgeInsets.zero,
            enabled: !field.readOnly,
            onChanged: (val) {
              setState(() {
                field.value = val;
              });
            },
          ),
        );

      case PdfFieldType.radio:
      case PdfFieldType.combobox:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: field.options.contains(field.value?.toString()) ? field.value?.toString() : null,
                items: field.options
                    .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: field.readOnly
                    ? null
                    : (val) {
                        setState(() {
                          field.value = val;
                        });
                      },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        );

      case PdfFieldType.signature:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.primary.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                Icon(Icons.draw, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      Text(
                        'Signature field (Page ${field.pageIndex + 1})',
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
