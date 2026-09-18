import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/file_opener_service.dart';
import '../../core/services/project_bundle_service.dart';
import '../video_viewer/video_viewer_screen.dart';

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

  Future<void> _openProjectItem(ProjectFileEntry item, int index) async {
    if (_bundle == null) return;

    // Show extraction progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
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
      ),
    );

    final String extractedPath;
    try {
      extractedPath = await ProjectBundleService.extractFile(
        _bundle!.archivePath,
        item.internalPath,
      );
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectViewerScreen.extractFile');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not extract file: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Close progress dialog

    if (!File(extractedPath).existsSync()) return;

    // Route to appropriate viewer
    if (item.category == ProjectItemCategory.video || item.fileType == KotoFileType.video) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoViewerScreen(
            filePath: extractedPath,
            title: item.fileName,
            addToRecent: false,
            projectBundle: _bundle,
            currentProjectIndex: index,
            onSwitchProjectItem: (newIndex) {
              Navigator.of(context).pop();
              if (newIndex >= 0 && newIndex < _bundle!.files.length) {
                _openProjectItem(_bundle!.files[newIndex], newIndex);
              }
            },
          ),
        ),
      );
    } else {
      await FileOpenerService.openFile(
        context: context,
        filePath: extractedPath,
        addToRecent: false,
      );
    }
  }

  void _startPresentation() {
    if (_bundle != null && _bundle!.files.isNotEmpty) {
      _openProjectItem(_bundle!.files.first, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_bundle?.projectName ?? 'Project Presentation'),
        actions: [
          if (_bundle != null && _bundle!.files.isNotEmpty)
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

        // Files List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final originalIndex = bundle.files.indexOf(item);
                    return _buildFileItemCard(item, originalIndex, theme, isDark);
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

  Widget _buildFileItemCard(
    ProjectFileEntry item,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    final (iconData, iconColor) = _getFileVisuals(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          item.fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(item.formattedSize, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            Text('•', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            Text(
              item.category.shortLabel,
              style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: () => _openProjectItem(item, index),
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
