import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_closed_contour.dart';
import 'architect_spline_geometry.dart';
import 'architect_underlay_contour_extractor.dart';

/// Origin of a contour automatically traced for a CAD Spline.
enum ArchitectSplineTraceSource {
  underlay,
  terrainContour,
  modelCurve,
  closedRoom,
}

/// Live preview & commit payload for Spline automatic contour tracing.
class ArchitectSplineTraceCandidate {
  final List<Offset> points;
  final bool closed;
  final Offset anchorPoint;
  final double distance;
  final ArchitectSplineTraceSource source;
  final double? elevation;

  const ArchitectSplineTraceCandidate({
    required this.points,
    required this.closed,
    required this.anchorPoint,
    required this.distance,
    required this.source,
    this.elevation,
  });
}

/// Automatically traces continuous open or closed contours from:
/// 1. Imported CAD underlays (DXF polylines, 2D/3D contours, splines, arcs, blocks)
/// 2. Site-plan terrain contours & boundaries
/// 3. Active-storey CAD primitives, slabs, roofs, zones & chained segments
/// 4. Enclosed rooms / bounded faces via [ArchitectClosedContour.detect]
class ArchitectSplineContourTracer {
  ArchitectSplineContourTracer._();

  static ArchitectSplineTraceCandidate? traceAt({
    required ArchitectProject project,
    required Offset modelPoint,
    required double hitToleranceMeters,
    DxfDocument? underlayDocument,
    BimCoordinateFrame? underlayFrame,
    Map<String, bool> underlayLayerVisibility = const {},
    bool detectElevation = true,
  }) {
    ArchitectSplineTraceCandidate? best;

    void consider(ArchitectSplineTraceCandidate? cand) {
      if (cand == null || cand.points.length < 2) return;
      if (best == null || cand.distance < best!.distance - 1e-4) {
        best = cand;
      }
    }

    // 1. CAD underlay curves & topographic contours (хоризонтали)
    if (underlayDocument != null && underlayFrame != null) {
      final picked = ArchitectUnderlayContourExtractor.pickAt(
        document: underlayDocument,
        frame: underlayFrame,
        layerVisibility: underlayLayerVisibility,
        modelPoint: modelPoint,
        hitToleranceMeters: hitToleranceMeters,
        detectElevation: detectElevation,
      );
      if (picked != null && picked.points.length >= 2) {
        final anchor = picked.anchorPoint ?? modelPoint;
        final simplified = simplifyForSpline(
          picked.points,
          closed: picked.closed,
        );
        if (simplified.length >= 2) {
          consider(
            ArchitectSplineTraceCandidate(
              points: simplified,
              closed: picked.closed,
              anchorPoint: anchor,
              distance: (anchor - modelPoint).distance,
              source: ArchitectSplineTraceSource.underlay,
              elevation: detectElevation ? picked.suggestedElevation : null,
            ),
          );
        }
      }
    }

    // 2. Terrain contours & boundaries when working on Site Plan (План Терен)
    if (project.activeStorey.isSite) {
      for (final surface in [project.existingTerrain, project.proposedTerrain]) {
        for (final c in surface.contours) {
          final pts = c.resolvedPolyline(samplesPerSpan: 10);
          if (pts.length < 2) continue;
          final hit = ArchitectUnderlayContourExtractor.closestOnCurve(
            pts,
            modelPoint,
            closed: c.closed,
          );
          if (hit.distance <= hitToleranceMeters) {
            final simplified = simplifyForSpline(pts, closed: c.closed);
            if (simplified.length >= 2) {
              consider(
                ArchitectSplineTraceCandidate(
                  points: simplified,
                  closed: c.closed,
                  anchorPoint: hit.point,
                  distance: hit.distance,
                  source: ArchitectSplineTraceSource.terrainContour,
                  elevation: c.elevation,
                ),
              );
            }
          }
        }
        for (final b in surface.boundaries) {
          if (b.polygon.length < 3) continue;
          final hit = ArchitectUnderlayContourExtractor.closestOnCurve(
            b.polygon,
            modelPoint,
            closed: true,
          );
          if (hit.distance <= hitToleranceMeters) {
            consider(
              ArchitectSplineTraceCandidate(
                points: simplifyForSpline(b.polygon, closed: true),
                closed: true,
                anchorPoint: hit.point,
                distance: hit.distance,
                source: ArchitectSplineTraceSource.terrainContour,
              ),
            );
          }
        }
      }
    }

    // 3. Active storey model curves & element perimeters
    consider(
      _traceActiveStoreyCurves(
        storey: project.activeStorey,
        modelPoint: modelPoint,
        hitToleranceMeters: hitToleranceMeters,
      ),
    );

    if (best != null) return best;

    // 4. Enclosed room / bounded architectural face around interior tap
    final closedFace = ArchitectClosedContour.detect(
      project.activeStorey,
      modelPoint,
    );
    if (closedFace != null && closedFace.polygon.length >= 3) {
      final simplified = simplifyForSpline(closedFace.polygon, closed: true);
      if (simplified.length >= 3) {
        return ArchitectSplineTraceCandidate(
          points: simplified,
          closed: true,
          anchorPoint: modelPoint,
          distance: hitToleranceMeters,
          source: ArchitectSplineTraceSource.closedRoom,
        );
      }
    }
    return null;
  }

