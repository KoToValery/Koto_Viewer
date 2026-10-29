import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_connection_policy.dart';

class ArchitectWallExteriorResult {
  final ArchitectWallLocation location;
  final WallExteriorSide? side;
  const ArchitectWallExteriorResult(this.location, [this.side]);
}

/// A planar graph of the physical core axes. Its bounded faces are interior
/// spaces, including unlabelled rooms. Open branches never manufacture a room.
/// All predicates use model-space doubles, independent of zoom and raster grids.
class ArchitectWallExteriorResolver {
  static final _cache = Expando<Map<String, ArchitectWallExteriorResult>>();
  static const _epsilon = 1e-7;

  static bool _sameGeometry(ArchitectWall a, ArchitectWall b) =>
      a.id == b.id &&
      (a.coreCenterStart - b.coreCenterStart).distance < _epsilon &&
      (a.coreCenterEnd - b.coreCenterEnd).distance < _epsilon &&
      (a.arcBulge - b.arcBulge).abs() < _epsilon &&
      (a.coreThickness - b.coreThickness).abs() < _epsilon &&
      a.connectStart == b.connectStart &&
      a.connectEnd == b.connectEnd &&
      a.isParapet == b.isParapet &&
      a.system.signature == b.system.signature &&
      a.systemPlacement.startTail == b.systemPlacement.startTail &&
      a.systemPlacement.endTail == b.systemPlacement.endTail;

  static bool _sameInputs(ArchitectWall a, ArchitectWall b) =>
      _sameGeometry(a, b) &&
      a.location == b.location &&
      a.exteriorSide == b.exteriorSide &&
      a.locationMode == b.locationMode &&
      a.exteriorSideMode == b.exteriorSideMode;

  static ArchitectProject resolve(
    ArchitectProject next,
    ArchitectProject previous,
  ) {
    var changed = false;
    final floors = [
      for (final floor in next.storeys)
        () {
          final old = previous.storeys
              .where((s) => s.id == floor.id)
              .firstOrNull;
          if (old != null &&
              floor.walls.length == old.walls.length &&
              List.generate(
                floor.walls.length,
                (i) => _sameInputs(floor.walls[i], old.walls[i]),
              ).every((v) => v)) {
            return floor;
          }
          final resolved = resolveStorey(floor, previous: old);
          changed |= !identical(resolved, floor);
          return resolved;
        }(),
    ];
    return changed ? next.copyWith(storeys: floors) : next;
  }

  static ArchitectStorey resolveStorey(
    ArchitectStorey floor, {
    ArchitectStorey? previous,
  }) {
    Map<String, ArchitectWallExteriorResult>? results;
    if (previous != null &&
        floor.walls.length == previous.walls.length &&
        List.generate(
          floor.walls.length,
          (i) => _sameGeometry(floor.walls[i], previous.walls[i]),
        ).every((v) => v)) {
      results = _cache[previous.walls];
    }
    results ??= analyze(floor.walls);
    var changed = false;
    final walls = [
      for (final wall in floor.walls)
        () {
          if (wall.isParapet) return wall;
          final inferred = results![wall.id];
          final location = wall.locationMode == WallResolutionMode.automatic
              ? inferred?.location ?? wall.location
              : wall.location;
          final exterior = location == null
              ? wall.isExterior
              : location == ArchitectWallLocation.exterior;
          final side =
              exterior &&
                  wall.exteriorSideMode == WallResolutionMode.automatic &&
                  inferred?.location == ArchitectWallLocation.exterior
              ? inferred?.side
              : null;
          final resolved =
              inferred != null &&
              (!exterior ||
                  inferred.side != null ||
                  wall.exteriorSideMode == WallResolutionMode.manual);
          if (location == wall.location &&
              (side == null || side == wall.exteriorSide) &&
              resolved == wall.exteriorResolved) {
            return wall;
          }
          changed = true;
          var updated = side != null && side != wall.exteriorSide
              ? wall.mirroredAroundCore()
              : wall;
          updated = updated.copyWith(
            location: location,
            exteriorResolved: resolved,
          );
          return updated;
        }(),
    ];
    if (!changed) return floor;
    final next = floor.copyWith(walls: walls);
    _cache[next.walls] = results;
    return next;
  }

