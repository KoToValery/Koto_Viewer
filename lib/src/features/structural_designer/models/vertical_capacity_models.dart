import '../analysis/slab_boundary_geometry.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'structural_element.dart';

/// Status of structural vertical capacity safety according to Eurocode 2 (EC2).
enum VerticalCapacityStatus {
  /// Utilization <= 80%, fully compliant.
  safe('В норма', Color(0xFF00E676), Color(0x3300E676)),

  /// Utilization between 80% and 100%, approaching limit.
  warning('Повишено натоварване', Color(0xFFFFB300), Color(0x33FFB300)),

  /// Utilization > 100% or punching shear failure, requires section enlargement.
  critical('Критично претоварване', Color(0xFFFF1744), Color(0x33FF1744));

  final String label;
  final Color color;
  final Color fillColor;

  const VerticalCapacityStatus(this.label, this.color, this.fillColor);

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case VerticalCapacityStatus.safe:
        return l10n.statusSafe;
      case VerticalCapacityStatus.warning:
        return l10n.statusWarning;
      case VerticalCapacityStatus.critical:
        return l10n.statusCritical;
    }
  }
}

/// Detailed vertical axial compression and punching shear check for an individual column.
class ColumnVerticalCheck {
  final String columnId;
  final String columnName;
  final String storeyId;
  final String storeyName;
  final int storeyIndex;
  final int numStoreysAbove;
  final Offset center;
  final ColumnShape shape;
  final double widthM;
  final double heightM;
  final double crossSectionAreaM2;
  final double tributaryAreaM2;

  /// Accumulated axial design load Ned accumulating from top down to this storey level (in kN).
  final double accumulatedLoadNedKn;

  /// Vertical shear force transferred from slab at this specific storey (in kN).
  final double floorShearForceVedKn;

  /// Design axial compression resistance Nrd according to EC2 (in kN).
  final double axialCapacityNrdKn;

  /// Utilization ratio Ned / Nrd.
  final double axialUtilization;

  /// Punching shear stress v_Ed at 2d perimeter (in MPa).
  final double punchingShearStressVedMpa;

  /// Concrete punching shear resistance v_Rd,c without shear rebar (in MPa).
  final double punchingShearResistanceVrdMpa;

  /// Punching shear utilization v_Ed / v_Rd,c.
  final double punchingUtilization;
  final PunchingSupportPosition punchingPosition;
  final double punchingBeta;

  /// Free opening boundaries and unsupported sections need a control-perimeter
  /// calculation beyond this preliminary rectangular-section approximation.
  final bool punchingRequiresReview;

  /// Overall safety status (safe, warning, or critical).
  final VerticalCapacityStatus status;

  /// Minimum required column cross-section (e.g. "40x40 cm" or "шайба 25x60 cm").
  final String minRequiredSectionCm;

  /// Actionable recommendation crafted specifically for the architect.
  final String architectRecommendation;

  /// Punching shear recommendation (if at risk).
  final String? punchingRecommendation;

  /// Whether column is connected to downstand beams (relieving punching shear).
  final bool hasConnectedBeams;

  /// Recommended slab thickness in cm if punching is critical.
  final int recommendedPunchingSlabThicknessCm;

  const ColumnVerticalCheck({
    required this.columnId,
    required this.columnName,
    required this.storeyId,
    required this.storeyName,
    required this.storeyIndex,
    required this.numStoreysAbove,
    required this.center,
    required this.shape,
    required this.widthM,
    required this.heightM,
    required this.crossSectionAreaM2,
    required this.tributaryAreaM2,
    required this.accumulatedLoadNedKn,
    required this.floorShearForceVedKn,
    required this.axialCapacityNrdKn,
    required this.axialUtilization,
    required this.punchingShearStressVedMpa,
    required this.punchingShearResistanceVrdMpa,
    required this.punchingUtilization,
    required this.status,
    required this.minRequiredSectionCm,
    required this.architectRecommendation,
    this.punchingRecommendation,
    this.hasConnectedBeams = false,
    this.punchingPosition = PunchingSupportPosition.undetermined,
    this.punchingBeta = 1.5,
    this.punchingRequiresReview = false,
    this.recommendedPunchingSlabThicknessCm = 20,
  });

  bool get isAxiallyOverloaded => axialUtilization > 1.0;
  bool get isPunchingCritical => punchingUtilization > 1.0;
  bool get hasWarning => status == VerticalCapacityStatus.warning;
  bool get hasCritical => status == VerticalCapacityStatus.critical;

  String localizedRecommendation(AppLocalizations l10n) {
    if (!isAxiallyOverloaded && punchingRequiresReview) {
      return l10n.schemePunchingGeometryReview;
    }
    if (!isAxiallyOverloaded && isPunchingCritical) {
      return l10n.verticalRecPunchingRisk(
        columnName, punchingShearStressVedMpa.toStringAsFixed(2),
        punchingShearResistanceVrdMpa.toStringAsFixed(2),
        recommendedPunchingSlabThicknessCm,
      );
    }
    final int curWCm = (widthM * 100).round();
    final int curHCm = (heightM * 100).round();
    final int util = (axialUtilization * 100).round();

    if (hasCritical) {
      return l10n.verticalRecColOverloaded(
        columnName,
        storeyName,
        curWCm,
        curHCm,
        minRequiredSectionCm,
        numStoreysAbove,
        accumulatedLoadNedKn.toStringAsFixed(0),
        axialCapacityNrdKn.toStringAsFixed(0),
      );
    } else if (hasWarning) {
      return l10n.verticalRecColWarning(
        columnName,
        storeyName,
        util,
        minRequiredSectionCm,
      );
    } else {
      return l10n.verticalRecColSafe(
        columnName,
        curWCm,
        curHCm,
        storeyName,
        numStoreysAbove,
        util,
      );
    }
  }

