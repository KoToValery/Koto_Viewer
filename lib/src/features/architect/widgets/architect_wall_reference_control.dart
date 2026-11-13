import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';

/// The same reference choice is available in the toolbar and beside the length.
class ArchitectWallReferenceControl extends StatelessWidget {
  final WallReferenceLine value;
  final ValueChanged<WallReferenceLine> onChanged;
  final bool inline;

  const ArchitectWallReferenceControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(WallReferenceLine reference) => switch (reference) {
      WallReferenceLine.center => l.architectWallReferenceCenter,
      WallReferenceLine.inner => l.architectWallReferenceInner,
      WallReferenceLine.outer => l.architectWallReferenceOuter,
      WallReferenceLine.left => l.architectWallReferenceLeft,
      WallReferenceLine.right => l.architectWallReferenceRight,
    };
    final references = [
      WallReferenceLine.center,
      WallReferenceLine.inner,
      WallReferenceLine.outer,
      // Display saved legacy defaults without changing their placement.
      if (value == WallReferenceLine.left || value == WallReferenceLine.right)
        value,
    ];
    if (inline) {
      final colors = Theme.of(context).colorScheme;
      return Semantics(
        label: l.architectWallLeadingLine,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final reference in references)
              IconButton(
                key: ValueKey('wall-panel-reference-${reference.name}'),
                tooltip: label(reference),
                isSelected: value == reference,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: value == reference
                      ? colors.secondaryContainer
                      : null,
                  side: value == reference
                      ? BorderSide(color: colors.onSecondaryContainer)
                      : BorderSide.none,
                ),
                onPressed: () {
                  onChanged(reference);
                  // Keep Enter/numeric keys with the enclosing exact panel.
                  Focus.of(context).requestFocus();
                },
                icon: AppIcon(switch (reference) {
                  WallReferenceLine.center => AppIconId.alignCenter,
                  WallReferenceLine.inner ||
                  WallReferenceLine.left => AppIconId.alignLeft,
                  WallReferenceLine.outer ||
                  WallReferenceLine.right => AppIconId.alignRight,
                }, size: 20),
              ),
          ],
        ),
      );
    }
    return Semantics(
      label: l.architectWallLeadingLine,
      child: Tooltip(
        message: l.architectWallLeadingLineHelp,
        child: DropdownButton<WallReferenceLine>(
          value: value,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: Theme.of(context).textTheme.bodySmall,
          items: [
            for (final reference in references)
              DropdownMenuItem(
                value: reference,
                child: Text(
                  label(reference),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (reference) {
            if (reference != null) onChanged(reference);
          },
        ),
      ),
    );
  }
}
