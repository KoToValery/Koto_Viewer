import 'dart:math' as math;
import 'dart:ui';

import '../models/element_check_models.dart';
import '../models/structural_element.dart';
import 'member_checks.dart';
import 'slab_boundary_geometry.dart';
import 'slab_plate_model.dart';
import 'structural_polygon_distance.dart';

// === SECTION: INDEX ===
// === SECTION: LOAD CONSTANTS ===
// === SECTION: RUNDOWN ===
// === SECTION: GEOMETRY HELPERS ===
//
// Top-down load path: each storey ceiling is solved as a plate on the columns,
// walls and beams below it. Reactions plus self-weight run down through
// elements that stand on each other; elements standing on nothing load the
// plate underneath as concentrated forces instead of disappearing.

// === SECTION: LOAD CONSTANTS ===

class RundownLoads {
  static const gammaG = 1.35, gammaQ = 1.5, psi2 = 0.3;
  static const concreteWeight = 25.0; // kN/m3

  /// Tolerance for an upper element standing on a lower one (metres).
  static const bearingToleranceM = 0.03;

  /// Beam ends must lie within this distance of a column or wall (metres).
  static const beamEndToleranceM = 0.30;
}

// === SECTION: RUNDOWN ===

class LoadRundown {
  /// Isolate entry point for `compute`.
  static PreliminaryCheckReport analyzeEntry((StructuralProject, double) input) =>
      analyze(input.$1, cadUnitsPerMeter: input.$2);

  static PreliminaryCheckReport analyze(
    StructuralProject project, {
    required double cadUnitsPerMeter,
    double spacingM = 0.5,
  }) {
    final watch = Stopwatch()..start();
    final scale = cadUnitsPerMeter;
    if (!scale.isFinite || scale <= 0) return PreliminaryCheckReport.empty;
    final storeys = project.ceilingStoreys
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    if (storeys.isEmpty) return PreliminaryCheckReport.empty;
    final material = CheckMaterial.of(project);

    final elements = <String, ElementUtilization>{};
    final slabs = <SlabCheckResult>[];
    final unsupported = <UnsupportedSlabArea>[];

    // Loads delivered from the storey above: per element, and onto the plate.
    var transferred = <String, (double, double)>{};
    var pendingPointLoads = <PlatePointLoad>[];

    for (var idx = storeys.length - 1; idx >= 0; idx--) {
      final storey = storeys[idx];
      final isRoof = idx == storeys.length - 1;
      final plate = _solvePlate(project, storey, scale, material,
          pendingPointLoads, withFacade: !isRoof, spacingM: spacingM);
      if (plate.status == PlateStatus.solved ||
          plate.status == PlateStatus.unstable) {
        if (plate.unsupportedCellsCad.isNotEmpty) {
          unsupported.add(UnsupportedSlabArea(
              storey.id, plate.unsupportedCellsCad, plate.unsupportedAreaM2));
        }
        slabs.addAll(MemberChecks.slabField(storey.id, plate, material, scale));
      }

      final beamShare = _beamReactions(storey, plate, scale);
      final height = storey.height.isFinite && storey.height > 0 ? storey.height : 2.8;
      final boundaries = SlabBoundaryGeometry.exposedEdges(storey.slabs, scale);
      final nextTransferred = <String, (double, double)>{};
      final nextPoint = <PlatePointLoad>[];
      final lower = idx > 0 ? storeys[idx - 1] : null;

      for (final col in storey.columns) {
        final key = PreliminaryCheckReport.key(storey.id, col.id);
        final area = MemberChecks.columnAreaM2(col, scale);
        final slabUls = plate.reactionUls[col.id] ?? 0;
        final slabQp = plate.reactionQp[col.id] ?? 0;
        final from = transferred[key] ?? (0.0, 0.0);
        final share = beamShare[col.id] ?? (0.0, 0.0);
        final selfWeight = RundownLoads.concreteWeight * area * height;
        final nUls = slabUls + share.$1 + from.$1 + RundownLoads.gammaG * selfWeight;
        final nQp = slabQp + share.$2 + from.$2 + selfWeight;
        final checks = MemberChecks.column(
          axialUls: nUls,
          axialQp: nQp,
          areaM2: area,
          minDimensionM: MemberChecks.columnMinDimensionM(col, scale),
          material: material,
        );
        if (slabUls > 1e-6) {
          checks.add(_punching(col, storey, scale, slabUls, material, boundaries));
        }
        elements[key] = ElementUtilization(
          elementId: col.id,
          storeyId: storey.id,
          type: CheckedElementType.column,
          checks: checks,
          axialUls: nUls,
          axialQuasiPermanent: nQp,
          slabReactionUls: slabUls,
        );
        if (lower != null) {
          _transferDown(col.id, [col.center], nUls, nQp, lower, scale,
              nextTransferred, nextPoint);
        }
      }

      for (final wall in storey.shearWalls) {
        final key = PreliminaryCheckReport.key(storey.id, wall.id);
        final lengthM = wall.length / scale, thicknessM = wall.thickness / scale;
        final area = lengthM * thicknessM;
        final slabUls = plate.reactionUls[wall.id] ?? 0;
        final slabQp = plate.reactionQp[wall.id] ?? 0;
        final from = transferred[key] ?? (0.0, 0.0);
        final share = beamShare[wall.id] ?? (0.0, 0.0);
        final selfWeight = RundownLoads.concreteWeight * area * height;
        final nUls = slabUls + share.$1 + from.$1 + RundownLoads.gammaG * selfWeight;
        final nQp = slabQp + share.$2 + from.$2 + selfWeight;
        elements[key] = ElementUtilization(
          elementId: wall.id,
          storeyId: storey.id,
          type: CheckedElementType.wall,
          checks: MemberChecks.wall(
            axialUls: nUls,
            axialQp: nQp,
            areaM2: area,
            thicknessM: thicknessM,
            material: material,
          ),
          axialUls: nUls,
          axialQuasiPermanent: nQp,
          slabReactionUls: slabUls,
        );
        if (lower != null) {
          final (a, b) = _bodyAxis(wall.polygonVertices);
          final pieces = math.max(2, (lengthM / 0.5).ceil());
          _transferDown(wall.id, [
            for (var k = 0; k < pieces; k++) a + (b - a) * ((k + .5) / pieces),
          ], nUls, nQp, lower, scale, nextTransferred, nextPoint);
        }
      }
      transferred = nextTransferred;
      pendingPointLoads = nextPoint;
    }

    return PreliminaryCheckReport(
      elements: elements,
      slabs: slabs,
      unsupported: unsupported,
      durationMs: watch.elapsedMilliseconds,
    );
  }

