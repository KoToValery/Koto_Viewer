import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'structural_polygon_distance.dart';

/// Eurocode 2 (EC2 EN 1992-1-1) Vertical Gravitational Capacity & Feasibility Calculator.
///
/// Analyzes multi-storey load paths, column crushing capacity (N_Ed vs N_Rd),
/// punching shear around columns (v_Ed vs v_Rd,c), slab span-to-depth deflection ratios,
/// and foundation soil pressure.
class VerticalCapacityCalculator {
  const VerticalCapacityCalculator._();

  /// Extracts numeric f_ck in MPa from concrete grade string (e.g. 'C25/30' -> 25.0).
  static double parseConcreteFck(String grade) {
    final match = RegExp(r'C(\d+)').firstMatch(grade.toUpperCase());
    if (match != null) {
      return double.tryParse(match.group(1) ?? '25') ?? 25.0;
    }
    return 25.0;
  }

  /// Calculates the cross-sectional area of a column in m².
  static double getColumnAreaM2(StructuralColumn col, double scale) {
    final wM = col.width / scale;
    final hM = col.height / scale;
    switch (col.shape) {
      case ColumnShape.rectangular:
        return wM * hM;
      case ColumnShape.circular:
        final r = wM / 2.0;
        return math.pi * r * r;
      case ColumnShape.lShape:
        final tM = math.min(col.thickness / scale, math.min(wM, hM) * 0.9);
        return wM * tM + (hM - tM) * tM;
    }
  }

  /// Estimates the tributary area A_trib in m² for a column based on surrounding supports
  /// and building/slab perimeter boundaries.
  static double calculateColumnTributaryAreaM2({
    required StructuralColumn col,
    required StoreyLevel storey,
    required double scale,
    required double totalFloorAreaM2,
  }) {
    final cPos = col.center;
    double minDxPos = double.infinity;
    double minDxNeg = double.infinity;
    double minDyPos = double.infinity;
    double minDyNeg = double.infinity;

    // 1. Check distance to other columns
    for (final other in storey.columns) {
      if (other.id == col.id) continue;
      final dx = other.center.dx - cPos.dx;
      final dy = other.center.dy - cPos.dy;
      final dist = (other.center - cPos).distance;
      if (dist < 1e-3) continue;

      if (dx.abs() > 0.1 * scale) {
        if (dx > 0 && dx < minDxPos) minDxPos = dx;
        if (dx < 0 && -dx < minDxNeg) minDxNeg = -dx;
      }
      if (dy.abs() > 0.1 * scale) {
        if (dy > 0 && dy < minDyPos) minDyPos = dy;
        if (dy < 0 && -dy < minDyNeg) minDyNeg = -dy;
      }
    }

    // 2. Check distance to shear walls
    for (final wall in storey.shearWalls) {
      final mid = (wall.start + wall.end) / 2.0;
      final dx = mid.dx - cPos.dx;
      final dy = mid.dy - cPos.dy;
      if (dx.abs() > 0.1 * scale) {
        if (dx > 0 && dx < minDxPos) minDxPos = dx;
        if (dx < 0 && -dx < minDxNeg) minDxNeg = -dx;
      }
      if (dy.abs() > 0.1 * scale) {
        if (dy > 0 && dy < minDyPos) minDyPos = dy;
        if (dy < 0 && -dy < minDyNeg) minDyNeg = -dy;
      }
    }

    // 3. Distance to slab boundary in 4 cardinal directions (if slab polygon exists)
    final double colWM = col.width / scale;
    final double colHM = col.height / scale;
    final double defaultEdgeOverhangM = math.max(0.20, math.min(colWM, colHM) * 0.5 + 0.15);

    double slabEdgeDxPos = double.infinity;
    double slabEdgeDxNeg = double.infinity;
    double slabEdgeDyPos = double.infinity;
    double slabEdgeDyNeg = double.infinity;

    for (final slab in storey.slabs) {
      final poly = slab.polygon;
      final n = poly.length;
      if (n < 3) continue;
      for (int i = 0; i < n; i++) {
        final p1 = poly[i];
        final p2 = poly[(i + 1) % n];

        // Horizontal ray at y = cPos.dy (checks +X and -X)
        if ((p1.dy <= cPos.dy && p2.dy > cPos.dy) || (p2.dy <= cPos.dy && p1.dy > cPos.dy)) {
          final dyTotal = p2.dy - p1.dy;
          if (dyTotal.abs() > 1e-4) {
            final t = (cPos.dy - p1.dy) / dyTotal;
            final xInt = p1.dx + t * (p2.dx - p1.dx);
            final dx = (xInt - cPos.dx) / scale;
            if (dx > 0 && dx < slabEdgeDxPos) slabEdgeDxPos = dx;
            if (dx < 0 && -dx < slabEdgeDxNeg) slabEdgeDxNeg = -dx;
          }
        }

        // Vertical ray at x = cPos.dx (checks +Y and -Y)
        if ((p1.dx <= cPos.dx && p2.dx > cPos.dx) || (p2.dx <= cPos.dx && p1.dx > cPos.dx)) {
          final dxTotal = p2.dx - p1.dx;
          if (dxTotal.abs() > 1e-4) {
            final t = (cPos.dx - p1.dx) / dxTotal;
            final yInt = p1.dy + t * (p2.dy - p1.dy);
            final dy = (yInt - cPos.dy) / scale;
            if (dy > 0 && dy < slabEdgeDyPos) slabEdgeDyPos = dy;
            if (dy < 0 && -dy < slabEdgeDyNeg) slabEdgeDyNeg = -dy;
          }
        }
      }
    }

    // Determine tributary half-spans in all 4 directions
    final double halfDxPos = minDxPos.isFinite
        ? (minDxPos / scale) / 2.0
        : (slabEdgeDxPos.isFinite ? slabEdgeDxPos.clamp(0.15, 4.0) : defaultEdgeOverhangM);

    final double halfDxNeg = minDxNeg.isFinite
        ? (minDxNeg / scale) / 2.0
        : (slabEdgeDxNeg.isFinite ? slabEdgeDxNeg.clamp(0.15, 4.0) : defaultEdgeOverhangM);

    final double halfDyPos = minDyPos.isFinite
        ? (minDyPos / scale) / 2.0
        : (slabEdgeDyPos.isFinite ? slabEdgeDyPos.clamp(0.15, 4.0) : defaultEdgeOverhangM);

    final double halfDyNeg = minDyNeg.isFinite
        ? (minDyNeg / scale) / 2.0
        : (slabEdgeDyNeg.isFinite ? slabEdgeDyNeg.clamp(0.15, 4.0) : defaultEdgeOverhangM);

    final double spanXM = (halfDxPos + halfDxNeg).clamp(1.0, 8.0);
    final double spanYM = (halfDyPos + halfDyNeg).clamp(1.0, 8.0);

    double aTrib = spanXM * spanYM;

    // Clamp to realistic maximum fraction of floor area if floor area is defined
    if (totalFloorAreaM2 > 5.0 && storey.columns.isNotEmpty) {
      final maxShare = (totalFloorAreaM2 / storey.columns.length) * 2.5;
      aTrib = math.min(aTrib, maxShare);
    }

    return math.max(1.5, aTrib);
  }

