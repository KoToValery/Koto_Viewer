import 'package:flutter/material.dart';

/// Quiet guidance that sizes to its message and leaves the drawing visible.
class ArchitectCanvasHint extends StatelessWidget {
  final String message;
  final int maxLines;
  final double maxWidth;
  final bool warning;

  const ArchitectCanvasHint({
    super.key,
    required this.message,
    this.maxLines = 2,
    this.maxWidth = 320,
    this.warning = false,
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
          color: warning ? const Color(0xF5FFEBEE) : const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: warning ? const Color(0xFFD32F2F) : const Color(0xFFDDE2E5),
            width: warning ? 1.1 : .7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warning) ...[
              const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: Color(0xFFC62828),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                message,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: warning
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFF4B5861),
                  fontSize: 12,
                  fontWeight: warning ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
