import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_underlay_models.dart';
import '../rendering/architect_cad_underlay_renderer.dart';
import '../rendering/architect_canvas_palette.dart';
import '../services/architect_underlay_service.dart';

Future<ArchitectCadImportSelection?> showArchitectCadImportDialog({
  required BuildContext context,
  required ArchitectPreparedCadUnderlay prepared,
  ArchitectCadUnderlayConfig? existing,
}) => showDialog<ArchitectCadImportSelection>(
  context: context,
  builder: (_) => _CadImportDialog(prepared: prepared, existing: existing),
);

enum _ScaleChoice {
  automatic,
  current,
  meters(1, 'm'),
  centimeters(100, 'cm'),
  millimeters(1000, 'mm'),
  inches(1 / .0254, 'in'),
  feet(1 / .3048, 'ft'),
  custom;

  final double? factor;
  final String? symbol;
  const _ScaleChoice([this.factor, this.symbol]);
}

Future<double?> showArchitectCadScaleDialog({
  required BuildContext context,
  required double currentUnitsPerMeter,
}) => showDialog<double>(
  context: context,
  builder: (_) => _CadScaleDialog(initialFactor: currentUnitsPerMeter),
);

class _CadScaleDialog extends StatefulWidget {
  final double initialFactor;
  const _CadScaleDialog({required this.initialFactor});

  @override
  State<_CadScaleDialog> createState() => _CadScaleDialogState();
}

class _CadScaleDialogState extends State<_CadScaleDialog> {
  late final TextEditingController _custom;
  late _ScaleChoice _choice;

  @override
  void initState() {
    super.initState();
    _choice = _ScaleChoice.values.firstWhere(
      (choice) => choice.factor == widget.initialFactor,
      orElse: () => _ScaleChoice.custom,
    );
    _custom = TextEditingController(text: widget.initialFactor.toString());
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final factor = _choice.factor ?? _readScale(_custom.text);
    return AlertDialog(
      scrollable: true,
      title: Text(l.architectUnderlayScale),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<_ScaleChoice>(
            initialValue: _choice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.architectUnderlayCadScaleUnitsLabel,
            ),
            items: [
              for (final choice in _ScaleChoice.values)
                if (choice.factor != null || choice == _ScaleChoice.custom)
                  DropdownMenuItem(
                    value: choice,
                    child: Text(
                      choice.symbol ?? l.architectUnderlayCadScaleCustom,
                    ),
                  ),
            ],
            onChanged: (choice) {
              if (choice != null) setState(() => _choice = choice);
            },
          ),
          if (_choice == _ScaleChoice.custom)
            TextField(
              controller: _custom,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.architectCadUnitsPerMeter,
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: factor == null
              ? null
              : () => Navigator.pop(context, factor),
          child: Text(l.applyAction),
        ),
      ],
    );
  }
}

double? _readScale(String input) {
  final factor = double.tryParse(input.trim().replaceAll(',', '.'));
  return factor != null &&
          factor.isFinite &&
          factor > 0 &&
          (1 / factor).isFinite
      ? factor
      : null;
}

class _CadImportDialog extends StatefulWidget {
  final ArchitectPreparedCadUnderlay prepared;
  final ArchitectCadUnderlayConfig? existing;

  const _CadImportDialog({required this.prepared, this.existing});

  @override
  State<_CadImportDialog> createState() => _CadImportDialogState();
}

class _CadImportDialogState extends State<_CadImportDialog> {
  late final double? _currentFactor;
  late final TextEditingController _custom;
  late _ScaleChoice _choice;
  late bool _cadOrientation;

  @override
  void initState() {
    super.initState();
    final units = widget.existing?.unitsPerMeter;
    _currentFactor = units != null && units > 0 && units.isFinite
        ? units
        : null;
    _choice = widget.existing?.lockOrigin == true && _currentFactor != null
        ? _ScaleChoice.current
        : _ScaleChoice.automatic;
    _cadOrientation = widget.existing?.cadOrientation ?? true;
    _custom = TextEditingController(text: _factor.toString());
  }

