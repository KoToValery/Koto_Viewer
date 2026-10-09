import 'dart:ui';
import '../analysis/structural_polygon_distance.dart';
import '../models/vertical_capacity_models.dart';

class SpanOverlayLine {
  final SupportSpanCheck check;
  final Offset start, end;
  final bool focused;
  const SpanOverlayLine(this.check, this.start, this.end, this.focused);
}

class SpanOverlayLabel {
  final SpanOverlayLine line;
  final Rect rect;
  const SpanOverlayLabel(this.line, this.rect);
}

class SupportSpanOverlayLayout {
  final List<SpanOverlayLine> lines;
  final List<SpanOverlayLabel> labels;
  const SupportSpanOverlayLayout(this.lines, this.labels);

  /// All visible problem lines remain. Only badges are bounded/collision-aware.
  /// Coordinates are pixels at the current zoom, so density is zoom-independent.
  static SupportSpanOverlayLayout build({
    required List<SupportSpanCheck> checks,
    required Offset Function(Offset) toPixel,
    required Rect viewport,
    required Size Function(SupportSpanCheck) labelSize,
    Offset? focusCad,
    double scale = 1,
    int maxLabels = 6,
    List<Rect> reserved = const [],
  }) {
    final lines = <SpanOverlayLine>[], safe = <SpanOverlayLine>[];
    for (final check in checks) {
      if (!check.isDetermined) continue;
      final clip = _clip(
        toPixel(check.segment.$1),
        toPixel(check.segment.$2),
        viewport,
      );
      if (clip == null) continue;
      final focused =
          focusCad != null &&
          ((check.segment.$1 - focusCad).distance <= .05 * scale ||
              (check.segment.$2 - focusCad).distance <= .05 * scale);
      final line = SpanOverlayLine(check, clip.$1, clip.$2, focused);
      if (check.isProblematic) {
        lines.add(line);
      } else if (focused) {
        safe.add(line);
      }
    }
    double focusDistance(SpanOverlayLine line) => focusCad == null
        ? 0
        : StructuralPolygonDistance.pointToSegment(
            toPixel(focusCad),
            line.start,
            line.end,
          );
    lines.sort((a, b) {
      if (a.focused != b.focused) return a.focused ? -1 : 1;
      final distance = focusDistance(a).compareTo(focusDistance(b));
      if (focusCad != null && distance != 0) return distance;
      final severity = b.check.utilization.compareTo(a.check.utilization);
      return severity != 0 ? severity : b.check.spanM.compareTo(a.check.spanM);
    });
    final labels = <SpanOverlayLabel>[];
    final occupied = [...reserved];
    for (final line in lines) {
      if (labels.length >= maxLabels) break;
      final v = line.end - line.start;
      if (v.distance < 35) continue;
      final normal = Offset(-v.dy, v.dx) / v.distance;
      final size = labelSize(line.check);
      var placed = false;
      for (final t in [.5, .3, .7]) {
        for (final offset in [14.0, -14.0, 30.0, -30.0]) {
          final center = line.start + v * t + normal * offset;
          final rect = Rect.fromCenter(
            center: center,
            width: size.width,
            height: size.height,
          );
          if (!viewport.contains(rect.topLeft) ||
              !viewport.contains(rect.bottomRight) ||
              occupied.any((r) => r.inflate(5).overlaps(rect))) {
            continue;
          }
          labels.add(SpanOverlayLabel(line, rect));
          occupied.add(rect);
          placed = true;
          break;
        }
        if (placed) break;
      }
    }
    // A few short green links give immediate confirmation around the preview.
    safe.sort((a, b) => a.check.spanM.compareTo(b.check.spanM));
    return SupportSpanOverlayLayout(
      List.unmodifiable([...lines, ...safe.take(3)]),
      List.unmodifiable(labels),
    );
  }

  static (Offset, Offset)? _clip(Offset a, Offset b, Rect rect) {
    final d = b - a;
    var low = 0.0, high = 1.0;
    for (final (p, q) in [
      (-d.dx, a.dx - rect.left),
      (d.dx, rect.right - a.dx),
      (-d.dy, a.dy - rect.top),
      (d.dy, rect.bottom - a.dy),
    ]) {
      if (p == 0) {
        if (q < 0) return null;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        if (t > high) return null;
        if (t > low) low = t;
      } else {
        if (t < low) return null;
        if (t < high) high = t;
      }
    }
    return (a + d * low, a + d * high);
  }
}
