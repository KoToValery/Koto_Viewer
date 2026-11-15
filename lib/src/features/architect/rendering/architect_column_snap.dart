// === SECTION: TABLE OF CONTENTS ===
// 1. COLUMN SNAP RESULT & HELPERS
// 2. ARCHITECT COLUMN SNAP ENGINE

import 'dart:math' as math;
import 'dart:ui';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_snap_helper.dart';
import 'architect_midpoint_tracking.dart';
import 'architect_snap_geometry.dart';
import 'architect_wall_geometry.dart';

// === SECTION: ARCHITECT COLUMN SNAP ENGINE ===

/// Specialized snapping engine for architectural and structural columns.
/// Provides precise flush attachment to door and window jambs (along and across walls),
/// automatic element rotation alignment to host walls, and falls back to general snaps.
class ArchitectColumnSnap {
  ArchitectColumnSnap._();

  /// Resolves the snapped target position, wall-aligned rotation, and magnetic guides
  /// for placing or translating a column.
  static ArchitectSnapResult resolve({
    required Offset raw,
    required ArchitectProject project,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
    double currentRotationDeg = 0.0,
    double tolerance = 0.25,
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

    ArchitectSnapResult? bestOpeningSnap;
    double bestDist = tolerance;

    final floor = project.activeStorey;
    final activeIdx = project.storeys.indexWhere((s) => s.id == floor.id);
    final rawWalls = floor.walls.isNotEmpty
        ? floor.walls
        : (activeIdx > 0 ? project.storeys[activeIdx - 1].walls : floor.walls);
    final referenceWalls = ArchitectWallGeometry.coreWalls(rawWalls);

    for (final wall in referenceWalls) {
      if (excludedIds.contains(wall.id)) continue;
      final wallLen = wall.length;
      if (wallLen < 1e-4) continue;

      for (final opening in [
        for (final d in wall.doors) (d.id, d.offsetRatio, d.width, true),
        for (final w in wall.windows) (w.id, w.offsetRatio, w.width, false),
      ]) {
        if (excludedIds.contains(opening.$1)) continue;

        final ratio = opening.$2;
        final openWidth = opening.$3;
        final isDoor = opening.$4;
        final snapLabel = isDoor ? 'Door jamb' : 'Window jamb';

        final center = wall.centerPointAt(ratio);
        final tangent = wall.tangentAt(ratio);
        final normal = wall.normalAt(ratio);

        final halfOpen = openWidth / 2.0;
        final leftJamb = wall.isCurved
            ? wall.centerPointAt(
                ((ratio * wallLen - halfOpen) / wallLen).clamp(0.0, 1.0),
              )
            : center - tangent * halfOpen;
        final rightJamb = wall.isCurved
            ? wall.centerPointAt(
                ((ratio * wallLen + halfOpen) / wallLen).clamp(0.0, 1.0),
              )
            : center + tangent * halfOpen;

        final wallAngleDeg =
            (math.atan2(tangent.dy, tangent.dx) * 180.0 / math.pi) % 360.0;

        // Try parallel and (for rectangular with different width/depth) perpendicular orientation
        final orientations =
            <({double rot, double halfAlong, double halfAcross})>[
              (
                rot: wallAngleDeg,
                halfAlong: columnWidth / 2.0,
                halfAcross: columnDepth / 2.0,
              ),
              if (columnShape == ColumnShape.rectangular &&
                  (columnWidth - columnDepth).abs() > 1e-4)
                (
                  rot: (wallAngleDeg + 90.0) % 360.0,
                  halfAlong: columnDepth / 2.0,
                  halfAcross: columnWidth / 2.0,
                ),
            ];

        for (final orient in orientations) {
          final acrossOffsets = <double>[
            0.0, // Centered on wall core / centerline
            if (wall.thickness > orient.halfAcross * 2.0 + 0.01) ...[
              wall.thickness / 2.0 - orient.halfAcross, // Flush exterior face
              -(wall.thickness / 2.0 -
                  orient.halfAcross), // Flush interior face
            ],
          ];

          for (final acrossOff in acrossOffsets) {
            final acrossVec = normal * acrossOff;

            // 1. Column flush against left jamb (outside opening)
            final pLeft = leftJamb - tangent * orient.halfAlong + acrossVec;
            final dLeft = (pLeft - raw).distance;
            if (dLeft <= bestDist) {
              bestDist = dLeft;
              final jambGuideStart = leftJamb - normal * (wall.thickness * 1.5);
              final jambGuideEnd = leftJamb + normal * (wall.thickness * 1.5);
              final wallGuideStart = center - tangent * (openWidth + 1.2);
              final wallGuideEnd = center + tangent * (openWidth + 1.2);
              bestOpeningSnap = ArchitectSnapResult(
                point: pLeft,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (jambGuideStart, jambGuideEnd),
                  (wallGuideStart, wallGuideEnd),
                ],
              );
            }

            // 2. Column flush against right jamb (outside opening)
            final pRight = rightJamb + tangent * orient.halfAlong + acrossVec;
            final dRight = (pRight - raw).distance;
            if (dRight <= bestDist) {
              bestDist = dRight;
              final jambGuideStart =
                  rightJamb - normal * (wall.thickness * 1.5);
              final jambGuideEnd = rightJamb + normal * (wall.thickness * 1.5);
              final wallGuideStart = center - tangent * (openWidth + 1.2);
              final wallGuideEnd = center + tangent * (openWidth + 1.2);
              bestOpeningSnap = ArchitectSnapResult(
                point: pRight,
                isSnapped: true,
                snapLabel: snapLabel,
                angleDeg: orient.rot,
                magneticGuides: [
                  (jambGuideStart, jambGuideEnd),
                  (wallGuideStart, wallGuideEnd),
                ],
              );
            }
          }
        }
      }
    }

    if (bestOpeningSnap != null) {
      return bestOpeningSnap;
    }

    // Tier 1: Wall corners, junctions (L/T/X), and standalone wall endpoints.
    final cornerSnap = _resolveWallCornerSnap(
      raw: raw,
      walls: referenceWalls,
      columnWidth: columnWidth,
      columnDepth: columnDepth,
      columnShape: columnShape,
      currentRotationDeg: currentRotationDeg,
      tolerance: tolerance,
      excludedIds: excludedIds,
    );
    if (cornerSnap != null) {
      return cornerSnap;
    }

    // Tier 2: Continuous wall faces and wall centerlines along straight or curved walls.
    final geometry = ArchitectSnapGeometry.of(project, wallCoresOnly: true);
    final wallFaceSnap = _resolveWallFaceSnap(
      raw: raw,
      walls: referenceWalls,
      geometry: geometry,
      columnWidth: columnWidth,
      columnDepth: columnDepth,
      columnShape: columnShape,
      currentRotationDeg: currentRotationDeg,
      tolerance: tolerance,
      excludedIds: excludedIds,
    );
    if (wallFaceSnap != null) {
      return wallFaceSnap;
    }

    // Tier 3: Center snap (for grid intersections / centers) + virtual column
    // perimeter snap (for slabs, beams, existing columns, and CAD lines).
    return _resolveFeatureFallback(
      raw: raw,
      project: project,
      columnWidth: columnWidth,
      columnDepth: columnDepth,
      columnShape: columnShape,
      currentRotationDeg: currentRotationDeg,
      tolerance: tolerance,
      magnetic: magnetic,
      excludedIds: excludedIds,
      midpointReferences: midpointReferences,
      underlay: underlay,
      frame: frame,
      visibility: visibility,
    );
  }

