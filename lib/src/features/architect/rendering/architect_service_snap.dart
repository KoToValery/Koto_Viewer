// === SECTION: ARCHITECT SERVICE SNAP ENGINE ===

import 'dart:math' as math;
import 'dart:ui';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_snap_helper.dart';
import 'architect_midpoint_tracking.dart';

/// Snapping engine for MEP risers, shafts, and chimneys.
/// Snaps flush against wall faces, wall corners/endpoints, and door/window jambs,
/// automatically aligning the riser orientation to the host wall.
class ArchitectServiceSnap {
  ArchitectServiceSnap._();

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
    final referenceWalls = floor.walls.isNotEmpty
        ? floor.walls
        : (activeIdx > 0 ? project.storeys[activeIdx - 1].walls : floor.walls);

    ArchitectSnapResult? bestCornerSnap;
    double bestCornerDist = tolerance;

    ArchitectSnapResult? bestJambSnap;
    double bestJambDist = tolerance;

    ArchitectSnapResult? bestFaceSnap;
    double bestFaceDist = tolerance;

    // Helper to generate orientations
    List<({double rot, double halfAlong, double halfAcross})> getOrientations(
      double wallAngleDeg,
    ) {
      return [
        (rot: wallAngleDeg, halfAlong: width / 2.0, halfAcross: depth / 2.0),
        if ((width - depth).abs() > 1e-4)
          (
            rot: (wallAngleDeg + 90.0) % 360.0,
            halfAlong: depth / 2.0,
            halfAcross: width / 2.0,
          ),
      ];
    }

    // -------------------------------------------------------------------------
    // 1. Wall corners & junctions (discrete point snap - high priority)
    // -------------------------------------------------------------------------
    final visitedJunctions = <String>{};

