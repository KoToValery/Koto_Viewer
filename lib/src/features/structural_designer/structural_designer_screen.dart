import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dxf_viewer/models/dxf_models.dart';
import '../dxf_viewer/rendering/dxf_painter.dart';
import '../dxf_viewer/rendering/dxf_snap_helper.dart';
import 'analysis/cantilever_detector.dart';
import 'models/cantilever_analysis_models.dart';
import 'models/structural_element.dart';
import 'rendering/structural_2d_painter.dart';
import 'rendering/structural_pointer_painter.dart';
import 'widgets/cantilever_analysis_sheet.dart';
import 'widgets/element_palette_bar.dart';
import 'widgets/storey_manager_sheet.dart';
import 'widgets/structural_3d_viewport.dart';

/// Main CAD/BIM Structural Designer workspace screen.
/// Enables placing columns, shear walls, and slabs over DWG/DXF underlay,
/// managing multi-storey buildings with ArchiCAD-like Trace Reference,
/// and automated real-time cantilever and deflection checks.
class StructuralDesignerScreen extends StatefulWidget {
  final DxfDocument document;
  final Rect? initialCadBounds;
  final Matrix4? initialTransform;
  final String title;

  const StructuralDesignerScreen({
    super.key,
    required this.document,
    this.initialCadBounds,
    this.initialTransform,
    this.title = 'Конструктивен Модел',
  });

  @override
  State<StructuralDesignerScreen> createState() =>
      _StructuralDesignerScreenState();
}

class _StructuralDesignerScreenState extends State<StructuralDesignerScreen> {
  late final TransformationController _transformController;

  late StructuralProject _project;
  StructuralDrawTool _activeTool = StructuralDrawTool.column;

  // Preset parameters for drawing
  StructuralColumn _currentColumnPreset = const StructuralColumn(
    id: 'preset_col',
    center: Offset.zero,
    shape: ColumnShape.rectangular,
    width: 0.25,
    height: 0.50,
  );
  double _currentWallThickness = 0.25;
  double _currentSlabThickness = 0.20;
  bool _snapEnabled = true;

  // In-progress drawing states
  Offset? _wallStartCad;
  final List<Offset> _slabPointsCad = [];

  // Pointer & Touch states (Offset pointer: 56px above finger)
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  DxfSnapResult? _activeSnap;
  Offset? _currentCadCoord;

  // History for Undo
  final List<StructuralProject> _undoStack = [];

  // Viewport & Scale
  Size _viewportSize = Size.zero;
  int _activePointersCount = 0;
  bool _isMultiTouchGesture = false;

