import 'dart:math' as math;
import 'dart:ui';

/// Shared screen-space rays for rotation and hatch direction handles.
class ArchitectAngularGuides {
  static void paint(
    Canvas canvas,
    Size size, {
    required Offset pivot,
    required Color color,
    double referenceAngle = 0,
    double? activeAngle,
  }) {
    final guide = Paint()
      ..color = color.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final angle = referenceAngle + i * math.pi / 4;
      final u = Offset(math.cos(angle), math.sin(angle));
      final active =
          activeAngle != null && math.cos(angle - activeAngle) > 1 - 1e-9;
      guide.color = color.withValues(alpha: active ? .8 : .35);
      // Clip before making dashes so even a far-off-screen pivot takes only
      // viewport-sized work. Keep dash phase tied to the original pivot.
      var first = 0.0, last = double.infinity;
      for (final (position, direction, extent) in [
        (pivot.dx, u.dx, size.width),
        (pivot.dy, u.dy, size.height),
      ]) {
        if (direction.abs() < 1e-10) {
          if (position < 0 || position > extent) last = -1;
        } else {
          final a = -position / direction, b = (extent - position) / direction;
          first = math.max(first, math.min(a, b));
          last = math.min(last, math.max(a, b));
        }
      }
      for (var t = (first / 12).floor() * 12.0; t <= last; t += 12) {
        canvas.drawLine(pivot + u * t, pivot + u * (t + 5), guide);
      }
    }
  }
}
