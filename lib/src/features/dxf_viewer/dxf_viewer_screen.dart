import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import '../home/widgets/share_options_sheet.dart';
import 'models/dxf_models.dart';
import 'parser/dxf_parser.dart';
import 'rendering/dxf_math.dart';
import 'rendering/dxf_painter.dart';
import 'widgets/dxf_info_sheet.dart';
import 'widgets/dxf_layer_sheet.dart';
import 'widgets/dxf_measurement_overlay.dart';
import 'widgets/dxf_search_bar.dart';

class DxfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const DxfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<DxfViewerScreen> createState() => _DxfViewerScreenState();
}

class _DxfViewerScreenState extends State<DxfViewerScreen> {
  final TransformationController _transformController = TransformationController();
  final TextEditingController _searchController = TextEditingController();

  DxfDocument? _document;
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;
  int _fileSizeBytes = 0;

  // View state
  DxfCanvasTheme _canvasTheme = DxfCanvasTheme.darkCad;
  bool _showGrid = true;
  double _currentScale = 1.0;
  Offset _currentCadCoord = Offset.zero;

  // Measurement tool
  bool _isMeasureMode = false;
  DxfMeasurement? _measurement;

  // Search tool
  bool _isSearchOpen = false;
  List<DxfEntity> _searchMatches = [];
  int _currentSearchIdx = 0;

