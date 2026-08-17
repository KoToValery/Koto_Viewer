import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _showLineNumbers = true;
  bool _isMonospace = true;
  bool _isWordWrap = true;
  double _fontSize = 13.5;

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _matchedLineIndices = [];
  int _currentMatchIndex = -1;

  final ScrollController _scrollController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadTextFile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

      String decodedText;
      try {
        decodedText = utf8.decode(bytes);
        _encodingName = 'UTF-8';
      } catch (_) {
        try {
          decodedText = latin1.decode(bytes);
          _encodingName = 'Latin-1 / ANSI';
        } catch (e) {
          decodedText = String.fromCharCodes(bytes);
          _encodingName = 'ASCII / Binary';
        }
      }

      _fullText = decodedText;
      _lines = decodedText.split(RegExp(r'\r?\n'));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_lines.length} lines • $_encodingName',
                    style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
        actions: [
          // Search Action
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
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
            icon: Icon(_isMonospace ? Icons.font_download : Icons.font_download_outlined),
            tooltip: _isMonospace ? 'Switch to Proportional Font' : 'Switch to Monospace Font',
            onPressed: () => setState(() => _isMonospace = !_isMonospace),
          ),

          // Word Wrap Toggle
          IconButton(
            icon: Icon(_isWordWrap ? Icons.wrap_text : Icons.format_align_left),
            tooltip: _isWordWrap ? 'Disable Word Wrap' : 'Enable Word Wrap',
            onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
          ),

          // Copy All
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy All',
            onPressed: _copyAllText,
          ),

          // Info / Properties
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Text Properties',
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

                    // Main Text Display Area
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
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
                                        width: 44,
                                        alignment: Alignment.topRight,
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.firaCode(
                                            fontSize: _fontSize * 0.85,
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
                                      child: _isWordWrap
                                          ? SelectableText(
                                              lineText.isEmpty ? ' ' : lineText,
                                              style: fontStyle,
                                            )
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: SelectableText(
                                                lineText.isEmpty ? ' ' : lineText,
                                                style: fontStyle,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Floating Font Sizing Controls
                          Positioned(
                            bottom: 20,
                            right: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.92),
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
                                        _fontSize = (_fontSize - 1.5).clamp(10.0, 28.0);
                                      });
                                    },
                                  ),
                                  Text(
                                    '${_fontSize.toStringAsFixed(0)}pt',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.text_increase, size: 18),
                                    tooltip: 'Larger Font',
                                    onPressed: () {
                                      setState(() {
                                        _fontSize = (_fontSize + 1.5).clamp(10.0, 28.0);
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
}
