import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_roof_settings.dart';
export '../models/architect_roof_settings.dart';
import '../services/architect_element_id.dart';
import 'architect_roof_drainage_editor.dart';
import 'architect_roof_number_field.dart';
import 'architect_roof_layer_editor.dart';
import 'architect_roof_construction_preview.dart';
import 'architect_roof_panel_fields.dart';

class ArchitectRoofLayersDialog extends StatefulWidget {
  final ArchitectRoofAssembly initialAssembly;
  final double initialSlopeDegrees,
      initialEavesOverhang,
      initialUpperSlopeDegrees;
  final ArchitectRoofEavesCut initialEavesCut;
  final double? initialBaseElevationOffset,
      initialManualSupportDistance,
      maxSupportDistance,
      initialBreakDistance;
  final bool initialAttachToWalls, initialIsMansard, canPickDownpipe;
  final ArchitectRoofDrainage initialDrainage;
  final ArchitectProject? project;
  final ArchitectRoofPlane? roof;
  final ValueChanged<ArchitectRoofLayersResult>? onApply;
  final bool Function(ArchitectRoofLayersResult)? onTryApply;
  final int initialTab;
  const ArchitectRoofLayersDialog({
    super.key,
    required this.initialAssembly,
    required this.initialSlopeDegrees,
    required this.initialEavesOverhang,
    required this.initialEavesCut,
    this.initialBaseElevationOffset,
    this.initialAttachToWalls = true,
    this.initialManualSupportDistance,
    this.maxSupportDistance,
    this.initialDrainage = const ArchitectRoofDrainage(),
    this.project,
    this.roof,
    this.canPickDownpipe = false,
    this.onApply,
    this.onTryApply,
    this.initialTab = 0,
    this.initialIsMansard = false,
    this.initialUpperSlopeDegrees = 25,
    this.initialBreakDistance,
  }) : assert(onApply != null || onTryApply != null);
  @override
  State<ArchitectRoofLayersDialog> createState() =>
      _ArchitectRoofLayersDialogState();
}

