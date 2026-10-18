import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import 'architect_material_layer_label.dart';

class ArchitectWallPlinthDialog extends StatefulWidget {
  final ArchitectProject project;
  final List<ArchitectWallPlinth> values;
  final bool Function(ArchitectWallPlinthPatch) onApply;
  const ArchitectWallPlinthDialog({
    super.key,
    required this.project,
    required this.values,
    required this.onApply,
  });
  @override
  State<ArchitectWallPlinthDialog> createState() => _PlinthState();
}

class _PlinthState extends State<ArchitectWallPlinthDialog> {
  final form = GlobalKey<FormState>(), edited = <String>{};
  bool mixed<T>(T Function(ArchitectWallPlinth) f) =>
      widget.values.map(f).toSet().length > 1;
  late bool? enabled = mixed((p) => p.enabled)
      ? null
      : widget.values.first.enabled;
  late ArchitectMaterial? finish = mixed((p) => p.finish)
      ? null
      : widget.values.first.finish;
  String number(double v) =>
      v.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  late final height = TextEditingController(
    text: mixed((p) => p.height)
        ? ''
        : number(widget.project.units.toUnit(widget.values.first.height)),
  );
  late final base = TextEditingController(
    text: mixed((p) => p.baseElevation)
        ? ''
        : number(widget.values.first.baseElevation),
  );
  double? parse(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v != null && v.isFinite ? v : null;
  }

  String? error;
  @override
  void dispose() {
    height.dispose();
    base.dispose();
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final h = parse(height.text), b = parse(base.text);
    if (enabled != false &&
        ((edited.contains('height') && (h == null || h <= 0)) ||
            (edited.contains('base') && b == null))) {
      setState(() => error = context.l10n.wallLayerInvalid);
      return;
    }
    final patch = ArchitectWallPlinthPatch(
      enabled: edited.contains('enabled') ? enabled : null,
      height: edited.contains('height') && h != null && h > 0
          ? widget.project.units.fromUnit(h)
          : null,
      baseElevation: edited.contains('base') ? b : null,
      finish: edited.contains('finish') ? finish : null,
    );
    if (widget.onApply(patch)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.wallPlinth),
      content: SizedBox(
        width: 360,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  key: const ValueKey('wall-plinth-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.wallPlinthEnabled),
                  value: enabled,
                  tristate: mixed((p) => p.enabled),
                  onChanged: (v) => setState(() {
                    enabled = v ?? false;
                    edited.add('enabled');
                  }),
                ),
                if (enabled != false) ...[
                  TextFormField(
                    key: const ValueKey('wall-plinth-height'),
                    controller: height,
                    decoration: InputDecoration(
                      labelText: 'H= (${widget.project.units.symbol})',
                      hintText: l.wallMixedValue,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => edited.add('height'),
                    validator: (_) {
                      final v = parse(height.text);
                      return mixed((p) => p.height) &&
                              !edited.contains('height')
                          ? null
                          : v == null || v <= 0
                          ? l.architectWallInvalidThickness
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ArchitectMaterial>(
                    initialValue: finish,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.wallPlinthFinish),
                    hint: Text(l.wallMixedValue),
                    items: [
                      for (final m in [
                        ArchitectMaterial.render,
                        ArchitectMaterial.tile,
                        ArchitectMaterial.stone,
                      ])
                        DropdownMenuItem(value: m, child: Text(m.label(l))),
                    ],
                    onChanged: (v) {
                      if (v != null)
                        setState(() {
                          finish = v;
                          edited.add('finish');
                        });
                    },
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.wallAdvanced),
                    children: [
                      TextFormField(
                        key: const ValueKey('wall-plinth-base'),
                        controller: base,
                        decoration: InputDecoration(
                          labelText: l.wallPlinthBase,
                          helperText: l.wallPlinthBaseHelp,
                          hintText: l.wallMixedValue,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onChanged: (_) => edited.add('base'),
                      ),
                    ],
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('wall-plinth-save'),
          onPressed: save,
          child: Text(l.save),
        ),
      ],
    );
  }
}
