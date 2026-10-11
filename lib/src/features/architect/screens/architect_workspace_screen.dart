import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../bim_projects/models/bim_work_project.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../models/architect_door.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_3d_builder.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_wall_snap.dart';
import '../rendering/architect_zone_snap.dart';
import '../rendering/architect_underlay_painter.dart';
import '../rendering/architect_scene_geometry.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_element_tool.dart';
import '../services/architect_grid_axis_tool.dart';
import '../services/architect_logger.dart';
import '../services/architect_zone_tool.dart';
import '../models/architect_wall_type.dart';
import '../widgets/architect_grid_axis_bar.dart';
import '../widgets/architect_grid_axis_offset_dialog.dart';
import '../widgets/architect_grid_axis_properties_card.dart';
import '../widgets/architect_project_wizard_dialog.dart';
import '../widgets/architect_storey_bar.dart';
import '../widgets/architect_tool_palette.dart';
import '../widgets/architect_zone_drafting_bar.dart';
import '../widgets/architect_zone_properties_card.dart';
import '../widgets/architect_viewport.dart';
import '../widgets/architect_wall_drafting_panel.dart';

// === SECTION: TABLE OF CONTENTS ===
// 1. STATE & TOOL CONTROLLERS
// 2. COORDINATE TRANSFORMS (SCREEN <-> MODEL)
// 3. 2D POINTER & TOUCH HANDLING (TOOL INPUT FROM ARCHITECT VIEWPORT)
// 4. ZONE EDITING & MUTATION HANDLERS
// 5. WALL & DOOR CONCEPT DRAFTING
// 6. DYNAMIC GRID AXES ACTIONS
// 7. DIAGNOSTIC LOGS DIALOG (ARCHITECT LOGGER)
// 8. 2D CANVAS VIEWPORT (LAYERED MODEL SPACE)
// 9. 3D SOLID VIEWPORT

/// The primary unified workspace for architectural concept drafting in 2D and 3D.
class ArchitectWorkspaceScreen extends StatefulWidget {
  final ArchitectProject? initialProject;
  final BimWorkProject? bimProject;
  final Map<String, DxfDocument>? underlaysByStorey;
  final BimCoordinateFrame underlayFrame;
  final ArchitectCommandController? commandController;

  const ArchitectWorkspaceScreen({
    super.key,
    this.initialProject,
    this.bimProject,
    this.underlaysByStorey,
    this.underlayFrame = const BimCoordinateFrame(),
    this.commandController,
  });

  @override
  State<ArchitectWorkspaceScreen> createState() =>
      _ArchitectWorkspaceScreenState();
}

// === SECTION: STATE & TOOL CONTROLLERS ===
class _ArchitectWorkspaceScreenState extends State<ArchitectWorkspaceScreen> {
  late final ArchitectCommandController _commands;
  ArchitectProject get _project => _commands.project;
  set _project(ArchitectProject value) => _commands.commit(value);
  Timer? _saveTimer;
  final ValueNotifier<int> _previewRevision = ValueNotifier(0);
  Object? _toolUiState;
  int _interactionEpoch = 0;
  void _repaintPreview() {
    _previewRevision.value++;
    // Tool configuration/selection changes refresh controls; pointer coordinates
    // only refresh the interaction painter and the tool's own HUD listeners.
    final state = (
      _axisTool.selectedAxisId,
      _axisTool.isDrafting,
      _zoneTool.isDrafting,
      _zoneTool.editingZone?.id,
      _elementTool.windowWidth,
      _elementTool.windowHeight,
      _elementTool.windowSill,
      _elementTool.columnShape,
      _elementTool.columnWidth,
      _elementTool.columnDepth,
      _elementTool.beamWidth,
      _elementTool.beamDepth,
      _elementTool.stairWidth,
      _elementTool.stairSteps,
      _elementTool.openingType,
    );
    if (state != _toolUiState && mounted) {
      _toolUiState = state;
      setState(() {});
    }
  }

  ArchitectTool _activeTool = ArchitectTool.zone;
  bool _is3DView = false;

  // Zone Drafting & Dynamic Slab-style Editing State
  ArchitectZoneCategory _activeZoneCategory = ArchitectZoneCategory.living;
  String? _selectedZoneId;
  int? _draggingVertexIndex;
  Offset? _draggingVertexPoint;
  int? _mergeCandidateIndex;
  Offset? _zoneMoveStartPoint;
  List<Offset>? _zoneMoveOriginalPolygon;
  List<Offset>? _zoneMovePreviewPolygon;
  Offset _vertexGrabOffset = Offset.zero;
  Offset _axisHandleGrabOffset = Offset.zero;
  List<(Offset, Offset)> _activeMagneticGuides = [];

  // Unified tool controller for zone drafting, edge extrusion, and geometry
  late final ArchitectZoneTool _zoneTool;

  // Unified tool controller for dynamic grid axes
  late final ArchitectGridAxisTool _axisTool;

  // Unified tool controller for architectural elements (windows, columns, beams, slabs, etc.)
  late final ArchitectElementTool _elementTool;

  // Underlays
  Map<String, DxfDocument> _underlaysByStorey = {};
  final Map<String, bool> _underlayLayerVisibility = {};
  bool _showUnderlay = true;

  DxfDocument? get _currentUnderlayDoc {
    if (!_showUnderlay) return null;
    return _underlaysByStorey[_project.activeStorey.id];
  }

