import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/slab_parallel_alignment_helper.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';
import 'structural_pointer_painter.dart';
import 'slab_plan_labels.dart';
import 'grid_axis_presentation.dart';
import 'support_span_overlay_layout.dart';
import 'structural_overview_layout.dart';

/// 2D CustomPainter that renders structural elements, ghost storeys (ArchiCAD Trace Reference),
/// interactive drawing previews, and cantilever warning zones projected onto CAD scene coordinates.
class Structural2dPainter extends CustomPainter {
  final StoreyLevel currentStorey;
  final List<StoreyLevel> gridAxisStoreys;
  final StoreyLevel? floorSlabStorey;
  final StoreyLevel? ceilingSlabStorey;
  final StoreyLevel? ghostStorey;
  final List<CantileverZone> cantileverZones;
  final VerticalCapacityReport? verticalReport;
  final SeismicAnalysisReport? seismicReport;
  final bool showCantileverHeatmap;
  final bool showSlabSpanOverlay;
  final List<SupportSpanCheck>? supportSpanChecks;
  final Offset? spanFocusCad;
  final Rect? spanVisibleCadRect;
  final StructuralDrawTool activeTool;
  final StructuralColumn? previewColumn;
  final Offset? previewColumnPos;
  final Offset? wallStartPos;
  final Offset? currentCursorCad;
  final Offset? slabStartCornerCad;
  final List<Offset> slabPointsInProgress;
  final List<Offset> openingPointsInProgress;
  final SlabOpeningType activeOpeningType;
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
  final int? selectedOpeningVertexIndex;
  final int? draggingOpeningVertexIndex;
  final Offset? draggingOpeningVertexPos;
  final int? mergeCandidateOpeningVertexIndex;
  final SlabEdgeGripInfo? extrudingOpeningGrip;
  final double? extrudingOpeningDistance;
  final List<Offset>? previewOpeningOffsetPolygon;
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
  final bool hasBasement;
  final FoundationType foundationType;
  final List<List<Offset>>? stripFoundations;
  final StructuralSlab? matFoundation;

