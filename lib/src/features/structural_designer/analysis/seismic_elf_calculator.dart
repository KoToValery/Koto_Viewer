import 'dart:math' as math;
import 'dart:ui';

import '../models/element_check_models.dart';
import '../models/slab_topology.dart';
import '../models/structural_element.dart';
import 'member_checks.dart';
import 'seismic_analysis_calculator.dart';
import 'seismic_layout_properties.dart';
import 'slab_boundary_geometry.dart';
import 'slab_contact_geometry.dart';
import 'slab_topology_analyzer.dart';

// === SECTION: INDEX ===
// === SECTION: ASSUMPTIONS ===
// === SECTION: RESULT MODELS ===
// === SECTION: POLYGON MOMENTS & RIGIDITY ===
// === SECTION: ELF CALCULATOR ===
//
// Preliminary EC8 §4.3.3.2 Lateral Force Method & rotation-invariant torsion
// screening. Computes principal stiffness axes, shear-corrected wall inertia
// (EC8 §4.2.3.2(9)), floor masses including perimeter facade loads, periods T1,
// base shear F_b, wall shear envelopes (including accidental torsion ±0.05 L),
// and cracked interstorey drifts.

// === SECTION: ASSUMPTIONS ===

class SeismicElfAssumptions {
  /// Cracked bending & shear stiffness factor (EC8 §4.3.1(7)).
  static const double crackedStiffnessFactor = 0.50;

  /// Poisson's ratio for concrete (G = E / (2 (1 + nu))).
  static const double concretePoisson = 0.20;

  /// Shear area factor kappa for rectangular walls (5/6).
  static const double wallShearAreaFactor = 5.0 / 6.0;

  /// Shear-to-flexure factor for cantilever walls: phi = 0.75 * (L/H)^2.
  static const double wallShearFlexureCoeff = 0.75;

  /// Accidental eccentricity fraction of perpendicular plan dimension (EC8 §4.3.2).
  static const double accidentalEccFraction = 0.05;

  /// Orthogonal directional combination factor (EC8 §4.3.3.5.2: 1.0 + 0.3).
  static const double directionalFactor = 0.30;

  /// DCM shear magnification factor for ductile walls (EC8 §5.4.2.4(7)).
  static const double dcmShearMagnification = 1.50;

  /// Assumed practical horizontal web reinforcement ratio rho_h for V_Rd,s.
  static const double wallHorizontalSteelRatio = 0.004;

  /// Design yield strength of web shear steel f_yd (MPa, B500B).
  static const double steelYieldMpa = 500.0 / 1.15;

  /// Effective shear lever arm z / l_w for reinforced concrete walls.
  static const double wallLeverArmRatio = 0.80;

  /// Joint flexibility factor for pure frame interstorey drift estimate.
  static const double frameJointFlexibility = 2.0;

  /// Concrete unit weight (kN/m³).
  static const double concreteUnitWeight = 25.0;
}

// === SECTION: RESULT MODELS ===

/// Applicability issue why the simplified lateral force method may not suffice.
enum SeismicApplicabilityIssue {
  notConfigured,
  periodExceedsLimit,
  torsionallyFlexible,
  highEccentricity,
  mixedDualSystem,
  irregularDiaphragm,
  noLateralSupports,
}

/// Rotation-invariant torsional assessment for one storey in its principal axes.
class StoreyTorsionResult {
  final String storeyId;
  final bool isEvaluated;

  /// Principal axis 1 angle (radians) and plan extents along principal axes (m).
  final double principalAngleRad;
  final double planLength1M;
  final double planLength2M;

  /// Center of Mass and Center of Rigidity in CAD coordinates.
  final Offset? cmCad;
  final Offset? crCad;

  /// Eccentricities along principal axes (m).
  final double e1M;
  final double e2M;

  /// Torsional radii r1 = sqrt(K_T / K2), r2 = sqrt(K_T / K1) (m).
  final double r1M;
  final double r2M;

  /// Mass radius of gyration l_s including openings & perimeter facades (m).
  final double lsM;

  /// max(e1 / (0.3 r1), e2 / (0.3 r2)): <= 1.0 satisfies e0 <= 0.30 r.
  final double eccentricityRatio;

  /// max(l_s / r1, l_s / r2): <= 1.0 satisfies r >= l_s (torsionally stiff).
  final double flexibilityRatio;

  /// Share of walls in total translational stiffness [0..1].
  final double wallStiffnessShare;

  const StoreyTorsionResult({
    required this.storeyId,
    required this.isEvaluated,
    this.principalAngleRad = 0,
    this.planLength1M = 0,
    this.planLength2M = 0,
    this.cmCad,
    this.crCad,
    this.e1M = 0,
    this.e2M = 0,
    this.r1M = 0,
    this.r2M = 0,
    this.lsM = 0,
    this.eccentricityRatio = double.nan,
    this.flexibilityRatio = double.nan,
    this.wallStiffnessShare = 0,
  });

  bool get isTorsionallyFlexible =>
      isEvaluated && flexibilityRatio.isFinite && flexibilityRatio > 1.0;

  bool get hasHighEccentricity =>
      isEvaluated && eccentricityRatio.isFinite && eccentricityRatio > 1.0;

  /// Governing torsion ratio (<= 1.0 within preliminary EC8 §4.2.3.2 bounds).
  double get governingRatio {
    if (!isEvaluated) return double.nan;
    if (!eccentricityRatio.isFinite) return flexibilityRatio;
    if (!flexibilityRatio.isFinite) return eccentricityRatio;
    return math.max(eccentricityRatio, flexibilityRatio);
  }

