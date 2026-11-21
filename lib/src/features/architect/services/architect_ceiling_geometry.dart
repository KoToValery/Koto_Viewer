import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_overlap.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import 'architect_slab_geometry.dart';

/// Describes a beam that protrudes into or below a suspended ceiling zone.
class CeilingBeamConflict {
  final String beamId;
  final String beamLabel;
  final double beamBottomElevation;
  final double overlapDepth;

  const CeilingBeamConflict({
    required this.beamId,
    required this.beamLabel,
    required this.beamBottomElevation,
    required this.overlapDepth,
  });
}

/// Computed elevation and clearance metrics for a suspended ceiling.
class CeilingElevationMetrics {
  /// Absolute elevation (m) of the underside of the upper slab.
  final double upperSlabBottom;

  /// True if [upperSlabBottom] came from an actual modeled slab above.
  final bool fromActualUpperSlab;

  /// Absolute elevation (m) of the visible bottom face of the ceiling.
  final double ceilingElevation;

  /// Clear height (m) from the current storey's finished floor to [ceilingElevation].
  final double clearHeight;

  /// Free cavity (m) between the top of the ceiling assembly and [upperSlabBottom].
  final double plenumDepth;

  /// Overhead beams colliding with the ceiling assembly.
  final List<CeilingBeamConflict> beamConflicts;

  const CeilingElevationMetrics({
    required this.upperSlabBottom,
    required this.fromActualUpperSlab,
    required this.ceilingElevation,
    required this.clearHeight,
    required this.plenumDepth,
    this.beamConflicts = const [],
  });

  bool get hasPlenumConflict => plenumDepth < -1e-4;
  bool get hasBeamConflict => beamConflicts.isNotEmpty;
  bool get hasAnyConflict => hasPlenumConflict || hasBeamConflict;
}

/// Pure geometric and elevation utilities for suspended ceilings.
class ArchitectCeilingGeometry {
  static const double defaultUpperSlabThickness = 0.20;

  /// Returns the immediate normal storey above [storey], or null if [storey]
  /// is the top floor.
  static ArchitectStorey? upperStoreyOf(
    ArchitectProject project,
    ArchitectStorey storey,
  ) {
    final above = project.storeys
        .where((s) => s.isBuildingStorey && s.elevation > storey.elevation + 1e-4)
        .toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    return above.firstOrNull;
  }

  /// Resolves the underside elevation (m) of the upper slab over [ceiling].
  ///
  /// Uses actual slab assemblies on the upper storey (or roof storey on the
  /// top floor) when overlapping [ceiling]; otherwise falls back to the upper
  /// storey elevation (or `storey.elevation + storey.height`) minus
  /// [defaultUpperSlabThickness].
  static ({double bottom, bool fromActualSlab}) resolveUpperSlabBottom(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final upper = upperStoreyOf(project, storey);
    final candidateStoreys = <ArchitectStorey>[
      if (upper != null) upper,
      if (upper == null && project.roofStorey != null) project.roofStorey!,
    ];

    final samples = <Offset>[
      if (ceiling.polygon.isNotEmpty) ceiling.centroid,
      ...ceiling.tessellatedPolygon,
    ];

    double? lowestSlabBottom;
    for (final s in candidateStoreys) {
      for (final slab in s.slabs) {
        if (slab.polygon.length < 3) continue;
        final surfaces = ArchitectSlabGeometry.surfaces(project, s, slab);
        if (surfaces.isEmpty) continue;
        final bottomLayer = surfaces.last;
        for (final pt in samples) {
          if (ArchitectSlabGeometry.contains(s, slab, pt, project: project)) {
            final b = bottomLayer.bottomAt(pt);
            if (lowestSlabBottom == null || b < lowestSlabBottom) {
              lowestSlabBottom = b;
            }
          }
        }
      }
    }

    if (lowestSlabBottom != null) {
      return (bottom: lowestSlabBottom, fromActualSlab: true);
    }

    final fallbackUpperTop = upper != null
        ? upper.elevation
        : (storey.elevation + storey.height);
    return (
      bottom: fallbackUpperTop - defaultUpperSlabThickness,
      fromActualSlab: false,
    );
  }

