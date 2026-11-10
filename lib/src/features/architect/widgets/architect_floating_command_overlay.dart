import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Floating confirmation and cancellation pill placed directly near the active element.
class ArchitectFloatingCommandOverlay extends StatelessWidget {
  final String label;
  final bool ready;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final Offset position;
  final Widget? customContent;
  final bool showConfirm;
  final String? confirmTooltip;
  final String? cancelTooltip;

  const ArchitectFloatingCommandOverlay({
    super.key,
    required this.label,
    this.ready = true,
    required this.onCancel,
    this.onConfirm,
    required this.position,
    this.customContent,
    this.showConfirm = true,
    this.confirmTooltip,
    this.cancelTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        key: const ValueKey('architect-floating-command-overlay'),
        color: const Color(0xEE1E2430),
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ready && showConfirm
                  ? const Color(0xFF00E676).withValues(alpha: 0.6)
                  : Colors.white24,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (customContent != null) ...[
                customContent!,
                const SizedBox(width: 6),
              ],
              // Cancel button (X)
              IconButton(
                key: const ValueKey('architect-command-cancel'),
                tooltip: cancelTooltip ?? l.cancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                splashRadius: 18,
                icon: const AppIcon(
                  AppIconId.close,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: onCancel,
              ),
              if (showConfirm && onConfirm != null) ...[
                const SizedBox(width: 4),
                // Confirm button (Green checkmark)
                IconButton(
                  key: const ValueKey('architect-command-apply'),
                  tooltip: confirmTooltip ?? l.applyAction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  splashRadius: 18,
                  icon: AppIcon(
                    AppIconId.confirm,
                    color: ready ? const Color(0xFF00E676) : Colors.white24,
                    size: 20,
                  ),
                  onPressed: ready ? onConfirm : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
