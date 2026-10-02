import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Eurocode 8 (EC8 EN 1998-1) Seismic Regularity & Risk Classification.
enum SeismicRiskLevel {
  /// Regular structural layout, low torsional eccentricity, adequate shear walls.
  regular('Регулярна / В норма', Color(0xFF00E676), Color(0x3300E676)),

  /// Moderate eccentricity or mild shear wall deficit.
  warning('Повишен сеизмичен риск', Color(0xFFFFB300), Color(0x33FFB300)),

  /// Severe irregularity: floating/transfer columns, high torsional sensitivity (>15%), or soft storey.
  critical('Критична сеизмична уязвимост', Color(0xFFD500F9), Color(0x33D500F9));

  final String label;
  final Color color;
  final Color fillColor;

  const SeismicRiskLevel(this.label, this.color, this.fillColor);

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case SeismicRiskLevel.regular:
        return l10n.statusSafe;
      case SeismicRiskLevel.warning:
        return l10n.statusWarning;
      case SeismicRiskLevel.critical:
        return l10n.statusCritical;
    }
  }
}

/// Detailed seismic analysis check for an individual building storey.
class StoreySeismicCheck {
  final String storeyId;
  final String storeyName;
  final int storeyIndex;

  /// Center of Mass (CM) in CAD coordinates.
  final Offset centerOfMassCad;

  /// Center of Rigidity / Stiffness (CR) in CAD coordinates.
  final Offset centerOfRigidityCad;

  /// Physical eccentricity vector (e_x, e_y) in meters.
  final Offset eccentricityM;

  /// Total building plan dimensions in meters at this storey.
  final double dimensionXM;
  final double dimensionYM;

  /// Relative eccentricity ratios: e_x / L_x and e_y / L_y.
  final double eccentricityRatioX;
  final double eccentricityRatioY;

  /// True if building is torsionally sensitive (e0 > 0.15 or e > 0.30 r).
  final bool isTorsionallySensitive;

  /// Total cross-sectional area of shear walls oriented along X axis (m²).
  final double wallAreaXM2;

  /// Total cross-sectional area of shear walls oriented along Y axis (m²).
  final double wallAreaYM2;

  /// Floor footprint area (m²).
  final double floorAreaM2;

  /// Shear wall ratio in X: (A_w,x / A_floor) * 100%.
  final double wallRatioX;

  /// Shear wall ratio in Y: (A_w,y / A_floor) * 100%.
  final double wallRatioY;

  /// True if shear wall coverage meets Bulgarian/EC8 recommendations (>= 1.0%).
  final bool isWallCoverageSufficientX;
  final bool isWallCoverageSufficientY;

  /// IDs of floating (transfer) columns on this storey with no lower support.
  final List<String> floatingColumnIds;
  final List<String> floatingColumnNames;

  /// IDs of shear walls discontinued on this storey.
  final List<String> discontinuousWallIds;

  /// Lateral stiffness index (sum EI / h³).
  final double lateralStiffnessIndex;

  /// Ratio of stiffness to the storey above (soft storey check).
  final double? stiffnessRatioToAbove;

  /// True if this storey is significantly softer than storey above (< 70%).
  final bool isSoftStorey;

  /// Overall risk level for this storey.
  final SeismicRiskLevel riskLevel;

  /// Architectural recommendation for balancing and regularity.
  final String architectRecommendation;

  const StoreySeismicCheck({
    required this.storeyId,
    required this.storeyName,
    required this.storeyIndex,
    required this.centerOfMassCad,
    required this.centerOfRigidityCad,
    required this.eccentricityM,
    required this.dimensionXM,
    required this.dimensionYM,
    required this.eccentricityRatioX,
    required this.eccentricityRatioY,
    required this.isTorsionallySensitive,
    required this.wallAreaXM2,
    required this.wallAreaYM2,
    required this.floorAreaM2,
    required this.wallRatioX,
    required this.wallRatioY,
    required this.isWallCoverageSufficientX,
    required this.isWallCoverageSufficientY,
    required this.floatingColumnIds,
    required this.floatingColumnNames,
    required this.discontinuousWallIds,
    required this.lateralStiffnessIndex,
    this.stiffnessRatioToAbove,
    required this.isSoftStorey,
    required this.riskLevel,
    required this.architectRecommendation,
  });

