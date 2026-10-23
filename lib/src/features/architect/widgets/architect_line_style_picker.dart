import 'dart:math' as math;
import '../models/architect_line_symbol.dart';
import 'architect_line_symbol_editor.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_line_style.dart';
import '../rendering/architect_line_pattern.dart';
import 'architect_wall_drafting_panel.dart';

extension ArchitectLineStyleLabel on ArchitectLineStyle {
  String label(AppLocalizations l) => switch (id) {
    'woodGrain' => l.architectHatchWood,
    'solid' => l.architectLineSolid,
    'powerLine' => l.architectLinePowerLine,
    'hatchBrickJoint' => l.architectLineHatchBrickJoint,
    'hatchAggregate' => l.architectLineHatchAggregate,
    'hatchGrain' => l.architectLineHatchGrain,
    'hatchDots' => l.architectLineHatchDots,
    'hatchEarth' => l.architectLineHatchEarth,
    'dashed' => l.architectLineDashed,
    'shortDashed' => l.architectLineShortDashed,
    'longDashed' => l.architectLineLongDashed,
    'dotted' => l.architectLineDotted,
    'sparseDotted' => l.architectLineSparseDotted,
    'dashDot' => l.architectLineDashDot,
    'dashDoubleDot' => l.architectLineDashDoubleDot,
    'longDashDot' => l.architectLineLongDashDot,
    'longShortDash' => l.architectLineLongShortDash,
    'doubleDashDot' => l.architectLineDoubleDashDot,
    _ => name,
  };
}

