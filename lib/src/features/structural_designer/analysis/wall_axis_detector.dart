import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/wall_axis_models.dart';

/// Intelligent Wall & Centerline Axis Detector for CAD / BIM drawings.
///
/// Implements:
/// 1. Automatic scale detection (250 mm / 25 cm / 0.25 m).
/// 2. Segment extraction grouped by (Layer, Color).
/// 3. Collinear pre-merging and deduplication.
/// 4. O(N log N) parallel pair detection sorted by perpendicular offset.
/// 5. Wall layer/color ranking (scoring by overlap length and pair count).
/// 6. Opening bridging across doors and windows (gaps <= 2.50 m).
/// 7. Topological corner snapping (L-corners and T-junctions).
/// 8. Clean layer generation (WALLS_250 and AXIS dashed).
class WallAxisDetector {
  const WallAxisDetector._();

  /// Default wall thickness in millimeters (standard European masonry wall).
  static const double defaultWallThicknessMm = 250.0;
  static const double defaultThicknessToleranceMm = 5.0;
  static const double defaultMinOverlapMm = 100.0;
  static const double defaultMaxOpeningBridgeGapMm = 2500.0; // 2.50 meters
  static const double defaultCornerSnapRadiusMm = 300.0; // 30 cm

  /// Detects wall pairs and centerline axes from a [DxfDocument].
  static WallAxisDetectionResult detect(
    DxfDocument document, {
    double targetThicknessMm = defaultWallThicknessMm,
    double thicknessToleranceMm = defaultThicknessToleranceMm,
    double minOverlapMm = defaultMinOverlapMm,
    double maxOpeningBridgeGapMm = defaultMaxOpeningBridgeGapMm,
    double cornerSnapRadiusMm = defaultCornerSnapRadiusMm,
    double? forceScaleFactor,
  }) {
    // Step 1: Extract all straight segments partitioned by (Layer, Color)
    final segmentsByGroup = _extractSegmentsByGroup(document);
    if (segmentsByGroup.isEmpty) {
      return WallAxisDetectionResult.empty;
    }

    // Step 2: Determine unit scale factor (CAD units per mm)
    final ({double scale, String unitName}) scaleInfo = forceScaleFactor != null
        ? (scale: forceScaleFactor, unitName: _getUnitNameFromScale(forceScaleFactor))
        : _autoDetectScale(
            segmentsByGroup,
            targetThicknessMm,
            thicknessToleranceMm,
            minOverlapMm,
          );

    final double scale = scaleInfo.scale;
    final double targetDistCad = targetThicknessMm * scale;
    final double toleranceCad = thicknessToleranceMm * scale;
    final double minOverlapCad = minOverlapMm * scale;
    final double maxBridgeGapCad = maxOpeningBridgeGapMm * scale;
    final double snapRadiusCad = cornerSnapRadiusMm * scale;

    // Step 3: Run pair detection on each (Layer, Color) group and rank them
    final List<LayerColorGroupResult> evaluatedGroups = [];

    for (final entry in segmentsByGroup.entries) {
      final segments = entry.value;
      if (segments.length < 2) continue;

      // Collinear pre-merging to clean broken drafts & duplicates
      final mergedSegments = _mergeCollinearSegments(segments, toleranceCad);

      // Detect parallel pairs at target distance
      final pairs = _findParallelPairs(
        mergedSegments,
        targetDistCad,
        toleranceCad,
        minOverlapCad,
      );

      if (pairs.isNotEmpty) {
        double totalOverlap = 0.0;
        for (final p in pairs) {
          totalOverlap += p.overlapLength;
        }

        // Score: primary weight on total length, secondary on pair count
        final score = totalOverlap + (pairs.length * 200.0 * scale);

        final firstSeg = segments.first;
        evaluatedGroups.add(
          LayerColorGroupResult(
            layerName: firstSeg.sourceLayer,
            colorIndex: firstSeg.sourceColorIndex,
            trueColor: firstSeg.sourceTrueColor,
            pairCount: pairs.length,
            totalOverlapLength: totalOverlap / scale / 1000.0, // in meters
            score: score,
            wallPairs: pairs,
          ),
        );
      }
    }

    // Sort groups descending by score
    evaluatedGroups.sort((a, b) => b.score.compareTo(a.score));

    if (evaluatedGroups.isEmpty) {
      return WallAxisDetectionResult(
        evaluatedGroups: const [],
        bestGroup: null,
        detectedScale: scale,
        detectedUnitName: scaleInfo.unitName,
        targetThicknessMm: targetThicknessMm,
        rawCenterlines: const [],
        bridgedCenterlines: const [],
        snappedCenterlines: const [],
        wallContourSegments: const [],
      );
    }

    final bestGroup = evaluatedGroups.first;

    // Step 4: Collect raw centerlines and wall contour segments from winning group
    final rawCenterlines = <(Offset, Offset)>[];
    final wallContourSegments = <(Offset, Offset)>[];

    for (final pair in bestGroup.wallPairs) {
      rawCenterlines.add((pair.centerlineStart, pair.centerlineEnd));
      wallContourSegments.add((pair.segmentA.start, pair.segmentA.end));
      wallContourSegments.add((pair.segmentB.start, pair.segmentB.end));
    }

    // Step 5: Bridge collinear gaps across openings (doors, windows)
    final bridgedCenterlines = _bridgeOpenings(
      rawCenterlines,
      maxBridgeGapCad,
      toleranceCad,
    );

    // Step 6: Topological corner snapping (L-corners and T-junctions)
    final snappedCenterlines = _snapCornersAndJunctions(
      bridgedCenterlines,
      snapRadiusCad,
    );

    return WallAxisDetectionResult(
      evaluatedGroups: evaluatedGroups,
      bestGroup: bestGroup,
      detectedScale: scale,
      detectedUnitName: scaleInfo.unitName,
      targetThicknessMm: targetThicknessMm,
      rawCenterlines: rawCenterlines,
      bridgedCenterlines: bridgedCenterlines,
      snappedCenterlines: snappedCenterlines,
      wallContourSegments: wallContourSegments,
    );
  }

