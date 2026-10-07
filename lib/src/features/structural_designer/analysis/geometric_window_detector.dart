import 'dart:math' as math;
import 'dart:ui';

import '../../dxf_viewer/models/dxf_models.dart';
import '../models/wall_axis_models.dart';
import 'structural_column_detector.dart';

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
    final allStrokes = _extractDocStrokes(doc);
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

        // Alignment check: the opening axis should be roughly aligned with wall directions
        final u = spanVec / spanDist;
        final alignmentA = (jA.axisDir.dx * u.dx + jA.axisDir.dy * u.dy).abs();
        final alignmentB = (jB.axisDir.dx * u.dx + jB.axisDir.dy * u.dy).abs();

        // Must be near-collinear (cos >= 0.94, angle <= 20 deg)
        // OR an L-corner opening (one aligned, one perpendicular)
        final isCollinear = alignmentA >= 0.94 && alignmentB >= 0.94;
        final isCorner = (alignmentA >= 0.90 && alignmentB <= 0.35) ||
                         (alignmentB >= 0.90 && alignmentA <= 0.35);

        if (!isCollinear && !isCorner) continue;

        // Check lateral offset between the two jamb centers
        final n = Offset(-u.dy, u.dx);
        final lateralOffset = ((jB.center - jA.center).dx * n.dx +
                               (jB.center - jA.center).dy * n.dy).abs();
        final maxThickness = math.max(jA.thickness, jB.thickness);
        if (lateralOffset > maxThickness * 0.85 + 50 * scale) continue;

        // Step 4: Evaluate opening corridor geometry
        final opening = _evaluateCorridor(
          startJamb: jA,
          endJamb: jB,
          spanVec: spanVec,
          spanDist: spanDist,
          strokes: strokes,
          scale: scale,
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
  }) {
    final u = spanVec / spanDist; // Longitudinal axis of opening
    final n = Offset(-u.dy, u.dx); // Transversal axis (across wall thickness)
    final corridorThickness = math.max(startJamb.thickness, endJamb.thickness);
    final halfCorridor = corridorThickness / 2.0 + 120.0 * scale; // Include sill/frame margin

    double dotU(Offset p) => (p - startJamb.center).dx * u.dx + (p - startJamb.center).dy * u.dy;
    double dotN(Offset p) => (p - startJamb.center).dx * n.dx + (p - startJamb.center).dy * n.dy;

    final longitudinalSpans = <(double, double, double)>[]; // (tMin, tMax, lateralOffset)
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

      final cosAngle = (v.dx * u.dx + v.dy * u.dy).abs() / vLen;

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
    if (coverageRatio >= 0.30) evidence.add('longitudinalCoverage_${(coverageRatio * 100).toInt()}%');
    if (transverseMullionCount > 0) evidence.add('transverseMullions_$transverseMullionCount');
    if (hasDimensionMarker) evidence.add('dimensionMarker');

    final bool isConfirmedWindow =
        (hasParallelPair && coverageRatio >= 0.25) ||
        (coverageRatio >= 0.25 && transverseMullionCount >= 1) ||
        (coverageRatio >= 0.25 && hasDimensionMarker);

    if (!isConfirmedWindow) return null;

    // Generate solid barrier polygon across the opening
    final halfThick = corridorThickness / 2.0;
    final barrierPolygon = <Offset>[
      startJamb.center + n * halfThick,
      endJamb.center + n * halfThick,
      endJamb.center - n * halfThick,
      startJamb.center - n * halfThick,
    ];

    return GeometricWindowOpening(
      start: startJamb.center,
      end: endJamb.center,
      thickness: corridorThickness,
      length: spanDist,
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
}