  ElementCheck get check => ElementCheck(
    CheckKind.storeyTorsion,
    governingRatio,
    1.0,
  );
}

/// Seismic results for a single storey.
class StoreySeismicElfResult {
  final String storeyId;
  final double elevationM;
  final double heightM;

  /// Seismic mass at this level (tonnes).
  final double massTonnes;

  /// Lateral forces & cumulative shears in the two principal directions (kN).
  final double force1Kn;
  final double force2Kn;
  final double shear1Kn;
  final double shear2Kn;

  /// Design interstorey drift d_r * nu (mm) vs EC8 §4.4.3.2 limit alpha * h (mm).
  final ElementCheck driftCheck;
  final StoreyTorsionResult torsion;

  const StoreySeismicElfResult({
    required this.storeyId,
    required this.elevationM,
    required this.heightM,
    required this.massTonnes,
    required this.force1Kn,
    required this.force2Kn,
    required this.shear1Kn,
    required this.shear2Kn,
    required this.driftCheck,
    required this.torsion,
  });
}

/// Full building lateral force seismic screening report.
class SeismicElfReport {
  final bool isConfigured;
  final SeismicSystemKind resolvedSystem;
  final double effectiveQ;
  final double totalHeightM;
  final double totalMassTonnes;

  /// Fundamental periods T1 in the two principal building directions (s).
  final double period1S;
  final double period2S;

  /// Base shears F_b in the two principal directions (kN).
  final double baseShear1Kn;
  final double baseShear2Kn;

  /// Per-storey seismic & torsion results (ordered bottom to top).
  final List<StoreySeismicElfResult> storeys;

  /// Per-wall seismic shear check keyed by `storeyId/wallId`.
  final Map<String, ElementCheck> wallShearChecks;

  /// Per-storey drift check keyed by `storeyId`.
  final Map<String, ElementCheck> storeyDriftChecks;

  /// Applicability warnings (e.g. needs 3D modal analysis).
  final Set<SeismicApplicabilityIssue> issues;

  const SeismicElfReport({
    required this.isConfigured,
    required this.resolvedSystem,
    required this.effectiveQ,
    required this.totalHeightM,
    required this.totalMassTonnes,
    required this.period1S,
    required this.period2S,
    required this.baseShear1Kn,
    required this.baseShear2Kn,
    required this.storeys,
    required this.wallShearChecks,
    required this.storeyDriftChecks,
    required this.issues,
  });

  static const empty = SeismicElfReport(
    isConfigured: false,
    resolvedSystem: SeismicSystemKind.wall,
    effectiveQ: 3.0,
    totalHeightM: 0,
    totalMassTonnes: 0,
    period1S: double.nan,
    period2S: double.nan,
    baseShear1Kn: double.nan,
    baseShear2Kn: double.nan,
    storeys: [],
    wallShearChecks: {},
    storeyDriftChecks: {},
    issues: {SeismicApplicabilityIssue.notConfigured},
  );

  bool get requires3dAnalysis => issues.any(
    (i) => i != SeismicApplicabilityIssue.notConfigured,
  );

  StoreySeismicElfResult? storey(String storeyId) {
    for (final s in storeys) {
      if (s.storeyId == storeyId) return s;
    }
    return null;
  }
}

// === SECTION: POLYGON MOMENTS & RIGIDITY ===

class _SectionMoments {
  final double area; // m²
  final Offset centroid; // metres relative to origin
  /// Second moments about centroid (m⁴):
  /// ix = integral (x - cx)^2 dA (resists bending along X),
  /// iy = integral (y - cy)^2 dA (resists bending along Y),
  /// ixy = integral (x - cx)(y - cy) dA.
  final double ix, iy, ixy;

  const _SectionMoments(this.area, this.centroid, this.ix, this.iy, this.ixy);

  /// Exact Green's theorem polygon moments about centroid in metres.
  static _SectionMoments fromPolygon(
    List<Offset> ring,
    Offset originCad,
    double scale,
  ) {
    if (ring.length < 3) {
      return const _SectionMoments(0, Offset.zero, 0, 0, 0);
    }
    double a2 = 0, mx = 0, my = 0, sxx = 0, syy = 0, sxy = 0;
    for (var i = 0; i < ring.length; i++) {
      final p = (ring[i] - originCad) / scale;
      final q = (ring[(i + 1) % ring.length] - originCad) / scale;
      final cross = p.dx * q.dy - q.dx * p.dy;
      a2 += cross;
      mx += (p.dx + q.dx) * cross;
      my += (p.dy + q.dy) * cross;
      sxx += (p.dx * p.dx + p.dx * q.dx + q.dx * q.dx) * cross;
      syy += (p.dy * p.dy + p.dy * q.dy + q.dy * q.dy) * cross;
      sxy += (2 * p.dx * p.dy + p.dx * q.dy + q.dx * p.dy + 2 * q.dx * q.dy) *
          cross;
    }
    final sign = a2 < 0 ? -1.0 : 1.0;
    final area = sign * a2 / 2.0;
    if (area <= 1e-12) {
      return const _SectionMoments(0, Offset.zero, 0, 0, 0);
    }
    final cx = sign * mx / (6.0 * area);
    final cy = sign * my / (6.0 * area);
    final ix = math.max(0.0, sign * sxx / 12.0 - area * cx * cx);
    final iy = math.max(0.0, sign * syy / 12.0 - area * cy * cy);
    final ixy = sign * sxy / 24.0 - area * cx * cy;
    return _SectionMoments(area, Offset(cx, cy), ix, iy, ixy);
  }
}

