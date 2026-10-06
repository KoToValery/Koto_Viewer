import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';

/// Intelligent Wall & Centerline Axis Detector for CAD / BIM drawings.
///
/// Features:
/// 1. Automatic scale detection (250 mm / 25 cm / 0.25 m) resilient to drawing bounds.
/// 2. Segment extraction grouped by (Layer, Color), separating brickwork from insulation.
/// 3. Robust origin-invariant perpendicular distance calculation (eliminating coordinate drift).
/// 4. O(N log N) parallel pair detection sorted by perpendicular offset.
/// 5. Structural building scoring (prioritizing orthogonal room layouts over border/title block margins).
/// 6. Opening bridging across doors and windows (gaps <= 2.50 m).
/// 7. Topological corner snapping (L-corners and T-junctions).
/// 8. Clean layer generation (WALLS_250 and AXIS dashed).
class WallAxisDetector {
  const WallAxisDetector._();

  /// Default wall thickness in millimeters (standard European masonry wall: 25 cm).
  static const double defaultWallThicknessMm = 250.0;
  /// Generous tolerance (+-55 mm) to comfortably handle 20 cm concrete walls (шайби),
  /// 24-25 cm masonry (четворка/Porotherm), and 30 cm walls with plaster.
  static const double defaultThicknessToleranceMm = 55.0;
  /// Partition wall thickness in millimeters (standard European interior wall: 12 cm).
  static const double partitionWallThicknessMm = 120.0;
  /// Tolerance for partition walls (+-35 mm: 85 mm to 155 mm).
  static const double partitionThicknessToleranceMm = 35.0;
  static const double defaultMinOverlapMm = 50.0; // 5 cm min overlap
  static const double defaultMaxOpeningBridgeGapMm = 2500.0; // 2.50 meters
  static const double defaultCornerSnapRadiusMm = 350.0; // 35 cm

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
    // Step 1: Extract all straight segments partitioned by Layer (including blocks)
    final segmentsByLayer = _extractSegments(document);
    if (segmentsByLayer.isEmpty) {
      return WallAxisDetectionResult.empty;
    }

