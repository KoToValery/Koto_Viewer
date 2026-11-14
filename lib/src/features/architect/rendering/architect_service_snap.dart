import 'dart:math' as math;
import 'dart:ui';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_midpoint_tracking.dart';
import 'architect_snap_helper.dart';
import 'architect_wall_geometry.dart';

/// Snapping engine for MEP risers, shafts, and chimneys.
/// Snaps flush against wall faces, wall corners/endpoints, and door/window jambs,
/// automatically aligning the riser orientation to the host wall.
class ArchitectServiceSnap {
  const ArchitectServiceSnap._();

  static double _faceRotationDeg(Offset faceNormal) {
    final deg =
        (math.atan2(-faceNormal.dx, faceNormal.dy) * 180.0 / math.pi) % 360.0;
    return deg.abs() < 1e-6 || (360.0 - deg).abs() < 1e-6 ? 0.0 : deg;
  }

  static double _angleDiffDeg(double a, double b) {
    final diff = ((a - b) % 360.0 + 540.0) % 360.0 - 180.0;
    return diff.abs();
  }

  static ArchitectSnapResult resolve({
    required Offset raw,
    required ArchitectProject project,
    required double width,
    required double depth,
    double currentRotationDeg = 0.0,
    double tolerance = 0.35,
    bool magnetic = true,
    Set<String> excludedIds = const {},
    List<ArchitectMidpointReference> midpointReferences = const [],
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (!magnetic || tolerance <= 0) {
      return ArchitectSnapResult(
        point: ArchitectSnapHelper.precision(project).inputPoint(raw),
      );
    }

    final floor = project.activeStorey;
    final activeIdx = project.storeys.indexWhere((s) => s.id == floor.id);
    final rawWalls = floor.walls.isNotEmpty
        ? floor.walls
        : (activeIdx > 0 ? project.storeys[activeIdx - 1].walls : floor.walls);
    final referenceWalls = ArchitectWallGeometry.coreWalls(rawWalls);

    var bestScoreDist = double.infinity;
    var bestOriginDist = double.infinity;
    var bestAngleDiff = double.infinity;
    ArchitectSnapResult? bestSnap;

    void resetBest() {
      bestScoreDist = double.infinity;
      bestOriginDist = double.infinity;
      bestAngleDiff = double.infinity;
      bestSnap = null;
    }

    void considerCandidate({
      required Offset faceOrigin,
      required Offset faceNormal,
      required String label,
      List<(Offset, Offset)> guides = const [],
    }) {
      final normLen = faceNormal.distance;
      if (normLen < 1e-6) return;
      final n = faceNormal / normLen;
      final visualCenter = faceOrigin + n * (depth / 2.0);
      final originDist = (raw - faceOrigin).distance;
      final centerDist = (raw - visualCenter).distance;
      final scoreDist = math.min(originDist, centerDist);
      final angleDeg = _faceRotationDeg(n);
      final angleDiff = _angleDiffDeg(angleDeg, currentRotationDeg);

      final isBetter =
          scoreDist < bestScoreDist - 1e-4 ||
          ((scoreDist - bestScoreDist).abs() <= 1e-4 &&
              (originDist < bestOriginDist - 1e-4 ||
                  ((originDist - bestOriginDist).abs() <= 1e-4 &&
                      angleDiff < bestAngleDiff - 1e-4)));
      if (!isBetter) return;

      bestScoreDist = scoreDist;
      bestOriginDist = originDist;
      bestAngleDiff = angleDiff;
      bestSnap = ArchitectSnapResult(
        point: faceOrigin,
        isSnapped: true,
        snapLabel: label,
        angleDeg: angleDeg,
        magneticGuides: guides,
      );
    }

    void considerCornerSide(
      ArchitectWall backWall,
      Offset uBack,
      Offset nBack,
      ArchitectWall sideWall,
      Offset uAdj,
      Offset nAdj,
      Offset junctionPt,
    ) {
      final denom = uBack.dx * uAdj.dy - uBack.dy * uAdj.dx;
      if (denom.abs() <= 0.1) return;
      final maxReach =
          (width + depth + backWall.thickness + sideWall.thickness) * 2.0;

      for (final sideBack in const [1.0, -1.0]) {
        final backNorm = nBack * sideBack;
        final pBackLine =
            junctionPt + backNorm * (backWall.thickness / 2.0 + depth / 2.0);
        for (final sideAdj in const [1.0, -1.0]) {
          final adjNorm = nAdj * sideAdj;
          final pAdjLine =
              junctionPt + adjNorm * (sideWall.thickness / 2.0 + width / 2.0);
          final dP = pAdjLine - pBackLine;
          final t = (dP.dx * uAdj.dy - dP.dy * uAdj.dx) / denom;
          final visualCenter = pBackLine + uBack * t;
          if ((visualCenter - junctionPt).distance > maxReach) continue;

          considerCandidate(
            faceOrigin: visualCenter - backNorm * (depth / 2.0),
            faceNormal: backNorm,
            label: 'Wall corner',
            guides: [
              (pBackLine - uBack * 1.5, pBackLine + uBack * 1.5),
              (pAdjLine - uAdj * 1.5, pAdjLine + uAdj * 1.5),
            ],
          );
        }
      }
    }

    // 1. Wall corners & endpoints (discrete point snap - high priority)
    final cornerRadius = math.min(0.45, tolerance * 1.4);
    for (var i = 0; i < referenceWalls.length; i++) {
      final wallA = referenceWalls[i];
      if (excludedIds.contains(wallA.id) ||
          wallA.length < 1e-4 ||
          wallA.isCurved) {
        continue;
      }
      final uA = (wallA.endPoint - wallA.startPoint).normalized();
      final nA = Offset(-uA.dy, uA.dx);
      final ptsA = [wallA.startPoint, wallA.endPoint];
      final junctionFlags = [false, false];

      for (var j = 0; j < referenceWalls.length; j++) {
        if (i == j) continue;
        final wallB = referenceWalls[j];
        if (excludedIds.contains(wallB.id) ||
            wallB.length < 1e-4 ||
            wallB.isCurved) {
          continue;
        }
        final uB = (wallB.endPoint - wallB.startPoint).normalized();
        final nB = Offset(-uB.dy, uB.dx);
        final ptsB = [wallB.startPoint, wallB.endPoint];

        for (var aIdx = 0; aIdx < 2; aIdx++) {
          for (var bIdx = 0; bIdx < 2; bIdx++) {
            if ((ptsA[aIdx] - ptsB[bIdx]).distance <= 0.15) {
              junctionFlags[aIdx] = true;
              if (i < j) {
                final junctionPt = ptsA[aIdx];
                considerCornerSide(wallA, uA, nA, wallB, uB, nB, junctionPt);
                considerCornerSide(wallB, uB, nB, wallA, uA, nA, junctionPt);
              }
            }
          }
        }
      }

      // Standalone wall endpoints (not part of a corner junction)
      for (var idx = 0; idx < 2; idx++) {
        if (junctionFlags[idx]) continue;
        final endPt = ptsA[idx];
        final farPt = idx == 0 ? wallA.endPoint : wallA.startPoint;
        final dir = (farPt - endPt).normalized();
        if (dir.distance < 1e-6) continue;
        final norm = Offset(-dir.dy, dir.dx);
        for (final side in const [1.0, -1.0]) {
          final faceNormal = norm * side;
          considerCandidate(
            faceOrigin:
                endPt + dir * (width / 2.0) + faceNormal * (wallA.thickness / 2.0),
            faceNormal: faceNormal,
            label: 'Wall corner',
          );
        }
        considerCandidate(
          faceOrigin: endPt,
          faceNormal: -dir,
          label: 'Wall corner',
        );
      }
    }

    if (bestSnap != null && bestScoreDist <= cornerRadius) {
      return bestSnap!;
    }

    // 2. Door & window opening jambs (discrete point snap - high priority)
    resetBest();
    final jambRadius = math.min(0.45, tolerance * 1.3);
    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id) || wall.length < 1e-4) continue;
      final openings = <(String, double, double)>[
        for (final d in wall.doors) (d.id, d.offsetRatio, d.width),
        for (final w in wall.windows) (w.id, w.offsetRatio, w.width),
      ];

