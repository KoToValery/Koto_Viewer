import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../services/architect_underlay_clip.dart';
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
import 'architect_midpoint_tracking.dart';

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
    bool wallCoresOnly = true,
    bool preferIntersections = false,
    Set<String> excludedIds = const {},
    List<ArchitectMidpointReference> midpointReferences = const [],
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
    wallCoresOnly: wallCoresOnly,
    preferIntersections: preferIntersections,
    excludedIds: excludedIds,
    midpointReferences: midpointReferences,
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
    bool wallCoresOnly = true,
    bool preferIntersections = false,
    Set<String> excludedIds = const {},
    Set<String>? includedIds,
    List<ArchitectMidpointReference> midpointReferences = const [],
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
    wallCoresOnly: wallCoresOnly,
    preferIntersections: preferIntersections,
    excludedIds: excludedIds,
    includedIds: includedIds,
    midpointReferences: midpointReferences,
    underlay: underlay,
    frame: frame,
    visibility: visibility,
  );

  static BimSnapKind _kind(String label) => switch (label) {
    'Endpoint' ||
    'Vertex' ||
    'Axis endpoint' ||
    'Door jamb' ||
    'Window jamb' => BimSnapKind.endpoint,
    'Intersection' || 'Axis intersection' => BimSnapKind.intersection,
    'Apparent intersection' => BimSnapKind.apparentIntersection,
    'Center' => BimSnapKind.center,
    'Midpoint' => BimSnapKind.midpoint,
    'Quadrant' => BimSnapKind.quadrant,
    'Perpendicular' => BimSnapKind.perpendicular,
    'Alignment' => BimSnapKind.alignment,
    'Midpoint alignment' => BimSnapKind.alignment,
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
    bool wallCoresOnly = true,
    List<ArchitectMidpointReference> midpointReferences = const [],
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (!magnetic) return ArchitectSnapResult(point: delta);
    final points =
        ArchitectSnapGeometry.of(project, wallCoresOnly: wallCoresOnly)
            .alignmentPoints
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
        wallCoresOnly: wallCoresOnly,
        excludedIds: elementIds,
        midpointReferences: midpointReferences,
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
    bool wallCoresOnly = true,
    bool preferIntersections = false,
    required Set<String> excludedIds,
    Set<String>? includedIds,
    required List<ArchitectMidpointReference> midpointReferences,
    DxfDocument? underlay,
    required BimCoordinateFrame frame,
    required Map<String, bool> visibility,
  }) {
    if (!magnetic || radius <= 0) {
      return ArchitectSnapResult(point: precision(project).inputPoint(raw));
    }
    final geometry = ArchitectSnapGeometry.of(
      project,
      wallCoresOnly: wallCoresOnly,
    );
    final underlayMask = ArchitectUnderlayClip.of(project);
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
    final includedOwners = includedIds == null
        ? null
        : {
            ...includedIds,
            for (final wall in project.activeStorey.walls.where(
              (w) => includedIds.contains(w.id),
            )) ...[
              ...wall.doors.map((door) => door.id),
              ...wall.windows.map((window) => window.id),
            ],
          };
    bool excluded(String owner) =>
        (includedOwners != null &&
            !includedOwners.contains(owner) &&
            !(owner.startsWith('@wall-axis:') &&
                includedOwners.contains(owner.substring(11)))) ||
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
    final intersections = BimSnapResolver<String>(
      raw: raw,
      radius: radius,
      anchor: anchor,
    );
    void consider(Offset point, String label) {
      final candidate = BimSnapCandidate(
        point: point,
        kind: _kind(label),
        source: label,
      );
      resolver.consider(candidate);
      if (preferIntersections && candidate.kind == BimSnapKind.intersection) {
        intersections.consider(candidate);
      }
    }

    final references = midpointReferences
        .where(
          (r) =>
              !excluded(r.owner) &&
              !excluded(r.edge.owner) &&
              geometry.midpointEdges.contains(r.edge),
        )
        .toList();
    for (final reference in references) {
      consider(reference.point, 'Midpoint');
    }

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
    if (underlay != null && includedIds == null) {
      underlay.orBuildSpatialIndex;
      nearby.addAll(
        ArchitectUnderlayClip.segments(
          DxfSegmentSnap.nearby(
            document: underlay,
            point: frame.toCad(raw),
            radius: radius * frame.unitsPerMeter,
            layerVisibility: visibility,
          ).map((e) => (frame.toModel(e.$1), frame.toModel(e.$2))),
          underlayMask,
        ),
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
    final apparentGuides = <Offset, List<(Offset, Offset)>>{};
    const maxExtension = 20.0;
    final extendedCandidates = <({Offset a, Offset b, String owner})>[];
    for (final edge in geometry.nearbyEdges(raw, maxExtension)) {
      if (excluded(edge.owner) ||
          edge.owner == '@wall-joints' ||
          edge.owner == '@wall-face-joints') {
        continue;
      }
      final u = edge.b - edge.a;
      final lenSq = u.dx * u.dx + u.dy * u.dy;
      if (lenSq < 1e-8) continue;
      final cross = ((raw.dx - edge.a.dx) * u.dy - (raw.dy - edge.a.dy) * u.dx)
          .abs();
      if (cross * cross <= radius * radius * lenSq) {
        extendedCandidates.add((a: edge.a, b: edge.b, owner: edge.owner));
      }
    }
    if (underlay != null && includedIds == null) {
      final cadMaxExt = maxExtension * frame.unitsPerMeter;
      final cadRaw = frame.toCad(raw);
      var dxfIdx = 0;
      for (final e in ArchitectUnderlayClip.segments(
        DxfSegmentSnap.nearby(
          document: underlay,
          point: cadRaw,
          radius: cadMaxExt,
          layerVisibility: visibility,
        ).map((e) => (frame.toModel(e.$1), frame.toModel(e.$2))),
        underlayMask,
      )) {
        final u = e.$2 - e.$1;
        final lenSq = u.dx * u.dx + u.dy * u.dy;
        if (lenSq < 1e-8) continue;
        final cross = ((raw.dx - e.$1.dx) * u.dy - (raw.dy - e.$1.dy) * u.dx)
            .abs();
        if (cross * cross <= radius * radius * lenSq) {
          extendedCandidates.add((a: e.$1, b: e.$2, owner: '@dxf:${dxfIdx++}'));
        }
      }
    }
    String elementId(String owner) =>
        owner.startsWith('@wall-axis:') ? owner.substring(11) : owner;
    for (var i = 0; i < extendedCandidates.length; i++) {
      final e1 = extendedCandidates[i];
      final id1 = elementId(e1.owner);
      for (var j = i + 1; j < extendedCandidates.length; j++) {
        final e2 = extendedCandidates[j];
        final id2 = elementId(e2.owner);
        if (id1 == id2) continue;
        final ext = DxfSegmentSnap.extendedIntersection(
          (e1.a, e1.b),
          (e2.a, e2.b),
          maxExtension: maxExtension,
        );
        if (ext != null &&
            (ext.point - raw).distance <= radius &&
            (!(e1.owner.startsWith('@dxf:') || e2.owner.startsWith('@dxf:')) ||
                ArchitectUnderlayClip.contains(underlayMask, ext.point))) {
          apparentGuides[ext.point] = [
            if (ext.guide1 != null) ext.guide1!,
            if (ext.guide2 != null) ext.guide2!,
          ];
          consider(ext.point, 'Apparent intersection');
        }
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
    final best = intersections.best ?? resolver.best;
    if (best != null) {
      final guides = <(Offset, Offset)>[];
      if (anchor != null) guides.add((anchor, best.point));
      if (best.source == 'Apparent intersection' &&
          apparentGuides.containsKey(best.point)) {
        guides.addAll(apparentGuides[best.point]!);
      }
      return ArchitectSnapResult(
        point: best.point,
        isSnapped: true,
        snapLabel: best.source,
        magneticGuides: guides,
      );
    }
    final tracked = ArchitectMidpointTracking.align(
      raw: raw,
      radius: radius,
      references: references,
      anchor: anchor,
    );
    if (tracked != null) {
      return ArchitectSnapResult(
        point: tracked.point,
        isSnapped: true,
        snapLabel: 'Midpoint alignment',
        magneticGuides: tracked.guides,
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
          magneticGuides: anchor == null
              ? [(axis.start, axis.end)]
              : [(anchor, proj), (axis.start, axis.end)],
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
