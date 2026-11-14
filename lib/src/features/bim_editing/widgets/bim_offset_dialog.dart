import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'bim_numeric_keypad.dart';

class BimElementOffsetOptions {
  final double distance;
  final bool copy;
  const BimElementOffsetOptions(this.distance, this.copy);

  BimElementOffsetOptions copyWith({double? distance, bool? copy}) =>
      BimElementOffsetOptions(distance ?? this.distance, copy ?? this.copy);
}

Future<BimElementOffsetOptions?> showBimElementOffsetDialog(
  BuildContext context, {
  required double unitToMeters,
  required String unitSymbol,
  double? initialDistance,
  bool? initialCopy,
  bool wallAxes = false,
}) => showDialog<BimElementOffsetOptions>(
  context: context,
  builder: (_) => _ElementOffsetDialog(
    unitToMeters: unitToMeters,
    unitSymbol: unitSymbol,
    initialDistance: initialDistance,
    initialCopy: initialCopy,
    wallAxes: wallAxes,
  ),
);

class _ElementOffsetDialog extends StatefulWidget {
  final double unitToMeters;
  final String unitSymbol;
  final double? initialDistance;
  final bool? initialCopy;
  final bool wallAxes;
  const _ElementOffsetDialog({
    required this.unitToMeters,
    required this.unitSymbol,
    this.initialDistance,
    this.initialCopy,
    required this.wallAxes,
  });
  @override
  State<_ElementOffsetDialog> createState() => _ElementOffsetDialogState();
}

class _ElementOffsetDialogState extends State<_ElementOffsetDialog> {
  final controller = TextEditingController();
  bool copy = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDistance != null && widget.unitToMeters > 0) {
      final unitVal = widget.initialDistance! / widget.unitToMeters;
      var str = unitVal.toStringAsFixed(2);
      if (str.contains('.')) {
        str = str.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      controller.text = str;
    }
    if (widget.initialCopy != null) {
      copy = widget.initialCopy!;
    }
  }

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
            child: const AppIcon(AppIconId.help, size: 20),
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
              readOnly: true,
              showCursor: true,
              keyboardType: TextInputType.none,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: widget.wallAxes
                    ? l.architectWallAxisSpacing
                    : l.bimOffsetDistance,
                suffixText: widget.unitSymbol,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => submit(),
            ),
            BimNumericKeypad(
              keyPrefix: 'architect-offset-key',
              decimals: 3,
              onKey: (key) => setState(() {
                controller.text = BimNumericKeypad.edit(
                  controller.text,
                  key,
                  decimals: 3,
                );
              }),
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
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const ValueKey('architect-offset-start'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
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
  String? _input;

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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      constraints: const BoxConstraints(maxWidth: 280),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: widget.inputKey,
              controller: controller,
              readOnly: true,
              showCursor: true,
              keyboardType: TextInputType.none,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                isDense: true,
                labelText: context.l10n.offsetAction,
                suffixText: widget.unitSymbol,
              ),
              onChanged: (text) => setState(() => _input = text),
              onSubmitted: (_) => submit(),
            ),
            BimNumericKeypad(
              keyPrefix: 'bim-offset-key',
              decimals: 3,
              onKey: (key) => setState(() {
                _input = BimNumericKeypad.edit(
                  _input,
                  key,
                  decimals: 3,
                );
                controller.text = _input!;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        Tooltip(
          message: context.l10n.specifyDirectionByDrag,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: valid ? submit : null,
            child: Text(context.l10n.offsetAction),
          ),
        ),
      ],
    );
  }
}
