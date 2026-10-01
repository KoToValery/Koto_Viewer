import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../dxf_viewer/models/dxf_models.dart';
import '../dxf_viewer/rendering/dxf_painter.dart';
import '../dxf_viewer/rendering/dxf_snap_helper.dart';
import 'analysis/cantilever_detector.dart';
import 'analysis/structural_underlay_filter.dart';
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
  final String? title;

  const StructuralDesignerScreen({
    super.key,
    required this.document,
    this.initialCadBounds,
    this.initialTransform,
    this.title,
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
    height: 0.25,
    thickness: 0.25,
  );
  double _currentWallThickness = 0.25;
  double _currentSlabThickness = 0.20;
  bool _snapEnabled = true;

  // In-progress drawing states
  Offset? _wallStartCad;
  Offset? _slabStartCornerCad;
  final List<Offset> _slabPointsCad = [];

  // Midpoint edge extrusion states (Cantilever / еркер drag)
  SlabEdgeGripInfo? _activeGrip;
  String? _activeExtrudingSlabId;
  bool _isExtrudingEdge = false;
  double _extrusionDistanceCad = 0.0;

  // Pointer & Touch states (Offset pointer: dynamic height above finger)
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  List<Offset> _snappedScreenPositions = [];
  DxfSnapResult? _activeSnap;
  String? _liveDimensionText;
  Offset? _currentCadCoord;
  bool _isPlacingWithHold = false;
  bool _initializedStoreyName = false;

  // Selection and move states (Column & Shear Wall edit/drag)
  StructuralColumn? _selectedColumn;
  StructuralShearWall? _selectedShearWall;
  bool _isMovingColumn = false;
  bool _hasMovedSelectedColumn = false;

  // Slab Correction States (Kotocadastre object correction workflow)
  StructuralSlab? _editingSlab;
  bool get _isEditingSlab => _editingSlab != null;
  StructuralSlab? _initialSlabBeforeCorrection;
  final List<StructuralSlab> _slabCorrectionUndoStack = [];
  int? _draggingSlabVertexIndex;
  Offset? _draggingSlabVertexCad;
  int? _mergeCandidateSlabVertexIndex;
  Offset? _midpointTouchDownPos;

  // History for Undo
  final List<StructuralProject> _undoStack = [];

  // Viewport & Scale
  Size _viewportSize = Size.zero;
  int _activePointersCount = 0;
  PointerDeviceKind? _activePointerKind;
  bool _isMultiTouchGesture = false;
  double _renderScale = 1.0;
  Timer? _scaleSettleTimer;

  // Layer filter for structural underlay (isolate thick walls & grid axes)
  bool _underlayFilterActive = false;
  final Map<String, bool> _originalLayerVisibility = {};

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
    final initialScale = widget.initialTransform?.getMaxScaleOnAxis() ?? 1.0;
    _renderScale = initialScale.clamp(0.001, 10000.0);
    _transformController.addListener(_onTransformChanged);

    for (final entry in widget.document.layers.entries) {
      _originalLayerVisibility[entry.key] = entry.value.isVisible;
    }

    // Underlay filter starts off (all layers visible as in commit e781d51).
    // The user can manually toggle structural underlay filtering via the AppBar funnel icon.

    _project = const StructuralProject();
    _runAnalysis();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedStoreyName && _project.storeys.isNotEmpty) {
      _initializedStoreyName = true;
      final storeys = List<StoreyLevel>.from(_project.storeys);
      final first = storeys[0];
      if (first.name.startsWith('Етаж 1') || first.name.startsWith('Storey 1')) {
        storeys[0] = first.copyWith(name: context.l10n.storeyLevelName(1, '0.00'));
        _project = _project.copyWith(storeys: storeys);
      }
    }
  }

  @override
  void dispose() {
    _scaleSettleTimer?.cancel();
    _transformController.removeListener(_onTransformChanged);
    for (final entry in _originalLayerVisibility.entries) {
      widget.document.layers[entry.key]?.isVisible = entry.value;
    }
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    _scaleSettleTimer?.cancel();
    _scaleSettleTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      final currentScale =
          _transformController.value.getMaxScaleOnAxis().clamp(0.001, 10000.0);
      if ((currentScale - _renderScale).abs() / _renderScale > 0.05) {
        setState(() {
          _renderScale = currentScale;
        });
      }
    });
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
        _selectedColumn = null;
        _isMovingColumn = false;
        _editingSlab = null;
        _initialSlabBeforeCorrection = null;
        _project = _undoStack.removeLast();
        _runAnalysis();
      });
      HapticFeedback.lightImpact();
    }
  }

  double get _cadUnitsPerMeter {
    final unit = widget.document.unit;
    if (unit != DxfUnit.unitless && unit.toMeters > 0) {
      return 1.0 / unit.toMeters;
    }
    final b = _cadBounds;
    final maxDim = math.max(b.width, b.height);
    if (maxDim > 500.0) {
      return 1000.0; // millimeters
    } else if (maxDim > 60.0) {
      return 100.0; // centimeters
    }
    return 1.0; // meters
  }

  void _runAnalysis() {
    _analysisSummary = CantileverDetector.analyzeProject(
      _project,
      cadUnitsPerMeter: _cadUnitsPerMeter,
    );
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
    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);
    return math.min(availW / docW, availH / docH);
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

  SlabEdgeGripInfo? _hitTestSlabMidpoint(Offset screenPos) {
    const double hitRadiusScreen = 28.0;
    for (final slab in _project.activeStorey.slabs) {
      for (final grip in slab.edgeGrips) {
        final screenGrip = _cadToScreen(grip.midpoint);
        if ((screenPos - screenGrip).distance <= hitRadiusScreen) {
          _activeExtrudingSlabId = slab.id;
          return grip;
        }
      }
    }
    return null;
  }

  StructuralColumn? _hitTestColumn(Offset screenPos) {
    const double hitMarginScreen = 28.0;
    for (final col in _project.activeStorey.columns.reversed) {
      final pts = col.polygonVertices.map(_cadToScreen).toList();
      if (pts.isEmpty) continue;
      double minX = pts.first.dx, maxX = pts.first.dx;
      double minY = pts.first.dy, maxY = pts.first.dy;
      for (final p in pts) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      final rect =
          Rect.fromLTRB(minX, minY, maxX, maxY).inflate(hitMarginScreen);
      if (rect.contains(screenPos)) {
        return col;
      }
    }
    return null;
  }

  StructuralShearWall? _hitTestShearWall(Offset screenPos) {
    const double hitMarginScreen = 24.0;
    for (final wall in _project.activeStorey.shearWalls.reversed) {
      final pts = wall.polygonVertices.map(_cadToScreen).toList();
      if (pts.isEmpty) continue;
      double minX = pts.first.dx, maxX = pts.first.dx;
      double minY = pts.first.dy, maxY = pts.first.dy;
      for (final p in pts) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      final rect = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(hitMarginScreen);
      if (rect.contains(screenPos)) {
        return wall;
      }
    }
    return null;
  }

  StructuralSlab? _hitTestSlab(Offset screenPos) {
    final active = _project.activeStorey;
    final cadPt = _screenToCad(screenPos);
    // 1. Point in polygon test
    for (final slab in active.slabs.reversed) {
      if (slab.containsPoint(cadPt)) {
        return slab;
      }
    }
    // 2. Near edge check (screen tolerance ~ 24px)
    const double edgeTolScreen = 24.0;
    for (final slab in active.slabs.reversed) {
      final pts = slab.polygon.map(_cadToScreen).toList();
      for (int i = 0; i < pts.length; i++) {
        final p1 = pts[i];
        final p2 = pts[(i + 1) % pts.length];
        final dist = _distToSegment(screenPos, p1, p2);
        if (dist <= edgeTolScreen) {
          return slab;
        }
      }
    }
    return null;
  }

  int? _hitTestSlabVertex(Offset screenPos, StructuralSlab slab) {
    const double hitRadiusScreen = 28.0;
    for (int i = 0; i < slab.polygon.length; i++) {
      final sPt = _cadToScreen(slab.polygon[i]);
      if ((screenPos - sPt).distance <= hitRadiusScreen) {
        return i;
      }
    }
    return null;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2)
        .clamp(0.0, 1.0);
    final proj = a + ab * t;
    return (p - proj).distance;
  }

  void _deleteSelectedColumn() {
    if (_selectedColumn == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final updatedCols =
        active.columns.where((c) => c.id != _selectedColumn!.id).toList();
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = null;
      _isMovingColumn = false;
    });
    HapticFeedback.heavyImpact();
  }

  void _rotateSelectedColumn() {
    if (_selectedColumn == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final col = _selectedColumn!;
    final updatedCol = col.copyWith(
      rotationRad: (col.rotationRad + math.pi / 2.0) % (2 * math.pi),
    );
    final updatedCols = active.columns
        .map((c) => c.id == updatedCol.id ? updatedCol : c)
        .toList();
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = updatedCol;
    });
    HapticFeedback.selectionClick();
  }

  void _mirrorSelectedColumn() {
    if (_selectedColumn == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final col = _selectedColumn!;

    final StructuralColumn updatedCol;
    if (col.shape == ColumnShape.lShape) {
      // Mirroring L-shaped column flips the orientation of the L
      updatedCol = col.copyWith(
        isMirrored: !col.isMirrored,
      );
    } else {
      // True geometric reflection across vertical axis: theta -> (pi - theta)
      final double newRot = (math.pi - col.rotationRad) % (2 * math.pi);
      updatedCol = col.copyWith(
        rotationRad: newRot,
      );
    }

    final updatedCols = active.columns
        .map((c) => c.id == updatedCol.id ? updatedCol : c)
        .toList();
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = updatedCol;
    });
    HapticFeedback.selectionClick();
  }

  void _updateSelectedColumnDimensions(double deltaWMeters, double deltaHMeters) {
    if (_selectedColumn == null) return;
    _pushUndo();
    final col = _selectedColumn!;
    final active = _project.activeStorey;
    final scale = _cadUnitsPerMeter;
    final currentWM = col.width / scale;
    final currentHM = col.height / scale;
    final newWM = (currentWM + deltaWMeters).clamp(0.15, 3.0);
    final newHM = (currentHM + deltaHMeters).clamp(0.15, 3.0);
    final updatedCol = col.copyWith(
      width: double.parse(newWM.toStringAsFixed(2)) * scale,
      height: double.parse(newHM.toStringAsFixed(2)) * scale,
    );
    final updatedCols = active.columns
        .map((c) => c.id == updatedCol.id ? updatedCol : c)
        .toList();
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = updatedCol;
    });
    HapticFeedback.selectionClick();
  }

  void _duplicateSelectedColumn() {
    if (_selectedColumn == null) return;
    _pushUndo();
    final col = _selectedColumn!;
    final active = _project.activeStorey;
    final offset = Offset(0.20 * _cadUnitsPerMeter, -0.20 * _cadUnitsPerMeter);
    final dup = StructuralColumn(
      id: 'col_${DateTime.now().millisecondsSinceEpoch}',
      center: col.center + offset,
      shape: col.shape,
      width: col.width,
      height: col.height,
      rotationRad: col.rotationRad,
      thickness: col.thickness,
      isMirrored: col.isMirrored,
    );
    final updatedCols = List<StructuralColumn>.from(active.columns)..add(dup);
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = dup;
      _isMovingColumn = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _deleteSelectedWall() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final updatedWalls =
        active.shearWalls.where((w) => w.id != _selectedShearWall!.id).toList();
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = null;
    });
    HapticFeedback.heavyImpact();
  }

  void _flipSelectedWall() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final wall = _selectedShearWall!;
    final updatedWall = wall.copyWith(isFlipped: !wall.isFlipped);
    final updatedWalls = active.shearWalls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = updatedWall;
    });
    HapticFeedback.selectionClick();
  }

  void _duplicateSelectedWall() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final wall = _selectedShearWall!;
    final active = _project.activeStorey;
    final offset = Offset(0.25 * _cadUnitsPerMeter, -0.25 * _cadUnitsPerMeter);
    final dup = StructuralShearWall(
      id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
      start: wall.start + offset,
      end: wall.end + offset,
      thickness: wall.thickness,
      isFlipped: wall.isFlipped,
    );
    final updatedWalls = List<StructuralShearWall>.from(active.shearWalls)..add(dup);
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = dup;
    });
    HapticFeedback.mediumImpact();
  }

  void _updateSelectedWallLength(double deltaMeters) {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final wall = _selectedShearWall!;
    final active = _project.activeStorey;
    final l = wall.length;
    final newL = math.max(0.30 * _cadUnitsPerMeter, l + deltaMeters * _cadUnitsPerMeter);
    final dir = (wall.end - wall.start) / (l > 1e-6 ? l : 1.0);
    final newEnd = wall.start + dir * newL;
    final updatedWall = wall.copyWith(end: newEnd);
    final updatedWalls = active.shearWalls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = updatedWall;
    });
    HapticFeedback.selectionClick();
  }

  void _mirrorEditingSlab() {
    if (_editingSlab == null) return;
    _pushSlabCorrectionUndo();
    final poly = _editingSlab!.polygon;
    if (poly.isEmpty) return;
    double minX = poly.first.dx, maxX = poly.first.dx;
    for (final p in poly) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
    }
    final double midX = (minX + maxX) / 2.0;

    final mirroredPoly = poly.map((p) => Offset(2 * midX - p.dx, p.dy)).toList();
    final mirroredOpenings = _editingSlab!.openings.map((op) {
      return op.map((p) => Offset(2 * midX - p.dx, p.dy)).toList();
    }).toList();

    setState(() {
      _editingSlab = _editingSlab!.copyWith(
        polygon: mirroredPoly,
        openings: mirroredOpenings,
      );
      _updateActiveStoreySlab(_editingSlab!);
    });
    HapticFeedback.selectionClick();
  }

  // --- Slab Correction Methods (Kotocadastre Object Correction Workflow) ---

  void _startSlabCorrection(StructuralSlab slab) {
    setState(() {
      _selectedColumn = null;
      _isMovingColumn = false;
      _isPlacingWithHold = false;
      _wallStartCad = null;
      _slabStartCornerCad = null;
      _slabPointsCad.clear();
      _editingSlab = slab;
      _initialSlabBeforeCorrection = slab;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _midpointTouchDownPos = null;
    });
    HapticFeedback.selectionClick();
  }

  void _pushSlabCorrectionUndo() {
    if (_editingSlab == null) return;
    _slabCorrectionUndoStack.add(_editingSlab!);
    if (_slabCorrectionUndoStack.length > 25) {
      _slabCorrectionUndoStack.removeAt(0);
    }
  }

  void _undoSlabCorrection() {
    if (_slabCorrectionUndoStack.isNotEmpty) {
      setState(() {
        _editingSlab = _slabCorrectionUndoStack.removeLast();
        _updateActiveStoreySlab(_editingSlab!);
      });
      HapticFeedback.lightImpact();
    }
  }

  void _updateActiveStoreySlab(StructuralSlab slab) {
    final active = _project.activeStorey;
    final updatedSlabs =
        active.slabs.map((s) => s.id == slab.id ? slab : s).toList();
    _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
  }

  void _cancelSlabCorrection() {
    if (_initialSlabBeforeCorrection != null) {
      _updateActiveStoreySlab(_initialSlabBeforeCorrection!);
    }
    setState(() {
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _midpointTouchDownPos = null;
    });
    HapticFeedback.selectionClick();
  }

  void _saveSlabCorrection() {
    if (_editingSlab == null) return;
    _pushUndo();
    final cleaned = _cleanSlabPolygon(_editingSlab!);
    _updateActiveStoreySlab(cleaned);
    setState(() {
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _midpointTouchDownPos = null;
      _runAnalysis();
    });
    HapticFeedback.mediumImpact();
  }

  void _deleteEditingSlab() {
    if (_editingSlab == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final updatedSlabs =
        active.slabs.where((s) => s.id != _editingSlab!.id).toList();
    _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
    setState(() {
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _midpointTouchDownPos = null;
    });
    HapticFeedback.heavyImpact();
  }

  StructuralSlab _cleanSlabPolygon(StructuralSlab slab) {
    if (slab.polygon.length <= 3) return slab;
    final List<Offset> pts = List.from(slab.polygon);
    final minDistanceCad = 0.05 * _cadUnitsPerMeter;

    // 1. Remove duplicate adjacent points
    bool changed = true;
    while (changed && pts.length > 3) {
      changed = false;
      for (int i = 0; i < pts.length; i++) {
        final next = (i + 1) % pts.length;
        if ((pts[i] - pts[next]).distance < minDistanceCad) {
          pts.removeAt(next);
          changed = true;
          break;
        }
      }
    }

    // 2. Remove collinear points
    changed = true;
    while (changed && pts.length > 3) {
      changed = false;
      for (int i = 0; i < pts.length; i++) {
        final prev = (i - 1 + pts.length) % pts.length;
        final next = (i + 1) % pts.length;
        final v1 = pts[i] - pts[prev];
        final v2 = pts[next] - pts[i];
        final l1 = v1.distance;
        final l2 = v2.distance;
        if (l1 > 1e-4 && l2 > 1e-4) {
          final cross = (v1.dx * v2.dy - v1.dy * v2.dx) / (l1 * l2);
          final dot = (v1.dx * v2.dx + v1.dy * v2.dy) / (l1 * l2);
          if (cross.abs() < 0.015 && dot > 0.99) {
            pts.removeAt(i);
            changed = true;
            break;
          }
        }
      }
    }

    return slab.copyWith(polygon: pts);
  }

  void _updateSlabVertexDrag(Offset screenPos) {
    if (_editingSlab == null || _draggingSlabVertexIndex == null) return;

    final rawCad = _screenToCad(screenPos);
    DxfSnapResult? snap;
    if (_snapEnabled) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double toleranceCad =
          24.0 / (fitScale * currentScale.clamp(0.001, 10000.0));
      snap = DxfSnapHelper.findSnapPoint(
        document: widget.document,
        cadPoint: rawCad,
        toleranceCad: toleranceCad,
      );
      snap ??= _findStructuralSnap(rawCad, toleranceCad);
    }
    final effectiveCad = snap?.point ?? rawCad;

    // Check snap-to-merge with adjacent vertices
    final polygon = _editingSlab!.polygon;
    final count = polygon.length;
    final idx = _draggingSlabVertexIndex!;
    final prevIdx = (idx - 1 + count) % count;
    final nextIdx = (idx + 1) % count;

    final sPrev = _cadToScreen(polygon[prevIdx]);
    final sNext = _cadToScreen(polygon[nextIdx]);
    const double mergeSnapRadiusScreen = 28.0;

    int? candidate;
    if ((screenPos - sPrev).distance <= mergeSnapRadiusScreen) {
      candidate = prevIdx;
    } else if ((screenPos - sNext).distance <= mergeSnapRadiusScreen) {
      candidate = nextIdx;
    }

    if (candidate != _mergeCandidateSlabVertexIndex) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _draggingSlabVertexCad = effectiveCad;
      _mergeCandidateSlabVertexIndex = candidate;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointersCount++;
    _activePointerKind = event.kind;
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
      if (_isPlacingWithHold) {
        setState(() {
          _isPlacingWithHold = false;
          _touchScreenPos = null;
          _targetScreenPos = null;
          _snappedScreenPos = null;
          _activeSnap = null;
        });
      }
      if (_isExtrudingEdge || _activeGrip != null) {
        setState(() {
          _isExtrudingEdge = false;
          _activeGrip = null;
          _activeExtrudingSlabId = null;
          _midpointTouchDownPos = null;
          _extrusionDistanceCad = 0.0;
        });
      }
      if (_isMovingColumn) {
        setState(() {
          _isMovingColumn = false;
          _touchScreenPos = null;
          _targetScreenPos = null;
          _snappedScreenPos = null;
          _activeSnap = null;
        });
      }
      if (_draggingSlabVertexIndex != null) {
        setState(() {
          _draggingSlabVertexIndex = null;
          _draggingSlabVertexCad = null;
          _mergeCandidateSlabVertexIndex = null;
        });
      }
      return;
    }
    _isMultiTouchGesture = false;

    // 1. If currently in Slab Correction Mode:
    if (_isEditingSlab) {
      // Check if tapped on a vertex handle of the editing slab
      final vIdx = _hitTestSlabVertex(event.localPosition, _editingSlab!);
      if (vIdx != null) {
        setState(() {
          _draggingSlabVertexIndex = vIdx;
          _draggingSlabVertexCad = _editingSlab!.polygon[vIdx];
          _mergeCandidateSlabVertexIndex = null;
        });
        HapticFeedback.selectionClick();
        return;
      }

      // Check if touched on a midpoint grip of the editing slab
      final grip = _hitTestSlabMidpoint(event.localPosition);
      if (grip != null) {
        setState(() {
          _activeGrip = grip;
          _activeExtrudingSlabId = _editingSlab!.id;
          _midpointTouchDownPos = event.localPosition;
          _isExtrudingEdge = false;
          _extrusionDistanceCad = 0.0;
        });
        HapticFeedback.selectionClick();
        return;
      }

      // Check if user tapped another slab to switch correction to it
      final hitAnotherSlab = _hitTestSlab(event.localPosition);
      if (hitAnotherSlab != null && hitAnotherSlab.id != _editingSlab!.id) {
        _startSlabCorrection(hitAnotherSlab);
        return;
      }
    }

    // 2. Check hit test on slab midpoint grips for edge extrusion or edit mode
    final grip = _hitTestSlabMidpoint(event.localPosition);
    if (grip != null) {
      setState(() {
        _activeGrip = grip;
        _midpointTouchDownPos = event.localPosition;
        _isExtrudingEdge = false;
        _extrusionDistanceCad = 0.0;
        _selectedColumn = null;
      });
      HapticFeedback.selectionClick();
      return;
    }

    // 3. Selection mode taps on column or slab
    if (!_isEditingSlab && _activeTool == StructuralDrawTool.select) {
      final hitCol = _hitTestColumn(event.localPosition);
      if (hitCol != null) {
        setState(() {
          _selectedColumn = hitCol;
          _isMovingColumn = true;
          _hasMovedSelectedColumn = false;
          _isPlacingWithHold = false;
        });
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        HapticFeedback.selectionClick();
        return;
      }

      final hitSlab = _hitTestSlab(event.localPosition);
      if (hitSlab != null) {
        _startSlabCorrection(hitSlab);
        return;
      }
    }

    // 4. If a column was already selected and user taps somewhere outside
    if (_selectedColumn != null && !_isMovingColumn) {
      final hit = _hitTestColumn(event.localPosition);
      if (hit == null) {
        setState(() {
          _selectedColumn = null;
        });
      }
    }

    // 5. Mouse interactions
    if (event.kind == PointerDeviceKind.mouse) {
      final hitCol = _hitTestColumn(event.localPosition);
      if (hitCol != null) {
        setState(() {
          _selectedColumn = hitCol;
          _isMovingColumn = true;
          _hasMovedSelectedColumn = false;
          _isPlacingWithHold = false;
        });
        _updatePointer(event.localPosition, isMouse: true);
        HapticFeedback.selectionClick();
        return;
      }
      final hitSlab = _hitTestSlab(event.localPosition);
      if (hitSlab != null) {
        _startSlabCorrection(hitSlab);
        return;
      }
      if (!_isEditingSlab) {
        _isPlacingWithHold = true;
        _updatePointer(event.localPosition, isMouse: true);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
      return;
    }
    if (_isMultiTouchGesture || _activePointersCount != 1) return;

    // A. Dragging slab vertex
    if (_draggingSlabVertexIndex != null) {
      _updateSlabVertexDrag(event.localPosition);
      return;
    }

    // B. Midpoint grip dragging (parallel extrusion)
    if (_activeGrip != null) {
      if (!_isExtrudingEdge && _midpointTouchDownPos != null) {
        if ((event.localPosition - _midpointTouchDownPos!).distance > 8.0) {
          _isExtrudingEdge = true;
        }
      }
      if (_isExtrudingEdge) {
        _updateEdgeExtrusion(event.localPosition);
      }
      return;
    }

    // C. Moving column with mouse
    if (event.kind == PointerDeviceKind.mouse &&
        _isMovingColumn &&
        _selectedColumn != null) {
      _updatePointer(event.localPosition, isMouse: true);
      final effectiveCad = _activeSnap?.point ?? _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedColumn!.topLeft).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedColumn = true;
        }
      }
      return;
    }

    // D. Placing element with mouse hold
    if (event.kind == PointerDeviceKind.mouse && _isPlacingWithHold) {
      _updatePointer(event.localPosition, isMouse: true);
    }
  }

  void _updateEdgeExtrusion(Offset screenPos) {
    final rawCad = _screenToCad(screenPos);
    DxfSnapResult? snap;
    if (_snapEnabled) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double toleranceCad = 24.0 / (fitScale * currentScale.clamp(0.001, 10000.0));
      snap = DxfSnapHelper.findSnapPoint(
        document: widget.document,
        cadPoint: rawCad,
        toleranceCad: toleranceCad,
      );
      snap ??= _findStructuralSnap(rawCad, toleranceCad);
    }
    final effectiveCad = snap?.point ?? rawCad;
    final disp = effectiveCad - _activeGrip!.midpoint;
    final d = disp.dx * _activeGrip!.normal.dx + disp.dy * _activeGrip!.normal.dy;

    setState(() {
      _extrusionDistanceCad = d;
    });
  }

  void _updatePointer(Offset screenPos, {bool isMouse = false}) {
    final touchPos = screenPos;

    // 1. Position target so the ENTIRE element is shifted above the finger and 100% visible
    double offsetAboveFinger = 72.0;
    if (!isMouse && (_activeTool == StructuralDrawTool.column || _isMovingColumn)) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double cadScale = fitScale * currentScale.clamp(0.001, 10000.0);
      final double colH = (_isMovingColumn && _selectedColumn != null)
          ? _selectedColumn!.height
          : _currentColumnPreset.height * _cadUnitsPerMeter;
      final double colW = (_isMovingColumn && _selectedColumn != null)
          ? _selectedColumn!.width
          : _currentColumnPreset.width * _cadUnitsPerMeter;
      final double maxDimScreen = math.max(colW, colH) * cadScale;
      // Entire column (including bottom edge) is clearly above the finger touch area
      offsetAboveFinger = math.max(80.0, maxDimScreen + 36.0);
    } else if (!isMouse) {
      offsetAboveFinger = 72.0;
    } else {
      offsetAboveFinger = 0.0;
    }

    final targetPos =
        isMouse ? screenPos : (screenPos - Offset(0, offsetAboveFinger));

    final rawCad = _screenToCad(targetPos);
    DxfSnapResult? snap;
    Offset? snappedScreen;
    Offset effectiveCad = rawCad;

    if (_snapEnabled) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double toleranceCad = 24.0 / (fitScale * currentScale.clamp(0.001, 10000.0));

      if (_activeTool == StructuralDrawTool.column || _isMovingColumn) {
        // Multi-corner weighted snapping for columns:
        // Key points: all polygon vertices/corners, edge midpoints, and center
        final ColumnShape colShape = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.shape
            : _currentColumnPreset.shape;
        final double colW = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.width
            : _currentColumnPreset.width * _cadUnitsPerMeter;
        final double colH = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.height
            : _currentColumnPreset.height * _cadUnitsPerMeter;
        final double colThick = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.thickness
            : _currentColumnPreset.thickness * _cadUnitsPerMeter;
        final double rot = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.rotationRad
            : _currentColumnPreset.rotationRad;
        final bool colMirrored = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.isMirrored
            : _currentColumnPreset.isMirrored;

        final tempCol = StructuralColumn(
          id: 'temp_calc',
          center: Offset.zero,
          shape: colShape,
          width: colW,
          height: colH,
          thickness: colThick,
          rotationRad: rot,
          isMirrored: colMirrored,
        );

        final cornerOffsets = tempCol.polygonVertices;
        final midOffsets = <Offset>[];
        for (int i = 0; i < cornerOffsets.length; i++) {
          final next = cornerOffsets[(i + 1) % cornerOffsets.length];
          midOffsets.add((cornerOffsets[i] + next) / 2.0);
        }

        // 1. Gather candidate column centers:
        final candidateCenters = <Offset>{rawCad};
        for (final cornerOffset in cornerOffsets) {
          final p = rawCad + cornerOffset;
          final s = DxfSnapHelper.findSnapPoint(
            document: widget.document,
            cadPoint: p,
            toleranceCad: toleranceCad,
          ) ?? _findStructuralSnap(p, toleranceCad);
          if (s != null) {
            candidateCenters.add(s.point - cornerOffset);
          }
        }
        for (final midOffset in midOffsets) {
          final p = rawCad + midOffset;
          final s = DxfSnapHelper.findSnapPoint(
            document: widget.document,
            cadPoint: p,
            toleranceCad: toleranceCad * 0.7,
          ) ?? _findStructuralSnap(p, toleranceCad * 0.7);
          if (s != null) {
            candidateCenters.add(s.point - midOffset);
          }
        }

        // 2. Score candidate centers with weighted snap priorities:
        // Endpoints have highest weight (+120), multi-endpoint corner locks (+1000 per endpoint)
        double bestScore = -1.0;
        Offset bestCenter = rawCad;
        List<Offset> bestSnappedScreenPts = [];
        List<DxfSnapResult> bestActiveSnaps = [];

        for (final candCenter in candidateCenters) {
          double candScore = 0.0;
          int endpointMatches = 0;
          final List<Offset> candScreens = [];
          final List<DxfSnapResult> candSnaps = [];

          for (final cornerOffset in cornerOffsets) {
            final pt = candCenter + cornerOffset;
            final match = DxfSnapHelper.findSnapPoint(
              document: widget.document,
              cadPoint: pt,
              toleranceCad: toleranceCad * 0.8,
            ) ?? _findStructuralSnap(pt, toleranceCad * 0.8);

            if (match != null) {
              if (match.type == DxfSnapType.endpoint) {
                candScore += 120.0;
                endpointMatches++;
              } else {
                candScore += 40.0;
              }
              candScreens.add(_cadToScreen(match.point));
              candSnaps.add(match);
            }
          }

          // Bonus for locking into corner (multiple endpoints simultaneously):
          if (endpointMatches >= 2) {
            candScore += 1000.0 * endpointMatches;
          }

          for (final midOffset in midOffsets) {
            final pt = candCenter + midOffset;
            final match = DxfSnapHelper.findSnapPoint(
              document: widget.document,
              cadPoint: pt,
              toleranceCad: toleranceCad * 0.5,
            ) ?? _findStructuralSnap(pt, toleranceCad * 0.5);

            if (match != null) {
              candScore += 25.0;
              candScreens.add(_cadToScreen(match.point));
              candSnaps.add(match);
            }
          }

          // Distance penalty from target position:
          final dist = (candCenter - rawCad).distance;
          candScore -= (dist / toleranceCad) * 8.0;

          if (candScore > bestScore && candScore > 0.0) {
            bestScore = candScore;
            bestCenter = candCenter;
            bestSnappedScreenPts = candScreens;
            bestActiveSnaps = candSnaps;
          }
        }

        if (bestScore > 0.0) {
          snap = bestActiveSnaps.isNotEmpty ? bestActiveSnaps.first : null;
          snappedScreen = bestSnappedScreenPts.isNotEmpty ? bestSnappedScreenPts.first : null;
          _snappedScreenPositions = bestSnappedScreenPts;
          effectiveCad = Offset(bestCenter.dx - colW / 2.0, bestCenter.dy + colH / 2.0);
        } else {
          _snappedScreenPositions = [];
          effectiveCad = Offset(rawCad.dx - colW / 2.0, rawCad.dy + colH / 2.0);
        }
        _liveDimensionText = null;
      } else if (_activeTool == StructuralDrawTool.shearWall) {
        // Shear wall drawing with 10 cm snapping and live dimensioning
        if (_wallStartCad == null) {
          snap = DxfSnapHelper.findSnapPoint(
            document: widget.document,
            cadPoint: rawCad,
            toleranceCad: toleranceCad,
          ) ?? _findStructuralSnap(rawCad, toleranceCad);

          if (snap != null) {
            effectiveCad = snap.point;
            snappedScreen = _cadToScreen(snap.point);
            _snappedScreenPositions = [snappedScreen];
          } else {
            _snappedScreenPositions = [];
          }
          _liveDimensionText = null;
        } else {
          snap = DxfSnapHelper.findSnapPoint(
            document: widget.document,
            cadPoint: rawCad,
            toleranceCad: toleranceCad,
          ) ?? _findStructuralSnap(rawCad, toleranceCad);

          if (snap != null) {
            effectiveCad = snap.point;
            snappedScreen = _cadToScreen(snap.point);
            _snappedScreenPositions = [snappedScreen];
          } else {
            // Free length snapped to 10 cm increments (0.10 m)
            final v = rawCad - _wallStartCad!;
            final distCad = v.distance;
            final distM = distCad / _cadUnitsPerMeter;
            final snappedM = math.max(0.10, (distM / 0.10).round() * 0.10);
            final snappedDistCad = snappedM * _cadUnitsPerMeter;
            if (distCad > 1e-6) {
              final unitDir = v / distCad;
              effectiveCad = _wallStartCad! + unitDir * snappedDistCad;
            } else {
              effectiveCad = rawCad;
            }
            snappedScreen = _cadToScreen(effectiveCad);
            _snappedScreenPositions = [];
          }
          final wallLenM = (effectiveCad - _wallStartCad!).distance / _cadUnitsPerMeter;
          _liveDimensionText = '${wallLenM.toStringAsFixed(2)} m';
        }
      } else {
        // Single point snap for slabs
        snap = DxfSnapHelper.findSnapPoint(
          document: widget.document,
          cadPoint: rawCad,
          toleranceCad: toleranceCad,
        ) ?? _findStructuralSnap(rawCad, toleranceCad);

        if (snap != null) {
          effectiveCad = snap.point;
          snappedScreen = _cadToScreen(snap.point);
          _snappedScreenPositions = [snappedScreen];
        } else {
          _snappedScreenPositions = [];
        }
        _liveDimensionText = null;
      }

      if (snap != null) {
        if (_activeSnap == null || _activeSnap!.point != snap.point) {
          HapticFeedback.selectionClick();
        }
      }
    } else {
      _snappedScreenPositions = [];
      if (_activeTool == StructuralDrawTool.column || _isMovingColumn) {
        final double colW = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.width
            : _currentColumnPreset.width * _cadUnitsPerMeter;
        final double colH = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.height
            : _currentColumnPreset.height * _cadUnitsPerMeter;
        effectiveCad = Offset(rawCad.dx - colW / 2.0, rawCad.dy + colH / 2.0);
        _liveDimensionText = null;
      } else if (_activeTool == StructuralDrawTool.shearWall && _wallStartCad != null) {
        final v = rawCad - _wallStartCad!;
        final distCad = v.distance;
        final distM = distCad / _cadUnitsPerMeter;
        final snappedM = math.max(0.10, (distM / 0.10).round() * 0.10);
        final snappedDistCad = snappedM * _cadUnitsPerMeter;
        if (distCad > 1e-6) {
          final unitDir = v / distCad;
          effectiveCad = _wallStartCad! + unitDir * snappedDistCad;
        } else {
          effectiveCad = rawCad;
        }
        final wallLenM = (effectiveCad - _wallStartCad!).distance / _cadUnitsPerMeter;
        _liveDimensionText = '${wallLenM.toStringAsFixed(2)} m';
      } else {
        _liveDimensionText = null;
      }
    }

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
        if (_isMovingColumn && col.id == _selectedColumn?.id) continue;
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

      // Slab polygon vertices and edge midpoints
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
        for (final g in slab.edgeGrips) {
          final d = (cadPt - g.midpoint).distance;
          if (d < minDist) {
            minDist = d;
            bestSnap = DxfSnapResult(
              point: g.midpoint,
              type: DxfSnapType.midpoint,
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
    if (_activePointersCount == 0) _activePointerKind = null;
    if (_isMultiTouchGesture) {
      if (_activePointersCount == 0) _isMultiTouchGesture = false;
      return;
    }

    // 1. Slab vertex dragging commit or merge on release
    if (_draggingSlabVertexIndex != null && _editingSlab != null) {
      final idx = _draggingSlabVertexIndex!;
      final candidate = _mergeCandidateSlabVertexIndex;
      if (candidate != null && _editingSlab!.polygon.length > 3) {
        _pushSlabCorrectionUndo();
        final updated = _editingSlab!.removeVertex(idx);
        if (updated != null) {
          _editingSlab = updated;
          _updateActiveStoreySlab(updated);
          HapticFeedback.heavyImpact();
        }
      } else if (_draggingSlabVertexCad != null) {
        _pushSlabCorrectionUndo();
        final updated = _editingSlab!.moveVertex(idx, _draggingSlabVertexCad!);
        _editingSlab = updated;
        _updateActiveStoreySlab(updated);
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _draggingSlabVertexIndex = null;
        _draggingSlabVertexCad = null;
        _mergeCandidateSlabVertexIndex = null;
      });
      return;
    }

    // 2. Edge extrusion or midpoint tap on release
    if (_activeGrip != null) {
      if (_isExtrudingEdge) {
        final d = _extrusionDistanceCad;
        final scale = _cadUnitsPerMeter;
        if (d.abs() >= 0.05 * scale) {
          final active = _project.activeStorey;
          final slabIdx =
              active.slabs.indexWhere((s) => s.id == _activeExtrudingSlabId);
          if (slabIdx != -1) {
            _pushUndo();
            final updatedSlab = active.slabs[slabIdx].extrudeEdgeParallel(
              edgeIndex: _activeGrip!.edgeIndex,
              distance: d,
            );
            final updatedSlabs = List<StructuralSlab>.from(active.slabs);
            updatedSlabs[slabIdx] = updatedSlab;
            _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
            if (_isEditingSlab && _editingSlab!.id == _activeExtrudingSlabId) {
              _editingSlab = updatedSlab;
            }
            HapticFeedback.heavyImpact();
          }
        }
      } else {
        // Tapped on midpoint grip without dragging!
        if (_isEditingSlab && _activeExtrudingSlabId == _editingSlab!.id) {
          // In slab edit mode: tap on midpoint inserts a new vertex
          _pushSlabCorrectionUndo();
          final updated =
              _editingSlab!.insertMidpointVertex(_activeGrip!.edgeIndex);
          _editingSlab = updated;
          _updateActiveStoreySlab(updated);
          HapticFeedback.lightImpact();
        } else {
          // If not currently in editing mode, start editing this slab!
          final active = _project.activeStorey;
          final hit = active.slabs.firstWhere(
            (s) => s.id == _activeExtrudingSlabId,
            orElse: () => active.slabs.first,
          );
          _startSlabCorrection(hit);
        }
      }
      setState(() {
        _isExtrudingEdge = false;
        _activeGrip = null;
        _activeExtrudingSlabId = null;
        _midpointTouchDownPos = null;
        _extrusionDistanceCad = 0.0;
      });
      return;
    }

    // 3. Moving column with mouse or touch release
    if (_isMovingColumn && _selectedColumn != null) {
      if (_hasMovedSelectedColumn) {
        final newTopLeft = _currentCadCoord;
        if (newTopLeft != null) {
          _pushUndo();
          final updatedCol = StructuralColumn.fromTopLeft(
            id: _selectedColumn!.id,
            topLeft: newTopLeft,
            shape: _selectedColumn!.shape,
            width: _selectedColumn!.width,
            height: _selectedColumn!.height,
            rotationRad: _selectedColumn!.rotationRad,
            thickness: _selectedColumn!.thickness,
            isMirrored: _selectedColumn!.isMirrored,
          );
          final active = _project.activeStorey;
          final updatedCols = active.columns
              .map((c) => c.id == updatedCol.id ? updatedCol : c)
              .toList();
          _updateActiveStorey(active.copyWith(columns: updatedCols));
          _selectedColumn = updatedCol;
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _isMovingColumn = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        _liveDimensionText = null;
      });
      return;
    }

    // 4. Placing element with mouse hold release
    if (event.kind == PointerDeviceKind.mouse && _isPlacingWithHold) {
      final cadToPlace = _currentCadCoord;
      if (cadToPlace != null) {
        _commitPlacement(cadToPlace);
      }
      setState(() {
        _isPlacingWithHold = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        _liveDimensionText = null;
      });
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointersCount = 0;
    _activePointerKind = null;
    _isMultiTouchGesture = false;
    setState(() {
      _isPlacingWithHold = false;
      _isMovingColumn = false;
      _isExtrudingEdge = false;
      _activeGrip = null;
      _activeExtrudingSlabId = null;
      _midpointTouchDownPos = null;
      _extrusionDistanceCad = 0.0;
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _snappedScreenPositions = [];
      _activeSnap = null;
      _liveDimensionText = null;
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isExtrudingEdge || _activeGrip != null) return;
    if (_isMultiTouchGesture || _activePointersCount > 1) return;

    // 0. If in slab correction mode: long press on vertex deletes it!
    if (_isEditingSlab) {
      final hitVIdx = _hitTestSlabVertex(details.localPosition, _editingSlab!);
      if (hitVIdx != null) {
        if (_editingSlab!.polygon.length <= 3) {
          HapticFeedback.vibrate();
        } else {
          _pushSlabCorrectionUndo();
          final updated = _editingSlab!.removeVertex(hitVIdx);
          if (updated != null) {
            _editingSlab = updated;
            _updateActiveStoreySlab(updated);
            HapticFeedback.heavyImpact();
          }
        }
        return;
      }
    }

    // 1. Check if holding on an existing placed column
    final hitCol = _hitTestColumn(details.localPosition);
    if (hitCol != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _selectedColumn = hitCol;
        _isMovingColumn = true;
        _hasMovedSelectedColumn = false;
        _isPlacingWithHold = false;
      });
      _updatePointer(details.localPosition, isMouse: false);
      return;
    }

    // 1b. Check if holding on an existing slab -> start slab correction!
    final hitSlab = _hitTestSlab(details.localPosition);
    if (hitSlab != null) {
      _startSlabCorrection(hitSlab);
      return;
    }

    // 2. Otherwise deselect previous selection
    if (_activeTool == StructuralDrawTool.select) {
      if (_selectedColumn != null) {
        setState(() => _selectedColumn = null);
      }
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedColumn = null;
      _isMovingColumn = false;
      _isPlacingWithHold = true;
    });
    _updatePointer(details.localPosition, isMouse: false);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isMovingColumn && _selectedColumn != null) {
      _updatePointer(details.localPosition, isMouse: false);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedColumn!.topLeft).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedColumn = true;
        }
      }
      return;
    }
    if (_isPlacingWithHold) {
      _updatePointer(details.localPosition, isMouse: false);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isMovingColumn && _selectedColumn != null) {
      if (_hasMovedSelectedColumn) {
        final newTopLeft = _currentCadCoord;
        if (newTopLeft != null) {
          _pushUndo();
          final updatedCol = StructuralColumn.fromTopLeft(
            id: _selectedColumn!.id,
            topLeft: newTopLeft,
            shape: _selectedColumn!.shape,
            width: _selectedColumn!.width,
            height: _selectedColumn!.height,
            rotationRad: _selectedColumn!.rotationRad,
          );
          final active = _project.activeStorey;
          final updatedCols = active.columns
              .map((c) => c.id == updatedCol.id ? updatedCol : c)
              .toList();
          _updateActiveStorey(active.copyWith(columns: updatedCols));
          _selectedColumn = updatedCol;
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _isMovingColumn = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
      });
      return;
    }

    if (_isPlacingWithHold) {
      final cadToPlace = _currentCadCoord;
      if (cadToPlace != null) {
        _commitPlacement(cadToPlace);
      }
      setState(() {
        _isPlacingWithHold = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
      });
    }
  }

  void _handleLongPressCancel() {
    if (_isMovingColumn) {
      setState(() {
        _isMovingColumn = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
      });
    }
    if (_isPlacingWithHold && _activePointersCount <= 1) {
      setState(() {
        _isPlacingWithHold = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
      });
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isEditingSlab) return;

    final hitCol = _hitTestColumn(details.localPosition);
    if (hitCol != null) {
      setState(() {
        _selectedColumn = hitCol;
        _selectedShearWall = null;
        _isMovingColumn = false;
      });
      HapticFeedback.selectionClick();
      return;
    }

    final hitWall = _hitTestShearWall(details.localPosition);
    if (hitWall != null) {
      setState(() {
        _selectedShearWall = hitWall;
        _selectedColumn = null;
        _isMovingColumn = false;
      });
      HapticFeedback.selectionClick();
      return;
    }

    final hitSlab = _hitTestSlab(details.localPosition);
    if (hitSlab != null) {
      _startSlabCorrection(hitSlab);
      return;
    }

    if (_selectedColumn != null || _selectedShearWall != null) {
      setState(() {
        _selectedColumn = null;
        _selectedShearWall = null;
      });
    }
  }

  // --- Element Placement Logic ---

  void _commitPlacement(Offset cadCoord) {
    final active = _project.activeStorey;
    final scale = _cadUnitsPerMeter;

    if (_activeTool == StructuralDrawTool.column) {
      _pushUndo();
      // Anchor column at Top-Left corner in CAD coordinates
      final newCol = StructuralColumn.fromTopLeft(
        id: 'col_${DateTime.now().millisecondsSinceEpoch}',
        topLeft: cadCoord,
        shape: _currentColumnPreset.shape,
        width: _currentColumnPreset.width * scale,
        height: _currentColumnPreset.height * scale,
        rotationRad: _currentColumnPreset.rotationRad,
        thickness: _currentColumnPreset.thickness * scale,
        isMirrored: _currentColumnPreset.isMirrored,
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
        if ((cadCoord - _wallStartCad!).distance >= 0.3 * scale) {
          _pushUndo();
          final newWall = StructuralShearWall(
            id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
            start: _wallStartCad!,
            end: cadCoord,
            thickness: _currentWallThickness * scale,
            isFlipped: false,
          );
          final updatedWalls = List<StructuralShearWall>.from(active.shearWalls)
            ..add(newWall);
          final updatedStorey = active.copyWith(shearWalls: updatedWalls);
          _updateActiveStorey(updatedStorey);
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _wallStartCad = null;
          _liveDimensionText = null;
        });
      }
    } else if (_activeTool == StructuralDrawTool.slab) {
      if (_slabStartCornerCad == null) {
        // Step 1: Set 1st corner of rectangular slab
        setState(() => _slabStartCornerCad = cadCoord);
        HapticFeedback.lightImpact();
      } else {
        // Step 2: Set opposite corner and commit closed rectangular slab
        final c1 = _slabStartCornerCad!;
        final c2 = cadCoord;
        final minX = math.min(c1.dx, c2.dx);
        final maxX = math.max(c1.dx, c2.dx);
        final minY = math.min(c1.dy, c2.dy);
        final maxY = math.max(c1.dy, c2.dy);

        final w = maxX - minX;
        final h = maxY - minY;

        if (w >= 0.3 * scale && h >= 0.3 * scale) {
          _pushUndo();
          // Closed counter-clockwise rectangle in CAD coordinates (Y up)
          final rectPolygon = [
            Offset(minX, minY),
            Offset(maxX, minY),
            Offset(maxX, maxY),
            Offset(minX, maxY),
          ];
          final newSlab = StructuralSlab(
            id: 'slab_${DateTime.now().millisecondsSinceEpoch}',
            polygon: rectPolygon,
            thickness: _currentSlabThickness,
          );
          final updatedSlabs = List<StructuralSlab>.from(active.slabs)..add(newSlab);
          final updatedStorey = active.copyWith(slabs: updatedSlabs);
          _updateActiveStorey(updatedStorey);
          HapticFeedback.heavyImpact();
        }
        setState(() {
          _slabStartCornerCad = null;
          _slabPointsCad.clear();
        });
      }
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

  // --- Structural Underlay Layer Filtering (White Thick Walls & Slabs focus) ---

  void _applyUnderlayFilter(bool activate) {
    _underlayFilterActive = activate;
    if (activate) {
      final visibleLayerNames = StructuralUnderlayFilter.filterLayers(
        layers: widget.document.layers.values,
        entities: widget.document.entities,
        blocks: widget.document.blocks,
      );

      // Verify how many entities in Model space will actually be visible
      final modelEntities = widget.document.layoutEntities['Model'] ?? widget.document.entities;
      int visibleCount = 0;
      for (final e in modelEntities) {
        if (e is DxfInsert) {
          final block = widget.document.blocks[e.blockName];
          if (block != null) {
            final hasChild = block.entities.any((child) => visibleLayerNames.contains(child.layer));
            if (hasChild || visibleLayerNames.contains(e.layer)) visibleCount++;
          } else if (visibleLayerNames.contains(e.layer)) {
            visibleCount++;
          }
        } else if (visibleLayerNames.contains(e.layer)) {
          visibleCount++;
        }
      }

      // If the filter resulted in ZERO visible entities, abort filter so screen is NEVER blank!
      if (visibleLayerNames.isEmpty || visibleCount == 0) {
        _underlayFilterActive = false;
        for (final entry in _originalLayerVisibility.entries) {
          widget.document.layers[entry.key]?.isVisible = entry.value;
        }
        return;
      }

      for (final layer in widget.document.layers.values) {
        layer.isVisible = visibleLayerNames.contains(layer.name);
      }
    } else {
      for (final entry in _originalLayerVisibility.entries) {
        widget.document.layers[entry.key]?.isVisible = entry.value;
      }
    }
  }

  void _toggleUnderlayFilter() {
    setState(() {
      _applyUnderlayFilter(!_underlayFilterActive);
    });
    HapticFeedback.selectionClick();
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
            name: context.l10n.storeyLevelName(nextIdx, newElev.toStringAsFixed(2)),
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
            newName: context.l10n.storeyTypicalName(nextIdx, active.name),
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
          cadUnitsPerMeter: _cadUnitsPerMeter,
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
          // Underlay Filter Toggle (Walls & Axes focus)
          IconButton(
            icon: Icon(
              _underlayFilterActive
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: _underlayFilterActive
                  ? const Color(0xFF00E5FF)
                  : Colors.white70,
            ),
            tooltip: _underlayFilterActive
                ? context.l10n.structuralFilterActive
                : context.l10n.structuralFilterInactive,
            onPressed: _toggleUnderlayFilter,
          ),
          // Snap Toggle
          IconButton(
            icon: Icon(
              _snapEnabled ? Icons.grain_rounded : Icons.lens_blur_rounded,
              color: _snapEnabled ? const Color(0xFF00E5FF) : Colors.white38,
            ),
            tooltip: _snapEnabled
                ? context.l10n.snapEnabledTooltip
                : context.l10n.snapDisabledTooltip,
            onPressed: () {
              setState(() => _snapEnabled = !_snapEnabled);
              HapticFeedback.selectionClick();
            },
          ),
          // Undo Button
          IconButton(
            icon: Icon(Icons.undo_rounded,
                color: _undoStack.isNotEmpty ? Colors.white : Colors.white24),
            tooltip: context.l10n.undoAction,
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          // 3D Viewport Launcher
          IconButton(
            icon: const Icon(Icons.view_in_ar_rounded, color: Color(0xFFFFB300)),
            tooltip: context.l10n.structural3dView,
            onPressed: _open3dViewport,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Gesture Recognizer wrapping InteractiveViewer:
              // Allows free 1-finger pan and 2-finger zoom to navigate freely,
              // and 280ms press-and-hold to activate element placement with 56px stem ruler!
              Positioned.fill(
                child: RawGestureDetector(
                  gestures: <Type, GestureRecognizerFactory>{
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                        duration: const Duration(milliseconds: 280),
                        debugOwner: this,
                      ),
                      (LongPressGestureRecognizer instance) {
                        instance
                          ..onLongPressStart = _handleLongPressStart
                          ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
                          ..onLongPressEnd = _handleLongPressEnd
                          ..onLongPressCancel = _handleLongPressCancel;
                      },
                    ),
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(debugOwner: this),
                      (TapGestureRecognizer instance) {
                        instance.onTapUp = _handleTapUp;
                      },
                    ),
                  },
                  child: Listener(
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      panEnabled: !_isPlacingWithHold &&
                          !_isExtrudingEdge &&
                          !_isMovingColumn &&
                          _draggingSlabVertexIndex == null,
                      scaleEnabled: !_isPlacingWithHold &&
                          !_isExtrudingEdge &&
                          !_isMovingColumn &&
                          _draggingSlabVertexIndex == null,
                      scaleFactor: 350.0,
                      trackpadScrollCausesScale: true,
                      minScale: 0.001,
                      maxScale: 1000.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      onInteractionStart: (details) {
                        if (details.pointerCount > 1) {
                          setState(() {
                            _isMultiTouchGesture = true;
                            _isPlacingWithHold = false;
                            _isMovingColumn = false;
                            _isExtrudingEdge = false;
                            _activeGrip = null;
                            _activeExtrudingSlabId = null;
                            _midpointTouchDownPos = null;
                            _extrusionDistanceCad = 0.0;
                            _draggingSlabVertexIndex = null;
                            _draggingSlabVertexCad = null;
                            _mergeCandidateSlabVertexIndex = null;
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
                                    currentScale: _renderScale,
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
                                  previewColumn: _currentColumnPreset.copyWith(
                                    width: _currentColumnPreset.width * _cadUnitsPerMeter,
                                    height: _currentColumnPreset.height * _cadUnitsPerMeter,
                                  ),
                                  previewColumnPos: _isPlacingWithHold ? _currentCadCoord : null,
                                  wallStartPos: _wallStartCad,
                                  currentCursorCad: _currentCadCoord,
                                  slabStartCornerCad: _slabStartCornerCad,
                                  slabPointsInProgress: _slabPointsCad,
                                  extrudingGrip: _activeGrip,
                                  extrusionDistance: _isExtrudingEdge ? _extrusionDistanceCad : null,
                                  selectedColumnId: _selectedColumn?.id,
                                  selectedShearWallId: _selectedShearWall?.id,
                                  movingColumn: _isMovingColumn ? _selectedColumn : null,
                                  movingColumnPos: _isMovingColumn ? (_activeSnap?.point ?? _currentCadCoord) : null,
                                  selectedSlabId: _editingSlab?.id,
                                  draggingSlabVertexIndex: _draggingSlabVertexIndex,
                                  draggingSlabVertexPos: _draggingSlabVertexCad,
                                  mergeCandidateVertexIndex: _mergeCandidateSlabVertexIndex,
                                  cadUnitsPerMeter: _cadUnitsPerMeter,
                                  zoomScale: _transformController.value.getMaxScaleOnAxis(),
                                  cadToScene: _cadToScene,
                                  cadScale: _getCadFitScale(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Screen-Space Offset Target Pointer with Stem Guideline & Live Dimensioning
              if ((_isPlacingWithHold || _isMovingColumn) &&
                  _touchScreenPos != null &&
                  _targetScreenPos != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: StructuralPointerPainter(
                        touchPos: _touchScreenPos!,
                        targetPos: _targetScreenPos!,
                        snappedPos: _snappedScreenPos,
                        snappedPositions: _snappedScreenPositions,
                        snapType: _activeSnap?.type,
                        activeTool: _isMovingColumn
                            ? StructuralDrawTool.column
                            : _activeTool,
                        previewColumn: _isMovingColumn
                            ? _selectedColumn!.copyWith(
                                width: _selectedColumn!.width / _cadUnitsPerMeter,
                                height: _selectedColumn!.height / _cadUnitsPerMeter,
                              )
                            : _currentColumnPreset,
                        wallStartPos: _wallStartCad != null ? _cadToScreen(_wallStartCad!) : null,
                        slabStartCornerPos: _slabStartCornerCad != null ? _cadToScreen(_slabStartCornerCad!) : null,
                        slabPoints: _slabPointsCad.map(_cadToScreen).toList(),
                        liveDimensionText: _liveDimensionText,
                        l10n: context.l10n,
                      ),
                    ),
                  ),
                ),

              // 3. Trace Reference Status Pill (Top Center)
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
                            context.l10n.traceReferenceLayer(_project.ghostStorey!.name),
                            style: const TextStyle(
                                color: Color(0xFF00E5FF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Floating Contextual Action Card for Selected Column or Shear Wall
              if (_selectedColumn != null && !_isMovingColumn && !_isPlacingWithHold && !_isEditingSlab)
                _buildSelectedColumnActionCard(context),
              if (_selectedShearWall != null && !_isMovingColumn && !_isPlacingWithHold && !_isEditingSlab)
                _buildSelectedWallActionCard(context),

              // 5. Bottom Dock Bar (Switches to Slab Correction Bar when editing slab)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _isEditingSlab
                    ? _buildSlabCorrectionBottomBar(context)
                    : ElementPaletteBar(
                        activeTool: _activeTool,
                        onSelectTool: (tool) {
                          setState(() {
                            _activeTool = tool;
                            _wallStartCad = null;
                            _slabStartCornerCad = null;
                            _slabPointsCad.clear();
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
                        hasSlabStartCorner: _slabStartCornerCad != null,
                        slabPointCount: _slabStartCornerCad != null ? 1 : _slabPointsCad.length,
                        onCloseSlab: _closeSlabPolygon,
                        onUndoPoint: () {
                          setState(() {
                            _slabStartCornerCad = null;
                            if (_slabPointsCad.isNotEmpty) _slabPointsCad.removeLast();
                          });
                        },
                        onClearSlab: () {
                          setState(() {
                            _slabStartCornerCad = null;
                            _slabPointsCad.clear();
                          });
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

  Widget _buildSelectedColumnActionCard(BuildContext context) {
    if (_selectedColumn == null || _isMovingColumn || _isPlacingWithHold || _isEditingSlab) {
      return const SizedBox.shrink();
    }

    final colScreen = _cadToScreen(_selectedColumn!.center);
    const double cardWidth = 350.0;
    const double cardHeight = 88.0;

    // Horizontal centering over column, clamped to viewport margins
    final double left = (colScreen.dx - cardWidth / 2.0).clamp(
      16.0,
      math.max(16.0, _viewportSize.width - cardWidth - 16.0),
    );

    // Prefer positioning 30px above column top, or below if near top edge
    double top = colScreen.dy - cardHeight - 28.0;
    if (top < 12.0) {
      top = colScreen.dy + 32.0;
    }
    // Prevent overlapping bottom dock bar
    top = top.clamp(
        12.0, math.max(12.0, _viewportSize.height - cardHeight - 160.0));

    final int wCm =
        (_selectedColumn!.width / _cadUnitsPerMeter * 100).round();
    final int hCm =
        (_selectedColumn!.height / _cadUnitsPerMeter * 100).round();
    final String dimStr = _selectedColumn!.shape == ColumnShape.lShape
        ? 'Г $wCm x $hCm / 25 cm'
        : _selectedColumn!.shape == ColumnShape.circular
            ? 'Ø$wCm cm'
            : '$wCm x $hCm cm';

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xF01E1E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Type & Dimensions badge + Modeling +/- 5cm buttons + Close
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB300),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.selectedColumnTitle(dimStr),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // In-place modeling 5 cm buttons
                  InkWell(
                    onTap: () => _updateSelectedColumnDimensions(-0.05, -0.05),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '-5 cm',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _updateSelectedColumnDimensions(0.05, 0.05),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '+5 cm',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _selectedColumn = null),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Action Buttons Row: Delete, Rotate 90°, Mirror, Duplicate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Delete Button (Red)
                  InkWell(
                    onTap: _deleteSelectedColumn,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x29FF5252),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFF5252), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xFFFF5252)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.delete,
                            style: const TextStyle(
                              color: Color(0xFFFF5252),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 2. Rotate 90° Button (Amber)
                  InkWell(
                    onTap: _rotateSelectedColumn,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x29FFB300),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFFB300), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.rotate_right_rounded,
                              size: 15, color: Color(0xFFFFB300)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.rotateElement,
                            style: const TextStyle(
                              color: Color(0xFFFFB300),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3. Mirror Button (Purple)
                  InkWell(
                    onTap: _mirrorSelectedColumn,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x29B388FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFB388FF), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flip_rounded,
                              size: 15, color: Color(0xFFB388FF)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.mirrorElement,
                            style: const TextStyle(
                              color: Color(0xFFB388FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 4. Duplicate Button (Teal / Cyan)
                  InkWell(
                    onTap: _duplicateSelectedColumn,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x2900E5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF00E5FF), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded,
                              size: 14, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.duplicateElement,
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedWallActionCard(BuildContext context) {
    if (_selectedShearWall == null || _isMovingColumn || _isPlacingWithHold || _isEditingSlab) {
      return const SizedBox.shrink();
    }

    final wall = _selectedShearWall!;
    final wallMidCad = (wall.start + wall.end) / 2.0;
    final wallScreen = _cadToScreen(wallMidCad);
    const double cardWidth = 350.0;
    const double cardHeight = 88.0;

    final double left = (wallScreen.dx - cardWidth / 2.0).clamp(
      16.0,
      math.max(16.0, _viewportSize.width - cardWidth - 16.0),
    );

    double top = wallScreen.dy - cardHeight - 28.0;
    if (top < 12.0) {
      top = wallScreen.dy + 32.0;
    }
    top = top.clamp(
        12.0, math.max(12.0, _viewportSize.height - cardHeight - 160.0));

    final double lengthM = wall.length / _cadUnitsPerMeter;
    final int thickCm = (wall.thickness / _cadUnitsPerMeter * 100).round();
    final String dimStr = '${lengthM.toStringAsFixed(2)} m (d=$thickCm cm)';

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xF01E1E24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Title & Close + [-10 cm] [+10 cm]
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.selectedWallTitle(dimStr),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Length step buttons [-10 cm] [+10 cm]
                  InkWell(
                    onTap: () => _updateSelectedWallLength(-0.10),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '-10 cm',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _updateSelectedWallLength(0.10),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '+10 cm',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _selectedShearWall = null),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Action Buttons Row: Delete, Flip Side, Duplicate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Delete Button (Red)
                  InkWell(
                    onTap: _deleteSelectedWall,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x29FF5252),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF5252), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFFF5252)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.delete,
                            style: const TextStyle(
                              color: Color(0xFFFF5252),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 2. Flip Side Button (Teal / Cyan)
                  InkWell(
                    onTap: _flipSelectedWall,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x2900E5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.flipSide,
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3. Duplicate Button (Purple)
                  InkWell(
                    onTap: _duplicateSelectedWall,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x29B388FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB388FF), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 14, color: Color(0xFFB388FF)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.duplicateElement,
                            style: const TextStyle(
                              color: Color(0xFFB388FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlabCorrectionBottomBar(BuildContext context) {
    if (_editingSlab == null) return const SizedBox.shrink();
    final areaM2 =
        _editingSlab!.netArea / (_cadUnitsPerMeter * _cadUnitsPerMeter);
    final perimM = _editingSlab!.perimeter / _cadUnitsPerMeter;
    final numPts = _editingSlab!.polygon.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFA1A1C23),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel Button (Red outline)
            OutlinedButton.icon(
              onPressed: _cancelSlabCorrection,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5252),
                side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(
                context.l10n.cancel,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),

            // Center Stats Pill
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x337C4DFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x667C4DFF)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB388FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.slabCorrectionTitle,
                          style: const TextStyle(
                            color: Color(0xFFB388FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S: ${areaM2.toStringAsFixed(1)} m²  P: ${perimM.toStringAsFixed(1)} m  ($numPts т.)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Undo Button
            IconButton(
              onPressed: _slabCorrectionUndoStack.isNotEmpty
                  ? _undoSlabCorrection
                  : null,
              icon: const Icon(Icons.undo_rounded),
              iconSize: 20,
              color: const Color(0xFF00E5FF),
              disabledColor: Colors.white24,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: context.l10n.undoAction,
            ),
            const SizedBox(width: 4),

            // Mirror Slab Button
            IconButton(
              onPressed: _mirrorEditingSlab,
              icon: const Icon(Icons.flip_rounded),
              iconSize: 20,
              color: const Color(0xFFB388FF),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: context.l10n.mirrorElement,
            ),
            const SizedBox(width: 4),

            // Delete Slab Button
            IconButton(
              onPressed: _deleteEditingSlab,
              icon: const Icon(Icons.delete_outline_rounded),
              iconSize: 20,
              color: const Color(0xFFFF5252),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              tooltip: context.l10n.deleteSlab,
            ),
            const SizedBox(width: 6),

            // Save Button (Green elevated)
            ElevatedButton.icon(
              onPressed: _saveSlabCorrection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(
                context.l10n.save,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
