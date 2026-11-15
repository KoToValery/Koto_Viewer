import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../services/architect_properties_session.dart';
import '../services/architect_stair_rules.dart';
import 'architect_property_number_field.dart';

/// Initial height and step-parameter prompt before tracing a freeform stair.
class ArchitectStairSetupDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectStair stair;

  const ArchitectStairSetupDialog({
    super.key,
    required this.project,
    required this.stair,
  });

  @override
  State<ArchitectStairSetupDialog> createState() =>
      _ArchitectStairSetupDialogState();
}

class _ArchitectStairSetupDialogState extends State<ArchitectStairSetupDialog> {
  final _form = GlobalKey<FormState>();
  late ArchitectStair _stair;

  ArchitectStairDesign get _d => _stair.design!;

  @override
  void initState() {
    super.initState();
    final design = ArchitectStairRules.resolveDesign(
      widget.project,
      widget.project.activeStorey,
      widget.stair.design!,
    );
    _stair = widget.stair.copyWith(design: design);
  }

  void _update(ArchitectStairDesign next) {
    try {
      next = ArchitectStairRules.resolveDesign(
        widget.project,
        widget.project.activeStorey,
        next,
      );
      next.validate();
      setState(() => _stair = _stair.copyWith(design: next));
    } on ArgumentError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.stairUnsupported)));
    }
  }

  void _confirm() {
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      final field = invalid.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (field.mounted) Scrollable.ensureVisible(field.context);
      });
      return;
    }
    Navigator.pop(context, _stair);
  }

  Widget _number(
    String key,
    String label,
    double value,
    ValueChanged<double> apply, {
    bool metric = true,
    bool integer = false,
    bool enabled = true,
    double minimum = .001,
    double maximum = 100,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ArchitectPropertyNumberField(
      key: ValueKey('stair-setup-$key'),
      project: widget.project,
      label: label,
      value: value,
      readOnly: !enabled,
      descriptor: ArchitectPropertyDescriptor(
        key,
        minimum: minimum,
        maximum: maximum,
        measure: metric
            ? ArchitectPropertyMeasure.length
            : ArchitectPropertyMeasure.count,
      ),
      helper: helper ?? (enabled ? null : context.l10n.propertiesAutomaticValue),
      onChanged: apply,
    ),
  );

  Widget _dropdown<T>(
    String key,
    String label,
    T value,
    Iterable<T> options,
    String Function(T) text,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      key: ValueKey('stair-setup-$key-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(text(option), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _d;
    final length = widget.project.formatLength;
    final targetMissing =
        d.followStoreys &&
        ArchitectStairRules.linkedRise(
              widget.project,
              widget.project.activeStorey,
              d,
            ) ==
            null;
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: Text(l.stairSetupTitle),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.risers} × ${length(d.riser)} / ${length(d.going)}',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '2h + b = ${length(2 * d.riser + d.going)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _dropdown<bool>(
                'height-mode',
                l.stairHeightMode,
                d.followStoreys,
                const [true, false],
                (v) => v ? l.stairFollowStoreys : l.stairHeightManual,
                (v) => _update(d.copyWith(followStoreys: v)),
              ),
              if (d.followStoreys)
                _dropdown<String>(
                  'target',
                  l.stairUpperStorey,
                  targetMissing ? 'missing' : d.upperStoreyId ?? '',
                  [
                    '',
                    for (final floor in widget.project.storeys)
                      if (floor.elevation >
                          widget.project.activeStorey.elevation)
                        floor.id,
                    if (targetMissing) 'missing',
                  ],
                  (id) => id.isEmpty
                      ? l.stairFloorHeight
                      : id == 'missing'
                      ? l.stairCheckUpperStorey
                      : widget.project.storeys
                            .firstWhere((s) => s.id == id)
                            .name,
                  (id) {
                    if (id == 'missing') return;
                    _update(
                      d.copyWith(
                        upperStoreyId: id.isEmpty ? null : id,
                        clearUpperStorey: id.isEmpty,
                      ),
                    );
                  },
                ),
              _number(
                'start-offset',
                l.stairStartOffset,
                d.startOffset,
                (v) => _update(d.copyWith(startOffset: v)),
                minimum: -100,
              ),
              _number(
                'rise',
                l.stairRise,
                d.rise,
                (v) => _update(d.copyWith(rise: v)),
                enabled: !d.followStoreys,
                maximum: 30,
              ),
              _number(
                'width',
                l.stairClearWidth,
                _stair.width,
                (v) => setState(() => _stair = _stair.copyWith(width: v)),
                minimum: .4,
                maximum: 10,
              ),
              _number(
                'risers',
                l.stairRisers,
                d.risers.toDouble(),
                (v) => _update(d.copyWith(manualRisers: v.toInt())),
                metric: false,
                integer: true,
                minimum: 2,
                maximum: 500,
                helper: '${l.stairRiser}: ${length(d.riser)}',
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${l.stairRisers} · ${l.stairAutomatic}'),
                value: d.manualRisers == null,
                onChanged: (v) => _update(
                  d.copyWith(
                    autoRisers: v,
                    manualRisers: v ? null : d.risers,
                  ),
                ),
              ),
              _number(
                'going',
                l.stairGoing,
                d.going,
                (v) => _update(d.copyWith(manualGoing: v)),
                minimum: .1,
                maximum: 2,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${l.stairGoing} · ${l.stairAutomatic}'),
                value: d.manualGoing == null,
                onChanged: (v) => _update(
                  d.copyWith(
                    autoGoing: v,
                    manualGoing: v ? null : d.going,
                  ),
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
          key: const ValueKey('stair-setup-confirm'),
          onPressed: targetMissing ? null : _confirm,
          child: Text(l.stairSetupConfirm),
        ),
      ],
    );
  }
}
