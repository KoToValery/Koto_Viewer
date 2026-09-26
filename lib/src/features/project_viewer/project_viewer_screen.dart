import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/file_opener_service.dart';
import '../../core/services/project_bundle_service.dart';
import '../video_viewer/video_viewer_screen.dart';
import '../dxf_viewer/dxf_viewer_screen.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../dxf_3d_viewer/dxf_3d_viewer_screen.dart';
import '../image_viewer/image_viewer_screen.dart';
import '../../core/services/project_bundle_preload_service.dart';

/// Architectural Presentation Hub Screen for ZIP and .kpack project bundles.
/// Displays categorized project deliverables (Videos, DWG/DXF, 3D, PDF, Renders)
/// and allows smooth full-screen presentation to clients without leaving the app.
class ProjectViewerScreen extends StatefulWidget {
  final String filePath;
  final bool addToRecent;

  const ProjectViewerScreen({
    super.key,
    required this.filePath,
    this.addToRecent = true,
  });

  @override
  State<ProjectViewerScreen> createState() => _ProjectViewerScreenState();
}

class _ProjectViewerScreenState extends State<ProjectViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ProjectBundleInfo? _bundle;
  ProjectItemCategory _selectedCategory = ProjectItemCategory.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  @override
  void dispose() {
    ProjectBundlePreloadService.cancel();
    super.dispose();
  }

  Future<void> _loadBundle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await ProjectBundleService.inspectBundle(widget.filePath);
      if (mounted) {
        setState(() {
          _bundle = info;
          _isLoading = false;
        });
        ProjectBundlePreloadService.startPreloading(info);
      }
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectViewerScreen._loadBundle');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _openProjectItem(ProjectFileEntry item, int index, {bool replace = false}) async {
    if (_bundle == null) return;

    // Check if file is already extracted in cache
    final isCached = await ProjectBundleService.isFileExtracted(
      _bundle!.archivePath,
      item.internalPath,
    );

    BuildContext? dialogContext;
    if (!isCached && mounted) {
      // Show extraction progress dialog ONLY when extraction is genuinely needed
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.extractingFile(item.fileName),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.formattedSize,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    final String extractedPath;
    String? readyDwgPath;
    try {
      extractedPath = await ProjectBundleService.extractFile(
        _bundle!.archivePath,
        item.internalPath,
      );
      if (item.fileType == KotoFileType.dwg) {
        readyDwgPath = await ProjectBundlePreloadService.prioritizeAndConvert(
          _bundle!.archivePath,
          item,
        );
      }
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectViewerScreen.extractFile');
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop(); // Close progress dialog specifically
    }

    if (!mounted || !File(extractedPath).existsSync()) return;

    // Helper to switch project items from child viewers smoothly without losing path or presentation state
    void switchItem(int newIndex) {
      if (!mounted || _bundle == null) return;
      if (newIndex >= 0 && newIndex < _bundle!.files.length) {
        _openProjectItem(_bundle!.files[newIndex], newIndex, replace: true);
      }
    }

    // Route to appropriate viewer with full presentation context
    final Widget viewerWidget;
    if (item.category == ProjectItemCategory.video || item.fileType == KotoFileType.video) {
      viewerWidget = VideoViewerScreen(
        filePath: extractedPath,
        title: item.fileName,
        addToRecent: false,
        projectBundle: _bundle,
        currentProjectIndex: index,
        onSwitchProjectItem: switchItem,
      );
    } else if (item.category == ProjectItemCategory.image ||
        item.fileType == KotoFileType.image ||
        item.fileType == KotoFileType.ico ||
        item.fileType == KotoFileType.psd) {
      viewerWidget = ImageViewerScreen(
        filePath: extractedPath,
        projectBundle: _bundle,
        currentProjectIndex: index,
        onSwitchProjectItem: switchItem,
      );
    } else if (item.category == ProjectItemCategory.drawing &&
        (item.fileType == KotoFileType.dxf || item.fileType == KotoFileType.dwg)) {
      String dxfPath = extractedPath;
      String? origPath;
      if (item.fileType == KotoFileType.dwg) {
        origPath = extractedPath;
        dxfPath = readyDwgPath ?? extractedPath;
      }
      viewerWidget = DxfViewerScreen(
        filePath: dxfPath,
        title: item.fileName,
        originalFilePath: origPath,
        addToRecent: false,
        projectBundle: _bundle,
        currentProjectIndex: index,
        onSwitchProjectItem: switchItem,
      );
    } else if (item.fileType == KotoFileType.pdf ||
        (item.category == ProjectItemCategory.drawing && item.fileType == KotoFileType.pdf)) {
      viewerWidget = PdfViewerScreen(
        filePath: extractedPath,
        title: item.fileName,
        addToRecent: false,
        projectBundle: _bundle,
        currentProjectIndex: index,
        onSwitchProjectItem: switchItem,
      );
    } else if (item.category == ProjectItemCategory.model3d) {
      viewerWidget = Dxf3DViewerScreen(
        filePath: extractedPath,
        title: item.fileName,
        addToRecent: false,
        projectBundle: _bundle,
        currentProjectIndex: index,
        onSwitchProjectItem: switchItem,
      );
    } else {
      await FileOpenerService.openFile(
        context: context,
        filePath: extractedPath,
        addToRecent: false,
      );
      return;
    }

    if (!mounted) return;
    if (replace) {
      // Lightweight 180ms fade transition for slide replacement avoids heavy 3D route transitions
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => viewerWidget,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 180),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => viewerWidget),
      );
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  void _startPresentation() {
    if (_bundle != null && _bundle!.files.isNotEmpty) {
      _openProjectItem(_bundle!.files.first, 0);
    }
  }

  void _saveCurrentOrder() {
    if (_bundle == null) return;
    final paths = _bundle!.files.map((f) => f.internalPath).toList();
    ProjectBundleService.savePresentationOrder(_bundle!.archivePath, paths);
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_bundle == null) return;
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _bundle!.files.removeAt(oldIndex);
      _bundle!.files.insert(newIndex, item);
    });
    _saveCurrentOrder();
  }

  void _moveFilteredItem(ProjectFileEntry item, bool moveUp, List<ProjectFileEntry> currentFiltered) {
    if (_bundle == null) return;
    final files = _bundle!.files;
    final currentIndex = files.indexOf(item);
    if (currentIndex == -1) return;

    final filteredIndex = currentFiltered.indexOf(item);
    if (filteredIndex == -1) return;

    if (moveUp && filteredIndex > 0) {
      final prevItem = currentFiltered[filteredIndex - 1];
      setState(() {
        files.remove(item);
        final newPrevIndex = files.indexOf(prevItem);
        files.insert(newPrevIndex, item);
      });
      _saveCurrentOrder();
    } else if (!moveUp && filteredIndex < currentFiltered.length - 1) {
      final nextItem = currentFiltered[filteredIndex + 1];
      setState(() {
        files.remove(item);
        final newNextIndex = files.indexOf(nextItem);
        files.insert(newNextIndex + 1, item);
      });
      _saveCurrentOrder();
    }
  }

  void _groupByCategory() {
    if (_bundle == null) return;
    setState(() {
      ProjectBundleService.sortFilesByCategory(_bundle!.files);
    });
    _saveCurrentOrder();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Файловете са групирани по категории'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_bundle?.projectName ?? 'Project Presentation'),
        actions: [
          if (_bundle != null && _bundle!.files.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Групирай по категории',
              onPressed: _groupByCategory,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _startPresentation,
                icon: const Icon(Icons.slideshow_rounded, size: 20),
                label: Text(context.l10n.presentationMode),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(theme, isDark),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_rounded, color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load project bundle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadBundle,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(ThemeData theme, bool isDark) {
    final bundle = _bundle!;
    final filtered = bundle.files.where((f) {
      final matchesCategory = _selectedCategory == ProjectItemCategory.all || f.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || f.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
    final isAllTab = _selectedCategory == ProjectItemCategory.all && _searchQuery.isEmpty;

    return Column(
      children: [
        // Project Overview Banner
        _buildOverviewBanner(bundle, theme, isDark),

        // Category Filter Chips
        _buildCategoryTabs(bundle, theme),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search files in project...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
        ),

        // Reordering info strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAllTab
                      ? 'Подредете с влачене или със стрелките за презентацията'
                      : 'Преподреждане в категорията (засяга презентацията)',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isAllTab)
                TextButton.icon(
                  onPressed: _groupByCategory,
                  icon: const Icon(Icons.sort_rounded, size: 14),
                  label: const Text('По категории', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
            ],
          ),
        ),

        // Files List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                )
              : isAllTab
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      buildDefaultDragHandles: false,
                      onReorder: _onReorder,
                      itemCount: filtered.length,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          shadowColor: Colors.black45,
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final presentationIndex = bundle.files.indexOf(item);
                        return _buildFileItemCard(
                          item: item,
                          presentationIndex: presentationIndex,
                          listIndex: index,
                          totalInList: filtered.length,
                          theme: theme,
                          isDark: isDark,
                          isReorderable: true,
                          onMoveUp: index > 0 ? () => _moveFilteredItem(item, true, filtered) : null,
                          onMoveDown: index < filtered.length - 1 ? () => _moveFilteredItem(item, false, filtered) : null,
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final presentationIndex = bundle.files.indexOf(item);
                        return _buildFileItemCard(
                          item: item,
                          presentationIndex: presentationIndex,
                          listIndex: index,
                          totalInList: filtered.length,
                          theme: theme,
                          isDark: isDark,
                          isReorderable: false,
                          onMoveUp: index > 0 ? () => _moveFilteredItem(item, true, filtered) : null,
                          onMoveDown: index < filtered.length - 1 ? () => _moveFilteredItem(item, false, filtered) : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildOverviewBanner(ProjectBundleInfo bundle, ThemeData theme, bool isDark) {
    final totalMb = (bundle.totalSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_rounded, color: Colors.amber.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.projectName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bundle.totalFiles} assets • $totalMb MB total',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bundle.clientName != null && bundle.clientName!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Client: ${bundle.clientName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ProjectBundleInfo bundle, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ProjectItemCategory.values.map((cat) {
          final count = bundle.getCountByCategory(cat);
          if (cat != ProjectItemCategory.all && count == 0) return const SizedBox.shrink();

          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text('${cat.shortLabel} ($count)'),
              avatar: Icon(_getCategoryIcon(cat), size: 16),
              onSelected: (_) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(ProjectItemCategory cat) {
    switch (cat) {
      case ProjectItemCategory.all:
        return Icons.auto_awesome_mosaic_rounded;
      case ProjectItemCategory.video:
        return Icons.play_circle_fill_rounded;
      case ProjectItemCategory.drawing:
        return Icons.architecture_rounded;
      case ProjectItemCategory.model3d:
        return Icons.view_in_ar_rounded;
      case ProjectItemCategory.image:
        return Icons.photo_library_rounded;
      case ProjectItemCategory.document:
        return Icons.article_rounded;
      case ProjectItemCategory.other:
        return Icons.folder_rounded;
    }
  }

  Widget _buildFileItemCard({
    required ProjectFileEntry item,
    required int presentationIndex,
    required int listIndex,
    required int totalInList,
    required ThemeData theme,
    required bool isDark,
    required bool isReorderable,
    required VoidCallback? onMoveUp,
    required VoidCallback? onMoveDown,
  }) {
    final (iconData, iconColor) = _getFileVisuals(item);

    return Card(
      key: ValueKey(item.internalPath),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 10, right: 6, top: 2, bottom: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order number badge showing presentation sequence
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.amber.shade700.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${presentationIndex + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Category icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
          ],
        ),
        title: Text(
          item.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(item.formattedSize, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(width: 6),
            Text('•', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(width: 6),
            Text(
              item.category.shortLabel,
              style: TextStyle(fontSize: 11.5, color: iconColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
              tooltip: 'Премести нагоре',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onMoveUp,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward_rounded, size: 19),
              tooltip: 'Премести надолу',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onMoveDown,
            ),
            if (isReorderable)
              ReorderableDragStartListener(
                index: listIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _openProjectItem(item, presentationIndex),
      ),
    );
  }

  (IconData, Color) _getFileVisuals(ProjectFileEntry item) {
    switch (item.category) {
      case ProjectItemCategory.video:
        return (Icons.play_circle_filled_rounded, Colors.redAccent);
      case ProjectItemCategory.drawing:
        if (item.fileType == KotoFileType.pdf) {
          return (Icons.picture_as_pdf_rounded, Colors.red.shade700);
        }
        return (Icons.draw_rounded, Colors.teal);
      case ProjectItemCategory.model3d:
        return (Icons.view_in_ar_rounded, Colors.indigoAccent);
      case ProjectItemCategory.image:
        return (Icons.image_rounded, Colors.deepPurpleAccent);
      case ProjectItemCategory.document:
        return (Icons.description_rounded, Colors.blueAccent);
      case ProjectItemCategory.all:
      case ProjectItemCategory.other:
        return (Icons.insert_drive_file_rounded, Colors.blueGrey);
    }
  }
}