  double? get _factor => switch (_choice) {
    _ScaleChoice.automatic => widget.prepared.suggestedUnitsPerMeter,
    _ScaleChoice.current => _currentFactor,
    _ScaleChoice.custom => _readScale(_custom.text),
    final preset => preset.factor,
  };

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final bounds = widget.prepared.document.bounds;
    final factor = _factor;
    final valid =
        factor != null &&
        factor.isFinite &&
        factor > 0 &&
        (bounds.longestSide / factor).isFinite &&
        (1 / factor).isFinite;
    final format = NumberFormat.decimalPattern(l.localeName)
      ..maximumFractionDigits = 4;
    final scientific = NumberFormat.scientificPattern(l.localeName);
    String number(double value) =>
        value != 0 && (value.abs() < .0001 || value.abs() >= 1e9)
        ? scientific.format(value)
        : format.format(value);
    final replacing = widget.existing != null;
    final suggested = widget.prepared.scaleIsEstimated
        ? switch (widget.prepared.suggestedUnitsPerMeter) {
            1000 => 'mm',
            100 => 'cm',
            _ => 'm',
          }
        : widget.prepared.declaredUnit.symbol;

    return AlertDialog(
      scrollable: true,
      title: Text(
        replacing ? l.architectCadReplaceTitle : l.architectCadImportTitle,
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.prepared.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: SizedBox(
                  height: 158,
                  child: CustomPaint(
                    painter: _CadImportPreview(
                      document: widget.prepared.document,
                      invertY: _cadOrientation,
                      palette: theme.brightness == Brightness.dark
                          ? const ArchitectCanvasPalette.dark()
                          : const ArchitectCanvasPalette.light(),
                      existing: widget.existing,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_ScaleChoice>(
              initialValue: _choice,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.architectUnderlayCadScaleUnitsLabel,
              ),
              items: [
                for (final choice in _ScaleChoice.values)
                  if (choice != _ScaleChoice.current || _currentFactor != null)
                    DropdownMenuItem(
                      value: choice,
                      child: Text(switch (choice) {
                        _ScaleChoice.automatic =>
                          '${l.architectCadScaleAuto} ($suggested)',
                        _ScaleChoice.current =>
                          '${l.architectCadScaleCurrent} (${number(_currentFactor!)})',
                        _ScaleChoice.custom =>
                          l.architectUnderlayCadScaleCustom,
                        _ => choice.symbol!,
                      }),
                    ),
              ],
              onChanged: (choice) {
                if (choice != null) setState(() => _choice = choice);
              },
            ),
            if (_choice == _ScaleChoice.automatic)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.prepared.scaleIsEstimated
                      ? l.architectCadScaleEstimated
                      : l.architectCadScaleFromFile,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_choice == _ScaleChoice.custom)
              TextField(
                controller: _custom,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l.architectCadUnitsPerMeter,
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 12),
            Text(
              valid
                  ? '${number(bounds.width / factor)} × ${number(bounds.height / factor)} m'
                  : '–',
              key: const ValueKey('architect-cad-import-size'),
              style: theme.textTheme.titleSmall,
            ),
            if (widget.existing?.cadOrientation == false)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectCadOrientation),
                subtitle: Text(l.architectCadOrientationHelp),
                value: _cadOrientation,
                onChanged: (value) => setState(() => _cadOrientation = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  ArchitectCadImportSelection(
                    prepared: widget.prepared,
                    unitsPerMeter: factor,
                    cadOrientation: _cadOrientation,
                  ),
                )
              : null,
          child: Text(
            replacing
                ? l.architectCadReplaceAccept
                : l.architectCadImportAccept,
          ),
        ),
      ],
    );
  }
}

class _CadImportPreview extends CustomPainter {
  final DxfDocument document;
  final bool invertY;
  final ArchitectCanvasPalette palette;
  final ArchitectCadUnderlayConfig? existing;

  const _CadImportPreview({
    required this.document,
    required this.invertY,
    required this.palette,
    this.existing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 32 || size.height < 32) return;
    final bounds = document.bounds;
    final scale = math.min(
      (size.width - 24) / bounds.width,
      (size.height - 24) / bounds.height,
    );
    if (!scale.isFinite || scale <= 0) return;
    final frame = BimCoordinateFrame(
      unitsPerMeter: 1 / scale,
      invertY: invertY,
    ).placing(bounds.center, size.center(Offset.zero));
    paintArchitectCadUnderlay(
      canvas: canvas,
      size: size,
      document: document,
      frame: frame,
      visibleModel: Offset.zero & size,
      viewportScale: 1,
      palette: palette,
      visibility: existing?.layerOverrides ?? const {},
      config: existing,
    );
  }

  @override
  bool shouldRepaint(covariant _CadImportPreview old) =>
      old.document != document ||
      old.invertY != invertY ||
      old.existing != existing ||
      old.palette.isDark != palette.isDark;
}
