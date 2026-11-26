import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import 'architect_terrain_tin.dart';

/// Describes a single proposed terrain modification zone (outer grading region,
/// standalone flat pad, batter-sloped daylight zone, or cutout hole) that cuts
/// into and replaces [ArchitectProject.existingTerrain] locally.
class ArchitectTerrainModificationZone {
  final String sourceBoundaryId;
  final List<Offset> innerPolygon;
  final List<Offset> outerPolygon;
  final ArchitectTerrainEdgeTransition transition;
  final double slopeRatio;
  final bool isHoleOnly;

  const ArchitectTerrainModificationZone({
    required this.sourceBoundaryId,
    required this.innerPolygon,
    required this.outerPolygon,
    required this.transition,
    required this.slopeRatio,
    this.isHoleOnly = false,
  });

  bool get hasDaylightRing =>
      transition == ArchitectTerrainEdgeTransition.slope &&
      !isHoleOnly &&
      outerPolygon.length >= 3 &&
      innerPolygon.length >= 3;
}

/// Result of slicing the composite (Existing + Proposed) terrain along a section
/// or elevation cut line.
class ArchitectCompositeProfileResult {
  /// Solid final ground segments (Proposed inside modification zones, Existing
  /// outside; excludes building footprints and terrain cutout holes).
  final List<List<Offset>> finalSegments;

  /// Dashed Existing terrain segments emitted ONLY where original terrain
  /// differs from [finalSegments] (`|z_ex - z_final| > diffTolerance`) or passes
  /// through an excluded building cut / excavation hole.
  final List<List<Offset>> existingDiffSegments;

  const ArchitectCompositeProfileResult({
    required this.finalSegments,
    required this.existingDiffSegments,
  });
}

class _IsolatedPadEntry {
  final ArchitectTerrainBoundary pad;
  final List<Offset> outerPolygon;
  final ArchitectTerrainSurface surface;
  final ArchitectTerrainTin? tin;

  const _IsolatedPadEntry({
    required this.pad,
    required this.outerPolygon,
    required this.surface,
    required this.tin,
  });
}

class _CompositePlan {
  final ArchitectTerrainSurface effectiveExisting;
  final ArchitectTerrainSurface effectiveProposedHost;
  final List<ArchitectTerrainModificationZone> zones;
  final List<List<Offset>> proposedHolePolygons;
  final ArchitectTerrainTin? baseExistingTin;
  final ArchitectTerrainTin? existingOutTin;
  final ArchitectTerrainTin? proposedHostTin;
  final List<_IsolatedPadEntry> isolatedPads;
  final bool useExisting;
  final bool useProposed;

  const _CompositePlan({
    required this.effectiveExisting,
    required this.effectiveProposedHost,
    required this.zones,
    required this.proposedHolePolygons,
    required this.baseExistingTin,
    required this.existingOutTin,
    required this.proposedHostTin,
    required this.isolatedPads,
    required this.useExisting,
    required this.useProposed,
  });

  double? evaluateExisting(Offset p) {
    if (!useExisting) return null;
    return baseExistingTin?.evaluateElevationAt(p) ??
        effectiveExisting.evaluateElevationAt(p);
  }

  bool isInProposedHole(Offset p) {
    for (final hole in proposedHolePolygons) {
      if (BimPolygonGeometry.contains(hole, p)) return true;
    }
    return false;
  }

  bool isInModificationZone(Offset p) {
    for (final z in zones) {
      if (z.outerPolygon.length >= 3 &&
          BimPolygonGeometry.contains(z.outerPolygon, p)) {
        return true;
      }
    }
    return false;
  }

  double? evaluateFinal(Offset p) {
    if (useProposed) {
      if (isInProposedHole(p)) return null;
      // Isolated pads (retaining wall or batter slope) take top priority inside their footprint/daylight ring.
      for (final entry in isolatedPads.reversed) {
        if (entry.outerPolygon.length >= 3 &&
            BimPolygonGeometry.contains(entry.outerPolygon, p)) {
          if (entry.pad.containsPoint(p)) {
            return entry.pad.elevation;
          }
          final zPad =
              entry.tin?.evaluateElevationAt(p) ??
              entry.surface.evaluateElevationAt(p);
          if (zPad != null) return zPad;
        }
      }
      if (proposedHostTin != null && (!useExisting || isInModificationZone(p))) {
        final zHost = proposedHostTin!.evaluateElevationAt(p);
        if (zHost != null) return zHost;
      } else if (!useExisting && effectiveProposedHost.isNotEmpty) {
        final zHost = effectiveProposedHost.evaluateElevationAt(p);
        if (zHost != null) return zHost;
      }
    }
    if (useExisting) {
      return existingOutTin?.evaluateElevationAt(p) ??
          baseExistingTin?.evaluateElevationAt(p) ??
          effectiveExisting.evaluateElevationAt(p);
    }
    return null;
  }
}

