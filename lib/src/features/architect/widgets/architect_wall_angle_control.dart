import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_clearance_badge_layout.dart';
import '../rendering/architect_clearance_obstacles.dart';

/// Temporary angle control, using the same white-paper badge as dimensions.
class ArchitectWallAngleControl extends StatelessWidget {
  final ArchitectWall wall;
  final List<ArchitectWall> walls;
  final bool locked;
  final Offset Function(Offset) toScreen, toModel;
  final double handleClearance;
  final VoidCallback? onToggle;

  const ArchitectWallAngleControl({
    super.key,
    required this.wall,
    required this.walls,
    required this.locked,
    required this.toScreen,
    required this.toModel,
    required this.handleClearance,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 180 || constraints.maxHeight < 240) {
        return const SizedBox.shrink();
      }
      final a = toScreen(wall.startPoint), b = toScreen(wall.endPoint);
      final delta = b - a;
      final normal = delta.distance > 1e-6
          ? Offset(delta.dy, -delta.dx) / delta.distance
          : const Offset(0, -1);
      final u = delta.distance > 1e-6 ? delta / delta.distance : Offset.zero;
      final obstacles = ArchitectClearanceObstacles.forWalls(walls);
      final rect = ArchitectClearanceBadgeLayout.place(
        preferred: (a + b) / 2 + normal * 64,
        available: Rect.fromLTRB(
          8,
          104,
          constraints.maxWidth - 8,
          constraints.maxHeight - 72,
        ),
        excluded: [
          for (final p in [
            a,
            b,
            a - u * handleClearance,
            b + u * handleClearance,
          ])
            Rect.fromCircle(center: p, radius: 28),
        ],
        size: const Size(104, 44),
        intersectsWall: (r) => obstacles.intersects(
          Rect.fromPoints(toModel(r.topLeft), toModel(r.bottomRight)),
        ),
      );
      final degrees =
          (math.atan2(wall.unitVector.dy, wall.unitVector.dx) * 180 / math.pi +
              360) %
          360;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Tooltip(
              message: locked
                  ? context.l10n.architectWallAngleUnlockHelp
                  : context.l10n.architectWallAngleLockHelp,
              child: Semantics(
                label: locked
                    ? context.l10n.architectWallAngleLocked
                    : context.l10n.architectWallAngleFree,
                toggled: locked,
                button: true,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: const BorderSide(color: Color(0xff777777), width: .7),
                  ),
                  child: InkWell(
                    key: const ValueKey('architect-wall-angle-lock'),
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          AppIcon(
                            locked ? AppIconId.lock : AppIconId.unlock,
                            size: 18,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${degrees.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
