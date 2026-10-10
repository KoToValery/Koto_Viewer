import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';

class SlabVertexSnap {
  static double tolerance(
    double pixelsPerCad,
    double unitsPerMeter, {
    required bool isMouse,
    bool merge = false,
  }) => math.min(
    (merge ? (isMouse ? 6.0 : 8.0) : (isMouse ? 8.0 : 12.0)) /
        pixelsPerCad.clamp(0.000001, double.infinity),
    (merge ? .05 : .10) * unitsPerMeter,
  );

  // Measure from the raw pointer; a prior snap cannot trigger deletion.
  static int? mergeCandidate(
    Offset raw,
    List<Offset> polygon,
    int movingIndex,
    double tolerance,
  ) {
    int? result;
    var best = tolerance;
    for (var i = 0; i < polygon.length; i++) {
      if (i == movingIndex) continue;
      final distance = (raw - polygon[i]).distance;
      if (distance <= best) {
        best = distance;
        result = i;
      }
    }
    return result;
  }

  // Exact perpendicular feet on slab edges and tracking from the preceding point.
  static ({DxfSnapResult? snap, List<(Offset, Offset)> guides}) align({
    required Offset raw,
    required Offset previous,
    required Iterable<(Offset, Offset)> edges,
    required double tolerance,
    Offset? incomingDirection,
  }) {
    DxfSnapResult? result;
    var best = tolerance;
    List<(Offset, Offset)> guides = [];
    void offer(Offset point, List<(Offset, Offset)> lines) {
      final distance = (raw - point).distance;
      if (distance <= best) {
        best = distance;
        result = DxfSnapResult(
          point: point,
          type: DxfSnapType.perpendicular,
          distance: distance,
        );
        guides = lines;
      }
    }

    final directions = <Offset>[const Offset(1, 0), const Offset(0, 1)];
    if (incomingDirection != null && incomingDirection.distance > 1e-9) {
      final u = incomingDirection / incomingDirection.distance;
      directions.addAll([u, Offset(-u.dy, u.dx)]);
    }
    for (final u in directions) {
      final d = raw - previous;
      final point = previous + u * (d.dx * u.dx + d.dy * u.dy);
      if ((point - previous).distance > tolerance) {
        offer(point, [(previous, point)]);
      }
    }
    for (final (a, b) in edges) {
      final d = b - a;
      if (d.distanceSquared < 1e-12) continue;
      final v = previous - a;
      final t = (v.dx * d.dx + v.dy * d.dy) / d.distanceSquared;
      if (t < 0 || t > 1) continue;
      final foot = a + d * t;
      if ((foot - previous).distance <= tolerance) continue;
      offer(foot, [(a, b), (previous, foot)]);
    }
    return (snap: result, guides: guides);
  }
}