      for (final opening in openings) {
        final ratio = opening.$2;
        final openWidth = opening.$3;
        final center = wall.centerPointAt(ratio);
        final tangent = wall.tangentAt(ratio);
        final normal = wall.normalAt(ratio);
        final halfOpen = openWidth / 2.0;

        final leftJamb = center - tangent * halfOpen;
        final rightJamb = center + tangent * halfOpen;
        final guideExt = normal * (wall.thickness * 1.5);

        for (final side in const [1.0, -1.0]) {
          final faceNormal = normal * side;
          final faceShift = faceNormal * (wall.thickness / 2.0);
          considerCandidate(
            faceOrigin: leftJamb - tangent * (width / 2.0) + faceShift,
            faceNormal: faceNormal,
            label: 'Opening jamb',
            guides: [(leftJamb - guideExt, leftJamb + guideExt)],
          );
          considerCandidate(
            faceOrigin: rightJamb + tangent * (width / 2.0) + faceShift,
            faceNormal: faceNormal,
            label: 'Opening jamb',
            guides: [(rightJamb - guideExt, rightJamb + guideExt)],
          );
        }
      }
    }

    if (bestSnap != null && bestScoreDist <= jambRadius) {
      return bestSnap!;
    }

    // 3. Wall faces along wall length (continuous edge snap)
    resetBest();
    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id) || wall.length < 1e-4) continue;

      final (rawRatio, _) = wall.projectPoint(raw);
      final ratio = rawRatio.clamp(0.0, 1.0);
      final baseProj = wall.centerPointAt(ratio);
      final n = wall.normalAt(ratio);
      final toRaw = raw - baseProj;
      final signedPerp = toRaw.dx * n.dx + toRaw.dy * n.dy;
      final side = signedPerp >= 0 ? 1.0 : -1.0;
      final faceNormal = n * side;
      final halfThick = wall.thickness / 2.0;
      final faceOrigin = baseProj + faceNormal * halfThick;
      final centerGuideOffset = faceNormal * (halfThick + depth / 2.0);

      considerCandidate(
        faceOrigin: faceOrigin,
        faceNormal: faceNormal,
        label: 'Wall face',
        guides: wall.isCurved
            ? const []
            : [
                (
                  wall.centerStart + centerGuideOffset,
                  wall.centerEnd + centerGuideOffset,
                ),
              ],
      );
    }

    if (bestSnap != null && bestScoreDist <= tolerance) {
      return bestSnap!;
    }

    // Fallback to standard drawing snaps
    return ArchitectSnapHelper.snapFree(
      rawPoint: raw,
      project: project,
      tolerance: tolerance,
      magnetic: magnetic,
      alignment: true,
      excludedIds: excludedIds,
      midpointReferences: midpointReferences,
      underlay: underlay,
      frame: frame,
      visibility: visibility,
    );
  }
}

extension on Offset {
  Offset normalized() {
    final d = distance;
    if (d < 1e-8) return Offset.zero;
    return this / d;
  }
}
