import 'dart:math' as math;
import 'dart:ui';
import '../models/wall_axis_models.dart';

/// Ignore a short, unsupported parallel remnant sharing a long facade face.
/// Full returns at both ends retain real steps/pilasters. Source CAD is untouched.
class SlabWallSupportFilter {
  static List<WallPairCandidate> clean(
    List<WallPairCandidate> pairs,
    double scale,
  ) {
    if (pairs.length > 1600 || !scale.isFinite || scale <= 0) return pairs;
    double distance(Offset p, Offset a, Offset b) {
      final d = b - a;
      if (d.distanceSquared == 0) return (p - a).distance;
      final t = ((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared;
      return (p - a - d * t.clamp(0.0, 1.0)).distance;
    }

    bool same(WallSegment a, WallSegment b) =>
        ((a.start - b.start).distance <= 5 * scale &&
            (a.end - b.end).distance <= 5 * scale) ||
        ((a.start - b.end).distance <= 5 * scale &&
            (a.end - b.start).distance <= 5 * scale);
    bool remnant(WallPairCandidate w) {
      final len = (w.centerlineEnd - w.centerlineStart).distance;
      final thickness = w.perpendicularDistance;
      // Short structural jambs are essential evidence for bridging real doors.
      if (thickness > 155 * scale) return false;
      if (len <= 0 || len > math.max(800 * scale, thickness * 3)) return false;
      final lengths = [w.segmentA.length, w.segmentB.length]..sort();
      if (lengths.last < len * 3 || lengths.first > len + thickness * .4) {
        return false;
      }
      final u = (w.centerlineEnd - w.centerlineStart) / len;
      final shadow = pairs.any((other) {
        if (identical(w, other)) {
          return false;
        }
        final d = other.centerlineEnd - other.centerlineStart;
        if (d.distance < len * 3 ||
            (u.dx * d.dy - u.dy * d.dx).abs() > d.distance * .01) {
          return false;
        }
        if (![
          w.segmentA,
          w.segmentB,
        ].any((a) => [other.segmentA, other.segmentB].any((b) => same(a, b)))) {
          return false;
        }
        return distance(
                  w.centerlineStart,
                  other.centerlineStart,
                  other.centerlineEnd,
                ) <=
                thickness * 1.1 + other.perpendicularDistance * .5 &&
            distance(
                  w.centerlineEnd,
                  other.centerlineStart,
                  other.centerlineEnd,
                ) <=
                thickness * 1.1 + other.perpendicularDistance * .5;
      });
      // A thin isolated cap paired to a much longer face has no wall returns.
      // Do not use it to project a wall-thickness sized spur beyond that face.
      if (!shadow && !(thickness <= 155 * scale && len <= thickness * 2.5)) {
        return false;
      }
      bool returned(Offset end) => pairs.any((other) {
        if (identical(other, w)) {
          return false;
        }
        final d = other.centerlineEnd - other.centerlineStart;
        return d.distance > 0 &&
            (u.dx * d.dy - u.dy * d.dx).abs() > d.distance * .5 &&
            distance(end, other.centerlineStart, other.centerlineEnd) <=
                thickness * .65 + 5 * scale;
      });
      return !(returned(w.centerlineStart) && returned(w.centerlineEnd));
    }

    return pairs.where((p) => !remnant(p)).toList();
  }
}
