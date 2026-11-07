import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';

class ArchitectWallHatch {
  /// All linear core patterns are 45 degrees in the wall's local coordinates.
  static void paint(
    Canvas canvas,
    ArchitectWall wall,
    Path region,
    double scale,
    Color color,
    {WallCoreMaterial? material}
  ) {
    if (region.getBounds().isEmpty) return;
    canvas.save();
    canvas.clipPath(region);
    canvas.translate(wall.coreCenterStart.dx, wall.coreCenterStart.dy);
    canvas.rotate(math.atan2(wall.unitVector.dy, wall.unitVector.dx));
    final bounds = canvas.getLocalClipBounds();
    final spacing = math.max(.12, 8 / scale);
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6 / scale;
    if ((material ?? wall.coreMaterial) == WallCoreMaterial.aeratedConcrete) {
      final start = ((bounds.left - bounds.height) / spacing).floor() * spacing;
      var isDashed = false;
      final dashLen = 2.0 / scale;
      final gapLen = 1.6 / scale;
      for (var x = start; x <= bounds.right; x += spacing * 0.5) {
        if (!isDashed) {
          canvas.drawLine(
            Offset(x, bounds.top),
            Offset(x + bounds.height, bounds.bottom),
            paint,
          );
        } else {
          final pA = Offset(x, bounds.top);
          final pB = Offset(x + bounds.height, bounds.bottom);
          final dir = pB - pA;
          final totalLen = dir.distance;
          if (totalLen > 1e-4) {
            final u = dir / totalLen;
            var d = 0.0;
            while (d < totalLen) {
              final segEnd = math.min(d + dashLen, totalLen);
              canvas.drawLine(pA + u * d, pA + u * segEnd, paint);
              d += dashLen + gapLen;
            }
          }
        }
        isDashed = !isDashed;
      }
      canvas.restore();
      return;
    }
    final start = ((bounds.left - bounds.height) / spacing).floor() * spacing;
    for (var x = start; x <= bounds.right; x += spacing) {
      void line(double offset) => canvas.drawLine(
        Offset(x + offset, bounds.top),
        Offset(x + offset + bounds.height, bounds.bottom),
        paint,
      );
      line(0);
      if ((material ?? wall.coreMaterial) == WallCoreMaterial.timber) line(spacing * .22);
      if ((material ?? wall.coreMaterial) == WallCoreMaterial.panel) {
        line(spacing * .15);
        line(spacing * .3);
      }
    }
    if ((material ?? wall.coreMaterial) == WallCoreMaterial.concrete) {
      for (
        var x = (bounds.left / spacing).floor() * spacing;
        x < bounds.right;
        x += spacing
      ) {
        for (
          var y = (bounds.top / spacing).floor() * spacing;
          y < bounds.bottom;
          y += spacing
        ) {
          canvas.drawCircle(
            Offset(x + spacing * .4, y + spacing * .7),
            .8 / scale,
            paint,
          );
        }
      }
    }
    canvas.restore();
  }
}
