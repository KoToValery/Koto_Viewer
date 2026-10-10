import 'dart:math' as math;
import 'dart:ui';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'seismic_analysis_calculator.dart';
import 'slab_boundary_geometry.dart';
import 'slab_contact_geometry.dart';
import 'slab_support_topology.dart';
import 'slab_topology_analyzer.dart';
import 'structural_geometry_units.dart';
import 'column_vertical_continuity.dart';
import 'wall_vertical_continuity.dart';
import '../models/seismic_analysis_models.dart';
import 'structural_polygon_distance.dart';
import 'vertical_capacity_calculator.dart';

class OpeningSupportCheck {
  final String slabId;
  final Offset point;
  final double distanceM;
  final double targetDistanceM;
  const OpeningSupportCheck(
    this.slabId,
    this.point,
    this.distanceM, {
    this.targetDistanceM = 1,
  });
  bool get requiresReview => !distanceM.isFinite || distanceM > targetDistanceM;
}

class BoundarySupportCheck {
  final Offset point;
  final double distanceM;

  /// A nearest column is not evidence of a continuous cantilever root.
  final bool hasSupportLine;
  final double thicknessM;
  const BoundarySupportCheck(
    this.point,
    this.distanceM,
    this.hasSupportLine,
    this.thicknessM,
  );
  // A close column alone cannot establish a continuous cantilever root.
  bool get requiresReview => !hasSupportLine;
  bool get problematic => hasSupportLine && distanceM > 7 * thicknessM;
}

/// The same score and diagnostics are used by manual inspection, seed ranking
/// and every accepted local change. All strength/stiffness values are preliminary.
class SupportLayoutAssessment {
  final SlabSupportTopology topology;
  final List<SupportSpanCheck> spans;
  final List<OpeningSupportCheck> openings;
  final List<BoundarySupportCheck> boundaries;
  final int continuityIssues, unavailableChecks, columnIssues;
  final double structuralPenalty,
      balancePenalty,
      balanceTargetPenalty,
      concreteVolumeM3;
  final int supportCount;
  final bool balanceAvailable;
  const SupportLayoutAssessment({
    required this.topology,
    required this.spans,
    required this.openings,
    required this.boundaries,
    required this.continuityIssues,
    required this.unavailableChecks,
    required this.columnIssues,
    required this.structuralPenalty,
    required this.balancePenalty,
    this.balanceTargetPenalty = 0,
    required this.concreteVolumeM3,
    required this.supportCount,
    this.balanceAvailable = true,
  });
  int get problematicFields => topology.fields
      .where((f) => f.utilization > 1 || f.requiresReview)
      .length;
  int get openingReviews => openings.where((p) => p.requiresReview).length;
  int get boundaryReviews =>
      boundaries.where((p) => p.requiresReview || p.problematic).length;
  double get maxSpanM =>
      spans.isEmpty ? double.nan : spans.map((s) => s.spanM).reduce(math.max);

  int compareTo(SupportLayoutAssessment other) {
    for (final pair in [
      (continuityIssues, other.continuityIssues),
      (unavailableChecks, other.unavailableChecks),
    ]) {
      final c = pair.$1.compareTo(pair.$2);
      if (c != 0) return c;
    }
    for (final pair in [
      (topology.unresolvedAreaM2, other.topology.unresolvedAreaM2),
      // Capacity and elastic regularity deficits are assessed together. A
      // tiny reduction of a gravity penalty must not buy a large torsion deficit.
      (
        structuralPenalty + balanceTargetPenalty,
        other.structuralPenalty + other.balanceTargetPenalty,
      ),
      (concreteVolumeM3, other.concreteVolumeM3),
      (balancePenalty, other.balancePenalty),
    ]) {
      final delta = pair.$1 - pair.$2;
      if (delta.abs() > 1e-6) return delta.sign.toInt();
    }
    return supportCount.compareTo(other.supportCount);
  }