class _SupportStiffness {
  final String id;
  final bool isWall;
  final Offset positionM; // metres in CAD frame
  final double kx, ky, kxy; // effective I_eq tensor (m⁴)
  final double strongIeq; // m⁴ along strong axis (for walls)
  final Offset axisUnit; // unit vector along strong axis (for walls)
  final double lengthM;
  final double thicknessM;

  const _SupportStiffness({
    required this.id,
    required this.isWall,
    required this.positionM,
    required this.kx,
    required this.ky,
    required this.kxy,
    required this.strongIeq,
    required this.axisUnit,
    required this.lengthM,
    required this.thicknessM,
  });
}

// === SECTION: ELF CALCULATOR ===

class SeismicElfCalculator {
  const SeismicElfCalculator._();

  static SeismicElfReport analyze(
    StructuralProject project, {
    required double cadUnitsPerMeter,
  }) {
    final scale = cadUnitsPerMeter;
    if (!scale.isFinite || scale <= 0) return SeismicElfReport.empty;

    final storeys = project.ceilingStoreys
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    if (storeys.isEmpty) return SeismicElfReport.empty;

    final params = project.designParameters ?? const ProjectDesignParameters();
    final material = CheckMaterial.of(project);
    final issues = <SeismicApplicabilityIssue>{};
    if (!params.isSeismicConfigured) {
      issues.add(SeismicApplicabilityIssue.notConfigured);
    }

    // Total building height H above base elevation.
    final baseElev = storeys.first.elevation;
    final heights = <double>[];
    final topElevations = <double>[];
    var runningH = 0.0;
    for (var i = 0; i < storeys.length; i++) {
      final h = storeys[i].height.isFinite && storeys[i].height > 0.5
          ? storeys[i].height
          : 2.8;
      heights.add(h);
      runningH += h;
      topElevations.add(storeys[i].elevation - baseElev + h);
    }
    final totalH = math.max(
      runningH,
      topElevations.isNotEmpty ? topElevations.last : 2.8,
    );

    // Phase 1: Per-storey masses, connected supports, principal axes & torsion.
    final storeyData = <_StoreySeismicData>[];
    var totalWallShareWeighted = 0.0;
    var totalStiffnessWeight = 0.0;

    for (var i = 0; i < storeys.length; i++) {
      final storey = storeys[i];
      final h = heights[i];
      final isRoof = i == storeys.length - 1;
      final data = _analyzeStoreyGeometry(
        project: project,
        storey: storey,
        storeyHeightM: h,
        buildingHeightM: totalH,
        scale: scale,
        withFacade: !isRoof,
      );
      storeyData.add(data);
      if (data.hasMultipleRegions) {
        issues.add(SeismicApplicabilityIssue.irregularDiaphragm);
      }
      if (data.torsion.isEvaluated) {
        final w = data.k1 + data.k2;
        totalWallShareWeighted += data.torsion.wallStiffnessShare * w;
        totalStiffnessWeight += w;
        if (data.torsion.isTorsionallyFlexible) {
          issues.add(SeismicApplicabilityIssue.torsionallyFlexible);
        }
        if (data.torsion.hasHighEccentricity) {
          issues.add(SeismicApplicabilityIssue.highEccentricity);
        }
      }
    }

    // Resolve structural system: explicit override or inferred from wall share.
    final avgWallShare = totalStiffnessWeight > 0
        ? totalWallShareWeighted / totalStiffnessWeight
        : 0.0;
    final inferredSystem = avgWallShare >= 0.65
        ? SeismicSystemKind.wall
        : avgWallShare <= 0.15
            ? SeismicSystemKind.frame
            : SeismicSystemKind.dual;
    final resolvedSystem = params.systemOverride ?? inferredSystem;
    if (resolvedSystem == SeismicSystemKind.dual ||
        (avgWallShare > 0.15 && avgWallShare < 0.65)) {
      issues.add(SeismicApplicabilityIssue.mixedDualSystem);
    }
    final effectiveQ = params.effectiveQ(resolvedSystem);

    final totalMassT = storeyData.fold<double>(0, (s, d) => s + d.massTonnes);
    if (totalStiffnessWeight <= 0) {
      issues.add(SeismicApplicabilityIssue.noLateralSupports);
    }

    // Determine building principal orientation from the ground (or first valid)
    // storey so global periods and base shears are strictly rotation-invariant.
    final baseData = storeyData.firstWhere(
      (d) => d.torsion.isEvaluated,
      orElse: () => storeyData.first,
    );
    final refAngle = baseData.torsion.principalAngleRad;
    final u1 = Offset(math.cos(refAngle), math.sin(refAngle));
    final u2 = Offset(-math.sin(refAngle), math.cos(refAngle));

    // Fundamental periods T1 in principal directions 1 and 2 (EC8 §4.3.3.2.2).
    final (t1, t2) = _estimatePeriods(
      baseData: baseData,
      u1: u1,
      u2: u2,
      totalH: totalH,
      system: resolvedSystem,
    );

    // Base shear F_b and storey forces when a_gR is configured.
    double fb1 = double.nan, fb2 = double.nan;
    final f1List = List<double>.filled(storeys.length, double.nan);
    final f2List = List<double>.filled(storeys.length, double.nan);
    final v1List = List<double>.filled(storeys.length, double.nan);
    final v2List = List<double>.filled(storeys.length, double.nan);

    if (params.isSeismicConfigured && totalMassT > 0) {
      final spec = params.spectrum;
      final tLimit = math.min(4.0 * spec.tc, 2.0);
      if ((t1.isFinite && t1 > tLimit) || (t2.isFinite && t2 > tLimit)) {
        issues.add(SeismicApplicabilityIssue.periodExceedsLimit);
      }

      double baseShear(double period) {
        final sd = params.designSpectrumMs2(period, resolvedSystem);
        final lambda =
            storeys.length > 2 && period <= 2.0 * spec.tc ? 0.85 : 1.0;
        // mass (t) * acceleration (m/s²) = kN!
        return sd * totalMassT * lambda;
      }

      fb1 = baseShear(t1);
      fb2 = baseShear(t2);

      var sumZm = 0.0;
      for (var i = 0; i < storeys.length; i++) {
        sumZm += topElevations[i] * storeyData[i].massTonnes;
      }
      if (sumZm > 0) {
        for (var i = 0; i < storeys.length; i++) {
          final w = topElevations[i] * storeyData[i].massTonnes / sumZm;
          f1List[i] = fb1 * w;
          f2List[i] = fb2 * w;
        }
        var cum1 = 0.0, cum2 = 0.0;
        for (var i = storeys.length - 1; i >= 0; i--) {
          cum1 += f1List[i];
          cum2 += f2List[i];
          v1List[i] = cum1;
          v2List[i] = cum2;
        }
      }
    }

    // Cracked interstorey drift integration bottom-to-top in both directions.
    final driftChecks = <String, ElementCheck>{};
    final d1 = _computeInterstoreyDrifts(
      storeyData: storeyData,
      heights: heights,
      topElevations: topElevations,
      forces: f1List,
      shears: v1List,
      direction: u1,
      material: material,
      system: resolvedSystem,
      q: effectiveQ,
    );
    final d2 = _computeInterstoreyDrifts(
      storeyData: storeyData,
      heights: heights,
      topElevations: topElevations,
      forces: f2List,
      shears: v2List,
      direction: u2,
      material: material,
      system: resolvedSystem,
      q: effectiveQ,
    );

    final nu = params.importanceClass.driftNu;
    final alpha = params.driftCategory.alphaLimit;
    final wallShearChecks = <String, ElementCheck>{};
    final storeyResults = <StoreySeismicElfResult>[];

    for (var i = 0; i < storeys.length; i++) {
      final data = storeyData[i];
      final storey = storeys[i];
      final h = heights[i];
      final limitMm = alpha * h * 1000.0;
      final worstDriftMm = (d1[i].isFinite && d2[i].isFinite)
          ? math.max(d1[i], d2[i]) * nu * 1000.0
          : double.nan;
      final driftCheck = ElementCheck(
        CheckKind.storeyDrift,
        worstDriftMm,
        limitMm,
      );
      driftChecks[storey.id] = driftCheck;

      // Distribute storey shear + torsion to every connected shear wall.
      if (params.isSeismicConfigured &&
          data.torsion.isEvaluated &&
          v1List[i].isFinite &&
          v2List[i].isFinite) {
        _evaluateStoreyWallShears(
          storeyId: storey.id,
          data: data,
          v1Kn: v1List[i],
          v2Kn: v2List[i],
          material: material,
          q: effectiveQ,
          outChecks: wallShearChecks,
        );
      }

      storeyResults.add(
        StoreySeismicElfResult(
          storeyId: storey.id,
          elevationM: storey.elevation,
          heightM: h,
          massTonnes: data.massTonnes,
          force1Kn: f1List[i],
          force2Kn: f2List[i],
          shear1Kn: v1List[i],
          shear2Kn: v2List[i],
          driftCheck: driftCheck,
          torsion: data.torsion,
        ),
      );
    }

    return SeismicElfReport(
      isConfigured: params.isSeismicConfigured,
      resolvedSystem: resolvedSystem,
      effectiveQ: effectiveQ,
      totalHeightM: totalH,
      totalMassTonnes: totalMassT,
      period1S: t1,
      period2S: t2,
      baseShear1Kn: fb1,
      baseShear2Kn: fb2,
      storeys: storeyResults,
      wallShearChecks: wallShearChecks,
      storeyDriftChecks: driftChecks,
      issues: Set.unmodifiable(issues),
    );
  }