  static double _uprightAngleDeg(double deg) {
    var a = deg % 360.0;
    if (a < 0) a += 360.0;
    if (a > 90.0 + 1e-4 && a <= 270.0 + 1e-4) {
      a = (a + 180.0) % 360.0;
    }
    return a.abs() < 1e-4 || (a - 360.0).abs() < 1e-4 ? 0.0 : a;
  }

  static double _angleDiff(double a, double b) {
    var d = (a - b) % 180.0;
    if (d < 0) d += 180.0;
    return math.min(d, 180.0 - d);
  }

  static List<({double rot, double halfAlong, double halfAcross})>
      _wallOrientations({
    required Offset tangent,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
  }) {
    if (columnShape == ColumnShape.circular) {
      final r = columnWidth / 2.0;
      return [(rot: 0.0, halfAlong: r, halfAcross: r)];
    }
    final baseDeg = _uprightAngleDeg(
      math.atan2(tangent.dy, tangent.dx) * 180.0 / math.pi,
    );
    return [
      (rot: baseDeg, halfAlong: columnWidth / 2.0, halfAcross: columnDepth / 2.0),
      if ((columnWidth - columnDepth).abs() > 1e-4)
        (
          rot: _uprightAngleDeg(baseDeg + 90.0),
          halfAlong: columnDepth / 2.0,
          halfAcross: columnWidth / 2.0,
        ),
    ];
  }

