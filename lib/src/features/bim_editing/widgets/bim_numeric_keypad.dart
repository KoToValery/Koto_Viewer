import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';

class BimNumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final String keyPrefix;
  final int decimals;
  const BimNumericKeypad({
    super.key,
    required this.onKey,
    this.keyPrefix = 'wall-key',
    this.decimals = 2,
  });

  /// Opens a compact dialog with [BimNumericKeypad] where the first pressed digit
  /// overwrites the existing displayed value directly without prior deletion.
  static Future<double?> showInputDialog(
    BuildContext context, {
    required String title,
    String initialText = '',
    String? unitLabel,
    int decimals = 2,
    bool allowNegative = false,
    double? min,
    double? max,
    String? Function(double)? validate,
    String? cancelLabel,
    String? applyLabel,
    Key? inputKey,
    String keyPrefix = 'bim-number-key',
  }) => showDialog<double>(
    context: context,
    builder: (_) => _BimNumericInputDialog(
      title: title,
      initialText: initialText,
      unitLabel: unitLabel,
      decimals: decimals,
      allowNegative: allowNegative,
      min: min,
      max: max,
      validate: validate,
      cancelLabel: cancelLabel,
      applyLabel: applyLabel,
      inputKey: inputKey,
      keyPrefix: keyPrefix,
    ),
  );

  static String edit(String? input, String key, {int decimals = 2}) {
    var value = input ?? '';
    if (key == '±') {
      return value.startsWith('-') ? value.substring(1) : '-$value';
    }
    if (key == '⌫') {
      return value.isEmpty ? '' : value.substring(0, value.length - 1);
    }
    if (key == '.') {
      if (decimals == 0) return value;
      return value.contains('.') ? value : '${value.isEmpty ? '0' : value}.';
    }
    if (value.length >= 10 ||
        (value.contains('.') && value.split('.').last.length >= decimals)) {
      return value;
    }
    return value + key;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['.', '0', '⌫'],
      ])
        Row(
          children: [
            for (final key in row)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: SizedBox(
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      key: ValueKey('$keyPrefix-$key'),
                      onPressed: key == '.' && decimals == 0
                          ? null
                          : () => onKey(key),
                      child: key == '⌫'
                          ? AppIcon(
                              AppIconId.backspace,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    ],
  );
}

class _BimNumericInputDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final String? unitLabel;
  final int decimals;
  final bool allowNegative;
  final double? min;
  final double? max;
  final String? Function(double)? validate;
  final String? cancelLabel;
  final String? applyLabel;
  final Key? inputKey;
  final String keyPrefix;

  const _BimNumericInputDialog({
    required this.title,
    required this.initialText,
    this.unitLabel,
    required this.decimals,
    required this.allowNegative,
    this.min,
    this.max,
    this.validate,
    this.cancelLabel,
    this.applyLabel,
    this.inputKey,
    required this.keyPrefix,
  });

  @override
  State<_BimNumericInputDialog> createState() => _BimNumericInputDialogState();
}

class _BimNumericInputDialogState extends State<_BimNumericInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  // Remains null until the first keypad/key entry so the first digit replaces
  // the pre-filled value directly without requiring manual deletion.
  String? _input;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      _input = BimNumericKeypad.edit(
        _input,
        key,
        decimals: widget.decimals,
      );
      _controller.value = TextEditingValue(
        text: _input!,
        selection: TextSelection.collapsed(offset: _input!.length),
      );
    });
  }

  double? _parsedValue() {
    final v = const BimNumericRule().parse(_controller.text);
    if (v == null || !v.isFinite) return null;
    if (!widget.allowNegative && v < 0) return null;
    if (widget.min != null && v < widget.min! - 1e-9) return null;
    if (widget.max != null && v > widget.max! + 1e-9) return null;
    if (widget.validate != null && widget.validate!(v) != null) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsedValue();
    final validationMsg = () {
      final raw = const BimNumericRule().parse(_controller.text);
      if (raw == null || !raw.isFinite) return null;
      return widget.validate?.call(raw);
    }();
    final l = context.l10n;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final ch = event.character;
        if (ch != null && RegExp(r'^[0-9.,]$').hasMatch(ch)) {
          _press(ch == ',' ? '.' : ch);
          return KeyEventResult.handled;
        }
        if (widget.allowNegative && ch == '-') {
          _press('±');
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          if (_input == null) {
            _input = _controller.text;
          }
          _press('⌫');
          return KeyEventResult.handled;
        }
        if ((event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            parsed != null) {
          Navigator.of(context).pop(parsed);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        actionsPadding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        constraints: const BoxConstraints(maxWidth: 300),
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: widget.inputKey ?? const ValueKey('bim-numeric-dialog-input'),
                controller: _controller,
                readOnly: true,
                showCursor: true,
                keyboardType: TextInputType.none,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: widget.unitLabel,
                  errorText: validationMsg,
                ),
                onChanged: (text) => setState(() => _input = text),
              ),
              const SizedBox(height: 8),
              BimNumericKeypad(
                keyPrefix: widget.keyPrefix,
                decimals: widget.decimals,
                onKey: _press,
              ),
              if (widget.allowNegative)
                TextButton(
                  onPressed: () {
                    _input ??= _controller.text;
                    _press('±');
                  },
                  child: const Text('±'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancelLabel ?? l.cancel),
          ),
          FilledButton(
            key: const ValueKey('bim-numeric-dialog-apply'),
            onPressed: parsed != null ? () => Navigator.of(context).pop(parsed) : null,
            child: Text(widget.applyLabel ?? l.applyAction),
          ),
        ],
      ),
    );
  }
}
