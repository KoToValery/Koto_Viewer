import 'dart:math' as math;
import '../services/architect_floor_drain_geometry.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'dart:convert';
import '../models/architect_elements.dart';
import '../models/architect_line_style.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_drawing_color.dart';
import 'architect_drawing_color_picker.dart';
import 'architect_hatch_picker.dart';
import 'architect_line_style_picker.dart';
import '../services/architect_line_styles.dart';
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
import 'dart:async';
import '../services/architect_properties_session.dart';
import '../services/architect_wall_compositions.dart';
import '../services/architect_wall_library.dart';
import 'architect_properties_shell.dart';
import 'architect_property_number_field.dart';
import 'architect_properties_plan_preview.dart';
import 'architect_wall_composition_editor.dart';
import 'architect_wall_type_label.dart';
import 'architect_wall_type_picker.dart';
import 'architect_component_library_dialog.dart';

class ArchitectElementPropertiesDialog extends StatefulWidget {
  final bool Function(ArchitectProject)? onApplyProject;
  final void Function(ArchitectProject?)? onPreview;
  final String? viewKey;
  final int? drawingScale;
  final ArchitectProject Function(ArchitectProject)? prepare;
  final bool Function()? isCurrent;
  final ArchitectProject project;
  final Set<String> elementIds;
  final VoidCallback? onSlabLayers;
  final VoidCallback? onScheduleTable;
  final void Function(Map<String, double>, Map<String, String>)? onWallLayers,
      onWallPlinth;
  final bool Function(Map<String, double>, Map<String, String>)? onStraighten;
  final bool Function(Map<String, double>, Map<String, String>) onApply;
  const ArchitectElementPropertiesDialog({
    super.key,
    required this.project,
    required this.elementIds,
    required this.onApply,
    this.onApplyProject,
    this.onPreview,
    this.prepare,
    this.viewKey,
    this.drawingScale,
    this.isCurrent,
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
  bool _preserveDimensionsOnStyleChange = true;
  bool get _supportsHatch => widget.elementIds.every(
    (id) => widget.project.activeStorey.cadPrimitives.any(
      (p) => p.id == id && p.type == CadPrimitiveType.hatch,
    ),
  );
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
      final hatches = widget.project.activeStorey.cadPrimitives
          .where((p) => widget.elementIds.contains(p.id))
          .toList();
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
    if (isDoor || isWindow) {
      final styleIds = records.map((e) => e['styleId'] as String?).toSet();
      if (styleIds.length == 1 && styleIds.first != null) {
        texts['styleId'] = styleIds.first!;
      }
      final casings = records.map((e) => e['hasCasing'] as bool?).toSet();
      if (casings.length == 1 && casings.first != null) {
        texts['hasCasing'] = '${casings.first}';
      }
    }
    if (isWindow) {
      final flips = records
          .map((e) => e['isFlipped'] as bool? ?? false)
          .toSet();
      if (flips.length == 1) {
        texts['isFlipped'] = '${flips.first}';
      }
    }
    final isZone =
        records.isNotEmpty &&
        records.every(
          (e) => e.containsKey('category') && e.containsKey('floorFinish'),
        );
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
      final floorFinishes = records
          .map((e) => e['floorFinish'] as String?)
          .toSet();
      if (floorFinishes.length == 1 && floorFinishes.first != null) {
        texts['floorFinish'] = floorFinishes.first!;
      }
      final wallFinishes = records
          .map((e) => e['wallFinish'] as String?)
          .toSet();
      if (wallFinishes.length == 1 && wallFinishes.first != null) {
        texts['wallFinish'] = wallFinishes.first!;
      }
      final ceilingFinishes = records
          .map((e) => e['ceilingFinish'] as String?)
          .toSet();
      if (ceilingFinishes.length == 1 && ceilingFinishes.first != null) {
        texts['ceilingFinish'] = ceilingFinishes.first!;
      }
      final autoBoundaries = records
          .map((e) => e['isAutoBoundary'] as bool?)
          .toSet();
      if (autoBoundaries.length == 1 && autoBoundaries.first != null) {
        texts['isAutoBoundary'] = '${autoBoundaries.first!}';
      }
    }
    if (_isText) fields.remove('fontSize');
    if (_isLevel) {
      for (final key in ['levelUnits', 'levelDecimals']) {
        if (records.every((e) => e[key] == null)) texts[key] = 'inherit';
      }
    }
    _initialTexts = Map.of(texts);
    if (records.every((e) => e.containsKey('floorFinish'))) {
      fields['targetArea'] =
          (records.map((e) => e['targetArea']).toSet().length == 1
                  ? records.first['targetArea'] as num?
                  : null)
              ?.toDouble();
    }
  }

  String label(String key) {
    final l = context.l10n;
    return switch (key) {
      'arcRadius' => l.propertiesRadius,
      'height' => isSlopedWall
          ? l.architectPropertyStartHeight
          : l.architectPropertyHeight,
      'endHeight' => l.architectPropertyEndHeight,
      'tiltAngle' => l.architectPropertyTiltAngle,
      'width' =>
        widget.elementIds.every(
              (id) => widget.project.activeStorey.columns.any(
                (c) => c.id == id && c.shape.name == 'circular',
              ),
            )
            ? l.propertiesDiameter
            : l.architectPropertyWidth,
      'depth' => l.architectPropertyDepth,
      'thickness' =>
        records.every((e) => e.containsKey('referenceLine'))
            ? l.architectPropertyTotal
            : l.architectPropertyThickness,
      'strokeWidth' => l.architectStrokeWeight,
      'coreThickness' => l.architectWallCoreThickness,
      'insulationThicknessOverride' => l.architectPropertyThickness,
      'rotationDeg' || 'angle' => l.architectPropertyAngle,
      'slopePercent' => l.propertiesSlope,
      'hatchAngle' => l.architectPropertyAngle,
      'hatchScale' => l.architectHatchScale,
      'stepCount' => l.architectPropertySteps,
      'sillHeight' => l.architectPropertySill,
      'elevation' => l.architectToolLevel,
      'offsetDistance' => l.architectPropertyOffset,
      'baseOffset' => l.propertiesBaseOffset,
      'clearHeight' => l.architectZoneClearHeight,
      'targetArea' => l.architectZoneTargetArea,
      'fontSize' => l.propertiesTextHeight,
      _ => l.architectPropertySize,
    };
  }

