import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import 'models/ebook_models.dart';
import 'parser/ebook_parser.dart';

/// Digital E-Book Reader Screen (.epub, .fb2, .fb2.zip).
/// Features full Cyrillic & international script support, customizable typography
/// (font size, line height, themes: Light, Warm Sepia, Dark Charcoal, AMOLED),
/// Table of Contents, Chapter navigation, inline images, search, and reading progress.
class EbookViewerScreen extends StatefulWidget {
  final String filePath;
  const EbookViewerScreen({super.key, required this.filePath});
  @override
  State<EbookViewerScreen> createState() => _EbookViewerScreenState();
}

class _EbookViewerScreenState extends State<EbookViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;
  EbookBook? _book;
  int _currentChapterIndex = 0;
  EbookSettings _settings = const EbookSettings();
  bool _showControls = true;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<int> _matchedChapterIndices = [];
  final ScrollController _scrollController = ScrollController();
  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) throw Exception('File not found: ' + widget.filePath);
      _fileSizeBytes = await file.length();
      final book = await EbookParser.parseFromFile(widget.filePath);
      if (mounted) setState(() { _book = book; _isLoading = false; });
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) setState(() { _errorMessage = 'Error loading e-book: ' + e.toString(); _isLoading = false; });
    }
  }

  void _goToChapter(int index) {
    if (_book == null || index < 0 || index >= _book!.chapters.length) return;
    setState(() { _currentChapterIndex = index; });
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
  }

  void _toggleControls() {
    setState(() { _showControls = !_showControls; });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      _matchedChapterIndices.clear();
      if (_searchQuery.isNotEmpty && _book != null) {
        for (int i = 0; i < _book!.chapters.length; i++) {
          if (_book!.chapters[i].rawText.toLowerCase().contains(_searchQuery) ||
              _book!.chapters[i].title.toLowerCase().contains(_searchQuery)) {
            _matchedChapterIndices.add(i);
          }
        }
      }
    });
  }

  void _showTypographySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _settings.themeMode.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final textColor = _settings.themeMode.textColor;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Reading & Typography', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('Size', style: TextStyle(fontSize: 14, color: textColor)),
                    const Spacer(),
                    IconButton.filledTonal(onPressed: _settings.fontSize > 12.0 ? () { setState(() { _settings = _settings.copyWith(fontSize: _settings.fontSize - 1.5); }); setSheetState(() {}); } : null, icon: const Icon(Icons.remove, size: 18)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_settings.fontSize.toInt().toString() + ' pt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor))),
                    IconButton.filledTonal(onPressed: _settings.fontSize < 36.0 ? () { setState(() { _settings = _settings.copyWith(fontSize: _settings.fontSize + 1.5); }); setSheetState(() {}); } : null, icon: const Icon(Icons.add, size: 18)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('Theme', style: TextStyle(fontSize: 14, color: textColor)),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: EbookThemeMode.values.map((mode) {
                      final isSelected = _settings.themeMode == mode;
                      return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(mode.label), selected: isSelected, avatar: Container(width: 14, height: 14, decoration: BoxDecoration(color: mode.backgroundColor, shape: BoxShape.circle, border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1))), onSelected: (selected) { if (selected) { setState(() { _settings = _settings.copyWith(themeMode: mode); }); setSheetState(() {}); } }));
                    }).toList()))),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('Font', style: TextStyle(fontSize: 14, color: textColor)),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: EbookFontFamily.values.map((font) {
                      final isSelected = _settings.fontFamily == font;
                      return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(font.label), selected: isSelected, onSelected: (selected) { if (selected) { setState(() { _settings = _settings.copyWith(fontFamily: font); }); setSheetState(() {}); } }));
                    }).toList()))),
                  ]),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Line Spacing', style: TextStyle(fontSize: 14, color: textColor)),
                    SegmentedButton<double>(segments: const [ButtonSegment(value: 1.4, label: Text('Tight')), ButtonSegment(value: 1.65, label: Text('Normal')), ButtonSegment(value: 1.95, label: Text('Relaxed'))], selected: {_settings.lineHeight}, onSelectionChanged: (set) { setState(() { _settings = _settings.copyWith(lineHeight: set.first); }); setSheetState(() {}); }),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTocSheet() {
    if (_book == null) return;
    final currentTheme = _settings.themeMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
          builder: (context, scrollController) {
            return Column(children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: currentTheme.textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Icon(Icons.format_list_bulleted_rounded, color: currentTheme.accentColor),
                const SizedBox(width: 10),
                Text('Table of Contents (' + _book!.chapters.length.toString() + ')', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: currentTheme.textColor)),
              ])),
              const Divider(height: 1),
              Expanded(child: ListView.separated(
                controller: scrollController,
                itemCount: _book!.chapters.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chapter = _book!.chapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  return ListTile(
                    selected: isCurrent,
                    selectedTileColor: currentTheme.accentColor.withValues(alpha: 0.12),
                    leading: CircleAvatar(radius: 14, backgroundColor: isCurrent ? currentTheme.accentColor : currentTheme.textColor.withValues(alpha: 0.1), child: Text((index + 1).toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : currentTheme.textColor))),
                    title: Text(chapter.title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, fontSize: 14, color: currentTheme.textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text('~' + (chapter.wordCount / 200).ceil().toString() + ' min', style: TextStyle(fontSize: 11, color: currentTheme.textColor.withValues(alpha: 0.6))),
                    onTap: () { Navigator.pop(context); _goToChapter(index); },
                  );
                },
              )),
            ]);
          },
        );
      },
    );
  }

  void _showInfoSheet() {
    if (_book == null) return;
    final meta = _book!.metadata;
    final currentTheme = _settings.themeMode;
    final formattedSize = _fileSizeBytes < 1024 * 1024 ? (_fileSizeBytes / 1024).toStringAsFixed(1) + ' KB' : (_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2) + ' MB';
    showModalBottomSheet(
      context: context,
      backgroundColor: currentTheme.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: currentTheme.textColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (meta.coverBytes != null)
                  Container(width: 60, height: 84, margin: const EdgeInsets.only(right: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]), clipBehavior: Clip.antiAlias, child: Image.memory(meta.coverBytes!, fit: BoxFit.cover))
                else
                  Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(right: 14), decoration: BoxDecoration(color: currentTheme.accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.book_rounded, color: currentTheme.accentColor, size: 28)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meta.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: currentTheme.textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(meta.authorString, style: TextStyle(fontSize: 13, color: currentTheme.textColor.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_fileName, style: TextStyle(fontSize: 11.5, color: currentTheme.textColor.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const Divider(height: 24),
              _buildInfoRow('Format:', _book!.format.name.toUpperCase(), currentTheme),
              _buildInfoRow('Total Chapters:', _book!.chapterCount.toString() + ' chapters', currentTheme),
              _buildInfoRow('Total Word Count:', _book!.totalWordCount.toString() + ' words', currentTheme),
              _buildInfoRow('Est. Reading Time:', '~' + _book!.estimatedReadTimeMinutes.toString() + ' minutes', currentTheme),
              _buildInfoRow('File Size:', formattedSize, currentTheme),
              if (meta.publisher != null && meta.publisher!.isNotEmpty) _buildInfoRow('Publisher:', meta.publisher!, currentTheme),
              if (meta.publicationDate != null && meta.publicationDate!.isNotEmpty) _buildInfoRow('Published Date:', meta.publicationDate!, currentTheme),
              if (meta.language != null && meta.language!.isNotEmpty) _buildInfoRow('Language:', meta.language!, currentTheme),
              if (meta.genre != null && meta.genre!.isNotEmpty) _buildInfoRow('Genre:', meta.genre!, currentTheme),
              if (meta.description != null && meta.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Annotation / Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: currentTheme.textColor)),
                const SizedBox(height: 4),
                Text(meta.description!, style: TextStyle(fontSize: 12.5, color: currentTheme.textColor.withValues(alpha: 0.8)), maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, EbookThemeMode theme) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: theme.textColor.withValues(alpha: 0.7))),
      const SizedBox(width: 8),
      Flexible(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textColor), overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
    ]));
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _settings.themeMode;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_errorMessage != null) RecentFilesService.removeRecentFile(widget.filePath);
      },
      child: Scaffold(
        backgroundColor: currentTheme.backgroundColor,
        appBar: _showControls ? AppBar(
          backgroundColor: currentTheme.surfaceColor,
          foregroundColor: currentTheme.textColor,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
            if (_errorMessage != null) RecentFilesService.removeRecentFile(widget.filePath);
            Navigator.of(context).pop(_errorMessage == null);
          }),
          title: _isSearchOpen ? TextField(controller: _searchController, autofocus: true, style: TextStyle(color: currentTheme.textColor, fontSize: 15), decoration: InputDecoration(hintText: 'Search in book text...', hintStyle: TextStyle(color: currentTheme.textColor.withValues(alpha: 0.5)), border: InputBorder.none), onChanged: _onSearchChanged) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_book?.title ?? _fileName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_book != null && _book!.chapters.isNotEmpty) Text(_book!.chapters[_currentChapterIndex].title, style: TextStyle(fontSize: 11.5, color: currentTheme.textColor.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
          actions: [
            IconButton(icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20), tooltip: 'Search Book', onPressed: () { setState(() { _isSearchOpen = !_isSearchOpen; if (!_isSearchOpen) { _searchController.clear(); _searchQuery = ''; _matchedChapterIndices.clear(); } }); }),
            IconButton(icon: const Icon(Icons.format_list_bulleted_rounded, size: 20), tooltip: 'Table of Contents', onPressed: _showTocSheet),
            IconButton(icon: const Icon(Icons.text_format_rounded, size: 20), tooltip: 'Typography & Theme', onPressed: _showTypographySheet),
            IconButton(icon: const Icon(Icons.info_outline, size: 20), tooltip: 'Book Info', onPressed: _showInfoSheet),
            IconButton(icon: const Icon(Icons.share_outlined, size: 20), tooltip: 'Share', onPressed: _shareFile),
          ],
        ) : null,
        body: GestureDetector(
          onTap: _toggleControls,
          child: _isLoading ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: currentTheme.accentColor), const SizedBox(height: 16), Text('Opening E-Book...', style: TextStyle(color: currentTheme.textColor.withValues(alpha: 0.7)))])) : _errorMessage != null ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.redAccent), const SizedBox(height: 16), Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: currentTheme.textColor)), const SizedBox(height: 16), ElevatedButton.icon(onPressed: _loadBook, icon: const Icon(Icons.refresh), label: const Text('Retry'))]))) : _book == null || _book!.chapters.isEmpty ? Center(child: Text('No content found', style: TextStyle(color: currentTheme.textColor))) : Stack(children: [
            _buildChapterContentView(currentTheme),
            if (_isSearchOpen && _searchQuery.isNotEmpty) _buildSearchResultsOverlay(currentTheme),
            if (_showControls && !_isSearchOpen) _buildBottomNavigationBar(currentTheme),
          ]),
        ),
      ),
    );
  }

  Widget _buildChapterContentView(EbookThemeMode theme) {
    final chapter = _book!.chapters[_currentChapterIndex];
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(_settings.horizontalPadding, 24, _settings.horizontalPadding, _showControls ? 100 : 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(bottom: 24.0), child: Text(chapter.title, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 1.35, color: theme.textColor, height: 1.3, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        for (final block in chapter.blocks) _buildBlockWidget(block, theme),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (_currentChapterIndex > 0) OutlinedButton.icon(onPressed: () => _goToChapter(_currentChapterIndex - 1), icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Prev Chapter')) else const SizedBox.shrink(),
          if (_currentChapterIndex < _book!.chapters.length - 1) FilledButton.icon(onPressed: () => _goToChapter(_currentChapterIndex + 1), icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('Next Chapter')) else const Text('End of Book', style: TextStyle(fontStyle: FontStyle.italic)),
        ]),
      ]),
    );
  }

  Widget _buildBlockWidget(EbookBlock block, EbookThemeMode theme) {
    switch (block.type) {
      case EbookBlockType.heading1:
        return Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 12.0), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 1.3, color: theme.textColor, height: 1.3, fontWeight: FontWeight.bold)));
      case EbookBlockType.heading2:
        return Padding(padding: const EdgeInsets.only(top: 16.0, bottom: 8.0), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 1.18, color: theme.textColor, height: 1.3, fontWeight: FontWeight.bold)));
      case EbookBlockType.heading3:
        return Padding(padding: const EdgeInsets.only(top: 12.0, bottom: 6.0), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 1.08, color: theme.textColor, height: 1.3, fontWeight: FontWeight.w600)));
      case EbookBlockType.paragraph:
        return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize, color: theme.textColor, height: _settings.lineHeight, fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal, fontStyle: block.isItalic ? FontStyle.italic : FontStyle.normal), textAlign: _settings.textAlign));
      case EbookBlockType.quote:
      case EbookBlockType.epigraph:
        return Container(margin: const EdgeInsets.symmetric(vertical: 12.0), padding: const EdgeInsets.fromLTRB(16, 10, 12, 10), decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.accentColor, width: 3.5)), color: theme.textColor.withValues(alpha: 0.04), borderRadius: const BorderRadius.horizontal(right: Radius.circular(6))), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 0.95, color: theme.textColor.withValues(alpha: 0.9), height: _settings.lineHeight, fontStyle: FontStyle.italic)));
      case EbookBlockType.poem:
        return Container(margin: const EdgeInsets.symmetric(vertical: 12.0), padding: const EdgeInsets.only(left: 24.0), child: Text(block.text, style: _settings.fontFamily.getTextStyle(fontSize: _settings.fontSize * 0.95, color: theme.textColor, height: _settings.lineHeight, fontStyle: FontStyle.italic)));
      case EbookBlockType.image:
        if (block.imageBytes != null) return Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(block.imageBytes!, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const SizedBox.shrink()))));
        return const SizedBox.shrink();
      case EbookBlockType.divider:
        return Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text('* * *', style: TextStyle(color: theme.textColor.withValues(alpha: 0.4), letterSpacing: 4, fontWeight: FontWeight.bold))));
    }
  }

  Widget _buildSearchResultsOverlay(EbookThemeMode theme) {
    return Container(
      color: theme.surfaceColor.withValues(alpha: 0.96),
      child: _matchedChapterIndices.isEmpty ? Center(child: Text('No matches found for "' + _searchQuery + '"', style: TextStyle(color: theme.textColor.withValues(alpha: 0.6)))) : ListView.separated(
        itemCount: _matchedChapterIndices.length,
        separatorBuilder: (ctx, idx) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final chIdx = _matchedChapterIndices[idx];
          final ch = _book!.chapters[chIdx];
          return ListTile(
            leading: Icon(Icons.search, color: theme.accentColor, size: 20),
            title: Text(ch.title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Chapter ' + (chIdx + 1).toString(), style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 12)),
            onTap: () { setState(() { _isSearchOpen = false; }); _goToChapter(chIdx); },
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(EbookThemeMode theme) {
    final totalChapters = _book!.chapters.length;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.surfaceColor.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: theme.textColor.withValues(alpha: 0.1))),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          Text((_currentChapterIndex + 1).toString(), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Slider(
            value: _currentChapterIndex.toDouble(),
            min: 0, max: (totalChapters - 1).toDouble(),
            divisions: totalChapters > 1 ? totalChapters - 1 : 1,
            activeColor: theme.accentColor,
            inactiveColor: theme.textColor.withValues(alpha: 0.2),
            onChanged: (val) { _goToChapter(val.round()); },
          )),
          Text(totalChapters.toString(), style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13)),
        ]),
      ),
    );
  }
}