  /// Calculates max clear span between adjacent supports in the storey (meters)
  /// and returns the coordinates of the critical span segment.
  static bool _segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
    double ccw(Offset a, Offset b, Offset c) {
      return (c.dy - a.dy) * (b.dx - a.dx) - (b.dy - a.dy) * (c.dx - a.dx);
    }

    final d1 = ccw(a1, a2, b1);
    final d2 = ccw(a1, a2, b2);
    final d3 = ccw(b1, b2, a1);
    final d4 = ccw(b1, b2, a2);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// Checks whether there is any intervening support (column or shear wall) between p1 and p2.
  /// Uses both Gabriel disc criterion and dynamic corridor checks so that spans cannot
  /// jump across intermediate supports, even when supports are snapped 12.5cm off-center.
  static bool _hasInterveningSupport({
    required Offset p1,
    required Offset p2,
    required StoreyLevel storey,
    required double scale,
    String? skipColId1,
    String? skipColId2,
    String? skipWallId1,
    String? skipWallId2,
  }) {
    final vec = p2 - p1;
    final len = vec.distance;
    if (len < 1e-3) return false;

    final u = vec / len;
    final mid = (p1 + p2) / 2.0;
    final radius = len / 2.0;
    final radiusLimit = math.max(0.0, radius - 0.25 * scale);
    final radiusLimitSq = radiusLimit * radiusLimit;

    // Corridor tolerance: for span distances, an obstacle within 1.2m of the line
    // or within 22% of span length definitely intercepts the slab bay.
    final corridorTol = math.max(0.70 * scale, math.min(1.80 * scale, 0.22 * len));

    // 1. Check all other columns
    for (final col in storey.columns) {
      if (col.id == skipColId1 || col.id == skipColId2) continue;
      final cPos = col.center;

      // Gabriel disc check
      final distToMidSq = (cPos - mid).distanceSquared;
      if (distToMidSq < radiusLimitSq) {
        return true;
      }

      // Corridor projection check
      final t = (cPos - p1).dx * u.dx + (cPos - p1).dy * u.dy;
      if (t > 0.35 * scale && t < len - 0.35 * scale) {
        final perpDist = ((cPos - p1).dx * (-u.dy) + (cPos - p1).dy * u.dx).abs();
        if (perpDist <= corridorTol) {
          return true;
        }
      }
    }

    // 2. Check all shear walls
    for (final wall in storey.shearWalls) {
      if (wall.id == skipWallId1 || wall.id == skipWallId2) continue;
      final wMid = (wall.start + wall.end) / 2.0;
      final wVec = wall.end - wall.start;

      // Candidate points on the wall to check: endpoints, midpoint, and intersection with line p1-p2
      final wallTestPoints = <Offset>[
        wall.start,
        wall.end,
        wMid,
      ];

      // Intersection of wall segment with the infinite line p1-p2
      final n = Offset(-u.dy, u.dx);
      final denom = wVec.dx * n.dx + wVec.dy * n.dy;
      if (denom.abs() > 1e-4) {
        final sInt = ((p1 - wall.start).dx * n.dx + (p1 - wall.start).dy * n.dy) / denom;
        if (sInt >= 0.0 && sInt <= 1.0) {
          wallTestPoints.add(Offset(wall.start.dx + sInt * wVec.dx, wall.start.dy + sInt * wVec.dy));
        }
      }

      // Check all candidate points on this wall
      for (final pt in wallTestPoints) {
        // Gabriel disc check
        if ((pt - mid).distanceSquared < radiusLimitSq) {
          return true;
        }

        // Corridor projection check
        final t = (pt - p1).dx * u.dx + (pt - p1).dy * u.dy;
        if (t > 0.35 * scale && t < len - 0.35 * scale) {
          final perpDist = ((pt - p1).dx * (-u.dy) + (pt - p1).dy * u.dx).abs();
          if (perpDist <= corridorTol) {
            return true;
          }
        }
      }

      // Segment intersection test (crosses wall centerline)
      if (_segmentsIntersect(p1, p2, wall.start, wall.end)) {
        return true;
      }
    }

    return false;
  }

