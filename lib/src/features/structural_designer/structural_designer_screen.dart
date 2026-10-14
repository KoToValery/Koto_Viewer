import '../bim_editing/widgets/bim_edit_actions.dart';
import '../bim_editing/geometry/bim_line_geometry.dart';
import 'analysis/slab_zone_grouping.dart';
import 'rendering/slab_colors.dart';
import 'rendering/grid_axis_bubble_layout.dart';
import 'analysis/staircase_automatic_openings.dart';
import 'rendering/slab_plan_labels.dart';
import 'dart:async';
import 'adapters/structural_element_adapters.dart';
import 'adapters/structural_snap_scene.dart';
import '../bim_editing/snapping/bim_snap_resolver.dart';
import '../bim_editing/operations/bim_axis_operations.dart';
import '../bim_editing/operations/bim_axis_naming.dart';
import '../bim_editing/geometry/bim_coordinate_frame.dart';
import '../bim_editing/commands/bim_edit_history.dart';
import '../bim_editing/interaction/bim_edit_session.dart';
import '../bim_editing/interaction/bim_drag_session.dart';
import '../bim_editing/interaction/bim_polygon_editor.dart';
import '../bim_editing/interaction/bim_transform_navigation.dart';
import '../bim_editing/widgets/bim_editing_viewport.dart';
import 'dart:math' as math;
import '../bim_projects/services/bim_underlay_conversion_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../dxf_viewer/models/dxf_display_settings.dart';
import '../dxf_viewer/models/dxf_models.dart';
import '../dxf_viewer/rendering/dxf_painter.dart';
import '../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../dxf_viewer/widgets/dxf_display_settings_sheet.dart';
import 'analysis/cantilever_detector.dart';
import 'analysis/seismic_analysis_calculator.dart';
import 'analysis/structural_underlay_filter.dart';
import 'analysis/vertical_capacity_calculator.dart';
import 'analysis/support_layout_evaluator.dart';
import 'analysis/support_span_feedback_cache.dart';
import 'analysis/slab_parallel_alignment_helper.dart';
import 'analysis/slab_seed_generator.dart';
import 'analysis/slab_vertex_snap.dart';
import 'analysis/slab_envelope_detector.dart';
import 'analysis/slab_projection_detector.dart';
import 'analysis/structural_magnetic_alignment_helper.dart';
import 'analysis/structural_pointer_interaction.dart';
import 'analysis/structural_measurement_snap.dart';
import 'analysis/wall_axis_detector.dart';
import 'analysis/project_grid_axes.dart';
import 'rendering/grid_axis_presentation.dart';
import 'models/cantilever_analysis_models.dart';
import 'models/seismic_analysis_models.dart';
import 'models/structural_element.dart';
import 'models/vertical_capacity_models.dart';
import 'models/wall_axis_models.dart';
import 'rendering/structural_2d_painter.dart';
import 'rendering/structural_pointer_painter.dart';
import 'services/structural_persistence_service.dart';
import 'widgets/cantilever_analysis_sheet.dart';
import 'widgets/element_palette_bar.dart';
import 'widgets/seismic_analysis_sheet.dart';
import 'widgets/seismic_load_dialog.dart';
import 'widgets/slab_level_dialog.dart';
import 'services/slab_opening_placement.dart';
import 'services/slab_edit_validation.dart';
import 'widgets/slab_edge_offset_dialog.dart';
import 'widgets/structural_offset_dialog.dart';
import 'widgets/storey_manager_sheet.dart';
import '../dxf_viewer/widgets/dxf_layer_sheet.dart';
import '../dxf_viewer/widgets/dxf_entity_context_sheet.dart';
import 'analysis/structural_column_synchronizer.dart';
import 'widgets/underlay_filter_config_sheet.dart';
import 'models/structural_bim_context.dart';
import 'widgets/structural_3d_viewport.dart';
import 'widgets/vertical_capacity_sheet.dart';

/// Main CAD/BIM Structural Designer workspace screen.
/// Enables placing columns, shear walls, and slabs over DWG/DXF underlay,
/// managing multi-storey buildings with ArchiCAD-like Trace Reference,
/// and automated real-time cantilever and deflection checks.
class StructuralDesignerScreen extends StatefulWidget {
  final DxfDocument document;
  final StructuralProject? initialProject;
  final Rect? initialCadBounds;
  final Matrix4? initialTransform;
  final String? title;
  final WallAxisDetectionResult? initialDetectionResult;
  final StructuralBimContext? bimContext;

  const StructuralDesignerScreen({
    super.key,
    required this.document,
    this.initialProject,
    this.initialCadBounds,
    this.initialTransform,
    this.title,
    this.initialDetectionResult,
    this.bimContext,
  });

  @override
  State<StructuralDesignerScreen> createState() =>
      _StructuralDesignerScreenState();
}

class _StructuralDesignerScreenState extends State<StructuralDesignerScreen> {
  late final TransformationController _transformController;
  late final _viewportNavigation = BimTransformNavigation(
    controller: _transformController,
    readSize: () => _viewportSize,
    onResize: (size) => _viewportSize = size,
  );
  bool _viewportHeld = false;
  bool get _viewportDragging => _beamMove != null || _duplicateDraft != null || _placementPointerHandled ||
      _isPlacingWithHold || _isOffsettingAxisWithDrag || _isOffsettingColumnWithDrag ||
      _isExtrudingEdge || _isMovingColumn || _isMovingShearWall || _isMovingOpening ||
      _isDraggingAxisHandle || _activeGrip != null || _activeOpeningGrip != null ||
      _draggingSlabVertexIndex != null || _draggingOpeningVertexIndex != null;

  void _beginViewportHold(Offset position) {
    _viewportHeld = true;
    if (_activeTool == StructuralDrawTool.measure) {
      _measurementHeldGesture = true;
      setState(() => _isPlacingWithHold = true);
      _updateMeasurementPointer(position, isMouse: false);
      HapticFeedback.selectionClick();
    } else {
      _handleLongPressStart(LongPressStartDetails(localPosition: position));
    }
  }

  void _moveViewportTool(PointerMoveEvent event) {
    _handlePointerMove(event);
    if (_viewportHeld) {
      _handleLongPressMoveUpdate(LongPressMoveUpdateDetails(localPosition: event.localPosition));
    }
  }

  void _releaseViewportTool(PointerUpEvent event) {
    final held = _viewportHeld;
    _viewportHeld = false;
    _handlePointerUp(event);
    if (held) {
      _handleLongPressEnd(LongPressEndDetails(localPosition: event.localPosition));
    } else {
      _handleTapUp(TapUpDetails(localPosition: event.localPosition, kind: event.kind));
    }
    _cancelContourEditors();
  }

  void _cancelViewportTool() {
    _viewportHeld = false;
    _handleLongPressCancel();
    _handlePointerCancel(const PointerCancelEvent());
  }

  DxfDocument get _document {
    if (widget.bimContext != null) {
      try {
        final activeId = _project.activeStorey.id;
        final underlay = widget.bimContext!.underlaysByStorey[activeId];
        if (underlay != null) return underlay;
      } catch (_) {}
    }
    return widget.document;
  }

  late StructuralProject _project;
  StructuralDrawTool _activeTool = StructuralDrawTool.column;

  // Preset parameters for drawing
  StructuralColumn _currentColumnPreset = const StructuralColumn(
    id: 'preset_col',
    center: Offset.zero,
    shape: ColumnShape.rectangular,
    width: 0.25,
    height: 0.30,
    thickness: 0.25,
  );
  double _currentWallThickness = 0.25;
  double _currentWallLength = 1.50;
  double _currentWallRotationRad = 0.0;
  double _currentSlabThickness = 0.20;
  bool _snapEnabled = true;
  bool _showGroundFoundations = false;

  // In-progress drawing & measuring states
  Offset? _measurementStartCad;
  bool _measurementHeldGesture = false;
  (Offset, Offset, String)? _activeMeasurement;
  Offset? _wallStartCad;
  Offset? _beamStartCad;
  double _currentBeamWidth = 0.25;
  double _currentBeamDepth = 0.50;
  Offset? _slabStartCornerCad;
  Offset? _openingStartCad;
  String _selectedOpeningPreset = 'shaft';
  final List<Offset> _slabPointsCad = [];
  final List<Offset> _openingPointsCad = [];

  SlabOpeningType get _currentOpeningType {
    switch (_selectedOpeningPreset) {
      case 'staircase':
        return SlabOpeningType.staircase;
      case 'elevator':
        return SlabOpeningType.elevator;
      case 'shaft':
      default:
        return SlabOpeningType.shaft;
    }
  }

  // Midpoint edge extrusion states (Cantilever / еркер drag)
  SlabEdgeGripInfo? _activeGrip;
  String? _activeExtrudingSlabId;
  bool _isExtrudingEdge = false;
  double _extrusionDistanceCad = 0.0;
  SlabParallelAlignmentResult? _activeParallelSnap;
  List<Offset>? _previewSlabOffsetPolygon;

  // Pointer & Touch states (Offset pointer: dynamic height above finger)
  Offset? _touchScreenPos;
  Offset? _targetScreenPos;
  Offset? _snappedScreenPos;
  List<Offset> _snappedScreenPositions = [];
  DxfSnapResult? _activeSnap;
  String? _liveDimensionText;
  (Offset, Offset)? _activeDynamicDimensionLine;
  Offset? _currentCadCoord;
  bool _isPlacingWithHold = false;
  bool _initializedStoreyName = false;

  // Selection and move states (Column, Shear Wall, Beam, Opening)
  StructuralColumn? _selectedColumn;
  StructuralShearWall? _selectedShearWall;
  StructuralBeam? _selectedBeam;
  final _slabVertexEditor = BimPolygonEditor<DxfSnapResult>(pointOf: (snap) => snap.point, isSnapped: (snap) => snap.distance.isFinite);
  final _openingVertexEditor = BimPolygonEditor<DxfSnapResult>(pointOf: (snap) => snap.point, isSnapped: (snap) => snap.distance.isFinite);
  Object? _contourRevision;
  void _previewContourVertex(BimPolygonEditor<DxfSnapResult> editor, String partId,
      List<Offset> nativePoints, int vertex, Offset raw, Offset target, DxfSnapResult? snap) {
    if (!identical(_contourRevision, _project)) {
      _slabVertexEditor.cancel(); _openingVertexEditor.cancel(); _contourRevision = _project;
    }
    if (!editor.active || editor.elementId != partId || editor.index != vertex) {
      editor.startVertex(partId, nativePoints.map((p) => p / _cadUnitsPerMeter).toList(), vertex);
    }
    editor.update(raw / _cadUnitsPerMeter, (_) => DxfSnapResult(
      point: target / _cadUnitsPerMeter, type: snap?.type ?? DxfSnapType.nearest,
      distance: snap == null ? double.infinity : snap.distance / _cadUnitsPerMeter),
      _slabSnapTolerance(merge: true) / _cadUnitsPerMeter);
  }
  void _cancelContourEditors() { _slabVertexEditor.cancel(); _openingVertexEditor.cancel(); _contourRevision = null; }
  BimDragSession<StructuralBeam>? _beamMove;
  void _beginBeamMove(StructuralBeam beam, Offset screen) {
    _beamMove = BimDragSession(context: _duplicateContext, original: beam,
      anchor: (beam.start + beam.end) / (2 * _cadUnitsPerMeter),
      translate: StructuralBeamEditingAdapter(frame: BimCoordinateFrame(unitsPerMeter: _cadUnitsPerMeter)).translate);
    _beamMove!.grabAt(_screenToCad(screen) / _cadUnitsPerMeter);
    _selectedBeam = beam;
    _selectedColumn = null;
    _selectedShearWall = null;
    _selectedGridAxis = null;
  }
  void _previewBeamMove(Offset screen, {required bool isMouse}) {
    final session = _beamMove;
    if (session == null) return;
    var target = session.targetForPointer(_screenToCad(screen) / _cadUnitsPerMeter);
    if (_snapEnabled) {
      final radius = StructuralPointerInteraction.snapToleranceCad(isMouse: isMouse,
        pixelsPerCadUnit: _getCadFitScale() * _transformController.value.getMaxScaleOnAxis(),
        cadUnitsPerMeter: _cadUnitsPerMeter);
      final snap = _findStructuralSnap(target * _cadUnitsPerMeter, radius,
        excludedElementIds: {session.original.id});
      if (snap != null) target = snap.point / _cadUnitsPerMeter;
    }
    setState(() => session.updateTarget(_duplicateContext, target));
  }
  StoreyLevel _withBeamMove(StoreyLevel floor) {
    final preview = _beamMove?.preview;
    if (preview == null) return floor;
    return floor.copyWith(beams: [for (final beam in floor.beams) beam.id == preview.id ? preview : beam]);
  }
  void _finishBeamMove(Offset screen, {required bool isMouse}) {
    _previewBeamMove(screen, isMouse: isMouse);
    final preview = _beamMove?.finish(_duplicateContext);
    _beamMove = null;
    if (preview == null) return;
    _pushUndo();
    _updateActiveStorey(_project.activeStorey.copyWith(beams: [
      for (final beam in _project.activeStorey.beams) beam.id == preview.id ? preview : beam]));
    setState(() => _selectedBeam = preview);
  }
  BimDragSession<Object>? _duplicateSession;
  Object? get _duplicateDraft => _duplicateSession?.original;
  Object get _duplicateContext => (_project, _project.activeStorey.id, _activeTool);
  String? _duplicateStoreyId;
  bool _placementPointerHandled = false;

  (String, int)? _selectedOpening;
  StructuralGridAxis? _selectedGridAxis;
  String _currentAxisName = '1';
  Offset? _firstWallEdgeStartCad;
  Offset? _firstWallEdgeEndCad;
  bool _isDraggingAxisHandle = false;
  bool _draggingAxisStart = false;
  BimEditSession<List<StructuralGridAxis>>? _axisGesture;
  StructuralProject? _axisPreviewProject;
  Offset? _axisMoveStart;
  StructuralGridAxis _axisInMetres(StructuralGridAxis axis) => axis.copyWith(
    start: axis.start / _cadUnitsPerMeter, end: axis.end / _cadUnitsPerMeter);
  StructuralGridAxis _axisInCad(StructuralGridAxis axis) => axis.copyWith(
    start: axis.start * _cadUnitsPerMeter, end: axis.end * _cadUnitsPerMeter);
  void _beginAxisHandle(StructuralGridAxis axis, bool start) {
    _axisMoveStart = null;
    _axisGesture = BimEditSession(context: _duplicateContext,
      original: List.unmodifiable(_project.effectiveGridAxes));
    _selectedGridAxis = axis;
    _draggingAxisStart = start;
    _isDraggingAxisHandle = true;
  }
  void _beginAxisMove(StructuralGridAxis axis, Offset screen) {
    _beginAxisHandle(axis, false);
    _axisMoveStart = _screenToCad(screen) / _cadUnitsPerMeter;
  }
  void _previewAxisHandle(Offset screen) {
    final session = _axisGesture;
    if (session == null || _selectedGridAxis == null) return;
    final original = session.original.firstWhere((a) => a.id == _selectedGridAxis!.id);
    final model = _axisInMetres(original);
    final point = _screenToCad(screen) / _cadUnitsPerMeter;
    final axes = session.original.map(_axisInMetres).toList();
    final radius = math.min(16 / (_getCadFitScale() * _transformController.value.getMaxScaleOnAxis() * _cadUnitsPerMeter), .20);
    final StructuralGridAxis updated;
    if (_axisMoveStart != null) {
      final delta = BimAxisOperations.movingDelta(original: model,
        delta: point - _axisMoveStart!, axes: axes, captureRadius: radius);
      updated = _axisInCad(model.copyWith(start: model.start + delta, end: model.end + delta));
    } else {
      updated = _axisInCad(BimAxisOperations.handlePreview(original: model,
        startHandle: _draggingAxisStart, point: point, axes: axes, captureRadius: radius));
    }
    if (!session.update(_duplicateContext, (axes) => BimAxisOperations.alignParallel(axes, updated))) return;
    setState(() {
      _axisPreviewProject = _project.copyWithGridAxes(session.preview);
      _selectedGridAxis = updated;
    });
  }
  void _cancelAxisGesture() {
    _axisGesture?.cancel();
    _axisGesture = null;
    _axisPreviewProject = null;
    _axisMoveStart = null;
    _isDraggingAxisHandle = false;
    if (_selectedGridAxis != null) _selectedGridAxis = _findProjectAxis(_selectedGridAxis!);
  }
  void _finishAxisGesture(Offset screen) {
    _previewAxisHandle(screen);
    final session = _axisGesture;
    final changed = session != null && session.original.any((axis) {
      final preview = session.preview.firstWhere((a) => a.id == axis.id);
      return axis.start != preview.start || axis.end != preview.end;
    });
    final axes = session?.finish(_duplicateContext, changed: changed);
    _cancelAxisGesture();
    if (axes != null) {
      _pushUndo();
      _updateProjectGridAxes(resequenceGridAxes(axes, isBulgarian: Localizations.localeOf(context).languageCode == 'bg'));
    }
  }
  bool _isMovingColumn = false;
  bool _hasMovedSelectedColumn = false;
  bool _isMovingShearWall = false;
  bool _hasMovedSelectedShearWall = false;
  StructuralAxisLockMode _axisLockMode = StructuralAxisLockMode.autoMode;
  Offset? _elementGrabOffsetCad;
  Offset? _elementMoveOriginalCenter;
  List<(Offset, Offset)>? _activeMagneticGuides;
  bool _isMovingOpening = false;
  bool _hasMovedSelectedOpening = false;
  List<Offset>? _movingOpeningRelativeOffsets;
  Offset? _movingOpeningOriginalCenter;
  int? _selectedOpeningVertexIndex;
  int? _draggingOpeningVertexIndex;
  Offset? _draggingOpeningVertexCad;
  int? _mergeCandidateOpeningVertexIndex;
  SlabEdgeGripInfo? _activeOpeningGrip;
  List<Offset>? _previewOpeningOffsetPolygon;
  StructuralColumn? _columnMirrorBase;
  int _columnMirrorCycle = 0;
  bool _isOffsettingAxisWithDrag = false;
  double _axisOffsetDistanceMeters = 3.0;
  StructuralGridAxis? _axisBeingOffset;
  double _currentOffsetSign = 1.0;

  bool _isOffsettingColumnWithDrag = false;
  double _columnOffsetDistanceMeters = 4.0;
  StructuralColumn? _columnBeingOffset;
  Offset _columnOffsetDirection = const Offset(1, 0);

  bool get _hasSelectedElement =>
      _selectedColumn != null ||
      _selectedShearWall != null ||
      _selectedBeam != null ||
      _selectedOpening != null ||
      _selectedGridAxis != null;

  // Slab Correction States (Kotocadastre object correction workflow)
  StructuralSlab? _editingSlab;
  bool get _isEditingSlab => _editingSlab != null;
  StructuralSlab? _initialSlabBeforeCorrection;
  StructuralProject? _initialSlabCorrectionProject;
  final List<List<StructuralSlab>> _slabCorrectionUndoStack = [];
  int? _draggingSlabVertexIndex;
  Offset? _draggingSlabVertexCad;
  int? _mergeCandidateSlabVertexIndex;
  int? _selectedSlabVertexIndex;
  Offset? _midpointTouchDownPos;

  // History for Undo
  final _history = BimEditHistory<StructuralProject>(limit: 20);

  // Viewport & Scale
  Size _viewportSize = Size.zero;
  int _activePointersCount = 0;
  PointerDeviceKind? _activePointerKind;
  bool _isMultiTouchGesture = false;
  double _renderScale = 1.0;
  Timer? _scaleSettleTimer;

  // CAD Display Settings & Theme
  DxfDisplaySettings _displaySettings = const DxfDisplaySettings();
  DxfCanvasTheme _canvasTheme = DxfCanvasTheme.darkCad;

  // Layer filter for structural underlay (isolate thick walls & grid axes)
  bool _underlayFilterActive = false;
  int _underlayRevision = 0;
  bool _isFilteringUnderlay = false;
  Set<String>? _customUnderlayFilterLayers;
  final Map<String, bool> _originalLayerVisibility = {};

  // Analysis result
  StructuralAnalysisSummary _analysisSummary = StructuralAnalysisSummary.empty;
  VerticalCapacityReport _verticalCapacityReport = VerticalCapacityReport.empty;
  final _spanFeedbackCache = SupportSpanFeedbackCache();
  SeismicAnalysisReport _seismicAnalysisReport = SeismicAnalysisReport.empty;

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject ?? const StructuralProject();
    _initDisplaySettings();
    DxfDisplaySettingsService.settingsNotifier.addListener(_onDisplaySettingsChanged);
    _transformController = TransformationController(
      widget.initialTransform != null
          ? Matrix4.copy(widget.initialTransform!)
          : Matrix4.identity(),
    );
    final initialScale = widget.initialTransform?.getMaxScaleOnAxis() ?? 1.0;
    _renderScale = initialScale.clamp(0.001, 10000.0);
    _transformController.addListener(_onTransformChanged);

    if (widget.bimContext != null) {
      for (final doc in widget.bimContext!.underlaysByStorey.values) {
        BimUnderlayMetadata.ensureDynamicLayers(doc);
      }
    }

    for (final entry in _document.layers.entries) {
      _originalLayerVisibility[entry.key] = entry.value.isVisible;
    }

    if (BimUnderlayMetadata.read(_document) != null) {
      final metadata = BimUnderlayMetadata.read(_document)!;
      _underlayFilterActive = _document.layers[metadata['wallLayer']]?.isVisible == true;
    }
    // Standalone drawings retain their existing filter controls.
    // The user can manually toggle structural underlay filtering via the AppBar funnel icon.
    if (widget.bimContext == null && _project.activeStorey.gridAxes.isEmpty) {
      if (widget.initialDetectionResult != null && widget.initialDetectionResult!.hasWallsFound) {
        final axes = WallAxisDetector.convertToStructuralGridAxes(
          widget.initialDetectionResult!.snappedCenterlines,
          isBulgarian: true,
          scale: widget.initialDetectionResult!.detectedScale,
        );
        if (axes.isNotEmpty) {
          final storeys = List<StoreyLevel>.from(_project.storeys);
          final activeIndex = _project.activeStoreyIndex.clamp(0, storeys.length - 1);
          storeys[activeIndex] = storeys[activeIndex].copyWith(gridAxes: axes);
          _project = _project.copyWith(storeys: storeys);
        }
      } else {
        final imported = WallAxisDetector.extractGridAxesFromDocument(_document);
        if (imported.isNotEmpty) {
          final storeys = List<StoreyLevel>.from(_project.storeys);
          final activeIndex = _project.activeStoreyIndex.clamp(0, storeys.length - 1);
          storeys[activeIndex] = storeys[activeIndex].copyWith(gridAxes: imported);
          _project = _project.copyWith(storeys: storeys);
        }
      }
    }
    if (_project.activeStorey.gridAxes.isEmpty) {
      _activeTool = StructuralDrawTool.gridAxis;
    } else {
      _activeTool = StructuralDrawTool.column;
    }
    _runAnalysis();

