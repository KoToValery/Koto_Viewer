// === SECTION: ARCHITECT GEOMETRIC GEODETIC & CONTOUR DETECTOR ===

import 'dart:math' as math;
import 'dart:ui';

import '../../../core/models/coordinate_system.dart';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_projects/services/bim_underlay_loader.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_underlay_models.dart';

class ArchitectGeodeticDetectionResult {
  final BimCoordinateFrame frame;
  final CoordinateSystem coordinateSystem;
  final bool isGeodetic;
  final List<ArchitectGeodeticContour> contours;
  final List<ArchitectGeodeticPoint> spotElevations;
  final ArchitectGeodeticSurvey survey;

  const ArchitectGeodeticDetectionResult({
    required this.frame,
    required this.coordinateSystem,
    required this.isGeodetic,
    required this.contours,
    required this.spotElevations,
    required this.survey,
  });

  bool get hasTopography => contours.isNotEmpty || spotElevations.isNotEmpty;
}

class _NumericTextCandidate {
  final Offset cadPosition;
  final Offset localPosition;
  final double value;
  final bool hasDecimal;
  final double rotationRad;
  final String layer;
  bool consumedByContour = false;

  _NumericTextCandidate({
    required this.cadPosition,
    required this.localPosition,
    required this.value,
    required this.hasDecimal,
    required this.rotationRad,
    required this.layer,
  });
}