  static List<Offset> _candidateVertices(
    Offset center,
    double rotDeg,
    double columnWidth,
    double columnDepth,
    ColumnShape shape,
  ) {
    if (shape == ColumnShape.circular) {
      final r = columnWidth / 2.0;
      return [
        center + Offset(r, 0),
        center + Offset(-r, 0),
        center + Offset(0, r),
        center + Offset(0, -r),
      ];
    }
    final rad = rotDeg * math.pi / 180.0;
    final ex = Offset(math.cos(rad), math.sin(rad)) * (columnWidth / 2.0);
    final ey = Offset(-math.sin(rad), math.cos(rad)) * (columnDepth / 2.0);
    return [
      center - ex - ey,
      center + ex - ey,
      center + ex + ey,
      center - ex + ey,
    ];
  }

  static ArchitectSnapResult? _resolveWallCornerSnap({
    required Offset raw,
    required List<ArchitectWall> walls,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
    required double currentRotationDeg,
    required double tolerance,
    required Set<String> excludedIds,
  }) {
    final straight = walls
        .where((w) => !w.isCurved && !excludedIds.contains(w.id) && w.length >= 1e-4)
        .toList();
    if (straight.isEmpty) return null;

    ({
      ArchitectSnapResult result,
      double triggerDist,
      double centerDist,
      int embedPenalty,
      double anglePenalty,
    })? best;

    void considerCandidate({
      required Offset candidate,
      required double rotDeg,
      required List<Offset> triggerVertices,
      required int embedPenalty,
      required List<(Offset, Offset)> guides,
      bool allowMidpointTrigger = false,
    }) {
      final centerDist = (candidate - raw).distance;
      double triggerDist = double.infinity;

      if (centerDist <= tolerance) {
        triggerDist = centerDist;
      }

      if (triggerVertices.isNotEmpty) {
        final colVerts = _candidateVertices(
          candidate,
          rotDeg,
          columnWidth,
          columnDepth,
          columnShape,
        );
        final triggerPoints = allowMidpointTrigger
            ? [
                ...colVerts,
                for (var idx = 0; idx < colVerts.length; idx++)
                  (colVerts[idx] + colVerts[(idx + 1) % colVerts.length]) / 2.0,
              ]
            : colVerts;
        for (final v in triggerVertices) {
          final vDist = (v - raw).distance;
          if (vDist > tolerance) continue;
          final touchesCorner =
              triggerPoints.any((k) => (k - v).distance < 1.5e-2);
          if (!touchesCorner) continue;
          // Prefer candidates extending from v toward the cursor quadrant (or
          // embedded into the corner when the cursor sits directly on v).
          final intoCand = candidate - v;
          final candLen = intoCand.distance;
          final rawRel = raw - v;
          final onCandidateSide = vDist < 1.5e-2 ||
              candLen < 1e-6 ||
              (rawRel.dx * intoCand.dx + rawRel.dy * intoCand.dy) >=
                  -0.02 * candLen;
          if (onCandidateSide && vDist < triggerDist) {
            triggerDist = vDist;
          }
        }
      }

      if (triggerDist > tolerance) return;
      final anglePenalty = columnShape == ColumnShape.circular
          ? 0.0
          : _angleDiff(rotDeg, currentRotationDeg);

      final isBetter = best == null ||
          triggerDist < best!.triggerDist - 5e-3 ||
          ((triggerDist - best!.triggerDist).abs() <= 5e-3 &&
              (embedPenalty < best!.embedPenalty ||
                  (embedPenalty == best!.embedPenalty &&
                      (centerDist < best!.centerDist - 5e-3 ||
                          ((centerDist - best!.centerDist).abs() <= 5e-3 &&
                              anglePenalty < best!.anglePenalty)))));

      if (isBetter) {
        best = (
          result: ArchitectSnapResult(
            point: candidate,
            isSnapped: true,
            snapLabel: 'Wall corner',
            angleDeg: columnShape == ColumnShape.circular ? null : rotDeg,
            magneticGuides: guides,
          ),
          triggerDist: triggerDist,
          centerDist: centerDist,
          embedPenalty: embedPenalty,
          anglePenalty: anglePenalty,
        );
      }
    }

    final junctionPoints = <Offset>[];
    final maxHalfExtent = math.max(columnWidth, columnDepth) / 2.0;

    // 1. Wall-to-wall intersections (L-corners, T-junctions, X-crossings)
    for (var i = 0; i < straight.length; i++) {
      final a = straight[i];
      final uA = a.unitVector;
      final nA = a.normalVector;
      final hA = a.thickness / 2.0;
      for (var j = i + 1; j < straight.length; j++) {
        final b = straight[j];
        final uB = b.unitVector;
        final nB = b.normalVector;
        final hB = b.thickness / 2.0;

        final det = nA.dx * nB.dy - nA.dy * nB.dx;
        if (det.abs() < 1e-4) continue;

        final rhsA = (a.startPoint.dx * nA.dx + a.startPoint.dy * nA.dy);
        final rhsB = (b.startPoint.dx * nB.dx + b.startPoint.dy * nB.dy);
        final p = Offset(
          (rhsA * nB.dy - rhsB * nA.dy) / det,
          (nA.dx * rhsB - nB.dx * rhsA) / det,
        );

        final alongA = (p - a.startPoint).dx * uA.dx + (p - a.startPoint).dy * uA.dy;
        final alongB = (p - b.startPoint).dx * uB.dx + (p - b.startPoint).dy * uB.dy;
        if (alongA < -hB - 0.05 ||
            alongA > a.length + hB + 0.05 ||
            alongB < -hA - 0.05 ||
            alongB > b.length + hA + 0.05) {
          continue;
        }
        junctionPoints.add(p);

        if ((p - raw).distance > tolerance + maxHalfExtent * 2 + hA + hB + 0.1) {
          continue;
        }

        final cornerVertices = <Offset>[
          p,
          for (final sA in const [-1.0, 1.0])
            for (final sB in const [-1.0, 1.0])
              p +
                  Offset(
                    ((sA * hA) * nB.dy - (sB * hB) * nA.dy) / det,
                    (nA.dx * (sB * hB) - nB.dx * (sA * hA)) / det,
                  ),
        ];

        final rotCandidates = <double>{
          for (final o in _wallOrientations(
            tangent: uA,
            columnWidth: columnWidth,
            columnDepth: columnDepth,
            columnShape: columnShape,
          ))
            o.rot,
          if ((uA.dx * uB.dx + uA.dy * uB.dy).abs() > 0.02 &&
              (uA.dx * nB.dx + uA.dy * nB.dy).abs() > 0.02)
            for (final o in _wallOrientations(
              tangent: uB,
              columnWidth: columnWidth,
              columnDepth: columnDepth,
              columnShape: columnShape,
            ))
              o.rot,
        };

        for (final rot in rotCandidates) {
          final double rA;
          final double rB;
          if (columnShape == ColumnShape.circular) {
            rA = columnWidth / 2.0;
            rB = rA;
          } else {
            final rad = rot * math.pi / 180.0;
            final ex = Offset(math.cos(rad), math.sin(rad));
            final ey = Offset(-ex.dy, ex.dx);
            rA = (ex.dx * nA.dx + ex.dy * nA.dy).abs() * (columnWidth / 2.0) +
                (ey.dx * nA.dx + ey.dy * nA.dy).abs() * (columnDepth / 2.0);
            rB = (ex.dx * nB.dx + ex.dy * nB.dy).abs() * (columnWidth / 2.0) +
                (ey.dx * nB.dx + ey.dy * nB.dy).abs() * (columnDepth / 2.0);
          }

          final dAOpts = <(double, int)>[
            (0.0, 0),
            (hA - rA, 0),
            (-(hA - rA), 0),
            (hA + rA, 1),
            (-(hA + rA), 1),
          ];
          final dBOpts = <(double, int)>[
            (0.0, 0),
            (hB - rB, 0),
            (-(hB - rB), 0),
            (hB + rB, 1),
            (-(hB + rB), 1),
          ];

          for (final (dA, penA) in dAOpts) {
            for (final (dB, penB) in dBOpts) {
              final cand =
                  p +
                  Offset(
                    (dA * nB.dy - dB * nA.dy) / det,
                    (nA.dx * dB - nB.dx * dA) / det,
                  );
              considerCandidate(
                candidate: cand,
                rotDeg: rot,
                triggerVertices: cornerVertices,
                embedPenalty: penA + penB,
                guides: [
                  (p - uA * 1.2, p + uA * 1.2),
                  (p - uB * 1.2, p + uB * 1.2),
                ],
              );
            }
          }
        }
      }
    }

    // 2. Standalone wall endpoints (free ends not at a wall junction)
    for (final w in straight) {
      final u = w.unitVector;
      final n = w.normalVector;
      final h = w.thickness / 2.0;
      for (final (endPt, into) in [(w.startPoint, u), (w.endPoint, -u)]) {
        if (junctionPoints.any((jp) => (jp - endPt).distance < 0.08)) continue;
        if ((endPt - raw).distance > tolerance + maxHalfExtent * 2 + h + 0.05) {
          continue;
        }
        final endVertices = <Offset>[endPt, endPt + n * h, endPt - n * h];
        for (final orient in _wallOrientations(
          tangent: u,
          columnWidth: columnWidth,
          columnDepth: columnDepth,
          columnShape: columnShape,
        )) {
          final alongOpts = <(double, int)>[
            (orient.halfAlong, 0),
            (-orient.halfAlong, 1),
          ];
          final acrossOpts = <(double, int)>[
            (0.0, 0),
            (h - orient.halfAcross, 0),
            (-(h - orient.halfAcross), 0),
            (h + orient.halfAcross, 1),
            (-(h + orient.halfAcross), 1),
          ];
          for (final (dAlong, pAlong) in alongOpts) {
            for (final (dAcross, pAcross) in acrossOpts) {
              final cand = endPt + into * dAlong + n * dAcross;
              considerCandidate(
                candidate: cand,
                rotDeg: orient.rot,
                triggerVertices: endVertices,
                embedPenalty: pAlong + pAcross,
                allowMidpointTrigger: true,
                guides: [
                  (endPt - n * (h + 0.6), endPt + n * (h + 0.6)),
                  (endPt - into * 0.6, endPt + into * 1.2),
                ],
              );
            }
          }
        }
      }
    }

    return best?.result;
  }

