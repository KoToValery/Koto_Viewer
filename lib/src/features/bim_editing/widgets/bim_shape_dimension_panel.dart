import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/icons/app_icon.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'bim_numeric_keypad.dart';

/// Project-unit values with a local keypad and optional physical-key input.
class BimShapeDimensionPanel extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String unit;
  final int decimals;
  final double minimum;
  final bool canSave, signed, keypadInitiallyOpen;
  final void Function(int index, double value) onChanged;
  final VoidCallback onSave, onCancel;
  const BimShapeDimensionPanel({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
    this.decimals = 2,
    required this.minimum,
    this.canSave = true,
    this.signed = false,
    this.keypadInitiallyOpen = true,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  }) : assert(values.length == labels.length && values.length > 0);
  @override
  State<BimShapeDimensionPanel> createState() => _BimShapeDimensionPanelState();
}

class _BimShapeDimensionPanelState extends State<BimShapeDimensionPanel> {
  late List<String?> input;
  late bool keypad;
  int active = 0;
  @override
  void initState() {
    super.initState();
    input = List.filled(widget.values.length, null);
    keypad = widget.keypadInitiallyOpen;
  }

  @override
  void didUpdateWidget(covariant BimShapeDimensionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length) {
      input = List.filled(widget.values.length, null);
      active = 0;
    }
  }

  double? value(int i) => input[i] == null
      ? widget.values[i]
      : const BimNumericRule().parse(input[i]!);
  bool valid(int i) =>
      value(i) != null && value(i)!.isFinite && value(i)! >= widget.minimum;
  bool get canSave =>
      widget.canSave && List.generate(input.length, valid).every((v) => v);

  void key(String key) => setState(() {
    if (key == '±') {
      input[active] ??= widget.values[active].toStringAsFixed(widget.decimals);
    }
    input[active] = BimNumericKeypad.edit(
      input[active],
      key,
      decimals: widget.decimals,
    );
    if (valid(active)) widget.onChanged(active, value(active)!);
  });

  KeyEventResult onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null && RegExp(r'^[0-9.,]$').hasMatch(character)) {
      key(character == ',' ? '.' : character);
      return KeyEventResult.handled;
    }
    if (widget.signed && (character == '-' || character == '+')) {
      final negative = (input[active] ?? widget.values[active].toString())
          .startsWith('-');
      if (negative != (character == '-')) {
        input[active] ??= widget.values[active].toStringAsFixed(
          widget.decimals,
        );
        key('±');
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      key('⌫');
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      setState(
        () => active =
            (active +
                (HardwareKeyboard.instance.isShiftPressed
                    ? input.length - 1
                    : 1)) %
            input.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (canSave) widget.onSave();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme, l = context.l10n;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => onKey(event),
      child: Material(
        key: const ValueKey('bim-shape-dimension-panel'),
        color: colors.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (var i = 0; i < widget.values.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Tooltip(
                          message: l.bimExactDistanceInputHelp,
                          child: InkWell(
                            key: ValueKey('shape-input-$i'),
                            onTap: () => setState(() {
                              active = i;
                              keypad = true;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !valid(i)
                                      ? colors.error
                                      : active == i
                                      ? colors.primary
                                      : colors.outlineVariant,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${input[i] ?? widget.values[i].toStringAsFixed(widget.decimals)} ${widget.unit}',
                                      style: TextStyle(
                                        color: valid(i)
                                            ? colors.onSurface
                                            : colors.error,
                                        fontSize: 18,
                                        height: 1.15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('shape-keypad-toggle'),
                    tooltip: l.bimExactDistanceInputHelp,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() => keypad = !keypad),
                    icon: AppIcon(
                      keypad ? AppIconId.expandLess : AppIconId.layoutGrid,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                  if (widget.signed)
                    TextButton(
                      key: const ValueKey('shape-sign'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => key('±'),
                      child: const Text('±'),
                    ),
                  const Spacer(),
                  Tooltip(
                    message: l.save,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FilledButton(
                        key: const ValueKey('shape-save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: canSave ? widget.onSave : null,
                        child: const AppIcon(AppIconId.confirm, size: 20),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('shape-cancel'),
                    tooltip: l.cancel,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: widget.onCancel,
                    icon: AppIcon(
                      AppIconId.close,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (!widget.canSave)
                Text(
                  l.architectOperationRejected,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.error, fontSize: 11),
                ),
              if (keypad)
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    key: const ValueKey('shape-keypad-scroll'),
                    padding: const EdgeInsets.only(top: 4),
                    child: BimNumericKeypad(
                      decimals: widget.decimals,
                      keyPrefix: 'shape-key',
                      onKey: key,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
