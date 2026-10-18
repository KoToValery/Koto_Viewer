import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_slab_assembly.dart';
import '../services/architect_element_id.dart';
import '../services/architect_slab_assemblies.dart';
import '../services/architect_slab_geometry.dart';
import 'architect_slab_labels.dart';

class ArchitectSlabLayersDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectSlab slab;
  final bool Function(ArchitectProject) onApply;
  const ArchitectSlabLayersDialog({
    super.key,
    required this.project,
    required this.slab,
    required this.onApply,
  });
  @override
  State<ArchitectSlabLayersDialog> createState() => _SlabLayersState();
}

class _SlabLayersState extends State<ArchitectSlabLayersDialog> {
  late ArchitectSlabAssembly draft;
  late final TextEditingController thickness, offset, name;
  List<ArchitectSlabAssembly> library = [];
  late bool onlyThis;
  double? direction;
  Offset? first;
  bool setDirection = false;
  bool lower = false;
  SlabUsage? filter;
  String? error;
  ArchitectStorey get storey => widget.project.activeStorey;
  @override
  void initState() {
    super.initState();
    final original = ArchitectSlabAssemblies.of(widget.project, widget.slab);
    draft =
        original ??
        ArchitectSlabAssembly(
          id: ArchitectElementId.next('assembly'),
          usage: SlabUsage.intermediate,
        );
    onlyThis = original == null;
    direction = widget.slab.slopeDirection;
    thickness = TextEditingController(text: '${widget.slab.thickness * 1000}');
    offset = TextEditingController(text: '${widget.slab.coreTopOffset * 1000}');
    name = TextEditingController(text: draft.customName);
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final loaded = await ArchitectSlabLibrary.load();
    if (mounted) setState(() => library = loaded);
  }

  @override
  void dispose() {
    thickness.dispose();
    offset.dispose();
    name.dispose();
    super.dispose();
  }