    // Auto-load persisted BiM model if previously saved for this drawing (demo mode only)
    if (widget.bimContext == null) {
      final docKey = widget.title ?? 'structural_model';
      StructuralPersistenceService.loadProject(documentKey: docKey).then((saved) {
        if (saved != null && mounted) {
          setState(() {
            _project = saved;
            _runAnalysis();
            if (_project.activeStorey.gridAxes.isEmpty) {
              _activeTool = StructuralDrawTool.gridAxis;
            } else {
              _activeTool = StructuralDrawTool.column;
            }
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoDetectWallsOnStartup();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedStoreyName && _project.storeys.isNotEmpty) {
      _initializedStoreyName = true;
      final storeys = List<StoreyLevel>.from(_project.storeys);
      bool changed = false;
      for (int i = 0; i < storeys.length; i++) {
        final s = storeys[i];
        if (s.name.startsWith('Етаж') ||
            s.name.startsWith('Storey') ||
            s.name.contains('Ground') ||
            s.name.contains('Floor') ||
            s.name.contains('Basement')) {
          storeys[i] = s.copyWith(name: s.elevationLabel);
          changed = true;
        }
      }
      if (changed) {
        _project = _project.copyWith(storeys: storeys);
      }
    }
  }

  @override
  void dispose() {
    _scaleSettleTimer?.cancel();
    DxfDisplaySettingsService.settingsNotifier.removeListener(_onDisplaySettingsChanged);
    _transformController.removeListener(_onTransformChanged);
    for (final entry in _originalLayerVisibility.entries) {
      _document.layers[entry.key]?.isVisible = entry.value;
    }
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _initDisplaySettings() async {
    final loaded = await DxfDisplaySettingsService.getSettings();
    if (mounted) {
      setState(() {
        _displaySettings = loaded;
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

  void _onTransformChanged() {
    _scaleSettleTimer?.cancel();
    _scaleSettleTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      final currentScale =
          _transformController.value.getMaxScaleOnAxis().clamp(0.001, 10000.0);
      setState(() {
        _renderScale = currentScale;
      });
    });
  }

  void _pushUndo() {
    _history.checkpoint(_project);
  }

  void _undo() {
    if (_history.canUndo) {
      setState(() {
        _selectedColumn = null;
        _isMovingColumn = false;
        _selectedShearWall = null;
        _isMovingShearWall = false;
        _editingSlab = null;
        _initialSlabBeforeCorrection = null;
        final viewedId = _project.activeStorey.id;
        final snapshot = _history.undo(_project);
        final index = snapshot.storeys.indexWhere((s) => s.id == viewedId);
        _project = index < 0 ? snapshot : snapshot.copyWith(activeStoreyIndex: index);
        _runAnalysis();
      });
      _saveProject();
      HapticFeedback.lightImpact();
    }
  }

  double get _cadUnitsPerMeter {
    if (widget.bimContext != null) {
      return widget.bimContext!.cadUnitsPerMeter;
    }
    final unit = _document.unit;
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
    _verticalCapacityReport = VerticalCapacityCalculator.analyzeProject(
      _project,
      cadUnitsPerMeter: _cadUnitsPerMeter,
    );
    _seismicAnalysisReport = SeismicAnalysisCalculator.analyzeProject(
      _project,
      cadUnitsPerMeter: _cadUnitsPerMeter,
    );
  }

  List<SupportSpanCheck> get _liveSupportSpanChecks {
    final center=_currentCadCoord;
    StructuralColumn? col;
    StructuralShearWall? wall;
    if(center!=null) {
      if(_isMovingColumn && _selectedColumn!=null) {
        col=_selectedColumn!.copyWith(center:center);
      } else if(_isPlacingWithHold && _activeTool==StructuralDrawTool.column) {
        col=_currentColumnPreset.copyWith(id:'__spacing_preview_column__',center:center,
          width:_currentColumnPreset.width*_cadUnitsPerMeter,
          height:_currentColumnPreset.height*_cadUnitsPerMeter,
          thickness:_currentColumnPreset.thickness*_cadUnitsPerMeter);
      }
      if(_isMovingShearWall && _selectedShearWall!=null) {
        final delta=center-_selectedShearWall!.center;
        wall=_selectedShearWall!.copyWith(start:_selectedShearWall!.start+delta,
            end:_selectedShearWall!.end+delta);
      } else if(_isPlacingWithHold && _activeTool==StructuralDrawTool.shearWall) {
        final u=Offset(math.cos(_currentWallRotationRad),math.sin(_currentWallRotationRad));
        wall=StructuralShearWall(id:'__spacing_preview_wall__',
            start:center-u*_currentWallLength*_cadUnitsPerMeter/2,
            end:center+u*_currentWallLength*_cadUnitsPerMeter/2,
            thickness:_currentWallThickness*_cadUnitsPerMeter);
      }
    }
    if(col==null && wall==null) {
      return _verticalCapacityReport.slabChecks
          .where((s)=>s.storeyId==_project.activeStorey.id).firstOrNull?.supportSpans ?? const [];
    }
    return _spanFeedbackCache.evaluate(_project,_cadUnitsPerMeter,
        previewColumn:col,previewWall:wall);
  }

  Offset? get _spanFocusCad =>
      (_isPlacingWithHold || _isMovingColumn || _isMovingShearWall)
          ? _currentCadCoord : _selectedColumn?.center ?? _selectedShearWall?.center;

  // --- Coordinate Transformations ---

  Rect get _cadBounds {
    if (widget.bimContext != null) {
      return widget.bimContext!.projectBounds;
    }
    if (widget.initialCadBounds != null &&
        !widget.initialCadBounds!.isEmpty &&
        widget.initialCadBounds!.isFinite) {
      return widget.initialCadBounds!;
    }
    return _document.bounds;
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

  Rect? _getVisibleCadRect() {
    if (_viewportSize.isEmpty) return null;
    try {
      final pTopLeft = _transformController.toScene(Offset.zero);
      final pBottomRight = _transformController.toScene(
        Offset(_viewportSize.width, _viewportSize.height),
      );

      final cadTopLeft = _sceneToCad(pTopLeft);
      final cadBottomRight = _sceneToCad(pBottomRight);

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

      final bounds = _cadBounds;
      final maxDocExtent = bounds.inflate(bounds.longestSide * 0.05 + 10.0);
      return rect.intersect(maxDocExtent);
    } catch (_) {
      return null;
    }
  }

  // --- Pointer & Touch Handling with Offset Ruler (56px) & Magnetic Snap ---

  SlabEdgeGripInfo? _hitTestSlabMidpoint(Offset screenPos) {
    if (_activeTool != StructuralDrawTool.slab && _activeTool != StructuralDrawTool.select) {
      return null;
    }
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

  StructuralBeam? _hitTestBeam(Offset screenPos) {
    const double hitMarginScreen = 24.0;
    for (final beam in _project.activeStorey.beams.reversed) {
      final pts = beam.polygonVertices.map(_cadToScreen).toList();
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
        return beam;
      }
    }
    return null;
  }

  (String, int)? _hitTestOpening(Offset screenPos) {
    if (!_showBimSlabs) return null;
    const double hitMarginScreen = 20.0;
    for (final slab in _project.activeStorey.slabs.reversed) {
      if (widget.bimContext != null && slab.isFloorSlab && !_isEditingSlab) continue;
      for (int i = 0; i < slab.openings.length; i++) {
        final op = slab.openings[i];
        if (op.length < 3) continue;
        final pts = op.map(_cadToScreen).toList();
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
          return (slab.id, i);
        }
      }
    }
    return null;
  }

  int? _hitTestOpeningVertex(Offset screenPos, List<Offset> opening) {
    const double hitMarginScreen = 24.0;
    for (int i = 0; i < opening.length; i++) {
      final sPt = _cadToScreen(opening[i]);
      if ((screenPos - sPt).distance <= hitMarginScreen) {
        return i;
      }
    }
    return null;
  }

  SlabEdgeGripInfo? _hitTestOpeningMidpoint(Offset screenPos, StructuralSlab slab, int opIdx) {
    const double hitMarginScreen = 24.0;
    final grips = slab.getOpeningEdgeGrips(opIdx);
    for (final grip in grips) {
      final sMid = _cadToScreen(grip.midpoint);
      if ((screenPos - sMid).distance <= hitMarginScreen) {
        return grip;
      }
    }
    return null;
  }

  void _deleteSelectedOpeningVertex() {
    if (_selectedOpening == null || _selectedOpeningVertexIndex == null) return;
    final (slabId, opIdx) = _selectedOpening!;
    final active = _project.activeStorey;
    final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
    if (slabIdx == -1) return;
    final slab = active.slabs[slabIdx];
    if (opIdx >= slab.openings.length) return;
    final op = slab.openings[opIdx];
    if (op.length <= 3) return;

    final updatedSlab = slab.removeOpeningVertex(opIdx, _selectedOpeningVertexIndex!);
    if (updatedSlab != null && _updateOpeningInStorey(
        (slabId, opIdx), updatedSlab.openings[opIdx], allowTransfer: false)) {
      setState(() {
        _selectedOpeningVertexIndex = null;
      });
      _saveProject();
      HapticFeedback.mediumImpact();
    }
  }

  StructuralGridAxis? _hitTestGridAxis(Offset screenPos) {
    if (!_showBimAxes) return null;
    final bubbles = GridAxisBubbleLayout.build(axes:_project.activeStorey.gridAxes,
      project:_cadToScreen, zoom:1, labelScale:GridAxisBubbleLayout.textScale(_transformController.value.getMaxScaleOnAxis()), levels:(axis) {
        final style=GridAxisPresentation.forStorey(axis,_project.activeStorey,_project.storeys);
        return style.reference ? style.levels : ''; });
    for (final axis in _project.activeStorey.gridAxes.reversed) {
      for (final start in [true,false]) {
        final point=bubbles[(axis.id,start)];
        if(point!=null && (point-screenPos).distance<=12) return axis;
      }
    }
    const double hitMarginScreen = 24.0;
    for (final axis in _project.activeStorey.gridAxes.reversed) {
      final p1 = _cadToScreen(axis.start);
      final p2 = _cadToScreen(axis.end);
      final closest = BimLineGeometry.closest(screenPos, p1, p2);
      if ((screenPos - closest).distance <= hitMarginScreen) {
        return axis;
      }
      if (axis.bubbleAtEnd && (screenPos - p2).distance <= hitMarginScreen * 1.5) {
        return axis;
      }
      if (axis.bubbleAtStart && (screenPos - p1).distance <= hitMarginScreen * 1.5) {
        return axis;
      }
    }
    return null;
  }

  (StructuralGridAxis, bool)? _hitTestGridAxisHandle(Offset screenPos) {
    const double hitMarginScreen = 28.0;
    if (_selectedGridAxis != null) {
      final p1 = _cadToScreen(_selectedGridAxis!.start);
      final p2 = _cadToScreen(_selectedGridAxis!.end);
      if ((screenPos - p1).distance <= hitMarginScreen) {
        return (_selectedGridAxis!, true); // start handle
      }
      if ((screenPos - p2).distance <= hitMarginScreen) {
        return (_selectedGridAxis!, false); // end handle
      }
    }
    // Also test endpoints of all other grid axes in the active storey
    for (final axis in _project.activeStorey.gridAxes) {
      if (_selectedGridAxis != null && axis.id == _selectedGridAxis!.id) continue;
      final p1 = _cadToScreen(axis.start);
      final p2 = _cadToScreen(axis.end);
      if ((screenPos - p1).distance <= hitMarginScreen) {
        return (axis, true);
      }
      if ((screenPos - p2).distance <= hitMarginScreen) {
        return (axis, false);
      }
    }
    return null;
  }

  String? _slabBadgeOwnerId;
  bool get _showBimSlabs => widget.bimContext == null ||
      BimUnderlayMetadata.dynamicVisible(_document, 'slabs');
  bool get _showBimAxes => widget.bimContext == null ||
      BimUnderlayMetadata.dynamicVisible(_document, 'axes');

  bool _slabBadgeSelectionHandled = false;
  StructuralSlab? _hitTestSlab(Offset screenPos) {
    if (!_showBimSlabs) return null;
    if (_activeTool != StructuralDrawTool.slab && _activeTool != StructuralDrawTool.select) {
      return null;
    }
    _slabBadgeOwnerId = null;
    if (_activeTool == StructuralDrawTool.slab) {
      final labels = SlabPlanLabels.layout(current:_project.activeStorey,
        lower:_floorSlabStorey, upper:_isEditingSlab ? null : _ceilingSlabStorey,
        showFloorSlabs:_isEditingSlab, project:_cadToScreen,
        selectedId:_editingSlab?.id);
      for (final label in labels) {
        if (label.rect.contains(screenPos)) {
          _slabBadgeSelectionHandled = true;
          _slabBadgeOwnerId = label.owner.id == _project.activeStorey.id ? null : label.owner.id;
          // Ceiling references carry transformed flags; edit the persisted slab.
          return _project.storeys.firstWhere((s) => s.id == label.owner.id).slabs
            .firstWhere((s) => s.id == label.slab.id);
        }
      }
    }
    // If user tapped on or near any compact structural element, NEVER select slab!
    if (_hitTestColumn(screenPos) != null ||
        _hitTestShearWall(screenPos) != null ||
        _hitTestBeam(screenPos) != null ||
        _hitTestOpening(screenPos) != null ||
        _hitTestGridAxis(screenPos) != null) {
      return null;
    }

    final active = _project.activeStorey;
    // 1. Prioritize boundary edge check (screen tolerance ~ 24px)
    const double edgeTolScreen = 24.0;
    for (final slab in active.slabs.reversed) {
      if (widget.bimContext != null && slab.isFloorSlab && !_isEditingSlab) continue;
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

    // 2. Interior polygon test (only when in clear open floor area)
    final cadPt = _screenToCad(screenPos);
    for (final slab in active.slabs.reversed) {
      if (widget.bimContext != null && slab.isFloorSlab && !_isEditingSlab) continue;
      if (slab.containsPoint(cadPt)) {
        return slab;
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

  (StructuralSlab, int)? _hitTestAnySlabVertex(Offset screenPos) {
    if (_activeTool != StructuralDrawTool.slab && _activeTool != StructuralDrawTool.select) {
      return null;
    }
    if (_editingSlab != null) {
      final vIdx = _hitTestSlabVertex(screenPos, _editingSlab!);
      if (vIdx != null) return (_editingSlab!, vIdx);
    }
    for (final slab in _project.activeStorey.slabs) {
      if (widget.bimContext != null && slab.isFloorSlab && !_isEditingSlab) continue;
      final vIdx = _hitTestSlabVertex(screenPos, slab);
      if (vIdx != null) return (slab, vIdx);
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
    final deleted = _selectedColumn!;
    final remainingCols =
        active.columns.where((c) => c.id != deleted.id).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedCols = renumberColumnsAfterDeletion(
      remainingCols,
      deleted,
      defaultPrefix: isBg ? 'К' : 'C',
    );
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      _selectedColumn = null;
      _isMovingColumn = false;
    });
    HapticFeedback.heavyImpact();
  }

  void _rotateSelectedColumn() {
    if (_selectedColumn == null) return;
    _columnMirrorBase = null;
    _columnMirrorCycle = 0;
    _pushUndo();
    final active = _project.activeStorey;
    final col = _selectedColumn!;
    final updatedCol = const StructuralColumnEditingAdapter().rotate(col, math.pi / 2);
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
    final current = _selectedColumn!;

    // Initialize or continue the outer-edge reflection sequence
    if (_columnMirrorBase == null || _columnMirrorBase!.id != current.id) {
      _columnMirrorBase = current;
      _columnMirrorCycle = 0;
    }

    // Sequence cycles through 4 outer bounding faces, then loops back to original:
    // 1: Right face (+W offset along uX, flip X)
    // 2: Top face (+H offset along uY, flip Y)
    // 3: Left face (-W offset along uX, flip X)
    // 4: Bottom face (-H offset along uY, flip Y)
    // 0: Reset to original baseline
    _columnMirrorCycle = (_columnMirrorCycle + 1) % 5;

    final StructuralColumn updatedCol;
    if (_columnMirrorCycle == 0) {
      // Loop back to initial baseline element
      updatedCol = _columnMirrorBase!;
      _columnMirrorBase = null;
    } else {
      final base = _columnMirrorBase!;
      final double rot = base.rotationRad;
      final cosA = math.cos(rot);
      final sinA = math.sin(rot);
      // Unit vectors along column width (uX) and column height (uY)
      final uX = Offset(cosA, sinA);
      final uY = Offset(-sinA, cosA);

      final double w = base.width;
      final double h = base.height;

      switch (_columnMirrorCycle) {
        case 1:
          // 1. Right outer face (+W offset along uX)
          final newCenter = base.center + uX * w;
          if (base.shape == ColumnShape.lShape) {
            updatedCol = base.copyWith(
              center: newCenter,
              isMirrored: !base.isMirrored,
            );
          } else {
            updatedCol = base.copyWith(
              center: newCenter,
              rotationRad: (math.pi - rot) % (2 * math.pi),
            );
          }
          break;
        case 2:
          // 2. Top outer face (+H offset along uY)
          final newCenter = base.center + uY * h;
          if (base.shape == ColumnShape.lShape) {
            updatedCol = base.copyWith(
              center: newCenter,
              isMirrored: !base.isMirrored,
              rotationRad: (rot + math.pi) % (2 * math.pi),
            );
          } else {
            updatedCol = base.copyWith(
              center: newCenter,
              rotationRad: (-rot) % (2 * math.pi),
            );
          }
          break;
        case 3:
          // 3. Left outer face (-W offset along uX)
          final newCenter = base.center - uX * w;
          if (base.shape == ColumnShape.lShape) {
            updatedCol = base.copyWith(
              center: newCenter,
              isMirrored: !base.isMirrored,
            );
          } else {
            updatedCol = base.copyWith(
              center: newCenter,
              rotationRad: (math.pi - rot) % (2 * math.pi),
            );
          }
          break;
        case 4:
        default:
          // 4. Bottom outer face (-H offset along uY)
          final newCenter = base.center - uY * h;
          if (base.shape == ColumnShape.lShape) {
            updatedCol = base.copyWith(
              center: newCenter,
              isMirrored: !base.isMirrored,
              rotationRad: (rot + math.pi) % (2 * math.pi),
            );
          } else {
            updatedCol = base.copyWith(
              center: newCenter,
              rotationRad: (-rot) % (2 * math.pi),
            );
          }
          break;
      }
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

  String _generateNextColumnName(List<StructuralColumn> existing) {
    int maxNum = 0;
    final regExp = RegExp(r'^[КKkк](\d+)$');
    for (final col in existing) {
      final name = col.name ?? '';
      final match = regExp.firstMatch(name.trim());
      if (match != null) {
        final val = int.tryParse(match.group(1)!);
        if (val != null && val > maxNum) {
          maxNum = val;
        }
      }
    }
    if (maxNum == 0 && existing.isNotEmpty) {
      maxNum = existing.length;
    }
    return 'К${maxNum + 1}';
  }

  void _renameSelectedColumn() {
    if (_selectedColumn == null) return;
    final current = _selectedColumn!;
    final controller = TextEditingController(text: current.displayName);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Color(0xFFFFB300), size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.renameColumnTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: context.l10n.designationLabel,
            labelStyle: const TextStyle(color: Color(0xFFFFB300)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFB300))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFB300), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop(val.isNotEmpty ? val : current.displayName);
            },
            child: Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty && newName != current.displayName) {
        _pushUndo();
        final updated = current.copyWith(name: newName);
        final active = _project.activeStorey;
        final updatedCols = active.columns
            .map((c) => c.id == updated.id ? updated : c)
            .toList();
        _updateActiveStorey(active.copyWith(columns: updatedCols));
        setState(() {
          _selectedColumn = updated;
        });
        HapticFeedback.selectionClick();
      }
    });
  }

  void _startDuplicateDrag(Object source) {
    final active = _project.activeStorey;
    final id = 'drag_copy_${DateTime.now().microsecondsSinceEpoch}';
    final draft = switch (source) {
      StructuralColumn c => c.copyWith(
        id: id,
        name: _generateNextColumnName(active.columns),
      ),
      StructuralShearWall w => w.copyWith(
        id: id,
        name: _generateNextShearWallName(active.shearWalls),
      ),
      StructuralBeam b => b.copyWith(
        id: id,
        name:
            '${context.l10n.structuralBeamNamePrefix}${active.beams.map((b) => extractElementNumber(b.displayName) ?? 0).fold(0, math.max) + 1}',
      ),
      _ => throw ArgumentError.value(source),
    };
    final center = switch (source) {
      StructuralColumn c => c.center,
      StructuralShearWall w => w.center,
      StructuralBeam b => (b.start + b.end) / 2,
      _ => Offset.zero,
    };
    setState(() {
      _duplicateSession = BimDragSession(context: _duplicateContext, original: draft,
        anchor: center / _cadUnitsPerMeter, translate: _translatedDuplicate);
      _duplicateStoreyId = active.id;
      _elementGrabOffsetCad = null;
    });
    HapticFeedback.selectionClick();
  }

  Object? get _positionedDuplicate => _duplicateSession?.preview;

  Object _translatedDuplicate(Object original, Offset delta) {
    final frame = BimCoordinateFrame(unitsPerMeter: _cadUnitsPerMeter);
    return switch (original) {
      StructuralColumn c => StructuralColumnEditingAdapter(frame: frame).translate(c, delta),
      StructuralShearWall w => StructuralWallEditingAdapter(frame: frame).translate(w, delta),
      StructuralBeam b => StructuralBeamEditingAdapter(frame: frame).translate(b, delta),
      _ => throw ArgumentError.value(original),
    };
  }

  StoreyLevel _withDuplicate(StoreyLevel floor) =>
      switch (floor.id == _duplicateStoreyId ? _positionedDuplicate : null) {
        StructuralColumn c => floor.copyWith(columns: [...floor.columns, c]),
        StructuralShearWall w => floor.copyWith(
          shearWalls: [...floor.shearWalls, w],
        ),
        StructuralBeam b => floor.copyWith(beams: [...floor.beams, b]),
        _ => floor,
      };

  void _updateDuplicateDrag(Offset screenPos, {required bool isMouse}) {
    var target = (_duplicateSession!.targetForPointer(_screenToCad(screenPos) / _cadUnitsPerMeter)) * _cadUnitsPerMeter;
    if (_snapEnabled) {
      final tolerance = StructuralPointerInteraction.snapToleranceCad(
        isMouse: isMouse,
        pixelsPerCadUnit:
            _getCadFitScale() * _transformController.value.getMaxScaleOnAxis(),
        cadUnitsPerMeter: _cadUnitsPerMeter,
      );
      final snap =
          _findStructuralSnap(target, tolerance) ??
          DxfSnapHelper.findSnapPoint(
            document: _document,
            cadPoint: target,
            toleranceCad: tolerance,
          );
      if (snap != null) target = snap.point;
    }
    setState(() {
      _duplicateSession?.updateTarget(_duplicateContext, target / _cadUnitsPerMeter);
    });
  }

  void _cancelDuplicateDrag() {
    setState(() {
      _duplicateSession?.cancel();
      _duplicateSession = null;
      _duplicateStoreyId = null;
    });
  }

  void _commitDuplicateDrag() {
    if (_project.activeStorey.id != _duplicateStoreyId) {
      _cancelDuplicateDrag();
      return;
    }
    final copy = _duplicateSession?.finish(_duplicateContext);
    if (copy == null) {
      _cancelDuplicateDrag();
      return;
    }
    _pushUndo();
    _updateActiveStorey(_withDuplicate(_project.activeStorey));
    setState(() {
      _selectedColumn = copy is StructuralColumn ? copy : null;
      _selectedShearWall = copy is StructuralShearWall ? copy : null;
      _selectedBeam = copy is StructuralBeam ? copy : null;
      _selectedGridAxis = null;
      _selectedOpening = null;
      _duplicateSession?.cancel();
      _duplicateSession = null;
      _duplicateStoreyId = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _duplicateSelectedColumn() {
    if (_selectedColumn == null) return;
    _startDuplicateDrag(_selectedColumn!);
  }

  String _generateNextShearWallName(List<StructuralShearWall> existing) {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final defaultPrefix = isBg ? 'Ш' : 'W';
    int maxNum = 0;
    for (final wall in existing) {
      final val = extractElementNumber(wall.displayName);
      if (val != null && val > maxNum) {
        maxNum = val;
      }
    }
    return '$defaultPrefix${maxNum + 1}';
  }

  void _deleteSelectedWall() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final deleted = _selectedShearWall!;
    final remainingWalls =
        active.shearWalls.where((w) => w.id != deleted.id).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedWalls = renumberShearWallsAfterDeletion(
      remainingWalls,
      deleted,
      defaultPrefix: isBg ? 'Ш' : 'W',
    );
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = null;
      _isMovingShearWall = false;
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

  void _rotateSelectedWall() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final wall = _selectedShearWall!;
    final updated = const StructuralWallEditingAdapter().rotate(wall, math.pi / 2);
    final active = _project.activeStorey;
    final updatedWalls = active.shearWalls
        .map((w) => w.id == updated.id ? updated : w)
        .toList();
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() => _selectedShearWall = updated);
    HapticFeedback.selectionClick();
  }

  void _startMovingSelectedColumn() {
    if (_selectedColumn == null) return;
    final screenPos = _cadToScreen(_selectedColumn!.center);
    setState(() {
      _isMovingColumn = true;
      _hasMovedSelectedColumn = false;
      _isPlacingWithHold = false;
      _elementMoveOriginalCenter = _selectedColumn!.center;
    });
    _updatePointer(screenPos, isMouse: false);
    HapticFeedback.selectionClick();
  }

  void _startMovingSelectedWall() {
    if (_selectedShearWall == null) return;
    final screenPos = _cadToScreen(_selectedShearWall!.center);
    setState(() {
      _isMovingShearWall = true;
      _hasMovedSelectedShearWall = false;
      _isPlacingWithHold = false;
      _elementMoveOriginalCenter = _selectedShearWall!.center;
    });
    _updatePointer(screenPos, isMouse: false);
    HapticFeedback.selectionClick();
  }

  void _confirmCurrentMove() {
    setState(() {
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _elementMoveOriginalCenter = null;
      _activeMagneticGuides = null;
      _liveDimensionText = null;
      _activeDynamicDimensionLine = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _cancelCurrentMove() {
    if (_elementMoveOriginalCenter != null) {
      final active = _project.activeStorey;
      if (_isMovingColumn && _selectedColumn != null) {
        final reverted = _selectedColumn!.copyWith(center: _elementMoveOriginalCenter!);
        final cols = active.columns.map((c) => c.id == reverted.id ? reverted : c).toList();
        _updateActiveStorey(active.copyWith(columns: cols));
        setState(() => _selectedColumn = reverted);
      } else if (_isMovingShearWall && _selectedShearWall != null) {
        final halfLen = _selectedShearWall!.length / 2.0;
        final u = Offset(math.cos(_selectedShearWall!.angleRad), math.sin(_selectedShearWall!.angleRad));
        final reverted = _selectedShearWall!.copyWith(
          start: _elementMoveOriginalCenter! - u * halfLen,
          end: _elementMoveOriginalCenter! + u * halfLen,
        );
        final walls = active.shearWalls.map((w) => w.id == reverted.id ? reverted : w).toList();
        _updateActiveStorey(active.copyWith(shearWalls: walls));
        setState(() => _selectedShearWall = reverted);
      }
    }
    setState(() {
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _elementMoveOriginalCenter = null;
      _activeMagneticGuides = null;
      _liveDimensionText = null;
      _activeDynamicDimensionLine = null;
    });
    HapticFeedback.selectionClick();
  }

  String _getShearWallRefLineLabel(BuildContext context, ShearWallReferenceLine refLine) {
    switch (refLine) {
      case ShearWallReferenceLine.center:
        return context.l10n.refLineCenter;
      case ShearWallReferenceLine.leftFace:
        return context.l10n.refLineLeft;
      case ShearWallReferenceLine.rightFace:
        return context.l10n.refLineRight;
    }
  }

  void _cycleSelectedWallReferenceLine() {
    if (_selectedShearWall == null) return;
    _pushUndo();
    final wall = _selectedShearWall!;
    final nextRef = wall.referenceLine == ShearWallReferenceLine.center
        ? ShearWallReferenceLine.leftFace
        : (wall.referenceLine == ShearWallReferenceLine.leftFace
            ? ShearWallReferenceLine.rightFace
            : ShearWallReferenceLine.center);
    final updatedWall = wall.copyWith(referenceLine: nextRef);
    final active = _project.activeStorey;
    final updatedWalls = active.shearWalls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();
    _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
    setState(() {
      _selectedShearWall = updatedWall;
    });
    HapticFeedback.selectionClick();
  }


  void _renameSelectedWall() {
    if (_selectedShearWall == null) return;
    final current = _selectedShearWall!;
    final controller = TextEditingController(text: current.displayName);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.renameColumnTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: context.l10n.shearWallTitle,
            labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop(val.isNotEmpty ? val : current.displayName);
            },
            child: Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty && newName != current.displayName) {
        _pushUndo();
        final updated = current.copyWith(name: newName);
        final active = _project.activeStorey;
        final updatedWalls = active.shearWalls
            .map((w) => w.id == updated.id ? updated : w)
            .toList();
        _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
        setState(() {
          _selectedShearWall = updated;
        });
        HapticFeedback.selectionClick();
      }
    });
  }

  void _duplicateSelectedWall() {
    if (_selectedShearWall == null) return;
    _startDuplicateDrag(_selectedShearWall!);
  }

  String _generateNextBeamName(List<StructuralBeam> existing, {required bool isBulgarian}) {
    final defaultPrefix = isBulgarian ? 'Г' : 'B';
    int maxNum = 0;
    for (final beam in existing) {
      final val = extractElementNumber(beam.displayName);
      if (val != null && val > maxNum) {
        maxNum = val;
      }
    }
    return '$defaultPrefix${maxNum + 1}';
  }

  void _renameSelectedBeam() {
    if (_selectedBeam == null) return;
    final current = _selectedBeam!;
    final controller = TextEditingController(text: current.displayName);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFB8C00), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: Color(0xFFFB8C00), size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.renameBeamTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: context.l10n.beamTitle,
            labelStyle: const TextStyle(color: Color(0xFFFB8C00)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFB8C00))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFB8C00), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFB8C00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop(val.isNotEmpty ? val : current.displayName);
            },
            child: Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((newName) {
      if (newName != null && newName.isNotEmpty && newName != current.displayName) {
        _pushUndo();
        final updated = current.copyWith(name: newName);
        final active = _project.activeStorey;
        final updatedBeams = active.beams
            .map((b) => b.id == updated.id ? updated : b)
            .toList();
        _updateActiveStorey(active.copyWith(beams: updatedBeams));
        setState(() {
          _selectedBeam = updated;
        });
        HapticFeedback.selectionClick();
      }
    });
  }

  void _deleteSelectedBeam() {
    if (_selectedBeam == null) return;
    _pushUndo();
    final active = _project.activeStorey;
    final deleted = _selectedBeam!;
    final remainingBeams =
        active.beams.where((b) => b.id != deleted.id).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedBeams = renumberBeamsAfterDeletion(
      remainingBeams,
      deleted,
      defaultPrefix: isBg ? 'Г' : 'B',
    );
    _updateActiveStorey(active.copyWith(beams: updatedBeams));
    setState(() {
      _selectedBeam = null;
    });
    HapticFeedback.heavyImpact();
  }

  void _duplicateSelectedBeam() {
    if (_selectedBeam == null) return;
    _startDuplicateDrag(_selectedBeam!);
  }

  void _updateSelectedBeamLength(double deltaMeters) {
    if (_selectedBeam == null) return;
    _pushUndo();
    final beam = _selectedBeam!;
    final active = _project.activeStorey;
    final l = beam.length;
    final newL = math.max(0.30 * _cadUnitsPerMeter, l + deltaMeters * _cadUnitsPerMeter);
    final dir = (beam.end - beam.start) / (l > 1e-6 ? l : 1.0);
    final newEnd = beam.start + dir * newL;
    final updatedBeam = beam.copyWith(end: newEnd);
    final updatedBeams = active.beams
        .map((b) => b.id == updatedBeam.id ? updatedBeam : b)
        .toList();
    _updateActiveStorey(active.copyWith(beams: updatedBeams));
    setState(() {
      _selectedBeam = updatedBeam;
    });
    HapticFeedback.selectionClick();
  }

  void _updateSelectedBeamDimensions(double wMeters, double dMeters) {
    if (_selectedBeam == null) return;
    _pushUndo();
    final beam = _selectedBeam!;
    final active = _project.activeStorey;
    final updatedBeam = beam.copyWith(
      width: wMeters * _cadUnitsPerMeter,
      depth: dMeters * _cadUnitsPerMeter,
    );
    final updatedBeams = active.beams
        .map((b) => b.id == updatedBeam.id ? updatedBeam : b)
        .toList();
    _updateActiveStorey(active.copyWith(beams: updatedBeams));
    setState(() {
      _selectedBeam = updatedBeam;
    });
    HapticFeedback.selectionClick();
  }

  void _deleteSelectedOpening() {
    if (_selectedOpening == null) return;
    _pushUndo();
    final (slabId, opIdx) = _selectedOpening!;
    final active = _project.activeStorey;
    final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
    if (slabIdx != -1) {
      final updatedSlab = active.slabs[slabIdx].removeOpening(opIdx);
      final updatedSlabs = List<StructuralSlab>.from(active.slabs);
      updatedSlabs[slabIdx] = updatedSlab;
      _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
      if (_isEditingSlab && _editingSlab!.id == slabId) {
        _editingSlab = updatedSlab;
      }
      setState(() {
        _selectedOpening = null;
        _selectedOpeningVertexIndex = null;
      });
      HapticFeedback.heavyImpact();
    }
  }

  List<Offset>? _getOpeningPolygon((String, int)? key) {
    if (key == null) return null;
    final (slabId, opIdx) = key;
    final active = _project.activeStorey;
    final slab = active.slabs.firstWhere(
      (s) => s.id == slabId,
      orElse: () => active.slabs.first,
    );
    if (opIdx >= 0 && opIdx < slab.openings.length) {
      return slab.openings[opIdx];
    }
    return null;
  }

  Offset _getOpeningCenter(List<Offset> poly) {
    if (poly.isEmpty) return Offset.zero;
    final sum = poly.reduce((a, b) => a + b);
    return Offset(sum.dx / poly.length, sum.dy / poly.length);
  }

  void _startMovingOpening((String, int) key, Offset screenPos, {required bool isMouse}) {
    final poly = _getOpeningPolygon(key);
    if (poly == null || poly.isEmpty) return;
    final center = _getOpeningCenter(poly);
    final relativeOffsets = poly.map((p) => p - center).toList();

    setState(() {
      _selectedOpening = key;
      _selectedColumn = null;
      _selectedShearWall = null;
      _selectedBeam = null;
      _selectedGridAxis = null;
      _isMovingOpening = true;
      _hasMovedSelectedOpening = false;
      _movingOpeningRelativeOffsets = relativeOffsets;
      _movingOpeningOriginalCenter = center;
      _isPlacingWithHold = false;
    });
    _updatePointer(screenPos, isMouse: isMouse);
    HapticFeedback.selectionClick();
  }

  void _rotateSelectedOpening() {
    if (_selectedOpening == null) return;
    final poly = _getOpeningPolygon(_selectedOpening);
    if (poly == null || poly.isEmpty) return;
    final center = _getOpeningCenter(poly);

    // Rotate 90 degrees CCW around center: (dx, dy) -> (-dy, dx)
    final rotatedPoly = poly.map((p) {
      final d = p - center;
      return center + Offset(-d.dy, d.dx);
    }).toList();

    _updateOpeningInStorey(_selectedOpening!, rotatedPoly);
    HapticFeedback.selectionClick();
  }

  bool _updateOpeningInStorey((String, int) oldKey, List<Offset> newPoly,
      {bool allowTransfer = true}) {
    final result = SlabOpeningPlacement.apply(
      slabs: _project.activeStorey.slabs, polygon: newPoly,
      scale: _cadUnitsPerMeter, replacing: oldKey, allowTransfer: allowTransfer,
      floorOwnedOnly: widget.bimContext != null);
    return _applyOpeningPlacement(result);
  }

  bool _applyOpeningPlacement(OpeningPlacementResult result) {
    if (!result.accepted) {
      final message = switch (result.issue) {
        OpeningPlacementIssue.missingSlab => context.l10n.openingNoSlab,
        OpeningPlacementIssue.ambiguousOwner => context.l10n.openingAmbiguousOwner,
        OpeningPlacementIssue.missingOpening => context.l10n.openingMissing,
        _ => context.l10n.openingInvalidPlacement,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return false;
    }
    _pushUndo();
    _updateActiveStorey(_project.activeStorey.copyWith(slabs: result.slabs!));
    setState(() {
      _selectedOpening = result.opening;
      _selectedOpeningVertexIndex = null;
    });
    return true;
  }

  SlabOpeningType _cycleOpeningType(SlabOpeningType current) {
    switch (current) {
      case SlabOpeningType.shaft:
        return SlabOpeningType.staircase;
      case SlabOpeningType.staircase:
        return SlabOpeningType.elevator;
      case SlabOpeningType.elevator:
        return SlabOpeningType.custom;
      case SlabOpeningType.custom:
        return SlabOpeningType.shaft;
    }
  }

  void _updateOpeningTypeInStorey((String, int) key, SlabOpeningType newType) {
    _pushUndo();
    final (slabId, opIdx) = key;
    final active = _project.activeStorey;
    final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
    if (slabIdx != -1) {
      final updatedSlab = active.slabs[slabIdx].updateOpeningType(opIdx, newType);
      final updatedSlabs = List<StructuralSlab>.from(active.slabs);
      updatedSlabs[slabIdx] = updatedSlab;
      _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
      HapticFeedback.selectionClick();
    }
  }

  String _getOpeningTypeName(SlabOpeningType type, AppLocalizations l10n) {
    switch (type) {
      case SlabOpeningType.shaft:
        return l10n.openingShaftTitle;
      case SlabOpeningType.staircase:
        return l10n.openingStaircaseTitle;
      case SlabOpeningType.elevator:
        return l10n.openingElevatorTitle;
      case SlabOpeningType.custom:
        return l10n.slabOpeningTitle;
    }
  }

  Size? _getPreviewOpeningSize() => null;

  List<Offset>? _getPreviewOpeningScreenPolygon() {
    if (_isMovingOpening && _movingOpeningRelativeOffsets != null) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double screenCadScale = fitScale * currentScale.clamp(0.001, 10000.0);
      return _movingOpeningRelativeOffsets!
          .map((r) => Offset(r.dx * screenCadScale, r.dy * screenCadScale))
          .toList();
    }
    return null;
  }

  StructuralGridAxis? _findProjectAxis(StructuralGridAxis axis) =>
      _project.effectiveGridAxes.where((a)=>a.id==axis.id).firstOrNull ??
      _project.effectiveGridAxes.where((a)=>ProjectGridAxes.sameAlignment(a,axis,_cadUnitsPerMeter)).firstOrNull;

  void _updateProjectGridAxes(List<StructuralGridAxis> newAxes) {
    if (widget.bimContext != null) {
      final ids=_project.effectiveGridAxes.map((a)=>a.id).toSet();
      newAxes=[for(final a in newAxes) ids.contains(a.id) ? a : a.copyWith(sourceStoreyIds:[_project.activeStorey.id])];
    }
    final previous={for(final a in _project.effectiveGridAxes) a.id:a};
    final changed=newAxes.where((a)=>previous[a.id]==null || previous[a.id]!.start!=a.start || previous[a.id]!.end!=a.end);
    if (changed.any((axis)=>newAxes.any((a)=>a.id!=axis.id && ProjectGridAxes.sameAlignment(a,axis,_cadUnitsPerMeter)))) {
      newAxes=ProjectGridAxes.merge(newAxes,_cadUnitsPerMeter,
        isBulgarian:Localizations.localeOf(context).languageCode=='bg');
    }
    setState(() {
      _project = _project.copyWithGridAxes(newAxes);
      if (_selectedGridAxis!=null) _selectedGridAxis=_findProjectAxis(_selectedGridAxis!);
    });
    _saveProject();
  }

  void _deleteSelectedGridAxis() {
    if (_selectedGridAxis == null) return;
    _pushUndo();
    final remaining = _project.effectiveGridAxes.where((a) => a.id != _selectedGridAxis!.id).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updated = resequenceGridAxes(remaining, isBulgarian: isBg);
    _updateProjectGridAxes(updated);
    setState(() => _selectedGridAxis = null);
    HapticFeedback.heavyImpact();
  }

  void _renameSelectedGridAxis() {
    if (_selectedGridAxis == null) return;
    var nextName = _getNextAxisName(_selectedGridAxis!.name);
    final used=_project.effectiveGridAxes.where((a)=>a.id!=_selectedGridAxis!.id).map((a)=>a.name).toSet();
    while (used.contains(nextName)) { nextName=_getNextAxisName(nextName); }
    _pushUndo();
    final updated = _selectedGridAxis!.copyWith(name: nextName);
    final axes = _project.effectiveGridAxes.map((a) => a.id == updated.id ? updated : a).toList();
    _updateProjectGridAxes(axes);
    setState(() => _selectedGridAxis = updated);
    HapticFeedback.selectionClick();
  }

  String _getNextAxisName(String current) => BimAxisNaming.getNextAxisName(
    current, Localizations.localeOf(context).languageCode == 'bg');
  String _getSuggestedAxisName(Offset start, Offset end) => BimAxisNaming.getSuggestedAxisName(
    start, end, _project.effectiveGridAxes, Localizations.localeOf(context).languageCode == 'bg');

  Offset _computeAxisOffsetVector(StructuralGridAxis axis, double distanceMeters, double directionSign) {
    return BimAxisOperations.offsetVector(axis, distanceMeters * _cadUnitsPerMeter, directionSign);
  }

  void _updateAxisOffsetDrag(Offset screenPos) {
    if (!_isOffsettingAxisWithDrag || _axisBeingOffset == null) return;
    final cadPt = _screenToCad(screenPos);
    final axis = _axisBeingOffset!;
    final newSign = BimAxisOperations.offsetSign(axis, cadPt, previous: _currentOffsetSign);

    if (newSign != _currentOffsetSign) {
      setState(() {
        _currentOffsetSign = newSign;
      });
      HapticFeedback.selectionClick();
    }
  }

  StructuralGridAxis? _getAxisOffsetPreview() {
    if (!_isOffsettingAxisWithDrag || _axisBeingOffset == null) return null;
    final axis = _axisBeingOffset!;
    final offsetVec = _computeAxisOffsetVector(axis, _axisOffsetDistanceMeters, _currentOffsetSign);
    return axis.copyWith(id: 'preview_offset', name: _getNextAxisName(axis.name),
      start: axis.start + offsetVec, end: axis.end + offsetVec);
  }

  void _startAxisOffsetDragMode(StructuralGridAxis axis, double distanceMeters) {
    setState(() {
      _isOffsettingAxisWithDrag = true;
      _axisBeingOffset = axis;
      _axisOffsetDistanceMeters = distanceMeters;
      _currentOffsetSign = 1.0;
    });
  }

  void _applyAxisOffset(StructuralGridAxis originalAxis, double distanceMeters, double directionSign) {
    _axisOffsetDistanceMeters = distanceMeters;
    final offsetVec = _computeAxisOffsetVector(originalAxis, distanceMeters, directionSign);
    final nextName = _getNextAxisName(originalAxis.name);
    final newAxis = originalAxis.copyWith(id: 'axis_${DateTime.now().microsecondsSinceEpoch}',
      name: nextName, start: originalAxis.start + offsetVec, end: originalAxis.end + offsetVec);

    _pushUndo();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedAxes = resequenceGridAxes([..._project.effectiveGridAxes, newAxis], isBulgarian: isBg);
    _updateProjectGridAxes(updatedAxes);

    setState(() {
      _selectedGridAxis = _findProjectAxis(newAxis);
      _isOffsettingAxisWithDrag = false;
      _axisBeingOffset = null;
    });
    HapticFeedback.mediumImpact();

    // Ask user whether to delete previous axis
    _promptDeletePreviousAxis(originalAxis);
  }

  void _promptDeletePreviousAxis(StructuralGridAxis previousAxis) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.offsetCreatedTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          context.l10n.deletePreviousAxisPrompt(previousAxis.name),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.keepBoth, style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deletePrevious, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((deletePrev) {
      if (deletePrev == true) {
        _deleteSpecificGridAxis(previousAxis.id);
      }
    });
  }

  void _deleteSpecificGridAxis(String axisId) {
    _pushUndo();
    final remaining = _project.effectiveGridAxes.where((a) => a.id != axisId).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updated = resequenceGridAxes(remaining, isBulgarian: isBg);
    _updateProjectGridAxes(updated);
    setState(() {
      if (_selectedGridAxis?.id == axisId) {
        _selectedGridAxis = null;
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _showGridAxisOffsetDialog() async {
    final element = _selectedGridAxis;
    if (element == null) return;
    final distance = await showStructuralOffsetDialog(context, centimeters: false);
    if (!mounted || distance == null) return;
    _startAxisOffsetDragMode(element, distance);
  }

  String _getNextColumnName(String baseName) {
    final active = _project.activeStorey;
    final existingNames = active.columns.map((c) => c.displayName.trim()).toSet();
    final match = RegExp(r'^([^\d]*)(\d+)$').firstMatch(baseName.trim());

    if (match != null) {
      final prefix = match.group(1) ?? 'К';
      int num = int.tryParse(match.group(2) ?? '1') ?? 1;
      while (true) {
        num++;
        final candidate = '$prefix$num';
        if (!existingNames.contains(candidate)) {
          return candidate;
        }
      }
    } else {
      int maxNum = active.columns.length;
      for (final c in active.columns) {
        final m = RegExp(r'\d+').firstMatch(c.displayName);
        if (m != null) {
          final n = int.tryParse(m.group(0)!);
          if (n != null && n > maxNum) maxNum = n;
        }
      }
      return 'К${maxNum + 1}';
    }
  }

  void _startColumnOffsetDragMode(StructuralColumn col, double distanceMeters) {
    setState(() {
      _isOffsettingColumnWithDrag = true;
      _columnBeingOffset = col;
      _columnOffsetDistanceMeters = distanceMeters;
      _columnOffsetDirection = const Offset(1, 0);
    });
  }

  void _updateColumnOffsetDrag(Offset screenPos) {
    if (!_isOffsettingColumnWithDrag || _columnBeingOffset == null) return;
    final cadPt = _screenToCad(screenPos);
    final col = _columnBeingOffset!;
    final delta = cadPt - col.center;

    final Offset newDir;
    if (delta.dx.abs() >= delta.dy.abs()) {
      newDir = delta.dx >= 0 ? const Offset(1, 0) : const Offset(-1, 0);
    } else {
      newDir = delta.dy >= 0 ? const Offset(0, 1) : const Offset(0, -1);
    }

    if (newDir != _columnOffsetDirection) {
      setState(() {
        _columnOffsetDirection = newDir;
      });
      HapticFeedback.selectionClick();
    }
  }

  StructuralColumn? _getColumnOffsetPreview() {
    if (!_isOffsettingColumnWithDrag || _columnBeingOffset == null) return null;
    final col = _columnBeingOffset!;
    final distCad = _columnOffsetDistanceMeters * _cadUnitsPerMeter;
    final offsetVec = _columnOffsetDirection * distCad;
    return col.copyWith(
      id: 'preview_offset_col',
      name: _getNextColumnName(col.displayName),
      center: col.center + offsetVec,
    );
  }

  void _applyColumnOffset(StructuralColumn originalCol, double distanceMeters, Offset direction) {
    _columnOffsetDistanceMeters = distanceMeters;
    final distCad = distanceMeters * _cadUnitsPerMeter;
    final dirLen = direction.distance;
    final normDir = dirLen > 1e-4 ? direction / dirLen : const Offset(1, 0);
    final offsetVec = normDir * distCad;

    final nextName = _getNextColumnName(originalCol.displayName);
    final newCol = originalCol.copyWith(
      id: 'col_${DateTime.now().millisecondsSinceEpoch}',
      name: nextName,
      center: originalCol.center + offsetVec,
    );

    _pushUndo();
    final active = _project.activeStorey;
    final updatedColumns = List<StructuralColumn>.from(active.columns)..add(newCol);
    _updateActiveStorey(active.copyWith(columns: updatedColumns));

    setState(() {
      _selectedColumn = newCol;
      _isOffsettingColumnWithDrag = false;
      _columnBeingOffset = null;
    });
    HapticFeedback.mediumImpact();

    _promptDeletePreviousColumn(originalCol);
  }

  void _promptDeletePreviousColumn(StructuralColumn previousCol) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF00E5FF), size: 20),
            const SizedBox(width: 8),
            Text(context.l10n.offsetCreatedTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          context.l10n.deletePreviousColumnPrompt(previousCol.displayName),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.keepBoth, style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deletePrevious, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((deletePrev) {
      if (deletePrev == true) {
        _deleteSpecificColumn(previousCol.id);
      }
    });
  }

  void _deleteSpecificColumn(String colId) {
    _pushUndo();
    final active = _project.activeStorey;
    final deleted = active.columns.where((c) => c.id == colId).firstOrNull;
    final remainingCols = active.columns.where((c) => c.id != colId).toList();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedCols = deleted != null
        ? renumberColumnsAfterDeletion(remainingCols, deleted, defaultPrefix: isBg ? 'К' : 'C')
        : remainingCols;
    _updateActiveStorey(active.copyWith(columns: updatedCols));
    setState(() {
      if (_selectedColumn?.id == colId) {
        _selectedColumn = null;
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _showColumnOffsetDialog() async {
    final element = _selectedColumn;
    if (element == null) return;
    final distance = await showStructuralOffsetDialog(context, centimeters: true);
    if (!mounted || distance == null) return;
    _startColumnOffsetDragMode(element, distance);
  }

  void _showCustomColumnDialog() {
    final double widthCm = (_currentColumnPreset.width * 100).roundToDouble();
    final double heightCm = (_currentColumnPreset.height * 100).roundToDouble();
    ColumnShape shape = _currentColumnPreset.shape;
    final wCtrl = TextEditingController(text: widthCm.toInt().toString());
    final hCtrl = TextEditingController(text: heightCm.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text(context.l10n.columnDimensionsTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: wCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: context.l10n.widthCm,
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixText: 'cm',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: hCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: context.l10n.heightCm,
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixText: 'cm',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<ColumnShape>(
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white,
                  selectedForegroundColor: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF282B34),
                  selectedBackgroundColor: const Color(0x3300E5FF),
                  side: const BorderSide(color: Colors.white30),
                ),
                segments: [
                  ButtonSegment(value: ColumnShape.rectangular, label: Text(context.l10n.shapeRectangular, style: const TextStyle(fontSize: 11))),
                  ButtonSegment(value: ColumnShape.circular, label: Text(context.l10n.shapeCircular, style: const TextStyle(fontSize: 11))),
                  ButtonSegment(value: ColumnShape.lShape, label: Text(context.l10n.shapeLShape, style: const TextStyle(fontSize: 11))),
                ],
                selected: {shape},
                onSelectionChanged: (val) => setDlgState(() => shape = val.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final w = (double.tryParse(wCtrl.text) ?? 25.0) / 100.0;
                final h = (double.tryParse(hCtrl.text) ?? 25.0) / 100.0;
                setState(() {
                  _currentColumnPreset = _currentColumnPreset.copyWith(
                    shape: shape,
                    width: w.clamp(0.15, 3.0),
                    height: (shape == ColumnShape.circular ? w : h).clamp(0.15, 3.0),
                  );
                });
                Navigator.of(ctx).pop();
              },
              child: Text(context.l10n.applyAction),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomWallDialog() {
    final lCtrl = TextEditingController(text: (_currentWallLength * 100).toInt().toString());
    final tCtrl = TextEditingController(text: (_currentWallThickness * 100).toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(context.l10n.customWallDimensions, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.l10n.propLengthL,
                labelStyle: const TextStyle(color: Colors.white70),
                suffixText: 'cm',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.l10n.thicknessCm,
                labelStyle: const TextStyle(color: Colors.white70),
                suffixText: 'cm',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              final l = (double.tryParse(lCtrl.text) ?? 150.0) / 100.0;
              final t = (double.tryParse(tCtrl.text) ?? 25.0) / 100.0;
              setState(() {
                _currentWallLength = l.clamp(0.40, 20.0);
                _currentWallThickness = t.clamp(0.10, 1.50);
              });
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.applyAction),
          ),
        ],
      ),
    );
  }

  void _showCustomBeamDialog() {
    final wCtrl = TextEditingController(text: (_currentBeamWidth * 100).toInt().toString());
    final dCtrl = TextEditingController(text: (_currentBeamDepth * 100).toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(context.l10n.beamDimensionsTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: wCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: context.l10n.widthBCm,
                  labelStyle: const TextStyle(color: Colors.white70),
                  suffixText: 'cm',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: dCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: context.l10n.depthHCm,
                  labelStyle: const TextStyle(color: Colors.white70),
                  suffixText: 'cm',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              final w = (double.tryParse(wCtrl.text) ?? 25.0) / 100.0;
              final d = (double.tryParse(dCtrl.text) ?? 50.0) / 100.0;
              setState(() {
                _currentBeamWidth = w.clamp(0.15, 2.0);
                _currentBeamDepth = d.clamp(0.20, 3.0);
              });
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.applyAction),
          ),
        ],
      ),
    );
  }

  void _showCustomSlabDialog() {
    if (_editingSlab != null) { _editCeilingSlabLevel(); return; }
    final double initialThickness = _editingSlab?.thickness ?? _currentSlabThickness;
    final tCtrl = TextEditingController(text: (initialThickness * 100).toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(context.l10n.slabThicknessTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: tCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: context.l10n.slabThicknessHCm,
            labelStyle: const TextStyle(color: Colors.white70),
            suffixText: 'cm',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              final t = (double.tryParse(tCtrl.text) ?? 20.0) / 100.0;
              final clamped = t.clamp(0.08, 1.0);
              setState(() {
                _currentSlabThickness = clamped;
                if (_editingSlab != null) {
                  _pushSlabCorrectionUndo();
                  _editingSlab = _editingSlab!.copyWith(thickness: clamped);
                  _updateActiveStoreySlab(_editingSlab!);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.applyAction),
          ),
        ],
      ),
    );
  }

  Future<void> _editCeilingSlabLevel() async {
    final slab = _editingSlab;
    if (slab == null) return;
    final ownerId = _project.activeStorey.id;
    final changed = await showDialog<StructuralSlab>(context: context,
      builder: (_) => SlabLevelDialog(storey: _project.activeStorey, slab: slab));
    if (!mounted || changed == null || _project.activeStorey.id != ownerId ||
        _editingSlab?.id != slab.id) {
      return;
    }
    _pushSlabCorrectionUndo();
    setState(() {
      _editingSlab = changed;
      _currentSlabThickness = changed.thickness;
      _updateActiveStoreySlab(changed);
    });
  }

  Future<void> _editSlabEdgeOffset() async {
    final slab = _editingSlab;
    if (slab == null) return;
    final ownerId = _project.activeStorey.id;
    final updated = await showDialog<List<StructuralSlab>>(
      context: context,
      builder: (_) => SlabEdgeOffsetDialog(
        slabs: _project.activeStorey.slabs, slab: slab,
        scale: _cadUnitsPerMeter, initialEdge: _selectedSlabVertexIndex ?? 0),
    );
    if (!mounted || updated == null || _project.activeStorey.id != ownerId ||
        _editingSlab?.id != slab.id) {
      return;
    }
    _pushSlabCorrectionUndo();
    setState(() {
      _editingSlab = updated.firstWhere((s) => s.id == slab.id);
      _updateActiveStorey(_project.activeStorey.copyWith(slabs: updated));
    });
  }

  void _showCustomAxisDialog() {
    final nameCtrl = TextEditingController(text: _currentAxisName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(context.l10n.axisNameTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: context.l10n.axisNameLabel,
            labelStyle: const TextStyle(color: Colors.white70),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              final text = nameCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() => _currentAxisName = text);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  (Offset, Offset)? _findClosestSegmentInCad(Offset cadPt, double toleranceCad) {
    double minDistance = toleranceCad;
    (Offset, Offset)? bestSeg;

    void checkSegment(Offset p1, Offset p2) {
      final closest = BimLineGeometry.closest(cadPt, p1, p2);
      final d = (cadPt - closest).distance;
      if (d < minDistance) {
        minDistance = d;
        bestSeg = (p1, p2);
      }
    }

    for (final w in _project.activeStorey.shearWalls) {
      final poly = w.polygonVertices;
      if (poly.length >= 4) {
        checkSegment(poly[0], poly[1]);
        checkSegment(poly[3], poly[2]);
      }
    }

    final entities = _document.layoutEntities['Model'] ?? _document.entities;
    for (final entity in entities) {
      final layer = _document.layers[entity.layer];
      if (layer != null && !layer.isVisible) continue;
      if (entity is DxfLine) {
        checkSegment(entity.p1, entity.p2);
      } else if (entity is DxfLwPolyline) {
        final v = entity.vertices;
        for (int i = 0; i < v.length; i++) {
          if (i + 1 < v.length || entity.isClosed) {
            checkSegment(v[i].offset, v[(i + 1) % v.length].offset);
          }
        }
      } else if (entity is DxfPolyline) {
        final v = entity.vertices;
        for (int i = 0; i < v.length; i++) {
          if (i + 1 < v.length || entity.isClosed) {
            checkSegment(v[i].offset, v[(i + 1) % v.length].offset);
          }
        }
      } else if (entity is DxfInsert) {
        final block = _document.blocks[entity.blockName];
        if (block != null && block.entities.isNotEmpty) {
          final rad = entity.rotationDeg * math.pi / 180.0;
          final cosA = math.cos(rad);
          final sinA = math.sin(rad);
          final bx = block.basePoint.dx;
          final by = block.basePoint.dy;

          Offset transformPt(Offset pt) {
            final lx = (pt.dx - bx) * entity.scaleX;
            final ly = (pt.dy - by) * entity.scaleY;
            final rx = lx * cosA - ly * sinA;
            final ry = lx * sinA + ly * cosA;
            return Offset(entity.insertPoint.dx + rx, entity.insertPoint.dy + ry);
          }

          for (final child in block.entities) {
            final childLayer = _document.layers[child.layer];
            if (childLayer != null && !childLayer.isVisible) continue;
            if (child is DxfLine) {
              checkSegment(transformPt(child.p1), transformPt(child.p2));
            } else if (child is DxfLwPolyline) {
              final v = child.vertices;
              for (int i = 0; i < v.length; i++) {
                if (i + 1 < v.length || child.isClosed) {
                  checkSegment(transformPt(v[i].offset), transformPt(v[(i + 1) % v.length].offset));
                }
              }
            }
          }
        }
      }
    }

    return bestSeg;
  }

  void _deleteSelectedSlabVertex() {
    if (_editingSlab == null) return;
    final vIdx = _selectedSlabVertexIndex;
    if (vIdx == null || vIdx >= _editingSlab!.polygon.length) return;
    if (_editingSlab!.polygon.length <= 3) {
      HapticFeedback.vibrate();
      return;
    }
    _pushSlabCorrectionUndo();
    final updated = _editingSlab!.removeVertex(vIdx);
    if (updated != null) {
      final cleaned = _cleanSlabPolygon(updated);
      _editingSlab = cleaned;
      _updateActiveStoreySlab(cleaned);
      _selectedSlabVertexIndex = null;
      HapticFeedback.heavyImpact();
    }
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
    final ownerId = _slabBadgeOwnerId;
    _slabBadgeOwnerId = null;
    setState(() {
      if (ownerId != null) {
        final index = _project.storeys.indexWhere((s) => s.id == ownerId);
        if (index >= 0 && index != _project.activeStoreyIndex) {
          _project = _project.copyWith(activeStoreyIndex:index);

          _selectedBeam = null; _selectedGridAxis = null; _selectedOpening = null;
          _originalLayerVisibility.clear();
          for (final entry in _document.layers.entries) {
            _originalLayerVisibility[entry.key] = entry.value.isVisible;
          }
          if (_underlayFilterActive) _applyUnderlayFilter(true);
          _runAnalysis();
        }
      }
      _selectedColumn = null;
      _isMovingColumn = false;
      _selectedShearWall = null;
      _isMovingShearWall = false;
      _isPlacingWithHold = false;
      _wallStartCad = null;
      _slabStartCornerCad = null;
      _slabPointsCad.clear();
      _openingPointsCad.clear();
      _editingSlab = slab;
      _initialSlabBeforeCorrection = slab;
      _initialSlabCorrectionProject = _project;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _activeMagneticGuides = [];
      _midpointTouchDownPos = null;
    });
    HapticFeedback.selectionClick();
  }

  void _pushSlabCorrectionUndo() {
    if (_editingSlab == null) return;
    _slabCorrectionUndoStack.add(List.of(_project.activeStorey.slabs));
    if (_slabCorrectionUndoStack.length > 25) {
      _slabCorrectionUndoStack.removeAt(0);
    }
  }

  void _undoSlabCorrection() {
    if (_slabCorrectionUndoStack.isNotEmpty) {
      setState(() {
        final slabs = _slabCorrectionUndoStack.removeLast();
        _editingSlab = slabs.firstWhere((s) => s.id == _editingSlab!.id);
        _updateActiveStorey(_project.activeStorey.copyWith(slabs: slabs));
      });
      HapticFeedback.lightImpact();
    }
  }

  bool _updateActiveStoreySlab(StructuralSlab slab) {
    final active = _project.activeStorey;
    if (!SlabEditValidation.accepts(active.slabs, slab, _cadUnitsPerMeter)) {
      if (_editingSlab?.id == slab.id) {
        _editingSlab = active.slabs.firstWhere((s) => s.id == slab.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.slabEdgeInvalid)));
      return false;
    }
    final updatedSlabs =
        active.slabs.map((s) => s.id == slab.id ? slab : s).toList();
    _updateActiveStorey(active.copyWith(slabs: updatedSlabs));
    return true;
  }

  void _cancelSlabCorrection() {
    if (_initialSlabBeforeCorrection != null && _initialSlabCorrectionProject != null) {
      _updateActiveStorey(_project.activeStorey.copyWith(
        slabs: _initialSlabCorrectionProject!.activeStorey.slabs));
    }
    setState(() {
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _activeMagneticGuides = [];
      _midpointTouchDownPos = null;
    });
    HapticFeedback.selectionClick();
  }

  void _saveSlabCorrection() {
    if (_editingSlab == null) return;
    _history.checkpoint(_initialSlabCorrectionProject ?? _project);
    if (!_updateActiveStoreySlab(_editingSlab!)) return;
    setState(() {
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _slabCorrectionUndoStack.clear();
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _activeMagneticGuides = [];
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
      _activeMagneticGuides = [];
      _midpointTouchDownPos = null;
    });
    HapticFeedback.heavyImpact();
  }

  StructuralSlab _cleanSlabPolygon(StructuralSlab slab) {
    if (slab.polygon.length <= 3) return slab;
    final minDistanceCad = 0.005 * _cadUnitsPerMeter;
    final cleaned = StructuralSlab.cleanPolygon(slab.polygon, minDistance: minDistanceCad);
    return slab.copyWith(polygon: cleaned);
  }

  double _slabSnapTolerance({bool merge = false}) => SlabVertexSnap.tolerance(
    _getCadFitScale() * _transformController.value.getMaxScaleOnAxis(),
    _cadUnitsPerMeter,
    isMouse: _activePointerKind == PointerDeviceKind.mouse, merge: merge);

  DxfSnapResult? _snapSlabPoint(Offset raw, {Offset? previous,
      Offset? incomingDirection, String? excludedSlabId, int? excludedVertex}) {
    _activeMagneticGuides = [];
    if (!_snapEnabled) return null;
    final tolerance = _slabSnapTolerance();
    final candidates = <DxfSnapResult>[];
    final cad = DxfSnapHelper.findSnapPoint(document: _document,
      cadPoint: raw, toleranceCad: tolerance, basePoint: previous,
      includeIntersections: true);
    if (cad != null) candidates.add(cad);
    final edges = <(Offset, Offset)>[
      ...DxfSegmentSnap.nearby(document: _document, point: raw,
          radius: math.max(.30 * _cadUnitsPerMeter, tolerance * 3), continuousOnly: true),
      if (previous != null) ...DxfSegmentSnap.nearby(document: _document, point: previous,
          radius: math.max(.30 * _cadUnitsPerMeter, tolerance * 3), continuousOnly: true),
    ];
    for (final slab in _project.activeStorey.slabs) {
      for (var i = 0; i < slab.polygon.length; i++) {
        final a = slab.polygon[i], b = slab.polygon[(i + 1) % slab.polygon.length];
        if (slab.id == excludedSlabId && i == excludedVertex) { continue; }
        final distance = (raw - a).distance;
        if (distance <= tolerance) { candidates.add(DxfSnapResult(
          point: a, type: DxfSnapType.endpoint, distance: distance)); }
        if (slab.id == excludedSlabId &&
            (i + 1) % slab.polygon.length == excludedVertex) { continue; }
        edges.add((a, b));
        final point = BimLineGeometry.closest(raw, a, b);
        if ((raw - point).distance <= tolerance) { candidates.add(DxfSnapResult(
          point: point, type: DxfSnapType.nearest, distance: (raw - point).distance)); }
      }
    }
    final structural = _findStructuralSnap(raw, tolerance,
        excludedSlabId: excludedSlabId);
    if (structural != null) { candidates.add(structural); }
    final alignment = previous == null ? null : SlabVertexSnap.align(
      raw: raw, previous: previous, edges: edges, tolerance: tolerance,
      incomingDirection: incomingDirection);
    // Preserve exact corners; perpendicular alignment beats nearest-edge snapping.
    final exact = candidates.where((c) => c.type == DxfSnapType.endpoint || c.type == DxfSnapType.intersection).toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    if (exact.isNotEmpty) {
      if (previous != null) _activeMagneticGuides = [(previous, exact.first.point)];
      return exact.first;
    }
    if (alignment?.snap != null) {
      _activeMagneticGuides = alignment!.guides;
      return alignment.snap;
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final result = candidates.firstOrNull;
    if (previous != null && result != null) _activeMagneticGuides = [(previous, result.point)];
    return result;
  }

  DxfSnapResult? _snapOpeningPoint(Offset raw) {
    if (_snapEnabled && _openingPointsCad.length >= 3 &&
        (raw-_openingPointsCad.first).distance <= _slabSnapTolerance()) {
      _activeMagneticGuides = [(_openingPointsCad.last, _openingPointsCad.first)];
      return DxfSnapResult(point: _openingPointsCad.first,
        type: DxfSnapType.endpoint, distance: (raw-_openingPointsCad.first).distance);
    }
    return _snapSlabPoint(raw, previous: _openingPointsCad.lastOrNull,
      incomingDirection: _openingPointsCad.length >= 2
          ? _openingPointsCad.last - _openingPointsCad[_openingPointsCad.length-2] : null);
  }

  void _commitOpeningTap(Offset localPosition) {
    // A quick touch tap uses its own location, never a stale held-pointer tip.
    final raw = _screenToCad(localPosition);
    final point = _snapOpeningPoint(raw)?.point ?? raw;
    _currentCadCoord = point;
    _commitPlacement(point);
  }

  void _updateSlabVertexDrag(Offset screenPos) {
    if (_editingSlab == null || _draggingSlabVertexIndex == null) return;

    final bool isMouse = _activePointerKind == PointerDeviceKind.mouse;
    final double offsetAboveFinger = isMouse ? 0.0 : 64.0;
    final targetScreenPos = isMouse ? screenPos : (screenPos - Offset(0, offsetAboveFinger));

    final rawCad = _screenToCad(targetScreenPos);
    final polygon = _editingSlab!.polygon;
    final count = polygon.length;
    final idx = _draggingSlabVertexIndex!;
    final previous = polygon[(idx - 1 + count) % count];
    DxfSnapResult? snap = _snapSlabPoint(rawCad, previous: previous,
      incomingDirection: previous - polygon[(idx - 2 + count) % count],
      excludedSlabId: _editingSlab!.id, excludedVertex: idx);
    Offset effectiveCad = snap?.point ?? rawCad;
    final bestCandidate = _snapEnabled ? SlabVertexSnap.mergeCandidate(
      rawCad, polygon, idx, _slabSnapTolerance(merge: true)) : null;
    if (bestCandidate == null && snap != null && polygon.asMap().entries.any(
        (e) => e.key != idx && (e.value - snap!.point).distance < 1e-8)) {
      snap = null;
      effectiveCad = rawCad;
      _activeMagneticGuides = [];
    }

    if (bestCandidate != null) {
      effectiveCad = polygon[bestCandidate];
      snap = DxfSnapResult(point: effectiveCad, type: DxfSnapType.endpoint, distance: 0);
    }

    if (bestCandidate != _mergeCandidateSlabVertexIndex) {
      HapticFeedback.selectionClick();
    }

    _previewContourVertex(_slabVertexEditor, _editingSlab!.id, _editingSlab!.polygon,
      idx, rawCad, effectiveCad, snap);
    final snappedScreen = snap != null ? _cadToScreen(effectiveCad) : null;

    setState(() {
      _touchScreenPos = screenPos;
      _targetScreenPos = targetScreenPos;
      _snappedScreenPos = snappedScreen;
      _snappedScreenPositions = snappedScreen != null ? [snappedScreen] : [];
      _activeSnap = snap;
      _currentCadCoord = effectiveCad;
      _draggingSlabVertexCad = effectiveCad;
      _mergeCandidateSlabVertexIndex = bestCandidate;
    });
  }

  void _updateOpeningVertexDrag(Offset screenPos) {
    if (_selectedOpening == null || _draggingOpeningVertexIndex == null) return;
    final (slabId, opIdx) = _selectedOpening!;
    final active = _project.activeStorey;
    final slab = active.slabs.firstWhere((s) => s.id == slabId, orElse: () => active.slabs.first);
    if (opIdx >= slab.openings.length) return;
    final op = slab.openings[opIdx];
    final idx = _draggingOpeningVertexIndex!;

    final bool isMouse = _activePointerKind == PointerDeviceKind.mouse;
    final double offsetAboveFinger = isMouse ? 0.0 : 64.0;
    final targetScreenPos = isMouse ? screenPos : (screenPos - Offset(0, offsetAboveFinger));

    final rawCad = _screenToCad(targetScreenPos);
    final previous = op[(idx - 1 + op.length) % op.length];
    DxfSnapResult? snap = _snapSlabPoint(rawCad, previous: previous,
      incomingDirection: previous - op[(idx - 2 + op.length) % op.length]);
    Offset effectiveCad = snap?.point ?? rawCad;
    final bestCandidate = _snapEnabled ? SlabVertexSnap.mergeCandidate(
      rawCad, op, idx, _slabSnapTolerance(merge: true)) : null;

    if (bestCandidate != null) {
      effectiveCad = op[bestCandidate];
      snap = DxfSnapResult(point: effectiveCad, type: DxfSnapType.endpoint, distance: 0);
    }

    if (bestCandidate != _mergeCandidateOpeningVertexIndex) {
      HapticFeedback.selectionClick();
    }

    _previewContourVertex(_openingVertexEditor, '$slabId/$opIdx', op,
      idx, rawCad, effectiveCad, snap);
    final snappedScreen = snap != null ? _cadToScreen(effectiveCad) : null;

    setState(() {
      _touchScreenPos = screenPos;
      _targetScreenPos = targetScreenPos;
      _snappedScreenPos = snappedScreen;
      _snappedScreenPositions = snappedScreen != null ? [snappedScreen] : [];
      _activeSnap = snap;
      _currentCadCoord = effectiveCad;
      _draggingOpeningVertexCad = effectiveCad;
      _mergeCandidateOpeningVertexIndex = bestCandidate;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    _slabBadgeSelectionHandled = false;
    _activePointersCount = 1;
    _activePointerKind = event.kind;
    _isMultiTouchGesture = false;
    _placementPointerHandled = false;
    if (_duplicateDraft != null) {
      _placementPointerHandled = true;
      _duplicateSession!.grabAt(_screenToCad(event.localPosition) / _cadUnitsPerMeter);
      _updateDuplicateDrag(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse);
      return;
    }
    _elementGrabOffsetCad = null;
    if (_isOffsettingAxisWithDrag && _axisBeingOffset != null) {
      _placementPointerHandled = true;
      _updateAxisOffsetDrag(event.localPosition);
      return;
    }
    if (_isOffsettingColumnWithDrag && _columnBeingOffset != null) {
      _placementPointerHandled = true;
      _updateColumnOffsetDrag(event.localPosition);
      return;
    }

    if (_activeTool == StructuralDrawTool.measure) {
      // Touch stays available to the pan recognizer until a hold wins.
      if (event.kind == PointerDeviceKind.mouse) {
        _isPlacingWithHold = true;
        _updatePointer(event.localPosition, isMouse: true);
      } else {
        _measurementHeldGesture = false;

      }
      return;
    }

    // 1. If currently in Slab Correction Mode:
    if (_isEditingSlab) {
      // Check if tapped on a vertex handle of the editing slab
      final vIdx = _hitTestSlabVertex(event.localPosition, _editingSlab!);
      if (vIdx != null) {
        setState(() {
          _draggingSlabVertexIndex = vIdx;
          _draggingSlabVertexCad = _editingSlab!.polygon[vIdx];
          _mergeCandidateSlabVertexIndex = null;
          _activeMagneticGuides = [];
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

      // In select mode only: check if user tapped a column or shear wall to exit slab editing and switch to it
      if (_activeTool == StructuralDrawTool.select) {
        final hitCol = _hitTestColumn(event.localPosition);
        if (hitCol != null) {
          setState(() {
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _selectedColumn = hitCol;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedGridAxis = null;
            _isMovingColumn = true;
            _hasMovedSelectedColumn = false;
            _isPlacingWithHold = false;
            _activeTool = StructuralDrawTool.column;
          });
          _updatePointer(event.localPosition,
              isMouse: event.kind == PointerDeviceKind.mouse);
          HapticFeedback.selectionClick();
          return;
        }

        final hitWall = _hitTestShearWall(event.localPosition);
        if (hitWall != null) {
          setState(() {
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _selectedShearWall = hitWall;
            _selectedColumn = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedGridAxis = null;
            _isMovingShearWall = true;
            _hasMovedSelectedShearWall = false;
            _isPlacingWithHold = false;
            _activeTool = StructuralDrawTool.shearWall;
          });
          _updatePointer(event.localPosition,
              isMouse: event.kind == PointerDeviceKind.mouse);
          HapticFeedback.selectionClick();
          return;
        }
      }
    }

    // 1b. If an opening is selected: check if tapped on its vertex handle or midpoint grip
    if (_selectedOpening != null &&
        (_activeTool == StructuralDrawTool.slabOpening || _activeTool == StructuralDrawTool.select)) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
      if (slabIdx != -1) {
        final slab = active.slabs[slabIdx];
        if (opIdx < slab.openings.length) {
          final op = slab.openings[opIdx];

          // Check if tapped on a vertex handle of the selected opening
          final vIdx = _hitTestOpeningVertex(event.localPosition, op);
          if (vIdx != null) {
            setState(() {
              _selectedOpeningVertexIndex = vIdx;
              _draggingOpeningVertexIndex = vIdx;
              _draggingOpeningVertexCad = op[vIdx];
              _mergeCandidateOpeningVertexIndex = null;
              _activeMagneticGuides = [];
            });
            HapticFeedback.selectionClick();
            return;
          }

          // Check if touched on a midpoint grip of the selected opening
          final opGrip = _hitTestOpeningMidpoint(event.localPosition, slab, opIdx);
          if (opGrip != null) {
            setState(() {
              _activeOpeningGrip = opGrip;
              _midpointTouchDownPos = event.localPosition;
              _isExtrudingEdge = false;
              _extrusionDistanceCad = 0.0;
              _previewOpeningOffsetPolygon = null;
            });
            HapticFeedback.selectionClick();
            return;
          }
        }
      }
    }

    // 2. Check hit test on slab midpoint grips for edge extrusion or edit mode
    if (_activeTool == StructuralDrawTool.slab || _activeTool == StructuralDrawTool.select) {
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
    }

    // Grid Axis handle dragging check (works on selected or any existing grid axis)
    if (_activeTool == StructuralDrawTool.gridAxis || _activeTool == StructuralDrawTool.select) {
      final handle = _hitTestGridAxisHandle(event.localPosition);
      if (handle != null) {
        setState(() {
          _beginAxisHandle(handle.$1, handle.$2);
          _selectedColumn = null;
          _selectedShearWall = null;
          _selectedBeam = null;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }

    if (event.kind == PointerDeviceKind.mouse &&
        (_activeTool == StructuralDrawTool.gridAxis || _activeTool == StructuralDrawTool.select)) {
      final axis = _hitTestGridAxis(event.localPosition);
      if (axis != null) {
        setState(() => _beginAxisMove(axis, event.localPosition));
        return;
      }
    }

    // Grid axis offset drag mode check
    if (_isOffsettingAxisWithDrag && _axisBeingOffset != null) {
      _updateAxisOffsetDrag(event.localPosition);
      return;
    }

    // Column offset drag mode check
    if (_isOffsettingColumnWithDrag && _columnBeingOffset != null) {
      _updateColumnOffsetDrag(event.localPosition);
      return;
    }

    if (event.kind == PointerDeviceKind.mouse && (_activeTool == StructuralDrawTool.beam || _activeTool == StructuralDrawTool.select)) {
      final beam = _hitTestBeam(event.localPosition);
      if (beam != null) { setState(() => _beginBeamMove(beam, event.localPosition)); return; }
    }

    // 3. Selection / Moving taps scoped strictly to active tool
    if (_activeTool == StructuralDrawTool.column) {
      final hitCol = _hitTestColumn(event.localPosition);
      if (hitCol != null) {
        setState(() {
          _selectedColumn = hitCol;
          _selectedShearWall = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedGridAxis = null;
          _isMovingColumn = true;
          _hasMovedSelectedColumn = false;
          _isPlacingWithHold = false;
        });
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        HapticFeedback.selectionClick();
        return;
      }
    } else if (_activeTool == StructuralDrawTool.shearWall) {
      final hitWall = _hitTestShearWall(event.localPosition);
      if (hitWall != null) {
        setState(() {
          _selectedShearWall = hitWall;
          _selectedColumn = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedGridAxis = null;
          _isMovingShearWall = true;
          _hasMovedSelectedShearWall = false;
          _isPlacingWithHold = false;
        });
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        HapticFeedback.selectionClick();
        return;
      }
    } else if (_activeTool == StructuralDrawTool.slabOpening) {
      if (_openingPointsCad.isEmpty) {
        final hitOpening = _hitTestOpening(event.localPosition);
        if (hitOpening != null) {
          _startMovingOpening(hitOpening, event.localPosition,
              isMouse: event.kind == PointerDeviceKind.mouse);
          return;
        }
      }
    } else if (_activeTool == StructuralDrawTool.slab && !_isEditingSlab) {
      final hitSlab = _hitTestSlab(event.localPosition);
      if (hitSlab != null) {
        _startSlabCorrection(hitSlab);
        return;
      }
    } else if (_activeTool == StructuralDrawTool.select && !_isEditingSlab) {
      final hitCol = _hitTestColumn(event.localPosition);
      if (hitCol != null) {
        setState(() {
          _selectedColumn = hitCol;
          _selectedShearWall = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedGridAxis = null;
          _isMovingColumn = true;
          _hasMovedSelectedColumn = false;
          _isPlacingWithHold = false;
          _activeTool = StructuralDrawTool.column;
        });
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        HapticFeedback.selectionClick();
        return;
      }

      final hitWall = _hitTestShearWall(event.localPosition);
      if (hitWall != null) {
        setState(() {
          _selectedShearWall = hitWall;
          _selectedColumn = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedGridAxis = null;
          _isMovingShearWall = true;
          _hasMovedSelectedShearWall = false;
          _isPlacingWithHold = false;
          _activeTool = StructuralDrawTool.shearWall;
        });
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        HapticFeedback.selectionClick();
        return;
      }

      final hitOpening = _hitTestOpening(event.localPosition);
      if (hitOpening != null) {
        _activeTool = StructuralDrawTool.slabOpening;
        _startMovingOpening(hitOpening, event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
        return;
      }

      final hitSlab = _hitTestSlab(event.localPosition);
      if (hitSlab != null) {
        _activeTool = StructuralDrawTool.slab;
        _startSlabCorrection(hitSlab);
        return;
      }
    }

    // 4. If a column, shear wall or opening was already selected and user taps somewhere outside
    if (_selectedColumn != null && !_isMovingColumn) {
      final hit = _hitTestColumn(event.localPosition);
      if (hit == null) {
        setState(() {
          _selectedColumn = null;
        });
      }
    }
    if (_selectedShearWall != null && !_isMovingShearWall) {
      final hit = _hitTestShearWall(event.localPosition);
      if (hit == null) {
        setState(() {
          _selectedShearWall = null;
        });
      }
    }
    if (_selectedOpening != null && !_isMovingOpening) {
      final hit = _hitTestOpening(event.localPosition);
      if (hit == null) {
        setState(() {
          _selectedOpening = null;
          _selectedOpeningVertexIndex = null;
        });
      }
    }

    // 5. Mouse interactions
    if (event.kind == PointerDeviceKind.mouse) {
      if (_activeTool == StructuralDrawTool.column || _activeTool == StructuralDrawTool.select) {
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
      }
      if (_activeTool == StructuralDrawTool.shearWall || _activeTool == StructuralDrawTool.select) {
        final hitWall = _hitTestShearWall(event.localPosition);
        if (hitWall != null) {
          setState(() {
            _selectedShearWall = hitWall;
            _isMovingShearWall = true;
            _hasMovedSelectedShearWall = false;
            _isPlacingWithHold = false;
          });
          _updatePointer(event.localPosition, isMouse: true);
          HapticFeedback.selectionClick();
          return;
        }
      }
      if (_activeTool == StructuralDrawTool.slabOpening || _activeTool == StructuralDrawTool.select) {
        final hitOpening = _hitTestOpening(event.localPosition);
        if (hitOpening != null) {
          _startMovingOpening(hitOpening, event.localPosition, isMouse: true);
          return;
        }
      }
      if (_activeTool == StructuralDrawTool.slab || _activeTool == StructuralDrawTool.select) {
        final hitSlab = _hitTestSlab(event.localPosition);
        if (hitSlab != null) {
          _startSlabCorrection(hitSlab);
          return;
        }
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
    if (_beamMove != null) { _previewBeamMove(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse); return; }
    if (_duplicateDraft != null) {
      _updateDuplicateDrag(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse);
      return;
    }

    if (_activeTool == StructuralDrawTool.measure) {
      if (_isPlacingWithHold) {
        _updatePointer(event.localPosition,
            isMouse: event.kind == PointerDeviceKind.mouse);
      }
      return;
    }

    // Updating grid axis offset drag direction
    if (_isOffsettingAxisWithDrag && _axisBeingOffset != null) {
      _updateAxisOffsetDrag(event.localPosition);
      return;
    }

    // Updating column offset drag direction
    if (_isOffsettingColumnWithDrag && _columnBeingOffset != null) {
      _updateColumnOffsetDrag(event.localPosition);
      return;
    }

    // Dragging grid axis handle (extend/shorten along axis line, harmonizing all parallel axes)
    if (_isDraggingAxisHandle && _selectedGridAxis != null) {
      _previewAxisHandle(event.localPosition);
      return;
    }

    // A. Dragging slab vertex
    if (_draggingSlabVertexIndex != null) {
      _updateSlabVertexDrag(event.localPosition);
      return;
    }

    // A2. Dragging opening vertex
    if (_draggingOpeningVertexIndex != null && _selectedOpening != null) {
      _updateOpeningVertexDrag(event.localPosition);
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

    // B2. Opening midpoint grip dragging (parallel extrusion)
    if (_activeOpeningGrip != null && _selectedOpening != null) {
      if (!_isExtrudingEdge && _midpointTouchDownPos != null) {
        if ((event.localPosition - _midpointTouchDownPos!).distance > 8.0) {
          _isExtrudingEdge = true;
        }
      }
      if (_isExtrudingEdge) {
        _updateOpeningEdgeExtrusion(event.localPosition);
      }
      return;
    }

    // C. Moving column with mouse
    if (event.kind == PointerDeviceKind.mouse &&
        _isMovingColumn &&
        _selectedColumn != null) {
      _updatePointer(event.localPosition, isMouse: true);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedColumn!.center).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedColumn = true;
        }
      }
      return;
    }

    // C1b. Moving shear wall with mouse
    if (event.kind == PointerDeviceKind.mouse &&
        _isMovingShearWall &&
        _selectedShearWall != null) {
      _updatePointer(event.localPosition, isMouse: true);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedShearWall!.center).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedShearWall = true;
        }
      }
      return;
    }

    // C2. Moving opening with mouse
    if (event.kind == PointerDeviceKind.mouse &&
        _isMovingOpening &&
        _selectedOpening != null) {
      _updatePointer(event.localPosition, isMouse: true);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null && _movingOpeningOriginalCenter != null) {
        final dist = (effectiveCad - _movingOpeningOriginalCenter!).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedOpening = true;
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
    if (_activeGrip == null) return;
    final grip = _activeGrip!;
    final rawCad = _screenToCad(screenPos);
    final disp = rawCad - grip.midpoint;
    final rawD = disp.dx * grip.normal.dx + disp.dy * grip.normal.dy;

    final double toleranceCad = _slabSnapTolerance();

    SlabParallelAlignmentResult? parallelSnap;
    if (_snapEnabled) {
      parallelSnap = SlabParallelAlignmentHelper.findParallelEdgeAlignment(
        edgeV1: grip.v1,
        edgeV2: grip.v2,
        gripNormal: grip.normal,
        rawDistance: rawD,
        toleranceCad: toleranceCad,
        document: _document,
        activeStorey: _project.activeStorey,
        activeSlabId: _activeExtrudingSlabId,
        ghostStorey: _project.ghostStorey,
        cadUnitsPerMeter: _cadUnitsPerMeter,
      );
    }

    final double effectiveD;
    if (parallelSnap != null) {
      effectiveD = parallelSnap.distance;
      if (_activeParallelSnap == null || (_activeParallelSnap!.distance - effectiveD).abs() > 1e-3) {
        HapticFeedback.selectionClick();
      }
    } else {
      DxfSnapResult? ptSnap;
      if (_snapEnabled) {
        ptSnap = DxfSnapHelper.findSnapPoint(
          document: _document,
          cadPoint: rawCad,
          toleranceCad: toleranceCad,
        );
        ptSnap ??= _findStructuralSnap(rawCad, toleranceCad);
      }
      if (ptSnap != null) {
        final ptDisp = ptSnap.point - grip.midpoint;
        effectiveD = ptDisp.dx * grip.normal.dx + ptDisp.dy * grip.normal.dy;
      } else {
        effectiveD = rawD;
      }
    }

    // Compute live preview polygon with dynamicPullEdge (avoiding orphan points and artifacts)
    List<Offset>? previewPoly;
    final active = _project.activeStorey;
    final slabIdx = active.slabs.indexWhere((s) => s.id == _activeExtrudingSlabId);
    if (slabIdx != -1 && effectiveD.abs() > 1e-4) {
      final previewSlab = active.slabs[slabIdx].dynamicPullEdge(
        edgeIndex: grip.edgeIndex,
        distance: effectiveD,
        minDistanceCad: 0.005 * _cadUnitsPerMeter,
      );
      previewPoly = previewSlab.polygon;
    }

    setState(() {
      _extrusionDistanceCad = effectiveD;
      _activeParallelSnap = parallelSnap;
      _previewSlabOffsetPolygon = previewPoly;
    });
  }

  void _updateOpeningEdgeExtrusion(Offset screenPos) {
    if (_activeOpeningGrip == null || _selectedOpening == null) return;
    final (slabId, opIdx) = _selectedOpening!;
    final grip = _activeOpeningGrip!;
    final rawCad = _screenToCad(screenPos);
    final disp = rawCad - grip.midpoint;
    final rawD = disp.dx * grip.normal.dx + disp.dy * grip.normal.dy;

    final double toleranceCad = _slabSnapTolerance();

    double effectiveD = rawD;
    if (_snapEnabled) {
      final ptSnap = DxfSnapHelper.findSnapPoint(
        document: _document,
        cadPoint: rawCad,
        toleranceCad: toleranceCad,
      ) ?? _findStructuralSnap(rawCad, toleranceCad);
      if (ptSnap != null) {
        final ptDisp = ptSnap.point - grip.midpoint;
        effectiveD = ptDisp.dx * grip.normal.dx + ptDisp.dy * grip.normal.dy;
      }
    }

    List<Offset>? previewPoly;
    final active = _project.activeStorey;
    final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
    if (slabIdx != -1 && effectiveD.abs() > 1e-4) {
      final slab = active.slabs[slabIdx];
      if (opIdx < slab.openings.length) {
        final previewSlab = slab.dynamicPullOpeningEdge(
          openingIndex: opIdx,
          edgeIndex: grip.edgeIndex,
          distance: effectiveD,
          minDistanceCad: 0.005 * _cadUnitsPerMeter,
        );
        if (opIdx < previewSlab.openings.length) {
          previewPoly = previewSlab.openings[opIdx];
        }
      }
    }

    setState(() {
      _extrusionDistanceCad = effectiveD;
      _previewOpeningOffsetPolygon = previewPoly;
    });
  }

  void _updatePointer(Offset screenPos, {bool isMouse = false}) {
    if (_activeTool == StructuralDrawTool.measure) {
      _updateMeasurementPointer(screenPos, isMouse: isMouse);
      return;
    }
    final touchPos = screenPos;

    var targetPos = StructuralPointerInteraction.placementTarget(screenPos, isMouse: isMouse);
    var rawCad = _screenToCad(targetPos);
    final movingCenter = _isMovingColumn ? _selectedColumn?.center
        : _isMovingShearWall ? _selectedShearWall?.center
        : _isMovingOpening ? _movingOpeningOriginalCenter : null;
    if (movingCenter != null) {
      final pointerCad = _screenToCad(screenPos);
      _elementGrabOffsetCad ??= StructuralPointerInteraction.grabOffset(movingCenter, pointerCad);
      rawCad = StructuralPointerInteraction.dragTarget(pointerCad, _elementGrabOffsetCad!);
      targetPos = _cadToScreen(rawCad);
    }
    StructuralAxisLockMode effectiveLockMode = _axisLockMode;
    final anchor = _elementMoveOriginalCenter ?? _selectedColumn?.center ?? _selectedShearWall?.center;
    if (HardwareKeyboard.instance.isShiftPressed && anchor != null) {
      effectiveLockMode = (rawCad.dx-anchor.dx).abs() > (rawCad.dy-anchor.dy).abs()
          ? StructuralAxisLockMode.lockY : StructuralAxisLockMode.lockX;
    }
    if (anchor != null && (_isMovingColumn || _isMovingShearWall)) {
      if (effectiveLockMode == StructuralAxisLockMode.lockX) { rawCad = Offset(anchor.dx, rawCad.dy); }
      if (effectiveLockMode == StructuralAxisLockMode.lockY) { rawCad = Offset(rawCad.dx, anchor.dy); }
      targetPos = _cadToScreen(rawCad);
    }
    DxfSnapResult? snap;
    Offset? snappedScreen;
    Offset effectiveCad = rawCad;

    if (_snapEnabled) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final toleranceCad = StructuralPointerInteraction.snapToleranceCad(
        isMouse: isMouse,
        pixelsPerCadUnit: fitScale * currentScale.clamp(.001, 10000.0),
        cadUnitsPerMeter: _cadUnitsPerMeter);
      bool acceptsCandidate(Offset center) {
        if (!StructuralPointerInteraction.accepts(rawCad, center, toleranceCad)) { return false; }
        if (anchor != null && effectiveLockMode == StructuralAxisLockMode.lockX &&
            (center.dx-anchor.dx).abs()>1e-8*_cadUnitsPerMeter) { return false; }
        if (anchor != null && effectiveLockMode == StructuralAxisLockMode.lockY &&
            (center.dy-anchor.dy).abs()>1e-8*_cadUnitsPerMeter) { return false; }
        return true;
      }
      if (_activeTool == StructuralDrawTool.column || _isMovingColumn) {
        final colW = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.width
            : _currentColumnPreset.width * _cadUnitsPerMeter;
        final colH = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.height
            : _currentColumnPreset.height * _cadUnitsPerMeter;
        final colRot = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.rotationRad
            : _currentColumnPreset.rotationRad;
        final colShape = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.shape
            : _currentColumnPreset.shape;
        final colThick = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.thickness
            : _currentColumnPreset.thickness * _cadUnitsPerMeter;
        final colMirrored = (_isMovingColumn && _selectedColumn != null)
            ? _selectedColumn!.isMirrored
            : _currentColumnPreset.isMirrored;

        // 1. Column Corners Snapping (ъгли на колоната към крайни точки, ъгли и оси)
        final featureTolerance = toleranceCad * .65;
        final dummyCol = StructuralColumn(
          id: 'dummy_col',
          center: Offset.zero,
          shape: colShape,
          width: colW,
          height: colH,
          rotationRad: colRot,
          thickness: colThick,
          isMirrored: colMirrored,
        );
        final cornerOffsets = dummyCol.polygonVertices;

        DxfSnapResult? bestCornerSnap;
        Offset? bestCandidateCenter;
        double minCornerDist = featureTolerance;

        for (final cornerOffset in cornerOffsets) {
          final p = rawCad + cornerOffset;
          final s = _findStructuralSnap(p, featureTolerance) ??
              DxfSnapHelper.findSnapPoint(
                document: _document,
                cadPoint: p,
                toleranceCad: featureTolerance,
                allowNearest: false,
              );
          if (s != null) {
            final d = (p - s.point).distance;
            if (d < minCornerDist && acceptsCandidate(s.point - cornerOffset)) {
              minCornerDist = d;
              bestCornerSnap = s;
              bestCandidateCenter = s.point - cornerOffset;
            }
          }
        }

        final mag = StructuralMagneticAlignmentHelper.alignColumn(
          rawCenter: rawCad,
          columnWidth: colW,
          columnHeight: colH,
          columnRotationRad: colRot,
          toleranceCad: toleranceCad,
          activeStorey: _project.activeStorey,
          movingColumnId: _isMovingColumn ? _selectedColumn?.id : null,
          dxfDocument: _document,
          cadUnitsPerMeter: _cadUnitsPerMeter,
          axisLockMode: effectiveLockMode,
          anchorCenter: _elementMoveOriginalCenter ?? _selectedColumn?.center,
          maxCorrectionCad: toleranceCad,
        );
        if (bestCandidateCenter != null && (mag == null ||
            (bestCandidateCenter-rawCad).distance < (mag.snappedCenter-rawCad).distance - 1e-8)) {
          effectiveCad = bestCandidateCenter;
          snap = bestCornerSnap;
          snappedScreen = _cadToScreen(bestCornerSnap!.point);
          _snappedScreenPositions = [snappedScreen];
          _activeMagneticGuides = null;
          _liveDimensionText = null;
          _activeDynamicDimensionLine = null;
        } else {
          if (mag != null) {
            effectiveCad = mag.snappedCenter;
            snappedScreen = _cadToScreen(mag.markerPoint ?? effectiveCad);
            _snappedScreenPositions = [snappedScreen];
            _activeMagneticGuides = mag.guideLines;
            _liveDimensionText = mag.liveDimensionText;
            _activeDynamicDimensionLine = mag.dimensionLine;
          } else {
            snap = _findStructuralSnap(rawCad, toleranceCad) ??
                DxfSnapHelper.findSnapPoint(
                  document: _document,
                  cadPoint: rawCad,
                  toleranceCad: toleranceCad,
                  allowNearest: false,
                );
            if (snap != null) {
              effectiveCad = snap.point;
              snappedScreen = _cadToScreen(snap.point);
              _snappedScreenPositions = [snappedScreen];
            } else {
              effectiveCad = rawCad;
              _snappedScreenPositions = [];
            }
            _activeMagneticGuides = null;
            _liveDimensionText = null;
            _activeDynamicDimensionLine = null;
          }
        }
      } else if (_isMovingOpening) {
        // Multi-edge and multi-corner weighted snapping for openings (edges snap to axes/walls, corners to landmarks)
        final cornerOffsets = _movingOpeningRelativeOffsets ?? const <Offset>[];

        // Calculate edge midpoints for edge-to-axis snapping
        final List<Offset> edgeOffsets = [];
        final nCorners = cornerOffsets.length;
        if (nCorners >= 2) {
          for (int i = 0; i < nCorners; i++) {
            edgeOffsets.add((cornerOffsets[i] + cornerOffsets[(i + 1) % nCorners]) / 2.0);
          }
        }

        final candidateCenters = <Offset>{rawCad};
        final gridAxesList = _project.activeStorey.gridAxes;

        // 1. Corner-to-landmark & corner-to-intersection candidates
        for (final cornerOffset in cornerOffsets) {
          final p = rawCad + cornerOffset;
          final s = _findStructuralSnap(p, toleranceCad, cornersOnly: true) ??
              DxfSnapHelper.findSnapPoint(
                document: _document,
                cadPoint: p,
                toleranceCad: toleranceCad,
                allowNearest: false,
              );
          if (s != null) {
            candidateCenters.add(s.point - cornerOffset);
          }

          // Corner snaps directly to grid axis intersections
          for (int i = 0; i < gridAxesList.length; i++) {
            for (int j = i + 1; j < gridAxesList.length; j++) {
              final inter = gridAxesList[i].intersectionWith(gridAxesList[j]);
              if (inter != null && (p - inter).distance <= toleranceCad * 1.5) {
                candidateCenters.add(inter - cornerOffset);
              }
            }
          }
        }

        // 2. Edge-to-axis candidates (openings snap by their perimeter edges, NEVER their center)
        for (final edgeOffset in edgeOffsets) {
          final pEdge = rawCad + edgeOffset;
          for (final axis in gridAxesList) {
            final proj = axis.projectPoint(pEdge);
            if ((pEdge - proj).distance <= toleranceCad) {
              candidateCenters.add(proj - edgeOffset);
            }
          }
        }

        double bestScore = -1.0;
        Offset bestCenter = rawCad;
        List<Offset> bestSnappedScreenPts = [];
        List<DxfSnapResult> bestActiveSnaps = [];

        for (final candCenter in candidateCenters) {
          double candScore = 0.0;
          int endpointMatches = 0;
          final List<Offset> candScreens = [];
          final List<DxfSnapResult> candSnaps = [];

          // Score corner matches
          for (final cornerOffset in cornerOffsets) {
            final pt = candCenter + cornerOffset;
            final match = _findStructuralSnap(pt, toleranceCad * 0.8, cornersOnly: true) ??
                DxfSnapHelper.findSnapPoint(
                  document: _document,
                  cadPoint: pt,
                  toleranceCad: toleranceCad * 0.8,
                  allowNearest: false,
                );

            if (match != null) {
              if (match.type == DxfSnapType.endpoint) {
                candScore += 160.0;
                endpointMatches++;
              } else {
                candScore += 50.0;
              }
              candScreens.add(_cadToScreen(match.point));
              candSnaps.add(match);
            }

            for (int i = 0; i < gridAxesList.length; i++) {
              for (int j = i + 1; j < gridAxesList.length; j++) {
                final inter = gridAxesList[i].intersectionWith(gridAxesList[j]);
                if (inter != null && (pt - inter).distance < 1e-3) {
                  candScore += 500.0;
                  endpointMatches++;
                  candScreens.add(_cadToScreen(inter));
                  candSnaps.add(DxfSnapResult(point: inter, type: DxfSnapType.endpoint, distance: 0));
                  break;
                }
              }
            }
          }

          if (endpointMatches >= 2) {
            candScore += 1200.0 * endpointMatches;
          }

          // Score opening perimeter edges sitting on grid axes
          for (final edgeOffset in edgeOffsets) {
            final candEdge = candCenter + edgeOffset;
            for (final axis in gridAxesList) {
              final distToAxis = (candEdge - axis.projectPoint(candEdge)).distance;
              if (distToAxis < 1e-3) {
                candScore += 450.0;
                candScreens.add(_cadToScreen(candEdge));
                candSnaps.add(DxfSnapResult(point: candEdge, type: DxfSnapType.midpoint, distance: 0));
                break;
              }
            }
          }

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
          effectiveCad = bestCenter;
        } else {
          _snappedScreenPositions = [];
          effectiveCad = rawCad;
        }
        _liveDimensionText = null;
      } else if (_activeTool == StructuralDrawTool.slabOpening) {
        snap = _snapOpeningPoint(rawCad);
        effectiveCad = snap?.point ?? rawCad;
        snappedScreen = snap == null ? null : _cadToScreen(snap.point);
        _snappedScreenPositions = snappedScreen == null ? [] : [snappedScreen];
        _liveDimensionText = _openingPointsCad.isEmpty ? null
            : '${((effectiveCad-_openingPointsCad.last).distance/_cadUnitsPerMeter).toStringAsFixed(2)} m';
      } else if (_activeTool == StructuralDrawTool.shearWall || _isMovingShearWall) {
        final wallL = (_isMovingShearWall && _selectedShearWall != null)
            ? _selectedShearWall!.length
            : _currentWallLength * _cadUnitsPerMeter;
        final wallT = (_isMovingShearWall && _selectedShearWall != null)
            ? _selectedShearWall!.thickness
            : _currentWallThickness * _cadUnitsPerMeter;
        final wallRot = (_isMovingShearWall && _selectedShearWall != null)
            ? _selectedShearWall!.angleRad
            : _currentWallRotationRad;
        final wallRef = (_isMovingShearWall && _selectedShearWall != null)
            ? _selectedShearWall!.referenceLine
            : ShearWallReferenceLine.center;
        final wallFlipped = (_isMovingShearWall && _selectedShearWall != null)
            ? _selectedShearWall!.isFlipped
            : false;

        final u = Offset(math.cos(wallRot), math.sin(wallRot));
        final halfLen = wallL / 2.0;

        final dummyWall = StructuralShearWall(
          id: 'dummy_wall',
          start: -u * halfLen,
          end: u * halfLen,
          thickness: wallT,
          referenceLine: wallRef,
          isFlipped: wallFlipped,
        );

        // Feature points: endpoints (start, end) and 4 box corners
        final featureTolerance = toleranceCad * .65;
        final List<Offset> wallFeatureOffsets = [
          -u * halfLen, // Start endpoint (крайна точка начало)
          u * halfLen,  // End endpoint (крайна точка край)
          ...dummyWall.polygonVertices, // 4 corner vertices (ъгли)
        ];

        DxfSnapResult? bestWallSnap;
        Offset? bestWallCandCenter;
        double minWallSnapDist = featureTolerance;

        for (final featOffset in wallFeatureOffsets) {
          final p = rawCad + featOffset;
          final s = _findStructuralSnap(p, featureTolerance) ??
              DxfSnapHelper.findSnapPoint(
                document: _document,
                cadPoint: p,
                toleranceCad: featureTolerance,
                allowNearest: false,
              );
          if (s != null) {
            final dist = (p - s.point).distance;
            if (dist < minWallSnapDist && acceptsCandidate(s.point - featOffset)) {
              minWallSnapDist = dist;
              bestWallSnap = s;
              bestWallCandCenter = s.point - featOffset;
            }
          }
        }

        final mag = StructuralMagneticAlignmentHelper.alignShearWall(
          rawCenter: rawCad,
          wallLength: wallL,
          wallThickness: wallT,
          wallRotationRad: wallRot,
          allowRotationSnap: false,
          toleranceCad: toleranceCad,
          activeStorey: _project.activeStorey,
          movingWallId: _isMovingShearWall ? _selectedShearWall?.id : null,
          dxfDocument: _document,
          cadUnitsPerMeter: _cadUnitsPerMeter,
          axisLockMode: effectiveLockMode,
          anchorCenter: _elementMoveOriginalCenter ?? _selectedShearWall?.center,
          maxCorrectionCad: toleranceCad,
        );
        if (bestWallCandCenter != null && (mag == null ||
            (bestWallCandCenter-rawCad).distance < (mag.snappedCenter-rawCad).distance - 1e-8)) {
          effectiveCad = bestWallCandCenter;
          snap = bestWallSnap;
          snappedScreen = _cadToScreen(bestWallSnap!.point);
          _snappedScreenPositions = [snappedScreen];
          _activeMagneticGuides = null;
          _liveDimensionText = null;
          _activeDynamicDimensionLine = null;
        } else {
          if (mag != null) {
            effectiveCad = mag.snappedCenter;
            snappedScreen = _cadToScreen(mag.markerPoint ?? effectiveCad);
            _snappedScreenPositions = [snappedScreen];
            _activeMagneticGuides = mag.guideLines;
            _liveDimensionText = mag.liveDimensionText;
            _activeDynamicDimensionLine = mag.dimensionLine;
          } else {
            snap = _findStructuralSnap(rawCad, toleranceCad) ??
                DxfSnapHelper.findSnapPoint(
                  document: _document,
                  cadPoint: rawCad,
                  toleranceCad: toleranceCad,
                  allowNearest: false,
                );
            if (snap != null) {
              effectiveCad = snap.point;
              snappedScreen = _cadToScreen(snap.point);
              _snappedScreenPositions = [snappedScreen];
            } else {
              effectiveCad = rawCad;
              _snappedScreenPositions = [];
            }
            _activeMagneticGuides = null;
            _liveDimensionText = null;
            _activeDynamicDimensionLine = null;
          }
        }
      } else if (_activeTool == StructuralDrawTool.beam) {
        // Magnetic axial alignment for beams (column center, shear wall center/axis, other beams, grid axes, and ortho-lock)
        final startCad = _beamStartCad;
        final mag = StructuralMagneticAlignmentHelper.alignBeamEndpoint(
          rawPoint: rawCad,
          beamStart: startCad,
          toleranceCad: toleranceCad,
          activeStorey: _project.activeStorey,
          cadUnitsPerMeter: _cadUnitsPerMeter,
          dxfDocument: _document,
        );

        if (mag != null) {
          snap = mag.objectSnap;
          effectiveCad = mag.snappedPoint;
          _activeMagneticGuides = mag.guideLines;
          snappedScreen = _cadToScreen(mag.snappedPoint);
          _snappedScreenPositions = [snappedScreen];
        } else {
          _activeMagneticGuides = null;
          if (startCad != null) {
            // Free length snapped to 10 cm increments (0.10 m)
            final v = rawCad - startCad;
            final distCad = v.distance;
            final distM = distCad / _cadUnitsPerMeter;
            final snappedM = math.max(0.10, (distM / 0.10).round() * 0.10);
            final snappedDistCad = snappedM * _cadUnitsPerMeter;
            if (distCad > 1e-6) {
              final unitDir = v / distCad;
              effectiveCad = startCad + unitDir * snappedDistCad;
            } else {
              effectiveCad = rawCad;
            }
            snappedScreen = _cadToScreen(effectiveCad);
            _snappedScreenPositions = [];
          } else {
            effectiveCad = rawCad;
            _snappedScreenPositions = [];
          }
        }

        if (startCad != null) {
          final lenM = (effectiveCad - startCad).distance / _cadUnitsPerMeter;
          _liveDimensionText = '${lenM.toStringAsFixed(2)} m';
        } else {
          _liveDimensionText = null;
        }
      } else if (_activeTool == StructuralDrawTool.gridAxis) {
        snap = _findStructuralSnap(rawCad, toleranceCad) ??
            DxfSnapHelper.findSnapPoint(
              document: _document,
              cadPoint: rawCad,
              toleranceCad: toleranceCad,
              allowNearest: false,
            );
        if (snap != null) {
          effectiveCad = snap.point;
          snappedScreen = _cadToScreen(snap.point);
          _snappedScreenPositions = [snappedScreen];
        } else {
          _snappedScreenPositions = [];
        }
        _liveDimensionText = null;
      } else if (_activeTool == StructuralDrawTool.slab) {
        if (_slabPointsCad.length >= 3 &&
            (rawCad - _slabPointsCad.first).distance <= _slabSnapTolerance(merge: true)) {
          snap = DxfSnapResult(
            point: _slabPointsCad.first,
            type: DxfSnapType.endpoint,
            distance: (rawCad - _slabPointsCad.first).distance,
          );
        } else {
          snap = _snapSlabPoint(rawCad,
            previous: _slabPointsCad.lastOrNull,
            incomingDirection: _slabPointsCad.length >= 2
              ? _slabPointsCad.last - _slabPointsCad[_slabPointsCad.length - 2] : null);
        }

        if (snap != null) {
          effectiveCad = snap.point;
          snappedScreen = _cadToScreen(snap.point);
          _snappedScreenPositions = [snappedScreen];
        } else {
          _snappedScreenPositions = [];
        }

        if (_slabPointsCad.isNotEmpty) {
          final lenM = (effectiveCad - _slabPointsCad.last).distance / _cadUnitsPerMeter;
          _liveDimensionText = '${lenM.toStringAsFixed(2)} m';
        } else {
          _liveDimensionText = null;
        }
      } else {
        // Single point snap for slabs & openings
        snap = _findStructuralSnap(rawCad, toleranceCad) ??
            DxfSnapHelper.findSnapPoint(
              document: _document,
              cadPoint: rawCad,
              toleranceCad: toleranceCad,
              allowNearest: false,
            );

        if (snap != null) {
          effectiveCad = snap.point;
          snappedScreen = _cadToScreen(snap.point);
          _snappedScreenPositions = [snappedScreen];
        } else {
          _snappedScreenPositions = [];
        }
        _liveDimensionText = null;
      }

      // All point and face snaps obey the same displacement and axis-lock budget.
      if ((_isMovingColumn || _isMovingShearWall ||
          _activeTool == StructuralDrawTool.column || _activeTool == StructuralDrawTool.shearWall) &&
          !acceptsCandidate(effectiveCad)) {
        effectiveCad = rawCad;
        snap = null;
        snappedScreen = null;
        _snappedScreenPositions = [];
        _activeMagneticGuides = null;
        _liveDimensionText = null;
        _activeDynamicDimensionLine = null;
      }
      if (snap != null) {
        if (_activeSnap == null || _activeSnap!.point != snap.point) {
          HapticFeedback.selectionClick();
        }
      }
    } else {
      _activeMagneticGuides = null;
      _activeDynamicDimensionLine = null;
      _snappedScreenPositions = [];
      if (_activeTool == StructuralDrawTool.column || _isMovingColumn) {
        effectiveCad = rawCad;
        _liveDimensionText = null;
      } else if (_isMovingOpening) {
        effectiveCad = rawCad;
        _liveDimensionText = null;
      } else if ((_activeTool == StructuralDrawTool.shearWall && _wallStartCad != null) ||
                 (_activeTool == StructuralDrawTool.beam && _beamStartCad != null)) {
        final startCad = _activeTool == StructuralDrawTool.shearWall ? _wallStartCad! : _beamStartCad!;
        final v = rawCad - startCad;
        final distCad = v.distance;
        final distM = distCad / _cadUnitsPerMeter;
        final snappedM = math.max(0.10, (distM / 0.10).round() * 0.10);
        final snappedDistCad = snappedM * _cadUnitsPerMeter;
        if (distCad > 1e-6) {
          final unitDir = v / distCad;
          effectiveCad = startCad + unitDir * snappedDistCad;
        } else {
          effectiveCad = rawCad;
        }
        final lenM = (effectiveCad - startCad).distance / _cadUnitsPerMeter;
        _liveDimensionText = '${lenM.toStringAsFixed(2)} m';
      } else if (_activeTool == StructuralDrawTool.measure && _measurementStartCad != null) {
        final distM = (rawCad - _measurementStartCad!).distance / _cadUnitsPerMeter;
        _liveDimensionText = distM >= 1.0 ? '${distM.toStringAsFixed(2)} m' : '${(distM * 100).toStringAsFixed(1)} cm';
      } else if (_activeTool == StructuralDrawTool.slab && _slabPointsCad.isNotEmpty) {
        final lenM = (rawCad - _slabPointsCad.last).distance / _cadUnitsPerMeter;
        _liveDimensionText = '${lenM.toStringAsFixed(2)} m';
      } else if (_activeTool == StructuralDrawTool.slabOpening && _openingPointsCad.isNotEmpty) {
        final lenM = (rawCad - _openingPointsCad.last).distance / _cadUnitsPerMeter;
        _liveDimensionText = '${lenM.toStringAsFixed(2)} m';
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

  void _updateMeasurementPointer(Offset screenPos, {required bool isMouse}) {
    final target = isMouse ? screenPos : screenPos - const Offset(0, 56);
    final raw = _screenToCad(target);
    DxfSnapResult? snap;
    _activeMagneticGuides = [];
    if (_snapEnabled) {
      final edges = <(Offset, Offset)>[];
      void polygon(List<Offset> points) {
        for (var i = 0; i < points.length; i++) {
          edges.add((points[i], points[(i + 1) % points.length]));
        }
      }
      final storey = _project.activeStorey;
      for (final column in storey.columns) { polygon(column.polygonVertices); }
      for (final wall in storey.shearWalls) { polygon(wall.polygonVertices); }
      for (final beam in storey.beams) {
        polygon(beam.polygonVertices);
        edges.add((beam.start, beam.end));
      }
      if (_showBimSlabs) {
        final slabs = <String, StructuralSlab>{
          for (final slab in [...storey.slabs, ...?_floorSlabStorey?.slabs,
              ...?_ceilingSlabStorey?.slabs]) slab.id: slab,
        };
        for (final slab in slabs.values) {
          polygon(slab.polygon);
          for (final opening in slab.openings) { polygon(opening); }
        }
      }
      if (_showBimAxes) {
        for (final axis in _project.effectiveGridAxes) {
          edges.add((axis.start, axis.end));
        }
      }
      final pixelsPerCad = _getCadFitScale() *
          _transformController.value.getMaxScaleOnAxis().clamp(.0001, 10000.0);
      final result = StructuralMeasurementSnap.find(document: _document,
          raw: raw, tolerance: 22 / pixelsPerCad, edges: edges,
          start: _measurementStartCad);
      snap = result.snap;
      _activeMagneticGuides = result.guides;
      if (snap != null && (_activeSnap?.point != snap.point ||
          _activeSnap?.type != snap.type)) {
        HapticFeedback.selectionClick();
      }
    }
    final effective = snap?.point ?? raw;
    final distance = _measurementStartCad == null ? null :
        (effective - _measurementStartCad!).distance / _cadUnitsPerMeter;
    setState(() {
      _touchScreenPos = screenPos;
      _targetScreenPos = target;
      _snappedScreenPos = snap == null ? null : _cadToScreen(snap.point);
      _snappedScreenPositions = _snappedScreenPos == null ? [] : [_snappedScreenPos!];
      _activeSnap = snap;
      _currentCadCoord = effective;
      _liveDimensionText = distance == null ? null : distance >= 1
          ? '${distance.toStringAsFixed(2)} m'
          : '${(distance * 100).toStringAsFixed(1)} cm';
    });
  }

  bool get _measurementTracksParallel {
    final guides = _activeMagneticGuides;
    if (_activeTool != StructuralDrawTool.measure || guides == null || guides.length < 2) {
      return false;
    }
    final edge = guides.first.$2 - guides.first.$1;
    final measurement = guides.last.$2 - guides.last.$1;
    final lengths = edge.distance * measurement.distance;
    return lengths > 1e-12 &&
        (edge.dx * measurement.dy - edge.dy * measurement.dx).abs() / lengths < 1e-6;
  }

  List<Offset>? _pointerElementPolygon() {
    final center = _currentCadCoord;
    if (center == null) return null;
    if (_isMovingColumn || _activeTool == StructuralDrawTool.column) {
      final col = _isMovingColumn
          ? _selectedColumn
          : _currentColumnPreset.copyWith(
              width: _currentColumnPreset.width * _cadUnitsPerMeter,
              height: _currentColumnPreset.height * _cadUnitsPerMeter,
              thickness: _currentColumnPreset.thickness * _cadUnitsPerMeter,
            );
      return col
          ?.copyWith(center: center)
          .polygonVertices
          .map(_cadToScreen)
          .toList();
    }
    if (_isMovingShearWall || _activeTool == StructuralDrawTool.shearWall) {
      final old = _isMovingShearWall ? _selectedShearWall : null;
      final length = old?.length ?? _currentWallLength * _cadUnitsPerMeter;
      final rot = old?.rotationRad ?? _currentWallRotationRad;
      final u = Offset(math.cos(rot), math.sin(rot));
      final wall =
          old?.copyWith(
            start: center - u * length / 2,
            end: center + u * length / 2,
          ) ??
          StructuralShearWall(
            id: 'pointer',
            start: center - u * length / 2,
            end: center + u * length / 2,
            thickness: _currentWallThickness * _cadUnitsPerMeter,
          );
      return wall.polygonVertices.map(_cadToScreen).toList();
    }
    return null;
  }

  DxfSnapResult? _findStructuralSnap(Offset cadPt, double toleranceCad, {bool cornersOnly = false, String? excludedSlabId, Set<String> excludedElementIds = const {}}) {
    final frame = BimCoordinateFrame(unitsPerMeter: _cadUnitsPerMeter);
    final raw = frame.toModel(cadPt), radius = toleranceCad / _cadUnitsPerMeter;
    final resolver = BimSnapResolver<StructuralSnapFeature>(raw: raw, radius: radius);
    for (final feature in StructuralSnapScene.of(_project, _cadUnitsPerMeter).query(raw, radius)) {
      if (excludedElementIds.contains(feature.owner) || feature.owner == excludedSlabId ||
          (_isMovingColumn && feature.owner == _selectedColumn?.id) ||
          (_isMovingShearWall && feature.owner == _selectedShearWall?.id) ||
          (cornersOnly && feature.kind == BimSnapKind.midpoint)) { continue; }
      resolver.consider(BimSnapCandidate(point: feature.point, kind: feature.kind, source: feature));
    }
    final best = resolver.best;
    if (best == null) return null;
    final point = frame.toCad(best.point);
    return DxfSnapResult(
      point: point,
      type: switch (best.kind) {
        BimSnapKind.intersection => DxfSnapType.intersection,
        BimSnapKind.midpoint => DxfSnapType.midpoint,
        _ => DxfSnapType.endpoint,
      },
      distance: (point - cadPt).distance,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointersCount = math.max(0, _activePointersCount - 1);
    if (_activePointersCount == 0) _activePointerKind = null;
    if (_isMultiTouchGesture) {
      if (_activePointersCount == 0) _isMultiTouchGesture = false;
      return;
    }

    if (_activeTool == StructuralDrawTool.measure && _isPlacingWithHold) {
      _updateMeasurementPointer(event.localPosition,
          isMouse: event.kind == PointerDeviceKind.mouse);
      _commitPlacement(_currentCadCoord!);
      setState(() {
        _isPlacingWithHold = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        _activeMagneticGuides = [];
        _liveDimensionText = null;
      });
      return;
    }

    if (_beamMove != null) { _finishBeamMove(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse); return; }
    if (_duplicateDraft != null && _placementPointerHandled) {
      _updateDuplicateDrag(event.localPosition, isMouse: event.kind == PointerDeviceKind.mouse);
      _commitDuplicateDrag();
      return;
    }

    // Grid axis offset drag mode commit on release
    if (_isOffsettingAxisWithDrag && _axisBeingOffset != null) {
      final axis = _axisBeingOffset!;
      final dist = _axisOffsetDistanceMeters;
      final sign = _currentOffsetSign;
      _applyAxisOffset(axis, dist, sign);
      return;
    }

    // Column offset drag mode commit on release
    if (_isOffsettingColumnWithDrag && _columnBeingOffset != null) {
      final col = _columnBeingOffset!;
      final dist = _columnOffsetDistanceMeters;
      final dir = _columnOffsetDirection;
      _applyColumnOffset(col, dist, dir);
      return;
    }

    // 0. Dragging grid axis handle commit on release
    if (_isDraggingAxisHandle) {
      _finishAxisGesture(event.localPosition);
      HapticFeedback.lightImpact();
      return;
    }

    // 1. Slab vertex dragging commit or merge on release
    if (_draggingSlabVertexIndex != null && _editingSlab != null) {
      final idx = _draggingSlabVertexIndex!;
      final candidate = _mergeCandidateSlabVertexIndex;
      if (candidate != null && _editingSlab!.polygon.length > 3) {
        _pushSlabCorrectionUndo();
        final updated = _editingSlab!.mergeVertices(
          fromIndex: idx,
          toIndex: candidate,
          minDistanceCad: 0.005 * _cadUnitsPerMeter,
        );
        if (updated != null) {
          final cleaned = _cleanSlabPolygon(updated);
          _editingSlab = cleaned;
          _updateActiveStoreySlab(cleaned);
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.slabPointsMerged),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (_draggingSlabVertexCad != null) {
        final testPts = _slabVertexEditor.active && !_slabVertexEditor.invalid
            ? _slabVertexEditor.preview!.map((p) => p * _cadUnitsPerMeter).toList()
            : (List<Offset>.from(_editingSlab!.polygon)..[idx] = _draggingSlabVertexCad!);
        final cleanedPts = StructuralSlab.cleanPolygon(testPts, minDistance: 0.005 * _cadUnitsPerMeter);
        if (cleanedPts.length >= 3 && !StructuralSlab.hasSelfIntersections(cleanedPts)) {
          _pushSlabCorrectionUndo();
          final updated = _editingSlab!.copyWith(polygon: cleanedPts);
          _editingSlab = updated;
          _updateActiveStoreySlab(updated);
          HapticFeedback.mediumImpact();
        } else if (!StructuralSlab.hasSelfIntersections(testPts)) {
          _pushSlabCorrectionUndo();
          final updated = _editingSlab!.moveVertex(idx, _draggingSlabVertexCad!);
          final cleaned = _cleanSlabPolygon(updated);
          _editingSlab = cleaned;
          _updateActiveStoreySlab(cleaned);
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.vibrate();
        }
      }
      setState(() {
        _draggingSlabVertexIndex = null;
        _draggingSlabVertexCad = null;
        _mergeCandidateSlabVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
      });
      return;
    }

    // 1b. Opening vertex dragging commit or merge on release
    if (_draggingOpeningVertexIndex != null && _selectedOpening != null) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
      if (slabIdx != -1) {
        final slab = active.slabs[slabIdx];
        if (opIdx < slab.openings.length) {
          final op = slab.openings[opIdx];
          final idx = _draggingOpeningVertexIndex!;
          final candidate = _mergeCandidateOpeningVertexIndex;
          if (candidate != null && op.length > 3) {
            final updatedSlab = slab.mergeOpeningVertices(
              openingIndex: opIdx,
              fromIndex: idx,
              toIndex: candidate,
              minDistanceCad: 0.005 * _cadUnitsPerMeter,
            ) ?? slab.removeOpeningVertex(opIdx, idx);
            if (updatedSlab != null && _updateOpeningInStorey(
                (slabId, opIdx), updatedSlab.openings[opIdx], allowTransfer: false)) {
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.openingPointsMerged),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else if (_draggingOpeningVertexCad != null) {
            final testPts = List<Offset>.from(op);
            testPts[idx] = _draggingOpeningVertexCad!;
            final cleanedPts = StructuralSlab.cleanPolygon(testPts, minDistance: 0.005 * _cadUnitsPerMeter);
            if (cleanedPts.length >= 3 && !StructuralSlab.hasSelfIntersections(cleanedPts)) {
              _updateOpeningInStorey((slabId, opIdx), cleanedPts, allowTransfer: false);
              HapticFeedback.mediumImpact();
            } else if (!StructuralSlab.hasSelfIntersections(testPts)) {
              _updateOpeningInStorey((slabId, opIdx), testPts, allowTransfer: false);
              HapticFeedback.mediumImpact();
            } else {
              HapticFeedback.vibrate();
            }
          }
        }
      }
      setState(() {
        _draggingOpeningVertexIndex = null;
        _draggingOpeningVertexCad = null;
        _mergeCandidateOpeningVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
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
            if (_isEditingSlab) {
              _pushSlabCorrectionUndo();
            } else {
              _pushUndo();
            }
            final updatedSlab = active.slabs[slabIdx].dynamicPullEdge(
              edgeIndex: _activeGrip!.edgeIndex,
              distance: d,
              minDistanceCad: 0.05 * scale,
            );
            final cleanedSlab = _cleanSlabPolygon(updatedSlab);
            if (_updateActiveStoreySlab(cleanedSlab) &&
                _isEditingSlab && _editingSlab!.id == _activeExtrudingSlabId) {
              _editingSlab = cleanedSlab;
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
        _activeParallelSnap = null;
        _previewSlabOffsetPolygon = null;
      });
      return;
    }

    // 2b. Opening edge extrusion or midpoint tap on release
    if (_activeOpeningGrip != null && _selectedOpening != null) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
      if (slabIdx != -1) {
        final slab = active.slabs[slabIdx];
        if (opIdx < slab.openings.length) {
          if (_isExtrudingEdge) {
            final d = _extrusionDistanceCad;
            final scale = _cadUnitsPerMeter;
            if (d.abs() >= 0.05 * scale) {
              final updatedSlab = slab.dynamicPullOpeningEdge(
                openingIndex: opIdx,
                edgeIndex: _activeOpeningGrip!.edgeIndex,
                distance: d,
                minDistanceCad: 0.05 * scale,
              );
              _updateOpeningInStorey((slabId, opIdx),
                updatedSlab.openings[opIdx], allowTransfer: false);
              HapticFeedback.heavyImpact();
            }
          } else {
            // Tapped on midpoint grip without dragging -> insert midpoint vertex!
            final updatedSlab = slab.insertOpeningMidpointVertex(opIdx, _activeOpeningGrip!.edgeIndex);
            _updateOpeningInStorey((slabId, opIdx),
              updatedSlab.openings[opIdx], allowTransfer: false);
            HapticFeedback.lightImpact();
          }
        }
      }
      setState(() {
        _isExtrudingEdge = false;
        _activeOpeningGrip = null;
        _midpointTouchDownPos = null;
        _extrusionDistanceCad = 0.0;
        _previewOpeningOffsetPolygon = null;
      });
      return;
    }

    // 3. Moving column with mouse or touch release
    if (_isMovingColumn && _selectedColumn != null) {
      if (_hasMovedSelectedColumn) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          _pushUndo();
          final updatedCol = _selectedColumn!.copyWith(
            center: newCenter,
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
      final bool keepMoveActiveOnTouch = _elementMoveOriginalCenter != null && event.kind != PointerDeviceKind.mouse;
      setState(() {
        _isMovingColumn = keepMoveActiveOnTouch;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        if (!keepMoveActiveOnTouch) {
          _activeMagneticGuides = null;
          _liveDimensionText = null;
          _activeDynamicDimensionLine = null;
          _elementMoveOriginalCenter = null;
        }
      });
      return;
    }

    // 3b. Moving shear wall with mouse or touch release
    if (_isMovingShearWall && _selectedShearWall != null) {
      if (_hasMovedSelectedShearWall) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          _pushUndo();
          final halfLen = _selectedShearWall!.length / 2.0;
          final rot = _selectedShearWall!.rotationRad;
          final u = Offset(math.cos(rot), math.sin(rot));
          final updatedWall = _selectedShearWall!.copyWith(
            start: newCenter - u * halfLen,
            end: newCenter + u * halfLen,
          );
          final active = _project.activeStorey;
          final updatedWalls = active.shearWalls
              .map((w) => w.id == updatedWall.id ? updatedWall : w)
              .toList();
          _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
          _selectedShearWall = updatedWall;
          HapticFeedback.mediumImpact();
        }
      }
      final bool keepMoveActiveOnTouch = _elementMoveOriginalCenter != null && event.kind != PointerDeviceKind.mouse;
      setState(() {
        _isMovingShearWall = keepMoveActiveOnTouch;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        if (!keepMoveActiveOnTouch) {
          _activeMagneticGuides = null;
          _liveDimensionText = null;
          _activeDynamicDimensionLine = null;
          _elementMoveOriginalCenter = null;
        }
      });
      return;
    }

    // 3b. Moving opening with mouse or touch release
    if (_isMovingOpening && _selectedOpening != null) {
      if (_hasMovedSelectedOpening && _movingOpeningRelativeOffsets != null) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          final newPoly = _movingOpeningRelativeOffsets!
              .map((r) => newCenter + r)
              .toList();
          _updateOpeningInStorey(_selectedOpening!, newPoly);
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _isMovingOpening = false;
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
        _activeDynamicDimensionLine = null;
      });
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _cancelContourEditors();
    _beamMove?.cancel();
    _beamMove = null;
    _cancelAxisGesture();
    if (_duplicateDraft != null) _cancelDuplicateDrag();
    _activePointersCount = 0;
    _activePointerKind = null;
    _isMultiTouchGesture = false;
    _isDraggingAxisHandle = false;
    setState(() {
      _isPlacingWithHold = false;
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _activeMagneticGuides = null;
      _isMovingOpening = false;
      _isExtrudingEdge = false;
      _activeGrip = null;
      _activeExtrudingSlabId = null;
      _midpointTouchDownPos = null;
      _extrusionDistanceCad = 0.0;
      _draggingSlabVertexIndex = null;
      _draggingSlabVertexCad = null;
      _mergeCandidateSlabVertexIndex = null;
      _activeMagneticGuides = [];
      _touchScreenPos = null;
      _targetScreenPos = null;
      _snappedScreenPos = null;
      _snappedScreenPositions = [];
      _activeSnap = null;
      _liveDimensionText = null;
      _activeDynamicDimensionLine = null;
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_isDraggingAxisHandle) return;
    if (_duplicateDraft != null || _placementPointerHandled) return;
    if (_activeTool == StructuralDrawTool.measure) return;
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isExtrudingEdge || _activeGrip != null) return;
    if (_isMultiTouchGesture || _activePointersCount > 1) return;

    // -1. If Layers tab is active: holding on an element triggers layer context sheet (hide/isolate)
    if (_activeTool == StructuralDrawTool.layers) {
      _handleLayerContextAtPoint(details.localPosition);
      return;
    }

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

    // 0b. Check if holding on an axis handle -> immediately drag endpoint
    if (_activeTool == StructuralDrawTool.gridAxis || _activeTool == StructuralDrawTool.select) {
      final axisHandle = _hitTestGridAxisHandle(details.localPosition);
      if (axisHandle != null) {
        HapticFeedback.heavyImpact();
        setState(() {
          _beginAxisHandle(axisHandle.$1, axisHandle.$2);
          _selectedColumn = null;
          _selectedShearWall = null;
          _selectedBeam = null;
        });
        return;
      }

      // 0c. Check if holding on an axis line -> select axis and open card
      final hitAxis = _hitTestGridAxis(details.localPosition);
      if (hitAxis != null) {
        HapticFeedback.heavyImpact();
        setState(() {
          _beginAxisMove(hitAxis, details.localPosition);
          _selectedColumn = null;
          _selectedShearWall = null;
          _selectedBeam = null;
        });
        return;
      }
    }

    // 1. Check if holding on an existing placed column
    if (_activeTool == StructuralDrawTool.column || _activeTool == StructuralDrawTool.select) {
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
    }

    // 1b. Check if holding on an existing shear wall
    if (_activeTool == StructuralDrawTool.shearWall || _activeTool == StructuralDrawTool.select) {
      final hitWall = _hitTestShearWall(details.localPosition);
      if (hitWall != null) {
        HapticFeedback.heavyImpact();
        setState(() {
          _selectedShearWall = hitWall;
          _isMovingShearWall = true;
          _hasMovedSelectedShearWall = false;
          _isPlacingWithHold = false;
          _selectedColumn = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedOpeningVertexIndex = null;
          _selectedGridAxis = null;
          _isMovingColumn = false;
        });
        _updatePointer(details.localPosition, isMouse: false);
        return;
      }
    }

    // 1c. Check if holding on an existing beam
    if (_activeTool == StructuralDrawTool.beam || _activeTool == StructuralDrawTool.select) {
      final hitBeam = _hitTestBeam(details.localPosition);
      if (hitBeam != null) {
        HapticFeedback.heavyImpact();
        setState(() {
          _selectedBeam = hitBeam;
          _selectedColumn = null;
          _selectedShearWall = null;
          _selectedOpening = null;
          _selectedOpeningVertexIndex = null;
          _selectedGridAxis = null;
          _isMovingColumn = false;
          _isMovingShearWall = false;
        });
        return;
      }
    }

    // 1d. Check if holding on ANY slab vertex -> enter vertex move mode!
    if (_activeTool == StructuralDrawTool.slab || _activeTool == StructuralDrawTool.select) {
      final hitVertex = _hitTestAnySlabVertex(details.localPosition);
    if (hitVertex != null) {
      final (hitSlab, vIdx) = hitVertex;
      _startSlabCorrection(hitSlab);
      setState(() {
        _draggingSlabVertexIndex = vIdx;
        _draggingSlabVertexCad = hitSlab.polygon[vIdx];
        _mergeCandidateSlabVertexIndex = null;
        _activeMagneticGuides = [];
      });
      HapticFeedback.heavyImpact();
      return;
      }
    }

    // 1e. Check if holding on an existing slab -> start slab correction!
    if (_activeTool == StructuralDrawTool.slab || _activeTool == StructuralDrawTool.select) {
      final hitSlab = _hitTestSlab(details.localPosition);
      if (hitSlab != null) {
        _startSlabCorrection(hitSlab);
        return;
      }
    }

    // 1f. Check if holding on a vertex of the selected opening
    if (_selectedOpening != null &&
        (_activeTool == StructuralDrawTool.slabOpening || _activeTool == StructuralDrawTool.select)) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
      if (slabIdx != -1 && opIdx < active.slabs[slabIdx].openings.length) {
        final op = active.slabs[slabIdx].openings[opIdx];
        final vIdx = _hitTestOpeningVertex(details.localPosition, op);
        if (vIdx != null) {
          HapticFeedback.heavyImpact();
          setState(() {
            _selectedOpeningVertexIndex = vIdx;
            _draggingOpeningVertexIndex = vIdx;
            _draggingOpeningVertexCad = op[vIdx];
            _mergeCandidateOpeningVertexIndex = null;
            _activeMagneticGuides = [];
          });
          return;
        }
      }
    }

    if (_activeTool == StructuralDrawTool.beam || _activeTool == StructuralDrawTool.select) {
      final beam = _hitTestBeam(details.localPosition);
      if (beam != null) { setState(() => _beginBeamMove(beam, details.localPosition)); return; }
    }

    // 1g. Check if holding on an existing slab opening -> move opening!
    if (_activeTool == StructuralDrawTool.slabOpening || _activeTool == StructuralDrawTool.select) {
      final hitOpening = _hitTestOpening(details.localPosition);
      if (hitOpening != null) {
        HapticFeedback.heavyImpact();
        _startMovingOpening(hitOpening, details.localPosition, isMouse: false);
        return;
      }
    }

    // 2. Otherwise deselect previous selection
    if (_activeTool == StructuralDrawTool.select) {
      if (_hasSelectedElement) {
        setState(() {
          _selectedColumn = null;
          _selectedShearWall = null;
          _selectedBeam = null;
          _selectedOpening = null;
          _selectedOpeningVertexIndex = null;
          _selectedGridAxis = null;
          _isMovingColumn = false;
          _isMovingShearWall = false;
        });
      }
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedColumn = null;
      _selectedShearWall = null;
      _selectedBeam = null;
      _selectedOpening = null;
      _selectedOpeningVertexIndex = null;
      _selectedGridAxis = null;
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _isPlacingWithHold = true;

    });
    _updatePointer(details.localPosition, isMouse: false);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_duplicateDraft != null || _placementPointerHandled) return;
    if (_activeTool == StructuralDrawTool.measure) return;
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_isDraggingAxisHandle && _selectedGridAxis != null) {
      _previewAxisHandle(details.localPosition);
      return;
    }
    if (_draggingSlabVertexIndex != null && _editingSlab != null) {
      _updateSlabVertexDrag(details.localPosition);
      return;
    }
    if (_draggingOpeningVertexIndex != null && _selectedOpening != null) {
      _updateOpeningVertexDrag(details.localPosition);
      return;
    }
    if (_isMovingColumn && _selectedColumn != null) {
      _updatePointer(details.localPosition, isMouse: false);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedColumn!.center).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedColumn = true;
        }
      }
      return;
    }
    if (_isMovingShearWall && _selectedShearWall != null) {
      _updatePointer(details.localPosition, isMouse: false);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null) {
        final dist = (effectiveCad - _selectedShearWall!.center).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedShearWall = true;
        }
      }
      return;
    }
    if (_isMovingOpening && _selectedOpening != null) {
      _updatePointer(details.localPosition, isMouse: false);
      final effectiveCad = _currentCadCoord;
      if (effectiveCad != null && _movingOpeningOriginalCenter != null) {
        final dist = (effectiveCad - _movingOpeningOriginalCenter!).distance;
        if (dist > 0.05 * _cadUnitsPerMeter) {
          _hasMovedSelectedOpening = true;
        }
      }
      return;
    }
    if (_isPlacingWithHold) {
      _updatePointer(details.localPosition, isMouse: false);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_duplicateDraft != null || _placementPointerHandled) return;
    if (_activeTool == StructuralDrawTool.measure) return;
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_draggingSlabVertexIndex != null && _editingSlab != null) {
      final idx = _draggingSlabVertexIndex!;
      final candidate = _mergeCandidateSlabVertexIndex;
      if (candidate != null && _editingSlab!.polygon.length > 3) {
        _pushSlabCorrectionUndo();
        final updated = _editingSlab!.mergeVertices(
          fromIndex: idx,
          toIndex: candidate,
          minDistanceCad: 0.005 * _cadUnitsPerMeter,
        );
        if (updated != null) {
          final cleaned = _cleanSlabPolygon(updated);
          _editingSlab = cleaned;
          _updateActiveStoreySlab(cleaned);
          _saveProject();
          HapticFeedback.heavyImpact();
        }
      } else if (_draggingSlabVertexCad != null) {
        final testPts = _slabVertexEditor.active && !_slabVertexEditor.invalid
            ? _slabVertexEditor.preview!.map((p) => p * _cadUnitsPerMeter).toList()
            : (List<Offset>.from(_editingSlab!.polygon)..[idx] = _draggingSlabVertexCad!);
        final cleanedPts = StructuralSlab.cleanPolygon(testPts, minDistance: 0.005 * _cadUnitsPerMeter);
        if (cleanedPts.length >= 3 && !StructuralSlab.hasSelfIntersections(cleanedPts)) {
          _pushSlabCorrectionUndo();
          final updated = _editingSlab!.copyWith(polygon: cleanedPts);
          _editingSlab = updated;
          _updateActiveStoreySlab(updated);
          _saveProject();
          HapticFeedback.mediumImpact();
        } else if (!StructuralSlab.hasSelfIntersections(testPts)) {
          _pushSlabCorrectionUndo();
          final updated = _editingSlab!.moveVertex(idx, _draggingSlabVertexCad!);
          final cleaned = _cleanSlabPolygon(updated);
          _editingSlab = cleaned;
          _updateActiveStoreySlab(cleaned);
          _saveProject();
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _draggingSlabVertexIndex = null;
        _draggingSlabVertexCad = null;
        _mergeCandidateSlabVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
      });
      return;
    }
    if (_draggingOpeningVertexIndex != null && _selectedOpening != null) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
      if (slabIdx != -1 && opIdx < active.slabs[slabIdx].openings.length) {
        final idx = _draggingOpeningVertexIndex!;
        final candidate = _mergeCandidateOpeningVertexIndex;
        if (candidate != null && active.slabs[slabIdx].openings[opIdx].length > 3) {
          final updatedSlab = active.slabs[slabIdx].mergeOpeningVertices(
            openingIndex: opIdx,
            fromIndex: idx,
            toIndex: candidate,
            minDistanceCad: 0.005 * _cadUnitsPerMeter,
          );
          if (updatedSlab != null) {
            _updateOpeningInStorey((slabId, opIdx), updatedSlab.openings[opIdx], allowTransfer: false);
            _saveProject();
            HapticFeedback.heavyImpact();
          }
        } else if (_draggingOpeningVertexCad != null) {
          final testPts = _openingVertexEditor.active && !_openingVertexEditor.invalid
              ? _openingVertexEditor.preview!.map((p) => p * _cadUnitsPerMeter).toList()
              : (List<Offset>.from(active.slabs[slabIdx].openings[opIdx])..[idx] = _draggingOpeningVertexCad!);
          final cleanedPts = StructuralSlab.cleanPolygon(testPts, minDistance: 0.005 * _cadUnitsPerMeter);
          if (cleanedPts.length >= 3 && !StructuralSlab.hasSelfIntersections(cleanedPts)) {
            _updateOpeningInStorey((slabId, opIdx), cleanedPts, allowTransfer: false);
            _saveProject();
            HapticFeedback.mediumImpact();
          }
        }
      }
      setState(() {
        _draggingOpeningVertexIndex = null;
        _draggingOpeningVertexCad = null;
        _mergeCandidateOpeningVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
      });
      return;
    }
    if (_isDraggingAxisHandle) {
      setState(() {
        _isDraggingAxisHandle = false;
      });
      HapticFeedback.lightImpact();
      return;
    }
    if (_isMovingColumn && _selectedColumn != null) {
      if (_hasMovedSelectedColumn) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          _pushUndo();
          final updatedCol = _selectedColumn!.copyWith(
            center: newCenter,
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
        _activeMagneticGuides = null;
      });
      return;
    }

    if (_isMovingShearWall && _selectedShearWall != null) {
      if (_hasMovedSelectedShearWall) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          _pushUndo();
          final halfLen = _selectedShearWall!.length / 2.0;
          final rot = _selectedShearWall!.rotationRad;
          final u = Offset(math.cos(rot), math.sin(rot));
          final updatedWall = _selectedShearWall!.copyWith(
            start: newCenter - u * halfLen,
            end: newCenter + u * halfLen,
          );
          final active = _project.activeStorey;
          final updatedWalls = active.shearWalls
              .map((w) => w.id == updatedWall.id ? updatedWall : w)
              .toList();
          _updateActiveStorey(active.copyWith(shearWalls: updatedWalls));
          _selectedShearWall = updatedWall;
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _isMovingShearWall = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
        _activeMagneticGuides = null;
      });
      return;
    }

