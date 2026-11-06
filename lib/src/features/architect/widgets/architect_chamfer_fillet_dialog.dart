// === SECTION: ARCHITECT CHAMFER & FILLET DIALOG ===

import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../bim_editing/properties/bim_numeric_rule.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../../../core/l10n/l10n_extensions.dart';

class ArchitectChamferFilletOptions {
  final bool isFillet;
  final double value; // distance or radius
  final bool applyToAll;

  const ArchitectChamferFilletOptions({
    required this.isFillet,
    required this.value,
    this.applyToAll = false,
  });
}

Future<ArchitectChamferFilletOptions?> showArchitectChamferFilletDialog(
  BuildContext context, {
  required double unitToMeters,
  required String unitSymbol,
  bool initialIsFillet = false,
  bool canApplyToAll = false,
}) => showDialog<ArchitectChamferFilletOptions>(
  context: context,
  builder: (_) => _ChamferFilletDialog(
    unitToMeters: unitToMeters,
    unitSymbol: unitSymbol,
    initialIsFillet: initialIsFillet,
    canApplyToAll: canApplyToAll,
  ),
);

class _ChamferFilletDialog extends StatefulWidget {
  final double unitToMeters;
  final String unitSymbol;
  final bool initialIsFillet;
  final bool canApplyToAll;

  const _ChamferFilletDialog({
    required this.unitToMeters,
    required this.unitSymbol,
    required this.initialIsFillet,
    required this.canApplyToAll,
  });

  @override
  State<_ChamferFilletDialog> createState() => _ChamferFilletDialogState();
}

class _ChamferFilletDialogState extends State<_ChamferFilletDialog> {
  late bool isFillet;
  late final TextEditingController controller;
  bool applyToAll = false;

  @override
  void initState() {
    super.initState();
    isFillet = widget.initialIsFillet;
    controller = TextEditingController(text: '0.50');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final parsed = const BimNumericRule().parse(controller.text);
    final metres = parsed == null ? null : parsed * widget.unitToMeters;
    final valid = metres != null && metres.isFinite && metres > 0;

    void submit() {
      if (valid) {
        Navigator.of(context).pop(
          ArchitectChamferFilletOptions(
            isFillet: isFillet,
            value: metres,
            applyToAll: applyToAll,
          ),
        );
      }
    }

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 320),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: Row(
        children: [
          AppIcon(
            isFillet ? AppIconId.roundedCorner : AppIconId.rectangle,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFillet ? l.architectFillet : l.architectChamfer,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l.architectChamfer),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l.architectFillet),
                ),
              ],
              selected: {isFillet},
              onSelectionChanged: (selected) {
                setState(() => isFillet = selected.first);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              keyboardType: TextInputType.none,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: isFillet
                    ? l.architectFilletRadius
                    : l.architectChamferDistance,
                suffixText: widget.unitSymbol,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 10),
            Theme(
              data: ThemeData.dark(),
              child: BimNumericKeypad(
                keyPrefix: 'chamfer-fillet-key',
                onKey: (key) => setState(() {
                  controller.text = BimNumericKeypad.edit(
                    controller.text,
                    key,
                    decimals: 2,
                  );
                }),
              ),
            ),
            if (widget.canApplyToAll) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.architectApplyToAllCorners),
                value: applyToAll,
                onChanged: (val) => setState(() => applyToAll = val ?? false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: valid ? submit : null,
          child: Text(l.applyAction),
        ),
      ],
    );
  }
}
