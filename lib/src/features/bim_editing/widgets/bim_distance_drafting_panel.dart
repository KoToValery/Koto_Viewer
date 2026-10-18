import 'package:flutter/material.dart';
import 'bim_numeric_keypad.dart';
import '../properties/bim_numeric_rule.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Local keypad never requests platform text input or covers the whole canvas.
class BimDistanceDraftingPanel extends StatefulWidget {
  final double length;
  final String unit;
  final int decimals;
  final double minimumLength;
  final ValueChanged<double> onLength;
  final VoidCallback onEnd, onContinue, onUnlock, onCancel;
  final bool showContinue, showDirection, keypadInitiallyOpen;
  final String? title, endLabel;
  const BimDistanceDraftingPanel({
    super.key,
    required this.length,
    required this.unit,
    this.decimals = 2,
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
      final value = BimNumericKeypad.edit(_input, key, decimals: widget.decimals);
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
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null && widget.title!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                child: Text(
                  widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            InkWell(
              key: const ValueKey('wall-length-input'),
              onTap: () => setState(() => _keypad = !_keypad),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  border: Border.all(
                    color: _valid ? Colors.cyanAccent : Colors.redAccent,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_input ?? widget.length.toStringAsFixed(widget.decimals)} ${widget.unit}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.dialpad,
                      size: 16,
                      color: _keypad ? Colors.amberAccent : Colors.cyanAccent,
                    ),
                  ],
                ),
              ),
            ),
            if (_keypad) ...[
              const SizedBox(height: 4),
              BimNumericKeypad(decimals: widget.decimals, onKey: _key),
            ],
            if (_keypad && widget.minimumLength < 0)
              TextButton(
                onPressed: () => _key('±'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('±'),
              ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  if (widget.showDirection) ...[
                    IconButton(
                      key: const ValueKey('wall-direction-unlock'),
                      tooltip: l10n.architectWallDirection,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        backgroundColor: Colors.cyanAccent.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Colors.cyanAccent, width: 1.0),
                        ),
                      ),
                      onPressed: widget.onUnlock,
                      icon: const Icon(
                        Icons.explore_outlined,
                        size: 18,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('wall-end'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent, width: 1.0),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _valid ? widget.onEnd : null,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.endLabel ?? l10n.architectWallEnd,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.showContinue) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('wall-continue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: const Color(0xFF1E242C),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: _valid ? widget.onContinue : null,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.architectWallContinue,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    key: const ValueKey('wall-cancel'),
                    tooltip: l10n.cancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    onPressed: widget.onCancel,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.redAccent,
                      size: 19,
                      weight: 700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
