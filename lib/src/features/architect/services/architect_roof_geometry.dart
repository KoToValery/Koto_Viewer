// === SECTION: TABLE OF CONTENTS ===
// 1. Data Structures (ArchitectRoofEdgeKind, ArchitectRoofSectionMember, ArchitectRoofSectionSlice)
// 2. Auto-Roof Generator (Gable / Hip / Shed / Flat from building walls or slabs)
// 3. Plan Edge Classification & Wall Support Line
// 4. Section Cut Geometry (Mitered Layers, Discrete Battens, Rafters, Mauerlat, Ridge Purlin)
// 5. Wall-to-Roof Clipping & Height Adaptation

import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_wall_network.dart';
import 'architect_element_id.dart';
import 'architect_polygon_geometry.dart';

// === SECTION: DATA STRUCTURES ===

enum ArchitectRoofEdgeKind {
  eaves,
  ridge,
  hipOrValley,
  verge,
}

enum ArchitectRoofMemberKind {
  layer,
  tileProfile,
  batten,
  counterBatten,
  rafter,
  wallPlate,
  ringBeam,
  ridgePurlin,
  fascia,
  metalFlashing,
}

class ArchitectRoofSectionMember {
  final String roofId;
  final ArchitectRoofMemberKind kind;
  final ArchitectRoofLayerRole? role;
  final ArchitectRoofMaterial? material;
  final Path path;
  final List<Offset> polygon;
  final bool drawTimberDiagonals;

  const ArchitectRoofSectionMember({
    required this.roofId,
    required this.kind,
    required this.path,
    required this.polygon,
    this.role,
    this.material,
    this.drawTimberDiagonals = false,
  });
}

class ArchitectRoofSectionSlice {
  final String roofId;
  final double fromS;
  final double toS;
  final List<ArchitectRoofSectionMember> members;
  /// Bottom boundary points `(s, z)` of the roof assembly along `[fromS, toS]`.
  final List<Offset> bottomProfile;
  /// Full outer envelope path of the roof slice (for boolean wall trimming).
  final Path envelopePath;
  /// Horizontal wall cap intervals `[fromS, toS]` where supporting walls terminate at `maxWallZ` (bottom of 10 cm concrete ring beam).
  final List<({double fromS, double toS, double maxWallZ})> wallCapIntervals;

  const ArchitectRoofSectionSlice({
    required this.roofId,
    required this.fromS,
    required this.toS,
    required this.members,
    required this.bottomProfile,
    required this.envelopePath,
    this.wallCapIntervals = const [],
  });
}

// === SECTION: AUTO-ROOF GENERATOR ===