  static ArchitectSplineTraceCandidate? _traceActiveStoreyCurves({
    required ArchitectStorey storey,
    required Offset modelPoint,
    required double hitToleranceMeters,
  }) {
    final openPool = <List<Offset>>[];
    final closedCurves = <List<Offset>>[];

    for (final p in storey.cadPrimitives) {
      switch (p.type) {
        case CadPrimitiveType.line:
          if ((p.endPoint - p.startPoint).distance > 1e-4) {
            openPool.add([p.startPoint, p.endPoint]);
          }
        case CadPrimitiveType.arc:
          final arcPts = p.arc?.face(0, 0);
          if (arcPts != null && arcPts.length >= 2) {
            openPool.add(arcPts);
          }
        case CadPrimitiveType.polyline:
          if (p.isClosedPolyline) {
            if (p.contourPoints.length >= 3) closedCurves.add(p.contourPoints);
          } else if (p.linePoints.length >= 2) {
            openPool.add(p.linePoints);
          }
        case CadPrimitiveType.spline:
          final pts = p.contourPoints;
          final sampled = pts.length >= 2
              ? ArchitectSplineGeometry.samplePoints(
                  pts,
                  closed: p.isClosedPolyline,
                  samplesPerSpan: 10,
                )
              : const <Offset>[];
          if (sampled.length >= 2) {
            if (p.isClosedPolyline) {
              closedCurves.add(sampled);
            } else {
              openPool.add(sampled);
            }
          }
        case CadPrimitiveType.circle:
          final r = (p.endPoint - p.startPoint).distance;
          if (r > 1e-3) {
            closedCurves.add([
              for (var i = 0; i < 24; i++)
                Offset(
                  p.startPoint.dx + r * math.cos(i * math.pi / 12.0),
                  p.startPoint.dy + r * math.sin(i * math.pi / 12.0),
                ),
            ]);
          }
        case CadPrimitiveType.ellipse:
          final rx = p.radiusX ?? (p.endPoint.dx - p.startPoint.dx).abs() / 2;
          final ry = p.radiusY ?? (p.endPoint.dy - p.startPoint.dy).abs() / 2;
          if (rx > 1e-3 && ry > 1e-3) {
            final center = (p.startPoint + p.endPoint) / 2;
            final rot = (p.rotationDeg ?? 0.0) * math.pi / 180.0;
            final cosR = math.cos(rot);
            final sinR = math.sin(rot);
            closedCurves.add([
              for (var i = 0; i < 24; i++)
                () {
                  final a = i * math.pi / 12.0;
                  final lx = rx * math.cos(a);
                  final ly = ry * math.sin(a);
                  return Offset(
                    center.dx + lx * cosR - ly * sinR,
                    center.dy + lx * sinR + ly * cosR,
                  );
                }(),
            ]);
          }
        case CadPrimitiveType.rect:
        case CadPrimitiveType.hatch:
        case CadPrimitiveType.mask:
          if (p.polygonCorners.length >= 3) {
            closedCurves.add(p.polygonCorners);
          }
      }
    }

    for (final s in storey.slabs) {
      if (s.polygon.length >= 3) closedCurves.add(s.polygon);
    }
    for (final r in storey.roofs) {
      if (r.points.length >= 3) closedCurves.add(r.points);
    }
    for (final z in storey.zones) {
      if (z.polygon.length >= 3) closedCurves.add(z.polygon);
    }

    var bestDist = hitToleranceMeters;
    Offset? bestAnchor;
    List<Offset>? bestPoints;
    var bestClosed = false;
    var bestOpenIdx = -1;

    for (var i = 0; i < openPool.length; i++) {
      final hit = ArchitectUnderlayContourExtractor.closestOnCurve(
        openPool[i],
        modelPoint,
        closed: false,
      );
      if (hit.distance <= bestDist) {
        bestDist = hit.distance;
        bestAnchor = hit.point;
        bestOpenIdx = i;
        bestClosed = false;
        bestPoints = null;
      }
    }

    for (final poly in closedCurves) {
      final hit = ArchitectUnderlayContourExtractor.closestOnCurve(
        poly,
        modelPoint,
        closed: true,
      );
      if (hit.distance < bestDist - 1e-4) {
        bestDist = hit.distance;
        bestAnchor = hit.point;
        bestOpenIdx = -1;
        bestClosed = true;
        bestPoints = poly;
      }
    }

    if (bestAnchor == null) return null;

    if (bestOpenIdx >= 0) {
      final stitched = ArchitectUnderlayContourExtractor.stitchOpenCurves(
        initialChain: openPool[bestOpenIdx],
        pool: openPool,
        usedIndices: {bestOpenIdx},
      );
      bestPoints = stitched.points;
      bestClosed = stitched.closed;
    }

    if (bestPoints == null || bestPoints.length < 2) return null;
    final simplified = simplifyForSpline(bestPoints, closed: bestClosed);
    if (simplified.length < 2) return null;

    return ArchitectSplineTraceCandidate(
      points: simplified,
      closed: bestClosed,
      anchorPoint: bestAnchor,
      distance: bestDist,
      source: ArchitectSplineTraceSource.modelCurve,
    );
  }

