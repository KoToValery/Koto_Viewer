import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import 'architect_canvas_palette.dart';

/// Architectural room stamps, zone fills, schedules, and drafting previews.
/// Manual contour handles are rendered by the shared polygon painter.
class ArchitectZonePainterHelper {
  /// Draws the room schedule table or ghost preview.
  static void drawZoneSchedule({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    bool isTableSelected = false,
    Offset? tableDragPreviewOrigin,
    Offset? tableGhostOrigin,
    AppLocalizations? l10n,
  }) {
    final effectiveTableOrigin =
        tableDragPreviewOrigin ?? storey.zoneScheduleOrigin;
    if (effectiveTableOrigin != null && storey.zones.isNotEmpty) {
      drawZoneScheduleTable(
        canvas: canvas,
        storey: storey,
        origin: effectiveTableOrigin,
        zoomScale: zoomScale,
        palette: palette,
        isSelected: isTableSelected,
        l10n: l10n,
      );
    } else if (tableGhostOrigin != null) {
      drawZoneTableGhostPreview(
        canvas: canvas,
        origin: tableGhostOrigin,
        zoomScale: zoomScale,
        zoneCount: storey.zones.length,
        l10n: l10n,
      );
    }
  }

  /// Renders all functional zones for the active storey.
  static void drawZones({
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Canvas canvas,
    required ArchitectProject project,
    required double zoomScale,
    String? selectedZoneId,
    int? draggingVertexIndex,
    Offset? draggingVertexPoint,
    int? mergeCandidateIndex,
    List<Offset>? extrudePreviewPolygon,
    bool isExtrudeSelfIntersecting = false,
    List<Offset>? editingPolygon,
  }) {
    final activeStorey = project.activeStorey;
    if (activeStorey.zones.isEmpty) return;

    for (final zone in activeStorey.zones) {
      final isSelected = zone.id == selectedZoneId;
      _drawSingleZone(
        palette: palette,
        canvas: canvas,
        zone: zone,
        isSelected: isSelected,
        zoomScale: zoomScale,
        draggingVertexIndex: isSelected ? draggingVertexIndex : null,
        draggingVertexPoint: isSelected ? draggingVertexPoint : null,
        mergeCandidateIndex: isSelected ? mergeCandidateIndex : null,
        extrudePreviewPolygon: isSelected ? extrudePreviewPolygon : null,
        isExtrudeSelfIntersecting: isSelected
            ? isExtrudeSelfIntersecting
            : false,
        editingPolygon: isSelected ? editingPolygon : null,
      );
    }
  }

