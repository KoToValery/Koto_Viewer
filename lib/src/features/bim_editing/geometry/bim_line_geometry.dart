import 'dart:ui';

class BimLineGeometry {
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