  /// Checks whether a candidate span p1-p2 is the diagonal hypotenuse of an orthogonal or near-orthogonal
  /// structural bay (e.g. opposite corners of a rectangular panel), where two-way bending is actually
  /// governed by the orthogonal spans rather than the diagonal distance.
  static bool _isDiagonalOfBay({
    required Offset p1,
    required Offset p2,
    required StoreyLevel storey,
    required double scale,
    String? skipColId1,
    String? skipColId2,
    String? skipWallId1,
    String? skipWallId2,
  }) {
    final len = (p2 - p1).distance;
    final lenM = len / scale;
    if (lenM < 1.5) return false;

    // Both delta X and delta Y must be significant (at least 0.8m)
    final dxM = (p2.dx - p1.dx).abs() / scale;
    final dyM = (p2.dy - p1.dy).abs() / scale;
    if (dxM < 0.8 || dyM < 0.8) return false;

    // Collect all candidate corner supports (excluding the elements being evaluated)
    final candidateCorners = <Offset>[];
    for (final col in storey.columns) {
      if (col.id == skipColId1 || col.id == skipColId2) continue;
      candidateCorners.add(col.center);
    }
    for (final wall in storey.shearWalls) {
      if (wall.id == skipWallId1 || wall.id == skipWallId2) continue;
      candidateCorners.add((wall.start + wall.end) / 2.0);
      candidateCorners.add(wall.start);
      candidateCorners.add(wall.end);
    }

    for (final s in candidateCorners) {
      final v1 = s - p1;
      final v2 = p2 - s;
      final d1 = v1.distance;
      final d2 = v2.distance;
      if (d1 < 0.8 * scale || d2 < 0.8 * scale) continue;
      if (d1 > len - 0.2 * scale || d2 > len - 0.2 * scale) continue;

      final u1 = v1 / d1;
      final u2 = v2 / d2;
      final dot = (u1.dx * u2.dx + u1.dy * u2.dy).abs();
      if (dot <= 0.45) {
        final pythDist = math.sqrt(d1 * d1 + d2 * d2);
        if ((pythDist - len).abs() <= 0.25 * len) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns the closest point on segment [a, b] to point [p].
  static Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq < 1e-6) return a;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / abLenSq).clamp(0.0, 1.0);
    return Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
  }

  /// Returns the closest pair of points between two segments [a1, b1] and [a2, b2].
  static (Offset, Offset) _closestPointsBetweenSegments(
    Offset a1,
    Offset b1,
    Offset a2,
    Offset b2,
  ) {
    final m1 = (a1 + b1) / 2.0;
    final m2 = (a2 + b2) / 2.0;
    final candidates = [
      (a1, _closestPointOnSegment(a1, a2, b2)),
      (b1, _closestPointOnSegment(b1, a2, b2)),
      (_closestPointOnSegment(a2, a1, b1), a2),
      (_closestPointOnSegment(b2, a1, b1), b2),
      (m1, _closestPointOnSegment(m1, a2, b2)),
      (_closestPointOnSegment(m2, a1, b1), m2),
    ];
    var best = candidates.first;
    var minDSq = (best.$2 - best.$1).distanceSquared;
    for (int k = 1; k < candidates.length; k++) {
      final dSq = (candidates[k].$2 - candidates[k].$1).distanceSquared;
      if (dSq < minDSq) {
        minDSq = dSq;
        best = candidates[k];
      }
    }
    return best;
  }

  /// Split at every slab/opening crossing; a span may not bridge a void or
  /// disconnected slab. Boundary segments remain valid for edge supports.
  static bool _spanOnSlab(Offset a,Offset b,StoreyLevel floor,double scale) {
    if(floor.slabs.isEmpty) return true; // geometry-only callers
    final u=b-a;
    double cross(Offset x,Offset y)=>x.dx*y.dy-x.dy*y.dx;
    final cuts=<double>[0,1];
    for(final slab in floor.slabs) {
      for(final ring in [slab.polygon,...slab.openings]) {
        for(var i=0;i<ring.length;i++) {
          final c=ring[i],v=ring[(i+1)%ring.length]-c;
          final den=cross(u,v);
          if(den.abs()<=1e-10*u.distance*v.distance) continue;
          final t=cross(c-a,v)/den, q=cross(c-a,u)/den;
          if(t>0 && t<1 && q>=0 && q<=1) cuts.add(t);
        }
      }
    }
    cuts.sort();
    bool onEdge(Offset p,List<Offset> ring) {
      for(var i=0;i<ring.length;i++) {
        if(StructuralPolygonDistance.pointToSegment(p,ring[i],ring[(i+1)%ring.length])<=1e-7*scale) return true;
      }
      return false;
    }
    for(var i=1;i<cuts.length;i++) {
      if(cuts[i]-cuts[i-1]<1e-9) continue;
      final p=a+u*((cuts[i]+cuts[i-1])/2);
      if(!floor.slabs.any((s)=>(StructuralPolygonDistance.inside(p,s.polygon)||onEdge(p,s.polygon)) &&
        !s.openings.any((h)=>StructuralPolygonDistance.inside(p,h)&&!onEdge(p,h)))) {
        return false;
      }
    }
    return true;
  }