  /// Computes absolute ceiling elevation, clear floor-to-ceiling height,
  /// plenum cavity depth, and overhead beam collisions.
  static CeilingElevationMetrics computeMetrics(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final slabInfo = resolveUpperSlabBottom(project, storey, ceiling);
    final ceilingElevation = slabInfo.bottom - ceiling.dropFromUpperSlab;
    final clearHeight = ceilingElevation - storey.elevation;
    final plenumDepth =
        ceiling.dropFromUpperSlab - ceiling.constructionThickness;
    final ceilingTop = ceilingElevation + ceiling.constructionThickness;

    final conflicts = <CeilingBeamConflict>[];
    final outer = ceiling.tessellatedPolygon;
    if (outer.length >= 3) {
      final ceilingOverlap = BimPolygonOverlap(outer);
      final holeOverlaps = [
        for (final h in ceiling.holes)
          if (h.length >= 3) BimPolygonOverlap(h),
      ];

      void checkBeams(
        Iterable<ArchitectBeam> beams,
        double hostElevation,
        bool Function(ArchitectBeam) isRelevant,
      ) {
        for (final beam in beams) {
          if (!isRelevant(beam)) continue;
          final beamBottom = hostElevation + beam.minBottomOffset;
          if (beamBottom >= ceilingTop - 1e-4) continue;
          final beamPoly = BimPolygonOverlap(beam.polygonCorners);
          var hitArea = ceilingOverlap.intersectionArea(beamPoly);
          if (hitArea <= 1e-6) continue;
          for (final hole in holeOverlaps) {
            hitArea -= hole.intersectionArea(beamPoly);
          }
          if (hitArea > 1e-5) {
            conflicts.add(
              CeilingBeamConflict(
                beamId: beam.id,
                beamLabel: beam.label,
                beamBottomElevation: beamBottom,
                overlapDepth: ceilingTop - beamBottom,
              ),
            );
          }
        }
      }

      checkBeams(
        storey.beams,
        storey.elevation,
        (b) => b.minBottomOffset > storey.cutPlaneHeight,
      );
      final upper = upperStoreyOf(project, storey);
      if (upper != null) {
        checkBeams(upper.beams, upper.elevation, (b) => b.minBottomOffset < 0);
      }
    }

    return CeilingElevationMetrics(
      upperSlabBottom: slabInfo.bottom,
      fromActualUpperSlab: slabInfo.fromActualSlab,
      ceilingElevation: ceilingElevation,
      clearHeight: clearHeight,
      plenumDepth: plenumDepth,
      beamConflicts: conflicts,
    );
  }

