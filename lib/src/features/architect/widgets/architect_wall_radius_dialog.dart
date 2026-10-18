import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';

class ArchitectWallRadiusDialog extends StatefulWidget {
  final ArchitectProject project;
  final double radius, minimum;
  const ArchitectWallRadiusDialog({
    super.key,
    required this.project,
    required this.radius,
    required this.minimum,
  });
  @override
  State<ArchitectWallRadiusDialog> createState() => _RadiusState();
}

class _RadiusState extends State<ArchitectWallRadiusDialog> {
  final form = GlobalKey<FormState>();
  late final input = TextEditingController(
    text: widget.project.units
        .toUnit(widget.radius)
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'\.?0+$'), ''),
  );
  double? get value => double.tryParse(input.text.trim().replaceAll(',', '.'));
  void save() {
    if (form.currentState!.validate())
      Navigator.pop(context, widget.project.units.fromUnit(value!));
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.wallArc),
    content: Form(
      key: form,
      child: TextFormField(
        key: const ValueKey('wall-arc-radius-input'),
        controller: input,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'R= (${widget.project.units.symbol})',
        ),
        validator: (_) {
          final v = value;
          return v == null ||
                  !v.isFinite ||
                  widget.project.units.fromUnit(v) < widget.minimum
              ? context.l10n.wallArcInvalidRadius
              : null;
        },
        onFieldSubmitted: (_) => save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: save, child: Text(context.l10n.applyAction)),
    ],
  );
}