class ArchitectRoofGeometry {
  /// Generates a complete roof (Gable, Hip, Shed, or Flat) over the exterior walls
  /// or slabs of the active storey (or the supporting storey immediately below if active storey has no walls).
  static List<ArchitectRoofPlane> generateAutoRoof({
    required ArchitectProject project,
    required AutoRoofType type,
    double slopeDegrees = 22.0,
    double eavesOverhang = 0.50,
    ArchitectRoofPreset? preset,
  }) {
    final storey = project.activeStorey;
    final storeyIdx = project.storeys.indexWhere((s) => s.id == storey.id);

    // Find reference walls or slabs (from active storey or storey below)
    var walls = storey.walls;
    if (walls.isEmpty && storeyIdx > 0) {
      walls = project.storeys[storeyIdx - 1].walls;
    }

    final hullPoints = <Offset>[];
    for (final w in walls) {
      if (!w.isParapet) {
        hullPoints.addAll(w.polygonCorners);
      }
    }
    if (hullPoints.isEmpty) {
      for (final w in walls) {
        hullPoints.addAll(w.polygonCorners);
      }
    }
    if (hullPoints.isEmpty) {
      final slabs = storey.slabs.isNotEmpty
          ? storey.slabs
          : (storeyIdx > 0 ? project.storeys[storeyIdx - 1].slabs : const []);
      for (final s in slabs) {
        hullPoints.addAll(s.polygon);
      }
    }
    if (hullPoints.length < 3) return const [];

    var minX = hullPoints.first.dx, maxX = hullPoints.first.dx;
    var minY = hullPoints.first.dy, maxY = hullPoints.first.dy;
    for (final p in hullPoints.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    if ((maxX - minX) < 0.5 || (maxY - minY) < 0.5) return const [];

    final overhang = type == AutoRoofType.flat ? 0.0 : eavesOverhang;
    final left = minX - overhang;
    final right = maxX + overhang;
    final top = minY - overhang;
    final bottom = maxY + overhang;
    final width = right - left;
    final depth = bottom - top;

    final effectivePreset =
        preset ??
        (type == AutoRoofType.flat
            ? ArchitectRoofPreset.flatWarm
            : ArchitectRoofPreset.pitchedTiles);
    final assembly = ArchitectRoofAssembly.fromPreset(effectivePreset);
    final baseZ = storey.walls.isEmpty && storeyIdx > 0 ? 0.0 : storey.height;
    final groupId = ArchitectElementId.next('roof_grp');

    // Multi-pitch Straight Skeleton generation over real exterior walls (supports L-shape, T-shape, articulated walls)
    if (type == AutoRoofType.hip && walls.isNotEmpty) {
      final wallPath = ArchitectWallNetwork.body(walls);
      final rawContours = ArchitectPathSolid.contours(wallPath);
      if (rawContours.isNotEmpty) {
        var maxArea = 0.0;
        List<Offset>? largest;
        for (final c in rawContours) {
          final cleaned = BimPolygonGeometry.clean(c, removeCollinear: true);
          final area = BimPolygonGeometry.signedArea(cleaned).abs();
          if (area > maxArea && cleaned.length >= 3) {
            maxArea = area;
            largest = cleaned;
          }
        }
        if (largest != null && maxArea > 1.0) {
          final eavesPoly = offsetPolygonOutwards(largest, overhang);
          final planes = decomposeMultiPitchPolygon(
            eavesPolygon: eavesPoly,
            storey: storey,
            slopeDegrees: slopeDegrees,
            baseElevationOffset: baseZ,
            eavesOverhang: overhang,
            assembly: assembly,
            roofGroupId: groupId,
          );
          if (planes.isNotEmpty) {
            return planes;
          }
        }
      }
    }

    ArchitectRoofPlane makePlane(
      List<Offset> pts, {
      int eavesEdge = 0,
      double? slopeOverride,
    }) => ArchitectRoofPlane(
      id: ArchitectElementId.next('roof'),
      storeyId: storey.id,
      points: pts,
      eavesEdgeIndex: eavesEdge,
      slopeDegrees: slopeOverride ?? slopeDegrees,
      baseElevationOffset: baseZ,
      eavesOverhang: overhang,
      assembly: assembly.copyWith(),
      roofGroupId: groupId,
    );

    switch (type) {
      case AutoRoofType.flat:
        return [
          makePlane(
            [
              Offset(left, top),
              Offset(right, top),
              Offset(right, bottom),
              Offset(left, bottom),
            ],
            eavesEdge: 0,
            slopeOverride: 1.5,
          ),
        ];

      case AutoRoofType.shed:
        return [
          makePlane(
            [
              Offset(left, bottom),
              Offset(right, bottom),
              Offset(right, top),
              Offset(left, top),
            ],
            eavesEdge: 0,
            slopeOverride: slopeDegrees.clamp(3.0, 45.0),
          ),
        ];

      case AutoRoofType.gable:
        if (width >= depth) {
          final midY = (top + bottom) / 2.0;
          return [
            // North/Top slope: eaves along top edge (left,top)->(right,top)
            makePlane([
              Offset(left, top),
              Offset(right, top),
              Offset(right, midY),
              Offset(left, midY),
            ], eavesEdge: 0),
            // South/Bottom slope: eaves along bottom edge (right,bottom)->(left,bottom)
            makePlane([
              Offset(right, bottom),
              Offset(left, bottom),
              Offset(left, midY),
              Offset(right, midY),
            ], eavesEdge: 0),
          ];
        } else {
          final midX = (left + right) / 2.0;
          return [
            // West/Left slope: eaves along left edge (left,bottom)->(left,top)
            makePlane([
              Offset(left, bottom),
              Offset(left, top),
              Offset(midX, top),
              Offset(midX, bottom),
            ], eavesEdge: 0),
            // East/Right slope: eaves along right edge (right,top)->(right,bottom)
            makePlane([
              Offset(right, top),
              Offset(right, bottom),
              Offset(midX, bottom),
              Offset(midX, top),
            ], eavesEdge: 0),
          ];
        }

      case AutoRoofType.hip:
        if (width >= depth) {
          final halfSpan = depth / 2.0;
          final midY = (top + bottom) / 2.0;
          final rLeft = Offset(
            math.min((left + right) / 2.0, left + halfSpan),
            midY,
          );
          final rRight = Offset(
            math.max((left + right) / 2.0, right - halfSpan),
            midY,
          );
          final isPyramid = (rRight.dx - rLeft.dx).abs() < 1e-3;
          return [
            // Top trapezoid (or triangle if pyramid)
            makePlane(
              isPyramid
                  ? [Offset(left, top), Offset(right, top), rLeft]
                  : [Offset(left, top), Offset(right, top), rRight, rLeft],
              eavesEdge: 0,
            ),
            // Bottom trapezoid (or triangle if pyramid)
            makePlane(
              isPyramid
                  ? [Offset(right, bottom), Offset(left, bottom), rLeft]
                  : [
                      Offset(right, bottom),
                      Offset(left, bottom),
                      rLeft,
                      rRight,
                    ],
              eavesEdge: 0,
            ),
            // Left hip triangle
            makePlane(
              [Offset(left, bottom), Offset(left, top), rLeft],
              eavesEdge: 0,
            ),
            // Right hip triangle
            makePlane(
              [Offset(right, top), Offset(right, bottom), rRight],
              eavesEdge: 0,
            ),
          ];
        } else {
          final halfSpan = width / 2.0;
          final midX = (left + right) / 2.0;
          final rTop = Offset(
            midX,
            math.min((top + bottom) / 2.0, top + halfSpan),
          );
          final rBottom = Offset(
            midX,
            math.max((top + bottom) / 2.0, bottom - halfSpan),
          );
          final isPyramid = (rBottom.dy - rTop.dy).abs() < 1e-3;
          return [
            // Left trapezoid
            makePlane(
              isPyramid
                  ? [Offset(left, bottom), Offset(left, top), rTop]
                  : [Offset(left, bottom), Offset(left, top), rTop, rBottom],
              eavesEdge: 0,
            ),
            // Right trapezoid
            makePlane(
              isPyramid
                  ? [Offset(right, top), Offset(right, bottom), rTop]
                  : [Offset(right, top), Offset(right, bottom), rBottom, rTop],
              eavesEdge: 0,
            ),
            // Top hip triangle
            makePlane(
              [Offset(left, top), Offset(right, top), rTop],
              eavesEdge: 0,
            ),
            // Bottom hip triangle
            makePlane(
              [Offset(right, bottom), Offset(left, bottom), rBottom],
              eavesEdge: 0,
            ),
          ];
        }
    }
  }

  /// Offsets closed polygon [polygon] outwards by [distance].
  static List<Offset> offsetPolygonOutwards(List<Offset> polygon, double distance) {
    if (distance <= 0.001 || polygon.length < 3) return polygon;
    final n = polygon.length;
    final isCcw = BimPolygonGeometry.signedArea(polygon) > 0;
    final pts = isCcw ? polygon : polygon.reversed.toList();

    final result = <Offset>[];
    for (var i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n];
      final curr = pts[i];
      final next = pts[(i + 1) % n];

      final ePrev = curr - prev;
      final eNext = next - curr;
      if (ePrev.distance < 1e-6 || eNext.distance < 1e-6) continue;

      // Outward unit normal for CCW polygon: (dy, -dx)
      final nPrev = Offset(ePrev.dy, -ePrev.dx) / ePrev.distance;
      final nNext = Offset(eNext.dy, -eNext.dx) / eNext.distance;

      // Bisector vector pointing outwards
      final b = nPrev + nNext;
      final denom = 1.0 + (nPrev.dx * nNext.dx + nPrev.dy * nNext.dy);
      if (denom.abs() < 1e-4) {
        result.add(curr + nPrev * distance);
      } else {
        final v = b / denom;
        result.add(curr + v * distance);
      }
    }
    final cleaned = BimPolygonGeometry.clean(result, removeCollinear: true);
    return cleaned.length >= 3 ? cleaned : polygon;
  }

