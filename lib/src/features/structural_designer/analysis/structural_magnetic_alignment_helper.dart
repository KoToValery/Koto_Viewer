import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart';

/// Magnetic alignment result for columns.
class ColumnMagneticAlignmentResult {
  final Offset snappedCenter;
  final List<(Offset, Offset)> guideLines;
  final String description;
  final Offset? markerPoint;
  final String? liveDimensionText;
  final (Offset, Offset)? dimensionLine;

  const ColumnMagneticAlignmentResult({
    required this.snappedCenter,
    required this.guideLines,
    required this.description,
    this.markerPoint,
    this.liveDimensionText,
    this.dimensionLine,
  });
}

/// Magnetic alignment result for shear walls.
class ShearWallMagneticAlignmentResult {
  final Offset snappedCenter;
  final double? snappedRotationRad;
  final List<(Offset, Offset)> guideLines;
  final String description;
  final Offset? markerPoint;
  final String? liveDimensionText;
  final (Offset, Offset)? dimensionLine;

  const ShearWallMagneticAlignmentResult({
    required this.snappedCenter,
    this.snappedRotationRad,
    required this.guideLines,
    required this.description,
    this.markerPoint,
    this.liveDimensionText,
    this.dimensionLine,
  });
}

/// Magnetic alignment result for beams.
class BeamMagneticAlignmentResult {
  final Offset snappedPoint;
  final List<(Offset, Offset)> guideLines;
  final String description;
  final Offset? markerPoint;

  const BeamMagneticAlignmentResult({
    required this.snappedPoint,
    required this.guideLines,
    required this.description,
    this.markerPoint,
  });
}

/// Direction constraint mode for element movement / placement.
enum StructuralAxisLockMode {
  /// Free 2-DOF magnetic snapping (both X and Y are active).
  autoMode,

  /// Movement is constrained vertically; X coordinate remains fixed.
  lockX,

  /// Movement is constrained horizontally; Y coordinate remains fixed.
  lockY,
}

/// Face-to-face clear distance to an adjacent structural element.
class NeighborClearDistance {
  final String direction; // 'left', 'right', 'top', 'bottom'
  final String neighborName;
  final double currentClearDistanceM;
  final Offset neighborFacePoint;
  final Offset ourFacePoint;
  final bool isHorizontal;
  final double sign; // +1.0 or -1.0

  const NeighborClearDistance({
    required this.direction,
    required this.neighborName,
    required this.currentClearDistanceM,
    required this.neighborFacePoint,
    required this.ourFacePoint,
    required this.isHorizontal,
    required this.sign,
  });

  /// Computes the delta offset (in CAD units) that must be added to current element center
  /// so that the face-to-face clear distance becomes [targetClearDistanceM].
  Offset computeDeltaCad({
    required double targetClearDistanceM,
    required double cadUnitsPerMeter,
  }) {
    final double diffM = targetClearDistanceM - currentClearDistanceM;
    final double diffCad = diffM * cadUnitsPerMeter;
    if (isHorizontal) {
      return Offset(sign * diffCad, 0.0);
    } else {
      return Offset(0.0, sign * diffCad);
    }
  }
}

/// Helper for magnetic parallel and axial alignment (магнитно прилепване)
/// for columns, shear walls, and beams, replacing point-snapping with ArchiCAD-style guidelines.
class StructuralMagneticAlignmentHelper {
  const StructuralMagneticAlignmentHelper._();

  static List<({Offset offset, String name})> _getColumnAnchors({
    required double width,
    required double height,
    required double rotationRad,
    required double cadUnitsPerMeter,
  }) {
    final halfW = width / 2.0;
    final halfH = height / 2.0;
    final cosA = math.cos(rotationRad);
    final sinA = math.sin(rotationRad);

    Offset rotate(double lx, double ly) {
      return Offset(
        lx * cosA - ly * sinA,
        lx * sinA + ly * cosA,
      );
    }

    final anchors = <({Offset offset, String name})>[];
    // 1. Geometric Center
    anchors.add((offset: Offset.zero, name: 'center'));

    // 2. Modular 12.5 cm Wall-Axis Nodes (Center of 25cm masonry wall modules)
    final mod12_5 = 0.125 * cadUnitsPerMeter;
    final mod25 = 0.25 * cadUnitsPerMeter;

    if (height >= width && height >= mod25) {
      final y1 = -halfH + mod12_5;
      final y2 = halfH - mod12_5;
      anchors.add((offset: rotate(0, y1), name: 'wallModuleStart'));
      anchors.add((offset: rotate(0, y2), name: 'wallModuleEnd'));

      double currY = y1 + mod25;
      while (currY < y2 - mod12_5 * 0.5) {
        anchors.add((offset: rotate(0, currY), name: 'wallModuleMid'));
        currY += mod25;
      }
    } else if (width > height && width >= mod25) {
      final x1 = -halfW + mod12_5;
      final x2 = halfW - mod12_5;
      anchors.add((offset: rotate(x1, 0), name: 'wallModuleStart'));
      anchors.add((offset: rotate(x2, 0), name: 'wallModuleEnd'));

      double currX = x1 + mod25;
      while (currX < x2 - mod12_5 * 0.5) {
        anchors.add((offset: rotate(currX, 0), name: 'wallModuleMid'));
        currX += mod25;
      }
    }

    // 3. Edge midpoints and corners (for flush outer face / property line alignment)
    anchors.add((offset: rotate(0, -halfH), name: 'edgeBottom'));
    anchors.add((offset: rotate(0, halfH), name: 'edgeTop'));
    anchors.add((offset: rotate(-halfW, 0), name: 'edgeLeft'));
    anchors.add((offset: rotate(halfW, 0), name: 'edgeRight'));

    anchors.add((offset: rotate(-halfW, -halfH), name: 'cornerBL'));
    anchors.add((offset: rotate(halfW, -halfH), name: 'cornerBR'));
    anchors.add((offset: rotate(halfW, halfH), name: 'cornerTR'));
    anchors.add((offset: rotate(-halfW, halfH), name: 'cornerTL'));

    return anchors;
  }

  /// Extracts architectural and structural reference segments (outer wall faces, closure lines,
  /// opening corridors, column faces, and CAD polylines/lines) for magnetic edge-to-edge alignment.
  static List<({Offset p1, Offset p2, String source, double thickness})> _extractReferenceSegments({
    required StoreyLevel activeStorey,
    DxfDocument? dxfDocument,
    double cadUnitsPerMeter = 1.0,
    String? excludeWallId,
    String? excludeColumnId,
  }) {
    final segments = <({Offset p1, Offset p2, String source, double thickness})>[];

    // 1. Existing Shear Walls: Faces and End Caps (closure lines)
    for (final wall in activeStorey.shearWalls) {
      if (excludeWallId != null && wall.id == excludeWallId) continue;
      final segVec = wall.end - wall.start;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);
      final halfL = wall.length / 2.0;
      final halfT = wall.thickness / 2.0;
      final c = wall.center;

      // Start Cap (transverse closure line next to opening/end)
      segments.add((p1: c - u * halfL - n * halfT, p2: c - u * halfL + n * halfT, source: 'wallCap', thickness: wall.thickness));
      // End Cap (transverse closure line next to opening/end)
      segments.add((p1: c + u * halfL - n * halfT, p2: c + u * halfL + n * halfT, source: 'wallCap', thickness: wall.thickness));
      // Outer Faces (left and right)
      segments.add((p1: c - n * halfT - u * halfL, p2: c - n * halfT + u * halfL, source: 'wallFace', thickness: wall.thickness));
      segments.add((p1: c + n * halfT - u * halfL, p2: c + n * halfT + u * halfL, source: 'wallFace', thickness: wall.thickness));
      // Centerline
      segments.add((p1: wall.start, p2: wall.end, source: 'wallCenterline', thickness: wall.thickness));
    }

    // 2. Slab Openings (shafts, staircases, elevators, custom openings)
    for (final slab in activeStorey.slabs) {
      for (final op in slab.openings) {
        final poly = op;
        final nPts = poly.length;
        if (nPts < 2) continue;
        for (int i = 0; i < nPts; i++) {
          final p1 = poly[i];
          final p2 = poly[(i + 1) % nPts];
          if ((p2 - p1).distance >= 0.04 * cadUnitsPerMeter) {
            segments.add((p1: p1, p2: p2, source: 'openingEdge', thickness: 0.0));
          }
        }
      }
    }

    // 3. Existing Columns (outer perimeter faces)
    for (final col in activeStorey.columns) {
      if (excludeColumnId != null && col.id == excludeColumnId) continue;
      final poly = col.polygonVertices;
      final nPts = poly.length;
      if (nPts >= 3) {
        for (int i = 0; i < nPts; i++) {
          final p1 = poly[i];
          final p2 = poly[(i + 1) % nPts];
          segments.add((p1: p1, p2: p2, source: 'columnFace', thickness: 0.0));
        }
      }
    }

