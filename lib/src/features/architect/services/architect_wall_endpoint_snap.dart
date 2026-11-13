import 'architect_underlay_clip.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_snap_geometry.dart';
import '../rendering/architect_snap_helper.dart';

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
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    final anchor = atStart ? wall.endPoint : wall.startPoint;
    final origin = atStart ? wall.startPoint : wall.endPoint;
    final radius = math.min(14 / math.max(scale, 1e-4), .35);
    if (!angleLocked) {
      // Explicit unlock also removes angular/parallel capture, so a small
      // correction cannot be pulled back onto the wall's previous direction.
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: raw,
        project: snapProject,
        tolerance: radius,
        magnetic: magnetic,
        wallCoresOnly: true,
        underlay: underlay,
        frame: frame,
        visibility: visibility,
      );
      if ((snap.point - origin).distance < .001 ||
          (snap.point - anchor).distance < .001) {
        return ArchitectSnapResult(
          point: ArchitectSnapHelper.precision(snapProject).inputPoint(raw),
        );
      }
      return snap;
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
}
