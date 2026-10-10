import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import 'structural_scheme_readiness.dart';
import 'staircase_inventory.dart';
import 'slab_contact_geometry.dart';
import 'slab_topology_analyzer.dart';
import 'structural_polygon_distance.dart';
import 'wall_placement_domain.dart';
import 'wall_placement_network.dart';
import 'geometric_window_detector.dart';
import 'vertical_capacity_calculator.dart';
import 'seismic_analysis_calculator.dart';
import 'support_placement_rules.dart';
import 'support_layout_evaluator.dart';
import 'support_layout_optimizer.dart';
import 'structural_geometry_units.dart';
import '../models/vertical_capacity_models.dart';

class InitialSchemeOptions {
  final double minSpacingM, minWallSpacingM, targetSpacingM, wallLengthM;
  final double? maxWallLengthM;
  final double columnWidthM, columnDepthM, wallThicknessM;
  final ColumnShape columnShape;
  final double columnThicknessM;
  final bool enforcePairedWalls, generousDensity, adaptiveSizes;
  final int placementAttemptsPerStage, searchVariants, maxSearchEvaluations;
  final bool optimizeLayout;
  const InitialSchemeOptions({
    this.columnShape = ColumnShape.rectangular,
    this.columnThicknessM = .25,
    this.minSpacingM = 2,
    this.minWallSpacingM = 2,
    this.targetSpacingM = 5,
    this.wallLengthM = 1.5,
    this.maxWallLengthM,
    this.columnWidthM = .25,
    this.columnDepthM = .3,
    this.wallThicknessM = .25,
    this.enforcePairedWalls = true,
    this.generousDensity = false,
    this.adaptiveSizes = true,
    this.placementAttemptsPerStage = 4000,
    this.optimizeLayout = true,
    this.searchVariants = 3,
    this.maxSearchEvaluations = 64,
  });

  /// User-controlled generation bound, not a normative maximum wall length.
  double get effectiveMaxWallLengthM =>
      maxWallLengthM ?? math.max(wallLengthM, 2.5);
  bool get valid =>
      [
        minSpacingM,
        minWallSpacingM,
        targetSpacingM,
        wallLengthM,
        effectiveMaxWallLengthM,
        columnThicknessM,
        columnWidthM,
        columnDepthM,
        wallThicknessM,
      ].every((v) => v.isFinite && v > 0) &&
      targetSpacingM >= minSpacingM &&
      effectiveMaxWallLengthM >= wallLengthM &&
      placementAttemptsPerStage > 0 &&
      searchVariants > 0 &&
      searchVariants <= 4 &&
      maxSearchEvaluations >= searchVariants;
}