  static ArchitectSnapResult? _resolveWallFaceSnap({
    required Offset raw,
    required List<ArchitectWall> walls,
    required ArchitectSnapGeometry geometry,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
    required double currentRotationDeg,
    required double tolerance,
    required Set<String> excludedIds,
  }) {
    ({
      ArchitectSnapResult result,
      double triggerDist,
      double centerDist,
      double thicknessFit,
      double anglePenalty,
    })? best;

    for (final wall in walls) {
      if (excludedIds.contains(wall.id)) continue;
      final len = wall.length;
      if (len < 1e-4) continue;

      final Offset axisPt;
      final Offset u;
      final Offset n;
      if (!wall.isCurved) {
        final tangent = wall.unitVector;
        final proj = (raw - wall.startPoint).dx * tangent.dx +
            (raw - wall.startPoint).dy * tangent.dy;
        if (proj < -tolerance || proj > len + tolerance) continue;
        axisPt = wall.startPoint + tangent * proj.clamp(0.0, len);
        u = tangent;
        n = wall.normalVector;
      } else {
        var bestT = 0.0;
        var bestD2 = double.infinity;
        const samples = 20;
        for (var i = 0; i <= samples; i++) {
          final t = i / samples;
          final d2 = (wall.centerPointAt(t) - raw).distanceSquared;
          if (d2 < bestD2) {
            bestD2 = d2;
            bestT = t;
          }
        }
        var lo = math.max(0.0, bestT - 1.0 / samples);
        var hi = math.min(1.0, bestT + 1.0 / samples);
        for (var i = 0; i < 6; i++) {
          final m1 = lo + (hi - lo) / 3.0;
          final m2 = hi - (hi - lo) / 3.0;
          if ((wall.centerPointAt(m1) - raw).distanceSquared <
              (wall.centerPointAt(m2) - raw).distanceSquared) {
            hi = m2;
          } else {
            lo = m1;
          }
        }
        final t = (lo + hi) / 2.0;
        axisPt = wall.centerPointAt(t);
        u = wall.tangentAt(t);
        n = wall.normalAt(t);
      }

      final halfT = wall.thickness / 2.0;
      final signedN = (raw - axisPt).dx * n.dx + (raw - axisPt).dy * n.dy;
      if (signedN.abs() > halfT + math.max(columnWidth, columnDepth) + tolerance) {
        continue;
      }

      for (final orient in _wallOrientations(
        tangent: u,
        columnWidth: columnWidth,
        columnDepth: columnDepth,
        columnShape: columnShape,
      )) {
        final halfAcross = orient.halfAcross;
        final offsets = <(double offset, double faceTrigger)>[
          (0.0, 0.0),
          (halfT - halfAcross, halfT),
          (-(halfT - halfAcross), -halfT),
          (halfT + halfAcross, halfT),
          (-(halfT + halfAcross), -halfT),
        ];

        for (final (off, faceLine) in offsets) {
          final candCenterDist = (signedN - off).abs();
          double triggerDist = candCenterDist <= tolerance
              ? candCenterDist
              : double.infinity;

          if (faceLine.abs() > 1e-6) {
            final faceDist = (signedN - faceLine).abs();
            if (faceDist <= tolerance) {
              final s = faceLine.sign;
              final isOutward = off.abs() > halfT + 1e-4;
              // Outside the wall face line -> snap column flush outside;
              // strictly inside the wall near the face line -> flush inward.
              final sideMatches = isOutward
                  ? (signedN * s >= halfT - 1e-4)
                  : (signedN * s >= halfT * 0.4 && signedN * s < halfT - 1e-4);
              if (sideMatches && faceDist < triggerDist) {
                triggerDist = faceDist;
              }
            }
          }

          if (triggerDist > tolerance) continue;

          var cand = axisPt + n * off;
          final guides = <(Offset, Offset)>[
            (
              axisPt + n * faceLine - u * 1.4,
              axisPt + n * faceLine + u * 1.4,
            ),
          ];

          // While locked onto the wall face, gently align along wall tangent `u`
          // with external alignment points (existing columns, perpendicular walls).
          if (!wall.isCurved) {
            var bestAlongDelta = tolerance * 0.6;
            double? snappedAlong;
            Offset? alignSource;
            for (final ap in geometry.alignmentPoints) {
              if (ap.owner == wall.id || excludedIds.contains(ap.owner)) continue;
              if (!const {'Endpoint', 'Corner', 'Center', 'Quadrant'}.contains(
                ap.label,
              )) {
                continue;
              }
              final deltaAlong =
                  (ap.point - cand).dx * u.dx + (ap.point - cand).dy * u.dy;
              if (deltaAlong.abs() < bestAlongDelta) {
                bestAlongDelta = deltaAlong.abs();
                snappedAlong = deltaAlong;
                alignSource = ap.point;
              }
            }
            if (snappedAlong != null && alignSource != null) {
              cand = cand + u * snappedAlong;
              guides.add((alignSource, cand));
            }
          }

          final thicknessFit = (halfAcross * 2.0 - wall.thickness).abs();
          final anglePenalty = columnShape == ColumnShape.circular
              ? 0.0
              : _angleDiff(orient.rot, currentRotationDeg);

          final isBetter = best == null ||
              triggerDist < best.triggerDist - 5e-3 ||
              ((triggerDist - best.triggerDist).abs() <= 5e-3 &&
                  (thicknessFit < best.thicknessFit - 5e-3 ||
                      ((thicknessFit - best.thicknessFit).abs() <= 5e-3 &&
                          (candCenterDist < best.centerDist - 5e-3 ||
                              ((candCenterDist - best.centerDist).abs() <=
                                      5e-3 &&
                                  anglePenalty < best.anglePenalty)))));

          if (isBetter) {
            best = (
              result: ArchitectSnapResult(
                point: cand,
                isSnapped: true,
                snapLabel: 'Wall face',
                angleDeg:
                    columnShape == ColumnShape.circular ? null : orient.rot,
                magneticGuides: guides,
              ),
              triggerDist: triggerDist,
              centerDist: candCenterDist,
              thicknessFit: thicknessFit,
              anglePenalty: anglePenalty,
            );
          }
        }
      }
    }

    return best?.result;
  }

