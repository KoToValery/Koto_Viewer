import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/reading_progress_service.dart';
import 'models/comic_models.dart';
import 'parser/comic_parser.dart';
import 'widgets/comic_page_item.dart';

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
  ComicFitMode _fitMode = ComicFitMode.fitWidth;
  double _currentZoomScale = 1.0;
  bool _isCurrentPageZoomed = false;
  final Map<int, ComicPageController> _pageItemControllers = {};

  // Webtoon zoom controller
  final TransformationController _webtoonTransformController = TransformationController();
  TapDownDetails? _webtoonDoubleTapDetails;

  // Bookmarks & Reading Progress
  bool _isCurrentBookmarked = false;
  List<BookmarkItem> _bookmarks = [];

  late PageController _pageController;
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
    _saveReadingProgress();
    _pageController.dispose();
    _webtoonScrollController.dispose();
    _thumbnailScrollController.dispose();
    _webtoonTransformController.dispose();
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

      // Restore saved reading progress
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      int restoredPage = 0;
      if (progress != null) {
        restoredPage = (progress.page - 1).clamp(0, comic.pageCount - 1);
        _bookmarks = progress.bookmarks;
      } else {
        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      }

      if (mounted) {
        setState(() {
          _comic = comic;
          _currentPageIndex = restoredPage;
          if (comic.metadata.isManga) {
            _readingMode = ComicReadingMode.rightToLeft;
          }
          _isLoading = false;
        });

        _pageController.dispose();
        _pageController = PageController(initialPage: restoredPage);
        _checkBookmarkStatus();

        if (restoredPage > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Resumed at Page ${restoredPage + 1} of ${comic.pageCount}'),
                ),
              );
            }
          });
        }
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

  void _saveReadingProgress() {
    if (_comic == null || _comic!.pageCount == 0) return;
    ReadingProgressService.saveProgress(
      widget.filePath,
      page: _currentPageIndex + 1,
      progressFraction: (_currentPageIndex + 1) / _comic!.pageCount,
    );
  }

  Future<void> _checkBookmarkStatus() async {
    final bookmarked = await ReadingProgressService.isBookmarked(
      widget.filePath,
      page: _currentPageIndex + 1,
    );
    if (mounted) {
      setState(() {
        _isCurrentBookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_comic == null) return;
    final pageNum = _currentPageIndex + 1;

    if (_isCurrentBookmarked) {
      final existing = _bookmarks.firstWhere(
        (b) => b.page == pageNum,
        orElse: () => BookmarkItem(
          id: '',
          page: pageNum,
          label: '',
          snippet: '',
          createdAt: DateTime.now(),
        ),
      );
      if (existing.id.isNotEmpty) {
        await ReadingProgressService.removeBookmark(widget.filePath, existing.id);
      }
      _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      setState(() => _isCurrentBookmarked = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmark removed'),
          ),
        );
      }
    } else {
      final newBookmark = BookmarkItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        page: pageNum,
        label: 'Page $pageNum',
        snippet: '${_comic!.title} - Page $pageNum of ${_comic!.pageCount}',
        createdAt: DateTime.now(),
      );

      await ReadingProgressService.addBookmark(widget.filePath, newBookmark);
      _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      setState(() => _isCurrentBookmarked = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmarked Page $pageNum'),
          ),
        );
      }
    }
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.55,
                minChildSize: 0.3,
                maxChildSize: 0.85,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark, color: Color(0xFFE11D48)),
                            const SizedBox(width: 10),
                            Text(
                              'Bookmarks (${_bookmarks.length})',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Expanded(
                        child: _bookmarks.isEmpty
                            ? const Center(
                                child: Text(
                                  'No bookmarks saved yet.\nTap the bookmark icon on any page.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _bookmarks.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                                itemBuilder: (context, index) {
                                  final b = _bookmarks[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFE11D48).withValues(alpha: 0.2),
                                      child: const Icon(Icons.bookmark, color: Color(0xFFE11D48), size: 18),
                                    ),
                                    title: Text(
                                      b.label,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      b.snippet,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white54),
                                      onPressed: () async {
                                        await ReadingProgressService.removeBookmark(widget.filePath, b.id);
                                        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
                                        _checkBookmarkStatus();
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _goToPage(b.page - 1);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _onPageChanged(int index) {
    if (_currentPageIndex != index) {
      final prevIndex = _currentPageIndex;
      _pageItemControllers[prevIndex]?.resetZoom();

      setState(() {
        _currentPageIndex = index;
        _currentZoomScale = 1.0;
        _isCurrentPageZoomed = false;
      });
      _saveReadingProgress();
      _checkBookmarkStatus();
      _scrollThumbnailToView(index);
    }
  }

  void _goToPage(int index) {
    if (_comic == null || index < 0 || index >= _comic!.pages.length) return;
    final prevIndex = _currentPageIndex;
    _pageItemControllers[prevIndex]?.resetZoom();

    setState(() {
      _currentPageIndex = index;
      _currentZoomScale = 1.0;
      _isCurrentPageZoomed = false;
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

  void _goToPreviousPage() {
    if (_readingMode == ComicReadingMode.verticalContinuous) return;
    if (_readingMode == ComicReadingMode.rightToLeft) {
      // In RTL (Manga), the visual left advances to next page
      if (_comic != null && _currentPageIndex < _comic!.pageCount - 1 && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      // In LTR, visual left goes to previous page
      if (_currentPageIndex > 0 && _pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _goToNextPage() {
    if (_readingMode == ComicReadingMode.verticalContinuous) return;
    if (_readingMode == ComicReadingMode.rightToLeft) {
      // In RTL (Manga), visual right goes to previous page
      if (_currentPageIndex > 0 && _pageController.hasClients) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      // In LTR, visual right advances to next page
      if (_comic != null && _currentPageIndex < _comic!.pageCount - 1 && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _zoomIn() {
    if (_readingMode == ComicReadingMode.verticalContinuous) {
      final cur = _webtoonTransformController.value.getMaxScaleOnAxis();
      final target = (cur + 0.5).clamp(1.0, 4.0);
      _webtoonTransformController.value = Matrix4.diagonal3Values(target, target, 1.0);
      setState(() => _currentZoomScale = target);
    } else {
      _pageItemControllers[_currentPageIndex]?.zoomIn();
    }
  }

  void _zoomOut() {
    if (_readingMode == ComicReadingMode.verticalContinuous) {
      final cur = _webtoonTransformController.value.getMaxScaleOnAxis();
      final target = (cur - 0.5).clamp(1.0, 4.0);
      if (target <= 1.05) {
        _webtoonTransformController.value = Matrix4.identity();
        setState(() => _currentZoomScale = 1.0);
      } else {
        _webtoonTransformController.value = Matrix4.diagonal3Values(target, target, 1.0);
        setState(() => _currentZoomScale = target);
      }
    } else {
      _pageItemControllers[_currentPageIndex]?.zoomOut();
    }
  }

  void _resetZoom() {
    if (_readingMode == ComicReadingMode.verticalContinuous) {
      _webtoonTransformController.value = Matrix4.identity();
      setState(() => _currentZoomScale = 1.0);
    } else {
      _pageItemControllers[_currentPageIndex]?.resetZoom();
      setState(() {
        _currentZoomScale = 1.0;
        _isCurrentPageZoomed = false;
      });
    }
  }

  void _cycleFitMode() {
    setState(() {
      switch (_fitMode) {
        case ComicFitMode.fitWidth:
          _fitMode = ComicFitMode.fitPage;
          break;
        case ComicFitMode.fitPage:
          _fitMode = ComicFitMode.fitHeight;
          break;
        case ComicFitMode.fitHeight:
          _fitMode = ComicFitMode.fitWidth;
          break;
      }
    });
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
                backgroundColor: Colors.black.withValues(alpha: 0.88),
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _saveReadingProgress();
                    if (_errorMessage != null) {
                      RecentFilesService.removeRecentFile(widget.filePath);
                    }
                    Navigator.of(context).pop(_errorMessage == null);
                  },
                ),
                // Row 1: Comic Title & Subtitle
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
                actions: const [],
                // Row 2: Command Actions Bar (horizontally scrollable, no overflow)
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(44),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.88),
                      border: const Border(
                        bottom: BorderSide(color: Colors.white12),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
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

                          // Fit Mode toggle
                          IconButton(
                            icon: Icon(
                              _fitMode == ComicFitMode.fitWidth
                                  ? Icons.fit_screen
                                  : _fitMode == ComicFitMode.fitPage
                                      ? Icons.fullscreen
                                      : Icons.swap_vert,
                              size: 20,
                            ),
                            tooltip: '${_fitMode.label} (Tap to change)',
                            onPressed: _cycleFitMode,
                          ),

                          // Jump to Page
                          IconButton(
                            icon: const Icon(Icons.pin_outlined, size: 20),
                            tooltip: 'Jump to Page',
                            onPressed: _showJumpToPageDialog,
                          ),

                          // Bookmark Toggle
                          IconButton(
                            icon: Icon(
                              _isCurrentBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              size: 20,
                              color: _isCurrentBookmarked ? const Color(0xFFE11D48) : null,
                            ),
                            tooltip: _isCurrentBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                            onPressed: _toggleBookmark,
                          ),

                          // View Bookmarks
                          IconButton(
                            icon: const Icon(Icons.bookmarks_outlined, size: 20),
                            tooltip: 'Saved Bookmarks',
                            onPressed: _showBookmarksSheet,
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
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: _isLoading
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

                          // Floating Zoom & Fit Bar
                          if (_showControls) _buildFloatingZoomBar(theme),

                          // Bottom Controls Overlay
                          if (_showControls) _buildBottomControlsOverlay(theme),
                        ],
                      ),
      ),
    );
  }

  Widget _buildPagedView() {
    return PageView.builder(
      controller: _pageController,
      reverse: _readingMode == ComicReadingMode.rightToLeft,
      itemCount: _comic!.pageCount,
      physics: _isCurrentPageZoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final page = _comic!.pages[index];
        return ComicPageItem(
          key: ValueKey('comic_page_$index'),
          page: page,
          fitMode: _fitMode,
          onZoomChanged: (scale) {
            if (_currentPageIndex == index && mounted) {
              final isZoomed = scale > 1.05;
              if (isZoomed != _isCurrentPageZoomed || (_currentZoomScale - scale).abs() > 0.05) {
                setState(() {
                  _isCurrentPageZoomed = isZoomed;
                  _currentZoomScale = scale;
                });
              }
            }
          },
          onLeftTap: _goToPreviousPage,
          onRightTap: _goToNextPage,
          onCenterTap: _toggleControls,
          onControllerCreated: (controller) {
            _pageItemControllers[index] = controller;
          },
          onControllerDisposed: () {
            _pageItemControllers.remove(index);
          },
        );
      },
    );
  }

  Widget _buildWebtoonView() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _webtoonDoubleTapDetails = details,
      onDoubleTap: () {
        if (_webtoonTransformController.value != Matrix4.identity()) {
          _webtoonTransformController.value = Matrix4.identity();
          setState(() => _currentZoomScale = 1.0);
        } else {
          final pos = _webtoonDoubleTapDetails?.localPosition ?? Offset.zero;
          const scale = 2.0;
          final matrix = Matrix4.identity();
          matrix.setEntry(0, 0, scale);
          matrix.setEntry(1, 1, scale);
          matrix.setEntry(0, 3, pos.dx * (1 - scale));
          matrix.setEntry(1, 3, pos.dy * (1 - scale));
          _webtoonTransformController.value = matrix;
          setState(() => _currentZoomScale = scale);
        }
      },
      onTap: _toggleControls,
      child: InteractiveViewer(
        transformationController: _webtoonTransformController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: true,
        scaleEnabled: true,
        boundaryMargin: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: ListView.builder(
          controller: _webtoonScrollController,
          itemCount: _comic!.pageCount,
          itemBuilder: (context, index) {
            final page = _comic!.pages[index];
            return Image.memory(
              page.bytes,
              fit: _fitMode.boxFit,
              errorBuilder: (ctx, err, stack) => Container(
                height: 200,
                color: Colors.black26,
                child: Center(
                  child: Text('Page ${index + 1} Error', style: const TextStyle(color: Colors.white70)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingZoomBar(ThemeData theme) {
    return Positioned(
      bottom: 148,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18, color: Colors.white),
              tooltip: 'Zoom Out',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: _currentZoomScale > 1.05 ? _zoomOut : null,
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: _resetZoom,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_currentZoomScale * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              tooltip: 'Zoom In',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: _currentZoomScale < 3.95 ? _zoomIn : null,
            ),
            Container(
              height: 18,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: Colors.white24,
            ),
            IconButton(
              icon: Icon(
                _fitMode == ComicFitMode.fitWidth
                    ? Icons.fit_screen
                    : _fitMode == ComicFitMode.fitPage
                        ? Icons.fullscreen
                        : Icons.swap_vert,
                size: 18,
                color: Colors.white,
              ),
              tooltip: '${_fitMode.label} (Tap to change)',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: _cycleFitMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlsOverlay(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
      ),
    );
  }
}
