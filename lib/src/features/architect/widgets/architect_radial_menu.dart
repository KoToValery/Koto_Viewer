// === SECTION: ARCHITECT RADIAL CONTEXT MENU ===
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_editing/widgets/bim_edit_actions.dart';
export '../../bim_editing/widgets/bim_edit_actions.dart' show BimEditAction;

typedef ArchitectRadialAction = BimEditAction;

class ArchitectRadialMenuItem {
  final ArchitectRadialAction action;
  final IconData icon;
  final String label;
  final Color color;

  const ArchitectRadialMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Adaptive fan/radial contextual menu shown on element long-press.
/// Fans away from user's palm and screen edges.
class ArchitectRadialMenu extends StatefulWidget {
  final Offset center;
  final List<ArchitectRadialMenuItem> items;
  final ValueChanged<ArchitectRadialAction> onActionSelected;
  final VoidCallback onDismiss;

  const ArchitectRadialMenu({
    super.key,
    required this.center,
    required this.items,
    required this.onActionSelected,
    required this.onDismiss,
  });

  @override
  State<ArchitectRadialMenu> createState() => _ArchitectRadialMenuState();
}

class _ArchitectRadialMenuState extends State<ArchitectRadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _select(ArchitectRadialAction action) {
    widget.onActionSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final center = widget.center;

    // Determine fan orientation:
    // Palm naturally covers below the finger, so default orientation is upward (-90°).
    // If finger is close to top of screen, fan downwards (+90°).
    final isTopHalf = center.dy < screenSize.height * 0.38;
    final isNearLeft = center.dx < 110;
    final isNearRight = center.dx > screenSize.width - 110;

    double baseAngle;
    double sweepAngle;

    if (isTopHalf) {
      if (isNearLeft) {
        baseAngle = 10 * math.pi / 180;
        sweepAngle = 80 * math.pi / 180;
      } else if (isNearRight) {
        baseAngle = 90 * math.pi / 180;
        sweepAngle = 80 * math.pi / 180;
      } else {
        baseAngle = 20 * math.pi / 180;
        sweepAngle = 140 * math.pi / 180;
      }
    } else {
      if (isNearLeft) {
        baseAngle = -85 * math.pi / 180;
        sweepAngle = 80 * math.pi / 180;
      } else if (isNearRight) {
        baseAngle = -175 * math.pi / 180;
        sweepAngle = 80 * math.pi / 180;
      } else {
        baseAngle = -160 * math.pi / 180;
        sweepAngle = 140 * math.pi / 180;
      }
    }

    final n = widget.items.length;
    const double radius = 78.0;

    return Stack(
      children: [
        // Central target ring around the touch point
        Positioned(
          left: center.dx - 18,
          top: center.dy - 18,
          child: IgnorePointer(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black38,
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: const Center(child: ContainerDot()),
              ),
            ),
          ),
        ),
        // Radial menu buttons
        for (var i = 0; i < n; i++) ...[
          _buildRadialButton(
            item: widget.items[i],
            center: center,
            angle: n == 1
                ? baseAngle + sweepAngle / 2
                : baseAngle + (i / (n - 1)) * sweepAngle,
            radius: radius,
            screenSize: screenSize,
          ),
        ],
      ],
    );
  }

  Widget _buildRadialButton({
    required ArchitectRadialMenuItem item,
    required Offset center,
    required double angle,
    required double radius,
    required Size screenSize,
  }) {
    const btnSize = 48.0;
    final targetX = center.dx + radius * math.cos(angle) - btnSize / 2;
    final targetY = center.dy + radius * math.sin(angle) - btnSize / 2;

    // Clamp button position within safe screen margins
    final clampedX = targetX.clamp(12.0, screenSize.width - btnSize - 12.0);
    final clampedY = targetY.clamp(32.0, screenSize.height - btnSize - 32.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _select(item.action),
            borderRadius: BorderRadius.circular(btnSize / 2),
            child: Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xF21C1E26),
                border: Border.all(
                  color: item.color.withValues(alpha: 0.85),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 19, color: item.color),
                  const SizedBox(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContainerDot extends StatelessWidget {
  const ContainerDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
