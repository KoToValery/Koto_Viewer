import 'dart:ui';

class BimLineGeometry {
  /// Clip a finite measurement to the visible drawing without changing its
  /// actual endpoints or measured value. Works at every line orientation.
  static (Offset, Offset)? visibleSegment(Offset a, Offset b, Rect view) {
    if (!view.isFinite || view.isEmpty) return null;
    var low = 0.0, high = 1.0;
    final delta = b - a;
    for (final (start, direction, minimum, maximum) in [
      (a.dx, delta.dx, view.left, view.right),
      (a.dy, delta.dy, view.top, view.bottom),
    ]) {
      if (direction.abs() < 1e-12) {
        if (start < minimum || start > maximum) return null;
        continue;
      }
      final first = (minimum - start) / direction;
      final second = (maximum - start) / direction;
      final near = first < second ? first : second;
      final far = first > second ? first : second;
      if (near > low) low = near;
      if (far < high) high = far;
      if (low > high) return null;
    }
    return (a + delta * low, a + delta * high);
  }

  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double parameter(
    Offset point,
    Offset start,
    Offset end, {
    bool finite = true,
  }) {
    final u = end - start;
    if (u.distanceSquared < 1e-16) return 0;
    final value = dot(point - start, u) / u.distanceSquared;
    return finite ? value.clamp(0.0, 1.0) : value;
  }

  static Offset closest(Offset point, Offset start, Offset end) =>
      start + (end - start) * parameter(point, start, end);
  static Offset? intersection(
    Offset a,
    Offset endA,
    Offset b,
    Offset endB, {
    bool firstFinite = false,
    bool secondFinite = false,
    double parallelTolerance = 1e-10,
  }) {
    final u = endA - a, v = endB - b, den = cross(u, v);
    if (u.distanceSquared < 1e-16 ||
        v.distanceSquared < 1e-16 ||
        den.abs() <= parallelTolerance * u.distance * v.distance) {
      return null;
    }
    final t = cross(b - a, v) / den, s = cross(b - a, u) / den;
    if ((firstFinite && (t < -1e-8 || t > 1 + 1e-8)) ||
        (secondFinite && (s < -1e-8 || s > 1 + 1e-8))) {
      return null;
    }
    return a + u * t;
  }

  static bool hostedFits({
    required double length,
    required double width,
    required double ratio,
    double epsilon = 1e-8,
  }) =>
      length.isFinite &&
      width.isFinite &&
      ratio.isFinite &&
      length > 0 &&
      width > 0 &&
      ratio * length - width / 2 >= -epsilon &&
      ratio * length + width / 2 <= length + epsilon;
}
