import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_material_label.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../services/architect_selection.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectElementPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final Set<String> elementIds;
  final VoidCallback? onSlabLayers;
  final bool Function(Map<String, double>, Map<String, String>) onApply;
  const ArchitectElementPropertiesDialog({
    super.key,
    required this.project,
    required this.elementIds,
    required this.onApply,
    this.onSlabLayers,
  });
  @override
  State<ArchitectElementPropertiesDialog> createState() =>
      _ArchitectElementPropertiesDialogState();
}

class _ArchitectElementPropertiesDialogState
    extends State<ArchitectElementPropertiesDialog> {
  final values = <String, double>{};
  final texts = <String, String>{};
  late final Map<String, double?> fields;
  late final List<Map<String, dynamic>> records;
  String reference(Map<String, dynamic> record) =>
      switch (record['referenceLine']) {
        'left' => record['exteriorSide'] == 'right' ? 'inner' : 'outer',
        'right' => record['exteriorSide'] == 'right' ? 'outer' : 'inner',
        final String value => value,
        _ => 'center',
      };
  @override
  void initState() {
    super.initState();
    records = [
      for (final id in widget.elementIds)
        ArchitectSelection.record(widget.project, id),
    ];
    if (records.every((e) => e.containsKey('referenceLine')) &&
        records.map(reference).toSet().length == 1 &&
        records.any(
          (e) => e['referenceLine'] == 'left' || e['referenceLine'] == 'right',
        )) {
      texts['referenceLine'] = reference(records.first);
    }
    final all = [
      for (final id in widget.elementIds)
        ArchitectSelection.fields(widget.project, id),
    ];
    fields = {
      for (final entry in all.first.entries)
        if (all.every((f) => f.containsKey(entry.key)))
          entry.key: all.every((f) => f[entry.key] == entry.value)
              ? entry.value
              : null,
    };
    final isDoor = records.isNotEmpty &&
        records.every((e) =>
            e.containsKey('offsetRatio') && e.containsKey('isHingeLeft'));
    final isWindow = records.isNotEmpty &&
        records.every((e) =>
            e.containsKey('offsetRatio') && e.containsKey('panesCount'));
    if (isDoor || isWindow) {
      final styleIds = records.map((e) => e['styleId'] as String?).toSet();
      if (styleIds.length == 1 && styleIds.first != null) {
        texts['styleId'] = styleIds.first!;
      }
    }
  }

  String label(String key) {
    final l = context.l10n;
    return switch (key) {
      'height' => l.architectPropertyHeight,
      'width' => l.architectPropertyWidth,
      'depth' => l.architectPropertyDepth,
      'thickness' =>
        records.every((e) => e.containsKey('referenceLine'))
            ? l.architectPropertyTotal
            : l.architectPropertyThickness,
      'strokeWidth' => l.architectPropertyThickness,
      'coreThickness' => l.architectWallCoreThickness,
      'insulationThicknessOverride' => l.architectPropertyThickness,
      'rotationDeg' => l.architectPropertyAngle,
      'stepCount' => l.architectPropertySteps,
      'sillHeight' => l.architectPropertySill,
      'elevation' => l.architectToolLevel,
      'offsetDistance' => l.architectPropertyOffset,
      'baseOffset' => l.architectPropertyBaseOffset,
      _ => l.architectPropertySize,
    };
  }

  bool metric(String key) => key != 'rotationDeg' && key != 'stepCount';
  double? fieldValue(String key) {
    if (key == 'height' &&
        records.every((e) => e.containsKey('referenceLine')) &&
        followsHeight &&
        normalWalls) {
      return widget.project.activeStorey.height;
    }
    if (key == 'thickness' &&
        fields.containsKey('coreThickness') &&
        (values.containsKey('coreThickness') ||
            values.containsKey('insulationThicknessOverride'))) {
      final core = values['coreThickness'] ?? fields['coreThickness'];
      final insulation =
          values['insulationThicknessOverride'] ??
          fields['insulationThicknessOverride'];
      return core != null && insulation != null ? core + insulation : null;
    }
    return values[key] ?? fields[key];
  }

  Future<void> editNumber(String key) async {
    final unit = metric(key)
        ? widget.project.units.symbol
        : key == 'rotationDeg'
        ? '°'
        : '';
    final value = fieldValue(key) ?? 0;
    var draft = metric(key) ? widget.project.units.toUnit(value) : value;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 250,
          child: ArchitectWallDraftingPanel(
            length: draft,
            unit: unit,
            title: label(key),
            endLabel: context.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            minimumLength:
                {'elevation', 'rotationDeg', 'offsetDistance', 'baseOffset'}.contains(key)
                ? -double.infinity
                : {'sillHeight', 'insulationThicknessOverride'}.contains(key)
                ? 0
                : .001,
            onLength: (v) => draft = v,
            onEnd: () {
              setState(
                () => values[key] = metric(key)
                    ? widget.project.units.fromUnit(draft)
                    : draft,
              );
              Navigator.pop(ctx);
            },
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  bool get followsHeight =>
      texts['followStoreyHeight'] == 'true' ||
      (!texts.containsKey('followStoreyHeight') &&
          records.every((e) => e['followStoreyHeight'] == true));
  bool get normalWalls =>
      records.every((e) => !ArchitectWall.fromJson(e).isParapet);
  Widget numberField(String key, bool walls) => ListTile(
    key: ValueKey('architect-property-$key'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label(key)),
    trailing: Text(
      fieldValue(key) == null
          ? '—'
          : metric(key)
          ? widget.project.units.format(fieldValue(key)!, decimals: 3)
          : fieldValue(key)!.toStringAsFixed(key == 'stepCount' ? 0 : 1),
    ),
    onTap:
        (walls && key == 'thickness') ||
            (walls && key == 'height' && followsHeight)
        ? null
        : () => editNumber(key),
  );

  Widget materialField(String key) {
    final l = context.l10n;
    final core = key == 'coreMaterial';
    final options = core
        ? WallCoreMaterial.values.map((m) => (m.name, m.label(l)))
        : WallInsulationMaterial.values.map((m) => (m.name, m.label(l)));
    final names = records.map((e) => e[key]).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('architect-property-$key'),
      isExpanded: true,
      initialValue:
          texts[key] ?? (names.length == 1 ? names.first as String? : null),
      decoration: InputDecoration(
        labelText: core
            ? l.architectPropertyCore
            : l.architectPropertyInsulation,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option.$1, child: Text(option.$2)),
      ],
      onChanged: (value) {
        if (value != null) setState(() => texts[key] = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final walls = records.every((e) => e.containsKey('referenceLine'));
    final isDoor =
        records.isNotEmpty &&
        records.every(
          (e) => e.containsKey('offsetRatio') && e.containsKey('isHingeLeft'),
        );
    final isWindow =
        records.isNotEmpty &&
        records.every(
          (e) => e.containsKey('offsetRatio') && e.containsKey('panesCount'),
        );
    return AlertDialog(
      title: Text(l.architectProperties),
      content: SizedBox(
        width: 270,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onSlabLayers != null)
                OutlinedButton.icon(
                  key: const ValueKey('architect-property-slab-layers'),
                  onPressed: widget.onSlabLayers,
                  icon: const Icon(Icons.layers_outlined),
                  label: Text(l.slabLayers),
                ),
              if (isDoor || isWindow) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('architect-property-styleId'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.architectFenestrationStyle,
                  ),
                  initialValue: FenestrationLibraryService.instance
                          .getStylesForKind(isDoor
                              ? FenestrationKind.door
                              : FenestrationKind.window)
                          .any((s) =>
                              s.id ==
                              (texts['styleId'] ?? records.first['styleId']))
                      ? (texts['styleId'] ??
                          records.first['styleId'] as String?)
                      : null,
                  items: [
                    for (final s in FenestrationLibraryService.instance
                        .getStylesForKind(isDoor
                            ? FenestrationKind.door
                            : FenestrationKind.window))
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        texts['styleId'] = val;
                        final s =
                            FenestrationLibraryService.instance.getStyleById(val);
                        if (s != null) {
                          values['width'] = s.defaultWidth;
                          values['height'] = s.defaultHeight;
                          values['sillHeight'] = s.defaultSillHeight;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (records.every((e) =>
                  e.containsKey('referenceLine') ||
                  e.containsKey('shape') ||
                  (e.containsKey('depth') && e.containsKey('width')))) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('architect-property-cutDisplayMode'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.architectPropertyCutDisplay,
                  ),
                  initialValue: texts['cutDisplayMode'] ??
                      (records.map((e) => e['cutDisplayMode'] as String? ?? 'auto').toSet().length == 1
                          ? (records.first['cutDisplayMode'] as String? ?? 'auto')
                          : null),
                  items: [
                    for (final mode in ArchitectCutDisplayMode.values)
                      DropdownMenuItem(
                        value: mode.name,
                        child: Text(switch (mode) {
                          ArchitectCutDisplayMode.auto => l.architectCutDisplayAuto,
                          ArchitectCutDisplayMode.projected => l.architectCutDisplayProjected,
                          ArchitectCutDisplayMode.cut => l.architectCutDisplayCut,
                          ArchitectCutDisplayMode.overhead => l.architectCutDisplayOverhead,
                        }),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => texts['cutDisplayMode'] = v);
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (!walls)
                for (final key in fields.keys) numberField(key, false),
              if (walls) ...[
                numberField('baseOffset', false),
                numberField('height', true),
                if (normalWalls)
                  CheckboxListTile(
                    key: const ValueKey(
                      'architect-property-followStoreyHeight',
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.architectWallFollowStorey),
                    value: followsHeight,
                    onChanged: (value) => setState(() {
                      texts['followStoreyHeight'] = '$value';
                      if (value == true) values.remove('height');
                    }),
                  ),
                materialField('coreMaterial'),
                numberField('coreThickness', true),
                materialField('insulationMaterial'),
                numberField('insulationThicknessOverride', true),
                numberField('thickness', true),
                IconButton(
                  key: const ValueKey('architect-property-flipSide'),
                  tooltip: l.architectWallFlipSide,
                  icon: Icon(
                    Icons.flip,
                    color: texts.containsKey('exteriorSide')
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF00E5FF)
                            : Theme.of(context).colorScheme.primary)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => setState(
                    () => texts['exteriorSide'] =
                        (texts['exteriorSide'] ??
                                records.first['exteriorSide']) ==
                            'right'
                        ? 'left'
                        : 'right',
                  ),
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('architect-property-referenceLine'),
                  decoration: InputDecoration(
                    labelText: l.architectWallLeadingLine,
                  ),
                  initialValue: records.map(reference).toSet().length == 1
                      ? reference(records.first)
                      : null,
                  items: [
                    for (final r in [
                      WallReferenceLine.center,
                      WallReferenceLine.inner,
                      WallReferenceLine.outer,
                    ])
                      DropdownMenuItem(
                        value: r.name,
                        child: Text(switch (r) {
                          WallReferenceLine.center =>
                            l.architectWallReferenceCenter,
                          WallReferenceLine.inner =>
                            l.architectWallReferenceInner,
                          _ => l.architectWallReferenceOuter,
                        }),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) texts['referenceLine'] = v;
                  },
                ),
              ],
              for (final key in [
                'name',
                'label',
                'text',
                'specId',
                'customText',
              ])
                if (records.every((e) => e.containsKey(key)))
                  TextFormField(
                    initialValue: records.map((e) => e[key]).toSet().length == 1
                        ? records.first[key] as String? ?? ''
                        : '',
                    decoration: InputDecoration(
                      labelText: key == 'text' || key == 'customText'
                          ? l.architectToolText
                          : l.architectPropertyName,
                    ),
                    onChanged: (v) => texts[key] = v,
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
          key: const ValueKey('architect-properties-save'),
          onPressed: () {
            if (widget.onApply(values, texts)) Navigator.pop(context);
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
