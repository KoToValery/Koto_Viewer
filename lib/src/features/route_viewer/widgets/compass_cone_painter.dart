import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A custom widget and painter that renders a live GPS marker with:
/// 1. A pulsating center blue location dot with a crisp white rim.
/// 2. An accuracy circle representation.
/// 3. A luminous directional field-of-view (FOV) cone pointing in the heading direction.
class UserLocationMarker extends StatelessWidget {
  final double? heading; // In degrees (0 = North)
  final double? accuracy;
  final double size;

  const UserLocationMarker({
    super.key,
    this.heading,
    this.accuracy,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CompassConePainter(
          heading: heading,
          accuracy: accuracy,
        ),
      ),
    );
  }
}

class _CompassConePainter extends CustomPainter {
  final double? heading;
  final double? accuracy;

  _CompassConePainter({this.heading, this.accuracy});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Field-of-View Cone if heading is available
    if (heading != null) {
      final double radHeading = (heading! - 90) * (math.pi / 180.0); // Offset so 0° is North (Up)
      final bool isUnreliable = accuracy == null || accuracy! > 35.0;
      final double fovAngle = (isUnreliable ? 85.0 : 55.0) * (math.pi / 180.0);
      final double coneRadius = size.width * 0.46;

      final Path conePath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: coneRadius),
          radHeading - (fovAngle / 2),
          fovAngle,
          false,
        )
        ..close();

      // Cone gradient: bright blue at origin, fading out softly (wider/gentler when uncalibrated)
      final Paint conePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2563EB).withValues(alpha: isUnreliable ? 0.28 : 0.45),
            const Color(0xFF38BDF8).withValues(alpha: isUnreliable ? 0.10 : 0.15),
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: coneRadius))
        ..style = PaintingStyle.fill;

      canvas.drawPath(conePath, conePaint);
    }

    // 2. Outer pulse / aura circle
    final Paint auraPaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16.0, auraPaint);

    // 3. Crisp white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9.0, borderPaint);

    // 4. Vibrant blue center dot
    final Paint dotPaint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassConePainter oldDelegate) {
    return oldDelegate.heading != heading;
  }
}
