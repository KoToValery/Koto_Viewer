// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. MAIN AXIS RENDERING (drawAxes)
// 3. SELECTION & HANDLE DRAWING
// 4. OFFSET & DRAFTING PREVIEW DRAWING
// 5. DASH-DOT & BUBBLE ROUTINES
// ===================================

import 'package:flutter/material.dart';

import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';

// === SECTION: MAIN AXIS RENDERING ===

/// High-performance canvas drawing routines for dynamic architectural grid axes.
class ArchitectGridAxisPainterHelper {
  static void drawAxes({
    required Canvas canvas,
    required ArchitectProject project,
    required double zoomScale,
    String? selectedAxisId,
    StructuralGridAxis? draggedAxisSnapshot,
    bool isDraggingHandle = false,
    bool isMovingAxis = false,
    StructuralGridAxis? moveOriginalAxis,
    Offset? moveCurrentDelta,
    StructuralGridAxis? offsetPreview,
    Offset? draftStart,
    Offset? draftEnd,
    String? draftSnapLabel,
  }) {
    // Normal axis paint
    final normalAxisPaint = Paint()
      ..color = const Color(0xFFC62828).withValues(alpha: 0.80)
      ..strokeWidth = 1.2 / zoomScale
      ..style = PaintingStyle.stroke;

    // Selected axis paint
    final selectedAxisPaint = Paint()
      ..color = const Color(0xFFFF9F0A)
      ..strokeWidth = 2.4 / zoomScale
      ..style = PaintingStyle.stroke;

    for (final axis in project.gridAxes) {
      final isSelected = (axis.id == selectedAxisId);

      // If this axis is currently being stretched via handle drag, use dragged snapshot
      StructuralGridAxis renderAxis = axis;
      if (isSelected && isDraggingHandle && draggedAxisSnapshot != null) {
        renderAxis = draggedAxisSnapshot;
      } else if (isSelected && isMovingAxis && moveCurrentDelta != null) {
        renderAxis = axis.copyWith(
          start: axis.start + moveCurrentDelta,
          end: axis.end + moveCurrentDelta,
        );
      }

      final paint = isSelected ? selectedAxisPaint : normalAxisPaint;
      _drawDashDotLine(canvas, renderAxis.start, renderAxis.end, paint, zoomScale);

      // Draw bubbles
      if (renderAxis.bubbleAtStart) {
        _drawBubble(
          canvas: canvas,
          center: renderAxis.start,
          label: renderAxis.name,
          zoomScale: zoomScale,
          isSelected: isSelected,
        );
      }
      if (renderAxis.bubbleAtEnd) {
        _drawBubble(
          canvas: canvas,
          center: renderAxis.end,
          label: renderAxis.name,
          zoomScale: zoomScale,
          isSelected: isSelected,
        );
      }

      // Draw handles if selected
      if (isSelected) {
        _drawHandles(
          canvas: canvas,
          start: renderAxis.start,
          end: renderAxis.end,
          zoomScale: zoomScale,
        );
      }
    }

    // Offset Preview Line
    if (offsetPreview != null) {
      _drawOffsetPreview(
        canvas: canvas,
        preview: offsetPreview,
        zoomScale: zoomScale,
      );
    }

    // Active Drafting Line
    if (draftStart != null && draftEnd != null) {
      _drawDraftingLine(
        canvas: canvas,
        start: draftStart,
        end: draftEnd,
        snapLabel: draftSnapLabel,
        zoomScale: zoomScale,
      );
    }
  }

  // === SECTION: SELECTION & HANDLE DRAWING ===

  static void _drawHandles({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double zoomScale,
  }) {
    final handlePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final handleBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    final double handleRadius = 6.0 / zoomScale;

    canvas.drawCircle(start, handleRadius, handlePaint);
    canvas.drawCircle(start, handleRadius, handleBorder);

    canvas.drawCircle(end, handleRadius, handlePaint);
    canvas.drawCircle(end, handleRadius, handleBorder);
  }

  // === SECTION: OFFSET & DRAFTING PREVIEW DRAWING ===

  static void _drawOffsetPreview({
    required Canvas canvas,
    required StructuralGridAxis preview,
    required double zoomScale,
  }) {
    final previewPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, preview.start, preview.end, previewPaint, zoomScale);

    if (preview.bubbleAtStart) {
      _drawBubble(
        canvas: canvas,
        center: preview.start,
        label: preview.name,
        zoomScale: zoomScale,
        isSelected: false,
        isGhost: true,
      );
    }
    if (preview.bubbleAtEnd) {
      _drawBubble(
        canvas: canvas,
        center: preview.end,
        label: preview.name,
        zoomScale: zoomScale,
        isSelected: false,
        isGhost: true,
      );
    }
  }

  static void _drawDraftingLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double zoomScale,
    String? snapLabel,
  }) {
    final draftPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;

    _drawDashDotLine(canvas, start, end, draftPaint, zoomScale);

    // Endpoints circles
    final pointPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 4.0 / zoomScale, pointPaint);
    canvas.drawCircle(end, 4.0 / zoomScale, pointPaint);

    // Dimension length badge at midpoint
    final mid = (start + end) / 2.0;
    final dist = (end - start).distance;
    if (dist > 0.4) {
      final textSpan = TextSpan(
        text: snapLabel != null ? '${dist.toStringAsFixed(2)} m ($snapLabel)' : '${dist.toStringAsFixed(2)} m',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.0 / zoomScale,
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xCC000000),
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2 + 12.0 / zoomScale));
    }
  }

  // === SECTION: DASH-DOT & BUBBLE ROUTINES ===

  static void _drawBubble({
    required Canvas canvas,
    required Offset center,
    required String label,
    required double zoomScale,
    required bool isSelected,
    bool isGhost = false,
  }) {
    final double bubbleRadius = 12.0 / zoomScale;

    final bgPaint = Paint()
      ..color = isGhost ? const Color(0xAA1E2A38) : const Color(0xFF1E1E24)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isGhost
          ? const Color(0xFF00E5FF)
          : isSelected
              ? const Color(0xFFFF9F0A)
              : const Color(0xFFC62828)
      ..strokeWidth = (isSelected ? 2.0 : 1.2) / zoomScale
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, bubbleRadius, bgPaint);
    canvas.drawCircle(center, bubbleRadius, borderPaint);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: isGhost ? const Color(0xFF00E5FF) : Colors.white,
        fontSize: 10.5 / zoomScale,
        fontWeight: FontWeight.bold,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  static void _drawDashDotLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double zoomScale,
  ) {
    final d = p2 - p1;
    final total = d.distance;
    if (total < 1e-4) return;
    final u = d / total;

    final dash = 12.0 / zoomScale;
    final gap = 4.0 / zoomScale;
    final dot = 2.0 / zoomScale;

    double cur = 0;
    while (cur < total) {
      final segEnd = (cur + dash).clamp(0.0, total);
      canvas.drawLine(p1 + u * cur, p1 + u * segEnd, paint);
      cur += dash + gap;
      if (cur >= total) break;
      final dotEnd = (cur + dot).clamp(0.0, total);
      canvas.drawLine(p1 + u * cur, p1 + u * dotEnd, paint);
      cur += dot + gap;
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
    final total = d.distance;
    if (total < 1e-4) return;
    final u = d / total;

    final dash = 8.0 / zoomScale;
    final gap = 5.0 / zoomScale;

    double cur = 0;
    while (cur < total) {
      final segEnd = (cur + dash).clamp(0.0, total);
      canvas.drawLine(p1 + u * cur, p1 + u * segEnd, paint);
      cur += dash + gap;
    }
  }
}
