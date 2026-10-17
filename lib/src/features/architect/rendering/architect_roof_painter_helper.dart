// === SECTION: TABLE OF CONTENTS ===
// 1. Committed Roof Planes 2D Painter (Hatch, Eaves Overhang Dashed Line, Ridge/Hip Edges, Slope Arrow & Badge)
// 2. Interactive Roof Drafting Preview (Rubber-band Polygon, Edge Dimensions, Snap Guides)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_geometry.dart';
import '../services/architect_roof_tool.dart';

// === SECTION: COMMITTED ROOF PLANES 2D PAINTER ===

class ArchitectRoofPainterHelper {
  static void paintRoofs({
    required Canvas canvas,
    required ArchitectStorey storey,
    required double scale,
    required Set<String> selectedIds,
    bool isGhost = false,
  }) {
    if (storey.roofs.isEmpty) return;

    for (final roof in storey.roofs) {
      if (roof.points.length < 3) continue;
      final isSelected = !isGhost && selectedIds.contains(roof.id);
      final path = Path()..addPolygon(roof.points, true);

      final topMat = roof.assembly.layers.firstOrNull?.material;
      final baseColor = switch (topMat) {
        ArchitectRoofMaterial.clayTiles => const Color(0xFFC85A32),
        ArchitectRoofMaterial.concreteTiles => const Color(0xFF78909C),
        ArchitectRoofMaterial.metalSeam => const Color(0xFF546E7A),
        ArchitectRoofMaterial.bitumenShingles => const Color(0xFF6D4C41),
        ArchitectRoofMaterial.waterproofing => const Color(0xFF455A64),
        _ => const Color(0xFFC85A32),
      };

      // 1. Subtle translucent fill so walls underneath remain visible
      final fillAlpha = isGhost ? 0.05 : (isSelected ? 0.22 : 0.12);
      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: fillAlpha)
          ..style = PaintingStyle.fill,
      );

      // 2. Architectural roof hatch (tile course lines perpendicular to slope, or seam lines along slope)
      if (!isGhost && scale > 6.0) {
        canvas.save();
        canvas.clipPath(path);
        final bounds = roof.bounds;
        final diag = bounds.size.longestSide + 1.0;
        final center = bounds.center;
        final slopeDir = roof.slopeDirection;
        final isStandingSeam = topMat == ArchitectRoofMaterial.metalSeam;
        final stepDir = isStandingSeam
            ? Offset(-slopeDir.dy, slopeDir.dx)
            : slopeDir;
        final lineDir = Offset(-stepDir.dy, stepDir.dx);
        final step = isStandingSeam ? 0.60 : 0.35;

        final hatchPaint = Paint()
          ..color = baseColor.withValues(alpha: isSelected ? 0.35 : 0.22)
          ..strokeWidth = 0.8 / scale
          ..style = PaintingStyle.stroke;

        final count = (diag / step).ceil();
        for (var i = -count; i <= count; i++) {
          final origin = center + stepDir * (i * step);
          canvas.drawLine(
            origin - lineDir * diag,
            origin + lineDir * diag,
            hatchPaint,
          );
        }
        canvas.restore();
      }

      // 3. Dashed inner wall bearing line (showing eaves overhang projection)
      final bearing = ArchitectRoofGeometry.wallBearingLine(roof);
      if (bearing != null && !isGhost) {
        _drawDashedLine(
          canvas,
          bearing.$1,
          bearing.$2,
          Paint()
            ..color = baseColor.withValues(alpha: 0.55)
            ..strokeWidth = 1.1 / scale
            ..style = PaintingStyle.stroke,
          dashLength: 0.20,
          gapLength: 0.14,
        );
      }

