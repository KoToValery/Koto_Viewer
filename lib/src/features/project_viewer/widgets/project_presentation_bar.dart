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
  final bool compact;

  const ProjectPresentationBar({
    super.key,
    required this.projectBundle,
    required this.currentIndex,
    required this.onSwitchProjectItem,
    this.onExit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = projectBundle.files.length;
    final currentItem = (currentIndex >= 0 && currentIndex < total)
        ? projectBundle.files[currentIndex]
        : null;
    final l10n = context.l10n;

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: compact ? 8 : 12, sigmaY: compact ? 8 : 12),
        child: Container(
          constraints: BoxConstraints(maxWidth: compact ? 300 : 480),
          margin: EdgeInsets.symmetric(horizontal: compact ? 6 : 16),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 12,
            vertical: compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xCC0F172A), // Dark slate with alpha
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
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
                icon: Icon(Icons.skip_previous_rounded, size: compact ? 20 : 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.prevProjectItem,
                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                constraints: compact ? const BoxConstraints(minWidth: 30, minHeight: 30) : const BoxConstraints(),
                onPressed: currentIndex > 0 && onSwitchProjectItem != null
                    ? () => onSwitchProjectItem!(currentIndex - 1)
                    : null,
              ),

              SizedBox(width: compact ? 4 : 8),

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
                            size: compact ? 12 : 14,
                            color: Colors.amberAccent,
                          ),
                          SizedBox(width: compact ? 4 : 6),
                        ],
                        Flexible(
                          child: Text(
                            currentItem?.fileName ?? projectBundle.projectName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: compact ? 11 : 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 1 : 2),
                    Text(
                      '${currentIndex + 1} / $total  •  ${projectBundle.projectName}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: compact ? 9.5 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: compact ? 4 : 8),

              // Next Button
              IconButton(
                icon: Icon(Icons.skip_next_rounded, size: compact ? 20 : 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.nextProjectItem,
                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                constraints: compact ? const BoxConstraints(minWidth: 30, minHeight: 30) : const BoxConstraints(),
                onPressed: currentIndex < total - 1 && onSwitchProjectItem != null
                    ? () => onSwitchProjectItem!(currentIndex + 1)
                    : null,
              ),

              if (onExit != null) ...[
                Container(
                  height: compact ? 18 : 24,
                  width: 1,
                  margin: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
                  color: Colors.white24,
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: compact ? 18 : 22),
                  color: Colors.white70,
                  tooltip: 'Exit Presentation',
                  visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                  padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  constraints: compact ? const BoxConstraints(minWidth: 26, minHeight: 26) : const BoxConstraints(),
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
