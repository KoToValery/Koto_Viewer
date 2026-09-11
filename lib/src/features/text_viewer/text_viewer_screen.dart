import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/services/recent_files_service.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';
import 'package:kotoview/src/core/services/reading_progress_service.dart';
import 'models/text_reflow_models.dart';
import 'widgets/text_reflow_view.dart';

enum LogLevelFilter { all, error, warn, info, debug }

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

  LogLevelFilter _logLevelFilter = LogLevelFilter.all;

  // Reflow / E-Book Reading Mode
  bool _isReflowMode = false;
  TextReflowSettings _reflowSettings = const TextReflowSettings();
  int? _resumedChapter;
  int? _resumedMiniPage;
  double? _resumedFraction;

  // Options
  bool _showLineNumbers = false; // User requested to default off
  bool _isMonospace = true;
  bool _isWordWrap = true;
  double _fontSize = 13.5;
  bool _isZoomBarExpanded = false;
  bool _isFullscreen = false;

  // Bookmarks & Reading Progress
  List<BookmarkItem> _bookmarks = [];

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<int> _matchedLineIndices = [];
  int _currentMatchIndex = -1;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  bool get _isLogFile {
    if (_fileName.toLowerCase().endsWith('.log')) return true;
    int count = 0;
    for (final line in _lines) {
      final l = line.toUpperCase();
      if (l.contains('ERROR') || l.contains('WARN') || l.contains('INFO') || l.contains('DEBUG')) {
        count++;
        if (count >= 5) return true;
      }
    }
    return false;
  }

  List<String> get _filteredLines {
    if (!_isLogFile || _logLevelFilter == LogLevelFilter.all) return _lines;
    return _lines.where((line) {
      final l = line.toUpperCase();
      switch (_logLevelFilter) {
        case LogLevelFilter.error:
          return l.contains('ERROR') || l.contains('FATAL');
        case LogLevelFilter.warn:
          return l.contains('WARN');
        case LogLevelFilter.info:
          return l.contains('INFO');
        case LogLevelFilter.debug:
          return l.contains('DEBUG') || l.contains('TRACE');
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadReflowSettings();
    _loadTextFile();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _saveReadingProgress();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReflowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('txt_reflow_is_enabled') ?? false;
      final fontSize = prefs.getDouble('txt_reflow_font_size') ?? 17.0;
      final themeIndex = prefs.getInt('txt_reflow_theme') ?? TextReflowTheme.sepia.index;
      final fontIndex = prefs.getInt('txt_reflow_font') ?? TextReflowFont.serif.index;
      final modeIndex = prefs.getInt('txt_reflow_mode') ?? TextReflowMode.paginated.index;
      final lineHeight = prefs.getDouble('txt_reflow_line_height') ?? 1.6;

      if (mounted) {
        setState(() {
          // If it's a log file, default to raw code view, otherwise use preference
          _isReflowMode = _isLogFile ? false : isEnabled;
          _reflowSettings = TextReflowSettings(
            fontSize: fontSize,
            theme: TextReflowTheme.values.elementAtOrNull(themeIndex) ?? TextReflowTheme.sepia,
            font: TextReflowFont.values.elementAtOrNull(fontIndex) ?? TextReflowFont.serif,
            mode: TextReflowMode.values.elementAtOrNull(modeIndex) ?? TextReflowMode.paginated,
            lineHeight: lineHeight,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _saveReflowSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('txt_reflow_is_enabled', _isReflowMode);
      await prefs.setDouble('txt_reflow_font_size', _reflowSettings.fontSize);
      await prefs.setInt('txt_reflow_theme', _reflowSettings.theme.index);
      await prefs.setInt('txt_reflow_font', _reflowSettings.font.index);
      await prefs.setInt('txt_reflow_mode', _reflowSettings.mode.index);
      await prefs.setDouble('txt_reflow_line_height', _reflowSettings.lineHeight);
    } catch (_) {}
  }

  void _toggleReflowMode() {
    setState(() {
      _isReflowMode = !_isReflowMode;
    });
    _saveReflowSettings();
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

      // Load saved progress and bookmarks
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      if (progress != null) {
        _bookmarks = progress.bookmarks;
        _resumedChapter = progress.chapter;
        _resumedMiniPage = progress.miniPage;
        _resumedFraction = progress.progressFraction;
      } else {
        _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (progress != null && progress.scrollOffset > 0 && !_isReflowMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _verticalScrollController.hasClients) {
              _verticalScrollController.jumpTo(
                progress.scrollOffset.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Resumed reading position'),
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
          _errorMessage = 'Error reading text file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _saveReadingProgress() {
    if (_isReflowMode) return;
    if (!_verticalScrollController.hasClients) return;
    final offset = _verticalScrollController.offset;
    final max = _verticalScrollController.position.maxScrollExtent;
    final fraction = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;

    ReadingProgressService.saveProgress(
      widget.filePath,
      scrollOffset: offset,
      progressFraction: fraction,
    );
  }

  Future<void> _toggleBookmark() async {
    if (_isReflowMode) {
      final progress = await ReadingProgressService.getProgress(widget.filePath);
      final currentChapter = progress?.chapter ?? 0;
      final currentMiniPage = progress?.miniPage ?? 0;
      final totalPercent = ((progress?.progressFraction ?? 0.0) * 100).round();

      final newBookmark = BookmarkItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        page: currentMiniPage + 1,
        chapter: currentChapter,
        miniPage: currentMiniPage,
        label: 'Pg. ${currentMiniPage + 1} ($totalPercent%)',
        snippet: 'Reading position ($totalPercent%)',
        createdAt: DateTime.now(),
      );

      await ReadingProgressService.addBookmark(widget.filePath, newBookmark);
      _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            content: Text('Bookmarked Page ${currentMiniPage + 1} ($totalPercent%)'),
          ),
        );
      }
      return;
    }

    final offset = _verticalScrollController.hasClients ? _verticalScrollController.offset : 0.0;
    final max = _verticalScrollController.hasClients ? _verticalScrollController.position.maxScrollExtent : 1.0;
    final percent = max > 0 ? ((offset / max) * 100).toInt() : 0;

    // Estimate current line
    final lineIndex = ((offset / (max > 0 ? max : 1.0)) * (_lines.isNotEmpty ? _lines.length : 1)).clamp(0, _lines.length - 1).toInt();
    final snippet = _lines.isNotEmpty && lineIndex < _lines.length && _lines[lineIndex].trim().isNotEmpty
        ? _lines[lineIndex].trim()
        : 'Line ${lineIndex + 1}';

    final newBookmark = BookmarkItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      page: lineIndex + 1,
      label: 'Line ${lineIndex + 1} ($percent%)',
      snippet: snippet.length > 60 ? '${snippet.substring(0, 57)}...' : snippet,
      createdAt: DateTime.now(),
    );

    await ReadingProgressService.addBookmark(widget.filePath, newBookmark);
    _bookmarks = await ReadingProgressService.getBookmarks(widget.filePath);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          content: Text('Bookmarked Line ${lineIndex + 1}'),
        ),
      );
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
                                  'No bookmarks saved yet.\nTap the bookmark icon to save your place.',
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
                                        setSheetState(() {});
                                        setState(() {});
                                      },
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (_isReflowMode) {
                                        setState(() {
                                          _resumedChapter = b.chapter ?? 0;
                                          _resumedMiniPage = b.miniPage ?? math.max(0, b.page - 1);
                                        });
                                      } else if (_verticalScrollController.hasClients && _lines.isNotEmpty) {
                                        final targetFraction = (b.page - 1) / _lines.length;
                                        final targetOffset = targetFraction * _verticalScrollController.position.maxScrollExtent;
                                        _verticalScrollController.animateTo(
                                          targetOffset,
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
      _matchedLineIndices.clear();
      _currentMatchIndex = -1;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final currentLines = _filteredLines;
        for (int i = 0; i < currentLines.length; i++) {
          if (currentLines[i].toLowerCase().contains(q)) {
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
              _buildInfoRow('Total Lines:', _isLogFile && _logLevelFilter != LogLevelFilter.all ? '${_filteredLines.length} / ${_lines.length} lines' : '${_lines.length} lines'),
              _buildInfoRow('Total Words:', '$wordCount words'),
              _buildInfoRow('Total Characters:', '${_fullText.length} chars'),
              _buildInfoRow('Detected Encoding:', _encodingName),
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

  Widget _buildLogFilterBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: LogLevelFilter.values.map((filter) {
          final isSelected = _logLevelFilter == filter;
          String label;
          switch (filter) {
            case LogLevelFilter.all: label = 'All'; break;
            case LogLevelFilter.error: label = 'ERROR'; break;
            case LogLevelFilter.warn: label = 'WARN'; break;
            case LogLevelFilter.info: label = 'INFO'; break;
            case LogLevelFilter.debug: label = 'DEBUG'; break;
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _logLevelFilter = filter;
                    // Reset search since lines changed
                    _matchedLineIndices.clear();
                    _currentMatchIndex = -1;
                    if (_searchQuery.isNotEmpty) {
                      _onSearchChanged(_searchQuery); // Re-run search
                    }
                  });
                }
              },
            ),
          );
        }).toList(),
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

    final currentLines = _filteredLines;

    return Scaffold(
      backgroundColor: _isReflowMode ? _reflowSettings.theme.backgroundColor : theme.scaffoldBackgroundColor,
      appBar: _isFullscreen ? null : AppBar(
        backgroundColor: _isReflowMode ? _reflowSettings.theme.surfaceColor : theme.colorScheme.surface,
        foregroundColor: _isReflowMode ? _reflowSettings.theme.textColor : null,
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
            decoration: BoxDecoration(
              color: _isReflowMode ? _reflowSettings.theme.surfaceColor : null,
              border: Border(
                bottom: BorderSide(
                  color: _isReflowMode
                      ? _reflowSettings.theme.textColor.withValues(alpha: 0.1)
                      : (isDark ? Colors.white10 : Colors.black12),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
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

                  // Reading Mode (Reflow / Overflow / E-Book)
                  IconButton(
                    icon: Icon(
                      _isReflowMode ? Icons.auto_stories : Icons.auto_stories_outlined,
                      size: 20,
                      color: _isReflowMode ? _reflowSettings.theme.accentColor : null,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: _isReflowMode
                        ? 'Exit Reading Mode (Code/Log View)'
                        : 'Reading Mode (Reflow / Overflow / E-Book)',
                    onPressed: _toggleReflowMode,
                  ),

                  // Bookmark button
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Add Bookmark',
                    onPressed: _toggleBookmark,
                  ),

                  // Bookmarks list
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _bookmarks.isNotEmpty,
                      label: Text('${_bookmarks.length}'),
                      child: const Icon(Icons.bookmarks_outlined, size: 20),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Bookmarks',
                    onPressed: _showBookmarksSheet,
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

                  // Line Numbers Toggle
                  IconButton(
                    icon: Icon(_showLineNumbers ? Icons.format_list_numbered : Icons.format_list_numbered_rtl, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: _showLineNumbers ? 'Hide Line Numbers' : 'Show Line Numbers',
                    onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
                  ),

                  // Fullscreen
                  IconButton(
                    icon: const Icon(Icons.fullscreen, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: 'Fullscreen',
                    onPressed: _toggleFullscreen,
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
                    if (!_isReflowMode && _isLogFile) _buildLogFilterBar(),

                    // Search Match Status Bar with Next/Prev
                    if (!_isReflowMode && _searchQuery.isNotEmpty)
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

                    // Main Text Display Area (Reflow E-Book View or Raw Line View)
                    Expanded(
                      child: _isReflowMode
                          ? TextReflowView(
                              fullText: _fullText,
                              fileName: _fileName,
                              filePath: widget.filePath,
                              settings: _reflowSettings,
                              onSettingsChanged: (newSettings) {
                                setState(() {
                                  _reflowSettings = newSettings;
                                });
                                _saveReflowSettings();
                              },
                              onExitReflow: () {
                                setState(() {
                                  _isReflowMode = false;
                                });
                                _saveReflowSettings();
                              },
                              bookmarks: _bookmarks,
                              onToggleBookmark: _toggleBookmark,
                              onShowBookmarks: _showBookmarksSheet,
                              onToggleFullscreen: _toggleFullscreen,
                              isFullscreen: _isFullscreen,
                              initialChapter: _resumedChapter,
                              initialMiniPage: _resumedMiniPage,
                              initialFraction: _resumedFraction,
                            )
                          : Stack(
                              children: [
                                _isWordWrap
                                    ? ListView.builder(
                                        controller: _verticalScrollController,
                                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                                        itemCount: currentLines.length,
                                        itemBuilder: (context, index) => _buildLineItem(
                                          index,
                                          currentLines[index],
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
                                              itemCount: currentLines.length,
                                              itemBuilder: (context, index) => _buildLineItem(
                                                index,
                                                currentLines[index],
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
                                  bottom: 20 + MediaQuery.paddingOf(context).bottom,
                                  right: 20,
                                  child: _buildZoomControls(theme),
                                ),

                                if (_isFullscreen)
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: FloatingActionButton.small(
                                      heroTag: 'exit_fullscreen',
                                      onPressed: _toggleFullscreen,
                                      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.8),
                                      child: Icon(Icons.fullscreen_exit, color: theme.colorScheme.onSurface),
                                    ),
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
    String lineText,
    TextStyle fontStyle,
    Color lineGutterColor,
    Color gutterBg,
  ) {
    final isCurrentMatch = _matchedLineIndices.isNotEmpty &&
        _currentMatchIndex >= 0 &&
        _matchedLineIndices[_currentMatchIndex] == index;
    final isMatch = _matchedLineIndices.contains(index);

    Color? lineBgColor;
    if (_isLogFile) {
      final l = lineText.toUpperCase();
      if (l.contains('ERROR') || l.contains('FATAL')) {
        lineBgColor = Colors.red.withValues(alpha: 0.15);
      } else if (l.contains('WARN') || l.contains('WARNING')) {
        lineBgColor = Colors.orange.withValues(alpha: 0.15);
      } else if (l.contains('DEBUG') || l.contains('TRACE')) {
        lineBgColor = Colors.blue.withValues(alpha: 0.08);
      }
    }

    return Container(
      color: isCurrentMatch
          ? const Color(0xFFFFD54F).withValues(alpha: 0.45)
          : isMatch
              ? const Color(0xFFFFD54F).withValues(alpha: 0.2)
              : lineBgColor,
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
