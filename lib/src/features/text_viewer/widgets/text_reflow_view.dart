import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/services/reading_progress_service.dart';
import '../models/text_reflow_models.dart';
import '../parser/text_reflow_parser.dart';
import '../parser/text_reflow_paginator.dart';

/// Full-screen responsive e-book reflow viewer for plain text (.txt) documents.
/// Gives plain text files an authentic electronic book reading feel with
/// screen-fitted mini-pages, book typography, themes, and page flipping.
class TextReflowView extends StatefulWidget {
  final String fullText;
  final String fileName;
  final String filePath;
  final TextReflowSettings settings;
  final ValueChanged<TextReflowSettings> onSettingsChanged;
  final VoidCallback onExitReflow;
  final List<BookmarkItem> bookmarks;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShowBookmarks;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;
  final int? initialChapter;
  final int? initialMiniPage;
  final double? initialFraction;

  const TextReflowView({
    super.key,
    required this.fullText,
    required this.fileName,
    required this.filePath,
    required this.settings,
    required this.onSettingsChanged,
    required this.onExitReflow,
    required this.bookmarks,
    required this.onToggleBookmark,
    required this.onShowBookmarks,
    required this.onToggleFullscreen,
    required this.isFullscreen,
    this.initialChapter,
    this.initialMiniPage,
    this.initialFraction,
  });

  @override
  State<TextReflowView> createState() => _TextReflowViewState();
}

class _TextReflowViewState extends State<TextReflowView> {
  late List<TextReflowChapter> _chapters;
  int _currentChapterIndex = 0;
  int _currentMiniPageIndex = 0;
  List<TextReflowPage> _currentPages = [];

  late PageController _pageController;
  final ScrollController _continuousScrollController = ScrollController();
  Size? _lastViewportSize;

  bool _showControls = true;
  bool _isTransitioningChapter = false;
  double _overscrollDistance = 0.0;
  bool _dragStartedOnLastPage = false;
  bool _dragStartedOnFirstPage = false;

  @override
  void initState() {
    super.initState();
    _chapters = TextReflowParser.parse(widget.fullText, defaultTitle: widget.fileName);
    _currentChapterIndex = (widget.initialChapter ?? 0).clamp(0, math.max(0, _chapters.length - 1));
    _currentMiniPageIndex = widget.initialMiniPage ?? 0;
    _pageController = PageController(initialPage: _currentMiniPageIndex);
  }