/// Reusable cached terrain sampler for fast repeated elevation queries at
/// arbitrary 2D points (e.g. fence piers, bay intervals, pathways, sections).
class ArchitectTerrainSampler {
  final _CompositePlan? _plan;
  final ArchitectTerrainSurface? _existingOnly;

  const ArchitectTerrainSampler._({
    _CompositePlan? plan,
    ArchitectTerrainSurface? existingOnly,
  }) : _plan = plan,
       _existingOnly = existingOnly;

  bool get isEmpty => _plan == null && _existingOnly == null;

  /// Evaluates the final composite ground elevation Z at [point], or `null` if
  /// no terrain covers [point] (or [point] lies inside a cutout hole).
  double? evaluateAt(Offset point) {
    if (_plan != null) return _plan.evaluateFinal(point);
    return _existingOnly?.evaluateElevationAt(point);
  }
}

/// Shared geometry engine that composes [ArchitectProject.existingTerrain] and
/// [ArchitectProject.proposedTerrain] into a single seamless final terrain for
/// 3D meshing, sections, elevations, 2D site plan clipping, and ground-level
/// element placement.
class ArchitectTerrainComposite {
  static const double defaultDiffTolerance = 0.005;

  /// Creates a reusable [ArchitectTerrainSampler] so callers performing dozens
  /// or hundreds of point queries (e.g. 3D fence/pathway builders, sections)
  /// build the composite TIN plan only once.
  static ArchitectTerrainSampler createSampler(
    ArchitectProject project, {
    bool respectLayerVisibility = false,
  }) {
    final useEx =
        project.existingTerrain.isNotEmpty &&
        (!respectLayerVisibility ||
            project.isLayerVisible(ArchitectLayer.terrainExistingLayerId));
    final useProp =
        project.proposedTerrain.isNotEmpty &&
        (!respectLayerVisibility ||
            project.isLayerVisible(ArchitectLayer.terrainProposedLayerId));
    if (!useEx && !useProp) {
      return const ArchitectTerrainSampler._();
    }
    if (!useProp) {
      return ArchitectTerrainSampler._(existingOnly: project.existingTerrain);
    }
    final plan = _buildPlan(
      existing: project.existingTerrain,
      proposed: project.proposedTerrain,
      useExisting: useEx,
      useProposed: true,
      buildingCutouts: const [],
    );
    return ArchitectTerrainSampler._(plan: plan);
  }

  /// Resolves all active proposed modification zones for [project] (used by 2D
  /// Site Plan clipping/daylight rendering, 3D meshing, and profile slicing).
  static List<ArchitectTerrainModificationZone> resolveModificationZones(
    ArchitectProject project,
  ) {
    if (project.proposedTerrain.isEmpty) return const [];
    final plan = _buildPlan(
      existing: project.existingTerrain,
      proposed: project.proposedTerrain,
      useExisting: project.existingTerrain.isNotEmpty,
      useProposed: true,
      buildingCutouts: const [],
    );
    return plan.zones;
  }

  /// Evaluates the final composite ground elevation Z at [point] in model
  /// coordinates, honoring local proposed zones, batter slopes, retaining pads,
  /// cutout holes, and surrounding existing terrain.
  static double? evaluateFinalElevationAt(
    ArchitectProject project,
    Offset point, {
    bool respectLayerVisibility = false,
  }) => createSampler(
    project,
    respectLayerVisibility: respectLayerVisibility,
  ).evaluateAt(point);

  /// Builds a single watertight 3D mesh for the final composite terrain surface
  /// (Existing clipped outside Proposed modification zones ∪ Proposed inside,
  /// minus [buildingCutouts]), with zero overlapping XY surfaces.
  static List<Triangle3D> buildCompositeMesh3D(
    ArchitectProject project, {
    required List<List<Offset>> buildingCutouts,
    required Color topColor,
    required Color sideColor,
    required Color bottomColor,
    Color retainingWallColor = const Color(0xFF9E9A92),
    double skirtDepth = 1.0,
    bool respectLayerVisibility = true,
  }) {
    final useEx =
        project.existingTerrain.isNotEmpty &&
        (!respectLayerVisibility ||
            project.isLayerVisible(ArchitectLayer.terrainExistingLayerId));
    final useProp =
        project.proposedTerrain.isNotEmpty &&
        (!respectLayerVisibility ||
            project.isLayerVisible(ArchitectLayer.terrainProposedLayerId));
    if (!useEx && !useProp) return const [];

    final plan = _buildPlan(
      existing: project.existingTerrain,
      proposed: project.proposedTerrain,
      useExisting: useEx,
      useProposed: useProp,
      buildingCutouts: buildingCutouts,
    );

    final triangles = <ArchitectTinTriangle>[
      if (plan.existingOutTin != null) ...plan.existingOutTin!.triangles,
      if (plan.proposedHostTin != null) ...plan.proposedHostTin!.triangles,
      for (final pad in plan.isolatedPads)
        if (pad.tin != null) ...pad.tin!.triangles,
    ];
    if (triangles.isEmpty) return const [];

    return ArchitectTerrainTin.buildSolidFromTriangles(
      triangles,
      topColor: topColor,
      sideColor: sideColor,
      bottomColor: bottomColor,
      retainingWallColor: retainingWallColor,
      skirtDepth: skirtDepth,
    );
  }

