import 'package:flutter/material.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';

class BimElementOffsetOptions {
  final double distance;
  final bool copy;
  const BimElementOffsetOptions(this.distance, this.copy);
}

Future<BimElementOffsetOptions?> showBimElementOffsetDialog(
  BuildContext context, {
  required double unitToMeters,
  required String unitSymbol,
}) => showDialog<BimElementOffsetOptions>(
  context: context,
  builder: (_) =>
      _ElementOffsetDialog(unitToMeters: unitToMeters, unitSymbol: unitSymbol),
);

class _ElementOffsetDialog extends StatefulWidget {
  final double unitToMeters;
  final String unitSymbol;
  const _ElementOffsetDialog({
    required this.unitToMeters,
    required this.unitSymbol,
  });
  @override
  State<_ElementOffsetDialog> createState() => _ElementOffsetDialogState();
}

class _ElementOffsetDialogState extends State<_ElementOffsetDialog> {
  final controller = TextEditingController();
  bool copy = true;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = const BimNumericRule().parse(controller.text);
    final metres = value == null ? null : value * widget.unitToMeters;
    final valid = metres != null && metres.isFinite && metres > 0;
    void submit() {
      if (valid) {
        Navigator.of(context).pop(BimElementOffsetOptions(metres, copy));
      }
    }

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 320),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: Row(
        children: [
          Expanded(child: Text(l.offsetAction)),
          Tooltip(
            message: l.bimOffsetHelp,
            child: const Icon(Icons.help_outline, size: 20),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('architect-offset-distance'),
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l.bimOffsetDistance,
                suffixText: widget.unitSymbol,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => submit(),
            ),
            CheckboxListTile(
              key: const ValueKey('architect-offset-copy'),
              value: copy,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.bimOffsetCopy),
              onChanged: (v) => setState(() => copy = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const ValueKey('architect-offset-start'),
          onPressed: valid ? submit : null,
          child: Text(l.offsetAction),
        ),
      ],
    );
  }
}

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
    final value = const BimNumericRule().parse(controller.text);
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
