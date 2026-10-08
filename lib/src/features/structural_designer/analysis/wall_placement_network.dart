import 'dart:math' as math;
import 'dart:ui';
import 'geometric_window_detector.dart';
import 'structural_polygon_distance.dart';
import 'wall_placement_domain.dart';

class PlacementWallSegment {
  final Offset start, end;
  final double width;
  const PlacementWallSegment(this.start, this.end, this.width);
  Offset get center => (start + end) / 2;
}

/// Distance ordering over connected wall segments. Openings are traversal links,
/// never permission to place a support; architectural validation is independent.
class WallPlacementNetwork {
  static List<double> distances(
    List<PlacementWallSegment> walls,
    List<List<Offset>> cores,
    List<GeometricWindowOpening> openings,
    double scale,
  ) {
    if (walls.isEmpty) return [];
    final polygons = walls
        .map((w) => WallPlacementDomain.strip(w.start, w.end, w.width))
        .toList();
    Rect bounds(List<Offset> p) => Rect.fromLTRB(
      p.map((p) => p.dx).reduce(math.min),
      p.map((p) => p.dy).reduce(math.min),
      p.map((p) => p.dx).reduce(math.max),
      p.map((p) => p.dy).reduce(math.max),
    );
    final boxes = polygons.map(bounds).toList();
    final edges = List.generate(walls.length, (_) => <(int, double)>[]);
    void connect(int a, int b, double cost) {
      if (a < 0 || b < 0 || a == b) return;
      edges[a].add((b, cost));
      edges[b].add((a, cost));
    }

    for (var i = 0; i < walls.length; i++) {
      for (var j = 0; j < i; j++) {
        if (!boxes[i].inflate(.03 * scale).overlaps(boxes[j])) continue;
        if (StructuralPolygonDistance.between(polygons[i], polygons[j]) <=
            .03 * scale) {
          connect(i, j, (walls[i].center - walls[j].center).distance / scale);
        }
      }
    }
    for (final opening in openings) {
      int at(Offset p) {
        var best = -1, distance = .03 * scale;
        for (var i = 0; i < walls.length; i++) {
          final d = math.min(
            (walls[i].start - p).distance,
            (walls[i].end - p).distance,
          );
          if (d < distance) {
            best = i;
            distance = d;
          }
        }
        return best;
      }

      final a = at(opening.start), b = at(opening.end);
      if (a >= 0 && b >= 0) {
        connect(a, b, (walls[a].center - walls[b].center).distance / scale);
      }
    }
    final result = List.filled(walls.length, double.infinity);
    final proximity = List.filled(walls.length, double.infinity);
    for (final core in cores) {
      if (core.isEmpty) continue;
      final distances = [
        for (final wall in walls)
          core
              .map(
                (p) =>
                    StructuralPolygonDistance.pointToSegment(
                      p,
                      wall.start,
                      wall.end,
                    ) /
                    scale,
              )
              .reduce(math.min),
      ];
      final nearest = distances.reduce(math.min);
      for (var i = 0; i < walls.length; i++) {
        proximity[i] = math.min(proximity[i], distances[i]);
        if (distances[i] <= nearest + .25) {
          result[i] = math.min(result[i], distances[i]);
        }
      }
    }
    final visited = <int>{};
    var frontier = 0.0;
    while (visited.length < walls.length) {
      var best = -1, distance = double.infinity;
      for (var i = 0; i < walls.length; i++) {
        if (!visited.contains(i) && result[i] < distance) {
          best = i;
          distance = result[i];
        }
      }
      if (best < 0) {
        // A disconnected wing gets its own seed; it must not be silently skipped.
        for (var i = 0; i < walls.length; i++) {
          if (!visited.contains(i) &&
              (best < 0 || proximity[i] < proximity[best])) {
            best = i;
          }
        }
        result[best] = frontier + 1;
      }
      visited.add(best);
      frontier = math.max(frontier, result[best]);
      for (final (next, cost) in edges[best]) {
        result[next] = math.min(result[next], result[best] + cost);
      }
    }
    return result;
  }
}