  static _StoreySeismicData _analyzeStoreyGeometry({
    required StructuralProject project,
    required StoreyLevel storey,
    required double storeyHeightM,
    required double buildingHeightM,
    required double scale,
    required bool withFacade,
  }) {
    final topology = SlabTopologyAnalyzer.analyze(storey.slabs, scale);
    final hasMultipleRegions = topology.issue == SlabTopologyIssue.separateRegions;

    // Connected elements (if slabs exist, filter by contact; otherwise include
    // nothing for lateral diaphragm).
    final hasSlabs = storey.slabs.isNotEmpty;
    final connectedCols = <StructuralColumn>[];
    final connectedWalls = <StructuralShearWall>[];
    if (hasSlabs) {
      for (final col in storey.columns) {
        final contact = SlabContactGeometry.columnContact(col, storey.slabs, scale);
        if (contact != null && contact.areaM2 > 1e-10) {
          connectedCols.add(col);
        }
      }
      for (final wall in storey.shearWalls) {
        final conn = SeismicAnalysisCalculator.getWallDiaphragmConnection(
          wall,
          storey.slabs,
          scale,
        );
        if (conn.isConnected && conn.effectiveLengthM > 0.05) {
          connectedWalls.add(wall);
        }
      }
    }

    // 1. Mass & CM (in kN weight, then divided by g = 9.81 -> tonnes).
    // Includes slabs (net of openings), connected columns, connected walls,
    // AND perimeter facade walls (facadeWallLoad along exposed outer edges).
    var totalWeightKn = 0.0;
    var sumWx = 0.0, sumWy = 0.0;

    for (final slab in storey.slabs) {
      if (slab.polygon.length < 3) continue;
      final load = slab.effectiveSeismicLoad(project);
      if (!load.isValid || !slab.thickness.isFinite || slab.thickness <= 0) {
        continue;
      }
      final wKnM2 = load.weightKnM2(slab.thickness);
      final origin = slab.polygon.first;
      final gross = PolygonMassIntegrals.integrate(slab.polygon, origin, scale);
      var area = gross.area, mx = gross.firstX, my = gross.firstY;
      for (final op in slab.openings) {
        if (op.length < 3) continue;
        final hole = PolygonMassIntegrals.integrate(op, origin, scale);
        area -= hole.area;
        mx -= hole.firstX;
        my -= hole.firstY;
      }
      if (area <= 1e-9) continue;
      final cCad = origin + Offset(mx / area, my / area) * scale;
      final weight = area * wKnM2;
      totalWeightKn += weight;
      sumWx += weight * cCad.dx;
      sumWy += weight * cCad.dy;
    }

    for (final col in connectedCols) {
      final m = col.shape == ColumnShape.circular
          ? _SectionMoments(
              math.pi * math.pow(col.width / scale / 2, 2),
              Offset.zero,
              0,
              0,
              0,
            )
          : _SectionMoments.fromPolygon(col.polygonVertices, col.center, scale);
      final cCad = col.center + m.centroid * scale;
      final w = m.area * storeyHeightM * SeismicElfAssumptions.concreteUnitWeight;
      totalWeightKn += w;
      sumWx += w * cCad.dx;
      sumWy += w * cCad.dy;
    }

    for (final wall in connectedWalls) {
      final lM = wall.length / scale, tM = wall.thickness / scale;
      final w = lM * tM * storeyHeightM * SeismicElfAssumptions.concreteUnitWeight;
      final cCad = wall.center;
      totalWeightKn += w;
      sumWx += w * cCad.dx;
      sumWy += w * cCad.dy;
    }

    final facadeEdges = (withFacade &&
            project.facadeWallLoad.isFinite &&
            project.facadeWallLoad > 0 &&
            hasSlabs)
        ? SlabBoundaryGeometry.exposedEdges(storey.slabs, scale)
            .where((e) => !e.opening)
            .toList()
        : const <SlabBoundaryEdge>[];
    for (final edge in facadeEdges) {
      final lenM = (edge.b - edge.a).distance / scale;
      if (lenM <= 1e-6) continue;
      final w = lenM * project.facadeWallLoad;
      final mid = (edge.a + edge.b) / 2.0;
      totalWeightKn += w;
      sumWx += w * mid.dx;
      sumWy += w * mid.dy;
    }

    final cmCad = totalWeightKn > 0
        ? Offset(sumWx / totalWeightKn, sumWy / totalWeightKn)
        : null;

    // 2. Polar weight integral about CM -> radius of gyration l_s.
    var polarWeight = 0.0;
    if (cmCad != null) {
      for (final slab in storey.slabs) {
        if (slab.polygon.length < 3) continue;
        final load = slab.effectiveSeismicLoad(project);
        if (!load.isValid || !slab.thickness.isFinite || slab.thickness <= 0) {
          continue;
        }
        var polar = PolygonMassIntegrals.integrate(slab.polygon, cmCad, scale).polar;
        for (final op in slab.openings) {
          if (op.length < 3) continue;
          polar -= PolygonMassIntegrals.integrate(op, cmCad, scale).polar;
        }
        polarWeight += math.max(0.0, polar) * load.weightKnM2(slab.thickness);
      }
      for (final col in connectedCols) {
        if (col.shape == ColumnShape.circular) {
          final r = col.width / scale / 2.0;
          final a = math.pi * r * r;
          final d2 = ((col.center - cmCad) / scale).distanceSquared;
          polarWeight += SeismicElfAssumptions.concreteUnitWeight *
              storeyHeightM * a * (r * r / 2.0 + d2);
        } else {
          polarWeight += SeismicElfAssumptions.concreteUnitWeight *
              storeyHeightM *
              PolygonMassIntegrals.integrate(col.polygonVertices, cmCad, scale).polar;
        }
      }
      for (final wall in connectedWalls) {
        final lM = wall.length / scale, tM = wall.thickness / scale;
        final d2 = ((wall.center - cmCad) / scale).distanceSquared;
        polarWeight += SeismicElfAssumptions.concreteUnitWeight *
            storeyHeightM * lM * tM * ((lM * lM + tM * tM) / 12.0 + d2);
      }
      for (final edge in facadeEdges) {
        final lenM = (edge.b - edge.a).distance / scale;
        if (lenM <= 1e-6) continue;
        final w = lenM * project.facadeWallLoad;
        final mid = (edge.a + edge.b) / 2.0;
        final d2 = ((mid - cmCad) / scale).distanceSquared;
        polarWeight += w * (lenM * lenM / 12.0 + d2);
      }
    }
    final lsM = totalWeightKn > 0
        ? math.sqrt(math.max(0.0, polarWeight / totalWeightKn))
        : 0.0;

    // 3. Lateral support stiffnesses (including shear deformation for walls and
    // full polygon moments for L-columns).
    final supports = <_SupportStiffness>[];
    var wallStiffnessSum = 0.0;
    var totalStiffnessSum = 0.0;

    for (final wall in connectedWalls) {
      final lM = wall.length / scale, tM = wall.thickness / scale;
      if (lM <= 0.05 || tM <= 0.05) continue;
      final iStrongRaw = tM * math.pow(lM, 3) / 12.0;
      final phi = SeismicElfAssumptions.wallShearFlexureCoeff *
          math.pow(lM / math.max(buildingHeightM, 2.4), 2);
      final iStrong = iStrongRaw / (1.0 + phi);
      final iWeak = lM * math.pow(tM, 3) / 12.0;
      final angle = wall.angleRad;
      final c = math.cos(angle), s = math.sin(angle);
      final kx = iStrong * c * c + iWeak * s * s;
      final ky = iStrong * s * s + iWeak * c * c;
      final kxy = (iStrong - iWeak) * s * c;
      supports.add(
        _SupportStiffness(
          id: wall.id,
          isWall: true,
          positionM: wall.center / scale,
          kx: kx,
          ky: ky,
          kxy: kxy,
          strongIeq: iStrong,
          axisUnit: Offset(c, s),
          lengthM: lM,
          thicknessM: tM,
        ),
      );
      wallStiffnessSum += kx + ky;
      totalStiffnessSum += kx + ky;
    }

    for (final col in connectedCols) {
      double ix, iy, ixy;
      Offset posM;
      if (col.shape == ColumnShape.circular) {
        final d = col.width / scale;
        ix = math.pi * math.pow(d, 4) / 64.0;
        iy = ix;
        ixy = 0.0;
        posM = col.center / scale;
      } else {
        final m = _SectionMoments.fromPolygon(col.polygonVertices, col.center, scale);
        ix = m.ix;
        iy = m.iy;
        ixy = m.ixy;
        posM = (col.center + m.centroid * scale) / scale;
      }
      if (ix <= 1e-12 && iy <= 1e-12) continue;
      supports.add(
        _SupportStiffness(
          id: col.id,
          isWall: false,
          positionM: posM,
          kx: ix,
          ky: iy,
          kxy: ixy,
          strongIeq: math.max(ix, iy),
          axisUnit: const Offset(1, 0),
          lengthM: math.max(col.width, col.height) / scale,
          thicknessM: math.min(col.width, col.height) / scale,
        ),
      );
      totalStiffnessSum += ix + iy;
    }

    // 4. Center of Rigidity & Principal Stiffness Axes (rotation-invariant).
    final layoutSupports = [
      for (final s in supports) LayoutSupport(s.positionM, s.kx, s.ky, s.kxy),
    ];
    final rigidity = LayoutRigidity.calculate(layoutSupports);

    if (rigidity == null || cmCad == null) {
      return _StoreySeismicData(
        storeyId: storey.id,
        massTonnes: totalWeightKn / ProjectDesignParameters.gravityMs2,
        supports: supports,
        hasMultipleRegions: hasMultipleRegions,
        k1: 0,
        k2: 0,
        kt: 0,
        torsion: StoreyTorsionResult(
          storeyId: storey.id,
          isEvaluated: false,
          cmCad: cmCad,
          lsM: lsM,
        ),
      );
    }

    // Principal axes of 2x2 translational matrix [kx, kxy; kxy, ky].
    final sumKx = rigidity.kx;
    final sumKy = rigidity.ky;
    var sumKxy = 0.0;
    for (final s in supports) {
      sumKxy += s.kxy;
    }
    final avg = (sumKx + sumKy) / 2.0;
    final halfDiff = (sumKx - sumKy) / 2.0;
    final rad = math.sqrt(halfDiff * halfDiff + sumKxy * sumKxy);
    final k1 = avg + rad;
    final k2 = math.max(1e-12, avg - rad);
    // When stiffness is isotropic (K1 == K2), align with the longest slab edge
    // so plan dimensions and accidental eccentricity stay rotation-invariant.
    double alpha1;
    if (rad > 1e-9 * math.max(1e-12, avg)) {
      alpha1 = 0.5 * math.atan2(2.0 * sumKxy, sumKx - sumKy);
    } else {
      alpha1 = _longestSlabEdgeAngle(storey.slabs);
    }
    final u1 = Offset(math.cos(alpha1), math.sin(alpha1));
    final u2 = Offset(-math.sin(alpha1), math.cos(alpha1));

    // Plan extents along principal axes (rotation-invariant!).
    var min1 = double.infinity, max1 = -double.infinity;
    var min2 = double.infinity, max2 = -double.infinity;
    for (final slab in storey.slabs) {
      for (final p in slab.polygon) {
        final pm = p / scale;
        final p1 = pm.dx * u1.dx + pm.dy * u1.dy;
        final p2 = pm.dx * u2.dx + pm.dy * u2.dy;
        if (p1 < min1) min1 = p1;
        if (p1 > max1) max1 = p1;
        if (p2 < min2) min2 = p2;
        if (p2 > max2) max2 = p2;
      }
    }
    final plan1 = max1 > min1 ? math.max(1.0, max1 - min1) : 1.0;
    final plan2 = max2 > min2 ? math.max(1.0, max2 - min2) : 1.0;

    final crCad = rigidity.center * scale;
    final eVecM = (cmCad - crCad) / scale;
    final e1M = (eVecM.dx * u1.dx + eVecM.dy * u1.dy).abs();
    final e2M = (eVecM.dx * u2.dx + eVecM.dy * u2.dy).abs();
    final kt = rigidity.torsion;
    final r1M = k2 > 0 ? math.sqrt(kt / k2) : 0.0;
    final r2M = k1 > 0 ? math.sqrt(kt / k1) : 0.0;

    final eccRatio1 = r1M > 1e-6 ? e1M / (0.30 * r1M) : double.infinity;
    final eccRatio2 = r2M > 1e-6 ? e2M / (0.30 * r2M) : double.infinity;
    final flexRatio1 = r1M > 1e-6 ? lsM / r1M : double.infinity;
    final flexRatio2 = r2M > 1e-6 ? lsM / r2M : double.infinity;

    final wallShare = totalStiffnessSum > 0
        ? (wallStiffnessSum / totalStiffnessSum).clamp(0.0, 1.0)
        : 0.0;

    return _StoreySeismicData(
      storeyId: storey.id,
      massTonnes: totalWeightKn / ProjectDesignParameters.gravityMs2,
      supports: supports,
      hasMultipleRegions: hasMultipleRegions,
      k1: k1,
      k2: k2,
      kt: kt,
      crPosM: rigidity.center,
      cmPosM: cmCad / scale,
      torsion: StoreyTorsionResult(
        storeyId: storey.id,
        isEvaluated: true,
        principalAngleRad: alpha1,
        planLength1M: plan1,
        planLength2M: plan2,
        cmCad: cmCad,
        crCad: crCad,
        e1M: e1M,
        e2M: e2M,
        r1M: r1M,
        r2M: r2M,
        lsM: lsM,
        eccentricityRatio: math.max(eccRatio1, eccRatio2),
        flexibilityRatio: math.max(flexRatio1, flexRatio2),
        wallStiffnessShare: wallShare,
      ),
    );
  }

