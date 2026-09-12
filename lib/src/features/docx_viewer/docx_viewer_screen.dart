import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/reading_progress_service.dart';
import 'models/docx_models.dart';
import 'parser/docx_parser.dart';
import '../../core/widgets/viewer_loading_screen.dart';
import '../../core/l10n/l10n_extensions.dart';

/// Microsoft Word Document (.docx) Viewer Screen with 1:1 A4 Page Formatting,
/// Authentic Page Framing, Logo Header, Tab Stops, Exact Borders, and Zoom Slider.
class DocxViewerScreen extends StatefulWidget {
  final String filePath;

  const DocxViewerScreen({super.key, required this.filePath});

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  DocxDocument? _document;
  double _zoomScale = 1.0;
  bool _hasCalculatedInitialFit = false;
  bool _isZoomBarExpanded = false;
  bool _isSinglePageMode = false;
  bool _isSinglePageZoomed = false;
  TapDownDetails? _continuousDoubleTapDetails;
  bool _isFullscreen = false;
  int _currentPageIndex = 0;
  late PageController _docxPageController;

  // Bookmarks & Reading Progress
  bool _isCurrentBookmarked = false;
  List<BookmarkItem> _bookmarks = [];

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _searchMatchCount = 0;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final TransformationController _continuousTransformationController = TransformationController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _docxPageController = PageController(initialPage: _currentPageIndex);
    _loadDocxFile();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _saveReadingProgress();
    _docxPageController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _continuousTransformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  Future<void> _loadDocxFile() async {
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
      final bytes = await file.readAsBytes();

      final doc = DocxParser.parse(bytes);

      // Restore saved reading progress
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      int restoredPage = 0;
      if (progress != null && doc.pages.isNotEmpty) {
        restoredPage = (progress.page - 1).clamp(0, doc.pages.length - 1);
        _bookmarks = progress.bookmarks;
      } else {
        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      }

      if (mounted) {
        setState(() {
          _document = doc;
          _currentPageIndex = restoredPage;
          _isLoading = false;
        });

        _docxPageController.dispose();
        _docxPageController = PageController(initialPage: restoredPage);
        _checkBookmarkStatus();

        if (restoredPage > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Resumed at Page ${restoredPage + 1} of ${doc.pages.length}'),
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
          _errorMessage = 'Error reading Word document: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _saveReadingProgress() {
    if (_document == null || _document!.pages.isEmpty) return;
    ReadingProgressService.saveProgress(
      widget.filePath,
      page: _currentPageIndex + 1,
      progressFraction: (_currentPageIndex + 1) / _document!.pages.length,
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
    if (_document == null || _document!.pages.isEmpty) return;
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
        snippet: '$_fileName - Page $pageNum of ${_document!.pages.length}',
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Bookmarks (${_bookmarks.length})',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _bookmarks.isEmpty
                            ? Center(
                                child: Text(
                                  'No bookmarks saved yet.\nTap the bookmark icon on any page.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _bookmarks.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final b = _bookmarks[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      child: Icon(Icons.bookmark, color: theme.colorScheme.primary, size: 18),
                                    ),
                                    title: Text(
                                      b.label,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      b.snippet,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
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

  void _goToPage(int pageIndex) {
    if (_document == null || pageIndex < 0 || pageIndex >= _document!.pages.length) return;
    setState(() {
      _currentPageIndex = pageIndex;
    });

    if (_isSinglePageMode) {
      if (_docxPageController.hasClients) {
        _docxPageController.jumpToPage(pageIndex);
      }
    }
    _saveReadingProgress();
    _checkBookmarkStatus();
  }

  void _calculateInitialFit(Size viewportSize) {
    if (_hasCalculatedInitialFit || _document == null) return;
    _hasCalculatedInitialFit = true;

    final settings = _document!.pageSettings;
    final double availW = math.max(200.0, viewportSize.width - 32.0);
    final double availH = math.max(300.0, viewportSize.height - 120.0);

    final double scaleW = availW / settings.widthPt;
    final double scaleH = availH / settings.heightPt;

    final double fitScale = math.min(scaleW, scaleH).clamp(0.35, 2.5);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _zoomScale = fitScale;
        });
      }
    });
  }

  void _fitPage(Size viewportSize) {
    if (_document == null) return;
    _continuousTransformationController.value = Matrix4.identity();
    final settings = _document!.pageSettings;
    final double availW = math.max(200.0, viewportSize.width - 32.0);
    final double availH = math.max(300.0, viewportSize.height - 120.0);

    final double scaleW = availW / settings.widthPt;
    final double scaleH = availH / settings.heightPt;
    setState(() {
      _zoomScale = math.min(scaleW, scaleH).clamp(0.3, 3.0);
    });
  }

  void _fitWidth(Size viewportSize) {
    if (_document == null) return;
    _continuousTransformationController.value = Matrix4.identity();
    final settings = _document!.pageSettings;
    final double availW = math.max(200.0, viewportSize.width - 32.0);
    setState(() {
      _zoomScale = (availW / settings.widthPt).clamp(0.3, 3.0);
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _calculateSearchMatches();
    });
  }

  void _calculateSearchMatches() {
    if (_document == null || _searchQuery.isEmpty) {
      _searchMatchCount = 0;
      return;
    }
    final q = _searchQuery.toLowerCase();
    int count = 0;
    for (final block in _document!.blocks) {
      if (block is DocxParagraph) {
        if (block.plainText.toLowerCase().contains(q)) {
          count++;
        }
      } else if (block is DocxTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            if (cell.plainText.toLowerCase().contains(q)) {
              count++;
            }
          }
        }
      }
    }
    _searchMatchCount = count;
  }

  void _showInfoSheet() {
    if (_document == null) return;
    final theme = Theme.of(context);
    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    final settings = _document!.pageSettings;
    final orientationStr = settings.isLandscape ? 'Landscape' : 'Portrait';
    final paperStr = '${settings.paperName} $orientationStr (${settings.widthPt.toStringAsFixed(0)} × ${settings.heightPt.toStringAsFixed(0)} pt)';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
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
                          color: const Color(0xFF2B579A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.article_rounded, color: Color(0xFF2B579A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Word Document • Properties',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                  _buildInfoRow('File Name:', _fileName),
                  _buildInfoRow('File Size:', formattedSize),
                  _buildInfoRow('Page Format:', paperStr),
                  _buildInfoRow('Pages / Sheets:', '${_document!.pages.length}'),
                  _buildInfoRow('Paragraphs:', '${_document!.paragraphCount}'),
                  _buildInfoRow('Tables:', '${_document!.tableCount}'),
                  _buildInfoRow('Estimated Words:', '${_document!.wordCount} words'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _copyAllText() {
    if (_document == null) return;
    final buffer = StringBuffer();
    for (final block in _document!.blocks) {
      if (block is DocxParagraph) {
        buffer.writeln(block.plainText);
      } else if (block is DocxTable) {
        for (final row in block.rows) {
          buffer.writeln(row.cells.map((c) => c.plainText).join('\t'));
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document text copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final l10n = context.l10n;
      return ViewerLoadingScreen(
        fileName: _fileName,
        fileSizeBytes: _fileSizeBytes > 0 ? _fileSizeBytes : null,
        icon: Icons.description_rounded,
        accentColor: const Color(0xFF2B579A),
        loadingTitle: l10n.loadingWordDoc,
        statusMessage: l10n.statusParsingWord,
        onCancel: () => Navigator.of(context).pop(false),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final viewerBg = isDark ? const Color(0xFF141414) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: viewerBg,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: theme.colorScheme.surface,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _saveReadingProgress();
                  Navigator.of(context).pop(true);
                },
              ),
              // Row 1: Document Title & Page subtitle
              title: _isSearchOpen
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search in document...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_document != null && _document!.pages.isNotEmpty)
                          Text(
                            'Page ${_currentPageIndex + 1} of ${_document!.pages.length} • ${_isSinglePageMode ? "Single Page" : "Continuous"}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
              actions: const [],
              // Row 2: Action commands (horizontally scrollable, no overflow)
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // View Mode Toggle (Single Page vs Continuous Scroll)
                        IconButton(
                          icon: Icon(
                            _isSinglePageMode ? Icons.view_carousel_outlined : Icons.view_stream_outlined,
                            size: 20,
                          ),
                          tooltip: _isSinglePageMode
                              ? 'Single Page Mode (Tap for Continuous)'
                              : 'Continuous Mode (Tap for Single Page)',
                          onPressed: () {
                            setState(() {
                              _isSinglePageMode = !_isSinglePageMode;
                            });
                            if (_isSinglePageMode) {
                              _docxPageController.dispose();
                              _docxPageController = PageController(initialPage: _currentPageIndex);
                            }
                          },
                        ),

                        // Search Action
                        IconButton(
                          icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: _isSearchOpen ? 'Close Search' : 'Search in Document',
                          onPressed: () {
                            setState(() {
                              _isSearchOpen = !_isSearchOpen;
                              if (!_isSearchOpen) {
                                _searchController.clear();
                                _onSearchChanged('');
                              }
                            });
                          },
                        ),

                        // Bookmark Toggle
                        IconButton(
                          icon: Icon(
                            _isCurrentBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            size: 20,
                            color: _isCurrentBookmarked ? theme.colorScheme.primary : null,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: _isCurrentBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                          onPressed: _toggleBookmark,
                        ),

                        // Bookmarks List
                        IconButton(
                          icon: const Icon(Icons.bookmarks_outlined, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: 'Saved Bookmarks',
                          onPressed: _showBookmarksSheet,
                        ),

                        // Fullscreen Toggle
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: 'Fullscreen',
                          onPressed: _toggleFullscreen,
                        ),

                        // Copy All
                        IconButton(
                          icon: const Icon(Icons.copy_all_outlined, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: 'Copy Document Text',
                          onPressed: _copyAllText,
                        ),

                        // Info / Properties
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: 'Document Properties',
                          onPressed: _showInfoSheet,
                        ),

                        // Share
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          tooltip: 'Share',
                          onPressed: _shareFile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2B579A)),
                  SizedBox(height: 16),
                  Text('Loading Word Document...'),
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
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDocxFile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                    _calculateInitialFit(viewportSize);

                    final docSheetW = (_document != null ? _document!.pageSettings.widthPt * _zoomScale : 595.0) + 32.0;

                    return Stack(
                      children: [
                        _isSinglePageMode
                            ? PageView.builder(
                                controller: _docxPageController,
                                itemCount: _document!.pages.length,
                                physics: _isSinglePageZoomed
                                    ? const NeverScrollableScrollPhysics()
                                    : const PageScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentPageIndex = index;
                                    _isSinglePageZoomed = false;
                                  });
                                  _saveReadingProgress();
                                  _checkBookmarkStatus();
                                },
                                itemBuilder: (context, index) {
                                  return DocxSinglePageItem(
                                    key: ValueKey('docx_page_$index'),
                                    onZoomChanged: (zoom) {
                                      if (_currentPageIndex == index && mounted) {
                                        final isZoomed = zoom > 1.05;
                                        if (isZoomed != _isSinglePageZoomed) {
                                          setState(() {
                                            _isSinglePageZoomed = isZoomed;
                                          });
                                        }
                                      }
                                    },
                                    onLeftTap: () {
                                      if (_currentPageIndex > 0 && _docxPageController.hasClients) {
                                        _docxPageController.previousPage(
                                          duration: const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                        );
                                      }
                                    },
                                    onRightTap: () {
                                      if (_document != null && _currentPageIndex < _document!.pages.length - 1 && _docxPageController.hasClients) {
                                        _docxPageController.nextPage(
                                          duration: const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                        );
                                      }
                                    },
                                    onCenterTap: _toggleFullscreen,
                                    child: _buildDocxSinglePageWidget(index, theme, isDark),
                                  );
                                },
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTapDown: (details) => _continuousDoubleTapDetails = details,
                                onDoubleTap: () {
                                  if (_continuousTransformationController.value.getMaxScaleOnAxis() > 1.05) {
                                    _continuousTransformationController.value = Matrix4.identity();
                                  } else {
                                    final pos = _continuousDoubleTapDetails?.localPosition ?? Offset(viewportSize.width / 2, viewportSize.height / 2);
                                    const scale = 1.75;
                                    final matrix = Matrix4.identity();
                                    matrix.setEntry(0, 0, scale);
                                    matrix.setEntry(1, 1, scale);
                                    matrix.setEntry(0, 3, pos.dx * (1 - scale));
                                    matrix.setEntry(1, 3, pos.dy * (1 - scale));
                                    _continuousTransformationController.value = matrix;
                                  }
                                },
                                child: InteractiveViewer(
                                  transformationController: _continuousTransformationController,
                                  panEnabled: true,
                                  scaleEnabled: true,
                                  minScale: 0.5,
                                  maxScale: 4.0,
                                  constrained: false,
                                  boundaryMargin: const EdgeInsets.symmetric(vertical: 100, horizontal: 80),
                                  child: SizedBox(
                                    width: math.max(viewportSize.width, docSheetW),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: _buildPages(theme, isDark),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                        // Search Match Bar
                        if (_searchQuery.isNotEmpty)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, size: 16, color: Color(0xFFF57C00)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Found $_searchMatchCount ${_searchMatchCount == 1 ? "match" : "matches"} for "$_searchQuery"',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF57C00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Floating Exit Fullscreen Button
                        if (_isFullscreen)
                          Positioned(
                            top: MediaQuery.paddingOf(context).top + 12,
                            right: 16,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _toggleFullscreen,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.black87 : Colors.white.withValues(alpha: 0.9)),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.fullscreen_exit,
                                    size: 22,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Floating Zoom Control Bar (Offset above system safe area)
                        Positioned(
                          bottom: 16 + MediaQuery.paddingOf(context).bottom,
                          right: 16,
                          child: _buildZoomControls(theme, viewportSize),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  /// Builds authentic 1:1 A4 Paper Sheet widgets for all document pages.
  List<Widget> _buildPages(ThemeData theme, bool isDark) {
    if (_document == null) return [];
    return [
      for (int i = 0; i < _document!.pages.length; i++)
        _buildDocxSinglePageWidget(i, theme, isDark),
    ];
  }

  Widget _buildDocxSinglePageWidget(int i, ThemeData theme, bool isDark) {
    final settings = _document!.pageSettings;
    final sheetW = settings.widthPt * _zoomScale;
    final sheetH = settings.heightPt * _zoomScale;
    final sheetPadding = settings.margins * _zoomScale;

    final docBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final docBorderColor = isDark ? const Color(0xFF383838) : const Color(0xFFCBD5E1);
    final page = _document!.pages[i];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1:1 Paper Sheet Container with Page Framing Canvas
          Container(
            width: sheetW,
            constraints: BoxConstraints(minHeight: sheetH),
            decoration: BoxDecoration(
              color: docBg,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: docBorderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _DocxPageShapePainter(
                shapes: settings.pageShapes,
                zoomScale: _zoomScale,
              ),
              child: Padding(
                padding: sheetPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildPageBlocks(page.blocks, theme, isDark),
                ),
              ),
            ),
          ),

          // Page footer tag
          if (_document!.pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Page ${i + 1} of ${_document!.pages.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPageBlocks(List<DocxBlock> blocks, ThemeData theme, bool isDark) {
    if (blocks.isEmpty) {
      return [const Text('Page is empty.')];
    }

    final List<Widget> widgets = [];
    for (final block in blocks) {
      if (block is DocxParagraph) {
        widgets.add(_buildParagraphWidget(block, theme, isDark));
      } else if (block is DocxTable) {
        widgets.add(_buildTableWidget(block, theme, isDark));
      } else if (block is DocxHeaderBox) {
        widgets.add(_buildHeaderBoxWidget(block, theme, isDark));
      } else if (block is DocxImageBlock) {
        widgets.add(_buildImageBlockWidget(block));
      }
    }
    return widgets;
  }

  Widget _buildHeaderBoxWidget(DocxHeaderBox headerBox, ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white70 : const Color(0xFF1E293B);

    return Padding(
      padding: EdgeInsets.only(bottom: 12.0 * _zoomScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              if (headerBox.logoBytes != null)
                Padding(
                  padding: EdgeInsets.only(right: 14.0 * _zoomScale),
                  child: Image.memory(
                    headerBox.logoBytes!,
                    width: (headerBox.logoWidthPt ?? 85.0) * _zoomScale,
                    height: (headerBox.logoHeightPt ?? 65.0) * _zoomScale,
                    fit: BoxFit.contain,
                  ),
                ),

              // Company Header Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: headerBox.headerLines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    final isMainTitle = index == 0;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 1.5 * _zoomScale),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: (isMainTitle ? 13.0 : 10.5) * _zoomScale,
                          fontWeight: isMainTitle ? FontWeight.bold : FontWeight.w500,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageBlockWidget(DocxImageBlock block) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0 * _zoomScale),
      child: Align(
        alignment: block.alignment,
        child: Image.memory(
          block.imageBytes,
          width: block.widthPt != null ? block.widthPt! * _zoomScale : null,
          height: block.heightPt != null ? block.heightPt! * _zoomScale : null,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildParagraphWidget(
    DocxParagraph paragraph,
    ThemeData theme,
    bool isDark, {
    bool isInsideCell = false,
  }) {
    // If paragraph contains a HeaderBox (Logo + Company details)
    if (paragraph.headerBox != null) {
      return _buildHeaderBoxWidget(paragraph.headerBox!, theme, isDark);
    }

    // Check if paragraph has tabs (e.g. "ЧАСТ:" -> <tab> -> "ФАЗА: технически проект")
    final hasTabs = paragraph.runs.any((r) => r.isTab);

    Widget content;
    if (hasTabs) {
      content = _buildTabbedParagraph(paragraph, theme, isDark);
    } else {
      final spans = <InlineSpan>[];
      for (final run in paragraph.runs) {
        if (run.isTab) continue;
        final baseSize = run.fontSize ?? _getBaseFontSizeForHeading(paragraph.headingLevel);
        final scaledSize = (baseSize * _zoomScale).clamp(6.0, 72.0);
        final isMatched = _searchQuery.isNotEmpty &&
            run.text.toLowerCase().contains(_searchQuery.toLowerCase());

        spans.add(
          TextSpan(
            text: run.text,
            style: TextStyle(
              fontSize: scaledSize,
              fontFamily: run.fontFamily,
              fontWeight: (run.isBold || paragraph.headingLevel != DocxHeadingLevel.none)
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: run.isUnderline
                  ? TextDecoration.underline
                  : run.isStrike
                      ? TextDecoration.lineThrough
                      : null,
              color: isMatched
                  ? Colors.black87
                  : run.color ?? (isDark ? Colors.white70 : Colors.black87),
              backgroundColor: isMatched ? const Color(0xFFFFD54F) : null,
              height: paragraph.lineSpacing ?? (isInsideCell ? 1.15 : 1.25),
            ),
          ),
        );
      }

      if (paragraph.runs.isEmpty) {
        content = SizedBox(height: (isInsideCell ? 0.0 : 12.0) * _zoomScale);
      } else {
        // Prepend first-line indent if present
        if (paragraph.indentFirstLine > 0 && !paragraph.isBullet && spans.isNotEmpty) {
          spans.insert(
            0,
            WidgetSpan(
              child: SizedBox(
                width: (paragraph.indentFirstLine * _zoomScale).clamp(0.0, 200.0),
              ),
            ),
          );
        }

        content = SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: paragraph.alignment,
          ),
        );
      }
    }

    // Bullet / List Item
    if (paragraph.isBullet) {
      final prefixText = paragraph.listPrefix != null ? '${paragraph.listPrefix}\t' : '-\t';
      
      final spans = <InlineSpan>[
        TextSpan(
          text: prefixText,
          style: TextStyle(
            fontSize: 12.0 * _zoomScale,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ];
      
      if (content is SizedBox) {
        final inner = content.child;
        if (inner is Text) {
          final span = inner.textSpan;
          if (span is TextSpan) {
            if (span.children != null) {
              spans.addAll(span.children!);
            } else if (span.text != null) {
              spans.add(TextSpan(text: span.text, style: span.style));
            }
          }
        }
      } else if (content is Text) {
        final span = content.textSpan;
        if (span is TextSpan) {
          if (span.children != null) {
            spans.addAll(span.children!);
          } else if (span.text != null) {
            spans.add(TextSpan(text: span.text, style: span.style));
          }
        }
      }
      
      content = SizedBox(
        width: double.infinity,
        child: Text.rich(
          TextSpan(children: spans),
          textAlign: paragraph.alignment,
        ),
      );
    }

    // Left & Right Indents
    if (paragraph.indentLeft > 0 || paragraph.indentRight > 0) {
      double paddingLeft = paragraph.indentLeft;
      if (paragraph.isBullet) {
        paddingLeft = math.max(0.0, paddingLeft - 18.0); // Subtract hanging indent so bullet aligns correctly
      }
      content = Padding(
        padding: EdgeInsets.only(
          left: (paddingLeft * _zoomScale).clamp(0.0, 450.0),
          right: (paragraph.indentRight * _zoomScale).clamp(0.0, 450.0),
        ),
        child: content,
      );
    }

    // Divider line below paragraph
    if (paragraph.bottomBorder != null && paragraph.bottomBorder!.hasBorder) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          SizedBox(height: 2.0 * _zoomScale),
          Container(
            height: (paragraph.bottomBorder!.width * _zoomScale).clamp(0.5, 4.0),
            color: paragraph.bottomBorder!.color,
          ),
        ],
      );
    }

    // Inside table cells, Word suppresses spaceBefore on first paragraphs and doesn't stack margins
    final topMargin = isInsideCell
        ? 0.0
        : (paragraph.spaceBefore * _zoomScale).clamp(0.0, 40.0);
    final bottomMargin = isInsideCell
        ? 0.0
        : (paragraph.spaceAfter * _zoomScale).clamp(0.0, 40.0);

    if (topMargin == 0.0 && bottomMargin == 0.0) {
      return content;
    }

    return Padding(
      padding: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
      child: content,
    );
  }

  Widget _buildTabbedParagraph(DocxParagraph paragraph, ThemeData theme, bool isDark) {
    final List<List<DocxRun>> segments = [[]];
    for (final run in paragraph.runs) {
      if (run.isTab) {
        segments.add([]);
      } else {
        segments.last.add(run);
      }
    }

    if (segments.length <= 1) {
      return SizedBox(
        width: double.infinity,
        child: Text(
          paragraph.plainText,
          textAlign: paragraph.alignment,
          style: TextStyle(fontSize: 12.0 * _zoomScale),
        ),
      );
    }

    final firstRuns = segments[0];
    final secondRuns = segments.sublist(1).expand((s) => s).toList();

    if (paragraph.tabPositions.isNotEmpty) {
      final tabPos = (paragraph.tabPositions.first * _zoomScale).clamp(30.0, 400.0);
      return SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: tabPos,
              child: Text.rich(
                TextSpan(
                  children: firstRuns.map((r) => _buildSpan(r, paragraph, isDark)).toList(),
                ),
                textAlign: paragraph.alignment,
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: secondRuns.map((r) => _buildSpan(r, paragraph, isDark)).toList(),
                ),
                textAlign: paragraph.alignment,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: firstRuns.map((r) => _buildSpan(r, paragraph, isDark)).toList(),
            ),
            textAlign: paragraph.alignment,
          ),
          SizedBox(width: 24.0 * _zoomScale),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: secondRuns.map((r) => _buildSpan(r, paragraph, isDark)).toList(),
              ),
              textAlign: paragraph.alignment,
            ),
          ),
        ],
      ),
    );
  }

  InlineSpan _buildSpan(DocxRun run, DocxParagraph paragraph, bool isDark) {
    final baseSize = run.fontSize ?? _getBaseFontSizeForHeading(paragraph.headingLevel);
    final scaledSize = (baseSize * _zoomScale).clamp(6.0, 72.0);
    final isMatched = _searchQuery.isNotEmpty &&
        run.text.toLowerCase().contains(_searchQuery.toLowerCase());

    return TextSpan(
      text: run.text,
      style: TextStyle(
        fontSize: scaledSize,
        fontFamily: run.fontFamily,
        fontWeight: (run.isBold || paragraph.headingLevel != DocxHeadingLevel.none)
            ? FontWeight.bold
            : FontWeight.normal,
        fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: run.isUnderline
            ? TextDecoration.underline
            : run.isStrike
                ? TextDecoration.lineThrough
                : null,
        color: isMatched
            ? Colors.black87
            : run.color ?? (isDark ? Colors.white70 : Colors.black87),
        backgroundColor: isMatched ? const Color(0xFFFFD54F) : null,
      ),
    );
  }

  double _getBaseFontSizeForHeading(DocxHeadingLevel level) {
    switch (level) {
      case DocxHeadingLevel.title:
        return 14.5;
      case DocxHeadingLevel.h1:
        return 16.0;
      case DocxHeadingLevel.h2:
        return 14.0;
      case DocxHeadingLevel.h3:
        return 13.0;
      case DocxHeadingLevel.h4:
      case DocxHeadingLevel.h5:
      case DocxHeadingLevel.h6:
      case DocxHeadingLevel.none:
        return 12.0;
    }
  }

  Widget _buildTableWidget(DocxTable table, ThemeData theme, bool isDark) {
    final settings = _document?.pageSettings ?? const DocxPageSettings();
    final defaultBorderColor = isDark ? const Color(0xFF555555) : const Color(0xFF94A3B8);

    final TableBorder? tableBorder = (table.borders != null && table.borders!.hasAnyBorder)
        ? table.borders!.toTableBorder(defaultColor: defaultBorderColor, zoomScale: _zoomScale)
        : null;

    final maxContentWidth = settings.contentWidthPt * _zoomScale;
    final double totalGrid = table.columnWidths.fold(0.0, (a, b) => a + b);

    // Determine exact or proportional table width
    double tableWidth;
    if (table.totalWidthPt != null && table.totalWidthPt! > 0) {
      tableWidth = (table.totalWidthPt! * _zoomScale).clamp(100.0, maxContentWidth);
    } else if (totalGrid > 0) {
      tableWidth = (totalGrid * _zoomScale).clamp(100.0, maxContentWidth);
    } else {
      tableWidth = maxContentWidth;
    }

    Map<int, TableColumnWidth>? columnWidthsMap;
    if (table.columnWidths.isNotEmpty) {
      if (totalGrid > 0) {
        columnWidthsMap = {};
        for (int c = 0; c < table.columnWidths.length; c++) {
          final fraction = table.columnWidths[c] / totalGrid;
          columnWidthsMap[c] = FlexColumnWidth(fraction);
        }
      }
    }

    final tableWidget = Table(
      columnWidths: columnWidthsMap,
      defaultColumnWidth: const FlexColumnWidth(),
      border: tableBorder,
      children: table.rows.map((row) {
        final rowMinHeight = row.heightPt != null ? (row.heightPt! * _zoomScale) : null;

        return TableRow(
          decoration: row.isHeader
              ? BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF1F5F9),
                )
              : null,
          children: row.cells.map((cell) {
            final cellPadding = (cell.padding ?? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5)) *
                _zoomScale;

            BoxDecoration? cellDecoration;
            Border? cellBorder;
            if (cell.borders != null) {
              final b = cell.borders!;
              final tSide = b.top?.toBorderSide(zoomScale: _zoomScale);
              final bSide = b.bottom?.toBorderSide(zoomScale: _zoomScale);
              final lSide = b.left?.toBorderSide(zoomScale: _zoomScale);
              final rSide = b.right?.toBorderSide(zoomScale: _zoomScale);

              if ((tSide != null && tSide != BorderSide.none) ||
                  (bSide != null && bSide != BorderSide.none) ||
                  (lSide != null && lSide != BorderSide.none) ||
                  (rSide != null && rSide != BorderSide.none)) {
                cellBorder = Border(
                  top: tSide ?? BorderSide.none,
                  bottom: bSide ?? BorderSide.none,
                  left: lSide ?? BorderSide.none,
                  right: rSide ?? BorderSide.none,
                );
              }
            }

            if (cell.backgroundColor != null || cellBorder != null) {
              cellDecoration = BoxDecoration(
                color: cell.backgroundColor,
                border: cellBorder,
              );
            }

            return Container(
              constraints: rowMinHeight != null
                  ? BoxConstraints(minHeight: rowMinHeight)
                  : null,
              decoration: cellDecoration,
              padding: cellPadding,
              alignment: cell.verticalAlignment,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: cell.paragraphs
                    .map((p) => _buildParagraphWidget(p, theme, isDark, isInsideCell: true))
                    .toList(),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );

    Widget result = SizedBox(
      width: tableWidth,
      child: tableWidget,
    );

    // Table Alignment
    if (table.alignment == TextAlign.center) {
      result = Center(child: result);
    } else if (table.alignment == TextAlign.right) {
      result = Align(alignment: Alignment.centerRight, child: result);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0 * _zoomScale),
      child: result,
    );
  }

  /// Floating Zoom Control Bar with Slider, [-]/[+], % badge, Fit-Page and Fit-Width.
  Widget _buildZoomControls(ThemeData theme, Size viewportSize) {
    if (!_isZoomBarExpanded) {
      return FloatingActionButton.small(
        heroTag: 'docx_zoom_btn',
        onPressed: () => setState(() => _isZoomBarExpanded = true),
        backgroundColor: theme.colorScheme.surface,
        child: Icon(Icons.zoom_in, color: theme.colorScheme.primary, size: 20),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom Out
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: l10n.zoomOut,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _zoomScale = (_zoomScale - 0.15).clamp(0.3, 3.0);
              });
            },
          ),

          // Zoom Slider
          SizedBox(
            width: 110,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _zoomScale.clamp(0.3, 3.0),
                min: 0.3,
                max: 3.0,
                onChanged: (val) {
                  _continuousTransformationController.value = Matrix4.identity();
                  setState(() {
                    _zoomScale = val;
                  });
                },
              ),
            ),
          ),

          // Zoom In
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: l10n.zoomIn,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              _continuousTransformationController.value = Matrix4.identity();
              setState(() {
                _zoomScale = (_zoomScale + 0.15).clamp(0.3, 3.0);
              });
            },
          ),

          const SizedBox(width: 4),

          // Zoom Percentage Badge (Tap to reset 100%)
          InkWell(
            onTap: () {
              _continuousTransformationController.value = Matrix4.identity();
              setState(() => _zoomScale = 1.0);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(_zoomScale * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Fit to Screen (Fit Page)
          IconButton(
            icon: const Icon(Icons.fit_screen, size: 18),
            tooltip: l10n.fitPage,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => _fitPage(viewportSize),
          ),

          // Fit Width
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 18),
            tooltip: l10n.fitWidth,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => _fitWidth(viewportSize),
          ),

          // Collapse Bar
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Minimize Controls',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isZoomBarExpanded = false),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for rendering VML/DrawingML page-level shapes (e.g. teal frame lines).
class _DocxPageShapePainter extends CustomPainter {
  final List<DocxDrawingShape> shapes;
  final double zoomScale;

  _DocxPageShapePainter({required this.shapes, required this.zoomScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (shapes.isEmpty) return;

    for (final shape in shapes) {
      if (shape.isLine) {
        final paint = Paint()
          ..color = shape.color
          ..strokeWidth = (shape.strokeWidth * zoomScale).clamp(0.8, 3.0)
          ..style = PaintingStyle.stroke;

        final p1 = Offset(shape.from.dx * zoomScale, shape.from.dy * zoomScale);
        final p2 = Offset(shape.to.dx * zoomScale, shape.to.dy * zoomScale);

        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DocxPageShapePainter oldDelegate) {
    return oldDelegate.shapes != shapes || oldDelegate.zoomScale != zoomScale;
  }
}

/// Single DOCX page item widget that manages zoom and enables pan only when scaled,
/// ensuring PageView horizontal swiping is smooth and responsive at normal scale.
class DocxSinglePageItem extends StatefulWidget {
  final Widget child;
  final ValueChanged<double>? onZoomChanged;
  final VoidCallback? onLeftTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onRightTap;

  const DocxSinglePageItem({
    super.key,
    required this.child,
    this.onZoomChanged,
    this.onLeftTap,
    this.onCenterTap,
    this.onRightTap,
  });

  @override
  State<DocxSinglePageItem> createState() => DocxSinglePageItemState();
}

class DocxSinglePageItemState extends State<DocxSinglePageItem> with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

  bool _panEnabled = false;
  double _currentScale = 1.0;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _animController.removeListener(_onAnimationTick);
    _animController.dispose();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (_matrixAnimation != null) {
      _transformationController.value = _matrixAnimation!.value;
    }
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    _currentScale = scale;
    final shouldEnablePan = scale > 1.05;
    if (shouldEnablePan != _panEnabled) {
      setState(() {
        _panEnabled = shouldEnablePan;
      });
    }
    widget.onZoomChanged?.call(scale);
  }

  void _onTapUp(TapUpDetails details) {
    if (_currentScale > 1.05) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final width = renderBox.size.width;
    final x = details.localPosition.dx;

    if (x < width * 0.25) {
      widget.onLeftTap?.call();
    } else if (x > width * 0.75) {
      widget.onRightTap?.call();
    } else {
      widget.onCenterTap?.call();
    }
  }

  void _animateToMatrix(Matrix4 target) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
  }

  void _onDoubleTap() {
    if (_animController.isAnimating) return;

    if (_currentScale > 1.05) {
      _animateToMatrix(Matrix4.identity());
    } else {
      final tapPos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final renderBox = context.findRenderObject() as RenderBox?;
      final size = renderBox?.size ?? MediaQuery.sizeOf(context);

      const targetScale = 2.5;
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, targetScale);
      matrix.setEntry(1, 1, targetScale);

      final targetDx = (tapPos.dx * (1 - targetScale)).clamp(size.width * (1 - targetScale), 0.0);
      final targetDy = (tapPos.dy * (1 - targetScale)).clamp(size.height * (1 - targetScale), 0.0);

      matrix.setEntry(0, 3, targetDx);
      matrix.setEntry(1, 3, targetDy);

      _animateToMatrix(matrix);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _onTapUp,
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: _panEnabled,
        scaleEnabled: true,
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

