import 'package:flutter/material.dart';

/// Type of detected cantilever zone.
enum CantileverType {
  /// Regular 1-way cantilever along a supporting edge/wall.
  linear('Линеен еркер (еднопосочна конзола)', Icons.linear_scale_rounded),

  /// Double corner cantilever (biaxial overhang without corner column support).
  cornerBiaxial('Двоен ъглов еркер (двупосочна конзола)', Icons.crop_free_rounded),

  /// Stacked / transfer cantilever where a column from upper floor rests on cantilever.
  transferStacked('Трансферен еркер (колона върху конзола)', Icons.warning_amber_rounded);

  final String label;
  final IconData icon;
  const CantileverType(this.label, this.icon);
}

/// Structural safety & deflection assessment status.
enum CantileverRiskLevel {
  safe('В норма (Безопасно)', Color(0xFF00E676), Color(0x3300E676)),
  warning('Внимание (Повишено провисване)', Color(0xFFFFB300), Color(0x33FFB300)),
  critical('Критично (Риск от недопустими деформации)', Color(0xFFFF1744), Color(0x33FF1744));

  final String label;
  final Color color;
  final Color fillColor;
  const CantileverRiskLevel(this.label, this.color, this.fillColor);
}

/// Detailed calculation result for a detected cantilever region.
class CantileverZone {
  final String id;
  final CantileverType type;
  final String storeyName;
  final Offset supportEdgeStart;
  final Offset supportEdgeEnd;
  final Offset overhangTip;
  final double length; // L_cant in meters
  final double? lengthY; // Ly in meters for corner overhang
  final double? effectiveDiagonal; // L_diag = sqrt(Lx^2 + Ly^2) for corner
  final double slabThickness; // h in meters
  final double slendernessRatio; // L / h
  final double elasticDeflectionMm; // f_el in mm
  final double longTermDeflectionMm; // f_tot in mm with creep phi
  final double limitDeflectionMm; // f_lim = L / 250 in mm
  final CantileverRiskLevel riskLevel;
  final List<String> recommendations;
  final String? stackedColumnId;

  const CantileverZone({
    required this.id,
    required this.type,
    required this.storeyName,
    required this.supportEdgeStart,
    required this.supportEdgeEnd,
    required this.overhangTip,
    required this.length,
    this.lengthY,
    this.effectiveDiagonal,
    required this.slabThickness,
    required this.slendernessRatio,
    required this.elasticDeflectionMm,
    required this.longTermDeflectionMm,
    required this.limitDeflectionMm,
    required this.riskLevel,
    required this.recommendations,
    this.stackedColumnId,
  });

  bool get isCorner => type == CantileverType.cornerBiaxial;
  bool get isTransfer => type == CantileverType.transferStacked;

  double get deflectionRatio =>
      limitDeflectionMm > 0 ? (longTermDeflectionMm / limitDeflectionMm) : 0.0;
}

/// Overall report summary for all storeys.
class StructuralAnalysisSummary {
  final int totalCantilevers;
  final int cornerCantilevers;
  final int transferCantilevers;
  final int criticalCount;
  final int warningCount;
  final double maxDeflectionMm;
  final double maxDeflectionRatio;
  final List<CantileverZone> zones;

  const StructuralAnalysisSummary({
    required this.totalCantilevers,
    required this.cornerCantilevers,
    required this.transferCantilevers,
    required this.criticalCount,
    required this.warningCount,
    required this.maxDeflectionMm,
    required this.maxDeflectionRatio,
    required this.zones,
  });

  static const empty = StructuralAnalysisSummary(
    totalCantilevers: 0,
    cornerCantilevers: 0,
    transferCantilevers: 0,
    criticalCount: 0,
    warningCount: 0,
    maxDeflectionMm: 0.0,
    maxDeflectionRatio: 0.0,
    zones: [],
  );
}
