import 'dart:math' as math;
import 'dart:ui';

import '../models/element_check_models.dart';
import '../models/structural_element.dart';
import 'slab_boundary_geometry.dart';
import 'slab_plate_model.dart';

// === SECTION: INDEX ===
// === SECTION: MATERIAL & ASSUMPTIONS ===
// === SECTION: VERTICAL MEMBERS ===
// === SECTION: PUNCHING ===
// === SECTION: SLAB FIELD ===
//
// Preliminary EC2/EC8-based screening formulas. Every assumed quantity is a
// named constant below so a reviewing engineer can find and adjust it.

// === SECTION: MATERIAL & ASSUMPTIONS ===

class CheckMaterial {
  final double fck; // MPa
  final double fcd; // MPa
  final double elasticModulusMpa;
  const CheckMaterial(this.fck, this.fcd, this.elasticModulusMpa);

  /// alpha_cc = 0.85, gamma_c = 1.5 (kept consistent with the existing report).
  factory CheckMaterial.of(StructuralProject project) {
    final match = RegExp(r'C(\d+)').firstMatch(project.concreteGrade.toUpperCase());
    final fck = double.tryParse(match?.group(1) ?? '') ?? 25.0;
    final e = project.concreteE.isFinite && project.concreteE > 0
        ? project.concreteE
        : 31000.0;
    return CheckMaterial(fck, 0.85 * fck / 1.5, e);
  }
}

class CheckAssumptions {
  /// Steel stress when concrete reaches eps_c2 = 2 per mille (Es * 0.002).
  static const steelCompressionMpa = 400.0;

  /// Assumed longitudinal reinforcement ratios.
  static const columnSteelRatio = 0.01;
  static const wallSteelRatio = 0.002;
  static const slabTopSteelRatio = 0.006;

  /// EC8 DCM limits of the normalised axial load in the seismic situation.
  static const columnNuLimit = 0.65;
  static const wallNuLimit = 0.40;

  /// Cover plus half bar for the mean effective depth of a slab.
  static const slabDepthReductionM = 0.035;

  /// Long-term multiplier on the elastic, uncracked deflection under G + psi2 Q
  /// (creep and cracking). Screening value, shown to the user.
  static const longTermDeflectionFactor = 3.0;

  /// Deflection limit L / 250 (EC2 7.4.1(4)), L_eff = 2 x distance to support.
  static const deflectionSpanRatio = 250.0;

  /// Practical slab section capacity mu = M / (d^2 f_cd) at x/d ~ 0.25.
  static const slabMomentCoefficient = 0.18;

  /// Moments are averaged over this radius before the capacity comparison.
  static const momentSmoothingRadiusM = 1.0;
}

// === SECTION: VERTICAL MEMBERS ===

class MemberChecks {
  /// Section capacity in centric compression with e0 = max(h/30, 20 mm):
  /// N_Rd = f_cd A (1 - 2 e0 / h) + rho A sigma_s.
  static double axialCapacityKn({
    required double areaM2,
    required double minDimensionM,
    required double steelRatio,
    required CheckMaterial material,
  }) {
    if (!(areaM2 > 0) || !(minDimensionM > 0)) return double.nan;
    final e0 = math.max(minDimensionM / 30, 0.02);
    final concrete = material.fcd * areaM2 * math.max(0.0, 1 - 2 * e0 / minDimensionM);
    final steel = steelRatio * areaM2 * CheckAssumptions.steelCompressionMpa;
    return (concrete + steel) * 1000;
  }

  static List<ElementCheck> column({
    required double axialUls,
    required double axialQp,
    required double areaM2,
    required double minDimensionM,
    required CheckMaterial material,
  }) => [
    ElementCheck(
      CheckKind.columnAxial,
      axialUls,
      axialCapacityKn(
        areaM2: areaM2,
        minDimensionM: minDimensionM,
        steelRatio: CheckAssumptions.columnSteelRatio,
        material: material,
      ),
    ),
    ElementCheck(
      CheckKind.columnSeismicAxial,
      areaM2 > 0 ? axialQp / (areaM2 * material.fcd * 1000) : double.nan,
      CheckAssumptions.columnNuLimit,
    ),
  ];

