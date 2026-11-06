import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import 'architect_clearance_badge_layout.dart';

/// All geometry is in logical pixels. The widget and painter share this result.
class ArchitectDynamicDimensionLayout {
  final Offset measuredStart, measuredEnd, start, end;
  final Rect label, viewport;
  final int? endpoint;
  final bool active;
  const ArchitectDynamicDimensionLayout({
    required this.measuredStart,
    required this.measuredEnd,
    required this.start,
    required this.end,
    required this.label,
    required this.viewport,
    this.endpoint,
    this.active = false,
  });

  (Offset, Offset)? get visibleLine =>
      BimLineGeometry.visibleSegment(start, end, viewport);
  bool get startOutside => !viewport.contains(start);
  bool get endOutside => !viewport.contains(end);
  Offset get labelAnchor => BimLineGeometry.closest(label.center, start, end);
  bool get hasLeader => !label.inflate(4).contains(labelAnchor);

  static ArchitectDynamicDimensionLayout place({
    required Offset start,
    required Offset end,
    required Rect available,
    required Rect viewport,
    required List<Rect> excluded,
    required bool Function(Rect) intersectsWall,
    int? endpoint,
    bool active = false,
  }) {
    final delta = end - start;
    final direction = delta.distance < 1e-8
        ? const Offset(1, 0)
        : delta / delta.distance;
    final normal = Offset(-direction.dy, direction.dx);
    // Choose the clearer side; labels may move, their witnesses never do.
    Offset? bestShift;
    var bestScore = double.infinity;
    for (final amount in [24.0, -24.0, 48.0, -48.0]) {
      final shift = normal * amount;
      final segment = BimLineGeometry.visibleSegment(
        start + shift,
        end + shift,
        available,
      );
      final center = segment == null
          ? (start + end) / 2 + shift
          : (segment.$1 + segment.$2) / 2;
      final rect = Rect.fromCenter(center: center, width: 88, height: 36);
      final score =
          amount.abs() +
          (intersectsWall(rect) ? 1000 : 0) +
          (excluded.any((r) => r.overlaps(rect.inflate(4))) ? 2000 : 0) +
          (available.contains(center) ? 0 : 4000);
      if (score < bestScore) {
        bestScore = score;
        bestShift = shift;
      }
    }
    final a = start + bestShift!, b = end + bestShift;
    final segment = BimLineGeometry.visibleSegment(a, b, available);
    final label = ArchitectClearanceBadgeLayout.place(
      preferred: segment == null ? (a + b) / 2 : (segment.$1 + segment.$2) / 2,
      available: available,
      excluded: [
        ...excluded,
        // Short spans need an external value with a leader. Never mask a tick
        // or the actual measured face merely to keep the value near its centre.
        for (final point in [a, b]) Rect.fromCircle(center: point, radius: 8),
        for (final point in [start, end])
          Rect.fromCircle(center: point, radius: 5),
      ],
      intersectsWall: intersectsWall,
    );
    return ArchitectDynamicDimensionLayout(
      measuredStart: start,
      measuredEnd: end,
      start: a,
      end: b,
      label: label,
      viewport: viewport,
      endpoint: endpoint,
      active: active,
    );
  }
}
