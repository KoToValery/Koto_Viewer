import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_math.dart';
import '../models/architect_landscape_models.dart';
import 'architect_landscape_tool.dart';

class _ExtractedCurve {
  final int id;
  final List<Offset> points;
  final bool closed;
  final String layer;
  final double? elevation;
  final Rect bounds;

  _ExtractedCurve({
    required this.id,
    required this.points,
    required this.closed,
    required this.layer,
    required this.elevation,
    required this.bounds,
  });
}

class _ExtractedElevationText {
  final Offset position;
  final double value;
  final int decimalPlaces;
  final String layer;
  final double boxRadius;

  const _ExtractedElevationText({
    required this.position,
    required this.value,
    required this.decimalPlaces,
    required this.layer,
    required this.boxRadius,
  });
}

class _FlattenedUnderlayIndex {
  final BimCoordinateFrame frame;
  final int visibilityHash;
  final List<_ExtractedCurve> curves;
  final List<_ExtractedElevationText> texts;

  const _FlattenedUnderlayIndex({
    required this.frame,
    required this.visibilityHash,
    required this.curves,
    required this.texts,
  });
}

/// Interactive CAD underlay contour extractor supporting:
/// - `DxfLwPolyline` (including bulge arcs & DXF 38 elevation)
/// - `DxfPolyline` (2D & 3D polylines with vertex Z & bulges)
/// - `DxfSpline` (exact NURBS evaluation via `DxfMath.evaluateSpline`)
/// - `DxfLine` / `DxfArc` chains
/// - Nested `DxfInsert` block transformations
/// - Endpoint chain stitching & inline elevation-text gap bridging
/// - Exact clipping against Terrain outer boundary polygons
class ArchitectUnderlayContourExtractor {
  ArchitectUnderlayContourExtractor._();

  static final _cache = Expando<_FlattenedUnderlayIndex>();

  static int _hashVisibility(Map<String, bool> visibility) {
    if (visibility.isEmpty) return 0;
    final keys = visibility.keys.toList()..sort();
    return Object.hashAll([
      for (final k in keys) Object.hash(k, visibility[k]),
    ]);
  }

