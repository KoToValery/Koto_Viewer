import '../widgets/architect_slab_layers_dialog.dart';
import '../widgets/architect_roof_layers_dialog.dart';
import '../widgets/architect_roof_bar.dart';
import '../services/architect_roof_tool.dart';
import '../widgets/architect_building_sections_screen.dart';
import '../widgets/architect_elevations_screen.dart';
import '../../bim_editing/widgets/bim_edit_actions.dart';
import '../../bim_editing/geometry/bim_contour_drafting_geometry.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_camera.dart';
import '../../dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../bim_projects/models/bim_work_project.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../bim_editing/interaction/bim_edit_session.dart';
import '../../bim_editing/interaction/bim_drag_session.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../structural_designer/analysis/structural_pointer_interaction.dart';
import '../../structural_designer/rendering/structural_pointer_painter.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../models/architect_door.dart';
import '../models/architect_window.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_canvas_palette.dart';
import '../rendering/architect_ghost_storey_painter.dart';
import '../widgets/architect_workspace_settings_dialog.dart';
import '../rendering/architect_3d_builder.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_wall_snap.dart';
import '../rendering/architect_wall_geometry.dart';
import '../rendering/architect_zone_snap.dart';
import '../rendering/architect_underlay_painter.dart';
import '../rendering/architect_scene_geometry.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_element_tool.dart';
import '../services/architect_stair_rules.dart';
import '../widgets/architect_stair_properties_dialog.dart';
import '../services/architect_polygon_editor.dart';
import '../services/architect_polygon_dimensions.dart';
import '../services/architect_polygon_geometry.dart';
import '../widgets/architect_polygon_distance_overlay.dart';
import '../widgets/architect_shape_dimension_panel.dart';
import '../services/architect_selection.dart';
import '../services/architect_dimension_chain.dart';
import '../rendering/architect_dimension_chain_preview.dart';
import '../widgets/architect_dimension_edit_overlay.dart';
import '../services/architect_wall_relations.dart';
import '../rendering/architect_clearance_badge_layout.dart';
import '../rendering/architect_wall_network.dart';
import '../widgets/architect_element_properties_dialog.dart';
import '../widgets/architect_radial_menu.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../services/architect_grid_axis_tool.dart';
import '../services/architect_axis_geometry.dart';
import '../widgets/architect_axis_value_dialog.dart';
import '../services/architect_logger.dart';
import '../services/architect_zone_tool.dart';
import '../models/architect_wall_type.dart';
import '../widgets/architect_grid_axis_bar.dart';
import '../widgets/architect_grid_axis_offset_dialog.dart';
import '../widgets/architect_grid_axis_properties_card.dart';
import '../widgets/architect_project_wizard_dialog.dart';
import '../widgets/architect_workspace_view_bar.dart';
import '../services/architect_workspace_view_controller.dart';
import '../services/architect_building_elevation.dart';
import '../services/architect_building_section.dart';
import '../widgets/architect_tool_palette.dart';
import '../widgets/architect_zone_drafting_bar.dart';
import '../widgets/architect_zone_properties_card.dart';
import '../widgets/architect_viewport.dart';
import '../widgets/architect_wall_drafting_panel.dart';
import 'fenestration_editor_screen.dart';
import '../models/architect_fenestration_style.dart';
import '../services/fenestration_library_service.dart';
import '../services/architect_wall_overshoot_detector.dart';
import '../widgets/architect_wall_overshoot_banner.dart';

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

class _ArchitectSurfaceHit {
  final Offset anchor;
  final Offset direction;
  final Offset normal;
  final double distance;
  const _ArchitectSurfaceHit({
    required this.anchor,
    required this.direction,
    required this.normal,
    required this.distance,
  });
}

// === SECTION: STATE & TOOL CONTROLLERS ===
class _ArchitectWorkspaceScreenState extends State<ArchitectWorkspaceScreen> {
  late final ArchitectWorkspaceViewController _commands;
  late final ArchitectCommandController _modelCommands;
  ArchitectProject get _project => _commands.project;
  set _project(ArchitectProject value) => _commands.commit(value);
  final Map<ArchitectWorkspaceView, String> _lastViewIds = {};
  final Map<String, ({double scale, Offset translation})> _viewCameras = {};
  ArchitectProject? _projectionSource;
  String? _projectionKey;
  ArchitectBuildingElevation? _facadeGeometry;
  ArchitectBuildingSection? _sectionGeometry;

  String get _workspaceViewKey => _commands.isPlan
      ? 'plan:${_modelCommands.project.activeStoreyId}'
      : '${_commands.view.name}:${_commands.viewId}';

  void _selectWorkspaceView(ArchitectWorkspaceView type, String? id) {
    _cancelDrafting();
    _clearSelection();
    _viewCameras[_workspaceViewKey] = (
      scale: _viewport.scale,
      translation: _viewport.translation,
    );
    if (id != null) _lastViewIds[type] = id;
    _commands.select(type, id);
    if (type == ArchitectWorkspaceView.plan && id != null) {
      _commands.activateStorey(id);
    }
    setState(() {
      _is3DView = false;
      _activeTool = ArchitectTool.select;
      _interactionEpoch++;
    });
    final saved = _viewCameras[_workspaceViewKey];
    if (saved == null) {
      _initTransform();
    } else {
      _viewport.navigate(
        previousFocal: Offset.zero,
        focal: Offset.zero,
        scaleFactor: saved.scale / _viewport.scale,
      );
      _viewport.panBy(saved.translation - _viewport.translation);
    }
  }

