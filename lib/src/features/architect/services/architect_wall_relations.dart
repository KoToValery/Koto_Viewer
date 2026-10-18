// === SECTION: TABLE OF CONTENTS ===
// 1. WALL CLEARANCES (ArchitectWallClearance)
// 2. WALL TRIM SPANS (ArchitectWallTrimSpan)
// 3. HOSTED OPENING CLEARANCES & MODULAR MASONRY PLACEMENT (ArchitectOpeningClearance, ArchitectOpeningPlacement)

import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../rendering/architect_wall_network.dart';

// === SECTION: WALL CLEARANCES ===
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
    if(wall.isCurved)return const [];
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
    if(wall.isCurved)return const [];
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final nearest = <int, ArchitectWallClearance>{};
    final origin = wall.centerStart, u = wall.unitVector, n = wall.normalVector;
    for (final other in walls) {
      if (other.isCurved || other.id == wall.id ||
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

// === SECTION: WALL TRIM SPANS ===
class ArchitectWallTrimSpan {
  final ArchitectWall wall;
  final double from, to;
  const ArchitectWallTrimSpan(this.wall, this.from, this.to);
  Offset get start =>
      wall.isCurved?wall.referencePointAt(from):wall.coreCenterStart + wall.unitVector * (from * wall.length);
  Offset get end => wall.isCurved?wall.referencePointAt(to):wall.coreCenterStart + wall.unitVector * (to * wall.length);

  /// The picked interval is bounded by real wall crossings or wall ends.
  static ArchitectWallTrimSpan at(
    ArchitectWall wall,
    List<ArchitectWall> walls,
    Offset pick,
  ) {
    final cuts = <double>[0, 1];
    for (final other in walls) {
      if (other.id == wall.id) continue;
      if(wall.isCurved||other.isCurved) {
        for(final p in wall.intersections(other)) {
          final ratio=wall.isCurved?wall.arc!.parameter(p):wall.projectPoint(p).$1;
          if(ratio*wall.length>.001&&(1-ratio)*wall.length>.001&&cuts.every((c)=>(c-ratio).abs()>1e-8))cuts.add(ratio);
        }
        continue;
      }
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
    final ratio = wall.isCurved ? wall.arc!.parameter(pick).clamp(0.0,1.0) :
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

// === SECTION: HOSTED OPENING CLEARANCES & MODULAR MASONRY PLACEMENT ===

/// Classification of the physical boundary bounding an opening's masonry pier.
enum ArchitectOpeningBoundaryKind {
  wallStart,
  wallEnd,
  intersectingWall,
  neighborOpening,
}

/// Dynamic clearance readout from a door/window jamb to the nearest opening,
/// intersecting wall core face, or host wall endpoint.
class ArchitectOpeningClearance {
  final String wallId;
  final String openingId;
  final bool isLeft;
  final double distance;
  final Offset start;
  final Offset end;
  final Offset jambPoint;
  final Offset referencePoint;
  final ArchitectOpeningBoundaryKind boundaryKind;
  final String? referenceElementId;
  final bool isModularSnap;

  const ArchitectOpeningClearance({
    required this.wallId,
    required this.openingId,
    required this.isLeft,
    required this.distance,
    required this.start,
    required this.end,
    required this.jambPoint,
    required this.referencePoint,
    required this.boundaryKind,
    this.referenceElementId,
    this.isModularSnap = false,
  });

  Offset get midpoint => (start + end) / 2;
  String get key => '$openingId-${isLeft ? 'left' : 'right'}';

  /// Computes the left and right clearances for an existing or preview opening.
  static List<ArchitectOpeningClearance> forOpening({
    required ArchitectWall wall,
    required List<ArchitectWall> walls,
    required String openingId,
    required double offsetRatio,
    required double openingWidth,
  }) {
    final len = wall.length;
    if (len < 1e-4) return const [];
    final centerAlong = offsetRatio * len;
    final halfW = wall.openingArcSpan(openingWidth) / 2.0;
    final leftJamb = centerAlong - halfW;
    final rightJamb = centerAlong + halfW;

    final span = ArchitectOpeningPlacement.findFreeSpan(
      wall: wall,
      walls: walls,
      targetAlong: centerAlong,
      openingWidth: openingWidth,
      excludeOpeningId: openingId,
    );
    final leftStation = span?.leftStation ?? 0.0;
    final rightStation = span?.rightStation ?? len;
    final leftKind = span?.leftKind ?? ArchitectOpeningBoundaryKind.wallStart;
    final rightKind = span?.rightKind ?? ArchitectOpeningBoundaryKind.wallEnd;
    final leftRefId = span?.leftRefId ?? wall.id;
    final rightRefId = span?.rightRefId ?? wall.id;

    final leftDist = math.max(0.0, leftJamb - leftStation);
    final rightDist = math.max(0.0, rightStation - rightJamb);
    final step = ArchitectOpeningPlacement.modularStepForWall(wall);

    bool isModular(double d) =>
        d > 1e-4 && (d / step - (d / step).round()).abs() < 1e-3;

    Offset at(double station,double extra) {
      final r=station/len;
      return wall.centerPointAt(r)+wall.normalAt(r)*wall.exteriorSign*(wall.thickness/2+extra);
    }
    final leftRefPt=at(leftStation,0),leftJambPt=at(leftJamb,0),leftStart=at(leftStation,.22),leftEnd=at(leftJamb,.22);
    final rightRefPt=at(rightStation,0),rightJambPt=at(rightJamb,0),rightStart=at(rightJamb,.22),rightEnd=at(rightStation,.22);

    return [
      ArchitectOpeningClearance(
        wallId: wall.id,
        openingId: openingId,
        isLeft: true,
        distance: leftDist,
        start: leftStart,
        end: leftEnd,
        jambPoint: leftJambPt,
        referencePoint: leftRefPt,
        boundaryKind: leftKind,
        referenceElementId: leftRefId,
        isModularSnap: isModular(leftDist),
      ),
      ArchitectOpeningClearance(
        wallId: wall.id,
        openingId: openingId,
        isLeft: false,
        distance: rightDist,
        start: rightStart,
        end: rightEnd,
        jambPoint: rightJambPt,
        referencePoint: rightRefPt,
        boundaryKind: rightKind,
        referenceElementId: rightRefId,
        isModularSnap: isModular(rightDist),
      ),
    ];
  }
}

class ArchitectOpeningFreeSpan {
  final double leftStation;
  final double rightStation;
  final ArchitectOpeningBoundaryKind leftKind;
  final String? leftRefId;
  final ArchitectOpeningBoundaryKind rightKind;
  final String? rightRefId;

  const ArchitectOpeningFreeSpan({
    required this.leftStation,
    required this.rightStation,
    required this.leftKind,
    this.leftRefId,
    required this.rightKind,
    this.rightRefId,
  });

  double get length => rightStation - leftStation;
}

class ArchitectOpeningPlacementResult {
  final ArchitectWall wall;
  final double offsetRatio;
  final double leftStation;
  final double rightStation;
  final double stepMeters;
  final bool isModularSnap;
  final String? snapLabel;
  final List<ArchitectOpeningClearance> clearances;
  final bool openInward;
  final bool isHingeLeft;

  const ArchitectOpeningPlacementResult({
    required this.wall,
    required this.offsetRatio,
    required this.leftStation,
    required this.rightStation,
    required this.stepMeters,
    required this.isModularSnap,
    this.snapLabel,
    required this.clearances,
    this.openInward = true,
    this.isHingeLeft = true,
  });

  Offset get centerPoint =>
      wall.centerPointAt(offsetRatio);
}

/// Constructive masonry placement and snapping engine for hosted doors & windows.
class ArchitectOpeningPlacement {
  /// Returns the constructive masonry module step for [wall] (based on its core thickness).
  static double modularStepForWall(ArchitectWall wall) {
    final core = wall.coreThickness;
    if (core <= 0.01) return 0.25;
    return core;
  }

  /// Collects all free spans along [wall] not occupied by other openings or intersecting wall cores.
  static List<ArchitectOpeningFreeSpan> freeSpansForWall({
    required ArchitectWall wall,
    required List<ArchitectWall> walls,
    String? excludeOpeningId,
  }) {
    final len = wall.length;
    if (len < 1e-4) return const [];
    final u = wall.unitVector;

    final obstacles = <({
      double start,
      double end,
      ArchitectOpeningBoundaryKind kind,
      String id,
    })>[];

    // 1. Hosted doors & windows on the same wall
    for (final d in wall.doors) {
      if (d.id == excludeOpeningId) continue;
      final c = d.offsetRatio * len;
      final s = (c - wall.openingArcSpan(d.width) / 2.0).clamp(0.0, len);
      final e = (c + wall.openingArcSpan(d.width) / 2.0).clamp(0.0, len);
      if (e > s + 1e-5) {
        obstacles.add((
          start: s,
          end: e,
          kind: ArchitectOpeningBoundaryKind.neighborOpening,
          id: d.id,
        ));
      }
    }
    for (final w in wall.windows) {
      if (w.id == excludeOpeningId) continue;
      final c = w.offsetRatio * len;
      final s = (c - wall.openingArcSpan(w.width) / 2.0).clamp(0.0, len);
      final e = (c + wall.openingArcSpan(w.width) / 2.0).clamp(0.0, len);
      if (e > s + 1e-5) {
        obstacles.add((
          start: s,
          end: e,
          kind: ArchitectOpeningBoundaryKind.neighborOpening,
          id: w.id,
        ));
      }
    }

    // 2. Intersecting (cross / T-junction / corner) walls
    for (final other in walls) {
      if (other.id == wall.id || other.isDetached) continue;
      if(wall.isCurved||other.isCurved) {
        for(final p in wall.intersections(other)) {
          final ratio=wall.isCurved?wall.arc!.parameter(p):wall.projectPoint(p).$1,otherRatio=other.isCurved?other.arc!.parameter(p):other.projectPoint(p).$1;
          final a=wall.tangentAt(ratio),b=other.tangentAt(otherRatio),sin=(a.dx*b.dy-a.dy*b.dx).abs();
          if(sin<.15)continue;
          final station=ratio*len,half=other.coreThickness/2/sin;
          final from=(station-half).clamp(0.0,len),to=(station+half).clamp(0.0,len);
          if(from>.01&&to<len-.01)obstacles.add((start:from,end:to,kind:ArchitectOpeningBoundaryKind.intersectingWall,id:other.id));
        }
        continue;
      }
      final sinTheta =
          (u.dx * other.unitVector.dy - u.dy * other.unitVector.dx).abs();
      if (sinTheta < 0.15) continue;

      final inter = ArchitectWallNetwork.intersection(
        wall.coreCenterStart,
        wall.coreCenterEnd,
        other.coreCenterStart,
        other.coreCenterEnd,
        finite: false,
      );
      if (inter == null) continue;

      final dWall = inter - wall.centerStart;
      final alongWall = dWall.dx * u.dx + dWall.dy * u.dy;
      final dOther = inter - other.coreCenterStart;
      final alongOther =
          dOther.dx * other.unitVector.dx + dOther.dy * other.unitVector.dy;

      final halfWallCore = wall.coreThickness / 2.0;
      final halfOtherCore = other.coreThickness / 2.0;

      if (alongWall < -halfWallCore - 0.02 ||
          alongWall > len + halfWallCore + 0.02 ||
          alongOther < -halfOtherCore - 0.02 ||
          alongOther > other.length + halfOtherCore + 0.02) {
        continue;
      }

      final halfProjected = halfOtherCore / sinTheta;
      final rawStart = alongWall - halfProjected;
      final rawEnd = alongWall + halfProjected;

      // Only treat a corner cross-wall as an internal obstacle if it is a mid-wall
      // junction OR if we want the corner face when the cross-wall crosses the interior.
      // Wait: if rawStart <= 0.005 (corner at startPoint) or rawEnd >= len - 0.005 (corner at endPoint),
      // check if the user connects at start/end vs mid-wall:
      // If a cross-wall intersects in the middle of the wall (rawStart > 0.01 && rawEnd < len - 0.01),
      // it splits the wall at its core faces [rawStart, rawEnd].
      // If it is at the corner (rawStart <= 0.01 or rawEnd >= len - 0.01),
      // we record the intersecting wall at 0.0 or len so boundaryKind is intersectingWall
      // while keeping the full wall length [0, len] available from the wall start/end!
      if (rawStart > 0.01 && rawEnd < len - 0.01) {
        final s = rawStart.clamp(0.0, len);
        final e = rawEnd.clamp(0.0, len);
        if (e > s + 1e-5) {
          obstacles.add((
            start: s,
            end: e,
            kind: ArchitectOpeningBoundaryKind.intersectingWall,
            id: other.id,
          ));
        }
      }
    }

    String? startCrossWallId;
    String? endCrossWallId;
    for (final other in walls) {
      if (other.id == wall.id || other.isDetached) continue;
      final sinTheta =
          (u.dx * other.unitVector.dy - u.dy * other.unitVector.dx).abs();
      if (sinTheta < 0.15) continue;
      if ((other.startPoint - wall.startPoint).distance <=
              other.thickness / 2 + 0.05 ||
          (other.endPoint - wall.startPoint).distance <=
              other.thickness / 2 + 0.05 ||
          other.containsPoint(wall.startPoint, tolerance: 0.05)) {
        startCrossWallId ??= other.id;
      }
      if ((other.startPoint - wall.endPoint).distance <=
              other.thickness / 2 + 0.05 ||
          (other.endPoint - wall.endPoint).distance <=
              other.thickness / 2 + 0.05 ||
          other.containsPoint(wall.endPoint, tolerance: 0.05)) {
        endCrossWallId ??= other.id;
      }
    }

    obstacles.sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping obstacles
    final merged = <({
      double start,
      double end,
      ArchitectOpeningBoundaryKind leftKind,
      String leftId,
      ArchitectOpeningBoundaryKind rightKind,
      String rightId,
    })>[];

    for (final obs in obstacles) {
      if (merged.isEmpty || obs.start > merged.last.end + 1e-5) {
        merged.add((
          start: obs.start,
          end: obs.end,
          leftKind: obs.kind,
          leftId: obs.id,
          rightKind: obs.kind,
          rightId: obs.id,
        ));
      } else {
        final last = merged.removeLast();
        final useNewRight = obs.end >= last.end;
        merged.add((
          start: last.start,
          end: math.max(last.end, obs.end),
          leftKind: last.leftKind,
          leftId: last.leftId,
          rightKind: useNewRight ? obs.kind : last.rightKind,
          rightId: useNewRight ? obs.id : last.rightId,
        ));
      }
    }

    final spans = <ArchitectOpeningFreeSpan>[];
    var cursor = 0.0;
    var cursorKind = startCrossWallId != null
        ? ArchitectOpeningBoundaryKind.intersectingWall
        : ArchitectOpeningBoundaryKind.wallStart;
    var cursorId = startCrossWallId ?? wall.id;

    for (final obs in merged) {
      if (obs.start > cursor + 1e-5) {
        spans.add(
          ArchitectOpeningFreeSpan(
            leftStation: cursor,
            rightStation: obs.start,
            leftKind: cursorKind,
            leftRefId: cursorId,
            rightKind: obs.leftKind,
            rightRefId: obs.leftId,
          ),
        );
      }
      cursor = math.max(cursor, obs.end);
      cursorKind = obs.rightKind;
      cursorId = obs.rightId;
    }

    if (len > cursor + 1e-5) {
      spans.add(
        ArchitectOpeningFreeSpan(
          leftStation: cursor,
          rightStation: len,
          leftKind: cursorKind,
          leftRefId: cursorId,
          rightKind: endCrossWallId != null
              ? ArchitectOpeningBoundaryKind.intersectingWall
              : ArchitectOpeningBoundaryKind.wallEnd,
          rightRefId: endCrossWallId ?? wall.id,
        ),
      );
    }

    return spans;
  }

  /// Finds the best free span on [wall] that can accommodate [openingWidth] near [targetAlong].
  static ArchitectOpeningFreeSpan? findFreeSpan({
    required ArchitectWall wall,
    required List<ArchitectWall> walls,
    required double targetAlong,
    required double openingWidth,
    String? excludeOpeningId,
  }) {
    final spans = freeSpansForWall(
      wall: wall,
      walls: walls,
      excludeOpeningId: excludeOpeningId,
    ).where((s) => s.length >= wall.openingArcSpan(openingWidth) - 1e-5).toList();
    if (spans.isEmpty) return null;

    ArchitectOpeningFreeSpan? best;
    var bestDist = double.infinity;
    final halfW = wall.openingArcSpan(openingWidth) / 2.0;
    for (final s in spans) {
      final minC = s.leftStation + halfW;
      final maxC = math.max(minC, s.rightStation - halfW);
      final clamped = targetAlong.clamp(minC, maxC);
      final d = (targetAlong - clamped).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  /// Resolves the host wall, modular-snapped offsetRatio, and dynamic clearances
  /// for placing or dragging a door or window.
  static ArchitectOpeningPlacementResult? resolve({
    required Offset rawPoint,
    required List<ArchitectWall> walls,
    required double openingWidth,
    String? excludeOpeningId,
    ArchitectWall? fixedHostWall,
    bool magnetic = true,
    bool? defaultHingeLeft,
  }) {
    ArchitectWall? host = fixedHostWall;
    if (host == null) {
      var bestDist = double.infinity;
      for (final wall in walls) {
        if (wall.length < openingWidth - 1e-5) continue;
        final (_, dist) = wall.projectPoint(rawPoint);
        final maxSnapDist = wall.thickness / 2.0 + math.max(openingWidth * 1.5, 1.20);
        if (dist <= maxSnapDist && dist < bestDist) {
          bestDist = dist;
          host = wall;
        }
      }
    }
    if (host == null || host.length < openingWidth - 1e-5) return null;

    final len = host.length;
    final (rawRatio, _) = host.projectPoint(rawPoint);
    final rawAlong = rawRatio.clamp(0.0, 1.0) * len;

    final span = findFreeSpan(
      wall: host,
      walls: walls,
      targetAlong: rawAlong,
      openingWidth: openingWidth,
      excludeOpeningId: excludeOpeningId,
    );
    if (span == null) return null;

    final halfW = host.openingArcSpan(openingWidth) / 2.0;
    final minCenter = span.leftStation + halfW;
    final maxCenter = math.max(minCenter, span.rightStation - halfW);
    var centerAlong = rawAlong.clamp(minCenter, maxCenter);

    final step = modularStepForWall(host);
    var isModularSnap = false;
    String? snapLabel;

    if (magnetic && maxCenter > minCenter + 1e-5) {
      final rawLeft = centerAlong - halfW - span.leftStation;
      final rawRight = span.rightStation - (centerAlong + halfW);
      final maxClearance = span.length - host.openingArcSpan(openingWidth);

      // Determine whether to measure modular steps from the left reference or right reference:
      // If one side is an existing opening (or mid-wall intersection) and the other is a wall end,
      // prefer the existing opening reference unless the cursor is close to the opposite end.
      final bool preferLeft;
      if (span.leftKind == ArchitectOpeningBoundaryKind.neighborOpening &&
          span.rightKind != ArchitectOpeningBoundaryKind.neighborOpening) {
        preferLeft = rawRight > step * 1.5 || rawLeft <= rawRight;
      } else if (span.rightKind ==
              ArchitectOpeningBoundaryKind.neighborOpening &&
          span.leftKind != ArchitectOpeningBoundaryKind.neighborOpening) {
        preferLeft = rawLeft <= step * 1.5 && rawLeft < rawRight;
      } else {
        preferLeft = rawLeft <= rawRight;
      }

      // Check if cursor is very close to exact midpoint of the free span
      final midCenter = (span.leftStation + span.rightStation) / 2.0;
      if ((centerAlong - midCenter).abs() <= math.min(0.04, step * 0.15)) {
        centerAlong = midCenter;
        snapLabel = 'Midpoint';
      } else if (preferLeft) {
        var snappedLeft = (rawLeft / step).round() * step;
        if (snappedLeft > maxClearance + 1e-6) {
          snappedLeft = (maxClearance / step).floor() * step;
        }
        snappedLeft = snappedLeft.clamp(0.0, maxClearance);
        centerAlong = span.leftStation + halfW + snappedLeft;
        isModularSnap = true;
        snapLabel = '${(snappedLeft * 100).round()} cm';
      } else {
        var snappedRight = (rawRight / step).round() * step;
        if (snappedRight > maxClearance + 1e-6) {
          snappedRight = (maxClearance / step).floor() * step;
        }
        snappedRight = snappedRight.clamp(0.0, maxClearance);
        centerAlong = span.rightStation - halfW - snappedRight;
        isModularSnap = true;
        snapLabel = '${(snappedRight * 100).round()} cm';
      }
    }

    final ratio = (centerAlong / len).clamp(0.0, 1.0);
    final clearances = ArchitectOpeningClearance.forOpening(
      wall: host,
      walls: walls,
      openingId: excludeOpeningId ?? 'preview',
      offsetRatio: ratio,
      openingWidth: openingWidth,
    );

    final toCursor = rawPoint - host.centerPointAt(ratio);
    final normalDot =
        toCursor.dx * host.normalAt(ratio).dx + toCursor.dy * host.normalAt(ratio).dy;
    final openInward = normalDot.abs() < 1e-3 ? true : normalDot >= 0;

    final alongDot =
        toCursor.dx * host.tangentAt(ratio).dx + toCursor.dy * host.tangentAt(ratio).dy;
    final isHingeLeft = alongDot.abs() > 0.03
        ? alongDot < 0
        : (defaultHingeLeft ?? true);

    return ArchitectOpeningPlacementResult(
      wall: host,
      offsetRatio: ratio,
      leftStation: span.leftStation,
      rightStation: span.rightStation,
      stepMeters: step,
      isModularSnap: isModularSnap,
      snapLabel: snapLabel,
      clearances: clearances,
      openInward: openInward,
      isHingeLeft: isHingeLeft,
    );
  }
}

