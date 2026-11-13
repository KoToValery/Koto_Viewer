import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps exact-entry controls inside the canvas, above the tool palette.
class ArchitectExactInputOverlay extends StatelessWidget {
  final Offset anchor;
  final Widget child;
  const ArchitectExactInputOverlay({
    super.key,
    required this.anchor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (bounds.maxWidth <= 16 || bounds.maxHeight <= 16) {
        return const SizedBox.shrink();
      }
      final width = math.min(344.0, bounds.maxWidth - 16);
      final phone = bounds.maxWidth < 600;
      final left = phone
          ? (bounds.maxWidth - width) / 2
          : (anchor.dx + 16).clamp(8.0, bounds.maxWidth - width - 8);
      final top = phone
          ? 8.0
          : (anchor.dy + 24).clamp(8.0, math.max(8.0, bounds.maxHeight - 360));
      return Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            top: phone ? null : top.toDouble(),
            bottom: phone ? 8 : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: bounds.maxHeight - top - 8,
              ),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}
