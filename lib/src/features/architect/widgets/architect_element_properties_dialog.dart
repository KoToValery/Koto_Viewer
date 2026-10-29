import 'dart:convert';
import '../models/architect_elements.dart';
import '../models/architect_line_style.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_drawing_color.dart';
import 'architect_drawing_color_picker.dart';
import 'architect_hatch_picker.dart';
import 'architect_line_style_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_material_label.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../models/architect_door.dart';
import '../services/architect_selection.dart';
import '../models/architect_zone.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectElementPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final Set<String> elementIds;
  final VoidCallback? onSlabLayers;
  final VoidCallback? onScheduleTable;
  final void Function(Map<String,double>,Map<String,String>)? onWallLayers,onWallPlinth;
  final bool Function(Map<String, double>, Map<String, String>)? onStraighten;
  final bool Function(Map<String, double>, Map<String, String>) onApply;
  const ArchitectElementPropertiesDialog({
    super.key,
    required this.project,
    required this.elementIds,
    required this.onApply,
    this.onSlabLayers,
    this.onScheduleTable,
    this.onWallLayers,
    this.onWallPlinth,
    this.onStraighten,
  });
  @override
  State<ArchitectElementPropertiesDialog> createState() =>
      _ArchitectElementPropertiesDialogState();
}

