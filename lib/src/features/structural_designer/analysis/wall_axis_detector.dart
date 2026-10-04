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

      // Detect parallel pairs at target distance
      final pairs = _findParallelPairs(
        mergedSegments,
        targetDistCad,
        toleranceCad,
        minOverlapCad,
      );

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

        // Check soft keywords (title block, sheet border, furniture, hatch -> penalty)
        double keywordMultiplier = 1.0;
        final lowerName = layerName.toLowerCase();
        if (_isClutterOrBorderLayer(lowerName)) {
          keywordMultiplier = 0.1; // Soft penalty for title block, format, borders
        } else if (_isStructuralLayer(lowerName)) {
          keywordMultiplier = 1.5; // Soft boost for wall layers
        }

        // Score: combines total length, pair count diversity, and layout quality
        final pairFactor = 1.0 + math.sqrt(pairs.length);
        final score = totalOverlap * pairFactor * layoutBonus * keywordMultiplier;

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
      // Include other high-scoring wall layers (e.g. interior + exterior walls)
      if (g.score >= bestGroup.score * 0.3 && g.pairCount >= 2) {
        activeGroups.add(g);
      }
    }

    // Step 4: Collect raw centerlines and wall contour segments
    final rawCenterlines = <(Offset, Offset)>[];
    final wallContourSegments = <(Offset, Offset)>[];

    for (final group in activeGroups) {
      for (final pair in group.wallPairs) {
        rawCenterlines.add((pair.centerlineStart, pair.centerlineEnd));
        wallContourSegments.add((pair.segmentA.start, pair.segmentA.end));
        wallContourSegments.add((pair.segmentB.start, pair.segmentB.end));
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
      wallContourSegments: wallContourSegments,
    );
  }

  /// Converts detected snapped centerline segments into unified, continuous [StructuralGridAxis] elements.
  ///
  /// Merges collinear wall centerlines along the same structural alignment into single continuous axes,
  /// extends them past the building perimeter (by default 1.20 m) so end bubbles sit neatly outside walls,
  /// and sequences them with standard engineering naming (1, 2, 3... for vertical, А, Б, В... for horizontal).
  static List<StructuralGridAxis> convertToStructuralGridAxes(
    List<(Offset, Offset)> centerlines, {
    required bool isBulgarian,
    required double scale,
    double extensionM = 1.20,
    double collinearToleranceMm = 200.0,
  }) {
    if (centerlines.isEmpty) return const [];

    final extensionCad = (extensionM * 1000.0) * scale;
    final collinearTolCad = collinearToleranceMm * scale;

    // Angle bucketing (within +-1.5 degrees)
    const angleTolerance = 1.5 * math.pi / 180.0;
    final buckets = <List<(Offset, Offset)>>[];

    for (final line in centerlines) {
      final p1 = line.$1;
      final p2 = line.$2;
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
      final cosA = math.cos(refAngle);
      final sinA = math.sin(refAngle);

      // Sort by perpendicular offset d
      final withD = bucket.map((line) {
        final mid = (line.$1 + line.$2) / 2.0;
        final d = -mid.dx * sinA + mid.dy * cosA;
        final t1 = line.$1.dx * cosA + line.$1.dy * sinA;
        final t2 = line.$2.dx * cosA + line.$2.dy * sinA;
        return (line: line, d: d, tMin: math.min(t1, t2), tMax: math.max(t1, t2));
      }).toList()
        ..sort((a, b) => a.d.compareTo(b.d));

      // Cluster collinear lines
      final clusters = <List<({(Offset, Offset) line, double d, double tMin, double tMax})>>[];
      var curCluster = [withD.first];
      for (int i = 1; i < withD.length; i++) {
        if ((withD[i].d - curCluster.last.d).abs() <= collinearTolCad) {
          curCluster.add(withD[i]);
        } else {
          clusters.add(curCluster);
          curCluster = [withD[i]];
        }
      }
      clusters.add(curCluster);

      for (final cluster in clusters) {
        double minT = cluster.first.tMin;
        double maxT = cluster.first.tMax;
        double avgD = 0;
        for (final item in cluster) {
          minT = math.min(minT, item.tMin);
          maxT = math.max(maxT, item.tMax);
          avgD += item.d;
        }
        avgD /= cluster.length;

        // Extend past outer wall ends so axis bubbles sit outside the building envelope
        final tStart = minT - extensionCad;
        final tEnd = maxT + extensionCad;

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
            id: 'axis_auto_$axisCounter',
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
      'wall', 'стена', 'стен', 'stena', 'zid', 'masonry', 'mason', 'структура', 'констр'
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
    double minOverlapCad,
  ) {
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
}