  // Legacy stroke weights are shown as paper mm, independently of model units.
  bool metric(String key) => !{
    'strokeWidth',
    'rotationDeg',
    'stepCount',
    'hatchScale',
    'hatchAngle',
  }.contains(key);
  bool get isSlopedWall =>
      (values.containsKey('endHeight') ||
          (_common('endHeight') != null && !_cleared.contains('endHeight'))) &&
      records.every((e) => e.containsKey('referenceLine'));

  double? fieldValue(String key) {
    if (_cleared.contains(key)) return null;
    if (key == 'height' &&
        records.every((e) => e.containsKey('referenceLine')) &&
        followsHeight &&
        normalWalls &&
        !isSlopedWall) {
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

  bool get followsHeight =>
      texts['followStoreyHeight'] == 'true' ||
      (!texts.containsKey('followStoreyHeight') &&
          records.every((e) => e['followStoreyHeight'] == true));
  bool get normalWalls =>
      records.every((e) => !ArchitectWall.fromJson(e).isParapet);
  Widget _zoneMetricsBanner(
    ArchitectZone zone,
    AppLocalizations l,
  ) => Container(
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
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'architect-property-category-${texts['category'] ?? _common('category')}',
      ),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l.architectZoneCategory,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      initialValue: texts['category'] ?? _common('category') as String?,
      items: [
        for (final cat in ArchitectZoneCategory.values)
          DropdownMenuItem(
            value: cat.name,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon.fromMaterial(cat.icon, size: 18, color: cat.color),
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
            final currentName =
                texts['name'] ?? (records.first['name'] as String? ?? '');
            if (currentName.isEmpty ||
                ArchitectZoneCategory.values.any(
                  (c) => c.localizedName(l) == currentName,
                )) {
              texts['name'] = newCat.localizedName(l);
            }
          });
        }
      },
    );
  }

  Widget _zoneNumberAndNameFields(AppLocalizations l) {
    final currentNumber =
        texts['number'] ??
        (records.map((e) => e['number']).toSet().length == 1
            ? records.first['number'] as String? ?? '1'
            : '');
    final currentName =
        texts['name'] ??
        (records.map((e) => e['name']).toSet().length == 1
            ? records.first['name'] as String? ?? ''
            : '');
    final numberController = _textControllers.putIfAbsent(
      'number',
      () => TextEditingController(text: currentNumber),
    );
    final nameController = _textControllers.putIfAbsent(
      'name',
      () => TextEditingController(text: currentName),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: TextFormField(
            key: ValueKey('architect-property-number-${_initialText("number")}'),
            controller: numberController,
            decoration: InputDecoration(
              labelText: l.architectZoneNumberPrompt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            onChanged: (v) {
              texts['number'] = v;
              _inputDirty = true;
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) _preview();
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            key: ValueKey('architect-property-name-${_initialText("name")}'),
            controller: nameController,
            decoration: InputDecoration(
              labelText: l.architectZoneName,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
            onChanged: (v) {
              texts['name'] = v;
              _inputDirty = true;
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 300), () {
                if (mounted) _preview();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _zoneFinishField(String key, String label, List<String> presets) {
    final current =
        texts[key] ??
        (records.map((e) => e[key]).toSet().length == 1
            ? records.first[key] as String? ?? ''
            : '');
    final controller = _textControllers.putIfAbsent(
      key,
      () => TextEditingController(text: current),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('architect-property-$key-${_initialText(key)}'),
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onChanged: (v) {
                texts[key] = v;
                _inputDirty = true;
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) _preview();
                });
              },
            ),
          ),
          PopupMenuButton<String>(
            tooltip: label,
            icon: const AppIcon(AppIconId.expandMore, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (val) {
              controller.text = val;
              texts[key] = val;
              _inputDirty = true;
              setState(() {});
              _preview();
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
              : (_common('isAutoBoundary') as bool?));
    return CheckboxListTile(
      key: const ValueKey('architect-property-isAutoBoundary'),
      tristate: true,
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

  Widget numberField(String key, bool walls) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ArchitectPropertyNumberField(
      key: ValueKey('architect-property-$key'),
      descriptor: ArchitectPropertyDescriptor.of(key),
      project: key == 'elevation' && _isLevel
          ? widget.project.copyWith(
              units: _levelUnit,
              distanceDecimals: _levelDigits,
            )
          : widget.project,
      label: label(key),
      value: fieldValue(key),
      onClear: (key == 'targetArea' || key == 'tiltAngle')
          ? () => setState(() {
              values.remove(key);
              _cleared.add(key);
              fields[key] = null;
            })
          : null,
      readOnly:
          walls && (key == 'thickness' || (key == 'height' && followsHeight)),
      helper: walls && key == 'thickness'
          ? context.l10n.propertiesCalculated
          : walls && key == 'height' && followsHeight
          ? context.l10n.architectWallFollowStorey
          : null,
      onChanged: (value) => setState(() {
        if (value == fields[key]) {
          values.remove(key);
        } else {
          _cleared.remove(key);
          values[key] = value;
        }
      }),
    ),
  );

  Widget materialField(String key) {
    final l = context.l10n;
    final core = key == 'coreMaterial';
    final options = core
        ? WallCoreMaterial.values.map((m) => (m.name, m.label(l)))
        : WallInsulationMaterial.values.map((m) => (m.name, m.label(l)));
    final names = records.map((e) => e[key]).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('architect-property-$key-${_initialText(key)}'),
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

  final _form = GlobalKey<FormState>();
  final _shell = GlobalKey<ArchitectPropertiesShellState>();
  final _compositionHandle = ArchitectPropertiesEditorHandle();
  late final Map<String, String> _initialTexts;
  String _initialText(String key) => _initialTexts[key] ?? (_common(key)?.toString() ?? "");
  Timer? _timer;
  int _tab = 0;
  int _typeVersion = 0;
  String? _error;
  ArchitectWallType? _composition;
  ArchitectWallPlinthPatch? _region;
  bool _compositionChanged = false;
  bool _flipMixed = false;
  late final _session = ArchitectPropertiesSession(widget.project);
  late ArchitectProject _draft = widget.project;
  final _cleared = <String>{};
  final _textControllers = <String, TextEditingController>{};
    Object? _common(String key) {
    final all = records.map((e) => e[key]).toSet();
    return all.length == 1 ? all.single : null;
  }

  Map<String, String> get _patch => {
    for (final e in texts.entries)
      if (e.value != (_initialTexts[e.key] ?? '${_common(e.key) ?? ''}'))
        e.key: e.value,
  };
  bool _inputDirty = false;
  bool get _dirty =>
      _flipMixed ||
      (_compositionHandle.isDirty?.call() ?? false) ||
      _inputDirty ||
      _paperTextMm != null ||
      _resetTextSize ||
      _projectLevelUnits != null ||
      _projectLevelDecimals != null ||
      _cleared.isNotEmpty ||
      values.isNotEmpty ||
      _patch.isNotEmpty ||
      _composition != null;
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _preview();
    });
  }

  ArchitectProject _candidate() {
    var next = SetArchitectElementProperties(
      storeyId: widget.project.activeStoreyId,
      elementIds: widget.elementIds,
      values: values,
      clearValues: _cleared,
      textValues: _patch,
    ).apply(widget.project);
    if (_composition != null) {
      final originalWall = widget.project.activeStorey.walls
          .firstWhere((wall) => widget.elementIds.contains(wall.id));
      final compositionHeight = _composition!.customHeight;
      final heightEdited = _composition!.railing != null &&
          compositionHeight != null &&
          (compositionHeight - originalWall.height).abs() > 1e-9;
      next = SetArchitectWallComposition(
        type: _composition!,
        storeyId: widget.project.activeStoreyId,
        wallIds: widget.elementIds,
        plinthPatch: _region,
        preserveComposition: !_compositionChanged,
        railingHeight: heightEdited ? compositionHeight : null,
      ).apply(next);
    }
    if (_flipMixed) {
      for (final wall in widget.project.activeStorey.walls.where(
        (w) => widget.elementIds.contains(w.id),
      )) {
        next = SetArchitectElementProperties(
          storeyId: widget.project.activeStoreyId,
          elementIds: {wall.id},
          textValues: {
            'exteriorSideMode': 'manual',
            'exteriorSide': wall.exteriorSide == WallExteriorSide.right
                ? 'left'
                : 'right',
          },
        ).apply(next);
      }
    }
    if (_paperTextMm != null || _resetTextSize) {
      final sizes = Map<String, double>.of(next.document.overrideMm);
      for (final id in widget.elementIds) {
        final key = '$_viewKey/$id/ordinary/$_scale';
        if (_resetTextSize) {
          sizes.remove(key);
        } else {
          sizes[key] = _paperTextMm!;
        }
      }
      next = next.copyWith(document: next.document.copyWith(overrideMm: sizes));
    }
    next = next.copyWith(
      levelUnits: _projectLevelUnits,
      levelDecimals: _projectLevelDecimals,
    );
    return widget.prepare?.call(next) ?? next;
  }

  bool _preview({bool notify = true}) {
    try {
      if (widget.isCurrent?.call() == false) throw StateError('stale');
      _session.stage('properties', (_) => _candidate());
      _draft = _session.preview;
      if (notify) widget.onPreview?.call(_draft);
      super.setState(() => _error = null);
      return true;
    } on ArchitectRailingOpeningsError {
      super.setState(() => _error = context.l10n.railingHasOpenings);
      return false;
    } on ArgumentError {
      super.setState(() => _error = context.l10n.propertiesInvalid);
      return false;
    } on StateError {
      super.setState(() => _error = context.l10n.propertiesStale);
      return false;
    }
  }

  void _save() {
    _timer?.cancel();
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      _shell.currentState?.expand();
      setState(() => _error = context.l10n.propertiesInvalid);
      final field = invalid.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (field.mounted) Scrollable.ensureVisible(field.context);
      });
      return;
    }
    if (_compositionHandle.validate != null &&
        !_compositionHandle.validate!()) {
      setState(() {
        _tab = 1;
        _error = context.l10n.propertiesInvalid;
      });
      _shell.currentState?.expand();
      return;
    }
    if (!_preview(notify: false)) return;
    if (!_dirty ||
        (widget.onApplyProject?.call(_draft) ??
            widget.onApply(values, _patch))) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    widget.onPreview?.call(null);
    super.dispose();
  }

  Widget _textField(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey('architect-property-$key-${_initialText(key)}'),
      controller: _textControllers.putIfAbsent(
        key,
        () => TextEditingController(
          text: texts[key] ?? _common(key)?.toString() ?? '',
        ),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: _common(key) == null ? context.l10n.wallMixedValue : null,
      ),
      onChanged: (v) {
        texts[key] = v;
        _inputDirty = true;
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) _preview();
        });
      },
    ),
  );
  Widget _scroll(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  ArchitectWallType _wallType() {
    final w = widget.project.activeStorey.walls.firstWhere(
      (w) => widget.elementIds.contains(w.id),
    );
    return ArchitectWallType(
      id: 'properties-${w.id}',
      name: '',
      isCatalogType: false,
      layers: w.resolvedLayers,
      system: w.system,
      totalThickness: w.thickness,
      parapetFinish: w.parapetFinish,
      railing: w.railing,
      customHeight: w.height,
      usage: w.isParapet
          ? WallUsage.parapet
          : w.isExterior
          ? WallUsage.exterior
          : WallUsage.interior,
      location: w.isExterior
          ? ArchitectWallLocation.exterior
          : ArchitectWallLocation.interior,
    );
  }

  Future<void> _pickType() async {
    final result = await showArchitectWallTypePicker(
      context,
      types: ArchitectWallLibrary.available(widget.project.wallTypes)
          .where((t) => t.isParapet == _wallType().isParapet).toList(),
      activeType: _composition ?? _wallType(),
      unit: widget.project.units,
      projectId: widget.project.id,
    );
    if (result != null && mounted) {
      setState(() {
        _typeVersion++;
        _composition = result.type;
        _compositionChanged = true;
      });
    }
  }

  Widget _choice(String key, String label, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('architect-property-$key-${_initialText(key)}'),
          isExpanded: true,
          initialValue: texts[key] ?? _common(key)?.toString(),
          decoration: InputDecoration(
            labelText: label,
            hintText: context.l10n.wallMixedValue,
          ),
          items: [
            for (final e in options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => texts[key] = v);
          },
        ),
      );
  bool get _isText => widget.elementIds.every(
    (id) => widget.project.activeStorey.annotations.any((a) => a.id == id),
  );
  bool get _isLevel => widget.elementIds.every(
    (id) => widget.project.activeStorey.elevationMarkers.any((a) => a.id == id),
  );
  double? _paperTextMm;
  bool _resetTextSize = false;
  ArchitectUnit? _projectLevelUnits;
  int? _projectLevelDecimals;
  String get _viewKey =>
      widget.viewKey ?? 'plan:${widget.project.activeStoreyId}';
  int get _scale =>
      widget.drawingScale ??
      widget.project.document.viewScales[_viewKey] ??
      widget.project.dimensionScale.denominator;
  ArchitectUnit get _levelUnit =>
      ArchitectUnit.values
          .where(
            (u) => u.name == (texts['levelUnits'] ?? _common('levelUnits')),
          )
          .firstOrNull ??
      _projectLevelUnits ??
      widget.project.levelUnits;
  int get _levelDigits =>
      int.tryParse(
        texts['levelDecimals'] ?? '${_common('levelDecimals') ?? ''}',
      ) ??
      _projectLevelDecimals ??
      widget.project.levelDecimals;

  List<Widget> _textFields(AppLocalizations l) {
    final heights = {
      for (final id in widget.elementIds)
        widget.project.document.textMm(
          _viewKey,
          id,
          ArchitectAnnotationRole.ordinary,
          _scale,
        ),
    };
    return [
      TextFormField(
        key: ValueKey('architect-property-paper-text-$_resetTextSize'),
        initialValue: _resetTextSize
            ? null
            : (heights.length == 1 ? heights.single.toStringAsFixed(2) : ''),
        decoration: InputDecoration(
          labelText: l.architectTextPaperHeight,
          hintText: l.wallMixedValue,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) =>
            _resetTextSize || v == null || v.isEmpty && heights.length != 1
            ? null
            : double.tryParse(v.replaceAll(',', '.'))?.isFinite == true &&
                  (double.tryParse(v.replaceAll(',', '.')) ?? 0) > 0
            ? null
            : l.propertiesInvalid,
        onChanged: (v) => setState(() {
          _paperTextMm = double.tryParse(v.replaceAll(',', '.'));
          _resetTextSize = false;
          _inputDirty = true;
        }),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => setState(() {
            _paperTextMm = null;
            _resetTextSize = true;
          }),
          child: Text(l.architectAnnotationReset),
        ),
      ),
      _choice('alignment', l.architectTextAlignment, {
        'left': l.architectTextLeft,
        'center': l.architectTextCenter,
        'right': l.architectTextRight,
      }),
      _choice('fontWeight', l.architectTextWeight, {
        '400': l.architectTextRegular,
        '600': l.architectTextSemibold,
        '700': l.architectTextBold,
        if (_common('fontWeight') != null &&
            ![400, 600, 700].contains(_common('fontWeight')))
          '${_common('fontWeight')}': '${_common('fontWeight')}',
      }),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.architectTextItalic),
        value: (texts['italic'] ?? '${_common('italic')}') == 'true',
        onChanged: (v) => setState(() => texts['italic'] = '$v'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.architectTextUnderline),
        value: (texts['underline'] ?? '${_common('underline')}') == 'true',
        onChanged: (v) => setState(() => texts['underline'] = '$v'),
      ),
      ArchitectDrawingColorPicker(
        value: ArchitectDrawingColor(
          int.tryParse(texts['textColor'] ?? '') ??
              (_common('colorValue') as num?)?.toInt() ??
              0xFF212121,
        ),
        onChanged: (v) => setState(() => texts['textColor'] = '${v.argb}'),
      ),
    ];
  }

  List<Widget> _levelFields(AppLocalizations l) => [
    _choice('symbol', l.architectLevelSymbol, {
      'automatic': l.wallAutomatic,
      'plan': l.architectLevelPlan,
      'elevation': l.architectLevelElevation,
    }),
    _choice('levelUnits', l.architectLevelFormat, {
      'inherit': l.architectInheritProject,
      for (final u in ArchitectUnit.values) u.name: u.symbol,
    }),
    _choice('levelDecimals', l.architectPrecision, {
      'inherit': l.architectInheritProject,
      for (var i = 0; i <= 4; i++) '$i': '$i',
    }),
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l.architectInheritProject),
      children: [
        DropdownButtonFormField<ArchitectUnit>(
          key: const ValueKey('architect-project-level-units'),
          initialValue: _projectLevelUnits ?? widget.project.levelUnits,
          decoration: InputDecoration(labelText: l.architectLevelFormat),
          items: [
            for (final u in ArchitectUnit.values)
              DropdownMenuItem(value: u, child: Text(u.symbol)),
          ],
          onChanged: (u) => setState(() => _projectLevelUnits = u),
        ),
        DropdownButtonFormField<int>(
          key: const ValueKey('architect-project-level-decimals'),
          initialValue: _projectLevelDecimals ?? widget.project.levelDecimals,
          decoration: InputDecoration(labelText: l.architectPrecision),
          items: [
            for (var i = 0; i <= 4; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (n) => setState(() => _projectLevelDecimals = n),
        ),
      ],
    ),
  ];

  String _title(AppLocalizations l) {
    final s = widget.project.activeStorey, ids = widget.elementIds;
    final name = ids.every((id) => s.walls.any((e) => e.id == id))
        ? l.architectToolWall
        : ids.every((id) => s.walls.any((w) => w.doors.any((e) => e.id == id)))
        ? l.architectToolDoor
        : ids.every(
            (id) => s.walls.any((w) => w.windows.any((e) => e.id == id)),
          )
        ? l.architectToolWindow
        : ids.every((id) => s.columns.any((e) => e.id == id))
        ? l.architectToolColumn
        : ids.every((id) => s.beams.any((e) => e.id == id))
        ? l.architectToolBeam
        : ids.every((id) => s.slabs.any((e) => e.id == id))
        ? l.architectToolSlab
        : ids.every((id) => s.zones.any((e) => e.id == id))
        ? l.architectToolZone
        : ids.every((id) => s.floorDrains.any((e) => e.id == id))
        ? l.architectToolFloorDrain
        : ids.every((id) => s.openings.any((e) => e.id == id))
        ? l.architectToolOpening
        : ids.every((id) => s.annotations.any((e) => e.id == id))
        ? l.architectToolText
        : ids.every((id) => s.dimensions.any((e) => e.id == id))
        ? l.architectToolDimension
        : ids.every((id) => s.elevationMarkers.any((e) => e.id == id))
        ? l.architectToolLevel
        : ids.every((id) => widget.project.gridAxes.any((e) => e.id == id))
        ? l.architectToolAxis
        : ids.every(
            (id) => s.cadPrimitives.any(
              (e) => e.id == id && e.type == CadPrimitiveType.hatch,
            ),
          )
        ? l.architectToolHatch
        : l.architectProperties;
    return ids.length == 1 ? name : l.propertiesSelection(name, ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final walls = widget.elementIds.every(
      (id) => widget.project.activeStorey.walls.any((w) => w.id == id),
    );
    final isDoor = records.every(
      (e) => e.containsKey('offsetRatio') && e.containsKey('isHingeLeft'),
    );
    final isWindow = records.every(
      (e) => e.containsKey('offsetRatio') && e.containsKey('panesCount'),
    );
    final isZone = records.every((e) => e.containsKey('floorFinish'));
    final pages = <Widget>[];
    if (!walls) {
      pages.add(
        _scroll([
          if (_isText) ..._textFields(l),
          if (_isLevel) ..._levelFields(l),
          if (widget.elementIds.every(
            (id) => widget.project.activeStorey.cadPrimitives.any(
              (p) => p.id == id && p.type == CadPrimitiveType.polyline,
            ),
          ))
            CheckboxListTile(
              key: const ValueKey('architect-property-closed'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectPolylineClosed),
              value: (texts['closed'] ?? '${_common('closed')}') == 'true',
              onChanged: (v) => setState(() => texts['closed'] = '$v'),
            ),
          if (widget.elementIds.every(
            (id) => widget.project.activeStorey.cadPrimitives.any(
              (p) => p.id == id && (p.type == CadPrimitiveType.line || p.type == CadPrimitiveType.arc),
            ),
          )) ...[
            DropdownButtonFormField<ArchitectLineEndCap>(
              decoration: InputDecoration(labelText: l.architectLineStartCap),
              value: ArchitectLineEndCap.values.where((c) => c.name == (texts['startCap'] ?? _common('startCap'))).firstOrNull ?? ArchitectLineEndCap.none,
              items: [
                DropdownMenuItem(value: ArchitectLineEndCap.none, child: Text(l.architectLineCapNone)),
                DropdownMenuItem(value: ArchitectLineEndCap.arrowFilled, child: Text(l.architectLineCapArrowFilled)),
                DropdownMenuItem(value: ArchitectLineEndCap.arrowOpen, child: Text(l.architectLineCapArrowOpen)),
                DropdownMenuItem(value: ArchitectLineEndCap.dotFilled, child: Text(l.architectLineCapDotFilled)),
                DropdownMenuItem(value: ArchitectLineEndCap.dotOpen, child: Text(l.architectLineCapDotOpen)),
                DropdownMenuItem(value: ArchitectLineEndCap.tick, child: Text(l.architectLineCapTick)),
              ],
              onChanged: (v) => setState(() => texts['startCap'] = v?.name ?? 'none'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ArchitectLineEndCap>(
              decoration: InputDecoration(labelText: l.architectLineEndCap),
              value: ArchitectLineEndCap.values.where((c) => c.name == (texts['endCap'] ?? _common('endCap'))).firstOrNull ?? ArchitectLineEndCap.none,
              items: [
                DropdownMenuItem(value: ArchitectLineEndCap.none, child: Text(l.architectLineCapNone)),
                DropdownMenuItem(value: ArchitectLineEndCap.arrowFilled, child: Text(l.architectLineCapArrowFilled)),
                DropdownMenuItem(value: ArchitectLineEndCap.arrowOpen, child: Text(l.architectLineCapArrowOpen)),
                DropdownMenuItem(value: ArchitectLineEndCap.dotFilled, child: Text(l.architectLineCapDotFilled)),
                DropdownMenuItem(value: ArchitectLineEndCap.dotOpen, child: Text(l.architectLineCapDotOpen)),
                DropdownMenuItem(value: ArchitectLineEndCap.tick, child: Text(l.architectLineCapTick)),
              ],
              onChanged: (v) => setState(() => texts['endCap'] = v?.name ?? 'none'),
            ),
          ],
          if (widget.elementIds.every(
            (id) => widget.project.activeStorey.cadPrimitives.any(
              (p) => p.id == id && p.type == CadPrimitiveType.mask,
            ),
          ))
            CheckboxListTile(
              key: const ValueKey('architect-property-mask-border'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectMaskBorderShow),
              value: (texts['maskBorder'] ?? '${_common('maskBorder')}') != 'false',
              onChanged: (v) => setState(() => texts['maskBorder'] = '$v'),
            ),
          for (final drain in widget.project.activeStorey.floorDrains.where(
            (d) => widget.elementIds.contains(d.id),
          ))
            for (final issue in ArchitectFloorDrainGeometry.field(
              drain,
              widget.project.activeStorey.walls,
            ).issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(switch (issue) {
                        ArchitectDrainIssue.outsideFloor =>
                          l.architectDrainOutsideFloor,
                        ArchitectDrainIssue.nearDoor =>
                          l.architectDrainNearDoor,
                        ArchitectDrainIssue.invalidSurface =>
                          l.architectDrainInvalidSurface,
                      }),
                    ),
                  ],
                ),
              ),
          if (widget.onScheduleTable != null) ...[
            OutlinedButton.icon(
              key: const ValueKey('architect-property-schedule-table'),
              onPressed: widget.onScheduleTable,
              icon: const AppIcon(AppIconId.schedule, size: 18),
              label: Text(l.architectZoneScheduleTitle),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.onSlabLayers != null)
            OutlinedButton.icon(
              key: const ValueKey('architect-property-slab-layers'),
              onPressed: widget.onSlabLayers,
              icon: const AppIcon(AppIconId.layers),
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('architect-property-styleId'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.architectFenestrationStyle,
                    ),
                    value: FenestrationLibraryService.instance
                            .getStylesForKind(
                              isDoor
                                  ? FenestrationKind.door
                                  : FenestrationKind.window,
                            )
                            .any(
                              (s) =>
                                  s.id ==
                                  (texts['styleId'] ?? _common('styleId')),
                            )
                        ? (texts['styleId'] ?? _common('styleId') as String?)
                        : null,
                    items: [
                      for (final s in FenestrationLibraryService.instance
                          .getStylesForKind(
                        isDoor ? FenestrationKind.door : FenestrationKind.window,
                      ))
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.localizedName(l),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          texts['styleId'] = val;
                          if (!_preserveDimensionsOnStyleChange) {
                            final s = FenestrationLibraryService.instance
                                .getStyleById(val);
                            if (s != null) {
                              values['width'] = s.defaultWidth;
                              values['height'] = s.defaultHeight;
                              values['sillHeight'] = s.defaultSillHeight;
                            }
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l.architectBrowseLibrary,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                    ),
                    icon: const AppIcon(AppIconId.library, size: 18),
                    label: Text(l.architectBrowseLibrary),
                    onPressed: () {
                      ArchitectComponentLibraryDialog.show(
                        context,
                        initialCategory: isDoor
                            ? ArchitectComponentCategory.doors
                            : ArchitectComponentCategory.windows,
                        onSelectFenestration: (style) {
                          setState(() {
                            texts['styleId'] = style.id;
                            if (!_preserveDimensionsOnStyleChange) {
                              values['width'] = style.defaultWidth;
                              values['height'] = style.defaultHeight;
                              values['sillHeight'] = style.defaultSillHeight;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l.architectSkinOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              subtitle: Text(
                l.architectSkinOnlyDesc,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value: _preserveDimensionsOnStyleChange,
              onChanged: (v) =>
                  setState(() => _preserveDimensionsOnStyleChange = v ?? true),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('architect-property-hasCasing'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                l.architectCasingToggle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              value: texts.containsKey('hasCasing')
                  ? texts['hasCasing'] == 'true'
                  : (_common('hasCasing') as bool? ??
                      FenestrationLibraryService.instance
                          .getStyleById(
                            texts['styleId'] ??
                                _common('styleId') as String? ??
                                '',
                          )
                          ?.hasCasing ??
                      false),
              onChanged: (val) {
                setState(() => texts['hasCasing'] = '$val');
              },
            ),
            const SizedBox(height: 8),
          ],
          if ((isDoor || isWindow) && widget.elementIds.length == 1)
            ArchitectPropertiesPlanPreview(
              project: _draft,
              elementId: widget.elementIds.single,
            ),
          if (isDoor) ...[
            _textField('specId', l.architectDoorSpecId),
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
                  emptySelectionAllowed: true,
                  selected: {
                    if (texts.containsKey('isHingeLeft'))
                      texts['isHingeLeft'] == 'true'
                    else if (_common('isHingeLeft') != null)
                      _common('isHingeLeft') as bool,
                  },
                  onSelectionChanged: (sel) {
                    setState(() {
                      if (sel.isEmpty) return;
                      final isLeft = sel.first;
                      texts['isHingeLeft'] = '$isLeft';
                      final currentSpec =
                          texts['specId'] ?? (_common('specId') as String?);
                      if (currentSpec != null && currentSpec.isNotEmpty) {
                        final base = ArchitectDoor.extractBaseNumber(
                          currentSpec,
                        );
                        if (base != null) {
                          texts['specId'] = ArchitectDoor.formatSpecId(
                            baseNumber: base,
                            isHingeLeft: isLeft,
                          );
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
                  emptySelectionAllowed: true,
                  selected: {
                    if (texts.containsKey('openInward'))
                      texts['openInward'] == 'true'
                    else if (_common('openInward') != null)
                      _common('openInward') as bool,
                  },
                  onSelectionChanged: (sel) {
                    if (sel.isNotEmpty) {
                      setState(() => texts['openInward'] = '${sel.first}');
                    }
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
              trailing: Checkbox(
                tristate: true,
                value: texts.containsKey('isFlipped')
                    ? texts['isFlipped'] == 'true'
                    : _common('isFlipped') as bool?,
                onChanged: (val) {
                  setState(() => texts['isFlipped'] = '${val ?? false}');
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (records.every(
            (e) =>
                widget.project.activeStorey.columns.any(
                  (c) => c.id == e['id'],
                ) ||
                widget.project.activeStorey.beams.any((b) => b.id == e['id']),
          )) ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('architect-property-cutDisplayMode'),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.architectPropertyCutDisplay,
              ),
              initialValue:
                  texts['cutDisplayMode'] ??
                  (records
                              .map(
                                (e) => e['cutDisplayMode'] as String? ?? 'auto',
                              )
                              .toSet()
                              .length ==
                          1
                      ? (records.first['cutDisplayMode'] as String? ?? 'auto')
                      : null),
              items: [
                for (final mode in ArchitectCutDisplayMode.values)
                  DropdownMenuItem(
                    value: mode.name,
                    child: Text(switch (mode) {
                      ArchitectCutDisplayMode.auto => l.architectCutDisplayAuto,
                      ArchitectCutDisplayMode.projected =>
                        l.architectCutDisplayProjected,
                      ArchitectCutDisplayMode.cut => l.architectCutDisplayCut,
                      ArchitectCutDisplayMode.overhead =>
                        l.architectCutDisplayOverhead,
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
            ArchitectHatchPicker(
              key: const ValueKey('architect-property-hatch'),
              value: _hatchPattern,
              colorValue: _hatchColor?.argb,
              customPatterns: widget.project.hatchPatterns,
              lineStyles: widget.project.lineStyles,
              onChanged: (pattern) => setState(() {
                _hatchPattern = pattern;
                texts['hatchPattern'] = jsonEncode(pattern.toJson());
              }),
            ),
            ArchitectDrawingColorPicker(
              key: const ValueKey('architect-property-hatch-color'),
              value: _hatchColor,
              onChanged: (color) => setState(() {
                _hatchColor = color;
                texts['drawingColor'] = jsonEncode(color.toJson());
              }),
            ),
            CheckboxListTile(
              key: const ValueKey('architect-property-hatch-border'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              tristate: true,
              title: Text(l.architectHatchBorder),
              value: _hatchBorder,
              onChanged: (v) => setState(() {
                _hatchBorder = v ?? false;
                texts['hatchBorder'] = '${v ?? false}';
              }),
            ),
          ],
          if (_supportsLineStyle)
            ArchitectLineStylePicker(
              key: const ValueKey('architect-property-line-style'),
              value: _lineStyle,
              customStyles: widget.project.lineStyles,
              onDeleteStyle: (style) {
                ArchitectLineStyleLibrary.delete(style.id);
                setState(() {
                  if (_lineStyle?.id == style.id) {
                    _lineStyle = ArchitectLineStyle.solid;
                    texts['lineStyle'] = jsonEncode(
                      ArchitectLineStyle.solid.toJson(),
                    );
                  }
                });
              },
              onChanged: (style) => setState(() {
                _lineStyle = style;
                texts['lineStyle'] = jsonEncode(style.toJson());
              }),
            ),
          if (_supportsLineStyle)
            TextButton.icon(
              key: const ValueKey('architect-property-line-pattern'),
              icon: const AppIcon(AppIconId.properties),
              label: Text(l.architectLinePatternEditor),
              onPressed: () async {
                final current = _lineStyle ?? ArchitectLineStyle.presets[1];
                final edited = await showDialog<ArchitectLineStyle>(
                  context: context,
                  builder: (_) => ArchitectLinePatternEditor(
                    initial: current.isPreset
                        ? ArchitectLineStyle(
                            id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                            name: current.label(l),
                            segmentsMm: current.isSolid
                                ? const [3, 1.5]
                                : current.segmentsMm,
                            symbol: current.symbol,
                          )
                        : current,
                  ),
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
            for (final key in [
              'width',
              'height',
              'depth',
              'thickness',
              'sillHeight',
              'baseOffset',
              'rotationDeg',
              'size',
              'angle',
              'slopePercent',
              'strokeWidth',
              'hatchScale',
              'hatchAngle',
              'fontSize',
              'elevation',
              'offsetDistance',
              'stepCount',
            ].where(fields.containsKey))
              if (!(key == 'depth' &&
                  widget.elementIds.every(
                    (id) => widget.project.activeStorey.columns.any(
                      (c) => c.id == id && c.shape.name == 'circular',
                    ),
                  )))
                numberField(key, false),
          if (!isZone)
            for (final key in ['name', 'label', 'text', 'customText'])
              if (records.every((e) => e.containsKey(key)))
                TextFormField(
                  key: ValueKey('architect-property-$key-${_initialText(key)}'),
                  controller: _textControllers.putIfAbsent(
                    key,
                    () => TextEditingController(
                      text: texts[key] ??
                          (records.map((e) => e[key]).toSet().length == 1
                              ? records.first[key] as String? ?? ''
                              : ''),
                    ),
                  ),
                  decoration: InputDecoration(
                    labelText: key == 'text' || key == 'customText'
                        ? l.architectToolText
                        : l.architectPropertyName,
                  ),
                  minLines: key == 'text' ? 3 : 1,
                  maxLines: key == 'text' ? null : 1,
                  onChanged: (v) {
                    texts[key] = v;
                    _inputDirty = true;
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) _preview();
                    });
                  },
                ),
        ]),
      );
    } else {
      pages.add(
        _scroll([
          OutlinedButton(
            onPressed: _pickType,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (_composition ?? _wallType()).catalogLabel(
                      l,
                      widget.project.units,
                    ),
                  ),
                ),
                const AppIcon(AppIconId.expandMore),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (normalWalls) ...[
            CheckboxListTile(
              key: const ValueKey('architect-property-followStoreyHeight'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectWallFollowStorey),
              tristate: true,
              value: isSlopedWall
                  ? false
                  : (texts.containsKey('followStoreyHeight')
                      ? texts['followStoreyHeight'] == 'true'
                      : _common('followStoreyHeight') as bool?),
              onChanged: isSlopedWall
                  ? null
                  : (v) => setState(() {
                      texts['followStoreyHeight'] = '${v ?? false}';
                      if (v == true) values.remove('height');
                    }),
            ),
            CheckboxListTile(
              key: const ValueKey('architect-property-slopedTop'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectWallSlopedTop),
              subtitle: Text(l.architectWallSlopedTopHelp),
              value: isSlopedWall,
              onChanged: (v) => setState(() {
                if (v == true) {
                  final curH = values['height'] ??
                      (records.first['height'] as num?)?.toDouble() ??
                      widget.project.activeStorey.height;
                  values['endHeight'] = curH + 1.0;
                  _cleared.remove('endHeight');
                  texts['followStoreyHeight'] = 'false';
                  texts['clipToRoof'] = 'false';
                } else {
                  values.remove('endHeight');
                  _cleared.add('endHeight');
                }
              }),
            ),
          ],
          numberField('height', true),
          if (isSlopedWall) ...[
            numberField('endHeight', false),
            CheckboxListTile(
              key: const ValueKey('architect-property-clipToRoof'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectWallClipToRoof),
              value: texts.containsKey('clipToRoof')
                  ? texts['clipToRoof'] == 'true'
                  : (_common('clipToRoof') as bool? ?? true),
              onChanged: (v) => setState(() {
                texts['clipToRoof'] = '${v ?? true}';
              }),
            ),
            () {
              final h1 =
                  fieldValue('height') ?? widget.project.activeStorey.height;
              final h2 = fieldValue('endHeight') ?? h1;
              final wall = widget.project.activeStorey.walls
                  .where((w) => widget.elementIds.contains(w.id))
                  .firstOrNull;
              final len = wall?.length ?? 1.0;
              final deg = len > 1e-4
                  ? (math.atan2((h2 - h1).abs(), len) * 180 / math.pi)
                  : 0.0;
              final pct = len > 1e-4 ? (((h2 - h1).abs() / len) * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.architectWallCalculatedSlope(
                    deg.toStringAsFixed(1),
                    pct.toStringAsFixed(1),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              );
            }(),
          ],
          numberField('baseOffset', false),
          if (records.every((e) => e.containsKey('referenceLine')))
            numberField('tiltAngle', false),
          if (fields.containsKey('arcRadius')) numberField('arcRadius', false),
          if (normalWalls)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                key: const ValueKey('architect-property-location'),
                isExpanded: true,
                initialValue: texts['locationMode'] == 'automatic'
                    ? 'automatic'
                    : texts['location'] ??
                          (records
                                      .map(
                                        (e) => e['locationMode'] == 'manual'
                                            ? e['location']
                                            : 'automatic',
                                      )
                                      .toSet()
                                      .length ==
                                  1
                              ? (records.first['locationMode'] == 'manual'
                                    ? records.first['location'] as String
                                    : 'automatic')
                              : null),
                decoration: InputDecoration(
                  labelText: l.wallLocation,
                  hintText: l.wallMixedValue,
                ),
                items: [
                  for (final e in {
                    'automatic': l.wallAutomatic,
                    'exterior': l.wallExterior,
                    'interior': l.wallInterior,
                  }.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() {
                  if (v == null) return;
                  texts['locationMode'] = v == 'automatic'
                      ? 'automatic'
                      : 'manual';
                  if (v == 'automatic') {
                    texts.remove('location');
                  } else {
                    texts['location'] = v;
                  }
                }),
              ),
            ),
        ]),
      );
      final compositions = widget.project.activeStorey.walls
          .where((w) => widget.elementIds.contains(w.id))
          .map(
            (w) => jsonEncode([
              w.system.toJson(),
              w.railing?.toJson(),
              w.resolvedLayers.map((l) => l.toJson()..remove('id')).toList(),
            ]),
          )
          .toSet();
      pages.add(
        compositions.length > 1 && _composition == null
            ? _scroll([
                Text(l.wallMixedValue),
                const SizedBox(height: 8),
                Text(l.propertiesMixedCompositionHelp),
                TextButton(onPressed: _pickType, child: Text(l.wallChooseType)),
              ])
            : widget.onApplyProject != null
            ? ArchitectWallCompositionEditor(
                key: ValueKey('composition-$_typeVersion'),
                embedded: true,
                editorHandle: _compositionHandle,
                project: widget.project,
                type: _composition ?? _wallType(),
                allowTypeSelection: true,
                plinth: widget.project.activeStorey.walls
                    .firstWhere((w) => widget.elementIds.contains(w.id))
                    .plinth,
                plinths: widget.project.activeStorey.walls
                    .where((w) => widget.elementIds.contains(w.id))
                    .map((w) => w.plinth)
                    .toList(),
                onDraftChanged: (type, region, changed) {
                  if (!changed && (region == null || region.isEmpty)) return;
                  setState(() {
                    _composition = type;
                    _region = region;
                    _compositionChanged = changed;
                  });
                },
                onApply: (type, region, changed) {
                  setState(() {
                    _composition = type;
                    _region = region;
                    _compositionChanged = changed;
                  });
                  return false;
                },
              )
            : _scroll([
                materialField('coreMaterial'),
                const SizedBox(height: 16),
                numberField('coreThickness', true),
                materialField('insulationMaterial'),
                const SizedBox(height: 16),
                numberField('insulationThicknessOverride', true),
                numberField('thickness', true),
              ]),
      );
      pages.add(
        _scroll([
          _choice('exteriorSideMode', l.wallExteriorSideLabel, {
            'automatic': l.wallAutomatic,
            'manual': l.wallManual,
          }),
          OutlinedButton.icon(
            key: const ValueKey('architect-property-flipSide'),
            icon: const AppIcon(AppIconId.flipHorizontal),
            label: Text(l.architectWallFlipSide),
            onPressed: () => setState(() {
              texts['exteriorSideMode'] = 'manual';
              if (_common('exteriorSide') == null) {
                _flipMixed = !_flipMixed;
                return;
              }
              texts['exteriorSide'] =
                  (texts['exteriorSide'] ?? _common('exteriorSide')) == 'right'
                  ? 'left'
                  : 'right';
            }),
          ),
          const SizedBox(height: 16),
          _choice('referenceLine', l.architectWallLeadingLine, {
            'center': l.architectWallReferenceCenter,
            'inner': l.architectWallReferenceInner,
            'outer': l.architectWallReferenceOuter,
          }),
          _choice('cutDisplayMode', l.architectPropertyCutDisplay, {
            'auto': l.architectCutDisplayAuto,
            'projected': l.architectCutDisplayProjected,
            'cut': l.architectCutDisplayCut,
            'overhead': l.architectCutDisplayOverhead,
          }),
          if (records.length == 1 &&
              (records.first['system'] as Map?)?['kind'] == 'sandwichPanels')
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
                    final value = double.tryParse(text.replaceAll(',', '.'));
                    if (value != null && value.isFinite) {
                      updatePanelPlacement({
                        'mountingOffset': widget.project.units.fromUnit(value),
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
                        for (final id
                            in panelPlacement['columnIds'] as List? ?? [])
                          if (widget.project.activeStorey.columns.any(
                            (c) => c.id == id,
                          ))
                            id,
                      ],
                    }),
                    child: Text(l.wallRemoveMissingSupports),
                  ),
                ],
              ],
            ),
        ]),
      );
    }
    return ArchitectPropertiesShell(
      key: _shell,
      title: _title(l),
      subtitle: widget.project.activeStorey.name,
      isDirty: () => _dirty,
      onSave: _save,
      navigation: walls
          ? SizedBox(
              height:
                  48 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: TextButton(
                        key: ValueKey('properties-tab-$i'),
                        style: TextButton.styleFrom(
                          foregroundColor: _tab == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          shape: const RoundedRectangleBorder(),
                        ),
                        onPressed: () => setState(() {
                          _tab = i;
                          if (i > 0) _shell.currentState?.expand();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color: _tab == i
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            [
                              l.propertiesBasic,
                              l.roofUiAssembly,
                              l.propertiesMore,
                            ][i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
      content: Form(
        key: _form,
        onChanged: () => _inputDirty = true,
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: IndexedStack(index: _tab, children: pages),
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
          key: const ValueKey('architect-properties-save'),
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
