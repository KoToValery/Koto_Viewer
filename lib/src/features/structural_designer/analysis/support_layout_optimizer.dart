import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import 'support_layout_evaluator.dart';
import 'support_placement_rules.dart';
import 'structural_polygon_distance.dart';
import 'wall_placement_domain.dart';

class LayoutSearchResult {
  final StoreyLevel floor;
  final SupportLayoutAssessment assessment;
  final int evaluations, acceptedChanges;
  final Map<String, int> evaluationsByOperation;
  final bool limited;
  const LayoutSearchResult(
    this.floor,
    this.assessment,
    this.evaluations,
    this.acceptedChanges,
    this.evaluationsByOperation,
    this.limited,
  );
}

class _SearchState {
  final StoreyLevel floor;
  final SupportLayoutAssessment assessment;
  final int changes;
  const _SearchState(this.floor, this.assessment, this.changes);
}

/// Bounded beam search with joint wall moves. Only newly proposed supports may
/// change; accepted/manual supports and all upper-level continuations stay fixed.
class SupportLayoutOptimizer {
  static LayoutSearchResult optimize({
    required StructuralProject project,
    required StoreyLevel fixedFloor,
    required List<StoreyLevel> seeds,
    required List<WallPairCandidate> wallPairs,
    required WallPlacementDomain domain,
    required double scale,
    required double minSpacingM,
    required double maxWallLengthM,
    required int maxEvaluations,
    double wallSpacingM = 2,
    double initialWallLengthM = 1.5,
    wallThicknessM = .25,
    bool adaptiveSizes = true,
    bool pairedWalls = true,
    ColumnShape columnShape = ColumnShape.rectangular,
    double columnWidthM = .25,
    double columnDepthM = .3,
    double columnThicknessM = .25,
  }) {
    final fixedIds = <String>{
      ...fixedFloor.columns.map((c) => c.id),
      ...fixedFloor.shearWalls.map((w) => w.id),
    };
    var evaluations = 0;
    final counts = <String, int>{}, cache = <String, _SearchState>{};
    String signature(StoreyLevel floor) {
      String p(Offset p) =>
          '${(p.dx / scale * 1e6).round()},${(p.dy / scale * 1e6).round()}';
      final parts = [
        ...floor.columns.map(
          (c) =>
              'c:${c.id}:${p(c.center)}:${(c.width / scale * 1e6).round()}:${(c.height / scale * 1e6).round()}:${(c.rotationRad * 1e8).round()}',
        ),
        ...floor.shearWalls.map(
          (w) =>
              'w:${w.id}:${p(w.start)}:${p(w.end)}:${(w.thickness / scale * 1e6).round()}',
        ),
      ]..sort();
      return parts.join(';');
    }

    _SearchState assess(StoreyLevel floor, int changes, String operation) {
      final key = signature(floor);
      final old = cache[key];
      if (old != null) return old;
      evaluations++;
      counts.update(operation, (n) => n + 1, ifAbsent: () => 1);
      final state = _SearchState(
        floor,
        SupportLayoutEvaluator.evaluate(project, floor, scale),
        changes,
      );
      cache[key] = state;
      return state;
    }

    var beam = [for (final seed in seeds) assess(seed, 0, 'seeds')]
      ..sort((a, b) => a.assessment.compareTo(b.assessment));
    if (beam.length > 3) beam = beam.take(3).toList();
    final runs =
        wallPairs
            .where(
              (w) =>
                  (w.centerlineEnd - w.centerlineStart).distance > .1 * scale,
            )
            .toList()
          ..sort((a, b) {
            final x = a.centerlineStart.dx.compareTo(b.centerlineStart.dx);
            return x != 0
                ? x
                : a.centerlineStart.dy.compareTo(b.centerlineStart.dy);
          });
    WallPairCandidate? runFor(Offset p, {Offset? direction}) {
      WallPairCandidate? best;
      var distance = .4 * scale;
      for (final r in runs) {
        final v = r.centerlineEnd - r.centerlineStart, u = v / v.distance;
        if (direction != null &&
            (u.dx * direction.dx + u.dy * direction.dy).abs() < .999) {
          continue;
        }
        final d = StructuralPolygonDistance.pointToSegment(
          p,
          r.centerlineStart,
          r.centerlineEnd,
        );
        if (d < distance) {
          distance = d;
          best = r;
        }
      }
      return best;
    }

    bool columnFits(StructuralColumn c, StoreyLevel f, {String? skipId}) =>
        SupportPlacementRules.reason(
          polygon: SupportPlacementRules.columnFootprint(c),
          center: c.center,
          isWall: false,
          floor: f,
          domain: domain,
          scale: scale,
          columnSpacingM: minSpacingM,
          wallSpacingM: wallSpacingM,
          skipId: skipId,
        ) ==
        null;
    bool wallFits(StructuralShearWall w, StoreyLevel f, {String? skipId}) =>
        w.length > 0 &&
        SupportPlacementRules.reason(
              polygon: w.polygonVertices,
              center: w.center,
              isWall: true,
              wallDirection: (w.end - w.start) / w.length,
              floor: f,
              domain: domain,
              scale: scale,
              columnSpacingM: minSpacingM,
              wallSpacingM: wallSpacingM,
              skipId: skipId,
            ) ==
            null;
    bool retainsColumnGrid(Offset before, Offset after, Offset direction) {
      for (final axis in fixedFloor.gridAxes) {
        final v = axis.end - axis.start;
        if (v.distance < 1e-8 * scale) continue;
        final u = v / v.distance;
        // An exactly aligned transverse row must survive local optimisation.
        // An axis parallel to the supporting wall does not restrict movement.
        if ((u.dx * direction.dx + u.dy * direction.dy).abs() > .1) continue;
        if (StructuralPolygonDistance.pointToSegment(
                  before,
                  axis.start,
                  axis.end,
                ) <=
                1e-6 * scale &&
            StructuralPolygonDistance.pointToSegment(
                  after,
                  axis.start,
                  axis.end,
                ) >
                1e-6 * scale) {
          return false;
        }
      }
      return true;
    }

    StoreyLevel replaceColumn(StoreyLevel f, StructuralColumn c) => f.copyWith(
      columns: [for (final old in f.columns) old.id == c.id ? c : old],
    );
    StoreyLevel replaceWall(StoreyLevel f, StructuralShearWall w) => f.copyWith(
      shearWalls: [for (final old in f.shearWalls) old.id == w.id ? w : old],
    );
    const operations = [
      'remove',
      'move-wall',
      'resize-wall',
      'move-column',
      'resize-column',
      'add-column',
      'add-wall',
      'paired-walls',
    ];
    final perOperation = math.max(
      1,
      (maxEvaluations - seeds.length) ~/ operations.length,
    );
    Iterable<StoreyLevel> neighbors(
      _SearchState state,
      String operation,
    ) sync* {
      final floor = state.floor;
      final cols = floor.columns
          .where((c) => !fixedIds.contains(c.id))
          .toList();
      final walls = floor.shearWalls
          .where((w) => !fixedIds.contains(w.id))
          .toList();
      // Rotate the traversal deterministically after an accepted change so an
      // evaluation quota cannot always be spent on the first support in a list.
      if (cols.isNotEmpty) {
        final n = state.changes % cols.length;
        cols.addAll(cols.take(n).toList());
        cols.removeRange(0, n);
      }
      if (walls.isNotEmpty) {
        final n = state.changes % walls.length;
        walls.addAll(walls.take(n).toList());
        walls.removeRange(0, n);
      }
      if (operation == 'remove') {
        for (final c in cols.reversed) {
          yield floor.copyWith(
            columns: floor.columns.where((old) => old.id != c.id).toList(),
          );
        }
        for (final w in walls.reversed) {
          if (pairedWalls) {
            final u = (w.end - w.start) / w.length;
            final same = floor.shearWalls
                .where(
                  (other) =>
                      other.length > 0 &&
                      (((other.end - other.start) / other.length).dx * u.dx +
                                  ((other.end - other.start) / other.length)
                                          .dy *
                                      u.dy)
                              .abs() >=
                          .9239,
                )
                .length;
            if (same <= 2) continue;
          }
          yield floor.copyWith(
            shearWalls: floor.shearWalls
                .where((old) => old.id != w.id)
                .toList(),
          );
        }
      } else if (operation == 'move-column' || operation == 'resize-column') {
        for (final c in cols) {
          final r = runFor(c.center);
          if (r == null) continue;
          final v = r.centerlineEnd - r.centerlineStart, u = v / v.distance;
          if (operation == 'move-column') {
            for (final delta in [.5, -.5, .25, -.25]) {
              final trial = c.copyWith(center: c.center + u * (delta * scale));
              if (retainsColumnGrid(c.center, trial.center, u) &&
                  columnFits(trial, floor, skipId: c.id)) {
                yield replaceColumn(floor, trial);
              }
            }
          } else if (adaptiveSizes && c.shape == ColumnShape.rectangular) {
            for (final delta in [.05, -.05]) {
              final h = c.height + delta * scale;
              if (h < .2 * scale || h > .8 * scale) continue;
              final trial = c.copyWith(height: h);
              if (columnFits(trial, floor, skipId: c.id)) {
                yield replaceColumn(floor, trial);
              }
            }
          }
        }
      } else if (operation == 'move-wall' || operation == 'resize-wall') {
        for (final w in walls) {
          final u = (w.end - w.start) / w.length;
          if (operation == 'move-wall') {
            for (final delta in [1.0, -1.0, .5, -.5]) {
              final trial = w.copyWith(
                start: w.start + u * (delta * scale),
                end: w.end + u * (delta * scale),
              );
              if (wallFits(trial, floor, skipId: w.id)) {
                yield replaceWall(floor, trial);
              }
            }
          } else if (adaptiveSizes) {
            for (final delta in [.1, -.1]) {
              final length = w.length + delta * scale;
              if (length < scale ||
                  length > maxWallLengthM * scale + 1e-8 * scale) {
                continue;
              }
              final trial = w.copyWith(
                start: w.center - u * length / 2,
                end: w.center + u * length / 2,
              );
              if (wallFits(trial, floor, skipId: w.id)) {
                yield replaceWall(floor, trial);
              }
            }
          }
        }
      } else if (operation == 'paired-walls') {
        for (var i = 0; i < walls.length; i++) {
          for (var j = 0; j < i; j++) {
            final a = walls[i],
                b = walls[j],
                u = (a.end - a.start) / a.length,
                v = (b.end - b.start) / b.length;
            for (final delta in [.5, -.5]) {
              final x = a.copyWith(
                start: a.start + u * (delta * scale),
                end: a.end + u * (delta * scale),
              );
              final y = b.copyWith(
                start: b.start - v * (delta * scale),
                end: b.end - v * (delta * scale),
              );
              final trial = replaceWall(replaceWall(floor, x), y);
              if (wallFits(x, trial, skipId: x.id) &&
                  wallFits(y, trial, skipId: y.id)) {
                yield trial;
              }
            }
          }
        }
      } else if (operation == 'add-wall') {
        if (floor.columns.length + floor.shearWalls.length >= 300) return;
        final boundaryTargets = state.assessment.boundaries
            .where((b) => b.requiresReview)
            .map((b) => b.point)
            .toList();
        double boundaryDistance(WallPairCandidate r) => boundaryTargets.isEmpty
            ? double.infinity
            : boundaryTargets
                  .map(
                    (p) => StructuralPolygonDistance.pointToSegment(
                      p,
                      r.centerlineStart,
                      r.centerlineEnd,
                    ),
                  )
                  .reduce(math.min);
        double clearance(WallPairCandidate r) => floor.shearWalls.isEmpty
            ? (r.centerlineEnd - r.centerlineStart).distance
            : floor.shearWalls
                  .map(
                    (w) =>
                        (w.center - (r.centerlineStart + r.centerlineEnd) / 2)
                            .distance,
                  )
                  .reduce(math.min);
        final ordered = [...runs]
          ..sort((a, b) {
            final edgeDelta = boundaryDistance(a) - boundaryDistance(b);
            if (edgeDelta.isFinite && edgeDelta.abs() > 1e-8 * scale) {
              return edgeDelta.sign.toInt();
            }
            final delta = clearance(b) - clearance(a);
            return delta.abs() > 1e-8 * scale
                ? delta.sign.toInt()
                : runs.indexOf(a).compareTo(runs.indexOf(b));
          });
        for (final r in ordered.take(8)) {
          final v = r.centerlineEnd - r.centerlineStart, u = v / v.distance;
          // Use the same 1 m lower bound as the seed generator. Short solid
          // facade segments must remain candidates when adaptive sizing is on.
          final longest = math.min(
            initialWallLengthM * scale,
            math.min(maxWallLengthM * scale, v.distance),
          );
          final lengths = adaptiveSizes
              ? <double>{longest, math.min(longest, 1.25 * scale), scale}
              : <double>{initialWallLengthM * scale};
          for (final length in lengths) {
            if (length < scale - 1e-8 * scale ||
                length > v.distance ||
                length > maxWallLengthM * scale) {
              continue;
            }
            final thickness = adaptiveSizes
                ? math.min(
                    wallThicknessM * scale,
                    ((r.perpendicularDistance / scale + 1e-8) / .05).floor() *
                        .05 *
                        scale,
                  )
                : wallThicknessM * scale;
            if (thickness < .2 * scale - 1e-8 * scale) continue;
            final fractions = [
              for (final p in boundaryTargets)
                (((p - r.centerlineStart).dx * u.dx +
                            (p - r.centerlineStart).dy * u.dy -
                            length / 2) /
                        (v.distance - length))
                    .clamp(0.0, 1.0),
              .5,
              .25,
              .75,
            ].where((f) => f.isFinite).toSet();
            for (final fraction in fractions) {
              final center =
                  r.centerlineStart +
                  u * (length / 2 + (v.distance - length) * fraction);
              final w = StructuralShearWall(
                id: 'scheme:${floor.id}:search-w:${(center.dx / scale * 1e6).round()},${(center.dy / scale * 1e6).round()}',
                start: center - u * length / 2,
                end: center + u * length / 2,
                thickness: thickness,
                generatedBy: 'initial-scheme-optimized',
              );
              if (wallFits(w, floor)) {
                yield floor.copyWith(shearWalls: [...floor.shearWalls, w]);
              }
            }
          }
        }
      } else if (operation == 'add-column') {
        if (floor.columns.length + floor.shearWalls.length >= 300) return;
        final targets = [
          ...state.assessment.openings
              .where((p) => p.requiresReview)
              .map((p) => p.point),
          ...state.assessment.spans
              .take(4)
              .map((s) => (s.segment.$1 + s.segment.$2) / 2),
        ];
        for (final target in targets) {
          final ordered = [...runs]
            ..sort((a, b) {
              final delta =
                  StructuralPolygonDistance.pointToSegment(
                    target,
                    a.centerlineStart,
                    a.centerlineEnd,
                  ) -
                  StructuralPolygonDistance.pointToSegment(
                    target,
                    b.centerlineStart,
                    b.centerlineEnd,
                  );
              return delta.abs() > 1e-8 * scale
                  ? delta.sign.toInt()
                  : runs.indexOf(a).compareTo(runs.indexOf(b));
            });
          for (final r in ordered.take(4)) {
            final d = r.centerlineEnd - r.centerlineStart, u = d / d.distance;
            final width =
                columnShape != ColumnShape.rectangular || !adaptiveSizes
                ? columnWidthM
                : math.min(
                    math.min(columnWidthM, columnDepthM),
                    ((r.perpendicularDistance / scale + 1e-8) / .05).floor() *
                        .05,
                  );
            if (width < .2) continue;
            final depth =
                (adaptiveSizes && columnShape == ColumnShape.rectangular
                    ? math.max(columnWidthM, columnDepthM)
                    : columnDepthM) *
                scale;
            final margin = depth / 2;
            if (d.distance < 2 * margin) continue;
            final along =
                ((target - r.centerlineStart).dx * u.dx +
                        (target - r.centerlineStart).dy * u.dy)
                    .clamp(margin, d.distance - margin);
            final center = r.centerlineStart + u * along.toDouble();
            final id =
                'scheme:${floor.id}:search-c:${(center.dx / scale * 1e6).round()},${(center.dy / scale * 1e6).round()}';
            if (floor.columns.any((c) => c.id == id)) continue;
            final c = StructuralColumn(
              id: id,
              center: center,
              width: width * scale,
              height: depth,
              shape: columnShape,
              thickness: columnThicknessM * scale,
              rotationRad: math.atan2(u.dy, u.dx) + math.pi / 2,
              generatedBy: 'initial-scheme-optimized',
            );
            if (columnFits(c, floor)) {
              yield floor.copyWith(columns: [...floor.columns, c]);
            }
          }
        }
      }
    }

    var exhausted = false;
    for (var round = 0; round < 4 && evaluations < maxEvaluations; round++) {
      final contenders = [...beam];
      var changed = false;
      for (final operation in operations) {
        for (final state in beam) {
          var perState = 0;
          for (final floor in neighbors(state, operation)) {
            if (evaluations >= maxEvaluations ||
                (round < 2 && (counts[operation] ?? 0) >= perOperation)) {
              exhausted = true;
              break;
            }
            if (cache.containsKey(signature(floor))) continue;
            final next = assess(floor, state.changes + 1, operation);
            contenders.add(next);
            changed = true;
            if (++perState >= 2) break;
          }
        }
      }
      contenders.sort((a, b) => a.assessment.compareTo(b.assessment));
      final seen = <String>{};
      beam = contenders
          .where((s) => seen.add(signature(s.floor)))
          .take(3)
          .toList();
      // Reserve two rounds for every operation, then let feasible operations
      // use the remaining total budget instead of abandoning it at a quota.
      if (!changed && round >= 2) break;
    }
    final best = beam.first;
    return LayoutSearchResult(
      best.floor,
      best.assessment,
      evaluations,
      best.changes,
      Map.unmodifiable(counts),
      exhausted || evaluations >= maxEvaluations,
    );
  }
}