class _ArchitectRoofLayersDialogState extends State<ArchitectRoofLayersDialog>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  late ArchitectRoofAssembly _assembly = widget.initialAssembly.copyWith();
  late double _slopeDegrees = widget.initialSlopeDegrees,
      _eavesOverhang = widget.initialEavesOverhang;
  late double _upperSlope =
      widget.roof?.upperSlopeDegrees ?? widget.initialUpperSlopeDegrees;
  late double? _breakDistance = widget.roof == null
      ? widget.initialBreakDistance
      : widget.roof!.breakDistance;
  late ArchitectRoofEavesCut _eavesCut = widget.initialEavesCut;
  late double? _baseElevationOffset = widget.initialBaseElevationOffset;
  late bool _attachToWalls = widget.initialAttachToWalls,
      _manualSupport = widget.initialManualSupportDistance != null;
  late double _supportDistance =
      widget.initialManualSupportDistance ?? widget.initialEavesOverhang;
  late ArchitectRoofDrainage _drainage = widget.initialDrainage;
  bool _applyGroup = false, _saveDefaults = false;
  String? _error;
  final _detailControllers = <String, ExpansibleController>{};
  ArchitectUnit get _unit => widget.project?.units ?? ArchitectUnit.centimeters;
  bool get _mansard => widget.roof?.isMansard ?? widget.initialIsMansard;
  int get _groupCount {
    final r = widget.roof, p = widget.project;
    if (r == null ||
        p == null ||
        r.roofGroupId == null ||
        r.roofGroupId!.isEmpty) {
      return 1;
    }
    return p.storeys
        .where((s) => s.id == r.storeyId)
        .expand((s) => s.roofs)
        .where((roof) => roof.roofGroupId == r.roofGroupId)
        .length;
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _detailControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectPreset(ArchitectRoofPreset preset) {
    if (preset == ArchitectRoofPreset.custom) return;
    setState(() {
      _assembly = ArchitectRoofAssembly.fromPreset(preset);
      if (_assembly.panels != null) {
        var spec = _assembly.panels!;
        final columns = [
          for (final floor in widget.project?.storeys ?? <ArchitectStorey>[])
            for (final c in floor.columns)
              if (widget.roof == null ||
                  widget.roof!.bounds.inflate(.3).contains(c.position))
                c.id,
        ];
        spec = spec.copyWith(columnIds: columns);
        _assembly = ArchitectRoofAssembly.panelRoof(spec);
        if (spec.membrane) {
          _slopeDegrees = 2;
        } else if (_slopeDegrees < spec.minimumSlope) {
          _slopeDegrees = 6;
        }
      } else if (_drainage.position == ArchitectGutterPosition.internal) {
        _drainage = _drainage.copyWith(
          position: ArchitectGutterPosition.external,
        );
      }
    });
  }

  String? get _assemblyError {
    if (_assembly.panels != null) {
      final spec = _assembly.panels!;
      if (_slopeDegrees < spec.minimumSlope) {
        return context.l10n.roofPanelSlopeInvalid;
      }
      try {
        spec.validate(slope: _slopeDegrees, mansard: _mansard);
      } on ArgumentError {
        return context.l10n.roofPanelInvalid;
      }
    }
    final zone = _assembly.layers
        .where(
          (l) => l.role == ArchitectRoofLayerRole.rafters || l.isBetweenRafters,
        )
        .toList();
    if (zone.length > 1) return context.l10n.roofUiParallelZone;
    if (_assembly.timber.hasRafters &&
        _assembly.layers.any(
          (l) =>
              l.isBetweenRafters &&
              l.thickness > _assembly.timber.rafterHeight + 1e-9,
        )) {
      return context.l10n.roofUiInsulationFit;
    }
    return null;
  }

  Future<void> _editLayer([int? index]) async {
    final layer = index == null
        ? ArchitectRoofLayer(
            id: ArchitectElementId.next('roof_layer'),
            role: ArchitectRoofLayerRole.insulation,
            material: ArchitectRoofMaterial.mineralWool,
            thickness: .10,
          )
        : _assembly.layers[index];
    final result = await showDialog<RoofLayerEditResult>(
      context: context,
      builder: (_) => RoofLayerEditorDialog(
        layer: layer,
        layers: _assembly.layers,
        index: index,
      ),
    );
    if (!mounted || result == null) return;
    if (index != null &&
        (result.position == index || result.position == index + 1) &&
        jsonEncode(_assembly.layers[index].toJson()) ==
            jsonEncode(result.layer.toJson())) {
      return;
    }
    setState(() {
      final next = [..._assembly.layers];
      if (index != null) next.removeAt(index);
      var position = result.position;
      if (index != null && position > index) position--;
      final zone = result.layer.isBetweenRafters
          ? next.indexWhere((l) => l.role == ArchitectRoofLayerRole.rafters)
          : -1;
      if (zone >= 0) {
        next[zone] = result.layer.copyWith(id: next[zone].id);
      } else {
        next.insert(position.clamp(0, next.length), result.layer);
      }
      var timber = _assembly.timber;
      switch (result.layer.role) {
        case ArchitectRoofLayerRole.battens:
          timber = timber.copyWith(battenHeight: result.layer.thickness);
          break;
        case ArchitectRoofLayerRole.counterBattens:
          timber = timber.copyWith(counterBattenHeight: result.layer.thickness);
          break;
        case ArchitectRoofLayerRole.rafters:
          timber = timber.copyWith(rafterHeight: result.layer.thickness);
          break;
        default:
          break;
      }
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
        timber: timber,
      );
    });
  }

  void _removeLayer(int index) {
    if (_assembly.layers.length <= 1) return;
    setState(() {
      final next = [..._assembly.layers]..removeAt(index);
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
      );
    });
  }

  void _moveLayer(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _assembly.layers.length) return;
    setState(() {
      final next = [..._assembly.layers];
      final item = next.removeAt(index);
      next.insert(to, item);
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
      );
    });
  }

  void _updateTimber(ArchitectRoofTimberSpec next) {
    if (jsonEncode(next.toJson()) == jsonEncode(_assembly.timber.toJson())) {
      return;
    }
    setState(() {
      final old = _assembly.timber;
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        timber: next,
        layers: [
          for (final l in _assembly.layers)
            if (l.role == ArchitectRoofLayerRole.battens &&
                old.battenHeight != next.battenHeight)
              l.copyWith(thickness: next.battenHeight)
            else if (l.role == ArchitectRoofLayerRole.counterBattens &&
                old.counterBattenHeight != next.counterBattenHeight)
              l.copyWith(thickness: next.counterBattenHeight)
            else if (l.role == ArchitectRoofLayerRole.rafters &&
                old.rafterHeight != next.rafterHeight)
              l.copyWith(thickness: next.rafterHeight)
            else
              l,
        ],
      );
    });
  }

  Set<ArchitectRoofSetting> _changes() {
    final result = <ArchitectRoofSetting>{};
    void check(ArchitectRoofSetting key, Object? a, Object? b) {
      if (a != b) result.add(key);
    }

    check(
      ArchitectRoofSetting.assembly,
      jsonEncode(widget.initialAssembly.toJson()),
      jsonEncode(_assembly.toJson()),
    );
    check(
      ArchitectRoofSetting.slope,
      widget.initialSlopeDegrees,
      _slopeDegrees,
    );
    check(
      ArchitectRoofSetting.overhang,
      widget.initialEavesOverhang,
      _eavesOverhang,
    );
    check(ArchitectRoofSetting.eavesCut, widget.initialEavesCut, _eavesCut);
    check(
      ArchitectRoofSetting.elevation,
      widget.initialBaseElevationOffset,
      _baseElevationOffset,
    );
    check(
      ArchitectRoofSetting.attachment,
      widget.initialAttachToWalls,
      _attachToWalls,
    );
    check(
      ArchitectRoofSetting.support,
      widget.initialManualSupportDistance,
      _manualSupport ? _supportDistance : null,
    );
    check(
      ArchitectRoofSetting.upperSlope,
      widget.roof?.upperSlopeDegrees ?? widget.initialUpperSlopeDegrees,
      _upperSlope,
    );
    check(
      ArchitectRoofSetting.breakDistance,
      widget.roof == null
          ? widget.initialBreakDistance
          : widget.roof!.breakDistance,
      _breakDistance,
    );
    final d = widget.initialDrainage;
    check(
      ArchitectRoofSetting.gutterVisible,
      d.showGutter,
      _drainage.showGutter,
    );
    check(
      ArchitectRoofSetting.pipesVisible,
      d.showDownpipes,
      _drainage.showDownpipes,
    );
    check(ArchitectRoofSetting.gutterProfile, d.profile, _drainage.profile);
    check(ArchitectRoofSetting.gutterPosition, d.position, _drainage.position);
    check(ArchitectRoofSetting.gutterMaterial, d.material, _drainage.material);
    check(
      ArchitectRoofSetting.gutterWidth,
      d.gutterWidth,
      _drainage.gutterWidth,
    );
    check(
      ArchitectRoofSetting.gutterDepth,
      d.gutterDepth,
      _drainage.gutterDepth,
    );
    check(
      ArchitectRoofSetting.pipes,
      jsonEncode(d.downpipes.map((p) => p.toJson()).toList()),
      jsonEncode(_drainage.downpipes.map((p) => p.toJson()).toList()),
    );
    return result;
  }

  void _save({bool pickDownpipe = false}) {
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      final field = invalid.first;
      final tab =
          field.context.getInheritedWidgetOfExactType<_RoofTabScope>()?.index ??
          _tabs.index;
      _tabs.animateTo(tab);
      field.context
          .getInheritedWidgetOfExactType<_RoofDetailScope>()
          ?.controller
          .expand();
      setState(() => _error = context.l10n.roofUiNumericInvalid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (field.mounted) {
          Scrollable.ensureVisible(
            field.context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
      return;
    }
    if (_assemblyError != null) {
      _tabs.animateTo(1);
      setState(() => _error = _assemblyError);
      return;
    }
    final result = ArchitectRoofLayersResult(
      assembly: _assembly,
      slopeDegrees: _slopeDegrees,
      eavesOverhang: _eavesOverhang,
      eavesCut: _eavesCut,
      baseElevationOffset: _baseElevationOffset,
      attachToWalls: _attachToWalls,
      manualSupportDistance: _manualSupport ? _supportDistance : null,
      drainage: _drainage,
      pickDownpipe: pickDownpipe,
      upperSlopeDegrees: _upperSlope,
      breakDistance: _breakDistance,
      applyToGroup: _applyGroup,
      saveForNewRoofs: widget.roof == null || _saveDefaults,
      changes: _changes(),
    );
    if (widget.onTryApply != null) {
      if (!widget.onTryApply!(result)) {
        setState(() => _error = context.l10n.roofUiNumericInvalid);
        return;
      }
    } else {
      widget.onApply!(result);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.architectToolRoof,
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: widget.roof == null
                      ? Text(l.roofUiNewScope)
                      : _groupCount > 1
                      ? DropdownButtonFormField<bool>(
                          key: const ValueKey('roof-edit-scope'),
                          initialValue: _applyGroup,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: false,
                              child: Text(l.roofUiOnlyPlane),
                            ),
                            DropdownMenuItem(
                              value: true,
                              child: Text(l.roofUiWholeRoof(_groupCount)),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _applyGroup = v ?? false),
                        )
                      : Text(l.roofUiOnlyPlane),
                ),
                if (widget.roof != null)
                  Tooltip(
                    message: '${l.roofUiScopeHelp}\n${l.roofUiIndependentHelp}',
                    child: const Icon(Icons.info_outline, size: 18),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: l.roofUiShape),
              Tab(text: l.roofUiAssembly),
              Tab(text: l.roofUiDetails),
            ],
          ),
          _preview(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _RoofKeepAlive(child: _RoofTabScope(index: 0, child: _shape())),
                _RoofKeepAlive(
                  child: _RoofTabScope(index: 1, child: _layers()),
                ),
                _RoofKeepAlive(
                  child: _RoofTabScope(index: 2, child: _details()),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('roof-layers-apply'),
                  onPressed: _save,
                  child: Text(l.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: body));
    }
    return Dialog(child: SizedBox(width: 640, height: 800, child: body));
  }

  Widget _construction() => ArchitectRoofConstructionPreview(
    assembly: _assembly,
    slope: _slopeDegrees,
    overhang: _eavesOverhang,
    eavesCut: _eavesCut,
    support: _manualSupport ? _supportDistance : null,
    mansard: _mansard,
    upperSlope: _upperSlope,
    breakDistance: _breakDistance,
    project: widget.project,
    roof: widget.roof,
    drainage: _drainage,
  );

  Widget _preview() {
    final l = context.l10n;
    final label =
        '${l.roofUiPreview} · ${roofNumber(_assembly.totalThickness * 1000)} mm';
    void open() => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: Text(l.roofUiPreview)),
                  IconButton(
                    key: const ValueKey('roof-preview-close'),
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 8,
                  child: _construction(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom <
        440) {
      return SizedBox(
        height: 36,
        child: TextButton.icon(
          key: const ValueKey('roof-preview'),
          onPressed: open,
          icon: const Icon(Icons.zoom_in, size: 18),
          label: Text(label),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        key: const ValueKey('roof-preview'),
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        title: Text(label),
        children: [
          Tooltip(
            message: l.roofUiPreviewHelp,
            child: InkWell(
              onTap: open,
              child: SizedBox(
                height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 80 : 146,
                width: double.infinity,
                child: _construction(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shape() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchitectRoofNumberField(
            key: const ValueKey('roof-slope-input'),
            value: _slopeDegrees,
            label: l.architectRoofSlope,
            unit: '°',
            pitch: true,
            max: 80,
            onChanged: (v) => setState(() => _slopeDegrees = v),
          ),
          if (_mansard) ...[
            ArchitectRoofNumberField(
              key: const ValueKey('roof-upper-slope-input'),
              value: _upperSlope,
              label: l.architectRoofUpperSlope,
              unit: '°',
              pitch: true,
              max: 85,
              onChanged: (v) => setState(() => _upperSlope = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.roofUiAutoBreak),
              value: _breakDistance == null,
              onChanged: (v) => setState(
                () => _breakDistance = v
                    ? null
                    : widget.roof?.effectiveBreakDistance ?? 1.8,
              ),
            ),
            if (_breakDistance != null)
              ArchitectRoofNumberField(
                key: const ValueKey('roof-break-input'),
                value: _unit.toUnit(_breakDistance!),
                label: l.architectRoofBreakDistance,
                unit: _unit.symbol,
                min: _unit.toUnit(widget.roof?.minimumBreakDistance ?? .10),
                max: widget.roof == null
                    ? double.infinity
                    : _unit.toUnit(widget.roof!.maximumBreakDistance),
                onChanged: (v) =>
                    setState(() => _breakDistance = _unit.fromUnit(v)),
              ),
          ],
          // This is a creation/datum parameter, not a measured distance from
          // the current polygon to the facade. Existing contours are edited
          // directly in plan, so do not present this stale nominal as a ruler.
          if (widget.roof == null)
            ArchitectRoofNumberField(
              key: const ValueKey('roof-overhang-input'),
              value: _unit.toUnit(_eavesOverhang),
              label: l.architectRoofOverhang,
              unit: _unit.symbol,
              onChanged: (v) =>
                  setState(() => _eavesOverhang = _unit.fromUnit(v)),
            ),
          if (_baseElevationOffset != null)
            ArchitectRoofNumberField(
              key: const ValueKey('roof-elevation-input'),
              value: _unit.toUnit(_baseElevationOffset!),
              label: l.architectRoofBaseElev,
              unit: _unit.symbol,
              min: -double.infinity,
              onChanged: (v) => setState(() {
                _baseElevationOffset = _unit.fromUnit(v);
                _attachToWalls = false;
              }),
            ),
          Tooltip(
            message: _assembly.panels == null
                ? l.architectRoofAlignOnceHelp
                : l.architectRoofAttachToWallsSubtitle,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _assembly.panels == null
                    ? l.architectRoofAlignOnce
                    : l.architectRoofAttachToWalls,
              ),
              value: _attachToWalls,
              onChanged: (v) => setState(() => _attachToWalls = v),
            ),
          ),
          Tooltip(
            message: l.architectRoofManualSupportHelp,
            child: CheckboxListTile(
              key: const ValueKey('roof-manual-support'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.architectRoofManualSupport),
              value: _manualSupport,
              onChanged: (v) => setState(() => _manualSupport = v ?? false),
            ),
          ),
          if (_manualSupport)
            ArchitectRoofNumberField(
              key: const ValueKey('roof-support-distance'),
              value: _unit.toUnit(_supportDistance),
              label: l.architectRoofSupportDistance,
              invalidMessage: l.architectRoofSupportDistanceInvalid,
              unit: _unit.symbol,
              max: widget.maxSupportDistance == null
                  ? double.infinity
                  : _unit.toUnit(widget.maxSupportDistance!),
              validate: (v) =>
                  v < 0 ? l.architectRoofSupportDistanceInvalid : null,
              onChanged: (v) =>
                  setState(() => _supportDistance = _unit.fromUnit(v)),
            ),
        ],
      ),
    );
  }

  Widget _layers() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ArchitectRoofPreset>(
            key: ValueKey('roof-preset-${_assembly.preset.name}'),
            initialValue: _assembly.preset,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.roofUiAssembly),
            items: [
              for (final p in ArchitectRoofPreset.values)
                if (p != ArchitectRoofPreset.custom || _assembly.preset == p)
                  DropdownMenuItem(
                    value: p,
                    enabled: p != ArchitectRoofPreset.custom,
                    child: Text(p.label(l), overflow: TextOverflow.ellipsis),
                  ),
            ],
            onChanged: (p) {
              if (p != null) _selectPreset(p);
            },
          ),
          if (_assembly.panels != null)
            ArchitectRoofPanelFields(
              value: _assembly.panels!,
              project: widget.project,
              onChanged: (p) => setState(
                () => _assembly = ArchitectRoofAssembly.panelRoof(p),
              ),
            )
          else
            for (var i = 0; i < _assembly.layers.length; i++)
              _buildLayerTile(context, i, _assembly.layers[i]),
          if (_assembly.panels == null)
            TextButton.icon(
              key: const ValueKey('roof-add-layer'),
              onPressed: () => _editLayer(),
              icon: const Icon(Icons.add),
              label: Text(l.slabAddLayer),
            ),
          if (_assemblyError != null)
            Text(
              _assemblyError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildLayerTile(
    BuildContext context,
    int index,
    ArchitectRoofLayer layer,
  ) {
    final l = context.l10n;
    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          key: ValueKey('roof-layer-${layer.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(layer.material.label(l)),
          subtitle: Text(
            '${layer.role.label(l)}${layer.isBetweenRafters ? ' · ${l.roofUiBetween}' : ''}',
          ),
          onTap: () => _editLayer(index),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${roofNumber(layer.thickness * 1000)} mm'),
              PopupMenuButton<String>(
                key: ValueKey('roof-layer-actions-${layer.id}'),
                tooltip: l.roofUiLayerActions,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(l.roofUiLayerEdit)),
                  PopupMenuItem(
                    value: 'up',
                    enabled: index > 0,
                    child: Text(l.wallLayerUp),
                  ),
                  PopupMenuItem(
                    value: 'down',
                    enabled: index + 1 < _assembly.layers.length,
                    child: Text(l.wallLayerDown),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: _assembly.layers.length > 1,
                    child: Text(l.delete),
                  ),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      _editLayer(index);
                    case 'up':
                      _moveLayer(index, -1);
                    case 'down':
                      _moveLayer(index, 1);
                    case 'delete':
                      _removeLayer(index);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _details() {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_assembly.panels == null) _buildTimberTab(context),
          if (_assembly.panels == null)
            ExpansionTile(
              controller: _detailControllers.putIfAbsent(
                'eaves',
                ExpansibleController.new,
              ),
              tilePadding: EdgeInsets.zero,
              title: Text(l.architectRoofEavesCutLabel),
              children: [
                DropdownButtonFormField<ArchitectRoofEavesCut>(
                  initialValue: _eavesCut,
                  isExpanded: true,
                  items: [
                    for (final c in ArchitectRoofEavesCut.values)
                      DropdownMenuItem(value: c, child: Text(c.label(l))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _eavesCut = v);
                  },
                ),
              ],
            ),
          ExpansionTile(
            key: const ValueKey('roof-drainage-section'),
            controller: _detailControllers.putIfAbsent(
              'drainage',
              ExpansibleController.new,
            ),
            maintainState: true,
            tilePadding: EdgeInsets.zero,
            title: Text(l.architectDrainageTitle),
            children: [
              _RoofDetailScope(
                controller: _detailControllers['drainage']!,
                child: ArchitectRoofDrainageEditor(
                  allowInternal: _assembly.panels != null,
                  value: _drainage,
                  project: widget.project,
                  roof: widget.roof,
                  embedded: true,
                  onChanged: (v) => setState(() => _drainage = v),
                  onPlace: widget.canPickDownpipe
                      ? () => _save(pickDownpipe: true)
                      : null,
                ),
              ),
            ],
          ),
          if (widget.roof != null)
            CheckboxListTile(
              key: const ValueKey('roof-save-defaults'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.roofUiSaveDefaults),
              value: _saveDefaults,
              onChanged: (v) => setState(() => _saveDefaults = v ?? false),
            ),
        ],
      ),
    );
  }

  Widget _buildTimberTab(BuildContext context) {
    final l = context.l10n;
    final t = _assembly.timber;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Battens (Летви)
          _buildTimberCard(
            title: l.architectRoofBattensLabel,
            subtitle:
                '${roofNumber(t.battenWidth * 100)}×${roofNumber(t.battenHeight * 100)} cm · ${l.architectRoofStepLabel} ${roofNumber(t.battenSpacing * 100)} cm',
            enabled: t.hasBattens,
            onToggle: (v) => _updateTimber(t.copyWith(hasBattens: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyWidth,
                      unit: 'cm',
                      value: (t.battenWidth * 100),
                      min: 3.0,
                      max: 10.0,
                      divisions: 7,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(battenWidth: v / 100.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyHeight,
                      unit: 'cm',
                      value: (t.battenHeight * 100),
                      min: 2.0,
                      max: 8.0,
                      divisions: 6,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(battenHeight: v / 100.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectRoofStepLabel,
                      unit: 'cm',
                      value: (t.battenSpacing * 100),
                      min: 20.0,
                      max: 50.0,
                      divisions: 30,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(battenSpacing: v / 100.0)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Counter-battens (Контралетви)
          _buildTimberCard(
            title: l.architectRoofCounterBattensLabel,
            subtitle:
                '${roofNumber(t.counterBattenWidth * 100)}×${roofNumber(t.counterBattenHeight * 100)} cm',
            enabled: t.hasCounterBattens,
            onToggle: (v) => _updateTimber(t.copyWith(hasCounterBattens: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyWidth,
                      unit: 'cm',
                      value: (t.counterBattenWidth * 100),
                      min: 3.0,
                      max: 10.0,
                      divisions: 7,
                      onChanged: (v) => _updateTimber(
                        t.copyWith(counterBattenWidth: v / 100.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyHeight,
                      unit: 'cm',
                      value: (t.counterBattenHeight * 100),
                      min: 2.0,
                      max: 8.0,
                      divisions: 6,
                      onChanged: (v) => _updateTimber(
                        t.copyWith(counterBattenHeight: v / 100.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Rafters (Ребра)
          _buildTimberCard(
            title: l.architectRoofRaftersLabel,
            subtitle:
                '${roofNumber(t.rafterWidth * 100)}×${roofNumber(t.rafterHeight * 100)} cm · ${l.architectRoofStepLabel} ${roofNumber(t.rafterSpacing * 100)} cm',
            enabled: t.hasRafters,
            onToggle: (v) => _updateTimber(t.copyWith(hasRafters: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyWidth,
                      unit: 'cm',
                      value: (t.rafterWidth * 100),
                      min: 6.0,
                      max: 16.0,
                      divisions: 10,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(rafterWidth: v / 100.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyHeight,
                      unit: 'cm',
                      value: (t.rafterHeight * 100),
                      min: 10.0,
                      max: 26.0,
                      divisions: 16,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(rafterHeight: v / 100.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectRoofStepLabel,
                      unit: 'cm',
                      value: (t.rafterSpacing * 100),
                      min: 40.0,
                      max: 100.0,
                      divisions: 12,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(rafterSpacing: v / 100.0)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4. Wall Plate / Mauerlat (Мауерлат)
          _buildTimberCard(
            title: l.architectRoofWallPlateLabel,
            subtitle:
                '${roofNumber(t.wallPlateWidth * 100)}×${roofNumber(t.wallPlateHeight * 100)} cm',
            enabled: t.hasWallPlate,
            onToggle: (v) => _updateTimber(t.copyWith(hasWallPlate: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyWidth,
                      unit: 'cm',
                      value: (t.wallPlateWidth * 100),
                      min: 10.0,
                      max: 24.0,
                      divisions: 14,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(wallPlateWidth: v / 100.0)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyHeight,
                      unit: 'cm',
                      value: (t.wallPlateHeight * 100),
                      min: 10.0,
                      max: 24.0,
                      divisions: 14,
                      onChanged: (v) =>
                          _updateTimber(t.copyWith(wallPlateHeight: v / 100.0)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4b. Reinforced Concrete Ring Beam under Wall Plate (10 см стоманобетонен пояс)
          _buildTimberCard(
            title: l.architectRoofRingBeamLabel,
            subtitle:
                '${l.architectPropertyHeight}: ${roofNumber(t.ringBeamHeight * 100)} cm',
            enabled: t.hasRingBeam,
            onToggle: (v) => _updateTimber(t.copyWith(hasRingBeam: v)),
            children: [
              _buildCompactSliderField(
                label: l.architectPropertyHeight,
                unit: 'cm',
                value: (t.ringBeamHeight * 100),
                min: 5.0,
                max: 25.0,
                divisions: 20,
                onChanged: (v) =>
                    _updateTimber(t.copyWith(ringBeamHeight: v / 100.0)),
              ),
            ],
          ),

          // 5. Ridge Purlin (Билова столица)
          _buildTimberCard(
            title: l.architectRoofRidgePurlinLabel,
            subtitle:
                '${roofNumber(t.ridgePurlinWidth * 100)}×${roofNumber(t.ridgePurlinHeight * 100)} cm',
            enabled: t.hasRidgePurlin,
            onToggle: (v) => _updateTimber(t.copyWith(hasRidgePurlin: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyWidth,
                      unit: 'cm',
                      value: (t.ridgePurlinWidth * 100),
                      min: 12.0,
                      max: 24.0,
                      divisions: 12,
                      onChanged: (v) => _updateTimber(
                        t.copyWith(ridgePurlinWidth: v / 100.0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactSliderField(
                      label: l.architectPropertyHeight,
                      unit: 'cm',
                      value: (t.ridgePurlinHeight * 100),
                      min: 14.0,
                      max: 30.0,
                      divisions: 16,
                      onChanged: (v) => _updateTimber(
                        t.copyWith(ridgePurlinHeight: v / 100.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 6. Fascia Board & Metal Flashing (Челна дъска и метална обшивка)
          _buildTimberCard(
            title: l.architectRoofFasciaLabel,
            subtitle: '${roofNumber(t.fasciaThickness * 1000)} mm',
            enabled: t.hasFasciaBoard,
            onToggle: (v) => _updateTimber(t.copyWith(hasFasciaBoard: v)),
            children: [
              _buildCompactSliderField(
                label: l.architectPropertyThickness,
                unit: 'mm',
                value: (t.fasciaThickness * 1000),
                min: 18.0,
                max: 40.0,
                divisions: 22,
                onChanged: (v) =>
                    _updateTimber(t.copyWith(fasciaThickness: v / 1000.0)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.architectRoofMetalFlashingLabel),
                value: t.hasMetalFlashing,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: (v) =>
                    _updateTimber(t.copyWith(hasMetalFlashing: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimberCard({
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required List<Widget> children,
  }) {
    final controller = _detailControllers.putIfAbsent(
      title,
      ExpansibleController.new,
    );
    return ExpansionTile(
      controller: controller,
      maintainState: true,
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: enabled, onChanged: onToggle),
      children: enabled
          ? [
              _RoofDetailScope(
                controller: controller,
                child: Column(children: children),
              ),
            ]
          : const [],
    );
  }

  Widget _buildCompactSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String unit = 'cm',
  }) => ArchitectRoofNumberField(
    value: value,
    label: label,
    unit: unit,
    min: .000001,
    onChanged: onChanged,
  );
}

class _RoofDetailScope extends InheritedWidget {
  final ExpansibleController controller;
  const _RoofDetailScope({required this.controller, required super.child});
  @override
  bool updateShouldNotify(_RoofDetailScope old) => controller != old.controller;
}

class _RoofTabScope extends InheritedWidget {
  final int index;
  const _RoofTabScope({required this.index, required super.child});
  @override
  bool updateShouldNotify(_RoofTabScope old) => index != old.index;
}

class _RoofKeepAlive extends StatefulWidget {
  final Widget child;
  const _RoofKeepAlive({required this.child});
  @override
  State<_RoofKeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_RoofKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
