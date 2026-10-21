import 'dart:ui';
import 'dart:math' as math;

/// Screen-space placement: keep values readable even when their walls are far
/// outside the viewport, and reserve space for contextual controls.
class ArchitectClearanceBadgeLayout {
  static const openingReferenceScale = 100.0;
  static const openingBaseSize = Size(88, 36);

  /// Opening values follow model space, including when the view zooms out.
  static Size openingSize(double zoomScale, Rect available) {
    final scale = math.min(
      zoomScale / openingReferenceScale,
      math.min(
        available.width / openingBaseSize.width,
        available.height / openingBaseSize.height,
      ),
    );
    return openingBaseSize * scale;
  }

  static Rect place({
    required Offset preferred,
    required Rect available,
    required List<Rect> excluded,
    required bool Function(Rect) intersectsWall,
    Size size = const Size(88, 36),
  }) {
    final half = Offset(size.width / 2, size.height / 2);
    final centers = Rect.fromLTRB(
      available.left + half.dx,
      available.top + half.dy,
      available.right - half.dx,
      available.bottom - half.dy,
    );
    Offset clamp(Offset p) => Offset(
      p.dx.clamp(centers.left, centers.right),
      p.dy.clamp(centers.top, centers.bottom),
    );
    final origin = clamp(preferred);
    final candidates = <Offset>[origin];
    for (var step = 1; step <= 12; step++) {
      for (final direction in [
        const Offset(1, 0),
        const Offset(-1, 0),
        const Offset(0, 1),
        const Offset(0, -1),
      ]) {
        candidates.add(clamp(origin + direction * (step * 12.0)));
      }
    }
    for (var y = centers.top; y <= centers.bottom; y += 18) {
      for (var x = centers.left; x <= centers.right; x += 24) {
        candidates.add(Offset(x, y));
      }
    }
    candidates.sort(
      (a, b) =>
          (a - origin).distanceSquared.compareTo((b - origin).distanceSquared),
    );
    Rect? fallback;
    for (final candidate in candidates) {
      final rect = Rect.fromCenter(
        center: candidate,
        width: size.width,
        height: size.height,
      );
      if (excluded.any((r) => r.overlaps(rect.inflate(4)))) continue;
      fallback ??= rect;
      if (!intersectsWall(rect)) return rect;
    }
    // In dense plans, a backed label may cover geometry but never leave view.
    return fallback ??
        Rect.fromCenter(center: origin, width: size.width, height: size.height);
  }
}
