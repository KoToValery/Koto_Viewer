import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

Future<String?> showArchitectAxisValueDialog({
  required BuildContext context,
  required String title,
  required String label,
  required String value,
  bool numeric = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AxisValueDialog(
    title: title,
    label: label,
    value: value,
    numeric: numeric,
  ),
);

class _AxisValueDialog extends StatefulWidget {
  final String title, label, value;
  final bool numeric;
  const _AxisValueDialog({
    required this.title,
    required this.label,
    required this.value,
    required this.numeric,
  });

  @override
  State<_AxisValueDialog> createState() => _AxisValueDialogState();
}

class _AxisValueDialogState extends State<_AxisValueDialog> {
  late final controller = TextEditingController(text: widget.value);
  bool get valid =>
      controller.text.trim().isNotEmpty &&
      (!widget.numeric ||
          double.tryParse(controller.text.replaceAll(',', '.'))?.isFinite ==
              true);

  void save() {
    if (valid) Navigator.pop(context, controller.text.trim());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('architect-axis-value'),
      controller: controller,
      autofocus: true,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        key: const ValueKey('architect-axis-value-save'),
        onPressed: valid ? save : null,
        child: Text(context.l10n.save),
      ),
    ],
  );
}
