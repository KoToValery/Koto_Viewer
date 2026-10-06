import 'dart:math' as math;
import 'dart:ui';

/// Distance between closed filled polygons, including crossing and containment.
/// This is a geometric screening measure, not a punching-shear verification.
class StructuralPolygonDistance {
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double pointToSegment(Offset p, Offset a, Offset b) {
    final d = b - a;
    if (d.distanceSquared == 0) return (p - a).distance;
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared)
        .clamp(0.0, 1.0);
    return (p - a - d * t).distance;
  }

  static bool inside(Offset p, List<Offset> ring) {
    var result = false;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < a.dx + (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy)) {
        result = !result;
      }
    }
    return result;
  }

  static double between(List<Offset> a, List<Offset> b) {
    if (a.length < 3 || b.length < 3) return double.infinity;
    if (inside(a.first, b) || inside(b.first, a)) return 0;
    var distance = double.infinity;
    for (var i = 0; i < a.length; i++) {
      final p = a[i], q = a[(i + 1) % a.length], u = q - p;
      for (var j = 0; j < b.length; j++) {
        final r = b[j], s = b[(j + 1) % b.length], v = s - r;
        final denominator = _cross(u, v);
        if (denominator != 0) {
          final t = _cross(r - p, v) / denominator,
              w = _cross(r - p, u) / denominator;
          if (t >= 0 && t <= 1 && w >= 0 && w <= 1) return 0;
        }
        distance = math.min(
          distance,
          math.min(
            math.min(pointToSegment(p, r, s), pointToSegment(q, r, s)),
            math.min(pointToSegment(r, p, q), pointToSegment(s, p, q)),
          ),
        );
      }
    }
    return distance;
  }

  static double toCircle(List<Offset> ring, Offset center, double radius) {
    if (ring.length < 3 || radius <= 0) return double.infinity;
    if (inside(center, ring)) return 0;
    var distance = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      distance = math.min(
        distance,
        pointToSegment(center, ring[i], ring[(i + 1) % ring.length]),
      );
    }
    return math.max(0, distance - radius);
  }
}
