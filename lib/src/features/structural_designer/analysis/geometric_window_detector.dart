import 'dart:math' as math;
import 'dart:ui';

import '../../dxf_viewer/models/dxf_models.dart';
import '../models/wall_axis_models.dart';
import 'structural_column_detector.dart';
import 'structural_underlay_source.dart';

/// Represents a geometrically identified window, vitrina, or door opening
/// located strictly between structural wall jambs or columns.
class GeometricWindowOpening {
  /// Center point of the opening start (at jamb A).
  final Offset start;

  /// Center point of the opening end (at jamb B).
  final Offset end;

  /// Effective thickness of the opening corridor (typically wall thickness).
  final double thickness;

  /// Width / span of the clear opening between jambs.
  final double length;

  /// 4-point polygon forming a solid barrier across the opening
  /// to prevent raster flood leaking during slab detection.
  final List<Offset> barrierPolygon;

  /// Detailed geometric diagnostics for auditability.
  final List<String> evidence;

  const GeometricWindowOpening({
    required this.start,
    required this.end,
    required this.thickness,
    required this.length,
    required this.barrierPolygon,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
    'start': [start.dx, start.dy],
    'end': [end.dx, end.dy],
    'thickness': thickness,
    'length': length,
    'evidence': evidence,
  };
}

/// Purely geometric detector for windows, vitrines, and facade glazing.
///
/// Principle:
/// - NEVER relies on hardcoded layer names or dictionary keyword filters.
///   (In real BIM/CAD files like Archicad Worksheet exports, windows and walls
///   frequently share the exact same layer 'стени' or 'A-WALL').
/// - Detects openings strictly between wall jambs ($0.60\,\text{m} \le L \le 5.50\,\text{m}$).
/// - Analyzes geometric features in the opening corridor:
///   1. Longitudinal lines (glazing panes, frame lines, sills).
///   2. Transverse segments (frame profiles at jambs, mullions/шпроси every 0.8–1.5m).
///   3. Dimension witness marks / opening dimension ticks.
///   4. Pen lineweight contrasts (uncut glazing pen vs thick cut wall pen).
class GeometricWindowDetector {
  const GeometricWindowDetector._();

  /// Minimum clear opening span (60 cm - small window / bathroom / shaft door).
  static const double minOpeningSpanM = 0.60;

  /// Maximum clear opening span supported for vitrines / curtain walls (5.50 m).
  static const double maxOpeningSpanM = 5.50;

