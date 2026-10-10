import 'dart:math' as math;
import 'dart:ui';
import '../models/wall_axis_models.dart';
import 'slab_opening_evidence.dart';
import 'slab_axis_support_grid.dart';

import 'geometric_window_detector.dart';

class SlabGapHypothesis {
  final Offset start, end;
  final double thickness;
  final int wallA, wallB;
  final bool wideOpeningEvidence;
  final List<Offset> axisSupportIntersections;
  const SlabGapHypothesis(
    this.start,
    this.end,
    this.thickness,
    this.wallA,
    this.wallB, {
    this.wideOpeningEvidence = false,
    this.axisSupportIntersections = const [],
  });
  Map<String, dynamic> toJson() => {
    'start': [start.dx, start.dy],
    'end': [end.dx, end.dy],
    'thickness': thickness,
    'walls': [wallA, wallB],
    if (axisSupportIntersections.isNotEmpty)
      'axisSupportIntersections': axisSupportIntersections
          .map((p) => [p.dx, p.dy])
          .toList(),
    'reason': axisSupportIntersections.isNotEmpty
        ? 'wallContinuityBetweenOccupiedAxisIntersections'
        : wideOpeningEvidence
        ? 'matchingWallFacesWithParallelFrameStrokes'
        : 'collinearMatchingWallFaces',
    'confirmedOpening': false,
  };
}

/// Spatially separate components are processed independently, never tiled
/// through walls. Gaps are hypotheses, not evidence of doors or windows.
class SlabWallRegions {
  final List<List<WallPairCandidate>> regions;
  final List<List<SlabGapHypothesis>> gaps;
  final bool tooComplex;
  SlabWallRegions(this.regions, this.gaps, {this.tooComplex = false});

