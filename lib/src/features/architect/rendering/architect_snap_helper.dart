import '../../bim_editing/geometry/bim_line_geometry.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/snapping/bim_snap_resolver.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import 'architect_snap_geometry.dart';

class ArchitectSnapResult {
  final Offset point;
  final bool isSnapped;
  final String? snapLabel;
  final double? angleDeg;
  final ArchitectWallAttachment? wallAttachment;
  final List<(Offset, Offset)> magneticGuides;
  const ArchitectSnapResult({
    required this.point,
    this.isSnapped = false,
    this.snapLabel,
    this.angleDeg,
    this.wallAttachment,
    this.magneticGuides = const [],
  });
}

/// Common bounded object snaps and magnetic guides for all drawing tools.
class ArchitectSnapHelper {
  static BimPrecisionPolicy precision(ArchitectProject project) =>
      project.units.isImperial
      ? BimPrecisionPolicy.imperial
      : BimPrecisionPolicy.metric;

  static ArchitectSnapResult snapWithAnchor({
    required Offset anchor,
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = .20,
    bool magnetic = true,
    bool alignment = false,
    bool excludeWallAxes = false,
    Set<String> excludedIds = const {},
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) => _resolve(
    raw: rawPoint,
    anchor: anchor,
    project: project,
    radius: tolerance.clamp(0.0, .60),
    magnetic: magnetic,
    alignment: alignment,
    excludeWallAxes: excludeWallAxes,
    excludedIds: excludedIds,
    underlay: underlay,
    frame: frame,
    visibility: visibility,
  );

  static ArchitectSnapResult snapFree({
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = .20,
    bool magnetic = true,
    bool alignment = false,
    bool excludeWallAxes = false,
    Set<String> excludedIds = const {},
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) => _resolve(
    raw: rawPoint,
    project: project,
    radius: tolerance.clamp(0.0, .60),
    magnetic: magnetic,
    alignment: alignment,
    excludeWallAxes: excludeWallAxes,
    excludedIds: excludedIds,
    underlay: underlay,
    frame: frame,
    visibility: visibility,
  );

  static BimSnapKind _kind(String label) => switch (label) {
    'Endpoint' || 'Vertex' || 'Axis endpoint' => BimSnapKind.endpoint,
    'Intersection' || 'Axis intersection' => BimSnapKind.intersection,
    'Center' => BimSnapKind.center,
    'Midpoint' => BimSnapKind.midpoint,
    'Perpendicular' => BimSnapKind.perpendicular,
    'Alignment' => BimSnapKind.alignment,
    _ => BimSnapKind.edge,
  };
  static int _rank(String label) => _kind(label).priority;
  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// Move the entire selection using its real features, excluding self-snaps.
  static ArchitectSnapResult snapTranslation({
    required ArchitectProject project,
    required Set<String> elementIds,
    required Offset delta,
    double tolerance = .20,
    bool magnetic = true,
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (!magnetic) return ArchitectSnapResult(point: delta);
    final points = ArchitectSnapGeometry.of(project).alignmentPoints
        .where((p) => elementIds.contains(p.owner))
        .map((p) => p.point)
        .toSet();
    ArchitectSnapResult? best;
    var bestCorrection = double.infinity;
    var bestRank = 99;
    for (final point in points) {
      final raw = point + delta;
      final snap = snapFree(
        rawPoint: raw,
        project: project,
        tolerance: tolerance,
        alignment: true,
        excludedIds: elementIds,
        underlay: underlay,
        frame: frame,
        visibility: visibility,
      );
      if (!snap.isSnapped) continue;
      final correction = snap.point - raw;
      final rank = snap.snapLabel == 'Alignment' ? 5 : _rank(snap.snapLabel!);
      if (rank < bestRank ||
          (rank == bestRank && correction.distance < bestCorrection)) {
        bestRank = rank;
        bestCorrection = correction.distance;
        best = ArchitectSnapResult(
          point: delta + correction,
          isSnapped: true,
          snapLabel: snap.snapLabel,
          magneticGuides: [...snap.magneticGuides, (raw, snap.point)],
        );
      }
    }
    return best ?? ArchitectSnapResult(point: delta);
  }

  static ArchitectSnapResult _resolve({
    required Offset raw,
    Offset? anchor,
    required ArchitectProject project,
    required double radius,
    required bool magnetic,
    required bool alignment,
    bool excludeWallAxes = false,
    required Set<String> excludedIds,
    DxfDocument? underlay,
    required BimCoordinateFrame frame,
    required Map<String, bool> visibility,
  }) {
    if (!magnetic || radius <= 0) {
      return ArchitectSnapResult(point: precision(project).inputPoint(raw));
    }
    final geometry = ArchitectSnapGeometry.of(project);
    final excludeJoints = project.activeStorey.walls.any(
      (w) => excludedIds.contains(w.id),
    );
    final excludedOwners = {
      ...excludedIds,
      for (final wall in project.activeStorey.walls.where(
        (w) => excludedIds.contains(w.id),
      )) ...[
        ...wall.doors.map((door) => door.id),
        ...wall.windows.map((window) => window.id),
      ],
    };
    bool excluded(String owner) =>
        excludedOwners.contains(owner) ||
        (excludeWallAxes && owner.startsWith('@wall-axis')) ||
        (owner.startsWith('@wall-axis:') &&
            excludedOwners.contains(owner.substring(11))) ||
        (owner == '@wall-joints' && excludeJoints) ||
        (owner == '@axes' &&
            project.gridAxes.any((a) => excludedIds.contains(a.id)));
    final resolver = BimSnapResolver<String>(
      raw: raw,
      radius: radius,
      anchor: anchor,
    );
    void consider(Offset point, String label) => resolver.consider(
      BimSnapCandidate(point: point, kind: _kind(label), source: label),
    );

    for (final candidate in geometry.query(raw, radius)) {
      if (!excluded(candidate.owner)) {
        consider(candidate.point, candidate.label);
      }
    }
    final nearby = <(Offset, Offset)>[];
    for (final edge in geometry.nearbyEdges(raw, radius)) {
      if (excluded(edge.owner)) continue;
      final projection = BimLineGeometry.closest(raw, edge.a, edge.b);
      if ((projection - raw).distance <= radius) nearby.add((edge.a, edge.b));
    }
    if (underlay != null) {
      underlay.orBuildSpatialIndex;
      nearby.addAll(
        DxfSegmentSnap.nearby(
          document: underlay,
          point: frame.toCad(raw),
          radius: radius * frame.unitsPerMeter,
          layerVisibility: visibility,
        ).map((e) => (frame.toModel(e.$1), frame.toModel(e.$2))),
      );
    }
    for (final edge in nearby) {
      consider(edge.$1, 'Endpoint');
      consider(edge.$2, 'Endpoint');
      if ((edge.$2 - edge.$1).distance > 0.45) {
        consider((edge.$1 + edge.$2) / 2, 'Midpoint');
      }
      consider(BimLineGeometry.closest(raw, edge.$1, edge.$2), 'Edge');
      if (anchor != null) {
        final u = edge.$2 - edge.$1;
        final t = _dot(anchor - edge.$1, u) / u.distanceSquared;
        if (t >= 0 && t <= 1) consider(edge.$1 + u * t, 'Perpendicular');
      }
    }
    for (var i = 0; i < nearby.length; i++) {
      for (final other in nearby.skip(i + 1)) {
        final p = DxfSegmentSnap.intersection(nearby[i], other);
        if (p != null) consider(p, 'Intersection');
      }
    }
    final circles = geometry
        .nearbyCircles(raw, radius)
        .where(
          (c) =>
              !excluded(c.owner) &&
              ((raw - c.center).distance - c.radius).abs() <= radius,
        )
        .toList();
    for (final circle in circles) {
      consider(
        DxfSnapHelper.closestPointOnCircle(raw, circle.center, circle.radius),
        'Edge',
      );
      for (final edge in nearby) {
        for (final p in _circleCrossings(circle, edge)) {
          consider(p, 'Intersection');
        }
      }
    }
    for (var i = 0; i < circles.length; i++) {
      for (final b in circles.skip(i + 1)) {
        final a = circles[i], d = b.center - a.center, length = d.distance;
        if (length < 1e-9 ||
            length > a.radius + b.radius ||
            length < (a.radius - b.radius).abs()) {
          continue;
        }
        final along =
            (a.radius * a.radius - b.radius * b.radius + length * length) /
            (2 * length);
        final height = math.sqrt(
          math.max(0, a.radius * a.radius - along * along),
        );
        final u = d / length, n = Offset(-u.dy, u.dx);
        for (final p in [
          a.center + u * along + n * height,
          a.center + u * along - n * height,
        ]) {
          consider(p, 'Intersection');
        }
      }
    }
    for (final axis in project.gridAxes) {
      if (excluded(axis.id)) continue;
      if (anchor == null) {
        consider(axis.projectPoint(raw), 'Axis ${axis.name}');
      }
      for (final edge in nearby) {
        // Axes are reference lines; object edges remain finite.
        final p = _axisCrossing(axis.start, axis.end, edge);
        if (p != null) consider(p, 'Intersection');
      }
    }
    final best = resolver.best;
    if (best != null) {
      return ArchitectSnapResult(
        point: best.point,
        isSnapped: true,
        snapLabel: best.source,
        magneticGuides: anchor == null ? [] : [(anchor, best.point)],
      );
    }
    if (anchor != null) {
      final delta = raw - anchor;
      if (delta.distance < 1e-9) return ArchitectSnapResult(point: anchor);
      final angle = math.atan2(delta.dy, delta.dx);
      // Right angles have stronger capture than intermediate directions.
      for (final step in [math.pi / 2, math.pi / 4]) {
        final target = (angle / step).round() * step;
        final u = Offset(math.cos(target), math.sin(target));
        final projection = anchor + u * _dot(delta, u);
        final threshold = step == math.pi / 2 ? math.pi / 15 : math.pi / 30;
        if ((angle - target).abs() <= threshold &&
            (projection - raw).distance <= radius + 1e-9) {
          final degrees = (target * 180 / math.pi + 360) % 360;
          for (final axis in project.gridAxes) {
            if (excluded(axis.id)) continue;
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
            final dist = (inter - projection).distance;
            if (dist <= math.max(radius, 0.25)) {
              return ArchitectSnapResult(
                point: inter,
                isSnapped: true,
                snapLabel: 'Axis ${axis.name}',
                angleDeg: degrees,
                magneticGuides: [(anchor, inter), (axis.start, axis.end)],
              );
            }
          }
          return ArchitectSnapResult(
            point: projection,
            isSnapped: true,
            snapLabel: '${degrees.round()}°',
            angleDeg: degrees,
            magneticGuides: [(anchor, projection)],
          );
        }
      }
      if (alignment) {
        for (final edge in geometry.edges) {
          if (excluded(edge.owner)) continue;
          final u = (edge.b - edge.a) / (edge.b - edge.a).distance;
          for (final direction in [u, Offset(-u.dy, u.dx)]) {
            final projection = anchor + direction * _dot(delta, direction);
            if ((projection - raw).distance <= radius &&
                (projection - raw).distance <=
                    delta.distance * math.sin(math.pi / 90)) {
              return ArchitectSnapResult(
                point: projection,
                isSnapped: true,
                snapLabel: 'Alignment',
                magneticGuides: [(anchor, projection), (edge.a, edge.b)],
              );
            }
          }
        }
      }
    }
    for (final axis in project.gridAxes) {
      if (excluded(axis.id)) continue;
      final proj = axis.projectPoint(raw);
      if ((proj - raw).distance <= radius) {
        return ArchitectSnapResult(
          point: proj,
          isSnapped: true,
          snapLabel: 'Axis ${axis.name}',
          magneticGuides: anchor == null ? [(axis.start, axis.end)] : [(anchor, proj), (axis.start, axis.end)],
        );
      }
    }
    if (alignment) {
      Offset? aligned;
      (Offset, Offset)? guide;
      var distance = radius;
      void align(Offset base, Offset direction) {
        final projection = base + direction * _dot(raw - base, direction);
        final d = (projection - raw).distance;
        if (d < distance &&
            (anchor == null || (projection - anchor).distance > 1e-9)) {
          distance = d;
          aligned = projection;
          guide = (base, projection);
        }
      }

      for (final p in geometry.alignmentPoints) {
        if (excluded(p.owner)) continue;
        align(p.point, const Offset(1, 0));
        align(p.point, const Offset(0, 1));
      }
      for (final edge in geometry.edges) {
        if (excluded(edge.owner)) continue;
        final u = (edge.b - edge.a) / (edge.b - edge.a).distance;
        for (final p in [edge.a, edge.b]) {
          align(p, u);
          align(p, Offset(-u.dy, u.dx));
        }
      }
      if (aligned != null) {
        return ArchitectSnapResult(
          point: aligned!,
          isSnapped: true,
          snapLabel: 'Alignment',
          magneticGuides: [guide!],
        );
      }
    }
    return ArchitectSnapResult(point: precision(project).inputPoint(raw));
  }

  static Iterable<Offset> _circleCrossings(
    ArchitectSnapCircle circle,
    (Offset, Offset) edge,
  ) sync* {
    final u = edge.$2 - edge.$1, v = edge.$1 - circle.center;
    final a = u.distanceSquared,
        b = 2 * _dot(v, u),
        c = v.distanceSquared - circle.radius * circle.radius;
    final discriminant = b * b - 4 * a * c;
    if (a < 1e-16 || discriminant < -1e-10) return;
    final root = math.sqrt(math.max(0, discriminant));
    for (final t in [(-b - root) / (2 * a), (-b + root) / (2 * a)]) {
      if (t >= 0 && t <= 1) yield edge.$1 + u * t;
    }
  }

  static Offset? _axisCrossing(Offset a, Offset b, (Offset, Offset) edge) {
    final u = b - a, v = edge.$2 - edge.$1, d = edge.$1 - a;
    final cross = u.dx * v.dy - u.dy * v.dx;
    if (cross.abs() <= 1e-12 * u.distance * v.distance) return null;
    final s = (d.dx * u.dy - d.dy * u.dx) / cross;
    if (s < 0 || s > 1) return null;
    final t = (d.dx * v.dy - d.dy * v.dx) / cross;
    return a + u * t;
  }
}
