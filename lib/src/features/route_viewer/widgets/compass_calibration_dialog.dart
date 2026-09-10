import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A modern modal dialog showing an animated Figure-8 motion for device magnetometer calibration.
/// Automatically detects phone language (Bulgarian for 'bg', English otherwise).
class CompassCalibrationDialog extends StatefulWidget {
  const CompassCalibrationDialog({super.key});

  /// Displays the calibration dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CompassCalibrationDialog(),
    );
  }

  @override
  State<CompassCalibrationDialog> createState() => _CompassCalibrationDialogState();
}

class _CompassCalibrationDialogState extends State<CompassCalibrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isBulgarian(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code.toLowerCase() == 'bg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBg = _isBulgarian(context);

    final title = isBg ? 'Калибриране на компаса' : 'Compass Calibration';
    final subtitle = isBg
        ? 'Сензорът за посока е ненадежден и изисква калибриране.'
        : 'The directional compass is unreliable and needs calibration.';
    final instruction = isBg
        ? 'Раздвижете телефона във въздуха с плавно движение във формата на хоризонтална осмица (∞).'
        : 'Move your phone through the air in a smooth horizontal figure-8 pattern (∞).';
    final hint = isBg
        ? 'Пазете устройството от магнитни калъфи и метални предмети.'
        : 'Keep away from magnetic phone cases or large metal objects.';
    final buttonLabel = isBg ? 'Разбрах' : 'Got it';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Icon & Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore,
                    color: Colors.blueAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Animated Figure-8 Stage
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FigureEightPainter(
                      progress: _controller.value,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Main Instruction
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gesture_rounded,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      instruction,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Hint note
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws the Figure-8 (∞) lemniscate curve and animates a gliding phone.
class _FigureEightPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final bool isDark;

  _FigureEightPainter({
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double a = size.width * 0.36; // Horizontal amplitude
    final double b = size.height * 0.58; // Vertical amplitude

    // 1. Draw track path (Lemniscate: x = a*sin(t), y = (b/2)*sin(2t))
    final Path trackPath = Path();
    const int steps = 120;
    for (int i = 0; i <= steps; i++) {
      final double t = (i / steps) * 2 * math.pi;
      final double x = center.dx + a * math.sin(t);
      final double y = center.dy + (b / 2) * math.sin(2 * t);
      if (i == 0) {
        trackPath.moveTo(x, y);
      } else {
        trackPath.lineTo(x, y);
      }
    }
    trackPath.close();

    // Track line paint
    final Paint trackPaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.8)
          : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trackPath, trackPaint);

    // Subtle glow over the track
    final Paint trackGlowPaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: isDark ? 0.25 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0;
    canvas.drawPath(trackPath, trackGlowPaint);

    // 2. Compute phone position and tangent angle for current progress
    final double currentT = progress * 2 * math.pi;
    final double px = center.dx + a * math.sin(currentT);
    final double py = center.dy + (b / 2) * math.sin(2 * currentT);

    // Tangent derivative dx/dt = a*cos(t), dy/dt = b*cos(2t)
    final double dx = a * math.cos(currentT);
    final double dy = b * math.cos(2 * currentT);
    final double headingAngle = math.atan2(dy, dx);

    // 3. Draw pulsating trail behind the phone
    for (int i = 1; i <= 6; i++) {
      final double trailT = currentT - (i * 0.08);
      final double tx = center.dx + a * math.sin(trailT);
      final double ty = center.dy + (b / 2) * math.sin(2 * trailT);
      final double alpha = (1.0 - (i / 7)) * 0.45;
      final Paint trailPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tx, ty), 3.5 - (i * 0.4), trailPaint);
    }

    // 4. Draw phone indicator at (px, py) rotated along tangent
    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(headingAngle);

    // Phone shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(1, 2), width: 28, height: 18),
        const Radius.circular(5),
      ),
      shadowPaint,
    );

    // Phone body
    final Paint bodyPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 18),
        const Radius.circular(5),
      ),
      bodyPaint,
    );

    // Phone border (glowing blue)
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 18),
        const Radius.circular(5),
      ),
      borderPaint,
    );

    // Screen area
    final Paint screenPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(1.5, 0), width: 18, height: 12),
        const Radius.circular(2.5),
      ),
      screenPaint,
    );

    // Home indicator / notch dot
    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(-10, 0), 1.4, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FigureEightPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