    for (var i = 0; i < referenceWalls.length; i++) {
      final wallA = referenceWalls[i];
      if (excludedIds.contains(wallA.id) || wallA.length < 1e-4) continue;

      final ptsA = [wallA.startPoint, wallA.endPoint];

      for (var j = i + 1; j < referenceWalls.length; j++) {
        final wallB = referenceWalls[j];
        if (excludedIds.contains(wallB.id) || wallB.length < 1e-4) continue;

        final ptsB = [wallB.startPoint, wallB.endPoint];

        // Check if wallA and wallB meet at any endpoint
        for (final pA in ptsA) {
          for (final pB in ptsB) {
            final junctionDist = (pA - pB).distance;
            final maxJunctionTol = math.max(wallA.thickness, wallB.thickness) * 1.5;
            if (junctionDist > maxJunctionTol) continue;

            final junctionPt = (pA + pB) / 2.0;
            final key = '${junctionPt.dx.toStringAsFixed(2)}_${junctionPt.dy.toStringAsFixed(2)}';
            if (visitedJunctions.contains(key)) continue;
            visitedJunctions.add(key);

            // Direction vectors moving away from junction into walls
            final farA = (pA == wallA.startPoint) ? wallA.endPoint : wallA.startPoint;
            final farB = (pB == wallB.startPoint) ? wallB.endPoint : wallB.startPoint;
            final vecA = farA - junctionPt;
            final vecB = farB - junctionPt;
            if (vecA.distance < 1e-4 || vecB.distance < 1e-4) continue;

            final uA = vecA / vecA.distance;
            final uB = vecB / vecB.distance;
            final nA = Offset(-uA.dy, uA.dx);
            final nB = Offset(-uB.dy, uB.dx);

            final wallAngleA = (math.atan2(-uA.dy, -uA.dx) * 180.0 / math.pi) % 360.0;
            final orients = getOrientations(wallAngleA);

            // Test line intersection in the corner quadrants
            final det = uA.dx * uB.dy - uA.dy * uB.dx;
            if (det.abs() > 0.05) {
              for (final orient in orients) {
                for (final sideA in [1.0, -1.0]) {
                  for (final sideB in [1.0, -1.0]) {
                    final pLineA = junctionPt + nA * ((wallA.thickness / 2.0 + orient.halfAcross) * sideA);
                    final pLineB = junctionPt + nB * ((wallB.thickness / 2.0 + orient.halfAlong) * sideB);
                    final diff = pLineB - pLineA;
                    final t = (diff.dx * uB.dy - diff.dy * uB.dx) / det;
                    final cornerCandidate = pLineA + uA * t;

                    final dist = (cornerCandidate - raw).distance;
                    if (dist < bestCornerDist) {
                      bestCornerDist = dist;
                      bestCornerSnap = ArchitectSnapResult(
                        point: cornerCandidate,
                        isSnapped: true,
                        snapLabel: 'Wall corner',
                        angleDeg: orient.rot,
                        magneticGuides: [
                          (pLineA - uA * 1.5, pLineA + uA * 1.5),
                          (pLineB - uB * 1.5, pLineB + uB * 1.5),
                        ],
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Standalone wall endpoints (not part of a corner)
      for (final endPt in ptsA) {
        final farPt = (endPt == wallA.startPoint) ? wallA.endPoint : wallA.startPoint;
        final dir = (farPt - endPt).normalized();
        final norm = Offset(-dir.dy, dir.dx);
        final wallAngle = (math.atan2(-dir.dy, -dir.dx) * 180.0 / math.pi) % 360.0;
        final orients = getOrientations(wallAngle);

        for (final orient in orients) {
          final candidatePoints = [
            endPt + dir * orient.halfAlong + norm * (wallA.thickness / 2.0 + orient.halfAcross),
            endPt + dir * orient.halfAlong - norm * (wallA.thickness / 2.0 + orient.halfAcross),
            endPt - dir * orient.halfAlong + norm * (wallA.thickness / 2.0 + orient.halfAcross),
            endPt - dir * orient.halfAlong - norm * (wallA.thickness / 2.0 + orient.halfAcross),
          ];

          for (final cp in candidatePoints) {
            final dist = (cp - raw).distance;
            if (dist < bestCornerDist) {
              bestCornerDist = dist;
              bestCornerSnap = ArchitectSnapResult(
                point: cp,
                isSnapped: true,
                snapLabel: 'Wall corner',
                angleDeg: orient.rot,
              );
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. Door & window opening jambs (discrete point snap - high priority)
    // -------------------------------------------------------------------------
    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id) || wall.length < 1e-4) continue;

      final wallLen = wall.length;
      for (final opening in [
        for (final d in wall.doors) (d.id, d.offsetRatio, d.width, true),
        for (final w in wall.windows) (w.id, w.offsetRatio, w.width, false),
      ]) {
        if (excludedIds.contains(opening.$1)) continue;

        final ratio = opening.$2;
        final openWidth = opening.$3;
        final isDoor = opening.$4;
        final snapLabel = 'Opening jamb';

        final center = wall.centerPointAt(ratio);
        final tangent = wall.tangentAt(ratio);
        final normal = wall.normalAt(ratio);
        final halfOpen = openWidth / 2.0;

        final leftJamb = center - tangent * halfOpen;
        final rightJamb = center + tangent * halfOpen;
        final wallAngleDeg = (math.atan2(tangent.dy, tangent.dx) * 180.0 / math.pi) % 360.0;
        final orients = getOrientations(wallAngleDeg);

        for (final orient in orients) {
          final sideOffsets = <double>[
            wall.thickness / 2.0 + orient.halfAcross,
            -(wall.thickness / 2.0 + orient.halfAcross),
            0.0,
          ];

          for (final acrossOff in sideOffsets) {
            final acrossVec = normal * acrossOff;

            // Left jamb snap
            final pLeft = leftJamb - tangent * orient.halfAlong + acrossVec;
            final dLeft = (pLeft - raw).distance;
            if (dLeft < bestJambDist) {
              bestJambDist = dLeft;
              bestJambSnap = ArchitectSnapResult(
                point: pLeft,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (leftJamb - normal * (wall.thickness * 1.5), leftJamb + normal * (wall.thickness * 1.5)),
                  (center - tangent * (openWidth + 1.2), center + tangent * (openWidth + 1.2)),
                ],
              );
            }

            // Right jamb snap
            final pRight = rightJamb + tangent * orient.halfAlong + acrossVec;
            final dRight = (pRight - raw).distance;
            if (dRight < bestJambDist) {
              bestJambDist = dRight;
              bestJambSnap = ArchitectSnapResult(
                point: pRight,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (rightJamb - normal * (wall.thickness * 1.5), rightJamb + normal * (wall.thickness * 1.5)),
                  (center - tangent * (openWidth + 1.2), center + tangent * (openWidth + 1.2)),
                ],
              );
            }
          }
        }
      }
    }

    // If a discrete corner or jamb snap was found within tolerance, it takes priority!
    if (bestCornerSnap != null || bestJambSnap != null) {
      if (bestCornerSnap != null && bestJambSnap != null) {
        return bestCornerDist <= bestJambDist ? bestCornerSnap : bestJambSnap;
      }
      return bestCornerSnap ?? bestJambSnap!;
    }

    // -------------------------------------------------------------------------
    // 3. Wall faces along wall length (continuous edge snap)
    // -------------------------------------------------------------------------
    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id) || wall.length < 1e-4) continue;

      final wallLen = wall.length;
      final p1 = wall.startPoint;
      final p2 = wall.endPoint;
      final lineVec = p2 - p1;
      final u = lineVec / wallLen;
      final toPt = raw - p1;
      final projDist = toPt.dx * u.dx + toPt.dy * u.dy;
      final n = Offset(-u.dy, u.dx);
      final wallAngleDeg = (math.atan2(lineVec.dy, lineVec.dx) * 180.0 / math.pi) % 360.0;
      final orients = getOrientations(wallAngleDeg);

      if (projDist >= -tolerance && projDist <= wallLen + tolerance) {
        final clampedProj = projDist.clamp(0.0, wallLen);
        final baseProj = p1 + u * clampedProj;
        final side = (toPt.dx * n.dx + toPt.dy * n.dy) >= 0 ? 1.0 : -1.0;

        for (final orient in orients) {
          final candidateOffsets = <double>[
            (wall.thickness / 2.0 + orient.halfAcross) * side,
            if (wall.thickness >= orient.halfAcross * 2.0)
              (wall.thickness / 2.0 - orient.halfAcross) * side,
            0.0,
          ];

          for (final off in candidateOffsets) {
            final targetPoint = baseProj + n * off;
            final dist = (targetPoint - raw).distance;
            if (dist < bestFaceDist) {
              bestFaceDist = dist;
              final guideStart = p1 + n * off;
              final guideEnd = p2 + n * off;
              bestFaceSnap = ArchitectSnapResult(
                point: targetPoint,
                isSnapped: true,
                snapLabel: 'Wall face',
                angleDeg: orient.rot,
                magneticGuides: [(guideStart, guideEnd)],
              );
            }
          }
        }
      }
    }

    if (bestFaceSnap != null) {
      return bestFaceSnap;
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
