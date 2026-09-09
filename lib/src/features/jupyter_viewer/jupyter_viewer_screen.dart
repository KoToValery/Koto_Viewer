import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

class JupyterViewerScreen extends StatefulWidget {
  final String filePath;

  const JupyterViewerScreen({super.key, required this.filePath});

  @override
  State<JupyterViewerScreen> createState() => _JupyterViewerScreenState();
}

class _JupyterViewerScreenState extends State<JupyterViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _cells = [];
  String _nbformat = '';

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadNotebook();
  }

  Future<void> _loadNotebook() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final bytes = await file.readAsBytes();
      final decoded = UniversalEncodingService.decodeBytesWithEncoding(bytes);
      
      final Map<String, dynamic> notebook = json.decode(decoded.text);
      
      setState(() {
        _cells = notebook['cells'] ?? [];
        _nbformat = '${notebook['nbformat'] ?? '4'}.${notebook['nbformat_minor'] ?? '0'}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error parsing notebook:\n$_errorMessage', textAlign: TextAlign.center))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cells.length,
                        padding: const EdgeInsets.all(8.0),
                        itemBuilder: (context, index) {
                          final cell = _cells[index];
                          return _buildCell(cell, index);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      child: Text(
                        '${_cells.length} cells | nbformat $_nbformat',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCell(dynamic cell, int index) {
    final String type = cell['cell_type'] ?? '';
    final dynamic sourceData = cell['source'];
    final String source = sourceData is List
        ? sourceData.join('')
        : (sourceData?.toString() ?? '');

    if (type == 'markdown') {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.blue, width: 3)),
          ),
          padding: const EdgeInsets.all(12),
          child: MarkdownBody(data: source),
        ),
      );
    } else if (type == 'code') {
      final executionCount = cell['execution_count'];
      final List<dynamic> outputs = cell['outputs'] ?? [];

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.grey, width: 3)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (executionCount != null)
                Text('[$executionCount]:', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.black26 
                  : Colors.grey[200],
                child: SelectableText(
                  source,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              if (outputs.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...outputs.map((out) => _buildOutput(out)),
              ],
            ],
          ),
        ),
      );
    } else if (type == 'raw') {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Text(source, style: const TextStyle(fontFamily: 'monospace', color: Colors.grey)),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildOutput(dynamic output) {
    final type = output['output_type'];
    if (type == 'stream') {
      final dynamic textData = output['text'];
      final text = textData is List ? textData.join('') : textData.toString();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(top: 4),
        color: Colors.grey.withValues(alpha: 0.1),
        child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      );
    } else if (type == 'display_data' || type == 'execute_result') {
      final data = output['data'];
      if (data != null) {
        if (data['image/png'] != null) {
          final imgData = data['image/png'].toString().replaceAll('\n', '');
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Image.memory(base64Decode(imgData)),
          );
        } else if (data['image/jpeg'] != null) {
          final imgData = data['image/jpeg'].toString().replaceAll('\n', '');
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Image.memory(base64Decode(imgData)),
          );
        } else if (data['text/plain'] != null) {
          final dynamic textData = data['text/plain'];
          final text = textData is List ? textData.join('') : textData.toString();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(top: 4),
            color: Colors.grey.withValues(alpha: 0.1),
            child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}
