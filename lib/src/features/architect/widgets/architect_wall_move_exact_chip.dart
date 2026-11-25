import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Non-blocking floating chip shown after moving a wall so the user can
/// optionally refine the exact displacement distance along the same direction.
class ArchitectWallMoveExactChip extends StatelessWidget {
  final String distanceText;
  final String? angleText;
  final Offset position;
  final VoidCallback onEdit;
  final VoidCallback onDismiss;

  const ArchitectWallMoveExactChip({
    super.key,
    required this.distanceText,
    this.angleText,
    required this.position,
    required this.onEdit,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = angleText == null ? distanceText : '$distanceText · $angleText';
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        key: const ValueKey('architect-wall-move-exact-chip'),
        color: const Color(0xF02A333B),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Colors.cyanAccent.withValues(alpha: 0.75),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: l.architectWallMoveExactDistance,
              child: InkWell(
                key: const ValueKey('architect-wall-move-exact-edit'),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 15,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 16,
              color: Colors.white24,
            ),
            Tooltip(
              message: l.close,
              child: InkWell(
                key: const ValueKey('architect-wall-move-exact-dismiss'),
                onTap: onDismiss,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
