import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_roof.dart';
import 'architect_roof_number_field.dart';

class RoofLayerEditResult {
  final ArchitectRoofLayer layer;
  final int position;
  const RoofLayerEditResult(this.layer, this.position);
}

class RoofLayerEditorDialog extends StatefulWidget {
  final ArchitectRoofLayer layer;
  final List<ArchitectRoofLayer> layers;
  final int? index;
  const RoofLayerEditorDialog({
    super.key,
    required this.layer,
    required this.layers,
    this.index,
  });
  @override
  State<RoofLayerEditorDialog> createState() => _LayerState();
}

class _LayerState extends State<RoofLayerEditorDialog> {
  final form = GlobalKey<FormState>();
  late ArchitectRoofLayerRole role = widget.layer.role;
  late ArchitectRoofMaterial material = widget.layer.material;
  late double thickness = widget.layer.thickness * 1000;
  late bool between = widget.layer.isBetweenRafters;
  late int position = widget.index ?? widget.layers.length;
  int get otherZone {
    for (var i = 0; i < widget.layers.length; i++) {
      if (i != widget.index &&
          (widget.layers[i].role == ArchitectRoofLayerRole.rafters ||
              widget.layers[i].isBetweenRafters)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final conflict =
        between && otherZone >= 0 && widget.layers[otherZone].isBetweenRafters;
    return AlertDialog(
      title: Text(l.roofUiLayerEdit),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ArchitectRoofLayerRole>(
                key: ValueKey('roof-layer-role-${role.name}'),
                initialValue: role,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.slabRole),
                items: [
                  for (final r in ArchitectRoofLayerRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label(l))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => role = v);
                },
              ),
              DropdownButtonFormField<ArchitectRoofMaterial>(
                initialValue: material,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.slabMaterial),
                items: [
                  for (final m in ArchitectRoofMaterial.values)
                    DropdownMenuItem(value: m, child: Text(m.label(l))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => material = v);
                },
              ),
              ArchitectRoofNumberField(
                key: const ValueKey('roof-layer-thickness-input'),
                value: thickness,
                label: l.architectPropertyThickness,
                unit: 'mm',
                min: .000001,
                onChanged: (v) => setState(() => thickness = v),
              ),
              SwitchListTile(
                key: const ValueKey('roof-layer-between'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.roofUiBetween),
                value: between,
                onChanged: (v) => setState(() {
                  between = v;
                  if (v) {
                    role = ArchitectRoofLayerRole.insulation;
                    if (otherZone >= 0) position = otherZone;
                  }
                }),
              ),
              if (between && otherZone >= 0)
                Text(l.roofUiStructureZone)
              else
                DropdownButtonFormField<int>(
                  key: const ValueKey('roof-layer-position'),
                  initialValue: position,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.roofUiLayerPosition),
                  items: [
                    for (var i = 0; i <= widget.layers.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          i == widget.layers.length
                              ? l.roofUiLayerEnd
                              : l.roofUiBeforeLayer(
                                  '${i + 1} · ${widget.layers[i].material.label(l)}',
                                ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => position = v ?? position),
                ),
              if (conflict)
                Text(
                  l.roofUiParallelZone,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          key: const ValueKey('roof-layer-save'),
          onPressed: () {
            if (conflict || !form.currentState!.validate()) return;
            Navigator.pop(
              context,
              RoofLayerEditResult(
                widget.layer.copyWith(
                  role: role,
                  material: material,
                  thickness: thickness / 1000,
                  isBetweenRafters: between,
                ),
                between && otherZone >= 0 ? otherZone : position,
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
