import 'dart:ui';
import '../services/architect_drag_controller.dart';
import '../rendering/architect_canvas_palette.dart';

class ArchitectDragPainterHelper {
  static void drawDragInteraction(
    Canvas canvas,
    Size size,
    ArchitectDragController dragController,
    ArchitectCanvasPalette palette,
  ) {
    if (dragController.isIdle) return;

    final paint = Paint()
      ..color = palette.activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (dragController.isPickingBasePoint) {
      // Draw prompt at cursor
      // ...
    } else if (dragController.isDraggingToTarget) {
      // Draw rubber band, ghost, etc.
      // ...
    }
  }
}
