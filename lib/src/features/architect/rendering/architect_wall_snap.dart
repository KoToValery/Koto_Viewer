import 'dart:math' as math;
import 'dart:ui';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_snap_helper.dart';
import 'architect_wall_network.dart';
import 'architect_wall_geometry.dart';

class ArchitectWallSnap {
  static ArchitectSnapResult resolve({
    required Offset raw,
    Offset? anchor,
    required ArchitectProject project,
    required double scale,
    double capturePixels = 14,
    bool magnetic = true,
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    final radius = math.min(capturePixels / scale, .35);
    var best = magnetic
        ? ArchitectSnapHelper.snapFree(
            rawPoint: raw,
            project: project,
            tolerance: radius,
          )
        : ArchitectSnapResult(point: raw);
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

    ArchitectSnapResult describe(ArchitectSnapResult result) {
      if (!result.isSnapped) return result;
      ArchitectWallAttachment? attachment;
      var bestDistance = double.infinity;
      for (final wall in project.activeStorey.walls) {
        final inner =
            wall.centerStart - wall.exteriorNormal * wall.thickness / 2;
        final outer =
            wall.centerStart + wall.exteriorNormal * wall.thickness / 2;
        final coreOuter =
            wall.coreCenterStart + wall.exteriorNormal * wall.coreThickness / 2;
        for (final face in [
          (WallReferenceLine.center, wall.coreCenterStart),
          (WallReferenceLine.inner, inner),
          (WallReferenceLine.outer, outer),
          (WallReferenceLine.outer, coreOuter),
        ]) {
          final d = result.point - face.$2;
          final along = d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
          final across =
              (d.dx * wall.normalVector.dx + d.dy * wall.normalVector.dy).abs();
          if (across > 1e-7 ||
              along < -4 * wall.thickness ||
              along > wall.length + 4 * wall.thickness) {
            continue;
          }
          final projection =
              face.$2 + wall.unitVector * along.clamp(0.0, wall.length);
          final distance = (projection - raw).distance;
          if (distance < bestDistance) {
            bestDistance = distance;
            attachment = ArchitectWallAttachment(wall, face.$1);
          }
        }
      }
      return ArchitectSnapResult(
        point: result.point,
        isSnapped: result.isSnapped,
        snapLabel: result.snapLabel,
        angleDeg: result.angleDeg,
        magneticGuides: result.magneticGuides,
        wallAttachment: attachment,
      );
    }

    // The axis crossing must beat a nearer projection onto either axis.
    final axes = magnetic
        ? project.gridAxes
        : project.gridAxes.take(0).toList();
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
    if (magnetic) {
      final geometry = ArchitectWallGeometry.of(project.activeStorey.walls);
      segments.addAll(geometry.edges);
      for (final point in geometry.corners) {
        consider(point, 'Vertex', 0);
      }
    }
    if (magnetic && underlay != null) {
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
      return describe(best);
    }
    if (magnetic && anchor == null) {
      final aligned = ArchitectWallAlignment.point(
        raw,
        project.activeStorey.walls,
        scale,
      );
      if (aligned.$2.isNotEmpty &&
          (anchor == null || (aligned.$1 - anchor).distance >= .001)) {
        return ArchitectSnapResult(
          point: aligned.$1,
          isSnapped: true,
          snapLabel: 'Alignment',
          magneticGuides: aligned.$2,
        );
      }
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
    if (magnetic) {
      // Relative directions also work when the neighboring wall is rotated.
      for (final wall in project.activeStorey.walls) {
        for (final u in [wall.unitVector, wall.normalVector]) {
          final along = delta.dx * u.dx + delta.dy * u.dy;
          final projected = anchor + u * along;
          if ((projected - raw).distance <= 8 / scale &&
              (projected - raw).distance <=
                  delta.distance * math.sin(math.pi / 90)) {
            final direction = along < 0 ? u * -1 : u;
            final degrees =
                (math.atan2(direction.dy, direction.dx) * 180 / math.pi + 360) %
                360;
            return ArchitectSnapResult(
              point: projected,
              isSnapped: true,
              snapLabel: '${degrees.round()}°',
              angleDeg: degrees,
              magneticGuides: [(anchor, projected)],
            );
          }
        }
      }
      final aligned = ArchitectWallAlignment.point(
        raw,
        project.activeStorey.walls,
        scale,
      );
      if (aligned.$2.isNotEmpty && (aligned.$1 - anchor).distance >= .001) {
        return ArchitectSnapResult(
          point: aligned.$1,
          isSnapped: true,
          snapLabel: 'Alignment',
          magneticGuides: aligned.$2,
        );
      }
    }
    if (best.isSnapped) return describe(best);
    return ArchitectSnapResult(
      point: ArchitectSnapHelper.precision(project).inputPoint(raw),
    );
  }
}
