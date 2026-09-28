import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive on-screen Virtual Joystick for 3D Walkthrough / Fly Mode.
///
/// Provides smooth analog 2-axis directional deflection:
/// - dy < 0: Move Forward in view direction
/// - dy > 0: Move Backward
/// - dx < 0: Strafe Left
/// - dx > 0: Strafe Right
class Cad3DVirtualJoystick extends StatefulWidget {
  final double radius;
  final double knobRadius;
  final ValueChanged<Offset> onDirectionChanged;
  final bool isDark;

  const Cad3DVirtualJoystick({
    super.key,
    this.radius = 64.0,
    this.knobRadius = 26.0,
    required this.onDirectionChanged,
    this.isDark = true,
  });

  @override
  State<Cad3DVirtualJoystick> createState() => _Cad3DVirtualJoystickState();
}

class _Cad3DVirtualJoystickState extends State<Cad3DVirtualJoystick>
    with SingleTickerProviderStateMixin {
  Offset _knobOffset = Offset.zero;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;
  bool _isDragging = false;

  static const double _deadzone = 0.08;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(() {
        setState(() {
          _knobOffset = _springAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _springController.stop();
    _isDragging = true;
    HapticFeedback.selectionClick();
    _updateKnob(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateKnob(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _releaseKnob();
  }

  void _onPanCancel() {
    _releaseKnob();
  }

  void _releaseKnob() {
    _isDragging = false;
    widget.onDirectionChanged(Offset.zero);

    _springAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutCubic,
    ));

    _springController.forward(from: 0.0);
  }

  void _updateKnob(Offset localPos) {
    final center = Offset(widget.radius, widget.radius);
    final delta = localPos - center;
    final maxDist = widget.radius - widget.knobRadius * 0.5;
    final dist = delta.distance;

    final Offset clampedOffset;
    if (dist > maxDist) {
      clampedOffset = (delta / dist) * maxDist;
    } else {
      clampedOffset = delta;
    }

    setState(() {
      _knobOffset = clampedOffset;
    });

    // Compute normalized deflection [-1.0, 1.0]
    final normalizedDist = clampedOffset.distance / maxDist;
    if (normalizedDist < _deadzone) {
      widget.onDirectionChanged(Offset.zero);
    } else {
      // Re-map outside deadzone smoothly
      final factor = (normalizedDist - _deadzone) / (1.0 - _deadzone);
      final direction = (clampedOffset / clampedOffset.distance) * factor.clamp(0.0, 1.0);
      widget.onDirectionChanged(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2.0;
    const accentColor = Color(0xFF00E5FF);

    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring & Subtle Base
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDark
                    ? Colors.black.withValues(alpha: _isDragging ? 0.45 : 0.28)
                    : Colors.white.withValues(alpha: _isDragging ? 0.65 : 0.45),
                border: Border.all(
                  color: _isDragging
                      ? accentColor.withValues(alpha: 0.85)
                      : accentColor.withValues(alpha: 0.35),
                  width: _isDragging ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                  if (_isDragging)
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: CustomPaint(
                painter: _JoystickBasePainter(
                  isDark: widget.isDark,
                  accentColor: accentColor,
                  isDragging: _isDragging,
                ),
              ),
            ),

            // Draggable Knob (Thumb stick)
            Transform.translate(
              offset: _knobOffset,
              child: Container(
                width: widget.knobRadius * 2.0,
                height: widget.knobRadius * 2.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isDragging
                        ? [
                            accentColor.withValues(alpha: 0.95),
                            accentColor.withValues(alpha: 0.65),
                          ]
                        : [
                            widget.isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
                            widget.isDark ? const Color(0xFF1F2937) : const Color(0xFF94A3B8),
                          ],
                  ),
                  border: Border.all(
                    color: _isDragging
                        ? Colors.white
                        : accentColor.withValues(alpha: 0.6),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                    if (_isDragging)
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDragging
                          ? Colors.white
                          : accentColor.withValues(alpha: 0.8),
                    ),
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

/// Custom painter for subtle directional tick marks on the joystick base
class _JoystickBasePainter extends CustomPainter {
  final bool isDark;
  final Color accentColor;
  final bool isDragging;

  const _JoystickBasePainter({
    required this.isDark,
    required this.accentColor,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final tickPaint = Paint()
      ..color = (isDragging ? accentColor : (isDark ? Colors.white : Colors.black))
          .withValues(alpha: isDragging ? 0.6 : 0.25)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const tickLen = 6.0;
    const margin = 5.0;

    // Up Tick
    canvas.drawLine(
      Offset(center.dx, margin),
      Offset(center.dx, margin + tickLen),
      tickPaint,
    );
    // Down Tick
    canvas.drawLine(
      Offset(center.dx, size.height - margin),
      Offset(center.dx, size.height - margin - tickLen),
      tickPaint,
    );
    // Left Tick
    canvas.drawLine(
      Offset(margin, center.dy),
      Offset(margin + tickLen, center.dy),
      tickPaint,
    );
    // Right Tick
    canvas.drawLine(
      Offset(size.width - margin, center.dy),
      Offset(size.width - margin - tickLen, center.dy),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickBasePainter oldDelegate) {
    return oldDelegate.isDragging != isDragging ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}