  /// Decomposes an arbitrary closed polygon [eavesPolygon] into matching hipped roof planes
  /// using straight skeleton bisector decomposition.
  /// Generates clean planar faces with 45° hips, 45° valleys (at reflex corners),
  /// and horizontal ridges.
  static List<ArchitectRoofPlane> decomposeMultiPitchPolygon({
    required List<Offset> eavesPolygon,
    required ArchitectStorey storey,
    required double slopeDegrees,
    required double baseElevationOffset,
    required double eavesOverhang,
    required ArchitectRoofAssembly assembly,
    String? roofGroupId,
  }) {
    final cleaned = BimPolygonGeometry.clean(eavesPolygon, removeCollinear: true);
    if (cleaned.length < 3) return const [];

    final isCcw = BimPolygonGeometry.signedArea(cleaned) > 0;
    final poly = isCcw ? cleaned : cleaned.reversed.toList();
    final n = poly.length;
    final groupId = roofGroupId ?? ArchitectElementId.next('roof_grp');

    final planes = <ArchitectRoofPlane>[];

    // For each edge i, construct its face by clipping poly against all bisector half-planes
    for (var i = 0; i < n; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % n];
      final edgeDir = b - a;
      if (edgeDir.distance < 0.05) continue;

      // Inward unit normal for CCW polygon: (-dy, dx)
      final normI = Offset(-edgeDir.dy, edgeDir.dx) / edgeDir.distance;

      var facePoly = List<Offset>.from(poly);

      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final aJ = poly[j];
        final bJ = poly[(j + 1) % n];
        final edgeJDir = bJ - aJ;
        if (edgeJDir.distance < 0.05) continue;

        final normJ = Offset(-edgeJDir.dy, edgeJDir.dx) / edgeJDir.distance;

        // Condition: dist(P, Edge_i) <= dist(P, Edge_j)
        // (P - a) . normI <= (P - aJ) . normJ
        // P . (normI - normJ) <= a . normI - aJ . normJ
        final deltaNorm = normI - normJ;
        if (deltaNorm.distance < 1e-6) continue;

        final rhs = BimPolygonGeometry.dot(a, normI) - BimPolygonGeometry.dot(aJ, normJ);

        facePoly = _clipPolygonByHalfPlane(facePoly, deltaNorm, rhs);
        if (facePoly.length < 3) break;
      }

