import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_grid_axis.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_snap_helper.dart';
import 'architect_midpoint_tracking.dart';
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
    List<Offset> referenceDirections = const [],
    List<ArchitectMidpointReference> midpointReferences = const [],
  }) {
    final radius = math.min(capturePixels / scale, .35);
    var best = magnetic
        ? ArchitectSnapHelper.snapFree(
            rawPoint: raw,
            project: project,
            tolerance: radius,
            midpointReferences: midpointReferences,
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
            'Midpoint alignment' ||
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
        if (wall.isCurved) {
          final r = wall.arc!.parameter(result.point).clamp(0.0, 1.0),
              n = wall.normalAt(r) * wall.exteriorSign;
          for (final face in [
            (
              WallReferenceLine.center,
              wall.centerPointAt(r) - n * wall.coreAsymmetry / 2,
            ),
            (
              WallReferenceLine.outer,
              wall.centerPointAt(r) + n * wall.thickness / 2,
            ),
            (
              WallReferenceLine.inner,
              wall.centerPointAt(r) - n * wall.thickness / 2,
            ),
          ]) {
            if ((result.point - face.$2).distance < .0001 &&
                (face.$2 - raw).distance < bestDistance) {
              bestDistance = (face.$2 - raw).distance;
              attachment = ArchitectWallAttachment(wall, face.$1);
            }
          }
          continue;
        }
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
      consider(axes[i].projectPoint(raw), 'Axis ${axes[i].name}', 2);
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
    // Strong orthogonal capture (~24px); lighter 15-degree increments.
    for (final step in [math.pi / 2, math.pi / 12]) {
      final target = (angle / step).round() * step;
      final threshold = step == math.pi / 2 ? math.pi / 15 : math.pi / 90;
      final directionRadius = math.min(24.0 / scale, 0.4);
      final u = Offset(math.cos(target), math.sin(target));
      final projected = anchor + u * (delta.dx * u.dx + delta.dy * u.dy);
      if ((angle - target).abs() <= threshold &&
          (projected - raw).distance <= directionRadius) {
        final degrees = (target * 180 / math.pi + 360) % 360;
        final axisCrossing = _axisCrossingOnRay(
          anchor: anchor,
          u: u,
          projected: projected,
          degrees: degrees,
          axes: project.gridAxes,
          tolerance: directionRadius,
        );
        if (axisCrossing != null) return axisCrossing;
        final perpCrossing = _perpendicularWallCrossingOnRay(
          anchor: anchor,
          u: u,
          projected: projected,
          degrees: degrees,
          walls: project.activeStorey.walls,
          tolerance: directionRadius,
          scale: scale,
        );
        if (perpCrossing != null) return perpCrossing;
        final guideLength = math.max(
          delta.distance + 40.0 / scale,
          60.0 / scale,
        );
        final guideEnd = anchor + u * guideLength;
        return ArchitectSnapResult(
          point: projected,
          isSnapped: true,
          snapLabel: '${degrees.round()}°',
          angleDeg: degrees,
          magneticGuides: [(anchor, guideEnd)],
        );
      }
    }
    if (magnetic) {
      // Relative directions and reference directions (e.g. wall being lengthened/edited).
      final directionRadius = math.min(24.0 / scale, 0.4);
      final directionsToTest = <Offset>[
        for (final wall in project.activeStorey.walls) ...[
          wall.unitVector,
          wall.normalVector,
        ],
        ...referenceDirections,
      ];
      for (final uCandidate in directionsToTest) {
        if (uCandidate.distanceSquared < 1e-8) continue;
        final uNorm = uCandidate / uCandidate.distance;
        for (final u in [uNorm, uNorm * -1]) {
          final along = delta.dx * u.dx + delta.dy * u.dy;
          if (along <= 1e-4) continue;
          final projected = anchor + u * along;
          final dist = (projected - raw).distance;
          if (dist <= directionRadius &&
              dist <= delta.distance * math.sin(math.pi / 15)) {
            final degrees =
                (math.atan2(u.dy, u.dx) * 180 / math.pi + 360) % 360;
            final axisCrossing = _axisCrossingOnRay(
              anchor: anchor,
              u: u,
              projected: projected,
              degrees: degrees,
              axes: project.gridAxes,
              tolerance: directionRadius,
            );
            if (axisCrossing != null) return axisCrossing;
            final perpCrossing = _perpendicularWallCrossingOnRay(
              anchor: anchor,
              u: u,
              projected: projected,
              degrees: degrees,
              walls: project.activeStorey.walls,
              tolerance: directionRadius,
              scale: scale,
            );
            if (perpCrossing != null) return perpCrossing;
            final guideLength = math.max(
              along.abs() + 40.0 / scale,
              60.0 / scale,
            );
            final guideEnd = anchor + u * guideLength;
            return ArchitectSnapResult(
              point: projected,
              isSnapped: true,
              snapLabel: '${degrees.round()}°',
              angleDeg: degrees,
              magneticGuides: [(anchor, guideEnd)],
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

  static ArchitectSnapResult? _axisCrossingOnRay({
    required Offset anchor,
    required Offset u,
    required Offset projected,
    required double degrees,
    required List<BimGridAxis> axes,
    required double tolerance,
  }) {
    ArchitectSnapResult? best;
    double bestDist = tolerance;
    for (final axis in axes) {
      final inter = BimLineGeometry.intersection(
        anchor,
        anchor + u,
        axis.start,
        axis.end,
        firstFinite: false,
        secondFinite: false,
      );
      if (inter == null) continue;
      final t = (inter - anchor).dx * u.dx + (inter - anchor).dy * u.dy;
      if (t <= 1e-4) continue;
      final d = (inter - projected).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = ArchitectSnapResult(
          point: inter,
          isSnapped: true,
          snapLabel: 'Axis ${axis.name}',
          angleDeg: degrees,
          magneticGuides: [(anchor, inter), (axis.start, axis.end)],
        );
      }
    }
    return best;
  }

  static ArchitectSnapResult? _perpendicularWallCrossingOnRay({
    required Offset anchor,
    required Offset u,
    required Offset projected,
    required double degrees,
    required List<ArchitectWall> walls,
    required double tolerance,
    double maxDistance = 25.0,
    double scale = 1.0,
  }) {
    ArchitectSnapResult? best;
    double bestDist = tolerance;

    for (final wall in walls) {
      if (wall.isCurved) continue;
      if ((wall.startPoint - anchor).distance < 1e-3 ||
          (wall.endPoint - anchor).distance < 1e-3) {
        continue;
      }
      final v = wall.unitVector;
      final dot = (u.dx * v.dx + u.dy * v.dy).abs();
      final isPerpendicular = dot <= 0.05;
      final isParallel = dot >= 0.95;
      if (!isPerpendicular && !isParallel) continue;

      final lines = <(Offset, Offset)>[
        if (isPerpendicular) ...[
          (wall.startPoint, wall.endPoint),
          if (wall.polygonCorners.length >= 4) ...[
            (wall.polygonCorners[0], wall.polygonCorners[1]),
            (wall.polygonCorners[3], wall.polygonCorners[2]),
          ],
          if (wall.coreCorners.length >= 4) ...[
            (wall.coreCorners[0], wall.coreCorners[1]),
            (wall.coreCorners[3], wall.coreCorners[2]),
          ],
        ],
        if (isParallel) ...[
          if (wall.polygonCorners.length >= 4) ...[
            (wall.polygonCorners[1], wall.polygonCorners[2]),
            (wall.polygonCorners[3], wall.polygonCorners[0]),
          ],
          if (wall.coreCorners.length >= 4) ...[
            (wall.coreCorners[1], wall.coreCorners[2]),
            (wall.coreCorners[3], wall.coreCorners[0]),
          ],
          (
            wall.startPoint - wall.normalVector * 0.5,
            wall.startPoint + wall.normalVector * 0.5,
          ),
          (
            wall.endPoint - wall.normalVector * 0.5,
            wall.endPoint + wall.normalVector * 0.5,
          ),
        ],
      ];

      for (final (w1, w2) in lines) {
        final inter = BimLineGeometry.intersection(
          anchor,
          anchor + u,
          w1,
          w2,
          firstFinite: false,
          secondFinite: false,
        );
        if (inter == null) continue;
        final t = (inter - anchor).dx * u.dx + (inter - anchor).dy * u.dy;
        if (t <= 1e-3) continue;

        // Closest point on the wall segment to inter
        final seg = w2 - w1;
        final segLen = seg.distance;
        if (segLen < 1e-4) continue;
        final segU = seg / segLen;
        final s = ((inter - w1).dx * segU.dx + (inter - w1).dy * segU.dy).clamp(
          0.0,
          segLen,
        );
        final closestOnWall = w1 + segU * s;

        final gap = (closestOnWall - inter).distance;
        if (gap > maxDistance) continue;

        final d = (inter - projected).distance;
        if (d <= bestDist) {
          bestDist = d;
          final overshoot = math.max(0.4, 20.0 / scale);
          final rayGuide = (anchor, inter + u * overshoot);
          final (Offset, Offset) perpGuide;
          if (gap > 1e-4) {
            final guideDir = inter - closestOnWall;
            final norm = guideDir / guideDir.distance;
            perpGuide = (closestOnWall, inter + norm * overshoot);
          } else {
            perpGuide = (w1 - segU * overshoot, w2 + segU * overshoot);
          }
          best = ArchitectSnapResult(
            point: inter,
            isSnapped: true,
            snapLabel: 'Perpendicular',
            angleDeg: degrees,
            magneticGuides: [rayGuide, perpGuide],
          );
        }
      }
    }
    return best;
  }
}
