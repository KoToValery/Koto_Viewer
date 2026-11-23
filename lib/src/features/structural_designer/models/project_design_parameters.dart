import 'dart:math' as math;

// === SECTION: INDEX ===
// === SECTION: ENUMS & SPECTRUM TABLES ===
// === SECTION: DESIGN PARAMETERS MODEL ===
//
// Project-wide preliminary design inputs entered once per project.
// EC8 EN 1998-1 Table 3.2 (Type 1) and Table 3.3 (Type 2) elastic spectrum
// parameters are stored as explicit data tables so an engineer can review or
// override them against a National Annex without digging into solver code.

// === SECTION: ENUMS & SPECTRUM TABLES ===

/// Ground types per EC8 EN 1998-1 §3.1.2.
enum SeismicSoilType {
  a,
  b,
  c,
  d,
  e;

  String get code => name.toUpperCase();
}

/// Spectrum type per EC8 §3.2.2.2 (Type 1: Ms > 5.5, Type 2: Ms <= 5.5).
enum SeismicSpectrumType { type1, type2 }

/// Building importance classes per EC8 §4.2.5.
enum SeismicImportanceClass {
  i(0.8, 0.5),
  ii(1.0, 0.5),
  iii(1.2, 0.4),
  iv(1.4, 0.4);

  /// Recommended importance factor gamma_I (EC8 §4.2.5(5)).
  final double gammaI;

  /// Recommended drift reduction factor nu (EC8 §4.4.3.2(2)).
  final double driftNu;

  const SeismicImportanceClass(this.gammaI, this.driftNu);

  String get roman => name.toUpperCase();
}

/// Primary lateral-force-resisting system per EC8 §5.2.2.1.
enum SeismicSystemKind {
  /// Ductile shear wall system (auto-detected when walls dominate).
  wall(3.0, 0.05),

  /// Moment-resisting RC frame (auto-detected when no walls exist).
  frame(3.0, 0.075),

  /// Dual wall-frame system.
  dual(3.0, 0.05),

  /// Low ductility (DCL) / uncoupled conservative fallback.
  lowDuctility(1.5, 0.05);

  /// Typical preliminary DCM (or DCL) behaviour factor q.
  final double defaultQ;

  /// EC8 §4.3.3.2.2 period coefficient C_t fallback when A_c is not used.
  final double defaultCt;

  const SeismicSystemKind(this.defaultQ, this.defaultCt);
}

/// Non-structural element category for EC8 §4.4.3.2 drift limits.
enum DriftDamageCategory {
  /// Brittle non-structural elements attached to the structure (0.005 h).
  brittle(0.005),

  /// Ductile non-structural elements (0.0075 h).
  ductile(0.0075),

  /// Non-interfering or absent non-structural elements (0.010 h).
  nonInterfering(0.010);

  final double alphaLimit;
  const DriftDamageCategory(this.alphaLimit);
}

/// Elastic response spectrum shape constants (S, T_B, T_C, T_D).
class Ec8SpectrumParams {
  final double s;
  final double tb;
  final double tc;
  final double td;
  final String source;

  const Ec8SpectrumParams({
    required this.s,
    required this.tb,
    required this.tc,
    required this.td,
    required this.source,
  });