  static PlateSolution _solvePlate(
    StructuralProject project,
    StoreyLevel storey,
    double scale,
    CheckMaterial material,
    List<PlatePointLoad> pointLoads, {
    required bool withFacade,
    required double spacingM,
  }) {
    final regions = <PlateRegion>[
      for (final slab in storey.slabs)
        if (slab.polygon.length >= 3)
          () {
            final g = RundownLoads.concreteWeight * slab.thickness +
                project.deadLoadSuperimposed;
            final q = project.liveLoad;
            return PlateRegion(
              polygon: slab.polygon,
              openings: slab.openings,
              thicknessM: slab.thickness,
              loadUls: RundownLoads.gammaG * g + RundownLoads.gammaQ * q,
              loadQuasiPermanent: g + RundownLoads.psi2 * q,
            );
          }(),
    ];
    if (regions.isEmpty) return const PlateSolution(status: PlateStatus.noSlab);
    final supports = <PlateSupport>[
      for (final c in storey.columns) PlateSupport.footprint(c.id, c.polygonVertices),
      for (final w in storey.shearWalls)
        () {
          final (a, b) = _bodyAxis(w.polygonVertices);
          return PlateSupport.line(w.id, a, b, w.thickness / 2);
        }(),
      for (final b in storey.beams)
        PlateSupport.line(b.id, b.start, b.end, b.width / 2),
    ];
    final facade = project.facadeWallLoad;
    final lineLoads = <PlateLineLoad>[
      if (withFacade && facade.isFinite && facade > 0)
        for (final edge in SlabBoundaryGeometry.exposedEdges(storey.slabs, scale))
          if (!edge.opening)
            PlateLineLoad(edge.a, edge.b, RundownLoads.gammaG * facade, facade),
    ];
    return SlabPlateModel.solve(
      regions: regions,
      supports: supports,
      pointLoads: pointLoads,
      lineLoads: lineLoads,
      cadUnitsPerMeter: scale,
      elasticModulusKpa: material.elasticModulusMpa * 1000,
      spacingM: spacingM,
    );
  }

