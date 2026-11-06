import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/properties/bim_numeric_rule.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../models/architect_project.dart';

/// Edits a temporary candidate only. The workspace command owns the final save.
class ArchitectNewPointDistanceDialog extends StatefulWidget {
  final ArchitectProject project;
  final int endpoint;
  final double distance;
  final bool Function(double) accepts;
  final ValueChanged<double> onPreview;
  const ArchitectNewPointDistanceDialog({
    super.key,
    required this.project,
    required this.endpoint,
    required this.distance,
    required this.accepts,
    required this.onPreview,
  });

  @override
  State<ArchitectNewPointDistanceDialog> createState() =>
      _DistanceDialogState();
}

class _DistanceDialogState extends State<ArchitectNewPointDistanceDialog> {
  String? _input;
  int get _decimals => math.max(4, widget.project.distanceDecimals);
  double? get _distance {
    if (_input == null) return widget.distance;
    final parsed = const BimNumericRule().parse(_input!);
    return parsed == null ? null : widget.project.units.fromUnit(parsed);
  }

  bool get _valid => _distance != null && widget.accepts(_distance!);

  void _key(String key) {
    setState(() {
      _input = BimNumericKeypad.edit(
        _input,
        key == ',' ? '.' : key,
        decimals: _decimals,
      );
    });
    if (_valid) widget.onPreview(_distance!);
  }

  void _apply() {
    if (_valid) Navigator.pop(context, _distance);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valid = _valid;
    final displayed =
        _input ??
        widget.project.units
            .toUnit(widget.distance)
            .toStringAsFixed(_decimals)
            .replaceFirst(RegExp(r'\.?0+$'), '');
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _apply();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _key('⌫');
            return KeyEventResult.handled;
          }
          final character = event.character;
          if (character != null && RegExp(r'^[0-9.,-]$').hasMatch(character)) {
            _key(character);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 280,
            maxHeight: MediaQuery.sizeOf(context).height - 32,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.architectNewPointDistanceTitle(widget.endpoint)),
                const SizedBox(height: 10),
                Semantics(
                  label: l.architectNewPointDistanceTitle(widget.endpoint),
                  child: Container(
                    key: const ValueKey('architect-new-point-distance-input'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: valid
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: Text(
                      '$displayed ${widget.project.units.symbol}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (!valid)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.architectNewPointDistanceInvalid,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                BimNumericKeypad(
                  keyPrefix: 'new-point-key',
                  decimals: _decimals,
                  onKey: _key,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey(
                          'architect-new-point-distance-cancel',
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.cancel),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey(
                          'architect-new-point-distance-apply',
                        ),
                        onPressed: valid ? _apply : null,
                        child: Text(l.applyAction),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
