import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';

/// Specialized rendering helper for architectural functional zones,
/// dynamic vertex handles, midpoint grips, and magnetic guide lines.
class ArchitectZonePainterHelper {
  /// Renders all functional zones for the active storey.
  static void drawZones({
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
    bool isMoveWholeZoneMode = false,
    double moveDistanceMeters = 0.0,
  }) {
    final activeStorey = project.activeStorey;
    if (activeStorey.zones.isEmpty) return;

    for (final zone in activeStorey.zones) {
      final isSelected = zone.id == selectedZoneId;
      _drawSingleZone(
        canvas: canvas,
        zone: zone,
        isSelected: isSelected,
        zoomScale: zoomScale,
        draggingVertexIndex: isSelected ? draggingVertexIndex : null,
        draggingVertexPoint: isSelected ? draggingVertexPoint : null,
        mergeCandidateIndex: isSelected ? mergeCandidateIndex : null,
        extrudePreviewPolygon: isSelected ? extrudePreviewPolygon : null,
        isExtrudeSelfIntersecting: isSelected ? isExtrudeSelfIntersecting : false,
        editingPolygon: isSelected ? editingPolygon : null,
        isMoveWholeZoneMode: isSelected ? isMoveWholeZoneMode : false,
        moveDistanceMeters: isSelected ? moveDistanceMeters : 0.0,
      );
    }
  }

  static void _drawSingleZone({
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
    bool isMoveWholeZoneMode = false,
    double moveDistanceMeters = 0.0,
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
        : (isSelected ? const Color(0xFF00E5FF) : zone.color.withValues(alpha: 0.85));
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = (isSelected ? 2.2 : 1.2) / zoomScale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // 3. Central room stamp badge (Име и Квадратура)
    _drawRoomStamp(
      canvas: canvas,
      zone: zone,
      centroid: zone.centroid,
      zoomScale: zoomScale,
      isSelected: isSelected,
    );

    // 4. Dynamic BiM-style handles if selected
    if (isSelected) {
      _drawDynamicHandles(
        canvas: canvas,
        polygon: poly,
        zoomScale: zoomScale,
        draggingVertexIndex: draggingVertexIndex,
        mergeCandidateIndex: mergeCandidateIndex,
      );
    }
  }

  /// Draws the centered room stamp with room name and net area.
  static void _drawRoomStamp({
    required Canvas canvas,
    required ArchitectZone zone,
    required Offset centroid,
    required double zoomScale,
    required bool isSelected,
  }) {
    final areaText = '${zone.area.toStringAsFixed(1)} m²';
    final nameText = zone.name;

    final nameSpan = TextSpan(
      text: nameText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 11.0 / zoomScale,
        fontWeight: FontWeight.bold,
      ),
    );
    final areaSpan = TextSpan(
      text: '\n$areaText',
      style: TextStyle(
        color: zone.color,
        fontSize: 10.0 / zoomScale,
        fontWeight: FontWeight.w600,
      ),
    );

    final tp = TextPainter(
      text: TextSpan(children: [nameSpan, areaSpan]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgePaddingH = 8.0 / zoomScale;
    final badgePaddingV = 4.0 / zoomScale;
    final badgeRect = Rect.fromCenter(
      center: centroid,
      width: tp.width + badgePaddingH * 2,
      height: tp.height + badgePaddingV * 2,
    );

    final bgPaint = Paint()
      ..color = const Color(0xDE1A1C24)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = (isSelected ? const Color(0xFF00E5FF) : zone.color)
          .withValues(alpha: 0.6)
      ..strokeWidth = 1.0 / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(5.0 / zoomScale)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, Radius.circular(5.0 / zoomScale)),
      borderPaint,
    );

    tp.paint(
      canvas,
      centroid - Offset(tp.width / 2, tp.height / 2),
    );
  }

  /// Draws dynamic vertex handles and edge midpoint grips.
  static void _drawDynamicHandles({
    required Canvas canvas,
    required List<Offset> polygon,
    required double zoomScale,
    int? draggingVertexIndex,
    int? mergeCandidateIndex,
  }) {
    final vertexRadius = 12.0 / zoomScale;
    final midpointRadius = 7.5 / zoomScale;

    // Edge midpoint grips
    final midFill = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    final midBorder = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < polygon.length; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % polygon.length];
      final mid = (p1 + p2) / 2.0;

      // Draw diamond for edge midpoint
      final dPath = Path()
        ..moveTo(mid.dx, mid.dy - midpointRadius)
        ..lineTo(mid.dx + midpointRadius, mid.dy)
        ..lineTo(mid.dx, mid.dy + midpointRadius)
        ..lineTo(mid.dx - midpointRadius, mid.dy)
        ..close();

      canvas.drawPath(dPath, midFill);
      canvas.drawPath(dPath, midBorder);