  /// Candidate support intervals in metres, sorted from largest to smallest.
  /// Shared by the manual report and progressive automatic infill.
  static List<({double spanM, (Offset, Offset) segment})> calculateSupportSpans(
    StoreyLevel storey,
    double scale,
  ) {
    final List<({double spanM, (Offset, Offset) segment})> candidateSpans = [];

    // Beam spans are split at vertical supports, including a live preview.
    for (final beam in storey.beams) {
      final v=beam.end-beam.start, length=v.distance;
      if(length<.5*scale) continue;
      final u=v/length;
      final cuts=<double>[0,length];
      void add(Offset p) {
        final t=(p-beam.start).dx*u.dx+(p-beam.start).dy*u.dy;
        if(t>.05*scale && t<length-.05*scale &&
            StructuralPolygonDistance.pointToSegment(p,beam.start,beam.end)<=.45*scale) { cuts.add(t); }
      }
      for(final col in storey.columns) { add(col.center); }
      for(final wall in storey.shearWalls) {
        final w=wall.end-wall.start;
        final den=v.dx*w.dy-v.dy*w.dx;
        if(den.abs()>1e-10*length*w.distance) {
          final d=wall.start-beam.start;
          final t=(d.dx*w.dy-d.dy*w.dx)/den;
          final q=(d.dx*v.dy-d.dy*v.dx)/den;
          if(t>0 && t<1 && q>=0 && q<=1) add(beam.start+v*t);
        }
        add(wall.start); add(wall.end); add(wall.center);
      }
      cuts.sort();
      for(var i=1;i<cuts.length;i++) {
        final spanM=(cuts[i]-cuts[i-1])/scale;
        if(spanM>=.5) { candidateSpans.add((spanM:spanM,
            segment:(beam.start+u*cuts[i-1],beam.start+u*cuts[i]))); }
      }
    }

    // 2. Clear Spans along Grid Axes (supports lying within 0.45m of axis line, including intersecting shear walls)
    for (final axis in storey.gridAxes) {
      final aVec = axis.end - axis.start;
      final aLen = aVec.distance;
      if (aLen < 1e-4) continue;
      final uAxis = aVec / aLen;
      final nAxis = Offset(-uAxis.dy, uAxis.dx);

      final supportsOnAxis = <({Offset pos, double t, String supportId})>[];
      for (final col in storey.columns) {
        final distPerp = ((col.center - axis.start).dx * nAxis.dx +
                (col.center - axis.start).dy * nAxis.dy)
            .abs();
        if (distPerp <= 0.45 * scale) {
          final t = (col.center - axis.start).dx * uAxis.dx +
              (col.center - axis.start).dy * uAxis.dy;
          supportsOnAxis.add((pos: col.center, t: t, supportId: col.id));
        }
      }
      for (final wall in storey.shearWalls) {
        final wVec = wall.end - wall.start;
        // Check intersection of shear wall with axis line
        final denom = wVec.dx * nAxis.dx + wVec.dy * nAxis.dy;
        if (denom.abs() > 1e-4) {
          final sInt = ((axis.start - wall.start).dx * nAxis.dx +
                  (axis.start - wall.start).dy * nAxis.dy) /
              denom;
          if (sInt >= -0.15 && sInt <= 1.15) {
            final pInt = wall.start + wVec * sInt.clamp(0.0, 1.0);
            final distPerp = ((pInt - axis.start).dx * nAxis.dx +
                    (pInt - axis.start).dy * nAxis.dy)
                .abs();
            if (distPerp <= 0.45 * scale) {
              final t = (pInt - axis.start).dx * uAxis.dx +
                  (pInt - axis.start).dy * uAxis.dy;
              supportsOnAxis.add((pos: pInt, t: t, supportId: wall.id));
            }
          }
        }

        // Check endpoints and midpoint of shear wall
        final mid = (wall.start + wall.end) / 2.0;
        for (final pt in [wall.start, wall.end, mid]) {
          final distPerp = ((pt - axis.start).dx * nAxis.dx +
                  (pt - axis.start).dy * nAxis.dy)
              .abs();
          if (distPerp <= 0.45 * scale) {
            final t = (pt - axis.start).dx * uAxis.dx +
                (pt - axis.start).dy * uAxis.dy;
            supportsOnAxis.add((pos: pt, t: t, supportId: wall.id));
          }
        }
      }

      // Deduplicate supports from the same element that have very close t (< 0.30m)
      supportsOnAxis.sort((a, b) => a.t.compareTo(b.t));
      final dedupedSupports = <({Offset pos, double t, String supportId})>[];
      for (final s in supportsOnAxis) {
        if (dedupedSupports.isEmpty) {
          dedupedSupports.add(s);
        } else {
          final prev = dedupedSupports.last;
          if (prev.supportId == s.supportId && (s.t - prev.t).abs() < 0.30 * scale) {
            continue;
          }
          dedupedSupports.add(s);
        }
      }

      for (int i = 0; i < dedupedSupports.length - 1; i++) {
        // Do not form span between two points of the SAME wall!
        if (dedupedSupports[i].supportId == dedupedSupports[i + 1].supportId) {
          continue;
        }

        final distM = (dedupedSupports[i + 1].t - dedupedSupports[i].t) / scale;
        if (distM >= 1.0) {
          // Verify that no other support intervenes between them
          if (_hasInterveningSupport(
            p1: dedupedSupports[i].pos,
            p2: dedupedSupports[i + 1].pos,
            storey: storey,
            scale: scale,
            skipColId1: dedupedSupports[i].supportId,
            skipColId2: dedupedSupports[i + 1].supportId,
            skipWallId1: dedupedSupports[i].supportId,
            skipWallId2: dedupedSupports[i + 1].supportId,
          )) {
            continue;
          }

          candidateSpans.add((
            spanM: distM,
            segment: (dedupedSupports[i].pos, dedupedSupports[i + 1].pos),
          ));
        }
      }
    }

    // 3. Spans between adjacent Column pairs (Gabriel disc + corridor check)
    final cols = storey.columns;
    for (int i = 0; i < cols.length; i++) {
      for (int j = i + 1; j < cols.length; j++) {
        final c1 = cols[i].center;
        final c2 = cols[j].center;
        final dM = (c2 - c1).distance / scale;
        if (dM < 1.0) continue;

        if (_hasInterveningSupport(
          p1: c1,
          p2: c2,
          storey: storey,
          scale: scale,
          skipColId1: cols[i].id,
          skipColId2: cols[j].id,
        )) {
          continue;
        }

        if (_isDiagonalOfBay(
          p1: c1,
          p2: c2,
          storey: storey,
          scale: scale,
          skipColId1: cols[i].id,
          skipColId2: cols[j].id,
        )) {
          continue;
        }

        candidateSpans.add((spanM: dM, segment: (c1, c2)));
      }
    }

    // 4. Spans between Columns and Shear Walls (measured to closest point on wall)
    for (final col in storey.columns) {
      for (final wall in storey.shearWalls) {
        final wallPt = _closestPointOnSegment(col.center, wall.start, wall.end);
        final dM = (col.center - wallPt).distance / scale;
        if (dM < 1.0) continue;

        if (_hasInterveningSupport(
          p1: col.center,
          p2: wallPt,
          storey: storey,
          scale: scale,
          skipColId1: col.id,
          skipWallId1: wall.id,
        )) {
          continue;
        }

        if (_isDiagonalOfBay(
          p1: col.center,
          p2: wallPt,
          storey: storey,
          scale: scale,
          skipColId1: col.id,
          skipWallId1: wall.id,
        )) {
          continue;
        }

        candidateSpans.add((spanM: dM, segment: (col.center, wallPt)));
      }
    }

    // 5. Spans between Shear Wall pairs (measured between closest points of walls)
    final walls = storey.shearWalls;
    for (int i = 0; i < walls.length; i++) {
      for (int j = i + 1; j < walls.length; j++) {
        final pair = _closestPointsBetweenSegments(
          walls[i].start,
          walls[i].end,
          walls[j].start,
          walls[j].end,
        );
        final p1 = pair.$1;
        final p2 = pair.$2;
        final dM = (p2 - p1).distance / scale;
        if (dM < 1.0) continue;

        if (_hasInterveningSupport(
          p1: p1,
          p2: p2,
          storey: storey,
          scale: scale,
          skipWallId1: walls[i].id,
          skipWallId2: walls[j].id,
        )) {
          continue;
        }

        if (_isDiagonalOfBay(
          p1: p1,
          p2: p2,
          storey: storey,
          scale: scale,
          skipWallId1: walls[i].id,
          skipWallId2: walls[j].id,
        )) {
          continue;
        }

        candidateSpans.add((spanM: dM, segment: (p1, p2)));
      }
    }

    candidateSpans.removeWhere((s)=>!_spanOnSlab(s.segment.$1,s.segment.$2,storey,scale));
    candidateSpans.sort((a, b) => b.spanM.compareTo(a.spanM));
    return candidateSpans;
  }