  static _FlattenedUnderlayIndex _indexFor(
    DxfDocument doc,
    BimCoordinateFrame frame,
    Map<String, bool> layerVisibility,
  ) {
    final visHash = _hashVisibility(layerVisibility);
    final existing = _cache[doc];
    if (existing != null &&
        existing.frame == frame &&
        existing.visibilityHash == visHash) {
      return existing;
    }

    final curves = <_ExtractedCurve>[];
    final texts = <_ExtractedElevationText>[];
    var nextId = 0;

    bool isLayerVisible(String layer) {
      final docLayer = doc.layers[layer];
      if (docLayer != null && (!docLayer.isVisible || docLayer.isFrozen)) {
        return layerVisibility[layer] ?? false;
      }
      return layerVisibility[layer] ?? true;
    }

    void addCurve(
      List<Offset> cadPts, {
      required bool closed,
      required String layer,
      required double? elevation,
      required Offset Function(Offset) mapPoint,
    }) {
      if (cadPts.length < 2) return;
      final modelPts = <Offset>[];
      for (final raw in cadPts) {
        final mp = frame.toModel(mapPoint(raw));
        if (!mp.dx.isFinite || !mp.dy.isFinite) continue;
        if (modelPts.isEmpty || (modelPts.last - mp).distance > 1e-4) {
          modelPts.add(mp);
        }
      }
      if (closed &&
          modelPts.length >= 3 &&
          (modelPts.first - modelPts.last).distance <= 1e-3) {
        modelPts.removeLast();
      }
      if (modelPts.length < 2) return;
      if (closed && modelPts.length < 3) return;
      final bounds = _boundsOf(modelPts);
      // Skip degenerate tiny ticks (< 5 cm)
      if (math.max(bounds.width, bounds.height) < 0.05) return;
      curves.add(
        _ExtractedCurve(
          id: nextId++,
          points: modelPts,
          closed: closed,
          layer: layer,
          elevation: elevation,
          bounds: bounds,
        ),
      );
    }

    void visitEntity(
      DxfEntity entity,
      Offset Function(Offset) mapPoint,
      double scaleAbs,
      String? parentLayer,
      int depth,
    ) {
      if (entity.isPaperSpace) return;
      if (entity is DxfText && entity.isInvisible) return;
      final effectiveLayer = (entity.layer == '0' && parentLayer != null)
          ? parentLayer
          : entity.layer;
      if (!isLayerVisible(effectiveLayer)) return;

      if (entity is DxfInsert) {
        if (depth >= 6) return;
        final block = doc.blocks[entity.blockName];
        if (block == null || block.entities.isEmpty) return;
        final rad = entity.rotationDeg * math.pi / 180.0;
        final cosA = math.cos(rad);
        final sinA = math.sin(rad);
        final bx = block.basePoint.dx;
        final by = block.basePoint.dy;

        Offset childMap(Offset pt) {
          final lx = (pt.dx - bx) * entity.scaleX;
          final ly = (pt.dy - by) * entity.scaleY;
          final rx = lx * cosA - ly * sinA;
          final ry = lx * sinA + ly * cosA;
          return mapPoint(
            Offset(entity.insertPoint.dx + rx, entity.insertPoint.dy + ry),
          );
        }

        final nextScale =
            scaleAbs * math.max(entity.scaleX.abs(), entity.scaleY.abs());
        for (final child in block.entities) {
          visitEntity(child, childMap, nextScale, effectiveLayer, depth + 1);
        }
        return;
      }

      if (entity is DxfLwPolyline) {
        final expanded = _expandPolylineVertices(
          entity.vertices,
          isClosed: entity.isClosed,
        );
        final elev = entity.elevation.abs() > 1e-4 && entity.elevation.abs() < 9000
            ? entity.elevation
            : null;
        addCurve(
          expanded,
          closed: entity.isClosed,
          layer: effectiveLayer,
          elevation: elev,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfPolyline) {
        final expanded = _expandPolylineVertices(
          entity.vertices,
          isClosed: entity.isClosed,
        );
        final elev = _resolvePolylineElevation(entity);
        addCurve(
          expanded,
          closed: entity.isClosed,
          layer: effectiveLayer,
          elevation: elev,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfSpline) {
        final pts = entity.controlPoints.isNotEmpty
            ? DxfMath.evaluateSpline(
                entity.degree,
                entity.controlPoints,
                knots: entity.knots,
                weights: entity.weights,
                sampleCount: math.max(48, entity.controlPoints.length * 10),
              )
            : entity.fitPoints;
        final elev = entity.elevation != null &&
                entity.elevation!.abs() > 1e-4 &&
                entity.elevation!.abs() < 9000
            ? entity.elevation
            : null;
        addCurve(
          pts,
          closed: entity.isClosed,
          layer: effectiveLayer,
          elevation: elev,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfLine) {
        addCurve(
          [entity.p1, entity.p2],
          closed: false,
          layer: effectiveLayer,
          elevation: null,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfArc) {
        final pts = _sampleArc(entity);
        addCurve(
          pts,
          closed: false,
          layer: effectiveLayer,
          elevation: null,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfCircle) {
        final pts = [
          for (var i = 0; i < 24; i++)
            Offset(
              entity.center.dx + entity.radius * math.cos(i * math.pi / 12.0),
              entity.center.dy + entity.radius * math.sin(i * math.pi / 12.0),
            ),
        ];
        addCurve(
          pts,
          closed: true,
          layer: effectiveLayer,
          elevation: null,
          mapPoint: mapPoint,
        );
      } else if (entity is DxfText) {
        final parsed = _parseElevationWithMeta(entity.text);
        if (parsed != null) {
          final textLen = entity.text.trim().length;
          final wCad = math.max(entity.height, textLen * entity.height * 0.65);
          final anchorCad =
              (entity.hAlign != 0 || entity.vAlign != 0) &&
                  entity.alignPoint != null
              ? entity.alignPoint!
              : entity.insertPoint;
          final ox = switch (entity.hAlign) {
            0 => 0.5 * wCad,
            2 => -0.5 * wCad,
            _ => 0.0,
          };
          final oy = switch (entity.vAlign) {
            0 || 1 => 0.5 * entity.height,
            3 => -0.5 * entity.height,
            _ => 0.0,
          };
          final rad = entity.rotationDeg * math.pi / 180.0;
          final cosA = math.cos(rad);
          final sinA = math.sin(rad);
          final centerCad = Offset(
            anchorCad.dx + ox * cosA - oy * sinA,
            anchorCad.dy + ox * sinA + oy * cosA,
          );
          final pos = frame.toModel(mapPoint(centerCad));
          final edgePos = frame.toModel(
            mapPoint(
              Offset(
                anchorCad.dx + wCad * cosA,
                anchorCad.dy + wCad * sinA,
              ),
            ),
          );
          final anchorPos = frame.toModel(mapPoint(anchorCad));
          final modelWidth = (edgePos - anchorPos).distance;
          final modelHeight = (entity.height * scaleAbs) / frame.unitsPerMeter;
          final boxR = math.max(
            0.45,
            math.min(6.0, math.max(modelWidth * 0.65, modelHeight * 1.6)),
          );
          texts.add(
            _ExtractedElevationText(
              position: pos,
              value: parsed.value,
              decimalPlaces: parsed.decimalPlaces,
              layer: effectiveLayer,
              boxRadius: boxR,
            ),
          );
        }
      } else if (entity is DxfMText) {
        final clean = entity.cleanText;
        final parsed = _parseElevationWithMeta(clean);
        if (parsed != null) {
          final textLen = clean.trim().length;
          final estW = math.max(entity.height, textLen * entity.height * 0.65);
          final wCad = (entity.refWidth != null && entity.refWidth! > 0)
              ? math.min(entity.refWidth!, textLen * entity.height * 0.72)
              : estW;
          final col = (entity.attachmentPoint - 1).clamp(0, 8) % 3;
          final row = (entity.attachmentPoint - 1).clamp(0, 8) ~/ 3;
          final ox = col == 0 ? 0.5 * wCad : (col == 2 ? -0.5 * wCad : 0.0);
          final oy = row == 0
              ? -0.5 * entity.height
              : (row == 2 ? 0.5 * entity.height : 0.0);
          final rad =
              (entity.directionVector != null &&
                  entity.directionVector!.distance > 1e-6)
              ? math.atan2(
                  entity.directionVector!.dy,
                  entity.directionVector!.dx,
                )
              : entity.rotationDeg * math.pi / 180.0;
          final cosA = math.cos(rad);
          final sinA = math.sin(rad);
          final anchorCad = entity.insertPoint;
          final centerCad = Offset(
            anchorCad.dx + ox * cosA - oy * sinA,
            anchorCad.dy + ox * sinA + oy * cosA,
          );
          final pos = frame.toModel(mapPoint(centerCad));
          final edgePos = frame.toModel(
            mapPoint(
              Offset(
                anchorCad.dx + wCad * cosA,
                anchorCad.dy + wCad * sinA,
              ),
            ),
          );
          final anchorPos = frame.toModel(mapPoint(anchorCad));
          final modelWidth = (edgePos - anchorPos).distance;
          final modelHeight = (entity.height * scaleAbs) / frame.unitsPerMeter;
          final boxR = math.max(
            0.45,
            math.min(6.0, math.max(modelWidth * 0.65, modelHeight * 1.6)),
          );
          texts.add(
            _ExtractedElevationText(
              position: pos,
              value: parsed.value,
              decimalPlaces: parsed.decimalPlaces,
              layer: effectiveLayer,
              boxRadius: boxR,
            ),
          );
        }
      }
    }

    for (final entity in doc.entities) {
      visitEntity(entity, (p) => p, 1.0, null, 0);
    }

    final built = _FlattenedUnderlayIndex(
      frame: frame,
      visibilityHash: visHash,
      curves: curves,
      texts: texts,
    );
    _cache[doc] = built;
    return built;
  }

  /// Picks the contour under [modelPoint] within [hitToleranceMeters],
  /// automatically stitching connected segments and bridging elevation-text gaps.
  /// Set [detectElevation] to `false` to disable automatic elevation capture
  /// while still stitching split segments and inline text gaps.
  static ArchitectPickedContourCandidate? pickAt({
    required DxfDocument document,
    required BimCoordinateFrame frame,
    required Map<String, bool> layerVisibility,
    required Offset modelPoint,
    required double hitToleranceMeters,
    bool detectElevation = true,
  }) {
    final index = _indexFor(document, frame, layerVisibility);
    if (index.curves.isEmpty) return null;

    _ExtractedCurve? bestCurve;
    var bestDist = hitToleranceMeters;
    var bestAnchor = modelPoint;

    for (final curve in index.curves) {
      if (!curve.bounds.inflate(bestDist).contains(modelPoint)) continue;
      final hit = _closestOnCurve(curve.points, modelPoint, closed: curve.closed);
      if (hit.distance <= bestDist) {
        bestDist = hit.distance;
        bestCurve = curve;
        bestAnchor = hit.point;
      }
    }

    if (bestCurve == null) return null;

    final used = <int>{bestCurve.id};
    var chain = List<Offset>.from(bestCurve.points);
    var closed = bestCurve.closed;
    double? capturedGapTextElev;
    var resolvedElev = bestCurve.elevation;

    if (!closed) {
      final result = _stitchChain(
        initialChain: chain,
        layer: bestCurve.layer,
        index: index,
        used: used,
        initialElev: resolvedElev,
      );
      chain = result.points;
      closed = result.closed;
      resolvedElev ??= result.elevation;
      capturedGapTextElev = result.gapTextElevation;
    }

    final suggestedElev = detectElevation
        ? (resolvedElev ??
            capturedGapTextElev ??
            _nearestTextElevation(chain, index.texts, maxDist: 1.5))
        : null;

    return ArchitectPickedContourCandidate(
      points: chain,
      closed: closed,
      suggestedElevation: suggestedElev,
      sourceLayer: bestCurve.layer,
      anchorPoint: bestAnchor,
    );
  }

  /// Extracts all stitched contours (bridging endpoint chains and inline
  /// elevation-text gaps) for whole-document geodetic analysis.
  static List<ArchitectPickedContourCandidate> extractStitchedContours({
    required DxfDocument document,
    required BimCoordinateFrame frame,
    Map<String, bool> layerVisibility = const {},
  }) {
    final index = _indexFor(document, frame, layerVisibility);
    if (index.curves.isEmpty) return const [];
    final used = <int>{};
    final out = <ArchitectPickedContourCandidate>[];
    for (final c in index.curves) {
      if (used.contains(c.id)) continue;
      used.add(c.id);
      if (c.closed) {
        out.add(
          ArchitectPickedContourCandidate(
            points: c.points,
            closed: true,
            suggestedElevation: c.elevation,
            sourceLayer: c.layer,
          ),
        );
        continue;
      }
      final result = _stitchChain(
        initialChain: c.points,
        layer: c.layer,
        index: index,
        used: used,
        initialElev: c.elevation,
      );
      final elev = result.elevation ?? result.gapTextElevation;
      out.add(
        ArchitectPickedContourCandidate(
          points: result.points,
          closed: result.closed,
          suggestedElevation: elev,
          sourceLayer: c.layer,
        ),
      );
    }
    return out;
  }

  /// Clips a picked polyline [points] cleanly to the outer [boundaries].
  /// Returns 1 or more sub-chains lying inside the boundaries; if [boundaries]
  /// has no outer polygons, returns the original curve unchanged.
  static List<({List<Offset> points, bool closed})> clipToBoundaries({
    required List<Offset> points,
    required bool closed,
    required List<ArchitectTerrainBoundary> boundaries,
  }) {
    final outers = [
      for (final b in boundaries)
        if (b.polygon.length >= 3 && !b.isFlatPad && !b.isHole) b.polygon,
    ];
    if (outers.isEmpty || points.length < 2) {
      return [(points: points, closed: closed)];
    }

    bool insideAny(Offset p) =>
        outers.any((poly) => BimPolygonGeometry.contains(poly, p));

    final segCount = closed ? points.length : points.length - 1;
    final result = <({List<Offset> points, bool closed})>[];
    var current = <Offset>[];
    var clippedAnyEdge = false;

    for (var i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ts = <double>{0.0, 1.0};

      for (final poly in outers) {
        for (var j = 0; j < poly.length; j++) {
          final c = poly[j];
          final d = poly[(j + 1) % poly.length];
          final t = _segmentIntersectionT(a, b, c, d);
          if (t != null && t > 1e-5 && t < 1.0 - 1e-5) {
            ts.add(t);
            clippedAnyEdge = true;
          }
        }
      }

      final sortedTs = ts.toList()..sort();
      for (var k = 0; k < sortedTs.length - 1; k++) {
        final t0 = sortedTs[k];
        final t1 = sortedTs[k + 1];
        if (t1 - t0 < 1e-5) continue;
        final p0 = Offset.lerp(a, b, t0)!;
        final p1 = Offset.lerp(a, b, t1)!;
        final mid = Offset.lerp(p0, p1, 0.5)!;
        if (insideAny(mid)) {
          if (current.isEmpty) {
            current.add(p0);
          } else if ((current.last - p0).distance > 1e-4) {
            if (current.length >= 2) {
              result.add((points: current, closed: false));
            }
            current = [p0];
          }
          if ((current.last - p1).distance > 1e-4) {
            current.add(p1);
          }
        } else {
          if (current.length >= 2) {
            result.add((points: current, closed: false));
          }
          current = <Offset>[];
        }
      }
    }

    if (current.length >= 2) {
      final isStillClosed =
          closed &&
          !clippedAnyEdge &&
          current.length >= 3;
      if (isStillClosed && (current.first - current.last).distance < 1e-3) {
        current.removeLast();
      }
      result.add((points: current, closed: isStillClosed));
    }

    return result;
  }

  /// Stitches connected open [pool] polylines onto [initialChain] by matching
  /// touching endpoints and tangent continuity within [joinTol].
  static ({List<Offset> points, bool closed}) stitchOpenCurves({
    required List<Offset> initialChain,
    required List<List<Offset>> pool,
    required Set<int> usedIndices,
    double joinTol = 0.08,
  }) {
    final curves = [
      for (var i = 0; i < pool.length; i++)
        _ExtractedCurve(
          id: i,
          points: pool[i],
          closed: false,
          layer: '',
          elevation: null,
          bounds: pool[i].isEmpty ? Rect.zero : _boundsOf(pool[i]),
        ),
    ];
    final result = _stitchChain(
      initialChain: initialChain,
      layer: '',
      index: _FlattenedUnderlayIndex(
        frame: BimCoordinateFrame(origin: Offset.zero, unitsPerMeter: 1.0),
        visibilityHash: 0,
        curves: curves,
        texts: const [],
      ),
      used: usedIndices,
      initialElev: null,
      joinTol: joinTol,
      allowSharpCorners: true,
    );
    return (points: result.points, closed: result.closed);
  }

  static ({
    List<Offset> points,
    bool closed,
    double? elevation,
    double? gapTextElevation,
  })
  _stitchChain({
    required List<Offset> initialChain,
    required String layer,
    required _FlattenedUnderlayIndex index,
    required Set<int> used,
    required double? initialElev,
    double joinTol = 0.08,
    bool allowSharpCorners = false,
  }) {
    final chain = List<Offset>.from(initialChain);
    var elev = initialElev;
    double? gapElev;
    const maxSteps = 256;

    for (var step = 0; step < maxSteps; step++) {
      if ((chain.first - chain.last).distance <= joinTol && chain.length >= 4) {
        chain.removeLast();
        return (
          points: chain,
          closed: true,
          elevation: elev,
          gapTextElevation: gapElev,
        );
      }

      var extended = false;
      for (final atEnd in [true, false]) {
        final endPt = atEnd ? chain.last : chain.first;
        final dir = _endTangent(chain, atEnd: atEnd);
        final match = _findNextSegment(
          endPt: endPt,
          dir: dir,
          layer: layer,
          index: index,
          used: used,
          joinTol: joinTol,
          allowSharpCorners: allowSharpCorners,
        );
        if (match != null) {
          used.add(match.curve.id);
          elev ??= match.curve.elevation;
          gapElev ??= match.gapTextElevation;
          final segPts = match.reverse
              ? match.curve.points.reversed.toList()
              : match.curve.points;
          if (atEnd) {
            for (final p in segPts.skip(match.gapTextElevation == null ? 1 : 0)) {
              if ((chain.last - p).distance > 1e-4) chain.add(p);
            }
          } else {
            final prefix = <Offset>[];
            for (var i = segPts.length - (match.gapTextElevation == null ? 2 : 1);
                i >= 0;
                i--) {
              prefix.add(segPts[i]);
            }
            for (final p in prefix) {
              if ((chain.first - p).distance > 1e-4) chain.insert(0, p);
            }
          }
          extended = true;
          break;
        }
      }
      if (!extended) break;
    }

    final isClosed =
        chain.length >= 4 && (chain.first - chain.last).distance <= joinTol;
    if (isClosed) {
      chain.removeLast();
    } else if (chain.length >= 4 && index.texts.isNotEmpty) {
      final selfGapElev = _checkSelfClosureAcrossTextGap(chain, index.texts, joinTol);
      if (selfGapElev != null) {
        gapElev ??= selfGapElev;
        return (
          points: chain,
          closed: true,
          elevation: elev,
          gapTextElevation: gapElev,
        );
      }
    }
    return (
      points: chain,
      closed: isClosed,
      elevation: elev,
      gapTextElevation: gapElev,
    );
  }

  static double? _checkSelfClosureAcrossTextGap(
    List<Offset> chain,
    List<_ExtractedElevationText> texts,
    double joinTol,
  ) {
    final endPt = chain.last;
    final startPt = chain.first;
    final gap = startPt - endPt;
    final gapLen = gap.distance;
    if (gapLen <= joinTol || gapLen > 12.0) return null;
    final endDir = _endTangent(chain, atEnd: true);
    final startDir = _startTangent(chain, reverse: false);
    if (endDir == null || startDir == null) return null;
    final uGap = gap / gapLen;
    if (endDir.dx * uGap.dx + endDir.dy * uGap.dy < 0.50) return null;
    if (uGap.dx * startDir.dx + uGap.dy * startDir.dy < 0.40) return null;

    _ExtractedElevationText? bestTxt;
    var bestScore = double.infinity;
    for (final txt in texts) {
      final maxGap = math.max(4.5, txt.boxRadius * 2.6 + 1.2).clamp(4.5, 12.0);
      if (gapLen > maxGap) continue;
      final closest = _closestPointOnSeg(txt.position, endPt, startPt);
      final dTxt = (closest - txt.position).distance;
      if (dTxt <= txt.boxRadius + 1.1) {
        final score = dTxt + (txt.decimalPlaces == 2 ? 0.0 : 0.4);
        if (score < bestScore) {
          bestScore = score;
          bestTxt = txt;
        }
      }
    }
    return bestTxt?.value;
  }

  static ({
    _ExtractedCurve curve,
    bool reverse,
    double? gapTextElevation,
  })?
  _findNextSegment({
    required Offset endPt,
    required Offset? dir,
    required String layer,
    required _FlattenedUnderlayIndex index,
    required Set<int> used,
    required double joinTol,
    bool allowSharpCorners = false,
  }) {
    // 1. Direct endpoint connection within joinTol (or slightly wider for collinear breaks)
    _ExtractedCurve? bestCurve;
    var bestReverse = false;
    var bestScore = double.infinity;
    final minDot = allowSharpCorners ? -0.45 : 0.25;
    final collinearTol = math.max(joinTol, 0.22);

    for (final c in index.curves) {
      if (used.contains(c.id) || c.closed || c.points.length < 2) continue;
      if (c.layer != layer) continue;
      for (final reverse in [false, true]) {
        final candStart = reverse ? c.points.last : c.points.first;
        final d = (candStart - endPt).distance;
        if (d > collinearTol) continue;
        final candDir = _startTangent(c.points, reverse: reverse);
        if (dir != null && candDir != null) {
          final dot = dir.dx * candDir.dx + dir.dy * candDir.dy;
          if (d > joinTol && dot < 0.88) continue;
          if (dot < minDot) continue;
          final score = d + (1.0 - dot) * 0.25;
          if (score < bestScore) {
            bestScore = score;
            bestCurve = c;
            bestReverse = reverse;
          }
        } else if (d <= joinTol && d < bestScore) {
          bestScore = d;
          bestCurve = c;
          bestReverse = reverse;
        }
      }
    }
    if (bestCurve != null) {
      return (curve: bestCurve, reverse: bestReverse, gapTextElevation: null);
    }

    // 2. Text-gap bridging across inline elevation labels
    if (dir == null || index.texts.isEmpty) return null;
    final candidateTexts = <_ExtractedElevationText>[];
    for (final txt in index.texts) {
      final toText = txt.position - endPt;
      final dText = toText.distance;
      final maxReach = math.max(3.5, txt.boxRadius * 2.2 + 2.2).clamp(3.5, 9.0);
      if (dText <= maxReach) {
        if (dText <= txt.boxRadius + 0.85) {
          candidateTexts.add(txt);
        } else {
          final uText = toText / dText;
          if (dir.dx * uText.dx + dir.dy * uText.dy > 0.25) {
            candidateTexts.add(txt);
          }
        }
      }
    }
    if (candidateTexts.isEmpty) return null;

    var bestGapScore = double.infinity;
    _ExtractedElevationText? bestGapText;
    for (final c in index.curves) {
      if (used.contains(c.id) || c.closed || c.points.length < 2) continue;
      if (c.layer != layer) continue;
      for (final reverse in [false, true]) {
        final candStart = reverse ? c.points.last : c.points.first;
        final gap = candStart - endPt;
        final gapLen = gap.distance;
        if (gapLen < joinTol || gapLen > 12.0) continue;
        final uGap = gap / gapLen;
        final align = dir.dx * uGap.dx + dir.dy * uGap.dy;
        if (align < 0.50) continue;
        final candDir = _startTangent(c.points, reverse: reverse);
        if (candDir != null &&
            (dir.dx * candDir.dx + dir.dy * candDir.dy) < 0.40 &&
            (uGap.dx * candDir.dx + uGap.dy * candDir.dy) < 0.45) {
          continue;
        }
        // Check against all nearby elevation texts so one irrelevant label cannot mask the real one
        for (final txt in candidateTexts) {
          final maxGap = math.max(4.5, txt.boxRadius * 2.6 + 1.2).clamp(4.5, 12.0);
          if (gapLen > maxGap) continue;
          final closestToText = _closestPointOnSeg(txt.position, endPt, candStart);
          final textDist = (closestToText - txt.position).distance;
          if (textDist > txt.boxRadius + 1.1) continue;
          final score =
              gapLen +
              (1.0 - align) * 2.0 +
              textDist * 0.6 +
              (txt.decimalPlaces == 2 ? 0.0 : 0.4);
          if (score < bestGapScore) {
            bestGapScore = score;
            bestCurve = c;
            bestReverse = reverse;
            bestGapText = txt;
          }
        }
      }
    }

    if (bestCurve != null && bestGapText != null) {
      return (
        curve: bestCurve,
        reverse: bestReverse,
        gapTextElevation: bestGapText.value,
      );
    }
    return null;
  }

  static Offset? _endTangent(List<Offset> pts, {required bool atEnd}) {
    if (pts.length < 2) return null;
    if (atEnd) {
      final tip = pts.last;
      for (var i = pts.length - 2; i >= 0; i--) {
        final d = tip - pts[i];
        if (d.distance >= 0.15 || i == 0) {
          return d.distance > 1e-6 ? d / d.distance : null;
        }
      }
    } else {
      final tip = pts.first;
      for (var i = 1; i < pts.length; i++) {
        final d = tip - pts[i];
        if (d.distance >= 0.15 || i == pts.length - 1) {
          return d.distance > 1e-6 ? d / d.distance : null;
        }
      }
    }
    return null;
  }

  static Offset? _startTangent(List<Offset> pts, {required bool reverse}) {
    if (pts.length < 2) return null;
    if (reverse) {
      final tip = pts.last;
      for (var i = pts.length - 2; i >= 0; i--) {
        final d = pts[i] - tip;
        if (d.distance >= 0.15 || i == 0) {
          return d.distance > 1e-6 ? d / d.distance : null;
        }
      }
    } else {
      final tip = pts.first;
      for (var i = 1; i < pts.length; i++) {
        final d = pts[i] - tip;
        if (d.distance >= 0.15 || i == pts.length - 1) {
          return d.distance > 1e-6 ? d / d.distance : null;
        }
      }
    }
    return null;
  }

  static List<Offset> _expandPolylineVertices(
    List<DxfPolylineVertex> vertices, {
    required bool isClosed,
  }) {
    if (vertices.isEmpty) return const [];
    final pts = <Offset>[vertices.first.offset];
    final count = vertices.length;
    final segCount = isClosed ? count : count - 1;
    for (var i = 0; i < segCount; i++) {
      final v1 = vertices[i];
      final v2 = vertices[(i + 1) % count];
      if (v1.bulge.abs() > 1e-6) {
        final arcPts = DxfMath.generateBulgeArcPoints(
          v1.offset,
          v2.offset,
          v1.bulge,
          maxSegments: 24,
        );
        for (var k = 1; k < arcPts.length; k++) {
          pts.add(arcPts[k]);
        }
      } else {
        pts.add(v2.offset);
      }
    }
    return pts;
  }

  static double? _resolvePolylineElevation(DxfPolyline entity) {
    if (entity.elevation.abs() > 1e-4 && entity.elevation.abs() < 9000) {
      return entity.elevation;
    }
    if (entity.vertices.isEmpty) return null;
    final firstZ = entity.vertices.first.z;
    if (firstZ.abs() > 1e-4 &&
        firstZ.abs() < 9000 &&
        entity.vertices.every((v) => (v.z - firstZ).abs() < 1e-3)) {
      return firstZ;
    }
    return null;
  }

  static List<Offset> _sampleArc(DxfArc arc) {
    var sweep = arc.endAngleDeg - arc.startAngleDeg;
    if (sweep <= 0) sweep += 360.0;
    final steps = (sweep / 8.0).ceil().clamp(6, 48);
    final pts = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final rad = (arc.startAngleDeg + sweep * (i / steps)) * math.pi / 180.0;
      pts.add(
        Offset(
          arc.center.dx + arc.radius * math.cos(rad),
          arc.center.dy + arc.radius * math.sin(rad),
        ),
      );
    }
    return pts;
  }

  /// Parses geodetic elevation labels, rejecting bare integers (e.g. parcel/plot IDs)
  /// and requiring 2-3 decimal digits (e.g. `542.50`, `104,25`).
  static ({double value, int decimalPlaces})? parseElevationText(String raw) =>
      _parseElevationWithMeta(raw);

  static ({double value, int decimalPlaces})? _parseElevationWithMeta(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned.length > 18) return null;
    cleaned = cleaned.replaceAll(RegExp(r'\\[A-Za-z0-9]+;'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '').trim();
    final normalized = cleaned.replaceAll(',', '.');
    final match = RegExp(
      r'^(?:[HKZК]\s*=?\s*)?([+-]?\d+\.(\d{2,3}))\s*(?:m|м)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final val = double.tryParse(match.group(1)!);
    if (val == null || !val.isFinite || val.abs() > 8900) return null;
    return (value: val, decimalPlaces: match.group(2)!.length);
  }

  static double? _nearestTextElevation(
    List<Offset> chain,
    List<_ExtractedElevationText> texts, {
    required double maxDist,
  }) {
    if (chain.isEmpty || texts.isEmpty) return null;
    double? bestVal;
    var bestScore = maxDist + 0.5;
    for (final txt in texts) {
      final hit = _closestOnCurve(chain, txt.position, closed: false);
      if (hit.distance < maxDist) {
        final score = hit.distance + (txt.decimalPlaces == 2 ? 0.0 : 0.25);
        if (score < bestScore) {
          bestScore = score;
          bestVal = txt.value;
        }
      }
    }
    return bestVal;
  }

  /// Returns the minimum distance and closest point on [pts] to [query].
  static ({double distance, Offset point}) closestOnCurve(
    List<Offset> pts,
    Offset query, {
    required bool closed,
  }) =>
      _closestOnCurve(pts, query, closed: closed);

  static ({double distance, Offset point}) _closestOnCurve(
    List<Offset> pts,
    Offset query, {
    required bool closed,
  }) {
    var bestDist = double.infinity;
    var bestPt = pts.first;
    final count = closed ? pts.length : pts.length - 1;
    for (var i = 0; i < count; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final p = _closestPointOnSeg(query, a, b);
      final d = (query - p).distance;
      if (d < bestDist) {
        bestDist = d;
        bestPt = p;
      }
    }
    return (distance: bestDist, point: bestPt);
  }

  static Offset _closestPointOnSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.distanceSquared;
    if (lenSq < 1e-12) return a;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq)
        .clamp(0.0, 1.0);
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  static double? _segmentIntersectionT(
    Offset a,
    Offset b,
    Offset c,
    Offset d,
  ) {
    final r = b - a;
    final s = d - c;
    final denom = r.dx * s.dy - r.dy * s.dx;
    if (denom.abs() < 1e-10) return null;
    final ca = c - a;
    final t = (ca.dx * s.dy - ca.dy * s.dx) / denom;
    final u = (ca.dx * r.dy - ca.dy * r.dx) / denom;
    if (t >= -1e-6 && t <= 1.0 + 1e-6 && u >= -1e-6 && u <= 1.0 + 1e-6) {
      return t.clamp(0.0, 1.0);
    }
    return null;
  }

  static Rect _boundsOf(List<Offset> pts) {
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
