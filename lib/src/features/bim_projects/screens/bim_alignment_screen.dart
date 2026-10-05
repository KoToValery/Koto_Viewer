import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_display_settings.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../../dxf_viewer/rendering/dxf_painter.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/bim_work_project.dart';
import '../services/bim_project_library_service.dart';
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
    _loadAllUnderlays();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _touchCadCoord = null;
      _activeSnapCad = null;
      _isDraggingPoint = false;
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _loadAllUnderlays() async {
    setState(() => _isLoading = true);
    final lib = BimProjectLibraryService.instance;

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
      appBar: AppBar(
        title: Text(l10n.bimAlignmentTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showOnionSkin ? Icons.layers_rounded : Icons.layers_outlined,
              color: _showOnionSkin ? const Color(0xFF00E5FF) : null,
            ),
            tooltip: l10n.bimAlignmentOnionSkin,
            onPressed: () {
              setState(() => _showOnionSkin = !_showOnionSkin);
            },
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
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                            final bounds = _currentDoc!.bounds;

                            return GestureDetector(
                              onLongPressStart: (details) {
                                final scenePos = _transformController.toScene(details.localPosition);
                                final cadPt = _sceneToCad(scenePos, bounds, viewportSize);
                                final snap = DxfSnapHelper.findSnapPoint(
                                  document: _currentDoc!,
                                  cadPoint: cadPt,
                                  toleranceCad: 0.5 * (bounds.width / 50.0),
                                );
                                setState(() {
                                  _isDraggingPoint = true;
                                  _touchCadCoord = cadPt;
                                  _activeSnapCad = snap?.point;
                                });
                                HapticFeedback.selectionClick();
                              },
                              onLongPressMoveUpdate: (details) {
                                final scenePos = _transformController.toScene(details.localPosition);
                                final cadPt = _sceneToCad(scenePos, bounds, viewportSize);
                                final snap = DxfSnapHelper.findSnapPoint(
                                  document: _currentDoc!,
                                  cadPoint: cadPt,
                                  toleranceCad: 0.5 * (bounds.width / 50.0),
                                );
                                setState(() {
                                  _touchCadCoord = cadPt;
                                  _activeSnapCad = snap?.point;
                                });
                              },
                              onLongPressEnd: (details) {
                                final target = _activeSnapCad ?? _touchCadCoord;
                                if (target != null) {
                                  _onSetControlPoint(target);
                                }
                              },
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.05,
                                maxScale: 100.0,
                                boundaryMargin: const EdgeInsets.all(double.infinity),
                                child: SizedBox(
                                  width: viewportSize.width,
                                  height: viewportSize.height,
                                  child: Stack(
                                    children: [
                                      // Optional onion skin from lower storey
                                      if (_showOnionSkin && _lowerDoc != null && _lowerStorey?.controlPoint != null && _currentStorey.controlPoint != null)
                                        Positioned.fill(
                                          child: Opacity(
                                            opacity: 0.35,
                                            child: CustomPaint(
                                              painter: DxfPainter(
                                                document: _lowerDoc!,
                                                theme: DxfCanvasTheme.darkCad,
                                                settings: const DxfDisplaySettings(),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Main active storey drawing
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: DxfPainter(
                                            document: _currentDoc!,
                                            theme: DxfCanvasTheme.darkCad,
                                            settings: const DxfDisplaySettings(),
                                          ),
                                        ),
                                      ),

                                      // Control Point Marker Overlay
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _ControlPointOverlayPainter(
                                            placedPoint: _currentStorey.controlPoint,
                                            draggingPoint: _isDraggingPoint ? (_activeSnapCad ?? _touchCadCoord) : null,
                                            cadToScene: (pt) => _cadToScene(pt, bounds, viewportSize),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            l10n.bimProjectNoUnderlay,
                            style: TextStyle(color: theme.hintColor),
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
  final Offset Function(Offset) cadToScene;

  _ControlPointOverlayPainter({
    required this.placedPoint,
    required this.draggingPoint,
    required this.cadToScene,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (placedPoint != null) {
      final p = cadToScene(placedPoint!);
      _drawBullseye(canvas, p, color: const Color(0xFF00E5FF), isPlaced: true);
    }

    if (draggingPoint != null) {
      final p = cadToScene(draggingPoint!);
      _drawBullseye(canvas, p, color: const Color(0xFFFF9100), isPlaced: false);
    }
  }

  void _drawBullseye(Canvas canvas, Offset p, {required Color color, required bool isPlaced}) {
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
    canvas.drawLine(Offset(p.dx - 26, p.dy), Offset(p.dx + 26, p.dy), crossPaint);
    canvas.drawLine(Offset(p.dx, p.dy - 26), Offset(p.dx, p.dy + 26), crossPaint);

    // Center dot
    canvas.drawCircle(p, 3, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _ControlPointOverlayPainter oldDelegate) {
    return oldDelegate.placedPoint != placedPoint ||
        oldDelegate.draggingPoint != draggingPoint;
  }
}
