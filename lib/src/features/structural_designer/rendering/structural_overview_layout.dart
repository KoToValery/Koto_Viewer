import 'dart:math' as math;
import 'dart:ui';

class SupportOverviewEntry {
  final String id, label;
  final Offset anchor;
  final Rect symbolBounds;
  final Size labelSize;
  final Color color;
  final int priority;
  const SupportOverviewEntry({
    required this.id,
    required this.label,
    required this.anchor,
    required this.symbolBounds,
    required this.labelSize,
    required this.color,
    this.priority = 0,
  });
}

class SupportOverviewLabel {
  final SupportOverviewEntry entry;
  final Rect rect;
  const SupportOverviewLabel(this.entry, this.rect);
}

class StructuralOverviewLayout {
  /// A screen symbol, independent of model geometry, snapping and hit testing.
  static List<Offset> columnSymbol(
    List<Offset> polygon, {
    double minimumSize = 12,
  }) {
    if (polygon.isEmpty) return const [];
    final bounds = boundsOf(polygon);
    if (bounds.longestSide <= 0 || bounds.longestSide >= minimumSize) {
      return polygon;
    }
    final factor = minimumSize / bounds.longestSide;
    return [
      for (final p in polygon) bounds.center + (p - bounds.center) * factor,
    ];
  }

  static Rect boundsOf(List<Offset> polygon) => Rect.fromLTRB(
    polygon.map((p) => p.dx).reduce(math.min),
    polygon.map((p) => p.dy).reduce(math.min),
    polygon.map((p) => p.dx).reduce(math.max),
    polygon.map((p) => p.dy).reduce(math.max),
  );

  /// Every symbol remains visible. Names may be omitted only when there is no
  /// non-overlapping space; selection/zoom brings the requested name forward.
  static List<SupportOverviewLabel> arrange(
    List<SupportOverviewEntry> entries,
    Rect viewport, {
    List<Rect> reserved = const [],
  }) {
    final ordered = [...entries]
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.id.compareTo(b.id);
      });
    final occupied = [...reserved];
    final labels = <SupportOverviewLabel>[];
    for (final entry in ordered) {
      if (!viewport.overlaps(entry.symbolBounds)) continue;
      final w = entry.labelSize.width, h = entry.labelSize.height;
      final r = entry.symbolBounds;
      final candidates = <Offset>[
        Offset(r.right + 5 + w / 2, r.center.dy),
        Offset(r.center.dx, r.top - 5 - h / 2),
        Offset(r.left - 5 - w / 2, r.center.dy),
        Offset(r.center.dx, r.bottom + 5 + h / 2),
        for (final gap in [18.0, 34.0]) ...[
          entry.anchor + Offset(w / 2 + gap, -h - gap),
          entry.anchor + Offset(-w / 2 - gap, -h - gap),
          entry.anchor + Offset(w / 2 + gap, h + gap),
          entry.anchor + Offset(-w / 2 - gap, h + gap),
        ],
      ];
      for (final center in candidates) {
        final box = Rect.fromCenter(center: center, width: w, height: h);
        if (!viewport.contains(box.topLeft) ||
            !viewport.contains(box.bottomRight) ||
            occupied.any((o) => o.inflate(3).overlaps(box)) ||
            entries.any(
              (other) => other.symbolBounds.inflate(2).overlaps(box),
            )) {
          continue;
        }
        labels.add(SupportOverviewLabel(entry, box));
        occupied.add(box);
        break;
      }
    }
    return List.unmodifiable(labels);
  }
}
