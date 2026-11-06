import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

class ArchitectCommandPreviewBar extends StatelessWidget {
  final String label;
  final bool ready;
  final VoidCallback onCancel, onConfirm;

  const ArchitectCommandPreviewBar({
    super.key,
    required this.label,
    required this.ready,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      key: const ValueKey('architect-command-bar'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: ready
                    ? l.architectCommandReview
                    : l.architectCommandAim,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('architect-command-cancel'),
              tooltip: l.cancel,
              onPressed: onCancel,
              icon: const AppIcon(AppIconId.close),
            ),
            IconButton(
              key: const ValueKey('architect-command-apply'),
              tooltip: l.applyAction,
              onPressed: ready ? onConfirm : null,
              icon: AppIcon(
                AppIconId.confirm, color: ready ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