      // Dimension of this edge
      final edgeLen = (p2 - p1).distance;
      if (edgeLen > 0.8) {
        _drawEdgeDimension(canvas, p1, p2, edgeLen, zoomScale);
      }
    }

    // Vertex pins (GPS_Mapping style prominent nodes)
    final vFill = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final vBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0 / zoomScale
      ..style = PaintingStyle.stroke;

    final mergeFill = Paint()
      ..color = const Color(0xFFFF3D00) // Red pulse for merge candidate
      ..style = PaintingStyle.fill;

    for (int i = 0; i < polygon.length; i++) {
      final v = polygon[i];
      final isMergeCandidate = (i == mergeCandidateIndex);
      final isDragging = (i == draggingVertexIndex);

      // Drop shadow
      canvas.drawCircle(
        v,
        (isMergeCandidate || isDragging ? vertexRadius * 1.4 : vertexRadius) + 1.5 / zoomScale,
        Paint()..color = Colors.black45,
      );

      if (isMergeCandidate) {
        canvas.drawCircle(v, vertexRadius * 1.5, mergeFill);
        canvas.drawCircle(v, vertexRadius * 1.5, vBorder);
      } else {
        canvas.drawCircle(
          v,
          isDragging ? vertexRadius * 1.3 : vertexRadius,
          vFill,
        );
        canvas.drawCircle(
          v,
          isDragging ? vertexRadius * 1.3 : vertexRadius,
          vBorder,
        );
      }

      // Vertex index number (1-based, GPS_Mapping style)
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 10.5 / zoomScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, v - Offset(tp.width / 2, tp.height / 2));
    }
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
    final label = '${category.defaultBgName}\n${w.toStringAsFixed(2)} × ${h.toStringAsFixed(2)} m\n${area.toStringAsFixed(1)} m²';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
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
      final rectPath = Path()..moveTo(previewRectangle[0].dx, previewRectangle[0].dy);
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
        ..color = (isSelfIntersecting ? const Color(0xFFFF5252) : category.color)
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
        _drawEdgeDimension(canvas, points[i], points[i + 1], edgeLen, zoomScale);
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
      _drawDashedLine(canvas, orthoGuide.$1, orthoGuide.$2, orthoPaint, zoomScale);
    }

    // 5. Committed vertex nodes (Numbered 1..N GPS_Mapping style)
    final nodeRadius = 13.0 / zoomScale;
    final nodeShadow = Paint()..color = Colors.black54;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isStartNode = (i == 0);

      if (isStartNode) {
        // --- POINT 1: SPECIAL START BEACON & CLOSING TARGET ---
        final beaconRadius = (isClosingSnap ? 24.0 : 20.0) / zoomScale;
        final beaconColor = isClosingSnap ? const Color(0xFF00E676) : const Color(0xFF00E5FF);

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
            ..strokeWidth = (isClosingSnap ? 2.5 : 1.8) / zoomScale
            ..style = PaintingStyle.stroke,
        );

        // Inner radar guide ring
        canvas.drawCircle(
          pt,
          beaconRadius * 0.72,
          Paint()
            ..color = beaconColor.withValues(alpha: 0.5)
            ..strokeWidth = 1.0 / zoomScale
            ..style = PaintingStyle.stroke,
        );

        // Drop shadow for core node
        canvas.drawCircle(pt, nodeRadius + 1.5 / zoomScale, nodeShadow);

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
            ..strokeWidth = 2.4 / zoomScale
            ..style = PaintingStyle.stroke,
        );

        // Bold black numeral '1'
        final tp1 = TextPainter(
          text: TextSpan(
            text: '1',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12.0 / zoomScale,
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
                fontSize: 9.5 / zoomScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final labelPos = pt + Offset(-tpLabel.width / 2, beaconRadius + 4.0 / zoomScale);
          final labelRect = Rect.fromLTWH(
            labelPos.dx - 6.0 / zoomScale,
            labelPos.dy - 3.0 / zoomScale,
            tpLabel.width + 12.0 / zoomScale,
            tpLabel.height + 6.0 / zoomScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(labelRect, Radius.circular(5.0 / zoomScale)),
            Paint()..color = const Color(0xEE1A1C24),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(labelRect, Radius.circular(5.0 / zoomScale)),
            Paint()
              ..color = const Color(0xFF00E5FF)
              ..strokeWidth = 1.0 / zoomScale
              ..style = PaintingStyle.stroke,
          );
          tpLabel.paint(canvas, labelPos);
        }

        // When closing snap is active (3+ points hovering start):
        if (isClosingSnap && points.length >= 3) {
          final badgeText = closeLabel ?? 'Затвори зона (1)';
          final tpClose = TextPainter(
            text: TextSpan(
              text: badgeText,
              style: TextStyle(
                color: const Color(0xFF00E676),
                fontSize: 10.5 / zoomScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final badgePos = pt - Offset(tpClose.width / 2, (beaconRadius + tpClose.height + 6.0 / zoomScale));
          final badgeRect = Rect.fromLTWH(
            badgePos.dx - 7.0 / zoomScale,
            badgePos.dy - 4.0 / zoomScale,
            tpClose.width + 14.0 / zoomScale,
            tpClose.height + 8.0 / zoomScale,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(badgeRect, Radius.circular(6.0 / zoomScale)),
            Paint()..color = const Color(0xF2161822),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(badgeRect, Radius.circular(6.0 / zoomScale)),
            Paint()
              ..color = const Color(0xFF00E676)
              ..strokeWidth = 1.5 / zoomScale
              ..style = PaintingStyle.stroke,
          );
          tpClose.paint(canvas, badgePos);
        }
      } else {
        // --- SUBSEQUENT POINTS 2..N: HIGH CONTRAST BADGES ---
        canvas.drawCircle(pt, nodeRadius + 1.5 / zoomScale, nodeShadow);

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
            ..strokeWidth = 2.0 / zoomScale
            ..style = PaintingStyle.stroke,
        );

        final tpN = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.0 / zoomScale,
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
    final color = isSelfIntersecting ? const Color(0xFFFF5252) : const Color(0xFF00E5FF);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, v1, vNew1, linePaint, zoomScale);
    _drawDashedLine(canvas, vNew1, vNew2, linePaint, zoomScale);
    _drawDashedLine(canvas, vNew2, v2, linePaint, zoomScale);

    // Dimension badge
    final midExtruded = (vNew1 + vNew2) / 2.0;
    final distText = '${distance >= 0 ? "+" : ""}${distance.toStringAsFixed(2)} m';
    final tp = TextPainter(
      text: TextSpan(
        text: distText,
        style: TextStyle(
          color: Colors.white,
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
}
