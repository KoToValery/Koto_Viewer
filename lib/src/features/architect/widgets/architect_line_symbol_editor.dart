import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_line_symbol.dart';
import 'architect_line_symbol_sketch.dart';
import 'architect_wall_drafting_panel.dart';

extension ArchitectLineSymbolLabel on ArchitectLineSymbolShape {
  String label(AppLocalizations l) => switch (this) {
    ArchitectLineSymbolShape.none => l.architectLineSymbolNone,
    ArchitectLineSymbolShape.lightning => l.architectLineSymbolLightning,
    ArchitectLineSymbolShape.circle => l.architectLineSymbolCircle,
    ArchitectLineSymbolShape.square => l.architectLineSymbolSquare,
    ArchitectLineSymbolShape.triangle => l.architectLineSymbolTriangle,
    ArchitectLineSymbolShape.diamond => l.architectLineSymbolDiamond,
    ArchitectLineSymbolShape.cross => l.architectLineSymbolCross,
    ArchitectLineSymbolShape.arrow => l.architectLineSymbolArrow,
    ArchitectLineSymbolShape.chevron => l.architectLineSymbolChevron,
    ArchitectLineSymbolShape.custom => l.architectLineSymbolCustom,
  };
}

class ArchitectLineSymbolEditor extends StatelessWidget {
  final ArchitectLineSymbol? value;
  final ValueChanged<ArchitectLineSymbol?> onChanged;
  const ArchitectLineSymbolEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _draw(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final strokes = await showDialog<List<List<Offset>>>(
      context: context,
      builder: (_) => ArchitectLineSymbolSketch(
        initial: value?.shape == ArchitectLineSymbolShape.custom
            ? value!.strokes
            : const [],
      ),
    );
    if (strokes != null && context.mounted) {
      onChanged(
        (value ?? const ArchitectLineSymbol()).copyWith(
          shape: ArchitectLineSymbolShape.custom,
          strokes: strokes,
        ),
      );
    }
  }

  Future<void> _number(
    BuildContext context, {
    required String title,
    required double initial,
    required double minimum,
    required double maximum,
    required String unit,
    required ValueChanged<double> apply,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var draft = initial;
    final l = context.l10n;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        var invalid = false;
        return StatefulBuilder(
          builder: (ctx, update) => Dialog(
            child: SizedBox(
              width: 250,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArchitectWallDraftingPanel(
                    length: draft,
                    unit: unit,
                    decimals: 2,
                    title: title,
                    endLabel: l.save,
                    minimumLength: minimum,
                    keypadInitiallyOpen: true,
                    showDirection: false,
                    showContinue: false,
                    onLength: (v) => draft = v,
                    onEnd: () {
                      if (draft >= minimum && draft <= maximum) {
                        Navigator.pop(ctx, draft);
                      } else {
                        update(() => invalid = true);
                      }
                    },
                    onContinue: () {},
                    onUnlock: () {},
                    onCancel: () => Navigator.pop(ctx),
                  ),
                  if (invalid)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l.architectLineSymbolRange(
                          '$minimum',
                          '$maximum',
                          unit,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result != null && context.mounted) apply(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, symbol = value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: l.architectLineSymbol,
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ArchitectLineSymbolShape>(
              key: const ValueKey('line-symbol-shape'),
              isExpanded: true,
              value: symbol?.shape ?? ArchitectLineSymbolShape.none,
              items: [
                for (final shape in ArchitectLineSymbolShape.values)
                  DropdownMenuItem(
                    value: shape,
                    child: Text(
                      shape.label(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (shape) {
                if (shape == null) return;
                if (shape == ArchitectLineSymbolShape.none) {
                  onChanged(null);
                } else if (shape == ArchitectLineSymbolShape.custom) {
                  _draw(context);
                } else {
                  onChanged(
                    (symbol ?? const ArchitectLineSymbol()).copyWith(
                      shape: shape,
                      strokes: const [],
                    ),
                  );
                }
              },
            ),
          ),
        ),
        if (symbol != null)
          ExpansionTile(
            key: const ValueKey('line-symbol-settings'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: true,
            title: Text(
              l.architectLineSymbolSettings,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            children: [
              if (symbol.shape == ArchitectLineSymbolShape.custom)
                TextButton.icon(
                  key: const ValueKey('line-symbol-edit-shape'),
                  onPressed: () => _draw(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.architectLineSymbolDraw),
                ),
              ListTile(
                key: const ValueKey('line-symbol-size'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectLineSymbolSize),
                trailing: Text('${symbol.sizeMm} mm'),
                onTap: () => _number(
                  context,
                  title: l.architectLineSymbolSize,
                  initial: symbol.sizeMm,
                  minimum: .5,
                  maximum: 20,
                  unit: 'mm',
                  apply: (size) => onChanged(
                    symbol.copyWith(
                      sizeMm: size,
                      spacingMm: math.max(symbol.spacingMm, size * 1.5),
                    ),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('line-symbol-spacing'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectLineSymbolSpacing),
                trailing: Text('${symbol.spacingMm} mm'),
                onTap: () => _number(
                  context,
                  title: l.architectLineSymbolSpacing,
                  initial: symbol.spacingMm,
                  minimum: symbol.sizeMm * 1.5,
                  maximum: 100,
                  unit: 'mm',
                  apply: (spacing) =>
                      onChanged(symbol.copyWith(spacingMm: spacing)),
                ),
              ),
              ListTile(
                key: const ValueKey('line-symbol-angle'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectPropertyAngle),
                trailing: Text('${symbol.angleDeg}°'),
                onTap: () => _number(
                  context,
                  title: l.architectPropertyAngle,
                  initial: symbol.angleDeg,
                  minimum: -180,
                  maximum: 180,
                  unit: '°',
                  apply: (angle) => onChanged(symbol.copyWith(angleDeg: angle)),
                ),
              ),
              CheckboxListTile(
                key: const ValueKey('line-symbol-follow'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectLineSymbolFollow),
                value: symbol.followLine,
                onChanged: (v) {
                  if (v != null) onChanged(symbol.copyWith(followLine: v));
                },
              ),
              CheckboxListTile(
                key: const ValueKey('line-symbol-clear-line'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectLineSymbolClearLine),
                value: symbol.clearLine,
                onChanged: (v) {
                  if (v != null) onChanged(symbol.copyWith(clearLine: v));
                },
              ),
            ],
          ),
      ],
    );
  }
}
