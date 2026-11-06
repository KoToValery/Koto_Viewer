import 'dart:ui';

// === SECTION: INDEX ===
// === SECTION: CHECK KINDS & LEVELS ===
// === SECTION: ELEMENT CHECK ===
// === SECTION: ELEMENT UTILIZATION ===
// === SECTION: SLAB RESULTS ===
// === SECTION: REPORT ===

// === SECTION: CHECK KINDS & LEVELS ===

/// Preliminary checks shown while placing supports by hand. Every value is an
/// elastic screening estimate with visible assumptions, not a code verification.
enum CheckKind {
  /// N_Ed (ULS) against a section capacity with minimum eccentricity e0.
  columnAxial,

  /// Normalised seismic axial load nu_d = N(G + psi2 Q) / (A_c f_cd).
  columnSeismicAxial,

  /// Slab reaction at the column against v_Rd,c / v_Rd,max (EC2 6.4).
  punching,

  /// Wall axial load under ULS.
  wallAxial,

  /// Normalised seismic axial load of a ductile wall.
  wallSeismicAxial,

  /// Long-term deflection against L_eff / 250.
  slabDeflection,

  /// Smoothed design moment against the practical section capacity.
  slabBending,
}

/// Traffic-light level. Colour is never the only carrier: the percentage text
/// is always drawn next to it.
enum UtilizationLevel {
  ok,
  near,
  over,
  unknown;

  static const nearThreshold = 0.85;

  static UtilizationLevel of(double utilization) {
    if (!utilization.isFinite || utilization < 0) return unknown;
    if (utilization <= nearThreshold) return ok;
    if (utilization <= 1.0) return near;
    return over;
  }

  Color get color => switch (this) {
    ok => const Color(0xFF69F0AE),
    near => const Color(0xFFFFB74D),
    over => const Color(0xFFFF5252),
    unknown => const Color(0xFFB0BEC5),
  };

  Color get fill => switch (this) {
    ok => const Color(0xFF1B7F4B),
    near => const Color(0xFFB26A00),
    over => const Color(0xFFB71C1C),
    unknown => const Color(0xFF546E7A),
  };
}

// === SECTION: ELEMENT CHECK ===

/// One demand/capacity pair. Units are SI symbols chosen by the check kind.
class ElementCheck {
  final CheckKind kind;
  final double demand;
  final double capacity;

  const ElementCheck(this.kind, this.demand, this.capacity);

  bool get isDetermined =>
      demand.isFinite && capacity.isFinite && capacity > 0 && demand >= 0;

  double get utilization => isDetermined ? demand / capacity : double.nan;

  UtilizationLevel get level => UtilizationLevel.of(utilization);
}

// === SECTION: ELEMENT UTILIZATION ===

enum CheckedElementType { column, wall }

class ElementUtilization {
  final String elementId;
  final String storeyId;
  final CheckedElementType type;
  final List<ElementCheck> checks;

  /// Axial load in the element at this storey (kN), ULS and G + psi2 Q.
  final double axialUls, axialQuasiPermanent;

  /// Slab reaction carried directly by this support (ULS, kN).
  final double slabReactionUls;

  const ElementUtilization({
    required this.elementId,
    required this.storeyId,
    required this.type,
    required this.checks,
    required this.axialUls,
    required this.axialQuasiPermanent,
    required this.slabReactionUls,
  });

  /// Worst determined check; null when nothing could be evaluated.
  ElementCheck? get governing {
    ElementCheck? worst;
    for (final c in checks) {
      if (!c.isDetermined) continue;
      if (worst == null || c.utilization > worst.utilization) worst = c;
    }
    return worst;
  }

  double get utilization => governing?.utilization ?? double.nan;

  UtilizationLevel get level => UtilizationLevel.of(utilization);

  ElementCheck? check(CheckKind kind) {
    for (final c in checks) {
      if (c.kind == kind) return c;
    }
    return null;
  }
}

// === SECTION: SLAB RESULTS ===

/// Worst point of one connected plate region on a storey ceiling.
class SlabCheckResult {
  final String storeyId;
  final int component;
  final ElementCheck deflection;
  final Offset deflectionPointCad;
  final ElementCheck bending;
  final Offset bendingPointCad;

  const SlabCheckResult({
    required this.storeyId,
    required this.component,
    required this.deflection,
    required this.deflectionPointCad,
    required this.bending,
    required this.bendingPointCad,
  });

  ElementCheck get governing =>
      !bending.isDetermined ||
          (deflection.isDetermined &&
              deflection.utilization >= bending.utilization)
      ? deflection
      : bending;

  Offset get governingPointCad =>
      identical(governing, deflection) ? deflectionPointCad : bendingPointCad;
}

/// Plate cells that no support can hold (rigid-body mechanism).
class UnsupportedSlabArea {
  final String storeyId;
  final List<List<Offset>> cellsCad;
  final double areaM2;
  const UnsupportedSlabArea(this.storeyId, this.cellsCad, this.areaM2);
}

// === SECTION: REPORT ===

class PreliminaryCheckReport {
  /// Keys are `storeyId/elementId`.
  final Map<String, ElementUtilization> elements;
  final List<SlabCheckResult> slabs;
  final List<UnsupportedSlabArea> unsupported;
  final int durationMs;

  const PreliminaryCheckReport({
    required this.elements,
    required this.slabs,
    required this.unsupported,
    this.durationMs = 0,
  });

  static const empty = PreliminaryCheckReport(
    elements: {},
    slabs: [],
    unsupported: [],
  );

  static String key(String storeyId, String elementId) => '$storeyId/$elementId';

  ElementUtilization? element(String storeyId, String elementId) =>
      elements[key(storeyId, elementId)];

  Iterable<SlabCheckResult> slabsFor(String storeyId) =>
      slabs.where((s) => s.storeyId == storeyId);

  Iterable<UnsupportedSlabArea> unsupportedFor(String storeyId) =>
      unsupported.where((u) => u.storeyId == storeyId);
}