  static double _longestSlabEdgeAngle(List<StructuralSlab> slabs) {
    var bestLen = -1.0;
    var angle = 0.0;
    for (final slab in slabs) {
      final poly = slab.polygon;
      for (var i = 0; i < poly.length; i++) {
        final d = poly[(i + 1) % poly.length] - poly[i];
        if (d.distance > bestLen) {
          bestLen = d.distance;
          angle = math.atan2(d.dy, d.dx);
        }
      }
    }
    return angle;
  }

  /// EC8 §4.3.3.2.2 fundamental period estimate in the two principal directions.
  static (double, double) _estimatePeriods({
    required _StoreySeismicData baseData,
    required Offset u1,
    required Offset u2,
    required double totalH,
    required SeismicSystemKind system,
  }) {
    final hPow = math.pow(math.max(totalH, 2.0), 0.75).toDouble();
    if (system == SeismicSystemKind.frame) {
      final t = 0.075 * hPow;
      return (t, t);
    }

    double periodAlong(Offset dir) {
      // EC8 eq. (4.7) & (4.8): C_t = 0.075 / sqrt(A_c),
      // A_c = sum A_i * (0.2 + (l_wi / H)^2), with l_wi / H <= 0.9.
      var ac = 0.0;
      for (final s in baseData.supports) {
        if (!s.isWall) continue;
        final proj = (s.axisUnit.dx * dir.dx + s.axisUnit.dy * dir.dy).abs();
        final proj2 = proj * proj;
        if (proj2 < 1e-4) continue;
        final area = s.lengthM * s.thicknessM * proj2;
        final ratio = math.min(0.9, s.lengthM / math.max(totalH, 2.4));
        ac += area * (0.2 + ratio * ratio);
      }
      if (ac <= 1e-4) return system.defaultCt * hPow;
      final ct = (0.075 / math.sqrt(ac)).clamp(0.03, 0.085);
      return ct * hPow;
    }

    return (periodAlong(u1), periodAlong(u2));
  }

