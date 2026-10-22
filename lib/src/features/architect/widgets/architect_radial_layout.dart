import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Concentric arcs leave the picked point and the spaces between buttons open.
/// The same occupied bounds are used by nearby drawing readouts.
class ArchitectRadialLayout {
  final List<Offset> targets;
  final Rect badge;
  final Rect clusterRect;
  final double buttonSize;
  final double contentHeight;

  const ArchitectRadialLayout(
    this.targets,
    this.badge, [
    this.clusterRect = Rect.zero,
    this.buttonSize = 52,
    this.contentHeight = 0,
  ]);

  List<Rect> get occupied => [
    if (!badge.isEmpty) badge.inflate(4),
    for (final target in targets)
      Rect.fromCenter(
        center: target,
        width: buttonSize + 8,
        height: buttonSize + 8,
      ),
  ];

  static ArchitectRadialLayout compute({
    required Size size,
    required Offset center,
    required int count,
    bool hasTitle = false,
    List<Rect> elementBounds = const [],
  }) {
    final result = _fit(size, center, count, hasTitle, elementBounds);
    if (result != null) return result;
    // Very short viewports keep touch targets usable and scroll the fan.
    final tall = Size(size.width, math.max(size.height, 640));
    final fallback = _fit(tall, center, count, hasTitle, elementBounds);
    return fallback ?? ArchitectRadialLayout(const [], Rect.zero);
  }

  static ArchitectRadialLayout? _fit(
    Size size,
    Offset center,
    int count,
    bool hasTitle,
    List<Rect> elementBounds,
  ) {
    const margin = 8.0;
    final available = (Offset.zero & size).deflate(margin);
    if (available.width < 44 || available.height < 44) return null;
    final anchor = Offset(
      center.dx.clamp(available.left + 4, available.right - 4),
      center.dy.clamp(available.top + 4, available.bottom - 4),
    );
    final dot = Rect.fromCenter(center: anchor, width: 6, height: 6);
    if (count == 0) return ArchitectRadialLayout(const [], dot);
    final protected = [
      for (final rect in elementBounds)
        if (rect.overlaps(available)) rect.intersect(available).inflate(4),
    ];
    final element = protected.isEmpty
        ? null
        : protected.reduce((a, b) => a.expandToInclude(b));
    final picked = Rect.fromCircle(center: anchor, radius: 24);
    // Prefer full-size controls. Compact controls are only used if none fit.
    for (final button in [52.0, 48.0, 44.0]) {
      ArchitectRadialLayout? best;
      var bestScore = double.infinity;
      for (final sweep in [
        math.pi * 5 / 6,
        math.pi,
        math.pi * 2 / 3,
        math.pi / 2,
      ]) {
        final arcs = <(double radius, int count, double step)>[];
        var remaining = count;
        var radius = button * 1.35;
        while (remaining > 0) {
          final step = 2 * math.asin((button + 6) / (2 * radius));
          final capacity = (sweep / step).floor() + 1;
          final n = math.min(remaining, capacity);
          arcs.add((radius, n, step));
          remaining -= n;
          radius += button + 6;
        }
        for (var direction = 0; direction < 24; direction++) {
          final angle = -math.pi / 2 + direction * math.pi / 12;
          final targets = <Offset>[];
          for (final (r, n, step) in arcs) {
            for (var i = 0; i < n; i++) {
              final a = angle + (i - (n - 1) / 2) * step;
              targets.add(anchor + Offset(math.cos(a), math.sin(a)) * r);
            }
          }
          Rect buttonRect(Offset target) =>
              Rect.fromCenter(center: target, width: button, height: button);
          var bounds = targets
              .map(buttonRect)
              .reduce((a, b) => a.expandToInclude(b));
          var badge = dot;
          if (hasTitle) {
            final width = math.min(196.0, math.max(120.0, bounds.width * .7));
            badge = Rect.fromCenter(
              center: Offset(
                bounds.center.dx,
                math.sin(angle) > .2 ? bounds.bottom + 20 : bounds.top - 20,
              ),
              width: width,
              height: 28,
            );
            bounds = bounds.expandToInclude(badge);
          }
          if (bounds.width > available.width + 1e-8 ||
              bounds.height > available.height + 1e-8) {
            continue;
          }
          final offsets = [
            Offset.zero,
            if (element != null) ...[
              Offset(element.left - 8 - bounds.right, 0),
              Offset(element.right + 8 - bounds.left, 0),
              Offset(0, element.top - 8 - bounds.bottom),
              Offset(0, element.bottom + 8 - bounds.top),
            ],
          ];
          for (final offset in offsets) {
            final moved = bounds.shift(offset);
            final shift =
                offset +
                Offset(
                  moved.left < available.left
                      ? available.left - moved.left
                      : moved.right > available.right
                      ? available.right - moved.right
                      : 0,
                  moved.top < available.top
                      ? available.top - moved.top
                      : moved.bottom > available.bottom
                      ? available.bottom - moved.bottom
                      : 0,
                );
            final placed = targets.map((p) => p + shift).toList();
            final placedBadge = hasTitle ? badge.shift(shift) : dot;
            final occupied = [
              for (final p in placed) buttonRect(p),
              if (hasTitle) placedBadge,
            ];
            double overlap(Rect a, Rect b) {
              if (!a.overlaps(b)) return 0;
              final intersection = a.intersect(b);
              return intersection.width *
                  intersection.height /
                  (button * button);
            }

            final score =
                occupied.fold<double>(
                  0,
                  (sum, rect) =>
                      sum +
                      overlap(rect, picked) * 100000 +
                      protected.fold<double>(
                        0,
                        (v, element) => v + overlap(rect, element) * 1000,
                      ),
                ) +
                shift.distance * 2 +
                bounds.width * bounds.height * .001 +
                arcs.last.$1 * .1 +
                direction * .001;
            if (score < bestScore) {
              bestScore = score;
              best = ArchitectRadialLayout(
                placed,
                placedBadge,
                bounds.shift(shift),
                button,
                size.height,
              );
            }
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }
}
