import 'dart:async';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_projects/services/bim_underlay_picker_helper.dart';
import '../models/architect_grid_preset.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_hatch_patterns.dart';
import '../services/architect_line_styles.dart';
import '../services/architect_wall_library.dart';
import '../services/architect_underlay_service.dart';
import 'architect_cad_import_dialog.dart';
import 'architect_grid_scheme.dart';
import 'architect_grid_preset_label.dart';
import 'architect_numeric_keypad.dart';
import 'architect_structural_scheme_labels.dart';

class ArchitectProjectWizardDialog extends StatefulWidget {
  final String? initialProjectName;
  final String? underlayOwnerId;
  final Future<ArchitectProject> Function(
    ArchitectProject project,
    Map<String, ArchitectCadImportSelection> underlays,
  )?
  onCreate;
  const ArchitectProjectWizardDialog({
    super.key,
    this.initialProjectName,
    this.underlayOwnerId,
    this.onCreate,
  });

  static Future<ArchitectProject?> show(
    BuildContext context, {
    String? initialProjectName,
    String? underlayOwnerId,
    Future<ArchitectProject> Function(
      ArchitectProject project,
      Map<String, ArchitectCadImportSelection> underlays,
    )?
    onCreate,
  }) => showDialog<ArchitectProject>(
    context: context,
    barrierDismissible: onCreate == null,
    builder: (_) => ArchitectProjectWizardDialog(
      initialProjectName: initialProjectName,
      underlayOwnerId: underlayOwnerId,
      onCreate: onCreate,
    ),
  );

  @override
  State<ArchitectProjectWizardDialog> createState() =>
      _ArchitectProjectWizardDialogState();
}

class _LevelDraft {
  double elevation, height;
  ArchitectCadImportSelection? overlay;
  final TextEditingController elevationInput = TextEditingController();
  final TextEditingController heightInput = TextEditingController();
  _LevelDraft(this.elevation, this.height);
  String get elevationLabel =>
      ArchitectStorey(id: '', name: '', elevation: elevation).elevationLabel;
  void dispose() {
    unawaited(overlay?.prepared.dispose());
    elevationInput.dispose();
    heightInput.dispose();
  }
}

