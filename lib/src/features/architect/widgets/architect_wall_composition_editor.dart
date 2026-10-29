import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_element_id.dart';
import 'architect_material_layer_label.dart';
import 'architect_wall_type_label.dart';
import 'architect_wall_type_picker.dart';
import 'architect_wall_layer_preview.dart';
import 'architect_wall_system_fields.dart';
import 'architect_wall_system_preview.dart';

class _LayerDraft {
  ArchitectMaterialLayer layer;
  final TextEditingController input;
  _LayerDraft(this.layer, ArchitectUnit unit)
    : input = TextEditingController(
        text: _number(unit.toUnit(layer.thickness)),
      );
  void dispose() => input.dispose();
}

/// Keep each construction's inputs when trying another system in this dialog.
class _SystemDraft {
  final ArchitectWallType source;
  final ArchitectWallSystem system;
  final List<ArchitectMaterialLayer> layers;
  final List<String> dimensions;
  final String name;
  final ArchitectWallLocation location;
  _SystemDraft(
    this.source,
    this.system,
    this.layers,
    this.dimensions,
    this.name,
    this.location,
  );
}

String _number(double value) =>
    ArchitectUnit.trimZeros(value.toStringAsFixed(6));
double? _parse(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

class ArchitectWallCompositionEditor extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectWallType type;
  final int? typeUseCount;
  final bool requireName, allowTypeSelection, isNewType;
  final ArchitectWallPlinth? plinth;
  final List<ArchitectWallPlinth> plinths;
  final bool Function(ArchitectWallType, ArchitectWallPlinthPatch?, bool)
  onApply;
  const ArchitectWallCompositionEditor({
    super.key,
    required this.project,
    required this.type,
    required this.onApply,
    this.typeUseCount,
    this.plinth,
    this.plinths = const [],
    this.requireName = false,
    this.allowTypeSelection = false,
    this.isNewType = false,
  });
  @override
  State<ArchitectWallCompositionEditor> createState() => _EditorState();
}

class _EditorState extends State<ArchitectWallCompositionEditor> {
  final form = GlobalKey<FormState>();
  final retiredInputs = <TextEditingController>[];
  late final name = TextEditingController(
    text: widget.type.isFactoryPreset ? '' : widget.type.name,
  );
  late final drafts = [
    for (final layer in widget.type.resolvedLayers)
      _LayerDraft(layer, widget.project.units),
  ];
  late ArchitectWallLocation location = widget.type.resolvedLocation;
  late bool saveToCatalog = widget.type.isCatalogType;
  late ArchitectWallSystem system = widget.type.system;
  late ParapetFinish parapetFinish =
      widget.type.parapetFinish ?? ParapetFinish.cap;
  late final defaultHeight = TextEditingController(
    text: _number(
      widget.project.units.toUnit(widget.type.customHeight ?? 1.05),
    ),
  );
  bool compositionChanged = false, detailsChanged = false;
  ArchitectWallType? pickedType;
  final systemDrafts = <ArchitectWallSystemKind, _SystemDraft>{};
  String? expandedLayer;
  String? error;
  final editedRegionFields = <String>{};
  List<ArchitectWallPlinth> get regions => widget.plinths.isEmpty
      ? [if (widget.plinth != null) widget.plinth!]
      : widget.plinths;
  bool mixed<T>(T Function(ArchitectWallPlinth) field) =>
      regions.map(field).toSet().length > 1;
  late bool? plinthEnabled = mixed((p) => p.enabled)
      ? null
      : widget.plinth?.enabled ?? false;
  late final plinthHeight = TextEditingController(
    text: mixed((p) => p.height)
        ? ''
        : _number(widget.project.units.toUnit(widget.plinth?.height ?? .5)),
  );
  late final plinthBase = TextEditingController(
    text: mixed((p) => p.baseElevation)
        ? ''
        : _number(
            widget.plinth?.baseElevation ??
                widget.project.activeStorey.elevation,
          ),
  );
  late ArchitectMaterial? plinthFinish = mixed((p) => p.finish)
      ? null
      : widget.plinth?.finish ?? ArchitectMaterial.render;
  ArchitectWallType get source => pickedType ?? widget.type;
  ArchitectWallType get currentType => source.copyWith(
    system: system,
    layers: layers,
    name: name.text.trim(),
    location: location,
  );

