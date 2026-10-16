import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectWorkspaceSettings {
  final ArchitectUnit units;
  final ArchitectDimensionScale dimensionScale;
  final bool ghostStoreys, upperOverhangs, grid, magnetic, underlay, darkCanvas;
  final double axisCoreThickness;
  const ArchitectWorkspaceSettings({
    required this.units,
    this.dimensionScale = ArchitectDimensionScale.scale100,
    required this.ghostStoreys,
    this.upperOverhangs = true,
    required this.grid,
    required this.magnetic,
    required this.underlay,
    required this.darkCanvas,
    required this.axisCoreThickness,
  });
}

class ArchitectWorkspaceSettingsDialog extends StatefulWidget {
  final ArchitectWorkspaceSettings settings;
  final bool hasUnderlay;
  const ArchitectWorkspaceSettingsDialog({
    super.key,
    required this.settings,
    required this.hasUnderlay,
  });
  @override
  State<ArchitectWorkspaceSettingsDialog> createState() =>
      _ArchitectWorkspaceSettingsDialogState();
}

class _ArchitectWorkspaceSettingsDialogState
    extends State<ArchitectWorkspaceSettingsDialog> {
  late ArchitectUnit units = widget.settings.units;
  late ArchitectDimensionScale dimensionScale = widget.settings.dimensionScale;
  late bool ghost = widget.settings.ghostStoreys,
      upperOverhangs = widget.settings.upperOverhangs,
      grid = widget.settings.grid,
      magnetic = widget.settings.magnetic,
      underlay = widget.settings.underlay,
      dark = widget.settings.darkCanvas;
  late double core = widget.settings.axisCoreThickness;

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
                  trailing: Text(units.format(core)),
                  onTap: editCore,
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
              dimensionScale: dimensionScale,
              ghostStoreys: ghost,
              upperOverhangs: upperOverhangs,
              grid: grid,
              magnetic: magnetic,
              underlay: underlay,
              darkCanvas: dark,
              axisCoreThickness: core,
            ),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
