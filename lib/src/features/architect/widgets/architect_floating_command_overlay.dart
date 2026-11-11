import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'architect_canvas_hint.dart';

/// Independent, touch-friendly actions with optional lightweight context chips.
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
  final Key surfaceKey;

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
    this.surfaceKey = const ValueKey('architect-floating-command-overlay'),
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasConfirm = showConfirm && onConfirm != null;
    final availableWidth = (MediaQuery.sizeOf(context).width - position.dx - 8)
        .clamp(hasConfirm ? 100.0 : 48.0, double.infinity);
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        key: surfaceKey,
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: availableWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty) ...[
                Flexible(
                  child: ArchitectCanvasHint(
                    message: label,
                    maxLines: 1,
                    maxWidth: 180,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (customContent != null) ...[
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Material(
                      // Existing embedded editors use light text. Their small
                      // surface stays independent of the two action buttons.
                      color: const Color(0xF02A333B),
                      borderRadius: BorderRadius.circular(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: customContent!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              _action(
                key: const ValueKey('architect-command-cancel'),
                discKey: const ValueKey('architect-command-cancel-disc'),
                tooltip: cancelTooltip ?? l.cancel,
                icon: AppIconId.close,
                color: const Color(0xFF65737E),
                onPressed: onCancel,
              ),
              if (hasConfirm) ...[
                const SizedBox(width: 4),
                _action(
                  key: const ValueKey('architect-command-apply'),
                  discKey: const ValueKey('architect-command-apply-disc'),
                  tooltip: confirmTooltip ?? l.applyAction,
                  icon: AppIconId.confirm,
                  color: const Color(0xFF18846B),
                  onPressed: ready ? onConfirm : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required Key key,
    required Key discKey,
    required String tooltip,
    required AppIconId icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return IconButton(
      key: key,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        fixedSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: Container(
        key: discKey,
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: .27)
                : const Color(0xFFE2E6E9),
            width: .8,
          ),
          boxShadow: [
            if (enabled)
              const BoxShadow(
                color: Color(0x14000000),
                blurRadius: 5,
                offset: Offset(0, 1),
              ),
          ],
        ),
        child: AppIcon(
          icon,
          color: enabled ? color : const Color(0xFFBFC8CD),
          size: 18,
        ),
      ),
      onPressed: onPressed,
    );
  }
}
