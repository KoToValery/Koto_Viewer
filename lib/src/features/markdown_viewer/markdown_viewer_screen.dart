import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Markdown Viewer Screen (.md / .markdown)
class MarkdownViewerScreen extends StatefulWidget {
  final String filePath;

  const MarkdownViewerScreen({super.key, required this.filePath});

  @override
  State<MarkdownViewerScreen> createState() => _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends State<MarkdownViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  String _markdownContent = '';
  bool _showRawSource = false;

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadMarkdownFile();
  }

  Future<void> _loadMarkdownFile() async {
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

      _markdownContent = UniversalEncodingService.decodeBytes(bytes);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading markdown: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLinkTap(String text, String? href, String title) async {
    if (href == null || href.isEmpty) return;
    try {
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showInfoSheet() {
    final theme = Theme.of(context);
    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    final linesCount = _markdownContent.split(RegExp(r'\r?\n')).length;
    final wordCount = _markdownContent.trim().isEmpty ? 0 : _markdownContent.trim().split(RegExp(r'\s+')).length;
    final headingsCount = RegExp(r'^#{1,6}\s', multiLine: true).allMatches(_markdownContent).length;

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
                      color: const Color(0xFF4338CA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF4338CA)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Markdown Document • Properties',
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
              _buildInfoRow('Total Headings:', '$headingsCount headings'),
              _buildInfoRow('Total Lines:', '$linesCount lines'),
              _buildInfoRow('Total Words:', '$wordCount words'),
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

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _markdownContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markdown copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
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
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),

                // Raw Source Toggle
                IconButton(
                  icon: Icon(_showRawSource ? Icons.visibility : Icons.code, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _showRawSource ? 'Formatted View' : 'Raw Markdown Source',
                  onPressed: () => setState(() => _showRawSource = !_showRawSource),
                ),

                // Copy Content
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Copy Markdown',
                  onPressed: _copyContent,
                ),

                // Info / Properties
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Markdown Properties',
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
                  CircularProgressIndicator(color: Color(0xFF4338CA)),
                  SizedBox(height: 16),
                  Text('Loading Markdown Document...'),
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
                          onPressed: _loadMarkdownFile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _showRawSource
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _markdownContent,
                        style: GoogleFonts.firaCode(fontSize: 13.5, height: 1.5),
                      ),
                    )
                  : Markdown(
                      data: _markdownContent,
                      selectable: true,
                      onTapLink: _handleLinkTap,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
                        h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, height: 1.4),
                        h3: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, height: 1.4),
                        p: const TextStyle(fontSize: 14.5, height: 1.6),
                        code: GoogleFonts.firaCode(
                          fontSize: 13,
                          backgroundColor: isDark
                              ? const Color(0xFF2D3748)
                              : const Color(0xFFEDF2F7),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(color: theme.colorScheme.primary, width: 4),
                          ),
                        ),
                        tableBorder: TableBorder.all(
                          color: theme.dividerColor.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
    );
  }
}