  /// Condenses dense sampled polylines into clean, faithful Catmull-Rom fit points.
  static List<Offset> simplifyForSpline(
    List<Offset> raw, {
    required bool closed,
    double toleranceMeters = 0.012,
    int maxPoints = 64,
  }) {
    if (raw.length < 2) return List.of(raw);
    final deduped = <Offset>[];
    for (final p in raw) {
      if (deduped.isEmpty || (deduped.last - p).distance > 0.002) {
        deduped.add(p);
      }
    }
    if (closed &&
        deduped.length >= 3 &&
        (deduped.first - deduped.last).distance <= 0.002) {
      deduped.removeLast();
    }
    if (deduped.length <= 40) return deduped;

    var tol = toleranceMeters;
    var simplified = _rdp(deduped, tol, closed: closed);
    while (simplified.length > maxPoints && tol < 0.12) {
      tol *= 1.5;
      simplified = _rdp(deduped, tol, closed: closed);
    }
    return simplified;
  }

  static List<Offset> _rdp(
    List<Offset> pts,
    double epsilon, {
    required bool closed,
  }) {
    if (pts.length <= 3) return pts;
    if (closed) {
      final anchor = pts.first;
      var splitIdx = 1;
      var maxDist = -1.0;
      for (var i = 1; i < pts.length; i++) {
        final d = (pts[i] - anchor).distance;
        if (d > maxDist) {
          maxDist = d;
          splitIdx = i;
        }
      }
      final left = _rdp(pts.sublist(0, splitIdx + 1), epsilon, closed: false);
      final right = _rdp(
        [...pts.sublist(splitIdx), pts.first],
        epsilon,
        closed: false,
      );
      return [
        ...left.take(left.length - 1),
        ...right.take(right.length - 1),
      ];
    }

    var maxPerp = 0.0;
    var index = 0;
    final a = pts.first;
    final b = pts.last;
    final ab = b - a;
    final len = ab.distance;
    for (var i = 1; i < pts.length - 1; i++) {
      final d = len < 1e-8
          ? (pts[i] - a).distance
          : ((pts[i].dx - a.dx) * ab.dy - (pts[i].dy - a.dy) * ab.dx).abs() /
                len;
      if (d > maxPerp) {
        maxPerp = d;
        index = i;
      }
    }
    if (maxPerp > epsilon) {
      final r1 = _rdp(pts.sublist(0, index + 1), epsilon, closed: false);
      final r2 = _rdp(pts.sublist(index), epsilon, closed: false);
      return [...r1.take(r1.length - 1), ...r2];
    }
    return [pts.first, pts.last];
  }
}
