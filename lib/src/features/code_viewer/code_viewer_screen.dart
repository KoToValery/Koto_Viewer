import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:xml/xml.dart';
import '../../core/services/universal_encoding_service.dart';

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
  bool _showLineNumbers = true;
  bool _wordWrap = false;
  bool _isFormatted = false;
  bool _hideSecrets = true;
  double _fontSize = 13.5;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;

  late String _language;
  bool _isLargeFile = false;
  bool _showAsPlainText = false;
  
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

    // --- Filename-based detection (no extension) ---
    // Dockerfile, Dockerfile.prod, Dockerfile.dev, etc.
    if (nameLower == 'dockerfile' ||
        nameLower.startsWith('dockerfile.') ||
        nameLower.endsWith('.dockerfile')) {
      return 'dockerfile';
    }
    // docker-compose files
    if (nameLower == 'docker-compose.yml' ||
        nameLower == 'docker-compose.yaml' ||
        nameLower.startsWith('docker-compose.') &&
            (nameLower.endsWith('.yml') || nameLower.endsWith('.yaml'))) {
      return 'yaml';
    }
    // .dockerignore
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
    _loadFile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
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

    } catch (e) {
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
      } catch (e) {
        // Fallback to raw if parsing fails
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

    setState(() {
      _displayContent = content;
      _lineCount = _displayContent.split('\n').length;
      _searchMatches.clear();
      _currentMatchIndex = -1;
    });
    
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
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
    
    // Estimate scroll position (rough estimation based on font size + padding)
    final estimatedLineHeight = _fontSize * 1.5; // Rough estimate
    final targetOffset = lineIndex * estimatedLineHeight;
    
    if (_verticalController.hasClients) {
      final maxScroll = _verticalController.position.maxScrollExtent;
      _verticalController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
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

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              _isSearchOpen = !_isSearchOpen;
              if (!_isSearchOpen) {
                _searchController.clear();
                _searchMatches.clear();
              }
            });
          },
          tooltip: 'Search',
        ),
        IconButton(
          icon: Icon(_showLineNumbers ? Icons.format_list_numbered : Icons.format_list_bulleted),
          onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
          tooltip: 'Toggle Line Numbers',
        ),
        IconButton(
          icon: Icon(_wordWrap ? Icons.wrap_text : Icons.subject),
          onPressed: () => setState(() => _wordWrap = !_wordWrap),
          tooltip: 'Toggle Word Wrap',
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copyContent,
          tooltip: 'Copy',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareContent,
          tooltip: 'Share',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'format') {
              setState(() {
                _isFormatted = !_isFormatted;
                _updateDisplayContent();
              });
            } else if (value == 'secrets') {
              setState(() {
                _hideSecrets = !_hideSecrets;
                _updateDisplayContent();
              });
            } else if (value == 'text_mode') {
              setState(() {
                _showAsPlainText = !_showAsPlainText;
              });
            }
          },
          itemBuilder: (context) => [
            if (_isJsonOrXml)
              PopupMenuItem(
                value: 'format',
                child: Text(_isFormatted ? 'Show Raw' : 'Pretty Print'),
              ),
            if (_isEnv)
              PopupMenuItem(
                value: 'secrets',
                child: Text(_hideSecrets ? 'Show Secrets' : 'Hide Secrets'),
              ),
            if (_isLargeFile)
              PopupMenuItem(
                value: 'text_mode',
                child: Text(_showAsPlainText ? 'Use Syntax Highlighting' : 'View as Plain Text'),
              ),
            PopupMenuItem(
              value: 'font',
              child: StatefulBuilder(
                builder: (context, setPopupState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Font Size: ${_fontSize.toStringAsFixed(1)}'),
                    Slider(
                      value: _fontSize,
                      min: 10.0,
                      max: 20.0,
                      onChanged: (v) {
                        setPopupState(() => _fontSize = v);
                        setState(() => _fontSize = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
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

  Widget _buildContent() {
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
              onPressed: () => setState(() => _showAsPlainText = true),
              child: const Text('View as Plain Text'),
            ),
            TextButton(
              onPressed: () => setState(() => _isLargeFile = false),
              child: const Text('Continue anyway'),
            ),
          ],
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = isDark ? atomOneDarkTheme : atomOneLightTheme;

    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: 1.5,
    );

    Widget viewer;

    if (_showAsPlainText) {
      viewer = Container(
        width: _wordWrap ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        child: Text(
          _displayContent,
          style: textStyle.copyWith(color: isDark ? Colors.white : Colors.black),
        ),
      );
    } else {
      viewer = HighlightView(
        _displayContent,
        language: _language,
        theme: theme,
        padding: const EdgeInsets.all(16),
        textStyle: textStyle,
      );
    }

    // Overlay search highlights
    Widget searchOverlay = const SizedBox.shrink();
    if (_searchMatches.isNotEmpty) {
      searchOverlay = Positioned.fill(
        child: CustomPaint(
          painter: _SearchHighlightPainter(
            matches: _searchMatches,
            currentMatch: _searchMatches[_currentMatchIndex],
            lineHeight: _fontSize * 1.5,
            paddingTop: 16.0,
          ),
        ),
      );
    }

    Widget content = Stack(
      children: [
        viewer,
        if (_searchMatches.isNotEmpty) searchOverlay,
      ],
    );

    if (_showLineNumbers) {
      final lines = _displayContent.split('\n');
      final lineNumbers = lines.asMap().keys.map((i) => '${i + 1}').join('\n');

      final lineNumbersWidget = Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
        child: Text(
          lineNumbers,
          style: textStyle.copyWith(
            color: isDark ? Colors.white54 : Colors.black54,
          ),
          textAlign: TextAlign.right,
        ),
      );

      if (_wordWrap) {
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lineNumbersWidget,
            Expanded(child: content),
          ],
        );
      } else {
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lineNumbersWidget,
            content,
          ],
        );
      }
    }

    if (_wordWrap) {
      return SingleChildScrollView(
        controller: _verticalController,
        child: content,
      );
    } else {
      return SingleChildScrollView(
        controller: _verticalController,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: content,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          _fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _buildToolbar(),
        ],
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF282C34) // atomOneDark bg
                            : const Color(0xFFFAFAFA), // atomOneLight bg
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildContent(),
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

class _SearchHighlightPainter extends CustomPainter {
  final List<int> matches;
  final int currentMatch;
  final double lineHeight;
  final double paddingTop;

  _SearchHighlightPainter({
    required this.matches,
    required this.currentMatch,
    required this.lineHeight,
    required this.paddingTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final match in matches) {
      if (match == currentMatch) {
        paint.color = Colors.orange.withValues(alpha: 0.5);
      } else {
        paint.color = Colors.yellow.withValues(alpha: 0.3);
      }

      final top = paddingTop + (match * lineHeight);
      canvas.drawRect(
        Rect.fromLTWH(0, top, size.width, lineHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SearchHighlightPainter oldDelegate) {
    return oldDelegate.matches != matches ||
        oldDelegate.currentMatch != currentMatch ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.paddingTop != paddingTop;
  }
}