  static List<ElementCheck> wall({
    required double axialUls,
    required double axialQp,
    required double areaM2,
    required double thicknessM,
    required CheckMaterial material,
  }) => [
    ElementCheck(
      CheckKind.wallAxial,
      axialUls,
      axialCapacityKn(
        areaM2: areaM2,
        minDimensionM: thicknessM,
        steelRatio: CheckAssumptions.wallSteelRatio,
        material: material,
      ),
    ),
    ElementCheck(
      CheckKind.wallSeismicAxial,
      areaM2 > 0 ? axialQp / (areaM2 * material.fcd * 1000) : double.nan,
      CheckAssumptions.wallNuLimit,
    ),
  ];

  /// Smallest section dimension in metres (L-shapes use the leg thickness).
  static double columnMinDimensionM(StructuralColumn c, double scale) =>
      switch (c.shape) {
        ColumnShape.circular => c.width / scale,
        ColumnShape.rectangular => math.min(c.width, c.height) / scale,
        ColumnShape.lShape =>
          math.min(c.thickness, math.min(c.width, c.height)) / scale,
      };

  static double polygonAreaM2(List<Offset> poly, double scale) {
    var a = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      a += p.dx * q.dy - q.dx * p.dy;
    }
    return a.abs() / 2 / (scale * scale);
  }

  static double columnAreaM2(StructuralColumn c, double scale) =>
      c.shape == ColumnShape.circular
          ? math.pi * math.pow(c.width / scale / 2, 2)
          : polygonAreaM2(c.polygonVertices, scale);

  // === SECTION: PUNCHING ===

  /// Basic control perimeter at 2d (EC2 6.4.2), clipped where it leaves the
  /// slab or crosses an opening; the column face perimeter u0 likewise.
  static ({double u1, double u0}) punchingPerimeters(
    List<Offset> columnPolygon,
    List<StructuralSlab> slabs,
    double effectiveDepthM,
    double scale,
  ) {
    final hull = compute2DConvexHull(columnPolygon);
    if (hull.length < 3) return (u1: double.nan, u0: double.nan);
    double clippedLength(List<Offset> ring) {
      var length = 0.0;
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i], b = ring[(i + 1) % ring.length];
        if (SlabBoundaryGeometry.contains((a + b) / 2, slabs)) {
          length += (b - a).distance;
        }
      }
      return length / scale;
    }

    // Minkowski sum with a circle: support point plus r * n for fine n.
    const steps = 144;
    final r = 2 * effectiveDepthM * scale;
    final control = <Offset>[];
    for (var k = 0; k < steps; k++) {
      final angle = 2 * math.pi * k / steps;
      final n = Offset(math.cos(angle), math.sin(angle));
      var best = hull.first;
      for (final v in hull) {
        if (v.dx * n.dx + v.dy * n.dy > best.dx * n.dx + best.dy * n.dy) best = v;
      }
      control.add(best + n * r);
    }
    // Column face sampled just outside the section.
    final face = <Offset>[];
    final centre = hull.reduce((a, b) => a + b) / hull.length.toDouble();
    for (var i = 0; i < hull.length; i++) {
      final a = hull[i], b = hull[(i + 1) % hull.length];
      for (var k = 0; k < 8; k++) {
        final p = a + (b - a) * (k / 8);
        final out = p - centre;
        face.add(out.distance > 0 ? p + out / out.distance * (0.01 * scale) : p);
      }
    }
    return (u1: clippedLength(control), u0: clippedLength(face));
  }

  /// v_Ed = beta V / (u1 d) against v_Rd,c, and at u0 against v_Rd,max.
  static ElementCheck punching({
    required double reactionUls,
    required double beta,
    required double u1,
    required double u0,
    required double effectiveDepthM,
    required CheckMaterial material,
  }) {
    if (!(effectiveDepthM > 0.05) || !(u1 > 0) || !(u0 > 0) ||
        !reactionUls.isFinite) {
      return const ElementCheck(CheckKind.punching, double.nan, double.nan);
    }
    final dMm = effectiveDepthM * 1000;
    final k = math.min(2.0, 1 + math.sqrt(200 / dMm));
    final vRdc = math.max(
      0.18 / 1.5 * k * math.pow(100 * CheckAssumptions.slabTopSteelRatio * material.fck, 1 / 3),
      0.035 * math.pow(k, 1.5) * math.sqrt(material.fck),
    );
    final vRdMax = 0.4 * 0.6 * (1 - material.fck / 250) * material.fcd;
    final v = math.max(0.0, reactionUls);
    final vEd = beta * v / (u1 * effectiveDepthM) / 1000;
    final vEd0 = beta * v / (u0 * effectiveDepthM) / 1000;
    return vEd / vRdc >= vEd0 / vRdMax
        ? ElementCheck(CheckKind.punching, vEd, vRdc)
        : ElementCheck(CheckKind.punching, vEd0, vRdMax);
  }

  // === SECTION: SLAB FIELD ===

  /// Worst deflection and bending point of every connected plate region.
  static List<SlabCheckResult> slabField(
    String storeyId,
    PlateSolution plate,
    CheckMaterial material,
    double scale,
  ) {
    if (plate.status != PlateStatus.solved) return const [];
    final byComponent = <int, SlabCheckResult>{};
    final worstDeflection = <int, (double, Offset, double, double)>{};
    final minSpan = 2 * plate.spacingM;
    for (final n in plate.nodes) {
      final span = math.max(minSpan, 2 * n.distanceToSupportM);
      final w = n.deflectionQp * CheckAssumptions.longTermDeflectionFactor * 1000;
      final limit = span / CheckAssumptions.deflectionSpanRatio * 1000;
      final u = w / limit;
      final current = worstDeflection[n.component];
      if (current == null || u > current.$1) {
        worstDeflection[n.component] = (u, n.pointCad, w, limit);
      }
    }
    // Smoothed moments: average components over the radius, then design
    // moment max(|Mx| + |Mxy|, |My| + |Mxy|) (Wood-Armer simplification).
    final radius = CheckAssumptions.momentSmoothingRadiusM * scale;
    final buckets = <(int, int), List<PlateCellResult>>{};
    (int, int) bucket(Offset p) => ((p.dx / radius).floor(), (p.dy / radius).floor());
    for (final c in plate.cells) {
      buckets.putIfAbsent(bucket(c.centerCad), () => []).add(c);
    }
    final worstBending = <int, (double, Offset, double, double)>{};
    for (final c in plate.cells) {
      final (bx, by) = bucket(c.centerCad);
      var mx = 0.0, my = 0.0, mxy = 0.0, count = 0;
      for (var i = bx - 1; i <= bx + 1; i++) {
        for (var j = by - 1; j <= by + 1; j++) {
          for (final o in buckets[(i, j)] ?? const <PlateCellResult>[]) {
            if (o.component != c.component ||
                (o.centerCad - c.centerCad).distance > radius) {
              continue;
            }
            mx += o.mx;
            my += o.my;
            mxy += o.mxy;
            count++;
          }
        }
      }
      if (count == 0) continue;
      mx /= count;
      my /= count;
      mxy /= count;
      final m = math.max(mx.abs() + mxy.abs(), my.abs() + mxy.abs());
      final d = c.thicknessM - CheckAssumptions.slabDepthReductionM;
      if (d <= 0.03) continue;
      final capacity = CheckAssumptions.slabMomentCoefficient * d * d * material.fcd * 1000;
      final u = m / capacity;
      final current = worstBending[c.component];
      if (current == null || u > current.$1) {
        worstBending[c.component] = (u, c.centerCad, m, capacity);
      }
    }
    for (final entry in worstDeflection.entries) {
      final (_, point, w, limit) = entry.value;
      final bend = worstBending[entry.key];
      byComponent[entry.key] = SlabCheckResult(
        storeyId: storeyId,
        component: entry.key,
        deflection: ElementCheck(CheckKind.slabDeflection, w, limit),
        deflectionPointCad: point,
        bending: bend == null
            ? const ElementCheck(CheckKind.slabBending, double.nan, double.nan)
            : ElementCheck(CheckKind.slabBending, bend.$3, bend.$4),
        bendingPointCad: bend?.$2 ?? point,
      );
    }
    return byComponent.values.toList();
  }
}
