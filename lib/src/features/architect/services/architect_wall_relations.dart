import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../rendering/architect_wall_network.dart';

class ArchitectWallClearance {
  final String wallId, neighborId;
  final int side;
  final double distance;
  final Offset start, end;

  /// Endpoint readouts pivot the wall instead of translating the whole wall.
  final bool? atStart;
  final String? supportId;
  const ArchitectWallClearance({
    required this.wallId,
    required this.neighborId,
    required this.side,
    required this.distance,
    required this.start,
    required this.end,
    this.atStart,
    this.supportId,
  });
  Offset get midpoint => (start + end) / 2;
  String get key => atStart == null
      ? neighborId
      : '$neighborId-${atStart! ? 'start' : 'end'}';

  ArchitectWallClearance nearView(
    ArchitectWall wall,
    ArchitectWall neighbor,
    Rect view,
  ) {
    if (atStart != null) return this;
    double along(Offset p) {
      final d = p - wall.centerStart;
      return d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
    }

    final extents = neighbor.polygonCorners.map(along).toList();
    final lo = math.max(0.0, extents.reduce(math.min));
    final hi = math.min(wall.length, extents.reduce(math.max));
    final station = along(view.center).clamp(lo, math.max(lo, hi));
    final shift = wall.unitVector * (station - along(start));
    return ArchitectWallClearance(
      wallId: wallId,
      neighborId: neighborId,
      side: side,
      distance: distance,
      start: start + shift,
      end: end + shift,
    );
  }

