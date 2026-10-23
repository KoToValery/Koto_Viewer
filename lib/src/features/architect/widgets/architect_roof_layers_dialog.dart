// === SECTION: TABLE OF CONTENTS ===
// 1. ArchitectRoofLayersDialog (Dialog for roof assembly layers, presets & timber carpentry)
// 2. _RoofLayersPreviewPainter (Interactive cross-section diagram of layers, battens, rafters, Mauerlat)
// 3. _RoofLayerEditorDialog (Modal dialog to add/edit an individual roof layer)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_element_id.dart';
import 'architect_roof_drainage_editor.dart';

// === SECTION: ARCHITECT ROOF LAYERS DIALOG ===

class ArchitectRoofLayersResult {
  final ArchitectRoofAssembly assembly;
  final double slopeDegrees;
  final double eavesOverhang;
  final ArchitectRoofEavesCut eavesCut;
  final double? baseElevationOffset;
  final bool attachToWalls;
  final double? manualSupportDistance;
  final ArchitectRoofDrainage drainage;
  final bool pickDownpipe;

  const ArchitectRoofLayersResult({
    required this.assembly,
    required this.slopeDegrees,
    required this.eavesOverhang,
    required this.eavesCut,
    this.baseElevationOffset,
    this.attachToWalls = true,
    this.manualSupportDistance,
    this.drainage = const ArchitectRoofDrainage(),
    this.pickDownpipe = false,
  });
}

class ArchitectRoofLayersDialog extends StatefulWidget {
  final ArchitectRoofAssembly initialAssembly;
  final double initialSlopeDegrees;
  final double initialEavesOverhang;
  final ArchitectRoofEavesCut initialEavesCut;
  final double? initialBaseElevationOffset;
  final bool initialAttachToWalls;
  final double? initialManualSupportDistance;
  final double? maxSupportDistance;
  final ArchitectRoofDrainage initialDrainage;
  final ArchitectProject? project;
  final ArchitectRoofPlane? roof;
  final bool canPickDownpipe;
  final ValueChanged<ArchitectRoofLayersResult> onApply;

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
    required this.onApply,
  });

  @override
  State<ArchitectRoofLayersDialog> createState() =>
      _ArchitectRoofLayersDialogState();
}

class _ArchitectRoofLayersDialogState extends State<ArchitectRoofLayersDialog> {
  late ArchitectRoofAssembly _assembly;
  late double _slopeDegrees;
  late double _eavesOverhang;
  late ArchitectRoofEavesCut _eavesCut;
  late double? _baseElevationOffset;
  late bool _attachToWalls;
  late bool _manualSupport;
  late final TextEditingController _supportDistance;
  final _supportField = GlobalKey<FormFieldState<String>>();
  final _drainageForm = GlobalKey<FormState>();
  late ArchitectRoofDrainage _drainage;

  @override
  void initState() {
    super.initState();
    _drainage = widget.initialDrainage;
    _assembly = widget.initialAssembly.copyWith();
    _slopeDegrees = widget.initialSlopeDegrees;
    _eavesOverhang = widget.initialEavesOverhang;
    _eavesCut = widget.initialEavesCut;
    _baseElevationOffset = widget.initialBaseElevationOffset;
    _attachToWalls = widget.initialAttachToWalls;
    _manualSupport = widget.initialManualSupportDistance != null;
    _supportDistance = TextEditingController(
      text: ((widget.initialManualSupportDistance ?? _eavesOverhang) * 100)
          .toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _supportDistance.dispose();
    super.dispose();
  }

  void _selectPreset(ArchitectRoofPreset preset) {
    setState(() {
      _assembly = ArchitectRoofAssembly.fromPreset(preset);
      if (preset == ArchitectRoofPreset.flatWarm && _slopeDegrees > 5.0) {
        _slopeDegrees = 1.5;
        _eavesOverhang = 0.0;
      } else if (preset != ArchitectRoofPreset.flatWarm &&
          _slopeDegrees < 5.0) {
        _slopeDegrees = 22.0;
        if (_eavesOverhang == 0.0) _eavesOverhang = 0.50;
      }
    });
  }

  Future<void> _editLayer([int? index]) async {
    final existing = index != null
        ? _assembly.layers[index]
        : ArchitectRoofLayer(
            id: ArchitectElementId.next('roof_layer'),
            role: ArchitectRoofLayerRole.insulation,
            material: ArchitectRoofMaterial.mineralWool,
            thickness: 0.10,
          );
    final result = await showDialog<ArchitectRoofLayer>(
      context: context,
      builder: (_) => _RoofLayerEditorDialog(layer: existing),
    );
    if (!mounted || result == null) return;
    setState(() {
      final next = List<ArchitectRoofLayer>.from(_assembly.layers);
      if (index == null) {
        next.add(result);
      } else {
        next[index] = result;
      }
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
      );
    });
  }