/// Geometric-first detector for geodetic coordinate systems, topographic
/// contour lines (хоризонтали), and spot elevations (височинни коти) from DXF/DWG.
class ArchitectGeodeticDetector {
  /// Analyzes [doc] for geodetic coordinates, contour polylines/splines, and spot elevations.
  ///
  /// Preserves coordinate alignment when:
  /// - [lockedOrigin] and [lockedUnitsPerMeter] are provided (live Xref reload or explicit replace), OR
  /// - [existingSurvey] has the same geodetic CRS as [doc] (importing a new geodetic file with a different name).
  static ArchitectGeodeticDetectionResult analyzeDocument({
    required DxfDocument doc,
    required String storeyId,
    Offset? lockedOrigin,
    double? lockedUnitsPerMeter,
    ArchitectGeodeticSurvey? existingSurvey,
  }) {
    final bounds = doc.bounds;
    final detectedCrs = CoordinateSystem.detectFromBounds(bounds);
    final isGeodetic =
        detectedCrs != CoordinateSystem.localCartesian &&
        detectedCrs != CoordinateSystem.wgs84Geo;

    // Resolve stable coordinate frame
    final double unitsPerMeter;
    final Offset origin;
    if (lockedOrigin != null &&
        lockedUnitsPerMeter != null &&
        lockedUnitsPerMeter > 0) {
      origin = lockedOrigin;
      unitsPerMeter = lockedUnitsPerMeter;
    } else if (isGeodetic &&
        existingSurvey != null &&
        existingSurvey.coordinateSystemId == detectedCrs.id &&
        existingSurvey.unitsPerMeter > 0) {
      // Same geodetic CRS as existing survey -> lock to exact same geodetic origin!
      origin = Offset(
        existingSurvey.geodeticOriginX,
        existingSurvey.geodeticOriginY,
      );
      unitsPerMeter = existingSurvey.unitsPerMeter;
    } else {
      unitsPerMeter = isGeodetic
          ? 1.0
          : BimUnderlayLoader.computeUnitsPerMeter(doc, bounds);
      origin = bounds.isFinite && !bounds.isEmpty ? bounds.center : Offset.zero;
    }

    final frame = BimCoordinateFrame(
      origin: origin,
      unitsPerMeter: unitsPerMeter,
    );

    // 1. Collect numeric elevation texts and survey point markers (circles, points, inserts, cross ticks)
    final numericTexts = <_NumericTextCandidate>[];
    final markerPositionsLocal = <Offset>[];

    for (final entity in doc.entities) {
      if (entity.isPaperSpace) continue;
      if (entity is DxfText && !entity.isInvisible) {
        final parsed = _parseElevationText(entity.text);
        if (parsed != null) {
          final cadPos = entity.alignPoint ?? entity.insertPoint;
          numericTexts.add(
            _NumericTextCandidate(
              cadPosition: cadPos,
              localPosition: frame.toModel(cadPos),
              value: parsed.value,
              hasDecimal: parsed.hasDecimal,
              rotationRad: entity.rotationDeg * math.pi / 180.0,
              layer: entity.layer,
            ),
          );
        }
      } else if (entity is DxfMText) {
        final parsed = _parseElevationText(entity.cleanText);
        if (parsed != null) {
          numericTexts.add(
            _NumericTextCandidate(
              cadPosition: entity.insertPoint,
              localPosition: frame.toModel(entity.insertPoint),
              value: parsed.value,
              hasDecimal: parsed.hasDecimal,
              rotationRad: entity.rotationDeg * math.pi / 180.0,
              layer: entity.layer,
            ),
          );
        }
      } else if (entity is DxfPoint) {
        markerPositionsLocal.add(frame.toModel(entity.point));
      } else if (entity is DxfInsert) {
        markerPositionsLocal.add(frame.toModel(entity.insertPoint));
      } else if (entity is DxfCircle) {
        final radiusMeters = entity.radius / unitsPerMeter;
        if (radiusMeters > 0.01 && radiusMeters <= 0.85) {
          markerPositionsLocal.add(frame.toModel(entity.center));
        }
      }
    }

    // 2. Geometric-first contour detection
    final rawContours = <_RawContourCandidate>[];
    final confirmedContourLayers = <String, List<double>>{};

    int candidateIndex = 0;
    for (final entity in doc.entities) {
      if (entity.isPaperSpace) continue;

      if (entity is DxfLwPolyline && entity.vertices.length >= 3) {
        final localPts = [
          for (final v in entity.vertices) frame.toModel(Offset(v.x, v.y)),
        ];
        if (!_isPlausibleContourGeometry(localPts, isClosed: entity.isClosed)) {
          continue;
        }

        double? detectedElevation;
        if (entity.elevation.abs() > 1e-3 &&
            entity.elevation.abs() < 9000.0) {
          // Signal A: Explicit 3D polyline elevation (DXF code 38)
          detectedElevation = entity.elevation;
        } else {
          // Signal B: 2D topographic curve paired with tangential/adjacent numeric elevation label
          final matchedText = _findNearestContourLabel(
            localPts,
            numericTexts,
            isClosed: entity.isClosed,
          );
          if (matchedText != null) {
            detectedElevation = matchedText.value;
            matchedText.consumedByContour = true;
          }
        }

        if (detectedElevation != null) {
          confirmedContourLayers
              .putIfAbsent(entity.layer, () => <double>[])
              .add(detectedElevation);
        }

        rawContours.add(
          _RawContourCandidate(
            index: candidateIndex++,
            points: localPts,
            closed: entity.isClosed,
            layer: entity.layer,
            elevation: detectedElevation,
          ),
        );
      } else if (entity is DxfSpline) {
        final srcPts = entity.fitPoints.length >= 3
            ? entity.fitPoints
            : entity.controlPoints;
        if (srcPts.length >= 3) {
          final localPts = [for (final p in srcPts) frame.toModel(p)];
          if (_isPlausibleContourGeometry(
            localPts,
            isClosed: entity.isClosed,
          )) {
            final matchedText = _findNearestContourLabel(
              localPts,
              numericTexts,
              isClosed: entity.isClosed,
            );
            double? elev;
            if (matchedText != null) {
              elev = matchedText.value;
              matchedText.consumedByContour = true;
              confirmedContourLayers
                  .putIfAbsent(entity.layer, () => <double>[])
                  .add(elev);
            }
            rawContours.add(
              _RawContourCandidate(
                index: candidateIndex++,
                points: localPts,
                closed: entity.isClosed,
                layer: entity.layer,
                elevation: elev,
              ),
            );
          }
        }
      }
    }

    // Second pass: For unlabeled smooth curves on a layer that already has confirmed contours,
    // propagate the nearest contour elevation on that layer so intermediate contours aren't dropped.
    final resolvedContours = <_RawContourCandidate>[];
    for (final c in rawContours) {
      if (c.elevation != null) {
        resolvedContours.add(c);
      } else if (confirmedContourLayers.containsKey(c.layer) &&
          c.points.length >= 4) {
        final nearestElev = _nearestContourElevation(c, rawContours);
        if (nearestElev != null) {
          resolvedContours.add(c.withElevation(nearestElev));
        }
      }
    }

    // Determine dominant contour step ΔZ to classify major vs minor contours
    final stepZ = _estimateContourStep(
      resolvedContours.map((c) => c.elevation!).toList(),
    );
    final majorStep = stepZ * 5.0;

    final contours = <ArchitectGeodeticContour>[];
    for (var i = 0; i < resolvedContours.length; i++) {
      final rc = resolvedContours[i];
      final elev = rc.elevation!;
      final isMajor = majorStep > 1e-3
          ? ((elev / majorStep).roundToDouble() * majorStep - elev).abs() <
                0.02
          : (elev - elev.roundToDouble()).abs() < 0.02;
      contours.add(
        ArchitectGeodeticContour(
          id: 'topo_cnt_${storeyId}_$i',
          storeyId: storeyId,
          points: rc.points,
          elevation: double.parse(elev.toStringAsFixed(3)),
          isMajor: isMajor,
          closed: rc.closed,
          sourceLayer: rc.layer,
        ),
      );
    }

    // 3. Geometric-first Spot Elevation (височинни коти / пикети) detection
    final spotElevations = <ArchitectGeodeticPoint>[];
    int ptIdx = 0;
    for (final txt in numericTexts) {
      if (txt.consumedByContour) continue;
      if (!txt.hasDecimal) continue;
      if (txt.value.abs() < 0.05 || txt.value.abs() > 8900.0) continue;

      // Check if near a survey point marker (circle/point/insert) within 1.8m,
      // or if the file is geodetic / has confirmed contours.
      Offset? anchorLocal;
      double bestDist = 1.80;
      for (final m in markerPositionsLocal) {
        final d = (m - txt.localPosition).distance;
        if (d < bestDist) {
          bestDist = d;
          anchorLocal = m;
        }
      }

      if (anchorLocal != null || isGeodetic || contours.isNotEmpty) {
        final posLocal = anchorLocal ?? txt.localPosition;
        final posCad = frame.toCad(posLocal);
        spotElevations.add(
          ArchitectGeodeticPoint(
            id: 'topo_pt_${storeyId}_${ptIdx++}',
            storeyId: storeyId,
            position: posLocal,
            geodeticX: posCad.dx,
            geodeticY: posCad.dy,
            elevation: double.parse(txt.value.toStringAsFixed(3)),
            sourceLayer: txt.layer,
          ),
        );
      }
    }

    final baseSurvey =
        existingSurvey ??
        ArchitectGeodeticSurvey(
          coordinateSystemId: detectedCrs.id,
          geodeticOriginX: frame.origin.dx,
          geodeticOriginY: frame.origin.dy,
          unitsPerMeter: frame.unitsPerMeter,
        );

    final updatedSurvey = baseSurvey.withStoreyData(
      storeyId: storeyId,
      storeyContours: contours,
      storeyPoints: spotElevations,
      coordinateSystemId: isGeodetic
          ? detectedCrs.id
          : baseSurvey.coordinateSystemId,
      geodeticOriginX: isGeodetic
          ? frame.origin.dx
          : baseSurvey.geodeticOriginX,
      geodeticOriginY: isGeodetic
          ? frame.origin.dy
          : baseSurvey.geodeticOriginY,
      unitsPerMeter: isGeodetic
          ? frame.unitsPerMeter
          : baseSurvey.unitsPerMeter,
    );

    return ArchitectGeodeticDetectionResult(
      frame: frame,
      coordinateSystem: detectedCrs,
      isGeodetic: isGeodetic,
      contours: contours,
      spotElevations: spotElevations,
      survey: updatedSurvey,
    );
  }

