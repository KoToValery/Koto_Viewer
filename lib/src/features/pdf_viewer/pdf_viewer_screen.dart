import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../home/widgets/share_options_sheet.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const PdfViewerScreen({super.key, required this.filePath, this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _isDarkModeView = false;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String _fileName = '';

  double _currentZoom = 1.0;
  bool _isZoomBarExpanded = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _fileName =
        widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _pdfController.addListener(_onControllerChanged);
    _saveToRecentFiles();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pdfController.removeListener(_onControllerChanged);
    super.dispose();
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

  Future<void> _saveToRecentFiles() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final size = await file.length();
        final pdfItem = PdfItem(
          path: widget.filePath,
          name: _fileName,
          sizeInBytes: size,
          lastOpened: DateTime.now(),
        );
        await RecentFilesService.addRecentFile(pdfItem);
      }
    } catch (_) {}
  }

  void _fitCurrentPage() {
    if (!_pdfController.isReady) return;
    try {
      _pdfController.goToPage(pageNumber: _currentPage, anchor: PdfPageAnchor.center);
    } catch (_) {}
  }

  void _onZoomSliderChanged(double newZoom) {
    if (!_pdfController.isReady) return;
    setState(() {
      _currentZoom = newZoom;
    });
    try {
      _pdfController.setZoom(_pdfController.centerPosition, newZoom);
    } catch (_) {}
  }

  void _zoomIn() {
    if (!_pdfController.isReady) return;
    final newZoom = (_currentZoom * 1.25).clamp(0.3, 4.0);
    _onZoomSliderChanged(newZoom);
  }

  void _zoomOut() {
    if (!_pdfController.isReady) return;
    final newZoom = (_currentZoom / 1.25).clamp(0.3, 4.0);
    _onZoomSliderChanged(newZoom);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing file: $e')));
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
                  _pdfController.goToPage(pageNumber: page, anchor: PdfPageAnchor.center);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _isFullscreen ? null : AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),

                // Invert mode
                IconButton(
                  icon: Icon(_isDarkModeView ? Icons.light_mode : Icons.dark_mode, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Fullscreen',
                  onPressed: _toggleFullscreen,
                ),

                // Share
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Share PDF',
                  onPressed: _sharePdf,
                ),

                // Print
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Print PDF',
                  onPressed: _printPdf,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: _isDarkModeView
                ? const ColorFilter.matrix([
                    -1.0,
                    0.0,
                    0.0,
                    0.0,
                    255.0,
                    0.0,
                    -1.0,
                    0.0,
                    0.0,
                    255.0,
                    0.0,
                    0.0,
                    -1.0,
                    0.0,
                    255.0,
                    0.0,
                    0.0,
                    0.0,
                    1.0,
                    0.0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: PdfViewer.file(
              widget.filePath,
              controller: _pdfController,
              params: PdfViewerParams(
                margin: 12.0,
                panAxis: PanAxis.free,
                boundaryMargin: const EdgeInsets.all(36.0),
                scrollByMouseWheel: 0.2,
                onViewerReady: (document, controller) {
                  setState(() {
                    _pageCount = document.pages.length;
                    _isLoading = false;
                  });
                  // Fit page 1 on screen by default so full text is visible
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && controller.isReady) {
                      _fitCurrentPage();
                    }
                  });
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber != null) {
                    setState(() {
                      _currentPage = pageNumber;
                    });
                  }
                },
                errorBannerBuilder: (context, error, stackTrace, documentRef) {
                  RecentFilesService.removeRecentFile(widget.filePath);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              size: 48,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load document',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The file is damaged, incomplete (0 bytes), or not in a valid PDF format.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Floating Zoom Control Bar
          if (!_isLoading)
            Positioned(
              bottom: 16,
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
        ],
      ),
      bottomNavigationBar: _isFullscreen ? null : BottomAppBar(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: 'First Page',
              onPressed: _currentPage > 1
                  ? () => _pdfController.goToPage(pageNumber: 1, anchor: PdfPageAnchor.center)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous Page',
              onPressed: _currentPage > 1
                  ? () => _pdfController.goToPage(pageNumber: _currentPage - 1, anchor: PdfPageAnchor.center)
                  : null,
            ),
            GestureDetector(
              onTap: _showJumpToPageDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
              onPressed: _currentPage < _pageCount
                  ? () => _pdfController.goToPage(pageNumber: _currentPage + 1, anchor: PdfPageAnchor.center)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: 'Last Page',
              onPressed: _currentPage < _pageCount
                  ? () => _pdfController.goToPage(pageNumber: _pageCount, anchor: PdfPageAnchor.center)
                  : null,
            ),
          ],
        ),
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
          // Zoom Out
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom Out (-)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: _zoomOut,
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
                value: _currentZoom.clamp(0.3, 4.0),
                min: 0.3,
                max: 4.0,
                onChanged: _onZoomSliderChanged,
              ),
            ),
          ),

          // Zoom In
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom In (+)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: _zoomIn,
          ),

          const SizedBox(width: 4),

          // Zoom Percentage Badge (Tap to reset / fit page)
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
