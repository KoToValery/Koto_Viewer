import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';

/// The same reference choice is available in the toolbar and beside the length.
class ArchitectWallReferenceControl extends StatelessWidget {
  final WallReferenceLine value;
  final ValueChanged<WallReferenceLine> onChanged;

  const ArchitectWallReferenceControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
            for (final reference in [
              WallReferenceLine.center,
              WallReferenceLine.inner,
              WallReferenceLine.outer,
              // Display saved legacy defaults without changing their placement.
              if (value == WallReferenceLine.left ||
                  value == WallReferenceLine.right)
                value,
            ])
              DropdownMenuItem(
                value: reference,
                child: Text(
                  switch (reference) {
                    WallReferenceLine.center => l.architectWallReferenceCenter,
                    WallReferenceLine.inner => l.architectWallReferenceInner,
                    WallReferenceLine.outer => l.architectWallReferenceOuter,
                    WallReferenceLine.left => l.architectWallReferenceLeft,
                    WallReferenceLine.right => l.architectWallReferenceRight,
                  },
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
