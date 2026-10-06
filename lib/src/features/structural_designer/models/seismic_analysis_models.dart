import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'slab_topology.dart';

/// Eurocode 8 (EC8 EN 1998-1) Seismic Regularity & Risk Classification.
enum SeismicRiskLevel {
  /// Regular structural layout, low torsional eccentricity, adequate shear walls.
  regular(
    'Без сигнал от предварителния модел',
    Color(0xFF00E676),
    Color(0x3300E676),
  ),

  /// Moderate eccentricity or mild shear wall deficit.
  warning('Повишен сеизмичен риск', Color(0xFFFFB300), Color(0x33FFB300)),

  /// Severe irregularity: floating/transfer columns, high torsional sensitivity (>15%), or soft storey.
  critical(
    'Критична сеизмична уязвимост',
    Color(0xFFD500F9),
    Color(0x33D500F9),
  );

  final String label;
  final Color color;
  final Color fillColor;

  const SeismicRiskLevel(this.label, this.color, this.fillColor);

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case SeismicRiskLevel.regular:
        return l10n.seismicPreliminaryBalanced;
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

  /// Slab geometry is present; this alone does not certify diaphragm behaviour.
  final bool hasSlabDiaphragm;

  /// False when the preliminary lateral model cannot be evaluated.
  final bool hasLateralStiffness;
  final List<String> connectionReviewNames;
  final SlabTopology slabTopology;
  final List<DiaphragmRegionCheck> diaphragmRegions;

  /// Center of Mass (CM), null when the single-diaphragm model is unavailable.
  final Offset? centerOfMassCad;

  /// Center of Rigidity (CR), null when geometry or stiffness is unevaluated.
  final Offset? centerOfRigidityCad;

  /// Physical eccentricity vector (e_x, e_y) in meters, or null if no diaphragm exists.
  final Offset? eccentricityM;

  /// Total building plan dimensions in meters at this storey.
  final double dimensionXM;
  final double dimensionYM;

  /// Relative eccentricity ratios: e_x / L_x and e_y / L_y.
  final double eccentricityRatioX;
  final double eccentricityRatioY;

  /// True if building is torsionally sensitive (r_x < l_s or r_y < l_s) per EC8 §4.2.3.2.
  final bool isTorsionallySensitive;

  /// Eurocode 8 Torsional radius in X direction: r_x = sqrt(I_p,R / K_y).
  final double torsionalRadiusX;

  /// Eurocode 8 Torsional radius in Y direction: r_y = sqrt(I_p,R / K_x).
  final double torsionalRadiusY;

  /// Radius of gyration from the modeled distributed weights, including openings.
  final double massRadiusOfGyration;

  /// Preliminary torsional layout index in m^6 (common E/height/restraint factor omitted).
  final double torsionalRigidity;

  /// True if building is torsionally stiff (r_x >= l_s and r_y >= l_s) per EC8 §4.2.3.2.
  final bool isTorsionallyStiff;

  /// True if building has structural eccentricity exceeding 0.30*r per EC8 §4.2.3.2.
  final bool hasSignificantEccentricity;

  /// Legacy flag. Always false from the preliminary calculator: full compliance is unverified.
  final bool isPlanRegularEC8;

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

  /// IDs of shear walls located outside the slab boundary (not connected to diaphragm).
  final List<String> disconnectedWallIds;
  final List<String> disconnectedWallNames;

