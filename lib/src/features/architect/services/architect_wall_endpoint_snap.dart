import 'architect_underlay_clip.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_midpoint_tracking.dart';
import '../rendering/architect_snap_geometry.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_wall_geometry.dart';

/// Endpoint-only constraint. Whole-wall translation never uses this resolver.
class ArchitectWallEndpointSnap {
  static ArchitectSnapResult resolve({
    required ArchitectWall wall,
    required bool atStart,
    required Offset raw,
    required ArchitectProject snapProject,
    required double scale,
    required bool angleLocked,
    bool magnetic = true,
    List<ArchitectMidpointReference> midpointReferences = const [],
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    final anchor = atStart ? wall.endPoint : wall.startPoint;
    final origin = atStart ? wall.startPoint : wall.endPoint;
    final radius = math.min(14 / math.max(scale, 1e-4), .35);
    if (!angleLocked) {
      return _resolveUnlocked(
        wall: wall,
        anchor: anchor,
        origin: origin,
        raw: raw,
        snapProject: snapProject,
        scale: scale,
        radius: radius,
        magnetic: magnetic,
        midpointReferences: midpointReferences,
        underlay: underlay,
        frame: frame,
        visibility: visibility,
      );
    }

    final u = wall.unitVector;
    double along(Offset p) => (p - anchor).dx * u.dx + (p - anchor).dy * u.dy;
    Offset project(Offset p) => anchor + u * along(p);
    final projected = project(raw);
    var target = projected;
    var bestDistance = radius + 1e-9;
    var bestRank = 3;
    final degrees = (math.atan2(u.dy, u.dx) * 180 / math.pi + 360) % 360;
    var label = '${degrees.toStringAsFixed(1)}°';
    List<(Offset, Offset)> targetGuides = const [];

    void consider(
      Offset p,
      String name,
      int rank, [
      List<(Offset, Offset)> guides = const [],
    ]) {
      if ((p - anchor).distance < .001 || (p - origin).distance < .001) return;
      // A nearby endpoint outside the constraint must never rotate the wall.
      if ((p - project(p)).distance > 1e-7) return;
      final distance = (p - projected).distance;
      if (distance <= radius &&
          (rank < bestRank || (rank == bestRank && distance < bestDistance))) {
        target = project(p);
        label = name;
        bestDistance = distance;
        bestRank = rank;
        targetGuides = guides;
      }
    }

    void crossing(Offset a, Offset b, String name, {bool finite = true}) {
      final p = BimLineGeometry.intersection(
        anchor,
        anchor + u,
        a,
        b,
        firstFinite: false,
        secondFinite: finite,
      );
      if (p != null) consider(p, name, 1, [(a, b)]);
    }

    if (magnetic) {
      final geometry = ArchitectSnapGeometry.of(
        snapProject,
        wallCoresOnly: true,
      );
      for (final point in geometry.query(projected, radius)) {
        consider(point.point, point.label, 0);
      }
      for (final edge in geometry.nearbyEdges(projected, radius)) {
        crossing(edge.a, edge.b, 'Intersection');
      }
      for (final circle in geometry.nearbyCircles(projected, radius)) {
        final foot = project(circle.center);
        final square =
            circle.radius * circle.radius -
            (foot - circle.center).distanceSquared;
        if (square < 0) continue;
        final d = math.sqrt(square);
        consider(foot + u * d, 'Intersection', 1);
        consider(foot - u * d, 'Intersection', 1);
      }
      for (final axis in snapProject.gridAxes) {
        crossing(axis.start, axis.end, 'Axis ${axis.name}', finite: false);
      }
      if (underlay != null) {
        underlay.orBuildSpatialIndex;
        for (final edge in ArchitectUnderlayClip.segments(
          DxfSegmentSnap.nearby(
            document: underlay,
            point: frame.toCad(projected),
            radius: radius * frame.unitsPerMeter,
            layerVisibility: visibility,
          ).map((edge) => (frame.toModel(edge.$1), frame.toModel(edge.$2))),
          ArchitectUnderlayClip.of(snapProject),
        )) {
          final a = edge.$1, b = edge.$2;
          consider(a, 'Endpoint', 0);
          consider(b, 'Endpoint', 0);
          crossing(a, b, 'Intersection');
        }
      }
    }
    final guideU = along(target) < 0 ? -u : u;
    return ArchitectSnapResult(
      point: target,
      isSnapped: true,
      angleDeg: degrees,
      snapLabel: label,
      magneticGuides: [
        (anchor, target + guideU * (40 / math.max(scale, 1e-4))),
        ...targetGuides,
      ],
    );
  }

  /// Resolves an unlocked wall endpoint with cardinal/45° guides and wall
  /// crossings while keeping the wall's own previous direction unlocked.
  static ArchitectSnapResult _resolveUnlocked({
    required ArchitectWall wall,
    required Offset anchor,
    required Offset origin,
    required Offset raw,
    required ArchitectProject snapProject,
    required double scale,
    required double radius,
    required bool magnetic,
    required List<ArchitectMidpointReference> midpointReferences,
    DxfDocument? underlay,
    required BimCoordinateFrame frame,
    required Map<String, bool> visibility,
  }) {
    if (!magnetic) {
      return ArchitectSnapResult(
        point: ArchitectSnapHelper.precision(snapProject).inputPoint(raw),
      );
    }

    final origU = wall.unitVector;
    final overshoot = math.max(0.4, 32.0 / math.max(scale, 1e-4));
    final coreWalls = ArchitectWallGeometry.coreWalls(
      snapProject.activeStorey.walls,
    );
    final excludedPoints = _excludedJointPoints(coreWalls, anchor, origin);

    final objectSnap = ArchitectSnapHelper.snapFree(
      rawPoint: raw,
      project: snapProject,
      tolerance: radius,
      magnetic: true,
      wallCoresOnly: true,
      excludedPoints: excludedPoints,
      midpointReferences: midpointReferences,
      underlay: underlay,
      frame: frame,
      visibility: visibility,
    );
    final isSecondaryObjectSnap =
        objectSnap.snapLabel == 'Edge' ||
        (objectSnap.snapLabel?.startsWith('Axis ') ?? false);
    if (objectSnap.isSnapped && !isSecondaryObjectSnap) {
      return ArchitectSnapResult(
        point: objectSnap.point,
        isSnapped: true,
        snapLabel: objectSnap.snapLabel,
        angleDeg: objectSnap.angleDeg,
        wallAttachment: objectSnap.wallAttachment,
        magneticGuides: [
          (anchor, objectSnap.point),
          ...objectSnap.magneticGuides,
        ],
      );
    }

    final delta = raw - anchor;
    if (delta.distance >= 1e-4) {
      final angle = math.atan2(delta.dy, delta.dx);
      final prevDirThreshold = math.cos(0.04 * math.pi / 180);
      for (final step in [math.pi / 2, math.pi / 4]) {
        final target = (angle / step).round() * step;
        final u = Offset(math.cos(target), math.sin(target));
        // Never pull a small unlocked nudge back onto the wall's own direction.
        if ((u.dx * origU.dx + u.dy * origU.dy).abs() > prevDirThreshold) {
          continue;
        }
        final along = delta.dx * u.dx + delta.dy * u.dy;
        if (along <= 1e-4) continue;
        final projected = anchor + u * along;
        final threshold = step == math.pi / 2 ? math.pi / 15 : math.pi / 30;
        if ((angle - target).abs() > threshold ||
            (projected - raw).distance > radius) {
          continue;
        }
        final degrees = (target * 180 / math.pi + 360) % 360;
        final crossing = _unlockedRayCrossing(
          anchor: anchor,
          origin: origin,
          u: u,
          projected: projected,
          degrees: degrees,
          snapProject: snapProject,
          coreWalls: coreWalls,
          tolerance: radius,
          overshoot: overshoot,
        );
        if (crossing != null) return crossing;
        return ArchitectSnapResult(
          point: projected,
          isSnapped: true,
          snapLabel: '${degrees.round()}°',
          angleDeg: degrees,
          magneticGuides: [(anchor, projected + u * overshoot)],
        );
      }
    }

    if (objectSnap.isSnapped) {
      return ArchitectSnapResult(
        point: objectSnap.point,
        isSnapped: true,
        snapLabel: objectSnap.snapLabel,
        angleDeg: objectSnap.angleDeg,
        wallAttachment: objectSnap.wallAttachment,
        magneticGuides: [
          (anchor, objectSnap.point),
          ..._guidesForEdgeOrAxis(
            point: objectSnap.point,
            snapLabel: objectSnap.snapLabel,
            snapProject: snapProject,
            overshoot: overshoot,
          ),
        ],
      );
    }

    final aligned = _alignUnlocked(
      anchor: anchor,
      origin: origin,
      origU: origU,
      raw: raw,
      coreWalls: coreWalls,
      radius: radius,
      overshoot: overshoot,
    );
    if (aligned != null) return aligned;

    return ArchitectSnapResult(
      point: ArchitectSnapHelper.precision(snapProject).inputPoint(raw),
    );
  }

  static ArchitectSnapResult? _unlockedRayCrossing({
    required Offset anchor,
    required Offset origin,
    required Offset u,
    required Offset projected,
    required double degrees,
    required ArchitectProject snapProject,
    required List<ArchitectWall> coreWalls,
    required double tolerance,
    required double overshoot,
  }) {
    ArchitectSnapResult? best;
    var bestDist = tolerance + 1e-9;

    for (final axis in snapProject.gridAxes) {
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
      if (t <= 1e-4 || (inter - origin).distance < 1e-3) continue;
      final d = (inter - projected).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = ArchitectSnapResult(
          point: inter,
          isSnapped: true,
          snapLabel: 'Axis ${axis.name}',
          angleDeg: degrees,
          magneticGuides: [
            (anchor, inter + u * overshoot),
            (axis.start, axis.end),
          ],
        );
      }
    }

    for (final other in coreWalls) {
      if (other.isCurved || other.isOpenRailing) continue;
      final v = other.unitVector;
      final dot = (u.dx * v.dx + u.dy * v.dy).abs();
      final isPerpOrParallel = dot <= 0.05 || dot >= 0.95;
      final maxGap = isPerpOrParallel ? 25.0 : 2.0;

      final lines = <(Offset, Offset)>[
        (other.startPoint, other.endPoint),
        if (other.coreCorners.length >= 4 && other.railing == null) ...[
          (other.coreCorners[0], other.coreCorners[1]),
          (other.coreCorners[3], other.coreCorners[2]),
          if (dot >= 0.95) ...[
            (other.coreCorners[1], other.coreCorners[2]),
            (other.coreCorners[3], other.coreCorners[0]),
          ],
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
        if (t <= 1e-4 || (inter - origin).distance < 1e-3) continue;
        final seg = w2 - w1;
        final segLen = seg.distance;
        if (segLen < 1e-4) continue;
        final segU = seg / segLen;
        final s = ((inter - w1).dx * segU.dx + (inter - w1).dy * segU.dy).clamp(
          0.0,
          segLen,
        );
        final closest = w1 + segU * s;
        final gap = (closest - inter).distance;
        if (gap > maxGap) continue;
        final d = (inter - projected).distance;
        if (d < bestDist - 1e-6) {
          bestDist = d;
          final (Offset, Offset) otherGuide;
          if (gap > 1e-4) {
            final dir = inter - closest;
            final norm = dir / dir.distance;
            otherGuide = (closest, inter + norm * overshoot);
          } else {
            otherGuide = (w1 - segU * overshoot, w2 + segU * overshoot);
          }
          best = ArchitectSnapResult(
            point: inter,
            isSnapped: true,
            snapLabel: isPerpOrParallel ? 'Perpendicular' : 'Intersection',
            angleDeg: degrees,
            magneticGuides: [(anchor, inter + u * overshoot), otherGuide],
          );
        }
      }
    }
    return best;
  }

  static List<(Offset, Offset)> _guidesForEdgeOrAxis({
    required Offset point,
    required String? snapLabel,
    required ArchitectProject snapProject,
    required double overshoot,
  }) {
    if (snapLabel != null && snapLabel.startsWith('Axis ')) {
      final name = snapLabel.substring(5);
      for (final axis in snapProject.gridAxes) {
        if (axis.name == name) return [(axis.start, axis.end)];
      }
    }
    final geometry = ArchitectSnapGeometry.of(
      snapProject,
      wallCoresOnly: true,
    );
    for (final edge in geometry.nearbyEdges(point, 1e-3)) {
      final closest = BimLineGeometry.closest(point, edge.a, edge.b);
      if ((closest - point).distance <= 1e-4) {
        final seg = edge.b - edge.a;
        if (seg.distance > 1e-4) {
          final u = seg / seg.distance;
          return [(edge.a - u * overshoot, edge.b + u * overshoot)];
        }
      }
    }
    return const [];
  }

  static ArchitectSnapResult? _alignUnlocked({
    required Offset anchor,
    required Offset origin,
    required Offset origU,
    required Offset raw,
    required List<ArchitectWall> coreWalls,
    required double radius,
    required double overshoot,
  }) {
    var bestDist = radius;
    Offset? aligned;
    (Offset, Offset)? guide;

    void tryAlign(Offset base, Offset dir) {
      final len = dir.distance;
      if (len < 1e-6) return;
      final u = dir / len;
      final along = (raw - base).dx * u.dx + (raw - base).dy * u.dy;
      final projection = base + u * along;
      if ((projection - anchor).distance < 1e-3 ||
          (projection - origin).distance < 1e-3) {
        return;
      }
      // Keep the wall's own previous line unlocked.
      final crossPrev =
          (projection - anchor).dx * origU.dy -
          (projection - anchor).dy * origU.dx;
      if (crossPrev.abs() < 1e-4) return;
      final d = (projection - raw).distance;
      if (d < bestDist) {
        bestDist = d;
        aligned = projection;
        guide = along >= 0
            ? (base - u * overshoot, projection + u * overshoot)
            : (projection - u * overshoot, base + u * overshoot);
      }
    }

    for (final other in coreWalls) {
      if (other.isCurved || other.isOpenRailing) continue;
      tryAlign(other.startPoint, other.unitVector);
      for (final p in [other.startPoint, other.endPoint]) {
        tryAlign(p, const Offset(1, 0));
        tryAlign(p, const Offset(0, 1));
      }
      if (other.coreCorners.length >= 4) {
        for (final corner in other.coreCorners) {
          tryAlign(corner, other.unitVector);
          tryAlign(corner, other.normalVector);
        }
      }
    }

    if (aligned == null) return null;
    return ArchitectSnapResult(
      point: aligned!,
      isSnapped: true,
      snapLabel: 'Alignment',
      magneticGuides: [(anchor, aligned!), guide!],
    );
  }

  /// Excludes [anchor], [origin], and the end-cap corners of walls meeting at
  /// [origin] so the joint's thickness never hijacks sliding along a neighbor.
  static List<Offset> _excludedJointPoints(
    List<ArchitectWall> coreWalls,
    Offset anchor,
    Offset origin,
  ) {
    final excluded = <Offset>[anchor, origin];
    for (final other in coreWalls) {
      if (other.isCurved || other.coreCorners.length < 4) continue;
      if ((other.startPoint - origin).distance < 1e-3) {
        excluded.add(other.coreCorners[0]);
        excluded.add(other.coreCorners[3]);
      }
      if ((other.endPoint - origin).distance < 1e-3) {
        excluded.add(other.coreCorners[1]);
        excluded.add(other.coreCorners[2]);
      }
    }
    return excluded;
  }
}