class ArchitectLineStyleSample extends StatelessWidget {
  final ArchitectLineStyle style;
  final double width, height;
  const ArchitectLineStyleSample({
    super.key,
    required this.style,
    this.width = 96,
    this.height = 24,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _SamplePainter(style, Theme.of(context).colorScheme.onSurface),
  );
}

class _SamplePainter extends CustomPainter {
  final ArchitectLineStyle style;
  final Color color;
  _SamplePainter(this.style, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final source = Path()
      ..moveTo(1, size.height / 2)
      ..lineTo(size.width - 1, size.height / 2);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      ArchitectLinePattern.path(
        source,
        style,
        style.symbol == null
            ? 3
            : math.min(3, (size.height - 4) / style.symbol!.sizeMm),
      ),
      Paint()
        ..color = color
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SamplePainter old) =>
      old.style != style || old.color != color;
}

/// One small control; the full catalog and editor appear only on demand.
class ArchitectLineStylePicker extends StatelessWidget {
  final ArchitectLineStyle? value;
  final List<ArchitectLineStyle> customStyles;
  final ValueChanged<ArchitectLineStyle> onChanged;
  final bool compact;
  const ArchitectLineStylePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.customStyles = const [],
    this.compact = false,
  });

  Future<void> _choose(BuildContext context) async {
    final l = context.l10n;
    final options = <String, ArchitectLineStyle>{
      for (final s in ArchitectLineStyle.allPresets) s.id: s,
      for (final s in customStyles) s.id: s,
      if (value != null &&
          !value!.isPreset &&
          !customStyles.any((s) => s.id == value!.id))
        value!.id: value!,
    }.values.toList();
    final chosen = await showDialog<ArchitectLineStyle>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.architectLineStyle),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        content: SizedBox(
          width: 300,
          height: MediaQuery.sizeOf(context).height * .45,
          child: ListView(
            children: [
              for (final style in options)
                ListTile(
                  key: ValueKey('line-style-${style.id}'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    style.label(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ArchitectLineStyleSample(style: style, width: 86),
                  selected: style == value,
                  onTap: () => Navigator.pop(dialogContext, style),
                ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('line-style-custom'),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(l.architectLinePatternEditor),
            onPressed: () async {
              final style = await showDialog<ArchitectLineStyle>(
                context: dialogContext,
                builder: (_) => ArchitectLinePatternEditor(
                  initial: value ?? ArchitectLineStyle.presets[1],
                ),
              );
              if (style != null && dialogContext.mounted) {
                Navigator.pop(dialogContext, style);
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
        message: '${l.architectLineStyle}: ${value?.label(l) ?? '—'}',
        child: InkWell(
          onTap: () => _choose(context),
          child: SizedBox(
            width: 58,
            height: 40,
            child: Center(
              child: ArchitectLineStyleSample(
                style: value ?? ArchitectLineStyle.solid,
                width: 42,
              ),
            ),
          ),
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(l.architectLineStyle),
      subtitle: Text(
        value?.label(l) ?? '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: value == null
          ? const Text('—')
          : ArchitectLineStyleSample(style: value!),
      onTap: () => _choose(context),
    );
  }
}

class ArchitectLinePatternEditor extends StatefulWidget {
  final ArchitectLineStyle initial;
  const ArchitectLinePatternEditor({super.key, required this.initial});
  @override
  State<ArchitectLinePatternEditor> createState() =>
      _ArchitectLinePatternEditorState();
}

class _ArchitectLinePatternEditorState
    extends State<ArchitectLinePatternEditor> {
  late final TextEditingController _name;
  late final List<double> _segments;
  ArchitectLineSymbol? _symbol;
  bool _continuous = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.initial.isPreset ? '' : widget.initial.name,
    );
    _symbol = widget.initial.symbol;
    _continuous = widget.initial.isSolid && _symbol != null;
    _segments = widget.initial.isSolid
        ? [3, 1.5]
        : List.of(widget.initial.segmentsMm);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _edit(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var draft = _segments[index];
    final l = context.l10n;
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, update) => Dialog(
            child: SizedBox(
              width: 250,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ArchitectWallDraftingPanel(
                    length: draft,
                    unit: 'mm',
                    decimals: 2,
                    title: index.isEven
                        ? l.architectLineDash
                        : l.architectLineGap,
                    endLabel: l.save,
                    minimumLength: .1,
                    keypadInitiallyOpen: true,
                    showDirection: false,
                    showContinue: false,
                    onLength: (v) => draft = v,
                    onEnd: () {
                      if (draft <= 100) {
                        Navigator.pop(ctx, draft);
                      } else {
                        update(() => error = l.architectLinePatternRange);
                      }
                    },
                    onContinue: () {},
                    onUnlock: () {},
                    onCancel: () => Navigator.pop(ctx),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        error!,
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
    if (value != null && mounted) setState(() => _segments[index] = value);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectLinePatternEditor),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('line-pattern-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l.architectPropertyName),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: LayoutBuilder(
                  builder: (_, size) => ArchitectLineStyleSample(
                    width: size.maxWidth,
                    style: ArchitectLineStyle(
                      id: 'preview',
                      name: '_',
                      segmentsMm: _continuous
                          ? const []
                          : List.unmodifiable(_segments),
                      symbol: _symbol,
                    ),
                  ),
                ),
              ),
              Text(
                l.architectLinePatternHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ArchitectLineSymbolEditor(
                value: _symbol,
                onChanged: (symbol) => setState(() {
                  _symbol = symbol;
                  if (symbol == null) _continuous = false;
                }),
              ),
              if (_symbol != null)
                SwitchListTile(
                  key: const ValueKey('line-symbol-solid-base'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.architectLineSolid),
                  value: _continuous,
                  onChanged: (v) => setState(() => _continuous = v),
                ),
              if (!_continuous) ...[
                Row(
                  children: [
                    Expanded(child: Text('${l.architectLineDash} (mm)')),
                    Expanded(child: Text('${l.architectLineGap} (mm)')),
                    const SizedBox(width: 36),
                  ],
                ),
                for (var pair = 0; pair < _segments.length ~/ 2; pair++)
                  Row(
                    children: [
                      for (final index in [pair * 2, pair * 2 + 1])
                        Expanded(
                          child: TextButton(
                            key: ValueKey('line-pattern-length-$index'),
                            onPressed: () => _edit(index),
                            child: Text(_segments[index].toStringAsFixed(2)),
                          ),
                        ),
                      IconButton(
                        key: ValueKey('line-pattern-remove-$pair'),
                        tooltip: l.architectLinePatternRemove,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: _segments.length <= 2
                            ? null
                            : () => setState(
                                () => _segments.removeRange(
                                  pair * 2,
                                  pair * 2 + 2,
                                ),
                              ),
                      ),
                    ],
                  ),
                TextButton.icon(
                  key: const ValueKey('line-pattern-add'),
                  onPressed: _segments.length >= 16
                      ? null
                      : () => setState(() => _segments.addAll([3, 1.5])),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.architectLinePatternAdd),
                ),
              ],
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
          key: const ValueKey('line-pattern-save'),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  ArchitectLineStyle(
                    id: widget.initial.isPreset
                        ? 'custom_${DateTime.now().microsecondsSinceEpoch}'
                        : widget.initial.id,
                    name: _name.text.trim(),
                    segmentsMm: _continuous
                        ? const []
                        : List.unmodifiable(_segments),
                    symbol: _symbol,
                  ),
                ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