  Future<void> _manageWorkspaceViews(ArchitectWorkspaceView type) async {
    _cancelDrafting();
    String? selected = _lastViewIds[type];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => type == ArchitectWorkspaceView.elevation
            ? ArchitectElevationsScreen(
                controller: _modelCommands,
                initialSelectedId: selected,
                onViewSelected: (id) => selected = id,
              )
            : ArchitectBuildingSectionsScreen(
                controller: _modelCommands,
                initialSelectedId: selected,
                onViewSelected: (id) => selected = id,
              ),
      ),
    );
    if (mounted) _selectWorkspaceView(type, selected);
  }

  void _cacheProjection() {
    final original = _modelCommands.project;
    if (identical(original, _projectionSource) &&
        _projectionKey == _workspaceViewKey) {
      return;
    }
    _projectionSource = original;
    _projectionKey = _workspaceViewKey;
    _facadeGeometry = null;
    _sectionGeometry = null;
    if (_commands.view == ArchitectWorkspaceView.elevation) {
      final e = original.elevations
          .where((e) => e.id == _commands.viewId).firstOrNull;
      if (e != null) {
        _facadeGeometry = ArchitectBuildingElevation.build(original, e);
      }
    } else if (_commands.view == ArchitectWorkspaceView.section) {
      final s = original.sections
          .where((e) => e.id == _commands.viewId).firstOrNull;
      if (s != null) {
        _sectionGeometry = ArchitectBuildingSection.build(original, s);
      }
    }
  }

  ArchitectSectionDrawing? get _workspaceSectionDrawing {
    _cacheProjection();
    final cut = _modelCommands.project.sections
        .where((e) => e.id == _commands.viewId).firstOrNull;
    if (cut == null || _sectionGeometry == null) return null;
    return ArchitectSectionDrawing(
      _modelCommands.project,
      cut,
      _sectionGeometry!,
      context.l10n,
      _canvasPalette.isDark ? const ColorScheme.dark() : const ColorScheme.light(),
      null,
      Theme.of(context).textTheme.bodyMedium?.fontFamily,
    );
  }

  Rect? get _workspaceViewBounds {
    if (_commands.isPlan) return null;
    _cacheProjection();
    final b = _facadeGeometry?.bounds ?? _workspaceSectionDrawing?.bounds;
    return b == null ? null : Rect.fromLTRB(b.left, -b.bottom, b.right, -b.top);
  }

  CustomPainter? get _workspaceProjectionPainter {
    _cacheProjection();
    final centre = _viewport.visibleRect.center;
    final upCentre = Offset(centre.dx, -centre.dy);
    if (_facadeGeometry != null) {
      return ArchitectFacadePainter(
        _facadeGeometry!, upCentre, _viewport.scale,
        fill: _canvasPalette.background,
        stroke: _canvasPalette.foreground(Colors.black),
      );
    }
    final drawing = _workspaceSectionDrawing;
    return drawing == null
        ? null
        : ArchitectBuildingSectionPainter(drawing, upCentre, _viewport.scale);
  }
  Timer? _saveTimer;
  final ValueNotifier<int> _previewRevision = ValueNotifier(0);
  Object? _toolUiState;
  int _interactionEpoch = 0;
  bool _dimensionChainMode = false;
  ArchitectDimensionStyle _dimensionStyle = ArchitectDimensionStyle.single;
  ArchitectDimension? _dimensionEditing;
  final List<ArchitectDimensionAnchor> _dimensionAnchors = [];
  Offset? _dimensionDirection;
  bool _dimensionPlacing = false;
  bool _dimensionChoosingDirection = false;
  bool _dimensionAllowPoint = false;
  bool _dimensionQuestionOpen = false;
  double _dimensionOffset = .5;
  bool _dimensionShowOverall = true;
  ArchitectDimensionAnchor? _singleDimensionStartAnchor;
  Offset? _selectionCyclePoint;
  List<String> _selectionCycleIds = [];
  int _selectionCycleIndex = -1;

  void _resetDimensionDraft() {
    _dimensionEditing = null;
    _singleDimensionStartAnchor = null;
    _dimensionAnchors.clear();
    _dimensionDirection = null;
    _dimensionPlacing = false;
    _dimensionChoosingDirection = false;
    _dimensionAllowPoint = false;
    _activeMagneticGuides = [];
    _activeSnapLabel = null;
  }

  ArchitectDimension? get _dimensionDraft {
    if (_dimensionAnchors.length < 2 || _dimensionDirection == null) {
      return null;
    }
    return ArchitectDimensionChain.build(
      id: 'dimension-preview',
      anchors: _dimensionAnchors,
      direction: _dimensionDirection!,
      offset: _dimensionOffset,
      style: _dimensionStyle,
    ).copyWith(
      showOverall: _dimensionShowOverall,
      customText: _dimensionEditing?.customText,
    );
  }

  ArchitectDimension? get _singleDimensionPreview {
    if (_activeTool != ArchitectTool.dimension ||
        _dimensionChainMode ||
        _draftStart == null ||
        _draftEnd == null ||
        (_draftEnd! - _draftStart!).distance < .001) {
      return null;
    }
    return ArchitectDimensionChain.build(
      id: 'dimension-preview',
      anchors: [
        _singleDimensionStartAnchor ??
            ArchitectDimensionAnchor(point: _draftStart!),
        ArchitectDimensionAnchor(point: _draftEnd!),
      ],
      direction: _draftEnd! - _draftStart!,
      offset: _dimensionOffset,
      style: ArchitectDimensionStyle.single,
    );
  }

  void _addWallsToDimension(ArchitectDimension dimension) {
    _cancelDrafting();
    setState(() {
      _activeTool = ArchitectTool.dimension;
      _dimensionStyle = dimension.isChain
          ? dimension.style
          : ArchitectDimensionStyle.single;
      _dimensionChainMode = true;
      _dimensionEditing = dimension;
      _dimensionAnchors.addAll(
        dimension.isChain
            ? dimension.anchors
            : [
                ArchitectDimensionAnchor(point: dimension.startPoint),
                ArchitectDimensionAnchor(point: dimension.endPoint),
              ],
      );
      _dimensionDirection = dimension.unitVector;
      _dimensionOffset = dimension.offsetDistance;
      _dimensionShowOverall = dimension.showOverall;
    });
  }

  void _removeDimensionReference(ArchitectDimensionEditPoint reference) {
    final draft = _dimensionDraft;
    if (draft == null) return;
    final next = ArchitectDimensionChain.removeAnchors(
      draft,
      reference.anchorIndices,
    );
    if (next == null) return;
    setState(() {
      _dimensionAnchors
        ..clear()
        ..addAll(next.anchors);
      _dimensionOffset = next.offsetDistance;
    });
    HapticFeedback.selectionClick();
  }

  List<String> _selectionCandidates(Offset point) {
    final first = _hitSelection(point);
    return <String>{
      ?first,
      ..._elementTool.hitTestElements(
        _project.activeStorey,
        point,
        _currentScale,
      ),
      for (final zone in _project.activeStorey.zones)
        if ((Path()..addPolygon(zone.polygon, true)).contains(point)) zone.id,
      for (final axis in _project.gridAxes)
        if ((point - BimLineGeometry.closest(point, axis.start, axis.end))
                .distance <=
            14 / _currentScale)
          axis.id,
    }.toList();
  }

  String? _nextSelection(Offset point, {bool advance = true}) {
    final ids = _selectionCandidates(point);
    if (ids.isEmpty) {
      _selectionCyclePoint = null;
      return null;
    }
    // Stable candidate ordering is independent of the current primary tool hit.
    final same =
        _selectionCyclePoint != null &&
        (point - _selectionCyclePoint!).distance * _currentScale <= 12 &&
        ids.length == _selectionCycleIds.length &&
        ids.every(_selectionCycleIds.contains);
    if (!same) {
      _selectionCyclePoint = point;
      _selectionCycleIds = ids;
      _selectionCycleIndex = -1;
    }
    if (advance || _selectionCycleIndex < 0) {
      _selectionCycleIndex =
          (_selectionCycleIndex + 1) % _selectionCycleIds.length;
      if (_multiSelect) {
        for (var step = 0; step < _selectionCycleIds.length; step++) {
          final index =
              (_selectionCycleIndex + step) % _selectionCycleIds.length;
          if (!_effectiveSelection.contains(_selectionCycleIds[index])) {
            _selectionCycleIndex = index;
            break;
          }
        }
      }
    }
    return _selectionCycleIds[_selectionCycleIndex];
  }

  void _commitDimensionDraft() {
    final draft = _dimensionDraft;
    if (draft == null || draft.length < .001 ||
        draft.dimensionPoints.length < 2) {
      _operationError();
      return;
    }
    final dimension = draft.copyWith(
      id: _dimensionEditing?.id ?? ArchitectElementId.next('dimension'),
    );
    _commands.commit(
      _project.updateActiveStorey(
        _project.activeStorey.copyWith(
          dimensions: _dimensionEditing == null
              ? [..._project.activeStorey.dimensions, dimension]
              : [
                  for (final d in _project.activeStorey.dimensions)
                    if (d.id == dimension.id) dimension else d,
                ],
        ),
      ),
    );
    setState(_resetDimensionDraft);
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
  }

  ArchitectDimensionAnchor _dimensionPointAnchor(Offset point) {
    final candidates = _selectionCandidates(point);
    for (final id in candidates) {
      final wall = _project.activeStorey.walls
          .where((w) => w.id == id)
          .firstOrNull;
      if (wall != null) {
        final ratio = BimLineGeometry.parameter(
          point,
          wall.coreCenterStart,
          wall.coreCenterEnd,
        );
        final center =
            wall.coreCenterStart +
            (wall.coreCenterEnd - wall.coreCenterStart) * ratio;
        return ArchitectDimensionAnchor(
          point: point,
          elementId: id,
          feature: 'wallFace',
          ratio: ratio,
          side:
              ArchitectDimensionChain.dot(point - center, wall.normalVector) /
              wall.coreThickness,
        );
      }
      final anchor = ArchitectDimensionChain.pickElement(_project, id, point);
      if (anchor != null &&
          (anchor.point - point).distance <= 16 / _currentScale) {
        return anchor;
      }
    }
    return ArchitectDimensionAnchor(point: point);
  }

  Future<void> _askDimensionFinish() async {
    if (_dimensionQuestionOpen) return;
    _dimensionQuestionOpen = true;
    final epoch = _interactionEpoch;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('architect-dimension-finish-dialog'),
        title: Text(context.l10n.architectDimensionChain),
        actions: [
          TextButton(
            key: const ValueKey('architect-dimension-continue'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.architectDimensionContinue),
          ),
          FilledButton(
            key: const ValueKey('architect-dimension-finish'),
            onPressed: _dimensionDraft == null
                ? null
                : () => Navigator.pop(context, true),
            child: Text(context.l10n.architectDimensionFinish),
          ),
        ],
      ),
    );
    _dimensionQuestionOpen = false;
    if (!mounted || epoch != _interactionEpoch || finish == null) return;
    if (finish && _dimensionEditing != null) {
      _commitDimensionDraft();
      return;
    }
    setState(() {
      _dimensionPlacing = finish;
      _dimensionAllowPoint = !finish;
    });
  }

  Future<void> _setDimensionDistance() async {
    if (_dimensionDraft == null) return;
    final epoch = _interactionEpoch;
    final unit = _project.units;
    double? distance;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.architectPropertyOffset),
        content: ArchitectShapeDimensionPanel(
          values: [unit.toUnit(_dimensionOffset)],
          labels: [context.l10n.architectPropertyOffset],
          unit: unit.symbol,
          signed: true,
          minimum: -double.maxFinite,
          onChanged: (_, value) => distance = unit.fromUnit(value),
          onSave: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      ),
    );
    if (!mounted || epoch != _interactionEpoch || accepted != true) return;
    _dimensionOffset = distance ?? _dimensionOffset;
    _commitDimensionDraft();
  }

  void _handleDimensionChainTap(Offset raw) {
    if (_dimensionQuestionOpen) return;
    if (_dimensionChoosingDirection) {
      final surface = _findNearestSurface(raw);
      if (surface == null) {
        _operationError();
        return;
      }
      final referenceWall = _project.activeStorey.walls
          .where((w) => w.containsPoint(raw, tolerance: 8 / _currentScale))
          .firstOrNull;
      final direction = referenceWall?.unitVector ?? surface.direction;
      final proposed = ArchitectDimensionChain.build(
        id: 'preview',
        anchors: _dimensionAnchors,
        direction: direction,
      );
      if (_dimensionAnchors.length >= 2 && proposed.length < .001) {
        _operationError();
        return;
      }
      setState(() {
        _dimensionDirection = direction;
        _dimensionChoosingDirection = false;
        _dimensionPlacing = _dimensionAnchors.length >= 2;
      });
      return;
    }
    if (_dimensionPlacing) {
      final draft = _dimensionDraft;
      if (draft == null) return;
      final rawOffset = ArchitectDimensionChain.dot(
        raw - draft.startPoint,
        draft.normal,
      );
      final snap = _snapDimensionOffset(draft, rawOffset);
      _dimensionOffset = snap.offset;
      _activeSnapLabel = null;
      _activeMagneticGuides = [];
      _commitDimensionDraft();
      return;
    }
    final ids = _selectionCandidates(raw);

    // 1. Check if an opening (window or door) was picked
    ArchitectWall? openingHostWall;
    String? openingId;
    for (final w in _project.activeStorey.walls) {
      for (final o in [
        ...w.doors.map((d) => d.id),
        ...w.windows.map((win) => win.id),
      ]) {
        if (ids.contains(o)) {
          openingHostWall = w;
          openingId = o;
          break;
        }
      }
      if (openingId != null) break;
    }

    final snap = _snapDimensionPoint(raw);
    final anchors = <ArchitectDimensionAnchor>[];

    final isCornerSnap = snap.snapLabel != null &&
        (snap.snapLabel == 'Vertex' ||
            snap.snapLabel == 'Endpoint' ||
            snap.snapLabel == 'Intersection' ||
            snap.snapLabel == 'Axis intersection' ||
            snap.snapLabel == 'Center' ||
            snap.snapLabel == 'Corner') &&
        (snap.point - raw).distance <= 20 / _currentScale;

    if (openingId != null && openingHostWall != null) {
      _dimensionDirection ??= openingHostWall.unitVector;
      anchors.addAll(
        ArchitectDimensionChain.openingAnchors(openingHostWall, openingId),
      );
    } else if (isCornerSnap) {
      final cornerWall = _project.activeStorey.walls
          .where((w) => w.containsPoint(snap.point, tolerance: 0.15))
          .firstOrNull;
      anchors.add(
        ArchitectDimensionAnchor(
          point: snap.point,
          elementId: cornerWall?.id,
          feature: 'vertex',
        ),
      );
    } else if (_dimensionAllowPoint && snap.isSnapped) {
      anchors.add(_dimensionPointAnchor(snap.point));
    } else {
      final candidateWalls = _project.activeStorey.walls
          .where((w) => ids.contains(w.id))
          .toList();
      final previousWall = _project.activeStorey.walls
          .where(
            (w) => _dimensionAnchors.any(
              (a) => a.elementId == w.id && a.feature == 'wallFace',
            ),
          )
          .firstOrNull;

      ArchitectWall? wall;
      if (previousWall != null) {
        wall = candidateWalls
            .where(
              (w) =>
                  BimLineGeometry.cross(
                    w.unitVector,
                    previousWall.unitVector,
                  ).abs() <=
                  .01,
            )
            .firstOrNull;
      }
      wall ??= candidateWalls.firstOrNull;

      if (wall != null) {
        if (previousWall != null &&
            BimLineGeometry.cross(
                  wall.unitVector,
                  previousWall.unitVector,
                ).abs() >
                .01) {
          // If tapping near the end of a perpendicular wall (e.g. wall junction or step corner),
          // treat as a vertex corner anchor instead of failing.
          final nearestEnd =
              (raw - wall.startPoint).distance < (raw - wall.endPoint).distance
                  ? wall.startPoint
                  : wall.endPoint;
          if ((raw - nearestEnd).distance <= 24 / _currentScale) {
            anchors.add(
              ArchitectDimensionAnchor(
                point: nearestEnd,
                elementId: wall.id,
                feature: 'vertex',
              ),
            );
          } else {
            _operationError();
            return;
          }
        } else {
          _dimensionDirection ??= wall.normalVector;
          if (_dimensionAllowPoint) {
            anchors.add(ArchitectDimensionChain.wallFaceAt(wall, snap.point));
          } else {
            anchors.addAll(ArchitectDimensionChain.wallFaces(wall, raw));
          }
        }
      } else {
        for (final id in ids) {
          final anchor = ArchitectDimensionChain.pickElement(
            _project,
            id,
            snap.point,
          );
          if (anchor != null) {
            anchors.add(anchor);
            break;
          }
        }
        if (anchors.isEmpty) {
          if (_dimensionAnchors.isNotEmpty && !_dimensionAllowPoint) {
            _askDimensionFinish();
            return;
          }
          anchors.add(ArchitectDimensionAnchor(point: snap.point));
        }
      }
    }
    setState(() {
      final previous = _dimensionEditing == null ? null : _dimensionDraft;
      _dimensionAllowPoint = false;
      for (final a in anchors) {
        if (!_dimensionAnchors.any(
          (b) =>
              a.elementId == b.elementId &&
              a.feature == b.feature &&
              a.index == b.index &&
              a.side == b.side &&
              (a.feature == 'wallFace' || (a.point - b.point).distance < 1e-6),
        )) {
          _dimensionAnchors.add(a);
        }
      }
      if (_dimensionDirection == null && _dimensionAnchors.length >= 2) {
        final delta =
            _dimensionAnchors.last.point - _dimensionAnchors.first.point;
        if (delta.distance > .001) _dimensionDirection = delta / delta.distance;
      }
      if (previous != null) {
        final extended = ArchitectDimensionChain.addAnchors(previous, anchors);
        _dimensionOffset = extended.offsetDistance;
      }
    });
    HapticFeedback.selectionClick();
  }

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
      _elementTool.stairDesign,
      _elementTool.openingType,
      _roofTool.drawMode,
      _roofTool.slopeDegrees,
      _roofTool.eavesOverhang,
      _roofTool.draftPoints.length,
    );
    if (state != _toolUiState && mounted) {
      _toolUiState = state;
      setState(() {});
    }
  }

  ArchitectTool _activeTool = ArchitectTool.zone;
  bool _is3DView = false;
  ArchitectCanvasPalette _canvasPalette = const ArchitectCanvasPalette.light();
  static const _darkCanvasPreference = 'architect_dark_canvas';
  bool _canvasPreferenceChanged = false;
  bool _showGhostStoreys = false;
  bool _showUpperOverhangs = true;
  bool _showDrawingGrid = true;
  double _axisWallCoreThickness = .25;
  bool _viewPreferencesChanged = false;

  Future<void> _loadWorkspacePreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || _viewPreferencesChanged) return;
      setState(() {
        _showGhostStoreys =
            preferences.getBool('architect_ghost_storeys') ?? false;
        _showUpperOverhangs =
            preferences.getBool('architect_upper_overhangs') ?? true;
        _showDrawingGrid =
            preferences.getBool('architect_drawing_grid') ?? true;
        _magnetEnabled = preferences.getBool('architect_magnetic_snap') ?? true;
        _showUnderlay = preferences.getBool('architect_show_underlay') ?? true;
        final core = preferences.getDouble('architect_axis_wall_core') ?? .25;
        _axisWallCoreThickness = core.isFinite && core >= .001 ? core : .25;
      });
      if (widget.initialProject == null &&
          widget.commandController == null &&
          widget.bimProject == null) {
        final name = preferences.getString('architect_display_units');
        final units = ArchitectUnit.values
            .where((unit) => unit.name == name)
            .firstOrNull;
        if (units != null) _commands.setUnits(units);
      }
    } catch (error) {
      debugPrint('Architect workspace preferences: $error');
    }
  }

  Future<void> _saveWorkspacePreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('architect_ghost_storeys', _showGhostStoreys);
      await preferences.setBool(
        'architect_upper_overhangs',
        _showUpperOverhangs,
      );
      await preferences.setBool('architect_drawing_grid', _showDrawingGrid);
      await preferences.setBool('architect_magnetic_snap', _magnetEnabled);
      await preferences.setBool('architect_show_underlay', _showUnderlay);
      await preferences.setDouble(
        'architect_axis_wall_core',
        _axisWallCoreThickness,
      );
      await preferences.setString(
        'architect_display_units',
        _project.units.name,
      );
      if (_canvasPreferenceChanged) {
        await preferences.setBool(_darkCanvasPreference, _canvasPalette.isDark);
      }
    } catch (error) {
      debugPrint('Architect workspace preferences: $error');
    }
  }

  void _changeViewPreference(VoidCallback change) {
    _viewPreferencesChanged = true;
    setState(() {
      change();
      _activeSnapLabel = null;
      _activeMagneticGuides = [];
    });
    unawaited(_saveWorkspacePreferences());
  }

  Future<void> _showWorkspaceSettings() async {
    final result = await showDialog<ArchitectWorkspaceSettings>(
      context: context,
      builder: (_) => ArchitectWorkspaceSettingsDialog(
        hasUnderlay: _underlaysByStorey.isNotEmpty,
        settings: ArchitectWorkspaceSettings(
          units: _project.units,
          dimensionScale: _project.dimensionScale,
          ghostStoreys: _showGhostStoreys,
          upperOverhangs: _showUpperOverhangs,
          grid: _showDrawingGrid,
          magnetic: _magnetEnabled,
          underlay: _showUnderlay,
          darkCanvas: _canvasPalette.isDark,
          axisCoreThickness: _axisWallCoreThickness,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _canvasPreferenceChanged = true;
    _commands.setUnits(result.units);
    _commands.setDimensionScale(result.dimensionScale);
    _changeViewPreference(() {
      _showGhostStoreys = result.ghostStoreys;
      _showUpperOverhangs = result.upperOverhangs;
      _showDrawingGrid = result.grid;
      _magnetEnabled = result.magnetic;
      _showUnderlay = result.underlay;
      _axisWallCoreThickness = result.axisCoreThickness;
      _canvasPalette = result.darkCanvas
          ? const ArchitectCanvasPalette.dark()
          : const ArchitectCanvasPalette.light();
    });
    _saveBiMProjectIfAttached();
  }

  void _generateAxesFromWalls() {
    _cancelDrafting();
    final result = _axisTool.generateOnWalls(
      project: _project,
      coreThickness: _axisWallCoreThickness,
      isBulgarian: context.l10n.usesCyrillicAxisNames,
    );
    _commands.commit(result.project);
    _saveBiMProjectIfAttached();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.walls == 0
              ? context.l10n.architectAxesNoMatchingWalls
              : context.l10n.architectAxesGenerated(result.added),
        ),
      ),
    );
  }

  void _toggle3DView() {
    _cancelActiveDrags();
    if (!_commands.isPlan) {
      _selectWorkspaceView(ArchitectWorkspaceView.plan, _modelCommands.project.activeStoreyId);
    }
    setState(() => _is3DView = !_is3DView);
  }

  void _resetWorkspaceView() {
    if (_is3DView) {
      setState(() {
        _camera3D.yaw = math.pi / 4;
        _camera3D.pitch = .6;
        _camera3D.zoom = 1;
      });
    } else {
      _initTransform();
    }
  }

  Future<void> _loadCanvasPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || _canvasPreferenceChanged) return;
      setState(() {
        _canvasPalette = preferences.getBool(_darkCanvasPreference) == true
            ? const ArchitectCanvasPalette.dark()
            : const ArchitectCanvasPalette.light();
      });
    } catch (error) {
      debugPrint('Architect canvas preference: $error');
    }
  }

  Future<void> _toggleCanvasBackground() async {
    _canvasPreferenceChanged = true;
    final isDark = !_canvasPalette.isDark;
    setState(() {
      _canvasPalette = isDark
          ? const ArchitectCanvasPalette.dark()
          : const ArchitectCanvasPalette.light();
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_darkCanvasPreference, isDark);
    } catch (error) {
      debugPrint('Architect canvas preference: $error');
    }
  }

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

  // Unified tool controller for roof planes, auto-roof generation, and carpentry
  late final ArchitectRoofTool _roofTool;

  // Underlays
  Map<String, DxfDocument> _underlaysByStorey = {};
  final Map<String, bool> _underlayLayerVisibility = {};
  bool _showUnderlay = true;

  DxfDocument? get _currentUnderlayDoc {
    if (!_showUnderlay || !_commands.isPlan) return null;
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
      _modelCommands.project,
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
    if (_wallJoinSourceId != null && !valid.contains(_wallJoinSourceId)) {
      _wallJoinSourceId = null;
      _wallJoinPointer = null;
    }
    if (_isActivelyDraggingHandle) {
      _cancelActiveDrags();
      _interactionEpoch++;
    }
    if (_selectedZoneId != null && _zoneTool.isEditingZone) {
      final zone = _project.activeStorey.zones.firstWhere(
        (z) => z.id == _selectedZoneId,
      );
      if (!identical(_zoneTool.editingZone, zone)) {
        _zoneTool.startEditingZone(zone);
      }
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
    _resetDimensionDraft();
    _selectionCyclePoint = null;
    _polygonEditId = null;
    _polygonSelectedEdge = null;
    _pendingShape = null;
    _shapePanelAnchor = null;
    _selectionIds.clear();
    _wallCutIds = {};
    _wallCutStart = null;
    _wallCutConfirmedDir = null;
    _wallStartAttachment = null;
    _wallExtendId = null;
    _wallJoinSourceId = null;
    _wallJoinPointer = null;
    _multiSelect = false;
    _moveSelection = false;
    _wallParallelMove = false;
    _interactionEpoch++;
    _cancelActiveDrags();
    _zoneTool.cancelAll();
    _axisTool.cancelAll();
    _elementTool.cancelSlabDrafting();
    _roofTool.clearDraft();
    setState(() {
      _draftStart = null;
      _draftEnd = null;
      _wallDirectionLocked = false;
      _selectedZoneId = null;
      _selectedElementId = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionCyclePoint = null;
      _cancelActiveDrags();
      _selectionIds.clear();
      _selectedElementId = null;
      _selectedZoneId = null;
      _axisTool.deselect();
      _zoneTool.cancelEditingZone();
      _multiSelect = false;
      _moveSelection = false;
      _wallParallelMove = false;
      _wallEndpointClearanceId = null;
      _wallExtendId = null;
      _wallJoinSourceId = null;
      _wallJoinPointer = null;
      _wallCutIds = {};
      _wallCutStart = null;
      _wallCutConfirmedDir = null;
    });
  }

  // Wall Drafting State
  double _wallThickness = 0.25; // 25 cm default
  ArchitectWallType? _activeWallType;
  String? _preferredWallTypeId;
  bool _wallPreferenceChanged = false;
  static const _wallTypePreference = 'architect_wall_type';
  List<ArchitectWallType> get _availableWallTypes => _project.wallTypes.isEmpty
      ? ArchitectWallType.standardCatalog()
      : _project.wallTypes;

  void _restoreWallType() {
    final types = _availableWallTypes;
    _activeWallType = types.firstWhere(
      (type) => type.id == _preferredWallTypeId,
      orElse: () => types.firstWhere(
        (type) => type.usage == WallUsage.exterior && type.hasInsulation,
        orElse: () => types.first,
      ),
    );
    _wallThickness = _activeWallType!.totalThickness;
  }

  Future<void> _loadWallTypePreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || _wallPreferenceChanged) return;
      setState(() {
        _preferredWallTypeId = preferences.getString(_wallTypePreference);
        _restoreWallType();
      });
    } catch (error) {
      debugPrint('Architect wall preference: $error');
    }
  }

  Future<void> _selectWallType(ArchitectWallType type) async {
    _wallPreferenceChanged = true;
    setState(() {
      _preferredWallTypeId = type.id;
      _activeWallType = type;
      _wallThickness = type.totalThickness;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_wallTypePreference, type.id);
    } catch (error) {
      debugPrint('Architect wall preference: $error');
    }
  }

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
  String? _wallJoinSourceId;
  Offset? _wallJoinPointer;
  (Offset, Offset)? get _wallJoinLeaderLine {
    if (_wallJoinSourceId == null) return null;
    final wall = _project.activeStorey.walls
        .where((w) => w.id == _wallJoinSourceId)
        .firstOrNull;
    if (wall == null) return null;
    final center = (wall.startPoint + wall.endPoint) / 2;
    final target = _wallJoinPointer ??
        (center + wall.normalVector * (wall.thickness + 0.6));
    return (center, target);
  }
  Set<String> _wallCutIds = {};
  Offset? _wallCutStart;
  Offset? _wallCutConfirmedDir;
  bool _magnetEnabled = true;
  bool _wallCutStroke = false;
  bool _controlTrimClick = false;
  ArchitectWallAttachment? _wallStartAttachment;
  final Set<String> _selectionIds = {};
  Set<String> _groupDragIds = {};
  bool _multiSelect = false;
  bool _moveSelection = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPos;
  Set<String> get _effectiveSelection {
    if (_selectionIds.isNotEmpty) return Set.of(_selectionIds);
    return {
      ?_selectedElementId,
      ?_selectedZoneId,
      if (_axisTool.selectedAxisId != null) _axisTool.selectedAxisId!,
    };
  }

  bool _touchInput = false;
  bool _placingWithHold = false;
  bool _wallPrecisionMode = true;
  Offset? _touchPosition;
  ArchitectWall? _wallEndpointOriginal;
  ArchitectProject? _wallSnapProject;
  bool _wallDragStart = false;
  Offset _wallGrabOffset = Offset.zero;
  bool _wallParallelMove = false;
  String? _wallEndpointClearanceId;
  void _toggleParallelMove() {
    _cancelActiveDrags();
    setState(() {
      _wallParallelMove = !_wallParallelMove;
      _moveSelection = _wallParallelMove;
      _polygonEditId = null;
      _wallCutIds = {};
    });
  }

  Future<void> _editParallelOffset() async {
    final wall = _selectedWall;
    if (wall == null || _effectiveSelection.length != 1) return;
    final value = await showArchitectAxisValueDialog(
      context: context,
      title: context.l10n.architectWallParallel,
      label: '${context.l10n.offsetAction} (${_project.units.symbol})',
      value: '0',
      numeric: true,
    );
    if (!mounted || value == null) return;
    final distance = _project.units.fromUnit(
      double.parse(value.replaceAll(',', '.')),
    );
    if (distance.abs() < 1e-9) return;
    final current = _project.activeStorey.walls
        .where((w) => w.id == wall.id)
        .firstOrNull;
    if (current == null) return;
    _executeWallEdit(
      MoveArchitectElements(
        storeyId: _project.activeStoreyId,
        elementIds: {wall.id},
        delta: current.normalVector * distance,
      ),
    );
    setState(() {
      _wallParallelMove = true;
      _moveSelection = true;
    });
  }

  Offset _parallelDelta(Offset delta, Set<String> ids) {
    if (!_wallParallelMove || ids.length != 1) return delta;
    final wall = (_elementMoveOriginal ?? _project).activeStorey.walls
        .where((w) => ids.contains(w.id))
        .firstOrNull;
    if (wall == null) return delta;
    final normal = wall.normalVector;
    return normal * (delta.dx * normal.dx + delta.dy * normal.dy);
  }

  ArchitectWall? get _selectedWall {
    for (final wall in _project.activeStorey.walls) {
      if (wall.id == _selectedElementId) return wall;
    }
    return null;
  }

  final Set<String> _dismissedOvershoots = {};

  ArchitectWallOvershoot? get _activeOvershoot {
    if (_is3DView) return null;
    final walls = _project.activeStorey.walls;
    if (_selectedWallIds.length == 1) {
      final wall =
          walls.where((w) => w.id == _selectedWallIds.first).firstOrNull;
      if (wall != null) {
        final list = ArchitectWallOvershootDetector.detectForWall(
          wall,
          walls,
          ignoredIds: _dismissedOvershoots,
        );
        if (list.isNotEmpty) return list.first;
      }
    }
    final all = ArchitectWallOvershootDetector.detectInStorey(
      _project.activeStorey,
      ignoredIds: _dismissedOvershoots,
    );
    return all.firstOrNull;
  }

  void _handleTrimOvershoot(ArchitectWallOvershoot overshoot) {
    final commands = ArchitectWallOvershootDetector.createTrimCommands(
      storeyId: _project.activeStoreyId,
      overshoot: overshoot,
    );
    _commands.executeBatch(commands);
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.architectWallOvershootTrimmed(overshoot.overshootCm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  void _handleDismissOvershoot(ArchitectWallOvershoot overshoot) {
    setState(() {
      _dismissedOvershoots.add(overshoot.id);
    });
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
  BimDragSession<ArchitectProject>? _duplicateMove;
  String? _duplicateMoveId, _duplicateSourceId;
  void _beginDuplicateMove(String id) {
    _cancelActiveDrags();
    final (floor, copyId) = _elementTool.duplicateElementById(
      _project.activeStorey,
      id,
      offset: Offset.zero,
    );
    if (copyId == null) return;
    final draft = _project.updateActiveStorey(floor);
    final bounds = ArchitectSelection.bounds(draft, copyId);
    if (bounds == null) return;
    final storeyId = _project.activeStoreyId;
    setState(() {
      _polygonEditId = null;
      _duplicateMoveId = copyId;
      _duplicateSourceId = id;
      _duplicateMove = BimDragSession(
        context: _elementMoveContext,
        original: draft,
        anchor: bounds.center,
        translate: (original, delta) => MoveArchitectElement(
          storeyId: storeyId,
          elementId: copyId,
          delta: delta,
          carryConnections: false,
        ).apply(original),
      );
    });
  }

  void _previewDuplicateMove(Offset model) {
    final session = _duplicateMove;
    if (session == null) return;
    var delta = ArchitectSnapHelper.precision(
      _project,
    ).inputPoint(session.targetForPointer(model) - session.anchor);
    final snap = ArchitectSnapHelper.snapTranslation(
      project: session.original,
      elementIds: {_duplicateMoveId!, _duplicateSourceId!},
      delta: delta,
      tolerance: (_touchInput ? 12 : 8) / _currentScale,
      magnetic: _magnetEnabled,
      underlay: _currentUnderlayDoc,
      frame: widget.underlayFrame,
      visibility: _underlayLayerVisibility,
    );
    delta = snap.point;
    session.updateTarget(_elementMoveContext, session.anchor + delta);
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    _repaintPreview();
  }

  BimEditSession<ArchitectProject>? _elementMoveSession;
  ArchitectProject? _elementMovePreviewValue;
  Object get _elementMoveContext =>
      (_project, _project.activeStoreyId, _activeTool);
  ArchitectProject? get _elementMoveOriginal => _elementMoveSession?.original;
  set _elementMoveOriginal(ArchitectProject? project) {
    _elementMoveSession?.cancel();
    _elementMoveSession = project == null
        ? null
        : BimEditSession(context: _elementMoveContext, original: project);
  }

  ArchitectProject? get _elementMovePreview => _elementMovePreviewValue;
  set _elementMovePreview(ArchitectProject? project) {
    final normalized = project == null
        ? null
        : ArchitectDimensionChain.resolve(project);
    _elementMovePreviewValue = normalized;
    if (normalized != null) {
      _elementMoveSession?.update(_elementMoveContext, (_) => normalized);
    }
  }

  ArchitectProject? _finishElementMove({required bool changed}) =>
      _elementMoveSession?.finish(_elementMoveContext, changed: changed);
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

  /// Whether a geometric vertex or handle is currently being dragged.
  bool get _isDraggingVertexOrHandle =>
      _isHandleEngaged ||
      _duplicateMove != null ||
      _polygonEditor.active ||
      _draggingElementId != null ||
      _draggingVertexIndex != null ||
      _zoneTool.isExtruding ||
      _zoneTool.isMovingZone ||
      _zoneMoveStartPoint != null ||
      _axisTool.isDraggingHandle ||
      _axisTool.isMovingAxis ||
      _axisTool.isOffsettingWithDrag ||
      _wallEndpointOriginal != null ||
      _groupDragIds.isNotEmpty;

  /// Whether gestures should be captured exclusively by the tool instead of panning.
  bool get _isActivelyDraggingHandle =>
      _draftCancelPointer != null ||
      _isDraggingVertexOrHandle ||
      _wallCutIds.isNotEmpty ||
      _wallExtendId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCanvasPreference());
    _modelCommands =
        widget.commandController ??
        ArchitectCommandController(
          widget.initialProject ??
              ArchitectProject.starterWithCatalog(
                name: widget.bimProject?.name ?? 'Architectural Project',
                storeyCount: widget.bimProject?.storeys.length ?? 2,
              ),
        );

    _commands = ArchitectWorkspaceViewController(_modelCommands);
    _commands.addListener(_onModelChanged);
    unawaited(_loadWorkspacePreferences());

    _restoreWallType();
    unawaited(_loadWallTypePreference());

    _zoneTool = ArchitectZoneTool()..addListener(_repaintPreview);

    _axisTool = ArchitectGridAxisTool()..addListener(_repaintPreview);

    _elementTool = ArchitectElementTool()..addListener(_repaintPreview);

    _roofTool = ArchitectRoofTool()..addListener(_repaintPreview);
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

  bool _initializedDefaultProjectName = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedDefaultProjectName) {
      _initializedDefaultProjectName = true;
      if (widget.initialProject == null && widget.bimProject == null) {
        if (_project.name == 'Architectural Project' ||
            _project.name == 'Архитектурен проект') {
          _commands.restore(
            _project.copyWith(name: context.l10n.architectDefaultProjectName),
          );
        }
      }
    }
  }


  Future<void> _loadAttachedBimProject() async {
    final loaded = await BimProjectLibraryService.instance.loadArchitectProject(
      widget.bimProject!.id,
    );
    if (loaded != null && mounted) {
      setState(() {
        _commands.restore(loaded);
        _restoreWallType();
      });
      _initTransform();
    }
  }

  void _initTransform() {
    var bounds = ArchitectSceneGeometry.projectBounds(_project);
    final viewBounds = _workspaceViewBounds;
    if (viewBounds != null) {
      bounds = bounds == Rect.zero ? viewBounds : bounds.expandToInclude(viewBounds);
    }
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
    _commands.dispose();
    if (widget.commandController == null) _modelCommands.dispose();
    _zoneTool.dispose();
    _axisTool.dispose();
    _elementTool.dispose();
    _roofTool.dispose();
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
      defaultName: _activeZoneCategory.localizedName(l10n),
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
    if (_draftOverlayContains(event.localPosition)) {
      _draftCancelPointer = event.pointer;
      return;
    }
    if (_radialMenuScreenPosition != null) {
      setState(() => _radialMenuScreenPosition = null);
    }
    _touchInput = event.kind == PointerDeviceKind.touch;
    _handlePointerDown = event.localPosition;
    _handleMoved = false;
    _isHandleEngaged = false;

    final rawModel = _screenToModel(event.localPosition);
    if (_activeTool == ArchitectTool.dimension &&
        (_dimensionChainMode || _dimensionPlacing) &&
        _effectiveSelection.isEmpty) {
      return;
    }
    if (_activeTool == ArchitectTool.axis && !_axisTool.isDrafting) {
      final wall = _wallForAxis(rawModel);
      final axis = _axisTool.getSelectedAxis(_project);
      if (wall != null &&
          (axis == null ||
              !axis.isParallelTo(
                StructuralGridAxis(
                  id: 'wall',
                  name: '',
                  start: wall.coreCenterStart,
                  end: wall.coreCenterEnd,
                ),
                toleranceRad: 1e-6,
              ) ||
              (axis.projectPoint(wall.coreCenterStart) - wall.coreCenterStart)
                      .distance >
                  1e-6)) {
        return;
      }
    }
    if (_duplicateMove != null) {
      _duplicateMove!.grabAt(rawModel);
      _isHandleEngaged = true;
      return;
    }
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
    if (_moveSelection ||
        (_activeTool != ArchitectTool.select && _multiSelect)) {
      final id = _hitSelection(rawModel);
      if (_moveSelection && id != null && _effectiveSelection.contains(id)) {
        _groupDragIds = _effectiveSelection;
        _draggingElementId = id;
        _elementMoveStart = rawModel;
        _elementMoveDelta = Offset.zero;
        _elementMoveOriginal = _project;
        _elementMovePreview = _project;
        _isHandleEngaged = true;
        return;
      }
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

    // Midpoint handle check for selected wall (extrusion / step move)
    if (_selectedWall != null && _wallCutIds.isEmpty && _wallExtendId == null) {
      final wall = _selectedWall!;
      final mid = (wall.startPoint + wall.endPoint) / 2;
      final midTol = math.min(16 / _currentScale, 0.35);
      if ((rawModel - mid).distance <= midTol) {
        _draggingElementId = wall.id;
        _elementMoveStart = rawModel;
        _elementMoveDelta = Offset.zero;
        _elementMoveOriginal = _project;
        _elementMovePreview = _project;
        _isHandleEngaged = true;
        HapticFeedback.mediumImpact();
        ArchitectLogger.log(
          'HANDLE',
          'Wall ${wall.id} midpoint extrusion engaged',
        );
        return;
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
        (_moveSelection ||
            _activeTool != ArchitectTool.select ||
            _project.activeStorey.dimensions.any(
              (d) => _effectiveSelection.contains(d.id),
            )) &&
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
    if (_draftCancelPointer == event.pointer) return;
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
    if (_draftCancelPointer != null) return;
    if (!_canPlaceWithMarker) return;
    if (_effectiveSelection.isNotEmpty &&
        _wallCutIds.isEmpty &&
        _wallExtendId == null) {
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

  ArchitectOpeningPlacementResult? get _openingPlacementPreview {
    final raw = _cursorModel;
    if (raw == null ||
        _effectiveSelection.isNotEmpty ||
        _isActivelyDraggingHandle ||
        (_activeTool != ArchitectTool.door &&
            _activeTool != ArchitectTool.window)) {
      return null;
    }
    final width = _activeTool == ArchitectTool.door
        ? _doorWidth
        : _elementTool.windowWidth;
    return ArchitectOpeningPlacement.resolve(
      walls: _project.activeStorey.walls,
      rawPoint: raw,
      openingWidth: width,
      magnetic: _magnetEnabled,
    );
  }

  ArchitectDoor? get _doorPreview {
    if (_activeTool != ArchitectTool.door) return null;
    final preview = _openingPlacementPreview;
    if (preview == null) return null;
    final activeStyle =
        _elementTool.activeDoorStyle ??
        FenestrationLibraryService.instance.activeDoorStyle;
    return ArchitectDoor(
      id: 'preview_door',
      wallId: preview.wall.id,
      offsetRatio: preview.offsetRatio,
      width: _doorWidth,
      height: _doorHeight,
      sillHeight: _doorSill,
      isHingeLeft: _isHingeLeft,
      openInward: preview.openInward,
      specId: '$_doorSpecCounter',
      uuid: 'preview_door',
      styleId: activeStyle.id,
      style: activeStyle,
    );
  }

  ArchitectWindow? get _windowPreview {
    if (_activeTool != ArchitectTool.window) return null;
    final preview = _openingPlacementPreview;
    if (preview == null) return null;
    final activeStyle =
        _elementTool.activeWindowStyle ??
        FenestrationLibraryService.instance.activeWindowStyle;
    return ArchitectWindow(
      id: 'preview_window',
      wallId: preview.wall.id,
      offsetRatio: preview.offsetRatio,
      width: _elementTool.windowWidth,
      height: _elementTool.windowHeight,
      sillHeight: _elementTool.windowSill,
      specId: 'W',
      uuid: 'preview_window',
      styleId: activeStyle.id,
      style: activeStyle,
    );
  }

  Offset? get _placementPreviewTarget {
    final raw = _cursorModel;
    if (raw != null &&
        (_activeTool == ArchitectTool.door ||
            _activeTool == ArchitectTool.window)) {
      final preview = _openingPlacementPreview;
      if (preview != null) return preview.centerPoint;
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

  ArchitectSnapResult _snapDimensionPoint(Offset raw, {Offset? anchor}) {
    final snap = anchor == null
        ? ArchitectSnapHelper.snapFree(
            rawPoint: raw,
            project: _project,
            tolerance: (_touchInput ? 14 : 10) / _currentScale,
            magnetic: _magnetEnabled,
            alignment: true,
            excludeWallAxes: true,
            underlay: _currentUnderlayDoc,
            frame: widget.underlayFrame,
            visibility: _underlayLayerVisibility,
          )
        : ArchitectSnapHelper.snapWithAnchor(
            rawPoint: raw,
            anchor: anchor,
            project: _project,
            tolerance: (_touchInput ? 14 : 10) / _currentScale,
            magnetic: _magnetEnabled,
            alignment: true,
            excludeWallAxes: true,
            underlay: _currentUnderlayDoc,
            frame: widget.underlayFrame,
            visibility: _underlayLayerVisibility,
          );
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    return snap;
  }

  ({double offset, String? label, List<(Offset, Offset)> guides})
      _snapDimensionOffset(
    ArchitectDimension dimension,
    double rawOffset, {
    String? excludedId,
  }) {
    final u = dimension.unitVector;
    final n = dimension.normal;
    final p0 = dimension.startPoint;
    final scale = _currentScale;
    final tolerance = (14 / scale).clamp(0.04, 0.12);

    final targets = <({double pos, String name})>[];

    // 1. Baseline of this dimension (measured geometry):
    targets.add((pos: 0.0, name: 'baseline'));

    // 2. Parallel dimensions in the active storey:
    for (final other in _project.activeStorey.dimensions) {
      if (other.id == dimension.id || other.id == excludedId) continue;
      final dotDir =
          (other.unitVector.dx * u.dx + other.unitVector.dy * u.dy).abs();
      if (dotDir > 0.98) {
        final y = ArchitectDimensionChain.dot(other.lineStart - p0, n);
        targets.add((pos: y, name: 'dimension'));
      }
    }

    // 3. Parallel walls in the active storey:
    for (final wall in _project.activeStorey.walls) {
      final dotDir =
          (wall.unitVector.dx * u.dx + wall.unitVector.dy * u.dy).abs();
      if (dotDir > 0.98) {
        final dStart = wall.startPoint - p0;
        final alongStart = dStart.dx * u.dx + dStart.dy * u.dy;
        final dEnd = wall.endPoint - p0;
        final alongEnd = dEnd.dx * u.dx + dEnd.dy * u.dy;
        final minAlong = math.min(alongStart, alongEnd);
        final maxAlong = math.max(alongStart, alongEnd);
        if (maxAlong < -2.0 || minAlong > dimension.length + 2.0) continue;

        final nWall = wall.normalVector * (wall.thickness / 2);
        final outer1 = wall.centerStart + nWall;
        final outer2 = wall.centerStart - nWall;
        targets.add((
          pos: ArchitectDimensionChain.dot(outer1 - p0, n),
          name: 'wall',
        ));
        targets.add((
          pos: ArchitectDimensionChain.dot(outer2 - p0, n),
          name: 'wall',
        ));

        if (wall.hasInsulation) {
          final nCore = wall.normalVector * (wall.coreThickness / 2);
          final core1 = wall.coreCenterStart + nCore;
          final core2 = wall.coreCenterStart - nCore;
          targets.add((
            pos: ArchitectDimensionChain.dot(core1 - p0, n),
            name: 'wallCore',
          ));
          targets.add((
            pos: ArchitectDimensionChain.dot(core2 - p0, n),
            name: 'wallCore',
          ));
        }
      }
    }

    double? bestOffset;
    double bestDiff = tolerance;
    String? bestLabel;
    List<(Offset, Offset)> bestGuides = [];

    for (final target in targets) {
      for (final dist in const [0.30, 0.40]) {
        for (final sign in const [1.0, -1.0]) {
          final candidate = target.pos + sign * dist;
          final diff = (rawOffset - candidate).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestOffset = candidate;
            final cm = (dist * 100).round();
            bestLabel = '$cm cm';

            final dimLinePt = p0 + n * candidate;
            final targetLinePt = p0 + n * target.pos;
            bestGuides = [
              (targetLinePt, dimLinePt),
              (dimLinePt, dimLinePt + u * dimension.length),
            ];
          }
        }
      }
    }

    if (bestOffset != null) {
      return (offset: bestOffset, label: bestLabel, guides: bestGuides);
    }
    return (offset: rawOffset, label: null, guides: <(Offset, Offset)>[]);
  }

  Offset _snapMovingElements(Offset delta, Set<String> ids) {
    if (_magnetEnabled &&
        ids.isNotEmpty &&
        ids.every(
          (id) => _elementMoveOriginal!.gridAxes.any((a) => a.id == id),
        )) {
      ({Offset delta, (Offset, Offset) guide})? best;
      for (final axis in _elementMoveOriginal!.gridAxes.where(
        (a) => ids.contains(a.id),
      )) {
        final candidate = ArchitectAxisGeometry.snapToWall(
          axis: axis,
          delta: delta,
          walls: _elementMoveOriginal!.activeStorey.walls,
          tolerance: math.min(12 / _currentScale, .20),
        );
        if (candidate != null &&
            (best == null ||
                (candidate.delta - delta).distance <
                    (best.delta - delta).distance)) {
          best = candidate;
        }
      }
      if (best != null) {
        _activeSnapLabel = 'Center';
        _activeMagneticGuides = [best.guide];
        return best.delta;
      }
    }
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

  ArchitectRoofPlane? get _selectedRoof {
    final id = _selectedElementId;
    if (id == null || _effectiveSelection.length > 1) return null;
    for (final roof in _project.activeStorey.roofs) {
      if (roof.id == id) return roof;
    }
    return null;
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
    for (final roof in _project.activeStorey.roofs) {
      if (roof.id == id) return roof.points;
    }
    for (final zone in _project.activeStorey.zones) {
      if (zone.id == id) return zone.polygon;
    }
    for (final opening in _project.activeStorey.openings) {
      if (opening.id == id) return opening.boundary;
    }
    return null;
  }

  void _updatePointerPreview(Offset screenPosition) {
    if (_pendingShape != null) return;
    final rawModel = _screenToModel(screenPosition);
    if (_duplicateMove != null) {
      _previewDuplicateMove(rawModel);
      return;
    }
    _cursorModel = rawModel;
    if (_activeTool == ArchitectTool.dimension &&
        (_dimensionChainMode || _dimensionPlacing) &&
        _dimensionAnchors.isNotEmpty &&
        !_isActivelyDraggingHandle) {
      final draft = _dimensionDraft;
      if (_dimensionPlacing && draft != null) {
        final rawOffset = ArchitectDimensionChain.dot(
          rawModel - draft.startPoint,
          draft.normal,
        );
        final snap = _snapDimensionOffset(draft, rawOffset);
        _dimensionOffset = snap.offset;
        _activeSnapLabel = snap.label;
        _activeMagneticGuides = snap.guides;
      }
      _repaintPreview();
      return;
    }
    if (_activeTool == ArchitectTool.dimension && !_dimensionPlacing) {
      final snap = _snapDimensionPoint(rawModel, anchor: _draftStart);
      _cursorModel = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _activeMagneticGuides = snap.magneticGuides;
      if (_draftStart != null) {
        _draftEnd = snap.point;
      }
      _repaintPreview();
      return;
    }
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
      delta = _parallelDelta(delta, _groupDragIds);
      if (_magnetEnabled &&
          _elementMoveOriginal!.activeStorey.walls.any(
            (w) => _groupDragIds.contains(w.id),
          )) {
        final alignment = ArchitectWallAlignment.move(
          _elementMoveOriginal!.activeStorey.walls,
          _groupDragIds,
          delta,
          _currentScale,
          parallelOnly: _wallParallelMove,
        );
        delta = alignment.$1;
        _activeMagneticGuides = alignment.$2;
      } else {
        delta = _snapMovingElements(delta, _groupDragIds);
      }
      delta = _parallelDelta(delta, _groupDragIds);
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
      ArchitectWall? hostedOpeningWall;
      double? hostedOpeningRatio;
      double? hostedOpeningWidth;
      if (selectedWall == null) {
        for (final w in _elementMoveOriginal!.activeStorey.walls) {
          for (final d in w.doors) {
            if (d.id == _draggingElementId) {
              hostedOpeningWall = w;
              hostedOpeningRatio = d.offsetRatio;
              hostedOpeningWidth = d.width;
              break;
            }
          }
          if (hostedOpeningWall != null) break;
          for (final win in w.windows) {
            if (win.id == _draggingElementId) {
              hostedOpeningWall = w;
              hostedOpeningRatio = win.offsetRatio;
              hostedOpeningWidth = win.width;
              break;
            }
          }
          if (hostedOpeningWall != null) break;
        }
      }
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
        final snapDelta = _snapMovingElements(delta, {selectedWall.id});
        if ((snapDelta - delta).distance > 1e-4) {
          delta = snapDelta;
        } else {
          _activeMagneticGuides = [..._activeMagneticGuides, ...alignment.$2];
        }
      } else if (hostedOpeningWall != null) {
        if ((rawModel - _elementMoveStart!).distance < 1e-6) {
          delta = Offset.zero;
          _activeSnapLabel = null;
          _activeMagneticGuides = [];
        } else {
          final origCenter =
              hostedOpeningWall.centerStart +
              (hostedOpeningWall.centerEnd - hostedOpeningWall.centerStart) *
                  hostedOpeningRatio!;
          final placement = ArchitectOpeningPlacement.resolve(
            walls: _elementMoveOriginal!.activeStorey.walls,
            rawPoint: origCenter + (rawModel - _elementMoveStart!),
            openingWidth: hostedOpeningWidth!,
            excludeOpeningId: _draggingElementId,
            fixedHostWall: hostedOpeningWall,
            magnetic: _magnetEnabled,
          );
          if (placement != null) {
            delta = placement.centerPoint - origCenter;
            _activeSnapLabel = placement.isModularSnap
                ? context.l10n.architectOpeningModularSnap(
                    (placement.stepMeters * 100).round(),
                  )
                : placement.snapLabel;
          }
          _activeMagneticGuides = [];
        }
      } else {
        delta = _snapMovingElements(delta, {_draggingElementId!});
      }
      delta = _parallelDelta(delta, {_draggingElementId!});
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
        final dimension = _elementMoveOriginal!.activeStorey.dimensions
            .where((d) => d.id == _draggingElementId)
            .firstOrNull;
        if (dimension != null) {
          final dotDeltaNormal =
              delta.dx * dimension.normal.dx + delta.dy * dimension.normal.dy;
          final rawOffset = dimension.offsetDistance + dotDeltaNormal;
          final snap = _snapDimensionOffset(
            dimension,
            rawOffset,
            excludedId: dimension.id,
          );
          final snappedDelta =
              dimension.normal * (snap.offset - dimension.offsetDistance);
          delta = snappedDelta;
          _activeSnapLabel = snap.label;
          _activeMagneticGuides = snap.guides;
        }
        try {
          _elementMovePreview = MoveArchitectElement(
            storeyId: _project.activeStorey.id,
            elementId: _draggingElementId!,
            delta: delta,
          ).apply(_elementMoveOriginal!);
        } on ArgumentError {
          _elementMoveDelta = null;
        }
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
      _axisTool.updateMoving(rawModel, _project.gridAxes, _currentScale,
        walls: _project.activeStorey.walls, magnetic: _magnetEnabled);
      _activeMagneticGuides = _axisTool.moveWallGuide == null
          ? [] : [_axisTool.moveWallGuide!];
      _activeSnapLabel = _axisTool.moveWallGuide == null ? null : 'Center';
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

    // 7. Slab or Roof drafting candidate
    if (_activeTool == ArchitectTool.slab &&
        _elementTool.slabDraftPoints.isNotEmpty) {
      _elementTool.updateSlabCandidate(_resolveSlabPoint(rawModel));
      _cursorModel = _elementTool.slabCandidatePoint;
    } else if (_activeTool == ArchitectTool.roof) {
      final pt = _resolveRoofPoint(rawModel);
      _roofTool.updateCandidate(
        pt,
        snapLabel: _activeSnapLabel,
        magneticGuides: _activeMagneticGuides,
      );
      _cursorModel = pt;
    } else if (_activeTool == ArchitectTool.door ||
        _activeTool == ArchitectTool.window) {
      final preview = _openingPlacementPreview;
      _activeSnapLabel = preview == null
          ? null
          : preview.isModularSnap
          ? context.l10n.architectOpeningModularSnap(
              (preview.stepMeters * 100).round(),
            )
          : preview.snapLabel;
      _activeMagneticGuides = [];
    } else if (_canPlaceWithMarker) {
      final snap = _snapElement(rawModel);
      _cursorModel = snap.point;
      _activeSnapLabel = snap.snapLabel;
    }
    if (_wallJoinSourceId != null) {
      _wallJoinPointer = rawModel;
    }
    _repaintPreview();
  }

  Offset _resolveRoofPoint(Offset raw) {
    final points = _roofTool.draftPoints;
    if (_roofTool.drawMode == RoofDrawMode.polygon && points.length >= 3) {
      if ((raw - points.first).distance <= math.min(18 / _currentScale, 0.35)) {
        _activeSnapLabel = context.l10n.architectZonePointSnapStart;
        _activeMagneticGuides = [];
        return points.first;
      }
      final closure =
          BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
            points: points,
            raw: raw,
            tolerance: math.max(16 / _currentScale, 0.30),
          );
      if (closure.isSnapped) {
        _activeSnapLabel = context.l10n.snapAlignPoint1;
        _activeMagneticGuides = closure.magneticGuides;
        return closure.point;
      }
    }
    final anchor = _roofTool.drawMode == RoofDrawMode.polygon
        ? points.lastOrNull
        : null;
    final snap = _snapElement(raw, anchor: anchor);
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    return snap.point;
  }

  Offset _resolveSlabPoint(Offset raw) {
    final points = _elementTool.slabDraftPoints;
    if (points.length >= 3) {
      if ((raw - points.first).distance <= math.min(16 / _currentScale, .20)) {
        _activeSnapLabel = context.l10n.architectZonePointSnapStart;
        _activeMagneticGuides = [];
        return points.first;
      }
      final closure =
          BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
            points: points,
            raw: raw,
            tolerance: math.max(16 / _currentScale, 0.30),
          );
      if (closure.isSnapped) {
        _activeSnapLabel = context.l10n.snapAlignPoint1;
        _activeMagneticGuides = closure.magneticGuides;
        return closure.point;
      }
    }
    final snap = _snapElement(raw, anchor: points.lastOrNull);
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    return snap.point;
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (_draftOverlayContains(event.localPosition)) return;
    _touchInput = false;
    _updatePointerPreview(event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_draftCancelPointer == event.pointer) {
      _draftCancelPointer = null;
      return;
    }
    if (_controlTrimClick) {
      _controlTrimClick = false;
      return;
    }
    if (_isDraggingVertexOrHandle && !_handleMoved) {
      if (_polygonEditId != null) {
        _selectPolygonEdge(_screenToModel(event.localPosition));
      }
      _cancelActiveDrags();
      if (_polygonEditId == null && !_moveSelection) {
        _selectAt(_screenToModel(event.localPosition), toggle:
            _multiSelect || _activeTool == ArchitectTool.select ||
            HardwareKeyboard.instance.isShiftPressed ||
            HardwareKeyboard.instance.isControlPressed);
      }
      _repaintPreview();
      return;
    }
    // Resolve again at release: touch has no hover and the final event can
    // differ from the last move. Preview and commit share the same resolver.
    _updatePointerPreview(_placementPosition(event.localPosition));
    if (_wallCutIds.isNotEmpty && _wallCutStart != null) {
      final modelPos = _screenToModel(_placementPosition(event.localPosition));
      if ((_wallCutStart! - modelPos).distance > 15 / _currentScale) {
        final Offset cutStart;
        final Offset cutEnd;
        if (_wallCutConfirmedDir != null) {
          final delta = modelPos - _wallCutStart!;
          final cutDir = _snappedCutDirection(delta);
          final extend = math.max(delta.distance + 50 / _currentScale, 10.0);
          cutStart = _wallCutStart! - cutDir * extend;
          cutEnd = _wallCutStart! + cutDir * extend;
        } else {
          cutStart = _wallCutStart!;
          cutEnd = modelPos;
        }
        _executeWallEdit(
          CutArchitectWalls(
            storeyId: _project.activeStoreyId,
            wallIds: Set.of(_wallCutIds),
            start: cutStart,
            end: cutEnd,
          ),
        );
        setState(() {
          _wallCutStart = null;
          _wallCutConfirmedDir = null;
          _wallCutIds = {};
        });
        _repaintPreview();
        return;
      }
    }
    if (_isDraggingVertexOrHandle) {
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
    _draftCancelPointer = null;
    _duplicateMove?.cancel();
    _duplicateMove = null;
    _duplicateMoveId = null;
    _duplicateSourceId = null;
    _polygonEditor.cancel();
    _radialMenuScreenPosition = null;
    _wallJoinSourceId = null;
    _wallJoinPointer = null;
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
    if (_duplicateMove != null) {
      final id = _duplicateMoveId;
      final preview = _duplicateMove!.finish(_elementMoveContext);
      _cancelActiveDrags();
      if (preview != null) {
        _commands.commit(preview);
        setState(() {
          _selectedElementId = id;
          _selectedZoneId = null;
        });
        _saveBiMProjectIfAttached();
      }
      return;
    }
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
    if (_groupDragIds.isNotEmpty ||
        _wallEndpointOriginal != null ||
        _draggingElementId != null) {
      final preview = _finishElementMove(
        changed:
            _wallEndpointOriginal != null ||
            (_elementMoveDelta?.distance ?? 0) > 1e-9,
      );
      _cancelActiveDrags();
      if (preview != null) {
        _commands.commit(preview);
        _saveBiMProjectIfAttached();
      }
      return;
    }
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

  bool _selectDraftingElement(Offset point) {
    final id = _hitSelection(point);
    if (id == null) return false;
    final wall = _project.activeStorey.walls
        .where((w) => w.id == id)
        .firstOrNull;
    if (wall != null &&
        !wall.containsPoint(
          point,
          tolerance: math.min(6 / _currentScale, .08),
        )) {
      return false;
    }
    return _selectAt(point);
  }

  void _handleTap(Offset rawModel) {
    if (_pendingShape != null || _polygonDistanceOpen) return;

    // A rapid second wall tap while drafting must not invoke selection's double tap.
    if (_activeTool == ArchitectTool.dimension &&
        (_dimensionChainMode || _dimensionPlacing) &&
        !_multiSelect && _effectiveSelection.isEmpty) {
      _handleDimensionChainTap(rawModel);
      return;
    }

    final candidates = _selectionCandidates(rawModel);
    final now = DateTime.now();
    final isDoubleTap = candidates.length <= 1 &&
        _lastTapTime != null &&
        _lastTapPos != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 380) &&
        (rawModel - _lastTapPos!).distance * _currentScale < 25;
    _lastTapTime = now;
    _lastTapPos = rawModel;

    if (isDoubleTap && _activeTool != ArchitectTool.select && !_multiSelect) {
      final hitId = _hitSelection(rawModel);
      if (hitId != null) {
        final storey = _project.activeStorey;
        if (storey.walls.any((w) => w.id == hitId)) {
          final chain = _elementTool.findConnectedWallChain(storey, hitId);
          if (chain.isNotEmpty) {
            setState(() {
              _selectionIds
                ..clear()
                ..addAll(chain);
              _selectedElementId = hitId;
              _selectedZoneId = null;
              _multiSelect = true;
            });
            HapticFeedback.mediumImpact();
            return;
          }
        } else if (storey.columns.any((c) => c.id == hitId)) {
          setState(() {
            _selectionIds
              ..clear()
              ..addAll(storey.columns.map((c) => c.id));
            _selectedElementId = hitId;
            _selectedZoneId = null;
            _multiSelect = true;
          });
          HapticFeedback.mediumImpact();
          return;
        } else if (storey.beams.any((b) => b.id == hitId)) {
          setState(() {
            _selectionIds
              ..clear()
              ..addAll(storey.beams.map((b) => b.id));
            _selectedElementId = hitId;
            _selectedZoneId = null;
            _multiSelect = true;
          });
          HapticFeedback.mediumImpact();
          return;
        } else if (storey.slabs.any((s) => s.id == hitId)) {
          setState(() {
            _selectionIds
              ..clear()
              ..addAll(storey.slabs.map((s) => s.id));
            _selectedElementId = hitId;
            _selectedZoneId = null;
            _multiSelect = true;
          });
          HapticFeedback.mediumImpact();
          return;
        } else if (storey.roofs.any((r) => r.id == hitId)) {
          setState(() {
            _selectionIds
              ..clear()
              ..addAll(storey.roofs.map((r) => r.id));
            _selectedElementId = hitId;
            _selectedZoneId = null;
            _multiSelect = true;
          });
          HapticFeedback.mediumImpact();
          return;
        }
      }
    }
    if (_polygonEditId != null) {
      _selectPolygonEdge(rawModel);
      return;
    }
    if (_wallCutIds.isNotEmpty) {
      if (!_wallCutStroke) {
        final span = _trimSpanAt(rawModel);
        if (span != null) {
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
      }
      if (_wallCutStart == null) {
        // Step 1: Click 1 confirms the surface (or sets first point in space)
        final surface = _findNearestSurface(rawModel);
        setState(() {
          _wallCutStart = surface?.anchor ?? rawModel;
          _wallCutConfirmedDir = surface?.direction;
        });
        return;
      } else {
        // Step 2: Click 2 determines cut direction and slices
        final Offset cutStart;
        final Offset cutEnd;
        if (_wallCutConfirmedDir != null) {
          final delta = rawModel - _wallCutStart!;
          final cutDir = _snappedCutDirection(delta);
          final extend = math.max(delta.distance + 50 / _currentScale, 10.0);
          cutStart = _wallCutStart! - cutDir * extend;
          cutEnd = _wallCutStart! + cutDir * extend;
        } else {
          cutStart = _wallCutStart!;
          cutEnd = rawModel;
        }

        _executeWallEdit(
          CutArchitectWalls(
            storeyId: _project.activeStoreyId,
            wallIds: Set.of(_wallCutIds),
            start: cutStart,
            end: cutEnd,
          ),
        );
        setState(() {
          _wallCutStart = null;
          _wallCutConfirmedDir = null;
          _wallCutIds = {};
        });
        return;
      }
    }
    if (_wallJoinSourceId != null) {
      final sourceId = _wallJoinSourceId!;
      final hit = _hitSelection(rawModel);
      final hitWall = _project.activeStorey.walls
          .where((w) => w.id == hit && w.id != sourceId)
          .firstOrNull;
      if (hitWall != null) {
        try {
          _commands.execute(
            JoinArchitectWalls(
              storeyId: _project.activeStoreyId,
              wallIds: {sourceId, hitWall.id},
            ),
          );
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          setState(() {
            _wallJoinSourceId = null;
            _wallJoinPointer = null;
            _selectionIds.clear();
            _selectedElementId = null;
            _selectedZoneId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectWallJoinSuccess),
              duration: const Duration(seconds: 2),
            ),
          );
        } on ArgumentError {
          _operationError();
          setState(() {
            _wallJoinSourceId = null;
            _wallJoinPointer = null;
          });
        }
        return;
      }
      if (hit == sourceId) {
        setState(() {
          _wallJoinSourceId = null;
          _wallJoinPointer = null;
        });
        return;
      }
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
      _selectAt(rawModel, toggle: true);
      return;
    }

    if (_draftStart == null &&
        !_axisTool.isDrafting &&
        !_zoneTool.isDrafting &&
        !_roofTool.isDrafting &&
        _elementTool.slabDraftPoints.isEmpty &&
        !(_touchInput && _placingWithHold) &&
        _effectiveSelection.isEmpty &&
        _activeTool != ArchitectTool.select &&
        !(_activeTool == ArchitectTool.axis &&
            _wallForAxis(rawModel) != null) &&
        _selectDraftingElement(rawModel)) {
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

    // Active selection tap handling: toggle in multi-select or select tool, replace in single-select, or cancel on empty space
    if (_effectiveSelection.isNotEmpty) {
      // If a single roof plane is selected and the user taps near one of its edges,
      // switch its eaves edge directly with 1 tap!
      final selectedRoof = _selectedRoof;
      if (selectedRoof != null && !_multiSelect) {
        final edgeIdx = ArchitectRoofTool.hitTestEdgeIndex(
          selectedRoof,
          rawModel,
          tolerance: math.min(18.0 / _currentScale, 0.35),
        );
        if (edgeIdx != null && edgeIdx != selectedRoof.safeEavesEdgeIndex) {
          _commands.execute(
            UpdateArchitectRoofPlane(
              storeyId: _project.activeStoreyId,
              roof: selectedRoof.copyWith(eavesEdgeIndex: edgeIdx),
            ),
          );
          _saveBiMProjectIfAttached();
          HapticFeedback.selectionClick();
          return;
        }
      }

      final shouldToggle = _multiSelect ||
          _activeTool == ArchitectTool.select ||
          HardwareKeyboard.instance.isShiftPressed ||
          HardwareKeyboard.instance.isControlPressed;
      final hit = _selectAt(rawModel, toggle: shouldToggle);
      if (!hit) {
        _clearSelection();
      }
      return;
    }

    if (_activeTool == ArchitectTool.select) {
      _selectAt(rawModel, toggle: true);
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
        magnetic: _magnetEnabled,
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

    // 9b. In Roof tool
    if (_activeTool == ArchitectTool.roof) {
      final pt = _resolveRoofPoint(rawModel);
      final created = _roofTool.addDraftPoint(
        pt,
        storey: _project.activeStorey,
        closeRadius: math.min(18.0 / _currentScale, 0.35),
      );
      if (created != null) {
        setState(() {
          _commands.execute(
            CreateArchitectRoofPlane(
              storeyId: _project.activeStoreyId,
              roof: created,
            ),
          );
          _selectionIds
            ..clear()
            ..add(created.id);
          _selectedElementId = created.id;
          _activeMagneticGuides = [];
          _activeSnapLabel = null;
        });
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
      } else {
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
        if ((_snapElement(rawModel, anchor: _draftStart).point - _draftStart!).distance < .05) return;
        final stair = _stairAt(
          _draftStart!,
          _snapElement(rawModel, anchor: _draftStart).point,
          id: ArchitectElementId.next('stair'),
        );
        if (ArchitectStairRules.check(
              stair,
            ).any((c) => c.state == StairCheckState.error) &&
            !stair.design!.isDraft) {
          _showStairProperties(stair: stair, create: true);
          return;
        }
        _commands.execute(
          PutArchitectStair(
            storeyId: _project.activeStoreyId,
            stair: stair,
            create: true,
          ),
        );
        setState(() {
          _draftStart = null;
          _draftEnd = null;
        });
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
      }
      return;
    }

    // 12. In Dimension tool
    if (_activeTool == ArchitectTool.dimension) {
      if (_draftStart == null) {
        final snap = _snapDimensionPoint(rawModel);
        setState(() {
          _singleDimensionStartAnchor = _dimensionPointAnchor(snap.point);
          _draftStart = snap.point;
          _draftEnd = snap.point;
        });
      } else {
        final snap = _snapDimensionPoint(rawModel, anchor: _draftStart);
        if ((snap.point - _draftStart!).distance >= .001) {
          setState(() {
            _dimensionAnchors.addAll([
              _singleDimensionStartAnchor ??
                  ArchitectDimensionAnchor(point: _draftStart!),
              _dimensionPointAnchor(snap.point),
            ]);
            _dimensionDirection = snap.point - _draftStart!;
            _dimensionPlacing = true;
            _singleDimensionStartAnchor = null;
            _draftStart = null;
            _draftEnd = null;
          });
          HapticFeedback.selectionClick();
        } else {
          _operationError();
        }
      }
      return;
    }

    // 13. In Level Marker tool
    if (_activeTool == ArchitectTool.level) {
      final point = _snapElement(rawModel).point;
      final (updatedStorey, _) = _elementTool.placeElevationMarker(
        storey: _project.activeStorey,
        point: point,
        elevation: _commands.isPlan ? _project.activeStorey.elevation : -point.dy,
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
      followStoreyHeight: _activeWallType?.isParapet != true,
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

  // === SECTION: WALL SPLIT & SURFACE DETECTION ===
  _ArchitectSurfaceHit? _findNearestSurface(Offset rawPoint) {
    _ArchitectSurfaceHit? bestHit;
    double bestDist = 30 / _currentScale;

    void testSegment(Offset p1, Offset p2) {
      final seg = p2 - p1;
      final segLen = seg.distance;
      if (segLen < 0.001) return;
      final proj = BimLineGeometry.closest(rawPoint, p1, p2);
      final dist = (rawPoint - proj).distance;
      if (dist < bestDist) {
        bestDist = dist;
        final dir = seg / segLen;
        final normal = Offset(-dir.dy, dir.dx);
        bestHit = _ArchitectSurfaceHit(
          anchor: proj,
          direction: dir,
          normal: normal,
          distance: dist,
        );
      }
    }

    final storey = _project.activeStorey;
    // 1. Walls: prioritize selected walls if any, or all walls
    final wallsToTest = _wallCutIds.isNotEmpty
        ? storey.walls.where((w) => _wallCutIds.contains(w.id))
        : storey.walls;
    for (final wall in wallsToTest) {
      testSegment(wall.startPoint, wall.endPoint);
      final corners = wall.polygonCorners;
      for (var i = 0; i < corners.length; i++) {
        testSegment(corners[i], corners[(i + 1) % corners.length]);
      }
    }

    // 2. Slabs
    for (final slab in storey.slabs) {
      final poly = slab.polygon;
      for (var i = 0; i < poly.length; i++) {
        testSegment(poly[i], poly[(i + 1) % poly.length]);
      }
    }

    // 3. Grid axes
    for (final axis in _project.gridAxes) {
      testSegment(axis.start, axis.end);
    }

    // 4. Columns
    for (final col in storey.columns) {
      if (col.shape == ColumnShape.rectangular) {
        final halfW = col.width / 2.0;
        final halfD = col.depth / 2.0;
        final angle = col.rotationDeg * math.pi / 180;
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        Offset rot(double lx, double ly) =>
            col.position + Offset(lx * cosA - ly * sinA, lx * sinA + ly * cosA);
        final c1 = rot(-halfW, -halfD);
        final c2 = rot(halfW, -halfD);
        final c3 = rot(halfW, halfD);
        final c4 = rot(-halfW, halfD);
        testSegment(c1, c2);
        testSegment(c2, c3);
        testSegment(c3, c4);
        testSegment(c4, c1);
      }
    }

    // 5. Zones
    for (final zone in storey.zones) {
      final poly = zone.polygon;
      for (var i = 0; i < poly.length; i++) {
        testSegment(poly[i], poly[(i + 1) % poly.length]);
      }
    }

    for (final line in storey.cadPrimitives) {
      if (line.type == CadPrimitiveType.line) {
        testSegment(line.startPoint, line.endPoint);
      }
    }
    for (final beam in storey.beams) {
      testSegment(beam.startPoint, beam.endPoint);
    }

    return bestHit;
  }

  Offset _snappedCutDirection(Offset rawDelta) {
    if (rawDelta.distance < 1e-4) {
      if (_wallCutConfirmedDir != null) {
        return Offset(-_wallCutConfirmedDir!.dy, _wallCutConfirmedDir!.dx);
      }
      return const Offset(0, 1);
    }
    final u = rawDelta / rawDelta.distance;
    if (_wallCutConfirmedDir != null) {
      final sDir = _wallCutConfirmedDir!;
      final nDir = Offset(-sDir.dy, sDir.dx);
      final dotN = u.dx * nDir.dx + u.dy * nDir.dy;
      final dotS = u.dx * sDir.dx + u.dy * sDir.dy;
      if (dotN.abs() >= 0.906) {
        return dotN >= 0 ? nDir : -nDir;
      }
      if (dotS.abs() >= 0.939) {
        return dotS >= 0 ? sDir : -sDir;
      }
      return u;
    } else {
      if (u.dx.abs() >= 0.939) return Offset(u.dx.sign, 0);
      if (u.dy.abs() >= 0.939) return Offset(0, u.dy.sign);
      return u;
    }
  }

  List<ArchitectWallClearance> get _wallClearances {
    final ids = _effectiveSelection;
    if (ids.length != 1 || _wallCutIds.isNotEmpty || _wallExtendId != null) {
      return [];
    }
    final walls = (_elementMovePreview ?? _project).activeStorey.walls;
    final selected = walls.where((w) => ids.contains(w.id));
    if (selected.isEmpty) return [];
    final endpoints = ArchitectWallClearance.endpoints(
      selected.first,
      walls,
      includeParallel: _wallEndpointClearanceId == selected.first.id,
    );
    return [
          ...ArchitectWallClearance.nearest(selected.first, walls).where(
            (gap) => !endpoints.any((end) => end.neighborId == gap.neighborId),
          ),
          ...endpoints,
        ]
        .map(
          (gap) => gap.nearView(
            selected.first,
            walls.firstWhere((w) => w.id == gap.neighborId),
            _viewport.visibleRect,
          ),
        )
        .toList();
  }

  List<ArchitectOpeningClearance> get _selectedOpeningClearances {
    final ids = _effectiveSelection;
    if (ids.length != 1 || _wallCutIds.isNotEmpty || _wallExtendId != null) {
      return const [];
    }
    final targetId = ids.single;
    final walls = (_elementMovePreview ?? _project).activeStorey.walls;
    for (final wall in walls) {
      for (final door in wall.doors) {
        if (door.id == targetId) {
          return ArchitectOpeningClearance.forOpening(
            wall: wall,
            walls: walls,
            openingId: door.id,
            offsetRatio: door.offsetRatio,
            openingWidth: door.width,
          );
        }
      }
      for (final window in wall.windows) {
        if (window.id == targetId) {
          return ArchitectOpeningClearance.forOpening(
            wall: wall,
            walls: walls,
            openingId: window.id,
            offsetRatio: window.offsetRatio,
            openingWidth: window.width,
          );
        }
      }
    }
    return const [];
  }

  List<ArchitectOpeningClearance> get _openingClearances {
    final selected = _selectedOpeningClearances;
    if (selected.isNotEmpty) return selected;
    final preview = _openingPlacementPreview;
    if (preview != null) return preview.clearances;
    return const [];
  }

  bool get _showOpeningClearanceBadges =>
      _openingPlacementPreview != null ||
      (_draggingElementId != null && _selectedOpeningClearances.isNotEmpty);

  Widget _buildWallClearanceOverlay() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (context, child) {
        final clearances = _wallClearances;
        final openingClearances = _draggingElementId == null
            ? _selectedOpeningClearances
            : const <ArchitectOpeningClearance>[];
        if (clearances.isEmpty && openingClearances.isEmpty) {
          return const SizedBox.shrink();
        }
        final walls = (_elementMovePreview ?? _project).activeStorey.walls;
        final body = ArchitectWallNetwork.body(walls);
        if (_viewport.size.width < 104 || _viewport.size.height < 180) {
          return const SizedBox.shrink();
        }
        final available = Rect.fromLTRB(
          8,
          64,
          _viewport.size.width - 8,
          _viewport.size.height - 80,
        );
        final excluded = <Rect>[
          if (_radialMenuScreenPosition != null && _radialMenuItems.isNotEmpty)
            ...ArchitectRadialLayout.compute(
              size: _viewport.size,
              center: _radialMenuScreenPosition!,
              count: _radialMenuItems.length,
              hasTitle: _effectiveSelection.length > 1,
            ).occupied,
        ];
        final placements = <String, Rect>{};
        for (final gap in clearances) {
          final start = _viewport.toScreen(gap.start),
              end = _viewport.toScreen(gap.end);
          final segment = BimLineGeometry.visibleSegment(start, end, available);
          final preferred = segment == null
              ? (start + end) / 2
              : (segment.$1 + segment.$2) / 2;
          final rect = ArchitectClearanceBadgeLayout.place(
            preferred: preferred,
            available: available,
            excluded: excluded,
            intersectsWall: (rect) {
              final modelRect = Rect.fromPoints(
                _viewport.toModel(rect.topLeft),
                _viewport.toModel(rect.bottomRight),
              );
              return Path.combine(
                PathOperation.intersect,
                body,
                Path()..addRect(modelRect),
              ).computeMetrics().isNotEmpty;
            },
          );
          placements[gap.key] = rect;
          excluded.add(rect);
        }
        for (final gap in openingClearances) {
          final start = _viewport.toScreen(gap.start),
              end = _viewport.toScreen(gap.end);
          final segment = BimLineGeometry.visibleSegment(start, end, available);
          final preferred = segment == null
              ? (start + end) / 2
              : (segment.$1 + segment.$2) / 2;
          final rect = ArchitectClearanceBadgeLayout.place(
            preferred: preferred,
            available: available,
            excluded: excluded,
            intersectsWall: (rect) {
              final modelRect = Rect.fromPoints(
                _viewport.toModel(rect.topLeft),
                _viewport.toModel(rect.bottomRight),
              );
              return Path.combine(
                PathOperation.intersect,
                body,
                Path()..addRect(modelRect),
              ).computeMetrics().isNotEmpty;
            },
          );
          placements[gap.key] = rect;
          excluded.add(rect);
        }
        return Stack(
          children: [
            for (final gap in clearances)
              Builder(
                builder: (context) {
                  final rect = placements[gap.key]!;
                  return Positioned.fromRect(
                    rect: rect,
                    child: IgnorePointer(
                      ignoring:
                          _radialMenuScreenPosition != null ||
                          (gap.atStart == null &&
                              _activeTool == ArchitectTool.select &&
                              !_moveSelection),
                      child: Tooltip(
                        message: gap.atStart == null
                            ? context.l10n.architectWallClearance
                            : context.l10n.architectWallEndpointClearance,
                        child: Material(
                          color: const Color(0xEE1E242C),
                          elevation: 3,
                          shadowColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: InkWell(
                            key: ValueKey('wall-clearance-${gap.key}'),
                            onTap: () {
                              setState(() => _radialMenuScreenPosition = null);
                              _editWallClearance(gap);
                            },
                            child: Center(
                              child: Text(
                                gap.atStart == null
                                    ? _project.units.format(
                                        gap.distance,
                                        decimals: 3,
                                      )
                                    : context.l10n.architectWallEndpointValue(
                                        gap.atStart! ? 1 : 2,
                                        _project.units.format(
                                          gap.distance,
                                          decimals: 3,
                                        ),
                                      ),
                                style: TextStyle(
                                  color: gap.atStart == null
                                      ? Colors.cyanAccent
                                      : const Color(0xFFFFB74D),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            for (final gap in openingClearances)
              Builder(
                builder: (context) {
                  final rect = placements[gap.key]!;
                  return Positioned.fromRect(
                    rect: rect,
                    child: IgnorePointer(
                      ignoring: _radialMenuScreenPosition != null,
                      child: Tooltip(
                        message: context.l10n.architectOpeningClearance,
                        child: Material(
                          color: gap.isModularSnap
                              ? const Color(0xEE004D40)
                              : const Color(0xEE1E242C),
                          elevation: 3,
                          shadowColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(
                              color: gap.isModularSnap
                                  ? const Color(0xFF64FFDA)
                                  : Colors.white24,
                            ),
                          ),
                          child: InkWell(
                            key: ValueKey('opening-clearance-${gap.key}'),
                            onTap: () {
                              setState(() => _radialMenuScreenPosition = null);
                              _editOpeningClearance(gap);
                            },
                            child: Center(
                              child: Text(
                                _project.units.format(
                                  gap.distance,
                                  decimals: 3,
                                ),
                                style: TextStyle(
                                  color: gap.isModularSnap
                                      ? const Color(0xFF64FFDA)
                                      : Colors.cyanAccent,
                                  fontSize: 12,
                                  fontWeight: gap.isModularSnap
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
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
    for (final roof in storey.roofs) {
      if (roof.id == _polygonEditId) return roof.points;
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
              right: 64,
              child: Material(
                color: const Color(0xEE1E242C),
                elevation: 4,
                shadowColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
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
                              : Colors.white70,
                        ),
                        onPressed: _polygonDistanceOpen || _polygonEditor.active
                            ? null
                            : () => setState(() => _polygonEdgeMode = mode),
                      ),
                    Expanded(
                      child: !selected
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                context.l10n.architectEdgeSelectHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : TextButton.icon(
                              key: const ValueKey('polygon-edge-offset'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                              ),
                              onPressed: _polygonDistanceOpen
                                  ? null
                                  : () => _editPolygonDistance(null),
                              icon: const Icon(Icons.swap_vert, size: 18),
                              label: Text(
                                context.l10n.architectZoneOffset,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                    IconButton(
                      key: const ValueKey('polygon-edit-close'),
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: context.l10n.close,
                      onPressed: _polygonDistanceOpen
                          ? null
                          : () => setState(() {
                              _polygonEditId = null;
                              _polygonSelectedEdge = null;
                            }),
                      icon: const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.cyanAccent,
                      ),
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
    if (gap.atStart != null) {
      setState(() {
        _wallEndpointClearanceId = gap.wallId;
        _wallParallelMove = false;
        _moveSelection = false;
      });
    }
    var distance = gap.distance;
    final storeyId = _project.activeStoreyId;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 220,
          child: ArchitectWallDraftingPanel(
            title: gap.atStart == null
                ? context.l10n.architectWallClearance
                : context.l10n.architectWallEndpointClearance,
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
                gap.atStart != null
                    ? SetArchitectWallEndpointClearance(
                        storeyId: storeyId,
                        wallId: gap.wallId,
                        neighborId: gap.neighborId,
                        supportId: gap.supportId!,
                        atStart: gap.atStart!,
                        distance: distance,
                      )
                    : SetArchitectWallClearance(
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

  void _editOpeningClearance(ArchitectOpeningClearance gap) {
    var distance = gap.distance;
    final storeyId = _project.activeStoreyId;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 220,
          child: ArchitectWallDraftingPanel(
            title: context.l10n.architectOpeningClearance,
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
                SetArchitectOpeningClearance(
                  storeyId: storeyId,
                  wallId: gap.wallId,
                  openingId: gap.openingId,
                  isLeft: gap.isLeft,
                  distance: distance,
                ),
              );
              _saveBiMProjectIfAttached();
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
      if (command is InsertArchitectElementPoint) {
        _operationError();
        return;
      }
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
    final placement = ArchitectOpeningPlacement.resolve(
      walls: activeStorey.walls,
      rawPoint: point,
      openingWidth: _doorWidth,
      magnetic: _magnetEnabled,
    );
    if (placement == null) return;

    final targetWall = placement.wall;
    final ratio = placement.offsetRatio;
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
    if (_activeTool == ArchitectTool.select ||
        _multiSelect ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed) {
      return _elementTool.hitTestElement(
            _project.activeStorey,
            point,
            _currentScale,
          ) ??
          _axisTool
              .hitTestAxis(
                point,
                _project.gridAxes,
                tolerance: 14 / _currentScale,
              )
              ?.id ??
          _findZoneAt(point)?.id;
    }
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
        _roofTool.isDrafting ||
        _elementTool.slabDraftPoints.isNotEmpty) {
      return false;
    }
    if (_dimensionAnchors.isNotEmpty) return false;
    if (_selectionCandidates(_screenToModel(screenPoint))
        .any(_effectiveSelection.contains)) {
      return true;
    }
    return _selectAt(_screenToModel(screenPoint), invalidateGesture: false);
  }

  bool _onContextHold(Offset screenPoint) {
    if (_handleMoved ||
        _wallCutIds.isNotEmpty ||
        _draftStart != null ||
        _wallDirectionLocked ||
        _zoneTool.isDrafting ||
        _axisTool.isDrafting ||
        _roofTool.isDrafting ||
        _elementTool.slabDraftPoints.isNotEmpty) {
      return false;
    }
    if (_dimensionAnchors.isNotEmpty) return false;
    final candidates = _selectionCandidates(_screenToModel(screenPoint));
    final ok =
        candidates.any(_effectiveSelection.contains) ||
        _selectAt(_screenToModel(screenPoint), invalidateGesture: false);
    if (ok) {
      final id = _selectedElementId ?? _selectedZoneId ?? _effectiveSelection.firstOrNull;
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

  ArchitectRadialMenuItem _radialItem({
    required BimEditAction action,
    required Color color,
  }) => ArchitectRadialMenuItem(
    action: action,
    icon: BimEditActions.icon(action),
    label: BimEditActions.label(action, context.l10n),
    color: color,
    tooltip: action == BimEditAction.rename
        ? context.l10n.renameGridAxis
        : action == BimEditAction.newPoint
        ? (_selectedWall != null
              ? context.l10n.bimWallNewPointHelp
              : context.l10n.bimNewPointHint)
        : null,
  );

  List<ArchitectRadialMenuItem> _buildRadialMenuItems(String elementId) {
    final items = <ArchitectRadialMenuItem>[];
    if (_effectiveSelection.length > 1) {
      final sel = _effectiveSelection;
      final storey = _project.activeStorey;
      final wallCount = storey.walls.where((w) => sel.contains(w.id)).length;
      final colCount = storey.columns.where((c) => sel.contains(c.id)).length;
      final beamCount = storey.beams.where((b) => sel.contains(b.id)).length;
      final total = sel.length;

      final isAllWalls = wallCount == total;
      final isAllColsOrBeams = (colCount + beamCount) == total;

      if (isAllWalls) {
        return [
          _radialItem(
            action: ArchitectRadialAction.duplicate,
            color: const Color(0xFF64FFDA),
          ),
          _radialItem(
            action: ArchitectRadialAction.join,
            color: const Color(0xFF00E5FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.move,
            color: const Color(0xFFFFB300),
          ),
          _radialItem(
            action: ArchitectRadialAction.flip,
            color: const Color(0xFF40C4FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.properties,
            color: const Color(0xFFB388FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.delete,
            color: const Color(0xFFFF5252),
          ),
        ];
      }

      if (isAllColsOrBeams) {
        return [
          _radialItem(
            action: ArchitectRadialAction.duplicate,
            color: const Color(0xFF64FFDA),
          ),
          _radialItem(
            action: ArchitectRadialAction.move,
            color: const Color(0xFFFFB300),
          ),
          _radialItem(
            action: ArchitectRadialAction.rotate,
            color: const Color(0xFF40C4FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.properties,
            color: const Color(0xFFB388FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.delete,
            color: const Color(0xFFFF5252),
          ),
        ];
      }

      return [
        _radialItem(
          action: ArchitectRadialAction.move,
          color: const Color(0xFFFFB300),
        ),
        _radialItem(
          action: ArchitectRadialAction.properties,
          color: const Color(0xFFB388FF),
        ),
        _radialItem(
          action: ArchitectRadialAction.delete,
          color: const Color(0xFFFF5252),
        ),
      ];
    }

    final storey = _project.activeStorey;
    final isBeam = storey.beams.any((b) => b.id == elementId);
    final isCol = storey.columns.any((c) => c.id == elementId);
    final isWall = storey.walls.any((w) => w.id == elementId);
    final isDoor = storey.walls.any(
      (w) => w.doors.any((d) => d.id == elementId),
    );
    final isWindow = storey.walls.any(
      (w) => w.windows.any((win) => win.id == elementId),
    );
    final isSlab = storey.slabs.any((s) => s.id == elementId);
    final isRoof = storey.roofs.any((r) => r.id == elementId);
    final isCadPrim = storey.cadPrimitives.any((c) => c.id == elementId);
    final isZone = storey.zones.any((z) => z.id == elementId);
    final isAxis = _project.gridAxes.any((a) => a.id == elementId);
    final isDimension = storey.dimensions.any((d) => d.id == elementId);

    if (isCol || isBeam) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,

          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.rotate,

          color: const Color(0xFF40C4FF),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.duplicate,

          color: const Color(0xFF64FFDA),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isWall) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.duplicate,

          color: const Color(0xFF64FFDA),
        ),
      );

      items.add(
        _radialItem(
          action: ArchitectRadialAction.join,

          color: const Color(0xFF00E5FF),
        ),
      );

      items.add(
        _radialItem(
          action: ArchitectRadialAction.newPoint,

          color: const Color(0xFF80CBC4),
        ),
      );

      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,

          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.split,

          color: const Color(0xFFFF9100),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.flip,

          color: const Color(0xFF40C4FF),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isDoor || isWindow) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,

          color: const Color(0xFFFFB300),
        ),
      );
      if (isDoor) {
        items.add(
          _radialItem(
            action: ArchitectRadialAction.flip,

            color: const Color(0xFF40C4FF),
          ),
        );
      }
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isSlab || isRoof || isCadPrim || isZone) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.edit,

          color: const Color(0xFF00E5FF),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,

          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.duplicate,

          color: const Color(0xFF64FFDA),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),
        ),
      );
    } else if (isAxis) {
      for (final action in [
        ArchitectRadialAction.move,
        ArchitectRadialAction.rename,
        ArchitectRadialAction.offset,
        ArchitectRadialAction.rotate,
        ArchitectRadialAction.properties,
      ]) {
        items.add(_radialItem(action: action, color: const Color(0xFFFFB300)));
      }
    } else if (isDimension) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.newPoint,
          color: const Color(0xFF80CBC4),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,
          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,
          color: const Color(0xFFB388FF),
        ),
      );
    } else {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.move,

          color: const Color(0xFFFFB300),
        ),
      );
      items.add(
        _radialItem(
          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),
        ),
      );
    }

    if (!items.any((it) => it.action == ArchitectRadialAction.newPoint) &&
        InsertArchitectElementPoint.pathOf(storey, elementId) != null) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.newPoint,
          color: const Color(0xFF80CBC4),
        ),
      );
    }

    items.add(
      _radialItem(
        action: ArchitectRadialAction.delete,

        color: const Color(0xFFFF5252),
      ),
    );

    return items;
  }

  void _insertMidpoint(String id, {Offset? pick}) {
    final path = InsertArchitectElementPoint.pathOf(_project.activeStorey, id);
    if (path == null || path.points.length < 2) return;
    final hit = BimLineGeometry.insertion(
      path.points,
      pick ?? (path.points.first + path.points[1]) / 2,
      closed: path.closed,
    );
    if (hit == null) return;
    _cancelActiveDrags();
    final before = _project;
    _executeWallEdit(
      InsertArchitectElementPoint(
        storeyId: _project.activeStoreyId,
        elementId: id,
        point: hit.point,
        newElementId: ArchitectElementId.next('point'),
        atMidpoint: true,
      ),
    );
    if (identical(before, _project)) return;
    setState(() {
      if (path.closed) {
        _polygonEditId = id;
        _polygonSelectedEdge = hit.edge;
        if (_selectedZoneId == id) {
          _zoneTool.startEditingZone(
            _project.activeStorey.zones.firstWhere((z) => z.id == id),
          );
        }
      }
      _moveSelection = false;
      _wallCutIds = {};
      _wallCutStart = null;
      _wallCutConfirmedDir = null;
      _wallExtendId = null;
      _draftStart = null;
      _draftEnd = null;
    });
    HapticFeedback.selectionClick();
  }

  void _handleRadialAction(ArchitectRadialAction action) {
    final id = _radialMenuElementId;
    final pick = _radialMenuScreenPosition == null
        ? null
        : _screenToModel(_radialMenuScreenPosition!);
    setState(() {
      _radialMenuScreenPosition = null;
      _radialMenuElementId = null;
    });
    if (id == null) return;

    if (_effectiveSelection.length > 1) {
      switch (action) {
        case ArchitectRadialAction.delete:
          _deleteSelection();
          return;
        case ArchitectRadialAction.flip:
          final next = _elementTool.flipElementsByIds(
            _project.activeStorey,
            _effectiveSelection,
          );
          _commands.commit(_project.updateActiveStorey(next));
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          return;
        case ArchitectRadialAction.rotate:
          final next = _elementTool.rotateElementsByIds(
            _project.activeStorey,
            _effectiveSelection,
          );
          _commands.commit(_project.updateActiveStorey(next));
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          return;
        case ArchitectRadialAction.duplicate:
          _beginDuplicateSelection();
          return;
        case ArchitectRadialAction.move:
          setState(() {
            _polygonEditId = null;
            _polygonSelectedEdge = null;
            _moveSelection = true;
          });
          return;
        case ArchitectRadialAction.properties:
          _showProperties();
          return;
        case ArchitectRadialAction.join:
          _triggerWallJoin();
          return;
        default:
          break;
      }
    }

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
          _wallParallelMove = false;
          _moveSelection = true;
        });
        break;

      case ArchitectRadialAction.duplicate:
        _beginDuplicateMove(id);
        break;

      case ArchitectRadialAction.rotate:
        final axis = _project.gridAxes.where((a) => a.id == id).firstOrNull;
        if (axis != null) {
          _handleAxisRotate(axis);
          break;
        }
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

      case ArchitectRadialAction.newPoint:
        final dimension = _project.activeStorey.dimensions
            .where((d) => d.id == id)
            .firstOrNull;
        if (dimension != null) {
          _addWallsToDimension(dimension);
          setState(() {
            _dimensionAllowPoint = true;
            _dimensionPlacing = false;
          });
          break;
        }
        _insertMidpoint(id, pick: pick);
        break;

      case ArchitectRadialAction.split:
        setState(() {
          _wallCutStroke = true;
          _wallCutIds = {id};
          _wallCutStart = null;
          _wallCutConfirmedDir = null;
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

      case ArchitectRadialAction.rename:
        final axis = _project.gridAxes.where((a) => a.id == id).firstOrNull;
        if (axis != null) _handleAxisRename(axis);
        break;

      case ArchitectRadialAction.offset:
        final axis = _project.gridAxes.where((a) => a.id == id).firstOrNull;
        if (axis != null) {
          _handleAxisOffset(axis);
        }
        break;

      case ArchitectRadialAction.join:
        _triggerWallJoin();
        break;
    }
  }

  bool _selectAt(
    Offset point, {
    bool invalidateGesture = true,
    bool toggle = false,
  }) {
    final id = _nextSelection(point, advance: invalidateGesture);
    if (id == null) return false;
    _cancelActiveDrags();
    _polygonEditId = null;
    _polygonSelectedEdge = null;
    _zoneTool.cancelAll();
    _axisTool.cancelAll();
    final shouldMulti = _multiSelect ||
        _activeTool == ArchitectTool.select ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed;
    setState(() {
      if (invalidateGesture) _interactionEpoch++;
      _draftStart = null;
      _draftEnd = null;
      if (shouldMulti) {
        if (_selectionIds.isEmpty && _selectedElementId != null) {
          _selectionIds.add(_selectedElementId!);
        } else if (_selectionIds.isEmpty && _selectedZoneId != null) {
          _selectionIds.add(_selectedZoneId!);
        }
        if (toggle && _selectionIds.contains(id)) {
          _selectionIds.remove(id);
        } else {
          _selectionIds.add(id);
        }
      } else {
        _selectionIds
          ..clear()
          ..add(id);
      }
      final primary = _selectionIds.contains(id)
          ? id
          : _selectionIds.lastOrNull;
      if (primary != _selectedElementId || _selectionIds.length != 1) {
        _wallEndpointClearanceId = null;
        _wallParallelMove = false;
        _moveSelection = false;
      }
      _selectedElementId = primary;
      _selectedZoneId = null;
      if (primary != null) {
        final zone = _project.activeStorey.zones
            .where((e) => e.id == primary)
            .firstOrNull;
        if (zone != null) {
          _selectedZoneId = primary;
          _zoneTool.startEditingZone(zone);
        } else if (_project.gridAxes.any((e) => e.id == primary)) {
          _axisTool.selectAxis(primary);
        }
      }
    });
    HapticFeedback.selectionClick();
    return true;
  }

  void _operationError() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.architectOperationRejected)),
  );

  ArchitectStair _stairAt(Offset start, Offset end, {String id = 'preview'}) {
    final delta = end - start;
    final endPoint = delta.distance < .001 ? start + const Offset(1, 0) : end;
    return ArchitectStair(
      id: id,
      startPoint: start,
      endPoint: endPoint,
      width: _elementTool.stairWidth,
      design: ArchitectStairRules.resolveDesign(
        _project,
        _project.activeStorey,
        _elementTool.stairDesign,
      ),
    );
  }

  void _showStairProperties({ArchitectStair? stair, bool create = false}) {
    final defaults = stair == null;
    final initial = stair ?? _stairAt(Offset.zero, const Offset(1, 0));
    showDialog<void>(
      context: context,
      builder: (_) => ArchitectStairPropertiesDialog(
        project: _project,
        stair: initial,
        onApply: (next) {
          try {
            if (defaults) {
              _elementTool.setStairParams(
                width: next.width,
                design: next.design,
              );
            } else {
              _commands.execute(
                PutArchitectStair(
                  storeyId: _project.activeStoreyId,
                  stair: next,
                  create: create,
                ),
              );
              if (create) {
                setState(() {
                  _draftStart = null;
                  _draftEnd = null;
                });
              }
              _saveBiMProjectIfAttached();
            }
            return true;
          } on ArgumentError {
            _operationError();
            return false;
          }
        },
      ),
    );
  }

  Future<void> _openRoofLayersDialog({ArchitectRoofPlane? roof}) async {
    final target = roof ?? _selectedRoof;
    final initialAssembly = target?.assembly ?? _roofTool.activeAssembly;
    final initialSlope = target?.slopeDegrees ?? _roofTool.slopeDegrees;
    final initialOverhang = target?.eavesOverhang ?? _roofTool.eavesOverhang;
    final initialEavesCut = target?.eavesCut ?? _roofTool.eavesCut;
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectRoofLayersDialog(
        initialAssembly: initialAssembly,
        initialSlopeDegrees: initialSlope,
        initialEavesOverhang: initialOverhang,
        initialEavesCut: initialEavesCut,
        initialBaseElevationOffset: target?.baseElevationOffset,
        onApply: (result) {
          setState(() {
            _roofTool.setAssembly(result.assembly);
            _roofTool.setSlopeDegrees(result.slopeDegrees);
            _roofTool.setEavesOverhang(result.eavesOverhang);
            _roofTool.setEavesCut(result.eavesCut);
            if (target != null) {
              _commands.execute(
                UpdateArchitectRoofPlane(
                  storeyId: _project.activeStoreyId,
                  roof: target.copyWith(
                    assembly: result.assembly,
                    slopeDegrees: result.slopeDegrees,
                    eavesOverhang: result.eavesOverhang,
                    eavesCut: result.eavesCut,
                    baseElevationOffset: result.baseElevationOffset,
                  ),
                ),
              );
              _saveBiMProjectIfAttached();
            }
          });
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  void _handleAutoRoof(AutoRoofType type) {
    final generated = ArchitectRoofTool.generateAutoRoof(
      project: _project,
      type: type,
      tool: _roofTool,
    );
    if (generated.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectRoofAutoNoWalls),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _commands.execute(
        ReplaceStoreyRoofs(
          storeyId: _project.activeStoreyId,
          roofs: generated,
        ),
      );
      _selectionIds
        ..clear()
        ..add(generated.first.id);
      _selectedElementId = generated.first.id;
      _multiSelect = false;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectRoofAutoCreated(generated.length)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showProperties() {
    final ids = _effectiveSelection;
    if (ids.isEmpty) return;
    if (ids.length == 1) {
      final stairs = _project.activeStorey.stairs.where(
        (s) => ids.contains(s.id),
      );
      if (stairs.isNotEmpty) {
        _showStairProperties(stair: stairs.first);
        return;
      }
      final roofs = _project.activeStorey.roofs.where(
        (r) => ids.contains(r.id),
      );
      if (roofs.isNotEmpty) {
        _openRoofLayersDialog(roof: roofs.first);
        return;
      }
    }
    showDialog<void>(
      context: context,
      builder: (_) => ArchitectElementPropertiesDialog(
        project: _project,
        elementIds: ids,
        onSlabLayers: ids.length == 1 && _project.activeStorey.slabs.any((s) => ids.contains(s.id))
            ? () {
                Navigator.pop(context);
                final slab = _project.activeStorey.slabs.firstWhere((s) => ids.contains(s.id));
                showDialog<void>(context: context, builder: (_) => ArchitectSlabLayersDialog(
                  project: _project, slab: slab, onApply: (next) {
                    _commands.commit(next); return true;
                  }));
              }
            : null,
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

  Set<String> get _selectedWallIds {
    final ids = _effectiveSelection;
    return _project.activeStorey.walls
        .where((wall) => ids.contains(wall.id))
        .map((wall) => wall.id)
        .toSet();
  }

  void _triggerWallJoin() {
    final wallIds = _selectedWallIds;
    if (wallIds.length >= 2) {
      _cancelActiveDrags();
      try {
        _commands.execute(
          JoinArchitectWalls(
            storeyId: _project.activeStoreyId,
            wallIds: wallIds,
          ),
        );
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectWallJoinSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      } on ArgumentError {
        _operationError();
      }
    } else if (wallIds.length == 1) {
      final sourceId = wallIds.single;
      setState(() {
        _radialMenuScreenPosition = null;
        _wallCutIds = {};
        _wallCutStart = null;
        _wallCutConfirmedDir = null;
        _wallExtendId = null;
        _moveSelection = false;
        _wallParallelMove = false;
        if (_wallJoinSourceId == sourceId) {
          _wallJoinSourceId = null;
          _wallJoinPointer = null;
        } else {
          _wallJoinSourceId = sourceId;
          final wall = _project.activeStorey.walls
              .where((w) => w.id == sourceId)
              .firstOrNull;
          if (wall != null) {
            final center = (wall.startPoint + wall.endPoint) / 2;
            _wallJoinPointer =
                center + wall.normalVector * (wall.thickness + 0.6);
          }
        }
      });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildWallSelectionActions(Set<String> wallIds) {
    final l = context.l10n;
    return Material(
      key: const ValueKey('architect-wall-floating-actions'),
      color: const Color(0xEE1E242C),
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      shadowColor: Colors.black54,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('architect-wall-flip'),
              tooltip: l.architectWallFlipSide,
              icon: const Icon(Icons.flip, color: Color(0xFF00E5FF)),
              onPressed: () => _executeWallEdit(
                MirrorArchitectWalls(
                  storeyId: _project.activeStoreyId,
                  wallIds: wallIds,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('architect-wall-cut'),
              tooltip: l.architectWallCut,
              icon: Icon(
                Icons.content_cut,
                color: _wallCutIds.isNotEmpty ? Colors.amber : Colors.white,
              ),
              onPressed: () {
                _cancelActiveDrags();
                setState(() {
                  _wallCutIds = _wallCutIds.isEmpty ? wallIds : {};
                  _wallCutStroke = false;
                  _wallCutStart = null;
                  _wallCutConfirmedDir = null;
                  _moveSelection = false;
                  _wallParallelMove = false;
                });
              },
            ),
            IconButton(
              key: const ValueKey('architect-wall-join'),
              tooltip: l.architectWallJoinTooltip,
              icon: Icon(
                Icons.call_merge,
                color: _wallJoinSourceId != null ? Colors.amber : Colors.white,
              ),
              onPressed: () => _triggerWallJoin(),
            ),
            if (wallIds.length == 1) ...[
              IconButton(
                key: const ValueKey('architect-wall-new-point'),
                tooltip: l.bimNewPoint,
                icon: const Icon(
                  Icons.add_location_alt_outlined,
                  color: Color(0xFF80CBC4),
                ),
                onPressed: () {
                  _cancelActiveDrags();
                  _insertMidpoint(wallIds.single);
                },
              ),
              IconButton(
                key: const ValueKey('architect-wall-extend'),
                tooltip: l.architectWallExtend,
                icon: Icon(
                  Icons.open_in_full,
                  color: _wallExtendId == wallIds.single
                      ? Colors.amber
                      : Colors.white,
                ),
                onPressed: () {
                  _cancelActiveDrags();
                  setState(() {
                    _radialMenuScreenPosition = null;
                    _wallCutIds = {};
                    _wallCutStart = null;
                    _moveSelection = false;
                    _wallParallelMove = false;
                    _wallExtendId = _wallExtendId == wallIds.single
                        ? null
                        : wallIds.single;
                  });
                },
              ),
              () {
                final wall = _project.activeStorey.walls
                    .where((w) => w.id == wallIds.single)
                    .firstOrNull;
                final overshoot = wall != null
                    ? ArchitectWallOvershootDetector.detectForWall(
                        wall,
                        _project.activeStorey.walls,
                      ).firstOrNull
                    : null;
                if (overshoot != null) {
                  return IconButton(
                    key: const ValueKey('architect-wall-trim-overshoot'),
                    tooltip: l.architectWallOvershootTooltip,
                    icon: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: Colors.amberAccent,
                    ),
                    onPressed: () => _handleTrimOvershoot(overshoot),
                  );
                }
                return const SizedBox.shrink();
              }(),
            ],
          ],
        ),
      ),
    );
  }

  void _deleteSelection() {
    final ids = _effectiveSelection;
    if (ids.isEmpty) return;
    final storey = _elementTool.deleteElementsByIds(_project.activeStorey, ids);
    _commands.commit(
      _project
          .updateActiveStorey(
            storey.copyWith(
              zones: storey.zones.where((z) => !ids.contains(z.id)).toList(),
            ),
          )
          .copyWithGridAxes(
            _project.gridAxes.where((a) => !ids.contains(a.id)).toList(),
          ),
    );
    _saveBiMProjectIfAttached();
    _clearSelection();
  }

  void _beginDuplicateSelection() {
    _cancelActiveDrags();
    final ids = _effectiveSelection;
    if (ids.isEmpty) return;
    final (nextStorey, copyIds) = _elementTool.duplicateElementsByIds(
      _project.activeStorey,
      ids,
      offset: const Offset(0.5, 0.5),
    );
    if (copyIds.isEmpty) return;
    final updated = _project.updateActiveStorey(nextStorey);
    _commands.commit(updated);
    _saveBiMProjectIfAttached();
    setState(() {
      _selectionIds
        ..clear()
        ..addAll(copyIds);
      _selectedElementId = copyIds.firstOrNull;
      _moveSelection = true;
    });
    HapticFeedback.lightImpact();
  }

  void _selectConnectedWalls() {
    final wallIds = _selectedWallIds;
    if (wallIds.isEmpty) return;
    final allConnected = <String>{};
    for (final wallId in wallIds) {
      allConnected.addAll(
        _elementTool.findConnectedWallChain(_project.activeStorey, wallId),
      );
    }
    if (allConnected.isNotEmpty) {
      setState(() {
        _selectionIds
          ..clear()
          ..addAll(allConnected);
        _selectedElementId = allConnected.first;
        _multiSelect = true;
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _selectSimilarElements() {
    final sel = _effectiveSelection;
    if (sel.isEmpty) return;
    final storey = _project.activeStorey;
    final targetIds = <String>{};

    final hasWalls = storey.walls.any((w) => sel.contains(w.id));
    final hasCols = storey.columns.any((c) => sel.contains(c.id));
    final hasBeams = storey.beams.any((b) => sel.contains(b.id));
    final hasSlabs = storey.slabs.any((s) => sel.contains(s.id));
    final hasRoofs = storey.roofs.any((r) => sel.contains(r.id));
    final hasZones = storey.zones.any((z) => sel.contains(z.id));
    final hasAxes = _project.gridAxes.any((a) => sel.contains(a.id));

    if (hasWalls) targetIds.addAll(storey.walls.map((w) => w.id));
    if (hasCols) targetIds.addAll(storey.columns.map((c) => c.id));
    if (hasBeams) targetIds.addAll(storey.beams.map((b) => b.id));
    if (hasSlabs) targetIds.addAll(storey.slabs.map((s) => s.id));
    if (hasRoofs) targetIds.addAll(storey.roofs.map((r) => r.id));
    if (hasZones) targetIds.addAll(storey.zones.map((z) => z.id));
    if (hasAxes) targetIds.addAll(_project.gridAxes.map((a) => a.id));

    if (targetIds.isNotEmpty) {
      setState(() {
        _selectionIds
          ..clear()
          ..addAll(targetIds);
        _selectedElementId = targetIds.first;
        _multiSelect = true;
      });
      HapticFeedback.mediumImpact();
    }
  }

  Widget _buildDimensionBar() {
    final l = context.l10n;
    return Material(
      color: const Color(0xEE1E242C),
      borderRadius: BorderRadius.circular(8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            children: [
              for (final mode in [
                (
                  ArchitectDimensionStyle.single,
                  'architect-dimension-single',
                  l.architectDimensionSingle,
                ),
                (
                  ArchitectDimensionStyle.exterior,
                  'architect-dimension-chain',
                  l.architectDimensionExterior,
                ),
                (
                  ArchitectDimensionStyle.interior,
                  'architect-dimension-interior',
                  l.architectDimensionInterior,
                ),
              ])
                Tooltip(
                  message: switch (mode.$1) {
                    ArchitectDimensionStyle.single =>
                      l.architectDimensionEndHint,
                    ArchitectDimensionStyle.exterior =>
                      l.architectDimensionChainHint,
                    ArchitectDimensionStyle.interior =>
                      l.architectDimensionInteriorHelp,
                  },
                  child: TextButton(
                    key: ValueKey(mode.$2),
                    style: TextButton.styleFrom(
                      foregroundColor: mode.$1 == _dimensionStyle
                          ? Colors.cyanAccent
                          : Colors.white70,
                    ),
                    onPressed: () => setState(() {
                      _resetDimensionDraft();
                      _draftStart = null;
                      _draftEnd = null;
                      _dimensionStyle = mode.$1;
                      _dimensionChainMode =
                          mode.$1 != ArchitectDimensionStyle.single;
                    }),
                    child: Text(mode.$3),
                  ),
                ),
            ],
          ),
          if (_dimensionAnchors.isNotEmpty)
            Wrap(
              children: [
                if (_dimensionStyle == ArchitectDimensionStyle.exterior)
                  IconButton(
                    key: const ValueKey('architect-dimension-overall'),
                    tooltip: l.architectDimensionOverall,
                    icon: Icon(
                      Icons.straighten,
                      color: _dimensionShowOverall
                          ? Colors.cyanAccent
                          : Colors.white70,
                    ),
                    onPressed: () => setState(
                      () => _dimensionShowOverall = !_dimensionShowOverall,
                    ),
                  ),
                if (_dimensionChainMode && _dimensionEditing == null)
                  IconButton(
                    key: const ValueKey('architect-dimension-direction'),
                    tooltip: l.architectDimensionDirectionHint,
                    icon: Icon(
                      Icons.align_horizontal_left,
                      color: _dimensionChoosingDirection
                          ? Colors.amber
                          : Colors.white70,
                    ),
                    onPressed: () => setState(() {
                      _dimensionChoosingDirection =
                          !_dimensionChoosingDirection;
                      _dimensionPlacing = false;
                    }),
                  ),
                if (_dimensionChainMode && _dimensionPlacing)
                  IconButton(
                    key: const ValueKey('architect-dimension-add-walls'),
                    tooltip: l.architectDimensionAddWalls,
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: () => setState(() {
                      _dimensionPlacing = false;
                      _dimensionAllowPoint = false;
                    }),
                  ),
                IconButton(
                  key: const ValueKey('architect-dimension-new-point'),
                  tooltip: l.architectDimensionNewPoint,
                  icon: Icon(
                    Icons.add_location_alt_outlined,
                    color: _dimensionAllowPoint
                        ? Colors.cyanAccent
                        : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _dimensionAllowPoint = !_dimensionAllowPoint;
                    if (_dimensionAllowPoint) {
                      _dimensionPlacing = false;
                      _dimensionChoosingDirection = false;
                    }
                  }),
                ),
                IconButton(
                  key: const ValueKey('architect-dimension-distance'),
                  tooltip: l.architectPropertyOffset,
                  icon: const Icon(Icons.space_bar, color: Colors.white70),
                  onPressed: _dimensionDraft == null
                      ? null
                      : _setDimensionDistance,
                ),
                IconButton(
                  key: const ValueKey('architect-dimension-place'),
                  tooltip: _dimensionEditing != null
                      ? l.architectDimensionConfirm
                      : l.architectDimensionPositionHint,
                  icon: Icon(
                    _dimensionEditing != null ? Icons.check : Icons.open_with,
                    color: _dimensionEditing != null
                        ? Colors.greenAccent
                        : _dimensionPlacing
                        ? Colors.amber
                        : Colors.white70,
                  ),
                  onPressed: _dimensionDraft == null
                      ? null
                      : _dimensionEditing != null
                      ? _commitDimensionDraft
                      : () => setState(() {
                          _dimensionPlacing = true;
                          _dimensionChoosingDirection = false;
                        }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    final l = context.l10n;
    final ids = _effectiveSelection;
    final wallIds = _selectedWallIds;
    final dimension = ids.length == 1
        ? _project.activeStorey.dimensions
              .where((d) => ids.contains(d.id))
              .firstOrNull
        : null;
    void clear() => _clearSelection();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E26),
        border: Border(top: BorderSide(color: Colors.white12, width: 1.0)),
      ),
      child: Material(
        key: const ValueKey('architect-selection-bar'),
        color: Colors.transparent,
        child: IconButtonTheme(
          data: const IconButtonThemeData(
            style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dimension != null) ...[
                  IconButton(
                    key: const ValueKey('architect-dimension-new-point'),
                    tooltip: l.architectDimensionNewPoint,
                    icon: const Icon(
                      Icons.add_location_alt_outlined,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      _addWallsToDimension(dimension);
                      setState(() {
                        _dimensionAllowPoint = true;
                        _dimensionPlacing = false;
                      });
                    },
                  ),
                  IconButton(
                    key: const ValueKey('architect-dimension-add-walls'),
                    tooltip: l.architectDimensionEditPoints,
                    icon: const Icon(
                      Icons.edit_location_alt_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => _addWallsToDimension(dimension),
                  ),
                ],
                if (wallIds.isNotEmpty)
                  IconButton(
                    key: const ValueKey('architect-select-connected'),
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectSelectConnected,
                    icon: const Icon(
                      Icons.hub_outlined,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    onPressed: _selectConnectedWalls,
                  ),
                if (wallIds.length == 1) () {
                  final wall = _project.activeStorey.walls
                      .where((w) => w.id == wallIds.first)
                      .firstOrNull;
                  final overshoot = wall != null
                      ? ArchitectWallOvershootDetector.detectForWall(
                          wall,
                          _project.activeStorey.walls,
                        ).firstOrNull
                      : null;
                  if (overshoot != null) {
                    return IconButton(
                      key: const ValueKey('architect-selection-trim-overshoot'),
                      constraints: const BoxConstraints.tightFor(
                        width: 26,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: l.architectWallOvershootTooltip,
                      icon: const Icon(
                        Icons.auto_fix_high_rounded,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                      onPressed: () => _handleTrimOvershoot(overshoot),
                    );
                  }
                  return const SizedBox.shrink();
                }(),
                IconButton(
                  key: const ValueKey('architect-select-similar'),
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: l.architectSelectSimilar,
                  icon: const Icon(
                    Icons.select_all_rounded,
                    color: Colors.cyanAccent,
                    size: 18,
                  ),
                  onPressed: _selectSimilarElements,
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  key: const ValueKey('architect-multi-select'),
                  tooltip: l.architectSelectionMulti,
                  icon: Icon(
                    Icons.library_add_check_outlined,
                    size: 18,
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
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  key: const ValueKey('architect-selection-move'),
                  tooltip: l.architectSelectionMove,
                  icon: Icon(
                    Icons.open_with,
                    size: 18,
                    color: _moveSelection ? Colors.amber : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _radialMenuScreenPosition = null;
                    _polygonEditId = null;
                    _polygonSelectedEdge = null;
                    _wallParallelMove = false;
                    _moveSelection = !_moveSelection;
                  }),
                ),
                if (wallIds.length == 1 && ids.length == 1)
                  Tooltip(
                    message: l.architectWallParallelHelp,
                    child: InkWell(
                      key: const ValueKey('architect-wall-parallel'),
                      onTap: _toggleParallelMove,
                      onLongPress: _editParallelOffset,
                      child: SizedBox(
                        width: 32,
                        height: 40,
                        child: Icon(
                          Icons.swap_vert,
                          size: 19,
                          color: _wallParallelMove
                              ? Colors.amber
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  key: const ValueKey('architect-selection-properties'),
                  tooltip: l.architectProperties,
                  icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                  onPressed: () {
                    setState(() => _radialMenuScreenPosition = null);
                    _showProperties();
                  },
                ),
                if (wallIds.isNotEmpty)
                  IconButton(
                    key: const ValueKey('wall-detach'),
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 40,
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
                if (ids.length == 1 &&
                    InsertArchitectElementPoint.pathOf(
                          _project.activeStorey,
                          ids.single,
                        ) !=
                        null)
                  IconButton(
                    key: const ValueKey('architect-selection-new-point'),
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: l.bimNewPoint,
                    icon: const Icon(
                      Icons.add_location_alt_outlined,
                      color: Color(0xFF80CBC4),
                      size: 18,
                    ),
                    onPressed: () {
                      _cancelActiveDrags();
                      _insertMidpoint(ids.single);
                    },
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
                          _wallCutConfirmedDir = null;
                          _wallExtendId = null;
                        });
                      } else if (action == 'mirror') {
                        _executeWallEdit(
                          MirrorArchitectWalls(
                            storeyId: _project.activeStoreyId,
                            wallIds: wallIds,
                          ),
                        );
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
                        _insertMidpoint(wallIds.single);
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
                      if (wallIds.length == 1 && !_multiSelect) ...[
                        PopupMenuItem(
                          value: 'length',
                          child: Text(l.architectWallLength),
                        ),
                        PopupMenuItem(
                          value: 'point',
                          child: Text(l.bimNewPoint),
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
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: l.delete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  onPressed: _deleteSelection,
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  key: const ValueKey('architect-clear-selection'),
                  tooltip: l.close,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 18,
                    weight: 800,
                  ),
                  onPressed: clear,
                ),
              ],
            ),
          ),
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
      ...storey.roofs.map((e) => e.id),
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
      unitToMeters: _project.units.scaleToMeters,
      unitSymbol: _project.units.symbol,
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

  void _replaceAxis(StructuralGridAxis axis) {
    if (!_project.gridAxes.any((a) => a.id == axis.id)) return;
    _commands.commit(
      _project.copyWithGridAxes([
        for (final existing in _project.gridAxes)
          existing.id == axis.id ? axis : existing,
      ]),
    );
    _saveBiMProjectIfAttached();
    HapticFeedback.selectionClick();
  }

  Future<void> _handleAxisRename(StructuralGridAxis axis) async {
    final name = await showArchitectAxisValueDialog(
      context: context,
      title: context.l10n.axisNameTitle,
      label: context.l10n.renameGridAxis,
      value: axis.name,
    );
    if (!mounted || name == null) return;
    final current = _project.gridAxes.where((a) => a.id == axis.id).firstOrNull;
    if (current != null && current.name != name) {
      _replaceAxis(current.copyWith(name: name));
    }
  }

  Future<void> _handleAxisRotate(StructuralGridAxis axis) async {
    final value = await showArchitectAxisValueDialog(
      context: context,
      title: context.l10n.architectRadialRotate,
      label: '${context.l10n.architectPropertyAngle} (°)',
      value: (axis.angleRad * 180 / math.pi).toStringAsFixed(2),
      numeric: true,
    );
    if (!mounted || value == null) return;
    final current = _project.gridAxes.where((a) => a.id == axis.id).firstOrNull;
    if (current == null) return;
    final radians =
        double.parse(value.replaceAll(',', '.')) % 360 * math.pi / 180;
    final midpoint = (current.start + current.end) / 2;
    final half =
        Offset(math.cos(radians), math.sin(radians)) * current.length / 2;
    _replaceAxis(
      current.copyWith(start: midpoint - half, end: midpoint + half),
    );
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
        _commands.select(ArchitectWorkspaceView.plan, null);
        _modelCommands.commit(newProj);
        _wallDirectionLocked = false;
        _restoreWallType();
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
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              _project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions:
                [
                      IconButton(
                        key: const ValueKey('architect-undo'),
                        tooltip: l10n.architectZoneUndoAction,
                        onPressed: _commands.canUndo ? _undoModel : null,
                        color: Colors.white,
                        disabledColor: Colors.white38,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton(
                        key: const ValueKey('architect-redo'),
                        tooltip: l10n.architectZoneRedoAction,
                        onPressed: _commands.canRedo ? _redoModel : null,
                        color: Colors.white,
                        disabledColor: Colors.white38,
                        icon: const Icon(Icons.redo),
                      ),
                      IconButton(
                        key: const ValueKey('architect-ghost-storeys'),
                        tooltip: l10n.architectGhostStoreys,
                        icon: Icon(
                          Icons.layers_outlined,
                          color: _showGhostStoreys
                              ? Colors.cyanAccent
                              : Colors.white54,
                        ),
                        onPressed: () => _changeViewPreference(
                          () => _showGhostStoreys = !_showGhostStoreys,
                        ),
                      ),
                      if (!compactActions)
                        IconButton(
                          key: const ValueKey('architect-grid-toggle'),
                          tooltip: l10n.architectDrawingGrid,
                          icon: Icon(
                            Icons.grid_4x4,
                            color: _showDrawingGrid
                                ? Colors.cyanAccent
                                : Colors.white54,
                          ),
                          onPressed: () => _changeViewPreference(
                            () => _showDrawingGrid = !_showDrawingGrid,
                          ),
                        ),
                      IconButton(
                        key: const ValueKey('architect-settings'),
                        tooltip: l10n.architectSettings,
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _showWorkspaceSettings,
                      ),
                      if (!compactActions)
                        IconButton(
                          key: const ValueKey('architect-deselect'),
                          tooltip: l10n.architectDeselect,
                          onPressed:
                              _effectiveSelection.isNotEmpty || _multiSelect
                              ? _clearSelection
                              : null,
                          icon: Icon(
                            Icons.deselect_outlined,
                            color:
                                (_effectiveSelection.isNotEmpty || _multiSelect)
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                      // 2D / 3D Toggle Button
                      if (!compactActions)
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
                          onPressed: _toggle3DView,
                        ),
                      // Reset View Button
                      if (!compactActions)
                        IconButton(
                          tooltip: l10n.architectResetView,
                          icon: const Icon(
                            Icons.center_focus_strong_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _resetWorkspaceView,
                        ),
                      // Canvas Background (Theme Toggle) Button - Always accessible
                      if (!_is3DView)
                        IconButton(
                          key: const ValueKey('architect-canvas-background'),
                          tooltip: _canvasPalette.isDark
                              ? l10n.architectCanvasLight
                              : l10n.architectCanvasDark,
                          icon: Icon(
                            _canvasPalette.isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: _canvasPalette.isDark
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFF81D4FA),
                          ),
                          onPressed: _toggleCanvasBackground,
                        ),
                      if (!compactActions)
                        IconButton(
                          tooltip: l10n.architectNewProject,
                          icon: const Icon(
                            Icons.add_business_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _openNewProjectWizard,
                        ),
                      // Diagnostic Logs Dialog Button
                      if (!compactActions)
                        IconButton(
                          tooltip: l10n.architectDebugLogs,
                          icon: const Icon(
                            Icons.bug_report_rounded,
                            color: Colors.white,
                          ),
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
                          onPressed: () => _changeViewPreference(
                            () => _showUnderlay = !_showUnderlay,
                          ),
                        ),
                      if (compactActions)
                        PopupMenuButton<String>(
                          key: const ValueKey('architect-more'),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                          onSelected: (action) {
                            switch (action) {
                              case 'grid':
                                _changeViewPreference(
                                  () => _showDrawingGrid = !_showDrawingGrid,
                                );
                                break;
                              case 'view':
                                _toggle3DView();
                                break;
                              case 'fit':
                                _resetWorkspaceView();
                                break;
                              case 'deselect':
                                _clearSelection();
                                break;
                              case 'background':
                                unawaited(_toggleCanvasBackground());
                                break;
                              case 'new':
                                _openNewProjectWizard();
                                break;
                              case 'logs':
                                _showDebugLogsDialog();
                                break;
                              case 'underlay':
                                _changeViewPreference(
                                  () => _showUnderlay = !_showUnderlay,
                                );
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            CheckedPopupMenuItem(
                              value: 'grid',
                              checked: _showDrawingGrid,
                              child: Text(l10n.architectDrawingGrid),
                            ),
                            PopupMenuItem(
                              value: 'view',
                              child: Text(
                                _is3DView
                                    ? l10n.architectView2D
                                    : l10n.architectView3D,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'fit',
                              child: Text(l10n.architectResetView),
                            ),
                            if (_effectiveSelection.isNotEmpty || _multiSelect)
                              PopupMenuItem(
                                value: 'deselect',
                                child: Text(l10n.architectDeselect),
                              ),

                            if (!_is3DView)
                              PopupMenuItem(
                                key: const ValueKey(
                                  'architect-canvas-background-menu',
                                ),
                                value: 'background',
                                child: Row(
                                  children: [
                                    Icon(
                                      _canvasPalette.isDark
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
                                      color: _canvasPalette.isDark
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFF81D4FA),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _canvasPalette.isDark
                                          ? l10n.architectCanvasLight
                                          : l10n.architectCanvasDark,
                                    ),
                                  ],
                                ),
                              ),
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
                    ]
                    .map(
                      (action) => compactActions
                          ? SizedBox(width: 40, child: action)
                          : action,
                    )
                    .toList(),
          ),
          bottomNavigationBar: _is3DView || !_commands.hasView
              ? null
              : ArchitectToolPalette(
                  drawingOnly: !_commands.isPlan,
                  activeTool: _activeTool,
                  onToolChanged: (tool) => setState(() {
                    _resetDimensionDraft();
                    _selectionCyclePoint = null;
                    _selectionIds.clear();
                    _interactionEpoch++;
                    _cancelActiveDrags();
                    _zoneTool.cancelAll();
                    _axisTool.cancelAll();
                    _elementTool.cancelSlabDrafting();
                    _roofTool.clearDraft();
                    _selectedZoneId = null;
                    _selectedElementId = null;
                    _wallParallelMove = false;
                    _wallEndpointClearanceId = null;
                    _moveSelection = false;
                    _activeTool = tool;
                    _pendingShape = null;
                    _shapePanelAnchor = null;
                    _columnPreviewPoint = null;
                    _cursorModel = null;
                    _draftStart = null;
                    _draftEnd = null;
                    _wallDirectionLocked = false;
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
                  wallTypes: _availableWallTypes,
                  activeWallType: _activeWallType,
                  onWallTypeSelected: _selectWallType,
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
                  stairDesign: _elementTool.stairDesign,
                  onStairShapeChanged: (shape) => _elementTool.setStairParams(
                    design: _elementTool.stairDesign.copyWith(shape: shape, autoRisers: true)),
                  onStairProperties: () => _showStairProperties(),
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
              ArchitectWorkspaceViewBar(
                project: _modelCommands.project,
                view: _commands.view,
                viewId: _commands.viewId,
                lastViewIds: _lastViewIds,
                onSelected: _selectWorkspaceView,
                onManage: _manageWorkspaceViews,
              ),

              // Main Viewport (2D Canvas or 3D Solid Model)
              Expanded(
                child: Stack(
                  children: [
                    _is3DView ? _build3DViewport() : !_commands.hasView
                        ? Center(child: Text(l10n.architectViewDrawingEmpty))
                        : _build2DCanvas(),
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
                          onGenerateFromWalls: _generateAxesFromWalls,
                        ),
                      ),
                    if ((_activeTool == ArchitectTool.roof ||
                            _selectedRoof != null) &&
                        !_is3DView &&
                        _polygonEditId == null)
                      Positioned(
                        top: 10,
                        left: 8,
                        right: 8,
                        child: ArchitectRoofBar(
                          tool: _roofTool,
                          selectedRoof: _selectedRoof,
                          onAutoRoof: _handleAutoRoof,
                          onOpenLayersDialog: () =>
                              _openRoofLayersDialog(roof: _selectedRoof),
                          onSwitchEavesEdge: () {
                            final sel = _selectedRoof;
                            if (sel == null || sel.points.length < 3) return;
                            final nextEdge =
                                (sel.safeEavesEdgeIndex + 1) %
                                sel.points.length;
                            setState(() {
                              _commands.execute(
                                UpdateArchitectRoofPlane(
                                  storeyId: _project.activeStoreyId,
                                  roof: sel.copyWith(eavesEdgeIndex: nextEdge),
                                ),
                              );
                            });
                            _saveBiMProjectIfAttached();
                            HapticFeedback.selectionClick();
                          },
                          onSelectedRoofSlopeChanged: (slopeDeg) {
                            setState(() {
                              _roofTool.setSlopeDegrees(slopeDeg);
                              final sel = _selectedRoof;
                              if (sel != null) {
                                _commands.execute(
                                  UpdateArchitectRoofPlane(
                                    storeyId: _project.activeStoreyId,
                                    roof: sel.copyWith(slopeDegrees: slopeDeg),
                                  ),
                                );
                                _saveBiMProjectIfAttached();
                              }
                            });
                            HapticFeedback.selectionClick();
                          },
                          onSelectedRoofOverhangChanged: (overhang) {
                            setState(() {
                              _roofTool.setEavesOverhang(overhang);
                              final sel = _selectedRoof;
                              if (sel != null) {
                                _commands.execute(
                                  UpdateArchitectRoofPlane(
                                    storeyId: _project.activeStoreyId,
                                    roof: sel.copyWith(eavesOverhang: overhang),
                                  ),
                                );
                                _saveBiMProjectIfAttached();
                              }
                            });
                            HapticFeedback.selectionClick();
                          },
                          onFinishPolygon: () {
                            final created = _roofTool.finishPolygonDraft(
                              storey: _project.activeStorey,
                            );
                            if (created != null) {
                              setState(() {
                                _commands.execute(
                                  CreateArchitectRoofPlane(
                                    storeyId: _project.activeStoreyId,
                                    roof: created,
                                  ),
                                );
                                _selectionIds
                                  ..clear()
                                  ..add(created.id);
                                _selectedElementId = created.id;
                              });
                              _saveBiMProjectIfAttached();
                              HapticFeedback.mediumImpact();
                            }
                          },
                          onUndoDraftPoint: () =>
                              setState(() => _roofTool.undoLastDraftPoint()),
                          onCancelDraft: () =>
                              setState(() => _roofTool.clearDraft()),
                        ),
                      ),
                    // Floating Overshoot Notice Banner
                    if (_activeOvershoot != null && !_is3DView)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: ArchitectWallOvershootBanner(
                            overshoot: _activeOvershoot!,
                            onTrim: () => _handleTrimOvershoot(_activeOvershoot!),
                            onDismiss: () =>
                                _handleDismissOvershoot(_activeOvershoot!),
                          ),
                        ),
                      ),
                    if (_wallJoinSourceId != null && !_is3DView)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: Material(
                            key: const ValueKey('architect-wall-join-banner'),
                            color: const Color(0xEE1E242C),
                            borderRadius: BorderRadius.circular(24),
                            elevation: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.call_merge,
                                    color: Color(0xFF00E5FF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.architectWallJoinSelectSecond,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    key: const ValueKey(
                                      'architect-wall-join-cancel',
                                    ),
                                    onTap: () => setState(() {
                                      _wallJoinSourceId = null;
                                      _wallJoinPointer = null;
                                    }),
                                    child: const Icon(
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
                  ],
                ),
              ),

              // Floating Zone Property Inspector Card if a zone is selected
              if (!_multiSelect && _effectiveSelection.length == 1 &&
                  _selectedZone != null && !_is3DView)
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
                  _effectiveSelection.length == 1 &&
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

  Offset? get _draftCancelAnchor =>
      _dimensionAnchors.firstOrNull?.point ??
      _draftStart ??
      _axisTool.draftStart ??
      _zoneTool.draftPoints.firstOrNull ??
      _elementTool.slabDraftPoints.firstOrNull ??
      _roofTool.draftPoints.firstOrNull;
  int? _draftCancelPointer;
  Rect? _renderedDraftCancelRect, _renderedDraftConfirmRect;
  List<ArchitectDimensionEditHandle> _renderedDimensionEditHandles = [];
  bool get _canConfirmDimension {
    final draft = _dimensionDraft;
    return _activeTool == ArchitectTool.dimension &&
        draft != null &&
        draft.length >= .001 &&
        draft.dimensionPoints.length >= 2;
  }

  Rect? get _draftCancelRect {
    final anchor = _draftCancelAnchor;
    if (anchor == null ||
        _viewport.size.width < 48 ||
        _viewport.size.height < 48) {
      return null;
    }
    final point = _viewport.toScreen(anchor);
    final width = _canConfirmDimension && _viewport.size.width >= 92
        ? 84.0
        : 40.0;
    return Rect.fromLTWH(
      (point.dx + 1).clamp(4.0, _viewport.size.width - width - 4),
      (point.dy - 48).clamp(4.0, _viewport.size.height - 40),
      40,
      40,
    );
  }

  Rect? get _draftConfirmRect {
    final cancel = _draftCancelRect;
    return cancel != null && _canConfirmDimension && _viewport.size.width >= 92
        ? cancel.shift(const Offset(44, 0))
        : null;
  }

  List<ArchitectDimensionEditHandle> get _dimensionEditHandles {
    final draft = _dimensionDraft;
    if (_activeTool != ArchitectTool.dimension ||
        !_dimensionChainMode ||
        _dimensionPlacing ||
        _dimensionChoosingDirection ||
        draft == null) {
      return const [];
    }
    return ArchitectDimensionEditOverlay.layout(
      dimension: draft,
      viewport: _viewport,
      excluded: [?_draftCancelRect, ?_draftConfirmRect],
    );
  }

  bool _draftOverlayContains(Offset position) =>
      _renderedDraftCancelRect?.contains(position) == true ||
      _renderedDraftConfirmRect?.contains(position) == true ||
      _renderedDimensionEditHandles.any((h) => h.rect.contains(position));

  Widget _buildDraftCancel() => AnimatedBuilder(
    animation: Listenable.merge([_viewport, _previewRevision]),
    builder: (context, _) {
      final rect = _draftCancelRect;
      _renderedDraftCancelRect = rect;
      _renderedDraftConfirmRect = _draftConfirmRect;
      if (rect == null) return const SizedBox.shrink();
      final confirm = _draftConfirmRect;
      return Stack(
        children: [
          Positioned(
            left: rect.left,
            top: rect.top,
            child: IconButton(
              key: const ValueKey('architect-draft-cancel'),
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: context.l10n.cancel,
              icon: SizedBox(
                width: 40,
                height: 40,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    key: const ValueKey('architect-draft-cancel-mark'),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              onPressed: _cancelDrafting,
            ),
          ),
          if (confirm != null)
            Positioned.fromRect(
              rect: confirm,
              child: IconButton(
                key: const ValueKey('architect-dimension-confirm'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: context.l10n.architectDimensionConfirm,
                onPressed: _commitDimensionDraft,
                icon: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2E7D32),
                      ),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

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
            _duplicateMove == null &&
            _effectiveSelection.isNotEmpty &&
            !_multiSelect &&
            !_moveSelection &&
            _wallCutIds.isEmpty &&
            _wallExtendId == null,
        touchHoldToPlace: _canPlaceWithMarker,
        onToolHoldStart: _beginPlacementHold,
        onSelectionHold: _duplicateMove == null ? _onSelectionHold : null,
        onContextHold: _duplicateMove == null ? _onContextHold : null,
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
            ColoredBox(
              key: const ValueKey('architect-canvas'),
              color: _canvasPalette.background,
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: ArchitectUnderlayPainter(
                  palette: _canvasPalette,
                  document: _currentUnderlayDoc,
                  frame: widget.underlayFrame,
                  viewport: _viewport,
                  visibility: Map.of(_underlayLayerVisibility),
                ),
              ),
            ),
            if (_showGhostStoreys && _commands.isPlan)
              RepaintBoundary(
                child: CustomPaint(
                  painter: ArchitectGhostStoreyPainter(
                    project: _project,
                    viewport: _viewport,
                    palette: _canvasPalette,
                  ),
                ),
              ),
            if (!_commands.isPlan)
              RepaintBoundary(child: AnimatedBuilder(
                animation: _viewport,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('architect-workspace-projection'),
                  painter: _workspaceProjectionPainter,
                ),
              )),
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
                      final lastAnchor = _draftStart ??
                          _axisTool.draftStart ??
                          _zoneTool.draftPoints.lastOrNull ??
                          _elementTool.slabDraftPoints.lastOrNull ??
                          _roofTool.draftPoints.lastOrNull;
                      final liveDim = lastAnchor != null &&
                              (target - lastAnchor).distance > 0.01
                          ? _project.units.format(
                              (target - lastAnchor).distance,
                              decimals: 2,
                            )
                          : null;
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
                          liveDimensionText: liveDim,
                          l10n: context.l10n,
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
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<int>(
                  valueListenable: _previewRevision,
                  builder: (_, revision, child) => CustomPaint(
                    key: const ValueKey('architect-dimension-chain-preview'),
                    painter: ArchitectDimensionChainPreview(
                      dimension: _dimensionDraft ?? _singleDimensionPreview,
                      viewport: _viewport,
                      units: _project.units,
                      dimensionScale: _project.dimensionScale,
                      palette: _canvasPalette,
                      storey: _project.activeStorey,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_viewport, _previewRevision]),
                builder: (_, _) {
                  // Hit testing must use the controls that were actually drawn,
                  // even if a camera resize has just scheduled another frame.
                  _renderedDimensionEditHandles = _dimensionEditHandles;
                  return ArchitectDimensionEditOverlay(
                    handles: _renderedDimensionEditHandles,
                    onRemove: _removeDimensionReference,
                  );
                },
              ),
            ),
            Positioned.fill(child: _buildDraftCancel()),
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
                      border: Border.all(color: Colors.white24, width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _activeTool == ArchitectTool.dimension
                            ? (_dimensionChoosingDirection
                                  ? context.l10n.architectDimensionDirectionHint
                                  : _dimensionPlacing
                                  ? context.l10n.architectDimensionPositionHint
                                  : _dimensionEditing != null
                                  ? context.l10n.architectDimensionEditPointsHint
                                  : _dimensionStyle ==
                                        ArchitectDimensionStyle.interior
                                  ? context.l10n.architectDimensionInteriorHint
                                  : _dimensionChainMode
                                  ? context.l10n.architectDimensionChainHint
                                  : _draftStart == null
                                  ? context.l10n.architectDimensionStartHint
                                  : context.l10n.architectDimensionEndHint)
                            : _wallCutIds.isNotEmpty
                            ? (_wallCutStroke
                                  ? (_wallCutStart == null
                                        ? context
                                              .l10n
                                              .architectWallSplitSurfaceHint
                                        : context
                                              .l10n
                                              .architectWallSplitDirectionHint)
                                  : context.l10n.architectWallCutHint)
                            : _wallExtendId != null
                            ? context.l10n.architectWallExtendHint
                            : _effectiveSelection.isNotEmpty
                            ? (_activeTool == ArchitectTool.select && !_moveSelection
                                  ? context.l10n.architectSelectionCycleHelp
                                  : context.l10n.architectEditHoldHint)
                            : _activeTool == ArchitectTool.select
                            ? context.l10n.architectSelectionCycleHelp
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
            title: _effectiveSelection.length > 1
                ? ArchitectSelection.summary(
                    _project,
                    _effectiveSelection,
                    context.l10n,
                  )
                : null,
            onActionSelected: _handleRadialAction,
            onDismiss: () => setState(() => _radialMenuScreenPosition = null),
          ),
        ),
      if (_duplicateMove != null)
        Positioned(
          top: 8,
          left: 8,
          right: 64,
          child: Material(
            color: const Color(0xE61E1E26),
            borderRadius: BorderRadius.circular(8),
            elevation: 4,
            shadowColor: Colors.black54,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1.0),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.dragDuplicateHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(_cancelActiveDrags);
                      _repaintPreview();
                    },
                    child: Text(context.l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      _buildWallClearanceOverlay(),
      _buildPolygonDistanceOverlay(),
      _buildShapeDimensionOverlay(),
      if (_activeTool == ArchitectTool.dimension &&
          !_multiSelect &&
          _effectiveSelection.isEmpty)
        Positioned(top: 8, left: 8, right: 8, child: _buildDimensionBar()),
      if (_selectedWallIds.isNotEmpty)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topLeft,
            child: _buildWallSelectionActions(_selectedWallIds),
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
                elevation: 4,
                shadowColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.white24),
                ),
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
                          iconEnabledColor: Colors.white,
                          iconDisabledColor: Colors.white38,
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
                        icon: Icon(
                          Icons.flip,
                          size: 20,
                          color: _wallExteriorSide == WallExteriorSide.right
                              ? const Color(0xFF00E5FF)
                              : Colors.white,
                        ),
                        onPressed: () => setState(() {
                          _wallStartAttachment = null;
                          _wallExteriorSide =
                              _wallExteriorSide == WallExteriorSide.left
                              ? WallExteriorSide.right
                              : WallExteriorSide.left;
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
                              : Colors.white70,
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
                            color: Colors.white,
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
    if (label == null) return null;
    final l10n = context.l10n;
    if (label == 'Merge' || label == 'Обединяване (Merge)') {
      return l10n.snapMerge;
    }
    if (label.endsWith(' (Corner)') || label.endsWith(' (Ъгъл)')) {
      final name = label.replaceAll(' (Corner)', '').replaceAll(' (Ъгъл)', '');
      return '$name (${l10n.snapCorner})';
    }
    if (label.endsWith(' (Edge)') || label.endsWith(' (Ръб)')) {
      final name = label.replaceAll(' (Edge)', '').replaceAll(' (Ръб)', '');
      return '$name (${l10n.snapEdge})';
    }
    if (label.contains(' × ')) {
      final parts = label.split(' × ');
      return parts.map((p) => _localizedSnapLabel(p) ?? p).join(' × ');
    }
    if (label.startsWith('Axis ')) {
      return '${l10n.architectToolAxis} ${label.substring(5)}';
    }
    if (label.startsWith('Ос ')) {
      return '${l10n.architectToolAxis} ${label.substring(3)}';
    }
    return switch (label) {
      'Endpoint' || 'Axis endpoint' => l10n.snapEndpoint,
      'Vertex' => l10n.snapPoint,
      'Midpoint' => l10n.snapMidpoint,
      'Center' => l10n.snapCenter,
      'Intersection' || 'Axis intersection' => l10n.snapIntersection,
      'Edge' => l10n.snapNearest,
      'Perpendicular' => l10n.snapPerpendicular,
      'Alignment' => l10n.architectWallAlign,
      'Alignment with Point 1' => l10n.snapAlignPoint1,
      '30 cm' => l10n.architectDimensionSnap30cm,
      '40 cm' => l10n.architectDimensionSnap40cm,
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
    var project = _duplicateMove?.preview ?? _elementMovePreview ?? _project;
    if (_dimensionEditing != null) {
      project = project.updateActiveStorey(
        project.activeStorey.copyWith(
          dimensions: project.activeStorey.dimensions
              .where((d) => d.id != _dimensionEditing!.id)
              .toList(),
        ),
      );
    }
    return _axisTool.isDraggingHandle || _axisTool.isMovingAxis
        ? project.copyWithGridAxes(_axisTool.previewAxes(project.gridAxes))
        : project;
  }

  Architect2dPainter _makePainter(ArchitectPaintLayer layer) =>
      Architect2dPainter(
        l10n: context.l10n,
        palette: _canvasPalette,
        paintGrid: _showDrawingGrid,
        showUpperOverhangs: _showUpperOverhangs,
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
        activeDraftStart: _activeTool == ArchitectTool.dimension ? null : _draftStart,
        activeDraftEnd: _activeTool == ArchitectTool.dimension ? null : _draftEnd,
        stairPreview: _activeTool == ArchitectTool.stair && _draftStart != null
            ? _stairAt(_draftStart!, _draftEnd ?? _draftStart!) : null,
        activeWallThickness: _wallThickness,
        activeWallReference: _wallReference,
        activeWallExteriorSide: _wallExteriorSide,
        showWallCursor: !_placingWithHold,
        wallClearances: _wallClearances,
        openingClearances: _openingClearances,
        showOpeningClearanceBadges: _showOpeningClearanceBadges,
        doorPreview: _doorPreview,
        windowPreview: _windowPreview,
        wallTrimSpan:
            _wallCutIds.isNotEmpty && !_wallCutStroke && _cursorModel != null
            ? _trimSpanAt(_cursorModel!)
            : null,
        wallCutGuideLine: () {
          if (_wallCutIds.isEmpty || _wallCutStart != null) return null;
          final pos = _cursorModel;
          if (pos == null) return null;
          final surface = _findNearestSurface(pos);
          final anchor = surface?.anchor ?? pos;
          final dir = surface?.direction ?? const Offset(1, 0);
          final guideLen = math.max(120 / _currentScale, 3.0);
          return (anchor - dir * guideLen, anchor + dir * guideLen);
        }(),
        wallCutAnchor: () {
          if (_wallCutIds.isEmpty) return null;
          if (_wallCutStart != null) return _wallCutStart;
          final pos = _cursorModel;
          if (pos == null) return null;
          final surface = _findNearestSurface(pos);
          return surface?.anchor ?? pos;
        }(),
        wallCutLine: () {
          if (_wallCutIds.isEmpty || _wallCutStart == null) return null;
          final pos = _cursorModel ?? _wallCutStart!;
          if (_wallCutConfirmedDir != null) {
            final delta = pos - _wallCutStart!;
            final dir = _snappedCutDirection(delta);
            final cutLen = math.max(delta.distance + 40 / _currentScale, 4.0);
            return (
              _wallCutStart! - dir * cutLen,
              _wallCutStart! + dir * cutLen,
            );
          } else {
            return (_wallCutStart!, pos);
          }
        }(),
        activeWallInsulation: _activeWallType?.insulationThickness,
        activeWallTypeId: _activeWallType?.id,
        activeSnapLabel: _localizedSnapLabel(_activeSnapLabel),
        selectedElementId: _selectedElementId,
        selectedElementIds: _effectiveSelection,
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
        zoneCategoryName: _activeZoneCategory.localizedName(context.l10n),
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
        roofTool: _roofTool,
        polygonEditInvalid: _polygonEditor.invalid,
        polygonLeaderLine: _polygonEditor.leaderLine,
        wallJoinLeaderLine: _wallJoinLeaderLine,
        activeOvershoot: _activeOvershoot,
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
