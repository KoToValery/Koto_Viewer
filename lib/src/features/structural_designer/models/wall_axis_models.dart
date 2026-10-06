import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';

/// Representation of an extracted 2D segment from CAD geometry.
class WallSegment {
  final Offset start;
  final Offset end;
  final double angleRad; // Normalized in [0, pi)
  final double
  offsetFromOrigin; // Perpendicular distance to origin (p * normal)
  final double length;
  final String sourceLayer;
  final int? sourceColorIndex;
  final int? sourceTrueColor;
  final DxfEntity? sourceEntity;

  const WallSegment({
    required this.start,
    required this.end,
    required this.angleRad,
    required this.offsetFromOrigin,
    required this.length,
    required this.sourceLayer,
    this.sourceColorIndex,
    this.sourceTrueColor,
    this.sourceEntity,
  });

  /// Unit direction vector along this segment.
  Offset get direction => Offset(math.cos(angleRad), math.sin(angleRad));

  /// Unique key for (Layer, Color) grouping.
  String get groupKey {
    final cKey = sourceTrueColor != null
        ? 'tc_${sourceTrueColor!}'
        : 'aci_${sourceColorIndex ?? 256}';
    return '${sourceLayer.trim()}##$cKey';
  }
}

/// A matched pair of parallel wall edges.
class WallPairCandidate {
  final WallSegment segmentA;
  final WallSegment segmentB;
  final double perpendicularDistance;
  final double overlapLength;
  final Offset centerlineStart;
  final Offset centerlineEnd;

  const WallPairCandidate({
    required this.segmentA,
    required this.segmentB,
    required this.perpendicularDistance,
    required this.overlapLength,
    required this.centerlineStart,
    required this.centerlineEnd,
  });
}

/// Statistics and candidate wall pairs for a single (Layer, Color) pair.
class LayerColorGroupResult {
  final String layerName;
  final int? colorIndex;
  final int? trueColor;
  final int pairCount;
  final double totalOverlapLength;
  final double score;
  final List<WallPairCandidate> wallPairs;

  const LayerColorGroupResult({
    required this.layerName,
    this.colorIndex,
    this.trueColor,
    required this.pairCount,
    required this.totalOverlapLength,
    required this.score,
    required this.wallPairs,
  });

  String get groupKey {
    final cKey = trueColor != null
        ? 'tc_$trueColor'
        : 'aci_${colorIndex ?? 256}';
    return '$layerName##$cKey';
  }
}

/// Overall result of the wall axis detection algorithm.
class WallAxisDetectionResult {
  final List<LayerColorGroupResult> evaluatedGroups;
  final LayerColorGroupResult? bestGroup;
  final double
  detectedScale; // CAD units per mm (e.g. 1.0 for mm, 0.1 for cm, 0.001 for m)
  final String detectedUnitName; // 'mm', 'cm', or 'm'
  final double targetThicknessMm;
  final List<(Offset, Offset)> rawCenterlines;
  final List<(Offset, Offset)> bridgedCenterlines;
  final List<(Offset, Offset)> snappedCenterlines;
  final List<(Offset, Offset)> wallContourSegments;
  final List<(Offset, Offset)> closureSegments;
  final List<WallPairCandidate> selectedWallPairs;

  const WallAxisDetectionResult({
    required this.evaluatedGroups,
    this.bestGroup,
    required this.detectedScale,
    required this.detectedUnitName,
    required this.targetThicknessMm,
    required this.rawCenterlines,
    required this.bridgedCenterlines,
    required this.snappedCenterlines,
    required this.wallContourSegments,
    this.closureSegments = const [],
    this.selectedWallPairs = const [],
  });

  bool get hasWallsFound => bestGroup != null && bestGroup!.pairCount > 0;

  static const WallAxisDetectionResult empty = WallAxisDetectionResult(
    evaluatedGroups: [],
    bestGroup: null,
    detectedScale: 1.0,
    detectedUnitName: 'mm',
    targetThicknessMm: 250.0,
    rawCenterlines: [],
    bridgedCenterlines: [],
    snappedCenterlines: [],
    wallContourSegments: [],
    closureSegments: [],
  );
}
