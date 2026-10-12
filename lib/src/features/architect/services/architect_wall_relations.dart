import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../rendering/architect_wall_network.dart';

class ArchitectWallClearance {
  final String wallId, neighborId;
  final int side;
  final double distance;
  final Offset start, end;
  const ArchitectWallClearance({
    required this.wallId,
    required this.neighborId,
    required this.side,
    required this.distance,
    required this.start,
    required this.end,
  });
  Offset get midpoint => (start + end) / 2;

  /// Finished-face distance to the nearest facing wall on each side.
  static List<ArchitectWallClearance> nearest(
    ArchitectWall wall,
    List<ArchitectWall> walls,
  ) {
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final nearest = <int, ArchitectWallClearance>{};
    final origin = wall.centerStart, u = wall.unitVector, n = wall.normalVector;
    for (final other in walls) {
      if (other.id == wall.id ||
          (dot(u, other.unitVector).abs() - 1).abs() > 1e-7) {
        continue;
      }
      final corners = other.polygonCorners;
      final along = corners.map((p) => dot(p - origin, u)).toList();
      final lo = math.max(0.0, along.reduce(math.min));
      final hi = math.min(wall.length, along.reduce(math.max));
      if (hi - lo < .001) continue;
      final across = corners.map((p) => dot(p - origin, n)).toList();
      final low = across.reduce(math.min), high = across.reduce(math.max);
      final half = wall.thickness / 2;
      final side = low >= half - 1e-8
          ? 1
          : high <= -half + 1e-8
          ? -1
          : 0;
      if (side == 0) continue;
      final gap = math.max(0.0, side > 0 ? low - half : -half - high);
      if (nearest[side] != null && nearest[side]!.distance <= gap) continue;
      final start = origin + u * ((lo + hi) / 2) + n * (side * half);
      nearest[side] = ArchitectWallClearance(
        wallId: wall.id,
        neighborId: other.id,
        side: side,
        distance: gap,
        start: start,
        end: start + n * (side * gap),
      );
    }
    return [
      for (final side in [-1, 1])
        if (nearest[side] != null) nearest[side]!,
    ];
  }
}

class ArchitectWallTrimSpan {
  final ArchitectWall wall;
  final double from, to;
  const ArchitectWallTrimSpan(this.wall, this.from, this.to);
  Offset get start =>
      wall.coreCenterStart + wall.unitVector * (from * wall.length);
  Offset get end => wall.coreCenterStart + wall.unitVector * (to * wall.length);

  /// The picked interval is bounded by real wall crossings or wall ends.
  static ArchitectWallTrimSpan at(
    ArchitectWall wall,
    List<ArchitectWall> walls,
    Offset pick,
  ) {
    final cuts = <double>[0, 1];
    for (final other in walls) {
      if (other.id == wall.id) continue;
      final point = ArchitectWallNetwork.intersection(
        wall.coreCenterStart,
        wall.coreCenterEnd,
        other.coreCenterStart,
        other.coreCenterEnd,
      );
      if (point == null) continue;
      final d = point - wall.coreCenterStart;
      final along = d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
      final e = point - other.coreCenterStart;
      final otherAlong =
          e.dx * other.unitVector.dx + e.dy * other.unitVector.dy;
      if (along <= .001 ||
          along >= wall.length - .001 ||
          otherAlong < -other.thickness / 2 ||
          otherAlong > other.length + other.thickness / 2) {
        continue;
      }
      final ratio = along / wall.length;
      if (cuts.every((c) => (c - ratio).abs() > 1e-8)) cuts.add(ratio);
    }
    cuts.sort();
    final d = pick - wall.coreCenterStart;
    final ratio =
        ((d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy) / wall.length)
            .clamp(0.0, 1.0);
    for (var i = 0; i < cuts.length - 1; i++) {
      if (ratio < cuts[i + 1] - 1e-8 || i == cuts.length - 2) {
        return ArchitectWallTrimSpan(wall, cuts[i], cuts[i + 1]);
      }
    }
    return ArchitectWallTrimSpan(wall, 0, 1);
  }
}
