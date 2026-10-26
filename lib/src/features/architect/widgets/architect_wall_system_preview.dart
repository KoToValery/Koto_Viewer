import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_wall_type.dart';

/// Construction diagram on paper: cavities remain empty and round profiles
/// retain a circular aspect ratio at every available preview width.
class ArchitectWallSystemPreview extends StatelessWidget {
  final ArchitectWallSystem system;
  final List<ArchitectMaterialLayer> layers;
  const ArchitectWallSystemPreview({
    super.key,
    required this.system,
    required this.layers,
  });
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SystemPainter(system, layers));
}

class _SystemPainter extends CustomPainter {
  final ArchitectWallSystem system;
  final List<ArchitectMaterialLayer> layers;
  _SystemPainter(this.system, this.layers);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()
      ..color = const Color(0xff484848)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (system.isLog) {
      final radius = size.height / (6 - 4 * system.overlapPercent / 100),
          step = 2 * radius * (1 - system.overlapPercent / 100);
      for (var row = 0; row < 3; row++) {
        final center = Offset(size.width / 2, radius + row * step);
        final profile = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
          Path()..addOval(
            Rect.fromCircle(center: center + Offset(0, step), radius: radius),
          ),
        );
        canvas.drawPath(profile, ink);
      }
    } else {
      final total =
          layers.fold<double>(0, (v, l) => v + l.thickness) +
          system.additionalDepth;
      var cursor = 0.0;
      for (final layer in layers) {
        final left = cursor / total * size.width;
        cursor += layer.thickness;
        final right = cursor / total * size.width;
        canvas.drawRect(Rect.fromLTRB(left, 1, right, size.height - 1), ink);
        if (layer.role == ArchitectLayerRole.core && system.isFrame) {
          final x = left + 2;
          canvas.drawPath(
            Path()
              ..moveTo(right - 2, 5)
              ..lineTo(x, 5)
              ..lineTo(x, size.height - 5)
              ..lineTo(right - 2, size.height - 5),
            ink,
          );
        } else if (layer.role == ArchitectLayerRole.core) {
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(left, 1, right, size.height - 1));
          for (var x = left - size.height; x < right; x += 12) {
            canvas.drawLine(
              Offset(x, size.height),
              Offset(x + size.height, 0),
              ink,
            );
          }
          canvas.restore();
        }
      }
      if (system.isPanel && system.supportDepth > 0) {
        final left = cursor / total * size.width;
        canvas.drawRect(
          Rect.fromLTRB(left, 1, size.width - 1, size.height - 1),
          ink,
        );
        final x = math.min(left + 8, size.width - 3), y = size.height * .25;
        canvas.drawRect(
          Rect.fromLTRB(x, y, size.width - 8, size.height - y),
          ink,
        );
        canvas.drawRect(
          Rect.fromLTRB(
            x + 1.5,
            y + 1.5,
            size.width - 9.5,
            size.height - y - 1.5,
          ),
          ink,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SystemPainter old) =>
      old.system.signature != system.signature || old.layers != layers;
}