  /// Maximum preliminary support interval, or NaN when undetermined.
  static ({double maxSpanM, (Offset, Offset)? criticalSpanSegment}) calculateClearSpan(
    StoreyLevel storey,
    double scale,
  ) {
    final spans = calculateSupportSpans(storey, scale);
    return spans.isEmpty
        ? (maxSpanM: double.nan, criticalSpanSegment: null)
        : (maxSpanM: spans.first.spanM, criticalSpanSegment: spans.first.segment);
  }

  /// Calculates max clear span between supports in the storey (meters).
  static double calculateMaxSpanM(StoreyLevel storey, double scale) {
    return calculateClearSpan(storey, scale).maxSpanM;
  }

  /// All adjacent support intervals, deduplicated across axes and pair searches.
  /// A crossing of slabs with different thickness uses the smallest assigned
  /// thickness along the interval. Holes/disconnected plates remain excluded.
  static List<SupportSpanCheck> evaluateSupportSpans(StoreyLevel floor, double scale) {
    if (!scale.isFinite || scale <= 0 || floor.slabs.isEmpty) return const [];
    final checks = <SupportSpanCheck>[];
    final seen = <String>{};
    String point(Offset p) => '${(p.dx / scale * 1e6).round()},${(p.dy / scale * 1e6).round()}';
    for (final span in calculateSupportSpans(floor, scale)) {
      final a = span.segment.$1, b = span.segment.$2;
      final ends = [point(a),point(b)]..sort();
      if (!seen.add(ends.join(':'))) continue;
      final slabs = floor.slabs.where((slab) {
        // Positive length within this plate, excluding isolated endpoint contact.
        final cuts = <double>[0,1];
        final u = b-a;
        double cross(Offset x, Offset y) => x.dx*y.dy-x.dy*y.dx;
        for (var i=0; i<slab.polygon.length; i++) {
          final c=slab.polygon[i], v=slab.polygon[(i+1)%slab.polygon.length]-c;
          final den=cross(u,v);
          if (den.abs() <= 1e-10*u.distance*v.distance) continue;
          final t=cross(c-a,v)/den, q=cross(c-a,u)/den;
          if (t>0 && t<1 && q>=0 && q<=1) cuts.add(t);
        }
        cuts.sort();
        for(var i=1; i<cuts.length; i++) {
          if (cuts[i]-cuts[i-1] < 1e-9) continue;
          final p=a+u*((cuts[i]+cuts[i-1])/2);
          if (StructuralPolygonDistance.inside(p,slab.polygon) ||
              List.generate(slab.polygon.length, (j) =>
                StructuralPolygonDistance.pointToSegment(p,slab.polygon[j],
                  slab.polygon[(j+1)%slab.polygon.length]) <= 1e-7*scale).any((v)=>v)) { return true; }
        }
        return false;
      }).toList();
      if (slabs.isEmpty) continue;
      final h=slabs.every((s)=>s.thickness.isFinite && s.thickness>.03)
          ? slabs.map((s)=>s.thickness).reduce(math.min) : double.nan;
      // A beam elsewhere on this floor must not improve every slab interval.
      final hasBeam=floor.beams.any((beam) =>
        StructuralPolygonDistance.pointToSegment(a,beam.start,beam.end)<=.05*scale &&
        StructuralPolygonDistance.pointToSegment(b,beam.start,beam.end)<=.05*scale);
      checks.add(SupportSpanCheck(segment:span.segment,spanM:span.spanM,
        thicknessM:h,allowableSpanM:h.isFinite ? (h-.03)*(hasBeam ? 28 : 22) : double.nan,
        slabIds:List.unmodifiable(slabs.map((s)=>s.id)),hasBeams:hasBeam));
    }
    checks.sort((a,b)=>b.utilization.compareTo(a.utilization));
    return List.unmodifiable(checks);
  }

  /// The report and live placement assistant share the same local thickness
  /// assessment; no hidden centimetre tolerance or rounding changes safety.
  static SlabDeflectionCheck evaluateSlabSpan(StoreyLevel storey,double scale) {
    final checks=evaluateSupportSpans(storey,scale);
    final critical=checks.firstOrNull;
    final determined=critical?.isDetermined ?? false;
    final h=critical?.thicknessM ?? (storey.slabs.firstOrNull?.thickness ?? double.nan);
    final requiredH=determined ? critical!.requiredThicknessM : 0.0;
    final safe=determined && !critical!.isProblematic;
    return SlabDeflectionCheck(storeyId:storey.id,storeyName:storey.name,
      currentThicknessM:h,maxSpanM:determined ? critical!.spanM : double.nan,
      recommendedMinThicknessM:requiredH,isDeflectionSafe:safe,
      deflectionRatio:determined ? requiredH/h : 0,
      recommendation:!determined ? 'Support span is undetermined.' :
        safe ? 'Предварителната проверка по дебелината на плочата не установява превишено подпорно разстояние.' :
        'Подпорното разстояние превишава предварителния ориентир за зададената дебелина на плочата.',
      criticalSpanSegment:determined ? critical!.segment : null,
      hasBeams:critical?.hasBeams ?? false,supportSpans:checks);
  }