  SupportLayoutAssessment mapPoints(Offset Function(Offset) transform) {
    return SupportLayoutAssessment(
      topology: SlabSupportTopology(
        fields: [
          for (final f in topology.fields)
            SlabSupportField(
              polygon: f.polygon.map(transform).toList(),
              lxM: f.lxM,
              lyM: f.lyM,
              thicknessM: f.thicknessM,
              requiresReview: f.requiresReview,
            ),
        ],
        unresolvedAreaM2: topology.unresolvedAreaM2,
        limited: topology.limited,
        invalidGeometry: topology.invalidGeometry,
      ),
      spans: [
        for (final s in spans)
          SupportSpanCheck(
            segment: (transform(s.segment.$1), transform(s.segment.$2)),
            spanM: s.spanM,
            thicknessM: s.thicknessM,
            allowableSpanM: s.allowableSpanM,
            slabIds: s.slabIds,
            hasBeams: s.hasBeams,
          ),
      ],
      openings: [
        for (final p in openings)
          OpeningSupportCheck(
            p.slabId,
            transform(p.point),
            p.distanceM,
            targetDistanceM: p.targetDistanceM,
          ),
      ],
      boundaries: [
        for (final p in boundaries)
          BoundarySupportCheck(
            transform(p.point),
            p.distanceM,
            p.hasSupportLine,
            p.thicknessM,
          ),
      ],
      continuityIssues: continuityIssues,
      unavailableChecks: unavailableChecks,
      columnIssues: columnIssues,
      structuralPenalty: structuralPenalty,
      balancePenalty: balancePenalty,
      balanceTargetPenalty: balanceTargetPenalty,
      concreteVolumeM3: concreteVolumeM3,
      supportCount: supportCount,
      balanceAvailable: balanceAvailable,
    );
  }

  Map<String, Object?> toMetrics() => {
    'supportCount': supportCount,
    'balanceAvailable': balanceAvailable,
    'concreteVolumeM3': concreteVolumeM3,
    'maxSpanM': maxSpanM.isFinite ? maxSpanM : null,
    'fields': topology.fields.length,
    'problematicFields': problematicFields,
    'unresolvedAreaM2': topology.unresolvedAreaM2,
    'openingReviews': openingReviews,
    'boundaryReviews': boundaryReviews,
    'continuityIssues': continuityIssues,
    'unavailableChecks': unavailableChecks,
    'columnIssues': columnIssues,
    'structuralPenalty': structuralPenalty,
    'balancePenalty': balancePenalty,
    'balanceTargetPenalty': balanceTargetPenalty,
  };
}

class SupportLayoutEvaluator {
  static SupportLayoutAssessment evaluate(
    StructuralProject project,
    StoreyLevel floor,
    double scale, {
    double openingDistanceM = 1,
  }) {
    if (!scale.isFinite || scale <= 0) {
      return const SupportLayoutAssessment(
        topology: SlabSupportTopology(invalidGeometry: true),
        spans: [],
        openings: [],
        boundaries: [],
        continuityIssues: 0,
        unavailableChecks: 1,
        columnIssues: 0,
        structuralPenalty: 100,
        balancePenalty: 100,
        concreteVolumeM3: 0,
        supportCount: 0,
        balanceAvailable: false,
      );
    }
    final origin = floor.slabs.firstOrNull?.polygon.firstOrNull ?? Offset.zero;
    final units = StructuralGeometryUnits(scale, origin);
    final result = _evaluate(
      units.project(project),
      units.floor(floor),
      1,
      openingDistanceM: openingDistanceM,
    );
    return result.mapPoints(units.toCad);
  }

  static ({double penalty, double targetPenalty, int unavailable}) _rigidity(
    SeismicAnalysisReport report,
    String floorId,
  ) {
    var unavailable = 0;
    var balance = 0.0, targetPenalty = 0.0;
    for (final s in report.storeyChecks) {
      if (s.storeyId != floorId) continue;
      final checks = s.diaphragmRegions.isEmpty
          ? [s]
          : s.diaphragmRegions
                .map((r) => r.check)
                .whereType<StoreySeismicCheck>()
                .toList();
      if (checks.isEmpty) unavailable++;
      for (final check in checks) {
        if (!check.hasLateralStiffness ||
            check.eccentricityM == null ||
            check.torsionalRadiusX <= 0 ||
            check.torsionalRadiusY <= 0) {
          unavailable++;
          continue;
        }
        final e = check.eccentricityM!;
        targetPenalty +=
            math.pow(math.max(0, e.dx.abs() / check.torsionalRadiusX - .3), 2) +
            math.pow(math.max(0, e.dy.abs() / check.torsionalRadiusY - .3), 2) +
            math.pow(
              math.max(
                0,
                check.massRadiusOfGyration / check.torsionalRadiusX - 1,
              ),
              2,
            ) +
            math.pow(
              math.max(
                0,
                check.massRadiusOfGyration / check.torsionalRadiusY - 1,
              ),
              2,
            );
        balance +=
            math.pow(e.dx.abs() / math.max(check.torsionalRadiusX, .001), 2) +
            math.pow(e.dy.abs() / math.max(check.torsionalRadiusY, .001), 2) +
            math.pow(
              math.max(
                0,
                check.massRadiusOfGyration / check.torsionalRadiusX - 1,
              ),
              2,
            ) +
            math.pow(
              math.max(
                0,
                check.massRadiusOfGyration / check.torsionalRadiusY - 1,
              ),
              2,
            );
      }
    }
    return (
      penalty: balance,
      targetPenalty: targetPenalty,
      unavailable: unavailable,
    );
  }