  static void _drawSingleZone({
    required ArchitectCanvasPalette palette,
    required Canvas canvas,
    required ArchitectZone zone,
    required bool isSelected,
    required double zoomScale,
    int? draggingVertexIndex,
    Offset? draggingVertexPoint,
    int? mergeCandidateIndex,
    List<Offset>? extrudePreviewPolygon,
    bool isExtrudeSelfIntersecting = false,
    List<Offset>? editingPolygon,
  }) {
    final poly = extrudePreviewPolygon != null
        ? List<Offset>.from(extrudePreviewPolygon)
        : (isSelected && editingPolygon != null
              ? List<Offset>.from(editingPolygon)
              : List<Offset>.from(zone.polygon));
    if (poly.length < 3) return;

    // If a vertex is currently being dragged, substitute its position for live preview
    if (draggingVertexIndex != null &&
        draggingVertexPoint != null &&
        draggingVertexIndex >= 0 &&
        draggingVertexIndex < poly.length) {
      poly[draggingVertexIndex] = draggingVertexPoint;
    }

    final path = Path()..moveTo(poly.first.dx, poly.first.dy);
    for (int i = 1; i < poly.length; i++) {
      path.lineTo(poly[i].dx, poly[i].dy);
    }
    path.close();

    // 1. Pastel architectural fill
    final fillPaint = Paint()
      ..color = zone.color.withValues(alpha: isSelected ? 0.28 : 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Zone border
    final borderColor = isExtrudeSelfIntersecting
        ? const Color(0xFFFF5252)
        : (isSelected
              ? const Color(0xFF00E5FF)
              : palette.foreground(zone.color).withValues(alpha: 0.85));
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = (isSelected ? 2.2 : 1.2) / math.max(zoomScale, 80.0)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // Keep the stamp and its area attached to the live contour preview.
    final stampZone = zone.copyWith(polygon: poly);
    _drawRoomStamp(
      canvas: canvas,
      zone: stampZone,
      centroid: stampZone.centroid,
      zoomScale: zoomScale,
      isSelected: isSelected,
    );
  }

  /// Draws the compact architectural room badge with sequence number, name, and area.
  static void _drawRoomStamp({
    required Canvas canvas,
    required ArchitectZone zone,
    required Offset centroid,
    required double zoomScale,
    required bool isSelected,
  }) {
    canvas.save();
    canvas.translate(centroid.dx, centroid.dy);
    // Fixed model-space lettering: zooming out reduces the stamp with the plan.
    canvas.scale(1.0 / 80.0);

    final numberText = '№ ${zone.number.isNotEmpty ? zone.number : '1'}';
    final nameText = zone.name;
    final areaText = '${zone.area.toStringAsFixed(2)} m²';

    final numberSpan = TextSpan(
      text: '$numberText\n',
      style: TextStyle(
        color: zone.color,
        fontFamily: 'Roboto',
        fontSize: 10.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    );
    final nameSpan = TextSpan(
      text: '$nameText\n',
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Roboto',
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
      ),
    );
    final areaSpan = TextSpan(
      text: areaText,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontFamily: 'Roboto',
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final tp = TextPainter(
      text: TextSpan(children: [numberSpan, nameSpan, areaSpan]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    const badgePaddingH = 8.0;
    const badgePaddingV = 5.0;
    final badgeRect = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + badgePaddingH * 2,
      height: tp.height + badgePaddingV * 2,
    );

    final bgPaint = Paint()
      ..color = const Color(0xEE161822)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = (isSelected ? const Color(0xFF00E5FF) : zone.color).withValues(
        alpha: isSelected ? 0.95 : 0.65,
      )
      ..strokeWidth = isSelected ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6.0)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6.0)),
      borderPaint,
    );

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static void _drawEdgeDimension(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double length,
    double zoomScale,
  ) {
    final mid = (p1 + p2) / 2.0;
    final delta = p2 - p1;
    final u = delta / delta.distance;
    final n = Offset(-u.dy, u.dx) * (0.22); // slight offset from edge

    final tp = TextPainter(
      text: TextSpan(
        text: '${length.toStringAsFixed(2)} m',
        style: TextStyle(
          color: const Color(0xFFEEEEEE),
          fontFamily: 'Roboto',
          fontSize: 8.5 / zoomScale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = mid + n;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 4.0 / zoomScale,
      height: tp.height + 2.0 / zoomScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(2.5 / zoomScale)),
      Paint()..color = const Color(0xCC212121),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Renders the rubber-band interactive drag preview when drawing a new zone.
  static void drawActiveZoneDrag({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required ArchitectZoneCategory category,
    String? categoryName,
    required double zoomScale,
  }) {
    final rect = Rect.fromPoints(start, end);
    final w = rect.width.abs();
    final h = rect.height.abs();
    final area = w * h;

    final fillPaint = Paint()
      ..color = category.color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = category.color
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, borderPaint);

    // Live dimensions badge in center
    final catName = categoryName ?? '';
    final label =
        '$catName\n${w.toStringAsFixed(2)} × ${h.toStringAsFixed(2)} m\n${area.toStringAsFixed(1)} m²';

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 10.5 / zoomScale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final center = rect.center;
    final badgeRect = Rect.fromCenter(
      center: center,
      width: tp.width + 12.0 / zoomScale,
      height: tp.height + 8.0 / zoomScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(6.0 / zoomScale)),
      Paint()..color = const Color(0xE61A1C24),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(6.0 / zoomScale)),
      Paint()
        ..color = category.color
        ..strokeWidth = 1.2 / zoomScale
        ..style = PaintingStyle.stroke,
    );

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Draws magnetic dashed alignment guide lines.
  static void drawMagneticGuides({
    required Canvas canvas,
    required List<(Offset, Offset)> guides,
    required double zoomScale,
  }) {
    if (guides.isEmpty) return;

    final guidePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final (p1, p2) in guides) {
      _drawDashedLine(canvas, p1, p2, guidePaint, zoomScale);
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double zoomScale,
  ) {
    final d = p2 - p1;
    final totalLen = d.distance;
    if (totalLen < 1e-4) return;

    final u = d / totalLen;
    final dashLen = 6.0 / zoomScale;
    final gapLen = 4.0 / zoomScale;
    double current = 0.0;

    while (current < totalLen) {
      final start = p1 + u * current;
      final next = math.min(current + dashLen, totalLen);
      final end = p1 + u * next;
      canvas.drawLine(start, end, paint);
      current += dashLen + gapLen;
    }
  }

  /// Renders point-by-point zone drafting session with orthogonal straightening guides,
  /// vertex nodes, live dimensions, and first-point closing snap targets.
  static void drawPointByPointDrafting({
    required Canvas canvas,
    required List<Offset> points,
    required Offset? candidatePoint,
    required ArchitectZoneCategory category,
    required double zoomScale,
    (Offset, Offset)? orthoGuide,
    String? orthoLabel,
    bool isClosingSnap = false,
    bool isSelfIntersecting = false,
    String? closeLabel,
    List<Offset> previewRectangle = const [],
  }) {
    if (points.isEmpty) return;

    // 0. Quick rectangle mode preview
    if (previewRectangle.length == 4) {
      final rectPath = Path()
        ..moveTo(previewRectangle[0].dx, previewRectangle[0].dy);
      for (int i = 1; i < 4; i++) {
        rectPath.lineTo(previewRectangle[i].dx, previewRectangle[i].dy);
      }
      rectPath.close();

      canvas.drawPath(
        rectPath,
        Paint()
          ..color = category.color.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        rectPath,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.0 / zoomScale
          ..style = PaintingStyle.stroke,
      );
      for (int i = 0; i < 4; i++) {
        final p1 = previewRectangle[i];
        final p2 = previewRectangle[(i + 1) % 4];
        final len = (p2 - p1).distance;
        if (len > 0.3) {
          _drawEdgeDimension(canvas, p1, p2, len, zoomScale);
        }
      }
    }

    final candidate = candidatePoint;
    final allPoints = candidate != null ? [...points, candidate] : points;

    // 1. Polygon Fill preview if >= 3 points
    if (allPoints.length >= 3 && previewRectangle.isEmpty) {
      final fillPath = Path()..moveTo(allPoints.first.dx, allPoints.first.dy);
      for (int i = 1; i < allPoints.length; i++) {
        fillPath.lineTo(allPoints[i].dx, allPoints[i].dy);
      }
      fillPath.close();

      final fillPaint = Paint()
        ..color =
            (isSelfIntersecting ? const Color(0xFFFF5252) : category.color)
                .withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // 2. Committed segments
    final strokeColor = isSelfIntersecting
        ? const Color(0xFFFF5252)
        : (isClosingSnap ? const Color(0xFF00E676) : const Color(0xFF00E5FF));

    final committedPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.9)
      ..strokeWidth = 2.0 / zoomScale
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], committedPaint);
      final edgeLen = (points[i + 1] - points[i]).distance;
      if (edgeLen > 0.6) {
        _drawEdgeDimension(
          canvas,
          points[i],
          points[i + 1],
          edgeLen,
          zoomScale,
        );
      }
    }

    // 3. Active rubber-band segment from last committed point to candidate
    if (candidate != null && points.isNotEmpty && previewRectangle.isEmpty) {
      final lastPt = points.last;
      final rubberPaint = Paint()
        ..color = strokeColor
        ..strokeWidth = 1.8 / zoomScale
        ..style = PaintingStyle.stroke;

      _drawDashedLine(canvas, lastPt, candidate, rubberPaint, zoomScale);

      // Dimension & angle badge for the active rubberband segment
      final segLen = (candidate - lastPt).distance;
      if (segLen > 0.25) {
        _drawSegmentDimensionAndAngle(
          canvas: canvas,
          p1: lastPt,
          p2: candidate,
          length: segLen,
          orthoLabel: orthoLabel,
          zoomScale: zoomScale,
        );
      }
    }

    // 4. Extended orthogonal straightening guide line
    if (orthoGuide != null && previewRectangle.isEmpty) {
      final orthoPaint = Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: 0.85)
        ..strokeWidth = 1.2 / zoomScale
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        orthoGuide.$1,
        orthoGuide.$2,
        orthoPaint,
        zoomScale,
      );
    }

    // 5. Committed vertex nodes (Numbered 1..N GPS_Mapping style)
    final draftingScale = math.max(zoomScale, 80.0);
    final nodeRadius = 13.0 / draftingScale;
    final nodeShadow = Paint()..color = Colors.black54;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isStartNode = (i == 0);

      if (isStartNode) {
        // --- POINT 1: SPECIAL START BEACON & CLOSING TARGET ---
        final beaconRadius = (isClosingSnap ? 24.0 : 20.0) / draftingScale;
        final beaconColor = isClosingSnap
            ? const Color(0xFF00E676)
            : const Color(0xFF00E5FF);

        // Pulsing radar glow aura
        canvas.drawCircle(
          pt,
          beaconRadius,
          Paint()
            ..color = beaconColor.withValues(alpha: isClosingSnap ? 0.35 : 0.20)
            ..style = PaintingStyle.fill,
        );

        // Outer beacon ring
        canvas.drawCircle(
          pt,
          beaconRadius,
          Paint()
            ..color = beaconColor
            ..strokeWidth = (isClosingSnap ? 2.5 : 1.8) / draftingScale
            ..style = PaintingStyle.stroke,
        );

        // Inner radar guide ring
        canvas.drawCircle(
          pt,
          beaconRadius * 0.72,
          Paint()
            ..color = beaconColor.withValues(alpha: 0.5)
            ..strokeWidth = 1.0 / draftingScale
            ..style = PaintingStyle.stroke,
        );

        // Drop shadow for core node
        canvas.drawCircle(pt, nodeRadius + 1.5 / draftingScale, nodeShadow);

        // Start core circle (solid high-contrast neon)
        canvas.drawCircle(
          pt,
          nodeRadius,
          Paint()
            ..color = beaconColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pt,
          nodeRadius,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.4 / draftingScale
            ..style = PaintingStyle.stroke,
        );

        // Bold black numeral '1'
        final tp1 = TextPainter(
          text: TextSpan(
            text: '1',
            style: TextStyle(
              color: Colors.black87,
              fontFamily: 'Roboto',
              fontSize: 12.0 / draftingScale,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp1.paint(canvas, pt - Offset(tp1.width / 2, tp1.height / 2));

        // When points.length == 1: show immediate helper badge under Point 1
        if (points.length == 1) {
          final tpLabel = TextPainter(
            text: TextSpan(
              text: '1',
              style: TextStyle(
                color: const Color(0xFF00E5FF),
                fontFamily: 'Roboto',
                fontSize: 9.5 / draftingScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final labelPos =
              pt +
              Offset(-tpLabel.width / 2, beaconRadius + 4.0 / draftingScale);
          final labelRect = Rect.fromLTWH(
            labelPos.dx - 6.0 / draftingScale,
            labelPos.dy - 3.0 / draftingScale,
            tpLabel.width + 12.0 / draftingScale,
            tpLabel.height + 6.0 / draftingScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              labelRect,
              Radius.circular(5.0 / draftingScale),
            ),
            Paint()..color = const Color(0xEE1A1C24),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              labelRect,
              Radius.circular(5.0 / draftingScale),
            ),
            Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 1.0 / draftingScale
              ..style = PaintingStyle.stroke,
          );
          tpLabel.paint(canvas, labelPos);
        }

        // When closing snap is active (3+ points hovering start):
        if (isClosingSnap &&
            points.length >= 3 &&
            closeLabel != null &&
            closeLabel.isNotEmpty) {
          final badgeText = closeLabel;
          final tpClose = TextPainter(
            text: TextSpan(
              text: badgeText,
              style: TextStyle(
                color: const Color(0xFF00E676),
                fontFamily: 'Roboto',
                fontSize: 10.5 / draftingScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final badgePos =
              pt -
              Offset(
                tpClose.width / 2,
                (beaconRadius + tpClose.height + 6.0 / draftingScale),
              );
          final badgeRect = Rect.fromLTWH(
            badgePos.dx - 7.0 / draftingScale,
            badgePos.dy - 4.0 / draftingScale,
            tpClose.width + 14.0 / draftingScale,
            tpClose.height + 8.0 / draftingScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              badgeRect,
              Radius.circular(6.0 / draftingScale),
            ),
            Paint()..color = const Color(0xF2161822),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              badgeRect,
              Radius.circular(6.0 / draftingScale),
            ),
            Paint()
              ..color = const Color(0xFF00E676)
              ..strokeWidth = 1.5 / draftingScale
              ..style = PaintingStyle.stroke,
          );
          tpClose.paint(canvas, badgePos);
        }
      } else {
        // --- SUBSEQUENT POINTS 2..N: HIGH CONTRAST BADGES ---
        canvas.drawCircle(pt, nodeRadius + 1.5 / draftingScale, nodeShadow);

        canvas.drawCircle(
          pt,
          nodeRadius,
          Paint()
            ..color = category.color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pt,
          nodeRadius,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.0 / draftingScale
            ..style = PaintingStyle.stroke,
        );

        final tpN = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontSize: 11.0 / draftingScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpN.paint(canvas, pt - Offset(tpN.width / 2, tpN.height / 2));
      }
    }
  }

  static void _drawSegmentDimensionAndAngle({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required double length,
    String? orthoLabel,
    required double zoomScale,
  }) {
    final mid = (p1 + p2) / 2.0;
    final delta = p2 - p1;
    final u = delta / delta.distance;
    final n = Offset(-u.dy, u.dx) * (0.35); // offset normal

    final text = orthoLabel != null
        ? '${length.toStringAsFixed(2)} m  ($orthoLabel)'
        : '${length.toStringAsFixed(2)} m';

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 9.5 / zoomScale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = mid + n;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 6.0 / zoomScale,
      height: tp.height + 4.0 / zoomScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4.0 / zoomScale)),
      Paint()..color = const Color(0xEE1E1E28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4.0 / zoomScale)),
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
        ..strokeWidth = 0.8 / zoomScale
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Draws live interactive extrusion step preview when dragging edge midpoint.
  static void drawEdgeExtrudePreview({
    required Canvas canvas,
    required Offset v1,
    required Offset v2,
    required Offset normal,
    required double distance,
    required double zoomScale,
    required bool isSelfIntersecting,
  }) {
    final vNew1 = v1 + normal * distance;
    final vNew2 = v2 + normal * distance;
    final color = isSelfIntersecting
        ? const Color(0xFFFF5252)
        : const Color(0xFF00E5FF);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, v1, vNew1, linePaint, zoomScale);
    _drawDashedLine(canvas, vNew1, vNew2, linePaint, zoomScale);
    _drawDashedLine(canvas, vNew2, v2, linePaint, zoomScale);

    // Dimension badge
    final midExtruded = (vNew1 + vNew2) / 2.0;
    final distText =
        '${distance >= 0 ? "+" : ""}${distance.toStringAsFixed(2)} m';
    final tp = TextPainter(
      text: TextSpan(
        text: distText,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 9.5 / zoomScale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = midExtruded + normal * (0.25 * (distance >= 0 ? 1 : -1));
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 6.0 / zoomScale,
      height: tp.height + 4.0 / zoomScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4.0 / zoomScale)),
      Paint()..color = const Color(0xEE1E1E28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4.0 / zoomScale)),
      Paint()
        ..color = color
        ..strokeWidth = 1.0 / zoomScale
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // ===========================================================================
  // SECTION: COMPACT ZONE FINISH SCHEDULE TABLE
  // ===========================================================================

  static const double zoneTableTotalWidth = 590.0;
  static const double zoneTableTitleHeight = 28.0;
  static const double zoneTableHeaderHeight = 24.0;
  static const double zoneTableRowHeight = 22.0;
  static const double zoneTableFooterHeight = 24.0;

  static const List<double> zoneTableColWidths = [
    36.0, // №
    135.0, // Наименование
    80.0, // Квадратура (m²)
    115.0, // Настилка под
    114.0, // Стени
    110.0, // Таван
  ];

  static double getZoneTableTotalHeight(int zoneCount) {
    final rowCount = zoneCount > 0 ? zoneCount : 1;
    return zoneTableTitleHeight +
        zoneTableHeaderHeight +
        (rowCount * zoneTableRowHeight) +
        zoneTableFooterHeight;
  }

  /// Calculates the bounding rectangle of the table in model coordinates (meters).
  static Rect getZoneTableBounds({
    required ArchitectStorey storey,
    required Offset origin,
    required double zoomScale,
  }) {
    final totalHeight = getZoneTableTotalHeight(storey.zones.length);
    final widthModel = zoneTableTotalWidth / zoomScale;
    final heightModel = totalHeight / zoomScale;
    return Rect.fromLTWH(origin.dx, origin.dy, widthModel, heightModel);
  }

  /// Renders a publication-ready compact architectural room finish schedule table
  /// directly on the 2D drawing canvas at [origin].
  static void drawZoneScheduleTable({
    required Canvas canvas,
    required ArchitectStorey storey,
    required Offset origin,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool isSelected = false,
    AppLocalizations? l10n,
  }) {
    final zones = storey.zones;
    if (zones.isEmpty) return;

    final sortedZones = List<ArchitectZone>.from(zones)
      ..sort((a, b) => a.number.compareTo(b.number));

    final totalWidth = zoneTableTotalWidth;
    final totalHeight = getZoneTableTotalHeight(sortedZones.length);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(1.0 / zoomScale);

    final tableRect = Rect.fromLTWH(0, 0, totalWidth, totalHeight);

    // 1. Table Background & Outer Border
    final bgPaint = Paint()
      ..color = const Color(0xF7131622)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..strokeWidth = isSelected ? 2.0 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      borderPaint,
    );

    if (isSelected) {
      final glowPaint = Paint()
        ..color = const Color(0x3300E5FF)
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(tableRect.inflate(2), const Radius.circular(8)),
        glowPaint,
      );
    }

    final gridLinePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 2. Title Header
    final titlePaint = Paint()
      ..color = const Color(0xFF0F2642)
      ..style = PaintingStyle.fill;
    final titleRect = Rect.fromLTWH(0, 0, totalWidth, zoneTableTitleHeight);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        titleRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      titlePaint,
    );
    canvas.drawLine(
      const Offset(0, zoneTableTitleHeight),
      Offset(totalWidth, zoneTableTitleHeight),
      borderPaint,
    );

    final titlePrefix =
        l10n?.architectZoneScheduleTitle ?? 'ТАБЛИЦА НА ПОМЕЩЕНИЯТА';
    final titleText =
        '${titlePrefix.toUpperCase()} — ${storey.name.toUpperCase()}';
    final titleTp = TextPainter(
      text: TextSpan(
        text: titleText,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Roboto',
          fontSize: 11.0,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: totalWidth - 16);
    titleTp.paint(
      canvas,
      Offset(
        (totalWidth - titleTp.width) / 2,
        (zoneTableTitleHeight - titleTp.height) / 2,
      ),
    );

    // 3. Column Headers
    final headerPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final headerRect = Rect.fromLTWH(
      0,
      zoneTableTitleHeight,
      totalWidth,
      zoneTableHeaderHeight,
    );
    canvas.drawRect(headerRect, headerPaint);
    canvas.drawLine(
      const Offset(0, zoneTableTitleHeight + zoneTableHeaderHeight),
      Offset(totalWidth, zoneTableTitleHeight + zoneTableHeaderHeight),
      borderPaint,
    );

    final headers = [
      l10n?.architectZoneScheduleColNo ?? '№',
      l10n?.architectZoneScheduleColName ?? 'Помещение',
      l10n?.architectZoneScheduleColArea ?? 'Квадратура',
      l10n?.architectZoneScheduleColFloor ?? 'Настилка под',
      l10n?.architectZoneScheduleColWalls ?? 'Стени',
      l10n?.architectZoneScheduleColCeiling ?? 'Таван',
    ];

    double curX = 0;
    for (int i = 0; i < headers.length; i++) {
      final w = zoneTableColWidths[i];
      final isCentered = i == 0;
      final colTp = TextPainter(
        text: TextSpan(
          text: headers[i],
          style: const TextStyle(
            color: Color(0xFF7DD3FC),
            fontFamily: 'Roboto',
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: isCentered ? TextAlign.center : TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 8);

      final tx = isCentered ? curX + (w - colTp.width) / 2 : curX + 6.0;
      colTp.paint(
        canvas,
        Offset(
          tx,
          zoneTableTitleHeight + (zoneTableHeaderHeight - colTp.height) / 2,
        ),
      );

      curX += w;
      if (i < headers.length - 1) {
        canvas.drawLine(
          Offset(curX, zoneTableTitleHeight),
          Offset(curX, totalHeight - zoneTableFooterHeight),
          gridLinePaint,
        );
      }
    }

    // 4. Room Rows
    double totalNetArea = 0.0;
    double curY = zoneTableTitleHeight + zoneTableHeaderHeight;

    for (int rowIdx = 0; rowIdx < sortedZones.length; rowIdx++) {
      final z = sortedZones[rowIdx];
      totalNetArea += z.area;

      // Alternating row background
      if (rowIdx % 2 == 1) {
        final rowRect = Rect.fromLTWH(0, curY, totalWidth, zoneTableRowHeight);
        canvas.drawRect(
          rowRect,
          Paint()..color = Colors.white.withValues(alpha: 0.03),
        );
      }

      // Horizontal separator line
      canvas.drawLine(
        Offset(0, curY + zoneTableRowHeight),
        Offset(totalWidth, curY + zoneTableRowHeight),
        gridLinePaint,
      );

      final rowValues = [
        z.number.isNotEmpty ? z.number : '${rowIdx + 1}',
        z.name,
        '${z.area.toStringAsFixed(2)} m²',
        z.floorFinish.isNotEmpty ? z.floorFinish : '—',
        z.wallFinish.isNotEmpty ? z.wallFinish : '—',
        z.ceilingFinish.isNotEmpty ? z.ceilingFinish : '—',
      ];

      double cellX = 0;
      for (int c = 0; c < rowValues.length; c++) {
        final w = zoneTableColWidths[c];
        final isCentered = c == 0;
        final isNumeric = c == 0 || c == 2;
        final cellTp = TextPainter(
          text: TextSpan(
            text: rowValues[c],
            style: TextStyle(
              color: c == 0 ? z.color : Colors.white.withValues(alpha: 0.9),
              fontFamily: 'Roboto',
              fontSize: 9.5,
              fontWeight: isNumeric ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: w - 8);

        final pX = isCentered ? cellX + (w - cellTp.width) / 2 : cellX + 6.0;
        cellTp.paint(
          canvas,
          Offset(pX, curY + (zoneTableRowHeight - cellTp.height) / 2),
        );
        cellX += w;
      }

      curY += zoneTableRowHeight;
    }

    // 5. Total Footer Row
    final footerRect = Rect.fromLTWH(
      0,
      curY,
      totalWidth,
      zoneTableFooterHeight,
    );
    final footerPaint = Paint()
      ..color = const Color(0xFF0F2642)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        footerRect,
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      footerPaint,
    );
    canvas.drawLine(Offset(0, curY), Offset(totalWidth, curY), borderPaint);

    final totalLabel =
        l10n?.architectZoneScheduleTotalArea.toUpperCase() ?? 'ОБЩО';
    final countLabel =
        l10n?.architectZoneScheduleRoomCount.toUpperCase() ?? 'БРОЙ';
    final footerTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$totalLabel: ',
            style: const TextStyle(
              color: Color(0xFF7DD3FC),
              fontFamily: 'Roboto',
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '${totalNetArea.toStringAsFixed(2)} m²',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontSize: 11.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: '   •   $countLabel: ${sortedZones.length}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'Roboto',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: totalWidth - 16);

    footerTp.paint(
      canvas,
      Offset(12.0, curY + (zoneTableFooterHeight - footerTp.height) / 2),
    );

    canvas.restore();
  }

  /// Draws a lightweight ghost placement preview following cursor when placing the table.
  static void drawZoneTableGhostPreview({
    required Canvas canvas,
    required Offset origin,
    required double zoomScale,
    required int zoneCount,
    AppLocalizations? l10n,
  }) {
    final totalWidth = zoneTableTotalWidth;
    final rowCount = zoneCount > 0 ? zoneCount : 2;
    final totalHeight = getZoneTableTotalHeight(rowCount);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(1.0 / zoomScale);

    final tableRect = Rect.fromLTWH(0, 0, totalWidth, totalHeight);

    // Translucent preview box
    final fillPaint = Paint()
      ..color = const Color(0x3300E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      fillPaint,
    );

    // Glowing cyan border
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(6)),
      borderPaint,
    );

    // Prompt inside
    final hint =
        l10n?.architectZoneTableBarHint ?? 'Кликнете за поставяне на таблицата';
    final hintTp = TextPainter(
      text: TextSpan(
        text: '📋 $hint',
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontFamily: 'Roboto',
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: totalWidth - 16);
    hintTp.paint(
      canvas,
      Offset(
        (totalWidth - hintTp.width) / 2,
        (totalHeight - hintTp.height) / 2,
      ),
    );

    canvas.restore();
  }
}
