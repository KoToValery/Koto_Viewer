import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

class ArchitectProjectionStatus extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;
  const ArchitectProjectionStatus({
    super.key,
    required this.failed,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: failed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.architectProjectionLoadFailed),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.retry),
                ),
              ],
            )
          : CircularProgressIndicator(
              semanticsLabel: l.architectProjectionLoading,
            ),
    );
  }
}
