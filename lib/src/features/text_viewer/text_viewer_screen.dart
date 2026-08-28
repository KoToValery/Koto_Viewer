import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kotoview/src/core/services/recent_files_service.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Text Viewer Screen for .txt, .log, .csv, and coordinate files.
class TextViewerScreen extends StatefulWidget {
  final String filePath;

  const TextViewerScreen({super.key, required this.filePath});

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;
  String _encodingName = 'UTF-8';

  String _fullText = '';
  List<String> _lines = [];

  // Options
  final bool _showLineNumbers = true;
  bool _isMonospace = true;
  bool _isWordWrap = true;
  double _fontSize = 13.5;
  bool _isZoomBarExpanded = true;

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<int> _matchedLineIndices = [];
  int _currentMatchIndex = -1;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadTextFile();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTextFile() async {
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

      final result = UniversalEncodingService.decodeBytesWithEncoding(bytes);
      _fullText = result.text;
      _encodingName = result.encodingName;
      _lines = result.text.split(RegExp(r'\r?\n'));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading text file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _matchedLineIndices.clear();
      _currentMatchIndex = -1;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        for (int i = 0; i < _lines.length; i++) {
          if (_lines[i].toLowerCase().contains(q)) {
            _matchedLineIndices.add(i);
          }
        }
        if (_matchedLineIndices.isNotEmpty) {
          _currentMatchIndex = 0;
        }
      }
    });
  }

  void _nextMatch() {
    if (_matchedLineIndices.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchedLineIndices.length;
    });
  }

  void _prevMatch() {
    if (_matchedLineIndices.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchedLineIndices.length) % _matchedLineIndices.length;
    });
  }

  void _showInfoSheet() {
    final theme = Theme.of(context);
    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    final wordCount = _fullText.trim().isEmpty ? 0 : _fullText.trim().split(RegExp(r'\s+')).length;

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
                      color: const Color(0xFF475569).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Text Document • Properties',
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
              _buildInfoRow('Total Lines:', '${_lines.length} lines'),
              _buildInfoRow('Total Words:', '$wordCount words'),
              _buildInfoRow('Total Characters:', '${_fullText.length} chars'),
              _buildInfoRow('Detected Encoding:', _encodingName),
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

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  void _copyAllText() {
    Clipboard.setData(ClipboardData(text: _fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All text copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gutterBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9);
    final lineGutterColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    final fontStyle = _isMonospace
        ? GoogleFonts.firaCode(fontSize: _fontSize, height: 1.45)
        : TextStyle(fontSize: _fontSize, height: 1.45);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  hintText: 'Find in text...',
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
            : Text(
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
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),

                // Search Action
                IconButton(
                  icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _isSearchOpen ? 'Close Search' : 'Find in Text',
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

                // Monospace Toggle
                IconButton(
                  icon: Icon(_isMonospace ? Icons.font_download : Icons.font_download_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _isMonospace ? 'Switch to Proportional Font' : 'Switch to Monospace Font',
                  onPressed: () => setState(() => _isMonospace = !_isMonospace),
                ),

                // Word Wrap Toggle (Fit to Screen)
                IconButton(
                  icon: Icon(_isWordWrap ? Icons.wrap_text : Icons.format_align_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _isWordWrap ? 'Disable Word Wrap' : 'Enable Word Wrap',
                  onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
                ),

                // Copy All
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Copy All',
                  onPressed: _copyAllText,
                ),

                // Info / Properties
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Text Properties',
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF475569)),
                  SizedBox(height: 16),
                  Text('Loading Text Document...'),
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
                          onPressed: _loadTextFile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Search Match Status Bar with Next/Prev
                    if (_searchQuery.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: Color(0xFFF57C00)),
                            const SizedBox(width: 8),
                            Text(
                              _matchedLineIndices.isEmpty
                                  ? 'No matches found'
                                  : 'Match ${_currentMatchIndex + 1} of ${_matchedLineIndices.length}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF57C00),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                              tooltip: 'Previous Match',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _prevMatch,
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                              tooltip: 'Next Match',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _nextMatch,
                            ),
                          ],
                        ),
                      ),

                    // Main Text Display Area (Vertical & Horizontal Scrollable)
                    Expanded(
                      child: Stack(
                        children: [
                          _isWordWrap
                              ? ListView.builder(
                                  controller: _verticalScrollController,
                                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                                  itemCount: _lines.length,
                                  itemBuilder: (context, index) => _buildLineItem(
                                    index,
                                    fontStyle,
                                    lineGutterColor,
                                    gutterBg,
                                  ),
                                )
                              : Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: 2500, // Wide canvas for unified horizontal scroll
                                      child: ListView.builder(
                                        controller: _verticalScrollController,
                                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                                        itemCount: _lines.length,
                                        itemBuilder: (context, index) => _buildLineItem(
                                          index,
                                          fontStyle,
                                          lineGutterColor,
                                          gutterBg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                          // Floating Zoom Slider Controls
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: _buildZoomControls(theme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLineItem(
    int index,
    TextStyle fontStyle,
    Color lineGutterColor,
    Color gutterBg,
  ) {
    final lineText = _lines[index];
    final isCurrentMatch = _matchedLineIndices.isNotEmpty &&
        _currentMatchIndex >= 0 &&
        _matchedLineIndices[_currentMatchIndex] == index;
    final isMatch = _matchedLineIndices.contains(index);

    return Container(
      color: isCurrentMatch
          ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
          : isMatch
              ? const Color(0xFFFFD54F).withValues(alpha: 0.2)
              : null,
      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLineNumbers) ...[
            Container(
              width: 48,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.firaCode(
                  fontSize: (_fontSize * 0.82).clamp(8.0, 24.0),
                  color: lineGutterColor,
                  fontWeight: isCurrentMatch ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Container(
              width: 1,
              height: _fontSize * 1.5,
              color: gutterBg,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SelectableText(
              lineText.isEmpty ? ' ' : lineText,
              style: fontStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls(ThemeData theme) {
    if (!_isZoomBarExpanded) {
      return FloatingActionButton.small(
        heroTag: 'text_zoom_btn',
        onPressed: () => setState(() => _isZoomBarExpanded = true),
        backgroundColor: theme.colorScheme.surface,
        child: Icon(Icons.text_increase, color: theme.colorScheme.primary, size: 20),
      );
    }

    final double zoomPercent = (_fontSize / 13.5) * 100.0;

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
          // Zoom Out (Decrease Font)
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Smaller Font (-)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize - 1.5).clamp(8.0, 34.0);
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
                value: _fontSize.clamp(8.0, 34.0),
                min: 8.0,
                max: 34.0,
                onChanged: (val) {
                  setState(() {
                    _fontSize = val;
                  });
                },
              ),
            ),
          ),

          // Zoom In (Increase Font)
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Larger Font (+)',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize + 1.5).clamp(8.0, 34.0);
              });
            },
          ),

          const SizedBox(width: 4),

          // Percentage Badge (Tap to reset 100% / 13.5pt)
          InkWell(
            onTap: () => setState(() => _fontSize = 13.5),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${zoomPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Fit Screen / Word Wrap toggle
          IconButton(
            icon: Icon(_isWordWrap ? Icons.wrap_text : Icons.format_align_left, size: 18),
            tooltip: _isWordWrap ? 'Word Wrap ON (Fit Screen)' : 'Word Wrap OFF',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
          ),

          // Minimize
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
