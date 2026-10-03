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

  const ColumnMagneticAlignmentResult({
    required this.snappedCenter,
    required this.guideLines,
    required this.description,
    this.markerPoint,
  });
}

/// Magnetic alignment result for shear walls.
class ShearWallMagneticAlignmentResult {
  final Offset snappedCenter;
  final double? snappedRotationRad;
  final List<(Offset, Offset)> guideLines;
  final String description;
  final Offset? markerPoint;

  const ShearWallMagneticAlignmentResult({
    required this.snappedCenter,
    this.snappedRotationRad,
    required this.guideLines,
    required this.description,
    this.markerPoint,
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

  /// Aligns a column center to structural grid axes, other column coordinates (X/Y),
  /// shear walls, beams, or DXF underlay lines.
  static ColumnMagneticAlignmentResult? alignColumn({
    required Offset rawCenter,
    required double toleranceCad,
    required StoreyLevel activeStorey,
    String? movingColumnId,
    DxfDocument? dxfDocument,
    double cadUnitsPerMeter = 1.0,
  }) {
    // 1. Grid Axes Intersections (Highest priority: column centered on axis intersection)
    final axes = activeStorey.gridAxes;
    for (int i = 0; i < axes.length; i++) {
      for (int j = i + 1; j < axes.length; j++) {
        final inter = axes[i].intersectionWith(axes[j]);
        if (inter != null && (rawCenter - inter).distance <= toleranceCad * 1.4) {
          return ColumnMagneticAlignmentResult(
            snappedCenter: inter,
            guideLines: [
              (axes[i].start, axes[i].end),
              (axes[j].start, axes[j].end),
            ],
            description: 'gridIntersection',
            markerPoint: inter,
          );
        }
      }
    }

    // 2. Single Grid Axis line alignment (column center on axis line)
    for (final axis in axes) {
      final proj = axis.projectPoint(rawCenter);
      if ((rawCenter - proj).distance <= toleranceCad) {
        return ColumnMagneticAlignmentResult(
          snappedCenter: proj,
          guideLines: [(axis.start, axis.end)],
          description: 'gridAxis',
          markerPoint: proj,
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

      // Case A: Parallel to grid axis -> magnetically lock centerline onto axis
      if (dot > 0.94) {
        final distPerp = (rawCenter - axis.start).dx * nAxis.dx +
            (rawCenter - axis.start).dy * nAxis.dy;
        if (distPerp.abs() <= toleranceCad) {
          final snapped = rawCenter - nAxis * distPerp;
          return ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(axis.start, axis.end)],
            description: 'gridAxis',
            markerPoint: snapped,
          );
        }
      }

      // Case B: Perpendicular to grid axis -> end or center touches axis
      if (dot < 0.20) {
        final pStart = rawCenter - uWall * halfLen;
        final pEnd = rawCenter + uWall * halfLen;

        // Check if start or end touches axis
        final distStart = (pStart - axis.start).dx * nAxis.dx + (pStart - axis.start).dy * nAxis.dy;
        if (distStart.abs() <= toleranceCad) {
          final snapped = rawCenter - nAxis * distStart;
          return ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(axis.start, axis.end)],
            description: 'gridAxis',
            markerPoint: pStart - nAxis * distStart,
          );
        }

        final distEnd = (pEnd - axis.start).dx * nAxis.dx + (pEnd - axis.start).dy * nAxis.dy;
        if (distEnd.abs() <= toleranceCad) {
          final snapped = rawCenter - nAxis * distEnd;
          return ShearWallMagneticAlignmentResult(
            snappedCenter: snapped,
            guideLines: [(axis.start, axis.end)],
            description: 'gridAxis',
            markerPoint: pEnd - nAxis * distEnd,
          );
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

    // 2. Shear Wall Centers, Endpoints, and Baseline Axis
    // 2a. Wall Centers
    StructuralShearWall? bestWallCenter;
    double bestWallCenterDist = double.infinity;
    for (final wall in activeStorey.shearWalls) {
      final d = (rawPoint - wall.center).distance;
      if (d <= toleranceCad && d < bestWallCenterDist) {
        bestWallCenterDist = d;
        bestWallCenter = wall;
      }
    }
    if (bestWallCenter != null) {
      final guides = <(Offset, Offset)>[(bestWallCenter.start, bestWallCenter.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestWallCenter.center));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestWallCenter.center,
        guideLines: guides,
        description: 'shearWallCenter',
        markerPoint: bestWallCenter.center,
      );
    }

    // 2b. Wall Endpoints (start / end)
    Offset? bestWallEndPt;
    StructuralShearWall? bestWallEndObj;
    double bestWallEndDist = double.infinity;
    for (final wall in activeStorey.shearWalls) {
      final dStart = (rawPoint - wall.start).distance;
      if (dStart <= toleranceCad && dStart < bestWallEndDist) {
        bestWallEndDist = dStart;
        bestWallEndPt = wall.start;
        bestWallEndObj = wall;
      }
      final dEnd = (rawPoint - wall.end).distance;
      if (dEnd <= toleranceCad && dEnd < bestWallEndDist) {
        bestWallEndDist = dEnd;
        bestWallEndPt = wall.end;
        bestWallEndObj = wall;
      }
    }
    if (bestWallEndPt != null && bestWallEndObj != null) {
      final guides = <(Offset, Offset)>[(bestWallEndObj.start, bestWallEndObj.end)];
      if (beamStart != null) {
        guides.add((beamStart, bestWallEndPt));
      }
      return BeamMagneticAlignmentResult(
        snappedPoint: bestWallEndPt,
        guideLines: guides,
        description: 'shearWallEnd',
        markerPoint: bestWallEndPt,
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
