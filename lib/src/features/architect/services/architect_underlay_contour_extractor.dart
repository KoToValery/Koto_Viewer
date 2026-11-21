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
  final String layer;
  final double boxRadius;

  const _ExtractedElevationText({
    required this.position,
    required this.value,
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
        final parsed = _parseNumericElevation(entity.text);
        if (parsed != null) {
          final pos = frame.toModel(mapPoint(entity.alignPoint ?? entity.insertPoint));
          final modelHeight = (entity.height * scaleAbs) / frame.unitsPerMeter;
          final boxR = math.max(
            0.35,
            math.min(3.5, modelHeight * math.max(2.0, entity.text.trim().length * 0.45)),
          );
          texts.add(
            _ExtractedElevationText(
              position: pos,
              value: parsed,
              layer: effectiveLayer,
              boxRadius: boxR,
            ),
          );
        }
      } else if (entity is DxfMText) {
        final clean = entity.cleanText;
        final parsed = _parseNumericElevation(clean);
        if (parsed != null) {
          final pos = frame.toModel(mapPoint(entity.insertPoint));
          final modelHeight = (entity.height * scaleAbs) / frame.unitsPerMeter;
          final boxR = math.max(
            0.35,
            math.min(3.5, modelHeight * math.max(2.0, clean.trim().length * 0.45)),
          );
          texts.add(
            _ExtractedElevationText(
              position: pos,
              value: parsed,
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
  static ArchitectPickedContourCandidate? pickAt({
    required DxfDocument document,
    required BimCoordinateFrame frame,
    required Map<String, bool> layerVisibility,
    required Offset modelPoint,
    required double hitToleranceMeters,
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

    final suggestedElev =
        resolvedElev ??
        capturedGapTextElev ??
        _nearestTextElevation(chain, index.texts, maxDist: 1.5);

    return ArchitectPickedContourCandidate(
      points: chain,
      closed: closed,
      suggestedElevation: suggestedElev,
      sourceLayer: bestCurve.layer,
      anchorPoint: bestAnchor,
    );
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
    if (isClosed) chain.removeLast();
    return (
      points: chain,
      closed: isClosed,
      elevation: elev,
      gapTextElevation: gapElev,
    );
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
    // 1. Direct endpoint connection within joinTol
    _ExtractedCurve? bestCurve;
    var bestReverse = false;
    var bestScore = double.infinity;
    final minDot = allowSharpCorners ? -0.45 : 0.25;

    for (final c in index.curves) {
      if (used.contains(c.id) || c.closed || c.points.length < 2) continue;
      if (c.layer != layer) continue;
      for (final reverse in [false, true]) {
        final candStart = reverse ? c.points.last : c.points.first;
        final d = (candStart - endPt).distance;
        if (d > joinTol) continue;
        final candDir = _startTangent(c.points, reverse: reverse);
        if (dir != null && candDir != null) {
          final dot = dir.dx * candDir.dx + dir.dy * candDir.dy;
          if (dot < minDot) continue;
          final score = d + (1.0 - dot) * 0.25;
          if (score < bestScore) {
            bestScore = score;
            bestCurve = c;
            bestReverse = reverse;
          }
        } else if (d < bestScore) {
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
    if (dir == null) return null;
    _ExtractedElevationText? nearbyText;
    for (final txt in index.texts) {
      final dText = (txt.position - endPt).distance;
      if (dText <= txt.boxRadius + 2.2) {
        final toText = txt.position - endPt;
        if (toText.distance > 1e-4) {
          final uText = toText / toText.distance;
          if (dir.dx * uText.dx + dir.dy * uText.dy > 0.35) {
            nearbyText = txt;
            break;
          }
        }
      }
    }
    if (nearbyText == null) return null;

    var bestGapScore = double.infinity;
    for (final c in index.curves) {
      if (used.contains(c.id) || c.closed || c.points.length < 2) continue;
      if (c.layer != layer) continue;
      for (final reverse in [false, true]) {
        final candStart = reverse ? c.points.last : c.points.first;
        final gap = candStart - endPt;
        final gapLen = gap.distance;
        if (gapLen < joinTol || gapLen > 4.2) continue;
        final uGap = gap / gapLen;
        final align = dir.dx * uGap.dx + dir.dy * uGap.dy;
        if (align < 0.55) continue;
        final candDir = _startTangent(c.points, reverse: reverse);
        if (candDir != null &&
            (dir.dx * candDir.dx + dir.dy * candDir.dy) < 0.45) {
          continue;
        }
        // Check that gap passes near the elevation text position
        final closestToText = _closestPointOnSeg(nearbyText.position, endPt, candStart);
        if ((closestToText - nearbyText.position).distance >
            nearbyText.boxRadius + 1.0) {
          continue;
        }
        final score = gapLen + (1.0 - align) * 2.0;
        if (score < bestGapScore) {
          bestGapScore = score;
          bestCurve = c;
          bestReverse = reverse;
        }
      }
    }

    if (bestCurve != null) {
      return (
        curve: bestCurve,
        reverse: bestReverse,
        gapTextElevation: nearbyText.value,
      );
    }
    return null;
  }

  static Offset? _endTangent(List<Offset> pts, {required bool atEnd}) {
    if (pts.length < 2) return null;
    final d = atEnd
        ? (pts.last - pts[pts.length - 2])
        : (pts.first - pts[1]);
    return d.distance > 1e-6 ? d / d.distance : null;
  }

  static Offset? _startTangent(List<Offset> pts, {required bool reverse}) {
    if (pts.length < 2) return null;
    final d = reverse
        ? (pts[pts.length - 2] - pts.last)
        : (pts[1] - pts.first);
    return d.distance > 1e-6 ? d / d.distance : null;
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

  static double? _parseNumericElevation(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned.length > 16) return null;
    cleaned = cleaned.replaceAll(RegExp(r'\\[A-Za-z0-9]+;'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[{}]'), '').trim();
    final normalized = cleaned.replaceAll(',', '.');
    final match = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)\s*(?:m|м)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final val = double.tryParse(match.group(1)!);
    if (val == null || !val.isFinite || val.abs() > 8900) return null;
    return val;
  }

  static double? _nearestTextElevation(
    List<Offset> chain,
    List<_ExtractedElevationText> texts, {
    required double maxDist,
  }) {
    if (chain.isEmpty || texts.isEmpty) return null;
    double? bestVal;
    var bestD = maxDist;
    for (final txt in texts) {
      final hit = _closestOnCurve(chain, txt.position, closed: false);
      if (hit.distance < bestD) {
        bestD = hit.distance;
        bestVal = txt.value;
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
