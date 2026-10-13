import 'package:flutter/material.dart';
import '../../bim_editing/widgets/bim_offset_dialog.dart';

Future<double?> showStructuralOffsetDialog(
  BuildContext context, {
  required bool centimeters,
}) => showBimOffsetDialog(
  context,
  unitToMeters: centimeters ? .01 : 1,
  unitSymbol: centimeters ? 'cm' : 'm',
  inputKey: const ValueKey('structural-offset-distance'),
);