    if (_isMovingOpening && _selectedOpening != null) {
      if (_hasMovedSelectedOpening && _movingOpeningRelativeOffsets != null) {
        final newCenter = _currentCadCoord;
        if (newCenter != null) {
          final newPoly = _movingOpeningRelativeOffsets!
              .map((r) => newCenter + r)
              .toList();
          _updateOpeningInStorey(_selectedOpening!, newPoly);
          HapticFeedback.mediumImpact();
        }
      }
      setState(() {
        _isMovingOpening = false;
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
        _activeMagneticGuides = null;
        _liveDimensionText = null;
        _activeDynamicDimensionLine = null;
      });
    }
  }

  void _handleLongPressCancel() {
    if (_duplicateDraft != null || _placementPointerHandled) return;
    if (_activeTool == StructuralDrawTool.measure) return;
    if (_isMovingColumn) {
      setState(() {
        _isMovingColumn = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
        _activeMagneticGuides = null;
      });
    }
    if (_draggingSlabVertexIndex != null) {
      setState(() {
        _draggingSlabVertexIndex = null;
        _draggingSlabVertexCad = null;
        _mergeCandidateSlabVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
      });
    }
    if (_draggingOpeningVertexIndex != null) {
      setState(() {
        _draggingOpeningVertexIndex = null;
        _draggingOpeningVertexCad = null;
        _mergeCandidateOpeningVertexIndex = null;
        _activeMagneticGuides = [];
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
      });
    }
    if (_isMovingShearWall) {
      setState(() {
        _isMovingShearWall = false;
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _activeSnap = null;
        _activeMagneticGuides = null;
      });
    }
    if (_isMovingOpening) {
      setState(() {
        _isMovingOpening = false;
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
        _activeMagneticGuides = null;
      });
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_placementPointerHandled || _duplicateDraft != null) return;
    if (_activeTool == StructuralDrawTool.measure) {
      if (details.kind == PointerDeviceKind.mouse || _isMultiTouchGesture ||
          _activePointersCount > 1 || _isPlacingWithHold || _measurementHeldGesture) {
        return;
      }
      // A quick tap selects its actual location; holds use the offset tip.
      _updateMeasurementPointer(details.localPosition, isMouse: true);
      _commitPlacement(_currentCadCoord!);
      setState(() {
        _touchScreenPos = null;
        _targetScreenPos = null;
        _snappedScreenPos = null;
        _snappedScreenPositions = [];
        _activeSnap = null;
        _activeMagneticGuides = [];
        _liveDimensionText = null;
      });
      return;
    }
    // Pointer-down may navigate to the badge owner and rearrange its labels.
    // The same tap must not select the next storey's newly positioned badge.
    if (_slabBadgeSelectionHandled) {
      _slabBadgeSelectionHandled = false;
      return;
    }
    if (_activePointerKind == PointerDeviceKind.mouse) return;
    if (_activeTool == StructuralDrawTool.layers) {
      _handleLayerContextAtPoint(details.localPosition);
      return;
    }

    // 1. In-progress multi-point drawing takes precedence on placement taps:
    if (_activeTool == StructuralDrawTool.slab && _slabPointsCad.isNotEmpty) {
      final cadPt = _screenToCad(details.localPosition);
      _commitPlacement(cadPt);
      return;
    }
    if (_activeTool == StructuralDrawTool.slabOpening &&
        (_openingPointsCad.isNotEmpty || _openingStartCad != null)) {
      _commitOpeningTap(details.localPosition);
      return;
    }
    if (_activeTool == StructuralDrawTool.beam && _beamStartCad != null) {
      final cadPt = _currentCadCoord ?? _screenToCad(details.localPosition);
      _commitPlacement(cadPt);
      return;
    }

    // 2. MODAL HIT-TESTING & INTERACTION
    // Each tool strictly selects and edits only its own element type:
    switch (_activeTool) {
      case StructuralDrawTool.column:
        final hitCol = _hitTestColumn(details.localPosition);
        if (hitCol != null) {
          setState(() {
            _selectedColumn = hitCol;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _isMovingColumn = false;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final cadPt = _screenToCad(details.localPosition);
        _commitPlacement(cadPt);
        return;

      case StructuralDrawTool.shearWall:
        final hitWall = _hitTestShearWall(details.localPosition);
        if (hitWall != null) {
          setState(() {
            _selectedShearWall = hitWall;
            _selectedColumn = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _isMovingShearWall = false;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final cadPt = _screenToCad(details.localPosition);
        _commitPlacement(cadPt);
        return;

      case StructuralDrawTool.beam:
        final hitBeam = _hitTestBeam(details.localPosition);
        if (hitBeam != null) {
          setState(() {
            _selectedBeam = hitBeam;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final cadPt = _currentCadCoord ?? _screenToCad(details.localPosition);
        _commitPlacement(cadPt);
        return;

      case StructuralDrawTool.slabOpening:
        if (_selectedOpening != null) {
          final (slabId, opIdx) = _selectedOpening!;
          final active = _project.activeStorey;
          final slabIdx = active.slabs.indexWhere((s) => s.id == slabId);
          if (slabIdx != -1 && opIdx < active.slabs[slabIdx].openings.length) {
            final hitVIdx = _hitTestOpeningVertex(details.localPosition, active.slabs[slabIdx].openings[opIdx]);
            if (hitVIdx != null) {
              setState(() {
                _selectedOpeningVertexIndex = hitVIdx;
              });
              HapticFeedback.selectionClick();
              return;
            }
          }
        }
        final hitOpening = _hitTestOpening(details.localPosition);
        if (hitOpening != null) {
          setState(() {
            _selectedOpening = hitOpening;
            _selectedOpeningVertexIndex = null;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _isMovingOpening = false;
          });
          HapticFeedback.selectionClick();
          return;
        }
        _commitOpeningTap(details.localPosition);
        return;

      case StructuralDrawTool.gridAxis:
        final hitAxis = _hitTestGridAxis(details.localPosition);
        if (hitAxis != null) {
          setState(() {
            _selectedGridAxis = hitAxis;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final cadPt = _screenToCad(details.localPosition);
        _commitPlacement(cadPt);
        return;

      case StructuralDrawTool.slab:
        if (_isEditingSlab) {
          final hitVIdx = _hitTestSlabVertex(details.localPosition, _editingSlab!);
          if (hitVIdx != null) {
            setState(() {
              _selectedSlabVertexIndex = hitVIdx;
            });
            HapticFeedback.selectionClick();
            return;
          }
        }
        final hitSlab = _hitTestSlab(details.localPosition);
        if (hitSlab != null) {
          _startSlabCorrection(hitSlab);
          setState(() {
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
          });
          HapticFeedback.selectionClick();
          return;
        }
        if (_isEditingSlab) {
          setState(() {
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
          });
          return;
        }
        final cadPt = _screenToCad(details.localPosition);
        _commitPlacement(cadPt);
        return;

      case StructuralDrawTool.select:
        // Selection mode: hit-test elements in Z-order
        final hitCol = _hitTestColumn(details.localPosition);
        if (hitCol != null) {
          setState(() {
            _selectedColumn = hitCol;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _activeTool = StructuralDrawTool.column;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final hitWall = _hitTestShearWall(details.localPosition);
        if (hitWall != null) {
          setState(() {
            _selectedShearWall = hitWall;
            _selectedColumn = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _activeTool = StructuralDrawTool.shearWall;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final hitBeam = _hitTestBeam(details.localPosition);
        if (hitBeam != null) {
          setState(() {
            _selectedBeam = hitBeam;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _activeTool = StructuralDrawTool.beam;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final hitOpening = _hitTestOpening(details.localPosition);
        if (hitOpening != null) {
          setState(() {
            _selectedOpening = hitOpening;
            _selectedOpeningVertexIndex = null;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _activeTool = StructuralDrawTool.slabOpening;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final hitAxis = _hitTestGridAxis(details.localPosition);
        if (hitAxis != null) {
          setState(() {
            _selectedGridAxis = hitAxis;
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
            _activeTool = StructuralDrawTool.gridAxis;
          });
          HapticFeedback.selectionClick();
          return;
        }
        final hitSlab = _hitTestSlab(details.localPosition);
        if (hitSlab != null) {
          _startSlabCorrection(hitSlab);
          setState(() {
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _activeTool = StructuralDrawTool.slab;
          });
          HapticFeedback.selectionClick();
          return;
        }
        if (_hasSelectedElement) {
          setState(() {
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
          });
        }
        return;

      default:
        if (_hasSelectedElement) {
          setState(() {
            _selectedColumn = null;
            _selectedShearWall = null;
            _selectedBeam = null;
            _selectedOpening = null;
            _selectedOpeningVertexIndex = null;
            _selectedGridAxis = null;
            _editingSlab = null;
            _selectedSlabVertexIndex = null;
          });
        }
        break;
    }
  }

  // --- Element Placement Logic ---

  void _commitPlacement(Offset cadCoord) {
    final active = _project.activeStorey;
    final scale = _cadUnitsPerMeter;

    if (_activeTool == StructuralDrawTool.column) {
      _pushUndo();
      final candidateCol = StructuralColumn(
        id: 'col_${DateTime.now().millisecondsSinceEpoch}',
        center: cadCoord,
        shape: _currentColumnPreset.shape,
        width: _currentColumnPreset.width * scale,
        height: _currentColumnPreset.height * scale,
        rotationRad: _currentColumnPreset.rotationRad,
        thickness: _currentColumnPreset.thickness * scale,
        isMirrored: _currentColumnPreset.isMirrored,
      );

      final matchingName = StructuralColumnSynchronizer.findMatchingColumnName(
        _project,
        cadCoord,
        candidateCol,
        cadUnitsPerMeter: scale,
      );
      final nextColName = matchingName ??
          StructuralColumnSynchronizer.generateNextProjectColumnName(_project);
      final newCol = candidateCol.copyWith(name: nextColName);

      final updatedColumns = List<StructuralColumn>.from(active.columns)
        ..add(newCol);
      final updatedStorey = active.copyWith(columns: updatedColumns);
      _updateActiveStorey(updatedStorey);
      HapticFeedback.mediumImpact();
    } else if (_activeTool == StructuralDrawTool.gridAxis) {
      final double fitScale = _getCadFitScale();
      final double currentScale = _transformController.value.getMaxScaleOnAxis();
      final double toleranceCad = 36.0 / (fitScale * currentScale.clamp(0.001, 10000.0));
      final seg = _findClosestSegmentInCad(cadCoord, toleranceCad);
      if (seg != null) {
        if (_firstWallEdgeStartCad == null) {
          setState(() {
            _firstWallEdgeStartCad = seg.$1;
            _firstWallEdgeEndCad = seg.$2;
          });
          HapticFeedback.lightImpact();
        } else {
          final suggestedName = _getSuggestedAxisName(_firstWallEdgeStartCad!, _firstWallEdgeEndCad!);
          final rawAxis = StructuralGridAxis.fromTwoSegments(
            id: 'axis_${DateTime.now().millisecondsSinceEpoch}',
            name: suggestedName,
            a1: _firstWallEdgeStartCad!,
            a2: _firstWallEdgeEndCad!,
            b1: seg.$1,
            b2: seg.$2,
            extensionLength: 1.5 * scale,
          );
          if (rawAxis != null) {
            final existingParallel = _project.effectiveGridAxes
                .where((a) => a.isParallelTo(rawAxis))
                .firstOrNull;
            final axis = existingParallel != null
                ? rawAxis.alignWith(existingParallel)
                : rawAxis;

            _pushUndo();
            final isBg = Localizations.localeOf(context).languageCode == 'bg';
            final updatedAxes = resequenceGridAxes([..._project.effectiveGridAxes, axis], isBulgarian: isBg);
            _updateProjectGridAxes(updatedAxes);
            setState(() {
              _firstWallEdgeStartCad = null;
              _firstWallEdgeEndCad = null;
              _currentAxisName = _getNextAxisName(axis.name);
              _selectedGridAxis = _findProjectAxis(axis);
            });
            HapticFeedback.mediumImpact();
          }
        }
      }
    } else if (_activeTool == StructuralDrawTool.shearWall) {
      _pushUndo();
      final nextWallName = _generateNextShearWallName(active.shearWalls);
      final dir = Offset(math.cos(_currentWallRotationRad), math.sin(_currentWallRotationRad));
      final halfLen = (_currentWallLength * scale) / 2.0;
      final newWall = StructuralShearWall(
        id: 'wall_${DateTime.now().millisecondsSinceEpoch}',
        name: nextWallName,
        start: cadCoord - dir * halfLen,
        end: cadCoord + dir * halfLen,
        thickness: _currentWallThickness * scale,
        isFlipped: false,
      );
      final updatedWalls = List<StructuralShearWall>.from(active.shearWalls)
        ..add(newWall);
      final updatedStorey = active.copyWith(shearWalls: updatedWalls);
      _updateActiveStorey(updatedStorey);
      HapticFeedback.mediumImpact();
    } else if (_activeTool == StructuralDrawTool.slab) {
      if (!_isPlacingWithHold) {
        cadCoord = _snapSlabPoint(cadCoord, previous: _slabPointsCad.lastOrNull,
          incomingDirection: _slabPointsCad.length >= 2
            ? _slabPointsCad.last - _slabPointsCad[_slabPointsCad.length - 2] : null)?.point ?? cadCoord;
      }
      if (_slabPointsCad.length >= 3) {
        final distToFirst = (cadCoord - _slabPointsCad.first).distance;
        final closeThresholdCad = _slabSnapTolerance(merge: true);
        if (distToFirst <= closeThresholdCad) {
          _closeSlabPolygon();
          return;
        }
      }
      if (_slabPointsCad.isEmpty ||
          (cadCoord - _slabPointsCad.last).distance >= 0.05 * scale) {
        setState(() {
          _slabPointsCad.add(cadCoord);
        });
        HapticFeedback.lightImpact();
      }
    } else if (_activeTool == StructuralDrawTool.beam) {
      if (_beamStartCad == null) {
        // Step 1: Set beam start point
        setState(() => _beamStartCad = cadCoord);
        HapticFeedback.lightImpact();
      } else {
        // Step 2: Set beam end point and commit
        if ((cadCoord - _beamStartCad!).distance >= 0.3 * scale) {
          _pushUndo();
          final isBg = Localizations.localeOf(context).languageCode == 'bg';
          final nextBeamName = _generateNextBeamName(active.beams, isBulgarian: isBg);
          final newBeam = StructuralBeam(
            id: 'beam_${DateTime.now().millisecondsSinceEpoch}',
            name: nextBeamName,
            start: _beamStartCad!,
            end: cadCoord,
            width: _currentBeamWidth * scale,
            depth: _currentBeamDepth * scale,
          );
          final updatedBeams = List<StructuralBeam>.from(active.beams)
            ..add(newBeam);
          final updatedStorey = active.copyWith(beams: updatedBeams);
          _updateActiveStorey(updatedStorey);
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _beamStartCad = null;
          _liveDimensionText = null;
          _activeMagneticGuides = null;
        });
      }
    } else if (_activeTool == StructuralDrawTool.slabOpening) {
      if (_openingPointsCad.length >= 3) {
        final distToFirst = (cadCoord - _openingPointsCad.first).distance;
        final double fitScale = _getCadFitScale();
        final double currentScale = _transformController.value.getMaxScaleOnAxis();
        final closeThresholdCad = math.min(
            12.0 / (fitScale * currentScale.clamp(0.001, 10000.0)), .10 * scale);
        if (distToFirst <= closeThresholdCad) {
          _closeOpeningPolygon();
          return;
        }
      }
      if (_openingPointsCad.isEmpty ||
          (cadCoord - _openingPointsCad.last).distance >= 0.05 * scale) {
        setState(() {
          _openingPointsCad.add(cadCoord);
        });
        HapticFeedback.lightImpact();
      }
    } else if (_activeTool == StructuralDrawTool.measure) {
      if (_measurementStartCad == null) {
        setState(() {
          _measurementStartCad = cadCoord;
          _activeMeasurement = null;
        });
        HapticFeedback.lightImpact();
      } else {
        final p1 = _measurementStartCad!;
        final p2 = cadCoord;
        final distM = (p2 - p1).distance / scale;
        final label = distM >= 1.0
            ? '${distM.toStringAsFixed(2)} m'
            : '${(distM * 100).toStringAsFixed(1)} cm';
        setState(() {
          _activeMeasurement = (p1, p2, label);
          _measurementStartCad = null;
          _liveDimensionText = null;
        });
        HapticFeedback.mediumImpact();
      }
    }
  }

  bool _addOpeningToSlab(List<Offset> opPoly,
      {SlabOpeningType type = SlabOpeningType.shaft}) {
    final result = SlabOpeningPlacement.apply(
      slabs: _project.activeStorey.slabs, polygon: opPoly,
      scale: _cadUnitsPerMeter, type: type,
      floorOwnedOnly: widget.bimContext != null);
    final accepted = _applyOpeningPlacement(result);
    if (accepted) HapticFeedback.heavyImpact();
    return accepted;
  }


  void _ensureSlabsPopulatedForActiveStorey() {
    // Project source revisions and owned floors are synchronized by the BIM library.
    if (widget.bimContext != null) return;
    final active = _project.activeStorey;
    if (active.slabs.isNotEmpty) return;
    final metadata = BimUnderlayMetadata.read(_document);
    if (metadata == null || metadata['slabEnvelope'] == null) return;
    final seeds = SlabSeedGenerator.generate(
      metadata: metadata,
      document: _document,
      storeyId: active.id,
      existing: active.slabs,
      unitsPerMeter: _cadUnitsPerMeter,
      thickness: _currentSlabThickness,
      floorOwned: widget.bimContext != null,
    );
    if (seeds.isNotEmpty) {
      final coloredSeeds = [
        for (var i = 0; i < seeds.length; i++)
          seeds[i].copyWith(
            colorValue: SlabColors.forSlab(seeds[i], fallback: Structural2dPainter.slabPalette[
                i % Structural2dPainter.slabPalette.length]).toARGB32(),
          ),
      ];
      _updateActiveStorey(active.copyWith(slabs: coloredSeeds));
      _runAnalysis();
      setState(() {});
    }
  }

  Future<void> _clearStructuralSupports() async {
    final snapshot = _project;
    final count = snapshot.storeys.fold<int>(
      0, (n, s) => n + s.columns.length + s.shearWalls.length);
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.bimClearStructure),
        content: Text(context.l10n.bimClearStructureConfirm(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (!mounted || confirmed != true || !identical(_project, snapshot)) return;
    _pushUndo();
    setState(() {
      _project = _project.copyWith(storeys: [
        for (final s in _project.storeys) s.copyWith(columns: [], shearWalls: [])]);
      _selectedColumn = null;
      _selectedShearWall = null;
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _isPlacingWithHold = false;
      _currentCadCoord = null;
      _runAnalysis();
    });
    _saveProject();
  }

  Map<String, DxfDocument> get _staircaseDocuments =>
      widget.bimContext?.underlaysByStorey ??
      {_project.activeStorey.id: _document};

  void _applyAutomaticStairCuts(AutomaticStairCuts result) {
    if (result.added == 0) return;
    _pushUndo();
    setState(() {
      _project = result.project;
      _selectedOpening = null;
      _runAnalysis();
    });
    _saveProject();
  }

  Future<void> _generateStaircaseOpenings() async {
    if (_isEditingSlab ||
        _slabPointsCad.isNotEmpty ||
        _openingPointsCad.isNotEmpty ||
        _wallStartCad != null ||
        _beamStartCad != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.schemeEditing)));
      return;
    }
    final targets = StaircaseAutomaticOpenings.detect(
      _project,
      _staircaseDocuments,
      _cadUnitsPerMeter,
    );
    final result = StaircaseAutomaticOpenings.apply(
      _project,
      targets,
      _cadUnitsPerMeter,
    );
    _applyAutomaticStairCuts(result);
    final missing = StaircaseAutomaticOpenings.missing(
      _project,
      targets,
      _cadUnitsPerMeter,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.added > 0
              ? context.l10n.staircaseAutoAdded(result.added)
              : targets.isNotEmpty && missing.isEmpty
              ? context.l10n.staircaseAutoExisting
              : context.l10n.staircaseAutoNotFound,
        ),
      ),
    );
  }

  Future<void> _generateSlabSeeds() async {
    final active = _project.activeStorey;
    var metadata = BimUnderlayMetadata.read(_document);
    List<(Offset, Offset)>? wallReferences;
    if (metadata == null) {
      final wallResult = WallAxisDetector.detect(_document);
      if (wallResult.hasWallsFound) {
        final envelope = SlabEnvelopeDetector.detect(wallResult, document: _document);
        final projections = SlabProjectionDetector.detect(
          _document,
          envelope,
          wallResult.detectedScale,
          wallLayers: wallResult.selectedWallPairs
              .expand((p) => [p.segmentA.sourceLayer, p.segmentB.sourceLayer])
              .toSet(),
        );
        metadata = {
          'slabEnvelope': envelope.toJson(),
          'slabProjections': projections.map((p) => p.toJson()).toList(),
        };
        wallReferences = [...wallResult.wallContourSegments, ...wallResult.closureSegments];
      }
    } else if ((metadata['slabProjections'] as List? ?? []).isEmpty) {
      final wallResult = WallAxisDetector.detect(_document);
      if (wallResult.hasWallsFound) {
        final envelope = SlabEnvelopeDetector.detect(wallResult, document: _document);
        final projections = SlabProjectionDetector.detect(
          _document,
          envelope,
          wallResult.detectedScale,
          wallLayers: wallResult.selectedWallPairs
              .expand((p) => [p.segmentA.sourceLayer, p.segmentB.sourceLayer])
              .toSet(),
        );
        if (projections.isNotEmpty) {
          metadata = {
            ...metadata,
            'slabProjections': projections.map((p) => p.toJson()).toList(),
          };
        }
      }
    }
    if (metadata == null || metadata['slabEnvelope'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bimSlabSeedsEmpty)),
      );
      return;
    }
    if (active.slabs.any((s) => s.id.startsWith(SlabSeedGenerator.prefix(active.id)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bimSlabsAlreadyGenerated)),
      );
      return;
    }
    final seeds = SlabSeedGenerator.generate(
      metadata: metadata,
      document: _document,
      storeyId: active.id,
      existing: active.slabs,
      unitsPerMeter: _cadUnitsPerMeter,
      thickness: _currentSlabThickness,
      floorOwned: widget.bimContext != null,
      wallReferences: wallReferences,
    );
    final total = ((metadata['slabEnvelope'] as Map?)?['contours'] as List? ?? []).length +
        (metadata['slabProjections'] as List? ?? []).length;
    if (seeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bimSlabSeedsEmpty)),
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.bimGenerateSlabs),
        content: Text(context.l10n.bimSlabSeedsReview(
          seeds.length,
          total > seeds.length ? total - seeds.length : 0,
          (_currentSlabThickness * 100).toStringAsFixed(1),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true || _project.activeStorey.id != active.id) return;
    _pushUndo();
    final coloredSeeds = [
      for (var i = 0; i < seeds.length; i++)
        seeds[i].copyWith(
          colorValue: SlabColors.forSlab(seeds[i], fallback: Structural2dPainter.slabPalette[
              (active.slabs.length + i) % Structural2dPainter.slabPalette.length]).toARGB32(),
        ),
    ];
    _updateActiveStorey(active.copyWith(slabs: [...active.slabs, ...coloredSeeds]));
    _runAnalysis();
    setState(() {});
    _saveProject();
  }

  void _closeSlabPolygon() {
    if (_slabPointsCad.length >= 3) {
      _pushUndo();
      final active = _project.activeStorey;
      final cleanedPts = StructuralSlab.cleanPolygon(
        List.from(_slabPointsCad),
        minDistance: 0.005 * _cadUnitsPerMeter,
      );
      if (cleanedPts.length >= 3) {
        final newSlab = StructuralSlab(
          id: 'slab_${DateTime.now().millisecondsSinceEpoch}',
          isFloorSlab: widget.bimContext != null,
          polygon: cleanedPts,
          thickness: _currentSlabThickness,
          colorValue: Structural2dPainter.slabPalette[
                  active.slabs.length % Structural2dPainter.slabPalette.length]
              .toARGB32(),
        );
        final updatedSlabs = List<StructuralSlab>.from(active.slabs)..add(newSlab);
        final updatedStorey = active.copyWith(slabs: updatedSlabs);
        _updateActiveStorey(updatedStorey);
      }

      setState(() {
        _slabPointsCad.clear();
        _activeMagneticGuides = [];
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _closeOpeningPolygon() {
    if (_openingPointsCad.length >= 3) {
      final cleanedPts = StructuralSlab.cleanPolygon(
        List.from(_openingPointsCad),
        minDistance: 0.005 * _cadUnitsPerMeter,
      );
      if (cleanedPts.length < 3 ||
          !_addOpeningToSlab(cleanedPts, type: _currentOpeningType)) { return; }
      setState(() {
        _openingPointsCad.clear();
        _openingStartCad = null;
        _liveDimensionText = null;
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _saveProject() {
    if (widget.bimContext != null) {
      widget.bimContext!.onProjectChanged(_project);
      return;
    }
    final docKey = widget.title ?? 'structural_model';
    StructuralPersistenceService.saveProject(documentKey: docKey, project: _project);
  }

  void _updateActiveStorey(StoreyLevel newStorey) {
    newStorey = newStorey.copyWith(slabs: SlabZoneGrouping.attach(
      newStorey.slabs, _cadUnitsPerMeter, owner: newStorey));
    final storeys = List<StoreyLevel>.from(_project.storeys);
    storeys[_project.activeStoreyIndex] = newStorey;
    setState(() {
      _project = _project.copyWith(storeys: storeys);
      _runAnalysis();
    });
    _saveProject();
  }

  bool _filterUnderlayEntity(DxfEntity entity) {
    // 1. Suppress all hatches (fill patterns) in structural underlay
    if (entity is DxfHatch) return false;
    // 2. If entity is on a white structural layer, suppress non-white entities (e.g. insulation lines with color 30)
    final layer = _document.layers[entity.layer];
    if (layer != null && StructuralUnderlayFilter.isWhiteLayer(layer)) {
      if (entity.colorIndex != null &&
          entity.colorIndex != 256 &&
          entity.colorIndex != 0 &&
          entity.colorIndex != 7 &&
          entity.colorIndex != 255) {
        return false;
      }
    }
    return true;
  }

  // --- Structural Underlay Layer Filtering (White Thick Walls & Slabs focus) ---

  void _applyUnderlayFilter(bool activate) {
    void execute() {
      if (BimUnderlayMetadata.read(_document) != null) {
        _underlayFilterActive = activate;
        final docs = widget.bimContext?.underlaysByStorey ?? {'': _document};
        for (final entry in docs.entries) {
          BimUnderlayMetadata.setFiltered(entry.value, activate);
          widget.bimContext?.onLayerVisibilityChanged(entry.key,
            {for (final l in entry.value.layers.values) l.name: l.isVisible});
        }
        _underlayRevision++;
        return;
      }
      _underlayFilterActive = activate;
      if (activate) {
        final Set<String> visibleLayerNames = _customUnderlayFilterLayers ??
            StructuralUnderlayFilter.filterLayers(
              layers: _document.layers.values,
              entities: _document.entities,
              blocks: _document.blocks,
            );
        _customUnderlayFilterLayers ??= Set<String>.from(visibleLayerNames);

        // Verify how many entities in Model space will actually be visible
        final modelEntities = _document.layoutEntities['Model'] ?? _document.entities;
        int visibleCount = 0;
        for (final e in modelEntities) {
          if (e is DxfInsert) {
            final block = _document.blocks[e.blockName];
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
            _document.layers[entry.key]?.isVisible = entry.value;
          }
          _underlayRevision++;
          return;
        }

        for (final layer in _document.layers.values) {
          layer.isVisible = visibleLayerNames.contains(layer.name);
        }

        // Propagate filter to all subsequent storey layouts in the BIM project
        if (widget.bimContext != null) {
          for (final entry in widget.bimContext!.underlaysByStorey.entries) {
            final storeyId = entry.key;
            final doc = entry.value;
            if (storeyId == _project.activeStorey.id) continue;
            final sVisible = _customUnderlayFilterLayers ??
                StructuralUnderlayFilter.filterLayers(
                  layers: doc.layers.values,
                  entities: doc.entities,
                  blocks: doc.blocks,
                );
            if (sVisible.isNotEmpty) {
              for (final l in doc.layers.values) {
                l.isVisible = sVisible.contains(l.name);
              }
            }
            final sVisMap = {for (final l in doc.layers.values) l.name: l.isVisible};
            widget.bimContext!.onLayerVisibilityChanged(storeyId, sVisMap);
          }
        }
      } else {
        for (final entry in _originalLayerVisibility.entries) {
          _document.layers[entry.key]?.isVisible = entry.value;
        }

        // Restore all layers across all storeys
        if (widget.bimContext != null) {
          for (final entry in widget.bimContext!.underlaysByStorey.entries) {
            final storeyId = entry.key;
            final doc = entry.value;
            if (storeyId == _project.activeStorey.id) continue;
            for (final l in doc.layers.values) {
              l.isVisible = true;
            }
            final sVisMap = {for (final l in doc.layers.values) l.name: l.isVisible};
            widget.bimContext!.onLayerVisibilityChanged(storeyId, sVisMap);
          }
        }
      }

      _underlayRevision++;

      if (widget.bimContext != null) {
        final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
        widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
      }
    }

    if (mounted) {
      setState(execute);
    } else {
      execute();
    }
  }

  void _showUnderlayFilterConfig() {
    final activeSet = _customUnderlayFilterLayers ??
        StructuralUnderlayFilter.filterLayers(
          layers: _document.layers.values,
          entities: _document.entities,
          blocks: _document.blocks,
        );
    _customUnderlayFilterLayers ??= Set<String>.from(activeSet);

    UnderlayFilterConfigSheet.show(
      context: context,
      document: _document,
      activeFilterLayers: _customUnderlayFilterLayers!,
      isDark: _canvasTheme.isDark,
      onFilterLayersChanged: (newLayers) {
        setState(() {
          _customUnderlayFilterLayers = Set<String>.from(newLayers);
          if (_underlayFilterActive) {
            for (final layer in _document.layers.values) {
              layer.isVisible = _customUnderlayFilterLayers!.contains(layer.name);
            }
            _underlayRevision++;
          }
        });
        if (widget.bimContext != null) {
          final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
          widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
        }
      },
      onResetToAuto: () {
        setState(() {
          _customUnderlayFilterLayers = null;
          if (_underlayFilterActive) {
            _applyUnderlayFilter(true);
          }
        });
      },
    );
  }

  void _handleLayerContextAtPoint(Offset localPos) {
    final scenePoint = _transformController.toScene(localPos);
    final cadPoint = _sceneToCad(scenePoint);

    final fitScale = _getCadFitScale();
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final toleranceCad = 26.0 / (fitScale * currentScale.clamp(0.0001, 10000.0));

    final entity = DxfSnapHelper.hitTestEntity(
      document: _document,
      cadPoint: cadPoint,
      toleranceCad: toleranceCad,
    );

    if (entity != null) {
      HapticFeedback.heavyImpact();
      final layerName = entity.layer.trim().isEmpty ? '0' : entity.layer;
      final layer = _document.layers[layerName];

      DxfEntityContextSheet.show(
        context: context,
        entity: entity,
        document: _document,
        isDark: _canvasTheme.isDark,
        onHideLayer: () {
          if (layer != null) {
            setState(() {
              layer.isVisible = false;
              _underlayRevision++;
              if (_customUnderlayFilterLayers != null) {
                _customUnderlayFilterLayers!.remove(layerName);
              }
            });
            if (widget.bimContext != null) {
              final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
              widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.layerHiddenNotice(layerName)),
                action: SnackBarAction(
                  label: context.l10n.undoAction,
                  onPressed: () {
                    setState(() {
                      layer.isVisible = true;
                      _underlayRevision++;
                      if (_customUnderlayFilterLayers != null) {
                        _customUnderlayFilterLayers!.add(layerName);
                      }
                    });
                    if (widget.bimContext != null) {
                      final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
                      widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
                    }
                  },
                ),
              ),
            );
          }
        },
        onIsolateLayer: () {
          setState(() {
            for (final l in _document.layers.values) {
              l.isVisible = (l.name == layerName);
            }
            _underlayRevision++;
          });
          if (widget.bimContext != null) {
            final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
            widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
          }
        },
        onShowAllLayers: () {
          setState(() {
            for (final l in _document.layers.values) {
              l.isVisible = true;
            }
            _underlayRevision++;
          });
          if (widget.bimContext != null) {
            final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
            widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
          }
        },
        onOpenLayerManager: _showLayersSheet,
      );
    }
  }

  void _showLayersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DxfLayerSheet(
        document: _document,
        isDark: true,
        additionalLayerCounts: {
          for (final entry in BimUnderlayMetadata.dynamicLayers(_document).entries)
            entry.value: entry.key == 'axes' ? _project.activeStorey.gridAxes.length :
              {for (final slab in [..._project.activeStorey.slabs,
                ...?_floorSlabStorey?.slabs, ...?_ceilingSlabStorey?.slabs]) slab.id}.length,
        },
        onLayersChanged: () {
          if (widget.bimContext != null) {
            final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
            widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
          }
          setState(() {
            _underlayRevision++;
            if (!_showBimSlabs) {
              _editingSlab = null;
              _selectedOpening = null;
              _selectedSlabVertexIndex = null;
            }
            if (!_showBimAxes) _selectedGridAxis = null;
          });
        },
      ),
    );
  }

  void _applyDetectedWallsAndAxes(WallAxisDetectionResult result) {
    if (!result.hasWallsFound) return;

    _pushUndo();
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    WallAxisDetector.applyToDocument(_document, result, isBulgarian: isBg);

    // Auto-detect slab layers by keyword and integrate into underlay filter
    final slabResult = StructuralUnderlayFilter.detectSlabLayers(_document);
    if (slabResult.hasValidLayers) {
      _customUnderlayFilterLayers ??= StructuralUnderlayFilter.filterLayers(
        layers: _document.layers.values,
        entities: _document.entities,
        blocks: _document.blocks,
      );
      _customUnderlayFilterLayers!.addAll(slabResult.detectedLayers);
      for (final slabLayer in slabResult.detectedLayers) {
        if (_document.layers.containsKey(slabLayer)) {
          _document.layers[slabLayer]!.isVisible = true;
        }
      }
    }

    _applyUnderlayFilter(true);
    if (widget.bimContext != null) {
      widget.bimContext!.onWallsDetected(_project.activeStorey.id);
    }

    // Convert detected centerlines to native StructuralGridAxis elements
    final newGridAxes = WallAxisDetector.convertToStructuralGridAxes(
      result.snappedCenterlines,
      isBulgarian: isBg,
      scale: result.detectedScale,
    );

    final updatedAxes=ProjectGridAxes.merge([
      ..._project.effectiveGridAxes,
      for(final a in newGridAxes) a.copyWith(sourceStoreyIds:
        widget.bimContext==null ? const [] : [_project.activeStorey.id]),
    ],_cadUnitsPerMeter,isBulgarian:isBg);
    _updateProjectGridAxes(updatedAxes);

    // Automatically generate initial dynamic slabs in the same step if none exist
    final active = _project.activeStorey;
    final higherStoreys = _project.storeys
        .where((s) => s.elevation > active.elevation).toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final hasCeilingLayout = widget.bimContext == null ||
        (higherStoreys.isNotEmpty &&
          widget.bimContext!.underlaysByStorey.containsKey(higherStoreys.first.id));
    if (hasCeilingLayout && (active.slabs.isEmpty || !active.slabs.any((s) => s.id.startsWith(SlabSeedGenerator.prefix(active.id))))) {
      var slabMeta = BimUnderlayMetadata.read(_document);
      List<(Offset, Offset)>? wallReferences;
      if (slabMeta == null) {
        final envelope = SlabEnvelopeDetector.detect(result, document: _document);
        final projections = SlabProjectionDetector.detect(
          _document,
          envelope,
          result.detectedScale,
          wallLayers: result.selectedWallPairs
              .expand((p) => [p.segmentA.sourceLayer, p.segmentB.sourceLayer])
              .toSet(),
        );
        slabMeta = {
          'slabEnvelope': envelope.toJson(),
          'slabProjections': projections.map((p) => p.toJson()).toList(),
        };
        wallReferences = [...result.wallContourSegments, ...result.closureSegments];
      }
      final seeds = SlabSeedGenerator.generate(
        metadata: slabMeta,
        document: _document,
        storeyId: active.id,
        existing: active.slabs,
        unitsPerMeter: _cadUnitsPerMeter,
        thickness: _currentSlabThickness,
        floorOwned: widget.bimContext != null,
        wallReferences: wallReferences,
      );
      if (seeds.isNotEmpty) {
        final currentActive = _project.activeStorey;
        final coloredSeeds = [
          for (var i = 0; i < seeds.length; i++)
            seeds[i].copyWith(
              colorValue: SlabColors.forSlab(seeds[i], fallback: Structural2dPainter.slabPalette[
                  (currentActive.slabs.length + i) % Structural2dPainter.slabPalette.length]).toARGB32(),
            ),
        ];
        _updateActiveStorey(currentActive.copyWith(slabs: [...currentActive.slabs, ...coloredSeeds]));
      }
    }

    _activeTool = StructuralDrawTool.gridAxis;
    _runAnalysis();
    setState(() {});

    final String wallMsg = context.l10n.wallsAndAxesGeneratedSuccess(
      newGridAxes.length,
      result.wallContourSegments.length,
      result.detectedUnitName,
    );
    final String slabMsg = slabResult.hasValidLayers
        ? context.l10n.slabLayerAddedToFilter(slabResult.detectedLayers.join(', '))
        : context.l10n.noSlabLayerDetectedOrEmpty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$wallMsg\n$slabMsg'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
  }

  void _checkAutoDetectWallsOnStartup() {
    // BIM underlays are analysed once at import; empty/deleted axes stay empty.
    if (widget.bimContext != null) {
      return;
    }
    if (!mounted) return;
    final isBg = Localizations.localeOf(context).languageCode == 'bg';

    // If axes are already populated in active storey (e.g. from initState or saved project)
    if (_project.effectiveGridAxes.isNotEmpty) {
      if (widget.initialDetectionResult != null || _document.layers.containsKey('WALLS_250')) {
        _applyUnderlayFilter(true);
        _runAnalysis();
        setState(() {});
      }
      return;
    }

    // If initialDetectionResult was provided from layer prep modal, apply it now
    if (widget.initialDetectionResult != null && widget.initialDetectionResult!.hasWallsFound) {
      _applyDetectedWallsAndAxes(widget.initialDetectionResult!);
      return;
    }

    // Check if axes can be imported from an external DXF AXIS layer
    final importedAxes = WallAxisDetector.extractGridAxesFromDocument(
      _document,
      isBulgarian: isBg,
    );
    if (importedAxes.isNotEmpty) {
      _updateProjectGridAxes(importedAxes);
      _applyUnderlayFilter(true);
      _runAnalysis();
      setState(() {
        _activeTool = StructuralDrawTool.gridAxis;
      });
      return;
    }

    // If WALLS_250 exists but gridAxes is empty, re-detect to populate dynamic gridAxes
    if (_document.layers.containsKey('WALLS_250')) {
      final result = WallAxisDetector.detect(_document);
      if (result.hasWallsFound) {
        _applyDetectedWallsAndAxes(result);
      }
      return;
    }

    final result = WallAxisDetector.detect(_document);
    if (!result.hasWallsFound || !mounted) return;

    final best = result.bestGroup!;
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFFF5252), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.autoDetectWallsAndAxes,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.wallCandidatesFound(
                            best.pairCount,
                            best.totalOverlapLength.toStringAsFixed(1),
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF00E5FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.autoDetectWallsPrompt(
                  '25',
                  result.detectedUnitName,
                  best.layerName,
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      context.l10n.cancel,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.l10n.isolateWallsAndGenerateAxes),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _applyDetectedWallsAndAxes(result);
      }
    });
  }

  void _runManualAutoDetectWalls() {
    if (widget.bimContext != null) {
      // Reprocess the preserved source via the project's underlay management.
      widget.bimContext!.onManageStoreys();
      return;
    }
    final result = WallAxisDetector.detect(_document);
    if (!result.hasWallsFound) {
      final slabResult = StructuralUnderlayFilter.detectSlabLayers(_document);
      if (slabResult.hasValidLayers) {
        _customUnderlayFilterLayers ??= StructuralUnderlayFilter.filterLayers(
          layers: _document.layers.values,
          entities: _document.entities,
          blocks: _document.blocks,
        );
        _customUnderlayFilterLayers!.addAll(slabResult.detectedLayers);
        for (final slabLayer in slabResult.detectedLayers) {
          if (_document.layers.containsKey(slabLayer)) {
            _document.layers[slabLayer]!.isVisible = true;
          }
        }
        _applyUnderlayFilter(true);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.noWallsDetected}\n${context.l10n.slabLayerAddedToFilter(slabResult.detectedLayers.join(', '))}',
            ),
            backgroundColor: const Color(0xFF1E88E5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.noWallsDetected}\n${context.l10n.noSlabLayerDetectedOrEmpty}',
            ),
            backgroundColor: const Color(0xFF33333D),
          ),
        );
      }
      return;
    }
    _applyDetectedWallsAndAxes(result);
  }

  Future<void> _showExportDialog() async {
    if (widget.bimContext != null) {
      await widget.bimContext!.onExport(context, _project, _project.activeStorey.id);
      return;
    }
    final baseName = widget.title ?? 'structural_model';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.exportBimModel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.data_object_rounded, color: Color(0xFF00E5FF)),
                ),
                title: Text(
                  context.l10n.exportBimJson,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'JSON (.bim.json)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final file = await StructuralPersistenceService.exportToJsonFile(
                      project: _project,
                      baseName: baseName,
                    );
                    await StructuralPersistenceService.shareFile(file);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
                      );
                    }
                  }
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.architecture_rounded, color: Color(0xFFFFB300)),
                ),
                title: Text(
                  context.l10n.exportStructuralDxf,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'AutoCAD DXF (S-COL, S-WALL, S-BEAM, S-SLAB, S-AXIS)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final file = await StructuralPersistenceService.exportToDxfFile(
                      project: _project,
                      baseName: baseName,
                      cadUnitsPerMeter: _cadUnitsPerMeter,
                    );
                    await StructuralPersistenceService.shareFile(file);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTool(StructuralDrawTool tool) {
    _cancelContourEditors();
    _beamMove?.cancel();
    _beamMove = null;
    _cancelAxisGesture();
    if (_duplicateDraft != null) _cancelDuplicateDrag();
    if (_isEditingSlab) _cancelSlabCorrection();
    setState(() {
      _activeTool = tool;

      _selectedColumn = null;
      _selectedShearWall = null;
      _selectedBeam = null;
      _selectedOpening = null;
      _selectedOpeningVertexIndex = null;
      _selectedGridAxis = null;
      _editingSlab = null;
      _selectedSlabVertexIndex = null;
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _isMovingOpening = false;
      _wallStartCad = null;
      _beamStartCad = null;
      _openingStartCad = null;
      _measurementStartCad = null;
      _activeMeasurement = null;
      _firstWallEdgeStartCad = null;
      _firstWallEdgeEndCad = null;
      _slabStartCornerCad = null;
      _slabPointsCad.clear();
      _openingPointsCad.clear();
    });
  }

  void _toggleUnderlayFilter() {
    setState(() {
      _isFilteringUnderlay = true;
    });
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        final disabling = _underlayFilterActive;
        _applyUnderlayFilter(!disabling);
        if (disabling) _selectTool(StructuralDrawTool.layers);
        _isFilteringUnderlay = false;
      });
    });
  }

  void _syncColumnNumbersAcrossStoreys() {
    final (syncedProject, count) = StructuralColumnSynchronizer.synchronize(
      _project,
      cadUnitsPerMeter: _cadUnitsPerMeter,
    );
    setState(() {
      _project = syncedProject;
    });
    _saveProject();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.syncColumnsSuccess(count))),
    );
  }

  StoreyLevel? get _floorSlabStorey => widget.bimContext == null
      ? null : _project.floorSlabStoreyFor(_project.activeStorey);

  StoreyLevel? get _ceilingSlabStorey => widget.bimContext == null
      ? null : _project.ceilingSlabStoreyFor(_project.activeStorey);

  void _openCurrentSlab() {
    final slabs = _project.activeStorey.slabs;
    if (slabs.isEmpty) return;
    setState(() {
      _selectedColumn = null;
      _selectedShearWall = null;
      _selectedBeam = null;
      _selectedGridAxis = null;
      _selectedOpening = null;
      _isMovingOpening = false;
      _slabStartCornerCad = null;
      _openingStartCad = null;
      _wallStartCad = null;
      _beamStartCad = null;
      _slabPointsCad.clear();
      _openingPointsCad.clear();
      _activeTool = StructuralDrawTool.slab;
    });
    final name = BimUnderlayMetadata.dynamicLayers(_document)['slabs'];
    if (name != null) {
      _document.layers[name]?.isVisible = true;
      _document.layers[name]?.isFrozen = false;
      widget.bimContext?.onLayerVisibilityChanged(_project.activeStorey.id,
        {for (final l in _document.layers.values) l.name: l.isVisible});
    }
    _startSlabCorrection(slabs.first);
  }

  // --- Storey Management Actions ---

  void _openStoreyManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StoreyManagerSheet(
        project: _project,
        onManageStoreys: widget.bimContext?.onManageStoreys,
        onSelectStorey: (idx) {
          setState(() {
            _project = _project.copyWith(activeStoreyIndex: idx);

            _editingSlab = null;
            _initialSlabBeforeCorrection = null;
            _initialSlabCorrectionProject = null;
            _slabCorrectionUndoStack.clear();
            _selectedOpening = null;
            _isMovingOpening = false;
            _slabPointsCad.clear();
            _openingPointsCad.clear();
            _wallStartCad = null;
            _originalLayerVisibility.clear();
            for (final entry in _document.layers.entries) {
              _originalLayerVisibility[entry.key] = entry.value.isVisible;
            }
            if (_underlayFilterActive) {
              _applyUnderlayFilter(true);
            }
            _runAnalysis();
            _ensureSlabsPopulatedForActiveStorey();
          });
          _saveProject();
        },
        onGhostModeChanged: (mode) {
          setState(() => _project = _project.copyWith(ghostMode: mode));
          _saveProject();
        },
        onUpdateHeight: (idx, newH) {
          final storeys = List<StoreyLevel>.from(_project.storeys);
          storeys[idx] = storeys[idx].copyWith(height: newH);
          setState(() {
            _project = _project.copyWith(storeys: storeys);
            _runAnalysis();
          });
          _saveProject();
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
            gridAxes: _project.effectiveGridAxes,
          );
          final updated = List<StoreyLevel>.from(_project.storeys)..add(newStorey);
          setState(() {
            _project = _project.copyWith(
              storeys: updated,
              activeStoreyIndex: updated.length - 1,
            );
            _runAnalysis();
          });
          _saveProject();
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
          final (syncedProject, _) = StructuralColumnSynchronizer.synchronize(
            _project.copyWith(
              storeys: updated,
              activeStoreyIndex: updated.length - 1,
            ),
            cadUnitsPerMeter: _cadUnitsPerMeter,
          );
          setState(() {
            _project = syncedProject;
            _runAnalysis();
          });
          _saveProject();
          HapticFeedback.heavyImpact();
        },
        onSyncColumns: _syncColumnNumbersAcrossStoreys,
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
          _saveProject();
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

  void _openVerticalCapacityReport() {
    final assessments={for(final floor in _project.ceilingStoreys) floor.id:
      SupportLayoutEvaluator.evaluate(_project,floor.copyWith(gridAxes:_project.effectiveGridAxes),_cadUnitsPerMeter)};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => VerticalCapacitySheet(report: _verticalCapacityReport,assessments:assessments),
    );
  }

  void _openSeismicReport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SeismicAnalysisSheet(report: _seismicAnalysisReport,
        onLocateElement: (storeyId, elementId, isWall) {
          Navigator.of(ctx).pop();
          _locateSeismicElement(storeyId, elementId, isWall);
        },
        onEditLoads: () {
          Navigator.of(ctx).pop();
          _editSeismicLoads();
        }),
    );
  }

  void _locateSeismicElement(String storeyId, String elementId, bool isWall) {
    final index = _project.storeys.indexWhere((s) => s.id == storeyId);
    if (index < 0) return;
    final storey = _project.storeys[index];
    StructuralColumn? column;
    StructuralShearWall? wall;
    if (isWall) {
      for (final candidate in storey.shearWalls) { if(candidate.id == elementId) wall = candidate; }
    } else {
      for (final candidate in storey.columns) { if(candidate.id == elementId) column = candidate; }
    }
    if (column == null && wall == null) return;
    final center = wall?.center ?? column!.center;
    setState(() {
      _project = _project.copyWith(activeStoreyIndex: index);

      _selectedColumn = column;
      _selectedShearWall = wall;
      _selectedBeam = null;
      _selectedOpening = null;
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _activeTool = isWall ? StructuralDrawTool.shearWall : StructuralDrawTool.column;
      _isMovingColumn = false;
      _isMovingShearWall = false;
      _slabPointsCad.clear();
      _openingPointsCad.clear();
      _wallStartCad = null;
      _beamStartCad = null;
      _runAnalysis();
    });
    if (!_viewportSize.isEmpty && center.dx.isFinite && center.dy.isFinite) {
      final scene = _cadToScene(center);
      final rawExtent = wall?.length ?? math.max(column!.width, column.height);
      final extent = rawExtent.isFinite ? rawExtent : _cadUnitsPerMeter;
      final edge = _cadToScene(center + Offset(math.max(extent, _cadUnitsPerMeter), 0));
      final zoom = (math.min(_viewportSize.width,_viewportSize.height)*0.45 /
        math.max((edge-scene).distance, 1e-6)).clamp(0.001,10000.0);
      final matrix = Matrix4.diagonal3Values(zoom,zoom,1);
      matrix.setEntry(0,3,_viewportSize.width/2-scene.dx*zoom);
      matrix.setEntry(1,3,_viewportSize.height*.4-scene.dy*zoom);
      _transformController.value = matrix;
    }
  }

  Future<void> _editSeismicLoads() async {
    final updated = await showDialog<StructuralProject>(context: context,
      builder: (_) => SeismicLoadDialog(project: _project));
    if (!mounted || updated == null) return;
    _pushUndo();
    setState(() {
      _project = updated;
      _editingSlab = null;
      _initialSlabBeforeCorrection = null;
      _runAnalysis();
    });
    _saveProject();
    _openSeismicReport();
  }

  void _open3dViewport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Structural3dViewport(
          project: _project,
          cantileverZones: _analysisSummary.zones,
          verticalReport: _verticalCapacityReport,
          seismicReport: _seismicAnalysisReport,
          cadUnitsPerMeter: _cadUnitsPerMeter,
          onExit: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 540;

    final layersButton = IconButton(
      icon: const Icon(Icons.layers_outlined, color: Colors.white70, size: 20),
      tooltip: context.l10n.layersTooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: _showLayersSheet,
    );

    final navigationButton = IconButton(
      key: const ValueKey('bim-navigation'),
      icon: Icon(Icons.pan_tool_rounded, size: 18,
        color: _activeTool == StructuralDrawTool.select ? const Color(0xFF00E5FF) : Colors.white70),
      tooltip: context.l10n.toolNavigation,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
      onPressed: () => _selectTool(StructuralDrawTool.select),
    );

    final filterButton = Tooltip(
      message: _underlayFilterActive
          ? context.l10n.structuralFilterActive
          : context.l10n.structuralFilterInactive,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _toggleUnderlayFilter,
        onLongPress: _showUnderlayFilterConfig,
        child: Container(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          alignment: Alignment.center,
          decoration: _underlayFilterActive
              ? BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            _underlayFilterActive
                ? Icons.filter_alt_rounded
                : Icons.filter_alt_outlined,
            color: _underlayFilterActive
                ? const Color(0xFF00E5FF)
                : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );

    final undoButton = IconButton(
      icon: Icon(Icons.undo_rounded,
          color: _history.canUndo ? Colors.white : Colors.white24,
          size: 20),
      tooltip: context.l10n.undoAction,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: _history.canUndo ? _undo : null,
    );

    final exportButton = IconButton(
      icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
      tooltip: context.l10n.exportBimModel,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: _showExportDialog,
    );

    final viewport3dButton = IconButton(
      icon: const Icon(Icons.view_in_ar_rounded, color: Color(0xFFFFB300), size: 20),
      tooltip: context.l10n.structural3dView,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: _open3dViewport,
    );

    final moreMenu = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      color: const Color(0xFF242426),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) {
        switch (value) {
          case 'toggle_snap':
            setState(() => _snapEnabled = !_snapEnabled);
            HapticFeedback.selectionClick();
            break;
          case 'toggle_foundations':
            setState(() => _showGroundFoundations = !_showGroundFoundations);
            HapticFeedback.selectionClick();
            break;
          case 'layers':
            _showLayersSheet();
            break;
          case 'filter':
            _toggleUnderlayFilter();
            break;
          case 'filter_config':
            _showUnderlayFilterConfig();
            break;
          case 'sync_columns':
            _syncColumnNumbersAcrossStoreys();
            break;
          case 'display_settings':
            _showDisplaySettingsSheet();
            break;
          case 'theme_toggle':
            setState(() {
              _canvasTheme = _canvasTheme.isDark
                  ? DxfCanvasTheme.paperWhite
                  : DxfCanvasTheme.darkCad;
            });
            break;
          case 'auto_walls':
            _runManualAutoDetectWalls();
            break;
          case 'clear_structure':
            _clearStructuralSupports();
            break;
          case 'export':
            _showExportDialog();
            break;
        }
      },
      itemBuilder: (context) => [
          PopupMenuItem(value: 'clear_structure',
            child: Text(context.l10n.bimClearStructure,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))),
        PopupMenuItem(
          value: 'toggle_snap',
          child: Row(
            children: [
              Icon(
                _snapEnabled ? Icons.grain_rounded : Icons.lens_blur_rounded,
                size: 20,
                color: _snapEnabled ? const Color(0xFF00E5FF) : Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                _snapEnabled ? context.l10n.snapEnabledTooltip : context.l10n.snapDisabledTooltip,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_foundations',
          child: Row(
            children: [
              Icon(
                _showGroundFoundations ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: _showGroundFoundations ? const Color(0xFF00E5FF) : Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.toggleGroundFoundations,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        if (isCompact)
          PopupMenuItem(
            value: 'layers',
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, size: 20, color: Colors.white70),
                const SizedBox(width: 12),
                Text(context.l10n.layersTooltip,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'filter_config',
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF00E5FF)),
              const SizedBox(width: 12),
              Text(context.l10n.manageUnderlayFilter,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (_project.storeys.length > 1)
          PopupMenuItem(
            value: 'sync_columns',
            child: Row(
              children: [
                const Icon(Icons.sync_alt_rounded, size: 20, color: Color(0xFF00E5FF)),
                const SizedBox(width: 12),
                Text(context.l10n.syncColumnsAcrossStoreys,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'display_settings',
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 20, color: Colors.white70),
              const SizedBox(width: 12),
              Text(context.l10n.displaySettings,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'theme_toggle',
          child: Row(
            children: [
              Icon(
                _canvasTheme.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                _canvasTheme.isDark
                    ? context.l10n.cadThemePaperWhite
                    : context.l10n.cadThemeDarkCad,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'auto_walls',
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFFF5252)),
              const SizedBox(width: 12),
              Text(context.l10n.autoDetectWallsAndAxes,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (isCompact)
          PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                const Icon(Icons.share_outlined, size: 20, color: Colors.white70),
                const SizedBox(width: 12),
                Text(context.l10n.exportBimModel,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
      ],
    );

    if (!isCompact) {
      return [
        layersButton,
        navigationButton,
        filterButton,
        undoButton,
        exportButton,
        viewport3dButton,
        moreMenu,
        const SizedBox(width: 4),
      ];
    }

    // Compact mode for narrow/mobile screens to prevent RenderFlex horizontal overflows:
    // Display primary actions directly with Underlay filter quick button
    return [
      navigationButton,
      filterButton,
      undoButton,
      viewport3dButton,
      moreMenu,
      const SizedBox(width: 4),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final floor = _floorSlabStorey;
    final ceiling = _ceilingSlabStorey;
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          onTap: _openStoreyManager,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_rounded,
                    size: 16, color: Color(0xFF00E5FF)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _project.activeStorey.elevationLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
        actions: _buildAppBarActions(context),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          Offset? previewAxisStart;
          Offset? previewAxisEnd;
          if (_activeTool == StructuralDrawTool.gridAxis &&
              _firstWallEdgeStartCad != null &&
              _firstWallEdgeEndCad != null &&
              _currentCadCoord != null) {
            final double fitScale = _getCadFitScale();
            final double currentScale = _transformController.value.getMaxScaleOnAxis();
            final double toleranceCad = 36.0 / (fitScale * currentScale.clamp(0.001, 10000.0));
            final seg2 = _findClosestSegmentInCad(_currentCadCoord!, toleranceCad * 2.0);
            if (seg2 != null) {
              final rawPreviewAxis = StructuralGridAxis.fromTwoSegments(
                id: 'preview',
                name: _getSuggestedAxisName(_firstWallEdgeStartCad!, _firstWallEdgeEndCad!),
                a1: _firstWallEdgeStartCad!,
                a2: _firstWallEdgeEndCad!,
                b1: seg2.$1,
                b2: seg2.$2,
                extensionLength: 1.5 * _cadUnitsPerMeter,
              );
              if (rawPreviewAxis != null) {
                final existingParallel = _project.activeStorey.gridAxes
                    .where((a) => a.isParallelTo(rawPreviewAxis))
                    .firstOrNull;
                final previewAxis = existingParallel != null
                    ? rawPreviewAxis.alignWith(existingParallel)
                    : rawPreviewAxis;
                previewAxisStart = previewAxis.start;
                previewAxisEnd = previewAxis.end;
              }
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // One shared owner routes tools and camera; the native viewer
              // temporarily remains a transform-only rendering bridge.
              Positioned.fill(
                child: BimEditingViewport(
                  controller: _viewportNavigation,
                  inputKey: const ValueKey('construction-viewport-input'),
                  interactionKey: (_document, _project.activeStorey.id, _activeTool),
                  singlePointerPan: true,
                  touchHoldToPlace: true,
                  holdExistingHandles: true,
                  isDraggingHandle: () => _viewportDragging,
                  onToolDown: _handlePointerDown,
                  onToolMove: _moveViewportTool,
                  onToolHover: (_) {},
                  onToolUp: _releaseViewportTool,
                  onToolHoldStart: _beginViewportHold,
                  onToolCancel: _cancelViewportTool,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    panEnabled: false,
                    scaleEnabled: false,
                    minScale: .001,
                    maxScale: 1000,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: Container(
                        color: _canvasTheme.bgColor,
                        width: _viewportSize.width,
                        height: _viewportSize.height,
                        child: Stack(
                          children: [
                            // CAD DWG/DXF Architecture Underlay (dimmed)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  size: _viewportSize,
                                  isComplex: true,
                                  willChange: false,
                                  painter: DxfPainter(
                                    document: _document,
                                    theme: _canvasTheme,
                                    activeLayout: 'Model',
                                    currentScale: _renderScale,
                                    visibleCadRect: _underlayFilterActive ? null : _getVisibleCadRect(),
                                    settings: _displaySettings,
                                    drawingColorOverride: _canvasTheme.isDark
                                        ? const Color(0xFF92979C)
                                        : const Color(0xFF757A80),
                                    drawingStrokeWidthOverride: 0.8,
                                    originalStyleLayers: _underlayFilterActive ? {
                                      if (BimUnderlayMetadata.read(_document)?['wallLayer'] case final String layer) layer,
                                      'WALLS_250',
                                    } : const {},
                                    revision: _underlayRevision,
                                    entityFilter: (_underlayFilterActive && BimUnderlayMetadata.read(_document) == null)
                                        ? _filterUnderlayEntity
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            // Structural Elements Layer (Columns, Walls, Slabs, Ghost Story, Cantilever badges)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: Structural2dPainter(
                                  currentStorey: _withBeamMove(_withDuplicate((_axisPreviewProject ?? _project).activeStorey)),
                                  showSlabs: _showBimSlabs,
                                  showFloorSlabs: widget.bimContext == null || _isEditingSlab,
                                  showGridAxes: _showBimAxes,
                                  floorSlabStorey: floor,
                                  ceilingSlabStorey: ceiling,
                                  ghostStorey: _project.ghostStorey,
                                  hasBasement: _project.hasBasement,
                                  foundationType: _project.foundationType,
                                  stripFoundations: (_showGroundFoundations && _project.activeStorey.elevation.abs() < 1e-4 && !_project.hasBasement)
                                      ? _project.computeDefaultStripFoundations(_project.activeStorey, cadUnitsPerMeter: _cadUnitsPerMeter)
                                      : null,
                                  matFoundation: (_showGroundFoundations && _project.activeStorey.elevation.abs() < 1e-4 && !_project.hasBasement)
                                      ? _project.computeDefaultMatFoundation(_project.activeStorey, cadUnitsPerMeter: _cadUnitsPerMeter)
                                      : null,
                                  cantileverZones: _analysisSummary.zones,
                                  verticalReport: _verticalCapacityReport,
                                  seismicReport: _seismicAnalysisReport,
                                  showCantileverHeatmap: true,
                                  showSlabSpanOverlay: true,
                                  supportSpanChecks: _liveSupportSpanChecks,
                                  spanFocusCad: _spanFocusCad,
                                  spanVisibleCadRect: Rect.fromPoints(
                                    _sceneToCad(_transformController.toScene(Offset.zero)),
                                    _sceneToCad(_transformController.toScene(
                                        Offset(_viewportSize.width,_viewportSize.height)))),
                                  activeTool: _activeTool,
                                  previewColumn: _currentColumnPreset.copyWith(
                                    width: _currentColumnPreset.width * _cadUnitsPerMeter,
                                    height: _currentColumnPreset.height * _cadUnitsPerMeter,
                                  ),
                                  previewColumnPos: (_isPlacingWithHold && _activeTool == StructuralDrawTool.column) ? _currentCadCoord : null,
                                  previewShearWallPos: (_isPlacingWithHold && _activeTool == StructuralDrawTool.shearWall) ? _currentCadCoord : null,
                                  previewWallLength: _currentWallLength * _cadUnitsPerMeter,
                                  previewWallThickness: _currentWallThickness * _cadUnitsPerMeter,
                                  previewWallRotationRad: _currentWallRotationRad,
                                  movingShearWall: _isMovingShearWall ? _selectedShearWall : null,
                                  movingShearWallPos: _isMovingShearWall ? _currentCadCoord : null,
                                  magneticGuideLines: _activeMagneticGuides,
                                  dynamicDimensionLine: _activeDynamicDimensionLine,
                                  dynamicDimensionText: _liveDimensionText,
                                  wallStartPos: _wallStartCad,
                                  beamStartPos: _beamStartCad,
                                  beamPreviewWidth: _currentBeamWidth * _cadUnitsPerMeter,
                                  openingStartCornerCad: _openingStartCad,
                                  selectedOpening: _selectedOpening,
                                  selectedOpeningVertexIndex: _selectedOpeningVertexIndex,
                                  draggingOpeningVertexIndex: _draggingOpeningVertexIndex,
                                  draggingOpeningVertexPos: _draggingOpeningVertexCad,
                                  mergeCandidateOpeningVertexIndex: _mergeCandidateOpeningVertexIndex,
                                  extrudingOpeningGrip: _activeOpeningGrip,
                                  extrudingOpeningDistance: _isExtrudingEdge ? _extrusionDistanceCad : null,
                                  previewOpeningOffsetPolygon: _isExtrudingEdge ? _previewOpeningOffsetPolygon : null,
                                  movingOpeningPolygon: _isMovingOpening && _movingOpeningRelativeOffsets != null
                                      ? _movingOpeningRelativeOffsets!
                                          .map((r) => (_currentCadCoord ?? _movingOpeningOriginalCenter ?? Offset.zero) + r)
                                          .toList()
                                      : null,
                                  currentCursorCad: _currentCadCoord,
                                  slabStartCornerCad: _slabStartCornerCad,
                                  slabPointsInProgress: _slabPointsCad,
                                  openingPointsInProgress: _openingPointsCad,
                                  activeOpeningType: _currentOpeningType,
                                  extrudingGrip: _activeGrip,
                                  extrusionDistance: _isExtrudingEdge ? _extrusionDistanceCad : null,
                                  activeParallelSnap: _isExtrudingEdge ? _activeParallelSnap : null,
                                  previewSlabOffsetPolygon: _isExtrudingEdge ? _previewSlabOffsetPolygon : null,
                                  l10n: context.l10n,
                                  selectedColumnId: _selectedColumn?.id,
                                  selectedShearWallId: _selectedShearWall?.id,
                                  selectedBeamId: _selectedBeam?.id,
                                  selectedGridAxisId: _selectedGridAxis?.id,
                                  gridAxisStoreys: (_axisPreviewProject ?? _project).storeys,
                                  axisOffsetPreview: _getAxisOffsetPreview(),
                                  columnOffsetPreview: _getColumnOffsetPreview(),
                                  firstWallEdgeStartCad: _firstWallEdgeStartCad,
                                  firstWallEdgeEndCad: _firstWallEdgeEndCad,
                                  gridAxisPreviewStartCad: previewAxisStart,
                                  gridAxisPreviewEndCad: previewAxisEnd,
                                  movingColumn: _isMovingColumn ? _selectedColumn : null,
                                  movingColumnPos: _isMovingColumn ? _currentCadCoord : null,
                                  selectedSlabId: _editingSlab?.id,
                                  draggingSlabVertexIndex: _draggingSlabVertexIndex,
                                  draggingSlabVertexPos: _draggingSlabVertexCad,
                                  mergeCandidateVertexIndex: _mergeCandidateSlabVertexIndex,
                                  activeMeasurement: _activeMeasurement,
                                  measurementStartCad: _measurementStartCad,
                                  cadUnitsPerMeter: _cadUnitsPerMeter,
                                  zoomScale: _transformController.value.getMaxScaleOnAxis(),
                                  cadToScene: _cadToScene,
                                  cadScale: _getCadFitScale(),
                                ),
                              ),
                            ),
                            if (_isFilteringUnderlay)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE61E1E24),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF00E5FF)),
                                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.l10n.filteringUnderlay,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
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
              if ((_isPlacingWithHold ||
                      _isMovingColumn ||
                      _isMovingShearWall ||
                      _isMovingOpening ||
                      (_activeTool == StructuralDrawTool.measure &&
                          _measurementStartCad != null)) &&
                  _touchScreenPos != null &&
                  _targetScreenPos != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: StructuralPointerOverlay(
                      painter: StructuralPointerPainter(
                        touchPos: _touchScreenPos!,
                        targetPos: _targetScreenPos!,
                        placementPos: _currentCadCoord != null ? _cadToScreen(_currentCadCoord!) : null,
                        previewElementPolygon: _pointerElementPolygon(),
                        snappedPos: _snappedScreenPos,
                        snappedPositions: _snappedScreenPositions,
                        snapType: _activeSnap?.type,
                        activeTool: _isMovingOpening
                            ? StructuralDrawTool.slabOpening
                            : (_isMovingColumn
                                ? StructuralDrawTool.column
                                : (_isMovingShearWall
                                    ? StructuralDrawTool.shearWall
                                    : _activeTool)),
                        previewColumn: _isMovingColumn
                            ? _selectedColumn!.copyWith(
                                width: _selectedColumn!.width / _cadUnitsPerMeter,
                                height: _selectedColumn!.height / _cadUnitsPerMeter,
                              )
                            : _currentColumnPreset,
                        previewWallLengthScreen: _isMovingShearWall
                            ? (_selectedShearWall!.length * _getCadFitScale() * _transformController.value.getMaxScaleOnAxis())
                            : (_currentWallLength * _cadUnitsPerMeter * _getCadFitScale() * _transformController.value.getMaxScaleOnAxis()),
                        previewWallThicknessScreen: _isMovingShearWall
                            ? (_selectedShearWall!.thickness * _getCadFitScale() * _transformController.value.getMaxScaleOnAxis())
                            : (_currentWallThickness * _cadUnitsPerMeter * _getCadFitScale() * _transformController.value.getMaxScaleOnAxis()),
                        previewWallRotationRad: _isMovingShearWall
                            ? _selectedShearWall!.rotationRad
                            : _currentWallRotationRad,
                        wallStartPos: _wallStartCad != null ? _cadToScreen(_wallStartCad!) : null,
                        beamStartPos: _beamStartCad != null ? _cadToScreen(_beamStartCad!) : null,
                        slabStartCornerPos: _slabStartCornerCad != null ? _cadToScreen(_slabStartCornerCad!) : null,
                        openingStartCornerPos: _openingStartCad != null ? _cadToScreen(_openingStartCad!) : null,
                        measureStartPos: _measurementStartCad != null ? _cadToScreen(_measurementStartCad!) : null,
                        previewOpeningSize: _getPreviewOpeningSize(),
                        previewOpeningPolygon: _getPreviewOpeningScreenPolygon(),
                        slabPoints: _slabPointsCad.map(_cadToScreen).toList(),
                        openingPoints: _openingPointsCad.map(_cadToScreen).toList(),
                        activeOpeningType: _currentOpeningType,
                        liveDimensionText: _liveDimensionText,
                        measurementParallel: _measurementTracksParallel,
                        scale: _cadUnitsPerMeter * _getCadFitScale() * _transformController.value.getMaxScaleOnAxis(),
                        l10n: context.l10n,
                      ),
                    ),
                  ),
                ),

              // 3. Floor slab reference and trace status.
              if (widget.bimContext != null && _project.activeStorey.slabs.isNotEmpty)
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Material(
                    key: const ValueKey('bim-floor-slab-reference'),
                    color: const Color(0xEE1C1C1E),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(children: [
                        const Icon(Icons.layers_outlined, color: Color(0xFF00B0FF), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${context.l10n.toolSlab} · ${_project.activeStorey.elevationLabel}',
                          style: const TextStyle(color: Colors.white, fontSize: 12))),
                        const SizedBox(width: 8),
                        TextButton(
                          key: const ValueKey('bim-edit-floor-slab'),
                          onPressed: _isPlacingWithHold || _isMovingColumn ||
                              _isMovingShearWall || _isExtrudingEdge ||
                              _slabPointsCad.isNotEmpty || _openingPointsCad.isNotEmpty ||
                              _wallStartCad != null || _beamStartCad != null
                              ? null : _openCurrentSlab,
                          child: Text(context.l10n.bimEditFloorSlab),
                        ),
                      ]),
                    ),
                  ),
                ),
              if (_project.ghostStorey != null &&
                  (floor == null || _project.activeStorey.slabs.isNotEmpty))
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

              // 3b. Grid Axis Offset Direction Drag Guide Banner
              if (_isOffsettingAxisWithDrag && _axisBeingOffset != null)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xEE1E1E24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.dragForDirectionReleaseToOffset(_axisOffsetDistanceMeters.toStringAsFixed(2)),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() {
                              _isOffsettingAxisWithDrag = false;
                              _axisBeingOffset = null;
                            }),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3c. Column Offset Direction Drag Guide Banner
              if (_isOffsettingColumnWithDrag && _columnBeingOffset != null)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xEE1E1E24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.dragForDirectionReleaseToOffset(_columnOffsetDistanceMeters.toStringAsFixed(2)),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() {
                              _isOffsettingColumnWithDrag = false;
                              _columnBeingOffset = null;
                            }),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Dock Bar (Switches to Slab Correction Bar when editing slab, Floating Move Bar when moving, or Contextual Element Dock when element is selected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _duplicateDraft != null
                    ? Material(
                        color: const Color(0xFA1E1E24),
                        child: SafeArea(top: false, child: Row(children: [
                          const SizedBox(width: 12),
                          Expanded(child: Text(context.l10n.dragDuplicateHint, style: const TextStyle(color: Colors.white))),
                          TextButton(onPressed: _cancelDuplicateDrag, child: Text(context.l10n.cancel)),
                        ])),
                      )
                    : _isEditingSlab
                    ? _buildSlabCorrectionBottomBar(context)
                    : (_isMovingColumn || _isMovingShearWall)
                        ? _buildFloatingMoveBottomBar(context)
                        : (_hasSelectedElement && !_isMovingColumn && !_isMovingShearWall && !_isMovingOpening && !_isPlacingWithHold)
                            ? _buildContextualElementBottomDock(context)
                            : ElementPaletteBar(
                        axisLockMode: _axisLockMode,
                        onUpdateAxisLockMode: (mode) => setState(() => _axisLockMode = mode),
                        activeTool: _activeTool,
                        onSelectTool: _selectTool,
                        currentColumnPreset: _currentColumnPreset,
                        onUpdateColumnPreset: (preset) {
                          setState(() => _currentColumnPreset = preset);
                        },
                        currentWallThickness: _currentWallThickness,
                        onUpdateWallThickness: (t) {
                          setState(() => _currentWallThickness = t);
                        },
                        currentWallLength: _currentWallLength,
                        currentWallRotationRad: _currentWallRotationRad,
                        onUpdateWallDimensions: (len, thick) {
                          setState(() {
                            _currentWallLength = len;
                            _currentWallThickness = thick;
                          });
                        },
                        onRotateWall: () {
                          setState(() {
                            _currentWallRotationRad = (_currentWallRotationRad + math.pi / 2.0) % (2 * math.pi);
                          });
                          HapticFeedback.selectionClick();
                        },
                        onClearMeasurement: () {
                          setState(() {
                            _measurementStartCad = null;
                            _activeMeasurement = null;
                            _liveDimensionText = null;
                          });
                        },
                        hasActiveMeasurement: _activeMeasurement != null || _measurementStartCad != null,
                        currentBeamWidth: _currentBeamWidth,
                        currentBeamDepth: _currentBeamDepth,
                        onUpdateBeamDimensions: (w, d) {
                          setState(() {
                            _currentBeamWidth = w;
                            _currentBeamDepth = d;
                          });
                        },
                        currentSlabThickness: _currentSlabThickness,
                        onUpdateSlabThickness: (t) {
                          setState(() => _currentSlabThickness = t);
                        },
                        onManageUnderlays: widget.bimContext?.onManageStoreys,
                        onGenerateSlabs: _generateSlabSeeds,
                        onGenerateStaircaseOpenings: _generateStaircaseOpenings,
                        currentOpeningPreset: _selectedOpeningPreset,
                        onUpdateOpeningPreset: (preset) {
                          setState(() {
                            _selectedOpeningPreset = preset;

                            _openingPointsCad.clear();
                            _openingStartCad = null;
                            _liveDimensionText = null;
                          });
                        },
                        hasOpeningStartCorner: _openingStartCad != null,
                        isDrawingOpening: _activeTool == StructuralDrawTool.slabOpening,

                        openingPointCount: _openingPointsCad.length,
                        onCloseOpening: _closeOpeningPolygon,
                        onUndoOpeningPoint: () {
                          setState(() {
                            if (_openingPointsCad.isNotEmpty) _openingPointsCad.removeLast();
                            if (_openingPointsCad.isEmpty) _liveDimensionText = null;
                          });
                        },
                        onClearOpening: () {
                          setState(() {

                            _openingPointsCad.clear();
                            _openingStartCad = null;
                            _liveDimensionText = null;
                          });
                        },
                        currentAxisName: _currentAxisName,
                        onUpdateAxisName: (name) => setState(() => _currentAxisName = name),
                        hasFirstWallEdge: _firstWallEdgeStartCad != null,
                        onClearAxis: () {
                          setState(() {
                            _firstWallEdgeStartCad = null;
                            _firstWallEdgeEndCad = null;
                          });
                        },
                        isDrawingSlab: _activeTool == StructuralDrawTool.slab,
                        hasSlabStartCorner: _slabPointsCad.isNotEmpty,
                        slabPointCount: _slabPointsCad.length,
                        onCloseSlab: _closeSlabPolygon,
                        onUndoPoint: () {
                          setState(() {
                            _slabStartCornerCad = null;
                            _openingStartCad = null;
                            if (_slabPointsCad.isNotEmpty) _slabPointsCad.removeLast();
                          });
                        },
                        onClearSlab: () {
                          setState(() {
                            _slabStartCornerCad = null;
                            _openingStartCad = null;
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
                        onOpenVerticalCapacityReport: _openVerticalCapacityReport,
                        verticalCapacityReport: _verticalCapacityReport,
                        onOpenSeismicReport: _openSeismicReport,
                        seismicReport: _seismicAnalysisReport,
                        hasWallStart: _wallStartCad != null,
                        hasBeamStart: _beamStartCad != null,
                        onCustomColumnDimensions: _showCustomColumnDialog,
                        onCustomWallThickness: _showCustomWallDialog,
                        onCustomBeamDimensions: _showCustomBeamDialog,
                        onCustomSlabThickness: _showCustomSlabDialog,
                        onCustomAxisName: _showCustomAxisDialog,
                        onOpenLayerManager: _showLayersSheet,
                        onOpenUnderlayFilterConfig: _showUnderlayFilterConfig,
                        onShowAllLayers: () {
                          setState(() {
                            for (final l in _document.layers.values) {
                              l.isVisible = true;
                            }
                            _underlayRevision++;
                          });
                          if (widget.bimContext != null) {
                            final visMap = {for (final l in _document.layers.values) l.name: l.isVisible};
                            widget.bimContext!.onLayerVisibilityChanged(_project.activeStorey.id, visMap);
                          }
                        },
                        onIsolateWhiteLayers: () {
                          _applyUnderlayFilter(true);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContextualElementBottomDock(BuildContext context) {
    if (!_hasSelectedElement || _isMovingColumn || _isMovingShearWall || _isMovingOpening || _isPlacingWithHold || _isEditingSlab) {
      return const SizedBox.shrink();
    }

    final Color primaryColor;
    final String title;
    final String subtitle;
    final VoidCallback onDeselect;
    final VoidCallback? onRename;
    final List<Widget> actionButtons = [];

    if (_selectedColumn != null) {
      final col = _selectedColumn!;
      primaryColor = const Color(0xFFFFB300);
      final rotated = math.sin(col.rotationRad).abs() > math.cos(col.rotationRad).abs();
      final int wCm = ((rotated ? col.height : col.width) / _cadUnitsPerMeter * 100).round();
      final int hCm = ((rotated ? col.width : col.height) / _cadUnitsPerMeter * 100).round();
      final String dimStr = col.shape == ColumnShape.lShape
          ? 'Г $wCm x $hCm / 25 cm'
          : col.shape == ColumnShape.circular
              ? 'Ø$wCm cm'
              : '$wCm x $hCm cm';
      title = col.displayName;
      subtitle = dimStr;
      onDeselect = () => setState(() {
        _selectedColumn = null;
        _columnMirrorBase = null;
        _columnMirrorCycle = 0;
      });
      onRename = _renameSelectedColumn;

      actionButtons.addAll([
        _buildDockActionButton(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.delete,
          color: const Color(0xFFFF5252),
          onTap: _deleteSelectedColumn,
        ),
        _buildDockActionButton(action: BimEditAction.move,
          color: const Color(0xFF69F0AE),
          onTap: _startMovingSelectedColumn,
        ),
        _buildDockActionButton(action: BimEditAction.offset,
          color: const Color(0xFF00E5FF),
          onTap: _showColumnOffsetDialog,
        ),
        _buildDockActionButton(action: BimEditAction.rotate,
          color: const Color(0xFFFFB300),
          onTap: _rotateSelectedColumn,
        ),
        _buildDockActionButton(
          icon: Icons.flip_rounded,
          label: context.l10n.mirrorElement,
          color: const Color(0xFFB388FF),
          onTap: _mirrorSelectedColumn,
        ),
        _buildDockActionButton(action: BimEditAction.duplicate,
          color: const Color(0xFF448AFF),
          onTap: _duplicateSelectedColumn,
        ),
      ]);
    } else if (_selectedShearWall != null) {
      final wall = _selectedShearWall!;
      primaryColor = const Color(0xFF00E5FF);
      final double lengthM = wall.length / _cadUnitsPerMeter;
      final int thickCm = (wall.thickness / _cadUnitsPerMeter * 100).round();
      title = wall.displayName.isNotEmpty ? wall.displayName : context.l10n.shearWallTitle;
      final lengthCm = (lengthM * 100).round();
      final vertical = math.sin(wall.angleRad).abs() > math.cos(wall.angleRad).abs();
      subtitle = vertical ? '$thickCm x $lengthCm cm' : '$lengthCm x $thickCm cm';
      onDeselect = () => setState(() => _selectedShearWall = null);
      onRename = _renameSelectedWall;

      actionButtons.addAll([
        _buildDockActionButton(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.delete,
          color: const Color(0xFFFF5252),
          onTap: _deleteSelectedWall,
        ),
        _buildDockActionButton(action: BimEditAction.move,
          color: const Color(0xFF69F0AE),
          onTap: _startMovingSelectedWall,
        ),
        _buildDockActionButton(
          icon: Icons.line_weight_rounded,
          label: _getShearWallRefLineLabel(context, wall.referenceLine),
          color: const Color(0xFFFFB300),
          onTap: _cycleSelectedWallReferenceLine,
        ),
        _buildDockActionButton(
          icon: Icons.swap_horiz_rounded,
          label: context.l10n.flipSide,
          color: const Color(0xFF00E5FF),
          onTap: _flipSelectedWall,
        ),
        _buildDockActionButton(action: BimEditAction.rotate,
          color: const Color(0xFFFFB300),
          onTap: _rotateSelectedWall,
        ),
        _buildDockActionButton(action: BimEditAction.duplicate,
          color: const Color(0xFFB388FF),
          onTap: _duplicateSelectedWall,
        ),
      ]);
    } else if (_selectedBeam != null) {
      final beam = _selectedBeam!;
      primaryColor = const Color(0xFFFB8C00);
      final int wCm = (beam.width / _cadUnitsPerMeter * 100).round();
      final int dCm = (beam.depth / _cadUnitsPerMeter * 100).round();
      final double lenM = beam.length / _cadUnitsPerMeter;
      title = '${beam.displayName} ($wCm/$dCm)';
      subtitle = '$wCm x $dCm cm, L = ${lenM.toStringAsFixed(2)} m';
      onDeselect = () => setState(() => _selectedBeam = null);
      onRename = _renameSelectedBeam;

      actionButtons.addAll([
        _buildDockActionButton(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.delete,
          color: const Color(0xFFFF5252),
          onTap: _deleteSelectedBeam,
        ),
        for (final (w, d, lbl) in [
          (0.25, 0.50, '25x50'),
          (0.25, 0.60, '25x60'),
          (0.25, 0.40, '25x40'),
        ])
          InkWell(
            onTap: () => _updateSelectedBeamDimensions(w, d),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: (wCm == (w * 100).toInt() && dCm == (d * 100).toInt())
                    ? const Color(0x33FB8C00)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (wCm == (w * 100).toInt() && dCm == (d * 100).toInt())
                       ? const Color(0xFFFB8C00)
                      : Colors.white24,
                  width: 1,
                ),
              ),
              child: Text(
                lbl,
                style: TextStyle(
                  color: (wCm == (w * 100).toInt() && dCm == (d * 100).toInt())
                      ? const Color(0xFFFFB74D)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        InkWell(
          onTap: () => _updateSelectedBeamLength(-0.10),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Text(
              '-10 cm',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        InkWell(
          onTap: () => _updateSelectedBeamLength(0.10),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: const Text(
              '+10 cm',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        _buildDockActionButton(action: BimEditAction.duplicate,
          color: const Color(0xFFB388FF),
          onTap: _duplicateSelectedBeam,
        ),
      ]);
    } else if (_selectedOpening != null) {
      final (slabId, opIdx) = _selectedOpening!;
      final active = _project.activeStorey;
      final slab = active.slabs.firstWhere((s) => s.id == slabId, orElse: () => active.slabs.first);
      final op = opIdx < slab.openings.length ? slab.openings[opIdx] : <Offset>[];
      double minX = op.isNotEmpty ? op.first.dx : 0, maxX = op.isNotEmpty ? op.first.dx : 0;
      double minY = op.isNotEmpty ? op.first.dy : 0, maxY = op.isNotEmpty ? op.first.dy : 0;
      for (final p in op) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      final double wM = (maxX - minX) / _cadUnitsPerMeter;
      final double hM = (maxY - minY) / _cadUnitsPerMeter;
      final opType = slab.getOpeningType(opIdx);
      switch (opType) {
        case SlabOpeningType.staircase:
          primaryColor = const Color(0xFF00B0FF);
          title = context.l10n.openingStaircaseTitle;
          break;
        case SlabOpeningType.elevator:
          primaryColor = const Color(0xFF7C4DFF);
          title = context.l10n.openingElevatorTitle;
          break;
        case SlabOpeningType.shaft:
          primaryColor = const Color(0xFFFF9800);
          title = context.l10n.openingShaftTitle;
          break;
        case SlabOpeningType.custom:
          primaryColor = const Color(0xFFFF9800);
          title = context.l10n.slabOpeningTitle;
          break;
      }
      subtitle = '${wM.toStringAsFixed(2)} x ${hM.toStringAsFixed(2)} m';
      onDeselect = () => setState(() {
        _selectedOpening = null;
        _selectedOpeningVertexIndex = null;
      });
      onRename = null;

      actionButtons.addAll([
        if (_selectedOpeningVertexIndex != null && op.length > 3)
          _buildDockActionButton(
            icon: Icons.delete_sweep_rounded,
            label: context.l10n.deleteOpeningPoint,
            color: const Color(0xFFFFB300),
            onTap: _deleteSelectedOpeningVertex,
          ),
        _buildDockActionButton(
          icon: Icons.category_outlined,
          label: _getOpeningTypeName(opType, context.l10n),
          color: primaryColor,
          onTap: () {
            final nextType = _cycleOpeningType(opType);
            _updateOpeningTypeInStorey(_selectedOpening!, nextType);
          },
        ),
        _buildDockActionButton(action: BimEditAction.rotate,
          color: primaryColor,
          onTap: _rotateSelectedOpening,
        ),
        _buildDockActionButton(action: BimEditAction.move,
          color: const Color(0xFF00E5FF),
          onTap: () {
            if (_selectedOpening != null) {
              final poly = _getOpeningPolygon(_selectedOpening);
              if (poly != null && poly.isNotEmpty) {
                final center = _getOpeningCenter(poly);
                _startMovingOpening(
                  _selectedOpening!,
                  _cadToScreen(center),
                  isMouse: false,
                );
              }
            }
          },
        ),
        _buildDockActionButton(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.delete,
          color: const Color(0xFFFF5252),
          onTap: _deleteSelectedOpening,
        ),
      ]);
    } else if (_selectedGridAxis != null) {
      final axis = _selectedGridAxis!;
      final presentation=GridAxisPresentation.forStorey(axis,_project.activeStorey,_project.storeys);
      primaryColor=presentation.reference ? presentation.color.withValues(alpha:1) : const Color(0xFFFF453A);
      final double lenM = axis.length / _cadUnitsPerMeter;
      title = context.l10n.gridAxisTitle(axis.name);
      subtitle = 'L = ${lenM.toStringAsFixed(2)} m${presentation.levels.isEmpty ? '' : ' · ${context.l10n.gridAxisSourceLevels(presentation.levels)}'}';
      onDeselect = () => setState(() => _selectedGridAxis = null);
      onRename = _renameSelectedGridAxis;

      actionButtons.addAll([
        _buildDockActionButton(
          icon: Icons.delete_outline_rounded,
          label: context.l10n.deleteGridAxis,
          color: const Color(0xFFFF5252),
          onTap: _deleteSelectedGridAxis,
        ),
        _buildDockActionButton(action: BimEditAction.offset,
          color: const Color(0xFF00E5FF),
          onTap: _showGridAxisOffsetDialog,
        ),
        _buildDockActionButton(
          icon: Icons.edit_outlined,
          label: context.l10n.renameGridAxis,
          color: const Color(0xFFFFB300),
          onTap: _renameSelectedGridAxis,
        ),
      ]);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFA1E1E24),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: primaryColor.withValues(alpha: 0.8), width: 1.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Header (Element Badge & Subtitle, optional Rename, Close X button)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onRename != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onRename,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(Icons.edit_outlined, size: 14, color: primaryColor),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '•  $subtitle',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onDeselect,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Action Buttons (Scrollable horizontally)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < actionButtons.length; i++) ...[
                    actionButtons[i],
                    if (i < actionButtons.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockActionButton({IconData? icon, String? label, BimEditAction? action,
    required Color color, required VoidCallback onTap}) => BimActionButton(
      icon: icon ?? BimEditActions.icon(action!), label: label ?? BimEditActions.label(action!, context.l10n),
      color: color, onTap: onTap, tooltip: action == BimEditAction.duplicate ? context.l10n.dragDuplicateHint : null);

  void _cleanEditingSlabContour() {
    if (_editingSlab == null) return;
    final initialCount = _editingSlab!.polygon.length;
    final cleaned = _cleanSlabPolygon(_editingSlab!);
    final diff = initialCount - cleaned.polygon.length;
    if (diff > 0) {
      _pushSlabCorrectionUndo();
      setState(() {
        _editingSlab = cleaned;
      });
      if (!_updateActiveStoreySlab(cleaned)) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.slabContourCleaned(diff)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.slabContourAlreadyClean),
          duration: const Duration(seconds: 1),
        ),
      );
    }
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
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
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

            IconButton(
              tooltip: context.l10n.slabEdgeOffset,
              onPressed: _editSlabEdgeOffset,
              icon: const Icon(Icons.straighten, color: Colors.white, size: 20),
            ),
            IconButton(
              tooltip: context.l10n.cleanSlabContourTooltip,
              onPressed: _cleanEditingSlabContour,
              icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF00E5FF), size: 20),
            ),
            // Delete Selected Vertex Button
            if (_selectedSlabVertexIndex != null && _editingSlab != null && _editingSlab!.polygon.length > 3) ...[
              OutlinedButton.icon(
                onPressed: _deleteSelectedSlabVertex,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB300),
                  side: const BorderSide(color: Color(0xFFFFB300), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                label: Text(
                  context.l10n.deleteVertex,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Center Stats Pill
            SizedBox(
              width: 210,
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
                        Flexible(
                          child: InkWell(
                            onTap: _showCustomSlabDialog,
                            child: Text(
                              '↑ ${_project.activeStorey.structuralElevationFor(_editingSlab!).toStringAsFixed(3)} m · h=${(_editingSlab!.thickness * 100).toStringAsFixed(1)} cm',
                              style: const TextStyle(
                                color: Color(0xFFB388FF),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S: ${areaM2.toStringAsFixed(1)} m²  P: ${perimM.toStringAsFixed(1)} m  ($numPts ${context.l10n.pointsAbbr})',
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

  Widget _buildFloatingMoveBottomBar(BuildContext context) {
    final String elementName = _selectedColumn != null
        ? _selectedColumn!.displayName
        : (_selectedShearWall != null
            ? (_selectedShearWall!.displayName.isNotEmpty
                ? _selectedShearWall!.displayName
                : context.l10n.shearWallTitle)
            : context.l10n.moveElement);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFA1E1E24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Color(0xFF69F0AE), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Header with move indicator and Axis Lock chips
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF69F0AE),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.l10n.precisionMoveActive}: $elementName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Actions - [✖ Cancel] [⚙ Fine position / Clear distance] [✔ Confirm]
            Row(
              children: [
                // Cancel Button
                OutlinedButton.icon(
                  onPressed: _cancelCurrentMove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5252),
                    side: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(
                    context.l10n.cancelMove,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                // Confirm Button
                ElevatedButton.icon(
                  onPressed: _confirmCurrentMove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    context.l10n.confirmMove,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
