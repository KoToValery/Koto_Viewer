import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/bim_work_project.dart';

/// Shared elevation entry with localised validation and centimetre precision.
Future<double?> showBimElevationDialog({
  required BuildContext context,
  required double initialElevation,
  required Iterable<double> occupiedElevations,
}) async {
  final l10n = context.l10n;
  final occupied = occupiedElevations
      .map(BimStoreyUnderlay.formatElevation)
      .toSet();
  final formKey = GlobalKey<FormState>();
  var input = initialElevation.toStringAsFixed(2);
  return showDialog<double>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.bimProjectEditElevation),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: l10n.bimProjectElevation,
              suffixText: 'm',
              helperText: l10n.bimProjectElevationHelper,
            ),
            onChanged: (value) => input = value,
            validator: (value) {
              final elevation = BimStoreyUnderlay.parseElevation(value ?? '');
              if (elevation == null) return l10n.bimProjectInvalidElevation;
              if (occupied.contains(
                BimStoreyUnderlay.formatElevation(elevation),
              )) {
                return l10n.bimProjectDuplicateElevation;
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(
                  context,
                ).pop(BimStoreyUnderlay.parseElevation(input));
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(
                  context,
                ).pop(BimStoreyUnderlay.parseElevation(input));
              }
            },
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}