  /// Distances from connected endpoint junctions, along their supports, to
  /// perpendicular reference walls. The clearance is measured from the visual
  /// intersection point of the inner/outer wall edge with the support face,
  /// preserving clear room dimensions and visual edge corners.
  static List<ArchitectWallClearance> endpoints(
    ArchitectWall wall,
    List<ArchitectWall> walls, {
    bool includeParallel = false,
  }) {
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    final result = <ArchitectWallClearance>[];
    final ordered = walls.toList()..sort((a, b) => a.id.compareTo(b.id));
    for (final atStart in [true, false]) {
      if (!(atStart ? wall.connectStart : wall.connectEnd)) continue;
      final point = atStart ? wall.startPoint : wall.endPoint;
      final bestBySide = <int, ArchitectWallClearance>{};
      for (final support in ordered) {
        if (support.id == wall.id ||
            support.isDetached ||
            !support.connectsAt(point) ||
            cross(support.unitVector, wall.unitVector).abs() < 1e-5) {
          continue;
        }
        final lines = [
          (support.startPoint, support.endPoint),
          (support.coreCenterStart, support.coreCenterEnd),
          (support.polygonCorners[0], support.polygonCorners[1]),
          (support.polygonCorners[3], support.polygonCorners[2]),
        ];
        final onSupport = lines.any((line) {
          final d = point - line.$1;
          final along = dot(d, support.unitVector);
          return cross(d, support.unitVector).abs() < .001 &&
              along >= -.001 &&
              along <= support.length + .001;
        });
        if (!onSupport) continue;

        // Visual intersection logic:
        // 1. Face of support where wall extends
        final wallDir = atStart ? wall.unitVector : -wall.unitVector;
        final supportNormalDot = dot(wallDir, support.normalVector);
        final sOffset = dot(support.centerOffset, support.normalVector);
        final supportFaceNormalOffset =
            sOffset +
            (supportNormalDot >= 0
                ? support.thickness / 2
                : -support.thickness / 2);
        final supportFaceStart =
            support.startPoint + support.normalVector * supportFaceNormalOffset;
        final supportFaceEnd =
            support.endPoint + support.normalVector * supportFaceNormalOffset;

        // 2. Both finished face lines of wall (inner and outer edges)
        final wOffset = dot(wall.centerOffset, wall.normalVector);
        final wallFace1Start =
            wall.startPoint +
            wall.normalVector * (wOffset + wall.thickness / 2);
        final wallFace1End =
            wall.endPoint + wall.normalVector * (wOffset + wall.thickness / 2);
        final wallFace2Start =
            wall.startPoint +
            wall.normalVector * (wOffset - wall.thickness / 2);
        final wallFace2End =
            wall.endPoint + wall.normalVector * (wOffset - wall.thickness / 2);

        final inter1 = ArchitectWallNetwork.intersection(
          supportFaceStart,
          supportFaceEnd,
          wallFace1Start,
          wallFace1End,
        );
        final inter2 = ArchitectWallNetwork.intersection(
          supportFaceStart,
          supportFaceEnd,
          wallFace2Start,
          wallFace2End,
        );

        for (final target in ordered) {
          if (target.id == wall.id ||
              target.id == support.id ||
              dot(target.unitVector, support.unitVector).abs() > 1e-5 ||
              (!includeParallel &&
                  cross(target.unitVector, wall.unitVector).abs() < 1e-5)) {
            continue;
          }
          final axisDistance = dot(
            target.centerStart - point,
            support.unitVector,
          );
          if (axisDistance.abs() < target.thickness / 2 - 1e-8) continue;
          final side = axisDistance.sign.toInt();
          final direction = support.unitVector * side.toDouble();

          // 3. Visual start: pick wall face edge facing target (furthest along direction)
          Offset visualStart = point;
          if (inter1 != null && inter2 != null) {
            final along1 = dot(inter1 - point, direction);
            final along2 = dot(inter2 - point, direction);
            visualStart = along1 >= along2 ? inter1 : inter2;
          } else if (inter1 != null) {
            visualStart = inter1;
          } else if (inter2 != null) {
            visualStart = inter2;
          }

          // 4. Target faces (inner and outer edges of target meeting support face)
          final tOffset = dot(target.centerOffset, target.normalVector);
          final targetFace1Start =
              target.startPoint +
              target.normalVector * (tOffset + target.thickness / 2);
          final targetFace1End =
              target.endPoint +
              target.normalVector * (tOffset + target.thickness / 2);
          final targetFace2Start =
              target.startPoint +
              target.normalVector * (tOffset - target.thickness / 2);
          final targetFace2End =
              target.endPoint +
              target.normalVector * (tOffset - target.thickness / 2);

          final tInter1 = ArchitectWallNetwork.intersection(
            supportFaceStart,
            supportFaceEnd,
            targetFace1Start,
            targetFace1End,
          );
          final tInter2 = ArchitectWallNetwork.intersection(
            supportFaceStart,
            supportFaceEnd,
            targetFace2Start,
            targetFace2End,
          );

          Offset visualEnd =
              point +
              direction *
                  math.max(0.0, axisDistance.abs() - target.thickness / 2);
          if (tInter1 != null && tInter2 != null) {
            final along1 = dot(tInter1 - point, direction);
            final along2 = dot(tInter2 - point, direction);
            visualEnd = along1 <= along2 ? tInter1 : tInter2;
          } else if (tInter1 != null) {
            visualEnd = tInter1;
          } else if (tInter2 != null) {
            visualEnd = tInter2;
          }

          final rawClearance = dot(visualEnd - visualStart, direction);
          if (rawClearance < -1e-5) continue;
          final clearDistance = math.max(0.0, rawClearance);

          final station = dot(visualEnd - target.centerStart, target.unitVector);
          if (station < -target.thickness / 2 - .01 ||
              station > target.length + target.thickness / 2 + .01) {
            continue;
          }

          if (bestBySide[side] != null &&
              bestBySide[side]!.distance <= clearDistance) {
            continue;
          }
          bestBySide[side] = ArchitectWallClearance(
            wallId: wall.id,
            neighborId: target.id,
            side: side,
            distance: clearDistance,
            start: visualStart,
            end: visualEnd,
            atStart: atStart,
            supportId: support.id,
          );
        }
      }
      result.addAll(bestBySide.values);
    }
    return result;
  }

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
