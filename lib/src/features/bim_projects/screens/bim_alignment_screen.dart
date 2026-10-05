import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_display_settings.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../../dxf_viewer/rendering/dxf_painter.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../../dxf_viewer/widgets/dxf_display_settings_sheet.dart';
import '../../dxf_viewer/widgets/dxf_layer_sheet.dart';
import '../models/bim_work_project.dart';
import '../services/bim_project_library_service.dart';
import '../services/bim_underlay_picker_helper.dart';
import 'bim_workspace_screen.dart';

/// Screen allowing users to inspect each storey underlay drawing and place a common
/// control point (reference point) on all floors for precise multi-storey BiM alignment.
class BimAlignmentScreen extends StatefulWidget {
  final BimWorkProject project;

  const BimAlignmentScreen({
    super.key,
    required this.project,
  });

  @override
  State<BimAlignmentScreen> createState() => _BimAlignmentScreenState();
}

class _BimAlignmentScreenState extends State<BimAlignmentScreen>
    with SingleTickerProviderStateMixin {
  late BimWorkProject _project;
  late TabController _tabController;
  final Map<String, DxfDocument> _loadedDocs = {};
  bool _isLoading = true;
  bool _showOnionSkin = false;

  DxfCanvasTheme _canvasTheme = DxfCanvasTheme.darkCad;
  DxfDisplaySettings _displaySettings = const DxfDisplaySettings();
  double _renderScale = 1.0;
  bool _isGestureActive = false;
  Timer? _transformSettleTimer;

  final TransformationController _transformController =
      TransformationController();
  Offset? _touchCadCoord;
  Offset? _activeSnapCad;
  bool _isDraggingPoint = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _tabController = TabController(
      length: _project.storeys.isNotEmpty ? _project.storeys.length : 1,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _transformController.addListener(_onTransformChanged);
    _initDisplaySettings();
    DxfDisplaySettingsService.settingsNotifier.addListener(_onDisplaySettingsChanged);
    _loadAllUnderlays();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    DxfDisplaySettingsService.settingsNotifier.removeListener(_onDisplaySettingsChanged);
    _transformSettleTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDisplaySettings() async {
    final settings = await DxfDisplaySettingsService.getSettings();
    if (mounted) {
      setState(() {
        _displaySettings = settings;
      });
    }
  }

  void _onDisplaySettingsChanged() {
    if (mounted) {
      setState(() {
        _displaySettings = DxfDisplaySettingsService.settingsNotifier.value;
      });
    }
  }

  void _onTransformChanged() {
    if (_isGestureActive) return;
    _transformSettleTimer?.cancel();
    _transformSettleTimer = Timer(const Duration(milliseconds: 60), _syncCanvasAfterTransform);
  }

  void _syncCanvasAfterTransform() {
    if (!mounted || _isGestureActive) return;
    final currentScale = _transformController.value.getMaxScaleOnAxis().clamp(0.001, 10000.0);
    if ((currentScale - _renderScale).abs() / _renderScale > 0.03) {
      setState(() {
        _renderScale = currentScale;
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _touchCadCoord = null;
      _activeSnapCad = null;
      _isDraggingPoint = false;
      _renderScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _loadAllUnderlays() async {
    setState(() => _isLoading = true);
    final lib = BimProjectLibraryService.instance;
    _loadedDocs.clear();

    for (final storey in _project.storeys) {
      if (storey.hasUnderlay) {
        final file = await lib.getUnderlayFile(_project.id, storey.underlayFileName!);
        if (file != null && await file.exists()) {
          try {
            final doc = await DxfParser.parseFromFile(file);
            _loadedDocs[storey.storeyId] = doc;
          } catch (e) {
            debugPrint('Error loading underlay for ${storey.storeyId}: $e');
          }
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAttachUnderlayForCurrentStorey() async {
    final file = await BimUnderlayPickerHelper.pickCadUnderlayFile(context);
    if (file == null) return;

    setState(() => _isLoading = true);
    try {
      await BimProjectLibraryService.instance.attachUnderlayFile(
        _project.id,
        _currentStorey.storeyId,
        file,
      );

      final latestProject = await BimProjectLibraryService.instance.loadProject(_project.id) ?? _project;
      if (mounted) {
        setState(() {
          _project = latestProject;
          _touchCadCoord = null;
          _activeSnapCad = null;
          _isDraggingPoint = false;
        });
        await _loadAllUnderlays();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.bimProjectUnderlayAttached),
              backgroundColor: const Color(0xFF00E676),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error attaching underlay in alignment screen: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotOpenFilePicker(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  BimStoreyUnderlay get _currentStorey {
    final idx = _tabController.index.clamp(0, _project.storeys.length - 1);
    return _project.storeys[idx];
  }

  DxfDocument? get _currentDoc => _loadedDocs[_currentStorey.storeyId];

  BimStoreyUnderlay? get _lowerStorey {
    final idx = _tabController.index;
    if (idx > 0) {
      return _project.storeys[idx - 1];
    }
    return null;
  }

  DxfDocument? get _lowerDoc =>
      _lowerStorey != null ? _loadedDocs[_lowerStorey!.storeyId] : null;

  // --- Coordinate conversion helpers ---
  double _getCadFitScale(Rect b, Size size) {
    if (size.isEmpty) return 1.0;
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    const double padding = 32.0;
    final double availW = math.max(size.width - padding * 2, 10.0);
    final double availH = math.max(size.height - padding * 2, 10.0);
    return math.min(availW / docW, availH / docH);
  }

  Offset _sceneToCad(Offset scenePt, Rect b, Size size) {
    final fitScale = _getCadFitScale(b, size);
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    final double tx = (size.width - docW * fitScale) / 2.0;
    final double ty = (size.height - docH * fitScale) / 2.0;
    final double minX = b.left;
    final double maxY = b.bottom > b.top ? b.bottom : b.top;

    final double cadX = minX + (scenePt.dx - tx) / fitScale;
    final double cadY = maxY - (scenePt.dy - ty) / fitScale;
    return Offset(cadX, cadY);
  }

  Offset _cadToScene(Offset cadPt, Rect b, Size size) {
    final fitScale = _getCadFitScale(b, size);
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    final double tx = (size.width - docW * fitScale) / 2.0;
    final double ty = (size.height - docH * fitScale) / 2.0;
    final double minX = b.left;
    final double maxY = b.bottom > b.top ? b.bottom : b.top;

    return Offset(
      tx + (cadPt.dx - minX) * fitScale,
      ty + (maxY - cadPt.dy) * fitScale,
    );
  }

  Offset _cadToScreen(Offset cadPt, Rect b, Size size) {
    final scenePos = _cadToScene(cadPt, b, size);
    return MatrixUtils.transformPoint(_transformController.value, scenePos);
  }

  Rect? _getVisibleCadRect(Rect bounds, Size viewportSize) {
    if (viewportSize.isEmpty) return null;
    try {
      final pTopLeft = _transformController.toScene(Offset.zero);
      final pBottomRight = _transformController.toScene(
        Offset(viewportSize.width, viewportSize.height),
      );

      final cadTopLeft = _sceneToCad(pTopLeft, bounds, viewportSize);
      final cadBottomRight = _sceneToCad(pBottomRight, bounds, viewportSize);

      final left = math.min(cadTopLeft.dx, cadBottomRight.dx);
      final right = math.max(cadTopLeft.dx, cadBottomRight.dx);
      final bottom = math.min(cadTopLeft.dy, cadBottomRight.dy);
      final top = math.max(cadTopLeft.dy, cadBottomRight.dy);

      final marginX = (right - left) * 0.1;
      final marginY = (top - bottom) * 0.1;

      final rect = Rect.fromLTRB(
        left - marginX,
        bottom - marginY,
        right + marginX,
        top + marginY,
      );

      final maxDocExtent = bounds.inflate(bounds.longestSide * 0.05 + 10.0);
      return rect.intersect(maxDocExtent);
    } catch (_) {
      return null;
    }
  }

  void _updateSnapPoint(Offset localPosition, Rect bounds, Size viewportSize) {
    if (_currentDoc == null) return;
    final scenePos = _transformController.toScene(localPosition);
    final cadPt = _sceneToCad(scenePos, bounds, viewportSize);
    final fitScale = _getCadFitScale(bounds, viewportSize);
    final currentScale = _transformController.value.getMaxScaleOnAxis().clamp(0.0001, 10000.0);
    final toleranceCad = 26.0 / (fitScale * currentScale);

    final snap = DxfSnapHelper.findSnapPoint(
      document: _currentDoc!,
      cadPoint: cadPt,
      toleranceCad: toleranceCad,
    );

    setState(() {
      _touchCadCoord = cadPt;
      _activeSnapCad = snap?.point;
    });
  }

  void _showLayersSheet() {
    if (_currentDoc == null) return;
    DxfLayerSheet.show(
      context: context,
      document: _currentDoc!,
      isDark: _canvasTheme.isDark,
      onLayersChanged: () {
        setState(() {});
      },
    );
  }

  void _showDisplaySettingsSheet() {
    DxfDisplaySettingsSheet.show(
      context: context,
      initialSettings: _displaySettings,
      onSettingsChanged: (newSettings) {
        setState(() {
          _displaySettings = newSettings;
        });
      },
    );
  }

  void _clearControlPoint() {
    HapticFeedback.lightImpact();
    final updatedStoreys = _project.storeys.map((s) {
      if (s.storeyId == _currentStorey.storeyId) {
        return s.copyWith(clearControlPoint: true);
      }
      return s;
    }).toList();

    final updatedProject = _project.copyWith(
      storeys: updatedStoreys,
      alignmentConfirmed: false,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _project = updatedProject;
      _touchCadCoord = null;
      _activeSnapCad = null;
      _isDraggingPoint = false;
    });

    BimProjectLibraryService.instance.saveProjectManifest(updatedProject);
  }

  void _onSetControlPoint(Offset cadPoint) {
    HapticFeedback.mediumImpact();
    final updatedStoreys = _project.storeys.map((s) {
      if (s.storeyId == _currentStorey.storeyId) {
        return s.copyWith(controlPoint: cadPoint);
      }
      return s;
    }).toList();

    final updatedProject = _project.copyWith(
      storeys: updatedStoreys,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _project = updatedProject;
      _touchCadCoord = null;
      _activeSnapCad = null;
      _isDraggingPoint = false;
    });

    BimProjectLibraryService.instance.saveProjectManifest(updatedProject);
  }

  Future<void> _onConfirmAlignment() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bimAlignmentConfirmTitle),
        content: Text(l10n.bimAlignmentConfirmMessage),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.isolateWallsAndGenerateAxes),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updated = _project.copyWith(
        alignmentConfirmed: true,
        updatedAt: DateTime.now(),
      );
      await BimProjectLibraryService.instance.saveProjectManifest(updated);
      setState(() => _project = updated);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BimWorkspaceScreen(project: updated),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.bimAlignmentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: _currentStorey.hasUnderlay
                ? l10n.bimProjectReplaceUnderlay
                : l10n.bimProjectAddUnderlay,
            onPressed: _pickAndAttachUnderlayForCurrentStorey,
          ),
          IconButton(
            icon: const Icon(Icons.layers_rounded),
            tooltip: l10n.layersTooltip,
            onPressed: _showLayersSheet,
          ),
          IconButton(
            icon: Icon(
              _showOnionSkin ? Icons.compare_rounded : Icons.compare_outlined,
              color: _showOnionSkin ? const Color(0xFF00E5FF) : null,
            ),
            tooltip: l10n.bimAlignmentOnionSkin,
            onPressed: () {
              setState(() => _showOnionSkin = !_showOnionSkin);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  _showDisplaySettingsSheet();
                  break;
                case 'theme':
                  setState(() {
                    _canvasTheme = _canvasTheme.isDark
                        ? DxfCanvasTheme.paperWhite
                        : DxfCanvasTheme.darkCad;
                  });
                  break;
                case 'clear_cp':
                  _clearControlPoint();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.displaySettings),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      _canvasTheme.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(_canvasTheme.isDark ? l10n.cadThemePaperWhite : l10n.cadThemeDarkCad),
                  ],
                ),
              ),
              if (_currentStorey.isControlPointSet)
                PopupMenuItem(
                  value: 'clear_cp',
                  child: Row(
                    children: [
                      const Icon(Icons.clear_rounded, size: 20, color: Colors.orangeAccent),
                      const SizedBox(width: 10),
                      Text(l10n.clear, style: const TextStyle(color: Colors.orangeAccent)),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _project.storeys.isNotEmpty
              ? TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _project.storeys.map((s) {
                    final hasCp = s.isControlPointSet;
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasCp ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 14,
                            color: hasCp ? const Color(0xFF00E676) : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(s.name),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instruction banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF00E5FF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.bimAlignmentInstructions,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // CAD Drawing Canvas
                Expanded(
                  child: _currentDoc != null
                      ? Container(
                          color: _canvasTheme.bgColor,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                              final bounds = _currentDoc!.bounds;

                              return Stack(
                                fit: StackFit.passthrough,
                                children: [
                                  GestureDetector(
                                    onLongPressStart: (details) {
                                      _isDraggingPoint = true;
                                      _updateSnapPoint(details.localPosition, bounds, viewportSize);
                                      HapticFeedback.selectionClick();
                                    },
                                    onLongPressMoveUpdate: (details) {
                                      _updateSnapPoint(details.localPosition, bounds, viewportSize);
                                    },
                                    onLongPressEnd: (details) {
                                      setState(() {
                                        _isDraggingPoint = false;
                                      });
                                      final target = _activeSnapCad ?? _touchCadCoord;
                                      if (target != null) {
                                        _onSetControlPoint(target);
                                      }
                                    },
                                    onLongPressCancel: () {
                                      setState(() {
                                        _isDraggingPoint = false;
                                      });
                                    },
                                    child: InteractiveViewer(
                                      transformationController: _transformController,
                                      scaleFactor: 350.0,
                                      trackpadScrollCausesScale: true,
                                      minScale: 0.001,
                                      maxScale: 1000.0,
                                      boundaryMargin: const EdgeInsets.all(double.infinity),
                                      onInteractionStart: (details) {
                                        _isGestureActive = true;
                                        _transformSettleTimer?.cancel();
                                      },
                                      onInteractionEnd: (details) {
                                        _isGestureActive = false;
                                        _transformSettleTimer?.cancel();
                                        _transformSettleTimer = Timer(
                                          const Duration(milliseconds: 60),
                                          _syncCanvasAfterTransform,
                                        );
                                      },
                                      child: SizedBox(
                                        width: viewportSize.width,
                                        height: viewportSize.height,
                                        child: Stack(
                                          children: [
                                            // Optional onion skin from lower storey
                                            if (_showOnionSkin && _lowerDoc != null) ...[
                                              Builder(
                                                builder: (context) {
                                                  Offset offset = Offset.zero;
                                                  if (_lowerStorey?.controlPoint != null &&
                                                      _currentStorey.controlPoint != null) {
                                                    final curCp = _cadToScene(
                                                        _currentStorey.controlPoint!, bounds, viewportSize);
                                                    final lowCp = _cadToScene(
                                                        _lowerStorey!.controlPoint!, _lowerDoc!.bounds, viewportSize);
                                                    offset = curCp - lowCp;
                                                  }

                                                  return Positioned.fill(
                                                    child: Transform.translate(
                                                      offset: offset,
                                                      child: Opacity(
                                                        opacity: 0.38,
                                                        child: RepaintBoundary(
                                                          child: CustomPaint(
                                                            size: viewportSize,
                                                            isComplex: true,
                                                            willChange: false,
                                                            painter: DxfPainter(
                                                              document: _lowerDoc!,
                                                              theme: _canvasTheme,
                                                              activeLayout: 'Model',
                                                              currentScale: _renderScale,
                                                              visibleCadRect: _getVisibleCadRect(
                                                                  _lowerDoc!.bounds, viewportSize),
                                                              showGrid: false,
                                                              settings: _displaySettings,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],

                                            // Main active storey drawing
                                            Positioned.fill(
                                              child: RepaintBoundary(
                                                child: CustomPaint(
                                                  size: viewportSize,
                                                  isComplex: true,
                                                  willChange: false,
                                                  painter: DxfPainter(
                                                    document: _currentDoc!,
                                                    theme: _canvasTheme,
                                                    activeLayout: 'Model',
                                                    currentScale: _renderScale,
                                                    visibleCadRect: _getVisibleCadRect(bounds, viewportSize),
                                                    showGrid: true,
                                                    settings: _displaySettings,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Screen-Space Control Point Bullseye Marker (Crisp, vector-sharp at ANY zoom scale)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        size: viewportSize,
                                        painter: _ControlPointOverlayPainter(
                                          placedPoint: _currentStorey.controlPoint,
                                          draggingPoint: _isDraggingPoint
                                              ? (_activeSnapCad ?? _touchCadCoord)
                                              : null,
                                          cadToScreen: (pt) => _cadToScreen(pt, bounds, viewportSize),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.layers_clear_outlined,
                                  size: 64,
                                  color: theme.hintColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.bimProjectNoUnderlay,
                                  style: TextStyle(color: theme.hintColor, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: Text(l10n.bimProjectAddUnderlay),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _pickAndAttachUnderlayForCurrentStorey,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // Bottom Control Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Status Indicator
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _currentStorey.isControlPointSet
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    size: 16,
                                    color: _currentStorey.isControlPointSet
                                        ? const Color(0xFF00E676)
                                        : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _currentStorey.isControlPointSet
                                            ? l10n.bimAlignmentControlPointSet(
                                                _currentStorey.controlPoint!.dx.toStringAsFixed(2),
                                                _currentStorey.controlPoint!.dy.toStringAsFixed(2),
                                              )
                                            : l10n.bimAlignmentControlPointMissing,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_project.storeys.where((s) => s.isControlPointSet).length}/${_project.underlaysCount} aligned',
                                style: TextStyle(fontSize: 11, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Ready / Start BiM Button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: Text(l10n.bimAlignmentReadyButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: _project.allControlPointsPlaced
                              ? _onConfirmAlignment
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ControlPointOverlayPainter extends CustomPainter {
  final Offset? placedPoint;
  final Offset? draggingPoint;
  final Offset Function(Offset) cadToScreen;

  _ControlPointOverlayPainter({
    required this.placedPoint,
    required this.draggingPoint,
    required this.cadToScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (placedPoint != null) {
      final p = cadToScreen(placedPoint!);
      _drawBullseye(
        canvas,
        p,
        color: const Color(0xFF00E5FF),
        isPlaced: true,
        label: 'CP: (${placedPoint!.dx.toStringAsFixed(2)}, ${placedPoint!.dy.toStringAsFixed(2)})',
      );
    }

    if (draggingPoint != null) {
      final p = cadToScreen(draggingPoint!);
      _drawBullseye(
        canvas,
        p,
        color: const Color(0xFFFF9100),
        isPlaced: false,
        label: 'Snap: (${draggingPoint!.dx.toStringAsFixed(2)}, ${draggingPoint!.dy.toStringAsFixed(2)})',
      );
    }
  }

  void _drawBullseye(
    Canvas canvas,
    Offset p, {
    required Color color,
    required bool isPlaced,
    required String label,
  }) {
    // Subtle circular glow around target
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p, 26, glowPaint);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final crossPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    // Concentric circles
    canvas.drawCircle(p, 12, ringPaint);
    canvas.drawCircle(p, 20, ringPaint..strokeWidth = 1.0);

    // Crosshairs
    canvas.drawLine(Offset(p.dx - 28, p.dy), Offset(p.dx + 28, p.dy), crossPaint);
    canvas.drawLine(Offset(p.dx, p.dy - 28), Offset(p.dx, p.dy + 28), crossPaint);

    // Center dot
    canvas.drawCircle(p, 3.5, Paint()..color = color..style = PaintingStyle.fill);

    // Coordinate badge
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black.withValues(alpha: 0.70),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(p.dx + 16, p.dy - 24));
  }

  @override
  bool shouldRepaint(covariant _ControlPointOverlayPainter oldDelegate) {
    return oldDelegate.placedPoint != placedPoint ||
        oldDelegate.draggingPoint != draggingPoint;
  }
}
