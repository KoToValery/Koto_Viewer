import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_stair_geometry.dart';

class StairRailingPath {
  final List<Vector3> base;
  final bool wallMounted;
  const StairRailingPath(this.base, this.wallMounted);
}

/// Guards are derived, never frozen into the stair when it is placed. Wall
/// edits, openings and floor heights therefore immediately change the result.
class ArchitectStairRailings {
  static final _cache = Expando<Expando<List<StairRailingPath>>>();
  static List<StairRailingPath> build(
    ArchitectStair stair, {
    required ArchitectStorey storey,
    ArchitectProject? project,
  }) {
    if (stair.design == null || !stair.design!.showRailing) return const [];
    final key = project ?? storey;
    final cache = _cache[key] ??= Expando<List<StairRailingPath>>();
    final cached = cache[stair];
    if (cached != null) return cached;
    final d = stair.design!, geometry = ArchitectStairGeometry.of(stair);
    final candidates = <(ArchitectWall, double)>[];
    final bounds = stair.plan.bounds.inflate(.08);
    for (final floor in project?.storeys ?? [storey]) {
      for (final wall in floor.walls) {
        final rect = Rect.fromPoints(
          wall.centerStart,
          wall.centerEnd,
        ).inflate(wall.thickness / 2 + .05);
        if (!rect.overlaps(bounds)) continue;
        candidates.add((
          wall.copyWith(height: wall.effectiveHeight(floor.height)),
          floor.elevation + wall.baseOffset - storey.elevation,
        ));
      }
    }
    bool wallAt(Offset point, Offset tangent, double base) {
      for (final (wall, bottom) in candidates) {
        if (ArchitectStairGeometry.dot(tangent, wall.unitVector).abs() < .96) {
          continue;
        }
        final along = ArchitectStairGeometry.dot(
          point - wall.centerStart,
          wall.unitVector,
        );
        if (along < -.01 || along > wall.length + .01) continue;
        final distance = ArchitectStairGeometry.pointSegmentDistance(
          point,
          wall.centerStart,
          wall.centerEnd,
        );
        if ((distance - wall.thickness / 2).abs() > .045) continue;
        if (bottom > base + .025 ||
            bottom + wall.height < base + d.guardHeight - .025) {
          continue;
        }
        var opening = false;
        for (final value in [
          for (final door in wall.doors)
            (door.offsetRatio, door.width, door.sillHeight, door.height),
          for (final window in wall.windows)
            (
              window.offsetRatio,
              window.width,
              window.sillHeight,
              window.height,
            ),
        ]) {
          if ((along - value.$1 * wall.length).abs() <= value.$2 / 2 + .025 &&
              bottom + value.$3 < base + d.guardHeight &&
              bottom + value.$3 + value.$4 > base) {
            opening = true;
            break;
          }
        }
        if (!opening) return true;
      }
      return false;
    }

    final pieces = <({Vector3 a, Vector3 b, bool wall})>[];
    // Resample the spiral analytically, rather than creating a post at every
    // tiny vertex used to draw its smooth plan contour.
    var edges = [
      if (!d.isSpiral)
        for (final (a, b) in geometry.guardEdges)
          (
            a: a,
            b: b,
            za: geometry.elevationAt(a),
            zb: geometry.elevationAt(b),
          ),
    ];
    if (d.isSpiral) {
      final u = stair.unitVector,
          v = stair.normalVector * (d.turnLeft ? -1 : 1);
      final centre = stair.startPoint + v * (d.innerRadius + stair.width / 2);
      final sweep = d.sweepDegrees * math.pi / 180;
      edges = [
        for (final radius in [d.innerRadius, d.innerRadius + stair.width])
          ...() {
            final count = math.max(8, (sweep * radius / .12).ceil());
            Offset p(int i) =>
                centre +
                u * (radius * math.sin(sweep * i / count)) -
                v * (radius * math.cos(sweep * i / count));
            return [
              for (var i = 0; i < count; i++)
                (
                  a: p(i),
                  b: p(i + 1),
                  za:
                      d.startOffset +
                      (1 + (d.risers - 1) * i / count) * d.riser,
                  zb:
                      d.startOffset +
                      (1 + (d.risers - 1) * (i + 1) / count) * d.riser,
                ),
            ];
          }(),
      ];
    }
    for (final edge in edges) {
      final a = edge.a, b = edge.b;
      final delta = b - a;
      final count = math.max(1, (delta.distance / .08).ceil());
      final tangent = delta / delta.distance;
      for (var i = 0; i < count; i++) {
        final p = a + delta * (i / count), q = a + delta * ((i + 1) / count);
        final za = edge.za + (edge.zb - edge.za) * i / count;
        final zb = edge.za + (edge.zb - edge.za) * (i + 1) / count;
        pieces.add((
          a: Vector3(p.dx, p.dy, za),
          b: Vector3(q.dx, q.dy, zb),
          wall: wallAt((p + q) / 2, tangent, (za + zb) / 2),
        ));
      }
    }
    String node(Vector3 p, bool wall) =>
        '${wall ? 1 : 0}:${(p.x * 1e5).round()},${(p.y * 1e5).round()},${(p.z * 1e5).round()}';
    final links = <String, List<int>>{};
    for (var i = 0; i < pieces.length; i++) {
      for (final p in [pieces[i].a, pieces[i].b]) {
        (links[node(p, pieces[i].wall)] ??= []).add(i);
      }
    }
    final used = <int>{}, paths = <StairRailingPath>[];
    for (var seed = 0; seed < pieces.length; seed++) {
      if (used.contains(seed)) continue;
      final wall = pieces[seed].wall;
      final values = <Vector3>[pieces[seed].a, pieces[seed].b];
      used.add(seed);
      void extend(bool front) {
        while (true) {
          final current = front ? values.first : values.last;
          final next = (links[node(current, wall)] ?? [])
              .where((i) => !used.contains(i))
              .firstOrNull;
          if (next == null) break;
          used.add(next);
          final piece = pieces[next];
          final point = node(piece.a, wall) == node(current, wall)
              ? piece.b
              : piece.a;
          if (front) {
            values.insert(0, point);
          } else {
            values.add(point);
          }
        }
      }

      extend(false);
      extend(true);
      if (wall) {
        for (var i = 0; i < values.length; i++) {
          final p = Offset(values[i].x, values[i].y);
          var nearest = Offset.zero, distance = double.infinity;
          for (final (a, b) in stair.plan.nosings) {
            final mid = (a + b) / 2, length = (mid - p).distance;
            if (length < distance) {
              distance = length;
              nearest = mid;
            }
          }
          final delta = nearest - p;
          if (delta.distance > .001) {
            final q = p + delta / delta.distance * .045;
            values[i] = Vector3(q.dx, q.dy, values[i].z);
          }
        }
      }
      paths.add(StairRailingPath(values, wall));
    }
    return cache[stair] = paths;
  }
}
