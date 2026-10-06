import 'dart:math' as math;
import 'dart:ui';
import '../models/wall_axis_models.dart';
import 'slab_opening_evidence.dart';

class SlabGapHypothesis {
  final Offset start, end;
  final double thickness;
  final int wallA, wallB;
  final bool wideOpeningEvidence;
  const SlabGapHypothesis(
    this.start,
    this.end,
    this.thickness,
    this.wallA,
    this.wallB, {
    this.wideOpeningEvidence = false,
  });
  Map<String, dynamic> toJson() => {
    'start': [start.dx, start.dy],
    'end': [end.dx, end.dy],
    'thickness': thickness,
    'walls': [wallA, wallB],
    'reason': wideOpeningEvidence
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

    final boxes = walls
        .map(
          (w) => Rect.fromPoints(
            w.centerlineStart,
            w.centerlineEnd,
          ).inflate(w.perpendicularDistance / 2 + 750 * scale),
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
      for (var i = 0; i < group.length; i++) {
        final a = group[i], d = a.centerlineEnd - a.centerlineStart;
        if (d.distance < 100 * scale) continue;
        final u = d / d.distance;
        double dot(Offset p) => p.dx * u.dx + p.dy * u.dy;
        double cross(Offset p) => p.dx * u.dy - p.dy * u.dx;
        for (var j = i + 1; j < group.length; j++) {
          if (++comparisons > 2000000) {
            return SlabWallRegions([], [], tooComplex: true);
          }
          final b = group[j], e = b.centerlineEnd - b.centerlineStart;
          if (e.distance < 100 * scale ||
              cross(e / e.distance).abs() > 0.01745) {
            continue;
          }
          if (a.segmentA.sourceLayer != b.segmentA.sourceLayer ||
              (a.perpendicularDistance - b.perpendicularDistance).abs() >
                  20 * scale) {
            continue;
          }
          if (cross(b.centerlineStart - a.centerlineStart).abs() > 15 * scale ||
              cross(b.centerlineEnd - a.centerlineStart).abs() > 15 * scale) {
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
          if (length < 75 * scale || length > 4500 * scale) continue;
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
            proposals.add(
              SlabGapHypothesis(
                start,
                end,
                (a.perpendicularDistance + b.perpendicularDistance) / 2,
                i,
                j,
                wideOpeningEvidence: length > 1500 * scale,
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
      allGaps.add(
        proposals
            .where(
              (p) => !proposals.any(
                (q) =>
                    !identical(p, q) &&
                    (near(p.start, q.start) ||
                        near(p.start, q.end) ||
                        near(p.end, q.start) ||
                        near(p.end, q.end)),
              ),
            )
            .toList(),
      );
    }
    return SlabWallRegions(regions, allGaps);
  }
}
