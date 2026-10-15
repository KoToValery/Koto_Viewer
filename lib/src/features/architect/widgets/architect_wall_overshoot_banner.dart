// === SECTION: ARCHITECT WALL OVERSHOOT BANNER ===

import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_wall_overshoot_detector.dart';

/// Floating banner notifying the user of an unintentional wall overshoot stub
/// and offering automatic cleanup (trim) or dismiss (keep as is).
class ArchitectWallOvershootBanner extends StatelessWidget {
  final ArchitectWallOvershoot overshoot;
  final VoidCallback onTrim;
  final VoidCallback onDismiss;

  const ArchitectWallOvershootBanner({
    super.key,
    required this.overshoot,
    required this.onTrim,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF232530),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amberAccent.withAlpha(160), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_fix_high_rounded,
                color: Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.architectWallOvershootDetected(overshoot.overshootCm),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              // Trim Button
              FilledButton.icon(
                key: const ValueKey('architect-overshoot-trim'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 30),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: onTrim,
                icon: const Icon(Icons.content_cut_rounded, size: 14),
                label: Text(l10n.architectWallOvershootTrim),
              ),
              const SizedBox(width: 6),
              // Dismiss Button
              Tooltip(
                message: l10n.architectWallOvershootDismiss,
                child: IconButton(
                  key: const ValueKey('architect-overshoot-dismiss'),
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
