import 'dart:ui';
import '../../bim_editing/geometry/bim_offset_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../models/architect_contour.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';

/// Native offsets in model metres. Groups are selection metadata, never a
/// replacement boundary: connected axes join; separate contours stay separate.
class ArchitectOffset {
  static Set<String> supportedIds(ArchitectStorey s) => {
    ...s.walls.map((e) => e.id),
    ...s.beams.map((e) => e.id),
    ...s.stairs.map((e) => e.id),
    ...s.slabs.map((e) => e.id),
    ...s.roofs.map((e) => e.id),
    ...s.openings.map((e) => e.id),
    ...s.zones.where((e) => !e.isAutoBoundary).map((e) => e.id),
    ...s.cadPrimitives.map((e) => e.id),
  };

  static bool supports(ArchitectStorey s, Set<String> ids) =>
      ids.isNotEmpty && supportedIds(s).containsAll(ids);

  /// Nearest selected boundary is the visual origin of the direction arrow.
  static Offset directionAnchor(ArchitectStorey s, Set<String> ids, Offset side) {
    var best = double.infinity;
    var anchor = side;
    void consider(Offset point) {
      final distance = (point - side).distanceSquared;
      if (distance < best) { best = distance; anchor = point; }
    }
    void ring(List<Offset> points) {
      for (var i = 0; i < points.length; i++) {
        final a = points[i], d = points[(i + 1) % points.length] - a;
        if (d.distanceSquared < 1e-12) continue;
        final t = (BimPolygonGeometry.dot(side - a, d) / d.distanceSquared).clamp(0.0, 1.0);
        consider(a + d * t);
      }
    }
    for (final e in _axes(s, ids)) {
      consider(e.referencePointAt(e.projectPoint(side).$1.clamp(0.0, 1.0)));
    }
    for (final e in s.slabs.where((e) => ids.contains(e.id))) { ring(e.polygon); }
    for (final e in s.roofs.where((e) => ids.contains(e.id))) { ring(e.points); }
    for (final e in s.openings.where((e) => ids.contains(e.id))) { ring(e.boundary); }
    for (final e in s.zones.where((e) => ids.contains(e.id))) { ring(e.polygon); }
    for (final e in s.cadPrimitives.where((e) => ids.contains(e.id))) {
      if (e.isPolygon) ring(e.polygonCorners);
      if (e.type == CadPrimitiveType.circle) {
        final d = side - e.startPoint;
        if (d.distance > 1e-12) consider(e.startPoint + d / d.distance * (e.endPoint - e.startPoint).distance);
      }
    }
    return anchor;
  }

  static List<ArchitectWall> _axes(ArchitectStorey s, Set<String> ids) => [
    ...s.walls.where((e) => ids.contains(e.id)),
    for (final e in s.beams.where((e) => ids.contains(e.id)))
      ArchitectWall(id: e.id, startPoint: e.startPoint, endPoint: e.endPoint),
    for (final e in s.stairs.where((e) => ids.contains(e.id)))
      ArchitectWall(id: e.id, startPoint: e.startPoint, endPoint: e.endPoint),
    for (final e in s.cadPrimitives.where(
      (e) => ids.contains(e.id) && e.type == CadPrimitiveType.line,
    ))
      ArchitectWall(id: e.id, startPoint: e.startPoint, endPoint: e.endPoint),
  ];

