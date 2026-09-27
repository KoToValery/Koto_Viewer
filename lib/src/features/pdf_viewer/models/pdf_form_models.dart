enum PdfFieldType {
  text,
  checkbox,
  radio,
  combobox,
  listbox,
  signature,
  other,
}

class PdfFormFieldModel {
  final String name;
  final String? tooltip;
  final PdfFieldType type;
  final int pageIndex;
  final bool readOnly;
  final bool isMultiline;
  final List<String> options;
  dynamic value;
  final dynamic initialValue;

  PdfFormFieldModel({
    required this.name,
    this.tooltip,
    required this.type,
    this.pageIndex = 0,
    this.readOnly = false,
    this.isMultiline = false,
    this.options = const [],
    this.value,
    dynamic initialValue,
  }) : initialValue = initialValue ?? value;

  bool get isModified => value != initialValue;

  String get displayName {
    if (tooltip != null && tooltip!.trim().isNotEmpty) {
      return tooltip!.trim();
    }
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Field';
  }

  PdfFormFieldModel copyWith({
    String? name,
    String? tooltip,
    PdfFieldType? type,
    int? pageIndex,
    bool? readOnly,
    bool? isMultiline,
    List<String>? options,
    dynamic value,
    dynamic initialValue,
  }) {
    return PdfFormFieldModel(
      name: name ?? this.name,
      tooltip: tooltip ?? this.tooltip,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      readOnly: readOnly ?? this.readOnly,
      isMultiline: isMultiline ?? this.isMultiline,
      options: options ?? this.options,
      value: value ?? this.value,
      initialValue: initialValue ?? this.initialValue,
    );
  }
}
