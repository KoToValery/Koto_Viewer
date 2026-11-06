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

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

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
