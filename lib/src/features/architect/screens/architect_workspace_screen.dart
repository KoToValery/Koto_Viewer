import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../bim_projects/models/bim_work_project.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../models/architect_door.dart';
import '../models/architect_elements.dart';
import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_3d_builder.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_zone_snap.dart';
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

// === SECTION: TABLE OF CONTENTS ===
// 1. STATE & TOOL CONTROLLERS
// 2. COORDINATE TRANSFORMS (SCREEN <-> MODEL)
// 3. 2D POINTER & TOUCH HANDLING (LISTENER + ZERO ARENA CONFLICT)
// 4. ZONE EDITING & MUTATION HANDLERS
// 5. WALL & DOOR CONCEPT DRAFTING
// 6. DYNAMIC GRID AXES ACTIONS
// 7. DIAGNOSTIC LOGS DIALOG (ARCHITECT LOGGER)
// 8. 2D CANVAS VIEWPORT (INTERACTIVE VIEWER)
// 9. 3D SOLID VIEWPORT

/// The primary unified workspace for architectural concept drafting in 2D and 3D.
class ArchitectWorkspaceScreen extends StatefulWidget {
  final ArchitectProject? initialProject;
  final BimWorkProject? bimProject;
  final Map<String, DxfDocument>? underlaysByStorey;

  const ArchitectWorkspaceScreen({
    super.key,
    this.initialProject,
    this.bimProject,
    this.underlaysByStorey,
  });

  @override
  State<ArchitectWorkspaceScreen> createState() =>
      _ArchitectWorkspaceScreenState();
}

