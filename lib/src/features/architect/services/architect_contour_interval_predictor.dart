import 'dart:ui';

import '../models/architect_landscape_models.dart';

/// Infers the contour vertical interval (сечение на хоризонталите, Δh) from
/// digitized contours and predicts the next contour's absolute elevation using
/// the 2D gradient around existing contours (supporting up, down from a middle
/// contour, and filling skipped intermediate contours).
class ArchitectContourIntervalPredictor {
  ArchitectContourIntervalPredictor._();

  /// Minimum and maximum reasonable contour intervals in meters.
  static const double minIntervalMeters = 0.01;
  static const double maxIntervalMeters = 50.0;

  /// Infers the smallest consistent vertical step (Δh in meters) between at least
  /// 2 contours with distinct elevations. Returns `null` if fewer than 2 distinct
  /// elevation levels exist.
  static double? inferIntervalMeters(
    List<ArchitectTerrainContour> contours, {
    required double datumElevation,
  }) {
    if (contours.length < 2) return null;
    final sorted = <double>[
      for (final c in contours) c.effectiveAbsolute(datumElevation),
    ]..sort();

    final distinct = <double>[];
    for (final z in sorted) {
      if (distinct.isEmpty || (z - distinct.last).abs() >= 0.005) {
        distinct.add(z);
      }
    }
    if (distinct.length < 2) return null;

    double? minDiff;
    for (var i = 0; i + 1 < distinct.length; i++) {
      final diff = distinct[i + 1] - distinct[i];
      if (diff >= minIntervalMeters && diff <= maxIntervalMeters) {
        if (minDiff == null || diff < minDiff) {
          minDiff = diff;
        }
      }
    }
    if (minDiff == null) return null;
    return double.parse(minDiff.toStringAsFixed(4));
  }

  /// Predicts the absolute elevation (in meters) for a newly picked or traced
  /// contour based on existing terrain contours and [explicitIntervalMeters]
  /// (falling back to [surface.contourInterval] or inferred Δh).
  static double predictNextAbsoluteElevation({
    required ArchitectTerrainSurface surface,
    required List<Offset> candidatePoints,
    required bool candidateClosed,
    required double fallbackAbsoluteElevation,
    double? explicitIntervalMeters,
  }) {
    if (surface.contours.isEmpty || candidatePoints.isEmpty) {
      return fallbackAbsoluteElevation;
    }

    final datum = surface.datumElevation;
    final step = _resolveEffectiveStep(
      surface: surface,
      explicitIntervalMeters: explicitIntervalMeters,
    );

    // Build sampled polylines for each existing contour paired with its abs Z.
    final existing = <({List<Offset> pts, double absZ})>[];
    for (final c in surface.contours) {
      final pts = c.resolvedPolyline(samplesPerSpan: 6);
      if (pts.isEmpty) continue;
      existing.add((pts: pts, absZ: c.effectiveAbsolute(datum)));
    }
    if (existing.isEmpty) return fallbackAbsoluteElevation;

    // 1. Find the nearest existing contour (C_near) to the candidate curve.
    var nearIdx = 0;
    var bestNearDistSq = double.infinity;
    var pCandAtNear = candidatePoints.first;
    var pNearAtCand = existing.first.pts.first;

    for (var i = 0; i < existing.length; i++) {
      final pair = _closestPair(candidatePoints, existing[i].pts);
      if (pair.distSq < bestNearDistSq) {
        bestNearDistSq = pair.distSq;
        nearIdx = i;
        pCandAtNear = pair.a;
        pNearAtCand = pair.b;
      }
    }

    final zNear = existing[nearIdx].absZ;
    if (step <= 1e-4) {
      return _round4(fallbackAbsoluteElevation);
    }

    // 2. Find the nearest contour with a distinct elevation (C_ref) to pNearAtCand.
    int? refIdx;
    var bestRefDistSq = double.infinity;
    var pRefAtNear = Offset.zero;
    for (var i = 0; i < existing.length; i++) {
      if ((existing[i].absZ - zNear).abs() < 0.005) continue;
      final closest = _closestPointOnPolyline(pNearAtCand, existing[i].pts);
      if (closest.distSq < bestRefDistSq) {
        bestRefDistSq = closest.distSq;
        refIdx = i;
        pRefAtNear = closest.point;
      }
    }

    // With only one elevation level digitized so far, step up by Δh (user can tap -Δh if descending).
    if (refIdx == null) {
      return _round4(zNear + step);
    }

    final zRef = existing[refIdx].absZ;
    final vCand = pCandAtNear - pNearAtCand;
    final vRef = pRefAtNear - pNearAtCand;
    final candLenSq = vCand.distanceSquared;
    final refLenSq = vRef.distanceSquared;

    if (candLenSq < 1e-8 || refLenSq < 1e-8) {
      return _round4(zNear + step);
    }

    final dot = vCand.dx * vRef.dx + vCand.dy * vRef.dy;
    final dzRefToNear = zNear - zRef;
    final slopeSign = dzRefToNear >= 0 ? 1.0 : -1.0;

    // Candidate lies on the opposite side of C_near relative to C_ref:
    // Continue the gradient across C_near (works both going higher above top
    // contour AND going lower below a middle/lower contour).
    if (dot <= 0) {
      return _round4(zNear + slopeSign * step);
    }

    // Candidate lies on the same side of C_near as C_ref (between them if closer
    // to C_near than C_ref is, and there is a vertical gap >= 1.5 * step).
    final zDiff = (zRef - zNear).abs();
    if (zDiff >= step * 1.5 - 1e-4 && candLenSq < refLenSq) {
      final towardsRefSign = zRef > zNear ? 1.0 : -1.0;
      return _round4(zNear + towardsRefSign * step);
    }

    // Candidate sits beyond C_ref on the same side or too close to distinguish: step along gradient.
    return _round4(zNear + slopeSign * step);
  }