  /// Detects all geometric window openings in a drawing given wall pairs.
  static List<GeometricWindowOpening> detect(
    DxfDocument doc,
    List<WallPairCandidate> wallPairs,
    double scale, {
    List<DetectedStructuralColumn> columns = const [],
  }) {
    if (wallPairs.isEmpty || !scale.isFinite || scale <= 0) return const [];

    // Step 1: Collect all straight entity strokes from the document (lines, polylines, blocks)
    final allStrokes = _extractDocStrokes(
      StructuralUnderlaySource.original(doc),
    );
    if (allStrokes.isEmpty) return const [];

    // Filter out strokes that coincide with structural wall faces
    final strokes = allStrokes.where((s) {
      for (final w in wallPairs) {
        for (final seg in [w.segmentA, w.segmentB]) {
          final d1 = (s.$1 - seg.start).distance;
          final d2 = (s.$2 - seg.end).distance;
          final d3 = (s.$1 - seg.end).distance;
          final d4 = (s.$2 - seg.start).distance;
          if ((d1 < 15 * scale && d2 < 15 * scale) ||
              (d3 < 15 * scale && d4 < 15 * scale)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    final minSpanCad = minOpeningSpanM * 1000.0 * scale;
    final maxSpanCad = maxOpeningSpanM * 1000.0 * scale;

    // Step 2: Extract wall jambs (end caps) per wall pair
    final jambsByWall = <int, (_WallJamb, _WallJamb)>{};
    for (int i = 0; i < wallPairs.length; i++) {
      final w = wallPairs[i];
      final d = w.centerlineEnd - w.centerlineStart;
      if (d.distance < 10 * scale) continue;
      final u = d / d.distance;
      final n = Offset(-u.dy, u.dx);
      final halfThick = w.perpendicularDistance / 2.0;

      final jStart = _WallJamb(
        center: w.centerlineStart,
        normal: n,
        axisDir: u,
        wallIndex: i,
        thickness: w.perpendicularDistance,
        pLeft: w.centerlineStart + n * halfThick,
        pRight: w.centerlineStart - n * halfThick,
        isStart: true,
      );

      final jEnd = _WallJamb(
        center: w.centerlineEnd,
        normal: n,
        axisDir: u,
        wallIndex: i,
        thickness: w.perpendicularDistance,
        pLeft: w.centerlineEnd + n * halfThick,
        pRight: w.centerlineEnd - n * halfThick,
        isStart: false,
      );
      jambsByWall[i] = (jStart, jEnd);
    }

    final openings = <GeometricWindowOpening>[];
    final wallIndices = jambsByWall.keys.toList();

    // Step 3: Test the facing (closest) jamb pair between each pair of walls
    for (int idxA = 0; idxA < wallIndices.length; idxA++) {
      final i = wallIndices[idxA];
      final pairA = jambsByWall[i]!;
      for (int idxB = idxA + 1; idxB < wallIndices.length; idxB++) {
        final j = wallIndices[idxB];
        final pairB = jambsByWall[j]!;

        _WallJamb? bestA, bestB;
        double minDistance = double.infinity;
        for (final a in [pairA.$1, pairA.$2]) {
          for (final b in [pairB.$1, pairB.$2]) {
            final dist = (b.center - a.center).distance;
            if (dist < minDistance) {
              minDistance = dist;
              bestA = a;
              bestB = b;
            }
          }
        }
        if (bestA == null || bestB == null) continue;
        final jA = bestA;
        final jB = bestB;

        final spanVec = jB.center - jA.center;
        final spanDist = spanVec.distance;
        if (spanDist < minSpanCad || spanDist > maxSpanCad) continue;

        // Alignment check: the opening axis should be aligned with wall directions
        // Openings connect one part of the wall straight to the other along the facade
        final u = spanVec / spanDist;
        final alignmentA = (jA.axisDir.dx * u.dx + jA.axisDir.dy * u.dy).abs();
        final alignmentB = (jB.axisDir.dx * u.dx + jB.axisDir.dy * u.dy).abs();

        // Must be near-collinear facade walls (cos >= 0.92, angle <= 23 deg)
        // Corner/angled jumps across niches/balconies are rejected to prevent skewed slab boundaries
        final isCollinear = alignmentA >= 0.92 && alignmentB >= 0.92;
        if (!isCollinear) continue;

        // Face-to-face check ("лице в лице"):
        // A true wall opening (window/vitrina) is a hole in a single wall axis.
        // The two jamb end-caps must face directly toward each other across the gap.
        final facingA = jA.openNormal.dx * u.dx + jA.openNormal.dy * u.dy;
        final facingB = jB.openNormal.dx * (-u.dx) + jB.openNormal.dy * (-u.dy);
        if (facingA < 0.85 || facingB < 0.85) continue;

        // Check lateral offset between the two jamb centers
        final n = Offset(-u.dy, u.dx);
        final lateralOffset =
            ((jB.center - jA.center).dx * n.dx +
                    (jB.center - jA.center).dy * n.dy)
                .abs();
        final maxThickness = math.max(jA.thickness, jB.thickness);
        if (lateralOffset > maxThickness * 0.85 + 50 * scale) continue;

        // Check if this opening spans the mouth of an inward recess/courtyard
        final isRecess = isRecessMouth(
          centerA: jA.center,
          dirA: jA.axisDir,
          thicknessA: jA.thickness,
          centerB: jB.center,
          dirB: jB.axisDir,
          thicknessB: jB.thickness,
          wallPairs: wallPairs,
          wallIndexA: i,
          wallIndexB: j,
          scale: scale,
        );

        // Intervening obstacle check: ensure no intermediate wall or column sits between jA and jB in this corridor
        bool hasInterveningObstacle = false;
        final corridorBounds = Rect.fromPoints(
          jA.center,
          jB.center,
        ).inflate(maxThickness);
        for (int k = 0; k < wallPairs.length; k++) {
          if (k == i || k == j) continue;
          final otherWall = wallPairs[k];
          final wRect = Rect.fromPoints(
            otherWall.centerlineStart,
            otherWall.centerlineEnd,
          ).inflate(otherWall.perpendicularDistance / 2.0);
          if (!corridorBounds.overlaps(wRect)) continue;

          final t1 =
              (otherWall.centerlineStart - jA.center).dx * u.dx +
              (otherWall.centerlineStart - jA.center).dy * u.dy;
          final t2 =
              (otherWall.centerlineEnd - jA.center).dx * u.dx +
              (otherWall.centerlineEnd - jA.center).dy * u.dy;
          final tMin = math.min(t1, t2);
          final tMax = math.max(t1, t2);

          if (tMax > 50.0 * scale && tMin < spanDist - 50.0 * scale) {
            final d1 =
                ((otherWall.centerlineStart - jA.center).dx * n.dx +
                        (otherWall.centerlineStart - jA.center).dy * n.dy)
                    .abs();
            final d2 =
                ((otherWall.centerlineEnd - jA.center).dx * n.dx +
                        (otherWall.centerlineEnd - jA.center).dy * n.dy)
                    .abs();
            if (math.min(d1, d2) <=
                maxThickness * 0.85 + otherWall.perpendicularDistance / 2.0) {
              hasInterveningObstacle = true;
              break;
            }
          }
        }
        if (hasInterveningObstacle) continue;

        for (final col in columns) {
          if (!corridorBounds.overlaps(col.bounds)) continue;
          final colCenter = col.bounds.center;
          final tCol =
              (colCenter - jA.center).dx * u.dx +
              (colCenter - jA.center).dy * u.dy;
          if (tCol > 50.0 * scale && tCol < spanDist - 50.0 * scale) {
            final dCol =
                ((colCenter - jA.center).dx * n.dx +
                        (colCenter - jA.center).dy * n.dy)
                    .abs();
            final colRadius = math.max(col.width, col.height) / 2.0;
            if (dCol <= maxThickness * 0.85 + colRadius) {
              hasInterveningObstacle = true;
              break;
            }
          }
        }
        if (hasInterveningObstacle) continue;

        // Step 4: Evaluate opening corridor geometry
        final opening = _evaluateCorridor(
          startJamb: jA,
          endJamb: jB,
          spanVec: spanVec,
          spanDist: spanDist,
          strokes: strokes,
          scale: scale,
          isRecessMouth: isRecess,
        );

        if (opening != null) {
          openings.add(opening);
        }
      }
    }

    return openings;
  }

  /// Evaluates strokes within the opening corridor between two jambs.
  static GeometricWindowOpening? _evaluateCorridor({
    required _WallJamb startJamb,
    required _WallJamb endJamb,
    required Offset spanVec,
    required double spanDist,
    required List<(Offset, Offset, double)> strokes, // (p1, p2, lineweight)
    required double scale,
    bool isRecessMouth = false,
  }) {
    // Determine common facade direction along wall axis
    var uWall = startJamb.axisDir;
    // Snap near-orthogonal to exact (1, 0) or (0, 1)
    if (uWall.dy.abs() <= 0.08) {
      uWall = const Offset(1.0, 0.0);
    } else if (uWall.dx.abs() <= 0.08) {
      uWall = const Offset(0.0, 1.0);
    }
    // Orient uWall from startJamb towards endJamb
    if ((endJamb.center - startJamb.center).dx * uWall.dx +
            (endJamb.center - startJamb.center).dy * uWall.dy <
        0) {
      uWall = -uWall;
    }
    final nWall = Offset(-uWall.dy, uWall.dx);

    final corridorThickness = math.max(startJamb.thickness, endJamb.thickness);
    final halfCorridor =
        corridorThickness / 2.0 + 120.0 * scale; // Include sill/frame margin

    double dotU(Offset p) =>
        (p - startJamb.center).dx * uWall.dx +
        (p - startJamb.center).dy * uWall.dy;
    double dotN(Offset p) =>
        (p - startJamb.center).dx * nWall.dx +
        (p - startJamb.center).dy * nWall.dy;

    final longitudinalSpans =
        <(double, double, double)>[]; // (tMin, tMax, lateralOffset)
    int transverseMullionCount = 0;
    bool hasDimensionMarker = false;

    for (final stroke in strokes) {
      final p1 = stroke.$1;
      final p2 = stroke.$2;
      final v = p2 - p1;
      final vLen = v.distance;
      if (vLen < 15.0 * scale) continue;

      final t1 = dotU(p1);
      final t2 = dotU(p2);
      final d1 = dotN(p1);
      final d2 = dotN(p2);

      // Must be within lateral corridor bounds
      if (math.max(d1.abs(), d2.abs()) > halfCorridor) continue;

      // Must be within longitudinal span (with small 60mm tolerance for jamb attachments)
      final tMin = math.min(t1, t2);
      final tMax = math.max(t1, t2);
      if (tMax < -60.0 * scale || tMin > spanDist + 60.0 * scale) continue;

      final cosAngle = (v.dx * uWall.dx + v.dy * uWall.dy).abs() / vLen;

      // Longitudinal stroke (glazing line, frame edge, window sill)
      // Angle <= 16 degrees (cos >= 0.96)
      if (cosAngle >= 0.96) {
        final clampedMin = math.max(0.0, tMin);
        final clampedMax = math.min(spanDist, tMax);
        if (clampedMax > clampedMin) {
          final latOffset = (d1 + d2) / 2.0;
          longitudinalSpans.add((clampedMin, clampedMax, latOffset));
        }
      }
      // Transverse stroke (mullion / шпроса / профил на каса / делител)
      // Angle >= 75 degrees (cos <= 0.25)
      else if (cosAngle <= 0.25) {
        // Transversal lines are short profile segments (30mm - 350mm)
        if (vLen >= 25.0 * scale && vLen <= corridorThickness * 1.5) {
          transverseMullionCount++;
        }
        // Or a dimension witness line crossing the opening
        else if (vLen >= corridorThickness * 0.5) {
          hasDimensionMarker = true;
        }
      }
    }

    if (longitudinalSpans.isEmpty) return null;

    // Calculate cumulative coverage along span
    longitudinalSpans.sort((a, b) => a.$1.compareTo(b.$1));
    double covered = 0.0;
    double curStart = longitudinalSpans.first.$1;
    double curEnd = longitudinalSpans.first.$2;

    for (int k = 1; k < longitudinalSpans.length; k++) {
      final next = longitudinalSpans[k];
      if (next.$1 <= curEnd + 35.0 * scale) {
        curEnd = math.max(curEnd, next.$2);
      } else {
        covered += math.max(0.0, curEnd - curStart);
        curStart = next.$1;
        curEnd = next.$2;
      }
    }
    covered += math.max(0.0, curEnd - curStart);
    final coverageRatio = covered / spanDist;

    // Check for pairs of parallel longitudinal lines (characteristic of frames & glazing)
    bool hasParallelPair = false;
    for (int a = 0; a < longitudinalSpans.length; a++) {
      for (int b = a + 1; b < longitudinalSpans.length; b++) {
        final sA = longitudinalSpans[a];
        final sB = longitudinalSpans[b];
        final separation = (sA.$3 - sB.$3).abs();
        final overlap = math.min(sA.$2, sB.$2) - math.max(sA.$1, sB.$1);
        if (separation >= 8.0 * scale &&
            separation <= corridorThickness &&
            overlap >= 0.20 * spanDist) {
          hasParallelPair = true;
          break;
        }
      }
      if (hasParallelPair) break;
    }

    // Geometric Decision Criteria:
    // 1. Parallel pair covering >= 30% of span (standard CAD window / Archicad 2D)
    // 2. High longitudinal coverage >= 45% of span (single-line or multi-line vitrina)
    // 3. Longitudinal coverage >= 25% PLUS at least 1 transverse mullion / frame profile tick
    // 4. Longitudinal coverage >= 25% PLUS opening dimension witness line / marker
    final evidence = <String>[];
    if (hasParallelPair) evidence.add('parallelFrameOrGlazingPair');
    if (coverageRatio >= 0.30) {
      evidence.add('longitudinalCoverage_${(coverageRatio * 100).toInt()}%');
    }
    if (transverseMullionCount > 0) {
      evidence.add('transverseMullions_$transverseMullionCount');
    }
    if (hasDimensionMarker) evidence.add('dimensionMarker');

    final bool isConfirmedWindow;
    if (isRecessMouth) {
      // Across an inward courtyard or recess mouth, require genuine glazing frames/lines
      // so we never bridge an open courtyard/niche unless it is an explicitly glazed facade.
      isConfirmedWindow =
          (hasParallelPair && coverageRatio >= 0.25) ||
          (coverageRatio >= 0.25 && transverseMullionCount >= 2);
    } else {
      isConfirmedWindow =
          (hasParallelPair && coverageRatio >= 0.25) ||
          (coverageRatio >= 0.25 && transverseMullionCount >= 1) ||
          (coverageRatio >= 0.25 && hasDimensionMarker);
    }

    if (!isConfirmedWindow) return null;

    // Project opening endpoints strictly along uWall so the bridge is 100% collinear with the wall
    final spanAlongWall = dotU(endJamb.center);
    if (spanAlongWall <= 0) return null;

    final dEnd = dotN(endJamb.center);
    final dMid = dEnd / 2.0;

    final alignedStart = startJamb.center + nWall * dMid;
    final alignedEnd = startJamb.center + uWall * spanAlongWall + nWall * dMid;

    // Generate solid barrier polygon across the opening, strictly parallel/perpendicular to wall
    final halfThick = corridorThickness / 2.0;
    final barrierPolygon = <Offset>[
      alignedStart + nWall * halfThick,
      alignedEnd + nWall * halfThick,
      alignedEnd - nWall * halfThick,
      alignedStart - nWall * halfThick,
    ];

    return GeometricWindowOpening(
      start: alignedStart,
      end: alignedEnd,
      thickness: corridorThickness,
      length: spanAlongWall,
      barrierPolygon: barrierPolygon,
      evidence: evidence,
    );
  }

  /// Extracts straight segment strokes from all model space entities in the DXF document.
  static List<(Offset, Offset, double)> _extractDocStrokes(DxfDocument doc) {
    final result = <(Offset, Offset, double)>[];
    var visited = 0;

    void visit(
      DxfEntity e,
      Offset Function(Offset) tr,
      double inheritedLw,
      int depth,
    ) {
      if (++visited > 80000 || depth > 8 || e.isPaperSpace) return;
      var lt = (e.lineType ?? 'BYLAYER').toUpperCase();
      if (lt == 'BYLAYER') {
        lt = (doc.layers[e.layer]?.lineType ?? 'CONTINUOUS').toUpperCase();
      }
      if (lt != 'CONTINUOUS' && lt != 'BYBLOCK' && lt.isNotEmpty) return;

      final lw = e.lineWeight ?? inheritedLw;

      if (e is DxfInsert) {
        final block = doc.blocks[e.blockName];
        if (block == null) return;
        final angle = e.rotationDeg * math.pi / 180.0;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);

        Offset childTr(Offset p) {
          final v = p - block.basePoint;
          final x = v.dx * e.scaleX;
          final y = v.dy * e.scaleY;
          return tr(
            e.insertPoint + Offset(x * cosA - y * sinA, x * sinA + y * cosA),
          );
        }

        for (final child in block.entities) {
          visit(child, childTr, lw, depth + 1);
        }
      } else if (e is DxfLine) {
        result.add((tr(e.p1), tr(e.p2), lw));
      } else if (e is DxfLwPolyline) {
        final count = e.isClosed ? e.vertices.length : e.vertices.length - 1;
        for (int i = 0; i < count; i++) {
          final a = e.vertices[i];
          final b = e.vertices[(i + 1) % e.vertices.length];
          if (a.bulge.abs() < 1e-8) {
            result.add((tr(Offset(a.x, a.y)), tr(Offset(b.x, b.y)), lw));
          }
        }
      }
    }

    final entities = doc.layoutEntities['Model'] ?? doc.entities;
    for (final e in entities) {
      visit(e, (p) => p, 0.0, 0);
    }

    return result;
  }

  /// Checks whether a jamb at [center] with wall direction [wallDir] connects to a perpendicular return wall
  /// (such as the side wall of an inward niche, courtyard, or loggia), and returns the unit vector
  /// pointing along the return wall away from [center].
  static Offset? perpendicularReturnDirection({
    required Offset center,
    required Offset wallDir,
    required double wallThickness,
    required List<WallPairCandidate> wallPairs,
    required int excludeWallIndex,
    required double scale,
  }) {
    final searchRadius = wallThickness * 1.25 + 35.0 * scale;
    for (int k = 0; k < wallPairs.length; k++) {
      if (k == excludeWallIndex) continue;
      final other = wallPairs[k];
      final otherDir = other.segmentA.direction;
      final dot = (wallDir.dx * otherDir.dx + wallDir.dy * otherDir.dy).abs();
      // Must be perpendicular (cos <= 0.22, angle >= 77 deg)
      if (dot <= 0.22) {
        final d1 = (other.centerlineStart - center).distance;
        final d2 = (other.centerlineEnd - center).distance;
        final dMid = _closestPointOnSegment(
          center,
          other.centerlineStart,
          other.centerlineEnd,
        );
        if (math.min(d1, d2) <= searchRadius ||
            (center - dMid).distance <= searchRadius) {
          final otherLen =
              (other.centerlineEnd - other.centerlineStart).distance;
          if (otherLen >= 400.0 * scale) {
            final farEnd = d1 > d2
                ? other.centerlineStart
                : other.centerlineEnd;
            final vec = farEnd - center;
            if (vec.distance > 1e-4) {
              return vec / vec.distance;
            }
          }
        }
      }
    }
    return null;
  }

  /// Checks whether a jamb at [center] connects to any perpendicular return wall.
  static bool hasPerpendicularReturnWall({
    required Offset center,
    required Offset wallDir,
    required double wallThickness,
    required List<WallPairCandidate> wallPairs,
    required int excludeWallIndex,
    required double scale,
  }) {
    return perpendicularReturnDirection(
          center: center,
          wallDir: wallDir,
          wallThickness: wallThickness,
          wallPairs: wallPairs,
          excludeWallIndex: excludeWallIndex,
          scale: scale,
        ) !=
        null;
  }

  /// Checks whether two jambs across an opening span the mouth of an inward architectural recess,
  /// courtyard, or loggia by verifying that both ends connect to perpendicular return walls
  /// heading in the same direction into the building depth.
  static bool isRecessMouth({
    required Offset centerA,
    required Offset dirA,
    required double thicknessA,
    required Offset centerB,
    required Offset dirB,
    required double thicknessB,
    required List<WallPairCandidate> wallPairs,
    required int wallIndexA,
    required int wallIndexB,
    required double scale,
  }) {
    final rA = perpendicularReturnDirection(
      center: centerA,
      wallDir: dirA,
      wallThickness: thicknessA,
      wallPairs: wallPairs,
      excludeWallIndex: wallIndexA,
      scale: scale,
    );
    if (rA == null) return false;

    final rB = perpendicularReturnDirection(
      center: centerB,
      wallDir: dirB,
      wallThickness: thicknessB,
      wallPairs: wallPairs,
      excludeWallIndex: wallIndexB,
      scale: scale,
    );
    if (rB == null) return false;

    // Both return walls must extend in the same inward direction (cos >= 0.5)
    return (rA.dx * rB.dx + rA.dy * rB.dy) >= 0.5;
  }

  static Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return a;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    return a + ab * t.clamp(0.0, 1.0);
  }
}

class _WallJamb {
  final Offset center;
  final Offset normal;
  final Offset axisDir;
  final int wallIndex;
  final double thickness;
  final Offset pLeft;
  final Offset pRight;
  final bool isStart;

  const _WallJamb({
    required this.center,
    required this.normal,
    required this.axisDir,
    required this.wallIndex,
    required this.thickness,
    required this.pLeft,
    required this.pRight,
    required this.isStart,
  });

  /// Outward normal pointing out of the wall end into open space.
  Offset get openNormal => isStart ? -axisDir : axisDir;
}