  /// IDs of columns located outside the slab boundary (not connected to diaphragm).
  final List<String> disconnectedColumnIds;
  final List<String> disconnectedColumnNames;

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
    this.hasSlabDiaphragm = true,
    this.hasLateralStiffness = true,
    this.connectionReviewNames = const [],
    this.slabTopology = const SlabTopology(SlabTopologyIssue.none, 1),
    this.diaphragmRegions = const [],
    this.centerOfMassCad,
    this.centerOfRigidityCad,
    this.eccentricityM,
    required this.dimensionXM,
    required this.dimensionYM,
    required this.eccentricityRatioX,
    required this.eccentricityRatioY,
    required this.isTorsionallySensitive,
    this.torsionalRadiusX = 0.0,
    this.torsionalRadiusY = 0.0,
    this.massRadiusOfGyration = 0.0,
    this.torsionalRigidity = 0.0,
    this.isTorsionallyStiff = false,
    this.hasSignificantEccentricity = false,
    this.isPlanRegularEC8 = false,
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
    this.disconnectedWallIds = const [],
    this.disconnectedWallNames = const [],
    this.disconnectedColumnIds = const [],
    this.disconnectedColumnNames = const [],
    required this.lateralStiffnessIndex,
    this.stiffnessRatioToAbove,
    required this.isSoftStorey,
    required this.riskLevel,
    required this.architectRecommendation,
  });

  double get maxEccentricityM {
    if (eccentricityM == null) return 0.0;
    return (eccentricityM!.dx.abs() > eccentricityM!.dy.abs())
        ? eccentricityM!.dx.abs()
        : eccentricityM!.dy.abs();
  }

  double get maxEccentricityRatio {
    if (!hasSlabDiaphragm) return 0.0;
    return (eccentricityRatioX > eccentricityRatioY)
        ? eccentricityRatioX
        : eccentricityRatioY;
  }

  String localizedRecommendation(AppLocalizations l10n) {
    switch (slabTopology.issue) {
      case SlabTopologyIssue.invalidGeometry:
        return l10n.seismicInvalidSlabGeometry;
      case SlabTopologyIssue.overlappingSlabs:
        return l10n.seismicOverlappingSlabs;
      case SlabTopologyIssue.separateRegions:
        return l10n.seismicSeparateRegions(slabTopology.regionCount);
      case SlabTopologyIssue.computationLimit:
        return l10n.seismicSlabGeometryLimit;
      case SlabTopologyIssue.none:
        break;
    }
    if (!hasSlabDiaphragm) {
      return l10n.seismicRecNoSlabDiaphragm;
    }

    if (connectionReviewNames.isNotEmpty) {
      return l10n.seismicConnectionReview(connectionReviewNames.join(', '));
    }
    if (!hasLateralStiffness) return l10n.seismicRigidityUnavailable;

    final StringBuffer rec = StringBuffer();
    if (disconnectedWallNames.isNotEmpty) {
      rec.write(
        l10n.seismicRecDisconnectedWalls(disconnectedWallNames.join(', ')),
      );
      rec.write(' ');
    }
    if (disconnectedColumnNames.isNotEmpty) {
      rec.write(
        l10n.seismicRecDisconnectedCols(disconnectedColumnNames.join(', ')),
      );
      rec.write(' ');
    }
    if (floatingColumnNames.isNotEmpty) {
      rec.write(l10n.seismicRecFloatingCols(floatingColumnNames.join(', ')));
    }
    if (isTorsionallySensitive &&
        centerOfMassCad != null &&
        centerOfRigidityCad != null) {
      rec.write(
        l10n.seismicRecHighTorsion(
          maxEccentricityM.toStringAsFixed(2),
          (maxEccentricityRatio * 100).round(),
        ),
      );
      if (centerOfRigidityCad!.dx < centerOfMassCad!.dx) {
        rec.write(l10n.seismicRecAddWallEast);
      } else if (centerOfRigidityCad!.dx > centerOfMassCad!.dx) {
        rec.write(l10n.seismicRecAddWallWest);
      }
      if (centerOfRigidityCad!.dy < centerOfMassCad!.dy) {
        rec.write(l10n.seismicRecAddWallNorth);
      } else if (centerOfRigidityCad!.dy > centerOfMassCad!.dy) {
        rec.write(l10n.seismicRecAddWallSouth);
      }
    } else if (isTorsionallyStiff && hasSignificantEccentricity) {
      rec.write(
        l10n.seismicRecTorsionStiffEccentric(
          torsionalRadiusX.toStringAsFixed(2),
          torsionalRadiusY.toStringAsFixed(2),
          massRadiusOfGyration.toStringAsFixed(2),
          maxEccentricityM.toStringAsFixed(2),
        ),
      );
    } else if (!isWallCoverageSufficientX || !isWallCoverageSufficientY) {
      if (!isWallCoverageSufficientX && !isWallCoverageSufficientY) {
        rec.write(
          l10n.seismicRecDeficitBoth(
            wallRatioX.toStringAsFixed(1),
            wallRatioY.toStringAsFixed(1),
          ),
        );
      } else if (!isWallCoverageSufficientX) {
        rec.write(l10n.seismicRecDeficitX(wallRatioX.toStringAsFixed(1)));
      } else {
        rec.write(l10n.seismicRecDeficitY(wallRatioY.toStringAsFixed(1)));
      }
    } else {
      rec.write(l10n.seismicRecBalanced);
    }

    String result = rec.toString().trim();
    if (isSoftStorey) {
      result = '${l10n.seismicRecSoftStoreyPrefix}$result';
    }
    return result;
  }
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

  String localizedRecommendation(AppLocalizations l10n) {
    final int recH = (recommendedMinDepthM * 100).ceil();
    final int wCm = (currentWidthM * 100).round();
    final int dCm = (currentDepthM * 100).round();

    if (!isDepthSufficient) {
      return l10n.seismicRecBeamDepthInsufficient(
        spanM.toStringAsFixed(2),
        dCm,
        wCm,
        recH,
      );
    } else if (!isWidthSufficient) {
      return l10n.seismicRecBeamWidthInsufficient(wCm, dCm);
    } else {
      return l10n.seismicRecBeamSizingOk(wCm, dCm, spanM.toStringAsFixed(2));
    }
  }
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

  String localizedRecommendation(AppLocalizations l10n) {
    if (!distanceToSupportM.isFinite) return l10n.seismicOpeningNotEvaluated;
    final support = nearestSupportName ?? '';
    if (isTooClose) {
      return l10n.seismicRecOpeningClose(
        distanceToSupportM.toStringAsFixed(2),
        support,
      );
    } else {
      return l10n.seismicRecOpeningSafe(
        distanceToSupportM.toStringAsFixed(2),
        support,
      );
    }
  }
}

