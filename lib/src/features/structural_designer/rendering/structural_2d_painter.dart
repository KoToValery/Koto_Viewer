import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/slab_parallel_alignment_helper.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'structural_pointer_painter.dart';

/// 2D CustomPainter that renders structural elements, ghost storeys (ArchiCAD Trace Reference),
/// interactive drawing previews, and cantilever warning zones projected onto CAD scene coordinates.
class Structural2dPainter extends CustomPainter {
  final StoreyLevel currentStorey;
  final StoreyLevel? ghostStorey;
  final List<CantileverZone> cantileverZones;
  final VerticalCapacityReport? verticalReport;
  final SeismicAnalysisReport? seismicReport;
  final bool showCantileverHeatmap;
  final StructuralDrawTool activeTool;
  final StructuralColumn? previewColumn;
  final Offset? previewColumnPos;
  final Offset? wallStartPos;
  final Offset? currentCursorCad;
  final Offset? slabStartCornerCad;
  final List<Offset> slabPointsInProgress;
  final SlabEdgeGripInfo? extrudingGrip;
  final double? extrusionDistance;
  final String? selectedColumnId;
  final String? selectedShearWallId;
  final String? selectedBeamId;
  final StructuralGridAxis? axisOffsetPreview;
  final StructuralColumn? columnOffsetPreview;
  final String? selectedGridAxisId;
  final Offset? firstWallEdgeStartCad;
  final Offset? firstWallEdgeEndCad;
  final Offset? gridAxisPreviewStartCad;
  final Offset? gridAxisPreviewEndCad;
  final Offset? beamStartPos;
  final double beamPreviewWidth;
  final Offset? openingStartCornerCad;
  final (String, int)? selectedOpening;
  final List<Offset>? movingOpeningPolygon;
  final StructuralColumn? movingColumn;
  final Offset? movingColumnPos;
  final String? selectedSlabId;
  final int? draggingSlabVertexIndex;
  final Offset? draggingSlabVertexPos;
  final int? mergeCandidateVertexIndex;
  final (Offset, Offset, String)? activeMeasurement;
  final Offset? measurementStartCad;
  final SlabParallelAlignmentResult? activeParallelSnap;
  final List<Offset>? previewSlabOffsetPolygon;
  final AppLocalizations? l10n;
  final Offset? previewShearWallPos;
  final double previewWallLength;
  final double previewWallThickness;
  final double previewWallRotationRad;
  final StructuralShearWall? movingShearWall;
  final Offset? movingShearWallPos;
  final List<(Offset, Offset)>? magneticGuideLines;
  final (Offset, Offset)? dynamicDimensionLine;
  final String? dynamicDimensionText;
  final double cadUnitsPerMeter;
  final double zoomScale;
  final Offset Function(Offset) cadToScene;
  final double cadScale;

