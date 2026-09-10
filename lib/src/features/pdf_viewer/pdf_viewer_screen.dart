import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/reading_progress_service.dart';
import '../home/widgets/share_options_sheet.dart';
import '../../core/widgets/viewer_loading_screen.dart';
import 'models/pdf_reflow_models.dart';
import 'services/pdf_text_extractor_service.dart';
import 'widgets/pdf_reflow_view.dart';

/// PDF Document Viewer Screen with Single Page Mode (Swipe) and Continuous Scroll,
/// 2-row header navigation, reading progress auto-save & resume, bookmarks,
/// invert color mode, zoom slider, and Android system-safe UI.
class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const PdfViewerScreen({super.key, required this.filePath, this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  late final PdfDocumentRef _documentRef;
  late PageController _singlePageController;

  bool _isSinglePageMode = true;
  bool _isDarkModeView = false;
  int _pageCount = 0;
  int _currentPage = 1;
  String _fileName = '';
  int _fileSizeBytes = 0;
  bool get _isPresentation => _fileName.toLowerCase().endsWith('.pptx') || _fileName.toLowerCase().endsWith('.ppt');

  double _currentZoom = 1.0;
  bool _isZoomBarExpanded = false;
  bool _isFullscreen = false;

  // Bookmarks & Reading Progress
  bool _isCurrentBookmarked = false;
  List<BookmarkItem> _bookmarks = [];
  bool _hasRestoredPage = false;
  int? _savedPageToRestore;

  // Reflow / E-Book Reading Mode
  bool _isReflowMode = false;
  PdfReflowSettings _reflowSettings = const PdfReflowSettings();
  late final PdfTextExtractorService _textExtractorService;

  // Page zoom controllers for Single Page Mode
  final Map<int, TransformationController> _pageTransformControllers = {};

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _documentRef = PdfDocumentRefFile(widget.filePath);
    _singlePageController = PageController(initialPage: _currentPage - 1);
    _textExtractorService = PdfTextExtractorService(filePath: widget.filePath);
    _pdfController.addListener(_onControllerChanged);
    _loadProgressAndSaveRecent();
    _loadReflowSettings();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageTransformControllers.clear();
    _textExtractorService.clearMemoryCache();
    _saveReadingProgress();
    _pdfController.removeListener(_onControllerChanged);
    _singlePageController.dispose();
    super.dispose();
  }

  Future<void> _loadReflowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontSize = prefs.getDouble('pdf_reflow_font_size') ?? 17.0;
      final themeIndex = prefs.getInt('pdf_reflow_theme') ?? PdfReflowTheme.sepia.index;
      final fontIndex = prefs.getInt('pdf_reflow_font') ?? PdfReflowFont.serif.index;
      final isContinuous = prefs.getBool('pdf_reflow_is_continuous') ?? false;

      if (mounted) {
        setState(() {
          _reflowSettings = PdfReflowSettings(
            fontSize: fontSize.clamp(12.0, 32.0),
            theme: PdfReflowTheme.values.elementAtOrNull(themeIndex) ?? PdfReflowTheme.sepia,
            font: PdfReflowFont.values.elementAtOrNull(fontIndex) ?? PdfReflowFont.serif,
            isContinuous: isContinuous,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _saveReflowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('pdf_reflow_font_size', _reflowSettings.fontSize);
      await prefs.setInt('pdf_reflow_theme', _reflowSettings.theme.index);
      await prefs.setInt('pdf_reflow_font', _reflowSettings.font.index);
      await prefs.setBool('pdf_reflow_is_continuous', _reflowSettings.isContinuous);
    } catch (_) {}
  }

  Future<void> _loadProgressAndSaveRecent() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (mounted) {
          setState(() {
            _fileSizeBytes = size;
          });
        }
        final pdfItem = PdfItem(
          path: widget.filePath,
          name: _fileName,
          sizeInBytes: size,
          lastOpened: DateTime.now(),
        );
        await RecentFilesService.addRecentFile(pdfItem);
      }

      // Check saved reading progress
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      if (progress != null && progress.page > 0) {
        _savedPageToRestore = progress.page;
        _bookmarks = progress.bookmarks;
      } else {
        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      }
      _checkBookmarkStatus();
    } catch (_) {}
  }

  void _saveReadingProgress() {
    if (_pageCount <= 0) return;
    ReadingProgressService.saveProgress(
      widget.filePath,
      page: _currentPage,
      progressFraction: _currentPage / _pageCount,
    );
  }

  Future<void> _checkBookmarkStatus() async {
    final bookmarked = await ReadingProgressService.isBookmarked(
      widget.filePath,
      page: _currentPage,
    );
    if (mounted) {
      setState(() {
        _isCurrentBookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_pageCount <= 0) return;

    if (_isCurrentBookmarked) {
      final existing = _bookmarks.firstWhere(
        (b) => b.page == _currentPage,
        orElse: () => BookmarkItem(
          id: '',
          page: _currentPage,
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
        page: _currentPage,
        label: 'Page $_currentPage',
        snippet: '$_fileName - Page $_currentPage of $_pageCount',
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
            content: Text('Bookmarked Page $_currentPage'),
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
                                      _goToPage(b.page);
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

  void _showInfoSheet() async {
    final theme = Theme.of(context);
    int sizeBytes = 0;
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        sizeBytes = await file.length();
      }
    } catch (_) {}

    final formattedSize = sizeBytes < 1024 * 1024
        ? '${(sizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    if (!mounted) return;

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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF Document',
                              style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Total Pages:', '$_pageCount pages'),
                  _buildInfoRow('Current Page:', 'Page $_currentPage of $_pageCount'),
                  _buildInfoRow('File Size:', formattedSize),
                  _buildInfoRow('View Mode:', _isSinglePageMode ? 'Single Page (Swipe)' : 'Continuous Scroll'),
                  _buildInfoRow('File Path:', widget.filePath),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
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

  void _onControllerChanged() {
    if (!mounted || !_pdfController.isReady) return;
    try {
      final z = _pdfController.currentZoom;
      if ((z - _currentZoom).abs() > 0.02) {
        setState(() {
          _currentZoom = z;
        });
      }
    } catch (_) {}
  }

  void _goToPage(int page) {
    if (page < 1 || page > _pageCount) return;
    setState(() {
      _currentPage = page;
      _currentZoom = 1.0;
    });

    if (_isSinglePageMode) {
      _pageTransformControllers[_currentPage]?.value = Matrix4.identity();
      if (_singlePageController.hasClients) {
        _singlePageController.jumpToPage(page - 1);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _singlePageController.hasClients) {
            _singlePageController.jumpToPage(page - 1);
          }
        });
      }
    } else {
      if (_pdfController.isReady) {
        _pdfController.goToPage(pageNumber: page, anchor: PdfPageAnchor.center);
      }
    }

    _saveReadingProgress();
    _checkBookmarkStatus();
  }

  void _setSinglePageZoom(TransformationController controller, double newScale) {
    if (newScale <= 1.01) {
      controller.value = Matrix4.identity();
      setState(() {
        _currentZoom = 1.0;
      });
    } else {
      final size = MediaQuery.sizeOf(context);
      final dx = (size.width / 2) * (1 - newScale);
      final dy = (size.height / 2) * (1 - newScale);
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, newScale);
      matrix.setEntry(1, 1, newScale);
      matrix.setEntry(0, 3, dx);
      matrix.setEntry(1, 3, dy);
      controller.value = matrix;
      setState(() {
        _currentZoom = newScale;
      });
    }
  }

  void _fitCurrentPage() {
    if (_isSinglePageMode) {
      final controller = _pageTransformControllers[_currentPage];
      if (controller != null) {
        controller.value = Matrix4.identity();
        setState(() => _currentZoom = 1.0);
      }
    } else {
      if (!_pdfController.isReady) return;
      try {
        _pdfController.goToPage(pageNumber: _currentPage, anchor: PdfPageAnchor.center);
      } catch (_) {}
    }
  }

  void _onZoomSliderChanged(double newZoom) {
    if (_isSinglePageMode) {
      final controller = _pageTransformControllers[_currentPage];
      if (controller != null) {
        _setSinglePageZoom(controller, newZoom);
      }
    } else {
      if (!_pdfController.isReady) return;
      setState(() {
        _currentZoom = newZoom;
      });
      try {
        _pdfController.setZoom(_pdfController.centerPosition, newZoom);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    if (_isSinglePageMode) {
      final controller = _pageTransformControllers[_currentPage];
      if (controller != null) {
        final newZoom = (_currentZoom * 1.25).clamp(1.0, 4.0);
        _setSinglePageZoom(controller, newZoom);
      }
    } else {
      if (!_pdfController.isReady) return;
      final newZoom = (_currentZoom * 1.25).clamp(0.3, 4.0);
      _onZoomSliderChanged(newZoom);
    }
  }

  void _zoomOut() {
    if (_isSinglePageMode) {
      final controller = _pageTransformControllers[_currentPage];
      if (controller != null) {
        final newZoom = (_currentZoom / 1.25).clamp(1.0, 4.0);
        _setSinglePageZoom(controller, newZoom);
      }
    } else {
      if (!_pdfController.isReady) return;
      final newZoom = (_currentZoom / 1.25).clamp(0.3, 4.0);
      _onZoomSliderChanged(newZoom);
    }
  }

  void _sharePdf() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareOptionsSheet(filePath: widget.filePath),
    );
  }

  Future<void> _printPdf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing file: $e')),
        );
      }
    }
  }

  void _showJumpToPageDialog() {
    if (_pageCount <= 1) return;
    final controller = TextEditingController(text: _currentPage.toString());

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
              labelText: 'Page Number (1 - $_pageCount)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= _pageCount) {
                  _goToPage(page);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
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

  void _toggleViewMode() {
    setState(() {
      _isSinglePageMode = !_isSinglePageMode;
      _currentZoom = 1.0;
    });
    if (_isSinglePageMode) {
      _singlePageController.dispose();
      _singlePageController = PageController(initialPage: _currentPage - 1);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pdfController.isReady) {
          _pdfController.goToPage(pageNumber: _currentPage, anchor: PdfPageAnchor.center);
        }
      });
    }
  }

  void _toggleReflowMode() {
    setState(() {
      _isReflowMode = !_isReflowMode;
      _currentZoom = 1.0;
    });

    if (!_isReflowMode) {
      if (_isSinglePageMode) {
        _singlePageController.dispose();
        _singlePageController = PageController(initialPage: _currentPage - 1);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pdfController.isReady) {
            _pdfController.goToPage(pageNumber: _currentPage, anchor: PdfPageAnchor.center);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: (_isFullscreen || _pageCount == 0)
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
              // Row 1: PDF Title & Page Subtitle
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_pageCount > 0)
                    Text(
                      'Page $_currentPage of $_pageCount • ${_isReflowMode ? "Reading Mode (Reflow)" : (_isSinglePageMode ? "Single Page" : "Continuous")}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
              actions: const [],
              // Row 2: Actions Bar (horizontally scrollable, no overflow)
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Reading Mode / Reflow Toggle (E-Book Experience)
                        IconButton(
                          icon: Icon(
                            _isReflowMode ? Icons.auto_stories : Icons.auto_stories_outlined,
                            size: 20,
                            color: _isReflowMode ? theme.colorScheme.primary : null,
                          ),
                          tooltip: _isReflowMode
                              ? 'Exit Reading Mode (Back to Original PDF)'
                              : 'Reading Mode (Reflow / E-Book)',
                          onPressed: _toggleReflowMode,
                        ),

                        // View Mode Toggle (Single Page vs Continuous Scroll)
                        IconButton(
                          icon: Icon(
                            _isSinglePageMode ? Icons.view_carousel_outlined : Icons.view_stream_outlined,
                            size: 20,
                          ),
                          tooltip: _isSinglePageMode
                              ? 'Single Page Mode (Tap for Continuous)'
                              : 'Continuous Mode (Tap for Single Page)',
                          onPressed: _toggleViewMode,
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
                            color: _isCurrentBookmarked ? theme.colorScheme.primary : null,
                          ),
                          tooltip: _isCurrentBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                          onPressed: _toggleBookmark,
                        ),

                        // Bookmarks List
                        IconButton(
                          icon: const Icon(Icons.bookmarks_outlined, size: 20),
                          tooltip: 'Saved Bookmarks',
                          onPressed: _showBookmarksSheet,
                        ),

                        // Invert Mode (Dark/Light)
                        IconButton(
                          icon: Icon(_isDarkModeView ? Icons.light_mode : Icons.dark_mode, size: 20),
                          tooltip: 'Toggle Invert Colors',
                          onPressed: () {
                            setState(() {
                              _isDarkModeView = !_isDarkModeView;
                            });
                          },
                        ),

                        // Fullscreen
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 20),
                          tooltip: 'Fullscreen',
                          onPressed: _toggleFullscreen,
                        ),

                        // Info Sheet
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: 'PDF Properties',
                          onPressed: _showInfoSheet,
                        ),

                        // Share
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20),
                          tooltip: 'Share PDF',
                          onPressed: _sharePdf,
                        ),

                        // Print
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20),
                          tooltip: 'Print PDF',
                          onPressed: _printPdf,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: _isDarkModeView && !_isReflowMode
                ? const ColorFilter.matrix([
                    -1.0, 0.0, 0.0, 0.0, 255.0,
                    0.0, -1.0, 0.0, 0.0, 255.0,
                    0.0, 0.0, -1.0, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: _isReflowMode
                ? _buildReflowView()
                : (_isSinglePageMode
                    ? _buildSinglePageView()
                    : _buildContinuousView()),
          ),

          // Floating Zoom Controls (Offset above system safe area) - only in standard PDF mode
          if (!_isFullscreen && !_isReflowMode)
            Positioned(
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              right: 16,
              child: _buildZoomControls(theme),
            ),

          if (_isFullscreen)
            Positioned(
              top: 20,
              right: 20,
              child: FloatingActionButton.small(
                heroTag: 'exit_fullscreen_pdf',
                onPressed: _toggleFullscreen,
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: Icon(Icons.fullscreen_exit, color: theme.colorScheme.onSurface),
              ),
            ),

          // Modern Fullscreen Loading Overlay
          if (_pageCount == 0)
            Positioned.fill(
              child: ViewerLoadingScreen(
                fileName: _fileName,
                fileSizeBytes: _fileSizeBytes > 0 ? _fileSizeBytes : null,
                icon: _isPresentation ? Icons.slideshow_rounded : Icons.picture_as_pdf_rounded,
                accentColor: _isPresentation ? const Color(0xFFD24726) : const Color(0xFFE53935),
                loadingTitle: _isPresentation ? 'Loading presentation...' : 'Loading PDF document...',
                statusMessage: 'Preparing and analyzing pages...',
                onCancel: () => Navigator.of(context).pop(false),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_isFullscreen || _pageCount == 0)
          ? null
          : SafeArea(
              child: BottomAppBar(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page),
                      tooltip: 'First Page',
                      onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous Page',
                      onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                    ),
                    GestureDetector(
                      onTap: _showJumpToPageDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_currentPage / $_pageCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next Page',
                      onPressed: _currentPage < _pageCount ? () => _goToPage(_currentPage + 1) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page),
                      tooltip: 'Last Page',
                      onPressed: _currentPage < _pageCount ? () => _goToPage(_pageCount) : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Reading Mode (Reflow): Responsive e-book experience with OCR support for scanned pages
  Widget _buildReflowView() {
    return PdfDocumentViewBuilder(
      documentRef: _documentRef,
      builder: (context, document) {
        if (document == null) {
          return ViewerLoadingScreen(
            fileName: _fileName,
            fileSizeBytes: _fileSizeBytes > 0 ? _fileSizeBytes : null,
            icon: Icons.auto_stories,
            accentColor: const Color(0xFF2563EB),
            loadingTitle: 'Loading document for reading...',
            statusMessage: 'Extracting and preparing pages...',
            onCancel: () => Navigator.of(context).pop(false),
          );
        }

        if (_pageCount != document.pages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pageCount = document.pages.length;
              });
            }
          });
        }

        return PdfReflowView(
          document: document,
          currentPage: _currentPage,
          onPageChanged: (newPage) {
            if (_currentPage == newPage || !mounted) return;
            void update() {
              if (mounted && _currentPage != newPage) {
                setState(() {
                  _currentPage = newPage;
                });
                _saveReadingProgress();
                _checkBookmarkStatus();
              }
            }

            if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
              WidgetsBinding.instance.addPostFrameCallback((_) => update());
            } else {
              update();
            }
          },
          onToggleControls: _toggleFullscreen,
          onExitReflow: () {
            setState(() {
              _isReflowMode = false;
            });
          },
          extractorService: _textExtractorService,
          settings: _reflowSettings,
          onSettingsChanged: (newSettings) {
            setState(() {
              _reflowSettings = newSettings;
            });
            _saveReflowSettings();
          },
        );
      },
    );
  }

  /// Single Page Mode: Exactly 1 page on screen with swipe page-turning and pinch-to-zoom
  Widget _buildSinglePageView() {
    return PdfDocumentViewBuilder(
      documentRef: _documentRef,
      builder: (context, document) {
        if (document == null) {
          return ViewerLoadingScreen(
            fileName: _fileName,
            fileSizeBytes: _fileSizeBytes > 0 ? _fileSizeBytes : null,
            icon: _isPresentation ? Icons.slideshow_rounded : Icons.picture_as_pdf_rounded,
            accentColor: _isPresentation ? const Color(0xFFD24726) : const Color(0xFFE53935),
            loadingTitle: _isPresentation ? 'Loading presentation...' : 'Loading PDF document...',
            statusMessage: 'Preparing and analyzing pages...',
            onCancel: () => Navigator.of(context).pop(false),
          );
        }

        if (_pageCount != document.pages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _pageCount = document.pages.length;
              });

              // Restore saved page
              if (!_hasRestoredPage && _savedPageToRestore != null) {
                _hasRestoredPage = true;
                final restoreTo = _savedPageToRestore!.clamp(1, _pageCount);
                if (restoreTo > 1) {
                  _goToPage(restoreTo);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      content: Text('Resumed at Page $restoreTo of $_pageCount'),
                    ),
                  );
                }
              }
            }
          });
        }

        return PageView.builder(
          controller: _singlePageController,
          itemCount: document.pages.length,
          physics: _currentZoom > 1.05
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (index) {
            final newPage = index + 1;
            if (_currentPage == newPage) return;
            final prevPage = _currentPage;
            _pageTransformControllers[prevPage]?.value = Matrix4.identity();
            setState(() {
              _currentPage = newPage;
              _currentZoom = 1.0;
            });
            _saveReadingProgress();
            _checkBookmarkStatus();
          },
          itemBuilder: (context, index) {
            final pageNum = index + 1;
            return PdfSinglePageItem(
              key: ValueKey('pdf_page_$pageNum'),
              document: document,
              pageNumber: pageNum,
              onZoomChanged: (zoom) {
                if (_currentPage == pageNum && mounted) {
                  setState(() {
                    _currentZoom = zoom;
                  });
                }
              },
              onLeftTap: () {
                if (_currentPage > 1 && _singlePageController.hasClients) {
                  _singlePageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              onRightTap: () {
                if (_currentPage < _pageCount && _singlePageController.hasClients) {
                  _singlePageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              onCenterTap: _toggleFullscreen,
              onControllerCreated: (controller) {
                _pageTransformControllers[pageNum] = controller;
              },
              onControllerDisposed: () {
                _pageTransformControllers.remove(pageNum);
              },
            );
          },
        );
      },
    );
  }

  /// Continuous Mode: Vertical scrolling of all pages
  Widget _buildContinuousView() {
    return PdfViewer.file(
      widget.filePath,
      controller: _pdfController,
      params: PdfViewerParams(
        margin: 12.0,
        panAxis: PanAxis.free,
        boundaryMargin: const EdgeInsets.all(36.0),
        scrollByMouseWheel: 0.2,
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => const SizedBox.shrink(),
        onViewerReady: (document, controller) {
          setState(() {
            _pageCount = document.pages.length;
          });

          // Restore saved page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && controller.isReady) {
              if (!_hasRestoredPage && _savedPageToRestore != null) {
                _hasRestoredPage = true;
                final restoreTo = _savedPageToRestore!.clamp(1, _pageCount);
                if (restoreTo > 1) {
                  _goToPage(restoreTo);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      content: Text('Resumed at Page $restoreTo of $_pageCount'),
                    ),
                  );
                  return;
                }
              }
              _fitCurrentPage();
            }
          });
        },
        onPageChanged: (pageNumber) {
          if (pageNumber != null && mounted && _currentPage != pageNumber) {
            setState(() {
              _currentPage = pageNumber;
            });
            _saveReadingProgress();
            _checkBookmarkStatus();
          }
        },
      ),
    );
  }

  Widget _buildZoomControls(ThemeData theme) {
    if (!_isZoomBarExpanded) {
      return FloatingActionButton.small(
        heroTag: 'pdf_zoom_btn',
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
          // Zoom Out (-)
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom Out (-)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: _zoomOut,
          ),

          // Zoom Slider
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _currentZoom.clamp(_isSinglePageMode ? 1.0 : 0.3, 4.0),
                min: _isSinglePageMode ? 1.0 : 0.3,
                max: 4.0,
                onChanged: _onZoomSliderChanged,
              ),
            ),
          ),

          // Zoom In (+)
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom In (+)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: _zoomIn,
          ),

          const SizedBox(width: 4),

          // Zoom Percentage Badge
          InkWell(
            onTap: _fitCurrentPage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(_currentZoom * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Fit Page Button
          IconButton(
            icon: const Icon(Icons.fit_screen, size: 18),
            tooltip: 'Fit Page to Screen',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: _fitCurrentPage,
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

/// Single PDF page widget that manages zoom, animated double-tap, and 3-zone tap navigation
class PdfSinglePageItem extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final ValueChanged<double>? onZoomChanged;
  final ValueChanged<TransformationController>? onControllerCreated;
  final VoidCallback? onControllerDisposed;
  final VoidCallback? onLeftTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onRightTap;

  const PdfSinglePageItem({
    super.key,
    required this.document,
    required this.pageNumber,
    this.onZoomChanged,
    this.onControllerCreated,
    this.onControllerDisposed,
    this.onLeftTap,
    this.onCenterTap,
    this.onRightTap,
  });

  @override
  State<PdfSinglePageItem> createState() => PdfSinglePageItemState();
}

class PdfSinglePageItemState extends State<PdfSinglePageItem> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

  bool _panEnabled = false;
  double _currentScale = 1.0;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(_onAnimationTick);

    widget.onControllerCreated?.call(_transformController);
  }

  @override
  void dispose() {
    widget.onControllerDisposed?.call();
    _animController.removeListener(_onAnimationTick);
    _animController.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (_matrixAnimation != null) {
      _transformController.value = _matrixAnimation!.value;
    }
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    _currentScale = scale;
    final shouldEnablePan = scale > 1.05;
    if (shouldEnablePan != _panEnabled) {
      setState(() {
        _panEnabled = shouldEnablePan;
      });
    }
    widget.onZoomChanged?.call(scale);
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward(from: 0.0);
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    if (_animController.isAnimating) return;

    if (_currentScale > 1.05) {
      _animateToMatrix(Matrix4.identity());
    } else {
      const double targetScale = 2.5;
      final size = context.size ?? MediaQuery.sizeOf(context);
      final pos = _doubleTapDetails?.localPosition ?? Offset(size.width / 2, size.height / 2);

      final rawDx = pos.dx * (1 - targetScale);
      final rawDy = pos.dy * (1 - targetScale);

      final minDx = size.width * (1 - targetScale);
      final minDy = size.height * (1 - targetScale);

      final clampedDx = rawDx.clamp(minDx, 0.0);
      final clampedDy = rawDy.clamp(minDy, 0.0);

      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, targetScale);
      matrix.setEntry(1, 1, targetScale);
      matrix.setEntry(0, 3, clampedDx);
      matrix.setEntry(1, 3, clampedDy);

      _animateToMatrix(matrix);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_animController.isAnimating) return;

    final size = context.size;
    if (size == null || size.width == 0) return;

    // When zoomed in, tapping on sides does NOT flip pages
    if (_currentScale > 1.05) {
      widget.onCenterTap?.call();
      return;
    }

    final xRatio = details.localPosition.dx / size.width;
    if (xRatio < 0.25) {
      widget.onLeftTap?.call();
    } else if (xRatio > 0.75) {
      widget.onRightTap?.call();
    } else {
      widget.onCenterTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      onTapUp: _onTapUp,
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: _panEnabled,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(80.0),
        child: Center(
          child: PdfPageView(
            key: ValueKey('pdf_pv_${widget.pageNumber}'),
            document: widget.document,
            pageNumber: widget.pageNumber,
            maximumDpi: 300,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

