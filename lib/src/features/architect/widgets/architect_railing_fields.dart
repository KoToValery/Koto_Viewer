import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart' show ArchitectUnit;
import '../models/architect_wall_type.dart';
import 'architect_railing_label.dart';

/// Controlled draft fields: editing does not execute a project command.
class ArchitectRailingFields extends StatelessWidget {
  final ArchitectRailingDesign? design;
  final double totalHeight;
  final ArchitectUnit unit;
  final ValueChanged<ArchitectRailingDesign> onChanged;
  final ValueChanged<double> onHeightChanged;

  const ArchitectRailingFields({
    super.key,
    required this.design,
    required this.totalHeight,
    required this.unit,
    required this.onChanged,
    required this.onHeightChanged,
  });

  Widget _dimension(
    BuildContext context,
    String id,
    String label,
    double value,
    ValueChanged<double> change, {
    bool zeroAllowed = false,
    String? help,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: _RailingDimensionField(
      key: ValueKey(
        'railing-${design?.kind.name ?? 'legacy'}-$id-${unit.name}',
      ),
      value: value,
      unit: unit,
      label: label,
      help: help,
      zeroAllowed: zeroAllowed,
      onChanged: change,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, value = design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ArchitectRailingKind>(
          key: ValueKey('railing-model-${value?.kind.name ?? 'legacy'}'),
          initialValue: value?.kind,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.railingModel),
          hint: Text(l.railingLegacy),
          items: [
            for (final kind in ArchitectRailingKind.values)
              DropdownMenuItem(
                value: kind,
                child: Row(
                  children: [
                    SizedBox(
                      width: 62,
                      height: 30,
                      child: ArchitectRailingPreview(kind: kind),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kind.label(l),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (kind) {
            if (kind != null && kind != value?.kind) {
              onChanged(ArchitectRailingDesign.preset(kind));
            }
          },
        ),
        if (value != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 72,
              child: ArchitectRailingPreview(kind: value.kind),
            ),
          ),
          _dimension(
            context,
            'height',
            l.railingHeight,
            totalHeight,
            onHeightChanged,
            help: l.railingTotalHeightHelp,
          ),
          if (value.hasSolidBody)
            _dimension(
              context,
              'solid-height',
              l.railingSolidHeight,
              value.solidHeightAt(totalHeight),
              (v) => onChanged(
                value.kind == ArchitectRailingKind.solidCap
                    ? value.copyWith(
                        copingThickness: totalHeight - v,
                        clearSolidHeight: true,
                      )
                    : value.copyWith(solidHeight: v),
              ),
            ),
          ExpansionTile(
            key: ValueKey('railing-details-${value.kind.name}'),
            tilePadding: EdgeInsets.zero,
            title: Text(l.compositionDetails),
            children: [
              if (value.kind != ArchitectRailingKind.solidCap)
                DropdownButtonFormField<ArchitectRailingMount>(
                  key: ValueKey('railing-mount-${value.kind.name}'),
                  initialValue: value.mounting,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.railingMount),
                  items: [
                    for (final mount in ArchitectRailingMount.values)
                      DropdownMenuItem(
                        value: mount,
                        child: Text(
                          mount == ArchitectRailingMount.top
                              ? l.railingMountTop
                              : l.railingMountSide,
                        ),
                      ),
                  ],
                  onChanged: (mount) {
                    if (mount != null) {
                      onChanged(value.copyWith(mounting: mount));
                    }
                  },
                ),
              if (value.kind == ArchitectRailingKind.solidCap)
                _dimension(
                  context,
                  'coping',
                  l.railingCopingThickness,
                  totalHeight - value.solidHeightAt(totalHeight),
                  (v) => onChanged(
                    value.copyWith(copingThickness: v, clearSolidHeight: true),
                  ),
                ),
              if (value.kind != ArchitectRailingKind.solidCap)
                _dimension(
                  context,
                  'handrail',
                  l.railingHandrailDiameter,
                  value.handrailDiameter,
                  (v) => onChanged(value.copyWith(handrailDiameter: v)),
                ),
              if (value.kind != ArchitectRailingKind.solidCap &&
                  value.kind != ArchitectRailingKind.glassChannel) ...[
                _dimension(
                  context,
                  'post-size',
                  l.railingPostSize,
                  value.postSize,
                  (v) => onChanged(value.copyWith(postSize: v)),
                ),
                _dimension(
                  context,
                  'post-spacing',
                  l.railingPostSpacing,
                  value.postSpacing,
                  (v) => onChanged(value.copyWith(postSpacing: v)),
                ),
              ],
              if (value.isGlass) ...[
                _dimension(
                  context,
                  'glass',
                  l.railingGlassThickness,
                  value.glassThickness,
                  (v) => onChanged(value.copyWith(glassThickness: v)),
                ),
                _dimension(
                  context,
                  'panel-width',
                  l.railingPanelWidth,
                  value.panelWidth,
                  (v) => onChanged(value.copyWith(panelWidth: v)),
                ),
                _dimension(
                  context,
                  'panel-gap',
                  l.railingPanelGap,
                  value.panelGap,
                  (v) => onChanged(value.copyWith(panelGap: v)),
                  zeroAllowed: true,
                ),
              ],
              if (value.kind == ArchitectRailingKind.glassChannel) ...[
                _dimension(
                  context,
                  'channel-width',
                  l.railingChannelWidth,
                  value.channelWidth,
                  (v) => onChanged(value.copyWith(channelWidth: v)),
                ),
                _dimension(
                  context,
                  'channel-height',
                  l.railingChannelHeight,
                  value.channelHeight,
                  (v) => onChanged(value.copyWith(channelHeight: v)),
                ),
              ],
              if (!value.hasSolidBody &&
                  value.kind != ArchitectRailingKind.glassChannel)
                _dimension(
                  context,
                  'bottom-gap',
                  l.railingBottomGap,
                  value.bottomGap,
                  (v) => onChanged(value.copyWith(bottomGap: v)),
                  zeroAllowed: true,
                ),
              if (!value.hasSolidBody && !value.isGlass) ...[
                _dimension(
                  context,
                  'infill-spacing',
                  l.railingInfillSpacing,
                  value.infillSpacing,
                  (v) => onChanged(value.copyWith(infillSpacing: v)),
                ),
                _dimension(
                  context,
                  'infill-width',
                  l.railingInfillWidth,
                  value.infillWidth,
                  (v) => onChanged(value.copyWith(infillWidth: v)),
                ),
                if (value.kind == ArchitectRailingKind.verticalSlats)
                  _dimension(
                    context,
                    'infill-depth',
                    l.railingInfillDepth,
                    value.infillDepth,
                    (v) => onChanged(value.copyWith(infillDepth: v)),
                  ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ],
      ],
    );
  }
}

class _RailingDimensionField extends StatefulWidget {
  final double value;
  final ArchitectUnit unit;
  final String label;
  final String? help;
  final bool zeroAllowed;
  final ValueChanged<double> onChanged;
  const _RailingDimensionField({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    this.help,
    required this.zeroAllowed,
    required this.onChanged,
  });
  @override
  State<_RailingDimensionField> createState() => _RailingDimensionState();
}

class _RailingDimensionState extends State<_RailingDimensionField> {
  late final input = TextEditingController(text: _formatted);
  String get _formatted => ArchitectUnit.trimZeros(
    widget.unit.toUnit(widget.value).toStringAsFixed(6),
  );
  double? parse(String text) {
    final number = double.tryParse(text.trim().replaceAll(',', '.'));
    return number != null &&
            number.isFinite &&
            (widget.zeroAllowed ? number >= 0 : number > 0)
        ? widget.unit.fromUnit(number)
        : null;
  }

  @override
  void didUpdateWidget(covariant _RailingDimensionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.unit != widget.unit) {
      final parsed = parse(input.text);
      if (oldWidget.unit != widget.unit ||
          parsed == null ||
          (parsed - widget.value).abs() > 1e-9) {
        final value = widget.value, unit = widget.unit;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.value == value && widget.unit == unit) {
            input.text = _formatted;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: input,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: widget.unit.symbol,
      isDense: true,
      suffixIcon: widget.help == null
          ? null
          : Tooltip(
              message: widget.help!,
              child: const Icon(Icons.info_outline, size: 18),
            ),
    ),
    validator: (text) =>
        parse(text ?? '') == null ? context.l10n.railingInvalid : null,
    onChanged: (text) {
      final value = parse(text);
      if (value != null) widget.onChanged(value);
    },
  );
}

/// Sparse monochrome elevation, readable in the catalog at phone widths.
class ArchitectRailingPreview extends StatelessWidget {
  final ArchitectRailingKind kind;
  const ArchitectRailingPreview({super.key, required this.kind});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PreviewPainter(kind));
}

class _PreviewPainter extends CustomPainter {
  final ArchitectRailingKind kind;
  _PreviewPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pen = Paint()
      ..color = const Color(0xff333333)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final left = size.width * .06, right = size.width * .94;
    final top = size.height * .16, bottom = size.height * .9;
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), pen);
    line(left, bottom, right, bottom);
    if (kind == ArchitectRailingKind.solidCap ||
        kind == ArchitectRailingKind.solidStainless) {
      final solidTop = kind == ArchitectRailingKind.solidCap
          ? top + 3
          : top + size.height * .20;
      canvas.drawRect(Rect.fromLTRB(left, solidTop, right, bottom), pen);
      line(left, top, right, top);
      for (final ratio in [.15, .5, .85]) {
        final x = left + (right - left) * ratio;
        if (kind == ArchitectRailingKind.solidStainless) {
          line(x, solidTop, x, top);
        }
      }
    } else if (kind == ArchitectRailingKind.glassChannel ||
        kind == ArchitectRailingKind.glassPosts) {
      line(left, top, right, top);
      line(left, top, left, bottom);
      line(right, top, right, bottom);
      for (final ratio in [1 / 3, 2 / 3]) {
        final x = left + (right - left) * ratio;
        line(x, top, x, bottom);
      }
      if (kind == ArchitectRailingKind.glassChannel) {
        line(left, bottom - 3, right, bottom - 3);
      }
      if (kind == ArchitectRailingKind.glassPosts) {
        final thick = pen.strokeWidth;
        pen.strokeWidth = 2;
        line(left, top, left, bottom);
        line(right, top, right, bottom);
        pen.strokeWidth = thick;
      }
    } else {
      line(left, top, right, top);
      for (var i = 0; i <= 10; i++) {
        final x = left + (right - left) * i / 10;
        if (kind == ArchitectRailingKind.verticalSlats) {
          canvas.drawRect(Rect.fromLTRB(x - .7, top, x + .7, bottom), pen);
        } else {
          line(x, top, x, bottom);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => oldDelegate.kind != kind;
}