  /// Recommended EC8 EN 1998-1 Table 3.2 (Type 1) & Table 3.3 (Type 2).
  static Ec8SpectrumParams forSoil(
    SeismicSoilType soil,
    SeismicSpectrumType type,
  ) {
    if (type == SeismicSpectrumType.type1) {
      return switch (soil) {
        SeismicSoilType.a => const Ec8SpectrumParams(
          s: 1.00,
          tb: 0.15,
          tc: 0.40,
          td: 2.00,
          source: 'EN 1998-1 Table 3.2 (Type 1)',
        ),
        SeismicSoilType.b => const Ec8SpectrumParams(
          s: 1.20,
          tb: 0.15,
          tc: 0.50,
          td: 2.00,
          source: 'EN 1998-1 Table 3.2 (Type 1)',
        ),
        SeismicSoilType.c => const Ec8SpectrumParams(
          s: 1.15,
          tb: 0.20,
          tc: 0.60,
          td: 2.00,
          source: 'EN 1998-1 Table 3.2 (Type 1)',
        ),
        SeismicSoilType.d => const Ec8SpectrumParams(
          s: 1.35,
          tb: 0.20,
          tc: 0.80,
          td: 2.00,
          source: 'EN 1998-1 Table 3.2 (Type 1)',
        ),
        SeismicSoilType.e => const Ec8SpectrumParams(
          s: 1.40,
          tb: 0.15,
          tc: 0.50,
          td: 2.00,
          source: 'EN 1998-1 Table 3.2 (Type 1)',
        ),
      };
    }
    return switch (soil) {
      SeismicSoilType.a => const Ec8SpectrumParams(
        s: 1.00,
        tb: 0.05,
        tc: 0.25,
        td: 1.20,
        source: 'EN 1998-1 Table 3.3 (Type 2)',
      ),
      SeismicSoilType.b => const Ec8SpectrumParams(
        s: 1.35,
        tb: 0.05,
        tc: 0.25,
        td: 1.20,
        source: 'EN 1998-1 Table 3.3 (Type 2)',
      ),
      SeismicSoilType.c => const Ec8SpectrumParams(
        s: 1.50,
        tb: 0.10,
        tc: 0.25,
        td: 1.20,
        source: 'EN 1998-1 Table 3.3 (Type 2)',
      ),
      SeismicSoilType.d => const Ec8SpectrumParams(
        s: 1.80,
        tb: 0.10,
        tc: 0.30,
        td: 1.20,
        source: 'EN 1998-1 Table 3.3 (Type 2)',
      ),
      SeismicSoilType.e => const Ec8SpectrumParams(
        s: 1.60,
        tb: 0.05,
        tc: 0.25,
        td: 1.20,
        source: 'EN 1998-1 Table 3.3 (Type 2)',
      ),
    };
  }
}

// === SECTION: DESIGN PARAMETERS MODEL ===

/// Project-level seismic and drift design assumptions.
///
/// [agR] is intentionally nullable so no hidden seismic zone is invented for an
/// unconfigured project. Without [agR], gravity/plate checks run normally while
/// seismic shear and drift checks report "not configured".
class ProjectDesignParameters {
  static const double gravityMs2 = 9.81;

  /// Reference peak ground acceleration as a fraction of g (e.g. 0.23 for 0.23g).
  final double? agR;
  final SeismicImportanceClass importanceClass;
  final SeismicSoilType soilType;
  final SeismicSpectrumType spectrumType;

  /// Optional explicit system override; null auto-infers from placed supports.
  final SeismicSystemKind? systemOverride;

  /// Optional explicit behaviour factor q override; null uses system default.
  final double? behaviorFactorQ;

  /// Lower bound factor beta for design spectrum (EC8 §3.2.2.5, default 0.20).
  final double spectrumBeta;

  /// Non-structural drift damage limit category (EC8 §4.4.3.2).
  final DriftDamageCategory driftCategory;

  const ProjectDesignParameters({
    this.agR,
    this.importanceClass = SeismicImportanceClass.ii,
    this.soilType = SeismicSoilType.b,
    this.spectrumType = SeismicSpectrumType.type1,
    this.systemOverride,
    this.behaviorFactorQ,
    this.spectrumBeta = 0.20,
    this.driftCategory = DriftDamageCategory.brittle,
  });

  /// True only when the user has explicitly entered a valid positive a_gR.
  bool get isSeismicConfigured =>
      agR != null && agR!.isFinite && agR! > 0.0 && agR! <= 1.5;

  /// Design ground acceleration a_g = gamma_I * a_gR in m/s².
  double get agMs2 =>
      isSeismicConfigured ? agR! * importanceClass.gammaI * gravityMs2 : double.nan;

  /// Design ground acceleration as fraction of g.
  double get agG =>
      isSeismicConfigured ? agR! * importanceClass.gammaI : double.nan;

  Ec8SpectrumParams get spectrum =>
      Ec8SpectrumParams.forSoil(soilType, spectrumType);

  double effectiveQ(SeismicSystemKind resolvedSystem) {
    final q = behaviorFactorQ ?? resolvedSystem.defaultQ;
    return q.isFinite && q >= 1.0 ? q : resolvedSystem.defaultQ;
  }