  // Layout & viewport
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _transformController.addListener(_onTransformChanged);
    _loadDxfFile();
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.001) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  Future<void> _loadDxfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File does not exist: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      _fileSizeBytes = await file.length();
      final doc = await DxfParser.parseFromFile(file);

      setState(() {
        _document = doc;
        _isLoading = false;
      });

      _saveToRecentFiles();

      // Fit to screen after frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToScreen();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open DXF file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToRecentFiles() async {
    try {
      final pdfItem = PdfItem(
        path: widget.filePath,
        name: _fileName,
        sizeInBytes: _fileSizeBytes,
        lastOpened: DateTime.now(),
      );
      await RecentFilesService.addRecentFile(pdfItem);
    } catch (_) {}
  }

  /// Fit the entire DXF drawing inside the available viewport.
  void _fitToScreen() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    _zoomBy(1.35);
  }

  void _zoomOut() {
    _zoomBy(1 / 1.35);
  }

  void _zoomBy(double factor) {
    if (_viewportSize.isEmpty) return;

    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentMatrix = _transformController.value;

    final translation = currentMatrix.getTranslation();
    final scale = currentMatrix.getMaxScaleOnAxis();

    final newScale = (scale * factor).clamp(0.001, 1000.0);

    // Zoom centered on viewport center
    final dx = center.dx - (center.dx - translation.x) * (newScale / scale);
    final dy = center.dy - (center.dy - translation.y) * (newScale / scale);

    final newMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);

    _transformController.value = newMatrix;
  }

  Offset _sceneToCad(Offset scenePoint) {
    if (_document == null || _viewportSize.isEmpty) return Offset.zero;

    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);

    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double fitScale = math.min(availW / docW, availH / docH);

    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = _document!.bounds.left;
    final double maxY = _document!.bounds.bottom > _document!.bounds.top
        ? _document!.bounds.bottom
        : _document!.bounds.top;

    final double cadX = minX + (scenePoint.dx - tx) / fitScale;
    final double cadY = maxY - (scenePoint.dy - ty) / fitScale;

    return Offset(cadX, cadY);
  }

  Offset _cadToScene(Offset cadPoint) {
    if (_document == null || _viewportSize.isEmpty) return Offset.zero;

    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);

    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double fitScale = math.min(availW / docW, availH / docH);

    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = _document!.bounds.left;
    final double maxY = _document!.bounds.bottom > _document!.bounds.top
        ? _document!.bounds.bottom
        : _document!.bounds.top;

    final double sceneX = tx + (cadPoint.dx - minX) * fitScale;
    final double sceneY = ty + (maxY - cadPoint.dy) * fitScale;

    return Offset(sceneX, sceneY);
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (_document == null) return;

    final scenePoint = _transformController.toScene(details.localPosition);
    final cadPoint = _sceneToCad(scenePoint);

    setState(() {
      _currentCadCoord = cadPoint;
    });

    if (_isMeasureMode) {
      setState(() {
        if (_measurement == null || _measurement!.p2Cad != null) {
          _measurement = DxfMeasurement(p1Cad: cadPoint);
        } else {
          _measurement = DxfMeasurement(
            p1Cad: _measurement!.p1Cad,
            p2Cad: cadPoint,
          );
        }
      });
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (_document == null) return;
    final scenePoint = _transformController.toScene(event.localPosition);
    final cadPoint = _sceneToCad(scenePoint);

    setState(() {
      _currentCadCoord = cadPoint;
    });
  }

  // --- Search Logic ---
  void _onSearchChanged(String query) {
    if (_document == null || query.trim().isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentSearchIdx = 0;
      });
      return;
    }

    final q = query.trim().toLowerCase();
    final matches = <DxfEntity>[];

    for (final e in _document!.entities) {
      if (e is DxfText && e.text.toLowerCase().contains(q)) {
        matches.add(e);
      } else if (e is DxfMText && e.cleanText.toLowerCase().contains(q)) {
        matches.add(e);
      } else if (e is DxfDimension && (e.textOverride?.toLowerCase().contains(q) ?? false)) {
        matches.add(e);
      }
    }

    setState(() {
      _searchMatches = matches;
      _currentSearchIdx = 0;
    });

    if (matches.isNotEmpty) {
      _jumpToMatch(0);
    }
  }

  void _jumpToMatch(int index) {
    if (_searchMatches.isEmpty || _document == null || _viewportSize.isEmpty) return;
    final entity = _searchMatches[index];

    Offset? pos;
    if (entity is DxfText) {
      pos = entity.alignPoint ?? entity.insertPoint;
    } else if (entity is DxfMText) {
      pos = entity.insertPoint;
    } else if (entity is DxfDimension) {
      pos = entity.textPoint;
    }

    if (pos != null) {
      final scenePoint = _cadToScene(pos);
      const double zoomLevel = 4.0;
      final tx = _viewportSize.width / 2 - scenePoint.dx * zoomLevel;
      final ty = _viewportSize.height / 2 - scenePoint.dy * zoomLevel;

      final matrix = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(zoomLevel);

      _transformController.value = matrix;
    }
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentSearchIdx = (_currentSearchIdx + 1) % _searchMatches.length;
    });
    _jumpToMatch(_currentSearchIdx);
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentSearchIdx = (_currentSearchIdx - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _jumpToMatch(_currentSearchIdx);
  }

  void _showLayersSheet() {
    if (_document == null) return;
    DxfLayerSheet.show(
      context: context,
      document: _document!,
      isDark: _canvasTheme.isDark,
      onLayersChanged: () {
        setState(() {});
      },
    );
  }

  void _showInfoSheet() {
    if (_document == null) return;
    DxfInfoSheet.show(
      context: context,
      document: _document!,
      fileName: _fileName,
      fileSizeBytes: _fileSizeBytes,
    );
  }

  void _shareDxf() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareOptionsSheet(filePath: widget.filePath),
    );
  }

  Future<void> _printDxf() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print preview unavailable: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _canvasTheme.bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_document != null)
              Text(
                '${_document!.totalEntities} entities • ${_document!.totalLayers} layers',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
        actions: [
          // Fit to screen (Zoom Extents)
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit to Screen (Zoom Extents)',
            onPressed: _document != null ? _fitToScreen : null,
          ),

          // Layer Manager
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'CAD Layers',
            onPressed: _document != null ? _showLayersSheet : null,
          ),

          // Measurement Tool
          IconButton(
            icon: Icon(
              Icons.straighten,
              color: _isMeasureMode ? const Color(0xFFFF5252) : null,
            ),
            tooltip: _isMeasureMode ? 'Exit Measure Mode' : 'Measure Distance',
            onPressed: _document != null
                ? () {
                    setState(() {
                      _isMeasureMode = !_isMeasureMode;
                      if (!_isMeasureMode) _measurement = null;
                    });
                  }
                : null,
          ),

          // Search in Drawing
          IconButton(
            icon: Icon(
              Icons.search,
              color: _isSearchOpen ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Search Text',
            onPressed: _document != null
                ? () {
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (!_isSearchOpen) {
                        _searchController.clear();
                        _searchMatches = [];
                      }
                    });
                  }
                : null,
          ),

          // Theme / Background Popup
          PopupMenuButton<DxfCanvasTheme>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Canvas Background Theme',
            initialValue: _canvasTheme,
            onSelected: (t) {
              setState(() {
                _canvasTheme = t;
              });
            },
            itemBuilder: (context) => DxfCanvasTheme.values.map((t) {
              return PopupMenuItem(
                value: t,
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: t.bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(t.name),
                    if (t == _canvasTheme) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // More Options (Info, Share, Print)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showInfoSheet();
                  break;
                case 'grid':
                  setState(() {
                    _showGrid = !_showGrid;
                  });
                  break;
                case 'share':
                  _shareDxf();
                  break;
                case 'print':
                  _printDxf();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'grid',
                child: Row(
                  children: [
                    Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20),
                    const SizedBox(width: 12),
                    Text(_showGrid ? 'Hide CAD Grid' : 'Show CAD Grid'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 12),
                    const Text('Drawing Properties'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Share File'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Print / Export'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

            if (_isLoading) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading CAD Drawing...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDxfFile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_document == null) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: [
                // Interactive CAD Canvas
                MouseRegion(
                  onHover: _handlePointerHover,
                  child: GestureDetector(
                    onTapUp: _handleCanvasTap,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.01,
                      maxScale: 1000.0,
                      boundaryMargin: const EdgeInsets.all(1000.0),
                      child: CustomPaint(
                        size: _viewportSize,
                        painter: DxfPainter(
                          document: _document!,
                          theme: _canvasTheme,
                          currentScale: _currentScale,
                          measurement: _measurement,
                          searchQuery: _isSearchOpen ? _searchController.text : null,
                          showGrid: _showGrid,
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Search Bar
                if (_isSearchOpen)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: DxfSearchBar(
                      controller: _searchController,
                      matchCount: _searchMatches.length,
                      currentMatchIndex: _currentSearchIdx,
                      onChanged: _onSearchChanged,
                      onNext: _nextMatch,
                      onPrevious: _previousMatch,
                      onClose: () {
                        setState(() {
                          _isSearchOpen = false;
                          _searchController.clear();
                          _searchMatches = [];
                        });
                      },
                    ),
                  ),

                // Top Measure Status Bar
                if (_isMeasureMode)
                  Positioned(
                    top: _isSearchOpen ? 72 : 12,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: DxfMeasurementOverlay(
                        measurement: _measurement,
                        onClear: () {
                          setState(() {
                            _measurement = null;
                          });
                        },
                        onExit: () {
                          setState(() {
                            _isMeasureMode = false;
                            _measurement = null;
                          });
                        },
                      ),
                    ),
                  ),

                // Bottom Left Coordinate & Scale HUD
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'X: ${DxfMath.formatDistance(_currentCadCoord.dx)}  Y: ${DxfMath.formatDistance(_currentCadCoord.dy)}  |  Zoom: ${(_currentScale * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Bottom Right Floating Navigation Controls
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In',
                        onPressed: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _buildFloatingButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out',
                        onPressed: _zoomOut,
                      ),
                      const SizedBox(height: 8),
                      _buildFloatingButton(
                        icon: Icons.center_focus_strong,
                        tooltip: 'Fit to Screen',
                        onPressed: _fitToScreen,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xEE1E293B),
      shape: const CircleBorder(side: BorderSide(color: Colors.white12)),
      elevation: 6,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}