    // 4. DXF Underlay (Lines, LwPolylines, Polylines)
    if (dxfDocument != null) {
      for (final entity in dxfDocument.entities) {
        final layer = dxfDocument.layers[entity.layer];
        if (layer != null && !layer.isVisible) continue;

        if (entity is DxfLine) {
          final len = (entity.p2 - entity.p1).distance;
          if (len >= 0.04 * cadUnitsPerMeter) {
            segments.add((p1: entity.p1, p2: entity.p2, source: 'dxfLine', thickness: 0.0));
          }
        } else if (entity is DxfLwPolyline) {
          final v = entity.vertices;
          for (int i = 0; i < v.length - 1; i++) {
            final p1 = v[i].offset;
            final p2 = v[i + 1].offset;
            if ((p2 - p1).distance >= 0.04 * cadUnitsPerMeter) {
              segments.add((p1: p1, p2: p2, source: 'dxfPolyline', thickness: 0.0));
            }
          }
          if (entity.isClosed && v.length > 2) {
            final p1 = v.last.offset;
            final p2 = v.first.offset;
            if ((p2 - p1).distance >= 0.04 * cadUnitsPerMeter) {
              segments.add((p1: p1, p2: p2, source: 'dxfPolyline', thickness: 0.0));
            }
          }
        } else if (entity is DxfPolyline) {
          final v = entity.vertices;
          for (int i = 0; i < v.length - 1; i++) {
            final p1 = v[i].offset;
            final p2 = v[i + 1].offset;
            if ((p2 - p1).distance >= 0.04 * cadUnitsPerMeter) {
              segments.add((p1: p1, p2: p2, source: 'dxfPolyline', thickness: 0.0));
            }
          }
          if (entity.isClosed && v.length > 2) {
            final p1 = v.last.offset;
            final p2 = v.first.offset;
            if ((p2 - p1).distance >= 0.04 * cadUnitsPerMeter) {
              segments.add((p1: p1, p2: p2, source: 'dxfPolyline', thickness: 0.0));
            }
          }
        }
      }
    }

