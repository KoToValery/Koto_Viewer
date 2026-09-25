import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/services/project_bundle_service.dart';

/// Reusable Presentation Navigation Bar displayed at the bottom of any viewer
/// during Project Presentation Mode.
///
/// Allows switching between architectural drawings, 3D models, renders,
/// and video walkthroughs with previous / next controls and project counters.
class ProjectPresentationBar extends StatelessWidget {
  final ProjectBundleInfo projectBundle;
  final int currentIndex;
  final void Function(int newIndex)? onSwitchProjectItem;
  final VoidCallback? onExit;

  const ProjectPresentationBar({
    super.key,
    required this.projectBundle,
    required this.currentIndex,
    required this.onSwitchProjectItem,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final total = projectBundle.files.length;
    final currentItem = (currentIndex >= 0 && currentIndex < total)
        ? projectBundle.files[currentIndex]
        : null;
    final l10n = context.l10n;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC0F172A), // Dark slate with alpha
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous Button
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.prevProjectItem,
                onPressed: currentIndex > 0 && onSwitchProjectItem != null
                    ? () => onSwitchProjectItem!(currentIndex - 1)
                    : null,
              ),

              const SizedBox(width: 8),

              // Center Project & File Info
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentItem != null) ...[
                          Icon(
                            _getCategoryIcon(currentItem.category),
                            size: 14,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            currentItem?.fileName ?? projectBundle.projectName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${currentIndex + 1} / $total  •  ${projectBundle.projectName}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Next Button
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.nextProjectItem,
                onPressed: currentIndex < total - 1 && onSwitchProjectItem != null
                    ? () => onSwitchProjectItem!(currentIndex + 1)
                    : null,
              ),

              if (onExit != null) ...[
                Container(
                  height: 24,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.white24,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: Colors.white70,
                  tooltip: 'Exit Presentation',
                  onPressed: onExit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ProjectItemCategory category) {
    switch (category) {
      case ProjectItemCategory.video:
        return Icons.play_circle_filled_rounded;
      case ProjectItemCategory.drawing:
        return Icons.architecture_rounded;
      case ProjectItemCategory.model3d:
        return Icons.view_in_ar_rounded;
      case ProjectItemCategory.image:
        return Icons.photo_rounded;
      case ProjectItemCategory.document:
        return Icons.description_rounded;
      case ProjectItemCategory.all:
      case ProjectItemCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }
}
