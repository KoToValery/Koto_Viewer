import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../models/architect_zone_presets.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectWorkspaceSettings {
  final ArchitectZonePresets zonePresets;
  final ArchitectUnit units;
  final int distanceDecimals;
  final ArchitectDimensionScale dimensionScale;
  final bool ghostStoreys, upperOverhangs, grid, magnetic, underlay, darkCanvas;
  final double axisCoreThickness;
  final double handleOffsetLength;
  const ArchitectWorkspaceSettings({
    required this.units,
    this.zonePresets = const ArchitectZonePresets(),
    this.distanceDecimals = 2,
    this.dimensionScale = ArchitectDimensionScale.scale100,
    required this.ghostStoreys,
    this.upperOverhangs = true,
    required this.grid,
    required this.magnetic,
    required this.underlay,
    required this.darkCanvas,
    required this.axisCoreThickness,
    this.handleOffsetLength = 50.0,
  });
}

class ArchitectWorkspaceSettingsDialog extends StatefulWidget {
  final ArchitectWorkspaceSettings settings;
  final bool hasUnderlay;
  final VoidCallback? onWalls;
  const ArchitectWorkspaceSettingsDialog({
    super.key,
    required this.settings,
    required this.hasUnderlay, this.onWalls,
  });
  @override
  State<ArchitectWorkspaceSettingsDialog> createState() =>
      _ArchitectWorkspaceSettingsDialogState();
}

