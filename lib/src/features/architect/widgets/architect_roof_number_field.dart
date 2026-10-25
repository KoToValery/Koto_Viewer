import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

String roofNumber(double value, {int precision = 9}) =>
    value.toStringAsFixed(precision).replaceFirst(RegExp(r'\.?0+$'), '');
double? roofParseNumber(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

/// Exact numeric input, including values finer than a slider step.
class ArchitectRoofNumberField extends StatefulWidget {
  final double value, min, max;
  final String label, unit;
  final ValueChanged<double> onChanged;
  final bool pitch;
  final String? Function(double)? validate;
  final String? invalidMessage;
  const ArchitectRoofNumberField({
    super.key,
    required this.value,
    required this.label,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.pitch = false,
    this.validate,
    this.invalidMessage,
  });
  @override
  State<ArchitectRoofNumberField> createState() => _NumberState();
}

class _NumberState extends State<ArchitectRoofNumberField> {
  late final text = TextEditingController(text: roofNumber(widget.value));
  bool percent = false;
  double last = 0;
  double _shown(double value) =>
      percent ? math.tan(value * math.pi / 180) * 100 : value;
  double? _value(String input) {
    final value = roofParseNumber(input);
    return value == null
        ? null
        : percent
        ? math.atan(value / 100) * 180 / math.pi
        : value;
  }

  @override
  void initState() {
    super.initState();
    last = widget.value;
  }

  @override
  void didUpdateWidget(covariant ArchitectRoofNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        (widget.value - last).abs() > math.max(1, widget.value.abs()) * 1e-10;
    last = widget.value;
    if (changed) {
      final wanted = roofNumber(_shown(widget.value));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            roofNumber(_shown(widget.value)) == wanted &&
            text.text != wanted) {
          text.value = TextEditingValue(
            text: wanted,
            selection: TextSelection.collapsed(offset: wanted.length),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: TextFormField(
      controller: text,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: widget.min < 0,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.pitch ? null : widget.unit,
        suffixIcon: widget.pitch
            ? DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: percent,
                  items: const [
                    DropdownMenuItem(value: false, child: Text('°')),
                    DropdownMenuItem(value: true, child: Text('%')),
                  ],
                  onChanged: (v) {
                    if (v == null || _value(text.text) == null) return;
                    final value = _value(text.text)!;
                    setState(() {
                      percent = v;
                      text.text = roofNumber(_shown(value));
                    });
                  },
                ),
              )
            : null,
        helperText: widget.pitch
            ? percent
                  ? '${roofNumber(widget.value, precision: 2)}°'
                  : '${roofNumber(math.tan(widget.value * math.pi / 180) * 100, precision: 2)}%'
            : null,
      ),
      validator: (s) {
        final value = _value(s ?? '');
        if (value == null || value < widget.min || value > widget.max) {
          return widget.invalidMessage ?? context.l10n.roofUiNumericInvalid;
        }
        return widget.validate?.call(value);
      },
      onChanged: (s) {
        final value = _value(s);
        if (value != null &&
            value >= widget.min &&
            value <= widget.max &&
            widget.validate?.call(value) == null) {
          last = value;
          widget.onChanged(value);
        }
      },
    ),
  );
}

class ArchitectRoofQuickValue {
  final double value;
  final bool applyToGroup;
  const ArchitectRoofQuickValue(this.value, this.applyToGroup);
}

Future<ArchitectRoofQuickValue?> showArchitectRoofNumber(
  BuildContext context, {
  required String label,
  required double value,
  required String unit,
  double min = 0,
  double max = double.infinity,
  bool pitch = false,
  int groupCount = 1,
}) => showDialog<ArchitectRoofQuickValue>(
  context: context,
  builder: (_) => _QuickDialog(
    label: label,
    value: value,
    unit: unit,
    min: min,
    max: max,
    pitch: pitch,
    groupCount: groupCount,
  ),
);

class _QuickDialog extends StatefulWidget {
  final String label, unit;
  final double value, min, max;
  final bool pitch;
  final int groupCount;
  const _QuickDialog({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.pitch,
    required this.groupCount,
  });
  @override
  State<_QuickDialog> createState() => _QuickState();
}

class _QuickState extends State<_QuickDialog> {
  final form = GlobalKey<FormState>();
  late double value = widget.value;
  bool group = false;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.label),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.groupCount > 1)
                DropdownButtonFormField<bool>(
                  initialValue: group,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(l.roofUiOnlyPlane),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(l.roofUiWholeRoof(widget.groupCount)),
                    ),
                  ],
                  onChanged: (v) => setState(() => group = v ?? false),
                ),
              ArchitectRoofNumberField(
                key: const ValueKey('roof-quick-value'),
                value: value,
                label: widget.label,
                unit: widget.unit,
                min: widget.min,
                max: widget.max,
                pitch: widget.pitch,
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, ArchitectRoofQuickValue(value, group));
            }
          },
          child: Text(l.applyAction),
        ),
      ],
    );
  }
}
