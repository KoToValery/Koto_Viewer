import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final radius = BorderRadius.circular(16);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final character = event.character;
        if (character != null && RegExp(r'^[0-9.,]$').hasMatch(character)) {
          _key(character == ',' ? '.' : character);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _key('⌫');
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && _valid) {
          widget.onEnd();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: colors.surface,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.extraControls != null) ...[
                widget.extraControls!,
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('wall-length-input'),
                      onTap: () => setState(() => _keypad = !_keypad),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          border: Border.all(
                            color: _valid
                                ? colors.outlineVariant
                                : colors.error,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.title ?? l10n.architectEdgeDistance,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${_input ?? widget.length.toStringAsFixed(widget.decimals)} ${widget.unit}',
                                      style: TextStyle(
                                        color: _valid
                                            ? colors.onSurface
                                            : colors.error,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppIcon(
                              AppIconId.layoutGrid,
                              size: 18,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('wall-cancel'),
                    tooltip: l10n.cancel,
                    onPressed: widget.onCancel,
                    icon: AppIcon(
                      AppIconId.close,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
              if (_keypad) ...[
                const SizedBox(height: 6),
                BimNumericKeypad(decimals: widget.decimals, onKey: _key),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (widget.showDirection)
                    IconButton(
                      key: const ValueKey('wall-direction-unlock'),
                      tooltip: l10n.architectWallDirection,
                      onPressed: widget.onUnlock,
                      icon: AppIcon(
                        AppIconId.compass,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  if (_keypad && widget.minimumLength < 0)
                    TextButton(
                      onPressed: () => _key('±'),
                      child: const Text('±'),
                    ),
                  const Spacer(),
                  if (widget.showContinue) ...[
                    IconButton(
                      key: const ValueKey('wall-continue'),
                      tooltip: l10n.architectWallContinue,
                      onPressed: _valid ? widget.onContinue : null,
                      icon: AppIcon(
                        AppIconId.redo,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Tooltip(
                    message: widget.endLabel ?? l10n.architectWallEnd,
                    child: FilledButton(
                      key: const ValueKey('wall-end'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _valid ? widget.onEnd : null,
                      child: AppIcon(
                        AppIconId.confirm,
                        size: 22,
                        color: _valid
                            ? colors.onPrimary
                            : colors.onSurface.withValues(alpha: .38),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
