import 'package:flutter/material.dart';
import 'bim_numeric_keypad.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Local keypad never requests platform text input or covers the whole canvas.
class BimDistanceDraftingPanel extends StatefulWidget {
  final double length;
  final String unit;
  final double minimumLength;
  final ValueChanged<double> onLength;
  final VoidCallback onEnd, onContinue, onUnlock, onCancel;
  final bool showContinue, showDirection, keypadInitiallyOpen;
  final String? title, endLabel;
  const BimDistanceDraftingPanel({
    super.key,
    required this.length,
    required this.unit,
    this.minimumLength = .001,
    required this.onLength,
    required this.onEnd,
    required this.onContinue,
    required this.onUnlock,
    required this.onCancel,
    this.showContinue = true,
    this.showDirection = true,
    this.keypadInitiallyOpen = false,
    this.title,
    this.endLabel,
  });
  @override
  State<BimDistanceDraftingPanel> createState() =>
      _BimDistanceDraftingPanelState();
}

class _BimDistanceDraftingPanelState extends State<BimDistanceDraftingPanel> {
  String? _input;
  bool _keypad = false;
  @override
  void initState() {
    super.initState();
    _keypad = widget.keypadInitiallyOpen;
  }

  bool get _valid {
    final value = _input == null
        ? widget.length
        : const BimNumericRule().parse(_input!);
    return value != null && value.isFinite && value >= widget.minimumLength;
  }

  void _key(String key) {
    setState(() {
      final value = BimNumericKeypad.edit(_input, key);
      _input = value;
      final number = const BimNumericRule().parse(value);
      if (number != null && number.isFinite && number >= widget.minimumLength) {
        widget.onLength(number);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
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
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.showDirection
                        ? IconButton(
                            tooltip: l10n.architectWallDirection,
                            onPressed: widget.onUnlock,
                            icon: const Icon(Icons.explore_outlined, size: 20),
                          )
                        : Text(
                            widget.title ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ),
              ],
            ),
            InkWell(
              key: const ValueKey('wall-length-input'),
              onTap: () => setState(() => _keypad = !_keypad),
              child: Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _valid ? Colors.cyanAccent : Colors.redAccent,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_input ?? widget.length.toStringAsFixed(2)} ${widget.unit}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.dialpad,
                      size: 18,
                      color: Colors.cyanAccent,
                    ),
                  ],
                ),
              ),
            ),
            if (_keypad) ...[
              const SizedBox(height: 4),
              BimNumericKeypad(onKey: _key),
            ],
            if (_keypad && widget.minimumLength < 0)
              TextButton(onPressed: () => _key('±'), child: const Text('±')),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const ValueKey('wall-end'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                    ),
                    onPressed: _valid ? widget.onEnd : null,
                    child: Text(widget.endLabel ?? l10n.architectWallEnd),
                  ),
                ),
                if (widget.showContinue)
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('wall-continue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: const Color(0xFF1E242C),
                      ),
                      onPressed: _valid ? widget.onContinue : null,
                      child: Text(l10n.architectWallContinue),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
