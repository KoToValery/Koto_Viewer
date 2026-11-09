import 'dart:ui';

/// High-precision Catmull-Rom interpolating spline generator for architectural drafting.
/// Converts sequential fit points into continuous cubic Bezier segments (C1/G1 continuity).
class ArchitectSplineGeometry {
  const ArchitectSplineGeometry._();

  /// Creates a smooth cubic Bezier path passing exactly through each point in [points].
  static Path generatePath(List<Offset> points, {bool closed = false}) {
    final path = Path();
    if (points.isEmpty) return path;

    var pts = points;
    if (closed && pts.length > 2 && pts.first == pts.last) {
      pts = pts.sublist(0, pts.length - 1);
    }

    if (pts.length == 1) {
      path.moveTo(pts.first.dx, pts.first.dy);
      return path;
    }
    if (pts.length == 2) {
      path.moveTo(pts.first.dx, pts.first.dy);
      path.lineTo(pts.last.dx, pts.last.dy);
      if (closed) path.close();
      return path;
    }

    final n = pts.length;
    path.moveTo(pts[0].dx, pts[0].dy);

    final segments = closed ? n : n - 1;
    for (var i = 0; i < segments; i++) {
      final p0 = closed ? pts[(i - 1 + n) % n] : (i > 0 ? pts[i - 1] : pts[0]);
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = closed
          ? pts[(i + 2) % n]
          : (i + 2 < n ? pts[i + 2] : p2 + (p2 - p1));

      // Catmull-Rom to Cubic Bezier control points formula:
      // cp1 = p1 + (p2 - p0) / 6
      // cp2 = p2 - (p3 - p1) / 6
      final cp1 = p1 + (p2 - p0) * (1.0 / 6.0);
      final cp2 = p2 - (p3 - p1) * (1.0 / 6.0);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    if (closed) {
      path.close();
    }

    return path;
  }

  /// Evaluates points along the spline path for hit-testing and discretization.
  static List<Offset> samplePoints(List<Offset> points, {bool closed = false, int samplesPerSpan = 16}) {
    if (points.length < 2) return List.from(points);

    var pts = points;
    if (closed && pts.length > 2 && pts.first == pts.last) {
      pts = pts.sublist(0, pts.length - 1);
    }

    final result = <Offset>[];
    final n = pts.length;
    final segments = closed ? n : n - 1;

    for (var i = 0; i < segments; i++) {
      final p0 = closed ? pts[(i - 1 + n) % n] : (i > 0 ? pts[i - 1] : pts[0]);
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = closed
          ? pts[(i + 2) % n]
          : (i + 2 < n ? pts[i + 2] : p2 + (p2 - p1));

      final cp1 = p1 + (p2 - p0) * (1.0 / 6.0);
      final cp2 = p2 - (p3 - p1) * (1.0 / 6.0);

      final steps = samplesPerSpan.clamp(4, 64);
      for (var s = (i == 0 ? 0 : 1); s <= steps; s++) {
        final t = s / steps;
        final t2 = t * t;
        final t3 = t2 * t;
        final mt = 1.0 - t;
        final mt2 = mt * mt;
        final mt3 = mt2 * mt;

        final pt = p1 * mt3 + cp1 * (3.0 * mt2 * t) + cp2 * (3.0 * mt * t2) + p2 * t3;
        result.add(pt);
      }
    }
    return result;
  }

  /// Calculates minimum distance from [testPoint] to the spline curve.
  static double distanceToPoint(List<Offset> points, Offset testPoint, {bool closed = false}) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) return (points.first - testPoint).distance;

    final poly = samplePoints(points, closed: closed, samplesPerSpan: 12);
    var minDist = double.infinity;
    for (var i = 0; i < poly.length - 1; i++) {
      final d = _pointToSegmentDistance(testPoint, poly[i], poly[i + 1]);
      if (d < minDist) minDist = d;
    }
    if (closed && poly.length > 2) {
      final d = _pointToSegmentDistance(testPoint, poly.last, poly.first);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-8) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
    final proj = a + ab * t;
    return (p - proj).distance;
  }
}
