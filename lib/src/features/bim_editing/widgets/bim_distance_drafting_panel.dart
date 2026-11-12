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

  Widget _value(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = widget.title ?? context.l10n.architectEdgeDistance;
    return Tooltip(
      message: context.l10n.bimExactDistanceInputHelp,
      child: Semantics(
        button: true,
        expanded: _keypad,
        label: label,
        child: InkWell(
          key: const ValueKey('wall-length-input'),
          onTap: () => setState(() => _keypad = !_keypad),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: !_valid
                    ? colors.error
                    : _keypad
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_input ?? widget.length.toStringAsFixed(widget.decimals)} ${widget.unit}',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: _valid ? colors.onSurface : colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                AppIcon(
                  _keypad ? AppIconId.expandLess : AppIconId.layoutGrid,
                  size: 16,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _symbol(AppIconId icon, Color color, String? caption) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: caption == null ? 20 : 18, color: color),
      if (caption != null) ...[
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            caption,
            maxLines: 1,
            style: TextStyle(fontSize: 10, height: 1, color: color),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
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
        if ((event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            _valid) {
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
        key: const ValueKey('bim-distance-panel'),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inline =
                  constraints.maxWidth >= 288 || !widget.showContinue;
              final captions = constraints.maxWidth >= 320 || !inline;
              final cancel = IconButton(
                key: const ValueKey('wall-cancel'),
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
              );
              final direction = IconButton(
                key: const ValueKey('wall-direction-unlock'),
                tooltip: l.architectWallDirection,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                onPressed: widget.onUnlock,
                icon: AppIcon(
                  AppIconId.compass,
                  size: 20,
                  color: colors.primary,
                ),
              );
              final continueButton = IconButton(
                key: const ValueKey('wall-continue'),
                tooltip: l.architectWallContinue,
                constraints: BoxConstraints.tightFor(
                  width: captions ? 64 : 44,
                  height: 44,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                style: IconButton.styleFrom(
                  backgroundColor: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _valid ? widget.onContinue : null,
                icon: _symbol(
                  AppIconId.redo,
                  _valid
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: .38),
                  captions ? l.architectWallContinue : null,
                ),
              );
              final end = Tooltip(
                message: widget.endLabel ?? l.architectWallEnd,
                child: SizedBox(
                  width: captions ? 56 : 44,
                  height: 44,
                  child: FilledButton(
                    key: const ValueKey('wall-end'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _valid ? widget.onEnd : null,
                    child: _symbol(
                      AppIconId.confirm,
                      _valid
                          ? colors.onPrimary
                          : colors.onSurface.withValues(alpha: .38),
                      captions ? widget.endLabel ?? l.architectWallEnd : null,
                    ),
                  ),
                ),
              );
              final signed = TextButton(
                onPressed: () => _key('±'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('±'),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.extraControls != null) ...[
                    widget.extraControls!,
                    const SizedBox(height: 4),
                  ],
                  if (inline)
                    Row(
                      children: [
                        Expanded(child: _value(context)),
                        if (widget.showDirection) direction,
                        if (_keypad && widget.minimumLength < 0) signed,
                        if (widget.showContinue) ...[
                          continueButton,
                          const SizedBox(width: 4),
                        ],
                        end,
                        cancel,
                      ],
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(child: _value(context)),
                        cancel,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.showDirection) direction,
                        if (_keypad && widget.minimumLength < 0) signed,
                        const Spacer(),
                        if (widget.showContinue) ...[
                          continueButton,
                          const SizedBox(width: 4),
                        ],
                        end,
                      ],
                    ),
                  ],
                  if (_keypad)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: BimNumericKeypad(
                        decimals: widget.decimals,
                        onKey: _key,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