  void switchSystem(ArchitectWallSystemKind kind) {
    systemDrafts[system.kind] = _SystemDraft(
      source,
      system,
      [for (final d in drafts) d.layer],
      [for (final d in drafts) d.input.text],
      name.text,
      location,
    );
    final previous = systemDrafts[kind];
    final template =
        previous?.source ??
        ArchitectWallType.standardCatalog(
          includeSpecial: true,
        ).firstWhere((t) => t.system.kind == kind);
    for (final d in drafts) {
      retiredInputs.add(d.input);
    }
    pickedType = template;
    system = previous?.system ?? template.system;
    drafts
      ..clear()
      ..addAll([
        for (final layer in previous?.layers ?? template.resolvedLayers)
          _LayerDraft(layer, widget.project.units),
      ]);
    if (previous != null) {
      for (var i = 0; i < drafts.length; i++) {
        drafts[i].input.text = previous.dimensions[i];
      }
    }
    name.text = previous?.name ?? '';
    location = previous?.location ?? template.resolvedLocation;
    expandedLayer = null;
    changed();
  }

  double get total =>
      system.additionalDepth +
      drafts.fold<double>(
        0,
        (v, d) => v + widget.project.units.fromUnit(_parse(d.input.text) ?? 0),
      );
  bool invalidNumber(_LayerDraft d) =>
      _parse(d.input.text) == null || _parse(d.input.text)! <= 0;
  List<ArchitectMaterialLayer> get layers => [
    for (final d in drafts)
      d.layer.copyWith(
        thickness: widget.project.units.fromUnit(_parse(d.input.text) ?? 0),
      ),
  ];
  String? get layerError {
    if (drafts.any(invalidNumber)) {
      return context.l10n.architectWallInvalidThickness;
    }
    if (drafts.length > 20) return context.l10n.wallLayerLimit;
    try {
      ArchitectMaterialLayer.validate(layers);
      system.validate(total);
      if (system.isLog &&
          (layers.length != 1 ||
              layers.first.material != ArchitectMaterial.timber)) {
        return context.l10n.wallSystemInvalid;
      }
      if (system.isFrame &&
          system.insulationDepth >
              layers
                  .where((l) => l.role == ArchitectLayerRole.core)
                  .fold<double>(0, (v, l) => v + l.thickness)) {
        return context.l10n.wallSystemInvalid;
      }
      return null;
    } on ArgumentError {
      return system.isSpecial
          ? context.l10n.wallSystemInvalid
          : context.l10n.wallLayerCoreError;
    }
  }

  void changed() {
    compositionChanged = true;
    detailsChanged = true;
    error = null;
  }

