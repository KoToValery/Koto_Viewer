import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_color_table.dart';
import '../models/dxf_display_settings.dart';
import '../models/dxf_models.dart';
import 'dxf_linetype_helper.dart';
import 'dxf_math.dart';
import 'dxf_snap_helper.dart';

/// Theme presets for the CAD viewer background.
enum DxfCanvasTheme {
  darkCad(
    name: 'CAD Dark',
    bgColor: Color(0xFF14171A),
    gridColor: Color(0xFF22272E),
    isDark: true,
  ),
  paperWhite(
    name: 'Paper White',
    bgColor: Color(0xFFF8F9FA),
    gridColor: Color(0xFFE9ECEF),
    isDark: false,
  );

  final String name;
  final Color bgColor;
  final Color gridColor;
  final bool isDark;

  const DxfCanvasTheme({
    required this.name,
    required this.bgColor,
    required this.gridColor,
    required this.isDark,
  });
}

/// Measurement state model.
class DxfMeasurement {
  final Offset p1Cad;
  final Offset? p2Cad;

  const DxfMeasurement({required this.p1Cad, this.p2Cad});

  double? get distance => p2Cad != null ? (p2Cad! - p1Cad).distance : null;
  double? get deltaX => p2Cad != null ? (p2Cad!.dx - p1Cad.dx).abs() : null;
  double? get deltaY => p2Cad != null ? (p2Cad!.dy - p1Cad.dy).abs() : null;
}

/// CustomPainter for rendering entire DXF drawing.
class DxfPainter extends CustomPainter {
  final DxfDocument document;
  final DxfCanvasTheme theme;
  final double currentScale;
  final DxfMeasurement? measurement;
  final DxfEntity? highlightedEntity;
  final DxfSnapResult? snapResult;
  final bool showGrid;
  final DxfDisplaySettings settings;

  DxfPainter({
    required this.document,
    required this.theme,
    this.currentScale = 1.0,
    this.measurement,
    this.highlightedEntity,
    this.snapResult,
    this.showGrid = true,
    this.settings = const DxfDisplaySettings(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= 0 || size.height <= 0) return;

    final double docW = math.max(document.width, 1.0);
    final double docH = math.max(document.height, 1.0);

    const double padding = 32.0;
    final double availW = math.max(size.width - padding * 2, 10.0);
    final double availH = math.max(size.height - padding * 2, 10.0);

    final double fitScale = math.min(availW / docW, availH / docH);

    final double scaledW = docW * fitScale;
    final double scaledH = docH * fitScale;

    final double tx = (size.width - scaledW) / 2.0;
    final double ty = (size.height - scaledH) / 2.0;

    final double minX = document.bounds.left;
    final double maxY = document.bounds.bottom > document.bounds.top
        ? document.bounds.bottom
        : document.bounds.top;

    // Helper: convert CAD point (Y up) to Canvas point (Y down)
    Offset toCanvas(Offset cadPoint) {
      return Offset(
        tx + (cadPoint.dx - minX) * fitScale,
        ty + (maxY - cadPoint.dy) * fitScale,
      );
    }

    // 1. Draw subtle CAD background grid if enabled
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // 2. Draw Entities
    for (final entity in document.entities) {
      final layer = document.layers[entity.layer];
      if (layer != null && !layer.isVisible) {
        continue;
      }

      final color = DxfColorTable.resolveColor(
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        layerColor: layer != null
            ? DxfColorTable.resolveColor(
                colorIndex: layer.colorIndex,
                trueColor: layer.trueColor,
                isDarkBackground: theme.isDark,
              )
            : null,
        isDarkBackground: theme.isDark,
      );

      final strokeWidth = _calcStrokeWidth(entity.lineWeight, layer: layer);

      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      _renderEntity(
        canvas: canvas,
        entity: entity,
        strokePaint: strokePaint,
        fillPaint: fillPaint,
        toCanvas: toCanvas,
        fitScale: fitScale,
        blocks: document.blocks,
        layers: document.layers,
      );
    }

    // 3. Draw Highlighted Entity
    if (highlightedEntity != null) {
      _drawEntityHighlight(canvas, highlightedEntity!, toCanvas);
    }

    // 4. Draw Active Snap Marker
    if (snapResult != null) {
      _drawSnapMarker(canvas, snapResult!, toCanvas);
    }

    // 5. Draw Active Measurement Overlay
    if (measurement != null) {
      _drawMeasurement(canvas, measurement!, toCanvas);
    }
  }

  double _calcStrokeWidth(double? lineWeight, {DxfLayer? layer, bool isThick = false}) {
    final scale = currentScale.clamp(0.001, 10000.0);

    // Determine effective lineweight in millimeters:
    // 1. User custom layer override (0.12, 0.25, 0.35, 0.70 mm)
    // 2. Entity own lineweight from DXF
    // 3. Layer original lineweight from DXF
    double? mm = layer?.customLineweight ?? lineWeight ?? layer?.lineweight;

    if (mm == null && (isThick || (layer?.isThick ?? false))) {
      mm = 0.70;
    }

    if (mm != null && mm > 0) {
      // AutoCAD standard lineweight mapping (in mm) to screen canvas pixels:
      // 0.12 mm -> ~0.95 px
      // 0.25 mm -> ~1.50 px
      // 0.35 mm -> ~2.20 px
      // 0.70 mm -> ~3.80 px
      final basePx = (mm * 5.0).clamp(0.8, 14.0);
      return (basePx * settings.lineThicknessScale) / scale;
    }

    // Default crisp standard thin line (~1.1 px)
    return (1.1 * settings.lineThicknessScale) / scale;
  }

  void _drawGrid(Canvas canvas, Size size) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final gridPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 0.5 / scale
      ..isAntiAlias = true;

    final double step = _calculateGridStep(size);
    if (step <= 0) return;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  double _calculateGridStep(Size size) {
    final maxDim = math.max(size.width, size.height);
    if (maxDim <= 0) return 50.0;
    double step = 100.0;
    while (step * 20 < maxDim) {
      step *= 10.0;
    }
    while (step * 2 > maxDim && step > 10.0) {
      step /= 10.0;
    }
    return step;
  }

  void _drawStrokePath(
    Canvas canvas,
    Path path,
    Paint paint,
    String? lineType,
    String? layerLineType,
  ) {
    final pattern = DxfLinetypeHelper.resolvePattern(
      lineType,
      layerLineType: layerLineType,
      customLineTypes: document.lineTypes,
    );
    if (pattern == null) {
      canvas.drawPath(path, paint);
    } else {
      final scale = currentScale.clamp(0.001, 10000.0);
      final dashedPath = DxfLinetypeHelper.createDashedPath(
        path,
        pattern,
        scale: (1.5 * settings.lineThicknessScale) / scale,
      );
      canvas.drawPath(dashedPath, paint);
    }
  }

  void _drawStrokeLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    String? lineType,
    String? layerLineType,
  ) {
    final pattern = DxfLinetypeHelper.resolvePattern(
      lineType,
      layerLineType: layerLineType,
      customLineTypes: document.lineTypes,
    );
    if (pattern == null) {
      canvas.drawLine(p1, p2, paint);
    } else {
      final scale = currentScale.clamp(0.001, 10000.0);
      final dashedPath = DxfLinetypeHelper.createDashedLine(
        p1,
        p2,
        pattern,
        scale: (1.5 * settings.lineThicknessScale) / scale,
      );
      canvas.drawPath(dashedPath, paint);
    }
  }

