import '../../../core/services/ui_settings_service.dart';

import '../models/architect_floor_drain.dart';

import '../services/architect_floor_drain_commands.dart';

import '../services/architect_floor_drain_geometry.dart';

import '../widgets/architect_floor_drain_bar.dart';
import '../services/architect_marquee_tool.dart';

import '../rendering/architect_floor_drain_painter_helper.dart';

import '../services/architect_closed_contour.dart';

import '../widgets/architect_terrain_editor.dart';

import '../models/architect_line_style.dart';

import '../models/architect_hatch_pattern.dart';
import '../models/architect_drawing_color.dart';

import '../widgets/architect_hatch_picker.dart';

import '../services/architect_hatch_patterns.dart';

import '../widgets/architect_line_style_picker.dart';

import '../services/architect_line_styles.dart';

import '../services/architect_line_editing.dart';

import '../services/architect_offset.dart';
import '../services/architect_rotation.dart';
import '../widgets/architect_rotation_overlay.dart';
import '../widgets/architect_transform_point_input.dart';
import '../widgets/architect_offset_direction.dart';

import '../../bim_editing/widgets/bim_offset_dialog.dart';

import '../services/architect_apartment_zones.dart';

import '../widgets/architect_sheets_screen.dart';

import '../widgets/architect_annotation_settings.dart';

import '../services/architect_drawing_publisher.dart';

import '../rendering/architect_vector_scene.dart';

import '../widgets/architect_wall_types_manager.dart';

import '../widgets/architect_wall_composition_editor.dart';

import '../widgets/architect_wall_radius_dialog.dart';

import '../widgets/architect_wall_plinth_dialog.dart';

import '../services/architect_wall_compositions.dart';

import '../widgets/architect_wall_thickness_dialog.dart';

import '../widgets/architect_slab_layers_dialog.dart';

import '../widgets/architect_roof_layers_dialog.dart';
import '../services/architect_roof_settings_commands.dart';
import '../widgets/architect_roof_number_field.dart';
import '../widgets/architect_auto_roof_preview_dialog.dart';

import '../widgets/architect_roof_bar.dart';

import '../rendering/architect_roof_painter_helper.dart';

import '../services/architect_roof_geometry.dart';

import '../services/architect_roof_drainage_geometry.dart';

import '../services/architect_roof_tool.dart';

import '../widgets/architect_building_sections_screen.dart';

import '../widgets/architect_section_visibility_dialog.dart';

import '../widgets/architect_elevations_screen.dart';

import '../widgets/architect_workspace_view_placement.dart';
import '../widgets/architect_view_direction_picker.dart';
import '../widgets/architect_view_properties_dialog.dart';
import '../models/architect_section.dart';
import '../models/architect_elevation.dart';

import '../widgets/architect_projection_editor.dart';

import '../../bim_editing/widgets/bim_edit_actions.dart';

import '../../bim_editing/geometry/bim_contour_drafting_geometry.dart';

import 'dart:math' as math;

import 'dart:async';

import 'dart:convert';

import '../models/architect_zone_presets.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter/gestures.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/l10n_extensions.dart';

import '../../cad_3d/cad_3d_controller.dart';

import '../widgets/architect_3d_viewport.dart';

import '../../dxf_viewer/models/dxf_models.dart';

import '../../bim_projects/models/bim_work_project.dart';

import '../../bim_projects/models/bim_coordinate_frame.dart';

import "../models/architect_component_definition.dart";

import "../services/component_library_service.dart";

import "../widgets/architect_component_library_dialog.dart";

import "../widgets/component_studio_dialog.dart";

import '../widgets/component_dimensions_dialog.dart';

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

import '../rendering/architect_snap_helper.dart';

import '../rendering/architect_midpoint_tracking.dart';

import '../rendering/architect_wall_snap.dart';

import '../rendering/architect_column_snap.dart';

import '../rendering/architect_wall_geometry.dart';

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

import '../widgets/architect_zone_schedule_dialog.dart';

import '../widgets/architect_zone_table_bar.dart';

import '../rendering/architect_zone_painter_helper.dart';

import '../services/architect_room_detector.dart';

import '../widgets/architect_viewport.dart';

import '../widgets/architect_wall_drafting_panel.dart';

import 'fenestration_editor_screen.dart';

import '../models/architect_fenestration_style.dart';

import '../services/fenestration_library_service.dart';

import '../services/architect_wall_overshoot_detector.dart';

import '../widgets/architect_wall_overshoot_banner.dart';



// ============================================================================

// TABLE OF CONTENTS (grep: "=== SECTION:")

// 1.  === SECTION: WIDGET DECLARATION & PUBLIC API ===

// 2.  === SECTION: STATE & TOOL CONTROLLERS ===

// 3.  === SECTION: COORDINATE TRANSFORMS (SCREEN <-> MODEL) ===

// 4.  === SECTION: 2D POINTER & TOUCH HANDLING (TOOL INPUT FROM ARCHITECT VIEWPORT) ===

// 5.  === SECTION: ZONE EDITING & MUTATION HANDLERS ===

// 6.  === SECTION: WALL & DOOR CONCEPT DRAFTING ===

// 7.  === SECTION: WALL SPLIT, SURFACE DETECTION & CLEARANCES ===

// 8.  === SECTION: FENESTRATION (DOORS, WINDOWS) & RADIAL ACTIONS ===

// 9.  === SECTION: SELECTION ACTIONS, BARS & TOOLBARS ===

// 10. === SECTION: DYNAMIC GRID AXES ACTIONS ===

// 11. === SECTION: MAIN BUILD METHOD & WORKSPACE LAYOUT ===

// 12. === SECTION: DIAGNOSTIC LOGS DIALOG (ARCHITECT LOGGER) ===

// 13. === SECTION: 2D CANVAS VIEWPORT (LAYERED MODEL SPACE) ===

// 14. === SECTION: 3D SOLID VIEWPORT ===

// ============================================================================



