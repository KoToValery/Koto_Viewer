import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'architect_elements_painter_helper.dart';

/// Independent static layer: pointer previews never repaint the CAD document.
class ArchitectUnderlayPainter extends CustomPainter {
  final DxfDocument? document;
  final BimCoordinateFrame frame;
  final BimViewportController viewport;
  final Map<String, bool> visibility;
  ArchitectUnderlayPainter({
    required this.document,
    required this.frame,
    required this.viewport,
    required this.visibility,
  }) : super(repaint: viewport);
  @override
  void paint(Canvas canvas, Size size) {
    if (document == null) return;
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale / frame.unitsPerMeter);
    canvas.translate(-frame.origin.dx, -frame.origin.dy);
    ArchitectElementsPainterHelper.drawUnderlay(
      canvas: canvas,
      underlayDoc: document,
      zoomScale: viewport.scale / frame.unitsPerMeter,
      layerVisibility: visibility,
      visibleRect: frame
          .rectToCad(viewport.visibleRect)
          .inflate(2 * frame.unitsPerMeter / viewport.scale),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectUnderlayPainter oldDelegate) =>
      document != oldDelegate.document ||
      frame != oldDelegate.frame ||
      viewport != oldDelegate.viewport ||
      !mapEquals(visibility, oldDelegate.visibility);
}
