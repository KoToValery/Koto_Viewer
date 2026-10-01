import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/structural_element.dart';
import 'deflection_calculator.dart';

/// Geometry detector that scans structural storeys for cantilever overhangs,
/// corner double cantilevers, and stacked transfer columns.
class CantileverDetector {
  const CantileverDetector._();

  /// Calculates the shortest distance from point [p] to line segment [a]-[b].
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final double abX = b.dx - a.dx;
    final double abY = b.dy - a.dy;
    final double lenSq = abX * abX + abY * abY;
    if (lenSq < 1e-9) {
      return (p - a).distance;
    }
    final double t =
        (((p.dx - a.dx) * abX + (p.dy - a.dy) * abY) / lenSq).clamp(0.0, 1.0);
    final Offset proj = Offset(a.dx + t * abX, a.dy + t * abY);
    return (p - proj).distance;
  }

  /// Finds the closest support center to a given point [p].
  static (Offset, double)? findClosestSupport(
    Offset p,
    List<StructuralColumn> columns,
    List<StructuralShearWall> walls,
  ) {
    double minDist = double.infinity;
    Offset? closest;

    for (final col in columns) {
      final d = (p - col.center).distance;
      if (d < minDist) {
        minDist = d;
        closest = col.center;
      }
    }

    for (final wall in walls) {
      final d = distanceToSegment(p, wall.start, wall.end);
      if (d < minDist) {
        minDist = d;
        // Project onto segment
        final abX = wall.end.dx - wall.start.dx;
        final abY = wall.end.dy - wall.start.dy;
        final lenSq = abX * abX + abY * abY;
        if (lenSq > 1e-9) {
          final t = (((p.dx - wall.start.dx) * abX +
                      (p.dy - wall.start.dy) * abY) /
                  lenSq)
              .clamp(0.0, 1.0);
          closest = Offset(wall.start.dx + t * abX, wall.start.dy + t * abY);
        } else {
          closest = wall.start;
        }
      }
    }

    if (closest == null) return null;
    return (closest, minDist);
  }

  /// Scans the entire project and returns a comprehensive cantilever analysis report.
  static StructuralAnalysisSummary analyzeProject(
    StructuralProject project, {
    double cadUnitsPerMeter = 1.0,
  }) {
    final List<CantileverZone> allZones = [];

    for (int sIdx = 0; sIdx < project.storeys.length; sIdx++) {
      final storey = project.storeys[sIdx];
      final StoreyLevel? lowerStorey =
          sIdx > 0 ? project.storeys[sIdx - 1] : null;

      allZones.addAll(analyzeStorey(
        storey: storey,
        lowerStorey: lowerStorey,
        cadUnitsPerMeter: cadUnitsPerMeter,
        concreteE: project.concreteE,
        deadLoad: project.deadLoadSuperimposed,
        liveLoad: project.liveLoad,
        facadeLoad: project.facadeWallLoad,
      ));
    }

    int cornerCount = 0;
    int transferCount = 0;
    int criticalCount = 0;
    int warningCount = 0;
    double maxDeflection = 0.0;
    double maxRatio = 0.0;

    for (final z in allZones) {
      if (z.isCorner) cornerCount++;
      if (z.isTransfer) transferCount++;
      if (z.riskLevel == CantileverRiskLevel.critical) criticalCount++;
      if (z.riskLevel == CantileverRiskLevel.warning) warningCount++;
      if (z.longTermDeflectionMm > maxDeflection) {
        maxDeflection = z.longTermDeflectionMm;
      }
      if (z.deflectionRatio > maxRatio) {
        maxRatio = z.deflectionRatio;
      }
    }

    return StructuralAnalysisSummary(
      totalCantilevers: allZones.length,
      cornerCantilevers: cornerCount,
      transferCantilevers: transferCount,
      criticalCount: criticalCount,
      warningCount: warningCount,
      maxDeflectionMm: maxDeflection,
      maxDeflectionRatio: maxRatio,
      zones: allZones,
    );
  }

  /// Analyzes a single storey for linear cantilevers, double corner cantilevers,
  /// and transfer stacked columns.
  static List<CantileverZone> analyzeStorey({
    required StoreyLevel storey,
    StoreyLevel? lowerStorey,
    double cadUnitsPerMeter = 1.0,
    double concreteE = 31000.0,
    double deadLoad = 1.5,
    double liveLoad = 2.0,
    double facadeLoad = 3.5,
  }) {
    final List<CantileverZone> results = [];
    if (storey.slabs.isEmpty) return results;

    final double scaleToM = 1.0 / math.max(cadUnitsPerMeter, 1e-4);

    // Minimum distance from column center to edge to be classified as cantilever
    const double minCantileverM = 0.60;

    int zoneCounter = 1;

    for (final slab in storey.slabs) {
      final poly = slab.polygon;
      if (poly.length < 3) continue;

      // Check each vertex of the slab polygon
      for (int i = 0; i < poly.length; i++) {
        final pt = poly[i];
        final prevPt = poly[(i - 1 + poly.length) % poly.length];
        final nextPt = poly[(i + 1) % poly.length];

        final supportInfo =
            findClosestSupport(pt, storey.columns, storey.shearWalls);
        if (supportInfo == null) continue;

        final closestSupport = supportInfo.$1;
        final dist = supportInfo.$2;
        final distM = dist * scaleToM;

        if (distM >= minCantileverM) {
          // Check if it's a corner vertex or an edge
          final v1 = (prevPt - pt);
          final v2 = (nextPt - pt);
          final l1 = v1.distance;
          final l2 = v2.distance;
          final l1M = l1 * scaleToM;
          final l2M = l2 * scaleToM;

          // Check for Corner Biaxial Cantilever:
          // Corner occurs when the polygon has a vertex (angle not flat)
          // and the vertex hangs in both orthogonal directions (dx and dy) from the closest column
          final double dot = (l1 > 1e-4 && l2 > 1e-4)
              ? (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2)
              : 0.0;
          final bool isGeometricCorner = dot.abs() <= 0.85;

          final double dx = (pt.dx - closestSupport.dx).abs();
          final double dy = (pt.dy - closestSupport.dy).abs();
          final double dxM = dx * scaleToM;
          final double dyM = dy * scaleToM;

          final bool isCornerVertex = isGeometricCorner &&
              (dxM >= 0.40 && dyM >= 0.40) &&
              (l1M > 0.5 && l2M > 0.5);

          if (isCornerVertex) {
            // Found a double corner cantilever!
            final zone = DeflectionCalculator.evaluateCantilever(
              id: '${storey.id}_corner_${zoneCounter++}',
              type: CantileverType.cornerBiaxial,
              storeyName: storey.name,
              supportEdgeStart: closestSupport,
              supportEdgeEnd: closestSupport + Offset(dx, 0),
              overhangTip: pt,
              length: dxM,
              lengthY: dyM,
              slabThickness: slab.thickness,
              concreteE: concreteE,
              superimposedDeadLoad: deadLoad,
              liveLoad: liveLoad,
              facadeLoad: facadeLoad,
            );
            results.add(zone);
          } else if (distM >= 0.80) {
            // Linear 1-way cantilever
            // Ensure we don't duplicate adjacent points of same overhang
            final bool alreadyRecorded = results.any(
                (r) => !r.isCorner && (r.overhangTip - pt).distance * scaleToM < 1.2);
            if (!alreadyRecorded) {
              final zone = DeflectionCalculator.evaluateCantilever(
                id: '${storey.id}_linear_${zoneCounter++}',
                type: CantileverType.linear,
                storeyName: storey.name,
                supportEdgeStart: closestSupport,
                supportEdgeEnd: closestSupport,
                overhangTip: pt,
                length: distM,
                slabThickness: slab.thickness,
                concreteE: concreteE,
                superimposedDeadLoad: deadLoad,
                liveLoad: liveLoad,
                facadeLoad: facadeLoad,
              );
              results.add(zone);
            }
          }
        }
      }
    }

    // Stacked / Transfer column check against lower storey:
    if (lowerStorey != null && lowerStorey.slabs.isNotEmpty) {
      for (final col in storey.columns) {
        // Check if there is a column on the lower storey directly under this column
        final hasLowerColumn = lowerStorey.columns.any(
            (lc) => (lc.center - col.center).distance * scaleToM < 0.45);
        final hasLowerWall = lowerStorey.shearWalls.any(
            (lw) => distanceToSegment(col.center, lw.start, lw.end) * scaleToM < 0.35);

        if (!hasLowerColumn && !hasLowerWall) {
          // Column has NO direct vertical support underneath!
          // Check if it sits on the lower slab
          final lowerSlab = lowerStorey.slabs.firstWhere(
            (s) => s.containsPoint(col.center),
            orElse: () => const StructuralSlab(id: '', polygon: []),
          );

          if (lowerSlab.polygon.isNotEmpty) {
            // Check distance from closest support on the lower storey
            final lowerSupportInfo = findClosestSupport(
                col.center, lowerStorey.columns, lowerStorey.shearWalls);
            if (lowerSupportInfo != null && lowerSupportInfo.$2 * scaleToM >= 0.60) {
              // Stacked column on cantilever!
              // Estimate axial load transferred from upper floor (~150 kN typical)
              const double estimatedUpperLoadKn = 150.0;
              final zone = DeflectionCalculator.evaluateCantilever(
                id: '${storey.id}_transfer_${zoneCounter++}',
                type: CantileverType.transferStacked,
                storeyName: storey.name,
                supportEdgeStart: lowerSupportInfo.$1,
                supportEdgeEnd: lowerSupportInfo.$1,
                overhangTip: col.center,
                length: lowerSupportInfo.$2 * scaleToM,
                slabThickness: lowerSlab.thickness,
                concreteE: concreteE,
                superimposedDeadLoad: deadLoad,
                liveLoad: liveLoad,
                facadeLoad: facadeLoad,
                stackedColumnLoadKn: estimatedUpperLoadKn,
                stackedColumnId: col.id,
              );
              results.add(zone);
            }
          }
        }
      }
    }

    return results;
  }
}
