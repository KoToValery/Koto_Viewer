import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import 'architect_roof_number_field.dart';

class ArchitectRoofPanelFields extends StatelessWidget {
  final ArchitectRoofPanelSpec value;
  final ValueChanged<ArchitectRoofPanelSpec> onChanged;
  final ArchitectProject? project;
  const ArchitectRoofPanelFields({
    super.key,
    required this.value,
    required this.onChanged,
    this.project,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, p = value;
    Widget number(
      String key,
      String label,
      double v,
      ArchitectRoofPanelSpec Function(double) update, {
      bool degrees = false,
      double min = .001,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ArchitectRoofNumberField(
        key: ValueKey('roof-panel-$key'),
        value: degrees ? v : v * 1000,
        label: label,
        unit: degrees ? '°' : 'mm',
        min: min,
        onChanged: (v) => onChanged(update(degrees ? v : v / 1000)),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Tooltip(
          message: l.roofPanelHelp,
          child: Text(
            l.roofPanelThickness,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        number(
          'thickness',
          l.architectPropertyThickness,
          p.thickness,
          (v) => p.copyWith(thickness: v),
        ),
        number('skin', l.roofPanelSkin, p.skin, (v) => p.copyWith(skin: v)),
        number(
          'module',
          l.roofPanelModule,
          p.module,
          (v) => p.copyWith(module: v),
        ),
        if (!p.membrane)
          number(
            'rib',
            l.roofPanelRib,
            p.ribHeight,
            (v) => p.copyWith(ribHeight: v),
            min: 0,
          ),
        number(
          'minimum-slope',
          l.roofPanelMinSlope,
          p.minimumSlope,
          (v) => p.copyWith(minimumSlope: v),
          degrees: true,
          min: .1,
        ),
        number(
          'cutback',
          l.roofPanelCutback,
          p.cutback,
          (v) => p.copyWith(cutback: v),
          min: 0,
        ),
        number(
          'upstand',
          l.roofPanelUpstand,
          p.upstand,
          (v) => p.copyWith(upstand: v),
        ),
        ExpansionTile(
          key: const ValueKey('roof-panel-frame'),
          tilePadding: EdgeInsets.zero,
          title: Text(l.roofPanelFrame),
          children: [
            number(
              'beam-depth',
              l.roofPanelBeamDepth,
              p.beamDepth,
              (v) => p.copyWith(beamDepth: v),
            ),
            number(
              'beam-width',
              l.roofPanelBeamWidth,
              p.beamWidth,
              (v) => p.copyWith(beamWidth: v),
            ),
            number(
              'beam-web',
              l.roofPanelWeb,
              p.beamWeb,
              (v) => p.copyWith(beamWeb: v),
            ),
            number(
              'beam-flange',
              l.roofPanelFlange,
              p.beamFlange,
              (v) => p.copyWith(beamFlange: v),
            ),
            if (p.columnIds.isEmpty)
              number(
                'frames',
                l.roofPanelFramesSpacing,
                p.frameSpacing,
                (v) => p.copyWith(frameSpacing: v),
              ),
            number(
              'purlin-depth',
              l.roofPanelPurlinDepth,
              p.purlinDepth,
              (v) => p.copyWith(purlinDepth: v),
            ),
            number(
              'purlin-width',
              l.roofPanelPurlinWidth,
              p.purlinWidth,
              (v) => p.copyWith(purlinWidth: v),
            ),
            number(
              'purlin-metal',
              l.roofPanelPurlinMetal,
              p.purlinMetal,
              (v) => p.copyWith(purlinMetal: v),
            ),
            number(
              'purlins',
              l.roofPanelPurlinSpacing,
              p.purlinSpacing,
              (v) => p.copyWith(purlinSpacing: v),
            ),
          ],
        ),
        if (project != null)
          ExpansionTile(
            key: const ValueKey('roof-panel-columns'),
            tilePadding: EdgeInsets.zero,
            title: Text(l.roofPanelColumns),
            children: [
              for (final floor in project!.storeys)
                for (final c in floor.columns)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.label),
                    value: p.columnIds.contains(c.id),
                    onChanged: (v) {
                      final ids = p.columnIds.toSet();
                      v == true ? ids.add(c.id) : ids.remove(c.id);
                      onChanged(p.copyWith(columnIds: ids.toList()));
                    },
                  ),
              if (p.columnIds.any(
                (id) => !project!.storeys.any(
                  (f) => f.columns.any((c) => c.id == id),
                ),
              )) ...[
                Text(l.wallMissingSupports),
                TextButton(
                  onPressed: () => onChanged(
                    p.copyWith(
                      columnIds: p.columnIds
                          .where(
                            (id) => project!.storeys.any(
                              (f) => f.columns.any((c) => c.id == id),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  child: Text(l.wallRemoveMissingSupports),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
