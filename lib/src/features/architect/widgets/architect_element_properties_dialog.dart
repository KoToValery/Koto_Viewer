import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../services/architect_selection.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectElementPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final Set<String> elementIds;
  final bool Function(Map<String, double>, Map<String, String>) onApply;
  const ArchitectElementPropertiesDialog({
    super.key,
    required this.project,
    required this.elementIds,
    required this.onApply,
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
      'thickness' || 'strokeWidth' => l.architectPropertyThickness,
      'coreThickness' => l.architectPropertyCore,
      'insulationThicknessOverride' => l.architectPropertyInsulation,
      'rotationDeg' => l.architectPropertyAngle,
      'stepCount' => l.architectPropertySteps,
      'sillHeight' => l.architectPropertySill,
      'elevation' => l.architectToolLevel,
      'offsetDistance' => l.architectPropertyOffset,
      _ => l.architectPropertySize,
    };
  }

  bool metric(String key) => key != 'rotationDeg' && key != 'stepCount';
  double? fieldValue(String key) {
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
    final value = values[key] ?? fields[key] ?? 0;
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
                {'elevation', 'rotationDeg', 'offsetDistance'}.contains(key)
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final walls = records.every((e) => e.containsKey('referenceLine'));
    final isDoor = records.isNotEmpty &&
        records.every((e) =>
            e.containsKey('offsetRatio') && e.containsKey('isHingeLeft'));
    final isWindow = records.isNotEmpty &&
        records.every((e) =>
            e.containsKey('offsetRatio') && e.containsKey('panesCount'));
    return AlertDialog(
      title: Text(l.architectProperties),
      content: SizedBox(
        width: 270,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDoor || isWindow) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('architect-property-styleId'),
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
              for (final entry in fields.entries)
                ListTile(
                  key: ValueKey('architect-property-${entry.key}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label(entry.key)),
                  trailing: Text(
                    fieldValue(entry.key) == null
                        ? '—'
                        : metric(entry.key)
                        ? widget.project.units.format(
                            fieldValue(entry.key)!,
                            decimals: 3,
                          )
                        : fieldValue(
                            entry.key,
                          )!.toStringAsFixed(entry.key == 'stepCount' ? 0 : 1),
                  ),
                  onTap: walls && entry.key == 'thickness'
                      ? null
                      : () => editNumber(entry.key),
                ),
              if (walls) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('architect-property-referenceLine'),
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
                IconButton(
                  key: const ValueKey('architect-property-flipSide'),
                  tooltip: l.architectWallFlipSide,
                  icon: Icon(
                    Icons.flip,
                    color: texts.containsKey('exteriorSide')
                        ? Colors.amber
                        : null,
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
