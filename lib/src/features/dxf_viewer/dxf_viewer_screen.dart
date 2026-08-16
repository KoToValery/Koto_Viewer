import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/coordinate_system_service.dart';
import '../../core/services/recent_files_service.dart';
import '../../core/widgets/coordinate_settings_dialog.dart';
import '../home/widgets/share_options_sheet.dart';
import 'models/dxf_display_settings.dart';
import 'models/dxf_models.dart';
import 'parser/dxf_parser.dart';
import 'rendering/dxf_math.dart';
import 'rendering/dxf_painter.dart';
import 'rendering/dxf_snap_helper.dart';
import 'widgets/dxf_import_dialog.dart';
import 'widgets/dxf_info_sheet.dart';
import 'widgets/dxf_layer_sheet.dart';
import 'widgets/dxf_measure_pointer_painter.dart';
import 'widgets/dxf_measurement_overlay.dart';

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
  DxfDisplaySettings _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;

  // Measurement & Snap tool
  bool _isMeasureMode = false;
  bool _snapEnabled = true;
  DxfMeasurement? _measurement;
  DxfSnapResult? _hoveredSnap;

  // Offset Snapping Pointer State (Aiming reticle & sharp tip)
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  DxfSnapResult? _activeMeasureSnap;
  int _activePointersCount = 0;

  // Layout & viewport
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _transformController.addListener(_onTransformChanged);
    DxfDisplaySettingsService.settingsNotifier.addListener(_onDisplaySettingsChanged);
    _initDisplaySettings();
    _loadDxfFile();
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    DxfDisplaySettingsService.settingsNotifier.removeListener(_onDisplaySettingsChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onDisplaySettingsChanged() {
    if (mounted) {
      setState(() {
        _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;
      });
    }
  }

  Future<void> _initDisplaySettings() async {
    final settings = await DxfDisplaySettingsService.getSettings();
    if (mounted) {
      setState(() {
        _displaySettings = settings;
      });
    }
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
    if (_document == null || _viewportSize.isEmpty) return cadPoint;
    final double fitScale = _getCadFitScale();
    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);
    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;
    final double minX = _document!.bounds.left;
    final double maxY = _document!.bounds.bottom > _document!.bounds.top
        ? _document!.bounds.bottom
        : _document!.bounds.top;

    return Offset(
      tx + (cadPoint.dx - minX) * fitScale,
      ty + (maxY - cadPoint.dy) * fitScale,
    );
  }

  Offset _cadToScreen(Offset cadPoint) {
    final scenePos = _cadToScene(cadPoint);
    return MatrixUtils.transformPoint(_transformController.value, scenePos);
  }

  double _getCadFitScale() {
    if (_document == null || _viewportSize.isEmpty) return 1.0;
    final double docW = math.max(_document!.width, 1.0);
    final double docH = math.max(_document!.height, 1.0);
    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);
    return math.min(availW / docW, availH / docH);
  }

  void _handleMeasurePointerDown(PointerDownEvent event) {
    if (!_isMeasureMode || _document == null) return;
    _activePointersCount++;
    if (_activePointersCount > 1) {
      // Multi-touch: cancel single finger measurement so InteractiveViewer can pinch-zoom
      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeMeasureSnap = null;
      });
      return;
    }

    _updateMeasurePointer(event.localPosition);
  }

  void _handleMeasurePointerMove(PointerMoveEvent event) {
    if (!_isMeasureMode || _document == null || _activePointersCount != 1) return;
    _updateMeasurePointer(event.localPosition);
  }

  void _updateMeasurePointer(Offset screenPos) {
    final touchPos = screenPos;
    // Position target tip 56 pixels directly above finger
    final targetPos = screenPos - const Offset(0, 56.0);
    final scenePt = _transformController.toScene(targetPos);
    final rawCadPt = _sceneToCad(scenePt);

    DxfSnapResult? snap;
    Offset? snappedScreen;

    if (_snapEnabled && _document != null) {
      final fitScale = _getCadFitScale();
      final toleranceCad = 22.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
      snap = DxfSnapHelper.findSnapPoint(
        document: _document!,
        cadPoint: rawCadPt,
        toleranceCad: toleranceCad,
      );

      if (snap != null) {
        if (_activeMeasureSnap == null || _activeMeasureSnap!.point != snap.point) {
          HapticFeedback.selectionClick();
        }
        snappedScreen = _cadToScreen(snap.point);
      }
    }

    setState(() {
      _touchScreenPos = touchPos;
      _targetScreenPos = targetPos;
      _snappedScreenPos = snappedScreen;
      _activeMeasureSnap = snap;
      _currentCadCoord = snap != null ? snap.point : rawCadPt;
    });
  }

  void _handleMeasurePointerUp(PointerUpEvent event) {
    if (!_isMeasureMode) return;
    _activePointersCount = math.max(0, _activePointersCount - 1);

    if (_touchScreenPos != null) {
      final finalCadPt = _activeMeasureSnap?.point ?? _currentCadCoord;
      HapticFeedback.mediumImpact();

      setState(() {
        if (_measurement == null || _measurement!.p2Cad != null) {
          _measurement = DxfMeasurement(p1Cad: finalCadPt);
        } else {
          _measurement = DxfMeasurement(
            p1Cad: _measurement!.p1Cad,
            p2Cad: finalCadPt,
          );
        }
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeMeasureSnap = null;
      });
    }
  }

  void _handleMeasurePointerCancel(PointerCancelEvent event) {
    _activePointersCount = 0;
    setState(() {
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeMeasureSnap = null;
    });
  }

  void _handleCanvasTap(TapUpDetails details) {
    if (_document == null) return;

    final scenePoint = _transformController.toScene(details.localPosition);
    final rawCadPoint = _sceneToCad(scenePoint);

    // If snapped, use the exact snapped landmark point
    final cadPoint = (_isMeasureMode && _snapEnabled && _hoveredSnap != null)
        ? _hoveredSnap!.point
        : rawCadPoint;

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

    DxfSnapResult? snap;
    if (_isMeasureMode && _snapEnabled) {
      final fitScale = _getCadFitScale();
      // 18 screen pixels tolerance converted to CAD coordinates
      final toleranceCad = 18.0 / (fitScale * _currentScale.clamp(0.0001, 10000.0));
      snap = DxfSnapHelper.findSnapPoint(
        document: _document!,
        cadPoint: cadPoint,
        toleranceCad: toleranceCad,
      );
    }

    setState(() {
      _currentCadCoord = snap != null ? snap.point : cadPoint;
      _hoveredSnap = snap;
    });
  }

  /// Handles importing an additional DXF drawing into the current workspace.
  Future<void> _importDxfFile() async {
    if (_document == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dxf', 'dwg', 'DXF', 'DWG'],
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final file = File(filePath);

      if (!filePath.toLowerCase().endsWith('.dxf')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a valid .dxf file to import.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parsing DXF for import...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final importedDoc = await DxfParser.parseFromFile(file);
      final activeCrs = CoordinateSystemService.activeSystemNotifier.value;

      if (!mounted) return;

      final action = await DxfImportDialog.show(
        context: context,
        file: file,
        currentDoc: _document!,
        importedDoc: importedDoc,
        activeCrs: activeCrs,
      );

      if (action == null || !mounted) return;

      // Merge imported document into current document
      final mergedLayers = Map<String, DxfLayer>.from(_document!.layers);
      for (final entry in importedDoc.layers.entries) {
        if (!mergedLayers.containsKey(entry.key)) {
          mergedLayers[entry.key] = entry.value;
        }
      }

      final mergedBlocks = Map<String, DxfBlock>.from(_document!.blocks);
      for (final entry in importedDoc.blocks.entries) {
        mergedBlocks[entry.key] = entry.value;
      }

      final mergedEntities = List<DxfEntity>.from(_document!.entities)..addAll(importedDoc.entities);
      final mergedBounds = _document!.bounds.expandToInclude(importedDoc.bounds);

      final mergedStats = Map<String, int>.from(_document!.entityStats);
      for (final entry in importedDoc.entityStats.entries) {
        mergedStats[entry.key] = (mergedStats[entry.key] ?? 0) + entry.value;
      }

      setState(() {
        _document = DxfDocument(
          layers: mergedLayers,
          blocks: mergedBlocks,
          entities: mergedEntities,
          headerVars: _document!.headerVars,
          bounds: mergedBounds,
          entityStats: mergedStats,
        );
      });

      final importedName = filePath.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${importedDoc.totalEntities} entities from $importedName'),
          action: SnackBarAction(
            label: 'Fit Screen',
            onPressed: _fitToScreen,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing DXF: $e')),
        );
      }
    }
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

  void _showCoordinateSettings() async {
    final selected = await CoordinateSettingsDialog.show(context);
    if (selected != null && mounted) {
      setState(() {});
    }
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
    final activeCrs = CoordinateSystemService.activeSystemNotifier.value;

    return Scaffold(
      backgroundColor: _canvasTheme.bgColor,
      appBar: AppBar(
        title: null,
        actions: [
          // Fit to screen (Zoom Extents)
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit to Screen (Zoom Extents)',
            onPressed: _document != null ? _fitToScreen : null,
          ),

          // Import DXF
          IconButton(
            icon: const Icon(Icons.add_to_photos_outlined),
            tooltip: 'Import DXF into Drawing',
            onPressed: _document != null ? _importDxfFile : null,
          ),

          // Layer Manager (where thin/thick lines are chosen per layer)
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
                      if (!_isMeasureMode) {
                        _measurement = null;
                        _hoveredSnap = null;
                        _touchScreenPos = null;
                        _targetScreenPos = null;
                        _snappedScreenPos = null;
                        _activeMeasureSnap = null;
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

          // More Options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importDxfFile();
                  break;
                case 'crs':
                  _showCoordinateSettings();
                  break;
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
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.add_to_photos_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Import DXF File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'crs',
                child: Row(
                  children: [
                    Icon(Icons.public_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Coordinate System'),
                  ],
                ),
              ),
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
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Drawing Properties'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Share File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Print / Export'),
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
                // Interactive CAD Canvas with Touch Listener for Measurement
                Listener(
                  onPointerDown: _isMeasureMode ? _handleMeasurePointerDown : null,
                  onPointerMove: _isMeasureMode ? _handleMeasurePointerMove : null,
                  onPointerUp: _isMeasureMode ? _handleMeasurePointerUp : null,
                  onPointerCancel: _isMeasureMode ? _handleMeasurePointerCancel : null,
                  child: MouseRegion(
                    onHover: _handlePointerHover,
                    child: GestureDetector(
                      onTapUp: _isMeasureMode ? null : _handleCanvasTap,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        panEnabled: !_isMeasureMode,
                        scaleEnabled: true,
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
                            snapResult: _isMeasureMode && _snapEnabled ? (_hoveredSnap ?? _activeMeasureSnap) : null,
                            showGrid: _showGrid,
                            settings: _displaySettings,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Offset Snapping Pointer Overlay (Sharp tip 56px above finger with magnetism halo)
                if (_isMeasureMode && _touchScreenPos != null && _targetScreenPos != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: DxfMeasurePointerPainter(
                          touchPos: _touchScreenPos!,
                          targetPos: _targetScreenPos!,
                          snappedPos: _snappedScreenPos,
                          snapType: _activeMeasureSnap?.type,
                          currentCadCoord: _currentCadCoord,
                          p1CadCoord: _measurement?.p1Cad,
                          isSettingSecondPoint: _measurement != null && _measurement!.p2Cad == null,
                        ),
                      ),
                    ),
                  ),

                // Top Measure Status Bar
                if (_isMeasureMode)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: DxfMeasurementOverlay(
                        measurement: _measurement,
                        snapEnabled: _snapEnabled,
                        onToggleSnap: () {
                          setState(() {
                            _snapEnabled = !_snapEnabled;
                            if (!_snapEnabled) {
                              _hoveredSnap = null;
                              _activeMeasureSnap = null;
                              _snappedScreenPos = null;
                            }
                          });
                        },
                        onClear: () {
                          setState(() {
                            _measurement = null;
                            _touchScreenPos = null;
                            _targetScreenPos = null;
                            _snappedScreenPos = null;
                            _activeMeasureSnap = null;
                          });
                        },
                        onExit: () {
                          setState(() {
                            _isMeasureMode = false;
                            _measurement = null;
                            _hoveredSnap = null;
                            _touchScreenPos = null;
                            _targetScreenPos = null;
                            _snappedScreenPos = null;
                            _activeMeasureSnap = null;
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
                      'X: ${DxfMath.formatDistance(_currentCadCoord.dx)}  Y: ${DxfMath.formatDistance(_currentCadCoord.dy)}  |  Zoom: ${(_currentScale * 100).toStringAsFixed(0)}%  |  ${activeCrs.name}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
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