    return segments;
  }

  /// Discovers adjacent columns and shear walls along the horizontal and vertical corridors
  /// and calculates exact face-to-face clear distances (светли размери).
  static List<NeighborClearDistance> findNeighborClearDistances({
    required Offset center,
    required double width,
    required double height,
    required StoreyLevel activeStorey,
    String? currentElementId,
    double cadUnitsPerMeter = 1.0,
  }) {
    final results = <NeighborClearDistance>[];

    // Collect candidate neighbor elements
    final candidates = <({String name, Offset center, double w, double h})>[];
    for (final col in activeStorey.columns) {
      if (currentElementId != null && col.id == currentElementId) continue;
      candidates.add((
        name: col.displayName.isNotEmpty ? col.displayName : 'К',
        center: col.center,
        w: col.width,
        h: col.height,
      ));
    }
    for (final wall in activeStorey.shearWalls) {
      if (currentElementId != null && wall.id == currentElementId) continue;
      final dx = (wall.end.dx - wall.start.dx).abs();
      final dy = (wall.end.dy - wall.start.dy).abs();
      final sinA = math.sin(wall.angleRad).abs();
      final cosA = math.cos(wall.angleRad).abs();
      final bboxW = dx + wall.thickness * sinA;
      final bboxH = dy + wall.thickness * cosA;
      candidates.add((
        name: wall.displayName.isNotEmpty ? wall.displayName : 'Ш',
        center: wall.center,
        w: bboxW,
        h: bboxH,
      ));
    }

    final corridorXMargin = math.max(height, 0.4 * cadUnitsPerMeter) * 1.5;
    final corridorYMargin = math.max(width, 0.4 * cadUnitsPerMeter) * 1.5;

    // 1. Horizontal Corridor (Left & Right)
    ({String name, Offset center, double w, double h})? nearestLeft;
    double maxLeftX = -double.infinity;
    ({String name, Offset center, double w, double h})? nearestRight;
    double minRightX = double.infinity;

    for (final cand in candidates) {
      final dY = (cand.center.dy - center.dy).abs();
      if (dY <= corridorXMargin) {
        if (cand.center.dx < center.dx) {
          if (cand.center.dx > maxLeftX) {
            maxLeftX = cand.center.dx;
            nearestLeft = cand;
          }
        } else if (cand.center.dx > center.dx) {
          if (cand.center.dx < minRightX) {
            minRightX = cand.center.dx;
            nearestRight = cand;
          }
        }
      }
    }

    if (nearestLeft != null) {
      final faceOurLeft = center.dx - width / 2.0;
      final faceNeighborRight = nearestLeft.center.dx + nearestLeft.w / 2.0;
      final clearDistCad = faceOurLeft - faceNeighborRight;
      if (clearDistCad > 0.01 * cadUnitsPerMeter) {
        results.add(NeighborClearDistance(
          direction: 'left',
          neighborName: nearestLeft.name,
          currentClearDistanceM: clearDistCad / cadUnitsPerMeter,
          neighborFacePoint: Offset(faceNeighborRight, center.dy),
          ourFacePoint: Offset(faceOurLeft, center.dy),
          isHorizontal: true,
          sign: 1.0,
        ));
      }
    }

    if (nearestRight != null) {
      final faceOurRight = center.dx + width / 2.0;
      final faceNeighborLeft = nearestRight.center.dx - nearestRight.w / 2.0;
      final clearDistCad = faceNeighborLeft - faceOurRight;
      if (clearDistCad > 0.01 * cadUnitsPerMeter) {
        results.add(NeighborClearDistance(
          direction: 'right',
          neighborName: nearestRight.name,
          currentClearDistanceM: clearDistCad / cadUnitsPerMeter,
          neighborFacePoint: Offset(faceNeighborLeft, center.dy),
          ourFacePoint: Offset(faceOurRight, center.dy),
          isHorizontal: true,
          sign: -1.0,
        ));
      }
    }

    // 2. Vertical Corridor (Bottom & Top)
    ({String name, Offset center, double w, double h})? nearestBottom;
    double maxBottomY = -double.infinity;
    ({String name, Offset center, double w, double h})? nearestTop;
    double minTopY = double.infinity;

    for (final cand in candidates) {
      final dX = (cand.center.dx - center.dx).abs();
      if (dX <= corridorYMargin) {
        if (cand.center.dy < center.dy) {
          if (cand.center.dy > maxBottomY) {
            maxBottomY = cand.center.dy;
            nearestBottom = cand;
          }
        } else if (cand.center.dy > center.dy) {
          if (cand.center.dy < minTopY) {
            minTopY = cand.center.dy;
            nearestTop = cand;
          }
        }
      }
    }

    if (nearestBottom != null) {
      final faceOurBottom = center.dy - height / 2.0;
      final faceNeighborTop = nearestBottom.center.dy + nearestBottom.h / 2.0;
      final clearDistCad = faceOurBottom - faceNeighborTop;
      if (clearDistCad > 0.01 * cadUnitsPerMeter) {
        results.add(NeighborClearDistance(
          direction: 'bottom',
          neighborName: nearestBottom.name,
          currentClearDistanceM: clearDistCad / cadUnitsPerMeter,
          neighborFacePoint: Offset(center.dx, faceNeighborTop),
          ourFacePoint: Offset(center.dx, faceOurBottom),
          isHorizontal: false,
          sign: 1.0,
        ));
      }
    }

    if (nearestTop != null) {
      final faceOurTop = center.dy + height / 2.0;
      final faceNeighborBottom = nearestTop.center.dy - nearestTop.h / 2.0;
      final clearDistCad = faceNeighborBottom - faceOurTop;
      if (clearDistCad > 0.01 * cadUnitsPerMeter) {
        results.add(NeighborClearDistance(
          direction: 'top',
          neighborName: nearestTop.name,
          currentClearDistanceM: clearDistCad / cadUnitsPerMeter,
          neighborFacePoint: Offset(center.dx, faceNeighborBottom),
          ourFacePoint: Offset(center.dx, faceOurTop),
          isHorizontal: false,
          sign: -1.0,
        ));
      }
    }

    return results;
  }

  /// Aligns a column center to structural grid axes, other column coordinates (X/Y),
  /// shear walls, beams, or DXF underlay lines.
  static ColumnMagneticAlignmentResult? alignColumn({
    required Offset rawCenter,
    double columnWidth = 0.25,
    double columnHeight = 0.25,
    double columnRotationRad = 0.0,
    required double toleranceCad,
    required StoreyLevel activeStorey,
    String? movingColumnId,
    DxfDocument? dxfDocument,
    double cadUnitsPerMeter = 1.0,
    StructuralAxisLockMode axisLockMode = StructuralAxisLockMode.autoMode,
    Offset? anchorCenter,
    Offset? previousSnappedCenter,
    double? maxCorrectionCad,
  }) {
    // 0. Handle Axis Constraint Mode
    Offset effectiveRawCenter = rawCenter;
    if (axisLockMode == StructuralAxisLockMode.lockX && anchorCenter != null) {
      effectiveRawCenter = Offset(anchorCenter.dx, effectiveRawCenter.dy);
    } else if (axisLockMode == StructuralAxisLockMode.lockY && anchorCenter != null) {
      effectiveRawCenter = Offset(effectiveRawCenter.dx, anchorCenter.dy);
    }

    // 0b. Hysteresis tolerance window (sticky snap)
    double effectiveTol = toleranceCad;
    if (maxCorrectionCad == null && previousSnappedCenter != null &&
        (effectiveRawCenter - previousSnappedCenter).distance <= toleranceCad * 1.35) {
      effectiveTol = toleranceCad * 1.35;
    }

    ColumnMagneticAlignmentResult? wrapResult(ColumnMagneticAlignmentResult res) {
      if (maxCorrectionCad != null && (res.snappedCenter-effectiveRawCenter).distance > maxCorrectionCad+1e-8) return null;
      if (axisLockMode == StructuralAxisLockMode.lockX && anchorCenter != null) {
        return ColumnMagneticAlignmentResult(
          snappedCenter: Offset(anchorCenter.dx, res.snappedCenter.dy),
          guideLines: res.guideLines,
          description: res.description,
          markerPoint: res.markerPoint != null ? Offset(anchorCenter.dx, res.markerPoint!.dy) : null,
          liveDimensionText: res.liveDimensionText,
          dimensionLine: res.dimensionLine,
        );
      } else if (axisLockMode == StructuralAxisLockMode.lockY && anchorCenter != null) {
        return ColumnMagneticAlignmentResult(
          snappedCenter: Offset(res.snappedCenter.dx, anchorCenter.dy),
          guideLines: res.guideLines,
          description: res.description,
          markerPoint: res.markerPoint != null ? Offset(res.markerPoint!.dx, anchorCenter.dy) : null,
          liveDimensionText: res.liveDimensionText,
          dimensionLine: res.dimensionLine,
        );
      }
      return res;
    }

    final axes = activeStorey.gridAxes;
    final anchors = _getColumnAnchors(
      width: columnWidth,
      height: columnHeight,
      rotationRad: columnRotationRad,
      cadUnitsPerMeter: cadUnitsPerMeter,
    );

    // 1. Grid Axes Intersections (Highest priority: column center or 12.5 cm wall module on intersection)
    double bestInterDist = double.infinity;
    Offset? bestSnappedCenter;
    Offset? bestInterPoint;
    (StructuralGridAxis, StructuralGridAxis)? bestAxes;

    for (int i = 0; i < axes.length; i++) {
      for (int j = i + 1; j < axes.length; j++) {
        final inter = axes[i].intersectionWith(axes[j]);
        if (inter == null) continue;

        // Pass 1: Geometric center and 12.5 cm modular nodes have highest priority
        for (final anchor in anchors) {
          final isPrimary = anchor.name == 'center' || anchor.name.startsWith('wallModule');
          if (!isPrimary) continue;
          final anchorWorld = effectiveRawCenter + anchor.offset;
          final d = (anchorWorld - inter).distance;
          if (d <= effectiveTol * 1.5 && d < bestInterDist) {
            bestInterDist = d;
            bestSnappedCenter = inter - anchor.offset;
            bestInterPoint = inter;
            bestAxes = (axes[i], axes[j]);
          }
        }

        // Pass 2: Secondary anchors (edges and corners for flush outer face alignment)
        if (bestSnappedCenter == null) {
          for (final anchor in anchors) {
            final isPrimary = anchor.name == 'center' || anchor.name.startsWith('wallModule');
            if (isPrimary) continue;
            final anchorWorld = effectiveRawCenter + anchor.offset;
            final d = (anchorWorld - inter).distance;
            if (d <= effectiveTol * 0.7 && d < bestInterDist) {
              bestInterDist = d;
              bestSnappedCenter = inter - anchor.offset;
              bestInterPoint = inter;
              bestAxes = (axes[i], axes[j]);
            }
          }
        }
      }
    }

    if (bestSnappedCenter != null && bestAxes != null) {
      return wrapResult(ColumnMagneticAlignmentResult(
        snappedCenter: bestSnappedCenter,
        guideLines: [
          (bestAxes.$1.start, bestAxes.$1.end),
          (bestAxes.$2.start, bestAxes.$2.end),
        ],
        description: 'gridIntersection',
        markerPoint: bestInterPoint,
      ));
    }

    // 2. Single Grid Axis line alignment (column anchor locks to axis line + 2-DOF cross-alignment)
    for (final axis in axes) {
      final aVec = axis.end - axis.start;
      final aLen = aVec.distance;
      if (aLen < 1e-4) continue;
      final uAxis = aVec / aLen;
      final nAxis = Offset(-uAxis.dy, uAxis.dx);

      double bestPerpDist = double.infinity;
      ({Offset offset, String name})? bestAnchor;

      for (final anchor in anchors) {
        final anchorWorld = effectiveRawCenter + anchor.offset;
        final distPerp = (anchorWorld - axis.start).dx * nAxis.dx +
            (anchorWorld - axis.start).dy * nAxis.dy;
        if (distPerp.abs() <= effectiveTol && distPerp.abs() < bestPerpDist.abs()) {
          bestPerpDist = distPerp;
          bestAnchor = anchor;
        }
      }

      if (bestAnchor != null) {
        final baseCenterOnAxis = effectiveRawCenter - nAxis * bestPerpDist;

        // --- 2-DOF Cross-Axis & Element Alignment along the axis ---
        // 2a. Check if any other Column aligns perpendicularly across the axis
        Offset? crossColAlignPt;
        Offset? crossColSourcePt;
        double minCrossColDist = double.infinity;
        for (final otherCol in activeStorey.columns) {
          if (movingColumnId != null && otherCol.id == movingColumnId) continue;
          final proj = axis.projectPoint(otherCol.center);
          final dPerpCol = (otherCol.center - proj).distance;
          if (dPerpCol > 0.15 * cadUnitsPerMeter) {
            final dAlong = (baseCenterOnAxis - proj).distance;
            if (dAlong <= effectiveTol && dAlong < minCrossColDist) {
              minCrossColDist = dAlong;
              crossColAlignPt = proj;
              crossColSourcePt = otherCol.center;
            }
          }
        }

        // 2b. Check if any Shear Wall center aligns perpendicularly across the axis
        Offset? crossWallAlignPt;
        Offset? crossWallSourcePt;
        double minCrossWallDist = double.infinity;
        for (final wall in activeStorey.shearWalls) {
          final proj = axis.projectPoint(wall.center);
          final dPerpWall = (wall.center - proj).distance;
          if (dPerpWall > 0.15 * cadUnitsPerMeter) {
            final dAlong = (baseCenterOnAxis - proj).distance;
            if (dAlong <= effectiveTol && dAlong < minCrossWallDist) {
              minCrossWallDist = dAlong;
              crossWallAlignPt = proj;
              crossWallSourcePt = wall.center;
            }
          }
        }

        if (crossColAlignPt != null && crossColSourcePt != null) {
          final finalCenter = crossColAlignPt - bestAnchor.offset;
          return wrapResult(ColumnMagneticAlignmentResult(
            snappedCenter: finalCenter,
            guideLines: [
              (axis.start, axis.end),
              (crossColSourcePt, crossColAlignPt),
            ],
            description: 'gridAxisAndColumn',
            markerPoint: crossColAlignPt,
          ));
        }

        if (crossWallAlignPt != null && crossWallSourcePt != null) {
          final finalCenter = crossWallAlignPt - bestAnchor.offset;
          return wrapResult(ColumnMagneticAlignmentResult(
            snappedCenter: finalCenter,
            guideLines: [
              (axis.start, axis.end),
              (crossWallSourcePt, crossWallAlignPt),
            ],
            description: 'gridAxisAndWall',
            markerPoint: crossWallAlignPt,
          ));
        }

        // Obstacles along axis direction to compute distance and 5 cm snap
        final obstacles = <Offset>[];

        for (final otherCol in activeStorey.columns) {
          if (movingColumnId != null && otherCol.id == movingColumnId) continue;
          final proj = axis.projectPoint(otherCol.center);
          if ((otherCol.center - proj).distance <= 1.5 * cadUnitsPerMeter) {
            obstacles.add(proj);
          }
        }

        for (final wall in activeStorey.shearWalls) {
          final p1 = axis.projectPoint(wall.start);
          final p2 = axis.projectPoint(wall.end);
          if ((wall.start - p1).distance <= 1.5 * cadUnitsPerMeter) obstacles.add(p1);
          if ((wall.end - p2).distance <= 1.5 * cadUnitsPerMeter) obstacles.add(p2);
          final pCenter = axis.projectPoint(wall.center);
          if ((wall.center - pCenter).distance <= 1.5 * cadUnitsPerMeter) obstacles.add(pCenter);
        }

        for (final otherAxis in axes) {
          if (otherAxis.id == axis.id) continue;
          final inter = axis.intersectionWith(otherAxis);
          if (inter != null) {
            obstacles.add(inter);
          }
        }

        Offset? closestObstacle;
        double minObstacleDist = double.infinity;
        for (final obs in obstacles) {
          final dist = (baseCenterOnAxis - obs).distance;
          if (dist > 1e-3 && dist < minObstacleDist) {
            minObstacleDist = dist;
            closestObstacle = obs;
          }
        }

        Offset finalCenter = baseCenterOnAxis;
        String? dimText;
        (Offset, Offset)? dimLine;

        const double stepM = 0.01; // 1 cm construction precision
        if (closestObstacle != null && minObstacleDist <= 12.0 * cadUnitsPerMeter) {
          final distM = minObstacleDist / cadUnitsPerMeter;
          final snappedM = distM <= 0.02 ? 0.0 : (distM / stepM).round() * stepM;
          final snappedDistCad = snappedM * cadUnitsPerMeter;

          final v = baseCenterOnAxis - closestObstacle;
          final dirAlong = (v.dx * uAxis.dx + v.dy * uAxis.dy) >= 0 ? uAxis : -uAxis;
          final snappedAnchorWorld = closestObstacle + dirAlong * snappedDistCad;
          finalCenter = snappedAnchorWorld - bestAnchor.offset;

          dimText = '${snappedM.toStringAsFixed(2)} m';
          dimLine = (closestObstacle, snappedAnchorWorld);
        } else {
          final t = (baseCenterOnAxis - axis.start).dx * uAxis.dx +
              (baseCenterOnAxis - axis.start).dy * uAxis.dy;
          final tM = t / cadUnitsPerMeter;
          final snappedTm = (tM / stepM).round() * stepM;
          final snappedAnchorWorld = axis.start + uAxis * (snappedTm * cadUnitsPerMeter);
          finalCenter = snappedAnchorWorld - bestAnchor.offset;
          if (snappedTm.abs() > 0.005) {
            dimText = '${snappedTm.abs().toStringAsFixed(2)} m';
            dimLine = (axis.start, snappedAnchorWorld);
          }
        }

        return wrapResult(ColumnMagneticAlignmentResult(
          snappedCenter: finalCenter,
          guideLines: [(axis.start, axis.end)],
          description: 'gridAxis',
          markerPoint: finalCenter + bestAnchor.offset,
          liveDimensionText: dimText,
          dimensionLine: dimLine,
        ));
      }
    }

    // 3. Multi-DOF Column and Shear Wall Orthogonal Alignment (X and Y solved independently)
    Offset candidateCenter = effectiveRawCenter;
    final List<(Offset, Offset)> colGuides = [];
    double? candX;
    double? candY;
    StructuralColumn? xRefCol;
    StructuralColumn? yRefCol;
    String? equalSpacingDimText;
    (Offset, Offset)? equalSpacingDimLine;

    for (final col in activeStorey.columns) {
      if (movingColumnId != null && col.id == movingColumnId) continue;

      // X alignment: compare Center, Flush Left, Flush Right with axial priority
      if (candX == null) {
        final dCenter = (effectiveRawCenter.dx - col.center.dx).abs();
        final rawLeft = effectiveRawCenter.dx - columnWidth / 2.0;
        final colLeft = col.center.dx - col.width / 2.0;
        final dLeft = (rawLeft - colLeft).abs();
        final rawRight = effectiveRawCenter.dx + columnWidth / 2.0;
        final colRight = col.center.dx + col.width / 2.0;
        final dRight = (rawRight - colRight).abs();

        final minY = math.min(effectiveRawCenter.dy, col.center.dy) - 3.0 * cadUnitsPerMeter;
        final maxY = math.max(effectiveRawCenter.dy, col.center.dy) + 3.0 * cadUnitsPerMeter;

        if (dLeft <= effectiveTol * 0.6 && dLeft < dCenter - 0.05) {
          xRefCol = col;
          candX = colLeft + columnWidth / 2.0;
          colGuides.add((Offset(colLeft, minY), Offset(colLeft, maxY)));
        } else if (dRight <= effectiveTol * 0.6 && dRight < dCenter - 0.05) {
          xRefCol = col;
          candX = colRight - columnWidth / 2.0;
          colGuides.add((Offset(colRight, minY), Offset(colRight, maxY)));
        } else if (dCenter <= effectiveTol) {
          xRefCol = col;
          candX = col.center.dx;
          colGuides.add((Offset(col.center.dx, minY), Offset(col.center.dx, maxY)));
        } else if (dLeft <= effectiveTol) {
          xRefCol = col;
          candX = colLeft + columnWidth / 2.0;
          colGuides.add((Offset(colLeft, minY), Offset(colLeft, maxY)));
        } else if (dRight <= effectiveTol) {
          xRefCol = col;
          candX = colRight - columnWidth / 2.0;
          colGuides.add((Offset(colRight, minY), Offset(colRight, maxY)));
        }
      }

      // Y alignment: compare Center, Flush Bottom, Flush Top with axial priority
      if (candY == null) {
        final dCenter = (effectiveRawCenter.dy - col.center.dy).abs();
        final rawBot = effectiveRawCenter.dy - columnHeight / 2.0;
        final colBot = col.center.dy - col.height / 2.0;
        final dBot = (rawBot - colBot).abs();
        final rawTop = effectiveRawCenter.dy + columnHeight / 2.0;
        final colTop = col.center.dy + col.height / 2.0;
        final dTop = (rawTop - colTop).abs();

        final minX = math.min(effectiveRawCenter.dx, col.center.dx) - 3.0 * cadUnitsPerMeter;
        final maxX = math.max(effectiveRawCenter.dx, col.center.dx) + 3.0 * cadUnitsPerMeter;

        if (dBot <= effectiveTol * 0.6 && dBot < dCenter - 0.05) {
          yRefCol = col;
          candY = colBot + columnHeight / 2.0;
          colGuides.add((Offset(minX, colBot), Offset(maxX, colBot)));
        } else if (dTop <= effectiveTol * 0.6 && dTop < dCenter - 0.05) {
          yRefCol = col;
          candY = colTop - columnHeight / 2.0;
          colGuides.add((Offset(minX, colTop), Offset(maxX, colTop)));
        } else if (dCenter <= effectiveTol) {
          yRefCol = col;
          candY = col.center.dy;
          colGuides.add((Offset(minX, col.center.dy), Offset(maxX, col.center.dy)));
        } else if (dBot <= effectiveTol) {
          yRefCol = col;
          candY = colBot + columnHeight / 2.0;
          colGuides.add((Offset(minX, colBot), Offset(maxX, colBot)));
        } else if (dTop <= effectiveTol) {
          yRefCol = col;
          candY = colTop - columnHeight / 2.0;
          colGuides.add((Offset(minX, colTop), Offset(maxX, colTop)));
        }
      }

      if (candX != null && candY != null) break;
    }

    // 3b. Equal Spacing Snapping (Равни разстояния между две съседни колони)
    if (candX == null && activeStorey.columns.length >= 2) {
      for (int i = 0; i < activeStorey.columns.length; i++) {
        final c1 = activeStorey.columns[i];
        if (movingColumnId != null && c1.id == movingColumnId) continue;
        for (int j = i + 1; j < activeStorey.columns.length; j++) {
          final c2 = activeStorey.columns[j];
          if (movingColumnId != null && c2.id == movingColumnId) continue;
          if ((c1.center.dy - c2.center.dy).abs() > 0.6 * cadUnitsPerMeter) continue;
          if ((effectiveRawCenter.dy - c1.center.dy).abs() > 0.9 * cadUnitsPerMeter) continue;
          final leftC = c1.center.dx < c2.center.dx ? c1 : c2;
          final rightC = c1.center.dx < c2.center.dx ? c2 : c1;
          final leftFace = leftC.center.dx + leftC.width / 2.0;
          final rightFace = rightC.center.dx - rightC.width / 2.0;
          if (rightFace - leftFace > columnWidth) {
            final equalX = (leftFace + rightFace) / 2.0;
            if ((effectiveRawCenter.dx - equalX).abs() <= effectiveTol) {
              candX = equalX;
              final clearM = ((equalX - columnWidth / 2.0) - leftFace) / cadUnitsPerMeter;
              colGuides.add((Offset(leftFace, leftC.center.dy), Offset(rightFace, rightC.center.dy)));
              equalSpacingDimText = '${clearM.toStringAsFixed(2)} = ${clearM.toStringAsFixed(2)} m';
              equalSpacingDimLine = (Offset(leftFace, leftC.center.dy), Offset(rightFace, rightC.center.dy));
              break;
            }
          }
        }
        if (candX != null) break;
      }
    }
    if (candY == null && activeStorey.columns.length >= 2) {
      for (int i = 0; i < activeStorey.columns.length; i++) {
        final c1 = activeStorey.columns[i];
        if (movingColumnId != null && c1.id == movingColumnId) continue;
        for (int j = i + 1; j < activeStorey.columns.length; j++) {
          final c2 = activeStorey.columns[j];
          if (movingColumnId != null && c2.id == movingColumnId) continue;
          if ((c1.center.dx - c2.center.dx).abs() > 0.6 * cadUnitsPerMeter) continue;
          if ((effectiveRawCenter.dx - c1.center.dx).abs() > 0.9 * cadUnitsPerMeter) continue;
          final botC = c1.center.dy < c2.center.dy ? c1 : c2;
          final topC = c1.center.dy < c2.center.dy ? c2 : c1;
          final botFace = botC.center.dy + botC.height / 2.0;
          final topFace = topC.center.dy - topC.height / 2.0;
          if (topFace - botFace > columnHeight) {
            final equalY = (botFace + topFace) / 2.0;
            if ((effectiveRawCenter.dy - equalY).abs() <= effectiveTol) {
              candY = equalY;
              final clearM = ((equalY - columnHeight / 2.0) - botFace) / cadUnitsPerMeter;
              colGuides.add((Offset(botC.center.dx, botFace), Offset(topC.center.dx, topFace)));
              equalSpacingDimText = '${clearM.toStringAsFixed(2)} = ${clearM.toStringAsFixed(2)} m';
              equalSpacingDimLine = (Offset(botC.center.dx, botFace), Offset(topC.center.dx, topFace));
              break;
            }
          }
        }
        if (candY != null) break;
      }
    }

    if (candX != null || candY != null) {
      candidateCenter = Offset(candX ?? effectiveRawCenter.dx, candY ?? effectiveRawCenter.dy);

      // Measure clear distance (светъл размер) to the reference column along the line
      String? dimText = equalSpacingDimText;
      (Offset, Offset)? dimLine = equalSpacingDimLine;

      if (dimText == null) {
        if (candX != null && xRefCol != null && candY == null) {
          final double signY = candidateCenter.dy >= xRefCol.center.dy ? 1.0 : -1.0;
          final double faceOurY = candidateCenter.dy - signY * columnHeight / 2.0;
          final double faceRefY = xRefCol.center.dy + signY * xRefCol.height / 2.0;
          final double clearDistCad = (faceOurY - faceRefY).abs();
          if (clearDistCad > 0.05 * cadUnitsPerMeter && clearDistCad <= 12.0 * cadUnitsPerMeter) {
            final clearDistM = clearDistCad / cadUnitsPerMeter;
            dimText = '${clearDistM.toStringAsFixed(2)} m';
            final p1 = Offset(candidateCenter.dx, faceRefY);
            final p2 = Offset(candidateCenter.dx, faceOurY);
            dimLine = (p1, p2);
          }
        } else if (candY != null && yRefCol != null && candX == null) {
          final double signX = candidateCenter.dx >= yRefCol.center.dx ? 1.0 : -1.0;
          final double faceOurX = candidateCenter.dx - signX * columnWidth / 2.0;
          final double faceRefX = yRefCol.center.dx + signX * yRefCol.width / 2.0;
          final double clearDistCad = (faceOurX - faceRefX).abs();
          if (clearDistCad > 0.05 * cadUnitsPerMeter && clearDistCad <= 12.0 * cadUnitsPerMeter) {
            final clearDistM = clearDistCad / cadUnitsPerMeter;
            dimText = '${clearDistM.toStringAsFixed(2)} m';
            final p1 = Offset(faceRefX, candidateCenter.dy);
            final p2 = Offset(faceOurX, candidateCenter.dy);
            dimLine = (p1, p2);
          }
        }
      }

      return wrapResult(ColumnMagneticAlignmentResult(
        snappedCenter: candidateCenter,
        guideLines: colGuides,
        description: equalSpacingDimText != null
            ? 'equalSpacing'
            : ((candX != null && candY != null) ? 'columnAlign2D' : 'columnAlign'),
        markerPoint: candidateCenter,
        liveDimensionText: dimText,
        dimensionLine: dimLine,
      ));
    }

    // 4. Wall Closure lines, Openings, and CAD Underlay reference segments
    final refSegments = _extractReferenceSegments(
      activeStorey: activeStorey,
      dxfDocument: dxfDocument,
      cadUnitsPerMeter: cadUnitsPerMeter,
      excludeColumnId: movingColumnId,
    );

    ColumnMagneticAlignmentResult? bestClosureSnap;
    double bestClosureDist = double.infinity;

    for (final seg in refSegments) {
      final p1 = seg.p1;
      final p2 = seg.p2;
      final segVec = p2 - p1;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);

      for (final anchor in anchors) {
        if (anchor.name.startsWith('wallModule')) continue;
        final anchorWorld = effectiveRawCenter + anchor.offset;
        final distPerp = (anchorWorld - p1).dx * n.dx + (anchorWorld - p1).dy * n.dy;
        if (distPerp.abs() <= effectiveTol) {
          final proj = anchorWorld - n * distPerp;
          final t = (proj - p1).dx * u.dx + (proj - p1).dy * u.dy;

          // Check if projection is within or near the segment
          if (t >= -effectiveTol && t <= segLen + effectiveTol) {
            Offset snappedAnchor = proj;
            // Snap to closest feature: endpoint p1, endpoint p2, or midpoint
            final distP1 = t.abs();
            final distP2 = (t - segLen).abs();
            final distMid = (t - segLen / 2.0).abs();

            if (distMid <= distP1 && distMid <= distP2 && distMid <= effectiveTol) {
              snappedAnchor = (p1 + p2) / 2.0;
            } else if (distP1 <= distP2 && distP1 <= effectiveTol) {
              snappedAnchor = p1;
            } else if (distP2 <= effectiveTol) {
              snappedAnchor = p2;
            } else {
              snappedAnchor = p1 + u * t.clamp(0.0, segLen);
            }

            final snappedCenter = snappedAnchor - anchor.offset;
            final moveDist = (snappedCenter - effectiveRawCenter).distance;

            // Prioritize wall closure lines (caps) and opening edges
            final isHighPriority = seg.source == 'wallCap' || seg.source == 'openingEdge';
            final score = moveDist - (isHighPriority ? effectiveTol : 0.0);

            if (score < bestClosureDist) {
              bestClosureDist = score;
              bestClosureSnap = ColumnMagneticAlignmentResult(
                snappedCenter: snappedCenter,
                guideLines: [(p1 - u * 0.5, p2 + u * 0.5)],
                description: seg.source,
                markerPoint: snappedAnchor,
              );
            }
          }
        }
      }
    }

    if (bestClosureSnap != null) {
      return wrapResult(bestClosureSnap);
    }

    // 5. Centerline of Shear Walls (within wall span)
    for (final wall in activeStorey.shearWalls) {
      final segVec = wall.end - wall.start;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);
      final distPerp = (effectiveRawCenter - wall.start).dx * n.dx + (effectiveRawCenter - wall.start).dy * n.dy;
      if (distPerp.abs() <= effectiveTol) {
        final t = (effectiveRawCenter - wall.start).dx * u.dx + (effectiveRawCenter - wall.start).dy * u.dy;
        if (t >= 0.0 && t <= segLen) {
          final proj = effectiveRawCenter - n * distPerp;
          return wrapResult(ColumnMagneticAlignmentResult(
            snappedCenter: proj,
            guideLines: [(wall.start - u * 2.0, wall.end + u * 2.0)],
            description: 'shearWall',
            markerPoint: proj,
          ));
        }
      }
    }

    // 6. Centerline of Beams
    for (final beam in activeStorey.beams) {
      final segVec = beam.end - beam.start;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);
      final distPerp = (effectiveRawCenter - beam.start).dx * n.dx + (effectiveRawCenter - beam.start).dy * n.dy;
      if (distPerp.abs() <= effectiveTol) {
        final proj = effectiveRawCenter - n * distPerp;
        return wrapResult(ColumnMagneticAlignmentResult(
          snappedCenter: proj,
          guideLines: [(beam.start - u * 2.0, beam.end + u * 2.0)],
          description: 'beam',
          markerPoint: proj,
        ));
      }
    }

    return null;
  }

  /// Aligns a shear wall (center, orientation) to structural grid axes,
  /// other shear walls, beams, columns, or DXF underlay lines.
  static ShearWallMagneticAlignmentResult? alignShearWall({
    required Offset rawCenter,
    required double wallLength,
    required double wallThickness,
    required double wallRotationRad,
    required double toleranceCad,
    required StoreyLevel activeStorey,
    String? movingWallId,
    DxfDocument? dxfDocument,
    double cadUnitsPerMeter = 1.0,
    StructuralAxisLockMode axisLockMode = StructuralAxisLockMode.autoMode,
    Offset? anchorCenter,
    Offset? previousSnappedCenter,
    double? maxCorrectionCad,
    bool allowRotationSnap = true,
  }) {
    // 0. Handle Axis Constraint Mode
    Offset effectiveRawCenter = rawCenter;
    if (axisLockMode == StructuralAxisLockMode.lockX && anchorCenter != null) {
      effectiveRawCenter = Offset(anchorCenter.dx, effectiveRawCenter.dy);
    } else if (axisLockMode == StructuralAxisLockMode.lockY && anchorCenter != null) {
      effectiveRawCenter = Offset(effectiveRawCenter.dx, anchorCenter.dy);
    }

    // 0b. Hysteresis tolerance window (sticky snap)
    double effectiveTol = toleranceCad;
    if (maxCorrectionCad == null && previousSnappedCenter != null &&
        (effectiveRawCenter - previousSnappedCenter).distance <= toleranceCad * 1.35) {
      effectiveTol = toleranceCad * 1.35;
    }

    ShearWallMagneticAlignmentResult? wrapWallResult(ShearWallMagneticAlignmentResult res) {
      if (maxCorrectionCad != null && (res.snappedCenter-effectiveRawCenter).distance > maxCorrectionCad+1e-8) return null;
      if (!allowRotationSnap && res.snappedRotationRad != null) {
        final delta = (res.snappedRotationRad! - wallRotationRad).abs() % (2 * math.pi);
        if (math.min(delta, 2 * math.pi - delta) > 1e-8) return null;
      }
      if (axisLockMode == StructuralAxisLockMode.lockX && anchorCenter != null) {
        return ShearWallMagneticAlignmentResult(
          snappedCenter: Offset(anchorCenter.dx, res.snappedCenter.dy),
          snappedRotationRad: res.snappedRotationRad,
          guideLines: res.guideLines,
          description: res.description,
          markerPoint: res.markerPoint != null ? Offset(anchorCenter.dx, res.markerPoint!.dy) : null,
          liveDimensionText: res.liveDimensionText,
          dimensionLine: res.dimensionLine,
        );
      } else if (axisLockMode == StructuralAxisLockMode.lockY && anchorCenter != null) {
        return ShearWallMagneticAlignmentResult(
          snappedCenter: Offset(res.snappedCenter.dx, anchorCenter.dy),
          snappedRotationRad: res.snappedRotationRad,
          guideLines: res.guideLines,
          description: res.description,
          markerPoint: res.markerPoint != null ? Offset(res.markerPoint!.dx, anchorCenter.dy) : null,
          liveDimensionText: res.liveDimensionText,
          dimensionLine: res.dimensionLine,
        );
      }
      return res;
    }

    // Snap rotation to clean orthogonal if close
    double effectiveWallRot = wallRotationRad;
    const double angleTol = 0.15; // ~8.5 degrees
    for (final standardRot in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2, 2 * math.pi]) {
      final diff = (wallRotationRad - standardRot).abs() % (2 * math.pi);
      if (allowRotationSnap && (diff <= angleTol || (2 * math.pi - diff) <= angleTol)) {
        effectiveWallRot = standardRot % (2 * math.pi);
        break;
      }
    }

    final uWall = Offset(math.cos(effectiveWallRot), math.sin(effectiveWallRot));
    final nWall = Offset(-uWall.dy, uWall.dx);
    final halfLen = wallLength / 2.0;

    // 1. Grid Axes alignment
    for (final axis in activeStorey.gridAxes) {
      final aVec = axis.end - axis.start;
      final aLen = aVec.distance;
      if (aLen < 1e-4) continue;
      final uAxis = aVec / aLen;
      final nAxis = Offset(-uAxis.dy, uAxis.dx);

      final dot = (uWall.dx * uAxis.dx + uWall.dy * uAxis.dy).abs();

      // Case A: Parallel to grid axis -> magnetically lock centerline onto axis + 2-DOF step snapping
      if (dot > 0.94) {
        final distPerp = (effectiveRawCenter - axis.start).dx * nAxis.dx +
            (effectiveRawCenter - axis.start).dy * nAxis.dy;
        if (distPerp.abs() <= effectiveTol) {
          final baseCenterOnAxis = effectiveRawCenter - nAxis * distPerp;

          // Check if start or end touches any perpendicular grid axis (T-junction with cross-axis)
          for (final otherAxis in activeStorey.gridAxes) {
            if (otherAxis.id == axis.id) continue;
            final inter = axis.intersectionWith(otherAxis);
            if (inter != null) {
              final dStart = (baseCenterOnAxis - uWall * halfLen - inter).distance;
              if (dStart <= effectiveTol) {
                final snappedCenter = inter + uWall * halfLen;
                return wrapWallResult(ShearWallMagneticAlignmentResult(
                  snappedCenter: snappedCenter,
                  snappedRotationRad: axis.angleRad,
                  guideLines: [(axis.start, axis.end), (otherAxis.start, otherAxis.end)],
                  description: 'gridAxisAndCrossAxis',
                  markerPoint: inter,
                ));
              }
              final dEnd = (baseCenterOnAxis + uWall * halfLen - inter).distance;
              if (dEnd <= effectiveTol) {
                final snappedCenter = inter - uWall * halfLen;
                return wrapWallResult(ShearWallMagneticAlignmentResult(
                  snappedCenter: snappedCenter,
                  snappedRotationRad: axis.angleRad,
                  guideLines: [(axis.start, axis.end), (otherAxis.start, otherAxis.end)],
                  description: 'gridAxisAndCrossAxis',
                  markerPoint: inter,
                ));
              }
            }
          }

          // Check if start or end touches any perpendicular column face (flush with column)
          for (final col in activeStorey.columns) {
            final proj = axis.projectPoint(col.center);
            final dStart = (baseCenterOnAxis - uWall * halfLen - proj).distance;
            if (dStart <= effectiveTol) {
              final snappedCenter = proj + uWall * halfLen;
              return wrapWallResult(ShearWallMagneticAlignmentResult(
                snappedCenter: snappedCenter,
                snappedRotationRad: axis.angleRad,
                guideLines: [(axis.start, axis.end), (col.center, proj)],
                description: 'gridAxisAndColumn',
                markerPoint: proj,
              ));
            }
            final dEnd = (baseCenterOnAxis + uWall * halfLen - proj).distance;
            if (dEnd <= effectiveTol) {
              final snappedCenter = proj - uWall * halfLen;
              return wrapWallResult(ShearWallMagneticAlignmentResult(
                snappedCenter: snappedCenter,
                snappedRotationRad: axis.angleRad,
                guideLines: [(axis.start, axis.end), (col.center, proj)],
                description: 'gridAxisAndColumn',
                markerPoint: proj,
              ));
            }
          }

          // Along axis direction, find nearest reference obstacle to snap in 5cm steps
          final obstacles = <Offset>[];
          for (final col in activeStorey.columns) {
            final proj = axis.projectPoint(col.center);
            if ((col.center - proj).distance <= 1.5 * cadUnitsPerMeter) {
              obstacles.add(proj);
            }
          }
          for (final wall in activeStorey.shearWalls) {
            if (movingWallId != null && wall.id == movingWallId) continue;
            final p1 = axis.projectPoint(wall.start);
            final p2 = axis.projectPoint(wall.end);
            if ((wall.start - p1).distance <= 1.5 * cadUnitsPerMeter) obstacles.add(p1);
            if ((wall.end - p2).distance <= 1.5 * cadUnitsPerMeter) obstacles.add(p2);
          }
          for (final otherAxis in activeStorey.gridAxes) {
            if (otherAxis.id == axis.id) continue;
            final inter = axis.intersectionWith(otherAxis);
            if (inter != null) obstacles.add(inter);
          }

          Offset? closestObstacle;
          double minObstacleDist = double.infinity;
          for (final obs in obstacles) {
            final dStart = (baseCenterOnAxis - uWall * halfLen - obs).distance;
            final dEnd = (baseCenterOnAxis + uWall * halfLen - obs).distance;
            final dCenter = (baseCenterOnAxis - obs).distance;
            final dMin = math.min(dCenter, math.min(dStart, dEnd));
            if (dMin > 1e-3 && dMin < minObstacleDist) {
              minObstacleDist = dMin;
              closestObstacle = obs;
            }
          }

          Offset finalCenter = baseCenterOnAxis;
          String? dimText;
          (Offset, Offset)? dimLine;

          const double stepM = 0.01; // 1 cm construction precision
          if (closestObstacle != null && minObstacleDist <= 12.0 * cadUnitsPerMeter) {
            final distM = minObstacleDist / cadUnitsPerMeter;
            final snappedM = distM <= 0.02 ? 0.0 : (distM / stepM).round() * stepM;
            final snappedDistCad = snappedM * cadUnitsPerMeter;

            final dStart = (baseCenterOnAxis - uWall * halfLen - closestObstacle).distance;
            final dEnd = (baseCenterOnAxis + uWall * halfLen - closestObstacle).distance;

            Offset refNodeOnWall;
            Offset offsetToCenter;
            if (dStart <= dEnd) {
              refNodeOnWall = baseCenterOnAxis - uWall * halfLen;
              offsetToCenter = uWall * halfLen;
            } else {
              refNodeOnWall = baseCenterOnAxis + uWall * halfLen;
              offsetToCenter = -uWall * halfLen;
            }

            final v = refNodeOnWall - closestObstacle;
            final dirAlong = (v.dx * uAxis.dx + v.dy * uAxis.dy) >= 0 ? uAxis : -uAxis;
            final snappedNodeWorld = closestObstacle + dirAlong * snappedDistCad;
            finalCenter = snappedNodeWorld + offsetToCenter;

            dimText = '${snappedM.toStringAsFixed(2)} m';
            dimLine = (closestObstacle, snappedNodeWorld);
          } else {
            final t = (baseCenterOnAxis - axis.start).dx * uAxis.dx +
                (baseCenterOnAxis - axis.start).dy * uAxis.dy;
            final tM = t / cadUnitsPerMeter;
            final snappedTm = (tM / stepM).round() * stepM;
            finalCenter = axis.start + uAxis * (snappedTm * cadUnitsPerMeter);
            if (snappedTm.abs() > 0.005) {
              dimText = '${snappedTm.abs().toStringAsFixed(2)} m';
              dimLine = (axis.start, finalCenter);
            }
          }

          return wrapWallResult(ShearWallMagneticAlignmentResult(
            snappedCenter: finalCenter,
            snappedRotationRad: axis.angleRad,
            guideLines: [(axis.start, axis.end)],
            description: 'gridAxis',
            markerPoint: finalCenter,
            liveDimensionText: dimText,
            dimensionLine: dimLine,
          ));
        }
      }

      // Case B: Perpendicular to grid axis -> end, center, or 12.5 cm module touches axis
      if (dot < 0.20) {
        final pStart = effectiveRawCenter - uWall * halfLen;
        final pEnd = effectiveRawCenter + uWall * halfLen;
        final mod12_5 = 0.125 * cadUnitsPerMeter;
        final pModStart = effectiveRawCenter - uWall * (halfLen - mod12_5);
        final pModEnd = effectiveRawCenter + uWall * (halfLen - mod12_5);

        final testNodes = [
          (pStart, 'wallStart'),
          (pEnd, 'wallEnd'),
          (pModStart, 'wallModuleStart'),
          (pModEnd, 'wallModuleEnd'),
        ];

        for (final node in testNodes) {
          final distPerp = (node.$1 - axis.start).dx * nAxis.dx +
              (node.$1 - axis.start).dy * nAxis.dy;
          if (distPerp.abs() <= effectiveTol) {
            final snappedNode = node.$1 - nAxis * distPerp;
            final offsetFromNode = effectiveRawCenter - node.$1;
            final snappedCenter = snappedNode + offsetFromNode;
            return wrapWallResult(ShearWallMagneticAlignmentResult(
              snappedCenter: snappedCenter,
              guideLines: [(axis.start, axis.end)],
              description: 'gridAxis',
              markerPoint: snappedNode,
            ));
          }
        }
      }
    }

    // 2. Collinear with other Shear Walls
    for (final wall in activeStorey.shearWalls) {
      if (movingWallId != null && wall.id == movingWallId) continue;
      final wVec = wall.end - wall.start;
      final wLen = wVec.distance;
      if (wLen < 1e-4) continue;
      final uOther = wVec / wLen;
      final nOther = Offset(-uOther.dy, uOther.dx);

      final dot = (uWall.dx * uOther.dx + uWall.dy * uOther.dy).abs();
      if (dot > 0.94) {
        final distPerp = (effectiveRawCenter - wall.start).dx * nOther.dx +
            (effectiveRawCenter - wall.start).dy * nOther.dy;
        if (distPerp.abs() <= effectiveTol) {
          final snapped = effectiveRawCenter - nOther * distPerp;
          return wrapWallResult(ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(wall.start - uOther * 3.0, wall.end + uOther * 3.0)],
            description: 'shearWall',
            markerPoint: snapped,
          ));
        }
      }
    }

    // 3. Collinear with Beams
    for (final beam in activeStorey.beams) {
      final bVec = beam.end - beam.start;
      final bLen = bVec.distance;
      if (bLen < 1e-4) continue;
      final uBeam = bVec / bLen;
      final nBeam = Offset(-uBeam.dy, uBeam.dx);

      final dot = (uWall.dx * uBeam.dx + uWall.dy * uBeam.dy).abs();
      if (dot > 0.94) {
        final distPerp = (effectiveRawCenter - beam.start).dx * nBeam.dx +
            (effectiveRawCenter - beam.start).dy * nBeam.dy;
        if (distPerp.abs() <= effectiveTol) {
          final snapped = effectiveRawCenter - nBeam * distPerp;
          return wrapWallResult(ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(beam.start - uBeam * 2.0, beam.end + uBeam * 2.0)],
            description: 'beam',
            markerPoint: snapped,
          ));
        }
      }
    }

    // 4. Wall centerline passes through an existing Column
    for (final col in activeStorey.columns) {
      final distPerp = (col.center - effectiveRawCenter).dx * nWall.dx +
          (col.center - effectiveRawCenter).dy * nWall.dy;
      if (distPerp.abs() <= effectiveTol) {
        final snapped = effectiveRawCenter + nWall * distPerp;
        final guideStart = snapped - uWall * (halfLen + 2.0);
        final guideEnd = snapped + uWall * (halfLen + 2.0);
        return wrapWallResult(ShearWallMagneticAlignmentResult(
          snappedCenter: snapped,
          guideLines: [(guideStart, guideEnd)],
          description: 'column',
          markerPoint: col.center,
        ));
      }
    }

    // 5. Angle wall outer edge, corner walls, and CAD underlay reference segments
    final refSegments = _extractReferenceSegments(
      activeStorey: activeStorey,
      dxfDocument: dxfDocument,
      cadUnitsPerMeter: cadUnitsPerMeter,
      excludeWallId: movingWallId,
    );

    ShearWallMagneticAlignmentResult? bestWallSegSnap;
    double bestWallSegDist = double.infinity;

    for (final seg in refSegments) {
      final p1 = seg.p1;
      final p2 = seg.p2;
      final segVec = p2 - p1;
      final segLen = segVec.distance;
      if (segLen < 0.1 * cadUnitsPerMeter) continue;
      final uLine = segVec / segLen;
      final nLine = Offset(-uLine.dy, uLine.dx);

      final dot = (uWall.dx * uLine.dx + uWall.dy * uLine.dy).abs();
      final dotPerp = (uWall.dx * nLine.dx + uWall.dy * nLine.dy).abs();

      // Case A: Parallel or Angle Wall Alignment (wall orients along the line)
      if (dot >= 0.88) {
        final alignDir = (uWall.dx * uLine.dx + uWall.dy * uLine.dy) >= 0 ? 1.0 : -1.0;
        final uW = uLine * alignDir;
        final snappedRot = (alignDir > 0)
            ? math.atan2(uLine.dy, uLine.dx)
            : math.atan2(-uLine.dy, -uLine.dx);

        final distCenter = (effectiveRawCenter - p1).dx * nLine.dx + (effectiveRawCenter - p1).dy * nLine.dy;
        final halfThick = wallThickness / 2.0;

        // Test Left Face, Right Face, and Centerline
        final faceOffsets = [
          (0.0, 'center'),
          (-halfThick, 'leftFace'),
          (halfThick, 'rightFace'),
        ];

        for (final (fOff, _) in faceOffsets) {
          final distFace = distCenter - fOff;
          if (distFace.abs() <= effectiveTol) {
            final baseCenter = effectiveRawCenter - nLine * distFace;

            // Along the segment, test start cap, end cap, and corners against p1 and p2
            Offset finalCenter = baseCenter;
            final dStartP1 = (baseCenter - uW * halfLen - p1).distance;
            final dStartP2 = (baseCenter - uW * halfLen - p2).distance;
            final dEndP1 = (baseCenter + uW * halfLen - p1).distance;
            final dEndP2 = (baseCenter + uW * halfLen - p2).distance;

            if (dStartP1 <= effectiveTol * 1.2) {
              finalCenter = p1 + uW * halfLen;
            } else if (dStartP2 <= effectiveTol * 1.2) {
              finalCenter = p2 + uW * halfLen;
            } else if (dEndP1 <= effectiveTol * 1.2) {
              finalCenter = p1 - uW * halfLen;
            } else if (dEndP2 <= effectiveTol * 1.2) {
              finalCenter = p2 - uW * halfLen;
            } else {
              // 1 cm step snapping along the wall segment
              final t = (baseCenter - p1).dx * uLine.dx + (baseCenter - p1).dy * uLine.dy;
              final tM = t / cadUnitsPerMeter;
              const double stepM = 0.01;
              final snappedTm = (tM / stepM).round() * stepM;
              finalCenter = p1 + uLine * (snappedTm * cadUnitsPerMeter);
            }

            final moveDist = (finalCenter - effectiveRawCenter).distance;
            if (moveDist < bestWallSegDist) {
              bestWallSegDist = moveDist;
              bestWallSegSnap = ShearWallMagneticAlignmentResult(
                snappedCenter: finalCenter,
                snappedRotationRad: snappedRot,
                guideLines: [(p1 - uLine * 1.5, p2 + uLine * 1.5)],
                description: 'angleWallEdge',
                markerPoint: finalCenter,
              );
            }
          }
        }
      }

      // Case B: Perpendicular Alignment (Start cap or End cap flush to return wall / corner)
      if (dotPerp >= 0.88) {
        final startCapCenter = effectiveRawCenter - uWall * halfLen;
        final endCapCenter = effectiveRawCenter + uWall * halfLen;

        final distStart = (startCapCenter - p1).dx * nLine.dx + (startCapCenter - p1).dy * nLine.dy;
        if (distStart.abs() <= effectiveTol) {
          final snappedStart = startCapCenter - nLine * distStart;
          final snappedCenter = snappedStart + uWall * halfLen;
          final moveDist = (snappedCenter - effectiveRawCenter).distance;
          if (moveDist < bestWallSegDist) {
            bestWallSegDist = moveDist;
            bestWallSegSnap = ShearWallMagneticAlignmentResult(
              snappedCenter: snappedCenter,
              snappedRotationRad: effectiveWallRot,
              guideLines: [(p1 - uLine * 1.5, p2 + uLine * 1.5)],
              description: 'cornerReturnWall',
              markerPoint: snappedStart,
            );
          }
        }

        final distEnd = (endCapCenter - p1).dx * nLine.dx + (endCapCenter - p1).dy * nLine.dy;
        if (distEnd.abs() <= effectiveTol) {
          final snappedEnd = endCapCenter - nLine * distEnd;
          final snappedCenter = snappedEnd - uWall * halfLen;
          final moveDist = (snappedCenter - effectiveRawCenter).distance;
          if (moveDist < bestWallSegDist) {
            bestWallSegDist = moveDist;
            bestWallSegSnap = ShearWallMagneticAlignmentResult(
              snappedCenter: snappedCenter,
              snappedRotationRad: effectiveWallRot,
              guideLines: [(p1 - uLine * 1.5, p2 + uLine * 1.5)],
              description: 'cornerReturnWall',
              markerPoint: snappedEnd,
            );
          }
        }
      }
    }

    if (bestWallSegSnap != null) {
      return wrapWallResult(bestWallSegSnap);
    }

    return null;
  }

  /// Magnetically aligns a beam endpoint (start or end) to column centers,
  /// shear wall centers and axes, other beam endpoints and axes, grid axes,
  /// and orthogonal directions (0°, 90°, 180°, 270°).
  static BeamMagneticAlignmentResult? alignBeamEndpoint({
    required Offset rawPoint,
    Offset? beamStart,
    required double toleranceCad,
    required StoreyLevel activeStorey,
    String? excludeBeamId,
    double cadUnitsPerMeter = 1.0,
  }) {
    // 1. Column Centers (Highest priority: axial connection directly to column center)
    StructuralColumn? bestCol;
    double bestColDist = double.infinity;
    for (final col in activeStorey.columns) {
      final d = (rawPoint - col.center).distance;
      if (d <= toleranceCad && d < bestColDist) {
        bestColDist = d;
        bestCol = col;
      }
    }
    if (bestCol != null) {
      final guides = <(Offset, Offset)>[];
      if (beamStart != null) {
        guides.add((beamStart, bestCol.center));
      } else {
        final crossSpan = 1.5 * cadUnitsPerMeter;
        guides.add((
          Offset(bestCol.center.dx - crossSpan, bestCol.center.dy),
          Offset(bestCol.center.dx + crossSpan, bestCol.center.dy),
        ));
        guides.add((
          Offset(bestCol.center.dx, bestCol.center.dy - crossSpan),
          Offset(bestCol.center.dx, bestCol.center.dy + crossSpan),
        ));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestCol.center,
        guideLines: guides,
        description: 'columnCenter',
        markerPoint: bestCol.center,
      );
    }

    // 2. Shear Wall Discrete Nodes: Center, Endpoints, and 12.5 cm Modular Nodes
    Offset? bestNodePt;
    StructuralShearWall? bestNodeWall;
    double bestNodeDist = double.infinity;
    String bestNodeType = '';

    for (final wall in activeStorey.shearWalls) {
      // 2a. Center
      final dCenter = (rawPoint - wall.center).distance;
      if (dCenter <= toleranceCad && dCenter < bestNodeDist) {
        bestNodeDist = dCenter;
        bestNodePt = wall.center;
        bestNodeWall = wall;
        bestNodeType = 'shearWallCenter';
      }

      // 2b. Endpoints (start / end)
      final dStart = (rawPoint - wall.start).distance;
      if (dStart <= toleranceCad && dStart < bestNodeDist) {
        bestNodeDist = dStart;
        bestNodePt = wall.start;
        bestNodeWall = wall;
        bestNodeType = 'shearWallEnd';
      }
      final dEnd = (rawPoint - wall.end).distance;
      if (dEnd <= toleranceCad && dEnd < bestNodeDist) {
        bestNodeDist = dEnd;
        bestNodePt = wall.end;
        bestNodeWall = wall;
        bestNodeType = 'shearWallEnd';
      }

      // 2c. 12.5 cm Modular End Nodes (for 25cm masonry wall corners / perpendicular junctions)
      final wVec = wall.end - wall.start;
      final wLen = wVec.distance;
      if (wLen >= 0.3 * cadUnitsPerMeter) {
        final u = wVec / wLen;
        final mod12_5 = 0.125 * cadUnitsPerMeter;
        final m1 = wall.start + u * mod12_5;
        final m2 = wall.end - u * mod12_5;
        final d1 = (rawPoint - m1).distance;
        if (d1 <= toleranceCad && d1 < bestNodeDist && dStart > 0.10 * cadUnitsPerMeter) {
          bestNodeDist = d1;
          bestNodePt = m1;
          bestNodeWall = wall;
          bestNodeType = 'shearWallModule';
        }
        final d2 = (rawPoint - m2).distance;
        if (d2 <= toleranceCad && d2 < bestNodeDist && dEnd > 0.10 * cadUnitsPerMeter) {
          bestNodeDist = d2;
          bestNodePt = m2;
          bestNodeWall = wall;
          bestNodeType = 'shearWallModule';
        }
      }
    }

    if (bestNodePt != null && bestNodeWall != null) {
      final guides = <(Offset, Offset)>[(bestNodeWall.start, bestNodeWall.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestNodePt));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestNodePt,
        guideLines: guides,
        description: bestNodeType,
        markerPoint: bestNodePt,
      );
    }

    // 2c. Shear Wall Baseline Axis (segment projection)
    Offset? bestWallAxisProj;
    StructuralShearWall? bestWallAxisObj;
    double bestWallAxisDist = double.infinity;
    for (final wall in activeStorey.shearWalls) {
      final wVec = wall.end - wall.start;
      final wLen = wVec.distance;
      if (wLen < 1e-4) continue;
      final u = wVec / wLen;
      final t = (rawPoint - wall.start).dx * u.dx + (rawPoint - wall.start).dy * u.dy;
      if (t >= 0.0 && t <= wLen) {
        final proj = wall.start + u * t;
        final d = (rawPoint - proj).distance;
        if (d <= toleranceCad && d < bestWallAxisDist) {
          bestWallAxisDist = d;
          bestWallAxisProj = proj;
          bestWallAxisObj = wall;
        }
      }
    }
    if (bestWallAxisProj != null && bestWallAxisObj != null) {
      final guides = <(Offset, Offset)>[(bestWallAxisObj.start, bestWallAxisObj.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestWallAxisProj));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestWallAxisProj,
        guideLines: guides,
        description: 'shearWallAxis',
        markerPoint: bestWallAxisProj,
      );
    }

    // 3. Other Beams (Endpoints & T-junctions)
    Offset? bestBeamEndPt;
    StructuralBeam? bestBeamEndObj;
    double bestBeamEndDist = double.infinity;
    for (final b in activeStorey.beams) {
      if (excludeBeamId != null && b.id == excludeBeamId) continue;
      final dStart = (rawPoint - b.start).distance;
      if (dStart <= toleranceCad && dStart < bestBeamEndDist) {
        bestBeamEndDist = dStart;
        bestBeamEndPt = b.start;
        bestBeamEndObj = b;
      }
      final dEnd = (rawPoint - b.end).distance;
      if (dEnd <= toleranceCad && dEnd < bestBeamEndDist) {
        bestBeamEndDist = dEnd;
        bestBeamEndPt = b.end;
        bestBeamEndObj = b;
      }
    }
    if (bestBeamEndPt != null && bestBeamEndObj != null) {
      final guides = <(Offset, Offset)>[(bestBeamEndObj.start, bestBeamEndObj.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestBeamEndPt));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestBeamEndPt,
        guideLines: guides,
        description: 'beamEnd',
        markerPoint: bestBeamEndPt,
      );
    }

    // 3b. Other Beams Axial Projection (T-junctions)
    Offset? bestBeamAxisProj;
    StructuralBeam? bestBeamAxisObj;
    double bestBeamAxisDist = double.infinity;
    for (final b in activeStorey.beams) {
      if (excludeBeamId != null && b.id == excludeBeamId) continue;
      final bVec = b.end - b.start;
      final bLen = bVec.distance;
      if (bLen < 1e-4) continue;
      final u = bVec / bLen;
      final t = (rawPoint - b.start).dx * u.dx + (rawPoint - b.start).dy * u.dy;
      if (t >= 0.0 && t <= bLen) {
        final proj = b.start + u * t;
        final d = (rawPoint - proj).distance;
        if (d <= toleranceCad && d < bestBeamAxisDist) {
          bestBeamAxisDist = d;
          bestBeamAxisProj = proj;
          bestBeamAxisObj = b;
        }
      }
    }
    if (bestBeamAxisProj != null && bestBeamAxisObj != null) {
      final guides = <(Offset, Offset)>[(bestBeamAxisObj.start, bestBeamAxisObj.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestBeamAxisProj));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestBeamAxisProj,
        guideLines: guides,
        description: 'beamAxis',
        markerPoint: bestBeamAxisProj,
      );
    }

    // 4. Grid Axes (Intersections and Lines)
    final axes = activeStorey.gridAxes;
    for (int i = 0; i < axes.length; i++) {
      for (int j = i + 1; j < axes.length; j++) {
        final inter = axes[i].intersectionWith(axes[j]);
        if (inter != null && (rawPoint - inter).distance <= toleranceCad * 1.2) {
          final guides = <(Offset, Offset)>[
            (axes[i].start, axes[i].end),
            (axes[j].start, axes[j].end),
          ];
          if (beamStart != null) {
            guides.add((beamStart, inter));
          }
          return BeamMagneticAlignmentResult(
            snappedPoint: inter,
            guideLines: guides,
            description: 'gridIntersection',
            markerPoint: inter,
          );
        }
      }
    }

    for (final axis in axes) {
      final proj = axis.projectPoint(rawPoint);
      if ((rawPoint - proj).distance <= toleranceCad) {
        final guides = <(Offset, Offset)>[(axis.start, axis.end)];
        if (beamStart != null) {
          guides.add((beamStart, proj));
        }
        return BeamMagneticAlignmentResult(
          snappedPoint: proj,
          guideLines: guides,
          description: 'gridAxis',
          markerPoint: proj,
        );
      }
    }

    // 5. Orthogonal Direction Lock (0°, 90°, 180°, 270°) with 0.10m increment rounding
    if (beamStart != null) {
      final dx = rawPoint.dx - beamStart.dx;
      final dy = rawPoint.dy - beamStart.dy;

      // Horizontal lock
      if (dy.abs() <= toleranceCad && dx.abs() > 0.05 * cadUnitsPerMeter) {
        final lenM = dx.abs() / cadUnitsPerMeter;
        final snappedLenM = math.max(0.10, (lenM / 0.10).round() * 0.10);
        final snappedX = beamStart.dx + (dx >= 0 ? 1.0 : -1.0) * (snappedLenM * cadUnitsPerMeter);
        final snappedPt = Offset(snappedX, beamStart.dy);
        return BeamMagneticAlignmentResult(
          snappedPoint: snappedPt,
          guideLines: [(beamStart, snappedPt)],
          description: 'orthoLock',
          markerPoint: snappedPt,
        );
      }

      // Vertical lock
      if (dx.abs() <= toleranceCad && dy.abs() > 0.05 * cadUnitsPerMeter) {
        final lenM = dy.abs() / cadUnitsPerMeter;
        final snappedLenM = math.max(0.10, (lenM / 0.10).round() * 0.10);
        final snappedY = beamStart.dy + (dy >= 0 ? 1.0 : -1.0) * (snappedLenM * cadUnitsPerMeter);
        final snappedPt = Offset(beamStart.dx, snappedY);
        return BeamMagneticAlignmentResult(
          snappedPoint: snappedPt,
          guideLines: [(beamStart, snappedPt)],
          description: 'orthoLock',
          markerPoint: snappedPt,
        );
      }
    }

    return null;
  }
}
