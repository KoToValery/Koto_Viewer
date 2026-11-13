import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_clearance_badge_layout.dart';
import '../rendering/architect_clearance_obstacles.dart';
import '../services/architect_polygon_editor.dart';

/// The selected contour's temporary angle constraint follows the wall badge.
class ArchitectPolygonAngleControl extends StatelessWidget {
  final List<Offset> polygon;
  final List<ArchitectWall> walls;
  final int edge;
  final bool locked;
  final Offset Function(Offset) toScreen, toModel;
  final double scale, handleClearance;
  final VoidCallback? onToggle;
  const ArchitectPolygonAngleControl({
    super.key,
    required this.polygon,
    required this.walls,
    required this.edge,
    required this.locked,
    required this.toScreen,
    required this.toModel,
    required this.scale,
    required this.handleClearance,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (polygon.length < 3 ||
          edge < 0 ||
          edge >= polygon.length ||
          constraints.maxWidth < 180 ||
          constraints.maxHeight < 240) {
        return const SizedBox.shrink();
      }
      final a = toScreen(polygon[edge]),
          b = toScreen(polygon[(edge + 1) % polygon.length]);
      final delta = b - a;
      final normal = delta.distance > 1e-6
          ? Offset(delta.dy, -delta.dx) / delta.distance
          : const Offset(0, -1);
      final obstacles = ArchitectClearanceObstacles.forWalls(walls);
      final rect = ArchitectClearanceBadgeLayout.place(
        preferred: (a + b) / 2 + normal * 76,
        available: Rect.fromLTRB(
          8,
          64,
          constraints.maxWidth - 8,
          constraints.maxHeight - 72,
        ),
        excluded: [
          for (var i = 0; i < polygon.length; i++)
            for (final p in [
              polygon[i],
              ArchitectPolygonEditor.offsetVertexHandle(
                polygon,
                i,
                scale,
                handleClearance,
              ),
              ArchitectPolygonEditor.offsetEdgeHandle(
                polygon,
                i,
                scale,
                handleClearance,
              ),
            ])
              Rect.fromCircle(center: toScreen(p), radius: 28),
        ],
        size: const Size(104, 44),
        intersectsWall: (r) => obstacles.intersects(
          Rect.fromPoints(toModel(r.topLeft), toModel(r.bottomRight)),
        ),
      );
      final degrees =
          (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
      final l = context.l10n;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Tooltip(
              message: locked
                  ? l.architectPolygonAngleUnlockHelp
                  : l.architectPolygonAngleLockHelp,
              child: Semantics(
                label: locked
                    ? l.architectPolygonAngleLocked
                    : l.architectPolygonAngleFree,
                toggled: locked,
                button: true,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: const BorderSide(color: Color(0xff777777), width: .7),
                  ),
                  child: InkWell(
                    key: const ValueKey('architect-polygon-angle-lock'),
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
