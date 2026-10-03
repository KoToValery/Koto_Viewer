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
  }) {
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
          final anchorWorld = rawCenter + anchor.offset;
          final d = (anchorWorld - inter).distance;
          if (d <= toleranceCad * 1.5 && d < bestInterDist) {
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
            final anchorWorld = rawCenter + anchor.offset;
            final d = (anchorWorld - inter).distance;
            if (d <= toleranceCad * 0.7 && d < bestInterDist) {
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
      return ColumnMagneticAlignmentResult(
        snappedCenter: bestSnappedCenter,
        guideLines: [
          (bestAxes.$1.start, bestAxes.$1.end),
          (bestAxes.$2.start, bestAxes.$2.end),
        ],
        description: 'gridIntersection',
        markerPoint: bestInterPoint,
      );
    }

    // 2. Single Grid Axis line alignment (column anchor locks to axis line + 5 cm step snapping)
    for (final axis in axes) {
      final aVec = axis.end - axis.start;
      final aLen = aVec.distance;
      if (aLen < 1e-4) continue;
      final uAxis = aVec / aLen;
      final nAxis = Offset(-uAxis.dy, uAxis.dx);

      double bestPerpDist = double.infinity;
      ({Offset offset, String name})? bestAnchor;

      for (final anchor in anchors) {
        final anchorWorld = rawCenter + anchor.offset;
        final distPerp = (anchorWorld - axis.start).dx * nAxis.dx +
            (anchorWorld - axis.start).dy * nAxis.dy;
        if (distPerp.abs() <= toleranceCad && distPerp.abs() < bestPerpDist.abs()) {
          bestPerpDist = distPerp;
          bestAnchor = anchor;
        }
      }

      if (bestAnchor != null) {
        final baseCenterOnAxis = rawCenter - nAxis * bestPerpDist;

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

        const double stepM = 0.05; // 5 cm construction snap step
        if (closestObstacle != null && minObstacleDist <= 12.0 * cadUnitsPerMeter) {
          final distM = minObstacleDist / cadUnitsPerMeter;
          final snappedM = math.max(stepM, (distM / stepM).round() * stepM);
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
          if (snappedTm.abs() > 0.01) {
            dimText = '${snappedTm.abs().toStringAsFixed(2)} m';
            dimLine = (axis.start, snappedAnchorWorld);
          }
        }

        return ColumnMagneticAlignmentResult(
          snappedCenter: finalCenter,
          guideLines: [(axis.start, axis.end)],
          description: 'gridAxis',
          markerPoint: finalCenter + bestAnchor.offset,
          liveDimensionText: dimText,
          dimensionLine: dimLine,
        );
      }
    }

    // 3. Other Columns in the storey (X / Y collinear magnetic alignment guides)
    Offset candidateCenter = rawCenter;
    final List<(Offset, Offset)> colGuides = [];
    bool alignedX = false;
    bool alignedY = false;

    for (final col in activeStorey.columns) {
      if (movingColumnId != null && col.id == movingColumnId) continue;

      if (!alignedX && (rawCenter.dx - col.center.dx).abs() <= toleranceCad) {
        candidateCenter = Offset(col.center.dx, candidateCenter.dy);
        alignedX = true;
        final minY = math.min(rawCenter.dy, col.center.dy) - 3.0 * cadUnitsPerMeter;
        final maxY = math.max(rawCenter.dy, col.center.dy) + 3.0 * cadUnitsPerMeter;
        colGuides.add((Offset(col.center.dx, minY), Offset(col.center.dx, maxY)));
      }

      if (!alignedY && (rawCenter.dy - col.center.dy).abs() <= toleranceCad) {
        candidateCenter = Offset(candidateCenter.dx, col.center.dy);
        alignedY = true;
        final minX = math.min(rawCenter.dx, col.center.dx) - 3.0 * cadUnitsPerMeter;
        final maxX = math.max(rawCenter.dx, col.center.dx) + 3.0 * cadUnitsPerMeter;
        colGuides.add((Offset(minX, col.center.dy), Offset(maxX, col.center.dy)));
      }

      if (alignedX && alignedY) break;
    }

    if (alignedX || alignedY) {
      return ColumnMagneticAlignmentResult(
        snappedCenter: candidateCenter,
        guideLines: colGuides,
        description: 'columnAlign',
        markerPoint: candidateCenter,
      );
    }

    // 4. Centerline of Shear Walls
    for (final wall in activeStorey.shearWalls) {
      final segVec = wall.end - wall.start;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);
      final distPerp = (rawCenter - wall.start).dx * n.dx + (rawCenter - wall.start).dy * n.dy;
      if (distPerp.abs() <= toleranceCad) {
        final proj = rawCenter - n * distPerp;
        return ColumnMagneticAlignmentResult(
          snappedCenter: proj,
          guideLines: [(wall.start - u * 2.0, wall.end + u * 2.0)],
          description: 'shearWall',
          markerPoint: proj,
        );
      }
    }

    // 5. Centerline of Beams
    for (final beam in activeStorey.beams) {
      final segVec = beam.end - beam.start;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;
      final u = segVec / segLen;
      final n = Offset(-u.dy, u.dx);
      final distPerp = (rawCenter - beam.start).dx * n.dx + (rawCenter - beam.start).dy * n.dy;
      if (distPerp.abs() <= toleranceCad) {
        final proj = rawCenter - n * distPerp;
        return ColumnMagneticAlignmentResult(
          snappedCenter: proj,
          guideLines: [(beam.start - u * 2.0, beam.end + u * 2.0)],
          description: 'beam',
          markerPoint: proj,
        );
      }
    }

    // 6. DXF Underlay lines
    if (dxfDocument != null) {
      for (final entity in dxfDocument.entities) {
        if (entity is DxfLine) {
          final p1 = entity.p1;
          final p2 = entity.p2;
          final segVec = p2 - p1;
          final segLen = segVec.distance;
          if (segLen < 0.2 * cadUnitsPerMeter) continue;
          final u = segVec / segLen;
          final n = Offset(-u.dy, u.dx);
          final distPerp = (rawCenter - p1).dx * n.dx + (rawCenter - p1).dy * n.dy;
          if (distPerp.abs() <= toleranceCad) {
            final proj = rawCenter - n * distPerp;
            final t = ((proj - p1).dx * u.dx + (proj - p1).dy * u.dy) / segLen;
            if (t >= -0.2 && t <= 1.2) {
              return ColumnMagneticAlignmentResult(
                snappedCenter: proj,
                guideLines: [(p1 - u * 1.5, p2 + u * 1.5)],
                description: 'dxfLine',
                markerPoint: proj,
              );
            }
          }
        }
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
  }) {
    final uWall = Offset(math.cos(wallRotationRad), math.sin(wallRotationRad));
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

      // Case A: Parallel to grid axis -> magnetically lock centerline onto axis + 5 cm step snapping
      if (dot > 0.94) {
        final distPerp = (rawCenter - axis.start).dx * nAxis.dx +
            (rawCenter - axis.start).dy * nAxis.dy;
        if (distPerp.abs() <= toleranceCad) {
          final baseCenterOnAxis = rawCenter - nAxis * distPerp;

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

          const double stepM = 0.05; // 5 cm construction snap step
          if (closestObstacle != null && minObstacleDist <= 12.0 * cadUnitsPerMeter) {
            final distM = minObstacleDist / cadUnitsPerMeter;
            final snappedM = math.max(stepM, (distM / stepM).round() * stepM);
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
            if (snappedTm.abs() > 0.01) {
              dimText = '${snappedTm.abs().toStringAsFixed(2)} m';
              dimLine = (axis.start, finalCenter);
            }
          }

          return ShearWallMagneticAlignmentResult(
            snappedCenter: finalCenter,
            guideLines: [(axis.start, axis.end)],
            description: 'gridAxis',
            markerPoint: finalCenter,
            liveDimensionText: dimText,
            dimensionLine: dimLine,
          );
        }
      }

      // Case B: Perpendicular to grid axis -> end, center, or 12.5 cm module touches axis
      if (dot < 0.20) {
        final pStart = rawCenter - uWall * halfLen;
        final pEnd = rawCenter + uWall * halfLen;
        final mod12_5 = 0.125 * cadUnitsPerMeter;
        final pModStart = rawCenter - uWall * (halfLen - mod12_5);
        final pModEnd = rawCenter + uWall * (halfLen - mod12_5);

        final testNodes = [
          (pStart, 'wallStart'),
          (pEnd, 'wallEnd'),
          (pModStart, 'wallModuleStart'),
          (pModEnd, 'wallModuleEnd'),
        ];

        for (final node in testNodes) {
          final distPerp = (node.$1 - axis.start).dx * nAxis.dx +
              (node.$1 - axis.start).dy * nAxis.dy;
          if (distPerp.abs() <= toleranceCad) {
            final snappedNode = node.$1 - nAxis * distPerp;
            final offsetFromNode = rawCenter - node.$1;
            final snappedCenter = snappedNode + offsetFromNode;
            return ShearWallMagneticAlignmentResult(
              snappedCenter: snappedCenter,
              guideLines: [(axis.start, axis.end)],
              description: 'gridAxis',
              markerPoint: snappedNode,
            );
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
        final distPerp = (rawCenter - wall.start).dx * nOther.dx +
            (rawCenter - wall.start).dy * nOther.dy;
        if (distPerp.abs() <= toleranceCad) {
          final snapped = rawCenter - nOther * distPerp;
          return ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(wall.start - uOther * 3.0, wall.end + uOther * 3.0)],
            description: 'shearWall',
            markerPoint: snapped,
          );
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
        final distPerp = (rawCenter - beam.start).dx * nBeam.dx +
            (rawCenter - beam.start).dy * nBeam.dy;
        if (distPerp.abs() <= toleranceCad) {
          final snapped = rawCenter - nBeam * distPerp;
          return ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(beam.start - uBeam * 2.0, beam.end + uBeam * 2.0)],
            description: 'beam',
            markerPoint: snapped,
          );
        }
      }
    }

    // 4. Wall centerline passes through an existing Column
    for (final col in activeStorey.columns) {
      final distPerp = (col.center - rawCenter).dx * nWall.dx +
          (col.center - rawCenter).dy * nWall.dy;
      if (distPerp.abs() <= toleranceCad) {
        final snapped = rawCenter + nWall * distPerp;
        final guideStart = snapped - uWall * (halfLen + 2.0);
        final guideEnd = snapped + uWall * (halfLen + 2.0);
        return ShearWallMagneticAlignmentResult(
          snappedCenter: snapped,
          guideLines: [(guideStart, guideEnd)],
          description: 'column',
          markerPoint: col.center,
        );
      }
    }

    // 5. Parallel to DXF Underlay wall lines
    if (dxfDocument != null) {
      for (final entity in dxfDocument.entities) {
        if (entity is DxfLine) {
          final p1 = entity.p1;
          final p2 = entity.p2;
          final lVec = p2 - p1;
          final lLen = lVec.distance;
          if (lLen < 0.3 * cadUnitsPerMeter) continue;
          final uLine = lVec / lLen;
          final nLine = Offset(-uLine.dy, uLine.dx);

          final dot = (uWall.dx * uLine.dx + uWall.dy * uLine.dy).abs();
          if (dot > 0.94) {
            final distPerp = (rawCenter - p1).dx * nLine.dx + (rawCenter - p1).dy * nLine.dy;
            if (distPerp.abs() <= toleranceCad) {
              final snapped = rawCenter - nLine * distPerp;
              return ShearWallMagneticAlignmentResult(
                snappedCenter: snapped,
                guideLines: [(p1 - uLine * 1.5, p2 + uLine * 1.5)],
                description: 'dxfLine',
                markerPoint: snapped,
              );
            }
          }
        }
      }
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
