import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'architect_properties_shell.dart';
import '../services/architect_section_junctions.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_slab_assembly.dart';
import '../services/architect_element_id.dart';
import '../services/architect_slab_assemblies.dart';
import '../services/architect_slab_geometry.dart';
import 'architect_slab_labels.dart';
import 'architect_composition_controls.dart';

class ArchitectSlabLayersDialog extends StatefulWidget {
  final ValueChanged<ArchitectProject>? onPreview;
  final bool Function()? isCurrent;
  final ArchitectProject project;
  final ArchitectSlab slab;
  final bool Function(ArchitectProject) onApply;
  const ArchitectSlabLayersDialog({
    super.key,
    required this.project,
    required this.slab,
    required this.onApply,
    this.onPreview,
    this.isCurrent,
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
  bool details = false;
  SlabUsage? filter;
  String? error;
  final invalidLayers = <String>{};
  ArchitectStorey get storey => widget.project.activeStorey;
  ArchitectUnit get unit => widget.project.units;
  @override
  void initState() {
    super.initState();
    final original = ArchitectSlabAssemblies.of(widget.project, widget.slab);
    draft =
        original ??
        ArchitectSlabAssembly(
          id: ArchitectElementId.next('assembly'),
          usage: ArchitectSectionJunctions.defaultUsageForStorey(
            widget.project,
            storey,
          ),
          above: ArchitectSlabCatalog.preset(
            ArchitectSectionJunctions.defaultUsageForStorey(
              widget.project,
              storey,
            ),
          ).above,
          below: ArchitectSlabCatalog.preset(
            ArchitectSectionJunctions.defaultUsageForStorey(
              widget.project,
              storey,
            ),
          ).below,
        );
    onlyThis = true;
    direction = widget.slab.slopeDirection;
    thickness = TextEditingController(
      text: architectCompositionNumber(widget.slab.thickness, unit),
    );
    offset = TextEditingController(
      text: architectCompositionNumber(widget.slab.coreTopOffset, unit),
    );
    name = TextEditingController(text: draft.customName);
    _baseline = _fingerprint;
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final loaded = await ArchitectSlabLibrary.load();
    if (mounted) setState(() => library = loaded);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    thickness.dispose();
    offset.dispose();
    name.dispose();
    super.dispose();
  }

  double? number(String s) {
    final value = double.tryParse(s.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : null;
  }

  double distance(TextEditingController field, double original) {
    if (field.text == architectCompositionNumber(original, unit)) {
      return original;
    }
    final parsed = number(field.text);
    return parsed == null ? original : unit.fromUnit(parsed);
  }

  List<ArchitectSlabLayer> get layers => lower ? draft.below : draft.above;
  void change(List<ArchitectSlabLayer> next) => setState(() {
    draft = lower ? draft.copyWith(below: next) : draft.copyWith(above: next);
    invalidLayers.retainAll([...draft.above, ...draft.below].map((l) => l.id));
  });
  ArchitectSlabAssembly get named =>
      draft.copyWith(customName: name.text.trim());

  void load(ArchitectSlabAssembly value) => setState(() {
    invalidLayers.clear();
    final shared = widget.project.slabAssemblies.any((a) => a.id == value.id);
    if (shared) {
      draft = value;
      onlyThis = true;
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
      builder: (_) => _LayerEditor(layer: old, allowSlope: !lower, unit: unit),
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
      if (invalidLayers.isNotEmpty) {
        setState(() {
          details = false;
          lower = !draft.above.any((layer) => invalidLayers.contains(layer.id));
          error = context.l10n.architectWallInvalidThickness;
        });
        return false;
      }
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

  late String _baseline;
  Timer? _previewTimer;
  late final _instanceId = ArchitectElementId.next('assembly');
  String get _fingerprint => jsonEncode([
    named.toJson(),
    thickness.text,
    offset.text,
    direction,
    onlyThis,
  ]);
  ArchitectProject _candidate() {
    named.validate();
    final t = number(thickness.text), o = number(offset.text);
    if (t == null ||
        t <= 0 ||
        o == null ||
        (draft.hasSlope && direction == null)) {
      throw ArgumentError('Invalid slab');
    }
    return ArchitectSlabAssemblies.assign(
      widget.project,
      storey.id,
      widget.slab.id,
      named.copyWith(id: onlyThis ? _instanceId : draft.id),
      onlyThis: onlyThis,
      thickness: distance(thickness, widget.slab.thickness),
      coreTopOffset: distance(offset, widget.slab.coreTopOffset),
      direction: direction,
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && widget.onPreview != null) {
        try {
          widget.onPreview!(
            _fingerprint == _baseline ? widget.project : _candidate(),
          );
        } on ArgumentError {
          /* Incomplete input. */
        }
      }
    });
  }

  void save() {
    if (_fingerprint == _baseline) {
      Navigator.pop(context);
      return;
    }
    if (!valid()) return;
    if (widget.isCurrent?.call() == false) {
      setState(() => error = context.l10n.propertiesStale);
      return;
    }
    try {
      final project = _candidate();
      if (widget.onApply(project)) Navigator.pop(context);
    } on ArgumentError {
      setState(() => error = context.l10n.slabInvalid);
    }
  }

  Future<void> choosePreset() async {
    final l = context.l10n;
    final choices = <String, ArchitectSlabAssembly>{
      for (final a in ArchitectSlabCatalog.presets) a.id: a,
      for (final a in library) a.id: a,
      for (final a in widget.project.slabAssemblies) a.id: a,
    }.values;
    final chosen = await showArchitectCompositionPicker<ArchitectSlabAssembly>(
      context,
      title: l.slabPreset,
      selectedId: draft.id,
      preferenceKey: 'architect_slab_catalog_favorites',
      choices: [
        for (final a in choices)
          if (filter == null || a.usage == filter)
            ArchitectCompositionChoice(
              id: a.id,
              label: a.label(l),
              detail:
                  '${a.usage.label(l)} · ${[...a.above, ...a.below].map((layer) => layer.label(l)).join(' · ')}',
              value: a,
            ),
      ],
    );
    if (chosen != null && mounted) load(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final previewSlab = widget.slab.copyWith(
      assemblyId: draft.id,
      thickness: distance(thickness, widget.slab.thickness),
      coreTopOffset: distance(offset, widget.slab.coreTopOffset),
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
    final sharedCount = widget.project.storeys
        .expand((s) => s.slabs)
        .where((slab) => slab.assemblyId == draft.id)
        .length;
    return ArchitectPropertiesShell(
      title: l.architectToolSlab,
      subtitle: storey.name,
      initiallyExpanded: true,
      onSave: save,
      isDirty: () => _fingerprint != _baseline,
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArchitectCompositionHeader(
              key: const ValueKey('slab-composition-header'),
              title: named.label(l),
              onChoose: choosePreset,
              summary:
                  '${l.slabCore}: ${architectCompositionLength(previewSlab.thickness, unit)} · '
                  '${l.compositionTotal}: ${architectCompositionLength(previewSlab.thickness + draft.upperThickness + draft.lowerThickness, unit)}',
              scope: sharedCount > 0
                  ? Tooltip(
                      message: l.slabSharedHelp,
                      child: DropdownButtonFormField<bool>(
                        key: ValueKey('slab-edit-scope-$onlyThis'),
                        initialValue: onlyThis,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          DropdownMenuItem(
                            value: true,
                            child: Text(l.slabOnlyThis),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text(l.compositionScopeType(sharedCount)),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => onlyThis = value ?? true),
                      ),
                    )
                  : Text(
                      l.slabOnlyThis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('slab-composition-tab'),
                  label: Text(l.compositionTab),
                  selected: !details,
                  onSelected: (_) => setState(() => details = false),
                ),
                ChoiceChip(
                  key: const ValueKey('slab-details-tab'),
                  label: Text(l.compositionDetails),
                  selected: details,
                  onSelected: (_) => setState(() => details = true),
                ),
              ],
            ),
            if (details) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SlabUsage>(
                      key: ValueKey('slab-filter-${filter?.name}'),
                      initialValue: filter,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.slabAllUsages),
                      items: [
                        for (final u in SlabUsage.values)
                          DropdownMenuItem(value: u, child: Text(u.label(l))),
                      ],
                      onChanged: (u) => setState(() => filter = u),
                    ),
                  ),
                  IconButton(
                    tooltip: l.slabAllUsages,
                    onPressed: () => setState(() => filter = null),
                    icon: const AppIcon(AppIconId.filterOff),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.roofUiAssembly,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.propertiesMore,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'library',
                        child: AppMenuLabel(
                          icon: AppIconId.save,
                          child: Text(l.slabSaveLibrary),
                        ),
                      ),
                      if (library.any((a) => a.id == draft.id))
                        PopupMenuItem(
                          value: 'delete_library',
                          child: AppMenuLabel(
                            icon: AppIconId.delete,
                            child: Text(l.slabDeleteLibrary),
                          ),
                        ),
                      PopupMenuItem(
                        value: 'new',
                        child: AppMenuLabel(
                          icon: AppIconId.add,
                          child: Text(l.slabNewType),
                        ),
                      ),
                    ],
                    onSelected: (action) async {
                      if (action == 'new') {
                        setState(() {
                          onlyThis = true;
                          draft = named.copyWith(
                            id: ArchitectElementId.next('assembly'),
                          );
                        });
                        return;
                      }
                      if (action == 'delete_library') {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => architectAlertDialog(
                            title: Text(l.slabDeleteLibrary),
                            content: Text(
                              l.slabDeleteConfirm(
                                draft.customName.isNotEmpty
                                    ? draft.customName
                                    : draft.usage.label(l),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l.delete),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ArchitectSlabLibrary.delete(draft.id);
                          await _loadLibrary();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(l.slabLibraryDeleted)),
                          );
                        }
                        return;
                      }
                      if (!valid()) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await ArchitectSlabLibrary.save(named);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? l.slabLibrarySaved : l.slabLibraryFailed,
                          ),
                        ),
                      );
                      _loadLibrary();
                    },
                  ),
                ],
              ),
              TextField(
                onChanged: (_) => setState(() {}),
                controller: name,
                decoration: InputDecoration(
                  labelText: l.architectPropertyName,
                  hintText: draft.usage.label(l),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
              TextField(
                key: const ValueKey('slab-core-offset'),
                controller: offset,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: l.slabCoreOffset,
                  suffixText: unit.symbol,
                ),
                onChanged: (_) => setState(() {}),
              ),
              Text(
                '${l.slabFinishedLevel}: ${surfaces.first.topAt(p).toStringAsFixed(3)} m · '
                '${l.slabBottomLevel}: ${surfaces.last.bottomAt(p).toStringAsFixed(3)} m',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!details) ...[
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
                        labelText: l.slabCore,
                        suffixText: unit.symbol,
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
                              (Path()..addPolygon(previewSlab.polygon, true))
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
                                                Offset(c.maxWidth / 2, 57.5)) /
                                            scale;
                                    setState(() {
                                      if (first == null) {
                                        first = point;
                                      } else if ((point - first!).distance >
                                          .001) {
                                        final v = point - first!;
                                        direction = math.atan2(v.dy, v.dx);
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
              if (draft.hasSlope)
                TextButton.icon(
                  onPressed: () => setState(() {
                    setDirection = true;
                    first = null;
                  }),
                  icon: const AppIcon(AppIconId.diagonalDown),
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
                      icon: const AppIcon(AppIconId.hatch),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'tile',
                          child: AppMenuLabel(
                            icon: AppIconId.grid,
                            child: Text(l.slabFinishTile),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'parquet',
                          child: AppMenuLabel(
                            icon: AppIconId.hatch,
                            child: Text(l.slabFinishParquet),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'wet',
                          child: AppMenuLabel(
                            icon: AppIconId.water,
                            child: Text(l.slabFinishWet),
                          ),
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
                icon: const AppIcon(AppIconId.add),
                label: Text(l.slabAddLayer),
              ),
              if (draft.usage == SlabUsage.ground ||
                  draft.usage == SlabUsage.foundation)
                Text(
                  l.slabNaturalGround,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          key: const ValueKey('slab-layers-save'),
          onPressed: save,
          child: Text(l.save),
        ),
      ],
    );
  }

  Widget _row(int index) {
    final l = context.l10n, layer = layers[index];
    return ArchitectCompositionLayerRow(
      key: ValueKey('slab-layer-${layer.id}'),
      marker: Container(
        width: 10,
        height: 24,
        color: ArchitectSlabGeometry.materialColor(layer.material),
      ),
      title: layer.label(l),
      thickness: architectCompositionLength(layer.thickness, unit),
      thicknessEditor: ArchitectCompositionThicknessField(
        key: ValueKey('slab-layer-thickness-${layer.id}'),
        value: layer.thickness,
        unit: unit,
        onValidityChanged: (valid) {
          if (valid) {
            invalidLayers.remove(layer.id);
          } else {
            invalidLayers.add(layer.id);
          }
        },
        onChanged: (value) => change([
          for (var i = 0; i < layers.length; i++)
            i == index ? layers[i].copyWith(thickness: value) : layers[i],
        ]),
      ),
      detail:
          '${layer.role.label(l)}${layer.slopePercent > 0 ? ' · ${layer.slopePercent}%' : ''}',
      onEdit: () => editLayer(index),
      actions: PopupMenuButton<String>(
        tooltip: l.wallLayerDetails,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'up',
            enabled: index > 0,
            child: AppMenuLabel(icon: AppIconId.up, child: Text(l.slabMoveUp)),
          ),
          PopupMenuItem(
            value: 'down',
            enabled: index < layers.length - 1,
            child: AppMenuLabel(
              icon: AppIconId.down,
              child: Text(l.slabMoveDown),
            ),
          ),
          PopupMenuItem(
            value: 'copy',
            child: AppMenuLabel(
              icon: AppIconId.duplicate,
              child: Text(l.slabDuplicate),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: AppMenuLabel(icon: AppIconId.delete, child: Text(l.delete)),
          ),
        ],
        onSelected: (v) {
          final next = [...layers];
          if (v == 'delete') {
            invalidLayers.remove(layer.id);
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
  final ArchitectUnit unit;
  const _LayerEditor({
    required this.layer,
    required this.allowSlope,
    required this.unit,
  });
  @override
  State<_LayerEditor> createState() => _LayerEditorState();
}

class _LayerEditorState extends State<_LayerEditor> {
  final form = GlobalKey<FormState>();
  late SlabMaterial material = widget.layer.material;
  late SlabLayerRole role = widget.layer.role;
  late final name = TextEditingController(text: widget.layer.customName);
  late final thickness = TextEditingController(
    text: architectCompositionNumber(widget.layer.thickness, widget.unit),
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

    return architectAlertDialog(
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
                  decoration: InputDecoration(
                    labelText: l.architectPropertyThickness,
                    suffixText: widget.unit.symbol,
                  ),
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
                    thickness.text ==
                        architectCompositionNumber(
                          widget.layer.thickness,
                          widget.unit,
                        )
                    ? widget.layer.thickness
                    : widget.unit.fromUnit(
                        double.parse(thickness.text.replaceAll(',', '.')),
                      ),
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