  const Structural2dPainter({
    required this.currentStorey,
    this.gridAxisStoreys = const [],
    this.floorSlabStorey,
    this.ceilingSlabStorey,
    this.ghostStorey,
    this.hasBasement = false,
    this.foundationType = FoundationType.stripFooting,
    this.stripFoundations,
    this.matFoundation,
    this.cantileverZones = const [],
    this.verticalReport,
    this.seismicReport,
    this.showCantileverHeatmap = true,
    this.showSlabSpanOverlay = true,
    this.supportSpanChecks,
    this.spanFocusCad,
    this.spanVisibleCadRect,
    this.activeTool = StructuralDrawTool.select,
    this.previewColumn,
    this.previewColumnPos,
    this.wallStartPos,
    this.beamStartPos,
    this.beamPreviewWidth = 0.25,
    this.openingStartCornerCad,
    this.selectedOpening,
    this.movingOpeningPolygon,
    this.selectedOpeningVertexIndex,
    this.draggingOpeningVertexIndex,
    this.draggingOpeningVertexPos,
    this.mergeCandidateOpeningVertexIndex,
    this.extrudingOpeningGrip,
    this.extrudingOpeningDistance,
    this.previewOpeningOffsetPolygon,
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
    this.openingPointsInProgress = const [],
    this.activeOpeningType = SlabOpeningType.shaft,
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
    // 0. Draw Ground Foundations (Strip footings or Mat Foundation) at elevation 0.00 if no basement
    if (currentStorey.elevation.abs() < 1e-4 && !hasBasement) {
      _drawGroundFoundations(canvas);
    }

    // 1. Draw Ghost Storey (Trace Reference underlay) if enabled
    if (ghostStorey != null) {
      _drawGhostStorey(canvas, ghostStorey!);
    }

    // The lower storey's ceiling is also this storey's floor. Show it even
    // with trace reference off, without making it an editable roof plate.
    final floor = floorSlabStorey;
    if (floor != null) {
      for (var i = 0; i < floor.slabs.length; i++) {
        _drawSlab(canvas, floor.slabs[i], slabIndex: i,
          isGhost: currentStorey.slabs.isNotEmpty, readOnly: true,
          levelOwner: floor, isFloor: true);
      }
    }

    // Floor slabs drawn on the higher level are the ceiling of this plan.
    final ceiling = ceilingSlabStorey;
    if (ceiling != null) {
      for (var i = 0; i < ceiling.slabs.length; i++) {
        _drawSlab(canvas, ceiling.slabs[i], slabIndex: i, isGhost: false,
          readOnly: true, levelOwner: ceiling);
      }
    }

    // 2. Slabs owned by this drawing remain available for editing.
    if (currentStorey.slabs.isNotEmpty) {
      for (int i = 0; i < currentStorey.slabs.length; i++) {
        _drawSlab(
          canvas,
          currentStorey.slabs[i],
          slabIndex: i,
          isGhost: false,
        );
      }
    }

    // Circulation polygons are separate visual reservations, never slab holes.
    for(final zone in currentStorey.staircaseZones.values) {
      if(zone.length<3) continue;
      final points=zone.map(cadToScene).toList();
      final path=Path()..moveTo(points.first.dx,points.first.dy);
      for(final p in points.skip(1)) { path.lineTo(p.dx,p.dy); } path.close();
      canvas.drawPath(path,Paint()..color=const Color(0xFF80CBC4).withValues(alpha:.06));
      canvas.drawPath(path,Paint()..color=const Color(0xFF80CBC4).withValues(alpha:.65)
        ..style=PaintingStyle.stroke..strokeWidth=1/zoomScale);
    }

    // 2b. Draw Active Storey Beams
    for (final beam in currentStorey.beams) {
      _drawBeam(canvas, beam, isGhost: false);
    }

    // 2c. Draw Active Storey Grid Axes
    final axisBubbles=_gridAxisBubbleCenters();
    for (final axis in currentStorey.gridAxes) {
      _drawGridAxis(canvas, axis, isGhost: false, bubbleCenters:axisBubbles);
    }

    // 2d. Draw Grid Axis Offset Preview (Live duplication guidance)
    if (axisOffsetPreview != null) {
      _drawGridAxis(canvas, axisOffsetPreview!, isGhost: false, isPreview: true);
    }

    final overview = _supportOverviewLabels(size);
    if (showSlabSpanOverlay) {
      _drawSupportSpanFeedback(canvas, size,
          reservedLabels: overview.map((l) => l.rect).toList());
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
    _drawSupportOverviewLabels(canvas, overview);
    if (activeTool == StructuralDrawTool.slab) _drawSlabLabels(canvas);
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

  List<SupportSpanCheck> get _supportChecks => supportSpanChecks ?? verticalReport?.slabChecks
      .where((s) => s.storeyId == currentStorey.id).firstOrNull?.supportSpans ?? const [];

  TextPainter _spanSummaryText() {
    final problems=_supportChecks.where((c)=>c.isProblematic).length;
    final unknown=_supportChecks.where((c)=>!c.isDetermined).length;
    final count=l10n?.spanFeedbackCount(problems) ?? 'Spacing problems: $problems';
    final scope=l10n?.spanFeedbackScope ?? 'Preliminary · assigned slab thickness';
    return TextPainter(text:TextSpan(
        text:'$count\n$scope${unknown>0 ? '\n${l10n?.spanFeedbackUnknown(unknown) ?? 'Unknown: $unknown'}' : ''}',
        style:const TextStyle(color:Color(0xFFFFE0B2),fontSize:10,fontWeight:FontWeight.w600)),
        textDirection:TextDirection.ltr)..layout();
  }

  Rect _spanSummaryRect(Rect viewport,TextPainter text) => Rect.fromLTWH(
      viewport.left+10,viewport.top+10,
      math.min(text.width+16,math.max(0,viewport.width-20)),text.height+12);

  void _drawSupportSpanFeedback(Canvas canvas, Size size, {List<Rect> reservedLabels = const []}) {
    final checks = _supportChecks;
    if (checks.isEmpty) return;
    final zoom = zoomScale.clamp(.001,10000.0);
    Offset pixel(Offset p) => cadToScene(p)*zoom;
    final viewport = spanVisibleCadRect == null
        ? Rect.fromLTWH(0,0,size.width*zoom,size.height*zoom)
        : Rect.fromPoints(pixel(spanVisibleCadRect!.topLeft),pixel(spanVisibleCadRect!.bottomRight));
    String label(SupportSpanCheck c) =>
        'L ${c.spanM.toStringAsFixed(2)} > ${c.allowableSpanM.toStringAsFixed(2)} m · h ${(c.thicknessM*100).round()} cm';
    Color color(SupportSpanCheck c) => !c.isProblematic ? const Color(0xFF69F0AE) :
        c.utilization>=1.3 ? const Color(0xFFFF5252) : const Color(0xFFFFB74D);
    TextPainter text(String value,Color color,{double fontSize=11}) => TextPainter(
        text:TextSpan(text:value,style:TextStyle(color:color,fontSize:fontSize,
            fontWeight:FontWeight.w600)),textDirection:TextDirection.ltr)..layout();
    final summaryText=_spanSummaryText();
    final summaryRect=_spanSummaryRect(viewport,summaryText);
    final focusRect=spanFocusCad==null ? null :
        Rect.fromCircle(center:pixel(spanFocusCad!),radius:30);
    final layout=SupportSpanOverlayLayout.build(checks:checks,toPixel:pixel,
        viewport:viewport.deflate(3),focusCad:spanFocusCad,scale:cadUnitsPerMeter,
        reserved:[summaryRect,?focusRect,...reservedLabels,
          for(final c in currentStorey.columns)
            StructuralOverviewLayout.boundsOf(StructuralOverviewLayout.columnSymbol(
              c.polygonVertices.map(pixel).toList())).inflate(3),
          for(final w in currentStorey.shearWalls)
            StructuralOverviewLayout.boundsOf(w.polygonVertices.map(pixel).toList()).inflate(3)],labelSize:(c) {
          final tp=text(label(c),color(c)); return Size(tp.width+12,tp.height+8);
        });
    canvas.save();
    canvas.scale(1/zoom);
    canvas.clipRect(viewport);
    for(final line in layout.lines) {
      final c=color(line.check);
      // Subtle broad stripe plus a crisp stroke keeps every zone visible while
      // letting the drawing show through. Only local connections are emphasized.
      canvas.drawLine(line.start,line.end,Paint()
        ..color=c.withValues(alpha:line.focused ? .16 : .07)..strokeWidth=line.focused ? 9 : 6);
      canvas.drawLine(line.start,line.end,Paint()
        ..color=c.withValues(alpha:line.focused ? 1 : .85)..strokeWidth=line.focused ? 2.8 : 2.0);
    }
    void badge(Rect rect,TextPainter tp,Color c) {
      final shape=RRect.fromRectAndRadius(rect,const Radius.circular(5));
      canvas.drawRRect(shape,Paint()..color=const Color(0xED1E1E24));
      canvas.drawRRect(shape,Paint()..color=c.withValues(alpha:.7)
        ..style=PaintingStyle.stroke..strokeWidth=1);
      tp.paint(canvas,Offset(rect.left+6,rect.top+4));
    }
    for(final item in layout.labels) {
      badge(item.rect,text(label(item.line.check),color(item.line.check)),color(item.line.check));
    }
    badge(summaryRect,summaryText,const Color(0xFFFFB74D));
    canvas.restore();
  }

  List<SupportOverviewLabel> _supportOverviewLabels(Size size) {
    final zoom = zoomScale.clamp(.001,10000.0);
    Offset pixel(Offset p) => cadToScene(p)*zoom;
    final viewport = spanVisibleCadRect == null
        ? Rect.fromLTWH(0,0,size.width*zoom,size.height*zoom)
        : Rect.fromPoints(pixel(spanVisibleCadRect!.topLeft),pixel(spanVisibleCadRect!.bottomRight));
    final entries = <SupportOverviewEntry>[];
    void add(String id, String name, Offset anchor, Rect bounds, Color color,
        {bool selected=false, bool warning=false}) {
      final label = '$name${warning ? ' !' : ''}';
      final tp = TextPainter(text: TextSpan(text:label,
          style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w800)),
          textDirection:TextDirection.ltr)..layout();
      entries.add(SupportOverviewEntry(id:id,label:label,anchor:anchor,
          symbolBounds:bounds,labelSize:Size(tp.width+10,tp.height+6),color:color,
          priority:selected ? 3 : warning ? 2 : 0));
    }
    for(final c in currentStorey.columns) {
      if(c.id==movingColumn?.id) continue;
      final check=verticalReport?.getCheckForColumn(c.id);
      final floating=seismicReport?.isColumnFloating(c.id) ?? false;
      final disconnected=seismicReport?.storeyChecks.where((s)=>s.storeyId==currentStorey.id)
          .firstOrNull?.disconnectedColumnIds.contains(c.id) ?? false;
      final warning=floating || disconnected || (check!=null && check.status!=VerticalCapacityStatus.safe);
      final color=floating ? const Color(0xFFE040FB) :
        (disconnected || check?.status==VerticalCapacityStatus.critical) ? const Color(0xFFFF5252) :
        warning ? const Color(0xFFFFB300) : const Color(0xFF82B1FF);
      final symbol=StructuralOverviewLayout.columnSymbol(c.polygonVertices.map(pixel).toList());
      add(c.id,c.displayName,pixel(c.center),StructuralOverviewLayout.boundsOf(symbol),
          color,selected:c.id==selectedColumnId,warning:warning);
    }
    final seismic=seismicReport?.storeyChecks.where((s)=>s.storeyId==currentStorey.id).firstOrNull;
    for(final w in currentStorey.shearWalls) {
      if(w.id==movingShearWall?.id) continue;
      final warning=(seismic?.discontinuousWallIds.contains(w.id) ?? false) ||
          (seismic?.disconnectedWallIds.contains(w.id) ?? false);
      final pts=w.polygonVertices.map(pixel).toList();
      final center=pts.reduce((a,b)=>a+b)/pts.length.toDouble();
      // Reserve the actual section, enlarged only enough for the overview stripe.
      final bounds=StructuralOverviewLayout.boundsOf(pts).inflate(3);
      add(w.id,w.displayName,center,bounds,
          warning ? const Color(0xFFE040FB) : const Color(0xFF64FFDA),
          selected:w.id==selectedShearWallId,warning:warning);
    }
    return StructuralOverviewLayout.arrange(entries,viewport.deflate(3),
        reserved:showSlabSpanOverlay && _supportChecks.isNotEmpty
            ? [_spanSummaryRect(viewport,_spanSummaryText())] : const []);
  }

  void _drawSupportOverviewLabels(Canvas canvas,List<SupportOverviewLabel> labels) {
    final zoom=zoomScale.clamp(.001,10000.0);
    canvas.save(); canvas.scale(1/zoom);
    for(final label in labels) {
      final entry=label.entry, rect=label.rect;
      final edge=Offset(entry.anchor.dx.clamp(rect.left,rect.right).toDouble(),
          entry.anchor.dy.clamp(rect.top,rect.bottom).toDouble());
      canvas.drawLine(entry.anchor,edge,Paint()
        ..color=const Color(0xE60B1320)..strokeWidth=3);
      canvas.drawLine(entry.anchor,edge,Paint()
        ..color=entry.color.withValues(alpha:.8)..strokeWidth=1);
      final shape=RRect.fromRectAndRadius(rect,const Radius.circular(4));
      canvas.drawRRect(shape,Paint()..color=const Color(0xF20B1320));
      canvas.drawRRect(shape,Paint()..color=entry.color
          ..style=PaintingStyle.stroke..strokeWidth=1.2);
      final tp=TextPainter(text:TextSpan(text:entry.label,
          style:TextStyle(color:entry.color,fontSize:11.5,fontWeight:FontWeight.w800)),
          textDirection:TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(rect.left+5,rect.top+3));
    }
    canvas.restore();
  }

  void _drawGhostStorey(Canvas canvas, StoreyLevel ghost) {
    for (int i = 0; i < ghost.slabs.length; i++) {
      if (floorSlabStorey?.slabs.any((s) => s.id == ghost.slabs[i].id) == true ||
          ceilingSlabStorey?.slabs.any((s) => s.id == ghost.slabs[i].id) == true) {
        continue;
      }
      _drawSlab(canvas, ghost.slabs[i], slabIndex: i, isGhost: true);
    }
    for (final beam in ghost.beams) {
      _drawBeam(canvas, beam, isGhost: true);
    }
    for (final axis in ghost.gridAxes) {
      if (!currentStorey.gridAxes.any((a) => a.id == axis.id)) {
        _drawGridAxis(canvas, axis, isGhost: true);
      }
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

  void _drawGroundFoundations(Canvas canvas) {
    if (foundationType == FoundationType.stripFooting &&
        stripFoundations != null &&
        stripFoundations!.isNotEmpty) {
      final fillPaint = Paint()
        ..color = const Color(0x22546E7A)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = const Color(0x8878909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / zoomScale;

      for (final poly in stripFoundations!) {
        if (poly.length < 3) continue;
        final pts = poly.map(cadToScene).toList();
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    } else if (foundationType == FoundationType.matFoundation && matFoundation != null) {
      final pts = matFoundation!.polygon.map(cadToScene).toList();
      if (pts.length >= 3) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();
        final fillPaint = Paint()
          ..color = const Color(0x22546E7A)
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = const Color(0x9978909C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / zoomScale;
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  void _drawSlabLabels(Canvas canvas) {
    final labels = SlabPlanLabels.layout(current:currentStorey, lower:floorSlabStorey,
      upper:ceilingSlabStorey, project:cadToScene, zoom:zoomScale, selectedId:selectedSlabId);
    String level(double z) => '${z > 0 ? '+' : z == 0 ? '±' : ''}${z.toStringAsFixed(2)}';
    for (final label in labels.reversed) {
      final slab = label.slab;
      final selected = !label.reference && slab.id == selectedSlabId;
      final index = label.owner.slabs.indexOf(slab);
      final color = _getSlabBaseColor(slab, index).withValues(alpha:label.reference ? .6 : 1);
      if ((label.rect.center - label.anchor).distance > 1 / zoomScale) {
        canvas.drawLine(label.anchor, label.rect.center, Paint()..color=color..strokeWidth=1 / zoomScale);
      }
      canvas.save();
      canvas.translate(label.rect.center.dx, label.rect.center.dy);
      canvas.scale(1 / zoomScale);
      final rect = Rect.fromCenter(center:Offset.zero, width:126, height:52);
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(rounded, Paint()..color=const Color(0xF0181A22));
      canvas.drawRRect(rounded, Paint()..color=selected ? Colors.white : color
        ..style=PaintingStyle.stroke..strokeWidth=selected ? 2 : 1);
      final concrete = label.owner.structuralElevationFor(slab);
      final ownerText = l10n?.localeName == 'bg' ? 'Етаж' : 'Level';
      final text = TextPainter(text:TextSpan(children:[
        TextSpan(text:'$ownerText ${level(label.owner.elevation)}\n', style:TextStyle(color: selected ? Colors.white : Colors.white70, fontSize:10)),
        TextSpan(text:'${label.floor ? '↓' : '↑'} ${level(concrete)}\n', style:const TextStyle(color:Colors.white,fontSize:11.5,fontWeight:FontWeight.bold)),
        TextSpan(text:'d = ${(slab.thickness * 100).round()} cm', style:TextStyle(color:color,fontSize:9.5)),
      ]),textDirection:TextDirection.ltr,textAlign:TextAlign.center)..layout(maxWidth:120);
      text.paint(canvas, Offset(-text.width / 2,-text.height / 2));
      canvas.restore();
    }
  }

  void _drawSlab(
    Canvas canvas,
    StructuralSlab slab, {
    required int slabIndex,
    required bool isGhost,
    bool readOnly = false,
    StoreyLevel? levelOwner,
    bool isFloor = false,
  }) {
    if (slab.polygon.length < 3) return;

    final isSelected = !readOnly && !isGhost && (slab.id == selectedSlabId);
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
      ..color = slabColor.withValues(alpha: isGhost ? .08 : isSelected ? .35 : .18)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isGhost ? slabColor.withValues(alpha: .35)
          : isSelected ? Colors.white : slabColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isGhost ? 1.0 : isSelected ? 2.5 : 1.8) / zoomScale;

    final bool isSlabTool = activeTool == StructuralDrawTool.slab;
    if (isSlabTool) {
      canvas.drawPath(path, fillPaint);
    }

    // Smooth clean outline without diagonal hatching (as requested)
    canvas.drawPath(path, borderPaint);

    // Draw openings outline & architectural representation per type
    for (int oIdx = 0; oIdx < slab.openings.length; oIdx++) {
      final op = slab.openings[oIdx];
      if (op.length >= 3) {
        final isOpSelected = !readOnly && !isGhost &&
            selectedOpening != null &&
            selectedOpening!.$1 == slab.id &&
            selectedOpening!.$2 == oIdx;
        final bool isMovingThis = isOpSelected && movingOpeningPolygon != null;
        final opType = slab.getOpeningType(oIdx);

        List<Offset> effectiveOp = op;
        if (isOpSelected) {
          if (draggingOpeningVertexIndex != null &&
              draggingOpeningVertexPos != null &&
              draggingOpeningVertexIndex! < op.length) {
            effectiveOp = List<Offset>.from(op);
            effectiveOp[draggingOpeningVertexIndex!] = draggingOpeningVertexPos!;
          } else if (previewOpeningOffsetPolygon != null && previewOpeningOffsetPolygon!.isNotEmpty) {
            effectiveOp = previewOpeningOffsetPolygon!;
          }
        }

        final opPts = effectiveOp.map(cadToScene).toList();
        final opPath = Path()..moveTo(opPts.first.dx, opPts.first.dy);
        for (int i = 1; i < opPts.length; i++) {
          opPath.lineTo(opPts[i].dx, opPts[i].dy);
        }
        opPath.close();

        final Color baseColor;
        switch (opType) {
          case SlabOpeningType.staircase:
            baseColor = const Color(0xFF00B0FF);
            break;
          case SlabOpeningType.elevator:
            baseColor = const Color(0xFF7C4DFF);
            break;
          case SlabOpeningType.shaft:
          case SlabOpeningType.custom:
            baseColor = const Color(0xFFFF9800);
            break;
        }

        final opFillPaint = Paint()
          ..color = isGhost
              ? baseColor.withValues(alpha: 0.05)
              : (isOpSelected ? baseColor.withValues(alpha: 0.25) : baseColor.withValues(alpha: 0.12))
            ..style = PaintingStyle.fill;
        canvas.drawPath(opPath, opFillPaint);

        final opBorderPaint = Paint()
          ..color = isGhost
              ? baseColor.withValues(alpha: 0.4)
              : (isMovingThis
                  ? const Color(0x55FFFFFF)
                  : (isOpSelected ? const Color(0xFFFF5252) : baseColor))
          ..style = PaintingStyle.stroke
          ..strokeWidth = isOpSelected ? (2.5 / zoomScale) : (1.5 / zoomScale);

        canvas.drawPath(opPath, opBorderPaint);

        // Internal architectural drafting details
        if (opPts.length >= 4) {
          if (opType == SlabOpeningType.staircase) {
            _drawStaircaseTreads(canvas, opPts, opBorderPaint);
          } else if (opType == SlabOpeningType.elevator) {
            canvas.drawLine(opPts[0], opPts[2], opBorderPaint);
            canvas.drawLine(opPts[1], opPts[3], opBorderPaint);
            _drawElevatorCabin(canvas, opPts, opBorderPaint);
          } else {
            // Standard MEP shaft / custom cutout: architectural X cross
            canvas.drawLine(opPts[0], opPts[2], opBorderPaint);
            canvas.drawLine(opPts[1], opPts[3], opBorderPaint);
          }
        }

        // Draw interactive polygon vertex handles and edge grips when opening is selected
        if (isOpSelected) {
          _drawOpeningVertexHandles(canvas, effectiveOp);
          _drawOpeningEdgeGrips(canvas, slab, oIdx);
          if (extrudingOpeningGrip != null && extrudingOpeningDistance != null) {
            _drawOpeningExtrusionPreview(canvas, extrudingOpeningGrip!, extrudingOpeningDistance!);
          }
        }
      }
    }

    // Draw corner vertex handles and midpoint edge grips ONLY when the slab tool is active AND this slab is selected
    if (isSlabTool && isSelected && !isGhost) {
      _drawSlabVertexHandles(canvas, polygon);
      _drawSlabEdgeGrips(canvas, slab);
    }
  }

  void _drawSlabVertexHandles(Canvas canvas, List<Offset> polygon) {
    final double radius = 3.8 / zoomScale;
    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;

    final candidateFill = Paint()
      ..color = const Color(0x55F44336)
      ..style = PaintingStyle.fill;
    final candidateStroke = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;

    // Magnetic link line between dragged vertex and candidate
    if (mergeCandidateVertexIndex != null &&
        draggingSlabVertexIndex != null &&
        mergeCandidateVertexIndex! < polygon.length &&
        draggingSlabVertexIndex! < polygon.length) {
      final sCand = cadToScene(polygon[mergeCandidateVertexIndex!]);
      final sDrag = cadToScene(polygon[draggingSlabVertexIndex!]);
      final linkPaint = Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / zoomScale;
      _drawDashDotLine(canvas, sDrag, sCand, linkPaint);

      final outerRingPaint = Paint()
        ..color = const Color(0x88FF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / zoomScale;
      canvas.drawCircle(sCand, radius * 1.8, outerRingPaint);
    }

    for (int i = 0; i < polygon.length; i++) {
      final scenePt = cadToScene(polygon[i]);
      if (mergeCandidateVertexIndex == i) {
        // Highlight merge candidate with glowing red target
        canvas.drawCircle(scenePt, radius * 1.6, candidateFill);
        canvas.drawCircle(scenePt, radius * 1.6, candidateStroke);
      }

      if (draggingSlabVertexIndex == i) {
        // Active dragging vertex
        final activeFill = Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scenePt, radius * 1.2, activeFill);
        canvas.drawCircle(scenePt, radius * 1.2, handleStroke);
      } else {
        canvas.drawCircle(scenePt, radius, handleFill);
        canvas.drawCircle(scenePt, radius, handleStroke);
      }
    }
  }

  void _drawSlabEdgeGrips(Canvas canvas, StructuralSlab slab) {
    final grips = slab.edgeGrips;
    if (grips.isEmpty) return;

    final double radius = 3.0 / zoomScale;
    final gripFill = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final gripBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;

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
            : '${d.abs().toStringAsFixed(2)} m')
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

  void _drawOpeningVertexHandles(Canvas canvas, List<Offset> polygon) {
    final double radius = 6.0 / zoomScale;
    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;

    final candidateFill = Paint()
      ..color = const Color(0x55F44336)
      ..style = PaintingStyle.fill;
    final candidateStroke = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 / zoomScale;

    if (mergeCandidateOpeningVertexIndex != null &&
        draggingOpeningVertexIndex != null &&
        mergeCandidateOpeningVertexIndex! < polygon.length &&
        draggingOpeningVertexIndex! < polygon.length) {
      final sCand = cadToScene(polygon[mergeCandidateOpeningVertexIndex!]);
      final sDrag = cadToScene(polygon[draggingOpeningVertexIndex!]);
      final linkPaint = Paint()
        ..color = const Color(0xFFFF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / zoomScale;
      _drawDashDotLine(canvas, sDrag, sCand, linkPaint);

      final outerRingPaint = Paint()
        ..color = const Color(0x88FF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / zoomScale;
      canvas.drawCircle(sCand, radius * 2.4, outerRingPaint);
    }

    for (int i = 0; i < polygon.length; i++) {
      final scenePt = cadToScene(polygon[i]);
      if (mergeCandidateOpeningVertexIndex == i) {
        canvas.drawCircle(scenePt, radius * 1.8, candidateFill);
        canvas.drawCircle(scenePt, radius * 1.8, candidateStroke);
      }

      if (draggingOpeningVertexIndex == i) {
        final activeFill = Paint()
          ..color = const Color(0xFFFFD600)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scenePt, radius * 1.3, activeFill);
        canvas.drawCircle(scenePt, radius * 1.3, handleStroke);
      } else if (selectedOpeningVertexIndex == i) {
        final selFill = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scenePt, radius * 1.2, selFill);
        canvas.drawCircle(scenePt, radius * 1.2, handleStroke);
      } else {
        canvas.drawCircle(scenePt, radius, handleFill);
        canvas.drawCircle(scenePt, radius, handleStroke);
      }
    }
  }

  void _drawOpeningEdgeGrips(Canvas canvas, StructuralSlab slab, int opIdx) {
    final grips = slab.getOpeningEdgeGrips(opIdx);
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
      if (extrudingOpeningGrip != null &&
          extrudingOpeningGrip!.edgeIndex == grip.edgeIndex &&
          (extrudingOpeningGrip!.midpoint - grip.midpoint).distance < 1e-4) {
        continue;
      }
      final sceneMid = cadToScene(grip.midpoint);
      canvas.drawCircle(sceneMid, radius, gripFill);
      canvas.drawCircle(sceneMid, radius, gripBorder);
    }
  }

  void _drawOpeningExtrusionPreview(Canvas canvas, SlabEdgeGripInfo grip, double d) {
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

    final extrudePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 / zoomScale;

    // Draw stepped extruded edge lines
    canvas.drawLine(sV1, sNew1, extrudePaint);
    canvas.drawLine(sNew1, sNew2, extrudePaint);
    canvas.drawLine(sNew2, sV2, extrudePaint);

    // Draw displacement vector arrow
    final arrowPaint = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawLine(cadToScene(grip.midpoint), sMidNew, arrowPaint);

    final midHandleFill = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    final midHandleBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;
    canvas.drawCircle(sMidNew, 5.0 / zoomScale, midHandleFill);
    canvas.drawCircle(sMidNew, 5.0 / zoomScale, midHandleBorder);

    // Distance badge text
    canvas.save();
    canvas.translate(sMidNew.dx, sMidNew.dy);
    canvas.scale(1.0 / zoomScale);

    final distText = '${d.abs().toStringAsFixed(2)} m';
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
    textPainter.paint(canvas, badgeOffset);
    canvas.restore();
  }

  void _drawStaircaseTreads(Canvas canvas, List<Offset> opPts, Paint borderPaint) {
    if (opPts.length < 4) return;
    final treadPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.65)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    final d1 = (opPts[1] - opPts[0]).distance;
    final d2 = (opPts[3] - opPts[0]).distance;

    final Offset pA0, pA1, pB0, pB1;
    if (d2 >= d1) {
      pA0 = opPts[0];
      pA1 = opPts[3];
      pB0 = opPts[1];
      pB1 = opPts[2];
    } else {
      pA0 = opPts[0];
      pA1 = opPts[1];
      pB0 = opPts[3];
      pB1 = opPts[2];
    }

    const int numTreads = 9;
    for (int i = 1; i < numTreads; i++) {
      final t = i / numTreads;
      final ptA = Offset.lerp(pA0, pA1, t)!;
      final ptB = Offset.lerp(pB0, pB1, t)!;
      canvas.drawLine(ptA, ptB, treadPaint);
    }

    final startMid = Offset.lerp(pA0, pB0, 0.5)!;
    final endMid = Offset.lerp(pA1, pB1, 0.5)!;
    final arrowStart = Offset.lerp(startMid, endMid, 0.2)!;
    final arrowEnd = Offset.lerp(startMid, endMid, 0.8)!;
    final arrowDir = arrowEnd - arrowStart;
    final arrowLen = arrowDir.distance;
    if (arrowLen > 10.0 / zoomScale) {
      final u = arrowDir / arrowLen;
      final normal = Offset(-u.dy, u.dx);
      final arrowPaint = Paint()
        ..color = borderPaint.color
        ..strokeWidth = 1.5 / zoomScale
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(arrowStart, 2.5 / zoomScale, Paint()..color = borderPaint.color);
      canvas.drawLine(arrowStart, arrowEnd, arrowPaint);
      final headLen = 6.0 / zoomScale;
      final headWidth = 3.5 / zoomScale;
      final headLeft = arrowEnd - u * headLen + normal * headWidth;
      final headRight = arrowEnd - u * headLen - normal * headWidth;
      canvas.drawLine(arrowEnd, headLeft, arrowPaint);
      canvas.drawLine(arrowEnd, headRight, arrowPaint);
    }
  }

  void _drawElevatorCabin(Canvas canvas, List<Offset> opPts, Paint borderPaint) {
    if (opPts.length < 4) return;
    double cx = 0, cy = 0;
    for (final p in opPts) {
      cx += p.dx;
      cy += p.dy;
    }
    final center = Offset(cx / opPts.length, cy / opPts.length);

    final cabinPts = opPts.map((p) => Offset.lerp(p, center, 0.3)!).toList();
    final cabinPath = Path()..moveTo(cabinPts[0].dx, cabinPts[0].dy);
    for (int i = 1; i < cabinPts.length; i++) {
      cabinPath.lineTo(cabinPts[i].dx, cabinPts[i].dy);
    }
    cabinPath.close();

    final cabinFill = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final cabinStroke = Paint()
      ..color = borderPaint.color
      ..strokeWidth = 1.4 / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.drawPath(cabinPath, cabinFill);
    canvas.drawPath(cabinPath, cabinStroke);

    final tp = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          color: borderPaint.color,
          fontSize: (12.0 / zoomScale).clamp(8.0, 24.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2.0, tp.height / 2.0));
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

  Map<(String,bool),Offset> _gridAxisBubbleCenters() {
    final result=<(String,bool),Offset>{}, occupied=<Rect>[];
    for(final axis in currentStorey.gridAxes) {
      final style=GridAxisPresentation.forStorey(axis,currentStorey,gridAxisStoreys);
      final label=TextPainter(text:TextSpan(text:axis.name,style:const TextStyle(
        fontSize:11,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();
      final radius=math.max(8.0,math.max(label.width,label.height)/2+1.8);
      final levels=TextPainter(text:TextSpan(text:style.reference ? style.levels : '',
        style:const TextStyle(fontSize:9)),textDirection:TextDirection.ltr)..layout();
      final width=math.max(radius,levels.width/2)+3;
      final bottom=radius+(style.reference && style.levels.isNotEmpty ? levels.height+3 : 0)+3;
      final start=cadToScene(axis.start), end=cadToScene(axis.end), v=end-start;
      if (v.distance<=0) continue;
      for(final atStart in [if(axis.bubbleAtStart) true,if(axis.bubbleAtEnd) false]) {
        final base=atStart ? start : end, direction=(atStart ? -v : v)/v.distance;
        var center=base;
        for(var step=0;step<24;step++) {
          final rect=Rect.fromLTRB(center.dx-width/zoomScale,center.dy-(radius+3)/zoomScale,
            center.dx+width/zoomScale,center.dy+bottom/zoomScale);
          if (!occupied.any((r)=>r.overlaps(rect)) || step==23) {
            occupied.add(rect);break;
          }
          center=base+direction*((step+1)*24/zoomScale);
        }
        result[(axis.id,atStart)]=center;
      }
    }
    return result;
  }

  void _drawGridAxis(Canvas canvas, StructuralGridAxis axis, {required bool isGhost, bool isPreview = false, Map<(String,bool),Offset>? bubbleCenters}) {
    final p1 = cadToScene(axis.start);
    final p2 = cadToScene(axis.end);
    final isSelected = !isGhost && !isPreview && (axis.id == selectedGridAxisId);

    final presentation=GridAxisPresentation.forStorey(axis,currentStorey,gridAxisStoreys);
    final reference=!isGhost && !isPreview && presentation.reference;
    final color=isSelected ? const Color(0xFFFF9F0A) : presentation.color;
    final axisPaint = Paint()
      ..color = isGhost
          ? const Color(0x66FF453A)
          : isPreview
              ? const Color(0xFF00E5FF)
              : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isSelected || isPreview ? 2.5 : reference ? 1.0 : 1.5) / zoomScale;

    _drawDashDotLine(canvas, p1, p2, axisPaint);

    final endBubble=bubbleCenters?[(axis.id,false)] ?? p2;
    final startBubble=bubbleCenters?[(axis.id,true)] ?? p1;
    if (endBubble!=p2) _drawDashDotLine(canvas,p2,endBubble,axisPaint);
    if (startBubble!=p1) _drawDashDotLine(canvas,p1,startBubble,axisPaint);
    if (axis.bubbleAtEnd) {
      _drawAxisBubble(canvas, endBubble, axis.direction, axis.name, isSelected: isSelected || isPreview, isGhost: isGhost, axisColor: reference ? color : null, levels: reference ? presentation.levels : null);
    }
    if (axis.bubbleAtStart) {
      _drawAxisBubble(canvas, startBubble, -axis.direction, axis.name, isSelected: isSelected || isPreview, isGhost: isGhost, axisColor: reference ? color : null, levels: reference ? presentation.levels : null);
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
    Color? axisColor,
    String? levels,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0 / zoomScale);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: axisColor != null && !isSelected ? axisColor.withValues(alpha:.8) : isGhost ? const Color(0xAAFFFFFF) : Colors.white,
        fontSize: 11.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textMaxDim = math.max(textPainter.width, textPainter.height);
    final radius = math.max(8.0, textMaxDim / 2.0 + 1.8);

    final bgPaint = Paint()
      ..color = isGhost ? const Color(0xCC2C2C2E) : const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0x66FF453A)
          : (isSelected ? const Color(0xFFFF9F0A) : axisColor ?? const Color(0xFFFF453A))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : axisColor != null ? 1.0 : 1.4;

    canvas.drawCircle(Offset.zero, radius, bgPaint);
    canvas.drawCircle(Offset.zero, radius, borderPaint);

    final textOffset = Offset(
      -textPainter.width / 2.0,
      -textPainter.height / 2.0,
    );
    textPainter.paint(canvas, textOffset);
    if (levels!=null && levels.isNotEmpty) {
      final source=TextPainter(text:TextSpan(text:levels,style:TextStyle(
        fontSize:9,color:(axisColor ?? Colors.white70).withValues(alpha:.6))),textDirection:TextDirection.ltr)..layout();
      source.paint(canvas,Offset(-source.width/2,radius+3));
    }
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

    final storeyCheck = seismicReport?.storeyChecks
        .where((s) => s.storeyId == currentStorey.id).firstOrNull;
    final warning = !isGhost && !isPreview && !isMoving &&
        ((storeyCheck?.discontinuousWallIds.contains(wall.id) ?? false) ||
         (storeyCheck?.disconnectedWallIds.contains(wall.id) ?? false));
    final activeFill = warning ? const Color(0xFF9C27B0) : const Color(0xFF00897B);
    final activeAccent = warning ? const Color(0xFFEA80FC) : const Color(0xFF26D6BD);
    final fillPaint = Paint()
      ..color = isMoving
          ? const Color(0x26FFB300)
          : isPreview ? const Color(0xB300E5FF)
          : (isGhost ? const Color(0x4D78909C) : activeFill)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isPreview || isMoving
          ? const Color(0xFF00E5FF)
          : (isGhost ? const Color(0x8090A4AE) : activeAccent)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (isPreview || isMoving ? 2.5 : 1.8) / zoomScale;

    if (!isGhost && !isPreview && !isMoving) {
      final start = (pts[0] + pts[3]) / 2, end = (pts[1] + pts[2]) / 2;
      final width = (pts[0] - pts[3]).distance * zoomScale;
      canvas.drawPath(path, Paint()..color = const Color(0xEE0B1320)
          ..style = PaintingStyle.stroke..strokeWidth = 4.5 / zoomScale);
      if (width < 6) {
        canvas.drawLine(start, end, Paint()..color = const Color(0xEE0B1320)
            ..strokeWidth = 10 / zoomScale..strokeCap = StrokeCap.square);
        canvas.drawLine(start, end, Paint()..color = activeAccent
            ..strokeWidth = 6 / zoomScale..strokeCap = StrokeCap.square);
      }
    }
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Axial centerline of the shear wall (for beam connections and grid axis alignment)
    final centerLinePaint = Paint()
      ..color = isPreview || isMoving
          ? const Color(0xFF00E5FF)
          : (isGhost ? const Color(0x40FFFFFF) : activeAccent)
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
    final symbol = isGhost || isPreview ? pts :
        StructuralOverviewLayout.columnSymbol(pts, minimumSize: 12 / zoomScale);
    final path = Path()..moveTo(symbol[0].dx, symbol[0].dy);
    for (int i = 1; i < symbol.length; i++) {
      path.lineTo(symbol[i].dx, symbol[i].dy);
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

    final isDisconnected = !isGhost && !isPreview && !isMovingThis &&
        (seismicReport?.storeyChecks.where((s) => s.storeyId == currentStorey.id)
            .firstOrNull?.disconnectedColumnIds.contains(col.id) ?? false);
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
    } else if (isDisconnected || (vCheck != null && vCheck.status == VerticalCapacityStatus.critical)) {
      // Glows RED for critical crushing or punching failure
      fillColor = const Color(0xEEB71C1C);
      borderColor = const Color(0xFFFF1744);
    } else if (vCheck != null && vCheck.status == VerticalCapacityStatus.warning) {
      // Glows ORANGE/AMBER for near-capacity columns
      fillColor = const Color(0xEEF57F17);
      borderColor = const Color(0xFFFFB300);
    } else {
      fillColor = const Color(0xFF2979FF);
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

    if (!isGhost && !isPreview) {
      canvas.drawPath(path, Paint()..color = const Color(0xEE0B1320)
        ..style = PaintingStyle.stroke..strokeWidth = 5 / zoomScale);
    }
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
    if (StructuralOverviewLayout.boundsOf(pts).longestSide * zoomScale >= 18) {
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
          ..color = const Color(0x26FFB300)
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
    } else if (activeTool == StructuralDrawTool.slabOpening) {
      if (openingPointsInProgress.isNotEmpty) {
        final Color opColor;
        switch (activeOpeningType) {
          case SlabOpeningType.staircase:
            opColor = const Color(0xFF00B0FF);
            break;
          case SlabOpeningType.elevator:
            opColor = const Color(0xFF7C4DFF);
            break;
          case SlabOpeningType.shaft:
          case SlabOpeningType.custom:
            opColor = const Color(0xFFFF9800);
            break;
        }

        final opBorderPaint = Paint()
          ..color = opColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        final pts = openingPointsInProgress.map(cadToScene).toList();
        for (int i = 0; i < pts.length - 1; i++) {
          canvas.drawLine(pts[i], pts[i + 1], opBorderPaint);
        }

        bool isCloseSnap = false;
        if (currentCursorCad != null) {
          final sCursor = cadToScene(currentCursorCad!);
          if (openingPointsInProgress.length >= 3 &&
              (currentCursorCad! - openingPointsInProgress.first).distance < math.min(12.0 / (cadScale * zoomScale), .10 * cadUnitsPerMeter)) {
            isCloseSnap = true;
            final closeLinePaint = Paint()
              ..color = const Color(0xFF00E676)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 / zoomScale;
            canvas.drawLine(pts.last, pts.first, closeLinePaint);
          } else {
            canvas.drawLine(pts.last, sCursor, opBorderPaint);
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
        if (openingPointsInProgress.length >= 3) {
          final ringPaint = Paint()
            ..color = isCloseSnap ? const Color(0xFF00E676) : opColor
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
      } else if (openingStartCornerCad != null && currentCursorCad != null) {
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

        final Color baseColor;
        switch (activeOpeningType) {
          case SlabOpeningType.staircase:
            baseColor = const Color(0xFF00B0FF);
            break;
          case SlabOpeningType.elevator:
            baseColor = const Color(0xFF7C4DFF);
            break;
          case SlabOpeningType.shaft:
          case SlabOpeningType.custom:
            baseColor = const Color(0xFFFF9800);
            break;
        }

        final opFill = Paint()
          ..color = baseColor.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill;
        final opBorder = Paint()
          ..color = baseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / zoomScale;

        canvas.drawPath(path, opFill);
        canvas.drawPath(path, opBorder);

        if (activeOpeningType == SlabOpeningType.staircase) {
          _drawStaircaseTreads(canvas, [p1, p2, p3, p4], opBorder);
        } else if (activeOpeningType == SlabOpeningType.elevator) {
          canvas.drawLine(p1, p3, opBorder);
          canvas.drawLine(p2, p4, opBorder);
          _drawElevatorCabin(canvas, [p1, p2, p3, p4], opBorder);
        } else {
          // Architectural X cross
          canvas.drawLine(p1, p3, opBorder);
          canvas.drawLine(p2, p4, opBorder);
        }
      }
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

      final s = cadToScene(zone.supportEdgeStart);
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
      final badgeColor = check.isTorsionallySensitive
          ? const Color(0xFFFF1744)
          : (check.hasSignificantEccentricity
              ? const Color(0xFFFFB300)
              : const Color(0xFFD500F9));

      final linePaint = Paint()
        ..color = badgeColor
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
        ..color = badgeColor
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
