import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import 'models/comic_models.dart';
import 'parser/comic_parser.dart';

/// Interactive Digital Comic Book & Manga Viewer Screen (.cbz, .cbr, .cbt).
/// Features LTR Western, RTL Manga, and Continuous Vertical Webtoon reading modes,
/// full-screen immersive canvas, thumbnail scrubbing, page jump, and metadata inspection.
class ComicViewerScreen extends StatefulWidget {
  final String filePath;

  const ComicViewerScreen({super.key, required this.filePath});

  @override
  State<ComicViewerScreen> createState() => _ComicViewerScreenState();
}

class _ComicViewerScreenState extends State<ComicViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  ComicBook? _comic;
  int _currentPageIndex = 0;
  ComicReadingMode _readingMode = ComicReadingMode.leftToRight;
  bool _showControls = true;
  bool _fitToWidth = true;

  late final PageController _pageController;
  final ScrollController _webtoonScrollController = ScrollController();
  final ScrollController _thumbnailScrollController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    _loadComic();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _webtoonScrollController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComic() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${widget.filePath}');
      }

      _fileSizeBytes = await file.length();
      final comic = await ComicParser.parseFromFile(widget.filePath);

      if (mounted) {
        setState(() {
          _comic = comic;
          if (comic.metadata.isManga) {
            _readingMode = ComicReadingMode.rightToLeft;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading comic book: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    if (_currentPageIndex != index) {
      setState(() {
        _currentPageIndex = index;
      });
      _scrollThumbnailToView(index);
    }
  }

  void _goToPage(int index) {
    if (_comic == null || index < 0 || index >= _comic!.pages.length) return;
    setState(() {
      _currentPageIndex = index;
    });
    if (_readingMode == ComicReadingMode.verticalContinuous) {
      // In webtoon mode, estimate scroll position
      if (_webtoonScrollController.hasClients) {
        final maxScroll = _webtoonScrollController.position.maxScrollExtent;
        final target = (maxScroll / _comic!.pages.length) * index;
        _webtoonScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    }
    _scrollThumbnailToView(index);
  }

  void _scrollThumbnailToView(int index) {
    if (!_thumbnailScrollController.hasClients) return;
    const itemWidth = 64.0;
    final targetOffset = (index * itemWidth) - 100.0;
    _thumbnailScrollController.animateTo(
      targetOffset.clamp(0.0, _thumbnailScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _showJumpToPageDialog() {
    if (_comic == null || _comic!.pageCount <= 1) return;
    final controller = TextEditingController(text: '${_currentPageIndex + 1}');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jump to Page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Page Number (1 - ${_comic!.pageCount})',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pageNum = int.tryParse(controller.text.trim());
                if (pageNum != null && pageNum >= 1 && pageNum <= _comic!.pageCount) {
                  Navigator.of(context).pop();
                  _goToPage(pageNum - 1);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _showInfoSheet() {
    if (_comic == null) return;
    final theme = Theme.of(context);
    final meta = _comic!.metadata;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Color(0xFFE11D48)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _fileName,
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Total Pages:', '${_comic!.pageCount} pages'),
              _buildInfoRow('File Archive Size:', formattedSize),
              if (meta.series != null && meta.series!.isNotEmpty)
                _buildInfoRow('Series:', meta.series!),
              if (meta.number != null && meta.number!.isNotEmpty)
                _buildInfoRow('Issue #:', meta.number!),
              if (meta.writer != null && meta.writer!.isNotEmpty)
                _buildInfoRow('Writer:', meta.writer!),
              if (meta.penciller != null && meta.penciller!.isNotEmpty)
                _buildInfoRow('Artist / Penciller:', meta.penciller!),
              if (meta.publisher != null && meta.publisher!.isNotEmpty)
                _buildInfoRow('Publisher:', meta.publisher!),
              if (meta.genre != null && meta.genre!.isNotEmpty)
                _buildInfoRow('Genre:', meta.genre!),
              if (meta.year != null)
                _buildInfoRow('Published:', '${meta.year}${meta.month != null ? "/${meta.month}" : ""}'),
              if (meta.summary != null && meta.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  meta.summary!,
                  style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodyMedium?.color),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_errorMessage != null) {
          RecentFilesService.removeRecentFile(widget.filePath);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _showControls
            ? AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_errorMessage != null) {
                      RecentFilesService.removeRecentFile(widget.filePath);
                    }
                    Navigator.of(context).pop(_errorMessage == null);
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _comic?.title ?? _fileName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_comic != null)
                      Text(
                        'Page ${_currentPageIndex + 1} of ${_comic!.pageCount} • ${_readingMode.shortLabel}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                  ],
                ),
                actions: [
                  // Reading Mode Menu
                  PopupMenuButton<ComicReadingMode>(
                    icon: const Icon(Icons.menu_book_rounded, size: 20),
                    tooltip: 'Reading Mode',
                    onSelected: (mode) {
                      setState(() {
                        _readingMode = mode;
                      });
                    },
                    itemBuilder: (context) => ComicReadingMode.values.map((mode) {
                      return PopupMenuItem<ComicReadingMode>(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(
                              mode == ComicReadingMode.verticalContinuous
                                  ? Icons.view_headline_rounded
                                  : mode == ComicReadingMode.rightToLeft
                                      ? Icons.keyboard_double_arrow_left_rounded
                                      : Icons.keyboard_double_arrow_right_rounded,
                              size: 18,
                              color: _readingMode == mode ? theme.colorScheme.primary : null,
                            ),
                            const SizedBox(width: 10),
                            Text(mode.label),
                            if (_readingMode == mode) ...[
                              const Spacer(),
                              Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  // Fit to Width toggle
                  IconButton(
                    icon: Icon(
                      _fitToWidth ? Icons.fit_screen : Icons.fullscreen,
                      size: 20,
                    ),
                    tooltip: _fitToWidth ? 'Fit to Width' : 'Fit to Page',
                    onPressed: () => setState(() => _fitToWidth = !_fitToWidth),
                  ),

                  // Jump to Page
                  IconButton(
                    icon: const Icon(Icons.pin_outlined, size: 20),
                    tooltip: 'Jump to Page',
                    onPressed: _showJumpToPageDialog,
                  ),

                  // Info
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    tooltip: 'Comic Info',
                    onPressed: _showInfoSheet,
                  ),

                  // Share
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share',
                    onPressed: _shareFile,
                  ),
                ],
              )
            : null,
        body: GestureDetector(
          onTap: _toggleControls,
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE11D48)),
                      SizedBox(height: 16),
                      Text('Opening Comic Book...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadComic,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _comic == null || _comic!.pages.isEmpty
                      ? const Center(child: Text('No pages found', style: TextStyle(color: Colors.white70)))
                      : Stack(
                          children: [
                            // Main Reader Surface
                            _readingMode == ComicReadingMode.verticalContinuous
                                ? _buildWebtoonView()
                                : _buildPagedView(),

                            // Bottom Controls Overlay
                            if (_showControls) _buildBottomControlsOverlay(theme),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildPagedView() {
    return PageView.builder(
      controller: _pageController,
      reverse: _readingMode == ComicReadingMode.rightToLeft,
      itemCount: _comic!.pageCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final page = _comic!.pages[index];
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: Image.memory(
              page.bytes,
              fit: _fitToWidth ? BoxFit.fitWidth : BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('Error loading page ${index + 1}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebtoonView() {
    return ListView.builder(
      controller: _webtoonScrollController,
      itemCount: _comic!.pageCount,
      itemBuilder: (context, index) {
        final page = _comic!.pages[index];
        return Image.memory(
          page.bytes,
          fit: BoxFit.fitWidth,
          errorBuilder: (ctx, err, stack) => Container(
            height: 200,
            color: Colors.black26,
            child: Center(
              child: Text('Page ${index + 1} Error', style: const TextStyle(color: Colors.white70)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControlsOverlay(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.85),
              Colors.black,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page Slider & Scrubber
            Row(
              children: [
                Text(
                  '${_currentPageIndex + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Expanded(
                  child: Slider(
                    value: _currentPageIndex.toDouble(),
                    min: 0,
                    max: (_comic!.pageCount - 1).toDouble(),
                    divisions: _comic!.pageCount > 1 ? _comic!.pageCount - 1 : 1,
                    activeColor: const Color(0xFFE11D48),
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      _goToPage(val.round());
                    },
                  ),
                ),
                Text(
                  '${_comic!.pageCount}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Thumbnail Strip
            SizedBox(
              height: 60,
              child: ListView.separated(
                controller: _thumbnailScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: _comic!.pageCount,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final page = _comic!.pages[index];
                  final isSelected = index == _currentPageIndex;
                  return GestureDetector(
                    onTap: () => _goToPage(index),
                    child: Container(
                      width: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE11D48) : Colors.white24,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        page.bytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
