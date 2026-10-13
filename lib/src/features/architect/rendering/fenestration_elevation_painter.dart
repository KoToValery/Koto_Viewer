// === SECTION: FENESTRATION ELEVATION PAINTER ===
import 'package:flutter/material.dart';
import '../models/architect_fenestration_style.dart';

/// Canvas painter for rendering interactive 2D facade elevations of windows and doors.
class FenestrationElevationPainter extends CustomPainter {
  final ArchitectFenestrationStyle style;
  final String? selectedPaneId;

  const FenestrationElevationPainter({
    required this.style,
    this.selectedPaneId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 10 || size.height < 10) return;

    // Draw background subtle CAD grid plate
    final bgPaint = Paint()..color = const Color(0xFF1E222B);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Draw faint grid dots
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    const step = 24.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
      }
    }

    style.paintElevation2D(
      canvas: canvas,
      size: size,
      selectedPaneId: selectedPaneId,
    );
  }

  @override
  bool shouldRepaint(covariant FenestrationElevationPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.selectedPaneId != selectedPaneId;
  }
}