  /// Slices the composite terrain along [start] -> [end] for Sections or
  /// Elevations, producing:
  /// - `finalSegments`: solid final ground line (stopping at [excludedIntervals]
  ///   and cutout holes).
  /// - `existingDiffSegments`: dashed original ground line ONLY where existing
  ///   elevation differs from final ground by more than [diffTolerance] (or under
  ///   [excludedIntervals] / cutout holes when [includeUnderExcluded] is true).
  static ArchitectCompositeProfileResult sliceCompositeProfiles({
    required ArchitectTerrainSurface existing,
    required ArchitectTerrainSurface proposed,
    required Offset start,
    required Offset end,
    bool existingVisible = true,
    bool proposedVisible = true,
    List<(double, double)> excludedIntervals = const [],
    double stationShift = 0.0,
    bool includeUnderExcluded = true,
    double diffTolerance = defaultDiffTolerance,
    List<Offset>? overrideFinalProfile,
  }) {
    final totalLen = (end - start).distance;
    if (totalLen < 0.05) {
      return const ArchitectCompositeProfileResult(
        finalSegments: [],
        existingDiffSegments: [],
      );
    }

    final useEx = existingVisible && existing.isNotEmpty;
    final useProp = proposedVisible && proposed.isNotEmpty;
    if (!useEx &&
        !useProp &&
        (overrideFinalProfile == null || overrideFinalProfile.length < 2)) {
      return const ArchitectCompositeProfileResult(
        finalSegments: [],
        existingDiffSegments: [],
      );
    }

    final dir = (end - start) / totalLen;
    final plan = _buildPlan(
      existing: existing,
      proposed: proposed,
      useExisting: useEx,
      useProposed: useProp,
      buildingCutouts: const [],
    );

    // 1. Gather all candidate station values along [0, totalLen].
    final stations = <double>{0.0, totalLen};
    final step = (totalLen / 40.0).clamp(0.20, 0.85);
    for (var s = step; s < totalLen; s += step) {
      stations.add(s);
    }

    void addSurfaceStations(ArchitectTerrainSurface surf, ArchitectTerrainTin? tin) {
      if (surf.isEmpty) return;
      for (final c in surf.contours) {
        final pts = c.resolvedPolyline(samplesPerSpan: 6);
        final count = c.closed ? pts.length : pts.length - 1;
        for (var i = 0; i < count; i++) {
          final hit = _raySegmentIntersectionStation(
            start,
            dir,
            totalLen,
            pts[i],
            pts[(i + 1) % pts.length],
          );
          if (hit != null) stations.add(hit);
        }
      }
      for (final b in surf.boundaries) {
        for (var i = 0; i < b.polygon.length; i++) {
          final hit = _raySegmentIntersectionStation(
            start,
            dir,
            totalLen,
            b.polygon[i],
            b.polygon[(i + 1) % b.polygon.length],
          );
          if (hit != null) stations.add(hit);
        }
      }
      if (tin != null) {
        for (final hitPt in tin.intersectionStations(start, end)) {
          final s = (hitPt.dx - start.dx) * dir.dx + (hitPt.dy - start.dy) * dir.dy;
          if (s >= 0.0 && s <= totalLen) stations.add(s);
        }
      }
    }

    if (useEx) {
      addSurfaceStations(plan.effectiveExisting, plan.baseExistingTin);
      addSurfaceStations(plan.effectiveExisting, plan.existingOutTin);
    }
    if (useProp) {
      addSurfaceStations(plan.effectiveProposedHost, plan.proposedHostTin);
      for (final pad in plan.isolatedPads) {
        addSurfaceStations(pad.surface, pad.tin);
      }
    }
    for (final z in plan.zones) {
      for (final poly in [z.innerPolygon, z.outerPolygon]) {
        for (var i = 0; i < poly.length; i++) {
          final hit = _raySegmentIntersectionStation(
            start,
            dir,
            totalLen,
            poly[i],
            poly[(i + 1) % poly.length],
          );
          if (hit != null) stations.add(hit);
        }
      }
    }
    if (overrideFinalProfile != null) {
      for (final p in overrideFinalProfile) {
        final s = p.dx - stationShift;
        if (s >= 0.0 && s <= totalLen) stations.add(s);
      }
    }

    // 2. Collect excluded intervals (building footprints + active cutout holes).
    final combinedExcluded = <(double, double)>[...excludedIntervals];
    void addHoleExclusions(List<List<Offset>> holes) {
      for (final hole in holes) {
        if (hole.length < 3) continue;
        final hits = <double>[];
        for (var i = 0; i < hole.length; i++) {
          final hit = _raySegmentIntersectionStation(
            start,
            dir,
            totalLen,
            hole[i],
            hole[(i + 1) % hole.length],
          );
          if (hit != null) hits.add(hit);
        }
        if (hits.length >= 2) {
          hits.sort();
          for (var i = 0; i + 1 < hits.length; i += 2) {
            combinedExcluded.add((hits[i], hits[i + 1]));
          }
        }
      }
    }

    if (useProp) {
      addHoleExclusions(plan.proposedHolePolygons);
    } else if (useEx) {
      addHoleExclusions([
        for (final b in existing.boundaries)
          if (b.isHole && b.polygon.length >= 3) b.polygon,
      ]);
    }

    for (final iv in combinedExcluded) {
      if (iv.$1 > 0.0 && iv.$1 < totalLen) stations.add(iv.$1);
      if (iv.$2 > 0.0 && iv.$2 < totalLen) stations.add(iv.$2);
    }

    double? evalOverride(double s) {
      final poly = overrideFinalProfile;
      if (poly == null || poly.length < 2) return null;
      final x = s + stationShift;
      if (x < poly.first.dx - 1e-4 || x > poly.last.dx + 1e-4) return null;
      for (var i = 0; i + 1 < poly.length; i++) {
        final a = poly[i];
        final b = poly[i + 1];
        if (x >= a.dx - 1e-4 && x <= b.dx + 1e-4) {
          final dx = b.dx - a.dx;
          if (dx.abs() < 1e-6) return a.dy;
          final t = ((x - a.dx) / dx).clamp(0.0, 1.0);
          return a.dy + (b.dy - a.dy) * t;
        }
      }
      return null;
    }

    bool isInExcluded(double s) {
      for (final iv in combinedExcluded) {
        if (s > iv.$1 + 1e-5 && s < iv.$2 - 1e-5) return true;
      }
      return false;
    }

    double? evalFinalAtStation(double s) {
      if (overrideFinalProfile != null && overrideFinalProfile.length >= 2) {
        return evalOverride(s);
      }
      if (isInExcluded(s)) return null;
      return plan.evaluateFinal(start + dir * s);
    }

    double? evalExistingAtStation(double s) {
      if (!useEx) return null;
      return plan.evaluateExisting(start + dir * s);
    }

    // 3. Insert exact cut-to-fill zero-crossing stations where z_ex == z_final.
    final sortedBase = _dedupeSortedStations(stations);
    if (useEx && (useProp || overrideFinalProfile != null)) {
      for (var i = 0; i + 1 < sortedBase.length; i++) {
        final s0 = sortedBase[i];
        final s1 = sortedBase[i + 1];
        if (s1 - s0 < 1e-3) continue;
        final probe0 = s0 + math.min(1e-4, (s1 - s0) * 0.1);
        final probe1 = s1 - math.min(1e-4, (s1 - s0) * 0.1);
        final zEx0 = evalExistingAtStation(probe0);
        final zEx1 = evalExistingAtStation(probe1);
        final zFin0 = evalFinalAtStation(probe0);
        final zFin1 = evalFinalAtStation(probe1);
        if (zEx0 == null || zEx1 == null || zFin0 == null || zFin1 == null) {
          continue;
        }
        final d0 = zEx0 - zFin0;
        final d1 = zEx1 - zFin1;
        if ((d0 > diffTolerance && d1 < -diffTolerance) ||
            (d0 < -diffTolerance && d1 > diffTolerance)) {
          final t = (-d0 / (d1 - d0)).clamp(0.0, 1.0);
          stations.add(probe0 + (probe1 - probe0) * t);
        }
      }
    }

    final sorted = _dedupeSortedStations(stations);

    // 4. Build solid final profile segments (honoring vertical retaining steps!).
    final finalSegments = <List<Offset>>[];
    if (overrideFinalProfile != null && overrideFinalProfile.length >= 2) {
      finalSegments.add(List<Offset>.of(overrideFinalProfile));
    } else {
      List<Offset>? currentFinal;
      for (var i = 0; i + 1 < sorted.length; i++) {
        final s0 = sorted[i];
        final s1 = sorted[i + 1];
        if (s1 - s0 < 1e-4) continue;
        final sMid = (s0 + s1) * 0.5;
        if (isInExcluded(sMid)) {
          if (currentFinal != null && currentFinal.length >= 2) {
            finalSegments.add(currentFinal);
          }
          currentFinal = null;
          continue;
        }
        final eps = math.min(1e-4, (s1 - s0) * 0.1);
        final z0 = evalFinalAtStation(s0 + eps);
        final z1 = evalFinalAtStation(s1 - eps);
        if (z0 == null || z1 == null) {
          if (currentFinal != null && currentFinal.length >= 2) {
            finalSegments.add(currentFinal);
          }
          currentFinal = null;
          continue;
        }
        final p0 = Offset(s0 + stationShift, z0);
        final p1 = Offset(s1 + stationShift, z1);
        if (currentFinal == null) {
          currentFinal = [p0, p1];
        } else {
          if ((currentFinal.last.dx - p0.dx).abs() > 1e-4 ||
              (currentFinal.last.dy - p0.dy).abs() > 1e-4) {
            currentFinal.add(p0);
          }
          currentFinal.add(p1);
        }
      }
      if (currentFinal != null && currentFinal.length >= 2) {
        finalSegments.add(currentFinal);
      }
    }

    // 5. Build filtered dashed Existing segments ONLY where differing or under building/hole.
    final existingDiffSegments = <List<Offset>>[];
    if (useEx) {
      List<Offset>? currentDiff;
      for (var i = 0; i + 1 < sorted.length; i++) {
        final s0 = sorted[i];
        final s1 = sorted[i + 1];
        if (s1 - s0 < 1e-4) continue;
        final eps = math.min(1e-4, (s1 - s0) * 0.1);
        final sMid = (s0 + s1) * 0.5;
        final zEx0 = evalExistingAtStation(s0 + eps);
        final zEx1 = evalExistingAtStation(s1 - eps);
        final zExMid = evalExistingAtStation(sMid);
        if (zEx0 == null || zEx1 == null || zExMid == null) {
          if (currentDiff != null && currentDiff.length >= 2) {
            existingDiffSegments.add(currentDiff);
          }
          currentDiff = null;
          continue;
        }

        final excludedMid = isInExcluded(sMid);
        final zFinMid = evalFinalAtStation(sMid);
        final zFin0 = evalFinalAtStation(s0 + eps);
        final zFin1 = evalFinalAtStation(s1 - eps);

        final bool keep;
        if (excludedMid) {
          keep = includeUnderExcluded;
        } else if (zFinMid == null) {
          keep = true;
        } else {
          final maxDiff = math.max(
            (zExMid - zFinMid).abs(),
            math.max(
              zFin0 != null ? (zEx0 - zFin0).abs() : 0.0,
              zFin1 != null ? (zEx1 - zFin1).abs() : 0.0,
            ),
          );
          keep = maxDiff > diffTolerance;
        }

        if (!keep) {
          if (currentDiff != null && currentDiff.length >= 2) {
            existingDiffSegments.add(currentDiff);
          }
          currentDiff = null;
          continue;
        }

        final p0 = Offset(s0 + stationShift, zEx0);
        final p1 = Offset(s1 + stationShift, zEx1);
        if (currentDiff == null) {
          currentDiff = [p0, p1];
        } else {
          if ((currentDiff.last - p0).distance > 1e-3) {
            if (currentDiff.length >= 2) {
              existingDiffSegments.add(currentDiff);
            }
            currentDiff = [p0, p1];
          } else {
            currentDiff.add(p1);
          }
        }
      }
      if (currentDiff != null && currentDiff.length >= 2) {
        existingDiffSegments.add(currentDiff);
      }
    }

    return ArchitectCompositeProfileResult(
      finalSegments: finalSegments,
      existingDiffSegments: existingDiffSegments,
    );
  }

