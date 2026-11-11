import 'package:flutter/material.dart';

/// Quiet guidance that sizes to its message and leaves the drawing visible.
class ArchitectCanvasHint extends StatelessWidget {
  final String message;
  final int maxLines;
  final double maxWidth;

  const ArchitectCanvasHint({
    super.key,
    required this.message,
    this.maxLines = 2,
    this.maxWidth = 320,
  });

  @override
  Widget build(BuildContext context) => Align(
    widthFactor: 1,
    heightFactor: 1,
    child: Tooltip(
      message: message,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFDDE2E5), width: .7),
        ),
        child: Text(
          message,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4B5861),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
