import 'package:flutter/material.dart';

import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_display_settings.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_painter.dart';
import '../models/architect_underlay_models.dart';
import 'architect_canvas_palette.dart';

/// Shared model-space rendering for the import preview, the plan and its drag ghost.
void paintArchitectCadUnderlay({
  required Canvas canvas,
  required Size size,
  required DxfDocument document,
  required BimCoordinateFrame frame,
  required Rect visibleModel,
  required double viewportScale,
  required ArchitectCanvasPalette palette,
  required Map<String, bool> visibility,
  ArchitectCadUnderlayConfig? config,
  double opacityMultiplier = 1,
}) {
  document.orBuildSpatialIndex;
  final opacity = (config?.opacity ?? palette.underlay.a) * opacityMultiplier;
  final isolated = opacity < 1 || DxfPainter.hasWipeouts(document);
  if (isolated) {
    canvas.saveLayer(
      visibleModel,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }
  try {
    DxfPainter(
      document: document,
      theme: palette.isDark
          ? DxfCanvasTheme.darkCad
          : DxfCanvasTheme.paperWhite,
      currentScale: viewportScale,
      showGrid: false,
      settings: const DxfDisplaySettings(pointStyle: DxfPointStyle.dot),
      visibleCadRect: frame.rectToCad(visibleModel),
      drawingColorOverride: config?.useOriginalColors == true
          ? null
          : palette.underlay.withValues(alpha: 1),
      drawingStrokeWidthOverride: config?.useOriginalLineweights == true
          ? null
          : .8,
      modelPlacement: DxfModelPlacement(
        toCanvas: frame.toModel,
        scale: 1 / frame.unitsPerMeter,
        invertY: frame.invertY,
      ),
      modelLayerOverrides: visibility,
    ).paint(canvas, size);
  } finally {
    if (isolated) canvas.restore();
  }
}