  static ({double value, bool hasDecimal})? _parseElevationText(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    // Strip common MTEXT formatting prefixes like \A1; or {\fArial;...}
    cleaned = cleaned.replaceAll(RegExp(r'\\[A-Za-z0-9]+;'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '').trim();
    if (cleaned.length > 14) return null;

    final normalized = cleaned.replaceAll(',', '.');
    final match = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)\s*(?:m|м)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final numStr = match.group(1)!;
    final val = double.tryParse(numStr);
    if (val == null || !val.isFinite) return null;
    final hasDecimal = numStr.contains('.');
    return (value: val, hasDecimal: hasDecimal);
  }

  /// Rejects tiny symbols, orthogonal boxes/columns, and short segments.
  /// Accepts multi-vertex topographic polylines with realistic length and curvature.
  static bool _isPlausibleContourGeometry(
    List<Offset> pts, {
    required bool isClosed,
  }) {
    if (pts.length < 3) return false;
    double totalLen = 0.0;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    int nonOrthogonalSegments = 0;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final seg = b - a;
      final d = seg.distance;
      totalLen += d;
      if (b.dx < minX) minX = b.dx;
      if (b.dx > maxX) maxX = b.dx;
      if (b.dy < minY) minY = b.dy;
      if (b.dy > maxY) maxY = b.dy;
      if (d > 1e-3) {
        final angle = seg.direction.abs();
        final isOrtho =
            (angle < 0.04) ||
            ((angle - math.pi / 2).abs() < 0.04) ||
            ((angle - math.pi).abs() < 0.04);
        if (!isOrtho) nonOrthogonalSegments++;
      }
    }
    if (isClosed && pts.length >= 3) {
      totalLen += (pts.first - pts.last).distance;
    }

