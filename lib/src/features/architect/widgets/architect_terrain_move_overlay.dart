import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'architect_underlay_crop_overlay.dart';

/// Displays the center 4-arrow free-move handle on a selected terrain boundary,
/// matching the direct-drag interaction pattern used by underlays.
class ArchitectTerrainMoveOverlay extends StatelessWidget {
  final List<Offset> polygon;
  final double scale;
  final double rotation;
  final Offset translation;
  final bool moving;

  const ArchitectTerrainMoveOverlay({
    super.key,
    required this.polygon,
    required this.scale,
    required this.translation,
    this.rotation = 0.0,
    this.moving = false,
  });

  /// Returns true when [rawModel] hits the center free-move handle of [polygon].
  static bool hitCenterHandle(
    List<Offset> polygon,
    Offset rawModel,
    double scale,
  ) {
    final center = ArchitectUnderlayCropOverlay.centerPoint(polygon);
    if (center == null || scale <= 0) return false;
    return (center - rawModel).distance <= 24.0 / scale;
  }

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _TerrainMovePainter(this)));
}

class _TerrainMovePainter extends CustomPainter {
  final ArchitectTerrainMoveOverlay data;
  const _TerrainMovePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.polygon.length < 3 || data.scale <= 0) return;
    final centerModel = ArchitectUnderlayCropOverlay.centerPoint(data.polygon);
    if (centerModel == null) return;
    final scaled = centerModel * data.scale;
    final Offset centerScreen;
    if (data.rotation == 0) {
      centerScreen = scaled + data.translation;
    } else {
      final c = math.cos(data.rotation);
      final s = math.sin(data.rotation);
      centerScreen =
          Offset(scaled.dx * c - scaled.dy * s, scaled.dx * s + scaled.dy * c) +
          data.translation;
    }
    ArchitectUnderlayCropOverlay.paintCenterMoveHandle(
      canvas,
      centerScreen,
      moving: data.moving,
    );
  }

  @override
  bool shouldRepaint(covariant _TerrainMovePainter oldDelegate) =>
      oldDelegate.data.polygon != data.polygon ||
      oldDelegate.data.scale != data.scale ||
      oldDelegate.data.rotation != data.rotation ||
      oldDelegate.data.translation != data.translation ||
      oldDelegate.data.moving != data.moving;
}