  /// Evaluates design spectrum S_d(T) in m/s² per EC8 §3.2.2.5(4)P.
  double designSpectrumMs2(double periodS, SeismicSystemKind resolvedSystem) {
    if (!isSeismicConfigured || !periodS.isFinite || periodS < 0) {
      return double.nan;
    }
    final ag = agMs2;
    final p = spectrum;
    final q = effectiveQ(resolvedSystem);
    final floor = spectrumBeta * ag;
    if (periodS <= p.tb) {
      final ratio = p.tb > 0 ? periodS / p.tb : 1.0;
      return ag * p.s * (2.0 / 3.0 + ratio * (2.5 / q - 2.0 / 3.0));
    }
    if (periodS <= p.tc) {
      return ag * p.s * (2.5 / q);
    }
    if (periodS <= p.td) {
      return math.max(ag * p.s * (2.5 / q) * (p.tc / periodS), floor);
    }
    return math.max(
      ag * p.s * (2.5 / q) * (p.tc * p.td / (periodS * periodS)),
      floor,
    );
  }

  ProjectDesignParameters copyWith({
    double? agR,
    bool clearAgR = false,
    SeismicImportanceClass? importanceClass,
    SeismicSoilType? soilType,
    SeismicSpectrumType? spectrumType,
    SeismicSystemKind? systemOverride,
    bool clearSystemOverride = false,
    double? behaviorFactorQ,
    bool clearBehaviorFactorQ = false,
    double? spectrumBeta,
    DriftDamageCategory? driftCategory,
  }) {
    return ProjectDesignParameters(
      agR: clearAgR ? null : (agR ?? this.agR),
      importanceClass: importanceClass ?? this.importanceClass,
      soilType: soilType ?? this.soilType,
      spectrumType: spectrumType ?? this.spectrumType,
      systemOverride: clearSystemOverride
          ? null
          : (systemOverride ?? this.systemOverride),
      behaviorFactorQ: clearBehaviorFactorQ
          ? null
          : (behaviorFactorQ ?? this.behaviorFactorQ),
      spectrumBeta: spectrumBeta ?? this.spectrumBeta,
      driftCategory: driftCategory ?? this.driftCategory,
    );
  }

  Map<String, dynamic> toJson() => {
    if (agR != null) 'agR': agR,
    'importanceClass': importanceClass.name,
    'soilType': soilType.name,
    'spectrumType': spectrumType.name,
    if (systemOverride != null) 'systemOverride': systemOverride!.name,
    if (behaviorFactorQ != null) 'behaviorFactorQ': behaviorFactorQ,
    'spectrumBeta': spectrumBeta,
    'driftCategory': driftCategory.name,
  };

  factory ProjectDesignParameters.fromJson(Map<String, dynamic> json) {
    final rawAg = (json['agR'] as num?)?.toDouble();
    final rawQ = (json['behaviorFactorQ'] as num?)?.toDouble();
    final rawBeta = (json['spectrumBeta'] as num?)?.toDouble();
    return ProjectDesignParameters(
      agR: rawAg != null && rawAg.isFinite && rawAg > 0 ? rawAg : null,
      importanceClass: SeismicImportanceClass.values.firstWhere(
        (v) => v.name == json['importanceClass'],
        orElse: () => SeismicImportanceClass.ii,
      ),
      soilType: SeismicSoilType.values.firstWhere(
        (v) => v.name == json['soilType'],
        orElse: () => SeismicSoilType.b,
      ),
      spectrumType: SeismicSpectrumType.values.firstWhere(
        (v) => v.name == json['spectrumType'],
        orElse: () => SeismicSpectrumType.type1,
      ),
      systemOverride: json['systemOverride'] == null
          ? null
          : SeismicSystemKind.values.cast<SeismicSystemKind?>().firstWhere(
              (v) => v?.name == json['systemOverride'],
              orElse: () => null,
            ),
      behaviorFactorQ: rawQ != null && rawQ.isFinite && rawQ >= 1.0 ? rawQ : null,
      spectrumBeta: rawBeta != null && rawBeta.isFinite && rawBeta >= 0
          ? rawBeta
          : 0.20,
      driftCategory: DriftDamageCategory.values.firstWhere(
        (v) => v.name == json['driftCategory'],
        orElse: () => DriftDamageCategory.brittle,
      ),
    );
  }
}