    // Must be at least 2.5m long in model space
    if (totalLen < 2.5) return false;

    // Reject 4-point closed axis-aligned rectangles (columns, rooms, title blocks)
    if (isClosed && pts.length <= 5 && nonOrthogonalSegments <= 1) {
      return false;
    }

    // Must have either >= 4 vertices with non-orthogonal segments or >= 6 vertices
    if (pts.length < 4 && nonOrthogonalSegments == 0) {
      return false;
    }
    final span = math.max(maxX - minX, maxY - minY);
    return span >= 1.5;
  }

  static _NumericTextCandidate? _findNearestContourLabel(
    List<Offset> pts,
    List<_NumericTextCandidate> texts, {
    required bool isClosed,
  }) {
    _NumericTextCandidate? best;
    double bestScore = 1.35; // Max perpendicular distance in meters

    for (final txt in texts) {
      if (txt.consumedByContour) continue;
      // Elevation labels on contours are typically positive heights or decimal elevations
      if (!txt.hasDecimal && (txt.value < 5.0 || txt.value > 4000.0)) {
        continue;
      }

      for (var i = 0; i < pts.length - 1; i++) {
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final dist = _pointToSegmentDistance(txt.localPosition, p1, p2);
        if (dist < bestScore) {
          bestScore = dist;
          best = txt;
        }
      }
      if (isClosed && pts.length >= 3) {
        final dist = _pointToSegmentDistance(
          txt.localPosition,
          pts.last,
          pts.first,
        );
        if (dist < bestScore) {
          bestScore = dist;
          best = txt;
        }
      }
    }
    return best;
  }

  static double? _nearestContourElevation(
    _RawContourCandidate target,
    List<_RawContourCandidate> all,
  ) {
    if (target.points.isEmpty) return null;
    final sample = target.points[target.points.length ~/ 2];
    double bestDist = double.infinity;
    double? bestElev;
    for (final other in all) {
      if (other.elevation == null || other.points.isEmpty) continue;
      final otherMid = other.points[other.points.length ~/ 2];
      final d = (sample - otherMid).distance;
      if (d < bestDist) {
        bestDist = d;
        bestElev = other.elevation;
      }
    }
    return bestElev;
  }

  static double _estimateContourStep(List<double> elevations) {
    if (elevations.length < 2) return 1.0;
    final unique = elevations
        .map((e) => (e * 100).round() / 100.0)
        .toSet()
        .toList()
      ..sort();
    if (unique.length < 2) return 1.0;

    final diffs = <double>[];
    for (var i = 1; i < unique.length; i++) {
      final d = unique[i] - unique[i - 1];
      if (d >= 0.09 && d <= 10.0) {
        diffs.add(d);
      }
    }
    if (diffs.isEmpty) return 1.0;
    diffs.sort();
    final median = diffs[diffs.length ~/ 2];
    for (final std in const [0.10, 0.20, 0.25, 0.50, 1.0, 2.0, 5.0]) {
      if ((median - std).abs() < std * 0.25) return std;
    }
    return 1.0;
  }

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-9) return (p - a).distance;
    final t =
        ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq;
    final clampedT = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * clampedT, a.dy + ab.dy * clampedT);
    return (p - proj).distance;
  }
}

class _RawContourCandidate {
  final int index;
  final List<Offset> points;
  final bool closed;
  final String layer;
  final double? elevation;

  const _RawContourCandidate({
    required this.index,
    required this.points,
    required this.closed,
    required this.layer,
    this.elevation,
  });

  _RawContourCandidate withElevation(double newElevation) =>
      _RawContourCandidate(
        index: index,
        points: points,
        closed: closed,
        layer: layer,
        elevation: newElevation,
      );
}