  void _saveBiMProjectIfAttached() {
    if (widget.bimProject == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _flushSave);
  }

  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (widget.bimProject == null) return;
    final saved = await BimProjectLibraryService.instance.saveArchitectProject(
      widget.bimProject!.id,
      _project,
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'bg'
                ? 'Промените не са записани. Проверете мястото за съхранение.'
                : 'Changes could not be saved. Check storage.',
          ),
        ),
      );
    }
  }

  void _onModelChanged() {
    if (!mounted) return;
    if (_isActivelyDraggingHandle) {
      _cancelActiveDrags();
      _interactionEpoch++;
    }
    setState(() {});
    _saveBiMProjectIfAttached();
  }

  void _undoModel() {
    _cancelDrafting();
    _commands.undo();
  }

  void _redoModel() {
    _cancelDrafting();
    _commands.redo();
  }

  void _cancelDrafting() {
    _wallInsertPointId = null;
    _interactionEpoch++;
    _cancelActiveDrags();
    _zoneTool.cancelAll();
    _axisTool.cancelAll();
    _elementTool.cancelSlabDrafting();
    setState(() {
      _draftStart = null;
      _draftEnd = null;
      _wallDirectionLocked = false;
      _selectedZoneId = null;
      _selectedElementId = null;
    });
  }

  // Wall Drafting State
  double _wallThickness = 0.25; // 25 cm default
  ArchitectWallType? _activeWallType;
  WallDraftingMode _wallMode = WallDraftingMode.singleLine;
  Offset? _draftStart;
  Offset? _draftEnd;
  bool _wallDirectionLocked = false;
  Offset? _wallPanelAnchor;
  WallReferenceLine _wallReference = WallReferenceLine.center;
  bool _wallTouchInput = false;
  ArchitectWall? _wallEndpointOriginal;
  bool _wallDragStart = false;
  Offset _wallGrabOffset = Offset.zero;
  bool _wallParallelMove = false;
  String? _wallInsertPointId;

  ArchitectWall? get _selectedWall {
    for (final wall in _project.activeStorey.walls) {
      if (wall.id == _selectedElementId) return wall;
    }
    return null;
  }

  Offset? _cursorModel;
  Offset? _columnPreviewPoint;
  String? _activeSnapLabel;

  // Door State (from element_vrata.dxf)
  double _doorWidth = 0.90;
  double _doorHeight = 2.00;
  double _doorSill = 0.0;
  bool _isHingeLeft = true;
  int _doorSpecCounter = 1;

  // Selection & Zoom
  String? _selectedElementId;
  String? _draggingElementId;
  Offset? _elementMoveStart;
  Offset? _elementMoveDelta;
  ArchitectProject? _elementMoveOriginal;
  ArchitectProject? _elementMovePreview;
  final BimViewportController _viewport = BimViewportController();
  bool _hasFramedViewport = false;
  late Cad3DCamera _camera3D;

  // Pointer ownership and navigation live in ArchitectViewport.
  bool _isHandleEngaged = false;
  Offset? _handlePointerDown;
  bool _handleMoved = false;

  ArchitectZone? get _selectedZone {
    if (_selectedZoneId == null) return null;
    final zones = _project.activeStorey.zones;
    for (final z in zones) {
      if (z.id == _selectedZoneId) return z;
    }
    return null;
  }

  /// Whether an element handle (vertex, extrusion edge, axis handle/move, or whole zone move)
  /// is actively being dragged. ArchitectViewport routes captured handles exclusively to the tool.
  bool get _isActivelyDraggingHandle =>
      _isHandleEngaged ||
      _draggingElementId != null ||
      _draggingVertexIndex != null ||
      _zoneTool.isExtruding ||
      _zoneTool.isMovingZone ||
      _zoneMoveStartPoint != null ||
      _axisTool.isDraggingHandle ||
      _axisTool.isMovingAxis ||
      _axisTool.isOffsettingWithDrag;

  @override
  void initState() {
    super.initState();
    _commands =
        widget.commandController ??
        ArchitectCommandController(
          widget.initialProject ??
              ArchitectProject.starterWithCatalog(
                name: widget.bimProject?.name ?? 'Архитектурен проект',
                storeyCount: widget.bimProject?.storeys.length ?? 2,
              ),
        );
    _commands.addListener(_onModelChanged);

    if (_project.wallTypes.isNotEmpty) {
      _activeWallType = _project.wallTypes.first;
      _wallThickness = _activeWallType!.totalThickness;
    }

    _zoneTool = ArchitectZoneTool()..addListener(_repaintPreview);

    _axisTool = ArchitectGridAxisTool()..addListener(_repaintPreview);

    _elementTool = ArchitectElementTool()..addListener(_repaintPreview);

    if (widget.underlaysByStorey != null) {
      _underlaysByStorey = Map.from(widget.underlaysByStorey!);
    }

    if (widget.bimProject != null &&
        widget.initialProject == null &&
        widget.commandController == null) {
      _loadAttachedBimProject();
    }

    _camera3D = Cad3DCamera(
      yaw: math.pi / 4,
      pitch: 0.6,
      zoom: 1.0,
      mode: Cad3DInteractionMode.orbit,
    );

    // Initial camera scale for 2D canvas: 1 meter = 40 logical pixels
  }

  Future<void> _loadAttachedBimProject() async {
    final loaded = await BimProjectLibraryService.instance.loadArchitectProject(
      widget.bimProject!.id,
    );
    if (loaded != null && mounted) {
      setState(() {
        _commands.restore(loaded);
      });
      _initTransform();
    }
  }

  void _initTransform() {
    var bounds = ArchitectSceneGeometry.projectBounds(_project);
    final underlay = _currentUnderlayDoc;
    if (underlay != null) {
      final source = widget.underlayFrame.rectToModel(underlay.bounds);
      bounds = bounds == Rect.zero ? source : bounds.expandToInclude(source);
    }
    _viewport.fit(
      bounds == Rect.zero ? const Rect.fromLTRB(-5, -5, 15, 15) : bounds,
    );
  }

  @override
  void dispose() {
    if (_saveTimer != null) {
      unawaited(_flushSave());
    }
    _commands.removeListener(_onModelChanged);
    if (widget.commandController == null) _commands.dispose();
    _zoneTool.dispose();
    _axisTool.dispose();
    _elementTool.dispose();
    _viewport.dispose();
    _previewRevision.dispose();
    super.dispose();
  }

  // === SECTION: COORDINATE TRANSFORMS (SCREEN <-> MODEL) ===

  Offset _screenToModel(Offset screenPos) {
    return _viewport.toModel(screenPos);
  }

  double get _currentScale => _viewport.scale;

  // ===========================================================================
  // 2D POINTER & TOUCH HANDLING
  // ===========================================================================

  int? _hitTestZoneVertex(Offset modelPt, ArchitectZone zone) {
    final tolerance = 14.0 / _currentScale;
    for (int i = 0; i < zone.polygon.length; i++) {
      if ((modelPt - zone.polygon[i]).distance <= tolerance) {
        return i;
      }
    }
    return null;
  }

  int? _hitTestZoneMidpoint(Offset modelPt, ArchitectZone zone) {
    final tolerance = 12.0 / _currentScale;
    for (int i = 0; i < zone.polygon.length; i++) {
      final p1 = zone.polygon[i];
      final p2 = zone.polygon[(i + 1) % zone.polygon.length];
      final mid = (p1 + p2) / 2.0;
      if ((modelPt - mid).distance <= tolerance) {
        return i;
      }
    }
    return null;
  }

  ArchitectZone? _findZoneAt(Offset modelPt) {
    final zones = _project.activeStorey.zones;
    for (int i = zones.length - 1; i >= 0; i--) {
      if (zones[i].containsPoint(modelPt)) {
        return zones[i];
      }
    }
    return null;
  }

  void _commitDraftedZone() {
    final l10n = context.l10n;
    final newZone = _zoneTool.commitDrafting(
      category: _activeZoneCategory,
      defaultName: _activeZoneCategory.defaultBgName,
    );

    if (newZone != null) {
      final activeStorey = _project.activeStorey;
      setState(() {
        _commands.execute(
          CreateArchitectZone(storeyId: activeStorey.id, zone: newZone),
        );
        _selectedZoneId = newZone.id;
        _activeMagneticGuides = [];
        _activeSnapLabel = null;
      });
      _zoneTool.startEditingZone(newZone);

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.architectZoneCreated(
              newZone.name,
              newZone.area.toStringAsFixed(1),
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      if (_zoneTool.pointStatus == ZoneDraftingPointStatus.selfIntersects) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneSelfIntersectError),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneMinPointsError),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // === SECTION: 2D POINTER & TOUCH HANDLING (TOOL INPUT FROM ARCHITECT VIEWPORT) ===

  void _onPointerDown(PointerDownEvent event) {
    _wallTouchInput = event.kind == PointerDeviceKind.touch;
    _handlePointerDown = event.localPosition;
    _handleMoved = false;
    _isHandleEngaged = false;

    final rawModel = _screenToModel(event.localPosition);
    if (_activeTool == ArchitectTool.wall) {
      _updatePointerPreview(_placementPosition(event.localPosition));
      _repaintPreview();
    }
    if (_activeTool == ArchitectTool.select && _selectedWall != null) {
      if (_wallInsertPointId != null) return;
      final wall = _selectedWall!;
      for (final atStart in [true, false]) {
        final point = atStart ? wall.startPoint : wall.endPoint;
        if ((point - rawModel).distance <= 18 / _currentScale) {
          _wallEndpointOriginal = wall;
          _wallDragStart = atStart;
          _wallGrabOffset = point - rawModel;
          _elementMoveOriginal = _project;
          _isHandleEngaged = true;
          return;
        }
      }
    }

    // 0. If in axis offset drag mode:
    if (_axisTool.isOffsettingWithDrag) {
      _axisTool.updateOffsetDrag(rawModel);
      _isHandleEngaged = true;
      return;
    }

    // 1. Grid Axis handle & body interactions in Axis or Select mode
    if ((_activeTool == ArchitectTool.axis ||
            _activeTool == ArchitectTool.select) &&
        !_axisTool.isDrafting) {
      // 1a. Handle hit check (stretching axis extents)
      final axisHandle = _axisTool.hitTestAxisHandle(
        rawModel,
        _activeTool == ArchitectTool.select
            ? _project.gridAxes
                  .where((a) => a.id == _axisTool.selectedAxisId)
                  .toList()
            : _project.gridAxes,
        tolerance: 18.0 / _currentScale,
      );
      if (axisHandle != null) {
        _axisHandleGrabOffset =
            (axisHandle.$2 ? axisHandle.$1.start : axisHandle.$1.end) -
            rawModel;
        _axisTool.startHandleDrag(axisHandle.$1, axisHandle.$2);
        _isHandleEngaged = true;
        setState(() {
          _selectedZoneId = null;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        ArchitectLogger.log(
          'HANDLE',
          'Axis handle drag engaged for ${axisHandle.$1.name}',
        );
        return;
      }

      if (_activeTool == ArchitectTool.select &&
          _tryStartElementDrag(rawModel)) {
        return;
      }

      // 1b. Axis body hit check (select or start move if already selected)
      final hitAxis = _axisTool.hitTestAxis(
        rawModel,
        _project.gridAxes,
        tolerance: 16.0 / _currentScale,
      );
      if (hitAxis != null) {
        if (_axisTool.selectedAxisId == hitAxis.id) {
          _axisTool.startMoving(hitAxis, rawModel);
          _isHandleEngaged = true;
          ArchitectLogger.log(
            'HANDLE',
            'Axis moving engaged for ${hitAxis.name}',
          );
        } else {
          _axisTool.selectAxis(hitAxis.id);
          ArchitectLogger.log('SELECT', 'Axis ${hitAxis.name} selected');
        }
        setState(() {
          _selectedZoneId = null;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        return;
      }
    }

    // 2. Zone handle interactions in Zone or Select mode
    if (_activeTool == ArchitectTool.zone ||
        _activeTool == ArchitectTool.select) {
      // 2a. Whole zone move mode check (GPS_Mapping mode)
      if (_zoneTool.isMoveWholeZoneMode && _selectedZone != null) {
        _zoneTool.startMovingZone(rawModel);
        _isHandleEngaged = true;
        ArchitectLogger.log(
          'HANDLE',
          'Zone move whole mode engaged for ${_selectedZone!.name}',
        );
        return;
      }

      final currentSelected = _selectedZone;
      if (currentSelected != null) {
        // 2b. Vertex handle check (drag existing vertex)
        final vIdx = _hitTestZoneVertex(rawModel, currentSelected);
        if (vIdx != null) {
          setState(() {
            _draggingVertexIndex = vIdx;
            _draggingVertexPoint = currentSelected.polygon[vIdx];
            _vertexGrabOffset = currentSelected.polygon[vIdx] - rawModel;
            _mergeCandidateIndex = null;
            _activeMagneticGuides = [];
            _isHandleEngaged = true;
          });
          HapticFeedback.selectionClick();
          ArchitectLogger.log('HANDLE', 'Zone vertex $vIdx drag engaged');
          return;
        }

        // 2c. Midpoint handle check (extrude/pull edge)
        final midIdx = _hitTestZoneMidpoint(rawModel, currentSelected);
        if (midIdx != null) {
          _zoneTool.startExtrude(
            zone: currentSelected,
            edgeIndex: midIdx,
            pointerModel: rawModel,
          );
          _isHandleEngaged = true;
          HapticFeedback.mediumImpact();
          ArchitectLogger.log('HANDLE', 'Zone edge $midIdx extrusion engaged');
          return;
        }

        // 2d. Tap inside currently selected zone -> initiate body move
        if (currentSelected.containsPoint(rawModel)) {
          setState(() {
            _zoneMoveStartPoint = rawModel;
            _zoneMoveOriginalPolygon = List<Offset>.from(
              currentSelected.polygon,
            );
            _isHandleEngaged = true;
          });
          ArchitectLogger.log(
            'HANDLE',
            'Zone body drag initiated for ${currentSelected.name}',
          );
          return;
        }
      }
    }

    // No handle engaged on pointer-down: free pan/zoom candidate
    ArchitectLogger.log(
      'VIEWPORT',
      'Pointer down at $rawModel - no handle hit, tool input candidate',
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_handlePointerDown != null &&
        (event.localPosition - _handlePointerDown!).distance > 1e-6) {
      _handleMoved = true;
    }
    _updatePointerPreview(_placementPosition(event.localPosition));
  }

  Offset _placementPosition(Offset point) =>
      _activeTool == ArchitectTool.wall && _wallTouchInput
      ? point - const Offset(0, 64)
      : point;

  ArchitectSnapResult _snapWall(Offset raw, {Offset? anchor}) =>
      ArchitectWallSnap.resolve(
        raw: raw,
        anchor: anchor,
        project: _project,
        scale: _currentScale,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
      );

  void _updatePointerPreview(Offset screenPosition) {
    final rawModel = _screenToModel(screenPosition);
    _cursorModel = rawModel;
    if (_wallEndpointOriginal != null && _elementMoveOriginal != null) {
      final original = _wallEndpointOriginal!;
      final snapProject = _project.updateActiveStorey(
        _project.activeStorey.copyWith(
          walls: _project.activeStorey.walls
              .where((w) => w.id != original.id)
              .toList(),
        ),
      );
      final snap = ArchitectWallSnap.resolve(
        raw: rawModel + _wallGrabOffset,
        anchor: _wallDragStart ? original.endPoint : original.startPoint,
        project: snapProject,
        scale: _currentScale,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
      );
      final updated = original.copyWith(
        startPoint: _wallDragStart ? snap.point : null,
        endPoint: _wallDragStart ? null : snap.point,
      );
      try {
        _elementMovePreview = UpdateArchitectWall(
          storeyId: _project.activeStorey.id,
          wall: updated,
        ).apply(_elementMoveOriginal!);
        _activeSnapLabel = snap.snapLabel;
      } on ArgumentError {
        /* Keep the last valid preview. */
      }
      _repaintPreview();
      return;
    }
    if (_activeTool == ArchitectTool.column) {
      _columnPreviewPoint = ArchitectSnapHelper.snapFree(
        rawPoint: rawModel,
        project: _project,
        tolerance: 12.0 / _currentScale,
      ).point;
      _repaintPreview();
      return;
    }

    if (_draggingElementId != null &&
        _elementMoveStart != null &&
        _elementMoveOriginal != null) {
      var delta = ArchitectSnapHelper.precision(
        _project,
      ).inputPoint(rawModel - _elementMoveStart!);
      final selectedWall = _selectedWall;
      if (selectedWall != null && _wallParallelMove) {
        final n = selectedWall.normalVector;
        delta = n * (delta.dx * n.dx + delta.dy * n.dy);
      }
      _elementMoveDelta = delta;
      if (selectedWall != null) {
        try {
          _elementMovePreview = UpdateArchitectWall(
            storeyId: _project.activeStorey.id,
            wall: selectedWall.copyWith(
              startPoint: selectedWall.startPoint + delta,
              endPoint: selectedWall.endPoint + delta,
            ),
          ).apply(_elementMoveOriginal!);
        } on ArgumentError {
          _elementMoveDelta = null;
        }
      } else {
        _elementMovePreview = MoveArchitectElement(
          storeyId: _project.activeStorey.id,
          elementId: _draggingElementId!,
          delta: delta,
        ).apply(_elementMoveOriginal!);
      }
      _repaintPreview();
      return;
    }

    // 0. Axis offset drag preview
    if (_axisTool.isOffsettingWithDrag) {
      _axisTool.updateOffsetDrag(rawModel);
      return;
    }

    // 0b. Axis handle stretching
    if (_axisTool.isDraggingHandle) {
      _axisTool.updateHandleDrag(
        rawModel + _axisHandleGrabOffset,
        _project.gridAxes,
        _currentScale,
      );
      return;
    }

    // 0c. Axis body moving
    if (_axisTool.isMovingAxis) {
      _axisTool.updateMoving(rawModel, _project.gridAxes, _currentScale);
      return;
    }

    // 0d. Axis drafting
    if (_activeTool == ArchitectTool.axis && _axisTool.isDrafting) {
      _axisTool.updateDrafting(rawModel, _project, _currentScale);
      return;
    }

    // 1. Point-by-point zone drafting preview
    if (_activeTool == ArchitectTool.zone && _zoneTool.isDrafting) {
      _zoneTool.updateDraftingPointer(
        rawModelPoint: rawModel,
        project: _project,
        currentScale: _currentScale,
      );
      return;
    }

    // 2. Dragging edge midpoint (extruding segment)
    if (_zoneTool.isExtruding) {
      _zoneTool.updateExtrudePointer(rawModel);
      return;
    }

    // 3. Dragging a zone vertex (dynamic slab editing)
    if (_draggingVertexIndex != null && _selectedZone != null) {
      final snap = ArchitectZoneSnap.snap(
        raw: rawModel + _vertexGrabOffset,
        project: _project,
        excludedZoneId: _selectedZoneId,
        movingVertexIndex: _draggingVertexIndex,
        tolerance: 14.0 / _currentScale,
      );
      _draggingVertexPoint = snap.point;
      _mergeCandidateIndex = snap.mergeCandidateIndex;
      _activeMagneticGuides = snap.magneticGuides;
      _activeSnapLabel = snap.snapLabel;
      _repaintPreview();
      return;
    }

    // 4. Moving whole zone (GPS_Mapping mode or legacy drag)
    if (_zoneTool.isMoveWholeZoneMode && _zoneTool.isEditingZone) {
      _zoneTool.updateMovingZone(rawModel);
      return;
    }
    if (_zoneMoveStartPoint != null &&
        _zoneMoveOriginalPolygon != null &&
        _selectedZone != null) {
      final delta = rawModel - _zoneMoveStartPoint!;
      final translated = _zoneMoveOriginalPolygon!
          .map((p) => p + delta)
          .toList();
      _zoneMovePreviewPolygon = translated;
      _repaintPreview();
      return;
    }

    // 5. Wall drafting preview
    if (_activeTool == ArchitectTool.wall && _draftStart != null) {
      if (_wallDirectionLocked) return;
      final snap = _snapWall(rawModel, anchor: _draftStart);
      _draftEnd = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _repaintPreview();
      return;
    }

    // 6. Two-point architectural tools preview
    if (_draftStart != null &&
        (_activeTool == ArchitectTool.beam ||
            _activeTool == ArchitectTool.opening ||
            _activeTool == ArchitectTool.stair ||
            _activeTool == ArchitectTool.dimension ||
            _activeTool == ArchitectTool.cadLine ||
            _activeTool == ArchitectTool.cadRect ||
            _activeTool == ArchitectTool.cadCircle ||
            _activeTool == ArchitectTool.measure)) {
      final snap = _activeTool == ArchitectTool.dimension
          ? ArchitectSnapHelper.snapFree(
              rawPoint: rawModel,
              project: _project,
              tolerance: 12.0 / _currentScale,
            )
          : ArchitectSnapHelper.snapWithAnchor(
              anchor: _draftStart!,
              rawPoint: rawModel,
              project: _project,
              tolerance: 12.0 / _currentScale,
            );
      _draftEnd = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _repaintPreview();
      return;
    }

    // 7. Slab drafting candidate
    if (_activeTool == ArchitectTool.slab &&
        _elementTool.slabDraftPoints.isNotEmpty) {
      _elementTool.updateSlabCandidate(_resolveSlabPoint(rawModel));
    }
  }

  Offset _resolveSlabPoint(Offset raw) {
    final points = _elementTool.slabDraftPoints;
    if (points.length >= 3 &&
        (raw - points.first).distance <= math.min(16 / _currentScale, .20)) {
      return points.first;
    }
    return ArchitectSnapHelper.snapFree(
      rawPoint: raw,
      project: _project,
      tolerance: 14 / _currentScale,
    ).point;
  }

  void _onPointerHover(PointerHoverEvent event) {
    _wallTouchInput = false;
    _updatePointerPreview(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isActivelyDraggingHandle && !_handleMoved) {
      _cancelActiveDrags();
      _repaintPreview();
      return;
    }
    // Resolve again at release: touch has no hover and the final event can
    // differ from the last move. Preview and commit share the same resolver.
    _updatePointerPreview(_placementPosition(event.localPosition));
    if (_isActivelyDraggingHandle) {
      _commitActiveHandleDrag(event.localPosition);
      _isHandleEngaged = false;
      _repaintPreview();
    } else {
      _handleTap(_screenToModel(_placementPosition(event.localPosition)));
    }
  }

  void _cancelActiveDrags() {
    _wallEndpointOriginal = null;
    _handleMoved = false;
    _handlePointerDown = null;
    _draggingElementId = null;
    _elementMoveStart = null;
    _elementMoveDelta = null;
    _elementMoveOriginal = null;
    _elementMovePreview = null;
    _isHandleEngaged = false;
    _draggingVertexIndex = null;
    _draggingVertexPoint = null;
    _mergeCandidateIndex = null;
    _zoneMoveStartPoint = null;
    _zoneMoveOriginalPolygon = null;
    _zoneMovePreviewPolygon = null;
    _activeMagneticGuides = [];
    _activeSnapLabel = null;
    if (_zoneTool.isExtruding) {
      _zoneTool.cancelExtrude();
    }
    if (_zoneTool.isMovingZone) {
      _zoneTool.cancelMovingZone();
    }
    if (_axisTool.isDraggingHandle ||
        _axisTool.isMovingAxis ||
        _axisTool.isOffsettingWithDrag) {
      _axisTool.cancelAll();
    }
  }

  void _commitActiveHandleDrag(Offset screenPos) {
    final l10n = context.l10n;
    final isBg = Localizations.localeOf(context).languageCode == 'bg';

    if (_wallEndpointOriginal != null ||
        (_draggingElementId != null && _selectedWall != null)) {
      final preview = _elementMovePreview;
      final id = _wallEndpointOriginal?.id ?? _draggingElementId;
      _cancelActiveDrags();
      if (preview != null && id != null) {
        final wall = preview.activeStorey.walls.firstWhere((w) => w.id == id);
        _commands.execute(
          UpdateArchitectWall(storeyId: _project.activeStorey.id, wall: wall),
        );
      }
      return;
    }

    if (_draggingElementId != null && _elementMoveDelta != null) {
      if (_elementMoveDelta!.distance > 1e-9) {
        _commands.execute(
          MoveArchitectElement(
            storeyId: _project.activeStorey.id,
            elementId: _draggingElementId!,
            delta: _elementMoveDelta!,
          ),
        );
      }
      _draggingElementId = null;
      _elementMoveStart = null;
      _elementMoveDelta = null;
      _elementMoveOriginal = null;
      _elementMovePreview = null;
      return;
    }

    // 0. Commit axis offset drag
    if (_axisTool.isOffsettingWithDrag && _axisTool.axisBeingOffset != null) {
      final origAxis = _axisTool.axisBeingOffset!;
      final dist = _axisTool.offsetDistanceMeters;
      final sign = _axisTool.currentOffsetSign;
      final (updatedProj, newAxis) = _axisTool.applyOffset(
        project: _project,
        originalAxis: origAxis,
        distanceMeters: dist,
        directionSign: sign,
        isBulgarian: isBg,
      );
      setState(() {
        _project = updatedProj;
      });
      HapticFeedback.mediumImpact();
      _promptDeletePreviousAxis(origAxis);
      return;
    }

    // 0b. Commit axis handle drag
    if (_axisTool.isDraggingHandle) {
      final updatedProj = _axisTool.commitHandleDrag(_project, isBg);
      if (updatedProj != null) {
        setState(() => _project = updatedProj);
        HapticFeedback.lightImpact();
      }
      return;
    }

    // 0c. Commit axis moving
    if (_axisTool.isMovingAxis) {
      final updatedProj = _axisTool.commitMoving(_project, isBg);
      if (updatedProj != null) {
        setState(() => _project = updatedProj);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectAxisMoved),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // 1. Edge extrusion commit
    if (_zoneTool.isExtruding) {
      final isSelfIntersecting = _zoneTool.isExtrudeSelfIntersecting;
      final result = _zoneTool.commitExtrude();
      if (result != null) {
        final (updatedZone, cleanedCount) = result;
        _updateZone(updatedZone);
        HapticFeedback.mediumImpact();
        if (cleanedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneCleaned(cleanedCount)),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (isSelfIntersecting) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.architectZoneSelfIntersectError),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 2. Commit vertex drag with orphan cleaning & self-intersection protection
    if (_draggingVertexIndex != null && _selectedZone != null) {
      final zone = _selectedZone!;
      final idx = _draggingVertexIndex!;
      final mergeCandidate = _mergeCandidateIndex;

      if (mergeCandidate != null && zone.polygon.length > 3) {
        final updated = zone.removeVertex(idx);
        if (updated != null) {
          final cleaned = ArchitectZoneGeometry.cleanPolygon(
            updated.polygon,
            minDistance: 1e-6,
            minCollinearDistance: 1e-7,
          );
          _updateZone(updated.copyWith(polygon: cleaned));
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneMerged),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (_draggingVertexPoint != null) {
        final candidatePoly = List<Offset>.from(zone.polygon)
          ..[idx] = _draggingVertexPoint!;
        if (ArchitectZoneGeometry.hasSelfIntersections(candidatePoly)) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneSelfIntersectError),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final cleaned = ArchitectZoneGeometry.cleanPolygon(
            candidatePoly,
            minDistance: 1e-6,
            minCollinearDistance: 1e-7,
          );
          final updated = zone.copyWith(polygon: cleaned);
          _updateZone(updated);
          HapticFeedback.lightImpact();
        }
      }

      setState(() {
        _draggingVertexIndex = null;
        _draggingVertexPoint = null;
        _mergeCandidateIndex = null;
        _activeMagneticGuides = [];
        _activeSnapLabel = null;
      });
      return;
    }

    // 3. Commit whole zone move (GPS_Mapping mode or legacy drag)
    if (_zoneTool.isMoveWholeZoneMode && _zoneTool.isEditingZone) {
      _zoneTool.finishMovingZone();
      final updated = _zoneTool.commitEditingZone();
      if (updated != null) {
        _updateZone(updated);
        _zoneTool.startEditingZone(updated);
      }
      return;
    }
    if (_zoneMoveStartPoint != null) {
      if (_zoneMovePreviewPolygon != null && _selectedZone != null) {
        _updateZone(_selectedZone!.copyWith(polygon: _zoneMovePreviewPolygon));
      }
      setState(() {
        _zoneMovePreviewPolygon = null;
        _zoneMoveStartPoint = null;
        _zoneMoveOriginalPolygon = null;
        _activeMagneticGuides = [];
      });
      return;
    }
  }

  void _handleTap(Offset rawModel) {
    if (_wallInsertPointId != null && _activeTool == ArchitectTool.select) {
      final wall = _selectedWall;
      _wallInsertPointId = null;
      if (wall != null) {
        final (ratio, distance) = wall.projectPoint(rawModel);
        if (distance <= wall.thickness / 2 + 20 / _currentScale) {
          _executeWallEdit(
            SplitArchitectWall(
              storeyId: _project.activeStorey.id,
              wallId: wall.id,
              newWallId: ArchitectElementId.next('wall'),
              ratio: ratio,
            ),
          );
        }
      }
      setState(() {});
      return;
    }
    // 1. In Axis tool
    if (_activeTool == ArchitectTool.axis) {
      // If axis drafting is in progress, commit it
      if (_axisTool.isDrafting) {
        final isBg = Localizations.localeOf(context).languageCode == 'bg';
        _axisTool.updateDrafting(rawModel, _project, _currentScale);
        final result = _axisTool.commitDrafting(
          project: _project,
          isBulgarian: isBg,
        );
        if (result != null) {
          final (updatedProj, newAxis) = result;
          setState(() => _project = updatedProj);
          HapticFeedback.mediumImpact();
        }
        return;
      }

      // Check if existing axis was tapped
      final hitAxis = _axisTool.hitTestAxis(
        rawModel,
        _project.gridAxes,
        tolerance: 16.0 / _currentScale,
      );
      if (hitAxis != null) {
        _axisTool.selectAxis(hitAxis.id);
        setState(() {
          _selectedZoneId = null;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        return;
      }

      // Empty space tap -> start drafting new axis
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModel,
        project: _project,
        tolerance: 14.0 / _currentScale,
      );
      _axisTool.startDrafting(snap.point);
      setState(() {
        _selectedZoneId = null;
        _selectedElementId = null;
      });
      HapticFeedback.lightImpact();
      return;
    }

    // 2. In Zone tool
    if (_activeTool == ArchitectTool.zone) {
      // Point-by-point drafting mode:
      if (_zoneTool.isDrafting) {
        // Immediately compute fresh snap for this tap location (touch devices have no hover)
        _zoneTool.updateDraftingPointer(
          rawModelPoint: rawModel,
          project: _project,
          currentScale: _currentScale,
        );

        if (_zoneTool.isClosingSnap) {
          _commitDraftedZone();
          return;
        }

        final candidate = _zoneTool.candidatePoint ?? rawModel;
        final added = _zoneTool.addDraftingPoint(candidate);
        if (_zoneTool.pointStatus == ZoneDraftingPointStatus.closeTarget) {
          _commitDraftedZone();
        } else if (added) {
          HapticFeedback.lightImpact();
          setState(() {});
          ArchitectLogger.log('DRAFT', 'Added zone drafting point: $candidate');
        } else if (_zoneTool.pointStatus ==
            ZoneDraftingPointStatus.selfIntersects) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectZoneSelfIntersectError),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Check if tapped inside an existing zone to select it
      final hitZone = _findZoneAt(rawModel);
      if (hitZone != null) {
        _zoneTool.startEditingZone(hitZone);
        setState(() {
          _selectedZoneId = hitZone.id;
          _selectedElementId = null;
          _axisTool.deselect();
        });
        HapticFeedback.selectionClick();
        return;
      }

      // If a zone is already selected, tapping empty space deselects it
      if (_selectedZoneId != null) {
        _zoneTool.cancelEditingZone();
        setState(() => _selectedZoneId = null);
        HapticFeedback.selectionClick();
        return;
      }

      // Tapping empty space starts point-by-point drafting!
      final snap = ArchitectZoneSnap.snap(
        raw: rawModel,
        project: _project,
        tolerance: 16.0 / _currentScale,
      );
      final startPt = snap.isSnapped ? snap.point : rawModel;
      _zoneTool.startDrafting(startPt);
      setState(() {
        _selectedZoneId = null;
        _axisTool.deselect();
      });
      HapticFeedback.mediumImpact();
      ArchitectLogger.log(
        'DRAFT',
        'Started zone drafting at point 1: $startPt',
      );
      return;
    }

    // 3. In Select tool
    if (_activeTool == ArchitectTool.select) {
      final hitZone = _findZoneAt(rawModel);
      if (hitZone != null) {
        _zoneTool.startEditingZone(hitZone);
        setState(() {
          _selectedZoneId = hitZone.id;
          _selectedElementId = null;
          _axisTool.deselect();
        });
        HapticFeedback.selectionClick();
        return;
      }

      final hitAxis = _axisTool.hitTestAxis(
        rawModel,
        _project.gridAxes,
        tolerance: 16.0 / _currentScale,
      );
      if (hitAxis != null) {
        _axisTool.selectAxis(hitAxis.id);
        setState(() {
          _selectedZoneId = null;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        return;
      }

      _trySelectElementAt(rawModel);
      return;
    }

    // 4. In Wall tool
    if (_activeTool == ArchitectTool.wall) {
      if (_wallDirectionLocked) return;
      if (_draftStart == null) {
        final snap = _snapWall(rawModel);
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
          _activeSnapLabel = snap.snapLabel;
        });
      } else {
        final snap = _snapWall(rawModel, anchor: _draftStart);
        if ((snap.point - _draftStart!).distance >= .001) {
          setState(() {
            _draftEnd = snap.point;
            _activeSnapLabel = snap.snapLabel;
            _wallDirectionLocked = true;
            _wallPanelAnchor = (_draftStart! + snap.point) / 2;
          });
        }
      }
      return;
    }

    // 5. In Door tool
    if (_activeTool == ArchitectTool.door) {
      _tryPlaceDoorAt(rawModel);
      return;
    }

    // 6. In Window tool
    if (_activeTool == ArchitectTool.window) {
      final res = _elementTool.placeWindow(
        storey: _project.activeStorey,
        point: rawModel,
      );
      if (res != null) {
        final (updatedStorey, newWin) = res;
        setState(() {
          _project = _project.updateActiveStorey(updatedStorey);
        });
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.architectWindowPlaced(
                newWin.id,
                (newWin.width * 100).round(),
                (newWin.height * 100).round(),
              ),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // 7. In Column tool
    if (_activeTool == ArchitectTool.column) {
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModel,
        project: _project,
        tolerance: 12.0 / _currentScale,
      );
      final pt = snap.point;
      final (_, newCol) = _elementTool.placeColumn(
        storey: _project.activeStorey,
        point: pt,
      );
      setState(() {
        _commands.execute(
          PlaceArchitectColumn(
            storeyId: _project.activeStorey.id,
            column: newCol,
          ),
        );
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.architectColumnPlaced(
              '${(newCol.width * 100).round()}x${(newCol.depth * 100).round()}',
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // 8. In Beam tool
    if (_activeTool == ArchitectTool.beam) {
      if (_draftStart == null) {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: rawModel,
          project: _project,
          tolerance: 12.0 / _currentScale,
        );
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
        });
      } else {
        final snap = ArchitectSnapHelper.snapWithAnchor(
          anchor: _draftStart!,
          rawPoint: rawModel,
          project: _project,
          tolerance: 12.0 / _currentScale,
        );
        final res = _elementTool.placeBeam(
          storey: _project.activeStorey,
          start: _draftStart!,
          end: snap.point,
        );
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
            _draftStart = null;
            _draftEnd = null;
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectBeamPlaced),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          setState(() {
            _draftStart = null;
            _draftEnd = null;
          });
        }
      }
      return;
    }

    // 9. In Slab tool
    if (_activeTool == ArchitectTool.slab) {
      final pt = _resolveSlabPoint(rawModel);

      if (_elementTool.slabDraftPoints.length >= 3 &&
          (pt - _elementTool.slabDraftPoints.first).distance <=
              math.min(16.0 / _currentScale, .20)) {
        final res = _elementTool.commitSlab(storey: _project.activeStorey);
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
        }
      } else {
        _elementTool.addSlabPoint(pt);
        HapticFeedback.lightImpact();
      }
      return;
    }

    // 10. In Opening tool
    if (_activeTool == ArchitectTool.opening) {
      if (_draftStart == null) {
        setState(() {
          final point = ArchitectSnapHelper.snapFree(
            rawPoint: rawModel,
            project: _project,
            tolerance: 12.0 / _currentScale,
          ).point;
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final res = _elementTool.placeOpening(
          storey: _project.activeStorey,
          p1: _draftStart!,
          p2: _draftEnd ?? rawModel,
        );
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
            _draftStart = null;
            _draftEnd = null;
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectOpeningPlaced),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          setState(() {
            _draftStart = null;
            _draftEnd = null;
          });
        }
      }
      return;
    }

    // 11. In Stair tool
    if (_activeTool == ArchitectTool.stair) {
      if (_draftStart == null) {
        setState(() {
          final point = ArchitectSnapHelper.snapFree(
            rawPoint: rawModel,
            project: _project,
            tolerance: 12.0 / _currentScale,
          ).point;
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final res = _elementTool.placeStair(
          storey: _project.activeStorey,
          start: _draftStart!,
          end: _draftEnd ?? rawModel,
        );
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
            _draftStart = null;
            _draftEnd = null;
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectStairPlaced),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          setState(() {
            _draftStart = null;
            _draftEnd = null;
          });
        }
      }
      return;
    }

    // 12. In Dimension tool
    if (_activeTool == ArchitectTool.dimension) {
      if (_draftStart == null) {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: rawModel,
          project: _project,
          tolerance: 12.0 / _currentScale,
        );
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
        });
      } else {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: rawModel,
          project: _project,
          tolerance: 12.0 / _currentScale,
        );
        final res = _elementTool.placeDimension(
          storey: _project.activeStorey,
          start: _draftStart!,
          end: snap.point,
        );
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
            _draftStart = null;
            _draftEnd = null;
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectDimensionPlaced),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          setState(() {
            _draftStart = null;
            _draftEnd = null;
          });
        }
      }
      return;
    }

    // 13. In Level Marker tool
    if (_activeTool == ArchitectTool.level) {
      final (updatedStorey, _) = _elementTool.placeElevationMarker(
        storey: _project.activeStorey,
        point: rawModel,
        elevation: _project.activeStorey.elevation,
      );
      setState(() {
        _project = _project.updateActiveStorey(updatedStorey);
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectLevelPlaced),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // 14. In Text tool
    if (_activeTool == ArchitectTool.text) {
      _promptAddAnnotation(rawModel);
      return;
    }

    // 15. In CAD Primitives tools
    if (_activeTool == ArchitectTool.cadLine ||
        _activeTool == ArchitectTool.cadRect ||
        _activeTool == ArchitectTool.cadCircle) {
      if (_draftStart == null) {
        setState(() {
          final point = ArchitectSnapHelper.snapFree(
            rawPoint: rawModel,
            project: _project,
            tolerance: 12.0 / _currentScale,
          ).point;
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final type = _activeTool == ArchitectTool.cadLine
            ? CadPrimitiveType.line
            : _activeTool == ArchitectTool.cadRect
            ? CadPrimitiveType.rect
            : CadPrimitiveType.circle;
        final res = _elementTool.placeCadPrimitive(
          storey: _project.activeStorey,
          type: type,
          start: _draftStart!,
          end: _draftEnd ?? rawModel,
        );
        if (res != null) {
          setState(() {
            _project = _project.updateActiveStorey(res.$1);
            _draftStart = null;
            _draftEnd = null;
          });
          _saveBiMProjectIfAttached();
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectCadShapePlaced),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          setState(() {
            _draftStart = null;
            _draftEnd = null;
          });
        }
      }
      return;
    }

    // 16. In Measure tool
    if (_activeTool == ArchitectTool.measure) {
      if (_draftStart == null) {
        setState(() {
          final point = ArchitectSnapHelper.snapFree(
            rawPoint: rawModel,
            project: _project,
            tolerance: 12.0 / _currentScale,
          ).point;
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final endpoint = _draftEnd ?? rawModel;
        final dist = (endpoint - _draftStart!).distance;
        final dx = (endpoint.dx - _draftStart!.dx).abs();
        final dy = (endpoint.dy - _draftStart!.dy).abs();
        setState(() {
          _draftStart = null;
          _draftEnd = null;
        });
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'L = ${dist.toStringAsFixed(2)} m (dx: ${dx.toStringAsFixed(2)} m, dy: ${dy.toStringAsFixed(2)} m)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
  }

  // === SECTION: ZONE EDITING & MUTATION HANDLERS ===

  void _updateZone(ArchitectZone updated) {
    final activeStorey = _project.activeStorey;
    final updatedZones = activeStorey.zones
        .map((z) => z.id == updated.id ? updated : z)
        .toList();
    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(zones: updatedZones),
      );
    });
    _saveBiMProjectIfAttached();
    if (_zoneTool.editingZone?.id == updated.id) {
      _zoneTool.startEditingZone(updated);
    }
  }

  void _deleteSelectedZone() {
    if (_selectedZoneId == null) return;
    final activeStorey = _project.activeStorey;
    final updatedZones = activeStorey.zones
        .where((z) => z.id != _selectedZoneId)
        .toList();
    _zoneTool.cancelEditingZone();
    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(zones: updatedZones),
      );
      _selectedZoneId = null;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectZoneDeleted),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // === SECTION: WALL & DOOR CONCEPT DRAFTING ===

  void _commitCurrentWallSegment(Offset targetPoint, {bool? continueChain}) {
    if (_draftStart == null) return;
    final p1 = _draftStart!;
    final p2 = targetPoint;
    final len = (p2 - p1).distance;
    if (len < 0.001) return;

    final now = ArchitectElementId.next('element');
    final newWall = ArchitectWall(
      id: 'wall_$now',
      startPoint: p1,
      endPoint: p2,
      thickness: _wallThickness,
      height: _activeWallType?.customHeight ?? _project.activeStorey.height,
      wallTypeId: _activeWallType?.id,
      parapetFinish: _activeWallType?.parapetFinish,
      referenceLine: _wallReference,
    );

    setState(() {
      _commands.execute(
        CreateArchitectWall(storeyId: _project.activeStorey.id, wall: newWall),
      );
      _wallDirectionLocked = false;
      if (continueChain ?? (_wallMode == WallDraftingMode.chained)) {
        _draftStart = p2;
        _draftEnd = p2;
      } else {
        _draftStart = null;
        _draftEnd = null;
        _wallDirectionLocked = false;
        _wallInsertPointId = null;
        _activeSnapLabel = null;
      }
    });
    _saveBiMProjectIfAttached();

    HapticFeedback.lightImpact();
  }

  void _finishChainedWall() {
    setState(() {
      _draftStart = null;
      _draftEnd = null;
      _wallDirectionLocked = false;
      _activeSnapLabel = null;
    });
  }

  void _executeWallEdit(ArchitectModelCommand command) {
    try {
      _commands.execute(command);
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'bg'
                ? 'Промяната пресича отвор или създава твърде къса стена. Изберете друга точка.'
                : 'The edit crosses an opening or creates a wall that is too short. Choose another point.',
          ),
        ),
      );
    }
  }

  void _editWallLength() {
    final wall = _selectedWall;
    if (wall == null) return;
    var length = wall.length;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 250,
          child: ArchitectWallDraftingPanel(
            length: _project.units.toUnit(length),
            unit: _project.units.symbol,
            minimumLength: _project.units.toUnit(.001),
            isBulgarian: Localizations.localeOf(context).languageCode == 'bg',
            onLength: (value) => length = _project.units.fromUnit(value),
            onEnd: () {
              Navigator.of(dialogContext).pop();
              _executeWallEdit(
                UpdateArchitectWall(
                  storeyId: _project.activeStorey.id,
                  wall: wall.copyWith(
                    endPoint: wall.startPoint + wall.unitVector * length,
                  ),
                ),
              );
            },
            onContinue: () {
              Navigator.of(dialogContext).pop();
              _executeWallEdit(
                UpdateArchitectWall(
                  storeyId: _project.activeStorey.id,
                  wall: wall.copyWith(
                    endPoint: wall.startPoint + wall.unitVector * length,
                  ),
                ),
              );
            },
            onUnlock: () => Navigator.of(dialogContext).pop(),
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  void _tryPlaceDoorAt(Offset point) {
    final activeStorey = _project.activeStorey;
    ArchitectWall? targetWall;
    double bestDist = double.infinity;

    for (final wall in activeStorey.walls) {
      final (_, dist) = wall.projectPoint(point);
      if (dist <= wall.thickness / 2.0 + 0.30 && dist < bestDist) {
        bestDist = dist;
        targetWall = wall;
      }
    }

    if (targetWall == null) return;

    final (ratio, _) = targetWall.projectPoint(point);
    final now = ArchitectElementId.next('element');

    final newDoor = ArchitectDoor(
      id: 'door_$now',
      wallId: targetWall.id,
      offsetRatio: ratio,
      width: _doorWidth,
      height: _doorHeight,
      sillHeight: _doorSill,
      isHingeLeft: _isHingeLeft,
      specId: '$_doorSpecCounter',
      uuid: 'UUID_$now',
    );

    _doorSpecCounter++;
    final updatedWall = targetWall.addDoor(newDoor);
    final updatedWalls = activeStorey.walls
        .map((w) => w.id == updatedWall.id ? updatedWall : w)
        .toList();

    setState(() {
      _project = _project.updateActiveStorey(
        activeStorey.copyWith(walls: updatedWalls),
      );
    });
    _saveBiMProjectIfAttached();

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.architectDoorPlaced(
            newDoor.specId,
            (newDoor.width * 100).round(),
            (newDoor.height * 100).round(),
          ),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  bool _tryStartElementDrag(Offset point) {
    final storey = _project.activeStorey;
    // Filled slabs are background surfaces; point/line objects take precedence.
    final id = _elementTool.hitTestElement(
      storey.copyWith(slabs: []),
      point,
      _currentScale,
    );
    if (id == null) return false;
    final movable = [
      ...storey.walls.map((e) => e.id),
      ...storey.columns.map((e) => e.id),
      ...storey.beams.map((e) => e.id),
      ...storey.openings.map((e) => e.id),
      ...storey.stairs.map((e) => e.id),
      ...storey.dimensions.map((e) => e.id),
      ...storey.annotations.map((e) => e.id),
      ...storey.elevationMarkers.map((e) => e.id),
      ...storey.cadPrimitives.map((e) => e.id),
    ].contains(id);
    _zoneTool.cancelEditingZone();
    _axisTool.deselect();
    setState(() {
      _selectedElementId = id;
      _selectedZoneId = null;
    });
    // Hosted doors/windows are selected here; their wall owns their geometry.
    _isHandleEngaged = true;
    if (movable) {
      _draggingElementId = id;
      _elementMoveStart = point;
      _elementMoveDelta = Offset.zero;
      _elementMoveOriginal = _project;
      _elementMovePreview = _project;
    }
    return true;
  }

  void _trySelectElementAt(Offset point) {
    final hitId = _elementTool.hitTestElement(
      _project.activeStorey,
      point,
      _currentScale,
    );
    setState(() {
      _selectedElementId = hitId;
      _selectedZoneId = null;
    });
    _axisTool.deselect();
    if (hitId != null) {
      HapticFeedback.selectionClick();
    }
  }

  String get _selectedElementLabel {
    final s = _project.activeStorey;
    final id = _selectedElementId;
    for (final column in s.columns) {
      if (column.id == id) return column.label;
    }
    for (final beam in s.beams) {
      if (beam.id == id) return beam.label;
    }
    for (final slab in s.slabs) {
      if (slab.id == id) return slab.label;
    }
    for (final opening in s.openings) {
      if (opening.id == id) return opening.label;
    }
    for (final stair in s.stairs) {
      if (stair.id == id) return context.l10n.architectToolStair;
    }
    for (final dimension in s.dimensions) {
      if (dimension.id == id) return dimension.displayText;
    }
    for (final marker in s.elevationMarkers) {
      if (marker.id == id) return marker.formattedElevation;
    }
    for (final annotation in s.annotations) {
      if (annotation.id == id) return annotation.text;
    }
    for (final wall in s.walls) {
      if (wall.id == id) return context.l10n.architectToolWall;
      for (final door in wall.doors) {
        if (door.id == id) {
          return '${context.l10n.architectToolDoor} ${door.specId}';
        }
      }
      for (final window in wall.windows) {
        if (window.id == id) return context.l10n.architectToolWindow;
      }
    }
    return 'CAD';
  }

  void _deleteSelectedElement() {
    if (_selectedElementId == null) return;
    final updatedStorey = _elementTool.deleteElementById(
      _project.activeStorey,
      _selectedElementId!,
    );
    setState(() {
      _project = _project.updateActiveStorey(updatedStorey);
      _selectedElementId = null;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
  }

  Future<void> _promptAddAnnotation(Offset point) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: 'Текст / Кота');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          l10n.architectAnnotationText,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.architectAnnotationText,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty && mounted) {
      final (updatedStorey, _) = _elementTool.placeAnnotation(
        storey: _project.activeStorey,
        point: point,
        text: controller.text.trim(),
      );
      setState(() {
        _project = _project.updateActiveStorey(updatedStorey);
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.architectAnnotationPlaced),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // === SECTION: DYNAMIC GRID AXES ACTIONS ===

  void _handleAxisOffset(StructuralGridAxis axis) {
    showArchitectGridAxisOffsetDialog(
      context: context,
      axis: axis,
      initialDistance: _axisTool.offsetDistanceMeters,
      onApplyOffset: (distance, directionSign) {
        final isBg = Localizations.localeOf(context).languageCode == 'bg';
        final (updatedProj, newAxis) = _axisTool.applyOffset(
          project: _project,
          originalAxis: axis,
          distanceMeters: distance,
          directionSign: directionSign,
          isBulgarian: isBg,
        );
        setState(() {
          _project = updatedProj;
        });
        HapticFeedback.mediumImpact();
        _promptDeletePreviousAxis(axis);
      },
      onStartDragMode: (distance) {
        _axisTool.startOffsetDrag(axis, distance);
      },
    );
  }

  void _promptDeletePreviousAxis(StructuralGridAxis previousAxis) async {
    final shouldDelete = await promptDeletePreviousAxisDialog(
      context: context,
      previousAxis: previousAxis,
    );
    if (shouldDelete && mounted) {
      final isBg = Localizations.localeOf(context).languageCode == 'bg';
      final updatedProj = _axisTool.deleteAxisById(
        _project,
        previousAxis.id,
        isBg,
      );
      setState(() => _project = updatedProj);
      HapticFeedback.lightImpact();
    }
  }

  void _handleAxisAlign(StructuralGridAxis axis) {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedProj = _axisTool.alignSelectedAxis(_project, isBg);
    setState(() => _project = updatedProj);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectAxisAligned),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleAlignAllAxes() {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedProj = _axisTool.alignAllAxes(_project, isBg);
    setState(() => _project = updatedProj);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectAxesAligned),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleResequenceAxes() {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedProj = _axisTool.resequenceAllAxes(_project, isBg);
    setState(() => _project = updatedProj);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectAxesResequenced),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleAxisRename(StructuralGridAxis axis) {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedProj = _axisTool.renameSelectedAxis(_project, isBg);
    if (updatedProj != null) {
      setState(() => _project = updatedProj);
      final updatedAxis = _axisTool.getSelectedAxis(updatedProj);
      HapticFeedback.selectionClick();
      if (updatedAxis != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectAxisRenamed(updatedAxis.name)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _handleAxisDelete(StructuralGridAxis axis) {
    final isBg = Localizations.localeOf(context).languageCode == 'bg';
    final updatedProj = _axisTool.deleteSelectedAxis(_project, isBg);
    if (updatedProj != null) {
      setState(() => _project = updatedProj);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectAxisDeleted),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ===========================================================================
  // WIZARD & ACTIONS
  // ===========================================================================

  Future<void> _openNewProjectWizard() async {
    final newProj = await ArchitectProjectWizardDialog.show(
      context,
      initialProjectName: _project.name,
    );
    if (newProj != null && mounted) {
      setState(() {
        _project = newProj;
        _wallDirectionLocked = false;
        _wallInsertPointId = null;
        if (_project.wallTypes.isNotEmpty) {
          _activeWallType = _project.wallTypes.first;
          _wallThickness = _activeWallType!.totalThickness;
        }
        _draftStart = null;
        _draftEnd = null;
      });
      _saveBiMProjectIfAttached();
      _initTransform();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compactActions = MediaQuery.sizeOf(context).width < 600;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _undoModel,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            _redoModel,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelDrafting,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF141419),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E26),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _project.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.architectStudioSubtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
            actions: [
              IconButton(
                key: const ValueKey('architect-undo'),
                tooltip: 'Undo',
                onPressed: _commands.canUndo ? _undoModel : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const ValueKey('architect-redo'),
                tooltip: 'Redo',
                onPressed: _commands.canRedo ? _redoModel : null,
                icon: const Icon(Icons.redo),
              ),
              // 2D / 3D Toggle Button
              IconButton(
                tooltip: _is3DView
                    ? l10n.architectView2D
                    : l10n.architectView3D,
                icon: Icon(
                  _is3DView
                      ? Icons.crop_square_rounded
                      : Icons.view_in_ar_rounded,
                  color: const Color(0xFF00E5FF),
                ),
                onPressed: () {
                  _cancelActiveDrags();
                  setState(() => _is3DView = !_is3DView);
                },
              ),
              // Reset View Button
              IconButton(
                tooltip: l10n.architectResetView,
                icon: const Icon(Icons.center_focus_strong_rounded),
                onPressed: () {
                  if (_is3DView) {
                    setState(() {
                      _camera3D.yaw = math.pi / 4;
                      _camera3D.pitch = 0.6;
                      _camera3D.zoom = 1.0;
                    });
                  } else {
                    _initTransform();
                  }
                },
              ),
              // New Project Wizard Button
              if (!compactActions)
                IconButton(
                  tooltip: l10n.architectNewProject,
                  icon: const Icon(Icons.add_business_rounded),
                  onPressed: _openNewProjectWizard,
                ),
              // Diagnostic Logs Dialog Button
              if (!compactActions)
                IconButton(
                  tooltip: l10n.architectDebugLogs,
                  icon: const Icon(Icons.bug_report_rounded),
                  onPressed: _showDebugLogsDialog,
                ),
              // CAD Underlay Toggle Button (if underlays are present)
              if (!compactActions && _underlaysByStorey.isNotEmpty)
                IconButton(
                  tooltip: l10n.architectUnderlayToggle,
                  icon: Icon(
                    _showUnderlay
                        ? Icons.layers_rounded
                        : Icons.layers_clear_rounded,
                    color: _showUnderlay
                        ? const Color(0xFF00E5FF)
                        : Colors.white38,
                  ),
                  onPressed: () =>
                      setState(() => _showUnderlay = !_showUnderlay),
                ),
              if (compactActions)
                PopupMenuButton<String>(
                  key: const ValueKey('architect-more'),
                  onSelected: (action) {
                    switch (action) {
                      case 'new':
                        _openNewProjectWizard();
                        break;
                      case 'logs':
                        _showDebugLogsDialog();
                        break;
                      case 'underlay':
                        setState(() => _showUnderlay = !_showUnderlay);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'new',
                      child: Text(l10n.architectNewProject),
                    ),
                    if (_underlaysByStorey.isNotEmpty)
                      PopupMenuItem(
                        value: 'underlay',
                        child: Text(l10n.architectUnderlayToggle),
                      ),
                    PopupMenuItem(
                      value: 'logs',
                      child: Text(l10n.architectDebugLogs),
                    ),
                  ],
                ),
            ],
          ),
          bottomNavigationBar: _is3DView
              ? null
              : ArchitectToolPalette(
                  activeTool: _activeTool,
                  onToolChanged: (tool) => setState(() {
                    _interactionEpoch++;
                    _cancelActiveDrags();
                    _zoneTool.cancelAll();
                    _axisTool.cancelAll();
                    _elementTool.cancelSlabDrafting();
                    _selectedZoneId = null;
                    _selectedElementId = null;
                    _activeTool = tool;
                    _columnPreviewPoint = null;
                    _cursorModel = null;
                    _draftStart = null;
                    _draftEnd = null;
                    _wallDirectionLocked = false;
                    _wallInsertPointId = null;
                    _activeMagneticGuides = [];
                    _activeSnapLabel = null;
                  }),
                  activeZoneCategory: _activeZoneCategory,
                  onZoneCategoryChanged: (cat) =>
                      setState(() => _activeZoneCategory = cat),
                  wallThickness: _wallThickness,
                  onWallThicknessChanged: (t) =>
                      setState(() => _wallThickness = t),
                  wallMode: _wallMode,
                  onWallModeChanged: (m) => setState(() => _wallMode = m),
                  isChainingWall:
                      _draftStart != null &&
                      _wallMode == WallDraftingMode.chained,
                  onFinishChainedWall: () {
                    if (_wallDirectionLocked && _draftEnd != null) {
                      _commitCurrentWallSegment(
                        _draftEnd!,
                        continueChain: false,
                      );
                    } else {
                      _finishChainedWall();
                    }
                  },
                  wallTypes: _project.wallTypes,
                  activeWallType: _activeWallType,
                  onWallTypeSelected: (wt) => setState(() {
                    _activeWallType = wt;
                    _wallThickness = wt.totalThickness;
                  }),
                  doorWidth: _doorWidth,
                  onDoorWidthChanged: (w) => setState(() => _doorWidth = w),
                  doorHeight: _doorHeight,
                  onDoorHeightChanged: (h) => setState(() => _doorHeight = h),
                  doorSill: _doorSill,
                  onDoorSillChanged: (s) => setState(() => _doorSill = s),
                  isHingeLeft: _isHingeLeft,
                  onHingeSideChanged: (left) =>
                      setState(() => _isHingeLeft = left),
                  windowWidth: _elementTool.windowWidth,
                  onWindowWidthChanged: (w) =>
                      _elementTool.setWindowParams(width: w),
                  windowHeight: _elementTool.windowHeight,
                  onWindowHeightChanged: (h) =>
                      _elementTool.setWindowParams(height: h),
                  windowSill: _elementTool.windowSill,
                  onWindowSillChanged: (s) =>
                      _elementTool.setWindowParams(sill: s),
                  columnShape: _elementTool.columnShape,
                  onColumnShapeChanged: (sh) =>
                      _elementTool.setColumnParams(shape: sh),
                  columnWidth: _elementTool.columnWidth,
                  onColumnWidthChanged: (cw) =>
                      _elementTool.setColumnParams(width: cw),
                  columnDepth: _elementTool.columnDepth,
                  onColumnDepthChanged: (cd) =>
                      _elementTool.setColumnParams(depth: cd),
                  beamWidth: _elementTool.beamWidth,
                  onBeamWidthChanged: (bw) =>
                      _elementTool.setBeamParams(width: bw),
                  beamDepth: _elementTool.beamDepth,
                  onBeamDepthChanged: (bd) =>
                      _elementTool.setBeamParams(depth: bd),
                  stairWidth: _elementTool.stairWidth,
                  onStairWidthChanged: (sw) =>
                      _elementTool.setStairParams(width: sw),
                  stairSteps: _elementTool.stairSteps,
                  onStairStepsChanged: (st) =>
                      _elementTool.setStairParams(steps: st),
                  openingType: _elementTool.openingType,
                  onOpeningTypeChanged: (ot) => _elementTool.setOpeningType(ot),
                ),
          body: Column(
            children: [
              // Storey Level Bar
              ArchitectStoreyBar(
                project: _project,
                onStoreySelected: (sId) {
                  _cancelDrafting();
                  _commands.activateStorey(sId);
                  _initTransform();
                  _saveBiMProjectIfAttached();
                },
              ),

              // Main Viewport (2D Canvas or 3D Solid Model)
              Expanded(
                child: Stack(
                  children: [
                    _is3DView ? _build3DViewport() : _build2DCanvas(),
                    if (_activeTool == ArchitectTool.zone && !_is3DView)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: ArchitectZoneDraftingBar(
                          tool: _zoneTool,
                          category: _activeZoneCategory,
                          onClose: _commitDraftedZone,
                          onUndo: () =>
                              setState(() => _zoneTool.undoDraftingPoint()),
                          onCancel: () => setState(() {
                            _zoneTool.cancelDrafting();
                            _selectedZoneId = null;
                          }),
                        ),
                      ),
                    if (_activeTool == ArchitectTool.axis && !_is3DView)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: ArchitectGridAxisBar(
                          tool: _axisTool,
                          axisCount: _project.gridAxes.length,
                          onResequence: _handleResequenceAxes,
                          onAlignAll: _handleAlignAllAxes,
                        ),
                      ),
                  ],
                ),
              ),

              // Floating Zone Property Inspector Card if a zone is selected
              if (_selectedZone != null && !_is3DView)
                ArchitectZonePropertiesCard(
                  zone: _selectedZone!,
                  tool: _zoneTool,
                  onZoneUpdated: _updateZone,
                  onDeleteZone: _deleteSelectedZone,
                  onClose: () {
                    _zoneTool.cancelEditingZone();
                    setState(() => _selectedZoneId = null);
                  },
                ),

              // Floating Axis Property Inspector Card if an axis is selected
              if (_axisTool.selectedAxisId != null && !_is3DView)
                Builder(
                  builder: (ctx) {
                    final selectedAxis = _axisTool.getSelectedAxis(_project);
                    if (selectedAxis == null) return const SizedBox.shrink();
                    return ArchitectGridAxisPropertiesCard(
                      axis: selectedAxis,
                      onOffset: () => _handleAxisOffset(selectedAxis),
                      onAlign: () => _handleAxisAlign(selectedAxis),
                      onRename: () => _handleAxisRename(selectedAxis),
                      onDelete: () => _handleAxisDelete(selectedAxis),
                      onClose: () => _axisTool.deselect(),
                    );
                  },
                ),

              // Floating Element Selection Bar if an element is selected
              if (_selectedElementId != null && !_is3DView)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF1E1E26),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF00E5FF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.selectedElement(_selectedElementLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_selectedWall != null) ...[
                        IconButton(
                          key: const ValueKey('wall-edit-length'),
                          icon: const Icon(
                            Icons.straighten,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          tooltip:
                              Localizations.localeOf(context).languageCode ==
                                  'bg'
                              ? 'Точна дължина'
                              : 'Exact length',
                          onPressed: _editWallLength,
                        ),
                        IconButton(
                          key: const ValueKey('wall-insert-point'),
                          icon: Icon(
                            Icons.add_location_alt_outlined,
                            color: _wallInsertPointId != null
                                ? Colors.amber
                                : Colors.cyanAccent,
                            size: 20,
                          ),
                          tooltip:
                              Localizations.localeOf(context).languageCode ==
                                  'bg'
                              ? 'Нова точка: посочете по стената'
                              : 'Insert point: tap the wall',
                          onPressed: () => setState(
                            () => _wallInsertPointId = _selectedWall!.id,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('wall-parallel-move'),
                          icon: Icon(
                            Icons.swap_vert,
                            color: _wallParallelMove
                                ? Colors.amber
                                : Colors.white54,
                            size: 20,
                          ),
                          tooltip:
                              Localizations.localeOf(context).languageCode ==
                                  'bg'
                              ? 'Успоредно изтегляне'
                              : 'Parallel drag',
                          onPressed: () => setState(
                            () => _wallParallelMove = !_wallParallelMove,
                          ),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        tooltip: context.l10n.delete,
                        onPressed: _deleteSelectedElement,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        tooltip: context.l10n.close,
                        onPressed: () =>
                            setState(() => _selectedElementId = null),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // === SECTION: DIAGNOSTIC LOGS DIALOG (ARCHITECT LOGGER) ===

  void _showDebugLogsDialog() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final logs = ArchitectLogger.history;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              title: Row(
                children: [
                  const Icon(
                    Icons.bug_report_rounded,
                    color: Color(0xFF00E5FF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.architectDebugLogs,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 400,
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          l10n.architectNoLogs,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          // Reverse chronological order (newest on top)
                          final logItem = logs[logs.length - 1 - index];
                          final isGesture =
                              logItem.contains('[GESTURE]') ||
                              logItem.contains('[VIEWPORT]') ||
                              logItem.contains('[POINTER_');
                          final isError = logItem.contains('[ERROR]');
                          final isTap = logItem.contains('[TAP]');
                          final color = isError
                              ? Colors.redAccent
                              : isTap
                              ? const Color(0xFF00E676)
                              : isGesture
                              ? const Color(0xFF00E5FF)
                              : Colors.white70;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              logItem,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ArchitectLogger.clear();
                    setDialogState(() {});
                  },
                  child: Text(l10n.architectClearLogs),
                ),
                TextButton(
                  onPressed: logs.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: logs.join('\n')),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.copied),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                  child: Text(l10n.architectCopyLogs),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === SECTION: 2D CANVAS VIEWPORT (LAYERED MODEL SPACE) ===

  Widget _build2DCanvas() => Stack(
    children: [
      ArchitectViewport(
        controller: _viewport,
        interactionKey: (
          _interactionEpoch,
          _activeTool,
          _project.id,
          _project.activeStoreyId,
        ),
        singlePointerPan:
            _activeTool == ArchitectTool.select ||
            _activeTool == ArchitectTool.wall,
        isDraggingHandle: () => _isActivelyDraggingHandle,
        onToolDown: _onPointerDown,
        onToolMove: _onPointerMove,
        onToolHover: _onPointerHover,
        onToolUp: _onPointerUp,
        onToolCancel: () {
          _cancelActiveDrags();
          _repaintPreview();
        },
        onFirstLayout: (_) {
          if (!_hasFramedViewport) {
            _hasFramedViewport = true;
            _initTransform();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF3F5F7)),
            RepaintBoundary(
              child: CustomPaint(
                painter: ArchitectUnderlayPainter(
                  document: _currentUnderlayDoc,
                  frame: widget.underlayFrame,
                  viewport: _viewport,
                  visibility: Map.of(_underlayLayerVisibility),
                ),
              ),
            ),
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _previewRevision,
                builder: (_, revision, child) => CustomPaint(
                  painter: _makePainter(ArchitectPaintLayer.model),
                ),
              ),
            ),
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _previewRevision,
                builder: (_, revision, child) => CustomPaint(
                  painter: _makePainter(ArchitectPaintLayer.interaction),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: IgnorePointer(
                child: ValueListenableBuilder<int>(
                  valueListenable: _previewRevision,
                  builder: (context, revision, child) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xE61E1E26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _cursorModel == null
                            ? (Localizations.localeOf(context).languageCode ==
                                      'bg'
                                  ? '2 пръста: местене/мащаб • мишка: среден бутон/колело'
                                  : '2 fingers: pan/zoom • mouse: middle button/wheel')
                            : 'X: ${_project.units.format((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dx, decimals: 3)}  '
                                  'Y: ${_project.units.format((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dy, decimals: 3)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_activeTool == ArchitectTool.wall)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<WallReferenceLine>(
                value: _wallReference,
                dropdownColor: const Color(0xFF1E242C),
                underline: const SizedBox.shrink(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
                items: [
                  for (final reference in WallReferenceLine.values)
                    DropdownMenuItem(
                      value: reference,
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'bg'
                            ? switch (reference) {
                                WallReferenceLine.center => 'Водеща: център',
                                WallReferenceLine.left => 'Водеща: ляв край',
                                WallReferenceLine.right => 'Водеща: десен край',
                              }
                            : 'Reference: ${reference.name}',
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _wallReference = value);
                },
              ),
            ),
          ),
        ),
      if (_activeTool == ArchitectTool.wall)
        AnimatedBuilder(
          animation: Listenable.merge([_viewport, _previewRevision]),
          builder: (context, _) {
            if (!_wallDirectionLocked ||
                _draftStart == null ||
                _draftEnd == null) {
              return const SizedBox.shrink();
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final point = _viewport.toScreen(
                  _wallPanelAnchor ?? (_draftStart! + _draftEnd!) / 2,
                );
                final width = math.min(250.0, constraints.maxWidth - 16);
                final left = (point.dx + 20).clamp(
                  8.0,
                  math.max(8.0, constraints.maxWidth - width - 8),
                );
                final top = (point.dy + 24).clamp(
                  8.0,
                  math.max(8.0, constraints.maxHeight - 320),
                );
                return Stack(
                  children: [
                    Positioned(
                      left: left.toDouble(),
                      top: top.toDouble(),
                      width: width,
                      child: ArchitectWallDraftingPanel(
                        key: ValueKey((_draftStart, _wallDirectionLocked)),
                        length: _project.units.toUnit(
                          (_draftEnd! - _draftStart!).distance,
                        ),
                        unit: _project.units.symbol,
                        minimumLength: _project.units.toUnit(.001),
                        isBulgarian:
                            Localizations.localeOf(context).languageCode ==
                            'bg',
                        onLength: (value) {
                          if (_project.units.fromUnit(value) < .001) return;
                          final delta = _draftEnd! - _draftStart!;
                          if (delta.distance < .001) return;
                          _draftEnd =
                              _draftStart! +
                              delta /
                                  delta.distance *
                                  _project.units.fromUnit(value);
                          _activeSnapLabel = null;
                          _repaintPreview();
                        },
                        onEnd: () => _commitCurrentWallSegment(
                          _draftEnd!,
                          continueChain: false,
                        ),
                        onContinue: () => _commitCurrentWallSegment(
                          _draftEnd!,
                          continueChain: true,
                        ),
                        onUnlock: () =>
                            setState(() => _wallDirectionLocked = false),
                        onCancel: _finishChainedWall,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
    ],
  );

  Architect2dPainter _makePainter(ArchitectPaintLayer layer) =>
      Architect2dPainter(
        project: _elementMovePreview ?? _project,
        viewport: _viewport,
        layer: layer,
        activeTool: _activeTool,
        cursorPosition: _cursorModel,
        columnPreview:
            _activeTool == ArchitectTool.column && _columnPreviewPoint != null
            ? ArchitectColumn(
                id: 'preview',
                position: _columnPreviewPoint!,
                width: _elementTool.columnWidth,
                depth: _elementTool.columnDepth,
                shape: _elementTool.columnShape,
              )
            : null,
        activeDraftStart: _draftStart,
        activeDraftEnd: _draftEnd,
        activeWallThickness: _wallThickness,
        activeWallReference: _wallReference,
        activeSnapLabel: _activeSnapLabel,
        selectedElementId: _selectedElementId,
        selectedZoneId: _selectedZoneId,
        activeZoneCategory: _activeZoneCategory,
        draggingVertexIndex: _draggingVertexIndex,
        draggingVertexPoint: _draggingVertexPoint,
        mergeCandidateIndex: _mergeCandidateIndex,
        selectedAxisId: _axisTool.selectedAxisId,
        draggedAxisSnapshot: _axisTool.draggedAxisSnapshot,
        isDraggingAxisHandle: _axisTool.isDraggingHandle,
        isMovingAxis: _axisTool.isMovingAxis,
        moveOriginalAxis: _axisTool.moveOriginalAxis,
        moveCurrentDelta: _axisTool.moveCurrentDelta,
        axisOffsetPreview: _axisTool.getOffsetPreview(
          Localizations.localeOf(context).languageCode == 'bg',
        ),
        axisDraftStart: _axisTool.draftStart,
        axisDraftEnd: _axisTool.draftEnd,
        axisDraftSnapLabel: _axisTool.draftSnapLabel,
        magneticGuides: _zoneTool.isDrafting
            ? _zoneTool.magneticGuides
            : _activeMagneticGuides,
        zoomScale: _currentScale,
        zoneDraftingPoints: _zoneTool.draftPoints,
        zoneDraftingCandidate: _zoneTool.candidatePoint,
        zoneOrthoGuide: _zoneTool.orthoGuide,
        zoneOrthoLabel: _zoneTool.orthoLabel,
        isZoneClosingSnap: _zoneTool.isClosingSnap,
        isZoneDraftingSelfIntersecting:
            _zoneTool.pointStatus == ZoneDraftingPointStatus.selfIntersects,
        zoneCloseLabel: context.l10n.architectZonePointSnapStart,
        zoneExtrudePreviewPolygon: _zoneTool.extrudePreviewPolygon,
        zoneExtrudeV1: _zoneTool.extrudeV1,
        zoneExtrudeV2: _zoneTool.extrudeV2,
        zoneExtrudeNormal: _zoneTool.extrudeNormal,
        zoneExtrudeDistance: _zoneTool.extrudeDistance,
        isZoneExtrudeSelfIntersecting: _zoneTool.isExtrudeSelfIntersecting,
        zonePreviewRectangle: _zoneTool.previewRectangle,
        zoneEditingPolygon: _zoneMovePreviewPolygon ?? _zoneTool.editingPolygon,
        isMoveWholeZoneMode: _zoneTool.isMoveWholeZoneMode,
        zoneMoveDistanceMeters: _zoneTool.moveDistanceMeters,

        underlayLayerVisibility: _underlayLayerVisibility,
        slabDraftPoints: _elementTool.slabDraftPoints,
        slabCandidatePoint: _elementTool.slabCandidatePoint,
      );

  // === SECTION: 3D SOLID VIEWPORT ===

  Widget _build3DViewport() {
    final mesh = Architect3dBuilder.buildProjectMesh(_project);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _camera3D.yaw += details.delta.dx * 0.01;
          _camera3D.pitch = (_camera3D.pitch + details.delta.dy * 0.01).clamp(
            0.05,
            math.pi / 2 - 0.05,
          );
        });
      },
      child: Container(
        color: const Color(0xFF181A20),
        child: CustomPaint(
          size: Size.infinite,
          painter: Cad3DMeshPainter(
            mesh: mesh,
            camera: _camera3D,
            shadingMode: Cad3DShadingMode.smoothShaded,
            theme: Cad3DTheme.darkCad,
            showGrid: true,
            isInteracting: false,
          ),
        ),
      ),
    );
  }
}