  double? number(String s) {
    final value = double.tryParse(s.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  List<ArchitectSlabLayer> get layers => lower ? draft.below : draft.above;
  void change(List<ArchitectSlabLayer> next) => setState(() {
    draft = lower ? draft.copyWith(below: next) : draft.copyWith(above: next);
  });
  ArchitectSlabAssembly get named =>
      draft.copyWith(customName: name.text.trim());

  void load(ArchitectSlabAssembly value) => setState(() {
    final shared = widget.project.slabAssemblies.any((a) => a.id == value.id);
    if (shared) {
      draft = value;
      onlyThis = false;
    } else {
      draft = value.copyWith(
        id: onlyThis ? ArchitectElementId.next('assembly') : draft.id,
      );
    }
    name.text = draft.customName;
    error = null;
    first = null;
    setDirection = draft.hasSlope && direction == null;
  });

  Future<void> editLayer([int? index]) async {
    final old = index == null
        ? ArchitectSlabLayer(
            id: ArchitectElementId.next('layer'),
            material: SlabMaterial.screed,
            role: SlabLayerRole.screed,
            thickness: .01,
          )
        : layers[index];
    final result = await showDialog<ArchitectSlabLayer>(
      context: context,
      builder: (_) => _LayerEditor(layer: old, allowSlope: !lower),
    );
    if (!mounted || result == null) return;
    final next = [...layers];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    change(next);
  }

  bool valid() {
    try {
      named.validate();
      if (number(thickness.text) == null ||
          number(thickness.text)! <= 0 ||
          !number(thickness.text)!.isFinite ||
          number(offset.text) == null ||
          !number(offset.text)!.isFinite) {
        throw ArgumentError();
      }
      if (draft.hasSlope && direction == null) {
        setState(() => error = context.l10n.slabDirectionRequired);
        return false;
      }
      return true;
    } on ArgumentError {
      setState(() => error = context.l10n.slabInvalid);
      return false;
    }
  }

  void save() {
    if (!valid()) return;
    final a = named.copyWith(
      id: onlyThis ? ArchitectElementId.next('assembly') : draft.id,
    );
    try {
      final project = ArchitectSlabAssemblies.assign(
        widget.project,
        storey.id,
        widget.slab.id,
        a,
        onlyThis: onlyThis,
        thickness: number(thickness.text)! / 1000,
        coreTopOffset: number(offset.text)! / 1000,
        direction: direction,
      );
      if (widget.onApply(project)) Navigator.pop(context);
    } on ArgumentError {
      setState(() => error = context.l10n.slabInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final previewSlab = widget.slab.copyWith(
      assemblyId: draft.id,
      thickness:
          (number(thickness.text) ?? widget.slab.thickness * 1000) / 1000,
      coreTopOffset:
          (number(offset.text) ?? widget.slab.coreTopOffset * 1000) / 1000,
      slopeDirection: direction,
    );
    final previewProject = widget.project.copyWith(
      slabAssemblies: [
        ...widget.project.slabAssemblies.where((a) => a.id != draft.id),
        draft,
      ],
    );
    final surfaces = ArchitectSlabGeometry.surfaces(
      previewProject,
      storey,
      previewSlab,
    );
    final p = previewSlab.centroid;
    final options = [
      ...ArchitectSlabCatalog.presets,
      ...widget.project.slabAssemblies,
      ...library,
    ].where((a) => filter == null || a.usage == filter).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.slabLayers,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.slabPresetHelp,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        content: Text(l.slabPresetHelp),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.close),
                          ),
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<SlabUsage>(
                            key: ValueKey('slab-filter-${filter?.name}'),
                            initialValue: filter,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.slabAllUsages,
                            ),
                            items: [
                              for (final u in SlabUsage.values)
                                DropdownMenuItem(
                                  value: u,
                                  child: Text(u.label(l)),
                                ),
                            ],
                            onChanged: (u) => setState(() => filter = u),
                          ),
                        ),
                        IconButton(
                          tooltip: l.slabAllUsages,
                          onPressed: () => setState(() => filter = null),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'slab-presets-${filter?.name}-${library.length}',
                      ),
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.slabPreset),
                      items: [
                        for (var i = 0; i < options.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              options[i].label(l),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (i) {
                        if (i != null) load(options[i]);
                      },
                    ),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: l.architectPropertyName,
                        hintText: draft.usage.label(l),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                    if (widget.slab.assemblyId != null ||
                        widget.project.slabAssemblies.any(
                          (a) => a.id == draft.id,
                        )) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(l.slabOnlyThis),
                        value: onlyThis,
                        onChanged: (v) => setState(() => onlyThis = v),
                      ),
                      if (!onlyThis)
                        Text(
                          l.slabSharedHelp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('slab-core-thickness'),
                            controller: thickness,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '${l.slabCore} (mm)',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('slab-core-offset'),
                            controller: offset,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '${l.slabCoreOffset} (mm)',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 115,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _StackPreview(surfaces, p),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (_, c) {
                                final bounds =
                                    (Path()..addPolygon(
                                          previewSlab.polygon,
                                          true,
                                        ))
                                        .getBounds()
                                        .inflate(.3);
                                final scale = math.min(
                                  c.maxWidth / math.max(bounds.width, .1),
                                  115 / math.max(bounds.height, .1),
                                );
                                return GestureDetector(
                                  key: const ValueKey('slab-slope-plan'),
                                  onTapUp: !setDirection
                                      ? null
                                      : (d) {
                                          final point =
                                              bounds.center +
                                              (d.localPosition -
                                                      Offset(
                                                        c.maxWidth / 2,
                                                        57.5,
                                                      )) /
                                                  scale;
                                          setState(() {
                                            if (first == null) {
                                              first = point;
                                            } else if ((point - first!)
                                                    .distance >
                                                .001) {
                                              final v = point - first!;
                                              direction = math.atan2(
                                                v.dy,
                                                v.dx,
                                              );
                                              first = null;
                                              setDirection = false;
                                              error = null;
                                            }
                                          });
                                        },
                                  child: CustomPaint(
                                    size: Size(c.maxWidth, 115),
                                    painter: _SlabPlanPreview(
                                      previewSlab,
                                      bounds.center,
                                      scale,
                                      first,
                                      direction,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${l.slabAbove}: ${widget.project.formatLength(surfaces.first.topAt(p) - storey.elevation - previewSlab.coreTopOffset)} · '
                      '${l.slabBelow}: ${widget.project.formatLength(draft.lowerThickness)}',
                    ),
                    Text(
                      '${l.slabFinishedLevel}: ${surfaces.first.topAt(p).toStringAsFixed(3)} m · '
                      '${l.slabBottomLevel}: ${surfaces.last.bottomAt(p).toStringAsFixed(3)} m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (draft.hasSlope)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          setDirection = true;
                          first = null;
                        }),
                        icon: const Icon(Icons.south_east),
                        label: Text(
                          setDirection ? l.slabDirectionHelp : l.slabDirection,
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(l.slabAbove),
                          selected: !lower,
                          onSelected: (_) => setState(() => lower = false),
                        ),
                        ChoiceChip(
                          label: Text(l.slabBelow),
                          selected: lower,
                          onSelected: (_) => setState(() => lower = true),
                        ),
                        if (!lower)
                          PopupMenuButton<String>(
                            tooltip: l.slabFinish,
                            icon: const Icon(Icons.texture),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'tile',
                                child: Text(l.slabFinishTile),
                              ),
                              PopupMenuItem(
                                value: 'parquet',
                                child: Text(l.slabFinishParquet),
                              ),
                              PopupMenuItem(
                                value: 'wet',
                                child: Text(l.slabFinishWet),
                              ),
                            ],
                            onSelected: (v) => change([
                              ...ArchitectSlabCatalog.finish(
                                parquet: v == 'parquet',
                                wet: v == 'wet',
                              ),
                              ...layers.where(
                                (x) =>
                                    !x.finishPackage &&
                                    x.role != SlabLayerRole.finish,
                              ),
                            ]),
                          ),
                      ],
                    ),
                    for (var i = 0; i < layers.length; i++) _row(i),
                    TextButton.icon(
                      key: const ValueKey('slab-add-layer'),
                      onPressed: editLayer,
                      icon: const Icon(Icons.add),
                      label: Text(l.slabAddLayer),
                    ),
                    if (draft.usage == SlabUsage.ground ||
                        draft.usage == SlabUsage.foundation)
                      Text(
                        l.slabNaturalGround,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      if (!valid()) return;
                      final ok = await ArchitectSlabLibrary.save(named);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? l.slabLibrarySaved : l.slabLibraryFailed,
                          ),
                        ),
                      );
                      _loadLibrary();
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l.slabSaveLibrary),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      onlyThis = true;
                      draft = named.copyWith(
                        id: ArchitectElementId.next('assembly'),
                      );
                    }),
                    child: Text(l.slabNewType),
                  ),
                  FilledButton(
                    key: const ValueKey('slab-layers-save'),
                    onPressed: save,
                    child: Text(l.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(int index) {
    final l = context.l10n, layer = layers[index];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 10,
        height: 24,
        color: ArchitectSlabGeometry.materialColor(layer.material),
      ),
      title: Text(layer.label(l)),
      subtitle: Text(
        '${(layer.thickness * 1000).toStringAsFixed(1)} mm'
        '${layer.slopePercent > 0 ? ' · ${layer.slopePercent}%' : ''}',
      ),
      onTap: () => editLayer(index),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'up',
            enabled: index > 0,
            child: Text(l.slabMoveUp),
          ),
          PopupMenuItem(
            value: 'down',
            enabled: index < layers.length - 1,
            child: Text(l.slabMoveDown),
          ),
          PopupMenuItem(value: 'copy', child: Text(l.slabDuplicate)),
          PopupMenuItem(value: 'delete', child: Text(l.delete)),
        ],
        onSelected: (v) {
          final next = [...layers];
          if (v == 'delete') {
            next.removeAt(index);
          } else if (v == 'copy') {
            next.insert(
              index + 1,
              layer.copyWith(id: ArchitectElementId.next('layer')),
            );
          } else {
            final target = index + (v == 'up' ? -1 : 1);
            next[index] = next[target];
            next[target] = layer;
          }
          change(next);
        },
      ),
    );
  }
}

