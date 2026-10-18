import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_canvas_palette.dart';
import 'architect_elements_painter_helper.dart';

class ArchitectDimensionChainPreview extends CustomPainter {
  final ArchitectDimension? dimension;
  final BimViewportController viewport;
  final ArchitectUnit units;
  final int? decimals;
  final ArchitectDimensionScale dimensionScale;
  final ArchitectCanvasPalette palette;
  final ArchitectStorey? storey;
  ArchitectDimensionChainPreview({
    required this.dimension,
    required this.viewport,
    required this.units,
    this.decimals,
    this.dimensionScale = ArchitectDimensionScale.scale100,
    required this.palette,
    this.storey,
  }) : super(repaint: viewport);
  @override
  void paint(Canvas canvas, Size size) {
    if (dimension == null) return;
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);
    ArchitectElementsPainterHelper.drawDimensions(
      canvas: canvas,
      storey: (storey ?? const ArchitectStorey(id: 'preview', name: ''))
          .copyWith(dimensions: [dimension!]),
      zoomScale: viewport.scale,
      selectedElementId: dimension!.id,
      unit: units,
      decimals: decimals,
      dimensionScale: dimensionScale,
      palette: palette,
      wallObstacles: Path(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArchitectDimensionChainPreview old) =>
      old.dimension != dimension ||
      old.storey != storey ||
      old.units != units ||
      old.decimals != decimals ||
      old.dimensionScale != dimensionScale ||
      old.palette != palette;
}
