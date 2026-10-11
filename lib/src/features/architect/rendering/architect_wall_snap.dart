import 'dart:math' as math;
import 'dart:ui';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_project.dart';
import 'architect_snap_helper.dart';
import 'architect_wall_network.dart';

class ArchitectWallSnap {
  static ArchitectSnapResult resolve({
    required Offset raw,
    Offset? anchor,
    required ArchitectProject project,
    required double scale,
    double capturePixels = 14,
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    final radius = math.min(capturePixels / scale, .35);
    var best = ArchitectSnapHelper.snapFree(
      rawPoint: raw,
      project: project,
      tolerance: radius,
    );
    if (anchor != null && (best.point - anchor).distance < .001) {
      best = ArchitectSnapResult(point: raw);
    }
    var distance = best.isSnapped ? (best.point - raw).distance : radius + 1e-9;
    var priority = best.isSnapped
        ? switch (best.snapLabel) {
            'Endpoint' || 'Vertex' || 'Axis endpoint' => 0,
            'Axis intersection' ||
            'Intersection' ||
            'Center' ||
            'Midpoint' => 1,
            _ => 3,
          }
        : 3;
    void consider(Offset point, String label, int rank) {
      if (anchor != null && (point - anchor).distance < .001) return;
      final d = (point - raw).distance;
      if (d <= radius &&
          (rank < priority || (rank == priority && d < distance - 1e-9))) {
        best = ArchitectSnapResult(
          point: point,
          isSnapped: true,
          snapLabel: label,
        );
        distance = d;
        priority = rank;
      }
    }

    // The axis crossing must beat a nearer projection onto either axis.
    final axes = project.gridAxes;
    for (var i = 0; i < axes.length; i++) {
      for (final b in axes.skip(i + 1)) {
        final point = ArchitectWallNetwork.intersection(
          axes[i].start,
          axes[i].end,
          b.start,
          b.end,
        );
        if (point != null) consider(point, 'Axis intersection', 0);
      }
    }

    final segments = <(Offset, Offset)>[];
    for (final wall in project.activeStorey.walls) {
      segments.add((wall.startPoint, wall.endPoint));
      final corners = wall.polygonCorners;
      segments.addAll([(corners[0], corners[1]), (corners[3], corners[2])]);
    }
    if (underlay != null) {
      underlay.orBuildSpatialIndex;
      segments.addAll(
        DxfSegmentSnap.nearby(
          document: underlay,
          point: frame.toCad(raw),
          radius: radius * frame.unitsPerMeter,
          layerVisibility: visibility,
        ).map((s) => (frame.toModel(s.$1), frame.toModel(s.$2))),
      );
    }
    final nearby = <(Offset, Offset)>[];
    for (final s in segments) {
      final delta = s.$2 - s.$1;
      if (delta.distanceSquared < 1e-12) continue;
      final t =
          ((raw - s.$1).dx * delta.dx + (raw - s.$1).dy * delta.dy) /
          delta.distanceSquared;
      final projection = s.$1 + delta * t.clamp(0.0, 1.0);
      if ((projection - raw).distance > radius) continue;
      nearby.add(s);
      consider(s.$1, 'Endpoint', 0);
      consider(s.$2, 'Endpoint', 0);
      consider(projection, 'Edge', 2);
    }
    for (var i = 0; i < nearby.length; i++) {
      for (final s in nearby.skip(i + 1)) {
        final point = DxfSegmentSnap.intersection(nearby[i], s);
        if (point != null) consider(point, 'Intersection', 1);
      }
    }
    if (best.isSnapped &&
        (priority <= 1 || anchor == null) &&
        (anchor == null || (best.point - anchor).distance >= .001)) {
      return best;
    }
    if (anchor == null) {
      return ArchitectSnapResult(
        point: ArchitectSnapHelper.precision(project).inputPoint(raw),
      );
    }
    final delta = raw - anchor;
    if (delta.distance < .001) return ArchitectSnapResult(point: anchor);
    final angle = math.atan2(delta.dy, delta.dx);
    // Strong orthogonal capture; lighter 15-degree increments.
    for (final step in [math.pi / 2, math.pi / 12]) {
      final target = (angle / step).round() * step;
      final threshold = step == math.pi / 2 ? math.pi / 15 : math.pi / 90;
      final directionRadius = step == math.pi / 2
          ? math.min(28 / scale, .5)
          : radius;
      final u = Offset(math.cos(target), math.sin(target));
      final projected = anchor + u * (delta.dx * u.dx + delta.dy * u.dy);
      if ((angle - target).abs() <= threshold &&
          (projected - raw).distance <= directionRadius) {
        final degrees = (target * 180 / math.pi + 360) % 360;
        return ArchitectSnapResult(
          point: projected,
          isSnapped: true,
          snapLabel: '${degrees.round()}°',
          angleDeg: degrees,
        );
      }
    }
    if (best.isSnapped) return best;
    return ArchitectSnapResult(
      point: ArchitectSnapHelper.precision(project).inputPoint(raw),
    );
  }
}
