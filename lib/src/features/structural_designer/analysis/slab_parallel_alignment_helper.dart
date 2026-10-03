import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart';

/// Result of magnetic parallel line alignment (прилепване към успоредна линия)
/// during slab edge dragging, similar to ArchiCAD.
class SlabParallelAlignmentResult {
  /// The target parallel offset distance in CAD units.
  final double distance;

  /// Start point of the parallel reference line segment.
  final Offset refStart;

  /// End point of the parallel reference line segment.
  final Offset refEnd;

  /// Human-readable source descriptor (e.g. 'dxfLine', 'slab', 'wall', 'beam', 'gridAxis').
  final String source;

  /// Difference between raw pointer distance and snapped distance in CAD units.
  final double delta;

  const SlabParallelAlignmentResult({
    required this.distance,
    required this.refStart,
    required this.refEnd,
    required this.source,
    required this.delta,
  });
}

/// Intelligent magnetic alignment helper for slab edge offsetting.
/// Matches dragged edges to any parallel reference lines from the DXF underlay,
/// other slabs, shear walls, beams, columns, and grid axes.
class SlabParallelAlignmentHelper {
  const SlabParallelAlignmentHelper._();

  /// Searches for any line segment in the project that is parallel to the dragged edge
  /// [edgeV1]->[edgeV2] and whose offset distance along [gripNormal] matches [rawDistance]
  /// within [toleranceCad].
  static SlabParallelAlignmentResult? findParallelEdgeAlignment({
    required Offset edgeV1,
    required Offset edgeV2,
    required Offset gripNormal,
    required double rawDistance,
    required double toleranceCad,
    DxfDocument? document,
    required StoreyLevel activeStorey,
    String? activeSlabId,
    StoreyLevel? ghostStorey,
    double cadUnitsPerMeter = 1.0,
  }) {
    final edgeVec = edgeV2 - edgeV1;
    final edgeLen = edgeVec.distance;
    if (edgeLen < 1e-4) return null;

    final uEdge = edgeVec / edgeLen;
    final mid = (edgeV1 + edgeV2) / 2.0;

    // Collect reference line segments
    final List<(Offset, Offset, String)> candidateSegments = [];

    // 1. Other slabs in active storey and ghost storey
    final storeys = [activeStorey, ?ghostStorey];
    for (final storey in storeys) {
      for (final slab in storey.slabs) {
        final isSameSlab = (activeSlabId != null && slab.id == activeSlabId);
        final poly = slab.polygon;
        final count = poly.length;
        for (int i = 0; i < count; i++) {
          final p1 = poly[i];
          final p2 = poly[(i + 1) % count];
          if (isSameSlab) {
            // Skip the dragged edge itself
            if (((p1 - edgeV1).distance < 1e-3 && (p2 - edgeV2).distance < 1e-3) ||
                ((p1 - edgeV2).distance < 1e-3 && (p2 - edgeV1).distance < 1e-3)) {
              continue;
            }
          }
          candidateSegments.add((p1, p2, 'slab'));
        }
        for (final op in slab.openings) {
          for (int i = 0; i < op.length; i++) {
            candidateSegments.add((op[i], op[(i + 1) % op.length], 'slabOpening'));
          }
        }
      }

      // 2. Structural walls
      for (final wall in storey.shearWalls) {
        candidateSegments.add((wall.start, wall.end, 'wall'));
        final poly = wall.polygonVertices;
        if (poly.length >= 4) {
          candidateSegments.add((poly[2], poly[3], 'wall'));
        }
      }

      // 3. Structural beams
      for (final beam in storey.beams) {
        candidateSegments.add((beam.start, beam.end, 'beam'));
        final poly = beam.polygonVertices;
        if (poly.length >= 4) {
          candidateSegments.add((poly[0], poly[1], 'beam'));
          candidateSegments.add((poly[2], poly[3], 'beam'));
        }
      }

      // 4. Grid axes
      for (final axis in storey.gridAxes) {
        candidateSegments.add((axis.start, axis.end, 'gridAxis'));
      }

      // 5. Columns
      for (final col in storey.columns) {
        final poly = col.polygonVertices;
        for (int i = 0; i < poly.length; i++) {
          candidateSegments.add((poly[i], poly[(i + 1) % poly.length], 'column'));
        }
      }
    }

    // 6. DXF Underlay lines and segments
    if (document != null) {
      final searchBox = Rect.fromCenter(
        center: mid,
        width: math.max(edgeLen * 3.0, 50.0 * cadUnitsPerMeter),
        height: math.max(edgeLen * 3.0, 50.0 * cadUnitsPerMeter),
      );
      final Iterable<DxfEntity> entities;
      if (document.spatialIndex != null) {
        entities = document.spatialIndex!.query(searchBox);
      } else {
        entities = document.entities;
      }

      for (final entity in entities) {
        final layer = document.layers[entity.layer];
        if (layer != null && !layer.isVisible) continue;

        if (entity is DxfLine) {
          candidateSegments.add((entity.p1, entity.p2, 'dxfLine'));
        } else if (entity is DxfLwPolyline) {
          final vertices = entity.vertices;
          for (int i = 0; i < vertices.length - 1; i++) {
            candidateSegments.add((vertices[i].offset, vertices[i + 1].offset, 'dxfPolyline'));
          }
          if (entity.isClosed && vertices.length > 2) {
            candidateSegments.add((vertices.last.offset, vertices.first.offset, 'dxfPolyline'));
          }
        } else if (entity is DxfPolyline) {
          final vertices = entity.vertices;
          for (int i = 0; i < vertices.length - 1; i++) {
            candidateSegments.add((vertices[i].offset, vertices[i + 1].offset, 'dxfPolyline'));
          }
          if (entity.isClosed && vertices.length > 2) {
            candidateSegments.add((vertices.last.offset, vertices.first.offset, 'dxfPolyline'));
          }
        } else if (entity is DxfInsert) {
          final block = document.blocks[entity.blockName];
          if (block != null && block.entities.isNotEmpty) {
            final rad = entity.rotationDeg * math.pi / 180.0;
            final cosA = math.cos(rad);
            final sinA = math.sin(rad);
            final bx = block.basePoint.dx;
            final by = block.basePoint.dy;

            Offset transformPt(Offset pt) {
              final lx = (pt.dx - bx) * entity.scaleX;
              final ly = (pt.dy - by) * entity.scaleY;
              final rx = lx * cosA - ly * sinA;
              final ry = lx * sinA + ly * cosA;
              return Offset(entity.insertPoint.dx + rx, entity.insertPoint.dy + ry);
            }

            for (final child in block.entities) {
              final childLayer = document.layers[child.layer];
              if (childLayer != null && !childLayer.isVisible) continue;
              if (child is DxfLine) {
                candidateSegments.add((transformPt(child.p1), transformPt(child.p2), 'dxfBlock'));
              }
            }
          }
        }
      }
    }

    // Test candidate segments for parallelism & magnetic alignment
    SlabParallelAlignmentResult? bestResult;
    double bestScore = double.infinity;

    for (final seg in candidateSegments) {
      final pA = seg.$1;
      final pB = seg.$2;
      final segVec = pB - pA;
      final segLen = segVec.distance;
      if (segLen < 1e-4) continue;

      final uSeg = segVec / segLen;

      // Parallel check: cross product |uEdge x uSeg|
      final cross = (uEdge.dx * uSeg.dy - uEdge.dy * uSeg.dx).abs();
      if (cross > 0.045) continue; // Not parallel (> ~2.5 deg)

      // Signed distance from mid to the infinite line AB along gripNormal
      final double dTarget = (pA.dx - mid.dx) * gripNormal.dx + (pA.dy - mid.dy) * gripNormal.dy;
      final double delta = (rawDistance - dTarget).abs();

      if (delta <= toleranceCad) {
        // Longitudinal proximity score (favor segments that overlap the edge)
        final projA = (pA.dx - mid.dx) * uEdge.dx + (pA.dy - mid.dy) * uEdge.dy;
        final projB = (pB.dx - mid.dx) * uEdge.dx + (pB.dy - mid.dy) * uEdge.dy;
        final minP = math.min(projA, projB);
        final maxP = math.max(projA, projB);
        final halfL = edgeLen / 2.0;

        final double gap;
        if (maxP < -halfL) {
          gap = -halfL - maxP;
        } else if (minP > halfL) {
          gap = minP - halfL;
        } else {
          gap = 0.0;
        }

        final double score = delta + 0.15 * gap;
        if (score < bestScore) {
          bestScore = score;
          bestResult = SlabParallelAlignmentResult(
            distance: dTarget,
            refStart: pA,
            refEnd: pB,
            source: seg.$3,
            delta: delta,
          );
        }
      }
    }

    return bestResult;
  }
}
