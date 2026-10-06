import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_display_settings.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../services/bim_underlay_conversion_service.dart';
import '../widgets/bim_elevation_dialog.dart';
import '../../dxf_viewer/rendering/dxf_painter.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../../dxf_viewer/widgets/dxf_display_settings_sheet.dart';
import '../../dxf_viewer/widgets/dxf_layer_sheet.dart';
import '../../structural_designer/analysis/structural_underlay_filter.dart';
import '../models/bim_work_project.dart';
import '../services/bim_project_library_service.dart';
import '../services/bim_underlay_picker_helper.dart';
import 'bim_workspace_screen.dart';

/// Screen allowing users to inspect each storey underlay drawing and place a common
/// control point (reference point) on all floors for precise multi-storey BiM alignment.
class BimAlignmentScreen extends StatefulWidget {
  final BimWorkProject project;

  const BimAlignmentScreen({super.key, required this.project});

  @override
  State<BimAlignmentScreen> createState() => _BimAlignmentScreenState();
}

class _BimAlignmentScreenState extends State<BimAlignmentScreen>
    with TickerProviderStateMixin {
  late BimWorkProject _project;
  late TabController _tabController;
  final Map<String, DxfDocument> _loadedDocs = {};
  bool _isLoading = true;
  String? _loadError;
  bool _showOnionSkin = false;
  bool _underlayFilterActive = false;

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
  PointerDeviceKind _activePointerKind = PointerDeviceKind.touch;
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  DxfSnapType? _activeSnapType;

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
    DxfDisplaySettingsService.settingsNotifier.addListener(
      _onDisplaySettingsChanged,
    );
    _loadAllUnderlays();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    DxfDisplaySettingsService.settingsNotifier.removeListener(
      _onDisplaySettingsChanged,
    );
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
    _transformSettleTimer = Timer(
      const Duration(milliseconds: 60),
      _syncCanvasAfterTransform,
    );
  }

  void _syncCanvasAfterTransform() {
    if (!mounted || _isGestureActive) return;
    final currentScale = _transformController.value.getMaxScaleOnAxis().clamp(
      0.001,
      10000.0,
    );
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
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeSnapType = null;
      _isDraggingPoint = false;
      _renderScale = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _loadAllUnderlays() async {
    setState(() => _isLoading = true);
    final lib = BimProjectLibraryService.instance;
    _loadedDocs.clear();

    try {
      _loadError = null;
      _project = await lib.prepareUnderlays(
        _project,
        loadedDocuments: _loadedDocs,
      );
      for (final storey in _project.storeys) {
        if (!storey.hasUnderlay) continue;
        final doc = _loadedDocs[storey.storeyId]!;
        for (final entry in storey.layerVisibility.entries) {
          doc.layers[entry.key]?.isVisible = entry.value;
        }
        _loadedDocs[storey.storeyId] = doc;
      }
      final currentDoc = _loadedDocs[_currentStorey.storeyId];
      _underlayFilterActive =
          currentDoc != null &&
          BimUnderlayMetadata.generatedLayers(
            currentDoc,
          ).any((name) => currentDoc.layers[name]?.isVisible == true);
    } catch (error) {
      _loadError = error.toString();
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

      final latestProject =
          await BimProjectLibraryService.instance.loadProject(_project.id) ??
          _project;
      if (mounted) {
        setState(() {
          _project = latestProject;
          _touchCadCoord = null;
          _activeSnapCad = null;
          _touchScreenPos = null;
          _targetScreenPos = null;
          _snappedScreenPos = null;
          _activeSnapType = null;
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

  void _updateSnapPoint(
    Offset localPosition,
    Rect bounds,
    Size viewportSize, {
    bool isMouse = false,
  }) {
    if (_currentDoc == null) return;
    final touchPos = localPosition;
    // On touch/mobile: position target tip 56 pixels directly above finger so finger doesn't obscure view (same as CAD dimensioning)
    final targetPos = isMouse
        ? localPosition
        : (localPosition - const Offset(0, 56.0));
    final scenePos = _transformController.toScene(targetPos);
    final cadPt = _sceneToCad(scenePos, bounds, viewportSize);
    final fitScale = _getCadFitScale(bounds, viewportSize);
    final currentScale = _transformController.value.getMaxScaleOnAxis().clamp(
      0.0001,
      10000.0,
    );
    final toleranceCad = 26.0 / (fitScale * currentScale);

    final snap = DxfSnapHelper.findSnapPoint(
      document: _currentDoc!,
      cadPoint: cadPt,
      toleranceCad: toleranceCad,
    );

    if (snap != null) {
      if (_activeSnapCad == null || _activeSnapCad != snap.point) {
        HapticFeedback.selectionClick();
      }
    }

    final effectiveCad = snap?.point ?? cadPt;
    final snappedScreen = snap != null
        ? _cadToScreen(snap.point, bounds, viewportSize)
        : null;

    setState(() {
      _touchScreenPos = touchPos;
      _targetScreenPos = targetPos;
      _snappedScreenPos = snappedScreen;
      _activeSnapType = snap?.type;
      _activeSnapCad = snap?.point;
      _touchCadCoord = effectiveCad;
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
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeSnapType = null;
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
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeSnapType = null;
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

  void _toggleUnderlayFilter() {
    setState(() {
      _underlayFilterActive = !_underlayFilterActive;
      for (final doc in _loadedDocs.values) {
        if (BimUnderlayMetadata.read(doc) != null) {
          BimUnderlayMetadata.setFiltered(doc, _underlayFilterActive);
          continue;
        }
        if (_underlayFilterActive) {
          final visible = StructuralUnderlayFilter.filterLayers(
            layers: doc.layers.values,
            entities: doc.entities,
            blocks: doc.blocks,
          );
          if (visible.isNotEmpty) {
            for (final l in doc.layers.values) {
              l.isVisible = visible.contains(l.name);
            }
          }
        } else {
          for (final l in doc.layers.values) {
            l.isVisible = true;
          }
        }
      }
    });
    _project = _project.copyWith(
      storeys: _project.storeys.map((storey) {
        final doc = _loadedDocs[storey.storeyId];
        return doc == null
            ? storey
            : storey.copyWith(
                layerVisibility: {
                  for (final l in doc.layers.values) l.name: l.isVisible,
                },
              );
      }).toList(),
    );
    BimProjectLibraryService.instance.saveProjectManifest(_project);
    HapticFeedback.selectionClick();
  }

  Future<void> _manageElevation({bool add = false, bool sort = false}) async {
    if (_isLoading) return;
    final activeId = _currentStorey.storeyId;
    final storeys = List<BimStoreyUnderlay>.of(_project.storeys);
    if (sort) {
      storeys.sort((a, b) => a.elevation.compareTo(b.elevation));
    } else {
      final elevation = await showBimElevationDialog(
        context: context,
        initialElevation: add
            ? storeys.map((s) => s.elevation).reduce(math.max) + 2.8
            : _currentStorey.elevation,
        occupiedElevations: storeys
            .where((s) => add || s.storeyId != activeId)
            .map((s) => s.elevation),
      );
      if (!mounted || elevation == null) return;
      if (add) {
        storeys.add(
          BimStoreyUnderlay(
            storeyId: 'storey_${DateTime.now().microsecondsSinceEpoch}',
            name: BimStoreyUnderlay.formatElevation(elevation),
            elevation: elevation,
          ),
        );
      } else {
        final index = storeys.indexWhere((s) => s.storeyId == activeId);
        storeys[index] = storeys[index].copyWith(elevation: elevation);
      }
    }
    setState(() => _isLoading = true);
    try {
      final updated = await BimProjectLibraryService.instance.updateStoreys(
        _project.id,
        storeys,
      );
      if (!mounted) return;
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _project = updated;
      _tabController = TabController(
        length: updated.storeys.length,
        vsync: this,
        initialIndex: updated.storeys.indexWhere((s) => s.storeyId == activeId),
      );
      _tabController.addListener(_onTabChanged);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reprocess() async {
    if (_isLoading || !_currentStorey.hasUnderlay) return;
    setState(() => _isLoading = true);
    try {
      await BimProjectLibraryService.instance.reprocessUnderlay(
        _project.id,
        _currentStorey.storeyId,
      );
      if (mounted) await _loadAllUnderlays();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = '$error';
          _isLoading = false;
        });
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
            onPressed: _isLoading
                ? null
                : _pickAndAttachUnderlayForCurrentStorey,
          ),
          IconButton(
            icon: Icon(
              _underlayFilterActive
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: _underlayFilterActive ? const Color(0xFF00E5FF) : null,
            ),
            tooltip: _underlayFilterActive
                ? l10n.structuralFilterActive
                : l10n.structuralFilterInactive,
            onPressed: _toggleUnderlayFilter,
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
                case 'edit_elevation':
                  _manageElevation();
                  break;
                case 'add_elevation':
                  _manageElevation(add: true);
                  break;
                case 'sort_elevations':
                  _manageElevation(sort: true);
                  break;
                case 'reprocess':
                  _reprocess();
                  break;
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
                value: 'edit_elevation',
                enabled: !_isLoading,
                child: Text(l10n.bimProjectEditElevation),
              ),
              PopupMenuItem(
                value: 'add_elevation',
                enabled: !_isLoading,
                child: Text(l10n.bimProjectAddStorey),
              ),
              PopupMenuItem(
                value: 'sort_elevations',
                enabled: !_isLoading,
                child: Text(l10n.bimProjectSortStoreys),
              ),
              PopupMenuItem(
                value: 'reprocess',
                enabled: !_isLoading && _currentStorey.hasUnderlay,
                child: Text(l10n.bimProjectReprocessUnderlay),
              ),
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
                    Text(
                      _canvasTheme.isDark
                          ? l10n.cadThemePaperWhite
                          : l10n.cadThemeDarkCad,
                    ),
                  ],
                ),
              ),
              if (_currentStorey.isControlPointSet)
                PopupMenuItem(
                  value: 'clear_cp',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.clear_rounded,
                        size: 20,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.clear,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
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
                            hasCp
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 14,
                            color: hasCp
                                ? const Color(0xFF00E676)
                                : Colors.orangeAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(s.elevationLabel),
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
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  TextButton(
                    onPressed: _loadAllUnderlays,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Instruction banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF00E5FF),
                      ),
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
                              final viewportSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final bounds = _currentDoc!.bounds;

                              return Stack(
                                fit: StackFit.passthrough,
                                children: [
                                  RawGestureDetector(
                                    gestures: <Type, GestureRecognizerFactory>{
                                      LongPressGestureRecognizer:
                                          GestureRecognizerFactoryWithHandlers<
                                            LongPressGestureRecognizer
                                          >(
                                            () => LongPressGestureRecognizer(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              debugOwner: this,
                                            ),
                                            (
                                              LongPressGestureRecognizer
                                              instance,
                                            ) {
                                              instance
                                                ..onLongPressStart = (details) {
                                                  _isDraggingPoint = true;
                                                  _updateSnapPoint(
                                                    details.localPosition,
                                                    bounds,
                                                    viewportSize,
                                                    isMouse:
                                                        _activePointerKind ==
                                                        PointerDeviceKind.mouse,
                                                  );
                                                  HapticFeedback.selectionClick();
                                                }
                                                ..onLongPressMoveUpdate =
                                                    (details) {
                                                      _updateSnapPoint(
                                                        details.localPosition,
                                                        bounds,
                                                        viewportSize,
                                                        isMouse:
                                                            _activePointerKind ==
                                                            PointerDeviceKind
                                                                .mouse,
                                                      );
                                                    }
                                                ..onLongPressEnd = (details) {
                                                  final target =
                                                      _activeSnapCad ??
                                                      _touchCadCoord;
                                                  setState(() {
                                                    _isDraggingPoint = false;
                                                    _touchScreenPos = null;
                                                    _targetScreenPos = null;
                                                    _snappedScreenPos = null;
                                                    _activeSnapType = null;
                                                  });
                                                  if (target != null) {
                                                    _onSetControlPoint(target);
                                                  }
                                                }
                                                ..onLongPressCancel = () {
                                                  setState(() {
                                                    _isDraggingPoint = false;
                                                    _touchScreenPos = null;
                                                    _targetScreenPos = null;
                                                    _snappedScreenPos = null;
                                                    _activeSnapType = null;
                                                  });
                                                };
                                            },
                                          ),
                                    },
                                    child: Listener(
                                      onPointerDown: (e) {
                                        _activePointerKind = e.kind;
                                      },
                                      child: InteractiveViewer(
                                        transformationController:
                                            _transformController,
                                        scaleFactor: 350.0,
                                        trackpadScrollCausesScale: true,
                                        minScale: 0.001,
                                        maxScale: 1000.0,
                                        boundaryMargin: const EdgeInsets.all(
                                          double.infinity,
                                        ),
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
                                              if (_showOnionSkin &&
                                                  _lowerDoc != null) ...[
                                                Builder(
                                                  builder: (context) {
                                                    Offset offset = Offset.zero;
                                                    if (_lowerStorey
                                                                ?.controlPoint !=
                                                            null &&
                                                        _currentStorey
                                                                .controlPoint !=
                                                            null) {
                                                      final curCp = _cadToScene(
                                                        _currentStorey
                                                            .controlPoint!,
                                                        bounds,
                                                        viewportSize,
                                                      );
                                                      final lowCp = _cadToScene(
                                                        _lowerStorey!
                                                            .controlPoint!,
                                                        _lowerDoc!.bounds,
                                                        viewportSize,
                                                      );
                                                      offset = curCp - lowCp;
                                                    }

                                                    return Positioned.fill(
                                                      child: Transform.translate(
                                                        offset: offset,
                                                        child: Opacity(
                                                          opacity: 0.38,
                                                          child: RepaintBoundary(
                                                            child: CustomPaint(
                                                              size:
                                                                  viewportSize,
                                                              isComplex: true,
                                                              willChange: false,
                                                              painter: DxfPainter(
                                                                document:
                                                                    _lowerDoc!,
                                                                theme:
                                                                    _canvasTheme,
                                                                activeLayout:
                                                                    'Model',
                                                                currentScale:
                                                                    _renderScale,
                                                                visibleCadRect:
                                                                    _getVisibleCadRect(
                                                                      _lowerDoc!
                                                                          .bounds,
                                                                      viewportSize,
                                                                    ),
                                                                showGrid: false,
                                                                settings:
                                                                    _displaySettings,
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
                                                      currentScale:
                                                          _renderScale,
                                                      visibleCadRect:
                                                          _getVisibleCadRect(
                                                            bounds,
                                                            viewportSize,
                                                          ),
                                                      showGrid: true,
                                                      settings:
                                                          _displaySettings,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
                                          placedPoint:
                                              _currentStorey.controlPoint,
                                          draggingPoint: _isDraggingPoint
                                              ? (_activeSnapCad ??
                                                    _touchCadCoord)
                                              : null,
                                          touchPos: _isDraggingPoint
                                              ? _touchScreenPos
                                              : null,
                                          targetPos: _isDraggingPoint
                                              ? _targetScreenPos
                                              : null,
                                          snappedPos: _isDraggingPoint
                                              ? _snappedScreenPos
                                              : null,
                                          snapType: _isDraggingPoint
                                              ? _activeSnapType
                                              : null,
                                          cadToScreen: (pt) => _cadToScreen(
                                            pt,
                                            bounds,
                                            viewportSize,
                                          ),
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
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: Text(l10n.bimProjectAddUnderlay),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : _pickAndAttachUnderlayForCurrentStorey,
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
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
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
                                                _currentStorey.controlPoint!.dx
                                                    .toStringAsFixed(2),
                                                _currentStorey.controlPoint!.dy
                                                    .toStringAsFixed(2),
                                              )
                                            : l10n.bimAlignmentControlPointMissing,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_project.storeys.where((s) => s.isControlPointSet).length}/${_project.underlaysCount} aligned',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Ready / Start BiM Button
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.bimAlignmentReadyButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
  final Offset? touchPos;
  final Offset? targetPos;
  final Offset? snappedPos;
  final DxfSnapType? snapType;
  final Offset Function(Offset) cadToScreen;

  _ControlPointOverlayPainter({
    required this.placedPoint,
    required this.draggingPoint,
    this.touchPos,
    this.targetPos,
    this.snappedPos,
    this.snapType,
    required this.cadToScreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (placedPoint != null && draggingPoint == null) {
      final p = cadToScreen(placedPoint!);
      _drawBullseye(
        canvas,
        p,
        color: const Color(0xFF00E5FF),
        isPlaced: true,
        label:
            'CP: (${placedPoint!.dx.toStringAsFixed(2)}, ${placedPoint!.dy.toStringAsFixed(2)})',
      );
    }

    if (draggingPoint != null) {
      final effectiveTip =
          snappedPos ?? targetPos ?? cadToScreen(draggingPoint!);
      final bool isSnapped = snappedPos != null;
      final baseColor = isSnapped
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFF9100);
      final glowColor = baseColor.withValues(alpha: 0.35);

      // 1. Draw Touch Anchor under user's finger (if finger touch position is available)
      if (touchPos != null) {
        final touchAnchorPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        final touchBorderPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final touchCenterPaint = Paint()
          ..color = baseColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(touchPos!, 18, touchAnchorPaint);
        canvas.drawCircle(touchPos!, 18, touchBorderPaint);
        canvas.drawCircle(touchPos!, 3.5, touchCenterPaint);

        // 2. Sleek Guideline Stem connecting touch anchor to the offset target apex
        final stemPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        final glowStemPaint = Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;

        final stemPath = Path()
          ..moveTo(touchPos!.dx, touchPos!.dy - 18)
          ..lineTo(effectiveTip.dx, effectiveTip.dy + 24);

        canvas.drawPath(stemPath, glowStemPaint);
        canvas.drawPath(stemPath, stemPaint);
      }

      // 3. Offset Target Bullseye (56px above finger, fully visible)
      final snapLabel = isSnapped
          ? (snapType != null ? snapType!.name.toUpperCase() : 'SNAP')
          : 'CP';
      final coordText =
          '${draggingPoint!.dx.toStringAsFixed(2)}, ${draggingPoint!.dy.toStringAsFixed(2)}';

      _drawBullseye(
        canvas,
        effectiveTip,
        color: baseColor,
        isPlaced: false,
        label: '$snapLabel: ($coordText)',
        snapType: snapType,
      );
    }
  }

  void _drawBullseye(
    Canvas canvas,
    Offset p, {
    required Color color,
    required bool isPlaced,
    required String label,
    DxfSnapType? snapType,
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
    canvas.drawLine(
      Offset(p.dx - 28, p.dy),
      Offset(p.dx + 28, p.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(p.dx, p.dy - 28),
      Offset(p.dx, p.dy + 28),
      crossPaint,
    );

    // Snap marker glyph if snapped
    if (snapType != null) {
      final snapPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      switch (snapType) {
        case DxfSnapType.endpoint:
          canvas.drawRect(
            Rect.fromCenter(center: p, width: 14, height: 14),
            snapPaint,
          );
          break;
        case DxfSnapType.midpoint:
          final path = Path()
            ..moveTo(p.dx, p.dy - 8)
            ..lineTo(p.dx + 8, p.dy + 7)
            ..lineTo(p.dx - 8, p.dy + 7)
            ..close();
          canvas.drawPath(path, snapPaint);
          break;
        case DxfSnapType.center:
          canvas.drawCircle(p, 8, snapPaint);
          break;
        case DxfSnapType.perpendicular:
          canvas.drawLine(
            Offset(p.dx - 6, p.dy + 6),
            Offset(p.dx + 6, p.dy + 6),
            snapPaint,
          );
          canvas.drawLine(
            Offset(p.dx, p.dy + 6),
            Offset(p.dx, p.dy - 6),
            snapPaint,
          );
          break;
        default:
          canvas.drawRect(
            Rect.fromCenter(center: p, width: 12, height: 12),
            snapPaint,
          );
          break;
      }
    }

    // Center dot
    canvas.drawCircle(
      p,
      3.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Coordinate badge with rounded dark backdrop
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(
      p.dx + 16,
      p.dy - 26,
      textPainter.width + 10,
      textPainter.height + 6,
    );
    final badgeRRect = RRect.fromRectAndRadius(
      badgeRect,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      badgeRRect,
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    canvas.drawRRect(
      badgeRRect,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    textPainter.paint(canvas, Offset(p.dx + 21, p.dy - 23));
  }

  @override
  bool shouldRepaint(covariant _ControlPointOverlayPainter oldDelegate) {
    return oldDelegate.placedPoint != placedPoint ||
        oldDelegate.draggingPoint != draggingPoint ||
        oldDelegate.touchPos != touchPos ||
        oldDelegate.targetPos != targetPos ||
        oldDelegate.snappedPos != snappedPos ||
        oldDelegate.snapType != snapType;
  }
}