  /// Runs comprehensive Eurocode 2 vertical capacity analysis for the given project.
  static VerticalCapacityReport analyzeProject(
    StructuralProject project, {
    double cadUnitsPerMeter = 1.0,
  }) {
    final originalIndices = <String, int>{
      for (var i = 0; i < project.storeys.length; i++) project.storeys[i].id: i,
    };
    final sorted = project.ceilingStoreys
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    project = project.copyWith(storeys: sorted);
    if (project.storeys.isEmpty) {
      return VerticalCapacityReport.empty;
    }

    final scale = cadUnitsPerMeter;
    final double fck = parseConcreteFck(project.concreteGrade);
    // Design concrete compressive strength f_cd = alpha_cc * fck / gamma_c
    final double fcdMpa = 0.85 * fck / 1.50; // ~14.17 MPa for C25/30
    const double fydMpa = 500.0 / 1.15; // ~434.78 MPa for B500B
    const double rhoMin = 0.01; // 1% rebar
    const double etaReduction = 0.80; // reduction for second-order & eccentricities

    final int numStoreys = project.storeys.length;

    // Calculate total footprint area from ground slab or default foundations
    final groundStorey = project.storeys.first;
    double totalFootprintAreaM2 = 0.0;
    for (final s in groundStorey.slabs) {
      totalFootprintAreaM2 += s.netArea / (scale * scale);
    }
    if (totalFootprintAreaM2 <= 1.0 && (groundStorey.columns.isNotEmpty || groundStorey.shearWalls.isNotEmpty)) {
      if (!project.hasBasement && project.foundationType == FoundationType.stripFooting) {
        final strips = project.computeDefaultStripFoundations(groundStorey, cadUnitsPerMeter: scale);
        for (final strip in strips) {
          totalFootprintAreaM2 += StructuralSlab.calculateArea(strip) / (scale * scale);
        }
      } else if (!project.hasBasement && project.foundationType == FoundationType.matFoundation) {
        final mat = project.computeDefaultMatFoundation(groundStorey, cadUnitsPerMeter: scale);
        if (mat != null) {
          totalFootprintAreaM2 += mat.netArea / (scale * scale);
        }
      }
      if (totalFootprintAreaM2 <= 1.0 && groundStorey.columns.isNotEmpty) {
        // Fallback estimate footprint from column envelope
        final pts = groundStorey.columns.map((c) => c.center).toList();
        double minX = pts.first.dx, maxX = pts.first.dx;
        double minY = pts.first.dy, maxY = pts.first.dy;
        for (final p in pts) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        totalFootprintAreaM2 = ((maxX - minX + 2.0 * scale) / scale) *
            ((maxY - minY + 2.0 * scale) / scale);
      }
    }
    totalFootprintAreaM2 = math.max(10.0, totalFootprintAreaM2);

    // 1. Calculate floor load for each storey
    // ULS load: w_d = 1.35 * G_k + 1.50 * Q_k
    final List<double> storeyFloorLoadKnM2 = [];
    final List<double> storeySlabThicknessM = [];
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final s = project.storeys[sIdx];
      final double hSlabM = s.slabs.isNotEmpty ? s.slabs.first.thickness : 0.20;
      storeySlabThicknessM.add(hSlabM);
      final double gSlab = 25.0 * hSlabM; // slab self-weight
      final double totalGk = gSlab + project.deadLoadSuperimposed;
      final double totalQk = project.liveLoad;
      final double wd = 1.35 * totalGk + 1.50 * totalQk;
      storeyFloorLoadKnM2.add(wd);
    }

    final List<ColumnVerticalCheck> allColumnChecks = [];
    final List<SlabDeflectionCheck> allSlabChecks = [];
    int criticalCount = 0;
    int warningCount = 0;
    int punchingRiskCount = 0;
    double maxAxialUtil = 0.0;
    double maxPunchingUtil = 0.0;
    double totalAccumulatedBaseLoadKn = 0.0;

    // Shared preliminary span assessment, also used by automatic placement.
    for (final storey in project.storeys) {
      allSlabChecks.add(evaluateSlabSpan(storey.copyWith(
        gridAxes:storey.gridAxes.isEmpty ? project.effectiveGridAxes : storey.gridAxes),scale));
    }

    // 3. Complete building vertical load accumulating at foundation level
    // Includes all slabs (dead + superimposed + live loads), columns, shear walls, and beams
    totalAccumulatedBaseLoadKn = 0.0;
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final s = project.storeys[sIdx];
      final wd = storeyFloorLoadKnM2[sIdx];
      final hSlabM = storeySlabThicknessM[sIdx];

      // A. Slabs
      double floorSlabAreaM2 = 0.0;
      for (final slab in s.slabs) {
        floorSlabAreaM2 += slab.netArea / (scale * scale);
      }
      if (floorSlabAreaM2 <= 1.0) floorSlabAreaM2 = totalFootprintAreaM2;
      totalAccumulatedBaseLoadKn += floorSlabAreaM2 * wd;

      // B. Columns self-weight
      for (final col in s.columns) {
        final acM2 = getColumnAreaM2(col, scale);
        totalAccumulatedBaseLoadKn += 25.0 * acM2 * s.height * 1.35;
      }

      // C. Shear walls self-weight
      for (final wall in s.shearWalls) {
        final tM = wall.thickness / scale;
        final lM = (wall.end - wall.start).distance / scale;
        totalAccumulatedBaseLoadKn += 25.0 * (tM * lM) * s.height * 1.35;
      }

