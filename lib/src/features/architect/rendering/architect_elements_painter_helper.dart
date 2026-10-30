import '../models/architect_contour.dart';
import '../models/architect_line_style.dart';
import 'architect_hatch_geometry.dart';
import 'architect_line_pattern.dart';
import 'architect_vector_scene.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'architect_stair_plan_painter.dart';
import 'architect_canvas_palette.dart';
// === SECTION: ARCHITECTURAL ELEMENTS PAINTER HELPER ===
import 'dart:math' as math;
import 'architect_polygon_painter.dart';
import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_quadtree.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_grid_axis.dart';
import '../services/component_geometry_cache.dart';
import '../services/component_library_service.dart';
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
      architectDrawingSources(canvas, {slab.id}, 'slabs');
      if (slab.polygon.length < 3) continue;
      final isSelected = slab.id == selectedElementId;
      final border = isSelected
          ? (Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 2.5 / zoomScale
              ..style = PaintingStyle.stroke)
          : slabBorderPaint;

      final path = ArchitectContour.path(slab.polygon, slab.holes);

      if (isSelected) canvas.drawPath(path, slabFillPaint);
      canvas.drawPath(path, border);

      if (ArchitectTextScope.current != null || zoomScale > 12.0) {
        final c = slab.centroid;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(ArchitectPaperStyle.annotationScale);
        final tp = ArchitectTextPainter(elementId: slab.id, role: ArchitectAnnotationRole.ordinary, modelScale: ArchitectPaperStyle.annotationScale,
          text: TextSpan(
            children: [
              ArchitectAnnotationSpan(role: ArchitectAnnotationRole.ordinary, text: '${slab.label}\n'),
              ArchitectAnnotationSpan(role: ArchitectAnnotationRole.area, text: ArchitectTextScope.current?.area(slab.area) ?? '${BimDistanceUnit.trimZeros(slab.area.toStringAsFixed(2))} m²'),
            ],
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
      architectDrawingSources(canvas, {beam.id}, 'beams');
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

      canvas.drawPath(path, paint);

      // Centerline
      canvas.drawLine(beam.startPoint, beam.endPoint, paint);

      if (ArchitectTextScope.current != null || zoomScale > 15.0) {
        final mid = (beam.startPoint + beam.endPoint) / 2.0;
        canvas.save();
        canvas.translate(mid.dx, mid.dy);
        canvas.rotate(ArchitectDimensionLayout.textAngle(beam.unitVector));
        final scope = ArchitectTextScope.current;
        final fontSize = scope?.fontSize(beam.id, ArchitectAnnotationRole.ordinary) ??
            11 * ArchitectPaperStyle.annotationScale;
        final tp = ArchitectTextPainter(elementId: beam.id, role: ArchitectAnnotationRole.ordinary, modelScale: 1,
          text: TextSpan(
            text: beam.label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : palette.foreground(const Color(0xFF263238)),
              fontFamily: 'Roboto',
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Like column lettering, fit the designation to the physical element.
        final fit = math.min(1.0, math.min(
          beam.width * .8 / math.max(tp.height, .0001),
          beam.length * .8 / math.max(tp.width, .0001)));
        canvas.scale(fit);
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
      architectDrawingSources(canvas, {op.id}, 'openings');
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
          ..color = Colors.transparent
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(path, pBorder);

      // Diagonal X mark across opposite corners
      if (op.boundary.length == 4) {
        canvas.drawLine(op.boundary[0], op.boundary[2], crossPaint);
        canvas.drawLine(op.boundary[1], op.boundary[3], crossPaint);
      }

      if (ArchitectTextScope.current != null || zoomScale > 12.0) {
        final c = op.centroid;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(ArchitectPaperStyle.annotationScale);
        final tp = ArchitectTextPainter(elementId: op.id, role: ArchitectAnnotationRole.ordinary, modelScale: ArchitectPaperStyle.annotationScale,
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
    required Canvas canvas, required ArchitectStorey storey,
    required double zoomScale, String? selectedElementId,
    ArchitectProject? project, AppLocalizations? l10n,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) {
    for (final stair in storey.stairs) {
      drawStair(canvas: canvas, stair: stair, zoomScale: zoomScale,
        storey: storey, project: project, cutHeight: storey.cutPlaneHeight,
        l10n: l10n, dimensionScale: dimensionScale, background: palette.background,
        color: stair.id == selectedElementId ? const Color(0xFF00E5FF) :
          stair.design?.isDraft == true ? const Color(0xFFD32F2F) :
          palette.foreground(const Color(0xFF1B5E20)));
    }
  }

  static void drawStair({required Canvas canvas, required ArchitectStair stair,
    required double zoomScale, Color color = const Color(0xFF1B5E20),
    Color background = Colors.white, double? cutHeight,
    ArchitectStorey? storey, ArchitectProject? project, AppLocalizations? l10n,
    bool labels = true,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) => ArchitectStairPlanPainter.draw(canvas: canvas, stair: stair,
    scale: zoomScale, color: color, background: background, cutHeight: cutHeight,
    storey: storey, project: project, l10n: l10n, labels: labels, dimensionScale: dimensionScale);

  // ===========================================================================
  // 7. DIMENSIONS
  // ===========================================================================

  static void drawDimensions({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    ArchitectStorey? dimensionStorey,
    List<StructuralGridAxis> gridAxes = const [],
    required double zoomScale,
    String? selectedElementId,
    Path? wallObstacles,
    ArchitectUnit unit = ArchitectUnit.meters,
    int? decimals,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) {
    for (final dim in storey.dimensions) {
      architectDrawingSources(canvas, {dim.id}, 'dimensions');
      final isSelected = dim.id == selectedElementId;
      if (dim.length < 1e-4) continue;
      final u = dim.unitVector;
      final n = dim.normal;
      final points = dim.dimensionPoints;
      if (points.length < 2) continue;
      final scope = ArchitectTextScope.current;
      final paperScale = ArchitectDrawingScale(scope?.denominator ?? dimensionScale.denominator);
      final annotationScale = ArchitectDimensionScale.values.firstWhere(
        (s) => s.denominator == paperScale.denominator);

      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: zoomScale,
        storey: dimensionStorey ?? storey,
        gridAxes: gridAxes,
        dimensionScale: annotationScale,
      );
      if (tiers.isEmpty) continue;

      final dimPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(const Color(0xFF37474F))
        ..strokeWidth = isSelected ? 2 / zoomScale : paperScale.paperToModel(.125)
        ..style = PaintingStyle.stroke;

      final witnessPaint = Paint()
        ..color = palette.foreground(const Color(0xFF78909C))
        ..strokeWidth = paperScale.paperToModel(.1)
        ..style = PaintingStyle.stroke;

      for (final segment in ArchitectDimensionLayout.witnessSegments(
        dim,
        tiers,
        dimensionScale: annotationScale,
      )) {
        canvas.drawLine(segment.$1, segment.$2, witnessPaint);
      }
      if (isSelected) {
        final draftingScale = math.max(zoomScale, 80.0);
        for (final witness in dim.witnessPoints) {
          canvas.drawCircle(witness, 3 / draftingScale, dimPaint);
        }
      }

      final tickSize = paperScale.paperToModel(.8);
      final tickVec = (u + n) * (tickSize / 1.414);
      final outward = n * (dim.offsetDistance < 0 ? -1 : 1);

      // Paper-space size converted to model metres, independent of camera zoom.
      final modelTextHeight = scope?.height(dim.id, ArchitectAnnotationRole.dimension) ?? annotationScale.textHeight;
      final textScale = modelTextHeight / ArchitectDrawingScale.fontCapRatio / 11.0;

      for (final tier in tiers) {
        // Dimension line
        canvas.drawLine(tier.line.$1, tier.line.$2, dimPaint);

        // Architectural 45-degree ticks
        for (final point in tier.points) {
          canvas.drawLine(point - tickVec, point + tickVec, dimPaint);
        }

        // Dimension text
        for (
          var segmentIndex = 0;
          segmentIndex < tier.segments.length;
          segmentIndex++
        ) {
          final segment = tier.segments[segmentIndex];
          final p1 = segment.$1, p2 = segment.$2;
          final isSingleSegment =
              tier.segments.length == 1 &&
              (dim.style != ArchitectDimensionStyle.exterior ||
                  tier.tierIndex == 2);
          final text =
              isSingleSegment && dim.customText?.trim().isNotEmpty == true
              ? dim.customText!
              : BimDistanceUnit.trimZeros(unit
                    .toUnit((p2 - p1).distance)
                    .toStringAsFixed(
                      decimals ?? (unit == ArchitectUnit.centimeters ||
                              unit == ArchitectUnit.millimeters ? 0 : 2),
                    ));

          final tp = ArchitectTextPainter(elementId: dim.id, role: ArchitectAnnotationRole.dimension, modelScale: textScale,
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

          final textWidth = tp.width * textScale;
          final clearance = paperScale.paperToModel(.6);
          final center = ArchitectDimensionLayout.segmentTextCenter(
            tier: tier,
            segmentIndex: segmentIndex,
            direction: u,
            textWidth: textWidth,
            clearance: clearance,
          );
          final displacement = center - (p1 + p2) / 2;
          if (displacement.distance > 1e-9) {
            final sign = displacement.dx * u.dx + displacement.dy * u.dy < 0
                ? -1.0
                : 1.0;
            canvas.drawLine(
              sign < 0 ? p1 : p2,
              center + u * sign * (textWidth / 2 + clearance / 2),
              dimPaint,
            );
          }
          final lines = tp.computeLineMetrics();
          final multiline = lines.length > 1;
          final halfHeight = multiline ? tp.height * textScale / 2 : modelTextHeight / 2;
          final mid = center + outward * (halfHeight + paperScale.paperToModel(.4));
          canvas.save();
          canvas.translate(mid.dx, mid.dy);
          canvas.rotate(ArchitectDimensionLayout.textAngle(u));
          canvas.scale(textScale);
          // Position visible capitals, rather than the font's empty leading,
          // at the same paper clearance in the workspace and publication.
          final top = multiline || lines.isEmpty
              ? -tp.height / 2
              : -lines.first.baseline + modelTextHeight / textScale / 2;
          tp.paint(canvas, Offset(-tp.width / 2, top));
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
      architectDrawingSources(canvas, {marker.id}, 'elevationMarkers');
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

      final label = ArchitectTextScope.current?.length(marker.elevation) ?? marker.formattedElevation;
      canvas.save();
      canvas.translate(p.dx + s * .4, p.dy - .02);
      canvas.scale(1.0 / zoomScale);
      final tp = ArchitectTextPainter(elementId: marker.id, role: ArchitectAnnotationRole.ordinary, modelScale: 1 / zoomScale,
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
      architectDrawingSources(canvas, {ann.id}, 'annotations');
      final isSelected = ann.id == selectedElementId;
      canvas.save();
      canvas.translate(ann.position.dx, ann.position.dy);
      canvas.scale(1.0 / zoomScale);
      final tp = ArchitectTextPainter(elementId: ann.id, role: ArchitectAnnotationRole.ordinary, modelScale: 1 / zoomScale,
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
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
    String? selectedElementId,
    bool? hatchesOnly,
    bool hatchSelectionOnly = false,
  }) {
    final unitsPerMm = ArchitectDrawingScale(
      ArchitectTextScope.current?.denominator ?? dimensionScale.denominator,
    ).paperToModel(1);
    for (final prim in storey.cadPrimitives) {
      if (hatchesOnly != null && (prim.type == CadPrimitiveType.hatch) != hatchesOnly) continue;
      architectDrawingSources(canvas, {prim.id}, 'cadPrimitives');
      final isSelected = prim.id == selectedElementId;
      final paint = Paint()
        ..color = isSelected
            ? const Color(0xFF00E5FF)
            : palette.foreground(Color(prim.colorValue))
        ..strokeWidth = (isSelected ? 2.4 : prim.strokeWidth) / zoomScale
        ..style = PaintingStyle.stroke;

      if (prim.type == CadPrimitiveType.hatch) {
        final boundary = ArchitectContour.path(prim.polygonCorners, prim.holes);
        final color = Color(prim.colorValue);
        // Keep fill interiors below walls and draw only an outline in the
        // selection layer, without compounding their transparency.
        if (!hatchSelectionOnly) {
          canvas.save();
          canvas.clipPath(boundary);
          if (prim.hatchPattern.isSolid) {
            architectDrawingSources(canvas, {prim.id}, 'cadFill');
            canvas.drawPath(
              boundary,
              Paint()..color = color..style = PaintingStyle.fill,
            );
          } else {
            canvas.drawPath(
              ArchitectHatchGeometry.path(
                boundary: boundary,
                pattern: prim.hatchPattern,
                unitsPerMm: unitsPerMm,
                scale: prim.hatchScale,
                angleDeg: prim.hatchAngle,
                visibleBounds: canvas.getLocalClipBounds(),
                origin: prim.polygonCorners.first,
              ),
              Paint()..color = color..style = PaintingStyle.stroke
                ..strokeWidth = .13 * unitsPerMm,
            );
          }
          canvas.restore();
        }
        architectDrawingSources(canvas, {prim.id}, 'cadPrimitives');
        if (prim.hatchBorder || isSelected) {
          final borderColor = isSelected ? paint.color : prim.hatchPattern.isSolid
              ? palette.foreground(ArchitectPaperStyle.rule) : color;
          canvas.drawPath(
            prim.hatchBorder
                ? ArchitectLinePattern.path(boundary, prim.lineStyle, unitsPerMm)
                : boundary,
            Paint()..color = borderColor..style = PaintingStyle.stroke
              ..strokeWidth = isSelected ? paint.strokeWidth : .18 * unitsPerMm,
          );
        }
      } else if (prim.type == CadPrimitiveType.line ||
          prim.type == CadPrimitiveType.polyline) {
        canvas.drawPath(
          ArchitectLinePattern.path(
            Path()..addPolygon(prim.linePoints, false),
            prim.lineStyle,
            unitsPerMm,
          ),
          paint,
        );
      } else if (prim.type == CadPrimitiveType.rect) {
        canvas.drawPath(
          ArchitectLinePattern.path(
            ArchitectContour.path(prim.polygonCorners, prim.holes),
            prim.lineStyle,
            unitsPerMm,
          ),
          paint,
        );
      } else if (prim.type == CadPrimitiveType.circle) {
        final r = (prim.endPoint - prim.startPoint).distance;
        canvas.drawCircle(prim.startPoint, r, paint);
      }
    }
  }

  // ===========================================================================
  // 9B. ARCHITECTURAL 3D/2D COMPONENTS (FURNITURE, SANITARY, KITCHEN)
  // ===========================================================================

  static void drawComponents({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    String? selectedElementId,
    Set<String> selectedElementIds = const {},
    bool layerVisible = true,
  }) {
    if (!layerVisible || storey.components.isEmpty) return;

    for (final comp in storey.components) {
      if (!comp.isVisible) continue;
      final def = ComponentLibraryService.instance.findDefinition(comp.definitionId);
      if (def == null) continue;
      final geo = ComponentGeometryCache.instance.getOrCompute(def, comp.parameters);
      final isSelected = comp.id == selectedElementId || selectedElementIds.contains(comp.id);

      canvas.save();
      canvas.translate(comp.position.dx, comp.position.dy);
      canvas.rotate(comp.rotation);

      // 2. Outer outline
      final outlinePaint = Paint()
        ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(const Color(0xFF263238))
        ..strokeWidth = (isSelected ? 2.5 : 1.2) / zoomScale
        ..style = PaintingStyle.stroke;
      canvas.drawPath(geo.block2d.outline, outlinePaint);

      // 3. Inner detail linework
      final detailPaint = Paint()
        ..color = isSelected ? const Color(0xFF00E5FF) : palette.foreground(const Color(0xFF546E7A))
        ..strokeWidth = (isSelected ? 1.8 : 0.8) / zoomScale
        ..style = PaintingStyle.stroke;
      for (final p in geo.block2d.detailPaths) {
        canvas.drawPath(p, detailPaint);
      }

      // If selected, display insertion origin indicator
      if (isSelected) {
        final originDot = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 4.0 / zoomScale, originDot);
      }

      canvas.restore();
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
    int? decimals,
    ArchitectLineStyle lineStyle = ArchitectLineStyle.solid,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
    ArchitectStair? stairPreview,
    ArchitectStorey? stairStorey,
    ArchitectProject? stairProject,
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
      if (activeTool == ArchitectTool.opening) {
        canvas.drawRect(rect, fillPreview);
        canvas.drawRect(rect, previewPaint);
      } else {
        canvas.drawPath(
          ArchitectLinePattern.path(
            Path()..addRect(rect),
            lineStyle,
            ArchitectDrawingScale(dimensionScale.denominator).paperToModel(1),
          ),
          previewPaint,
        );
      }
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
        decimals: decimals,
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
        storey: stairStorey, project: stairProject, cutHeight: stairStorey?.cutPlaneHeight, labels: false,
          zoomScale: zoomScale,
          color: const Color(0xFF00897B),
        );
      }
    } else if (activeTool == ArchitectTool.dimension) {
      canvas.drawLine(p1, p2, previewPaint);
    } else if (activeTool == ArchitectTool.cadLine) {
      canvas.drawPath(
        ArchitectLinePattern.path(
          Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy),
          lineStyle,
          ArchitectDrawingScale(dimensionScale.denominator).paperToModel(1),
        ),
        previewPaint,
      );
      final delta = p2 - p1;
      if (delta.distance >= .001) {
        final u = delta / delta.distance;
        ArchitectPolygonPainter.dimension(
          canvas,
          p1,
          p2,
          Offset(-u.dy, u.dx),
          zoomScale,
          unit,
          decimals: decimals,
        );
      }
    } else if (activeTool == ArchitectTool.section || activeTool == ArchitectTool.elevation) {
      canvas.drawLine(p1, p2, previewPaint..strokeWidth = 2.0 / zoomScale);
      canvas.drawCircle(p1, 4 / zoomScale, previewPaint..style = PaintingStyle.fill);
      canvas.drawCircle(p2, 4 / zoomScale, previewPaint);
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
          decimals: decimals,
        );
      }
    } else if (activeTool == ArchitectTool.measure) {
      canvas.drawLine(p1, p2, previewPaint);
      final dist = (p2 - p1).distance;
      final mid = (p1 + p2) / 2.0;
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(1.0 / zoomScale);
      final tp = ArchitectTextPainter(
        text: TextSpan(
          text: unit.format(dist, decimals: decimals),
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

    final draftingScale = math.max(zoomScale, 80.0);
    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / draftingScale
      ..style = PaintingStyle.stroke;

    final vertexPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5 / draftingScale, vertexPaint);
      if (i > 0) {
        canvas.drawLine(points[i - 1], points[i], linePaint);
      }
    }

    if (candidatePoint != null && points.isNotEmpty) {
      final dashPaint = Paint()
        ..color = const Color(0xFFFFD600)
        ..strokeWidth = 1.4 / draftingScale
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points.last, candidatePoint, dashPaint);
      canvas.drawCircle(candidatePoint, 3.5 / draftingScale, dashPaint);
    }
  }
}