      if (facePoly.length >= 3) {
        // Ensure edge i is at index 0 (safeEavesEdgeIndex)
        final orderedFace = _alignFaceToEaves(facePoly, a, b);
        if (orderedFace.length >= 3 && BimPolygonGeometry.signedArea(orderedFace).abs() > 0.05) {
          planes.add(
            ArchitectRoofPlane(
              id: ArchitectElementId.next('roof'),
              storeyId: storey.id,
              points: orderedFace,
              eavesEdgeIndex: 0,
              slopeDegrees: slopeDegrees,
              baseElevationOffset: baseElevationOffset,
              eavesOverhang: eavesOverhang,
              assembly: assembly.copyWith(),
              roofGroupId: groupId,
            ),
          );
        }
      }
    }

    return planes;
  }

  static List<Offset> _clipPolygonByHalfPlane(
    List<Offset> poly,
    Offset normal,
    double c,
  ) {
    if (poly.length < 3) return const [];
    final output = <Offset>[];

    bool isInside(Offset p) => (p.dx * normal.dx + p.dy * normal.dy) <= c + 1e-6;

    Offset intersect(Offset p1, Offset p2) {
      final val1 = p1.dx * normal.dx + p1.dy * normal.dy - c;
      final val2 = p2.dx * normal.dx + p2.dy * normal.dy - c;
      final denom = val2 - val1;
      if (denom.abs() < 1e-9) return p1;
      final t = (-val1 / denom).clamp(0.0, 1.0);
      return p1 + (p2 - p1) * t;
    }

    for (var k = 0; k < poly.length; k++) {
      final curr = poly[k];
      final next = poly[(k + 1) % poly.length];
      final currIn = isInside(curr);
      final nextIn = isInside(next);

      if (currIn) {
        if (nextIn) {
          output.add(next);
        } else {
          output.add(intersect(curr, next));
        }
      } else {
        if (nextIn) {
          output.add(intersect(curr, next));
          output.add(next);
        }
      }
    }
    return BimPolygonGeometry.clean(output, removeCollinear: true);
  }

  static List<Offset> _alignFaceToEaves(
    List<Offset> face,
    Offset eavesA,
    Offset eavesB,
  ) {
    if (face.length < 3) return face;
    var bestIdx = -1;
    var bestDist = 0.20;
    for (var k = 0; k < face.length; k++) {
      final p1 = face[k];
      final p2 = face[(k + 1) % face.length];
      final d = (p1 - eavesA).distance + (p2 - eavesB).distance;
      if (d < bestDist) {
        bestDist = d;
        bestIdx = k;
      }
    }
    if (bestIdx == 0) return face;
    if (bestIdx > 0) {
      return [
        ...face.sublist(bestIdx),
        ...face.sublist(0, bestIdx),
      ];
    }
    return face;
  }

  // === SECTION: PLAN EDGE CLASSIFICATION & WALL SUPPORT LINE ===

  /// Classifies edge [edgeIndex] of [roof] relative to adjacent roof planes on the same storey.
  static ArchitectRoofEdgeKind classifyEdge(
    ArchitectRoofPlane roof,
    int edgeIndex,
    List<ArchitectRoofPlane> allRoofs,
  ) {
    final n = roof.points.length;
    if (n < 2) return ArchitectRoofEdgeKind.verge;
    if (edgeIndex == roof.safeEavesEdgeIndex) {
      return ArchitectRoofEdgeKind.eaves;
    }
    final a = roof.points[edgeIndex % n];
    final b = roof.points[(edgeIndex + 1) % n];

    for (final other in allRoofs) {
      if (other.id == roof.id || other.points.length < 2) continue;
      for (var j = 0; j < other.points.length; j++) {
        final oa = other.points[j];
        final ob = other.points[(j + 1) % other.points.length];
        final sharesSame =
            ((a - oa).distance < 0.05 && (b - ob).distance < 0.05) ||
            ((a - ob).distance < 0.05 && (b - oa).distance < 0.05);
        if (sharesSame) {
          final za = roof.topElevationAt(a);
          final zb = roof.topElevationAt(b);
          return (za - zb).abs() < 0.04
              ? ArchitectRoofEdgeKind.ridge
              : ArchitectRoofEdgeKind.hipOrValley;
        }
      }
    }
    final za = roof.topElevationAt(a);
    final zb = roof.topElevationAt(b);
    if ((za - zb).abs() < 0.02 && roof.signedDistanceFromEaves(a) > 0.1) {
      return ArchitectRoofEdgeKind.ridge;
    }
    return ArchitectRoofEdgeKind.verge;
  }

  /// Returns the inner wall bearing line segment `(p1, p2)` shifted inward from
  /// the eaves edge by `roof.eavesOverhang`, clipped to the roof polygon.
  static (Offset, Offset)? wallBearingLine(ArchitectRoofPlane roof) {
    if (roof.eavesOverhang <= 0.01 || roof.points.length < 3) return null;
    final (ea, eb) = roof.eavesEdge;
    final inward = roof.inwardNormalOfEdge(roof.safeEavesEdgeIndex);
    final shift = inward *
        (roof.reverseSlope
            ? (roof.maxSlopeRun - roof.eavesOverhang)
            : roof.eavesOverhang);
    final lineA = ea + shift;
    final lineB = eb + shift;
    final edgeDir = eb - ea;
    final len = edgeDir.distance;
    if (len < 1e-4) return null;
    final u = edgeDir / len;

    // Intersect infinite bearing line with roof polygon edges
    final tHits = <double>[];
    for (var i = 0; i < roof.points.length; i++) {
      final p1 = roof.points[i];
      final p2 = roof.points[(i + 1) % roof.points.length];
      final hit = _intersectLineWithSegment(lineA, lineB, p1, p2);
      if (hit != null) {
        final t = (hit - lineA).dx * u.dx + (hit - lineA).dy * u.dy;
        tHits.add(t);
      }
    }
    if (tHits.length < 2) {
      return (lineA, lineB);
    }
    tHits.sort();
    return (lineA + u * tHits.first, lineA + u * tHits.last);
  }

  static Offset? _intersectLineWithSegment(
    Offset l1,
    Offset l2,
    Offset s1,
    Offset s2,
  ) {
    final r = l2 - l1;
    final s = s2 - s1;
    final rxs = r.dx * s.dy - r.dy * s.dx;
    if (rxs.abs() < 1e-8) return null;
    final qp = s1 - l1;
    final u = (qp.dx * r.dy - qp.dy * r.dx) / rxs;
    if (u < -1e-5 || u > 1.0 + 1e-5) return null;
    return s1 + s * u.clamp(0.0, 1.0);
  }

  // === SECTION: SECTION CUT GEOMETRY (MITERED LAYERS & CARPENTRY) ===

  /// Resolves the effective `baseElevationOffset` of [roof] when `roof.attachToWalls` is enabled,
  /// aligning the roof bearing plane with the highest supporting non-parapet wall on [storey]
  /// (or [lowerStorey] if [storey] has no walls).
  static double resolveAttachedBaseElevationOffset({
    required ArchitectRoofPlane roof,
    required ArchitectStorey storey,
    ArchitectStorey? lowerStorey,
  }) {
    if (!roof.attachToWalls) return roof.baseElevationOffset;
    final candidateWalls = storey.walls.where((w) => !w.isParapet).toList();
    if (candidateWalls.isNotEmpty) {
      var maxH = 0.0;
      for (final w in candidateWalls) {
        final h = w.baseOffset + w.effectiveHeight(storey.height);
        if (h > maxH) maxH = h;
      }
      if (maxH > 0.0) return maxH;
    }
    if (storey.walls.isEmpty && lowerStorey != null) {
      final lowerWalls = lowerStorey.walls.where((w) => !w.isParapet).toList();
      if (lowerWalls.isNotEmpty) {
        var maxTopZ = double.negativeInfinity;
        for (final w in lowerWalls) {
          final topZ =
              lowerStorey.elevation + w.baseOffset + w.effectiveHeight(lowerStorey.height);
          if (topZ > maxTopZ) maxTopZ = topZ;
        }
        return maxTopZ - storey.elevation;
      }
    }
    return roof.baseElevationOffset;
  }

  /// Slices all roof planes on [storey] along the vertical section plane [sectionLine]
  /// and produces clean, non-overlapping layer polygons, mitered ridge joins,
  /// plumbed eaves with fascia boards, metal flashing (`метална обшивка`),
  /// discrete battens (`летви`), counter-battens, rafters (`ребра`),
  /// Mauerlat (`мауерлат`), 10 cm reinforced concrete ring beam (`10 см стоманобетонен пояс`),
  /// and ridge purlin (`билова столица`).
  static List<ArchitectRoofSectionSlice> buildSectionSlices({
    required ArchitectStorey storey,
    required ArchitectSection sectionLine,
    ArchitectStorey? lowerStorey,
  }) {
    if (storey.roofs.isEmpty) return const [];
    final lineVec = sectionLine.end - sectionLine.start;
    final lineLen = lineVec.distance;
    if (lineLen < 1e-6) return const [];
    final lineDir = lineVec / lineLen;

    // 0. Intersect supporting walls with sectionLine to find transverse wall intervals [wMin, wMax]
    final supportingWalls = storey.walls.isNotEmpty
        ? storey.walls
        : (lowerStorey?.walls ?? const []);
    final wallIntervals = <({double fromS, double toS})>[];
    for (final wall in supportingWalls) {
      if (wall.isParapet) continue;
      final corners = wall.polygonCorners;
      if (corners.length < 3) continue;
      final wHits = <double>[];
      for (var i = 0; i < corners.length; i++) {
        final a = corners[i];
        final b = corners[(i + 1) % corners.length];
        final hit = _intersectSegments(
          sectionLine.start,
          sectionLine.end,
          a,
          b,
        );
        if (hit != null) {
          final s =
              (hit - sectionLine.start).dx * lineDir.dx +
              (hit - sectionLine.start).dy * lineDir.dy;
          if (wHits.every((h) => (h - s).abs() > 1e-4)) {
            wHits.add(s);
          }
        }
      }
      if (wHits.length >= 2) {
        wHits.sort();
        final wMin = wHits.first;
        final wMax = wHits.last;
        final wSpan = wMax - wMin;
        // Transverse / oblique wall cross-section (exclude longitudinal gable wall cuts)
        if (wSpan >= 0.06 && wSpan <= 0.85) {
          wallIntervals.add((fromS: wMin, toS: wMax));
        }
      }
    }

    // 1. Collect raw 1D intervals [fromS, toS] for each roof plane crossed by the section line.
    final rawIntervals =
        <({ArchitectRoofPlane roof, double fromS, double toS})>[];
    for (final roof in storey.roofs) {
      if (roof.points.length < 3) continue;
      final hits = <double>[];
      for (var i = 0; i < roof.points.length; i++) {
        final a = roof.points[i];
        final b = roof.points[(i + 1) % roof.points.length];
        final hit = _intersectSegments(
          sectionLine.start,
          sectionLine.end,
          a,
          b,
        );
        if (hit != null) {
          final s =
              (hit - sectionLine.start).dx * lineDir.dx +
              (hit - sectionLine.start).dy * lineDir.dy;
          if (hits.every((h) => (h - s).abs() > 1e-4)) {
            hits.add(s);
          }
        }
      }
      if (roof.containsPoint(sectionLine.start) &&
          hits.every((h) => h.abs() > 1e-4)) {
        hits.add(0.0);
      }
      if (roof.containsPoint(sectionLine.end) &&
          hits.every((h) => (h - lineLen).abs() > 1e-4)) {
        hits.add(lineLen);
      }
      hits.sort();
      for (var i = 0; i + 1 < hits.length; i++) {
        final s0 = hits[i];
        final s1 = hits[i + 1];
        if (s1 - s0 < 0.02) continue;
        final midWorld = sectionLine.start + lineDir * ((s0 + s1) * 0.5);
        if (roof.containsPoint(midWorld)) {
          rawIntervals.add((roof: roof, fromS: s0, toS: s1));
        }
      }
    }

    if (rawIntervals.isEmpty) return const [];
    rawIntervals.sort((a, b) => a.fromS.compareTo(b.fromS));

    final draftSlices =
        <
          ({
            String roofId,
            double fromS,
            double toS,
            double zTop0,
            double zTop1,
            double totalVerticalThick,
            List<ArchitectRoofSectionMember> layerMembers,
            List<ArchitectRoofSectionMember> discreteMembers,
            List<({double fromS, double toS, double maxWallZ})> wallCapIntervals,
          })
        >[];

    for (var idx = 0; idx < rawIntervals.length; idx++) {
      final item = rawIntervals[idx];
      final roof = item.roof;
      final s0 = item.fromS;
      final s1 = item.toS;
      final p0 = sectionLine.start + lineDir * s0;
      final p1 = sectionLine.start + lineDir * s1;

      final zTop0 = storey.elevation + roof.topElevationAt(p0);
      final zTop1 = storey.elevation + roof.topElevationAt(p1);
      final zBot0 = storey.elevation + roof.undersideElevationAt(p0);
      final zBot1 = storey.elevation + roof.undersideElevationAt(p1);

      final cosSlope = math.cos(roof.slopeRadians).clamp(0.15, 1.0);
      final totalVerticalThick = roof.assembly.totalThickness / cosSlope;

      // Check if s0 or s1 is a ridge/valley joint with another roof slice
      final sharesStart = rawIntervals.any(
        (o) =>
            o.roof.id != roof.id &&
            ((o.toS - s0).abs() < 0.03 || (o.fromS - s0).abs() < 0.03),
      );
      final sharesEnd = rawIntervals.any(
        (o) =>
            o.roof.id != roof.id &&
            ((o.fromS - s1).abs() < 0.03 || (o.toS - s1).abs() < 0.03),
      );

      final layerMembers = <ArchitectRoofSectionMember>[];
      final discreteMembers = <ArchitectRoofSectionMember>[];
      final wallCapIntervals = <({double fromS, double toS, double maxWallZ})>[];
      final timber = roof.assembly.timber;

      // Apparent slope along the section line:
      final dzDs = (zTop1 - zTop0) / (s1 - s0);
      final apparentAngle = math.atan(dzDs);
      final cosApparent = math.cos(apparentAngle).clamp(0.15, 1.0);
      final slopeDirDotSection =
          (roof.slopeDirection.dx * lineDir.dx +
                  roof.slopeDirection.dy * lineDir.dy)
              .abs();

      // 2. Build continuous / mitered layers from top to bottom
      var cumulativePerp = 0.0;
      double? battenTopPerp;
      double? rafterTopPerp;
      double? rafterBotPerp;
      double coveringThickPerp = 0.04;

      for (final layer in roof.assembly.layers) {
        final dTopV = cumulativePerp / cosSlope;
        final dBotV = (cumulativePerp + layer.thickness) / cosSlope;

        if (layer.role == ArchitectRoofLayerRole.covering) {
          coveringThickPerp = layer.thickness;
        }
        if (layer.role == ArchitectRoofLayerRole.battens) {
          battenTopPerp = cumulativePerp;
        }
        if (layer.role == ArchitectRoofLayerRole.rafters ||
            layer.isBetweenRafters) {
          rafterTopPerp ??= cumulativePerp;
          rafterBotPerp = cumulativePerp + layer.thickness;
        }

        final isDiscreteBattenGap =
            layer.role == ArchitectRoofLayerRole.battens &&
            timber.hasBattens &&
            slopeDirDotSection > 0.35;

        if (!isDiscreteBattenGap) {
          final poly = <Offset>[
            Offset(s0, zTop0 - dTopV),
            Offset(s1, zTop1 - dTopV),
            Offset(s1, zTop1 - dBotV),
            Offset(s0, zTop0 - dBotV),
          ];
          layerMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.layer,
              role: layer.role,
              material: layer.material,
              polygon: poly,
              path: Path()..addPolygon(poly, true),
            ),
          );
        }

        cumulativePerp += layer.thickness;
      }

      // 3. Discrete Battens (Летви) along the slope
      if (timber.hasBattens && slopeDirDotSection > 0.35) {
        final bTopV = (battenTopPerp ?? 0.04) / cosSlope;
        final bHeightV = timber.battenHeight / cosSlope;
        final stepS =
            (timber.battenSpacing / math.max(0.25, slopeDirDotSection)).clamp(
              0.18,
              0.80,
            );
        final halfW = (timber.battenWidth * 0.5) * cosApparent;

        final startFromS0 = zTop0 <= zTop1;
        final count = ((s1 - s0 - 0.08) / stepS).floor();
        for (var k = 0; k <= count; k++) {
          final sCenter = startFromS0
              ? (s0 + 0.06 + k * stepS)
              : (s1 - 0.06 - k * stepS);
          if (sCenter - halfW < s0 + 0.01 || sCenter + halfW > s1 - 0.01) {
            continue;
          }
          final sa = sCenter - halfW;
          final sb = sCenter + halfW;
          final zaTop = zTop0 + dzDs * (sa - s0) - bTopV;
          final zbTop = zTop0 + dzDs * (sb - s0) - bTopV;
          final battenPoly = <Offset>[
            Offset(sa, zaTop),
            Offset(sb, zbTop),
            Offset(sb, zbTop - bHeightV),
            Offset(sa, zaTop - bHeightV),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.batten,
              role: ArchitectRoofLayerRole.battens,
              material: ArchitectRoofMaterial.timberBoarding,
              polygon: battenPoly,
              path: Path()..addPolygon(battenPoly, true),
              drawTimberDiagonals: true,
            ),
          );
        }
      }

      // 4. Discrete Rafters & Counter-Battens when cutting across the slope (parallel to eaves)
      if (timber.hasRafters && slopeDirDotSection <= 0.35) {
        final rTopV =
            (rafterTopPerp ?? roof.assembly.thicknessAboveRafters) / cosSlope;
        final rHeightV = timber.rafterHeight / cosSlope;
        final stepS = timber.rafterSpacing.clamp(0.35, 1.20);
        final halfW = timber.rafterWidth * 0.5;
        final count = ((s1 - s0 - 0.10) / stepS).floor();
        for (var k = 0; k <= count; k++) {
          final sCenter = s0 + 0.08 + k * stepS;
          if (sCenter + halfW > s1 - 0.01) break;
          final sa = sCenter - halfW;
          final sb = sCenter + halfW;
          final zaTop = zTop0 + dzDs * (sa - s0) - rTopV;
          final zbTop = zTop0 + dzDs * (sb - s0) - rTopV;
          final rafterPoly = <Offset>[
            Offset(sa, zaTop),
            Offset(sb, zbTop),
            Offset(sb, zbTop - rHeightV),
            Offset(sa, zaTop - rHeightV),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.rafter,
              role: ArchitectRoofLayerRole.rafters,
              material: ArchitectRoofMaterial.timberBoarding,
              polygon: rafterPoly,
              path: Path()..addPolygon(rafterPoly, true),
              drawTimberDiagonals: true,
            ),
          );
        }
      }

      // 5. Mauerlat / Wall Plate (Мауерлат) & 10 cm Concrete Ring Beam (Стоманобетонен пояс)
      // at intersected supporting walls (or at the nominal eaves bearing line if no walls are present).
      if ((timber.hasWallPlate || timber.hasRingBeam) &&
          slopeDirDotSection > 0.25) {
        final sliceWallSpans = <({double fromS, double toS})>[];
        for (final wSpan in wallIntervals) {
          final wCenter = (wSpan.fromS + wSpan.toS) * 0.5;
          if (wCenter > s0 + 0.04 && wCenter < s1 - 0.04) {
            sliceWallSpans.add(wSpan);
          }
        }
        if (sliceWallSpans.isEmpty) {
          final bearingLine = wallBearingLine(roof);
          double? sWallPlate;
          if (bearingLine != null) {
            final hit = _intersectSegments(
              sectionLine.start,
              sectionLine.end,
              bearingLine.$1,
              bearingLine.$2,
            );
            if (hit != null) {
              sWallPlate =
                  (hit - sectionLine.start).dx * lineDir.dx +
                  (hit - sectionLine.start).dy * lineDir.dy;
            }
          }
          if (sWallPlate == null && roof.eavesOverhang > 0.05) {
            final overhangS =
                roof.eavesOverhang / math.max(0.3, slopeDirDotSection);
            sWallPlate = zTop0 <= zTop1 ? (s0 + overhangS) : (s1 - overhangS);
          }
          if (sWallPlate != null &&
              sWallPlate > s0 + 0.05 &&
              sWallPlate < s1 - 0.05) {
            final nominalHalfW = math.max(0.125, timber.wallPlateWidth * 0.5);
            sliceWallSpans.add((
              fromS: sWallPlate - nominalHalfW,
              toS: sWallPlate + nominalHalfW,
            ));
          }
        }

        final dRafterBotV =
            (rafterBotPerp ?? roof.assembly.totalThickness) / cosSlope;

        for (final wSpan in sliceWallSpans) {
          final sWallCenter = (wSpan.fromS + wSpan.toS) * 0.5;
          final wallW = (wSpan.toS - wSpan.fromS).clamp(0.12, 0.85);
          // Rafter underside elevation at the supporting wall centerline
          final zRafterBotWall =
              zTop0 + dzDs * (sWallCenter - s0) - dRafterBotV;
          var zCurrentBot = zRafterBotWall;

          if (timber.hasWallPlate) {
            final halfWp = math.min(timber.wallPlateWidth, wallW) * 0.5;
            final sa = sWallCenter - halfWp;
            final sb = sWallCenter + halfWp;
            final zWpTop = zCurrentBot;
            final zWpBot = zWpTop - timber.wallPlateHeight;
            final wpPoly = <Offset>[
              Offset(sa, zWpTop),
              Offset(sb, zWpTop),
              Offset(sb, zWpBot),
              Offset(sa, zWpBot),
            ];
            discreteMembers.add(
              ArchitectRoofSectionMember(
                roofId: roof.id,
                kind: ArchitectRoofMemberKind.wallPlate,
                material: ArchitectRoofMaterial.timberBoarding,
                polygon: wpPoly,
                path: Path()..addPolygon(wpPoly, true),
                drawTimberDiagonals: true,
              ),
            );
            zCurrentBot = zWpBot;
          }

          if (timber.hasRingBeam && timber.ringBeamHeight > 0.01) {
            final zRbTop = zCurrentBot;
            final zRbBot = zRbTop - timber.ringBeamHeight;
            final rbPoly = <Offset>[
              Offset(wSpan.fromS, zRbTop),
              Offset(wSpan.toS, zRbTop),
              Offset(wSpan.toS, zRbBot),
              Offset(wSpan.fromS, zRbBot),
            ];
            discreteMembers.add(
              ArchitectRoofSectionMember(
                roofId: roof.id,
                kind: ArchitectRoofMemberKind.ringBeam,
                role: ArchitectRoofLayerRole.structure,
                material: ArchitectRoofMaterial.rcSlab,
                polygon: rbPoly,
                path: Path()..addPolygon(rbPoly, true),
              ),
            );
            zCurrentBot = zRbBot;
          }

          wallCapIntervals.add((
            fromS: wSpan.fromS - 0.005,
            toS: wSpan.toS + 0.005,
            maxWallZ: zCurrentBot,
          ));
        }
      }

      // 6. Ridge Purlin (Билова столица) at the high end (only once per shared ridge)
      if (timber.hasRidgePurlin && slopeDirDotSection > 0.25) {
        final highAtEnd = zTop1 >= zTop0;
        final sRidge = highAtEnd ? s1 : s0;
        final dRafterBotV =
            (rafterBotPerp ?? roof.assembly.totalThickness) / cosSlope;
        final zRidgeBot = (highAtEnd ? zTop1 : zTop0) - dRafterBotV;
        final isPrimaryAtSharedRidge = highAtEnd ? true : !sharesStart;
        if (isPrimaryAtSharedRidge && roof.slopeDegrees >= 5.0) {
          final halfRp = timber.ridgePurlinWidth * 0.5;
          final sa = sRidge - halfRp;
          final sb = sRidge + halfRp;
          final rpPoly = <Offset>[
            Offset(sa, zRidgeBot),
            Offset(sb, zRidgeBot),
            Offset(sb, zRidgeBot - timber.ridgePurlinHeight),
            Offset(sa, zRidgeBot - timber.ridgePurlinHeight),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.ridgePurlin,
              material: ArchitectRoofMaterial.timberBoarding,
              polygon: rpPoly,
              path: Path()..addPolygon(rpPoly, true),
              drawTimberDiagonals: true,
            ),
          );
        }
      }

      // 7. Fascia Board (Челна дъска) & Metal Flashing / Drip Edge (Метална обшивка / капелник) at the free lower eaves end
      final lowAtStart = zTop0 <= zTop1;
      final hasFreeLowStart = lowAtStart && !sharesStart;
      final hasFreeLowEnd = !lowAtStart && !sharesEnd;

      if (timber.hasFasciaBoard && (hasFreeLowStart || hasFreeLowEnd)) {
        final fw = timber.fasciaThickness;
        final fasciaPoly = hasFreeLowStart
            ? <Offset>[
                Offset(s0 - fw, zTop0),
                Offset(s0, zTop0),
                Offset(s0, zBot0),
                Offset(s0 - fw, zBot0),
              ]
            : <Offset>[
                Offset(s1, zTop1),
                Offset(s1 + fw, zTop1),
                Offset(s1 + fw, zBot1),
                Offset(s1, zBot1),
              ];
        discreteMembers.add(
          ArchitectRoofSectionMember(
            roofId: roof.id,
            kind: ArchitectRoofMemberKind.fascia,
            material: ArchitectRoofMaterial.timberBoarding,
            polygon: fasciaPoly,
            path: Path()..addPolygon(fasciaPoly, true),
            drawTimberDiagonals: true,
          ),
        );
      }

      if (timber.hasMetalFlashing &&
          roof.slopeDegrees >= 3.0 &&
          (hasFreeLowStart || hasFreeLowEnd)) {
        final fw = timber.hasFasciaBoard ? timber.fasciaThickness : 0.0;
        final covV = coveringThickPerp / cosSlope;
        final tFlash = 0.008; // Sheet metal thickness in section representation
        final apronLen = math.min(0.12, (s1 - s0) * 0.25);
        final dropLen = math.min(0.065, totalVerticalThick * 0.45);
        final dripLip = 0.014;

        if (hasFreeLowStart) {
          final sOuter = s0 - fw;
          final zApronStart = zTop0 - covV;
          final zApronEnd = zTop0 + dzDs * apronLen - covV;
          final flashPoly = <Offset>[
            Offset(s0 + apronLen, zApronEnd + tFlash),
            Offset(sOuter - tFlash, zApronStart + tFlash),
            Offset(sOuter - tFlash, zApronStart - dropLen),
            Offset(sOuter - tFlash - dripLip, zApronStart - dropLen - dripLip),
            Offset(sOuter - dripLip, zApronStart - dropLen - dripLip),
            Offset(sOuter, zApronStart - dropLen),
            Offset(sOuter, zApronStart),
            Offset(s0 + apronLen, zApronEnd),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.metalFlashing,
              material: ArchitectRoofMaterial.metalSeam,
              polygon: flashPoly,
              path: Path()..addPolygon(flashPoly, true),
            ),
          );
        } else if (hasFreeLowEnd) {
          final sOuter = s1 + fw;
          final zApronStart = zTop1 - covV;
          final zApronEnd = zTop1 - dzDs * apronLen - covV;
          final flashPoly = <Offset>[
            Offset(s1 - apronLen, zApronEnd + tFlash),
            Offset(sOuter + tFlash, zApronStart + tFlash),
            Offset(sOuter + tFlash, zApronStart - dropLen),
            Offset(sOuter + tFlash + dripLip, zApronStart - dropLen - dripLip),
            Offset(sOuter + dripLip, zApronStart - dropLen - dripLip),
            Offset(sOuter, zApronStart - dropLen),
            Offset(sOuter, zApronStart),
            Offset(s1 - apronLen, zApronEnd),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.metalFlashing,
              material: ArchitectRoofMaterial.metalSeam,
              polygon: flashPoly,
              path: Path()..addPolygon(flashPoly, true),
            ),
          );
        }
      }

      draftSlices.add((
        roofId: roof.id,
        fromS: s0,
        toS: s1,
        zTop0: zTop0,
        zTop1: zTop1,
        totalVerticalThick: totalVerticalThick,
        layerMembers: layerMembers,
        discreteMembers: discreteMembers,
        wallCapIntervals: wallCapIntervals,
      ));
    }

    // 8. Collect all discrete structural cutouts across ALL slices on this storey
    // so shared ridge purlins, Mauerlat, ring beams, rafters, fascia, and flashing
    // cleanly boolean-subtract from every overlapping continuous roof layer!
    final allDiscreteCutouts = <Path>[];
    for (final draft in draftSlices) {
      for (final dm in draft.discreteMembers) {
        if (dm.kind == ArchitectRoofMemberKind.rafter ||
            dm.kind == ArchitectRoofMemberKind.wallPlate ||
            dm.kind == ArchitectRoofMemberKind.ringBeam ||
            dm.kind == ArchitectRoofMemberKind.ridgePurlin ||
            dm.kind == ArchitectRoofMemberKind.fascia ||
            dm.kind == ArchitectRoofMemberKind.metalFlashing) {
          allDiscreteCutouts.add(dm.path);
        }
      }
    }

    final result = <ArchitectRoofSectionSlice>[];
    for (final draft in draftSlices) {
      final cleanedLayers = <ArchitectRoofSectionMember>[];
      for (final layerMember in draft.layerMembers) {
        var cleanedPath = layerMember.path;
        for (final cutout in allDiscreteCutouts) {
          try {
            cleanedPath = Path.combine(
              PathOperation.difference,
              cleanedPath,
              cutout,
            );
          } catch (_) {}
        }
        cleanedLayers.add(
          ArchitectRoofSectionMember(
            roofId: layerMember.roofId,
            kind: layerMember.kind,
            role: layerMember.role,
            material: layerMember.material,
            polygon: layerMember.polygon,
            path: cleanedPath,
          ),
        );
      }

      final members = [...cleanedLayers, ...draft.discreteMembers];

      var envelope = Path()
        ..addPolygon([
          Offset(draft.fromS, draft.zTop0),
          Offset(draft.toS, draft.zTop1),
          Offset(draft.toS, draft.zTop1 - draft.totalVerticalThick),
          Offset(draft.fromS, draft.zTop0 - draft.totalVerticalThick),
        ], true);
      for (final m in draft.discreteMembers) {
        if (m.kind == ArchitectRoofMemberKind.wallPlate ||
            m.kind == ArchitectRoofMemberKind.ringBeam ||
            m.kind == ArchitectRoofMemberKind.ridgePurlin ||
            m.kind == ArchitectRoofMemberKind.fascia ||
            m.kind == ArchitectRoofMemberKind.metalFlashing) {
          try {
            envelope = Path.combine(PathOperation.union, envelope, m.path);
          } catch (_) {}
        }
      }
      // Also union the vertical cap zone above each supporting wall's 10 cm ring beam
      // so zero masonry wall slivers protrude beside the Mauerlat!
      for (final cap in draft.wallCapIntervals) {
        final capRect = Path()
          ..addRect(
            Rect.fromLTRB(
              cap.fromS,
              cap.maxWallZ,
              cap.toS,
              math.max(draft.zTop0, draft.zTop1) + 0.5,
            ),
          );
        try {
          envelope = Path.combine(PathOperation.union, envelope, capRect);
        } catch (_) {}
      }

      result.add(
        ArchitectRoofSectionSlice(
          roofId: draft.roofId,
          fromS: draft.fromS,
          toS: draft.toS,
          members: members,
          bottomProfile: [
            Offset(draft.fromS, draft.zTop0 - draft.totalVerticalThick),
            Offset(draft.toS, draft.zTop1 - draft.totalVerticalThick),
          ],
          envelopePath: envelope,
          wallCapIntervals: draft.wallCapIntervals,
        ),
      );
    }

    return result;
  }

  /// Evaluates the roof underside elevation (world Z in metres) at [worldPt] on [storey].
  /// Returns `null` if no roof plane covers [worldPt].
  static double? roofUndersideZAt(ArchitectStorey storey, Offset worldPt) {
    double? bestZ;
    for (final roof in storey.roofs) {
      if (roof.containsPoint(worldPt)) {
        final z = storey.elevation + roof.undersideElevationAt(worldPt);
        if (bestZ == null || z < bestZ) {
          bestZ = z;
        }
      }
    }
    return bestZ;
  }

  /// Evaluates the roof top elevation (world Z in metres) at [worldPt] on [storey].
  static double? roofTopZAt(ArchitectStorey storey, Offset worldPt) {
    double? bestZ;
    for (final roof in storey.roofs) {
      if (roof.containsPoint(worldPt)) {
        final z = storey.elevation + roof.topElevationAt(worldPt);
        if (bestZ == null || z > bestZ) {
          bestZ = z;
        }
      }
    }
    return bestZ;
  }

  static Offset? _intersectSegments(
    Offset a1,
    Offset a2,
    Offset b1,
    Offset b2,
  ) {
    final r = a2 - a1;
    final s = b2 - b1;
    final rxs = r.dx * s.dy - r.dy * s.dx;
    if (rxs.abs() < 1e-8) return null;
    final qp = b1 - a1;
    final t = (qp.dx * s.dy - qp.dy * s.dx) / rxs;
    final u = (qp.dx * r.dy - qp.dy * r.dx) / rxs;
    if (t < -1e-5 || t > 1.0 + 1e-5 || u < -1e-5 || u > 1.0 + 1e-5) {
      return null;
    }
    return a1 + r * t.clamp(0.0, 1.0);
  }
}
