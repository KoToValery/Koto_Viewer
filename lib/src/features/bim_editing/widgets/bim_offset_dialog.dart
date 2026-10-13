import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Only the distance is entered here; the canvas determines the direction.
Future<double?> showBimOffsetDialog(
  BuildContext context, {
  required double unitToMeters,
  required String unitSymbol,
  Key inputKey = const ValueKey('bim-offset-distance'),
}) => showDialog<double>(
  context: context,
  builder: (_) => _BimOffsetDialog(
    unitToMeters: unitToMeters,
    unitSymbol: unitSymbol,
    inputKey: inputKey,
  ),
);

class _BimOffsetDialog extends StatefulWidget {
  final double unitToMeters;
  final String unitSymbol;
  final Key inputKey;
  const _BimOffsetDialog({
    required this.unitToMeters,
    required this.unitSymbol,
    required this.inputKey,
  });

  @override
  State<_BimOffsetDialog> createState() => _BimOffsetDialogState();
}

class _BimOffsetDialogState extends State<_BimOffsetDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    final valid = value != null && value.isFinite && value > 0;
    void submit() {
      if (valid) {
        Navigator.of(context).pop(value * widget.unitToMeters);
      }
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      constraints: const BoxConstraints(maxWidth: 280),
      content: TextField(
        key: widget.inputKey,
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          labelText: context.l10n.offsetAction,
          suffixText: widget.unitSymbol,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        Tooltip(
          message: context.l10n.specifyDirectionByDrag,
          child: TextButton(
            onPressed: valid ? submit : null,
            child: Text(context.l10n.offsetAction),
          ),
        ),
      ],
    );
  }
}