class _LayerEditor extends StatefulWidget {
  final ArchitectSlabLayer layer;
  final bool allowSlope;
  const _LayerEditor({required this.layer, required this.allowSlope});
  @override
  State<_LayerEditor> createState() => _LayerEditorState();
}

class _LayerEditorState extends State<_LayerEditor> {
  final form = GlobalKey<FormState>();
  late SlabMaterial material = widget.layer.material;
  late SlabLayerRole role = widget.layer.role;
  late final name = TextEditingController(text: widget.layer.customName);
  late final thickness = TextEditingController(
    text: '${widget.layer.thickness * 1000}',
  );
  late final slope = TextEditingController(
    text: '${widget.layer.slopePercent}',
  );
  @override
  void dispose() {
    name.dispose();
    thickness.dispose();
    slope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String? validate(String? v, {bool zero = false}) {
      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
      return n != null && n.isFinite && (zero ? n >= 0 && n <= 100 : n > 0)
          ? null
          : l.slabInvalid;
    }

    return AlertDialog(
      title: Text(l.slabEditLayer),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SlabMaterial>(
                  initialValue: material,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.slabMaterial),
                  items: [
                    for (final m in SlabMaterial.values.where(
                      (m) => m != SlabMaterial.concrete,
                    ))
                      DropdownMenuItem(value: m, child: Text(m.label(l))),
                  ],
                  onChanged: (m) {
                    if (m != null) setState(() => material = m);
                  },
                ),
                DropdownButtonFormField<SlabLayerRole>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.slabRole),
                  items: [
                    for (final r in SlabLayerRole.values.where(
                      (r) => widget.allowSlope || r != SlabLayerRole.slope,
                    ))
                      DropdownMenuItem(value: r, child: Text(r.label(l))),
                  ],
                  onChanged: (r) {
                    if (r != null) {
                      setState(() {
                        role = r;
                        if (r == SlabLayerRole.slope && slope.text == '0.0') {
                          slope.text = '2';
                        }
                      });
                    }
                  },
                ),
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: l.architectPropertyName,
                  ),
                  validator: (v) =>
                      material == SlabMaterial.custom &&
                          (v ?? '').trim().isEmpty
                      ? l.slabInvalid
                      : null,
                ),
                TextFormField(
                  controller: thickness,
                  decoration: InputDecoration(labelText: l.slabThicknessMm),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => validate(v),
                ),
                if (widget.allowSlope)
                  TextFormField(
                    controller: slope,
                    decoration: InputDecoration(labelText: l.slabSlope),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => validate(v, zero: true),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              context,
              widget.layer.copyWith(
                material: material,
                role: role,
                customName: name.text.trim(),
                thickness:
                    double.parse(thickness.text.replaceAll(',', '.')) / 1000,
                slopePercent: widget.allowSlope
                    ? double.parse(slope.text.replaceAll(',', '.'))
                    : 0,
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _StackPreview extends CustomPainter {
  final List<SlabLayerSurface> surfaces;
  final Offset point;
  _StackPreview(this.surfaces, this.point);
  @override
  void paint(Canvas canvas, Size size) {
    final weights = surfaces
        .map((s) => math.max(s.thicknessAt(point), .008))
        .toList();
    final sum = weights.fold(0.0, (a, b) => a + b);
    var y = 4.0;
    for (var i = 0; i < surfaces.length; i++) {
      final height = weights[i] / sum * (size.height - 8);
      final rect = Rect.fromLTWH(8, y, size.width - 20, height);
      canvas.drawRect(
        rect,
        Paint()
          ..color = ArchitectSlabGeometry.materialColor(
            surfaces[i].layer.material,
          ),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.blueGrey
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5,
      );
      y += height;
    }
  }

  @override
  bool shouldRepaint(covariant _StackPreview oldDelegate) => true;
}

class _SlabPlanPreview extends CustomPainter {
  final ArchitectSlab slab;
  final Offset centre;
  final double scale;
  final Offset? first;
  final double? direction;
  _SlabPlanPreview(
    this.slab,
    this.centre,
    this.scale,
    this.first,
    this.direction,
  );
  @override
  void paint(Canvas canvas, Size size) {
    Offset p(Offset v) =>
        Offset(size.width / 2, size.height / 2) + (v - centre) * scale;
    final path = Path()..addPolygon(slab.polygon.map(p).toList(), true);
    canvas.drawPath(path, Paint()..color = const Color(0xFFCFD8DC));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blueGrey
        ..style = PaintingStyle.stroke,
    );
    if (first != null) {
      canvas.drawCircle(p(first!), 4, Paint()..color = Colors.orange);
    }
    if (direction != null) {
      final u = Offset(math.cos(direction!), math.sin(direction!));
      final c = p(slab.centroid), a = c - u * 25, b = c + u * 25;
      final paint = Paint()
        ..color = Colors.deepOrange
        ..strokeWidth = 2;
      canvas.drawLine(a, b, paint);
      final n = Offset(-u.dy, u.dx);
      canvas.drawLine(b, b - u * 8 + n * 5, paint);
      canvas.drawLine(b, b - u * 8 - n * 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SlabPlanPreview oldDelegate) => true;
}