  // ===========================================================================
  // INTERNAL COMPOSITE PLANNING & DAYLIGHT BATTER GEOMETRY
  // ===========================================================================

  static _CompositePlan _buildPlan({
    required ArchitectTerrainSurface existing,
    required ArchitectTerrainSurface proposed,
    required bool useExisting,
    required bool useProposed,
    required List<List<Offset>> buildingCutouts,
  }) {
    final baseExistingTin =
        useExisting && existing.isNotEmpty ? ArchitectTerrainTin.of(existing) : null;
    double? evalExisting(Offset p) =>
        baseExistingTin?.evaluateElevationAt(p) ??
        (useExisting && existing.isNotEmpty
            ? existing.evaluateElevationAt(p)
            : null);

    if (!useProposed || proposed.isEmpty) {
      final exTin = !useExisting || existing.isEmpty
          ? null
          : (buildingCutouts.isEmpty
                ? baseExistingTin
                : ArchitectTerrainTin.build(
                    existing,
                    extraCutouts: buildingCutouts,
                    cutoutElevationAt: evalExisting,
                  ));
      return _CompositePlan(
        effectiveExisting: existing,
        effectiveProposedHost: proposed,
        zones: const [],
        proposedHolePolygons: const [],
        baseExistingTin: baseExistingTin,
        existingOutTin: exTin,
        proposedHostTin: null,
        isolatedPads: const [],
        useExisting: useExisting && existing.isNotEmpty,
        useProposed: false,
      );
    }

    final explicitOuters = [
      for (final b in proposed.boundaries)
        if (!b.isHole && !b.isFlatPad && b.polygon.length >= 3) b,
    ];
    final pads = [
      for (final b in proposed.boundaries)
        if (b.isFlatPad && !b.isHole && b.polygon.length >= 3) b,
    ];
    final holes = [
      for (final b in proposed.boundaries)
        if (b.isHole && b.polygon.length >= 3) b,
    ];
    final proposedHolePolys = [for (final h in holes) h.polygon];

    // Step A: Build the proposed host surface (everything in Proposed EXCEPT
    // flat pads, which are isolated so retaining walls / batter slopes never
    // distort the surrounding TIN out to distant site corners).
    final hostBoundaries = <ArchitectTerrainBoundary>[];
    final hostSpots = <ArchitectTerrainSpot>[...proposed.spots];
    final zones = <ArchitectTerrainModificationZone>[];

    for (final bnd in explicitOuters) {
      final transition = bnd.effectiveEdgeTransition;
      if (transition == ArchitectTerrainEdgeTransition.slope &&
          useExisting &&
          existing.isNotEmpty) {
        final daylight = computeDaylightPolygon(
          innerPolygon: bnd.polygon,
          proposedElevationAtVertex: (i) => bnd.vertexElevationAt(i),
          existingElevationAt: evalExisting,
          slopeRatio: bnd.slopeRatio,
        );
        hostBoundaries.add(
          ArchitectTerrainBoundary(
            id: '${bnd.id}__daylight',
            polygon: daylight,
            elevation: bnd.elevation,
            autoInterpolateElevation: true,
            edgeTransition: ArchitectTerrainEdgeTransition.matchExisting,
            slopeRatio: bnd.slopeRatio,
          ),
        );
        for (var i = 0; i < bnd.polygon.length; i++) {
          hostSpots.add(
            ArchitectTerrainSpot(
              id: '${bnd.id}__crest_$i',
              position: bnd.polygon[i],
              elevation: bnd.vertexElevationAt(i),
            ),
          );
        }
        zones.add(
          ArchitectTerrainModificationZone(
            sourceBoundaryId: bnd.id,
            innerPolygon: bnd.polygon,
            outerPolygon: daylight,
            transition: transition,
            slopeRatio: bnd.slopeRatio,
          ),
        );
      } else {
        hostBoundaries.add(bnd);
        zones.add(
          ArchitectTerrainModificationZone(
            sourceBoundaryId: bnd.id,
            innerPolygon: bnd.polygon,
            outerPolygon: bnd.polygon,
            transition: transition,
            slopeRatio: bnd.slopeRatio,
          ),
        );
      }
    }

    // Proposed contours/spots with no explicit outer boundary and no pads -> auto-zone.
    if (explicitOuters.isEmpty &&
        pads.isEmpty &&
        holes.isEmpty &&
        (proposed.contours.isNotEmpty || proposed.spots.isNotEmpty)) {
      final b = proposed.bounds;
      if (b != null && !b.isEmpty) {
        final rect = b.inflate(1.5);
        final poly = [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ];
        hostBoundaries.add(
          ArchitectTerrainBoundary(
            id: '${proposed.id}__auto_zone',
            polygon: poly,
            autoInterpolateElevation: true,
            edgeTransition: ArchitectTerrainEdgeTransition.matchExisting,
          ),
        );
        zones.add(
          ArchitectTerrainModificationZone(
            sourceBoundaryId: '${proposed.id}__auto_zone',
            innerPolygon: poly,
            outerPolygon: poly,
            transition: ArchitectTerrainEdgeTransition.matchExisting,
            slopeRatio: 1.5,
          ),
        );
      }
    }

    // Keep holes on host surface too.
    hostBoundaries.addAll(holes);
    for (final h in holes) {
      final c = _polygonCentroid(h.polygon);
      final insideHost = explicitOuters.any(
        (o) => BimPolygonGeometry.contains(o.polygon, c),
      );
      if (!insideHost) {
        zones.add(
          ArchitectTerrainModificationZone(
            sourceBoundaryId: h.id,
            innerPolygon: h.polygon,
            outerPolygon: h.polygon,
            transition: ArchitectTerrainEdgeTransition.retainingWall,
            slopeRatio: h.slopeRatio,
            isHoleOnly: true,
          ),
        );
      }
    }

    final hasHostSurface =
        hostBoundaries.any((b) => !b.isHole && !b.isFlatPad);
    final rawProposedHost = hasHostSurface
        ? proposed.copyWith(boundaries: hostBoundaries, spots: hostSpots)
        : const ArchitectTerrainSurface(state: ArchitectTerrainState.proposed);

    final existingSeamSplits = useExisting && existing.isNotEmpty
        ? _extractSurfaceSegments(existing)
        : const <({Offset a, Offset b})>[];

    // Base host TIN (before pad cutouts) used to evaluate exact surrounding
    // ground elevation along pad perimeters / daylight slopes.
    final baseProposedHostTin = rawProposedHost.isNotEmpty
        ? ArchitectTerrainTin.build(
            rawProposedHost,
            boundaryElevationAt: useExisting ? evalExisting : null,
            seamSplitSegments: existingSeamSplits,
          )
        : null;

    double? evalSurroundingForPad(Offset p) =>
        baseProposedHostTin?.evaluateElevationAt(p) ?? evalExisting(p);

    // Step B: Resolve each Flat pad as its own isolated retaining or sloped surface
    // and collect its outer cutout polygon to subtract from host + existing.
    final padCutouts = <List<Offset>>[];
    final isolatedPadDrafts =
        <({
          ArchitectTerrainBoundary pad,
          List<Offset> outerPoly,
          ArchitectTerrainSurface surface,
        })>[];

    for (final pad in pads) {
      final transition = pad.effectiveEdgeTransition;
      final List<Offset> outerPoly;
      final ArchitectTerrainSurface padSurface;

      if (transition == ArchitectTerrainEdgeTransition.slope &&
          (baseProposedHostTin != null || (useExisting && existing.isNotEmpty))) {
        outerPoly = computeDaylightPolygon(
          innerPolygon: pad.polygon,
          proposedElevationAtVertex: (_) => pad.elevation,
          existingElevationAt: evalSurroundingForPad,
          slopeRatio: pad.slopeRatio,
        );
        padSurface = ArchitectTerrainSurface(
          id: '${pad.id}__sloped_surface',
          state: ArchitectTerrainState.proposed,
          datumElevation: proposed.datumElevation,
          boundaries: [
            ArchitectTerrainBoundary(
              id: '${pad.id}__daylight',
              polygon: outerPoly,
              elevation: pad.elevation,
              autoInterpolateElevation: true,
              edgeTransition: ArchitectTerrainEdgeTransition.matchExisting,
              slopeRatio: pad.slopeRatio,
            ),
            pad,
          ],
        );
      } else {
        outerPoly = pad.polygon;
        padSurface = ArchitectTerrainSurface(
          id: '${pad.id}__flat_surface',
          state: ArchitectTerrainState.proposed,
          datumElevation: proposed.datumElevation,
          boundaries: [
            ArchitectTerrainBoundary(
              id: '${pad.id}__outer',
              polygon: pad.polygon,
              elevation: pad.elevation,
              autoInterpolateElevation: false,
              edgeTransition: transition,
              slopeRatio: pad.slopeRatio,
            ),
            pad,
          ],
        );
      }

      padCutouts.add(outerPoly);
      isolatedPadDrafts.add((
        pad: pad,
        outerPoly: outerPoly,
        surface: padSurface,
      ));
      zones.add(
        ArchitectTerrainModificationZone(
          sourceBoundaryId: pad.id,
          innerPolygon: pad.polygon,
          outerPolygon: outerPoly,
          transition: transition,
          slopeRatio: pad.slopeRatio,
        ),
      );
    }

    // Collect shared seam split segments across host, existing, and pads.
    final padSeamSplits = <({Offset a, Offset b})>[
      for (final d in isolatedPadDrafts) ..._extractSurfaceSegments(d.surface),
    ];
    final hostSeamSplits = <({Offset a, Offset b})>[
      if (rawProposedHost.isNotEmpty) ..._extractSurfaceSegments(rawProposedHost),
      ...padSeamSplits,
    ];
    final surroundingSeamSplits = <({Offset a, Offset b})>[
      ...existingSeamSplits,
      if (rawProposedHost.isNotEmpty) ..._extractSurfaceSegments(rawProposedHost),
    ];

    // Step C: Build final TINs with exact cutouts so ZERO XY triangles overlap!
    final modificationCutouts = [
      for (final z in zones)
        if (z.outerPolygon.length >= 3) z.outerPolygon,
    ];

    final existingOutTin = useExisting && existing.isNotEmpty
        ? ArchitectTerrainTin.build(
            existing,
            extraCutouts: [...modificationCutouts, ...buildingCutouts],
            cutoutElevationAt: evalExisting,
            seamSplitSegments: hostSeamSplits,
          )
        : null;

    final proposedHostTin = rawProposedHost.isNotEmpty
        ? ArchitectTerrainTin.build(
            rawProposedHost,
            extraCutouts: [...padCutouts, ...buildingCutouts],
            boundaryElevationAt: useExisting ? evalExisting : null,
            cutoutElevationAt: evalSurroundingForPad,
            seamSplitSegments: [...existingSeamSplits, ...padSeamSplits],
          )
        : null;

    final isolatedPads = <_IsolatedPadEntry>[
      for (final d in isolatedPadDrafts)
        _IsolatedPadEntry(
          pad: d.pad,
          outerPolygon: d.outerPoly,
          surface: d.surface,
          tin: ArchitectTerrainTin.build(
            d.surface,
            extraCutouts: [...proposedHolePolys, ...buildingCutouts],
            boundaryElevationAt: evalSurroundingForPad,
            cutoutElevationAt: (_) => d.pad.elevation,
            seamSplitSegments: surroundingSeamSplits,
          ),
        ),
    ];

    return _CompositePlan(
      effectiveExisting: existing,
      effectiveProposedHost: rawProposedHost,
      zones: zones,
      proposedHolePolygons: proposedHolePolys,
      baseExistingTin: baseExistingTin,
      existingOutTin: existingOutTin,
      proposedHostTin: proposedHostTin,
      isolatedPads: isolatedPads,
      useExisting: useExisting && existing.isNotEmpty,
      useProposed: true,
    );
  }

