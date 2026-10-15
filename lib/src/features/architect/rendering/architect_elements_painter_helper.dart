import 'architect_canvas_palette.dart';
// === SECTION: ARCHITECTURAL ELEMENTS PAINTER HELPER ===
import 'dart:math' as math;
import 'architect_polygon_painter.dart';
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_quadtree.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_2d_painter.dart';
import 'architect_dimension_layout.dart';

/// Canvas painter helper for specialized architectural drawing elements
/// (windows, columns, beams, slabs, openings, stairs, annotations, dimensions, and CAD underlays).
class ArchitectElementsPainterHelper {
  ArchitectElementsPainterHelper._();
  static final _indexes = Expando<DxfQuadTree>();
  static final _paths = Expando<Path>();

  // ===========================================================================
  // 1. CAD UNDERLAY (DXF/DWG BACKGROUND)
  // ===========================================================================

  static void drawUnderlay({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required DxfDocument? underlayDoc,
    required double zoomScale,
    required Map<String, bool> layerVisibility,
    Rect? visibleRect,
  }) {
    if (underlayDoc == null || underlayDoc.entities.isEmpty) return;

    final underlayPaint = Paint()
      ..color = palette.underlay
      ..strokeWidth = 0.8 / zoomScale
      ..style = PaintingStyle.stroke;

    final entities = visibleRect == null
        ? underlayDoc.entities
        : (_indexes[underlayDoc] ??=
                  underlayDoc.spatialIndex ??
                  DxfQuadTree.build(
                    underlayDoc.entities,
                    underlayDoc.blocks,
                    underlayDoc.bounds,
                  ))
              .query(visibleRect);
    for (final entity in entities) {
      if (layerVisibility[entity.layer] == false ||
          (layerVisibility[entity.layer] == null &&
              underlayDoc.layers[entity.layer]?.isVisible == false)) {
        continue;
      }

      if (entity is DxfLine) {
        canvas.drawLine(entity.p1, entity.p2, underlayPaint);
      } else if (entity is DxfLwPolyline) {
        if (entity.vertices.length >= 2) {
          final path =
              _paths[entity] ??
              (Path()..moveTo(entity.vertices[0].x, entity.vertices[0].y));
          if (_paths[entity] == null) {
            for (int i = 1; i < entity.vertices.length; i++) {
              path.lineTo(entity.vertices[i].x, entity.vertices[i].y);
            }
            if (entity.isClosed) path.close();
            _paths[entity] = path;
          }
          canvas.drawPath(path, underlayPaint);
        }
      } else if (entity is DxfPolyline) {
        if (entity.vertices.length >= 2) {
          final path =
              _paths[entity] ??
              (Path()..moveTo(entity.vertices[0].x, entity.vertices[0].y));
          if (_paths[entity] == null) {
            for (int i = 1; i < entity.vertices.length; i++) {
              path.lineTo(entity.vertices[i].x, entity.vertices[i].y);
            }
            if (entity.isClosed) path.close();
            _paths[entity] = path;
          }
          canvas.drawPath(path, underlayPaint);
        }
      } else if (entity is DxfCircle) {
        canvas.drawCircle(entity.center, entity.radius, underlayPaint);
      } else if (entity is DxfArc) {
        final rect = Rect.fromCircle(
          center: entity.center,
          radius: entity.radius,
        );
        final startAngle = entity.startAngleDeg * math.pi / 180.0;
        double sweepAngle =
            (entity.endAngleDeg - entity.startAngleDeg) * math.pi / 180.0;
        if (sweepAngle < 0) sweepAngle += 2 * math.pi;
        canvas.drawArc(rect, startAngle, sweepAngle, false, underlayPaint);
      }
    }
  }

  // ===========================================================================
  // 2. SLABS
  // ===========================================================================

