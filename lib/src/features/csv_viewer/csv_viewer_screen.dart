import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

class CsvViewerScreen extends StatefulWidget {
  final String filePath;

  const CsvViewerScreen({super.key, required this.filePath});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  String _rawText = '';
  List<List<dynamic>> _rows = [];
  String _delimiter = ',';
  bool _isRawMode = false;
  
  String _searchQuery = '';
  int? _sortColumn;
  bool _sortAscending = true;
  
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }

      final bytes = await file.readAsBytes();
      final result = UniversalEncodingService.decodeBytesWithEncoding(bytes);
      _rawText = result.text;
      
      _delimiter = _detectDelimiter(_rawText);
      _parseCsv();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _detectDelimiter(String text) {
    final lines = text.split('\n').take(5).toList();
    if (lines.isEmpty) return ',';
    
    final counts = {',': 0, ';': 0, '\t': 0, '|': 0};
    for (final line in lines) {
      for (final delim in counts.keys) {
        counts[delim] = counts[delim]! + delim.allMatches(line).length;
      }
    }
    
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  void _parseCsv() {
    try {
      _rows = CsvDecoder(
        fieldDelimiter: _delimiter,
      ).convert(_rawText);
    } catch (e) {
      _rows = [];
    }
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumn == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnIndex;
        _sortAscending = true;
      }
      
      if (_rows.length > 1) {
        final headers = _rows.first;
        final dataRows = _rows.sublist(1);
        
        dataRows.sort((a, b) {
          final aValue = columnIndex < a.length ? a[columnIndex] : '';
          final bValue = columnIndex < b.length ? b[columnIndex] : '';
          final comp = aValue.toString().compareTo(bValue.toString());
          return _sortAscending ? comp : -comp;
        });
        
        _rows = [headers, ...dataRows];
      }
    });
  }

  List<List<dynamic>> get _filteredRows {
    if (_searchQuery.isEmpty || _rows.isEmpty) return _rows;
    final headers = _rows.first;
    final dataRows = _rows.sublist(1).where((row) {
      return row.any((cell) => cell.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
    return [headers, ...dataRows];
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
            icon: Icon(_isRawMode ? Icons.grid_on : Icons.text_snippet),
            tooltip: 'Toggle Raw Text',
            onPressed: () => setState(() => _isRawMode = !_isRawMode),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Delimiter',
            onSelected: (val) {
              setState(() {
                _delimiter = val;
                _parseCsv();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: ',', child: Text('Comma (,)')),
              const PopupMenuItem(value: ';', child: Text('Semicolon (;)')),
              const PopupMenuItem(value: '\t', child: Text('Tab (\\t)')),
              const PopupMenuItem(value: '|', child: Text('Pipe (|)')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Column(
                  children: [
                    if (!_isRawMode)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search rows...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    Expanded(
                      child: _isRawMode
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(_rawText),
                            )
                          : _buildDataTable(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      width: double.infinity,
                      child: Text(
                        '${_rows.isEmpty ? 0 : _rows.length - 1} rows x ${_rows.isEmpty ? 0 : _rows.first.length} cols | delimiter: ${_delimiter == '\t' ? 'TAB' : _delimiter}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDataTable() {
    if (_rows.isEmpty) return const Center(child: Text('Empty CSV'));
    
    final displayRows = _filteredRows;
    if (displayRows.isEmpty) return const Center(child: Text('No matches'));
    
    final headers = displayRows.first;
    final data = displayRows.sublist(1);
    
    final bool showNotice = data.length > 1000;
    final renderData = showNotice ? data.take(1000).toList() : data;

    return Column(
      children: [
        if (showNotice)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.amber.withOpacity(0.2),
            child: const Text('Showing first 1000 rows for performance', style: TextStyle(fontSize: 12)),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalController,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumn != null ? _sortColumn! + 1 : null,
                sortAscending: _sortAscending,
                columns: [
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...List.generate(headers.length, (i) {
                    return DataColumn(
                      label: Text(headers[i].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onSort: (columnIndex, ascending) => _onSort(columnIndex - 1),
                    );
                  }),
                ],
                rows: List.generate(renderData.length, (rowIndex) {
                  final row = renderData[rowIndex];
                  return DataRow(
                    cells: [
                      DataCell(Text('${rowIndex + 1}')),
                      ...List.generate(headers.length, (colIndex) {
                        return DataCell(Text(colIndex < row.length ? row[colIndex].toString() : ''));
                      }),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
