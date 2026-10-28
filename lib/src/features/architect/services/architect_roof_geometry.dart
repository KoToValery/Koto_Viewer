// === SECTION: TABLE OF CONTENTS ===
// 1. Data Structures (ArchitectRoofEdgeKind, ArchitectRoofSectionMember, ArchitectRoofSectionSlice)
// 2. Auto-Roof Generator (Gable / Hip / Shed / Flat from building walls or slabs)
// 3. Plan Edge Classification & Wall Support Line
// 4. Section Cut Geometry (Mitered Layers, Discrete Battens, Rafters, Mauerlat, Ridge Purlin)
// 5. Wall-to-Roof Clipping & Height Adaptation
// 6. Roof Drafting Snap Guides (Hip/Valley Intersections & Inner Corner Alignments)

import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_wall_network.dart';
import '../rendering/architect_panel_roof_geometry.dart';
import '../rendering/architect_mesh_section.dart';
import 'architect_element_id.dart';
import 'architect_polygon_geometry.dart';
import 'architect_roof_junctions.dart';
import 'architect_panel_supports.dart';

// === SECTION: DATA STRUCTURES ===

enum ArchitectRoofEdgeKind { eaves, ridge, hipOrValley, verge }

enum ArchitectRoofMemberKind {
  layer,
  tileProfile,
  batten,
  counterBatten,
  rafter,
  wallPlate,
  ringBeam,
  ridgePurlin,
  intermediatePurlin,
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
  static ArchitectStorey? supportingSteelStorey(ArchitectProject project,ArchitectStorey floor) {
    if(floor.columns.isNotEmpty)return floor;
    final candidates=project.storeys.where((f)=>f.elevation<=floor.elevation&&f.columns.isNotEmpty).toList()
      ..sort((a,b)=>b.elevation.compareTo(a.elevation));
    return candidates.firstOrNull;
  }
  /// Resolve by physical elevation, independent of plan/menu ordering. Empty
  /// intermediate levels must not hide the walls carrying a dedicated roof plan.
  static ArchitectStorey? supportingWallStorey(
    ArchitectProject project,
    ArchitectStorey roofStorey,
  ) {
    if (roofStorey.walls.any((w) => !w.isParapet)) return roofStorey;
    final candidates =
        project.storeys
            .where(
              (s) =>
                  s.id != roofStorey.id &&
                  !s.isRoof &&
                  s.elevation <= roofStorey.elevation + 1e-4 &&
                  s.walls.any((w) => !w.isParapet),
            )
            .toList()
          ..sort((a, b) => b.elevation.compareTo(a.elevation));
    return candidates.firstOrNull;
  }

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
    if(preset==ArchitectRoofPreset.sandwichPitched||preset==ArchitectRoofPreset.sandwichMembrane) {
      for(final column in supportingSteelStorey(project,storey)?.columns??[]) {
        hullPoints.addAll(ArchitectPanelSupports.corners(column));
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
        (type==AutoRoofType.flat && preset==ArchitectRoofPreset.sandwichPitched?ArchitectRoofPreset.sandwichMembrane:preset) ??
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
      slopeDegrees: assembly.panels!=null?math.max(slopeOverride??slopeDegrees,assembly.panels!.minimumSlope):slopeOverride ?? slopeDegrees,
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
            makePlane([
              Offset(left, bottom),
              Offset(left, top),
              rLeft,
            ], eavesEdge: 0),
            // Right hip triangle
            makePlane([
              Offset(right, top),
              Offset(right, bottom),
              rRight,
            ], eavesEdge: 0),
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
            makePlane([
              Offset(left, top),
              Offset(right, top),
              rTop,
            ], eavesEdge: 0),
            // Bottom hip triangle
            makePlane([
              Offset(right, bottom),
              Offset(left, bottom),
              rBottom,
            ], eavesEdge: 0),
          ];
        }
    }
  }

  /// Offsets closed polygon [polygon] outwards by [distance].
  static List<Offset> offsetPolygonOutwards(
    List<Offset> polygon,
    double distance,
  ) {
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
  /// using weighted straight skeleton bisector decomposition.
  /// Supports equal slopes (45° hips/valleys at 90° corners) or unequal per-edge slopes
  /// [perEdgeSlopeDegrees] for roofs over wings of differing spans or varied pitches.
  static List<ArchitectRoofPlane> decomposeMultiPitchPolygon({
    required List<Offset> eavesPolygon,
    required ArchitectStorey storey,
    required double slopeDegrees,
    required double baseElevationOffset,
    required double eavesOverhang,
    required ArchitectRoofAssembly assembly,
    String? roofGroupId,
    List<double>? perEdgeSlopeDegrees,
  }) {
    final cleaned = BimPolygonGeometry.clean(
      eavesPolygon,
      removeCollinear: true,
    );
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

      final slopeDegI =
          perEdgeSlopeDegrees != null && i < perEdgeSlopeDegrees.length
          ? perEdgeSlopeDegrees[i]
          : slopeDegrees;
      final tanI = math.tan(slopeDegI * math.pi / 180.0);

      // Inward unit normal for CCW polygon: (-dy, dx)
      final normI = Offset(-edgeDir.dy, edgeDir.dx) / edgeDir.distance;
      final vecI = normI * tanI;

      var facePoly = List<Offset>.from(poly);

      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final aJ = poly[j];
        final bJ = poly[(j + 1) % n];
        final edgeJDir = bJ - aJ;
        if (edgeJDir.distance < 0.05) continue;

        final slopeDegJ =
            perEdgeSlopeDegrees != null && j < perEdgeSlopeDegrees.length
            ? perEdgeSlopeDegrees[j]
            : slopeDegrees;
        final tanJ = math.tan(slopeDegJ * math.pi / 180.0);

        final normJ = Offset(-edgeJDir.dy, edgeJDir.dx) / edgeJDir.distance;
        final vecJ = normJ * tanJ;

        // In 3D space, height on face i is z_i(P) = (P - a) . vecI
        // Condition for point P belonging to face i: z_i(P) <= z_j(P)
        // (P - a) . vecI <= (P - aJ) . vecJ
        // P . (vecI - vecJ) <= a . vecI - aJ . vecJ
        final deltaVec = vecI - vecJ;
        if (deltaVec.distance < 1e-6) continue;

        final rhs =
            BimPolygonGeometry.dot(a, vecI) - BimPolygonGeometry.dot(aJ, vecJ);

        facePoly = _clipPolygonByHalfPlane(facePoly, deltaVec, rhs);
        if (facePoly.length < 3) break;
      }

      if (facePoly.length >= 3) {
        // Ensure edge i is at index 0 (safeEavesEdgeIndex)
        final orderedFace = _alignFaceToEaves(facePoly, a, b);
        if (orderedFace.length >= 3 &&
            BimPolygonGeometry.signedArea(orderedFace).abs() > 0.05) {
          planes.add(
            ArchitectRoofPlane(
              id: ArchitectElementId.next('roof'),
              storeyId: storey.id,
              points: orderedFace,
              eavesEdgeIndex: 0,
              slopeDegrees: slopeDegI,
              baseElevationOffset: baseElevationOffset,
              eavesOverhang: eavesOverhang,
              assembly: assembly.copyWith(),
              roofGroupId: groupId,
              isSlopeLocked: true,
            ),
          );
        }
      }
    }

    return planes;
  }

  /// Calculates the required roof slope in degrees for a roof plane with horizontal run [runDistance]
  /// to reach a target ridge height [targetRidgeHeight] above its eaves.
  static double calculateSlopeToMatchRidgeHeight({
    required double targetRidgeHeight,
    required double runDistance,
    double minSlope = 5.0,
    double maxSlope = 60.0,
  }) {
    if (runDistance <= 0.05 || targetRidgeHeight <= 0.01) {
      return 22.0;
    }
    final slopeRad = math.atan(targetRidgeHeight / runDistance);
    final slopeDeg = slopeRad * 180.0 / math.pi;
    return slopeDeg.clamp(minSlope, maxSlope);
  }

  /// Calculates the horizontal plan angle in degrees of the hip or valley bisector
  /// between two slopes with pitches [slopeDeg1] and [slopeDeg2] meeting at corner angle [cornerAngleRad].
  static double calculateHipAngle({
    required double slopeDeg1,
    required double slopeDeg2,
    double cornerAngleRad = math.pi / 2.0,
  }) {
    final s1 = math.tan(slopeDeg1 * math.pi / 180.0);
    final s2 = math.tan(slopeDeg2 * math.pi / 180.0);
    if ((cornerAngleRad - math.pi / 2.0).abs() < 1e-4) {
      return math.atan2(s1, s2) * 180.0 / math.pi;
    }
    final sinCorner = math.sin(cornerAngleRad);
    final cosCorner = math.cos(cornerAngleRad);
    final tanTheta = (s1 * sinCorner) / (s2 + s1 * cosCorner);
    return math.atan(tanTheta) * 180.0 / math.pi;
  }

  static List<Offset> _clipPolygonByHalfPlane(
    List<Offset> poly,
    Offset normal,
    double c,
  ) {
    if (poly.length < 3) return const [];
    final output = <Offset>[];

    bool isInside(Offset p) =>
        (p.dx * normal.dx + p.dy * normal.dy) <= c + 1e-6;

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
      return [...face.sublist(bestIdx), ...face.sublist(0, bestIdx)];
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
  /// the eaves edge by the manual support distance or nominal overhang,
  /// clipped to the roof polygon.
  static (Offset, Offset)? wallBearingLine(ArchitectRoofPlane roof) {
    final distance = roof.manualSupportDistance ?? roof.eavesOverhang;
    if (!distance.isFinite ||
        distance < 0 ||
        distance > roof.maxSlopeRun ||
        roof.points.length < 3) {
      return null;
    }
    if (roof.manualSupportDistance == null && distance <= 0.01) return null;
    final (ea, eb) = roof.eavesEdge;
    final inward = roof.inwardNormalOfEdge(roof.safeEavesEdgeIndex);
    final shift =
        inward * (roof.reverseSlope ? (roof.maxSlopeRun - distance) : distance);
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
    ArchitectProject? project,
    required ArchitectRoofPlane roof,
    required ArchitectStorey storey,
    ArchitectStorey? lowerStorey,
  }) {
    if (!roof.attachToWalls) return roof.baseElevationOffset;
    if(roof.assembly.panels!=null) {
      final selected=roof.assembly.panels!.columnIds;
      if(project!=null&&selected.isNotEmpty) {
        final heights=[for(final f in project.storeys)for(final c in f.columns)
          if(selected.contains(c.id))f.elevation-storey.elevation+c.baseOffset+(c.height??f.height)-
            (roof.signedDistanceFromEaves(c.position)-roof.eavesOverhang)*math.tan(roof.slopeRadians)];
        return heights.length==selected.length?heights.reduce(math.max):roof.baseElevationOffset;
      }
      final source=storey.columns.isNotEmpty?storey:lowerStorey;
      if(source==null&&roof.assembly.panels!.columnIds.isNotEmpty)return roof.baseElevationOffset;
      if(source!=null) {
        final ids=roof.assembly.panels!.columnIds;
        final columns=source.columns.where((c)=>ids.isEmpty||ids.contains(c.id)).toList();
        if(ids.isNotEmpty && columns.length!=ids.length)return roof.baseElevationOffset;
        if(columns.isNotEmpty) {
          columns.sort((a,b)=>(roof.signedDistanceFromEaves(a.position)-roof.eavesOverhang).abs()
            .compareTo((roof.signedDistanceFromEaves(b.position)-roof.eavesOverhang).abs()));
          return columns.map((c)=>source.elevation-storey.elevation+c.baseOffset+(c.height??source.height)-
            (roof.signedDistanceFromEaves(c.position)-roof.eavesOverhang)*math.tan(roof.slopeRadians)).reduce(math.max);
        }
      }
    }
    final bearingDepth =
        roof.assembly.preset == ArchitectRoofPreset.logTimber &&
            roof.assembly.timber.hasWallPlate
        ? roof.assembly.timber.wallPlateHeight
        : 0.0;
    final candidateWalls = storey.walls.where((w) => !w.isParapet).toList();
    if (candidateWalls.isNotEmpty) {
      var maxH = 0.0;
      for (final w in candidateWalls) {
        final h = w.baseOffset + w.effectiveHeight(storey.height);
        if (h > maxH) maxH = h;
      }
      if (maxH > 0.0) return maxH + bearingDepth;
    }
    if (storey.walls.isEmpty && lowerStorey != null) {
      final lowerWalls = lowerStorey.walls.where((w) => !w.isParapet).toList();
      if (lowerWalls.isNotEmpty) {
        var maxTopZ = double.negativeInfinity;
        for (final w in lowerWalls) {
          final topZ =
              lowerStorey.elevation +
              w.baseOffset +
              w.effectiveHeight(lowerStorey.height);
          if (topZ > maxTopZ) maxTopZ = topZ;
        }
        return maxTopZ - storey.elevation + bearingDepth;
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
    ArchitectProject? project,
  }) {
    if (storey.roofs.isEmpty) return const [];
    final lineVec = sectionLine.end - sectionLine.start;
    final lineLen = lineVec.distance;
    if (lineLen < 1e-6) return const [];
    final lineDir = lineVec / lineLen;
    final panelSlices=<ArchitectRoofSectionSlice>[];
    for(final roof in storey.roofs.where((r)=>r.assembly.panels!=null)) {
      final members=<ArchitectRoofSectionMember>[];
      var envelope=Path();Rect? bounds;
      for(final component in ArchitectPanelRoofGeometry.build(storey,roof,project:project)) {
        var path=component.section(sectionLine.start,lineDir);
        path=ArchitectMeshSection.combine(PathOperation.intersect,path,Path()..addRect(Rect.fromLTRB(0,-1e6,lineLen,1e6)));
        if(path.getBounds().isEmpty)continue;
        bounds=bounds?.expandToInclude(path.getBounds())??path.getBounds();
        envelope=ArchitectMeshSection.combine(PathOperation.union,envelope,path);
        members.add(ArchitectRoofSectionMember(roofId:roof.id,kind:component.structural?
          ArchitectRoofMemberKind.rafter:ArchitectRoofMemberKind.layer,material:component.material,
          path:path,polygon:const []));
      }
      if(bounds!=null) {
        panelSlices.add(ArchitectRoofSectionSlice(roofId:roof.id,fromS:bounds.left,toS:bounds.right,
        members:members,envelopePath:envelope,bottomProfile:[for(final x in [bounds.left,bounds.right])
          Offset(x,storey.elevation+ArchitectPanelRoofGeometry.panelUnderside(roof,sectionLine.start+lineDir*x))]));
      }
    }

    // 0. Intersect supporting walls with sectionLine to find transverse wall intervals [wMin, wMax]
    final supportingWalls = storey.walls.any((w) => !w.isParapet)
        ? storey.walls.where((w) => !w.isParapet).toList()
        : (lowerStorey?.walls ?? const []);
    final wallIntervals = <({double fromS, double toS, double plateScale})>[];
    for (final wall in supportingWalls) {
      if (wall.isParapet) continue;
      // Concrete and timber bear on the masonry/concrete core, never on the
      // centre of the complete envelope (which may include thick insulation).
      final corners = wall.coreCorners;
      if (corners.length < 3) continue;
      final transverse =
          (wall.normalVector.dx * lineDir.dx +
                  wall.normalVector.dy * lineDir.dy)
              .abs();
      if (!wall.isCurved && transverse < 0.15) continue;
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
        if (wSpan >= 0.01 &&
            (wall.isCurved ||
                wSpan <= wall.coreThickness / transverse + 0.01)) {
          wallIntervals.add((
            fromS: wMin,
            toS: wMax,
            plateScale: wall.isCurved ? 1.0 : 1.0 / transverse,
          ));
        }
      }
    }

    // 1. Collect raw 1D intervals [fromS, toS] for each roof plane crossed by the section line.
    final rawIntervals =
        <({ArchitectRoofPlane roof, double fromS, double toS})>[];
    final roofJunctions = ArchitectRoofJunctions.of(storey, project: project);
    for (final roof in storey.roofs) {
      if(roof.assembly.panels!=null)continue;
      if (roof.points.length < 3) continue;
      final footprint = roofJunctions.footprint(roof);
      final hits = <double>[];
      for (final contour in ArchitectPathSolid.contours(footprint)) {
        for (var i = 0; i < contour.length; i++) {
          final a = contour[i];
          final b = contour[(i + 1) % contour.length];
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
      }
      if (footprint.contains(sectionLine.start) &&
          hits.every((h) => h.abs() > 1e-4)) {
        hits.add(0.0);
      }
      if (footprint.contains(sectionLine.end) &&
          hits.every((h) => (h - lineLen).abs() > 1e-4)) {
        hits.add(lineLen);
      }
      hits.sort();
      for (var i = 0; i + 1 < hits.length; i++) {
        final s0 = hits[i];
        final s1 = hits[i + 1];
        if (s1 - s0 < 0.02) continue;
        final midWorld = sectionLine.start + lineDir * ((s0 + s1) * 0.5);
        if (footprint.contains(midWorld)) {
          if (roof.isMansard) {
            final p0 = sectionLine.start + lineDir * s0;
            final p1 = sectionLine.start + lineDir * s1;
            final d0 = roof.signedDistanceFromEaves(p0);
            final d1 = roof.signedDistanceFromEaves(p1);
            final k = roof.effectiveBreakDistance;
            final denom = d1 - d0;
            if (denom.abs() > 1e-4) {
              final t = (k - d0) / denom;
              if (t > 0.03 && t < 0.97) {
                final sK = s0 + t * (s1 - s0);
                rawIntervals.add((roof: roof, fromS: s0, toS: sK));
                rawIntervals.add((roof: roof, fromS: sK, toS: s1));
                continue;
              }
            }
          }
          rawIntervals.add((roof: roof, fromS: s0, toS: s1));
        }
      }
    }

    if (rawIntervals.isEmpty) return panelSlices;
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
            List<({double fromS, double toS, double maxWallZ})>
            wallCapIntervals,
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
      final wallCapIntervals =
          <({double fromS, double toS, double maxWallZ})>[];
      final timber = roof.assembly.timber;

      // Apparent slope along the section line:
      final dzDs = (zTop1 - zTop0) / (s1 - s0);
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
          rafterBotPerp = cumulativePerp + roof.assembly.layerDepth(layer);
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

        cumulativePerp += roof.assembly.layerDepth(layer);
      }

      // 3. Discrete Battens (Летви) along the slope (true orthogonal rectangular profiles)
      if (timber.hasBattens && slopeDirDotSection > 0.35) {
        final hypot = math.sqrt(1.0 + dzDs * dzDs);
        final uSlope = Offset(1.0 / hypot, dzDs / hypot);
        final vNormIn = Offset(dzDs / hypot, -1.0 / hypot);

        final isEavesAtS0 = zTop0 <= zTop1;
        final uUpslope = isEavesAtS0 ? uSlope : -uSlope;
        final pEaves = isEavesAtS0 ? Offset(s0, zTop0) : Offset(s1, zTop1);
        final slopeLen = (s1 - s0) * hypot;

        final stepDist =
            (timber.battenSpacing / math.max(0.25, slopeDirDotSection)).clamp(
              0.18,
              0.80,
            );
        final dTopPerp = battenTopPerp ?? 0.04;
        final halfW = timber.battenWidth * 0.5;
        final bHeight = timber.battenHeight;

        final startDist = halfW + 0.03;
        final availableLen = slopeLen - startDist - halfW - 0.03;
        final count = availableLen > 0 ? (availableLen / stepDist).floor() : 0;

        for (var k = 0; k <= count; k++) {
          final distAlongSlope = startDist + k * stepDist;
          final pCenterTop = pEaves + uUpslope * distAlongSlope;
          final cTop = pCenterTop + vNormIn * dTopPerp;

          // True orthogonal rectangle oriented with the roof slope:
          // p1 -> p2 is along the slope (width = timber.battenWidth)
          // p2 -> p3 is perpendicular to the slope (height = timber.battenHeight)
          final p1 = cTop - uUpslope * halfW;
          final p2 = cTop + uUpslope * halfW;
          final p3 = p2 + vNormIn * bHeight;
          final p4 = p1 + vNormIn * bHeight;

          final minS = math.min(math.min(p1.dx, p2.dx), math.min(p3.dx, p4.dx));
          final maxS = math.max(math.max(p1.dx, p2.dx), math.max(p3.dx, p4.dx));
          if (minS < s0 - 0.02 || maxS > s1 + 0.02) {
            continue;
          }

          final battenPoly = <Offset>[p1, p2, p3, p4];
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
        final hypot = math.sqrt(1.0 + dzDs * dzDs);
        final uSlope = Offset(1.0 / hypot, dzDs / hypot);
        final vNormIn = Offset(dzDs / hypot, -1.0 / hypot);

        final rTopPerpDist =
            rafterTopPerp ?? roof.assembly.thicknessAboveRafters;
        final rHeight = timber.rafterHeight;
        final halfW = timber.rafterWidth * 0.5;
        final stepDist = timber.rafterSpacing.clamp(0.35, 1.20);
        final spanLen = (s1 - s0) * hypot;
        final availableLen = spanLen - 0.16;
        final count = availableLen > 0 ? (availableLen / stepDist).floor() : 0;

        for (var k = 0; k <= count; k++) {
          final distAlongSlope = 0.08 + halfW + k * stepDist;
          if (distAlongSlope + halfW > spanLen - 0.02) break;

          final pCenterTop = Offset(s0, zTop0) + uSlope * distAlongSlope;
          final cTop = pCenterTop + vNormIn * rTopPerpDist;

          final p1 = cTop - uSlope * halfW;
          final p2 = cTop + uSlope * halfW;
          final p3 = p2 + vNormIn * rHeight;
          final p4 = p1 + vNormIn * rHeight;

          final minS = math.min(math.min(p1.dx, p2.dx), math.min(p3.dx, p4.dx));
          final maxS = math.max(math.max(p1.dx, p2.dx), math.max(p3.dx, p4.dx));
          if (minS < s0 - 0.02 || maxS > s1 + 0.02) continue;

          final rafterPoly = <Offset>[p1, p2, p3, p4];
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
        final sliceWallSpans =
            <({double fromS, double toS, double plateScale})>[];
        if (roof.manualSupportDistance == null) {
          for (final wSpan in wallIntervals) {
            final wCenter = (wSpan.fromS + wSpan.toS) * 0.5;
            if (wCenter >= s0 - 1e-4 && wCenter <= s1 + 1e-4) {
              sliceWallSpans.add(wSpan);
            }
          }
        }
        if (roof.manualSupportDistance != null ||
            (sliceWallSpans.isEmpty && supportingWalls.isEmpty)) {
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
          if (roof.manualSupportDistance == null &&
              sWallPlate == null &&
              roof.eavesOverhang > 0.05) {
            final overhangS =
                roof.eavesOverhang / math.max(0.3, slopeDirDotSection);
            sWallPlate = zTop0 <= zTop1 ? (s0 + overhangS) : (s1 - overhangS);
          }
          if (sWallPlate != null &&
              sWallPlate >= s0 - 1e-4 &&
              sWallPlate <= s1 + 1e-4) {
            final plateScale = 1.0 / slopeDirDotSection;
            var nominalWidth =
                math.max(0.25, timber.wallPlateWidth) * plateScale;
            if (roof.manualSupportDistance != null &&
                wallIntervals.isNotEmpty) {
              final station = sWallPlate;
              final nearest = [...wallIntervals]
                ..sort(
                  (a, b) => (((a.fromS + a.toS) * .5) - station)
                      .abs()
                      .compareTo((((b.fromS + b.toS) * .5) - station).abs()),
                );
              nominalWidth = nearest.first.toS - nearest.first.fromS;
            }
            final nominalHalfW = nominalWidth * .5;
            sliceWallSpans.add((
              fromS: sWallPlate - nominalHalfW,
              toS: sWallPlate + nominalHalfW,
              plateScale: plateScale,
            ));
          }
        }

        final dRafterBotV =
            (rafterBotPerp ?? roof.assembly.totalThickness) / cosSlope;

        for (final wSpan in sliceWallSpans) {
          final sWallCenter = (wSpan.fromS + wSpan.toS) * 0.5;
          final wallW = wSpan.toS - wSpan.fromS;
          // Rafter underside elevation at the supporting wall centerline
          final zRafterBotWall =
              zTop0 + dzDs * (sWallCenter - s0) - dRafterBotV;
          var zCurrentBot = zRafterBotWall;

          if (timber.hasWallPlate) {
            final halfWp =
                math.min(timber.wallPlateWidth * wSpan.plateScale, wallW) * 0.5;
            final sa = sWallCenter - halfWp;
            final sb = sWallCenter + halfWp;
            // A horizontal seat cuts a shallow birdsmouth in the rafter;
            // choosing its higher underside avoids a gap above half the plate.
            final zWpTop = math.max(
              zTop0 + dzDs * (sa - s0) - dRafterBotV,
              zTop0 + dzDs * (sb - s0) - dRafterBotV,
            );
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

      // 6b. Mansard Intermediate Purlin (Междинна столица) at knuckle fold
      if (roof.isMansard && slopeDirDotSection > 0.25) {
        final d0 = roof.signedDistanceFromEaves(p0);
        final d1 = roof.signedDistanceFromEaves(p1);
        final k = roof.effectiveBreakDistance;
        final isKnuckleAtS0 = (d0 - k).abs() < 0.05;
        final isKnuckleAtS1 = (d1 - k).abs() < 0.05;
        if (isKnuckleAtS1 && d1 > d0) {
          final halfKp = 0.08;
          final sa = s1 - halfKp;
          final sb = s1 + halfKp;
          final zKpTop = zBot1;
          final zKpBot = zKpTop - 0.16;
          final kpPoly = <Offset>[
            Offset(sa, zKpTop),
            Offset(sb, zKpTop),
            Offset(sb, zKpBot),
            Offset(sa, zKpBot),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.intermediatePurlin,
              material: ArchitectRoofMaterial.timberBoarding,
              polygon: kpPoly,
              path: Path()..addPolygon(kpPoly, true),
              drawTimberDiagonals: true,
            ),
          );
        } else if (isKnuckleAtS0 && d0 > d1) {
          final halfKp = 0.08;
          final sa = s0 - halfKp;
          final sb = s0 + halfKp;
          final zKpTop = zBot0;
          final zKpBot = zKpTop - 0.16;
          final kpPoly = <Offset>[
            Offset(sa, zKpTop),
            Offset(sb, zKpTop),
            Offset(sb, zKpBot),
            Offset(sa, zKpBot),
          ];
          discreteMembers.add(
            ArchitectRoofSectionMember(
              roofId: roof.id,
              kind: ArchitectRoofMemberKind.intermediatePurlin,
              material: ArchitectRoofMaterial.timberBoarding,
              polygon: kpPoly,
              path: Path()..addPolygon(kpPoly, true),
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
        final tFlash = 0.001;
        final apronLen = math.min(0.12, (s1 - s0) * 0.25);
        final dropLen = math.min(
          roof.drainage.showGutter ? 0.005 : 0.065,
          totalVerticalThick * 0.45,
        );
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
            dm.kind == ArchitectRoofMemberKind.intermediatePurlin ||
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
            m.kind == ArchitectRoofMemberKind.intermediatePurlin ||
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

    return [...result,...panelSlices];
  }

  /// Evaluates the roof underside elevation (world Z in metres) at [worldPt] on [storey].
  /// Returns `null` if no roof plane covers [worldPt].
  static double? roofUndersideZAt(ArchitectStorey storey, Offset worldPt) {
    double? bestZ;
    final junctions = ArchitectRoofJunctions.of(storey);
    for (final roof in storey.roofs) {
      if (junctions.footprint(roof).contains(worldPt)) {
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
    final junctions = ArchitectRoofJunctions.of(storey);
    for (final roof in storey.roofs) {
      if (junctions.footprint(roof).contains(worldPt)) {
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

  // === SECTION: ROOF DRAFTING SNAP GUIDES ===

  /// Resolves intelligent drafting guide snapping for roof polygons and hip lines.
  ///
  /// Evaluates 45° and hip angle rays from [anchor] and projects [raw] onto the best matching ray.
  /// If the cursor is close to a key architectural intersection along the ray:
  /// - Hip apex (intersection with symmetrical hip ray from eaves start P0)
  /// - 45° valley/hip ray from wall corners (inner or exterior building corners)
  /// - Perpendicular from an inner wall corner to the eaves
  /// - Ridge line / parallel alignment passing through a wall corner
  /// it snaps directly to the intersection and emits dual magnetic guides meeting at that point.
  /// Otherwise, it tracks smoothly along the active ray.
  static RoofSnapGuideResult? resolveRoofGuideSnap({
    required Offset raw,
    required Offset anchor,
    required List<Offset> draftPoints,
    required ArchitectStorey activeStorey,
    required double currentSlopeDegrees,
    required double snapTolerance,
    required String Function() hip45Label,
    required String Function(String deg) hipAngleLabel,
    required String Function() hipIntersectionLabel,
    required String Function() cornerHipIntersectionLabel,
    required String Function() ridgeAlignmentLabel,
    required String Function() perpToCornerLabel,
  }) {
    final delta = raw - anchor;
    final dist = delta.distance;
    if (dist < 0.10) return null;

    // 1. Calculate base hip angle (45° or custom angle for unequal slopes with adjacent roof)
    double baseHip = 45.0;
    final nearRoof = activeStorey.roofs.where((r) {
      return r.points.any((p) => (p - anchor).distance < 0.5);
    }).firstOrNull;
    if (nearRoof != null &&
        (nearRoof.slopeDegrees - currentSlopeDegrees).abs() > 0.5) {
      baseHip = calculateHipAngle(
        slopeDeg1: currentSlopeDegrees,
        slopeDeg2: nearRoof.slopeDegrees,
      );
    }

    // 2. Identify eaves orientation if available
    double? eavesAngleRad;
    Offset? eavesUnit;
    Offset? p0;
    if (draftPoints.isNotEmpty) {
      p0 = draftPoints.first;
    }
    if (draftPoints.length >= 2) {
      final p1 = draftPoints[1];
      final eavesDelta = p1 - p0!;
      if (eavesDelta.distance > 0.05) {
        eavesAngleRad = math.atan2(eavesDelta.dy, eavesDelta.dx);
        eavesUnit = eavesDelta / eavesDelta.distance;
      }
    }

    // 3. Assemble candidate ray angles from anchor (in degrees, [0, 360))
    final angles = <double>{
      baseHip,
      (180.0 - baseHip) % 360.0,
      (180.0 + baseHip) % 360.0,
      (360.0 - baseHip) % 360.0,
      45.0,
      135.0,
      225.0,
      315.0,
      0.0,
      90.0,
      180.0,
      270.0,
    };

    if (eavesAngleRad != null) {
      final eavesDeg = (eavesAngleRad * 180.0 / math.pi) % 360.0;
      angles.add((eavesDeg + baseHip) % 360.0);
      angles.add((eavesDeg - baseHip + 360.0) % 360.0);
      angles.add((eavesDeg + 180.0 - baseHip + 360.0) % 360.0);
      angles.add((eavesDeg + 180.0 + baseHip) % 360.0);
      angles.add((eavesDeg + 90.0) % 360.0);
      angles.add((eavesDeg + 270.0) % 360.0);
      angles.add((eavesDeg + 360.0) % 360.0);
      angles.add((eavesDeg + 180.0) % 360.0);
    }

    // 4. Find the best matching ray from anchor
    double? bestPerpDist;
    double? bestProjT;
    Offset? bestDir;
    double? bestAngleDeg;
    Offset? bestProjPt;

    for (final angleDeg in angles) {
      final rad = angleDeg * math.pi / 180.0;
      final dir = Offset(math.cos(rad), math.sin(rad));
      final proj = delta.dx * dir.dx + delta.dy * dir.dy;
      if (proj <= 0.08) continue; // Behind anchor or too close

      final guidePt = anchor + dir * proj;
      final perpDist = (raw - guidePt).distance;
      if (perpDist <= snapTolerance) {
        if (bestPerpDist == null || perpDist < bestPerpDist) {
          bestPerpDist = perpDist;
          bestProjT = proj;
          bestDir = dir;
          bestAngleDeg = angleDeg;
          bestProjPt = guidePt;
        }
      }
    }

    if (bestProjPt == null ||
        bestDir == null ||
        bestProjT == null ||
        bestAngleDeg == null) {
      return null;
    }

    final activeDir = bestDir;
    final activeProjPt = bestProjPt;
    final activeProjT = bestProjT;
    final activeAngleDeg = bestAngleDeg;

    // 5. Collect candidate intersection points along the active ray
    final candidates = <_RoofGuideCandidate>[];

    // Helper to test intersection with a ray (origin, dir)
    void checkRayIntersection({
      required Offset origin,
      required Offset dir,
      required String label,
      required Offset sourcePt,
      required int priority,
      double maxDistFromSource = 45.0,
    }) {
      final cross = activeDir.dx * dir.dy - activeDir.dy * dir.dx;
      if (cross.abs() < 1e-4) return; // Parallel or anti-parallel

      final dOrigin = origin - anchor;
      final tAnchor = (dOrigin.dx * dir.dy - dOrigin.dy * dir.dx) / cross;
      final tSource =
          (dOrigin.dx * activeDir.dy - dOrigin.dy * activeDir.dx) / cross;

      if (tAnchor > 0.10 && tSource > 0.05 && tSource <= maxDistFromSource) {
        final interPt = anchor + activeDir * tAnchor;
        final distAlongRay = (interPt - activeProjPt).distance;
        candidates.add(
          _RoofGuideCandidate(
            point: interPt,
            label: label,
            guideLine: (sourcePt, interPt),
            distanceToCursor: distAlongRay,
            priority: priority,
          ),
        );
      }
    }

    // Helper to test intersection with an infinite line passing through [ptOnLine] with direction [lineDir]
    void checkLineIntersection({
      required Offset ptOnLine,
      required Offset lineDir,
      required String label,
      required Offset sourcePt,
      required int priority,
      double maxDistFromSource = 45.0,
    }) {
      final cross = activeDir.dx * lineDir.dy - activeDir.dy * lineDir.dx;
      if (cross.abs() < 1e-4) return;

      final dOrigin = ptOnLine - anchor;
      final tAnchor =
          (dOrigin.dx * lineDir.dy - dOrigin.dy * lineDir.dx) / cross;
      final tLine =
          (dOrigin.dx * activeDir.dy - dOrigin.dy * activeDir.dx) / cross;

      if (tAnchor > 0.10 && tLine.abs() <= maxDistFromSource) {
        final interPt = anchor + activeDir * tAnchor;
        final distAlongRay = (interPt - activeProjPt).distance;
        candidates.add(
          _RoofGuideCandidate(
            point: interPt,
            label: label,
            guideLine: (sourcePt, interPt),
            distanceToCursor: distAlongRay,
            priority: priority,
          ),
        );
      }
    }

    // Candidate Type A: Symmetrical hip from P0 (start of eaves / draft)
    if (p0 != null && (p0 - anchor).distance > 0.25) {
      final p0Angles = <double>{
        baseHip,
        (180.0 - baseHip) % 360.0,
        (180.0 + baseHip) % 360.0,
        (360.0 - baseHip) % 360.0,
        45.0,
        135.0,
        225.0,
        315.0,
      };
      if (eavesAngleRad != null) {
        final eavesDeg = (eavesAngleRad * 180.0 / math.pi) % 360.0;
        p0Angles.add((eavesDeg + baseHip) % 360.0);
        p0Angles.add((eavesDeg - baseHip + 360.0) % 360.0);
        p0Angles.add((eavesDeg + 180.0 - baseHip + 360.0) % 360.0);
        p0Angles.add((eavesDeg + 180.0 + baseHip) % 360.0);
      }
      for (final a in p0Angles) {
        final rad = a * math.pi / 180.0;
        final dir = Offset(math.cos(rad), math.sin(rad));
        checkRayIntersection(
          origin: p0,
          dir: dir,
          label: hipIntersectionLabel(),
          sourcePt: p0,
          priority: 10,
        );
      }
    }

    // Guides belong to supporting walls and the current eaves. Existing roof
    // vertices remain object snaps, never guide origins for another slope.
    final refCorners = <Offset>[];
    void addCorner(Offset pt) {
      if ((pt - anchor).distance < 0.15) return;
      if ((pt - raw).distance > 45.0) return;
      for (final existing in refCorners) {
        if ((existing - pt).distance < 0.04) return;
      }
      refCorners.add(pt);
    }

    final wallCorners = [for (final w in activeStorey.walls) ...[w.startPoint, w.endPoint]];
    double fromEaves(Offset p) => eavesUnit == null || p0 == null ? 0 :
        ((p - p0).dx * eavesUnit.dy - (p - p0).dy * eavesUnit.dx).abs();
    final nearestWall = wallCorners.isEmpty ? 0.0 : wallCorners.map(fromEaves).reduce(math.min);
    for (final corner in wallCorners) {
      // Corners on the far facade belong to the opposite slope. Account for
      // the overhang by measuring from the nearest supporting wall line.
      if (fromEaves(corner) <= nearestWall + math.max(.05, snapTolerance)) addCorner(corner);
    }
    for (final dp in draftPoints.take(2)) {
      addCorner(dp);
    }

    // Type B: 45° / Valley rays from corner C
    final cornerHipAngles = <double>[45.0, 135.0, 225.0, 315.0];
    if (eavesAngleRad != null) {
      final eavesDeg = (eavesAngleRad * 180.0 / math.pi) % 360.0;
      cornerHipAngles.add((eavesDeg + baseHip) % 360.0);
      cornerHipAngles.add((eavesDeg - baseHip + 360.0) % 360.0);
      cornerHipAngles.add((eavesDeg + 180.0 - baseHip + 360.0) % 360.0);
      cornerHipAngles.add((eavesDeg + 180.0 + baseHip) % 360.0);
    }
    for (final c in refCorners) {
      for (final a in cornerHipAngles) {
        final rad = a * math.pi / 180.0;
        final dir = Offset(math.cos(rad), math.sin(rad));
        checkRayIntersection(
          origin: c,
          dir: dir,
          label: cornerHipIntersectionLabel(),
          sourcePt: c,
          priority: 8,
        );
      }
    }

    // Type C: Ridge / parallel alignment through corner C
    if (eavesUnit != null) {
      for (final c in refCorners) {
        checkLineIntersection(
          ptOnLine: c,
          lineDir: eavesUnit,
          label: ridgeAlignmentLabel(),
          sourcePt: c,
          priority: 6,
        );
      }
    }

    // Type D: Perpendicular to eaves through corner C
    if (eavesUnit != null) {
      final eavesPerp = Offset(-eavesUnit.dy, eavesUnit.dx);
      for (final c in refCorners) {
        checkLineIntersection(
          ptOnLine: c,
          lineDir: eavesPerp,
          label: perpToCornerLabel(),
          sourcePt: c,
          priority: 7,
        );
      }
    }

    // 6. Select closest intersection candidate within snap tolerance
    final maxSnapDist = snapTolerance;
    final validCandidates = candidates
        .where((c) => c.distanceToCursor <= maxSnapDist)
        .toList();

    if (validCandidates.isNotEmpty) {
      // Deduplicate nearby candidates within 12cm, keeping the highest priority
      final clustered = <_RoofGuideCandidate>[];
      for (final c in validCandidates) {
        final existingIdx = clustered.indexWhere(
          (u) => (u.point - c.point).distance < 0.12,
        );
        if (existingIdx == -1) {
          clustered.add(c);
        } else if (c.priority > clustered[existingIdx].priority) {
          clustered[existingIdx] = c;
        }
      }

      // Sort clustered candidates:
      // If a candidate has priority >= 10 (Hip Apex) and is within maxSnapDist,
      // it takes precedence unless another candidate is more than 0.25m closer.
      clustered.sort((a, b) {
        if (a.priority >= 10 &&
            b.priority < 10 &&
            (a.distanceToCursor - b.distanceToCursor) < 0.25) {
          return -1;
        }
        if (b.priority >= 10 &&
            a.priority < 10 &&
            (b.distanceToCursor - a.distanceToCursor) < 0.25) {
          return 1;
        }
        final dDiff = (a.distanceToCursor - b.distanceToCursor).abs();
        if (dDiff < 0.05) {
          return b.priority.compareTo(a.priority);
        }
        return a.distanceToCursor.compareTo(b.distanceToCursor);
      });

      final bestCandidate = clustered.first;
      return RoofSnapGuideResult(
        point: bestCandidate.point,
        snapLabel: bestCandidate.label,
        magneticGuides: [
          (anchor, bestCandidate.point),
          bestCandidate.guideLine,
        ],
        isIntersectionSnap: true,
      );
    }

    // 7. Fallback to continuous ray tracking along anchorDir
    final guideSpan = math.max(activeProjT + 2.0, 10.0);
    final rayLabel =
        (activeAngleDeg - 45.0).abs() < 0.5 ||
            (activeAngleDeg - 135.0).abs() < 0.5 ||
            (activeAngleDeg - 225.0).abs() < 0.5 ||
            (activeAngleDeg - 315.0).abs() < 0.5
        ? hip45Label()
        : hipAngleLabel(activeAngleDeg.toStringAsFixed(1));

    return RoofSnapGuideResult(
      point: activeProjPt,
      snapLabel: rayLabel,
      magneticGuides: [(anchor, anchor + activeDir * guideSpan)],
      isIntersectionSnap: false,
    );
  }
}

/// Result of roof drafting magnetic guide snapping.
class RoofSnapGuideResult {
  final Offset point;
  final String snapLabel;
  final List<(Offset, Offset)> magneticGuides;
  final bool isIntersectionSnap;

  const RoofSnapGuideResult({
    required this.point,
    required this.snapLabel,
    required this.magneticGuides,
    this.isIntersectionSnap = false,
  });
}

class _RoofGuideCandidate {
  final Offset point;
  final String label;
  final (Offset, Offset) guideLine;
  final double distanceToCursor;
  final int priority;

  _RoofGuideCandidate({
    required this.point,
    required this.label,
    required this.guideLine,
    required this.distanceToCursor,
    required this.priority,
  });
}
