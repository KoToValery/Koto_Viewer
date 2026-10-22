import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';

Future<({double? depth})?> showArchitectViewDepth(
  BuildContext context,
  ArchitectProject project,
  double? depth,
) => showDialog<({double? depth})>(
  context: context,
  builder: (_) => _ViewDepthDialog(project: project, depth: depth),
);

class _ViewDepthDialog extends StatefulWidget {
  final ArchitectProject project;
  final double? depth;
  const _ViewDepthDialog({required this.project, required this.depth});
  @override
  State<_ViewDepthDialog> createState() => _ViewDepthState();
}

class _ViewDepthState extends State<_ViewDepthDialog> {
  final form = GlobalKey<FormState>();
  late bool unlimited = widget.depth == null;
  late final input = TextEditingController(
    text: widget.project.units.toUnit(widget.depth ?? 10).toStringAsFixed(2),
  );
  double? get depth {
    final value = double.tryParse(input.text.trim().replaceAll(',', '.'));
    return value == null ? null : widget.project.units.fromUnit(value);
  }
  void save() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, (depth: unlimited ? null : depth));
    }
  }
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectViewDepth),
      content: SizedBox(
        width: 320,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                key: const ValueKey('architect-view-depth-unlimited'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectViewUnlimited),
                value: unlimited,
                onChanged: (value) => setState(() => unlimited = value!),
              ),
              TextFormField(
                key: const ValueKey('architect-view-depth-input'),
                controller: input,
                enabled: !unlimited,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l.architectViewDepth} (${widget.project.units.symbol})',
                ),
                validator: (_) => !unlimited &&
                    (depth == null || !depth!.isFinite || depth! < .01)
                    ? l.architectViewDepthInvalid : null,
                onFieldSubmitted: (_) => save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('architect-view-depth-save'),
          onPressed: save,
          child: Text(l.applyAction),
        ),
      ],
    );
  }
}
