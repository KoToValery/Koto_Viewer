import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/services/reading_progress_service.dart';
import 'models/ebook_models.dart';
import 'parser/ebook_parser.dart';
import 'parser/ebook_paginator.dart';

/// Digital E-Book Reader Screen (.epub, .fb2, .fb2.zip).
/// Features full Cyrillic & international script support, customizable typography,
/// dynamic screen mini-page pagination with 3D paper curl animation,
/// automatic reading progress restore (exact mini-page), bookmarking,
/// two-row header navigation, and Android system-safe UI.
class EbookViewerScreen extends StatefulWidget {
  final String filePath;
  const EbookViewerScreen({super.key, required this.filePath});

  @override
  State<EbookViewerScreen> createState() => _EbookViewerScreenState();
}

class _EbookViewerScreenState extends State<EbookViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;
  EbookBook? _book;
  int _currentChapterIndex = 0;
  int _currentMiniPageIndex = 0;
  List<EbookMiniPage> _currentMiniPages = [];
  EbookSettings _settings = const EbookSettings();
  bool _showControls = true;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<int> _matchedChapterIndices = [];

  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  Size? _lastViewportSize;

  // Reading progress & bookmarks
  bool _isCurrentBookmarked = false;
  List<BookmarkItem> _bookmarks = [];
  int? _pendingResumeMiniPage;
  int? _pendingResumeBlock;
  int? _pendingResumeChar;
  bool _hasRestoredProgress = false;
  int _paginatedChapterIndex = -1;
  bool _isTransitioningChapter = false;
  double _overscrollDistance = 0.0;

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentMiniPageIndex);
    _loadBook();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _saveReadingProgress();
    _scrollController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
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
      final book = await EbookParser.parseFromFile(widget.filePath);

      // Load saved reading progress and bookmarks
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      if (progress != null) {
        _currentChapterIndex = (progress.chapter ?? 0).clamp(0, book.chapters.length - 1);
        _pendingResumeMiniPage = progress.miniPage;
        _pendingResumeBlock = progress.blockIndex;
        _pendingResumeChar = progress.charOffset;
        _bookmarks = progress.bookmarks;
      } else {
        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      }

      if (mounted) {
        setState(() {
          _book = book;
          _isLoading = false;
        });
        _checkBookmarkStatus();
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading e-book: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _paginateChapter(Size viewportSize, {int? preferredAnchorBlock, int? preferredAnchorChar}) {
    if (_book == null || _book!.chapters.isEmpty) return;

    // Capture currently visible reading anchor before repaginating
    int? currentBlock = preferredAnchorBlock;
    int? currentChar = preferredAnchorChar;
    if (currentBlock == null && _currentMiniPages.isNotEmpty && _currentMiniPageIndex < _currentMiniPages.length) {
      final curPage = _currentMiniPages[_currentMiniPageIndex];
      currentBlock = curPage.startBlockIndex;
      currentChar = curPage.startCharOffset;
    }

    final isSameChapter = _paginatedChapterIndex == _currentChapterIndex;
    _paginatedChapterIndex = _currentChapterIndex;

    final chapter = _book!.chapters[_currentChapterIndex];

    int targetIndex = 0;
    if (!_hasRestoredProgress && (_pendingResumeMiniPage != null || _pendingResumeBlock != null)) {
      _hasRestoredProgress = true;
      final savedBlock = _pendingResumeBlock;
      final savedChar = _pendingResumeChar;
      final savedMiniPage = _pendingResumeMiniPage;
      _pendingResumeMiniPage = null;
      _pendingResumeBlock = null;
      _pendingResumeChar = null;

      final result = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: viewportSize,
        settings: _settings,
        textColor: _settings.themeMode.textColor,
        anchorBlockIndex: savedBlock,
        anchorCharOffset: savedChar,
      );

      if (savedBlock != null) {
        targetIndex = result.anchorPageIndex;
      } else if (savedMiniPage != null) {
        targetIndex = savedMiniPage.clamp(0, result.pages.length - 1);
      }
      _currentMiniPages = result.pages;
      _currentMiniPageIndex = targetIndex;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && targetIndex > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              content: Text('Resumed at Chapter ${_currentChapterIndex + 1}, Page ${targetIndex + 1}'),
            ),
          );
        }
      });
    } else if (isSameChapter && currentBlock != null) {
      // Repaginating SAME chapter (fullscreen toggle, screen rotate, font size change)
      final result = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: viewportSize,
        settings: _settings,
        textColor: _settings.themeMode.textColor,
        anchorBlockIndex: currentBlock,
        anchorCharOffset: currentChar,
      );
      targetIndex = result.anchorPageIndex;
      _currentMiniPages = result.pages;
      _currentMiniPageIndex = targetIndex;
    } else {
      // Navigating to chapter (preferredAnchorBlock or preferred mini page)
      final result = EbookPaginator.paginateChapterWithAnchor(
        chapter: chapter,
        viewportSize: viewportSize,
        settings: _settings,
        textColor: _settings.themeMode.textColor,
        anchorBlockIndex: preferredAnchorBlock,
        anchorCharOffset: preferredAnchorChar,
      );
      if (preferredAnchorBlock != null) {
        targetIndex = result.anchorPageIndex;
      } else {
        targetIndex = _currentMiniPageIndex.clamp(0, result.pages.length - 1);
      }
      _currentMiniPages = result.pages;
      _currentMiniPageIndex = targetIndex;
    }

    if (_pageController.hasClients) {
      _pageController.jumpToPage(targetIndex);
    } else {
      _pageController.dispose();
      _pageController = PageController(initialPage: targetIndex);
    }

    _checkBookmarkStatus();
  }

  void _saveReadingProgress() {
    if (_book == null || _book!.chapters.isEmpty) return;

    final page = (_currentMiniPages.isNotEmpty && _currentMiniPageIndex < _currentMiniPages.length)
        ? _currentMiniPages[_currentMiniPageIndex]
        : null;

    final totalChapters = _book!.chapters.length;
    final chapterFraction = _currentChapterIndex / totalChapters;
    final miniFraction = (_currentMiniPages.isNotEmpty)
        ? (_currentMiniPageIndex / _currentMiniPages.length) * (1.0 / totalChapters)
        : 0.0;
    final totalProgress = (chapterFraction + miniFraction).clamp(0.0, 1.0);

    ReadingProgressService.saveProgress(
      widget.filePath,
      chapter: _currentChapterIndex,
      miniPage: _currentMiniPageIndex,
      blockIndex: page?.startBlockIndex,
      charOffset: page?.startCharOffset,
      progressFraction: totalProgress,
    );
  }

  Future<void> _checkBookmarkStatus() async {
    final bookmarked = await ReadingProgressService.isBookmarked(
      widget.filePath,
      chapter: _currentChapterIndex,
      miniPage: _currentMiniPageIndex,
    );
    if (mounted) {
      setState(() {
        _isCurrentBookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_book == null) return;

    final page = (_currentMiniPages.isNotEmpty && _currentMiniPageIndex < _currentMiniPages.length)
        ? _currentMiniPages[_currentMiniPageIndex]
        : null;

    if (_isCurrentBookmarked) {
      final existing = _bookmarks.firstWhere(
        (b) => b.chapter == _currentChapterIndex && b.miniPage == _currentMiniPageIndex,
        orElse: () => BookmarkItem(
          id: '',
          page: _currentMiniPageIndex + 1,
          chapter: _currentChapterIndex,
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
      final chapterTitle = _book!.chapters[_currentChapterIndex].title;
      final snippet = page?.snippet.isNotEmpty == true ? page!.snippet : chapterTitle;
      final newBookmark = BookmarkItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        page: _currentMiniPageIndex + 1,
        chapter: _currentChapterIndex,
        miniPage: _currentMiniPageIndex,
        blockIndex: page?.startBlockIndex,
        charOffset: page?.startCharOffset,
        label: 'Ch. ${_currentChapterIndex + 1}, Pg. ${_currentMiniPageIndex + 1}',
        snippet: snippet,
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
            content: Text('Bookmarked: Ch. ${_currentChapterIndex + 1}, Page ${_currentMiniPageIndex + 1}'),
          ),
        );
      }
    }
  }

  void _showBookmarksSheet() {
    final currentTheme = _settings.themeMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.35,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: currentTheme.textColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.bookmark, color: currentTheme.accentColor),
                            const SizedBox(width: 10),
                            Text(
                              'Bookmarks (${_bookmarks.length})',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: currentTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _bookmarks.isEmpty
                            ? Center(
                                child: Text(
                                  'No bookmarks added yet.\nTap the bookmark icon to save your place.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: currentTheme.textColor.withValues(alpha: 0.6)),
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
                                      backgroundColor: currentTheme.accentColor.withValues(alpha: 0.15),
                                      child: Icon(Icons.bookmark, color: currentTheme.accentColor, size: 18),
                                    ),
                                    title: Text(
                                      b.label,
                                      style: TextStyle(
                                        color: currentTheme.textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      b.snippet,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: currentTheme.textColor.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
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
                                      if (b.chapter != null) {
                                        _goToChapter(
                                          b.chapter!,
                                          targetMiniPage: b.miniPage,
                                          targetBlock: b.blockIndex,
                                          targetChar: b.charOffset,
                                        );
                                      }
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

  void _goToChapter(int chapterIndex, {int? targetMiniPage, int? targetBlock, int? targetChar}) {
    if (_book == null || chapterIndex < 0 || chapterIndex >= _book!.chapters.length) return;

    _isTransitioningChapter = false;
    setState(() {
      _currentChapterIndex = chapterIndex;
      _currentMiniPageIndex = targetMiniPage ?? 0;
    });

    if (_lastViewportSize != null) {
      _paginateChapter(
        _lastViewportSize!,
        preferredAnchorBlock: targetBlock,
        preferredAnchorChar: targetChar,
      );
      if (targetBlock == null && targetMiniPage != null && targetMiniPage < _currentMiniPages.length) {
        _currentMiniPageIndex = targetMiniPage;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetMiniPage);
        }
      }
      if (mounted) {
        setState(() {});
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    _saveReadingProgress();
    _checkBookmarkStatus();
  }

  void _onMiniPageChanged(int index) {
    setState(() {
      _currentMiniPageIndex = index;
    });
    _saveReadingProgress();
    _checkBookmarkStatus();
  }

  void _goToNextChapterOrPage() {
    if (_currentMiniPageIndex < _currentMiniPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex < _book!.chapters.length - 1) {
      _goToChapter(_currentChapterIndex + 1, targetMiniPage: 0);
    }
  }

  void _goToPrevChapterOrPage() {
    if (_currentMiniPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex > 0) {
      // Transition to previous chapter's last page
      final prevChapter = _book!.chapters[_currentChapterIndex - 1];
      if (_lastViewportSize != null) {
        final prevPages = EbookPaginator.paginateChapter(
          chapter: prevChapter,
          viewportSize: _lastViewportSize!,
          settings: _settings,
          textColor: _settings.themeMode.textColor,
        );
        _goToChapter(_currentChapterIndex - 1, targetMiniPage: math.max(0, prevPages.length - 1));
      } else {
        _goToChapter(_currentChapterIndex - 1);
      }
    }
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      _matchedChapterIndices.clear();
      if (_searchQuery.isNotEmpty && _book != null) {
        for (int i = 0; i < _book!.chapters.length; i++) {
          if (_book!.chapters[i].rawText.toLowerCase().contains(_searchQuery) ||
              _book!.chapters[i].title.toLowerCase().contains(_searchQuery)) {
            _matchedChapterIndices.add(i);
          }
        }
      }
    });
  }

  void _showTypographySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _settings.themeMode.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final textColor = _settings.themeMode.textColor;
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
                            color: textColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reading & Typography',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Font Size
                      Row(
                        children: [
                          Text('Size', style: TextStyle(fontSize: 14, color: textColor)),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: _settings.fontSize > 12.0
                                ? () {
                                    setState(() {
                                      _settings = _settings.copyWith(fontSize: _settings.fontSize - 1.5);
                                    });
                                    if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                                    setSheetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_settings.fontSize.toInt()} pt',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _settings.fontSize < 36.0
                                ? () {
                                    setState(() {
                                      _settings = _settings.copyWith(fontSize: _settings.fontSize + 1.5);
                                    });
                                    if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                                    setSheetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Theme
                      Row(
                        children: [
                          Text('Theme', style: TextStyle(fontSize: 14, color: textColor)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: EbookThemeMode.values.map((mode) {
                                  final isSelected = _settings.themeMode == mode;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(mode.label),
                                      selected: isSelected,
                                      avatar: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: mode.backgroundColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.grey.withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _settings = _settings.copyWith(themeMode: mode);
                                          });
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Font family
                      Row(
                        children: [
                          Text('Font', style: TextStyle(fontSize: 14, color: textColor)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: EbookFontFamily.values.map((font) {
                                  final isSelected = _settings.fontFamily == font;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(font.label),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _settings = _settings.copyWith(fontFamily: font);
                                          });
                                          if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                                          setSheetState(() {});
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Line Spacing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Line Spacing', style: TextStyle(fontSize: 14, color: textColor)),
                          SegmentedButton<double>(
                            segments: const [
                              ButtonSegment(value: 1.4, label: Text('Tight')),
                              ButtonSegment(value: 1.65, label: Text('Normal')),
                              ButtonSegment(value: 1.95, label: Text('Relaxed')),
                            ],
                            selected: {_settings.lineHeight},
                            onSelectionChanged: (set) {
                              setState(() {
                                _settings = _settings.copyWith(lineHeight: set.first);
                              });
                              if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Reading Mode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page Flow', style: TextStyle(fontSize: 14, color: textColor)),
                          SegmentedButton<EbookReadingMode>(
                            segments: const [
                              ButtonSegment(
                                value: EbookReadingMode.paginated,
                                icon: Icon(Icons.auto_stories, size: 16),
                                label: Text('Pages'),
                              ),
                              ButtonSegment(
                                value: EbookReadingMode.continuous,
                                icon: Icon(Icons.view_day_outlined, size: 16),
                                label: Text('Scroll'),
                              ),
                            ],
                            selected: {_settings.readingMode},
                            onSelectionChanged: (set) {
                              setState(() {
                                _settings = _settings.copyWith(readingMode: set.first);
                              });
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTocSheet() {
    if (_book == null) return;
    final currentTheme = _settings.themeMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: currentTheme.textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.format_list_bulleted_rounded, color: currentTheme.accentColor),
                        const SizedBox(width: 10),
                        Text(
                          'Table of Contents (${_book!.chapters.length})',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: currentTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _book!.chapters.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chapter = _book!.chapters[index];
                        final isCurrent = index == _currentChapterIndex;
                        return ListTile(
                          selected: isCurrent,
                          selectedTileColor: currentTheme.accentColor.withValues(alpha: 0.12),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrent
                                ? currentTheme.accentColor
                                : currentTheme.textColor.withValues(alpha: 0.1),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : currentTheme.textColor,
                              ),
                            ),
                          ),
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: currentTheme.textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '~${(chapter.wordCount / 200).ceil()} min',
                            style: TextStyle(
                              fontSize: 11,
                              color: currentTheme.textColor.withValues(alpha: 0.6),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _goToChapter(index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showInfoSheet() {
    if (_book == null) return;
    final meta = _book!.metadata;
    final currentTheme = _settings.themeMode;
    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: currentTheme.textColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (meta.coverBytes != null)
                        Container(
                          width: 60,
                          height: 84,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(meta.coverBytes!, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: currentTheme.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.book_rounded, color: currentTheme.accentColor, size: 28),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: currentTheme.textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta.authorString,
                              style: TextStyle(
                                fontSize: 13,
                                color: currentTheme.textColor.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fileName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: currentTheme.textColor.withValues(alpha: 0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Format:', _book!.format.name.toUpperCase(), currentTheme),
                  _buildInfoRow('Total Chapters:', '${_book!.chapterCount} chapters', currentTheme),
                  _buildInfoRow('Total Word Count:', '${_book!.totalWordCount} words', currentTheme),
                  _buildInfoRow('Est. Reading Time:', '~${_book!.estimatedReadTimeMinutes} minutes', currentTheme),
                  _buildInfoRow('File Size:', formattedSize, currentTheme),
                  if (meta.publisher != null && meta.publisher!.isNotEmpty)
                    _buildInfoRow('Publisher:', meta.publisher!, currentTheme),
                  if (meta.publicationDate != null && meta.publicationDate!.isNotEmpty)
                    _buildInfoRow('Published Date:', meta.publicationDate!, currentTheme),
                  if (meta.language != null && meta.language!.isNotEmpty)
                    _buildInfoRow('Language:', meta.language!, currentTheme),
                  if (meta.genre != null && meta.genre!.isNotEmpty)
                    _buildInfoRow('Genre:', meta.genre!, currentTheme),
                  if (meta.description != null && meta.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Annotation / Summary:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: currentTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.description!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: currentTheme.textColor.withValues(alpha: 0.8),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, EbookThemeMode theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.textColor.withValues(alpha: 0.7))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textColor),
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
    final currentTheme = _settings.themeMode;
    final isPaginated = _settings.readingMode == EbookReadingMode.paginated;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _saveReadingProgress();
        if (_errorMessage != null) RecentFilesService.removeRecentFile(widget.filePath);
      },
      child: Scaffold(
        backgroundColor: currentTheme.backgroundColor,
        appBar: _showControls
            ? AppBar(
                backgroundColor: currentTheme.surfaceColor,
                foregroundColor: currentTheme.textColor,
                elevation: 0.5,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _saveReadingProgress();
                    if (_errorMessage != null) RecentFilesService.removeRecentFile(widget.filePath);
                    Navigator.of(context).pop(_errorMessage == null);
                  },
                ),
                // Row 1: Book Title & Chapter Subtitle
                title: _isSearchOpen
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: currentTheme.textColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search in book text...',
                          hintStyle: TextStyle(color: currentTheme.textColor.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                        ),
                        onChanged: _onSearchChanged,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _book?.title ?? _fileName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_book != null && _book!.chapters.isNotEmpty)
                            Text(
                              _book!.chapters[_currentChapterIndex].title,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: currentTheme.textColor.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                actions: [
                  if (_isSearchOpen)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() {
                          _isSearchOpen = false;
                          _searchController.clear();
                          _searchQuery = '';
                          _matchedChapterIndices.clear();
                        });
                      },
                    ),
                ],
                // Row 2: Universal Action Commands Bar (horizontally scrollable, no overflow)
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(44),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: currentTheme.surfaceColor,
                      border: Border(
                        bottom: BorderSide(
                          color: currentTheme.textColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Search Toggle
                          IconButton(
                            icon: Icon(_isSearchOpen ? Icons.search_off : Icons.search, size: 20),
                            tooltip: 'Search Book',
                            onPressed: () {
                              setState(() {
                                _isSearchOpen = !_isSearchOpen;
                                if (!_isSearchOpen) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _matchedChapterIndices.clear();
                                }
                              });
                            },
                          ),

                          // Table of Contents
                          IconButton(
                            icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
                            tooltip: 'Table of Contents',
                            onPressed: _showTocSheet,
                          ),

                          // Bookmark Toggle
                          IconButton(
                            icon: Icon(
                              _isCurrentBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              size: 20,
                              color: _isCurrentBookmarked ? currentTheme.accentColor : null,
                            ),
                            tooltip: _isCurrentBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                            onPressed: _toggleBookmark,
                          ),

                          // View Bookmarks List
                          IconButton(
                            icon: const Icon(Icons.bookmarks_outlined, size: 20),
                            tooltip: 'Saved Bookmarks',
                            onPressed: _showBookmarksSheet,
                          ),

                          // Reading Flow Mode Toggle (Pages vs Scroll)
                          IconButton(
                            icon: Icon(
                              isPaginated ? Icons.auto_stories : Icons.view_day_outlined,
                              size: 20,
                            ),
                            tooltip: isPaginated
                                ? 'Page Flip Mode (Tap for Continuous)'
                                : 'Continuous Scroll (Tap for Pages)',
                            onPressed: () {
                              setState(() {
                                _settings = _settings.copyWith(
                                  readingMode: isPaginated
                                      ? EbookReadingMode.continuous
                                      : EbookReadingMode.paginated,
                                );
                              });
                              if (_settings.readingMode == EbookReadingMode.paginated && _lastViewportSize != null) {
                                _paginateChapter(_lastViewportSize!);
                              }
                            },
                          ),

                          // Typography & Theme
                          IconButton(
                            icon: const Icon(Icons.text_format_rounded, size: 20),
                            tooltip: 'Typography & Theme',
                            onPressed: _showTypographySheet,
                          ),

                          // Book Info
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 20),
                            tooltip: 'Book Info',
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
        body: GestureDetector(
          onTap: _toggleControls,
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: currentTheme.accentColor),
                      const SizedBox(height: 16),
                      Text(
                        'Opening E-Book...',
                        style: TextStyle(color: currentTheme.textColor.withValues(alpha: 0.7)),
                      ),
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
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: currentTheme.textColor),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadBook,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _book == null || _book!.chapters.isEmpty
                      ? Center(
                          child: Text(
                            'No content found',
                            style: TextStyle(color: currentTheme.textColor),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                            if (_lastViewportSize != viewportSize) {
                              _lastViewportSize = viewportSize;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _paginateChapter(viewportSize);
                                  setState(() {});
                                }
                              });
                            }

                            return Stack(
                              children: [
                                isPaginated
                                    ? _buildPaginatedPageView(currentTheme)
                                    : _buildContinuousChapterView(currentTheme),

                                if (_isSearchOpen && _searchQuery.isNotEmpty)
                                  _buildSearchResultsOverlay(currentTheme),

                                if (_showControls && !_isSearchOpen)
                                  _buildBottomNavigationBar(currentTheme),
                              ],
                            );
                          },
                        ),
        ),
      ),
    );
  }

  /// Paginated Mini-Pages with Realistic 3D Paper Curl Transition
  Widget _buildPaginatedPageView(EbookThemeMode theme) {
    if (_currentMiniPages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _overscrollDistance = 0.0;
              } else if (notification is ScrollUpdateNotification) {
                if (notification.metrics.hasContentDimensions) {
                  // If on the last page of current chapter, track forward overscroll
                  if (_currentMiniPageIndex >= _currentMiniPages.length - 1 &&
                      _currentChapterIndex < _book!.chapters.length - 1) {
                    final over = notification.metrics.pixels - notification.metrics.maxScrollExtent;
                    if (over > _overscrollDistance) {
                      _overscrollDistance = over;
                    }
                  }
                  // If on the first page of current chapter, track backward overscroll
                  else if (_currentMiniPageIndex <= 0 && _currentChapterIndex > 0) {
                    final over = notification.metrics.minScrollExtent - notification.metrics.pixels;
                    if (over > -_overscrollDistance) {
                      _overscrollDistance = -over;
                    }
                  }
                }
              } else if (notification is OverscrollNotification) {
                if (_currentMiniPageIndex >= _currentMiniPages.length - 1 &&
                    _currentChapterIndex < _book!.chapters.length - 1) {
                  if (notification.overscroll > 0) {
                    _overscrollDistance += notification.overscroll;
                  }
                } else if (_currentMiniPageIndex <= 0 && _currentChapterIndex > 0) {
                  if (notification.overscroll < 0) {
                    _overscrollDistance += notification.overscroll; // negative
                  }
                }
              } else if (notification is ScrollEndNotification ||
                  (notification is UserScrollNotification && notification.direction == ScrollDirection.idle)) {
                final dist = _overscrollDistance;
                _overscrollDistance = 0.0;
                if (!_isTransitioningChapter) {
                  if (dist > 15 &&
                      _currentMiniPageIndex >= _currentMiniPages.length - 1 &&
                      _currentChapterIndex < _book!.chapters.length - 1) {
                    _isTransitioningChapter = true;
                    _goToNextChapterOrPage();
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) _isTransitioningChapter = false;
                    });
                  } else if (dist < -15 &&
                      _currentMiniPageIndex <= 0 &&
                      _currentChapterIndex > 0) {
                    _isTransitioningChapter = true;
                    _goToPrevChapterOrPage();
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) _isTransitioningChapter = false;
                    });
                  }
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: _currentMiniPages.length,
              onPageChanged: _onMiniPageChanged,
              itemBuilder: (context, index) {
                final page = _currentMiniPages[index];
                return Container(
                  color: theme.backgroundColor,
                  padding: EdgeInsets.fromLTRB(
                    _settings.horizontalPadding,
                    16,
                    _settings.horizontalPadding,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // If first mini-page of chapter, show chapter title
                      if (index == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Text(
                            page.chapterTitle,
                            style: _settings.fontFamily.getTextStyle(
                              fontSize: _settings.fontSize * 1.3,
                              color: theme.textColor,
                              height: 1.3,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Render mini-page blocks
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final block in page.blocks)
                              _buildBlockWidget(block, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Discrete Book Footer Indicator
        SafeArea(
          top: false,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${_currentMiniPageIndex + 1} of ${_currentMiniPages.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Flexible(
                  child: Text(
                    _book!.chapters[_currentChapterIndex].title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textColor.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Text(
                  'Ch. ${_currentChapterIndex + 1}/${_book!.chapters.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Continuous vertical scrollable chapter view
  Widget _buildContinuousChapterView(EbookThemeMode theme) {
    final chapter = _book!.chapters[_currentChapterIndex];
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        _settings.horizontalPadding,
        24,
        _settings.horizontalPadding,
        _showControls ? 110 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              chapter.title,
              style: _settings.fontFamily.getTextStyle(
                fontSize: _settings.fontSize * 1.35,
                color: theme.textColor,
                height: 1.3,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          for (final block in chapter.blocks)
            _buildBlockWidget(block, theme),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentChapterIndex > 0)
                OutlinedButton.icon(
                  onPressed: () => _goToChapter(_currentChapterIndex - 1),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Prev Chapter'),
                )
              else
                const SizedBox.shrink(),
              if (_currentChapterIndex < _book!.chapters.length - 1)
                FilledButton.icon(
                  onPressed: () => _goToChapter(_currentChapterIndex + 1),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Next Chapter'),
                )
              else
                const Text('End of Book', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(EbookBlock block, EbookThemeMode theme) {
    switch (block.type) {
      case EbookBlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize * 1.3,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case EbookBlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize * 1.18,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case EbookBlockType.heading3:
        return Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize * 1.08,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case EbookBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize,
              color: theme.textColor,
              height: _settings.lineHeight,
              fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: _settings.textAlign,
          ),
        );
      case EbookBlockType.quote:
      case EbookBlockType.epigraph:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.accentColor, width: 3.5)),
            color: theme.textColor.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
          ),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize * 0.95,
              color: theme.textColor.withValues(alpha: 0.9),
              height: _settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case EbookBlockType.poem:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          padding: const EdgeInsets.only(left: 24.0),
          child: Text(
            block.text,
            style: _settings.fontFamily.getTextStyle(
              fontSize: _settings.fontSize * 0.95,
              color: theme.textColor,
              height: _settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case EbookBlockType.image:
        if (block.imageBytes != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  block.imageBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case EbookBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Center(
            child: Text(
              '* * *',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.4),
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildSearchResultsOverlay(EbookThemeMode theme) {
    return Container(
      color: theme.surfaceColor.withValues(alpha: 0.96),
      child: _matchedChapterIndices.isEmpty
          ? Center(
              child: Text(
                'No matches found for "$_searchQuery"',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.6)),
              ),
            )
          : ListView.separated(
              itemCount: _matchedChapterIndices.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final chIdx = _matchedChapterIndices[idx];
                final ch = _book!.chapters[chIdx];
                return ListTile(
                  leading: Icon(Icons.search, color: theme.accentColor, size: 20),
                  title: Text(
                    ch.title,
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Chapter ${chIdx + 1}',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _isSearchOpen = false;
                    });
                    _goToChapter(chIdx);
                  },
                );
              },
            ),
    );
  }

  Widget _buildBottomNavigationBar(EbookThemeMode theme) {
    final totalChapters = _book!.chapters.length;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.surfaceColor.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Prev',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _goToPrevChapterOrPage,
              ),
              const SizedBox(width: 8),
              Text(
                '${_currentChapterIndex + 1}',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _currentChapterIndex.toDouble(),
                  min: 0,
                  max: (totalChapters - 1).toDouble(),
                  divisions: totalChapters > 1 ? totalChapters - 1 : 1,
                  activeColor: theme.accentColor,
                  inactiveColor: theme.textColor.withValues(alpha: 0.2),
                  onChanged: (val) {
                    _goToChapter(val.round());
                  },
                ),
              ),
              Text(
                '$totalChapters',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _goToNextChapterOrPage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