    // Step 2: Determine unit scale factor (CAD units per mm)
    final ({double scale, String unitName}) scaleInfo = forceScaleFactor != null
        ? (scale: forceScaleFactor, unitName: _getUnitNameFromScale(forceScaleFactor))
        : _autoDetectScale(
            document,
            segmentsByLayer,
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

    // Step 3: Run pair detection on each Layer and rank them
    final List<LayerColorGroupResult> evaluatedGroups = [];

    for (final entry in segmentsByLayer.entries) {
      final segments = entry.value;
      if (segments.length < 2) continue;

      final firstSeg = segments.first;
      final layerName = firstSeg.sourceLayer;

      // Collinear pre-merging to clean broken drafts & duplicates
      final mergedSegments = _mergeCollinearSegments(segments, toleranceCad);

      // Detect parallel pairs at target distance (250mm)
      final pairs25 = _findParallelPairs(
        mergedSegments,
        targetDistCad,
        toleranceCad,
        minOverlapCad,
        documentBounds: document.bounds,
      );

      // Detect partition wall pairs at 120mm (12cm)
      final pairs12 = _findParallelPairs(
        mergedSegments,
        partitionWallThicknessMm * scale,
        partitionThicknessToleranceMm * scale,
        minOverlapCad,
        documentBounds: document.bounds,
      );

      // Avoid duplicate pairs if tolerances overlap
      final pairs = <WallPairCandidate>[...pairs25];
      for (final p12 in pairs12) {
        final isDup = pairs.any((p) =>
            ((p.centerlineStart - p12.centerlineStart).distance < toleranceCad &&
             (p.centerlineEnd - p12.centerlineEnd).distance < toleranceCad) ||
            ((p.centerlineStart - p12.centerlineEnd).distance < toleranceCad &&
             (p.centerlineEnd - p12.centerlineStart).distance < toleranceCad));
        if (!isDup) {
          pairs.add(p12);
        }
      }

      if (pairs.isNotEmpty) {
        double totalOverlap = 0.0;
        int horizontalCount = 0;
        int verticalCount = 0;

        for (final p in pairs) {
          totalOverlap += p.overlapLength;
          final angleDeg = p.segmentA.angleRad * 180.0 / math.pi;
          if (angleDeg < 30.0 || angleDeg > 150.0) {
            horizontalCount++;
          } else if (angleDeg > 60.0 && angleDeg < 120.0) {
            verticalCount++;
          }
        }

        // Structural building multiplier: real buildings have walls in BOTH directions (rooms)
        double layoutBonus = 1.0;
        if (horizontalCount > 0 && verticalCount > 0) {
          layoutBonus = 2.5; // Strong boost for real room layouts
        }

        // Network connectivity bonus: real building walls intersect or meet perpendicular walls at corners/T-junctions
        int cornerConnections = 0;
        for (final p1 in pairs) {
          final a1 = p1.segmentA.angleRad * 180.0 / math.pi;
          for (final p2 in pairs) {
            if (p1 == p2) continue;
            final a2 = p2.segmentA.angleRad * 180.0 / math.pi;
            if (((a1 - a2).abs() - 90.0).abs() <= 15.0) {
              final d1 = (p1.centerlineStart - p2.centerlineStart).distance;
              final d2 = (p1.centerlineStart - p2.centerlineEnd).distance;
              final d3 = (p1.centerlineEnd - p2.centerlineStart).distance;
              final d4 = (p1.centerlineEnd - p2.centerlineEnd).distance;
              if (d1 <= snapRadiusCad || d2 <= snapRadiusCad || d3 <= snapRadiusCad || d4 <= snapRadiusCad) {
                cornerConnections++;
                break;
              }
            }
          }
        }
        final connRatio = pairs.isNotEmpty ? (cornerConnections / pairs.length) : 0.0;
        final networkBonus = 1.0 + (connRatio * 1.5);

        // Check soft keywords (title block, sheet border, furniture, hatch -> penalty)
        double keywordMultiplier = 1.0;
        final lowerName = layerName.toLowerCase();
        if (_isClutterOrBorderLayer(lowerName)) {
          keywordMultiplier = 0.1; // Soft penalty for title block, format, borders
        } else if (_isStructuralLayer(lowerName)) {
          keywordMultiplier = 1.5; // Soft boost for wall layers
        }

        // Score: combines total length, pair count diversity, layout quality, and topological connectivity
        final pairFactor = 1.0 + math.sqrt(pairs.length);
        final score = totalOverlap * pairFactor * layoutBonus * networkBonus * keywordMultiplier;

        final firstSeg = segments.first;
        evaluatedGroups.add(
          LayerColorGroupResult(
            layerName: layerName,
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

    // Select the best group, plus any secondary wall groups that have significant scores
    final bestGroup = evaluatedGroups.first;
    final activeGroups = <LayerColorGroupResult>[bestGroup];

    for (int i = 1; i < evaluatedGroups.length; i++) {
      final g = evaluatedGroups[i];
      // Include other high-scoring wall layers (e.g. interior + exterior walls, 12cm partition walls)
      // Geometry-driven without rigid keyword gating: any wall candidate group with >= 25% score is included
      const double scoreThreshold = 0.25;
      if (g.score >= bestGroup.score * scoreThreshold && g.pairCount >= 2) {
        activeGroups.add(g);
      }
    }

    // Step 4: Collect raw centerlines and closed wall contour segments with opening jamb caps
    final rawCenterlines = <(Offset, Offset)>[];
    final wallContourSegments = <(Offset, Offset)>[];
    final closureSegments = <(Offset, Offset)>[];

    final allPairs = <WallPairCandidate>[];
    for (final group in activeGroups) {
      allPairs.addAll(group.wallPairs);
    }

    for (final group in activeGroups) {
      for (final pair in group.wallPairs) {
        rawCenterlines.add((pair.centerlineStart, pair.centerlineEnd));
        _collectWallContourWithEndCaps(
          pair,
          allPairs,
          wallContourSegments,
          closureSegments,
        );
      }
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
      selectedWallPairs: allPairs,
      wallContourSegments: wallContourSegments,
      closureSegments: closureSegments,
    );
  }

  /// Converts detected snapped centerline segments into unified, continuous [StructuralGridAxis] elements.
  ///
  /// Merges collinear wall centerlines along the same structural alignment into single continuous axes,
  /// extends them past the entire building perimeter (by default 1.20 m) so end bubbles sit neatly aligned outside walls,
  /// and sequences them with standard engineering naming (1, 2, 3... for vertical, А, Б, В... for horizontal).
  static List<StructuralGridAxis> convertToStructuralGridAxes(
    List<(Offset, Offset)> centerlines, {
    required bool isBulgarian,
    required double scale,
    double extensionM = 1.20,
    double collinearToleranceMm = 50.0,
    double minTotalWallLengthM = 0.30,
  }) {
    if (centerlines.isEmpty) return const [];

    final extensionCad = (extensionM * 1000.0) * scale;
    final collinearTolCad = collinearToleranceMm * scale;
    final minTotalWallLengthCad = (minTotalWallLengthM * 1000.0) * scale;

    // 1. Calculate the overall bounding envelope of all detected centerlines
    double bMinX = double.infinity;
    double bMaxX = -double.infinity;
    double bMinY = double.infinity;
    double bMaxY = -double.infinity;

    for (final line in centerlines) {
      final p1 = line.$1;
      final p2 = line.$2;
      bMinX = math.min(bMinX, math.min(p1.dx, p2.dx));
      bMaxX = math.max(bMaxX, math.max(p1.dx, p2.dx));
      bMinY = math.min(bMinY, math.min(p1.dy, p2.dy));
      bMaxY = math.max(bMaxY, math.max(p1.dy, p2.dy));
    }

    final envelopeCorners = [
      Offset(bMinX, bMinY),
      Offset(bMaxX, bMinY),
      Offset(bMaxX, bMaxY),
      Offset(bMinX, bMaxY),
    ];

    // 2. Angle bucketing (within +-1.5 degrees)
    const angleTolerance = 1.5 * math.pi / 180.0;
    final buckets = <List<(Offset, Offset)>>[];

    for (final line in centerlines) {
      final p1 = line.$1;
      final p2 = line.$2;
      if ((p2 - p1).distance < 1e-4) continue;

      var angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      if (angle < 0) angle += math.pi;
      if (angle >= math.pi - 1e-4) angle = 0.0;

      bool placed = false;
      for (final bucket in buckets) {
        final b0 = bucket.first;
        var bAngle = math.atan2(b0.$2.dy - b0.$1.dy, b0.$2.dx - b0.$1.dx);
        if (bAngle < 0) bAngle += math.pi;
        if (bAngle >= math.pi - 1e-4) bAngle = 0.0;

        double diff = (angle - bAngle).abs();
        if (diff > math.pi - angleTolerance) diff = (diff - math.pi).abs();
        if (diff <= angleTolerance) {
          bucket.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) buckets.add([line]);
    }

    final rawAxes = <StructuralGridAxis>[];
    int axisCounter = 0;

    for (final bucket in buckets) {
      final b0 = bucket.first;
      var refAngle = math.atan2(b0.$2.dy - b0.$1.dy, b0.$2.dx - b0.$1.dx);
      if (refAngle < 0) refAngle += math.pi;
      if (refAngle >= math.pi - 1e-4) refAngle = 0.0;

      // Snap near horizontal / vertical to exact 0.0 and pi/2
      if (refAngle < 2.0 * math.pi / 180.0 || (refAngle - math.pi).abs() < 2.0 * math.pi / 180.0) {
        refAngle = 0.0;
      } else if ((refAngle - math.pi / 2.0).abs() < 2.0 * math.pi / 180.0) {
        refAngle = math.pi / 2.0;
      }

      final cosA = math.cos(refAngle);
      final sinA = math.sin(refAngle);

      // Project the whole building envelope onto the axis direction vector u = (cosA, sinA)
      double envMinT = double.infinity;
      double envMaxT = -double.infinity;
      for (final corner in envelopeCorners) {
        final t = corner.dx * cosA + corner.dy * sinA;
        envMinT = math.min(envMinT, t);
        envMaxT = math.max(envMaxT, t);
      }

      // Compute perpendicular offset d and directional range [tMin, tMax]
      final withD = bucket.map((line) {
        final mid = (line.$1 + line.$2) / 2.0;
        final d = -mid.dx * sinA + mid.dy * cosA;
        final t1 = line.$1.dx * cosA + line.$1.dy * sinA;
        final t2 = line.$2.dx * cosA + line.$2.dy * sinA;
        final len = (line.$2 - line.$1).distance;
        return (line: line, d: d, length: len, tMin: math.min(t1, t2), tMax: math.max(t1, t2));
      }).toList()
        ..sort((a, b) => a.d.compareTo(b.d));

      // Cluster collinear lines along the same alignment
      final initialClusters = <List<({(Offset, Offset) line, double d, double length, double tMin, double tMax})>>[];
      var curCluster = [withD.first];
      double clusterBaseD = withD.first.d;
      for (int i = 1; i < withD.length; i++) {
        if ((withD[i].d - clusterBaseD).abs() <= collinearTolCad) {
          curCluster.add(withD[i]);
        } else {
          initialClusters.add(curCluster);
          curCluster = [withD[i]];
          clusterBaseD = withD[i].d;
        }
      }
      initialClusters.add(curCluster);

      // Merge clusters whose weighted average offsets are within collinearTolCad
      final clusters = <List<({(Offset, Offset) line, double d, double length, double tMin, double tMax})>>[];
      for (final c in initialClusters) {
        if (clusters.isEmpty) {
          clusters.add(c);
        } else {
          final prev = clusters.last;
          final prevAvgD = prev.fold<double>(0.0, (sum, it) => sum + it.d * it.length) /
              prev.fold<double>(0.0, (sum, it) => sum + it.length);
          final curAvgD = c.fold<double>(0.0, (sum, it) => sum + it.d * it.length) /
              c.fold<double>(0.0, (sum, it) => sum + it.length);
          if ((curAvgD - prevAvgD).abs() <= collinearTolCad) {
            prev.addAll(c);
          } else {
            clusters.add(c);
          }
        }
      }

      for (final cluster in clusters) {
        double totalLen = 0.0;
        double weightedD = 0.0;
        double clusterMinT = double.infinity;
        double clusterMaxT = -double.infinity;

        for (final item in cluster) {
          totalLen += item.length;
          weightedD += item.d * item.length;
          clusterMinT = math.min(clusterMinT, item.tMin);
          clusterMaxT = math.max(clusterMaxT, item.tMax);
        }

        // Filter out tiny artifacts below minimum wall length
        if (totalLen < minTotalWallLengthCad && minTotalWallLengthCad > 0) {
          continue;
        }

        final avgD = totalLen > 0 ? weightedD / totalLen : cluster.first.d;

        // In structural BIM drawings, grid axes span across the entire building envelope,
        // with end bubbles sitting aligned outside the building perimeter.
        final tStart = math.min(envMinT, clusterMinT) - extensionCad;
        final tEnd = math.max(envMaxT, clusterMaxT) + extensionCad;

        final startPt = Offset(
          tStart * cosA - avgD * sinA,
          tStart * sinA + avgD * cosA,
        );
        final endPt = Offset(
          tEnd * cosA - avgD * sinA,
          tEnd * sinA + avgD * cosA,
        );

        axisCounter++;
        rawAxes.add(
          StructuralGridAxis(
            id: 'axis_auto_${axisCounter}_${DateTime.now().millisecondsSinceEpoch}',
            name: '$axisCounter',
            start: startPt,
            end: endPt,
            bubbleAtStart: true,
            bubbleAtEnd: true,
          ),
        );
      }
    }

    return resequenceGridAxes(rawAxes, isBulgarian: isBulgarian);
  }

  /// Injects cleaned wall contours into [document] in layer [wallLayerName] (default 'WALLS_250'),
  /// isolating structural masonry and hiding clutter layers.
  ///
  /// Note: Grid axes are NOT injected as static CAD drawing lines into [document].
  /// Instead, they are generated dynamically as native interactive [StructuralGridAxis] elements
  /// inside the BIM module ([StructuralDesignerScreen]) via [convertToStructuralGridAxes]
  /// and stored in [StructuralProjectStorey.gridAxes].
  static void applyToDocument(
    DxfDocument document,
    WallAxisDetectionResult result, {
    String wallLayerName = 'WALLS_250',
    String? axisLayerName,
    bool isBulgarian = true,
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

    // 3. Remove any previously injected entities for wallLayerName or AXIS
    try {
      document.entities.removeWhere(
        (e) =>
            e.layer == wallLayerName ||
            e.layer == 'AXIS' ||
            (axisLayerName != null && e.layer == axisLayerName),
      );
    } catch (_) {}

    // Ensure AXIS layer does not contain static CAD entities in underlay
    if (document.layers.containsKey('AXIS')) {
      document.layers['AXIS']?.isVisible = false;
    }
    if (axisLayerName != null && document.layers.containsKey(axisLayerName)) {
      document.layers[axisLayerName]?.isVisible = false;
    }

    // 4. Add wall contour lines to document
    final newEntities = <DxfEntity>[];

    // 4a. Add wall contour lines to wallLayerName (e.g. WALLS_250)
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

    // 4b. Inject transverse closing caps directly into the ORIGINAL wall layer
    // (e.g. 'стени'), so walls are closed when viewing the architectural underlay!
    final origWallLayer = result.bestGroup?.layerName;
    if (origWallLayer != null && origWallLayer != wallLayerName && document.layers.containsKey(origWallLayer)) {
      final caps = result.closureSegments.isNotEmpty ? result.closureSegments : result.wallContourSegments;
      for (final cap in caps) {
        bool exists = false;
        for (final e in document.entities) {
          if (e.layer == origWallLayer && e is DxfLine) {
            final d1 = (e.p1 - cap.$1).distance + (e.p2 - cap.$2).distance;
            final d2 = (e.p1 - cap.$2).distance + (e.p2 - cap.$1).distance;
            if (d1 < 1.0 || d2 < 1.0) {
              exists = true;
              break;
            }
          }
        }
        if (!exists) {
          newEntities.add(
            DxfLine(
              p1: cap.$1,
              p2: cap.$2,
              layer: origWallLayer,
              colorIndex: wallColor,
              trueColor: result.bestGroup?.trueColor,
            ),
          );
        }
      }
    }

    // 5. Mutate document entity lists
    try {
      document.entities.addAll(newEntities);
    } catch (_) {
      // List was unmodifiable (e.g. in test mock)
    }
    final modelList = document.layoutEntities['Model'];
    if (modelList != null) {
      try {
        modelList.removeWhere(
          (e) =>
              e.layer == wallLayerName ||
              e.layer == 'AXIS' ||
              (axisLayerName != null && e.layer == axisLayerName),
        );
        modelList.addAll(newEntities);
      } catch (_) {}
    }

    // Invalidate spatial index so new entities are picked up
    document.spatialIndex = null;
  }

  /// Extracts or reconstructs [StructuralGridAxis] elements from document's grid axis layer ([axisLayerName]),
  /// matching lines with adjacent bubble text labels.
  static List<StructuralGridAxis> extractGridAxesFromDocument(
    DxfDocument document, {
    String axisLayerName = 'AXIS',
    bool isBulgarian = true,
  }) {
    final entities = document.layoutEntities['Model'] ?? document.entities;
    final axisLines = entities
        .whereType<DxfLine>()
        .where((l) => l.layer == axisLayerName || l.layer == 'AXIS')
        .toList();

    if (axisLines.isEmpty) return const [];

    final axisTexts = entities
        .whereType<DxfText>()
        .where((t) => t.layer == axisLayerName || t.layer == 'AXIS')
        .toList();

    final result = <StructuralGridAxis>[];
    int idx = 0;

    for (final line in axisLines) {
      idx++;
      String name = '$idx';
      double bestDist = double.infinity;
      for (final txt in axisTexts) {
        final d1 = (txt.insertPoint - line.p1).distance;
        final d2 = (txt.insertPoint - line.p2).distance;
        final d = math.min(d1, d2);
        if (d < bestDist && d < 2000.0) {
          bestDist = d;
          name = txt.text;
        }
      }

      result.add(
        StructuralGridAxis(
          id: 'axis_imported_${idx}_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          start: line.p1,
          end: line.p2,
          bubbleAtStart: true,
          bubbleAtEnd: true,
        ),
      );
    }

    return resequenceGridAxes(result, isBulgarian: isBulgarian);
  }

  // --- Internal Geometric & Grouping Methods ---

  static bool _isClutterOrBorderLayer(String lowerName) {
    const clutter = [
      'антетка', 'antetka', 'рамка', 'ramka', 'border', 'title',
      'sheet', 'лист', 'format', 'формат', 'stamp', 'печат',
      'defpoints', 'dim', 'размер', 'hatch', 'штрих',
      'furn', 'мебел', 'text', 'текст',
    ];
    for (final kw in clutter) {
      if (lowerName.contains(kw)) return true;
    }
    return false;
  }

  static bool _isStructuralLayer(String lowerName) {
    const structural = [
      'wall', 'стена', 'стен', 'stena', 'zid', 'masonry', 'mason', 'структура', 'констр',
      '12', 'прегр', 'pregr', 'part', 'partition', 'вътр', 'interior'
    ];
    for (final kw in structural) {
      if (lowerName.contains(kw)) return true;
    }
    return false;
  }

  static String _getUnitNameFromScale(double scale) {
    if ((scale - 1.0).abs() < 1e-4) return 'mm';
    if ((scale - 0.1).abs() < 1e-4) return 'cm';
    if ((scale - 0.001).abs() < 1e-5) return 'm';
    return 'units';
  }

  @visibleForTesting
  static Map<String, List<WallSegment>> extractSegmentsForTesting(DxfDocument document) =>
      _extractSegments(document);

  /// Extracts straight segments from document, grouped primarily by Layer.
  /// Unpacks block references (INSERT) to ensure block geometry is fully captured.
  static Map<String, List<WallSegment>> _extractSegments(DxfDocument document) {
    final segmentsByLayer = <String, List<WallSegment>>{};
    final entities = document.layoutEntities['Model'] ?? document.entities;

    for (final entity in entities) {
      if (entity.isPaperSpace) continue;

      if (entity is DxfInsert) {
        _extractSegmentsFromInsert(document, entity, segmentsByLayer, depth: 0);
      } else {
        _extractSegmentsFromEntity(document, entity, segmentsByLayer);
      }
    }

    return segmentsByLayer;
  }

  static void _extractSegmentsFromEntity(
    DxfDocument document,
    DxfEntity entity,
    Map<String, List<WallSegment>> map,
  ) {
    final layerObj = document.layers[entity.layer];
    final resolvedColorIndex = (entity.colorIndex != null &&
            entity.colorIndex != 256 &&
            entity.colorIndex != 0)
        ? entity.colorIndex
        : layerObj?.colorIndex ?? 7;
    final resolvedTrueColor = entity.trueColor ?? layerObj?.trueColor;

    if (entity is DxfLine) {
      _addSegmentIfValid(
        map,
        entity.p1,
        entity.p2,
        entity.layer,
        resolvedColorIndex,
        resolvedTrueColor,
        entity,
      );
    } else if (entity is DxfLwPolyline) {
      final vertices = entity.vertices;
      if (vertices.length >= 2) {
        for (int i = 0; i < vertices.length - 1; i++) {
          final v1 = vertices[i];
          final v2 = vertices[i + 1];
          if (v1.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              map,
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
              map,
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
    } else if (entity is DxfPolyline) {
      final vertices = entity.vertices;
      if (vertices.length >= 2) {
        for (int i = 0; i < vertices.length - 1; i++) {
          final v1 = vertices[i];
          final v2 = vertices[i + 1];
          if (v1.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              map,
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
              map,
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
  }

  static void _extractSegmentsFromInsert(
    DxfDocument document,
    DxfInsert insert,
    Map<String, List<WallSegment>> map, {
    required int depth,
  }) {
    if (depth > 4) return;
    final block = document.blocks[insert.blockName];
    if (block == null || block.entities.isEmpty) return;

    final double rad = insert.rotationDeg * math.pi / 180.0;
    final double cosA = math.cos(rad);
    final double sinA = math.sin(rad);
    final double basePx = block.basePoint.dx;
    final double basePy = block.basePoint.dy;

    Offset transform(Offset pt) {
      final double bx = (pt.dx - basePx) * insert.scaleX;
      final double by = (pt.dy - basePy) * insert.scaleY;
      final double rx = bx * cosA - by * sinA;
      final double ry = bx * sinA + by * cosA;
      return Offset(insert.insertPoint.dx + rx, insert.insertPoint.dy + ry);
    }

    for (final child in block.entities) {
      if (child.isPaperSpace) continue;
      // Inherit insert's layer if child's layer is '0'
      final effectiveLayer = (child.layer.trim() == '0' || child.layer.isEmpty)
          ? insert.layer
          : child.layer;

      final layerObj = document.layers[effectiveLayer];
      final resolvedColor = child.colorIndex ?? insert.colorIndex ?? layerObj?.colorIndex ?? 7;
      final resolvedTrueColor = child.trueColor ?? insert.trueColor ?? layerObj?.trueColor;

      if (child is DxfLine) {
        _addSegmentIfValid(
          map,
          transform(child.p1),
          transform(child.p2),
          effectiveLayer,
          resolvedColor,
          resolvedTrueColor,
          child,
        );
      } else if (child is DxfLwPolyline) {
        final vertices = child.vertices;
        if (vertices.length >= 2) {
          for (int i = 0; i < vertices.length - 1; i++) {
            if (vertices[i].bulge.abs() < 1e-5) {
              _addSegmentIfValid(
                map,
                transform(Offset(vertices[i].x, vertices[i].y)),
                transform(Offset(vertices[i + 1].x, vertices[i + 1].y)),
                effectiveLayer,
                resolvedColor,
                resolvedTrueColor,
                child,
              );
            }
          }
          if (child.isClosed && vertices.length > 2 && vertices.last.bulge.abs() < 1e-5) {
            _addSegmentIfValid(
              map,
              transform(Offset(vertices.last.x, vertices.last.y)),
              transform(Offset(vertices.first.x, vertices.first.y)),
              effectiveLayer,
              resolvedColor,
              resolvedTrueColor,
              child,
            );
          }
        }
      } else if (child is DxfInsert) {
        _extractSegmentsFromInsert(document, child, map, depth: depth + 1);
      }
    }
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
      sourceLayer: layer.trim(),
      sourceColorIndex: colorIndex,
      sourceTrueColor: trueColor,
      sourceEntity: entity,
    );

    final groupKey = '${seg.sourceLayer}#c${seg.sourceColorIndex ?? 0}';
    map.putIfAbsent(groupKey, () => []).add(seg);
  }

  /// Tests scales: mm (1.0), cm (0.1), and m (0.001) guided by drawing bounds.
  static ({double scale, String unitName}) _autoDetectScale(
    DxfDocument document,
    Map<String, List<WallSegment>> segmentsByLayer,
    double targetThicknessMm,
    double thicknessToleranceMm,
    double minOverlapMm,
  ) {
    final double width = document.bounds.width.abs();
    final double height = document.bounds.height.abs();
    final double maxDim = math.max(width, height);

    // Candidates in priority order
    final candidateScales = <({double scale, String unitName})>[];
    if (maxDim > 1000.0) {
      // Almost certainly millimeters or centimeters
      candidateScales.add((scale: 1.0, unitName: 'mm'));
      candidateScales.add((scale: 0.1, unitName: 'cm'));
      candidateScales.add((scale: 0.001, unitName: 'm'));
    } else if (maxDim > 150.0) {
      candidateScales.add((scale: 0.1, unitName: 'cm'));
      candidateScales.add((scale: 1.0, unitName: 'mm'));
      candidateScales.add((scale: 0.001, unitName: 'm'));
    } else {
      candidateScales.add((scale: 0.001, unitName: 'm'));
      candidateScales.add((scale: 0.1, unitName: 'cm'));
      candidateScales.add((scale: 1.0, unitName: 'mm'));
    }

    double maxTotalOverlap = 0.0;
    var bestCandidate = candidateScales.first;

    for (final candidate in candidateScales) {
      final s = candidate.scale;
      final targetDist = targetThicknessMm * s;
      final tolerance = thicknessToleranceMm * s;
      final minOverlap = minOverlapMm * s;

      double candidateTotalOverlap = 0.0;

      for (final entry in segmentsByLayer.entries) {
        final segments = entry.value;
        if (segments.length < 2) continue;
        final firstSeg = segments.first;
        if (_isClutterOrBorderLayer(firstSeg.sourceLayer.toLowerCase())) continue;

        final pairs = _findParallelPairs(
          segments,
          targetDist,
          tolerance,
          minOverlap,
          documentBounds: document.bounds,
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

  @visibleForTesting
  static List<WallSegment> mergeCollinearSegmentsForTesting(
    List<WallSegment> segments,
    double toleranceCad,
  ) =>
      _mergeCollinearSegments(segments, toleranceCad);

  @visibleForTesting
  static List<WallPairCandidate> findParallelPairsForTesting(
    List<WallSegment> segments,
    double targetDistanceCad,
    double toleranceCad,
    double minOverlapCad, {
    Rect? documentBounds,
    bool checkIntermediate = true,
  }) =>
      _findParallelPairs(
        segments,
        targetDistanceCad,
        toleranceCad,
        minOverlapCad,
        documentBounds: documentBounds,
        checkIntermediate: checkIntermediate,
      );

  @visibleForTesting
  static List<(Offset, Offset)> bridgeOpeningsForTesting(
    List<(Offset, Offset)> rawAxes,
    double maxBridgeGapCad,
    double toleranceCad,
  ) =>
      _bridgeOpenings(rawAxes, maxBridgeGapCad, toleranceCad);

  /// Merges touching or overlapping collinear segments in the same layer.
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

      // Compute bucket reference angle and normal to eliminate coordinate origin errors
      final refAngle = bucket.first.angleRad;
      final double cosA = math.cos(refAngle);
      final double sinA = math.sin(refAngle);

      // Sort by perpendicular offset along the bucket normal
      bucket.sort((a, b) {
        final midA = (a.start + a.end) / 2.0;
        final midB = (b.start + b.end) / 2.0;
        final dA = -midA.dx * sinA + midA.dy * cosA;
        final dB = -midB.dx * sinA + midB.dy * cosA;
        return dA.compareTo(dB);
      });

      // Sub-cluster collinear lines with same offset
      final List<List<WallSegment>> collinearClusters = [];
      List<WallSegment> currentCluster = [bucket.first];

      for (int i = 1; i < bucket.length; i++) {
        final prev = bucket[i - 1];
        final curr = bucket[i];
        final midPrev = (prev.start + prev.end) / 2.0;
        final midCurr = (curr.start + curr.end) / 2.0;
        final dPrev = -midPrev.dx * sinA + midPrev.dy * cosA;
        final dCurr = -midCurr.dx * sinA + midCurr.dy * cosA;

        if ((dCurr - dPrev).abs() <= toleranceCad * 0.4) {
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

        // Project intervals onto direction vector u
        final intervals = cluster.map((s) {
          final t1 = s.start.dx * cosA + s.start.dy * sinA;
          final t2 = s.end.dx * cosA + s.end.dy * sinA;
          final mid = (s.start + s.end) / 2.0;
          final d = -mid.dx * sinA + mid.dy * cosA;
          return (tMin: math.min(t1, t2), tMax: math.max(t1, t2), d: d, seg: s);
        }).toList()
          ..sort((a, b) => a.tMin.compareTo(b.tMin));

        double curTMin = intervals.first.tMin;
        double curTMax = intervals.first.tMax;
        double curD = intervals.first.d;
        WallSegment curRefSeg = intervals.first.seg;

        for (int i = 1; i < intervals.length; i++) {
          final next = intervals[i];
          if (next.tMin <= curTMax + toleranceCad) {
            curTMax = math.max(curTMax, next.tMax);
            curD = (curD + next.d) / 2.0;
          } else {
            // Commit previous merged segment
            final startPt = Offset(
              curTMin * cosA - curD * sinA,
              curTMin * sinA + curD * cosA,
            );
            final endPt = Offset(
              curTMax * cosA - curD * sinA,
              curTMax * sinA + curD * cosA,
            );
            mergedList.add(
              WallSegment(
                start: startPt,
                end: endPt,
                angleRad: curRefSeg.angleRad,
                offsetFromOrigin: curD,
                length: curTMax - curTMin,
                sourceLayer: curRefSeg.sourceLayer,
                sourceColorIndex: curRefSeg.sourceColorIndex,
                sourceTrueColor: curRefSeg.sourceTrueColor,
                sourceEntity: curRefSeg.sourceEntity,
              ),
            );
            curTMin = next.tMin;
            curTMax = next.tMax;
            curD = next.d;
            curRefSeg = next.seg;
          }
        }

        // Commit final interval
        final startPt = Offset(
          curTMin * cosA - curD * sinA,
          curTMin * sinA + curD * cosA,
        );
        final endPt = Offset(
          curTMax * cosA - curD * sinA,
          curTMax * sinA + curD * cosA,
        );
        mergedList.add(
          WallSegment(
            start: startPt,
            end: endPt,
            angleRad: curRefSeg.angleRad,
            offsetFromOrigin: curD,
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

  /// Buckets segments by normalized angle (within tolerance +-1.5 deg ~= 0.026 rad).
  static List<List<WallSegment>> _bucketByAngle(List<WallSegment> segments) {
    const double angleTolerance = 1.5 * math.pi / 180.0; // 1.5 degrees
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
  /// Uses a single reference normal per angle bucket to guarantee origin-invariant distance.
  static List<WallPairCandidate> _findParallelPairs(
    List<WallSegment> segments,
    double targetDistanceCad,
    double toleranceCad,
    double minOverlapCad, {
    Rect? documentBounds,
    bool checkIntermediate = true,
  }) {
    final pairs = <WallPairCandidate>[];
    final angleBuckets = _bucketByAngle(segments);

    for (final bucket in angleBuckets) {
      if (bucket.length < 2) continue;

      // Use a single reference angle and normal for this entire bucket
      final refAngle = bucket.first.angleRad;
      final double cosA = math.cos(refAngle);
      final double sinA = math.sin(refAngle);

      // Pre-compute d and projection interval [tMin, tMax] for every segment
      final projected = bucket.map((s) {
        final mid = (s.start + s.end) / 2.0;
        final d = -mid.dx * sinA + mid.dy * cosA;
        final t1 = s.start.dx * cosA + s.start.dy * sinA;
        final t2 = s.end.dx * cosA + s.end.dy * sinA;
        return (
          seg: s,
          d: d,
          tMin: math.min(t1, t2),
          tMax: math.max(t1, t2),
        );
      }).toList()
        ..sort((a, b) => a.d.compareTo(b.d));

      final n = projected.length;
      for (int i = 0; i < n; i++) {
        final s1 = projected[i];
        final minOffset = s1.d + targetDistanceCad - toleranceCad;
        final maxOffset = s1.d + targetDistanceCad + toleranceCad;

        // Binary search for first index with offset >= minOffset
        int low = i + 1;
        int high = n - 1;
        int startIdx = n;
        while (low <= high) {
          final mid = (low + high) >> 1;
          if (projected[mid].d >= minOffset) {
            startIdx = mid;
            high = mid - 1;
          } else {
            low = mid + 1;
          }
        }

        // Scan partners in [minOffset, maxOffset]
        for (int j = startIdx; j < n; j++) {
          final s2 = projected[j];
          if (s2.d > maxOffset) break;

          final double dist = (s2.d - s1.d).abs();

          final tStart = math.max(s1.tMin, s2.tMin);
          final tEnd = math.min(s1.tMax, s2.tMax);
          final overlap = tEnd - tStart;

          if (overlap >= minOverlapCad) {
            // Sheet border / margin frame rejection:
            // Border lines span a large fraction of the sheet and sit right at the boundary.
            if (documentBounds != null &&
                documentBounds.width > 0 &&
                documentBounds.height > 0) {
              if (_isSheetBorder(s1.seg, documentBounds, targetDistanceCad) ||
                  _isSheetBorder(s2.seg, documentBounds, targetDistanceCad)) {
                continue; // Reject sheet border lines
              }
            }

            if (checkIntermediate && j > i + 1) {
              // Check if any intermediate segment between s1 (index i) and s2 (index j)
              // runs parallel in the cavity between s1 and s2.
              // In solid masonry or concrete walls, the space between the outer faces is empty.
              // In windows, doors, and multi-layer assemblies, intermediate parallel lines
              // (window frames, glass panes, sills, insulation interfaces) lie between the outer lines.
              final margin = math.max(toleranceCad * 0.15, dist * 0.10);
              bool hasIntermediate = false;

              for (int k = i + 1; k < j; k++) {
                final sk = projected[k];
                if (sk.d > s1.d + margin && sk.d < s2.d - margin) {
                  final kOverlap = math.min(tEnd, sk.tMax) - math.max(tStart, sk.tMin);
                  if (kOverlap >= math.min(minOverlapCad * 0.35, dist * 0.20)) {
                    hasIntermediate = true;
                    break;
                  }
                }
              }

              if (hasIntermediate) {
                continue; // Reject false window / multi-line pair
              }
            }

            final double midOffset = (s1.d + s2.d) / 2.0;
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
                segmentA: s1.seg,
                segmentB: s2.seg,
                perpendicularDistance: dist,
                overlapLength: overlap,
                centerlineStart: centerStart,
                centerlineEnd: centerEnd,
              ),
            );
          }
        }
      }
    }

    // Filter repetitive ladder rungs (e.g. stair treads, title block rows, gratings)
    // In solid walls, each face belongs to only one wall cavity.
    // If a segment participates in pairs on BOTH sides at target wall thickness,
    // it is a shared internal rung of an equidistant ladder/stair/grid.
    if (pairs.length > 2) {
      final partnersMap = <WallSegment, List<double>>{};
      for (final p in pairs) {
        partnersMap.putIfAbsent(p.segmentA, () => []).add(p.perpendicularDistance);
        partnersMap.putIfAbsent(p.segmentB, () => []).add(-p.perpendicularDistance);
      }
      pairs.removeWhere((p) {
        final aPartners = partnersMap[p.segmentA] ?? [];
        final bPartners = partnersMap[p.segmentB] ?? [];
        final aHasBoth = aPartners.any((d) => d > 0) && aPartners.any((d) => d < 0);
        final bHasBoth = bPartners.any((d) => d > 0) && bPartners.any((d) => d < 0);
        return aHasBoth && bHasBoth;
      });
    }

    return pairs;
  }

  static bool _isSheetBorder(
    WallSegment s,
    Rect docBounds,
    double targetDistCad,
  ) {
    // Structural wall layers are never sheet borders
    if (_isStructuralLayer(s.sourceLayer.toLowerCase())) return false;

    final double docWidth = docBounds.width.abs();
    final double docHeight = docBounds.height.abs();
    // A drawing must be significantly larger than a single wall to have sheet margins
    if (docWidth < targetDistCad * 8 || docHeight < targetDistCad * 8) return false;

    final double deg = s.angleRad * 180.0 / math.pi;
    if (deg < 15.0 || deg > 165.0) {
      if (s.length >= docWidth * 0.60) {
        final double midY = (s.start.dy + s.end.dy) / 2.0;
        final double dEdge = math.min((midY - docBounds.top).abs(), (midY - docBounds.bottom).abs());
        if (dEdge <= docHeight * 0.06) return true;
      }
    } else if (deg > 75.0 && deg < 105.0) {
      if (s.length >= docHeight * 0.60) {
        final double midX = (s.start.dx + s.end.dx) / 2.0;
        final double dEdge = math.min((midX - docBounds.left).abs(), (midX - docBounds.right).abs());
        if (dEdge <= docWidth * 0.06) return true;
      }
    }
    return false;
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
      final mid = (p1 + p2) / 2.0;
      final offset = -mid.dx * sinA + mid.dy * cosA;

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

      final refAngle = bucket.first.angleRad;
      final double cosA = math.cos(refAngle);
      final double sinA = math.sin(refAngle);

      bucket.sort((a, b) {
        final midA = (a.start + a.end) / 2.0;
        final midB = (b.start + b.end) / 2.0;
        final dA = -midA.dx * sinA + midA.dy * cosA;
        final dB = -midB.dx * sinA + midB.dy * cosA;
        return dA.compareTo(dB);
      });

      final List<List<WallSegment>> collinearGroups = [];
      List<WallSegment> curGroup = [bucket.first];

      for (int i = 1; i < bucket.length; i++) {
        final prev = bucket[i - 1];
        final curr = bucket[i];
        final midPrev = (prev.start + prev.end) / 2.0;
        final midCurr = (curr.start + curr.end) / 2.0;
        final dPrev = -midPrev.dx * sinA + midPrev.dy * cosA;
        final dCurr = -midCurr.dx * sinA + midCurr.dy * cosA;

        if ((dCurr - dPrev).abs() <= toleranceCad) {
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

        final intervals = group.map((s) {
          final t1 = s.start.dx * cosA + s.start.dy * sinA;
          final t2 = s.end.dx * cosA + s.end.dy * sinA;
          final mid = (s.start + s.end) / 2.0;
          final d = -mid.dx * sinA + mid.dy * cosA;
          return (tMin: math.min(t1, t2), tMax: math.max(t1, t2), d: d, seg: s);
        }).toList()
          ..sort((a, b) => a.tMin.compareTo(b.tMin));

        double curTMin = intervals.first.tMin;
        double curTMax = intervals.first.tMax;
        double curD = intervals.first.d;

        for (int i = 1; i < intervals.length; i++) {
          final next = intervals[i];
          final gap = next.tMin - curTMax;

          // If gap <= maxBridgeGapCad, bridge through the door/window opening!
          if (gap <= maxBridgeGapCad) {
            curTMax = math.max(curTMax, next.tMax);
            curD = (curD + next.d) / 2.0;
          } else {
            // Commit previous segment
            bridgedAxes.add(
              (
                Offset(curTMin * cosA - curD * sinA, curTMin * sinA + curD * cosA),
                Offset(curTMax * cosA - curD * sinA, curTMax * sinA + curD * cosA),
              ),
            );
            curTMin = next.tMin;
            curTMax = next.tMax;
            curD = next.d;
          }
        }

        // Commit trailing segment
        bridgedAxes.add(
          (
            Offset(curTMin * cosA - curD * sinA, curTMin * sinA + curD * cosA),
            Offset(curTMax * cosA - curD * sinA, curTMax * sinA + curD * cosA),
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

        final dxA = a.p2.dx - a.p1.dx;
        final dyA = a.p2.dy - a.p1.dy;
        final dxB = b.p2.dx - b.p1.dx;
        final dyB = b.p2.dy - b.p1.dy;
        final lenA = math.sqrt(dxA * dxA + dyA * dyA);
        final lenB = math.sqrt(dxB * dxB + dyB * dyB);
        if (lenA < 1e-4 || lenB < 1e-4) continue;

        final dot = (dxA * dxB + dyA * dyB) / (lenA * lenB);
        if (dot.abs() > 0.96) continue; // Parallel, skip L-corner

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
              lines[i] = (
                p1: pair.isAStart ? intersection : a.p1,
                p2: pair.isAStart ? a.p2 : intersection,
              );
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

        void checkAndSnapT(Offset pt, bool isStart) {
          final double abX = b.p2.dx - b.p1.dx;
          final double abY = b.p2.dy - b.p1.dy;
          final double lenSq = abX * abX + abY * abY;
          if (lenSq < 1e-6) return;

          final double t =
              (((pt.dx - b.p1.dx) * abX + (pt.dy - b.p1.dy) * abY) / lenSq).clamp(0.0, 1.0);
          final Offset proj = Offset(b.p1.dx + t * abX, b.p1.dy + t * abY);
          final double dist = (pt - proj).distance;

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
    if (denom.abs() < 1e-9) return null;

    final double t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;
    return Offset(x1 + t * (x2 - x1), y1 + t * (y2 - y1));
  }

  /// Closes open wall ends at doors and windows by adding transverse closure caps (jamb lines),
  /// while preserving corner and T-junction continuity.
  static void _collectWallContourWithEndCaps(
    WallPairCandidate pair,
    List<WallPairCandidate> allPairs,
    List<(Offset, Offset)> wallContourSegments, [
    List<(Offset, Offset)>? closureSegments,
  ]) {
    final sA = pair.segmentA;
    final sB = pair.segmentB;
    final refAngle = sA.angleRad;
    final double cosA = math.cos(refAngle);
    final double sinA = math.sin(refAngle);
    final u = Offset(cosA, sinA);

    // Perpendicular offsets of both faces from origin
    final midA = (sA.start + sA.end) / 2.0;
    final midB = (sB.start + sB.end) / 2.0;
    final dA = -midA.dx * sinA + midA.dy * cosA;
    final dB = -midB.dx * sinA + midB.dy * cosA;

    // Projections along u for segment A
    final t1A = sA.start.dx * cosA + sA.start.dy * sinA;
    final t2A = sA.end.dx * cosA + sA.end.dy * sinA;
    final tMinA = math.min(t1A, t2A);
    final tMaxA = math.max(t1A, t2A);

    // Projections along u for segment B
    final t1B = sB.start.dx * cosA + sB.start.dy * sinA;
    final t2B = sB.end.dx * cosA + sB.end.dy * sinA;
    final tMinB = math.min(t1B, t2B);
    final tMaxB = math.max(t1B, t2B);

    // Common overlap along wall length
    final tStart = math.max(tMinA, tMinB);
    final tEnd = math.min(tMaxA, tMaxB);

    if (tEnd <= tStart) {
      // Degenerate/no overlap, preserve original segments
      _addSegmentUnique(wallContourSegments, sA.start, sA.end);
      _addSegmentUnique(wallContourSegments, sB.start, sB.end);
      return;
    }

    // Perpendicular face points at the start of the mutual overlap
    final pAStart = Offset(tStart * cosA - dA * sinA, tStart * sinA + dA * cosA);
    final pBStart = Offset(tStart * cosA - dB * sinA, tStart * sinA + dB * cosA);
    final midStart = (pAStart + pBStart) / 2.0;

    // Perpendicular face points at the end of the mutual overlap
    final pAEnd = Offset(tEnd * cosA - dA * sinA, tEnd * sinA + dA * cosA);
    final pBEnd = Offset(tEnd * cosA - dB * sinA, tEnd * sinA + dB * cosA);
    final midEnd = (pAEnd + pBEnd) / 2.0;

    final wallThickness = pair.perpendicularDistance;

    // Check if start is an open jamb/opening or a corner/junction
    final bool isStartCorner = _isCornerOrJunction(midStart, u, wallThickness, allPairs, pair);
    final Offset faceAStart;
    final Offset faceBStart;

    if (!isStartCorner) {
      // Open end (door/window opening or free wall end): close with transverse cap
      _addSegmentUnique(wallContourSegments, pAStart, pBStart);
      if (closureSegments != null) {
        _addSegmentUnique(closureSegments, pAStart, pBStart);
      }
      faceAStart = pAStart;
      faceBStart = pBStart;
    } else {
      // Corner or junction: keep original outer endpoints to meet intersecting wall
      faceAStart = (t1A == tMinA) ? sA.start : sA.end;
      faceBStart = (t1B == tMinB) ? sB.start : sB.end;
    }

    // Check if end is an open jamb/opening or a corner/junction
    final bool isEndCorner = _isCornerOrJunction(midEnd, u, wallThickness, allPairs, pair);
    final Offset faceAEnd;
    final Offset faceBEnd;

    if (!isEndCorner) {
      // Open end (door/window opening or free wall end): close with transverse cap
      _addSegmentUnique(wallContourSegments, pAEnd, pBEnd);
      if (closureSegments != null) {
        _addSegmentUnique(closureSegments, pAEnd, pBEnd);
      }
      faceAEnd = pAEnd;
      faceBEnd = pBEnd;
    } else {
      // Corner or junction: keep original outer endpoints to meet intersecting wall
      faceAEnd = (t2A == tMaxA) ? sA.end : sA.start;
      faceBEnd = (t2B == tMaxB) ? sB.end : sB.start;
    }

    // Add longitudinal wall face segments
    _addSegmentUnique(wallContourSegments, faceAStart, faceAEnd);
    _addSegmentUnique(wallContourSegments, faceBStart, faceBEnd);
  }

  /// Determines whether [midPt] of a wall pair connects to an intersecting or continuing wall
  /// (e.g. L-corner, T-junction, or collinear continuation), rather than being an open jamb / opening.
  static bool _isCornerOrJunction(
    Offset midPt,
    Offset wallDir,
    double wallThickness,
    List<WallPairCandidate> allPairs,
    WallPairCandidate currentPair,
  ) {
    final searchRadius = wallThickness * 1.25;

    for (final other in allPairs) {
      if (identical(other, currentPair)) continue;

      final otherDir = other.segmentA.direction;
      final dot = (wallDir.dx * otherDir.dx + wallDir.dy * otherDir.dy).abs();

      if (dot < 0.85) {
        // Non-parallel wall (L-corner or T-junction):
        final p1 = other.centerlineStart;
        final p2 = other.centerlineEnd;
        final closest = _closestPointOnSegment(midPt, p1, p2);
        if ((midPt - closest).distance <= searchRadius) {
          return true;
        }
      } else {
        // Parallel wall: check if it touches midPt directly (collinear continuation with no opening)
        if ((other.centerlineStart - midPt).distance <= wallThickness * 0.45 ||
            (other.centerlineEnd - midPt).distance <= wallThickness * 0.45) {
          return true;
        }
      }
    }

    return false;
  }

  /// Calculates the closest point on the line segment [a]-[b] to point [p].
  static Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return a;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    final clampedT = t.clamp(0.0, 1.0);
    return a + ab * clampedT;
  }

  /// Adds a segment to [list] if it is not degenerate and does not already exist within [tol].
  static void _addSegmentUnique(
    List<(Offset, Offset)> list,
    Offset p1,
    Offset p2, {
    double tol = 5.0,
  }) {
    if ((p2 - p1).distance < 1.0) return;
    for (final existing in list) {
      if (((existing.$1 - p1).distance <= tol && (existing.$2 - p2).distance <= tol) ||
          ((existing.$1 - p2).distance <= tol && (existing.$2 - p1).distance <= tol)) {
        return;
      }
    }
    list.add((p1, p2));
  }
}