  static double balanceIndex(
    StructuralProject project,
    StoreyLevel floor,
    double scale,
  ) {
    final units = StructuralGeometryUnits(
      scale,
      floor.slabs.firstOrNull?.polygon.firstOrNull ?? Offset.zero,
    );
    final normalized = units.project(project);
    final assessed = normalized.copyWith(
      storeys: [
        for (final s in normalized.storeys)
          s.id == floor.id ? units.floor(floor) : s,
      ],
    );
    final report = SeismicAnalysisCalculator.analyzeProject(
      assessed,
      cadUnitsPerMeter: 1,
    );
    final rigidity = _rigidity(report, floor.id);
    return rigidity.unavailable > 0 ? double.infinity : rigidity.penalty;
  }

  static SupportLayoutAssessment _evaluate(
    StructuralProject project,
    StoreyLevel floor,
    double scale, {
    double openingDistanceM = 1,
  }) {
    final assessed = project.copyWith(
      storeys: [for (final s in project.storeys) s.id == floor.id ? floor : s],
    );
    final spans = VerticalCapacityCalculator.evaluateSupportSpans(floor, scale);
    final topology = SlabSupportTopology.analyze(
      floor,
      scale,
      intervals: spans,
    );
    final slabRegions = SlabSupportRegions(floor, scale);
    double distance(Offset p) => slabRegions.distance(p) / scale;
    final openings = <OpeningSupportCheck>[];
    for (final s in floor.slabs) {
      for (final hole in s.openings) {
        for (var i = 0; i < hole.length; i++) {
          // Corner and edge midpoint checks are independent from broad coverage.
          for (final p in [
            hole[i],
            (hole[i] + hole[(i + 1) % hole.length]) / 2,
          ]) {
            openings.add(
              OpeningSupportCheck(
                s.id,
                p,
                distance(p),
                targetDistanceM: openingDistanceM,
              ),
            );
          }
        }
      }
    }
    final boundaries = <BoundarySupportCheck>[];
    for (final edge in SlabBoundaryGeometry.exposedEdges(floor.slabs, scale)) {
      if (edge.opening) continue;
      final p = (edge.a + edge.b) / 2;
      final nearest = distance(p);
      var lineDistance = double.infinity;
      for (final line in [
        ...floor.shearWalls.map((w) => (w.start, w.end)),
        ...floor.beams.map((b) => (b.start, b.end)),
      ]) {
        final u = line.$2 - line.$1;
        if (u.distance == 0) continue;
        final t =
            (((p - line.$1).dx * u.dx + (p - line.$1).dy * u.dy) /
                    u.distanceSquared)
                .clamp(0.0, 1.0);
        // End-point proximity cannot establish the root of a cantilever strip.
        if (t <= 1e-6 || t >= 1 - 1e-6) continue;
        final q = line.$1 + u * t;
        if (!SlabBoundaryGeometry.segmentOnSlabs(p, q, floor.slabs, scale)) {
          continue;
        }
        lineDistance = math.min(lineDistance, (p - q).distance / scale);
      }
      final owners = floor.slabs.where(
        (s) =>
            StructuralPolygonDistance.inside(p, s.polygon) ||
            List.generate(
              s.polygon.length,
              (i) =>
                  StructuralPolygonDistance.pointToSegment(
                    p,
                    s.polygon[i],
                    s.polygon[(i + 1) % s.polygon.length],
                  ) <
                  1e-6 * scale,
            ).any((v) => v),
      );
      final h = owners.isEmpty
          ? double.nan
          : owners.map((s) => s.thickness).reduce(math.min);
      boundaries.add(
        BoundarySupportCheck(
          p,
          lineDistance.isFinite ? lineDistance : nearest,
          lineDistance.isFinite,
          h,
        ),
      );
    }
    final seismic = SeismicAnalysisCalculator.analyzeProject(
      assessed,
      cadUnitsPerMeter: scale,
    );
    final rigidity = _rigidity(seismic, floor.id);
    var continuity = 0;
    final levels = [...assessed.storeys]
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    for (var i = 1; i < levels.length; i++) {
      continuity += levels[i].columns
          .where(
            (c) => !ColumnVerticalContinuity.evaluate(
              c,
              levels[i - 1],
              scale,
            ).isContinuous,
          )
          .length;
      continuity += levels[i].shearWalls
          .where(
            (w) => !WallVerticalContinuity.evaluate(
              w,
              levels[i - 1].shearWalls,
              scale,
            ).isContinuous,
          )
          .length;
    }
    var unavailable = rigidity.unavailable;
    // Losing a known root line cannot improve a cantilever score by making
    // the check unavailable. Keep that distinction ahead of numeric penalties.
    unavailable += boundaries.where((b) => b.requiresReview).length;
    final balance = rigidity.penalty;
    if (topology.invalidGeometry || topology.limited || spans.isEmpty) {
      unavailable++;
    }
    final vertical = VerticalCapacityCalculator.analyzeProject(
      assessed,
      cadUnitsPerMeter: scale,
    );
    final columns = vertical.columnChecks.where((c) => c.storeyId == floor.id);
    final columnIssues = columns
        .where(
          (c) =>
              c.axialUtilization > .8 ||
              c.punchingUtilization > .85 ||
              c.punchingRequiresReview,
        )
        .length;
    final area = floor.slabs.fold<double>(
      0,
      (a, s) => a + s.netArea / (scale * scale),
    );
    double excess(double value) =>
        value.isFinite ? math.pow(math.max(0, value - 1), 2).toDouble() : 100;
    var penalty = 5 * topology.unresolvedAreaM2 / math.max(area, 1);
    for (final span in spans) {
      penalty += excess(span.utilization);
    }
    for (final field in topology.fields) {
      penalty += excess(field.utilization);
    }
    for (final p in openings) {
      penalty += p.distanceM.isFinite
          ? math.pow(math.max(0, p.distanceM / p.targetDistanceM - 1), 2) /
                math.max(1, openings.length)
          : 100;
    }
    for (final p in boundaries) {
      if (p.distanceM.isFinite && p.thicknessM > 0) {
        penalty +=
            math.pow(
              math.max(
                0,
                p.distanceM / (p.hasSupportLine ? 7 * p.thicknessM : 2.5) - 1,
              ),
              2,
            ) /
            math.max(1, boundaries.length);
      }
    }
    for (final c in columns) {
      penalty +=
          math.pow(math.max(0, c.axialUtilization / .8 - 1), 2) +
          math.pow(math.max(0, c.punchingUtilization / .85 - 1), 2);
    }
    final volume =
        (floor.columns.fold<double>(
              0,
              (a, c) =>
                  a + VerticalCapacityCalculator.getColumnAreaM2(c, scale),
            ) +
            floor.shearWalls.fold<double>(
              0,
              (a, w) => a + w.length * w.thickness / (scale * scale),
            )) *
        floor.height;
    return SupportLayoutAssessment(
      topology: topology,
      spans: spans,
      openings: List.unmodifiable(openings),
      boundaries: List.unmodifiable(boundaries),
      continuityIssues: continuity,
      unavailableChecks: unavailable,
      columnIssues: columnIssues,
      structuralPenalty: penalty,
      balancePenalty: balance.toDouble(),
      balanceTargetPenalty: rigidity.targetPenalty,
      concreteVolumeM3: volume,
      supportCount: floor.columns.length + floor.shearWalls.length,
      balanceAvailable: rigidity.unavailable == 0,
    );
  }
}

