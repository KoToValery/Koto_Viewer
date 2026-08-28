import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'excel_formula_evaluator.dart';

/// Interactive Excel Spreadsheet Viewer (.xlsx / .xls)
class XlsxViewerScreen extends StatefulWidget {
  final String filePath;

  const XlsxViewerScreen({super.key, required this.filePath});

  @override
  State<XlsxViewerScreen> createState() => _XlsxViewerScreenState();
}

class _XlsxViewerScreenState extends State<XlsxViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  xl.Excel? _excel;
  List<String> _sheetNames = [];
  String _activeSheetName = '';

  // Data cache for active sheet: 2D table of formatted strings
  List<List<String>> _sheetData = [];
  List<List<String?>> _sheetFormulas = [];
  int _maxRows = 0;
  int _maxCols = 0;
  List<double> _colWidths = [];

  // Selection & Inspector
  int _selectedRow = -1;
  int _selectedCol = -1;
  String _selectedCellValue = '';
  String? _selectedFormula;

  // Search
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _searchMatchCount = 0;

  // Zoom / Scale
  double _zoomScale = 1.0;

  // Synchronized scrolling
  final ScrollController _horizontalDataController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _verticalDataController = ScrollController();
  final ScrollController _verticalHeaderController = ScrollController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();

    // Link horizontal controllers
    _horizontalDataController.addListener(() {
      if (_horizontalHeaderController.hasClients &&
          _horizontalHeaderController.offset != _horizontalDataController.offset) {
        _horizontalHeaderController.jumpTo(_horizontalDataController.offset);
      }
    });

    // Link vertical controllers
    _verticalDataController.addListener(() {
      if (_verticalHeaderController.hasClients &&
          _verticalHeaderController.offset != _verticalDataController.offset) {
        _verticalHeaderController.jumpTo(_verticalDataController.offset);
      }
    });

    _loadExcelFile();
  }

  @override
  void dispose() {
    _horizontalDataController.dispose();
    _horizontalHeaderController.dispose();
    _verticalDataController.dispose();
    _verticalHeaderController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
      final delta = event.scrollDelta.dy < 0 ? 0.1 : -0.1;
      setState(() {
        _zoomScale = (_zoomScale + delta).clamp(0.4, 3.0);
      });
    }
  }

  Future<void> _loadExcelFile() async {
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

      final excel = xl.Excel.decodeBytes(bytes);
      final sheets = excel.tables.keys.toList();

      if (sheets.isEmpty) {
        throw Exception('No sheets found in Excel file.');
      }

      _excel = excel;
      _sheetNames = sheets;
      _activeSheetName = sheets.first;

      _extractActiveSheetData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading Excel file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _extractActiveSheetData() {
    if (_excel == null || !_excel!.tables.containsKey(_activeSheetName)) return;

    final table = _excel!.tables[_activeSheetName]!;
    _maxRows = table.maxRows;
    _maxCols = table.maxColumns;

    final List<List<String>> rows = List.generate(
      _maxRows,
      (_) => List.filled(_maxCols, ''),
    );
    final List<List<String?>> formulas = List.generate(
      _maxRows,
      (_) => List.filled(_maxCols, null),
    );
    final List<double> widths = List.filled(_maxCols, 80.0);

    // Pass 1: Extract direct values and identify formula cells
    for (int r = 0; r < _maxRows; r++) {
      final rowData = table.row(r);
      for (int c = 0; c < _maxCols; c++) {
        if (c < rowData.length && rowData[c] != null) {
          final val = rowData[c]?.value;
          if (val is xl.FormulaCellValue) {
            formulas[r][c] = val.formula;
          } else {
            rows[r][c] = _formatCellValue(val);
          }
        }
      }
    }

    // Pass 2: Evaluate formulas into calculated values
    for (int r = 0; r < _maxRows; r++) {
      for (int c = 0; c < _maxCols; c++) {
        final formula = formulas[r][c];
        if (formula != null) {
          final evaluated = ExcelFormulaEvaluator.evaluate(
            formula: formula,
            getCellValue: (row, col) {
              if (row >= 0 && row < _maxRows && col >= 0 && col < _maxCols) {
                return rows[row][col];
              }
              return null;
            },
            maxRows: _maxRows,
            maxCols: _maxCols,
          );
          rows[r][c] = evaluated;
        }

        // Estimate column width from character count (Cyrillic & Latin)
        final cellValue = rows[r][c];
        final estimatedWidth = math.max(80.0, math.min(380.0, cellValue.length * 9.5 + 24.0));
        if (estimatedWidth > widths[c]) {
          widths[c] = estimatedWidth;
        }
      }
    }

    _sheetData = rows;
    _sheetFormulas = formulas;
    _colWidths = widths;
    _selectedRow = -1;
    _selectedCol = -1;
    _selectedCellValue = '';
    _selectedFormula = null;
    _calculateSearchMatches();
  }

  String _formatCellValue(dynamic val) {
    if (val == null) return '';

    // Handle excel 4.0.6 typed values
    if (val is xl.TextCellValue) {
      return val.value.text ?? '';
    } else if (val is xl.IntCellValue) {
      return val.value.toString();
    } else if (val is xl.DoubleCellValue) {
      final double d = val.value;
      if (d == d.roundToDouble()) {
        return d.toStringAsFixed(0);
      }
      return d.toStringAsFixed(2);
    } else if (val is xl.BoolCellValue) {
      return val.value ? 'TRUE' : 'FALSE';
    } else if (val is xl.FormulaCellValue) {
      return val.formula;
    } else if (val is xl.DateTimeCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    } else if (val is xl.DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    } else if (val is xl.TimeCellValue) {
      return '${val.hour.toString().padLeft(2, '0')}:${val.minute.toString().padLeft(2, '0')}';
    }

    return val.toString();
  }

  String _getColumnLetter(int colIndex) {
    String result = '';
    int col = colIndex;
    while (col >= 0) {
      result = String.fromCharCode((col % 26) + 65) + result;
      col = (col ~/ 26) - 1;
    }
    return result;
  }

  void _onSheetSelected(String sheetName) {
    if (_activeSheetName == sheetName) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeSheetName = sheetName;
      _extractActiveSheetData();
    });
  }

  void _onCellTapped(int r, int c) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
      _selectedCellValue = (r < _sheetData.length && c < _sheetData[r].length) ? _sheetData[r][c] : '';
      _selectedFormula = (r < _sheetFormulas.length && c < _sheetFormulas[r].length) ? _sheetFormulas[r][c] : null;
    });
  }

  void _calculateSearchMatches() {
    if (_searchQuery.trim().isEmpty) {
      _searchMatchCount = 0;
      return;
    }
    final q = _searchQuery.toLowerCase();
    int count = 0;
    for (final row in _sheetData) {
      for (final cell in row) {
        if (cell.toLowerCase().contains(q)) {
          count++;
        }
      }
    }
    _searchMatchCount = count;
  }

  void _showSheetsMenu() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart_outlined, color: Color(0xFF107C41)),
                      const SizedBox(width: 10),
                      Text(
                        'Workbook Sheets (${_sheetNames.length})',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sheetNames.length,
                    itemBuilder: (context, index) {
                      final name = _sheetNames[index];
                      final isSelected = name == _activeSheetName;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle : Icons.article_outlined,
                          color: isSelected ? const Color(0xFF107C41) : Colors.grey,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF107C41) : null,
                          ),
                        ),
                        trailing: Text(
                          'Sheet ${index + 1}',
                          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _onSheetSelected(name);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showInfoSheet() {
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
                      color: const Color(0xFF107C41).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: Color(0xFF107C41)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Excel Spreadsheet • Properties',
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
              _buildInfoRow('Total Sheets:', '${_sheetNames.length} sheets'),
              _buildInfoRow('Active Sheet:', _activeSheetName),
              _buildInfoRow('Grid Dimensions:', '$_maxRows rows × $_maxCols columns'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cellBgOdd = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cellBgEven = isDark ? const Color(0xFF242424) : const Color(0xFFF9FAFB);
    final headerBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);
    final gridLineColor = isDark ? const Color(0xFF383838) : const Color(0xFFD1D5DB);

    const double rowHeight = 34.0;
    const double rowHeaderWidth = 46.0;

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
                  hintText: 'Search in active sheet...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _searchMatchCount = 0;
                      });
                    },
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _calculateSearchMatches();
                  });
                },
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

                // Search Toggle
                IconButton(
                  icon: Icon(_isSearchOpen ? Icons.close : Icons.search, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _isSearchOpen ? 'Close Search' : 'Search in Sheet',
                  onPressed: () {
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (!_isSearchOpen) {
                        _searchQuery = '';
                        _searchController.clear();
                        _searchMatchCount = 0;
                      }
                    });
                  },
                ),

                // Sheets List Quick Button
                IconButton(
                  icon: const Icon(Icons.table_chart_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'All Sheets',
                  onPressed: _showSheetsMenu,
                ),

                // Info / Properties
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Spreadsheet Properties',
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
                  CircularProgressIndicator(color: Color(0xFF107C41)),
                  SizedBox(height: 16),
                  Text('Loading Spreadsheet...'),
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
                          onPressed: _loadExcelFile,
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
                    if (_searchQuery.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: Color(0xFFF57C00)),
                            const SizedBox(width: 8),
                            Text(
                              'Found $_searchMatchCount ${_searchMatchCount == 1 ? "match" : "matches"} in "$_activeSheetName"',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF57C00),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Top Formula / Cell Inspector Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF107C41).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF107C41).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _selectedRow >= 0 && _selectedCol >= 0
                                  ? '${_getColumnLetter(_selectedCol)}${_selectedRow + 1}'
                                  : 'Cell',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF107C41),
                              ),
                            ),
                          ),
                          if (_selectedFormula != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'fx',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _selectedFormula != null
                                  ? Row(
                                      children: [
                                        Text(
                                          '=${_selectedFormula!.startsWith('=') ? _selectedFormula!.substring(1) : _selectedFormula}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(Result: $_selectedCellValue)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                            color: theme.textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _selectedCellValue.isEmpty
                                          ? 'Tap any cell to inspect content'
                                          : _selectedCellValue,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _selectedCellValue.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                        color: _selectedCellValue.isEmpty ? Colors.grey : null,
                                      ),
                                    ),
                            ),
                          ),
                          if (_selectedCellValue.isNotEmpty || _selectedFormula != null)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Copy Cell Text',
                              onPressed: () {
                                final textToCopy = _selectedFormula != null
                                    ? '=${_selectedFormula!.startsWith('=') ? _selectedFormula!.substring(1) : _selectedFormula}\nResult: $_selectedCellValue'
                                    : _selectedCellValue;
                                Clipboard.setData(ClipboardData(text: textToCopy));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cell content copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    // Main 2D Grid Table with Sticky Headers
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (_maxRows == 0 || _maxCols == 0) {
                            return const Center(child: Text('Sheet is empty.'));
                          }

                          final totalWidth = _colWidths.fold<double>(0.0, (sum, w) => sum + w);
                          final scaledRowHeight = rowHeight * _zoomScale;

                          return Listener(
                            onPointerSignal: _handlePointerSignal,
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    // Top Row: Corner + Sticky Column Headers
                                    Row(
                                      children: [
                                        // Top-Left Corner Box
                                        Container(
                                          width: rowHeaderWidth,
                                          height: scaledRowHeight,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: headerBg,
                                            border: Border.all(color: gridLineColor, width: 0.5),
                                          ),
                                          child: const Icon(Icons.grid_4x4, size: 14, color: Colors.grey),
                                        ),
                                        // Sticky Column Headers (A, B, C...)
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: _horizontalHeaderController,
                                            scrollDirection: Axis.horizontal,
                                            physics: const ClampingScrollPhysics(),
                                            child: SizedBox(
                                              width: totalWidth * _zoomScale,
                                              height: scaledRowHeight,
                                              child: Row(
                                                children: List.generate(_maxCols, (c) {
                                                  final colW = _colWidths[c] * _zoomScale;
                                                  final isColSelected = _selectedCol == c;
                                                  return Container(
                                                    width: colW,
                                                    height: scaledRowHeight,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: isColSelected
                                                          ? const Color(0xFF107C41).withValues(alpha: 0.25)
                                                          : headerBg,
                                                      border: Border.all(color: gridLineColor, width: 0.5),
                                                    ),
                                                    child: Text(
                                                      _getColumnLetter(c),
                                                      style: TextStyle(
                                                        fontSize: 12 * _zoomScale.clamp(0.8, 1.2),
                                                        fontWeight: FontWeight.bold,
                                                        color: isColSelected
                                                            ? const Color(0xFF107C41)
                                                            : theme.textTheme.bodyMedium?.color,
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Body Area: Sticky Row Numbers + Data Grid
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // Sticky Row Numbers (1, 2, 3...)
                                          SizedBox(
                                            width: rowHeaderWidth,
                                            child: SingleChildScrollView(
                                              controller: _verticalHeaderController,
                                              scrollDirection: Axis.vertical,
                                              physics: const ClampingScrollPhysics(),
                                              child: Column(
                                                children: List.generate(_maxRows, (r) {
                                                  final isRowSelected = _selectedRow == r;
                                                  return Container(
                                                    width: rowHeaderWidth,
                                                    height: scaledRowHeight,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: isRowSelected
                                                          ? const Color(0xFF107C41).withValues(alpha: 0.25)
                                                          : headerBg,
                                                      border: Border.all(color: gridLineColor, width: 0.5),
                                                    ),
                                                    child: Text(
                                                      '${r + 1}',
                                                      style: TextStyle(
                                                        fontSize: 11 * _zoomScale.clamp(0.8, 1.2),
                                                        fontWeight: FontWeight.bold,
                                                        color: isRowSelected
                                                            ? const Color(0xFF107C41)
                                                            : theme.textTheme.bodySmall?.color,
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                          ),

                                          // Data Cells 2D Grid
                                          Expanded(
                                            child: SingleChildScrollView(
                                              controller: _horizontalDataController,
                                              scrollDirection: Axis.horizontal,
                                              physics: const ClampingScrollPhysics(),
                                              child: SingleChildScrollView(
                                                controller: _verticalDataController,
                                                scrollDirection: Axis.vertical,
                                                physics: const ClampingScrollPhysics(),
                                                child: SizedBox(
                                                  width: totalWidth * _zoomScale,
                                                  child: Column(
                                                    children: List.generate(_maxRows, (r) {
                                                      final rowBg = r % 2 == 0 ? cellBgEven : cellBgOdd;
                                                      return SizedBox(
                                                        height: scaledRowHeight,
                                                        child: Row(
                                                          children: List.generate(_maxCols, (c) {
                                                            final colW = _colWidths[c] * _zoomScale;
                                                            final cellText = (r < _sheetData.length &&
                                                                    c < _sheetData[r].length)
                                                                ? _sheetData[r][c]
                                                                : '';
                                                            final isSelected = _selectedRow == r && _selectedCol == c;
                                                            final isSearchMatch = _searchQuery.trim().isNotEmpty &&
                                                                cellText
                                                                    .toLowerCase()
                                                                    .contains(_searchQuery.toLowerCase());

                                                            return InkWell(
                                                              onTap: () => _onCellTapped(r, c),
                                                              child: Container(
                                                                width: colW,
                                                                height: scaledRowHeight,
                                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                                alignment: Alignment.centerLeft,
                                                                decoration: BoxDecoration(
                                                                  color: isSelected
                                                                      ? const Color(0xFF107C41).withValues(alpha: 0.3)
                                                                      : isSearchMatch
                                                                          ? const Color(0xFFFFD54F).withValues(alpha: 0.6)
                                                                          : rowBg,
                                                                  border: Border.all(
                                                                    color: isSelected
                                                                        ? const Color(0xFF107C41)
                                                                        : gridLineColor,
                                                                    width: isSelected ? 1.5 : 0.5,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  cellText,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontSize: 12.5 * _zoomScale.clamp(0.8, 1.4),
                                                                    color: isSearchMatch && !isDark
                                                                        ? Colors.black87
                                                                        : null,
                                                                    fontWeight: isSearchMatch
                                                                        ? FontWeight.bold
                                                                        : FontWeight.normal,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Floating Zoom Controls (+ / - / 100%)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
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
                                          icon: const Icon(Icons.remove, size: 18),
                                          tooltip: 'Zoom Out',
                                          onPressed: () {
                                            setState(() {
                                              _zoomScale = (_zoomScale - 0.2).clamp(0.5, 2.5);
                                            });
                                          },
                                        ),
                                        InkWell(
                                          onTap: () => setState(() => _zoomScale = 1.0),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: Text(
                                              '${(_zoomScale * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 18),
                                          tooltip: 'Zoom In',
                                          onPressed: () {
                                            setState(() {
                                              _zoomScale = (_zoomScale + 0.2).clamp(0.5, 2.5);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Sheet Tabs Strip (Like Excel / Sheets)
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_open_rounded, size: 20),
                            tooltip: 'All Sheets (${_sheetNames.length})',
                            onPressed: _showSheetsMenu,
                          ),
                          const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              itemCount: _sheetNames.length,
                              itemBuilder: (context, index) {
                                final name = _sheetNames[index];
                                final isSelected = name == _activeSheetName;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Material(
                                    color: isSelected
                                        ? const Color(0xFF107C41).withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _onSheetSelected(name),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF107C41)
                                                : theme.dividerColor.withValues(alpha: 0.25),
                                            width: isSelected ? 1.5 : 0.8,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.table_chart,
                                              size: 14,
                                              color: isSelected ? const Color(0xFF107C41) : Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? const Color(0xFF107C41) : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