class InitialSchemeProposal {
  final List<StructuralColumn> columns;
  final List<StructuralShearWall> walls;
  final int unresolvedRegions, rejectedCandidates;
  final bool limited;
  final Set<String> limitReasons;
  final Map<String, int> attemptsByStage;
  final SupportLayoutAssessment? assessment, initialAssessment;
  final int searchedLayouts, optimizationChanges, optimizationEvaluations;
  final Map<String, int> optimizationOperations;
  final String? continuationSource;
  final bool replacesGeneratedSupports;
  final Set<String> openingColumnIds;
  final SlabDeflectionCheck? spanCheck;
  final Set<String> resizedColumnIds, columnSizingReviewIds;
  final double wallRatioX, wallRatioY, wallDeficitXM2, wallDeficitYM2;
  final Map<String, int> rejectionReasons;
  final double? maxSupportSpanM;
  final (Offset, Offset)? criticalSupportSpan;

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
    this.limitReasons = const {},
    this.attemptsByStage = const {},
    this.assessment,
    this.initialAssessment,
    this.searchedLayouts = 1,
    this.optimizationChanges = 0,
    this.optimizationEvaluations = 0,
    this.optimizationOperations = const {},
    this.continuationSource,
    this.replacesGeneratedSupports = false,
    this.openingColumnIds = const {},
    this.spanCheck,
    this.resizedColumnIds = const {},
    this.columnSizingReviewIds = const {},
    this.wallRatioX = 0,
    this.wallRatioY = 0,
    this.wallDeficitXM2 = 0,
    this.wallDeficitYM2 = 0,
    this.rejectionReasons = const {},
    this.maxSupportSpanM,
    this.criticalSupportSpan,
    this.uncoveredSamples = 0,
    this.maxSupportDistanceM = 0,
    this.uncoveredPoints = const [],
  });
  InitialSchemeProposal inCad(double factor) {
    Offset point(Offset p) => p * factor;
    final check = spanCheck;
    return InitialSchemeProposal(
      columns: List.unmodifiable(
        columns.map(
          (c) => c.copyWith(
            center: point(c.center),
            width: c.width * factor,
            height: c.height * factor,
            thickness: c.thickness * factor,
          ),
        ),
      ),
      walls: List.unmodifiable(
        walls.map(
          (w) => w.copyWith(
            start: point(w.start),
            end: point(w.end),
            thickness: w.thickness * factor,
          ),
        ),
      ),
      unresolvedRegions: unresolvedRegions,
      rejectedCandidates: rejectedCandidates,
      limited: limited,
      limitReasons: limitReasons,
      attemptsByStage: attemptsByStage,
      assessment: assessment?.mapPoints(point),
      initialAssessment: initialAssessment?.mapPoints(point),
      searchedLayouts: searchedLayouts,
      optimizationChanges: optimizationChanges,
      optimizationEvaluations: optimizationEvaluations,
      optimizationOperations: optimizationOperations,
      continuationSource: continuationSource,
      replacesGeneratedSupports: replacesGeneratedSupports,
      openingColumnIds: openingColumnIds,
      resizedColumnIds: resizedColumnIds,
      columnSizingReviewIds: columnSizingReviewIds,
      wallRatioX: wallRatioX,
      wallRatioY: wallRatioY,
      wallDeficitXM2: wallDeficitXM2,
      wallDeficitYM2: wallDeficitYM2,
      rejectionReasons: rejectionReasons,
      maxSupportSpanM: maxSupportSpanM,
      criticalSupportSpan: criticalSupportSpan == null
          ? null
          : (point(criticalSupportSpan!.$1), point(criticalSupportSpan!.$2)),
      uncoveredSamples: uncoveredSamples,
      maxSupportDistanceM: maxSupportDistanceM,
      uncoveredPoints: List.unmodifiable(uncoveredPoints.map(point)),
      spanCheck: check == null
          ? null
          : SlabDeflectionCheck(
              storeyId: check.storeyId,
              storeyName: check.storeyName,
              currentThicknessM: check.currentThicknessM,
              maxSpanM: check.maxSpanM,
              recommendedMinThicknessM: check.recommendedMinThicknessM,
              isDeflectionSafe: check.isDeflectionSafe,
              deflectionRatio: check.deflectionRatio,
              recommendation: check.recommendation,
              hasBeams: check.hasBeams,
              criticalSpanSegment: check.criticalSpanSegment == null
                  ? null
                  : (
                      point(check.criticalSpanSegment!.$1),
                      point(check.criticalSpanSegment!.$2),
                    ),
              supportSpans: [
                for (final s in check.supportSpans)
                  SupportSpanCheck(
                    segment: (point(s.segment.$1), point(s.segment.$2)),
                    spanM: s.spanM,
                    thicknessM: s.thicknessM,
                    allowableSpanM: s.allowableSpanM,
                    slabIds: s.slabIds,
                    hasBeams: s.hasBeams,
                  ),
              ],
            ),
    );
  }

  bool get isEmpty =>
      columns.isEmpty && walls.isEmpty && !replacesGeneratedSupports;
  StoreyLevel apply(StoreyLevel floor) => floor.copyWith(
    columns: [
      ...floor.columns.where(
        (c) =>
            !replacesGeneratedSupports ||
            !(c.generatedBy?.startsWith('initial-scheme') ?? false),
      ),
      ...columns.where(
        (c) => !floor.columns.any(
          (old) =>
              old.id == c.id &&
              (!replacesGeneratedSupports ||
                  !(old.generatedBy?.startsWith('initial-scheme') ?? false)),
        ),
      ),
    ],
    shearWalls: [
      ...floor.shearWalls.where(
        (w) =>
            !replacesGeneratedSupports ||
            !(w.generatedBy?.startsWith('initial-scheme') ?? false),
      ),
      ...walls.where(
        (w) => !floor.shearWalls.any(
          (old) =>
              old.id == w.id &&
              (!replacesGeneratedSupports ||
                  !(old.generatedBy?.startsWith('initial-scheme') ?? false)),
        ),
      ),
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
/// grid axes guide candidates but never authorize placement outside walls.
class InitialSchemeGenerator {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

  /// Upper levels have one inherited scheme. Never repair a span or wall-area
  /// deficit with a new floating support; report it for revision of the base.
  static InitialSchemeProposal _continueLowerStorey(
    StructuralProject project,
    StoreyLevel lower,
    List<WallPairCandidate> wallPairs,
    List<GeometricWindowOpening> wallOpenings,
    double scale,
  ) {
    final floor = project.activeStorey.copyWith(
      staircaseZones: project.staircaseZonesFor(project.activeStorey));
    final manual = floor.copyWith(
      columns: floor.columns
          .where((c) => !(c.generatedBy?.startsWith('initial-scheme') ?? false))
          .toList(),
      shearWalls: floor.shearWalls
          .where((w) => !(w.generatedBy?.startsWith('initial-scheme') ?? false))
          .toList(),
    );
    final domain = WallPlacementDomain.build(wallPairs, wallOpenings, scale);
    final cols = <StructuralColumn>[], walls = <StructuralShearWall>[];
    final fallback = <String>{};
    final blockedPoints = <Offset>[];
    final rejections = <String, int>{};
    void reject(String reason) =>
        rejections.update(reason, (n) => n + 1, ifAbsent: () => 1);
    bool same(List<Offset> a, List<Offset> b) =>
        a.length == b.length &&
        a.every((p) => b.any((q) => (p - q).distance < 1e-7 * scale));
    final occupied = <List<Offset>>[
      ...manual.columns.map((c) => c.polygonVertices),
      ...manual.shearWalls.map((w) => w.polygonVertices),
    ];
    bool fits(List<Offset> poly, {bool allowOpening = false}) {
      if (!SupportPlacementRules.circulationFits(poly, floor, scale)) {
        reject('staircase'); return false;
      }
      if (!domain.contains(poly, includeOpenings: allowOpening)) {
        reject('wall');
        return false;
      }
      final area = StructuralSlab.calculateArea(poly) / (scale * scale);
      final contact = SlabContactGeometry.measure(poly, floor.slabs, scale);
      if (contact == null ||
          area <= 0 ||
          (contact.areaM2 - area).abs() > math.max(1e-10, area * 1e-7) ||
          floor.slabs.any(
            (s) => s.openings.any(
              (h) => StructuralPolygonDistance.between(poly, h) <= 1e-7 * scale,
            ),
          )) {
        reject('slab');
        return false;
      }
      if (occupied.any(
        (p) => StructuralPolygonDistance.between(p, poly) < .05 * scale - 1e-8,
      )) {
        reject('collision');
        return false;
      }
      occupied.add(poly);
      return true;
    }

    for (final c in manual.columns) {
      if (!lower.columns.any(
        (old) => same(old.polygonVertices, c.polygonVertices),
      )) {
        reject('continuity');
      }
    }
    for (final w in manual.shearWalls) {
      if (!lower.shearWalls.any(
        (old) => same(old.polygonVertices, w.polygonVertices),
      )) {
        reject('continuity');
      }
    }
    for (final c in lower.columns) {
      if (manual.columns.any(
        (old) => (old.center - c.center).distance < 1e-7 * scale,
      )) {
        continue;
      }
      final inOpening = !domain.contains(c.polygonVertices);
      if (!fits(c.polygonVertices, allowOpening: inOpening)) {
        blockedPoints.add(c.center);
        continue;
      }
      final id = 'scheme:${floor.id}:continued-c:${c.id}';
      cols.add(
        c.copyWith(
          id: id,
          generatedBy: inOpening
              ? 'initial-scheme-v2-opening-review'
              : 'initial-scheme-continuation',
        ),
      );
      if (inOpening) fallback.add(id);
    }
    for (final w in lower.shearWalls) {
      if (manual.shearWalls.any(
        (old) => same(old.polygonVertices, w.polygonVertices),
      )) {
        continue;
      }
      if (!fits(w.polygonVertices)) {
        blockedPoints.add(w.center);
        continue;
      }
      walls.add(
        w.copyWith(
          id: 'scheme:${floor.id}:continued-w:${w.id}',
          generatedBy: 'initial-scheme-continuation',
        ),
      );
    }
    final assessed = manual.copyWith(
      columns: [...manual.columns, ...cols],
      shearWalls: [...manual.shearWalls, ...walls],
    );
    final span = VerticalCapacityCalculator.calculateClearSpan(assessed, scale);
    final density = SeismicAnalysisCalculator.wallDensity(assessed, scale);
    final loads = VerticalCapacityCalculator.analyzeProject(
      project.copyWith(
        storeys: [
          for (final s in project.storeys) s.id == floor.id ? assessed : s,
        ],
      ),
      cadUnitsPerMeter: scale,
    );
    return InitialSchemeProposal(
      columns: List.unmodifiable(cols),
      walls: List.unmodifiable(walls),
      continuationSource: lower.elevationLabel,
      uncoveredPoints: List.unmodifiable(blockedPoints),
      uncoveredSamples: blockedPoints.length,
      replacesGeneratedSupports:
          floor.columns.length != manual.columns.length ||
          floor.shearWalls.length != manual.shearWalls.length,
      openingColumnIds: Set.unmodifiable(fallback),
      rejectionReasons: Map.unmodifiable(rejections),
      rejectedCandidates: rejections.values.fold(0, (a, b) => a + b),
      wallRatioX: density.ratioX,
      wallRatioY: density.ratioY,
      wallDeficitXM2: density.deficitX,
      wallDeficitYM2: density.deficitY,
      maxSupportSpanM: span.maxSpanM.isFinite ? span.maxSpanM : null,
      criticalSupportSpan: span.criticalSpanSegment,
      spanCheck: VerticalCapacityCalculator.evaluateSlabSpan(assessed, scale),
      columnSizingReviewIds: loads.columnChecks
          .where(
            (c) =>
                c.storeyId == floor.id &&
                cols.any((col) => col.id == c.columnId) &&
                (c.axialUtilization > .80 || c.punchingUtilization > .85),
          )
          .map((c) => c.columnId)
          .toSet(),
      unresolvedRegions: SlabTopologyAnalyzer.analyze(assessed.slabs, scale)
          .regions
          .where((r) {
            final regional = assessed.copyWith(
              slabs: [for (final i in r) assessed.slabs[i]],
            );
            final d = SeismicAnalysisCalculator.wallDensity(regional, scale);
            return d.ratioX <= 0 || d.ratioY <= 0;
          })
          .length,
    );
  }

  static InitialSchemeProposal generate({
    required StructuralProject project,
    StructuralProject? sourceProject,
    required List<WallPairCandidate> wallPairs,
    required double scale,
    List<GeometricWindowOpening> wallOpenings = const [],
    InitialSchemeOptions options = const InitialSchemeOptions(),
    int variant = 0,
  }) {
    if (!StaircaseInventory.evaluate(sourceProject ?? project, scale).ready ||
        !scale.isFinite ||
        scale <= 0 ||
        !options.valid ||
        !StructuralSchemeReadiness.evaluate(project, scale).geometryReady) {
      return const InitialSchemeProposal();
    }
    final units = StructuralGeometryUnits(scale, Offset.zero);
    WallSegment segment(WallSegment s) => WallSegment(
      start: units.toMetres(s.start),
      end: units.toMetres(s.end),
      angleRad: s.angleRad,
      offsetFromOrigin: s.offsetFromOrigin / scale,
      length: s.length / scale,
      sourceLayer: s.sourceLayer,
      sourceColorIndex: s.sourceColorIndex,
      sourceTrueColor: s.sourceTrueColor,
      sourceEntity: s.sourceEntity,
      lineweight: s.lineweight,
    );
    final pairs = [
      for (final w in wallPairs)
        WallPairCandidate(
          segmentA: segment(w.segmentA),
          segmentB: segment(w.segmentB),
          perpendicularDistance: w.perpendicularDistance / scale,
          overlapLength: w.overlapLength / scale,
          centerlineStart: units.toMetres(w.centerlineStart),
          centerlineEnd: units.toMetres(w.centerlineEnd),
        ),
    ];
    final openings = [
      for (final o in wallOpenings)
        GeometricWindowOpening(
          start: units.toMetres(o.start),
          end: units.toMetres(o.end),
          thickness: o.thickness / scale,
          length: o.length / scale,
          barrierPolygon: o.barrierPolygon.map(units.toMetres).toList(),
          evidence: o.evidence,
        ),
    ];
    return _generateInMetres(
      project: units.project(project),
      wallPairs: pairs,
      scale: 1,
      wallOpenings: openings,
      options: options,
      variant: variant,
    ).inCad(scale);
  }

  static InitialSchemeProposal _generateInMetres({
    required StructuralProject project,
    required List<WallPairCandidate> wallPairs,
    required double scale,
    List<GeometricWindowOpening> wallOpenings = const [],
    InitialSchemeOptions options = const InitialSchemeOptions(),
    int variant = 0,
  }) {
    final first = _generateLayout(
      project: project,
      wallPairs: wallPairs,
      scale: scale,
      wallOpenings: wallOpenings,
      options: options,
      variant: variant,
      balancedWallPositions: false,
      sparseColumns: true,
    );
    if (!options.valid ||
        !scale.isFinite ||
        scale <= 0 ||
        !StructuralSchemeReadiness.evaluate(project, scale).geometryReady ||
        first.limitReasons.contains('input')) {
      return first;
    }
    final floor = project.activeStorey.copyWith(
      staircaseZones: project.staircaseZonesFor(project.activeStorey));
    final evaluatedFirst = first
        .apply(floor)
        .copyWith(gridAxes: project.effectiveGridAxes);
    var before = SupportLayoutEvaluator.evaluate(
      project,
      evaluatedFirst,
      scale,
    );
    final candidates = <InitialSchemeProposal>[first];
    LayoutSearchResult? result;
    if (options.optimizeLayout &&
        first.continuationSource == null &&
        !first.isEmpty) {
      for (var seed = 1; seed < options.searchVariants; seed++) {
        candidates.add(
          _generateLayout(
            project: project,
            wallPairs: wallPairs,
            scale: scale,
            wallOpenings: wallOpenings,
            options: options,
            variant: seed == options.searchVariants - 1 ? 0 : variant + seed,
            preferColumnNodes: seed == options.searchVariants - 1,
            balancedWallPositions: seed != options.searchVariants - 1,
          ),
        );
      }
      result = SupportLayoutOptimizer.optimize(
        project: project,
        fixedFloor: floor,
        seeds: [
          for (final p in candidates)
            p.apply(floor).copyWith(gridAxes: project.effectiveGridAxes),
        ],
        wallPairs: wallPairs,
        domain: WallPlacementDomain.build(wallPairs, wallOpenings, scale),
        scale: scale,
        minSpacingM: options.minSpacingM,
        wallSpacingM: options.minWallSpacingM,
        initialWallLengthM: options.wallLengthM,
        wallThicknessM: options.wallThicknessM,
        maxWallLengthM: options.effectiveMaxWallLengthM,
        maxEvaluations: options.maxSearchEvaluations,
        adaptiveSizes: options.adaptiveSizes,
        pairedWalls: options.enforcePairedWalls,
        columnShape: options.columnShape,
        columnWidthM: options.columnWidthM,
        columnDepthM: options.columnDepthM,
        columnThicknessM: options.columnThicknessM,
      );
    }
    var finalFloor = result?.floor ?? evaluatedFirst;
    var assessment = result?.assessment ?? before;
    var acceptedChanges = result?.acceptedChanges ?? 0;
    if (first.continuationSource == null &&
        (floor.columns.isNotEmpty || floor.shearWalls.isNotEmpty)) {
      final current = floor.copyWith(gridAxes: project.effectiveGridAxes);
      final currentAssessment = SupportLayoutEvaluator.evaluate(
        project,
        current,
        scale,
      );
      before = currentAssessment;
      // Repeated generation may append only a measured improvement. A seed
      // cannot force extra concrete into an already better accepted scheme.
      if (assessment.compareTo(currentAssessment) >= 0) {
        finalFloor = current;
        assessment = currentAssessment;
        acceptedChanges = 0;
      }
    }
    final ids = <String>{
      ...floor.columns.map((c) => c.id),
      ...floor.shearWalls.map((w) => w.id),
    };
    final cols = first.continuationSource == null
        ? finalFloor.columns.where((c) => !ids.contains(c.id)).toList()
        : first.columns;
    final walls = first.continuationSource == null
        ? finalFloor.shearWalls.where((w) => !ids.contains(w.id)).toList()
        : first.walls;
    final openingIds = cols
        .where((c) => c.generatedBy?.contains('opening-review') ?? false)
        .map((c) => c.id)
        .toSet();
    final spans = VerticalCapacityCalculator.calculateClearSpan(
      finalFloor,
      scale,
    );
    final density = SeismicAnalysisCalculator.wallDensity(finalFloor, scale);
    final loads = VerticalCapacityCalculator.analyzeProject(
      project.copyWith(
        storeys: [
          for (final s in project.storeys) s.id == floor.id ? finalFloor : s,
        ],
      ),
      cadUnitsPerMeter: scale,
    );
    final sizingIds = loads.columnChecks
        .where(
          (c) =>
              c.storeyId == floor.id &&
              cols.any((col) => col.id == c.columnId) &&
              (c.axialUtilization > .8 ||
                  c.punchingUtilization > .85 ||
                  c.punchingRequiresReview),
        )
        .map((c) => c.columnId)
        .toSet();
    final reasons = <String, int>{};
    final attempts = <String, int>{};
    for (final candidate in candidates) {
      for (final e in candidate.rejectionReasons.entries) {
        reasons.update(e.key, (n) => n + e.value, ifAbsent: () => e.value);
      }
      for (final e in candidate.attemptsByStage.entries) {
        attempts.update(e.key, (n) => n + e.value, ifAbsent: () => e.value);
      }
    }
    final limits = <String>{
      for (final p in candidates) ...p.limitReasons,
      if (result?.limited ?? false) 'optimization',
      if (assessment.topology.limited) 'fields',
    };
    final points = <Offset>[];
    var maxDistance = 0.0;
    if (first.continuationSource == null) {
      final regional = SlabSupportRegions(finalFloor, scale);
      final samples = <Offset>[
        for (final s in floor.slabs)
          for (final ring in [s.polygon, ...s.openings])
            for (var i = 0; i < ring.length; i++) ...[
              ring[i],
              (ring[i] + ring[(i + 1) % ring.length]) / 2,
            ],
        ...first.uncoveredPoints,
      ];
      for (final p in samples) {
        final distance = regional.distance(p) / scale;
        maxDistance = math.max(maxDistance, distance);
        if (distance > options.targetSpacingM / 2) points.add(p);
      }
    } else {
      points.addAll(first.uncoveredPoints);
    }
    final names = <String>{
      ...floor.columns.map((c) => c.displayName),
      ...floor.shearWalls.map((w) => w.displayName),
    };
    String name(String prefix) {
      var n = 1;
      while (!names.add('$prefix$n')) {
        n++;
      }
      return '$prefix$n';
    }

    return InitialSchemeProposal(
      columns: List.unmodifiable(cols.map((c) => c.copyWith(name: name('C')))),
      walls: List.unmodifiable(walls.map((w) => w.copyWith(name: name('W')))),
      continuationSource: first.continuationSource,
      replacesGeneratedSupports: first.replacesGeneratedSupports,
      openingColumnIds: Set.unmodifiable(openingIds),
      assessment: assessment,
      initialAssessment: before,
      searchedLayouts: candidates.length,
      optimizationChanges: acceptedChanges,
      optimizationEvaluations: result?.evaluations ?? 0,
      optimizationOperations: result?.evaluationsByOperation ?? const {},
      rejectionReasons: Map.unmodifiable(reasons),
      rejectedCandidates: reasons.values.fold(0, (a, b) => a + b),
      attemptsByStage: Map.unmodifiable(attempts),
      limited: first.limited || limits.isNotEmpty,
      limitReasons: Set.unmodifiable(limits),
      wallRatioX: density.ratioX,
      wallRatioY: density.ratioY,
      wallDeficitXM2: density.deficitX,
      wallDeficitYM2: density.deficitY,
      columnSizingReviewIds: Set.unmodifiable(sizingIds),
      resizedColumnIds: Set.unmodifiable(
        cols
            .where(
              (c) =>
                  (c.width / scale - options.columnWidthM).abs() > 1e-6 ||
                  (c.height / scale - options.columnDepthM).abs() > 1e-6,
            )
            .map((c) => c.id),
      ),
      maxSupportSpanM: spans.maxSpanM.isFinite ? spans.maxSpanM : null,
      criticalSupportSpan: spans.criticalSpanSegment,
      spanCheck: VerticalCapacityCalculator.evaluateSlabSpan(finalFloor, scale),
      unresolvedRegions: SlabTopologyAnalyzer.analyze(finalFloor.slabs, scale)
          .regions
          .where((r) {
            final slabs = [for (final i in r) finalFloor.slabs[i]];
            final directions = finalFloor.shearWalls
                .where(
                  (w) =>
                      w.length > 0 &&
                      (SlabContactGeometry.measure(
                                w.polygonVertices,
                                slabs,
                                scale,
                              )?.areaM2 ??
                              0) >
                          1e-8,
                )
                .map((w) => (w.end - w.start) / w.length)
                .toList();
            return !directions.any(
              (a) => directions.any(
                (b) => (a.dx * b.dy - a.dy * b.dx).abs() >= .9239,
              ),
            );
          })
          .length,
      uncoveredPoints: List.unmodifiable(points),
      uncoveredSamples: points.length,
      maxSupportDistanceM: maxDistance,
    );
  }

  static InitialSchemeProposal _generateLayout({
    required StructuralProject project,
    required List<WallPairCandidate> wallPairs,
    required double scale,
    List<GeometricWindowOpening> wallOpenings = const [],
    InitialSchemeOptions options = const InitialSchemeOptions(),
    int variant = 0,
    bool preferColumnNodes = false,
    bool balancedWallPositions = true,
    bool sparseColumns = false,
  }) {
    if (!options.valid ||
        !StructuralSchemeReadiness.evaluate(project, scale).geometryReady) {
      return const InitialSchemeProposal();
    }
    final floor = project.activeStorey.copyWith(
      staircaseZones: project.staircaseZonesFor(project.activeStorey));
    final lowerLevels =
        project.storeys
            .where((s) => s.elevation < floor.elevation - 1e-6)
            .toList()
          ..sort((a, b) => b.elevation.compareTo(a.elevation));
    if (wallPairs.length > 800 ||
        wallOpenings.length > 800 ||
        lowerLevels.any((s) => s.columns.length + s.shearWalls.length > 500)) {
      return const InitialSchemeProposal(
        limited: true,
        limitReasons: {'input'},
      );
    }
    if (lowerLevels.isNotEmpty) {
      return _continueLowerStorey(
        project,
        lowerLevels.first,
        wallPairs,
        wallOpenings,
        scale,
      );
    }

    final openingColumnIds = <String>{};
    final columnRuns = <String, _WallRun>{};
    final rejectionReasons = <String, int>{};
    void reject(String reason) {
      rejectionReasons.update(reason, (n) => n + 1, ifAbsent: () => 1);
    }

    if (wallPairs.length > 800 ||
        wallOpenings.length > 800 ||
        project.effectiveGridAxes.length > 120 ||
        floor.columns.length + floor.shearWalls.length > 500) {
      return const InitialSchemeProposal(
        limited: true,
        limitReasons: {'input'},
      );
    }
    final domain = WallPlacementDomain.build(wallPairs, wallOpenings, scale);
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
    var seedBalance = double.infinity;
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
    final elementSlots = <String, int>{
      for (var i = 0; i < floor.columns.length; i++) floor.columns[i].id: i,
      for (var i = 0; i < floor.shearWalls.length; i++)
        floor.shearWalls[i].id: floor.columns.length + i,
    };
    final attemptsByStage = <String, int>{};
    final limitReasons = <String>{};
    var stage = 'core';
    bool budgetAvailable() {
      if ((attemptsByStage[stage] ?? 0) < options.placementAttemptsPerStage) {
        return true;
      }
      if (limitReasons.add('placement:$stage')) reject('budget');
      return false;
    }

    bool consumeAttempt() {
      if (!budgetAvailable()) {
        if (limitReasons.add('placement:$stage')) reject('budget');
        return false;
      }
      attemptsByStage.update(stage, (n) => n + 1, ifAbsent: () => 1);
      return true;
    }

    final directionCoverage = <int, Set<int>>{};
    final regionCache = <String, int>{};
    int uncachedRegionOf(List<Offset> poly) {
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

    int regionOf(List<Offset> poly) {
      final key = poly.map((p) => '${p.dx},${p.dy}').join(';');
      if (regionCache.containsKey(key)) return regionCache[key]!;
      final r = uncachedRegionOf(poly);
      if (regionCache.length < 8192) regionCache[key] = r;
      return r;
    }

    bool onRun(List<Offset> poly, _WallRun run) {
      if (!domain.contains(poly)) return false;
      // Longitudinal footprint must not extend into a door/window gap.
      return poly.every((p) {
        final along = dot(p - run.a, run.u);
        return along >= -1e-8 * scale && along <= run.length + 1e-8 * scale;
      });
    }

    bool slabFits(List<Offset> poly) =>
        SupportPlacementRules.circulationFits(poly, floor, scale) &&
        regionOf(poly) >= 0 &&
        !floor.slabs.any(
          (s) => s.openings.any(
            (hole) =>
                StructuralPolygonDistance.between(poly, hole) <= 1e-7 * scale,
          ),
        );
    bool allowed(
      List<Offset> poly,
      Offset center, {
      bool isWall = false,
      Offset? wallDirection,
    }) {
      if (!consumeAttempt()) return false;
      final reason = !slabFits(poly)
          ? 'slab'
          : SupportPlacementRules.separationReason(
              polygon: poly,
              center: center,
              isWall: isWall,
              wallDirection: wallDirection,
              columns: [...floor.columns, ...cols],
              walls: [...floor.shearWalls, ...walls],
              scale: scale,
              columnSpacingM: options.minSpacingM,
              wallSpacingM: options.minWallSpacingM,
            );
      if (reason != null) {
        reject(reason);
        return false;
      }
      // A sparse seed tests whether near-wall columns are redundant. This is
      // an optional seed strategy, not the mixed-support collision rule; other
      // seeds and the optimizer may retain/add them when the layout benefits.
      if (sparseColumns &&
          !isWall &&
          [...floor.shearWalls, ...walls].any(
            (w) =>
                (w.center - center).distance <
                options.minSpacingM * scale - 1e-8 * scale,
          )) {
        reject('seed-density');
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

    void addColumn(
      Offset p, {
      _WallRun? preferredRun,
      Offset? axisDirection,
      bool openingFallback = false,
    }) {
      if (cols.length + walls.length >= 300 || !budgetAvailable()) return;
      final run = preferredRun ?? nearRun(p);
      if (run == null) {
        reject('no-wall');
        return;
      }
      final u = run.u;
      var wallFitSeen = false;
      bool fits(StructuralColumn col) {
        final poly = col.shape == ColumnShape.circular
            ? SlabContactGeometry.columnFootprint(
                col.copyWith(width: col.width / math.cos(math.pi / 256)),
              )
            : col.polygonVertices;
        final wallFits = domain.contains(
          poly,
          includeOpenings: openingFallback,
        );
        wallFitSeen = wallFitSeen || wallFits;
        return wallFits && slabFits(poly);
      }

      final sections = <StructuralColumn>[];
      if (options.adaptiveSizes &&
          options.columnShape == ColumnShape.rectangular) {
        // Use a 5 cm module, a 20 cm screening floor, and the actual wall width.
        // Final load checks may enlarge the longitudinal side after placement.
        final across = math.min(
          math.min(options.columnWidthM, options.columnDepthM),
          ((run.width / scale + 1e-8) / .05).floor() * .05,
        );
        if (across < .20 - 1e-8) {
          reject('wall');
          return;
        }
        var along = math.max(options.columnWidthM, options.columnDepthM);
        final lengthM = run.length / scale;
        if (!openingFallback && lengthM >= along && lengthM <= .80 + 1e-8) {
          along = math.max(along, ((lengthM + 1e-8) / .05).floor() * .05);
        }
        if (lengthM < along - 1e-8) {
          reject('wall');
          return;
        }
        final t = dot(p - run.a, u)
            .clamp(
              along * scale / 2,
              math.max(along * scale / 2, run.length - along * scale / 2),
            )
            .toDouble();
        final projected = run.a + u * t;
        sections.add(
          StructuralColumn(
            id: '',
            center: projected,
            width: across * scale,
            height: along * scale,
            rotationRad: math.atan2(u.dy, u.dx) + math.pi / 2,
          ),
        );
      } else {
        final center = run.a + u * dot(p - run.a, u);
        final c = StructuralColumn(
          id: '',
          center: center,
          shape: options.columnShape,
          thickness: options.columnThicknessM * scale,
          width: options.columnWidthM * scale,
          height: options.columnDepthM * scale,
          rotationRad: math.atan2(u.dy, u.dx),
        );
        sections.add(c);
        if (c.shape != ColumnShape.circular) {
          sections.add(c.copyWith(rotationRad: c.rotationRad + math.pi / 2));
        }
      }
      StructuralColumn? chosen;
      for (final section in sections) {
        final positions = <Offset>[];
        {
          // Prefer a transverse grid axis, then an existing support row, if the
          // complete section still fits. Never force an axis through a slab step.
          for (final axis in project.effectiveGridAxes) {
            final v = axis.end - axis.start;
            final den = cross(u, v);
            if (v.distance == 0 || den.abs() < .9 * v.distance) continue;
            final t = cross(axis.start - run.a, v) / den;
            final q = cross(axis.start - run.a, u) / den;
            final aligned = run.a + u * t;
            if (q >= 0 &&
                q <= 1 &&
                (aligned - section.center).distance <= .40 * scale) {
              positions.add(aligned);
            }
          }
          for (final existing in [...floor.columns, ...cols]) {
            final aligned = run.a + u * dot(existing.center - run.a, u);
            if ((aligned - section.center).distance <= .40 * scale) {
              positions.add(aligned);
            }
          }
        }
        positions.add(section.center);
        for (final center in positions) {
          final c = section.copyWith(center: center);
          final candidateId = 'scheme:${floor.id}:c:${point(c.center)}';
          if (fits(c) &&
              !ids.contains(candidateId) &&
              allowed(SupportPlacementRules.columnFootprint(c), c.center)) {
            chosen = c;
            break;
          }
        }
        if (chosen != null) break;
      }
      if (chosen == null) {
        reject(wallFitSeen ? 'slab' : 'wall');
        return;
      }
      final id = 'scheme:${floor.id}:c:${point(chosen.center)}';
      if (ids.contains(id)) {
        return;
      }
      var c = chosen.copyWith(id: id, generatedBy: 'initial-scheme-v1');
      if (openingFallback && !domain.contains(c.polygonVertices)) {
        c = c.copyWith(generatedBy: 'initial-scheme-v2-opening-review');
        openingColumnIds.add(c.id);
      }
      cols.add(c);
      columnRuns[id] = run;
      elementSlots[c.id] = occupied.length;
      occupied.add(c.polygonVertices);
      centers.add(c.center);
      ids.add(id);
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
    final stairDistances = <_WallRun, double>{
      for (final run in runs)
        run:
            stairRings
                .map(
                  (ring) => StructuralPolygonDistance.between(
                    ring,
                    WallPlacementDomain.strip(run.a, run.b, run.width),
                  ),
                )
                .fold(double.infinity, math.min) /
            scale,
    };
    double stairDistance(_WallRun run) => stairDistances[run]!;
    final travel = WallPlacementNetwork.distances(
      runs.map((r) => PlacementWallSegment(r.a, r.b, r.width)).toList(),
      stairRings,
      domain.openings,
      scale,
    );
    final routeDistance = <_WallRun, double>{
      for (var i = 0; i < runs.length; i++) runs[i]: travel[i],
    };
    final wallRuns = List<_WallRun>.of(runs)
      ..sort((a, b) {
        final d = routeDistance[a]!.compareTo(routeDistance[b]!);
        return d != 0 ? d : point(a.a).compareTo(point(b.a));
      });
    double pointRoute(Offset p) {
      final run = nearRun(p);
      return run == null
          ? double.infinity
          : routeDistance[run]! + (p - run.center).distance / scale;
    }

    double wallThicknessFor(_WallRun run) => options.adaptiveSizes
        ? math.min(
            options.wallThicknessM * scale,
            ((run.width / scale + 1e-8) / .05).floor() * .05 * scale,
          )
        : options.wallThicknessM * scale;

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
    if (preferColumnNodes) {
      stage = 'columns';
      var work = 0;
      for (var i = 0; i < runs.length && work < 5000; i++) {
        for (var j = 0; j < i && work < 5000; j++) {
          work++;
          final a = runs[i], b = runs[j], u = a.b - a.a, v = b.b - b.a;
          final den = cross(u, v);
          if (den.abs() <= 1e-8 * u.distance * v.distance) continue;
          final t = cross(b.a - a.a, v) / den, q = cross(b.a - a.a, u) / den;
          if (t >= 0 && t <= 1 && q >= 0 && q <= 1) {
            addColumn(a.a + u * t, preferredRun: a);
          }
        }
      }
      if (work >= 5000) limitReasons.add('junctions');
      stage = 'core';
    }
    for (final run in wallRuns) {
      if (walls.length + cols.length >= 300 || !budgetAvailable()) break;
      if (stairDistance(run) > 1.5 ||
          run.length < options.wallLengthM * scale ||
          direction(run) > 1) {
        continue;
      }
      final half = options.wallLengthM * scale / 2;
      final core = stairDistance(run) <= 1.5;
      final positions = <double>[
        if (sparseColumns) run.length / 2,
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
          thickness: wallThicknessFor(run),
          generatedBy: 'initial-scheme-v1',
        );
        final r = regionOf(w.polygonVertices);
        if (w.thickness < .20 * scale - 1e-8 ||
            r < 0 ||
            ids.contains(w.id) ||
            !onRun(w.polygonVertices, run) ||
            !allowed(
              w.polygonVertices,
              center,
              isWall: true,
              wallDirection: run.u,
            )) {
          continue;
        }
        walls.add(w);
        seedBalance = SupportLayoutEvaluator.balanceIndex(
          project,
          floor.copyWith(
            columns: [...floor.columns, ...cols],
            shearWalls: [...floor.shearWalls, ...walls],
          ),
          scale,
        );
        elementSlots[w.id] = occupied.length;
        occupied.add(w.polygonVertices);
        centers.add(center);
        ids.add(w.id);
        directionCoverage.putIfAbsent(r, () => {}).add(direction(run));
        break;
      }
    }
    Offset regionCentroid(int r) {
      final slabs = [for (final i in regions[r]) floor.slabs[i]];
      final pts = slabs.expand((s) => s.polygon).toList();
      final bounds = Rect.fromLTRB(
        pts.map((p) => p.dx).reduce(math.min),
        pts.map((p) => p.dy).reduce(math.min),
        pts.map((p) => p.dx).reduce(math.max),
        pts.map((p) => p.dy).reduce(math.max),
      );
      return SlabContactGeometry.measure(
            [
              bounds.topLeft,
              bounds.topRight,
              bounds.bottomRight,
              bounds.bottomLeft,
            ],
            slabs,
            scale,
          )?.centroidCad ??
          bounds.center;
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
      if (walls.length + cols.length >= 300 || !budgetAvailable()) return false;
      final targetLenM = overrideLengthM ?? options.wallLengthM;
      if (targetLenM < 1.0 || run.length < targetLenM * scale) return false;
      final half = targetLenM * scale / 2;
      final positions = <double>[
        half + (run.length - 2 * half) * (variant == 0 ? .5 : phase),
        half,
        run.length - half,
      ];
      final validWalls = <({StructuralShearWall wall, double balance})>[];
      for (final along in positions) {
        final center = run.a + run.u * along;
        final w = StructuralShearWall(
          id: 'scheme:${floor.id}:w:${point(center)}',
          start: center - run.u * (targetLenM * scale / 2),
          end: center + run.u * (targetLenM * scale / 2),
          thickness: wallThicknessFor(run),
          generatedBy: 'initial-scheme-v1',
        );
        if (w.thickness < .20 * scale - 1e-8 || ids.contains(w.id)) continue;
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
        if (!allowed(
          w.polygonVertices,
          center,
          isWall: true,
          wallDirection: run.u,
        )) {
          continue;
        }

        final trialFloor = floor.copyWith(
          columns: [...floor.columns, ...cols],
          shearWalls: [...floor.shearWalls, ...walls, w],
        );
        validWalls.add((
          wall: w,
          balance: SupportLayoutEvaluator.balanceIndex(
            project,
            trialFloor,
            scale,
          ),
        ));
      }
      if (validWalls.isEmpty) return false;
      if (balancedWallPositions) {
        validWalls.sort((a, b) {
          final delta = a.balance - b.balance;
          return delta.isFinite && delta.abs() > 1e-8 ? delta.sign.toInt() : 0;
        });
      }
      final w = validWalls.first.wall;
      walls.add(w);
      seedBalance = validWalls.first.balance;
      elementSlots[w.id] = occupied.length;
      occupied.add(w.polygonVertices);
      centers.add(w.center);
      ids.add(w.id);
      directionCoverage.putIfAbsent(r, () => {}).add(d);
      return true;
    }

    stage = 'walls';
    // Shear wall pairing engine
    for (var r = 0; r < regions.length; r++) {
      final cm = regionCentroid(r);
      final area = regionAreaM2(r);

      for (final dir in [0, 1]) {
        final targetCount = options.enforcePairedWalls
            ? (options.generousDensity && area > 140 ? 4 : 2)
            : 2;
        final transverse = dir == 0 ? perp : primary;
        List<StructuralShearWall> matchingWalls() =>
            [...floor.shearWalls, ...walls]
                .where(
                  (w) =>
                      w.length > 0 &&
                      regionOf(w.polygonVertices) == r &&
                      elementDirection((w.end - w.start) / w.length) == dir,
                )
                .toList();
        bool hasOppositeSides() {
          final positions = matchingWalls().map(
            (w) => dot(w.center - cm, transverse) / scale,
          );
          return positions.any((v) => v < -.25) &&
              positions.any((v) => v > .25);
        }

        // A wall count must not end the search while all walls occupy one side.
        if (existingWallsInDir(r, dir) >= targetCount &&
            (!options.enforcePairedWalls || hasOppositeSides())) {
          continue;
        }

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

        // Re-rank after each accepted wall using the actual distribution.
        // Prefer a missing side, then reduce the transverse stiffness offset.
        final remaining = List<_WallRun>.of(ordered);
        while (remaining.isNotEmpty) {
          final count = existingWallsInDir(r, dir);
          if (count >= targetCount &&
              (!options.enforcePairedWalls || hasOppositeSides())) {
            break;
          }
          if (count >= targetCount + 1) break;
          final existing = matchingWalls();
          double score(_WallRun run) {
            final t = dot(run.center - cm, transverse) / scale;
            final positions = existing
                .map((w) => dot(w.center - cm, transverse) / scale)
                .toList();
            final missingSide =
                positions.isNotEmpty &&
                ((positions.every((p) => p >= -.25) && t < -.25) ||
                    (positions.every((p) => p <= .25) && t > .25));
            // Keep a regular midpoint seed as a competing layout. The other
            // seeds rank positions by the seismic report; all final candidates
            // still go through the same full layout evaluator.
            if (!balancedWallPositions) {
              var sum = 0.0, weight = 0.0;
              for (final w in existing) {
                final k = math.pow(w.length / scale, 3).toDouble();
                sum += dot(w.center - cm, transverse) / scale * k;
                weight += k;
              }
              final k = math.pow(options.wallLengthM, 3).toDouble();
              return (missingSide ? -1e6 : 0) +
                  (sum + t * k).abs() / (weight + k);
            }
            final half = options.wallLengthM * scale / 2;
            final center =
                run.a +
                run.u *
                    (half +
                        (run.length - 2 * half) * (variant == 0 ? .5 : phase));
            final trial = StructuralShearWall(
              id: 'balance-trial',
              start: center - run.u * half,
              end: center + run.u * half,
              thickness: wallThicknessFor(run),
            );
            final value = SupportLayoutEvaluator.balanceIndex(
              project,
              floor.copyWith(
                columns: [...floor.columns, ...cols],
                shearWalls: [...floor.shearWalls, ...walls, trial],
              ),
              scale,
            );
            return (missingSide ? -1e6 : 0) + (value.isFinite ? value : 1e3);
          }

          final scores = <_WallRun, double>{
            for (final run in remaining) run: score(run),
          };

          remaining.sort((a, b) {
            final delta = scores[a]! - scores[b]!;
            final d = delta.abs() > 1e-8 ? delta.sign.toInt() : 0;
            return d != 0 ? d : point(a.a).compareTo(point(b.a));
          });
          final run = remaining.removeAt(0);
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
              minWallSpacingM: math.max(options.minWallSpacingM * 1.2, 2.5),
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
              minWallSpacingM: math.max(options.minWallSpacingM * 1.2, 2.5),
              overrideLengthM: math.max(1.0, options.wallLengthM * 0.75),
            );
          }
        }
      }
    }

    StoreyLevel layoutFloor() => floor.copyWith(
      columns: [...floor.columns, ...cols],
      shearWalls: [...floor.shearWalls, ...walls],
      gridAxes: project.effectiveGridAxes,
    );
    var density = SeismicAnalysisCalculator.wallDensity(layoutFloor(), scale);
    seedBalance = SupportLayoutEvaluator.balanceIndex(
      project,
      layoutFloor(),
      scale,
    );
    if (options.adaptiveSizes) {
      // Grow accepted walls in their solid runs before consuming more positions.
      // The 1% target is the report's
      // screening reference, not a normative proof of seismic capacity.
      for (
        var pass = 0;
        pass < 40 && (density.deficitX > 1e-6 || density.deficitY > 1e-6);
        pass++
      ) {
        var changed = false;
        final candidates = List<int>.generate(walls.length, (i) => i);
        final centroid = regions.isEmpty ? Offset.zero : regionCentroid(0);
        candidates.sort((a, b) {
          final d =
              ((walls[b].center - centroid).distance -
                  (walls[a].center - centroid).distance) /
              scale;
          return d.abs() > 1e-8
              ? d.sign.toInt()
              : walls[a].id.compareTo(walls[b].id);
        });
        for (final index in candidates) {
          final old = walls[index];
          final run = nearRun(old.center);
          if (run == null ||
              dot(run.u, (old.end - old.start) / old.length).abs() < .999) {
            continue;
          }
          final x = run.u.dx.abs(), y = run.u.dy.abs();
          if (x * density.deficitX + y * density.deficitY < 1e-6) continue;
          final nextLength = math.min(
            options.effectiveMaxWallLengthM * scale,
            old.length + .10 * scale,
          );
          if (nextLength <= old.length + 1e-8 * scale) continue;
          if (nextLength > run.length + 1e-8 * scale) continue;
          final t = dot(old.center - run.a, run.u).clamp(
            nextLength / 2,
            math.max(nextLength / 2, run.length - nextLength / 2),
          );
          final center = run.a + run.u * t.toDouble();
          final trial = old.copyWith(
            start: center - run.u * nextLength / 2,
            end: center + run.u * nextLength / 2,
          );
          final actualIndex = elementSlots[old.id];
          if (actualIndex == null ||
              !onRun(trial.polygonVertices, run) ||
              !slabFits(trial.polygonVertices) ||
              SupportPlacementRules.separationReason(
                    polygon: trial.polygonVertices,
                    center: center,
                    isWall: true,
                    wallDirection: run.u,
                    columns: [...floor.columns, ...cols],
                    walls: [...floor.shearWalls, ...walls],
                    skipId: old.id,
                    scale: scale,
                    columnSpacingM: options.minSpacingM,
                    wallSpacingM: options.minWallSpacingM,
                  ) !=
                  null ||
              occupied.asMap().entries.any(
                (e) =>
                    e.key != actualIndex &&
                    StructuralPolygonDistance.between(
                          e.value,
                          trial.polygonVertices,
                        ) <
                        .05 * scale,
              )) {
            continue;
          }
          final trialBalance = SupportLayoutEvaluator.balanceIndex(
            project,
            layoutFloor().copyWith(
              shearWalls: [
                ...floor.shearWalls,
                for (final w in walls) w.id == old.id ? trial : w,
              ],
            ),
            scale,
          );
          // The regular geometry seed keeps its competing midpoint strategy.
          // Balance-oriented seeds stop growth which worsens the seismic score,
          // even if the auxiliary wall-area target has not been attained.
          if (balancedWallPositions &&
              seedBalance.isFinite &&
              (!trialBalance.isFinite || trialBalance > seedBalance + 1e-8)) {
            continue;
          }
          seedBalance = trialBalance;
          walls[index] = trial;
          occupied[actualIndex] = trial.polygonVertices;
          centers[actualIndex] = trial.center;
          density = SeismicAnalysisCalculator.wallDensity(layoutFloor(), scale);
          changed = true;
          if (density.deficitX <= 1e-6 && density.deficitY <= 1e-6) break;
        }
        if (!changed) break;
      }
      // Two walls per direction can still have insufficient area. Add further
      // admissible, distributed walls instead of stopping at the count.
      for (
        var pass = 0;
        pass < 24 && (density.deficitX > 1e-6 || density.deficitY > 1e-6);
        pass++
      ) {
        var changed = false;
        final ordered = List<_WallRun>.of(wallRuns)
          ..sort((a, b) {
            double score(_WallRun r) =>
                r.length /
                scale *
                (r.u.dx.abs() * density.deficitX +
                    r.u.dy.abs() * density.deficitY);
            final d = score(b).compareTo(score(a));
            return d != 0 ? d : point(a.a).compareTo(point(b.a));
          });
        for (final run in ordered) {
          if (run.u.dx.abs() * density.deficitX +
                  run.u.dy.abs() * density.deficitY <
              1e-6) {
            continue;
          }
          final thicknessM = wallThicknessFor(run) / scale;
          if (thicknessM < .20 || run.length / scale < 1) continue;
          final need = math.max(
            run.u.dx.abs() > .1 ? density.deficitX / run.u.dx.abs() : 0.0,
            run.u.dy.abs() > .1 ? density.deficitY / run.u.dy.abs() : 0.0,
          );
          final desired = math.min(
            options.effectiveMaxWallLengthM,
            math.min(
              run.length / scale,
              math.max(
                options.wallLengthM,
                (need / thicknessM / .10 - 1e-8).ceil() * .10,
              ),
            ),
          );
          for (var reg = 0; reg < regions.length && !changed; reg++) {
            for (var length = desired; length >= 1 - 1e-8; length -= .10) {
              if (tryAddWall(
                run,
                reg,
                direction(run),
                minWallSpacingM: options.minWallSpacingM,
                overrideLengthM: length,
              )) {
                density = SeismicAnalysisCalculator.wallDensity(
                  layoutFloor(),
                  scale,
                );
                changed = true;
                break;
              }
            }
          }
          if (changed) break;
        }
        if (!changed) break;
      }
    }

    stage = 'columns';
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
          addColumn(run.a + run.u * along, preferredRun: run);
        }
      }
    }

    final axes = List<StructuralGridAxis>.of(project.effectiveGridAxes)
      ..sort((a, b) => a.id.compareTo(b.id));
    final intersectionCandidates = <Offset>[];
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
          intersectionCandidates.add(p);
        }
      }
    }
    // 4. Exact and fuzzy wall junctions
    var junctionWork = 0;
    for (var i = 0; i < runs.length && junctionWork < 50000; i++) {
      for (var j = 0; j < i && junctionWork < 50000; j++) {
        junctionWork++;
        if (cols.length + walls.length >= 300 || !budgetAvailable()) break;
        final a = runs[i], b = runs[j], u = a.b - a.a, v = b.b - b.a;
        final den = cross(u, v);
        if (den.abs() > 1e-8 * u.distance * v.distance) {
          final t = cross(b.a - a.a, v) / den;
          final s = cross(b.a - a.a, u) / den;
          if (t >= -0.15 && t <= 1.15 && s >= -0.15 && s <= 1.15) {
            intersectionCandidates.add(a.a + u * t.clamp(0.0, 1.0).toDouble());
          }
        }
        for (final pt in [a.a, a.b]) {
          final d = StructuralPolygonDistance.pointToSegment(pt, b.a, b.b);
          if (d <= math.max(0.35 * scale, b.width * 1.2)) {
            final along = dot(pt - b.a, b.u).clamp(0.0, b.length).toDouble();
            intersectionCandidates.add(b.a + b.u * along);
          }
        }
        for (final pt in [b.a, b.b]) {
          final d = StructuralPolygonDistance.pointToSegment(pt, a.a, a.b);
          if (d <= math.max(0.35 * scale, a.width * 1.2)) {
            final along = dot(pt - a.a, a.u).clamp(0.0, a.length).toDouble();
            intersectionCandidates.add(a.a + a.u * along);
          }
        }
      }
    }

    intersectionCandidates.sort((a, b) {
      final d = pointRoute(a).compareTo(pointRoute(b));
      return d != 0 ? d : point(a).compareTo(point(b));
    });
    for (final p in intersectionCandidates) {
      addColumn(p);
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
                          : options.targetSpacingM / 2)))
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

    for (final run in wallRuns) {
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
    stage = 'coverage';
    // Prefer the nearest admissible position to each unsupported edge sample.
    // No column is invented outside architectural walls or inside a slab opening.
    for (final probe in [...boundaryProbes, ...interiorProbes]) {
      while (supportDistance(probe.p, probe.region) > coverageRadius &&
          cols.length + walls.length < 300 &&
          budgetAvailable()) {
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
    while (cols.length + walls.length < 300 && budgetAvailable()) {
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
    StoreyLevel assessedFloor() => floor.copyWith(
      columns: [...floor.columns, ...cols],
      shearWalls: [...floor.shearWalls, ...walls],
      gridAxes: project.effectiveGridAxes,
    );
    var span = VerticalCapacityCalculator.calculateClearSpan(
      assessedFloor(),
      scale,
    );
    var intervals = VerticalCapacityCalculator.calculateSupportSpans(
      assessedFloor(),
      scale,
    );
    bool improves(List<({double spanM, (Offset, Offset) segment})> trial) {
      if (trial.isEmpty) return false;
      for (var i = 0; i < math.min(intervals.length, trial.length); i++) {
        final delta = trial[i].spanM - intervals[i].spanM;
        if (delta.abs() > 1e-6) return delta < 0;
      }
      return trial.length < intervals.length;
    }

    stage = 'repair';
    // Geometry failures stay excluded, but positions discarded by coverage or
    // an earlier score are reconsidered under the support-field objective.
    used.clear();
    // Repair a critical support interval using only remaining solid-wall positions.
    // Trial additions must reduce the shared metric, not just a nearest-point radius.
    for (
      var pass = 0;
      pass < 20 &&
          span.maxSpanM.isFinite &&
          (span.maxSpanM > options.targetSpacingM ||
              !VerticalCapacityCalculator.evaluateSlabSpan(
                assessedFloor(),
                scale,
              ).isDeflectionSafe);
      pass++
    ) {
      var improved = false;
      for (var i = 0; i < candidates.length; i++) {
        if (used.contains(i)) continue;
        final before = cols.length;
        tryCandidate(i);
        if (cols.length == before) continue;
        final trial = VerticalCapacityCalculator.calculateSupportSpans(
          assessedFloor(),
          scale,
        );
        if (improves(trial)) {
          intervals = trial;
          span = VerticalCapacityCalculator.calculateClearSpan(
            assessedFloor(),
            scale,
          );
          improved = true;
          break;
        }
        final rejected = cols.removeLast();
        occupied.removeLast();
        centers.removeLast();
        supportRegions.removeLast();
        ids.remove(rejected.id);
        columnRuns.remove(rejected.id);
        elementSlots.remove(rejected.id);
      }
      if (!improved) break;
    }
    stage = 'openings';
    // Only after all useful solid candidates have been tried, consider explicit
    // jamb-bounded architectural openings. Slab holes are still never allowed.
    for (final opening in domain.openings) {
      final run = _WallRun(opening.start, opening.end, opening.thickness);
      final count = math.max(
        1,
        math.min(30, (run.length / (options.minSpacingM * scale / 2)).ceil()),
      );
      for (var k = 0; k <= count; k++) {
        final p = run.a + run.u * (run.length * k / count);
        final region = pointRegion(p);
        if (region < 0 || supportDistance(p, region) <= coverageRadius) {
          continue;
        }
        final before = cols.length;
        addColumn(p, preferredRun: run, openingFallback: true);
        if (cols.length > before) supportRegions.add(regionOf(occupied.last));
      }
    }
    final columnSizingReviewIds = <String>{};
    if (options.adaptiveSizes) {
      StructuralProject assessedProject() => project.copyWith(
        storeys: [
          for (final f in project.storeys)
            f.id == floor.id ? assessedFloor() : f,
        ],
      );
      // Reuse the application's load accumulation, axial and punching checks.
      // Enlarge only the longitudinal side in 5 cm steps, within solid geometry.
      for (var pass = 0; pass < 3; pass++) {
        final loadReport = VerticalCapacityCalculator.analyzeProject(
          assessedProject(),
          cadUnitsPerMeter: scale,
        );
        var changed = false;
        for (final check in loadReport.columnChecks.where(
          (c) => c.storeyId == floor.id,
        )) {
          if (check.axialUtilization <= .80 &&
              check.punchingUtilization <= .85) {
            continue;
          }
          final index = cols.indexWhere((c) => c.id == check.columnId);
          if (index < 0) {
            continue;
          }
          final old = cols[index], run = columnRuns[check.columnId];
          if (run == null || old.shape != ColumnShape.rectangular) continue;
          final requiredArea =
              check.crossSectionAreaM2 * check.axialUtilization / .80;
          final targetAlong = math.max(
            old.height / scale + .05,
            ((requiredArea / (old.width / scale) / .05) - 1e-8).ceil() * .05,
          );
          final maxAlong = math.min(.80, run.length / scale);
          for (
            var length = math.min(targetAlong, maxAlong);
            length > old.height / scale + 1e-8;
            length -= .05
          ) {
            final trial = old.copyWith(height: length * scale);
            final oldIndex = elementSlots[old.id];
            if (oldIndex == null ||
                !domain.contains(
                  trial.polygonVertices,
                  includeOpenings: openingColumnIds.contains(old.id),
                ) ||
                !slabFits(trial.polygonVertices) ||
                occupied.asMap().entries.any(
                  (e) =>
                      e.key != oldIndex &&
                      StructuralPolygonDistance.between(
                            e.value,
                            trial.polygonVertices,
                          ) <
                          .05 * scale,
                )) {
              continue;
            }
            cols[index] = trial;
            occupied[oldIndex] = trial.polygonVertices;
            changed = true;
            break;
          }
        }
        if (!changed) break;
      }
      final finalLoads = VerticalCapacityCalculator.analyzeProject(
        assessedProject(),
        cadUnitsPerMeter: scale,
      );
      columnSizingReviewIds.addAll(
        finalLoads.columnChecks
            .where(
              (c) =>
                  c.storeyId == floor.id &&
                  cols.any((col) => col.id == c.columnId) &&
                  (c.axialUtilization > .80 || c.punchingUtilization > .85),
            )
            .map((c) => c.columnId),
      );
    }
    span = VerticalCapacityCalculator.calculateClearSpan(
      assessedFloor(),
      scale,
    );
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
      rejectedCandidates: rejectionReasons.values.fold<int>(0, (a, b) => a + b),
      rejectionReasons: Map.unmodifiable(rejectionReasons),
      wallRatioX: density.ratioX,
      wallRatioY: density.ratioY,
      wallDeficitXM2: density.deficitX,
      wallDeficitYM2: density.deficitY,
      columnSizingReviewIds: Set.unmodifiable(columnSizingReviewIds),
      resizedColumnIds: Set.unmodifiable(
        cols
            .where(
              (c) =>
                  ((c.width / scale - options.columnWidthM).abs() > 1e-6 ||
                  (c.height / scale - options.columnDepthM).abs() > 1e-6),
            )
            .map((c) => c.id),
      ),
      openingColumnIds: Set.unmodifiable(openingColumnIds),
      maxSupportSpanM: span.maxSpanM.isFinite ? span.maxSpanM : null,
      criticalSupportSpan: span.criticalSpanSegment,
      spanCheck: VerticalCapacityCalculator.evaluateSlabSpan(
        assessedFloor(),
        scale,
      ),
      uncoveredSamples: uncovered,
      uncoveredPoints: List.unmodifiable(uncoveredPoints),
      maxSupportDistanceM: maxDistance,
      unresolvedRegions: List.generate(regions.length, (i) => i)
          .where((r) => !(directionCoverage[r]?.containsAll({0, 1}) ?? false))
          .length,
      attemptsByStage: Map.unmodifiable(attemptsByStage),
      limitReasons: Set.unmodifiable({
        ...limitReasons,
        for (final e in attemptsByStage.entries)
          if (e.value >= options.placementAttemptsPerStage)
            'placement:${e.key}',
        if (samplingLimited) 'sampling',
        if (cols.length + walls.length >= 300) 'elements',
        if (junctionWork >= 50000) 'junctions',
      }),
      limited:
          limitReasons.isNotEmpty ||
          samplingLimited ||
          attemptsByStage.values.any(
            (n) => n >= options.placementAttemptsPerStage,
          ) ||
          cols.length + walls.length >= 300 ||
          junctionWork >= 50000,
    );
  }
}
