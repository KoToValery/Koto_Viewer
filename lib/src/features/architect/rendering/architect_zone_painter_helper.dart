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
  }) {
    final poly = List<Offset>.from(zone.polygon);
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
    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : zone.color.withValues(alpha: 0.85)
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
    final vertexRadius = 6.0 / zoomScale;
    final midpointRadius = 4.5 / zoomScale;

    // Edge midpoint grips
    final midFill = Paint()
      ..color = const Color(0xFFFFD600)
      ..style = PaintingStyle.fill;
    final midBorder = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2 / zoomScale
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

    // Vertex pins
    final vFill = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    final vBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    final mergeFill = Paint()
      ..color = const Color(0xFFFF3D00) // Red pulse for merge candidate
      ..style = PaintingStyle.fill;

    for (int i = 0; i < polygon.length; i++) {
      final v = polygon[i];
      final isMergeCandidate = (i == mergeCandidateIndex);
      final isDragging = (i == draggingVertexIndex);

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
}
