// === SECTION: FLOOR DRAIN GEOMETRY ===
// Table of Contents:
// 1. FALL FIELD (height of the finished floor above the drain)
// 2. DOOR THRESHOLDS & DRAIN VALIDATION
// 3. AUTOMATIC DRAIN PLACEMENT
// 4. DRAWING GEOMETRY (arrows, contour lines) with cache

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../models/architect_floor_drain.dart';
import '../models/architect_wall.dart';


/// A door opening that lies on the edge of the wet-area floor.
class ArchitectDrainThreshold {
  final Offset start;
  final Offset end;

  /// Floor height at the middle of the threshold above the drain, metres.
  final double fall;
  const ArchitectDrainThreshold(this.start, this.end, this.fall);
  Offset get middle => (start + end) / 2;
}

enum ArchitectDrainIssue { outsideFloor, nearDoor }

class ArchitectDrainContour {
  final Path path;

  /// Height above the drain level in millimetres.
  final int millimetres;
  final Offset? labelPoint;
  const ArchitectDrainContour(this.path, this.millimetres, this.labelPoint);
}

class ArchitectDrainField {
  final List<(Offset, Offset)> arrows;
  final List<ArchitectDrainContour> contours;
  final List<ArchitectDrainThreshold> thresholds;
  final Set<ArchitectDrainIssue> issues;

  /// Highest point of the finished floor above the drain level, metres.
  final double maxFall;
  const ArchitectDrainField({
    required this.arrows,
    required this.contours,
    required this.thresholds,
    required this.issues,
    required this.maxFall,
  });
}

class ArchitectFloorDrainGeometry {
  ArchitectFloorDrainGeometry._();

  // ===========================================================================
  // 1. FALL FIELD
  // ===========================================================================