  /// New IDs are supplied by the command, keeping repeated previews stable.
  /// Openings stay fixed in world coordinates when a host perimeter is offset.
  static ArchitectStorey apply(
    ArchitectStorey s,
    Set<String> ids, {
    required double distance,
    required Offset side,
    Map<String, String> idMap = const {},
    String? editingGroupId,
    Map<String, String> groupIdMap = const {},
  }) {
    if (!supports(s, ids) ||
        !distance.isFinite ||
        distance <= 0 ||
        !side.dx.isFinite ||
        !side.dy.isFinite) {
      throw ArgumentError('Invalid offset selection or distance');
    }
    final copy = idMap.isNotEmpty;
    if (copy &&
        (idMap.length != ids.length ||
            !ids.every(idMap.containsKey) ||
            idMap.values.toSet().length != ids.length)) {
      throw ArgumentError('Incomplete offset ID map');
    }
    String id(String source) => idMap[source] ?? source;
    final axes = _axes(s, ids);
    final shifted = <String, ArchitectWall>{};
    final shifts = <String, double>{};
    // Different native kinds do not acquire artificial axis junctions.
    final kinds = <String, String>{
      for (final e in s.walls) e.id: 'wall',
      for (final e in s.beams) e.id: 'beam',
      for (final e in s.cadPrimitives) e.id: 'line',
      for (final e in s.stairs) e.id: e.id,
    };
    for (final kind in axes.map((e) => kinds[e.id]).toSet()) {
      final remaining = axes.where((e) => kinds[e.id] == kind).toList();
      for (final path in _chains(remaining)) {
        final closed =
            (path.last.endPoint - path.first.startPoint).distance < 1e-7;
        final samples = _samples(path);
        _validatePath(path, closed);
        if (closed && BimPolygonGeometry.signedArea(samples).abs() < 1e-6) {
          throw ArgumentError('Invalid closed offset chain');
        }
        double left;
        if (closed) {
          left =
              distance *
              BimPolygonGeometry.signedArea(samples).sign *
              (BimPolygonGeometry.contains(samples, side) ? 1 : -1);
        } else {
          var best = double.infinity;
          left = distance;
          for (final e in path) {
            final r = e.projectPoint(side).$1.clamp(0.0, 1.0);
            final p = e.referencePointAt(r);
            final delta = side - p;
            if (delta.distance < best) {
              best = delta.distance;
              final t = e.tangentAt(r);
              left =
                  distance * (BimPolygonGeometry.cross(t, delta) >= 0 ? 1 : -1);
            }
          }
        }
        final parallels = [for (final e in path) _parallel(e, left)];
        final starts = parallels.map((e) => e.startPoint).toList();
        final ends = parallels.map((e) => e.endPoint).toList();
        for (var i = 0; i < (closed ? path.length : path.length - 1); i++) {
          final j = (i + 1) % path.length;
          final a = parallels[i], b = parallels[j];
          Offset? corner;
          if ((a.endPoint - b.startPoint).distance < 1e-7) {
            corner = (a.endPoint + b.startPoint) / 2;
          } else {
            final hits = a.intersections(b, finite: false)
              ..sort(
                (p, q) => (p - path[i].endPoint).distance.compareTo(
                  (q - path[i].endPoint).distance,
                ),
              );
            corner = hits.firstOrNull;
          }
          if (corner == null ||
              (corner - path[i].endPoint).distance > distance * 50) {
            throw ArgumentError('Offset junction is ambiguous');
          }
          ends[i] = starts[j] = corner;
        }
        final result = <ArchitectWall>[];
        for (var i = 0; i < path.length; i++) {
          final e = parallels[i].withExtendedEnds(
            start: starts[i],
            end: ends[i],
          );
          if (!e.length.isFinite ||
              e.length < .001 ||
              (!e.isCurved &&
                  BimPolygonGeometry.dot(
                        e.endPoint - e.startPoint,
                        path[i].endPoint - path[i].startPoint,
                      ) <=
                      0)) {
            throw ArgumentError('Offset segment collapsed');
          }
          result.add(e);
          final original = axes.firstWhere((p) => p.id == e.id);
          final reversed =
              (original.startPoint - path[i].startPoint).distance > 1e-7;
          shifted[e.id] = reversed
              ? e.copyWith(
                  startPoint: e.endPoint,
                  endPoint: e.startPoint,
                  arcBulge: -e.arcBulge,
                )
              : e;
          shifts[e.id] = reversed ? -left : left;
        }
        final points = _samples(result);
        _validatePath(result, closed);
        if (closed) {
          if (BimPolygonGeometry.signedArea(points).abs() < 1e-6 ||
              BimPolygonGeometry.signedArea(points) *
                      BimPolygonGeometry.signedArea(samples) <=
                  0) {
            throw ArgumentError('Offset chain intersects');
          }
        }
      }
    }

    List<Offset> contour(
      List<Offset> outer, [
      List<List<Offset>> holes = const [],
    ]) {
      final amount = BimPolygonGeometry.contains(outer, side)
          ? -distance
          : distance;
      final points = BimOffsetGeometry.ring(outer, amount);
      if (!ArchitectContour.valid(points, holes)) {
        throw ArgumentError('Offset crosses a host opening');
      }
      return points;
    }

    double openingRatio(ArchitectWall old, ArchitectWall next, double ratio) {
      final d = shifts[old.id]!;
      final p =
          old.arc?.pointAt(ratio, leftOffset: d) ??
          old.referencePointAt(ratio) + old.normalVector * d;
      return next.projectPoint(p).$1;
    }

    final walls = [
      for (final e in s.walls)
        if (!ids.contains(e.id) || copy) e,
      for (final e in s.walls.where((e) => ids.contains(e.id)))
        (() {
          final axis = shifted[e.id]!;
          final next = e.copyWith(
            id: id(e.id),
            startPoint: axis.startPoint,
            endPoint: axis.endPoint,
            arcBulge: axis.arcBulge,
            doors: [
              for (final d in e.doors)
                d.copyWith(
                  id: copy ? '${id(e.id)}_door_${d.id}' : d.id,
                  uuid: copy ? '${id(e.id)}_uuid_${d.id}' : d.uuid,
                  wallId: id(e.id),
                  offsetRatio: openingRatio(e, axis, d.offsetRatio),
                ),
            ],
            windows: [
              for (final w in e.windows)
                w.copyWith(
                  id: copy ? '${id(e.id)}_window_${w.id}' : w.id,
                  uuid: copy ? '${id(e.id)}_uuid_${w.id}' : w.uuid,
                  wallId: id(e.id),
                  offsetRatio: openingRatio(e, axis, w.offsetRatio),
                ),
            ],
          );
          for (final opening in [
            ...next.doors.map((d) => (d.offsetRatio, d.width)),
            ...next.windows.map((w) => (w.offsetRatio, w.width)),
          ]) {
            if (opening.$1 * next.length < opening.$2 / 2 - 1e-8 ||
                (1 - opening.$1) * next.length < opening.$2 / 2 - 1e-8) {
              throw ArgumentError('Opening no longer fits offset wall');
            }
          }
          next.validateGeometry();
          return next;
        })(),
    ];
    final next = s.copyWith(
      walls: walls,
      beams: [
        for (final e in s.beams)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.beams.where((e) => ids.contains(e.id)))
          e.copyWith(
            id: id(e.id),
            startPoint: shifted[e.id]!.startPoint,
            endPoint: shifted[e.id]!.endPoint,
          ),
      ],
      stairs: [
        for (final e in s.stairs)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.stairs.where((e) => ids.contains(e.id)))
          e.copyWith(
            id: id(e.id),
            startPoint: shifted[e.id]!.startPoint,
            endPoint: shifted[e.id]!.endPoint,
          ),
      ],
      slabs: [
        for (final e in s.slabs)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.slabs.where((e) => ids.contains(e.id)))
          e.copyWith(id: id(e.id), polygon: contour(e.polygon, e.holes)),
      ],
      roofs: [
        for (final e in s.roofs)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.roofs.where((e) => ids.contains(e.id)))
          (() {
            final copiedRoofGroup = !copy || e.roofGroupId == null
                ? e.roofGroupId
                : 'offset_roof_${id(s.roofs.firstWhere((r) => ids.contains(r.id) && r.roofGroupId == e.roofGroupId).id)}';
            final r = e.copyWith(
              id: id(e.id),
              points: contour(e.points, e.holes),
              placementResolved: true,
              roofGroupId: copiedRoofGroup,
            );
            // Extend the existing sloped plane, preserving elevation at every
            // original world point instead of moving the whole roof vertically.
            return r.copyWith(
              baseElevationOffset:
                  r.baseElevationOffset +
                  e.undersideElevationAt(e.points.first) -
                  r.undersideElevationAt(e.points.first),
            );
          })(),
      ],
      openings: [
        for (final e in s.openings)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.openings.where((e) => ids.contains(e.id)))
          e.copyWith(id: id(e.id), boundary: contour(e.boundary)),
      ],
      zones: [
        for (final e in s.zones)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.zones.where((e) => ids.contains(e.id)))
          e.copyWith(
            id: id(e.id),
            polygon: contour(e.polygon),
            clearScheduleOrigin: copy,
            isAutoBoundary: false,
          ),
      ],
      cadPrimitives: [
        for (final e in s.cadPrimitives)
          if (!ids.contains(e.id) || copy) e,
        for (final e in s.cadPrimitives.where((e) => ids.contains(e.id)))
          (() {
            if (e.type == CadPrimitiveType.line) {
              return e.copyWith(
                id: id(e.id),
                startPoint: shifted[e.id]!.startPoint,
                endPoint: shifted[e.id]!.endPoint,
              );
            }
            if (e.type == CadPrimitiveType.circle) {
              final v = e.endPoint - e.startPoint;
              final radius =
                  v.distance +
                  ((side - e.startPoint).distance < v.distance
                      ? -distance
                      : distance);
              if (!v.distance.isFinite ||
                  !radius.isFinite ||
                  v.distance < .001 ||
                  radius < .001) {
                throw ArgumentError('Offset circle collapsed');
              }
              return e.copyWith(
                id: id(e.id),
                endPoint: e.startPoint + v / v.distance * radius,
              );
            }
            final p = contour(e.polygonCorners, e.holes);
            final bounds = p.fold(
              Rect.fromPoints(p.first, p.first),
              (r, v) => r.expandToInclude(Rect.fromPoints(v, v)),
            );
            return e.copyWith(
              id: id(e.id),
              polygon: p,
              startPoint: bounds.topLeft,
              endPoint: bounds.bottomRight,
            );
          })(),
      ],
    );
    if (!copy) return next;
    if (editingGroupId != null) {
      if (!s.groups.any(
        (g) => g.id == editingGroupId && g.elementIds.containsAll(ids),
      )) {
        throw ArgumentError('Offset selection escaped the edited group');
      }
      return next.copyWith(
        groups: [
          for (final g in s.groups)
            g.id == editingGroupId
                ? ArchitectElementGroup(
                    id: g.id,
                    elementIds: {...g.elementIds, ...idMap.values},
                  )
                : g,
        ],
      );
    }
    return next.copyWith(
      groups: [
        ...s.groups,
        for (final g in s.groups.where(
          (g) => g.elementIds.every(idMap.containsKey),
        ))
          ArchitectElementGroup(
            id:
                groupIdMap[g.id] ??
                (throw ArgumentError('Missing offset group ID')),
            elementIds: g.elementIds.map((e) => idMap[e]!).toSet(),
          ),
      ],
    );
  }

  static ArchitectWall _parallel(ArchitectWall e, double left) {
    if (e.isCurved) {
      if (e.arc!.radius - e.arcBulge.sign * left <= .001) {
        throw ArgumentError('Offset arc collapsed');
      }
      return e.copyWith(
        startPoint: e.arc!.pointAt(0, leftOffset: left),
        endPoint: e.arc!.pointAt(1, leftOffset: left),
        doors: [],
        windows: [],
      );
    }
    final shift = e.normalVector * left;
    return e.copyWith(
      startPoint: e.startPoint + shift,
      endPoint: e.endPoint + shift,
      doors: [],
      windows: [],
    );
  }

  static List<Offset> _samples(List<ArchitectWall> path) => [
    for (final e in path)
      for (var i = 0; i < (e.isCurved ? 64 : 1); i++)
        e.referencePointAt(i / (e.isCurved ? 64 : 1)),
    if ((path.first.startPoint - path.last.endPoint).distance > 1e-7)
      path.last.endPoint,
  ];

  /// Check exact curves rather than comparing every tessellated sample pair.
  /// Full circle bounds conservatively reject distant pairs before intersection.
  static void _validatePath(List<ArchitectWall> path, bool closed) {
    const tolerance = 1e-7;
    final bounds = [
      for (final e in path)
        (e.isCurved
                ? Rect.fromCircle(center: e.arc!.center, radius: e.arc!.radius)
                : Rect.fromPoints(e.startPoint, e.endPoint))
            .inflate(tolerance),
    ];
    for (var i = 0; i < path.length; i++) {
      for (var j = i + 1; j < path.length; j++) {
        if (!bounds[i].overlaps(bounds[j])) continue;
        final a = path[i], b = path[j];
        final allowed = [
          if (j == i + 1) a.endPoint,
          if (closed && i == 0 && j == path.length - 1) a.startPoint,
        ];
        final hits = [...a.intersections(b)];
        if (!a.isCurved &&
            !b.isCurved &&
            BimPolygonGeometry.cross(a.unitVector, b.unitVector).abs() < 1e-9 &&
            BimPolygonGeometry.cross(
                  a.unitVector,
                  b.startPoint - a.startPoint,
                ).abs() <
                tolerance) {
          final x = BimPolygonGeometry.dot(
            b.startPoint - a.startPoint,
            a.unitVector,
          );
          final y = BimPolygonGeometry.dot(
            b.endPoint - a.startPoint,
            a.unitVector,
          );
          final low = (x < y ? x : y).clamp(0.0, a.length);
          final high = (x > y ? x : y).clamp(0.0, a.length);
          if (high - low > tolerance) {
            throw ArgumentError('Overlapping offset axes');
          }
          for (final p in [a.startPoint, a.endPoint]) {
            if ((p - b.startPoint).distance < tolerance ||
                (p - b.endPoint).distance < tolerance) {
              hits.add(p);
            }
          }
        }
        if (a.isCurved &&
            b.isCurved &&
            (a.arc!.center - b.arc!.center).distance < tolerance &&
            (a.arc!.radius - b.arc!.radius).abs() < tolerance) {
          bool inside(ArchitectWall owner, Offset p) {
            final r = owner.arc!.parameter(p);
            return r > 1e-8 && r < 1 - 1e-8;
          }

          for (final r in [0.0, .5, 1.0]) {
            if (inside(a, b.referencePointAt(r)) ||
                inside(b, a.referencePointAt(r))) {
              throw ArgumentError('Overlapping offset arcs');
            }
          }
          hits.addAll([
            for (final p in [a.startPoint, a.endPoint])
              if ((p - b.startPoint).distance < tolerance ||
                  (p - b.endPoint).distance < tolerance)
                p,
          ]);
        }
        if (hits.any(
          (p) => !allowed.any((q) => (p - q).distance < tolerance),
        )) {
          throw ArgumentError('Offset chain intersects');
        }
      }
    }
  }

  /// Walk an unbranched chain, independent of stored segment direction/order.
  static List<List<ArchitectWall>> _chains(List<ArchitectWall> axes) {
    bool near(Offset a, Offset b) => (a - b).distance < 1e-7;
    int degree(Offset p) => axes.fold(
      0,
      (n, e) =>
          n + (near(p, e.startPoint) ? 1 : 0) + (near(p, e.endPoint) ? 1 : 0),
    );
    if (axes.any(
      (e) =>
          e.length < .001 || degree(e.startPoint) > 2 || degree(e.endPoint) > 2,
    )) {
      throw ArgumentError('Offset requires unbranched chains');
    }
    final remaining = [...axes];
    final result = <List<ArchitectWall>>[];
    while (remaining.isNotEmpty) {
      final endpoint =
          remaining
              .expand((e) => [e.startPoint, e.endPoint])
              .where((p) => degree(p) == 1)
              .firstOrNull ??
          remaining.first.startPoint;
      var point = endpoint;
      final chain = <ArchitectWall>[];
      while (true) {
        final e = remaining
            .where((e) => near(e.startPoint, point) || near(e.endPoint, point))
            .firstOrNull;
        if (e == null) break;
        remaining.remove(e);
        final oriented = near(e.startPoint, point)
            ? e
            : e.copyWith(
                startPoint: e.endPoint,
                endPoint: e.startPoint,
                arcBulge: -e.arcBulge,
                doors: [],
                windows: [],
              );
        // Geometry proxies must not use a wall reference-line center offset.
        chain.add(
          ArchitectWall(
            id: e.id,
            startPoint: oriented.startPoint,
            endPoint: oriented.endPoint,
            arcBulge: oriented.arcBulge,
            thickness: .001,
          ),
        );
        point = oriented.endPoint;
      }
      result.add(chain);
    }
    return result;
  }
}