      // 4. Perimeter edges classified by role (Eaves, Ridge, Hip/Valley, Verge)
      for (var i = 0; i < roof.points.length; i++) {
        final a = roof.points[i];
        final b = roof.points[(i + 1) % roof.points.length];
        final kind = ArchitectRoofGeometry.classifyEdge(roof, i, storey.roofs);
        final isEaves = i == roof.safeEavesEdgeIndex;

        final edgeColor = isSelected
            ? (isEaves ? const Color(0xFF00E676) : const Color(0xFFFFAB40))
            : baseColor.withValues(alpha: isGhost ? 0.30 : 0.88);
        final strokeW = switch (kind) {
          ArchitectRoofEdgeKind.ridge ||
          ArchitectRoofEdgeKind.hipOrValley => 2.2 / scale,
          ArchitectRoofEdgeKind.eaves => (isSelected ? 2.8 : 1.9) / scale,
          ArchitectRoofEdgeKind.verge => 1.5 / scale,
        };

        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = edgeColor
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );
      }

      // 5. Slope arrow and elevation/angle badge at centroid
      if (!isGhost && scale > 8.0) {
        _drawSlopeIndicator(
          canvas: canvas,
          storey: storey,
          roof: roof,
          scale: scale,
          color: isSelected ? const Color(0xFFFFCC80) : baseColor,
          isSelected: isSelected,
        );
      }
    }
  }

  /// Returns true if [worldPoint] taps on the central slope direction arrow/badge of [roof].
  static bool hitTestSlopeIndicator(
    ArchitectRoofPlane roof,
    Offset worldPoint, {
    required double scale,
  }) {
    if (roof.points.length < 3) return false;
    final radius = math.max(0.45, 22.0 / scale);
    return (worldPoint - roof.centroid).distance <= radius;
  }

  static void _drawSlopeIndicator({
    required Canvas canvas,
    required ArchitectStorey storey,
    required ArchitectRoofPlane roof,
    required double scale,
    required Color color,
    bool isSelected = false,
  }) {
    final center = roof.centroid;
    final dir = roof.slopeDirection;
    final arrowHalfLen = (0.55).clamp(14.0 / scale, 0.75);
    final start = center - dir * arrowHalfLen;
    final end = center + dir * arrowHalfLen;

    if (isSelected) {
      final haloRadius = (0.42).clamp(13.0 / scale, 0.60);
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..color = const Color(0x3300E5FF)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..color = const Color(0xAA00E5FF)
          ..strokeWidth = 1.2 / scale
          ..style = PaintingStyle.stroke,
      );
    }

    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = (isSelected ? 2.1 : 1.6) / scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, arrowPaint);

    // Arrowhead at high (upslope) end
    final headLen = (0.18).clamp(5.0 / scale, 0.25);
    final perp = Offset(-dir.dy, dir.dx);
    final head1 = end - dir * headLen + perp * (headLen * 0.55);
    final head2 = end - dir * headLen - perp * (headLen * 0.55);
    canvas.drawLine(end, head1, arrowPaint);
    canvas.drawLine(end, head2, arrowPaint);

    // Label: slope degrees, percent, and ridge Z
    final degText = roof.slopeDegrees.toStringAsFixed(
      roof.slopeDegrees % 1 == 0 ? 0 : 1,
    );
    final pctText = roof.slopePercent.round();
    final ridgeZ = storey.elevation + roof.ridgeTopElevation;
    final sign = ridgeZ >= 0 ? '+' : '';
    final label = '$degText° ($pctText%)  $sign${ridgeZ.toStringAsFixed(2)}';

    final fontSize = (11.0 / scale).clamp(0.10, 0.32);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padX = 4.0 / scale;
    final padY = 2.0 / scale;
    final labelOffset = center + Offset(-tp.width / 2, 6.0 / scale);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - padX,
        labelOffset.dy - padY,
        tp.width + padX * 2,
        tp.height + padY * 2,
      ),
      Radius.circular(4.0 / scale),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = const Color(0xCC1E2229),
    );
    tp.paint(canvas, labelOffset);
  }

  // === SECTION: INTERACTIVE ROOF DRAFTING PREVIEW ===

  static void paintDraftRoof({
    required Canvas canvas,
    required ArchitectRoofTool roofTool,
    required double scale,
    required ArchitectUnit units,
  }) {
    if (!roofTool.isDrafting) return;

    // 1. Magnetic snap guides
    if (roofTool.activeMagneticGuides.isNotEmpty) {
      final guidePaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.7)
        ..strokeWidth = 1.0 / scale
        ..style = PaintingStyle.stroke;
      for (final (gA, gB) in roofTool.activeMagneticGuides) {
        _drawDashedLine(
          canvas,
          gA,
          gB,
          guidePaint,
          dashLength: 8.0 / scale,
          gapLength: 5.0 / scale,
        );
      }
    }

    final poly = roofTool.previewPolygon;
    if (poly.isEmpty) return;

    const accent = Color(0xFFFF7043);
    if (poly.length >= 3) {
      final path = Path()..addPolygon(poly, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = accent.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..strokeWidth = 2.0 / scale
          ..style = PaintingStyle.stroke,
      );
    } else if (poly.length == 2) {
      canvas.drawLine(
        poly[0],
        poly[1],
        Paint()
          ..color = accent
          ..strokeWidth = 2.0 / scale,
      );
    }

    // Draw vertices and live edge lengths
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      canvas.drawCircle(
        a,
        4.5 / scale,
        Paint()..color = i == 0 ? const Color(0xFF00E676) : accent,
      );
      if (i + 1 < poly.length || poly.length >= 3) {
        final b = poly[(i + 1) % poly.length];
        final len = (b - a).distance;
        if (len > 0.15) {
          final mid = (a + b) / 2.0;
          final text = units.format(len, decimals: 2);
          final fontSize = (10.5 / scale).clamp(0.08, 0.28);
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: mid,
                width: tp.width + 6 / scale,
                height: tp.height + 3 / scale,
              ),
              Radius.circular(3 / scale),
            ),
            Paint()..color = const Color(0xCC1E2229),
          );
          tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final d = p2 - p1;
    final len = d.distance;
    if (len < 1e-6) return;
    final u = d / len;
    var cursor = 0.0;
    while (cursor < len) {
      final end = math.min(cursor + dashLength, len);
      canvas.drawLine(p1 + u * cursor, p1 + u * end, paint);
      cursor += dashLength + gapLength;
    }
  }
}