  /// Beam reactions split equally to the supports at its two ends.
  static Map<String, (double, double)> _beamReactions(
    StoreyLevel storey,
    PlateSolution plate,
    double scale,
  ) {
    final result = <String, (double, double)>{};
    final tolerance = RundownLoads.beamEndToleranceM * scale;
    String? supportAt(Offset p) {
      for (final c in storey.columns) {
        if (StructuralPolygonDistance.inside(p, c.polygonVertices) ||
            _distanceToPolygon(p, c.polygonVertices) <= tolerance) {
          return c.id;
        }
      }
      for (final w in storey.shearWalls) {
        if (_distanceToPolygon(p, w.polygonVertices) <= tolerance) {
          return w.id;
        }
      }
      return null;
    }

    for (final beam in storey.beams) {
      final uls = plate.reactionUls[beam.id] ?? 0, qp = plate.reactionQp[beam.id] ?? 0;
      if (uls <= 0) continue;
      final ends = [supportAt(beam.start), supportAt(beam.end)].whereType<String>().toList();
      for (final id in ends) {
        final prev = result[id] ?? (0.0, 0.0);
        result[id] = (prev.$1 + uls / ends.length, prev.$2 + qp / ends.length);
      }
    }
    return result;
  }

  /// Loads at [points] go to the lower column/wall containing them, otherwise
  /// onto the lower storey ceiling plate as concentrated forces.
  static void _transferDown(
    String sourceId,
    List<Offset> points,
    double uls,
    double qp,
    StoreyLevel lower,
    double scale,
    Map<String, (double, double)> transferred,
    List<PlatePointLoad> pointLoads,
  ) {
    final tolerance = RundownLoads.bearingToleranceM * scale;
    final shareUls = uls / points.length, shareQp = qp / points.length;
    for (final p in points) {
      String? target;
      for (final c in lower.columns) {
        if (_distanceToPolygon(p, c.polygonVertices) <= tolerance) {
          target = c.id;
          break;
        }
      }
      if (target == null) {
        for (final w in lower.shearWalls) {
          if (_distanceToPolygon(p, w.polygonVertices) <= tolerance) {
            target = w.id;
            break;
          }
        }
      }
      if (target == null) {
        pointLoads.add(PlatePointLoad(sourceId, p, shareUls, shareQp));
      } else {
        final key = PreliminaryCheckReport.key(lower.id, target);
        final prev = transferred[key] ?? (0.0, 0.0);
        transferred[key] = (prev.$1 + shareUls, prev.$2 + shareQp);
      }
    }
  }

  static ElementCheck _punching(
    StructuralColumn col,
    StoreyLevel storey,
    double scale,
    double reactionUls,
    CheckMaterial material,
    List<SlabBoundaryEdge> boundaries,
  ) {
    StructuralSlab? slab;
    for (final s in storey.slabs) {
      if (StructuralPolygonDistance.inside(col.center, s.polygon)) {
        slab = s;
        break;
      }
    }
    slab ??= storey.slabs.isEmpty
        ? null
        : storey.slabs.reduce((a, b) =>
            _distanceToPolygon(col.center, a.polygon) <=
                    _distanceToPolygon(col.center, b.polygon)
                ? a
                : b);
    if (slab == null) {
      return const ElementCheck(CheckKind.punching, double.nan, double.nan);
    }
    final d = slab.thickness - CheckAssumptions.slabDepthReductionM;
    final position = SlabBoundaryGeometry.classify(col, storey.slabs, scale, d,
        boundaries: boundaries);
    final perimeters = MemberChecks.punchingPerimeters(
        col.polygonVertices, storey.slabs, d, scale);
    return MemberChecks.punching(
      reactionUls: reactionUls,
      beta: position.beta,
      u1: perimeters.u1,
      u0: perimeters.u0,
      effectiveDepthM: d,
      material: material,
    );
  }

  // === SECTION: GEOMETRY HELPERS ===

  /// Zero inside the polygon, otherwise the distance to its outline.
  static double _distanceToPolygon(Offset p, List<Offset> poly) {
    if (poly.length < 3) return double.infinity;
    if (StructuralPolygonDistance.inside(p, poly)) return 0;
    var best = double.infinity;
    for (var i = 0; i < poly.length; i++) {
      best = math.min(best,
          StructuralPolygonDistance.pointToSegment(p, poly[i], poly[(i + 1) % poly.length]));
    }
    return best;
  }

  /// Centre line of a 4-vertex wall/beam body (midpoints of the short ends).
  static (Offset, Offset) _bodyAxis(List<Offset> body) =>
      body.length < 4 ? (body.first, body.last) : ((body[0] + body[3]) / 2, (body[1] + body[2]) / 2);
}