class _ArchitectWorkspaceSettingsDialogState
    extends State<ArchitectWorkspaceSettingsDialog> {
  late final Map<String, String> zoneOverrides = Map.of(widget.settings.zonePresets.overrides);

  Widget presetField(String id, String label) => TextFormField(
    key: ValueKey('zone-preset-$id'),
    initialValue: zoneOverrides[id] ?? '',
    decoration: InputDecoration(labelText: label, hintText: label),
    onChanged: (value) {
      if (value.trim().isEmpty) {
        zoneOverrides.remove(id);
      } else {
        zoneOverrides[id] = value.trim();
      }
    },
  );

  late int distanceDecimals = widget.settings.distanceDecimals;
  late ArchitectUnit units = widget.settings.units;
  late ArchitectDimensionScale dimensionScale = widget.settings.dimensionScale;
  late bool ghost = widget.settings.ghostStoreys,
      upperOverhangs = widget.settings.upperOverhangs,
      grid = widget.settings.grid,
      magnetic = widget.settings.magnetic,
      underlay = widget.settings.underlay,
      dark = widget.settings.darkCanvas;
  late double core = widget.settings.axisCoreThickness;
  late double handleOffsetLength = widget.settings.handleOffsetLength;

  Future<void> editCore() async {
    var value = units.toUnit(core);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 250,
          child: ArchitectWallDraftingPanel(
            length: value,
            unit: units.symbol,
            decimals: distanceDecimals,
            title: context.l10n.architectAxesWallThickness,
            endLabel: context.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            minimumLength: units.toUnit(.001),
            onLength: (number) => value = number,
            onEnd: () {
              setState(() => core = units.fromUnit(value));
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
    return AlertDialog(
      title: Text(l.architectSettings),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if(widget.onWalls!=null)ListTile(key:const ValueKey('architect-settings-walls'),contentPadding:EdgeInsets.zero,title:Text(l.wallTypesTitle),leading:const Icon(Icons.line_weight),trailing:const Icon(Icons.chevron_right),onTap:widget.onWalls),
              ExpansionTile(
                key: const ValueKey('architect-settings-zone-presets'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.architectZonePresets),
                children: [
                  for (final category in ArchitectZoneCategory.values)
                    presetField('category.${category.name}', category.localizedName(l)),
                  for (final group in <String, String>{
                    'floor': l.architectZoneFloorFinish,
                    'wall': l.architectZoneWallFinish,
                    'ceiling': l.architectZoneCeilingFinish,
                  }.entries)
                    ExpansionTile(
                      title: Text(group.value),
                      children: [
                        for (final entry in const ArchitectZonePresets().finishes(group.key, l).asMap().entries)
                          presetField('${group.key}.${entry.key}', entry.value),
                      ],
                    ),
                ],
              ),
              DropdownButtonFormField<ArchitectUnit>(
                key: const ValueKey('architect-settings-units'),
                initialValue: units,
                decoration: InputDecoration(labelText: l.architectUnits),
                items: [
                  for (final unit in ArchitectUnit.values)
                    DropdownMenuItem(value: unit, child: Text(unit.symbol)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => units = value);
                },
              ),
              DropdownButtonFormField<int>(
                key: const ValueKey('architect-settings-precision'),
                initialValue: distanceDecimals,
                decoration: InputDecoration(
                  labelText: l.architectDistancePrecision,
                ),
                items: [
                  for (final value in [0, 1, 2])
                    DropdownMenuItem(value: value, child: Text('$value')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => distanceDecimals = value);
                },
              ),
              DropdownButtonFormField<ArchitectDimensionScale>(
                key: const ValueKey('architect-settings-dimension-scale'),
                initialValue: dimensionScale,
                decoration: InputDecoration(
                  labelText: l.architectDimensionScale,
                ),
                items: [
                  for (final scale in ArchitectDimensionScale.values)
                    DropdownMenuItem(value: scale, child: Text(scale.ratio)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => dimensionScale = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('architect-settings-ghost'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectGhostStoreys),
                value: ghost,
                onChanged: (value) => setState(() => ghost = value),
              ),
              SwitchListTile(
                key: const ValueKey('architect-settings-upper-overhangs'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectUpperOverhangs),
                subtitle: Text(l.architectUpperOverhangsHelp),
                value: upperOverhangs,
                onChanged: (value) => setState(() => upperOverhangs = value),
              ),
              SwitchListTile(
                key: const ValueKey('architect-settings-grid'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectDrawingGrid),
                value: grid,
                onChanged: (value) => setState(() => grid = value),
              ),
              SwitchListTile(
                key: const ValueKey('architect-settings-snap'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectWallMagnet),
                subtitle: Text(l.architectMagnetHelp),
                value: magnetic,
                onChanged: (value) => setState(() => magnetic = value),
              ),
              if (widget.hasUnderlay)
                SwitchListTile(
                  key: const ValueKey('architect-settings-underlay'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectUnderlayToggle),
                  value: underlay,
                  onChanged: (value) => setState(() => underlay = value),
                ),
              SwitchListTile(
                key: const ValueKey('architect-settings-dark'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectCanvasDark),
                value: dark,
                onChanged: (value) => setState(() => dark = value),
              ),
              Tooltip(
                message: l.architectAxesFromWallsHelp,
                child: ListTile(
                  key: const ValueKey('architect-settings-axis-thickness'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectAxesWallThickness),
                  trailing: Text(
                    units.format(core, decimals: distanceDecimals),
                  ),
                  onTap: editCore,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.architectHandleOffsetLength,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            key: const ValueKey('architect-settings-handle-offset'),
                            value: handleOffsetLength.clamp(20.0, 120.0),
                            min: 20.0,
                            max: 120.0,
                            divisions: 20,
                            label: '${handleOffsetLength.round()} px',
                            onChanged: (val) => setState(() => handleOffsetLength = val),
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          child: Text(
                            '${handleOffsetLength.round()} px',
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
          key: const ValueKey('architect-settings-save'),
          onPressed: () => Navigator.pop(
            context,
            ArchitectWorkspaceSettings(
              units: units,
              zonePresets: ArchitectZonePresets(Map.unmodifiable(zoneOverrides)),
              distanceDecimals: distanceDecimals,
              dimensionScale: dimensionScale,
              ghostStoreys: ghost,
              upperOverhangs: upperOverhangs,
              grid: grid,
              magnetic: magnetic,
              underlay: underlay,
              darkCanvas: dark,
              axisCoreThickness: core,
              handleOffsetLength: handleOffsetLength,
            ),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
