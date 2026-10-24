import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_line_style.dart';
import '../rendering/architect_hatch_geometry.dart';
import 'architect_line_style_picker.dart';
import 'architect_wall_drafting_panel.dart';
import 'architect_line_symbol_sketch.dart';
import '../models/architect_line_symbol.dart';

extension ArchitectHatchLabel on ArchitectHatchPattern {
  String label(AppLocalizations l) => switch (id) {
    'wood' => l.architectHatchWood,
    'metal' => l.architectHatchMetal,
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
                builder: (_) => ArchitectHatchGenerator(
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

/// A drawn motif becomes one repeated symbol family; the advanced editor stays
/// available for existing multi-layer definitions.
class ArchitectHatchGenerator extends StatefulWidget {
  final ArchitectHatchPattern initial;
  final List<ArchitectLineStyle> lineStyles;
  const ArchitectHatchGenerator({super.key,required this.initial,this.lineStyles=const []});
  @override
  State<ArchitectHatchGenerator> createState()=>_HatchGeneratorState();
}

class _HatchGeneratorState extends State<ArchitectHatchGenerator> {
  late final TextEditingController name=TextEditingController(
    text:widget.initial.isPreset?'':widget.initial.name);
  List<List<Offset>> strokes=[];
  double size=3, across=6, along=7, angle=0;
  @override
  void initState() {
    super.initState();
    final layer=widget.initial.layers.first;
    final symbol=layer.lineStyle.symbol;
    if(widget.initial.layers.length==1 && layer.symbolsOnly &&
        symbol?.shape==ArchitectLineSymbolShape.custom) {
      strokes=symbol!.strokes;size=symbol.sizeMm;
      across=layer.spacingMm;along=symbol.spacingMm;angle=layer.angleDeg;
    }
  }
  @override
  void dispose(){name.dispose();super.dispose();}
  ArchitectHatchPattern pattern({String id='preview'})=>ArchitectHatchPattern(
    id:id,name:name.text.trim().isEmpty?'_':name.text.trim(),layers:[
      ArchitectHatchLayer(angleDeg:angle,spacingMm:across,symbolsOnly:true,
        lineStyle:ArchitectLineStyle(id:'$id-motif',name:'_',segmentsMm:[],
          symbol:ArchitectLineSymbol(shape:ArchitectLineSymbolShape.custom,
            strokes:strokes,sizeMm:size,spacingMm:along,clearLine:false))),
    ]);
  Widget slider(String label,double value,double min,double max,ValueChanged<double> change)=>
    Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('$label: ${value.toStringAsFixed(1)}${max==180?'°':' mm'}'),
      Slider(value:value.clamp(min,max),min:min,max:max,onChanged:(v)=>setState(()=>change(v))),
    ]);
  @override
  Widget build(BuildContext context) {
    final l=context.l10n;
    return AlertDialog(title:Text(l.architectHatchGenerator),content:SizedBox(width:320,
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(key:const ValueKey('hatch-generator-name'),controller:name,
          decoration:InputDecoration(labelText:l.architectPropertyName),onChanged:(_)=>setState((){})),
        const SizedBox(height:8),Text(l.architectHatchGeneratorHint),
        TextButton.icon(key:const ValueKey('hatch-generator-draw'),icon:const Icon(Icons.polyline_outlined),
          label:Text(l.architectLineSymbolCustom),onPressed:() async {
            final result=await showDialog<List<List<Offset>>>(context:context,
              builder:(_)=>ArchitectLineSymbolSketch(initial:strokes,tilePreview:true,
                previewSizeMm:size,previewSpacingMm:along,previewRowSpacingMm:across,previewAngleDeg:angle));
            if(result!=null && mounted) setState(()=>strokes=result);
          }),
        if(strokes.isNotEmpty) ...[
          LayoutBuilder(builder:(_,c)=>ArchitectHatchSample(pattern:pattern(),width:c.maxWidth,height:130)),
          slider(l.architectPropertySize,size,.5,20,(v){size=v;if(along<size*1.5)along=size*1.5;}),
          slider(l.architectLineSymbolSpacing,along,size*1.5,100,(v)=>along=v),
          slider(l.architectHatchSpacing,across,.5,100,(v)=>across=v),
          slider(l.architectPropertyAngle,angle,-180,180,(v)=>angle=v),
        ],
        TextButton.icon(icon:const Icon(Icons.tune),label:Text(l.architectLineSymbolSettings),
          onPressed:() async {
            final result=await showDialog<ArchitectHatchPattern>(context:context,
              builder:(_)=>ArchitectHatchEditor(initial:widget.initial,lineStyles:widget.lineStyles));
            if(result!=null && context.mounted) Navigator.pop(context,result);
          }),
      ]))),actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:Text(l.cancel)),
        FilledButton(key:const ValueKey('hatch-generator-save'),
          onPressed:strokes.isEmpty||name.text.trim().isEmpty?null:()=>Navigator.pop(context,
            pattern(id:'hatch-${DateTime.now().microsecondsSinceEpoch}')),child:Text(l.save)),
      ]);
  }
}

class ArchitectHatchDraftBar extends StatelessWidget {
  final ArchitectHatchPattern pattern;
  final List<ArchitectHatchPattern> customPatterns;
  final List<ArchitectLineStyle> lineStyles;
  final int pointCount;
  final ValueChanged<ArchitectHatchPattern> onChanged;
  final VoidCallback onUndo, onFinish, onCancel;
  final bool automatic;
  final ValueChanged<bool>? onAutomaticChanged;
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
    this.automatic = false,
    this.onAutomaticChanged,
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
            if (onAutomaticChanged != null) ...[
              IconButton(
                key: const ValueKey('hatch-mode-auto'),
                tooltip: l.architectHatchAutoHint,
                isSelected: automatic,
                icon: const Icon(Icons.format_color_fill, size: 20),
                onPressed: () => onAutomaticChanged!(true),
              ),
              IconButton(
                key: const ValueKey('hatch-mode-manual'),
                tooltip: l.architectHatchDrawHint,
                isSelected: !automatic,
                icon: const Icon(Icons.polyline_outlined, size: 20),
                onPressed: () => onAutomaticChanged!(false),
              ),
            ],
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
                message: automatic ? l.architectHatchAutoHint : l.architectHatchDrawHint,
                child: Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    automatic ? Icons.format_color_fill : Icons.polyline_outlined,
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