      // D. Beams self-weight (downstand part below slab)
      for (final beam in s.beams) {
        final wM = beam.width / scale;
        final hM = beam.depth / scale;
        final netHM = math.max(0.10, hM - hSlabM);
        final lM = (beam.end - beam.start).distance / scale;
        totalAccumulatedBaseLoadKn += 25.0 * (wM * netHM) * lM * 1.35;
      }
    }

    // 4. Calculate single-storey floor shear and self-weight for each column
    final List<List<({
      StructuralColumn col,
      double acM2,
      double aTribM2,
      double floorShearKn,
      double colSelfWeightKn,
      double singleNedKn,
      bool hasConnectedBeams,
    })>> storeyColumnData = [];

    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final storey = project.storeys[sIdx];
      final double floorWd = storeyFloorLoadKnM2[sIdx];
      final list = <({
        StructuralColumn col,
        double acM2,
        double aTribM2,
        double floorShearKn,
        double colSelfWeightKn,
        double singleNedKn,
        bool hasConnectedBeams,
      })>[];

      for (final col in storey.columns) {
        final double acM2 = getColumnAreaM2(col, scale);
        final double aTribM2 = calculateColumnTributaryAreaM2(
          col: col,
          storey: storey,
          scale: scale,
          totalFloorAreaM2: totalFootprintAreaM2,
        );
        final double floorShearKn = floorWd * aTribM2;
        final double colSelfWeightKn = 25.0 * acM2 * storey.height * 1.35;
        final double singleNedKn = floorShearKn + colSelfWeightKn;

        bool connectedBeams = false;
        for (final beam in storey.beams) {
          final dStart = (col.center - beam.start).distance / scale;
          final dEnd = (col.center - beam.end).distance / scale;
          if (dStart <= 0.40 || dEnd <= 0.40) {
            connectedBeams = true;
            break;
          }
        }

        list.add((
          col: col,
          acM2: acM2,
          aTribM2: aTribM2,
          floorShearKn: floorShearKn,
          colSelfWeightKn: colSelfWeightKn,
          singleNedKn: singleNedKn,
          hasConnectedBeams: connectedBeams,
        ));
      }
      storeyColumnData.add(list);
    }

    // 5. Multi-storey vertical load accumulation (top-to-bottom load rundown)
    final Map<int, List<({double accumulatedNedKn, int numStoreysAbove})>> accumulatedByStorey = {};

    // Start with top storey
    final int topIdx = numStoreys - 1;
    accumulatedByStorey[topIdx] = storeyColumnData[topIdx].map((c) => (
      accumulatedNedKn: c.singleNedKn,
      numStoreysAbove: 1,
    )).toList();

    for (int sIdx = numStoreys - 2; sIdx >= 0; sIdx--) {
      final currentList = storeyColumnData[sIdx];
      final upperData = storeyColumnData[sIdx + 1];
      final upperAcc = accumulatedByStorey[sIdx + 1]!;

      final List<({double accumulatedNedKn, int numStoreysAbove})> accList = [];
      for (int i = 0; i < currentList.length; i++) {
        final col = currentList[i].col;
        int matchUpperIdx = -1;
        double minUpperDist = 0.40 * scale;
        for (int u = 0; u < upperData.length; u++) {
          final dist = (col.center - upperData[u].col.center).distance;
          if (dist <= minUpperDist) {
            minUpperDist = dist;
            matchUpperIdx = u;
          }
        }

        if (matchUpperIdx != -1) {
          final uInfo = upperAcc[matchUpperIdx];
          accList.add((
            accumulatedNedKn: uInfo.accumulatedNedKn + currentList[i].singleNedKn,
            numStoreysAbove: uInfo.numStoreysAbove + 1,
          ));
        } else {
          accList.add((
            accumulatedNedKn: currentList[i].singleNedKn,
            numStoreysAbove: 1,
          ));
        }
      }
      accumulatedByStorey[sIdx] = accList;
    }

    // 6. Comprehensive EC2 axial compression & punching checks for all columns
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final storey = project.storeys[sIdx];
      final double hSlab = storeySlabThicknessM[sIdx];
      final currentCols = storeyColumnData[sIdx];
      final currentAcc = accumulatedByStorey[sIdx]!;

      for (int cIdx = 0; cIdx < currentCols.length; cIdx++) {
        final colData = currentCols[cIdx];
        final col = colData.col;
        final colName = 'C${cIdx + 1}';
        final accInfo = currentAcc[cIdx];
        final double accumulatedNedKn = accInfo.accumulatedNedKn;
        final int storeysAbove = accInfo.numStoreysAbove;

        // EC2 Axial compression resistance N_Rd
        // N_Rd = eta * [A_c * f_cd + A_s * f_yd]
        final double asRebarM2 = colData.acM2 * rhoMin;
        final double nrdKn = etaReduction *
            (colData.acM2 * fcdMpa * 1000.0 + asRebarM2 * fydMpa * 1000.0);

        final double axialUtil = nrdKn > 0 ? (accumulatedNedKn / nrdKn) : 1.0;
        if (axialUtil > maxAxialUtil) maxAxialUtil = axialUtil;

        // Punching shear at slab-column connection (EC2 §6.4)
        // If column has connected beams framing into it, punching shear failure is relieved by beam shear
        final double dEffM = math.max(0.12, hSlab - 0.03);
        final double colWM = col.width / scale;
        final double colHM = col.height / scale;

        double distToEdgeM = 3.0;
        if (storey.slabs.isNotEmpty) {
          for (final slab in storey.slabs) {
            for (final grip in slab.edgeGrips) {
              final d = (col.center - grip.midpoint).distance / scale;
              if (d < distToEdgeM) distToEdgeM = d;
            }
          }
        }

        final double betaPunching;
        final double u1PerimeterM;
        if (distToEdgeM < dEffM) {
          // Corner column
          betaPunching = 1.50;
          u1PerimeterM = colWM + colHM + (math.pi / 2.0) * (2.0 * dEffM);
        } else if (distToEdgeM < 2.0 * dEffM) {
          // Edge column
          betaPunching = 1.40;
          u1PerimeterM = 2.0 * colWM + colHM + math.pi * (2.0 * dEffM);
        } else {
          // Interior column
          betaPunching = 1.15;
          u1PerimeterM = 2.0 * (colWM + colHM) + 2.0 * math.pi * (2.0 * dEffM);
        }

        // Punching shear stress v_Ed in MPa
        final double vedMpa = (betaPunching * colData.floorShearKn) /
            (u1PerimeterM * dEffM * 1000.0);

        // Concrete punching resistance v_Rd,c
        final double kSize = math.min(2.0, 1.0 + math.sqrt(200.0 / (dEffM * 1000.0)));
        const double cRdc = 0.12;
        const double rhoL = 0.006; // nominal flexural rebar ratio
        double vrdcMpa = cRdc * kSize * math.pow(100.0 * rhoL * fck, 1.0 / 3.0);
        final double vMin = 0.035 * math.pow(kSize, 1.5) * math.sqrt(fck);
        vrdcMpa = math.max(vrdcMpa, vMin);

        final double punchingUtil = colData.hasConnectedBeams
            ? 0.0
            : (vrdcMpa > 0 ? (vedMpa / vrdcMpa) : 1.0);
        if (punchingUtil > maxPunchingUtil) maxPunchingUtil = punchingUtil;

        // Overall status for this column
        final VerticalCapacityStatus status;
        if (axialUtil > 1.0 || punchingUtil > 1.0) {
          status = VerticalCapacityStatus.critical;
          criticalCount++;
        } else if (axialUtil > 0.80 || punchingUtil > 0.85) {
          status = VerticalCapacityStatus.warning;
          warningCount++;
        } else {
          status = VerticalCapacityStatus.safe;
        }

        if (punchingUtil > 1.0) {
          punchingRiskCount++;
        }

        // Calculate minimum required cross-section for the architect
        final double reqAreaM2 = accumulatedNedKn /
            (etaReduction * (fcdMpa + rhoMin * fydMpa) * 1000.0);
        final double minSideCm =
            math.max(25.0, (math.sqrt(reqAreaM2) * 100.0 / 5.0).ceil() * 5.0);
        final double wallLengthCm =
            math.max(40.0, ((reqAreaM2 / 0.25) * 100.0 / 10.0).ceil() * 10.0);
        final String minSectionStr = minSideCm > 35.0
            ? '${minSideCm.toInt()}x${minSideCm.toInt()} cm (или шайба 25x${wallLengthCm.toInt()} cm)'
            : '${minSideCm.toInt()}x${minSideCm.toInt()} cm';

        final curWCm = (colWM * 100).round();
        final curHCm = (colHM * 100).round();
        final String rec;
        if (axialUtil > 1.0) {
          rec = 'Колона $colName в ${storey.name} не може да е ${curWCm}x$curHCm cm, трябва да е минимум $minSectionStr, за да носи $storeysAbove етажа (Ned = ${accumulatedNedKn.toStringAsFixed(0)} kN, капацитет Nrd = ${nrdKn.toStringAsFixed(0)} kN).';
        } else if (axialUtil > 0.80) {
          rec = 'Колона $colName в ${storey.name} е близо до капацитета си (${(axialUtil * 100).round()}%). Препоръчва се преминаване към $minSectionStr.';
        } else {
          rec = 'Колона $colName (${curWCm}x$curHCm cm) в ${storey.name} поема $storeysAbove етажа напълно безопасно (${(axialUtil * 100).round()}%).';
        }

        final int recSlabH = (hSlab * 100).round() + 4;
        String? punchRec;
        if (colData.hasConnectedBeams) {
          punchRec = null;
        } else if (punchingUtil > 1.0) {
          punchRec = 'Риск от пробиване на плочата при $colName (v_Ed = ${vedMpa.toStringAsFixed(2)} MPa > v_Rd,c = ${vrdcMpa.toStringAsFixed(2)} MPa). Препоръчва се капител (drop panel), плоча $recSlabH cm или по-голяма колона.';
        }

        allColumnChecks.add(ColumnVerticalCheck(
          columnId: col.id,
          columnName: colName,
          storeyId: storey.id,
          storeyName: storey.name,
          storeyIndex: originalIndices[storey.id]!,
          numStoreysAbove: storeysAbove,
          center: col.center,
          shape: col.shape,
          widthM: colWM,
          heightM: colHM,
          crossSectionAreaM2: colData.acM2,
          tributaryAreaM2: colData.aTribM2,
          accumulatedLoadNedKn: accumulatedNedKn,
          floorShearForceVedKn: colData.floorShearKn,
          axialCapacityNrdKn: nrdKn,
          axialUtilization: axialUtil,
          punchingShearStressVedMpa: vedMpa,
          punchingShearResistanceVrdMpa: vrdcMpa,
          punchingUtilization: punchingUtil,
          status: status,
          minRequiredSectionCm: minSectionStr,
          architectRecommendation: rec,
          punchingRecommendation: punchRec,
          hasConnectedBeams: colData.hasConnectedBeams,
          recommendedPunchingSlabThicknessCm: recSlabH,
        ));
      }
    }

    // Average foundation soil pressure sigma_base = N_total / A_footprint (kPa)
    final double basePressureKpa = totalFootprintAreaM2 > 0
        ? (totalAccumulatedBaseLoadKn / totalFootprintAreaM2)
        : 0.0;

    final int slabIssuesCount = allSlabChecks.where((s) => !s.isDeflectionSafe).length;
    final VerticalCapacityStatus overallStatus;
    if (criticalCount > 0 || allSlabChecks.any((s) => !s.isDeflectionSafe && s.deflectionRatio >= 1.25)) {
      overallStatus = VerticalCapacityStatus.critical;
    } else if (warningCount > 0 || slabIssuesCount > 0) {
      overallStatus = VerticalCapacityStatus.warning;
    } else {
      overallStatus = VerticalCapacityStatus.safe;
    }

    return VerticalCapacityReport(
      totalVerticalLoadBaseKn: totalAccumulatedBaseLoadKn,
      basePressureKpa: basePressureKpa,
      footprintAreaM2: totalFootprintAreaM2,
      columnChecks: allColumnChecks,
      slabChecks: allSlabChecks,
      criticalColumnsCount: criticalCount,
      warningColumnsCount: warningCount,
      punchingRiskCount: punchingRiskCount,
      maxAxialUtilization: maxAxialUtil,
      maxPunchingUtilization: maxPunchingUtil,
      overallStatus: overallStatus,
    );
  }
}
