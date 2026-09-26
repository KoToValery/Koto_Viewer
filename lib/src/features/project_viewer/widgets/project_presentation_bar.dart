import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../../core/services/project_bundle_service.dart';

/// Reusable Presentation Navigation Bar displayed at the bottom of any viewer
/// during Project Presentation Mode.
///
/// Allows switching between architectural drawings, 3D models, renders,
/// and video walkthroughs with previous / next controls, project counters,
/// and an option to hide/skip or include the current file in the presentation.
class ProjectPresentationBar extends StatefulWidget {
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
  State<ProjectPresentationBar> createState() => _ProjectPresentationBarState();
}

class _ProjectPresentationBarState extends State<ProjectPresentationBar> {
  Future<void> _toggleCurrentItemHidden(ProjectFileEntry item) async {
    final newHidden = !item.isHidden;
    setState(() {
      item.isHidden = newHidden;
    });

    await ProjectBundleService.toggleFileHidden(
      widget.projectBundle.archivePath,
      item,
      newHidden,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newHidden
                ? context.l10n.fileHiddenNotification(item.fileName)
                : context.l10n.fileIncludedNotification(item.fileName),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.projectBundle.files.length;
    final currentItem = (widget.currentIndex >= 0 && widget.currentIndex < total)
        ? widget.projectBundle.files[widget.currentIndex]
        : null;
    final l10n = context.l10n;
    final isCurrentHidden = currentItem?.isHidden ?? false;
    final visibleFiles = widget.projectBundle.visibleFiles;

    final prevIndex = widget.projectBundle.getPreviousVisibleIndex(widget.currentIndex);
    final nextIndex = widget.projectBundle.getNextVisibleIndex(widget.currentIndex);

    final String counterText;
    if (isCurrentHidden) {
      counterText = '${l10n.fileSkippedInPresentation}  •  ${widget.projectBundle.projectName}';
    } else {
      final visiblePos = currentItem != null ? visibleFiles.indexOf(currentItem) + 1 : widget.currentIndex + 1;
      counterText = '$visiblePos / ${visibleFiles.length}  •  ${widget.projectBundle.projectName}';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.compact ? 8 : 12, sigmaY: widget.compact ? 8 : 12),
        child: Container(
          constraints: BoxConstraints(maxWidth: widget.compact ? 340 : 520),
          margin: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 16),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 12,
            vertical: widget.compact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xCC0F172A), // Dark slate with alpha
            borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
            border: Border.all(
              color: isCurrentHidden ? Colors.orangeAccent.withValues(alpha: 0.6) : Colors.white24,
              width: 1,
            ),
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
              // Previous Button (skips hidden files)
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, size: widget.compact ? 20 : 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.prevProjectItem,
                visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                constraints: widget.compact ? const BoxConstraints(minWidth: 30, minHeight: 30) : const BoxConstraints(),
                onPressed: prevIndex != null && widget.onSwitchProjectItem != null
                    ? () => widget.onSwitchProjectItem!(prevIndex)
                    : null,
              ),

              SizedBox(width: widget.compact ? 4 : 8),

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
                            size: widget.compact ? 12 : 14,
                            color: isCurrentHidden ? Colors.orangeAccent : Colors.amberAccent,
                          ),
                          SizedBox(width: widget.compact ? 4 : 6),
                        ],
                        Flexible(
                          child: Text(
                            currentItem?.fileName ?? widget.projectBundle.projectName,
                            style: TextStyle(
                              color: isCurrentHidden ? Colors.white70 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: widget.compact ? 11 : 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentHidden) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: Text(
                              l10n.hiddenInPresentation,
                              style: TextStyle(
                                color: Colors.orangeAccent.shade100,
                                fontSize: widget.compact ? 8.5 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: widget.compact ? 1 : 2),
                    Text(
                      counterText,
                      style: TextStyle(
                        color: isCurrentHidden
                            ? Colors.orangeAccent.shade100
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: widget.compact ? 9.5 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              SizedBox(width: widget.compact ? 4 : 8),

              // Next Button (skips hidden files)
              IconButton(
                icon: Icon(Icons.skip_next_rounded, size: widget.compact ? 20 : 26),
                color: Colors.white,
                disabledColor: Colors.white24,
                tooltip: l10n.nextProjectItem,
                visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                constraints: widget.compact ? const BoxConstraints(minWidth: 30, minHeight: 30) : const BoxConstraints(),
                onPressed: nextIndex != null && widget.onSwitchProjectItem != null
                    ? () => widget.onSwitchProjectItem!(nextIndex)
                    : null,
              ),

              // Hide / Include toggle button
              if (currentItem != null) ...[
                IconButton(
                  icon: Icon(
                    isCurrentHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: widget.compact ? 18 : 22,
                  ),
                  color: isCurrentHidden ? Colors.orangeAccent : Colors.white70,
                  tooltip: isCurrentHidden ? l10n.includeInPresentation : l10n.hideFromPresentation,
                  visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                  padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  constraints: widget.compact ? const BoxConstraints(minWidth: 28, minHeight: 28) : const BoxConstraints(),
                  onPressed: () => _toggleCurrentItemHidden(currentItem),
                ),
              ],

              if (widget.onExit != null) ...[
                Container(
                  height: widget.compact ? 18 : 24,
                  width: 1,
                  margin: EdgeInsets.symmetric(horizontal: widget.compact ? 2 : 4),
                  color: Colors.white24,
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: widget.compact ? 18 : 22),
                  color: Colors.white70,
                  tooltip: 'Exit Presentation',
                  visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
                  padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  constraints: widget.compact ? const BoxConstraints(minWidth: 26, minHeight: 26) : const BoxConstraints(),
                  onPressed: widget.onExit,
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