  @override
  void dispose() {
    name.dispose();
    defaultHeight.dispose();
    plinthHeight.dispose();
    plinthBase.dispose();
    for (final d in drafts) {
      d.dispose();
    }
    for (final input in retiredInputs) {
      input.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (widget.requireName && name.text.trim().isEmpty) {
      setState(() => error = context.l10n.wallCompositionName);
      return;
    }
    if (source.isParapet &&
        widget.typeUseCount != null &&
        (_parse(defaultHeight.text) == null ||
            _parse(defaultHeight.text)! <= 0)) {
      setState(() => error = context.l10n.wallInvalidHeight);
      return;
    }
    if (layerError != null) {
      setState(() => error = layerError);
      return;
    }
    try {
      final activePlinth =
          plinthEnabled != false && location == ArchitectWallLocation.exterior;
      if (activePlinth &&
          ((editedRegionFields.contains('height') &&
                  (_parse(plinthHeight.text) == null ||
                      _parse(plinthHeight.text)! <= 0)) ||
              (editedRegionFields.contains('base') &&
                  _parse(plinthBase.text) == null))) {
        throw ArgumentError('Invalid plinth field');
      }
      final region = widget.plinth == null
          ? null
          : ArchitectWallPlinthPatch(
              enabled: editedRegionFields.contains('enabled')
                  ? plinthEnabled
                  : null,
              height:
                  editedRegionFields.contains('height') &&
                      _parse(plinthHeight.text) != null &&
                      _parse(plinthHeight.text)! > 0
                  ? widget.project.units.fromUnit(_parse(plinthHeight.text)!)
                  : null,
              baseElevation: editedRegionFields.contains('base')
                  ? _parse(plinthBase.text)
                  : null,
              finish: editedRegionFields.contains('finish')
                  ? plinthFinish
                  : null,
            );
      if (region != null) {
        for (final value in regions) {
          region.apply(value);
        }
      }
      final type = source.copyWith(
        system: system,
        id: pickedType != null && detailsChanged ? widget.type.id : source.id,
        layers: layers,
        location: location,
        usage: source.isParapet
            ? WallUsage.parapet
            : location == ArchitectWallLocation.exterior
            ? WallUsage.exterior
            : WallUsage.interior,
        name: name.text.trim(),
        labelId: source.labelId ?? source.id,
        isCatalogType: widget.typeUseCount != null || !widget.allowTypeSelection
            ? source.isCatalogType
            : pickedType != null && !detailsChanged
            ? source.isCatalogType
            : saveToCatalog,
        parapetFinish: source.isParapet ? parapetFinish : null,
        customHeight: source.isParapet && widget.typeUseCount != null
            ? widget.project.units.fromUnit(_parse(defaultHeight.text)!)
            : null,
      );
      if (widget.onApply(type, region, compositionChanged)) {
        Navigator.pop(context);
      }
    } on ArgumentError {
      setState(() => error = context.l10n.wallLayerInvalid);
    }
  }

  Future<void> pickType() async {
    final types = {
      for (final t in ArchitectWallType.standardCatalog(includeSpecial: true))
        if (t.system.kind == system.kind && t.isParapet == source.isParapet)
          t.id: t,
      for (final t in widget.project.wallTypes)
        if (t.isCatalogType &&
            t.system.kind == system.kind &&
            t.isParapet == source.isParapet)
          t.id: t,
    }.values.toList();
    if (types.isEmpty) return;
    final result = await showArchitectWallTypePicker(
      context,
      types: types,
      activeType: source,
      unit: widget.project.units,
      projectId: widget.project.id,
    );
    if (result == null || !mounted) return;
    setState(() {
      pickedType = result.type;
      system = result.type.system;
      compositionChanged = true;
      detailsChanged = false;
      error = null;
      for (final d in drafts) {
        retiredInputs.add(d.input);
      }
      drafts
        ..clear()
        ..addAll([
          for (final l in result.type.resolvedLayers)
            _LayerDraft(l, widget.project.units),
        ]);
      name.text = result.type.isFactoryPreset ? '' : result.type.name;
      location = result.type.resolvedLocation;
      parapetFinish = result.type.parapetFinish ?? ParapetFinish.cap;
      expandedLayer = null;
    });
  }

  Future<void> addLayer() async {
    if (drafts.length >= 20) {
      setState(() => error = context.l10n.wallLayerLimit);
      return;
    }
    final l = context.l10n,
        unit = widget.project.units,
        addForm = GlobalKey<FormState>();
    var material = ArchitectMaterial.plaster;
    var position = expandedLayer == null
        ? drafts.length
        : drafts.indexWhere((d) => d.layer.id == expandedLayer) + 1;
    final input = TextEditingController(text: _number(unit.toUnit(.015)));
    retiredInputs.add(input);
    final result = await showDialog<(ArchitectMaterialLayer, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(l.wallLayerAdd),
          content: SingleChildScrollView(
            child: Form(
              key: addForm,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    key: const ValueKey('wall-layer-position'),
                    initialValue: position,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.wallLayerPosition),
                    items: [
                      for (var i = 0; i <= drafts.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            i == drafts.length
                                ? l.wallLayerAtEnd
                                : l.wallLayerBefore(
                                    '${i + 1} · ${drafts[i].layer.material.label(l)}',
                                  ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => position = v ?? position),
                  ),
                  DropdownButtonFormField<ArchitectMaterial>(
                    key: const ValueKey('wall-new-layer-material'),
                    initialValue: material,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.wallLayerMaterial),
                    items: [
                      for (final m in ArchitectMaterial.values)
                        DropdownMenuItem(value: m, child: Text(m.label(l))),
                    ],
                    onChanged: (v) => update(() {
                      material = v ?? material;
                      input.text = _number(
                        unit.toUnit(switch (material.defaultRole) {
                          ArchitectLayerRole.core => .12,
                          ArchitectLayerRole.insulation => .12,
                          ArchitectLayerRole.finish => .015,
                        }),
                      );
                    }),
                  ),
                  TextFormField(
                    key: const ValueKey('wall-new-layer-thickness'),
                    controller: input,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l.architectWallQuickThickness,
                      suffixText: unit.symbol,
                    ),
                    validator: (s) =>
                        _parse(s ?? '') == null || _parse(s ?? '')! <= 0
                        ? l.architectWallInvalidThickness
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const ValueKey('wall-layer-insert'),
              onPressed: () {
                if (!addForm.currentState!.validate()) return;
                Navigator.pop(ctx, (
                  ArchitectMaterialLayer(
                    id: ArchitectElementId.next('layer'),
                    material: material,
                    role: material.defaultRole,
                    thickness: unit.fromUnit(_parse(input.text)!),
                  ),
                  position,
                ));
              },
              child: Text(l.applyAction),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      changed();
      drafts.insert(result.$2, _LayerDraft(result.$1, unit));
      expandedLayer = result.$1.id;
    });
  }

  void addCoatings() => setState(() {
    if (drafts.length > 18) {
      error = context.l10n.wallLayerLimit;
      return;
    }
    changed();
    drafts.insert(
      0,
      _LayerDraft(
        ArchitectMaterialLayer(
          id: ArchitectElementId.next('layer'),
          material: location == ArchitectWallLocation.exterior
              ? ArchitectMaterial.render
              : ArchitectMaterial.plaster,
          role: ArchitectLayerRole.finish,
          thickness: location == ArchitectWallLocation.exterior ? .005 : .015,
        ),
        widget.project.units,
      ),
    );
    drafts.add(
      _LayerDraft(
        ArchitectMaterialLayer(
          id: ArchitectElementId.next('layer'),
          material: ArchitectMaterial.plaster,
          role: ArchitectLayerRole.finish,
          thickness: .015,
        ),
        widget.project.units,
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isNewType ? l.wallNewVariant : l.wallCompositionAction,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            widget.isNewType
                ? l.wallNewTypeScope
                : widget.typeUseCount == null
                ? l.wallSelectedScope
                : widget.typeUseCount == 0
                ? l.wallTypesTitle
                : l.wallTypeApply(widget.typeUseCount!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!system.isLog)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l.architectWallTotalThickness(
                  architectWallLength(total, widget.project.units),
                ),
                key: const ValueKey('wall-composition-total'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Expanded(
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!source.isParapet) ...[
                      DropdownButtonFormField<ArchitectWallSystemKind>(
                        key: ValueKey('wall-system-kind-${system.kind.name}'),
                        initialValue: system.kind,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.wallSystem),
                        items: [
                          for (final kind in ArchitectWallSystemKind.values)
                            DropdownMenuItem(
                              value: kind,
                              child: Text(kind.label(l)),
                            ),
                        ],
                        onChanged: (kind) {
                          if (kind == null || kind == system.kind) return;
                          setState(() => switchSystem(kind));
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.allowTypeSelection)
                      OutlinedButton(
                        key: const ValueKey('wall-composition-type'),
                        onPressed: pickType,
                        child: Row(
                          children: [
                            Expanded(child: Text(l.wallChooseType)),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                      ),
                    Text(
                      currentType.compositionLabel(l, widget.project.units),
                      key: const ValueKey('wall-active-composition'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (!system.isLog)
                      Text(
                        location == ArchitectWallLocation.exterior
                            ? l.wallLayerOutsideInside
                            : l.wallLayerSides,
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 54,
                      child: system.isSpecial
                          ? ArchitectWallSystemPreview(
                              system: system,
                              layers: layers,
                            )
                          : ArchitectWallLayerPreview(
                              layers: [
                                for (final d in drafts)
                                  d.layer.copyWith(
                                    thickness: widget.project.units.fromUnit(
                                      (_parse(d.input.text) ?? 0).clamp(
                                        .000001,
                                        double.infinity,
                                      ),
                                    ),
                                  ),
                              ],
                              selectedIndex: drafts.indexWhere(
                                (d) => d.layer.id == expandedLayer,
                              ),
                              onSelected: (index) => setState(
                                () => expandedLayer = drafts[index].layer.id,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    if (system.isLog)
                      TextFormField(
                        key: ValueKey(
                          'wall-layer-thickness-${drafts.first.layer.id}',
                        ),
                        controller: drafts.first.input,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l.wallLogDiameter,
                          suffixText: widget.project.units.symbol,
                        ),
                        onChanged: (_) => setState(changed),
                        validator: (_) => invalidNumber(drafts.first)
                            ? l.architectWallInvalidThickness
                            : null,
                      )
                    else
                      for (var i = 0; i < drafts.length; i++) _row(i),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!system.isLog)
                          TextButton.icon(
                            key: const ValueKey('wall-layer-add'),
                            onPressed: addLayer,
                            icon: const Icon(Icons.add),
                            label: Text(l.wallLayerAdd),
                          ),
                        if (!system.isLog &&
                            !drafts.any(
                              (d) => d.layer.role == ArchitectLayerRole.finish,
                            ))
                          TextButton.icon(
                            key: const ValueKey('wall-layer-coatings'),
                            onPressed: addCoatings,
                            icon: const Icon(Icons.add),
                            label: Text(l.wallLayerCoatings),
                          ),
                        if (location == ArchitectWallLocation.interior &&
                            drafts.first.layer.role ==
                                ArchitectLayerRole.finish &&
                            drafts.last.layer.role != ArchitectLayerRole.finish)
                          TextButton(
                            key: const ValueKey('wall-copy-finish'),
                            onPressed: () => setState(() {
                              final copies = drafts
                                  .takeWhile(
                                    (d) =>
                                        d.layer.role ==
                                        ArchitectLayerRole.finish,
                                  )
                                  .toList()
                                  .reversed;
                              if (drafts.length + copies.length > 20) {
                                error = l.wallLayerLimit;
                                return;
                              }
                              final values = [
                                for (final d in copies)
                                  _LayerDraft(
                                    d.layer.copyWith(
                                      id: ArchitectElementId.next('layer'),
                                      thickness: widget.project.units.fromUnit(
                                        _parse(d.input.text) ?? 0,
                                      ),
                                    ),
                                    widget.project.units,
                                  ),
                              ];
                              changed();
                              drafts.addAll(values);
                            }),
                            child: Tooltip(
                              message: l.wallCopyFinishHelp,
                              child: Text(l.wallCopyFinish),
                            ),
                          ),
                      ],
                    ),
                    if (layerError != null)
                      Text(
                        layerError!,
                        key: const ValueKey('wall-layer-validation'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (system.isSpecial)
                      ExpansionTile(
                        key: ValueKey(
                          'wall-system-options-${system.kind.name}',
                        ),
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.wallSystemOptions),
                        children: [
                          ArchitectWallSystemFields(
                            key: ValueKey(
                              'wall-system-fields-${source.id}-${system.kind.name}',
                            ),
                            system: system,
                            unit: widget.project.units,
                            thickness: total,
                            onChanged: (value) => setState(() {
                              system = value;
                              changed();
                            }),
                          ),
                        ],
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l.wallTypeDetails),
                      children: [
                        TextFormField(
                          controller: name,
                          onChanged: (_) => changed(),
                          validator: (s) =>
                              widget.requireName && (s ?? '').trim().isEmpty
                              ? l.wallCompositionName
                              : null,
                          decoration: InputDecoration(
                            labelText: l.wallCompositionName,
                            hintText: l.wallOptionalName,
                          ),
                        ),
                        if (!source.isParapet) ...[
                          DropdownButtonFormField<ArchitectWallLocation>(
                            key: ValueKey(
                              'wall-location-${system.kind.name}-${source.id}',
                            ),
                            initialValue: location,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.wallLocation,
                              suffixIcon: Tooltip(message: l.wallTypeLocationHint,
                                child: const Icon(Icons.info_outline, size: 18)),
                            ),
                            items: [
                              for (final v in ArchitectWallLocation.values)
                                DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    v == ArchitectWallLocation.exterior
                                        ? l.wallExterior
                                        : l.wallInterior,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  changed();
                                  location = v;
                                });
                              }
                            },
                          ),
                        ],
                        if (source.isParapet &&
                            widget.typeUseCount != null) ...[
                          DropdownButtonFormField<ParapetFinish>(
                            initialValue: parapetFinish,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.wallPlinthFinish,
                            ),
                            items: [
                              for (final f in ParapetFinish.values)
                                DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f == ParapetFinish.cap
                                        ? l.wallParapetCap
                                        : l.wallParapetHandrail,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              changed();
                              parapetFinish = v ?? parapetFinish;
                            }),
                          ),
                          TextFormField(
                            controller: defaultHeight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l.wallParapetDefaultHeight,
                              suffixText: widget.project.units.symbol,
                            ),
                            onChanged: (_) => setState(changed),
                            validator: (s) =>
                                _parse(s ?? '') == null || _parse(s ?? '')! <= 0
                                ? l.wallInvalidHeight
                                : null,
                          ),
                        ],
                        if (widget.allowTypeSelection)
                          CheckboxListTile(
                            key: const ValueKey('wall-save-to-catalog'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(l.wallSaveToCatalog),
                            value: saveToCatalog,
                            onChanged: (v) => setState(() {
                              changed();
                              saveToCatalog = v ?? false;
                            }),
                          ),
                      ],
                    ),
                    if (!system.isLog &&
                        widget.plinth != null &&
                        location == ArchitectWallLocation.exterior)
                      _plinth(),
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              const Spacer(),
              Flexible(
                child: FilledButton(
                  key: const ValueKey('wall-composition-save'),
                  onPressed: save,
                  child: Text(
                    widget.isNewType
                        ? l.wallCreate
                        : (widget.typeUseCount ?? 0) == 0
                        ? l.save
                        : l.wallTypeApply(widget.typeUseCount!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: body));
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 740),
        child: body,
      ),
    );
  }

  Widget _row(int index) {
    final d = drafts[index],
        l = context.l10n,
        open = expandedLayer == d.layer.id;
    return Column(
      key: ValueKey('wall-layer-${d.layer.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('wall-layer-details-${d.layer.id}'),
                onTap: () =>
                    setState(() => expandedLayer = open ? null : d.layer.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.isLog
                            ? l.wallLogDiameter
                            : d.layer.role.label(l),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(d.layer.material.label(l)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: TextFormField(
                key: ValueKey('wall-layer-thickness-${d.layer.id}'),
                controller: d.input,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  suffixText: widget.project.units.symbol,
                  isDense: true,
                ),
                onChanged: (_) => setState(changed),
                validator: (_) => invalidNumber(d) ? '' : null,
              ),
            ),
            if (!system.isLog)
              PopupMenuButton<String>(
                key: ValueKey('wall-layer-menu-${d.layer.id}'),
                tooltip: l.wallLayerDetails,
                itemBuilder: (_) => [
                  for (final role in ArchitectLayerRole.values)
                    CheckedPopupMenuItem(
                      value: role.name,
                      checked: d.layer.role == role,
                      child: Text(role.label(l)),
                    ),
                  PopupMenuItem(
                    value: 'up',
                    enabled: index > 0,
                    child: Text(l.wallLayerUp),
                  ),
                  PopupMenuItem(
                    value: 'down',
                    enabled: index + 1 < drafts.length,
                    child: Text(l.wallLayerDown),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: drafts.length > 1,
                    child: Text(l.delete),
                  ),
                ],
                onSelected: (value) => setState(() {
                  changed();
                  if (value == 'delete') {
                    retiredInputs.add(drafts.removeAt(index).input);
                  } else if (value == 'up' || value == 'down') {
                    final row = drafts.removeAt(index);
                    drafts.insert(index + (value == 'up' ? -1 : 1), row);
                  } else {
                    d.layer = d.layer.copyWith(
                      role: ArchitectLayerRole.values.byName(value),
                    );
                  }
                }),
              ),
          ],
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<ArchitectMaterial>(
              key: ValueKey('wall-layer-material-${d.layer.id}'),
              initialValue: d.layer.material,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.wallLayerMaterial),
              items: [
                for (final m in ArchitectMaterial.values)
                  DropdownMenuItem(value: m, child: Text(m.label(l))),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    changed();
                    d.layer = d.layer.copyWith(
                      material: v,
                      role: d.layer.role == d.layer.material.defaultRole
                          ? v.defaultRole
                          : d.layer.role,
                    );
                  });
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _plinth() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        CheckboxListTile(
          key: const ValueKey('wall-plinth-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.wallPlinth),
          value: plinthEnabled,
          tristate: mixed((p) => p.enabled),
          onChanged: (v) => setState(() {
            plinthEnabled = v ?? false;
            editedRegionFields.add('enabled');
          }),
        ),
        if (plinthEnabled != false) ...[
          TextFormField(
            key: const ValueKey('wall-plinth-height'),
            controller: plinthHeight,
            onChanged: (_) => editedRegionFields.add('height'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'H (${widget.project.units.symbol})',
              hintText: l.wallMixedValue,
            ),
            validator: (s) =>
                mixed((p) => p.height) && !editedRegionFields.contains('height')
                ? null
                : _parse(s ?? '') == null || _parse(s ?? '')! <= 0
                ? l.wallInvalidHeight
                : null,
          ),
          DropdownButtonFormField<ArchitectMaterial>(
            initialValue: plinthFinish,
            hint: Text(l.wallMixedValue),
            decoration: InputDecoration(labelText: l.wallPlinthFinish),
            items: [
              for (final m in [
                ArchitectMaterial.render,
                ArchitectMaterial.tile,
                ArchitectMaterial.stone,
              ])
                DropdownMenuItem(value: m, child: Text(m.label(l))),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  plinthFinish = v;
                  editedRegionFields.add('finish');
                });
              }
            },
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.wallAdvanced),
            children: [
              TextFormField(
                key: const ValueKey('wall-plinth-base'),
                controller: plinthBase,
                onChanged: (_) => editedRegionFields.add('base'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: l.wallPlinthBase,
                  helperText: l.wallPlinthBaseHelp,
                  hintText: l.wallMixedValue,
                ),
                validator: (s) =>
                    mixed((p) => p.baseElevation) &&
                        !editedRegionFields.contains('base')
                    ? null
                    : _parse(s ?? '') == null
                    ? l.wallLayerInvalid
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
