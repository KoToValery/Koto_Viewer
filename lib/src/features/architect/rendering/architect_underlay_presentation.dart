import 'package:flutter/material.dart';
import '../../dxf_viewer/models/dxf_color_table.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'architect_canvas_palette.dart';

/// Display-only CAD pens. Source entity/layer styles are never mutated.
/// Resolves original colors with the CAD viewer's ByLayer/TrueColor rules and
/// original lineweights with its paper-mm to screen-pixel mapping.
class ArchitectUnderlayPresentation {
  final ArchitectCanvasPalette palette;
  final double zoomScale;
  final double? opacity;
  final bool useOriginalColors;
  final bool useOriginalLineweights;
  final _pens = <(int, double), Paint>{};

  ArchitectUnderlayPresentation({
    required this.palette,
    required this.zoomScale,
    this.opacity,
    this.useOriginalColors = false,
    this.useOriginalLineweights = false,
  });

  Paint pen(DxfEntity entity, DxfLayer? layer) {
    var color = palette.underlay;
    if (useOriginalColors) {
      color = DxfColorTable.resolveColor(
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
        layerColor: layer == null
            ? null
            : DxfColorTable.resolveColor(
                colorIndex: layer.colorIndex,
                trueColor: layer.trueColor,
                isDarkBackground: palette.isDark,
              ),
        isDarkBackground: palette.isDark,
      );
    }
    color = color.withValues(
      alpha: (opacity ?? palette.underlay.a).clamp(0, 1),
    );
    var pixels = .8;
    if (useOriginalLineweights) {
      double? positive(double? value) =>
          value != null && value.isFinite && value > 0 ? value : null;
      final mm =
          positive(entity.lineWeight) ??
          positive(layer?.lineweight) ??
          positive(layer?.defaultEntityLineweight);
      pixels = mm == null ? 2 : (mm * 9.5).clamp(.75, 14);
    }
    final scale = zoomScale.isFinite && zoomScale > 0 ? zoomScale : 1.0;
    final width = pixels / scale;
    return _pens.putIfAbsent(
      (color.toARGB32(), width),
      () => Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke,
    );
  }
}
