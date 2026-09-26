import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:xml/xml.dart';
import '../../core/services/universal_encoding_service.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/errors/app_error_handler.dart';

/// Helper to parse highlighted code into line-by-line TextSpan groups.
/// This enables 100% synchronized row-by-row rendering with line numbers,
/// guaranteeing that line numbers NEVER desync, even with Word Wrap enabled.
List<List<TextSpan>> _parseHighlightedLines({
  required String source,
  required String? language,
  required Map<String, TextStyle> theme,
}) {
  final result = highlight.parse(
    source,
    language: (language != null && language != 'plaintext') ? language : null,
    autoDetection: language == null || language.isEmpty,
  );
  final nodes = result.nodes ?? [];

  List<List<TextSpan>> lines = [[]];

  void addTextSpan(String text, TextStyle? style) {
    if (text.isEmpty) return;
    // Replace tabs with 4 spaces for consistent code indentation
    final cleanText = text.replaceAll('\t', '    ');
    final parts = cleanText.split('\n');
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        lines.add([]);
      }
      if (parts[i].isNotEmpty) {
        lines.last.add(TextSpan(text: parts[i], style: style));
      }
    }
  }

  void traverse(Node node, TextStyle? inheritedStyle) {
    TextStyle? currentStyle = inheritedStyle;
    if (node.className != null && theme.containsKey(node.className!)) {
      currentStyle = currentStyle != null
          ? currentStyle.merge(theme[node.className!])
          : theme[node.className!];
    }

    if (node.value != null) {
      addTextSpan(node.value!, currentStyle);
    } else if (node.children != null) {
      for (final child in node.children!) {
        traverse(child, currentStyle);
      }
    }
  }

  for (final node in nodes) {
    traverse(node, null);
  }

  return lines;
}

class CodeViewerScreen extends StatefulWidget {
  final String filePath;

  const CodeViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<CodeViewerScreen> createState() => _CodeViewerScreenState();
}

class _CodeViewerScreenState extends State<CodeViewerScreen> {
  bool _isLoading = true;
  String? _error;
  String _fileContent = '';
  String _displayContent = '';
  int _fileSize = 0;
  String _encodingName = 'UTF-8';
  int _lineCount = 0;
  
  bool _isSearchOpen = false;
  bool _wordWrap = false;
  bool _isFormatted = false;
  bool _hideSecrets = true;
  double _fontSize = 13.5;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;

  late String _language;
  bool _isLargeFile = false;
  bool _showAsPlainText = false;

  List<List<TextSpan>> _lineSpans = [];
  double _maxLineWidth = 600.0;
  
  bool get _isJsonOrXml => _language == 'json' || _language == 'xml';
  bool get _isEnv => _language == 'bash' && widget.filePath.toLowerCase().endsWith('.env');
  String get _fileName {
    return widget.filePath.contains('/')
        ? widget.filePath.split('/').where((s) => s.isNotEmpty).last
        : widget.filePath.split(Platform.pathSeparator).last;
  }

