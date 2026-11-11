import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../rendering/architect_clearance_badge_layout.dart';
import 'architect_canvas_hint.dart';
import 'architect_floating_command_overlay.dart';

/// One quiet measurement/snap badge, clear of the curve and its touch grip.
/// Screen/model state, hit testing and commit ownership stay in the workspace.
class ArchitectCurvingEdgeOverlay extends StatelessWidget {
  final Offset p1, p2, chordMid, handlePos, gripPos;
  final bool isCurved, pendingConfirmation;
  final List<Offset> curvePoints;
  final String distanceText;
  final String? snapLabel;
  final bool Function(Rect) intersectsDrawing;
  final VoidCallback onConfirm, onCancel;

  const ArchitectCurvingEdgeOverlay({
    super.key,
    required this.p1,
    required this.p2,
    required this.chordMid,
    required this.handlePos,
    required this.gripPos,
    required this.isCurved,
    required this.curvePoints,
    required this.distanceText,
    this.snapLabel,
    required this.pendingConfirmation,
    required this.intersectsDrawing,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final message =
          'h=$distanceText${snapLabel == null ? '' : ' · $snapLabel'}';
      final available = Rect.fromLTRB(
        8,
        80,
        constraints.maxWidth - 8,
        constraints.maxHeight - 100,
      );
      if (available.width < 140 || available.height < 48) {
        return const SizedBox.shrink();
      }
      final text = TextPainter(
        text: TextSpan(
          text: message,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final actionsWidth = pendingConfirmation ? 104.0 : 0.0;
      final width = math.min(
        available.width,
        math.min(180, text.width + 16) + actionsWidth,
      );
      text.dispose();
      final delta = handlePos - chordMid;
      final outward = delta.distance > 1
          ? delta / delta.distance
          : const Offset(0, -1);
      final position = ArchitectClearanceBadgeLayout.place(
        preferred: gripPos + outward * 48,
        available: available,
        size: Size(width, pendingConfirmation ? 48 : 30),
        excluded: [
          Rect.fromCircle(center: gripPos, radius: 24),
          Rect.fromCircle(center: handlePos, radius: 16),
          Rect.fromCircle(center: p1, radius: 12),
          Rect.fromCircle(center: p2, radius: 12),
        ],
        intersectsWall: (rect) {
          if (intersectsDrawing(rect.inflate(8))) return true;
          for (var i = 1; i < curvePoints.length; i++) {
            if (Rect.fromPoints(
              curvePoints[i - 1],
              curvePoints[i],
            ).inflate(12).overlaps(rect)) {
              return true;
            }
          }
          return false;
        },
      );
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CurvingEdgeGuidePainter(
                  p1: p1,
                  p2: p2,
                  chordMid: chordMid,
                  handlePos: handlePos,
                  gripPos: gripPos,
                  isCurved: isCurved,
                ),
              ),
            ),
          ),
          if (pendingConfirmation)
            ArchitectFloatingCommandOverlay(
              surfaceKey: const ValueKey('architect-curving-feedback'),
              position: position.topLeft,
              label: message,
              onConfirm: onConfirm,
              onCancel: onCancel,
            )
          else
            Positioned.fromRect(
              rect: position,
              child: IgnorePointer(
                child: ArchitectCanvasHint(
                  key: const ValueKey('architect-curving-feedback'),
                  message: message,
                  maxLines: 1,
                  maxWidth: width,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CurvingEdgeGuidePainter extends CustomPainter {
  final Offset p1, p2, chordMid, handlePos, gripPos;
  final bool isCurved;

  _CurvingEdgeGuidePainter({
    required this.p1,
    required this.p2,
    required this.chordMid,
    required this.handlePos,
    required this.gripPos,
    required this.isCurved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dashed chord line between p1 and p2
    final chordPaint = Paint()
      ..color = const Color(0x9965737E)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, p1, p2, chordPaint, 6, 4);

    // 2. Height / sagitta line from chordMid to handlePos (apex)
    final heightPaint = Paint()
      ..color = const Color(0xFF65737E)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    if (isCurved && (handlePos - chordMid).distance > 2) {
      canvas.drawLine(chordMid, handlePos, heightPaint);

      // Ticks at both ends of height line
      final delta = handlePos - chordMid;
      final dist = delta.distance;
      if (dist > 1e-4) {
        final tick = Offset(-delta.dy, delta.dx) / dist * 5;
        canvas.drawLine(chordMid - tick, chordMid + tick, heightPaint);
        canvas.drawLine(handlePos - tick, handlePos + tick, heightPaint);
      }
    }

    final midDotPaint = Paint()
      ..color = const Color(0xFF65737E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(chordMid, 3.0, midDotPaint);

    // 3. Leader line from handlePos (apex) to gripPos (remote offset handle)
    if ((gripPos - handlePos).distance > 2) {
      final leaderPaint = Paint()
        ..color = const Color(0x9965737E)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, handlePos, gripPos, leaderPaint, 4, 3);
    }

    // Apex marker (small hollow circle at the apex of the curve)
    if (isCurved) {
      canvas.drawCircle(
        handlePos,
        4.0,
        Paint()
          ..color = const Color(0xFF65737E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        handlePos,
        2.0,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }

    // Remote grip stays legible without a glow.
    final bgGripPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(gripPos, 8, bgGripPaint);

    final outerHandlePaint = Paint()
      ..color = const Color(0xFF65737E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(gripPos, 7.5, outerHandlePaint);

    final innerHandlePaint = Paint()
      ..color = const Color(0xFF65737E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(gripPos, 2.5, innerHandlePaint);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 1e-4) return;
    final unitX = dx / distance;
    final unitY = dy / distance;
    var current = 0.0;
    while (current < distance) {
      final start = Offset(p1.dx + unitX * current, p1.dy + unitY * current);
      final endDist = math.min(current + dashWidth, distance);
      final end = Offset(p1.dx + unitX * endDist, p1.dy + unitY * endDist);
      canvas.drawLine(start, end, paint);
      current += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _CurvingEdgeGuidePainter old) =>
      old.p1 != p1 ||
      old.p2 != p2 ||
      old.chordMid != chordMid ||
      old.handlePos != handlePos ||
      old.gripPos != gripPos ||
      old.isCurved != isCurved;
}
