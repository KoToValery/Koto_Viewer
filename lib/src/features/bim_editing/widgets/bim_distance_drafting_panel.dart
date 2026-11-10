import 'package:kotoview/src/core/icons/app_icon.dart';
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

  /// Tool-specific controls above the length, without changing keypad state.
  final Widget? extraControls;
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
    this.extraControls,
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
      final value = BimNumericKeypad.edit(
        _input,
        key,
        decimals: widget.decimals,
      );
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
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.extraControls != null) ...[
              widget.extraControls!,
              const SizedBox(height: 4),
            ],
            if (widget.title != null && widget.title!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                child: Text(
                  widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
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
                  color: colors.surfaceContainerHighest,
                  border: Border.all(
                    color: _valid ? colors.primary : colors.error,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_input ?? widget.length.toStringAsFixed(widget.decimals)} ${widget.unit}',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AppIcon(
                      AppIconId.layoutGrid,
                      size: 16,
                      color: _keypad ? colors.tertiary : colors.primary,
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
                  foregroundColor: colors.onSurface,
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
                        foregroundColor: colors.primary,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: colors.primary, width: 1.0),
                        ),
                      ),
                      onPressed: widget.onUnlock,
                      icon: AppIcon(
                        AppIconId.compass,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    key: const ValueKey('wall-cancel'),
                    tooltip: l10n.cancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: colors.error,
                      backgroundColor: colors.error.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: colors.error, width: 1.5),
                      ),
                    ),
                    onPressed: widget.onCancel,
                    icon: AppIcon(
                      AppIconId.close,
                      color: colors.error,
                      size: 20,
                    ),
                  ),
                  if (widget.showContinue) ...[
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('wall-continue'),
                      tooltip: l10n.architectWallContinue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: colors.primary,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: colors.primary, width: 1.5),
                        ),
                      ),
                      onPressed: _valid ? widget.onContinue : null,
                      icon: AppIcon(
                        AppIconId.redo,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('wall-end'),
                    tooltip: widget.endLabel ?? l10n.architectWallEnd,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF00E676),
                      backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                      ),
                    ),
                    onPressed: _valid ? widget.onEnd : null,
                    icon: const AppIcon(
                      AppIconId.confirm,
                      color: Color(0xFF00E676),
                      size: 20,
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
