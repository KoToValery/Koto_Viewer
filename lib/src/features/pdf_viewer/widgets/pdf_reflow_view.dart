import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/pdf_reflow_models.dart';
import '../services/pdf_text_extractor_service.dart';

/// Full-screen responsive e-book style reflow viewer for PDF documents.
/// Adapts PDF text to phone screen dimensions, with OCR support for scanned pages.
class PdfReflowView extends StatefulWidget {
  final PdfDocument document;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onToggleControls;
  final VoidCallback onExitReflow;
  final PdfTextExtractorService extractorService;
  final PdfReflowSettings settings;
  final ValueChanged<PdfReflowSettings> onSettingsChanged;

  const PdfReflowView({
    super.key,
    required this.document,
    required this.currentPage,
    required this.onPageChanged,
    required this.onToggleControls,
    required this.onExitReflow,
    required this.extractorService,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<PdfReflowView> createState() => _PdfReflowViewState();
}

class _PdfReflowViewState extends State<PdfReflowView> {
  late PageController _pageController;
  final ScrollController _continuousScrollController = ScrollController();
  final Map<int, Future<PdfPageReflowData>> _pageFutures = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentPage - 1);
    _prefetchPages(widget.currentPage);
  }

  @override
  void didUpdateWidget(covariant PdfReflowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? -1) != widget.currentPage - 1) {
        _pageController.jumpToPage(widget.currentPage - 1);
      }
      _prefetchPages(widget.currentPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _continuousScrollController.dispose();
    super.dispose();
  }

  void _prefetchPages(int centerPage) {
    for (int p = centerPage - 1; p <= centerPage + 2; p++) {
      if (p >= 1 && p <= widget.document.pages.length) {
        _getPageData(p);
      }
    }
  }

  Future<PdfPageReflowData> _getPageData(int pageNumber) {
    return _pageFutures.putIfAbsent(pageNumber, () {
      return widget.extractorService.getPageData(widget.document, pageNumber);
    });
  }

  void _showSettingsSheet() {
    final theme = widget.settings.theme;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentSettings = widget.settings;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: currentSettings.theme.textColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reading Settings',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: currentSettings.theme.textColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onExitReflow();
                          },
                          icon: Icon(Icons.picture_as_pdf_outlined, size: 18, color: currentSettings.theme.accentColor),
                          label: Text(
                            'Original PDF',
                            style: TextStyle(color: currentSettings.theme.accentColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Font Size Controls
                    Row(
                      children: [
                        Text(
                          'Text Size',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: currentSettings.theme.textColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.text_decrease),
                          color: currentSettings.theme.textColor,
                          tooltip: 'Decrease font size',
                          onPressed: currentSettings.fontSize > 12.0
                              ? () {
                                  final updated = currentSettings.copyWith(
                                    fontSize: (currentSettings.fontSize - 1.5).clamp(12.0, 32.0),
                                  );
                                  widget.onSettingsChanged(updated);
                                  setSheetState(() {});
                                }
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: currentSettings.theme.textColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${currentSettings.fontSize.toInt()} pt',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: currentSettings.theme.textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.text_increase),
                          color: currentSettings.theme.textColor,
                          tooltip: 'Increase font size',
                          onPressed: currentSettings.fontSize < 32.0
                              ? () {
                                  final updated = currentSettings.copyWith(
                                    fontSize: (currentSettings.fontSize + 1.5).clamp(12.0, 32.0),
                                  );
                                  widget.onSettingsChanged(updated);
                                  setSheetState(() {});
                                }
                              : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Font Family Selector
                    Row(
                      children: [
                        Text(
                          'Font',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: currentSettings.theme.textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: PdfReflowFont.values.map((f) {
                              final isSelected = currentSettings.font == f;
                              return ChoiceChip(
                                label: Text(f.label),
                                selected: isSelected,
                                selectedColor: currentSettings.theme.accentColor.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? currentSettings.theme.accentColor
                                      : currentSettings.theme.textColor.withValues(alpha: 0.8),
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    final updated = currentSettings.copyWith(font: f);
                                    widget.onSettingsChanged(updated);
                                    setSheetState(() {});
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Theme Colors
                    Row(
                      children: [
                        Text(
                          'Theme',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: currentSettings.theme.textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: PdfReflowTheme.values.map((th) {
                              final isSelected = currentSettings.theme == th;
                              return GestureDetector(
                                onTap: () {
                                  final updated = currentSettings.copyWith(theme: th);
                                  widget.onSettingsChanged(updated);
                                  setSheetState(() {});
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: th.backgroundColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? currentSettings.theme.accentColor
                                          : Colors.grey.withValues(alpha: 0.3),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: currentSettings.theme.accentColor.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Aa',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: th.textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Reading Mode: Paginated vs Continuous
                    Row(
                      children: [
                        Text(
                          'Mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: currentSettings.theme.textColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Swipe Pages'),
                              icon: Icon(Icons.view_carousel_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Continuous'),
                              icon: Icon(Icons.view_stream_outlined, size: 16),
                            ),
                          ],
                          selected: {currentSettings.isContinuous},
                          onSelectionChanged: (set) {
                            final updated = currentSettings.copyWith(isContinuous: set.first);
                            widget.onSettingsChanged(updated);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;

    return Container(
      color: theme.backgroundColor,
      child: Stack(
        children: [
          // Content view: either Paginated PageView or Continuous ListView
          widget.settings.isContinuous
              ? _buildContinuousView()
              : _buildPaginatedView(),

          // Floating quick-settings FAB
          Positioned(
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'pdf_reflow_settings_btn',
              backgroundColor: theme.surfaceColor,
              foregroundColor: theme.accentColor,
              tooltip: 'Reading Settings',
              onPressed: _showSettingsSheet,
              child: const Icon(Icons.tune, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.document.pages.length,
      onPageChanged: (index) {
        final newPage = index + 1;
        widget.onPageChanged(newPage);
        _prefetchPages(newPage);
      },
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return _buildPageContainer(pageNum);
      },
    );
  }

  Widget _buildContinuousView() {
    return ListView.builder(
      controller: _continuousScrollController,
      padding: EdgeInsets.symmetric(
        horizontal: widget.settings.horizontalPadding,
        vertical: 24,
      ),
      itemCount: widget.document.pages.length,
      itemBuilder: (context, index) {
        final pageNum = index + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(pageNum),
              const SizedBox(height: 12),
              _buildPageContent(pageNum),
              const SizedBox(height: 24),
              Divider(
                color: widget.settings.theme.textColor.withValues(alpha: 0.15),
                thickness: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageContainer(int pageNumber) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final xRatio = details.localPosition.dx / constraints.maxWidth;
            if (xRatio < 0.25) {
              if (pageNumber > 1) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
            } else if (xRatio > 0.75) {
              if (pageNumber < widget.document.pages.length) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
            } else {
              widget.onToggleControls();
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: widget.settings.horizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(pageNumber),
                const SizedBox(height: 16),
                _buildPageContent(pageNumber),
                const SizedBox(height: 60), // bottom clearance for fab
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageHeader(int pageNumber) {
    final theme = widget.settings.theme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PAGE $pageNumber OF ${widget.document.pages.length}',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: theme.textColor.withValues(alpha: 0.5),
          ),
        ),
        FutureBuilder<PdfPageReflowData>(
          future: _getPageData(pageNumber),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isScannedOcr) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: theme.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'OCR Text',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: theme.accentColor,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildPageContent(int pageNumber) {
    final theme = widget.settings.theme;

    return FutureBuilder<PdfPageReflowData>(
      future: _getPageData(pageNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(theme.accentColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Extracting text for Page $pageNumber...',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Text(
                'Error loading page: ${snapshot.error}',
                style: TextStyle(color: Colors.redAccent.shade200, fontSize: 13),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null || data.blocks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notes_rounded, size: 40, color: theme.textColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No readable text found on Page $pageNumber.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: widget.onExitReflow,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('View Original PDF Page'),
                  ),
                ],
              ),
            ),
          );
        }

        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.blocks.map((block) {
              if (block.isHeading) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                  child: Text(
                    block.text,
                    textAlign: widget.settings.textAlign,
                    style: widget.settings.font.getTextStyle(
                      fontSize: widget.settings.fontSize * 1.25,
                      color: theme.textColor,
                      height: 1.35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Text(
                  block.text,
                  textAlign: widget.settings.textAlign,
                  style: widget.settings.font.getTextStyle(
                    fontSize: widget.settings.fontSize,
                    color: theme.textColor,
                    height: widget.settings.lineHeight,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
