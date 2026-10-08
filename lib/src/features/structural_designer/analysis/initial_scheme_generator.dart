import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import 'structural_scheme_readiness.dart';
import 'slab_contact_geometry.dart';
import 'slab_topology_analyzer.dart';
import 'structural_polygon_distance.dart';

class InitialSchemeOptions {
  final double minSpacingM, targetSpacingM, wallLengthM;
  final double columnWidthM, columnDepthM, wallThicknessM;
  final ColumnShape columnShape;
  final double columnThicknessM;
  final bool enforcePairedWalls, generousDensity;
  const InitialSchemeOptions({
    this.columnShape = ColumnShape.rectangular,
    this.columnThicknessM = .25,
    this.minSpacingM = 2,
    this.targetSpacingM = 5,
    this.wallLengthM = 1.5,
    this.columnWidthM = .25,
    this.columnDepthM = .3,
    this.wallThicknessM = .25,
    this.enforcePairedWalls = true,
    this.generousDensity = true,
  });
  bool get valid =>
      [
        minSpacingM,
        targetSpacingM,
        wallLengthM,
        columnThicknessM,
        columnWidthM,
        columnDepthM,
        wallThicknessM,
      ].every((v) => v.isFinite && v > 0) &&
      targetSpacingM >= minSpacingM;
}

class InitialSchemeProposal {
  final List<StructuralColumn> columns;
  final List<StructuralShearWall> walls;
  final int unresolvedRegions, rejectedCandidates;
  final bool limited;

  /// Geometric coverage only: these are not spans or calculated deflections.
  final int uncoveredSamples;
  final double maxSupportDistanceM;
  final List<Offset> uncoveredPoints;
  const InitialSchemeProposal({
    this.columns = const [],
    this.walls = const [],
    this.unresolvedRegions = 0,
    this.rejectedCandidates = 0,
    this.limited = false,
    this.uncoveredSamples = 0,
    this.maxSupportDistanceM = 0,
    this.uncoveredPoints = const [],
  });
  bool get isEmpty => columns.isEmpty && walls.isEmpty;
  StoreyLevel apply(StoreyLevel floor) => floor.copyWith(
    columns: [
      ...floor.columns,
      ...columns.where((c) => !floor.columns.any((old) => old.id == c.id)),
    ],
    shearWalls: [
      ...floor.shearWalls,
      ...walls.where((w) => !floor.shearWalls.any((old) => old.id == w.id)),
    ],
  );
}

class _WallRun {
  final Offset a, b;
  final double width;
  const _WallRun(this.a, this.b, this.width);
  Offset get u => (b - a) / (b - a).distance;
  Offset get center => (a + b) / 2;
  double get length => (b - a).distance;
}