  const Structural2dPainter({
    required this.currentStorey,
    this.ghostStorey,
    this.cantileverZones = const [],
    this.verticalReport,
    this.seismicReport,
    this.showCantileverHeatmap = true,
    this.activeTool = StructuralDrawTool.select,
    this.previewColumn,
    this.previewColumnPos,
    this.wallStartPos,
    this.beamStartPos,
    this.beamPreviewWidth = 0.25,
    this.openingStartCornerCad,
    this.selectedOpening,
    this.movingOpeningPolygon,
    this.axisOffsetPreview,
    this.columnOffsetPreview,
    this.selectedGridAxisId,
    this.firstWallEdgeStartCad,
    this.firstWallEdgeEndCad,
    this.gridAxisPreviewStartCad,
    this.gridAxisPreviewEndCad,
    this.currentCursorCad,
    this.slabStartCornerCad,
    this.slabPointsInProgress = const [],
    this.extrudingGrip,
    this.extrusionDistance,
    this.activeParallelSnap,
    this.previewSlabOffsetPolygon,
    this.l10n,
    this.previewShearWallPos,
    this.previewWallLength = 1.5,
    this.previewWallThickness = 0.25,
    this.previewWallRotationRad = 0.0,
    this.movingShearWall,
    this.movingShearWallPos,
    this.magneticGuideLines,
    this.dynamicDimensionLine,
    this.dynamicDimensionText,
    this.selectedColumnId,
    this.selectedShearWallId,
    this.selectedBeamId,
    this.movingColumn,
    this.movingColumnPos,
    this.selectedSlabId,
    this.draggingSlabVertexIndex,
    this.draggingSlabVertexPos,
    this.mergeCandidateVertexIndex,
    this.activeMeasurement,
    this.measurementStartCad,
    this.cadUnitsPerMeter = 1.0,
    this.zoomScale = 1.0,
    required this.cadToScene,
    required this.cadScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Ghost Storey (Trace Reference underlay) if enabled
    if (ghostStorey != null) {
      _drawGhostStorey(canvas, ghostStorey!);
    }

    // 2. Draw Active Storey Slabs
    for (int i = 0; i < currentStorey.slabs.length; i++) {
      _drawSlab(canvas, currentStorey.slabs[i], slabIndex: i, isGhost: false);
    }

    // 2b. Draw Active Storey Beams
    for (final beam in currentStorey.beams) {
      _drawBeam(canvas, beam, isGhost: false);
    }

    // 2c. Draw Active Storey Grid Axes
    for (final axis in currentStorey.gridAxes) {
      _drawGridAxis(canvas, axis, isGhost: false);
    }

    // 2d. Draw Grid Axis Offset Preview (Live duplication guidance)
    if (axisOffsetPreview != null) {
      _drawGridAxis(canvas, axisOffsetPreview!, isGhost: false, isPreview: true);
    }

    // 3. Draw Active Storey Shear Walls
    for (final wall in currentStorey.shearWalls) {
      if (movingShearWall?.id == wall.id) continue;
      _drawShearWall(canvas, wall, isGhost: false);
    }

    // 4. Draw Active Storey Columns
    for (final col in currentStorey.columns) {
      if (movingColumn?.id == col.id) continue;
      _drawColumn(canvas, col, isGhost: false);
    }

    // 4b. Draw Column Offset Preview (Live duplication guidance)
    if (columnOffsetPreview != null) {
      _drawColumn(canvas, columnOffsetPreview!, isGhost: false, isPreview: true);
    }

    // 4c. Draw Magnetic Guidelines (ArchiCAD style cyan guides with diamond markers)
    if (magneticGuideLines != null && magneticGuideLines!.isNotEmpty) {
      _drawMagneticGuidelines(canvas, magneticGuideLines!);
    }

    // 5. Draw Interactive In-Progress Elements
    _drawInteractivePreview(canvas);

    // 5b. Draw live edge extrusion preview if dragging a midpoint grip
    if (extrudingGrip != null && extrusionDistance != null) {
      _drawEdgeExtrusionPreview(canvas, extrudingGrip!, extrusionDistance!);
    }

    // 6. Draw Cantilever Overhangs & Warning Zones (Heatmap)
    if (showCantileverHeatmap && cantileverZones.isNotEmpty) {
      _drawCantileverOverlays(canvas);
    }

    // 7. Draw Eurocode 8 Seismic Centers (CM, CR) and Eccentricity
    if (seismicReport != null) {
      _drawSeismicCenters(canvas);
    }

    // 8. Draw Distance Measurement Dimension Line & Badge
    if (activeMeasurement != null) {
      _drawMeasurementLine(canvas, activeMeasurement!.$1, activeMeasurement!.$2, activeMeasurement!.$3);
    } else if (activeTool == StructuralDrawTool.measure && measurementStartCad != null && currentCursorCad != null) {
      final p1 = measurementStartCad!;
      final p2 = currentCursorCad!;
      final lenM = (p2 - p1).distance / cadUnitsPerMeter;
      final thickCm = (lenM * 100).round();
      _drawMeasurementLine(canvas, p1, p2, '${lenM.toStringAsFixed(2)} m ($thickCm cm)');
    }

    // 8b. Draw Dynamic Dimension Line (e.g. 5cm-snapped dimension to nearest wall/column/axis)
    if (dynamicDimensionLine != null && dynamicDimensionText != null) {
      _drawMeasurementLine(
        canvas,
        dynamicDimensionLine!.$1,
        dynamicDimensionLine!.$2,
        dynamicDimensionText!,
        color: const Color(0xFF00E5FF),
      );
    }
  }

  void _drawMeasurementLine(Canvas canvas, Offset p1Cad, Offset p2Cad, String label, {Color color = const Color(0xFFFF5252)}) {
    final p1 = cadToScene(p1Cad);
    final p2 = cadToScene(p2Cad);
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;
    canvas.drawLine(p1, p2, linePaint);

    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > 1e-4) {
      final ux = dx / len;
      final uy = dy / len;
      final nx = -uy;
      final ny = ux;
      final tickSize = 8.0 / zoomScale;

      void drawTick(Offset p) {
        final t1 = Offset(p.dx + (nx + ux) * tickSize * 0.7, p.dy + (ny + uy) * tickSize * 0.7);
        final t2 = Offset(p.dx - (nx + ux) * tickSize * 0.7, p.dy - (ny + uy) * tickSize * 0.7);
        canvas.drawLine(t1, t2, linePaint..strokeWidth = 2.5 / zoomScale);
      }
      drawTick(p1);
      drawTick(p2);
    }

    // Centered label badge with offset
    final mid = Offset((p1.dx + p2.dx) / 2.0, (p1.dy + p2.dy) / 2.0);
    final offsetMid = len > 1e-4
        ? Offset(mid.dx - (dy / len) * (18.0 / zoomScale), mid.dy + (dx / len) * (18.0 / zoomScale))
        : mid;

    canvas.save();
    canvas.translate(offsetMid.dx, offsetMid.dy);
    canvas.scale(1.0 / zoomScale);

    final span = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    final bgRect = Rect.fromCenter(center: Offset.zero, width: tp.width + 12.0, height: tp.height + 6.0);
    final bgPaint = Paint()..color = const Color(0xEE1E1E24);
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(5.0)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(5.0)), borderPaint);
    tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));

    canvas.restore();
  }

  void _drawGhostStorey(Canvas canvas, StoreyLevel ghost) {
    for (int i = 0; i < ghost.slabs.length; i++) {
      _drawSlab(canvas, ghost.slabs[i], slabIndex: i, isGhost: true);
    }
    for (final beam in ghost.beams) {
      _drawBeam(canvas, beam, isGhost: true);
    }
    for (final axis in ghost.gridAxes) {
      _drawGridAxis(canvas, axis, isGhost: true);
    }
    for (final wall in ghost.shearWalls) {
      _drawShearWall(canvas, wall, isGhost: true);
    }
    for (final col in ghost.columns) {
      _drawColumn(canvas, col, isGhost: true);
    }
  }

  static const List<Color> slabPalette = [
    Color(0xFF00B0FF), // Sky Blue
    Color(0xFF00E676), // Emerald Green
    Color(0xFFFFB300), // Warm Amber
    Color(0xFFAA00FF), // Vivid Purple
    Color(0xFFFF5252), // Coral Red
    Color(0xFF00E5FF), // Deep Cyan
    Color(0xFFFF9100), // Orange
    Color(0xFF3D5AFE), // Royal Indigo
  ];

  Color _getSlabBaseColor(StructuralSlab slab, int slabIndex) {
    if (slab.colorValue != null) {
      return Color(slab.colorValue!);
    }
    return slabPalette[slabIndex % slabPalette.length];
  }

  void _drawSlabHatch(Canvas canvas, Path clipPath, Color color, {required int slabIndex, required bool isGhost}) {
    canvas.save();
    canvas.clipPath(clipPath);

    final bounds = clipPath.getBounds();
    final hatchPaint = Paint()
      ..color = color.withValues(alpha: isGhost ? 0.05 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;

    // Spacing between diagonal hatch lines in scene pixels:
    final spacing = (28.0 / zoomScale).clamp(0.4, 200.0);
    final minX = bounds.left - bounds.height * 1.5;
    final maxX = bounds.right + bounds.height * 1.5;

    // Vary hatch angle based on slabIndex so different slab panels immediately stand out
    final patternMode = slabIndex % 4;
    for (double x = minX; x <= maxX; x += spacing) {
      if (patternMode == 0) {
        // +45 degrees
        canvas.drawLine(
          Offset(x, bounds.top),
          Offset(x + bounds.height, bounds.bottom),
          hatchPaint,
        );
      } else if (patternMode == 1) {
        // -45 degrees
        canvas.drawLine(
          Offset(x, bounds.bottom),
          Offset(x + bounds.height, bounds.top),
          hatchPaint,
        );
      } else if (patternMode == 2) {
        // Steeper 60 degrees
        canvas.drawLine(
          Offset(x, bounds.top),
          Offset(x + bounds.height * 0.58, bounds.bottom),
          hatchPaint,
        );
      } else {
        // Cross-hatch
        canvas.drawLine(
          Offset(x, bounds.top),
          Offset(x + bounds.height, bounds.bottom),
          hatchPaint,
        );
        canvas.drawLine(
          Offset(x, bounds.bottom),
          Offset(x + bounds.height, bounds.top),
          hatchPaint,
        );
      }
    }
    canvas.restore();
  }

  void _drawSlabLevelMarker(Canvas canvas, StructuralSlab slab, Color slabColor, {required bool isGhost}) {
    if (isGhost || slab.polygon.length < 3) return;

    final centroidScene = cadToScene(slab.centroid);
    // Overhead slab bottom-up perspective:
    // When drawing on level H, structural plans represent the slab overhead (+ storey height)
    final overheadElev = currentStorey.elevation + currentStorey.height - (slab.floorFinish ?? currentStorey.floorFinishThickness);
    final int thickCm = (slab.thickness * 100).round();

    final sign = overheadElev > 0 ? '+' : (overheadElev == 0 ? '±' : '');
    final elevStr = '$sign${overheadElev.toStringAsFixed(2)}';

    canvas.save();
    canvas.translate(centroidScene.dx, centroidScene.dy);
    canvas.scale(1.0 / zoomScale);

    // Section slab elevation marker:
    // Downward structural level triangle \/ resting on horizontal shelf line
    // Level elevation "+2.80" above the shelf, thickness "d = 20 cm" below
    final elevSpan = TextSpan(
      text: elevStr,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );
    final elevPainter = TextPainter(
      text: elevSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final subSpan = TextSpan(
      text: 'd = $thickCm cm',
      style: TextStyle(
        color: slabColor.withValues(alpha: 0.95),
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
      ),
    );
    final subPainter = TextPainter(
      text: subSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final headerSpan = TextSpan(
      text: '▲ ПЛОЧА НАД ${currentStorey.name.toUpperCase()}',
      style: const TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 8.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      ),
    );
    final headerPainter = TextPainter(
      text: headerSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final contentWidth = math.max(headerPainter.width, math.max(elevPainter.width, subPainter.width) + 24.0);
    final badgeWidth = contentWidth + 16.0;
    final badgeHeight = headerPainter.height + elevPainter.height + subPainter.height + 16.0;
    final badgeRect = Rect.fromCenter(
      center: Offset.zero,
      width: badgeWidth,
      height: badgeHeight,
    );

    final bgPaint = Paint()
      ..color = const Color(0xF0181A22)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = slabColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(6.0));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // 1. Header (overhead slab indicator)
    headerPainter.paint(
      canvas,
      Offset(-headerPainter.width / 2.0, -badgeHeight / 2.0 + 4.0),
    );

    // 2. Section Triangle & Shelf Line
    final shelfY = -badgeHeight / 2.0 + headerPainter.height + elevPainter.height + 6.0;
    final shelfStartX = -badgeWidth / 2.0 + 10.0;
    final shelfEndX = badgeWidth / 2.0 - 10.0;

    final shelfPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(shelfStartX, shelfY), Offset(shelfEndX, shelfY), shelfPaint);

    // Authentic structural level triangle: apex pointing down touching the shelf line
    final triPath = Path()
      ..moveTo(shelfStartX + 4.0, shelfY - 7.0)
      ..lineTo(shelfStartX + 12.0, shelfY - 7.0)
      ..lineTo(shelfStartX + 8.0, shelfY)
      ..close();
    final triPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(triPath, triPaint);

    // 3. Elevation text above shelf
    elevPainter.paint(
      canvas,
      Offset(shelfStartX + 16.0, shelfY - elevPainter.height - 1.0),
    );

    // 4. Thickness text below shelf
    subPainter.paint(
      canvas,
      Offset(shelfStartX + 16.0, shelfY + 2.0),
    );

    canvas.restore();
  }

  void _drawSlab(Canvas canvas, StructuralSlab slab, {required int slabIndex, required bool isGhost}) {
    if (slab.polygon.length < 3) return;

    final isSelected = !isGhost && (slab.id == selectedSlabId);
    List<Offset> polygon = slab.polygon;
    if (isSelected &&
        draggingSlabVertexIndex != null &&
        draggingSlabVertexPos != null &&
        draggingSlabVertexIndex! < polygon.length) {
      polygon = List<Offset>.from(polygon);
      polygon[draggingSlabVertexIndex!] = draggingSlabVertexPos!;
    }

    final pts = polygon.map(cadToScene).toList();
    final path = Path()..fillType = PathFillType.evenOdd;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    // Subtract openings
    for (final op in slab.openings) {
      if (op.length >= 3) {
        final opPts = op.map(cadToScene).toList();
        final opPath = Path();
        opPath.moveTo(opPts.first.dx, opPts.first.dy);
        for (int i = 1; i < opPts.length; i++) {
          opPath.lineTo(opPts[i].dx, opPts[i].dy);
        }
        opPath.close();
        path.addPath(opPath, Offset.zero);
      }
    }

    final slabColor = _getSlabBaseColor(slab, slabIndex);

    final fillPaint = Paint()
      ..color = isGhost
          ? slabColor.withValues(alpha: 0.08)
          : (isSelected
              ? slabColor.withValues(alpha: 0.35)
              : slabColor.withValues(alpha: 0.18))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? slabColor.withValues(alpha: 0.35)
          : (isSelected ? Colors.white : slabColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isGhost
          ? (1.0 / zoomScale)
          : (isSelected ? (2.5 / zoomScale) : (1.8 / zoomScale));

    canvas.drawPath(path, fillPaint);

    // Light transparent diagonal hatch pattern (щриховка) for clear slab distinction
    _drawSlabHatch(canvas, path, slabColor, slabIndex: slabIndex, isGhost: isGhost);

    canvas.drawPath(path, borderPaint);

    // Draw openings outline & architectural X cross
    for (int oIdx = 0; oIdx < slab.openings.length; oIdx++) {
      final op = slab.openings[oIdx];
      if (op.length >= 3) {
        final opPts = op.map(cadToScene).toList();
        final opPath = Path()..moveTo(opPts.first.dx, opPts.first.dy);
        for (int i = 1; i < opPts.length; i++) {
          opPath.lineTo(opPts[i].dx, opPts[i].dy);
        }
        opPath.close();

        final isOpSelected = !isGhost &&
            selectedOpening != null &&
            selectedOpening!.$1 == slab.id &&
            selectedOpening!.$2 == oIdx;
        final bool isMovingThis = isOpSelected && movingOpeningPolygon != null;

        final opBorderPaint = Paint()
          ..color = isGhost
              ? const Color(0x66FFB74D)
              : (isMovingThis
                  ? const Color(0x55FFFFFF)
                  : (isOpSelected ? const Color(0xFFFF5252) : const Color(0xFFFF9800)))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isOpSelected ? (2.5 / zoomScale) : (1.5 / zoomScale);

        canvas.drawPath(opPath, opBorderPaint);

        // Draw architectural X cross
        if (opPts.length >= 4) {
          canvas.drawLine(opPts[0], opPts[2], opBorderPaint);
          canvas.drawLine(opPts[1], opPts[3], opBorderPaint);
        }
      }
    }

    // Central structural elevation marker (конструктивен разрез с конструктивна кота)
    _drawSlabLevelMarker(canvas, slab, slabColor, isGhost: isGhost);

    // If selected, draw corner vertex handles
    if (isSelected) {
      _drawSlabVertexHandles(canvas, polygon);
    }

    // Draw midpoint edge grips for slabs on active storey
    if (!isGhost) {
      _drawSlabEdgeGrips(canvas, slab);
    }
  }

  void _drawSlabVertexHandles(Canvas canvas, List<Offset> polygon) {
    final double radius = 6.0 / zoomScale;
    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;

    final candidateFill = Paint()
      ..color = const Color(0x55F44336)
      ..style = PaintingStyle.fill;
    final candidateStroke = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / zoomScale;

    for (int i = 0; i < polygon.length; i++) {
      final scenePt = cadToScene(polygon[i]);
      if (mergeCandidateVertexIndex == i) {
        // Highlight merge candidate with glowing red target
        canvas.drawCircle(scenePt, radius * 1.8, candidateFill);
        canvas.drawCircle(scenePt, radius * 1.8, candidateStroke);
      }

      if (draggingSlabVertexIndex == i) {
        // Active dragging vertex
        final activeFill = Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scenePt, radius * 1.3, activeFill);
        canvas.drawCircle(scenePt, radius * 1.3, handleStroke);
      } else {
        canvas.drawCircle(scenePt, radius, handleFill);
        canvas.drawCircle(scenePt, radius, handleStroke);
      }
    }
  }

  void _drawSlabEdgeGrips(Canvas canvas, StructuralSlab slab) {
    final grips = slab.edgeGrips;
    if (grips.isEmpty) return;

    final double radius = 4.5 / zoomScale;
    final gripFill = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final gripBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / zoomScale;

    for (final grip in grips) {
      if (extrudingGrip != null &&
          extrudingGrip!.edgeIndex == grip.edgeIndex &&
          (extrudingGrip!.midpoint - grip.midpoint).distance < 1e-4) {
        continue;
      }
      final sceneMid = cadToScene(grip.midpoint);
      canvas.drawCircle(sceneMid, radius, gripFill);
      canvas.drawCircle(sceneMid, radius, gripBorder);
    }
  }

  void _drawEdgeExtrusionPreview(
      Canvas canvas, SlabEdgeGripInfo grip, double d) {
    final v1 = grip.v1;
    final v2 = grip.v2;
    final normal = grip.normal;
    final vNew1 = v1 + normal * d;
    final vNew2 = v2 + normal * d;
    final midNew = grip.midpoint + normal * d;

    final sV1 = cadToScene(v1);
    final sV2 = cadToScene(v2);
    final sNew1 = cadToScene(vNew1);
    final sNew2 = cadToScene(vNew2);
    final sMidNew = cadToScene(midNew);

    // 1. Draw Magnetic Parallel Alignment Guideline (ArchiCAD style)
    if (activeParallelSnap != null) {
      final sRefA = cadToScene(activeParallelSnap!.refStart);
      final sRefB = cadToScene(activeParallelSnap!.refEnd);
      final refVec = sRefB - sRefA;
      final refLen = refVec.distance;
      if (refLen > 1e-4) {
        final uRef = refVec / refLen;
        // Extend guideline past endpoints for clear alignment sighting across screen
        final guideStart = sRefA - uRef * (150.0 / zoomScale);
        final guideEnd = sRefB + uRef * (150.0 / zoomScale);

        final guidePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0 / zoomScale
          ..style = PaintingStyle.stroke;
        canvas.drawLine(guideStart, guideEnd, guidePaint);

        // Magnetic diamond markers at reference segment ends
        final markerPaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.fill;
        void drawDiamond(Offset pt) {
          final s = 4.5 / zoomScale;
          final p = Path()
            ..moveTo(pt.dx, pt.dy - s)
            ..lineTo(pt.dx + s, pt.dy)
            ..lineTo(pt.dx, pt.dy + s)
            ..lineTo(pt.dx - s, pt.dy)
            ..close();
          canvas.drawPath(p, markerPaint);
        }
        drawDiamond(sRefA);
        drawDiamond(sRefB);
      }
    }

    // 2. Draw preview polygon or extruded region
    if (previewSlabOffsetPolygon != null && previewSlabOffsetPolygon!.length >= 3) {
      final previewScenePts = previewSlabOffsetPolygon!.map(cadToScene).toList();
      final previewPath = Path()..addPolygon(previewScenePts, true);
      final previewFill = Paint()
        ..color = const Color(0x3800E5FF)
        ..style = PaintingStyle.fill;
      final previewBorder = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 / zoomScale;
      canvas.drawPath(previewPath, previewFill);
      canvas.drawPath(previewPath, previewBorder);
    } else {
      // Translucent fill for extruded region
      final fillPath = Path()
        ..moveTo(sV1.dx, sV1.dy)
        ..lineTo(sNew1.dx, sNew1.dy)
        ..lineTo(sNew2.dx, sNew2.dy)
        ..lineTo(sV2.dx, sV2.dy)
        ..close();

      final fillPaint = Paint()
        ..color = const Color(0x3800E5FF)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Perpendicular side connection lines
      final sidePaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;
      canvas.drawLine(sV1, sNew1, sidePaint);
      canvas.drawLine(sV2, sNew2, sidePaint);

      // Parallel extruded front edge
      final frontPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawLine(sNew1, sNew2, frontPaint);
    }

    // Original edge (dimmed line showing existing baseline)
    final ghostEdgePaint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawLine(sV1, sV2, ghostEdgePaint);

    // New corner vertex dots
    final vDotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final dotRadius = 4.0 / zoomScale;
    canvas.drawCircle(sNew1, dotRadius, vDotPaint);
    canvas.drawCircle(sNew2, dotRadius, vDotPaint);

    // Existing corner dots (anchors that stay in place)
    final anchorPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawCircle(sV1, dotRadius, anchorPaint);
    canvas.drawCircle(sV2, dotRadius, anchorPaint);

    // Midpoint active grip handle with glowing ring
    final gripRadius = 5.5 / zoomScale;
    final gripPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;
    canvas.drawCircle(sMidNew, gripRadius, gripPaint);
    canvas.drawCircle(sMidNew, gripRadius + 3.0 / zoomScale, ringPaint);

    // Distance badge text in crisp screen-space pixels
    canvas.save();
    canvas.translate(sMidNew.dx, sMidNew.dy);
    canvas.scale(1.0 / zoomScale);

    final bool isAligned = activeParallelSnap != null;
    final distText = isAligned
        ? (l10n != null
            ? l10n!.slabParallelAligned(d.abs().toStringAsFixed(2))
            : '${d.abs().toStringAsFixed(2)} m (Прилепено)')
        : '${d.abs().toStringAsFixed(2)} m';

    final textSpan = TextSpan(
      text: distText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const badgeOffset = Offset(12.0, -12.0);
    final bgRect = Rect.fromLTWH(
      badgeOffset.dx - 4.0,
      badgeOffset.dy - 2.0,
      textPainter.width + 8.0,
      textPainter.height + 4.0,
    );
    final badgeBgPaint = Paint()
      ..color = const Color(0xCC000000)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4.0)),
      badgeBgPaint,
    );
    if (isAligned) {
      final badgeBorderPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4.0)),
        badgeBorderPaint,
      );
    }
    textPainter.paint(canvas, badgeOffset);
    canvas.restore();
  }

  void _drawBeam(Canvas canvas, StructuralBeam beam, {required bool isGhost}) {
    final pts = beam.polygonVertices.map(cadToScene).toList();
    if (pts.length < 4) return;
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final isSelected = !isGhost && (beam.id == selectedBeamId);

    final fillPaint = Paint()
      ..color = isGhost
          ? const Color(0x33FFA726)
          : (isSelected ? const Color(0x66FFB300) : const Color(0x44FFA726))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x66FFB300)
          : (isSelected ? const Color(0xFFFFD54F) : const Color(0xFFFB8C00))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? (2.5 / zoomScale) : (1.6 / zoomScale);

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Centerline
    final centerPaint = Paint()
      ..color = isGhost ? const Color(0x40FFFFFF) : const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    canvas.drawLine(cadToScene(beam.start), cadToScene(beam.end), centerPaint);

    if (isSelected) {
      final selectHalo = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawPath(path, selectHalo);

      final handlePaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final handleSize = 3.5 / zoomScale;
      for (final pt in pts) {
        canvas.drawRect(
          Rect.fromCenter(center: pt, width: handleSize * 2, height: handleSize * 2),
          handlePaint,
        );
      }
    }

    // Beam designation / number badge (e.g. "Г1", "Г2" or "B1", "B2")
    if (!isGhost && beam.displayName.isNotEmpty) {
      final sStart = cadToScene(beam.start);
      final sEnd = cadToScene(beam.end);
      final midScene = Offset((sStart.dx + sEnd.dx) / 2.0, (sStart.dy + sEnd.dy) / 2.0);

      canvas.save();
      canvas.translate(midScene.dx, midScene.dy);
      canvas.scale(1.0 / zoomScale);

      final textSpan = TextSpan(
        text: beam.displayName,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final bgRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6.0,
        height: tp.height + 2.5,
      );
      final labelBgPaint = Paint()
        ..color = const Color(0xCC1E1E24)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3.5)),
        labelBgPaint,
      );

      final labelBorderPaint = Paint()
        ..color = isSelected ? const Color(0xFFFFD54F) : const Color(0xFFFB8C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(3.5)),
        labelBorderPaint,
      );

      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
      canvas.restore();
    }
  }

  void _drawGridAxis(Canvas canvas, StructuralGridAxis axis, {required bool isGhost, bool isPreview = false}) {
    final p1 = cadToScene(axis.start);
    final p2 = cadToScene(axis.end);
    final isSelected = !isGhost && !isPreview && (axis.id == selectedGridAxisId);

    final axisPaint = Paint()
      ..color = isGhost
          ? const Color(0x66FF453A)
          : isPreview
              ? const Color(0xFF00E5FF)
              : (isSelected ? const Color(0xFFFF9F0A) : const Color(0xFFFF453A))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSelected || isPreview ? 2.5 : 1.5) / zoomScale;

    _drawDashDotLine(canvas, p1, p2, axisPaint);

    if (axis.bubbleAtEnd) {
      _drawAxisBubble(canvas, p2, axis.direction, axis.name, isSelected: isSelected || isPreview, isGhost: isGhost);
    }
    if (axis.bubbleAtStart) {
      _drawAxisBubble(canvas, p1, -axis.direction, axis.name, isSelected: isSelected || isPreview, isGhost: isGhost);
    }

    if (isSelected) {
      final handlePaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / zoomScale;
      final handleRadius = 6.0 / zoomScale;

      canvas.drawCircle(p1, handleRadius, handlePaint);
      canvas.drawCircle(p1, handleRadius, handleBorder);

      canvas.drawCircle(p2, handleRadius, handlePaint);
      canvas.drawCircle(p2, handleRadius, handleBorder);
    }
  }

  void _drawAxisBubble(
    Canvas canvas,
    Offset center,
    Offset dir,
    String label, {
    required bool isSelected,
    required bool isGhost,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0 / zoomScale);

    const radius = 13.0;
    final bgPaint = Paint()
      ..color = isGhost ? const Color(0xCC2C2C2E) : const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x66FF453A)
          : (isSelected ? const Color(0xFFFF9F0A) : const Color(0xFFFF453A))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.8;

    canvas.drawCircle(Offset.zero, radius, bgPaint);
    canvas.drawCircle(Offset.zero, radius, borderPaint);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isGhost ? const Color(0xAAFFFFFF) : Colors.white,
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      -textPainter.width / 2.0,
      -textPainter.height / 2.0,
    );
    textPainter.paint(canvas, textOffset);
    canvas.restore();
  }

  void _drawDashDotLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final v = p2 - p1;
    final dist = v.distance;
    if (dist < 1e-4) return;
    final u = v / dist;

    final dashLen = 14.0 / zoomScale;
    final gapLen = 4.0 / zoomScale;
    final dotLen = 2.0 / zoomScale;

    double d = 0.0;
    while (d < dist) {
      final dEnd = math.min(d + dashLen, dist);
      canvas.drawLine(p1 + u * d, p1 + u * dEnd, paint);
      d += dashLen + gapLen;
      if (d >= dist) break;

      final dotEnd = math.min(d + dotLen, dist);
      canvas.drawLine(p1 + u * d, p1 + u * dotEnd, paint);
      d += dotLen + gapLen;
    }
  }

  void _drawShearWall(Canvas canvas, StructuralShearWall wall,
      {required bool isGhost, bool isPreview = false, bool isMoving = false}) {
    final pts = wall.polygonVertices.map(cadToScene).toList();
    if (pts.length < 4) return;
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final fillPaint = Paint()
      ..color = isPreview || isMoving
          ? const Color(0xB300E5FF)
          : (isGhost ? const Color(0x4D78909C) : const Color(0xE637474F))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isPreview || isMoving
          ? const Color(0xFF00E5FF)
          : (isGhost ? const Color(0x8090A4AE) : const Color(0xFFCFD8DC))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isPreview || isMoving ? 2.5 : 1.2) / zoomScale;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Axial centerline of the shear wall (for beam connections and grid axis alignment)
    final centerLinePaint = Paint()
      ..color = isPreview || isMoving
          ? const Color(0xFF00E5FF)
          : (isGhost ? const Color(0x40FFFFFF) : const Color(0xFF00E5FF).withValues(alpha: 0.8))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isPreview || isMoving ? 2.0 : 1.5) / zoomScale;
    canvas.drawLine(cadToScene(wall.start), cadToScene(wall.end), centerLinePaint);

    final isSelected = !isGhost && (wall.id == selectedShearWallId);
    if (isSelected) {
      final selectHalo = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawPath(path, selectHalo);

      final handlePaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final handleSize = 3.5 / zoomScale;
      for (final pt in pts) {
        canvas.drawRect(
          Rect.fromCenter(center: pt, width: handleSize * 2, height: handleSize * 2),
          handlePaint,
        );
      }
    }

    // Shear wall designation / number badge (e.g. "Ш1", "Ш2" or "W1", "W2")
    if (!isGhost && wall.displayName.isNotEmpty) {
      final midScene = Offset(
        (pts[0].dx + pts[1].dx + pts[2].dx + pts[3].dx) / 4.0,
        (pts[0].dy + pts[1].dy + pts[2].dy + pts[3].dy) / 4.0,
      );

      canvas.save();
      canvas.translate(midScene.dx, midScene.dy);
      canvas.scale(1.0 / zoomScale);

      final textSpan = TextSpan(
        text: wall.displayName,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final bgRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6.0,
        height: tp.height + 2.5,
      );
      final labelBgPaint = Paint()
        ..color = const Color(0xCC1E1E24)
        ..style = PaintingStyle.fill;
      final labelBorderPaint = Paint()
        ..color = isSelected ? const Color(0xFFFFB300) : const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), labelBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), labelBorderPaint);
      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));

      canvas.restore();
    }
  }

  void _drawMagneticGuidelines(Canvas canvas, List<(Offset, Offset)> guides) {
    final guidePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;
    final diamondPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (final guide in guides) {
      final s1 = cadToScene(guide.$1);
      final s2 = cadToScene(guide.$2);
      final v = s2 - s1;
      final len = v.distance;
      if (len > 1e-4) {
        final u = v / len;
        final gStart = s1 - u * (150.0 / zoomScale);
        final gEnd = s2 + u * (150.0 / zoomScale);
        canvas.drawLine(gStart, gEnd, guidePaint);

        final s = 4.5 / zoomScale;
        void drawDiamond(Offset pt) {
          final p = Path()
            ..moveTo(pt.dx, pt.dy - s)
            ..lineTo(pt.dx + s, pt.dy)
            ..lineTo(pt.dx, pt.dy + s)
            ..lineTo(pt.dx - s, pt.dy)
            ..close();
          canvas.drawPath(p, diamondPaint);
        }
        drawDiamond(s1);
        drawDiamond(s2);
      }
    }
  }

  void _drawColumn(Canvas canvas, StructuralColumn col,
      {required bool isGhost, bool isPreview = false}) {
    final pts = col.polygonVertices.map(cadToScene).toList();
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final bool isMovingThis = movingColumn != null && movingColumn!.id == col.id;
    final bool isSelected = !isGhost && !isPreview && (col.id == selectedColumnId);
    final vCheck = (!isGhost && !isPreview && !isMovingThis)
        ? verticalReport?.getCheckForColumn(col.id)
        : null;
    final bool isFloating = (!isGhost && !isPreview && !isMovingThis)
        ? (seismicReport?.isColumnFloating(col.id) ?? false)
        : false;

    final Color fillColor;
    final Color borderColor;
    if (isPreview) {
      fillColor = const Color(0x6600E5FF);
      borderColor = const Color(0xFF00E5FF);
    } else if (isGhost) {
      fillColor = const Color(0x4D64B5F6);
      borderColor = const Color(0x8090CAF9);
    } else if (isMovingThis) {
      fillColor = const Color(0x331565C0);
      borderColor = const Color(0x66FFFFFF);
    } else if (isFloating) {
      // Glows MAGENTA for floating / transfer columns
      fillColor = const Color(0xEEAA00FF);
      borderColor = const Color(0xFFE040FB);
    } else if (vCheck != null && vCheck.status == VerticalCapacityStatus.critical) {
      // Glows RED for critical crushing or punching failure
      fillColor = const Color(0xEEB71C1C);
      borderColor = const Color(0xFFFF1744);
    } else if (vCheck != null && vCheck.status == VerticalCapacityStatus.warning) {
      // Glows ORANGE/AMBER for near-capacity columns
      fillColor = const Color(0xEEF57F17);
      borderColor = const Color(0xFFFFB300);
    } else {
      fillColor = const Color(0xF01565C0);
      borderColor = Colors.white;
    }

    // Glowing aura behind critical, warning, or floating columns
    if ((isFloating || (vCheck != null && vCheck.status != VerticalCapacityStatus.safe)) && !isGhost && !isMovingThis) {
      final Color auraColor = isFloating
          ? const Color(0xFFE040FB)
          : (vCheck!.status == VerticalCapacityStatus.critical
              ? const Color(0xFFFF1744)
              : const Color(0xFFFFB300));
      final glowPaint = Paint()
        ..color = auraColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5 / zoomScale;
      canvas.drawPath(path, glowPaint);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isPreview
          ? (2.2 / zoomScale)
          : ((isFloating || (vCheck != null && vCheck.status == VerticalCapacityStatus.critical)) ? (2.4 / zoomScale) : (1.5 / zoomScale));

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Punching shear risk indicator (EC2 §6.4 control perimeter alert)
    if (vCheck != null && vCheck.isPunchingCritical && !isGhost && !isMovingThis) {
      final centerScene = cadToScene(col.center);
      final double rPunching = (math.max(col.width, col.height) / 2.0 + 0.35) * cadScale;
      final punchPaint = Paint()
        ..color = const Color(0xFFFF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / zoomScale;
      canvas.drawCircle(centerScene, rPunching, punchPaint);
    }

    // Floating column badge (EC8 vertical regularity alert)
    if (isFloating && !isGhost && !isMovingThis) {
      final centerScene = cadToScene(col.center);
      final badgeAnchorY = centerScene.dy - (col.height * cadScale / 2.0);
      canvas.save();
      canvas.translate(centerScene.dx, badgeAnchorY);
      canvas.scale(1.0 / zoomScale);

      const textSpan = TextSpan(
        text: 'НАСАДЕНА',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final badgeCenter = Offset(0, -tp.height / 2.0 - 4.0);
      final bgRect = Rect.fromCenter(
        center: badgeCenter,
        width: tp.width + 6.0,
        height: tp.height + 2.0,
      );
      final badgeBgPaint = Paint()
        ..color = const Color(0xEEAA00FF)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), badgeBgPaint);
      tp.paint(canvas, Offset(-tp.width / 2.0, badgeCenter.dy - tp.height / 2.0));
      canvas.restore();
    }

    // Selected highlight halo & corner grip handles
    if (isSelected && !isMovingThis) {
      final selectHalo = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;
      canvas.drawPath(path, selectHalo);

      final handlePaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.fill;
      final handleSize = 3.5 / zoomScale;
      for (final pt in pts) {
        canvas.drawRect(
          Rect.fromCenter(center: pt, width: handleSize * 2, height: handleSize * 2),
          handlePaint,
        );
      }
    }

    // Centroid crossmark
    final crossPaint = Paint()
      ..color = isGhost
          ? const Color(0x40FFFFFF)
          : isMovingThis
              ? const Color(0x40FFFFFF)
              : const Color(0xCCFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;

    final centerScene = cadToScene(col.center);
    final double crossLen = (math.min(col.width, col.height) * cadScale * 0.25)
        .clamp(3.0 / zoomScale, 14.0 / zoomScale);
    canvas.drawLine(
      Offset(centerScene.dx - crossLen, centerScene.dy),
      Offset(centerScene.dx + crossLen, centerScene.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(centerScene.dx, centerScene.dy - crossLen),
      Offset(centerScene.dx, centerScene.dy + crossLen),
      crossPaint,
    );

    // Column designation / number badge (e.g. "К1", "К2") - compact, screen-space scaled so it doesn't obstruct
    if (!isGhost && !isMovingThis && col.displayName.isNotEmpty) {
      canvas.save();
      canvas.translate(centerScene.dx, centerScene.dy);
      canvas.scale(1.0 / zoomScale);

      final textSpan = TextSpan(
        text: col.displayName,
        style: TextStyle(
          color: isPreview
              ? const Color(0xFF00E5FF)
              : (isSelected ? const Color(0xFFFFD54F) : Colors.white),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final bgRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 6.0,
        height: tp.height + 2.5,
      );
      final labelBgPaint = Paint()
        ..color = const Color(0xCC1E1E24)
        ..style = PaintingStyle.fill;
      final labelBorderPaint = Paint()
        ..color = isPreview
            ? const Color(0xFF00E5FF)
            : (isSelected ? const Color(0xFFFFB300) : const Color(0x66FFFFFF))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), labelBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), labelBorderPaint);
      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
      canvas.restore();
    }
  }

  void _drawInteractivePreview(Canvas canvas) {
    // 1. Moving column live preview
    if (movingColumn != null && movingColumnPos != null) {
      final col = movingColumn!.copyWith(center: movingColumnPos!);
      final pts = col.polygonVertices.map(cadToScene).toList();
      if (pts.isNotEmpty) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final movingFill = Paint()
          ..color = const Color(0x99FFB300)
          ..style = PaintingStyle.fill;
        final movingBorder = Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / zoomScale;

        canvas.drawPath(path, movingFill);
        canvas.drawPath(path, movingBorder);
      }
    }

    // 1b. Moving opening live preview
    if (movingOpeningPolygon != null && movingOpeningPolygon!.length >= 3) {
      final pts = movingOpeningPolygon!.map(cadToScene).toList();
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();

      final movingFill = Paint()
        ..color = const Color(0x99FFB300)
        ..style = PaintingStyle.fill;
      final movingBorder = Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;

      canvas.drawPath(path, movingFill);
      canvas.drawPath(path, movingBorder);
      if (pts.length >= 4) {
        canvas.drawLine(pts[0], pts[2], movingBorder);
        canvas.drawLine(pts[1], pts[3], movingBorder);
      }
    }

    // 1c. Moving shear wall live preview
    if (movingShearWall != null && movingShearWallPos != null) {
      final dir = movingShearWall!.end - movingShearWall!.start;
      final halfLen = dir.distance / 2.0;
      final u = dir.distance > 1e-4 ? dir / dir.distance : const Offset(1, 0);
      final movedWall = movingShearWall!.copyWith(
        start: movingShearWallPos! - u * halfLen,
        end: movingShearWallPos! + u * halfLen,
      );
      _drawShearWall(canvas, movedWall, isGhost: false, isMoving: true);
    }

    // 2. New column placement live preview
    if (activeTool == StructuralDrawTool.column &&
        previewColumn != null &&
        previewColumnPos != null &&
        movingColumn == null) {
      final col = previewColumn!.copyWith(center: previewColumnPos!);
      final pts = col.polygonVertices.map(cadToScene).toList();
      if (pts.isNotEmpty) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final previewFill = Paint()
          ..color = const Color(0x8000E5FF)
          ..style = PaintingStyle.fill;
        final previewBorder = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, previewFill);
        canvas.drawPath(path, previewBorder);
      }
    } else if (activeTool == StructuralDrawTool.shearWall) {
      if (previewShearWallPos != null && movingShearWall == null) {
        final dir = Offset(math.cos(previewWallRotationRad), math.sin(previewWallRotationRad));
        final halfLen = previewWallLength / 2.0;
        final previewWall = StructuralShearWall(
          id: 'preview_wall',
          start: previewShearWallPos! - dir * halfLen,
          end: previewShearWallPos! + dir * halfLen,
          thickness: previewWallThickness,
        );
        _drawShearWall(canvas, previewWall, isGhost: false, isPreview: true);
      }
    } else if (activeTool == StructuralDrawTool.beam &&
        beamStartPos != null &&
        currentCursorCad != null) {
      final previewBeam = StructuralBeam(
        id: 'preview_beam',
        start: beamStartPos!,
        end: currentCursorCad!,
        width: beamPreviewWidth,
      );
      final pts = previewBeam.polygonVertices.map(cadToScene).toList();
      if (pts.length >= 4) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        final pFill = Paint()
          ..color = const Color(0x66FFB300)
          ..style = PaintingStyle.fill;
        final pBorder = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, pFill);
        canvas.drawPath(path, pBorder);
        canvas.drawLine(
            cadToScene(beamStartPos!), cadToScene(currentCursorCad!), pBorder);
      }
    } else if (activeTool == StructuralDrawTool.slab) {
      if (slabStartCornerCad != null && currentCursorCad != null) {
        // Live rectangular slab preview
        final c1 = slabStartCornerCad!;
        final c2 = currentCursorCad!;
        final minX = math.min(c1.dx, c2.dx);
        final maxX = math.max(c1.dx, c2.dx);
        final minY = math.min(c1.dy, c2.dy);
        final maxY = math.max(c1.dy, c2.dy);

        final p1 = cadToScene(Offset(minX, maxY));
        final p2 = cadToScene(Offset(maxX, maxY));
        final p3 = cadToScene(Offset(maxX, minY));
        final p4 = cadToScene(Offset(minX, minY));

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();

        final slabFill = Paint()
          ..color = const Color(0x3300E5FF)
          ..style = PaintingStyle.fill;
        final slabBorder = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, slabFill);
        canvas.drawPath(path, slabBorder);

        // 4 corner dots
        final cornerDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        final rDot = 4.0 / zoomScale;
        canvas.drawCircle(p1, rDot, cornerDot);
        canvas.drawCircle(p2, rDot, cornerDot);
        canvas.drawCircle(p3, rDot, cornerDot);
        canvas.drawCircle(p4, rDot, cornerDot);

        // Midpoint dots preview
        final midDot = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.fill;
        final m1 = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final m2 = Offset((p2.dx + p3.dx) / 2, (p2.dy + p3.dy) / 2);
        final m3 = Offset((p3.dx + p4.dx) / 2, (p3.dy + p4.dy) / 2);
        final m4 = Offset((p4.dx + p1.dx) / 2, (p4.dy + p1.dy) / 2);
        canvas.drawCircle(m1, rDot, midDot);
        canvas.drawCircle(m2, rDot, midDot);
        canvas.drawCircle(m3, rDot, midDot);
        canvas.drawCircle(m4, rDot, midDot);
      } else if (slabPointsInProgress.isNotEmpty) {
        final slabPaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        final pts = slabPointsInProgress.map(cadToScene).toList();
        for (int i = 0; i < pts.length - 1; i++) {
          canvas.drawLine(pts[i], pts[i + 1], slabPaint);
        }

        bool isCloseSnap = false;
        if (currentCursorCad != null) {
          final sCursor = cadToScene(currentCursorCad!);
          if (slabPointsInProgress.length >= 3 &&
              (currentCursorCad! - slabPointsInProgress.first).distance < (28.0 / (cadScale * zoomScale))) {
            isCloseSnap = true;
            final closeLinePaint = Paint()
              ..color = const Color(0xFF00E676)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 / zoomScale;
            canvas.drawLine(pts.last, pts.first, closeLinePaint);
          } else {
            canvas.drawLine(pts.last, sCursor, slabPaint);
          }
        }

        final vDot = Paint()
          ..color = const Color(0xFFFF5252)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < pts.length; i++) {
          final p = pts[i];
          canvas.drawCircle(p, 4.0 / zoomScale, vDot);
        }

        // Highlight first point when >= 3 points with closure snap indicator
        if (slabPointsInProgress.length >= 3) {
          final ringPaint = Paint()
            ..color = isCloseSnap ? const Color(0xFF00E676) : const Color(0xFF00E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (isCloseSnap ? 3.0 : 1.5) / zoomScale;
          canvas.drawCircle(pts.first, (isCloseSnap ? 9.0 : 6.0) / zoomScale, ringPaint);
          if (isCloseSnap) {
            final innerDot = Paint()
              ..color = const Color(0xFF00E676)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(pts.first, 4.5 / zoomScale, innerDot);
          }
        }
      }
    } else if (activeTool == StructuralDrawTool.slabOpening &&
        openingStartCornerCad != null &&
        currentCursorCad != null) {
      final c1 = openingStartCornerCad!;
      final c2 = currentCursorCad!;
      final minX = math.min(c1.dx, c2.dx);
      final maxX = math.max(c1.dx, c2.dx);
      final minY = math.min(c1.dy, c2.dy);
      final maxY = math.max(c1.dy, c2.dy);

      final p1 = cadToScene(Offset(minX, maxY));
      final p2 = cadToScene(Offset(maxX, maxY));
      final p3 = cadToScene(Offset(maxX, minY));
      final p4 = cadToScene(Offset(minX, minY));

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      final opFill = Paint()
        ..color = const Color(0x33FF9800)
        ..style = PaintingStyle.fill;
      final opBorder = Paint()
        ..color = const Color(0xFFFF9800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / zoomScale;

      canvas.drawPath(path, opFill);
      canvas.drawPath(path, opBorder);
      // Architectural X cross
      canvas.drawLine(p1, p3, opBorder);
      canvas.drawLine(p2, p4, opBorder);
    } else if (activeTool == StructuralDrawTool.gridAxis) {
      // 1. Highlight first selected wall edge
      if (firstWallEdgeStartCad != null && firstWallEdgeEndCad != null) {
        final p1 = cadToScene(firstWallEdgeStartCad!);
        final p2 = cadToScene(firstWallEdgeEndCad!);

        final haloPaint = Paint()
          ..color = const Color(0x6600E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0 / zoomScale;
        final edgePaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / zoomScale;

        canvas.drawLine(p1, p2, haloPaint);
        canvas.drawLine(p1, p2, edgePaint);

        final dotPaint = Paint()
          ..color = const Color(0xFF00E5FF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p1, 4.0 / zoomScale, dotPaint);
        canvas.drawCircle(p2, 4.0 / zoomScale, dotPaint);
      }

      // 2. Live preview of resulting grid axis centerline
      if (gridAxisPreviewStartCad != null && gridAxisPreviewEndCad != null) {
        final p1 = cadToScene(gridAxisPreviewStartCad!);
        final p2 = cadToScene(gridAxisPreviewEndCad!);
        final previewPaint = Paint()
          ..color = const Color(0xCCFF453A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        _drawDashDotLine(canvas, p1, p2, previewPaint);
        final dir = (p2 - p1);
        final len = dir.distance;
        final uDir = len > 1e-4 ? dir / len : const Offset(1, 0);
        _drawAxisBubble(canvas, p1, -uDir, '?', isSelected: true, isGhost: false);
        _drawAxisBubble(canvas, p2, uDir, '?', isSelected: true, isGhost: false);
      }
    }
  }

  void _drawCantileverOverlays(Canvas canvas) {
    for (final zone in cantileverZones) {
      final Color color = zone.riskLevel.color;
      final Color fill = zone.riskLevel.fillColor;

      final s = cadToScene(zone.supportEdgeStart);
      final e = cadToScene(zone.supportEdgeEnd);
      final tip = cadToScene(zone.overhangTip);

      // Draw overhang span line from support to tip
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / zoomScale;

      canvas.drawLine(s, tip, linePaint);

      // Tip indicator
      final tipPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tip, 6.0 / zoomScale, tipPaint);

      if (zone.isCorner) {
        // Draw corner triangle
        final cornerPath = Path()
          ..moveTo(s.dx, s.dy)
          ..lineTo(e.dx, e.dy)
          ..lineTo(tip.dx, tip.dy)
          ..close();

        final cornerFill = Paint()
          ..color = fill
          ..style = PaintingStyle.fill;
        canvas.drawPath(cornerPath, cornerFill);

        // Corner warning badge
        final cornerRing = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;
        canvas.drawCircle(tip, 10.0 / zoomScale, cornerRing);
      }
    }
  }

  void _drawSeismicCenters(Canvas canvas) {
    if (seismicReport == null) return;
    final check = seismicReport!.getCheckForStorey(currentStorey.id);
    if (check == null || !check.hasSlabDiaphragm) return;
    if (check.centerOfMassCad == null || check.centerOfRigidityCad == null) return;

    final cmScene = cadToScene(check.centerOfMassCad!);
    final crScene = cadToScene(check.centerOfRigidityCad!);

    final double distScene = (cmScene - crScene).distance;

    // Draw line of eccentricity between CM and CR
    if (distScene > 4.0 / zoomScale) {
      final linePaint = Paint()
        ..color = check.isTorsionallySensitive
            ? const Color(0xFFFF1744)
            : const Color(0xFFD500F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 / zoomScale;
      _drawDashDotLine(canvas, cmScene, crScene, linePaint);

      // Eccentricity label in the middle of line (crisp screen-space pixels)
      final mid = (cmScene + crScene) / 2.0;
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.scale(1.0 / zoomScale);

      final textSpan = TextSpan(
        text: 'e = ${check.maxEccentricityM.toStringAsFixed(2)} m (${(check.maxEccentricityRatio * 100).round()}%)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final badgeRect = Rect.fromCenter(
        center: Offset.zero,
        width: tp.width + 10.0,
        height: tp.height + 4.0,
      );
      final bgPaint = Paint()
        ..color = (check.isTorsionallySensitive ? const Color(0xDD000000) : const Color(0xCC1E1E1E))
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = check.isTorsionallySensitive ? const Color(0xFFFF1744) : const Color(0xFFD500F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4.0)), bgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4.0)), borderPaint);
      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
      canvas.restore();
    }

    // Draw Center of Mass (CM) marker: Cyan/Blue target
    _drawCenterTarget(canvas, cmScene, 'CM', const Color(0xFF00E5FF));

    // Draw Center of Rigidity (CR) marker: Magenta/Purple target
    _drawCenterTarget(canvas, crScene, 'CR', const Color(0xFFD500F9));
  }

  void _drawCenterTarget(Canvas canvas, Offset pos, String label, Color color) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(1.0 / zoomScale);

    const double r = 11.0;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset.zero, r, fillPaint);
    canvas.drawCircle(Offset.zero, r, strokePaint);

    // Crosshairs
    const double chLen = r * 1.4;
    canvas.drawLine(const Offset(-chLen, 0), const Offset(chLen, 0), strokePaint);
    canvas.drawLine(const Offset(0, -chLen), const Offset(0, chLen), strokePaint);

    // Label badge above
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    final badgeCenter = Offset(0, -r - tp.height / 2.0 - 4.0);
    final bgRect = Rect.fromCenter(
      center: badgeCenter,
      width: tp.width + 6.0,
      height: tp.height + 2.0,
    );
    final bgPaint = Paint()..color = const Color(0xCC000000)..style = PaintingStyle.fill;
    final badgeBorder = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(3.0)), badgeBorder);
    tp.paint(canvas, Offset(-tp.width / 2.0, badgeCenter.dy - tp.height / 2.0));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Structural2dPainter oldDelegate) {
    return true;
  }
}