  static String _detectLanguage(String fileName) {
    final name = fileName.contains('/')
        ? fileName.split('/').where((s) => s.isNotEmpty).last
        : fileName.split(Platform.pathSeparator).last;
    final nameLower = name.toLowerCase();

    // Filename-based detection (no extension)
    if (nameLower == 'dockerfile' ||
        nameLower.startsWith('dockerfile.') ||
        nameLower.endsWith('.dockerfile')) {
      return 'dockerfile';
    }
    if (nameLower == 'docker-compose.yml' ||
        nameLower == 'docker-compose.yaml' ||
        nameLower.startsWith('docker-compose.') &&
            (nameLower.endsWith('.yml') || nameLower.endsWith('.yaml'))) {
      return 'yaml';
    }
    if (nameLower == '.dockerignore') {
      return 'bash';
    }

    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart': return 'dart';
      case 'js': case 'mjs': return 'javascript';
      case 'ts': case 'tsx': return 'typescript';
      case 'py': case 'pyw': return 'python';
      case 'java': return 'java';
      case 'kt': case 'kts': return 'kotlin';
      case 'swift': return 'swift';
      case 'cpp': case 'cc': case 'cxx': return 'cpp';
      case 'c': return 'c';
      case 'h': case 'hpp': return 'cpp';
      case 'cs': return 'csharp';
      case 'go': return 'go';
      case 'rs': return 'rust';
      case 'php': return 'php';
      case 'rb': return 'ruby';
      case 'sh': case 'bash': return 'bash';
      case 'ps1': return 'powershell';
      case 'html': case 'htm': return 'xml';
      case 'css': return 'css';
      case 'json': return 'json';
      case 'xml': return 'xml';
      case 'yaml': case 'yml': return 'yaml';
      case 'toml': return 'ini';
      case 'ini': return 'ini';
      case 'env': return 'bash';
      case 'sql': return 'sql';
      case 'proto': return 'protobuf';
      case 'dockerfile': return 'dockerfile';
      default: return 'plaintext';
    }
  }

  @override
  void initState() {
    super.initState();
    _language = _detectLanguage(widget.filePath);
    _verticalController.addListener(_syncGutterScroll);
    _loadFile();
  }

  @override
  void dispose() {
    _verticalController.removeListener(_syncGutterScroll);
    _searchController.dispose();
    _verticalController.dispose();
    _gutterScrollController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _syncGutterScroll() {
    if (!_wordWrap && _gutterScrollController.hasClients && _verticalController.hasClients) {
      if ((_gutterScrollController.offset - _verticalController.offset).abs() > 0.5) {
        _gutterScrollController.jumpTo(_verticalController.offset);
      }
    }
  }

  double get _lineHeight {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(fontFamily: 'monospace', fontSize: _fontSize, height: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.preferredLineHeight;
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception("File not found");
      }

      _fileSize = await file.length();
      if (_fileSize > 500 * 1024) { // > 500KB
        _isLargeFile = true;
      }

      final bytes = await file.readAsBytes();
      final decoded = UniversalEncodingService.decodeBytesWithEncoding(bytes);
      
      _fileContent = decoded.text;
      _encodingName = decoded.encodingName;
      _lineCount = _fileContent.split('\n').length;
      
      _updateDisplayContent();

    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'CodeViewer._loadCodeFile.fs');
      _error = mounted ? context.l10n.fileNotFoundOrInaccessible : e.toString();
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'CodeViewer._loadCodeFile.format');
      _error = e.message;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'CodeViewer._loadCodeFile');
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateDisplayContent() {
    String content = _fileContent;
    
    if (_isJsonOrXml && _isFormatted) {
      try {
        if (_language == 'json') {
          final dynamic parsed = json.decode(content);
          content = const JsonEncoder.withIndent('  ').convert(parsed);
        } else if (_language == 'xml') {
          final document = XmlDocument.parse(content);
          content = document.toXmlString(pretty: true);
        }
      } on FormatException {
        // Fallback to raw if JSON parsing fails
      } on XmlException {
        // Fallback to raw if XML parsing fails
      }
    }

    if (_isEnv && _hideSecrets) {
      final lines = content.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('=') && !line.trim().startsWith('#')) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            lines[i] = '${parts[0]}=••••••••';
          }
        }
      }
      content = lines.join('\n');
    }

    _displayContent = content;
    _lineCount = _displayContent.split('\n').length;
    _searchMatches.clear();
    _currentMatchIndex = -1;

    _updateLineSpans();

    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _updateLineSpans() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = isDark ? atomOneDarkTheme : atomOneLightTheme;

    if (_showAsPlainText || (_isLargeFile && !_showAsPlainText)) {
      final rawLines = _displayContent.split('\n');
      _lineSpans = rawLines.map((l) => [TextSpan(text: l.isEmpty ? ' ' : l)]).toList();
    } else {
      try {
        _lineSpans = _parseHighlightedLines(
          source: _displayContent,
          language: _language,
          theme: theme,
        );
      } catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'CodeViewer._parseHighlightedLines');
        final rawLines = _displayContent.split('\n');
        _lineSpans = rawLines.map((l) => [TextSpan(text: l.isEmpty ? ' ' : l)]).toList();
      }
    }

    if (_lineSpans.isEmpty) {
      _lineSpans = [[const TextSpan(text: ' ')]];
    }
    _lineCount = _lineSpans.length;

    _calculateMaxLineWidth();
    setState(() {});
  }

  void _calculateMaxLineWidth() {
    if (_lineSpans.isEmpty) {
      _maxLineWidth = 600.0;
      return;
    }

    int maxIndex = 0;
    int maxLen = 0;
    for (int i = 0; i < _lineSpans.length; i++) {
      int len = 0;
      for (final span in _lineSpans[i]) {
        len += span.text?.length ?? 0;
      }
      if (len > maxLen) {
        maxLen = len;
        maxIndex = i;
      }
    }

    final longestSpans = _lineSpans[maxIndex];
    final defaultCodeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: 1.5,
    );

    final painter = TextPainter(
      text: TextSpan(
        style: defaultCodeStyle,
        children: longestSpans.isEmpty ? const [TextSpan(text: ' ')] : longestSpans,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _maxLineWidth = math.max(600.0, painter.width + 64.0);
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final lines = _displayContent.split('\n');
    final matches = <int>[];

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains(lowerQuery)) {
        matches.add(i);
      }
    }

    setState(() {
      _searchMatches = matches;
      if (_searchMatches.isNotEmpty) {
        _currentMatchIndex = 0;
        _scrollToMatch();
      } else {
        _currentMatchIndex = -1;
      }
    });
  }

  void _scrollToMatch() {
    if (_searchMatches.isEmpty || _currentMatchIndex < 0) return;
    final lineIndex = _searchMatches[_currentMatchIndex];
    final targetOffset = lineIndex * _lineHeight;

    if (_verticalController.hasClients) {
      final maxScroll = _verticalController.position.maxScrollExtent;
      _verticalController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _scrollToMatch();
  }

  void _prevMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _scrollToMatch();
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _displayContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content copied to clipboard')),
    );
  }

  void _shareContent() {
    Share.shareXFiles([XFile(widget.filePath)]);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color? _getLineHighlightColor(int lineIndex, bool isDark) {
    if (_searchMatches.isEmpty) return null;
    if (_currentMatchIndex >= 0 &&
        _currentMatchIndex < _searchMatches.length &&
        _searchMatches[_currentMatchIndex] == lineIndex) {
      return Colors.orange.withValues(alpha: isDark ? 0.35 : 0.25);
    }
    if (_searchMatches.contains(lineIndex)) {
      return Colors.yellow.withValues(alpha: isDark ? 0.20 : 0.15);
    }
    return null;
  }

  Widget _buildSearchBar() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _performSearch,
            ),
          ),
          const SizedBox(width: 8),
          if (_searchMatches.isNotEmpty)
            Text('${_currentMatchIndex + 1} / ${_searchMatches.length}'),
          if (_searchMatches.isEmpty && _searchController.text.isNotEmpty)
            const Text('0 / 0'),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _searchMatches.isNotEmpty ? _prevMatch : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _searchMatches.isNotEmpty ? _nextMatch : null,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BoxConstraints constraints) {
    if (_isLargeFile && !_showAsPlainText) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('This file is very large.'),
            const Text('Syntax highlighting might cause performance issues.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showAsPlainText = true;
                  _updateLineSpans();
                });
              },
              child: const Text('View as Plain Text'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLargeFile = false;
                  _updateLineSpans();
                });
              },
              child: const Text('Continue anyway'),
            ),
          ],
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = isDark ? atomOneDarkTheme : atomOneLightTheme;

    final defaultCodeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: 1.5,
      color: theme['root']?.color ?? (isDark ? Colors.white : Colors.black87),
    );

    final gutterStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize * 0.9,
      height: 1.5,
      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      fontWeight: FontWeight.w500,
    );

    final gutterBg = isDark ? const Color(0xFF21252B) : const Color(0xFFF3F4F6);
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    final digits = math.max(2, _lineCount.toString().length);
    final gutterWidth = digits * (_fontSize * 0.65) + 20.0;
    final lineHeight = _lineHeight;

    if (_wordWrap) {
      // WORD WRAP ENABLED:
      // Row-by-row synchronized line architecture.
      // Gutter cell and wrapped code are in the exact same Row(crossAxisAlignment: CrossAxisAlignment.start).
      // Line numbers NEVER desync, and stay pinned on the left edge.
      return ListView.builder(
        controller: _verticalController,
        itemCount: _lineSpans.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, i) {
          final highlight = _getLineHighlightColor(i, isDark);
          return Container(
            color: highlight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: gutterWidth,
                  decoration: BoxDecoration(
                    color: gutterBg,
                    border: Border(right: BorderSide(color: dividerColor)),
                  ),
                  padding: const EdgeInsets.only(right: 8),
                  alignment: Alignment.topRight,
                  child: Text(
                    '${i + 1}',
                    style: gutterStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text.rich(
                      TextSpan(
                        style: defaultCodeStyle,
                        children: _lineSpans[i].isEmpty ? const [TextSpan(text: ' ')] : _lineSpans[i],
                      ),
                      softWrap: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // WORD WRAP DISABLED:
      // Pinned gutter on the left (never scrolls horizontally, line numbers NEVER hidden).
      // Code scrolls horizontally with _horizontalController.
      // Both columns share identical line count and itemExtent: lineHeight for 100% sync.
      final codeAvailableWidth = math.max(constraints.maxWidth - gutterWidth, _maxLineWidth);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pinned Gutter (never moves horizontally)
          Container(
            width: gutterWidth,
            decoration: BoxDecoration(
              color: gutterBg,
              border: Border(right: BorderSide(color: dividerColor)),
            ),
            child: ListView.builder(
              controller: _gutterScrollController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lineSpans.length,
              itemExtent: lineHeight,
              padding: EdgeInsets.zero,
              itemBuilder: (context, i) {
                final highlight = _getLineHighlightColor(i, isDark);
                return Container(
                  height: lineHeight,
                  color: highlight,
                  padding: const EdgeInsets.only(right: 8),
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${i + 1}',
                    style: gutterStyle,
                  ),
                );
              },
            ),
          ),

          // Code area (scrolls horizontally)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SizedBox(
                width: codeAvailableWidth,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: _lineSpans.length,
                  itemExtent: lineHeight,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, i) {
                    final highlight = _getLineHighlightColor(i, isDark);
                    return Container(
                      height: lineHeight,
                      color: highlight,
                      padding: const EdgeInsets.only(left: 8, right: 16),
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: defaultCodeStyle,
                          children: _lineSpans[i].isEmpty ? const [TextSpan(text: ' ')] : _lineSpans[i],
                        ),
                        softWrap: false,
                        maxLines: 1,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        // Row 1: File Name Only
        title: Text(
          _fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: const [],
        // Row 2: Universal Controls Bar (horizontally scrollable, no overflow)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21252B) : Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Search Toggle
                  IconButton(
                    icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20),
                    tooltip: _isSearchOpen ? 'Close Search' : 'Search',
                    onPressed: () {
                      setState(() {
                        _isSearchOpen = !_isSearchOpen;
                        if (!_isSearchOpen) {
                          _searchController.clear();
                          _searchMatches.clear();
                          _currentMatchIndex = -1;
                        }
                      });
                    },
                  ),

                  // Word Wrap Toggle (Fit to Screen)
                  IconButton(
                    icon: Icon(_wordWrap ? Icons.wrap_text : Icons.format_align_left, size: 20),
                    color: _wordWrap ? Theme.of(context).colorScheme.primary : null,
                    tooltip: _wordWrap ? 'Disable Word Wrap' : 'Enable Word Wrap',
                    onPressed: () => setState(() => _wordWrap = !_wordWrap),
                  ),

                  // Copy All
                  IconButton(
                    icon: const Icon(Icons.copy_all_outlined, size: 20),
                    tooltip: 'Copy All',
                    onPressed: _copyContent,
                  ),

                  // Share
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share',
                    onPressed: _shareContent,
                  ),

                  // If JSON / XML: Pretty Print / Format Toggle
                  if (_isJsonOrXml)
                    IconButton(
                      icon: Icon(_isFormatted ? Icons.code_off : Icons.code, size: 20),
                      color: _isFormatted ? Theme.of(context).colorScheme.primary : null,
                      tooltip: _isFormatted ? 'Show Raw' : 'Pretty Print',
                      onPressed: () {
                        setState(() {
                          _isFormatted = !_isFormatted;
                          _updateDisplayContent();
                        });
                      },
                    ),

                  // If .env: Hide/Show Secrets Toggle
                  if (_isEnv)
                    IconButton(
                      icon: Icon(_hideSecrets ? Icons.visibility_off : Icons.visibility, size: 20),
                      color: _hideSecrets ? Theme.of(context).colorScheme.primary : null,
                      tooltip: _hideSecrets ? 'Show Secrets' : 'Hide Secrets',
                      onPressed: () {
                        setState(() {
                          _hideSecrets = !_hideSecrets;
                          _updateDisplayContent();
                        });
                      },
                    ),

                  // Plain Text vs Syntax Highlighting (for large files)
                  if (_isLargeFile)
                    IconButton(
                      icon: Icon(_showAsPlainText ? Icons.text_fields : Icons.code, size: 20),
                      tooltip: _showAsPlainText ? 'Enable Syntax Highlighting' : 'View as Plain Text',
                      onPressed: () {
                        setState(() {
                          _showAsPlainText = !_showAsPlainText;
                          _updateLineSpans();
                        });
                      },
                    ),

                  // Font Size Slider Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.format_size, size: 20),
                    tooltip: 'Font Size (${_fontSize.toStringAsFixed(1)})',
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: StatefulBuilder(
                          builder: (context, setPopupState) => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Font Size: ${_fontSize.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Slider(
                                value: _fontSize,
                                min: 10.0,
                                max: 22.0,
                                divisions: 12,
                                onChanged: (v) {
                                  setPopupState(() => _fontSize = v);
                                  setState(() {
                                    _fontSize = v;
                                    _updateLineSpans();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_isSearchOpen) _buildSearchBar(),
                    Expanded(
                      child: Container(
                        color: isDark
                            ? const Color(0xFF282C34) // atomOneDark bg
                            : const Color(0xFFFAFAFA), // atomOneLight bg
                        width: double.infinity,
                        height: double.infinity,
                        child: LayoutBuilder(
                          builder: (context, constraints) => _buildContent(constraints),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Size: ${_formatSize(_fileSize)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Lines: $_lineCount',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Encoding: $_encodingName',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Lang: $_language',
                              overflow: TextOverflow.ellipsis,
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