  String? localizedPunchingRecommendation(AppLocalizations l10n) {
    if (punchingRequiresReview) {
      return l10n.schemePunchingGeometryReview;
    }
    if (punchingRecommendation == null) return null;
    return l10n.verticalRecPunchingRisk(
      columnName,
      punchingShearStressVedMpa.toStringAsFixed(2),
      punchingShearResistanceVrdMpa.toStringAsFixed(2),
      recommendedPunchingSlabThicknessCm,
    );
  }
}

/// Geometric support interval screened against the assigned local slab depth.
/// The simplified span/depth limit is preliminary, not a calculated deflection.
class SupportSpanCheck {
  final (Offset, Offset) segment;
  final double spanM, thicknessM, allowableSpanM;
  final List<String> slabIds;
  final bool hasBeams;
  const SupportSpanCheck({required this.segment, required this.spanM,
    required this.thicknessM, required this.allowableSpanM,
    this.slabIds = const [], this.hasBeams = false});
  bool get isDetermined => thicknessM.isFinite && thicknessM > .03 &&
      allowableSpanM.isFinite && allowableSpanM > 0;
  bool get isProblematic => isDetermined && spanM > allowableSpanM + 1e-8;
  double get utilization => isDetermined ? spanM / allowableSpanM : double.infinity;
  double get requiredThicknessM => spanM / (hasBeams ? 28 : 22) + .03;
}

/// Preliminary span/depth screening under the application's simplified assumptions.
class SlabDeflectionCheck {
  final String storeyId;
  final String storeyName;
  final double currentThicknessM;
  final double maxSpanM;
  final double recommendedMinThicknessM;
  final bool isDeflectionSafe;
  final double deflectionRatio;
  final String recommendation;
  final (Offset, Offset)? criticalSpanSegment;
  final bool hasBeams;
  final List<SupportSpanCheck> supportSpans;

  const SlabDeflectionCheck({
    required this.storeyId,
    required this.storeyName,
    required this.currentThicknessM,
    required this.maxSpanM,
    required this.recommendedMinThicknessM,
    required this.isDeflectionSafe,
    required this.deflectionRatio,
    required this.recommendation,
    this.criticalSpanSegment,
    this.hasBeams = false,
    this.supportSpans = const [],
  });

  bool get isSpanDetermined => maxSpanM.isFinite;

  String localizedRecommendation(AppLocalizations l10n) {
    if (!isSpanDetermined) return l10n.schemeSpanUnknown;
    final int curCm = (currentThicknessM * 100).round();
    final int reqCm = (recommendedMinThicknessM * 100).ceil();
    if (!isDeflectionSafe) {
      if (hasBeams) {
        return l10n.verticalRecSlabInsufficient(
          maxSpanM.toStringAsFixed(2),
          curCm,
          reqCm,
        );
      } else {
        return l10n.verticalRecSlabBeamlessDeflection(
          maxSpanM.toStringAsFixed(2),
          curCm,
          reqCm,
        );
      }
    } else {
      return l10n.verticalRecSlabSafe(
        curCm,
        maxSpanM.toStringAsFixed(2),
      );
    }
  }
}

/// Comprehensive vertical gravitational capacity report for the entire project.
class VerticalCapacityReport {
  /// Total vertical building weight accumulating at foundation level (kN).
  final double totalVerticalLoadBaseKn;

  /// Average foundation base pressure sigma_base (kPa = kN/m²).
  final double basePressureKpa;

  /// Total building footprint area (m²).
  final double footprintAreaM2;

  /// List of checks for every column across all storeys.
  final List<ColumnVerticalCheck> columnChecks;

  /// List of slab deflection checks for each storey.
  final List<SlabDeflectionCheck> slabChecks;

  /// Total count of critically overloaded columns.
  final int criticalColumnsCount;

  /// Total count of warning columns.
  final int warningColumnsCount;

  /// Count of columns exhibiting punching shear risk.
  final int punchingRiskCount;

  /// Highest axial compression utilization ratio in the building.
  final double maxAxialUtilization;

  /// Highest punching shear utilization ratio in the building.
  final double maxPunchingUtilization;

  /// Overall building gravitational status.
  final VerticalCapacityStatus overallStatus;

  const VerticalCapacityReport({
    required this.totalVerticalLoadBaseKn,
    required this.basePressureKpa,
    required this.footprintAreaM2,
    required this.columnChecks,
    required this.slabChecks,
    required this.criticalColumnsCount,
    required this.warningColumnsCount,
    required this.punchingRiskCount,
    required this.maxAxialUtilization,
    required this.maxPunchingUtilization,
    required this.overallStatus,
  });

  static const VerticalCapacityReport empty = VerticalCapacityReport(
    totalVerticalLoadBaseKn: 0.0,
    basePressureKpa: 0.0,
    footprintAreaM2: 0.0,
    columnChecks: [],
    slabChecks: [],
    criticalColumnsCount: 0,
    warningColumnsCount: 0,
    punchingRiskCount: 0,
    maxAxialUtilization: 0.0,
    maxPunchingUtilization: 0.0,
    overallStatus: VerticalCapacityStatus.safe,
  );

  /// Count of storeys exhibiting slab deflection issues (insufficient thickness).
  int get slabIssuesCount => slabChecks.where((s) => !s.isDeflectionSafe).length;

  /// Total number of alerts across columns, punching, and slabs.
  int get totalAlertCount => criticalColumnsCount + punchingRiskCount + slabIssuesCount;

  /// Returns column check for a given columnId in the active storey, if present.
  ColumnVerticalCheck? getCheckForColumn(String columnId) {
    for (final check in columnChecks) {
      if (check.columnId == columnId) return check;
    }
    return null;
  }
}