  static void drawSlabs({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    final slabFillPaint = Paint()
      ..color = const Color(0x1F78909C)
      ..style = PaintingStyle.fill;

    final slabBorderPaint = Paint()
      ..color = palette.foreground(const Color(0xFF546E7A))
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final slab in storey.slabs) {
      if (slab.polygon.length < 3) continue;
      final isSelected = slab.id == selectedElementId;
      final border = isSelected
          ? (Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 2.5 / zoomScale
              ..style = PaintingStyle.stroke)
          : slabBorderPaint;

      final path = Path()..moveTo(slab.polygon[0].dx, slab.polygon[0].dy);
      for (int i = 1; i < slab.polygon.length; i++) {
        path.lineTo(slab.polygon[i].dx, slab.polygon[i].dy);
      }
      path.close();

      canvas.drawPath(path, slabFillPaint);
      canvas.drawPath(path, border);

      if (zoomScale > 12.0) {
        final c = slab.centroid;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1.0 / zoomScale);
        final tp = TextPainter(
          text: TextSpan(
            text: '${slab.label}\n${slab.area.toStringAsFixed(1)} m²',
            style: TextStyle(
              color: palette.foreground(const Color(0xFF37474F)),
              fontFamily: 'Roboto',
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  // ===========================================================================
  // 3. BEAMS
  // ===========================================================================

  static void drawBeams({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final beam in storey.beams) {
      final isSelected = beam.id == selectedElementId;
      final isCut = beam.isCutAt(storey.cutPlaneHeight);
      final isOverhead = beam.isOverheadAt(storey.cutPlaneHeight);
      final strokeW = isSelected
          ? 2.2
          : (isCut
              ? ArchitectLineWeights.cutHeavy
              : (isOverhead
                  ? ArchitectLineWeights.overhead
                  : ArchitectLineWeights.projection));

      final paint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(const Color(0xFF37474F))
        ..strokeWidth = strokeW / zoomScale
        ..style = PaintingStyle.stroke;

      final corners = beam.polygonCorners;
      final path = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x18000000)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(path, paint);

      // Centerline
      canvas.drawLine(beam.startPoint, beam.endPoint, paint);

      if (zoomScale > 15.0) {
        final mid = (beam.startPoint + beam.endPoint) / 2.0;
        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        canvas.scale(1.0 / zoomScale);
        final tp = TextPainter(
          text: TextSpan(
            text: beam.label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : palette.foreground(const Color(0xFF263238)),
              fontFamily: 'Roboto',
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  // ===========================================================================
  // 4. COLUMNS
  // ===========================================================================

  static void drawColumns({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final col in storey.columns) {
      col.paint2D(
        palette: palette,
        canvas: canvas,
        zoomScale: zoomScale,
        isSelected: col.id == selectedElementId,
        cutPlaneHeight: storey.cutPlaneHeight,
        defaultStoreyHeight: storey.height,
      );
    }
  }

  // ===========================================================================
  // 5. OPENINGS / SHAFTS
  // ===========================================================================

  static void drawOpenings({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    final borderPaint = Paint()
      ..color = palette.foreground(const Color(0xFFBF360C))
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;

    final crossPaint = Paint()
      ..color = palette
          .foreground(const Color(0xFFD84315))
          .withValues(alpha: 0.7)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final op in storey.openings) {
      if (op.boundary.length < 3) continue;
      final isSelected = op.id == selectedElementId;
      final pBorder = isSelected
          ? (Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 2.4 / zoomScale
              ..style = PaintingStyle.stroke)
          : borderPaint;

      final path = Path()..moveTo(op.boundary[0].dx, op.boundary[0].dy);
      for (int i = 1; i < op.boundary.length; i++) {
        path.lineTo(op.boundary[i].dx, op.boundary[i].dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x1AFF5722)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(path, pBorder);

      // Diagonal X mark across opposite corners
      if (op.boundary.length == 4) {
        canvas.drawLine(op.boundary[0], op.boundary[2], crossPaint);
        canvas.drawLine(op.boundary[1], op.boundary[3], crossPaint);
      }

      if (zoomScale > 12.0) {
        final c = op.centroid;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1.0 / zoomScale);
        final tp = TextPainter(
          text: TextSpan(
            text: op.label,
            style: TextStyle(
              color: palette.foreground(const Color(0xFFBF360C)),
              fontFamily: 'Roboto',
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  // ===========================================================================
  // 6. STAIRS
  // ===========================================================================

  static void drawStairs({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final stair in storey.stairs) {
      drawStair(
        canvas: canvas,
        stair: stair,
        zoomScale: zoomScale,
        color: stair.id == selectedElementId
            ? const Color(0xFF00E5FF)
            : stair.design?.isDraft == true
            ? const Color(0xFFD32F2F)
            : palette.foreground(const Color(0xFF1B5E20)),
      );
    }
  }

  static void drawStair({
    required Canvas canvas,
    required ArchitectStair stair,
    required double zoomScale,
    Color color = const Color(0xFF1B5E20),
  }) {
    final plan = stair.plan;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(plan.path, Paint()..color = color.withValues(alpha: .08));
    canvas.drawPath(plan.path, stroke);
    final tread = Paint()
      ..color = color
      ..strokeWidth = .9 / zoomScale;
    for (final line in plan.nosings) {
      canvas.drawLine(line.$1, line.$2, tread);
    }
    final points = plan.walkingLine;
    if (points.length < 2) return;
    final arrow = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      arrow.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(arrow, stroke);
    canvas.drawCircle(points.first, 2.5 / zoomScale, Paint()..color = color);
    final end = points.last, delta = end - points[points.length - 2];
    if (delta.distance < 1e-8) return;
    final u = delta / delta.distance, n = Offset(-u.dy, u.dx);
    final size = math.min(.18, stair.width * .18);
    canvas.drawLine(end, end - u * size + n * size / 2, stroke);
    canvas.drawLine(end, end - u * size - n * size / 2, stroke);
  }

  // ===========================================================================
  // 7. DIMENSIONS
  // ===========================================================================

  static void drawDimensions({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
    Path? wallObstacles,
    ArchitectUnit unit = ArchitectUnit.meters,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) {
    for (final dim in storey.dimensions) {
      final isSelected = dim.id == selectedElementId;
      if (dim.length < 1e-4) continue;
      final u = dim.unitVector;
      final n = dim.normal;
      final points = dim.dimensionPoints;
      if (points.length < 2) continue;

      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: zoomScale,
        storey: storey,
      );
      if (tiers.isEmpty) continue;

      final dimPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(const Color(0xFF37474F))
        ..strokeWidth = (isSelected ? 2.0 : 1.0) / zoomScale
        ..style = PaintingStyle.stroke;

      final witnessPaint = Paint()
        ..color = palette.foreground(const Color(0xFF78909C))
        ..strokeWidth = 0.8 / zoomScale
        ..style = PaintingStyle.stroke;

      for (final segment in ArchitectDimensionLayout.witnessSegments(
        dim,
        tiers,
        dimensionScale: dimensionScale,
      )) {
        canvas.drawLine(segment.$1, segment.$2, witnessPaint);
      }
      if (isSelected) {
        for (final witness in dim.witnessPoints) {
          canvas.drawCircle(witness, 3 / zoomScale, dimPaint);
        }
      }

      final tickSize = dimensionScale.paperToModel(.8);
      final tickVec = (u + n) * (tickSize / 1.414);
      final outward = n * (dim.offsetDistance < 0 ? -1 : 1);

      // Paper-space size converted to model metres, independent of camera zoom.
      final modelTextHeight = dimensionScale.textHeight;
      final textOffset =
          outward * (modelTextHeight * 0.55 + dimensionScale.paperToModel(.4));
      final textScale = modelTextHeight / 11.0;

      for (final tier in tiers) {
        // Dimension line
        canvas.drawLine(tier.line.$1, tier.line.$2, dimPaint);

        // Architectural 45-degree ticks
        for (final point in tier.points) {
          canvas.drawLine(point - tickVec, point + tickVec, dimPaint);
        }

        // Dimension text
        for (final segment in tier.segments) {
          final p1 = segment.$1, p2 = segment.$2;
          final isSingleSegment =
              tier.segments.length == 1 && tier.tierIndex == 1;
          final text =
              isSingleSegment && dim.customText?.trim().isNotEmpty == true
              ? dim.customText!
              : unit
                    .toUnit((p2 - p1).distance)
                    .toStringAsFixed(
                      unit == ArchitectUnit.centimeters ||
                              unit == ArchitectUnit.millimeters
                          ? 0
                          : 2,
                    );

          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : palette.foreground(const Color(0xFF263238)),
                fontFamily: 'Roboto',
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final mid = (p1 + p2) / 2.0 + textOffset;
          canvas.save();
          canvas.translate(mid.dx, mid.dy);
          double angle = math.atan2(u.dy, u.dx);
          if (angle > math.pi / 2 || angle < -math.pi / 2) angle += math.pi;
          canvas.rotate(angle);
          canvas.scale(textScale);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }
      }
    }
  }

  // ===========================================================================
  // 8. ELEVATION MARKERS & ANNOTATIONS
  // ===========================================================================

  static void drawElevationMarkers({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final marker in storey.elevationMarkers) {
      final isSelected = marker.id == selectedElementId;
      final p = marker.position;
      final color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFFD81B60));

      final markerPaint = Paint()
        ..color = color
        ..strokeWidth = 1.2 / zoomScale
        ..style = PaintingStyle.stroke;

      // Architectural elevation arrowhead symbol
      const s = 0.20;
      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx - s, p.dy + s * 1.5)
        ..lineTo(p.dx + s, p.dy + s * 1.5)
        ..close();

      canvas.drawPath(path, markerPaint);
      canvas.drawLine(p, Offset(p.dx + s * 3.0, p.dy), markerPaint);

      final label = marker.formattedElevation;
      canvas.save();
      canvas.translate(p.dx + s * .4, p.dy - .02);
      canvas.scale(1.0 / zoomScale);
      final tp = TextPainter(
        text: TextSpan(
          text: marker.label != null ? '$label (${marker.label})' : label,
          style: TextStyle(
            color: color,
            fontFamily: 'Roboto',
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, -tp.height));
      canvas.restore();
    }
  }

  static void drawAnnotations({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final ann in storey.annotations) {
      final isSelected = ann.id == selectedElementId;
      canvas.save();
      canvas.translate(ann.position.dx, ann.position.dy);
      canvas.scale(1.0 / zoomScale);
      final tp = TextPainter(
        text: TextSpan(
          text: ann.text,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : palette.foreground(const Color(0xFF212121)),
            fontFamily: 'Roboto',
            fontSize: ann.fontSize * zoomScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  // ===========================================================================
  // 9. CAD PRIMITIVES
  // ===========================================================================

  static void drawCadPrimitives({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
  }) {
    for (final prim in storey.cadPrimitives) {
      final isSelected = prim.id == selectedElementId;
      final paint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(Color(prim.colorValue))
        ..strokeWidth = (isSelected ? 2.4 : prim.strokeWidth) / zoomScale
        ..style = PaintingStyle.stroke;

      if (prim.type == CadPrimitiveType.line) {
        canvas.drawLine(prim.startPoint, prim.endPoint, paint);
      } else if (prim.type == CadPrimitiveType.rect) {
        canvas.drawPath(Path()..addPolygon(prim.polygonCorners, true), paint);
      } else if (prim.type == CadPrimitiveType.circle) {
        final r = (prim.endPoint - prim.startPoint).distance;
        canvas.drawCircle(prim.startPoint, r, paint);
      }
    }
  }

  // ===========================================================================
  // 10. ACTIVE DRAFTING PREVIEW FOR NEW TOOLS
  // ===========================================================================

  static void drawActiveElementsDrafting({
    required Canvas canvas,
    required ArchitectTool activeTool,
    required Offset? draftStart,
    required Offset? draftEnd,
    required double zoomScale,
    ArchitectUnit unit = ArchitectUnit.meters,
    ArchitectStair? stairPreview,
  }) {
    if (draftStart == null || draftEnd == null) return;
    final p1 = draftStart;
    final p2 = draftEnd;

    final previewPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    final fillPreview = Paint()
      ..color = const Color(0x3300E5FF)
      ..style = PaintingStyle.fill;

    if (activeTool == ArchitectTool.column) {
      final r = 0.15;
      canvas.drawCircle(p2, r, fillPreview);
      canvas.drawCircle(p2, r, previewPaint);
    } else if (activeTool == ArchitectTool.beam) {
      canvas.drawLine(p1, p2, previewPaint);
    } else if (activeTool == ArchitectTool.opening ||
        activeTool == ArchitectTool.cadRect) {
      final rect = Rect.fromPoints(p1, p2);
      canvas.drawRect(rect, fillPreview);
      canvas.drawRect(rect, previewPaint);
      ArchitectPolygonPainter.draw(
        canvas: canvas,
        polygon: [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ],
        scale: zoomScale,
        unit: unit,
      );
      if (activeTool == ArchitectTool.opening) {
        canvas.drawLine(rect.topLeft, rect.bottomRight, previewPaint);
        canvas.drawLine(rect.topRight, rect.bottomLeft, previewPaint);
      }
    } else if (activeTool == ArchitectTool.stair) {
      if (stairPreview != null) {
        drawStair(
          canvas: canvas,
          stair: stairPreview,
          zoomScale: zoomScale,
          color: const Color(0xFF00897B),
        );
      }
    } else if (activeTool == ArchitectTool.dimension) {
      canvas.drawLine(p1, p2, previewPaint);
    } else if (activeTool == ArchitectTool.cadLine) {
      canvas.drawLine(p1, p2, previewPaint);
    } else if (activeTool == ArchitectTool.cadCircle) {
      final r = (p2 - p1).distance;
      canvas.drawCircle(p1, r, previewPaint);
      if (r > .001) {
        canvas.drawLine(p1, p2, previewPaint);
        final u = (p2 - p1) / r;
        ArchitectPolygonPainter.dimension(
          canvas,
          p1,
          p2,
          Offset(-u.dy, u.dx),
          zoomScale,
          unit,
        );
      }
    } else if (activeTool == ArchitectTool.measure) {
      canvas.drawLine(p1, p2, previewPaint);
      final dist = (p2 - p1).distance;
      final mid = (p1 + p2) / 2.0;
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(1.0 / zoomScale);
      final tp = TextPainter(
        text: TextSpan(
          text: '${unit.toUnit(dist).toStringAsFixed(2)} ${unit.symbol}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -tp.width / 2 - 4,
            -tp.height / 2 - 2,
            tp.width + 8,
            tp.height + 4,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xDD000000),
      );
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // ===========================================================================
  // 11. SLAB DRAFTING INTERACTION
  // ===========================================================================

  static void drawSlabDrafting({
    required Canvas canvas,
    required List<Offset> points,
    required Offset? candidatePoint,
    required double zoomScale,
  }) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    final vertexPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5 / zoomScale, vertexPaint);
      if (i > 0) {
        canvas.drawLine(points[i - 1], points[i], linePaint);
      }
    }

    if (candidatePoint != null && points.isNotEmpty) {
      final dashPaint = Paint()
        ..color = const Color(0xFFFFD600)
        ..strokeWidth = 1.4 / zoomScale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points.last, candidatePoint, dashPaint);
      canvas.drawCircle(candidatePoint, 3.5 / zoomScale, dashPaint);
    }
  }
}