  /// Injects detected walls and axes into [document], isolating walls and hiding other layers.
  static void applyToDocument(
    DxfDocument document,
    WallAxisDetectionResult result, {
    String wallLayerName = 'WALLS_250',
    String axisLayerName = 'AXIS',
  }) {
    if (!result.hasWallsFound) return;

    // 1. Hide all existing layers
    for (final layer in document.layers.values) {
      layer.isVisible = false;
    }

    // 2. Create or update WALLS_250 layer
    final wallColor = result.bestGroup?.colorIndex ?? 7;
    final wallLayer = DxfLayer(
      name: wallLayerName,
      colorIndex: wallColor,
      trueColor: result.bestGroup?.trueColor,
      isVisible: true,
      customLineweight: 0.70,
    );
    document.layers[wallLayerName] = wallLayer;

    // 3. Create or update AXIS layer (Red ACI 1, DASHED)
    final axisLayer = DxfLayer(
      name: axisLayerName,
      colorIndex: 1, // Red
      isVisible: true,
      lineType: 'DASHED',
      customLineweight: 0.25,
    );
    document.layers[axisLayerName] = axisLayer;

    // 4. Add wall contour lines to document
    final newEntities = <DxfEntity>[];

    for (final seg in result.wallContourSegments) {
      newEntities.add(
        DxfLine(
          p1: seg.$1,
          p2: seg.$2,
          layer: wallLayerName,
          colorIndex: wallColor,
          trueColor: result.bestGroup?.trueColor,
        ),
      );
    }

    // 5. Add centerline axis lines with DASHED linetype to document
    for (final axis in result.snappedCenterlines) {
      newEntities.add(
        DxfLine(
          p1: axis.$1,
          p2: axis.$2,
          layer: axisLayerName,
          colorIndex: 1,
          lineType: 'DASHED',
          lineTypeScale: 1.0,
        ),
      );
    }

    // 6. Mutate document entity lists
    try {
      document.entities.addAll(newEntities);
    } catch (_) {
      // List was unmodifiable (e.g. in test mock)
    }
    final modelList = document.layoutEntities['Model'];
    if (modelList != null) {
      try {
        modelList.addAll(newEntities);
      } catch (_) {}
    }

    // Invalidate spatial index so new entities are picked up
    document.spatialIndex = null;
  }