  // Analysis result
  StructuralAnalysisSummary _analysisSummary = StructuralAnalysisSummary.empty;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController(
      widget.initialTransform != null
          ? Matrix4.copy(widget.initialTransform!)
          : Matrix4.identity(),
    );
    _project = const StructuralProject();
    _runAnalysis();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _pushUndo() {
    _undoStack.add(_project);
    if (_undoStack.length > 20) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      setState(() {
        _project = _undoStack.removeLast();
        _runAnalysis();
      });
      HapticFeedback.lightImpact();
    }
  }

  void _runAnalysis() {
    _analysisSummary = CantileverDetector.analyzeProject(_project);
  }

  // --- Coordinate Transformations ---

  Rect get _cadBounds {
    if (widget.initialCadBounds != null &&
        !widget.initialCadBounds!.isEmpty &&
        widget.initialCadBounds!.isFinite) {
      return widget.initialCadBounds!;
    }
    return widget.document.bounds;
  }

  double _getCadFitScale() {
    if (_viewportSize.isEmpty) return 1.0;
    final b = _cadBounds;
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    return math.min(
      _viewportSize.width / docW,
      _viewportSize.height / docH,
    );
  }

  Offset _sceneToCad(Offset scenePoint) {
    if (_viewportSize.isEmpty) return scenePoint;
    final double fitScale = _getCadFitScale();
    final b = _cadBounds;
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = b.left;
    final double maxY = b.bottom > b.top ? b.bottom : b.top;

    final double cadX = minX + (scenePoint.dx - tx) / fitScale;
    final double cadY = maxY - (scenePoint.dy - ty) / fitScale;

    return Offset(cadX, cadY);
  }

  Offset _cadToScene(Offset cadPoint) {
    if (_viewportSize.isEmpty) return cadPoint;
    final double fitScale = _getCadFitScale();
    final b = _cadBounds;
    final double docW = math.max(b.width, 1.0);
    final double docH = math.max(b.height, 1.0);
    final double tx = (_viewportSize.width - docW * fitScale) / 2.0;
    final double ty = (_viewportSize.height - docH * fitScale) / 2.0;

    final double minX = b.left;
    final double maxY = b.bottom > b.top ? b.bottom : b.top;

    return Offset(
      tx + (cadPoint.dx - minX) * fitScale,
      ty + (maxY - cadPoint.dy) * fitScale,
    );
  }

  Offset _screenToCad(Offset screenPoint) {
    final scenePos = _transformController.toScene(screenPoint);
    return _sceneToCad(scenePos);
  }

  Offset _cadToScreen(Offset cadPoint) {
    final scenePos = _cadToScene(cadPoint);
    return MatrixUtils.transformPoint(_transformController.value, scenePos);
  }

  // --- Pointer & Touch Handling with Offset Ruler (56px) & Magnetic Snap ---

  void _handlePointerDown(PointerDownEvent event) {
    _activePointersCount++;
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
      });
      return;
    }
    _isMultiTouchGesture = false;
    if (_activeTool != StructuralDrawTool.select) {
      _updatePointer(event.localPosition,
          isMouse: event.kind == PointerDeviceKind.mouse);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
      return;
    }
    if (_isMultiTouchGesture || _activePointersCount != 1) return;
    if (_activeTool != StructuralDrawTool.select) {
      _updatePointer(event.localPosition,
          isMouse: event.kind == PointerDeviceKind.mouse);
    }
  }

  void _updatePointer(Offset screenPos, {bool isMouse = false}) {
    final touchPos = screenPos;
    // On touch mobile: target apex is positioned 56 pixels directly above finger
    // so finger does not obscure the crosshair or CAD vertices!
    final targetPos =
        isMouse ? screenPos : (screenPos - const Offset(0, 56.0));

    final rawCad = _screenToCad(targetPos);
    DxfSnapResult? snap;
    Offset? snappedScreen;

    if (_snapEnabled) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double toleranceCad = 24.0 / (fitScale * currentScale.clamp(0.001, 10000.0));

      // 1. First search in CAD DXF geometry
      snap = DxfSnapHelper.findSnapPoint(
        document: widget.document,
        cadPoint: rawCad,
        toleranceCad: toleranceCad,
      );

      // 2. Also search in existing structural elements (columns, walls, slabs, ghost story)
      snap ??= _findStructuralSnap(rawCad, toleranceCad);

      if (snap != null) {
        if (_activeSnap == null || _activeSnap!.point != snap.point) {
          HapticFeedback.selectionClick();
        }
        snappedScreen = _cadToScreen(snap.point);
      }
    }

    final effectiveCad = snap != null ? snap.point : rawCad;

    setState(() {
      _touchScreenPos = touchPos;
      _targetScreenPos = targetPos;
      _snappedScreenPos = snappedScreen;
      _activeSnap = snap;
      _currentCadCoord = effectiveCad;
    });
  }

  DxfSnapResult? _findStructuralSnap(Offset cadPt, double toleranceCad) {
    double minDist = toleranceCad;
    DxfSnapResult? bestSnap;

    final allStoreysToSnap = [
      _project.activeStorey,
      if (_project.ghostStorey != null) _project.ghostStorey!,
    ];

    for (final s in allStoreysToSnap) {
      // Column centers and corners
      for (final col in s.columns) {
        final dCenter = (cadPt - col.center).distance;
        if (dCenter < minDist) {
          minDist = dCenter;
          bestSnap = DxfSnapResult(
            point: col.center,
            type: DxfSnapType.center,
            distance: dCenter,
          );
        }
        for (final v in col.polygonVertices) {
          final d = (cadPt - v).distance;
          if (d < minDist) {
            minDist = d;
            bestSnap = DxfSnapResult(
              point: v,
              type: DxfSnapType.endpoint,
              distance: d,
            );
          }
        }
      }

      // Wall endpoints and midpoints
      for (final w in s.shearWalls) {
        final d1 = (cadPt - w.start).distance;
        if (d1 < minDist) {
          minDist = d1;
          bestSnap = DxfSnapResult(
            point: w.start,
            type: DxfSnapType.endpoint,
            distance: d1,
          );
        }
        final d2 = (cadPt - w.end).distance;
        if (d2 < minDist) {
          minDist = d2;
          bestSnap = DxfSnapResult(
            point: w.end,
            type: DxfSnapType.endpoint,
            distance: d2,
          );
        }
      }

      // Slab polygon vertices
      for (final slab in s.slabs) {
        for (final v in slab.polygon) {
          final d = (cadPt - v).distance;
          if (d < minDist) {
            minDist = d;
            bestSnap = DxfSnapResult(
              point: v,
              type: DxfSnapType.endpoint,
              distance: d,
            );
          }
        }
      }
    }

    return bestSnap;
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointersCount = math.max(0, _activePointersCount - 1);
    if (_isMultiTouchGesture) {
      if (_activePointersCount == 0) _isMultiTouchGesture = false;
      return;
    }

    if (_activeTool != StructuralDrawTool.select && _currentCadCoord != null) {
      _commitPlacement(_currentCadCoord!);
    }

    setState(() {
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeSnap = null;
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointersCount = 0;
    _isMultiTouchGesture = false;
    setState(() {
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _activeSnap = null;
    });
  }

  // --- Element Placement Logic ---

  void _commitPlacement(Offset cadCoord) {
    final active = _project.activeStorey;

    if (_activeTool == StructuralDrawTool.column) {
      _pushUndo();
      final newCol = _currentColumnPreset.copyWith(
        id: 'col_${DateTime.now().millisecondsSinceEpoch}',
        center: cadCoord,
      );
      final updatedColumns = List<StructuralColumn>.from(active.columns)
        ..add(newCol);
      final updatedStorey = active.copyWith(columns: updatedColumns);
      _updateActiveStorey(updatedStorey);
      HapticFeedback.mediumImpact();
    } else if (_activeTool == StructuralDrawTool.shearWall) {
      if (_wallStartCad == null) {
        // Step 1: Set wall start point
        setState(() => _wallStartCad = cadCoord);
        HapticFeedback.lightImpact();
      } else {
        // Step 2: Set wall end point and commit
        if ((cadCoord - _wallStartCad!).distance >= 0.3) {
          _pushUndo();
          final newWall = StructuralShearWall(
            id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
            start: _wallStartCad!,
            end: cadCoord,
            thickness: _currentWallThickness,
          );
          final updatedWalls = List<StructuralShearWall>.from(active.shearWalls)
            ..add(newWall);
          final updatedStorey = active.copyWith(shearWalls: updatedWalls);
          _updateActiveStorey(updatedStorey);
          HapticFeedback.mediumImpact();
        }
        setState(() => _wallStartCad = null);
      }
    } else if (_activeTool == StructuralDrawTool.slab) {
      // Add vertex to polygon
      setState(() => _slabPointsCad.add(cadCoord));
      HapticFeedback.lightImpact();
    }
  }

  void _closeSlabPolygon() {
    if (_slabPointsCad.length >= 3) {
      _pushUndo();
      final active = _project.activeStorey;
      final newSlab = StructuralSlab(
        id: 'slab_${DateTime.now().millisecondsSinceEpoch}',
        polygon: List.from(_slabPointsCad),
        thickness: _currentSlabThickness,
      );
      final updatedSlabs = List<StructuralSlab>.from(active.slabs)..add(newSlab);
      final updatedStorey = active.copyWith(slabs: updatedSlabs);
      _updateActiveStorey(updatedStorey);

      setState(() => _slabPointsCad.clear());
      HapticFeedback.heavyImpact();
    }
  }

  void _updateActiveStorey(StoreyLevel newStorey) {
    final storeys = List<StoreyLevel>.from(_project.storeys);
    storeys[_project.activeStoreyIndex] = newStorey;
    setState(() {
      _project = _project.copyWith(storeys: storeys);
      _runAnalysis();
    });
  }

  // --- Storey Management Actions ---

  void _openStoreyManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StoreyManagerSheet(
        project: _project,
        onSelectStorey: (idx) {
          setState(() {
            _project = _project.copyWith(activeStoreyIndex: idx);
            _slabPointsCad.clear();
            _wallStartCad = null;
            _runAnalysis();
          });
        },
        onGhostModeChanged: (mode) {
          setState(() => _project = _project.copyWith(ghostMode: mode));
        },
        onUpdateHeight: (idx, newH) {
          final storeys = List<StoreyLevel>.from(_project.storeys);
          storeys[idx] = storeys[idx].copyWith(height: newH);
          setState(() {
            _project = _project.copyWith(storeys: storeys);
            _runAnalysis();
          });
        },
        onAddStorey: () {
          _pushUndo();
          final nextIdx = _project.storeys.length + 1;
          final lastStorey = _project.storeys.last;
          final newElev = lastStorey.elevation + lastStorey.height;
          final newStorey = StoreyLevel(
            id: 'storey_$nextIdx',
            name: 'Етаж $nextIdx (Кота +${newElev.toStringAsFixed(2)})',
            elevation: newElev,
            height: lastStorey.height,
          );
          final updated = List<StoreyLevel>.from(_project.storeys)..add(newStorey);
          setState(() {
            _project = _project.copyWith(
              storeys: updated,
              activeStoreyIndex: updated.length - 1,
            );
            _runAnalysis();
          });
          HapticFeedback.mediumImpact();
        },
        onDuplicateCurrentStorey: () {
          _pushUndo();
          final active = _project.activeStorey;
          final nextIdx = _project.storeys.length + 1;
          final lastStorey = _project.storeys.last;
          final newElev = lastStorey.elevation + lastStorey.height;

          final duplicated = active.cloneToNextLevel(
            newId: 'storey_$nextIdx',
            newName: 'Етаж $nextIdx (Типов от ${active.name})',
            newElevation: newElev,
          );
          final updated = List<StoreyLevel>.from(_project.storeys)..add(duplicated);
          setState(() {
            _project = _project.copyWith(
              storeys: updated,
              activeStoreyIndex: updated.length - 1,
            );
            _runAnalysis();
          });
          HapticFeedback.heavyImpact();
        },
        onDeleteStorey: (idx) {
          if (_project.storeys.length <= 1) return;
          _pushUndo();
          final updated = List<StoreyLevel>.from(_project.storeys)..removeAt(idx);
          final newActive = math.min(_project.activeStoreyIndex, updated.length - 1);
          setState(() {
            _project = _project.copyWith(
              storeys: updated,
              activeStoreyIndex: newActive,
            );
            _runAnalysis();
          });
        },
      ),
    );
  }

  void _openCantileverReport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CantileverAnalysisSheet(summary: _analysisSummary),
    );
  }

  void _open3dViewport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Structural3dViewport(
          project: _project,
          cantileverZones: _analysisSummary.zones,
          onExit: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          onTap: _openStoreyManager,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_rounded,
                    size: 18, color: Color(0xFF00E5FF)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _project.activeStorey.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          ),
        ),
        actions: [
          // Snap Toggle
          IconButton(
            icon: Icon(
              _snapEnabled ? Icons.grain_rounded : Icons.lens_blur_rounded,
              color: _snapEnabled ? const Color(0xFF00E5FF) : Colors.white38,
            ),
            tooltip: _snapEnabled
                ? 'Прилепване (Snap): Включено'
                : 'Прилепване (Snap): Изключено',
            onPressed: () {
              setState(() => _snapEnabled = !_snapEnabled);
              HapticFeedback.selectionClick();
            },
          ),
          // Undo Button
          IconButton(
            icon: Icon(Icons.undo_rounded,
                color: _undoStack.isNotEmpty ? Colors.white : Colors.white24),
            tooltip: 'Отмени последно действие',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          // 3D Viewport Launcher
          IconButton(
            icon: const Icon(Icons.view_in_ar_rounded, color: Color(0xFFFFB300)),
            tooltip: '3D Конструкция',
            onPressed: _open3dViewport,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              // 1. Gesture Listener wrapping InteractiveViewer:
              // Allows single-finger placement with 56px offset ruler,
              // while simultaneously enabling free 2-finger pinch-to-zoom and pan anytime!
              Positioned.fill(
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    panEnabled: _activeTool == StructuralDrawTool.select || _isMultiTouchGesture,
                    scaleEnabled: true,
                    scaleFactor: 350.0,
                    trackpadScrollCausesScale: true,
                    minScale: 0.001,
                    maxScale: 1000.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    onInteractionStart: (details) {
                      if (details.pointerCount > 1) {
                        setState(() {
                          _isMultiTouchGesture = true;
                          _touchScreenPos = null;
                          _targetScreenPos = null;
                          _snappedScreenPos = null;
                          _activeSnap = null;
                        });
                      }
                    },
                    onInteractionEnd: (details) {
                      _activePointersCount = 0;
                      _isMultiTouchGesture = false;
                    },
                    child: SizedBox(
                      width: _viewportSize.width,
                      height: _viewportSize.height,
                      child: Stack(
                        children: [
                          // CAD DWG/DXF Architecture Underlay (dimmed)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: DxfPainter(
                                  document: widget.document,
                                  theme: DxfCanvasTheme.darkCad,
                                  activeLayout: 'Model',
                                  currentScale: 1.0,
                                ),
                              ),
                            ),
                          ),
                          // Structural Elements Layer (Columns, Walls, Slabs, Ghost Story, Cantilever badges)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: Structural2dPainter(
                                currentStorey: _project.activeStorey,
                                ghostStorey: _project.ghostStorey,
                                cantileverZones: _analysisSummary.zones,
                                showCantileverHeatmap: true,
                                activeTool: _activeTool,
                                previewColumn: _currentColumnPreset,
                                previewColumnPos: _currentCadCoord,
                                wallStartPos: _wallStartCad,
                                currentCursorCad: _currentCadCoord,
                                slabPointsInProgress: _slabPointsCad,
                                zoomScale: _transformController.value.getMaxScaleOnAxis(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Screen-Space Offset Target Pointer with Stem Guideline & Live Dimensioning
              if (_touchScreenPos != null && _targetScreenPos != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: StructuralPointerPainter(
                        touchPos: _touchScreenPos!,
                        targetPos: _targetScreenPos!,
                        snappedPos: _snappedScreenPos,
                        snapType: _activeSnap?.type,
                        activeTool: _activeTool,
                        previewColumn: _currentColumnPreset,
                        wallStartPos: _wallStartCad != null ? _cadToScreen(_wallStartCad!) : null,
                        slabPoints: _slabPointsCad.map(_cadToScreen).toList(),
                      ),
                    ),
                  ),
                ),

              // 4. Trace Reference Status Pill (Top Center)
              if (_project.ghostStorey != null)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D253A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00E5FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              size: 14, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 6),
                          Text(
                            'Референтен слой (Trace): ${_project.ghostStorey!.name}',
                            style: const TextStyle(
                                color: Color(0xFF00E5FF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Palette Dock Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ElementPaletteBar(
                  activeTool: _activeTool,
                  onSelectTool: (tool) {
                    setState(() {
                      _activeTool = tool;
                      _wallStartCad = null;
                    });
                  },
                  currentColumnPreset: _currentColumnPreset,
                  onUpdateColumnPreset: (preset) {
                    setState(() => _currentColumnPreset = preset);
                  },
                  currentWallThickness: _currentWallThickness,
                  onUpdateWallThickness: (t) {
                    setState(() => _currentWallThickness = t);
                  },
                  currentSlabThickness: _currentSlabThickness,
                  onUpdateSlabThickness: (t) {
                    setState(() => _currentSlabThickness = t);
                  },
                  isDrawingSlab: _activeTool == StructuralDrawTool.slab,
                  slabPointCount: _slabPointsCad.length,
                  onCloseSlab: _closeSlabPolygon,
                  onUndoPoint: () {
                    if (_slabPointsCad.isNotEmpty) {
                      setState(() => _slabPointsCad.removeLast());
                    }
                  },
                  onClearSlab: () {
                    setState(() => _slabPointsCad.clear());
                  },
                  onRotateColumn: () {
                    setState(() {
                      final double w = _currentColumnPreset.width;
                      final double h = _currentColumnPreset.height;
                      _currentColumnPreset = _currentColumnPreset.copyWith(
                        width: h,
                        height: w,
                      );
                    });
                    HapticFeedback.selectionClick();
                  },
                  onOpenCantileverReport: _openCantileverReport,
                  analysisSummary: _analysisSummary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