class _ArchitectProjectWizardDialogState
    extends State<ArchitectProjectWizardDialog> {
  static const double _defaultUpperStoreyHeightMeters = 2.9;

  late final TextEditingController _name;
  final _levelsForm = GlobalKey<FormState>();
  final _levels = [_LevelDraft(0, 3)];
  int _step = 0, _decimals = 1;
  bool _isCreating = false;
  bool _isPickingOverlay = false;
  ArchitectUnit _unit = ArchitectUnit.centimeters;
  ArchitectStructuralScheme _structuralScheme =
      ArchitectStructuralScheme.flatSlab;
  ArchitectGridPreset _grid = ArchitectGridPreset.standardPresets().first;
  List<double> _spacingsX = [7.2, 7.2, 7.2], _spacingsY = [6.6, 6.6];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialProjectName ?? '');
    _refreshLevelInputs();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final level in _levels) {
      level.dispose();
    }
    super.dispose();
  }

  String _number(double meters) =>
      _unit.toUnit(meters).toStringAsFixed(_decimals);
  int get _elevationDecimals => switch (_unit) {
    ArchitectUnit.centimeters => _decimals + 2,
    ArchitectUnit.millimeters => _decimals + 3,
    _ => 2,
  };
  String _elevationNumber(double value) =>
      '${value == 0
          ? '±'
          : value > 0
          ? '+'
          : ''}${value.toStringAsFixed(_elevationDecimals)}';
  double? _parse(String text, {bool elevation = false}) {
    final value = double.tryParse(
      text.trim().replaceAll(',', '.').replaceAll('±', ''),
    );
    return value == null || !value.isFinite
        ? null
        : elevation
        ? value
        : _unit.fromUnit(value);
  }

  void _refreshLevelInputs() {
    for (final level in _levels) {
      level.elevationInput.text = _elevationNumber(level.elevation);
      level.heightInput.text = _number(level.height);
    }
  }

  void _changeUnit(ArchitectUnit unit) => setState(() {
    _unit = unit;
    _refreshLevelInputs();
  });
  void _heightChanged(int index, String text) {
    final height = _parse(text);
    if (height == null || height <= 0) return;
    setState(() {
      _levels[index].height = height;
      for (var i = index + 1; i < _levels.length; i++) {
        _levels[i].elevation = _levels[i - 1].elevation + _levels[i - 1].height;
      }
      _refreshLevelInputs();
    });
  }

  void _elevationChanged(int index, String text) {
    final elevation = _parse(text, elevation: true);
    if (elevation == null ||
        index == 0 ||
        elevation <= _levels[index - 1].elevation ||
        (index + 1 < _levels.length &&
            elevation >= _levels[index + 1].elevation)) {
      return;
    }
    setState(() {
      final level = _levels[index];
      level.elevation = elevation;
      final previous = _levels[index - 1];
      previous.height = elevation - previous.elevation;
      if (index + 1 < _levels.length) {
        level.height = _levels[index + 1].elevation - elevation;
      }
      _refreshLevelInputs();
    });
  }

  void _addLevel() {
    if (!_levelsForm.currentState!.validate()) return;
    setState(() {
      final last = _levels.last;
      final next = _LevelDraft(
        last.elevation + last.height,
        _defaultUpperStoreyHeightMeters,
      );
      next.elevationInput.text = _elevationNumber(next.elevation);
      next.heightInput.text = _number(next.height);
      _levels.add(next);
    });
  }

  Future<void> _create() async {
    if (_isCreating || _isPickingOverlay) return;
    if (!_levelsForm.currentState!.validate()) return;
    final l = context.l10n;
    final storeys = [
      for (var i = 0; i < _levels.length; i++)
        ArchitectStorey(
          id: 'storey_$i',
          name: _levels[i].elevationLabel,
          elevation: _levels[i].elevation,
          height: _levels[i].height,
        ),
    ];
    final underlays = {
      for (var i = 0; i < storeys.length; i++)
        storeys[i].id: ?_levels[i].overlay,
    };
    setState(() => _isCreating = true);
    try {
      await ArchitectWallLibrary.loadCustomTypes();
      final customLines = await ArchitectLineStyleLibrary.load();
      final customHatches = await ArchitectHatchPatternLibrary.load();
      if (!mounted) return;
      final baseProject =
          ArchitectProject.starterWithCatalog(
            name: _name.text.trim().isEmpty
                ? l.architectDefaultProjectName
                : _name.text.trim(),
            storeyCount: storeys.length,
            groundHeight: storeys.first.height,
            gridPreset: _grid,
            spacingsX: _spacingsX,
            spacingsY: _spacingsY,
            structuralScheme: _structuralScheme,
            units: _unit,
            wallTypes: ArchitectWallType.standardCatalog(
              l10n: l,
              parapetHeight: ArchitectWallType.resolveParapetHeight(
                storeyElevation: storeys.last.elevation + storeys.last.height,
                storeyIndex: storeys.length,
              ),
            ),
          ).copyWith(
            storeys: storeys,
            distanceDecimals: _decimals,
            lineStyles: customLines,
            hatchPatterns: customHatches,
          ).ensureRoofStorey().ensureSiteStorey();
      final project = ArchitectWallLibrary.mergeCustomTypes(baseProject);
      final onCreate = widget.onCreate;
      final created = onCreate == null
          ? project.copyWith(
              cadUnderlays: await ArchitectUnderlayService.instance
                  .commitCadUnderlays(
                    widget.underlayOwnerId ?? project.id,
                    underlays,
                  ),
            )
          : await onCreate(project, underlays);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final labels = [
      l.architectWizardUnitsShort,
      l.architectWizardGridShort,
      l.architectWizardStoreysShort,
    ];
    final icons = [Icons.straighten, Icons.grid_on, Icons.layers_outlined];
    return PopScope(
      canPop: !_isCreating,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: _isCreating
                ? SizedBox(
                    key: const ValueKey('architect-wizard-creating'),
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _levels.any((e) => e.overlay != null)
                                ? l.architectWizardLoadingUnderlay
                                : l.architectWizardCreatingProject,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              compact
                                  ? l.architectWizardTitleShort
                                  : l.architectWizardTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: l.close,
                            onPressed: () => Navigator.pop(context),
                            icon: const AppIcon(AppIconId.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: ChoiceChip(
                                  key: ValueKey('architect-wizard-step-$i'),
                                  avatar: compact
                                      ? null
                                      : AppIcon.fromMaterial(
                                          icons[i],
                                          size: 16,
                                        ),
                                  label: Text(
                                    labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  showCheckmark: false,
                                  selected: _step == i,
                                  onSelected: (_) => setState(() => _step = i),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      Expanded(
                        child: SingleChildScrollView(
                          child: switch (_step) {
                            0 => _units(),
                            1 => _axes(),
                            _ => _storeys(),
                          },
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _step == 0
                                ? () => Navigator.pop(context)
                                : () => setState(() => _step--),
                            child: Text(
                              _step == 0 ? l.cancel : l.architectWizardBack,
                            ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _step == 2
                                ? _create
                                : () => setState(() => _step++),
                            child: Text(
                              _step == 2
                                  ? l.architectWizardCreateShort
                                  : l.architectWizardNext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _units() {
    final l = context.l10n;
    final labels = [
      l.architectUnitMeters,
      l.architectUnitCm,
      l.architectUnitMm,
      l.architectUnitFeet,
      l.architectUnitInches,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: l.bimProjectName,
            hintText: l.architectDefaultProjectName,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Text(l.architectUnits, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < ArchitectUnit.values.length; i++)
              Tooltip(
                message: labels[i],
                child: ChoiceChip(
                  label: Text(ArchitectUnit.values[i].symbol),
                  selected: _unit == ArchitectUnit.values[i],
                  onSelected: (_) => _changeUnit(ArchitectUnit.values[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l.architectDistancePrecision,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final decimals in [0, 1, 2])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('architect-wizard-precision-$decimals'),
                      label: Text('$decimals'),
                      selected: _decimals == decimals,
                      onSelected: (_) => setState(() {
                        _decimals = decimals;
                        _refreshLevelInputs();
                      }),
                    ),
                  ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l.architectWizardExample} ',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _decimals == 0 ? '0' : '0.${'0' * _decimals}',
                    key: const ValueKey('architect-wizard-precision-example'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l.architectStructuralScheme,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ArchitectStructuralScheme>(
          isExpanded: true,
          initialValue: _structuralScheme,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final scheme in ArchitectStructuralScheme.values)
              DropdownMenuItem(
                value: scheme,
                child: Text(scheme.label(l), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _structuralScheme = val);
          },
        ),
      ],
    );
  }

  bool _matchesPresetSpacings(
    ArchitectGridPreset preset,
    List<double> x,
    List<double> y,
  ) =>
      preset.type != GridPresetType.none &&
      preset.type != GridPresetType.custom &&
      x.every((v) => (v - preset.spacingX).abs() < 1e-6) &&
      y.every((v) => (v - preset.spacingY).abs() < 1e-6);

  Widget _axes() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in ArchitectGridPreset.standardPresets())
              Tooltip(
                message: preset.help(l),
                child: ChoiceChip(
                  label: Text(preset.label(l)),
                  selected: _grid.id == preset.id,
                  onSelected: (_) => setState(() {
                    final prevType = _grid.type;
                    _grid = preset;
                    if (preset.type == GridPresetType.custom) {
                      if (prevType == GridPresetType.none ||
                          _spacingsX.isEmpty ||
                          _spacingsY.isEmpty) {
                        _spacingsX = List.filled(
                          preset.axesX - 1,
                          preset.spacingX,
                        );
                        _spacingsY = List.filled(
                          preset.axesY - 1,
                          preset.spacingY,
                        );
                      }
                    } else if (preset.type != GridPresetType.none) {
                      _spacingsX = List.filled(
                        preset.axesX - 1,
                        preset.spacingX,
                      );
                      _spacingsY = List.filled(
                        preset.axesY - 1,
                        preset.spacingY,
                      );
                    }
                  }),
                ),
              ),
          ],
        ),
        if (_grid.type != GridPresetType.none) ...[
          const SizedBox(height: 16),
          ArchitectGridScheme(
            spacingsX: _spacingsX,
            spacingsY: _spacingsY,
            unit: _unit,
            decimals: _decimals,
            customMode: _grid.type == GridPresetType.custom,
            onChanged: (x, y) => setState(() {
              _spacingsX = x;
              _spacingsY = y;
              if (_grid.type != GridPresetType.custom &&
                  !_matchesPresetSpacings(_grid, x, y)) {
                _grid = ArchitectGridPreset.standardPresets().firstWhere(
                  (p) => p.type == GridPresetType.custom,
                );
              }
            }),
          ),
        ],
      ],
    );
  }

  Widget _storeys() {
    final l = context.l10n;
    return Form(
      key: _levelsForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tooltip(
                  message: l.architectWizardElevationHelp,
                  child: Text('${l.architectWizardElevation} (m)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tooltip(
                  message: l.architectWizardStoreyHeightHelp,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l.architectWizardHeight} (${_unit.symbol})'),
                      Text(
                        l.architectWizardHeightReference,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _levels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('architect-wizard-elevation-$i'),
                          controller: _levels[i].elevationInput,
                          readOnly: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          keyboardType: TextInputType.none,
                          onTap: i == 0
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();
                                  final temp = TextEditingController(
                                    text: _levels[i].elevation.toStringAsFixed(
                                      _elevationDecimals,
                                    ),
                                  );
                                  await openArchitectNumericKeypad(
                                    context: context,
                                    controller: temp,
                                    title: l.architectWizardElevation,
                                    unitLabel: 'm',
                                    decimals: _elevationDecimals,
                                    allowNegative: true,
                                    validate: (v) {
                                      if (v <= _levels[i - 1].elevation ||
                                          (i + 1 < _levels.length &&
                                              v >= _levels[i + 1].elevation)) {
                                        return l.architectWizardInvalidLevel;
                                      }
                                      return null;
                                    },
                                    onApplied: (text) =>
                                        _elevationChanged(i, text),
                                  );
                                  temp.dispose();
                                },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) => _elevationChanged(i, text),
                          validator: (text) {
                            final value = _parse(text ?? '', elevation: true);
                            return value == null ||
                                    (i > 0 &&
                                        value <= _levels[i - 1].elevation) ||
                                    (i + 1 < _levels.length &&
                                        value >= _levels[i + 1].elevation)
                                ? l.architectWizardInvalidLevel
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('architect-wizard-height-$i'),
                          controller: _levels[i].heightInput,
                          readOnly: true,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          keyboardType: TextInputType.none,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            openArchitectNumericKeypad(
                              context: context,
                              controller: _levels[i].heightInput,
                              title: l.architectWizardHeight,
                              unitLabel: _unit.symbol,
                              decimals: architectNumericDecimals(_unit),
                              min: .000001,
                              onApplied: (text) => _heightChanged(i, text),
                            );
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (text) => _heightChanged(i, text),
                          validator: (text) {
                            final value = _parse(text ?? '');
                            return value == null || value <= 0
                                ? l.architectWizardInvalidLevel
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildStoreyOverlayPicker(i, l),
                ],
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('architect-wizard-add-storey'),
                onPressed: _addLevel,
                icon: const AppIcon(AppIconId.add),
                label: Text(l.bimProjectAddStorey),
              ),
              const Spacer(),
              if (_levels.length > 1)
                IconButton(
                  key: const ValueKey('architect-wizard-remove-storey'),
                  tooltip: l.bimProjectDeleteStorey,
                  icon: const AppIcon(AppIconId.removeCircle),
                  onPressed: () =>
                      setState(() => _levels.removeLast().dispose()),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickStoreyUnderlay(_LevelDraft level) async {
    if (_isPickingOverlay) return;
    setState(() => _isPickingOverlay = true);
    ArchitectPreparedCadUnderlay? prepared;
    try {
      final source = await BimUnderlayPickerHelper.pickCadUnderlayFile(context);
      if (source == null || !mounted || !_levels.contains(level)) return;
      prepared = await ArchitectUnderlayService.instance.prepareCadUnderlay(
        source,
      );
      if (!mounted || !_levels.contains(level)) return;
      final selected = await showArchitectCadImportDialog(
        context: context,
        prepared: prepared,
      );
      if (selected == null || !mounted || !_levels.contains(level)) return;
      final old = level.overlay;
      setState(() => level.overlay = selected);
      prepared = null;
      await old?.prepared.dispose();
    } catch (error) {
      if (!mounted) return;
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ArchitectEmptyCadUnderlay
                ? l.architectCadImportEmpty
                : l.architectUnderlayLoadError(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingOverlay = false);
      await prepared?.dispose();
    }
  }

  Widget _buildStoreyOverlayPicker(int index, AppLocalizations l) {
    final level = _levels[index];
    final overlay = level.overlay;
    final colors = Theme.of(context).colorScheme;
    final VoidCallback? pick = _isPickingOverlay
        ? null
        : () => _pickStoreyUnderlay(level);
    if (overlay == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: ValueKey('architect-wizard-overlay-add-$index'),
          onPressed: pick,
          icon: const AppIcon(AppIconId.cadUnderlay, size: 16),
          label: Text(l.architectWizardAddOverlay),
        ),
      );
    }

    return Container(
      padding: const EdgeInsetsDirectional.only(start: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const AppIcon(AppIconId.cadUnderlay, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              overlay.prepared.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: l.architectWizardChangeOverlay,
            onPressed: pick,
            icon: const AppIcon(AppIconId.edit, size: 16),
          ),
          IconButton(
            key: ValueKey('architect-wizard-overlay-remove-$index'),
            tooltip: l.architectWizardRemoveOverlay,
            icon: const AppIcon(AppIconId.close, size: 16),
            onPressed: _isPickingOverlay
                ? null
                : () {
                    setState(() => level.overlay = null);
                    unawaited(overlay.prepared.dispose());
                  },
          ),
        ],
      ),
    );
  }
}