  static Map<String, ArchitectWallExteriorResult> analyze(
    List<ArchitectWall> walls,
  ) {
    final cached = _cache[walls];
    if (cached != null) return cached;
    final sources = walls
        .where((w) => !w.isParapet && w.length > .001)
        .toList();
    // Neutral proxies remove finish offsets and special-system decoration.
    final axes = [
      for (final w in sources)
        ArchitectWall(
          id: w.id,
          startPoint: w.coreCenterStart,
          endPoint: w.coreCenterEnd,
          arcBulge: w.arcBulge,
          thickness: w.coreThickness,
          connectStart: w.connectStart,
          connectEnd: w.connectEnd,
        ),
    ];
    final cuts = [
      for (final _ in axes) <double>[0, 1],
    ];
    final from = List.filled(axes.length, 0.0),
        to = List.filled(axes.length, 1.0);
    final overlaps = <int>{};
    double parameter(ArchitectWall w, Offset p) =>
        w.arc?.parameter(p) ??
        ((p - w.startPoint).dx * w.unitVector.dx +
                (p - w.startPoint).dy * w.unitVector.dy) /
            w.length;
    bool permitted(ArchitectWall w, double t) =>
        !w.isDetached &&
        (t > _epsilon || w.connectStart) &&
        (t < 1 - _epsilon || w.connectEnd);
    bool near(ArchitectWall w, double t, double allowance) =>
        t >= -allowance / w.length && t <= 1 + allowance / w.length;
    bool finite(double t) => t >= -_epsilon && t <= 1 + _epsilon;

    for (var i = 0; i < axes.length; i++) {
      final a = axes[i];
      for (var j = i + 1; j < axes.length; j++) {
        final b = axes[j];
        if (a.isDetached || b.isDetached) continue;
        final allowance =
            math.max(sources[i].thickness, sources[j].thickness) + .001;
        if (!Rect.fromPoints(a.startPoint, a.endPoint)
            .inflate(a.length * (a.isCurved ? 1 : 0) + allowance)
            .overlaps(
              Rect.fromPoints(
                b.startPoint,
                b.endPoint,
              ).inflate(b.length * (b.isCurved ? 1 : 0) + allowance),
            )) {
          continue;
        }
        final nodes = a.intersections(b, finite: false);
        if (!a.isCurved &&
            !b.isCurved &&
            _cross(a.unitVector, b.unitVector).abs() < _epsilon &&
            _cross(b.startPoint - a.startPoint, a.unitVector).abs() <
                _epsilon) {
          final t0 = parameter(a, b.startPoint), t1 = parameter(a, b.endPoint);
          if (math.min(1.0, math.max(t0, t1)) -
                  math.max(0.0, math.min(t0, t1)) >
              _epsilon) {
            overlaps.addAll([i, j]);
          }
          nodes.addAll([a.startPoint, a.endPoint, b.startPoint, b.endPoint]);
        }
        for (final p in nodes) {
          final ta = parameter(a, p), tb = parameter(b, p);
          if (!near(a, ta, allowance) ||
              !near(b, tb, allowance) ||
              !permitted(a, ta) ||
              !permitted(b, tb)) {
            continue;
          }
          // An extended axis is a junction only when the physical cores touch.
          if ((!finite(ta) || !finite(tb)) &&
              !(!a.isCurved &&
                  !b.isCurved &&
                  ArchitectWallConnectionPolicy.coreJunction(
                        sources[i],
                        sources[j],
                      ) !=
                      null) &&
              sources[i].intersections(sources[j]).isEmpty &&
              ![
                a.startPoint,
                a.endPoint,
              ].any((p) => b.containsPoint(p, tolerance: .0001)) &&
              ![
                b.startPoint,
                b.endPoint,
              ].any((p) => a.containsPoint(p, tolerance: .0001))) {
            continue;
          }
          cuts[i].add(ta);
          cuts[j].add(tb);
          from[i] = math.min(from[i], ta);
          to[i] = math.max(to[i], ta);
          from[j] = math.min(from[j], tb);
          to[j] = math.max(to[j], tb);
          for (final entry in [(i, j, ta), (j, i, tb)]) {
            final w = sources[entry.$1],
                other = sources[entry.$2],
                t = entry.$3;
            // A reference corner may place the core junction just before its
            // saved end cap. Those short junction overruns are not facade runs.
            final referenceNodes = w
                .intersections(other)
                .where((q) => (q - p).distance <= allowance * 1.5);
            final reach =
                ArchitectWallConnectionPolicy.coreJunctionReach(other) + .0001;
            if ((t < .5 && t * axes[entry.$1].length <= reach) ||
                referenceNodes.any(
                  (q) => (q - w.startPoint).distance < .0001,
                )) {
              from[entry.$1] = math.max(from[entry.$1], t);
            }
            if ((t > .5 && (1 - t) * axes[entry.$1].length <= reach) ||
                referenceNodes.any((q) => (q - w.endPoint).distance < .0001)) {
              to[entry.$1] = math.min(to[entry.$1], t);
            }
            if (ArchitectWallConnectionPolicy.protectsLogTail(
              w,
              other,
              true,
              p,
            )) {
              from[entry.$1] = math.max(from[entry.$1], t);
            }
            if (ArchitectWallConnectionPolicy.protectsLogTail(
              w,
              other,
              false,
              p,
            )) {
              to[entry.$1] = math.min(to[entry.$1], t);
            }
          }
        }
      }
    }

    final vertices = <Offset>[], indices = <(int, int, String?), int>{};
    int vertex(Offset p, String? detached) => indices.putIfAbsent(
      ((p.dx * 1e7).round(), (p.dy * 1e7).round(), detached),
      () {
        vertices.add(p);
        return vertices.length - 1;
      },
    );
    final adjacency = <int, Set<int>>{}, edges = <(int, int, int)>[];
    for (var i = 0; i < axes.length; i++) {
      final a = axes[i], arc = a.arc;
      if (arc != null) {
        final step = 2 * math.acos((1 - .00005 / arc.radius).clamp(-1, 1));
        final count = (arc.sweep.abs() / step).ceil().clamp(1, 2048);
        cuts[i].addAll([for (var k = 1; k < count; k++) k / count]);
      }
      cuts[i].addAll([from[i], to[i]]);
      final ts =
          cuts[i]
              .where((t) => t >= from[i] - _epsilon && t <= to[i] + _epsilon)
              .toList()
            ..sort();
      for (var k = 1; k < ts.length; k++) {
        if (ts[k] - ts[k - 1] < _epsilon) continue;
        Offset at(double t) =>
            arc?.pointAt(t) ?? a.startPoint + a.unitVector * (a.length * t);
        String? detached(double t) =>
            a.isDetached ||
                t.abs() < _epsilon && !a.connectStart ||
                (t - 1).abs() < _epsilon && !a.connectEnd
            ? a.id
            : null;
        final x = vertex(at(ts[k - 1]), detached(ts[k - 1])),
            y = vertex(at(ts[k]), detached(ts[k]));
        if (x == y) continue;
        (adjacency[x] ??= {}).add(y);
        (adjacency[y] ??= {}).add(x);
        edges.add((x, y, i));
      }
    }
    final sorted = {
      for (final e in adjacency.entries)
        e.key: e.value.toList()
          ..sort((a, b) {
            final u = vertices[a] - vertices[e.key],
                v = vertices[b] - vertices[e.key];
            return math.atan2(u.dy, u.dx).compareTo(math.atan2(v.dy, v.dx));
          }),
    };
    final visited = <(int, int)>{}, faces = <List<Offset>>[];
    for (final e in sorted.entries) {
      for (final next in e.value) {
        var edge = (e.key, next);
        if (visited.contains(edge)) continue;
        final first = edge, face = <Offset>[];
        while (visited.add(edge)) {
          face.add(vertices[edge.$1]);
          final neighbors = sorted[edge.$2]!,
              index = neighbors.indexOf(edge.$1);
          edge = (
            edge.$2,
            neighbors[(index - 1 + neighbors.length) % neighbors.length],
          );
        }
        // Backtracking around a dangling partition has zero area and is safe
        // in the winding predicate; do not discard the surrounding room.
        if (edge == first && _area(face) > 1e-6) faces.add(face);
      }
    }
    bool inside(Offset p) => faces.any((face) => _contains(face, p));
    final states = [for (final _ in sources) <int>{}];
    for (final (x, y, i) in edges) {
      final a = vertices[x], b = vertices[y], delta = b - a;
      final middle = (a + b) / 2;
      final n =
          Offset(-delta.dy, delta.dx) /
          delta.distance *
          math.min(.0005, delta.distance * .05);
      final left = inside(middle + n), right = inside(middle - n);
      states[i].add(
        left && right
            ? 0
            : left
            ? -1
            : right
            ? 1
            : 2,
      );
    }
    final result = <String, ArchitectWallExteriorResult>{};
    for (var i = 0; i < sources.length; i++) {
      if (overlaps.contains(i) || states[i].length != 1) continue;
      final state = states[i].single;
      if (state == 2) continue;
      result[sources[i].id] = state == 0
          ? const ArchitectWallExteriorResult(ArchitectWallLocation.interior)
          : ArchitectWallExteriorResult(
              ArchitectWallLocation.exterior,
              state == 1 ? WallExteriorSide.left : WallExteriorSide.right,
            );
    }
    return _cache[walls] = Map.unmodifiable(result);
  }

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double _area(List<Offset> p) {
    if (p.length < 3) return 0;
    final origin = p.first;
    var area = 0.0;
    for (var i = 0; i < p.length; i++) {
      area += _cross(p[i] - origin, p[(i + 1) % p.length] - origin);
    }
    return area / 2;
  }

  static bool _contains(List<Offset> polygon, Offset p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}