  // --- Internal Geometric & Grouping Methods ---

  static String _getUnitNameFromScale(double scale) {
    if ((scale - 1.0).abs() < 1e-4) return 'mm';
    if ((scale - 0.1).abs() < 1e-4) return 'cm';
    if ((scale - 0.001).abs() < 1e-5) return 'm';
    return 'units';
  }

  /// Extracts straight segments from document, grouped by `Layer##Color`.
  static Map<String, List<WallSegment>> _extractSegmentsByGroup(DxfDocument document) {
    final segmentsByGroup = <String, List<WallSegment>>{};
    final entities = document.layoutEntities['Model'] ?? document.entities;

    for (final entity in entities) {
      if (entity.isPaperSpace) continue;

      final layerObj = document.layers[entity.layer];
      final resolvedColorIndex = (entity.colorIndex != null &&
              entity.colorIndex != 256 &&
              entity.colorIndex != 0)
          ? entity.colorIndex
          : layerObj?.colorIndex ?? 7;
      final resolvedTrueColor = entity.trueColor ?? layerObj?.trueColor;

      if (entity is DxfLine) {
        _addSegmentIfValid(
          segmentsByGroup,
          entity.p1,
          entity.p2,
          entity.layer,
          resolvedColorIndex,
          resolvedTrueColor,
          entity,
        );
      } else if (entity is DxfLwPolyline) {
        final vertices = entity.vertices;
        if (vertices.length < 2) continue;
        for (int i = 0; i < vertices.length - 1; i++) {
          final v1 = vertices[i];
          final v2 = vertices[i + 1];
          // Only process straight polyline segments (ignore curved arcs with bulge != 0)
          if (v1.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              segmentsByGroup,
              Offset(v1.x, v1.y),
              Offset(v2.x, v2.y),
              entity.layer,
              resolvedColorIndex,
              resolvedTrueColor,
              entity,
            );
          }
        }
        if (entity.isClosed && vertices.length > 2) {
          final last = vertices.last;
          final first = vertices.first;
          if (last.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              segmentsByGroup,
              Offset(last.x, last.y),
              Offset(first.x, first.y),
              entity.layer,
              resolvedColorIndex,
              resolvedTrueColor,
              entity,
            );
          }
        }
      } else if (entity is DxfPolyline) {
        final vertices = entity.vertices;
        if (vertices.length < 2) continue;
        for (int i = 0; i < vertices.length - 1; i++) {
          final v1 = vertices[i];
          final v2 = vertices[i + 1];
          if (v1.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              segmentsByGroup,
              Offset(v1.x, v1.y),
              Offset(v2.x, v2.y),
              entity.layer,
              resolvedColorIndex,
              resolvedTrueColor,
              entity,
            );
          }
        }
        if (entity.isClosed && vertices.length > 2) {
          final last = vertices.last;
          final first = vertices.first;
          if (last.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              segmentsByGroup,
              Offset(last.x, last.y),
              Offset(first.x, first.y),
              entity.layer,
              resolvedColorIndex,
              resolvedTrueColor,
              entity,
            );
          }
        }
      }
    }

    return segmentsByGroup;
  }

  static void _addSegmentIfValid(
    Map<String, List<WallSegment>> map,
    Offset p1,
    Offset p2,
    String layer,
    int? colorIndex,
    int? trueColor,
    DxfEntity entity,
  ) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-4) return;

    // Normalize segment direction so start.dx < end.dx (or start.dy < end.dy if vertical)
    final Offset start;
    final Offset end;
    if (dx > 1e-7 || (dx.abs() <= 1e-7 && dy > 0)) {
      start = p1;
      end = p2;
    } else {
      start = p2;
      end = p1;
    }

    final double normDx = end.dx - start.dx;
    final double normDy = end.dy - start.dy;
    double angle = math.atan2(normDy, normDx);
    if (angle < 0) angle += math.pi;
    if (angle >= math.pi - 1e-6) angle = 0.0;

    // Normal vector n = (-sin, cos)
    final double cosA = math.cos(angle);
    final double sinA = math.sin(angle);
    final double offsetFromOrigin = -start.dx * sinA + start.dy * cosA;

    final seg = WallSegment(
      start: start,
      end: end,
      angleRad: angle,
      offsetFromOrigin: offsetFromOrigin,
      length: len,
      sourceLayer: layer,
      sourceColorIndex: colorIndex,
      sourceTrueColor: trueColor,
      sourceEntity: entity,
    );

    map.putIfAbsent(seg.groupKey, () => []).add(seg);
  }

  /// Tests scales: mm (1.0), cm (0.1), and m (0.001) to find which matches standard 25cm walls.
  static ({double scale, String unitName}) _autoDetectScale(
    Map<String, List<WallSegment>> segmentsByGroup,
    double targetThicknessMm,
    double thicknessToleranceMm,
    double minOverlapMm,
  ) {
    const candidateScales = [
      (scale: 1.0, unitName: 'mm'), // 250 mm -> 250 units
      (scale: 0.1, unitName: 'cm'), // 25 cm -> 25 units
      (scale: 0.001, unitName: 'm'), // 0.25 m -> 0.25 units
    ];

    double maxTotalOverlap = 0.0;
    var bestCandidate = candidateScales.first;

    for (final candidate in candidateScales) {
      final s = candidate.scale;
      final targetDist = targetThicknessMm * s;
      final tolerance = thicknessToleranceMm * s;
      final minOverlap = minOverlapMm * s;

      double candidateTotalOverlap = 0.0;

      for (final segments in segmentsByGroup.values) {
        if (segments.length < 2) continue;
        final pairs = _findParallelPairs(
          segments,
          targetDist,
          tolerance,
          minOverlap,
          quickCheckLimit: 40,
        );
        for (final p in pairs) {
          candidateTotalOverlap += p.overlapLength / s;
        }
      }

      if (candidateTotalOverlap > maxTotalOverlap) {
        maxTotalOverlap = candidateTotalOverlap;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }

  /// Merges touching or overlapping collinear segments in the same group.
  static List<WallSegment> _mergeCollinearSegments(
    List<WallSegment> segments,
    double toleranceCad,
  ) {
    if (segments.length < 2) return segments;

    final angleBuckets = _bucketByAngle(segments);
    final mergedList = <WallSegment>[];

    for (final bucket in angleBuckets) {
      if (bucket.length < 2) {
        mergedList.addAll(bucket);
        continue;
      }

      // Sort by perpendicular offset
      bucket.sort((a, b) => a.offsetFromOrigin.compareTo(b.offsetFromOrigin));

      // Sub-cluster collinear lines with same offset
      final List<List<WallSegment>> collinearClusters = [];
      List<WallSegment> currentCluster = [bucket.first];

      for (int i = 1; i < bucket.length; i++) {
        final prev = bucket[i - 1];
        final curr = bucket[i];
        if ((curr.offsetFromOrigin - prev.offsetFromOrigin).abs() <= toleranceCad * 0.5) {
          currentCluster.add(curr);
        } else {
          collinearClusters.add(currentCluster);
          currentCluster = [curr];
        }
      }
      collinearClusters.add(currentCluster);

      for (final cluster in collinearClusters) {
        if (cluster.length == 1) {
          mergedList.add(cluster.first);
          continue;
        }

        // Project onto common direction vector u
        final ref = cluster.first;
        final double cosA = math.cos(ref.angleRad);
        final double sinA = math.sin(ref.angleRad);

        // Sort intervals by tMin
        final intervals = cluster.map((s) {
          final t1 = s.start.dx * cosA + s.start.dy * sinA;
          final t2 = s.end.dx * cosA + s.end.dy * sinA;
          return (tMin: math.min(t1, t2), tMax: math.max(t1, t2), seg: s);
        }).toList()
          ..sort((a, b) => a.tMin.compareTo(b.tMin));

        double curTMin = intervals.first.tMin;
        double curTMax = intervals.first.tMax;
        WallSegment curRefSeg = intervals.first.seg;

        for (int i = 1; i < intervals.length; i++) {
          final next = intervals[i];
          // If intervals touch, overlap, or have gap <= tolerance: merge!
          if (next.tMin <= curTMax + toleranceCad) {
            curTMax = math.max(curTMax, next.tMax);
          } else {
            // Commit previous merged segment
            final startPt = Offset(
              curTMin * cosA - curRefSeg.offsetFromOrigin * sinA,
              curTMin * sinA + curRefSeg.offsetFromOrigin * cosA,
            );
            final endPt = Offset(
              curTMax * cosA - curRefSeg.offsetFromOrigin * sinA,
              curTMax * sinA + curRefSeg.offsetFromOrigin * cosA,
            );
            mergedList.add(
              WallSegment(
                start: startPt,
                end: endPt,
                angleRad: curRefSeg.angleRad,
                offsetFromOrigin: curRefSeg.offsetFromOrigin,
                length: curTMax - curTMin,
                sourceLayer: curRefSeg.sourceLayer,
                sourceColorIndex: curRefSeg.sourceColorIndex,
                sourceTrueColor: curRefSeg.sourceTrueColor,
                sourceEntity: curRefSeg.sourceEntity,
              ),
            );
            curTMin = next.tMin;
            curTMax = next.tMax;
            curRefSeg = next.seg;
          }
        }

        // Commit final interval
        final startPt = Offset(
          curTMin * cosA - curRefSeg.offsetFromOrigin * sinA,
          curTMin * sinA + curRefSeg.offsetFromOrigin * cosA,
        );
        final endPt = Offset(
          curTMax * cosA - curRefSeg.offsetFromOrigin * sinA,
          curTMax * sinA + curRefSeg.offsetFromOrigin * cosA,
        );
        mergedList.add(
          WallSegment(
            start: startPt,
            end: endPt,
            angleRad: curRefSeg.angleRad,
            offsetFromOrigin: curRefSeg.offsetFromOrigin,
            length: curTMax - curTMin,
            sourceLayer: curRefSeg.sourceLayer,
            sourceColorIndex: curRefSeg.sourceColorIndex,
            sourceTrueColor: curRefSeg.sourceTrueColor,
            sourceEntity: curRefSeg.sourceEntity,
          ),
        );
      }
    }

    return mergedList;
  }

  /// Buckets segments by normalized angle (within tolerance +-0.5 deg ~= 0.0087 rad).
  static List<List<WallSegment>> _bucketByAngle(List<WallSegment> segments) {
    const double angleTolerance = 0.5 * math.pi / 180.0; // 0.5 degrees
    final buckets = <List<WallSegment>>[];

    for (final seg in segments) {
      bool placed = false;
      for (final bucket in buckets) {
        final refAngle = bucket.first.angleRad;
        double diff = (seg.angleRad - refAngle).abs();
        if (diff > math.pi - angleTolerance) {
          diff = (diff - math.pi).abs();
        }
        if (diff <= angleTolerance) {
          bucket.add(seg);
          placed = true;
          break;
        }
      }
      if (!placed) {
        buckets.add([seg]);
      }
    }

    return buckets;
  }

  /// Finds parallel pairs in O(N log N) time by sorting on perpendicular offset.
  static List<WallPairCandidate> _findParallelPairs(
    List<WallSegment> segments,
    double targetDistanceCad,
    double toleranceCad,
    double minOverlapCad, {
    int? quickCheckLimit,
  }) {
    final pairs = <WallPairCandidate>[];
    final angleBuckets = _bucketByAngle(segments);

    for (final bucket in angleBuckets) {
      if (bucket.length < 2) continue;

      // Sort by perpendicular offset from origin
      bucket.sort((a, b) => a.offsetFromOrigin.compareTo(b.offsetFromOrigin));

      final n = bucket.length;
      for (int i = 0; i < n; i++) {
        final s1 = bucket[i];
        final minOffset = s1.offsetFromOrigin + targetDistanceCad - toleranceCad;
        final maxOffset = s1.offsetFromOrigin + targetDistanceCad + toleranceCad;

        // Binary search for first index with offset >= minOffset
        int low = i + 1;
        int high = n - 1;
        int startIdx = n;
        while (low <= high) {
          final mid = (low + high) >> 1;
          if (bucket[mid].offsetFromOrigin >= minOffset) {
            startIdx = mid;
            high = mid - 1;
          } else {
            low = mid + 1;
          }
        }

        // Scan partners in [minOffset, maxOffset]
        for (int j = startIdx; j < n; j++) {
          final s2 = bucket[j];
          if (s2.offsetFromOrigin > maxOffset) break;

          final double dist = (s2.offsetFromOrigin - s1.offsetFromOrigin).abs();

          // Calculate overlap along common direction
          final double cosA = math.cos(s1.angleRad);
          final double sinA = math.sin(s1.angleRad);

          final t1A = s1.start.dx * cosA + s1.start.dy * sinA;
          final t1B = s1.end.dx * cosA + s1.end.dy * sinA;
          final t1Min = math.min(t1A, t1B);
          final t1Max = math.max(t1A, t1B);

          final t2A = s2.start.dx * cosA + s2.start.dy * sinA;
          final t2B = s2.end.dx * cosA + s2.end.dy * sinA;
          final t2Min = math.min(t2A, t2B);
          final t2Max = math.max(t2A, t2B);

          final tStart = math.max(t1Min, t2Min);
          final tEnd = math.min(t1Max, t2Max);
          final overlap = tEnd - tStart;

          if (overlap >= minOverlapCad) {
            final double midOffset = (s1.offsetFromOrigin + s2.offsetFromOrigin) / 2.0;
            final centerStart = Offset(
              tStart * cosA - midOffset * sinA,
              tStart * sinA + midOffset * cosA,
            );
            final centerEnd = Offset(
              tEnd * cosA - midOffset * sinA,
              tEnd * sinA + midOffset * cosA,
            );

            pairs.add(
              WallPairCandidate(
                segmentA: s1,
                segmentB: s2,
                perpendicularDistance: dist,
                overlapLength: overlap,
                centerlineStart: centerStart,
                centerlineEnd: centerEnd,
              ),
            );

            if (quickCheckLimit != null && pairs.length >= quickCheckLimit) {
              return pairs;
            }
          }
        }
      }
    }

    return pairs;
  }

  /// Bridges collinear gaps (up to [maxBridgeGapCad] = 2.50 m) across door/window openings.
  static List<(Offset, Offset)> _bridgeOpenings(
    List<(Offset, Offset)> rawAxes,
    double maxBridgeGapCad,
    double toleranceCad,
  ) {
    if (rawAxes.length < 2) return rawAxes;

    // Convert raw lines to WallSegments for clustering
    final segs = <WallSegment>[];
    for (final line in rawAxes) {
      final p1 = line.$1;
      final p2 = line.$2;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-4) continue;

      double angle = math.atan2(dy, dx);
      if (angle < 0) angle += math.pi;
      if (angle >= math.pi - 1e-6) angle = 0.0;

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final offset = -p1.dx * sinA + p1.dy * cosA;

      segs.add(
        WallSegment(
          start: p1,
          end: p2,
          angleRad: angle,
          offsetFromOrigin: offset,
          length: len,
          sourceLayer: 'AXIS',
        ),
      );
    }

    final angleBuckets = _bucketByAngle(segs);
    final bridgedAxes = <(Offset, Offset)>[];

    for (final bucket in angleBuckets) {
      if (bucket.length == 1) {
        bridgedAxes.add((bucket.first.start, bucket.first.end));
        continue;
      }

      bucket.sort((a, b) => a.offsetFromOrigin.compareTo(b.offsetFromOrigin));

      final List<List<WallSegment>> collinearGroups = [];
      List<WallSegment> curGroup = [bucket.first];

      for (int i = 1; i < bucket.length; i++) {
        final prev = bucket[i - 1];
        final curr = bucket[i];
        if ((curr.offsetFromOrigin - prev.offsetFromOrigin).abs() <= toleranceCad) {
          curGroup.add(curr);
        } else {
          collinearGroups.add(curGroup);
          curGroup = [curr];
        }
      }
      collinearGroups.add(curGroup);

      for (final group in collinearGroups) {
        if (group.length == 1) {
          bridgedAxes.add((group.first.start, group.first.end));
          continue;
        }

        final ref = group.first;
        final double cosA = math.cos(ref.angleRad);
        final double sinA = math.sin(ref.angleRad);

        final intervals = group.map((s) {
          final t1 = s.start.dx * cosA + s.start.dy * sinA;
          final t2 = s.end.dx * cosA + s.end.dy * sinA;
          return (tMin: math.min(t1, t2), tMax: math.max(t1, t2), seg: s);
        }).toList()
          ..sort((a, b) => a.tMin.compareTo(b.tMin));

        double curTMin = intervals.first.tMin;
        double curTMax = intervals.first.tMax;
        double curOffset = intervals.first.seg.offsetFromOrigin;

        for (int i = 1; i < intervals.length; i++) {
          final next = intervals[i];
          final gap = next.tMin - curTMax;

          // If gap <= maxBridgeGapCad, bridge through the door/window opening!
          if (gap <= maxBridgeGapCad) {
            curTMax = math.max(curTMax, next.tMax);
            curOffset = (curOffset + next.seg.offsetFromOrigin) / 2.0;
          } else {
            // Commit previous segment
            bridgedAxes.add(
              (
                Offset(curTMin * cosA - curOffset * sinA, curTMin * sinA + curOffset * cosA),
                Offset(curTMax * cosA - curOffset * sinA, curTMax * sinA + curOffset * cosA),
              ),
            );
            curTMin = next.tMin;
            curTMax = next.tMax;
            curOffset = next.seg.offsetFromOrigin;
          }
        }

        // Commit trailing segment
        bridgedAxes.add(
          (
            Offset(curTMin * cosA - curOffset * sinA, curTMin * sinA + curOffset * cosA),
            Offset(curTMax * cosA - curOffset * sinA, curTMax * sinA + curOffset * cosA),
          ),
        );
      }
    }

    return bridgedAxes;
  }

  /// Snaps L-corners to common intersection and T-junctions perpendicularly.
  static List<(Offset, Offset)> _snapCornersAndJunctions(
    List<(Offset, Offset)> axes,
    double snapRadiusCad,
  ) {
    if (axes.length < 2) return axes;

    // Work on mutable list of endpoints
    final lines = axes.map((a) => (p1: a.$1, p2: a.$2)).toList();

    // 1. L-corners: Intersect endpoints within snapRadiusCad
    for (int i = 0; i < lines.length; i++) {
      for (int j = i + 1; j < lines.length; j++) {
        final a = lines[i];
        final b = lines[j];

        // Check if nearly parallel (angle difference < 15 deg or > 165 deg)
        final dxA = a.p2.dx - a.p1.dx;
        final dyA = a.p2.dy - a.p1.dy;
        final dxB = b.p2.dx - b.p1.dx;
        final dyB = b.p2.dy - b.p1.dy;
        final lenA = math.sqrt(dxA * dxA + dyA * dyA);
        final lenB = math.sqrt(dxB * dxB + dyB * dyB);
        if (lenA < 1e-4 || lenB < 1e-4) continue;

        final dot = (dxA * dxB + dyA * dyB) / (lenA * lenB);
        if (dot.abs() > 0.96) continue; // Parallel, skip L-corner

        // Check all 4 endpoint pairs
        final endpointPairs = [
          (ptA: a.p1, isAStart: true, ptB: b.p1, isBStart: true),
          (ptA: a.p1, isAStart: true, ptB: b.p2, isBStart: false),
          (ptA: a.p2, isAStart: false, ptB: b.p1, isBStart: true),
          (ptA: a.p2, isAStart: false, ptB: b.p2, isBStart: false),
        ];

        for (final pair in endpointPairs) {
          if ((pair.ptA - pair.ptB).distance <= snapRadiusCad) {
            final intersection = _intersectLines(a.p1, a.p2, b.p1, b.p2);
            if (intersection != null &&
                (intersection - pair.ptA).distance <= snapRadiusCad * 1.5 &&
                (intersection - pair.ptB).distance <= snapRadiusCad * 1.5) {
              // Update line A endpoint
              lines[i] = (
                p1: pair.isAStart ? intersection : a.p1,
                p2: pair.isAStart ? a.p2 : intersection,
              );
              // Update line B endpoint
              lines[j] = (
                p1: pair.isBStart ? intersection : b.p1,
                p2: pair.isBStart ? b.p2 : intersection,
              );
              break;
            }
          }
        }
      }
    }

    // 2. T-junctions: Snap interior wall endpoints perpendicularly onto intersecting lines
    for (int i = 0; i < lines.length; i++) {
      for (int j = 0; j < lines.length; j++) {
        if (i == j) continue;
        final a = lines[i];
        final b = lines[j];

        // Check if line A's start or end is within snapRadiusCad to segment B
        void checkAndSnapT(Offset pt, bool isStart) {
          final double abX = b.p2.dx - b.p1.dx;
          final double abY = b.p2.dy - b.p1.dy;
          final double lenSq = abX * abX + abY * abY;
          if (lenSq < 1e-6) return;

          final double t =
              (((pt.dx - b.p1.dx) * abX + (pt.dy - b.p1.dy) * abY) / lenSq).clamp(0.0, 1.0);
          final Offset proj = Offset(b.p1.dx + t * abX, b.p1.dy + t * abY);
          final double dist = (pt - proj).distance;

          // Interior T-junction: t in (0.05, 0.95) so it's not the end
          if (dist <= snapRadiusCad && t > 0.05 && t < 0.95) {
            lines[i] = (
              p1: isStart ? proj : a.p1,
              p2: isStart ? a.p2 : proj,
            );
          }
        }

        checkAndSnapT(a.p1, true);
        checkAndSnapT(a.p2, false);
      }
    }

    return lines.map((l) => (l.p1, l.p2)).toList();
  }

  /// Calculates intersection point of two infinite 2D lines.
  static Offset? _intersectLines(Offset a1, Offset a2, Offset b1, Offset b2) {
    final double x1 = a1.dx;
    final double y1 = a1.dy;
    final double x2 = a2.dx;
    final double y2 = a2.dy;

    final double x3 = b1.dx;
    final double y3 = b1.dy;
    final double x4 = b2.dx;
    final double y4 = b2.dy;

    final double denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 1e-9) return null; // Parallel or collinear

    final double t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    return Offset(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
  }
}