// === SECTION: STATE & TOOL CONTROLLERS ===
class _ArchitectWorkspaceScreenState extends State<ArchitectWorkspaceScreen> {
  late ArchitectProject _project;
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
    return _underlaysByStorey[_project.activeStorey.id] ??
        _underlaysByStorey.values.firstOrNull;
  }

  void _saveBiMProjectIfAttached() {
    if (widget.bimProject != null) {
      BimProjectLibraryService.instance.saveArchitectProject(
        widget.bimProject!.id,
        _project,
      );
    }
  }

  // Wall Drafting State
  double _wallThickness = 0.25; // 25 cm default
  ArchitectWallType? _activeWallType;
  WallDraftingMode _wallMode = WallDraftingMode.singleLine;
  Offset? _draftStart;
  Offset? _draftEnd;
  String? _activeSnapLabel;

  // Door State (from element_vrata.dxf)
  double _doorWidth = 0.90;
  double _doorHeight = 2.00;
  double _doorSill = 0.0;
  bool _isHingeLeft = true;
  int _doorSpecCounter = 1;

  // Selection & Zoom
  String? _selectedElementId;
  final TransformationController _transformController =
      TransformationController();
  late Cad3DCamera _camera3D;

  // Raw Pointer & Viewport Gesture Tracking (Listener-driven, Zero Arena Conflict)
  int _activePointersCount = 0;
  bool _isMultiTouchGesture = false;
  Offset? _pointerDownScreenPos;
  DateTime? _pointerDownTime;
  bool _isHandleEngaged = false;

  ArchitectZone? get _selectedZone {
    if (_selectedZoneId == null) return null;
    final zones = _project.activeStorey.zones;
    for (final z in zones) {
      if (z.id == _selectedZoneId) return z;
    }
    return null;
  }

  /// Whether an element handle (vertex, extrusion edge, axis handle/move, or whole zone move)
  /// is actively being dragged. Viewport panning is paused ONLY while dragging a handle.
  bool get _isActivelyDraggingHandle =>
      _isHandleEngaged ||
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
    _project = widget.initialProject ??
        ArchitectProject.starterWithCatalog(
          name: widget.bimProject?.name ?? 'Архитектурен проект',
          storeyCount: widget.bimProject?.storeys.length ?? 2,
        );

    if (_project.wallTypes.isNotEmpty) {
      _activeWallType = _project.wallTypes.first;
      _wallThickness = _activeWallType!.totalThickness;
    }

    _zoneTool = ArchitectZoneTool()
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _axisTool = ArchitectGridAxisTool()
      ..addListener(() {
        if (mounted) setState(() {});
      });

    _elementTool = ArchitectElementTool()
      ..addListener(() {
        if (mounted) setState(() {});
      });

    if (widget.underlaysByStorey != null) {
      _underlaysByStorey = Map.from(widget.underlaysByStorey!);
    }

    if (widget.bimProject != null && widget.initialProject == null) {
      _loadAttachedBimProject();
    }

    _camera3D = Cad3DCamera(
      yaw: math.pi / 4,
      pitch: 0.6,
      zoom: 1.0,
      mode: Cad3DInteractionMode.orbit,
    );

    // Initial camera scale for 2D canvas: 1 meter = 40 logical pixels
    _initTransform();
  }

  Future<void> _loadAttachedBimProject() async {
    final loaded = await BimProjectLibraryService.instance.loadArchitectProject(widget.bimProject!.id);
    if (loaded != null && mounted) {
      setState(() {
        _project = loaded;
      });
    }
  }

  void _initTransform() {
    final matrix = Matrix4.identity()
      ..translateByDouble(200.0, 300.0, 0.0, 1.0)
      ..scaleByDouble(40.0, 40.0, 1.0, 1.0);
    _transformController.value = matrix;
  }

  @override
  void dispose() {
    _zoneTool.dispose();
    _axisTool.dispose();
    _elementTool.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // === SECTION: COORDINATE TRANSFORMS (SCREEN <-> MODEL) ===

  Offset _screenToModel(Offset screenPos) {
    return _transformController.toScene(screenPos);
  }


  double get _currentScale =>
      _transformController.value.getMaxScaleOnAxis().clamp(0.01, 10000.0);

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
      final updatedStorey = activeStorey.copyWith(
        zones: [...activeStorey.zones, newZone],
      );

      setState(() {
        _project = _project.updateActiveStorey(updatedStorey);
        _selectedZoneId = newZone.id;
        _activeMagneticGuides = [];
        _activeSnapLabel = null;
      });
      _zoneTool.startEditingZone(newZone);

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.architectZoneCreated(newZone.name, newZone.area.toStringAsFixed(1)),
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

  // === SECTION: 2D POINTER & TOUCH HANDLING (LISTENER + ZERO ARENA CONFLICT) ===

  void _onPointerDown(PointerDownEvent event) {
    _activePointersCount++;
    ArchitectLogger.log(
      'POINTER_DOWN',
      'Pointer #${event.pointer} down at (${event.localPosition.dx.toStringAsFixed(1)}, ${event.localPosition.dy.toStringAsFixed(1)}) | Pointers count: $_activePointersCount',
    );

    // Multi-touch pinch zoom or two-finger pan detection:
    if (_activePointersCount > 1) {
      _isMultiTouchGesture = true;
      _cancelActiveDrags();
      ArchitectLogger.log(
        'GESTURE',
        'Multi-touch started ($_activePointersCount pointers). Viewport pinch-zoom prioritized.',
      );
      setState(() {});
      return;
    }

    _isMultiTouchGesture = false;
    _pointerDownScreenPos = event.localPosition;
    _pointerDownTime = DateTime.now();
    _isHandleEngaged = false;

    final rawModel = _screenToModel(event.localPosition);

    // 0. If in axis offset drag mode:
    if (_axisTool.isOffsettingWithDrag) {
      _axisTool.updateOffsetDrag(rawModel);
      _isHandleEngaged = true;
      return;
    }

    // 1. Grid Axis handle & body interactions in Axis or Select mode
    if (_activeTool == ArchitectTool.axis || _activeTool == ArchitectTool.select) {
      // 1a. Handle hit check (stretching axis extents)
      final axisHandle = _axisTool.hitTestAxisHandle(
        rawModel,
        _project.gridAxes,
        tolerance: 18.0 / _currentScale,
      );
      if (axisHandle != null) {
        _axisTool.startHandleDrag(axisHandle.$1, axisHandle.$2);
        _isHandleEngaged = true;
        setState(() {
          _selectedZoneId = null;
          _selectedElementId = null;
        });
        HapticFeedback.selectionClick();
        ArchitectLogger.log('HANDLE', 'Axis handle drag engaged for ${axisHandle.$1.name}');
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
          ArchitectLogger.log('HANDLE', 'Axis moving engaged for ${hitAxis.name}');
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
    if (_activeTool == ArchitectTool.zone || _activeTool == ArchitectTool.select) {
      // 2a. Whole zone move mode check (GPS_Mapping mode)
      if (_zoneTool.isMoveWholeZoneMode && _selectedZone != null) {
        _zoneTool.startMovingZone(rawModel);
        _isHandleEngaged = true;
        ArchitectLogger.log('HANDLE', 'Zone move whole mode engaged for ${_selectedZone!.name}');
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
            _zoneMoveOriginalPolygon = List<Offset>.from(currentSelected.polygon);
            _isHandleEngaged = true;
          });
          ArchitectLogger.log('HANDLE', 'Zone body drag initiated for ${currentSelected.name}');
          return;
        }
      }
    }

    // No handle engaged on pointer-down: free pan/zoom candidate
    ArchitectLogger.log(
      'VIEWPORT',
      'Pointer down at $rawModel - no handle hit, free pan candidate',
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointersCount > 1 || _isMultiTouchGesture) {
      return;
    }

    final rawModel = _screenToModel(event.localPosition);

    // 0. Axis offset drag preview
    if (_axisTool.isOffsettingWithDrag) {
      _axisTool.updateOffsetDrag(rawModel);
      return;
    }

    // 0b. Axis handle stretching
    if (_axisTool.isDraggingHandle) {
      _axisTool.updateHandleDrag(rawModel, _project.gridAxes, _currentScale);
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
        raw: rawModel,
        project: _project,
        excludedZoneId: _selectedZoneId,
        movingVertexIndex: _draggingVertexIndex,
        tolerance: 14.0 / _currentScale,
      );
      setState(() {
        _draggingVertexPoint = snap.point;
        _mergeCandidateIndex = snap.mergeCandidateIndex;
        _activeMagneticGuides = snap.magneticGuides;
        _activeSnapLabel = snap.snapLabel;
      });
      return;
    }

    // 4. Moving whole zone (GPS_Mapping mode or legacy drag)
    if (_zoneTool.isMoveWholeZoneMode && _zoneTool.isEditingZone) {
      _zoneTool.updateMovingZone(rawModel);
      return;
    }
    if (_zoneMoveStartPoint != null && _zoneMoveOriginalPolygon != null && _selectedZone != null) {
      final delta = rawModel - _zoneMoveStartPoint!;
      final translated = _zoneMoveOriginalPolygon!.map((p) => p + delta).toList();
      _updateZone(_selectedZone!.copyWith(polygon: translated));
      return;
    }

    // 5. Wall drafting preview
    if (_activeTool == ArchitectTool.wall && _draftStart != null) {
      final snap = ArchitectSnapHelper.snapWithAnchor(
        anchor: _draftStart!,
        rawPoint: rawModel,
        project: _project,
        tolerance: 12.0 / _currentScale,
      );
      setState(() {
        _draftEnd = snap.point;
        _activeSnapLabel = snap.snapLabel;
      });
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
      final snap = ArchitectSnapHelper.snapWithAnchor(
        anchor: _draftStart!,
        rawPoint: rawModel,
        project: _project,
        tolerance: 12.0 / _currentScale,
      );
      setState(() {
        _draftEnd = snap.point;
        _activeSnapLabel = snap.snapLabel;
      });
      return;
    }

    // 7. Slab drafting candidate
    if (_activeTool == ArchitectTool.slab &&
        _elementTool.slabDraftPoints.isNotEmpty) {
      _elementTool.updateSlabCandidate(rawModel);
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    final rawModel = _screenToModel(event.localPosition);
    if (_zoneTool.isDrafting) {
      _zoneTool.updateDraftingPointer(
        rawModelPoint: rawModel,
        project: _project,
        currentScale: _currentScale,
      );
    } else if (_activeTool == ArchitectTool.axis && _axisTool.isDrafting) {
      _axisTool.updateDrafting(rawModel, _project, _currentScale);
    } else if (_activeTool == ArchitectTool.slab &&
        _elementTool.slabDraftPoints.isNotEmpty) {
      _elementTool.updateSlabCandidate(rawModel);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointersCount = math.max(0, _activePointersCount - 1);
    ArchitectLogger.log(
      'POINTER_UP',
      'Pointer #${event.pointer} up at (${event.localPosition.dx.toStringAsFixed(1)}, ${event.localPosition.dy.toStringAsFixed(1)}) | Pointers count: $_activePointersCount',
    );

    if (_isMultiTouchGesture) {
      if (_activePointersCount == 0) {
        _isMultiTouchGesture = false;
        ArchitectLogger.log('GESTURE', 'Multi-touch gesture ended.');
      }
      return;
    }

    // If an element handle was actively being dragged, commit the drag!
    if (_isActivelyDraggingHandle) {
      _commitActiveHandleDrag(event.localPosition);
      _isHandleEngaged = false;
      return;
    }

    // Otherwise, check if this was a clean TAP vs a canvas PAN
    final downPos = _pointerDownScreenPos;
    final downTime = _pointerDownTime;
    final dist = downPos != null ? (event.localPosition - downPos).distance : 999.0;
    final elapsedMs = downTime != null
        ? DateTime.now().difference(downTime).inMilliseconds
        : 999;

    // A tap is defined by physical displacement (dist < 20.0px), NOT arbitrary timer timeout.
    // Stationary touch holding to aim (e.g. 600-1200ms) is 100% a TAP.
    if (dist < 20.0) {
      final rawModel = _screenToModel(event.localPosition);
      ArchitectLogger.log(
        'TAP',
        'Clean tap recognized at model ($rawModel) | dist: ${dist.toStringAsFixed(1)}px, time: ${elapsedMs}ms',
      );
      _handleTap(rawModel);
    } else {
      ArchitectLogger.log(
        'PAN',
        'Canvas pan completed (dist: ${dist.toStringAsFixed(1)}px, time: ${elapsedMs}ms). Viewport moved.',
      );
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointersCount = math.max(0, _activePointersCount - 1);
    ArchitectLogger.log('GESTURE', 'Pointer cancel #${event.pointer}');
    if (_activePointersCount == 0) {
      _isMultiTouchGesture = false;
      _cancelActiveDrags();
    }
  }

  void _cancelActiveDrags() {
    _isHandleEngaged = false;
    _draggingVertexIndex = null;
    _draggingVertexPoint = null;
    _mergeCandidateIndex = null;
    _zoneMoveStartPoint = null;
    _zoneMoveOriginalPolygon = null;
    _activeMagneticGuides = [];
    _activeSnapLabel = null;
    if (_zoneTool.isExtruding) {
      _zoneTool.cancelExtrude();
    }
    if (_zoneTool.isMovingZone) {
      _zoneTool.finishMovingZone();
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
          final cleaned = ArchitectZoneGeometry.cleanPolygon(updated.polygon);
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
        final candidatePoly = List<Offset>.from(zone.polygon)..[idx] = _draggingVertexPoint!;
        if (ArchitectZoneGeometry.hasSelfIntersections(candidatePoly)) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectZoneSelfIntersectError),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final cleaned = ArchitectZoneGeometry.cleanPolygon(candidatePoly);
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
      setState(() {
        _zoneMoveStartPoint = null;
        _zoneMoveOriginalPolygon = null;
        _activeMagneticGuides = [];
      });
      return;
    }

    // 4. Wall drafting commit
    if (_activeTool == ArchitectTool.wall &&
        _wallMode == WallDraftingMode.singleLine &&
        _draftStart != null &&
        _draftEnd != null) {
      _commitCurrentWallSegment(_draftEnd!);
      setState(() {
        _draftStart = null;
        _draftEnd = null;
        _activeSnapLabel = null;
      });
    }
  }

  void _handleTap(Offset rawModel) {
    // 1. In Axis tool
    if (_activeTool == ArchitectTool.axis) {
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

      // If axis drafting is in progress, commit it
      if (_axisTool.isDrafting) {
        final isBg = Localizations.localeOf(context).languageCode == 'bg';
        final result = _axisTool.commitDrafting(project: _project, isBulgarian: isBg);
        if (result != null) {
          final (updatedProj, newAxis) = result;
          setState(() => _project = updatedProj);
          HapticFeedback.mediumImpact();
        }
        return;
      }

      // Empty space tap -> start drafting new axis
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModel,
        project: _project,
        tolerance: 14.0 / _currentScale,
      );
      _axisTool.startDrafting(snap.isSnapped ? snap.point : rawModel);
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
        } else if (_zoneTool.pointStatus == ZoneDraftingPointStatus.selfIntersects) {
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
      ArchitectLogger.log('DRAFT', 'Started zone drafting at point 1: $startPt');
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
      if (_draftStart == null) {
        final snap = ArchitectSnapHelper.snapFree(
          rawPoint: rawModel,
          project: _project,
          tolerance: 10.0 / _currentScale,
        );
        setState(() {
          _draftStart = snap.point;
          _draftEnd = snap.point;
          _activeSnapLabel = snap.snapLabel;
        });
      } else {
        _commitCurrentWallSegment(rawModel);
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
      final pt = snap.isSnapped ? snap.point : rawModel;
      final (updatedStorey, newCol) = _elementTool.placeColumn(
        storey: _project.activeStorey,
        point: pt,
      );
      setState(() {
        _project = _project.updateActiveStorey(updatedStorey);
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
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModel,
        project: _project,
        tolerance: 14.0 / _currentScale,
      );
      final pt = snap.isSnapped ? snap.point : rawModel;

      if (_elementTool.slabDraftPoints.length >= 3 &&
          (pt - _elementTool.slabDraftPoints.first).distance <=
              16.0 / _currentScale) {
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
          _draftStart = rawModel;
          _draftEnd = rawModel;
        });
      } else {
        final res = _elementTool.placeOpening(
          storey: _project.activeStorey,
          p1: _draftStart!,
          p2: rawModel,
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
          _draftStart = rawModel;
          _draftEnd = rawModel;
        });
      } else {
        final res = _elementTool.placeStair(
          storey: _project.activeStorey,
          start: _draftStart!,
          end: rawModel,
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
          _draftStart = rawModel;
          _draftEnd = rawModel;
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
          end: rawModel,
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
          _draftStart = rawModel;
          _draftEnd = rawModel;
        });
      } else {
        final dist = (rawModel - _draftStart!).distance;
        final dx = (rawModel.dx - _draftStart!.dx).abs();
        final dy = (rawModel.dy - _draftStart!.dy).abs();
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

  void _commitCurrentWallSegment(Offset targetPoint) {
    if (_draftStart == null) return;
    final p1 = _draftStart!;
    final p2 = targetPoint;
    final len = (p2 - p1).distance;
    if (len < 0.20) return; // Ignore micro taps < 20 cm

    final now = DateTime.now().millisecondsSinceEpoch;
    final newWall = ArchitectWall(
      id: 'wall_$now',
      startPoint: p1,
      endPoint: p2,
      thickness: _activeWallType?.totalThickness ?? _wallThickness,
      height: _activeWallType?.customHeight ?? _project.activeStorey.height,
      wallTypeId: _activeWallType?.id,
      parapetFinish: _activeWallType?.parapetFinish,
    );

    final updatedStorey = _project.activeStorey.copyWith(
      walls: [..._project.activeStorey.walls, newWall],
    );

    setState(() {
      _project = _project.updateActiveStorey(updatedStorey);
      if (_wallMode == WallDraftingMode.chained) {
        _draftStart = p2;
        _draftEnd = p2;
      }
    });
    _saveBiMProjectIfAttached();

    HapticFeedback.lightImpact();
  }

  void _finishChainedWall() {
    setState(() {
      _draftStart = null;
      _draftEnd = null;
      _activeSnapLabel = null;
    });
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
    final now = DateTime.now().millisecondsSinceEpoch;

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
            child: Text(
              l10n.ok,
              style: const TextStyle(color: Colors.white),
            ),
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
      final updatedProj = _axisTool.deleteAxisById(_project, previousAxis.id, isBg);
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

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _project.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              l10n.architectStudioSubtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          // 2D / 3D Toggle Button
          IconButton(
            tooltip: _is3DView ? l10n.architectView2D : l10n.architectView3D,
            icon: Icon(
              _is3DView ? Icons.crop_square_rounded : Icons.view_in_ar_rounded,
              color: const Color(0xFF00E5FF),
            ),
            onPressed: () => setState(() => _is3DView = !_is3DView),
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
          IconButton(
            tooltip: l10n.architectNewProject,
            icon: const Icon(Icons.add_business_rounded),
            onPressed: _openNewProjectWizard,
          ),
          // Diagnostic Logs Dialog Button
          IconButton(
            tooltip: l10n.architectDebugLogs,
            icon: const Icon(Icons.bug_report_rounded),
            onPressed: _showDebugLogsDialog,
          ),
          // CAD Underlay Toggle Button (if underlays are present)
          if (_underlaysByStorey.isNotEmpty)
            IconButton(
              tooltip: l10n.architectUnderlayToggle,
              icon: Icon(
                _showUnderlay ? Icons.layers_rounded : Icons.layers_clear_rounded,
                color: _showUnderlay ? const Color(0xFF00E5FF) : Colors.white38,
              ),
              onPressed: () => setState(() => _showUnderlay = !_showUnderlay),
            ),
        ],
      ),
      body: Column(
        children: [
          // Storey Level Bar
          ArchitectStoreyBar(
            project: _project,
            onStoreySelected: (sId) {
              setState(() => _project = _project.copyWith(activeStoreyId: sId));
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
                      onUndo: () => setState(
                          () => _zoneTool.undoDraftingPoint()),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E1E26),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.selectedElement(_selectedElementId!),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
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
                    onPressed: () => setState(() => _selectedElementId = null),
                  ),
                ],
              ),
            ),

          // Bottom Responsive Tool Palette
          if (!_is3DView)
            ArchitectToolPalette(
              activeTool: _activeTool,
              onToolChanged: (tool) => setState(() {
                _zoneTool.cancelAll();
                _axisTool.cancelAll();
                _elementTool.cancelSlabDrafting();
                _selectedZoneId = null;
                _selectedElementId = null;
                _activeTool = tool;
                _draftStart = null;
                _draftEnd = null;
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
              isChainingWall: _draftStart != null &&
                  _wallMode == WallDraftingMode.chained,
              onFinishChainedWall: _finishChainedWall,
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
              onOpeningTypeChanged: (ot) =>
                  _elementTool.setOpeningType(ot),
            ),
        ],
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
                  const Icon(Icons.bug_report_rounded, color: Color(0xFF00E5FF)),
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
                          final isGesture = logItem.contains('[GESTURE]') ||
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
                          Clipboard.setData(ClipboardData(text: logs.join('\n')));
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

  // === SECTION: 2D CANVAS VIEWPORT (INTERACTIVE VIEWER) ===

  Widget _build2DCanvas() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerHover: _onPointerHover,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.01,
        maxScale: 100.0,
        panEnabled: !_isActivelyDraggingHandle,
        scaleEnabled: !_isActivelyDraggingHandle,
        trackpadScrollCausesScale: true,
        onInteractionStart: (details) {
          if (details.pointerCount > 1) {
            setState(() {
              _isMultiTouchGesture = true;
              _cancelActiveDrags();
            });
            ArchitectLogger.log(
              'VIEWPORT',
              'Multi-touch gesture started (${details.pointerCount} pointers). Dragging cancelled.',
            );
          }
        },
        onInteractionUpdate: (details) {
          if (details.pointerCount > 1) {
            _isMultiTouchGesture = true;
          }
        },
        onInteractionEnd: (details) {
          _activePointersCount = 0;
          _isMultiTouchGesture = false;
          ArchitectLogger.log(
            'VIEWPORT',
            'Viewport transform settled at scale: ${_currentScale.toStringAsFixed(2)}',
          );
        },
        child: SizedBox.expand(
          child: CustomPaint(
            painter: Architect2dPainter(
              project: _project,
              activeTool: _activeTool,
              activeDraftStart: _draftStart,
              activeDraftEnd: _draftEnd,
              activeWallThickness: _wallThickness,
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
                  _zoneTool.pointStatus ==
                      ZoneDraftingPointStatus.selfIntersects,
              zoneCloseLabel: context.l10n.architectZonePointSnapStart,
              zoneExtrudePreviewPolygon:
                  _zoneTool.extrudePreviewPolygon,
              zoneExtrudeV1: _zoneTool.extrudeV1,
              zoneExtrudeV2: _zoneTool.extrudeV2,
              zoneExtrudeNormal: _zoneTool.extrudeNormal,
              zoneExtrudeDistance: _zoneTool.extrudeDistance,
              isZoneExtrudeSelfIntersecting:
                  _zoneTool.isExtrudeSelfIntersecting,
              zonePreviewRectangle: _zoneTool.previewRectangle,
              zoneEditingPolygon: _zoneTool.editingPolygon,
              isMoveWholeZoneMode: _zoneTool.isMoveWholeZoneMode,
              zoneMoveDistanceMeters: _zoneTool.moveDistanceMeters,
              underlayDoc: _currentUnderlayDoc,
              underlayLayerVisibility: _underlayLayerVisibility,
              slabDraftPoints: _elementTool.slabDraftPoints,
              slabCandidatePoint: _elementTool.slabCandidatePoint,
            ),
          ),
        ),
      ),
    );
  }

  // === SECTION: 3D SOLID VIEWPORT ===

  Widget _build3DViewport() {
    final mesh = Architect3dBuilder.buildProjectMesh(_project);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _camera3D.yaw += details.delta.dx * 0.01;
          _camera3D.pitch =
              (_camera3D.pitch + details.delta.dy * 0.01).clamp(0.05, math.pi / 2 - 0.05);
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