class _ArchitectElementPropertiesDialogState
    extends State<ArchitectElementPropertiesDialog> {
  final values = <String, double>{};
  final texts = <String, String>{};
  Map<String, dynamic> get panelPlacement => Map<String, dynamic>.from(
    texts.containsKey('wallPanelPlacement')
        ? jsonDecode(texts['wallPanelPlacement']!) as Map
        : records.first['systemPlacement'] as Map? ?? {},
  );
  void updatePanelPlacement(Map<String, dynamic> patch) => setState(() {
    texts['wallPanelPlacement'] = jsonEncode({...panelPlacement, ...patch});
  });
  ArchitectLineStyle? _lineStyle;
  ArchitectHatchPattern? _hatchPattern;
  ArchitectDrawingColor? _hatchColor;
  bool? _hatchBorder;
  bool get _supportsHatch => widget.elementIds.every((id) =>
    widget.project.activeStorey.cadPrimitives.any((p) => p.id == id && p.type == CadPrimitiveType.hatch));
  bool get _supportsLineStyle => widget.elementIds.every(
    (id) => widget.project.activeStorey.cadPrimitives.any(
      (p) => p.id == id && p.type != CadPrimitiveType.circle,
    ),
  );
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
    if (_supportsHatch) {
      final hatches = widget.project.activeStorey.cadPrimitives.where((p) => widget.elementIds.contains(p.id)).toList();
      final patterns = hatches.map((p) => p.hatchPattern).toSet();
      if (patterns.length == 1) _hatchPattern = patterns.single;
      final colors = hatches.map((p) => p.drawingColor).toSet();
      if (colors.length == 1) _hatchColor = colors.single;
      final borders = hatches.map((p) => p.hatchBorder).toSet();
      if (borders.length == 1) _hatchBorder = borders.single;
    }
    if (_supportsLineStyle) {
      final styles = widget.project.activeStorey.cadPrimitives
          .where((p) => widget.elementIds.contains(p.id))
          .map((p) => p.lineStyle)
          .toSet();
      if (styles.length == 1) _lineStyle = styles.single;
    }
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
    if (isWindow) {
      final flips = records.map((e) => e['isFlipped'] as bool? ?? false).toSet();
      if (flips.length == 1) {
        texts['isFlipped'] = '${flips.first}';
      }
    }
    final isZone = records.isNotEmpty &&
        records.every((e) => e.containsKey('category') && e.containsKey('floorFinish'));
    if (isZone) {
      final categories = records.map((e) => e['category'] as String?).toSet();
      if (categories.length == 1 && categories.first != null) {
        texts['category'] = categories.first!;
      }
      final numbers = records.map((e) => e['number'] as String?).toSet();
      if (numbers.length == 1 && numbers.first != null) {
        texts['number'] = numbers.first!;
      }
      final names = records.map((e) => e['name'] as String?).toSet();
      if (names.length == 1 && names.first != null) {
        texts['name'] = names.first!;
      }
      final floorFinishes = records.map((e) => e['floorFinish'] as String?).toSet();
      if (floorFinishes.length == 1 && floorFinishes.first != null) {
        texts['floorFinish'] = floorFinishes.first!;
      }
      final wallFinishes = records.map((e) => e['wallFinish'] as String?).toSet();
      if (wallFinishes.length == 1 && wallFinishes.first != null) {
        texts['wallFinish'] = wallFinishes.first!;
      }
      final ceilingFinishes = records.map((e) => e['ceilingFinish'] as String?).toSet();
      if (ceilingFinishes.length == 1 && ceilingFinishes.first != null) {
        texts['ceilingFinish'] = ceilingFinishes.first!;
      }
      final autoBoundaries = records.map((e) => e['isAutoBoundary'] as bool?).toSet();
      if (autoBoundaries.length == 1 && autoBoundaries.first != null) {
        texts['isAutoBoundary'] = '${autoBoundaries.first!}';
      }
    }
  }

  String label(String key) {
    final l = context.l10n;
    return switch (key) {
      'arcRadius' => 'R=',
      'height' => l.architectPropertyHeight,
      'width' => l.architectPropertyWidth,
      'depth' => l.architectPropertyDepth,
      'thickness' =>
        records.every((e) => e.containsKey('referenceLine'))
            ? l.architectPropertyTotal
            : l.architectPropertyThickness,
      'strokeWidth' => l.architectStrokeWeight,
      'coreThickness' => l.architectWallCoreThickness,
      'insulationThicknessOverride' => l.architectPropertyThickness,
      'rotationDeg' => l.architectPropertyAngle,
      'hatchAngle' => l.architectPropertyAngle,
      'hatchScale' => l.architectHatchScale,
      'stepCount' => l.architectPropertySteps,
      'sillHeight' => l.architectPropertySill,
      'elevation' => l.architectToolLevel,
      'offsetDistance' => l.architectPropertyOffset,
      'baseOffset' => l.architectPropertyBaseOffset,
      'clearHeight' => l.architectZoneClearHeight,
      'targetArea' => l.architectZoneTargetArea,
      _ => l.architectPropertySize,
    };
  }

  // Legacy stroke weights are shown as paper mm, independently of model units.
  bool metric(String key) => !{'strokeWidth', 'rotationDeg', 'stepCount', 'hatchScale', 'hatchAngle'}.contains(key);
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
        : key == 'strokeWidth' ? 'mm'
        : key == 'rotationDeg' || key == 'hatchAngle'
        ? '°'
        : '';
    final value = fieldValue(key) ?? 0;
    var draft = key == 'strokeWidth' ? value / ArchitectCadPrimitive.strokeUnitsPerPaperMm
        : metric(key) ? widget.project.units.toUnit(value) : value;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 250,
          child: ArchitectWallDraftingPanel(
            length: draft,
            unit: unit,
            decimals: metric(key) ? widget.project.distanceDecimals : key == 'strokeWidth' ? 3 : key == 'stepCount' ? 0 : 2,
            title: label(key),
            endLabel: context.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            minimumLength:
                {'elevation', 'rotationDeg', 'hatchAngle', 'offsetDistance', 'baseOffset'}.contains(key)
                ? -double.infinity
                : {'sillHeight', 'insulationThicknessOverride'}.contains(key)
                ? 0
                : .001,
            onLength: (v) => draft = v,
            onEnd: () {
              setState(
                () => values[key] = key == 'strokeWidth'
                    ? draft * ArchitectCadPrimitive.strokeUnitsPerPaperMm
                    : metric(key) ? widget.project.units.fromUnit(draft) : draft,
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
  Widget _zoneMetricsBanner(ArchitectZone zone, AppLocalizations l) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: zone.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: zone.color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.square_foot, size: 16, color: zone.color),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${l.architectZoneAreaLabel}: ${widget.project.units.formatArea(zone.area)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${l.architectZonePerimeterLabel}: ${widget.project.formatLength(zone.perimeter)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _zoneCategoryField(AppLocalizations l) {
    final currentCatName = texts['category'] ??
        (records.map((e) => e['category']).toSet().length == 1
            ? records.first['category'] as String? ?? 'custom'
            : 'custom');
    final currentCat = ArchitectZoneCategory.values.firstWhere(
      (c) => c.name == currentCatName,
      orElse: () => ArchitectZoneCategory.custom,
    );
    return DropdownButtonFormField<String>(
      key: ValueKey('architect-property-category-$currentCatName'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.architectZoneCategory,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      initialValue: currentCat.name,
      items: [
        for (final cat in ArchitectZoneCategory.values)
          DropdownMenuItem(
            value: cat.name,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat.icon, size: 18, color: cat.color),
                const SizedBox(width: 8),
                Text(cat.localizedName(l)),
              ],
            ),
          ),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() {
            texts['category'] = val;
            final newCat = ArchitectZoneCategory.values.firstWhere(
              (c) => c.name == val,
              orElse: () => ArchitectZoneCategory.custom,
            );
            final currentName = texts['name'] ?? (records.first['name'] as String? ?? '');
            if (currentName.isEmpty ||
                ArchitectZoneCategory.values.any((c) => c.localizedName(l) == currentName)) {
              texts['name'] = newCat.localizedName(l);
            }
          });
        }
      },
    );
  }

  Widget _zoneNumberAndNameFields(AppLocalizations l) {
    final currentNumber = texts['number'] ??
        (records.map((e) => e['number']).toSet().length == 1
            ? records.first['number'] as String? ?? '1'
            : '1');
    final currentName = texts['name'] ??
        (records.map((e) => e['name']).toSet().length == 1
            ? records.first['name'] as String? ?? ''
            : '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: TextFormField(
            key: ValueKey('architect-property-number-$currentNumber'),
            initialValue: currentNumber,
            decoration: InputDecoration(
              labelText: l.architectZoneNumberPrompt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (v) => texts['number'] = v,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            key: ValueKey('architect-property-name-$currentName'),
            initialValue: currentName,
            decoration: InputDecoration(
              labelText: l.architectZoneName,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (v) => texts['name'] = v,
          ),
        ),
      ],
    );
  }

  Widget _zoneFinishField(String key, String label, List<String> presets) {
    final current = texts[key] ??
        (records.map((e) => e[key]).toSet().length == 1
            ? records.first[key] as String? ?? ''
            : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('architect-property-$key-$current'),
              initialValue: current,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (v) => texts[key] = v,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: label,
            icon: const Icon(Icons.arrow_drop_down, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (val) {
              setState(() => texts[key] = val);
            },
            itemBuilder: (_) => [
              for (final preset in presets.toSet())
                PopupMenuItem(value: preset, child: Text(preset)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoneBoundaryModeSwitch(AppLocalizations l) {
    final isAuto = texts['isAutoBoundary'] == 'false'
        ? false
        : (texts['isAutoBoundary'] == 'true'
            ? true
            : (records.first['isAutoBoundary'] as bool? ?? true));
    return CheckboxListTile(
      key: const ValueKey('architect-property-isAutoBoundary'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(l.architectZoneBoundaryAuto),
      subtitle: Text(
        l.architectZoneBoundaryAutoDesc,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
      value: isAuto,
      onChanged: (val) {
        if (val != null) {
          setState(() => texts['isAutoBoundary'] = '$val');
        }
      },
    );
  }

  Widget numberField(String key, bool walls) => ListTile(
    key: ValueKey('architect-property-$key'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(label(key)),
    trailing: Text(
      fieldValue(key) == null
          ? '—'
          : metric(key)
          ? widget.project.formatLength(fieldValue(key)!)
          : key == 'strokeWidth' ? '${(fieldValue(key)! / ArchitectCadPrimitive.strokeUnitsPerPaperMm).toStringAsFixed(3)} mm'
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
    final isZone = records.isNotEmpty &&
        records.every((e) => e.containsKey('category') && e.containsKey('floorFinish'));
    return AlertDialog(
      title: Text(l.architectProperties),
      content: SizedBox(
        width: isZone ? 310 : 270,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onScheduleTable != null) ...[
                OutlinedButton.icon(
                  key: const ValueKey('architect-property-schedule-table'),
                  onPressed: widget.onScheduleTable,
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text(l.architectZoneScheduleTitle),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.onSlabLayers != null)
                OutlinedButton.icon(
                  key: const ValueKey('architect-property-slab-layers'),
                  onPressed: widget.onSlabLayers,
                  icon: const Icon(Icons.layers_outlined),
                  label: Text(l.slabLayers),
                ),
              if (isZone) ...[
                if (widget.elementIds.length == 1) ...[
                  Builder(
                    builder: (_) {
                      final zone = widget.project.activeStorey.zones
                          .where((z) => widget.elementIds.contains(z.id))
                          .firstOrNull;
                      return zone != null
                          ? _zoneMetricsBanner(zone, l)
                          : const SizedBox.shrink();
                    },
                  ),
                ],
                _zoneNumberAndNameFields(l),
                const SizedBox(height: 8),
                _zoneCategoryField(l),
                const SizedBox(height: 4),
                numberField('clearHeight', false),
                if (fields.containsKey('targetArea'))
                  numberField('targetArea', false),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.architectZoneFinishes,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 4),
                _zoneFinishField(
                  'floorFinish',
                  l.architectZoneFloorFinish,
                  ArchitectZone.standardFloorFinishes(l),
                ),
                _zoneFinishField(
                  'wallFinish',
                  l.architectZoneWallFinish,
                  ArchitectZone.standardWallFinishes(l),
                ),
                _zoneFinishField(
                  'ceilingFinish',
                  l.architectZoneCeilingFinish,
                  ArchitectZone.standardCeilingFinishes(l),
                ),
                const SizedBox(height: 4),
                _zoneBoundaryModeSwitch(l),
              ],
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
              if (isDoor) ...[
                ListTile(
                  key: const ValueKey('architect-property-specId'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectDoorSpecId),
                  trailing: Text(
                    texts['specId'] ?? (records.first['specId'] as String? ?? '1'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final controller = TextEditingController(
                      text: texts['specId'] ??
                          (records.first['specId'] as String? ?? '1'),
                    );
                    final res = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.architectDoorSpecId),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: l.architectDoorSpecId,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.cancel),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text.trim()),
                            child: Text(l.save),
                          ),
                        ],
                      ),
                    );
                    if (res != null && res.isNotEmpty) {
                      setState(() => texts['specId'] = res);
                    }
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.architectDoorHingeSide,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<bool>(
                      expandedInsets: EdgeInsets.zero,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(
                            l.architectDoorHingeLeft,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(
                            l.architectDoorHingeRight,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selected: {
                        texts['isHingeLeft'] == 'false'
                            ? false
                            : (texts['isHingeLeft'] == 'true'
                                ? true
                                : (records.first['isHingeLeft'] as bool? ?? true)),
                      },
                      onSelectionChanged: (sel) {
                        setState(() {
                          final isLeft = sel.first;
                          texts['isHingeLeft'] = '$isLeft';
                          final currentSpec = texts['specId'] ?? (records.first['specId'] as String?);
                          if (currentSpec != null && currentSpec.isNotEmpty) {
                            final base = ArchitectDoor.extractBaseNumber(currentSpec);
                            if (base != null) {
                              texts['specId'] = ArchitectDoor.formatSpecId(baseNumber: base, isHingeLeft: isLeft);
                            }
                          }
                        });
                      },
                      showSelectedIcon: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.architectDoorSwingDirection,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    SegmentedButton<bool>(
                      expandedInsets: EdgeInsets.zero,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(
                            l.architectDoorSwingIn,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(
                            l.architectDoorSwingOut,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selected: {
                        texts['openInward'] == 'false'
                            ? false
                            : (texts['openInward'] == 'true'
                                ? true
                                : (records.first['openInward'] as bool? ?? true)),
                      },
                      onSelectionChanged: (sel) {
                        setState(() => texts['openInward'] = '${sel.first}');
                      },
                      showSelectedIcon: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (isWindow) ...[
                ListTile(
                  key: const ValueKey('architect-property-window-flip'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectWindowFlipSide),
                  trailing: Switch(
                    value: texts['isFlipped'] == 'true' ||
                        (texts['isFlipped'] == null &&
                            (records.first['isFlipped'] as bool? ?? false)),
                    onChanged: (val) {
                      setState(() => texts['isFlipped'] = '$val');
                    },
                  ),
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
              if (_supportsHatch) ...[
                ArchitectHatchPicker(key: const ValueKey('architect-property-hatch'), value: _hatchPattern,
                  colorValue: _hatchColor?.argb,
                  customPatterns: widget.project.hatchPatterns, lineStyles: widget.project.lineStyles,
                  onChanged: (pattern) => setState(() {
                    _hatchPattern = pattern; texts['hatchPattern'] = jsonEncode(pattern.toJson());
                  })),
                ArchitectDrawingColorPicker(key: const ValueKey('architect-property-hatch-color'), value: _hatchColor,
                  onChanged: (color) => setState(() {
                    _hatchColor = color; texts['drawingColor'] = jsonEncode(color.toJson());
                  })),
                CheckboxListTile(key: const ValueKey('architect-property-hatch-border'),
                  contentPadding: EdgeInsets.zero, dense: true, tristate: true,
                  title: Text(l.architectHatchBorder), value: _hatchBorder,
                  onChanged: (v) => setState(() {
                    _hatchBorder = v ?? false; texts['hatchBorder'] = '${v ?? false}';
                  })),
              ],
              if (_supportsLineStyle)
                ArchitectLineStylePicker(
                  key: const ValueKey('architect-property-line-style'),
                  value: _lineStyle,
                  customStyles: widget.project.lineStyles,
                  onChanged: (style) => setState(() {
                    _lineStyle = style;
                    texts['lineStyle'] = jsonEncode(style.toJson());
                  }),
                ),
              if (_supportsLineStyle)
                TextButton.icon(
                  key: const ValueKey('architect-property-line-pattern'),
                  icon: const Icon(Icons.tune),
                  label: Text(l.architectLinePatternEditor),
                  onPressed: () async {
                    final current = _lineStyle ?? ArchitectLineStyle.presets[1];
                    final edited = await showDialog<ArchitectLineStyle>(
                      context: context,
                      builder: (_) => ArchitectLinePatternEditor(initial:
                        current.isPreset ? ArchitectLineStyle(
                          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                          name: current.label(l),
                          segmentsMm: current.isSolid ? const [3, 1.5] : current.segmentsMm,
                          symbol: current.symbol,
                        ) : current),
                    );
                    if (edited != null && mounted) {
                      setState(() {
                        _lineStyle = edited;
                        texts['lineStyle'] = jsonEncode(edited.toJson());
                      });
                    }
                  },
                ),
              if (!walls && !isZone)
                for (final key in fields.keys) numberField(key, false),
              if (walls) ...[
                if(widget.onWallPlinth!=null)OutlinedButton.icon(key:const ValueKey('architect-property-wall-plinth'),icon:const Icon(Icons.border_bottom),label:Text(l.wallPlinth),onPressed:(){Navigator.pop(context);widget.onWallPlinth!(values,texts);}),
                if(widget.onWallLayers!=null)OutlinedButton.icon(key:const ValueKey('architect-property-wall-layers'),icon:const Icon(Icons.layers_outlined),label:Text(l.wallCompositionAction),onPressed:(){Navigator.pop(context);widget.onWallLayers!(values,texts);}),
                if (widget.onStraighten != null)
                  OutlinedButton.icon(
                    key: const ValueKey('architect-property-straighten'),
                    icon: const Icon(Icons.square_foot),
                    label: Text(l.architectWallStraighten),
                    onPressed: () {
                      if (widget.onStraighten!(values, texts)) Navigator.pop(context);
                    },
                  ),
                if(fields.containsKey('arcRadius'))numberField('arcRadius',false),
                numberField('baseOffset', false),
                if (records.length == 1 &&
                    (records.first['system'] as Map?)?['kind'] ==
                        'sandwichPanels')
                  ExpansionTile(
                    key: const ValueKey('wall-panel-supports'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.wallColumnSupports),
                    children: [
                      TextFormField(
                        key: const ValueKey('wall-panel-offset'),
                        initialValue: widget.project.units
                            .toUnit(
                              (panelPlacement['mountingOffset'] as num?)
                                      ?.toDouble() ??
                                  0,
                            )
                            .toString(),
                        decoration: InputDecoration(
                          labelText: l.wallMountingOffset,
                          suffixText: widget.project.units.symbol,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (text) {
                          final value = double.tryParse(
                            text.replaceAll(',', '.'),
                          );
                          if (value != null && value.isFinite) {
                            updatePanelPlacement({
                              'mountingOffset': widget.project.units.fromUnit(
                                value,
                              ),
                            });
                          }
                        },
                      ),
                      for (final column in widget.project.activeStorey.columns)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(column.label),
                          value: (panelPlacement['columnIds'] as List? ?? [])
                              .contains(column.id),
                          onChanged: (value) {
                            final ids = Set<String>.from(
                              panelPlacement['columnIds'] as List? ?? [],
                            );
                            if (value == true) {
                              ids.add(column.id);
                            } else {
                              ids.remove(column.id);
                            }
                            updatePanelPlacement({'columnIds': ids.toList()});
                          },
                        ),
                      if ((panelPlacement['columnIds'] as List? ?? []).any(
                        (id) => !widget.project.activeStorey.columns.any(
                          (c) => c.id == id,
                        ),
                      )) ...[
                        Text(l.wallMissingSupports),
                        TextButton(
                          key: const ValueKey('wall-panel-remove-missing'),
                          onPressed: () => updatePanelPlacement({
                            'columnIds': [
                              for (final id in panelPlacement['columnIds'] as List? ?? [])
                                if (widget.project.activeStorey.columns.any((c) => c.id == id)) id,
                            ],
                          }),
                          child: Text(l.wallRemoveMissingSupports),
                        ),
                      ],
                    ],
                  ),
                numberField('height', true),
                if (normalWalls) ...[
                  Tooltip(
                    message: l.wallLocationAutoHelp,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('architect-property-location'),
                      decoration: InputDecoration(labelText: l.wallLocation),
                      initialValue: records.map((e) => e['locationMode'] == 'manual'
                          ? e['location'] as String? ?? 'interior' : 'automatic').toSet().length == 1
                          ? records.first['locationMode'] == 'manual'
                            ? records.first['location'] as String? ?? 'interior' : 'automatic'
                          : null,
                      items: [
                        DropdownMenuItem(value: 'automatic', child: Text(l.wallAutomatic)),
                        DropdownMenuItem(value: 'exterior', child: Text(l.wallExterior)),
                        DropdownMenuItem(value: 'interior', child: Text(l.wallInterior)),
                      ],
                      onChanged: (v) => setState(() {
                        if (v == null) return;
                        texts['locationMode'] = v == 'automatic' ? 'automatic' : 'manual';
                        if (v == 'automatic') { texts.remove('location'); }
                        else { texts['location'] = v; }
                      }),
                    ),
                  ),
                  Tooltip(
                    message: l.wallSideAutoHelp,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('architect-property-sideMode-${texts['exteriorSideMode'] ?? ''}'),
                      decoration: InputDecoration(labelText: l.wallExteriorSideLabel),
                      initialValue: texts['exteriorSideMode'] ??
                          (records.map((e) => e['exteriorSideMode'] ?? 'automatic').toSet().length == 1
                            ? records.first['exteriorSideMode'] as String? ?? 'automatic' : null),
                      items: [
                        DropdownMenuItem(value: 'automatic', child: Text(l.wallAutomatic)),
                        DropdownMenuItem(value: 'manual', child: Text(l.wallManual)),
                      ],
                      onChanged: (v) => setState(() {
                        if (v != null) texts['exteriorSideMode'] = v;
                      }),
                    ),
                  ),
                ],
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
                if(!records.any((e)=>(e['layers'] as List? ?? []).isNotEmpty))...[
                materialField('coreMaterial'),
                numberField('coreThickness', true),
                materialField('insulationMaterial'),
                numberField('insulationThicknessOverride', true),
                numberField('thickness', true),
                ],
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
                  onPressed: () => setState(() {
                    texts['exteriorSideMode'] = 'manual';
                    texts['exteriorSide'] =
                        (texts['exteriorSide'] ??
                                records.first['exteriorSide']) ==
                            'right'
                        ? 'left'
                        : 'right';
                  }),
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
              if (!isZone)
                for (final key in [
                  'name',
                  'label',
                  'text',
                  'specId',
                  'customText',
                ])
                  if (records.every((e) => e.containsKey(key)))
                    TextFormField(
                      key: ValueKey('$key-${texts[key] ?? records.first[key]}'),
                      initialValue:
                          texts[key] ??
                          (records.map((e) => e[key]).toSet().length == 1
                              ? records.first[key] as String? ?? ''
                              : ''),
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