  /// Generates clipped Armstrong grid segments `(start, end)` in model space,
  /// honoring [ceiling.tileWidth], [ceiling.tileLength], [ceiling.gridAngle],
  /// [ceiling.gridOrigin], and [ceiling.gridCentered].
  static List<(Offset, Offset)> armstrongGridLines(
    ArchitectSuspendedCeiling ceiling, {
    int maxLinesPerAxis = 400,
  }) {
    if (ceiling.type != SuspendedCeilingType.armstrong) return const [];
    final outer = ceiling.tessellatedPolygon;
    if (outer.length < 3) return const [];
    final stepX = ceiling.tileWidth;
    final stepY = ceiling.tileLength;
    if (stepX <= 1e-3 || stepY <= 1e-3) return const [];

    final angle = ceiling.gridAngle;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final pivot = ceiling.gridOrigin ?? ceiling.centroid;

    Offset toLocal(Offset p) {
      final d = p - pivot;
      return Offset(d.dx * cosA + d.dy * sinA, -d.dx * sinA + d.dy * cosA);
    }

    Offset toWorld(Offset p) =>
        pivot + Offset(p.dx * cosA - p.dy * sinA, p.dx * sinA + p.dy * cosA);

    final localOuter = [for (final p in outer) toLocal(p)];
    final localHoles = [
      for (final h in ceiling.holes)
        if (h.length >= 3) [for (final p in h) toLocal(p)],
    ];

    var minX = localOuter.first.dx, maxX = minX;
    var minY = localOuter.first.dy, maxY = minY;
    for (final p in localOuter.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    double resolvePhase(double lo, double hi, double step) {
      if (ceiling.gridOrigin != null) return 0.0;
      if (!ceiling.gridCentered) return lo;
      final mid = (lo + hi) * 0.5;
      final halfSpan = (hi - lo) * 0.5;
      double edgeCut(double offsetFromMid) {
        final rem = (halfSpan - offsetFromMid) % step;
        return rem < 1e-5 ? step : rem;
      }

      // Joint on midpoint vs tile center on midpoint: choose larger perimeter cut.
      final cutJoint = edgeCut(0.0);
      final cutCenteredTile = edgeCut(step * 0.5);
      return cutCenteredTile >= cutJoint ? (mid + step * 0.5) : mid;
    }

    final phaseX = resolvePhase(minX, maxX, stepX);
    final phaseY = resolvePhase(minY, maxY, stepY);

    final segments = <(Offset, Offset)>[];

    // Vertical grid lines (constant x = constX in local grid space).
    final kStartX = ((minX - phaseX) / stepX).ceil();
    final kEndX = ((maxX - phaseX) / stepX).floor();
    if (kEndX - kStartX <= maxLinesPerAxis) {
      for (var k = kStartX; k <= kEndX; k++) {
        final x = phaseX + k * stepX;
        final spans = _clipVerticalLine(localOuter, localHoles, x);
        for (final (y0, y1) in spans) {
          if (y1 - y0 > 1e-4) {
            segments.add((toWorld(Offset(x, y0)), toWorld(Offset(x, y1))));
          }
        }
      }
    }

    // Horizontal grid lines (constant y = constY in local grid space).
    final kStartY = ((minY - phaseY) / stepY).ceil();
    final kEndY = ((maxY - phaseY) / stepY).floor();
    if (kEndY - kStartY <= maxLinesPerAxis) {
      for (var k = kStartY; k <= kEndY; k++) {
        final y = phaseY + k * stepY;
        final spans = _clipHorizontalLine(localOuter, localHoles, y);
        for (final (x0, x1) in spans) {
          if (x1 - x0 > 1e-4) {
            segments.add((toWorld(Offset(x0, y)), toWorld(Offset(x1, y))));
          }
        }
      }
    }

    return segments;
  }

  static List<(double, double)> _clipVerticalLine(
    List<Offset> outer,
    List<List<Offset>> holes,
    double x,
  ) {
    final outerSpans = _scanlineIntervals(outer, x, vertical: true);
    if (outerSpans.isEmpty || holes.isEmpty) return outerSpans;
    var result = outerSpans;
    for (final hole in holes) {
      final holeSpans = _scanlineIntervals(hole, x, vertical: true);
      if (holeSpans.isNotEmpty) {
        result = _subtractSpans(result, holeSpans);
        if (result.isEmpty) break;
      }
    }
    return result;
  }

  static List<(double, double)> _clipHorizontalLine(
    List<Offset> outer,
    List<List<Offset>> holes,
    double y,
  ) {
    final outerSpans = _scanlineIntervals(outer, y, vertical: false);
    if (outerSpans.isEmpty || holes.isEmpty) return outerSpans;
    var result = outerSpans;
    for (final hole in holes) {
      final holeSpans = _scanlineIntervals(hole, y, vertical: false);
      if (holeSpans.isNotEmpty) {
        result = _subtractSpans(result, holeSpans);
        if (result.isEmpty) break;
      }
    }
    return result;
  }

  /// Standard half-open scanline polygon intersection along x=[coord] (vertical)
  /// or y=[coord] (horizontal).
  static List<(double, double)> _scanlineIntervals(
    List<Offset> poly,
    double coord, {
    required bool vertical,
  }) {
    final hits = <double>[];
    final n = poly.length;
    for (var i = 0; i < n; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % n];
      final aPrimary = vertical ? a.dx : a.dy;
      final bPrimary = vertical ? b.dx : b.dy;
      final aOther = vertical ? a.dy : a.dx;
      final bOther = vertical ? b.dy : b.dx;
      if ((aPrimary <= coord && bPrimary > coord) ||
          (bPrimary <= coord && aPrimary > coord)) {
        final t = (coord - aPrimary) / (bPrimary - aPrimary);
        hits.add(aOther + t * (bOther - aOther));
      }
    }
    if (hits.length < 2) return const [];
    hits.sort();
    final spans = <(double, double)>[];
    for (var i = 0; i + 1 < hits.length; i += 2) {
      if (hits[i + 1] - hits[i] > 1e-5) {
        spans.add((hits[i], hits[i + 1]));
      }
    }
    return spans;
  }