  /// Cracked interstorey drifts d_r (m) along [direction] for every storey.
  static List<double> _computeInterstoreyDrifts({
    required List<_StoreySeismicData> storeyData,
    required List<double> heights,
    required List<double> topElevations,
    required List<double> forces,
    required List<double> shears,
    required Offset direction,
    required CheckMaterial material,
    required SeismicSystemKind system,
    required double q,
  }) {
    final n = storeyData.length;
    final out = List<double>.filled(n, double.nan);
    if (n == 0 || !shears.first.isFinite) return out;

    final eEffKpa = material.elasticModulusMpa *
        1000.0 *
        SeismicElfAssumptions.crackedStiffnessFactor;
    final gEffKpa = eEffKpa /
        (2.0 * (1.0 + SeismicElfAssumptions.concretePoisson));

    var thetaBelow = 0.0;
    for (var k = 0; k < n; k++) {
      final data = storeyData[k];
      final h = heights[k];
      final v = shears[k];
      if (!v.isFinite || !data.torsion.isEvaluated) continue;

      // Project support inertia & shear area onto [direction].
      var iDir = 0.0;
      var avWall = 0.0;
      var iColDir = 0.0;
      for (final s in data.supports) {
        final kProj = s.kx * direction.dx * direction.dx +
            2.0 * s.kxy * direction.dx * direction.dy +
            s.ky * direction.dy * direction.dy;
        iDir += kProj;
        if (s.isWall) {
          final proj = (s.axisUnit.dx * direction.dx + s.axisUnit.dy * direction.dy).abs();
          avWall += SeismicElfAssumptions.wallShearAreaFactor *
              s.lengthM * s.thicknessM * proj * proj;
        } else {
          iColDir += kProj;
        }
      }
      if (iDir <= 1e-10) continue;

      double de;
      if (system == SeismicSystemKind.frame || avWall <= 1e-6) {
        // Double-curvature frame interstorey drift with joint flexibility.
        final iFrame = math.max(iColDir, iDir);
        de = SeismicElfAssumptions.frameJointFlexibility *
            v * math.pow(h, 3) / (12.0 * eEffKpa * iFrame);
      } else {
        // Exact Timoshenko cantilever integration over storey k.
        var mTop = 0.0;
        for (var j = k + 1; j < n; j++) {
          if (forces[j].isFinite) {
            mTop += forces[j] * (topElevations[j] - topElevations[k]);
          }
        }
        final mBot = mTop + v * h;
        final ei = eEffKpa * iDir;
        final flexDrift = thetaBelow * h +
            (h * h / (6.0 * ei)) * (2.0 * mBot + mTop);
        final shearDrift = v * h / (gEffKpa * avWall);
        thetaBelow += (mTop + mBot) * h / (2.0 * ei);
        de = flexDrift + shearDrift;
      }
      out[k] = math.max(0.0, q * de);
    }
    return out;
  }