  static Offset nearestOnAxis(ArchitectFloorDrain drain, Offset p) {
    final (a, b) = drain.axis;
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 < 1e-12) return a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return a + ab * t;
  }

  /// Distance from [p] to the edge of the grate, never negative.
  static double distanceToGrate(ArchitectFloorDrain drain, Offset p) =>
      math.max(0, (p - nearestOnAxis(drain, p)).distance - drain.halfWidth);

  /// Finished-floor height above the drain level at [p], metres.
  static double fall(ArchitectFloorDrain drain, Offset p) =>
      distanceToGrate(drain, p) * drain.slopePercent / 100;

  /// Unit vector of the water flow at [p]; null on the grate itself.
  static Offset? downhill(ArchitectFloorDrain drain, Offset p) {
    final v = nearestOnAxis(drain, p) - p;
    return v.distance < 1e-6 ? null : v / v.distance;
  }

  /// The distance function is convex, so its maximum lies on a vertex.
  static double maxFall(ArchitectFloorDrain drain) {
    var result = 0.0;
    for (final p in drain.polygon) {
      result = math.max(result, fall(drain, p));
    }
    return result;
  }

  static double boundaryDistance(ArchitectFloorDrain drain, Offset p) {
    var best = double.infinity;
    void ring(List<Offset> r) {
      for (var i = 0; i < r.length; i++) {
        best = math.min(best, _segmentDistance(p, r[i], r[(i + 1) % r.length]));
      }
    }

    ring(drain.polygon);
    drain.holes.forEach(ring);
    return best;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    if (len2 < 1e-12) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ===========================================================================
  // 2. DOOR THRESHOLDS & DRAIN VALIDATION
  // ===========================================================================

  /// Doors whose opening lies on the floor outline. The floor continues over
  /// the threshold, so the fall must end there and no arrow crosses it.
  static List<ArchitectDrainThreshold> thresholds(
    ArchitectFloorDrain drain,
    Iterable<ArchitectWall> walls,
  ) {
    final result = <ArchitectDrainThreshold>[];
    final ring = drain.polygon;
    if (ring.length < 3) return result;
    for (final wall in walls) {
      for (final door in wall.doors) {
        final centre =
            wall.startPoint + (wall.endPoint - wall.startPoint) * door.offsetRatio;
        var bestDistance = double.infinity;
        (Offset, Offset)? bestEdge;
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i], b = ring[(i + 1) % ring.length];
          final d = _segmentDistance(centre, a, b);
          if (d < bestDistance) {
            bestDistance = d;
            bestEdge = (a, b);
          }
        }
        if (bestEdge == null || bestDistance > wall.thickness + 0.05) continue;
        final (a, b) = bestEdge;
        final edge = b - a;
        if (edge.distance < 1e-9) continue;
        final u = edge / edge.distance;
        final along = (centre - a).dx * u.dx + (centre - a).dy * u.dy;
        final half = door.width / 2;
        final from = (along - half).clamp(0.0, edge.distance);
        final to = (along + half).clamp(0.0, edge.distance);
        if (to - from < 0.1) continue;
        final start = a + u * from, end = a + u * to;
        result.add(
          ArchitectDrainThreshold(start, end, fall(drain, (start + end) / 2)),
        );
      }
    }
    return result;
  }

  static Set<ArchitectDrainIssue> validate(
    ArchitectFloorDrain drain,
    List<ArchitectDrainThreshold> thresholds,
  ) {
    final issues = <ArchitectDrainIssue>{};
    final (a, b) = drain.axis;
    final inside =
        drain.containsPoint(a) &&
        drain.containsPoint(b) &&
        boundaryDistance(drain, a) >= drain.halfWidth * .99 &&
        boundaryDistance(drain, b) >= drain.halfWidth * .99;
    if (!inside) issues.add(ArchitectDrainIssue.outsideFloor);
    for (final t in thresholds) {
      if (_segmentDistance(nearestOnAxis(drain, t.middle), t.start, t.end) <
              0.30 ||
          (nearestOnAxis(drain, t.middle) - t.middle).distance < 0.30) {
        issues.add(ArchitectDrainIssue.nearDoor);
      }
    }
    return issues;
  }

  // ===========================================================================
  // 3. AUTOMATIC DRAIN PLACEMENT
  // ===========================================================================

  /// Round drains sit in the calmest part of the floor, away from doors.
  /// Linear drains run along the longest wall without a door.
  static ArchitectFloorDrain autoPlace({
    required String id,
    required List<Offset> polygon,
    List<List<Offset>> holes = const [],
    required ArchitectDrainShape shape,
    required Iterable<ArchitectWall> walls,
    double slopePercent = ArchitectDrainDefaults.slopePercent,
    double? size,
    double? width,
  }) {
    var drain = ArchitectFloorDrain(
      id: id,
      polygon: polygon,
      holes: holes,
      shape: shape,
      position: _centroid(polygon),
      size:
          size ??
          (shape == ArchitectDrainShape.round
              ? ArchitectDrainDefaults.roundDiameter
              : ArchitectDrainDefaults.linearLength),
      width: width ?? ArchitectDrainDefaults.linearWidth,
      slopePercent: slopePercent,
    );
    final doors = thresholds(drain, walls);
    double doorDistance(Offset p) {
      var best = 3.0;
      for (final t in doors) {
        best = math.min(best, _segmentDistance(p, t.start, t.end));
      }
      return best;
    }

    if (shape == ArchitectDrainShape.linear) {
      final placed = _placeLinear(drain, doors);
      if (placed != null) return placed;
    }
    final bounds = _bounds(polygon);
    var best = drain.position;
    var bestScore = -double.infinity;
    const step = 0.05;
    for (var x = bounds.left; x <= bounds.right; x += step) {
      for (var y = bounds.top; y <= bounds.bottom; y += step) {
        final p = Offset(x, y);
        if (!drain.containsPoint(p)) continue;
        final wall = boundaryDistance(drain, p);
        if (wall < drain.halfWidth + 0.10) continue;
        final score = math.min(wall, 1.2) * 0.6 + doorDistance(p) * 0.8;
        if (score > bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
    drain = drain.copyWith(position: best);
    if (shape == ArchitectDrainShape.linear) {
      drain = drain.copyWith(size: math.min(drain.size, bounds.shortestSide));
    }
    return drain;
  }

  static ArchitectFloorDrain? _placeLinear(
    ArchitectFloorDrain drain,
    List<ArchitectDrainThreshold> doors,
  ) {
    final ring = drain.polygon;
    ({Offset a, Offset b, double length, bool door})? best;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      final length = (b - a).distance;
      if (length < ArchitectDrainDefaults.linearMin + 0.2) continue;
      final hasDoor = doors.any(
        (t) => _segmentDistance(t.middle, a, b) < 0.05,
      );
      final better =
          best == null ||
          (best.door && !hasDoor) ||
          (best.door == hasDoor && length > best.length);
      if (better) best = (a: a, b: b, length: length, door: hasDoor);
    }
    if (best == null) return null;
    final u = (best.b - best.a) / best.length;
    var normal = Offset(-u.dy, u.dx);
    final middle = (best.a + best.b) / 2;
    if (!drain.containsPoint(middle + normal * 0.05)) normal = -normal;
    final length = math.min(
      ArchitectDrainDefaults.linearLength,
      best.length - 0.2,
    );
    return drain.copyWith(
      size: length,
      angle: math.atan2(u.dy, u.dx),
      position: middle + normal * (drain.width / 2 + 0.03),
    );
  }

  static Offset _centroid(List<Offset> points) {
    var x = 0.0, y = 0.0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return points.isEmpty ? Offset.zero : Offset(x / points.length, y / points.length);
  }

  static Rect _bounds(List<Offset> points) {
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // ===========================================================================
  // 4. DRAWING GEOMETRY
  // ===========================================================================

  static final _cache = Expando<_CachedField>();

  /// Memoised per immutable drain and wall list.
  static ArchitectDrainField field(
    ArchitectFloorDrain drain,
    List<ArchitectWall> walls,
  ) {
    final cached = _cache[drain];
    if (cached != null && identical(cached.walls, walls)) return cached.field;
    final result = _build(drain, walls);
    _cache[drain] = _CachedField(walls, result);
    return result;
  }

  static ArchitectDrainField _build(
    ArchitectFloorDrain drain,
    List<ArchitectWall> walls,
  ) {
    final doors = thresholds(drain, walls);
    final issues = validate(drain, doors);
    final maxHeight = maxFall(drain);
    if (drain.polygon.length < 3 || maxHeight <= 1e-6) {
      return ArchitectDrainField(
        arrows: const [],
        contours: const [],
        thresholds: doors,
        issues: issues,
        maxFall: maxHeight,
      );
    }
    final slope = drain.slopePercent / 100;

    // Contour step: at most six lines, on a round millimetre value.
    const steps = [5, 10, 20, 25, 50, 100];
    final stepMm = steps.firstWhere(
      (s) => s >= maxHeight * 1000 / 6,
      orElse: () => steps.last,
    );
    final contours = <ArchitectDrainContour>[];
    for (var mm = stepMm; mm < maxHeight * 1000 - 1; mm += stepMm) {
      final offset = mm / 1000 / slope;
      contours.add(_contour(drain, offset, mm));
    }

    // Arrows on a regular grid, away from walls, grate and thresholds.
    final bounds = _bounds(drain.polygon);
    final spacing = math.sqrt(drain.area.abs() / 10).clamp(0.45, 0.9);
    final length = math.min(0.28, spacing * 0.45);
    final arrows = <(Offset, Offset)>[];
    for (var x = bounds.left + spacing / 2; x < bounds.right; x += spacing) {
      for (var y = bounds.top + spacing / 2; y < bounds.bottom; y += spacing) {
        final p = Offset(x, y);
        if (!drain.containsPoint(p) ||
            boundaryDistance(drain, p) < length / 2 + 0.08 ||
            distanceToGrate(drain, p) < length / 2 + 0.12) {
          continue;
        }
        if (doors.any((t) => _segmentDistance(p, t.start, t.end) < 0.30)) {
          continue;
        }
        final dir = downhill(drain, p);
        if (dir == null) continue;
        arrows.add((p - dir * (length / 2), p + dir * (length / 2)));
      }
    }
    return ArchitectDrainField(
      arrows: arrows,
      contours: contours,
      thresholds: doors,
      issues: issues,
      maxFall: maxHeight,
    );
  }

  static ArchitectDrainContour _contour(
    ArchitectFloorDrain drain,
    double offset,
    int millimetres,
  ) {
    final radius = drain.halfWidth + offset;
    final path = Path();
    final c = math.cos(drain.angle), s = math.sin(drain.angle);
    final matrix = Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0,
      0, 0, 1, 0,
      drain.position.dx, drain.position.dy, 0, 1,
    ]);
    if (drain.isLinear) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: drain.size + radius * 2,
            height: radius * 2,
          ),
          Radius.circular(radius),
        ),
      );
    } else {
      path.addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
    }
    // Label on the side of the contour that is furthest inside the room.
    Offset? label;
    var bestClearance = 0.0;
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      final local = drain.isLinear
          ? Offset(
              dir.dx.abs() < .2 ? 0 : (dir.dx > 0 ? drain.size / 2 : -drain.size / 2),
              0,
            ) + dir * radius
          : dir * radius;
      final world = drain.position + Offset(
        local.dx * c - local.dy * s,
        local.dx * s + local.dy * c,
      );
      if (!drain.containsPoint(world)) continue;
      final clearance = boundaryDistance(drain, world);
      if (clearance > bestClearance) {
        bestClearance = clearance;
        label = world;
      }
    }
    return ArchitectDrainContour(path.transform(matrix), millimetres, label);
  }
}

class _CachedField {
  final List<ArchitectWall> walls;
  final ArchitectDrainField field;
  const _CachedField(this.walls, this.field);
}
