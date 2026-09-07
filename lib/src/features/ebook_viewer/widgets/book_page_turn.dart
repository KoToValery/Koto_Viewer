import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A realistic, high-performance 3D page curl/flip transition for book reading.
/// Simulates paper depth, spine pivot rotation, and dynamic light/shadow curvature.
class BookPageTurnWrapper extends StatelessWidget {
  final int index;
  final PageController pageController;
  final Widget child;

  const BookPageTurnWrapper({
    super.key,
    required this.index,
    required this.pageController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, staticChild) {
        double pageOffset = 0.0;
        if (pageController.hasClients && pageController.position.haveDimensions) {
          final currentPage = pageController.page ?? pageController.initialPage.toDouble();
          pageOffset = currentPage - index;
        }

        // Clamp to avoid extreme values
        final clampedOffset = pageOffset.clamp(-1.0, 1.0);

        if (clampedOffset.abs() < 0.001) {
          // Page is flat and resting
          return staticChild!;
        }

        final isTurningAway = clampedOffset > 0; // Page is being turned forward
        final progress = clampedOffset.abs();

        final Matrix4 transform = Matrix4.identity()..setEntry(3, 2, 0.0011);

        if (isTurningAway) {
          // Rotate along the left spine like turning a real physical page
          final angle = -progress * (math.pi / 2.35);
          transform.rotateY(angle);
        } else {
          // Subtle parallax slip for the page underneath
          final slip = clampedOffset * 0.15 * MediaQuery.of(context).size.width;
          transform.translateByDouble(slip, 0.0, -10.0, 1.0);
        }

        return Transform(
          transform: transform,
          alignment: Alignment.centerLeft,
          child: Stack(
            fit: StackFit.expand,
            children: [
              staticChild!,

              // Realistic paper curl lighting & shadow gradient
              if (isTurningAway) ...[
                // Spine crease shadow
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.28 * progress),
                            Colors.black.withValues(alpha: 0.08 * progress),
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.12 * progress),
                            Colors.black.withValues(alpha: 0.25 * progress),
                          ],
                          stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Drop shadow falling onto the upcoming page from the turning page
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.35 * progress),
                            Colors.black.withValues(alpha: 0.12 * progress),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      child: child,
    );
  }
}
