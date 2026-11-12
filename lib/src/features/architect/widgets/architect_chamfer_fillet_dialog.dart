import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/widgets/bim_distance_drafting_panel.dart';

class ArchitectChamferFilletOptions {
  final bool isFillet;
  final double value;
  final bool applyToAll;
  const ArchitectChamferFilletOptions({
    required this.isFillet,
    required this.value,
    this.applyToAll = false,
  });
}

Future<ArchitectChamferFilletOptions?> showArchitectChamferFilletDialog(
  BuildContext context, {
  required double unitToMeters,
  required String unitSymbol,
  bool initialIsFillet = false,
  double initialValue = .50,
  int decimals = 2,
  bool canApplyToAll = false,
  bool wallAxes = false,
}) async {
  var value = initialValue;
  var all = false;
  return showDialog<ArchitectChamferFilletOptions>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) {
        final l = context.l10n;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 280,
              maxHeight: MediaQuery.sizeOf(context).height - 32,
            ),
            child: SingleChildScrollView(
              child: BimDistanceDraftingPanel(
                title: wallAxes
                    ? (initialIsFillet
                          ? l.architectWallAxisRadius
                          : l.architectWallAxisSetback)
                    : (initialIsFillet
                          ? l.architectFilletRadius
                          : l.architectChamferDistance),
                length: value / unitToMeters,
                unit: unitSymbol,
                decimals: decimals,
                minimumLength: .000001 / unitToMeters,
                keypadInitiallyOpen: true,
                showContinue: false,
                showDirection: false,
                endLabel: l.applyAction,
                extraControls: canApplyToAll
                    ? CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.architectApplyToAllCorners),
                        value: all,
                        onChanged: (v) => update(() => all = v ?? false),
                      )
                    : null,
                onLength: (v) => value = v * unitToMeters,
                onEnd: () => Navigator.pop(
                  dialogContext,
                  ArchitectChamferFilletOptions(
                    isFillet: initialIsFillet,
                    value: value,
                    applyToAll: all,
                  ),
                ),
                onCancel: () => Navigator.pop(dialogContext),
                onUnlock: () {},
                onContinue: () {},
              ),
            ),
          ),
        );
      },
    ),
  );
}