  double get maxEccentricityM =>
      (eccentricityM.dx.abs() > eccentricityM.dy.abs())
          ? eccentricityM.dx.abs()
          : eccentricityM.dy.abs();

  double get maxEccentricityRatio =>
      (eccentricityRatioX > eccentricityRatioY)
          ? eccentricityRatioX
          : eccentricityRatioY;
}

/// Preliminary sizing check for reinforced concrete beams (EC2 & EC8).
class BeamSizingCheck {
  final String beamId;
  final String beamName;
  final String storeyId;
  final String storeyName;
  final double spanM;
  final double currentWidthM;
  final double currentDepthM;
  final double recommendedMinDepthM;
  final double recommendedOptimalDepthM;
  final bool isDepthSufficient;
  final bool isWidthSufficient;
  final String recommendation;

  const BeamSizingCheck({
    required this.beamId,
    required this.beamName,
    required this.storeyId,
    required this.storeyName,
    required this.spanM,
    required this.currentWidthM,
    required this.currentDepthM,
    required this.recommendedMinDepthM,
    required this.recommendedOptimalDepthM,
    required this.isDepthSufficient,
    required this.isWidthSufficient,
    required this.recommendation,
  });
}

/// Safety check for slab penetration openings near columns and shear walls.
class OpeningProximityCheck {
  final String openingId;
  final String storeyId;
  final String storeyName;
  final double distanceToSupportM;
  final String? nearestSupportName;
  final bool isTooClose;
  final String recommendation;

  const OpeningProximityCheck({
    required this.openingId,
    required this.storeyId,
    required this.storeyName,
    required this.distanceToSupportM,
    this.nearestSupportName,
    required this.isTooClose,
    required this.recommendation,
  });
}

/// Comprehensive Eurocode 8 Seismic & Structural Regularity Report.
class SeismicAnalysisReport {
  final List<StoreySeismicCheck> storeyChecks;
  final List<BeamSizingCheck> beamChecks;
  final List<OpeningProximityCheck> openingChecks;
  final int totalFloatingColumnsCount;
  final int totalDiscontinuousWallsCount;
  final bool hasTorsionalSensitivity;
  final bool hasSoftStorey;
  final bool hasWallDeficit;
  final double maxEccentricityRatio;
  final SeismicRiskLevel overallRisk;

  const SeismicAnalysisReport({
    required this.storeyChecks,
    required this.beamChecks,
    required this.openingChecks,
    required this.totalFloatingColumnsCount,
    required this.totalDiscontinuousWallsCount,
    required this.hasTorsionalSensitivity,
    required this.hasSoftStorey,
    required this.hasWallDeficit,
    required this.maxEccentricityRatio,
    required this.overallRisk,
  });

  static const SeismicAnalysisReport empty = SeismicAnalysisReport(
    storeyChecks: [],
    beamChecks: [],
    openingChecks: [],
    totalFloatingColumnsCount: 0,
    totalDiscontinuousWallsCount: 0,
    hasTorsionalSensitivity: false,
    hasSoftStorey: false,
    hasWallDeficit: false,
    maxEccentricityRatio: 0.0,
    overallRisk: SeismicRiskLevel.regular,
  );

  bool isColumnFloating(String columnId) {
    for (final s in storeyChecks) {
      if (s.floatingColumnIds.contains(columnId)) return true;
    }
    return false;
  }

  StoreySeismicCheck? getCheckForStorey(String storeyId) {
    for (final s in storeyChecks) {
      if (s.storeyId == storeyId) return s;
    }
    return null;
  }
}
