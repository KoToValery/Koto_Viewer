import 'package:flutter/material.dart';

/// Floating Search Bar overlay for searching text in DXF drawing.
class DxfSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int matchCount;
  final int currentMatchIndex;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  const DxfSearchBar({
    super.key,
    required this.controller,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search text or dimensions in DXF...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: onChanged,
              ),
            ),
            if (controller.text.isNotEmpty) ...[
              Text(
                matchCount > 0 ? '${currentMatchIndex + 1}/$matchCount' : '0 matches',
                style: TextStyle(
                  fontSize: 12,
                  color: matchCount > 0 ? theme.colorScheme.primary : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                tooltip: 'Previous match',
                onPressed: matchCount > 0 ? onPrevious : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                tooltip: 'Next match',
                onPressed: matchCount > 0 ? onNext : null,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Close search',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
