import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';
import 'architect_wall_reference_control.dart';

/// Compact controls share the toolbar's draft state and keep exact input open.
class ArchitectWallDraftControls extends StatelessWidget {
  final WallReferenceLine reference;
  final ValueChanged<WallReferenceLine> onReference;
  final VoidCallback onFlip, onCurve;
  final bool flipped, curved, canCurve;

  const ArchitectWallDraftControls({
    super.key,
    required this.reference,
    required this.onReference,
    required this.onFlip,
    required this.onCurve,
    required this.flipped,
    required this.curved,
    required this.canCurve,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ArchitectWallReferenceControl(
          key: const ValueKey('wall-panel-reference'),
          value: reference,
          onChanged: onReference,
          inline: true,
        ),
      ),
      IconButton(
        key: const ValueKey('wall-panel-flip'),
        tooltip: context.l10n.architectWallFlipSide,
        isSelected: flipped,
        onPressed: onFlip,
        icon: const AppIcon(AppIconId.flipHorizontal, size: 20),
      ),
      IconButton(
        key: const ValueKey('wall-panel-curve'),
        tooltip: context.l10n.wallArc,
        isSelected: curved,
        onPressed: canCurve ? onCurve : null,
        icon: const AppIcon(AppIconId.roundedCorner, size: 20),
      ),
    ],
  );
}
