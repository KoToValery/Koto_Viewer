import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dxf_color_table.dart';
import '../models/dxf_display_settings.dart';
import '../models/dxf_models.dart';
import 'dxf_hatch_pattern_helper.dart';
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

/// CustomPainter for rendering entire DXF drawing.
class DxfPainter extends CustomPainter {
  final DxfDocument document;
  final DxfCanvasTheme theme;
  final double currentScale;
  final DxfMeasurement? measurement;
  final List<DxfAnnotation> annotations;
  final DxfEntity? highlightedEntity;
  final DxfSnapResult? snapResult;
  final bool showGrid;
  final DxfDisplaySettings settings;
  final Rect? visibleCadRect;

  DxfPainter({
    required this.document,
    required this.theme,
    this.currentScale = 1.0,
    this.measurement,
    this.annotations = const [],
    this.highlightedEntity,
    this.snapResult,
    this.showGrid = true,
    this.settings = const DxfDisplaySettings(),
    this.visibleCadRect,
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

    // 2. Draw Entities (Render all document entities directly so no lines or text ever disappear upon zooming in)
    final Iterable<DxfEntity> entitiesToDraw = (document.entities.length > 30000 && visibleCadRect != null && document.spatialIndex != null)
        ? document.spatialIndex!.query(visibleCadRect!.inflate(visibleCadRect!.longestSide * 0.5))
        : document.entities;

    for (final entity in entitiesToDraw) {
      try {
        final layer = document.layers[entity.layer];
        if (layer != null && (!layer.isVisible || layer.isFrozen)) {
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
      } catch (_) {
        // Individual entity rendering failure must never break the frame
      }
    }

    // 3. Draw Highlighted Entity
    if (highlightedEntity != null) {
      try {
        _drawEntityHighlight(canvas, highlightedEntity!, toCanvas);
      } catch (_) {}
    }

    // 4. Draw Active Snap Marker
    if (snapResult != null) {
      try {
        _drawSnapMarker(canvas, snapResult!, toCanvas);
      } catch (_) {}
    }

    // 5. Draw Saved Annotations (Leader notes)
    if (annotations.isNotEmpty) {
      try {
        _drawAnnotations(canvas, toCanvas, fitScale);
      } catch (_) {}
    }

    // 6. Draw Active Measurement Overlay
    if (measurement != null) {
      try {
        _drawMeasurement(canvas, measurement!, toCanvas, fitScale);
      } catch (_) {}
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
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
    String? effectiveLineType = lineType;
    if (effectiveLineType == null ||
        effectiveLineType.trim().toUpperCase() == 'BYBLOCK') {
      if (blockLineType != null && blockLineType.trim().isNotEmpty) {
        effectiveLineType = blockLineType;
      }
    }
    final pattern = DxfLinetypeHelper.resolvePattern(
      effectiveLineType,
      layerLineType: layerLineType,
      customLineTypes: document.lineTypes,
    );
    if (pattern == null) {
      canvas.drawPath(path, paint);
    } else {
      final scale = currentScale.clamp(0.001, 10000.0);
      final double ltScale = (entityLineTypeScale != null && entityLineTypeScale > 0)
          ? entityLineTypeScale
          : 1.0;
      final dashedPath = DxfLinetypeHelper.createDashedPath(
        path,
        pattern,
        scale: (1.0 * settings.lineThicknessScale * settings.linetypeScale * ltScale) / scale,
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
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
    String? effectiveLineType = lineType;
    if (effectiveLineType == null ||
        effectiveLineType.trim().toUpperCase() == 'BYBLOCK') {
      if (blockLineType != null && blockLineType.trim().isNotEmpty) {
        effectiveLineType = blockLineType;
      }
    }
    final pattern = DxfLinetypeHelper.resolvePattern(
      effectiveLineType,
      layerLineType: layerLineType,
      customLineTypes: document.lineTypes,
    );
    if (pattern == null) {
      canvas.drawLine(p1, p2, paint);
    } else {
      final scale = currentScale.clamp(0.001, 10000.0);
      final double ltScale = (entityLineTypeScale != null && entityLineTypeScale > 0)
          ? entityLineTypeScale
          : 1.0;
      final dashedPath = DxfLinetypeHelper.createDashedLine(
        p1,
        p2,
        pattern,
        scale: (1.0 * settings.lineThicknessScale * settings.linetypeScale * ltScale) / scale,
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
    String? blockLineType,
  }) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final layer = layers[entity.layer];
    final String? layerLineType = layer?.lineType;
    final double? entityLtScale = entity.lineTypeScale;

    if (entity is DxfLine) {
      final p1 = toCanvas(entity.p1);
      final p2 = toCanvas(entity.p2);
      _drawStrokeLine(
        canvas,
        p1,
        p2,
        strokePaint,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
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
      final double effectiveStroke = math.min(strokePaint.strokeWidth, math.max(0.0001, r * 0.45));
      final circlePaint = Paint()
        ..color = strokePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;
      _drawStrokePath(
        canvas,
        path,
        circlePaint,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfArc) {
      _renderArc(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        fitScale,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfEllipse) {
      _renderEllipse(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfLwPolyline) {
      _renderLwPolyline(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfPolyline) {
      _renderPolyline(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfSpline) {
      _renderSpline(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    } else if (entity is DxfText) {
      _renderText(canvas, entity, strokePaint.color, toCanvas, fitScale);
    } else if (entity is DxfMText) {
      _renderMText(canvas, entity, strokePaint.color, toCanvas, fitScale);
    } else if (entity is DxfSolid) {
      _renderSolid(canvas, entity, fillPaint, strokePaint, toCanvas);
    } else if (entity is DxfHatch) {
      _renderHatch(canvas, entity, fillPaint, strokePaint, toCanvas, fitScale);
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
      _renderLeader(
        canvas,
        entity,
        strokePaint,
        toCanvas,
        entity.lineType,
        layerLineType,
        entityLineTypeScale: entityLtScale,
        blockLineType: blockLineType,
      );
    }
  }

  void _renderArc(
    Canvas canvas,
    DxfArc arc,
    Paint paint,
    Offset Function(Offset) toCanvas,
    double fitScale,
    String? lineType,
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
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
    final double effectiveStroke = math.min(paint.strokeWidth, math.max(0.0001, rCanvas * 0.45));
    final arcPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    _drawStrokePath(
      canvas,
      path,
      arcPaint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
  }

  void _renderEllipse(
    Canvas canvas,
    DxfEllipse ellipse,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
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

    _drawStrokePath(
      canvas,
      path,
      paint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
  }

  void _renderLwPolyline(
    Canvas canvas,
    DxfLwPolyline poly,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
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

    _drawStrokePath(
      canvas,
      path,
      paint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
  }

  void _renderPolyline(
    Canvas canvas,
    DxfPolyline poly,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
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

    _drawStrokePath(
      canvas,
      path,
      paint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
  }

  void _renderSpline(
    Canvas canvas,
    DxfSpline spline,
    Paint paint,
    Offset Function(Offset) toCanvas,
    String? lineType,
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
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

    _drawStrokePath(
      canvas,
      path,
      paint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
  }

  /// The active drawing unit for measurements (user override or document header unit).
  DxfUnit get effectiveUnit => settings.unitOverride ?? document.unit;

  /// Calculates the effective text height for rendering, applying text style
  /// scale factors if specified in the style definition.
  ///
  /// Text heights are rendered 1:1 with CAD drawing units.
  double _getEffectiveTextHeight(
    double entityHeight,
    String? styleName,
    DxfDocument document,
  ) {
    double effectiveHeight = entityHeight;

    // Apply text style scale factor if style exists and has explicit custom scaling
    if (styleName != null && document.textStyles.containsKey(styleName)) {
      final style = document.textStyles[styleName]!;
      if ((style.heightScale - 1.0).abs() > 0.05 && style.heightScale > 0) {
        effectiveHeight *= style.heightScale;
      }
    }

    return effectiveHeight;
  }

  /// Resolves the most appropriate font family from the CAD text style definition.
  String _resolveFontFamily(String? styleName) {
    if (styleName == null) return 'Arial';
    final ts = document.textStyles[styleName];
    if (ts == null || ts.fontFile == null || ts.fontFile!.trim().isEmpty) return 'Arial';

    final f = ts.fontFile!.trim().toLowerCase();
    if (f.contains('isocpeur')) return 'ISOCPEUR';
    if (f.contains('simplex') || f.contains('txt') || f.contains('romans') || f.contains('monotxt')) {
      return 'Consolas';
    }
    if (f.contains('cour')) return 'Courier New';
    if (f.contains('times')) return 'Times New Roman';
    if (f.contains('segoe')) return 'Segoe UI';
    if (f.contains('tahoma')) return 'Tahoma';
    if (f.contains('arial')) return 'Arial';

    final dotIdx = ts.fontFile!.lastIndexOf('.');
    if (dotIdx > 0) {
      return ts.fontFile!.substring(0, dotIdx);
    }
    return ts.fontFile!;
  }

  /// Resolves font fallbacks with standard CAD, Windows, and system fallbacks.
  List<String> _resolveFontFallbacks(String primaryFont) {
    return [
      if (primaryFont != 'Arial') 'Arial',
      'ISOCPEUR',
      'Segoe UI',
      'Roboto',
      'sans-serif',
    ];
  }

  void _renderText(
    Canvas canvas,
    DxfText entity,
    Color color,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    if (entity.text.trim().isEmpty) return;

    // Apply effective text height calculation (includes text style scale)
    final effectiveHeight = _getEffectiveTextHeight(
      entity.height,
      entity.style,
      document,
    );

    // CAD Text Height specifies the Cap-Height (capital letter height).
    // In Flutter, TextStyle fontSize is the full font EM-box (~1.39x of cap-height for Arial/Roboto).
    // Scaling by 1 / 0.72 ensures capital letters render at EXACTLY entity.height drawing units.
    const double capHeightRatio = 0.72;
    final double fontSize = math.max((effectiveHeight / capHeightRatio) * fitScale, 0.1);

    final String fontFamily = _resolveFontFamily(entity.style);
    final List<String> fontFallbacks = _resolveFontFallbacks(fontFamily);

    final textPainter = TextPainter(
      text: TextSpan(
        text: entity.text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallbacks,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
    textPainter.layout();

    final pos = toCanvas(
      ((entity.hAlign != 0 || entity.vAlign != 0) && entity.alignPoint != null)
          ? entity.alignPoint!
          : entity.insertPoint,
    );

    canvas.save();
    try {
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

      // Vertical alignment offset:
      final double baseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final double capHeightPx = effectiveHeight * fitScale;

      double oy;
      switch (entity.vAlign) {
        case 1: // Bottom
          oy = -baseline;
          break;
        case 2: // Middle
          oy = -textPainter.height / 2.0;
          break;
        case 3: // Top
          oy = -baseline + capHeightPx;
          break;
        default: // 0 = Baseline
          if (entity.hAlign == 4) {
            oy = -textPainter.height / 2.0;
          } else {
            oy = -baseline;
          }
      }

      textPainter.paint(canvas, Offset(ox, oy));
    } finally {
      canvas.restore();
    }
  }

  void _renderMText(
    Canvas canvas,
    DxfMText entity,
    Color color,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    if (entity.cleanText.trim().isEmpty) return;

    // Apply effective text height calculation (includes text style scale)
    final effectiveHeight = _getEffectiveTextHeight(
      entity.height,
      entity.style,
      document,
    );

    // CAD Text Height specifies the Cap-Height (capital letter height).
    // Scaling by 1 / 0.72 ensures capital letters render at EXACTLY entity.height drawing units.
    const double capHeightRatio = 0.72;
    final double fontSize = math.max((effectiveHeight / capHeightRatio) * fitScale, 0.5);

    // Determine horizontal text alignment from MTEXT paragraph style codes or attachment point
    TextAlign align = TextAlign.left;
    final rawLower = entity.rawText.toLowerCase();
    if (rawLower.contains(r'\pqc;') || rawLower.contains(r'\qc;')) {
      align = TextAlign.center;
    } else if (rawLower.contains(r'\pqr;') || rawLower.contains(r'\qr;')) {
      align = TextAlign.right;
    } else if (entity.attachmentPoint == 2 ||
        entity.attachmentPoint == 5 ||
        entity.attachmentPoint == 8) {
      align = TextAlign.center;
    } else if (entity.attachmentPoint == 3 ||
        entity.attachmentPoint == 6 ||
        entity.attachmentPoint == 9) {
      align = TextAlign.right;
    }

    final String fontFamily = _resolveFontFamily(entity.style);
    final List<String> fontFallbacks = _resolveFontFallbacks(fontFamily);

    final textPainter = TextPainter(
      text: TextSpan(
        text: entity.cleanText,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallbacks,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );

    if (entity.refWidth != null && entity.refWidth! > 0) {
      textPainter.layout(maxWidth: entity.refWidth! * fitScale);
    } else {
      textPainter.layout();
    }

    final pos = toCanvas(entity.insertPoint);

    canvas.save();
    try {
      canvas.translate(pos.dx, pos.dy);

      final double rad = -entity.rotationDeg * math.pi / 180.0;
      canvas.rotate(rad);

      // Attachment Point offsets (1=TL, 2=TC, 3=TR, 4=ML, 5=MC, 6=MR, 7=BL, 8=BC, 9=BR)
      // In AutoCAD, MTEXT attachment points:
      // Top (1,2,3): Top of capital letters is at pos.dy
      // Middle (4,5,6): Center of text is at pos.dy
      // Bottom (7,8,9): Alphabetic baseline of last line is at pos.dy
      double ox = 0.0;
      double oy = 0.0;

      final double firstBaseline = textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final double capHeightPx = effectiveHeight * fitScale;

      final lineMetrics = textPainter.computeLineMetrics();
      final double lastBaseline = lineMetrics.isNotEmpty ? lineMetrics.last.baseline : firstBaseline;

      switch (entity.attachmentPoint) {
        case 0: // Unspecified (Default to Middle Center)
        case 5: // Middle Center
          ox = -textPainter.width / 2.0;
          oy = -textPainter.height / 2.0;
          break;
        case 1: // Top Left
          ox = 0;
          oy = -firstBaseline + capHeightPx;
          break;
        case 2: // Top Center
          ox = -textPainter.width / 2.0;
          oy = -firstBaseline + capHeightPx;
          break;
        case 3: // Top Right
          ox = -textPainter.width;
          oy = -firstBaseline + capHeightPx;
          break;
        case 4: // Middle Left
          ox = 0;
          oy = -textPainter.height / 2.0;
          break;
        case 6: // Middle Right
          ox = -textPainter.width;
          oy = -textPainter.height / 2.0;
          break;
        case 7: // Bottom Left
          ox = 0;
          oy = -lastBaseline;
          break;
        case 8: // Bottom Center
          ox = -textPainter.width / 2.0;
          oy = -lastBaseline;
          break;
        case 9: // Bottom Right
          ox = -textPainter.width;
          oy = -lastBaseline;
          break;
      }

      textPainter.paint(canvas, Offset(ox, oy));
    } finally {
      canvas.restore();
    }
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
    double fitScale,
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

    final nameUpper = hatch.patternName.toUpperCase();
    final layerUpper = hatch.layer.toUpperCase();

    // 1. Determine effective transparency / fill opacity
    double? effectiveOpacity;
    if (hatch.transparency != null) {
      effectiveOpacity = hatch.transparency!.clamp(0.02, 1.0);
    } else if (nameUpper.contains('10%') ||
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
      effectiveOpacity = 0.60;
    }

    // Draw solid/translucent fill only when the hatch is solid or has an explicit/shadow transparency
    if (effectiveOpacity != null && (hatch.isSolid || hatch.transparency != null || effectiveOpacity <= 0.75)) {
      final effectiveFillPaint = Paint()
        ..color = strokePaint.color.withValues(alpha: effectiveOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, effectiveFillPaint);
    }

    // 2. Draw geometric pattern lines for non-pure-solid hatches
    final bool isPureSolid = hatch.isSolid &&
        (nameUpper == 'SOLID' ||
            nameUpper == '_SOLID' ||
            nameUpper.contains('%') ||
            nameUpper.contains('SHADOW') ||
            nameUpper.contains('СЕНКИ') ||
            nameUpper.contains('SENKA') ||
            nameUpper.contains('СЯНКА') ||
            nameUpper.contains('TRANSP'));

    if (!isPureSolid) {
      _renderHatchPatternLines(canvas, path, hatch, strokePaint, toCanvas, fitScale);
    }
  }

  void _renderHatchPatternLines(
    Canvas canvas,
    Path clipPath,
    DxfHatch hatch,
    Paint strokePaint,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    final bounds = clipPath.getBounds();
    if (bounds.isEmpty || bounds.width <= 0 || bounds.height <= 0) return;

    final fallbackOrigin = hatch.boundaryPaths.isNotEmpty && hatch.boundaryPaths.first.isNotEmpty
        ? hatch.boundaryPaths.first.first
        : Offset.zero;

    final patternLines = DxfHatchPatternHelper.resolvePatternLines(
      hatch,
      fallbackOrigin: fallbackOrigin,
    );
    if (patternLines.isEmpty) return;

    final double scale = currentScale.clamp(0.001, 10000.0);
    // Crisp CAD line thickness for hatch lines
    final double lineThickness = math.min(
      strokePaint.strokeWidth,
      (0.85 * settings.lineThicknessScale) / scale,
    );
    final patternStrokePaint = Paint()
      ..color = strokePaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.15, lineThickness)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final center = bounds.center;
    final double radius = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) / 2.0 + 2.0;

    canvas.save();
    canvas.clipPath(clipPath);

    for (final line in patternLines) {
      _renderSinglePatternLineFamily(
        canvas: canvas,
        line: line,
        bounds: bounds,
        center: center,
        radius: radius,
        paint: patternStrokePaint,
        toCanvas: toCanvas,
        fitScale: fitScale,
      );
    }

    canvas.restore();
  }

  void _renderSinglePatternLineFamily({
    required Canvas canvas,
    required DxfHatchPatternLine line,
    required Rect bounds,
    required Offset center,
    required double radius,
    required Paint paint,
    required Offset Function(Offset) toCanvas,
    required double fitScale,
  }) {
    // 1. Line angle and unit direction in Canvas
    final double radCad = line.angle * math.pi / 180.0;
    // Canvas coordinate system has Y inverted relative to CAD (Y down vs Y up)
    final double dirX = math.cos(radCad);
    final double dirY = -math.sin(radCad);
    final dirCanvas = Offset(dirX, dirY);

    // Normal vector perpendicular to dirCanvas in Canvas coords (-dirY, dirX)
    final normalCanvas = Offset(-dirY, dirX);

    // 2. Base point in Canvas coords
    final baseCanvas = toCanvas(line.basePoint);

    // 3. Offset vector in Canvas coords (dx * fitScale, -dy * fitScale)
    final offsetCanvas = Offset(
      line.offset.dx * fitScale,
      -line.offset.dy * fitScale,
    );

    // 4. Perpendicular step between successive lines in the family
    final double step = offsetCanvas.dx * normalCanvas.dx + offsetCanvas.dy * normalCanvas.dy;
    final double absStep = step.abs();

    // Dense line safeguard: if spacing on screen is less than 1.2 pixels,
    // lines blend into a solid tint. Avoid lagging by rendering a representative tint.
    if (absStep > 0 && absStep < 1.2) {
      final denseFillPaint = Paint()
        ..color = paint.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(bounds, denseFillPaint);
      return;
    }

    // 5. Calculate range of line indices [kMin, kMax] touching the bounding box
    int kMin = 0;
    int kMax = 0;

    if (absStep < 1e-6) {
      // Single line family (no offset perpendicular)
      kMin = 0;
      kMax = 0;
    } else {
      // Project the 4 corners of bounds onto normalCanvas
      final c1 = bounds.topLeft;
      final c2 = bounds.topRight;
      final c3 = bounds.bottomRight;
      final c4 = bounds.bottomLeft;

      double dist(Offset p) =>
          (p.dx - baseCanvas.dx) * normalCanvas.dx + (p.dy - baseCanvas.dy) * normalCanvas.dy;

      final k1 = dist(c1) / step;
      final k2 = dist(c2) / step;
      final k3 = dist(c3) / step;
      final k4 = dist(c4) / step;

      final double rawMin = math.min(math.min(k1, k2), math.min(k3, k4));
      final double rawMax = math.max(math.max(k1, k2), math.max(k3, k4));

      kMin = rawMin.floor();
      kMax = rawMax.ceil();
    }

    final int totalLines = kMax - kMin + 1;
    if (totalLines <= 0) return;

    // Safety stride to prevent locking UI if total lines exceeds 1500
    final int stride = totalLines > 1500 ? (totalLines / 1000).ceil() : 1;

    // Check dashes
    final bool hasDashes = line.dashes.isNotEmpty;
    double dashPeriod = 0.0;
    if (hasDashes) {
      for (final d in line.dashes) {
        dashPeriod += d.abs() * fitScale;
      }
    }
    final bool useDashes = hasDashes && dashPeriod >= 1.5;

    // 6. Draw lines
    for (int k = kMin; k <= kMax; k += stride) {
      final lineBase = Offset(
        baseCanvas.dx + offsetCanvas.dx * k,
        baseCanvas.dy + offsetCanvas.dy * k,
      );

      // Project center onto this line
      final double tCenter = (center.dx - lineBase.dx) * dirCanvas.dx +
          (center.dy - lineBase.dy) * dirCanvas.dy;

      final double tStart = tCenter - radius;
      final double tEnd = tCenter + radius;

      if (!useDashes) {
        // Continuous line
        final pStart = Offset(
          lineBase.dx + dirCanvas.dx * tStart,
          lineBase.dy + dirCanvas.dy * tStart,
        );
        final pEnd = Offset(
          lineBase.dx + dirCanvas.dx * tEnd,
          lineBase.dy + dirCanvas.dy * tEnd,
        );
        canvas.drawLine(pStart, pEnd, paint);
      } else {
        // Dashed / dotted line
        final int startCycle = (tStart / dashPeriod).floor();
        double tCurr = startCycle * dashPeriod;

        while (tCurr < tEnd) {
          for (final d in line.dashes) {
            final double itemLen = d.abs() * fitScale;
            if (d > 0) {
              // Dash
              final double segStart = math.max(tCurr, tStart);
              final double segEnd = math.min(tCurr + itemLen, tEnd);
              if (segEnd > segStart) {
                final pStart = Offset(
                  lineBase.dx + dirCanvas.dx * segStart,
                  lineBase.dy + dirCanvas.dy * segStart,
                );
                final pEnd = Offset(
                  lineBase.dx + dirCanvas.dx * segEnd,
                  lineBase.dy + dirCanvas.dy * segEnd,
                );
                canvas.drawLine(pStart, pEnd, paint);
              }
            } else if (d == 0) {
              // Dot
              if (tCurr >= tStart && tCurr <= tEnd) {
                final pDot = Offset(
                  lineBase.dx + dirCanvas.dx * tCurr,
                  lineBase.dy + dirCanvas.dy * tCurr,
                );
                canvas.drawCircle(pDot, paint.strokeWidth * 0.7, paint);
              }
            }
            // If d < 0, it's a space (gap), do nothing
            tCurr += itemLen;
          }
        }
      }
    }
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
          if (childLayer != null && (!childLayer.isVisible || childLayer.isFrozen)) continue;

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
            blockLineType: insert.lineType,
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
        DxfEntity entityToDraw = e;
        // Dimension MText is drawn as defined in the block.
        
        // For dimension ticks/lines (non-MTEXT entities), use the dimension's color
        // For MTEXT (dimension text), keep its own color (usually white/byblock)
        Paint entityPaint = paint;
        if (entityToDraw is! DxfMText) {
          // Lines, solids, etc. should use dimension line color
          entityPaint = paint;
        } else {
          // Text keeps its own color from the block definition
          final entityLayer = layers[entityToDraw.layer];
          final textColor = DxfColorTable.resolveColor(
            colorIndex: entityToDraw.colorIndex,
            trueColor: entityToDraw.trueColor,
            layerColor: entityLayer != null
                ? DxfColorTable.resolveColor(
                    colorIndex: entityLayer.colorIndex,
                    trueColor: entityLayer.trueColor,
                    isDarkBackground: theme.isDark,
                  )
                : null,
            isDarkBackground: theme.isDark,
          );
          entityPaint = Paint()
            ..color = textColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = paint.strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true;
        }
        
        _renderEntity(
          canvas: canvas,
          entity: entityToDraw,
          strokePaint: entityPaint,
          fillPaint: Paint()..color = entityPaint.color.withValues(alpha: 0.3),
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
    String? layerLineType, {
    double? entityLineTypeScale,
    String? blockLineType,
  }) {
    if (leader.vertices.length < 2) return;

    final path = Path();
    final p0 = toCanvas(leader.vertices.first);
    path.moveTo(p0.dx, p0.dy);

    for (int i = 1; i < leader.vertices.length; i++) {
      final p = toCanvas(leader.vertices[i]);
      path.lineTo(p.dx, p.dy);
    }
    _drawStrokePath(
      canvas,
      path,
      paint,
      lineType,
      layerLineType,
      entityLineTypeScale: entityLineTypeScale,
      blockLineType: blockLineType,
    );
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
    double fitScale,
  ) {
    switch (m.tool) {
      case DxfMeasureTool.distance:
        _drawDistanceMeasurement(canvas, m, toCanvas);
        break;
      case DxfMeasureTool.area:
        _drawAreaMeasurement(canvas, m, toCanvas);
        break;
      case DxfMeasureTool.angle:
        _drawAngleMeasurement(canvas, m, toCanvas);
        break;
      case DxfMeasureTool.radius:
        _drawRadiusMeasurement(canvas, m, toCanvas, fitScale);
        break;
      case DxfMeasureTool.annotation:
        _drawAnnotationPreview(canvas, m, toCanvas);
        break;
    }
  }

  void _drawAnnotations(
    Canvas canvas,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final double mScale = settings.measurementScale;

    for (final anno in annotations) {
      final tip = toCanvas(anno.arrowTipCad);
      final textPos = toCanvas(anno.textPosCad);

      _drawSingleLeaderAnnotation(
        canvas: canvas,
        tip: tip,
        textPos: textPos,
        text: anno.text,
        color: anno.color,
        scale: scale,
        mScale: mScale,
      );
    }
  }

  void _drawAnnotationPreview(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
  ) {
    if (m.annotationTip == null) return;
    final scale = currentScale.clamp(0.001, 10000.0);
    final double mScale = settings.measurementScale;
    final tip = toCanvas(m.annotationTip!);

    final markerPaint = Paint()
      ..color = const Color(0xFFFF4081)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tip, (5.0 * mScale) / scale, markerPaint);

    if (m.annotationTextPos != null) {
      final textPos = toCanvas(m.annotationTextPos!);
      _drawSingleLeaderAnnotation(
        canvas: canvas,
        tip: tip,
        textPos: textPos,
        text: m.annotationText ?? 'Tap to place note',
        color: const Color(0xFFFF4081),
        scale: scale,
        mScale: mScale,
      );
    }
  }

  void _drawSingleLeaderAnnotation({
    required Canvas canvas,
    required Offset tip,
    required Offset textPos,
    required String text,
    required Color color,
    required double scale,
    required double mScale,
  }) {
    final leaderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.8 * settings.lineThicknessScale) / scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final delta = textPos - tip;
    final dist = delta.distance;

    // 1. Draw Arrowhead at tip
    final double arrowLen = (14.0 * mScale) / scale;
    final double arrowWidth = (6.5 * mScale) / scale;

    if (dist > 1e-3) {
      final u = delta / dist;
      final normal = Offset(-u.dy, u.dx);

      final pLeft = tip + u * arrowLen + normal * (arrowWidth / 2.0);
      final pRight = tip + u * arrowLen - normal * (arrowWidth / 2.0);

      final arrowPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(pLeft.dx, pLeft.dy)
        ..lineTo(pRight.dx, pRight.dy)
        ..close();

      canvas.drawPath(arrowPath, fillPaint);

      // Leader stem line from base of arrowhead to text position
      canvas.drawLine(tip + u * (arrowLen * 0.85), textPos, leaderPaint);
    } else {
      canvas.drawCircle(tip, (4.0 * mScale) / scale, fillPaint);
    }

    // 2. Horizontal Landing Shoulder Line under text
    final bool isRight = textPos.dx >= tip.dx;
    final double shoulderLen = (24.0 * mScale) / scale;
    final shoulderEnd = textPos + Offset(isRight ? shoulderLen : -shoulderLen, 0);
    canvas.drawLine(textPos, shoulderEnd, leaderPaint);

    // 3. Text Badge Layout
    try {
      final double fontSize = math.max(0.001, (12.0 * mScale) / scale);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 4,
      )..layout();

      final padH = (7.0 * mScale) / scale;
      final padV = (4.0 * mScale) / scale;
      final badgeW = tp.width + padH * 2;
      final badgeH = tp.height + padV * 2;

      final double badgeLeft = isRight ? textPos.dx + (4.0 / scale) : textPos.dx - badgeW - (4.0 / scale);
      final double badgeTop = textPos.dy - badgeH - (2.0 / scale);
      final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeW, badgeH);

      final bgPaint = Paint()
        ..color = const Color(0xFF141C2B).withValues(alpha: 0.94)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.2 * settings.lineThicknessScale) / scale;

      final rrect = RRect.fromRectAndRadius(badgeRect, Radius.circular((4.0 * mScale) / scale));
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderPaint);

      tp.paint(canvas, Offset(badgeLeft + padH, badgeTop + padV));
    } catch (_) {}
  }

  void _drawDistanceMeasurement(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
  ) {
    if (m.p1Cad == null) return;
    final scale = currentScale.clamp(0.001, 10000.0);
    final p1 = toCanvas(m.p1Cad!);

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

      final double dist = m.distance!;
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawBadge(
        canvas: canvas,
        center: mid + Offset(0, (-14.0 * mScale) / scale),
        text: 'L: ${DxfMath.formatDistance(dist, unit: effectiveUnit)} m',
        accentColor: const Color(0xFFFF5252),
        mScale: mScale,
        scale: scale,
      );
    }
  }

  void _drawAreaMeasurement(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
  ) {
    if (m.areaPoints.isEmpty) return;
    final scale = currentScale.clamp(0.001, 10000.0);
    final double dotRadius = (6.0 * settings.lineThicknessScale) / scale;
    final double lineStroke = (3.2 * settings.lineThicknessScale) / scale;
    final double mScale = settings.measurementScale;
    const accentColor = Color(0xFF00E5FF);

    final pts = m.areaPoints.map(toCanvas).toList();

    // Include candidate snap point for live real-time polygon preview while measuring
    final candidatePt = (snapResult != null && !m.isAreaClosed) ? toCanvas(snapResult!.point) : null;
    final fillPts = List<Offset>.from(pts);
    if (candidatePt != null && (pts.isEmpty || (candidatePt - pts.last).distanceSquared > 0.000001)) {
      fillPts.add(candidatePt);
    }

    // 1. Shaded polygon fill if >= 3 points (including candidate point!)
    if (fillPts.length >= 3) {
      final fillPath = Path()..moveTo(fillPts.first.dx, fillPts.first.dy);
      for (int i = 1; i < fillPts.length; i++) {
        fillPath.lineTo(fillPts[i].dx, fillPts[i].dy);
      }
      fillPath.close();

      // High-visibility vivid shaded polygon fill (38% cyan)
      final fillPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.38)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Subtle diagonal hatch lines inside the polygon for unmistakable CAD visual clarity
      final bounds = fillPath.getBounds();
      final hatchPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.22)
        ..strokeWidth = 1.2 / scale
        ..style = PaintingStyle.stroke;
      final double rawStep = 24.0 / scale;
      final double hatchStep = math.max(rawStep, (bounds.width + bounds.height) / 80.0);
      if (bounds.width > 0 && bounds.height > 0) {
        canvas.save();
        canvas.clipPath(fillPath);
        for (double x = bounds.left - bounds.height; x <= bounds.right; x += hatchStep) {
          canvas.drawLine(
            Offset(x, bounds.bottom),
            Offset(x + bounds.height, bounds.top),
            hatchPaint,
          );
        }
        canvas.restore();
      }
    }

    // 2. Confirmed Outline path (Bold 3.2px neon cyan line)
    if (pts.length >= 2) {
      final outlinePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        outlinePath.lineTo(pts[i].dx, pts[i].dy);
      }

      final outlinePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(outlinePath, outlinePaint);
    }

    // 2b. Rubber-band line to candidate point while finger moves
    if (candidatePt != null && pts.isNotEmpty) {
      final candidateLinePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineStroke;
      canvas.drawLine(pts.last, candidatePt, candidateLinePaint);

      // Closing rubber-band preview line back to start
      if (fillPts.length >= 3) {
        final closePreviewPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.0 * settings.lineThicknessScale) / scale;
        canvas.drawLine(candidatePt, pts.first, closePreviewPaint);
      }
    }

    // Closing outline back to start for confirmed points (always closed visually when >= 3 points!)
    if (pts.length >= 3) {
      final isFinal = m.isAreaClosed;
      final closeLinePaint = Paint()
        ..color = isFinal ? accentColor : accentColor.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFinal ? lineStroke : (2.0 * settings.lineThicknessScale) / scale;
      canvas.drawLine(pts.last, pts.first, closeLinePaint);
    }

    // 3. Numbered Vertex Pins (1, 2, 3...)
    final dotPaint = Paint()..color = accentColor..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 / scale;

    for (int i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], dotRadius, dotPaint);
      canvas.drawCircle(pts[i], dotRadius, dotBorderPaint);

      try {
        // Draw vertex index number
        final textSpan = TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: const Color(0xFF0A0A0A),
            fontSize: math.max(0.001, (7.5 * mScale) / scale),
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, pts[i] - Offset(tp.width / 2, tp.height / 2));
      } catch (_) {}
    }

    // 4. Centroid Result Badge (real-time live area & perimeter!)
    final calcCadPts = (fillPts.length >= 3 && candidatePt != null && snapResult != null)
        ? [...m.areaPoints, snapResult!.point]
        : m.areaPoints;

    if (calcCadPts.length >= 3) {
      final double area = DxfMath.calculatePolygonArea(calcCadPts);
      final double perim = DxfMath.calculatePolygonPerimeter(calcCadPts, isClosed: true);
      final Offset centroidCad = DxfMath.calculatePolygonCentroid(calcCadPts);
      final Offset centroidCanvas = toCanvas(centroidCad);

      _drawBadge(
        canvas: canvas,
        center: centroidCanvas,
        text: 'S = ${DxfMath.formatArea(area, unit: effectiveUnit)}',
        subText: 'P = ${DxfMath.formatDistance(perim, unit: effectiveUnit)} m',
        accentColor: accentColor,
        mScale: mScale,
        scale: scale,
      );
    }
  }

  void _drawAngleMeasurement(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
  ) {
    if (m.angleVertex == null) return;
    final scale = currentScale.clamp(0.001, 10000.0);
    final double dotRadius = (settings.pointSize * 0.85) / scale;
    final double lineStroke = (1.5 * settings.lineThicknessScale) / scale;
    final double mScale = settings.measurementScale;
    const accentColor = Color(0xFFFFB300);

    final v = toCanvas(m.angleVertex!);

    // Draw vertex marker
    final vDotPaint = Paint()..color = accentColor..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;
    canvas.drawCircle(v, dotRadius * 1.2, vDotPaint);
    canvas.drawCircle(v, dotRadius * 1.2, dotBorderPaint);

    final rayPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineStroke;

    Offset? p1;
    Offset? p2;

    if (m.angleP1 != null) {
      p1 = toCanvas(m.angleP1!);
      canvas.drawLine(v, p1, rayPaint);
      canvas.drawCircle(p1, dotRadius, vDotPaint);
      canvas.drawCircle(p1, dotRadius, dotBorderPaint);
    }

    if (m.angleP2 != null) {
      p2 = toCanvas(m.angleP2!);
      canvas.drawLine(v, p2, rayPaint);
      canvas.drawCircle(p2, dotRadius, vDotPaint);
      canvas.drawCircle(p2, dotRadius, dotBorderPaint);
    }

    if (p1 != null && p2 != null) {
      final double angleDeg = DxfMath.calculateAngleBetweenVectors(
        m.angleVertex!,
        m.angleP1!,
        m.angleP2!,
      );

      final double dx1 = p1.dx - v.dx;
        final double dy1 = p1.dy - v.dy;
        final double dx2 = p2.dx - v.dx;
        final double dy2 = p2.dy - v.dy;

        final double a1 = math.atan2(dy1, dx1);
        final double a2 = math.atan2(dy2, dx2);
        double sweep = a2 - a1;
        while (sweep <= -math.pi) {
          sweep += 2 * math.pi;
        }
        while (sweep > math.pi) {
          sweep -= 2 * math.pi;
        }

        final double arcRadius = (32.0 * mScale) / scale;
        final arcRect = Rect.fromCircle(center: v, radius: arcRadius);

        final arcPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineStroke;

        final sectorPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill;

        final sectorPath = Path()
          ..moveTo(v.dx, v.dy)
          ..arcTo(arcRect, a1, sweep, false)
          ..close();

        canvas.drawPath(sectorPath, sectorPaint);
        canvas.drawArc(arcRect, a1, sweep, false, arcPaint);

        final double midAngle = a1 + sweep / 2.0;
        final Offset badgePos = v +
            Offset(math.cos(midAngle), math.sin(midAngle)) *
                (arcRadius + (18.0 * mScale) / scale);

        _drawBadge(
          canvas: canvas,
          center: badgePos,
          text: '∠ = ${angleDeg.toStringAsFixed(1)}°',
          accentColor: accentColor,
          mScale: mScale,
          scale: scale,
        );
      }
    }

  void _drawRadiusMeasurement(
    Canvas canvas,
    DxfMeasurement m,
    Offset Function(Offset) toCanvas,
    double fitScale,
  ) {
    final scale = currentScale.clamp(0.001, 10000.0);
    final double mScale = settings.measurementScale;
    const accentColor = Color(0xFF00E676);

    // If points collected prior to 3-point solve
    if (m.circleCenter == null) {
      final dotPaint = Paint()..color = accentColor..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / scale;
      final dotRadius = (settings.pointSize * 0.85) / scale;
      for (final pt in m.circlePoints) {
        final cPt = toCanvas(pt);
        canvas.drawCircle(cPt, dotRadius, dotPaint);
        canvas.drawCircle(cPt, dotRadius, borderPaint);
      }
      return;
    }

    final c = toCanvas(m.circleCenter!);
    final double canvasRadius = m.radius! * fitScale;

    // 1. Highlight circle contour
    final circleHighlightPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 * settings.lineThicknessScale) / scale;
    canvas.drawCircle(c, canvasRadius, circleHighlightPaint);

    // 2. Center Crosshairs (+)
    final crossLen = (8.0 * mScale) / scale;
    final crossPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.4 * settings.lineThicknessScale) / scale;
    canvas.drawLine(c - Offset(crossLen, 0), c + Offset(crossLen, 0), crossPaint);
    canvas.drawLine(c - Offset(0, crossLen), c + Offset(0, crossLen), crossPaint);

    // 3. Radial leader line from center to edge
    Offset dir = const Offset(0.7071, -0.7071); // Default 45 deg
    if (m.circlePoints.isNotEmpty) {
      final sampleC = toCanvas(m.circlePoints.first);
      final delta = sampleC - c;
      if (delta.distance > 1e-4) {
        dir = delta / delta.distance;
      }
    }

    final edgePt = c + dir * canvasRadius;
    final leaderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.5 * settings.lineThicknessScale) / scale;
    canvas.drawLine(c, edgePt, leaderPaint);

    // Circle point on circumference
    canvas.drawCircle(edgePt, (settings.pointSize * 0.6) / scale, Paint()..color = accentColor);

    // 4. Dimension Badge
    final mid = Offset((c.dx + edgePt.dx) / 2, (c.dy + edgePt.dy) / 2);
    final String sub = 'Ø = ${DxfMath.formatDistance(m.radius! * 2.0, unit: effectiveUnit)} m${m.isArc && m.arcLength != null ? ' • Arc: ${DxfMath.formatDistance(m.arcLength!, unit: effectiveUnit)} m' : ''}';

    _drawBadge(
      canvas: canvas,
      center: mid + Offset(0, (-14.0 * mScale) / scale),
      text: 'R = ${DxfMath.formatDistance(m.radius!, unit: effectiveUnit)} m',
      subText: sub,
      accentColor: accentColor,
      mScale: mScale,
      scale: scale,
    );
  }

  void _drawBadge({
    required Canvas canvas,
    required Offset center,
    required String text,
    String? subText,
    required Color accentColor,
    required double mScale,
    required double scale,
  }) {
    try {
      final double fontSize = math.max(0.001, (9.5 * mScale) / scale);
      final double subFontSize = math.max(0.001, (8.5 * mScale) / scale);

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
      )..layout();

      TextPainter? subPainter;
      if (subText != null && subText.isNotEmpty) {
        subPainter = TextPainter(
          text: TextSpan(
            text: subText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: subFontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }

      final double contentW = math.max(textPainter.width, subPainter?.width ?? 0.0);
      final double contentH = textPainter.height + (subPainter != null ? subPainter.height + (2.0 / scale) : 0.0);

      final double padH = (7.0 * mScale) / scale;
      final double padV = (4.0 * mScale) / scale;
      final double cornerRadius = (5.0 * mScale) / scale;

      final bubbleRect = Rect.fromCenter(
        center: center,
        width: contentW + padH * 2,
        height: contentH + padV * 2,
      );

      final bgPaint = Paint()
        ..color = const Color(0xF2141C2B)
        ..style = PaintingStyle.fill;
      final borderBubble = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 * settings.lineThicknessScale) / scale;

      final rrect = RRect.fromRectAndRadius(bubbleRect, Radius.circular(cornerRadius));
      canvas.drawRRect(rrect, bgPaint);
      canvas.drawRRect(rrect, borderBubble);

      final double textLeft = bubbleRect.left + padH;
      final double textTop = bubbleRect.top + padV;
      textPainter.paint(canvas, Offset(textLeft, textTop));

      if (subPainter != null) {
        subPainter.paint(
          canvas,
          Offset(textLeft, textTop + textPainter.height + (2.0 / scale)),
        );
      }
    } catch (_) {}
  }

  @override
  bool shouldRepaint(covariant DxfPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.currentScale != currentScale ||
        oldDelegate.measurement != measurement ||
        oldDelegate.annotations != annotations ||
        oldDelegate.visibleCadRect != visibleCadRect ||
        oldDelegate.highlightedEntity != highlightedEntity ||
        oldDelegate.snapResult != snapResult ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.settings != settings;
  }
}
