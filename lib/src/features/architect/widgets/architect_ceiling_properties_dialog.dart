import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_ceiling_geometry.dart';
import 'architect_dialog.dart';
import 'architect_numeric_keypad.dart';

/// Properties & elevation anchor editor for a suspended ceiling (either an
/// existing ceiling or drafting defaults).
class ArchitectCeilingPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectSuspendedCeiling ceiling;
  final bool Function()? isCurrent;
  final ValueChanged<ArchitectSuspendedCeiling>? onPreview;
  final bool Function(ArchitectSuspendedCeiling) onApply;

  const ArchitectCeilingPropertiesDialog({
    super.key,
    required this.project,
    required this.ceiling,
    this.isCurrent,
    this.onPreview,
    required this.onApply,
  });

  @override
  State<ArchitectCeilingPropertiesDialog> createState() =>
      _ArchitectCeilingPropertiesDialogState();
}

class _ArchitectCeilingPropertiesDialogState
    extends State<ArchitectCeilingPropertiesDialog> {
  late ArchitectSuspendedCeiling _working = widget.ceiling;
  late final TextEditingController _labelCtrl = TextEditingController(
    text: _working.label,
  );
  late final TextEditingController _dropCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.dropFromUpperSlab, decimals: 3),
  );
  late final TextEditingController _panelThickCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.panelThickness, decimals: 4),
  );
  late final TextEditingController _carrierCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.gridSystemHeight, decimals: 3),
  );
  late final TextEditingController _insulationCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.insulationThickness, decimals: 3),
  );
  late final TextEditingController _tileWCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.tileWidth, decimals: 3),
  );
  late final TextEditingController _tileLCtrl = TextEditingController(
    text: formatArchitectNumericValue(_working.tileLength, decimals: 3),
  );
  late final TextEditingController _angleCtrl = TextEditingController(
    text: formatArchitectNumericValue(
      _working.gridAngle * 180 / math.pi,
      decimals: 1,
    ),
  );

  @override
  void dispose() {
    _labelCtrl.dispose();
    _dropCtrl.dispose();
    _panelThickCtrl.dispose();
    _carrierCtrl.dispose();
    _insulationCtrl.dispose();
    _tileWCtrl.dispose();
    _tileLCtrl.dispose();
    _angleCtrl.dispose();
    super.dispose();
  }

  void _update(ArchitectSuspendedCeiling next) {
    setState(() => _working = next);
    widget.onPreview?.call(next);
  }

  void _commitNumeric({
    double? drop,
    double? panelThickness,
    double? gridSystemHeight,
    double? insulationThickness,
    double? tileWidth,
    double? tileLength,
    double? gridAngleDeg,
  }) {
    _update(
      _working.copyWith(
        dropFromUpperSlab: drop ?? _working.dropFromUpperSlab,
        panelThickness: panelThickness ?? _working.panelThickness,
        gridSystemHeight: gridSystemHeight ?? _working.gridSystemHeight,
        insulationThickness:
            insulationThickness ?? _working.insulationThickness,
        tileWidth: tileWidth ?? _working.tileWidth,
        tileLength: tileLength ?? _working.tileLength,
        gridAngle: gridAngleDeg != null
            ? gridAngleDeg * math.pi / 180.0
            : _working.gridAngle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final metrics = ArchitectCeilingGeometry.computeMetrics(
      widget.project,
      widget.project.activeStorey,
      _working,
    );

    return architectAlertDialog(
      key: const ValueKey('architect-ceiling-properties-dialog'),
      title: Text(l.architectToolCeiling),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Elevation & Clearance Summary ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: metrics.hasAnyConflict
                      ? colors.error
                      : colors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _metricRow(
                    l.architectCeilingUpperSlab,
                    '${widget.project.formatLevel(metrics.upperSlabBottom)}'
                    '${metrics.fromActualUpperSlab ? '' : ' (${l.architectCeilingUpperSlabEstimated})'}',
                  ),
                  const SizedBox(height: 4),
                  _metricRow(
                    l.architectCeilingElevation,
                    widget.project.formatLevel(metrics.ceilingElevation),
                    bold: true,
                  ),
                  const SizedBox(height: 4),
                  _metricRow(
                    l.architectCeilingClearHeight,
                    widget.project.formatLength(metrics.clearHeight),
                  ),
                  const SizedBox(height: 4),
                  _metricRow(
                    l.architectCeilingPlenum,
                    widget.project.formatLength(metrics.plenumDepth),
                    warn: metrics.hasPlenumConflict,
                  ),
                  if (metrics.hasPlenumConflict) ...[
                    const SizedBox(height: 6),
                    Text(
                      l.architectCeilingPlenumWarning,
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ],
                  if (metrics.hasBeamConflict) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.architectCeilingBeamConflictDetails(
                        metrics.beamConflicts.length,
                      ),
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- Ceiling Type ---
            SegmentedButton<SuspendedCeilingType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: SuspendedCeilingType.armstrong,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.architectCeilingArmstrong, maxLines: 1),
                  ),
                ),
                ButtonSegment(
                  value: SuspendedCeilingType.gypsumBoard,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l.architectCeilingGypsum, maxLines: 1),
                  ),
                ),
              ],
              selected: {_working.type},
              onSelectionChanged: (sel) {
                final t = sel.first;
                final defaultThick = t == SuspendedCeilingType.armstrong
                    ? 0.015
                    : 0.0125;
                _panelThickCtrl.text = formatArchitectNumericValue(
                  defaultThick,
                  decimals: 4,
                );
                _update(
                  _working.copyWith(type: t, panelThickness: defaultThick),
                );
              },
            ),
            const SizedBox(height: 14),

            // --- Drop from upper slab ---
            ArchitectNumericFormField(
              fieldKey: const ValueKey('ceiling-prop-drop'),
              controller: _dropCtrl,
              title: l.architectCeilingDropLabel,
              unitLabel: 'm',
              decimals: 3,
              min: 0.02,
              max: 3.0,
              decoration: InputDecoration(
                labelText: l.architectCeilingDropLabel,
                suffixText: 'm',
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) {
                final v = double.tryParse(text.replaceAll(',', '.'));
                if (v != null && v >= 0.02 && v <= 3.0) {
                  _commitNumeric(drop: v);
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cm in [15, 20, 25, 30, 40])
                  ChoiceChip(
                    label: Text('$cm cm'),
                    selected:
                        ((_working.dropFromUpperSlab * 100).round() == cm),
                    onSelected: (_) {
                      final m = cm / 100.0;
                      _dropCtrl.text = formatArchitectNumericValue(
                        m,
                        decimals: 3,
                      );
                      _commitNumeric(drop: m);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // --- Type-specific parameters ---
            if (_working.type == SuspendedCeilingType.armstrong) ...[
              Text(
                l.architectCeilingTileSize,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (w, len, txt) in [
                    (0.60, 0.60, '60×60'),
                    (0.60, 1.20, '60×120'),
                    (0.30, 1.20, '30×120'),
                  ])
                    ChoiceChip(
                      label: Text(txt),
                      selected:
                          (_working.tileWidth - w).abs() < 1e-3 &&
                          (_working.tileLength - len).abs() < 1e-3,
                      onSelected: (_) {
                        _tileWCtrl.text = formatArchitectNumericValue(
                          w,
                          decimals: 3,
                        );
                        _tileLCtrl.text = formatArchitectNumericValue(
                          len,
                          decimals: 3,
                        );
                        _commitNumeric(tileWidth: w, tileLength: len);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ArchitectNumericFormField(
                      controller: _tileWCtrl,
                      title: l.architectCeilingTileWidth,
                      unitLabel: 'm',
                      decimals: 3,
                      min: 0.15,
                      max: 2.0,
                      decoration: InputDecoration(
                        labelText: l.architectCeilingTileWidth,
                        suffixText: 'm',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (text) {
                        final v = double.tryParse(text.replaceAll(',', '.'));
                        if (v != null && v >= 0.15 && v <= 2.0) {
                          _commitNumeric(tileWidth: v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ArchitectNumericFormField(
                      controller: _tileLCtrl,
                      title: l.architectCeilingTileLength,
                      unitLabel: 'm',
                      decimals: 3,
                      min: 0.15,
                      max: 2.0,
                      decoration: InputDecoration(
                        labelText: l.architectCeilingTileLength,
                        suffixText: 'm',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (text) {
                        final v = double.tryParse(text.replaceAll(',', '.'));
                        if (v != null && v >= 0.15 && v <= 2.0) {
                          _commitNumeric(tileLength: v);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ArmstrongProfileType>(
                isExpanded: true,
                initialValue: _working.armstrongProfile,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final p in ArmstrongProfileType.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p.localizedName(l)),
                    ),
                ],
                onChanged: (p) {
                  if (p != null) {
                    _update(_working.copyWith(armstrongProfile: p));
                  }
                },
              ),
              const SizedBox(height: 10),
              ArchitectNumericFormField(
                controller: _angleCtrl,
                title: l.architectCeilingGridAngle,
                unitLabel: '°',
                decimals: 1,
                allowNegative: true,
                min: -180,
                max: 180,
                decoration: InputDecoration(
                  labelText: l.architectCeilingGridAngle,
                  suffixText: '°',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) {
                  final v = double.tryParse(text.replaceAll(',', '.'));
                  if (v != null && v >= -180 && v <= 180) {
                    _commitNumeric(gridAngleDeg: v);
                  }
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectCeilingGridCentered),
                value: _working.gridCentered,
                onChanged: (v) => _update(
                  _working.copyWith(gridCentered: v, clearGridOrigin: v),
                ),
              ),
            ] else ...[
              DropdownButtonFormField<GypsumBoardVariant>(
                isExpanded: true,
                initialValue: _working.gypsumVariant,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final v in GypsumBoardVariant.values)
                    DropdownMenuItem(
                      value: v,
                      child: Text(v.localizedName(l)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _update(_working.copyWith(gypsumVariant: v));
                  }
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectCeilingDoubleBoard),
                value: _working.doubleBoard,
                onChanged: (v) => _update(_working.copyWith(doubleBoard: v)),
              ),
            ],

            const Divider(height: 20),

            // --- Construction layers & insulation ---
            Row(
              children: [
                Expanded(
                  child: ArchitectNumericFormField(
                    controller: _panelThickCtrl,
                    title: l.architectCeilingPanelThickness,
                    unitLabel: 'm',
                    decimals: 4,
                    min: 0.005,
                    max: 0.10,
                    decoration: InputDecoration(
                      labelText: l.architectCeilingPanelThickness,
                      suffixText: 'm',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final v = double.tryParse(text.replaceAll(',', '.'));
                      if (v != null && v >= 0.005 && v <= 0.10) {
                        _commitNumeric(panelThickness: v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ArchitectNumericFormField(
                    controller: _carrierCtrl,
                    title: l.architectCeilingCarrierHeight,
                    unitLabel: 'm',
                    decimals: 3,
                    min: 0.01,
                    max: 0.30,
                    decoration: InputDecoration(
                      labelText: l.architectCeilingCarrierHeight,
                      suffixText: 'm',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final v = double.tryParse(text.replaceAll(',', '.'));
                      if (v != null && v >= 0.01 && v <= 0.30) {
                        _commitNumeric(gridSystemHeight: v);
                      }
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectCeilingInsulation),
              value: _working.hasInsulation,
              onChanged: (v) => _update(_working.copyWith(hasInsulation: v)),
            ),
            if (_working.hasInsulation) ...[
              ArchitectNumericFormField(
                controller: _insulationCtrl,
                title: l.architectCeilingInsulationThickness,
                unitLabel: 'm',
                decimals: 3,
                min: 0.02,
                max: 0.30,
                decoration: InputDecoration(
                  labelText: l.architectCeilingInsulationThickness,
                  suffixText: 'm',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (text) {
                  final v = double.tryParse(text.replaceAll(',', '.'));
                  if (v != null && v >= 0.02 && v <= 0.30) {
                    _commitNumeric(insulationThickness: v);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],

            // --- Designation & annotations ---
            TextFormField(
              controller: _labelCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.architectCeilingLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _update(_working.copyWith(label: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectCeilingShowLabel),
              value: _working.showLabel,
              onChanged: (v) => _update(_working.copyWith(showLabel: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.architectCeilingShowElevation),
              value: _working.showElevationMarker,
              onChanged: (v) =>
                  _update(_working.copyWith(showElevationMarker: v)),
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
          key: const ValueKey('ceiling-prop-apply'),
          onPressed: () {
            if (widget.isCurrent != null && !widget.isCurrent!()) {
              Navigator.of(context).pop();
              return;
            }
            if (widget.onApply(_working)) {
              Navigator.of(context).pop();
            }
          },
          child: Text(l.applyAction),
        ),
      ],
    );
  }

  Widget _metricRow(
    String label,
    String value, {
    bool bold = false,
    bool warn = false,
  }) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: warn ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ),
    ],
  );
}