  /// Computes an outward-offset daylight ring around [innerPolygon] where a
  /// batter slope of `1:[slopeRatio]` (vertical:horizontal) meets the existing
  /// terrain surface.
  static List<Offset> computeDaylightPolygon({
    required List<Offset> innerPolygon,
    required double Function(int vertexIndex) proposedElevationAtVertex,
    required double? Function(Offset) existingElevationAt,
    required double slopeRatio,
  }) {
    if (innerPolygon.length < 3) return innerPolygon;
    final ratio = slopeRatio.clamp(0.1, 20.0);

    // Ensure CCW order in XY so outward normal of edge a->b is (+dy, -dx).
    final area2 = _signedArea2(innerPolygon);
    final ccw = area2 >= 0
        ? innerPolygon
        : innerPolygon.reversed.toList();
    double zForCcwIndex(int i) => area2 >= 0
        ? proposedElevationAtVertex(i)
        : proposedElevationAtVertex(innerPolygon.length - 1 - i);

    final n = ccw.length;
    final out = <Offset>[];
    for (var i = 0; i < n; i++) {
      final prev = ccw[(i - 1 + n) % n];
      final curr = ccw[i];
      final next = ccw[(i + 1) % n];

      final e1 = curr - prev;
      final e2 = next - curr;
      final l1 = e1.distance;
      final l2 = e2.distance;
      final n1 = l1 > 1e-6 ? Offset(e1.dy / l1, -e1.dx / l1) : const Offset(1, 0);
      final n2 = l2 > 1e-6 ? Offset(e2.dy / l2, -e2.dx / l2) : n1;

      var miter = n1 + n2;
      final mLen = miter.distance;
      double miterScale;
      if (mLen < 1e-4) {
        miter = n1;
        miterScale = 1.0;
      } else {
        miter = miter / mLen;
        final dot = (miter.dx * n1.dx + miter.dy * n1.dy).clamp(0.5, 1.0);
        miterScale = (1.0 / dot).clamp(1.0, 2.0);
      }

      final zProp = zForCcwIndex(i);
      var zEx = existingElevationAt(curr) ?? zProp;
      var dist = ((zProp - zEx).abs() * ratio).clamp(0.15, 15.0);
      for (var iter = 0; iter < 2; iter++) {
        final probe = curr + miter * (dist * miterScale);
        final zProbe = existingElevationAt(probe);
        if (zProbe == null) break;
        zEx = zProbe;
        dist = ((zProp - zEx).abs() * ratio).clamp(0.15, 15.0);
      }
      out.add(curr + miter * (dist * miterScale));
    }

    return area2 >= 0 ? out : out.reversed.toList();
  }

