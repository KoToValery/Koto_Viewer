import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_line_style.dart';
import '../rendering/architect_hatch_geometry.dart';
import 'architect_line_style_picker.dart';
import 'architect_wall_drafting_panel.dart';

extension ArchitectHatchLabel on ArchitectHatchPattern {
  String label(AppLocalizations l) => switch (id) {
    'diagonal' => l.architectHatchDiagonal,
    'reverseDiagonal' => l.architectHatchReverseDiagonal,
    'horizontal' => l.architectHatchHorizontal,
    'vertical' => l.architectHatchVertical,
    'cross' => l.architectHatchCross,
    'diagonalCross' => l.architectHatchDiagonalCross,
    'brick' => l.architectHatchBrick,
    'concrete' => l.architectHatchConcrete,
    'dots' => l.architectHatchDots,
    'earth' => l.architectHatchEarth,
    _ => name,
  };
}

class ArchitectHatchSample extends StatelessWidget {
  final ArchitectHatchPattern pattern;
  final double width, height;
  const ArchitectHatchSample({
    super.key,
    required this.pattern,
    this.width = 76,
    this.height = 38,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _HatchSamplePainter(
      pattern,
      Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _HatchSamplePainter extends CustomPainter {
  final ArchitectHatchPattern pattern;
  final Color color;
  _HatchSamplePainter(this.pattern, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final boundary = Path()..addRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(boundary);
    canvas.drawPath(
      ArchitectHatchGeometry.path(
        boundary: boundary,
        pattern: pattern,
        unitsPerMm: 3,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HatchSamplePainter old) =>
      old.pattern != pattern || old.color != color;
}

/// One small swatch in the workspace; catalogs and editing open on demand.
class ArchitectHatchPicker extends StatelessWidget {
  final ArchitectHatchPattern? value;
  final List<ArchitectHatchPattern> customPatterns;
  final List<ArchitectLineStyle> lineStyles;
  final ValueChanged<ArchitectHatchPattern> onChanged;
  final bool compact;
  const ArchitectHatchPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.customPatterns = const [],
    this.lineStyles = const [],
    this.compact = false,
  });
  Future<void> _choose(BuildContext context) async {
    final l = context.l10n;
    final options = <String, ArchitectHatchPattern>{
      for (final p in ArchitectHatchPattern.presets) p.id: p,
      for (final p in customPatterns) p.id: p,
      if (value != null &&
          !value!.isPreset &&
          !customPatterns.any((p) => p.id == value!.id))
        value!.id: value!,
    }.values.toList();
    final chosen = await showDialog<ArchitectHatchPattern>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.architectToolHatch),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        content: SizedBox(
          width: 300,
          height: MediaQuery.sizeOf(context).height * .45,
          child: ListView(
            children: [
              for (final p in options)
                ListTile(
                  key: ValueKey('hatch-pattern-${p.id}'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    p.label(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ArchitectHatchSample(pattern: p),
                  selected: p == value,
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('hatch-custom'),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(l.architectHatchCustom),
            onPressed: () async {
              final result = await showDialog<ArchitectHatchPattern>(
                context: ctx,
                builder: (_) => ArchitectHatchEditor(
                  initial: value ?? ArchitectHatchPattern.diagonal,
                  lineStyles: lineStyles,
                ),
              );
              if (result != null && ctx.mounted) Navigator.pop(ctx, result);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
    if (chosen != null && context.mounted) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (compact) {
      return Tooltip(
        message: '${l.architectToolHatch}: ${value?.label(l) ?? '—'}',
        child: InkWell(
          onTap: () => _choose(context),
          child: SizedBox(
            width: 58,
            height: 40,
            child: Center(
              child: ArchitectHatchSample(
                pattern: value ?? ArchitectHatchPattern.diagonal,
                width: 42,
                height: 28,
              ),
            ),
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(l.architectHatchPattern),
      subtitle: Text(
        value?.label(l) ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: value == null
          ? const Text('—')
          : ArchitectHatchSample(pattern: value!),
      onTap: () => _choose(context),
    );
  }
}

class ArchitectHatchEditor extends StatefulWidget {
  final ArchitectHatchPattern initial;
  final List<ArchitectLineStyle> lineStyles;
  const ArchitectHatchEditor({
    super.key,
    required this.initial,
    this.lineStyles = const [],
  });
  @override
  State<ArchitectHatchEditor> createState() => _ArchitectHatchEditorState();
}

class ArchitectHatchDraftBar extends StatelessWidget {
  final ArchitectHatchPattern pattern;
  final List<ArchitectHatchPattern> customPatterns;
  final List<ArchitectLineStyle> lineStyles;
  final int pointCount;
  final ValueChanged<ArchitectHatchPattern> onChanged;
  final VoidCallback onUndo, onFinish, onCancel;
  const ArchitectHatchDraftBar({
    super.key,
    required this.pattern,
    required this.customPatterns,
    required this.lineStyles,
    required this.pointCount,
    required this.onChanged,
    required this.onUndo,
    required this.onFinish,
    required this.onCancel,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Theme(
      data: ThemeData.dark(),
      child: Material(
        color: const Color(0xEE1E242C),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArchitectHatchPicker(
              key: const ValueKey('architect-draft-hatch'),
              value: pattern,
              compact: true,
              customPatterns: customPatterns,
              lineStyles: lineStyles,
              onChanged: onChanged,
            ),
            if (pointCount > 0) ...[
              IconButton(
                key: const ValueKey('hatch-draft-undo'),
                tooltip: l.undoAction,
                icon: const Icon(Icons.undo, size: 20),
                onPressed: onUndo,
              ),
              IconButton(
                key: const ValueKey('hatch-draft-finish'),
                tooltip: l.architectHatchFinish,
                icon: const Icon(Icons.check, size: 20),
                onPressed: pointCount >= 3 ? onFinish : null,
              ),
              IconButton(
                key: const ValueKey('hatch-draft-cancel'),
                tooltip: l.cancel,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onCancel,
              ),
            ] else
              Tooltip(
                message: l.architectHatchDrawHint,
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.polyline_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchitectHatchEditorState extends State<ArchitectHatchEditor> {
  late final TextEditingController _name;
  late final List<ArchitectHatchLayer> _layers;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.initial.isPreset ? '' : widget.initial.name,
    );
    _layers = List.of(widget.initial.layers);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ArchitectHatchPattern get _preview => ArchitectHatchPattern(
    id: 'preview',
    name: '_',
    layers: List.unmodifiable(_layers),
  );
  Future<void> _edit(
    int index,
    String field,
    double current,
    double min,
    double max,
    String label,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var draft = current;
    final l = context.l10n;
    final unit = field == 'angleDeg' ? '°' : 'mm';
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
                    title: label,
                    minimumLength: min,
                    endLabel: l.save,
                    keypadInitiallyOpen: true,
                    showDirection: false,
                    showContinue: false,
                    onLength: (v) => draft = v,
                    onEnd: () {
                      if (draft >= min && draft <= max) {
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
                        l.architectLineSymbolRange('$min', '$max', unit),
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
    if (result != null && mounted) {
      setState(() {
        final layer = _layers[index];
        _layers[index] = switch (field) {
          'angleDeg' => layer.copyWith(angleDeg: result),
          'spacingMm' => layer.copyWith(spacingMm: result),
          'phaseMm' => layer.copyWith(phaseMm: result),
          _ => layer.copyWith(shiftMm: result),
        };
      });
    }
  }

  Widget _number(
    int i,
    String field,
    double value,
    double min,
    double max,
    String label,
  ) => ListTile(
    key: ValueKey('hatch-layer-$i-$field'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      '${value.toStringAsFixed(2)}${field == 'angleDeg' ? '°' : ' mm'}',
    ),
    onTap: () => _edit(i, field, value, min, max, label),
  );
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectHatchCustom),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('hatch-pattern-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l.architectPropertyName),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 80,
                child: LayoutBuilder(
                  builder: (_, constraints) => ArchitectHatchSample(
                    pattern: _preview,
                    width: constraints.maxWidth,
                    height: 80,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.architectHatchHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (var i = 0; i < _layers.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(l.architectHatchLayer(i + 1))),
                            IconButton(
                              key: ValueKey('hatch-remove-$i'),
                              tooltip: l.delete,
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                              ),
                              onPressed: _layers.length == 1
                                  ? null
                                  : () => setState(() => _layers.removeAt(i)),
                            ),
                          ],
                        ),
                        _number(
                          i,
                          'angleDeg',
                          _layers[i].angleDeg,
                          -180,
                          180,
                          l.architectPropertyAngle,
                        ),
                        _number(
                          i,
                          'spacingMm',
                          _layers[i].spacingMm,
                          .5,
                          100,
                          l.architectHatchSpacing,
                        ),
                        ArchitectLineStylePicker(
                          key: ValueKey('hatch-layer-$i-style'),
                          value: _layers[i].lineStyle,
                          customStyles: widget.lineStyles,
                          onChanged: (style) => setState(() {
                            _layers[i] = _layers[i].copyWith(
                              lineStyle: style,
                              symbolsOnly: style.symbol == null
                                  ? false
                                  : _layers[i].symbolsOnly,
                            );
                          }),
                        ),
                        if (_layers[i].lineStyle.symbol != null)
                          CheckboxListTile(
                            key: ValueKey('hatch-layer-$i-symbols'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(l.architectHatchSymbolsOnly),
                            value: _layers[i].symbolsOnly,
                            onChanged: (v) {
                              if (v != null) {
                                setState(
                                  () => _layers[i] = _layers[i].copyWith(
                                    symbolsOnly: v,
                                  ),
                                );
                              }
                            },
                          ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            l.architectLineSymbolSettings,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          children: [
                            _number(
                              i,
                              'phaseMm',
                              _layers[i].phaseMm,
                              -100,
                              100,
                              l.architectHatchPhase,
                            ),
                            _number(
                              i,
                              'shiftMm',
                              _layers[i].shiftMm,
                              -100,
                              100,
                              l.architectHatchShift,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                key: const ValueKey('hatch-add-layer'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.architectHatchAddLayer),
                onPressed: _layers.length >= 8
                    ? null
                    : () => setState(
                        () => _layers.add(
                          const ArchitectHatchLayer(angleDeg: -45),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('hatch-pattern-save'),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  ArchitectHatchPattern(
                    id: widget.initial.isPreset
                        ? 'hatch_${DateTime.now().microsecondsSinceEpoch}'
                        : widget.initial.id,
                    name: _name.text.trim(),
                    layers: List.unmodifiable(_layers),
                  ),
                ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