/// Regional footprint distances never borrow a support from another diaphragm.
class SlabSupportRegions {
  final StoreyLevel floor;
  final double scale;
  late final regions = SlabTopologyAnalyzer.analyze(floor.slabs, scale).regions;
  SlabSupportRegions(this.floor, this.scale);
  double distance(Offset p) {
    var result = double.infinity;
    bool owns(StructuralSlab s) =>
        StructuralPolygonDistance.inside(p, s.polygon) ||
        [s.polygon, ...s.openings].any(
          (ring) => List.generate(
            ring.length,
            (i) =>
                StructuralPolygonDistance.pointToSegment(
                  p,
                  ring[i],
                  ring[(i + 1) % ring.length],
                ) <
                1e-7 * scale,
          ).any((v) => v),
        );
    final slabs = <StructuralSlab>[
      for (final region in regions)
        if (region.any((i) => owns(floor.slabs[i])))
          for (final i in region) floor.slabs[i],
    ];
    // Positive-area contact alone isn't a load-transfer proof; it only assigns
    // the support to a slab. A distance segment may not cross a hole or a gap.
    for (final poly in [
      ...floor.columns.map((c) => c.polygonVertices),
      ...floor.shearWalls.map((w) => w.polygonVertices),
    ]) {
      final contact = SlabContactGeometry.measure(poly, slabs, scale);
      if (contact == null || contact.areaM2 <= 1e-10) continue;
      if (StructuralPolygonDistance.inside(p, poly)) return 0;
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i], u = poly[(i + 1) % poly.length] - a;
        if (u.distance == 0) continue;
        final t = (((p - a).dx * u.dx + (p - a).dy * u.dy) / u.distanceSquared)
            .clamp(0.0, 1.0);
        final q = a + u * t;
        if (!SlabBoundaryGeometry.segmentOnSlabs(p, q, floor.slabs, scale)) {
          continue;
        }
        result = math.min(result, (p - q).distance);
      }
    }
    return result;
  }
}
