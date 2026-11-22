import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_overlap.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_contour.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_vertical_clip.dart';
import 'architect_roof_geometry.dart';
import 'architect_roof_junctions.dart';
import 'architect_slab_geometry.dart';

/// What structural/enclosing boundary exists directly above a suspended ceiling.
enum CeilingOverheadSupport {
  upperSlab,
  roof,
  freeSpace,
}

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
  /// Overhead support category detected above this ceiling.
  final CeilingOverheadSupport overheadSupport;

  /// Absolute reference elevation (m) above the ceiling (slab underside, roof
  /// peak underside in footprint, or storey height fallback minus slab).
  final double upperSlabBottom;

  /// True if [upperSlabBottom] came from an actual modeled slab above.
  final bool fromActualUpperSlab;

  /// Minimum and maximum roof underside elevation (m) over the ceiling when
  /// [overheadSupport] is [CeilingOverheadSupport.roof].
  final double? roofMinUnderside;
  final double? roofMaxUnderside;

  /// Absolute elevation (m) of the visible bottom face of the ceiling.
  final double ceilingElevation;

  /// Clear height (m) from the current storey's finished floor to [ceilingElevation].
  final double clearHeight;

  /// Free cavity (m) between the top of the ceiling assembly and [upperSlabBottom].
  final double plenumDepth;

  /// True when a ceiling under a roof lies completely above the roof underside
  /// and therefore produces no remaining geometry after slope clipping.
  final bool isFullyClippedByRoof;

  /// Overhead beams colliding with the ceiling assembly.
  final List<CeilingBeamConflict> beamConflicts;

  const CeilingElevationMetrics({
    this.overheadSupport = CeilingOverheadSupport.freeSpace,
    required this.upperSlabBottom,
    required this.fromActualUpperSlab,
    this.roofMinUnderside,
    this.roofMaxUnderside,
    required this.ceilingElevation,
    required this.clearHeight,
    required this.plenumDepth,
    this.isFullyClippedByRoof = false,
    this.beamConflicts = const [],
  });

  bool get isUnderRoof => overheadSupport == CeilingOverheadSupport.roof;
  bool get isFreeSpace => overheadSupport == CeilingOverheadSupport.freeSpace;
  double get effectiveDrop => upperSlabBottom - ceilingElevation;
  bool get hasPlenumConflict =>
      isFullyClippedByRoof ||
      (!isFreeSpace && plenumDepth < -1e-4) ||
      (isFreeSpace && clearHeight < 0.1);
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

  /// Collects probe points across [polygon] (centroid, vertices, and edge
  /// midpoints) for overhead slab / roof detection.
  static List<Offset> _probePoints(List<Offset> polygon) {
    if (polygon.isEmpty) return const [];
    var cx = 0.0, cy = 0.0;
    for (final p in polygon) {
      cx += p.dx;
      cy += p.dy;
    }
    final pts = <Offset>[Offset(cx / polygon.length, cy / polygon.length)];
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      pts.add(a);
      pts.add((a + b) * 0.5);
    }
    return pts;
  }

  /// Returns whether an actual modeled upper structural slab covers [polygon]
  /// on the storey above [storey] (or the roof storey on the top floor).
  static bool hasActualUpperSlab(
    ArchitectProject project,
    ArchitectStorey storey,
    List<Offset> polygon,
  ) {
    if (polygon.length < 3) return false;
    final probe = ArchitectSuspendedCeiling(id: '', polygon: polygon);
    return resolveOverheadSupport(project, storey, probe).support ==
        CeilingOverheadSupport.upperSlab;
  }

  /// Resolves the overhead structural boundary (slab underside, sloped roof
  /// soffit range, or free-space height fallback) over [ceiling].
  static ({
    CeilingOverheadSupport support,
    double bottom,
    bool fromActualSlab,
    double? roofMinZ,
    double? roofMaxZ,
  })
  resolveOverheadSupport(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final upper = upperStoreyOf(project, storey);
    final candidateStoreys = <ArchitectStorey>[
      if (upper != null) upper,
      if (upper == null && project.roofStorey != null) project.roofStorey!,
    ];

    final samples = _probePoints(ceiling.tessellatedPolygon);

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
      return (
        support: CeilingOverheadSupport.upperSlab,
        bottom: lowestSlabBottom,
        fromActualSlab: true,
        roofMinZ: null,
        roofMaxZ: null,
      );
    }

    final roofStorey = project.roofStorey;
    if (upper == null &&
        roofStorey != null &&
        roofStorey.roofs.isNotEmpty &&
        samples.isNotEmpty) {
      final roofZs = <double>[];
      for (final pt in samples) {
        final z = ArchitectRoofGeometry.roofUndersideZAt(roofStorey, pt);
        if (z != null) roofZs.add(z);
      }
      if (roofZs.isNotEmpty) {
        final minZ = roofZs.reduce(math.min);
        final maxZ = roofZs.reduce(math.max);
        return (
          support: CeilingOverheadSupport.roof,
          bottom: maxZ,
          fromActualSlab: false,
          roofMinZ: minZ,
          roofMaxZ: maxZ,
        );
      }
    }

    final fallbackUpperTop = upper != null
        ? upper.elevation
        : (storey.elevation + storey.height);
    return (
      support: CeilingOverheadSupport.freeSpace,
      bottom: fallbackUpperTop - defaultUpperSlabThickness,
      fromActualSlab: false,
      roofMinZ: null,
      roofMaxZ: null,
    );
  }

  /// Backward-compatible wrapper returning the reference underside elevation
  /// and whether an actual upper slab was found.
  static ({double bottom, bool fromActualSlab}) resolveUpperSlabBottom(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final info = resolveOverheadSupport(project, storey, ceiling);
    return (bottom: info.bottom, fromActualSlab: info.fromActualSlab);
  }

  /// Computes absolute ceiling elevation, clear floor-to-ceiling height,
  /// plenum cavity depth, and overhead beam collisions.
  static CeilingElevationMetrics computeMetrics(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    final overhead = resolveOverheadSupport(project, storey, ceiling);
    final ceilingElevation = switch (ceiling.elevationAnchor) {
      CeilingElevationAnchor.clearHeight =>
        storey.elevation + ceiling.clearHeight,
      CeilingElevationAnchor.fromUpperSlab =>
        overhead.bottom - ceiling.dropFromUpperSlab,
    };
    final clearHeight = ceilingElevation - storey.elevation;
    final ceilingTop = ceilingElevation + ceiling.constructionThickness;
    final plenumDepth = overhead.bottom - ceilingTop;

    var fullyClipped = false;
    if (overhead.support == CeilingOverheadSupport.roof &&
        overhead.roofMaxZ != null &&
        ceiling.polygon.length >= 3) {
      fullyClipped = ceilingElevation >= overhead.roofMaxZ! - 1e-4;
      if (!fullyClipped) {
        final clipped = _clipPathToRoof(
          project: project,
          ceiling: ceiling,
          cutZ: ceilingElevation,
        );
        fullyClipped = clipped.getBounds().isEmpty;
      }
    }

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
      overheadSupport: overhead.support,
      upperSlabBottom: overhead.bottom,
      fromActualUpperSlab: overhead.fromActualSlab,
      roofMinUnderside: overhead.roofMinZ,
      roofMaxUnderside: overhead.roofMaxZ,
      ceilingElevation: ceilingElevation,
      clearHeight: clearHeight,
      plenumDepth: plenumDepth,
      isFullyClippedByRoof: fullyClipped,
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

  static Path _clipPathToRoof({
    required ArchitectProject project,
    required ArchitectSuspendedCeiling ceiling,
    required double cutZ,
  }) {
    final rawPath = ArchitectContour.path(
      ceiling.polygon,
      ceiling.holes,
      bulges: ceiling.bulges,
    );
    final roofStorey = project.roofStorey;
    if (roofStorey == null || roofStorey.roofs.isEmpty) return rawPath;

    final junctions = ArchitectRoofJunctions.of(roofStorey, project: project);
    var roofUnion = Path();
    var validCovered = Path();

    for (final roof in roofStorey.roofs) {
      final fp = junctions.footprint(roof);
      if (fp.getBounds().isEmpty) continue;
      roofUnion = Path.combine(PathOperation.union, roofUnion, fp);
      final over = Path.combine(PathOperation.intersect, rawPath, fp);
      if (over.getBounds().isEmpty) continue;
      final clipped = ArchitectVerticalClip.positive(
        over,
        (p) => roofStorey.elevation + roof.undersideElevationAt(p) - cutZ,
      );
      if (!clipped.getBounds().isEmpty) {
        validCovered = Path.combine(PathOperation.union, validCovered, clipped);
      }
    }

    if (roofUnion.getBounds().isEmpty) return rawPath;
    final outsideRoofs = Path.combine(PathOperation.difference, rawPath, roofUnion);
    if (outsideRoofs.getBounds().isEmpty) return validCovered;
    if (validCovered.getBounds().isEmpty) return outsideRoofs;
    return Path.combine(PathOperation.union, outsideRoofs, validCovered);
  }

  /// Returns the effective 2D ceiling path for [ceiling], automatically clipped
  /// against overhead roof slopes when placed directly beneath a roof without
  /// an intervening structural slab.
  static Path effectivePath(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling, {
    CeilingElevationMetrics? metrics,
  }) {
    final rawPath = ArchitectContour.path(
      ceiling.polygon,
      ceiling.holes,
      bulges: ceiling.bulges,
    );
    if (ceiling.polygon.length < 3) return rawPath;
    final m = metrics ?? computeMetrics(project, storey, ceiling);
    if (m.overheadSupport != CeilingOverheadSupport.roof) return rawPath;
    return _clipPathToRoof(
      project: project,
      ceiling: ceiling,
      cutZ: m.ceilingElevation,
    );
  }

  /// Trims section intervals `[a, b]` along [section] to regions where the
  /// ceiling is not clipped away by an overhead roof underside at [cutZ].
  static List<(double, double)> trimSectionSpansToRoof({
    required ArchitectProject project,
    required ArchitectSection section,
    required List<(double, double)> spans,
    required double cutZ,
  }) {
    final roofStorey = project.roofStorey;
    if (roofStorey == null || roofStorey.roofs.isEmpty || spans.isEmpty) {
      return spans;
    }

    bool fitsAt(double s) {
      final pt = section.pointAt(s);
      final roofZ = ArchitectRoofGeometry.roofUndersideZAt(roofStorey, pt);
      return roofZ == null || roofZ >= cutZ - 1e-5;
    }

    double bisectTransition(double a, double b, bool aFits) {
      var lo = a;
      var hi = b;
      for (var i = 0; i < 16; i++) {
        final mid = (lo + hi) * 0.5;
        if (fitsAt(mid) == aFits) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      return (lo + hi) * 0.5;
    }

    final result = <(double, double)>[];
    for (final (a, b) in spans) {
      if (b - a <= 1e-5) continue;
      final steps = math.max(8, ((b - a) / 0.05).ceil()).clamp(8, 512);
      final ds = (b - a) / steps;
      var prevS = a;
      var prevFits = fitsAt(a);
      double? activeStart = prevFits ? a : null;

      for (var i = 1; i <= steps; i++) {
        final curS = i == steps ? b : a + i * ds;
        final curFits = fitsAt(curS);
        if (curFits != prevFits) {
          final cross = bisectTransition(prevS, curS, prevFits);
          if (curFits) {
            activeStart = cross;
          } else if (activeStart != null && cross - activeStart > 1e-4) {
            result.add((activeStart, cross));
            activeStart = null;
          } else {
            activeStart = null;
          }
        }
        prevS = curS;
        prevFits = curFits;
      }
      if (activeStart != null && b - activeStart > 1e-4) {
        result.add((activeStart, b));
      }
    }
    return result;
  }

  /// Resolves the top anchor elevation (m) for a suspension hanger at [worldPt].
  /// Returns `null` when no structural slab or roof covers that point.
  static double? hangerTopElevationAt(
    ArchitectProject project,
    CeilingElevationMetrics metrics,
    Offset worldPt,
  ) {
    return switch (metrics.overheadSupport) {
      CeilingOverheadSupport.upperSlab => metrics.upperSlabBottom,
      CeilingOverheadSupport.roof =>
        project.roofStorey == null
            ? null
            : ArchitectRoofGeometry.roofUndersideZAt(
                project.roofStorey!,
                worldPt,
              ),
      CeilingOverheadSupport.freeSpace => null,
    };
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

  /// Generates 3D triangles for [ceiling] (automatically roof-clipped when
  /// placed directly under a sloped roof without an upper slab).
  static List<Triangle3D> mesh(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSuspendedCeiling ceiling,
  ) {
    if (ceiling.polygon.length < 3) return const [];
    final metrics = computeMetrics(project, storey, ceiling);
    final path = effectivePath(project, storey, ceiling, metrics: metrics);
    if (path.getBounds().isEmpty) return const [];

    final zBottom = metrics.ceilingElevation;
    final zPanelTop = zBottom + ceiling.effectivePanelThickness;
    final zCarrierTop = zPanelTop + ceiling.gridSystemHeight;

    final panelColor = ceiling.type == SuspendedCeilingType.armstrong
        ? const Color(0xFFF4F6F8)
        : const Color(0xFFECE9E2);
    const carrierColor = Color(0xFFB0BEC5);
    const woolColor = Color(0xFFDDD295);

    return [
      ...ArchitectPathSolid.extrude(path, zBottom, zPanelTop, panelColor),
      ...ArchitectPathSolid.extrude(path, zPanelTop, zCarrierTop, carrierColor),
      if (ceiling.hasInsulation && ceiling.insulationThickness > 1e-4)
        ...ArchitectPathSolid.extrude(
          path,
          zCarrierTop,
          zCarrierTop + ceiling.insulationThickness,
          woolColor,
        ),
    ];
  }
}
