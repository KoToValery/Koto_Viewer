import 'package:flutter/material.dart';
import '../../bim_editing/properties/bim_distance_unit.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';

export '../../bim_editing/widgets/bim_numeric_keypad.dart';

typedef ArchitectNumericKeypad = BimNumericKeypad;

int architectNumericDecimals([BimDistanceUnit? unit]) =>
    unit == BimDistanceUnit.meters ? 4 : 3;

String formatArchitectNumericValue(double value, {int decimals = 3}) =>
    decimals == 0
    ? value.round().toString()
    : BimDistanceUnit.trimZeros(value.toStringAsFixed(6));

/// Opens the app's numeric keypad dialog and writes the chosen value into
/// [controller] without invoking the platform soft keyboard.
Future<void> openArchitectNumericKeypad({
  required BuildContext context,
  required TextEditingController controller,
  required String title,
  String? unitLabel,
  int decimals = 3,
  bool allowNegative = false,
  double? min,
  double? max,
  String? Function(double)? validate,
  ValueChanged<String>? onApplied,
}) async {
  final result = await BimNumericKeypad.showInputDialog(
    context,
    title: title,
    initialText: controller.text,
    unitLabel: unitLabel,
    decimals: decimals,
    allowNegative: allowNegative,
    min: min,
    max: max,
    validate: validate,
  );
  if (!context.mounted || result == null) return;
  final text = formatArchitectNumericValue(result, decimals: decimals);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  onApplied?.call(text);
}

/// Numeric [TextFormField] that suppresses the platform keyboard and opens
/// [BimNumericKeypad.showInputDialog] when tapped.
class ArchitectNumericFormField extends StatefulWidget {
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? initialValue;
  final String title;
  final String? unitLabel;
  final int decimals;
  final bool allowNegative;
  final double? min;
  final double? max;
  final String? Function(double)? validate;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final InputDecoration? decoration;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onFieldSubmitted;

  const ArchitectNumericFormField({
    super.key,
    this.fieldKey,
    this.controller,
    this.initialValue,
    required this.title,
    this.unitLabel,
    this.decimals = 3,
    this.allowNegative = false,
    this.min,
    this.max,
    this.validate,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.decoration,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onFieldSubmitted,
  });

  @override
  State<ArchitectNumericFormField> createState() =>
      _ArchitectNumericFormFieldState();
}

class _ArchitectNumericFormFieldState extends State<ArchitectNumericFormField> {
  TextEditingController? _ownedController;
  final _focusNode = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant ArchitectNumericFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    } else if (widget.controller != null && oldWidget.controller == null) {
      _ownedController?.dispose();
      _ownedController = null;
    } else if (widget.controller == null &&
        oldWidget.initialValue != widget.initialValue &&
        !_focusNode.hasFocus) {
      final wanted = widget.initialValue ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusNode.hasFocus || _controller.text == wanted) {
          return;
        }
        final currentNum = double.tryParse(
          _controller.text.trim().replaceAll(',', '.'),
        );
        final wantedNum = double.tryParse(wanted.trim().replaceAll(',', '.'));
        if (currentNum != null &&
            wantedNum != null &&
            (currentNum - wantedNum).abs() < 1e-9) {
          return;
        }
        _controller.value = TextEditingValue(
          text: wanted,
          selection: TextSelection.collapsed(offset: wanted.length),
        );
      });
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _controller,
    focusNode: _focusNode,
    readOnly: widget.readOnly,
    enabled: widget.enabled,
    autofocus: widget.autofocus,
    keyboardType: TextInputType.none,
    textAlign: widget.textAlign,
    textInputAction: widget.textInputAction,
    autovalidateMode: widget.autovalidateMode,
    decoration: widget.decoration,
    validator: widget.validator,
    onChanged: widget.onChanged,
    onSaved: widget.onSaved,
    onFieldSubmitted: widget.onFieldSubmitted,
    onTap: widget.readOnly || !widget.enabled
        ? null
        : () => openArchitectNumericKeypad(
            context: context,
            controller: _controller,
            title: widget.title,
            unitLabel: widget.unitLabel,
            decimals: widget.decimals,
            allowNegative: widget.allowNegative,
            min: widget.min,
            max: widget.max,
            validate: widget.validate,
            onApplied: widget.onChanged,
          ),
  );
}