  static List<({Offset a, Offset b})> _extractSurfaceSegments(
    ArchitectTerrainSurface surface,
  ) {
    final segs = <({Offset a, Offset b})>[];
    for (final c in surface.contours) {
      final pts = c.resolvedPolyline(samplesPerSpan: 6);
      final count = c.closed ? pts.length : pts.length - 1;
      for (var i = 0; i < count; i++) {
        segs.add((a: pts[i], b: pts[(i + 1) % pts.length]));
      }
    }
    for (final b in surface.boundaries) {
      for (var i = 0; i < b.polygon.length; i++) {
        segs.add((a: b.polygon[i], b: b.polygon[(i + 1) % b.polygon.length]));
      }
    }
    return segs;
  }

  static List<double> _dedupeSortedStations(Set<double> raw) {
    final list = raw.toList()..sort();
    final out = <double>[];
    for (final s in list) {
      if (out.isEmpty || (s - out.last).abs() > 1e-4) {
        out.add(s);
      }
    }
    return out;
  }

  static double _signedArea2(List<Offset> poly) {
    var sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum;
  }

  static Offset _polygonCentroid(List<Offset> poly) {
    if (poly.isEmpty) return Offset.zero;
    var sx = 0.0;
    var sy = 0.0;
    for (final p in poly) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / poly.length, sy / poly.length);
  }

  static double? _raySegmentIntersectionStation(
    Offset origin,
    Offset dir,
    double maxLen,
    Offset a,
    Offset b,
  ) {
    final v1 = origin - a;
    final v2 = b - a;
    final v3 = Offset(-dir.dy, dir.dx);
    final dot = v2.dx * v3.dx + v2.dy * v3.dy;
    if (dot.abs() < 1e-9) return null;
    final t1 = (v2.dx * v1.dy - v2.dy * v1.dx) / dot;
    final t2 = (v1.dx * v3.dx + v1.dy * v3.dy) / dot;
    if (t1 >= 0.0 && t1 <= maxLen && t2 >= 0.0 && t2 <= 1.0) {
      return t1;
    }
    return null;
  }
}
