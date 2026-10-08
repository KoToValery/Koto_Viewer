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
  final bool enforcePairedWalls;
  final bool generousDensity;

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

  const InitialSchemeProposal({
    this.columns = const [],
    this.walls = const [],
    this.unresolvedRegions = 0,
    this.rejectedCandidates = 0,
    this.limited = false,
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

/// Bounded, deterministic layout heuristic. Only unbridged paired wall runs
/// are evidence for placement; an axis by itself never proves a solid wall.
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
    String point(Offset p) =>
        '${(p.dx / scale).toStringAsFixed(4)},${(p.dy / scale).toStringAsFixed(4)}';
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
    if (runs.isEmpty) {
      return InitialSchemeProposal(
        unresolvedRegions: SlabTopologyAnalyzer.analyze(
          floor.slabs,
          scale,
        ).regionCount,
      );
    }
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
      var dist = math.max(0.35 * scale, options.wallThicknessM * scale);
      for (final run in runs) {
        final d = StructuralPolygonDistance.pointToSegment(p, run.a, run.b);
        if (d < dist) {
          best = run;
          dist = d;
        }
      }
      return best;
    }

    void addColumn(Offset p, {StructuralColumn? continuation}) {
      if (cols.length + walls.length >= 300 || attempts > 20000) return;
      final run = nearRun(p);
      if (run == null) return;
      // Preserve lower support center; other candidates project onto wall axis.
      final center = continuation != null
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
            rotationRad: math.atan2(run.u.dy, run.u.dx),
            generatedBy: 'initial-scheme-v1',
          );
      if (!onRun(c.polygonVertices, run) || !allowed(c.polygonVertices, center)) {
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
    final primary = longest.first.u;
    final perp = Offset(-primary.dy, primary.dx);

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
        stairRings.isEmpty
            ? 0.0
            : stairRings
                    .expand((p) => p)
                    .map(
                      (p) => StructuralPolygonDistance.pointToSegment(p, run.a, run.b),
                    )
                    .fold(double.infinity, math.min) /
                scale;

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
            .add(elementDirection(u));
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
        sumA += StructuralSlab.calculateArea(floor.slabs[idx].polygon) / (scale * scale);
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
      final center = run.center;
      final w = StructuralShearWall(
        id: 'scheme:${floor.id}:w:${point(center)}',
        start: center - run.u * (targetLenM * scale / 2),
        end: center + run.u * (targetLenM * scale / 2),
        thickness: options.wallThicknessM * scale,
        generatedBy: 'initial-scheme-v1',
      );
      if (ids.contains(w.id)) return false;
      if (regionOf(w.polygonVertices) != r) return false;
      if (!onRun(w.polygonVertices, run)) return false;

      // Spacing check against existing shear walls in the SAME direction
      final sameDirWalls = [...floor.shearWalls, ...walls].where((existing) {
        if (existing.length <= 0 || regionOf(existing.polygonVertices) != r) return false;
        final u = (existing.end - existing.start) / existing.length;
        return elementDirection(u) == d;
      });
      if (sameDirWalls.any((other) => (other.center - center).distance < minWallSpacingM * scale)) {
        return false;
      }
      if (!allowed(w.polygonVertices, center)) return false;

      walls.add(w);
      occupied.add(w.polygonVertices);
      centers.add(center);
      ids.add(w.id);
      directionCoverage.putIfAbsent(r, () => {}).add(d);
      return true;
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

        final primaryRuns = runs.where((run) =>
            direction(run) == dir &&
            run.length >= options.wallLengthM * scale
        ).toList();

        final fallbackRuns = runs.where((run) =>
            direction(run) == dir &&
            run.length < options.wallLengthM * scale &&
            run.length >= math.max(1.0, options.wallLengthM * 0.75) * scale
        ).toList();

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
          if (variant == 0) {
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
          tryAddWall(run, r, dir, minWallSpacingM: math.min(options.targetSpacingM, 3.5));
        }

        // Pass 2 (Rescue): If pairing is enforced and we placed exactly 1 wall (odd/unpaired!),
        // actively find the 2nd matching wall with relaxed spacing and relaxed length
        if (options.enforcePairedWalls && existingWallsInDir(r, dir) == 1) {
          for (final run in ordered) {
            if (existingWallsInDir(r, dir) >= 2) break;
            tryAddWall(run, r, dir, minWallSpacingM: math.max(options.minSpacingM * 1.2, 2.5));
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
          final margin = math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
          final along = dot(curr - run.a, run.u).clamp(margin, math.max(margin, run.length - margin)).toDouble();
          addColumn(run.a + run.u * along);
        }
      }
    }

    // 2. Staircase and elevator opening corners
    for (final slab in floor.slabs) {
      for (var o = 0; o < slab.openings.length; o++) {
        final type = slab.getOpeningType(o);
        if (type == SlabOpeningType.staircase || type == SlabOpeningType.elevator) {
          final opening = slab.openings[o];
          for (final pt in opening) {
            final run = nearRun(pt);
            if (run != null) {
              final margin = math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
              final along = dot(pt - run.a, run.u).clamp(margin, math.max(margin, run.length - margin)).toDouble();
              addColumn(run.a + run.u * along);
            }
          }
        }
      }
    }

    // 3. Grid axes intersections
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
          addColumn(a.start + u * t);
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

    // 5. Wall endpoints and intermediate samples along all runs
    for (final run in runs) {
      final margin =
          math.max(options.columnWidthM, options.columnDepthM) * scale / 2;
      if (run.length < 2 * margin) continue;
      if (options.generousDensity) {
        addColumn(run.a + run.u * margin);
        addColumn(run.b - run.u * margin);

        final step = math.min(options.targetSpacingM, 3.5) * scale;
        final count = math.min(100, math.max(1, (run.length / step).ceil()));
        for (var k = 1; k < count; k++) {
          addColumn(
            run.a + run.u * (margin + (run.length - 2 * margin) * k / count),
          );
        }
      } else {
        // Sparse layout: fewer divisions, only at full target spacing
        final step = options.targetSpacingM * scale;
        final count = math.min(60, math.max(1, (run.length / step).floor()));
        for (var k = 1; k < count; k++) {
          addColumn(
            run.a + run.u * (margin + (run.length - 2 * margin) * k / count),
          );
        }
      }
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
      unresolvedRegions: List.generate(regions.length, (i) => i)
          .where((r) => !(directionCoverage[r]?.containsAll({0, 1}) ?? false))
          .length,
      limited:
          attempts > 20000 ||
          cols.length + walls.length >= 300 ||
          junctionWork >= 50000,
    );
  }
}
