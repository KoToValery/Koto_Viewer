import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_type_label.dart';

class ArchitectWallSystemFields extends StatelessWidget {
  final ArchitectWallSystem system;
  final ArchitectUnit unit;
  final double thickness;
  final ValueChanged<ArchitectWallSystem> onChanged;
  const ArchitectWallSystemFields({
    super.key,
    required this.system,
    required this.unit,
    required this.thickness,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget number(
      String key,
      String label,
      double value,
      ArchitectWallSystem Function(double) update, {
      bool dimension = true,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('wall-system-$key'),
        initialValue: ArchitectUnit.trimZeros(
          (dimension ? unit.toUnit(value) : value).toStringAsFixed(6),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: dimension ? unit.symbol : null,
        ),
        validator: (text) {
          final v = double.tryParse((text ?? '').replaceAll(',', '.'));
          return v == null || !v.isFinite || v < 0 ? l.wallSystemInvalid : null;
        },
        onChanged: (text) {
          final v = double.tryParse(text.replaceAll(',', '.'));
          if (v != null && v.isFinite) {
            onChanged(update(dimension ? unit.fromUnit(v) : v));
          }
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (system.isLog) ...[
          number(
            'overlap',
            l.wallLogOverlap,
            system.overlapPercent,
            (v) => system.copyWith(overlapPercent: v),
            dimension: false,
          ),
          number(
            'tail',
            l.wallLogTail,
            system.tailFactor,
            (v) => system.copyWith(tailFactor: v),
            dimension: false,
          ),
          Text(
            '${l.wallLogPitch}: ${architectWallLength(system.pitch(thickness), unit)}',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.wallLogCasing),
            value: system.openingCasing,
            onChanged: (v) => onChanged(system.copyWith(openingCasing: v)),
          ),
          if (system.openingCasing)
            number(
              'casing',
              l.wallLogCasingWidth,
              system.casingWidth,
              (v) => system.copyWith(casingWidth: v),
            ),
          number(
            'settlement',
            l.wallLogSettlement,
            system.settlementAllowance,
            (v) => system.copyWith(settlementAllowance: v),
          ),
        ],
        if (system.isFrame || system.isPanel) ...[
          number(
            'spacing',
            l.wallStudSpacing,
            system.studSpacing,
            (v) => system.copyWith(studSpacing: v),
          ),
          number(
            'width',
            l.wallStudWidth,
            system.studWidth,
            (v) => system.copyWith(studWidth: v),
          ),
          number(
            'metal',
            l.wallMetalThickness,
            system.metalThickness,
            (v) => system.copyWith(metalThickness: v),
          ),
        ],
        if (system.isFrame)
          number(
            'wool',
            l.wallCavityInsulation,
            system.insulationDepth,
            (v) => system.copyWith(insulationDepth: v),
          ),
        if (system.isPanel) ...[
          number(
            'support',
            l.wallSupportDepth,
            system.supportDepth,
            (v) => system.copyWith(supportDepth: v),
          ),
          number(
            'module',
            l.wallPanelModule,
            system.panelModule,
            (v) => system.copyWith(panelModule: v),
          ),
          DropdownButtonFormField<ArchitectPanelMount>(
            initialValue: system.panelMount,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.wallPanelMount),
            items: [
              for (final mode in ArchitectPanelMount.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(
                    mode == ArchitectPanelMount.inFront
                        ? l.wallPanelInFront
                        : l.wallPanelBetween,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(system.copyWith(panelMount: v));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.wallPanelsHorizontal),
            value: system.horizontalPanels,
            onChanged: (v) => onChanged(system.copyWith(horizontalPanels: v)),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