/// Isolated preliminary region model. No cross-storey or coupling verification.
class DiaphragmRegionCheck {
  final List<int> slabIndices;
  final List<String> columnIds;
  final List<String> wallIds;
  final List<String> ambiguousSupportNames;
  final StoreySeismicCheck? check;
  const DiaphragmRegionCheck({required this.slabIndices,
    required this.columnIds, required this.wallIds,
    required this.ambiguousSupportNames, this.check});
}

/// Preliminary seismic and structural layout report.
class SeismicAnalysisReport {
  final List<StoreySeismicCheck> storeyChecks;
  final List<BeamSizingCheck> beamChecks;
  final List<OpeningProximityCheck> openingChecks;
  final int totalFloatingColumnsCount;
  final int totalDiscontinuousWallsCount;
  final int totalDisconnectedWallsCount;
  final int totalDisconnectedColumnsCount;
  final bool hasTorsionalSensitivity;
  final bool hasStructuralEccentricity;
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
    this.totalDisconnectedWallsCount = 0,
    this.totalDisconnectedColumnsCount = 0,
    required this.hasTorsionalSensitivity,
    this.hasStructuralEccentricity = false,
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
    totalDisconnectedWallsCount: 0,
    totalDisconnectedColumnsCount: 0,
    hasTorsionalSensitivity: false,
    hasStructuralEccentricity: false,
    hasSoftStorey: false,
    hasWallDeficit: false,
    maxEccentricityRatio: 0.0,
    overallRisk: SeismicRiskLevel.regular,
  );

  bool get hasDisconnectedElements =>
      totalDisconnectedWallsCount > 0 || totalDisconnectedColumnsCount > 0;

  bool get hasAnySlabDiaphragm => storeyChecks.any((s) => s.hasSlabDiaphragm);

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
