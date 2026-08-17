import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'models/docx_models.dart';
import 'parser/docx_parser.dart';
import 'parser/doc_parser.dart';
import '../pdf_viewer/pdf_viewer_screen.dart';
import '../../core/services/doc_to_pdf_converter_service.dart';

/// Microsoft Word Document (.docx) Viewer Screen.
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
  double _fontScale = 1.0;

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _searchMatchCount = 0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadDocxFile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
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

      DocxDocument doc;
      try {
        doc = DocxParser.parse(bytes);
      } catch (_) {
        doc = DocParser.parse(bytes);
      }

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading Word document: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAsPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF document...'),
          duration: Duration(seconds: 1),
        ),
      );

      final pdfPath = await DocToPdfConverterService.convertToPdf(widget.filePath);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: pdfPath,
            title: _fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not convert to PDF: $e')),
      );
    }
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

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
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
              _buildInfoRow('Paragraphs:', '${_document!.paragraphCount}'),
              _buildInfoRow('Headings:', '${_document!.headingCount}'),
              _buildInfoRow('Tables:', '${_document!.tableCount}'),
              _buildInfoRow('Estimated Words:', '${_document!.wordCount} words'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final docBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final docBorderColor = isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_document != null)
                    Text(
                      '${_document!.paragraphCount} paragraphs • ${_document!.tableCount} tables',
                      style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                    ),
                ],
              ),
        actions: [
          // Search Action
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
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

          // View as PDF Action
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'View as PDF',
            onPressed: _openAsPdf,
          ),

          // Copy All
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy Document Text',
            onPressed: _copyAllText,
          ),

          // Info / Properties
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Document Properties',
            onPressed: _showInfoSheet,
          ),

          // Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
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
              : Column(
                  children: [
                    // Search Match Status Bar
                    if (_searchQuery.isNotEmpty)
                      Container(
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

                    // Main Document Body (Simulated Document Sheet)
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 860),
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                                decoration: BoxDecoration(
                                  color: docBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: docBorderColor, width: 1),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildDocumentBlocks(theme, isDark),
                                ),
                              ),
                            ),
                          ),

                          // Floating Font Zoom Controls
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.text_decrease, size: 18),
                                    tooltip: 'Smaller Font',
                                    onPressed: () {
                                      setState(() {
                                        _fontScale = (_fontScale - 0.1).clamp(0.7, 1.8);
                                      });
                                    },
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _fontScale = 1.0),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        '${(_fontScale * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.text_increase, size: 18),
                                    tooltip: 'Larger Font',
                                    onPressed: () {
                                      setState(() {
                                        _fontScale = (_fontScale + 0.1).clamp(0.7, 1.8);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _buildDocumentBlocks(ThemeData theme, bool isDark) {
    if (_document == null || _document!.blocks.isEmpty) {
      return [const Text('Document is empty.')];
    }

    final List<Widget> widgets = [];

    for (final block in _document!.blocks) {
      if (block is DocxParagraph) {
        widgets.add(_buildParagraphWidget(block, theme, isDark));
      } else if (block is DocxTable) {
        widgets.add(_buildTableWidget(block, theme, isDark));
      }
    }

    return widgets;
  }

  Widget _buildParagraphWidget(DocxParagraph paragraph, ThemeData theme, bool isDark) {
    final spans = <InlineSpan>[];

    for (final run in paragraph.runs) {
      final baseSize = run.fontSize ?? _getBaseFontSizeForHeading(paragraph.headingLevel);
      final isMatched = _searchQuery.isNotEmpty && run.text.toLowerCase().contains(_searchQuery.toLowerCase());

      spans.add(
        TextSpan(
          text: run.text,
          style: TextStyle(
            fontSize: baseSize * _fontScale,
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
            height: 1.5,
          ),
        ),
      );
    }

    Widget content = SelectableText.rich(
      TextSpan(children: spans),
      textAlign: paragraph.alignment,
    );

    if (paragraph.isBullet) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 4.0),
            child: Icon(Icons.circle, size: 6.0 * _fontScale, color: theme.colorScheme.primary),
          ),
          Expanded(child: content),
        ],
      );
    }

    double bottomSpacing = 6.0;
    if (paragraph.headingLevel == DocxHeadingLevel.title) {
      bottomSpacing = 16.0;
    } else if (paragraph.headingLevel == DocxHeadingLevel.h1) {
      bottomSpacing = 12.0;
    } else if (paragraph.headingLevel == DocxHeadingLevel.h2) {
      bottomSpacing = 10.0;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: content,
    );
  }

  double _getBaseFontSizeForHeading(DocxHeadingLevel level) {
    switch (level) {
      case DocxHeadingLevel.title:
        return 22.0;
      case DocxHeadingLevel.h1:
        return 19.0;
      case DocxHeadingLevel.h2:
        return 16.5;
      case DocxHeadingLevel.h3:
        return 15.0;
      case DocxHeadingLevel.h4:
      case DocxHeadingLevel.h5:
      case DocxHeadingLevel.h6:
      case DocxHeadingLevel.none:
        return 13.5;
    }
  }

  Widget _buildTableWidget(DocxTable table, ThemeData theme, bool isDark) {
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: borderColor, width: 0.8, borderRadius: BorderRadius.circular(4)),
          children: table.rows.map((row) {
            return TableRow(
              children: row.cells.map((cell) {
                return Container(
                  color: cell.backgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cell.paragraphs.map((p) => _buildParagraphWidget(p, theme, isDark)).toList(),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}