  static double _resolveEffectiveStep({
    required ArchitectTerrainSurface surface,
    double? explicitIntervalMeters,
  }) {
    if (explicitIntervalMeters != null && explicitIntervalMeters > 1e-4) {
      return explicitIntervalMeters;
    }
    if (surface.contourInterval > 1e-4) {
      return surface.contourInterval;
    }
    return inferIntervalMeters(
          surface.contours,
          datumElevation: surface.datumElevation,
        ) ??
        0.0;
  }

  static ({Offset a, Offset b, double distSq}) _closestPair(
    List<Offset> polyA,
    List<Offset> polyB,
  ) {
    var bestDistSq = double.infinity;
    var bestA = polyA.first;
    var bestB = polyB.first;

    // Check sampled points of A against segments of B, and vice versa.
    for (final pa in polyA) {
      final hit = _closestPointOnPolyline(pa, polyB);
      if (hit.distSq < bestDistSq) {
        bestDistSq = hit.distSq;
        bestA = pa;
        bestB = hit.point;
      }
    }
    for (final pb in polyB) {
      final hit = _closestPointOnPolyline(pb, polyA);
      if (hit.distSq < bestDistSq) {
        bestDistSq = hit.distSq;
        bestA = hit.point;
        bestB = pb;
      }
    }
    return (a: bestA, b: bestB, distSq: bestDistSq);
  }

  static ({Offset point, double distSq}) _closestPointOnPolyline(
    Offset p,
    List<Offset> pts,
  ) {
    if (pts.length == 1) {
      final d = (p - pts.first).distanceSquared;
      return (point: pts.first, distSq: d);
    }
    var bestDistSq = double.infinity;
    var bestPt = pts.first;
    for (var i = 0; i + 1 < pts.length; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final ab = b - a;
      final lenSq = ab.distanceSquared;
      final Offset proj;
      if (lenSq < 1e-10) {
        proj = a;
      } else {
        final t =
            (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(
              0.0,
              1.0,
            );
        proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      }
      final d = (p - proj).distanceSquared;
      if (d < bestDistSq) {
        bestDistSq = d;
        bestPt = proj;
      }
    }
    return (point: bestPt, distSq: bestDistSq);
  }

  static double _round4(double v) => double.parse(v.toStringAsFixed(4));
}