  static SlabWallRegions build(
    List<WallPairCandidate> walls,
    double scale, {
    double targetThicknessMm = 250,
    List<GeometricWindowOpening> windowOpenings = const [],
    List<(Offset, Offset, String)> openingEvidence = const [],
  }) {
    final parent = List.generate(walls.length, (i) => i);
    int root(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    // Connect walls directly if a confirmed geometric window opening bridges them
    for (final win in windowOpenings) {
      int? idxA, idxB;
      final dWin = win.end - win.start;
      if (dWin.distance == 0) continue;
      final uWin = dWin / dWin.distance;
      for (int i = 0; i < walls.length; i++) {
        final w = walls[i];
        final dW = w.centerlineEnd - w.centerlineStart;
        if (dW.distance == 0) continue;
        final uW = dW / dW.distance;
        if ((uW.dx * uWin.dx + uW.dy * uWin.dy).abs() < 0.85) continue;

        final nearStartA =
            (w.centerlineStart - win.start).distance <= 120.0 * scale ||
            (w.centerlineEnd - win.start).distance <= 120.0 * scale;
        final nearEndB =
            (w.centerlineStart - win.end).distance <= 120.0 * scale ||
            (w.centerlineEnd - win.end).distance <= 120.0 * scale;
        if (nearStartA) idxA = i;
        if (nearEndB) idxB = i;
      }
      if (idxA != null && idxB != null && idxA != idxB) {
        parent[root(idxB)] = root(idxA);
      }
    }

    // Cluster walls with reach of 2500 * scale (up to 5.0m openings between walls)
    final boxes = walls
        .map(
          (w) => Rect.fromPoints(
            w.centerlineStart,
            w.centerlineEnd,
          ).inflate(w.perpendicularDistance / 2 + 2500 * scale),
        )
        .toList();
    final order = List.generate(walls.length, (i) => i)
      ..sort((a, b) => boxes[a].left.compareTo(boxes[b].left));
    var comparisons = 0;
    for (var a = 0; a < order.length; a++) {
      final i = order[a];
      for (var b = a + 1; b < order.length; b++) {
        final j = order[b];
        if (boxes[j].left > boxes[i].right) break;
        if (++comparisons > 2000000) {
          return SlabWallRegions([], [], tooComplex: true);
        }
        if (boxes[i].overlaps(boxes[j])) parent[root(j)] = root(i);
      }
    }
    final groups = <int, List<WallPairCandidate>>{};
    for (var i = 0; i < walls.length; i++) {
      groups.putIfAbsent(root(i), () => []).add(walls[i]);
    }
    // Process substantial components first if the per-run region budget is hit.
    double extent(List<WallPairCandidate> g) => g.fold<double>(
      0,
      (sum, w) => sum + (w.centerlineEnd - w.centerlineStart).distance,
    );
    final regions = groups.values.toList()
      ..sort((a, b) => extent(b).compareTo(extent(a)));
    final allGaps = <List<SlabGapHypothesis>>[];
    for (final group in regions) {
      final proposals = <SlabGapHypothesis>[];
      final axisGrid = SlabAxisSupportGrid(
        group,
        scale,
        targetThicknessMm: targetThicknessMm,
      );

      // Add confirmed geometric window openings between walls in this group
      for (final win in windowOpenings) {
        int? iA, iB;
        final dWin = win.end - win.start;
        if (dWin.distance == 0) continue;
        final uWin = dWin / dWin.distance;
        for (int k = 0; k < group.length; k++) {
          final w = group[k];
          final dW = w.centerlineEnd - w.centerlineStart;
          if (dW.distance == 0) continue;
          final uW = dW / dW.distance;
          if ((uW.dx * uWin.dx + uW.dy * uWin.dy).abs() < 0.85) continue;

          final nearA =
              (w.centerlineStart - win.start).distance <= 120.0 * scale ||
              (w.centerlineEnd - win.start).distance <= 120.0 * scale;
          final nearB =
              (w.centerlineStart - win.end).distance <= 120.0 * scale ||
              (w.centerlineEnd - win.end).distance <= 120.0 * scale;
          if (nearA) iA = k;
          if (nearB) iB = k;
        }
        if (iA != null && iB != null && iA != iB) {
          final gapBounds = Rect.fromPoints(
            win.start,
            win.end,
          ).inflate(25 * scale);
          var blocked = false;
          final dWin = win.end - win.start;
          if (dWin.distance > 0) {
            final uWin = dWin / dWin.distance;
            double crossW(Offset p) => p.dx * uWin.dy - p.dy * uWin.dx;
            double dotW(Offset p) => p.dx * uWin.dx + p.dy * uWin.dy;
            for (var k = 0; k < group.length; k++) {
              if (k == iA || k == iB) continue;
              final w = group[k];
              if (!gapBounds.overlaps(
                Rect.fromPoints(
                  w.centerlineStart,
                  w.centerlineEnd,
                ).inflate(w.perpendicularDistance / 2),
              )) {
                continue;
              }
              final v = w.centerlineEnd - w.centerlineStart;
              final den = crossW(v);
              if (den.abs() > 1e-5) {
                final t = -crossW(w.centerlineStart - win.start) / den;
                final along = dotW(w.centerlineStart + v * t - win.start);
                if (t >= -0.05 &&
                    t <= 1.05 &&
                    along >= -25 * scale &&
                    along <= win.length + 25 * scale) {
                  blocked = true;
                  break;
                }
              } else {
                final lo = math.min(
                  dotW(w.centerlineStart - win.start),
                  dotW(w.centerlineEnd - win.start),
                );
                final hi = math.max(
                  dotW(w.centerlineStart - win.start),
                  dotW(w.centerlineEnd - win.start),
                );
                if (hi > 25 * scale &&
                    lo < win.length - 25 * scale &&
                    crossW(w.centerlineStart - win.start).abs() <
                        w.perpendicularDistance / 2 + 50 * scale) {
                  blocked = true;
                  break;
                }
              }
            }
          }
          if (!blocked) {
            proposals.add(
              SlabGapHypothesis(
                win.start,
                win.end,
                win.thickness,
                iA,
                iB,
                wideOpeningEvidence: true,
              ),
            );
          }
        }
      }

      for (var i = 0; i < group.length; i++) {
        final a = group[i], d = a.centerlineEnd - a.centerlineStart;
        if (d.distance < 15 * scale ||
            (d.distance < 100 * scale && !axisGrid.isAxisWall(i))) {
          continue;
        }
        final u = d / d.distance;
        double dot(Offset p) => p.dx * u.dx + p.dy * u.dy;
        double cross(Offset p) => p.dx * u.dy - p.dy * u.dx;
        for (var j = i + 1; j < group.length; j++) {
          if (++comparisons > 2000000) {
            return SlabWallRegions([], [], tooComplex: true);
          }
          final b = group[j], e = b.centerlineEnd - b.centerlineStart;
          if (e.distance < 15 * scale ||
              (e.distance < 100 * scale && !axisGrid.isAxisWall(j)) ||
              cross(e / e.distance).abs() > 0.035) {
            continue;
          }
          final thickDiff = (a.perpendicularDistance - b.perpendicularDistance)
              .abs();
          if (thickDiff > 100 * scale) {
            continue;
          }
          if (cross(b.centerlineStart - a.centerlineStart).abs() > 35 * scale ||
              cross(b.centerlineEnd - a.centerlineStart).abs() > 35 * scale) {
            continue;
          }
          final b0 = dot(b.centerlineStart - a.centerlineStart),
              b1 = dot(b.centerlineEnd - a.centerlineStart);
          Offset start, end;
          if (math.min(b0, b1) > d.distance) {
            start = a.centerlineEnd;
            end = b0 < b1 ? b.centerlineStart : b.centerlineEnd;
          } else if (math.max(b0, b1) < 0) {
            start = b0 > b1 ? b.centerlineStart : b.centerlineEnd;
            end = a.centerlineStart;
          } else {
            continue;
          }
          final length = (end - start).distance;
          if (length < 75 * scale || length > 5500 * scale) continue;
          final axisSupports = axisGrid.supportingIntersections(
            i,
            j,
            start,
            end,
          );
          if ((d.distance < 100 * scale || e.distance < 100 * scale) &&
              (axisSupports.isEmpty || thickDiff > 50 * scale)) {
            continue;
          }

          // Architectural Opening vs Recess principle:
          // If both ends connect to perpendicular return walls extending inward in the same direction,
          // this is the mouth of an inner courtyard, niche, or loggia.
          // Unless confirmed as a glazed window in [windowOpenings], do NOT bridge across it.
          if (GeometricWindowDetector.isRecessMouth(
            centerA: start,
            dirA: u,
            thicknessA: a.perpendicularDistance,
            centerB: end,
            dirB: u,
            thicknessB: b.perpendicularDistance,
            wallPairs: group,
            wallIndexA: i,
            wallIndexB: j,
            scale: scale,
          )) {
            continue;
          }

          if (length > 1500 * scale) {
            comparisons += openingEvidence.length;
            if (comparisons > 2000000) {
              return SlabWallRegions([], [], tooComplex: true);
            }
            if (!SlabOpeningEvidence.supports(
              openingEvidence,
              start,
              end,
              (a.perpendicularDistance + b.perpendicularDistance) / 2,
              scale,
            )) {
              continue;
            }
          }
          // Avoid joining across an intervening wall or a return into a recess.
          final gapBounds = Rect.fromPoints(start, end).inflate(25 * scale);
          var blocked = false;
          for (var k = 0; k < group.length; k++) {
            if (k == i || k == j) continue;
            if (++comparisons > 2000000) {
              return SlabWallRegions([], [], tooComplex: true);
            }
            final w = group[k];
            if (!gapBounds.overlaps(
              Rect.fromPoints(
                w.centerlineStart,
                w.centerlineEnd,
              ).inflate(w.perpendicularDistance / 2),
            )) {
              continue;
            }
            final v = w.centerlineEnd - w.centerlineStart;
            final denominator = cross(v);
            if (denominator.abs() < 1e-9) {
              final lo = math.min(
                dot(w.centerlineStart - start),
                dot(w.centerlineEnd - start),
              );
              final hi = math.max(
                dot(w.centerlineStart - start),
                dot(w.centerlineEnd - start),
              );
              if (hi > 25 * scale &&
                  lo < length - 25 * scale &&
                  cross(w.centerlineStart - start).abs() <
                      w.perpendicularDistance / 2) {
                blocked = true;
              }
            } else {
              final t = -cross(w.centerlineStart - start) / denominator;
              final along = dot(w.centerlineStart + v * t - start);
              if (t >= -0.05 &&
                  t <= 1.05 &&
                  along >= -25 * scale &&
                  along <= length + 25 * scale) {
                blocked = true;
              }
            }
            if (blocked) break;
          }
          if (!blocked) {
            // Project strictly along wall axis u so the hypothesis has zero transverse skew
            final tStart = dot(start - a.centerlineStart);
            final tEnd = dot(end - a.centerlineStart);
            final n = Offset(-u.dy, u.dx);
            final dAvg =
                (cross(start - a.centerlineStart) +
                    cross(end - a.centerlineStart)) /
                2.0;
            final projStart = a.centerlineStart + u * tStart - n * dAvg;
            final projEnd = a.centerlineStart + u * tEnd - n * dAvg;

            proposals.add(
              SlabGapHypothesis(
                projStart,
                projEnd,
                (a.perpendicularDistance + b.perpendicularDistance) / 2,
                i,
                j,
                wideOpeningEvidence: length > 1500 * scale,
                axisSupportIntersections: axisSupports,
              ),
            );
          }
        }
      }
      if (proposals.length > 2000) {
        return SlabWallRegions([], [], tooComplex: true);
      }
      // Competing proposals sharing a jamb are ambiguous; do not choose one.
      bool near(Offset a, Offset b) => (a - b).distance <= 25 * scale;
      final uniqueProposals = <SlabGapHypothesis>[];
      for (final p in proposals) {
        final isDup = uniqueProposals.any(
          (u) =>
              (near(u.start, p.start) && near(u.end, p.end)) ||
              (near(u.start, p.end) && near(u.end, p.start)),
        );
        if (!isDup) uniqueProposals.add(p);
      }
      allGaps.add(
        uniqueProposals
            .where(
              (p) => !uniqueProposals.any(
                (q) =>
                    !identical(p, q) &&
                    ((near(p.start, q.start) && !near(p.end, q.end)) ||
                        (near(p.start, q.end) && !near(p.end, q.start)) ||
                        (near(p.end, q.start) && !near(p.start, q.end)) ||
                        (near(p.end, q.end) && !near(p.start, q.start))),
              ),
            )
            .toList(),
      );
    }
    return SlabWallRegions(regions, allGaps);
  }
}
