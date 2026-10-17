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
import 'architect_element_id.dart';

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
  ridgePurlin,
  fascia,
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

  const ArchitectRoofSectionSlice({
    required this.roofId,
    required this.fromS,
    required this.toS,
    required this.members,
    required this.bottomProfile,
    required this.envelopePath,
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

  /// Slices all roof planes on [storey] along the vertical section plane [sectionLine]
  /// and produces clean, non-overlapping layer polygons, mitered ridge joins,
  /// plumbed eaves with fascia boards, discrete battens (`летви`), counter-battens,
  /// rafters, Mauerlat (`мауерлат`), and ridge purlin (`билова столица`).
  static List<ArchitectRoofSectionSlice> buildSectionSlices({
    required ArchitectStorey storey,
    required ArchitectSection sectionLine,
  }) {
    if (storey.roofs.isEmpty) return const [];
    final lineVec = sectionLine.end - sectionLine.start;
    final lineLen = lineVec.distance;
    if (lineLen < 1e-6) return const [];
    final lineDir = lineVec / lineLen;

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

    final result = <ArchitectRoofSectionSlice>[];

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

      for (final layer in roof.assembly.layers) {
        final dTopV = cumulativePerp / cosSlope;
        final dBotV = (cumulativePerp + layer.thickness) / cosSlope;

        if (layer.role == ArchitectRoofLayerRole.battens) {
          battenTopPerp = cumulativePerp;
        }
        if (layer.role == ArchitectRoofLayerRole.rafters ||
            layer.isBetweenRafters) {
          rafterTopPerp ??= cumulativePerp;
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

      // 5. Mauerlat / Wall Plate (Мауерлат) at the supporting wall or eaves overhang line
      if (timber.hasWallPlate && slopeDirDotSection > 0.25) {
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
          final halfWp = timber.wallPlateWidth * 0.5;
          final sa = sWallPlate - halfWp;
          final sb = sWallPlate + halfWp;
          final zSupportTop = storey.elevation + roof.baseElevationOffset;
          final zSupportBot = zSupportTop - timber.wallPlateHeight;
          final wpPoly = <Offset>[
            Offset(sa, zSupportTop),
            Offset(sb, zSupportTop),
            Offset(sb, zSupportBot),
            Offset(sa, zSupportBot),
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
        }
      }

      // 6. Ridge Purlin (Билова столица) at the high end (only once per shared ridge)
      if (timber.hasRidgePurlin && slopeDirDotSection > 0.25) {
        final highAtEnd = zTop1 >= zTop0;
        final sRidge = highAtEnd ? s1 : s0;
        final zRidgeBot = highAtEnd ? zBot1 : zBot0;
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

      // 7. Fascia Board (Челна дъска) at the free lower eaves end
      if (timber.hasFasciaBoard) {
        final lowAtStart = zTop0 <= zTop1;
        if (lowAtStart && !sharesStart) {
          final fw = timber.fasciaThickness;
          final fasciaPoly = <Offset>[
            Offset(s0 - fw, zTop0),
            Offset(s0, zTop0),
            Offset(s0, zBot0),
            Offset(s0 - fw, zBot0),
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
        } else if (!lowAtStart && !sharesEnd) {
          final fw = timber.fasciaThickness;
          final fasciaPoly = <Offset>[
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
      }

      // 8. Boolean-subtract discrete timber cross-sections (rafters, wallPlate, ridgePurlin)
      // from overlapping continuous layers so zero redundant lines cross through them!
      final cleanedLayers = <ArchitectRoofSectionMember>[];
      for (final layerMember in layerMembers) {
        var cleanedPath = layerMember.path;
        for (final dm in discreteMembers) {
          if (dm.kind == ArchitectRoofMemberKind.rafter ||
              dm.kind == ArchitectRoofMemberKind.wallPlate ||
              dm.kind == ArchitectRoofMemberKind.ridgePurlin) {
            try {
              cleanedPath = Path.combine(
                PathOperation.difference,
                cleanedPath,
                dm.path,
              );
            } catch (_) {}
          }
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

      final members = [...cleanedLayers, ...discreteMembers];

      var envelope = Path()
        ..addPolygon([
          Offset(s0, zTop0),
          Offset(s1, zTop1),
          Offset(s1, zTop1 - totalVerticalThick),
          Offset(s0, zTop0 - totalVerticalThick),
        ], true);
      for (final m in discreteMembers) {
        if (m.kind == ArchitectRoofMemberKind.wallPlate ||
            m.kind == ArchitectRoofMemberKind.ridgePurlin ||
            m.kind == ArchitectRoofMemberKind.fascia) {
          try {
            envelope = Path.combine(PathOperation.union, envelope, m.path);
          } catch (_) {}
        }
      }

      result.add(
        ArchitectRoofSectionSlice(
          roofId: roof.id,
          fromS: s0,
          toS: s1,
          members: members,
          bottomProfile: [
            Offset(s0, zTop0 - totalVerticalThick),
            Offset(s1, zTop1 - totalVerticalThick),
          ],
          envelopePath: envelope,
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