  void _removeLayer(int index) {
    if (_assembly.layers.length <= 1) return;
    setState(() {
      final next = List<ArchitectRoofLayer>.from(_assembly.layers)
        ..removeAt(index);
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
      );
    });
  }

  void _moveLayer(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _assembly.layers.length) return;
    setState(() {
      final next = List<ArchitectRoofLayer>.from(_assembly.layers);
      final item = next.removeAt(index);
      next.insert(target, item);
      _assembly = _assembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: next,
      );
    });
  }

  void _updateTimber(ArchitectRoofTimberSpec nextTimber) {
    setState(() {
      _assembly = _assembly.copyWith(timber: nextTimber);
    });
  }

  String? _validateSupportDistance(String? text) {
    final cm = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
    if (cm == null ||
        !cm.isFinite ||
        cm < 0 ||
        (widget.maxSupportDistance != null &&
            cm / 100 > widget.maxSupportDistance!)) {
      return context.l10n.architectRoofSupportDistanceInvalid;
    }
    return null;
  }

  void _save({bool pickDownpipe = false}) {
    if (!(_drainageForm.currentState?.validate() ?? true)) return;
    if (_manualSupport &&
        _validateSupportDistance(_supportDistance.text) != null) {
      _supportField.currentState?.validate();
      return;
    }
    widget.onApply(
      ArchitectRoofLayersResult(
        drainage: _drainage,
        pickDownpipe: pickDownpipe,
        assembly: _assembly,
        slopeDegrees: _slopeDegrees,
        eavesOverhang: _eavesOverhang,
        eavesCut: _eavesCut,
        baseElevationOffset: _baseElevationOffset,
        attachToWalls: _attachToWalls,
        manualSupportDistance: _manualSupport
            ? double.parse(_supportDistance.text.trim().replaceAll(',', '.')) /
                  100
            : null,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFF1E222B),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.roofing_rounded,
                      color: Color(0xFF00E5FF),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.architectToolRoof,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                labelStyle: const TextStyle(fontSize: 12),
                indicatorColor: const Color(0xFF00E5FF),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.layers_rounded, size: 18),
                    text: l.slabLayers,
                  ),
                  Tab(
                    icon: const Icon(Icons.carpenter_rounded, size: 18),
                    text: l.architectRoofTimberTab,
                  ),
                  Tab(
                    icon: const Icon(Icons.water_drop_outlined, size: 18),
                    text: l.architectDrainageTitle,
                  ),
                ],
              ),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14171E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: CustomPaint(
                      painter: _RoofLayersPreviewPainter(
                        assembly: _assembly,
                        slopeDegrees: _slopeDegrees,
                        eavesCut: _eavesCut,
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: TabBarView(
                  children: [
                    _buildLayersTab(context),
                    _buildTimberTab(context),
                    Form(
                      key: _drainageForm,
                      child: ArchitectRoofDrainageEditor(
                        value: _drainage,
                        project: widget.project,
                        roof: widget.roof,
                        onChanged: (v) => setState(() => _drainage = v),
                        onPlace: widget.canPickDownpipe
                            ? () => _save(pickDownpipe: true)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey('roof-layers-apply'),
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l.save),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayersTab(BuildContext context) {
    final l = context.l10n;
    final totalCm = (_assembly.totalThickness * 100).toStringAsFixed(1);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ArchitectRoofPreset>(
            key: ValueKey('roof-preset-${_assembly.preset.name}'),
            initialValue: _assembly.preset,
            isExpanded: true,
            dropdownColor: const Color(0xFF262A34),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: l.architectRoofSectionDetailTitle,
              labelStyle: const TextStyle(color: Colors.white70),
              isDense: true,
            ),
            items: [
              for (final preset in ArchitectRoofPreset.values)
                DropdownMenuItem(
                  value: preset,
                  child: Text(
                    preset.label(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) _selectPreset(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactSliderField(
                  label:
                      '${l.architectRoofSlope}: ${_slopeDegrees.toStringAsFixed(1)}° (${(math.tan(_slopeDegrees * math.pi / 180) * 100).round()}%)',
                  value: _slopeDegrees.clamp(0.0, 60.0),
                  min: 0.0,
                  max: 60.0,
                  divisions: 120,
                  onChanged: (v) => setState(() => _slopeDegrees = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactSliderField(
                  label:
                      '${l.architectRoofOverhang}: ${(_eavesOverhang * 100).round()} cm',
                  value: (_eavesOverhang * 100).clamp(0.0, 150.0),
                  min: 0.0,
                  max: 150.0,
                  divisions: 30,
                  onChanged: (v) => setState(() => _eavesOverhang = v / 100.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: l.architectRoofManualSupportHelp,
            child: CheckboxListTile(
              key: const ValueKey('roof-manual-support'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l.architectRoofManualSupport,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              value: _manualSupport,
              activeColor: const Color(0xFF00E5FF),
              checkColor: Colors.black,
              onChanged: (value) =>
                  setState(() => _manualSupport = value ?? false),
            ),
          ),
          if (_manualSupport) ...[
            TextFormField(
              key: _supportField,
              controller: _supportDistance,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: l.architectRoofSupportDistance,
                suffixText: 'cm',
                labelStyle: const TextStyle(color: Colors.white70),
                isDense: true,
              ),
              validator: _validateSupportDistance,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ArchitectRoofEavesCut>(
                  initialValue: _eavesCut,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF262A34),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: l.architectRoofEavesCutLabel,
                    labelStyle: const TextStyle(color: Colors.white70),
                    isDense: true,
                  ),
                  items: [
                    for (final cut in ArchitectRoofEavesCut.values)
                      DropdownMenuItem(
                        value: cut,
                        child: Text(
                          cut.label(l),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _eavesCut = v);
                  },
                ),
              ),
              if (_baseElevationOffset != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactSliderField(
                    label:
                        '${l.architectRoofBaseElev}: ${_baseElevationOffset!.toStringAsFixed(2)} m',
                    value: _baseElevationOffset!.clamp(0.0, 6.0),
                    min: 0.0,
                    max: 6.0,
                    divisions: 120,
                    onChanged: (v) => setState(() {
                      _baseElevationOffset = v;
                      _attachToWalls = false;
                    }),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              l.architectRoofAttachToWalls,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              l.architectRoofAttachToWallsSubtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            value: _attachToWalls,
            activeThumbColor: const Color(0xFF00E5FF),
            onChanged: (v) => setState(() => _attachToWalls = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.slabLayers} ($totalCm cm)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('roof-add-layer'),
                onPressed: () => _editLayer(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.slabAddLayer),
              ),
            ],
          ),
          for (var i = 0; i < _assembly.layers.length; i++)
            _buildLayerTile(context, i, _assembly.layers[i]),
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
    final mm = (layer.thickness * 1000).round();
    return Card(
      color: const Color(0xFF262A34),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: CircleAvatar(
          radius: 12,
          backgroundColor: _materialColor(layer.material),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${layer.role.label(l)} · ${layer.material.label(l)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
        subtitle: Text(
          '$mm mm${layer.isBetweenRafters ? ' (${l.architectRoofRaftersLabel})' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.arrow_upward,
                size: 16,
                color: Colors.white70,
              ),
              onPressed: index > 0 ? () => _moveLayer(index, -1) : null,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.arrow_downward,
                size: 16,
                color: Colors.white70,
              ),
              onPressed: index < _assembly.layers.length - 1
                  ? () => _moveLayer(index, 1)
                  : null,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: Colors.cyanAccent,
              ),
              onPressed: () => _editLayer(index),
            ),
            if (_assembly.layers.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.redAccent,
                ),
                onPressed: () => _removeLayer(index),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimberTab(BuildContext context) {
    final l = context.l10n;
    final t = _assembly.timber;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Battens (Летви)
          _buildTimberCard(
            title: l.architectRoofBattensLabel,
            subtitle:
                '${(t.battenWidth * 100).round()}×${(t.battenHeight * 100).round()} cm · ${l.architectRoofStepLabel} ${(t.battenSpacing * 100).round()} cm',
            enabled: t.hasBattens,
            onToggle: (v) => _updateTimber(t.copyWith(hasBattens: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label:
                          '${l.architectPropertyWidth}: ${(t.battenWidth * 100).round()} cm',
                      value: (t.battenWidth * 100).clamp(3.0, 10.0),
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
                      label:
                          '${l.architectPropertyHeight}: ${(t.battenHeight * 100).round()} cm',
                      value: (t.battenHeight * 100).clamp(2.0, 8.0),
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
                      label:
                          '${l.architectRoofStepLabel}: ${(t.battenSpacing * 100).round()} cm',
                      value: (t.battenSpacing * 100).clamp(20.0, 50.0),
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
                '${(t.counterBattenWidth * 100).round()}×${(t.counterBattenHeight * 100).round()} cm',
            enabled: t.hasCounterBattens,
            onToggle: (v) => _updateTimber(t.copyWith(hasCounterBattens: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label:
                          '${l.architectPropertyWidth}: ${(t.counterBattenWidth * 100).round()} cm',
                      value: (t.counterBattenWidth * 100).clamp(3.0, 10.0),
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
                      label:
                          '${l.architectPropertyHeight}: ${(t.counterBattenHeight * 100).round()} cm',
                      value: (t.counterBattenHeight * 100).clamp(2.0, 8.0),
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
                '${(t.rafterWidth * 100).round()}×${(t.rafterHeight * 100).round()} cm · ${l.architectRoofStepLabel} ${(t.rafterSpacing * 100).round()} cm',
            enabled: t.hasRafters,
            onToggle: (v) => _updateTimber(t.copyWith(hasRafters: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label:
                          '${l.architectPropertyWidth}: ${(t.rafterWidth * 100).round()} cm',
                      value: (t.rafterWidth * 100).clamp(6.0, 16.0),
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
                      label:
                          '${l.architectPropertyHeight}: ${(t.rafterHeight * 100).round()} cm',
                      value: (t.rafterHeight * 100).clamp(10.0, 26.0),
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
                      label:
                          '${l.architectRoofStepLabel}: ${(t.rafterSpacing * 100).round()} cm',
                      value: (t.rafterSpacing * 100).clamp(40.0, 100.0),
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
                '${(t.wallPlateWidth * 100).round()}×${(t.wallPlateHeight * 100).round()} cm',
            enabled: t.hasWallPlate,
            onToggle: (v) => _updateTimber(t.copyWith(hasWallPlate: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label:
                          '${l.architectPropertyWidth}: ${(t.wallPlateWidth * 100).round()} cm',
                      value: (t.wallPlateWidth * 100).clamp(10.0, 24.0),
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
                      label:
                          '${l.architectPropertyHeight}: ${(t.wallPlateHeight * 100).round()} cm',
                      value: (t.wallPlateHeight * 100).clamp(10.0, 24.0),
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
                '${l.architectPropertyHeight}: ${(t.ringBeamHeight * 100).round()} cm',
            enabled: t.hasRingBeam,
            onToggle: (v) => _updateTimber(t.copyWith(hasRingBeam: v)),
            children: [
              _buildCompactSliderField(
                label:
                    '${l.architectPropertyHeight}: ${(t.ringBeamHeight * 100).round()} cm',
                value: (t.ringBeamHeight * 100).clamp(5.0, 25.0),
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
                '${(t.ridgePurlinWidth * 100).round()}×${(t.ridgePurlinHeight * 100).round()} cm',
            enabled: t.hasRidgePurlin,
            onToggle: (v) => _updateTimber(t.copyWith(hasRidgePurlin: v)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCompactSliderField(
                      label:
                          '${l.architectPropertyWidth}: ${(t.ridgePurlinWidth * 100).round()} cm',
                      value: (t.ridgePurlinWidth * 100).clamp(12.0, 24.0),
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
                      label:
                          '${l.architectPropertyHeight}: ${(t.ridgePurlinHeight * 100).round()} cm',
                      value: (t.ridgePurlinHeight * 100).clamp(14.0, 30.0),
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
            subtitle: '${(t.fasciaThickness * 1000).round()} mm',
            enabled: t.hasFasciaBoard,
            onToggle: (v) => _updateTimber(t.copyWith(hasFasciaBoard: v)),
            children: [
              _buildCompactSliderField(
                label:
                    '${l.architectPropertyThickness}: ${(t.fasciaThickness * 1000).round()} mm',
                value: (t.fasciaThickness * 1000).clamp(18.0, 40.0),
                min: 18.0,
                max: 40.0,
                divisions: 22,
                onChanged: (v) =>
                    _updateTimber(t.copyWith(fasciaThickness: v / 1000.0)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  l.architectRoofMetalFlashingLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
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
    return Card(
      color: const Color(0xFF262A34),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeThumbColor: const Color(0xFF00E5FF),
                  onChanged: onToggle,
                ),
              ],
            ),
            if (enabled) ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFF00E5FF),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  static Color _materialColor(ArchitectRoofMaterial material) =>
      switch (material) {
        ArchitectRoofMaterial.clayTiles => const Color(0xFFC85A32),
        ArchitectRoofMaterial.concreteTiles => const Color(0xFF7D848C),
        ArchitectRoofMaterial.metalSeam => const Color(0xFF546E7A),
        ArchitectRoofMaterial.bitumenShingles => const Color(0xFF455A64),
        ArchitectRoofMaterial.timberBoarding => const Color(0xFFD7A86E),
        ArchitectRoofMaterial.osb => const Color(0xFFC59B5F),
        ArchitectRoofMaterial.breathableMembrane => const Color(0xFF29B6F6),
        ArchitectRoofMaterial.vapourBarrier => const Color(0xFFAB47BC),
        ArchitectRoofMaterial.mineralWool => const Color(0xFFFFD54F),
        ArchitectRoofMaterial.xps => const Color(0xFF4DD0E1),
        ArchitectRoofMaterial.waterproofing => const Color(0xFF37474F),
        ArchitectRoofMaterial.slopeScreed => const Color(0xFF90A4AE),
        ArchitectRoofMaterial.rcSlab => const Color(0xFF78909C),
        ArchitectRoofMaterial.plasterboard => const Color(0xFFECEFF1),
      };
}

// === SECTION: ROOF LAYERS PREVIEW PAINTER ===

class _RoofLayersPreviewPainter extends CustomPainter {
  final ArchitectRoofAssembly assembly;
  final double slopeDegrees;
  final ArchitectRoofEavesCut eavesCut;

  const _RoofLayersPreviewPainter({
    required this.assembly,
    required this.slopeDegrees,
    required this.eavesCut,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 10 || size.height <= 10) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final angle = (slopeDegrees.clamp(0.0, 35.0)) * math.pi / 180.0;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final dir = Offset(cosA, -sinA);
    final normalUp = Offset(-sinA, -cosA);

    final scale = 190.0; // pixels per metre
    final eavesPt = Offset(38, size.height - 22);
    final runLength = (size.width - 76) / math.max(cosA, 0.5);

    // Draw supporting wall, 10 cm concrete ring beam & Mauerlat preview on the left
    final wallX = eavesPt.dx + 0.35 * scale * cosA;
    final wallBottomY = size.height;
    final rafterUndersideY = eavesPt.dy - 0.35 * scale * sinA;
    final mh = assembly.timber.hasWallPlate
        ? assembly.timber.wallPlateHeight * scale
        : 0.0;
    final rbh = assembly.timber.hasRingBeam
        ? assembly.timber.ringBeamHeight * scale
        : 0.0;
    final wallTopY = rafterUndersideY + mh + rbh;
    final wallW = 0.25 * scale;
    final wallRect = Rect.fromLTRB(
      wallX - wallW / 2,
      wallTopY,
      wallX + wallW / 2,
      wallBottomY,
    );
    canvas.drawRect(wallRect, Paint()..color = const Color(0xFF546E7A));
    canvas.drawRect(
      wallRect,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (assembly.timber.hasRingBeam) {
      final rbRect = Rect.fromLTRB(
        wallX - wallW / 2,
        wallTopY - rbh,
        wallX + wallW / 2,
        wallTopY,
      );
      canvas.drawRect(rbRect, Paint()..color = const Color(0xFF78909C));
      canvas.drawRect(
        rbRect,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    if (assembly.timber.hasWallPlate) {
      final mw = assembly.timber.wallPlateWidth * scale;
      final mRect = Rect.fromLTWH(wallX - mw / 2, rafterUndersideY, mw, mh);
      canvas.drawRect(mRect, Paint()..color = const Color(0xFFC68B59));
      canvas.drawRect(
        mRect,
        Paint()
          ..color = const Color(0xFF4E342E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawLine(
        mRect.topLeft,
        mRect.bottomRight,
        Paint()
          ..color = const Color(0xFF4E342E)
          ..strokeWidth = 1.0,
      );
      canvas.drawLine(
        mRect.bottomLeft,
        mRect.topRight,
        Paint()
          ..color = const Color(0xFF4E342E)
          ..strokeWidth = 1.0,
      );
    }

    // Draw layers from bottom to top
    var offsetPerp = 0.0;
    for (final layer in assembly.layers.reversed) {
      final h = math.max(layer.thickness * scale, 2.5);
      if (layer.role == ArchitectRoofLayerRole.battens &&
          assembly.timber.hasBattens) {
        // Draw discrete battens with X diagonals
        final bw = math.max(assembly.timber.battenWidth * scale, 6.0);
        final step = math.max(assembly.timber.battenSpacing * scale, 18.0);
        for (var s = 0.0; s <= runLength - bw; s += step) {
          final p0 = eavesPt + dir * s + normalUp * offsetPerp;
          final p1 = p0 + dir * bw;
          final p2 = p1 + normalUp * h;
          final p3 = p0 + normalUp * h;
          final path = Path()..addPolygon([p0, p1, p2, p3], true);
          canvas.drawPath(path, Paint()..color = const Color(0xFFD7A86E));
          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFF4E342E)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
          canvas.drawLine(
            p0,
            p2,
            Paint()
              ..color = const Color(0xFF4E342E)
              ..strokeWidth = 0.8,
          );
          canvas.drawLine(
            p3,
            p1,
            Paint()
              ..color = const Color(0xFF4E342E)
              ..strokeWidth = 0.8,
          );
        }
        offsetPerp += h;
        continue;
      }

      final p0 = eavesPt + normalUp * offsetPerp;
      final p1 = p0 + dir * runLength;
      final p2 = p1 + normalUp * h;
      final p3 = p0 + normalUp * h;
      final path = Path()..addPolygon([p0, p1, p2, p3], true);
      canvas.drawPath(
        path,
        Paint()
          ..color = _ArchitectRoofLayersDialogState._materialColor(
            layer.material,
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      offsetPerp += h;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoofLayersPreviewPainter oldDelegate) =>
      oldDelegate.assembly != assembly ||
      oldDelegate.slopeDegrees != slopeDegrees ||
      oldDelegate.eavesCut != eavesCut;
}

// === SECTION: ROOF LAYER EDITOR DIALOG ===

class _RoofLayerEditorDialog extends StatefulWidget {
  final ArchitectRoofLayer layer;

  const _RoofLayerEditorDialog({required this.layer});

  @override
  State<_RoofLayerEditorDialog> createState() => _RoofLayerEditorDialogState();
}

class _RoofLayerEditorDialogState extends State<_RoofLayerEditorDialog> {
  late ArchitectRoofLayerRole _role = widget.layer.role;
  late ArchitectRoofMaterial _material = widget.layer.material;
  late double _thicknessMm = (widget.layer.thickness * 1000).clamp(1.0, 400.0);
  late bool _isBetweenRafters = widget.layer.isBetweenRafters;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E222B),
      title: Text(
        l.slabAddLayer,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ArchitectRoofLayerRole>(
              initialValue: _role,
              isExpanded: true,
              dropdownColor: const Color(0xFF262A34),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: l.slabRole,
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              items: [
                for (final role in ArchitectRoofLayerRole.values)
                  DropdownMenuItem(value: role, child: Text(role.label(l))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _role = v);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ArchitectRoofMaterial>(
              initialValue: _material,
              isExpanded: true,
              dropdownColor: const Color(0xFF262A34),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: l.slabMaterial,
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              items: [
                for (final mat in ArchitectRoofMaterial.values)
                  DropdownMenuItem(value: mat, child: Text(mat.label(l))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _material = v);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${l.architectPropertyThickness}: ${_thicknessMm.round()} mm',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Slider(
              value: _thicknessMm,
              min: 1.0,
              max: 350.0,
              divisions: 349,
              activeColor: const Color(0xFF00E5FF),
              onChanged: (v) => setState(() => _thicknessMm = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                l.architectRoofRaftersLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              value: _isBetweenRafters,
              activeThumbColor: const Color(0xFF00E5FF),
              onChanged: (v) => setState(() => _isBetweenRafters = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            widget.layer.copyWith(
              role: _role,
              material: _material,
              thickness: _thicknessMm / 1000.0,
              isBetweenRafters: _isBetweenRafters,
            ),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