  /// Distributes storey shears + real & accidental torsion to shear walls.
  static void _evaluateStoreyWallShears({
    required String storeyId,
    required _StoreySeismicData data,
    required double v1Kn,
    required double v2Kn,
    required CheckMaterial material,
    required double q,
    required Map<String, ElementCheck> outChecks,
  }) {
    final t = data.torsion;
    if (!t.isEvaluated || data.crPosM == null || data.cmPosM == null) return;
    final crPosM = data.crPosM!;
    final eVecM = data.cmPosM! - crPosM;
    final a = t.principalAngleRad;
    final u1 = Offset(math.cos(a), math.sin(a));
    final u2 = Offset(-math.sin(a), math.cos(a));

    final signedE1 = eVecM.dx * u1.dx + eVecM.dy * u1.dy;
    final signedE2 = eVecM.dx * u2.dx + eVecM.dy * u2.dy;

    final ea1 = SeismicElfAssumptions.accidentalEccFraction * t.planLength1M;
    final ea2 = SeismicElfAssumptions.accidentalEccFraction * t.planLength2M;

    // DCM shear magnification (1.5 for q > 1.5, 1.0 for DCL).
    final shearMag = q > 1.5 ? SeismicElfAssumptions.dcmShearMagnification : 1.0;

    // Concrete compression strut factor nu1 = 0.6 (1 - f_ck / 250).
    final nu1 = 0.6 * (1.0 - material.fck / 250.0);

    for (final w in data.supports) {
      if (!w.isWall) continue;
      final rVec = w.positionM - crPosM;
      // Perpendicular lever arm of wall line of action about CR:
      // moment of unit force along axisUnit is r x axisUnit.
      final leverArm = rVec.dx * w.axisUnit.dy - rVec.dy * w.axisUnit.dx;

      // Direction 1 load (+u1 at CM): M_T = r_CM x (V1 u1) = -signedE2 * V1.
      final vDirect1 = data.k1 > 1e-12
          ? v1Kn * (w.strongIeq * (w.axisUnit.dx * u1.dx + w.axisUnit.dy * u1.dy)) / data.k1
          : 0.0;
      final mt1Plus = v1Kn * (-signedE2 + ea2);
      final mt1Minus = v1Kn * (-signedE2 - ea2);
      final vTors1Plus = data.kt > 1e-12 ? (mt1Plus / data.kt) * w.strongIeq * leverArm : 0.0;
      final vTors1Minus = data.kt > 1e-12 ? (mt1Minus / data.kt) * w.strongIeq * leverArm : 0.0;
      final vWall1 = math.max(
        vDirect1.abs(),
        math.max((vDirect1 + vTors1Plus).abs(), (vDirect1 + vTors1Minus).abs()),
      );

      // Direction 2 load (+u2 at CM): M_T = r_CM x (V2 u2) = +signedE1 * V2.
      final vDirect2 = data.k2 > 1e-12
          ? v2Kn * (w.strongIeq * (w.axisUnit.dx * u2.dx + w.axisUnit.dy * u2.dy)) / data.k2
          : 0.0;
      final mt2Plus = v2Kn * (signedE1 + ea1);
      final mt2Minus = v2Kn * (signedE1 - ea1);
      final vTors2Plus = data.kt > 1e-12 ? (mt2Plus / data.kt) * w.strongIeq * leverArm : 0.0;
      final vTors2Minus = data.kt > 1e-12 ? (mt2Minus / data.kt) * w.strongIeq * leverArm : 0.0;
      final vWall2 = math.max(
        vDirect2.abs(),
        math.max((vDirect2 + vTors2Plus).abs(), (vDirect2 + vTors2Minus).abs()),
      );

      // EC8 §4.3.3.5.2 directional combination envelope.
      const kDir = SeismicElfAssumptions.directionalFactor;
      final vEd = shearMag *
          math.max(vWall1 + kDir * vWall2, kDir * vWall1 + vWall2);

      // Preliminary wall shear capacity V_Rd (kN).
      final z = SeismicElfAssumptions.wallLeverArmRatio * w.lengthM;
      final vRds = SeismicElfAssumptions.wallHorizontalSteelRatio *
          w.thicknessM * z * SeismicElfAssumptions.steelYieldMpa * 1000.0;
      final vRdMax = 0.5 * w.thicknessM * z * nu1 * material.fcd * 1000.0;
      final vRd = math.min(vRds, vRdMax);

      outChecks[PreliminaryCheckReport.key(storeyId, w.id)] = ElementCheck(
        CheckKind.wallSeismicShear,
        vEd,
        vRd,
      );
    }
  }
}

class _StoreySeismicData {
  final String storeyId;
  final double massTonnes;
  final List<_SupportStiffness> supports;
  final bool hasMultipleRegions;
  final double k1, k2, kt;
  final Offset? crPosM;
  final Offset? cmPosM;
  final StoreyTorsionResult torsion;

  const _StoreySeismicData({
    required this.storeyId,
    required this.massTonnes,
    required this.supports,
    required this.hasMultipleRegions,
    required this.k1,
    required this.k2,
    required this.kt,
    this.crPosM,
    this.cmPosM,
    required this.torsion,
  });
}
