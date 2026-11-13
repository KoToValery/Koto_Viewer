import 'dart:ui';

import '../models/architect_component.dart';

/// Shared vector linework for the plan, catalog and publication recorder.
class ArchitectComponentOpeningPainter {
  static void draw(Canvas canvas, ArchitectComponentBlock2D block, Paint pen) {
    for (final opening in block.openingPaths) {
      final bounds = opening.getBounds();
      if (bounds.isEmpty) continue;
      canvas.save();
      canvas.clipPath(opening);
      canvas.drawLine(bounds.topLeft, bounds.bottomRight, pen);
      canvas.drawLine(bounds.topRight, bounds.bottomLeft, pen);
      canvas.restore();
    }
  }
}
