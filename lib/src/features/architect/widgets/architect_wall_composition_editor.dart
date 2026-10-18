import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_element_id.dart';
import 'architect_material_layer_label.dart';
import 'architect_wall_type_label.dart';

class _LayerDraft {
  ArchitectMaterialLayer layer;
  final TextEditingController input;
  _LayerDraft(this.layer, ArchitectUnit unit)
    : input = TextEditingController(
        text: _number(unit.toUnit(layer.thickness)),
      );
  void dispose() => input.dispose();
}

String _number(double v) => v
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

class ArchitectWallCompositionEditor extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectWallType type;
  final int? typeUseCount;
  final bool requireName;
  final bool allowTypeSelection;
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
  });
  @override
  State<ArchitectWallCompositionEditor> createState() => _EditorState();
}

class _EditorState extends State<ArchitectWallCompositionEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: !widget.type.isFactoryPreset ? widget.type.name : '',
  );
  late final drafts = [
    for (final layer in widget.type.resolvedLayers)
      _LayerDraft(layer, widget.project.units),
  ];
  late ArchitectWallLocation location = widget.type.resolvedLocation;
  late bool bearing =
      widget.type.isLoadBearing || widget.type.usage == WallUsage.bearing;
  List<ArchitectWallPlinth> get regions => widget.plinths.isEmpty
      ? [if (widget.plinth != null) widget.plinth!]
      : widget.plinths;
  bool mixed<T>(T Function(ArchitectWallPlinth) field) =>
      regions.map(field).toSet().length > 1;
  bool compositionChanged = false;
  bool detailsChanged = false;
  ArchitectWallType? pickedType;
  final editedRegionFields = <String>{};
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
  String? error;
  double? number(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v != null && v.isFinite ? v : null;
  }

  @override
  void dispose() {
    name.dispose();
    plinthHeight.dispose();
    plinthBase.dispose();
    for (final d in drafts) {
      d.dispose();
    }
    super.dispose();
  }

  double get total => drafts.fold(
    0,
    (v, d) => v + widget.project.units.fromUnit(number(d.input.text) ?? 0),
  );
  void save() {
    final l = context.l10n;
    if (!form.currentState!.validate()) return;
    try {
      final layers = [
        for (final d in drafts)
          d.layer.copyWith(
            thickness: widget.project.units.fromUnit(number(d.input.text)!),
          ),
      ];
      ArchitectMaterialLayer.validate(layers);
      final activePlinth =
          plinthEnabled != false && location == ArchitectWallLocation.exterior;
      if (activePlinth &&
          ((editedRegionFields.contains('height') &&
                  (number(plinthHeight.text) == null ||
                      number(plinthHeight.text)! <= 0)) ||
              (editedRegionFields.contains('base') &&
                  number(plinthBase.text) == null)))
        throw ArgumentError('Invalid plinth field');
      final region = widget.plinth == null
          ? null
          : ArchitectWallPlinthPatch(
              enabled: editedRegionFields.contains('enabled')
                  ? plinthEnabled
                  : null,
              height:
                  editedRegionFields.contains('height') &&
                      number(plinthHeight.text) != null &&
                      number(plinthHeight.text)! > 0
                  ? widget.project.units.fromUnit(number(plinthHeight.text)!)
                  : null,
              baseElevation: editedRegionFields.contains('base')
                  ? number(plinthBase.text)
                  : null,
              finish: editedRegionFields.contains('finish')
                  ? plinthFinish
                  : null,
            );
      if (region != null)
        for (final value in regions) {
          region.apply(value);
        }
      final source = pickedType ?? widget.type;
      final type = source.copyWith(
        id: pickedType != null && detailsChanged ? widget.type.id : source.id,
        layers: layers,
        location: location,
        loadBearing: bearing,
        name: name.text.trim(),
        labelId: source.labelId ?? source.id,
      );
      if (widget.onApply(type, region, compositionChanged))
        Navigator.pop(context);
    } on ArgumentError {
      setState(() => error = l.wallLayerInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.wallCompositionAction,
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
                widget.typeUseCount == null
                    ? l.wallSelectedScope
                    : l.wallTypeApply(widget.typeUseCount!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: form,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.allowTypeSelection) ...[
                          DropdownButtonFormField<ArchitectWallType>(
                            key: const ValueKey('wall-composition-type'),
                            initialValue: pickedType,
                            isExpanded: true,
                            hint: Text(widget.type.compactLabel(l)),
                            decoration: InputDecoration(
                              labelText: l.architectWallType,
                            ),
                            items: [
                              for (final t in widget.project.wallTypes)
                                DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.compactLabel(l),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (t) {
                              if (t == null) return;
                              setState(() {
                                pickedType = t;
                                compositionChanged = true;
                                detailsChanged = false;
                                for (final d in drafts) {
                                  d.dispose();
                                }
                                drafts
                                  ..clear()
                                  ..addAll([
                                    for (final layer in t.resolvedLayers)
                                      _LayerDraft(layer, widget.project.units),
                                  ]);
                                name.text = t.isFactoryPreset ? '' : t.name;
                                location = t.resolvedLocation;
                                bearing = t.isLoadBearing;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.requireName)
                          TextFormField(
                            controller: name,
                            onChanged: (_) {
                              compositionChanged = true;
                              detailsChanged = true;
                            },
                            validator: (s) =>
                                widget.requireName && (s ?? '').trim().isEmpty
                                ? l.wallCompositionName
                                : null,
                            decoration: InputDecoration(
                              labelText: l.wallCompositionName,
                              hintText: widget.type.compactLabel(l),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          location == ArchitectWallLocation.exterior
                              ? l.wallLayerOutsideInside
                              : l.wallLayerSides,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 52,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final d in drafts)
                                Expanded(
                                  flex: ((number(d.input.text) ?? 1) * 100)
                                      .round()
                                      .clamp(1, 100000),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: d.layer.material.color,
                                      border: Border.all(
                                        color:
                                            d.layer.role ==
                                                ArchitectLayerRole.core
                                            ? colors.onSurface
                                            : colors.outline,
                                        width:
                                            d.layer.role ==
                                                ArchitectLayerRole.core
                                            ? 2
                                            : 1,
                                      ),
                                    ),
                                    child: Tooltip(
                                      message:
                                          '${d.layer.material.label(l)} · ${d.input.text} ${widget.project.units.symbol}',
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var index = 0; index < drafts.length; index++)
                          _row(index),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const ValueKey('wall-layer-add'),
                            onPressed: () => setState(() {
                              compositionChanged = true;
                              detailsChanged = true;
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
                            }),
                            icon: const Icon(Icons.add),
                            label: Text(l.wallLayerAdd),
                          ),
                        ),
                        Text(
                          '${l.architectPropertyTotal}: ${_number(widget.project.units.toUnit(total))} ${widget.project.units.symbol}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(l.wallAdvanced),
                          children: [
                            if (!widget.requireName)
                              TextFormField(
                                controller: name,
                                onChanged: (_) {
                                  compositionChanged = true;
                                  detailsChanged = true;
                                },
                                validator: (s) =>
                                    widget.requireName &&
                                        (s ?? '').trim().isEmpty
                                    ? l.wallCompositionName
                                    : null,
                                decoration: InputDecoration(
                                  labelText: l.wallCompositionName,
                                  hintText: widget.type.compactLabel(l),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child:
                                      DropdownButtonFormField<
                                        ArchitectWallLocation
                                      >(
                                        initialValue: location,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: l.wallLocation,
                                        ),
                                        items: [
                                          for (final value
                                              in ArchitectWallLocation.values)
                                            DropdownMenuItem(
                                              value: value,
                                              child: Text(
                                                value ==
                                                        ArchitectWallLocation
                                                            .exterior
                                                    ? l.wallExterior
                                                    : l.wallInterior,
                                              ),
                                            ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              location = v;
                                              compositionChanged = true;
                                              detailsChanged = true;
                                            });
                                          }
                                        },
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(l.wallBearing),
                                    value: bearing,
                                    onChanged: (v) => setState(() {
                                      bearing = v ?? false;
                                      compositionChanged = true;
                                      detailsChanged = true;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (widget.plinth != null &&
                            location == ArchitectWallLocation.exterior) ...[
                          const Divider(height: 24),
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
                              onChanged: (_) =>
                                  editedRegionFields.add('height'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText:
                                    'H= (${widget.project.units.symbol})',
                                hintText: l.wallMixedValue,
                              ),
                              validator: (s) {
                                final v = number(s ?? '');
                                return mixed((p) => p.height) &&
                                        !editedRegionFields.contains('height')
                                    ? null
                                    : v == null || !v.isFinite || v <= 0
                                    ? l.architectWallInvalidThickness
                                    : null;
                              },
                            ),
                            DropdownButtonFormField<ArchitectMaterial>(
                              initialValue: plinthFinish,
                              hint: Text(l.wallMixedValue),
                              decoration: InputDecoration(
                                labelText: l.wallPlinthFinish,
                              ),
                              items: [
                                for (final m in [
                                  ArchitectMaterial.render,
                                  ArchitectMaterial.tile,
                                  ArchitectMaterial.stone,
                                ])
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(m.label(l)),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null)
                                  setState(() {
                                    plinthFinish = v;
                                    editedRegionFields.add('finish');
                                  });
                              },
                            ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(l.wallAdvanced),
                              children: [
                                TextFormField(
                                  key: const ValueKey('wall-plinth-base'),
                                  controller: plinthBase,
                                  onChanged: (_) =>
                                      editedRegionFields.add('base'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: l.wallPlinthBase,
                                    helperText: l.wallPlinthBaseHelp,
                                    hintText: l.wallMixedValue,
                                  ),
                                  validator: (s) {
                                    final v = number(s ?? '');
                                    return mixed((p) => p.baseElevation) &&
                                            !editedRegionFields.contains('base')
                                        ? null
                                        : v == null || !v.isFinite
                                        ? l.wallLayerInvalid
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                        if (error != null)
                          Text(error!, style: TextStyle(color: colors.error)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                        (widget.typeUseCount ?? 0) == 0
                            ? l.save
                            : l.wallTypeApply(widget.typeUseCount!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int index) {
    final d = drafts[index], l = context.l10n;
    return Padding(
      key: ValueKey('wall-layer-${d.layer.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<ArchitectMaterial>(
              key: ValueKey('wall-layer-material-${d.layer.id}'),
              initialValue: d.layer.material,
              isExpanded: true,
              decoration: InputDecoration(labelText: d.layer.role.label(l)),
              items: [
                for (final material in ArchitectMaterial.values)
                  DropdownMenuItem(
                    value: material,
                    child: Text(
                      material.label(l),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  compositionChanged = true;
                  detailsChanged = true;
                  setState(
                    () => d.layer = d.layer.copyWith(
                      material: v,
                      role: v.defaultRole,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              key: ValueKey('wall-layer-thickness-${d.layer.id}'),
              controller: d.input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.project.units.symbol,
              ),
              onChanged: (_) => setState(() {
                compositionChanged = true;
                detailsChanged = true;
              }),
              validator: (text) {
                final v = number(text ?? '');
                return v == null || !v.isFinite || v <= 0
                    ? l.architectWallInvalidThickness
                    : null;
              },
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l.wallLayerRole,
            icon: Icon(
              d.layer.role == ArchitectLayerRole.core
                  ? Icons.crop_square
                  : Icons.more_vert,
            ),
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
              compositionChanged = true;
              detailsChanged = true;
              if (value == 'delete') {
                drafts.removeAt(index).dispose();
              } else if (value == 'up' || value == 'down') {
                final to = index + (value == 'up' ? -1 : 1);
                final row = drafts.removeAt(index);
                drafts.insert(to, row);
              } else {
                d.layer = d.layer.copyWith(
                  role: ArchitectLayerRole.values.byName(value),
                );
              }
            }),
          ),
        ],
      ),
    );
  }
}
