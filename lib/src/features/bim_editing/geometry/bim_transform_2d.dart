import 'dart:math' as math;
import 'dart:ui';

class BimTransform2D {
  static double angle(double original, double delta) {
    if (!original.isFinite || !delta.isFinite) {
      throw ArgumentError('Invalid rotation');
    }
    return (original + delta) % (2 * math.pi);
  }

  static Offset rotate(Offset point, Offset pivot, double radians) {
    if (!radians.isFinite) throw ArgumentError('Invalid rotation');
    if (radians == 0) return point;
    final d = point - pivot, c = math.cos(radians), s = math.sin(radians);
    return pivot + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
  }

  static Offset mirror(Offset point, Offset origin, Offset direction) {
    if (direction.distanceSquared < 1e-16) {
      throw ArgumentError('Invalid mirror axis');
    }
    final d = point - origin;
    final projection =
        direction *
        ((d.dx * direction.dx + d.dy * direction.dy) /
            direction.distanceSquared);
    return origin + projection * 2 - d;
  }
}
