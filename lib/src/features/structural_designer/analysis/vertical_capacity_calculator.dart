import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';

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
  static ({double maxSpanM, (Offset, Offset)? criticalSpanSegment}) calculateClearSpan(
    StoreyLevel storey,
    double scale,
  ) {
    final List<({double spanM, (Offset, Offset) segment})> candidateSpans = [];

    // 1. Clear Spans along Beams (if beams exist)
    for (final beam in storey.beams) {
      final lenM = (beam.end - beam.start).distance / scale;
      if (lenM >= 0.5) {
        candidateSpans.add((spanM: lenM, segment: (beam.start, beam.end)));
      }
    }

    // 2. Clear Spans along Grid Axes (if columns lie on grid axes)
    for (final axis in storey.gridAxes) {
      final aVec = axis.end - axis.start;
      final aLen = aVec.distance;
      if (aLen < 1e-4) continue;
      final uAxis = aVec / aLen;
      final nAxis = Offset(-uAxis.dy, uAxis.dx);

      final colsOnAxis = <({StructuralColumn col, double t})>[];
      for (final col in storey.columns) {
        final distPerp = ((col.center - axis.start).dx * nAxis.dx +
                (col.center - axis.start).dy * nAxis.dy)
            .abs();
        if (distPerp <= 0.35 * scale) {
          final t = (col.center - axis.start).dx * uAxis.dx +
              (col.center - axis.start).dy * uAxis.dy;
          colsOnAxis.add((col: col, t: t));
        }
      }

      colsOnAxis.sort((a, b) => a.t.compareTo(b.t));

      for (int i = 0; i < colsOnAxis.length - 1; i++) {
        final distM = (colsOnAxis[i + 1].t - colsOnAxis[i].t) / scale;
        if (distM >= 1.0) {
          candidateSpans.add((
            spanM: distM,
            segment: (colsOnAxis[i].col.center, colsOnAxis[i + 1].col.center),
          ));
        }
      }
    }

    // 3. Spans between adjacent Column pairs (checking for intermediate supports & diagonals)
    final cols = storey.columns;
    for (int i = 0; i < cols.length; i++) {
      for (int j = i + 1; j < cols.length; j++) {
        final c1 = cols[i].center;
        final c2 = cols[j].center;
        final vec = c2 - c1;
        final len = vec.distance;
        final dM = len / scale;
        if (dM < 1.0 || dM > 16.0) continue;

        final u = vec / len;

        // Check if another column lies between c1 and c2 (eliminates false 8m, 12m spans across multiple bays)
        bool hasIntermediateSupport = false;
        for (int k = 0; k < cols.length; k++) {
          if (k == i || k == j) continue;
          final ck = cols[k].center;
          final t = (ck - c1).dx * u.dx + (ck - c1).dy * u.dy;
          if (t > 0.35 * scale && t < len - 0.35 * scale) {
            final perpDist = ((ck - c1).dx * (-u.dy) + (ck - c1).dy * u.dx).abs();
            if (perpDist <= 0.40 * scale) {
              hasIntermediateSupport = true;
              break;
            }
          }
        }
        if (hasIntermediateSupport) continue;

        // Check if a shear wall intersects or lies along segment c1-c2
        for (final wall in storey.shearWalls) {
          final mid = (wall.start + wall.end) / 2.0;
          final t = (mid - c1).dx * u.dx + (mid - c1).dy * u.dy;
          if (t > 0.35 * scale && t < len - 0.35 * scale) {
            final perpDist = ((mid - c1).dx * (-u.dy) + (mid - c1).dy * u.dx).abs();
            if (perpDist <= 0.40 * scale) {
              hasIntermediateSupport = true;
              break;
            }
          }
        }
        if (hasIntermediateSupport) continue;

        // Gabriel disc check: if any other column center is strictly inside the disc with diameter c1-c2,
        // then c1-c2 is not an adjacent span (eliminates knight's moves and multi-bay jumps)
        final midCol = (c1 + c2) / 2.0;
        final radiusCol = len / 2.0;
        final radiusLimit = math.max(0.0, radiusCol - 0.25 * scale);
        final radiusLimitSq = radiusLimit * radiusLimit;
        bool hasGabrielInterferer = false;
        for (int k = 0; k < cols.length; k++) {
          if (k == i || k == j) continue;
          final distSq = (cols[k].center - midCol).distanceSquared;
          if (distSq < radiusLimitSq) {
            hasGabrielInterferer = true;
            break;
          }
        }
        if (hasGabrielInterferer) continue;

        // Check if c1-c2 is a diagonal of an orthogonal 4-column bay
        bool isDiagonal = false;
        for (int k = 0; k < cols.length; k++) {
          if (k == i || k == j) continue;
          final ck = cols[k].center;
          final v1 = ck - c1;
          final v2 = c2 - ck;
          final d1 = v1.distance;
          final d2 = v2.distance;
          if (d1 > 0.8 * scale && d2 > 0.8 * scale && d1 < len - 0.2 * scale && d2 < len - 0.2 * scale) {
            final u1 = v1 / d1;
            final u2 = v2 / d2;
            final dot = (u1.dx * u2.dx + u1.dy * u2.dy).abs();
            if (dot < 0.35 && (math.sqrt(d1 * d1 + d2 * d2) - len).abs() < 0.20 * len) {
              isDiagonal = true;
              break;
            }
          }
        }
        if (isDiagonal) continue;

        candidateSpans.add((spanM: dM, segment: (c1, c2)));
      }
    }

    // 4. Also check distances from columns to adjacent shear walls
    for (final col in storey.columns) {
      for (final wall in storey.shearWalls) {
        final mid = (wall.start + wall.end) / 2.0;
        final dM = (col.center - mid).distance / scale;
        if (dM >= 1.0 && dM <= 12.0) {
          final vec = mid - col.center;
          final len = vec.distance;
          final u = vec / len;
          bool hasInter = false;
          for (final other in storey.columns) {
            if (other.id == col.id) continue;
            final t = (other.center - col.center).dx * u.dx + (other.center - col.center).dy * u.dy;
            if (t > 0.35 * scale && t < len - 0.35 * scale) {
              final perpDist = ((other.center - col.center).dx * (-u.dy) + (other.center - col.center).dy * u.dx).abs();
              if (perpDist <= 0.40 * scale) {
                hasInter = true;
                break;
              }
            }
          }
          if (!hasInter) {
            candidateSpans.add((spanM: dM, segment: (col.center, mid)));
          }
        }
      }
    }

    if (candidateSpans.isEmpty) {
      return (maxSpanM: 4.0, criticalSpanSegment: null);
    }

    // Find the critical (maximum) clear span
    var maxSpan = candidateSpans.first;
    for (final span in candidateSpans) {
      if (span.spanM > maxSpan.spanM) {
        maxSpan = span;
      }
    }

    return (maxSpanM: maxSpan.spanM, criticalSpanSegment: maxSpan.segment);
  }

  /// Calculates max clear span between supports in the storey (meters).
  static double calculateMaxSpanM(StoreyLevel storey, double scale) {
    return calculateClearSpan(storey, scale).maxSpanM;
  }

  /// Runs comprehensive Eurocode 2 vertical capacity analysis for the given project.
  static VerticalCapacityReport analyzeProject(
    StructuralProject project, {
    double cadUnitsPerMeter = 1.0,
  }) {
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

    // Calculate total footprint area from ground slab
    final groundStorey = project.storeys.first;
    double totalFootprintAreaM2 = 0.0;
    for (final s in groundStorey.slabs) {
      totalFootprintAreaM2 += s.netArea / (scale * scale);
    }
    if (totalFootprintAreaM2 <= 1.0 && groundStorey.columns.isNotEmpty) {
      // Estimate footprint from column envelope
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

    // 2. Analyze slab deflection for each storey
    for (int sIdx = 0; sIdx < numStoreys; sIdx++) {
      final storey = project.storeys[sIdx];
      final hCurrent = storeySlabThicknessM[sIdx];
      final spanRes = calculateClearSpan(storey, scale);
      final maxSpanM = spanRes.maxSpanM;
      final hasBeams = storey.beams.isNotEmpty;
      // Basic span-to-depth ratio L/d (EC2 Table 7.4N)
      final double basicRatio = hasBeams ? 28.0 : 22.0;
      final double dReqM = maxSpanM / basicRatio;
      final double hReqM = double.parse((dReqM + 0.03).toStringAsFixed(2)); // +30mm cover
      final bool isSafe = hCurrent >= (hReqM - 0.01);
      final double ratio = hReqM / (hCurrent > 0 ? hCurrent : 0.20);

      final String rec;
      if (!isSafe) {
        final reqCm = (hReqM * 100).round();
        final curCm = (hCurrent * 100).round();
        rec = hasBeams
            ? 'При отвор L = ${maxSpanM.toStringAsFixed(2)} m, дебелина $curCm cm е недостатъчна. Препоръчва се плоча минимум $reqCm cm.'
            : 'При светъл отвор L = ${maxSpanM.toStringAsFixed(2)} m без греди, плоча $curCm cm ще провисне недопустимо. Препоръчва се минимум $reqCm cm или главни греди 25x50 cm.';
      } else {
        rec = 'Дебелината на плочата (${(hCurrent * 100).round()} cm) е напълно достатъчна за светъл отвор L = ${maxSpanM.toStringAsFixed(2)} m.';
      }

      allSlabChecks.add(SlabDeflectionCheck(
        storeyId: storey.id,
        storeyName: storey.name,
        currentThicknessM: hCurrent,
        maxSpanM: maxSpanM,
        recommendedMinThicknessM: hReqM,
        isDeflectionSafe: isSafe,
        deflectionRatio: ratio,
        recommendation: rec,
        criticalSpanSegment: spanRes.criticalSpanSegment,
        hasBeams: hasBeams,
      ));
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
          storeyIndex: sIdx,
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