  static ArchitectSnapResult _resolveFeatureFallback({
    required Offset raw,
    required ArchitectProject project,
    required double columnWidth,
    required double columnDepth,
    required ColumnShape columnShape,
    required double currentRotationDeg,
    required double tolerance,
    required bool magnetic,
    required Set<String> excludedIds,
    required List<ArchitectMidpointReference> midpointReferences,
    required DxfDocument? underlay,
    required BimCoordinateFrame frame,
    required Map<String, bool> visibility,
  }) {
    final centerSnap = ArchitectSnapHelper.snapFree(
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

    if (centerSnap.isSnapped &&
        const {
          'Axis intersection',
          'Intersection',
          'Midpoint',
          'Center',
        }.contains(centerSnap.snapLabel)) {
      return centerSnap;
    }

    final rad = currentRotationDeg * math.pi / 180.0;
    final ex = Offset(math.cos(rad), math.sin(rad));
    final ey = Offset(-ex.dy, ex.dx);
    final halfW = columnWidth / 2.0;
    final halfD =
        (columnShape == ColumnShape.circular ? columnWidth : columnDepth) / 2.0;

    final perimeterPoints = <Offset>[
      if (columnShape == ColumnShape.circular) ...[
        raw + ex * halfW,
        raw - ex * halfW,
        raw + ey * halfW,
        raw - ey * halfW,
      ] else ...[
        raw - ex * halfW - ey * halfD,
        raw + ex * halfW - ey * halfD,
        raw + ex * halfW + ey * halfD,
        raw - ex * halfW + ey * halfD,
        raw + ex * halfW,
        raw - ex * halfW,
        raw + ey * halfD,
        raw - ey * halfD,
      ],
    ];

    ArchitectSnapResult? bestPerim;
    var bestPerimDist = double.infinity;
    var bestPerimRank = 99;
    for (final pt in perimeterPoints) {
      final s = ArchitectSnapHelper.snapFree(
        rawPoint: pt,
        project: project,
        tolerance: tolerance,
        magnetic: magnetic,
        alignment: false,
        excludedIds: excludedIds,
        midpointReferences: midpointReferences,
        underlay: underlay,
        frame: frame,
        visibility: visibility,
      );
      if (!s.isSnapped) continue;
      final label = s.snapLabel ?? '';
      if (label == 'Axis intersection' || label.startsWith('Axis ')) continue;
      final corr = s.point - pt;
      final dist = corr.distance;
      final rank = switch (s.snapLabel) {
        'Corner' || 'Endpoint' || 'Intersection' => 0,
        'Quadrant' || 'Midpoint' => 1,
        'Edge' || 'Perpendicular' => 2,
        _ => 3,
      };
      if (rank < bestPerimRank ||
          (rank == bestPerimRank && dist < bestPerimDist)) {
        bestPerimRank = rank;
        bestPerimDist = dist;
        bestPerim = ArchitectSnapResult(
          point: raw + corr,
          isSnapped: true,
          snapLabel: s.snapLabel,
          magneticGuides: [...s.magneticGuides, (pt, s.point)],
        );
      }
    }

    if (centerSnap.isSnapped &&
        (centerSnap.snapLabel?.startsWith('Axis ') ?? false) &&
        (bestPerim == null || bestPerimRank > 0)) {
      return centerSnap;
    }

    if (bestPerim != null &&
        (!centerSnap.isSnapped ||
            centerSnap.snapLabel == 'Edge' ||
            centerSnap.snapLabel == 'Alignment' ||
            bestPerimDist < (centerSnap.point - raw).distance)) {
      return bestPerim;
    }

    return centerSnap;
  }
}
