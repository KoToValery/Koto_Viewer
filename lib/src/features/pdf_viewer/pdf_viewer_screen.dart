import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

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

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _saveToRecentFiles();
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

  Future<void> _sharePdf() async {
    try {
      final file = XFile(widget.filePath);
      await Share.shareXFiles([file], text: 'Sharing PDF: $_fileName');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: _fileName,
      );
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
                  _pdfController.goToPage(pageNumber: page);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_pageCount > 0)
              Text(
                'Page $_currentPage of $_pageCount',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isDarkModeView ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle Invert Colors',
            onPressed: () {
              setState(() {
                _isDarkModeView = !_isDarkModeView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: _sharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print PDF',
            onPressed: _printPdf,
          ),
        ],
      ),
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: _isDarkModeView
                ? const ColorFilter.matrix([
                    -1.0, 0.0, 0.0, 0.0, 255.0,
                    0.0, -1.0, 0.0, 0.0, 255.0,
                    0.0, 0.0, -1.0, 0.0, 255.0,
                    0.0, 0.0, 0.0, 1.0, 0.0,
                  ])
                : const ColorFilter.mode(
                    Colors.transparent,
                    BlendMode.dst,
                  ),
            child: PdfViewer.file(
              widget.filePath,
              controller: _pdfController,
              params: PdfViewerParams(
                onViewerReady: (document, controller) {
                  setState(() {
                    _pageCount = document.pages.length;
                    _isLoading = false;
                  });
                },
                onPageChanged: (pageNumber) {
                  if (pageNumber != null) {
                    setState(() {
                      _currentPage = pageNumber;
                    });
                  }
                },
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: _currentPage > 1
                  ? () => _pdfController.goToPage(pageNumber: 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 1
                  ? () => _pdfController.goToPage(pageNumber: _currentPage - 1)
                  : null,
            ),
            GestureDetector(
              onTap: _showJumpToPageDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              onPressed: _currentPage < _pageCount
                  ? () => _pdfController.goToPage(pageNumber: _currentPage + 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: _currentPage < _pageCount
                  ? () => _pdfController.goToPage(pageNumber: _pageCount)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
