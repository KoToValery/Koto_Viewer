import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';

/// Quick instance edit: keep core and insulation explicit instead of scaling layers.
class ArchitectWallThicknessDialog extends StatefulWidget {
  final ArchitectProject project;
  final ArchitectWall wall;
  final bool Function(double core, double insulation) onApply;
  const ArchitectWallThicknessDialog({
    super.key,
    required this.project,
    required this.wall,
    required this.onApply,
  });
  @override
  State<ArchitectWallThicknessDialog> createState() => _ThicknessState();
}

class _ThicknessState extends State<ArchitectWallThicknessDialog> {
  final form = GlobalKey<FormState>();
  late final core = TextEditingController(
    text: number(widget.wall.coreThickness),
  );
  late final insulation = TextEditingController(
    text: number(widget.wall.insulationThickness),
  );
  String number(double value) => widget.project.units
      .toUnit(value)
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  double? parse(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null || !value.isFinite
        ? null
        : widget.project.units.fromUnit(value);
  }

  @override
  void dispose() {
    core.dispose();
    insulation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = parse(core.text), i = parse(insulation.text);
    Widget field(
      TextEditingController controller,
      String label,
      String key,
      double minimum,
    ) => TextFormField(
      key: ValueKey(key),
      controller: controller,
      autofocus: controller == core,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label (${widget.project.units.symbol})',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
      validator: (text) {
        final value = parse(text ?? '');
        return value == null || value < minimum
            ? l.architectWallInvalidThickness
            : null;
      },
    );
    return AlertDialog(
      title: Text(l.architectWallQuickThickness),
      content: SizedBox(
        width: 300,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(
                  core,
                  widget.wall.hasInsulation
                      ? l.architectWallQuickCore
                      : l.architectWallQuickThickness,
                  'architect-wall-core-input',
                  .001,
                ),
                if (widget.wall.hasInsulation) ...[
                  const SizedBox(height: 12),
                  field(
                    insulation,
                    l.architectWallQuickInsulation,
                    'architect-wall-insulation-input',
                    0,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l.architectPropertyTotal}: ${c == null || i == null ? '—' : widget.project.formatLength(c + i)}',
                  ),
                ],
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
          key: const ValueKey('architect-wall-thickness-save'),
          onPressed: () {
            if (form.currentState!.validate() &&
                widget.onApply(parse(core.text)!, parse(insulation.text)!)) {
              Navigator.pop(context);
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
