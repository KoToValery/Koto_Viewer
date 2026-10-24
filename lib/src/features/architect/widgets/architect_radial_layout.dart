import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_editing/models/bim_context_menu_settings.dart';

/// Slots always run clockwise from north. Only the complete cluster translates.
class ArchitectRadialLayout {
  final List<Offset> targets;
  final Rect badge, clusterRect;
  final Offset moreTarget;
  final double buttonSize, contentHeight;
  const ArchitectRadialLayout(
    this.targets,
    this.badge,
    this.clusterRect,
    this.moreTarget,
    this.buttonSize,
    this.contentHeight,
  );
  List<Rect> get occupied => [
    if (!badge.isEmpty) badge.inflate(4),
    for (final target in [...targets, moreTarget])
      Rect.fromCenter(
        center: target,
        width: buttonSize + 8,
        height: buttonSize + 8,
      ),
  ];
  static ArchitectRadialLayout compute({
    required Size size,
    required Offset center,
    BimContextMenuMode mode = BimContextMenuMode.circle,
    bool hasTitle = false,
    List<Rect> elementBounds = const [],
  }) {
    const button = 52.0, gap = 8.0, radius = 84.0, margin = 12.0;
    final side = mode == BimContextMenuMode.circle
        ? radius * 2 + button
        : button * 3 + gap * 2;
    final titleHeight = hasTitle ? 36.0 : 0.0;
    final height = side + titleHeight;
    final contentHeight = math.max(size.height, height + margin * 2);
    final available = Rect.fromLTWH(
      margin,
      margin,
      math.max(0, size.width - margin * 2),
      contentHeight - margin * 2,
    );
    final origin = center - Offset(side / 2, side / 2 + titleHeight);
    final desired = Rect.fromLTWH(origin.dx, origin.dy, side, height);
    Rect clamp(Rect r) => r.shift(
      Offset(
        r.left < available.left
            ? available.left - r.left
            : r.right > available.right
            ? available.right - r.right
            : 0,
        r.top < available.top
            ? available.top - r.top
            : r.bottom > available.bottom
            ? available.bottom - r.bottom
            : 0,
      ),
    );
    final candidates = <Rect>[
      clamp(desired),
      for (final e in elementBounds) ...[
        clamp(desired.shift(Offset(e.left - gap - desired.right, 0))),
        clamp(desired.shift(Offset(e.right + gap - desired.left, 0))),
        clamp(desired.shift(Offset(0, e.top - gap - desired.bottom))),
        clamp(desired.shift(Offset(0, e.bottom + gap - desired.top))),
      ],
    ];
    double score(Rect r) {
      var overlap = 0.0;
      for (final e in elementBounds) {
        if (r.overlaps(e)) {
          final i = r.intersect(e);
          overlap += i.width * i.height;
        }
      }
      return overlap * 100 + (r.center - desired.center).distance;
    }

    candidates.sort((a, b) => score(a).compareTo(score(b)));
    final frame = candidates.first;
    final middle = Offset(frame.center.dx, frame.top + titleHeight + side / 2);
    const grid = [
      Offset(0, -1),
      Offset(1, -1),
      Offset(1, 0),
      Offset(1, 1),
      Offset(0, 1),
      Offset(-1, 1),
      Offset(-1, 0),
      Offset(-1, -1),
    ];
    final targets = [
      for (var i = 0; i < 8; i++)
        middle +
            (mode == BimContextMenuMode.circle
                ? Offset(
                        math.cos(-math.pi / 2 + i * math.pi / 4),
                        math.sin(-math.pi / 2 + i * math.pi / 4),
                      ) *
                      radius
                : grid[i] * (button + gap)),
    ];
    return ArchitectRadialLayout(
      targets,
      hasTitle ? Rect.fromLTWH(frame.left, frame.top, side, 28) : Rect.zero,
      frame,
      middle,
      button,
      contentHeight,
    );
  }
}
