import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../models/structural_element.dart';

/// Endpoint labels share one row per side; only their short leaders may bend.
class GridAxisBubbleLayout {
  static double textScale(double zoom) =>
      math.pow(zoom.clamp(.001, 1), .2).toDouble().clamp(.65, 1);
  static Map<(String, bool), Offset> build({
    required List<StructuralGridAxis> axes,
    required Offset Function(Offset) project,
    required String Function(StructuralGridAxis) levels,
    double zoom = 1,
    double? labelScale,
  }) {
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final result = <(String, bool), Offset>{}, used = <String>{};
    final fontScale = labelScale ?? textScale(zoom);
    for (final first in axes) {
      if (used.contains(first.id)) continue;
      final delta = project(first.end) - project(first.start);
      if (delta.distance <= 0) continue;
      final u = delta / delta.distance, n = Offset(-u.dy, u.dx);
      final family = axes
          .where((a) => first.isParallelTo(a, toleranceRad: .001))
          .toList();
      used.addAll(family.map((a) => a.id));
      for (final side in [-1, 1]) {
        final entries =
            <
              ({
                String id,
                bool start,
                double wanted,
                double before,
                double after,
              })
            >[];
        var row = side < 0 ? double.infinity : -double.infinity;
        for (final axis in family) {
          final a = project(axis.start), b = project(axis.end);
          for (final start in [true, false]) {
            final endpoint = start ? a : b, other = start ? b : a;
            if ((dot(endpoint - other, u) < 0 ? -1 : 1) != side) continue;
            row = side < 0
                ? math.min(row, dot(endpoint, u))
                : math.max(row, dot(endpoint, u));
            if (start ? !axis.bubbleAtStart : !axis.bubbleAtEnd) continue;
            final name = TextPainter(
              text: TextSpan(
                text: axis.name,
                style: TextStyle(
                  fontSize: 11 * fontScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final note = TextPainter(
              text: TextSpan(
                text: levels(axis),
                style: TextStyle(fontSize: 9 * fontScale),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final radius = math.max(
              8 * fontScale,
              math.max(name.width, name.height) / 2 + 1.8 * fontScale,
            );
            // Text stays upright on screen, including the level below the circle.
            // Project its actual bounds onto the packing direction (also for
            // horizontal or rotated axes), rather than using its width alone.
            var lo = -radius, hi = radius;
            if (levels(axis).isNotEmpty) {
              final rect = Rect.fromLTWH(
                -note.width / 2,
                radius + 3 * fontScale,
                note.width,
                note.height,
              );
              for (final corner in [
                rect.topLeft,
                rect.topRight,
                rect.bottomLeft,
                rect.bottomRight,
              ]) {
                final value = dot(corner, n);
                lo = math.min(lo, value);
                hi = math.max(hi, value);
              }
            }
            entries.add((
              id: axis.id,
              start: start,
              wanted: dot(endpoint, n),
              before: -lo / zoom,
              after: hi / zoom,
            ));
          }
        }
        entries.sort((a, b) => a.wanted.compareTo(b.wanted));
        final packed = <double>[];
        for (var i = 0; i < entries.length; i++) {
          packed.add(
            i == 0
                ? entries[i].wanted
                : math.max(
                    entries[i].wanted,
                    packed.last +
                        entries[i - 1].after +
                        entries[i].before +
                        4 / zoom,
                  ),
          );
        }
        var shift = 0.0;
        for (var i = 0; i < packed.length; i++) {
          shift += packed[i] - entries[i].wanted;
        }
        if (packed.isNotEmpty) shift /= packed.length;
        for (var i = 0; i < packed.length; i++) {
          result[(entries[i].id, entries[i].start)] =
              u * row + n * (packed[i] - shift);
        }
      }
    }
    return result;
  }
}