  @override
  void didUpdateWidget(covariant TextReflowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialChapter != null && widget.initialChapter != oldWidget.initialChapter) {
      _goToChapter(widget.initialChapter!, targetMiniPage: widget.initialMiniPage);
    } else if (widget.initialMiniPage != null && widget.initialMiniPage != oldWidget.initialMiniPage) {
      if (_pageController.hasClients && widget.initialMiniPage! < _currentPages.length) {
        _pageController.jumpToPage(widget.initialMiniPage!);
      }
    }
  }

  @override
  void dispose() {
    _saveReadingProgress();
    _pageController.dispose();
    _continuousScrollController.dispose();
    super.dispose();
  }

  void _paginateChapter(Size viewportSize, {int? preferredAnchorBlock, int? preferredAnchorChar}) {
    if (_chapters.isEmpty) return;

    int? currentBlock = preferredAnchorBlock;
    int? currentChar = preferredAnchorChar;
    if (currentBlock == null && _currentPages.isNotEmpty && _currentMiniPageIndex < _currentPages.length) {
      final curPage = _currentPages[_currentMiniPageIndex];
      currentBlock = curPage.startBlockIndex;
      currentChar = curPage.startCharOffset;
    }

    final chapter = _chapters[_currentChapterIndex];

    final result = TextReflowPaginator.paginateChapterWithAnchor(
      chapter: chapter,
      viewportSize: viewportSize,
      settings: widget.settings,
      textColor: widget.settings.theme.textColor,
      anchorBlockIndex: currentBlock,
      anchorCharOffset: currentChar,
    );

    int targetIndex;
    if (currentBlock != null) {
      targetIndex = result.anchorPageIndex;
    } else {
      targetIndex = _currentMiniPageIndex.clamp(0, math.max(0, result.pages.length - 1));
    }

    _currentPages = result.pages;
    _currentMiniPageIndex = targetIndex;

    if (_pageController.hasClients) {
      _pageController.jumpToPage(targetIndex);
    } else {
      _pageController.dispose();
      _pageController = PageController(initialPage: targetIndex);
    }
  }

  void _goToChapter(int chapterIndex, {int? targetMiniPage, int? targetBlock, int? targetChar}) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;

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
      if (targetBlock == null && targetMiniPage != null && targetMiniPage < _currentPages.length) {
        _currentMiniPageIndex = targetMiniPage;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetMiniPage);
        }
      }
      if (mounted) setState(() {});
    }

    if (_continuousScrollController.hasClients) {
      _continuousScrollController.jumpTo(0.0);
    }

    _saveReadingProgress();
  }

  void _goToNextChapterOrPage() {
    if (_currentMiniPageIndex < _currentPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex < _chapters.length - 1) {
      _goToChapter(_currentChapterIndex + 1, targetMiniPage: 0);
    }
  }

  void _goToPrevChapterOrPage() {
    if (_currentMiniPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (_currentChapterIndex > 0) {
      final prevChapter = _chapters[_currentChapterIndex - 1];
      if (_lastViewportSize != null) {
        final prevPages = TextReflowPaginator.paginateChapter(
          chapter: prevChapter,
          viewportSize: _lastViewportSize!,
          settings: widget.settings,
          textColor: widget.settings.theme.textColor,
        );
        _goToChapter(_currentChapterIndex - 1, targetMiniPage: math.max(0, prevPages.length - 1));
      } else {
        _goToChapter(_currentChapterIndex - 1);
      }
    }
  }

  void _saveReadingProgress() {
    if (_chapters.isEmpty) return;

    final page = (_currentPages.isNotEmpty && _currentMiniPageIndex < _currentPages.length)
        ? _currentPages[_currentMiniPageIndex]
        : null;

    final totalChapters = _chapters.length;
    final chapterFraction = _currentChapterIndex / totalChapters;
    final miniFraction = (_currentPages.isNotEmpty)
        ? (_currentMiniPageIndex / _currentPages.length) * (1.0 / totalChapters)
        : 0.0;
    final totalProgress = (chapterFraction + miniFraction).clamp(0.0, 1.0);

    ReadingProgressService.saveProgress(
      widget.filePath,
      chapter: _currentChapterIndex,
      miniPage: _currentMiniPageIndex,
      page: _currentMiniPageIndex + 1,
      blockIndex: page?.startBlockIndex,
      charOffset: page?.startCharOffset,
      progressFraction: totalProgress,
    );
  }

  void _showSettingsSheet() {
    final theme = widget.settings.theme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentSettings = widget.settings;
            final textColor = theme.textColor;

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
                            color: textColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_stories, color: theme.accentColor, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Reading & E-Book Settings',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onExitReflow();
                            },
                            icon: Icon(Icons.code, size: 18, color: theme.accentColor),
                            label: Text(
                              'Code / Raw View',
                              style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Font Size
                      Row(
                        children: [
                          Text('Text Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: currentSettings.fontSize > 12.0
                                ? () {
                                    final updated = currentSettings.copyWith(
                                      fontSize: (currentSettings.fontSize - 1.5).clamp(12.0, 34.0),
                                    );
                                    widget.onSettingsChanged(updated);
                                    if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                                    setSheetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.remove, size: 18),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '${currentSettings.fontSize.toInt()} pt',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: currentSettings.fontSize < 34.0
                                ? () {
                                    final updated = currentSettings.copyWith(
                                      fontSize: (currentSettings.fontSize + 1.5).clamp(12.0, 34.0),
                                    );
                                    widget.onSettingsChanged(updated);
                                    if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                                    setSheetState(() {});
                                  }
                                : null,
                            icon: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Theme Palette
                      Row(
                        children: [
                          Text('Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: TextReflowTheme.values.map((th) {
                                  final isSelected = currentSettings.theme == th;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () {
                                        final updated = currentSettings.copyWith(theme: th);
                                        widget.onSettingsChanged(updated);
                                        setSheetState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: th.backgroundColor,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected ? th.accentColor : Colors.grey.withValues(alpha: 0.4),
                                            width: isSelected ? 2.5 : 1,
                                          ),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: th.accentColor.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: th.textColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              th.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: th.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Font Family
                      Row(
                        children: [
                          Text('Font', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: TextReflowFont.values.map((f) {
                                  final isSelected = currentSettings.font == f;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(f.label),
                                      selected: isSelected,
                                      selectedColor: theme.accentColor.withValues(alpha: 0.18),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? theme.accentColor : textColor,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          final updated = currentSettings.copyWith(font: f);
                                          widget.onSettingsChanged(updated);
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

                      // Page Flow Mode: Paginated vs Continuous
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page Flow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          SegmentedButton<TextReflowMode>(
                            segments: const [
                              ButtonSegment(
                                value: TextReflowMode.paginated,
                                label: Text('Swipe Pages'),
                                icon: Icon(Icons.auto_stories, size: 16),
                              ),
                              ButtonSegment(
                                value: TextReflowMode.continuous,
                                label: Text('Continuous'),
                                icon: Icon(Icons.view_day_outlined, size: 16),
                              ),
                            ],
                            selected: {currentSettings.mode},
                            onSelectionChanged: (set) {
                              final updated = currentSettings.copyWith(mode: set.first);
                              widget.onSettingsChanged(updated);
                              if (updated.mode == TextReflowMode.paginated && _lastViewportSize != null) {
                                _paginateChapter(_lastViewportSize!);
                              }
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Line Spacing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Line Spacing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          SegmentedButton<double>(
                            segments: const [
                              ButtonSegment(value: 1.4, label: Text('Tight')),
                              ButtonSegment(value: 1.6, label: Text('Normal')),
                              ButtonSegment(value: 1.9, label: Text('Relaxed')),
                            ],
                            selected: {currentSettings.lineHeight},
                            onSelectionChanged: (set) {
                              final updated = currentSettings.copyWith(lineHeight: set.first);
                              widget.onSettingsChanged(updated);
                              if (_lastViewportSize != null) _paginateChapter(_lastViewportSize!);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTocSheet() {
    if (_chapters.isEmpty) return;
    final theme = widget.settings.theme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
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
                      color: theme.textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.format_list_bulleted_rounded, color: theme.accentColor),
                        const SizedBox(width: 10),
                        Text(
                          'Table of Contents (${_chapters.length})',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: _chapters.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        final isCurrent = index == _currentChapterIndex;
                        return ListTile(
                          selected: isCurrent,
                          selectedTileColor: theme.accentColor.withValues(alpha: 0.12),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isCurrent ? theme.accentColor : theme.textColor.withValues(alpha: 0.1),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : theme.textColor,
                              ),
                            ),
                          ),
                          title: Text(
                            chapter.title,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: theme.textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            '~${(chapter.wordCount / 200).ceil()} min',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textColor.withValues(alpha: 0.6),
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

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final isPaginated = widget.settings.mode == TextReflowMode.paginated;

    return Container(
      color: theme.backgroundColor,
      child: LayoutBuilder(
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
              // Main Reading Content
              isPaginated ? _buildPaginatedView(theme) : _buildContinuousView(theme),

              // Floating Quick Settings & TOC Controls
              Positioned(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_chapters.length > 1) ...[
                      FloatingActionButton.small(
                        heroTag: 'txt_reflow_toc_btn',
                        backgroundColor: theme.surfaceColor,
                        foregroundColor: theme.accentColor,
                        tooltip: 'Table of Contents',
                        onPressed: _showTocSheet,
                        child: const Icon(Icons.format_list_bulleted, size: 18),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FloatingActionButton.small(
                      heroTag: 'txt_reflow_settings_btn',
                      backgroundColor: theme.surfaceColor,
                      foregroundColor: theme.accentColor,
                      tooltip: 'Reading Settings',
                      onPressed: _showSettingsSheet,
                      child: const Icon(Icons.tune, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Paginated Mini-Pages with swipe and tap zones.
  Widget _buildPaginatedView(TextReflowTheme theme) {
    if (_currentPages.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: theme.accentColor),
      );
    }

    final totalChapters = _chapters.length;
    final chapterFraction = _currentChapterIndex / totalChapters;
    final miniFraction = (_currentPages.isNotEmpty)
        ? (_currentMiniPageIndex / _currentPages.length) * (1.0 / totalChapters)
        : 0.0;
    final totalProgressPercent = ((chapterFraction + miniFraction).clamp(0.0, 1.0) * 100).round();

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _overscrollDistance = 0.0;
                _dragStartedOnLastPage = _currentPages.isNotEmpty && (_currentMiniPageIndex >= _currentPages.length - 1);
                _dragStartedOnFirstPage = _currentPages.isNotEmpty && (_currentMiniPageIndex <= 0);
              } else if (notification is ScrollUpdateNotification) {
                if (notification.metrics.hasContentDimensions) {
                  if (_dragStartedOnLastPage && _currentChapterIndex < _chapters.length - 1) {
                    final over = notification.metrics.pixels - notification.metrics.maxScrollExtent;
                    if (over > 0 && over > _overscrollDistance) {
                      _overscrollDistance = over;
                    }
                  } else if (_dragStartedOnFirstPage && _currentChapterIndex > 0) {
                    final over = notification.metrics.minScrollExtent - notification.metrics.pixels;
                    if (over > 0 && -over < _overscrollDistance) {
                      _overscrollDistance = -over;
                    }
                  }
                }
              } else if (notification is OverscrollNotification) {
                if (_dragStartedOnLastPage && _currentChapterIndex < _chapters.length - 1) {
                  if (notification.overscroll > 0) _overscrollDistance += notification.overscroll;
                } else if (_dragStartedOnFirstPage && _currentChapterIndex > 0) {
                  if (notification.overscroll < 0) _overscrollDistance += notification.overscroll;
                }
              } else if (notification is ScrollEndNotification ||
                  (notification is UserScrollNotification && notification.direction == ScrollDirection.idle)) {
                final dist = _overscrollDistance;
                final wasStartedLast = _dragStartedOnLastPage;
                final wasStartedFirst = _dragStartedOnFirstPage;
                _overscrollDistance = 0.0;
                _dragStartedOnLastPage = false;
                _dragStartedOnFirstPage = false;

                if (!_isTransitioningChapter) {
                  if (wasStartedLast &&
                      dist > 25 &&
                      _currentMiniPageIndex >= _currentPages.length - 1 &&
                      _currentChapterIndex < _chapters.length - 1) {
                    _isTransitioningChapter = true;
                    _goToChapter(_currentChapterIndex + 1, targetMiniPage: 0);
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) _isTransitioningChapter = false;
                    });
                  } else if (wasStartedFirst &&
                      dist < -25 &&
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
              physics: const PageScrollPhysics(parent: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())),
              itemCount: _currentPages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentMiniPageIndex = index;
                });
                _saveReadingProgress();
              },
              itemBuilder: (context, index) {
                final page = _currentPages[index];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final xRatio = details.localPosition.dx / constraints.maxWidth;
                        if (xRatio < 0.25) {
                          _goToPrevChapterOrPage();
                        } else if (xRatio > 0.75) {
                          _goToNextChapterOrPage();
                        } else {
                          _toggleControls();
                        }
                      },
                      child: Container(
                        color: theme.backgroundColor,
                        padding: EdgeInsets.fromLTRB(
                          widget.settings.horizontalPadding,
                          16,
                          widget.settings.horizontalPadding,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Show chapter title on page 0
                            if (index == 0 && page.chapterTitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                                child: Text(
                                  page.chapterTitle,
                                  style: widget.settings.font.getTextStyle(
                                    fontSize: widget.settings.fontSize * 1.3,
                                    color: theme.textColor,
                                    height: 1.3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Render blocks
                            Expanded(
                              child: ClipRect(
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final block in page.blocks)
                                        _buildBlockWidget(block, theme),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.textColor.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${_currentMiniPageIndex + 1} of ${_currentPages.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: Text(
                    _chapters[_currentChapterIndex].title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textColor.withValues(alpha: 0.55),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Text(
                  '$totalProgressPercent%',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Continuous scrollable book view
  Widget _buildContinuousView(TextReflowTheme theme) {
    final chapter = _chapters[_currentChapterIndex];

    return SingleChildScrollView(
      controller: _continuousScrollController,
      padding: EdgeInsets.fromLTRB(
        widget.settings.horizontalPadding,
        24,
        widget.settings.horizontalPadding,
        60,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chapter.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                chapter.title,
                style: widget.settings.font.getTextStyle(
                  fontSize: widget.settings.fontSize * 1.35,
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
              if (_currentChapterIndex < _chapters.length - 1)
                FilledButton.icon(
                  onPressed: () => _goToChapter(_currentChapterIndex + 1),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Next Chapter'),
                )
              else
                Text(
                  'End of Document',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(TextReflowBlock block, TextReflowTheme theme) {
    switch (block.type) {
      case TextReflowBlockType.heading1:
        return Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            block.text,
            style: widget.settings.font.getTextStyle(
              fontSize: widget.settings.fontSize * 1.35,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );

      case TextReflowBlockType.heading2:
        return Padding(
          padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
          child: Text(
            block.text,
            style: widget.settings.font.getTextStyle(
              fontSize: widget.settings.fontSize * 1.2,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case TextReflowBlockType.heading3:
        return Padding(
          padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
          child: Text(
            block.text,
            style: widget.settings.font.getTextStyle(
              fontSize: widget.settings.fontSize * 1.08,
              color: theme.textColor,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case TextReflowBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(
            block.text,
            style: widget.settings.font.getTextStyle(
              fontSize: widget.settings.fontSize,
              color: theme.textColor,
              height: widget.settings.lineHeight,
              fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: widget.settings.textAlign,
          ),
        );

      case TextReflowBlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.accentColor.withValues(alpha: 0.6),
                width: 3.0,
              ),
            ),
          ),
          child: Text(
            block.text,
            style: widget.settings.font.getTextStyle(
              fontSize: widget.settings.fontSize * 0.95,
              color: theme.textColor.withValues(alpha: 0.85),
              height: widget.settings.lineHeight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: widget.settings.textAlign,
          ),
        );

      case TextReflowBlockType.divider:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              '•  •  •',
              style: TextStyle(
                letterSpacing: 4.0,
                color: theme.textColor.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }
}
