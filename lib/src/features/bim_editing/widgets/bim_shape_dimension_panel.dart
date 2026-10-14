import 'package:flutter/material.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'bim_numeric_keypad.dart';

/// Project-unit values; this panel never opens the platform keyboard.
class BimShapeDimensionPanel extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String unit;
  final double minimum;
  final bool canSave, signed;
  final void Function(int index, double value) onChanged;
  final VoidCallback onSave, onCancel;
  const BimShapeDimensionPanel({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
    required this.minimum,
    this.canSave = true,
    this.signed = false,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  });
  @override
  State<BimShapeDimensionPanel> createState() => _BimShapeDimensionPanelState();
}

class _BimShapeDimensionPanelState extends State<BimShapeDimensionPanel> {
  late List<String?> input;
  int active = 0;
  @override
  void initState() {
    super.initState();
    input = List.filled(widget.values.length, null);
  }

  double? value(int i) => input[i] == null
      ? widget.values[i]
      : const BimNumericRule().parse(input[i]!);
  bool valid(int i) =>
      value(i) != null && value(i)!.isFinite && value(i)! >= widget.minimum;
  void key(String key) => setState(() {
    input[active] = BimNumericKeypad.edit(input[active], key);
    if (valid(active)) widget.onChanged(active, value(active)!);
  });
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xF51E242C),
    elevation: 8,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: InkWell(
                      key: ValueKey('shape-input-$i'),
                      onTap: () => setState(() => active = i),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !valid(i)
                                ? Colors.redAccent
                                : active == i
                                ? Colors.cyanAccent
                                : Colors.white38,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.labels[i],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${input[i] ?? widget.values[i].toStringAsFixed(2)} ${widget.unit}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.signed)
            TextButton(onPressed: () => key('±'), child: const Text('±')),
          BimNumericKeypad(keyPrefix: 'shape-key', onKey: key),
          if (!widget.canSave)
            Text(
              context.l10n.architectOperationRejected,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const ValueKey('shape-cancel'),
                  onPressed: widget.onCancel,
                  child: Text(context.l10n.cancel),
                ),
              ),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('shape-save'),
                  onPressed:
                      widget.canSave &&
                          List.generate(input.length, valid).every((v) => v)
                      ? widget.onSave
                      : null,
                  child: Text(context.l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
