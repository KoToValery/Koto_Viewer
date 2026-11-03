import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/properties/bim_numeric_rule.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../services/architect_wall_arc_editing.dart';

class ArchitectWallArcDimensionDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectWall wall;
  final ArchitectArcDimension dimension;
  final ValueChanged<ArchitectArcDimension> onDimension;
  final ValueChanged<ArchitectWall> onPreview;
  final void Function(ArchitectWall) validate;
  final String confirmLabel;

  const ArchitectWallArcDimensionDialog({
    super.key,
    required this.project,
    required this.wall,
    required this.dimension,
    required this.onDimension,
    required this.onPreview,
    required this.validate,
    required this.confirmLabel,
  });

  @override
  State<ArchitectWallArcDimensionDialog> createState() => _ArcDimensionState();
}

class _ArcDimensionState extends State<ArchitectWallArcDimensionDialog> {
  late ArchitectWall _wall = widget.wall;
  late ArchitectWall _inputBasis = widget.wall;
  late ArchitectArcDimension _dimension = widget.dimension;
  String? _input;
  bool _invalid = false;
  int get _decimals => math.max(4, widget.project.distanceDecimals);
  double get _value => _dimension == ArchitectArcDimension.sagitta
      ? _wall.arc!.sagitta
      : _wall.arc!.radius;

  @override
  void initState() {
    super.initState();
    _validateCurrent();
  }

  void _validateCurrent() {
    try {
      widget.validate(_wall);
      _invalid = false;
    } on ArgumentError {
      _invalid = true;
    }
  }

  void _evaluate() {
    final parsed = _input == null
        ? null
        : const BimNumericRule().parse(_input!);
    final value = _input == null
        ? _value
        : parsed == null
        ? null
        : widget.project.units.fromUnit(parsed);
    try {
      if (value == null) throw ArgumentError('Invalid dimension');
      final candidate = ArchitectWallArcEditing.withDimension(
        _inputBasis,
        _dimension,
        value,
      );
      widget.validate(candidate);
      _wall = candidate;
      _invalid = false;
    } on ArgumentError {
      _invalid = true;
    }
  }

  void _key(String key) {
    setState(() {
      _input = BimNumericKeypad.edit(
        _input,
        key == ',' ? '.' : key,
        decimals: _decimals,
      );
      _evaluate();
    });
    if (!_invalid) widget.onPreview(_wall);
  }

  void _select(ArchitectArcDimension dimension) {
    setState(() {
      _dimension = dimension;
      _inputBasis = _wall;
      _input = null;
      _validateCurrent();
    });
    widget.onDimension(dimension);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final displayed =
        _input ??
        widget.project.units
            .toUnit(_value)
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
          final character = event.character;
          if (character != null && RegExp(r'^[0-9.,-]$').hasMatch(character)) {
            _key(character);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _key('⌫');
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
                SegmentedButton<ArchitectArcDimension>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ArchitectArcDimension.sagitta,
                      label: Text(l.wallArcSagitta),
                      tooltip: l.wallArcSagittaHelp,
                    ),
                    ButtonSegment(
                      value: ArchitectArcDimension.radius,
                      label: Text(l.architectRadius),
                    ),
                  ],
                  selected: {_dimension},
                  onSelectionChanged: (values) => _select(values.single),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: _dimension == ArchitectArcDimension.sagitta
                      ? l.wallArcSagitta
                      : l.architectRadius,
                  child: Container(
                    key: const ValueKey('wall-arc-dimension-input'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _invalid ? colors.error : colors.primary,
                      ),
                    ),
                    child: Text(
                      '${_dimension == ArchitectArcDimension.sagitta ? 'h' : 'R'}=$displayed ${widget.project.units.symbol}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (_invalid)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.wallArcInvalidDimension,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                const SizedBox(height: 4),
                BimNumericKeypad(
                  keyPrefix: 'arc-key',
                  decimals: _decimals,
                  onKey: _key,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('wall-arc-dimension-cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.cancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('wall-arc-dimension-save'),
                        onPressed: _invalid
                            ? null
                            : () => Navigator.pop(context, _wall),
                        child: Text(widget.confirmLabel),
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