  void _renderEntity({
    required Canvas canvas,
    required DxfEntity entity,
    required Paint strokePaint,
    required Paint fillPaint,
    required Offset Function(Offset) toCanvas,
    required double fitScale,
    required Map<String, DxfBlock> blocks,
    required Map<String, DxfLayer> layers,
  }) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final layer = layers[entity.layer];
    final String? layerLineType = layer?.lineType;

    if (entity is DxfLine) {
      final p1 = toCanvas(entity.p1);
      final p2 = toCanvas(entity.p2);
      _drawStrokeLine(canvas, p1, p2, strokePaint, entity.lineType, layerLineType);
    } else if (entity is DxfPoint) {
      if (settings.pointStyle == DxfPointStyle.none || settings.pointSize <= 0) {
        return;
      }
      final p = toCanvas(entity.point);
      final double markSize = math.max(0.6, (settings.pointSize * 0.45) / scale);
      final double ptStroke = (1.0 * settings.lineThicknessScale) / scale;

      final ptStrokePaint = Paint()
        ..color = strokePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ptStroke
        ..isAntiAlias = true;

      final ptFillPaint = Paint()
        ..color = strokePaint.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      switch (settings.pointStyle) {
        case DxfPointStyle.none:
          break;
        case DxfPointStyle.dot:
          canvas.drawCircle(p, markSize, ptFillPaint);
          break;
        case DxfPointStyle.cross:
          canvas.drawLine(Offset(p.dx - markSize, p.dy), Offset(p.dx + markSize, p.dy), ptStrokePaint);
          canvas.drawLine(Offset(p.dx, p.dy - markSize), Offset(p.dx, p.dy + markSize), ptStrokePaint);
          break;
        case DxfPointStyle.xCross:
          final double d = markSize * 0.7071;
          canvas.drawLine(Offset(p.dx - d, p.dy - d), Offset(p.dx + d, p.dy + d), ptStrokePaint);
          canvas.drawLine(Offset(p.dx - d, p.dy + d), Offset(p.dx + d, p.dy - d), ptStrokePaint);
          break;
        case DxfPointStyle.circle:
          canvas.drawCircle(p, markSize, ptStrokePaint);
          break;
        case DxfPointStyle.circleDot:
          canvas.drawCircle(p, markSize, ptStrokePaint);
          canvas.drawCircle(p, markSize * 0.35, ptFillPaint);
          break;
      }
    } else if (entity is DxfCircle) {
      final center = toCanvas(entity.center);
      final r = entity.radius * fitScale;
      final path = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      final double effectiveStroke = math.min(strokePaint.strokeWidth, r * 0.45).clamp(0.2, strokePaint.strokeWidth);
      final circlePaint = Paint()
        ..color = strokePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..isAntiAlias = true;
      _drawStrokePath(canvas, path, circlePaint, entity.lineType, layerLineType);
    } else if (entity is DxfArc) {
      _renderArc(canvas, entity, strokePaint, toCanvas, fitScale, entity.lineType, layerLineType);
    } else if (entity is DxfEllipse) {
      _renderEllipse(canvas, entity, strokePaint, toCanvas, entity.lineType, layerLineType);
    } else if (entity is DxfLwPolyline) {
      _renderLwPolyline(canvas, entity, strokePaint, toCanvas, entity.lineType, layerLineType);
    } else if (entity is DxfPolyline) {
      _renderPolyline(canvas, entity, strokePaint, toCanvas, entity.lineType, layerLineType);
    } else if (entity is DxfSpline) {
      _renderSpline(canvas, entity, strokePaint, toCanvas, entity.lineType, layerLineType);
    } else if (entity is DxfText) {
      _renderText(canvas, entity, strokePaint.color, toCanvas, fitScale);
    } else if (entity is DxfMText) {
      _renderMText(canvas, entity, strokePaint.color, toCanvas, fitScale);
    } else if (entity is DxfSolid) {
      _renderSolid(canvas, entity, fillPaint, strokePaint, toCanvas);
    } else if (entity is DxfHatch) {
      _renderHatch(canvas, entity, fillPaint, strokePaint, toCanvas);
    } else if (entity is DxfInsert) {
      _renderInsert(
        canvas: canvas,
        insert: entity,
        blocks: blocks,
        layers: layers,
        toCanvas: toCanvas,
        fitScale: fitScale,
      );
    } else if (entity is DxfDimension) {
      _renderDimension(canvas, entity, strokePaint, toCanvas, fitScale, blocks, layers);
    } else if (entity is DxfLeader) {
      _renderLeader(canvas, entity, strokePaint, toCanvas, entity.lineType, layerLineType);
    }
  }

  void _renderArc(
    Canvas canvas,
    DxfArc arc,
    Paint paint,
    Offset Function(Offset) toCanvas,
    double fitScale,
    String? lineType,
    String? layerLineType,
  ) {
    final double cx = arc.center.dx;
    final double cy = arc.center.dy;
    final double r = arc.radius;
    if (r <= 0) return;

    double sweep = arc.endAngleDeg - arc.startAngleDeg;
    if (sweep <= 0) sweep += 360.0;

    final int segments = (48 * (sweep / 360.0)).clamp(8, 64).toInt();
    final double step = (sweep * math.pi / 180.0) / segments;
    final double startRad = arc.startAngleDeg * math.pi / 180.0;

    final path = Path();
    final firstCad = Offset(
      cx + r * math.cos(startRad),
      cy + r * math.sin(startRad),
    );
    final firstCanvas = toCanvas(firstCad);
    path.moveTo(firstCanvas.dx, firstCanvas.dy);

    for (int i = 1; i <= segments; i++) {
      final double rad = startRad + i * step;
      final cadPoint = Offset(
        cx + r * math.cos(rad),
        cy + r * math.sin(rad),
      );
      final canvasPoint = toCanvas(cadPoint);
      path.lineTo(canvasPoint.dx, canvasPoint.dy);
    }

    final double rCanvas = arc.radius * fitScale;
    final double effectiveStroke = math.min(paint.strokeWidth, rCanvas * 0.45).clamp(0.2, paint.strokeWidth);
    final arcPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke
      ..isAntiAlias = true;

    _drawStrokePath(canvas, path, arcPaint, lineType, layerLineType);
  }

  void _renderEllipse(
    Canvas canvas,
    DxfEllipse ellipse,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType,
  ) {
    final points = DxfMath.generateEllipsePoints(
      ellipse.center,
      ellipse.majorAxisEndOffset,
      ellipse.minorRatio,
      startParam: ellipse.startParam,
      endParam: ellipse.endParam,
    );

    if (points.isEmpty) return;
    final path = Path();
    final p0 = toCanvas(points.first);
    path.moveTo(p0.dx, p0.dy);

    for (int i = 1; i < points.length; i++) {
      final p = toCanvas(points[i]);
      path.lineTo(p.dx, p.dy);
    }

    _drawStrokePath(canvas, path, paint, lineType, layerLineType);
  }

  void _renderLwPolyline(
    Canvas canvas,
    DxfLwPolyline poly,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType,
  ) {
    if (poly.vertices.isEmpty) return;

    final path = Path();
    final List<Offset> allPoints = [];

    final int count = poly.vertices.length;
    final int endIdx = poly.isClosed ? count : count - 1;

    for (int i = 0; i < endIdx; i++) {
      final v1 = poly.vertices[i];
      final v2 = poly.vertices[(i + 1) % count];

      if (v1.bulge.abs() > 1e-6) {
        final arcPoints = DxfMath.generateBulgeArcPoints(
          v1.offset,
          v2.offset,
          v1.bulge,
        );
        if (allPoints.isNotEmpty && arcPoints.isNotEmpty && (allPoints.last - arcPoints.first).distanceSquared < 1e-10) {
          allPoints.addAll(arcPoints.skip(1));
        } else {
          allPoints.addAll(arcPoints);
        }
      } else {
        if (allPoints.isEmpty || (allPoints.last - v1.offset).distanceSquared > 1e-10) {
          allPoints.add(v1.offset);
        }
        allPoints.add(v2.offset);
      }
    }

    if (allPoints.isEmpty) return;

    final first = toCanvas(allPoints.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < allPoints.length; i++) {
      final p = toCanvas(allPoints[i]);
      path.lineTo(p.dx, p.dy);
    }

    if (poly.isClosed) {
      path.close();
    }

    _drawStrokePath(canvas, path, paint, lineType, layerLineType);
  }

  void _renderPolyline(
    Canvas canvas,
    DxfPolyline poly,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType,
  ) {
    if (poly.vertices.isEmpty) return;

    final path = Path();
    final List<Offset> allPoints = [];

    final int count = poly.vertices.length;
    final int endIdx = poly.isClosed ? count : count - 1;

    for (int i = 0; i < endIdx; i++) {
      final v1 = poly.vertices[i];
      final v2 = poly.vertices[(i + 1) % count];

      if (v1.bulge.abs() > 1e-6) {
        final arcPoints = DxfMath.generateBulgeArcPoints(
          v1.offset,
          v2.offset,
          v1.bulge,
        );
        if (allPoints.isNotEmpty && arcPoints.isNotEmpty && (allPoints.last - arcPoints.first).distanceSquared < 1e-10) {
          allPoints.addAll(arcPoints.skip(1));
        } else {
          allPoints.addAll(arcPoints);
        }
      } else {
        if (allPoints.isEmpty || (allPoints.last - v1.offset).distanceSquared > 1e-10) {
          allPoints.add(v1.offset);
        }
        allPoints.add(v2.offset);
      }
    }

    if (allPoints.isEmpty) return;

    final first = toCanvas(allPoints.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < allPoints.length; i++) {
      final p = toCanvas(allPoints[i]);
      path.lineTo(p.dx, p.dy);
    }

    if (poly.isClosed) {
      path.close();
    }

    _drawStrokePath(canvas, path, paint, lineType, layerLineType);
  }

  void _renderSpline(
    Canvas canvas,
    DxfSpline spline,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType,
  ) {
    final points = spline.controlPoints.isNotEmpty
        ? DxfMath.evaluateSpline(
            spline.degree,
            spline.controlPoints,
            knots: spline.knots,
            weights: spline.weights,
          )
        : spline.fitPoints;

    if (points.isEmpty) return;

    final path = Path();
    final p0 = toCanvas(points.first);
    path.moveTo(p0.dx, p0.dy);

    for (int i = 1; i < points.length; i++) {
      final p = toCanvas(points[i]);
      path.lineTo(p.dx, p.dy);
    }

    if (spline.isClosed) {
      path.close();
    }

    _drawStrokePath(canvas, path, paint, lineType, layerLineType);
  }

  void _renderText(
    Canvas canvas,
    DxfText entity,
    Color color,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    if (entity.text.trim().isEmpty) return;

    final fontSize = math.max(entity.height * fitScale, 0.1);
    final textPainter = TextPainter(
      text: TextSpan(
        text: entity.text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'Roboto',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final pos = toCanvas(
      ((entity.hAlign != 0 || entity.vAlign != 0) && entity.alignPoint != null)
          ? entity.alignPoint!
          : entity.insertPoint,
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    // Rotate (CAD rotation is CCW, so on canvas with Y down, rotation is -angle)
    final double rad = -entity.rotationDeg * math.pi / 180.0;
    canvas.rotate(rad);

    // Horizontal alignment offset
    double ox = 0.0;
    switch (entity.hAlign) {
      case 1: // Center
      case 4: // Middle
        ox = -textPainter.width / 2.0;
        break;
      case 2: // Right
        ox = -textPainter.width;
        break;
      default:
        ox = 0.0;
    }

    // Vertical alignment offset (0=Baseline, 1=Bottom, 2=Middle, 3=Top)
    double oy = -textPainter.height * 0.85; // Default baseline offset
    switch (entity.vAlign) {
      case 1: // Bottom
        oy = -textPainter.height;
        break;
      case 2: // Middle
        oy = -textPainter.height / 2.0;
        break;
      case 3: // Top
        oy = 0.0;
        break;
      default:
        if (entity.hAlign == 4) {
          // Special case: AutoCAD "Middle" horizontal alignment (hAlign=4, vAlign=0) is centered vertically as well
          oy = -textPainter.height / 2.0;
        } else {
          oy = -textPainter.height * 0.85;
        }
    }

    textPainter.paint(canvas, Offset(ox, oy));
    canvas.restore();
  }

  void _renderMText(
    Canvas canvas,
    DxfMText entity,
    Color color,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    if (entity.cleanText.trim().isEmpty) return;

    final fontSize = math.max(entity.height * fitScale, 0.1);
    final textPainter = TextPainter(
      text: TextSpan(
        text: entity.cleanText,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'Roboto',
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    if (entity.refWidth != null && entity.refWidth! > 0) {
      textPainter.layout(maxWidth: entity.refWidth! * fitScale);
    } else {
      textPainter.layout();
    }

    final pos = toCanvas(entity.insertPoint);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    final double rad = -entity.rotationDeg * math.pi / 180.0;
    canvas.rotate(rad);

    // Attachment Point offsets (1=TL, 2=TC, 3=TR, 4=ML, 5=MC, 6=MR, 7=BL, 8=BC, 9=BR)
    double ox = 0.0;
    double oy = 0.0;

    switch (entity.attachmentPoint) {
      case 1: // Top Left
        ox = 0;
        oy = 0;
        break;
      case 2: // Top Center
        ox = -textPainter.width / 2.0;
        oy = 0;
        break;
      case 3: // Top Right
        ox = -textPainter.width;
        oy = 0;
        break;
      case 4: // Middle Left
        ox = 0;
        oy = -textPainter.height / 2.0;
        break;
      case 5: // Middle Center
        ox = -textPainter.width / 2.0;
        oy = -textPainter.height / 2.0;
        break;
      case 6: // Middle Right
        ox = -textPainter.width;
        oy = -textPainter.height / 2.0;
        break;
      case 7: // Bottom Left
        ox = 0;
        oy = -textPainter.height;
        break;
      case 8: // Bottom Center
        ox = -textPainter.width / 2.0;
        oy = -textPainter.height;
        break;
      case 9: // Bottom Right
        ox = -textPainter.width;
        oy = -textPainter.height;
        break;
    }

    textPainter.paint(canvas, Offset(ox, oy));
    canvas.restore();
  }

  void _renderSolid(
    Canvas canvas,
    DxfSolid solid,
    Paint fillPaint,
    Paint strokePaint,
    Offset Function(Offset) toCanvas,
  ) {
    final p0 = toCanvas(solid.p0);
    final p1 = toCanvas(solid.p1);
    final p2 = toCanvas(solid.p2);
    final p3 = toCanvas(solid.p3);

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _renderHatch(
    Canvas canvas,
    DxfHatch hatch,
    Paint fillPaint,
    Paint strokePaint,
    Offset Function(Offset) toCanvas,
  ) {
    if (hatch.boundaryPaths.isEmpty) return;

    final path = Path()..fillType = PathFillType.evenOdd;
    for (final loop in hatch.boundaryPaths) {
      if (loop.isEmpty) continue;
      final p0 = toCanvas(loop.first);
      path.moveTo(p0.dx, p0.dy);
      for (int i = 1; i < loop.length; i++) {
        final p = toCanvas(loop[i]);
        path.lineTo(p.dx, p.dy);
      }
      path.close();
    }

    // 1. Determine effective transparency / fill opacity
    double effectiveOpacity = 0.35; // standard default fill opacity
    if (hatch.transparency != null) {
      effectiveOpacity = hatch.transparency!.clamp(0.02, 1.0);
    } else {
      final nameUpper = hatch.patternName.toUpperCase();
      final layerUpper = hatch.layer.toUpperCase();
      if (nameUpper.contains('10%') ||
          nameUpper.contains('SHADOW') ||
          nameUpper.contains('СЕНКИ') ||
          nameUpper.contains('SENKA') ||
          nameUpper.contains('СЯНКА') ||
          layerUpper.contains('SHADOW') ||
          layerUpper.contains('СЕНКИ') ||
          layerUpper.contains('СЯНКА') ||
          layerUpper.contains('SENKA') ||
          layerUpper.contains('TRANSP')) {
        effectiveOpacity = 0.10; // ArchiCAD shadow fill (~10% opacity)
      } else if (nameUpper.contains('25%') || nameUpper.contains('SOLID_25')) {
        effectiveOpacity = 0.25;
      } else if (nameUpper.contains('50%') || nameUpper.contains('SOLID_50')) {
        effectiveOpacity = 0.50;
      } else if (nameUpper.contains('75%') || nameUpper.contains('SOLID_75')) {
        effectiveOpacity = 0.75;
      } else if (hatch.isSolid) {
        effectiveOpacity = 0.40;
      }
    }

    final effectiveFillPaint = Paint()
      ..color = strokePaint.color.withValues(alpha: effectiveOpacity)
      ..style = PaintingStyle.fill;

    // Draw background translucent / solid fill
    canvas.drawPath(path, effectiveFillPaint);

    // 2. Draw geometric pattern lines for non-pure-solid hatches
    final name = hatch.patternName.toUpperCase();
    final bool isPureSolid = hatch.isSolid &&
        (name == 'SOLID' ||
            name == '_SOLID' ||
            name.contains('%') ||
            name.contains('SHADOW') ||
            name.contains('СЕНКИ') ||
            name.contains('SENKA') ||
            name.contains('СЯНКА') ||
            name.contains('TRANSP'));

    if (!isPureSolid) {
      _renderHatchPatternLines(canvas, path, hatch, strokePaint);
    }
  }

  void _renderHatchPatternLines(
    Canvas canvas,
    Path clipPath,
    DxfHatch hatch,
    Paint strokePaint,
  ) {
    final bounds = clipPath.getBounds();
    if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) return;

    final name = hatch.patternName.toUpperCase();
    final double scale = currentScale.clamp(0.001, 10000.0);
    final double rawSpacing = (hatch.patternScale > 0 ? hatch.patternScale : 1.0) * 14.0;
    final double spacing = (rawSpacing / scale).clamp(3.5, 400.0);

    final patternStrokePaint = Paint()
      ..color = strokePaint.color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (0.85 * settings.lineThicknessScale) / scale
      ..isAntiAlias = true;

    canvas.save();
    canvas.clipPath(clipPath);

    final double rad = hatch.patternAngle * math.pi / 180.0;

    if (name.contains('ANSI31') || name.contains('LINE') || name.contains('HATCH') || name.contains('DIAGONAL')) {
      _drawParallelLines(canvas, bounds, rad + math.pi / 4, spacing, patternStrokePaint);
    } else if (name.contains('ANSI32') || name.contains('ANSI37') || name.contains('CROSS') || name.contains('GRID') || name.contains('NET')) {
      _drawParallelLines(canvas, bounds, rad + math.pi / 4, spacing, patternStrokePaint);
      _drawParallelLines(canvas, bounds, rad - math.pi / 4, spacing, patternStrokePaint);
    } else if (name.contains('PLANK') || name.contains('FLOOR') || name.contains('HORIZ')) {
      _drawParallelLines(canvas, bounds, rad, spacing * 1.5, patternStrokePaint);
    } else if (name.contains('VERT')) {
      _drawParallelLines(canvas, bounds, rad + math.pi / 2, spacing * 1.5, patternStrokePaint);
    } else if (name.contains('INSULAT') || name.contains('STYROFOAM') || name.contains('SOLID___DASHED')) {
      _drawParallelLines(canvas, bounds, rad + math.pi / 4, spacing * 0.8, patternStrokePaint);
    } else if (name.contains('BRICK') || name.contains('AR-B')) {
      _drawBrickPattern(canvas, bounds, rad, spacing, patternStrokePaint);
    } else if (name.contains('CONC') || name.contains('GRAVEL')) {
      _drawConcretePattern(canvas, bounds, spacing, patternStrokePaint);
    } else if (name.contains('EARTH') || name.contains('SOIL')) {
      _drawEarthPattern(canvas, bounds, rad + math.pi / 4, spacing, patternStrokePaint);
    } else {
      _drawParallelLines(canvas, bounds, rad + math.pi / 4, spacing, patternStrokePaint);
    }

    canvas.restore();
  }

  void _drawParallelLines(
    Canvas canvas,
    Rect bounds,
    double angleRad,
    double spacing,
    Paint paint, {
    double offsetShift = 0.0,
  }) {
    if (spacing <= 0) return;
    final center = bounds.center;
    final radius = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) / 2 + 10;

    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    final normX = -sinA;
    final normY = cosA;

    final count = (radius * 2 / spacing).ceil().clamp(1, 600);
    for (int i = -count; i <= count; i++) {
      final double offset = i * spacing + offsetShift;
      final pMid = Offset(center.dx + normX * offset, center.dy + normY * offset);
      final p1 = Offset(pMid.dx - cosA * radius, pMid.dy - sinA * radius);
      final p2 = Offset(pMid.dx + cosA * radius, pMid.dy + sinA * radius);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawBrickPattern(
    Canvas canvas,
    Rect bounds,
    double angleRad,
    double spacing,
    Paint paint,
  ) {
    _drawParallelLines(canvas, bounds, angleRad, spacing, paint);
    _drawParallelLines(canvas, bounds, angleRad + math.pi / 2, spacing * 2.5, paint);
  }

  void _drawConcretePattern(
    Canvas canvas,
    Rect bounds,
    double spacing,
    Paint paint,
  ) {
    final double step = math.max(spacing * 0.8, 12.0);
    final dotPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    for (double x = bounds.left; x < bounds.right; x += step) {
      for (double y = bounds.top; y < bounds.bottom; y += step) {
        final double jitterX = (math.sin(x * 12.9898 + y * 78.233) * 43758.5453 % 1.0) * step * 0.6;
        final double jitterY = (math.cos(x * 39.346 + y * 11.135) * 43758.5453 % 1.0) * step * 0.6;
        final pt = Offset(x + jitterX, y + jitterY);

        if ((x.toInt() + y.toInt()) % 3 == 0) {
          final s = step * 0.25;
          final tri = Path()
            ..moveTo(pt.dx, pt.dy - s)
            ..lineTo(pt.dx - s, pt.dy + s)
            ..lineTo(pt.dx + s, pt.dy + s)
            ..close();
          canvas.drawPath(tri, paint);
        } else {
          canvas.drawCircle(pt, 1.0, dotPaint);
        }
      }
    }
  }

  void _drawEarthPattern(
    Canvas canvas,
    Rect bounds,
    double angleRad,
    double spacing,
    Paint paint,
  ) {
    final double groupSpacing = spacing * 2.2;
    _drawParallelLines(canvas, bounds, angleRad, groupSpacing, paint);
    _drawParallelLines(canvas, bounds, angleRad, groupSpacing, paint, offsetShift: spacing * 0.28);
    _drawParallelLines(canvas, bounds, angleRad, groupSpacing, paint, offsetShift: spacing * 0.56);
  }

  void _renderInsert({
    required Canvas canvas,
    required DxfInsert insert,
    required Map<String, DxfBlock> blocks,
    required Map<String, DxfLayer> layers,
    required Offset Function(Offset) toCanvas,
    required double fitScale,
  }) {
    final block = blocks[insert.blockName];
    if (block == null || block.entities.isEmpty) return;

    final rad = insert.rotationDeg * math.pi / 180.0;
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

    final blockBaseX = block.basePoint.dx;
    final blockBaseY = block.basePoint.dy;

    for (int r = 0; r < insert.rowCount; r++) {
      for (int c = 0; c < insert.colCount; c++) {
        final double offsetX = insert.insertPoint.dx + c * insert.colSpacing;
        final double offsetY = insert.insertPoint.dy + r * insert.rowSpacing;

        Offset localToCanvas(Offset childCadPoint) {
          final lx = (childCadPoint.dx - blockBaseX) * insert.scaleX;
          final ly = (childCadPoint.dy - blockBaseY) * insert.scaleY;
          final rx = lx * cosA - ly * sinA;
          final ry = lx * sinA + ly * cosA;
          return toCanvas(Offset(offsetX + rx, offsetY + ry));
        }

        for (final child in block.entities) {
          final childLayer = layers[child.layer];
          if (childLayer != null && !childLayer.isVisible) continue;

          final childColor = DxfColorTable.resolveColor(
            colorIndex: child.colorIndex ?? insert.colorIndex,
            trueColor: child.trueColor ?? insert.trueColor,
            layerColor: childLayer != null
                ? DxfColorTable.resolveColor(
                    colorIndex: childLayer.colorIndex,
                    trueColor: childLayer.trueColor,
                    isDarkBackground: theme.isDark,
                  )
                : null,
            isDarkBackground: theme.isDark,
          );

          final strokePaint = Paint()
            ..color = childColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = _calcStrokeWidth(child.lineWeight, layer: childLayer)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

          final fillPaint = Paint()
            ..color = childColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill;

          _renderEntity(
            canvas: canvas,
            entity: child,
            strokePaint: strokePaint,
            fillPaint: fillPaint,
            toCanvas: localToCanvas,
            fitScale: fitScale,
            blocks: blocks,
            layers: layers,
          );
        }
      }
    }
  }

  void _renderDimension(
    Canvas canvas,
    DxfDimension dim,
    Paint paint,
    Offset Function(Offset) toCanvas,
    double fitScale,
    Map<String, DxfBlock> blocks,
    Map<String, DxfLayer> layers,
  ) {
    // If dimension references an anonymous block *D..., render the block
    if (dim.blockName != null && blocks.containsKey(dim.blockName)) {
      final block = blocks[dim.blockName]!;
      for (final e in block.entities) {
        _renderEntity(
          canvas: canvas,
          entity: e,
          strokePaint: paint,
          fillPaint: Paint()..color = paint.color.withValues(alpha: 0.3),
          toCanvas: toCanvas,
          fitScale: fitScale,
          blocks: blocks,
          layers: layers,
        );
      }
      return;
    }

    // Otherwise fallback: draw dimension line between def points + text
    final p1 = toCanvas(dim.defPoint1);
    final p2 = toCanvas(dim.defPoint2 ?? dim.textPoint);
    canvas.drawLine(p1, p2, paint);

    if (dim.textOverride != null && dim.textOverride!.isNotEmpty) {
      final scale = currentScale.clamp(0.001, 10000.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: dim.textOverride,
          style: TextStyle(
            color: paint.color,
            fontSize: (11.0 * settings.measurementScale) / scale,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final tp = toCanvas(dim.textPoint);
      textPainter.paint(canvas, Offset(tp.dx - textPainter.width / 2, tp.dy - textPainter.height / 2));
    }
  }

  void _renderLeader(
    Canvas canvas,
    DxfLeader leader,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType,
  ) {
    if (leader.vertices.length < 2) return;

    final path = Path();
    final p0 = toCanvas(leader.vertices.first);
    path.moveTo(p0.dx, p0.dy);

    for (int i = 1; i < leader.vertices.length; i++) {
      final p = toCanvas(leader.vertices[i]);
      path.lineTo(p.dx, p.dy);
    }
    _drawStrokePath(canvas, path, paint, lineType, layerLineType);
  }

  void _drawSnapMarker(
    Canvas canvas,
    DxfSnapResult snap,
    Offset Function(Offset) toCanvas,
  ) {
    final pos = toCanvas(snap.point);
    final scale = currentScale.clamp(0.001, 10000.0);
    final double size = (settings.pointSize * 1.5) / scale;
    final double strokeW = (1.5 * settings.lineThicknessScale) / scale;

    final markerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    switch (snap.type) {
      case DxfSnapType.endpoint:
      case DxfSnapType.point:
        // Diamond marker ◇
        final path = Path()
          ..moveTo(pos.dx, pos.dy - size)
          ..lineTo(pos.dx + size, pos.dy)
          ..lineTo(pos.dx, pos.dy + size)
          ..lineTo(pos.dx - size, pos.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, markerPaint);
        break;

      case DxfSnapType.midpoint:
        // Triangle marker △
        final path = Path()
          ..moveTo(pos.dx, pos.dy - size)
          ..lineTo(pos.dx + size, pos.dy + size * 0.8)
          ..lineTo(pos.dx - size, pos.dy + size * 0.8)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, markerPaint);
        break;

      case DxfSnapType.center:
        // Circle marker ○
        canvas.drawCircle(pos, size * 0.85, fillPaint);
        canvas.drawCircle(pos, size * 0.85, markerPaint);
        break;

      case DxfSnapType.nearest:
        // Hourglass marker ⧖
        final double s = size * 0.75;
        final path = Path()
          ..moveTo(pos.dx - s, pos.dy - s)
          ..lineTo(pos.dx + s, pos.dy - s)
          ..lineTo(pos.dx - s, pos.dy + s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, markerPaint);
        break;

      case DxfSnapType.perpendicular:
        // CAD Perpendicular symbol ⟂
        final double s = size * 0.75;
        final path = Path()
          ..moveTo(pos.dx - s, pos.dy + s)
          ..lineTo(pos.dx + s, pos.dy + s)
          ..moveTo(pos.dx, pos.dy + s)
          ..lineTo(pos.dx, pos.dy - s)
          ..moveTo(pos.dx, pos.dy + s - s * 0.5)
          ..lineTo(pos.dx + s * 0.5, pos.dy + s - s * 0.5)
          ..lineTo(pos.dx + s * 0.5, pos.dy + s);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, markerPaint);
        break;
    }
  }

  void _drawEntityHighlight(
    Canvas canvas,
    DxfEntity entity,
    Offset Function(Offset) toCanvas,
  ) {
    final bounds = entity.getBoundingBox(document.blocks);
    if (bounds == null) return;

    final p1 = toCanvas(Offset(bounds.left, bounds.top));
    final p2 = toCanvas(Offset(bounds.right, bounds.bottom));
    final canvasRect = Rect.fromPoints(p1, p2);
    final scale = currentScale.clamp(0.001, 10000.0);

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * settings.lineThicknessScale) / scale;

    final rrect = RRect.fromRectAndRadius(canvasRect.inflate(4 / scale), Radius.circular(4 / scale));
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawMeasurement(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
  ) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final p1 = toCanvas(m.p1Cad);

    final double dotRadius = (settings.pointSize * 0.85) / scale;
    final double lineStroke = (1.5 * settings.lineThicknessScale) / scale;
    final double mScale = settings.measurementScale;

    final dotPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    final linePaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineStroke;

    canvas.drawCircle(p1, dotRadius, dotPaint);
    canvas.drawCircle(p1, dotRadius, dotBorderPaint);

    if (m.p2Cad != null) {
      final p2 = toCanvas(m.p2Cad!);
      canvas.drawCircle(p2, dotRadius, dotPaint);
      canvas.drawCircle(p2, dotRadius, dotBorderPaint);
      canvas.drawLine(p1, p2, linePaint);

      // Compact L-Only Measurement Callout Bubble
      final double dist = m.distance!;
      final String text = 'L: ${DxfMath.formatDistance(dist)}';

      final double fontSize = (9.5 * mScale) / scale;
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final double padH = (6.0 * mScale) / scale;
      final double padV = (3.0 * mScale) / scale;
      final double offsetY = (-14.0 * mScale) / scale;
      final double cornerRadius = (4.0 * mScale) / scale;

      final bubbleRect = Rect.fromCenter(
        center: mid + Offset(0, offsetY),
        width: textPainter.width + padH * 2,
        height: textPainter.height + padV * 2,
      );

      final bgPaint = Paint()
        ..color = const Color(0xF01E293B)
        ..style = PaintingStyle.fill;
      final borderBubble = Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 * settings.lineThicknessScale) / scale;

      final rrect = RRect.fromRectAndRadius(bubbleRect, Radius.circular(cornerRadius));
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderBubble);

      textPainter.paint(
        canvas,
        Offset(bubbleRect.left + padH, bubbleRect.top + padV),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DxfPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.currentScale != currentScale ||
        oldDelegate.measurement != measurement ||
        oldDelegate.highlightedEntity != highlightedEntity ||
        oldDelegate.snapResult != snapResult ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.settings != settings;
  }
}
