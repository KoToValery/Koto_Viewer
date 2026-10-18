import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_grid_preset.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import 'architect_grid_scheme.dart';
import 'architect_grid_preset_label.dart';

class ArchitectProjectWizardDialog extends StatefulWidget {
  final String? initialProjectName;
  const ArchitectProjectWizardDialog({super.key, this.initialProjectName});

  static Future<ArchitectProject?> show(
    BuildContext context, {
    String? initialProjectName,
  }) => showDialog<ArchitectProject>(
    context: context,
    builder: (_) =>
        ArchitectProjectWizardDialog(initialProjectName: initialProjectName),
  );

  @override
  State<ArchitectProjectWizardDialog> createState() =>
      _ArchitectProjectWizardDialogState();
}

class _LevelDraft {
  double elevation, height;
  final TextEditingController elevationInput = TextEditingController();
  final TextEditingController heightInput = TextEditingController();
  _LevelDraft(this.elevation, this.height);
  String get elevationLabel =>
      ArchitectStorey(id: '', name: '', elevation: elevation).elevationLabel;
  void dispose() {
    elevationInput.dispose();
    heightInput.dispose();
  }
}

class _ArchitectProjectWizardDialogState
    extends State<ArchitectProjectWizardDialog> {
  late final TextEditingController _name;
  final _levelsForm = GlobalKey<FormState>();
  final _levels = [_LevelDraft(0, 3)];
  int _step = 0, _decimals = 0;
  ArchitectUnit _unit = ArchitectUnit.centimeters;
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
        _levels[i].elevationInput.text = _elevationNumber(_levels[i].elevation);
      }
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
      previous.heightInput.text = _number(previous.height);
      if (index + 1 < _levels.length) {
        level.height = _levels[index + 1].elevation - elevation;
        level.heightInput.text = _number(level.height);
      }
    });
  }

  void _addLevel() {
    if (!_levelsForm.currentState!.validate()) return;
    setState(() {
      final last = _levels.last;
      final next = _LevelDraft(last.elevation + last.height, last.height);
      next.elevationInput.text = _elevationNumber(next.elevation);
      next.heightInput.text = _number(next.height);
      _levels.add(next);
    });
  }

  void _create() {
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
    final project = ArchitectProject.starterWithCatalog(
      name: _name.text.trim().isEmpty
          ? l.architectDefaultProjectName
          : _name.text.trim(),
      storeyCount: storeys.length,
      groundHeight: storeys.first.height,
      gridPreset: _grid,
      spacingsX: _spacingsX,
      spacingsY: _spacingsY,
      units: _unit,
      wallTypes: ArchitectWallType.standardCatalog(
        l10n: l,
        parapetHeight: ArchitectWallType.resolveParapetHeight(
          storeyElevation: storeys.last.elevation + storeys.last.height,
          storeyIndex: storeys.length,
        ),
      ),
    ).copyWith(storeys: storeys, distanceDecimals: _decimals);
    Navigator.pop(context, project);
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 20),
          child: Column(
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
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          key: ValueKey('architect-wizard-step-$i'),
                          avatar: compact ? null : Icon(icons[i], size: 16),
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
                    child: Text(_step == 0 ? l.cancel : l.architectWizardBack),
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
          spacing: 8,
          children: [
            for (final decimals in [0, 1, 2])
              ChoiceChip(
                key: ValueKey('architect-wizard-precision-$decimals'),
                label: Text('$decimals'),
                selected: _decimals == decimals,
                onSelected: (_) => setState(() {
                  _decimals = decimals;
                  _refreshLevelInputs();
                }),
              ),
          ],
        ),
      ],
    );
  }

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
                    _grid = preset;
                    if (preset.type != GridPresetType.none) {
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
            onChanged: (x, y) => setState(() {
              _spacingsX = x;
              _spacingsY = y;
              _grid = ArchitectGridPreset.standardPresets().firstWhere(
                (p) => p.type == GridPresetType.custom,
              );
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('architect-wizard-elevation-$i'),
                      controller: _levels[i].elevationInput,
                      readOnly: i == 0,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (text) => _elevationChanged(i, text),
                      validator: (text) {
                        final value = _parse(text ?? '', elevation: true);
                        return value == null ||
                                (i > 0 && value <= _levels[i - 1].elevation) ||
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
            ),
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('architect-wizard-add-storey'),
                onPressed: _addLevel,
                icon: const Icon(Icons.add),
                label: Text(l.bimProjectAddStorey),
              ),
              const Spacer(),
              if (_levels.length > 1)
                IconButton(
                  key: const ValueKey('architect-wizard-remove-storey'),
                  tooltip: l.bimProjectDeleteStorey,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      setState(() => _levels.removeLast().dispose()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