  static List<(double, double)> _subtractSpans(
    List<(double, double)> base,
    List<(double, double)> cuts,
  ) {
    var current = base;
    for (final (c0, c1) in cuts) {
      final next = <(double, double)>[];
      for (final (a, b) in current) {
        if (c1 <= a || c0 >= b) {
          next.add((a, b));
        } else {
          if (c0 > a) next.add((a, c0));
          if (c1 < b) next.add((c1, b));
        }
      }
      current = next;
      if (current.isEmpty) break;
    }
    return current;
  }

  /// Section intervals `[a, b]` along [section] inside [ceiling] excluding holes.
  static List<(double, double)> sectionIntervals(
    ArchitectSuspendedCeiling ceiling,
    ArchitectSection section,
  ) => ArchitectSlabGeometry.contourIntervals(
    ceiling.tessellatedPolygon,
    ceiling.holes,
    section,
  );

  /// Convex 2D fragments for 3D extrusion of [ceiling] with holes subtracted.
  static List<List<Offset>> footprint(ArchitectSuspendedCeiling ceiling) =>
      ArchitectSlabGeometry.contourFootprint(
        ceiling.tessellatedPolygon,
        ceiling.holes,
      );

  /// Generates 3D triangles for [ceiling] anchored below the upper slab.
  static List<Triangle3D> mesh(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final pieces = footprint(ceiling);
    if (pieces.isEmpty) return const [];
    final metrics = computeMetrics(project, storey, ceiling);
    final zBottom = metrics.ceilingElevation;
    final zPanelTop = zBottom + ceiling.effectivePanelThickness;
    final zCarrierTop = zPanelTop + ceiling.gridSystemHeight;

    final panelColor = ceiling.type == SuspendedCeilingType.armstrong
        ? const Color(0xFFF4F6F8)
        : const Color(0xFFECE9E2);
    const carrierColor = Color(0xFFB0BEC5);
    const woolColor = Color(0xFFDDD295);

    final result = <Triangle3D>[];

    void extrudeLayer(double z0, double z1, Color color) {
      if (z1 - z0 <= 1e-5) return;
      for (final p in pieces) {
        Vector3 v(int i, bool top) =>
            Vector3(p[i].dx, p[i].dy, top ? z1 : z0);
        void face(Vector3 a, Vector3 b, Vector3 c) => result.add(
          Triangle3D(v0: a, v1: b, v2: c, color: color, isDoubleSided: true),
        );
        for (var i = 1; i < p.length - 1; i++) {
          face(v(0, true), v(i, true), v(i + 1, true));
          face(v(0, false), v(i + 1, false), v(i, false));
        }
        for (var i = 0; i < p.length; i++) {
          final j = (i + 1) % p.length;
          face(v(i, false), v(j, false), v(j, true));
          face(v(i, false), v(j, true), v(i, true));
        }
      }
    }

    extrudeLayer(zBottom, zPanelTop, panelColor);
    extrudeLayer(zPanelTop, zCarrierTop, carrierColor);
    if (ceiling.hasInsulation && ceiling.insulationThickness > 1e-4) {
      extrudeLayer(
        zCarrierTop,
        zCarrierTop + ceiling.insulationThickness,
        woolColor,
      );
    }
    return result;
  }
}