/// Bounded, deterministic preliminary layout. Wall runs preserve opening gaps;
/// explicit grid axes also provide column candidates, but never wall evidence.
class InitialSchemeGenerator {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static InitialSchemeProposal generate({
    required StructuralProject project,
    required List<WallPairCandidate> wallPairs,
    required double scale,
    InitialSchemeOptions options = const InitialSchemeOptions(),
    int variant = 0,
  }) {
    if (!options.valid ||
        !StructuralSchemeReadiness.evaluate(project, scale).geometryReady) {
      return const InitialSchemeProposal();
    }
    final floor = project.activeStorey;
    if (wallPairs.length > 800 ||
        project.effectiveGridAxes.length > 120 ||
        floor.columns.length + floor.shearWalls.length > 500) {
      return const InitialSchemeProposal(limited: true);
    }
    // Normalize sub-nanometre arithmetic noise before formatting stable IDs.
    String coordinate(double x) =>
        ((x / scale * 1e9).round() / 1e9).toStringAsFixed(4);
    String point(Offset p) => '${coordinate(p.dx)},${coordinate(p.dy)}';
    final runs = <_WallRun>[];
    final seen = <String>{};
    for (final w in wallPairs) {
      var a = w.centerlineStart, b = w.centerlineEnd;
      if (![
            a.dx,
            a.dy,
            b.dx,
            b.dy,
            w.perpendicularDistance,
          ].every((x) => x.isFinite) ||
          (b - a).distance < .1 * scale ||
          w.perpendicularDistance <= 0) {
        continue;
      }
      if (a.dx > b.dx || (a.dx == b.dx && a.dy > b.dy)) {
        final t = a;
        a = b;
        b = t;
      }
      if (seen.add('${point(a)}:${point(b)}')) {
        runs.add(_WallRun(a, b, w.perpendicularDistance));
      }
    }
    runs.sort(
      (a, b) => ('${point(a.a)}:${point(a.b)}').compareTo(
        '${point(b.a)}:${point(b.b)}',
      ),
    );
    final regions = SlabTopologyAnalyzer.analyze(floor.slabs, scale).regions;
    final cols = <StructuralColumn>[], walls = <StructuralShearWall>[];
    final occupied = <List<Offset>>[
      ...floor.columns.map((c) => c.polygonVertices),
      ...floor.shearWalls.map((w) => w.polygonVertices),
    ];
    final centers = <Offset>[
      ...floor.columns.map((c) => c.center),
      ...floor.shearWalls.map((w) => w.center),
    ];
    final ids = <String>{
      ...floor.columns.map((c) => c.id),
      ...floor.shearWalls.map((w) => w.id),
    };
    int rejected = 0, attempts = 0;
    final directionCoverage = <int, Set<int>>{};
    int regionOf(List<Offset> poly) {
      final area = StructuralSlab.calculateArea(poly) / (scale * scale);
      if (!area.isFinite || area <= 1e-10) return -1;
      for (var r = 0; r < regions.length; r++) {
        final contact = SlabContactGeometry.measure(poly, [
          for (final i in regions[r]) floor.slabs[i],
        ], scale);
        if (contact != null &&
            (contact.areaM2 - area).abs() <= math.max(1e-10, area * 1e-7)) {
          return r;
        }
      }
      return -1;
    }

    bool onRun(List<Offset> poly, _WallRun run) {
      // Longitudinal footprint must not extend into a door/window gap.
      return poly.every((p) {
        final along = dot(p - run.a, run.u);
        return along >= -1e-8 * scale && along <= run.length + 1e-8 * scale;
      });
    }

    bool allowed(List<Offset> poly, Offset center) {
      if (++attempts > 20000) return false;
      if (floor.slabs.any(
            (s) => s.openings.any(
              (hole) =>
                  StructuralPolygonDistance.between(poly, hole) <= 1e-7 * scale,
            ),
          ) ||
          regionOf(poly) < 0 ||
          occupied.any(
            (p) => StructuralPolygonDistance.between(p, poly) < .05 * scale,
          ) ||
          centers.any(
            (p) => (p - center).distance < options.minSpacingM * scale,
          )) {
        rejected++;
        return false;
      }
      return true;
    }

    _WallRun? nearRun(Offset p) {
      _WallRun? best;
      var dist = math.max(.35 * scale, options.wallThicknessM * scale);
      for (final run in runs) {
        final d = StructuralPolygonDistance.pointToSegment(p, run.a, run.b);
        if (d < dist) {
          best = run;
          dist = d;
        }
      }
      return best;
    }

    // An explicit axis does not authorize filling a detected wall opening.
    bool inWallGap(Offset p, Offset u) {
      var before = false, after = false;
      for (final run in runs) {
        if (dot(run.u, u).abs() < .99 ||
            cross(p - run.a, u).abs() > .2 * scale) {
          continue;
        }
        final a = dot(run.a - p, u), b = dot(run.b - p, u);
        if (math.max(a, b) < 0) before = true;
        if (math.min(a, b) > 0) after = true;
      }
      return before && after;
    }

    bool inAnyWallGap(Offset p) => runs
        .where((r) => cross(p - r.a, r.u).abs() <= .2 * scale)
        .any((r) => inWallGap(p, r.u));

    void addColumn(
      Offset p, {
      StructuralColumn? continuation,
      _WallRun? preferredRun,
      Offset? axisDirection,
    }) {
      if (cols.length + walls.length >= 300 || attempts > 20000) return;
      final run = preferredRun ?? nearRun(p);
      if (run == null &&
          (axisDirection == null ||
              inWallGap(p, axisDirection) ||
              inAnyWallGap(p))) {
        return;
      }
      final u = run?.u ?? axisDirection!;
      // Preserve lower support center; other candidates project onto wall axis.
      final center = continuation != null
          ? p
          : run == null
          ? p
          : run.a + run.u * dot(p - run.a, run.u);
      final id = 'scheme:${floor.id}:c:${point(center)}';
      if (ids.contains(id)) return;
      final c =
          continuation?.copyWith(
            id: id,
            center: center,
            generatedBy: 'initial-scheme-v1',
          ) ??
          StructuralColumn(
            id: id,
            center: center,
            shape: options.columnShape,
            thickness: options.columnThicknessM * scale,
            width: options.columnWidthM * scale,
            height: options.columnDepthM * scale,
            rotationRad: math.atan2(u.dy, u.dx),
            generatedBy: 'initial-scheme-v1',
          );
      if ((run == null && c.polygonVertices.any(inAnyWallGap)) ||
          (run != null && !onRun(c.polygonVertices, run)) ||
          !allowed(c.polygonVertices, center)) {
        return;
      }
      cols.add(c);
      occupied.add(c.polygonVertices);
      centers.add(center);
      ids.add(id);
    }

    final lower =
        project.storeys
            .where((s) => s.elevation < floor.elevation - 1e-6)
            .toList()
          ..sort((a, b) => b.elevation.compareTo(a.elevation));
    if (lower.isNotEmpty) {
      final sorted = List<StructuralColumn>.of(lower.first.columns)
        ..sort((a, b) => point(a.center).compareTo(point(b.center)));
      for (final c in sorted) {
        addColumn(c.center, continuation: c);
      }
    }
    final longest = List<_WallRun>.of(runs)
      ..sort((a, b) => b.length.compareTo(a.length));
    final primary = longest.isEmpty ? const Offset(1, 0) : longest.first.u;
    // Irrational phase provides reproducible alternatives beyond two presets.
    final perp = Offset(-primary.dy, primary.dx);
    final layoutSpacingM = options.generousDensity
        ? math.max(options.minSpacingM, math.min(options.targetSpacingM, 3.5))
        : options.targetSpacingM;
    final phase = (math.max(0, variant) * .6180339887498949) % 1;
    int direction(_WallRun r) => dot(r.u, primary).abs() >= .9239
        ? 0
        : cross(r.u, primary).abs() >= .9239
        ? 1
        : 2;
    int elementDirection(Offset u) => dot(u, primary).abs() >= .9239
        ? 0
        : cross(u, primary).abs() >= .9239
        ? 1
        : 2;

    final stairRings = <List<Offset>>[
      for (final s in floor.slabs)
        for (var i = 0; i < s.openings.length; i++)
          if (s.getOpeningType(i) == SlabOpeningType.staircase ||
              s.getOpeningType(i) == SlabOpeningType.elevator)
            s.openings[i],
    ];
    double stairDistance(_WallRun run) =>
        stairRings
            .expand((p) => p)
            .map(
              (p) => StructuralPolygonDistance.pointToSegment(p, run.a, run.b),
            )
            .fold(double.infinity, math.min) /
        scale;
    final wallRuns = List<_WallRun>.of(runs);
    wallRuns.sort((a, b) {
      final av = stairDistance(a);
      final bv = stairDistance(b);
      final d = av.compareTo(bv);
      return d != 0 ? d : point(a.a).compareTo(point(b.a));
    });
    // Continue admissible lower walls before introducing new wall positions.
    if (lower.isNotEmpty) {
      final oldWalls = List<StructuralShearWall>.of(lower.first.shearWalls)
        ..sort((a, b) => point(a.center).compareTo(point(b.center)));
      for (final old in oldWalls) {
        if (cols.length + walls.length >= 300 || attempts > 20000) break;
        if (old.length <= 0) continue;
        final run = nearRun(old.center);
        if (run == null ||
            dot((old.end - old.start) / old.length, run.u).abs() < .99 ||
            !onRun(old.polygonVertices, run)) {
          continue;
        }
        final id = 'scheme:${floor.id}:w:${point(old.start)}:${point(old.end)}';
        if (ids.contains(id) || !allowed(old.polygonVertices, old.center)) {
          continue;
        }
        final w = old.copyWith(id: id, generatedBy: 'initial-scheme-v1');
        walls.add(w);
        occupied.add(w.polygonVertices);
        centers.add(w.center);
        ids.add(id);
      }
    }
    for (final w in [...floor.shearWalls, ...walls]) {
      final r = regionOf(w.polygonVertices);
      if (r >= 0 && w.length > 0) {
        final u = (w.end - w.start) / w.length;
        directionCoverage
            .putIfAbsent(r, () => {})
            .add(
              dot(u, primary).abs() >= .9239
                  ? 0
                  : cross(u, primary).abs() >= .9239
                  ? 1
                  : 2,
            );
      }
    }
    for (final run in wallRuns) {
      if (walls.length + cols.length >= 300 || attempts > 20000) break;
      if (stairDistance(run) > 1.5 ||
          run.length < options.wallLengthM * scale ||
          direction(run) > 1) {
        continue;
      }
      final half = options.wallLengthM * scale / 2;
      final core = stairDistance(run) <= 1.5;
      final positions = <double>[
        if (core)
          for (final ring in stairRings)
            for (var i = 0; i < ring.length; i++)
              dot(
                (ring[i] + ring[(i + 1) % ring.length]) / 2 - run.a,
                run.u,
              ).clamp(half, run.length - half),
        half + (run.length - 2 * half) * (variant == 0 ? .5 : phase),
        half,
        run.length - half,
      ];
      // Try windows along the run: its midpoint may be inside the staircase.
      for (final along in positions) {
        final center = run.a + run.u * along;
        final w = StructuralShearWall(
          id: 'scheme:${floor.id}:w:${point(center)}',
          start: center - run.u * half,
          end: center + run.u * half,
          thickness: options.wallThicknessM * scale,
          generatedBy: 'initial-scheme-v1',
        );
        final r = regionOf(w.polygonVertices);
        if (r < 0 ||
            ids.contains(w.id) ||
            !onRun(w.polygonVertices, run) ||
            !allowed(w.polygonVertices, center)) {
          continue;
        }
        walls.add(w);
        occupied.add(w.polygonVertices);
        centers.add(center);
        ids.add(w.id);
        directionCoverage.putIfAbsent(r, () => {}).add(direction(run));
        break;
      }
    }
    Offset regionCentroid(int r) {
      double sumA = 0, sumX = 0, sumY = 0;
      for (final idx in regions[r]) {
        final slab = floor.slabs[idx];
        final a = StructuralSlab.calculateArea(slab.polygon);
        if (a <= 0) continue;
        double cx = 0, cy = 0;
        for (final pt in slab.polygon) {
          cx += pt.dx;
          cy += pt.dy;
        }
        cx /= slab.polygon.length;
        cy /= slab.polygon.length;
        sumA += a;
        sumX += cx * a;
        sumY += cy * a;
      }
      return sumA > 0 ? Offset(sumX / sumA, sumY / sumA) : Offset.zero;
    }

    double regionAreaM2(int r) {
      double sumA = 0;
      for (final idx in regions[r]) {
        sumA +=
            StructuralSlab.calculateArea(floor.slabs[idx].polygon) /
            (scale * scale);
      }
      return sumA;
    }

    int existingWallsInDir(int reg, int d) {
      return [...floor.shearWalls, ...walls].where((w) {
        if (w.length <= 0 || regionOf(w.polygonVertices) != reg) return false;
        final u = (w.end - w.start) / w.length;
        return elementDirection(u) == d;
      }).length;
    }

    bool tryAddWall(
      _WallRun run,
      int r,
      int d, {
      double minWallSpacingM = 3.5,
      double? overrideLengthM,
    }) {
      if (walls.length + cols.length >= 300 || attempts > 20000) return false;
      final targetLenM = overrideLengthM ?? options.wallLengthM;
      if (run.length < targetLenM * scale) return false;
      final half = targetLenM * scale / 2;
      final positions = <double>[
        half + (run.length - 2 * half) * (variant == 0 ? .5 : phase),
        half,
        run.length - half,
      ];
      for (final along in positions) {
        final center = run.a + run.u * along;
        final w = StructuralShearWall(
          id: 'scheme:${floor.id}:w:${point(center)}',
          start: center - run.u * (targetLenM * scale / 2),
          end: center + run.u * (targetLenM * scale / 2),
          thickness: options.wallThicknessM * scale,
          generatedBy: 'initial-scheme-v1',
        );
        if (ids.contains(w.id)) continue;
        if (regionOf(w.polygonVertices) != r) continue;
        if (!onRun(w.polygonVertices, run)) continue;

        // Spacing check against existing shear walls in the SAME direction
        final sameDirWalls = [...floor.shearWalls, ...walls].where((existing) {
          if (existing.length <= 0 || regionOf(existing.polygonVertices) != r) {
            return false;
          }
          final u = (existing.end - existing.start) / existing.length;
          return elementDirection(u) == d;
        });
        if (sameDirWalls.any(
          (other) => (other.center - center).distance < minWallSpacingM * scale,
        )) {
          continue;
        }
        if (!allowed(w.polygonVertices, center)) continue;

        walls.add(w);
        occupied.add(w.polygonVertices);
        centers.add(center);
        ids.add(w.id);
        directionCoverage.putIfAbsent(r, () => {}).add(d);
        return true;
      }
      return false;
    }

    // Shear wall pairing engine
    for (var r = 0; r < regions.length; r++) {
      final cm = regionCentroid(r);
      final area = regionAreaM2(r);

      for (final dir in [0, 1]) {
        final currentCount = existingWallsInDir(r, dir);
        final targetCount = options.enforcePairedWalls
            ? (options.generousDensity && area > 140 ? 4 : 2)
            : 2;
        if (currentCount >= targetCount) continue;

        final primaryRuns = runs
            .where(
              (run) =>
                  direction(run) == dir &&
                  run.length >= options.wallLengthM * scale,
            )
            .toList();

        final fallbackRuns = runs
            .where(
              (run) =>
                  direction(run) == dir &&
                  run.length < options.wallLengthM * scale &&
                  run.length >=
                      math.max(1.0, options.wallLengthM * 0.75) * scale,
            )
            .toList();

        List<_WallRun> orderPairCandidates(List<_WallRun> candList) {
          final posGroup = <_WallRun>[];
          final negGroup = <_WallRun>[];
          for (final run in candList) {
            final trans = dir == 0
                ? dot(run.center - cm, perp) / scale
                : dot(run.center - cm, primary) / scale;
            if (trans >= 0) {
              posGroup.add(run);
            } else {
              negGroup.add(run);
            }
          }
          if (variant % 2 == 0) {
            posGroup.sort((a, b) {
              final d = stairDistance(a).compareTo(stairDistance(b));
              return d != 0 ? d : point(a.a).compareTo(point(b.a));
            });
            negGroup.sort((a, b) {
              final d = stairDistance(a).compareTo(stairDistance(b));
              return d != 0 ? d : point(a.a).compareTo(point(b.a));
            });
          } else {
            posGroup.sort((a, b) {
              final d = (b.length / scale).compareTo(a.length / scale);
              return d != 0 ? d : point(a.a).compareTo(point(b.a));
            });
            negGroup.sort((a, b) {
              final d = (b.length / scale).compareTo(a.length / scale);
              return d != 0 ? d : point(a.a).compareTo(point(b.a));
            });
          }
          final interleaved = <_WallRun>[];
          var pIdx = 0, nIdx = 0;
          while (pIdx < posGroup.length || nIdx < negGroup.length) {
            if (pIdx < posGroup.length) interleaved.add(posGroup[pIdx++]);
            if (nIdx < negGroup.length) interleaved.add(negGroup[nIdx++]);
          }
          return interleaved;
        }

        final ordered = orderPairCandidates(primaryRuns);

        // Pass 1: Try placing paired walls at standard spacing
        for (final run in ordered) {
          if (existingWallsInDir(r, dir) >= targetCount) break;
          tryAddWall(
            run,
            r,
            dir,
            minWallSpacingM: math.min(options.targetSpacingM, 3.5),
          );
        }

        // Pass 2 (Rescue): If pairing is enforced and we placed exactly 1 wall (odd/unpaired!),
        // actively find the 2nd matching wall with relaxed spacing and relaxed length
        if (options.enforcePairedWalls && existingWallsInDir(r, dir) == 1) {
          for (final run in ordered) {
            if (existingWallsInDir(r, dir) >= 2) break;
            tryAddWall(
              run,
              r,
              dir,
              minWallSpacingM: math.max(options.minSpacingM * 1.2, 2.5),
            );
          }
        }
        if (options.enforcePairedWalls && existingWallsInDir(r, dir) == 1) {
          final fallbackOrdered = orderPairCandidates(fallbackRuns);
          for (final run in fallbackOrdered) {
            if (existingWallsInDir(r, dir) >= 2) break;
            tryAddWall(
              run,
              r,
              dir,
              minWallSpacingM: math.max(options.minSpacingM * 1.2, 2.5),
              overrideLengthM: math.max(1.0, options.wallLengthM * 0.75),
            );
          }
        }
      }
    }

    // Where a core wall cannot fit, try columns along its actual solid runs.
    for (final run in wallRuns.where((r) => stairDistance(r) <= 1.5)) {
      final margin =
          math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
      if (run.length < 2 * margin) continue;
      for (final ring in stairRings) {
        for (final p in ring) {
          final along = dot(
            p - run.a,
            run.u,
          ).clamp(margin, run.length - margin);
          addColumn(run.a + run.u * along, preferredRun: run);
        }
      }
    }
    // Column placement
    // 1. Exterior slab corners
    for (final slab in floor.slabs) {
      final poly = slab.polygon;
      final n = poly.length;
      if (n < 3) continue;
      for (var i = 0; i < n; i++) {
        final curr = poly[i];
        final run = nearRun(curr);
        if (run != null) {
          final margin =
              math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
          final along = dot(
            curr - run.a,
            run.u,
          ).clamp(margin, math.max(margin, run.length - margin)).toDouble();
          addColumn(run.a + run.u * along);
        }
      }
    }

    final axes = List<StructuralGridAxis>.of(project.effectiveGridAxes)
      ..sort((a, b) => a.id.compareTo(b.id));
    for (var i = 0; i < axes.length; i++) {
      for (var j = 0; j < i; j++) {
        final a = axes[i],
            b = axes[j],
            u = a.end - a.start,
            v = b.end - b.start;
        final den = cross(u, v);
        if (den.abs() < 1e-8 * u.distance * v.distance) continue;
        final t = cross(b.start - a.start, v) / den,
            s = cross(b.start - a.start, u) / den;
        if (t >= 0 && t <= 1 && s >= 0 && s <= 1) {
          final p = a.start + u * t;
          if (!inWallGap(p, u / u.distance) && !inWallGap(p, v / v.distance)) {
            addColumn(p, axisDirection: u / u.distance);
          }
        }
      }
    }
    // 4. Exact and fuzzy wall junctions
    var junctionWork = 0;
    for (var i = 0; i < runs.length && junctionWork < 50000; i++) {
      for (var j = 0; j < i && junctionWork < 50000; j++) {
        junctionWork++;
        if (cols.length + walls.length >= 300 || attempts > 20000) break;
        final a = runs[i], b = runs[j], u = a.b - a.a, v = b.b - b.a;
        final den = cross(u, v);
        if (den.abs() > 1e-8 * u.distance * v.distance) {
          final t = cross(b.a - a.a, v) / den;
          final s = cross(b.a - a.a, u) / den;
          if (t >= -0.15 && t <= 1.15 && s >= -0.15 && s <= 1.15) {
            addColumn(a.a + u * t.clamp(0.0, 1.0).toDouble());
          }
        }
        for (final pt in [a.a, a.b]) {
          final d = StructuralPolygonDistance.pointToSegment(pt, b.a, b.b);
          if (d <= math.max(0.35 * scale, b.width * 1.2)) {
            final along = dot(pt - b.a, b.u).clamp(0.0, b.length).toDouble();
            addColumn(b.a + b.u * along);
          }
        }
        for (final pt in [b.a, b.b]) {
          final d = StructuralPolygonDistance.pointToSegment(pt, a.a, a.b);
          if (d <= math.max(0.35 * scale, a.width * 1.2)) {
            final along = dot(pt - a.a, a.u).clamp(0.0, a.length).toDouble();
            addColumn(a.a + a.u * along);
          }
        }
      }
    }

    // Dense candidates let the repair pass react to actual support distances,
    // instead of losing an entire bay when a fixed-spacing candidate is rejected.
    final candidates = <({Offset p, _WallRun? run, Offset? axis})>[];
    var samplingLimited = false;
    final margin =
        math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
    void sample(Offset a, Offset b, {_WallRun? run, Offset? axis}) {
      final length = (b - a).distance;
      if (length < 2 * margin) return;
      final u = (b - a) / length;
      final requested =
          (length /
                  (scale *
                      (options.generousDensity
                          ? options.minSpacingM / 2
                          : options.targetSpacingM)))
              .ceil();
      if (requested > 100) samplingLimited = true;
      final count = requested.clamp(1, 100);
      for (var k = 0; k <= count; k++) {
        if (candidates.length >= 2400) {
          samplingLimited = true;
          return;
        }
        final fraction = k == 0
            ? 0.0
            : k == count
            ? 1.0
            : ((k + (phase - .5) * .5) / count).clamp(0.0, 1.0);
        candidates.add((
          p: a + u * (margin + (length - 2 * margin) * fraction),
          run: run,
          axis: axis,
        ));
      }
    }

    for (final run in runs) {
      sample(run.a, run.b, run: run);
    }
    for (final axis in axes) {
      final d = axis.end - axis.start;
      if (d.distance > 1e-8 * scale) {
        sample(axis.start, axis.end, axis: d / d.distance);
      }
    }
    int pointRegion(Offset p) {
      for (var r = 0; r < regions.length; r++) {
        for (final i in regions[r]) {
          final slab = floor.slabs[i];
          if (StructuralPolygonDistance.inside(p, slab.polygon) &&
              !slab.openings.any(
                (h) => StructuralPolygonDistance.inside(p, h),
              )) {
            return r;
          }
        }
      }
      return -1;
    }

    final supportRegions = occupied.map(regionOf).toList();
    double supportDistance(Offset p, int region) {
      var d = double.infinity;
      for (var i = 0; i < occupied.length; i++) {
        if (supportRegions[i] != region) continue;
        final poly = occupied[i];
        if (StructuralPolygonDistance.inside(p, poly)) return 0;
        for (var j = 0; j < poly.length; j++) {
          d = math.min(
            d,
            StructuralPolygonDistance.pointToSegment(
              p,
              poly[j],
              poly[(j + 1) % poly.length],
            ),
          );
        }
      }
      return d;
    }

    final candidateRegions = candidates.map((c) => pointRegion(c.p)).toList();
    final used = <int>{};
    // Boundary probes drive infill before the general field pass. This catches
    // corners and projections that are missed by wall/axis samples alone.
    final boundaryProbes = <({Offset p, int region})>[];
    for (var r = 0; r < regions.length; r++) {
      for (final i in regions[r]) {
        final slab = floor.slabs[i];
        for (final ring in [slab.polygon, ...slab.openings]) {
          for (var j = 0; j < ring.length; j++) {
            final a = ring[j], b = ring[(j + 1) % ring.length];
            final requested =
                ((b - a).distance / (scale * options.minSpacingM / 2)).ceil();
            if (requested > 100) samplingLimited = true;
            final count = requested.clamp(1, 100);
            for (var k = 0; k < count; k++) {
              if (boundaryProbes.length >= 1600) {
                samplingLimited = true;
                break;
              }
              boundaryProbes.add((p: a + (b - a) * (k / count), region: r));
            }
          }
        }
      }
    }
    // Interior probes reveal wide fields even if all perimeter points are close
    // to supports. Sample in the dominant structural frame, not global XY.
    final interiorProbes = <({Offset p, int region})>[];
    final normal = Offset(-primary.dy, primary.dx);
    interiorSampling:
    for (var r = 0; r < regions.length; r++) {
      for (final i in regions[r]) {
        final slab = floor.slabs[i];
        final origin = slab.polygon.first;
        final xs = slab.polygon.map((p) => dot(p - origin, primary));
        final ys = slab.polygon.map((p) => dot(p - origin, normal));
        final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
        final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
        final step = math.min(2.0, layoutSpacingM / 2) * scale;
        final requestedX = ((maxX - minX) / step).ceil();
        final requestedY = ((maxY - minY) / step).ceil();
        if (requestedX > 100 || requestedY > 100) samplingLimited = true;
        final nx = requestedX.clamp(1, 100), ny = requestedY.clamp(1, 100);
        for (var x = 0; x < nx; x++) {
          for (var y = 0; y < ny; y++) {
            if (interiorProbes.length >= 1600) {
              samplingLimited = true;
              break interiorSampling;
            }
            final p =
                origin +
                primary * (minX + (maxX - minX) * (x + .5) / nx) +
                normal * (minY + (maxY - minY) * (y + .5) / ny);
            if (pointRegion(p) == r) interiorProbes.add((p: p, region: r));
          }
        }
      }
    }
    void tryCandidate(int i) {
      used.add(i);
      final c = candidates[i];
      addColumn(c.p, preferredRun: c.run, axisDirection: c.axis);
      while (supportRegions.length < occupied.length) {
        supportRegions.add(regionOf(occupied[supportRegions.length]));
      }
    }

    final coverageRadius = layoutSpacingM * scale / 2;
    // Prefer the nearest admissible position to each unsupported edge sample.
    // No column is invented outside walls/axes or inside a slab opening.
    for (final probe in [...boundaryProbes, ...interiorProbes]) {
      while (supportDistance(probe.p, probe.region) > coverageRadius &&
          cols.length + walls.length < 300 &&
          attempts <= 20000) {
        var best = -1;
        var distance = supportDistance(probe.p, probe.region);
        for (var i = 0; i < candidates.length; i++) {
          if (used.contains(i) || candidateRegions[i] != probe.region) continue;
          final d = (candidates[i].p - probe.p).distance;
          if (d < distance) {
            best = i;
            distance = d;
          }
        }
        if (best < 0) break;
        tryCandidate(best);
      }
    }
    // Farthest-first infill is deterministic and preserves manual supports.
    while (cols.length + walls.length < 300 && attempts <= 20000) {
      var best = -1;
      var distance = coverageRadius;
      for (var i = 0; i < candidates.length; i++) {
        if (used.contains(i) || candidateRegions[i] < 0) continue;
        final d = supportDistance(candidates[i].p, candidateRegions[i]);
        if (d > distance) {
          best = i;
          distance = d;
        }
      }
      if (best < 0) break;
      tryCandidate(best);
    }
    // Report residual geometric gaps, including projections for which no valid
    // support could be found. Never claim a solved span or EC2 deflection check.
    var uncovered = 0;
    final uncoveredPoints = <Offset>[];
    var maxDistance = 0.0;
    void probe(Offset p, int region) {
      final d = supportDistance(p, region) / scale;
      maxDistance = math.max(maxDistance, d);
      if (d > options.targetSpacingM / 2) {
        uncovered++;
        uncoveredPoints.add(p);
      }
    }

    for (var i = 0; i < candidates.length; i++) {
      if (candidateRegions[i] >= 0) probe(candidates[i].p, candidateRegions[i]);
    }
    for (final sample in [...boundaryProbes, ...interiorProbes]) {
      probe(sample.p, sample.region);
    }
    final names = <String>{
      ...floor.columns.map((c) => c.displayName),
      ...floor.shearWalls.map((w) => w.displayName),
    };
    String nextName(String prefix) {
      var n = 1;
      while (!names.add('$prefix$n')) {
        n++;
      }
      return '$prefix$n';
    }

    return InitialSchemeProposal(
      columns: List.unmodifiable(
        cols.map((c) => c.copyWith(name: nextName('C'))),
      ),
      walls: List.unmodifiable(
        walls.map((w) => w.copyWith(name: nextName('W'))),
      ),
      rejectedCandidates: rejected,
      uncoveredSamples: uncovered,
      uncoveredPoints: List.unmodifiable(uncoveredPoints),
      maxSupportDistanceM: maxDistance,
      unresolvedRegions: List.generate(regions.length, (i) => i)
          .where((r) => !(directionCoverage[r]?.containsAll({0, 1}) ?? false))
          .length,
      limited:
          samplingLimited ||
          attempts > 20000 ||
          cols.length + walls.length >= 300 ||
          junctionWork >= 50000,
    );
  }
}