// === SECTION: WIDGET DECLARATION & PUBLIC API ===

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

  bool _printPreview = false;

  final _scaledProjects = Expando<Map<int, ArchitectProject>>();

  ArchitectProject _withDrawingScale(ArchitectProject source) {

    final n = _publicationScale;

    if (source.dimensionScale.denominator == n) return source;

    return (_scaledProjects[source] ??= {}).putIfAbsent(

      n,

      () => source.copyWith(

        dimensionScale: ArchitectDimensionScale.values.firstWhere(

          (s) => s.denominator == n,

        ),

      ),

    );

  }



  ArchitectPublicationSources get _publicationSources =>

      ArchitectPublicationSources(

        underlays: _showUnderlay ? _underlaysByStorey : const {},

        frame: widget.underlayFrame,

        visibility: _underlayLayerVisibility,

      );

  int get _publicationScale =>

      _modelCommands.project.document.viewScales[_workspaceViewKey] ??

      _project.dimensionScale.denominator;

  ArchitectSavedDrawing get _publicationView => ArchitectSavedDrawing(

    id: _workspaceViewKey,

    sourceId: _commands.isPlan

        ? _modelCommands.project.activeStoreyId

        : _commands.viewId!,

    kind: ArchitectDrawingKind.values.byName(_commands.view.name),

    scale: _publicationScale,

  );

  Future<void> _openSheets() async {

    final drawing = await Navigator.push<ArchitectSavedDrawing>(

      context,

      MaterialPageRoute(

        builder: (_) => ArchitectSheetsScreen(

          controller: _modelCommands,

          sources: _publicationSources,

        ),

      ),

    );

    if (drawing != null && mounted) {

      _selectWorkspaceView(

        ArchitectWorkspaceView.values.byName(drawing.kind.name),

        drawing.sourceId,

      );

    }

  }



  Widget _publicationToolbar({bool compact = false}) {

    final l = context.l10n;

    final available = _commands.hasView && !_is3DView;

    void action(String key) {

      if (key == 'sheets') _openSheets();

      if (key == 'model') setState(() => _printPreview = false);

      if (key == 'preview' && available) {

        _cancelDrafting();

        _clearSelection();

        setState(() => _printPreview = !_printPreview);

      }

      if (key == 'annotations' && available) {

        showArchitectAnnotationSettings(

          context,

          _modelCommands,

          _publicationView,

          _publicationScale,

        );

      }

    }



    final scale = DropdownButton<int>(

      isExpanded: compact,

      value: _publicationScale,

      dropdownColor: const Color(0xFF1E1E26),

      style: const TextStyle(color: Colors.white, fontSize: 12),

      iconEnabledColor: Colors.white70,

      underline: const SizedBox.shrink(),

      items: [

        for (final n in ArchitectDrawingScale.presets)

          DropdownMenuItem(value: n, child: Text('1:$n')),

      ],

      onChanged: available

          ? (n) {

              if (n == null) return;

              final p = _modelCommands.project;

              _modelCommands.replaceView(

                p.copyWith(

                  document: p.document.copyWith(

                    viewScales: {

                      ...p.document.viewScales,

                      _workspaceViewKey: n,

                    },

                  ),

                ),

              );

              setState(() {});

            }

          : null,

    );

    if (compact) {

      return Row(

        children: [

          Expanded(child: scale),

          PopupMenuButton<String>(

            tooltip: l.architectSheets,

            icon: const Icon(Icons.layers_outlined, color: Colors.white),

            onSelected: action,

            itemBuilder: (_) => [

              PopupMenuItem(value: 'model', child: Text(l.architectModel)),

              PopupMenuItem(value: 'sheets', child: Text(l.architectSheets)),

              PopupMenuItem(

                value: 'preview',

                enabled: available,

                child: Text(l.architectPrintPreview),

              ),

              PopupMenuItem(

                value: 'annotations',

                enabled: available,

                child: Text(l.architectAnnotationSettings),

              ),

            ],

          ),

        ],

      );

    }

    return SingleChildScrollView(

      scrollDirection: Axis.horizontal,

      child: Row(

        children: [

          TextButton(

            style: TextButton.styleFrom(foregroundColor: Colors.white),

            onPressed: () => action('model'),

            child: Text(l.architectModel),

          ),

          TextButton(

            style: TextButton.styleFrom(foregroundColor: Colors.white),

            onPressed: () => action('sheets'),

            child: Text(l.architectSheets),

          ),

          scale,

          IconButton(

            color: Colors.white,

            tooltip: l.architectPrintPreview,

            onPressed: available ? () => action('preview') : null,

            icon: Icon(_printPreview ? Icons.visibility : Icons.print_outlined),

          ),

          IconButton(

            color: Colors.white,

            tooltip: l.architectAnnotationSettings,

            onPressed: available ? () => action('annotations') : null,

            icon: const Icon(Icons.text_fields),

          ),

        ],

      ),

    );

  }



  Widget _workspaceNavigationBar() {

    final compact = MediaQuery.sizeOf(context).width < 800;

    return Material(

      color: const Color(0xFF1E1E26),

      child: SizedBox(

        height: 48,

        child: Row(

          children: [

            Expanded(

              child: ArchitectWorkspaceViewBar(

                project: _modelCommands.project,

                view: _commands.view,

                viewId: _commands.viewId,

                lastViewIds: _lastViewIds,

                onSelected: _selectWorkspaceView,

                onManage: _manageWorkspaceViews,

                onDraft: _draftWorkspaceView,

              ),

            ),

            SizedBox(

              width: compact ? 120 : 340,

              child: _publicationToolbar(compact: compact),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildPublicationCanvas() {

    final scene = ArchitectDrawingPublisher.build(

      _modelCommands.project,

      _publicationView,

      _publicationScale,

      context.l10n,

      sources: _publicationSources,

    );

    return ColoredBox(

      color: Colors.white,

      child: ArchitectViewport(

        controller: _viewport,

        singlePointerPan: true,

        isDraggingHandle: () => false,

        onToolDown: (_) {},

        onToolMove: (_) {},

        onToolHover: (_) {},

        onToolUp: (_) {},

        onToolCancel: () {},

        onFirstLayout: (_) {},

        child: AnimatedBuilder(

          animation: _viewport,

          builder: (_, _) => CustomPaint(

            painter: _PublicationPreviewPainter(

              scene,

              _viewport.scale,

              _viewport.translation,

            ),

          ),

        ),

      ),

    );

  }



  ArchitectProject? _projectionSource;

  ({ArchitectWorkspaceView type, String? id, String mode})? _viewDraft;

  ({ArchitectProject source, ArchitectTool tool, Offset start, Offset end})? _viewDirectionDraft;



  void _draftWorkspaceView(

    ArchitectWorkspaceView type,

    String? id,

    String mode,

  ) {

    if (mode == 'new') {
      _selectWorkspaceView(ArchitectWorkspaceView.plan, _modelCommands.project.activeStoreyId);
      _changeTool(type == ArchitectWorkspaceView.section ? ArchitectTool.section : ArchitectTool.elevation,
        toggle: false);
      return;
    }

    if (mode == 'visibility' && type == ArchitectWorkspaceView.section) {

      showArchitectSectionVisibility(context, _modelCommands, sectionId: id);

      return;

    }

    if (mode == 'straight') {

      final p = _modelCommands.project;

      _modelCommands.commit(

        p.copyWith(

          sections: [

            for (final s in p.sections)

              if (s.id == id && type == ArchitectWorkspaceView.section)

                s.copyWith(steps: const [])

              else

                s,

          ],

          elevations: [

            for (final e in p.elevations)

              if (e.id == id && type == ArchitectWorkspaceView.elevation)

                e.copyWith(steps: const [])

              else

                e,

          ],

        ),

      );

      return;

    }

    _selectWorkspaceView(

      ArchitectWorkspaceView.plan,

      _modelCommands.project.activeStoreyId,

    );

    setState(

      () =>

          _viewDraft = (type: type, id: mode == 'new' ? null : id, mode: mode),

    );

  }



  String? _projectionKey;

  ArchitectBuildingElevation? _facadeGeometry;

  ArchitectBuildingSection? _sectionGeometry;



  String get _workspaceViewKey => _commands.isPlan

      ? 'plan:${_modelCommands.project.activeStoreyId}'

      : '${_commands.view.name}:${_commands.viewId}';



  void _selectWorkspaceView(ArchitectWorkspaceView type, String? id) {

    _terrainDrafting = false;

    _cancelDrafting();

    _clearSelection();

    _viewCameras[_workspaceViewKey] = (

      scale: _viewport.scale,

      translation: _viewport.translation,

    );

    if (id == 'add_roof_plan') {

      _modelCommands.commit(_modelCommands.project.ensureRoofStorey());

      _saveBiMProjectIfAttached();

      id = _modelCommands.project.roofStorey?.id;

    }

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

    ArchitectTool? draftTool;

    var terrainRequested = false;

    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => type == ArchitectWorkspaceView.elevation

            ? ArchitectElevationsScreen(

                controller: _modelCommands,

                initialSelectedId: selected,

                onViewSelected: (id) => selected = id,

                onDraftRequested: (tool) => draftTool = tool,

                onTerrainRequested: () => terrainRequested = true,

              )

            : ArchitectBuildingSectionsScreen(

                controller: _modelCommands,

                initialSelectedId: selected,

                onViewSelected: (id) => selected = id,

                onDraftRequested: (tool) => draftTool = tool,

              ),

      ),

    );

    if (mounted) {

      _selectWorkspaceView(type, selected);

      if (draftTool != null) _changeTool(draftTool!);

      if (terrainRequested) _startTerrainDraft();

    }

  }



  String? _selectedSectionRoofId;

  double? _sectionRoofDragStartModelY;

  double? _sectionRoofDragInitialOffset;

  double? _sectionRoofDragPreviewOffset;
  bool _isDraggingRoofKnuckle = false;
  String? _draggingRoofKnuckleId;
  double? _knuckleDragInitialBreakDist;
  Offset? _knuckleDragStartPoint;



  Offset _modelToSection(Offset rawModel) => Offset(rawModel.dx, -rawModel.dy);



  ArchitectProject get _projectionModelProject {

    final base = _withDrawingScale(_modelCommands.project);

    if (_selectedSectionRoofId == null ||

        _sectionRoofDragPreviewOffset == null) {

      return base;

    }

    return base.copyWith(

      storeys: [

        for (final st in base.storeys)

          if (st.roofs.any((r) => r.id == _selectedSectionRoofId))

            st.copyWith(

              roofs: [

                for (final r in st.roofs)

                  if (r.id == _selectedSectionRoofId)

                    r.copyWith(

                      baseElevationOffset: _sectionRoofDragPreviewOffset!,

                      attachToWalls: false,

                    )

                  else

                    r,

              ],

            )

          else

            st,

      ],

    );

  }



  void _cacheProjection() {

    final original = _projectionModelProject;

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

          .where((e) => e.id == _commands.viewId)

          .firstOrNull;

      if (e != null) {

        _facadeGeometry = ArchitectBuildingElevation.build(original, e);

      }

    } else if (_commands.view == ArchitectWorkspaceView.section) {

      final s = original.sections

          .where((e) => e.id == _commands.viewId)

          .firstOrNull;

      if (s != null) {

        _sectionGeometry = ArchitectBuildingSection.build(original, s).forView(s);

      }

    }

  }



  ArchitectSectionDrawing? get _workspaceSectionDrawing {

    _cacheProjection();

    final proj = _projectionModelProject;

    final cut = proj.sections

        .where((e) => e.id == _commands.viewId)

        .firstOrNull;

    if (cut == null || _sectionGeometry == null) return null;

    return ArchitectSectionDrawing(

      proj,

      cut,

      _sectionGeometry!,

      context.l10n,

      _canvasPalette.isDark

          ? const ColorScheme.dark()

          : const ColorScheme.light(),

      null,

      Theme.of(context).textTheme.bodyMedium?.fontFamily,

      _selectedSectionRoofId,

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

    final scope = ArchitectTextScope(

      _project.document,

      _workspaceViewKey,

      _publicationScale,

      _viewport.scale,

      units: _project.units,

      decimals: _project.distanceDecimals,

    );

    final centre = _viewport.visibleRect.center;

    final upCentre = Offset(centre.dx, -centre.dy);

    if (_facadeGeometry != null) {

      return ArchitectStyledPainter(

        ArchitectFacadePainter(

          _facadeGeometry!,

          upCentre,

          _viewport.scale,

          fill: _canvasPalette.background,

          stroke: _canvasPalette.foreground(Colors.black),

          fontFamily: 'ArchitectNoto',

        ),

        scope,

      );

    }

    final drawing = _workspaceSectionDrawing;

    return drawing == null

        ? null

        : ArchitectStyledPainter(

            ArchitectBuildingSectionPainter(drawing, upCentre, _viewport.scale),

            scope,

          );

  }



  Widget _nativeProjectionEditor() => AnimatedBuilder(

    animation: Listenable.merge([_viewport, _modelCommands]),

    builder: (_, _) {

      _cacheProjection();

      final original = _modelCommands.project;

      final facade = original.elevations

          .where((e) => e.id == _commands.viewId)

          .firstOrNull;

      final cut = original.sections

          .where((e) => e.id == _commands.viewId)

          .firstOrNull;

      final paths =

          _facadeGeometry?.elementPaths ??

          _sectionGeometry?.elementPaths ??

          <String, Path>{};

      return ArchitectProjectionEditor(

        key: ValueKey('workspace-editor:$_workspaceViewKey'),

        controller: _modelCommands,

        paths: paths,

        roofProfiles: _sectionGeometry?.roofProfiles ?? const {},

        elevation: _commands.view == ArchitectWorkspaceView.elevation,

        origin: facade?.centre ?? cut?.drawingOrigin ?? Offset.zero,

        right: facade?.right ?? cut?.drawingRight ?? const Offset(1, 0),

        scale: _viewport.scale,

        toView: (p) => _modelToSection(_screenToModel(p)),

        toScreen: (p) => _viewport.toScreen(Offset(p.dx, -p.dy)),

        onNavigate: (delta, factor, focal) => _viewport.navigate(

          previousFocal: focal - delta,

          focal: focal,

          scaleFactor: factor,

        ),

        onMissTap: (p) => _handleTap(_screenToModel(p)),

      );

    },

  );



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

      id: _dimensionEditing?.id ?? 'dimension-preview',

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



  bool _isElementAllowedForTool(String id, ArchitectTool tool) {

    if (tool == ArchitectTool.select) return true;

    final storey = _project.activeStorey;

    return switch (tool) {

      ArchitectTool.wall => storey.walls.any((w) => w.id == id),

      ArchitectTool.door =>

        storey.walls.any((w) => w.doors.any((d) => d.id == id)),

      ArchitectTool.window =>

        storey.walls.any((w) => w.windows.any((win) => win.id == id)),

      ArchitectTool.column => storey.columns.any((c) => c.id == id),

      ArchitectTool.beam => storey.beams.any((b) => b.id == id),

      ArchitectTool.slab => storey.slabs.any((s) => s.id == id),

      ArchitectTool.roof =>

        storey.roofs.any((r) => r.id == id) ||

        _project.storeys.any((st) => st.roofs.any((r) => r.id == id)),

      ArchitectTool.opening => storey.openings.any((o) => o.id == id),

      ArchitectTool.stair => storey.stairs.any((s) => s.id == id),

      ArchitectTool.component => storey.components.any((c) => c.id == id),

      ArchitectTool.dimension => storey.dimensions.any((d) => d.id == id),

      ArchitectTool.level => storey.elevationMarkers.any((e) => e.id == id),

      ArchitectTool.text => storey.annotations.any((a) => a.id == id),

      ArchitectTool.cadLine => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.line),

      ArchitectTool.cadRect => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.rect),

      ArchitectTool.floorDrain => storey.floorDrains.any((d) => d.id == id),

      ArchitectTool.cadCircle => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.circle),

      ArchitectTool.hatch => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.hatch),

      ArchitectTool.axis => _project.gridAxes.any((a) => a.id == id),

      ArchitectTool.zone => storey.zones.any((z) => z.id == id),
      ArchitectTool.section => _project.sections.any((s) => s.id == id),
      ArchitectTool.elevation => _project.elevations.any((e) => e.id == id),

      _ => false,

    };

  }



  ArchitectTool _toolForElement(String id) => ArchitectTool.values.firstWhere(

    (tool) => tool != ArchitectTool.select && _isElementAllowedForTool(id, tool),

    orElse: () => ArchitectTool.select,

  );



  void _toggleMultiSelection() {

    final ids = _effectiveSelection;

    final primary = _selectedElementId ?? _selectedZoneId ?? ids.lastOrNull;

    final enable = !_multiSelect;

    _cancelDrafting();

    setState(() {

      _radialMenuScreenPosition = null;

      _polygonEditId = null;

      _polygonSelectedEdge = null;

      _moveSelection = false;

      _selectionCyclePoint = null;

      _lastTapTime = null;

      _interactionEpoch++;

      _multiSelect = enable;

      _selectionIds.clear();

      if (_multiSelect) {

        _selectionIds.addAll(ids);

        _activeTool = ArchitectTool.select;

        _selectionContextActive = false;

      } else {

        if (primary != null) _selectionIds.add(primary);

        _selectedElementId = primary;

        _selectedZoneId = _project.activeStorey.zones.any((z) => z.id == primary)

            ? primary

            : null;

        _activeTool = primary == null

            ? ArchitectTool.select

            : _toolForElement(primary);

        _selectionContextActive = primary != null;

        if (_activeTool == ArchitectTool.axis && primary != null) {

          _axisTool.selectAxis(primary);

        }

        if (_selectedZoneId != null) {

          _zoneTool.startEditingZone(

            _project.activeStorey.zones.firstWhere((z) => z.id == primary),

          );

        }

      }

    });

  }



  List<String> _selectionCandidates(Offset point) {

    final candidates = _rawSelectionCandidates(point);

    final group = _editingGroup;

    return group == null ? candidates : candidates.where(group.elementIds.contains).toList();

  }



  List<String> _rawSelectionCandidates(Offset point) {

    if (_acceptsAnySelection) {

      final first = _hitSelection(point);

      return <String>{

        ?first,

        if (_showFurnitureLayer)

          for (final component in _project.activeStorey.components.reversed)

            if (component.isVisible && component.containsPoint(point)) component.id,

        ..._elementTool.hitTestElements(

          _project.activeStorey,

          point,

          _currentScale,

          gridAxes: _project.gridAxes,

          annotationProject: _project,

          drawingViewKey: _workspaceViewKey,

        ),

        for (final zone in _project.activeStorey.zones)

          if ((Path()..addPolygon(zone.polygon, true)).contains(point)) zone.id,

        for (final axis in _project.gridAxes)

          if ((point - BimLineGeometry.closest(point, axis.start, axis.end))

                  .distance <=

              14 / _currentScale)

            axis.id,
        ?_hitSection(point),
        ?_hitElevation(point),
      }.toList();

    }



    if (_activeTool == ArchitectTool.axis) {

      final hitAxis = _axisTool.hitTestAxis(

        point,

        _project.gridAxes,

        tolerance: 14 / _currentScale,

      );

      return hitAxis != null ? [hitAxis.id] : const [];

    }



    if (_activeTool == ArchitectTool.zone) {

      final hitZone = _findZoneAt(point);

      return hitZone != null ? [hitZone.id] : const [];

    }

    if (_activeTool == ArchitectTool.section) {
      final hit = _hitSection(point);
      return hit != null ? [hit] : const [];
    }

    if (_activeTool == ArchitectTool.elevation) {
      final hit = _hitElevation(point);
      return hit != null ? [hit] : const [];
    }



    final toolElements = _elementTool.hitTestElementsForTool(

      _project.activeStorey,

      point,

      _currentScale,

      _activeTool,

      gridAxes: _project.gridAxes,

      annotationProject: _project,

      drawingViewKey: _workspaceViewKey,

    );

    final first = _hitSelection(point);

    return <String>{

      ?first,

      ...toolElements,

    }.where((id) => _isElementAllowedForTool(id, _activeTool)).toList();

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

    }

    return _selectionCycleIds[_selectionCycleIndex];

  }



  void _commitDimensionDraft() {

    final draft = _dimensionDraft;

    if (draft == null ||

        draft.length < .001 ||

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



  void _commitCreatedRoofPlanes(List<ArchitectRoofPlane> createdList) {

    if (createdList.isEmpty) return;

    setState(() {

      for (final plane in createdList) {

        _commands.execute(

          CreateArchitectRoofPlane(

            storeyId: _project.activeStoreyId,

            roof: plane,

          ),

        );

      }

      _selectionIds

        ..clear()

        ..addAll(createdList.map((p) => p.id));

      _selectedElementId = createdList.first.id;

      _polygonSelectedEdge = createdList.first.safeEavesEdgeIndex;

      _activeMagneticGuides = [];

      _activeSnapLabel = null;

    });

    _saveBiMProjectIfAttached();

    HapticFeedback.mediumImpact();

  }



  void _commitRoofDraft() {

    final createdList = _roofTool.finishDraft(

      storey: _project.activeStorey,

    );

    if (createdList != null && createdList.isNotEmpty) {

      _commitCreatedRoofPlanes(createdList);

    }

  }



  ArchitectDimensionAnchor _dimensionPointAnchor(Offset point) {

    final candidates = <String>{

      ?_hitSelection(point),

      ..._elementTool.hitTestElements(

        _project.activeStorey,

        point,

        _currentScale,

        gridAxes: _project.gridAxes,

        annotationProject: _project,

        drawingViewKey: _workspaceViewKey,

      ),

    };

    for (final id in candidates) {

      final wall = _project.activeStorey.walls

          .where((w) => w.id == id)

          .firstOrNull;

      if (wall != null) {

        final ratio = BimLineGeometry.parameter(

          point,

          wall.coreCenterStart,

          wall.coreCenterEnd,

          finite: false,

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

      if (anchor != null && (anchor.point - point).distance <= 1e-6) {

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

          decimals: _project.distanceDecimals,

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

    final hitIds = _elementTool.hitTestElements(

      _project.activeStorey,

      raw,

      _currentScale,

      gridAxes: _project.gridAxes,

      annotationProject: _project,

      drawingViewKey: _workspaceViewKey,

    ).toSet();



    // 1. Check if an opening (window or door) was picked

    ArchitectWall? openingHostWall;

    String? openingId;

    for (final w in _project.activeStorey.walls) {

      for (final o in [

        ...w.doors.map((d) => d.id),

        ...w.windows.map((win) => win.id),

      ]) {

        if (hitIds.contains(o)) {

          openingHostWall = w;

          openingId = o;

          break;

        }

      }

      if (openingId != null) break;

    }



    final snap = _snapDimensionPoint(raw);

    final anchors = <ArchitectDimensionAnchor>[];



    final candidateWalls = _project.activeStorey.walls

        .where((w) => hitIds.contains(w.id))

        .toList();



    if (_dimensionAllowPoint) {

      if (snap.isSnapped) {

        anchors.add(_dimensionPointAnchor(snap.point));

      } else {

        final candidateWall = candidateWalls.firstOrNull;

        if (candidateWall != null) {

          anchors.add(ArchitectDimensionChain.wallFaceAt(candidateWall, raw));

        } else {

          anchors.add(ArchitectDimensionAnchor(point: raw));

        }

      }

    } else if (openingId != null && openingHostWall != null) {

      _dimensionDirection ??= openingHostWall.unitVector;

      anchors.addAll(

        ArchitectDimensionChain.openingAnchors(openingHostWall, openingId),

      );

    } else if (candidateWalls.isNotEmpty) {

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

          final targetPoint =

              (snap.isSnapped &&

                  (snap.point - nearestEnd).distance <= 24 / _currentScale)

              ? snap.point

              : nearestEnd;

          if ((raw - nearestEnd).distance <= 24 / _currentScale ||

              (raw - targetPoint).distance <= 24 / _currentScale) {

            anchors.add(

              ArchitectDimensionAnchor(

                point: targetPoint,

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

          anchors.addAll(ArchitectDimensionChain.wallFaces(wall, raw));

        }

      }

    } else {

      final isCornerSnap =

          snap.snapLabel != null &&

          (snap.snapLabel == 'Vertex' ||

              snap.snapLabel == 'Endpoint' ||

              snap.snapLabel == 'Intersection' ||

              snap.snapLabel == 'Corner') &&

          (snap.point - raw).distance <= 20 / _currentScale;



      final isEdgeSnap =

          snap.snapLabel == 'Edge' ||

          snap.snapLabel == 'Nearest' ||

          snap.snapLabel == 'Midpoint';

      if (snap.isSnapped && isEdgeSnap) {

        anchors.add(_dimensionPointAnchor(snap.point));

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

      } else {

        for (final id in hitIds) {

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

      _offsetOptions,

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



  ArchitectTool _activeTool = ArchitectTool.select;

  bool _is3DView = false;

  bool _placingDownpipe = false;

  String? _downpipeRoofId;

  ArchitectCanvasPalette _canvasPalette = const ArchitectCanvasPalette.light();

  static const _darkCanvasPreference = 'architect_dark_canvas';

  bool _canvasPreferenceChanged = false;

  bool _showGhostStoreys = false;

  bool _showUpperOverhangs = true;

  bool _showDrawingGrid = true;

  double _axisWallCoreThickness = .25;

  double _handleOffsetLength = 50.0;

  ArchitectZonePresets _zonePresets = const ArchitectZonePresets();

  bool _viewPreferencesChanged = false;



  Future<void> _loadWorkspacePreferences() async {

    try {

      final preferences = await SharedPreferences.getInstance();

      if (!mounted || _viewPreferencesChanged) return;

      final savedPresets = preferences.getString('architect_zone_presets');

      final zonePresets = savedPresets == null

          ? const ArchitectZonePresets()

          : ArchitectZonePresets.fromJson(

              jsonDecode(savedPresets) as Map<String, dynamic>,

            );

      setState(() {

        _zonePresets = zonePresets;

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

        final handleOffset =

            preferences.getDouble('architect_handle_offset_length') ?? 50.0;

        _handleOffsetLength = handleOffset.isFinite && handleOffset >= 0.0

            ? handleOffset

            : 50.0;

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

      await preferences.setString(

        'architect_zone_presets',

        jsonEncode(_zonePresets.overrides),

      );

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

      await preferences.setDouble(

        'architect_handle_offset_length',

        _handleOffsetLength,

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

        onWalls: _showWallTypes,

        settings: ArchitectWorkspaceSettings(

          zonePresets: _zonePresets,

          units: _project.units,

          dimensionScale: _project.dimensionScale,

          distanceDecimals: _project.distanceDecimals,

          ghostStoreys: _showGhostStoreys,

          upperOverhangs: _showUpperOverhangs,

          grid: _showDrawingGrid,

          magnetic: _magnetEnabled,

          underlay: _showUnderlay,

          darkCanvas: _canvasPalette.isDark,

          axisCoreThickness: _axisWallCoreThickness,

          handleOffsetLength: _handleOffsetLength,

        ),

      ),

    );

    if (result == null || !mounted) return;

    _canvasPreferenceChanged = true;

    _commands.setUnits(result.units);

    _commands.setDimensionScale(result.dimensionScale);

    _commands.setDistanceDecimals(result.distanceDecimals);

    _changeViewPreference(() {

      _showGhostStoreys = result.ghostStoreys;

      _showUpperOverhangs = result.upperOverhangs;

      _showDrawingGrid = result.grid;

      _magnetEnabled = result.magnetic;

      _showUnderlay = result.underlay;

      _axisWallCoreThickness = result.axisCoreThickness;

      _handleOffsetLength = result.handleOffsetLength;

      _zonePresets = result.zonePresets;

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

      _selectWorkspaceView(

        ArchitectWorkspaceView.plan,

        _modelCommands.project.activeStoreyId,

      );

    }

    setState(() => _is3DView = !_is3DView);

  }



  void _resetWorkspaceView() {

    if (_is3DView) {

      _camera3D.reset();

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



  // Zone placement and manual body movement

  ArchitectZoneKind _activeZoneKind = ArchitectZoneKind.room;

  ArchitectZoneCategory _activeZoneCategory = ArchitectZoneCategory.living;

  String? _selectedZoneId;

  Offset? _zoneMoveStartPoint;

  List<Offset>? _zoneMoveOriginalPolygon;

  List<Offset>? _zoneMovePreviewPolygon;

  Offset _axisHandleGrabOffset = Offset.zero;

  List<(Offset, Offset)> _activeMagneticGuides = [];

  final _midpointTracking = ArchitectMidpointTracking();



  bool get _showMidpointReferences =>

      _commands.isPlan && !_is3DView && !_printPreview && _magnetEnabled &&

      (_isActivelyDraggingHandle || _mirrorActive || _splitActive ||

          _newPointTargetId != null || _duplicateMove != null ||

          const {

            ArchitectTool.wall, ArchitectTool.cadLine, ArchitectTool.cadRect,

            ArchitectTool.cadCircle, ArchitectTool.slab, ArchitectTool.hatch, ArchitectTool.roof,

            ArchitectTool.beam, ArchitectTool.opening, ArchitectTool.stair,

            ArchitectTool.zone, ArchitectTool.axis, ArchitectTool.column,

            ArchitectTool.dimension, ArchitectTool.measure,

          }.contains(_activeTool));



  void _updateMidpointReferences(Offset raw) {

    _midpointTracking.update(

      project: _elementMoveOriginal ?? _project,

      raw: raw,

      scale: _currentScale,

      context: (_activeTool, _workspaceViewKey),

      enabled: _showMidpointReferences,

      capturePixels: _touchInput ? 12 : 8,

      hoverPixels: _touchInput ? 18 : 12,

      excludedIds: {

        ..._groupDragIds,

        ?_draggingElementId,

        if (_polygonEditor.elementId != null) _polygonEditor.elementId!,

        if (_wallEndpointOriginal != null) _wallEndpointOriginal!.id,

      },

    );

  }



  // Zone Schedule Table Placement & Drag State

  String? _selectedZoneTableId;

  bool _isZoneTableSelected = false;

  bool _isDraggingZoneTable = false;

  Offset? _zoneTableDragOffset;

  Offset? _zoneTablePreviewOrigin;



  // Zone placement controller; contour editing uses the common polygon editor

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

  double _componentRotation = 0.0;

  bool _showFurnitureLayer = true;

  void toggleFurnitureLayer() => setState(() => _showFurnitureLayer = !_showFurnitureLayer);



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



  void _onComponentLibraryChanged() {

    if (mounted) setState(() {});

  }



  void _onModelChanged() {

    if (!mounted) return;

    if ((_offsetOptions != null && !identical(_offsetSource, _project)) ||
        (_rotationSource != null && !identical(_rotationSource, _project)) ||
        (_viewDirectionDraft != null && !identical(_viewDirectionDraft!.source, _project))) {

      _cancelActiveDrags();
      _marqueeTool.cancel();

    }

    if (!_commands.isPlan || _editingGroup == null) _editingGroupId = null;

    _midpointTracking.clear();

    _restoreWallType();

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

    if (_selectedSectionRoofId != null &&

        (_commands.view != ArchitectWorkspaceView.section ||

            ArchitectBuildingSection.findRoofById(

                  _modelCommands.project,

                  _selectedSectionRoofId!,

                ) ==

                null)) {

      _selectedSectionRoofId = null;

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

    if (_selectionContextActive &&

        _effectiveSelection.isEmpty &&

        _selectedSectionRoofId == null) {

      _selectionContextActive = false;

      _activeTool = ArchitectTool.select;

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

    _editingGroupId = null;

    _resetDraftGroup();

    if (_cutOpeningTargetId != null) _activeTool = ArchitectTool.select;

    _cutOpeningTargetId = null;

    _terrainDrafting = false;

    _viewDraft = null;

    _placingDownpipe = false;

    _downpipeRoofId = null;

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

    _axisTool.deselect();

    _elementTool.cancelSlabDrafting();

    _roofTool.clearDraft();
    _marqueeTool.cancel();

    if (_selectionContextActive ||

        _activeTool == ArchitectTool.door ||

        _activeTool == ArchitectTool.window ||

        _activeTool == ArchitectTool.column) {

      _activeTool = ArchitectTool.select;

      _cursorModel = null;

      _columnPreviewPoint = null;

    }

    _selectionContextActive = false;

    setState(() {

      _draftStart = null;

      _wallArcEnd = null;

      _draftEnd = null;

      _wallDirectionLocked = false;

      _selectedZoneId = null;

      _selectedElementId = null;

      _selectedSectionRoofId = null;

    });

  }



  bool _terrainDrafting = false;



  void _startTerrainDraft() {

    _cancelDrafting(); _clearSelection();

    setState(() { _activeTool = ArchitectTool.select; _terrainDrafting = true; });

  }



  void _changeTool(ArchitectTool tool, {bool toggle = true}) => setState(() {

    _finishDraftGroup();

    _editingGroupId = null;

    _cutOpeningTargetId = null;

    _terrainDrafting = false;

    _placingDownpipe = false;

    _downpipeRoofId = null;

    final nextTool =

        (toggle && _activeTool == tool && tool != ArchitectTool.select)

        ? ArchitectTool.select

        : tool;

    _resetDimensionDraft();

    _selectionCyclePoint = null;

    _lastTapTime = null;

    _lastTapPos = null;

    _selectionIds.clear();

    _interactionEpoch++;

    _cancelActiveDrags();

    _zoneTool.cancelAll();

    _axisTool.cancelAll();

    _axisTool.deselect();

    _elementTool.cancelSlabDrafting();

    _roofTool.clearDraft();

    _selectedZoneId = null;

    _selectedElementId = null;

    _wallParallelMove = false;

    _wallEndpointClearanceId = null;

    _multiSelect = false;

    _moveSelection = false;

    _activeTool = nextTool;

    _midpointTracking.clear();

    _pendingShape = null;

    _shapePanelAnchor = null;

    _columnPreviewPoint = null;

    _columnPreviewRotation = 0.0;

    _cursorModel = null;

    _draftStart = null;

    _wallArcEnd = null;

    _draftEnd = null;

    _wallDirectionLocked = false;

    _activeMagneticGuides = [];

    _activeSnapLabel = null;

    _selectionContextActive = false;

    _selectedSectionRoofId = null;

    _isZoneTableSelected = false;

  });



  void _clearSelection() {

    setState(() {

      if (_selectionContextActive) _activeTool = ArchitectTool.select;

      _selectionContextActive = false;

      _selectionCyclePoint = null;

      _cancelActiveDrags();

      _selectionIds.clear();

      _selectedElementId = null;

      _selectedZoneId = null;

      _isZoneTableSelected = false;

      _selectedSectionRoofId = null;

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

      _wallCutStroke = false;

      _splitActive = false;

      _splitWallIds.clear();

      _splitPoint1 = null;

      _splitPoint2 = null;

      _splitPerpendicularNormal = null;

      _splitGuidePerpendicular = null;

      _splitWaitingForSide = false;

    });

  }



  // Wall Drafting State

  double _wallThickness = 0.25; // 25 cm default

  ArchitectWallType? _activeWallType;

  String? _preferredWallTypeId;

  bool _wallPreferenceChanged = false;

  static const _wallTypePreference = 'architect_wall_type';

  List<ArchitectWallType> get _availableWallTypes {
    final types = _project.wallTypes.where((t) => t.isCatalogType).toList();
    return types.isEmpty ? ArchitectWallType.standardCatalog() : types;
  }



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



  bool _wallCurved = false;

  Offset? _wallArcEnd;

  double get _draftArcBulge =>

      _wallArcEnd == null || _draftStart == null || _draftEnd == null

      ? 0

      : ArchitectWallArc.through(_draftStart!, _wallArcEnd!, _draftEnd!);

  void _commitWallArc() {

    if (_wallArcEnd == null) return;

    final bulge = _draftArcBulge;

    try {

      if (bulge.abs() < 1e-6) throw ArgumentError('Collinear arc');

      ArchitectWall(

        id: 'validate',

        startPoint: _draftStart!,

        endPoint: _wallArcEnd!,

        arcBulge: bulge,

        thickness: _wallThickness,

        referenceLine: _wallReference,

        exteriorSide: _wallExteriorSide,

        layers: _activeWallType?.layers ?? const [],

        insulationThicknessOverride: _activeWallType?.insulationThickness,

      ).validateGeometry();

      _commitCurrentWallSegment(

        _wallArcEnd!,

        arcBulge: bulge,

        continueChain: false,

      );

      setState(() => _wallArcEnd = null);

    } on ArgumentError {

      _operationError();

    }

  }



  Future<void> _editDraftArcRadius() async {

    if (_wallArcEnd == null || _draftStart == null) return;

    final start = _draftStart!, end = _wallArcEnd!, bulge = _draftArcBulge;

    final chord = (end - start).distance,

        previous = bulge.abs() < 1e-6

            ? chord

            : ArchitectWallArc(start, end, bulge).radius;

    final radius = await showDialog<double>(

      context: context,

      builder: (_) => ArchitectWallRadiusDialog(

        project: _project,

        radius: previous,

        minimum: chord / 2,

      ),

    );

    if (radius == null ||

        !mounted ||

        _draftStart != start ||

        _wallArcEnd != end) {

      return;

    }

    final root = math.sqrt(math.max(0, radius * radius - chord * chord / 4));

    final next =

        (bulge < 0 ? -1 : 1) *

        (radius + (bulge.abs() > 1 ? root : -root)) /

        (chord / 2);

    setState(() => _draftEnd = ArchitectWallArc(start, end, next).pointAt(.5));

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

  String? _polygonContourElementId;
  int _polygonContourIndex = 0;

  int? get _selectedPolygonHoleIndex {
    final id = _selectedElementId ?? _selectedZoneId;
    if (id == null || _polygonContourElementId != id || _polygonContourIndex <= 0) return null;
    final host = CutArchitectContourOpening.target(_project.activeStorey, id);
    final index = _polygonContourIndex - 1;
    return host != null && index < host.$2.length ? index : null;
  }

  void _selectPolygonContour(Offset point) {
    final id = _selectedElementId ?? _selectedZoneId;
    if (id == null || _effectiveSelection.length > 1) return;
    final host = CutArchitectContourOpening.target(_project.activeStorey, id);
    if (host == null) return;
    final ring = ArchitectPolygonEditor.hitContour(host.$1, host.$2,
        point, _currentScale, offsetLengthPx: _handleOffsetLength);
    if (ring == null) return;
    if (_polygonContourElementId != id || _polygonContourIndex != ring) {
      _polygonSelectedEdge = null;
    }
    _polygonContourElementId = id;
    _polygonContourIndex = ring;
  }

  bool _polygonDistanceOpen = false;

  Offset? _radialMenuScreenPosition;

  String? _radialMenuElementId;

  List<ArchitectRadialMenuItem> _radialMenuItems = [];



  List<Rect> get _radialElementBounds => [

    for (final id in _effectiveSelection)

      if (ArchitectSelection.bounds(_project, id) case final Rect bounds)

        Rect.fromPoints(

          _viewport.toScreen(bounds.topLeft),

          _viewport.toScreen(bounds.bottomRight),

        ).inflate(3),

  ];

  bool _wallDirectionLocked = false;

  Offset? _wallPanelAnchor;

  WallReferenceLine _wallReference = WallReferenceLine.center;

  WallExteriorSide _wallExteriorSide = WallExteriorSide.left;

  String? _wallExtendId;

  String? _wallJoinSourceId;

  Offset? _wallJoinPointer;

  (Offset, Offset)? get _wallJoinLeaderLine {

    if (_wallJoinSourceId == null) return null;

    final wall = _linearEditWalls

        .where((w) => w.id == _wallJoinSourceId)

        .firstOrNull;

    if (wall == null) return null;

    final center = wall.referencePointAt(.5);

    final target =

        _wallJoinPointer ??

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
  final _marqueeTool = ArchitectMarqueeTool();

  Set<String> _groupDragIds = {};

  bool _multiSelect = false;

  // Auto-picked tools expose editing; drawing starts only after a tool command.

  bool _selectionContextActive = false;

  bool get _acceptsAnySelection =>

      _activeTool == ArchitectTool.select ||

      _selectionContextActive ||

      _multiSelect;

  bool _moveSelection = false;

  DateTime? _lastTapTime;

  Offset? _lastTapPos;

  String? _editingGroupId;

  ArchitectElementGroup? get _editingGroup => _project.activeStorey.groups.where((g) => g.id == _editingGroupId).firstOrNull;

  ArchitectElementGroup? get _selectedGroup {

    if (!_commands.isPlan || _editingGroupId != null) return null;

    final ids = _effectiveSelection;

    return _project.activeStorey.groups.where((g) => g.elementIds.length == ids.length && g.elementIds.containsAll(ids)).firstOrNull;

  }

  Set<String> get _effectiveSelection {

    final raw = _rawSelection;

    if (!_commands.isPlan) return raw;

    final group = _editingGroup;

    return group != null ? raw.where(group.elementIds.contains).toSet() : _project.activeStorey.expandGroups(raw);

  }

  Set<String> get _rawSelection {

    if (_acceptsAnySelection) {

      if (_selectionIds.isNotEmpty) return Set.of(_selectionIds);

      return {

        ?_selectedElementId,

        ?_selectedZoneId,

        if (_axisTool.selectedAxisId != null) _axisTool.selectedAxisId!,

      };

    }

    final allowed = <String>{};

    for (final id in _selectionIds) {

      if (_isElementAllowedForTool(id, _activeTool)) allowed.add(id);

    }

    if (allowed.isNotEmpty) return allowed;

    if (_selectedElementId != null &&

        _isElementAllowedForTool(_selectedElementId!, _activeTool)) {

      return {_selectedElementId!};

    }

    if (_selectedZoneId != null &&

        _isElementAllowedForTool(_selectedZoneId!, _activeTool)) {

      return {_selectedZoneId!};

    }

    if (_activeTool == ArchitectTool.axis &&

        _axisTool.selectedAxisId != null &&

        _isElementAllowedForTool(_axisTool.selectedAxisId!, _activeTool)) {

      return {_axisTool.selectedAxisId!};

    }

    return const {};

  }



  bool _mirrorActive = false;

  ArchitectProject? _rotationSource;
  Set<String> _rotationIds = {};
  Offset _rotationPivot = Offset.zero;

  BimElementOffsetOptions? _offsetOptions;

  ArchitectProject? _offsetSource;

  Set<String> _offsetIds = {};

  Map<String, String> _offsetIdMap = {}, _offsetGroupIdMap = {};

  Offset? _offsetSide;

  bool _offsetValid = false;

  int _offsetEpoch = 0;

  bool _mirrorIsDuplicate = false;

  Set<String> _mirrorSourceIds = {};

  Offset? _mirrorAnchor;

  Offset? _mirrorCurrentPoint;

  Map<String, String>? _mirrorIdMap;



  bool _splitActive = false;

  Set<String> _splitWallIds = {};

  Offset? _splitPoint1;

  Offset? _splitPoint2;

  Offset? _splitPerpendicularNormal;

  (Offset, Offset)? _splitGuidePerpendicular;

  bool _splitWaitingForSide = false;



  String? _newPointTargetId;
  int? _newPointHoleIndex;

  Offset? _newPointCandidate;

  (Offset, Offset)? _newPointLeaderLine;



  bool _touchInput = false;

  bool _placingWithHold = false;

  bool _wallPrecisionMode = true;

  Offset? _touchPosition;

  ArchitectWall? _wallEndpointOriginal;

  ArchitectProject? _wallSnapProject;

  bool _wallDragStart = false;

  Offset _wallGrabOffset = Offset.zero;

  bool _wallEndpointIsOffset = false;

  Offset _wallEndpointDisplacement = Offset.zero;

  (Offset, Offset)? _wallEndpointLeaderLine;

  bool _wallParallelMove = false;

  ArchitectLineStyle _activeCadLineStyle = ArchitectLineStyle.solid;

  ArchitectDrainShape _drainShape = ArchitectDrainShape.round;

  double _drainSize = ArchitectDrainDefaults.roundDiameter;

  double _drainWidth = ArchitectDrainDefaults.linearWidth;

  double _drainSlopePercent = ArchitectDrainDefaults.slopePercent;

  bool _drainFromRoom = false;

  ArchitectFloorDrain? _drainDragOriginal;

  bool _drainDragIsOffset = false;

  Offset _drainGrabOffset = Offset.zero;



  ArchitectFloorDrain? get _selectedFloorDrain {

    if (_effectiveSelection.length > 1) return null;

    final id = _selectedElementId;

    if (id == null) return null;

    for (final drain in _project.activeStorey.floorDrains) {

      if (drain.id == id) return drain;

    }

    return null;

  }



  void _updateSelectedDrain(ArchitectFloorDrain updated) {

    try {

      _commands.execute(

        UpdateArchitectFloorDrain(

          storeyId: _project.activeStoreyId,

          drain: updated,

        ),

      );

      _saveBiMProjectIfAttached();

      setState(() {});

    } on ArgumentError {

      _operationError();

    }

  }



  Widget _floorDrainControl() {

    final selectedDrain = _selectedFloorDrain;

    if (selectedDrain != null) {

      return ArchitectFloorDrainBar(

        shape: selectedDrain.shape,

        size: selectedDrain.size,

        width: selectedDrain.width,

        slopePercent: selectedDrain.slopePercent,

        issues: ArchitectFloorDrainGeometry.validate(

          selectedDrain,

          ArchitectFloorDrainGeometry.thresholds(

            selectedDrain,

            _project.activeStorey.walls,

          ),

        ),

        onShape: (s) => _updateSelectedDrain(

          selectedDrain.copyWith(

            shape: s,

            size: s == ArchitectDrainShape.round

                ? ArchitectDrainDefaults.roundDiameter

                : ArchitectDrainDefaults.linearLength,

          ),

        ),

        onSize: (v) => _updateSelectedDrain(selectedDrain.copyWith(size: v)),

        onWidth: (w) => _updateSelectedDrain(selectedDrain.copyWith(width: w)),

        onSlope: (s) => _updateSelectedDrain(selectedDrain.copyWith(slopePercent: s)),

      );

    }

    return ArchitectFloorDrainBar(

      shape: _drainShape,

      size: _drainSize,

      width: _drainWidth,

      slopePercent: _drainSlopePercent,

      fromRoom: _drainFromRoom,

      pointCount: _elementTool.slabDraftPoints.length,

      onShape: (s) => setState(() {

        _drainShape = s;

        _drainSize = s == ArchitectDrainShape.round

            ? ArchitectDrainDefaults.roundDiameter

            : ArchitectDrainDefaults.linearLength;

      }),

      onSize: (v) => setState(() => _drainSize = v),

      onWidth: (w) => setState(() => _drainWidth = w),

      onSlope: (s) => setState(() => _drainSlopePercent = s),

      onFromRoom: (r) => setState(() {

        _drainFromRoom = r;

        _elementTool.cancelSlabDrafting();

      }),

      onUndo: () => setState(() {

        if (_elementTool.slabDraftPoints.isNotEmpty) {

          _elementTool.slabDraftPoints.removeLast();

          _elementTool.slabCandidatePoint = null;

        }

      }),

      onConfirm: _canConfirmContour ? _commitFloorDrain : null,

      onCancel: () => setState(_cancelDrafting),

    );

  }



  void _commitFloorDrain({ArchitectClosedContour? contour}) {

    final points = List<Offset>.unmodifiable(

      contour?.polygon ?? _elementTool.slabDraftPoints,

    );

    if (!ArchitectPolygonGeometry.valid(points)) {

      _operationError();

      return;

    }

    try {

      final id = ArchitectElementId.next('drain');

      final drain = ArchitectFloorDrainGeometry.autoPlace(

        id: id,

        polygon: points,

        holes: contour?.holes ?? const [],

        shape: _drainShape,

        walls: _project.activeStorey.walls,

        slopePercent: _drainSlopePercent,

        size: _drainSize,

        width: _drainWidth,

      );

      _commands.execute(

        PlaceArchitectFloorDrain(

          storeyId: _project.activeStoreyId,

          drain: drain,

        ),

      );

      setState(() {

        _elementTool.cancelSlabDrafting();

        _selectedElementId = id;

        _selectionIds

          ..clear()

          ..add(id);

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

    } on ArgumentError {

      _operationError();

    }

  }



  bool _automaticHatch = false;

  String? _cutOpeningTargetId;

  ArchitectHatchPattern _activeHatchPattern = ArchitectHatchPattern.diagonal;
  ArchitectDrawingColor _activeHatchColor = ArchitectDrawingColor.ink;

  Widget _hatchControl() => ArchitectHatchDraftBar(

    automatic: _automaticHatch,

    onAutomaticChanged: (v) => setState(() {

      _automaticHatch = v;

      _elementTool.cancelSlabDrafting();

    }),

    pattern: _activeHatchPattern,
    color: _activeHatchColor,
    onColorChanged: (color) => setState(() => _activeHatchColor = color),

    customPatterns: _project.hatchPatterns,

    lineStyles: _project.lineStyles,

    pointCount: _elementTool.slabDraftPoints.length,

    onUndo: () => setState(() {

      _elementTool.slabDraftPoints.removeLast();

      _elementTool.slabCandidatePoint = null;

    }),

    onFinish: _commitHatch,

    onCancel: () => setState(_elementTool.cancelSlabDrafting),

    onChanged: (pattern) {

      if (!pattern.isPreset && !_project.hatchPatterns.any((p) => p == pattern)) {

        _commands.execute(SaveArchitectHatchPattern(pattern));

        _saveBiMProjectIfAttached();

      }

      setState(() => _activeHatchPattern = pattern);

    },

  );



  void _commitHatch({ArchitectClosedContour? contour}) {

    final points = List<Offset>.unmodifiable(contour?.polygon ?? _elementTool.slabDraftPoints);

    if (!ArchitectPolygonGeometry.valid(points)) { _operationError(); return; }

    final bounds = ArchitectSceneGeometry.boundsOf(points);

    try {

      _commands.execute(PlaceArchitectCadPrimitive(storeyId: _project.activeStoreyId,

        primitive: ArchitectCadPrimitive(id: ArchitectElementId.next('hatch'),

          type: CadPrimitiveType.hatch, startPoint: bounds.topLeft, endPoint: bounds.bottomRight,

          polygon: points, holes: contour?.holes ?? const [], hatchPattern: _activeHatchPattern,
          colorValue: _activeHatchColor.argb, colorPresetId: _activeHatchColor.presetId)));

      setState(_elementTool.cancelSlabDrafting);

      _saveBiMProjectIfAttached(); HapticFeedback.mediumImpact();

    } on ArgumentError { _operationError(); }

  }

  void _startCutOpening(String id) {

    _cancelDrafting();

    setState(() {

      _cutOpeningTargetId = id;

      _activeTool = ArchitectTool.slab;

      _selectionContextActive = false;

    });

  }



  void _commitCutOpening() {

    final id = _cutOpeningTargetId;

    if (id == null) return;

    try {

      _commands.execute(CutArchitectContourOpening(

        storeyId: _project.activeStoreyId, elementId: id,

        polygon: List.of(_elementTool.slabDraftPoints)));

      _cancelDrafting();

      setState(() => _activeTool = ArchitectTool.select);

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

    } on ArgumentError {

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(

        content: Text(context.l10n.architectCutOpeningInvalid)));

    }

  }



  Widget _cutOpeningControl() => Material(

    color: Theme.of(context).colorScheme.surface,

    borderRadius: BorderRadius.circular(8),

    child: Row(children: [

      Expanded(child: Tooltip(

        message: context.l10n.architectCutOpeningHint,

        child: Padding(padding: const EdgeInsets.only(left: 12),

          child: Text(context.l10n.architectCutOpening)),

      )),

      IconButton(key: const ValueKey('opening-draft-undo'),

        tooltip: context.l10n.undoAction, icon: const Icon(Icons.undo),

        onPressed: _elementTool.slabDraftPoints.isEmpty ? null : () => setState(() {

          _elementTool.slabDraftPoints.removeLast();

          _elementTool.slabCandidatePoint = null;

        })),

      IconButton(key: const ValueKey('opening-draft-finish'),

        tooltip: context.l10n.architectCutOpening,

        icon: const Icon(Icons.check),

        onPressed: _canConfirmContour ? _commitCutOpening : null),

      IconButton(key: const ValueKey('opening-draft-cancel'),

        tooltip: context.l10n.cancel, icon: const Icon(Icons.close),

        onPressed: _cancelDrafting),

    ]),

  );



  Widget _lineStyleControl() => Theme(

    data: ThemeData.dark(),

    child: ArchitectLineStylePicker(

      key: const ValueKey('architect-draft-line-style'),

      value: _activeCadLineStyle,

      compact: true,

      customStyles: _project.lineStyles,

      onChanged: (style) {

        if (!style.isPreset && !_project.lineStyles.any((s) => s == style)) {

          _commands.execute(SaveArchitectLineStyle(style));

          _saveBiMProjectIfAttached();

        }

        setState(() => _activeCadLineStyle = style);

      },

    ),

  );

  bool get _viewMarkerTool => _activeTool == ArchitectTool.section || _activeTool == ArchitectTool.elevation;

  bool get _linearDraftTool =>
      _activeTool == ArchitectTool.wall ||
      _activeTool == ArchitectTool.cadLine ||
      _activeTool == ArchitectTool.section ||
      _activeTool == ArchitectTool.elevation;



  Set<String> get _selectedLineIds => _project.activeStorey.cadPrimitives

      .where(

        (p) =>

            p.type == CadPrimitiveType.line &&

            _effectiveSelection.contains(p.id),

      )

      .map((p) => p.id)

      .toSet();



  ArchitectWall? get _selectedLinearElement {
    if (_effectiveSelection.length != 1) return null;
    final id = _effectiveSelection.single;
    final line = _project.activeStorey.cadPrimitives
        .where((p) => p.id == id && p.type == CadPrimitiveType.line)
        .firstOrNull;
    if (line != null) return ArchitectLineEditing.segment(line);
    final sec = _project.sections.where((s) => s.id == id).firstOrNull;
    if (sec != null) {
      return ArchitectWall(
        id: sec.id,
        startPoint: sec.start,
        endPoint: sec.end,
        wallTypeId: 'section',
        thickness: 0.001,
      );
    }
    final elv = _project.elevations.where((e) => e.id == id).firstOrNull;
    if (elv != null) {
      return ArchitectWall(
        id: elv.id,
        startPoint: elv.start,
        endPoint: elv.end,
        wallTypeId: 'elevation',
        thickness: 0.001,
      );
    }
    return _selectedWall;
  }

  List<ArchitectWall> get _linearEditWalls {
    if (_activeTool == ArchitectTool.cadLine || _selectedLineIds.isNotEmpty) {
      return _project.activeStorey.cadPrimitives
          .where((p) => p.type == CadPrimitiveType.line)
          .map(ArchitectLineEditing.segment)
          .toList();
    }
    final sec = _project.sections
        .where((s) => _effectiveSelection.contains(s.id))
        .firstOrNull;
    if (sec != null) {
      return [
        ArchitectWall(
          id: sec.id,
          startPoint: sec.start,
          endPoint: sec.end,
          wallTypeId: 'section',
          thickness: 0.001,
        )
      ];
    }
    final elv = _project.elevations
        .where((e) => _effectiveSelection.contains(e.id))
        .firstOrNull;
    if (elv != null) {
      return [
        ArchitectWall(
          id: elv.id,
          startPoint: elv.start,
          endPoint: elv.end,
          wallTypeId: 'elevation',
          thickness: 0.001,
        )
      ];
    }
    return _project.activeStorey.walls;
  }



  ArchitectModelCommand _linearCommand(ArchitectModelCommand command) =>

      ArchitectLineEditing.adapt(_project, command);



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

    final wall = _selectedLinearElement;

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

    final current = _linearEditWalls.where((w) => w.id == wall.id).firstOrNull;

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

    final floor = (_elementMoveOriginal ?? _project).activeStorey;

    final wall = [

      ...floor.walls,

      ...floor.cadPrimitives

          .where((p) => p.type == CadPrimitiveType.line)

          .map(ArchitectLineEditing.segment),

    ].where((w) => ids.contains(w.id)).firstOrNull;

    if (wall == null) return delta;

    final normal = wall.normalVector;

    return normal * (delta.dx * normal.dx + delta.dy * normal.dy);

  }



  ArchitectWall? get _selectedWall {

    if (_effectiveSelection.length > 1) return null;

    if (_activeTool != ArchitectTool.select &&

        _activeTool != ArchitectTool.wall) {

      return null;

    }

    final singleId =

        _selectedElementId ??

        (_selectedWallIds.length == 1 ? _selectedWallIds.first : null);

    if (singleId == null) return null;

    for (final wall in _project.activeStorey.walls) {

      if (wall.id == singleId) return wall;

    }

    return null;

  }



  final Set<String> _dismissedOvershoots = {};



  ArchitectWallOvershoot? get _activeOvershoot {

    if (_is3DView) return null;

    final walls = _project.activeStorey.walls;

    if (_selectedWallIds.length == 1) {

      final wall = walls

          .where((w) => w.id == _selectedWallIds.first)

          .firstOrNull;

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

  double _columnPreviewRotation = 0.0;

  bool get _columnPreviewIsOccupied =>

      _columnPreviewPoint != null &&

      _project.activeStorey.columns.any(

        (column) => column.containsPoint(_columnPreviewPoint!, tolerance: 0),

      );

  String? _activeSnapLabel;



  // Door State (from element_vrata.dxf)

  double _doorWidth = 0.90;

  double _doorHeight = 2.00;

  double _doorSill = 0.0;

  bool _isHingeLeft = true;



  // Door & Window Placement Cooldown (prevents accidental duplicate taps and keeps tool active)

  Timer? _openingCooldownTimer;



  bool get _isOpeningPlacementCoolingDown =>

      _openingCooldownTimer?.isActive ?? false;



  void _startOpeningCooldown() {

    _openingCooldownTimer?.cancel();

    _openingCooldownTimer = Timer(const Duration(milliseconds: 1500), () {

      if (mounted) setState(() {});

    });

  }



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

    var draft = _project.updateActiveStorey(floor);

    if (_editingGroupId != null) {

      draft = AddArchitectGroupMembers(storeyId: _project.activeStoreyId,

        groupId: _editingGroupId!, elementIds: {copyId}).apply(draft);

    }

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

      midpointReferences: _midpointTracking.references,

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

  final Cad3DController _camera3D = Cad3DController();



  // Pointer ownership and navigation live in ArchitectViewport.

  bool _isHandleEngaged = false;

  Offset? _handlePointerDown;

  bool _handleMoved = false;



  ArchitectZone? get _selectedZone {

    if (_effectiveSelection.length > 1) return null;

    if (_activeTool != ArchitectTool.select &&

        _activeTool != ArchitectTool.zone) {

      return null;

    }

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

      _sectionRoofDragStartModelY != null ||

      _duplicateMove != null ||

      _polygonEditor.active ||

      _draggingElementId != null ||

      _zoneMoveStartPoint != null ||

      _axisTool.isDraggingHandle ||

      _axisTool.isMovingAxis ||

      _axisTool.isOffsettingWithDrag ||

      _wallEndpointOriginal != null ||

      _drainDragOriginal != null ||

      _isDraggingZoneTable ||

      _groupDragIds.isNotEmpty;



  /// Whether gestures should be captured exclusively by the tool instead of panning.

  bool get _isActivelyDraggingHandle =>

      _draftCancelPointer != null ||

      _isDraggingVertexOrHandle ||

      _wallCutIds.isNotEmpty ||

      _wallExtendId != null ||

      _wallJoinSourceId != null;



  @override

  void initState() {

    super.initState();

    ComponentLibraryService.instance.addListener(_onComponentLibraryChanged);

    unawaited(ComponentLibraryService.instance.init());

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

        _activeTool = ArchitectTool.select;

      });

      _initTransform();

    }

  }



  void _initTransform() {

    var bounds = ArchitectSceneGeometry.projectBounds(_project);

    final viewBounds = _workspaceViewBounds;

    if (viewBounds != null) {

      bounds = bounds == Rect.zero

          ? viewBounds

          : bounds.expandToInclude(viewBounds);

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

    ComponentLibraryService.instance.removeListener(_onComponentLibraryChanged);

    if (_saveTimer != null) {

      unawaited(_flushSave());

    }

    _openingCooldownTimer?.cancel();

    _commands.removeListener(_onModelChanged);

    _commands.dispose();

    if (widget.commandController == null) _modelCommands.dispose();

    _zoneTool.dispose();

    _axisTool.dispose();

    _elementTool.dispose();

    _roofTool.dispose();

    _viewport.dispose();

    _camera3D.dispose();

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



  bool _hitTestWallEndpoint(

    Offset rawModel,

    ArchitectWall wall, {

    required bool atStart,

  }) {

    final refPt = atStart ? wall.startPoint : wall.endPoint;

    final centerPt = atStart ? wall.centerStart : wall.centerEnd;

    final n = wall.normalVector * (wall.thickness / 2.0);

    final capA = centerPt - n;

    final capB = centerPt + n;

    final tol = math.min(

      math.max(26.0 / _currentScale, wall.thickness / 2.0 + 0.05),

      0.40,

    );

    if ((rawModel - refPt).distance <= tol) return true;

    if ((rawModel - centerPt).distance <= tol) return true;

    if ((rawModel - capA).distance <= tol) return true;

    if ((rawModel - capB).distance <= tol) return true;

    final closest = BimLineGeometry.closest(rawModel, capA, capB);

    return (rawModel - closest).distance <= tol;

  }



  ArchitectZone? _findZoneAt(Offset modelPt) {

    final zones = [

      ..._project.activeStorey.zones.where((z) => z.isApartment),

      ..._project.activeStorey.zones.where((z) => !z.isApartment),

    ];

    for (int i = zones.length - 1; i >= 0; i--) {

      if (zones[i].containsPoint(modelPt)) {

        return zones[i];

      }

    }

    return null;

  }



  ArchitectZone _applyZoneFinishPresets(ArchitectZone zone) {

    final l = context.l10n;

    String overrideFor(String kind, String resolved) {

      final defaults = const ArchitectZonePresets().finishes(kind, l);

      final index = defaults.indexOf(resolved);

      return index < 0 ? '' : _zonePresets.overrides['$kind.$index'] ?? '';

    }



    return zone.copyWith(

      floorFinish: overrideFor('floor', zone.resolvedFloorFinish(l)),

      wallFinish: overrideFor('wall', zone.resolvedWallFinish(l)),

      ceilingFinish: overrideFor('ceiling', zone.resolvedCeilingFinish(l)),

    );

  }



  void _commitDraftedZone() {

    final l10n = context.l10n;

    final nextNumber = (_project.activeStorey.zones.length + 1).toString();

    final repairedCrossings = _zoneTool.hasDraftCrossings;

    final newZone = _zoneTool.commitDrafting(

      category: _activeZoneCategory,

      defaultName: _activeZoneKind == ArchitectZoneKind.apartment ? l10n.architectApartment : _zonePresets.categoryName(_activeZoneCategory, l10n),

      number: nextNumber,

    );



    if (newZone != null) {

      final activeStorey = _project.activeStorey;

      setState(() {

        _commands.execute(

          CreateArchitectZone(

            storeyId: activeStorey.id,

            zone: _applyZoneFinishPresets(newZone).copyWith(kind: _activeZoneKind),

          ),

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

            '${l10n.architectZoneCreated(newZone.name, BimDistanceUnit.trimZeros(newZone.area.toStringAsFixed(2)))}'

            '${repairedCrossings ? '\n${l10n.architectZoneBoundaryRepaired}' : ''}',

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

    if (_offsetOptions != null) {

      _previewOffset(_screenToModel(_placementPosition(event.localPosition)));

      return;

    }

    if (_newPointTargetId != null) {

      _touchPosition = event.localPosition;

      _placingWithHold = true;

      _updateNewPointCandidate(rawModel, isTouch: _touchInput);

      return;

    }

    if (_commands.view == ArchitectWorkspaceView.section &&

        _selectedSectionRoofId != null) {

      _cacheProjection();

      final secPt = _modelToSection(rawModel);

      final hitRoof = _sectionGeometry?.pickRoof(secPt, 18 / _currentScale);

      final rb = _sectionGeometry?.roofBounds(_selectedSectionRoofId!);

      final nearHandle =

          rb != null &&

          (secPt - Offset(rb.center.dx, rb.bottom + 16 / _currentScale))

                  .distance <=

              20 / _currentScale;

      if (hitRoof == _selectedSectionRoofId || nearHandle) {

        final hit = ArchitectBuildingSection.findRoofById(

          _modelCommands.project,

          _selectedSectionRoofId!,

        );

        if (hit != null) {

          _sectionRoofDragStartModelY = rawModel.dy;

          _sectionRoofDragInitialOffset = hit.roof.baseElevationOffset;

          _sectionRoofDragPreviewOffset = hit.roof.baseElevationOffset;

          _isHandleEngaged = true;

          return;

        }

      }

    }

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

    _selectPolygonContour(rawModel);
    if (_polygonEditId != null) _selectPolygonEdge(rawModel);

    if (_linearDraftTool &&

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

    final selectedMansardRoof = _selectedRoof;
    if (selectedMansardRoof != null &&
        selectedMansardRoof.isMansard &&
        ArchitectRoofPainterHelper.hitTestKnuckleHandle(
          selectedMansardRoof,
          rawModel,
          scale: _currentScale,
        )) {
      _isDraggingRoofKnuckle = true;
      _draggingRoofKnuckleId = selectedMansardRoof.id;
      _knuckleDragInitialBreakDist =
          selectedMansardRoof.effectiveBreakDistance;
      _knuckleDragStartPoint = rawModel;
      _isHandleEngaged = true;
      HapticFeedback.selectionClick();
      ArchitectLogger.log(
        'HANDLE',
        'Roof knuckle drag engaged for ${selectedMansardRoof.id}',
      );
      return;
    }

    final polygon = _selectedPolygon;

    final isDirectContour =

        _polygonEditId == null &&

        (_selectedRoof != null || _selectedZone?.isAutoBoundary == false);

    final movableEdge =

        polygon != null &&

            (_polygonEditId != null &&

                    (_polygonEdgeMode == ArchitectPolygonEdgeMode.move ||

                        _polygonEdgeMode ==

                            ArchitectPolygonEdgeMode.extendCatheti) ||

                isDirectContour) &&

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

                mode: isDirectContour

                    ? ArchitectPolygonEdgeMode.extendCatheti

                    : _polygonEdgeMode,

                offsetLengthPx: _handleOffsetLength,

              )

            : _polygonEditor.start(

                (_selectedElementId ?? _selectedZoneId)!,

                polygon,

                rawModel,

                _currentScale,

                mode: _polygonEditId == null

                    ? (_selectedRoof != null ||

                              _selectedZone?.isAutoBoundary == false

                          ? ArchitectPolygonEdgeMode.extendCatheti

                          : ArchitectPolygonEdgeMode.pull)

                    : _polygonEdgeMode,

                offsetLengthPx: _handleOffsetLength,

              ))) {

      _elementMoveOriginal = _project;

      _elementMovePreview = _project;

      _isHandleEngaged = true;

      HapticFeedback.selectionClick();

      return;

    }

    if (_linearDraftTool && !_selectionContextActive) {

      _placingWithHold = !_touchInput;

      _touchPosition = null;

      if (!_touchInput) _updatePointerPreview(event.localPosition);

      _repaintPreview();

    }

    // Floor drain position handle check (direct grate or offset touch grip)

    final selectedDrain = _selectedFloorDrain;

    if (selectedDrain != null &&

        (_activeTool == ArchitectTool.select || _activeTool == ArchitectTool.floorDrain) &&

        !_mirrorActive &&

        _offsetOptions == null &&

        !_splitActive) {

      final clearance = _handleOffsetLength / _currentScale;

      final handlePt = ArchitectFloorDrainPainterHelper.offsetHandle(selectedDrain, clearance);

      final offsetTol = math.max(28.0 / _currentScale, 0.35);

      final directTol = math.max(14.0 / _currentScale, selectedDrain.halfWidth + 0.1);

      final hitOffset = _handleOffsetLength > 0 && (rawModel - handlePt).distance <= offsetTol;

      final hitDirect = (rawModel - selectedDrain.position).distance <= directTol;

      if (hitOffset || hitDirect) {

        _drainDragOriginal = selectedDrain;

        _drainDragIsOffset = hitOffset;

        _drainGrabOffset = (hitOffset ? handlePt : selectedDrain.position) - rawModel;

        _elementMoveOriginal = _project;

        _elementMovePreview = _project;

        _isHandleEngaged = true;

        HapticFeedback.selectionClick();

        return;

      }

    }



    // Wall endpoint handle check (works in Wall tool and Select tool)

    if ((_linearDraftTool || _activeTool == ArchitectTool.select) &&

        _selectedLinearElement != null &&

        _wallJoinSourceId == null &&

        !_mirrorActive &&

        _offsetOptions == null &&

        !_splitActive) {

      final wall = _selectedLinearElement!;

      final uStart = wall.tangentAt(0);

      final uEnd = wall.tangentAt(1);

      final clearance = _handleOffsetLength / _currentScale;

      final startHandle = wall.startPoint - uStart * clearance;

      final endHandle = wall.endPoint + uEnd * clearance;

      final offsetTol = math.max(28.0 / _currentScale, 0.35);



      final dStartHandle = (rawModel - startHandle).distance;

      final dEndHandle = (rawModel - endHandle).distance;

      final hitOffsetStart =

          _handleOffsetLength > 0 && dStartHandle <= offsetTol;

      final hitOffsetEnd = _handleOffsetLength > 0 && dEndHandle <= offsetTol;



      final hitDirectStart = _hitTestWallEndpoint(

        rawModel,

        wall,

        atStart: true,

      );

      final hitDirectEnd = _hitTestWallEndpoint(rawModel, wall, atStart: false);



      if (hitOffsetStart || hitOffsetEnd || hitDirectStart || hitDirectEnd) {

        final bool isOffset;

        final bool atStart;

        if (hitOffsetStart || hitOffsetEnd) {

          isOffset = true;

          atStart = (hitOffsetStart && hitOffsetEnd)

              ? dStartHandle <= dEndHandle

              : hitOffsetStart;

        } else {

          isOffset = false;

          atStart = (hitDirectStart && hitDirectEnd)

              ? (rawModel - wall.startPoint).distance <=

                    (rawModel - wall.endPoint).distance

              : hitDirectStart;

        }

        final point = atStart ? wall.startPoint : wall.endPoint;

        final handlePt = isOffset ? (atStart ? startHandle : endHandle) : point;



        _wallEndpointOriginal = wall;

        _wallDragStart = atStart;

        _wallEndpointIsOffset = isOffset;

        _wallEndpointDisplacement = isOffset ? (handlePt - point) : Offset.zero;

        _wallGrabOffset = handlePt - rawModel;

        _wallEndpointLeaderLine = isOffset ? (point, handlePt) : null;

        _elementMoveOriginal = _project;

        _elementMovePreview = _project;

        _isHandleEngaged = true;

        HapticFeedback.selectionClick();

        ArchitectLogger.log(

          'HANDLE',

          'Wall ${wall.id} endpoint ${atStart ? "start" : "end"} drag engaged (offset=$isOffset)',

        );

        return;

      }

    }



    // Direct endpoint grab on unselected wall (auto-selects and starts point drag)

    if ((_linearDraftTool || _activeTool == ArchitectTool.select) &&

        _selectedLinearElement == null &&

        _effectiveSelection.isEmpty &&

        _draftStart == null &&

        !_splitActive) {

      for (final wall in _linearEditWalls.reversed) {

        final hitStart = _hitTestWallEndpoint(rawModel, wall, atStart: true);

        final hitEnd = _hitTestWallEndpoint(rawModel, wall, atStart: false);

        if (hitStart || hitEnd) {

          final atStart = (hitStart && hitEnd)

              ? (rawModel - wall.startPoint).distance <=

                    (rawModel - wall.endPoint).distance

              : hitStart;

          final point = atStart ? wall.startPoint : wall.endPoint;

          setState(() {

            _selectedElementId = wall.id;

            if (_activeTool == ArchitectTool.select && !_multiSelect) {

              _activeTool = ArchitectTool.wall;

              _selectionContextActive = true;

            }

            _selectionIds

              ..clear()

              ..add(wall.id);

            _selectedZoneId = null;

          });

          _wallEndpointOriginal = wall;

          _wallDragStart = atStart;

          _wallGrabOffset = point - rawModel;

          _elementMoveOriginal = _project;

          _elementMovePreview = _project;

          _isHandleEngaged = true;

          HapticFeedback.selectionClick();

          ArchitectLogger.log(

            'HANDLE',

            'Wall ${wall.id} auto-selected and endpoint ${atStart ? "start" : "end"} drag engaged',

          );

          return;

        }

      }

    }



    // Midpoint handle check for selected wall (extrusion / step move)

    if (_selectedWall != null &&

        _wallCutIds.isEmpty &&

        _wallExtendId == null &&

        _wallJoinSourceId == null &&

        !_splitActive) {

      final wall = _selectedWall!;

      final mid = wall.referencePointAt(.5);

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



    // 2. Zone Schedule Table hit check (drag table or select it)

    if ((_activeTool == ArchitectTool.zoneTable ||

            _activeTool == ArchitectTool.zone ||

            _activeTool == ArchitectTool.select) &&

        _project.activeStorey.zoneScheduleOrigin != null &&

        _project.activeStorey.zones.isNotEmpty) {

      final tables = ArchitectZonePainterHelper.scheduleTables(

        project: _modelCommands.project, storey: _project.activeStorey,

        l10n: context.l10n, viewKey: _workspaceViewKey, zoomScale: _currentScale,

      );

      for (final table in tables.reversed) {

        if (!table.bounds.contains(rawModel)) continue;

        _selectedZoneTableId = table.group.id;

        _isDraggingZoneTable = true;

        _isHandleEngaged = true;

        _zoneTableDragOffset = table.origin - rawModel;

        _zoneTablePreviewOrigin = table.origin;

        setState(() {

          _isZoneTableSelected = true;

          _selectedZoneId = null;

          _selectedElementId = null;

          _selectionIds.clear();

        });

        HapticFeedback.selectionClick();

        return;

      }

    }



    // Manual zone body movement; vertices and edges use the common editor above

    if (_activeTool == ArchitectTool.zone) {

      final currentSelected = _selectedZone;

      if (currentSelected != null && !currentSelected.isAutoBoundary) {

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



    if (!_splitActive &&

        _effectiveSelection.isNotEmpty &&

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

        _wallExtendId == null &&

        !_mirrorActive &&

        _offsetOptions == null &&

        !_splitActive) {

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

      ((_activeTool != ArchitectTool.select && !_selectionContextActive) ||

          _mirrorActive ||

          _offsetOptions != null ||

          _splitActive ||

          _newPointTargetId != null) &&

      !_wallDirectionLocked &&

      _polygonEditId == null &&

      _pendingShape == null &&

      _wallJoinSourceId == null &&

      _wallCutIds.isEmpty &&

      _wallExtendId == null;



  ArchitectOpeningPlacementResult? get _openingPlacementPreview {

    if (_isOpeningPlacementCoolingDown) return null;

    final raw = _cursorModel;

    if (raw == null ||

        _isActivelyDraggingHandle ||

        (_activeTool != ArchitectTool.door &&

            _activeTool != ArchitectTool.window)) {

      return null;

    }

    final width = _activeTool == ArchitectTool.door

        ? _doorWidth

        : _elementTool.windowWidth;

    final result = ArchitectOpeningPlacement.resolve(

      walls: _project.activeStorey.walls,

      rawPoint: raw,

      openingWidth: width,

      magnetic: _magnetEnabled,

      defaultHingeLeft: _isHingeLeft,

    );

    if (result == null) return null;



    final targetWall = result.wall;

    final candidateAlong = result.offsetRatio * targetWall.length;

    final (rawRatio, _) = targetWall.projectPoint(raw);

    final rawAlong = rawRatio.clamp(0.0, 1.0) * targetWall.length;



    if (ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(

      wall: targetWall,

      candidateAlong: candidateAlong,

      rawAlong: rawAlong,

      openingWidth: width,

    )) {

      return null;

    }



    return result;

  }



  ArchitectDoor? get _doorPreview {

    if (_activeTool != ArchitectTool.door) return null;

    final preview = _openingPlacementPreview;

    if (preview == null) return null;

    final activeStyle =

        _elementTool.activeDoorStyle ??

        FenestrationLibraryService.instance.activeDoorStyle;

    final specId = ArchitectDoor.resolveSpecId(

      existingDoors: _project.allDoors,

      width: _doorWidth,

      height: _doorHeight,

      sillHeight: _doorSill,

      isHingeLeft: preview.isHingeLeft,

    );

    return ArchitectDoor(

      id: 'preview_door',

      wallId: preview.wall.id,

      offsetRatio: preview.offsetRatio,

      width: _doorWidth,

      height: _doorHeight,

      sillHeight: _doorSill,

      isHingeLeft: preview.isHingeLeft,

      openInward: preview.openInward,

      specId: specId,

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

        midpointReferences: _midpointTracking.references,

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

    if (_splitActive && _splitGuidePerpendicular != null) {

      final p1 = _splitGuidePerpendicular!.$1;

      final p2 = _splitGuidePerpendicular!.$2;

      final proj = BimLineGeometry.closest(raw, p1, p2);

      final screenDist = (raw - proj).distance * _currentScale;

      final tol = _touchInput ? 18.0 : 12.0;

      if (screenDist <= tol) {

        final res = ArchitectSnapResult(

          point: proj,

          snapLabel: context.l10n.architectWallSplitPerpendicular,

          magneticGuides: [(p1, p2)],

        );

        _activeSnapLabel = res.snapLabel;

        _activeMagneticGuides = res.magneticGuides;

        return res;

      }

    }

    final snap = anchor == null

        ? ArchitectSnapHelper.snapFree(

            midpointReferences: _midpointTracking.references,

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

            midpointReferences: _midpointTracking.references,

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



  ArchitectSnapResult _snapTransformPoint(Offset raw, bool touch,
      {bool selectionOnly = false, Offset? anchor}) {
    final source = _rotationSource ?? _project;
    final tolerance = (touch ? 12 : 8) / _currentScale;
    if (selectionOnly) {
      return ArchitectSnapHelper.snapFree(rawPoint: raw, project: source,
        tolerance: tolerance, includedIds: _rotationIds,
        midpointReferences: _midpointTracking.references);
    }
    if (anchor != null) {
      return ArchitectSnapHelper.snapWithAnchor(rawPoint: raw, anchor: anchor,
        project: source, tolerance: tolerance, magnetic: _magnetEnabled,
        alignment: true, midpointReferences: _midpointTracking.references,
        underlay: _currentUnderlayDoc, frame: widget.underlayFrame,
        visibility: _underlayLayerVisibility);
    }
    return ArchitectSnapHelper.snapFree(rawPoint: raw, project: source,
      tolerance: tolerance, magnetic: _magnetEnabled, alignment: true,
      midpointReferences: _midpointTracking.references,
      underlay: _currentUnderlayDoc, frame: widget.underlayFrame,
      visibility: _underlayLayerVisibility);
  }

  (Offset, double) _snapComponent(Offset rawModel, ArchitectComponentDefinition def) {

    if (def.placementMode == ComponentPlacementMode.wallAttached) {

      const snapDistance = 0.50;

      for (final wall in _project.activeStorey.walls) {

        final p1 = wall.startPoint;

        final p2 = wall.endPoint;

        final lineVec = p2 - p1;

        final lineLen = lineVec.distance;

        if (lineLen < 1e-4) continue;

        final u = lineVec / lineLen;

        final toPt = rawModel - p1;

        final projDist = toPt.dx * u.dx + toPt.dy * u.dy;

        if (projDist < 0.0 || projDist > lineLen) continue;

        final n = Offset(-u.dy, u.dx);

        final distToBaseline = (toPt.dx * n.dx + toPt.dy * n.dy).abs();

        if (distToBaseline <= snapDistance + wall.thickness / 2.0) {

          final baseProj = p1 + u * projDist;

          final side = (toPt.dx * n.dx + toPt.dy * n.dy) >= 0 ? 1.0 : -1.0;

          final wallFaceNormal = n * side;

          final snapPos = baseProj + wallFaceNormal * (wall.thickness / 2.0);

          final rot = math.atan2(wallFaceNormal.dy, wallFaceNormal.dx) - (math.pi / 2.0);

          return (snapPos, rot);

        }

      }

    }

    return (rawModel, _componentRotation);

  }



  ArchitectSnapResult _snapColumn(Offset raw) {

    final snap = ArchitectColumnSnap.resolve(

      midpointReferences: _midpointTracking.references,

      raw: raw,

      project: _project,

      columnWidth: _elementTool.columnWidth,

      columnDepth: _elementTool.columnDepth,

      columnShape: _elementTool.columnShape,

      currentRotationDeg: _columnPreviewRotation,

      tolerance: (_touchInput ? 14 : 10) / _currentScale,

      magnetic: _magnetEnabled,

      underlay: _currentUnderlayDoc,

      frame: widget.underlayFrame,

      visibility: _underlayLayerVisibility,

    );

    _activeSnapLabel = snap.snapLabel;

    _activeMagneticGuides = snap.magneticGuides;

    return snap;

  }



  ArchitectSnapResult _snapDimensionPoint(Offset raw, {Offset? anchor}) {

    final excludedIds = <String>{

      if (_dimensionEditing != null) _dimensionEditing!.id,

    };

    final snap = anchor == null

        ? ArchitectSnapHelper.snapFree(

            midpointReferences: _midpointTracking.references,

            rawPoint: raw,

            project: _project,

            tolerance: (_touchInput ? 14 : 10) / _currentScale,

            magnetic: _magnetEnabled,

            alignment: true,

            excludeWallAxes: true,

            preferIntersections: _dimensionAllowPoint,

            excludedIds: excludedIds,

            underlay: _currentUnderlayDoc,

            frame: widget.underlayFrame,

            visibility: _underlayLayerVisibility,

          )

        : ArchitectSnapHelper.snapWithAnchor(

            midpointReferences: _midpointTracking.references,

            rawPoint: raw,

            anchor: anchor,

            project: _project,

            tolerance: (_touchInput ? 14 : 10) / _currentScale,

            magnetic: _magnetEnabled,

            alignment: true,

            excludeWallAxes: true,

            preferIntersections: _dimensionAllowPoint,

            excludedIds: excludedIds,

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

      final dotDir = (other.unitVector.dx * u.dx + other.unitVector.dy * u.dy)

          .abs();

      if (dotDir > 0.98) {

        final y = ArchitectDimensionChain.dot(other.lineStart - p0, n);

        targets.add((pos: y, name: 'dimension'));

      }

    }



    // 3. Parallel walls in the active storey:

    for (final wall in _project.activeStorey.walls) {

      final dotDir = (wall.unitVector.dx * u.dx + wall.unitVector.dy * u.dy)

          .abs();

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

    if (_magnetEnabled && ids.length == 1) {

      final movingCol = _elementMoveOriginal!.activeStorey.columns

          .where((c) => ids.contains(c.id))

          .firstOrNull;

      if (movingCol != null) {

        final colSnap = ArchitectColumnSnap.resolve(

          midpointReferences: _midpointTracking.references,

          raw: movingCol.position + delta,

          project: _elementMoveOriginal!,

          columnWidth: movingCol.width,

          columnDepth: movingCol.depth,

          columnShape: movingCol.shape,

          currentRotationDeg: movingCol.rotationDeg,

          tolerance: (_touchInput ? 14 : 10) / _currentScale,

          magnetic: _magnetEnabled,

          excludedIds: ids,

          underlay: _currentUnderlayDoc,

          frame: widget.underlayFrame,

          visibility: _underlayLayerVisibility,

        );

        if (colSnap.isSnapped &&

            (colSnap.snapLabel == 'Door jamb' ||

                colSnap.snapLabel == 'Window jamb')) {

          _activeSnapLabel = colSnap.snapLabel;

          _activeMagneticGuides = colSnap.magneticGuides;

          return colSnap.point - movingCol.position;

        }

      }

    }

    final snap = ArchitectSnapHelper.snapTranslation(

      midpointReferences: _midpointTracking.references,

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

    if (_activeTool != ArchitectTool.select &&

        _activeTool != ArchitectTool.roof) {

      return null;

    }

    final id = _selectedElementId;

    if (id == null || _effectiveSelection.length > 1) return null;

    for (final roof in _project.activeStorey.roofs) {

      if (roof.id == id) return roof;

    }

    return null;

  }



  List<Offset>? get _selectedPolygon {

    if (_effectiveSelection.length > 1) return null;

    final id = _selectedElementId ?? _selectedZoneId;

    if (id == null) return null;

    final holeIndex = _selectedPolygonHoleIndex;
    final host = CutArchitectContourOpening.target(_project.activeStorey, id);
    if (holeIndex != null && host != null && holeIndex < host.$2.length) {
      return host.$2[holeIndex];
    }

    for (final p in _project.activeStorey.cadPrimitives) {

      if (p.id == id && p.isPolygon) {

        return p.polygonCorners;

      }

    }

    for (final drain in _project.activeStorey.floorDrains) {

      if (drain.id == id) return drain.polygon;

    }

    for (final slab in _project.activeStorey.slabs) {

      if (slab.id == id) return slab.polygon;

    }

    for (final roof in _project.activeStorey.roofs) {

      if (roof.id == id) return roof.points;

    }

    for (final zone in _project.activeStorey.zones) {

      if (zone.id == id) return (_polygonEditId == id || !zone.isAutoBoundary) ? zone.polygon : null;

    }

    for (final opening in _project.activeStorey.openings) {

      if (opening.id == id) return opening.boundary;

    }

    return null;

  }



  void _updatePointerPreview(Offset screenPosition) {

    if (_pendingShape != null) return;

    final rawModel = _screenToModel(screenPosition);

    if (_offsetOptions != null) {

      _previewOffset(rawModel);

      return;

    }

    _updateMidpointReferences(rawModel);

    if (_sectionRoofDragStartModelY != null &&

        _sectionRoofDragInitialOffset != null &&

        _selectedSectionRoofId != null) {

      final deltaZ = -(rawModel.dy - _sectionRoofDragStartModelY!);

      _sectionRoofDragPreviewOffset = _sectionRoofDragInitialOffset! + deltaZ;

      _projectionSource = null;

      _repaintPreview();

      return;

    }

    if (_isDraggingRoofKnuckle &&
        _draggingRoofKnuckleId != null &&
        _knuckleDragStartPoint != null &&
        _knuckleDragInitialBreakDist != null) {
      final roof = _project.activeStorey.roofs
          .where((r) => r.id == _draggingRoofKnuckleId)
          .firstOrNull;
      if (roof != null) {
        final delta = rawModel - _knuckleDragStartPoint!;
        final slopeDir = roof.slopeDirection;
        final dProj = delta.dx * slopeDir.dx + delta.dy * slopeDir.dy;
        final maxRun = roof.maxSlopeRun;
        final nextDist = (_knuckleDragInitialBreakDist! + dProj)
            .clamp(0.25, math.max(0.35, maxRun - 0.25))
            .toDouble();
        final updated = roof.copyWith(breakDistance: nextDist);
        setState(() {
          _commands.execute(
            UpdateArchitectRoofPlane(
              storeyId: _project.activeStoreyId,
              roof: updated,
            ),
          );
        });
      }
      return;
    }

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

      } else if (!_dimensionPlacing && !_dimensionChoosingDirection) {

        final snap = _snapDimensionPoint(rawModel);

        _cursorModel = snap.point;

      }

      _repaintPreview();

      return;

    }

    if (_activeTool == ArchitectTool.dimension &&

        !_dimensionPlacing &&

        !_isActivelyDraggingHandle) {

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

        (point) {

          _updateMidpointReferences(point);

          return _snapApartmentEditPoint(point) ?? ArchitectSnapHelper.snapFree(

            midpointReferences: _midpointTracking.references,

            rawPoint: point,

            project: _elementMoveOriginal!,

            tolerance: 12 / _currentScale,

            magnetic: _magnetEnabled,

            alignment: true,

            excludedIds: {_polygonEditor.elementId!},

            underlay: _currentUnderlayDoc,

            frame: widget.underlayFrame,

            visibility: _underlayLayerVisibility,

          );

        },

        math.min(12 / _currentScale, .20),

      );

      final snap = _polygonEditor.activeSnap;

      _activeSnapLabel = snap?.snapLabel;

      _activeMagneticGuides = snap?.magneticGuides ?? [];

      try {
        _elementMovePreview = UpdateArchitectPolygon(

        storeyId: _project.activeStoreyId,

        elementId: _polygonEditor.elementId!,

        polygon: _polygonEditor.preview!,
        holeIndex: _selectedPolygonHoleIndex,

        ).apply(_elementMoveOriginal!);
      } on ArgumentError {
        _polygonEditor.invalid = true;
      }

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

    if (_linearDraftTool && _draftStart == null && !_isActivelyDraggingHandle) {

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

          cadPrimitives: _project.activeStorey.cadPrimitives

              .where((p) => p.id != original.id)

              .toList(),

        ),

      );

      final rawTarget = rawModel + _wallGrabOffset - _wallEndpointDisplacement;

      _updateMidpointReferences(rawTarget);

      final origVec = original.endPoint - original.startPoint;

      final origDir = origVec.distance > 1e-4

          ? origVec / origVec.distance

          : const Offset(1, 0);

      final origNormal = Offset(-origDir.dy, origDir.dx);

      final snap = ArchitectWallSnap.resolve(

        midpointReferences: _midpointTracking.references,

        raw: rawTarget,

        magnetic: _magnetEnabled,

        anchor: _wallDragStart ? original.endPoint : original.startPoint,

        project: snapProject,

        scale: _currentScale,

        underlay: _currentUnderlayDoc,

        frame: widget.underlayFrame,

        visibility: _underlayLayerVisibility,

        referenceDirections: [origDir, origNormal],

      );

      final updated = original.copyWith(

        startPoint: _wallDragStart ? snap.point : null,

        endPoint: _wallDragStart ? null : snap.point,

      );

      if (_wallEndpointIsOffset) {

        _wallEndpointLeaderLine = (snap.point, rawModel + _wallGrabOffset);

      }

      try {

        _elementMovePreview = _linearCommand(

          UpdateArchitectWall(

            storeyId: _project.activeStorey.id,

            wall: updated,

            carryConnections: false,

          ),

        ).apply(_elementMoveOriginal!);

        _activeSnapLabel = snap.snapLabel;

        _activeMagneticGuides = snap.magneticGuides;

      } on ArgumentError {

        /* Keep the last valid preview. */

      }

      _repaintPreview();

      return;

    }

    if (_drainDragOriginal != null && _elementMoveOriginal != null) {

      final original = _drainDragOriginal!;

      final rawTarget = rawModel + _drainGrabOffset;

      final clearance = _handleOffsetLength / _currentScale;

      final handlePt = ArchitectFloorDrainPainterHelper.offsetHandle(original, clearance);

      final displacement = _drainDragIsOffset ? (handlePt - original.position) : Offset.zero;

      final nextPos = rawTarget - displacement;

      final updated = original.copyWith(position: nextPos);

      try {

        _elementMovePreview = UpdateArchitectFloorDrain(

          storeyId: _project.activeStoreyId,

          drain: updated,

        ).apply(_elementMoveOriginal!);

      } on ArgumentError { /* ignore */ }

      _repaintPreview();

      return;

    }



    if (_activeTool == ArchitectTool.column && !_isActivelyDraggingHandle) {

      final snap = _snapColumn(rawModel);

      _columnPreviewPoint = snap.point;

      _columnPreviewRotation = snap.angleDeg ?? 0.0;

      _activeSnapLabel = snap.snapLabel;

      _activeMagneticGuides = snap.magneticGuides;

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

          _linearEditWalls.any(

            (w) => _groupDragIds.contains(w.id),

          )) {

        final alignment = ArchitectWallAlignment.move(

          _linearEditWalls,

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

      final selectedWall = _selectedLinearElement;

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

          _linearEditWalls,

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

          _elementMoveDelta = delta;

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

      _axisTool.updateMoving(

        rawModel,

        _project.gridAxes,

        _currentScale,

        walls: _project.activeStorey.walls,

        magnetic: _magnetEnabled,

      );

      _activeMagneticGuides = _axisTool.moveWallGuide == null

          ? []

          : [_axisTool.moveWallGuide!];

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



    // Zone Schedule Table dragging

    if (_isDraggingZoneTable && _zoneTableDragOffset != null) {

      _zoneTablePreviewOrigin = rawModel + _zoneTableDragOffset!;

      _repaintPreview();

      return;

    }



    // 1. Point-by-point zone drafting preview

    if (_activeTool == ArchitectTool.zone && _zoneTool.isDrafting) {

      _updateZoneDraftingPointer(rawModel);

      _cursorModel = _zoneTool.candidatePoint;

      _repaintPreview();

      return;

    }



    // 4. Moving whole zone on canvas

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



    if (_activeTool == ArchitectTool.select && _marqueeTool.isDrafting) {
      _marqueeTool.updateCandidate(rawModel);
      _repaintPreview();
      return;
    }

    // 5. Wall drafting preview

    if (_linearDraftTool && _draftStart != null) {

      if (_activeTool == ArchitectTool.wall &&

          _wallCurved &&

          _wallArcEnd != null) {

        _draftEnd = _snapElement(rawModel).point;

        _repaintPreview();

        return;

      }

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



    // Mirror aiming and real-time preview
    if (_mirrorActive) {
      _previewMirrorSnap(_snapElement(rawModel, anchor: _mirrorAnchor));
      return;
    }

    // Split aiming and real-time preview

    if (_splitActive) {

      final snap = _snapElement(rawModel, anchor: _splitPoint1);

      _cursorModel = snap.point;

      _activeSnapLabel = snap.snapLabel;

      _activeMagneticGuides = snap.magneticGuides;

      _repaintPreview();

      return;

    }



    if (_newPointTargetId != null) {

      _updateNewPointCandidate(rawModel, isTouch: _touchInput);

      return;

    }



    // 7. Slab or Roof drafting candidate

    if ((_activeTool == ArchitectTool.slab || _activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.floorDrain) &&

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

    final isPolyMode =

        _roofTool.drawMode == RoofDrawMode.polygon ||

        _roofTool.drawMode == RoofDrawMode.multiPitch;

    final anchor = isPolyMode ? points.lastOrNull : null;

    final snap = _snapElement(raw, anchor: anchor);

    final midpointSnap = snap.snapLabel == 'Midpoint' ||

        snap.snapLabel == 'Midpoint alignment';

    if (isPolyMode && points.length >= 3) {

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

      if (closure.isSnapped && !midpointSnap) {

        _activeSnapLabel = context.l10n.snapAlignPoint1;

        _activeMagneticGuides = closure.magneticGuides;

        return closure.point;

      }

    }

    var pt = snap.point;

    var snapLabel = snap.snapLabel;

    var guides = snap.magneticGuides;



    // Check hip angle guides and intersections from anchor
    if (anchor != null && _magnetEnabled && !midpointSnap) {
      final l10n = context.l10n;
      final snapTol = (_touchInput ? 16 : 10) / _currentScale;
      final roofGuide = ArchitectRoofGeometry.resolveRoofGuideSnap(
        raw: raw,
        anchor: anchor,
        draftPoints: points,
        activeStorey: _project.activeStorey,
        currentSlopeDegrees: _roofTool.slopeDegrees,
        snapTolerance: snapTol,
        hip45Label: () => l10n.architectRoofSnap45Degrees,
        hipAngleLabel: (deg) => l10n.architectRoofSnapHipAngle(deg),
        hipIntersectionLabel: () => l10n.architectRoofSnapHipIntersection,
        cornerHipIntersectionLabel: () =>
            l10n.architectRoofSnapCornerHipIntersection,
        ridgeAlignmentLabel: () => l10n.architectRoofSnapRidgeAlignment,
        perpToCornerLabel: () => l10n.architectRoofSnapPerpToCorner,
      );

      if (roofGuide != null) {
        pt = roofGuide.point;
        snapLabel = roofGuide.snapLabel;
        guides = roofGuide.magneticGuides;
      }
    }



    _activeSnapLabel = snapLabel;

    _activeMagneticGuides = guides;

    return pt;

  }



  ArchitectSnapResult? _snapApartmentEditPoint(Offset point) {

    if (!_magnetEnabled || _selectedZone?.isApartment != true) return null;

    final snapped = ArchitectApartmentZones.snapBoundary(point,

      _project.activeStorey.walls, math.min(18 / _currentScale, .25));

    return snapped == null ? null : ArchitectSnapResult(point: snapped,

      isSnapped: true, snapLabel: context.l10n.architectApartment);

  }



  Offset _resolveSlabPoint(Offset raw) =>

      _resolveContourPoint(_elementTool.slabDraftPoints, raw);



  void _updateZoneDraftingPointer(Offset raw) {

    final point = _resolveContourPoint(_zoneTool.draftPoints, raw);

    _zoneTool.updateDraftingPointer(

      rawModelPoint: raw,

      project: _project,

      currentScale: _currentScale,

      resolvedSnap: ArchitectSnapResult(

        point: point,

        snapLabel: _activeSnapLabel,

        magneticGuides: _activeMagneticGuides,

      ),

    );

  }



  Offset _resolveContourPoint(List<Offset> points, Offset raw) {

    if (_activeTool == ArchitectTool.zone && _activeZoneKind == ArchitectZoneKind.apartment && _magnetEnabled) {

      final boundary = ArchitectApartmentZones.snapBoundary(raw, _project.activeStorey.walls, math.min(18 / _currentScale, .25));

      if (boundary != null) {

        _activeSnapLabel = context.l10n.architectApartment;

        _activeMagneticGuides = [];

        return boundary;

      }

    }

    final snap = _snapElement(raw, anchor: points.lastOrNull);

    final midpointSnap = snap.snapLabel == 'Midpoint' ||

        snap.snapLabel == 'Midpoint alignment';

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

      if (closure.isSnapped && !midpointSnap) {

        _activeSnapLabel = context.l10n.snapAlignPoint1;

        _activeMagneticGuides = closure.magneticGuides;

        return closure.point;

      }

    }

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

      _isDraggingRoofKnuckle = false;
    _draggingRoofKnuckleId = null;
    _knuckleDragInitialBreakDist = null;
    _knuckleDragStartPoint = null;

    _draftCancelPointer = null;

      return;

    }

    if (_controlTrimClick) {

      _controlTrimClick = false;

      return;

    }

    if (_newPointTargetId != null) {

      _commitNewPoint();

      return;

    }

    if (_isDraggingVertexOrHandle && !_handleMoved) {

      if (_sectionRoofDragStartModelY != null) {

        _cancelActiveDrags();

        _repaintPreview();

        return;

      }

      final pos = _screenToModel(event.localPosition);

      if (_polygonEditId != null || _selectedRoof != null) {

        _selectPolygonEdge(pos);

      }

      _cancelActiveDrags();

      if (_polygonEditId == null && _selectedRoof == null && !_moveSelection) {

        _selectAt(

          pos,

          toggle:

              _multiSelect ||

              _activeTool == ArchitectTool.select ||

              HardwareKeyboard.instance.isShiftPressed ||

              HardwareKeyboard.instance.isControlPressed,

        );

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

          _linearCommand(

            CutArchitectWalls(

              storeyId: _project.activeStoreyId,

              wallIds: Set.of(_wallCutIds),

              start: cutStart,

              end: cutEnd,

            ),

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

    _viewDirectionDraft = null;
    _rotationSource = null;
    _rotationIds = {};
    _offsetEpoch++;

    _offsetOptions = null;

    _offsetSource = null;

    _offsetSide = null;

    _offsetValid = false;

    _offsetIds = {};

    _offsetIdMap = {};

    _offsetGroupIdMap = {};

    _midpointTracking.clear();

    if (_sectionRoofDragStartModelY != null ||

        _sectionRoofDragPreviewOffset != null) {

      _sectionRoofDragStartModelY = null;

      _sectionRoofDragInitialOffset = null;

      _sectionRoofDragPreviewOffset = null;

      _projectionSource = null;

    }

    _isDraggingRoofKnuckle = false;
    _draggingRoofKnuckleId = null;
    _knuckleDragInitialBreakDist = null;
    _knuckleDragStartPoint = null;

    _draftCancelPointer = null;

    _duplicateMove?.cancel();

    _duplicateMove = null;

    _duplicateMoveId = null;

    _duplicateSourceId = null;

    _polygonEditor.cancel();

    _radialMenuScreenPosition = null;

    _controlTrimClick = false;

    _groupDragIds = {};

    _isHandleEngaged = false;
    _handleMoved = false;
    _handlePointerDown = null;
    _draggingElementId = null;
    _elementMoveStart = null;
    _elementMoveDelta = null;
    _elementMoveOriginal = null;
    _elementMovePreview = null;

    _placingWithHold = false;

    _touchPosition = null;

    _wallEndpointOriginal = null;

    _wallSnapProject = null;

    _wallEndpointIsOffset = false;

    _wallEndpointDisplacement = Offset.zero;

    _wallEndpointLeaderLine = null;

    _drainDragOriginal = null;

    _drainDragIsOffset = false;

    _drainGrabOffset = Offset.zero;

    _handleMoved = false;

    _handlePointerDown = null;

    _draggingElementId = null;

    _elementMoveStart = null;

    _elementMoveDelta = null;

    _elementMoveOriginal = null;

    _elementMovePreview = null;

    _isHandleEngaged = false;

    _zoneMoveStartPoint = null;

    _zoneMoveOriginalPolygon = null;

    _zoneMovePreviewPolygon = null;

    _activeMagneticGuides = [];

    _activeSnapLabel = null;

    if (_axisTool.isDraggingHandle ||

        _axisTool.isMovingAxis ||

        _axisTool.isOffsettingWithDrag) {

      _axisTool.cancelAll();

    }

    _isDraggingZoneTable = false;

    _zoneTableDragOffset = null;

    _zoneTablePreviewOrigin = null;

  }



  void _commitActiveHandleDrag(Offset screenPos) {

    if (_isDraggingRoofKnuckle) {
      _isDraggingRoofKnuckle = false;
      _draggingRoofKnuckleId = null;
      _knuckleDragInitialBreakDist = null;
      _knuckleDragStartPoint = null;
      _saveBiMProjectIfAttached();
      HapticFeedback.selectionClick();
      return;
    }

    if (_isDraggingZoneTable && _zoneTablePreviewOrigin != null) {

      final newOrigin = _zoneTablePreviewOrigin!;

      final tableId = _selectedZoneTableId;

      final current = _project.activeStorey;

      final tables = ArchitectZonePainterHelper.scheduleTables(project: _project,

        storey: current, l10n: context.l10n, viewKey: _workspaceViewKey, zoomScale: _currentScale);

      final origins = {for (final t in tables) t.group.id: t.origin};

      _cancelActiveDrags();

      setState(() {

        _project = _project.updateActiveStorey(current.copyWith(

          zoneScheduleOrigin: tableId == 'unassigned' ? newOrigin : current.zoneScheduleOrigin,

          zones: [for (final z in current.zones) z.isApartment

            ? z.copyWith(scheduleOrigin: z.id == tableId ? newOrigin : origins[z.id]) : z],

        ));

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

      return;

    }

    if (_sectionRoofDragStartModelY != null &&

        _sectionRoofDragPreviewOffset != null &&

        _selectedSectionRoofId != null) {

      final roofId = _selectedSectionRoofId!;

      final nextOffset = _sectionRoofDragPreviewOffset!;

      final changed =

          (_sectionRoofDragInitialOffset! - nextOffset).abs() > 1e-6;

      _cancelActiveDrags();

      if (changed) {

        final hit = ArchitectBuildingSection.findRoofById(

          _modelCommands.project,

          roofId,

        );

        if (hit != null) {

          _modelCommands.execute(

            UpdateArchitectRoofPlane(

              storeyId: hit.storey.id,

              roof: hit.roof.copyWith(

                baseElevationOffset: nextOffset,

                attachToWalls: false,

              ),

            ),

          );

          _saveBiMProjectIfAttached();

        }

      }

      return;

    }

    if (_duplicateMove != null) {

      final id = _duplicateMoveId;

      final preview = _duplicateMove!.finish(_elementMoveContext);

      _cancelActiveDrags();

      if (preview != null) {

        _commands.commit(preview);

        setState(() {

          _selectionIds..clear()..addAll({?id});

          _selectedElementId = id;

          _selectedZoneId = null;

        });

        _saveBiMProjectIfAttached();

      }

      return;

    }

    if (_polygonEditor.active) {

      final id = _polygonEditor.elementId!, points = _polygonEditor.preview!;
      final holeIndex = _selectedPolygonHoleIndex;

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
            holeIndex: holeIndex,

          ),

        );

        _saveBiMProjectIfAttached();

        if (_polygonEditId == id || _selectedRoof?.id == id) {

          _polygonSelectedEdge = editedEdge;

        }

      } else if (!valid) {

        _operationError();

      }

      return;

    }

    if (_groupDragIds.isNotEmpty ||

        _wallEndpointOriginal != null ||

        _drainDragOriginal != null ||

        _draggingElementId != null) {

      final preview = _finishElementMove(

        changed:

            _wallEndpointOriginal != null ||

            _drainDragOriginal != null ||

            (_elementMoveDelta?.distance ?? 0) > 1e-9,

      );

      _cancelActiveDrags();

      if (preview != null) {

        _commands.commit(preview);

        _saveBiMProjectIfAttached();

        _syncAutoZones(preview.activeStorey);

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

    if (_offsetOptions != null) {

      _commitOffset(rawModel);

      return;

    }

    if (_cutOpeningTargetId != null) {

      final pt = _resolveSlabPoint(rawModel);

      if (_elementTool.slabDraftPoints.length >= 3 &&

          (pt - _elementTool.slabDraftPoints.first).distance <=

            math.min(16.0 / _currentScale, .20)) {

        _commitCutOpening();

      } else {

        setState(() => _elementTool.addSlabPoint(pt));

      }

      return;

    }

    if (_activeTool == ArchitectTool.floorDrain && _drainFromRoom &&

        _effectiveSelection.isEmpty) {

      final contour = ArchitectClosedContour.detect(_project.activeStorey, rawModel);

      if (contour == null) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(

          content: Text(context.l10n.architectDrainRoomNotFound)));

      } else {

        _commitFloorDrain(contour: contour);

      }

      return;

    }



    if (_activeTool == ArchitectTool.hatch && _automaticHatch &&

        _effectiveSelection.isEmpty) {

      final contour = ArchitectClosedContour.detect(_project.activeStorey, rawModel);

      if (contour == null) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(

          content: Text(context.l10n.architectHatchAutoFailed)));

      } else {

        _commitHatch(contour: contour);

      }

      return;

    }



    if (_placingDownpipe) {

      _placeDownpipe(rawModel);

      return;

    }

    if (_pendingShape != null || _polygonDistanceOpen) return;



    if (_mirrorActive) {
      _pickMirrorSnap(_snapElement(rawModel, anchor: _mirrorAnchor));
      return;
    }

    if (_splitActive) {

      _handleSplitTap(rawModel);

      return;

    }



    if (_newPointTargetId != null) {

      _commitNewPoint();

      return;

    }



    // A rapid second wall tap while drafting must not invoke selection's double tap.

    if (_activeTool == ArchitectTool.dimension &&

        (_dimensionChainMode || _dimensionPlacing) &&

        !_multiSelect &&

        _effectiveSelection.isEmpty) {

      _handleDimensionChainTap(rawModel);

      return;

    }



    final candidates = _selectionCandidates(rawModel);

    if (_commands.view == ArchitectWorkspaceView.section &&

        (_activeTool == ArchitectTool.select ||

            _activeTool == ArchitectTool.roof) &&

        candidates.isEmpty &&

        _draftStart == null &&

        !_axisTool.isDrafting &&

        !_zoneTool.isDrafting &&

        !_roofTool.isDrafting &&

        _elementTool.slabDraftPoints.isEmpty) {

      _cacheProjection();

      final hitRoof = _sectionGeometry?.pickRoof(

        _modelToSection(rawModel),

        14 / _currentScale,

      );

      if (hitRoof != null) {

        setState(() {

          _selectionIds.clear();

          _selectedElementId = null;

          _selectedZoneId = null;

          _selectedSectionRoofId = hitRoof;

          if (!_multiSelect && _acceptsAnySelection) {

            _activeTool = ArchitectTool.roof;

            _selectionContextActive = true;

          }

        });

        HapticFeedback.selectionClick();

        return;

      } else if (_selectedSectionRoofId != null) {

        setState(() => _selectedSectionRoofId = null);

      }

    }



    final now = DateTime.now();

    final isDoubleTap =

        candidates.length <= 1 &&

        _lastTapTime != null &&

        _lastTapPos != null &&

        now.difference(_lastTapTime!) < const Duration(milliseconds: 380) &&

        (rawModel - _lastTapPos!).distance * _currentScale < 25;

    _lastTapTime = now;

    _lastTapPos = rawModel;



    if (isDoubleTap && !_multiSelect && !_selectionContextActive && _editingGroupId == null) {

      final hitId = _hitSelection(rawModel);

      if (hitId != null && _isElementAllowedForTool(hitId, _activeTool)) {

        final storey = _project.activeStorey;

        if ((_activeTool == ArchitectTool.wall ||

                _activeTool == ArchitectTool.select) &&

            storey.walls.any((w) => w.id == hitId)) {

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

        } else if ((_activeTool == ArchitectTool.column ||

                _activeTool == ArchitectTool.select) &&

            storey.columns.any((c) => c.id == hitId)) {

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

        } else if ((_activeTool == ArchitectTool.beam ||

                _activeTool == ArchitectTool.select) &&

            storey.beams.any((b) => b.id == hitId)) {

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

        } else if ((_activeTool == ArchitectTool.slab ||

                _activeTool == ArchitectTool.select) &&

            storey.slabs.any((s) => s.id == hitId)) {

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

        } else if ((_activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.select) &&

            storey.cadPrimitives.any((p) => p.id == hitId && p.type == CadPrimitiveType.hatch)) {

          setState(() {

            _selectionIds

              ..clear()

              ..addAll(storey.cadPrimitives.where((p) => p.type == CadPrimitiveType.hatch).map((p) => p.id));

            _selectedElementId = hitId;

            _selectedZoneId = null;

            _multiSelect = true;

          });

          HapticFeedback.mediumImpact();

          return;

        } else if ((_activeTool == ArchitectTool.roof ||

                _activeTool == ArchitectTool.select) &&

            storey.roofs.any((r) => r.id == hitId)) {

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

        setState(() {

          _wallCutStroke = true;

          _wallCutStart = rawModel;

        });

        return;

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

          _linearCommand(

            CutArchitectWalls(

              storeyId: _project.activeStoreyId,

              wallIds: Set.of(_wallCutIds),

              start: cutStart,

              end: cutEnd,

            ),

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

      final joiningLines = _selectedLineIds.contains(sourceId);

      final hit = _hitSelection(rawModel);

      var hitWall = _linearEditWalls

          .where(

            (w) =>

                (w.id == hit ||

                    w.doors.any((d) => d.id == hit) ||

                    w.windows.any((win) => win.id == hit)) &&

                w.id != sourceId,

          )

          .firstOrNull;

      hitWall ??= _linearEditWalls.where((w) {

        if (w.id == sourceId) return false;

        return w.containsPoint(

          rawModel,

          tolerance: math.max(16.0 / _currentScale, 0.25),

        );

      }).firstOrNull;



      if (hitWall != null) {

        try {

          _commands.execute(

            _linearCommand(

              JoinArchitectWalls(

                storeyId: _project.activeStoreyId,

                wallIds: {sourceId, hitWall.id},

              ),

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

              content: Text(

                (joiningLines

                    ? context.l10n.architectLineJoinSuccess

                    : context.l10n.architectWallJoinSuccess),

              ),

              duration: const Duration(seconds: 2),

            ),

          );

        } on ArgumentError {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(

                (joiningLines

                    ? context.l10n.architectLineJoinIncompatible

                    : context.l10n.architectWallJoinIncompatible),

              ),

              duration: const Duration(seconds: 2),

            ),

          );

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

      setState(() {

        _wallJoinSourceId = null;

        _wallJoinPointer = null;

      });

      return;

    }

    if (_wallExtendId != null) {

      final wall = _linearEditWalls.firstWhere((w) => w.id == _wallExtendId);

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

      for (final w in _linearEditWalls.where(

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

    if (_activeTool == ArchitectTool.select) {
      if (_marqueeTool.isDrafting) {
        if (_marqueeTool.mode == ArchitectSelectMode.rectangle) {
          _marqueeTool.addPoint(rawModel);
          final poly = _marqueeTool.previewPolygon;
          final hits = ArchitectMarqueeTool.evaluateSelection(
            storey: _project.activeStorey,
            project: _project,
            polygon: poly,
          );
          setState(() {
            if (_multiSelect) {
              _selectionIds.addAll(hits);
            } else {
              _selectionIds
                ..clear()
                ..addAll(hits);
            }
            if (_selectionIds.isNotEmpty) _selectionContextActive = true;
            _marqueeTool.cancel();
          });
          HapticFeedback.selectionClick();
          return;
        } else {
          // Polygon mode
          if (_marqueeTool.points.length >= 3 &&
              (rawModel - _marqueeTool.points.first).distance <=
                  math.min(20.0 / _currentScale, 0.40)) {
            final poly = _marqueeTool.previewPolygon;
            final hits = ArchitectMarqueeTool.evaluateSelection(
              storey: _project.activeStorey,
              project: _project,
              polygon: poly,
            );
            setState(() {
              if (_multiSelect) {
                _selectionIds.addAll(hits);
              } else {
                _selectionIds
                  ..clear()
                  ..addAll(hits);
              }
              if (_selectionIds.isNotEmpty) _selectionContextActive = true;
              _marqueeTool.cancel();
            });
            HapticFeedback.selectionClick();
            return;
          } else {
            setState(() {
              _marqueeTool.addPoint(rawModel);
            });
            HapticFeedback.lightImpact();
            return;
          }
        }
      }

      if (_selectionContextActive) {
        _handleSelectionTap(rawModel);
        return;
      }

      if (_selectAt(rawModel, toggle: _multiSelect)) {
        return;
      }

      setState(() {
        _marqueeTool.addPoint(rawModel);
      });
      HapticFeedback.selectionClick();
      return;
    }



    // A tap selects at the finger/cursor. Only an intentional hold places a

    // column, and an existing column always takes priority over placement.

    if (_activeTool == ArchitectTool.column &&

        (!_placingWithHold || _hitSelection(rawModel) != null)) {

      if (!_selectAt(rawModel)) _clearSelection();

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

        _activeTool != ArchitectTool.door &&

        _activeTool != ArchitectTool.window &&

        !(_activeTool == ArchitectTool.axis &&

            _wallForAxis(rawModel) != null) &&

        _selectDraftingElement(rawModel)) {

      return;

    }



    // In Door tool: Select existing door first, otherwise place door

    if (_activeTool == ArchitectTool.door) {

      if (_isOpeningPlacementCoolingDown) return;

      final hitDoor = _hitSelection(rawModel);

      if (hitDoor != null) {

        _selectAt(rawModel);

        return;

      }

      final placement = ArchitectOpeningPlacement.resolve(

        walls: _project.activeStorey.walls,

        rawPoint: rawModel,

        openingWidth: _doorWidth,

        magnetic: _magnetEnabled,

        defaultHingeLeft: _isHingeLeft,

      );

      if (placement != null) {

        final targetWall = placement.wall;

        final candidateAlong = placement.offsetRatio * targetWall.length;

        final (rawRatio, _) = targetWall.projectPoint(rawModel);

        final rawAlong = rawRatio.clamp(0.0, 1.0) * targetWall.length;



        if (ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(

          wall: targetWall,

          candidateAlong: candidateAlong,

          rawAlong: rawAlong,

          openingWidth: _doorWidth,

        )) {

          return;

        }



        _tryPlaceDoorAt(rawModel);

        return;

      }

      _clearSelection();

      return;

    }



    // In Window tool: Select existing window first, otherwise place window

    if (_activeTool == ArchitectTool.window) {

      if (_isOpeningPlacementCoolingDown) return;

      final hitWin = _hitSelection(rawModel);

      if (hitWin != null) {

        _selectAt(rawModel);

        return;

      }

      final placement = ArchitectOpeningPlacement.resolve(

        walls: _project.activeStorey.walls,

        rawPoint: rawModel,

        openingWidth: _elementTool.windowWidth,

        magnetic: _magnetEnabled,

      );

      if (placement != null) {

        final targetWall = placement.wall;

        final candidateAlong = placement.offsetRatio * targetWall.length;

        final (rawRatio, _) = targetWall.projectPoint(rawModel);

        final rawAlong = rawRatio.clamp(0.0, 1.0) * targetWall.length;



        if (ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(

          wall: targetWall,

          candidateAlong: candidateAlong,

          rawAlong: rawAlong,

          openingWidth: _elementTool.windowWidth,

        )) {

          return;

        }



        final res = _elementTool.placeWindow(

          storey: _project.activeStorey,

          point: rawModel,

          magnetic: _magnetEnabled,

        );

        if (res != null) {

          final (updatedStorey, newWin) = res;

          _startOpeningCooldown();

          setState(() {

            _cursorModel = null;

            _selectionIds.clear();

            _selectedElementId = null;

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

      _clearSelection();

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

        _updateZoneDraftingPointer(rawModel);



        final distToStart = _zoneTool.draftPoints.isNotEmpty

            ? (rawModel - _zoneTool.draftPoints.first).distance

            : double.infinity;

        final closeThreshold = math.min(16.0 / _currentScale, 0.20);



        if (_zoneTool.isClosingSnap ||

            _zoneTool.pointStatus == ZoneDraftingPointStatus.closeTarget ||

            (_zoneTool.draftPoints.length >= 3 &&

                distToStart <= closeThreshold)) {

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



      // Handle empty space tap based on placementMode:

      if (_zoneTool.placementMode == ArchitectZonePlacementMode.autoClick) {

        final roomPoly = ArchitectRoomDetector.detectRoomPolygon(

          seedPoint: rawModel,

          walls: _project.activeStorey.walls,

        );

        if (roomPoly != null && roomPoly.length >= 3) {

          final nextNumber = (_project.activeStorey.zones.length + 1)

              .toString();

          final newZone = _zoneTool.createAutoZone(

            polygon: roomPoly,

            seedPoint: rawModel,

            category: _activeZoneCategory,

            name: _zonePresets.categoryName(_activeZoneCategory, context.l10n),

            number: nextNumber,

          );

          setState(() {

            _commands.execute(

              CreateArchitectZone(

                storeyId: _project.activeStorey.id,

                zone: _applyZoneFinishPresets(newZone),

              ),

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

                context.l10n.architectZoneCreated(

                  newZone.name,

                  BimDistanceUnit.trimZeros(newZone.area.toStringAsFixed(2)),

                ),

              ),

              duration: const Duration(seconds: 1),

            ),

          );

        } else {

          HapticFeedback.heavyImpact();

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(context.l10n.architectZoneAutoFailed),

              duration: const Duration(seconds: 2),

            ),

          );

        }

        return;

      } else {

        // Same initial object snap as the slab contour tool.

        final startPt = _resolveContourPoint(const [], rawModel);

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

    }



    // 3. In Zone Table tool: Place or reposition schedule table

    if (_activeTool == ArchitectTool.zoneTable) {

      final updatedStorey = _placedZoneSchedules(rawModel);

      setState(() {

        _project = _project.updateActiveStorey(updatedStorey);

        _isZoneTableSelected = true;

        _selectedZoneId = null;

        _selectedElementId = null;

        _selectionIds.clear();

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(context.l10n.architectZoneTablePlaced),

          duration: const Duration(seconds: 1),

        ),

      );

      return;

    }



    if (_isZoneTableSelected) {

      setState(() => _isZoneTableSelected = false);

    }



    if (_effectiveSelection.isNotEmpty) {

      _handleSelectionTap(rawModel);

      return;

    }

    if (_activeTool == ArchitectTool.select) {

      _selectAt(rawModel, toggle: _multiSelect);

      return;

    }



    // 4. In Wall tool

    if (_linearDraftTool) {

      if (_activeTool == ArchitectTool.wall &&

          _wallCurved &&

          _wallArcEnd != null) {

        _draftEnd = _snapElement(rawModel).point;

        _commitWallArc();

        return;

      }

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

        if (_activeTool == ArchitectTool.wall &&

            _wallCurved &&

            (snap.point - _draftStart!).distance >= .001) {

          setState(() {

            _wallArcEnd = snap.point;

            final chord = snap.point - _draftStart!,

                normal = Offset(-chord.dy, chord.dx) / chord.distance;

            _draftEnd =

                (_draftStart! + snap.point) / 2 +

                normal * (chord.distance * .2);

          });

          return;

        }

        if ((snap.point - _draftStart!).distance >= .001 &&

            _wallPrecisionMode && !_viewMarkerTool) {

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



    // 7. In Column tool

    // 6B. In Component tool

    if (_activeTool == ArchitectTool.component) {

      final activeDef = ComponentLibraryService.instance.activeDefinition;

      final activeParams = ComponentLibraryService.instance.activeParameters;

      final (pos, rot) = _snapComponent(rawModel, activeDef);

      final newComp = ArchitectComponentInstance(

        id: "comp_${DateTime.now().millisecondsSinceEpoch}",

        definitionId: activeDef.id,

        position: pos,

        rotation: rot,

        parameters: Map.of(activeParams),

      );

      final updatedComponents = [..._project.activeStorey.components, newComp];

      final updatedStorey = _project.activeStorey.copyWith(components: updatedComponents);

      setState(() {

        _project = _project.copyWith(

          storeys: [

            for (final s in _project.storeys)

              if (s.id == updatedStorey.id) updatedStorey else s,

          ],

        );

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.lightImpact();

      return;

    }



    if (_activeTool == ArchitectTool.column) {

      final snap = _snapColumn(rawModel);

      final pt = snap.point;

      // Snapping can move the placement marker onto an existing column.

      if (_project.activeStorey.columns.any(

        (column) => column.containsPoint(pt, tolerance: 0),

      )) {

        _selectAt(pt);

        return;

      }

      final rot = snap.angleDeg ?? _columnPreviewRotation;

      final (_, newCol) = _elementTool.placeColumn(

        storey: _project.activeStorey,

        point: pt,

        rotationDeg: rot,

        existingColumns: _project.storeys.expand((s) => s.columns),

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

            _wallArcEnd = null;

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

            _wallArcEnd = null;

            _draftEnd = null;

          });

        }

      }

      return;

    }



    // 9. In Slab tool

    if (_activeTool == ArchitectTool.slab || _activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.floorDrain) {

      final pt = _resolveSlabPoint(rawModel);



      if (_elementTool.slabDraftPoints.length >= 3 &&

          (pt - _elementTool.slabDraftPoints.first).distance <=

              math.min(16.0 / _currentScale, .20)) {

        if (_activeTool == ArchitectTool.hatch) { _commitHatch(); return; }

      if (_activeTool == ArchitectTool.floorDrain) { _commitFloorDrain(); return; }

        if (_activeTool == ArchitectTool.floorDrain) { _commitFloorDrain(); return; }

        final res = _elementTool.commitSlab(storey: _project.activeStorey);

        if (res != null) {

          setState(() {

            _project = _project.updateActiveStorey(res.$1);

          });

          _saveBiMProjectIfAttached();

          HapticFeedback.mediumImpact();

        }

      } else {

        setState(() => _elementTool.addSlabPoint(pt));

        HapticFeedback.lightImpact();

      }

      return;

    }



    // 9b. In Roof tool

    if (_activeTool == ArchitectTool.roof) {

      final pt = _resolveRoofPoint(rawModel);

      final createdList = _roofTool.addDraftPoint(

        pt,

        storey: _project.activeStorey,

        closeRadius: math.min(18.0 / _currentScale, 0.35),

      );

      if (createdList != null && createdList.isNotEmpty) {

        _commitCreatedRoofPlanes(createdList);

      } else {

        _repaintPreview();

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

            _wallArcEnd = null;

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

            _wallArcEnd = null;

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

        if ((_snapElement(rawModel, anchor: _draftStart).point - _draftStart!)

                .distance <

            .05) {

          return;

        }

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

          _wallArcEnd = null;

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

            _wallArcEnd = null;

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

        elevation: _commands.isPlan

            ? _project.activeStorey.elevation

            : -point.dy,

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

    if (_activeTool == ArchitectTool.cadRect ||

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

        final type = _activeTool == ArchitectTool.cadRect

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

          _wallArcEnd = null;

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

    final previous = activeStorey.zones

        .where((z) => z.id == updated.id)

        .firstOrNull;

    if (previous == null) return;

    if (updated.isApartment) updated = updated.copyWith(isAutoBoundary: false, clearApartmentId: true);

    if (!updated.isApartment && !previous.isAutoBoundary && updated.isAutoBoundary) {

      final detected = ArchitectRoomDetector.automaticZone(

        updated,

        activeStorey.walls,

      );

      if (detected == null) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(context.l10n.architectZoneBoundaryOpen)),

        );

        return;

      }

      updated = detected;

    } else if (previous.isAutoBoundary && updated.isAutoBoundary) {

      updated = updated.copyWith(

        polygon: previous.polygon,

        seedPoint: previous.seedPoint,

      );

    }

    final updatedZones = activeStorey.zones

        .map((z) => z.id == updated.id ? updated : z)

        .toList();

    setState(() {

      _commands.commit(

        _project.updateActiveStorey(activeStorey.copyWith(zones: updatedZones)),

      );

    });

    _saveBiMProjectIfAttached();

    if (_zoneTool.editingZone?.id == updated.id) {

      _zoneTool.startEditingZone(updated);

    }

  }







  ArchitectStorey _placedZoneSchedules(Offset origin) {

    final current = _project.activeStorey;

    final base = current.copyWith(zoneScheduleOrigin: origin, zones: [for (final z in current.zones)

      z.isApartment ? z.copyWith(clearScheduleOrigin: true) : z]);

    final tables = ArchitectZonePainterHelper.scheduleTables(project: _project,

      storey: base, l10n: context.l10n, viewKey: _workspaceViewKey, zoomScale: _currentScale);

    final origins = {for (final t in tables) t.group.id: t.origin};

    return base.copyWith(zones: [for (final z in base.zones)

      z.isApartment ? z.copyWith(scheduleOrigin: origins[z.id]) : z]);

  }



  void _showRoomScheduleDialog() {

    ArchitectZoneScheduleDialog.show(

      presets: _zonePresets,

      context: context,

      storey: _project.activeStorey,

      units: _project.units,

      initialApartmentId: _selectedZone?.isApartment == true ? _selectedZoneId : _selectedZone?.apartmentId,

      onZoneUpdated: _updateZone,

      onTableOriginChanged: (origin) {

        setState(() {

          _project = _project.updateActiveStorey(origin == null

            ? _project.activeStorey.copyWith(clearZoneScheduleOrigin: true)

            : _placedZoneSchedules(origin));

        });

        _saveBiMProjectIfAttached();

      },

    );

  }



  void _removeZoneScheduleTable() {

    setState(() {

      final updatedStorey = _project.activeStorey.copyWith(

        clearZoneScheduleOrigin: true,

      );

      _project = _project.updateActiveStorey(updatedStorey);

      _isZoneTableSelected = false;

    });

    _saveBiMProjectIfAttached();

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(context.l10n.architectZoneTableRemoved),

        duration: const Duration(seconds: 1),

      ),

    );

  }



  Future<void> _checkZoneMergeAfterWallDelete(ArchitectStorey newStorey) async {

    final candidate = ArchitectRoomDetector.detectMergedZones(

      existingZones: newStorey.zones,

      remainingWalls: newStorey.walls,

    );

    if (candidate == null || !mounted) return;



    final l10n = context.l10n;

    final shouldMerge = await showDialog<bool>(

      context: context,

      barrierDismissible: true,

      builder: (ctx) => AlertDialog(

        backgroundColor: const Color(0xFF1E2430),

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(14),

          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),

        ),

        title: Row(

          children: [

            const Icon(

              Icons.merge_type_rounded,

              color: Color(0xFF38BDF8),

              size: 24,

            ),

            const SizedBox(width: 8),

            Expanded(

              child: Text(

                l10n.architectZoneMergeDialogTitle,

                style: const TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                  fontSize: 16,

                ),

              ),

            ),

          ],

        ),

        content: Text(

          l10n.architectZoneMergeDialogMessage(

            candidate.zoneA.name,

            candidate.zoneB.name,

          ),

          style: const TextStyle(color: Colors.white70, fontSize: 13.5),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.of(ctx).pop(false),

            child: Text(

              l10n.architectZoneMergeKeepSeparate,

              style: const TextStyle(color: Colors.white60),

            ),

          ),

          ElevatedButton.icon(

            style: ElevatedButton.styleFrom(

              backgroundColor: const Color(0xFF00E5FF),

              foregroundColor: Colors.black,

            ),

            icon: const Icon(Icons.check_rounded, size: 18),

            label: Text(

              l10n.architectZoneMergeConfirm,

              style: const TextStyle(fontWeight: FontWeight.bold),

            ),

            onPressed: () => Navigator.of(ctx).pop(true),

          ),

        ],

      ),

    );



    if (shouldMerge == true && mounted) {

      final updatedZones = newStorey.zones

          .where((z) => z.id != candidate.zoneB.id)

          .map(

            (z) => z.id == candidate.zoneA.id

                ? z.copyWith(polygon: candidate.mergedPolygon)

                : z,

          )

          .toList();

      setState(() {

        _project = _project.updateActiveStorey(

          newStorey.copyWith(zones: updatedZones),

        );

        _selectedZoneId = candidate.zoneA.id;

      });

      _saveBiMProjectIfAttached();

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(l10n.architectZoneMergedSuccess(candidate.zoneA.name)),

          duration: const Duration(seconds: 2),

        ),

      );

    }

  }



  void _syncAutoZones(ArchitectStorey storey) {

    if (storey.zones.isEmpty) return;

    final autoZones = storey.zones.where((z) => z.isAutoBoundary).toList();

    if (autoZones.isEmpty) return;



    bool changed = false;

    bool openBoundary = false;

    final updatedZones = List<ArchitectZone>.from(storey.zones);



    for (int i = 0; i < updatedZones.length; i++) {

      final zone = updatedZones[i];

      if (!zone.isAutoBoundary) continue;



      final detected = ArchitectRoomDetector.automaticZone(zone, storey.walls);

      if (detected == null) {

        openBoundary = true;

        continue;

      }

      final newPoly = detected.polygon;



      if (newPoly.length >= 3) {

        if (_hasPolygonGeometryChanged(zone.polygon, newPoly)) {

          updatedZones[i] = detected;

          changed = true;

        }

      }

    }



    if (openBoundary) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(context.l10n.architectZoneBoundaryOpen)),

      );

    }



    if (changed) {

      setState(() {

        _project = _project.updateActiveStorey(

          storey.copyWith(zones: updatedZones),

        );

      });

      _saveBiMProjectIfAttached();

    }

  }



  bool _hasPolygonGeometryChanged(List<Offset> a, List<Offset> b) {

    if (a.length != b.length) return true;

    for (int i = 0; i < a.length; i++) {

      if ((a[i] - b[i]).distance > 0.01) return true;

    }

    return false;

  }



  // === SECTION: WALL & DOOR CONCEPT DRAFTING ===



  final List<String> _draftChainIds = [];

  bool _groupDraftChain = false;

  Set<String> get _liveDraftChainIds => _draftChainIds.where(_project.activeStorey.groupableIds.contains).toSet();

  bool get _draftGroupChoiceVisible => _commands.isPlan &&

      _liveDraftChainIds.length + (_wallDirectionLocked ? 1 : 0) > 1;

  void _resetDraftGroup() { _draftChainIds.clear(); _groupDraftChain = false; }

  void _finishDraftGroup() {

    final ids = _liveDraftChainIds;

    if (_commands.isPlan && _groupDraftChain && ids.length > 1) {

      _commands.execute(GroupArchitectElements(storeyId: _project.activeStoreyId,

        groupId: ArchitectElementId.next('group'), elementIds: ids));

      _saveBiMProjectIfAttached();

    }

    _resetDraftGroup();

  }

  void _placeDraftSegment(ArchitectModelCommand command, String id, bool chain) {

    final ids = {..._liveDraftChainIds, id};

    _commands.executeBatch([command,

      if (!chain && _commands.isPlan && _groupDraftChain && ids.length > 1)

        GroupArchitectElements(storeyId: _project.activeStoreyId,

          groupId: ArchitectElementId.next('group'), elementIds: ids),

    ]);

    if (chain) { _draftChainIds.add(id); } else { _resetDraftGroup(); }

  }



  void _commitViewDirection(int side) {
    final draft = _viewDirectionDraft;
    if (draft == null || (side != 1 && side != -1)) return;
    final section = draft.tool == ArchitectTool.section;
    final id = ArchitectElementId.next(section ? 'sec' : 'elv');
    final label = String.fromCharCode(65 + (_project.sections.length % 26));
    final next = section ? _project.copyWith(sections: [..._project.sections,
      ArchitectSection(id: id, name: '${context.l10n.architectToolSection} $label-$label',
        start: side == 1 ? draft.start : draft.end, end: side == 1 ? draft.end : draft.start),
    ]) : _project.copyWith(elevations: [..._project.elevations,
      ArchitectElevation(id: id, start: draft.start, end: draft.end, viewSide: side),
    ]);
    _viewDirectionDraft = null;
    _modelCommands.commit(next);
    setState(() {
      _selectedElementId = id;
      _selectionIds..clear()..add(id);
      _lastViewIds[section ? ArchitectWorkspaceView.section : ArchitectWorkspaceView.elevation] = id;
    });
    _saveBiMProjectIfAttached();
    _repaintPreview();
    HapticFeedback.lightImpact();
  }

  void _commitCurrentWallSegment(

    Offset targetPoint, {

    bool? continueChain,

    double arcBulge = 0,

  }) {

    if (_draftStart == null) return;

    if (_activeTool == ArchitectTool.cadLine) {

      final end = targetPoint;

      if ((end - _draftStart!).distance < .001) return;

      final id = ArchitectElementId.next('cad');

      final chain = continueChain ?? (_wallMode == WallDraftingMode.chained);

      _placeDraftSegment(

        PlaceArchitectCadPrimitive(

          storeyId: _project.activeStoreyId,

          primitive: ArchitectCadPrimitive(

            id: id,

            type: CadPrimitiveType.line,

            startPoint: _draftStart!,

            endPoint: end,

            colorValue: 0xFF9E9E9E,

            lineStyle: _activeCadLineStyle,

          ),

        ), id, chain,

      );

      setState(() {

        if (continueChain == true) _wallMode = WallDraftingMode.chained;

        final chain = continueChain ?? (_wallMode == WallDraftingMode.chained);

        _draftStart = chain ? end : null;

        _draftEnd = chain ? end : null;

        _wallDirectionLocked = false;

        _wallPanelAnchor = null;

        _activeSnapLabel = null;

        _activeMagneticGuides = [];

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.lightImpact();

      return;

    }

    if (_viewMarkerTool) {
      if ((targetPoint - _draftStart!).distance < .01) return;
      setState(() {
        _viewDirectionDraft = (source: _project, tool: _activeTool,
          start: _draftStart!, end: targetPoint);
        _draftStart = null;
        _draftEnd = null;
        _wallDirectionLocked = false;
        _wallPanelAnchor = null;
        _activeSnapLabel = null;
        _activeMagneticGuides = [];
        _placingWithHold = false;
        _touchPosition = null;
      });
      // Keep both screen-space choices reachable even when the cut is drawn
      // near an edge of a phone viewport. Only the camera moves.
      final centre = _viewport.toScreen((_viewDirectionDraft!.start + targetPoint) / 2);
      final size = _viewport.size;
      if (size.width > 180 && size.height > 240) {
        _viewport.panBy(Offset(centre.dx.clamp(88, size.width - 88) - centre.dx,
          centre.dy.clamp(144, size.height - 88) - centre.dy));
      }
      HapticFeedback.selectionClick();
      return;
    }

    final p1 = _draftStart!;

    final p2 = targetPoint;

    final len = (p2 - p1).distance;

    if (len < 0.001) return;



    _orientWallReference(p2);

    final now = ArchitectElementId.next('element');

    final newWall = ArchitectWall(

      id: 'wall_$now',

      arcBulge: arcBulge,

      plinth: ArchitectWallPlinth(

        baseElevation: _project.activeStorey.elevation,

      ),

      startPoint: p1,

      endPoint: p2,

      thickness: _wallThickness,

      layers: _activeWallType?.resolvedLayers ?? const [],

      location: _activeWallType?.resolvedLocation,

      loadBearing: _activeWallType?.isLoadBearing ?? false,

      height: _activeWallType?.customHeight ?? _project.activeStorey.height,

      followStoreyHeight: _activeWallType?.isParapet != true,

      wallTypeId: _activeWallType?.id,

      parapetFinish: _activeWallType?.parapetFinish,

      parapet: _activeWallType?.isParapet,

      referenceLine: _wallReference,

      exteriorSide: _wallExteriorSide,

      insulationThicknessOverride: _activeWallType?.insulationThickness,

    );



    setState(() {

      _placeDraftSegment(

        CreateArchitectWall(storeyId: _project.activeStorey.id, wall: newWall), newWall.id,

        continueChain ?? (_wallMode == WallDraftingMode.chained),

      );

      _syncAutoZones(_project.activeStorey);

      _wallDirectionLocked = false;

      if (continueChain == true) _wallMode = WallDraftingMode.chained;

      if (continueChain ?? (_wallMode == WallDraftingMode.chained)) {

        _draftStart = p2;

        _draftEnd = p2;

        _wallStartAttachment = ArchitectWallAttachment(newWall, _wallReference);

      } else {

        _draftStart = null;

        _wallArcEnd = null;

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

    _finishDraftGroup();

    setState(() {

      _wallArcEnd = null;

      _draftStart = null;

      _wallArcEnd = null;

      _draftEnd = null;

      _wallDirectionLocked = false;

      _activeSnapLabel = null;

    });

  }



  void _adoptWallReference(ArchitectWallAttachment? attachment) {

    if (_activeTool != ArchitectTool.wall || attachment == null) return;

    if (_wallReference != attachment.reference) {

      setState(() => _wallReference = attachment.reference);

    }

  }



  void _orientWallReference(Offset end) {

    if (_activeTool != ArchitectTool.wall ||

        _wallStartAttachment == null ||

        _draftStart == null) {

      return;

    }

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

    for (final wall in _linearEditWalls) {

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

        : ArchitectWallTrimSpan.at(picked, [

            ..._project.activeStorey.walls,

            ..._linearEditWalls.where(

              (w) => !_project.activeStorey.walls.any((a) => a.id == w.id),

            ),

          ], point);

  }



  // === SECTION: WALL SPLIT, SURFACE DETECTION & CLEARANCES ===

  void _startCutSession(Set<String> wallIds) {

    _cancelActiveDrags();

    setState(() {

      _splitActive = false;

      _splitWallIds.clear();

      _wallCutIds = Set.from(wallIds);

      _wallCutStroke = false;

      _wallCutStart = null;

      _wallCutConfirmedDir = null;

      _wallExtendId = null;

      _radialMenuScreenPosition = null;

      _placingWithHold = false;

      _touchPosition = null;

      _moveSelection = false;

      _wallParallelMove = false;

    });

    HapticFeedback.selectionClick();

  }



  void _cancelCutSession() {

    setState(() {

      _wallCutIds.clear();

      _wallCutStart = null;

      _wallCutConfirmedDir = null;

      _wallCutStroke = false;

    });

    _repaintPreview();

  }



  void _startSplitSession({Set<String>? wallIds}) {

    _cancelActiveDrags();

    setState(() {

      _splitActive = true;

      _splitWallIds = wallIds != null && wallIds.isNotEmpty

          ? Set.from(wallIds)

          : Set.from(

              _selectedLineIds.isNotEmpty ? _selectedLineIds : _selectedWallIds,

            );

      _splitPoint1 = null;

      _splitPoint2 = null;

      _splitPerpendicularNormal = null;

      _splitGuidePerpendicular = null;

      _splitWaitingForSide = false;

      _radialMenuScreenPosition = null;

      _placingWithHold = false;

      _touchPosition = null;

      _moveSelection = false;

      _wallParallelMove = false;

      _wallCutIds = {};

      _wallCutStart = null;

      _wallCutConfirmedDir = null;

      _wallExtendId = null;

    });

    HapticFeedback.selectionClick();

  }



  void _cancelSplitSession() {

    setState(() {

      _splitActive = false;

      _splitPoint1 = null;

      _splitPoint2 = null;

      _splitPerpendicularNormal = null;

      _splitGuidePerpendicular = null;

      _splitWaitingForSide = false;

      _splitWallIds.clear();

      _placingWithHold = false;

      _touchPosition = null;

    });

    _repaintPreview();

  }



  (Offset, Offset)? _findWallTangentAndNormalAt(

    Offset pt,

    Set<String> targetWallIds,

  ) {

    final storey = _project.activeStorey.copyWith(walls: _linearEditWalls);

    final candidateWalls = targetWallIds.isNotEmpty

        ? storey.walls.where((w) => targetWallIds.contains(w.id)).toList()

        : storey.walls;

    final wallsToSearch = candidateWalls.isNotEmpty

        ? candidateWalls

        : storey.walls;

    if (wallsToSearch.isEmpty) return null;



    ArchitectWall? bestWall;

    double bestDist = double.infinity;

    for (final wall in wallsToSearch) {

      final closest = BimLineGeometry.closest(

        pt,

        wall.startPoint,

        wall.endPoint,

      );

      final dist = (pt - closest).distance;

      if (dist < bestDist) {

        bestDist = dist;

        bestWall = wall;

      }

    }

    if (bestWall != null) {

      final delta = bestWall.endPoint - bestWall.startPoint;

      final len = delta.distance;

      if (len > 1e-4) {

        final tangent = delta / len;

        final normal = Offset(-tangent.dy, tangent.dx);

        return (tangent, normal);

      }

    }

    return null;

  }



  void _confirmPerpendicularSplitPoint() {

    if (!_splitActive || _splitPoint1 == null) return;

    final n = _splitPerpendicularNormal ?? const Offset(0, 1);

    setState(() {

      _splitPoint2 = _splitPoint1! + n * 2.0;

      _splitWaitingForSide = true;

    });

    HapticFeedback.selectionClick();

    _repaintPreview();

  }



  void _commitSplitSide(int targetSign) {

    if (!_splitActive || _splitPoint1 == null) return;

    final p1 = _splitPoint1!;

    final p2 =

        _splitPoint2 ??

        (_splitPerpendicularNormal != null

            ? p1 + _splitPerpendicularNormal! * 2.0

            : p1 + const Offset(0, 1));

    final targetIds = _splitWallIds.isNotEmpty

        ? Set<String>.from(_splitWallIds)

        : _project.activeStorey.walls.map((w) => w.id).toSet();



    final beforeProject = _project;

    try {

      final command = _linearCommand(

        CutArchitectWalls(

          storeyId: _project.activeStoreyId,

          wallIds: targetIds,

          start: p1,

          end: p2,

        ),

      );

      _commands.execute(command);

      _saveBiMProjectIfAttached();



      final selectedIds = CutArchitectWalls.resolveSelectedWallIds(

        before: _selectedLineIds.isNotEmpty

            ? ArchitectLineEditing.geometry(

                beforeProject,

                _project.activeStoreyId,

              )

            : beforeProject,

        after: _selectedLineIds.isNotEmpty

            ? ArchitectLineEditing.geometry(_project, _project.activeStoreyId)

            : _project,

        storeyId: _project.activeStoreyId,

        cutWallIds: targetIds,

        start: p1,

        end: p2,

        targetSide: targetSign,

      );



      _selectionIds

        ..clear()

        ..addAll(selectedIds);

      _selectedElementId = selectedIds.firstOrNull;

      HapticFeedback.mediumImpact();

    } on ArgumentError {

      _operationError();

    } finally {

      setState(() {

        _splitActive = false;

        _splitPoint1 = null;

        _splitPoint2 = null;

        _splitPerpendicularNormal = null;

        _splitGuidePerpendicular = null;

        _splitWaitingForSide = false;

        _splitWallIds.clear();

        _placingWithHold = false;

        _touchPosition = null;

      });

      _repaintPreview();

    }

  }



  void _commitSplitWithPickSide(Offset pickPoint) {

    if (_splitPoint1 == null || _splitPoint2 == null) return;

    final v = _splitPoint2! - _splitPoint1!;

    final cross =

        v.dx * (pickPoint.dy - _splitPoint1!.dy) -

        v.dy * (pickPoint.dx - _splitPoint1!.dx);

    final sign = cross == 0 ? 0 : (cross > 0 ? 1 : -1);

    _commitSplitSide(sign);

  }



  void _handleSplitTap(Offset rawModel) {

    if (!_splitActive) return;



    if (_splitWaitingForSide) {

      _commitSplitWithPickSide(rawModel);

      return;

    }



    if (_splitPoint1 == null) {

      // Step 1: Pick Point 1 with CAD snap

      final snap = _snapElement(rawModel);

      final pt = snap.point;

      final tangentAndNormal = _findWallTangentAndNormalAt(pt, _splitWallIds);

      final normal = tangentAndNormal?.$2 ?? const Offset(0, 1);

      final span =

          math.max(_viewport.visibleRect.width, _viewport.visibleRect.height) *

          2.0;

      final clampedSpan = span.clamp(20.0, 500.0);



      setState(() {

        _splitPoint1 = pt;

        _splitPerpendicularNormal = normal;

        _splitGuidePerpendicular = (

          pt - normal * clampedSpan,

          pt + normal * clampedSpan,

        );

        _splitPoint2 = null;

        _splitWaitingForSide = false;

      });

      HapticFeedback.selectionClick();

      _repaintPreview();

      return;

    }



    // Step 2: Pick Point 2

    final snap = _snapElement(rawModel, anchor: _splitPoint1);

    final pt = snap.point;

    if ((pt - _splitPoint1!).distance > 0.02) {

      setState(() {

        _splitPoint2 = pt;

        _splitWaitingForSide = true;

      });

      HapticFeedback.selectionClick();

      _repaintPreview();

    }

  }



  Widget _buildCutPromptBanner() {

    return Material(

      key: const ValueKey('architect-cut-banner'),

      color: const Color(0xE61E1E26),

      borderRadius: BorderRadius.circular(8),

      elevation: 4,

      shadowColor: Colors.black54,

      child: Container(

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFFFF9100), width: 1.0),

        ),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

        child: SingleChildScrollView(

          scrollDirection: Axis.horizontal,

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Icon(Icons.content_cut, color: Color(0xFFFF9100), size: 18),

              const SizedBox(width: 8),

              Text(

                context.l10n.architectWallCutHint,

                style: const TextStyle(color: Colors.white, fontSize: 12),

              ),

              const SizedBox(width: 8),

              GestureDetector(

                key: const ValueKey('architect-cut-cancel'),

                onTap: _cancelCutSession,

                child: const Icon(Icons.close, color: Colors.white70, size: 18),

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildSplitPromptBanner() {

    final l = context.l10n;

    final isPoint1Set = _splitPoint1 != null;

    final isWaitingSide = _splitWaitingForSide;



    return Material(

      key: const ValueKey('architect-split-banner'),

      color: const Color(0xE61E1E26),

      borderRadius: BorderRadius.circular(8),

      elevation: 4,

      shadowColor: Colors.black54,

      child: Container(

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFFFF9100), width: 1.0),

        ),

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

        child: SingleChildScrollView(

          scrollDirection: Axis.horizontal,

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Icon(Icons.content_cut, size: 18, color: Color(0xFFFF9100)),

              const SizedBox(width: 8),

              Text(

                !isPoint1Set

                    ? l.architectWallSplitPromptPickFirst

                    : (!isWaitingSide

                          ? l.architectWallSplitPromptPickSecond

                          : l.architectWallSplitPromptPickSide),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(color: Colors.white, fontSize: 12),

              ),

              if (isPoint1Set && !isWaitingSide) ...[

                const SizedBox(width: 6),

                TextButton(

                  key: const ValueKey('architect-split-perpendicular-btn'),

                  style: TextButton.styleFrom(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 6,

                      vertical: 2,

                    ),

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  ),

                  onPressed: _confirmPerpendicularSplitPoint,

                  child: Text(

                    l.architectWallSplitPerpendicular,

                    style: const TextStyle(

                      color: Color(0xFF00E5FF),

                      fontSize: 11,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ),

              ],

              if (isWaitingSide) ...[

                const SizedBox(width: 6),

                TextButton(

                  key: const ValueKey('architect-split-side1-btn'),

                  style: TextButton.styleFrom(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 6,

                      vertical: 2,

                    ),

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  ),

                  onPressed: () => _commitSplitSide(-1),

                  child: Text(

                    l.architectWallSplitSide1,

                    style: const TextStyle(

                      color: Color(0xFFFFB300),

                      fontSize: 11,

                    ),

                  ),

                ),

                const SizedBox(width: 4),

                TextButton(

                  key: const ValueKey('architect-split-side2-btn'),

                  style: TextButton.styleFrom(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 6,

                      vertical: 2,

                    ),

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  ),

                  onPressed: () => _commitSplitSide(1),

                  child: Text(

                    l.architectWallSplitSide2,

                    style: const TextStyle(

                      color: Color(0xFFFFB300),

                      fontSize: 11,

                    ),

                  ),

                ),

                const SizedBox(width: 4),

                TextButton(

                  key: const ValueKey('architect-split-both-btn'),

                  style: TextButton.styleFrom(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 6,

                      vertical: 2,

                    ),

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  ),

                  onPressed: () => _commitSplitSide(0),

                  child: Text(

                    l.architectWallSplitBoth,

                    style: const TextStyle(color: Colors.white70, fontSize: 11),

                  ),

                ),

              ],

              const SizedBox(width: 6),

              IconButton(

                key: const ValueKey('architect-split-cancel-btn'),

                constraints: const BoxConstraints.tightFor(

                  width: 24,

                  height: 24,

                ),

                padding: EdgeInsets.zero,

                icon: const Icon(

                  Icons.close,

                  size: 16,

                  color: Colors.redAccent,

                ),

                tooltip: l.cancel,

                onPressed: _cancelSplitSession,

              ),

            ],

          ),

        ),

      ),

    );

  }



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

      animation: Listenable.merge([_viewport, _previewRevision, UiSettingsService.contextMenu]),

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

              mode: UiSettingsService.contextMenu.value.mode,

              hasTitle: _effectiveSelection.length > 1,

              elementBounds: _radialElementBounds,

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

            size: ArchitectClearanceBadgeLayout.openingSize(

              _currentScale, available,

            ),

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

                      ignoring: _radialMenuScreenPosition != null || _multiSelect,

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

                                    ? _project.formatLength(gap.distance)

                                    : context.l10n.architectWallEndpointValue(

                                        gap.atStart! ? 1 : 2,

                                        _project.formatLength(gap.distance),

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

              Positioned.fromRect(

                rect: placements[gap.key]!,

                child: IgnorePointer(

                  ignoring: _radialMenuScreenPosition != null || _multiSelect,

                  child: Tooltip(

                    message: context.l10n.architectOpeningClearance,

                    child: FittedBox(

                      key: ValueKey('opening-clearance-${gap.key}'),

                      child: SizedBox(

                        width: ArchitectClearanceBadgeLayout.openingBaseSize.width,

                        height: ArchitectClearanceBadgeLayout.openingBaseSize.height,

                        child: Material(

                          color: Colors.white,

                          shape: RoundedRectangleBorder(

                            borderRadius: BorderRadius.circular(3),

                            side: const BorderSide(color: Color(0xFF78818A), width: .7),

                          ),

                          child: InkWell(

                            onTap: () {

                              setState(() => _radialMenuScreenPosition = null);

                              _editOpeningClearance(gap);

                            },

                            child: Center(

                              child: Text(

                                _project.formatLength(gap.distance),

                                style: TextStyle(

                                  color: const Color(0xFF20252A),

                                  fontSize: 11,

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

                  ),

                ),

              ),

          ],

        );

      },

    ),

  );



  String? get _activePolygonDistanceElementId =>

      _polygonEditId ?? _selectedRoof?.id;



  List<Offset>? get _editablePolygon {

    final targetId = _activePolygonDistanceElementId;

    if (targetId == null ||

        targetId != (_selectedElementId ?? _selectedZoneId)) {

      return null;

    }

    final storey = (_elementMovePreview ?? _project).activeStorey;
    final holeIndex = _selectedPolygonHoleIndex;
    final host = CutArchitectContourOpening.target(storey, targetId);
    if (holeIndex != null && host != null && holeIndex < host.$2.length) {
      return host.$2[holeIndex];
    }

    for (final slab in storey.slabs) {

      if (slab.id == targetId) return slab.polygon;

    }

    for (final roof in storey.roofs) {

      if (roof.id == targetId) return roof.points;

    }

    for (final primitive in storey.cadPrimitives) {

      if (primitive.id == targetId && primitive.isPolygon) {

        return primitive.polygonCorners;

      }

    }

    for (final zone in storey.zones) {

      if (zone.id == targetId) return zone.polygon;

    }

    return null;

  }



  void _selectPolygonEdge(Offset point) {

    if (_polygonDistanceOpen) return;
    _selectPolygonContour(point);

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

        final targetId = _activePolygonDistanceElementId;

        if (polygon == null ||

            targetId == null ||

            _radialMenuScreenPosition != null) {

          return const SizedBox.shrink();

        }

        final edge = _polygonSelectedEdge;

        final selected = edge != null && edge < polygon.length;

        final effectiveProject = _elementMovePreview ?? _project;

        return Stack(

          children: [

            if (selected && !_polygonEditor.active)

              Positioned.fill(

                child: ArchitectPolygonDistanceOverlay(

                  polygon: polygon,

                  edge: edge,

                  dimensions: ArchitectPolygonDimensions.nearest(

                    elementId: targetId,

                    polygon: polygon,

                    edge: edge,

                    storey: effectiveProject.activeStorey,

                    project: effectiveProject,

                  ),

                  unit: _project.units,

                  scale: _currentScale,

                  toScreen: _viewport.toScreen,

                  obstacles: ArchitectWallNetwork.body(

                    effectiveProject.activeStorey.walls,

                  ),

                  onEdit: (dimension) => _editPolygonDistance(dimension),

                ),

              ),

            if (_polygonEditId != null)

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

                          onPressed:

                              _polygonDistanceOpen || _polygonEditor.active

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

    final id = _activePolygonDistanceElementId;
    final holeIndex = _selectedPolygonHoleIndex;

    if (polygon == null || edge == null || id == null) return;

    final original = List<Offset>.of(polygon);

    final isDirectContour = _polygonEditId == null && _selectedRoof?.id == id;

    final mode = isDirectContour

        ? ArchitectPolygonEdgeMode.extendCatheti

        : _polygonEdgeMode;

    final project = _project;

    final unit = project.units;

    List<Offset>? candidate = original;

    var displacement = 0.0;

    var enteredMeters = dimension?.distance ?? 0.0;

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

                decimals: _project.distanceDecimals,

                minimum: dimension == null

                    ? -double.infinity

                    : unit.toUnit(.001),

                signed: dimension == null,

                canSave: candidate != null && identical(project, _project),

                onChanged: (_, value) {

                  final meters = unit.fromUnit(value);

                  enteredMeters = meters;

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

                  if (candidate != null) {
                    try {
                      _elementMovePreview = UpdateArchitectPolygon(

                      storeyId: project.activeStoreyId,

                      elementId: id,

                      polygon: candidate!,
                      holeIndex: holeIndex,

                    ).apply(project);
                    } on ArgumentError {
                      candidate = null;
                      _elementMovePreview = null;
                    }
                  }

                  dialogSetState(() {});
                  if (candidate != null) {

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

                    final roof = _selectedRoof;

                    if (roof != null &&
                        holeIndex == null &&

                        roof.id == id &&

                        dimension != null &&

                        dimension.side == -1 &&

                        edge == roof.safeEavesEdgeIndex) {

                      _roofTool.setEavesOverhang(enteredMeters);

                      _commands.execute(

                        UpdateArchitectRoofPlane(

                          storeyId: project.activeStoreyId,

                          roof: roof.copyWith(

                            points: candidate!,

                            eavesOverhang: enteredMeters,

                          ),

                        ),

                      );

                    } else {

                      _commands.execute(

                        UpdateArchitectPolygon(

                          storeyId: project.activeStoreyId,

                          elementId: id,

                          polygon: candidate!,
                          holeIndex: holeIndex,

                        ),

                      );

                    }

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

            decimals: _project.distanceDecimals,

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

            decimals: _project.distanceDecimals,

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

      _commands.execute(_linearCommand(command));

      _saveBiMProjectIfAttached();

      _syncAutoZones(_project.activeStorey);

    } on ArgumentError {

      if (command is InsertArchitectElementPoint) {

        _operationError();

        return;

      }

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            _selectedLineIds.isNotEmpty || _activeTool == ArchitectTool.cadLine

                ? context.l10n.architectLineEditRejected

                : context.l10n.architectWallEditRejected,

          ),

        ),

      );

    }

  }



  void _editWallLength() {

    final wall = _selectedLinearElement;

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

            decimals: _project.distanceDecimals,

            minimumLength: _project.units.toUnit(.001),

            onLength: (value) => length = _project.units.fromUnit(value),

            onEnd: () {

              Navigator.of(dialogContext).pop();

              _executeWallEdit(

                _linearCommand(

                  UpdateArchitectWall(

                    storeyId: _project.activeStorey.id,

                    wall: wall.copyWith(

                      endPoint: wall.startPoint + wall.unitVector * length,

                    ),

                    carryConnections: false,

                  ),

                ),

              );

            },

            onContinue: () {

              Navigator.of(dialogContext).pop();

              _executeWallEdit(

                _linearCommand(

                  UpdateArchitectWall(

                    storeyId: _project.activeStorey.id,

                    wall: wall.copyWith(

                      endPoint: wall.startPoint + wall.unitVector * length,

                    ),

                    carryConnections: false,

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



  // === SECTION: FENESTRATION (DOORS, WINDOWS) & RADIAL ACTIONS ===



  void _tryPlaceDoorAt(Offset point) {

    if (_isOpeningPlacementCoolingDown) return;

    final activeStorey = _project.activeStorey;

    final placement = ArchitectOpeningPlacement.resolve(

      walls: activeStorey.walls,

      rawPoint: point,

      openingWidth: _doorWidth,

      magnetic: _magnetEnabled,

      defaultHingeLeft: _isHingeLeft,

    );

    if (placement == null) return;



    final targetWall = placement.wall;

    final ratio = placement.offsetRatio;

    final candidateAlong = ratio * targetWall.length;

    final (rawRatio, _) = targetWall.projectPoint(point);

    final rawAlong = rawRatio.clamp(0.0, 1.0) * targetWall.length;



    if (ArchitectOpeningPlacement.isPlacementBlockedOrOverlapping(

      wall: targetWall,

      candidateAlong: candidateAlong,

      rawAlong: rawAlong,

      openingWidth: _doorWidth,

    )) {

      return;

    }



    final now = ArchitectElementId.next('element');



    final activeStyle =

        _elementTool.activeDoorStyle ??

        FenestrationLibraryService.instance.activeDoorStyle;



    final specId = ArchitectDoor.resolveSpecId(

      existingDoors: _project.allDoors,

      width: _doorWidth,

      height: _doorHeight,

      sillHeight: _doorSill,

      isHingeLeft: placement.isHingeLeft,

    );



    final newDoor = ArchitectDoor(

      id: 'door_$now',

      wallId: targetWall.id,

      offsetRatio: ratio,

      width: _doorWidth,

      height: _doorHeight,

      sillHeight: _doorSill,

      isHingeLeft: placement.isHingeLeft,

      openInward: placement.openInward,

      specId: specId,

      uuid: 'UUID_$now',

      styleId: activeStyle.id,

      style: activeStyle,

    );



    final updatedWall = targetWall.addDoor(newDoor);

    final updatedWalls = activeStorey.walls

        .map((w) => w.id == updatedWall.id ? updatedWall : w)

        .toList();



    _startOpeningCooldown();

    setState(() {

      _cursorModel = null;

      _selectionIds.clear();

      _selectedElementId = null;

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



  String? _hitSection(Offset point) {
    final tol = 16.0 / _currentScale;
    for (final s in _project.sections.reversed) {
      if ((point - BimLineGeometry.closest(point, s.start, s.end)).distance <= tol) {
        return s.id;
      }
      final norm = s.viewDirection * (18.0 / _currentScale);
      if ((point - (s.start + norm)).distance <= tol ||
          (point - (s.end + norm)).distance <= tol) {
        return s.id;
      }
    }
    return null;
  }

  String? _hitElevation(Offset point) {
    final tol = 16.0 / _currentScale;
    for (final e in _project.elevations.reversed) {
      if ((point - BimLineGeometry.closest(point, e.start, e.end)).distance <= tol) {
        return e.id;
      }
      final mid = e.centre;
      final dir = e.viewDirection;
      final norm = (dir.distance > 0 ? dir / dir.distance : const Offset(0, 1)) * (24.0 / _currentScale);
      final tip = mid + norm;
      if ((point - tip).distance <= tol ||
          (point - BimLineGeometry.closest(point, mid, tip)).distance <= tol) {
        return e.id;
      }
    }
    return null;
  }

  String? _hitSelection(Offset point) {
    if (_activeTool == ArchitectTool.section) return _hitSection(point);
    if (_activeTool == ArchitectTool.elevation) return _hitElevation(point);

    if (_acceptsAnySelection || _activeTool == ArchitectTool.component) {
      final secHit = _hitSection(point);
      if (secHit != null) return secHit;
      final elvHit = _hitElevation(point);
      if (elvHit != null) return elvHit;

      if (_showFurnitureLayer) {

        for (final component in _project.activeStorey.components.reversed) {

          if (component.isVisible && component.containsPoint(point)) return component.id;

        }

      }

      if (_activeTool == ArchitectTool.component && !_acceptsAnySelection) return null;

      return _elementTool.hitTestElement(

            _project.activeStorey,

            point,

            _currentScale,

            gridAxes: _project.gridAxes,

            annotationProject: _project,

            drawingViewKey: _workspaceViewKey,

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

      gridAxes: _project.gridAxes,

      annotationProject: _project,

      drawingViewKey: _workspaceViewKey,

    );

  }



  bool _onSelectionHold(Offset screenPoint) {

    if (_wallCutIds.isNotEmpty ||

        _polygonEditId != null ||

        _wallJoinSourceId != null ||

        _wallExtendId != null) {

      return false;

    }

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

    final raw = _screenToModel(screenPoint);

    if (_selectionCandidates(raw).any(_effectiveSelection.contains)) {

      return true;

    }

    if (_selectAt(raw, invalidateGesture: false)) {

      return true;

    }

    if (_commands.view == ArchitectWorkspaceView.section &&

        (_activeTool == ArchitectTool.select ||

            _activeTool == ArchitectTool.roof)) {

      _cacheProjection();

      final hitRoof = _sectionGeometry?.pickRoof(

        _modelToSection(raw),

        16 / _currentScale,

      );

      if (hitRoof != null) {

        setState(() {

          _selectionIds.clear();

          _selectedElementId = null;

          _selectedZoneId = null;

          _selectedSectionRoofId = hitRoof;

          if (!_multiSelect && _acceptsAnySelection) {

            _activeTool = ArchitectTool.roof;

            _selectionContextActive = true;

          }

        });

        return true;

      }

    }

    return false;

  }



  bool _onContextHold(Offset screenPoint) {

    if (!_selectionContextActive &&

        (_activeTool == ArchitectTool.door ||

            _activeTool == ArchitectTool.window)) {

      return false;

    }

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

    final raw = _screenToModel(screenPoint);

    final candidates = _selectionCandidates(raw);

    final ok =

        candidates.any(_effectiveSelection.contains) ||

        _selectAt(raw, invalidateGesture: false);

    if (ok) {

      final id =

          _selectedElementId ??

          _selectedZoneId ??

          _effectiveSelection.firstOrNull;

      if (id != null) {

        setState(() {

          _radialMenuScreenPosition = screenPoint;

          _radialMenuElementId = id;

          _radialMenuItems = _buildRadialMenuItems(id);

        });

      }

      return true;

    }

    if (_commands.view == ArchitectWorkspaceView.section &&

        (_activeTool == ArchitectTool.select ||

            _activeTool == ArchitectTool.roof)) {

      _cacheProjection();

      final hitRoof =

          _sectionGeometry?.pickRoof(

            _modelToSection(raw),

            16 / _currentScale,

          ) ??

          _selectedSectionRoofId;

      if (hitRoof != null) {

        setState(() {

          _selectionIds.clear();

          _selectedElementId = null;

          _selectedZoneId = null;

          _selectedSectionRoofId = hitRoof;

          if (!_multiSelect && _acceptsAnySelection) {

            _activeTool = ArchitectTool.roof;

            _selectionContextActive = true;

          }

        });

        unawaited(_showSectionRoofContextMenu(screenPoint, hitRoof));

        return true;

      }

    }

    return false;

  }



  Future<void> _showSectionRoofContextMenu(

    Offset localPoint,

    String roofId,

  ) async {

    final l = context.l10n;

    final box = context.findRenderObject() as RenderBox?;

    final globalPos = box?.localToGlobal(localPoint) ?? localPoint;

    final action = await showMenu<String>(

      context: context,

      position: RelativeRect.fromLTRB(

        globalPos.dx,

        globalPos.dy,

        globalPos.dx,

        globalPos.dy,

      ),

      items: [

        PopupMenuItem(

          value: 'move_vertical',

          child: Row(

            children: [

              const Icon(Icons.swap_vert, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofMoveVerticalAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'snap_walls',

          child: Row(

            children: [

              const Icon(Icons.vertical_align_bottom, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofSnapToWallsAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'properties',

          child: Row(

            children: [

              const Icon(Icons.layers_outlined, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofPropertiesAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'flip_slope',

          child: Row(

            children: [

              const Icon(Icons.swap_horiz, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofFlipSlope),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'delete',

          child: Row(

            children: [

              const Icon(Icons.delete_outline, size: 18),

              const SizedBox(width: 8),

              Text(l.delete),

            ],

          ),

        ),

      ],

    );

    if (!mounted || action == null) return;

    final hit = ArchitectBuildingSection.findRoofById(

      _modelCommands.project,

      roofId,

    );

    if (hit == null) return;

    switch (action) {

      case 'move_vertical':

        setState(() => _selectedSectionRoofId = roofId);

      case 'snap_walls':

        final lower = ArchitectRoofGeometry.supportingWallStorey(

          _modelCommands.project,

          hit.storey,

        );

        final resolvedOffset =

            ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(

              roof: hit.roof,

              storey: hit.storey,

              lowerStorey: lower,

            );

        _modelCommands.execute(

          UpdateArchitectRoofPlane(

            storeyId: hit.storey.id,

            roof: hit.roof.copyWith(

              attachToWalls: true,

              baseElevationOffset: resolvedOffset,

            ),

          ),

        );

        _saveBiMProjectIfAttached();

      case 'properties':

        await _openRoofLayersDialog(roof: hit.roof);

      case 'flip_slope':

        _modelCommands.execute(

          UpdateArchitectRoofPlane(

            storeyId: hit.storey.id,

            roof: hit.roof.flippedSlope(),

          ),

        );

        _saveBiMProjectIfAttached();

      case 'delete':

        _modelCommands.execute(

          DeleteArchitectRoofPlane(

            storeyId: hit.storey.id,

            roofId: hit.roof.id,

          ),

        );

        setState(() {

          if (_selectedSectionRoofId == roofId) {

            _selectedSectionRoofId = null;

          }

        });

        _saveBiMProjectIfAttached();

    }

  }



  ArchitectRadialMenuItem _radialItem({

    required BimEditAction action,

    required Color color,

  }) => ArchitectRadialMenuItem(

    action: action,

    icon: BimEditActions.icon(action),

    label: BimEditActions.label(action, context.l10n),

    color: color,

    tooltip: action == BimEditAction.offset &&

        ArchitectOffset.supports(_project.activeStorey, _effectiveSelection)

        ? context.l10n.bimOffsetHelp

        : action == BimEditAction.rename

        ? context.l10n.renameGridAxis

        : action == BimEditAction.newPoint

        ? (_selectedWall != null

              ? context.l10n.bimWallNewPointHelp

              : context.l10n.bimNewPointHint)

        : null,

  );



  bool get _selectionHasAutoZones => _project.activeStorey.zones.any(

    (zone) => zone.isAutoBoundary && _effectiveSelection.contains(zone.id),

  );



  List<ArchitectRadialMenuItem> _buildRadialMenuItems(String elementId) {

    final items = _buildElementRadialMenuItems(elementId);

    if (_commands.isPlan && ArchitectRotation.supports(_project.activeStorey, _effectiveSelection) &&
        !items.any((item) => item.action == ArchitectRadialAction.rotate)) {
      items.add(_radialItem(action: ArchitectRadialAction.rotate, color: const Color(0xFF40C4FF)));
    }

    if (!_is3DView && ArchitectOffset.supports(_project.activeStorey, _effectiveSelection)) {

      items.add(_radialItem(action: ArchitectRadialAction.offset, color: const Color(0xFF80CBC4)));

    }

    if (_commands.isPlan && _editingGroupId == null) {

      final group = _selectedGroup;

      if (group != null) {

        items.addAll([

          _radialItem(action: ArchitectRadialAction.ungroup, color: const Color(0xFF80CBC4)),

          _radialItem(action: ArchitectRadialAction.editGroup, color: const Color(0xFF80CBC4)),

        ]);

      } else if (_effectiveSelection.length > 1 &&

          _project.activeStorey.groupableIds.containsAll(_effectiveSelection) &&

          !_project.activeStorey.groups.any((g) => g.elementIds.any(_effectiveSelection.contains))) {

        items.add(_radialItem(action: ArchitectRadialAction.group, color: const Color(0xFF80CBC4)));

      }

    }

    return items;

  }



  List<ArchitectRadialMenuItem> _buildElementRadialMenuItems(String elementId) {

    final items = <ArchitectRadialMenuItem>[];



    if (_effectiveSelection.length > 1) {

      if (_selectionHasAutoZones) {

        return [

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

      final sel = _effectiveSelection;

      final storey = _project.activeStorey;

      final wallCount = storey.walls.where((w) => sel.contains(w.id)).length;

      final colCount = storey.columns.where((c) => sel.contains(c.id)).length;

      final beamCount = storey.beams.where((b) => sel.contains(b.id)).length;

      final total = sel.length;



      final isAllWalls = wallCount == total || _selectedLineIds.length == total;

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

          if (wallCount == total) _radialItem(

            action: ArchitectRadialAction.flip,

            color: const Color(0xFF40C4FF),

          ),

          _radialItem(

            action: ArchitectRadialAction.properties,

            color: const Color(0xFFB388FF),

          ),

          _radialItem(

            action: ArchitectRadialAction.mirrorMove,

            color: const Color(0xFF00E5FF),

          ),

          _radialItem(

            action: ArchitectRadialAction.mirrorCopy,

            color: const Color(0xFF64FFDA),

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

            action: ArchitectRadialAction.mirrorMove,

            color: const Color(0xFF00E5FF),

          ),

          _radialItem(

            action: ArchitectRadialAction.mirrorCopy,

            color: const Color(0xFF64FFDA),

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

          action: ArchitectRadialAction.mirrorMove,

          color: const Color(0xFF00E5FF),

        ),

        _radialItem(

          action: ArchitectRadialAction.mirrorCopy,

          color: const Color(0xFF64FFDA),

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



    final isSection = _project.sections.any((s) => s.id == elementId);
    final isElevation = _project.elevations.any((e) => e.id == elementId);
    if (isSection || isElevation) {
      items.add(
        _radialItem(
          action: ArchitectRadialAction.openView,
          color: const Color(0xFF00E5FF),
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
      items.add(
        _radialItem(
          action: ArchitectRadialAction.delete,
          color: const Color(0xFFFF5252),
        ),
      );
      return items;
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

    final isLine = storey.cadPrimitives.any(

      (c) => c.id == elementId && c.type == CadPrimitiveType.line,

    );

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

    } else if (isWall || isLine) {

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

          action: ArchitectRadialAction.cut,



          color: const Color(0xFFFF7043),

        ),

      );

      items.add(

        _radialItem(

          action: ArchitectRadialAction.split,



          color: const Color(0xFFFF9100),

        ),

      );

      if (isWall) {

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

    } else if (isDoor || isWindow) {

      items.add(

        _radialItem(

          action: ArchitectRadialAction.move,



          color: const Color(0xFFFFB300),

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

    } else if (isZone) {

      items.add(

        _radialItem(

          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),

        ),

      );

      items.add(

        _radialItem(

          action: ArchitectRadialAction.edit,

          color: const Color(0xFF00E5FF),

        ),

      );

      items.add(

        _radialItem(

          action: ArchitectRadialAction.schedule,

          color: const Color(0xFF38BDF8),

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

    } else if (isSlab || isRoof || isCadPrim) {

      items.add(

        _radialItem(

          action: ArchitectRadialAction.edit,



          color: const Color(0xFF00E5FF),

        ),

      );

      if (isRoof) {

        items.add(

          _radialItem(

            action: ArchitectRadialAction.rotate,

            color: const Color(0xFF40C4FF),

          ),

        );

        items.add(

          _radialItem(

            action: ArchitectRadialAction.flip,

            color: const Color(0xFF80D8FF),

          ),

        );

      }

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



    if (_effectiveSelection.length <= 1 &&

        CutArchitectContourOpening.target(storey, elementId) != null &&

        _commands.view == ArchitectWorkspaceView.plan) {

      items.add(_radialItem(action: ArchitectRadialAction.cutOpening,

        color: const Color(0xFF80CBC4)));

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



    if (!isDoor && !isWindow && !isAxis) {

      items.add(

        _radialItem(

          action: ArchitectRadialAction.mirrorMove,

          color: const Color(0xFF00E5FF),

        ),

      );

      items.add(

        _radialItem(

          action: ArchitectRadialAction.mirrorCopy,

          color: const Color(0xFF64FFDA),

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



  void _startNewPointSession(String id, {Offset? initialPick}) {

    if (initialPick != null) _selectPolygonContour(initialPick);
    final holeIndex = _selectedPolygonHoleIndex;
    final path = InsertArchitectElementPoint.pathOf(_project.activeStorey, id,
        holeIndex: holeIndex);

    if (path == null || path.points.length < 2) return;

    _cancelActiveDrags();

    setState(() {

      _newPointTargetId = id;
      _newPointHoleIndex = holeIndex;

      _newPointCandidate = null;

      _newPointLeaderLine = null;

      _radialMenuScreenPosition = null;

      _activeSnapLabel = null;

    });

    if (initialPick != null) {

      _updateNewPointCandidate(initialPick, isTouch: false);

    }

  }



  void _cancelNewPointSession() {

    setState(() {

      _newPointTargetId = null;
      _newPointHoleIndex = null;

      _newPointCandidate = null;

      _newPointLeaderLine = null;

      _activeSnapLabel = null;

      _activeMagneticGuides = [];

    });

    _repaintPreview();

  }



  void _updateNewPointCandidate(Offset rawModel, {required bool isTouch}) {

    if (_newPointTargetId == null) return;

    final path = InsertArchitectElementPoint.pathOf(

      _project.activeStorey,

      _newPointTargetId!,
      holeIndex: _newPointHoleIndex,

    );

    if (path == null || path.points.length < 2) return;



    final hit = BimLineGeometry.insertion(

      path.points,

      rawModel,

      closed: path.closed,

    );

    if (hit == null) return;



    Offset candidate = hit.point;

    String? snapLabel;

    List<(Offset, Offset)> guides = [];



    final edgeP1 = path.points[hit.edge];

    final edgeP2 = path.points[(hit.edge + 1) % path.points.length];

    final snapTol = 24.0 / _currentScale;



    var bestDist = snapTol;

    final storeyWalls = _project.activeStorey.walls;



    // 1. Snapping to outer corners where wall insulation / core lines connect

    for (var i = 0; i < storeyWalls.length; i++) {

      final a = storeyWalls[i];

      if (a.length < 1e-4) continue;



      // Include wall individual corner vertices (insulation & core)

      for (final p in [...a.polygonCorners, ...a.coreCorners]) {

        final targetPoint = path.closed

            ? p

            : BimLineGeometry.closest(p, edgeP1, edgeP2);

        final dist = (targetPoint - hit.point).distance;

        if (dist <= bestDist) {

          bestDist = dist;

          candidate = targetPoint;

          snapLabel = 'Corner';

          guides = [

            if (!path.closed && (p - targetPoint).distance > 1e-4)

              (p, targetPoint),

          ];

        }

      }



      for (final b in storeyWalls.skip(i + 1)) {

        if (b.length < 1e-4) continue;

        final cross = BimLineGeometry.cross(a.unitVector, b.unitVector);

        if (cross.abs() < 1e-4) continue;



        // Outer face intersections (insulation corner junctions)

        final facesA = [

          (a.polygonCorners[0], a.polygonCorners[1]),

          (a.polygonCorners[3], a.polygonCorners[2]),

        ];

        final facesB = [

          (b.polygonCorners[0], b.polygonCorners[1]),

          (b.polygonCorners[3], b.polygonCorners[2]),

        ];

        for (final fa in facesA) {

          for (final fb in facesB) {

            final pt = BimLineGeometry.intersection(fa.$1, fa.$2, fb.$1, fb.$2);

            if (pt != null) {

              final targetPoint = path.closed

                  ? pt

                  : BimLineGeometry.closest(pt, edgeP1, edgeP2);

              final dist = (targetPoint - hit.point).distance;

              if (dist <= bestDist) {

                bestDist = dist;

                candidate = targetPoint;

                snapLabel = 'Corner';

                guides = [fa, fb];

              }

            }

          }

        }



        // Core face intersections (core corner junctions)

        final coreA = [

          (a.coreCorners[0], a.coreCorners[1]),

          (a.coreCorners[3], a.coreCorners[2]),

        ];

        final coreB = [

          (b.coreCorners[0], b.coreCorners[1]),

          (b.coreCorners[3], b.coreCorners[2]),

        ];

        for (final ca in coreA) {

          for (final cb in coreB) {

            final pt = BimLineGeometry.intersection(ca.$1, ca.$2, cb.$1, cb.$2);

            if (pt != null) {

              final targetPoint = path.closed

                  ? pt

                  : BimLineGeometry.closest(pt, edgeP1, edgeP2);

              final dist = (targetPoint - hit.point).distance;

              if (dist <= bestDist) {

                bestDist = dist;

                candidate = targetPoint;

                snapLabel = 'Core';

                guides = [ca, cb];

              }

            }

          }

        }

      }

    }



    // 2. Intersections of other walls with edgeP1..edgeP2

    for (final other in storeyWalls) {

      if (other.id == _newPointTargetId) continue;



      // 2a. Insulation lines

      final insLines = <(Offset, Offset)>[

        if (other.polygonCorners.length >= 4) ...[

          (other.polygonCorners[0], other.polygonCorners[1]),

          (other.polygonCorners[3], other.polygonCorners[2]),

          (other.polygonCorners[0], other.polygonCorners[3]),

          (other.polygonCorners[1], other.polygonCorners[2]),

        ],

      ];

      for (final (w1, w2) in insLines) {

        final inter = BimLineGeometry.intersection(

          edgeP1,

          edgeP2,

          w1,

          w2,

          firstFinite: true,

          secondFinite: false,

        );

        if (inter != null) {

          final dist = (inter - hit.point).distance;

          if (dist <= bestDist) {

            bestDist = dist;

            candidate = inter;

            snapLabel = 'Insulation';

            guides = [(w1, w2)];

          }

        }

      }



      // 2b. Core lines

      if (other.coreCorners.length >= 4) {

        final coreLines = <(Offset, Offset)>[

          (other.coreCorners[0], other.coreCorners[1]),

          (other.coreCorners[3], other.coreCorners[2]),

          (other.coreCorners[0], other.coreCorners[3]),

          (other.coreCorners[1], other.coreCorners[2]),

        ];

        for (final (c1, c2) in coreLines) {

          final inter = BimLineGeometry.intersection(

            edgeP1,

            edgeP2,

            c1,

            c2,

            firstFinite: true,

            secondFinite: false,

          );

          if (inter != null) {

            final dist = (inter - hit.point).distance;

            if (dist <= bestDist) {

              bestDist = dist;

              candidate = inter;

              snapLabel = 'Core';

              guides = [(c1, c2)];

            }

          }

        }

      }



      // 2c. Wall axis

      final interAxis = BimLineGeometry.intersection(

        edgeP1,

        edgeP2,

        other.startPoint,

        other.endPoint,

        firstFinite: true,

        secondFinite: false,

      );

      if (interAxis != null) {

        final dist = (interAxis - hit.point).distance;

        // Insulation & core take precedence over axis when within 4px of each other

        final margin = (snapLabel == 'Insulation' || snapLabel == 'Core')

            ? 4.0 / _currentScale

            : 0.0;

        if (dist <= bestDist - margin) {

          bestDist = dist;

          candidate = interAxis;

          snapLabel = 'Axis intersection';

          guides = [(other.startPoint, other.endPoint)];

        }

      }

    }



    // 3. Snapping to intersection with grid axes

    for (final axis in _project.gridAxes) {

      final inter = BimLineGeometry.intersection(

        edgeP1,

        edgeP2,

        axis.start,

        axis.end,

        firstFinite: true,

        secondFinite: false,

      );

      if (inter != null) {

        final dist = (inter - hit.point).distance;

        if (dist <= bestDist) {

          bestDist = dist;

          candidate = inter;

          snapLabel = 'Axis intersection';

          guides = [(axis.start, axis.end)];

        }

      }

    }



    // 3b. Door / window jambs and centres on the target wall

    final targetWall = storeyWalls

        .where((w) => w.id == _newPointTargetId)

        .firstOrNull;

    if (targetWall != null && targetWall.length > 1e-4) {

      final wallDir = (targetWall.endPoint - targetWall.startPoint) /

          targetWall.length;

      final openings = <(double, double, bool)>[

        for (final d in targetWall.doors)

          (d.offsetRatio, d.width, true),

        for (final w in targetWall.windows)

          (w.offsetRatio, w.width, false),

      ];

      final openingTol = math.min(bestDist, 16.0 / _currentScale);

      var openingBest = openingTol;

      for (final (ratio, width, _) in openings) {

        final centerDist = ratio * targetWall.length;

        for (final (along, label) in [

          (centerDist - width / 2, 'Opening edge'),

          (centerDist + width / 2, 'Opening edge'),

          (centerDist, 'Opening center'),

        ]) {

          if (along <= 1e-4 || along >= targetWall.length - 1e-4) continue;

          final pt = targetWall.startPoint + wallDir * along;

          final dist = (pt - hit.point).distance;

          // Jambs take precedence over the centre when equally close.

          final bias = label == 'Opening center' ? 2.0 / _currentScale : 0.0;

          if (dist + bias <= openingBest) {

            openingBest = dist + bias;

            bestDist = dist;

            candidate = pt;

            snapLabel = label;

            guides = [];

          }

        }

      }

    }



    // 4. Midpoint of the edge

    final mid = (edgeP1 + edgeP2) / 2;

    final midDist = (mid - hit.point).distance;

    if (midDist <= math.min(bestDist, 16.0 / _currentScale)) {

      bestDist = midDist;

      candidate = mid;

      snapLabel = 'Midpoint';

      guides = [];

    }



    // 5. Modular step (multiples of the wall thickness) measured from the

    // nearest end of the edge. Only used when no stronger snap was found.

    if (snapLabel == null) {

      final edgeLen = (edgeP2 - edgeP1).distance;

      final module = path.width > 1e-4 ? path.width : 0.1;

      final modulePx = module * _currentScale;

      if (edgeLen > 1e-4 && modulePx >= 6.0) {

        final dir = (edgeP2 - edgeP1) / edgeLen;

        final t = ((hit.point - edgeP1).dx * dir.dx +

            (hit.point - edgeP1).dy * dir.dy);

        final fromStart = t <= edgeLen / 2;

        final d = fromStart ? t : edgeLen - t;

        final snapped = (d / module).round() * module;

        final stepTol = math.min(6.0 / _currentScale, module / 3);

        if (snapped > 1e-4 &&

            snapped < edgeLen - 1e-4 &&

            (d - snapped).abs() <= stepTol) {

          candidate = fromStart

              ? edgeP1 + dir * snapped

              : edgeP2 - dir * snapped;

          snapLabel = 'Step';

          guides = [];

        }

      }

    }



    (Offset, Offset)? leaderLine;

    if (_handleOffsetLength > 0 && (rawModel - candidate).distance > 1e-3) {

      leaderLine = (candidate, rawModel);

    }



    _newPointCandidate = candidate;

    _newPointLeaderLine = leaderLine;

    _activeSnapLabel = snapLabel;

    _activeMagneticGuides = guides;

    _cursorModel = candidate;

    _repaintPreview();

  }



  void _commitNewPoint() {

    if (_newPointTargetId == null) return;

    final targetId = _newPointTargetId!;
    final holeIndex = _newPointHoleIndex;

    final pt = _newPointCandidate;

    if (pt == null) {

      _cancelNewPointSession();

      return;

    }



    final path = InsertArchitectElementPoint.pathOf(

      _project.activeStorey,

      targetId,
      holeIndex: holeIndex,

    );

    final hit = path == null

        ? null

        : BimLineGeometry.insertion(path.points, pt, closed: path.closed);



    final before = _project;

    _executeWallEdit(

      InsertArchitectElementPoint(

        storeyId: _project.activeStoreyId,

        elementId: targetId,

        point: pt,

        newElementId: ArchitectElementId.next('point'),

        atMidpoint: false,
        holeIndex: holeIndex,

      ),

    );

    if (identical(before, _project)) {

      _cancelNewPointSession();

      return;

    }



    setState(() {

      _newPointTargetId = null;

      _newPointCandidate = null;

      _newPointLeaderLine = null;

      _activeSnapLabel = null;

      _activeMagneticGuides = [];

      if (path != null && path.closed && hit != null) {
        _polygonContourElementId = targetId;
        _polygonContourIndex = holeIndex == null ? 0 : holeIndex + 1;

        _polygonEditId = targetId;

        _polygonSelectedEdge = hit.edge;

        if (_selectedZoneId == targetId) {

          _zoneTool.startEditingZone(

            _project.activeStorey.zones.firstWhere((z) => z.id == targetId),

          );

        }

      }

    });

    HapticFeedback.selectionClick();

    _repaintPreview();

  }



  Widget _buildNewPointPromptBanner() {

    return Material(

      key: const ValueKey('architect-new-point-banner'),

      color: const Color(0xE61E1E26),

      borderRadius: BorderRadius.circular(8),

      elevation: 4,

      shadowColor: Colors.black54,

      child: Container(

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFF00E5FF), width: 1.0),

        ),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

        child: SingleChildScrollView(

          scrollDirection: Axis.horizontal,

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              const BimEditingSymbol(

                BimEditAction.newPoint,

                color: Color(0xFF00E5FF),

                size: 18,

              ),

              const SizedBox(width: 8),

              Text(

                context.l10n.architectNewPointPrompt,

                style: const TextStyle(color: Colors.white, fontSize: 12),

              ),

              const SizedBox(width: 8),

              GestureDetector(

                key: const ValueKey('architect-new-point-cancel'),

                onTap: _cancelNewPointSession,

                child: const Icon(Icons.close, color: Colors.white70, size: 18),

              ),

            ],

          ),

        ),

      ),

    );

  }



  void _groupSelection() {

    final ids = _effectiveSelection;

    try {

      _commands.execute(GroupArchitectElements(storeyId: _project.activeStoreyId,

        groupId: ArchitectElementId.next('group'), elementIds: ids));

      setState(() {

        _selectionIds..clear()..addAll(ids);

        _selectedElementId = null; _selectedZoneId = null;

        _activeTool = ArchitectTool.select; _selectionContextActive = true; _moveSelection = true;

      });

      _saveBiMProjectIfAttached();

    } on ArgumentError { _operationError(); }

  }

  void _ungroupSelection() {

    final group = _selectedGroup;

    if (group == null) return;

    _commands.execute(UngroupArchitectElements(storeyId: _project.activeStoreyId, groupId: group.id));

    _clearSelection(); _saveBiMProjectIfAttached();

  }

  void _enterGroup() {

    final group = _selectedGroup;

    if (group == null) return;

    _clearSelection();

    setState(() { _editingGroupId = group.id; _activeTool = ArchitectTool.select; });

  }

  void _exitGroup() {

    final group = _editingGroup;

    _clearSelection();

    setState(() {

      _editingGroupId = null;

      if (group != null) {

        _selectionIds.addAll(group.elementIds);

        _selectionContextActive = true; _moveSelection = true;

      }

    });

  }

  Widget _groupEditBanner() => Material(

    borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.surface,

    child: Padding(padding: const EdgeInsets.only(left: 12), child: Row(children: [

      Expanded(child: Text(context.l10n.bimInsideGroup, overflow: TextOverflow.ellipsis)),

      TextButton(key: const ValueKey('architect-group-done'), onPressed: _exitGroup,

        child: Text(context.l10n.bimGroupDone)),

    ])),

  );



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

    if (action == ArchitectRadialAction.rotate && _commands.isPlan &&
        ArchitectRotation.supports(_project.activeStorey, _effectiveSelection)) {
      _startRotation();
      return;
    }

    if (action == ArchitectRadialAction.group) { _groupSelection(); return; }

    if (action == ArchitectRadialAction.ungroup) { _ungroupSelection(); return; }

    if (action == ArchitectRadialAction.editGroup) { _enterGroup(); return; }

    if (action == ArchitectRadialAction.offset &&

        ArchitectOffset.supports(_project.activeStorey, _effectiveSelection)) {

      _startOffset();

      return;

    }



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

          final bounds = _selectedGroup == null ? <Rect>[] : [

            for (final id in _effectiveSelection)

              if (ArchitectSelection.bounds(_project, id) case final Rect r) r,

          ];

          final origin = bounds.isEmpty ? null : bounds.reduce((a, b) => a.expandToInclude(b)).center;

          final next = _elementTool.rotateElementsByIds(

            _project.activeStorey,

            _effectiveSelection, origin: origin,

          );

          _commands.commit(_project.updateActiveStorey(next));

          _saveBiMProjectIfAttached();

          HapticFeedback.mediumImpact();

          return;

        case ArchitectRadialAction.duplicate:

          _beginDuplicateSelection();

          return;

        case ArchitectRadialAction.move:

          _cancelActiveDrags();

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

        case ArchitectRadialAction.mirrorMove:

          _startMirrorSession(isDuplicate: false);

          return;

        case ArchitectRadialAction.mirrorCopy:

          _startMirrorSession(isDuplicate: true);

          return;

        default:

          break;

      }

    }



    switch (action) {

      case ArchitectRadialAction.openView:
        _openSectionOrElevationView(id);
        break;

      case ArchitectRadialAction.group:

      case ArchitectRadialAction.ungroup:

      case ArchitectRadialAction.editGroup:

        break;

      case ArchitectRadialAction.cutOpening:

        _startCutOpening(id);

        break;

      case ArchitectRadialAction.schedule:

        _showRoomScheduleDialog();

        break;



      case ArchitectRadialAction.edit:
        if (pick != null) _selectPolygonContour(pick);

        final zoneToEdit = _project.activeStorey.zones.where((z) => z.id == id).firstOrNull;

        if (zoneToEdit != null && zoneToEdit.isAutoBoundary) {

          _commands.commit(

            _project.updateActiveStorey(

              _project.activeStorey.copyWith(

                zones: [

                  for (final z in _project.activeStorey.zones)

                    if (z.id == id) z.copyWith(isAutoBoundary: false) else z,

                ],

              ),

            ),

          );

        }

        final polygon = _selectedPolygon;

        if (polygon != null) {

          _cancelActiveDrags();

          setState(() {

            _polygonEditId = id;

            _polygonSelectedEdge = _selectedPolygonHoleIndex == null
                ? _selectedRoof?.safeEavesEdgeIndex : null;

            _moveSelection = false;

          });
          if (pick != null) _selectPolygonEdge(pick);

        } else if (_selectedLinearElement != null) {

          _wallEndpointOriginal = _selectedLinearElement;

          _wallDragStart = false;

          _elementMoveOriginal = _project;

          _elementMovePreview = _project;

          _isHandleEngaged = true;

        }

        break;



      case ArchitectRadialAction.straighten:

        final wall = _selectedWall;

        if (wall != null) {

          _straightenWall(wall);

        }

        break;



      case ArchitectRadialAction.move:

        _cancelActiveDrags();

        final zoneToMove = _project.activeStorey.zones.where((z) => z.id == id).firstOrNull;

        if (zoneToMove != null && zoneToMove.isAutoBoundary) {

          _commands.commit(

            _project.updateActiveStorey(

              _project.activeStorey.copyWith(

                zones: [

                  for (final z in _project.activeStorey.zones)

                    if (z.id == id) z.copyWith(isAutoBoundary: false) else z,

                ],

              ),

            ),

          );

        }

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

        final roofToRotate = _project.activeStorey.roofs

            .where((r) => r.id == id)

            .firstOrNull;

        if (roofToRotate != null) {

          final nextRoof = roofToRotate.nextSlopeEdge();

          setState(() {

            _commands.execute(

              UpdateArchitectRoofPlane(

                storeyId: _project.activeStoreyId,

                roof: nextRoof,

              ),

            );

            _polygonSelectedEdge = nextRoof.safeEavesEdgeIndex;

          });

          _saveBiMProjectIfAttached();

          HapticFeedback.mediumImpact();

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
        if (_project.sections.any((s) => s.id == id)) {
          _flipSection(id);
          break;
        }
        if (_project.elevations.any((e) => e.id == id)) {
          _flipElevation(id);
          break;
        }

        final roofToFlip = _project.activeStorey.roofs

            .where((r) => r.id == id)

            .firstOrNull;

        if (roofToFlip != null) {

          final nextRoof = roofToFlip.flippedSlope();

          setState(() {

            _commands.execute(

              UpdateArchitectRoofPlane(

                storeyId: _project.activeStoreyId,

                roof: nextRoof,

              ),

            );

            _polygonSelectedEdge = nextRoof.safeEavesEdgeIndex;

          });

          _saveBiMProjectIfAttached();

          HapticFeedback.mediumImpact();

          break;

        }

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

        _startNewPointSession(id, initialPick: pick);

        break;



      case ArchitectRadialAction.cut:

        _startCutSession({id});

        break;



      case ArchitectRadialAction.split:

        _startSplitSession(wallIds: {id});

        break;



      case ArchitectRadialAction.properties:
        if (_project.sections.any((s) => s.id == id) ||
            _project.elevations.any((e) => e.id == id)) {
          _showSectionElevationProperties(id);
          break;
        }
        _showProperties();
        break;



      case ArchitectRadialAction.delete:
        if (_project.sections.any((s) => s.id == id)) {
          _modelCommands.commit(
            _project.copyWith(
              sections: _project.sections.where((s) => s.id != id).toList(),
            ),
          );
          _saveBiMProjectIfAttached();
          setState(() {
            _selectedElementId = null;
            _selectionIds.remove(id);
          });
          HapticFeedback.heavyImpact();
          break;
        }
        if (_project.elevations.any((e) => e.id == id)) {
          _modelCommands.commit(
            _project.copyWith(
              elevations: _project.elevations.where((e) => e.id != id).toList(),
            ),
          );
          _saveBiMProjectIfAttached();
          setState(() {
            _selectedElementId = null;
            _selectionIds.remove(id);
          });
          HapticFeedback.heavyImpact();
          break;
        }
        var storey = _project.activeStorey;

        storey = _elementTool.deleteElementById(storey, id);

        _commands.commit(

          _project

              .updateActiveStorey(

                storey.copyWith(

                  zones: storey.zones.where((z) => z.id != id).toList(),

                  components: storey.components.where((c) => c.id != id).toList(),

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



      case ArchitectRadialAction.mirrorMove:

        _startMirrorSession(isDuplicate: false);

        break;



      case ArchitectRadialAction.mirrorCopy:

        _startMirrorSession(isDuplicate: true);

        break;

    }

  }



  void _handleSelectionTap(Offset point) {

    final selectedRoof = _selectedRoof;

    if (selectedRoof != null && !_multiSelect) {

      // 1. Tap on the central slope direction arrow/badge rotates slope direction

      if (ArchitectRoofPainterHelper.hitTestSlopeIndicator(

        selectedRoof,

        point,

        scale: _currentScale,

        storey: _project.activeStorey,

        project: _project,

      )) {

        final nextRoof = selectedRoof.nextSlopeEdge();

        setState(() {

          _commands.execute(

            UpdateArchitectRoofPlane(

              storeyId: _project.activeStoreyId,

              roof: nextRoof,

            ),

          );

          _polygonSelectedEdge = nextRoof.safeEavesEdgeIndex;

        });

        _saveBiMProjectIfAttached();

        HapticFeedback.selectionClick();

        return;

      }



      // 2. Tap near a roof edge selects that edge for dynamic wall distance editing

      //    (and a second tap on the already-selected edge sets it as the eaves edge).

      final edgeIdx = ArchitectRoofTool.hitTestEdgeIndex(

        selectedRoof,

        point,

        tolerance: math.min(18.0 / _currentScale, 0.35),

      );

      if (edgeIdx != null) {

        setState(() {

          if (_polygonSelectedEdge == edgeIdx &&

              (edgeIdx != selectedRoof.safeEavesEdgeIndex ||

                  selectedRoof.reverseSlope)) {

            _commands.execute(

              UpdateArchitectRoofPlane(

                storeyId: _project.activeStoreyId,

                roof: selectedRoof.withEavesEdge(edgeIdx),

              ),

            );

            _saveBiMProjectIfAttached();

          }

          _polygonSelectedEdge = edgeIdx;

        });

        HapticFeedback.selectionClick();

        return;

      }

    }



    if (!_selectAt(point, toggle: _multiSelect)) _clearSelection();

  }



  bool _selectAt(

    Offset point, {

    bool invalidateGesture = true,

    bool toggle = false,

  }) {

    final id = _nextSelection(point, advance: invalidateGesture);

    if (id == null) return false;

    if (!_acceptsAnySelection &&

        !_isElementAllowedForTool(id, _activeTool)) {

      return false;

    }

    if (!_multiSelect && id == _selectedElementId && _selectionIds.length == 1) {
      final sec = _project.sections.where((s) => s.id == id).firstOrNull;
      if (sec != null) {
        final tol = 20.0 / _currentScale;
        final norm = sec.viewDirection * (18.0 / _currentScale);
        if ((point - (sec.start + norm)).distance <= tol ||
            (point - (sec.end + norm)).distance <= tol) {
          _flipSection(sec.id);
          return true;
        }
      }
      final elv = _project.elevations.where((e) => e.id == id).firstOrNull;
      if (elv != null) {
        final tol = 20.0 / _currentScale;
        final mid = elv.centre;
        final dir = elv.viewDirection;
        final norm = (dir.distance > 0 ? dir / dir.distance : const Offset(0, 1)) * (24.0 / _currentScale);
        final tip = mid + norm;
        if ((point - tip).distance <= tol ||
            (point - BimLineGeometry.closest(point, mid, tip)).distance <= tol) {
          _flipElevation(elv.id);
          return true;
        }
      }
    }

    _cancelActiveDrags();

    _polygonEditId = null;

    _polygonSelectedEdge = null;

    _zoneTool.cancelAll();
    _polygonContourElementId = null;
    _polygonContourIndex = 0;

    _axisTool.cancelAll();

    _axisTool.deselect();

    final shouldMulti = _multiSelect;

    final adoptTool = !_multiSelect &&

        (_selectionContextActive || _activeTool == ArchitectTool.select);

    setState(() {

      if (invalidateGesture) _interactionEpoch++;

      _draftStart = null;

      _wallArcEnd = null;

      _draftEnd = null;

      if (shouldMulti) {

        if (_selectionIds.isEmpty && _selectedElementId != null) {

          _selectionIds.add(_selectedElementId!);

        } else if (_selectionIds.isEmpty && _selectedZoneId != null) {

          _selectionIds.add(_selectedZoneId!);

        }

        final members = _commands.isPlan && _editingGroupId == null

          ? _project.activeStorey.expandGroups({id}) : {id};

        if (toggle && members.every(_selectionIds.contains)) {

          _selectionIds.removeAll(members);

        } else {

          _selectionIds.addAll(members);

        }

      } else {

        _selectionIds

          ..clear()

          ..addAll(_commands.isPlan && _editingGroupId == null ? _project.activeStorey.expandGroups({id}) : {id});

      }

      final primary = _selectionIds.contains(id)

          ? id

          : _selectionIds.lastOrNull;



      if (primary != _selectedElementId || _selectionIds.length != 1) {
        _wallEndpointClearanceId = null;

        _wallParallelMove = false;

        _moveSelection = false;

      }

      final grouped = _editingGroupId == null && _commands.isPlan && _project.activeStorey.groupFor(id) != null;

      _selectedElementId = grouped ? null : primary;

      _selectedZoneId = null;

      if (grouped) {

        _activeTool = ArchitectTool.select;

        _selectionContextActive = true;

        _moveSelection = true;

      }

      if (!grouped && adoptTool && primary != null) {

        _activeTool = _toolForElement(primary);

        _selectionContextActive = true;

      }

      if (!grouped && primary != null) {

        final zone = _project.activeStorey.zones

            .where((e) => e.id == primary)

            .firstOrNull;

        if (zone != null) {

          _selectedZoneId = primary;

          _zoneTool.startEditingZone(zone);

        } else if (_project.gridAxes.any((e) => e.id == primary)) {

          _axisTool.selectAxis(primary);

        } else if (_selectionIds.length == 1) {

          final roof = _project.activeStorey.roofs

              .where((r) => r.id == primary)

              .firstOrNull;

          if (roof != null) {

            final edgeHit = ArchitectRoofTool.hitTestEdgeIndex(

              roof,

              point,

              tolerance: math.min(18.0 / _currentScale, 0.35),

            );

            _polygonSelectedEdge = edgeHit ?? roof.safeEavesEdgeIndex;

          }

        }

      }

    });

    HapticFeedback.selectionClick();

    _selectPolygonContour(point);
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

                  _wallArcEnd = null;

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



  void _setRoofDefaults(ArchitectRoofLayersResult result) {
    _roofTool.attachToWalls = result.attachToWalls;
    _roofTool.baseElevationOffset = result.baseElevationOffset;
    _roofTool.drainage = result.drainage.copyWith(downpipes: const []);
    _roofTool.setAssembly(result.assembly.copyWith());
    _roofTool.setSlopeDegrees(result.slopeDegrees);
    _roofTool.setUpperSlopeDegrees(result.upperSlopeDegrees);
    _roofTool.setBreakDistance(result.breakDistance);
    _roofTool.setEavesOverhang(result.eavesOverhang);
    _roofTool.setEavesCut(result.eavesCut);
    _roofTool.setManualSupportDistance(result.manualSupportDistance);
  }

  int _roofGroupCount(ArchitectRoofPlane? roof) {
    if (roof == null || roof.roofGroupId == null || roof.roofGroupId!.isEmpty) {
      return 1;
    }
    return _project.storeys
        .where((s) => s.id == roof.storeyId)
        .expand((s) => s.roofs)
        .where((r) => r.roofGroupId == roof.roofGroupId)
        .length;
  }

  void _applyRoofQuickValue(
    ArchitectRoofPlane roof,
    ArchitectRoofQuickValue value, {
    required bool slope,
  }) {
    if (!value.applyToGroup &&
        value.value == (slope ? roof.slopeDegrees : roof.eavesOverhang)) {
      return;
    }
    final result = ArchitectRoofLayersResult(
      assembly: roof.assembly,
      slopeDegrees: slope ? value.value : roof.slopeDegrees,
      eavesOverhang: slope ? roof.eavesOverhang : value.value,
      eavesCut: roof.eavesCut,
      applyToGroup: value.applyToGroup,
      changes: {
        slope ? ArchitectRoofSetting.slope : ArchitectRoofSetting.overhang,
      },
    );
    try {
      _modelCommands.execute(
        ApplyArchitectRoofSettings(
          storeyId: roof.storeyId,
          roofId: roof.id,
          settings: result,
        ),
      );
      _saveBiMProjectIfAttached();
    } on ArgumentError {
      _operationError();
    }
  }

  Future<void> _openRoofLayersDialog({
    ArchitectRoofPlane? roof,
    int initialTab = 0,
  }) async {
    var pickDownpipe = false;
    final original = _project;
    final target = roof ?? _selectedRoof ??
        (_selectedSectionRoofId == null
            ? null
            : ArchitectBuildingSection.findRoofById(
                _modelCommands.project,
                _selectedSectionRoofId!,
              )?.roof);
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectRoofLayersDialog(
        initialTab: initialTab,
        initialAssembly: target?.assembly ?? _roofTool.activeAssembly,
        initialSlopeDegrees: target?.slopeDegrees ?? _roofTool.slopeDegrees,
        initialEavesOverhang: target?.eavesOverhang ?? _roofTool.eavesOverhang,
        initialEavesCut: target?.eavesCut ?? _roofTool.eavesCut,
        initialDrainage: target?.drainage ?? _roofTool.drainage,
        initialBaseElevationOffset: target?.baseElevationOffset ??
            _roofTool.baseElevationOffset ?? _project.activeStorey.height,
        initialAttachToWalls: target?.attachToWalls ?? _roofTool.attachToWalls,
        initialManualSupportDistance: target == null
            ? _roofTool.manualSupportDistance
            : target.manualSupportDistance,
        initialIsMansard: target?.isMansard ??
            _roofTool.drawMode == RoofDrawMode.mansard,
        initialUpperSlopeDegrees: target?.upperSlopeDegrees ??
            _roofTool.upperSlopeDegrees,
        initialBreakDistance: target == null
            ? _roofTool.breakDistance
            : target.breakDistance,
        maxSupportDistance: target?.maxSlopeRun,
        project: original,
        roof: target,
        canPickDownpipe: target != null,
        onTryApply: (result) {
          if (!identical(original, _project)) {
            _operationError();
            return false;
          }
          try {
            if (target != null && result.changes.isNotEmpty) {
              _modelCommands.execute(
                ApplyArchitectRoofSettings(
                  storeyId: target.storeyId,
                  roofId: target.id,
                  settings: result,
                ),
              );
              _saveBiMProjectIfAttached();
            }
            if (target == null || result.saveForNewRoofs) {
              _setRoofDefaults(result);
            }
            pickDownpipe = result.pickDownpipe;
            return true;
          } on ArgumentError {
            _operationError();
            return false;
          }
        },
      ),
    );
    if (mounted && pickDownpipe && target != null) {
      _beginDownpipePlacement(target.id);
    }
  }

  void _beginDownpipePlacement([String? roofId]) {

    final project = _modelCommands.project;

    final floors = project.storeys

        .where((s) => s.roofs.any((r) => roofId == null || r.id == roofId))

        .toList();

    if (floors.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(context.l10n.architectDrainageNoRoof)),

      );

      return;

    }

    final floor =

        floors.where((s) => s.id == project.activeStoreyId).firstOrNull ??

        floors.last;

    _selectWorkspaceView(ArchitectWorkspaceView.plan, floor.id);

    setState(() {

      _placingDownpipe = true;

      _downpipeRoofId = roofId;

    });

  }



  void _placeDownpipe(Offset point) {

    final project = _modelCommands.project;

    ArchitectRoofPlane? selected;

    ArchitectStorey? floor;

    var distance = double.infinity, offset = 0.0;

    for (final storey in project.storeys) {

      if (storey.id != project.activeStoreyId) continue;

      for (final roof in storey.roofs) {

        if (_downpipeRoofId != null && roof.id != _downpipeRoofId) continue;

        final (start, end) = ArchitectRoofDrainageGeometry.eaves(roof);

        final axis = (end - start) / (end - start).distance;

        for (final (a, b) in ArchitectRoofDrainageGeometry.visibleEaves(

          project,

          storey,

          roof,

        )) {

          final d = b - a;

          // Leave room for the outlet collar and end cap when a phone tap

          // lands exactly at the end of an exposed gutter run.

          const endClearance = .061;

          if (d.distance <= endClearance * 2) continue;

          final t =

              (((point - a).dx * d.dx + (point - a).dy * d.dy) /

                      d.distanceSquared)

                  .clamp(

                    endClearance / d.distance,

                    1 - endClearance / d.distance,

                  );

          final p = a + d * t;

          if ((p - point).distance >= distance) continue;

          distance = (p - point).distance;

          selected = roof;

          floor = storey;

          offset = (p - start).dx * axis.dx + (p - start).dy * axis.dy;

        }

      }

    }

    if (selected == null ||

        floor == null ||

        distance > (24 / _viewport.scale).clamp(.15, .6)) {

      return;

    }

    final pipe = ArchitectDownpipe(

      id: ArchitectElementId.next('downpipe'),

      offset: offset,

    );

    final next = selected.copyWith(

      drainage: selected.drainage.copyWith(

        showGutter: true,

        showDownpipes: true,

        downpipes: [...selected.drainage.downpipes, pipe],

      ),

    );

    final route = ArchitectRoofDrainageGeometry.route(project, floor, next, pipe);

    if (route.status != ArchitectDownpipeStatus.ready) {

      final l = context.l10n;

      final message = switch (route.status) {

        ArchitectDownpipeStatus.noFacade => l.architectDrainageNoFacade,

        ArchitectDownpipeStatus.outsideEaves => l.architectDrainageOutside,

        _ => l.architectDrainageBlocked,

      };

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      return;

    }

    setState(() {

      _modelCommands.execute(

        UpdateArchitectRoofPlane(storeyId: floor!.id, roof: next),

      );

      _placingDownpipe = false;

      _downpipeRoofId = null;

      _selectionIds

        ..clear()

        ..add(next.id);

      _selectedElementId = next.id;

    });

    _saveBiMProjectIfAttached();

  }



  Future<void> _handleAutoRoof(AutoRoofType type) async {
    final original = _project;
    final generated = ArchitectRoofTool.generateAutoRoof(
      project: original,
      type: type,
      tool: _roofTool,
    );
    if (generated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.architectRoofAutoNoWalls)),
      );
      return;
    }
    final replaceIds = await showDialog<Set<String>>(
      context: context,
      builder: (_) => ArchitectAutoRoofPreviewDialog(
        project: original,
        generated: generated,
        type: type,
        selectedRoofId: _selectedRoof?.id,
      ),
    );
    if (!mounted || replaceIds == null) return;
    if (!identical(original, _project)) {
      _operationError();
      return;
    }
    try {
      _modelCommands.execute(
        CreateReviewedArchitectRoofs(
          storeyId: original.activeStoreyId,
          roofs: generated,
          replaceIds: replaceIds,
        ),
      );
      setState(() {
        _selectionIds
          ..clear()
          ..add(generated.first.id);
        _selectedElementId = generated.first.id;
        _polygonSelectedEdge = generated.first.safeEavesEdgeIndex;
        _multiSelect = false;
      });
      _saveBiMProjectIfAttached();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectRoofAutoCreated(generated.length)),
        ),
      );
    } on ArgumentError {
      _operationError();
    }
  }

  void _showWallTypes() {

    showDialog<void>(

      context: context,

      builder: (_) => ArchitectWallTypesManager(

        project: _modelCommands.project,

        onApply: (next) {

          try {

            _modelCommands.commit(next);

            _restoreWallType();

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

  void _createWallVariant(ArchitectWallType source) {
    final original = _project;
    showDialog<void>(
      context: context,
      builder: (_) => ArchitectWallCompositionEditor(
        project: original,
        type: source.copyWith(
          id: ArchitectElementId.next('wall_type'),
          name: '',
          labelId: source.labelId ?? source.id,
          isCatalogType: true,
        ),
        isNewType: true,
        typeUseCount: 0,
        onApply: (type, _, changed) {
          if (!identical(original, _project)) {
            _operationError();
            return false;
          }
          if (!changed) {
            _selectWallType(source);
            return true;
          }
          try {
            _modelCommands.execute(SetArchitectWallComposition(type: type));
            _selectWallType(type);
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



  void _editWallPlinth(

    Set<String> ids,

    Map<String, double> values,

    Map<String, String> texts,

  ) {

    final original = _project;

    ArchitectProject seeded;

    try {

      seeded = SetArchitectElementProperties(

        storeyId: original.activeStoreyId,

        elementIds: ids,

        values: values,

        textValues: texts,

      ).apply(original);

    } on ArgumentError {

      _operationError();

      return;

    }

    final walls = seeded.activeStorey.walls

        .where((w) => ids.contains(w.id))

        .toList();

    if (walls.length != ids.length || walls.isEmpty) return;

    showDialog<void>(

      context: context,

      builder: (_) => ArchitectWallPlinthDialog(

        project: seeded,

        values: walls.map((w) => w.plinth).toList(),

        onApply: (patch) {

          if (!identical(original, _project)) {

            _operationError();

            return false;

          }

          if (patch.isEmpty && values.isEmpty && texts.isEmpty) return true;

          try {

            _commands.executeBatch([

              SetArchitectElementProperties(

                storeyId: original.activeStoreyId,

                elementIds: ids,

                values: values,

                textValues: texts,

              ),

              SetArchitectWallPlinth(

                storeyId: original.activeStoreyId,

                wallIds: ids,

                patch: patch,

              ),

            ]);

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



  void _editWallLayers(

    Set<String> ids, {

    Map<String, double> values = const {},

    Map<String, String> texts = const {},

  }) {

    final original = _project;

    ArchitectProject seeded;

    try {

      seeded = SetArchitectElementProperties(

        storeyId: original.activeStoreyId,

        elementIds: ids,

        values: values,

        textValues: texts,

      ).apply(original);

    } on ArgumentError {

      _operationError();

      return;

    }

    final walls = seeded.activeStorey.walls

        .where((w) => ids.contains(w.id))

        .toList();

    if (walls.length != ids.length || walls.isEmpty) return;

    final wall = walls.first;

    final previous = seeded.wallTypes

        .where((t) => t.id == wall.wallTypeId)

        .firstOrNull;

    final type = ArchitectWallType(

      id: ArchitectElementId.next('wall_type'),

      name: previous != null && !previous.isFactoryPreset ? previous.name : '',

      isCatalogType: false,

      labelId: previous?.labelId ?? previous?.id,

      usage: wall.isParapet

          ? WallUsage.parapet

          : wall.isExterior

          ? WallUsage.exterior

          : WallUsage.interior,

      totalThickness: wall.thickness,

      layers: wall.resolvedLayers,

      location: wall.isExterior

          ? ArchitectWallLocation.exterior

          : ArchitectWallLocation.interior,

      loadBearing: wall.isLoadBearing,

      customHeight: previous?.customHeight,

      parapetFinish: wall.parapetFinish,

    );

    showDialog<void>(

      context: context,

      builder: (_) => ArchitectWallCompositionEditor(

        project: seeded,

        type: type,

        allowTypeSelection: true,

        onApply: (next, region, changed) {

          if (!identical(original, _project)) {

            _operationError();

            return false;

          }

          if (!changed &&

              (region == null || region.isEmpty) &&

              values.isEmpty &&

              texts.isEmpty) {

            return true;

          }

          try {

            _commands.executeBatch([

              SetArchitectElementProperties(

                storeyId: original.activeStoreyId,

                elementIds: ids,

                values: values,

                textValues: texts,

              ),

              SetArchitectWallComposition(

                type: next,

                storeyId: original.activeStoreyId,

                wallIds: ids,

                plinthPatch: region,

                preserveComposition: !changed,

              ),

            ]);

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



  Future<void> _showComponentDimensions(

    ArchitectComponentInstance component,

  ) async {

    final definition = ComponentLibraryService.instance.findDefinition(

      component.definitionId,

    );

    if (definition == null || component.isLocked) return;

    final storeyId = _project.activeStoreyId;

    final values = await ComponentDimensionsDialog.show(

      context,

      definition,

      component.parameters,

    );

    if (!mounted || values == null) return;

    final storey = _project.storeys.where((s) => s.id == storeyId).firstOrNull;

    if (storey == null || !storey.components.any((c) => c.id == component.id)) {

      return;

    }

    final updated = storey.copyWith(

      components: [

        for (final item in storey.components)

          item.id == component.id ? item.copyWith(parameters: values) : item,

      ],

    );

    _commands.commit(

      _project.copyWith(

        storeys: [

          for (final item in _project.storeys)

            item.id == storeyId ? updated : item,

        ],

      ),

    );

    _saveBiMProjectIfAttached();

  }



  void _showProperties() {

    final ids = _effectiveSelection;

    if (ids.isEmpty) return;

    if (ids.length == 1) {
      final sec = _project.sections.where((s) => ids.contains(s.id)).firstOrNull;
      if (sec != null) {
        _showSectionElevationProperties(sec.id);
        return;
      }
      final elv = _project.elevations.where((e) => ids.contains(e.id)).firstOrNull;
      if (elv != null) {
        _showSectionElevationProperties(elv.id);
        return;
      }
      final component = _project.activeStorey.components.where((c) => ids.contains(c.id)).firstOrNull;

      if (component != null) {

        _showComponentDimensions(component);

        return;

      }

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

        onScheduleTable: ids.any((id) => _project.activeStorey.zones.any((z) => z.id == id))

            ? () {

                Navigator.pop(context);

                _showRoomScheduleDialog();

              }

            : null,

        onWallPlinth:

            _selectedWallIds.length == ids.length &&

                _project.activeStorey.walls

                    .where((w) => ids.contains(w.id))

                    .every((w) => w.isExterior)

            ? (values, texts) => _editWallPlinth(ids, values, texts)

            : null,

        onWallLayers: _selectedWallIds.length == ids.length

            ? (values, texts) =>

                  _editWallLayers(ids, values: values, texts: texts)

            : null,

        onSlabLayers:

            ids.length == 1 &&

                _project.activeStorey.slabs.any((s) => ids.contains(s.id))

            ? () {

                Navigator.pop(context);

                final slab = _project.activeStorey.slabs.firstWhere(

                  (s) => ids.contains(s.id),

                );

                showDialog<void>(

                  context: context,

                  builder: (_) => ArchitectSlabLayersDialog(

                    project: _project,

                    slab: slab,

                    onApply: (next) {

                      _commands.commit(next);

                      return true;

                    },

                  ),

                );

              }

            : null,

        onStraighten:

            ids.length == 1 &&

                _selectedWallIds.length == 1 &&

                !_project.activeStorey.walls

                    .firstWhere((w) => w.id == ids.single)

                    .isCurved

            ? (values, texts) {

                try {

                  final edited = SetArchitectElementProperties(

                    storeyId: _project.activeStoreyId,

                    elementIds: ids,

                    values: values,

                    textValues: texts,

                  ).apply(_project);

                  final wall = edited.activeStorey.walls.firstWhere(

                    (w) => w.id == ids.single,

                  );

                  final command = _straightenWallCommand(edited, wall);

                  _cancelActiveDrags();

                  _commands.commit(command?.apply(edited) ?? edited);

                  _saveBiMProjectIfAttached();

                  return true;

                } on ArgumentError {

                  _operationError();

                  return false;

                }

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

    final wallIds = _selectedLineIds.isNotEmpty

        ? _selectedLineIds

        : _selectedWallIds;

    if (wallIds.length >= 2) {

      _cancelActiveDrags();

      try {

        _commands.execute(

          _linearCommand(

            JoinArchitectWalls(

              storeyId: _project.activeStoreyId,

              wallIds: wallIds,

            ),

          ),

        );

        _saveBiMProjectIfAttached();

        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              (_selectedLineIds.isNotEmpty ||

                      _activeTool == ArchitectTool.cadLine

                  ? context.l10n.architectLineJoinSuccess

                  : context.l10n.architectWallJoinSuccess),

            ),

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

          final wall = _linearEditWalls

              .where((w) => w.id == sourceId)

              .firstOrNull;

          if (wall != null) {

            final center = wall.referencePointAt(.5);

            _wallJoinPointer =

                center + wall.normalVector * (wall.thickness + 0.6);

          }

        }

      });

      HapticFeedback.selectionClick();

    }

  }



  // === SECTION: SELECTION ACTIONS, BARS & TOOLBARS ===



  void _editWallThickness(String id) {

    final wall = _project.activeStorey.walls

        .where((w) => w.id == id)

        .firstOrNull;

    if (wall == null) return;

    if (wall.layers.isNotEmpty) {

      _editWallLayers({id});

      return;

    }

    _cancelActiveDrags();

    setState(() => _radialMenuScreenPosition = null);

    showDialog<void>(

      context: context,

      builder: (_) => ArchitectWallThicknessDialog(

        project: _project,

        wall: wall,

        onApply: (core, insulation) {

          try {

            final edited = SetArchitectElementProperties(

              storeyId: _project.activeStoreyId,

              elementIds: {id},

              values: {

                'coreThickness': core,

                'insulationThicknessOverride': insulation,

              },

            ).apply(_project);

            final next = edited.activeStorey.walls.firstWhere(

              (w) => w.id == id,

            );

            final previous = edited.wallTypes

                .where((t) => t.id == wall.wallTypeId)

                .firstOrNull;

            final variant = ArchitectWallType(

              id: ArchitectElementId.next('wall_type'),

              isCatalogType: false,

              name: previous != null && !previous.isFactoryPreset

                  ? previous.name

                  : '',

              labelId: previous?.labelId ?? previous?.id,

              usage:

                  previous?.usage ??

                  (next.isExterior ? WallUsage.exterior : WallUsage.interior),

              totalThickness: next.thickness,

              layers: next.resolvedLayers,

              location: next.isExterior

                  ? ArchitectWallLocation.exterior

                  : ArchitectWallLocation.interior,

              loadBearing: next.isLoadBearing,

              customHeight: previous?.customHeight,

              parapetFinish: next.parapetFinish,

            );

            _commands.commit(

              SetArchitectWallComposition(

                type: variant,

                storeyId: edited.activeStoreyId,

                wallIds: {id},

              ).apply(edited),

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




  Widget _buildSelectControl() {
    final l10n = context.l10n;
    final isPoly = _marqueeTool.mode == ArchitectSelectMode.polygon;
    final drafting = _marqueeTool.isDrafting;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE61E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<ArchitectSelectMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment<ArchitectSelectMode>(
                  value: ArchitectSelectMode.rectangle,
                  icon: const Icon(Icons.crop_square_rounded, size: 18),
                  label: Text(
                    l10n.architectSelectModeRect,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                ButtonSegment<ArchitectSelectMode>(
                  value: ArchitectSelectMode.polygon,
                  icon: const Icon(Icons.polyline_rounded, size: 18),
                  label: Text(
                    l10n.architectSelectModePolygon,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              selected: {_marqueeTool.mode},
              onSelectionChanged: (set) {
                setState(() {
                  _marqueeTool.setMode(set.first);
                });
              },
            ),
            if (drafting) ...[
              const SizedBox(width: 8),
              if (isPoly && _marqueeTool.points.length >= 3)
                IconButton(
                  tooltip: l10n.architectSelectFinish,
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00E676), size: 22),
                  onPressed: () {
                    final poly = _marqueeTool.previewPolygon;
                    final hits = ArchitectMarqueeTool.evaluateSelection(
                      storey: _project.activeStorey,
                      project: _project,
                      polygon: poly,
                    );
                    setState(() {
                      if (_multiSelect) {
                        _selectionIds.addAll(hits);
                      } else {
                        _selectionIds
                          ..clear()
                          ..addAll(hits);
                      }
                      if (_selectionIds.isNotEmpty) _selectionContextActive = true;
                      _marqueeTool.cancel();
                    });
                    HapticFeedback.selectionClick();
                  },
                ),
              if (isPoly && _marqueeTool.points.isNotEmpty)
                IconButton(
                  tooltip: l10n.undoPoint,
                  icon: const Icon(Icons.undo_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: () {
                    setState(() {
                      _marqueeTool.removeLastPoint();
                    });
                  },
                ),
              IconButton(
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: () {
                  setState(() {
                    _marqueeTool.cancel();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWallSelectionActions(Set<String> wallIds) {

    final l = context.l10n;

    final selectedWalls = _project.activeStorey.walls

        .where((w) => wallIds.contains(w.id))

        .toList();

    final refLines = selectedWalls.map((w) => w.referenceLine).toSet();

    final currentRefLine = refLines.length == 1 ? refLines.first : null;

    return IntrinsicWidth(

      child: Material(

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

          child: SingleChildScrollView(

            scrollDirection: Axis.horizontal,

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                if (wallIds.length == 1)

                  TextButton(

                    key: const ValueKey('architect-wall-thickness'),

                    onPressed: () => _editWallThickness(wallIds.single),

                    child: Tooltip(

                      message: l.architectWallQuickThickness,

                      child: Text(

                        'd=${_project.formatLength(_project.activeStorey.walls.firstWhere((w) => w.id == wallIds.single).thickness)}',

                        style: const TextStyle(color: Colors.cyanAccent),

                      ),

                    ),

                  ),

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

                PopupMenuButton<WallReferenceLine>(

                  key: const ValueKey('architect-wall-reference-line'),

                  tooltip: l.architectWallLeadingLine,

                  color: const Color(0xFF1E242C),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(8),

                    side: const BorderSide(color: Colors.white24),

                  ),

                  child: Padding(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 6,

                      vertical: 8,

                    ),

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Icon(

                          switch (currentRefLine) {

                            WallReferenceLine.center =>

                              Icons.vertical_align_center,

                            WallReferenceLine.inner =>

                              Icons.vertical_align_bottom,

                            WallReferenceLine.outer => Icons.vertical_align_top,

                            _ => Icons.format_line_spacing,

                          },

                          size: 18,

                          color: const Color(0xFFFFB74D),

                        ),

                        const SizedBox(width: 4),

                        Text(

                          switch (currentRefLine) {

                            WallReferenceLine.center =>

                              l.architectWallReferenceCenter,

                            WallReferenceLine.inner =>

                              l.architectWallReferenceInner,

                            WallReferenceLine.outer =>

                              l.architectWallReferenceOuter,

                            _ => l.architectWallLeadingLine,

                          },

                          style: const TextStyle(

                            color: Color(0xFFFFB74D),

                            fontSize: 12,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                        const Icon(

                          Icons.arrow_drop_down,

                          size: 16,

                          color: Color(0xFFFFB74D),

                        ),

                      ],

                    ),

                  ),

                  itemBuilder: (context) => [

                    for (final ref in [

                      WallReferenceLine.center,

                      WallReferenceLine.inner,

                      WallReferenceLine.outer,

                    ])

                      PopupMenuItem<WallReferenceLine>(

                        key: ValueKey('architect-wall-ref-${ref.name}'),

                        value: ref,

                        child: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Icon(

                              ref == currentRefLine

                                  ? Icons.radio_button_checked

                                  : Icons.radio_button_unchecked,

                              size: 16,

                              color: ref == currentRefLine

                                  ? const Color(0xFFFFB74D)

                                  : Colors.white54,

                            ),

                            const SizedBox(width: 8),

                            Text(

                              switch (ref) {

                                WallReferenceLine.center =>

                                  l.architectWallReferenceCenter,

                                WallReferenceLine.inner =>

                                  l.architectWallReferenceInner,

                                WallReferenceLine.outer =>

                                  l.architectWallReferenceOuter,

                                _ => l.architectWallReferenceCenter,

                              },

                              style: TextStyle(

                                color: ref == currentRefLine

                                    ? const Color(0xFFFFB74D)

                                    : Colors.white,

                                fontWeight: ref == currentRefLine

                                    ? FontWeight.bold

                                    : FontWeight.normal,

                              ),

                            ),

                          ],

                        ),

                      ),

                  ],

                  onSelected: (newRef) =>

                      _setWallReferenceLine(wallIds, newRef),

                ),

                IconButton(

                  key: const ValueKey('architect-wall-cut'),

                  tooltip: l.architectWallCut,

                  icon: Icon(

                    Icons.content_cut,

                    color: (_wallCutIds.isNotEmpty && !_wallCutStroke)

                        ? Colors.amber

                        : Colors.white,

                  ),

                  onPressed: () {

                    if (_wallCutIds.isNotEmpty && !_wallCutStroke) {

                      _cancelCutSession();

                    } else {

                      _startCutSession(wallIds);

                    }

                  },

                ),

                IconButton(

                  key: const ValueKey('architect-wall-split'),

                  tooltip: l.architectWallSplit,

                  icon: Icon(

                    Icons.call_split,

                    color: _splitActive ? Colors.amber : Colors.white,

                  ),

                  onPressed: () {

                    if (_splitActive) {

                      _cancelSplitSession();

                    } else {

                      _startSplitSession(wallIds: wallIds);

                    }

                  },

                ),

                IconButton(

                  key: const ValueKey('architect-wall-join'),

                  tooltip: l.architectWallJoinTooltip,

                  icon: BimEditingSymbol(

                    BimEditAction.join,

                    color: _wallJoinSourceId != null

                        ? Colors.amber

                        : Colors.white,

                  ),

                  onPressed: () => _triggerWallJoin(),

                ),

                if (wallIds.length == 1) ...[

                  IconButton(

                    key: const ValueKey('architect-wall-new-point'),

                    tooltip: l.bimNewPoint,

                    icon: const BimEditingSymbol(

                      BimEditAction.newPoint,

                      color: Color(0xFF80CBC4),

                    ),

                    onPressed: () {

                      _cancelActiveDrags();

                      _startNewPointSession(wallIds.single);

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

        ),

      ),

    );

  }



  void _setWallReferenceLine(Set<String> wallIds, WallReferenceLine newRef) {

    if (wallIds.isEmpty) return;

    _cancelActiveDrags();

    _executeWallEdit(

      SetArchitectElementProperties(

        storeyId: _project.activeStoreyId,

        elementIds: wallIds,

        textValues: {'referenceLine': newRef.name},

      ),

    );

    _saveBiMProjectIfAttached();

    setState(() {

      _wallReference = newRef;

    });

  }



  bool _isWallOrthogonal(ArchitectWall wall) {

    final delta = wall.endPoint - wall.startPoint;

    if (delta.distance < 1e-4) return true;

    final angle = math.atan2(delta.dy, delta.dx);

    final target = (angle / (math.pi / 2)).round() * (math.pi / 2);

    return (angle - target).abs() < 1e-4;

  }



  UpdateArchitectWall? _straightenWallCommand(

    ArchitectProject project,

    ArchitectWall wall,

  ) {

    final delta = wall.endPoint - wall.startPoint;

    final len = delta.distance;

    if (len < 1e-4 || _isWallOrthogonal(wall)) return null;

    final angle = math.atan2(delta.dy, delta.dx);

    final target = (angle / (math.pi / 2)).round() * (math.pi / 2);

    final otherWalls = project.activeStorey.walls

        .where((w) => w.id != wall.id)

        .toList();

    final startConnected = otherWalls.any(

      (w) =>

          (w.startPoint - wall.startPoint).distance < 0.05 ||

          (w.endPoint - wall.startPoint).distance < 0.05 ||

          w.connectsAt(wall.startPoint),

    );

    final endConnected = otherWalls.any(

      (w) =>

          (w.startPoint - wall.endPoint).distance < 0.05 ||

          (w.endPoint - wall.endPoint).distance < 0.05 ||

          w.connectsAt(wall.endPoint),

    );



    final u = Offset(math.cos(target), math.sin(target));

    final Offset newStart;

    final Offset newEnd;

    final bool carryConn;



    if (endConnected && !startConnected) {

      newEnd = wall.endPoint;

      newStart = wall.endPoint - u * len;

      carryConn = false;

    } else {

      newStart = wall.startPoint;

      newEnd = wall.startPoint + u * len;

      carryConn = endConnected;

    }



    final updated = wall.copyWith(startPoint: newStart, endPoint: newEnd);

    return UpdateArchitectWall(

      storeyId: project.activeStoreyId,

      wall: updated,

      carryConnections: carryConn,

    );

  }



  void _straightenWall(ArchitectWall wall) {

    _cancelActiveDrags();

    final delta = wall.endPoint - wall.startPoint;

    final len = delta.distance;

    if (len < 1e-4) return;

    final angle = math.atan2(delta.dy, delta.dx);

    final target = (angle / (math.pi / 2)).round() * (math.pi / 2);

    if ((angle - target).abs() < 1e-4) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(context.l10n.architectWallAlreadyStraight),

          duration: const Duration(seconds: 1),

        ),

      );

      return;

    }



    final command = _straightenWallCommand(_project, wall)!;

    try {

      _commands.execute(command);

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(context.l10n.architectWallStraightened),

          duration: const Duration(seconds: 1),

        ),

      );

    } on ArgumentError {

      _operationError();

    }

  }



  void _deleteSelection() {

    final ids = _effectiveSelection;

    if (ids.isEmpty) return;

    final hadWalls = _project.activeStorey.walls.any((w) => ids.contains(w.id));

    final storey = _elementTool.deleteElementsByIds(_project.activeStorey, ids);

    final nextStorey = storey.copyWith(

      zones: storey.zones.where((z) => !ids.contains(z.id)).toList(),

    );

    final nextProject = _project
        .updateActiveStorey(nextStorey)
        .copyWithGridAxes(
          _project.gridAxes.where((a) => !ids.contains(a.id)).toList(),
        )
        .copyWith(
          sections: _project.sections.where((s) => !ids.contains(s.id)).toList(),
          elevations: _project.elevations.where((e) => !ids.contains(e.id)).toList(),
        );

    _commands.commit(nextProject);

    _saveBiMProjectIfAttached();

    _clearSelection();



    if (hadWalls) {

      _checkZoneMergeAfterWallDelete(nextProject.activeStorey);

    }

  }



  void _beginDuplicateSelection() {

    if (_selectionHasAutoZones) return;

    _cancelActiveDrags();

    final ids = _effectiveSelection;

    if (ids.isEmpty) return;

    final (nextStorey, copyIds) = _elementTool.duplicateElementsByIds(

      _project.activeStorey,

      ids,

      offset: const Offset(0.5, 0.5),

      copyGroups: _editingGroupId == null,

    );

    if (copyIds.isEmpty) return;

    var updated = _project.updateActiveStorey(nextStorey);

    if (_editingGroupId != null) {

      updated = AddArchitectGroupMembers(storeyId: _project.activeStoreyId,

        groupId: _editingGroupId!, elementIds: copyIds.toSet()).apply(updated);

    }

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



  void _startRotation() {
    final ids = Set<String>.of(_effectiveSelection);
    if (!ArchitectRotation.supports(_project.activeStorey, ids)) return;
    final bounds = [for (final id in ids)
      if (ArchitectSelection.bounds(_project, id) case final Rect r) r];
    if (bounds.isEmpty) return;
    _cancelActiveDrags();
    setState(() {
      _rotationSource = _project;
      _rotationIds = ids;
      _rotationPivot = bounds.reduce((a, b) => a.expandToInclude(b)).center;
      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _moveSelection = false;
      _wallParallelMove = false;
    });
  }

  void _previewRotation(Offset pivot, double angle) {
    final source = _rotationSource;
    if (source == null) return;
    _elementMovePreview = source.updateActiveStorey(
      ArchitectRotation.apply(source.activeStorey, _rotationIds, pivot, angle));
    _repaintPreview();
  }

  void _applyRotation(Offset pivot, double angle) {
    _previewRotation(pivot, angle);
    final next = _elementMovePreview;
    if (next == null) return;
    _cancelActiveDrags();
    _commands.commit(next);
    _saveBiMProjectIfAttached();
    setState(() {});
    HapticFeedback.mediumImpact();
    _repaintPreview();
  }

  Future<void> _startOffset() async {

    final ids = Set<String>.of(_effectiveSelection);

    if (!ArchitectOffset.supports(_project.activeStorey, ids)) return;

    _cancelActiveDrags();

    final source = _project;

    final epoch = _offsetEpoch;

    final options = await showBimElementOffsetDialog(context,

      unitToMeters: source.units.scaleToMeters, unitSymbol: source.units.symbol);

    if (!mounted || options == null || epoch != _offsetEpoch || !identical(source, _project)) return;

    setState(() {

      _offsetOptions = options;

      _offsetSource = source;

      _offsetIds = ids;

      _offsetIdMap = options.copy

          ? {for (final id in ids) id: ArchitectElementId.next('offset')} : {};

      _offsetGroupIdMap = options.copy && _editingGroupId == null

          ? {for (final g in source.activeStorey.groups.where((g) => ids.containsAll(g.elementIds)))

              g.id: ArchitectElementId.next('group')} : {};

      _offsetSide = null;

      _offsetValid = false;

      _polygonEditId = null;

      _polygonSelectedEdge = null;

      _moveSelection = false;

      _wallParallelMove = false;

      _zoneTool.cancelAll();

      _placingWithHold = false;

      _touchPosition = null;

    });

  }



  OffsetArchitectElements _offsetCommand(Offset side) => OffsetArchitectElements(

    storeyId: _offsetSource!.activeStoreyId, elementIds: _offsetIds,

    distance: _offsetOptions!.distance, side: side, idMap: _offsetIdMap,

    groupIdMap: _offsetGroupIdMap, editingGroupId: _editingGroupId);



  void _previewOffset(Offset side) {

    if (_offsetOptions == null || _offsetSource == null) return;

    final wasValid = _offsetValid;

    final wasAiming = _offsetSide != null;

    _offsetSide = side;

    _cursorModel = side;

    try {

      _elementMovePreview = _offsetCommand(side).apply(_offsetSource!);

      _offsetValid = true;

    } on ArgumentError {

      _elementMovePreview = null;

      _offsetValid = false;

    }

    if (wasValid != _offsetValid || !wasAiming) setState(() {});

    _repaintPreview();

  }



  void _commitOffset(Offset side) {

    _previewOffset(side);

    if (!_offsetValid || _elementMovePreview == null) {

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.bimOffsetInvalid)));

      return;

    }

    final next = _elementMovePreview!;

    final ids = _offsetOptions!.copy ? _offsetIdMap.values.toSet() : Set<String>.of(_offsetIds);

    _cancelActiveDrags();

    _commands.commit(next);

    _saveBiMProjectIfAttached();

    setState(() {

      _selectionIds..clear()..addAll(ids);

      _selectedElementId = ids.length == 1 ? ids.single : null;

      _selectedZoneId = null;

      _moveSelection = true;

    });

    HapticFeedback.mediumImpact();

    _repaintPreview();

  }



  Widget _offsetBanner() => Material(

    key: const ValueKey('architect-offset-banner'),

    color: Theme.of(context).colorScheme.surface,

    borderRadius: BorderRadius.circular(8),

    child: Padding(padding: const EdgeInsets.only(left: 12), child: Row(children: [

      Expanded(child: Tooltip(message: context.l10n.bimOffsetHelp, child: Text(

        _offsetSide != null && !_offsetValid ? context.l10n.bimOffsetInvalid : context.l10n.bimOffsetSide,

        maxLines: 2, overflow: TextOverflow.ellipsis))),

      IconButton(key: const ValueKey('architect-offset-cancel'), tooltip: context.l10n.cancel,

        icon: const Icon(Icons.close), onPressed: () {

          setState(_cancelActiveDrags); _repaintPreview();

        }),

    ])),

  );



  void _previewMirrorSnap(ArchitectSnapResult snap) {
    _cursorModel = snap.point;
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    _mirrorCurrentPoint = snap.point;
    final anchor = _mirrorAnchor;
    if (anchor != null) {
      final direction = snap.point - anchor;
      _elementMovePreview = direction.distanceSquared <= 1e-8 ? null :
        MirrorArchitectElements(storeyId: _project.activeStoreyId,
          elementIds: _mirrorSourceIds, origin: anchor, direction: direction,
          isDuplicate: _mirrorIsDuplicate, idMap: _mirrorIdMap,
          copyGroups: _editingGroupId == null).apply(_project);
    }
    _repaintPreview();
  }

  void _pickMirrorSnap(ArchitectSnapResult snap) {
    if (_mirrorAnchor == null) {
      setState(() { _mirrorAnchor = snap.point; _mirrorCurrentPoint = null; });
      HapticFeedback.selectionClick();
    } else {
      _executeMirror(anchor: _mirrorAnchor!, direction: snap.point - _mirrorAnchor!);
    }
    _repaintPreview();
  }

  void _startMirrorSession({required bool isDuplicate}) {

    if (_selectionHasAutoZones) return;

    if (_effectiveSelection.isEmpty) return;

    _cancelActiveDrags();

    setState(() {

      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _moveSelection = false;
      _mirrorActive = true;

      _mirrorIsDuplicate = isDuplicate;

      _mirrorSourceIds = Set<String>.from(_effectiveSelection);

      _mirrorAnchor = null;

      _mirrorCurrentPoint = null;

      _mirrorIdMap = isDuplicate

          ? {

              for (final id in _effectiveSelection)

                id: ArchitectElementId.next('mirror'),

            }

          : null;

      _radialMenuScreenPosition = null;

      _placingWithHold = false;

      _touchPosition = null;

      _elementMovePreview = null;

    });

    HapticFeedback.selectionClick();

  }



  void _cancelMirrorSession() {

    setState(() {

      _mirrorActive = false;

      _mirrorAnchor = null;

      _mirrorCurrentPoint = null;

      _mirrorIdMap = null;

      _elementMovePreview = null;

      _placingWithHold = false;

      _touchPosition = null;

    });

    _repaintPreview();

  }



  void _executeMirror({required Offset anchor, required Offset direction}) {

    if (direction.distanceSquared < 1e-12) return;

    final finalIdMap = _mirrorIsDuplicate ? _mirrorIdMap : null;

    try {

      final command = MirrorArchitectElements(

        storeyId: _project.activeStoreyId,

        elementIds: _mirrorSourceIds,

        origin: anchor,

        direction: direction,

        isDuplicate: _mirrorIsDuplicate,

        copyGroups: _editingGroupId == null,

        idMap: finalIdMap,

      );

      _commands.executeBatch([command,

        if (_mirrorIsDuplicate && finalIdMap != null && _editingGroupId != null)

          AddArchitectGroupMembers(storeyId: _project.activeStoreyId,

            groupId: _editingGroupId!, elementIds: finalIdMap.values.toSet()),

      ]);

      _saveBiMProjectIfAttached();

      if (_mirrorIsDuplicate && finalIdMap != null) {

        _selectionIds

          ..clear()

          ..addAll(finalIdMap.values);

        _selectedElementId = finalIdMap.values.firstOrNull;

      }

      HapticFeedback.mediumImpact();

    } on ArgumentError {

      _operationError();

    } finally {

      setState(() {

        _mirrorActive = false;

        _mirrorAnchor = null;

        _mirrorCurrentPoint = null;

        _mirrorIdMap = null;

        _elementMovePreview = null;

        _placingWithHold = false;

        _touchPosition = null;

      });

      _repaintPreview();

    }

  }



  Widget _buildMirrorPromptBanner() {
    final l = context.l10n;
    final anchor = _mirrorAnchor;
    return Material(key: const ValueKey('architect-mirror-banner'),
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(_mirrorIsDuplicate ? Icons.copy_all : Icons.flip, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(anchor == null ? l.architectMirrorPromptPickAnchor : l.architectMirrorPromptPickAxis,
              maxLines: 2, overflow: TextOverflow.ellipsis)),
            IconButton(key: const ValueKey('architect-mirror-pick-anchor'),
              tooltip: l.architectMirrorPickAnchor,
              icon: const Icon(Icons.center_focus_strong),
              onPressed: () { setState(() { _mirrorAnchor = null; _mirrorCurrentPoint = null;
                _elementMovePreview = null; }); _repaintPreview(); }),
            IconButton(key: const ValueKey('architect-mirror-cancel-btn'),
              tooltip: l.cancel, onPressed: _cancelMirrorSession, icon: const Icon(Icons.close)),
          ]),
          if (anchor != null) Row(children: [
            Expanded(child: TextButton(key: const ValueKey('architect-mirror-vertical-btn'),
              onPressed: () => _executeMirror(anchor: anchor, direction: const Offset(0, 1)),
              child: Text(l.architectMirrorAxisVertical))),
            Expanded(child: TextButton(key: const ValueKey('architect-mirror-horizontal-btn'),
              onPressed: () => _executeMirror(anchor: anchor, direction: const Offset(1, 0)),
              child: Text(l.architectMirrorAxisHorizontal))),
          ]),
        ])),
    );
  }


  void _openSectionOrElevationView(String id) {
    if (_project.sections.any((s) => s.id == id)) {
      _selectWorkspaceView(ArchitectWorkspaceView.section, id);
    } else if (_project.elevations.any((e) => e.id == id)) {
      _selectWorkspaceView(ArchitectWorkspaceView.elevation, id);
    }
  }

  void _flipSection(String id) {
    final sec = _project.sections.where((s) => s.id == id).firstOrNull;
    if (sec == null) return;
    _modelCommands.commit(
      _project.copyWith(
        sections: [
          for (final s in _project.sections)
            if (s.id == id) s.reversed() else s,
        ],
      ),
    );
    HapticFeedback.lightImpact();
  }

  void _flipElevation(String id) {
    final elv = _project.elevations.where((e) => e.id == id).firstOrNull;
    if (elv == null) return;
    _modelCommands.commit(
      _project.copyWith(
        elevations: [
          for (final e in _project.elevations)
            if (e.id == id) e.copyWith(viewSide: -e.viewSide) else e,
        ],
      ),
    );
    HapticFeedback.lightImpact();
  }

  void _showSectionElevationProperties(String id) {
    showArchitectViewPropertiesDialog(
      context: context,
      project: _project,
      viewId: id,
      controller: _modelCommands,
      onOpenView: () => _openSectionOrElevationView(id),
    );
  }

  void _selectConnectedWalls() {

    final wallIds = _selectedLineIds.isNotEmpty

        ? _selectedLineIds

        : _selectedWallIds;

    if (wallIds.isEmpty) return;

    final allConnected = <String>{};

    for (final wallId in wallIds) {

      allConnected.addAll(

        _elementTool.findConnectedWallChain(

          _project.activeStorey.copyWith(walls: _linearEditWalls),

          wallId,

        ),

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

    if (storey.cadPrimitives.any((p) => sel.contains(p.id) && p.type == CadPrimitiveType.hatch)) {

      targetIds.addAll(storey.cadPrimitives.where((p) => p.type == CadPrimitiveType.hatch).map((p) => p.id));

    }



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

                      l.architectDimensionExteriorHelp,

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

                      _wallArcEnd = null;

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

                  icon: BimEditingSymbol(

                    BimEditAction.newPoint,

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



    void _flipDoorsSwing(Set<String> doorIds) {
    if (doorIds.isEmpty) return;
    for (final id in doorIds) {
      final door = _project.activeStorey.walls
          .expand((w) => w.doors)
          .where((d) => d.id == id)
          .firstOrNull;
      if (door != null) {
        _commands.execute(
          SetArchitectElementProperties(
            storeyId: _project.activeStoreyId,
            elementIds: {id},
            textValues: {'openInward': (!door.openInward).toString()},
          ),
        );
      }
    }
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  void _flipDoorsHinge(Set<String> doorIds) {
    if (doorIds.isEmpty) return;
    for (final id in doorIds) {
      final door = _project.activeStorey.walls
          .expand((w) => w.doors)
          .where((d) => d.id == id)
          .firstOrNull;
      if (door != null) {
        _commands.execute(
          SetArchitectElementProperties(
            storeyId: _project.activeStoreyId,
            elementIds: {id},
            textValues: {'isHingeLeft': (!door.isHingeLeft).toString()},
          ),
        );
      }
    }
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  void _flipWindowsSide(Set<String> windowIds) {
    if (windowIds.isEmpty) return;
    for (final id in windowIds) {
      final window = _project.activeStorey.walls
          .expand((w) => w.windows)
          .where((w) => w.id == id)
          .firstOrNull;
      if (window != null) {
        _commands.execute(
          SetArchitectElementProperties(
            storeyId: _project.activeStoreyId,
            elementIds: {id},
            textValues: {'isFlipped': (!window.isFlipped).toString()},
          ),
        );
      }
    }
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  Widget _buildSelectionBar() {
    final l = context.l10n;
    final ids = _effectiveSelection;

    final wallIds = _selectedWallIds;

    final lineIds = _selectedLineIds;

    final segmentIds = lineIds.isNotEmpty ? lineIds : wallIds;

    final dimension = ids.length == 1
        ? _project.activeStorey.dimensions
              .where((d) => ids.contains(d.id))
              .firstOrNull
        : null;
    final selectedSection = ids.length == 1
        ? _project.sections.where((s) => ids.contains(s.id)).firstOrNull
        : null;
    final selectedElevation = ids.length == 1
        ? _project.elevations.where((e) => ids.contains(e.id)).firstOrNull
        : null;

        final selectedDoors = _project.activeStorey.walls
        .expand((w) => w.doors)
        .where((d) => ids.contains(d.id))
        .toList();
    final selectedWindows = _project.activeStorey.walls
        .expand((w) => w.windows)
        .where((w) => ids.contains(w.id))
        .toList();

    final isDoorSelection = selectedDoors.isNotEmpty && selectedDoors.length == ids.length;
    final isWindowSelection = selectedWindows.isNotEmpty && selectedWindows.length == ids.length;

    void clear() => _clearSelection();

    if (isDoorSelection) {
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
                  IconButton(
                    key: const ValueKey('architect-door-flip-swing'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectDoorFlipSwing,
                    icon: const Icon(
                      Icons.swap_vert,
                      color: Color(0xFF40C4FF),
                      size: 20,
                    ),
                    onPressed: () => _flipDoorsSwing(selectedDoors.map((d) => d.id).toSet()),
                  ),
                  IconButton(
                    key: const ValueKey('architect-door-flip-hinge'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectDoorFlipHinge,
                    icon: const Icon(
                      Icons.swap_horiz,
                      color: Color(0xFF40C4FF),
                      size: 20,
                    ),
                    onPressed: () => _flipDoorsHinge(selectedDoors.map((d) => d.id).toSet()),
                  ),
                  IconButton(
                    key: const ValueKey('architect-selection-move'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
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
                  IconButton(
                    key: const ValueKey('architect-selection-properties'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectProperties,
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                    onPressed: () {
                      setState(() => _radialMenuScreenPosition = null);
                      _showProperties();
                    },
                  ),
                  IconButton(
                    key: const ValueKey('architect-selection-delete'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
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
                    key: const ValueKey('architect-clear-selection'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
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

    if (isWindowSelection) {
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
                  IconButton(
                    key: const ValueKey('architect-window-flip-side'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectWindowFlipSide,
                    icon: const Icon(
                      Icons.flip,
                      color: Color(0xFF40C4FF),
                      size: 20,
                    ),
                    onPressed: () => _flipWindowsSide(selectedWindows.map((w) => w.id).toSet()),
                  ),
                  IconButton(
                    key: const ValueKey('architect-selection-move'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
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
                  IconButton(
                    key: const ValueKey('architect-selection-properties'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
                    tooltip: l.architectProperties,
                    icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
                    onPressed: () {
                      setState(() => _radialMenuScreenPosition = null);
                      _showProperties();
                    },
                  ),
                  IconButton(
                    key: const ValueKey('architect-selection-delete'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
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
                    key: const ValueKey('architect-clear-selection'),
                    constraints: const BoxConstraints.tightFor(width: 32, height: 40),
                    padding: EdgeInsets.zero,
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
                if (selectedSection != null) ...[
                  IconButton(
                    key: const ValueKey('architect-section-open-view'),
                    tooltip: l.architectOpenView,
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    onPressed: () => _openSectionOrElevationView(selectedSection.id),
                  ),
                  IconButton(
                    key: const ValueKey('architect-section-flip'),
                    tooltip: l.architectRadialFlip,
                    icon: const Icon(
                      Icons.flip,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => _flipSection(selectedSection.id),
                  ),
                  IconButton(
                    key: const ValueKey('architect-section-properties'),
                    tooltip: l.architectProperties,
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => _showSectionElevationProperties(selectedSection.id),
                  ),
                ],
                if (selectedElevation != null) ...[
                  IconButton(
                    key: const ValueKey('architect-elevation-open-view'),
                    tooltip: l.architectOpenView,
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    onPressed: () => _openSectionOrElevationView(selectedElevation.id),
                  ),
                  IconButton(
                    key: const ValueKey('architect-elevation-flip'),
                    tooltip: l.architectRadialFlip,
                    icon: const Icon(
                      Icons.flip,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => _flipElevation(selectedElevation.id),
                  ),
                  IconButton(
                    key: const ValueKey('architect-elevation-properties'),
                    tooltip: l.architectProperties,
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () => _showSectionElevationProperties(selectedElevation.id),
                  ),
                ],
                if (dimension != null) ...[

                  IconButton(

                    key: const ValueKey('architect-dimension-new-point'),

                    tooltip: l.architectDimensionNewPoint,

                    icon: const BimEditingSymbol(

                      BimEditAction.newPoint,

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

                if (segmentIds.isNotEmpty)

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

                if (wallIds.length == 1)

                  () {

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

                        key: const ValueKey(

                          'architect-selection-trim-overshoot',

                        ),

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

                if (!_selectionHasAutoZones)

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

                if (!_selectionHasAutoZones)

                  IconButton(

                    constraints: const BoxConstraints.tightFor(

                      width: 26,

                      height: 40,

                    ),

                    padding: EdgeInsets.zero,

                    key: const ValueKey('architect-selection-mirror-move'),

                    tooltip: l.architectMirrorMoveTooltip,

                    icon: const Icon(

                      Icons.flip,

                      color: Color(0xFF00E5FF),

                      size: 18,

                    ),

                    onPressed: () => _startMirrorSession(isDuplicate: false),

                  ),

                if (!_selectionHasAutoZones)

                  IconButton(

                    constraints: const BoxConstraints.tightFor(

                      width: 26,

                      height: 40,

                    ),

                    padding: EdgeInsets.zero,

                    key: const ValueKey('architect-selection-mirror-copy'),

                    tooltip: l.architectMirrorCopyTooltip,

                    icon: const Icon(

                      Icons.copy_all,

                      color: Color(0xFFFFB300),

                      size: 18,

                    ),

                    onPressed: () => _startMirrorSession(isDuplicate: true),

                  ),

                if (segmentIds.length == 1 && ids.length == 1)

                  Tooltip(

                    message: lineIds.isNotEmpty

                        ? l.architectLineParallelHelp

                        : l.architectWallParallelHelp,

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

                    icon: const BimEditingSymbol(

                      BimEditAction.newPoint,

                      color: Color(0xFF80CBC4),

                      size: 18,

                    ),

                    onPressed: () {

                      _cancelActiveDrags();

                      _startNewPointSession(ids.single);

                    },

                  ),

                if (segmentIds.isNotEmpty)

                  PopupMenuButton<String>(

                    key: const ValueKey('architect-wall-actions'),

                    padding: EdgeInsets.zero,

                    icon: const Icon(Icons.more_horiz, color: Colors.white70),

                    onSelected: (action) {

                      if (action == 'cut') {

                        _startCutSession(Set.of(segmentIds));

                      } else if (action == 'splitStroke') {

                        _startSplitSession(wallIds: Set.of(segmentIds));

                      } else if (action == 'mirror') {

                        _executeWallEdit(

                          MirrorArchitectWalls(

                            storeyId: _project.activeStoreyId,

                            wallIds: segmentIds,

                          ),

                        );

                      } else if (action == 'mirrorMove') {

                        _startMirrorSession(isDuplicate: false);

                      } else if (action == 'mirrorCopy') {

                        _startMirrorSession(isDuplicate: true);

                      } else if (action == 'join') {

                        try {

                          _commands.execute(

                            _linearCommand(

                              JoinArchitectWalls(

                                storeyId: _project.activeStoreyId,

                                wallIds: segmentIds,

                              ),

                            ),

                          );

                          _saveBiMProjectIfAttached();

                        } on ArgumentError {

                          _operationError();

                        }

                      } else if (action == 'extend') {

                        setState(() => _wallExtendId = segmentIds.single);

                      } else if (action == 'length') {

                        _editWallLength();

                      } else if (action == 'point') {

                        _startNewPointSession(segmentIds.single);

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

                        key: const ValueKey('wall-mirror-move'),

                        value: 'mirrorMove',

                        child: Text(l.architectMirrorMove),

                      ),

                      PopupMenuItem(

                        key: const ValueKey('wall-mirror-copy'),

                        value: 'mirrorCopy',

                        child: Text(l.architectMirrorCopy),

                      ),

                      if (lineIds.isEmpty)

                        PopupMenuItem(

                          key: const ValueKey('wall-mirror'),

                          value: 'mirror',

                          child: Text(l.architectWallMirror),

                        ),

                      if (segmentIds.length == 1 && !_multiSelect) ...[

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

                      if (segmentIds.length >= 2)

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
      ..._project.sections.map((e) => e.id),
      ..._project.elevations.map((e) => e.id),
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

        _wallArcEnd = null;

        _draftEnd = null;

      });

      _saveBiMProjectIfAttached();

      _initTransform();

    }

  }



  // === SECTION: MAIN BUILD METHOD & WORKSPACE LAYOUT ===



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

                  zonePresets: _zonePresets,

                  drawingOnly: !_commands.isPlan,

                  onTerrain: _commands.view == ArchitectWorkspaceView.elevation ? _startTerrainDraft : null,

                  activeTool: _activeTool,

                  onToolChanged: _changeTool,

                  multiSelect: _multiSelect,

                  onToggleMultiSelect: _toggleMultiSelection,

                  activeZoneCategory: _activeZoneCategory,

                  onZoneCategoryChanged: (cat) =>

                      setState(() => _activeZoneCategory = cat),

                  wallThickness: _wallThickness,

                  onWallThicknessChanged: (t) =>

                      setState(() => _wallThickness = t),

                  wallMode: _wallMode,

                  curvedWall: _wallCurved,

                  onArcWallSelected: () {

                    _finishChainedWall();

                    setState(() => _wallCurved = true);

                  },

                  onWallModeChanged: (m) {

                    _finishChainedWall();

                    setState(() {

                      _wallCurved = false;

                      _wallMode = m;

                    });

                  },

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

                  onCreateWallVariant: _createWallVariant,
                  onManageWallTypes: _showWallTypes,
                  wallProjectId: _project.id,
                  wallUnit: _project.units,

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

                    design: _elementTool.stairDesign.copyWith(

                      shape: shape,

                      autoRisers: true,

                    ),

                  ),

                  onStairProperties: () => _showStairProperties(),

                  stairWidth: _elementTool.stairWidth,

                  onStairWidthChanged: (sw) =>

                      _elementTool.setStairParams(width: sw),

                  stairSteps: _elementTool.stairSteps,

                  onStairStepsChanged: (st) =>

                      _elementTool.setStairParams(steps: st),

                  openingType: _elementTool.openingType,

                  onOpeningTypeChanged: (ot) => _elementTool.setOpeningType(ot),

                  componentRotation: _componentRotation,

                  onRotateComponent: () {

                    setState(() {

                      _componentRotation = (_componentRotation + 3.141592653589793 / 2.0) % (2.0 * 3.141592653589793);

                    });

                  },

                  onOpenComponentLibrary: () {

                    ArchitectComponentLibraryDialog.show(

                      context,

                      onSelectDownpipe: () => _beginDownpipePlacement(),
                      onSelectFloorDrain: () => setState(() => _activeTool = ArchitectTool.floorDrain),

                      onSelectComponent: (def) {

                        setState(() => _activeTool = ArchitectTool.component);

                      },

                      onSelectFenestration: (style) {

                        setState(() {

                          if (style.kind == FenestrationKind.door) {

                            _doorWidth = style.defaultWidth;

                            _doorHeight = style.defaultHeight;

                            _doorSill = style.defaultSillHeight;

                            _elementTool.setDoorStyle(style);

                            FenestrationLibraryService.instance

                                .setActiveDoorStyle(style);

                            _activeTool = ArchitectTool.door;

                          } else {

                            _elementTool.setWindowStyle(style);

                            FenestrationLibraryService.instance

                                .setActiveWindowStyle(style);

                            _activeTool = ArchitectTool.window;

                          }

                        });

                      },

                    );

                  },

                  onOpenComponentStudio: () {

                    ComponentStudioDialog.show(context);

                  },

                ),

          body: Column(

            children: [

              _workspaceNavigationBar(),



              // Main Viewport (2D Canvas or 3D Solid Model)

              Expanded(

                child: Stack(

                  children: [

                    _is3DView

                        ? _build3DViewport()

                        : !_commands.hasView

                        ? Center(child: Text(l10n.architectViewDrawingEmpty))

                        : (_printPreview

                              ? _buildPublicationCanvas()

                              : _build2DCanvas()),

                    if (_activeTool == ArchitectTool.zone &&

                        !_is3DView &&

                        _radialMenuScreenPosition == null &&

                        _newPointTargetId == null)

                      Positioned(

                        top: 10,

                        left: 0,

                        right: 0,

                        child: ArchitectZoneDraftingBar(

                          kind: _activeZoneKind,

                          onKindChanged: (kind) => setState(() {

                            _zoneTool.cancelDrafting();

                            _activeZoneKind = kind;

                            if (kind == ArchitectZoneKind.apartment) _zoneTool.placementMode = ArchitectZonePlacementMode.manualPoints;

                          }),

                          zonePresets: _zonePresets,

                          tool: _zoneTool,

                          category: _activeZoneCategory,

                          onCategoryChanged: (cat) =>

                              setState(() => _activeZoneCategory = cat),

                          onClose: _commitDraftedZone,

                          onUndo: () =>

                              setState(() => _zoneTool.undoDraftingPoint()),

                          onCancel: () => setState(() {

                            _zoneTool.cancelDrafting();

                            _selectedZoneId = null;

                          }),

                          onOpenScheduleTable: _showRoomScheduleDialog,

                          onPlaceTable: () => setState(

                            () => _activeTool = ArchitectTool.zoneTable,

                          ),

                        ),

                      ),

                    if (_activeTool == ArchitectTool.zoneTable &&

                        !_is3DView &&

                        _radialMenuScreenPosition == null &&

                        _newPointTargetId == null)

                      Positioned(

                        top: 10,

                        left: 0,

                        right: 0,

                        child: ArchitectZoneTableBar(

                          isTablePlaced:

                              _project.activeStorey.zoneScheduleOrigin != null,

                          onBackToZones: () =>

                              setState(() => _activeTool = ArchitectTool.zone),

                          onOpenScheduleDialog: _showRoomScheduleDialog,

                          onRemoveTable: _removeZoneScheduleTable,

                          onClose: () => setState(

                            () => _activeTool = ArchitectTool.select,

                          ),

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
                        _selectedPolygonHoleIndex == null &&

                        !_is3DView &&

                        (_polygonEditId == null ||

                            _polygonEditId == _selectedRoof?.id))

                      Positioned(

                        top: 10,

                        left: 8,

                        right: 8,

                        child: ArchitectRoofBar(

                          tool: _roofTool,

                          selectedRoof: _selectedRoof,

                          selectedEdgeIndex: _polygonSelectedEdge,

                          onAutoRoof: _handleAutoRoof,

                          onOpenLayersDialog: () =>

                              _openRoofLayersDialog(roof: _selectedRoof),

                          onSwitchEavesEdge: () {

                            final sel = _selectedRoof;

                            if (sel == null || sel.points.length < 3) return;

                            final nextRoof = sel.nextSlopeEdge();

                            setState(() {

                              _commands.execute(

                                UpdateArchitectRoofPlane(

                                  storeyId: _project.activeStoreyId,

                                  roof: nextRoof,

                                ),

                              );

                              _polygonSelectedEdge =

                                  nextRoof.safeEavesEdgeIndex;

                            });

                            _saveBiMProjectIfAttached();

                            HapticFeedback.selectionClick();

                          },

                          onFlipSlopeDirection: () {

                            final sel = _selectedRoof;

                            if (sel == null || sel.points.length < 3) return;

                            final nextRoof = sel.flippedSlope();

                            setState(() {

                              _commands.execute(

                                UpdateArchitectRoofPlane(

                                  storeyId: _project.activeStoreyId,

                                  roof: nextRoof,

                                ),

                              );

                              _polygonSelectedEdge =

                                  nextRoof.safeEavesEdgeIndex;

                            });

                            _saveBiMProjectIfAttached();

                            HapticFeedback.selectionClick();

                          },

                          onSetSelectedEdgeAsEaves: () {

                            final sel = _selectedRoof;

                            final edgeIdx = _polygonSelectedEdge;

                            if (sel == null ||

                                edgeIdx == null ||

                                sel.points.length < 3) {

                              return;

                            }

                            final nextRoof = sel.withEavesEdge(edgeIdx);

                            setState(() {

                              _commands.execute(

                                UpdateArchitectRoofPlane(

                                  storeyId: _project.activeStoreyId,

                                  roof: nextRoof,

                                ),

                              );

                              _polygonSelectedEdge =

                                  nextRoof.safeEavesEdgeIndex;

                            });

                            _saveBiMProjectIfAttached();

                            HapticFeedback.selectionClick();

                          },

                          groupCount: _roofGroupCount(_selectedRoof),
                          unit: _project.units,
                          onOpenAssemblyDialog: () => _openRoofLayersDialog(roof: _selectedRoof, initialTab: 1),
                          onApplySlope: (value) {
                            final roof = _selectedRoof;
                            if (roof != null) _applyRoofQuickValue(roof, value, slope: true);
                          },
                          onApplyOverhang: (value) {
                            final roof = _selectedRoof;
                            if (roof != null) _applyRoofQuickValue(roof, value, slope: false);
                          },
                          onToggleSlopeLocked: () {

                            final sel = _selectedRoof;

                            if (sel != null) {

                              setState(() {

                                _commands.execute(

                                  UpdateArchitectRoofPlane(

                                    storeyId: _project.activeStoreyId,

                                    roof: sel.copyWith(

                                      isSlopeLocked: !sel.isSlopeLocked,

                                    ),

                                  ),

                                );

                              });

                              _saveBiMProjectIfAttached();

                              HapticFeedback.selectionClick();

                            }

                          },

                          onMatchRidgeHeight: () {

                            final sel = _selectedRoof;

                            if (sel == null) return;

                            final grp = sel.roofGroupId;

                            ArchitectRoofPlane? refRoof;

                            if (grp != null && grp.isNotEmpty) {

                              for (final r in _project.activeStorey.roofs) {

                                if (r.id != sel.id && r.roofGroupId == grp) {

                                  if (refRoof == null ||

                                      r.maxSlopeRun > refRoof.maxSlopeRun) {

                                    refRoof = r;

                                  }

                                }

                              }

                            }

                            refRoof ??= _project.activeStorey.roofs

                                .where((r) => r.id != sel.id)

                                .firstOrNull;

                            if (refRoof == null) return;



                            final targetZ =

                                refRoof.maxSlopeRun *

                                math.tan(refRoof.slopeRadians);

                            final myRun = sel.maxSlopeRun;

                            final newSlope =

                                ArchitectRoofGeometry.calculateSlopeToMatchRidgeHeight(

                                  targetRidgeHeight: targetZ,

                                  runDistance: myRun,

                                );



                            setState(() {

                              _commands.execute(

                                UpdateArchitectRoofPlane(

                                  storeyId: _project.activeStoreyId,

                                  roof: sel.copyWith(

                                    slopeDegrees: newSlope,

                                    isSlopeLocked: false,

                                  ),

                                ),

                              );

                            });

                            _saveBiMProjectIfAttached();

                            HapticFeedback.mediumImpact();

                            ScaffoldMessenger.of(context).showSnackBar(

                              SnackBar(

                                content: Text(

                                  context.l10n.architectRoofRidgeHeightMatched(

                                    newSlope.toStringAsFixed(1),

                                    (refRoof.baseElevationOffset + targetZ)

                                        .toStringAsFixed(2),

                                  ),

                                ),

                                duration: const Duration(seconds: 2),

                              ),

                            );

                          },

                          onToggleMansard: () {
                            final sel = _selectedRoof;
                            if (sel == null) return;
                            final next = sel.copyWith(
                              isMansard: !sel.isMansard,
                              slopeDegrees: !sel.isMansard && sel.slopeDegrees <= 30.0
                                  ? 60.0
                                  : sel.slopeDegrees,
                              upperSlopeDegrees: sel.upperSlopeDegrees,
                            );
                            setState(() {
                              _commands.execute(
                                UpdateArchitectRoofPlane(
                                  storeyId: _project.activeStoreyId,
                                  roof: next,
                                ),
                              );
                            });
                            _saveBiMProjectIfAttached();
                            HapticFeedback.selectionClick();
                          },

                          onSelectedRoofUpperSlopeChanged: (upperSlopeDeg) {
                            final sel = _selectedRoof;
                            if (sel == null) return;
                            final next = sel.copyWith(
                              upperSlopeDegrees: upperSlopeDeg,
                            );
                            setState(() {
                              _commands.execute(
                                UpdateArchitectRoofPlane(
                                  storeyId: _project.activeStoreyId,
                                  roof: next,
                                ),
                              );
                            });
                            _saveBiMProjectIfAttached();
                            HapticFeedback.selectionClick();
                          },

                          onSelectedRoofBreakDistanceChanged: (dist) {
                            final sel = _selectedRoof;
                            if (sel == null) return;
                            final next = sel.copyWith(breakDistance: dist);
                            setState(() {
                              _commands.execute(
                                UpdateArchitectRoofPlane(
                                  storeyId: _project.activeStoreyId,
                                  roof: next,
                                ),
                              );
                            });
                            _saveBiMProjectIfAttached();
                            HapticFeedback.selectionClick();
                          },

                          onFinishPolygon: _commitRoofDraft,

                          onUndoDraftPoint: () =>

                              setState(() => _roofTool.undoLastDraftPoint()),

                          onCancelDraft: _cancelDrafting,

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

                            onTrim: () =>

                                _handleTrimOvershoot(_activeOvershoot!),

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

                                  BimEditingSymbol(

                                    BimEditAction.join,

                                    color: Color(0xFF00E5FF),

                                    size: 20,

                                  ),

                                  const SizedBox(width: 8),

                                  Text(

                                    (_selectedLineIds.isNotEmpty

                                        ? context

                                              .l10n

                                              .architectLineJoinSelectSecond

                                        : context

                                              .l10n

                                              .architectWallJoinSelectSecond),

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

                  !_is3DView &&

                  _radialMenuScreenPosition == null &&

                  _newPointTargetId == null)

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



  Offset? get _draftCancelAnchor {

    if (_activeTool == ArchitectTool.column && _effectiveSelection.isEmpty) {

      final center = _columnPreviewPoint ?? _cursorModel;

      if (center == null) return null;

      final halfWidth = _elementTool.columnWidth / 2;

      if (_elementTool.columnShape == ColumnShape.circular) {

        return center + Offset(halfWidth, -halfWidth);

      }

      final angle = _columnPreviewRotation * math.pi / 180;

      final cosine = math.cos(angle).abs();

      final sine = math.sin(angle).abs();

      final halfDepth = _elementTool.columnDepth / 2;

      return center + Offset(

        halfWidth * cosine + halfDepth * sine,

        -(halfWidth * sine + halfDepth * cosine),

      );

    }

    if (_activeTool == ArchitectTool.door ||

        _activeTool == ArchitectTool.window) {

      return _openingPlacementPreview?.centerPoint ?? _cursorModel;

    }

    if (_activeTool == ArchitectTool.roof && _roofTool.isDrafting) {

      return _roofTool.draftPoints.lastOrNull ??

          _roofTool.draftPoints.firstOrNull ??

          _draftStart;

    }

    return _dimensionAnchors.firstOrNull?.point ??

        _draftStart ??

        _axisTool.draftStart ??

        _zoneTool.draftPoints.lastOrNull ??

        _elementTool.slabDraftPoints.lastOrNull ??

        _roofTool.draftPoints.firstOrNull;

  }



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



  bool get _canConfirmRoofDraft =>

      _activeTool == ArchitectTool.roof &&

      _roofTool.isDrafting &&

      (_roofTool.drawMode == RoofDrawMode.polygon ||

          _roofTool.drawMode == RoofDrawMode.multiPitch) &&

      _roofTool.draftPoints.length >= 3;



  bool get _canConfirmContour =>

      (_activeTool == ArchitectTool.slab || _activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.floorDrain) &&

      ArchitectPolygonGeometry.valid(_elementTool.slabDraftPoints);



  bool get _canConfirmZone => _activeTool == ArchitectTool.zone &&

      _zoneTool.canCloseDraft && !_zoneTool.hasDraftCrossings;



  bool get _canConfirmDraft => _canConfirmDimension || _canConfirmRoofDraft ||

      _canConfirmContour || _canConfirmZone;



  void _onConfirmDraft() {

    if (_cutOpeningTargetId != null && _canConfirmContour) {

      _commitCutOpening();

      return;

    }

    if (_canConfirmContour) {

      if (_activeTool == ArchitectTool.hatch) { _commitHatch(); return; }

      final result = _elementTool.commitSlab(storey: _project.activeStorey);

      if (result != null) {

        setState(() => _project = _project.updateActiveStorey(result.$1));

        _saveBiMProjectIfAttached();

        HapticFeedback.mediumImpact();

      }

    } else if (_canConfirmZone) {

      _commitDraftedZone();

    } else if (_canConfirmRoofDraft) {

      _commitRoofDraft();

    } else if (_canConfirmDimension) {

      _commitDimensionDraft();

    }

  }



  Rect? get _draftCancelRect {

    final anchor = _draftCancelAnchor;

    if (anchor == null ||

        _viewport.size.width < 48 ||

        _viewport.size.height < 48) {

      return null;

    }

    final point = _viewport.toScreen(anchor);

    final width = _canConfirmDraft && _viewport.size.width >= 92

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

    return cancel != null && _canConfirmDraft && _viewport.size.width >= 92

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

    animation: Listenable.merge([_viewport, _previewRevision, _roofTool]),

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

                      color: _activeTool == ArchitectTool.column

                          ? Colors.white

                          : Theme.of(context).colorScheme.secondaryContainer,

                    ),

                    child: Icon(

                      Icons.close,

                      size: 13,

                      color: _activeTool == ArchitectTool.column

                          ? Colors.red

                          : Theme.of(context).colorScheme.onSecondaryContainer,

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

                key: ValueKey(

                  _canConfirmRoofDraft

                      ? 'architect-roof-confirm'

                      : _canConfirmContour || _canConfirmZone

                      ? 'architect-draft-confirm'

                      : 'architect-dimension-confirm',

                ),

                constraints: const BoxConstraints.tightFor(

                  width: 40,

                  height: 40,

                ),

                padding: EdgeInsets.zero,

                style: const ButtonStyle(

                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                ),

                tooltip: _canConfirmRoofDraft || _canConfirmContour || _canConfirmZone

                    ? context.l10n.architectDimensionFinish

                    : context.l10n.architectDimensionConfirm,

                onPressed: _onConfirmDraft,

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

          // Explicit mode commands increment the epoch. Auto-picking a tool

          // while holding an object must keep the same pointer gesture alive.

          _interactionEpoch,

          _project.id,

          _project.activeStoreyId,

        ),

        singlePointerPan: true,

        holdToEdit:

            _duplicateMove == null &&

            _offsetOptions == null &&

            _effectiveSelection.isNotEmpty &&

            !_multiSelect &&

            !_moveSelection &&

            _wallCutIds.isEmpty &&

            _wallExtendId == null &&

            _wallJoinSourceId == null &&

            _radialMenuScreenPosition == null &&

            _newPointTargetId == null,

        touchHoldToPlace: _canPlaceWithMarker,

        onToolHoldStart: _beginPlacementHold,

        onSelectionHold: _offsetOptions == null && _duplicateMove == null && _newPointTargetId == null

            ? _onSelectionHold

            : null,

        onContextHold: _offsetOptions == null && _duplicateMove == null && _newPointTargetId == null

            ? _onContextHold

            : null,

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

              RepaintBoundary(

                child: AnimatedBuilder(

                  animation: Listenable.merge([_viewport, _previewRevision]),

                  builder: (context, _) => CustomPaint(

                    key: const ValueKey('architect-workspace-projection'),

                    painter: _workspaceProjectionPainter,

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

                              _ when label.endsWith('°') => DxfSnapType.point,

                              _ => DxfSnapType.nearest,

                            };

                      final lastAnchor =

                          _draftStart ??

                          _axisTool.draftStart ??

                          _zoneTool.draftPoints.lastOrNull ??

                          _elementTool.slabDraftPoints.lastOrNull ??

                          _roofTool.draftPoints.lastOrNull ??

                          _mirrorAnchor ??

                          (_splitActive ? _splitPoint1 : null);

                      final liveDim =

                          lastAnchor != null &&

                              (target - lastAnchor).distance > 0.01

                          ? _project.formatLength(

                              (target - lastAnchor).distance,

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

                      decimals: _project.distanceDecimals,

                      dimensionScale: _project.dimensionScale,

                      palette: _canvasPalette,

                      storey: _project.activeStorey,

                      gridAxes: _project.gridAxes,

                      document: _project.document,

                      viewKey: _workspaceViewKey,

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

                                  ? context

                                        .l10n

                                        .architectDimensionEditPointsHint

                                  : _dimensionStyle ==

                                        ArchitectDimensionStyle.interior

                                  ? context.l10n.architectDimensionInteriorHint

                                  : _dimensionChainMode

                                  ? context.l10n.architectDimensionChainHint

                                  : _draftStart == null

                                  ? context.l10n.architectDimensionStartHint

                                  : context.l10n.architectDimensionEndHint)

                            : _mirrorActive

                            ? (_mirrorAnchor == null

                                  ? context.l10n.architectMirrorPromptPickAnchor

                                  : context.l10n.architectMirrorPromptPickAxis)

                            : _splitActive

                            ? (_splitPoint1 == null

                                  ? context

                                        .l10n

                                        .architectWallSplitPromptPickFirst

                                  : (!_splitWaitingForSide

                                        ? context

                                              .l10n

                                              .architectWallSplitPromptPickSecond

                                        : context

                                              .l10n

                                              .architectWallSplitPromptPickSide))

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

                            ? (_activeTool == ArchitectTool.select &&

                                      !_moveSelection

                                  ? context.l10n.architectSelectionCycleHelp

                                  : context.l10n.architectEditHoldHint)

                            : _activeTool == ArchitectTool.select

                            ? context.l10n.architectSelectionCycleHelp

                            : _activeTool == ArchitectTool.column

                            ? context.l10n.architectColumnPlacementHint

                            : _canPlaceWithMarker &&

                                  !_placingWithHold &&

                                  !_wallDirectionLocked

                            ? context.l10n.architectWallDraftHint

                            : _cursorModel == null

                            ? context.l10n.architectNavigationHint

                            : 'X: ${_project.formatLength((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dx)}  '

                                  'Y: ${_project.formatLength((_columnPreviewPoint ?? _draftEnd ?? _cursorModel!).dy)}',

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

            elementBounds: _radialElementBounds,

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

      if (_selectedWallIds.isNotEmpty &&

          _offsetOptions == null &&

          !_mirrorActive &&

          !_splitActive &&

          _radialMenuScreenPosition == null &&

          _newPointTargetId == null)

        Positioned(

          top: 8,

          left: 8,

          right: 8,

          child: Align(

            alignment: Alignment.topLeft,

            child: _buildWallSelectionActions(_selectedWallIds),

          ),

        ),

      _buildWallClearanceOverlay(),

      if (_placingDownpipe)

        Positioned(

          top: 8,

          left: 8,

          right: 8,

          child: Material(

            color: const Color(0xff1e242c),

            borderRadius: BorderRadius.circular(8),

            child: ListTile(

              dense: true,

              title: Text(

                context.l10n.architectDrainagePrompt,

                style: const TextStyle(color: Colors.white),

              ),

              trailing: IconButton(

                tooltip: context.l10n.cancel,

                icon: const Icon(Icons.close, color: Colors.white),

                onPressed: () => setState(_cancelDrafting),

              ),

            ),

          ),

        ),

      if (_cutOpeningTargetId != null)

        Positioned(top: 8, left: 8, right: 8, child: _cutOpeningControl()),

      if (_editingGroupId != null)

        Positioned(top: _offsetOptions == null ? 8 : 64, left: 8, right: 8, child: _groupEditBanner()),

      _buildPolygonDistanceOverlay(),

      _buildShapeDimensionOverlay(),

      if (_activeTool == ArchitectTool.dimension &&

          !_multiSelect &&

          _effectiveSelection.isEmpty)

        Positioned(top: 8, left: 8, right: 8, child: _buildDimensionBar()),

      if (_wallCutIds.isNotEmpty && !_wallCutStroke)

        Positioned(top: 8, left: 8, right: 64, child: _buildCutPromptBanner()),

      if (_splitActive)

        Positioned(

          top: 8,

          left: 8,

          right: 64,

          child: _buildSplitPromptBanner(),

        ),

      if (_newPointTargetId != null)

        Positioned(

          top: 8,

          left: 8,

          right: 64,

          child: _buildNewPointPromptBanner(),

        ),

      if (_activeTool == ArchitectTool.cadRect && _effectiveSelection.isEmpty)

        Positioned(

          top: 8,

          left: 8,

          child: Material(

            color: const Color(0xEE1E242C),

            borderRadius: BorderRadius.circular(8),

            child: Theme(data: ThemeData.dark(), child: _lineStyleControl()),

          ),

        ),

      if (_activeTool == ArchitectTool.select && _effectiveSelection.isEmpty)
        Positioned(top: 8, left: 8, child: _buildSelectControl()),

      if (_activeTool == ArchitectTool.hatch && _effectiveSelection.isEmpty)

        Positioned(top: 8, left: 8, child: _hatchControl()),

      if ((_activeTool == ArchitectTool.floorDrain || _selectedFloorDrain != null) &&

          _effectiveSelection.length <= 1)

        Positioned(top: 8, left: 8, child: _floorDrainControl()),

      if ((_activeTool == ArchitectTool.wall || _activeTool == ArchitectTool.cadLine) && _effectiveSelection.isEmpty)

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

                  child: Column(mainAxisSize: MainAxisSize.min, children: [Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      if (_activeTool == ArchitectTool.cadLine)

                        _lineStyleControl(),

                      if (_activeTool == ArchitectTool.wall)

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

                                        context

                                            .l10n

                                            .architectWallReferenceCenter,

                                      WallReferenceLine.inner =>

                                        context

                                            .l10n

                                            .architectWallReferenceInner,

                                      WallReferenceLine.outer =>

                                        context

                                            .l10n

                                            .architectWallReferenceOuter,

                                      _ =>

                                        context

                                            .l10n

                                            .architectWallReferenceCenter,

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

                      if (_activeTool == ArchitectTool.wall)

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



                      if (_activeTool == ArchitectTool.cadLine || !_wallCurved)

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

                                if (MediaQuery.sizeOf(context).width >=

                                    400) ...[

                                  const SizedBox(width: 8),

                                  Text(context.l10n.architectWallLength),

                                ],

                              ],

                            ),

                          ),

                        ),

                      if (_activeTool == ArchitectTool.wall)

                        IconButton(

                          key: const ValueKey('wall-arc-toggle'),

                          tooltip: context.l10n.wallArc,

                          constraints: const BoxConstraints.tightFor(

                            width: 36,

                            height: 40,

                          ),

                          padding: EdgeInsets.zero,

                          icon: Icon(

                            Icons.rounded_corner,

                            color: _wallCurved

                                ? Colors.cyanAccent

                                : Colors.white70,

                            size: 20,

                          ),

                          onPressed: () {

                            _finishChainedWall();

                            setState(() => _wallCurved = !_wallCurved);

                          },

                        ),

                      if (_wallArcEnd != null) ...[

                        TextButton(

                          key: const ValueKey('wall-arc-radius'),

                          onPressed: _editDraftArcRadius,

                          child: const Text('R='),

                        ),

                        IconButton(

                          key: const ValueKey('wall-arc-confirm'),

                          tooltip: context.l10n.applyAction,

                          onPressed: _commitWallArc,

                          icon: const Icon(

                            Icons.check,

                            color: Colors.cyanAccent,

                          ),

                        ),

                      ],

                      if (_activeTool == ArchitectTool.cadLine || !_wallCurved)

                        IconButton(

                          key: const ValueKey('wall-chain-toggle'),

                          constraints: const BoxConstraints.tightFor(

                            width: 36,

                            height: 40,

                          ),

                          padding: EdgeInsets.zero,

                          tooltip: context.l10n.architectWallChained,

                          onPressed: () => setState(

                            () => _wallMode =

                                _wallMode == WallDraftingMode.chained

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

                  if (_draftGroupChoiceVisible)

                    Theme(data: ThemeData.dark(), child: Row(children: [

                      Checkbox(key: const ValueKey('architect-draft-group'), value: _groupDraftChain,

                        onChanged: (v) => setState(() => _groupDraftChain = v ?? false)),

                      Text(context.l10n.bimGroup),

                      const Spacer(),

                      if (!_wallDirectionLocked)

                        IconButton(key: const ValueKey('architect-draft-group-finish'),

                          tooltip: context.l10n.bimGroupDone,

                          icon: const Icon(Icons.check), onPressed: _finishChainedWall),

                    ])),

                  ]),

                ),

              ),

            ),

          ),

        ),

      if (_activeTool == ArchitectTool.wall &&

          _wallCurved &&

          _effectiveSelection.isEmpty)

        Positioned(

          top: _draftGroupChoiceVisible ? 108 : 60,

          left: 8,

          right: 8,

          child: IgnorePointer(

            child: Align(

              alignment: Alignment.topLeft,

              child: DecoratedBox(

                decoration: BoxDecoration(

                  color: const Color(0xDD1E242C),

                  borderRadius: BorderRadius.circular(5),

                ),

                child: Padding(

                  padding: const EdgeInsets.symmetric(

                    horizontal: 8,

                    vertical: 4,

                  ),

                  child: Text(

                    _draftStart == null

                        ? context.l10n.wallArcPickStart

                        : _wallArcEnd == null

                        ? context.l10n.wallArcPickEnd

                        : context.l10n.wallArcPickThrough,

                    style: const TextStyle(color: Colors.white, fontSize: 12),

                  ),

                ),

              ),

            ),

          ),

        ),

      if (_linearDraftTool)

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

                        decimals: _project.distanceDecimals,

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

      if (!_commands.isPlan &&

          _activeTool == ArchitectTool.select &&

          _effectiveSelection.isEmpty)

        Positioned.fill(child: _nativeProjectionEditor()),

      if (_terrainDrafting)

        Positioned.fill(child: AnimatedBuilder(animation: _viewport,builder: (_, _) {

          final view=_modelCommands.project.elevations.firstWhere((e)=>e.id==_commands.viewId);

          return ArchitectTerrainEditor(initial:view.terrain,

            toView:(p)=>_modelToSection(_screenToModel(p)),

            toScreen:(p)=>_viewport.toScreen(Offset(p.dx,-p.dy)),

            onCancel:()=>setState(()=>_terrainDrafting=false),

            onApply:(points) {

              final original=_modelCommands.project;

              _modelCommands.commit(original.copyWith(elevations:[for(final e in original.elevations)

                if(e.id==view.id) e.copyWith(terrain:points) else e]));

              setState(()=>_terrainDrafting=false);

              _saveBiMProjectIfAttached();

            });

        })),

      if (_viewDraft != null)

        Positioned.fill(

          child: AnimatedBuilder(

            animation: _viewport,

            builder: (_, _) => ArchitectWorkspaceViewPlacement(

              key: ValueKey(_viewDraft),

              controller: _modelCommands,

              type: _viewDraft!.type,

              id: _viewDraft!.id,

              mode: _viewDraft!.mode,

              onNavigate: (delta, factor, focal) => _viewport.navigate(

                previousFocal: focal - delta,

                focal: focal,

                scaleFactor: factor,

              ),

              toModel: _screenToModel,

              toScreen: _viewport.toScreen,

              scale: _viewport.scale,

              onDone: (id) {

                final type = _viewDraft!.type;

                setState(() => _viewDraft = null);

                if (id != null) {

                  _saveBiMProjectIfAttached();

                  _selectWorkspaceView(type, id);

                }

              },

            ),

          ),

        ),

      if (_mirrorActive) ...[
        Positioned.fill(child: AnimatedBuilder(animation: _viewport,
          builder: (_, _) => ArchitectTransformPointInput(
            key: const ValueKey('architect-mirror-input'),
            toModel: _screenToModel, toScreen: _viewport.toScreen,
            snap: (raw, touch) => _snapTransformPoint(raw, touch, anchor: _mirrorAnchor),
            localizeSnap: _localizedSnapLabel,
            onAim: _previewMirrorSnap, onPick: _pickMirrorSnap,
            onNavigate: (delta, factor, focal) => _viewport.navigate(
              previousFocal: focal - delta, focal: focal, scaleFactor: factor),
          ),
        )),
        Positioned(top: 8, left: 8, right: 8, child: _buildMirrorPromptBanner()),
      ],
      if (_offsetOptions != null) ...[
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
          animation: Listenable.merge([_viewport, _previewRevision]),
          builder: (_, _) => CustomPaint(
            key: const ValueKey('architect-offset-direction'),
            painter: _offsetSide == null ? null : ArchitectOffsetDirectionPainter(
              start: _viewport.toScreen(ArchitectOffset.directionAnchor(
                _offsetSource!.activeStorey, _offsetIds, _offsetSide!)),
              side: _viewport.toScreen(_offsetSide!),
              color: _offsetValid ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
            ),
          ),
        ))),
        Positioned(top: 8, left: 8, right: 8, child: _offsetBanner()),
      ],
      if (_rotationSource != null)
        Positioned.fill(child: AnimatedBuilder(animation: _viewport,
          builder: (_, _) => ArchitectRotationOverlay(
            key: ValueKey(_rotationSource), initialPivot: _rotationPivot,
            toModel: _screenToModel, toScreen: _viewport.toScreen,
            snap: (raw, touch, selectionOnly) => _snapTransformPoint(raw, touch, selectionOnly: selectionOnly),
            localizeSnap: _localizedSnapLabel,
            onPreview: _previewRotation, onApply: _applyRotation,
            onNavigate: (delta, factor, focal) => _viewport.navigate(
              previousFocal: focal - delta, focal: focal, scaleFactor: factor),
            onCancel: () { setState(_cancelActiveDrags); _repaintPreview(); },
          ),
        )),
      if (_viewDirectionDraft case final draft?)
        Positioned.fill(child: AnimatedBuilder(animation: _viewport,
          builder: (_, _) => ArchitectViewDirectionPicker(
            key: ValueKey(draft), start: draft.start, end: draft.end,
            toScreen: _viewport.toScreen, onSelected: _commitViewDirection,
            onCancel: () { setState(() => _viewDirectionDraft = null); _repaintPreview(); },
            onNavigate: (delta, factor, focal) => _viewport.navigate(
              previousFocal: focal - delta, focal: focal, scaleFactor: factor),
          ),
        )),
    ],

  );



  void _cancelCadShape() => setState(() {

    _pendingShape = null;

    _shapePanelAnchor = null;

    _draftStart = null;

    _wallArcEnd = null;

    _draftEnd = null;

    _activeMagneticGuides = [];

    _activeSnapLabel = null;

  });



  void _commitCadShape(CadPrimitiveType type) {

    final result = _elementTool.placeCadPrimitive(

      storey: _project.activeStorey,

      type: type,

      lineStyle: type == CadPrimitiveType.rect

          ? _activeCadLineStyle

          : ArchitectLineStyle.solid,

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

                    decimals: _project.distanceDecimals,

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

    if (label == 'Insulation') return l10n.wallLayerInsulation;

    if (label == 'Core') return l10n.wallLayerCore;

    if (label == 'Corner') return l10n.snapCorner;

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

      'Opening edge' => l10n.snapOpeningEdge,

      'Opening center' => l10n.snapOpeningCenter,

      'Step' => l10n.snapModuleStep,

      'Midpoint alignment' => l10n.snapMidpointAlignment,

      'Center' => l10n.snapCenter,

      'Intersection' || 'Axis intersection' => l10n.snapIntersection,

      'Edge' => l10n.snapNearest,

      'Perpendicular' => l10n.snapPerpendicular,

      'Alignment' => l10n.architectWallAlign,

      'Alignment with Point 1' => l10n.snapAlignPoint1,

      '30 cm' => l10n.architectDimensionSnap30cm,

      '40 cm' => l10n.architectDimensionSnap40cm,

      'Door jamb' => l10n.snapDoorJamb,

      'Window jamb' => l10n.snapWindowJamb,

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



  Architect2dPainter _makePainter(

    ArchitectPaintLayer layer,

  ) => Architect2dPainter(

    l10n: context.l10n,

    palette: _canvasPalette,

    paintGrid: _showDrawingGrid,

    showUpperOverhangs: _showUpperOverhangs,

    showFurniture: _showFurnitureLayer,

    componentPreview: _activeTool == ArchitectTool.component && _cursorModel != null

        ? () {

            final activeDef = ComponentLibraryService.instance.activeDefinition;

            final activeParams = ComponentLibraryService.instance.activeParameters;

            final (pos, rot) = _snapComponent(_cursorModel!, activeDef);

            return ArchitectComponentInstance(

              id: "preview",

              definitionId: activeDef.id,

              position: pos,

              rotation: rot,

              parameters: activeParams,

            );

          }()

        : null,

    project: _withDrawingScale(_drawingProject),

    drawingViewKey: _workspaceViewKey,

    viewport: _viewport,

    layer: layer,

    midpointHints: _showMidpointReferences ? _midpointTracking.hints : const [],

    activeTool: _effectiveSelection.isEmpty

        ? _activeTool

        : ArchitectTool.select,

    activeCadLineStyle: _activeCadLineStyle,

    activeHatchPattern: _activeHatchPattern,
    activeHatchColorValue: _activeHatchColor.argb,

    cursorPosition: _cursorModel,

    columnPreview:

        _activeTool == ArchitectTool.column &&

            _effectiveSelection.isEmpty &&

            _columnPreviewPoint != null &&

            !_columnPreviewIsOccupied

        ? ArchitectColumn(

            id: 'preview',

            position: _columnPreviewPoint!,

            width: _elementTool.columnWidth,

            depth: _elementTool.columnDepth,

            shape: _elementTool.columnShape,

            rotationDeg: _columnPreviewRotation,

            label: ArchitectElementTool.nextColumnLabel(

              _project.storeys.expand((s) => s.columns),

            ),

          )

        : null,

    activeDraftStart: _activeTool == ArchitectTool.dimension

        ? null

        : _draftStart,

    activeDraftEnd: _activeTool == ArchitectTool.dimension ? null : _draftEnd,

    stairPreview: _activeTool == ArchitectTool.stair && _draftStart != null

        ? _stairAt(_draftStart!, _draftEnd ?? _draftStart!)

        : null,

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

        return (_wallCutStart! - dir * cutLen, _wallCutStart! + dir * cutLen);

      } else {

        return (_wallCutStart!, pos);

      }

    }(),

    mirrorAnchor: _mirrorActive ? _mirrorAnchor : null,

    mirrorAxisLine: () {

      if (!_mirrorActive || _mirrorAnchor == null) return null;

      final current = _mirrorCurrentPoint ?? _cursorModel;

      if (current == null) return null;

      final delta = current - _mirrorAnchor!;

      if (delta.distanceSquared < 1e-6) return null;

      final dir = delta / delta.distance;

      final span = math.max(120 / _currentScale, 20.0);

      return (_mirrorAnchor! - dir * span, _mirrorAnchor! + dir * span);

    }(),

    splitPoint1: _splitActive ? _splitPoint1 : null,

    splitPerpendicularGuide: _splitActive ? _splitGuidePerpendicular : null,

    splitCutLine: () {

      if (!_splitActive || _splitPoint1 == null) return null;

      if (_splitPoint2 != null) return (_splitPoint1!, _splitPoint2!);

      final pos = _cursorModel;

      if (pos == null || (pos - _splitPoint1!).distanceSquared < 1e-6) {

        return null;

      }

      return (_splitPoint1!, pos);

    }(),

    activeWallInsulation: _activeWallType?.insulationThickness,

    activeWallTypeId: _activeWallType?.id,

    activeWallArcEnd: _wallArcEnd,

    activeWallLayers: _activeWallType?.resolvedLayers ?? const [],

    activeSnapLabel: _localizedSnapLabel(_activeSnapLabel),

    selectedElementId: _selectedElementId,

    selectedElementIds: _effectiveSelection,

    selectedZoneId: _selectedZoneId,

    activeZoneCategory: _activeZoneCategory,

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

    zoneCategoryName: _zonePresets.categoryName(

      _activeZoneCategory,

      context.l10n,

    ),



    zonePreviewRectangle: _zoneTool.previewRectangle,

    zoneEditingPolygon: _zoneMovePreviewPolygon,

    isZoneTableSelected: _isZoneTableSelected,

    selectedZoneTableId: _selectedZoneTableId,

    zoneTableDragPreviewOrigin: _zoneTablePreviewOrigin,



    underlayLayerVisibility: _underlayLayerVisibility,

    slabDraftPoints: _elementTool.slabDraftPoints,

    slabCandidatePoint: _elementTool.slabCandidatePoint,
    marqueePoints: _marqueeTool.points,
    marqueePolygon: _marqueeTool.previewPolygon,

    roofTool: _roofTool,

    polygonEditInvalid: _polygonEditor.invalid,
    polygonEditHoleIndex: _selectedPolygonHoleIndex,

    polygonLeaderLine: _polygonEditor.leaderLine,

    handleOffsetLength: _handleOffsetLength,

    wallEndpointLeaderLine: _wallEndpointLeaderLine,

    wallJoinLeaderLine: _wallJoinLeaderLine,

    newPointCandidate: _newPointCandidate,

    newPointLeaderLine: _newPointLeaderLine,

    activeOvershoot: _activeOvershoot,

  );



  // === SECTION: 3D SOLID VIEWPORT ===



  Widget _build3DViewport() => Architect3dViewport(

    project: _modelCommands.project,

    controller: _camera3D,

  );

}



class _PublicationPreviewPainter extends CustomPainter {

  final ArchitectVectorScene scene;

  final double zoom;

  final Offset translation;

  _PublicationPreviewPainter(this.scene, this.zoom, this.translation);

  @override

  void paint(Canvas canvas, Size size) {

    canvas.clipRect(Offset.zero & size);

    canvas.translate(translation.dx, translation.dy);

    canvas.scale(zoom * scene.denominator / 1000);

    scene.paint(canvas);

  }



  @override

  bool shouldRepaint(covariant _PublicationPreviewPainter old) =>

      old.scene != scene || old.zoom != zoom || old.translation != translation;

}

