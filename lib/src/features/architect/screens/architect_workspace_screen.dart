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
import '../../structural_designer/analysis/structural_pointer_interaction.dart';
import '../../structural_designer/rendering/structural_pointer_painter.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
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
import '../rendering/architect_wall_geometry.dart';
import '../rendering/architect_zone_snap.dart';
import '../rendering/architect_underlay_painter.dart';
import '../rendering/architect_scene_geometry.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_element_tool.dart';
import '../services/architect_polygon_editor.dart';
import '../services/architect_polygon_dimensions.dart';
import '../services/architect_polygon_geometry.dart';
import '../widgets/architect_polygon_distance_overlay.dart';
import '../widgets/architect_shape_dimension_panel.dart';
import '../services/architect_selection.dart';
import '../services/architect_wall_relations.dart';
import '../rendering/architect_dimension_layout.dart';
import '../rendering/architect_wall_network.dart';
import '../widgets/architect_element_properties_dialog.dart';
import '../widgets/architect_radial_menu.dart';
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
import 'fenestration_editor_screen.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.architectSaveFailed)));
    }
  }

  void _onModelChanged() {
    if (!mounted) return;
    final valid = {
      for (final e in ArchitectSelection.records(
        _project.toJson(),
        _project.activeStoreyId,
      ))
        e['id'] as String,
    };
    _polygonSelectedEdge = null;
    if (_polygonEditId != null && !valid.contains(_polygonEditId)) {
      _polygonEditId = null;
    }
    _selectionIds.removeWhere((id) => !valid.contains(id));
    if (_selectedElementId != null && !valid.contains(_selectedElementId)) {
      _selectedElementId = null;
    }
    if (_selectedZoneId != null && !valid.contains(_selectedZoneId)) {
      _selectedZoneId = null;
      _zoneTool.cancelEditingZone();
    }
    if (_axisTool.selectedAxisId != null &&
        !valid.contains(_axisTool.selectedAxisId)) {
      _axisTool.deselect();
    }
    if (_wallExtendId != null && !valid.contains(_wallExtendId)) {
      _wallExtendId = null;
    }
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
    _polygonEditId = null;
    _polygonSelectedEdge = null;
    _pendingShape = null;
    _shapePanelAnchor = null;
    _selectionIds.clear();
    _wallCutIds = {};
    _wallCutStart = null;
    _wallStartAttachment = null;
    _wallExtendId = null;
    _multiSelect = false;
    _moveSelection = false;
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
  CadPrimitiveType? _pendingShape;
  Offset? _shapePanelAnchor;
  final _polygonEditor = ArchitectPolygonEditor();
  ArchitectPolygonEdgeMode _polygonEdgeMode = ArchitectPolygonEdgeMode.pull;
  String? _polygonEditId;
  int? _polygonSelectedEdge;
  bool _polygonDistanceOpen = false;
  Offset? _radialMenuScreenPosition;
  String? _radialMenuElementId;
  List<ArchitectRadialMenuItem> _radialMenuItems = [];
  bool _wallDirectionLocked = false;
  Offset? _wallPanelAnchor;
  WallReferenceLine _wallReference = WallReferenceLine.center;
  WallExteriorSide _wallExteriorSide = WallExteriorSide.left;
  String? _wallExtendId;
  Set<String> _wallCutIds = {};
  Offset? _wallCutStart;
  bool _magnetEnabled = true;
  bool _wallCutStroke = false;
  bool _controlTrimClick = false;
  ArchitectWallAttachment? _wallStartAttachment;
  final Set<String> _selectionIds = {};
  Set<String> _groupDragIds = {};
  bool _multiSelect = false;
  bool _moveSelection = false;
  Set<String> get _effectiveSelection => _multiSelect
      ? Set.of(_selectionIds)
      : {
          ?_selectedElementId,
          ?_selectedZoneId,
          if (_axisTool.selectedAxisId != null) _axisTool.selectedAxisId!,
        };
  bool _touchInput = false;
  bool _placingWithHold = false;
  bool _wallPrecisionMode = true;
  Offset? _touchPosition;
  ArchitectWall? _wallEndpointOriginal;
  ArchitectProject? _wallSnapProject;
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
      _polygonEditor.active ||
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
    FenestrationLibraryService.instance.init().then((_) {
      if (mounted) {
        _elementTool.activeWindowStyle ??=
            FenestrationLibraryService.instance.activeWindowStyle;
        _elementTool.activeDoorStyle ??=
            FenestrationLibraryService.instance.activeDoorStyle;
        setState(() {});
      }
    });

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
      padding: 80,
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
    if (_radialMenuScreenPosition != null) {
      setState(() => _radialMenuScreenPosition = null);
    }
    _touchInput = event.kind == PointerDeviceKind.touch;
    _handlePointerDown = event.localPosition;
    _handleMoved = false;
    _isHandleEngaged = false;

    final rawModel = _screenToModel(event.localPosition);
    if (_polygonDistanceOpen) return;
    if (_polygonEditId != null) _selectPolygonEdge(rawModel);
    if (_activeTool == ArchitectTool.wall &&
        event.kind == PointerDeviceKind.mouse &&
        HardwareKeyboard.instance.isControlPressed) {
      final span = _trimSpanAt(rawModel, restrictSelection: false);
      if (span != null) {
        _controlTrimClick = true;
        _executeWallEdit(
          TrimArchitectWall(
            storeyId: _project.activeStoreyId,
            wallId: span.wall.id,
            pick: rawModel,
          ),
        );
        return;
      }
    }
    if (_wallCutIds.isNotEmpty) {
      _cursorModel = rawModel;
      _repaintPreview();
      return;
    }
    if (_wallExtendId != null) return;
    if (_activeTool != ArchitectTool.select &&
        (_multiSelect || _moveSelection)) {
      final id = _hitSelection(rawModel);
      if (_moveSelection && id != null && _effectiveSelection.contains(id)) {
        _groupDragIds = _effectiveSelection;
        _draggingElementId = id;
        _elementMoveStart = rawModel;
        _elementMoveDelta = Offset.zero;
        _elementMoveOriginal = _project;
        _elementMovePreview = _project;
        _isHandleEngaged = true;
      }
      return;
    }
    final polygon = _selectedPolygon;
    final movableEdge =
        polygon != null &&
            _polygonEditId != null &&
            _polygonEdgeMode == ArchitectPolygonEdgeMode.move &&
            !polygon.any((p) => (p - rawModel).distance < 10 / _currentScale)
        ? ArchitectPolygonDimensions.hitEdge(
            polygon,
            rawModel,
            18 / _currentScale,
          )
        : null;
    if (polygon != null &&
        (movableEdge != null
            ? _polygonEditor.startEdge(
                (_selectedElementId ?? _selectedZoneId)!,
                polygon,
                movableEdge,
                rawModel,
                _currentScale,
              )
            : _polygonEditor.start(
                (_selectedElementId ?? _selectedZoneId)!,
                polygon,
                rawModel,
                _currentScale,
                mode: _polygonEditId == null
                    ? ArchitectPolygonEdgeMode.pull
                    : _polygonEdgeMode,
              ))) {
      _elementMoveOriginal = _project;
      _elementMovePreview = _project;
      _isHandleEngaged = true;
      HapticFeedback.selectionClick();
      return;
    }
    if (_activeTool == ArchitectTool.wall) {
      _placingWithHold = !_touchInput;
      _touchPosition = null;
      if (!_touchInput) _updatePointerPreview(event.localPosition);
      _repaintPreview();
    }
    if (_activeTool == ArchitectTool.wall && _selectedWall != null) {
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
    if (_activeTool == ArchitectTool.axis && !_axisTool.isDrafting) {
      // 1a. Handle hit check (stretching axis extents)
      final axisHandle = _axisTool.hitTestAxisHandle(
        rawModel,
        _project.gridAxes
            .where((a) => a.id == _axisTool.selectedAxisId)
            .toList(),
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

      // 1b. Axis body hit check (select or start move if already selected)
      final hitAxis = _axisTool.hitTestAxis(
        rawModel,
        _project.gridAxes,
        tolerance: 16.0 / _currentScale,
      );
      if (_wallForAxis(rawModel) != null &&
          (_axisTool.selectedAxisId == null ||
              hitAxis?.id != _axisTool.selectedAxisId)) {
        return;
      }
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
    if (_activeTool == ArchitectTool.zone) {
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

    if (_effectiveSelection.isNotEmpty &&
        _activeTool != ArchitectTool.select &&
        _tryStartElementDrag(rawModel)) {
      return;
    }

    // No handle engaged on pointer-down: free pan/zoom candidate
    ArchitectLogger.log(
      'VIEWPORT',
      'Pointer down at $rawModel - no handle hit, tool input candidate',
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_touchInput &&
        _isActivelyDraggingHandle &&
        !_handleMoved &&
        _handlePointerDown != null &&
        (event.localPosition - _handlePointerDown!).distance <= 6) {
      return;
    }
    if (_handlePointerDown != null &&
        (event.localPosition - _handlePointerDown!).distance > 1e-6) {
      _handleMoved = true;
    }
    if (_touchInput && _placingWithHold) {
      _touchPosition = event.localPosition;
    }
    _updatePointerPreview(_placementPosition(event.localPosition));
  }

  void _beginPlacementHold(Offset point) {
    if (!_canPlaceWithMarker) return;
    if (_effectiveSelection.isNotEmpty &&
        _wallCutIds.isEmpty &&
        _wallExtendId == null &&
        _wallInsertPointId == null) {
      // A hold on empty space resumes placement with the same active tool.
      setState(() {
        _selectionIds.clear();
        _selectedElementId = null;
        _selectedZoneId = null;
        _zoneTool.cancelAll();
        _axisTool.cancelAll();
      });
    }
    _placingWithHold = true;
    _touchPosition = point;
    _updatePointerPreview(_placementPosition(point));
    HapticFeedback.selectionClick();
  }

  bool get _canPlaceWithMarker =>
      _activeTool != ArchitectTool.select &&
      !_wallDirectionLocked &&
      _polygonEditId == null &&
      _pendingShape == null;

  Offset? get _placementPreviewTarget {
    final raw = _cursorModel;
    if (raw != null &&
        (_activeTool == ArchitectTool.door ||
            _activeTool == ArchitectTool.window)) {
      ArchitectWall? host;
      var best = double.infinity;
      for (final wall in _project.activeStorey.walls) {
        final (_, distance) = wall.projectPoint(raw);
        if (distance <= wall.thickness / 2 + .30 && distance < best) {
          host = wall;
          best = distance;
        }
      }
      if (host != null) {
        final (ratio, _) = host.projectPoint(raw);
        return host.centerStart + (host.centerEnd - host.centerStart) * ratio;
      }
    }
    return _draftEnd ?? raw;
  }

  Offset _placementPosition(Offset point) =>
      _canPlaceWithMarker && !_isActivelyDraggingHandle
      ? StructuralPointerInteraction.placementTarget(
          point,
          isMouse: !_touchInput || !_placingWithHold,
        )
      : point;

  ArchitectSnapResult _snapWall(Offset raw, {Offset? anchor}) =>
      ArchitectWallSnap.resolve(
        raw: raw,
        anchor: anchor,
        project: _project,
        scale: _currentScale,
        capturePixels: _touchInput ? 12 : 8,
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
      );

  ArchitectSnapResult _snapElement(Offset raw, {Offset? anchor}) {
    final snap = anchor == null
        ? ArchitectSnapHelper.snapFree(
            rawPoint: raw,
            project: _project,
            tolerance: (_touchInput ? 12 : 8) / _currentScale,
            magnetic: _magnetEnabled,
            alignment: true,
            underlay: _currentUnderlayDoc,
            frame: widget.underlayFrame,
            visibility: _underlayLayerVisibility,
          )
        : ArchitectSnapHelper.snapWithAnchor(
            rawPoint: raw,
            anchor: anchor,
            project: _project,
            tolerance: (_touchInput ? 12 : 8) / _currentScale,
            magnetic: _magnetEnabled,
            alignment: true,
            underlay: _currentUnderlayDoc,
            frame: widget.underlayFrame,
            visibility: _underlayLayerVisibility,
          );
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    return snap;
  }

  Offset _snapMovingElements(Offset delta, Set<String> ids) {
    final snap = ArchitectSnapHelper.snapTranslation(
      project: _elementMoveOriginal!,
      elementIds: ids,
      delta: delta,
      tolerance: (_touchInput ? 12 : 8) / _currentScale,
      magnetic: _magnetEnabled,
      underlay: _currentUnderlayDoc,
      frame: widget.underlayFrame,
      visibility: _underlayLayerVisibility,
    );
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    return snap.point;
  }

  List<Offset>? get _selectedPolygon {
    final id = _selectedElementId ?? _selectedZoneId;
    if (id == null) return null;
    for (final p in _project.activeStorey.cadPrimitives) {
      if (p.id == id && p.type == CadPrimitiveType.rect) {
        return p.polygonCorners;
      }
    }
    for (final slab in _project.activeStorey.slabs) {
      if (slab.id == id) return slab.polygon;
    }
    for (final zone in _project.activeStorey.zones) {
      if (zone.id == id) return zone.polygon;
    }
    return null;
  }

  void _updatePointerPreview(Offset screenPosition) {
    if (_pendingShape != null) return;
    final rawModel = _screenToModel(screenPosition);
    _cursorModel = rawModel;
    if (_polygonEditor.active) {
      _polygonEditor.update(
        rawModel,
        (point) => ArchitectSnapHelper.snapFree(
          rawPoint: point,
          project: _elementMoveOriginal!,
          tolerance: 12 / _currentScale,
          magnetic: _magnetEnabled,
          alignment: true,
          excludedIds: {_polygonEditor.elementId!},
          underlay: _currentUnderlayDoc,
          frame: widget.underlayFrame,
          visibility: _underlayLayerVisibility,
        ),
        math.min(12 / _currentScale, .20),
      );
      final snap = _polygonEditor.activeSnap;
      _activeSnapLabel = snap?.snapLabel;
      _activeMagneticGuides = snap?.magneticGuides ?? [];
      _elementMovePreview = UpdateArchitectPolygon(
        storeyId: _project.activeStoreyId,
        elementId: _polygonEditor.elementId!,
        polygon: _polygonEditor.preview!,
      ).apply(_elementMoveOriginal!);
      _repaintPreview();
      return;
    }
    if (_activeTool == ArchitectTool.axis &&
        !_axisTool.isDrafting &&
        !_isActivelyDraggingHandle) {
      final wall = _wallForAxis(rawModel);
      if (wall != null) {
        final d = rawModel - wall.coreCenterStart;
        final along = (d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy)
            .clamp(0.0, wall.length);
        _cursorModel = wall.coreCenterStart + wall.unitVector * along;
        _activeSnapLabel = 'Center';
        _repaintPreview();
        return;
      }
    }
    if (_wallCutIds.isNotEmpty) {
      _repaintPreview();
      return;
    }
    if (_activeTool == ArchitectTool.wall &&
        _draftStart == null &&
        !_isActivelyDraggingHandle) {
      final snap = _snapWall(rawModel);
      _adoptWallReference(snap.wallAttachment);
      _cursorModel = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _activeMagneticGuides = snap.magneticGuides;
      _repaintPreview();
      return;
    }
    if (_wallEndpointOriginal != null && _elementMoveOriginal != null) {
      final original = _wallEndpointOriginal!;
      final snapProject = _wallSnapProject ??= _project.updateActiveStorey(
        _project.activeStorey.copyWith(
          walls: _project.activeStorey.walls
              .where((w) => w.id != original.id)
              .toList(),
        ),
      );
      final snap = ArchitectWallSnap.resolve(
        raw: rawModel + _wallGrabOffset,
        magnetic: _magnetEnabled,
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
          carryConnections: false,
        ).apply(_elementMoveOriginal!);
        _activeSnapLabel = snap.snapLabel;
        _activeMagneticGuides = snap.magneticGuides;
      } on ArgumentError {
        /* Keep the last valid preview. */
      }
      _repaintPreview();
      return;
    }
    if (_activeTool == ArchitectTool.column && !_isActivelyDraggingHandle) {
      final snap = _snapElement(rawModel);
      _columnPreviewPoint = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _cursorModel = _columnPreviewPoint;
      _repaintPreview();
      return;
    }

    if (_groupDragIds.isNotEmpty &&
        _elementMoveStart != null &&
        _elementMoveOriginal != null) {
      var delta = ArchitectSnapHelper.precision(
        _project,
      ).inputPoint(rawModel - _elementMoveStart!);
      if (_magnetEnabled &&
          _elementMoveOriginal!.activeStorey.walls.any(
            (w) => _groupDragIds.contains(w.id),
          )) {
        final alignment = ArchitectWallAlignment.move(
          _elementMoveOriginal!.activeStorey.walls,
          _groupDragIds,
          delta,
          _currentScale,
        );
        delta = alignment.$1;
        _activeMagneticGuides = alignment.$2;
      } else {
        delta = _snapMovingElements(delta, _groupDragIds);
      }
      try {
        _elementMovePreview = MoveArchitectElements(
          storeyId: _project.activeStoreyId,
          elementIds: _groupDragIds,
          delta: delta,
        ).apply(_elementMoveOriginal!);
        _elementMoveDelta = delta;
      } on ArgumentError {
        _elementMoveDelta = null;
      }
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
      if (selectedWall != null && _magnetEnabled) {
        final alignment = ArchitectWallAlignment.move(
          _elementMoveOriginal!.activeStorey.walls,
          {selectedWall.id},
          delta,
          _currentScale,
          parallelOnly: _wallParallelMove,
        );
        delta = alignment.$1;
        _activeMagneticGuides = alignment.$2;
      } else if (selectedWall == null) {
        delta = _snapMovingElements(delta, {_draggingElementId!});
      }
      _elementMoveDelta = delta;
      if (selectedWall != null) {
        try {
          _elementMovePreview = MoveArchitectElement(
            storeyId: _project.activeStorey.id,
            elementId: selectedWall.id,
            delta: delta,
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
      _axisTool.updateDrafting(
        rawModel,
        _project,
        _currentScale,
        magnetic: _magnetEnabled,
        snapper: (anchor) => _snapElement(rawModel, anchor: anchor),
      );
      _cursorModel = _axisTool.draftEnd;
      _activeSnapLabel = _axisTool.draftSnapLabel;
      _repaintPreview();
      return;
    }

    // 1. Point-by-point zone drafting preview
    if (_activeTool == ArchitectTool.zone && _zoneTool.isDrafting) {
      _zoneTool.updateDraftingPointer(
        rawModelPoint: rawModel,
        project: _project,
        currentScale: _currentScale,
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
      );
      _cursorModel = _zoneTool.candidatePoint;
      _repaintPreview();
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
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
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
      _activeMagneticGuides = snap.magneticGuides;
      _orientWallReference(snap.point);
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
          ? _snapElement(rawModel)
          : _snapElement(rawModel, anchor: _draftStart);
      _draftEnd = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _repaintPreview();
      return;
    }

    // 7. Slab drafting candidate
    if (_activeTool == ArchitectTool.slab &&
        _elementTool.slabDraftPoints.isNotEmpty) {
      _elementTool.updateSlabCandidate(_resolveSlabPoint(rawModel));
      _cursorModel = _elementTool.slabCandidatePoint;
    } else if (_canPlaceWithMarker &&
        _activeTool != ArchitectTool.door &&
        _activeTool != ArchitectTool.window) {
      final snap = _snapElement(rawModel);
      _cursorModel = snap.point;
      _activeSnapLabel = snap.snapLabel;
    }
    _repaintPreview();
  }

  Offset _resolveSlabPoint(Offset raw) {
    final points = _elementTool.slabDraftPoints;
    if (points.length >= 3 &&
        (raw - points.first).distance <= math.min(16 / _currentScale, .20)) {
      return points.first;
    }
    return _snapElement(raw, anchor: points.lastOrNull).point;
  }

  void _onPointerHover(PointerHoverEvent event) {
    _touchInput = false;
    _updatePointerPreview(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_controlTrimClick) {
      _controlTrimClick = false;
      return;
    }
    if (_isActivelyDraggingHandle && !_handleMoved) {
      if (_polygonEditId != null) {
        _selectPolygonEdge(_screenToModel(event.localPosition));
      }
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
    _placingWithHold = false;
    _touchPosition = null;
    _repaintPreview();
  }

  void _cancelActiveDrags() {
    _polygonEditor.cancel();
    _radialMenuScreenPosition = null;
    _controlTrimClick = false;
    _groupDragIds = {};
    _placingWithHold = false;
    _touchPosition = null;
    _wallEndpointOriginal = null;
    _wallSnapProject = null;
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
    if (_polygonEditor.active) {
      final id = _polygonEditor.elementId!, points = _polygonEditor.preview!;
      final original = _polygonEditor.original!;
      final valid = !_polygonEditor.invalid;
      final editedEdge =
          _polygonEditor.edge && _polygonEditor.editedPoint != null
          ? ArchitectPolygonDimensions.hitEdge(
              points,
              _polygonEditor.editedPoint!,
              .001,
            )
          : null;
      final changed =
          points.length != original.length ||
          List.generate(
            points.length,
            (i) => i < original.length && points[i] == original[i],
          ).any((same) => !same);
      _cancelActiveDrags();
      if (valid && changed) {
        _commands.execute(
          UpdateArchitectPolygon(
            storeyId: _project.activeStoreyId,
            elementId: id,
            polygon: points,
          ),
        );
        _saveBiMProjectIfAttached();
        if (_polygonEditId == id) _polygonSelectedEdge = editedEdge;
      } else if (!valid) {
        _operationError();
      }
      return;
    }
    if (_groupDragIds.isNotEmpty) {
      final ids = Set<String>.of(_groupDragIds);
      final delta = _elementMoveDelta;
      _cancelActiveDrags();
      if (delta != null && delta.distance > 1e-9) {
        _commands.execute(
          MoveArchitectElements(
            storeyId: _project.activeStoreyId,
            elementIds: ids,
            delta: delta,
          ),
        );
        _saveBiMProjectIfAttached();
      }
      return;
    }
    final l10n = context.l10n;
    final isBg = Localizations.localeOf(context).languageCode == 'bg';

    if (_wallEndpointOriginal != null ||
        (_draggingElementId != null && _selectedWall != null)) {
      final preview = _elementMovePreview;
      _cancelActiveDrags();
      if (preview != null) {
        _commands.commit(preview);
        _saveBiMProjectIfAttached();
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
    if (_pendingShape != null || _polygonDistanceOpen) return;
    if (_polygonEditId != null) {
      _selectPolygonEdge(rawModel);
      return;
    }
    if (_wallCutIds.isNotEmpty) {
      if (!_wallCutStroke) {
        final span = _trimSpanAt(rawModel);
        if (span == null) return;
        final before = _project;
        _executeWallEdit(
          TrimArchitectWall(
            storeyId: _project.activeStoreyId,
            wallId: span.wall.id,
            pick: rawModel,
          ),
        );
        if (!identical(before, _project)) setState(() => _wallCutIds = {});
        return;
      }
      if (_wallCutStart == null) {
        setState(() => _wallCutStart = rawModel);
      } else {
        _executeWallEdit(
          CutArchitectWalls(
            storeyId: _project.activeStoreyId,
            wallIds: Set.of(_wallCutIds),
            start: _wallCutStart!,
            end: rawModel,
          ),
        );
        setState(() {
          _wallCutStart = null;
          _wallCutIds = {};
        });
      }
      return;
    }
    if (_wallExtendId != null) {
      final wall = _project.activeStorey.walls.firstWhere(
        (w) => w.id == _wallExtendId,
      );
      final hit =
          _hitSelection(rawModel) ??
          _axisTool
              .hitTestAxis(
                rawModel,
                _project.gridAxes,
                tolerance: 14 / _currentScale,
              )
              ?.id;
      Offset? target;
      for (final w in _project.activeStorey.walls.where(
        (w) => w.id == hit && w.id != wall.id,
      )) {
        target = ArchitectWallNetwork.intersection(
          wall.startPoint,
          wall.endPoint,
          w.startPoint,
          w.endPoint,
        );
      }
      for (final a in _project.gridAxes.where((a) => a.id == hit)) {
        target = ArchitectWallNetwork.intersection(
          wall.startPoint,
          wall.endPoint,
          a.start,
          a.end,
        );
      }
      if (hit != null && hit != wall.id && target == null) {
        _operationError();
        return;
      }
      _executeWallEdit(
        ExtendArchitectWall(
          storeyId: _project.activeStoreyId,
          wallId: wall.id,
          target: target ?? rawModel,
        ),
      );
      setState(() => _wallExtendId = null);
      return;
    }
    if (_activeTool != ArchitectTool.select && _multiSelect) {
      _selectAt(rawModel);
      return;
    }

    if (_wallInsertPointId != null && _activeTool == ArchitectTool.wall) {
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
      final isBg = Localizations.localeOf(context).languageCode == 'bg';
      // If axis drafting is in progress, commit it
      if (_axisTool.isDrafting) {
        _axisTool.updateDrafting(
          rawModel,
          _project,
          _currentScale,
          magnetic: _magnetEnabled,
          snapper: (anchor) => _snapElement(rawModel, anchor: anchor),
        );
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

      final wall = _wallForAxis(rawModel);
      if (wall != null) {
        final result = _axisTool.placeOnWall(
          project: _project,
          wall: wall,
          isBulgarian: isBg,
        );
        if (result != null) {
          setState(() => _project = result.$1);
          _saveBiMProjectIfAttached();
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
      final snap = _snapElement(rawModel);
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
          magnetic: _magnetEnabled,
          underlay: _currentUnderlayDoc,
          frame: widget.underlayFrame,
          visibility: _underlayLayerVisibility,
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
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility,
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

    // Navigation never captures an element; selection belongs to its tool.
    if (_activeTool == ArchitectTool.select) return;
    if (_effectiveSelection.isNotEmpty) {
      _selectAt(rawModel);
      return;
    }

    // 4. In Wall tool
    if (_activeTool == ArchitectTool.wall) {
      if (_wallDirectionLocked) return;
      if (_draftStart == null) {
        final snap = _snapWall(rawModel);
        _adoptWallReference(snap.wallAttachment);
        _wallStartAttachment = snap.wallAttachment;
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
          _activeSnapLabel = snap.snapLabel;
        });
        HapticFeedback.lightImpact();
      } else {
        final snap = _snapWall(rawModel, anchor: _draftStart);
        _orientWallReference(snap.point);
        if ((snap.point - _draftStart!).distance >= .001 &&
            _wallPrecisionMode) {
          setState(() {
            _draftEnd = snap.point;
            _activeSnapLabel = snap.snapLabel;
            _wallDirectionLocked = true;
            _wallPanelAnchor = (_draftStart! + snap.point) / 2;
          });
        } else if ((snap.point - _draftStart!).distance >= .001) {
          _commitCurrentWallSegment(snap.point);
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
      final snap = _snapElement(rawModel);
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
        final snap = _snapElement(rawModel);
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
        });
      } else {
        final snap = _snapElement(rawModel, anchor: _draftStart);
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
          final point = _snapElement(rawModel).point;
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
          final point = _snapElement(rawModel).point;
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
        final snap = _snapElement(rawModel);
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
        });
      } else {
        final snap = _snapElement(rawModel);
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
        point: _snapElement(rawModel).point,
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
      _promptAddAnnotation(_snapElement(rawModel).point);
      return;
    }

    // 15. CAD shape dimensions freeze after the second point.
    if (_activeTool == ArchitectTool.cadLine ||
        _activeTool == ArchitectTool.cadRect ||
        _activeTool == ArchitectTool.cadCircle) {
      if (_draftStart == null) {
        final point = _snapElement(rawModel).point;
        setState(() {
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final snap = _snapElement(rawModel, anchor: _draftStart);
        _draftEnd = snap.point;
        final type = _activeTool == ArchitectTool.cadLine
            ? CadPrimitiveType.line
            : _activeTool == ArchitectTool.cadRect
            ? CadPrimitiveType.rect
            : CadPrimitiveType.circle;
        final attached =
            snap.isSnapped &&
            snap.snapLabel != 'Alignment' &&
            !(snap.snapLabel?.endsWith('°') ?? false);
        if (type == CadPrimitiveType.circle ||
            (type == CadPrimitiveType.rect && !attached)) {
          setState(() {
            _pendingShape = type;
            _shapePanelAnchor = snap.point;
          });
        } else {
          _commitCadShape(type);
        }
      }
      return;
    }

    // 16. In Measure tool
    if (_activeTool == ArchitectTool.measure) {
      if (_draftStart == null) {
        setState(() {
          final point = _snapElement(rawModel).point;
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

    _orientWallReference(p2);
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
      exteriorSide: _wallExteriorSide,
      insulationThicknessOverride: _activeWallType?.insulationThickness,
    );

    setState(() {
      _commands.execute(
        CreateArchitectWall(storeyId: _project.activeStorey.id, wall: newWall),
      );
      _wallDirectionLocked = false;
      if (continueChain == true) _wallMode = WallDraftingMode.chained;
      if (continueChain ?? (_wallMode == WallDraftingMode.chained)) {
        _draftStart = p2;
        _draftEnd = p2;
        _wallStartAttachment = ArchitectWallAttachment(newWall, _wallReference);
      } else {
        _draftStart = null;
        _draftEnd = null;
        _wallStartAttachment = null;
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

  void _adoptWallReference(ArchitectWallAttachment? attachment) {
    if (attachment == null) return;
    if (_wallReference != attachment.reference) {
      setState(() => _wallReference = attachment.reference);
    }
  }

  void _orientWallReference(Offset end) {
    if (_wallStartAttachment == null || _draftStart == null) return;
    final side = _wallStartAttachment!.sideFor(
      _draftStart!,
      end,
      _wallThickness,
      _activeWallType?.insulationThickness ?? 0,
    );
    if (_wallExteriorSide != side) setState(() => _wallExteriorSide = side);
  }

  ArchitectWallTrimSpan? _trimSpanAt(
    Offset point, {
    bool restrictSelection = true,
  }) {
    ArchitectWall? picked;
    var best = double.infinity;
    for (final wall in _project.activeStorey.walls) {
      if (restrictSelection && !_wallCutIds.contains(wall.id)) continue;
      final (ratio, distance) = wall.projectPoint(point);
      final d = point - wall.centerStart;
      final along = d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
      if (along < -12 / _currentScale ||
          along > wall.length + 12 / _currentScale) {
        continue;
      }
      if (ratio >= 0 &&
          distance <= wall.thickness / 2 + 12 / _currentScale &&
          distance < best) {
        picked = wall;
        best = distance;
      }
    }
    return picked == null
        ? null
        : ArchitectWallTrimSpan.at(picked, _project.activeStorey.walls, point);
  }

  List<ArchitectWallClearance> get _wallClearances {
    final ids = _effectiveSelection;
    if (_activeTool != ArchitectTool.wall ||
        ids.length != 1 ||
        _wallCutIds.isNotEmpty) {
      return [];
    }
    final walls = (_elementMovePreview ?? _project).activeStorey.walls;
    final selected = walls.where((w) => ids.contains(w.id));
    return selected.isEmpty
        ? []
        : ArchitectWallClearance.nearest(selected.first, walls);
  }

  Widget _buildWallClearanceOverlay() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (context, child) {
        final clearances = _wallClearances;
        if (clearances.isEmpty) return const SizedBox.shrink();
        final walls = (_elementMovePreview ?? _project).activeStorey.walls;
        final body = ArchitectWallNetwork.body(walls);
        return Stack(
          children: [
            for (final gap in clearances)
              Builder(
                builder: (context) {
                  final wall = walls.firstWhere((w) => w.id == gap.wallId);
                  final position = ArchitectDimensionLayout.clearTextPosition(
                    gap.midpoint,
                    const Size(88, 36),
                    _currentScale,
                    wall.unitVector,
                    body,
                  );
                  final screen = _viewport.toScreen(position);
                  if (screen.dx < 44 ||
                      screen.dx > _viewport.size.width - 44 ||
                      screen.dy < 18 ||
                      screen.dy > _viewport.size.height - 18) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: screen.dx - 44,
                    top: screen.dy - 18,
                    width: 88,
                    height: 36,
                    child: Tooltip(
                      message: context.l10n.architectWallClearance,
                      child: Material(
                        color: const Color(0xEE1E242C),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          key: ValueKey('wall-clearance-${gap.neighborId}'),
                          onTap: () {
                            setState(() => _radialMenuScreenPosition = null);
                            _editWallClearance(gap);
                          },
                          child: Center(
                            child: Text(
                              _project.units.format(gap.distance, decimals: 3),
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    ),
  );

  List<Offset>? get _editablePolygon {
    if (_polygonEditId == null ||
        _polygonEditId != (_selectedElementId ?? _selectedZoneId)) {
      return null;
    }
    final storey = (_elementMovePreview ?? _project).activeStorey;
    for (final slab in storey.slabs) {
      if (slab.id == _polygonEditId) return slab.polygon;
    }
    for (final primitive in storey.cadPrimitives) {
      if (primitive.id == _polygonEditId &&
          primitive.type == CadPrimitiveType.rect) {
        return primitive.polygonCorners;
      }
    }
    for (final zone in storey.zones) {
      if (zone.id == _polygonEditId) return zone.polygon;
    }
    return null;
  }

  void _selectPolygonEdge(Offset point) {
    if (_polygonDistanceOpen) return;
    final polygon = _editablePolygon;
    if (polygon == null) return;
    var edge = ArchitectPolygonDimensions.hitEdge(
      polygon,
      point,
      18 / _currentScale,
    );
    if (edge == null) {
      var best = 18 / _currentScale;
      for (var i = 0; i < polygon.length; i++) {
        final handle = ArchitectPolygonEditor.offsetEdgeHandle(
          polygon,
          i,
          _currentScale,
        );
        final distance = (point - handle).distance;
        if (distance <= best) {
          edge = i;
          best = distance;
        }
      }
    }
    if (edge != null) {
      setState(() => _polygonSelectedEdge = edge);
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildPolygonDistanceOverlay() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (context, child) {
        final polygon = _editablePolygon;
        if (polygon == null || _radialMenuScreenPosition != null) {
          return const SizedBox.shrink();
        }
        final edge = _polygonSelectedEdge;
        final selected = edge != null && edge < polygon.length;
        return Stack(
          children: [
            if (selected && !_polygonEditor.active)
              Positioned.fill(
                child: ArchitectPolygonDistanceOverlay(
                  polygon: polygon,
                  edge: edge,
                  dimensions: ArchitectPolygonDimensions.nearest(
                    elementId: _polygonEditId!,
                    polygon: polygon,
                    edge: edge,
                    storey: (_elementMovePreview ?? _project).activeStorey,
                  ),
                  unit: _project.units,
                  scale: _currentScale,
                  toScreen: _viewport.toScreen,
                  obstacles: ArchitectWallNetwork.body(
                    (_elementMovePreview ?? _project).activeStorey.walls,
                  ),
                  onEdit: (dimension) => _editPolygonDistance(dimension),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: const Color(0xEE1E242C),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in ArchitectPolygonEdgeMode.values)
                      IconButton(
                        key: ValueKey('polygon-edge-${mode.name}'),
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: mode == ArchitectPolygonEdgeMode.move
                            ? context.l10n.architectEdgeMoveHint
                            : context.l10n.architectEdgePullHint,
                        icon: Icon(
                          mode == ArchitectPolygonEdgeMode.move
                              ? Icons.open_with
                              : Icons.unfold_more,
                          size: 20,
                          color: _polygonEdgeMode == mode
                              ? Colors.cyanAccent
                              : Colors.white54,
                        ),
                        onPressed: _polygonDistanceOpen || _polygonEditor.active
                            ? null
                            : () => setState(() => _polygonEdgeMode = mode),
                      ),
                    if (!selected)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(context.l10n.architectEdgeSelectHint),
                      )
                    else
                      TextButton.icon(
                        key: const ValueKey('polygon-edge-offset'),
                        onPressed: _polygonDistanceOpen
                            ? null
                            : () => _editPolygonDistance(null),
                        icon: const Icon(Icons.swap_vert, size: 18),
                        label: Text(context.l10n.architectZoneOffset),
                      ),
                    IconButton(
                      key: const ValueKey('polygon-edit-close'),
                      tooltip: context.l10n.close,
                      onPressed: _polygonDistanceOpen
                          ? null
                          : () => setState(() {
                              _polygonEditId = null;
                              _polygonSelectedEdge = null;
                            }),
                      icon: const Icon(Icons.check, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _editPolygonDistance(ArchitectPolygonDistance? dimension) async {
    if (_polygonDistanceOpen) return;
    final polygon = _editablePolygon, edge = _polygonSelectedEdge;
    final id = _polygonEditId;
    if (polygon == null || edge == null || id == null) return;
    final original = List<Offset>.of(polygon);
    final mode = _polygonEdgeMode;
    final project = _project;
    final unit = project.units;
    List<Offset>? candidate = original;
    var displacement = 0.0;
    final normal = ArchitectPolygonGeometry.normal(original, edge);
    final midpoint =
        (original[edge] + original[(edge + 1) % original.length]) / 2;
    setState(() => _polygonDistanceOpen = true);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, dialogSetState) => Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 260),
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: 250,
              child: ArchitectShapeDimensionPanel(
                values: [unit.toUnit(dimension?.distance ?? 0)],
                labels: [
                  dimension == null
                      ? context.l10n.architectZoneOffset
                      : context.l10n.architectEdgeDistance,
                ],
                unit: unit.symbol,
                minimum: dimension == null
                    ? -double.infinity
                    : unit.toUnit(.001),
                signed: dimension == null,
                canSave: candidate != null && identical(project, _project),
                onChanged: (_, value) {
                  final meters = unit.fromUnit(value);
                  displacement = dimension == null
                      ? meters
                      : dimension.side * (dimension.distance - meters);
                  candidate = dimension == null
                      ? ArchitectPolygonGeometry.offsetEdge(
                          original,
                          edge,
                          meters,
                          mode: mode,
                        )
                      : dimension.setDistance(original, meters, mode: mode);
                  dialogSetState(() {});
                  if (candidate != null) {
                    _elementMovePreview = UpdateArchitectPolygon(
                      storeyId: project.activeStoreyId,
                      elementId: id,
                      polygon: candidate!,
                    ).apply(project);
                    _polygonSelectedEdge = ArchitectPolygonDimensions.hitEdge(
                      candidate!,
                      midpoint + normal * displacement,
                      .001,
                    );
                  }
                  _repaintPreview();
                },
                onSave: () {
                  if (candidate == null || !identical(project, _project)) {
                    return;
                  }
                  _elementMovePreview = null;
                  if (displacement.abs() > ArchitectPolygonGeometry.epsilon) {
                    _commands.execute(
                      UpdateArchitectPolygon(
                        storeyId: project.activeStoreyId,
                        elementId: id,
                        polygon: candidate!,
                      ),
                    );
                    _saveBiMProjectIfAttached();
                  }
                  _polygonSelectedEdge = ArchitectPolygonDimensions.hitEdge(
                    candidate!,
                    midpoint + normal * displacement,
                    .001,
                  );
                  Navigator.of(dialogContext).pop();
                },
                onCancel: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ),
      ).then((_) {
        // Restore edge selection from the committed model (Cancel leaves it intact).
        final current = _selectedPolygon;
        if (current != null && identical(project, _project)) {
          _polygonSelectedEdge = edge;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _elementMovePreview = null;
          _polygonDistanceOpen = false;
        });
        _repaintPreview();
      }
    }
  }

  void _editWallClearance(ArchitectWallClearance gap) {
    var distance = gap.distance;
    final storeyId = _project.activeStoreyId;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 220,
          child: ArchitectWallDraftingPanel(
            title: context.l10n.architectWallClearance,
            endLabel: context.l10n.save,
            length: _project.units.toUnit(distance),
            unit: _project.units.symbol,
            minimumLength: 0,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            onLength: (value) => distance = _project.units.fromUnit(value),
            onEnd: () {
              Navigator.of(dialogContext).pop();
              _executeWallEdit(
                SetArchitectWallClearance(
                  storeyId: storeyId,
                  wallId: gap.wallId,
                  neighborId: gap.neighborId,
                  distance: distance,
                ),
              );
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
            onUnlock: () {},
            onContinue: () {},
          ),
        ),
      ),
    );
  }

  void _chooseWallDimension() {
    if (_wallDirectionLocked) return;
    setState(() {
      _wallPrecisionMode = !_wallPrecisionMode;
    });
  }

  void _executeWallEdit(ArchitectModelCommand command) {
    try {
      _commands.execute(command);
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.architectWallEditRejected)),
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

    final activeStyle =
        _elementTool.activeDoorStyle ??
        FenestrationLibraryService.instance.activeDoorStyle;

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
      styleId: activeStyle.id,
      style: activeStyle,
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

  void _openFenestrationEditor() async {
    final kind = _activeTool == ArchitectTool.door
        ? FenestrationKind.door
        : FenestrationKind.window;
    final initialStyle = kind == FenestrationKind.door
        ? (_elementTool.activeDoorStyle ??
              FenestrationLibraryService.instance.activeDoorStyle)
        : (_elementTool.activeWindowStyle ??
              FenestrationLibraryService.instance.activeWindowStyle);

    final result = await Navigator.push<ArchitectFenestrationStyle>(
      context,
      MaterialPageRoute(
        builder: (_) => FenestrationEditorScreen(
          initialKind: kind,
          initialStyle: initialStyle,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (result.kind == FenestrationKind.window) {
          _elementTool.setWindowStyle(result);
        } else {
          _doorWidth = result.defaultWidth;
          _doorHeight = result.defaultHeight;
          _doorSill = result.defaultSillHeight;
          _elementTool.setDoorStyle(result);
        }
      });
    }
  }

  String? _hitSelection(Offset point) {
    if (_activeTool == ArchitectTool.axis) {
      return _axisTool
          .hitTestAxis(point, _project.gridAxes, tolerance: 14 / _currentScale)
          ?.id;
    }
    if (_activeTool == ArchitectTool.zone) return _findZoneAt(point)?.id;
    return _elementTool.hitTestForTool(
      _project.activeStorey,
      point,
      _currentScale,
      _activeTool,
    );
  }

  bool _onSelectionHold(Offset screenPoint) {
    if (_wallCutIds.isNotEmpty || _polygonEditId != null) return false;
    if (_isActivelyDraggingHandle) return false;
    if (_draftStart != null ||
        _wallDirectionLocked ||
        _zoneTool.isDrafting ||
        _axisTool.isDrafting ||
        _elementTool.slabDraftPoints.isNotEmpty) {
      return false;
    }
    final ok = _selectAt(_screenToModel(screenPoint));
    if (ok) {
      final id = _selectedElementId ?? _selectedZoneId;
      if (id != null) {
        setState(() {
          _radialMenuScreenPosition = screenPoint;
          _radialMenuElementId = id;
          _radialMenuItems = _buildRadialMenuItems(id);
        });
      }
    }
    return ok;
  }

  List<ArchitectRadialMenuItem> _buildRadialMenuItems(String elementId) {
    final l10n = context.l10n;
    final items = <ArchitectRadialMenuItem>[];

    final storey = _project.activeStorey;
    final isCol = storey.columns.any((c) => c.id == elementId);
    final isWall = storey.walls.any((w) => w.id == elementId);
    final isDoor = storey.walls.any(
      (w) => w.doors.any((d) => d.id == elementId),
    );
    final isWindow = storey.walls.any(
      (w) => w.windows.any((win) => win.id == elementId),
    );
    final isSlab = storey.slabs.any((s) => s.id == elementId);
    final isCadPrim = storey.cadPrimitives.any((c) => c.id == elementId);
    final isZone = storey.zones.any((z) => z.id == elementId);
    final isAxis = _project.gridAxes.any((a) => a.id == elementId);

    if (isCol) {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.rotate,
          icon: Icons.rotate_right,
          label: l10n.architectRadialRotate,
          color: const Color(0xFF40C4FF),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.duplicate,
          icon: Icons.copy_all,
          label: l10n.architectRadialDuplicate,
          color: const Color(0xFF64FFDA),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isWall) {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.edit,
          icon: Icons.edit_outlined,
          label: l10n.architectRadialEdit,
          color: const Color(0xFF00E5FF),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.split,
          icon: Icons.content_cut,
          label: l10n.architectRadialSplit,
          color: const Color(0xFFFF9100),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.flip,
          icon: Icons.flip,
          label: l10n.architectRadialFlip,
          color: const Color(0xFF40C4FF),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isDoor || isWindow) {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      if (isDoor) {
        items.add(
          ArchitectRadialMenuItem(
            action: ArchitectRadialAction.flip,
            icon: Icons.flip,
            label: l10n.architectRadialFlip,
            color: const Color(0xFF40C4FF),
          ),
        );
      }
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isSlab || isCadPrim || isZone) {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.edit,
          icon: Icons.edit_outlined,
          label: l10n.architectRadialEdit,
          color: const Color(0xFF00E5FF),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.duplicate,
          icon: Icons.copy_all,
          label: l10n.architectRadialDuplicate,
          color: const Color(0xFF64FFDA),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isAxis) {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else {
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.move,
          icon: Icons.open_with,
          label: l10n.architectRadialMove,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        ArchitectRadialMenuItem(
          action: ArchitectRadialAction.properties,
          icon: Icons.tune,
          label: l10n.architectRadialProperties,
          color: const Color(0xFFB388FF),
        ),
      );
    }

    items.add(
      ArchitectRadialMenuItem(
        action: ArchitectRadialAction.delete,
        icon: Icons.delete_outline,
        label: l10n.architectRadialDelete,
        color: const Color(0xFFFF5252),
      ),
    );

    return items;
  }

  void _handleRadialAction(ArchitectRadialAction action) {
    final id = _radialMenuElementId;
    setState(() {
      _radialMenuScreenPosition = null;
      _radialMenuElementId = null;
    });
    if (id == null) return;

    switch (action) {
      case ArchitectRadialAction.edit:
        final polygon = _selectedPolygon;
        if (polygon != null) {
          _cancelActiveDrags();
          setState(() {
            _polygonEditId = id;
            _polygonSelectedEdge = null;
            _moveSelection = false;
          });
        } else if (_selectedWall != null) {
          _wallEndpointOriginal = _selectedWall;
          _wallDragStart = false;
        }
        break;

      case ArchitectRadialAction.move:
        setState(() {
          _polygonEditId = null;
          _polygonSelectedEdge = null;
          _moveSelection = true;
        });
        break;

      case ArchitectRadialAction.duplicate:
        final (nextStorey, newId) = _elementTool.duplicateElementById(
          _project.activeStorey,
          id,
        );
        if (newId != null) {
          _commands.commit(_project.updateActiveStorey(nextStorey));
          _saveBiMProjectIfAttached();
          setState(() {
            _selectedElementId = newId;
            _selectedZoneId = null;
          });
          HapticFeedback.mediumImpact();
        }
        break;

      case ArchitectRadialAction.rotate:
        final nextStorey = _elementTool.rotateElementById(
          _project.activeStorey,
          id,
        );
        _commands.commit(_project.updateActiveStorey(nextStorey));
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
        break;

      case ArchitectRadialAction.flip:
        final nextStorey = _elementTool.flipElementById(
          _project.activeStorey,
          id,
        );
        _commands.commit(_project.updateActiveStorey(nextStorey));
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
        break;

      case ArchitectRadialAction.split:
        setState(() {
          _wallCutStroke = true;
          _wallCutIds = {id};
          _wallCutStart = null;
        });
        break;

      case ArchitectRadialAction.properties:
        _showProperties();
        break;

      case ArchitectRadialAction.delete:
        var storey = _project.activeStorey;
        storey = _elementTool.deleteElementById(storey, id);
        _commands.commit(
          _project
              .updateActiveStorey(
                storey.copyWith(
                  zones: storey.zones.where((z) => z.id != id).toList(),
                ),
              )
              .copyWithGridAxes(
                _project.gridAxes.where((a) => a.id != id).toList(),
              ),
        );
        _saveBiMProjectIfAttached();
        setState(() {
          _selectedElementId = null;
          _selectedZoneId = null;
          _selectionIds.remove(id);
        });
        HapticFeedback.heavyImpact();
        break;

      case ArchitectRadialAction.offset:
        final axis = _project.gridAxes.where((a) => a.id == id).firstOrNull;
        if (axis != null) {
          _handleAxisOffset(axis);
        }
        break;
    }
  }

  bool _selectAt(Offset point) {
    final id = _hitSelection(point);
    if (id == null) return false;
    _cancelActiveDrags();
    _polygonEditId = null;
    _polygonSelectedEdge = null;
    _zoneTool.cancelAll();
    _axisTool.cancelAll();
    setState(() {
      _interactionEpoch++;
      _draftStart = null;
      _draftEnd = null;
      _selectedElementId = null;
      _selectedZoneId = null;
      if (_multiSelect) {
        if (!_selectionIds.add(id)) _selectionIds.remove(id);
      } else {
        if (_project.activeStorey.zones.any((e) => e.id == id)) {
          _selectedZoneId = id;
          _zoneTool.startEditingZone(
            _project.activeStorey.zones.firstWhere((e) => e.id == id),
          );
        } else if (_project.gridAxes.any((e) => e.id == id)) {
          _axisTool.selectAxis(id);
        } else {
          _selectedElementId = id;
        }
      }
    });
    HapticFeedback.selectionClick();
    return true;
  }

  void _operationError() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.architectOperationRejected)),
  );

  void _showProperties() {
    final ids = _effectiveSelection;
    if (ids.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => ArchitectElementPropertiesDialog(
        project: _project,
        elementIds: ids,
        onApply: (values, texts) {
          try {
            _commands.execute(
              SetArchitectElementProperties(
                storeyId: _project.activeStoreyId,
                elementIds: ids,
                values: values,
                textValues: texts,
              ),
            );
            _saveBiMProjectIfAttached();
            return true;
          } on ArgumentError {
            _operationError();
            return false;
          }
        },
      ),
    );
  }

  Widget _buildSelectionBar() {
    final l = context.l10n;
    final ids = _effectiveSelection;
    final wallIds = _project.activeStorey.walls
        .where((w) => ids.contains(w.id))
        .map((w) => w.id)
        .toSet();
    void clear() => setState(() {
      _cancelActiveDrags();
      _selectionIds.clear();
      _selectedElementId = null;
      _selectedZoneId = null;
      _axisTool.deselect();
      _zoneTool.cancelEditingZone();
      _multiSelect = false;
      _moveSelection = false;
      _wallExtendId = null;
      _wallCutIds = {};
      _wallCutStart = null;
    });
    return Material(
      color: const Color(0xFF1E1E26),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ids.length == 1 && _selectedElementId != null
                      ? _selectedElementLabel
                      : '${ids.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              key: const ValueKey('architect-multi-select'),
              tooltip: l.architectSelectionMulti,
              icon: Icon(
                Icons.library_add_check_outlined,
                color: _multiSelect ? Colors.amber : Colors.white70,
              ),
              onPressed: () => setState(() {
                _radialMenuScreenPosition = null;
                _polygonEditId = null;
                _polygonSelectedEdge = null;
                if (!_multiSelect) {
                  _selectionIds
                    ..clear()
                    ..addAll(ids);
                  _multiSelect = true;
                } else {
                  _multiSelect = false;
                  _selectionIds.clear();
                }
                _moveSelection = false;
              }),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              key: const ValueKey('architect-selection-move'),
              tooltip: l.architectSelectionMove,
              icon: Icon(
                Icons.open_with,
                color: _moveSelection ? Colors.amber : Colors.white70,
              ),
              onPressed: () => setState(() {
                _radialMenuScreenPosition = null;
                _polygonEditId = null;
                _polygonSelectedEdge = null;
                _moveSelection = !_moveSelection;
              }),
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              key: const ValueKey('architect-selection-properties'),
              tooltip: l.architectProperties,
              icon: const Icon(Icons.tune, color: Colors.white70),
              onPressed: () {
                setState(() => _radialMenuScreenPosition = null);
                _showProperties();
              },
            ),
            if (wallIds.isNotEmpty)
              IconButton(
                key: const ValueKey('wall-detach'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                tooltip:
                    _project.activeStorey.walls
                        .where((w) => wallIds.contains(w.id))
                        .every((w) => w.isDetached)
                    ? l.architectWallAttach
                    : l.architectWallDetach,
                icon: Icon(
                  Icons.link_off,
                  color:
                      _project.activeStorey.walls
                          .where((w) => wallIds.contains(w.id))
                          .every((w) => w.isDetached)
                      ? Colors.amber
                      : Colors.white70,
                ),
                onPressed: () => _executeWallEdit(
                  SetArchitectWallConnection(
                    storeyId: _project.activeStoreyId,
                    wallIds: wallIds,
                    connected: _project.activeStorey.walls
                        .where((w) => wallIds.contains(w.id))
                        .every((w) => w.isDetached),
                  ),
                ),
              ),
            if (wallIds.isNotEmpty)
              PopupMenuButton<String>(
                key: const ValueKey('architect-wall-actions'),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                onSelected: (action) {
                  if (action == 'cut' || action == 'splitStroke') {
                    setState(() {
                      _wallCutStroke = action == 'splitStroke';
                      _wallCutIds = Set.of(wallIds);
                      _wallCutStart = null;
                      _wallExtendId = null;
                      _wallInsertPointId = null;
                    });
                  } else if (action == 'mirror') {
                    _executeWallEdit(
                      MirrorArchitectWalls(
                        storeyId: _project.activeStoreyId,
                        wallIds: wallIds,
                      ),
                    );
                  } else if (action == 'magnet') {
                    setState(() {
                      _magnetEnabled = !_magnetEnabled;
                      _activeMagneticGuides = [];
                    });
                  } else if (action == 'join') {
                    try {
                      _commands.execute(
                        JoinArchitectWalls(
                          storeyId: _project.activeStoreyId,
                          wallIds: wallIds,
                        ),
                      );
                      _saveBiMProjectIfAttached();
                    } on ArgumentError {
                      _operationError();
                    }
                  } else if (action == 'extend') {
                    setState(() => _wallExtendId = wallIds.single);
                  } else if (action == 'length') {
                    _editWallLength();
                  } else if (action == 'point') {
                    setState(() => _wallInsertPointId = wallIds.single);
                  } else if (action == 'parallel') {
                    setState(() => _wallParallelMove = !_wallParallelMove);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const ValueKey('wall-cut'),
                    value: 'cut',
                    child: Row(
                      children: [
                        const Icon(Icons.content_cut, size: 18),
                        const SizedBox(width: 8),
                        Text(l.architectWallCut),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('wall-split-stroke'),
                    value: 'splitStroke',
                    child: Text(l.architectWallSplit),
                  ),
                  PopupMenuItem(
                    key: const ValueKey('wall-mirror'),
                    value: 'mirror',
                    child: Text(l.architectWallMirror),
                  ),
                  CheckedPopupMenuItem(
                    value: 'magnet',
                    checked: _magnetEnabled,
                    child: Text(l.architectWallMagnet),
                  ),
                  if (wallIds.length == 1 && !_multiSelect) ...[
                    PopupMenuItem(
                      value: 'length',
                      child: Text(l.architectWallLength),
                    ),
                    PopupMenuItem(
                      value: 'point',
                      child: Text(l.architectWallInsertPoint),
                    ),
                    PopupMenuItem(
                      value: 'parallel',
                      child: Text(l.architectWallParallel),
                    ),
                    PopupMenuItem(
                      key: const ValueKey('wall-extend'),
                      value: 'extend',
                      child: Text(l.architectWallExtend),
                    ),
                  ],
                  if (wallIds.length >= 2)
                    PopupMenuItem(
                      key: const ValueKey('wall-join'),
                      value: 'join',
                      child: Text(l.architectWallJoin),
                    ),
                ],
              ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                var storey = _project.activeStorey;
                for (final id in ids) {
                  storey = _elementTool.deleteElementById(storey, id);
                }
                _commands.commit(
                  _project
                      .updateActiveStorey(
                        storey.copyWith(
                          zones: storey.zones
                              .where((z) => !ids.contains(z.id))
                              .toList(),
                        ),
                      )
                      .copyWithGridAxes(
                        _project.gridAxes
                            .where((a) => !ids.contains(a.id))
                            .toList(),
                      ),
                );
                _saveBiMProjectIfAttached();
                clear();
              },
            ),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              key: const ValueKey('architect-clear-selection'),
              tooltip: l.close,
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: clear,
            ),
          ],
        ),
      ),
    );
  }

  bool _tryStartElementDrag(Offset point) {
    final storey = _project.activeStorey;
    final id = _hitSelection(point);
    if (id == null || !_effectiveSelection.contains(id)) return false;
    final movable = [
      ...storey.walls.map((e) => e.id),
      ...storey.walls.expand(
        (w) => [...w.doors.map((d) => d.id), ...w.windows.map((e) => e.id)],
      ),
      ...storey.columns.map((e) => e.id),
      ...storey.beams.map((e) => e.id),
      ...storey.slabs.map((e) => e.id),
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

  Future<void> _promptAddAnnotation(Offset point) async {
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: context.l10n.architectToolText,
    );
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
                tooltip: l10n.architectZoneUndoAction,
                onPressed: _commands.canUndo ? _undoModel : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const ValueKey('architect-redo'),
                tooltip: l10n.architectZoneRedoAction,
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
                    _pendingShape = null;
                    _shapePanelAnchor = null;
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
                  onCreateFenestration: _openFenestrationEditor,
                  activeWindowStyle:
                      _elementTool.activeWindowStyle ??
                      FenestrationLibraryService.instance.activeWindowStyle,
                  activeDoorStyle:
                      _elementTool.activeDoorStyle ??
                      FenestrationLibraryService.instance.activeDoorStyle,
                  onWindowStyleSelected: (style) {
                    setState(() {
                      _elementTool.setWindowStyle(style);
                    });
                  },
                  onDoorStyleSelected: (style) {
                    setState(() {
                      _doorWidth = style.defaultWidth;
                      _doorHeight = style.defaultHeight;
                      _doorSill = style.defaultSillHeight;
                      _elementTool.setDoorStyle(style);
                    });
                  },
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
                    if (_activeTool == ArchitectTool.zone &&
                        _zoneTool.isDrafting &&
                        !_is3DView)
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
              if (!_multiSelect && _selectedZone != null && !_is3DView)
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
              if (!_multiSelect &&
                  _axisTool.selectedAxisId != null &&
                  !_is3DView)
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

              if ((_effectiveSelection.isNotEmpty || _multiSelect) &&
                  !_is3DView)
                _buildSelectionBar(),
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
        singlePointerPan: true,
        holdToEdit:
            _effectiveSelection.isNotEmpty &&
            (!_multiSelect || _moveSelection) &&
            _wallCutIds.isEmpty &&
            _wallExtendId == null &&
            _wallInsertPointId == null,
        touchHoldToPlace: _canPlaceWithMarker,
        onToolHoldStart: _beginPlacementHold,
        onSelectionHold: _onSelectionHold,
        onEditTap: _polygonEditId == null
            ? null
            : (position) => _selectPolygonEdge(_screenToModel(position)),
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
            if (_canPlaceWithMarker)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_viewport, _previewRevision]),
                    builder: (context, _) {
                      final touch = _touchPosition;
                      final target = _placementPreviewTarget;
                      if (touch == null ||
                          target == null ||
                          !_placingWithHold ||
                          _wallDirectionLocked) {
                        return const SizedBox.shrink();
                      }
                      final tip = _viewport.toScreen(target);
                      final label = _activeSnapLabel;
                      final type = label == null
                          ? null
                          : switch (label) {
                              'Endpoint' || 'Vertex' => DxfSnapType.endpoint,
                              'Intersection' ||
                              'Axis intersection' => DxfSnapType.intersection,
                              'Midpoint' => DxfSnapType.midpoint,
                              'Center' => DxfSnapType.center,
                              'Perpendicular' => DxfSnapType.perpendicular,
                              _ when label.endsWith('°') =>
                                DxfSnapType.perpendicular,
                              _ => DxfSnapType.nearest,
                            };
                      return CustomPaint(
                        key: ValueKey(
                          _activeTool == ArchitectTool.wall
                              ? 'wall-offset-pointer'
                              : 'architect-offset-pointer',
                        ),
                        painter: StructuralPointerPainter(
                          touchPos: touch,
                          targetPos:
                              StructuralPointerInteraction.placementTarget(
                                touch,
                                isMouse: false,
                              ),
                          placementPos: tip,
                          snappedPos: type == null ? null : tip,
                          snapType: type,
                          activeTool: StructuralDrawTool.beam,
                        ),
                      );
                    },
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
              right: 12,
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
                        _wallCutIds.isNotEmpty
                            ? (_wallCutStroke
                                  ? context.l10n.architectWallSplitHint
                                  : context.l10n.architectWallCutHint)
                            : _wallExtendId != null
                            ? context.l10n.architectWallExtendHint
                            : _effectiveSelection.isNotEmpty
                            ? context.l10n.architectEditHoldHint
                            : _canPlaceWithMarker &&
                                  !_placingWithHold &&
                                  !_wallDirectionLocked
                            ? context.l10n.architectWallDraftHint
                            : _cursorModel == null
                            ? context.l10n.architectNavigationHint
                            : 'X: ${_project.units.format((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dx, decimals: 3)}  '
                                  'Y: ${_project.units.format((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dy, decimals: 3)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_radialMenuScreenPosition != null && _radialMenuItems.isNotEmpty)
        Positioned.fill(
          child: ArchitectRadialMenu(
            center: _radialMenuScreenPosition!,
            items: _radialMenuItems,
            onActionSelected: _handleRadialAction,
            onDismiss: () => setState(() => _radialMenuScreenPosition = null),
          ),
        ),
      _buildWallClearanceOverlay(),
      _buildPolygonDistanceOverlay(),
      _buildShapeDimensionOverlay(),
      if (_activeTool != ArchitectTool.wall &&
          _activeTool != ArchitectTool.select)
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            borderRadius: BorderRadius.circular(8),
            child: IconButton(
              key: const ValueKey('architect-magnet'),
              tooltip: _magnetEnabled
                  ? context.l10n.snapEnabledTooltip
                  : context.l10n.snapDisabledTooltip,
              icon: Icon(
                Icons.sensors,
                size: 20,
                color: _magnetEnabled ? Colors.cyanAccent : Colors.white54,
              ),
              onPressed: () => setState(() {
                _magnetEnabled = !_magnetEnabled;
                _activeSnapLabel = null;
                _activeMagneticGuides = [];
              }),
            ),
          ),
        ),
      if (_activeTool == ArchitectTool.wall && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 380,
              child: Material(
                color: const Color(0xEE1E242C),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: DropdownButton<WallReferenceLine>(
                          isExpanded: true,
                          value: _wallReference,
                          dropdownColor: const Color(0xFF1E242C),
                          underline: const SizedBox.shrink(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white, fontSize: 12),
                          items: [
                            for (final reference in [
                              WallReferenceLine.center,
                              WallReferenceLine.inner,
                              WallReferenceLine.outer,
                            ])
                              DropdownMenuItem(
                                value: reference,
                                child: Text(
                                  switch (reference) {
                                    WallReferenceLine.center =>
                                      context.l10n.architectWallReferenceCenter,
                                    WallReferenceLine.inner =>
                                      context.l10n.architectWallReferenceInner,
                                    WallReferenceLine.outer =>
                                      context.l10n.architectWallReferenceOuter,
                                    _ =>
                                      context.l10n.architectWallReferenceCenter,
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _wallReference = value;
                                _wallStartAttachment = null;
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 40,
                        ),
                        padding: EdgeInsets.zero,
                        key: const ValueKey('wall-flip-side'),
                        tooltip: context.l10n.architectWallFlipSide,
                        icon: const Icon(Icons.flip, size: 20),
                        onPressed: () => setState(() {
                          _wallStartAttachment = null;
                          _wallExteriorSide =
                              _wallExteriorSide == WallExteriorSide.left
                              ? WallExteriorSide.right
                              : WallExteriorSide.left;
                        }),
                      ),
                      IconButton(
                        key: const ValueKey('wall-magnet'),
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 40,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.architectWallMagnet,
                        icon: Icon(
                          Icons.sensors,
                          size: 18,
                          color: _magnetEnabled
                              ? Colors.cyanAccent
                              : Colors.white54,
                        ),
                        onPressed: () => setState(() {
                          _magnetEnabled = !_magnetEnabled;
                          _activeMagneticGuides = [];
                        }),
                      ),
                      TextButton(
                        key: const ValueKey('wall-dimension-mode'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 40),
                          textStyle: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(fontSize: 12),
                          foregroundColor: _wallPrecisionMode
                              ? Colors.cyanAccent
                              : Colors.white70,
                        ),
                        onPressed: _wallDirectionLocked
                            ? null
                            : _chooseWallDimension,
                        child: Tooltip(
                          message: context.l10n.architectWallLength,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.cyanAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.straighten, size: 18),
                              if (MediaQuery.sizeOf(context).width >= 400) ...[
                                const SizedBox(width: 8),
                                Text(context.l10n.architectWallLength),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('wall-chain-toggle'),
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 40,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.architectWallChained,
                        onPressed: () => setState(
                          () =>
                              _wallMode = _wallMode == WallDraftingMode.chained
                              ? WallDraftingMode.singleLine
                              : WallDraftingMode.chained,
                        ),
                        icon: Icon(
                          Icons.linear_scale_rounded,
                          size: 20,
                          color: _wallMode == WallDraftingMode.chained
                              ? Colors.cyanAccent
                              : Colors.white54,
                        ),
                      ),
                      if (_draftStart != null)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 40,
                          ),
                          padding: EdgeInsets.zero,
                          key: const ValueKey('wall-stop-drawing'),
                          tooltip: context.l10n.architectFinishChained,
                          onPressed: _finishChainedWall,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
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

  void _cancelCadShape() => setState(() {
    _pendingShape = null;
    _shapePanelAnchor = null;
    _draftStart = null;
    _draftEnd = null;
    _activeMagneticGuides = [];
    _activeSnapLabel = null;
  });

  void _commitCadShape(CadPrimitiveType type) {
    final result = _elementTool.placeCadPrimitive(
      storey: _project.activeStorey,
      type: type,
      start: _draftStart!,
      end: _draftEnd!,
    );
    if (result == null) {
      _operationError();
      return;
    }
    try {
      _commands.execute(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: result.$2,
        ),
      );
      _cancelCadShape();
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
    } on ArgumentError {
      _operationError();
    }
  }

  Widget _buildShapeDimensionOverlay() => Positioned.fill(
    child: ValueListenableBuilder<int>(
      valueListenable: _previewRevision,
      builder: (_, revision, child) {
        if (_pendingShape == null || _draftStart == null || _draftEnd == null) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final position = _viewport.toScreen(
              _shapePanelAnchor ?? _draftEnd!,
            );
            final width = math.min(260.0, constraints.maxWidth - 16);
            final left = (position.dx + 16).clamp(
              8.0,
              math.max(8.0, constraints.maxWidth - width - 8),
            );
            final top = (position.dy + 24).clamp(
              8.0,
              math.max(8.0, constraints.maxHeight - 265),
            );
            final delta = _draftEnd! - _draftStart!;
            final circle = _pendingShape == CadPrimitiveType.circle;
            final values = circle
                ? [delta.distance]
                : [delta.dx.abs(), delta.dy.abs()];
            return Stack(
              children: [
                Positioned(
                  left: left.toDouble(),
                  top: top.toDouble(),
                  width: width,
                  child: ArchitectShapeDimensionPanel(
                    key: ValueKey((_draftStart, _pendingShape)),
                    values: [for (final v in values) _project.units.toUnit(v)],
                    labels: circle
                        ? [context.l10n.architectRadius]
                        : [
                            context.l10n.architectShapeWidth,
                            context.l10n.architectShapeHeight,
                          ],
                    unit: _project.units.symbol,
                    minimum: _project.units.toUnit(.001),
                    onChanged: (index, value) {
                      final meters = _project.units.fromUnit(value);
                      final current = _draftEnd! - _draftStart!;
                      if (circle) {
                        final u = current.distance > .000001
                            ? current / current.distance
                            : const Offset(1, 0);
                        _draftEnd = _draftStart! + u * meters;
                      } else {
                        _draftEnd =
                            _draftStart! +
                            Offset(
                              index == 0
                                  ? (current.dx < 0 ? -meters : meters)
                                  : current.dx,
                              index == 1
                                  ? (current.dy < 0 ? -meters : meters)
                                  : current.dy,
                            );
                      }
                      _activeMagneticGuides = [];
                      _activeSnapLabel = null;
                      _repaintPreview();
                    },
                    onSave: () => _commitCadShape(_pendingShape!),
                    onCancel: _cancelCadShape,
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );

  String? _localizedSnapLabel(String? label) {
    final l10n = context.l10n;
    return switch (label) {
      'Endpoint' || 'Axis endpoint' => l10n.snapEndpoint,
      'Vertex' => l10n.snapPoint,
      'Midpoint' => l10n.snapMidpoint,
      'Center' => l10n.snapCenter,
      'Intersection' || 'Axis intersection' => l10n.snapIntersection,
      'Edge' => l10n.snapNearest,
      'Perpendicular' => l10n.snapPerpendicular,
      'Alignment' => l10n.architectWallAlign,
      final String value when value.startsWith('Axis ') =>
        '${l10n.architectToolAxis} ${value.substring(5)}',
      _ => label,
    };
  }

  ArchitectWall? _wallForAxis(Offset point) {
    ArchitectWall? picked;
    var best = double.infinity;
    for (final wall in _project.activeStorey.walls) {
      if (!wall.containsPoint(point)) continue;
      final d = point - wall.coreCenterStart;
      final distance =
          (d.dx * wall.normalVector.dx + d.dy * wall.normalVector.dy).abs();
      if (distance < best) {
        best = distance;
        picked = wall;
      }
    }
    return picked;
  }

  ArchitectProject get _drawingProject {
    final project = _elementMovePreview ?? _project;
    return _axisTool.isDraggingHandle || _axisTool.isMovingAxis
        ? project.copyWithGridAxes(_axisTool.previewAxes(project.gridAxes))
        : project;
  }

  Architect2dPainter _makePainter(ArchitectPaintLayer layer) =>
      Architect2dPainter(
        project: _drawingProject,
        viewport: _viewport,
        layer: layer,
        activeTool: _effectiveSelection.isEmpty
            ? _activeTool
            : ArchitectTool.select,
        cursorPosition: _cursorModel,
        columnPreview:
            _activeTool == ArchitectTool.column &&
                _effectiveSelection.isEmpty &&
                _columnPreviewPoint != null
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
        activeWallExteriorSide: _wallExteriorSide,
        showWallCursor: !_placingWithHold,
        wallClearances: _wallClearances,
        wallTrimSpan:
            _wallCutIds.isNotEmpty && !_wallCutStroke && _cursorModel != null
            ? _trimSpanAt(_cursorModel!)
            : null,
        wallCutLine:
            _wallCutStroke && _wallCutStart != null && _cursorModel != null
            ? (_wallCutStart!, _cursorModel!)
            : null,
        activeWallInsulation: _activeWallType?.insulationThickness,
        activeWallTypeId: _activeWallType?.id,
        activeSnapLabel: _localizedSnapLabel(_activeSnapLabel),
        selectedElementId: _multiSelect ? null : _selectedElementId,
        selectedElementIds: _multiSelect ? _selectionIds : const {},
        selectedZoneId: _selectedZoneId,
        activeZoneCategory: _activeZoneCategory,
        draggingVertexIndex: _draggingVertexIndex,
        draggingVertexPoint: _draggingVertexPoint,
        mergeCandidateIndex: _mergeCandidateIndex,
        selectedAxisId: _axisTool.selectedAxisId,
        draggedAxisSnapshot: _axisTool.draggedAxisSnapshot,
        isDraggingAxisHandle: false,
        isMovingAxis: false,
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
        polygonEditInvalid: _polygonEditor.invalid,
        polygonLeaderLine: _polygonEditor.leaderLine,
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
