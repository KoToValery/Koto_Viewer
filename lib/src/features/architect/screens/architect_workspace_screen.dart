import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import '../services/architect_underlay_service.dart';
import '../services/architect_drag_controller.dart';
import '../services/architect_wall_endpoint_snap.dart';
import '../widgets/architect_wall_angle_control.dart';
import '../services/architect_geodetic_detector.dart';
import '../widgets/architect_underlay_bar.dart';
import '../../bim_projects/services/bim_underlay_picker_helper.dart';
import '../widgets/architect_dialog.dart';
import '../services/architect_column_clearance.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../services/architect_selection_candidates.dart';
import '../widgets/architect_candidate_picker.dart';
import '../widgets/architect_wall_reference_control.dart';
import '../services/architect_interaction_mode.dart';
import '../services/architect_projection_loader.dart';
import '../widgets/architect_projection_status.dart';
import '../services/architect_drafting_seed.dart';
import '../widgets/architect_selection_control.dart';
import '../widgets/architect_selection_move_button.dart';
import '../widgets/architect_selection_action_bar.dart';
import '../widgets/architect_floating_command_overlay.dart';
import '../widgets/architect_canvas_hint.dart';
import '../widgets/architect_curving_edge_overlay.dart';
import '../services/architect_command_preview.dart';
import '../../bim_editing/commands/bim_edit_history.dart';
import '../../../core/services/ui_settings_service.dart';

import '../models/architect_floor_drain.dart';
import '../services/architect_decorative_library_service.dart';
import '../widgets/architect_decorative_drafting_overlay.dart';
import 'decorative_editor_screen.dart';

import '../services/architect_floor_drain_commands.dart';

import '../services/architect_floor_drain_geometry.dart';

import '../widgets/architect_floor_drain_bar.dart';
import '../services/architect_marquee_tool.dart';

import '../rendering/architect_floor_drain_painter_helper.dart';

import '../services/architect_closed_contour.dart';

import '../widgets/architect_terrain_editor.dart';
import '../services/architect_landscape_tool.dart';
import '../widgets/architect_landscape_bar.dart';

import '../models/architect_line_style.dart';

import '../models/architect_hatch_pattern.dart';
import '../models/architect_drawing_color.dart';

import '../widgets/architect_hatch_picker.dart';

import '../services/architect_hatch_patterns.dart';

import '../widgets/architect_line_style_picker.dart';

import '../services/architect_line_styles.dart';

import '../services/architect_line_editing.dart';
import '../services/architect_polyline_editing.dart';
import '../services/architect_chamfer_fillet.dart';
import '../widgets/architect_chamfer_fillet_dialog.dart';
import '../widgets/architect_layers_dialog.dart';
import '../widgets/architect_element_layer_dialog.dart';
import '../widgets/architect_find_and_select_dialog.dart';

import '../services/architect_offset.dart';
import '../services/architect_rotation.dart';
import '../widgets/architect_rotation_overlay.dart';
import '../widgets/architect_hatch_transform_handle.dart';
import '../widgets/architect_transform_point_input.dart';
import '../widgets/architect_offset_direction.dart';

import '../../bim_editing/widgets/bim_offset_dialog.dart';
import '../../bim_editing/geometry/bim_offset_geometry.dart';

import '../services/architect_apartment_zones.dart';

import '../widgets/architect_sheets_screen.dart';

import '../widgets/architect_annotation_settings.dart';

import '../services/architect_drawing_publisher.dart';

import '../rendering/architect_vector_scene.dart';

import '../widgets/architect_wall_types_manager.dart';
import '../widgets/architect_wall_type_label.dart';

import '../widgets/architect_wall_composition_editor.dart';

import '../widgets/architect_wall_arc_dimension_dialog.dart';
import '../widgets/architect_wall_arc_dimension_overlay.dart';
import '../services/architect_wall_arc_editing.dart';
import '../services/architect_new_point_measure.dart';
import '../services/architect_wall_library.dart';
import '../widgets/architect_new_point_overlay.dart';
import '../widgets/architect_new_point_distance_dialog.dart';


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
import '../widgets/architect_storeys_screen.dart';
import '../widgets/architect_copy_storey_dialog.dart';

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
import '../widgets/architect_downpipe_handle.dart';

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
import '../rendering/architect_service_snap.dart';
import '../components/definitions/service_components.dart';

import '../rendering/architect_wall_geometry.dart';

import '../rendering/architect_underlay_painter.dart';

import '../rendering/architect_scene_geometry.dart';

import '../services/architect_command_controller.dart';

import '../services/architect_element_tool.dart';

import '../services/architect_stair_rules.dart';

import '../widgets/architect_stair_properties_dialog.dart';

import '../services/architect_polygon_editor.dart';

import '../services/architect_polygon_dimensions.dart';
import '../services/architect_polygon_displacement.dart';

import '../services/architect_polygon_geometry.dart';

import '../widgets/architect_polygon_distance_overlay.dart';

import '../widgets/architect_shape_dimension_panel.dart';

import '../services/architect_selection.dart';

import '../services/architect_dimension_chain.dart';

import '../rendering/architect_dimension_chain_preview.dart';

import '../widgets/architect_dimension_edit_overlay.dart';

import '../services/architect_wall_relations.dart';

import '../rendering/architect_clearance_badge_layout.dart';
import '../rendering/architect_clearance_obstacles.dart';
import '../rendering/architect_dynamic_dimension_layout.dart';
import '../widgets/architect_dynamic_dimension_painter.dart';

import '../rendering/architect_wall_exterior_painter.dart';
import '../rendering/architect_wall_network.dart';

import '../widgets/architect_element_properties_dialog.dart';
import '../widgets/architect_properties_shell.dart';

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
import '../widgets/architect_zone_presets_dialog.dart';

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
// MASTER ARCHITECT WORKSPACE SCREEN LLM SEARCH INDEX & TABLE OF CONTENTS
// ============================================================================
// COMPANION MAP: See 'architect_workspace_screen.index.md' for reference patterns and symbols.
// QUICK NAV: Use rg -n on a [TAG:...] anchor or concrete class/method name from the companion map.
//
// [SEC-01-WIDGET]   Widget Declaration & Public Api
// [SEC-02-STATE]   [TAG:STATE_FIELDS] State Declarations & Tool Flags
//   ↳ [SUB]        [TAG:UNDERLAY_TOOLS] CAD Xref & Raster Underlay State & Handlers
//   ↳ [SUB]        [TAG:DRAG_TOOL] ARCHITECT 2-POINT SNAP DRAG CONTROLLER
//   ↳ [SUB]        [TAG:UNDERLAY_DRAG] UNDERLAY 2-POINT SNAP DRAG & SELECTION
//   ↳ [SUB]        [TAG:CAD_INSERTION] CAD UNDERLAY INTERACTIVE PLACEMENT
//   ↳ [SUB]        [TAG:ARC_EXACT_PLACEMENT] Chord input, shaping, exact rise, commit
//   ↳ [SUB]        [TAG:WALL_ENDPOINT_ANGLE] Endpoint angle constraint and fine adjustment
//   ↳ [SUB]        [TAG:STATE_LIFECYCLE] Lifecycle: initState & dispose
// [SEC-03-XFORM]   [TAG:XFORM_COORDS] Screen <-> Model Space & Snapping
// [SEC-04-TOUCH]   [TAG:TOUCH_DOWN] _onPointerDown Input Dispatch
//   ↳ [SUB]        [TAG:TOUCH_MOVE] _onPointerMove Input Dispatch & Previews
//   ↳ [SUB]        [TAG:TOUCH_UP] _onPointerUp Input Dispatch & Tool Commits
// [SEC-05-ZONES]   [TAG:ZONE_LOGIC] Zone Updates, Schedules & Presets
// [SEC-06-WALLS]   [TAG:WALL_DRAFT] Wall Concept Drafting & Chain Grouping
// [SEC-07-SPLIT]   [TAG:WALL_SPLIT] Wall Splitting, Cut Sessions & Clearances
// [SEC-08-FENEST]  [TAG:FENEST_RADIAL] Door/Window Placement & Radial Context Menus
//   ↳ [SUB]        [TAG:FLOATING_HUD] Contextual Floating Command Overlays & Interactive Edge Curving
//   ↳ [SUB]        [TAG:CURVING_EXACT_INPUT] Existing element: exact h, side preview, final Apply/Cancel
//   ↳ [SUB]        [TAG:CURVING_FEEDBACK] Compact neutral rise/snap feedback outside edited geometry
//   ↳ [SUB]        [TAG:DRAG_TOOL] ARCHITECT 2-POINT SNAP DRAG METHODS
// [SEC-09-SELECT]  [TAG:SELECTION_BAR] Selection HUD, Action Bars & Layer Modals
//   ↳ [SUB]        [TAG:MIRROR_WORKFLOW] Mirror axis picking, preview and commit
//   ↳ [SUB]        [TAG:FENESTRATION_SELECTION_UPDATES] Live Door & Window Parameter Mutators
//   ↳ [SUB]        [TAG:WALL_OPERATION_AXES] Core-axis corner edits and saved placement references
// [SEC-10-GRIDS]   [TAG:GRID_AXIS] Grid Axes Alignments, Offsets & Numbering
// [SEC-11-LAYOUT]  [TAG:BUILD_LAYOUT] Scaffold, Top/Bottom Bars & Sheet Panels
// [SEC-12-LOGS]    [TAG:LOGGER_UI] Diagnostic Logger Dialog Modal
// [SEC-13-VIEW2D]  [TAG:CANVAS_2D] 2D CustomPainter Canvas, Viewport & Draft Overlays
//   ↳ [SUB]        [TAG:CAD_EXPANSION_COMMITS] CAD EXPANSION COMMITS (ARC, MASK, SPLINE, ELLIPSE, LEADER, ROOF SLOP
// [SEC-14-VIEW3D]  [TAG:VIEW_3D] 3D Solid Viewport & Publication Preview
// ============================================================================

// === SECTION: [SEC-01-WIDGET] WIDGET DECLARATION & PUBLIC API ===

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



// === SECTION: [SEC-02-STATE] STATE & TOOL CONTROLLERS ===
// --- SUBSECTION: [TAG:STATE_FIELDS] State Declarations & Tool Flags ---

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

        frame: _effectiveUnderlayFrame,

        visibility: _effectiveUnderlayLayerVisibility,

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

            icon: const AppIcon(AppIconId.layers, color: Colors.white),

            onSelected: action,

            itemBuilder: (_) => [

              PopupMenuItem(value: 'model', child: AppMenuLabel(
                  icon: AppIconId.view3D,
                  child: Text(l.architectModel),
                ),
              ),

              PopupMenuItem(value: 'sheets', child: AppMenuLabel(
                  icon: AppIconId.file,
                  child: Text(l.architectSheets),
                ),
              ),

              PopupMenuItem(

                value: 'preview',

                enabled: available,

                child: AppMenuLabel(
                  icon: AppIconId.print,
                  child: Text(l.architectPrintPreview),

              ),
              ),

              PopupMenuItem(

                value: 'annotations',

                enabled: available,

                child: AppMenuLabel(
                  icon: AppIconId.properties,
                  child: Text(l.architectAnnotationSettings),
                ),

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

            icon: AppIcon.fromMaterial(_printPreview ? Icons.visibility : Icons.print_outlined,
            ),

          ),

          IconButton(

            color: Colors.white,

            tooltip: l.architectAnnotationSettings,

            onPressed: available ? () => action('annotations') : null,

            icon: const AppIcon(AppIconId.text),

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

        height: ArchitectWorkspaceViewBar.heightFor(context),

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
      _selectWorkspaceView(ArchitectWorkspaceView.plan, _modelCommands.project.activeStoreyId,
      );
      _changeTool(type == ArchitectWorkspaceView.section ? ArchitectTool.section : ArchitectTool.elevation,
        toggle: false,
      );
      return;
    }

    if (mode == 'copy_by_storey') {
      _openCopyStoreyDialog();
      return;
    }

    if (mode == 'visibility' && type == ArchitectWorkspaceView.section) {

      showArchitectSectionVisibility(context, _modelCommands, sectionId: id);

      return;

    }

    if (mode == 'straight') {
      _beginGeometryCommand(ArchitectRadialAction.straighten);

      final p = _modelCommands.project;

      _commands.commit(

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

    if (id != null) {
      _selectionIds..clear()..add(id);
      _selectedElementId = id;
      _beginGeometryCommand(ArchitectRadialAction.edit);
    }
    setState(

      () =>

          _viewDraft = (type: type, id: mode == 'new' ? null : id, mode: mode),

    );

  }



  String? _projectionKey;

  ArchitectBuildingElevation? _facadeGeometry;

  ArchitectBuildingSection? _sectionGeometry;
  String? _pendingProjectionFitKey;

  late final ArchitectProjectionLoader<ArchitectBuildingElevation> _facadeLoader = ArchitectProjectionLoader<ArchitectBuildingElevation>(() {
    if (!mounted) return;
    setState(() => _facadeGeometry = _facadeLoader.data);
    _fitLoadedProjection();
  });

  late final ArchitectProjectionLoader<ArchitectBuildingSection> _sectionLoader = ArchitectProjectionLoader<ArchitectBuildingSection>(() {
    if (!mounted) return;
    setState(() => _sectionGeometry = _sectionLoader.data);
    _fitLoadedProjection();
  });

  void _fitLoadedProjection() {
    if (_projectionFailed) return;
    if (_pendingProjectionFitKey == _workspaceViewKey) {
      _pendingProjectionFitKey = null;
      _initTransform();
    }
  }

  bool get _projectionLoading => _commands.view == ArchitectWorkspaceView.section
      ? _sectionLoader.loading : _commands.view == ArchitectWorkspaceView.elevation && _facadeLoader.loading;

  bool get _projectionFailed => _commands.view == ArchitectWorkspaceView.section
      ? _sectionLoader.failed : _commands.view == ArchitectWorkspaceView.elevation && _facadeLoader.failed;



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

    _sectionLoader.invalidate();
    _facadeLoader.invalidate();
    _projectionSource = null;
    _commands.select(type, id);

    if (type == ArchitectWorkspaceView.plan && id != null) {

      _commands.activateStorey(id);

    }

    setState(() {

      _is3DView = false;

      _activeTool = ArchitectTool.pan;

      _interactionEpoch++;

    });

    final saved = _viewCameras[_workspaceViewKey];
    _pendingProjectionFitKey = (type == ArchitectWorkspaceView.section || type == ArchitectWorkspaceView.elevation) && saved == null
        ? _workspaceViewKey : null;

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

    if (type == ArchitectWorkspaceView.plan) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArchitectStoreysScreen(
            controller: _modelCommands,
            initialSelectedStoreyId: _modelCommands.project.activeStoreyId,
          ),
        ),
      );
      setState(() {});
      return;
    }

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

  Future<void> _openCopyStoreyDialog({Set<String>? selectedElementIds}) async {
    final options = await ArchitectCopyStoreyDialog.show(
      context,
      project: _project,
      initialSourceStoreyId: _project.activeStoreyId,
      selectedElementIds: selectedElementIds,
    );
    if (options != null) {
      final (_, result) =
          ArchitectStoreyCopyService.copyElements(_project, options);
      _modelCommands.execute(CopyArchitectElementsAcrossStoreys(options));
      _saveBiMProjectIfAttached();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.architectCopySuccess(
                result.totalCopied,
                result.targetStoreyCount,
              ),
            ),
            backgroundColor: const Color(0xFF00897B),
          ),
        );
      }
    }
  }



  String? _selectedSectionRoofId;

  double? _sectionRoofDragStartModelY;

  double? _sectionRoofDragInitialOffset;

  double? _sectionRoofDragPreviewOffset;
  ArchitectProject? _roofPreviewBase, _roofPreviewProject;
  (String?, double?)? _roofPreviewKey;
  bool _isDraggingRoofKnuckle = false;
  String? _draggingRoofKnuckleId;
  double? _knuckleDragInitialBreakDist;
  Offset? _knuckleDragStartPoint;



  Offset _modelToSection(Offset rawModel) => Offset(rawModel.dx, -rawModel.dy);



  ArchitectProject? _propertiesModelPreview;

  ArchitectProject get _projectionModelProject {

    final base = _withDrawingScale(_propertiesModelPreview ?? _modelCommands.project,
    );

    if (_selectedSectionRoofId == null ||

        _sectionRoofDragPreviewOffset == null) {

      return base;

    }

    final previewKey = (_selectedSectionRoofId, _sectionRoofDragPreviewOffset);
    if (identical(base, _roofPreviewBase) && previewKey == _roofPreviewKey) {
      return _roofPreviewProject!;
    }
    _roofPreviewBase = base;
    _roofPreviewKey = previewKey;
    return _roofPreviewProject = base.copyWith(

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

        _facadeLoader.ensure(original, _workspaceViewKey,
          () => ArchitectBuildingElevation.buildAsync(original, e),
        );
        _facadeGeometry = _facadeLoader.data;

      }

    } else if (_commands.view == ArchitectWorkspaceView.section) {

      final s = original.sections

          .where((e) => e.id == _commands.viewId)

          .firstOrNull;

      if (s != null) {

        _sectionLoader.ensure(original, _workspaceViewKey,
          () async => (await ArchitectBuildingSection.buildAsync(original, s,
          )).forView(s),
        );
        _sectionGeometry = _sectionLoader.data;

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

      decimals: _project.distanceDecimals, levelUnits: _project.levelUnits, levelDecimals: _project.levelDecimals,

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

      if (_activeTool.isDecorativeTool) {
        return ArchitectDecorativeDraftingOverlay(
          key: ValueKey(
            'workspace-decor-draft:$_workspaceViewKey:${_activeTool.name}',
          ),
          controller: _modelCommands,
          elementTool: _elementTool,
          activeTool: _activeTool,
          paths: paths,
          roofProfiles: _sectionGeometry?.roofProfiles ?? const {},
          elevation: _commands.view == ArchitectWorkspaceView.elevation,
          origin: facade?.centre ?? cut?.drawingOrigin ?? Offset.zero,
          right: facade?.right ?? cut?.drawingRight ?? const Offset(1, 0),
          inward:
              facade?.viewDirection ??
              cut?.viewDirection ??
              const Offset(0, 1),
          scale: _viewport.scale,
          toView: (p) => _modelToSection(_screenToModel(p)),
          toScreen: (p) => _viewport.toScreen(Offset(p.dx, -p.dy)),
          onNavigate: (delta, factor, focal) => _viewport.navigate(
            previousFocal: focal - delta,
            focal: focal,
            scaleFactor: factor,
          ),
          onOpenStudio: () => _openDecorativeStudio(),
        );
      }

      return ArchitectProjectionEditor(
                          onPropertiesPreview: (next) {
                            if (identical(_propertiesModelPreview, next)) return;
                            _propertiesModelPreview = next;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
                          },

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
        onOpenDecorativeStudio: _openDecorativeStudio,

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

    if (tool == ArchitectTool.select || tool == ArchitectTool.pan) return true;

    final storey = _project.activeStorey;

    return switch (tool) {

      ArchitectTool.wall => storey.walls.any((w) => w.id == id),

      ArchitectTool.door =>

        storey.walls.any((w) => w.doors.any((d) => d.id == id),
      ),

      ArchitectTool.window =>

        storey.walls.any((w) => w.windows.any((win) => win.id == id),
      ),

      ArchitectTool.column => storey.columns.any((c) => c.id == id),

      ArchitectTool.beam => storey.beams.any((b) => b.id == id),

      ArchitectTool.slab => storey.slabs.any((s) => s.id == id),

      ArchitectTool.roof =>

        storey.roofs.any((r) => r.id == id) ||

        _project.storeys.any((st) => st.roofs.any((r) => r.id == id)),

      ArchitectTool.opening => storey.openings.any((o) => o.id == id),

      ArchitectTool.stair => storey.stairs.any((s) => s.id == id),

      ArchitectTool.component || ArchitectTool.services => storey.components.any((c) => c.id == id),

      ArchitectTool.dimension => storey.dimensions.any((d) => d.id == id),

      ArchitectTool.level => storey.elevationMarkers.any((e) => e.id == id),

      ArchitectTool.text => storey.annotations.any((a) => a.id == id),

      ArchitectTool.cadLine => storey.cadPrimitives

          .any((p) => p.id == id && (p.type == CadPrimitiveType.line ||
              p.type == CadPrimitiveType.polyline),
      ),

      ArchitectTool.cadRect => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.rect,
      ),

      ArchitectTool.floorDrain => storey.floorDrains.any((d) => d.id == id),

      ArchitectTool.cadCircle => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.circle,
      ),

      ArchitectTool.hatch => storey.cadPrimitives

          .any((p) => p.id == id && p.type == CadPrimitiveType.hatch,
      ),

      ArchitectTool.axis => _project.gridAxes.any((a) => a.id == id),

      ArchitectTool.zone => storey.zones.any((z) => z.id == id),
      ArchitectTool.section => _project.sections.any((s) => s.id == id),
      ArchitectTool.elevation => _project.elevations.any((e) => e.id == id),
      ArchitectTool.decorativeProfile ||
      ArchitectTool.decorativeFrame ||
      ArchitectTool.decorativeArc ||
      ArchitectTool.decorativeVoid ||
      ArchitectTool.decorativeLibrary =>
        storey.decorativeElements.any((d) => d.id == id),

      ArchitectTool.pathway => storey.pathways.any((p) => p.id == id),
      ArchitectTool.street => storey.streets.any((s) => s.id == id),
      ArchitectTool.vegetation => storey.vegetation.any((v) => v.id == id),
      ArchitectTool.siteFence => storey.siteFences.any((f) => f.id == id),
      ArchitectTool.terrain =>
        _project.existingTerrain.boundaries.any((b) => b.id == id) ||
        _project.existingTerrain.contours.any((c) => c.id == id) ||
        _project.existingTerrain.spots.any((s) => s.id == id) ||
        _project.proposedTerrain.boundaries.any((b) => b.id == id) ||
        _project.proposedTerrain.contours.any((c) => c.id == id) ||
        _project.proposedTerrain.spots.any((s) => s.id == id),

      ArchitectTool.contour =>
        _project.existingTerrain.contours.any((c) => c.id == id) ||
        _project.proposedTerrain.contours.any((c) => c.id == id),

      _ => false,

    };

  }



  void _toggleMultiSelection() {
    if (_multiSelect) {
      _changeTool(ArchitectTool.pan, toggle: false);
      return;
    }
    final ids = Set<String>.of(_effectiveSelection);
    final primary = _selectedElementId ?? _selectedZoneId ?? ids.lastOrNull;
    _changeTool(ArchitectTool.select, toggle: false);
    setState(() {
      _multiSelect = true;
      _selectionIds.addAll(ids);
      _selectedElementId = primary;
      _selectedZoneId = _project.activeStorey.zones.any((z) => z.id == primary) ? primary : null;
      _selectionOperation = ArchitectSelectionOperation.add;
    });
  }

  ArchitectSelectionCandidates? _touchCandidates;
  Size _touchViewportSize = Size.zero;

  void _onTouchViewportChanged() {
    final resized = _touchViewportSize != _viewport.size;
    _touchViewportSize = _viewport.size;
    // Adopting a tool can open its inspector and resize the canvas. Keep the
    // model-space snapshot through that layout change; navigation dismisses it.
    if (!resized) _dismissTouchCandidates();
  }

  void _dismissTouchCandidates() {
    if (_touchCandidates != null && mounted) {
      setState(() => _touchCandidates = null);
    }
  }

  List<String> _touchHits(Offset point) {
    final hits = ArchitectSelectionCandidates.planHits(
      _project,
      _elementTool,
      point,
      _currentScale,
      includeComponents: _showFurnitureLayer,
      drawingViewKey: _workspaceViewKey,
      allowed: (id) =>
          (_editingGroup == null || _editingGroup!.elementIds.contains(id)) &&
          (_acceptsAnySelection || _isElementAllowedForTool(id, _activeTool)),
    );
    if (_acceptsAnySelection && _commands.isPlan) {
      if (_currentUnderlayDoc != null &&
          _effectiveUnderlayFrame.rectToModel(_currentUnderlayDoc!.bounds).contains(point)) {
        if (!hits.contains('underlay_cad')) {
          hits.add('underlay_cad');
        }
      }
      for (final r in _project.rasterUnderlaysForStorey(_project.activeStorey.id)) {
        if (r.containsLocalPoint(point)) {
          final id = 'underlay_raster_${r.id}';
          if (!hits.contains(id)) {
            hits.add(id);
          }
        }
      }
    }
    return hits;
  }

  bool _candidateSelected(String id) {
    final members = _commands.isPlan && _editingGroupId == null
        ? _project.activeStorey.expandGroups({id})
        : {id};
    return members.every(_effectiveSelection.contains);
  }

  bool _candidateWillRemove(String id) => _explicitSelectionOperation
      ? _selectionOperation == ArchitectSelectionOperation.remove
      : _candidateSelected(id);

  void _chooseTouchCandidate(int index) {
    final session = _touchCandidates;
    if (session == null) return;
    final next = session.at(index);
    setState(() => _touchCandidates = next);
    if (!_multiSelect) {
      _applySelectionId(next.current, next.point, direct: true);
    }
  }

  void _applyTouchCandidate() {
    final session = _touchCandidates;
    if (session == null) return;
    _applySelectionId(
      session.current,
      session.point,
      toggle: true,
      direct: true,
    );
  }

  Widget _buildTouchCandidatePicker() {
    final session = _touchCandidates!;
    return ArchitectCandidatePicker(
      labels: architectCandidateLabels(context, _project, session.ids),
      index: session.index,
      onIndex: _chooseTouchCandidate,
      onApply: _multiSelect ? _applyTouchCandidate : null,
      isSelected: _candidateSelected,
      willRemove: _candidateWillRemove,
      trailing: MediaQuery.sizeOf(context).width < 600 && _showSelectionActions
          ? _buildSelectionBar(menuOnly: true) : null,
    );
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
        if (_currentUnderlayDoc != null &&
            _effectiveUnderlayFrame.rectToModel(_currentUnderlayDoc!.bounds).contains(point))
          'underlay_cad',
        for (final r in _project.rasterUnderlaysForStorey(_project.activeStorey.id))
          if (r.containsLocalPoint(point))
            'underlay_raster_${r.id}',
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
      applyDraftingDefaults: true,
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

      storey: _project.activeStorey);

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

      builder: (context) => architectAlertDialog(

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

      builder: (context) => architectAlertDialog(

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



  ArchitectInteractionMode _interactionMode =
      ArchitectInteractionMode.navigation;
  ArchitectTool _tool = ArchitectTool.pan;
  ArchitectTool get _activeTool => _tool;
  set _activeTool(ArchitectTool tool) {
    if (_tool != tool) _wallReferenceManual = false;
    if (_draftingSeed != null && _draftingSeed!.tool != tool) {
      _draftingSeed = null;
      _quickDrawingTool = null;
    }
    _tool = tool;
    _interactionMode = tool == ArchitectTool.pan
        ? ArchitectInteractionMode.navigation
        : tool == ArchitectTool.select
        ? (_multiSelect
              ? ArchitectInteractionMode.multiSelect
              : ArchitectInteractionMode.singleSelect)
        : ArchitectInteractionMode.drawing;
  }

  ArchitectDraftingSeed? _draftingSeed;
  ArchitectTool? _quickDrawingTool;
  bool get _manualSelection => _interactionMode.isManualSelection;
  bool get _canAdoptPickedTool =>
      _interactionMode == ArchitectInteractionMode.navigation ||
      _interactionMode == ArchitectInteractionMode.contextEdit;
  ArchitectTool? get _selectionDrawingTool {
    final ids = _effectiveSelection;
    if (ids.length != 1 || _selectedGroup != null) return null;
    final tool = ArchitectDraftingSeed.toolFor(_project, ids.single);
    if (!_commands.isPlan &&
        tool != null &&
        !{
          ArchitectTool.dimension,
          ArchitectTool.level,
          ArchitectTool.text,
          ArchitectTool.cadLine,
          ArchitectTool.cadRect,
          ArchitectTool.cadCircle,
          ArchitectTool.hatch,
        }.contains(tool)) {
      return null;
    }
    if (tool?.usesComponent == true) {
      final component = _project.activeStorey.components.where((c) => c.id == ids.single).firstOrNull;
      if (component == null || ComponentLibraryService.instance.findDefinition(component.definitionId,
              ) == null) {
        return null;
      }
    }
    return tool;
  }

  void _startDrawingFromSelection() {
    if (_interactionMode == ArchitectInteractionMode.drawing &&
        _quickDrawingTool != null) {
      _changeTool(ArchitectTool.pan, toggle: false);
      return;
    }
    final tool = _selectionDrawingTool;
    if (tool == null) return;
    final seed = ArchitectDraftingSeed.fromSelection(
      _project,
      _effectiveSelection.single,
    );
    if (seed == null) return;
    _changeTool(tool, toggle: false);
    setState(() {
      _draftingSeed = seed;
      _quickDrawingTool = tool;
      final json = seed.values;
      switch (tool) {
        case ArchitectTool.wall:
          final wall = ArchitectWall.fromJson(json);
          final type = _project.wallTypes
              .where((t) => t.id == wall.wallTypeId)
              .firstOrNull;
          _wallPreferenceChanged = true;
          _activeWallType = ArchitectWallType(
            id: wall.wallTypeId ?? _activeWallType?.id ?? 'int_12_partition',
            name: type?.name ?? '',
            labelId: type?.labelId,
            usage: wall.isParapet
                ? WallUsage.parapet
                : wall.isExterior
                ? WallUsage.exterior
                : WallUsage.interior,
            totalThickness: wall.thickness,
            insulationThickness: wall.insulationThickness,
            layers: wall.resolvedLayers,
            system: wall.system,
            location: wall.location,
            customHeight: wall.height,
            parapetFinish: wall.parapetFinish,
            railing: wall.railing,
          );
          _wallThickness = wall.thickness;
          _wallReference = wall.referenceLine;
          _wallExteriorSide = wall.exteriorSide;
          _wallCurved = wall.isCurved;
          break;
        case ArchitectTool.door:
          final door = ArchitectDoor.fromJson(json);
          _doorWidth = door.width;
          _doorHeight = door.height;
          _doorSill = door.sillHeight;
          _isHingeLeft = door.isHingeLeft;
          _elementTool.activeDoorStyle =
              door.style ??
              FenestrationLibraryService.instance.getStyleById(
                door.styleId ?? '',
              );
          break;
        case ArchitectTool.window:
          final window = ArchitectWindow.fromJson(json);
          _elementTool.windowWidth = window.width;
          _elementTool.windowHeight = window.height;
          _elementTool.windowSill = window.sillHeight;
          _elementTool.activeWindowStyle =
              window.style ??
              FenestrationLibraryService.instance.getStyleById(
                window.styleId ?? '',
              );
          break;
        case ArchitectTool.column:
          final column = ArchitectColumn.fromJson(json);
          _elementTool.columnShape = column.shape;
          _elementTool.columnWidth = column.width;
          _elementTool.columnDepth = column.depth;
          _columnPreviewRotation = column.rotationDeg;
          break;
        case ArchitectTool.beam:
          final beam = ArchitectBeam.fromJson(json);
          _elementTool.beamWidth = beam.width;
          _elementTool.beamDepth = beam.depth;
          break;
        case ArchitectTool.stair:
          final stair = ArchitectStair.fromJson(json);
          _elementTool.stairWidth = stair.width;
          _elementTool.stairSteps = stair.stepCount;
          _elementTool.stairDesign = stair.design ?? _elementTool.stairDesign;
          break;
        case ArchitectTool.opening:
          _elementTool.openingType = ArchitectOpening.fromJson(json).type;
          break;
        case ArchitectTool.roof:
          final roof = ArchitectRoofPlane.fromJson(json);
          _roofTool.slopeDegrees = roof.slopeDegrees;
          _roofTool.upperSlopeDegrees = roof.upperSlopeDegrees;
          _roofTool.breakDistance = roof.breakDistance;
          _roofTool.eavesOverhang = roof.eavesOverhang;
          _roofTool.manualSupportDistance = roof.manualSupportDistance;
          _roofTool.eavesCut = roof.eavesCut;
          _roofTool.attachToWalls = roof.attachToWalls;
          _roofTool.baseElevationOffset = roof.baseElevationOffset;
          _roofTool.activeAssembly = roof.assembly;
          _roofTool.drainage = roof.drainage.copyWith(downpipes: const []);
          _roofTool.drawMode = roof.isMansard
              ? RoofDrawMode.mansard
              : RoofDrawMode.polygon;
          break;
        case ArchitectTool.zone:
          final zone = ArchitectZone.fromJson(json);
          _activeZoneCategory = zone.category;
          _activeZoneKind = zone.kind;
          break;
        case ArchitectTool.component:
        case ArchitectTool.services:
          final component = ArchitectComponentInstance.fromJson(json);
          final library = ComponentLibraryService.instance;
          final definition = library.findDefinition(component.definitionId);
          if (definition != null) {
            library.setActiveDefinition(
              definition,
              parameters: component.parameters,
            );
          }
          _componentRotation = component.rotation;
          break;
        case ArchitectTool.dimension:
          final dimension = ArchitectDimension.fromJson(json);
          _dimensionStyle = dimension.style;
          _dimensionChainMode = dimension.isChain;
          _dimensionOffset = dimension.offsetDistance;
          _dimensionShowOverall = dimension.showOverall;
          break;
        case ArchitectTool.hatch:
          final hatch = ArchitectCadPrimitive.fromJson(json);
          _activeHatchPattern = hatch.hatchPattern;
          _activeHatchColor = ArchitectDrawingColor(
            hatch.colorValue,
            presetId: hatch.colorPresetId,
          );
          _automaticHatch = false;
          break;
        case ArchitectTool.cadLine:
          _cadPolylineMode = json['type'] == CadPrimitiveType.polyline.name;
          _activeCadLineStyle = ArchitectCadPrimitive.fromJson(json).lineStyle;
          break;
        case ArchitectTool.cadRect:
        case ArchitectTool.cadCircle:
          _activeCadLineStyle = ArchitectCadPrimitive.fromJson(json).lineStyle;
          break;
        case ArchitectTool.floorDrain:
          final drain = ArchitectFloorDrain.fromJson(json);
          _drainShape = drain.shape;
          _drainSize = drain.size;
          _drainWidth = drain.width;
          _drainSlopePercent = drain.slopePercent;
          _drainFromRoom = false;
          break;
        default:
          break;
      }
    });
  }

  void _restorePickedTool([String? id]) {
    if (_manualSelection) return;
    _activeTool = id == null
        ? ArchitectTool.pan
        : ArchitectDraftingSeed.toolFor(_project, id) ?? ArchitectTool.pan;
    if (id != null || _selectionIds.isNotEmpty) {
      _selectionContextActive = true;
    }
  }

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



  Future<void> _saveZonePresets(ArchitectZonePresets presets) async {
    _zonePresets = presets;
    await _saveWorkspacePreferences();
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
          structuralScheme: _project.structuralScheme,
          perimeterBeamDepth: _project.perimeterBeamDepth,

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

    final schemeChanged = result.structuralScheme != _project.structuralScheme;
    final beamDepthChanged =
        (result.perimeterBeamDepth - _project.perimeterBeamDepth).abs() > 1e-4;
    if (schemeChanged || beamDepthChanged) {
      setState(() {
        _project = _project.copyWith(
          structuralScheme: result.structuralScheme,
          perimeterBeamDepth: result.perimeterBeamDepth,
        );
      });
      if (schemeChanged) {
        _applyStructuralSchemeDefaults(result.structuralScheme);
      }
    }

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

    setState(() {
      _touchCandidates = null;
      _is3DView = !_is3DView;
    });

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
  Offset? _pendingZoneTableOrigin;
  Offset? _originalZoneTableOrigin;



  // Zone placement controller; contour editing uses the common polygon editor

  late final ArchitectZoneTool _zoneTool;



  // Unified tool controller for dynamic grid axes

  late final ArchitectGridAxisTool _axisTool;



  // Unified tool controller for architectural elements (windows, columns, beams, slabs, etc.)

  late final ArchitectElementTool _elementTool;



  // Unified tool controller for roof planes, auto-roof generation, and carpentry

  late final ArchitectRoofTool _roofTool;
  late final ArchitectLandscapeTool _landscapeTool;



  // --- SUBSECTION: [TAG:UNDERLAY_TOOLS] CAD Xref & Raster Underlay State & Handlers ---
  // Underlays
  Map<String, DxfDocument> _underlaysByStorey = {};
  final Map<String, bool> _underlayLayerVisibility = {};
  bool _showUnderlay = true;
  bool _underlayBusy = false;
  String? _underlayBusyMessage;
  ArchitectCadFileWatcher? _cadFileWatcher;
  final Map<String, ui.Image> _rasterImages = {};
  String? _selectedRasterId;
  int _rasterCalibrationStep = 0; // 0 = idle, 1 = pick P1, 2 = pick P2
  Offset? _rasterCalibrationP1;
  Offset? _rasterCalibrationP2;
  String? _draggingRasterId;
  Offset? _rasterDragStartModel;
  Offset? _rasterDragOriginalPos;
  bool _underlayMaskDrafting = false;
  String _underlayMaskMode = 'rect'; // 'rect' or 'polygon'
  bool _underlayMaskTargetIsCad = true;
  String? _underlayMaskTargetRasterId;
  List<Offset> _underlayMaskPoints = [];
  Offset? _underlayMaskDraftStart;

  // --- SUBSECTION: [TAG:DRAG_TOOL] ARCHITECT 2-POINT SNAP DRAG CONTROLLER ---
  final ArchitectDragController _dragController = ArchitectDragController();
  // A released target stays frozen for review until another canvas pick.
  bool _dragTargetPlaced = false;
  Offset _dragPointerOffset = Offset.zero;

  // --- SUBSECTION: [TAG:UNDERLAY_DRAG] UNDERLAY 2-POINT SNAP DRAG & SELECTION ---
  // Underlays use the shared [_dragController] so their gesture, preview,
  // confirmation, and cancellation lifecycle stays identical to element drag.
  bool _isCadUnderlaySelected = false;

  // --- SUBSECTION: [TAG:CAD_INSERTION] CAD UNDERLAY INTERACTIVE PLACEMENT ---
  bool _cadInsertionActive = false;
  Offset? _cadInsertionControlPoint;
  Offset? _cadInsertionPendingPoint;
  Offset? _cadInsertionHoverPoint;
  DxfDocument? _cadInsertionDoc;
  double _cadInsertionUnitsPerMeter = 1.0;
  ArchitectCadUnderlayConfig? _cadInsertionConfig;

  BimCoordinateFrame? get _ghostUnderlayFrame {
    if (_dragController.isDraggingToTarget && _dragController.isCadUnderlay) {
      return _dragController.ghostCadFrame;
    }
    if (!_cadInsertionActive || _cadInsertionControlPoint == null) return null;
    final target = _cadInsertionPendingPoint ??
        _cadInsertionHoverPoint ??
        _cursorModel ??
        Offset.zero;
    final scale =
        _cadInsertionUnitsPerMeter > 0 ? _cadInsertionUnitsPerMeter : 1.0;
    final origin = _cadInsertionControlPoint! - target * scale;
    return BimCoordinateFrame(origin: origin, unitsPerMeter: scale);
  }

  double _componentRotation = 0.0;
  bool _showFurnitureLayer = true;

  void toggleFurnitureLayer() => setState(() {
    _touchCandidates = null;
    _showFurnitureLayer = !_showFurnitureLayer;
  });

  ArchitectCadUnderlayConfig? get _currentCadUnderlayConfig =>
      _project.cadUnderlayForStorey(_project.activeStorey.id);

  BimCoordinateFrame get _effectiveUnderlayFrame {
    final cfg = _currentCadUnderlayConfig;
    if (cfg != null && cfg.hasLockedOrigin) {
      return BimCoordinateFrame(
        origin: Offset(cfg.lockedCadOriginX!, cfg.lockedCadOriginY!),
        unitsPerMeter: cfg.unitsPerMeter ?? 1.0,
      );
    }
    if (cfg != null && cfg.unitsPerMeter != null && cfg.unitsPerMeter! > 0) {
      return BimCoordinateFrame(
        origin: Offset.zero,
        unitsPerMeter: cfg.unitsPerMeter!,
      );
    }
    return widget.underlayFrame;
  }

  Map<String, bool> get _effectiveUnderlayLayerVisibility {
    final cfg = _currentCadUnderlayConfig;
    if (cfg != null && cfg.hiddenDxfLayers.isNotEmpty) {
      return {
        ..._underlayLayerVisibility,
        for (final hidden in cfg.hiddenDxfLayers) hidden: false,
      };
    }
    return _underlayLayerVisibility;
  }

  DxfDocument? get _currentUnderlayDoc {
    if (!_showUnderlay || !_commands.isPlan) return null;
    if (!_project.isLayerVisible(ArchitectLayer.cadUnderlayLayerId)) {
      return null;
    }
    final cfg = _currentCadUnderlayConfig;
    if (cfg != null && !cfg.visible) return null;
    return _underlaysByStorey[_project.activeStorey.id];
  }

  ArchitectRasterUnderlay? get _selectedRasterUnderlay {
    final list = _project.rasterUnderlaysForStorey(_project.activeStorey.id);
    if (list.isEmpty) return null;
    if (_selectedRasterId != null) {
      for (final item in list) {
        if (item.id == _selectedRasterId) return item;
      }
    }
    return list.last;
  }

  Future<void> _restorePersistedUnderlays() async {
    _cadFileWatcher ??= ArchitectCadFileWatcher(
      onExternalFileModified: _onExternalCadModified,
    );
    _cadFileWatcher!.updateConfigs(_project.cadUnderlays);
    final projId = widget.bimProject?.id ?? (_project.id.isNotEmpty ? _project.id : null);
    for (final entry in _project.cadUnderlays.entries) {
      final storeyId = entry.key;
      final cfg = entry.value;
      if (!_underlaysByStorey.containsKey(storeyId)) {
        final doc = await ArchitectUnderlayService.instance
            .loadSavedCadUnderlay(cfg, projectId: projId);
        if (doc != null && mounted) {
          setState(() {
            _underlaysByStorey[storeyId] = doc;
            for (final layerName in doc.layers.keys) {
              _underlayLayerVisibility.putIfAbsent(
                layerName,
                () => !cfg.hiddenDxfLayers.contains(layerName),
              );
            }
          });
        }
      }
    }
    if (widget.bimProject != null && projId != null) {
      for (final s in widget.bimProject!.storeys) {
        if (s.hasUnderlay && !_underlaysByStorey.containsKey(s.storeyId)) {
          try {
            final doc = await BimProjectLibraryService.instance.loadUnderlay(projId, s);
            if (mounted) {
              setState(() {
                _underlaysByStorey[s.storeyId] = doc;
                for (final layerName in doc.layers.keys) {
                  _underlayLayerVisibility.putIfAbsent(layerName, () => true);
                }
              });
            }
          } catch (e) {
            debugPrint('[ArchitectWorkspace] Failed to restore storey underlay: $e');
          }
        }
      }
    }
    for (final raster in _project.rasterUnderlays) {
      if (!_rasterImages.containsKey(raster.id) &&
          raster.internalImagePath.isNotEmpty) {
        final img = await ArchitectUnderlayService.instance
            .loadSavedRasterImage(raster);
        if (img != null && mounted) {
          setState(() {
            _rasterImages[raster.id] = img;
          });
        }
      }
    }
  }

  Future<void> _importOrReplaceCadUnderlay() async {
    if (_underlayBusy) return;
    try {
      final file = await BimUnderlayPickerHelper.pickCadUnderlayFile(context);
      if (file == null || !mounted) return;
      final isDwg = file.path.toLowerCase().endsWith('.dwg');
      setState(() {
        _underlayBusy = true;
        _underlayBusyMessage = isDwg
            ? context.l10n.convertingDwg
            : context.l10n.bimProjectConvertingUnderlay;
      });
      await _loadExternalCadFileForStorey(
        storeyId: _project.activeStorey.id,
        sourceFile: file,
        isAutoReload: false,
      );
    } catch (e, stack) {
      debugPrint('[ArchitectWorkspaceScreen] pickCadUnderlay error: $e\n$stack');
      if (mounted) {
        setState(() {
          _underlayBusy = false;
          _underlayBusyMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectUnderlayLoadError(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadExternalCadFileForStorey({
    required String storeyId,
    required File sourceFile,
    required bool isAutoReload,
  }) async {
    if (!mounted) return;
    final isDwg = sourceFile.path.toLowerCase().endsWith('.dwg');
    setState(() {
      _underlayBusy = true;
      _underlayBusyMessage = isDwg
          ? context.l10n.convertingDwg
          : context.l10n.bimProjectConvertingUnderlay;
    });
    try {
      final existingCfg = _project.cadUnderlays[storeyId];
      final importRes = await ArchitectUnderlayService.instance
          .importOrReloadCadUnderlay(
            projectId: widget.bimProject?.id ?? _project.name,
            storeyId: storeyId,
            sourceFile: sourceFile,
            existingConfig: existingCfg,
            existingSurvey: _project.geodeticSurvey,
            preserveExistingOrigin: existingCfg?.lockOrigin ?? true,
          );
      if (!mounted) return;

      final doc = importRes.document;
      final nextCfg = importRes.config;
      final detection = importRes.geodeticResult;

      final updatedUnderlays = Map<String, ArchitectCadUnderlayConfig>.from(
        _project.cadUnderlays,
      )..[storeyId] = nextCfg;

      _cadFileWatcher ??= ArchitectCadFileWatcher(
        onExternalFileModified: _onExternalCadModified,
      );
      _cadFileWatcher!.updateConfigs(updatedUnderlays);

      setState(() {
        _underlaysByStorey[storeyId] = doc;
        for (final layerName in doc.layers.keys) {
          _underlayLayerVisibility[layerName] = !nextCfg.hiddenDxfLayers
              .contains(layerName);
        }
        _commands.commit(
          _project.copyWith(
            cadUnderlays: updatedUnderlays,
            geodeticSurvey: detection.hasTopography
                ? detection.survey
                : _project.geodeticSurvey,
          ),
        );
        _underlayBusy = false;
        _underlayBusyMessage = null;
      });
      _saveBiMProjectIfAttached();

      if (!isAutoReload && existingCfg == null) {
        _initTransform();
      }

      if (mounted) {
        final l10n = context.l10n;
        final String message;
        if (isAutoReload) {
          message = l10n.architectCadUnderlayReloadedNotice(nextCfg.fileName);
        } else if (detection.hasTopography) {
          message = l10n.architectGeodesyDetectedNotice(
            detection.coordinateSystem.name,
            detection.contours.length,
            detection.spotElevations.length,
          );
        } else {
          message = l10n.architectCadUnderlayLoadedSuccess(nextCfg.fileName);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
        if (!isAutoReload) {
          setState(() {
            _isCadUnderlaySelected = true;
            _selectedRasterId = null;
            _selectionIds.clear();
            _selectedElementId = null;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('[ArchitectWorkspaceScreen] _loadExternalCadFileForStorey error: $e\n$stack');
      if (mounted) {
        setState(() {
          _underlayBusy = false;
          _underlayBusyMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectUnderlayLoadError(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted && _underlayBusy) {
        setState(() {
          _underlayBusy = false;
          _underlayBusyMessage = null;
        });
      }
    }
  }

  void _onExternalCadModified(String storeyId, File externalFile) {
    if (!mounted) return;
    unawaited(
      _loadExternalCadFileForStorey(
        storeyId: storeyId,
        sourceFile: externalFile,
        isAutoReload: true,
      ),
    );
  }

  void _toggleCadAutoReload(bool value) {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final updated = cfg.copyWith(autoReload: value);
    final map = Map<String, ArchitectCadUnderlayConfig>.from(
      _project.cadUnderlays,
    )..[cfg.storeyId] = updated;
    _cadFileWatcher ??= ArchitectCadFileWatcher(
      onExternalFileModified: _onExternalCadModified,
    );
    _cadFileWatcher!.updateConfigs(map);
    setState(() {
      _commands.commit(_project.copyWith(cadUnderlays: map));
    });
    _saveBiMProjectIfAttached();
  }

  void _toggleCadOriginLock(bool value) {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final updated = cfg.copyWith(lockOrigin: value);
    final map = Map<String, ArchitectCadUnderlayConfig>.from(
      _project.cadUnderlays,
    )..[cfg.storeyId] = updated;
    setState(() {
      _commands.commit(_project.copyWith(cadUnderlays: map));
    });
    _saveBiMProjectIfAttached();
  }

  Future<void> _reloadCurrentCadUnderlayNow() async {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final extPath = cfg.externalSourcePath;
    final sourceFile = (extPath != null && File(extPath).existsSync())
        ? File(extPath)
        : File(cfg.internalCopyPath);
    if (!sourceFile.existsSync()) return;
    await _loadExternalCadFileForStorey(
      storeyId: cfg.storeyId,
      sourceFile: sourceFile,
      isAutoReload: true,
    );
  }

  Future<void> _repositionCurrentCadUnderlay() async {
    final storeyId = _project.activeStorey.id;
    final cfg = _project.cadUnderlays[storeyId];
    final doc = _underlaysByStorey[storeyId];
    if (cfg == null || doc == null) return;
    _startUnderlaySnapDrag(isCad: true);
  }

  void _confirmCadInsertion() {
    if (!_cadInsertionActive ||
        _cadInsertionControlPoint == null ||
        _cadInsertionPendingPoint == null) {
      return;
    }
    final scale =
        _cadInsertionUnitsPerMeter > 0 ? _cadInsertionUnitsPerMeter : 1.0;
    final newOriginX =
        _cadInsertionControlPoint!.dx - _cadInsertionPendingPoint!.dx * scale;
    final newOriginY =
        _cadInsertionControlPoint!.dy - _cadInsertionPendingPoint!.dy * scale;

    final storeyId = _project.activeStorey.id;
    final cfg = _project.cadUnderlays[storeyId] ?? _cadInsertionConfig;
    if (cfg != null) {
      final updated = cfg.copyWith(
        lockedCadOriginX: newOriginX,
        lockedCadOriginY: newOriginY,
        unitsPerMeter: scale,
        lockOrigin: true,
      );
      final map =
          Map<String, ArchitectCadUnderlayConfig>.from(_project.cadUnderlays)
            ..[storeyId] = updated;

      setState(() {
        _commands.commit(_project.copyWith(cadUnderlays: map));
        _cadInsertionActive = false;
        _cadInsertionControlPoint = null;
        _cadInsertionPendingPoint = null;
        _cadInsertionHoverPoint = null;
        _cadInsertionDoc = null;
        _cadInsertionConfig = null;
      });
      _saveBiMProjectIfAttached();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectUnderlayPlacedSuccess),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelCadInsertion() {
    setState(() {
      _cadInsertionActive = false;
      _cadInsertionControlPoint = null;
      _cadInsertionPendingPoint = null;
      _cadInsertionHoverPoint = null;
      _cadInsertionDoc = null;
      _cadInsertionConfig = null;
    });
  }

  void _startUnderlaySnapDrag({required bool isCad, String? rasterId}) async {
    _discardGeometryCommand();
    _cancelActiveDrags();
    final storeyId = _project.activeStorey.id;
    if (isCad) {
      var cfg = _currentCadUnderlayConfig;
      var doc = _currentUnderlayDoc;
      if (doc == null && cfg != null) {
        final projId = widget.bimProject?.id ?? (_project.id.isNotEmpty ? _project.id : null);
        final loaded = await ArchitectUnderlayService.instance.loadSavedCadUnderlay(cfg, projectId: projId);
        if (loaded != null && mounted) {
          setState(() => _underlaysByStorey[storeyId] = loaded);
          doc = loaded;
        }
      }
      if (doc == null && widget.bimProject != null) {
        final storey = widget.bimProject!.storeys.where((s) => s.storeyId == storeyId).firstOrNull;
        if (storey != null && storey.hasUnderlay) {
          try {
            final loaded = await BimProjectLibraryService.instance.loadUnderlay(widget.bimProject!.id, storey);
            if (mounted) {
              setState(() => _underlaysByStorey[storeyId] = loaded);
              doc = loaded;
            }
          } catch (_) {}
        }
      }
      if (cfg == null && doc != null) {
        cfg = ArchitectCadUnderlayConfig(
          storeyId: storeyId,
          fileName: 'underlay.kcad',
          internalCopyPath: '',
        );
      }
      if (cfg == null || doc == null) return;
      final currentOrigin = cfg.hasLockedOrigin
          ? Offset(cfg.lockedCadOriginX!, cfg.lockedCadOriginY!)
          : _effectiveUnderlayFrame.origin;
      final defaultAnchor = _effectiveUnderlayFrame.toModel(doc.bounds.center);
      _dragController.startDrag(
        isUnderlay: true,
        isCadUnderlay: true,
        underlayName: cfg.fileName,
        storeyId: storeyId,
        unitsPerMeter: cfg.unitsPerMeter ?? 1.0,
        originalCadOrigin: currentOrigin,
        defaultAnchor: defaultAnchor,
        handleOffsetLength: _handleOffsetLength,
        zoomScale: _currentScale,
      );
      _dragTargetPlaced = false;
      setState(() {
        _isCadUnderlaySelected = true;
        _selectedRasterId = null;
        _selectionIds.clear();
        _selectedElementId = null;
      });
    } else {
      final raster = _selectedRasterUnderlay ??
          _project.rasterUnderlaysForStorey(storeyId).where((r) => r.id == rasterId).firstOrNull;
      if (raster == null || raster.locked) return;
      final defaultAnchor = raster.localBounds.center;
      _dragController.startDrag(
        isUnderlay: true,
        isCadUnderlay: false,
        rasterId: raster.id,
        underlayName: raster.fileName,
        storeyId: storeyId,
        unitsPerMeter: 1.0,
        originalRasterPosition: raster.position,
        defaultAnchor: defaultAnchor,
        handleOffsetLength: _handleOffsetLength,
        zoomScale: _currentScale,
      );
      _dragTargetPlaced = false;
      setState(() {
        _selectedRasterId = raster.id;
        _isCadUnderlaySelected = false;
        _selectionIds.clear();
        _selectedElementId = null;
      });
    }
  }

  void _openCadDxfLayersSheet() {
    final doc = _underlaysByStorey[_project.activeStorey.id];
    final cfg = _currentCadUnderlayConfig;
    if (doc == null || doc.layers.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E242C),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final vis = _effectiveUnderlayLayerVisibility;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const AppIcon(
                          AppIconId.layers,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.architectCadUnderlayLayersFilter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Builder(
                      builder: (_) {
                        final layerNames = doc.layers.keys.toList();
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: layerNames.length,
                          itemBuilder: (_, idx) {
                            final layerName = layerNames[idx];
                            final isOn = vis[layerName] ?? true;
                            return SwitchListTile(
                              dense: true,
                              title: Text(
                                layerName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              value: isOn,
                              activeThumbColor: Colors.cyanAccent,
                              onChanged: (next) {
                                setState(() {
                                  _underlayLayerVisibility[layerName] = next;
                                  if (cfg != null) {
                                    final nextHidden = Set<String>.from(
                                      cfg.hiddenDxfLayers,
                                    );
                                    if (next) {
                                      nextHidden.remove(layerName);
                                    } else {
                                      nextHidden.add(layerName);
                                    }
                                    final map =
                                        Map<
                                          String,
                                          ArchitectCadUnderlayConfig
                                        >.from(_project.cadUnderlays)
                                          ..[cfg.storeyId] = cfg.copyWith(
                                            hiddenDxfLayers: nextHidden,
                                          );
                                    _commands.commit(
                                      _project.copyWith(cadUnderlays: map),
                                    );
                                  }
                                });
                                setSheetState(() {});
                                _saveBiMProjectIfAttached();
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _extractGeodesyFromCurrentUnderlay() {
    final storeyId = _project.activeStorey.id;
    final doc = _underlaysByStorey[storeyId];
    if (doc == null) return;
    final cfg = _currentCadUnderlayConfig;
    final detection = ArchitectGeodeticDetector.analyzeDocument(
      doc: doc,
      storeyId: storeyId,
      lockedOrigin: cfg != null && cfg.hasLockedOrigin
          ? Offset(cfg.lockedCadOriginX!, cfg.lockedCadOriginY!)
          : null,
      lockedUnitsPerMeter: cfg?.unitsPerMeter,
      existingSurvey: _project.geodeticSurvey,
    );
    setState(() {
      _commands.commit(_project.copyWith(geodeticSurvey: detection.survey));
    });
    _saveBiMProjectIfAttached();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          detection.hasTopography
              ? context.l10n.architectGeodesyDetectedNotice(
                  detection.coordinateSystem.name,
                  detection.contours.length,
                  detection.spotElevations.length,
                )
              : context.l10n.architectGeodesyNoContoursFound,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyGeodesyTo3DTerrain() {
    final survey = _project.geodeticSurvey;
    if (survey == null) return;
    final storeyId = _project.activeStorey.id;
    final contours = survey.contoursForStorey(storeyId);
    final pts = survey.pointsForStorey(storeyId);
    if (contours.isEmpty && pts.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    int totalCount = pts.length;
    for (final c in contours) {
      totalCount += c.points.length;
      for (final p in c.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    for (final p in pts) {
      if (p.position.dx < minX) minX = p.position.dx;
      if (p.position.dy < minY) minY = p.position.dy;
      if (p.position.dx > maxX) maxX = p.position.dx;
      if (p.position.dy > maxY) maxY = p.position.dy;
    }
    if (!minX.isFinite || !maxX.isFinite) return;
    final boundary = <Offset>[
      Offset(minX, minY),
      Offset(maxX, minY),
      Offset(maxX, maxY),
      Offset(minX, maxY),
    ];
    setState(() {
      _commands.commit(
        _project.copyWith(
          elevations: [
            for (final e in _project.elevations)
              e.copyWith(terrain: boundary),
          ],
        ),
      );
    });
    _saveBiMProjectIfAttached();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.architectGeodesyAppliedToTerrainNotice(totalCount),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeCurrentCadUnderlay() {
    final storeyId = _project.activeStorey.id;
    final nextUnderlays = Map<String, ArchitectCadUnderlayConfig>.from(
      _project.cadUnderlays,
    )..remove(storeyId);
    _cadFileWatcher?.updateConfigs(nextUnderlays);
    setState(() {
      _underlaysByStorey.remove(storeyId);
      _commands.commit(_project.copyWith(cadUnderlays: nextUnderlays));
    });
    _saveBiMProjectIfAttached();
  }

  void _toggleCadVisibility(bool visible) {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final updated = cfg.copyWith(visible: visible);
    final map = Map<String, ArchitectCadUnderlayConfig>.from(
      _project.cadUnderlays,
    )..[cfg.storeyId] = updated;
    setState(() {
      _commands.commit(_project.copyWith(cadUnderlays: map));
      if (!visible) _isCadUnderlaySelected = false;
    });
    _saveBiMProjectIfAttached();
    if (!visible && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectUnderlayHiddenNotice),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.l10n.undoAction,
            onPressed: () => _toggleCadVisibility(true),
          ),
        ),
      );
    }
  }

  void _toggleRasterVisibility(String rasterId, bool visible) {
    final list = [
      for (final r in _project.rasterUnderlays)
        if (r.id == rasterId) r.copyWith(visible: visible) else r,
    ];
    setState(() {
      _commands.commit(_project.copyWith(rasterUnderlays: list));
      if (!visible && _selectedRasterId == rasterId) {
        _selectedRasterId = null;
      }
    });
    _saveBiMProjectIfAttached();
    if (!visible && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectUnderlayHiddenNotice),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: context.l10n.undoAction,
            onPressed: () => _toggleRasterVisibility(rasterId, true),
          ),
        ),
      );
    }
  }

  Future<void> _importRasterUnderlay() async {
    if (_underlayBusy) return;
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'pdf'],
        );
      } catch (e) {
        debugPrint(
          '[ArchitectWorkspaceScreen] custom FilePicker failed ($e), falling back to any',
        );
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }
      if (result == null || result.files.isEmpty || !mounted) return;

      String? pickedPath = result.files.single.path;
      if (pickedPath == null && result.files.single.bytes != null) {
        final tempDir = await Directory.systemTemp.createTemp('koto_raster_');
        final tempFile = File('${tempDir.path}/${result.files.single.name}');
        await tempFile.writeAsBytes(result.files.single.bytes!);
        pickedPath = tempFile.path;
      }
      if (pickedPath == null || !mounted) return;

      final lowerExt = pickedPath.split('.').last.toLowerCase();
      const validExts = {'png', 'jpg', 'jpeg', 'webp', 'bmp', 'pdf'};
      if (!validExts.contains(lowerExt)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.architectUnderlayLoadError('Unsupported format: $lowerExt'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      int selectedPage = 1;
      final isPdf = lowerExt == 'pdf';
      if (isPdf) {
        final pageCount =
            await ArchitectUnderlayService.instance.getPdfPageCount(
          pickedPath,
        );
        if (!mounted) return;
        if (pageCount > 1) {
          final chosen = await showArchitectPdfPagePickerDialog(
            context: context,
            pageCount: pageCount,
          );
          if (chosen == null || !mounted) return;
          selectedPage = chosen;
        }
      }

      setState(() {
        _underlayBusy = true;
        _underlayBusyMessage = context.l10n.architectUnderlayConverting;
      });
      final centre = _viewport.visibleRect.center;
      final projectId = widget.bimProject?.id ?? _project.name;
      final storeyId = _project.activeStorey.id;
      final ArchitectRasterImportResult loaded = isPdf
          ? await ArchitectUnderlayService.instance.importPdfPageAsRaster(
              projectId: projectId,
              storeyId: storeyId,
              pdfFile: File(pickedPath),
              pageNumber: selectedPage,
              initialCenter: centre,
            )
          : await ArchitectUnderlayService.instance.importRasterImageFile(
              projectId: projectId,
              storeyId: storeyId,
              sourceFile: File(pickedPath),
              initialCenter: centre,
            );
      if (!mounted) return;
      setState(() {
        _rasterImages[loaded.model.id] = loaded.image;
        _selectedRasterId = loaded.model.id;
        _commands.commit(
          _project.copyWith(
            rasterUnderlays: [..._project.rasterUnderlays, loaded.model],
          ),
        );
        _underlayBusy = false;
        _underlayBusyMessage = null;
      });
      _saveBiMProjectIfAttached();
    } catch (e, stack) {
      debugPrint(
        '[ArchitectWorkspaceScreen] _importRasterUnderlay error: $e\n$stack',
      );
      if (mounted) {
        setState(() {
          _underlayBusy = false;
          _underlayBusyMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectUnderlayLoadError(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted && _underlayBusy) {
        setState(() {
          _underlayBusy = false;
          _underlayBusyMessage = null;
        });
      }
    }
  }

  void _updateSelectedRaster(ArchitectRasterUnderlay updated) {
    setState(() {
      _commands.commit(
        _project.copyWith(
          rasterUnderlays: [
            for (final item in _project.rasterUnderlays)
              if (item.id == updated.id) updated else item,
          ],
        ),
      );
    });
    _saveBiMProjectIfAttached();
  }

  void _deleteSelectedRaster() {
    final selected = _selectedRasterUnderlay;
    if (selected == null) return;
    setState(() {
      _rasterImages.remove(selected.id);
      if (_selectedRasterId == selected.id) _selectedRasterId = null;
      _rasterCalibrationStep = 0;
      _rasterCalibrationP1 = null;
      _rasterCalibrationP2 = null;
      _commands.commit(
        _project.copyWith(
          rasterUnderlays: _project.rasterUnderlays
              .where((r) => r.id != selected.id)
              .toList(),
        ),
      );
    });
    _saveBiMProjectIfAttached();
  }

  Future<void> _handleRasterCalibrationTap(Offset modelPoint) async {
    final selected = _selectedRasterUnderlay;
    if (selected == null) return;
    if (_rasterCalibrationStep == 1) {
      setState(() {
        _rasterCalibrationP1 = modelPoint;
        _rasterCalibrationP2 = null;
        _rasterCalibrationStep = 2;
      });
      HapticFeedback.selectionClick();
      return;
    }
    if (_rasterCalibrationStep == 2 && _rasterCalibrationP1 != null) {
      final p1 = _rasterCalibrationP1!;
      final p2 = modelPoint;
      if ((p2 - p1).distance < 1e-4) return;
      setState(() {
        _rasterCalibrationP2 = p2;
      });
      HapticFeedback.mediumImpact();
      final currentSpan = (p2 - p1).distance;
      final dialogRes = await showArchitectRasterCalibrationDialog(
        context: context,
        currentMeasuredMeters: currentSpan,
      );
      if (!mounted) return;
      if (dialogRes != null && dialogRes.distanceMeters > 1e-4) {
        final calibrated = selected.calibrateTwoPoint(
          localP1: p1,
          localP2: p2,
          realDistanceMeters: dialogRes.distanceMeters,
          alignMode: dialogRes.alignMode,
        );
        _updateSelectedRaster(calibrated);
        final mmPerPx = (calibrated.metersPerPixel * 1000.0).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectRasterCalibratedSuccess(mmPerPx)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _rasterCalibrationStep = 0;
        _rasterCalibrationP1 = null;
        _rasterCalibrationP2 = null;
      });
    }
  }

  void _startUnderlayMaskDraft({
    required bool isCad,
    required String mode, // 'rect' or 'polygon'
    String? rasterId,
  }) {
    setState(() {
      _underlayMaskDrafting = true;
      _underlayMaskMode = mode;
      _underlayMaskTargetIsCad = isCad;
      _underlayMaskTargetRasterId = rasterId;
      _underlayMaskPoints = [];
      _underlayMaskDraftStart = null;
    });
  }

  void _commitUnderlayMask(List<Offset> polygon) {
    if (polygon.length < 3) {
      _cancelUnderlayMaskDraft();
      return;
    }
    if (_underlayMaskTargetIsCad) {
      final storeyId = _project.activeStorey.id;
      final cfg = _project.cadUnderlays[storeyId];
      if (cfg != null) {
        final updated = cfg.copyWith(maskPolygon: polygon, maskEnabled: true);
        final map = Map<String, ArchitectCadUnderlayConfig>.from(
          _project.cadUnderlays,
        )..[storeyId] = updated;
        _commands.commit(_project.copyWith(cadUnderlays: map));
        _saveBiMProjectIfAttached();
      }
    } else {
      final targetId = _underlayMaskTargetRasterId ?? _selectedRasterId;
      if (targetId != null) {
        final updatedList = [
          for (final r in _project.rasterUnderlays)
            if (r.id == targetId)
              r.copyWith(maskPolygon: polygon, maskEnabled: true)
            else
              r,
        ];
        _commands.commit(_project.copyWith(rasterUnderlays: updatedList));
        _saveBiMProjectIfAttached();
      }
    }
    setState(() {
      _underlayMaskDrafting = false;
      _underlayMaskDraftStart = null;
      _underlayMaskPoints = [];
    });
  }

  void _cancelUnderlayMaskDraft() {
    setState(() {
      _underlayMaskDrafting = false;
      _underlayMaskDraftStart = null;
      _underlayMaskPoints = [];
    });
  }

  Future<void> _openCadContextMenu(Offset globalPosition) async {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final action = await showArchitectUnderlayContextMenu(
      context: context,
      globalPosition: globalPosition,
      isCad: true,
      hasMask: cfg.hasActiveMask,
      maskEnabled: cfg.maskEnabled,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'position':
      case 'reposition':
      case 'drag':
        _startUnderlaySnapDrag(isCad: true);
      case 'hide':
        _toggleCadVisibility(false);
      case 'edit':
        _openCadEditDialog();
      case 'scale':
        _openCadScaleDialog();
      case 'mask':
        _openCadMaskMenu(globalPosition);
      case 'remove':
        _removeCurrentCadUnderlay();
    }
  }

  Future<void> _openCadMaskMenu(Offset globalPosition) async {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final action = await showArchitectUnderlayMaskMenu(
      context: context,
      globalPosition: globalPosition,
      hasMask: cfg.maskPolygon != null && cfg.maskPolygon!.length >= 3,
      maskEnabled: cfg.maskEnabled,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'mask_rect':
        _startUnderlayMaskDraft(isCad: true, mode: 'rect');
      case 'mask_polygon':
        _startUnderlayMaskDraft(isCad: true, mode: 'polygon');
      case 'mask_toggle':
        final updated = cfg.copyWith(maskEnabled: !cfg.maskEnabled);
        final map = Map<String, ArchitectCadUnderlayConfig>.from(
          _project.cadUnderlays,
        )..[cfg.storeyId] = updated;
        setState(() => _commands.commit(_project.copyWith(cadUnderlays: map)));
        _saveBiMProjectIfAttached();
      case 'mask_clear':
        final updated = cfg.copyWith(clearMask: true, maskEnabled: false);
        final map = Map<String, ArchitectCadUnderlayConfig>.from(
          _project.cadUnderlays,
        )..[cfg.storeyId] = updated;
        setState(() => _commands.commit(_project.copyWith(cadUnderlays: map)));
        _saveBiMProjectIfAttached();
    }
  }

  Future<void> _openCadScaleDialog() async {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    final newScale = await showArchitectCadScaleDialog(
      context: context,
      currentUnitsPerMeter: cfg.unitsPerMeter ?? 1.0,
    );
    if (!mounted || newScale == null) return;
    final updated = cfg.copyWith(unitsPerMeter: newScale);
    final map = Map<String, ArchitectCadUnderlayConfig>.from(
      _project.cadUnderlays,
    )..[cfg.storeyId] = updated;
    setState(() => _commands.commit(_project.copyWith(cadUnderlays: map)));
    _saveBiMProjectIfAttached();
  }

  void _openCadEditDialog() {
    final cfg = _currentCadUnderlayConfig;
    if (cfg == null) return;
    showArchitectUnderlayEditDialog(
      context: context,
      title: '${context.l10n.architectUnderlayEditDialogTitle}: ${cfg.fileName}',
      initialOpacity: cfg.opacity,
      onOpacityChanged: (val) {
        final current = _currentCadUnderlayConfig;
        if (current == null) return;
        final updated = current.copyWith(opacity: val);
        final map = Map<String, ArchitectCadUnderlayConfig>.from(
          _project.cadUnderlays,
        )..[current.storeyId] = updated;
        setState(() => _commands.commit(_project.copyWith(cadUnderlays: map)));
      },
      onOpenLayers: _openCadDxfLayersSheet,
      isAutoReload: cfg.autoReload,
      onToggleAutoReload: _toggleCadAutoReload,
      isLockOrigin: cfg.lockOrigin,
      onToggleLockOrigin: _toggleCadOriginLock,
      onRemove: _removeCurrentCadUnderlay,
    );
  }

  Future<void> _openRasterContextMenu(Offset globalPosition) async {
    final sel = _selectedRasterUnderlay;
    if (sel == null) return;
    final action = await showArchitectUnderlayContextMenu(
      context: context,
      globalPosition: globalPosition,
      isCad: false,
      hasMask: sel.hasActiveMask,
      maskEnabled: sel.maskEnabled,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'position':
      case 'reposition':
      case 'drag':
        _startUnderlaySnapDrag(isCad: false, rasterId: sel.id);
      case 'hide':
        _toggleRasterVisibility(sel.id, false);
      case 'edit':
        _openRasterEditDialog();
      case 'scale':
        _openRasterScaleDialog();
      case 'mask':
        _openRasterMaskMenu(globalPosition);
      case 'remove':
        _deleteSelectedRaster();
    }
  }

  Future<void> _openRasterMaskMenu(Offset globalPosition) async {
    final sel = _selectedRasterUnderlay;
    if (sel == null) return;
    final action = await showArchitectUnderlayMaskMenu(
      context: context,
      globalPosition: globalPosition,
      hasMask: sel.maskPolygon != null && sel.maskPolygon!.length >= 3,
      maskEnabled: sel.maskEnabled,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'mask_rect':
        _startUnderlayMaskDraft(isCad: false, mode: 'rect', rasterId: sel.id);
      case 'mask_polygon':
        _startUnderlayMaskDraft(
          isCad: false,
          mode: 'polygon',
          rasterId: sel.id,
        );
      case 'mask_toggle':
        _updateSelectedRaster(sel.copyWith(maskEnabled: !sel.maskEnabled));
      case 'mask_clear':
        _updateSelectedRaster(
          sel.copyWith(clearMask: true, maskEnabled: false),
        );
    }
  }

  void _openRasterScaleDialog() {
    setState(() {
      _rasterCalibrationStep = 1;
      _rasterCalibrationP1 = null;
      _rasterCalibrationP2 = null;
    });
  }

  void _openRasterEditDialog() {
    final sel = _selectedRasterUnderlay;
    if (sel == null) return;
    showArchitectUnderlayEditDialog(
      context: context,
      title: '${context.l10n.architectUnderlayEditDialogTitle}: ${sel.fileName}',
      initialOpacity: sel.opacity,
      onOpacityChanged: (val) {
        final current = _selectedRasterUnderlay;
        if (current != null) {
          _updateSelectedRaster(current.copyWith(opacity: val));
        }
      },
      isLocked: sel.locked,
      onToggleLock: () {
        final current = _selectedRasterUnderlay;
        if (current != null) {
          _updateSelectedRaster(current.copyWith(locked: !current.locked));
        }
      },
      onRotateCcw: () {
        final current = _selectedRasterUnderlay;
        if (current != null) {
          _updateSelectedRaster(
            current.copyWith(rotationRad: current.rotationRad - math.pi / 2),
          );
        }
      },
      onRotateCw: () {
        final current = _selectedRasterUnderlay;
        if (current != null) {
          _updateSelectedRaster(
            current.copyWith(rotationRad: current.rotationRad + math.pi / 2),
          );
        }
      },
      onRemove: _deleteSelectedRaster,
    );
  }



  void _saveBiMProjectIfAttached() {
    if (_commandPreview != null) return;

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
    if (_commandPreview != null &&
        !identical(_commandPreview!.document, _modelCommands.project)) {
      _discardGeometryCommand();
    }
    _touchCandidates = null;

    if (!mounted) return;

    if ((_offsetOptions != null && !identical(_offsetSource, _project)) ||
        (_hatchTransformSource != null && !identical(_hatchTransformSource, _project)) ||
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

      _activeTool = ArchitectTool.pan;

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
    if (_dragController.isActive) {
      _cancelDragPlacement();
      return;
    }
    if (_commandPreview != null) { _cancelGeometryCommand(); return; }
    _touchCandidates = null;

    _editingGroupId = null;

    _resetDraftGroup();

    if (_cutOpeningTargetId != null) _activeTool = ArchitectTool.pan;

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


      _explicitSelectionOperation = false;
      _selectionOperation = ArchitectSelectionOperation.replace;

    _moveSelection = false;

    _transverseMove = false;

    _interactionEpoch++;

    _cancelActiveDrags();

    _zoneTool.cancelAll();

    _axisTool.cancelAll();

    _axisTool.deselect();

    _elementTool.cancelSlabDrafting();

    _roofTool.clearDraft();
    _landscapeTool.clearDraft();
    _marqueeTool.cancel();

    if (_selectionContextActive ||

        _activeTool == ArchitectTool.door ||

        _activeTool == ArchitectTool.window ||

        _activeTool == ArchitectTool.column ||

        _activeTool == ArchitectTool.services ||

        _activeTool == ArchitectTool.opening) {

      _activeTool = ArchitectTool.pan;

      _cursorModel = null;

      _columnPreviewPoint = null;

      _servicePreviewPoint = null;

    }

    _selectionContextActive = false;

    setState(() {

      _resetWallDraft();

      _selectedZoneId = null;

      _selectedElementId = null;

      _selectedSectionRoofId = null;

      _columnPreviewPoint = null;

      _servicePreviewPoint = null;

    });

  }



  bool _terrainDrafting = false;



  void _startTerrainDraft() {

    _cancelDrafting(); _clearSelection();

    setState(() { _activeTool = ArchitectTool.pan; _terrainDrafting = true; });

  }



  void _changeTool(ArchitectTool tool, {bool toggle = true}) {
    // Move is a transient selection operation; preserve the drawing tool and
    // selection instead of clearing them during a tool switch.
    if (tool == ArchitectTool.drag) {
      _startDragSession();
      return;
    }
    setState(() {
    _discardGeometryCommand();
    _touchCandidates = null;
    final previousMode = _interactionMode;
    final keepSingle = tool == ArchitectTool.select && !previousMode.isManualSelection
        ? _effectiveSelection.lastOrNull : null;
    _draftingSeed = null;
    _quickDrawingTool = null;
    _marqueeTool.cancel();

    _finishDraftGroup();

    if (tool != ArchitectTool.pan && tool != ArchitectTool.select) {
      _editingGroupId = null;
    }

    _cutOpeningTargetId = null;

    _terrainDrafting = false;

    _placingDownpipe = false;

    _downpipeRoofId = null;

    _rasterCalibrationStep = 0;
    _rasterCalibrationP1 = null;
    _rasterCalibrationP2 = null;
    _draggingRasterId = null;

    final sameCommand = tool == ArchitectTool.select
        ? previousMode == ArchitectInteractionMode.singleSelect
        : _activeTool == tool && previousMode != ArchitectInteractionMode.contextEdit;
    final nextTool = toggle && sameCommand ? ArchitectTool.pan : tool;

    _resetDimensionDraft();

    _selectionCyclePoint = null;

    _selectionIds.clear();

    _interactionEpoch++;

    _cancelActiveDrags();

    _zoneTool.cancelAll();

    _axisTool.cancelAll();

    _axisTool.deselect();

    _elementTool.cancelSlabDrafting();

    _roofTool.clearDraft();
    _landscapeTool.clearDraft();

    _selectedZoneId = null;

    _selectedElementId = null;

    _transverseMove = false;

    _wallEndpointClearanceId = null;

    _multiSelect = false;
      _explicitSelectionOperation = false;
      _selectionOperation = ArchitectSelectionOperation.replace;

    _moveSelection = false;

    _activeTool = nextTool;
    if (nextTool.usesComponent) {
      final library = ComponentLibraryService.instance;
      final services = nextTool == ArchitectTool.services;
      if ((library.activeDefinition.category == ArchitectComponentCategory.services) != services) {
        library.setActiveDefinition(library.getAllDefinitions().firstWhere((d) =>
            (d.category == ArchitectComponentCategory.services) == services));
      }
    }
    if (nextTool == ArchitectTool.select && keepSingle != null) {
      _selectionIds.add(keepSingle);
      _selectedElementId = keepSingle;
    }

    _midpointTracking.clear();

    _pendingShape = null;

    _shapePanelAnchor = null;

    _columnPreviewPoint = null;

    _columnPreviewRotation = 0.0;

    _cursorModel = null;

    _resetWallDraft();

    _selectionContextActive = false;

    _selectedSectionRoofId = null;

    _isZoneTableSelected = false;

    });
  }



  void _clearSelection() {
    _wallAngleUnlockedId = null;
    _discardGeometryCommand();
    _touchCandidates = null;

    setState(() {

      if (_selectionContextActive) _activeTool = ArchitectTool.pan;

      _selectionContextActive = false;

      _selectionCyclePoint = null;

      _cancelActiveDrags();

      _selectionIds.clear();

      _selectedElementId = null;

      _selectedZoneId = null;

      _isZoneTableSelected = false;

      _selectedSectionRoofId = null;

      _isCadUnderlaySelected = false;
      _selectedRasterId = null;

      _radialMenuScreenPosition = null;

      _radialMenuElementId = null;

      _axisTool.deselect();

      _zoneTool.cancelEditingZone();


      _explicitSelectionOperation = false;
      _selectionOperation = ArchitectSelectionOperation.replace;

      _moveSelection = false;

      _transverseMove = false;

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

  List<ArchitectWallType> get _availableWallTypes =>
      ArchitectWallLibrary.available(_project.wallTypes);



  void _restoreWallType() {

    final types = _availableWallTypes;

    _activeWallType = types.firstWhere(

      (type) => type.id == _preferredWallTypeId,

      orElse: () => _project.wallTypes.where((type) => type.isCatalogType &&
          type.usage == WallUsage.exterior && type.hasInsulation).firstOrNull ??
          types.firstWhere(
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
    _draftingSeed = null;

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



  void _applyStructuralSchemeDefaults(ArchitectStructuralScheme scheme) {
    final types = _availableWallTypes;
    ArchitectWallType? target;
    switch (scheme) {
      case ArchitectStructuralScheme.sandwichPanels:
        target = types.where((t) => t.system.isPanel).firstOrNull;
        _roofTool.setPreset(ArchitectRoofPreset.sandwichPitched);
        break;
      case ArchitectStructuralScheme.roundLogs:
        target = types.where((t) => t.system.isLog).firstOrNull;
        _roofTool.setPreset(ArchitectRoofPreset.logTimber);
        break;
      case ArchitectStructuralScheme.studFrame:
        target = types.where((t) => t.system.isStud).firstOrNull;
        _roofTool.setPreset(ArchitectRoofPreset.pitchedTiles);
        break;
      case ArchitectStructuralScheme.flatSlab:
      case ArchitectStructuralScheme.beamAndSlab:
        target = types
            .where((t) =>
                t.id == 'ext_25_12_eps' ||
                (t.coreMaterial == WallCoreMaterial.brick &&
                    t.usage == WallUsage.exterior))
            .firstOrNull;
        _roofTool.setPreset(ArchitectRoofPreset.pitchedTiles);
        break;
    }
    if (target != null) {
      _selectWallType(target);
    }
  }

  // --- SUBSECTION: [TAG:ARC_EXACT_PLACEMENT] Chord input, shaping, exact rise, commit ---
  bool get _curvedDraftTool =>
      (_activeTool == ArchitectTool.wall && _wallCurved) ||
      (_activeTool == ArchitectTool.cadLine &&
          (_cadPolylineMode ? _polylineArcSegmentMode : _wallCurved)) ||
      _activeTool == ArchitectTool.cadArc;

  void _beginDraftArcShaping() {
    if (_draftStart == null || _draftEnd == null) return;
    setState(() {
      _wallArcEnd = _draftEnd;
      final chord = _wallArcEnd! - _draftStart!;
      final normal = Offset(-chord.dy, chord.dx) / chord.distance;
      _draftEnd = (_draftStart! + _wallArcEnd!) / 2 +
          normal * (chord.distance * .2);
      _draftArcExactBulge = null;
      _arcDimension = ArchitectArcDimension.sagitta;
      _wallDirectionLocked = false;
      _wallPanelAnchor = null;
    });
    _repaintPreview();
  }

  bool _wallCurved = false;

  Offset? _wallArcEnd;
  double? _draftArcExactBulge;
  ArchitectArcDimension _arcDimension = ArchitectArcDimension.sagitta;
  bool _arcEditorOpen = false;

  double get _draftArcBulge =>

      _wallArcEnd == null || _draftStart == null || _draftEnd == null

      ? 0

      : _draftArcExactBulge ??
          ArchitectWallArc.through(_draftStart!, _wallArcEnd!, _draftEnd!);

  void _commitLineArc() {
    if (_wallArcEnd == null || _draftStart == null) return;
    final bulge = _draftArcBulge;
    if (_activeTool == ArchitectTool.cadArc) {
      final id = ArchitectElementId.next('arc');
      _placeDraftSegment(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: ArchitectCadPrimitive(
            id: id,
            type: bulge.abs() > 1e-6
                ? CadPrimitiveType.arc
                : CadPrimitiveType.line,
            startPoint: _draftStart!,
            endPoint: _wallArcEnd!,
            arcBulge: bulge,
            colorValue: 0xFF9E9E9E,
            lineStyle: _activeCadLineStyle,
          ),
        ),
        id,
        false,
      );
    } else {
      _commitCurrentWallSegment(
        _wallArcEnd!,
        arcBulge: bulge,
        continueChain: _cadPolylineMode,
      );
    }
    setState(() {
      _wallArcEnd = null;
      _draftArcExactBulge = null;
      if (!_cadPolylineMode) {
        _draftStart = null;
        _draftEnd = null;
      }
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
  }

  void _commitWallArc() {
    if (_activeTool == ArchitectTool.cadLine || _activeTool == ArchitectTool.cadArc) {
      _commitLineArc();
      return;
    }
    if (_wallArcEnd == null) return;

    final bulge = _draftArcBulge;

    try {

      ArchitectWall(

        id: 'validate',

        startPoint: _draftStart!,

        endPoint: _wallArcEnd!,

        arcBulge: bulge,

        thickness: _wallThickness,

        referenceLine: _wallReference,

        exteriorSide: _wallExteriorSide,
      exteriorSideMode: _wallExteriorSideMode,

        system: _activeWallType?.system ?? const ArchitectWallSystem(),
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



  ArchitectWall? get _draftArcWall {
    if (!_curvedDraftTool ||
        _draftStart == null ||
        _wallArcEnd == null ||
        _draftEnd == null) {
      return null;
    }
    return ArchitectWall(
      id: 'arc-preview',
      startPoint: _draftStart!,
      endPoint: _wallArcEnd!,
      arcBulge: _draftArcBulge,
      thickness: _activeTool == ArchitectTool.wall ? _wallThickness : 0.001,
      referenceLine: _wallReference,
      exteriorSide: _wallExteriorSide,
      exteriorSideMode: _wallExteriorSideMode,
      system: _activeWallType?.system ?? const ArchitectWallSystem(),
      layers: _activeWallType?.resolvedLayers ?? const [],
      railing: _activeWallType?.railing,
      height: _activeWallType?.customHeight ?? _project.activeStorey.height,
      wallTypeId: _activeWallType?.id,
      insulationThicknessOverride: _activeWallType?.insulationThickness,
    );
  }

  Future<void> _editWallArcDimension({
    ArchitectArcDimension? dimension,
    bool commitDraft = false,
  }) async {
    if (_arcEditorOpen) return;
    final draft = _draftArcWall;
    final original =
        draft ?? (_effectiveSelection.length == 1 ? (_selectedWall ?? _selectedLinearElement) : null);
    if (original == null) return;
    _cancelActiveDrags();
    final source = _project, start = _draftStart, end = _wallArcEnd;
    final oldPoint = _draftEnd, oldExact = _draftArcExactBulge;
    final wall = original;
    if (dimension != null) _arcDimension = dimension;
    _arcEditorOpen = true;
    bool current() =>
        mounted &&
        identical(_project, source) &&
        (draft == null || (_draftStart == start && _wallArcEnd == end));
    final isCadPrim = _selectedLineIds.contains(original.id) ||
        source.activeStorey.cadPrimitives.any((p) => p.id == original.id);
    ArchitectModelCommand command(ArchitectWall candidate) {
      if (isCadPrim) {
        final existing = source.activeStorey.cadPrimitives
            .firstWhere((p) => p.id == original.id);
        return PlaceArchitectCadPrimitive(
          storeyId: source.activeStoreyId,
          primitive: existing.copyWith(
            type: candidate.arcBulge.abs() > 1e-6
                ? CadPrimitiveType.arc
                : CadPrimitiveType.line,
            arcBulge: candidate.arcBulge,
          ),
        );
      }
      return UpdateArchitectWall(
        storeyId: source.activeStoreyId,
        wall: candidate,
        carryConnections: false,
      );
    }
    ArchitectWall? result;
    try {
      result = await showDialog<ArchitectWall>(
        context: context,
        builder: (_) => ArchitectWallArcDimensionDialog(
          project: source,
          wall: wall,
          dimension: _arcDimension,
          confirmLabel: draft != null
              ? context.l10n.applyAction
              : context.l10n.save,
          onDimension: (value) {
            if (!current()) return;
            setState(() => _arcDimension = value);
            _repaintPreview();
          },
          validate: (candidate) {
            if (!current()) throw ArgumentError('Arc edit context changed');
            candidate.validateGeometry();
            ArchitectWallArcEditing.validateOpenings(candidate);
            if (draft == null) command(candidate).apply(source);
          },
          onPreview: (candidate) {
            if (!current()) return;
            setState(() {
              if (draft != null) {
                _draftEnd = candidate.arc?.midpoint ??
                    (candidate.startPoint + candidate.endPoint) / 2;
                _draftArcExactBulge = candidate.arcBulge;
              } else {
                _elementMovePreview = command(candidate).apply(source);
              }
            });
            _repaintPreview();
          },
        ),
      );
    } finally {
      _arcEditorOpen = false;
      if (mounted) {
        setState(() {
          _elementMovePreview = null;
          if (current() && draft != null) {
            _draftEnd = result == null
                ? oldPoint
                : result.arc?.midpoint ?? (result.startPoint + result.endPoint) / 2;
            _draftArcExactBulge = result?.arcBulge ?? oldExact;
          }
        });
        _repaintPreview();
      }
    }
    if (current() && draft != null && result != null && commitDraft) {
      _commitWallArc();
      return;
    }
    if (current() &&
        draft == null &&
        result != null &&
        (result.arcBulge - original.arcBulge).abs() > 1e-12) {
      if (isCadPrim) {
        _commands.execute(command(result));
      } else {
        _executeWallEdit(command(result));
      }
    }
  }

  Widget _buildWallArcDimensionOverlay() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (context, _) {
        if (!_commands.isPlan ||
            _mirrorActive ||
            _offsetOptions != null ||
            _splitActive ||
            _newPointTargetId != null ||
            _wallCutIds.isNotEmpty ||
            _wallExtendId != null ||
            _radialMenuScreenPosition != null ||
            _curvingEdgeElementId != null) {
          return const SizedBox.shrink();
        }
        final draft = _draftArcWall;
        final selected = _effectiveSelection.length == 1
            ? (_selectedWall ?? _selectedLinearElement)
            : null;
        final wall =
            draft ??
            (selected == null
                ? null
                : (_drawingProject.activeStorey.walls
                        .where((w) => w.id == selected.id && w.isCurved)
                        .firstOrNull ??
                    () {
                      final p = _drawingProject.activeStorey.cadPrimitives
                          .where((p) =>
                              p.id == selected.id &&
                              (p.isCurved || p.type == CadPrimitiveType.arc))
                          .firstOrNull;
                      return p != null ? ArchitectLineEditing.segment(p) : null;
                    }()));
        if (wall == null) return const SizedBox.shrink();
        return ArchitectWallArcDimensionOverlay(
          arc: ArchitectWallArc(wall.startPoint, wall.endPoint, wall.arcBulge),
          dimension: _arcDimension,
          toScreen: _viewport.toScreen,
          toModel: _viewport.toModel,
          format: _project.formatLength,
          indexedObstacles: ArchitectClearanceObstacles.forWalls(draft == null
              ? _drawingProject.activeStorey.walls
              : [..._drawingProject.activeStorey.walls, draft],
          ),
          onEdit: _editWallArcDimension,
        );
      },
    ),
  );

  WallDraftingMode _wallMode = WallDraftingMode.singleLine;

  bool _cadPolylineMode = false;
  String? _polylineDraftId;
  int? _polylineVertexIndex;
  bool _polylineEdgeDrag = false;

  ArchitectCadPrimitive? get _selectedPolyline => _effectiveSelection.length == 1
      ? _project.activeStorey.cadPrimitives.where((p) =>
          p.id == _effectiveSelection.single &&
          p.type == CadPrimitiveType.polyline,
            ).firstOrNull
      : null;

  ArchitectCadPrimitive? get _selectedSpline => _effectiveSelection.length == 1
      ? _project.activeStorey.cadPrimitives.where((p) =>
          p.id == _effectiveSelection.single &&
          p.type == CadPrimitiveType.spline,
            ).firstOrNull
      : null;

  void _setCadPolylineMode(bool value) {
    if (_cadPolylineMode == value) return;
    _finishChainedWall();
    setState(() => _cadPolylineMode = value);
  }

  Offset? _draftStart;

  Offset? _draftEnd;

  CadPrimitiveType? _pendingShape;

  Offset? _shapePanelAnchor;

  final _polygonEditor = ArchitectPolygonEditor();

  ArchitectPolygonEdgeMode _polygonEdgeMode = ArchitectPolygonEdgeMode.move;

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
        point, _currentScale, offsetLengthPx: _handleOffsetLength,
    );
    if (ring == null) return;
    if (_polygonContourElementId != id || _polygonContourIndex != ring) {
      _polygonSelectedEdge = null;
    }
    _polygonContourElementId = id;
    _polygonContourIndex = ring;
  }

  bool _polygonDistanceOpen = false;
  bool _polygonPrecisionMode = false;
  (Offset, Offset)? _polygonDisplacementLine;

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
  bool _preserveWallPosition = true;
  bool _wallReferenceManual = false;

  WallExteriorSide _wallExteriorSide = WallExteriorSide.left;
  WallResolutionMode _wallExteriorSideMode = WallResolutionMode.automatic;

  String? _wallExtendId;

  String? _wallJoinSourceId;
  String? _wallAttachSourceId;
  Offset? _wallAttachPointer;
  Set<String>? _pendingDetachWallIds;

  Offset? _wallJoinPointer;
  String? _chamferFilletSourceId;
  ArchitectChamferFilletOptions? _chamferFilletOptions;
  Offset? _chamferFilletPointer;
  double? _lastFilletRadius;
  double? _lastChamferDistance;

  String? _curvingEdgeElementId;
  int? _curvingEdgeSegmentIndex;
  Offset? _curvingEdgeStartPoint;
  Offset? _curvingEdgeEndPoint;
  double _curvingEdgeBulge = 0.0;
  double? _curvingEdgeExactBulge;
  bool _curvingEdgeEditorOpen = false;
  bool _isCurvingEdgeDragging = false;
  bool _curvingEdgeSnapped = false;
  String? _curvingEdgeSnapLabel;
  bool _curvingEdgePendingConfirmation = false;
  Offset _curvingEdgeGripDirection = const Offset(0, -1);
  Offset _curvingDragScreenOffset = Offset.zero;
  Offset? _lastTapModelPosition;

  Offset? get _curvingEdgeGripScreen {
    if (_curvingEdgeStartPoint == null || _curvingEdgeEndPoint == null) return null;
    final p1 = _curvingEdgeStartPoint!;
    final p2 = _curvingEdgeEndPoint!;
    final arc = ArchitectWallArc(p1, p2, _curvingEdgeBulge);
    final apexModel = _curvingEdgeBulge.abs() > 1e-4 ? arc.midpoint : (p1 + p2) / 2;
    final apexScreen = _viewport.toScreen(apexModel);
    final length = _handleOffsetLength > 0 ? _handleOffsetLength : 48.0;
    return apexScreen + _curvingEdgeGripDirection * length;
  }

  (Offset, Offset)? get _chamferFilletLeaderLine {
    if (_chamferFilletSourceId == null) return null;
    final wall = _linearEditWalls
        .where((w) => w.id == _chamferFilletSourceId)
        .firstOrNull;
    if (wall != null) {
      final center = wall.referencePointAt(.5);
      final target = _chamferFilletPointer ??
          (center + wall.normalVector * (wall.thickness + 0.6));
      return (center, target);
    }
    final line = _project.activeStorey.cadPrimitives
        .where((p) => p.id == _chamferFilletSourceId && p.type == CadPrimitiveType.line)
        .firstOrNull;
    if (line != null) {
      final center = (line.startPoint + line.endPoint) / 2;
      final target = _chamferFilletPointer ?? center;
      return (center, target);
    }
    return null;
  }

  (Offset, Offset)? get _wallAttachLeaderLine {
    if (_wallAttachSourceId == null) return null;
    final wall = _linearEditWalls
        .where((w) => w.id == _wallAttachSourceId)
        .firstOrNull;
    if (wall == null) return null;
    final center = wall.referencePointAt(.5);
    final target = _wallAttachPointer ??
        (center + wall.normalVector * (wall.thickness + 0.6));
    return (center, target);
  }

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
  ArchitectSelectionOperation _selectionOperation =
      ArchitectSelectionOperation.replace;
  ArchitectSelectionRelation _selectionRelation =
      ArchitectSelectionRelation.crossing;
  bool _explicitSelectionOperation = false;
  ArchitectSelectionOperation get _activeSelectionOperation =>
      _explicitSelectionOperation
      ? _selectionOperation
      : (_multiSelect
            ? ArchitectSelectionOperation.add
            : ArchitectSelectionOperation.replace);
  (int, ArchitectProject)? _selectionPreviewKey;
  ({bool active, Set<String> result, Set<String> added, Set<String> removed})
  _selectionPreviewValue = (
    active: false,
    result: <String>{},
    added: <String>{},
    removed: <String>{},
  );
  List<Offset> get _marqueeEvaluationPolygon =>
      _marqueeTool.mode == ArchitectSelectMode.polygon
      ? _marqueeTool.finish()
      : _marqueeTool.previewPolygon;

  Set<String> _marqueeHits(List<Offset> polygon) {
    final hits = ArchitectMarqueeTool.evaluateSelection(
      storey: _project.activeStorey,
      project: _project,
      polygon: polygon,
      includeComponents: _showFurnitureLayer,
      relation: _selectionRelation,
      drawingViewKey: _workspaceViewKey,
    );
    final editingGroup = _editingGroup;
    if (editingGroup != null) return hits.intersection(editingGroup.elementIds);
    if (_selectionRelation == ArchitectSelectionRelation.contained) {
      for (final group in _project.activeStorey.groups) {
        if (!hits.containsAll(group.elementIds)) {
          hits.removeAll(group.elementIds);
        }
      }
    }
    return _project.activeStorey.expandGroups(hits);
  }

  ({bool active, Set<String> result, Set<String> added, Set<String> removed})
  get _selectionPreview {
    if (!_marqueeTool.isDrafting ||
        !ArchitectPolygonGeometry.valid(_marqueeEvaluationPolygon)) {
      return (
        active: false,
        result: _effectiveSelection,
        added: <String>{},
        removed: <String>{},
      );
    }
    final key = (_previewRevision.value, _project);
    if (_selectionPreviewKey != key) {
      final current = Set<String>.of(_effectiveSelection);
      final result = ArchitectMarqueeTool.combine(
        current,
        _marqueeHits(_marqueeEvaluationPolygon),
        _activeSelectionOperation,
      );
      _selectionPreviewValue = (
        active: true,
        result: result,
        added: result.difference(current),
        removed: current.difference(result),
      );
      _selectionPreviewKey = key;
    }
    return _selectionPreviewValue;
  }

  void _setSelectionOperation(ArchitectSelectionOperation operation) {
    setState(() {
      _cancelActiveDrags();
      _marqueeTool.cancel();
      _moveSelection = false;
      _selectionOperation = operation;
      _explicitSelectionOperation = true;

      _selectionCyclePoint = null;
      _interactionEpoch++;
    });
    _repaintPreview();
  }

  void _setSelectionRelation(ArchitectSelectionRelation relation) {
    setState(() {
      _cancelActiveDrags();
      _marqueeTool.cancel();
      _selectionRelation = relation;
      _interactionEpoch++;
    });
    _repaintPreview();
  }
  Offset? _selectionBoxDown;
  Offset? _selectionBoxDownScreen;
  bool _selectionBoxDragging = false;
  bool get _showSelectionActions =>
      (_effectiveSelection.isNotEmpty ||
          _isZoneTableSelected ||
          (_multiSelect && !_explicitSelectionOperation)) &&
      _dragController.isIdle &&
      !_marqueeTool.isDrafting &&
      !_is3DView &&
      _radialMenuScreenPosition == null &&
      _newPointTargetId == null &&
      _pendingDetachWallIds == null &&
      _wallAttachSourceId == null;
  bool get _showSelectionControl => _multiSelect &&
      _dragController.isIdle &&
      _radialMenuScreenPosition == null && !_moveSelection && _newPointTargetId == null && _offsetOptions == null &&
      _duplicateMove == null && _rotationSource == null && !_mirrorActive &&
      !_splitActive && _wallCutIds.isEmpty && _wallExtendId == null &&
      _cutOpeningTargetId == null && !_terrainDrafting;

  Set<String> _groupDragIds = {};

  bool get _multiSelect => _interactionMode == ArchitectInteractionMode.multiSelect;
  set _multiSelect(bool value) {
    if (value) {
      _tool = ArchitectTool.select;
      _interactionMode = ArchitectInteractionMode.multiSelect;
    } else if (_multiSelect) {
      _interactionMode = ArchitectInteractionMode.singleSelect;
    }
  }

  // Auto-picked tools expose editing; drawing starts only after a tool command.

  bool get _selectionContextActive => _interactionMode == ArchitectInteractionMode.contextEdit;
  set _selectionContextActive(bool value) {
    if (_manualSelection) return;
    if (value) {
      _interactionMode = ArchitectInteractionMode.contextEdit;
    } else if (_selectionContextActive) {
      _interactionMode = _tool == ArchitectTool.pan
          ? ArchitectInteractionMode.navigation : ArchitectInteractionMode.drawing;
    }
  }

  bool get _acceptsAnySelection => _manualSelection || _canAdoptPickedTool;

  bool _moveSelection = false;

  ArchitectCommandPreview? _commandPreview;
  ArchitectProject? _commandLiveCandidate;
  ArchitectRadialAction? _commandAction;
  ({
    Set<String> ids,
    String? element,
    String? zone,
    ArchitectTool tool,
    ArchitectInteractionMode mode,
    bool contextActive,
    String? group,
    String? contour,
    int ring,
    String? polygonEdit,
    int? polygonEdge,
    ArchitectDraftingSeed? seed,
    ArchitectTool? quickTool,
    ArchitectWallType? wallType,
    double wallThickness,
  })?
  _commandSelection;

  Object get _commandContext => (
    _modelCommands.project,
    _commands.view,
    _commands.viewId,
    _commands.documentProject.activeStoreyId,
  );
  bool get _commandReady => _commandPreview?.ready == true;
  bool get _commandCanConfirm =>
      _commandReady ||
      _commandLiveCandidate != null ||
      (_elementMovePreview != null && _elementMoveDelta != null && _elementMoveDelta != Offset.zero) ||
      (_newPointTargetId != null && _newPointValid) ||
      (_commandAction == ArchitectRadialAction.cutOpening &&
          _canConfirmContour);

  void _beginGeometryCommand(ArchitectRadialAction action) {
    if (_commandPreview != null && !_commandReady && _commandAction == action) {
      return;
    }
    _discardGeometryCommand();
    _commandSelection = (
      ids: Set<String>.of(_selectionIds),
      element: _selectedElementId,
      zone: _selectedZoneId,
      tool: _activeTool,
      mode: _interactionMode,
      contextActive: _selectionContextActive,
      group: _editingGroupId,
      contour: _polygonContourElementId,
      ring: _polygonContourIndex,
      polygonEdit: _polygonEditId,
      polygonEdge: _polygonSelectedEdge,
      seed: _draftingSeed,
      quickTool: _quickDrawingTool,
      wallType: _activeWallType,
      wallThickness: _wallThickness,
    );
    _commandAction = action;
    _commandPreview = ArchitectCommandPreview(
      action: action.name,
      document: _modelCommands.project,
      context: _commandContext,
      original: _commands.documentProject,
    );
    setState(() {});
  }

  bool _captureGeometryPreview(ArchitectProject next) {
    final session = _commandPreview;
    if (session == null) return false;
    if (!identical(session.document, _modelCommands.project)) {
      _discardGeometryCommand();
      return true;
    }
    next = _prepareGeometryPreview(next);
    session.stage(_commandContext, next);
    _commands.editPreview = next;
    setState(() {});
    _repaintPreview();
    return true;
  }

  ArchitectProject _prepareGeometryPreview(ArchitectProject next) {
    // Room updates belong to the same transaction as their wall edit.
    if (_commands.isPlan) {
      final storey = next.activeStorey;
      final zones = storey.zones.map((originalZone) {
        final zone =
            (_commandAction == ArchitectRadialAction.move ||
                    _commandAction == ArchitectRadialAction.edit) &&
                _effectiveSelection.contains(originalZone.id)
            ? originalZone.copyWith(isAutoBoundary: false)
            : originalZone;
        return zone.isAutoBoundary
            ? ArchitectRoomDetector.automaticZone(zone, storey.walls) ?? zone
            : zone;
      }).toList();
      next = _modelCommands.prepare(
        next.updateActiveStorey(storey.copyWith(zones: zones)),
      );
    } else {
      next = ArchitectDimensionChain.resolve(next);
    }
    return next;
  }

  void _discardGeometryCommand() {
    final selection = _commandSelection;
    if (_commandPreview == null) return;
    _commandLiveCandidate = null;
    _viewDraft = null;
    _commandPreview!.cancel();
    _commandPreview = null;
    _commandAction = null;
    _commandSelection = null;
    _commands.editPreview = null;
    _cancelActiveDrags();
    _mirrorActive = false;
    _mirrorReview = false;
    _mirrorDirection = null;
    _mirrorAnchor = null;
    _mirrorCurrentPoint = null;
    _mirrorIdMap = null;
    _splitActive = false;
    _splitWallIds.clear();
    _splitPoint1 = null;
    _splitPoint2 = null;
    _splitWaitingForSide = false;
    _splitPerpendicularNormal = null;
    _splitGuidePerpendicular = null;
    _wallCutIds = {};
    _wallCutConfirmedDir = null;
    _wallCutStroke = false;
    _wallCutStart = null;
    _wallExtendId = null;
    _wallJoinSourceId = null;
    _chamferFilletSourceId = null;
    _chamferFilletOptions = null;
    _chamferFilletPointer = null;
    _curvingEdgeElementId = null;
    _curvingEdgeSegmentIndex = null;
    _curvingEdgeStartPoint = null;
    _curvingEdgeEndPoint = null;
    _curvingEdgeBulge = 0.0;
    _curvingEdgeExactBulge = null;
    _isCurvingEdgeDragging = false;
    _curvingEdgeSnapped = false;
    _curvingEdgeSnapLabel = null;
    _curvingEdgePendingConfirmation = false;
    _curvingDragScreenOffset = Offset.zero;
    _newPointTargetId = null;
    _newPointCandidate = null;
    _newPointSource = null;
    _newPointValid = false;
    _newPointDragOffset = Offset.zero;
    _newPointHoleIndex = null;
    _newPointLeaderLine = null;
    _newPointDistanceEditorOpen = false;
    _newPointExactPlacement = false;
    _polygonEditId = null;
    _polygonSelectedEdge = null;
    _cutOpeningTargetId = null;
    _elementTool.cancelSlabDrafting();
    _moveSelection = false;
    _transverseMove = false;
    if (selection != null) {
      _selectionIds
        ..clear()
        ..addAll(selection.ids);
      _selectedElementId = selection.element;
      _selectedZoneId = selection.zone;
      _activeTool = selection.tool;
      _interactionMode = selection.mode;
      _selectionContextActive = selection.contextActive;
      _editingGroupId = selection.group;
      _polygonContourElementId = selection.contour;
      _polygonContourIndex = selection.ring;
      _polygonEditId = selection.polygonEdit;
      _polygonSelectedEdge = selection.polygonEdge;
      _draftingSeed = selection.seed;
      _quickDrawingTool = selection.quickTool;
      _activeWallType = selection.wallType;
      _wallThickness = selection.wallThickness;
    }
  }

  void _cancelGeometryCommand() {
    setState(_discardGeometryCommand);
    _repaintPreview();
  }

  void _confirmGeometryCommand() {
    if (_newPointTargetId != null) {
      if (!_newPointValid) return;
      _commitNewPoint();
    }
    if (_commandLiveCandidate case final candidate?) {
      _commands.commit(candidate);
    } else if (_elementMovePreview != null) {
      _commands.commit(_elementMovePreview!);
    }
    if (!_commandReady &&
        _commandAction == ArchitectRadialAction.cutOpening &&
        _canConfirmContour) {
      _commitCutOpening();
    }
    final session = _commandPreview;
    if (session == null || !session.ready) return;
    final next = session.confirm(_commandContext);
    if (next == null) {
      _cancelGeometryCommand();
      return;
    }
    final ids = Set<String>.of(_effectiveSelection);
    final configuration = _commandSelection;
    _discardGeometryCommand();
    try {
      _commands.commit(next);
      final valid = ArchitectSelection.records(
        _project.toJson(),
        _project.activeStoreyId,
      ).map((e) => e['id'] as String).toSet();
      setState(() {
        _selectionIds
          ..clear()
          ..addAll(ids.intersection(valid));
        _selectedElementId = _selectionIds.firstOrNull;
        _selectedZoneId = null;
        if (configuration != null) {
          _draftingSeed = configuration.seed;
          _quickDrawingTool = configuration.quickTool;
          _activeWallType = configuration.wallType;
          _wallThickness = configuration.wallThickness;
        }
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.mediumImpact();
    } on ArgumentError {
      _operationError();
    }
    _repaintPreview();
  }

  Offset _commandFloatingPosition(Size screenSize) {
    Offset? modelTarget;
    if (_newPointCandidate != null) {
      modelTarget = _newPointCandidate;
    } else if (_elementMoveDelta != null && _effectiveSelection.isNotEmpty) {
      Rect? combined;
      for (final id in _effectiveSelection) {
        final b = ArchitectSelection.bounds(_project, id);
        if (b != null) combined = combined == null ? b : combined.expandToInclude(b);
      }
      if (combined != null) {
        modelTarget = combined.center + _elementMoveDelta!;
      }
    } else if (_cursorModel != null) {
      modelTarget = _cursorModel;
    } else if (_effectiveSelection.isNotEmpty) {
      Rect? combined;
      for (final id in _effectiveSelection) {
        final b = ArchitectSelection.bounds(_project, id);
        if (b != null) combined = combined == null ? b : combined.expandToInclude(b);
      }
      if (combined != null) {
        modelTarget = combined.center;
      }
    }

    Offset screenPos;
    if (modelTarget != null) {
      screenPos = _viewport.toScreen(modelTarget);
    } else {
      screenPos = Offset(screenSize.width / 2, screenSize.height / 2);
    }

    final x = (screenPos.dx - 60).clamp(16.0, screenSize.width - 170.0);
    final y = (screenPos.dy - 60).clamp(48.0, screenSize.height - 110.0);
    return Offset(x, y);
  }

  String? _editingGroupId;

  ArchitectElementGroup? get _editingGroup => _project.activeStorey.groups.where((g) => g.id == _editingGroupId).firstOrNull;

  ArchitectElementGroup? get _selectedGroup {

    if (!_commands.isPlan || _editingGroupId != null) return null;

    final ids = _effectiveSelection;

    return _project.activeStorey.groups.where((g) => g.elementIds.length == ids.length && g.elementIds.containsAll(ids),
        ).firstOrNull;

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
  ArchitectProject? _hatchTransformSource;
  int _hatchTransformEpoch = 0;

  BimElementOffsetOptions? _offsetOptions;

  ArchitectProject? _offsetSource;

  Set<String> _offsetIds = {};

  Map<String, String> _offsetIdMap = {}, _offsetGroupIdMap = {};

  Offset? _offsetSide;

  bool _offsetValid = false;

  int _offsetEpoch = 0;

  bool _mirrorIsDuplicate = false;
  bool _mirrorReview = false;
  Offset? _mirrorDirection;

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
  ArchitectStorey? _newPointSource;
  bool _newPointValid = false;
  bool _newPointDistanceEditorOpen = false;
  bool _newPointExactPlacement = false;
  Offset _newPointDragOffset = Offset.zero;
  Offset _newPointGripDirection = const Offset(0, -1);

  Offset get _newPointGripOffset =>
      _newPointGripDirection * (_handleOffsetLength > 0 ? _handleOffsetLength : 48);

  Offset? get _newPointGrip => _newPointCandidate == null ? null :
      _viewport.toScreen(_newPointCandidate!) + _newPointGripOffset;



  bool _touchInput = false;

  bool _placingWithHold = false;

  bool _wallPrecisionMode = true;

  Offset? _touchPosition;

  ArchitectWall? _wallEndpointOriginal;

  // --- SUBSECTION: [TAG:WALL_ENDPOINT_ANGLE] Endpoint angle constraint and fine adjustment ---
  String? _wallAngleUnlockedId;

  Widget _buildWallAngleOverlay() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (context, _) {
        final selected = _selectedWall;
        if (!_commands.isPlan ||
            _printPreview ||
            selected == null ||
            selected.isCurved ||
            _effectiveSelection.length != 1 ||
            _commandPreview != null ||
            _moveSelection ||
            _mirrorActive ||
            _splitActive ||
            _offsetOptions != null ||
            _rotationSource != null ||
            _duplicateMove != null ||
            _newPointTargetId != null ||
            _wallCutIds.isNotEmpty ||
            _wallExtendId != null ||
            _wallJoinSourceId != null ||
            _wallAttachSourceId != null ||
            _pendingDetachWallIds != null ||
            _curvingEdgeElementId != null ||
            _radialMenuScreenPosition != null) {
          return const SizedBox.shrink();
        }
        final wall = _drawingProject.activeStorey.walls
            .where((w) => w.id == selected.id)
            .firstOrNull;
        if (wall == null) return const SizedBox.shrink();
        return ArchitectWallAngleControl(
          wall: wall,
          walls: _drawingProject.activeStorey.walls,
          locked: _wallAngleUnlockedId != wall.id,
          toScreen: _viewport.toScreen,
          toModel: _screenToModel,
          handleClearance: _handleOffsetLength,
          onToggle: _isDraggingVertexOrHandle
              ? null
              : () {
                  setState(() {
                    _wallAngleUnlockedId =
                        _wallAngleUnlockedId == wall.id ? null : wall.id;
                  });
                  HapticFeedback.selectionClick();
                },
        );
      },
    ),
  );

  ArchitectProject? _wallSnapProject;

  bool _wallDragStart = false;

  Offset _wallGrabOffset = Offset.zero;

  bool _wallEndpointIsOffset = false;

  Offset _wallEndpointDisplacement = Offset.zero;

  (Offset, Offset)? _wallEndpointLeaderLine;

  bool _transverseMove = false;

  ArchitectLineStyle _activeCadLineStyle = ArchitectLineStyle.solid;
  ArchitectLineEndCap _activeLineStartCap = ArchitectLineEndCap.none;
  ArchitectLineEndCap _activeLineEndCap = ArchitectLineEndCap.none;
  double _activeLineCapSize = 0.20;
  double? _activePolylineWidth;
  bool _polylineArcSegmentMode = false;
  bool _maskBorder = true;
  RoofSlopeFormat _activeRoofSlopeFormat = RoofSlopeFormat.percent;
  RoofSlopeDirection _activeRoofSlopeDirection = RoofSlopeDirection.downslope;
  ArchitectLineEndCap _activeLeaderArrowStyle = ArchitectLineEndCap.arrowFilled;
  double _activeLeaderArrowSize = 0.18;

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
      applyDraftingDefaults: true,
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
    precisionMode: _wallPrecisionMode,
    onPrecisionToggle: () => setState(() => _wallPrecisionMode = !_wallPrecisionMode),
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

    final points = List<Offset>.unmodifiable(contour?.polygon ?? _elementTool.slabDraftPoints,
    );

    if (!ArchitectPolygonGeometry.valid(points)) { _operationError(); return; }

    final bounds = ArchitectSceneGeometry.boundsOf(points);

    try {

      _commands.execute(PlaceArchitectCadPrimitive(storeyId: _project.activeStoreyId,

        primitive: ArchitectCadPrimitive(id: ArchitectElementId.next('hatch'),

          type: CadPrimitiveType.hatch, startPoint: bounds.topLeft, endPoint: bounds.bottomRight,

          polygon: points, holes: contour?.holes ?? const [], hatchPattern: _activeHatchPattern,
          colorValue: _activeHatchColor.argb, colorPresetId: _activeHatchColor.presetId,
          ),
        ),
      applyDraftingDefaults: true,
    );

      setState(_elementTool.cancelSlabDrafting);

      _saveBiMProjectIfAttached(); HapticFeedback.mediumImpact();

    } on ArgumentError { _operationError(); }

  }

  void _startCutOpening(String id) {
    _beginGeometryCommand(ArchitectRadialAction.cutOpening);

    _cancelActiveDrags();
    _resetWallDraft();

    setState(() {

      _cutOpeningTargetId = id;
      _selectionIds.clear();
      _selectedElementId = null;
      _selectedZoneId = null;
      _polygonEditId = null;
      _moveSelection = false;
      _transverseMove = false;

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

        polygon: List.of(_elementTool.slabDraftPoints),
        ),
      );

      _cutOpeningTargetId = null;
      _elementTool.cancelSlabDrafting();

      _saveBiMProjectIfAttached();

      HapticFeedback.mediumImpact();

    } on ArgumentError {

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(

        content: Text(context.l10n.architectCutOpeningInvalid)),
      );

    }

  }



  Widget _cutOpeningControl() => Material(

    color: Theme.of(context).colorScheme.surface,

    borderRadius: BorderRadius.circular(8),

    child: Row(children: [

      Expanded(child: Tooltip(

        message: context.l10n.architectCutOpeningHint,

        child: Padding(padding: const EdgeInsets.only(left: 12),

          child: Text(context.l10n.architectCutOpening),
            ),
          ),
        ),

      IconButton(key: const ValueKey('opening-draft-undo'),

        tooltip: context.l10n.undoAction, icon: const AppIcon(AppIconId.undo),

        onPressed: _elementTool.slabDraftPoints.isEmpty ? null : () => setState(() {

          _elementTool.slabDraftPoints.removeLast();

          _elementTool.slabCandidatePoint = null;

        }),
        ),

      if (_commandPreview == null) IconButton(key: const ValueKey('opening-draft-finish'),

        tooltip: context.l10n.architectCutOpening,

        icon: const AppIcon(AppIconId.confirm),

        onPressed: _canConfirmContour ? _commitCutOpening : null,
          ),

      if (_commandPreview == null) IconButton(key: const ValueKey('opening-draft-cancel'),

        tooltip: context.l10n.cancel, icon: const AppIcon(AppIconId.close),

        onPressed: _cancelDrafting,
          ),

    ],
    ),

  );



  Widget _lineStyleControl() => Theme(

    data: ThemeData.dark(),

    child: ArchitectLineStylePicker(

      key: const ValueKey('architect-draft-line-style'),

      value: _activeCadLineStyle,

      compact: true,

      customStyles: _project.lineStyles,

      onDeleteStyle: (style) {
        _commands.execute(DeleteArchitectLineStyle(style.id));
        ArchitectLineStyleLibrary.delete(style.id);
        _saveBiMProjectIfAttached();
        if (_activeCadLineStyle.id == style.id) {
          setState(() => _activeCadLineStyle = ArchitectLineStyle.solid);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.architectLineStyleDeleted)),
        );
      },

      onChanged: (style) {

        final polylineId = _polylineDraftId;
        if (polylineId != null && _project.activeStorey.cadPrimitives
            .any((p) => p.id == polylineId,
            )) {
          _commands.execute(SetArchitectElementProperties(
            storeyId: _project.activeStoreyId, elementIds: {polylineId},
            textValues: {'lineStyle': jsonEncode(style.toJson())},
          ),
          );
          _saveBiMProjectIfAttached();
        }

        if (!style.isPreset && !_project.lineStyles.any((s) => s == style)) {

          _commands.execute(SaveArchitectLineStyle(style));
          ArchitectLineStyleLibrary.save(style);

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
      _activeTool == ArchitectTool.cadArc ||
      _activeTool == ArchitectTool.section ||
      _activeTool == ArchitectTool.elevation;



  Set<String> get _selectedLineIds => _project.activeStorey.cadPrimitives
      .where(
        (p) =>
            (p.type == CadPrimitiveType.line || p.type == CadPrimitiveType.arc) &&
            _effectiveSelection.contains(p.id),
      )
      .map((p) => p.id)
      .toSet();



  ArchitectWall? get _selectedLinearElement {
    if (_effectiveSelection.length != 1) return null;
    final id = _effectiveSelection.single;
    final line = _project.activeStorey.cadPrimitives
        .where((p) => p.id == id && (p.type == CadPrimitiveType.line || p.type == CadPrimitiveType.arc))
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
          .where((p) => p.type == CadPrimitiveType.line || p.type == CadPrimitiveType.arc)
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
        ),
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
        ),
      ];
    }
    return _project.activeStorey.walls;
  }



  ArchitectModelCommand _linearCommand(ArchitectModelCommand command) =>

      ArchitectLineEditing.adapt(_project, command);



  String? _wallEndpointClearanceId;
  String? _activeWallClearanceKey;

  void _setSelectionMove(ArchitectSelectionMoveAction action) {
    if (action == ArchitectSelectionMoveAction.free) {
      _startDragSession();
      return;
    }
    if (action == ArchitectSelectionMoveAction.offset) {
      _editMoveOffset();
      return;
    }
    if (action == ArchitectSelectionMoveAction.stop) {
      _cancelGeometryCommand();
      return;
    }
    _beginGeometryCommand(ArchitectRadialAction.move);
    _cancelActiveDrags();
    setState(() {
      _radialMenuScreenPosition = null;
      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _wallCutIds = {};
      _transverseMove = action == ArchitectSelectionMoveAction.transverse;
      _moveSelection = action != ArchitectSelectionMoveAction.stop;
    });
  }

  Future<void> _editMoveOffset() async {
    _beginGeometryCommand(ArchitectRadialAction.move);
    final wall = _selectedLinearElement;
    if (wall == null || wall.isCurved || _effectiveSelection.length != 1) return;
    final source = _project;
    _cancelActiveDrags();
    final value = await showArchitectAxisValueDialog(
      context: context,
      title: context.l10n.architectSelectionMove,
      label: '${context.l10n.offsetAction} (${_project.units.symbol})',
      value: '0',
      numeric: true,
    );
    if (mounted && value == null) { _cancelGeometryCommand(); return; }
    if (!mounted ||
        value == null ||
        !identical(source, _project) ||
        _effectiveSelection.length != 1 ||
        !_effectiveSelection.contains(wall.id)) {
      return;
    }
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
      _transverseMove = true;
      _moveSelection = true;
    });
  }

  Offset _constrainMoveDelta(Offset delta, Set<String> ids) {

    if (!_transverseMove || ids.length != 1) return delta;

    final floor = (_elementMoveOriginal ?? _project).activeStorey;

    final wall = [

      ...floor.walls,

      ...floor.cadPrimitives
          .where((p) => p.type == CadPrimitiveType.line || p.type == CadPrimitiveType.arc)
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
    if (_is3DView || _commandPreview != null) return null;
    final all = ArchitectWallOvershootDetector.detectInStorey(
      _project.activeStorey, ignoredIds: _dismissedOvershoots,
    );
    if (_selectedWallIds.length == 1) {
      final selected = all.where((os) => os.wall.id == _selectedWallIds.first).firstOrNull;
      if (selected != null) return selected;
    }
    return all.firstOrNull;
  }

  void _handleTrimOvershoot(ArchitectWallOvershoot overshoot) {
    final commands = ArchitectWallOvershootDetector.createTrimCommands(
      storeyId: _project.activeStoreyId, overshoot: overshoot,
    );
    if (commands.isEmpty) return;
    _beginGeometryCommand(ArchitectRadialAction.cut);
    _commands.executeBatch(commands);
    if (!_commandReady) {
      _cancelGeometryCommand();
      return;
    }
    HapticFeedback.selectionClick();
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

  Offset? _servicePreviewPoint;

  double _servicePreviewRotation = 0.0;

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

  bool _doorHasCasing = false;



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
    _beginGeometryCommand(ArchitectRadialAction.duplicate);

    _cancelActiveDrags();

    final (floor, copyId) = _elementTool.duplicateElementById(

      _project.activeStorey,

      id,

      offset: Offset.zero,

    );

    if (copyId == null) return;

    var draft = _project.updateActiveStorey(floor).copyWith(document:_project.document.copyElementOverrides({id:copyId}));

    if (_editingGroupId != null) {

      draft = AddArchitectGroupMembers(storeyId: _project.activeStoreyId,

        groupId: _editingGroupId!, elementIds: {copyId},
      ).apply(draft);

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

      frame: _effectiveUnderlayFrame,

      visibility: _effectiveUnderlayLayerVisibility,

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

      if (_commandPreview != null) {
        _captureGeometryPreview(normalized);
      }

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

      _draggingRasterId != null ||

      _groupDragIds.isNotEmpty;



  /// Whether gestures should be captured exclusively by the tool instead of panning.

  bool get _isActivelyDraggingHandle =>
      _draftCancelPointer != null ||
      _isDraggingVertexOrHandle ||
      _wallCutIds.isNotEmpty ||
      _wallExtendId != null ||
      _wallJoinSourceId != null ||
      _dragController.isActive ||
      _curvingEdgeElementId != null ||
      _chamferFilletSourceId != null ||
      _wallAttachSourceId != null;



  // --- SUBSECTION: [TAG:STATE_LIFECYCLE] Lifecycle: initState & dispose ---
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



    _commands = ArchitectWorkspaceViewController(_modelCommands)
      ..previewEdit = _captureGeometryPreview
      ..prepareCreation = (previous, next) => _interactionMode == ArchitectInteractionMode.drawing
          ? _draftingSeed?.apply(previous, next) ?? next : next;

    _commands.addListener(_onModelChanged);
    _viewport.addListener(_onTouchViewportChanged);

    unawaited(_loadWorkspacePreferences());



    _restoreWallType();

    unawaited(_loadWallTypePreference());



    _zoneTool = ArchitectZoneTool()..addListener(_repaintPreview);



    _axisTool = ArchitectGridAxisTool()..addListener(_repaintPreview);



    _elementTool = ArchitectElementTool()..addListener(_repaintPreview);



    _roofTool = ArchitectRoofTool()..addListener(_repaintPreview);
    _landscapeTool = ArchitectLandscapeTool()..addListener(_repaintPreview);
    ArchitectDecorativeLibraryService.instance.init();

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

    unawaited(_restorePersistedUnderlays());



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

        _activeTool = ArchitectTool.pan;

      });

      unawaited(_restorePersistedUnderlays());

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

      final source = _effectiveUnderlayFrame.rectToModel(underlay.bounds);

      bounds = bounds == Rect.zero ? source : bounds.expandToInclude(source);

    }

    _viewport.fit(

      bounds == Rect.zero ? const Rect.fromLTRB(-5, -5, 15, 15) : bounds,

      padding: 80,

    );

  }



  @override

  void dispose() {
    _dragController.dispose();

    _cadFileWatcher?.dispose();

    _sectionLoader.dispose();
    _facadeLoader.dispose();

    ComponentLibraryService.instance.removeListener(_onComponentLibraryChanged);

    if (_saveTimer != null) {

      unawaited(_flushSave());

    }

    _openingCooldownTimer?.cancel();

    _viewport.removeListener(_onTouchViewportChanged);
    _commands.removeListener(_onModelChanged);

    _commands.dispose();

    if (widget.commandController == null) _modelCommands.dispose();

    _zoneTool.dispose();

    _axisTool.dispose();

    _elementTool.dispose();

    _roofTool.dispose();
    _landscapeTool.dispose();

    _viewport.dispose();

    _camera3D.dispose();

    _previewRevision.dispose();

    super.dispose();

  }



  // === SECTION: [SEC-03-XFORM] COORDINATE TRANSFORMS (SCREEN <-> MODEL) ===
  // --- SUBSECTION: [TAG:XFORM_COORDS] Screen <-> Model Space & Snapping ---



  Offset _screenToModel(Offset screenPos) {

    return _viewport.toModel(screenPos);

  }

  Offset _modelToScreen(Offset modelPos) {
    return _viewport.toScreen(modelPos);
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

    final tol = math.max(26.0 / _currentScale, wall.thickness / 2.0 + 0.05);

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
    final cat = zone.category;
    final presetFloor = _zonePresets.defaultFloorFinish(cat, l);
    final presetWall = _zonePresets.defaultWallFinish(cat, l);
    final presetCeiling = _zonePresets.defaultCeilingFinish(cat, l);
    return zone.copyWith(
      floorFinish: zone.floorFinish.isNotEmpty ? zone.floorFinish : presetFloor,
      wallFinish: zone.wallFinish.isNotEmpty ? zone.wallFinish : presetWall,
      ceilingFinish: zone.ceilingFinish.isNotEmpty ? zone.ceilingFinish : presetCeiling,
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

            zone: _applyZoneFinishPresets(newZone,
            ).copyWith(kind: _activeZoneKind),

          ),
      applyDraftingDefaults: true,
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



  // === SECTION: [SEC-04-TOUCH] 2D POINTER & TOUCH HANDLING (TOOL INPUT FROM ARCHITECT VIEWPORT) ===
  // --- SUBSECTION: [TAG:TOUCH_DOWN] _onPointerDown Input Dispatch ---



  void _onPointerDown(PointerDownEvent event) {
    if (_commandReady) return;
    _dismissTouchCandidates();
    if (_interactionMode == ArchitectInteractionMode.navigation &&
        !_terrainDrafting && !_dragController.isActive) {
      _touchInput = event.kind == PointerDeviceKind.touch;
      _handlePointerDown = event.localPosition;
      _handleMoved = false;
      return;
    }

    if (_draftOverlayContains(event.localPosition)) {

      _draftCancelPointer = event.pointer;

      return;

    }

    // Only an explicit canvas gesture resumes three-point shaping. Hover must
    // never replace a curvature entered with the numeric editor.
    if (_wallArcEnd != null) _draftArcExactBulge = null;

    if (_radialMenuScreenPosition != null) {

      setState(() => _radialMenuScreenPosition = null);

    }

    _touchInput = event.kind == PointerDeviceKind.touch;

    _handlePointerDown = event.localPosition;

    _handleMoved = false;

    _isHandleEngaged = false;

    final rawModel = _screenToModel(event.localPosition);
    _lastTapModelPosition = rawModel;

    if (_dragController.isActive) {
      _placingWithHold = false;
      _touchPosition = null;
      if (_dragController.isPickingBasePoint) {
        _dragController.updateBaseHover(
          rawModel,
          project: _project,
          scale: _currentScale,
          dxfDoc: _currentUnderlayDoc,
          frame: _effectiveUnderlayFrame,
          raster: _selectedRasterUnderlay,
        );
        final base = _dragController.currentPointModel ?? rawModel;
        _dragPointerOffset = _dragController.currentSnapLabel == 'Grip'
            ? base - rawModel : Offset.zero;
        // The whole first gesture aims the base; only release locks it.
        _dragTargetPlaced = false;
        _isHandleEngaged = true;
        _updateDragAim(event.localPosition);
        HapticFeedback.selectionClick();
        setState(() {});
        return;
      } else if (_dragController.isDraggingToTarget) {
        _dragTargetPlaced = false;
        _dragPointerOffset = Offset.zero;
        _isHandleEngaged = true;
        _updateDragTarget(rawModel);
        _repaintPreview();
        setState(() {});
        return;
      }
    }

    if (_curvingEdgeElementId != null &&
        _curvingEdgeStartPoint != null &&
        _curvingEdgeEndPoint != null) {
      final p1 = _curvingEdgeStartPoint!;
      final p2 = _curvingEdgeEndPoint!;
      final chordMid = (p1 + p2) / 2;
      final arc = ArchitectWallArc(p1, p2, _curvingEdgeBulge);
      final handlePos = _curvingEdgeBulge.abs() > 1e-4 ? arc.midpoint : chordMid;
      final handleScreen = _viewport.toScreen(handlePos);
      final touchScreen = event.localPosition;
      final gripScreen = _curvingEdgeGripScreen;

      final hitGrip = gripScreen != null && (touchScreen - gripScreen).distance <= 48;
      final hitApex = (touchScreen - handleScreen).distance <= 48 || (rawModel - handlePos).distance <= 0.6;

      if (hitGrip || hitApex) {
        _isCurvingEdgeDragging = true;
        _isHandleEngaged = true;
        _curvingDragScreenOffset = hitGrip ? (gripScreen - touchScreen) : Offset.zero;
        _curvingEdgePendingConfirmation = false;
        HapticFeedback.lightImpact();
        setState(() {});
        _repaintPreview();
        return;
      }
    }

    if (_cadInsertionActive) {
      final snap = _snapDimensionPoint(rawModel);
      setState(() {
        _cadInsertionPendingPoint = snap.point;
        _cadInsertionHoverPoint = snap.point;
      });
      return;
    }

    if (_underlayMaskDrafting) {
      if (_underlayMaskMode == 'rect') {
        _underlayMaskDraftStart = rawModel;
        _underlayMaskPoints = [rawModel, rawModel, rawModel, rawModel];
        setState(() {});
        return;
      } else if (_underlayMaskMode == 'polygon') {
        setState(() {
          _underlayMaskPoints.add(rawModel);
        });
        return;
      }
    }

    if (_activeTool == ArchitectTool.rasterUnderlay &&
        _rasterCalibrationStep == 0) {
      final rasters = _project.rasterUnderlaysForStorey(
        _project.activeStorey.id,
      );
      for (final r in rasters.reversed) {
        if (r.containsLocalPoint(rawModel)) {
          setState(() => _selectedRasterId = r.id);
          if (!r.locked) {
            _draggingRasterId = r.id;
            _rasterDragStartModel = rawModel;
            _rasterDragOriginalPos = r.position;
            _isHandleEngaged = true;
          }
          return;
        }
      }
    }

    if (_offsetOptions != null) {

      _previewOffset(_screenToModel(_placementPosition(event.localPosition)));

      return;

    }

    if (_newPointTargetId != null) {
      if (_newPointDistanceEditorOpen) return;
      _newPointExactPlacement = false;
      _touchPosition = null;
      _placingWithHold = false;
      final grip = _newPointGrip;
      _newPointDragOffset = grip != null && (grip - event.localPosition).distance <= 24
          ? _viewport.toScreen(_newPointCandidate!) - event.localPosition
          : Offset.zero;
      _updateNewPointCandidate(
        _screenToModel(event.localPosition + _newPointDragOffset), isTouch: _touchInput,
      );
      return;
    }

    if (_showSelectionControl && _marqueeTool.isDrafting) {
      _selectionBoxDown = rawModel;
      _selectionBoxDownScreen = event.localPosition;
      return;
    }

    if (_showSelectionControl && _multiSelect && !_moveSelection) {
      if(_marqueeTool.mode==ArchitectSelectMode.rectangle) {
        _selectionBoxDown=rawModel;_selectionBoxDownScreen=event.localPosition;
      }
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
    if (_polygonEditId != null || _selectedRoof != null) {
      _selectPolygonEdge(rawModel);
    }

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

    if (_wallExtendId != null || _chamferFilletSourceId != null) return;

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

        ? () {
            final direct = ArchitectPolygonDimensions.hitEdge(
              polygon,
              rawModel,
              20 / _currentScale,
            );
            if (direct != null) return direct;
            if (_handleOffsetLength > 0) {
              var best = 28 / _currentScale;
              int? hitHandle;
              for (var i = 0; i < polygon.length; i++) {
                final handle = ArchitectPolygonEditor.offsetEdgeHandle(
                  polygon,
                  i,
                  _currentScale,
                  _handleOffsetLength,
                );
                final distance = (rawModel - handle).distance;
                if (distance <= best) {
                  hitHandle = i;
                  best = distance;
                }
              }
              return hitHandle;
            }
            return null;
          }()

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

                          : _polygonEdgeMode)

                    : _polygonEdgeMode,

                offsetLengthPx: _handleOffsetLength,

              ))) {
      if (movableEdge != null) {
        _polygonSelectedEdge = movableEdge;
      }
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

      final handlePt = ArchitectFloorDrainPainterHelper.offsetHandle(selectedDrain, clearance,
      );

      final offsetTol = math.max(28.0 / _currentScale, 0.35);

      final directTol = math.max(14.0 / _currentScale, selectedDrain.halfWidth + 0.1,
      );

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



    final polyline = _selectedPolyline ?? _selectedSpline;
    if (polyline != null && !_moveSelection && !_mirrorActive && _offsetOptions == null && _chamferFilletSourceId == null &&
        !_splitActive && _newPointTargetId == null) {
      final points = polyline.linePoints;
      final edgeHit = polyline.type == CadPrimitiveType.spline ? null : ArchitectPolylineEditing.hitEdge(points,rawModel,_currentScale,_handleOffsetLength);
      final hit = edgeHit ?? ArchitectPolylineEditing.hit(
          points, rawModel, _currentScale, _handleOffsetLength,
      );
      if (hit != null) {
        final (index, isOffset) = hit;
        _polylineEdgeDrag=edgeHit!=null;
        final point = _polylineEdgeDrag ? (points[index]+points[index+1])/2 : points[index];
        final handle = !isOffset ? point : _polylineEdgeDrag
          ? ArchitectPolylineEditing.edgeHandle(points,index,_currentScale,_handleOffsetLength)
          : ArchitectPolylineEditing.handle(points,index,_currentScale,_handleOffsetLength);
        _polylineVertexIndex = index;
        _wallDragStart = !_polylineEdgeDrag && index == 0;
        _wallEndpointOriginal = ArchitectWall(id: polyline.id,
          startPoint: _polylineEdgeDrag ? points[index] : points[index == 0 ? 0 : index - 1],
          endPoint: _polylineEdgeDrag ? point : points[index == 0 ? 1 : index], thickness: .001,
        );
        _wallEndpointIsOffset = isOffset;
        _wallEndpointDisplacement = handle - point;
        _wallGrabOffset = handle - rawModel;
        _wallEndpointLeaderLine = isOffset ? (point, handle) : null;
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

            if (_canAdoptPickedTool) {

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

      final midTol = math.max(16 / _currentScale, 0.35);

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
        _project.activeStorey.zoneScheduleOrigin != null) {
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
          if (!_multiSelect) {
            _selectionIds.clear();
          }
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



    if (_showSelectionControl && !_moveSelection &&
        _marqueeTool.mode == ArchitectSelectMode.rectangle) {
      _selectionBoxDown = rawModel;
      _selectionBoxDownScreen = event.localPosition;
    }

    // No handle engaged on pointer-down: free pan/zoom candidate

    ArchitectLogger.log(

      'VIEWPORT',

      'Pointer down at $rawModel - no handle hit, tool input candidate',

    );

  }



  // --- SUBSECTION: [TAG:TOUCH_MOVE] _onPointerMove Input Dispatch & Previews ---
  void _onPointerMove(PointerMoveEvent event) {
    if (_commandReady) return;
    if (_dragController.isActive) {
      _updateDragAim(event.localPosition);
      setState(() {});
      return;
    }
    if (_underlayMaskDrafting &&
        _underlayMaskMode == 'rect' &&
        _underlayMaskDraftStart != null) {
      final p1 = _underlayMaskDraftStart!;
      final p2 = _screenToModel(event.localPosition);
      final minX = math.min(p1.dx, p2.dx);
      final maxX = math.max(p1.dx, p2.dx);
      final minY = math.min(p1.dy, p2.dy);
      final maxY = math.max(p1.dy, p2.dy);
      setState(() {
        _underlayMaskPoints = [
          Offset(minX, minY),
          Offset(maxX, minY),
          Offset(maxX, maxY),
          Offset(minX, maxY),
        ];
      });
      return;
    }
    if (_interactionMode == ArchitectInteractionMode.navigation && !_terrainDrafting) return;
    if (_selectionBoxDown != null && _selectionBoxDownScreen != null &&
        _marqueeTool.mode == ArchitectSelectMode.rectangle) {
      if (_selectionBoxDragging || (event.localPosition - _selectionBoxDownScreen!).distance > 8) {
        if (!_marqueeTool.isDrafting) {
          setState(() => _marqueeTool.addPoint(_selectionBoxDown!));
        }
        _selectionBoxDragging = true;
        _marqueeTool.updateCandidate(_screenToModel(event.localPosition));
        _repaintPreview();
      }
      return;
    }

    if (_draftCancelPointer == event.pointer) return;
    // Explicit unlock permits a fine nudge without a large initial excursion.
    final fineEndpointAdjustment = _wallEndpointOriginal != null &&
        _wallEndpointOriginal!.id == _wallAngleUnlockedId;

    if (_touchInput &&

        _isActivelyDraggingHandle &&

        !_handleMoved &&

        _handlePointerDown != null &&

        (event.localPosition - _handlePointerDown!).distance <=
            (fineEndpointAdjustment ? 1 : 6)) {

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

    if (_dragController.isActive) {
      _placingWithHold = true;
      _updateDragAim(point);
      HapticFeedback.selectionClick();
      return;
    }

    if (_draftCancelPointer != null) return;

    if (!_canPlaceWithMarker) return;

    if (_effectiveSelection.isNotEmpty &&

        _wallCutIds.isEmpty &&

        _wallExtendId == null &&

        !_mirrorActive &&

        _offsetOptions == null &&

        !_splitActive && _newPointTargetId == null) {
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

      (_dragController.isActive ||
          (_activeTool != ArchitectTool.select && _activeTool != ArchitectTool.pan && !_selectionContextActive) ||

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

      hasCasing: _doorHasCasing,

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

      hasCasing: _elementTool.windowHasCasing,

    );

  }



  Offset? get _placementPreviewTarget {

    if (_dragController.isActive) return _dragController.currentPointModel;

    final raw = _cursorModel;

    if (raw != null &&

        (_activeTool == ArchitectTool.door ||

            _activeTool == ArchitectTool.window)) {

      final preview = _openingPlacementPreview;

      if (preview != null) return preview.centerPoint;

    }

    if (_activeTool == ArchitectTool.services && _servicePreviewPoint != null) {
      return _servicePreviewPoint;
    }

    if (_activeTool == ArchitectTool.column && _columnPreviewPoint != null) {
      return _columnPreviewPoint;
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

        frame: _effectiveUnderlayFrame,

        visibility: _effectiveUnderlayLayerVisibility,

      );



  ArchitectSnapResult _snapElement(Offset raw, {Offset? anchor, double? tolerancePixels,
  }) {

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

            tolerance: (tolerancePixels ?? (_touchInput ? 12 : 8)) / _currentScale,

            magnetic: _magnetEnabled,

            alignment: true,

            underlay: _currentUnderlayDoc,

            frame: _effectiveUnderlayFrame,

            visibility: _effectiveUnderlayLayerVisibility,

          )

        : ArchitectSnapHelper.snapWithAnchor(

            midpointReferences: _midpointTracking.references,

            rawPoint: raw,

            anchor: anchor,

            project: _project,

            tolerance: (tolerancePixels ?? (_touchInput ? 12 : 8)) / _currentScale,

            magnetic: _magnetEnabled,

            alignment: true,

            underlay: _currentUnderlayDoc,

            frame: _effectiveUnderlayFrame,

            visibility: _effectiveUnderlayLayerVisibility,

          );

    _activeSnapLabel = snap.snapLabel;

    _activeMagneticGuides = snap.magneticGuides;

    return snap;

  }



  ArchitectSnapResult _snapTransformPoint(Offset raw, bool touch,
      {bool selectionOnly = false, Offset? anchor,
  }) {
    final source = _rotationSource ?? _project;
    final tolerance = (touch ? 12 : 8) / _currentScale;
    if (selectionOnly) {
      return ArchitectSnapHelper.snapFree(rawPoint: raw, project: source,
        tolerance: tolerance, includedIds: _rotationIds,
        midpointReferences: _midpointTracking.references,
      );
    }
    if (anchor != null) {
      return ArchitectSnapHelper.snapWithAnchor(rawPoint: raw, anchor: anchor,
        project: source, tolerance: tolerance, magnetic: _magnetEnabled,
        alignment: true, midpointReferences: _midpointTracking.references,
        underlay: _currentUnderlayDoc, frame: _effectiveUnderlayFrame,
        visibility: _effectiveUnderlayLayerVisibility,
      );
    }
    return ArchitectSnapHelper.snapFree(rawPoint: raw, project: source,
      tolerance: tolerance, magnetic: _magnetEnabled, alignment: true,
      midpointReferences: _midpointTracking.references,
      underlay: _currentUnderlayDoc, frame: _effectiveUnderlayFrame,
      visibility: _effectiveUnderlayLayerVisibility,
    );
  }

  (Offset, double) _snapComponent(Offset rawModel, ArchitectComponentDefinition def,
  ) {

    if (def.category == ArchitectComponentCategory.services || def is ServiceComponentDefinition) {
      if (_servicePreviewPoint != null) {
        return (_servicePreviewPoint!, _servicePreviewRotation * math.pi / 180.0);
      }
      final activeParams = ComponentLibraryService.instance.activeParameters;
      final (w, d) = def is ServiceComponentDefinition
          ? def.footprint(activeParams)
          : (0.4, 0.4);
      final snap = ArchitectServiceSnap.resolve(
        raw: rawModel,
        project: _project,
        width: w,
        depth: d,
        currentRotationDeg: _servicePreviewRotation,
        tolerance: (_touchInput ? 16 : 10) / _currentScale,
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: _effectiveUnderlayFrame,
      );
      return (snap.point, (snap.angleDeg ?? _servicePreviewRotation) * math.pi / 180.0);
    }

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

      frame: _effectiveUnderlayFrame,

      visibility: _effectiveUnderlayLayerVisibility,

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

            frame: _effectiveUnderlayFrame,

            visibility: _effectiveUnderlayLayerVisibility,

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

            frame: _effectiveUnderlayFrame,

            visibility: _effectiveUnderlayLayerVisibility,

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

          frame: _effectiveUnderlayFrame,

          visibility: _effectiveUnderlayLayerVisibility,

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

      frame: _effectiveUnderlayFrame,

      visibility: _effectiveUnderlayLayerVisibility,

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



  ArchitectCadPrimitive? get _selectedHatch => _effectiveSelection.length == 1
      ? _project.activeStorey.cadPrimitives.where((p) =>
          p.id == _selectedElementId && p.type == CadPrimitiveType.hatch,
            ).firstOrNull
      : null;

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

    for (final pathway in _project.activeStorey.pathways) {
      if (pathway.id == id) return pathway.points;
    }

    for (final street in _project.activeStorey.streets) {
      if (street.id == id) return street.points;
    }

    for (final fence in _project.activeStorey.siteFences) {
      if (fence.id == id) return fence.points;
    }

    for (final veg in _project.activeStorey.vegetation) {
      if (veg.id == id && veg.isHedge) return veg.points;
    }

    for (final surface in [_project.proposedTerrain, _project.existingTerrain]) {
      for (final b in surface.boundaries) {
        if (b.id == id) return b.polygon;
      }
      for (final c in surface.contours) {
        if (c.id == id) return c.points;
      }
    }

    return null;

  }



  void _updatePointerPreview(Offset screenPosition) {
    if (_commandReady) return;

    if (_pendingShape != null) return;

    final rawModel = _screenToModel(screenPosition);

    // An active edit command takes priority over the adopted drawing tool.
    // Otherwise an idle Wall tool consumes movement before the point preview.
    if (_newPointTargetId != null) {
      if (!_newPointDistanceEditorOpen && !_newPointExactPlacement) {
        _updateNewPointCandidate(
          rawModel + _newPointDragOffset / _currentScale, isTouch: _touchInput,
        );
      }
      return;
    }

    // Curving owns its grip before any adopted drawing tool can consume motion.
    if (_isCurvingEdgeDragging &&
        _curvingEdgeElementId != null &&
        _curvingEdgeStartPoint != null &&
        _curvingEdgeEndPoint != null) {
      _updateMidpointReferences(rawModel);
      final p1 = _curvingEdgeStartPoint!;
      final p2 = _curvingEdgeEndPoint!;
      final chord = p2 - p1;
      final len = chord.distance;
      if (len > 1e-4) {
        final length = _handleOffsetLength > 0 ? _handleOffsetLength : 48.0;
        final currentGripScreen = screenPosition + _curvingDragScreenOffset;
        final targetApexScreen = currentGripScreen - (_curvingEdgeGripDirection * length);
        final targetModel = _screenToModel(targetApexScreen);

        final exact = _curvingEdgeExactBulge;
        final n = Offset(-chord.dy, chord.dx) / len;
        final chordMid = (p1 + p2) / 2;
        final v = targetModel - chordMid;
        final projection = v.dx * n.dx + v.dy * n.dy;
        final aimed = (-2.0 * projection / len).clamp(-20.0, 20.0);
        _curvingEdgeBulge = exact == null
            ? aimed
            : (projection.abs() < 1e-6 ? _curvingEdgeBulge.sign : aimed.sign) * exact;
        _curvingEdgeSnapped = false;
        _curvingEdgeSnapLabel = null;
        final apex = ArchitectWallArc(p1, p2, _curvingEdgeBulge).midpoint;
        final snap = _snapElement(apex, tolerancePixels: _touchInput ? 18 : 12);
        // A target is advertised only if the exact arc actually reaches it.
        if (snap.snapLabel != null &&
            (apex - snap.point).distance * _currentScale <= .5) {
          _curvingEdgeSnapped = true;
          _curvingEdgeSnapLabel = snap.snapLabel;
        }
        _updateCurvingPreview();
      }
      _repaintPreview();
      return;
    }

    if (_offsetOptions != null) {

      _previewOffset(rawModel);

      return;

    }

    _updateMidpointReferences(rawModel);

    if (_dragController.isActive) {
      if (_dragTargetPlaced) return;
      if (_dragController.isPickingBasePoint) {
        _dragController.updateBaseHover(
          rawModel,
          project: _project,
          scale: _currentScale,
          dxfDoc: _currentUnderlayDoc,
          frame: _effectiveUnderlayFrame,
          raster: _selectedRasterUnderlay,
        );
      } else if (_dragController.isDraggingToTarget) {
        _updateDragTarget(rawModel);
      }
      _cursorModel = _dragController.currentPointModel;
      _activeSnapLabel = _dragController.currentSnapLabel;
      _activeMagneticGuides = _dragController.magneticGuides;
      _repaintPreview();
      return;
    }

    if (_cadInsertionActive) {
      final snap = _snapDimensionPoint(rawModel);
      _cadInsertionHoverPoint = snap.point;
      _cursorModel = snap.point;
      _activeSnapLabel = snap.snapLabel;
      _activeMagneticGuides = snap.magneticGuides;
      _repaintPreview();
      return;
    }

    if (_draggingRasterId != null &&
        _rasterDragStartModel != null &&
        _rasterDragOriginalPos != null) {
      final delta = rawModel - _rasterDragStartModel!;
      final nextPos = _rasterDragOriginalPos! + delta;
      setState(() {
        _commands.commit(
          _project.copyWith(
            rasterUnderlays: [
              for (final r in _project.rasterUnderlays)
                if (r.id == _draggingRasterId)
                  r.copyWith(position: nextPos)
                else
                  r,
            ],
          ),
        );
      });
      return;
    }

    if (_activeTool == ArchitectTool.rasterUnderlay &&
        _rasterCalibrationStep > 0) {
      _cursorModel = rawModel;
      _repaintPreview();
      return;
    }

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

            frame: _effectiveUnderlayFrame,

            visibility: _effectiveUnderlayLayerVisibility,

          );

        },

        math.min(12 / _currentScale, .20));

      final snap = _polygonEditor.activeSnap;

      _activeSnapLabel = _selectedRoof != null ? null : snap?.snapLabel;

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

      final isStraightWall =
          !original.isCurved &&
          _elementMoveOriginal!.activeStorey.walls.any((w) => w.id == original.id);
      final snap = isStraightWall
          ? ArchitectWallEndpointSnap.resolve(
              wall: original,
              atStart: _wallDragStart,
              raw: rawTarget,
              snapProject: snapProject,
              scale: _currentScale,
              angleLocked: _wallAngleUnlockedId != original.id,
              magnetic: _magnetEnabled,
              underlay: _currentUnderlayDoc,
              frame: _effectiveUnderlayFrame,
              visibility: _effectiveUnderlayLayerVisibility,
            )
          : ArchitectWallSnap.resolve(
              midpointReferences: _midpointTracking.references,
              raw: rawTarget,
              magnetic: _magnetEnabled,
              anchor: _wallDragStart ? original.endPoint : original.startPoint,
              dragOrigin: _wallDragStart ? original.startPoint : original.endPoint,
              project: snapProject,
              scale: _currentScale,
              underlay: _currentUnderlayDoc,
              frame: _effectiveUnderlayFrame,
              visibility: _effectiveUnderlayLayerVisibility,
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

        final polylineIndex = _polylineVertexIndex;
        final polyline = _elementMoveOriginal!.activeStorey.cadPrimitives
            .where((p) => p.id == original.id &&
                (p.type == CadPrimitiveType.polyline || p.type == CadPrimitiveType.spline),
            ).firstOrNull;
        _elementMovePreview = polylineIndex != null && polyline != null
            ? UpdateArchitectPolyline(
                storeyId: _project.activeStoreyId, elementId: original.id,
                points: _polylineEdgeDrag ? ArchitectPolylineEditing.moveEdge(polyline.linePoints,polylineIndex,
                  snap.point-(polyline.linePoints[polylineIndex]+polyline.linePoints[polylineIndex+1])/2)
                  : ArchitectPolylineEditing.moveVertex(polyline.linePoints,polylineIndex,snap.point),
              ).apply(_elementMoveOriginal!)
            : _linearCommand(

          UpdateArchitectWall(

            storeyId: _project.activeStorey.id,

            wall: updated,

            carryConnections: true,

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

      final handlePt = ArchitectFloorDrainPainterHelper.offsetHandle(original, clearance,
      );

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

    if (_activeTool == ArchitectTool.services && !_isActivelyDraggingHandle) {
      final activeDef = ComponentLibraryService.instance.activeDefinition;
      final activeParams = ComponentLibraryService.instance.activeParameters;
      final (w, d) = activeDef is ServiceComponentDefinition
          ? activeDef.footprint(activeParams)
          : (0.4, 0.4);
      final snap = ArchitectServiceSnap.resolve(
        raw: rawModel,
        project: _project,
        width: w,
        depth: d,
        currentRotationDeg: _servicePreviewRotation,
        tolerance: (_touchInput ? 16 : 10) / _currentScale,
        magnetic: _magnetEnabled,
        underlay: _currentUnderlayDoc,
        frame: _effectiveUnderlayFrame,
      );
      _servicePreviewPoint = snap.point;
      _servicePreviewRotation = snap.angleDeg ?? 0.0;
      _activeSnapLabel = snap.snapLabel;
      _activeMagneticGuides = snap.magneticGuides;
      _cursorModel = _servicePreviewPoint;
      _repaintPreview();
      return;
    }



    if (_groupDragIds.isNotEmpty &&

        _elementMoveStart != null &&

        _elementMoveOriginal != null) {

      var delta = ArchitectSnapHelper.precision(

        _project,

      ).inputPoint(rawModel - _elementMoveStart!);

      delta = _constrainMoveDelta(delta, _groupDragIds);

      if (_magnetEnabled &&

          _linearEditWalls.any(

            (w) => _groupDragIds.contains(w.id))) {

        final alignment = ArchitectWallAlignment.move(

          _linearEditWalls,

          _groupDragIds,

          delta,

          _currentScale,

          parallelOnly: _transverseMove,

        );

        delta = alignment.$1;

        _activeMagneticGuides = alignment.$2;

      } else {

        delta = _snapMovingElements(delta, _groupDragIds);

      }

      delta = _constrainMoveDelta(delta, _groupDragIds);

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

      if (selectedWall != null && _transverseMove) {

        final n = selectedWall.normalVector;

        delta = n * (delta.dx * n.dx + delta.dy * n.dy);

      }

      if (selectedWall != null && _magnetEnabled) {

        final alignment = ArchitectWallAlignment.move(

          _linearEditWalls,

          {selectedWall.id},

          delta,

          _currentScale,

          parallelOnly: _transverseMove,

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

      delta = _constrainMoveDelta(delta, {_draggingElementId!});

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

      if (_curvedDraftTool && _wallArcEnd != null) {

        if (_draftArcExactBulge == null && !_arcEditorOpen) {
          _draftEnd = _snapElement(rawModel).point;
        }

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
      _activeTool == ArchitectTool.cadArc ||

            _activeTool == ArchitectTool.cadRect ||

            _activeTool == ArchitectTool.cadCircle ||
            _activeTool == ArchitectTool.cadEllipse ||
            _activeTool == ArchitectTool.leader ||

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



    // 7. Slab, Mask, Spline or Roof drafting candidate

    if ((_activeTool == ArchitectTool.slab || _activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.floorDrain || _activeTool == ArchitectTool.mask || _activeTool == ArchitectTool.spline) &&

        _elementTool.slabDraftPoints.isNotEmpty) {
      if (_wallDirectionLocked) return;

      _elementTool.updateSlabCandidate(_resolveSlabPoint(rawModel));

      _cursorModel = _elementTool.slabCandidatePoint;

    } else if (_activeTool == ArchitectTool.roofSlope) {
      _cursorModel = _snapElement(rawModel).point;
      _repaintPreview();
      return;
    } else if (_activeTool == ArchitectTool.roof) {

      final pt = _resolveRoofPoint(rawModel);

      _roofTool.updateCandidate(

        pt,

        snapLabel: _activeSnapLabel,

        magneticGuides: _activeMagneticGuides,

      );

      _cursorModel = pt;

    } else if (_activeTool.isLandscapeTool) {
      if (_landscapeTool.isDrafting) {
        final anchor = _landscapeTool.draftPoints.last;
        final snap = _snapElement(
          rawModel,
          anchor: anchor,
          tolerancePixels: _touchInput ? 18 : 12,
        );
        final orthoPerp = ArchitectLandscapeTool.resolveDraftSnapping(
          points: _landscapeTool.draftPoints,
          rawPoint: snap.isSnapped ? snap.point : rawModel,
          toleranceMeters: math.max(16.0 / _currentScale, 0.30),
        );
        final finalPoint = orthoPerp.$2 != null ? orthoPerp.$1 : snap.point;
        _cursorModel = finalPoint;
        _activeSnapLabel = orthoPerp.$2 ?? snap.snapLabel;
        _activeMagneticGuides = orthoPerp.$3.isNotEmpty
            ? orthoPerp.$3
            : snap.magneticGuides;
      } else {
        final snap = _snapElement(rawModel);
        _cursorModel = snap.point;
        _activeSnapLabel = snap.snapLabel;
        _activeMagneticGuides = snap.magneticGuides;
      }

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

    if (_wallAttachSourceId != null) {
      _wallAttachPointer = rawModel;
    }

    if (_chamferFilletSourceId != null) {
      _chamferFilletPointer = rawModel;
    }


    _repaintPreview();

  }



  Offset _resolveRoofPoint(Offset raw) {

    final points = _roofTool.draftPoints;

    final isPolyMode =

        _roofTool.drawMode == RoofDrawMode.polygon ||

        _roofTool.drawMode == RoofDrawMode.multiPitch;

    final anchor = isPolyMode ? points.lastOrNull : null;

    final snap = _snapElement(raw, anchor: anchor, tolerancePixels: _touchInput ? 18 : 12,
    );

    final midpointSnap = snap.snapLabel == 'Midpoint' ||

        snap.snapLabel == 'Midpoint alignment';

    final objectSnap = snap.isSnapped && const {
      'Endpoint', 'Vertex', 'Intersection', 'Apparent intersection', 'Axis endpoint',
      'Axis intersection', 'Center', 'Midpoint', 'Quadrant',
    }.contains(snap.snapLabel);
    final closesDraft = isPolyMode && points.length >= 3 &&
        (raw - points.first).distance <= math.min(18 / _currentScale, 0.35);
    if (objectSnap && !closesDraft) {
      _activeSnapLabel = snap.snapLabel;
      _activeMagneticGuides = snap.magneticGuides;
      return snap.point;
    }

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
        activeStorey: _project.activeStorey.walls.isEmpty
            ? (ArchitectRoofGeometry.supportingWallStorey(_project, _project.activeStorey,
                      ) ?? _project.activeStorey)
                .copyWith(roofs: _project.activeStorey.roofs)
            : _project.activeStorey,
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

      _project.activeStorey.walls, math.min(18 / _currentScale, .25),
    );

    return snapped == null ? null : ArchitectSnapResult(point: snapped,

      isSnapped: true, snapLabel: context.l10n.architectApartment,
          );

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

      final boundary = ArchitectApartmentZones.snapBoundary(raw, _project.activeStorey.walls, math.min(18 / _currentScale, .25),
      );

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
    if (_commandReady) return;
    if (_interactionMode == ArchitectInteractionMode.navigation &&
        !_terrainDrafting && !_dragController.isActive) return;

    if (_draftOverlayContains(event.localPosition)) return;

    _touchInput = false;
    _newPointDragOffset = Offset.zero;
    _updatePointerPreview(event.localPosition);

  }



  // --- SUBSECTION: [TAG:TOUCH_UP] _onPointerUp Input Dispatch & Tool Commits ---
  void _onPointerUp(PointerUpEvent event) {
    if (_commandReady) return;
    if (_dragController.isActive) {
      _updateDragAim(event.localPosition);
      if (_dragController.isPickingBasePoint) {
        _dragController.grabBasePoint(
          _dragController.currentPointModel!, frame: _effectiveUnderlayFrame,
        );
        _dragTargetPlaced = false;
        HapticFeedback.selectionClick();
      } else {
        // Only the second gesture places a target for review and Apply.
        _dragTargetPlaced = _hasValidDragTarget;
      }
      _dragPointerOffset = Offset.zero;
      _placingWithHold = false;
      _touchPosition = null;
      _isHandleEngaged = false;
      _handlePointerDown = null;
      _repaintPreview();
      setState(() {});
      return;
    }
    if (_isCurvingEdgeDragging) {
      _isCurvingEdgeDragging = false;
      _isHandleEngaged = false;
      setState(() => _curvingEdgePendingConfirmation = true);
      _repaintPreview();
      return;
    }
    if (_underlayMaskDrafting) {
      if (_underlayMaskMode == 'rect' && _underlayMaskDraftStart != null) {
        final p1 = _underlayMaskDraftStart!;
        final p2 = _screenToModel(event.localPosition);
        final minX = math.min(p1.dx, p2.dx);
        final maxX = math.max(p1.dx, p2.dx);
        final minY = math.min(p1.dy, p2.dy);
        final maxY = math.max(p1.dy, p2.dy);
        if ((maxX - minX) > 0.05 && (maxY - minY) > 0.05) {
          _commitUnderlayMask([
            Offset(minX, minY),
            Offset(maxX, minY),
            Offset(maxX, maxY),
            Offset(minX, maxY),
          ]);
        } else {
          _cancelUnderlayMaskDraft();
        }
        return;
      }
      if (_underlayMaskMode == 'polygon') {
        return;
      }
    }
    if (_interactionMode == ArchitectInteractionMode.navigation && !_terrainDrafting) {
      _handleTap(_screenToModel(event.localPosition));
      return;
    }
    if (_selectionBoxDragging) {
      _commitMarquee(rectangleEnd: _screenToModel(event.localPosition));
      return;
    }
    _selectionBoxDown = null;
    _selectionBoxDownScreen = null;

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
      if (_newPointDistanceEditorOpen || _newPointExactPlacement) return;
      _updateNewPointCandidate(
        _screenToModel(event.localPosition + _newPointDragOffset), isTouch: _touchInput,
      );
      _newPointDragOffset = Offset.zero;
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
    if (_selectionBoxDragging) _marqueeTool.cancel();
    _selectionBoxDown = null;
    _selectionBoxDownScreen = null;
    _selectionBoxDragging = false;
    _hatchTransformSource = null;
    _hatchTransformEpoch++;

    _viewDirectionDraft = null;
    _rotationSource = null;
    _rotationIds = {};
    _offsetEpoch++;

    _offsetOptions = null;

    _offsetSource = null;

    _offsetSide = null;

    _offsetValid = false;
    _pendingDetachWallIds = null;
    _wallAttachSourceId = null;
    _wallAttachPointer = null;

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
    _dragController.cancel();
    _dragTargetPlaced = false;
    _dragPointerOffset = Offset.zero;
    _underlayMaskDrafting = false;
    _underlayMaskDraftStart = null;
    _underlayMaskPoints = [];
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

    _polylineVertexIndex = null;
    _polylineEdgeDrag = false;

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
    _dragController.cancel();

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

    _draggingRasterId = null;
    _rasterDragStartModel = null;
    _rasterDragOriginalPos = null;

  }



  void _commitActiveHandleDrag(Offset screenPos) {

    if (_draggingRasterId != null) {
      _draggingRasterId = null;
      _rasterDragStartModel = null;
      _rasterDragOriginalPos = null;
      _saveBiMProjectIfAttached();
      HapticFeedback.selectionClick();
      return;
    }

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

        storey: current, l10n: context.l10n, viewKey: _workspaceViewKey, zoomScale: _currentScale,
      );

      final origins = {for (final t in tables) t.group.id: t.origin};

      _cancelActiveDrags();

      setState(() {

        _project = _project.updateActiveStorey(current.copyWith(

          zoneScheduleOrigin: tableId == 'unassigned' ? newOrigin : current.zoneScheduleOrigin,

          zones: [for (final z in current.zones) z.isApartment

            ? z.copyWith(scheduleOrigin: z.id == tableId ? newOrigin : origins[z.id],
                      ) : z,
            ],

        ),
        );

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

      final source = _elementMoveOriginal ?? _project;
      final isCadContour = source.activeStorey.cadPrimitives
          .any((p) => p.id == id && p.isPolygon,
      );
      final displacement = _polygonPrecisionMode && isCadContour && valid && changed
          ? ArchitectPolygonDisplacement.fromDrag(
              polygon: original, index: _polygonEditor.index!,
              edge: _polygonEditor.edge, target: _polygonEditor.editedPoint!,
              mode: _polygonEditor.edgeMode,
            )
          : null;
      _cancelActiveDrags();

      if (displacement != null) {
        unawaited(_editPolygonDisplacement(
          id: id, holeIndex: holeIndex, source: source, drag: displacement,
        ),
        );
        return;
      }

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

        if (_commandPreview != null) {
          _captureGeometryPreview(preview);
        } else {
          _commands.commit(preview);

          _saveBiMProjectIfAttached();

          _syncAutoZones(preview.activeStorey);
        }

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
    // Touch selection uses the physical outline (including joined ends) and
    // the same tolerance as the selection tool, before snapping for placement.
    if (_activeTool != ArchitectTool.wall && _hitSelection(point) == null) {
      return false;
    }
    return _selectAt(point);

  }



  void _handleTap(Offset rawModel) {
    if (_commandReady) return;
    _modelCommands.exteriorReviewWallIds = const {};
    if (_activeTool == ArchitectTool.select && _marqueeTool.isDrafting) {
      if (_marqueeTool.mode == ArchitectSelectMode.rectangle) {
        _commitMarquee(rectangleEnd: rawModel);
      } else if (_marqueeTool.points.length >= 3 &&
          (rawModel - _marqueeTool.points.first).distance * _currentScale <= 20) {
        _commitMarquee();
      } else {
        setState(() => _marqueeTool.addPoint(rawModel));
        _repaintPreview();
      }
      return;
    }

    if (_offsetOptions != null) {

      _previewOffset(rawModel);

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

      final contour = ArchitectClosedContour.detect(_project.activeStorey, rawModel,
      );

      if (contour == null) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(

          content: Text(context.l10n.architectDrainRoomNotFound)),
        );

      } else {

        _commitFloorDrain(contour: contour);

      }

      return;

    }



    if (_activeTool == ArchitectTool.hatch && _automaticHatch &&

        _effectiveSelection.isEmpty) {

      final contour = ArchitectClosedContour.detect(_project.activeStorey, rawModel,
      );

      if (contour == null) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(

          content: Text(context.l10n.architectHatchAutoFailed)),
        );

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



    if (_newPointTargetId != null) return;



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

        (_acceptsAnySelection || _activeTool == ArchitectTool.roof) &&

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

          if (_canAdoptPickedTool) {

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



    if (_polygonEditId != null || _selectedRoof != null) {
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

    if (_pendingDetachWallIds != null) {
      return;
    }

    if (_wallAttachSourceId != null) {
      final sourceId = _wallAttachSourceId!;
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
          tolerance: math.max(26.0 / _currentScale, 0.40),
        );
      }).firstOrNull;

      if (hitWall != null) {
        try {
          if (!_stageWallAttach({sourceId, hitWall.id})) return;
          HapticFeedback.mediumImpact();
          setState(() {
            _wallAttachSourceId = null;
            _wallAttachPointer = null;
            _selectionIds.clear();
            _selectedElementId = null;
            _selectedZoneId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectWallAttachSuccess),
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectWallAttachIncompatible),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {
            _wallAttachSourceId = null;
            _wallAttachPointer = null;
          });
        }
        return;
      }

      if (hit == sourceId) {
        setState(() {
          _wallAttachSourceId = null;
          _wallAttachPointer = null;
        });
        return;
      }

      setState(() {
        _wallAttachSourceId = null;
        _wallAttachPointer = null;
      });
      return;
    }

    if (_chamferFilletSourceId != null) {
      final sourceId = _chamferFilletSourceId!;
      final options = _chamferFilletOptions!;
      final storey = _project.activeStorey;
      final hit = _hitSelection(rawModel);

      var hitWall = _linearEditWalls
          .where((w) =>
              (w.id == hit ||
               w.doors.any((d) => d.id == hit) ||
               w.windows.any((win) => win.id == hit)) &&
              w.id != sourceId)
          .firstOrNull;
      hitWall ??= _linearEditWalls.where((w) {
        if (w.id == sourceId) return false;
        return w.containsPoint(
          rawModel,
          tolerance: math.max(24.0 / _currentScale, 0.4),
        );
      }).firstOrNull;

      final hitLine = storey.cadPrimitives
          .where((p) =>
              p.id != sourceId &&
              p.type == CadPrimitiveType.line &&
              (p.id == hit ||
               (rawModel - BimLineGeometry.closest(rawModel, p.startPoint, p.endPoint)).distance <= math.max(24.0 / _currentScale, 0.4)))
          .firstOrNull;

      if (hitWall != null && storey.walls.any((w) => w.id == sourceId)) {
        final wA = storey.walls.firstWhere((w) => w.id == sourceId);
        final wB = hitWall;
        final res = options.isFillet
            ? ArchitectChamferFillet.wallPairFillet(wA, wB, radius: options.value)
            : ArchitectChamferFillet.wallPairChamfer(wA, wB, distance: options.value);
        if (res != null) {
          final nextWalls = storey.walls.map((w) {
            if (w.id == wA.id) return res.wallA;
            if (w.id == wB.id) return res.wallB;
            return w;
          }).toList()..add(res.connector);
          _commands.commit(_project.updateActiveStorey(storey.copyWith(walls: nextWalls)));
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          setState(() {
            _chamferFilletSourceId = null;
            _chamferFilletOptions = null;
            _chamferFilletPointer = null;
            _selectionIds.clear();
            _selectedElementId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(options.isFillet
                  ? context.l10n.architectFillet
                  : context.l10n.architectChamfer),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectChamferFilletInvalid),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      } else if (hitLine != null &&
          storey.cadPrimitives.any((p) => p.id == sourceId && p.type == CadPrimitiveType.line)) {
        final lA = storey.cadPrimitives.firstWhere((p) => p.id == sourceId);
        final lB = hitLine;
        final res = options.isFillet
            ? ArchitectChamferFillet.linePairFillet(lA, lB, radius: options.value)
            : ArchitectChamferFillet.linePairChamfer(lA, lB, distance: options.value);
        if (res != null) {
          final nextPrimitives = storey.cadPrimitives.map((p) {
            if (p.id == lA.id) return res.lineA;
            if (p.id == lB.id) return res.lineB;
            return p;
          }).toList()..add(res.connector);
          _commands.commit(_project.updateActiveStorey(storey.copyWith(cadPrimitives: nextPrimitives)));
          _saveBiMProjectIfAttached();
          HapticFeedback.mediumImpact();
          setState(() {
            _chamferFilletSourceId = null;
            _chamferFilletOptions = null;
            _chamferFilletPointer = null;
            _selectionIds.clear();
            _selectedElementId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(options.isFillet
                  ? context.l10n.architectFillet
                  : context.l10n.architectChamfer),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.architectChamferFilletInvalid),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      return;
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

    if (_acceptsAnySelection) {
      if (_selectAt(rawModel, toggle: _multiSelect)) return;
      if (_multiSelect) {
        setState(() => _marqueeTool.addPoint(rawModel));
        _repaintPreview();
      } else {
        _clearSelection();
      }
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

            _commands.commit(_project.updateActiveStorey(updatedStorey), applyDraftingDefaults: true,
            );

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

          setState(() => _commands.commit(updatedProj, applyDraftingDefaults: true),
          );

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

          setState(() => _commands.commit(result.$1, applyDraftingDefaults: true),
          );

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
      applyDraftingDefaults: true,
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
        _pendingZoneTableOrigin = rawModel;
        _zoneTablePreviewOrigin = rawModel;
        _project = _project.updateActiveStorey(updatedStorey);
        _isZoneTableSelected = true;
        _selectedZoneId = null;
        _selectedElementId = null;
        _selectionIds.clear();
      });
      HapticFeedback.lightImpact();
      return;
    }

    if (_activeTool == ArchitectTool.rasterUnderlay) {
      if (_rasterCalibrationStep > 0) {
        unawaited(_handleRasterCalibrationTap(rawModel));
        return;
      }
      final rasters = _project.rasterUnderlaysForStorey(
        _project.activeStorey.id,
      );
      for (final r in rasters.reversed) {
        if (r.containsLocalPoint(rawModel)) {
          setState(() => _selectedRasterId = r.id);
          HapticFeedback.selectionClick();
          return;
        }
      }
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



    // 4. In Wall / Line / Arc tool

    if (_linearDraftTool) {

      if (_curvedDraftTool && _wallArcEnd != null) {

        _draftEnd = _snapElement(rawModel).point;

        unawaited(_editWallArcDimension(
          dimension: ArchitectArcDimension.sagitta,
          commitDraft: true,
        ));

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

        if ((snap.point - _draftStart!).distance >= .001 &&
            !_viewMarkerTool) {

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

    if (_activeTool.usesComponent) {
      final hitComp = _project.activeStorey.components.reversed.where((c) {
        if (!c.isVisible) return false;
        return c.containsPoint(rawModel);
      }).firstOrNull;

      if (hitComp != null) {
        _selectAt(rawModel);
        return;
      }

      if (_activeTool == ArchitectTool.services) {
        final activeDef = ComponentLibraryService.instance.activeDefinition;
        final activeParams = ComponentLibraryService.instance.activeParameters;
        final (w, d) = activeDef is ServiceComponentDefinition
            ? activeDef.footprint(activeParams)
            : (0.4, 0.4);
        final snap = ArchitectServiceSnap.resolve(
          raw: rawModel,
          project: _project,
          width: w,
          depth: d,
          currentRotationDeg: _servicePreviewRotation,
          tolerance: (_touchInput ? 16 : 10) / _currentScale,
          magnetic: _magnetEnabled,
          underlay: _currentUnderlayDoc,
          frame: _effectiveUnderlayFrame,
        );
        setState(() {
          _servicePreviewPoint = snap.point;
          _servicePreviewRotation = snap.angleDeg ?? 0.0;
          _cursorModel = snap.point;
        });
        _repaintPreview();
        return;
      }

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

      final updatedStorey = _project.activeStorey.copyWith(components: updatedComponents,
      );

      setState(() {

        _commands.commit(_project.copyWith(

          storeys: [

            for (final s in _project.storeys)

              if (s.id == updatedStorey.id) updatedStorey else s,

          ],

        ), applyDraftingDefaults: true,
        );

      });

      _saveBiMProjectIfAttached();

      HapticFeedback.lightImpact();

      return;

    }



    if (_activeTool == ArchitectTool.column) {
      if (_project.activeStorey.columns.any(
        (column) => column.containsPoint(rawModel, tolerance: 10 / _currentScale),
      )) {
        _selectAt(rawModel);
        return;
      }

      final snap = _snapColumn(rawModel);

      final pt = snap.point;

      // Snapping can move the placement marker onto an existing column.

      if (_project.activeStorey.columns.any(

        (column) => column.containsPoint(pt, tolerance: 0),

      )) {

        _selectAt(pt);

        return;

      }

      setState(() {
        _columnPreviewPoint = pt;
        _columnPreviewRotation = snap.angleDeg ?? _columnPreviewRotation;
        _cursorModel = pt;
      });
      _repaintPreview();
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

            _commands.commit(_project.updateActiveStorey(res.$1), applyDraftingDefaults: true,
            );

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



    // 9. In Slab / Mask / Spline tool

    if (_activeTool == ArchitectTool.slab || _activeTool == ArchitectTool.hatch || _activeTool == ArchitectTool.floorDrain || _activeTool == ArchitectTool.mask || _activeTool == ArchitectTool.spline) {
      if (_wallDirectionLocked) return;

      final pt = _resolveSlabPoint(rawModel);



      if (_elementTool.slabDraftPoints.length >= 3 &&

          (pt - _elementTool.slabDraftPoints.first).distance <=

              math.min(16.0 / _currentScale, .20)) {

        if (_activeTool == ArchitectTool.mask) { _commitMask(); return; }

        if (_activeTool == ArchitectTool.spline) { _commitSpline(closed: true); return; }

        if (_activeTool == ArchitectTool.hatch) { _commitHatch(); return; }

        if (_activeTool == ArchitectTool.floorDrain) { _commitFloorDrain(); return; }

        final res = _elementTool.commitSlab(storey: _project.activeStorey);

        if (res != null) {

          setState(() {

            _commands.commit(_project.updateActiveStorey(res.$1), applyDraftingDefaults: true,
            );

          });

          _saveBiMProjectIfAttached();

          HapticFeedback.mediumImpact();

        }

      } else {
        if (_activeTool == ArchitectTool.hatch &&
            _wallPrecisionMode &&
            _elementTool.slabDraftPoints.isNotEmpty) {
          final lastPt = _elementTool.slabDraftPoints.last;
          if ((pt - lastPt).distance >= .001) {
            setState(() {
              _draftStart = lastPt;
              _draftEnd = pt;
              _wallDirectionLocked = true;
              _wallPanelAnchor = (lastPt + pt) / 2;
            });
            return;
          }
        }

        setState(() => _elementTool.addSlabPoint(pt));

        HapticFeedback.lightImpact();

      }

      return;

    }



    // 9b. In Landscape tools (Terrain, Pathway, Vegetation, Site Fence)
    if (_activeTool.isLandscapeTool) {
      if (!_landscapeTool.isDrafting) {
        final hitId = ArchitectLandscapeTool.hitTestLandscapeElement(
          project: _project,
          storey: _project.activeStorey,
          worldPoint: rawModel,
          hitTolerance: math.max(22.0 / _currentScale, 0.35),
        );
        if (hitId != null) {
          _selectAt(rawModel, toggle: _multiSelect);
          return;
        }
      }

      final anchor = _landscapeTool.draftPoints.lastOrNull;
      final snap = _snapElement(rawModel, anchor: anchor);
      final orthoPerp = anchor != null
          ? ArchitectLandscapeTool.resolveDraftSnapping(
              points: _landscapeTool.draftPoints,
              rawPoint: snap.isSnapped ? snap.point : rawModel,
              toleranceMeters: math.max(16.0 / _currentScale, 0.30),
            )
          : null;
      final pt = (orthoPerp?.$2 != null) ? orthoPerp!.$1 : snap.point;
      final nextProject = _landscapeTool.handleTap(
        toolName: _activeTool.name,
        worldPoint: pt,
        project: _project,
        closeThresholdWorld: math.min(18.0 / _currentScale, 0.35),
      );
      if (nextProject != null) {
        setState(() {
          _commands.commit(nextProject, applyDraftingDefaults: true);
        });
        _saveBiMProjectIfAttached();
        HapticFeedback.mediumImpact();
      } else {
        setState(() {});
        _repaintPreview();
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

            _commands.commit(_project.updateActiveStorey(res.$1), applyDraftingDefaults: true,
            );

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

        _commands.commit(_project.updateActiveStorey(updatedStorey), applyDraftingDefaults: true,
        );

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

    // 14b. In Multileader tool
    if (_activeTool == ArchitectTool.leader) {
      if (_draftStart == null) {
        final point = _snapElement(rawModel).point;
        setState(() {
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final snap = _snapElement(rawModel, anchor: _draftStart);
        final p1 = _draftStart!;
        final p2 = snap.point;
        _promptAddLeaderAnnotation(p1, p2);
      }
      return;
    }

    // 14c. In CAD Ellipse tool
    if (_activeTool == ArchitectTool.cadEllipse) {
      if (_draftStart == null) {
        final point = _snapElement(rawModel).point;
        setState(() {
          _draftStart = point;
          _draftEnd = point;
        });
      } else {
        final snap = _snapElement(rawModel, anchor: _draftStart);
        _draftEnd = snap.point;
        _commitCadEllipse();
      }
      return;
    }

    // 14d. In Roof Slope Arrow tool
    if (_activeTool == ArchitectTool.roofSlope) {
      final point = _snapElement(rawModel).point;
      _commitRoofSlopeArrow(point);
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

        setState(() {

          _pendingShape = type;

          _shapePanelAnchor = snap.point;

        });

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



  // === SECTION: [SEC-05-ZONES] ZONE EDITING & MUTATION HANDLERS ===
  // --- SUBSECTION: [TAG:ZONE_LOGIC] Zone Updates, Schedules & Presets ---



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

      z.isApartment ? z.copyWith(clearScheduleOrigin: true) : z,
      ],
    );

    final tables = ArchitectZonePainterHelper.scheduleTables(project: _project,

      storey: base, l10n: context.l10n, viewKey: _workspaceViewKey, zoomScale: _currentScale,
    );

    final origins = {for (final t in tables) t.group.id: t.origin};

    return base.copyWith(zones: [for (final z in base.zones)

      z.isApartment ? z.copyWith(scheduleOrigin: origins[z.id]) : z,
      ],
    );

  }



  void _showRoomScheduleDialog() {
    ArchitectZoneScheduleDialog.show(
      presets: _zonePresets,
      context: context,
      storey: _project.activeStorey,
      units: _project.units,
      initialApartmentId: _selectedZone?.isApartment == true ? _selectedZoneId : _selectedZone?.apartmentId,
      onZoneUpdated: _updateZone,
      onPresetsChanged: (newPresets) {
        setState(() => _zonePresets = newPresets);
        _saveZonePresets(newPresets);
      },
      onTableOriginChanged: (origin) {
        setState(() {
          _project = _project.updateActiveStorey(origin == null
            ? _project.activeStorey.copyWith(clearZoneScheduleOrigin: true)
            : _placedZoneSchedules(origin),
          );
        });
        _saveBiMProjectIfAttached();
      },
    );
  }

  void _showZonePresetsDialog([ArchitectZoneCategory? initialCategory]) {
    ArchitectZonePresetsDialog.show(
      context: context,
      presets: _zonePresets,
      initialCategory: initialCategory,
      onSave: (newPresets) {
        setState(() => _zonePresets = newPresets);
        _saveZonePresets(newPresets);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectZonePresetsSaved),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _confirmZoneTablePlacement() {
    final origin = _pendingZoneTableOrigin ?? _project.activeStorey.zoneScheduleOrigin;
    if (origin == null) return;
    final updatedStorey = _placedZoneSchedules(origin);
    setState(() {
      _commands.commit(
        _project.updateActiveStorey(updatedStorey),
        applyDraftingDefaults: true,
      );
      _pendingZoneTableOrigin = null;
      _zoneTablePreviewOrigin = null;
      _originalZoneTableOrigin = origin;
      _isZoneTableSelected = true;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectZoneTablePlaced),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _cancelZoneTablePlacement() {
    setState(() {
      if (_originalZoneTableOrigin != null) {
        final restoredStorey = _placedZoneSchedules(_originalZoneTableOrigin!);
        _project = _project.updateActiveStorey(restoredStorey);
      } else {
        _project = _project.updateActiveStorey(
          _project.activeStorey.copyWith(clearZoneScheduleOrigin: true),
        );
      }
      _pendingZoneTableOrigin = null;
      _zoneTablePreviewOrigin = null;
      _isZoneTableSelected = false;
      _activeTool = ArchitectTool.zone;
    });
    HapticFeedback.lightImpact();
  }

  void _removeZoneScheduleTable() {
    setState(() {
      final updatedStorey = _project.activeStorey.copyWith(
        clearZoneScheduleOrigin: true,
      );
      _project = _project.updateActiveStorey(updatedStorey);
      _isZoneTableSelected = false;
      _pendingZoneTableOrigin = null;
      _originalZoneTableOrigin = null;
      _zoneTablePreviewOrigin = null;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
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

      builder: (ctx) => architectAlertDialog(

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

            icon: const AppIcon(AppIconId.confirm, size: 18),

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
    if (_commandPreview != null) return;

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



  // === SECTION: [SEC-06-WALLS] WALL & DOOR CONCEPT DRAFTING ===
  // --- SUBSECTION: [TAG:WALL_DRAFT] Wall Concept Drafting & Chain Grouping ---



  final List<String> _draftChainIds = [];

  bool _groupDraftChain = false;

  Set<String> get _liveDraftChainIds => _draftChainIds.where(_project.activeStorey.groupableIds.contains).toSet();

  bool get _draftGroupChoiceVisible => _commands.isPlan &&

      _liveDraftChainIds.length + (_wallDirectionLocked ? 1 : 0) > 1;

  void _resetDraftGroup() {
    _draftChainIds.clear();
    _groupDraftChain = false;
    _polylineDraftId = null;
  }

  void _finishDraftGroup() {

    final ids = _liveDraftChainIds;

    if (_commands.isPlan && _groupDraftChain && ids.length > 1) {

      _commands.execute(GroupArchitectElements(storeyId: _project.activeStoreyId,

        groupId: ArchitectElementId.next('group'), elementIds: ids,
        ),
      );

      _saveBiMProjectIfAttached();

    }

    _resetDraftGroup();

  }

  void _placeDraftSegment(ArchitectModelCommand command, String id, bool chain,
  ) {

    final ids = {..._liveDraftChainIds, id};

    _commands.executeBatch([command,

      if (!chain && _commands.isPlan && _groupDraftChain && ids.length > 1)

        GroupArchitectElements(storeyId: _project.activeStoreyId,

          groupId: ArchitectElementId.next('group'), elementIds: ids,
        ),

    ],
      applyDraftingDefaults: true);

    if (chain) {
      _draftChainIds.add(id);
    } else {
      _resetDraftGroup();
    }

  }



  void _commitViewDirection(int side) {
    final draft = _viewDirectionDraft;
    if (draft == null || (side != 1 && side != -1)) return;
    final section = draft.tool == ArchitectTool.section;
    final id = ArchitectElementId.next(section ? 'sec' : 'elv');
    final label = String.fromCharCode(65 + (_project.sections.length % 26));
    final next = section ? _project.copyWith(sections: [..._project.sections,
      ArchitectSection(id: id, name: '${context.l10n.architectToolSection} $label-$label',
        start: side == 1 ? draft.start : draft.end, end: side == 1 ? draft.end : draft.start,
              ),
    ],
          ) : _project.copyWith(elevations: [..._project.elevations,
      ArchitectElevation(id: id, start: draft.start, end: draft.end, viewSide: side,
              ),
    ],
          );
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

    if (_activeTool == ArchitectTool.cadArc) {
      final end = targetPoint;
      if ((end - _draftStart!).distance < .001) return;
      final id = ArchitectElementId.next('arc');
      _placeDraftSegment(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: ArchitectCadPrimitive(
            id: id,
            type: CadPrimitiveType.arc,
            startPoint: _draftStart!,
            endPoint: end,
            arcBulge: arcBulge,
            colorValue: 0xFF9E9E9E,
            lineStyle: _activeCadLineStyle,
          ),
        ),
        id,
        false,
      );
      setState(() {
        _draftStart = null;
        _draftEnd = null;
        _wallArcEnd = null;
        _wallDirectionLocked = false;
        _wallPanelAnchor = null;
        _activeSnapLabel = null;
        _activeMagneticGuides = [];
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      return;
    }

    if (_activeTool == ArchitectTool.cadLine) {

      if (_cadPolylineMode) {
        final end = targetPoint;
        if ((end - _draftStart!).distance < .001) return;
        final existing = _project.activeStorey.cadPrimitives
            .where((p) => p.id == _polylineDraftId &&
                p.type == CadPrimitiveType.polyline,
            ).firstOrNull;
        final chain = continueChain ?? true;
        final id = existing?.id ?? ArchitectElementId.next('polyline');
        final segBulge = _polylineArcSegmentMode ? arcBulge : 0.0;
        if (existing == null) {
          _commands.execute(PlaceArchitectCadPrimitive(
            storeyId: _project.activeStoreyId,
            primitive: ArchitectCadPrimitive(id: id,
              type: CadPrimitiveType.polyline,
              startPoint: _draftStart!, endPoint: end,
              polygon: [_draftStart!, end],
              colorValue: 0xFF9E9E9E, lineStyle: _activeCadLineStyle,
              bulges: [segBulge],
              customWidth: _activePolylineWidth,
              ),
          ),
      applyDraftingDefaults: true,
    );
        } else {
          final existingBulges = existing.bulges ?? List.filled(existing.linePoints.length - 1, 0.0);
          _commands.execute(UpdateArchitectPolyline(
            storeyId: _project.activeStoreyId, elementId: id,
            points: [...existing.linePoints, end],
            bulges: [...existingBulges, segBulge],
            customWidth: _activePolylineWidth ?? existing.customWidth,
          ),
          );
        }
        setState(() {
          _polylineDraftId = chain ? id : null;
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

            arcBulge: arcBulge,

            startCap: _activeLineStartCap,

            endCap: _activeLineEndCap,

            capSize: _activeLineCapSize,

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
          start: _draftStart!, end: targetPoint,
        );
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
      final centre = _viewport.toScreen((_viewDirectionDraft!.start + targetPoint) / 2,
      );
      final size = _viewport.size;
      if (size.width > 180 && size.height > 240) {
        _viewport.panBy(Offset(centre.dx.clamp(88, size.width - 88) - centre.dx,
          centre.dy.clamp(144, size.height - 88) - centre.dy,
          ),
        );
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

      system: _activeWallType?.system ?? const ArchitectWallSystem(),
      layers: _activeWallType?.resolvedLayers ?? const [],

      location: _activeWallType?.resolvedLocation,

      height: _activeWallType?.customHeight ?? _project.activeStorey.height,

      followStoreyHeight: _activeWallType?.isParapet != true,

      wallTypeId: _activeWallType?.id,

      parapetFinish: _activeWallType?.parapetFinish,
      railing: _activeWallType?.railing,

      parapet: _activeWallType?.isParapet,

      referenceLine: _wallReference,

      exteriorSide: _wallExteriorSide,
      exteriorSideMode: _wallExteriorSideMode,

      insulationThicknessOverride: _activeWallType?.insulationThickness,

    );



    setState(() {

      _placeDraftSegment(

        CreateArchitectWall(storeyId: _project.activeStorey.id, wall: newWall,
          wallType: _activeWallType), newWall.id,

        continueChain ?? (_wallMode == WallDraftingMode.chained),

      );

      _syncAutoZones(_project.activeStorey);
      _wallExteriorSideMode = WallResolutionMode.automatic;

      _wallDirectionLocked = false;
      _wallPanelAnchor = null;
      _activeMagneticGuides = [];

      if (continueChain == true) _wallMode = WallDraftingMode.chained;

      if (continueChain ?? (_wallMode == WallDraftingMode.chained)) {

        _draftStart = p2;

        _draftEnd = p2;

        _wallStartAttachment = ArchitectWallAttachment(newWall, _wallReference);

      } else {

        _resetWallDraft();

      }

    });

    _saveBiMProjectIfAttached();



    HapticFeedback.lightImpact();

  }




  void _finishChainedWall() {
    final chainIds = Set<String>.from(_liveDraftChainIds);
    if (_polylineDraftId != null) {
      chainIds.add(_polylineDraftId!);
      _polylineDraftId = null;
    }
    _finishDraftGroup();

    setState(() {
      _resetWallDraft();
      if (chainIds.isNotEmpty) {
        _selectionIds
          ..clear()
          ..addAll(chainIds);
        _selectedElementId = chainIds.last;
      }
    });
    _repaintPreview();
  }

  /// End/cancel always returns the still-active tool to an idle picking state.
  /// Preferences such as the reference line and chain mode survive this reset.
  void _resetWallDraft() {
    _interactionEpoch++;
    _polylineDraftId = null;
    _draftStart = null;
    _draftEnd = null;
    _wallArcEnd = null;
    _draftArcExactBulge = null;
    _wallStartAttachment = null;
    _wallDirectionLocked = false;
    _wallPanelAnchor = null;
    _activeSnapLabel = null;
    _activeMagneticGuides = [];
    _cursorModel = null;
    _placingWithHold = false;
    _touchPosition = null;
  }

  void _setDraftWallReference(WallReferenceLine reference) {
    setState(() {
      _wallReference = reference;
      _wallReferenceManual = true;
      // The user's choice overrides the orientation inherited at this start.
      _wallStartAttachment = null;
    });
    _repaintPreview();
  }


  void _adoptWallReference(ArchitectWallAttachment? attachment) {

    if (_activeTool != ArchitectTool.wall ||
        _wallReferenceManual || attachment == null) {
      return;
    }

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

    final side = ArchitectWallAttachment(
      _wallStartAttachment!.source,
      _wallReference,
    ).sideFor(

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



  // === SECTION: [SEC-07-SPLIT] WALL SPLIT, SURFACE DETECTION & CLEARANCES ===
  // --- SUBSECTION: [TAG:WALL_SPLIT] Wall Splitting, Cut Sessions & Clearances ---

  void _startCutSession(Set<String> wallIds) {
    _beginGeometryCommand(ArchitectRadialAction.cut);

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

      _transverseMove = false;

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
    _beginGeometryCommand(ArchitectRadialAction.split);

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

      _transverseMove = false;

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

      // Also split any intersecting landscape elements (pathways and site fences)
      final storey = _project.activeStorey;
      var landscapeSplitChanged = false;
      final nextPathways = <ArchitectPathway>[];
      for (final p in storey.pathways) {
        if (targetIds.contains(p.id) || _effectiveSelection.contains(p.id)) {
          final split = ArchitectLandscapeTool.splitPolyline(p.points, p1, p2);
          if (split != null) {
            final now = DateTime.now().microsecondsSinceEpoch;
            nextPathways.add(p.copyWith(points: split.$1));
            nextPathways.add(p.copyWith(id: 'path_${now}_split', points: split.$2));
            landscapeSplitChanged = true;
            continue;
          }
        }
        nextPathways.add(p);
      }

      final nextFences = <ArchitectSiteFence>[];
      for (final f in storey.siteFences) {
        if (targetIds.contains(f.id) || _effectiveSelection.contains(f.id)) {
          final split = ArchitectLandscapeTool.splitPolyline(f.points, p1, p2);
          if (split != null) {
            final now = DateTime.now().microsecondsSinceEpoch;
            nextFences.add(f.copyWith(points: split.$1));
            nextFences.add(f.copyWith(id: 'fence_${now}_split', points: split.$2));
            landscapeSplitChanged = true;
            continue;
          }
        }
        nextFences.add(f);
      }

      final nextStreets = <ArchitectStreet>[];
      for (final s in storey.streets) {
        if (targetIds.contains(s.id) || _effectiveSelection.contains(s.id)) {
          final split = ArchitectLandscapeTool.splitPolyline(s.points, p1, p2);
          if (split != null) {
            final now = DateTime.now().microsecondsSinceEpoch;
            nextStreets.add(s.copyWith(points: split.$1));
            nextStreets.add(s.copyWith(id: 'street_${now}_split', points: split.$2));
            landscapeSplitChanged = true;
            continue;
          }
        }
        nextStreets.add(s);
      }

      if (landscapeSplitChanged) {
        final updatedProject = _project.updateActiveStorey(
          storey.copyWith(
            pathways: nextPathways,
            siteFences: nextFences,
            streets: nextStreets,
          ),
        );
        _commands.commit(updatedProject);
        _saveBiMProjectIfAttached();
      }

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

      if (line.type == CadPrimitiveType.line ||
          line.type == CadPrimitiveType.polyline) {
        final points = line.linePoints;
        for (var i = 1; i < points.length; i++) {
          testSegment(points[i - 1], points[i]);
        }

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
      animation: Listenable.merge([_viewport, _previewRevision, UiSettingsService.contextMenu,
      ]),
      builder: (context, child) {
        if (_newPointTargetId != null) return const SizedBox.shrink();
        final columnGaps = _commands.isPlan && _effectiveSelection.length == 1
            ? ArchitectColumnClearance.forColumn(_elementMovePreview ?? _project, _effectiveSelection.single) : const <ArchitectColumnClearance>[];
        final clearances = [..._wallClearances, for(final gap in columnGaps)
          ArchitectWallClearance(wallId:gap.columnId,neighborId:gap.key,side:1,distance:gap.distance,start:gap.start,end:gap.end)];
        final openings = _draggingElementId == null
            ? _selectedOpeningClearances : const <ArchitectOpeningClearance>[];
        if ((clearances.isEmpty && openings.isEmpty) ||
            _viewport.size.width < 104 || _viewport.size.height < 180) {
          return const SizedBox.shrink();
        }
        final walls = (_elementMovePreview ?? _project).activeStorey.walls;
        final obstacles = ArchitectClearanceObstacles.forWalls(walls);
        bool intersectsWall(Rect rect) => obstacles.intersects(Rect.fromPoints(
          _viewport.toModel(rect.topLeft), _viewport.toModel(rect.bottomRight),
          ),
        );
        final available = Rect.fromLTRB(8, 64,
          _viewport.size.width - 8, _viewport.size.height - 80,
        );
        final bounds = (Offset.zero & _viewport.size).deflate(8);
        final excluded = <Rect>[
          if (_radialMenuScreenPosition != null && _radialMenuItems.isNotEmpty)
            ...ArchitectRadialLayout.compute(
              size: _viewport.size, center: _radialMenuScreenPosition!,
              mode: UiSettingsService.contextMenu.value.mode,
              hasTitle: _effectiveSelection.length > 1,
              elementBounds: _radialElementBounds,
            ).occupied,
        ];
        final selected = walls.where((w) => _effectiveSelection.contains(w.id)).firstOrNull;
        if (selected != null) {
          for (final handle in [
            _viewport.toScreen(selected.startPoint) - selected.tangentAt(0) * _handleOffsetLength,
            _viewport.toScreen(selected.endPoint) + selected.tangentAt(1) * _handleOffsetLength,
          ]) {
            excluded.add(Rect.fromCircle(center: handle, radius: 12));
          }
        }
        final dimensions = <String, ArchitectDynamicDimensionLayout>{};
        for (final gap in clearances) {
          final dim = ArchitectDynamicDimensionLayout.place(
            start: _viewport.toScreen(gap.start), end: _viewport.toScreen(gap.end),
            available: available, viewport: bounds, excluded: excluded,
            intersectsWall: intersectsWall,
            endpoint: gap.atStart == null ? null : gap.atStart! ? 1 : 2,
            active: _activeWallClearanceKey == gap.key,
          );
          dimensions[gap.key] = dim;
          excluded.add(dim.label);
        }
        final openingRects = <String, Rect>{};
        for (final gap in openings) {
          final start = _viewport.toScreen(gap.start), end = _viewport.toScreen(gap.end);
          final segment = BimLineGeometry.visibleSegment(start, end, available);
          final rect = ArchitectClearanceBadgeLayout.place(
            preferred: segment == null ? (start + end) / 2 : (segment.$1 + segment.$2) / 2,
            size: ArchitectClearanceBadgeLayout.openingSize(_currentScale, available,
            ),
            available: available, excluded: excluded, intersectsWall: intersectsWall,
          );
          openingRects[gap.key] = rect;
          excluded.add(rect);
        }
        final ignore = _radialMenuScreenPosition != null || _multiSelect || _marqueeTool.isDrafting;
        return Stack(children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
            key: const ValueKey('architect-dynamic-dimensions'),
            painter: ArchitectDynamicDimensionPainter(dimensions.values.toList(),
                  ),
                ),
              ),
            ),
          for (final gap in clearances)
            Positioned.fromRect(
              rect: dimensions[gap.key]!.label,
              child: IgnorePointer(ignoring: ignore, child: Tooltip(
                message: gap.key.startsWith('column:') ? context.l10n.architectColumnClearance : gap.atStart == null ? context.l10n.architectWallClearance
                    : context.l10n.architectWallEndpointClearance,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: _activeWallClearanceKey == gap.key
                        ? const Color(0xff006e91) : const Color(0xff78818a), width: .7,
                        ),
                  ),
                  child: InkWell(
                    key: ValueKey('wall-clearance-${gap.key}'),
                    onTapDown: (_) => setState(() => _activeWallClearanceKey = gap.key),
                    onTapCancel: () => setState(() => _activeWallClearanceKey = null),
                    onTap: () {
                      setState(() => _radialMenuScreenPosition = null);
                      _editWallClearance(gap);
                    },
                    child: Center(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                        gap.atStart == null ? _project.formatLength(gap.distance)
                            : context.l10n.architectWallEndpointValue(
                                gap.atStart! ? 1 : 2, _project.formatLength(gap.distance),
                                      ),
                        style: const TextStyle(color: Color(0xff20252a), fontSize: 12,
                          fontWeight: FontWeight.w500,
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
          for (final gap in openings)
            Positioned.fromRect(
              rect: openingRects[gap.key]!,
              child: IgnorePointer(ignoring: ignore, child: Tooltip(
                message: context.l10n.architectOpeningClearance,
                child: FittedBox(
                  key: ValueKey('opening-clearance-${gap.key}'),
                  child: SizedBox(
                    width: ArchitectClearanceBadgeLayout.openingBaseSize.width,
                    height: ArchitectClearanceBadgeLayout.openingBaseSize.height,
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3),
                        side: const BorderSide(color: Color(0xff78818a), width: .7,
                            ),
                          ),
                      child: InkWell(
                        onTap: () {
                          setState(() => _radialMenuScreenPosition = null);
                          _editOpeningClearance(gap);
                        },
                        child: Center(child: Text(_project.formatLength(gap.distance),
                          style: TextStyle(color: const Color(0xff20252a), fontSize: 11,
                            fontWeight: gap.isModularSnap ? FontWeight.w600 : FontWeight.normal,
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

    if (edge == null && _handleOffsetLength > 0) {
      var best = 28 / _currentScale;
      for (var i = 0; i < polygon.length; i++) {
        final handle = ArchitectPolygonEditor.offsetEdgeHandle(
          polygon,
          i,
          _currentScale,
          _handleOffsetLength,
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

            _radialMenuScreenPosition != null || _newPointTargetId != null || _marqueeTool.isDrafting) {

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

                top: _commandPreview == null ? 8 : null,
                bottom: _commandPreview == null ? null : 8,

                left: 8,

                right: _selectedHatch != null ? 8 : 64,

                child: Material(

                  color: Theme.of(context).colorScheme.surfaceContainerHigh,

                  elevation: 4,

                  shadowColor: Colors.black54,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(8),

                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant,
                    ),

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

                          tooltip: switch (mode) {
                            ArchitectPolygonEdgeMode.pull => context.l10n.architectEdgePullHint,
                            ArchitectPolygonEdgeMode.move => context.l10n.architectEdgeMoveHint,
                            ArchitectPolygonEdgeMode.extendCatheti => context.l10n.architectEdgeExtendHint,
                          },
                          icon: AppIcon(
                            switch (mode) {
                              ArchitectPolygonEdgeMode.pull => AppIconId.edgePull,
                              ArchitectPolygonEdgeMode.move => AppIconId.edgeMove,
                              ArchitectPolygonEdgeMode.extendCatheti => AppIconId.edgeExtend,
                            },

                            size: 20,

                            color: _polygonEdgeMode == mode

                                ? Theme.of(context).colorScheme.primary

                                : Theme.of(context,
                                  ).colorScheme.onSurfaceVariant,

                          ),

                          onPressed:

                              _polygonDistanceOpen || _polygonEditor.active

                              ? null

                              : () => setState(() => _polygonEdgeMode = mode),

                        ),

                      if (_project.activeStorey.cadPrimitives
                          .any((p) => p.id == targetId && p.isPolygon,
                      ))
                      IconButton(
                        key: const ValueKey('polygon-exact-offset'),
                        constraints: const BoxConstraints.tightFor(width: 36, height: 44,
                          ),
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.architectPolygonExactOffsetHint,
                        isSelected: _polygonPrecisionMode,
                        color: _polygonPrecisionMode
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        selectedIcon: const AppIcon(
                            AppIconId.layoutGrid, size: 20,
                          ),
                        icon: const AppIcon(AppIconId.layoutGrid, size: 20),
                        onPressed: _polygonDistanceOpen || _polygonEditor.active
                            ? null
                            : () => setState(() =>
                                _polygonPrecisionMode = !_polygonPrecisionMode,
                                ),
                      ),
                      Expanded(

                        child: !selected && _selectedHatch == null

                            ? Padding(

                                padding: const EdgeInsets.symmetric(

                                  horizontal: 8,

                                ),

                                child: Text(

                                  context.l10n.architectEdgeSelectHint,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: TextStyle(

                                    color: Theme.of(context,
                                    ).colorScheme.onSurfaceVariant,

                                    fontSize: 12,

                                  ),

                                ),

                              )

                            : LayoutBuilder(builder: (context, constraints) {
                                final hint = _selectedHatch == null
                                    ? context.l10n.architectZoneOffset
                                    : context.l10n.architectOffsetContourHint;
                                if (constraints.maxWidth < 110) {
                                  return IconButton(
                                    key: const ValueKey('polygon-edge-offset',
                                      ),
                                    tooltip: hint,
                                    icon: const AppIcon(
                                        AppIconId.swapVertical, size: 20,
                                      ),
                                    onPressed: _polygonDistanceOpen ? null
                                        : () => _editPolygonDistance(null),
                                  );
                                }
                                return TextButton.icon(

                                key: const ValueKey('polygon-edge-offset'),

                                style: TextButton.styleFrom(

                                  foregroundColor: Theme.of(context,
                                      ).colorScheme.primary,

                                ),

                                onPressed: _polygonDistanceOpen

                                    ? null

                                    : () => _editPolygonDistance(null),

                                icon: Tooltip(
                                  message: _selectedHatch == null
                                      ? context.l10n.architectZoneOffset
                                      : context.l10n.architectOffsetContourHint,
                                  child: const AppIcon(
                                        AppIconId.swapVertical, size: 18,
                                      ),
                                ),

                                label: Text(

                                  context.l10n.architectZoneOffset,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                ),

                              );
                              },
                              ),

                      ),

                      if (_selectedHatch != null) ...[
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 44,
                          ),
                          padding: EdgeInsets.zero,
                          key: const ValueKey('hatch-edit-new-point'),
                          tooltip: context.l10n.bimNewPoint,
                          icon: const AppIcon(AppIconId.locationAdd, size: 20),
                          onPressed: _polygonDistanceOpen ? null
                              : () => _startNewPointSession(_selectedHatch!.id),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 44,
                          ),
                          padding: EdgeInsets.zero,
                          key: const ValueKey('hatch-edit-properties'),
                          tooltip: context.l10n.architectProperties,
                          icon: const AppIcon(AppIconId.properties, size: 20),
                          onPressed: _polygonDistanceOpen ? null : _showProperties,
                        ),
                      ],
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

                        icon: AppIcon(
                          AppIconId.confirm,

                          size: 20,

                          color: Theme.of(context).colorScheme.primary,

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



  List<Offset>? _offsetHatchRing(List<Offset> points, double meters) {
    try {
      return BimOffsetGeometry.ring(points, meters);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _editPolygonDisplacement({
    required String id,
    required int? holeIndex,
    required ArchitectProject source,
    required ArchitectPolygonDisplacement drag,
  }) async {
    if (_polygonDistanceOpen || !mounted) return;
    final previousEdge = _polygonSelectedEdge;
    final unit = source.units;
    // The initial preview uses exactly the value displayed by the keypad.
    final initial = double.parse(unit.toUnit(drag.distance)
        .toStringAsFixed(source.distanceDecimals),
    );
    var meters = unit.fromUnit(initial);
    List<Offset>? candidate;
    var saved = false;

    void preview() {
      candidate = drag.atDistance(meters);
      _elementMovePreview = null;
      _polygonDisplacementLine = null;
      if (candidate != null && identical(source, _project)) {
        try {
          _elementMovePreview = UpdateArchitectPolygon(
            storeyId: source.activeStoreyId, elementId: id,
            polygon: candidate!, holeIndex: holeIndex,
          ).apply(source);
          _polygonDisplacementLine = (drag.origin, drag.target(meters));
        } on ArgumentError {
          candidate = null;
        }
      }
      _repaintPreview();
    }

    setState(() => _polygonDistanceOpen = true);
    preview();
    try {
      await showDialog<void>(context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, dialogSetState) => Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 280),
            backgroundColor: Colors.transparent,
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Theme.of(dialogContext,
                    ).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(padding: const EdgeInsets.all(8),
                    child: Text(drag.edge
                        ? context.l10n.architectEdgeOffsetHint
                        : context.l10n.architectVertexOffsetHint,
                      style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ),
                const SizedBox(height: 6),
                ArchitectShapeDimensionPanel(
                  key: const ValueKey('polygon-displacement-keypad'),
                  values: [initial],
                  labels: [context.l10n.architectPolygonExactOffset],
                  unit: unit.symbol, decimals: source.distanceDecimals,
                  minimum: -double.infinity, signed: true,
                  canSave: candidate != null && identical(source, _project),
                  onChanged: (_, value) {
                    meters = unit.fromUnit(value);
                    preview();
                    dialogSetState(() {});
                  },
                  onSave: () {
                    if (candidate == null || !identical(source, _project)) return;
                    _elementMovePreview = null;
                    _polygonDisplacementLine = null;
                    if (meters.abs() > ArchitectPolygonGeometry.epsilon) {
                      _commands.execute(UpdateArchitectPolygon(
                        storeyId: source.activeStoreyId, elementId: id,
                        polygon: candidate!, holeIndex: holeIndex,
                      ),
                        );
                      _saveBiMProjectIfAttached();
                    }
                    saved = true;
                    _polygonSelectedEdge = drag.edge
                        ? ArchitectPolygonDimensions.hitEdge(
                            candidate!, drag.target(meters), .001,
                            )
                        : null;
                    Navigator.of(dialogContext).pop();
                  },
                  onCancel: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _elementMovePreview = null;
          _polygonDisplacementLine = null;
          _polygonDistanceOpen = false;
          if (!saved && identical(source, _project)) {
            _polygonSelectedEdge = previousEdge;
          }
        });
        _repaintPreview();
      }
    }
  }

  Future<void> _editPolygonDistance(ArchitectPolygonDistance? dimension) async {
    _beginGeometryCommand(ArchitectRadialAction.edit);

    if (_polygonDistanceOpen) return;

    final polygon = _editablePolygon;
    final wholeRing = dimension == null && _selectedHatch != null;
    final edge = _polygonSelectedEdge ?? (wholeRing ? 0 : null);

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

                      ? wholeRing
                          ? holeIndex == null
                              ? context.l10n.architectOffsetOuterContour
                              : context.l10n.architectOffsetInnerContour
                          : context.l10n.architectZoneOffset
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

                  candidate = wholeRing
                      ? _offsetHatchRing(original, meters)
                      : dimension == null
                      ? ArchitectPolygonGeometry.offsetEdge(

                          original,

                          edge,

                          meters,

                          mode: mode,

                        )

                      : dimension.setDistance(original, meters, mode: mode);

                  _elementMovePreview = null;
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



  Future<void> _editPolylineSegment(ArchitectCadPrimitive path) async {
    var index = 0;
    final input = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(context.l10n.architectPolylineEdge),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: 0,
                items: [
                  for (var i = 0; i + 1 < path.linePoints.length; i++)
                    DropdownMenuItem(value: i, child: Text('${i + 1}')),
                ],
                onChanged: (v) => index = v ?? 0,
              ),
              TextFormField(
                controller: input,
                decoration: InputDecoration(
                  labelText: context.l10n.architectPropertyOffset,
                  suffixText: _project.units.symbol,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) =>
                    double.tryParse((v ?? '').replaceAll(',', '.'))?.isFinite ==
                        true
                    ? null
                    : context.l10n.propertiesInvalid,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final points = path.linePoints,
                  v = points[index + 1] - points[index];
              final amount = _project.units.fromUnit(
                double.parse(input.text.replaceAll(',', '.')),
              );
              try {
                _commands.execute(
                  UpdateArchitectPolyline(
                    storeyId: _project.activeStoreyId,
                    elementId: path.id,
                    points: ArchitectPolylineEditing.moveEdge(
                      points,
                      index,
                      Offset(-v.dy, v.dx) / v.distance * amount,
                    ),
                  ),
                );
                _saveBiMProjectIfAttached();
                Navigator.pop(ctx);
                setState(() {});
              } on ArgumentError {
                _operationError();
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    input.dispose();
  }

  Future<void> _editColumnClearance(ArchitectWallClearance gap) async {
    var distance = gap.distance;
    await showDialog<void>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(context.l10n.architectColumnClearance),
        content: SizedBox(
          width: 220,
          child: ArchitectWallDraftingPanel(
            title: context.l10n.architectColumnClearance,
            endLabel: context.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            onContinue: () {},
            onUnlock: () {},
            length: _project.units.toUnit(distance),
            unit: _project.units.symbol,
            decimals: _project.distanceDecimals,
            minimumLength: 0,
            onLength: (v) => distance = _project.units.fromUnit(v),
            onEnd: () {
              try {
                _commands.execute(
                  SetArchitectColumnClearance(
                    storeyId: _project.activeStoreyId,
                    columnId: gap.wallId,
                    key: gap.key,
                    distance: distance,
                  ),
                );
                _saveBiMProjectIfAttached();
                Navigator.pop(ctx);
                setState(() {});
              } on ArgumentError {
                _operationError();
              }
            },
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _activeWallClearanceKey = null);
  }

  void _editWallClearance(ArchitectWallClearance gap) {
    if (gap.key.startsWith('column:')) {
      _editColumnClearance(gap);
      return;
    }


    if (gap.atStart != null) {

      setState(() {

        _wallEndpointClearanceId = gap.wallId;

        _transverseMove = false;

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

    ).whenComplete(() {
      if (mounted) setState(() => _activeWallClearanceKey = null);
    });

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
    _beginGeometryCommand(_commandAction ??
        (command is MirrorArchitectWalls ? ArchitectRadialAction.flip :
         command is TrimArchitectWall || command is CutArchitectWalls
             ? ArchitectRadialAction.cut : ArchitectRadialAction.edit),
    );

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





  // === SECTION: [SEC-08-FENEST] FENESTRATION (DOORS, WINDOWS) & RADIAL ACTIONS ===
  // --- SUBSECTION: [TAG:FENEST_RADIAL] Door/Window Placement & Radial Context Menus ---



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

      hasCasing: _doorHasCasing,

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

      _commands.commit(_project.updateActiveStorey(

        activeStorey.copyWith(walls: updatedWalls)), applyDraftingDefaults: true,
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



  Future<void> _openDecorativeStudio([
    ArchitectDecorativeElement? initialElement,
    String? storeyId,
  ]) async {
    final result = await Navigator.push<ArchitectDecorativeElement>(
      context,
      MaterialPageRoute(
        builder: (_) => DecorativeEditorScreen(
          initialElement:
              initialElement ?? _elementTool.activeDecorativePreset,
          unit: _project.units,
          decimals: _project.distanceDecimals,
        ),
      ),
    );
    if (result != null && mounted) {
      if (initialElement != null && storeyId != null) {
        _commands.execute(
          UpdateArchitectDecorativeElement(
            storeyId: storeyId,
            element: result,
          ),
        );
        _saveBiMProjectIfAttached();
      } else {
        setState(() {
          _elementTool.setDecorativeParams(preset: result);
          if (_activeTool == ArchitectTool.decorativeLibrary) {
            _activeTool = ArchitectTool.decorativeProfile;
          }
        });
      }
    }
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
          createNew: true,

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

    if (_acceptsAnySelection || _activeTool.usesComponent) {
      final secHit = _hitSection(point);
      if (secHit != null) return secHit;
      final elvHit = _hitElevation(point);
      if (elvHit != null) return elvHit;

      {

        for (final component in _project.activeStorey.components.reversed) {

          if (!component.isVisible || !_showFurnitureLayer && !component.isServiceComponent) continue;
          if (!_acceptsAnySelection && component.isServiceComponent != (_activeTool == ArchitectTool.services)) continue;
          if (component.containsPoint(point)) return component.id;

        }

      }

      if (_activeTool.usesComponent && !_acceptsAnySelection) return null;

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
    if (_marqueeTool.isDrafting || _curvingEdgeElementId != null) return false;

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

    if (_effectiveSelection.isNotEmpty) {
      for (final selId in _effectiveSelection) {
        final wall = _project.activeStorey.walls.where((w) => w.id == selId).firstOrNull;
        if (wall != null) {
          final (ratio, dist) = wall.projectPoint(raw);
          final screenDist = dist * _currentScale;
          final ratioTol = (44.0 / _currentScale) / math.max(wall.length, 0.01);
          if (screenDist <= math.max(wall.thickness * _currentScale / 2 + 40.0, 44.0) &&
              ratio >= -ratioTol &&
              ratio <= 1.0 + ratioTol) {
            return true;
          }
        }
      }
    }

    if (_selectionCandidates(raw).any(_effectiveSelection.contains)) {

      return true;

    }

    if (_selectAt(raw, invalidateGesture: false)) {

      return true;

    }

    if (_commands.view == ArchitectWorkspaceView.section &&

        (_acceptsAnySelection || _activeTool == ArchitectTool.roof)) {

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

          if (_canAdoptPickedTool) {

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
    _dismissTouchCandidates();
    if (_marqueeTool.isDrafting || _curvingEdgeElementId != null) return false;

    // Candidates already respect the active drawing tool. Existing elements
    // keep their context menu while that tool is active, as well as in Select.

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

    // Context menu for room zones / functional areas
    final hitZone = _findZoneAt(raw);
    if (_activeTool == ArchitectTool.zone) {
      if (hitZone != null) {
        setState(() {
          _cancelActiveDrags();
          _selectedZoneId = hitZone.id;
          _selectedElementId = null;
          _selectionIds
            ..clear()
            ..add(hitZone.id);
          _zoneTool.startEditingZone(hitZone);
        });
        unawaited(_showZoneContextMenu(screenPoint, hitZone));
        return true;
      }
    }

    // Context menu for Raster Underlay
    final storeyRasters = _project.rasterUnderlaysForStorey(
      _project.activeStorey.id,
    );
    final hitRaster = storeyRasters.reversed
        .where((r) => r.visible && r.containsLocalPoint(raw))
        .firstOrNull;
    if (hitRaster != null &&
        (_activeTool == ArchitectTool.rasterUnderlay ||
            _activeTool == ArchitectTool.pan ||
            _activeTool == ArchitectTool.select)) {
      setState(() {
        _cancelActiveDrags();
        _selectedRasterId = hitRaster.id;
        _isCadUnderlaySelected = false;
        _selectedElementId = null;
        _selectionIds.clear();
        _radialMenuScreenPosition = screenPoint;
        _radialMenuElementId = 'underlay_raster_${hitRaster.id}';
        _radialMenuItems = _buildRadialMenuItems('underlay_raster_${hitRaster.id}');
      });
      return true;
    }

    // Context menu for CAD Underlay
    final cadCfg = _currentCadUnderlayConfig;
    final cadDoc = _underlaysByStorey[_project.activeStorey.id];
    final isOverCad = cadCfg != null &&
        cadCfg.visible &&
        cadDoc != null &&
        (_isCadUnderlaySelected ||
            _effectiveUnderlayFrame.rectToModel(cadDoc.bounds).contains(raw));
    if (isOverCad &&
        (_activeTool == ArchitectTool.cadUnderlay ||
            _activeTool == ArchitectTool.pan ||
            (_activeTool == ArchitectTool.select &&
                _effectiveSelection.isEmpty))) {
      setState(() {
        _cancelActiveDrags();
        _isCadUnderlaySelected = true;
        _selectedRasterId = null;
        _selectedElementId = null;
        _selectionIds.clear();
        _radialMenuScreenPosition = screenPoint;
        _radialMenuElementId = 'underlay_cad';
        _radialMenuItems = _buildRadialMenuItems('underlay_cad');
      });
      return true;
    }


    String? selectedHitId;
    if (_effectiveSelection.isNotEmpty) {
      for (final selId in _effectiveSelection) {
        final wall = _project.activeStorey.walls.where((w) => w.id == selId).firstOrNull;
        if (wall != null) {
          final (ratio, dist) = wall.projectPoint(raw);
          final screenDist = dist * _currentScale;
          final ratioTol = (44.0 / _currentScale) / math.max(wall.length, 0.01);
          if (screenDist <= math.max(wall.thickness * _currentScale / 2 + 40.0, 44.0) &&
              ratio >= -ratioTol &&
              ratio <= 1.0 + ratioTol) {
            selectedHitId = wall.id;
            break;
          }
        }
      }
    }

    final candidates = _selectionCandidates(raw);

    final ok =
        selectedHitId != null ||
        candidates.any(_effectiveSelection.contains) ||
        _selectAt(raw, invalidateGesture: false);

    if (ok) {

      final id =
          selectedHitId ??
          _selectedElementId ??

          _selectedZoneId ??

          _effectiveSelection.firstOrNull;

      if (id != null) {
        final zone = _project.activeStorey.zones.where((z) => z.id == id).firstOrNull;
        if (zone != null) {
          setState(_cancelActiveDrags);
          unawaited(_showZoneContextMenu(screenPoint, zone));
          return true;
        }

        setState(() {

          _cancelActiveDrags();

          _radialMenuScreenPosition = screenPoint;

          _radialMenuElementId = id;

          _radialMenuItems = _buildRadialMenuItems(id);

        });

      }

      return true;

    }

    if (_commands.view == ArchitectWorkspaceView.section &&

        (_acceptsAnySelection || _activeTool == ArchitectTool.roof)) {

      _cacheProjection();

      final hitRoof =

          _sectionGeometry?.pickRoof(

            _modelToSection(raw),

            16 / _currentScale,

          ) ??

          _selectedSectionRoofId;

      if (hitRoof != null) {

        setState(() {

          _cancelActiveDrags();

          _selectionIds.clear();

          _selectedElementId = null;

          _selectedZoneId = null;

          _selectedSectionRoofId = hitRoof;

          if (_canAdoptPickedTool) {

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



  Future<void> _showZoneContextMenu(
    Offset localPoint,
    ArchitectZone zone,
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
          value: 'properties',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.properties,
                size: 18,
                color: Color(0xFFB388FF),
              ),
              const SizedBox(width: 8),
              Text(l.architectProperties),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'schedule',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.schedule,
                size: 18,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 8),
              Text(l.architectZoneScheduleTitle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.edit,
                size: 18,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              Text(l.architectZoneEditContour),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'move',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.move,
                size: 18,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 8),
              Text(l.architectSelectionMove),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.duplicate,
                size: 18,
                color: Color(0xFF64FFDA),
              ),
              const SizedBox(width: 8),
              Text(l.duplicateElement),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'presets',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.settings,
                size: 18,
                color: Color(0xFF80CBC4),
              ),
              const SizedBox(width: 8),
              Text(l.architectZonePresetsDialogTitle),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const AppIcon(
                AppIconId.delete,
                size: 18,
                color: Color(0xFFFF5252),
              ),
              const SizedBox(width: 8),
              Text(
                l.delete,
                style: const TextStyle(color: Color(0xFFFF5252)),
              ),
            ],
          ),
        ),
      ],
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'properties':
        _showProperties();
        break;
      case 'schedule':
        _showRoomScheduleDialog();
        break;
      case 'edit':
        setState(() {
          _activeTool = ArchitectTool.zone;
          _selectedZoneId = zone.id;
          _selectionIds
            ..clear()
            ..add(zone.id);
          _zoneTool.startEditingZone(zone);
        });
        break;
      case 'move':
        setState(() {
          _selectedZoneId = zone.id;
          _selectionIds
            ..clear()
            ..add(zone.id);
          _moveSelection = true;
        });
        break;
      case 'duplicate':
        setState(() {
          _selectedZoneId = zone.id;
          _selectionIds
            ..clear()
            ..add(zone.id);
        });
        _beginGeometryCommand(ArchitectRadialAction.duplicate);
        break;
      case 'presets':
        _showZonePresetsDialog(zone.category);
        break;
      case 'delete':
        setState(() {
          _selectedZoneId = zone.id;
          _selectionIds
            ..clear()
            ..add(zone.id);
        });
        _deleteSelection();
        break;
    }
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

              const AppIcon(AppIconId.swapVertical, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofMoveVerticalAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'snap_walls',

          child: Row(

            children: [

              const AppIcon(AppIconId.alignBottom, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofSnapToWallsAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'properties',

          child: Row(

            children: [

              const AppIcon(AppIconId.layers, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofPropertiesAction),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'flip_slope',

          child: Row(

            children: [

              const AppIcon(AppIconId.swapHorizontal, size: 18),

              const SizedBox(width: 8),

              Text(l.architectRoofFlipSlope),

            ],

          ),

        ),

        PopupMenuItem(

          value: 'delete',

          child: Row(

            children: [

              const AppIcon(AppIconId.delete, size: 18),

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

    if (_commands.isPlan && ArchitectRotation.supports(_project.activeStorey, _effectiveSelection,
        ) &&
        !items.any((item) => item.action == ArchitectRadialAction.rotate)) {
      items.add(_radialItem(action: ArchitectRadialAction.rotate, color: const Color(0xFF40C4FF),
        ),
      );
    }

    if (!_is3DView && ArchitectOffset.supports(_project.activeStorey, _effectiveSelection)) {
      items.add(_radialItem(action: ArchitectRadialAction.offset, color: const Color(0xFF80CBC4)));
    }

    final canChamferFillet = _selectedWallIds.isNotEmpty ||
        _selectedLineIds.isNotEmpty ||
        _project.activeStorey.slabs.any((s) => _effectiveSelection.contains(s.id)) ||
        _project.activeStorey.cadPrimitives.any((p) => _effectiveSelection.contains(p.id)) ||
        _project.activeStorey.pathways.any((p) => _effectiveSelection.contains(p.id)) ||
        _project.activeStorey.streets.any((s) => _effectiveSelection.contains(s.id)) ||
        _project.activeStorey.siteFences.any((f) => _effectiveSelection.contains(f.id)) ||
        _project.activeStorey.vegetation.any((v) => _effectiveSelection.contains(v.id) && v.isHedge) ||
        _project.proposedTerrain.boundaries.any((b) => _effectiveSelection.contains(b.id)) ||
        _project.proposedTerrain.contours.any((c) => _effectiveSelection.contains(c.id)) ||
        _project.existingTerrain.boundaries.any((b) => _effectiveSelection.contains(b.id)) ||
        _project.existingTerrain.contours.any((c) => _effectiveSelection.contains(c.id));
    if (canChamferFillet) {
      if (!items.any((item) => item.action == ArchitectRadialAction.chamfer)) {
        items.add(_radialItem(action: ArchitectRadialAction.chamfer, color: const Color(0xFF80CBC4)));
      }
      if (!items.any((item) => item.action == ArchitectRadialAction.fillet)) {
        items.add(_radialItem(action: ArchitectRadialAction.fillet, color: const Color(0xFF4DB6AC)));
      }
    }

    if (_commands.isPlan && _editingGroupId == null) {

      final group = _selectedGroup;

      if (group != null) {

        items.addAll([

          _radialItem(action: ArchitectRadialAction.ungroup, color: const Color(0xFF80CBC4),
          ),

          _radialItem(action: ArchitectRadialAction.editGroup, color: const Color(0xFF80CBC4),
          ),

        ]);

      } else if (_effectiveSelection.length > 1 &&

          _project.activeStorey.groupableIds.containsAll(_effectiveSelection) &&

          !_project.activeStorey.groups.any((g) => g.elementIds.any(_effectiveSelection.contains),
          )) {

        items.add(_radialItem(action: ArchitectRadialAction.group, color: const Color(0xFF80CBC4),
          ),
        );

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
            action: ArchitectRadialAction.attach,
            color: const Color(0xFF00E5FF),
          ),
          _radialItem(
            action: ArchitectRadialAction.detach,
            color: const Color(0xFFFFB74D),
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

          action: ArchitectRadialAction.properties,

          color: const Color(0xFFB388FF),

        ),

        _radialItem(

          action: ArchitectRadialAction.delete,

          color: const Color(0xFFFF5252),

        ),

      ];

    }



    if (elementId == 'underlay_cad') {
      items.add(_radialItem(action: ArchitectRadialAction.move, color: const Color(0xFFFFB300)));
      items.add(_radialItem(action: ArchitectRadialAction.properties, color: const Color(0xFFB388FF)));
      items.add(_radialItem(action: ArchitectRadialAction.offset, color: const Color(0xFF4FC3F7)));
      items.add(_radialItem(action: ArchitectRadialAction.cut, color: const Color(0xFFFF7043)));
      items.add(_radialItem(action: ArchitectRadialAction.hide, color: const Color(0xFF90CAF9)));
      items.add(_radialItem(action: ArchitectRadialAction.delete, color: const Color(0xFFFF5252)));
      return items;
    }
    if (elementId.startsWith('underlay_raster')) {
      items.add(_radialItem(action: ArchitectRadialAction.move, color: const Color(0xFFFFB300)));
      items.add(_radialItem(action: ArchitectRadialAction.properties, color: const Color(0xFFB388FF)));
      items.add(_radialItem(action: ArchitectRadialAction.offset, color: const Color(0xFF4FC3F7)));
      items.add(_radialItem(action: ArchitectRadialAction.hide, color: const Color(0xFF90CAF9)));
      items.add(_radialItem(action: ArchitectRadialAction.delete, color: const Color(0xFFFF5252)));
      return items;
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



    if (storey.annotations.any((a) => a.id == elementId)) {
      for (final action in [ArchitectRadialAction.edit,ArchitectRadialAction.move,
        ArchitectRadialAction.rotate,ArchitectRadialAction.duplicate,
        ArchitectRadialAction.properties,ArchitectRadialAction.mirrorMove]) {
        items.add(_radialItem(action:action,color:const Color(0xFF00E5FF)));
      }
    } else if (isCol || isBeam) {

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
        items.add(
          _radialItem(
            action: ArchitectRadialAction.attach,
            color: const Color(0xFF00E5FF),
          ),
        );
        items.add(
          _radialItem(
            action: ArchitectRadialAction.detach,
            color: const Color(0xFFFFB74D),
          ),
        );
        final wall = storey.walls.where((w) => w.id == elementId).firstOrNull;
        if (wall != null && wall.isCurved) {
          items.add(
            _radialItem(
              action: ArchitectRadialAction.straighten,
              color: const Color(0xFF00E5FF),
            ),
          );
        } else {
          items.add(
            _radialItem(
              action: ArchitectRadialAction.curve,
              color: const Color(0xFF00E5FF),
            ),
          );
        }
      } else if (isLine) {
        final prim = storey.cadPrimitives.where((c) => c.id == elementId).firstOrNull;
        final isCurved = prim != null && (prim.type == CadPrimitiveType.arc || (prim.arcBulge != null && prim.arcBulge!.abs() > 1e-6));
        if (isCurved) {
          items.add(
            _radialItem(
              action: ArchitectRadialAction.straighten,
              color: const Color(0xFF00E5FF),
            ),
          );
        } else {
          items.add(
            _radialItem(
              action: ArchitectRadialAction.curve,
              color: const Color(0xFF00E5FF),
            ),
          );
        }
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
      if (isSlab || (isCadPrim && !isLine)) {
        items.add(
          _radialItem(
            action: ArchitectRadialAction.curve,
            color: const Color(0xFF00E5FF),
          ),
        );
      }

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

        color: const Color(0xFF80CBC4),
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



    if (!isDoor && !isWindow && !isAxis) {

      items.add(

        _radialItem(

          action: ArchitectRadialAction.mirrorMove,

          color: const Color(0xFF00E5FF),

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
    _beginGeometryCommand(ArchitectRadialAction.newPoint);
    _marqueeTool.cancel();
    if (initialPick != null) _selectPolygonContour(initialPick);
    final holeIndex = _selectedPolygonHoleIndex;
    final source = _project.activeStorey;
    final path = InsertArchitectElementPoint.pathOf(source, id, holeIndex: holeIndex,
    );
    if (path == null || path.points.length < 2) {
      _cancelGeometryCommand();
      return;
    }
    _cancelActiveDrags();
    setState(() {
      _newPointTargetId = id;
      _newPointHoleIndex = holeIndex;
      _newPointSource = source;
      _newPointCandidate = null;
      _newPointValid = false;
      _newPointDragOffset = Offset.zero;
      _newPointLeaderLine = null;
      _newPointDistanceEditorOpen = false;
      _newPointExactPlacement = false;
      _radialMenuScreenPosition = null;
      _activeSnapLabel = null;
    });
    final seed = initialPick ?? InsertArchitectElementPoint.locate(
      source, id, (path.points[0] + path.points[1]) / 2,
      atMidpoint: true, holeIndex: holeIndex,
    )!.point;
    final hit = InsertArchitectElementPoint.locate(source, id, seed, holeIndex: holeIndex,
    )!;
    final wall = source.walls.where((w) => w.id == id).firstOrNull;
    final edge = path.points[(hit.edge + 1) % path.points.length] - path.points[hit.edge];
    final tangent = wall?.tangentAt(hit.ratio) ?? edge / edge.distance;
    var normal = Offset(-tangent.dy, tangent.dx);
    if (normal.dy > 0 || (normal.dy.abs() < 1e-8 && normal.dx < 0)) normal = -normal;
    final screen = _viewport.toScreen(hit.point);
    final length = _handleOffsetLength > 0 ? _handleOffsetLength : 48.0;
    final safe = (Offset.zero & _viewport.size).deflate(24);
    if (!safe.contains(screen + normal * length) && safe.contains(screen - normal * length)) {
      normal = -normal;
    }
    _newPointGripDirection = normal;
    _updateNewPointCandidate(seed, isTouch: false);
  }

  void _cancelNewPointSession() {

    setState(() {

      _newPointTargetId = null;
      _newPointHoleIndex = null;

      _newPointCandidate = null;

      _newPointLeaderLine = null;

      _newPointDistanceEditorOpen = false;
      _newPointExactPlacement = false;

      _activeSnapLabel = null;

      _activeMagneticGuides = [];

    });

    _repaintPreview();

  }



  void _updateNewPointCandidate(Offset rawModel, {required bool isTouch}) {

    if (_newPointTargetId == null) return;

    final source = _newPointSource ?? _project.activeStorey;
    final curvedTarget = source.walls.where((w) => w.id == _newPointTargetId && w.isCurved).firstOrNull;
    if (curvedTarget != null) {
      var hit = InsertArchitectElementPoint.locate(source, curvedTarget.id, rawModel,
      )!;
      String? label;
      final mid = curvedTarget.referencePointAt(.5);
      if ((hit.point - mid).distance * _currentScale <= 16) {
        hit = (point: mid, edge: 0, ratio: .5);
        label = 'Midpoint';
      }
      _setNewPointCandidate(hit.point, label, const []);
      return;
    }
    final path = InsertArchitectElementPoint.pathOf(

      source,

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

    final storeyWalls = source.walls;



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



    _setNewPointCandidate(candidate, snapLabel, guides);
  }

  void _setNewPointCandidate(Offset candidate, String? snapLabel,
      List<(Offset, Offset)> guides,
  ) {
    final wasValid = _newPointValid;
    _newPointCandidate = candidate;
    _newPointValid = InsertArchitectElementPoint.canInsert(
      _newPointSource ?? _project.activeStorey, _newPointTargetId!, candidate,
      holeIndex: _newPointHoleIndex,
    );
    _newPointLeaderLine = (candidate, candidate + _newPointGripOffset / _currentScale,
    );
    _activeSnapLabel = snapLabel;
    _activeMagneticGuides = guides;
    _cursorModel = candidate;
    if (wasValid != _newPointValid) setState(() {});
    _repaintPreview();
  }

  ArchitectWall? get _newPointWall => _newPointTargetId == null ? null
      : (_newPointSource ?? _project.activeStorey).walls
          .where((wall) => wall.id == _newPointTargetId).firstOrNull;

  Future<void> _editNewPointDistance(int endpoint) async {
    final wall = _newPointWall;
    final candidate = _newPointCandidate;
    final source = _newPointSource;
    if (wall == null || candidate == null || source == null ||
        _newPointDistanceEditorOpen) {
      return;
    }
    final session = _commandPreview;
    final commandContext = _commandContext;
    final oldLabel = _activeSnapLabel;
    final oldGuides = _activeMagneticGuides;
    final oldExact = _newPointExactPlacement;
    bool current() => mounted && identical(_commandPreview, session) &&
        _commandContext == commandContext && identical(_newPointSource, source) &&
        _newPointTargetId == wall.id;
    Offset point(double distance) =>
        ArchitectNewPointMeasure.pointAtDistance(wall, endpoint, distance);
    bool accepts(double distance) {
      if (!current()) return false;
      try {
        return InsertArchitectElementPoint.canInsert(source, wall.id, point(distance));
      } on ArgumentError { return false; }
    }
    _newPointDistanceEditorOpen = true;
    double? result;
    try {
      result = await showDialog<double>(context: context,
        builder: (_) => ArchitectNewPointDistanceDialog(
          project: _project, endpoint: endpoint,
          distance: ArchitectNewPointMeasure(wall, candidate).distanceFrom(endpoint),
          accepts: accepts,
          onPreview: (distance) {
            if (accepts(distance)) _setNewPointCandidate(point(distance), null, const []);
          },
        ));
    } finally {
      if (current()) {
        _newPointDistanceEditorOpen = false;
        if (result != null && accepts(result)) {
          _setNewPointCandidate(point(result), null, const []);
          _newPointExactPlacement = true;
        } else {
          _setNewPointCandidate(candidate, oldLabel, oldGuides);
          _newPointExactPlacement = oldExact;
        }
      }
    }
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
      _newPointHoleIndex = null;
      _placingWithHold = false;
      _touchPosition = null;
      _selectionIds..clear()..add(targetId);
      _selectedElementId = targetId;
      _selectedZoneId = _project.activeStorey.zones.any((z) => z.id == targetId)
          ? targetId : null;
      _restorePickedTool(targetId);
      _newPointCandidate = null;

      _newPointLeaderLine = null;

      _newPointDistanceEditorOpen = false;
      _newPointExactPlacement = false;

      _activeSnapLabel = null;

      _activeMagneticGuides = [];

      if (path != null && path.closed && hit != null) {
        _polygonContourElementId = targetId;
        _polygonContourIndex = holeIndex == null ? 0 : holeIndex + 1;

        if (_polygonEditId != targetId && _selectedHatch != null) _polygonEdgeMode = ArchitectPolygonEdgeMode.pull;
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



  void _groupSelection() {
    _discardGeometryCommand();

    final ids = _effectiveSelection;

    try {

      _commands.execute(GroupArchitectElements(storeyId: _project.activeStoreyId,

        groupId: ArchitectElementId.next('group'), elementIds: ids,
        ),
      );

      setState(() {

        _selectionIds..clear()..addAll(ids);

        _selectedElementId = null; _selectedZoneId = null;

        _restorePickedTool(); _moveSelection = true;

      });

      _saveBiMProjectIfAttached();

    } on ArgumentError { _operationError(); }

  }

  void _ungroupSelection() {
    _discardGeometryCommand();

    final group = _selectedGroup;

    if (group == null) return;

    _commands.execute(UngroupArchitectElements(storeyId: _project.activeStoreyId, groupId: group.id,
      ),
    );

    _clearSelection(); _saveBiMProjectIfAttached();

  }

  void _enterGroup() {
    _discardGeometryCommand();

    final group = _selectedGroup;

    if (group == null) return;

    _clearSelection();

    setState(() { _editingGroupId = group.id; _activeTool = ArchitectTool.pan; });

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

      Expanded(child: Text(context.l10n.bimInsideGroup, overflow: TextOverflow.ellipsis,
            ),
          ),

      TextButton(key: const ValueKey('architect-group-done'), onPressed: _exitGroup,

        child: Text(context.l10n.bimGroupDone),
          ),

    ],
      ),
    ),

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
    if (id == 'underlay_cad') {
      switch (action) {
        case ArchitectRadialAction.move:
          _startUnderlaySnapDrag(isCad: true);
          return;
        case ArchitectRadialAction.properties:
          _openCadEditDialog();
          return;
        case ArchitectRadialAction.offset:
          _openCadScaleDialog();
          return;
        case ArchitectRadialAction.cut:
          _openCadMaskMenu(Offset.zero);
          return;
        case ArchitectRadialAction.hide:
          _toggleCadVisibility(false);
          return;
        case ArchitectRadialAction.delete:
          _removeCurrentCadUnderlay();
          return;
        default:
          return;
      }
    }
    if (id.startsWith('underlay_raster')) {
      final rasterId = id.replaceFirst('underlay_raster_', '');
      switch (action) {
        case ArchitectRadialAction.move:
          _startUnderlaySnapDrag(isCad: false, rasterId: rasterId);
          return;
        case ArchitectRadialAction.properties:
          _openRasterEditDialog();
          return;
        case ArchitectRadialAction.offset:
          _openRasterScaleDialog();
          return;
        case ArchitectRadialAction.cut:
          _openRasterMaskMenu(Offset.zero);
          return;
        case ArchitectRadialAction.hide:
          _toggleRasterVisibility(rasterId, false);
          return;
        case ArchitectRadialAction.delete:
          _deleteSelectedRaster();
          return;
        default:
          return;
      }
    }

    if (action == ArchitectRadialAction.curve) {
      _startEdgeCurvingSession(id);
      return;
    }
    if (const {
      ArchitectRadialAction.edit,
      ArchitectRadialAction.duplicate, ArchitectRadialAction.rotate,
      ArchitectRadialAction.split,
      ArchitectRadialAction.cut, ArchitectRadialAction.cutOpening,
      ArchitectRadialAction.offset, ArchitectRadialAction.newPoint,
      ArchitectRadialAction.join, ArchitectRadialAction.straighten,
      ArchitectRadialAction.mirrorMove, ArchitectRadialAction.mirrorCopy,
    }.contains(action)) {
      _beginGeometryCommand(action);
    } else {
      _discardGeometryCommand();
    }

    if (action == ArchitectRadialAction.rotate && _commands.isPlan &&
        ArchitectRotation.supports(_project.activeStorey, _effectiveSelection,
        )) {
      _startRotation();
      return;
    }

    if (action == ArchitectRadialAction.chamfer) {
      _triggerChamfer();
      return;
    }
    if (action == ArchitectRadialAction.fillet) {
      _triggerFillet();
      return;
    }

    if (action == ArchitectRadialAction.group) { _groupSelection(); return; }

    if (action == ArchitectRadialAction.ungroup) { _ungroupSelection(); return; }

    if (action == ArchitectRadialAction.editGroup) { _enterGroup(); return; }

    if (action == ArchitectRadialAction.offset && _selectedHatch != null) {
      if (pick != null) _selectPolygonContour(pick);
      setState(() => _polygonEditId = id);
      _editPolygonDistance(null);
      return;
    }
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
          _startDragSession();
          return;

        case ArchitectRadialAction.properties:

          _showProperties();

          return;

        case ArchitectRadialAction.join:

          _triggerWallJoin();

          return;

        case ArchitectRadialAction.attach:
          _triggerWallAttach();
          return;

        case ArchitectRadialAction.detach:
          _triggerWallDetach();
          return;

        case ArchitectRadialAction.mirrorMove:

          _startMirrorSession();

          return;

        case ArchitectRadialAction.mirrorCopy:

          _startMirrorSession();

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
        if (_project.activeStorey.annotations.any((a) => a.id == id) || _project.activeStorey.elevationMarkers.any((a) => a.id == id)) {
          _showProperties();
          break;
        }
        if (pick != null) _selectPolygonContour(pick);




        final polygon = _selectedPolygon;

        if (polygon != null) {

          _cancelActiveDrags();

          setState(() {

            if (_polygonEditId != id && _selectedHatch != null) _polygonEdgeMode = ArchitectPolygonEdgeMode.pull;
            _polygonEditId = id;

            _polygonSelectedEdge = _selectedPolygonHoleIndex == null
                ? _selectedRoof?.safeEavesEdgeIndex : null;

            _moveSelection = false;

          });
          if (pick != null) _selectPolygonEdge(pick);

        } else if (_selectedPolyline != null) {
          _cancelActiveDrags();
          setState(() => _moveSelection = false);
        } else if (_selectedLinearElement != null) {

          _wallEndpointOriginal = _selectedLinearElement;

          _wallDragStart = false;

          _elementMoveOriginal = _project;

          _elementMovePreview = _project;

          _isHandleEngaged = true;

        }

        break;



      case ArchitectRadialAction.straighten:
        final wall = _selectedWall ?? _project.activeStorey.walls.where((w) => w.id == id).firstOrNull;
        if (wall != null) {
          if (wall.isCurved) {
            _commands.execute(
              _linearCommand(
                UpdateArchitectWall(
                  storeyId: _project.activeStorey.id,
                  wall: wall.copyWith(arcBulge: 0.0),
                ),
              ),
            );
            _saveBiMProjectIfAttached();
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.architectWallStraightened)),
            );
          } else {
            _straightenWall(wall);
          }
        } else {
          final prim = _project.activeStorey.cadPrimitives.where((c) => c.id == id).firstOrNull;
          if (prim != null) {
            _commands.execute(
              PlaceArchitectCadPrimitive(
                storeyId: _project.activeStorey.id,
                primitive: prim.copyWith(
                  type: CadPrimitiveType.line,
                  arcBulge: 0.0,
                ),
              ),
            );
            _saveBiMProjectIfAttached();
            HapticFeedback.mediumImpact();
          }
        }
        break;



      case ArchitectRadialAction.move:
        _startDragSession();
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
        if (_selectionIds.isNotEmpty && _selectionIds.contains(id)) {
          _deleteSelection();
        } else {
          _selectedElementId = id;
          _selectionIds.add(id);
          _deleteSelection();
        }
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

      case ArchitectRadialAction.attach:
        _triggerWallAttach();
        break;

      case ArchitectRadialAction.detach:
        _triggerWallDetach();
        break;



      case ArchitectRadialAction.mirrorMove:

        _startMirrorSession();

        break;



      case ArchitectRadialAction.mirrorCopy:

        _startMirrorSession();

        break;

      case ArchitectRadialAction.chamfer:
        _triggerChamfer();
        break;

      case ArchitectRadialAction.fillet:
        _triggerFillet();
        break;

      case ArchitectRadialAction.curve:
        _startEdgeCurvingSession(id);
        break;

      case ArchitectRadialAction.hide:
        break;

    }

  }



  void _handleSelectionTap(Offset point) {
    final activeStorey = _project.activeStorey;
    final candidateWallIds = {
      ..._selectionIds,
      ?_selectedElementId,
      ..._modelCommands.exteriorReviewWallIds,
    };
    if (candidateWallIds.isNotEmpty) {
      final candidateWalls = activeStorey.walls
          .where((w) => candidateWallIds.contains(w.id))
          .toList();
      for (final wall in candidateWalls) {
        if (ArchitectWallExteriorPainter.hitTest(wall, point, _currentScale)) {
          final flipIds = _selectionIds.isNotEmpty && _selectionIds.contains(wall.id)
              ? _selectionIds
                  .where((id) => activeStorey.walls.any((w) => w.id == id))
                  .toSet()
              : {wall.id};
          _executeWallEdit(
            MirrorArchitectWalls(storeyId: activeStorey.id, wallIds: flipIds),
          );
          if (!_selectionIds.contains(wall.id)) {
            setState(() {
              _selectionIds
                ..clear()
                ..add(wall.id);
              _selectedElementId = wall.id;
            });
          }
          HapticFeedback.selectionClick();
          return;
        }
      }
    }

    _modelCommands.exteriorReviewWallIds = const {};

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
        scale: _currentScale,
        handleOffsetLength: _handleOffsetLength,
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

    if (selectedRoof != null && selectedRoof.containsPoint(point)) {
      return;
    }

    final selectedWall = _selectedWall;
    if (selectedWall != null) {
      final (ratio, dist) = selectedWall.projectPoint(point);
      final screenDist = dist * _currentScale;
      final ratioTol = (40.0 / _currentScale) / math.max(selectedWall.length, 0.01);
      if (screenDist <= math.max(selectedWall.thickness * _currentScale / 2 + 36.0, 44.0) &&
          ratio >= -ratioTol &&
          ratio <= 1.0 + ratioTol) {
        return;
      }
    }

    if (!_selectAt(point, toggle: _multiSelect)) _clearSelection();

  }



  bool _selectAt(Offset point, {
    bool invalidateGesture = true, bool toggle = false,
  }) {
    if (_touchInput && invalidateGesture) {
      final ids = _touchHits(point);
      setState(() => _touchCandidates = ids.length > 1
          ? ArchitectSelectionCandidates(ids, point) : null,
      );
      if (ids.isEmpty) return false;
      if (ids.length > 1 && _multiSelect) return true;
      return _applySelectionId(ids.first, point,
        invalidateGesture: invalidateGesture, toggle: toggle, direct: ids.length > 1,
      );
    }
    final id = _nextSelection(point, advance: invalidateGesture);
    if (id == null) return false;
    return _applySelectionId(id, point,
      invalidateGesture: invalidateGesture, toggle: toggle,
    );
  }

  bool _applySelectionId(String id, Offset point, {
    bool invalidateGesture = true, bool toggle = false, bool direct = false,
  }) {
    if (id == 'underlay_cad') {
      _cancelActiveDrags();
      setState(() {
        _isCadUnderlaySelected = true;
        _selectedRasterId = null;
        _selectedElementId = null;
        _selectionIds.clear();
      });
      return true;
    }
    if (id.startsWith('underlay_raster_')) {
      _cancelActiveDrags();
      final rasterId = id.substring('underlay_raster_'.length);
      setState(() {
        _selectedRasterId = rasterId;
        _isCadUnderlaySelected = false;
        _selectedElementId = null;
        _selectionIds.clear();
      });
      return true;
    }

    if (!_acceptsAnySelection &&

        !_isElementAllowedForTool(id, _activeTool)) {

      return false;

    }

    if (!direct && !_multiSelect && id == _selectedElementId && _selectionIds.length == 1) {
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

    final adoptTool = _canAdoptPickedTool;

    setState(() {

      if (invalidateGesture) _interactionEpoch++;

      _draftStart = null;

      _wallArcEnd = null;

      _draftEnd = null;

      if (_explicitSelectionOperation) {
        final current=Set<String>.of(_effectiveSelection);
        final members=_commands.isPlan && _editingGroupId==null
            ? _project.activeStorey.expandGroups({id}) : {id};
        _selectionIds..clear()..addAll(ArchitectMarqueeTool.combine(current,members,_selectionOperation),
          );
      } else if (shouldMulti) {

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

          ..addAll(_commands.isPlan && _editingGroupId == null ? _project.activeStorey.expandGroups({id}) : {id},
          );

      }

      final primary = _selectionIds.contains(id)

          ? id

          : _selectionIds.lastOrNull;



      if (primary != _selectedElementId || _selectionIds.length != 1) {
        _wallEndpointClearanceId = null;

        _transverseMove = false;

        _moveSelection = false;

      }

      final grouped = _selectionIds.isNotEmpty && _editingGroupId == null && _commands.isPlan && _project.activeStorey.groupFor(id) != null;

      _selectedElementId = grouped ? null : primary;

      _selectedZoneId = null;

      if (grouped && adoptTool) {

        _activeTool = ArchitectTool.pan;

        _selectionContextActive = true;

        _moveSelection = true;

      }

      if (!grouped && adoptTool && primary != null) {

        _restorePickedTool(primary);

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

        final pathway = _project.activeStorey.pathways
            .where((p) => p.id == primary)
            .firstOrNull;
        if (pathway != null) {
          _landscapeTool.loadFromPathway(pathway);
        }
        final street = _project.activeStorey.streets
            .where((s) => s.id == primary)
            .firstOrNull;
        if (street != null) {
          _landscapeTool.loadFromStreet(street);
        }
        final fence = _project.activeStorey.siteFences
            .where((f) => f.id == primary)
            .firstOrNull;
        if (fence != null) {
          _landscapeTool.loadFromFence(fence);
        }
        final veg = _project.activeStorey.vegetation
            .where((v) => v.id == primary)
            .firstOrNull;
        if (veg != null) {
          _landscapeTool.loadFromVegetation(veg);
        }
        for (final (surf, state) in [
          (_project.proposedTerrain, ArchitectTerrainState.proposed),
          (_project.existingTerrain, ArchitectTerrainState.existing),
        ]) {
          final bnd = surf.boundaries.where((b) => b.id == primary).firstOrNull;
          if (bnd != null) {
            _landscapeTool.loadFromTerrainBoundary(
              bnd,
              state,
              datum: surf.datumElevation,
            );
          }
          final cnt = surf.contours.where((c) => c.id == primary).firstOrNull;
          if (cnt != null) {
            _landscapeTool.loadFromTerrainContour(
              cnt,
              state,
              datum: surf.datumElevation,
            );
          }
          final sp = surf.spots.where((s) => s.id == primary).firstOrNull;
          if (sp != null) {
            _landscapeTool.loadFromTerrainSpot(
              sp,
              state,
              datum: surf.datumElevation,
            );
          }
        }

      }

    });

    HapticFeedback.selectionClick();

    _selectPolygonContour(point);
    if (_selectedHatch != null && !_multiSelect) {
      setState(() {
        if (_polygonEditId != id && _selectedHatch != null) _polygonEdgeMode = ArchitectPolygonEdgeMode.pull;
            _polygonEditId = id;
        _polygonSelectedEdge = ArchitectPolygonDimensions.hitEdge(
          _selectedPolygon!, point, 18 / _currentScale,
        );
      });
    }
    return true;
  }
  void _operationError() => ScaffoldMessenger.of(context).showSnackBar(

    SnackBar(content: Text(context.l10n.architectOperationRejected)),

  );



  ArchitectStair _stairAt(Offset start, Offset end, {String id = 'preview'}) {
    return ArchitectStair.fromCorner(

      id: id,

      corner: start,

      directionPoint: end,

      width: _elementTool.stairWidth,

      design: ArchitectStairRules.resolveDesign(

        _project,

        _project.activeStorey,

        _elementTool.stairDesign,

      ),

    );

  }



  final _propertiesCanvasKey=GlobalKey();
  EdgeInsets _propertiesDrawingInsets=EdgeInsets.zero;
  void _insetProperties(EdgeInsets overlay){
    if(!mounted)return;
    final render=_propertiesCanvasKey.currentContext?.findRenderObject();
    var bottom=0.0;
    if(overlay.bottom>0 && render is RenderBox && render.hasSize){
      final canvasBottom=render.localToGlobal(Offset.zero).dy+render.size.height;
      final panelTop=MediaQuery.sizeOf(context).height-overlay.bottom;
      bottom=(canvasBottom-panelTop).clamp(0.0,math.max(0,render.size.height-80),
      );
    }
    final next=EdgeInsets.only(right:overlay.right,bottom:bottom);
    if(next!=_propertiesDrawingInsets)setState(()=>_propertiesDrawingInsets=next);
  }

  void _setPropertiesPreview(ArchitectProject? next) {
    if (identical(_commands.editPreview, next)) return;
    _commands.editPreview = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        _repaintPreview();
      }
    });
  }

  void _showSlabProperties(ArchitectSlab slab) {
    final original = _commands.documentProject,
        document = _modelCommands.project;
    showArchitectProperties<void>(
      context: context,
      onInsets: _insetProperties,
      builder: (_) => ArchitectSlabLayersDialog(
        project: original,
        slab: slab,
        isCurrent: () => identical(document, _modelCommands.project),
        onPreview: (next) {
          if (identical(document, _modelCommands.project)) {
            _setPropertiesPreview(_modelCommands.prepare(next));
          }
        },
        onApply: (next) {
          if (!identical(document, _modelCommands.project)) return false;
          _commands.editPreview = null;
          _commands.commit(next);
          _saveBiMProjectIfAttached();
          return true;
        },
      ),
    ).whenComplete(() => _setPropertiesPreview(null));
  }

  void _showStairProperties({ArchitectStair? stair, bool create = false}) {
    final defaults = stair == null;

    final initial = stair ?? _stairAt(Offset.zero, const Offset(1, 0));

    final document = _modelCommands.project;
    final original = _commands.documentProject;
    showArchitectProperties<void>(
      context: context,
      onInsets: _insetProperties,

      builder: (_) => ArchitectStairPropertiesDialog(
        isCurrent: () => identical(document, _modelCommands.project),
        project: original,
        onPreview: defaults
            ? null
            : (next) {
                if (identical(document, _modelCommands.project)) {
                  try {
                    _setPropertiesPreview(
                      _modelCommands.prepare(
                        PutArchitectStair(
                          storeyId: original.activeStoreyId,
                          stair: next,
                          create: create,
                        ).apply(original),
                      ),
                    );
                  } on ArgumentError {
                    /* Keep the last valid preview. */
                  }
                }
              },

        stair: initial,

        onApply: (next) {
          if (!identical(document, _modelCommands.project)) return false;
          _commands.editPreview = null;

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
    ).whenComplete(() => _setPropertiesPreview(null));
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
    final document = _modelCommands.project;
    final target =
        roof ??
        _selectedRoof ??
        (_selectedSectionRoofId == null
            ? null
            : ArchitectBuildingSection.findRoofById(
                _modelCommands.project,
                _selectedSectionRoofId!,
              )?.roof);
    await showArchitectProperties<void>(
      context: context,
      onInsets: _insetProperties,
      builder: (_) => ArchitectRoofLayersDialog(
        isCurrent: () => identical(document, _modelCommands.project),
        initialTab: initialTab,
        initialAssembly: target?.assembly ?? _roofTool.activeAssembly,
        initialSlopeDegrees: target?.slopeDegrees ?? _roofTool.slopeDegrees,
        initialEavesOverhang: target?.eavesOverhang ?? _roofTool.eavesOverhang,
        initialEavesCut: target?.eavesCut ?? _roofTool.eavesCut,
        initialDrainage: target?.drainage ?? _roofTool.drainage,
        initialParapet: target?.parapet ?? const ArchitectParapet(),
        initialBaseElevationOffset:
            target?.baseElevationOffset ??
            _roofTool.baseElevationOffset ??
            _project.activeStorey.height,
        initialAttachToWalls: target?.attachToWalls ?? _roofTool.attachToWalls,
        initialManualSupportDistance: target == null
            ? _roofTool.manualSupportDistance
            : target.manualSupportDistance,
        initialIsMansard:
            target?.isMansard ?? _roofTool.drawMode == RoofDrawMode.mansard,
        initialUpperSlopeDegrees:
            target?.upperSlopeDegrees ?? _roofTool.upperSlopeDegrees,
        initialBreakDistance: target == null
            ? _roofTool.breakDistance
            : target.breakDistance,
        maxSupportDistance: target?.maxSlopeRun,
        project: original,
        roof: target,
        canPickDownpipe: target != null,
        onPreview: target == null
            ? null
            : (result) {
                if (identical(document, _modelCommands.project) &&
                    _commands.isPlan) {
                  _setPropertiesPreview(
                    _modelCommands.prepare(
                      ApplyArchitectRoofSettings(
                        storeyId: target.storeyId,
                        roofId: target.id,
                        settings: result,
                      ).apply(document),
                    ),
                  );
                }
              },
        onTryApply: (result) {
          if (!identical(document, _modelCommands.project)) {
            _operationError();
            return false;
          }
          try {
            _commands.editPreview = null;
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
    _setPropertiesPreview(null);
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

    final route = ArchitectRoofDrainageGeometry.route(project, floor, next, pipe,
    );

    if (route.status != ArchitectDownpipeStatus.ready) {

      final l = context.l10n;

      final message = switch (route.status) {

        ArchitectDownpipeStatus.noFacade => l.architectDrainageNoFacade,

        ArchitectDownpipeStatus.outsideEaves => l.architectDrainageOutside,

        _ => l.architectDrainageBlocked,

      };

      ScaffoldMessenger.of(context,
      ).showSnackBar(SnackBar(content: Text(message)));

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
      _explicitSelectionOperation = false;
      _selectionOperation = ArchitectSelectionOperation.replace;
      });
      _saveBiMProjectIfAttached();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectRoofAutoCreated(generated.length),
          ),
        ),
      );
    } on ArgumentError {
      _operationError();
    }
  }

  Future<void> _deleteWallType(ArchitectWallType type) async {
    final l = context.l10n;
    final uses = _project.storeys.fold(
      0,
      (v, s) => v + s.walls.where((w) => w.wallTypeId == type.id).length,
    );
    if (uses > 0) {
      _showWallTypes();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => architectAlertDialog(
        title: Text(l.delete),
        content: Text(
          l.wallTypeDeleteConfirm(type.catalogLabel(l, _project.units)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        _modelCommands.commit(
          DeleteArchitectWallType(type.id).apply(_modelCommands.project),
        );
        _restoreWallType();
        _saveBiMProjectIfAttached();
        ScaffoldMessenger.of(context,
        ).showSnackBar(
          SnackBar(content: Text(l.wallTypeDeleted)));
      } on ArgumentError {
        _operationError();
      }
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

      system: wall.system,
      layers: wall.resolvedLayers,

      location: wall.isExterior

          ? ArchitectWallLocation.exterior

          : ArchitectWallLocation.interior,

      customHeight: wall.height,

      parapetFinish: wall.parapetFinish,
      railing: wall.railing,

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

                railingHeight: next.railing != null && next.customHeight != wall.height
                    ? next.customHeight : null,

              ),

            ]);

            _saveBiMProjectIfAttached();

            return true;

          } on ArchitectRailingOpeningsError {

            rethrow;

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
    final original = _commands.documentProject,
        document = _modelCommands.project;
    ArchitectProject candidate(Map<String, dynamic> values) =>
        original.updateActiveStorey(
          original.activeStorey.copyWith(
            components: [
              for (final item in original.activeStorey.components)
                item.id == component.id
                    ? item.copyWith(parameters: values)
                    : item,
            ],
          ),
        );
    final values = await ComponentDimensionsDialog.show(
      context,
      definition,
      component.parameters,
      onInsets: _insetProperties,
      isCurrent: () => identical(document, _modelCommands.project),
      onPreview: (values) {
        if (identical(document, _modelCommands.project)) {
          _setPropertiesPreview(candidate(values));
        }
      },
    );
    _setPropertiesPreview(null);
    if (!mounted ||
        values == null ||
        !identical(document, _modelCommands.project)) {
      return;
    }
    _commands.commit(candidate(values));
    _saveBiMProjectIfAttached();
  }

  void _showProperties() {
    _discardGeometryCommand();

    final ids = _effectiveSelection;

    if (ids.isEmpty) return;

    if (ids.length == 1) {
      final sec = _project.sections
          .where((s) => ids.contains(s.id))
          .firstOrNull;
      if (sec != null) {
        _showSectionElevationProperties(sec.id);
        return;
      }
      final elv = _project.elevations
          .where((e) => ids.contains(e.id))
          .firstOrNull;
      if (elv != null) {
        _showSectionElevationProperties(elv.id);
        return;
      }
      final component = _project.activeStorey.components
          .where((c) => ids.contains(c.id))
          .firstOrNull;

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

    if (ids.length == 1) {
      final slab = _project.activeStorey.slabs
          .where((s) => ids.contains(s.id))
          .firstOrNull;
      if (slab != null) {
        _showSlabProperties(slab);
        return;
      }
    }
    final original = _commands.documentProject;
    final document = _modelCommands.project;
    void preview(ArchitectProject? next) {
      _commands.editPreview = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          _repaintPreview();
        }
      });
    }

    showArchitectProperties<void>(
      context: context,
      onInsets: _insetProperties,
      builder: (_) => ArchitectElementPropertiesDialog(
        viewKey: _workspaceViewKey, drawingScale: _publicationScale,
        project: original,
        elementIds: ids,
        isCurrent: () => identical(document, _modelCommands.project),
        prepare: _commands.isPlan ? _modelCommands.prepare : null,
        onPreview: preview,
        onApplyProject: (next) {
          if (!identical(document, _modelCommands.project)) return false;
          _commands.editPreview = null;
          try {
            _commands.commit(next);
            _saveBiMProjectIfAttached();
            return true;
          } on ArgumentError {
            _operationError();
            return false;
          }
        },
        onApply: (_, _) => false,
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



  bool _stageWallAttach(Set<String> wallIds) {
    try {
      final source = _commands.documentProject;
      final command = _selectedLineIds.isNotEmpty
          ? _linearCommand(ConnectArchitectWallsAtVertex(storeyId: source.activeStoreyId,
              wallIds: wallIds, primaryWallId: _selectedElementId))
          : AttachArchitectWalls(storeyId: source.activeStoreyId, wallIds: wallIds);
      final candidate = command.apply(source);
      _beginGeometryCommand(ArchitectRadialAction.attach);
      return _captureGeometryPreview(candidate);
    } on ArgumentError {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.architectWallAttachIncompatible)));
      return false;
    }
  }

  void _triggerWallAttach() {
    final wallIds = _selectedLineIds.isNotEmpty ? _selectedLineIds : _selectedWallIds;
    if (wallIds.length >= 2) {
      _cancelActiveDrags();
      try {
        if (!_stageWallAttach(wallIds)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectWallAttachSuccess),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectWallAttachIncompatible),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (wallIds.length == 1) {
      final sourceId = wallIds.single;
      setState(() {
        _cancelActiveDrags();
        _wallAttachSourceId = sourceId;
        final wall = _linearEditWalls.where((w) => w.id == sourceId).firstOrNull;
        if (wall != null) {
          final center = wall.referencePointAt(.5);
          _wallAttachPointer = center + wall.normalVector * (wall.thickness + 0.6);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectWallAttachSelectSecond),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _triggerWallDetach() {
    final wallIds = _selectedWallIds;
    if (wallIds.isEmpty) return;
    setState(() {
      _cancelActiveDrags();
      _pendingDetachWallIds = Set.from(wallIds);
      _elementMoveOriginal = _project;
      _elementMovePreview = SetArchitectWallConnection(
        storeyId: _project.activeStoreyId,
        wallIds: wallIds,
        connected: false, temporary: true,
      ).apply(_project);
    });
    _repaintPreview();
  }

  void _confirmWallDetach() {
    final wallIds = _pendingDetachWallIds;
    if (wallIds == null) return;
    final original = _elementMoveOriginal ?? _commands.documentProject;
    final candidate = SetArchitectWallConnection(storeyId: original.activeStoreyId,
      wallIds: wallIds, connected: false, temporary: true).apply(original);
    _cancelActiveDrags();
    _discardGeometryCommand();
    _commands.commit(candidate);
    _saveBiMProjectIfAttached();
    _repaintPreview();
  }

  void _cancelWallDetach() {
    setState(() {
      _pendingDetachWallIds = null;
      _elementMoveOriginal = null;
      _elementMovePreview = null;
    });
    _repaintPreview();
  }

  // --- SUBSECTION: [TAG:FLOATING_HUD] Contextual Floating Command Overlays & Interactive Edge Curving ---

  Offset _clampOverlayPosition(Offset screenPos, {double width = 240, double height = 48}) {
    final media = MediaQuery.sizeOf(context);
    final left = (screenPos.dx + 12).clamp(8.0, math.max(8.0, media.width - width - 8.0));
    final top = (screenPos.dy - height - 12).clamp(8.0, math.max(8.0, media.height - height - 12.0));
    return Offset(left.toDouble(), top.toDouble());
  }

  int _findClosestSegmentIndex(List<Offset> pts, Offset target) {
    if (pts.length < 2) return 0;
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      final d = _pointToSegmentDistance(target, p1, p2);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-8) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  void _updateCurvingPreview() {
    if (_curvingEdgeElementId == null) return;
    final storey = _project.activeStorey;
    final wall = storey.walls.where((w) => w.id == _curvingEdgeElementId).firstOrNull;
    if (wall != null) {
      final previewWall = wall.copyWith(arcBulge: _curvingEdgeBulge);
      final nextWalls = storey.walls.map((w) => w.id == wall.id ? previewWall : w).toList();
      _elementMovePreview = _project.updateActiveStorey(storey.copyWith(walls: nextWalls));
      return;
    }
    final prim = storey.cadPrimitives.where((p) => p.id == _curvingEdgeElementId).firstOrNull;
    if (prim != null) {
      if (prim.type == CadPrimitiveType.line || prim.type == CadPrimitiveType.arc) {
        final previewPrim = prim.copyWith(
          type: _curvingEdgeBulge.abs() > 1e-6 ? CadPrimitiveType.arc : CadPrimitiveType.line,
          arcBulge: _curvingEdgeBulge,
        );
        final nextPrims = storey.cadPrimitives.map((p) => p.id == prim.id ? previewPrim : p).toList();
        _elementMovePreview = _project.updateActiveStorey(storey.copyWith(cadPrimitives: nextPrims));
      } else {
        final pts = prim.isPolygon ? prim.polygonCorners : prim.linePoints;
        final bulges = List<double>.from(prim.bulges ?? List.filled(pts.length, 0.0));
        final segIdx = _curvingEdgeSegmentIndex ?? 0;
        if (segIdx < bulges.length) {
          bulges[segIdx] = _curvingEdgeBulge;
          final previewPrim = prim.copyWith(bulges: bulges);
          final nextPrims = storey.cadPrimitives.map((p) => p.id == prim.id ? previewPrim : p).toList();
          _elementMovePreview = _project.updateActiveStorey(storey.copyWith(cadPrimitives: nextPrims));
        }
      }
      return;
    }
    final slab = storey.slabs.where((s) => s.id == _curvingEdgeElementId).firstOrNull;
    if (slab != null) {
      final bulges = List<double>.from(slab.bulges ?? List.filled(slab.polygon.length, 0.0));
      final segIdx = _curvingEdgeSegmentIndex ?? 0;
      if (segIdx < bulges.length) {
        bulges[segIdx] = _curvingEdgeBulge;
        final previewSlab = slab.copyWith(bulges: bulges);
        final nextSlabs = storey.slabs.map((s) => s.id == slab.id ? previewSlab : s).toList();
        _elementMovePreview = _project.updateActiveStorey(storey.copyWith(slabs: nextSlabs));
      }
      return;
    }
  }

  void _initCurvingEdgeSession({
    required String id,
    int? segmentIndex,
    required Offset p1,
    required Offset p2,
    required double bulge,
  }) {
    _cancelActiveDrags();
    final p1Screen = _viewport.toScreen(p1);
    final p2Screen = _viewport.toScreen(p2);
    final chordScreen = p2Screen - p1Screen;
    final chordScreenLen = chordScreen.distance;
    final tangentScreen = chordScreenLen > 1e-4
        ? chordScreen / chordScreenLen
        : const Offset(1, 0);
    var normalScreen = Offset(-tangentScreen.dy, tangentScreen.dx);
    final arc = ArchitectWallArc(p1, p2, bulge);
    final apexModel = bulge.abs() > 1e-4 ? arc.midpoint : (p1 + p2) / 2;
    final apexScreen = _viewport.toScreen(apexModel);
    final chordMidScreen = _viewport.toScreen((p1 + p2) / 2);

    if ((apexScreen - chordMidScreen).distance > 1e-4) {
      normalScreen = (apexScreen - chordMidScreen) / (apexScreen - chordMidScreen).distance;
    }

    final length = _handleOffsetLength > 0 ? _handleOffsetLength : 48.0;
    final safe = (Offset.zero & _viewport.size).deflate(32);
    if (!safe.contains(apexScreen + normalScreen * length) &&
        safe.contains(apexScreen - normalScreen * length)) {
      normalScreen = -normalScreen;
    }

    setState(() {
      _curvingEdgeElementId = id;
      _curvingEdgeSegmentIndex = segmentIndex;
      _curvingEdgeStartPoint = p1;
      _curvingEdgeEndPoint = p2;
      _curvingEdgeExactBulge = null;
      _curvingEdgeBulge = bulge;
      _curvingEdgeGripDirection = normalScreen;
      _curvingDragScreenOffset = Offset.zero;
      _isCurvingEdgeDragging = false;
      _curvingEdgeSnapped = false;
      _curvingEdgeSnapLabel = null;
      _curvingEdgePendingConfirmation = false;
    });
    _repaintPreview();
    unawaited(_showCurvingEdgeExactInputDialog());
  }

  void _startEdgeCurvingSession(String id, [int? segmentIndex]) {
    final storey = _project.activeStorey;
    final wall = storey.walls.where((w) => w.id == id).firstOrNull;
    if (wall != null) {
      _initCurvingEdgeSession(
        id: id,
        p1: wall.startPoint,
        p2: wall.endPoint,
        bulge: wall.arcBulge,
      );
      return;
    }
    final prim = storey.cadPrimitives.where((p) => p.id == id).firstOrNull;
    if (prim != null) {
      if (prim.type == CadPrimitiveType.line || prim.type == CadPrimitiveType.arc) {
        _initCurvingEdgeSession(
          id: id,
          p1: prim.startPoint,
          p2: prim.endPoint,
          bulge: prim.arcBulge ?? 0.0,
        );
        return;
      } else if (prim.type == CadPrimitiveType.polyline && prim.linePoints.length >= 2) {
        int segIdx = segmentIndex ?? _polygonSelectedEdge ?? 0;
        final pts = prim.linePoints;
        if (segmentIndex == null && _polygonSelectedEdge == null && _lastTapModelPosition != null) {
          segIdx = _findClosestSegmentIndex(pts, _lastTapModelPosition!);
        }
        segIdx = segIdx.clamp(0, pts.length - 2);
        final bulge = (prim.bulges != null && segIdx < prim.bulges!.length) ? prim.bulges![segIdx] : 0.0;
        _initCurvingEdgeSession(
          id: id,
          segmentIndex: segIdx,
          p1: pts[segIdx],
          p2: pts[segIdx + 1],
          bulge: bulge,
        );
        return;
      } else if ((prim.type == CadPrimitiveType.hatch || prim.isPolygon) && prim.polygonCorners.length >= 3) {
        final pts = prim.polygonCorners;
        int segIdx = segmentIndex ?? _polygonSelectedEdge ?? 0;
        if (segmentIndex == null && _polygonSelectedEdge == null && _lastTapModelPosition != null) {
          segIdx = _findClosestSegmentIndex(pts, _lastTapModelPosition!);
        }
        segIdx = segIdx.clamp(0, pts.length - 1);
        final bulge = (prim.bulges != null && segIdx < prim.bulges!.length) ? prim.bulges![segIdx] : 0.0;
        _initCurvingEdgeSession(
          id: id,
          segmentIndex: segIdx,
          p1: pts[segIdx],
          p2: pts[(segIdx + 1) % pts.length],
          bulge: bulge,
        );
        return;
      }
    }
    final slab = storey.slabs.where((s) => s.id == id).firstOrNull;
    if (slab != null && slab.polygon.length >= 3) {
      final pts = slab.polygon;
      int segIdx = segmentIndex ?? _polygonSelectedEdge ?? 0;
      if (segmentIndex == null && _polygonSelectedEdge == null && _lastTapModelPosition != null) {
        segIdx = _findClosestSegmentIndex(pts, _lastTapModelPosition!);
      }
      segIdx = segIdx.clamp(0, pts.length - 1);
      final bulge = (slab.bulges != null && segIdx < slab.bulges!.length) ? slab.bulges![segIdx] : 0.0;
      _initCurvingEdgeSession(
        id: id,
        segmentIndex: segIdx,
        p1: pts[segIdx],
        p2: pts[(segIdx + 1) % pts.length],
        bulge: bulge,
      );
      return;
    }
  }

  void _commitCurvingEdgeSession() {
    if (_curvingEdgeElementId == null) {
      _cancelCurvingEdgeSession();
      return;
    }
    final id = _curvingEdgeElementId!;
    final bulge = _curvingEdgeBulge;
    final storey = _project.activeStorey;
    final wall = storey.walls.where((w) => w.id == id).firstOrNull;
    if (wall != null) {
      _commands.execute(
        _linearCommand(
          UpdateArchitectWall(
            storeyId: storey.id,
            wall: wall.copyWith(arcBulge: bulge),
          ),
        ),
      );
    } else {
      final prim = storey.cadPrimitives.where((p) => p.id == id).firstOrNull;
      if (prim != null) {
        if (prim.type == CadPrimitiveType.line || prim.type == CadPrimitiveType.arc) {
          _commands.execute(
            _linearCommand(UpdateArchitectWall(
              storeyId: storey.id,
              wall: ArchitectLineEditing.segment(prim).copyWith(arcBulge: bulge),
              carryConnections: false,
            )),
          );
        } else if (prim.type == CadPrimitiveType.polyline) {
          final bulges = List<double>.from(prim.bulges ?? List.filled(prim.linePoints.length, 0.0));
          final segIdx = _curvingEdgeSegmentIndex ?? 0;
          if (segIdx < bulges.length) {
            bulges[segIdx] = bulge;
            _commands.execute(
              UpdateArchitectBulges(
                storeyId: storey.id,
                elementId: prim.id,
                bulges: bulges,
              ),
            );
          }
        } else if (prim.type == CadPrimitiveType.hatch || prim.isPolygon) {
          final pts = prim.polygonCorners;
          final bulges = List<double>.from(prim.bulges ?? List.filled(pts.length, 0.0));
          final segIdx = _curvingEdgeSegmentIndex ?? 0;
          if (segIdx < bulges.length) {
            bulges[segIdx] = bulge;
            _commands.execute(
              UpdateArchitectBulges(
                storeyId: storey.id,
                elementId: prim.id,
                bulges: bulges,
              ),
            );
          }
        }
      } else {
        final slab = storey.slabs.where((s) => s.id == id).firstOrNull;
        if (slab != null) {
          final bulges = List<double>.from(slab.bulges ?? List.filled(slab.polygon.length, 0.0));
          final segIdx = _curvingEdgeSegmentIndex ?? 0;
          if (segIdx < bulges.length) {
            bulges[segIdx] = bulge;
            _commands.execute(
              _linearCommand(
                UpdateArchitectBulges(
                  storeyId: storey.id,
                  elementId: id,
                  bulges: bulges,
                ),
              ),
            );
          }
        }
      }
    }
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    setState(() {
      _curvingEdgeElementId = null;
      _curvingEdgeSegmentIndex = null;
      _curvingEdgeStartPoint = null;
      _curvingEdgeEndPoint = null;
      _curvingEdgeBulge = 0.0;
      _curvingEdgeExactBulge = null;
      _isCurvingEdgeDragging = false;
      _curvingEdgeSnapped = false;
      _curvingEdgeSnapLabel = null;
      _curvingEdgePendingConfirmation = false;
      _curvingDragScreenOffset = Offset.zero;
      _elementMovePreview = null;
    });
    _repaintPreview();
  }

  void _cancelCurvingEdgeSession() {
    setState(() {
      _curvingEdgeElementId = null;
      _curvingEdgeSegmentIndex = null;
      _curvingEdgeStartPoint = null;
      _curvingEdgeEndPoint = null;
      _curvingEdgeBulge = 0.0;
      _curvingEdgeExactBulge = null;
      _isCurvingEdgeDragging = false;
      _curvingEdgeSnapped = false;
      _curvingEdgeSnapLabel = null;
      _curvingEdgePendingConfirmation = false;
      _curvingDragScreenOffset = Offset.zero;
      _elementMovePreview = null;
    });
    _repaintPreview();
  }

  // --- SUBSECTION: [TAG:CURVING_EXACT_INPUT] Existing element: exact h, side preview, final Apply/Cancel ---
  Future<void> _showCurvingEdgeExactInputDialog() async {
    if (_curvingEdgeEditorOpen ||
        _curvingEdgeElementId == null ||
        _curvingEdgeStartPoint == null ||
        _curvingEdgeEndPoint == null) return;
    final source = _project;
    final id = _curvingEdgeElementId!;
    final p1 = _curvingEdgeStartPoint!;
    final p2 = _curvingEdgeEndPoint!;
    final host = source.activeStorey.walls.where((w) => w.id == id).firstOrNull;
    final basis = host?.copyWith(arcBulge: _curvingEdgeBulge) ?? ArchitectWall(
      id: id, startPoint: p1, endPoint: p2,
      thickness: .001, arcBulge: _curvingEdgeBulge,
    );
    bool current() => mounted && identical(_project, source) &&
        _curvingEdgeElementId == id &&
        _curvingEdgeStartPoint == p1 && _curvingEdgeEndPoint == p2;
    _curvingEdgeEditorOpen = true;
    ArchitectWall? result;
    try {
      result = await showDialog<ArchitectWall>(
        context: context,
        builder: (_) => ArchitectWallArcDimensionDialog(
          project: source,
          wall: basis,
          dimension: ArchitectArcDimension.sagitta,
          confirmLabel: context.l10n.applyAction,
          onDimension: (_) {},
          validate: (candidate) {
            if (!current()) throw ArgumentError('Curving context changed');
            candidate.validateGeometry();
            ArchitectWallArcEditing.validateOpenings(candidate);
          },
          onPreview: (candidate) {
            if (!current()) return;
            setState(() {
              _curvingEdgeBulge = candidate.arcBulge;
              _updateCurvingPreview();
            });
            _repaintPreview();
          },
        ),
      );
    } finally {
      _curvingEdgeEditorOpen = false;
    }
    if (!current()) return;
    final accepted = result;
    if (accepted == null) {
      _cancelCurvingEdgeSession();
      return;
    }
    setState(() {
      _curvingEdgeBulge = accepted.arcBulge;
      _curvingEdgeExactBulge = accepted.arcBulge.abs();
      _curvingEdgePendingConfirmation = true;
      _updateCurvingPreview();
    });
    _repaintPreview();
  }

  // --- SUBSECTION: [TAG:CURVING_FEEDBACK] Compact neutral rise/snap feedback outside edited geometry ---
  Widget _buildCurvingEdgeFloatingOverlay() {
    if (_curvingEdgeElementId == null ||
        _curvingEdgeStartPoint == null ||
        _curvingEdgeEndPoint == null) {
      return const SizedBox.shrink();
    }
    final p1 = _curvingEdgeStartPoint!;
    final p2 = _curvingEdgeEndPoint!;
    final arc = ArchitectWallArc(p1, p2, _curvingEdgeBulge);
    final curved = _curvingEdgeBulge.abs() > 1e-4;
    final apex = curved ? arc.midpoint : (p1 + p2) / 2;
    final handle = _viewport.toScreen(apex);
    final obstacles = ArchitectClearanceObstacles.forWalls(
      _drawingProject.activeStorey.walls,
    );
    final snap = _curvingEdgeSnapped ? _curvingEdgeSnapLabel : null;
    final label = snap == 'Midpoint alignment'
        ? context.l10n.snapMidpoint
        : _localizedSnapLabel(snap);
    return ArchitectCurvingEdgeOverlay(
      p1: _viewport.toScreen(p1),
      p2: _viewport.toScreen(p2),
      chordMid: _viewport.toScreen((p1 + p2) / 2),
      handlePos: handle,
      gripPos: _curvingEdgeGripScreen ?? handle,
      isCurved: curved,
      curvePoints: curved
          ? arc.face(0, 0).map(_viewport.toScreen).toList()
          : [_viewport.toScreen(p1), _viewport.toScreen(p2)],
      distanceText: _project.formatLength(arc.sagitta),
      snapLabel: label,
      pendingConfirmation: _curvingEdgePendingConfirmation,
      intersectsDrawing: (rect) => obstacles.intersects(Rect.fromPoints(
        _viewport.toModel(rect.topLeft), _viewport.toModel(rect.bottomRight),
      )),
      onConfirm: _commitCurvingEdgeSession,
      onCancel: _cancelCurvingEdgeSession,
    );
  }

  Widget _buildDetachFloatingOverlay() {
    final l = context.l10n;
    final anchor = _selectedLinearElement?.referencePointAt(0.5) ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 210);
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: l.architectWallDetach,
      ready: true,
      onCancel: _cancelWallDetach,
      onConfirm: _confirmWallDetach,
    );
  }

  Widget _buildAttachFloatingOverlay() {
    final l = context.l10n;
    final anchor = _wallAttachPointer ??
        (_linearEditWalls.where((w) => w.id == _wallAttachSourceId).firstOrNull?.referencePointAt(0.5) ?? Offset.zero);
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 220);
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: l.architectWallAttachSelectSecond,
      showConfirm: false,
      onCancel: () {
        setState(() {
          _wallAttachSourceId = null;
          _wallAttachPointer = null;
        });
        _repaintPreview();
      },
    );
  }

  Widget _buildChamferFilletFloatingOverlay() {
    final options = _chamferFilletOptions!;
    final anchor = _chamferFilletPointer ?? _selectedLinearElement?.referencePointAt(.5) ?? Offset.zero;
    return ArchitectFloatingCommandOverlay(
      position: _clampOverlayPosition(_viewport.toScreen(anchor), width: 260),
      label: context.l10n.architectChamferFilletSelectSecond, showConfirm: false,
      onCancel: _cancelGeometryCommand,
      customContent: TextButton(
        key: const ValueKey('architect-corner-exact-value'),
        onPressed: () async {
          final result = await showArchitectChamferFilletDialog(context,
            unitToMeters: _project.units.scaleToMeters, unitSymbol: _project.units.symbol,
            decimals: _project.distanceDecimals, initialIsFillet: options.isFillet,
            initialValue: options.value,
            wallAxes: _selectedWallIds.isNotEmpty);
          if (result == null || !mounted || _chamferFilletSourceId == null) return;
          setState(() {
            _chamferFilletOptions = result;
            if (result.isFillet) { _lastFilletRadius = result.value; }
            else { _lastChamferDistance = result.value; }
          });
        },
        child: Text(_project.formatLength(options.value), style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildWallJoinFloatingOverlay() {
    final l = context.l10n;
    final anchor = _wallJoinPointer ??
        (_linearEditWalls.where((w) => w.id == _wallJoinSourceId).firstOrNull?.referencePointAt(0.5) ??
         _project.activeStorey.cadPrimitives.where((p) => p.id == _wallJoinSourceId).firstOrNull?.startPoint ??
         Offset.zero);
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 230);
    final label = _selectedLineIds.isNotEmpty
        ? l.architectLineJoinSelectSecond
        : l.architectWallJoinSelectSecond;
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: label,
      showConfirm: false,
      onCancel: () {
        setState(() {
          _wallJoinSourceId = null;
          _wallJoinPointer = null;
        });
        _repaintPreview();
      },
    );
  }

  // --- SUBSECTION: [TAG:DRAG_TOOL] ARCHITECT 2-POINT SNAP DRAG METHODS ---

  void _startDragSession() {
    // Free Move owns its preview/commit. Numeric and transverse moves keep
    // their separate generic geometry-command workflow.
    _discardGeometryCommand();
    _cancelActiveDrags();
    _resetWallDraft();
    _touchCandidates = null;
    _moveSelection = false;
    _transverseMove = false;
    assert(_commandPreview == null);

    final storeyId = _project.activeStorey.id;

    if (_isCadUnderlaySelected) {
      final cfg = _currentCadUnderlayConfig;
      final doc = _currentUnderlayDoc;
      final currentOrigin = cfg != null && cfg.hasLockedOrigin
          ? Offset(cfg.lockedCadOriginX!, cfg.lockedCadOriginY!)
          : _effectiveUnderlayFrame.origin;
      final defaultAnchor = doc != null
          ? _effectiveUnderlayFrame.toModel(doc.bounds.center)
          : currentOrigin;

      _dragController.startDrag(
        isUnderlay: true,
        isCadUnderlay: true,
        underlayName: cfg?.fileName ?? 'underlay.kcad',
        storeyId: storeyId,
        unitsPerMeter: cfg?.unitsPerMeter ?? 1.0,
        originalCadOrigin: currentOrigin,
        defaultAnchor: defaultAnchor,
        handleOffsetLength: _handleOffsetLength,
        zoomScale: _currentScale,
      );
      _dragTargetPlaced = false;
      setState(() {});
      return;
    }

    if (_selectedRasterId != null) {
      final raster = _selectedRasterUnderlay ??
          _project.rasterUnderlaysForStorey(storeyId).where((r) => r.id == _selectedRasterId).firstOrNull;
      if (raster != null && !raster.locked) {
        final defaultAnchor = raster.localBounds.center;
        _dragController.startDrag(
          isUnderlay: true,
          isCadUnderlay: false,
          rasterId: raster.id,
          underlayName: raster.fileName,
          storeyId: storeyId,
          unitsPerMeter: 1.0,
          originalRasterPosition: raster.position,
          defaultAnchor: defaultAnchor,
          handleOffsetLength: _handleOffsetLength,
          zoomScale: _currentScale,
        );
        _dragTargetPlaced = false;
        setState(() {});
        return;
      }
    }

    final ids = <String>{
      ..._effectiveSelection,
      if (_selectedElementId case final id?) id,
      if (_selectedZoneId case final id?) id,
    };

    if (ids.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.architectNavigationHint),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    Rect? overallBounds;
    for (final id in ids) {
      final b = ArchitectSelection.bounds(_project, id);
      if (b != null) {
        overallBounds = overallBounds == null ? b : overallBounds.expandToInclude(b);
      }
    }
    final defaultAnchor = overallBounds?.center;

    _dragController.startDrag(
      elementIds: ids,
      isUnderlay: false,
      storeyId: storeyId,
      defaultAnchor: defaultAnchor,
      handleOffsetLength: _handleOffsetLength,
      zoomScale: _currentScale,
    );
    _elementMoveOriginal = _project;
    _elementMovePreview = null;
    _elementMoveDelta = null;
    _dragTargetPlaced = false;
    setState(() {});
  }

  bool get _hasValidDragTarget =>
      _dragController.isDraggingToTarget &&
      _dragController.distanceMeters > 1e-7 &&
      (_dragController.isUnderlay || _elementMovePreview != null);

  /// Both picks use the drafting tools' lifted touch target. A grabbed leader
  /// retains its own offset so it can aim the base without moving the element.
  void _updateDragAim(Offset screenPosition) {
    if (_touchInput && _placingWithHold) _touchPosition = screenPosition;
    final aim = StructuralPointerInteraction.placementTarget(
      screenPosition,
      isMouse: !_touchInput || !_placingWithHold ||
          _dragPointerOffset != Offset.zero,
    );
    final raw = _screenToModel(aim);
    _lastTapModelPosition = raw;
    if (_dragController.isPickingBasePoint) {
      _dragController.updateBaseHover(
        raw + _dragPointerOffset,
        project: _project,
        scale: _currentScale,
        dxfDoc: _currentUnderlayDoc,
        frame: _effectiveUnderlayFrame,
        raster: _selectedRasterUnderlay,
        snapToDefaultGrip: false,
        relocateHandle: true,
        showHandle: !_touchInput || !_placingWithHold,
      );
    } else {
      _updateDragTarget(raw);
    }
    _cursorModel = _dragController.currentPointModel;
    _activeSnapLabel = _dragController.currentSnapLabel;
    _activeMagneticGuides = _dragController.magneticGuides;
    _repaintPreview();
  }

  void _updateDragTarget(Offset rawModel) {
    _dragController.updateTargetHover(
      rawModel + _dragPointerOffset, project: _project, scale: _currentScale,
      dxfDoc: _currentUnderlayDoc,
      frame: _effectiveUnderlayFrame,
      visibility: _effectiveUnderlayLayerVisibility,
    );
    _cursorModel = _dragController.currentPointModel;
    _activeSnapLabel = _dragController.currentSnapLabel;
    _activeMagneticGuides = _dragController.magneticGuides;
    if (_dragController.isUnderlay) return;
    _elementMovePreview = null;
    _elementMoveDelta = null;
    final source = _elementMoveOriginal;
    final delta = _dragController.deltaModel;
    if (source == null || delta == null || delta.distance <= 1e-7) return;
    try {
      _elementMovePreview = MoveArchitectElements(
        storeyId: _dragController.storeyId,
        elementIds: _dragController.elementIds,
        delta: delta,
      ).apply(source);
      _elementMoveDelta = delta;
    } on ArgumentError {
      // An invalid candidate must not leave an earlier valid preview applied.
    }
  }

  void _confirmDragPlacement() {
    if (!_dragTargetPlaced || !_hasValidDragTarget) return;
    assert(_commandPreview == null);
    final target = _dragController.currentPointModel;
    if (target == null) return;

    if (_dragController.isUnderlay) {
      final storeyId = _dragController.storeyId;
      if (_dragController.isCadUnderlay) {
        final cfg = _project.cadUnderlays[storeyId];
        if (cfg != null) {
          final placement = _dragController.computeCadPlacement(
            targetPointModel: target,
            existingMask: cfg.maskPolygon,
          );
          final updated = cfg.copyWith(
            lockedCadOriginX: placement.newOriginX,
            lockedCadOriginY: placement.newOriginY,
            maskPolygon: placement.translatedMask,
            lockOrigin: true,
          );
          final map = Map<String, ArchitectCadUnderlayConfig>.from(
            _project.cadUnderlays,
          )..[storeyId] = updated;

          _commands.commit(_project.copyWith(cadUnderlays: map));
          _saveBiMProjectIfAttached();
        }
      } else {
        final rasterId = _dragController.rasterId;
        final raster = _project.rasterUnderlays.where((r) => r.id == rasterId).firstOrNull;
        if (raster != null) {
          final placement = _dragController.computeRasterPlacement(
            targetPointModel: target,
            existingMask: raster.maskPolygon,
          );
          final updated = raster.copyWith(
            position: placement.newPosition,
            maskPolygon: placement.translatedMask,
          );
          final list = [
            for (final r in _project.rasterUnderlays)
              if (r.id == rasterId) updated else r,
          ];
          _commands.commit(_project.copyWith(rasterUnderlays: list));
          _saveBiMProjectIfAttached();
        }
      }
    } else {
      if (_elementMovePreview != null) {
        _commands.commit(_elementMovePreview!);
        _saveBiMProjectIfAttached();
      }
    }

    _cancelDragPlacement();
  }

  void _cancelDragPlacement() {
    _dragController.cancel();
    _elementMovePreview = null;
    _elementMoveOriginal = null;
    _elementMoveDelta = null;
    _dragTargetPlaced = false;
    _dragPointerOffset = Offset.zero;
    _placingWithHold = false;
    _touchPosition = null;
    _isHandleEngaged = false;
    _cursorModel = null;
    _activeSnapLabel = null;
    _activeMagneticGuides = const [];
    setState(() {});
    _repaintPreview();
  }

  Widget _buildDragFloatingOverlay() {
    final targetModel = _dragController.currentPointModel ??
        _dragController.defaultHandleAnchor ??
        _cursorModel ??
        Offset.zero;
    final screenPos = _viewport.toScreen(targetModel);
    final isPicking = _dragController.isPickingBasePoint;
    // Keep the pill below the target, clear of its snap and length badges,
    // and clamp against the canvas rather than the whole phone screen.
    final width = isPicking ? 76.0 : 132.0;
    final canvasSize = _viewport.size;
    const height = 60.0;
    final safe = (Offset.zero & canvasSize).deflate(8);
    final candidates = [
      screenPos + const Offset(24, 32),
      screenPos + const Offset(24, -height - 36),
      screenPos + Offset(-width - 24, 32),
      screenPos + Offset(-width - 24, -height - 36),
    ];
    final clamped = candidates.where((position) =>
      safe.contains(position) && safe.contains(position + Offset(width, height)),
    ).firstOrNull ?? Offset(
      (screenPos.dx + 24).clamp(8.0, math.max(8.0, canvasSize.width - width - 8)),
      (screenPos.dy + 32).clamp(8.0, math.max(8.0, canvasSize.height - height - 8)),
    );
    return ArchitectFloatingCommandOverlay(
      surfaceKey: const ValueKey('architect-drag-command-overlay'),
      position: clamped,
      label: '',
      ready: _dragTargetPlaced && _hasValidDragTarget,
      showConfirm: !isPicking,
      onCancel: _cancelDragPlacement,
      onConfirm: _confirmDragPlacement,
    );
  }

  Widget _buildCutFloatingOverlay() {
    final l = context.l10n;
    final anchor = _wallCutStart ?? _cursorModel ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 210);
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: l.architectWallCutHint,
      showConfirm: false,
      onCancel: _cancelCutSession,
    );
  }

  Widget _buildSplitFloatingOverlay() {
    final l = context.l10n;
    final anchor = _splitPoint1 ?? _cursorModel ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 280);
    final isPoint1Set = _splitPoint1 != null;
    final isWaitingSide = _splitWaitingForSide;
    final hint = !isPoint1Set
        ? l.architectWallSplitPromptPickFirst
        : (!isWaitingSide
            ? l.architectWallSplitPromptPickSecond
            : l.architectWallSplitPromptPickSide);

    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: hint,
      showConfirm: false,
      onCancel: _cancelSplitSession,
      customContent: (isPoint1Set && !isWaitingSide) || isWaitingSide
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPoint1Set && !isWaitingSide)
                  TextButton(
                    key: const ValueKey('architect-split-perpendicular-btn'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                if (isWaitingSide) ...[
                  TextButton(
                    key: const ValueKey('architect-split-side1-btn'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _commitSplitSide(-1),
                    child: Text(l.architectWallSplitSide1, style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    key: const ValueKey('architect-split-side2-btn'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _commitSplitSide(1),
                    child: Text(l.architectWallSplitSide2, style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    key: const ValueKey('architect-split-both-btn'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _commitSplitSide(0),
                    child: Text(l.architectWallSplitBoth, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ],
              ],
            )
          : null,
    );
  }

  Widget _buildNewPointFloatingOverlay() {
    final l = context.l10n;
    final anchor = _newPointCandidate ?? _cursorModel ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 200);
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: l.bimNewPoint,
      ready: _newPointValid,
      onCancel: _cancelNewPointSession,
      onConfirm: _commitNewPoint,
    );
  }

  Widget _buildMirrorFloatingOverlay() {
    final l = context.l10n;
    final anchor = _mirrorAnchor ?? _mirrorCurrentPoint ?? _cursorModel ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 280);
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: _mirrorReview ? '' : _mirrorAnchor == null
          ? l.architectMirrorPromptPickAnchor
          : l.architectMirrorPromptPickAxis,
      showConfirm: _mirrorReview,
      ready: _commandReady,
      onConfirm: _confirmMirror,
      onCancel: _commandPreview != null
          ? _cancelGeometryCommand
          : _cancelMirrorSession,
      customContent: _mirrorReview
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(key: const ValueKey('architect-mirror-keep-original'),
                value: _mirrorIsDuplicate,
                onChanged: (value) {
                  _mirrorIsDuplicate = value ?? false;
                  _executeMirror(anchor: _mirrorAnchor!, direction: _mirrorDirection!);
                }),
              Text(l.architectMirrorKeepOriginal, style: const TextStyle(color: Colors.white)),
            ])
          : _mirrorAnchor != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const ValueKey('architect-mirror-vertical-btn'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _executeMirror(anchor: _mirrorAnchor!, direction: const Offset(0, 1)),
                  child: Text(l.architectMirrorAxisVertical, style: const TextStyle(fontSize: 11, color: Color(0xFF00E5FF))),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('architect-mirror-horizontal-btn'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _executeMirror(anchor: _mirrorAnchor!, direction: const Offset(1, 0)),
                  child: Text(l.architectMirrorAxisHorizontal, style: const TextStyle(fontSize: 11, color: Color(0xFF00E5FF))),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildOffsetFloatingOverlay() {
    final l = context.l10n;
    final anchor = _offsetSide ?? _cursorModel ?? Offset.zero;
    final screenPos = _viewport.toScreen(anchor);
    final clamped = _clampOverlayPosition(screenPos, width: 220);
    final options = _offsetOptions;
    return ArchitectFloatingCommandOverlay(
      position: clamped,
      label: _offsetSide != null && !_offsetValid
          ? l.bimOffsetInvalid
          : (_offsetSide == null
              ? l.bimOffsetSide
              : l.architectOffsetDynamicDistance),
      ready: _offsetValid,
      onCancel: () {
        setState(() {
          _offsetOptions = null;
          _offsetSide = null;
          _elementMovePreview = null;
        });
        _repaintPreview();
      },
      onConfirm: () {
        if (_offsetSide != null) {
          _commitOffset(_offsetSide!);
        }
      },
      customContent: options != null
          ? GestureDetector(
              onTap: () async {
                final res = await showBimElementOffsetDialog(
                  context,
                  unitToMeters: _project.units.scaleToMeters,
                  unitSymbol: _project.units.symbol,
                  initialDistance: options.distance,
                  initialCopy: options.copy,
                  wallAxes: _offsetIds.isNotEmpty && _offsetIds.every((id) =>
                      _project.activeStorey.walls.any((w) => w.id == id)),
                );
                if (res != null && mounted) {
                  setState(() {
                    _offsetOptions = res;
                    if (_offsetSide != null) {
                      _previewOffset(_offsetSide!);
                    }
                  });
                  _repaintPreview();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyanAccent, width: 0.8),
                ),
                child: Text(
                  _project.formatLength(options.distance),
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _triggerWallJoin() {
    _beginGeometryCommand(ArchitectRadialAction.join);

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

        _transverseMove = false;

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



  // === SECTION: [SEC-09-SELECT] SELECTION ACTIONS, BARS & TOOLBARS ===
  // --- SUBSECTION: [TAG:SELECTION_BAR] Selection HUD, Action Bars & Layer Modals ---



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

              system: next.system,
              layers: next.resolvedLayers,

              location: next.isExterior

                  ? ArchitectWallLocation.exterior

                  : ArchitectWallLocation.interior,

              customHeight: next.height,

              parapetFinish: next.parapetFinish,
              railing: next.railing,

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




  void _commitMarquee({Offset? rectangleEnd}) {
    final polygon = _marqueeTool.finish(rectangleEnd: rectangleEnd);
    if (polygon.isEmpty) {
      if (_selectionBoxDragging) {
        setState(() { _selectionBoxDragging = false; _selectionBoxDown = null;
          _selectionBoxDownScreen = null; _marqueeTool.cancel(); });
        _repaintPreview();
      }
      return;
    }
    final result=ArchitectMarqueeTool.combine(Set<String>.of(_effectiveSelection),_marqueeHits(polygon),_activeSelectionOperation,
    );
    setState(() {
      _selectionIds..clear()..addAll(result);
      _selectionBoxDown = null;
      _selectionBoxDownScreen = null;
      _selectionBoxDragging = false;
      _marqueeTool.cancel();
      _selectedElementId = null;
      _selectedZoneId = null;
      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _polygonContourElementId = null;
      _polygonContourIndex = 0;
      _zoneTool.cancelAll();
      _axisTool.cancelAll();
      _axisTool.deselect();
      final ids = _effectiveSelection;
      if (ids.length == 1) {
        _selectedElementId = ids.single;
        final zone = _project.activeStorey.zones.where((z) => z.id == ids.single).firstOrNull;
        if (zone != null) {
          _selectedZoneId = zone.id;
          _zoneTool.startEditingZone(zone);
        }
        if (_selectedHatch != null) { _polygonEdgeMode = ArchitectPolygonEdgeMode.pull; _polygonEditId = ids.single; }
      }
      // Area selection remains in the explicitly chosen Multi mode.
      _selectionCyclePoint = null;
    });
    _repaintPreview();
    HapticFeedback.selectionClick();
  }

  Widget _buildSelectControl() => ValueListenableBuilder<int>(
    valueListenable:_previewRevision,
    builder:(context,revision,child) {
      final preview=_selectionPreview;
      return ArchitectSelectionControl(
        mode:_marqueeTool.mode,drafting:_marqueeTool.isDrafting,
        canFinish:_marqueeTool.finish().isNotEmpty,canUndo:_marqueeTool.points.isNotEmpty,
        count:_effectiveSelection.length,previewCount:preview.active?preview.result.length:null,
        operation:_explicitSelectionOperation?_selectionOperation:(_multiSelect?null:ArchitectSelectionOperation.replace),
        relation:_selectionRelation,onOperation:_setSelectionOperation,onRelation:_setSelectionRelation,
        onMode:(mode)=>setState(() { _cancelActiveDrags();_marqueeTool.setMode(mode); }),
        onFinish:()=>_commitMarquee(),
        onUndo:() { setState(()=>_marqueeTool.removeLastPoint());_repaintPreview(); },
        onCancel:() { setState(() { _cancelActiveDrags();_marqueeTool.cancel(); });_repaintPreview(); },
        onClear:() { _marqueeTool.cancel();_clearSelection(); },
      );
    },
  );

  Widget _buildWallSelectionActions(Set<String> wallIds) {
    if (_commandPreview != null || _dragController.isActive) return const SizedBox.shrink();

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

                  icon: const AppIcon(
                    AppIconId.flipHorizontal, color: Color(0xFF00E5FF),
                  ),

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
                        AppIcon.fromMaterial(

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

                        const AppIcon(
                          AppIconId.expandMore,

                          size: 16,

                          color: Color(0xFFFFB74D),

                        ),

                      ],

                    ),

                  ),

                  itemBuilder: (context) => [
                    PopupMenuItem<WallReferenceLine>(enabled: false,
                      child: StatefulBuilder(builder: (context, update) => CheckboxListTile(
                        key: const ValueKey('architect-reference-preserve-position'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.architectPreserveWallPosition),
                        value: _preserveWallPosition,
                        onChanged: (value) {
                          setState(() => _preserveWallPosition = value ?? true);
                          update(() {});
                        },
                      )),
                    ),


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
                            AppIcon.fromMaterial(

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

                  icon: AppIcon(
                    AppIconId.cut,

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

                  icon: AppIcon(
                    AppIconId.split,

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

                IconButton(
                  key: const ValueKey('architect-wall-attach'),
                  tooltip: l.architectWallAttach,
                  icon: AppIcon.fromMaterial(
                    Icons.join_inner,
                    color: _wallAttachSourceId != null
                        ? Colors.amber
                        : Colors.white,
                  ),
                  onPressed: () => _triggerWallAttach(),
                ),

                IconButton(
                  key: const ValueKey('architect-wall-detach'),
                  tooltip: l.architectWallDetachPrompt,
                  icon: AppIcon.fromMaterial(
                    Icons.link_off,
                    color: _pendingDetachWallIds != null
                        ? Colors.amber
                        : Colors.white,
                  ),
                  onPressed: () => _triggerWallDetach(),
                ),

                if (wallIds.length == 1) ...[

                  IconButton(
                    key: const ValueKey('architect-wall-curve'),
                    tooltip: l.architectWallCurveTooltip,
                    icon: const Icon(
                      Icons.rounded_corner,
                      color: Color(0xFF80CBC4),
                      size: 20,
                    ),
                    onPressed: () => _startEdgeCurvingSession(wallIds.single),
                  ),

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

                    icon: AppIcon(
                      AppIconId.fullscreen,

                      color: _wallExtendId == wallIds.single

                          ? Colors.amber

                          : Colors.white,

                    ),

                    onPressed: () {
                      _beginGeometryCommand(ArchitectRadialAction.edit);

                      _cancelActiveDrags();

                      setState(() {

                        _radialMenuScreenPosition = null;

                        _wallCutIds = {};

                        _wallCutStart = null;

                        _moveSelection = false;

                        _transverseMove = false;

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

                        icon: const AppIcon(
                          AppIconId.auto,

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
        preserveWallPosition: _preserveWallPosition,

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



    _beginGeometryCommand(ArchitectRadialAction.straighten);
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
    _discardGeometryCommand();

    if (_isZoneTableSelected) {
      _removeZoneScheduleTable();
    }

    final ids = _selectionIds.isNotEmpty ? Set<String>.of(_selectionIds) : _effectiveSelection;

    if (ids.isEmpty) {
      _clearSelection();
      return;
    }

    final hadWalls = _project.activeStorey.walls.any((w) => ids.contains(w.id));

    final storey = _elementTool.deleteElementsByIds(_project.activeStorey, ids);

    final nextStorey = storey.copyWith(
      zones: storey.zones.where((z) => !ids.contains(z.id)).toList(),
      components: storey.components.where((c) => !ids.contains(c.id)).toList(),
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
    setState(() {
      _radialMenuScreenPosition = null;
      _radialMenuElementId = null;
    });



    if (hadWalls) {

      _checkZoneMergeAfterWallDelete(nextProject.activeStorey);

    }

  }



  void _beginDuplicateSelection() {
    _beginGeometryCommand(ArchitectRadialAction.duplicate);

    if (_selectionHasAutoZones) return;

    _cancelActiveDrags();

    final ids = _effectiveSelection;

    if (ids.isEmpty) return;

    final copiedIds=<String,String>{};
    final (nextStorey, copyIds) = _elementTool.duplicateElementsByIds(

      _project.activeStorey,

      ids,

      offset: const Offset(0.5, 0.5),

      copyGroups: _editingGroupId == null,copiedIds:copiedIds,

    );

    if (copyIds.isEmpty) return;

    var updated = _project.updateActiveStorey(nextStorey).copyWith(document:_project.document.copyElementOverrides(copiedIds));

    if (_editingGroupId != null) {

      updated = AddArchitectGroupMembers(storeyId: _project.activeStoreyId,

        groupId: _editingGroupId!, elementIds: copyIds.toSet(),
      ).apply(updated);

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
    _beginGeometryCommand(ArchitectRadialAction.rotate);
    final ids = Set<String>.of(_effectiveSelection);
    if (!ArchitectRotation.supports(_project.activeStorey, ids)) return;
    final bounds = [for (final id in ids)
      if (ArchitectSelection.bounds(_project, id) case final Rect r) r,
    ];
    if (bounds.isEmpty) return;
    _cancelActiveDrags();
    setState(() {
      _rotationSource = _project;
      _rotationIds = ids;
      _rotationPivot = bounds.reduce((a, b) => a.expandToInclude(b)).center;
      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _moveSelection = false;
      _transverseMove = false;
    });
  }

  Widget _buildHatchTransformHandle() => Positioned.fill(
    child: AnimatedBuilder(
      animation: Listenable.merge([_viewport, _previewRevision]),
      builder: (_, _) {
        final ids = _effectiveSelection;
        if (_commandPreview != null || _is3DView || _printPreview || ids.length != 1 ||
            _multiSelect || _moveSelection || _mirrorActive || _splitActive ||
            _offsetOptions != null || _rotationSource != null ||
            _duplicateMove != null || _newPointTargetId != null ||
            _radialMenuScreenPosition != null || _marqueeTool.isDrafting || _polygonEditor.active ||
            _isDraggingVertexOrHandle) {
          return const SizedBox.shrink();
        }
        final hatch = _project.activeStorey.cadPrimitives.where((p) =>
          p.id == ids.single && p.type == CadPrimitiveType.hatch &&
          !p.hatchPattern.isSolid && p.hatchPattern.layers.isNotEmpty,
            ).firstOrNull;
        if (hatch == null) return const SizedBox.shrink();
        return ArchitectHatchTransformHandle(
          key: ValueKey((_project.activeStoreyId, hatch.id, _hatchTransformEpoch,
          )),
          hatch: hatch,
          toScreen: _viewport.toScreen,
          toModel: _screenToModel,
          onStart: () => _hatchTransformSource = _project,
          onPreview: (angle, scale) => _previewHatchTransform(hatch.id, angle, scale),
          onApply: (angle, scale) {
            final source = _hatchTransformSource;
            if (source == null || !identical(source, _project)) return;
            _previewHatchTransform(hatch.id, angle, scale);
            final next = _elementMovePreview;
            _hatchTransformSource = null;
            _elementMovePreview = null;
            if (next != null &&
                ((angle - hatch.hatchAngle).abs() > 1e-8 ||
                 (scale - hatch.hatchScale).abs() > 1e-8)) {
              _commands.commit(next);
              _saveBiMProjectIfAttached();
            }
            _repaintPreview();
          },
          onCancel: () {
            _hatchTransformSource = null;
            _elementMovePreview = null;
            _repaintPreview();
          },
        );
      },
    ),
  );

  void _previewHatchTransform(String id, double angle, double scale) {
    final source = _hatchTransformSource;
    if (source == null || !identical(source, _project)) return;
    _elementMovePreview = source.updateActiveStorey(
      source.activeStorey.copyWith(cadPrimitives: [
        for (final p in source.activeStorey.cadPrimitives)
          p.id == id ? p.copyWith(hatchAngle: angle, hatchScale: scale) : p,
      ],
      ),
    );
    _repaintPreview();
  }

  void _previewRotation(Offset pivot, double angle) {
    final source = _rotationSource;
    if (source == null) return;
    _elementMovePreview = source.updateActiveStorey(
      ArchitectRotation.apply(source.activeStorey, _rotationIds, pivot, angle),
    );
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
    _beginGeometryCommand(ArchitectRadialAction.offset);

    final ids = Set<String>.of(_effectiveSelection);

    if (!ArchitectOffset.supports(_project.activeStorey, ids)) return;

    _cancelActiveDrags();

    final source = _project;

    final epoch = _offsetEpoch;

    final options = await showBimElementOffsetDialog(context,

      unitToMeters: source.units.scaleToMeters, unitSymbol: source.units.symbol,
      wallAxes: ids.every((id) => source.activeStorey.walls.any((w) => w.id == id)),
    );

    if (!mounted) return;
    if (options == null) { _cancelGeometryCommand(); return; }
    if (epoch != _offsetEpoch || !identical(source, _project)) return;

    setState(() {

      _offsetOptions = options;

      _offsetSource = source;

      _offsetIds = ids;

      _offsetIdMap = options.copy

          ? {for (final id in ids) id: ArchitectElementId.next('offset')} : {};

      _offsetGroupIdMap = options.copy && _editingGroupId == null

          ? {for (final g in source.activeStorey.groups.where((g) => ids.containsAll(g.elementIds),
              ))

              g.id: ArchitectElementId.next('group'),
            } : {};

      _offsetSide = null;

      _offsetValid = false;
    _pendingDetachWallIds = null;
    _wallAttachSourceId = null;
    _wallAttachPointer = null;

      _polygonEditId = null;

      _polygonSelectedEdge = null;

      _moveSelection = false;

      _transverseMove = false;

      _zoneTool.cancelAll();

      _placingWithHold = false;

      _touchPosition = null;

    });

  }



  OffsetArchitectElements _offsetCommand(Offset side) => OffsetArchitectElements(

    storeyId: _offsetSource!.activeStoreyId, elementIds: _offsetIds,

    distance: _offsetOptions!.distance, side: side, idMap: _offsetIdMap,

    groupIdMap: _offsetGroupIdMap, editingGroupId: _editingGroupId,
      );



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
    _pendingDetachWallIds = null;
    _wallAttachSourceId = null;
    _wallAttachPointer = null;

    }

    if (wasValid != _offsetValid || !wasAiming) setState(() {});

    _repaintPreview();

  }



  void _commitOffset(Offset side) {

    _previewOffset(side);

    if (!_offsetValid || _elementMovePreview == null) {

      ScaffoldMessenger.of(context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.bimOffsetInvalid)));

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



  // --- SUBSECTION: [TAG:MIRROR_WORKFLOW] Mirror axis picking, preview and commit ---
  void _previewMirrorSnap(ArchitectSnapResult snap) {
    if (!_mirrorActive || _mirrorReview) return;
    _cursorModel = snap.point;
    _activeSnapLabel = snap.snapLabel;
    _activeMagneticGuides = snap.magneticGuides;
    _mirrorCurrentPoint = snap.point;
    final anchor = _mirrorAnchor;
    try {
      if (anchor != null) {
        final direction = snap.point - anchor;
        final source = _commandPreview?.original ?? _project;
        // Aiming must not stage the generic command: doing so changes _project
        // and reflects the previous preview again on the next pointer update.
        // The second axis pick stages the command through _executeMirror.
        _elementMovePreviewValue = direction.distanceSquared <= 1e-8
            ? null
            : _prepareGeometryPreview(
                MirrorArchitectElements(
                  storeyId: source.activeStoreyId,
                  elementIds: _mirrorSourceIds,
                  origin: anchor,
                  direction: direction,
                  isDuplicate: _mirrorIsDuplicate,
                  idMap: _mirrorIdMap,
                  copyGroups: _editingGroupId == null,
                ).apply(source),
              );
      }
    } on ArgumentError {
      _elementMovePreviewValue = null;
    }
    _repaintPreview();
  }

  void _pickMirrorSnap(ArchitectSnapResult snap) {
    if (_mirrorReview) return;
    if (_mirrorAnchor == null) {
      setState(() { _mirrorAnchor = snap.point; _mirrorCurrentPoint = null; });
      HapticFeedback.selectionClick();
    } else {
      _executeMirror(anchor: _mirrorAnchor!, direction: snap.point - _mirrorAnchor!,
      );
    }
    _repaintPreview();
  }

  void _startMirrorSession() {
    _beginGeometryCommand(ArchitectRadialAction.mirrorMove);

    if (_selectionHasAutoZones) return;

    if (_effectiveSelection.isEmpty) return;

    _cancelActiveDrags();

    setState(() {

      _polygonEditId = null;
      _polygonSelectedEdge = null;
      _moveSelection = false;
      _mirrorActive = true;

      _mirrorIsDuplicate = false;
      _mirrorReview = false;
      _mirrorDirection = null;

      _mirrorSourceIds = Set<String>.from(_effectiveSelection);

      _mirrorAnchor = null;

      _mirrorCurrentPoint = null;

      _mirrorIdMap = {for (final id in _effectiveSelection)
        id: ArchitectElementId.next('mirror')};

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
    final session = _commandPreview;
    if (session == null || direction.distanceSquared < 1e-12) return;
    try {
      final source = session.original;
      var candidate = MirrorArchitectElements(
        storeyId: source.activeStoreyId, elementIds: _mirrorSourceIds,
        origin: anchor, direction: direction, isDuplicate: _mirrorIsDuplicate,
        copyGroups: _editingGroupId == null, idMap: _mirrorIdMap,
      ).apply(source);
      if (_mirrorIsDuplicate && _editingGroupId != null) {
        candidate = AddArchitectGroupMembers(storeyId: source.activeStoreyId,
          groupId: _editingGroupId!, elementIds: _mirrorIdMap!.values.toSet()).apply(candidate);
      }
      _captureGeometryPreview(candidate);
      setState(() {
        _mirrorDirection = direction;
        _mirrorReview = true;
        _elementMovePreviewValue = null;
      });
      _repaintPreview();
    } on ArgumentError { _operationError(); }
  }

  void _confirmMirror() {
    final copies = _mirrorIsDuplicate ? _mirrorIdMap?.values.toSet() : null;
    if (!_commandReady) return;
    _confirmGeometryCommand();
    if (copies != null && _commandPreview == null) {
      final existing = ArchitectSelection.records(_commands.documentProject.toJson(),
        _commands.documentProject.activeStoreyId).map((e) => e['id'] as String).toSet();
      final selected = copies.intersection(existing);
      if (selected.isNotEmpty) setState(() {
        _selectionIds..clear()..addAll(selected);
        _selectedElementId = selected.first;
      });
    }
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
    _commands.commit(
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
    _commands.commit(
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
      onPreview: _setPropertiesPreview,
      onInsets: _insetProperties,
      project: _project,
      viewId: id,
      controller: _modelCommands,
      onOpenView: () => _openSectionOrElevationView(id),
    );
  }

  void _selectConnectedWalls() {
    if (!_multiSelect) return;

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
    final selected = Set<String>.of(_effectiveSelection);
    if (selected.isEmpty) return;
    final types = ArchitectSelectionCandidates.tools(_project);
    final kinds = selected.map((id) => types[id]).nonNulls.toSet();
    final group = _editingGroup;
    final targets = {
      for (final entry in types.entries)
        if (kinds.contains(entry.value) &&
            (group == null || group.elementIds.contains(entry.key)) &&
            (_showFurnitureLayer || entry.value != ArchitectTool.component)) entry.key,
    };
    if (targets.isEmpty) return;
    _changeTool(ArchitectTool.select, toggle: false);
    setState(() {
      _selectionIds..clear()..addAll(targets);
      _selectedElementId = selected.where(targets.contains).firstOrNull ?? targets.first;
      _multiSelect = true;
    });
    HapticFeedback.selectionClick();
  }

  void _openFindAndSelectDialog() {
    showArchitectFindAndSelectDialog(
      context: context,
      project: _modelCommands.project,
      selectedIds: _effectiveSelection,
      onSelect: (ids) {
        setState(() {
          _selectionIds..clear()..addAll(ids);
          _selectedElementId = ids.length == 1 ? ids.single : null;
          _multiSelect = ids.length > 1;
        });
      },
      onSwitchStorey: (storeyId) {
        _selectWorkspaceView(ArchitectWorkspaceView.plan, storeyId);
      },
      onApplyCommand: (command) {
        _commands.execute(command);
        _saveBiMProjectIfAttached();
        setState(() {});
      },
    );
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

                    icon: AppIcon(
                      AppIconId.measure,

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

                    icon: AppIcon(
                      AppIconId.alignLeft,

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

                    icon: const AppIcon(AppIconId.add, color: Colors.white70),

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

                  icon: const AppIcon(AppIconId.space, color: Colors.white70),

                  onPressed: _dimensionDraft == null

                      ? null

                      : _setDimensionDistance,

                ),

                IconButton(

                  key: const ValueKey('architect-dimension-place'),

                  tooltip: _dimensionEditing != null

                      ? l.architectDimensionConfirm

                      : l.architectDimensionPositionHint,

                  icon: AppIcon.fromMaterial(

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
    try {
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
    } on ArgumentError {
      _operationError();
    }
  }

  void _flipDoorsHinge(Set<String> doorIds) {
    if (doorIds.isEmpty) return;
    try {
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
    } on ArgumentError {
      _operationError();
    }
  }

  void _flipWindowsSide(Set<String> windowIds) {
    if (windowIds.isEmpty) return;
    try {
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
    } on ArgumentError {
      _operationError();
    }
  }

  // --- SUBSECTION: [TAG:FENESTRATION_SELECTION_UPDATES] Live Door & Window Parameter Mutators ---
  void _updateSelectedDoor({
    double? width,
    double? height,
    double? sill,
    bool? isHingeLeft,
    bool? hasCasing,
    String? styleId,
  }) {
    final id = _selectedElementId;
    if (id == null) return;
    final values = <String, double>{
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sill != null) 'sillHeight': sill,
    };
    final texts = <String, String>{
      if (isHingeLeft != null) 'isHingeLeft': '$isHingeLeft',
      if (hasCasing != null) 'hasCasing': '$hasCasing',
      if (styleId != null) 'styleId': styleId,
    };
    try {
      _commands.execute(
        SetArchitectElementProperties(
          storeyId: _project.activeStoreyId,
          elementIds: {id},
          values: values,
          textValues: texts,
        ),
      );
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      setState(() {});
    } on ArgumentError {
      _operationError();
    }
  }

  void _updateSelectedWindow({
    double? width,
    double? height,
    double? sill,
    bool? isFlipped,
    bool? hasCasing,
    String? styleId,
  }) {
    final id = _selectedElementId;
    if (id == null) return;
    final values = <String, double>{
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sill != null) 'sillHeight': sill,
    };
    final texts = <String, String>{
      if (isFlipped != null) 'isFlipped': '$isFlipped',
      if (hasCasing != null) 'hasCasing': '$hasCasing',
      if (styleId != null) 'styleId': styleId,
    };
    try {
      _commands.execute(
        SetArchitectElementProperties(
          storeyId: _project.activeStoreyId,
          elementIds: {id},
          values: values,
          textValues: texts,
        ),
      );
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
      setState(() {});
    } on ArgumentError {
      _operationError();
    }
  }

  void _performLinearSelectionAction(String action, Set<String> segmentIds) {
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
      _startMirrorSession();
    } else if (action == 'mirrorCopy') {
      _startMirrorSession();
    } else if (action == 'join') {
      _beginGeometryCommand(ArchitectRadialAction.join);
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

    } else if (action == 'point') {
      _startNewPointSession(segmentIds.single);
    }
  }

  int? _selectedVertexIndexFor(List<Offset> pts) {
    final ref = _cursorModel ?? _selectionCyclePoint;
    if (ref != null && pts.isNotEmpty) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      for (var i = 0; i < pts.length; i++) {
        final d = (pts[i] - ref).distance;
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      return bestIdx;
    }
    return null;
  }

  // --- SUBSECTION: [TAG:WALL_OPERATION_AXES] Core-axis corner edits and saved placement references ---
  void _triggerChamfer() => _startChamferFilletSession(isFillet: false);
  void _triggerFillet() => _startChamferFilletSession(isFillet: true);

  void _startChamferFilletSession({required bool isFillet}) {
    _cancelActiveDrags();
    _openChamferFilletDialog(isFillet: isFillet);
  }

  Future<void> _openChamferFilletDialog({required bool isFillet}) async {
    final ids = _effectiveSelection;
    final storey = _project.activeStorey;
    final canApplyToAll = _selectedPolygon != null ||
        storey.slabs.any((s) => ids.contains(s.id)) ||
        storey.cadPrimitives.any((p) => ids.contains(p.id) && (p.isPolygon || p.type == CadPrimitiveType.polyline));

    final options = await showArchitectChamferFilletDialog(
      context,
      unitToMeters: _project.units.scaleToMeters,
      unitSymbol: _project.units.symbol,
      initialIsFillet: isFillet,
      initialValue: isFillet ? (_lastFilletRadius ?? .50) : (_lastChamferDistance ?? .30),
      decimals: _project.distanceDecimals,
      canApplyToAll: canApplyToAll,
      wallAxes: ids.isNotEmpty &&
          ids.every((id) => storey.walls.any((w) => w.id == id)),
    );
    if (options == null || !mounted) return;
    if (options.isFillet) { _lastFilletRadius = options.value; }
    else { _lastChamferDistance = options.value; }
    _beginGeometryCommand(options.isFillet ? ArchitectRadialAction.fillet : ArchitectRadialAction.chamfer);

    if (ids.length == 1 &&
        (storey.walls.any((w) => w.id == ids.single) ||
         storey.cadPrimitives.any((p) => p.id == ids.single && p.type == CadPrimitiveType.line))) {
      setState(() {
        _chamferFilletSourceId = ids.single;
        _chamferFilletOptions = options;
      });
      return;
    }

    _applyChamferFillet(options);
  }

  void _applyChamferFillet(ArchitectChamferFilletOptions options) {
    final ids = _effectiveSelection;
    var storey = _project.activeStorey;
    var changed = false;

    final updatedSlabs = storey.slabs.map((slab) {
      if (!ids.contains(slab.id)) return slab;
      final newPolygon = options.isFillet
          ? ArchitectChamferFillet.polygonFillet(
              slab.polygon,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(slab.polygon),
              radius: options.value,
            )
          : ArchitectChamferFillet.polygonChamfer(
              slab.polygon,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(slab.polygon),
              distance: options.value,
            );
      if (newPolygon.length >= 3) {
        changed = true;
        return slab.copyWith(polygon: newPolygon);
      }
      return slab;
    }).toList();
    storey = storey.copyWith(slabs: updatedSlabs);

    final updatedPrimitives = storey.cadPrimitives.map<ArchitectCadPrimitive>((prim) {
      if (!ids.contains(prim.id)) return prim;
      if (prim.type == CadPrimitiveType.polyline || prim.isPolygon) {
        final pts = prim.isPolygon ? prim.polygonCorners : prim.linePoints;
        final isClosed = prim.isPolygon || prim.isClosedPolyline;
        final newPts = options.isFillet
            ? ArchitectChamferFillet.polygonFillet(
                pts,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(pts),
                radius: options.value,
                isClosed: isClosed,
              )
            : ArchitectChamferFillet.polygonChamfer(
                pts,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(pts),
                distance: options.value,
                isClosed: isClosed,
              );
        if (newPts.length >= 2) {
          changed = true;
          return prim.copyWith(
            polygon: newPts,
            startPoint: newPts.first,
            endPoint: newPts.last,
          );
        }
      }
      return prim;
    }).toList();
    storey = storey.copyWith(cadPrimitives: updatedPrimitives);

    final updatedPathways = storey.pathways.map((p) {
      if (!ids.contains(p.id)) return p;
      final newPts = options.isFillet
          ? ArchitectChamferFillet.polygonFillet(
              p.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(p.points),
              radius: options.value,
              isClosed: p.closed,
            )
          : ArchitectChamferFillet.polygonChamfer(
              p.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(p.points),
              distance: options.value,
              isClosed: p.closed,
            );
      if (newPts.length >= 2) {
        changed = true;
        return p.copyWith(points: newPts);
      }
      return p;
    }).toList();
    storey = storey.copyWith(pathways: updatedPathways);

    final updatedFences = storey.siteFences.map((f) {
      if (!ids.contains(f.id)) return f;
      final newPts = options.isFillet
          ? ArchitectChamferFillet.polygonFillet(
              f.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(f.points),
              radius: options.value,
              isClosed: f.closed,
            )
          : ArchitectChamferFillet.polygonChamfer(
              f.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(f.points),
              distance: options.value,
              isClosed: f.closed,
            );
      if (newPts.length >= 2) {
        changed = true;
        return f.copyWith(points: newPts);
      }
      return f;
    }).toList();
    storey = storey.copyWith(siteFences: updatedFences);

    final updatedStreets = storey.streets.map((s) {
      if (!ids.contains(s.id)) return s;
      final newPts = options.isFillet
          ? ArchitectChamferFillet.polygonFillet(
              s.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(s.points),
              radius: options.value,
              isClosed: s.closed,
            )
          : ArchitectChamferFillet.polygonChamfer(
              s.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(s.points),
              distance: options.value,
              isClosed: s.closed,
            );
      if (newPts.length >= 2) {
        changed = true;
        return s.copyWith(points: newPts);
      }
      return s;
    }).toList();
    storey = storey.copyWith(streets: updatedStreets);

    final updatedVeg = storey.vegetation.map((v) {
      if (!ids.contains(v.id) || !v.isHedge) return v;
      final newPts = options.isFillet
          ? ArchitectChamferFillet.polygonFillet(
              v.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(v.points),
              radius: options.value,
              isClosed: false,
            )
          : ArchitectChamferFillet.polygonChamfer(
              v.points,
              vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(v.points),
              distance: options.value,
              isClosed: false,
            );
      if (newPts.length >= 2) {
        changed = true;
        return v.copyWith(points: newPts, position: newPts.first);
      }
      return v;
    }).toList();
    storey = storey.copyWith(vegetation: updatedVeg);

    var proj = _project;
    for (final (surf, isProposed) in [
      (proj.proposedTerrain, true),
      (proj.existingTerrain, false),
    ]) {
      var surfChanged = false;
      final nextBnd = surf.boundaries.map((b) {
        if (!ids.contains(b.id)) return b;
        final newPoly = options.isFillet
            ? ArchitectChamferFillet.polygonFillet(
                b.polygon,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(b.polygon),
                radius: options.value,
                isClosed: true,
              )
            : ArchitectChamferFillet.polygonChamfer(
                b.polygon,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(b.polygon),
                distance: options.value,
                isClosed: true,
              );
        if (newPoly.length >= 3) {
          surfChanged = true;
          changed = true;
          return b.copyWith(polygon: newPoly);
        }
        return b;
      }).toList();

      final nextCnt = surf.contours.map((c) {
        if (!ids.contains(c.id)) return c;
        final newPts = options.isFillet
            ? ArchitectChamferFillet.polygonFillet(
                c.points,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(c.points),
                radius: options.value,
                isClosed: c.closed,
              )
            : ArchitectChamferFillet.polygonChamfer(
                c.points,
                vertexIndex: options.applyToAll ? null : _selectedVertexIndexFor(c.points),
                distance: options.value,
                isClosed: c.closed,
              );
        if (newPts.length >= 2) {
          surfChanged = true;
          changed = true;
          return c.copyWith(points: newPts);
        }
        return c;
      }).toList();

      if (surfChanged) {
        final nextSurface = surf.copyWith(boundaries: nextBnd, contours: nextCnt);
        proj = isProposed
            ? proj.copyWith(proposedTerrain: nextSurface)
            : proj.copyWith(existingTerrain: nextSurface);
      }
    }

    final selectedWalls = storey.walls.where((w) => ids.contains(w.id)).toList();
    if (selectedWalls.length == 2) {
      final wA = selectedWalls[0];
      final wB = selectedWalls[1];
      final res = options.isFillet
          ? ArchitectChamferFillet.wallPairFillet(wA, wB, radius: options.value)
          : ArchitectChamferFillet.wallPairChamfer(wA, wB, distance: options.value);
      if (res != null) {
        final nextWalls = storey.walls.map((w) {
          if (w.id == wA.id) return res.wallA;
          if (w.id == wB.id) return res.wallB;
          return w;
        }).toList()..add(res.connector);
        storey = storey.copyWith(walls: nextWalls);
        changed = true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.architectChamferFilletInvalid),
        ));
        return;
      }
    }

    final selectedLines = storey.cadPrimitives
        .where((p) => ids.contains(p.id) && p.type == CadPrimitiveType.line)
        .toList();
    if (selectedLines.length == 2) {
      final lA = selectedLines[0];
      final lB = selectedLines[1];
      final res = options.isFillet
          ? ArchitectChamferFillet.linePairFillet(lA, lB, radius: options.value)
          : ArchitectChamferFillet.linePairChamfer(lA, lB, distance: options.value);
      if (res != null) {
        final nextPrimitives = storey.cadPrimitives.map((p) {
          if (p.id == lA.id) return res.lineA;
          if (p.id == lB.id) return res.lineB;
          return p;
        }).toList()..add(res.connector);
        storey = storey.copyWith(cadPrimitives: nextPrimitives);
        changed = true;
      }
    }

    if (changed) {
      _commands.commit(proj.updateActiveStorey(storey));
      if (!_commandReady) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.architectChamferFilletInvalid)));
      }
      _saveBiMProjectIfAttached();
      setState(() {});
    }
  }

  Future<void> _triggerChangeLayer() async {
    final ids = _effectiveSelection;
    if (ids.isEmpty) return;
    final firstId = ids.first;
    final currentLayerId = _project.elementLayerId(firstId, ArchitectLayer.wallLayerId);

    final selectedLayerId = await showArchitectElementLayerPicker(
      context,
      project: _project,
      currentLayerId: currentLayerId,
    );
    if (selectedLayerId == null || selectedLayerId == currentLayerId) return;

    final updatedElementLayers = Map<String, String>.from(_project.elementLayers);
    for (final id in ids) {
      updatedElementLayers[id] = selectedLayerId;
    }
    _commands.commit(
      _project.copyWith(elementLayers: updatedElementLayers),
    );
    _saveBiMProjectIfAttached();
    setState(() {});
  }

  void _openLayersDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ArchitectLayersDialog(
        project: _project,
        onToggleVisibility: (layer) {
          final updated = _project.effectiveLayers.map((l) {
            if (l.id == layer.id) {
              return l.copyWith(visible: !l.visible);
            }
            return l;
          }).toList();
          setState(() {
            _project = _project.copyWith(layers: updated);
          });
          _saveBiMProjectIfAttached();
        },
        onCreateLayer: (name, colorValue) {
          final id = 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}';
          final newLayer = ArchitectLayer(
            id: id,
            name: name,
            isStandard: false,
            visible: true,
            colorValue: colorValue,
          );
          setState(() {
            _project = _project.copyWith(
              layers: [..._project.effectiveLayers, newLayer],
            );
          });
          _saveBiMProjectIfAttached();
        },
        onDeleteLayer: (layer) {
          if (layer.isStandard) return;
          final updatedLayers = _project.effectiveLayers
              .where((l) => l.id != layer.id)
              .toList();
          final updatedElementLayers = Map<String, String>.from(_project.elementLayers);
          updatedElementLayers.removeWhere((_, lId) => lId == layer.id);
          setState(() {
            _project = _project.copyWith(
              layers: updatedLayers,
              elementLayers: updatedElementLayers,
            );
          });
          _saveBiMProjectIfAttached();
        },
        onShowAll: () {
          final updated = _project.effectiveLayers
              .map((l) => l.copyWith(visible: true))
              .toList();
          setState(() {
            _project = _project.copyWith(layers: updated);
          });
          _saveBiMProjectIfAttached();
        },
      ),
    );
  }

  Widget _buildSelectionBar({bool menuOnly = false}) {
    if (_commandReady ||
        (_commandPreview != null &&
            _commandAction != ArchitectRadialAction.move)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final ids = _effectiveSelection;
    final wallIds = _selectedWallIds;
    final lineIds = _selectedLineIds;
    final segmentIds = lineIds.isNotEmpty ? lineIds : wallIds;
    final storey = _project.activeStorey;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final foreground = compact
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white70;
    final accent = compact
        ? Theme.of(context).colorScheme.primary
        : Colors.cyanAccent;
    final danger = compact
        ? Theme.of(context).colorScheme.error
        : Colors.redAccent;
    Widget icon(IconData data, [Color? color]) =>
        AppIcons.isRegistered(data)
            ? AppIcon.fromMaterial(data, color: color ?? foreground, size: 20)
            : Icon(data, color: color ?? foreground, size: 20);
    ArchitectSelectionAction action(
      String id,
      String label,
      IconData symbol,
      VoidCallback callback, {
      bool primary = false,
      Color? color,
      String? commandId,
      Widget? graphic,
      String? tooltip,
      double desktopWidth = 26,
    }) => ArchitectSelectionAction(
      id: id,
      label: label,
      icon: graphic ?? icon(symbol, color),
      tooltip: tooltip,
      onPressed: callback,
      primary: primary,
      commandId: commandId,
      desktopWidth: desktopWidth,
    );
    ArchitectSelectionAction linear(
      String id,
      String label,
      IconData symbol,
      String command, {
      String? commandId,
    }) => action(
      id,
      label,
      symbol,
      () => _performLinearSelectionAction(command, segmentIds),
      commandId: commandId,
    );

    if (ids.isEmpty && (_isCadUnderlaySelected || _selectedRasterId != null)) {
      final isCad = _isCadUnderlaySelected;
      final raster = _selectedRasterUnderlay;
      return ArchitectSelectionActionBar(
        actions: [
          action(
            'underlay-position',
            l.architectUnderlayPositionAction,
            Icons.open_with,
            () => _startUnderlaySnapDrag(isCad: isCad, rasterId: raster?.id),
            primary: true,
            color: const Color(0xFF00E5FF),
            tooltip: l.architectUnderlayPositionTooltip,
          ),
          action(
            'underlay-hide',
            l.architectUnderlayHide,
            Icons.visibility_off_outlined,
            () => isCad
                ? _toggleCadVisibility(false)
                : (raster != null ? _toggleRasterVisibility(raster.id, false) : null),
            color: Colors.white70,
            tooltip: l.architectUnderlayHideTooltip,
          ),
          action(
            'underlay-scale',
            l.architectUnderlayScale,
            Icons.straighten,
            isCad ? _openCadScaleDialog : _openRasterScaleDialog,
            color: const Color(0xFF4FC3F7),
          ),
          action(
            'underlay-mask',
            l.architectUnderlayMask,
            Icons.crop,
            () => isCad ? _openCadMaskMenu(Offset.zero) : _openRasterMaskMenu(Offset.zero),
            color: const Color(0xFF00E5FF),
          ),
          action(
            'underlay-properties',
            l.architectUnderlayEdit,
            Icons.tune,
            isCad ? _openCadEditDialog : _openRasterEditDialog,
            color: const Color(0xFFB388FF),
          ),
          action(
            'underlay-delete',
            l.delete,
            Icons.delete_outline,
            isCad ? _removeCurrentCadUnderlay : _deleteSelectedRaster,
            color: danger,
          ),
          action(
            'architect-clear-selection',
            l.architectSelectionClear,
            Icons.close,
            _clearSelection,
            primary: true,
          ),
        ],
        count: 1,
        menuOnly: menuOnly,
        showClear: true,
        showCount: false,
        onAction: _dismissTouchCandidates,
      );
    }

    if (ids.isEmpty && _isZoneTableSelected) {
      return ArchitectSelectionActionBar(
        actions: [
          action(
            'architect-selection-delete',
            l.delete,
            Icons.delete_outline,
            _deleteSelection,
            primary: true,
            color: danger,
          ),
          action(
            'architect-clear-selection',
            l.architectSelectionClear,
            Icons.close,
            _clearSelection,
            primary: true,
          ),
        ],
        count: 1,
        menuOnly: menuOnly,
        showClear: true,
        showCount: false,
        onAction: _dismissTouchCandidates,
      );
    }

    final doors = storey.walls
        .expand((w) => w.doors)
        .where((d) => ids.contains(d.id))
        .toList();
    final windows = storey.walls
        .expand((w) => w.windows)
        .where((w) => ids.contains(w.id))
        .toList();
    final onlyDoors = doors.isNotEmpty && doors.length == ids.length;
    final onlyWindows = windows.isNotEmpty && windows.length == ids.length;
    final generic = !onlyDoors && !onlyWindows;
    final dimension = ids.length == 1
        ? storey.dimensions.where((d) => ids.contains(d.id)).firstOrNull
        : null;
    final section = ids.length == 1
        ? _project.sections.where((s) => ids.contains(s.id)).firstOrNull
        : null;
    final elevation = ids.length == 1
        ? _project.elevations.where((e) => ids.contains(e.id)).firstOrNull
        : null;
    final supportsTransverse =
        generic &&
        ids.length == 1 &&
        segmentIds.length == 1 &&
        _selectedLinearElement?.isCurved == false;
    final actions = <ArchitectSelectionAction>[];
    final path=_selectedPolyline;
    if(path!=null) {
      actions.add(action('architect-polyline-toggle',path.isClosedPolyline?l.architectPolylineOpen:l.architectPolylineClose,Icons.polyline,(){
        try {
          _commands.execute(UpdateArchitectPolyline(storeyId:_project.activeStoreyId,elementId:path.id,points:path.linePoints,closed:!path.isClosedPolyline));
          _saveBiMProjectIfAttached();setState((){});
        } on ArgumentError {_operationError();}
      }));
      if(!path.isClosedPolyline)actions.add(action('architect-polyline-edge',l.architectPolylineEdge,Icons.straighten,()=>_editPolylineSegment(path)));
    }


    if (onlyDoors) {
      final doorIds = doors.map((d) => d.id).toSet();
      actions.addAll([
        action(
          'architect-door-flip-swing',
          l.architectDoorFlipSwing,
          Icons.swap_vert,
          () => _flipDoorsSwing(doorIds),
          color: accent,
          desktopWidth: 32,
        ),
        action(
          'architect-door-flip-hinge',
          l.architectDoorFlipHinge,
          Icons.swap_horiz,
          () => _flipDoorsHinge(doorIds),
          color: accent,
          desktopWidth: 32,
        ),
        action(
          'architect-find-and-select',
          l.architectFindAndSelect,
          Icons.filter_alt_outlined,
          _openFindAndSelectDialog,
          color: accent,
          desktopWidth: 32,
        ),
      ]);
    } else if (onlyWindows) {
      actions.addAll([
        action(
          'architect-window-flip-side',
          l.architectWindowFlipSide,
          Icons.flip,
          () => _flipWindowsSide(windows.map((w) => w.id).toSet()),
          color: accent,
          desktopWidth: 32,
        ),
        action(
          'architect-find-and-select',
          l.architectFindAndSelect,
          Icons.filter_alt_outlined,
          _openFindAndSelectDialog,
          color: accent,
          desktopWidth: 32,
        ),
      ]);
    } else {
      if (section != null) {
        actions.addAll([
          action(
            'architect-section-open-view',
            l.architectOpenView,
            Icons.visibility_outlined,
            () => _openSectionOrElevationView(section.id),
            color: accent,
          ),
          action(
            'architect-section-flip',
            l.architectRadialFlip,
            Icons.flip,
            () => _flipSection(section.id),
          ),
          action(
            'architect-section-properties',
            l.architectProperties,
            Icons.tune,
            () => _showSectionElevationProperties(section.id),
          ),
        ]);
      }
      if (elevation != null) {
        actions.addAll([
          action(
            'architect-elevation-open-view',
            l.architectOpenView,
            Icons.visibility_outlined,
            () => _openSectionOrElevationView(elevation.id),
            color: accent,
          ),
          action(
            'architect-elevation-flip',
            l.architectRadialFlip,
            Icons.flip,
            () => _flipElevation(elevation.id),
          ),
          action(
            'architect-elevation-properties',
            l.architectProperties,
            Icons.tune,
            () => _showSectionElevationProperties(elevation.id),
          ),
        ]);
      }
      if (dimension != null) {
        actions.addAll([
          action(
            'architect-dimension-new-point',
            l.architectDimensionNewPoint,
            Icons.add_location_alt_outlined,
            () {
              _addWallsToDimension(dimension);
              setState(() {
                _dimensionAllowPoint = true;
                _dimensionPlacing = false;
              });
            },
            color: accent,
            graphic: BimEditingSymbol(
              BimEditAction.newPoint,
              color: accent,
              size: 18,
            ),
          ),
          action(
            'architect-dimension-add-walls',
            l.architectDimensionEditPoints,
            Icons.edit_location_alt_outlined,
            () => _addWallsToDimension(dimension),
          ),
        ]);
      }
      if (_multiSelect && segmentIds.isNotEmpty) {
        actions.add(
          action(
            'architect-select-connected',
            l.architectSelectConnected,
            Icons.hub_outlined,
            _selectConnectedWalls,
            color: accent,
          ),
        );
      }
      if (wallIds.length == 1) {
        final wall = storey.walls
            .where((w) => wallIds.contains(w.id))
            .firstOrNull;
        final overshoot = wall == null
            ? null
            : ArchitectWallOvershootDetector.detectForWall(
                wall,
                storey.walls,
              ).firstOrNull;
        if (overshoot != null) {
          actions.add(
            action(
              'architect-selection-trim-overshoot',
              l.architectWallOvershootTooltip,
              Icons.auto_fix_high_rounded,
              () => _handleTrimOvershoot(overshoot),
              color: accent,
            ),
          );
        }
      }
      if (_multiSelect) {
        actions.add(
          action(
            'architect-select-similar',
            l.architectSelectSimilar,
            Icons.select_all_rounded,
            _selectSimilarElements,
            color: accent,
            tooltip: l.architectSelectSimilarHelp,
          ),
        );
      }
      actions.add(
        action(
          'architect-find-and-select',
          l.architectFindAndSelect,
          Icons.filter_alt_outlined,
          _openFindAndSelectDialog,
          color: accent,
          tooltip: l.architectFindAndSelectHelp,
        ),
      );
    }

    if (!generic || !_selectionHasAutoZones) {
      actions.add(
        ArchitectSelectionAction(
          id: 'architect-selection-move',
          label: l.architectSelectionMove,
          icon: icon(Icons.open_with, _moveSelection ? Colors.amber : null),
          primary: true,
          onPressed: () => _setSelectionMove(
            _moveSelection
                ? ArchitectSelectionMoveAction.stop
                : ArchitectSelectionMoveAction.free,
          ),
          button: ArchitectSelectionMoveButton(
            active: _moveSelection,
            transverse: _transverseMove,
            supportsTransverse: supportsTransverse,
            onSelected: _setSelectionMove,
          ),
          children: supportsTransverse
              ? [
                  action(
                    'architect-move-free',
                    l.architectMoveFree,
                    Icons.open_with,
                    () => _setSelectionMove(ArchitectSelectionMoveAction.free),
                  ),
                  action(
                    'architect-move-transverse',
                    l.architectMoveTransverse,
                    Icons.swap_vert,
                    () => _setSelectionMove(
                      ArchitectSelectionMoveAction.transverse,
                    ),
                  ),
                  action(
                    'architect-move-offset',
                    l.architectMoveOffset,
                    Icons.straighten,
                    () =>
                        _setSelectionMove(ArchitectSelectionMoveAction.offset),
                  ),
                  if (_moveSelection)
                    action(
                      'architect-move-stop',
                      l.architectMoveStop,
                      Icons.stop,
                      () =>
                          _setSelectionMove(ArchitectSelectionMoveAction.stop),
                    ),
                ]
              : const [],
        ),
      );
      if (generic) {
        actions.addAll([
          action(
            'architect-selection-mirror-move',
            l.architectMirrorMove,
            Icons.flip,
            () => _startMirrorSession(),
            color: accent,
            commandId: 'mirrorMove',
            tooltip: l.architectMirrorMoveTooltip,
          ),
        ]);
      }
    }
    actions.add(
      action(
        'architect-selection-properties',
        l.architectProperties,
        Icons.tune,
        () {
          setState(() => _radialMenuScreenPosition = null);
          _showProperties();
        },
        primary: true,
      ),
    );
    actions.add(
      action(
        'architect-selection-copy-to-storeys',
        l.architectCopyToStoreys,
        Icons.copy_all_rounded,
        () => _openCopyStoreyDialog(selectedElementIds: ids),
        color: accent,
        tooltip: l.architectCopyToStoreysTooltip,
      ),
    );

    final selectedZone = ids.length == 1
        ? storey.zones.where((z) => ids.contains(z.id)).firstOrNull
        : null;
    if (selectedZone != null) {
      actions.add(
        action(
          'architect-zone-schedule',
          l.architectZoneScheduleTitle,
          Icons.table_chart_rounded,
          _showRoomScheduleDialog,
          color: const Color(0xFF38BDF8),
        ),
      );
      actions.add(
        action(
          'architect-zone-presets',
          l.architectZonePresetsDialogTitle,
          Icons.tune_rounded,
          () => _showZonePresetsDialog(selectedZone.category),
          color: const Color(0xFF80CBC4),
        ),
      );
    }

    if (generic) {
      if (wallIds.isNotEmpty) {
        actions.add(
          action(
            'wall-attach',
            l.architectWallAttach,
            Icons.join_inner,
            _triggerWallAttach,
            primary: true,
            color: _wallAttachSourceId != null ? Colors.amber : null,
            tooltip: l.architectWallAttach,
          ),
        );
        actions.add(
          action(
            'wall-detach',
            l.architectWallDetach,
            Icons.link_off,
            _triggerWallDetach,
            primary: true,
            color: _pendingDetachWallIds != null ? Colors.amber : null,
            tooltip: l.architectWallDetachPrompt,
          ),
        );
        if (wallIds.length == 1) {
          actions.add(
            action(
              'wall-curve',
              l.architectLineCurve,
              Icons.rounded_corner,
              () => _startEdgeCurvingSession(wallIds.single),
              color: accent,
              commandId: 'curveWall',
              tooltip: l.architectLineCurve,
            ),
          );
        }
      }
      if (ids.length == 1) {
        final linePrim = storey.cadPrimitives.where((p) =>
            p.id == ids.single &&
            (p.type == CadPrimitiveType.line ||
             p.type == CadPrimitiveType.polyline ||
             p.type == CadPrimitiveType.spline)).firstOrNull;
        if (linePrim != null) {
          actions.add(
            action(
              'architect-selection-continue',
              l.architectLineContinue,
              Icons.play_arrow,
              () => _continueLineDrafting(linePrim),
              color: accent,
              commandId: 'continue',
              tooltip: l.architectLineContinueTooltip,
            ),
          );
          if (linePrim.type == CadPrimitiveType.line) {
            actions.add(
              action(
                'architect-line-curve',
                l.architectLineCurve,
                Icons.rounded_corner,
                () => _startEdgeCurvingSession(linePrim.id),
                color: accent,
                commandId: 'curveLine',
              ),
            );
          } else if (linePrim.type == CadPrimitiveType.polyline) {
            actions.add(
              action(
                'architect-poly-curve',
                l.architectPolylineCurveSegment,
                Icons.rounded_corner,
                () => _startEdgeCurvingSession(linePrim.id),
                color: accent,
                commandId: 'curvePolyline',
              ),
            );
          } else if (linePrim.type == CadPrimitiveType.spline) {
            final isClosed = linePrim.closed ?? false;
            actions.add(
              action(
                'architect-spline-toggle-close',
                isClosed ? l.architectSplineOpen : l.architectSplineClose,
                isClosed ? Icons.lock_open : Icons.all_inclusive,
                () => _toggleSplineClosed(linePrim),
                color: accent,
                commandId: 'toggleSpline',
              ),
            );
          }
        }
        final isSlabSelected = storey.slabs.any((s) => s.id == ids.single);
        final polygonPrim = storey.cadPrimitives.where((p) =>
            p.id == ids.single &&
            (p.type == CadPrimitiveType.hatch || p.isPolygon)).firstOrNull;
        if (isSlabSelected || polygonPrim != null) {
          actions.add(
            action(
              'architect-contour-curve',
              l.architectLineCurve,
              Icons.rounded_corner,
              () => _startEdgeCurvingSession(ids.single),
              color: accent,
              commandId: 'curveContour',
              tooltip: l.architectLineCurve,
            ),
          );
        }
        if (InsertArchitectElementPoint.pathOf(storey, ids.single) != null) {
          actions.add(
            action(
              'architect-selection-new-point',
              l.bimNewPoint,
              Icons.add_circle_outline,
              () {
                _cancelActiveDrags();
                _startNewPointSession(ids.single);
              },
              color: accent,
              commandId: 'newPoint',
              graphic: BimEditingSymbol(
                BimEditAction.newPoint,
                color: accent,
                size: 18,
              ),
            ),
          );
        }
      }
      if (segmentIds.isNotEmpty) {
        actions.add(
          ArchitectSelectionAction(
            id: 'architect-wall-actions',
            label: l.contextMenuMore,
            icon: icon(Icons.more_horiz),
            children: [
              linear('wall-cut', l.architectWallCut, Icons.content_cut, 'cut'),
              action(
                'wall-chamfer',
                l.architectChamfer,
                Icons.crop_square,
                _triggerChamfer,
                color: accent,
                commandId: 'chamfer',
              ),
              action(
                'wall-fillet',
                l.architectFillet,
                Icons.rounded_corner,
                _triggerFillet,
                color: accent,
                commandId: 'fillet',
              ),
              linear(
                'wall-split-stroke',
                l.architectWallSplit,
                Icons.call_split,
                'splitStroke',
              ),
              linear(
                'wall-mirror-move',
                l.architectMirrorMove,
                Icons.flip,
                'mirrorMove',
                commandId: 'mirrorMove',
              ),
              if (lineIds.isEmpty)
                linear(
                  'wall-mirror',
                  l.architectWallMirror,
                  Icons.swap_horiz,
                  'mirror',
                ),
              if (segmentIds.length == 1 && !_multiSelect) ...[
                linear(
                  'wall-point',
                  l.bimNewPoint,
                  Icons.add_circle_outline,
                  'point',
                  commandId: 'newPoint',
                ),
                linear(
                  'wall-extend',
                  l.architectWallExtend,
                  Icons.open_in_full,
                  'extend',
                ),
              ],
              if (segmentIds.length >= 2)
                linear(
                  'wall-join',
                  l.architectWallJoin,
                  Icons.join_inner,
                  'join',
                ),
            ],
          ),
        );
      }
    }
    final canChamferFillet = wallIds.isNotEmpty ||
        lineIds.isNotEmpty ||
        storey.slabs.any((s) => ids.contains(s.id)) ||
        storey.cadPrimitives.any((p) => ids.contains(p.id) && (p.isPolygon || p.type == CadPrimitiveType.polyline || p.type == CadPrimitiveType.line)) ||
        storey.pathways.any((p) => ids.contains(p.id)) ||
        storey.streets.any((s) => ids.contains(s.id)) ||
        storey.siteFences.any((f) => ids.contains(f.id)) ||
        storey.vegetation.any((v) => ids.contains(v.id) && v.isHedge) ||
        _project.proposedTerrain.boundaries.any((b) => ids.contains(b.id)) ||
        _project.proposedTerrain.contours.any((c) => ids.contains(c.id)) ||
        _project.existingTerrain.boundaries.any((b) => ids.contains(b.id)) ||
        _project.existingTerrain.contours.any((c) => ids.contains(c.id));

    if (canChamferFillet) {
      actions.add(
        ArchitectSelectionAction(
          id: 'architect-chamfer-fillet-menu',
          label: l.architectChamfer,
          icon: icon(Icons.rounded_corner),
          children: [
            action(
              'architect-chamfer',
              l.architectChamfer,
              Icons.crop_square_outlined,
              _triggerChamfer,
              color: accent,
            ),
            action(
              'architect-fillet',
              l.architectFillet,
              Icons.rounded_corner,
              _triggerFillet,
              color: accent,
            ),
          ],
        ),
      );
    }

    if (ids.isNotEmpty) {
      actions.add(
        action(
          'architect-change-layer',
          l.architectChangeLayer,
          Icons.layers_outlined,
          _triggerChangeLayer,
          color: accent,
        ),
      );
    }

    actions.addAll([
      action(
        'architect-selection-delete',
        l.delete,
        Icons.delete_outline,
        _deleteSelection,
        primary: true,
        color: danger,
      ),
      action(
        'architect-clear-selection',
        l.architectSelectionClear,
        Icons.close,
        _clearSelection,
        primary: true,
      ),
    ]);
    return ArchitectSelectionActionBar(
      actions: actions,
      count: ids.length,
      menuOnly: menuOnly,
      showClear: !_showSelectionControl,
      showCount: !_showSelectionControl,
      onAction: _dismissTouchCandidates,
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
      ...storey.pathways.map((e) => e.id),
      ...storey.streets.map((e) => e.id),
      ...storey.vegetation.map((e) => e.id),
      ...storey.siteFences.map((e) => e.id),
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

      builder: (ctx) => architectAlertDialog(

        backgroundColor: const Color(0xFF1E1E24),

        title: Text(

          l10n.architectAnnotationText,

          style: const TextStyle(color: Colors.white),

        ),

        content: TextField(

          controller: controller,

          autofocus: true, minLines: 3, maxLines: null,

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

        _commands.commit(_project.updateActiveStorey(updatedStorey), applyDraftingDefaults: true);

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



  // === SECTION: [SEC-10-GRIDS] DYNAMIC GRID AXES ACTIONS ===
  // --- SUBSECTION: [TAG:GRID_AXIS] Grid Axes Alignments, Offsets & Numbering ---



  void _handleAxisOffset(StructuralGridAxis axis) {

    showArchitectGridAxisOffsetDialog(

      context: context,

      unitToMeters: _project.units.scaleToMeters,

      unitSymbol: _project.units.symbol,

      onStartDragMode: (distance) {
        _beginGeometryCommand(ArchitectRadialAction.offset);

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
    _beginGeometryCommand(ArchitectRadialAction.straighten);

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
    _beginGeometryCommand(ArchitectRadialAction.straighten);

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

    _beginGeometryCommand(ArchitectRadialAction.rotate);
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



  // === SECTION: [SEC-11-LAYOUT] MAIN BUILD METHOD & WORKSPACE LAYOUT ===
  // --- SUBSECTION: [TAG:BUILD_LAYOUT] Scaffold, Top/Bottom Bars & Sheet Panels ---



  @override

  Widget build(BuildContext context) {

    final l10n = context.l10n;

    final compactActions = MediaQuery.sizeOf(context).width < 600;

    final selectedDoor = _selectedElementId != null
        ? _project.activeStorey.walls
            .expand((w) => w.doors)
            .where((d) => d.id == _selectedElementId)
            .firstOrNull
        : null;
    final selectedWindow = _selectedElementId != null
        ? _project.activeStorey.walls
            .expand((w) => w.windows)
            .where((w) => w.id == _selectedElementId)
            .firstOrNull
        : null;



    return CallbackShortcuts(

      bindings: {

        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):

            _undoModel,

        const SingleActivator(LogicalKeyboardKey.keyY, control: true):

            _redoModel,

        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            _startDragSession,

        const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            _startDragSession,

        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openFindAndSelectDialog,

        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _openFindAndSelectDialog,

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

                        icon: const AppIcon(AppIconId.undo),

                      ),

                      IconButton(

                        key: const ValueKey('architect-redo'),

                        tooltip: l10n.architectZoneRedoAction,

                        onPressed: _commands.canRedo ? _redoModel : null,

                        color: Colors.white,

                        disabledColor: Colors.white38,

                        icon: const AppIcon(AppIconId.redo),

                      ),

                      IconButton(

                        key: const ValueKey('architect-ghost-storeys'),

                        tooltip: l10n.architectGhostStoreys,

                        icon: AppIcon(
                          AppIconId.layers,

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

                          icon: AppIcon(
                            AppIconId.grid,

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

                        icon: const AppIcon(
                          AppIconId.settings,

                          color: Colors.white,

                        ),

                        onPressed: _showWorkspaceSettings,

                      ),

                      IconButton(

                        key: const ValueKey('architect-layers'),

                        tooltip: l10n.architectLayers,

                        icon: const AppIcon(
                          AppIconId.layers,

                          color: Colors.white,

                        ),

                        onPressed: _openLayersDialog,

                      ),

                      if (!compactActions)

                        IconButton(

                          key: const ValueKey('architect-deselect'),

                          tooltip: l10n.architectDeselect,

                          onPressed:

                              _effectiveSelection.isNotEmpty || _multiSelect

                              ? _clearSelection

                              : null,

                          icon: AppIcon(
                            AppIconId.deselect,

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

                          icon: AppIcon.fromMaterial(

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

                          icon: const AppIcon(
                            AppIconId.fitView,

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

                          icon: AppIcon.fromMaterial(

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

                          icon: const AppIcon(
                            AppIconId.newBuilding,

                            color: Colors.white,

                          ),

                          onPressed: _openNewProjectWizard,

                        ),

                      // Diagnostic Logs Dialog Button

                      if (!compactActions)

                        IconButton(

                          tooltip: l10n.architectDebugLogs,

                          icon: const AppIcon(
                            AppIconId.bug,

                            color: Colors.white,

                          ),

                          onPressed: _showDebugLogsDialog,

                        ),

                      // CAD Underlay Toggle Button (if underlays are present)

                      if (!compactActions && _underlaysByStorey.isNotEmpty)

                        IconButton(

                          tooltip: l10n.architectUnderlayToggle,

                          icon: AppIcon.fromMaterial(

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

                          icon: const AppIcon(
                            AppIconId.moreVertical,

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

                              child: AppMenuLabel(
                                icon: AppIconId.grid,
                                child: Text(l10n.architectDrawingGrid),

                            ),
                            ),

                            PopupMenuItem(

                              value: 'view',

                              child: AppMenuLabel(
                                icon: _is3DView
                                    ? AppIconId.viewTop
                                    : AppIconId.view3D,

                              child: Text(

                                _is3DView

                                    ? l10n.architectView2D

                                    : l10n.architectView3D,

                              ),

                            ),
                            ),

                            PopupMenuItem(

                              value: 'fit',

                              child: AppMenuLabel(
                                icon: AppIconId.fitView,
                                child: Text(l10n.architectResetView),
                              ),

                            ),

                            if (_effectiveSelection.isNotEmpty || _multiSelect)

                              PopupMenuItem(

                                value: 'deselect',

                                child: AppMenuLabel(
                                  icon: AppIconId.deselect,
                                  child: Text(l10n.architectDeselect),
                                ),

                              ),



                            if (!_is3DView)

                              PopupMenuItem(

                                key: const ValueKey(

                                  'architect-canvas-background-menu',

                                ),

                                value: 'background',

                                child: Row(

                                  children: [
                                    AppIcon.fromMaterial(

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

                              child: AppMenuLabel(
                                icon: AppIconId.add,
                                child: Text(l10n.architectNewProject),

                            ),
                            ),

                            if (_underlaysByStorey.isNotEmpty)

                              PopupMenuItem(

                                value: 'underlay',

                                child: AppMenuLabel(
                                  icon: AppIconId.layers,
                                  child: Text(l10n.architectUnderlayToggle),

                              ),
                              ),

                            PopupMenuItem(

                              value: 'logs',

                              child: AppMenuLabel(
                                icon: AppIconId.bug,
                                child: Text(l10n.architectDebugLogs),
                              ),

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

              : Visibility(
                  visible: !_dragController.isActive,
                  maintainState: true,
                  child: ArchitectToolPalette(

                  zonePresets: _zonePresets,

                  drawingOnly: !_commands.isPlan,

                  onTerrain: _commands.view == ArchitectWorkspaceView.elevation ? _startTerrainDraft : null,

                  activeTool: _activeTool,
                  interactionMode: _interactionMode,
                  selectionTool: _selectionDrawingTool ?? _quickDrawingTool,
                  onSelectAll: _effectiveSelection.isEmpty ? null : _selectSimilarElements,
                  onFindAndSelect: _openFindAndSelectDialog,
                  onDrawSelection: _startDrawingFromSelection,

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
                  onDeleteWallType: _deleteWallType,
                  wallProjectId: _project.id,
                  wallUnit: _project.units,

                  onCreateFenestration: _openFenestrationEditor,

                  activeWindowStyle:
                      selectedWindow?.resolvedStyle ??
                      _elementTool.activeWindowStyle ??
                      FenestrationLibraryService.instance.activeWindowStyle,

                  activeDoorStyle:
                      selectedDoor?.resolvedStyle ??
                      _elementTool.activeDoorStyle ??
                      FenestrationLibraryService.instance.activeDoorStyle,

                  selectedDoor: selectedDoor,
                  selectedWindow: selectedWindow,

                  doorHasCasing: selectedDoor?.effectiveHasCasing ?? _doorHasCasing,
                  onDoorHasCasingChanged: (c) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(hasCasing: c);
                    } else {
                      setState(() => _doorHasCasing = c);
                    }
                  },

                  windowHasCasing: selectedWindow?.effectiveHasCasing ??
                      _elementTool.windowHasCasing,
                  onWindowHasCasingChanged: (c) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(hasCasing: c);
                    } else {
                      _elementTool.setWindowParams(hasCasing: c);
                    }
                  },

                  windowIsFlipped: selectedWindow?.isFlipped,
                  onWindowFlippedChanged: (f) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(isFlipped: f);
                    }
                  },

                  onWindowStyleSelected: (style) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(styleId: style.id);
                    } else {
                      setState(() {
                        _elementTool.setWindowStyle(style);
                      });
                    }
                  },

                  onDoorStyleSelected: (style) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(styleId: style.id);
                    } else {
                      setState(() {
                        _doorWidth = style.defaultWidth;
                        _doorHeight = style.defaultHeight;
                        _doorSill = style.defaultSillHeight;
                        _elementTool.setDoorStyle(style);
                      });
                    }
                  },

                  doorWidth: selectedDoor?.width ?? _doorWidth,

                  onDoorWidthChanged: (w) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(width: w);
                    } else {
                      setState(() => _doorWidth = w);
                    }
                  },

                  doorHeight: selectedDoor?.height ?? _doorHeight,

                  onDoorHeightChanged: (h) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(height: h);
                    } else {
                      setState(() => _doorHeight = h);
                    }
                  },

                  doorSill: selectedDoor?.sillHeight ?? _doorSill,

                  onDoorSillChanged: (s) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(sill: s);
                    } else {
                      setState(() => _doorSill = s);
                    }
                  },

                  isHingeLeft: selectedDoor?.isHingeLeft ?? _isHingeLeft,

                  onHingeSideChanged: (left) {
                    if (selectedDoor != null) {
                      _updateSelectedDoor(isHingeLeft: left);
                    } else {
                      setState(() => _isHingeLeft = left);
                    }
                  },

                  windowWidth: selectedWindow?.width ?? _elementTool.windowWidth,

                  onWindowWidthChanged: (w) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(width: w);
                    } else {
                      _elementTool.setWindowParams(width: w);
                    }
                  },

                  windowHeight: selectedWindow?.height ?? _elementTool.windowHeight,

                  onWindowHeightChanged: (h) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(height: h);
                    } else {
                      _elementTool.setWindowParams(height: h);
                    }
                  },

                  windowSill: selectedWindow?.sillHeight ?? _elementTool.windowSill,

                  onWindowSillChanged: (s) {
                    if (selectedWindow != null) {
                      _updateSelectedWindow(sill: s);
                    } else {
                      _elementTool.setWindowParams(sill: s);
                    }
                  },

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
                  decorativeDepth: _elementTool.decorativeDepth,
                  onDecorativeDepthChanged: (d) =>
                      setState(() => _elementTool.setDecorativeParams(depth: d)),
                  decorativeSpanLength: _elementTool.decorativeSpanLength,
                  onDecorativeSpanLengthChanged: (l) => setState(
                    () => _elementTool.setDecorativeParams(spanLength: l),
                  ),
                  decorativeFrameWidth: _elementTool.decorativeFrameWidth,
                  onDecorativeFrameWidthChanged: (fw) => setState(
                    () => _elementTool.setDecorativeParams(frameWidth: fw),
                  ),
                  decorativeNormalOffset: _elementTool.decorativeNormalOffset,
                  onDecorativeNormalOffsetChanged: (no) => setState(
                    () => _elementTool.setDecorativeParams(normalOffset: no),
                  ),
                  decorativeMaterial: _elementTool.decorativeMaterial,
                  onDecorativeMaterialChanged: (m) => setState(
                    () => _elementTool.setDecorativeParams(material: m),
                  ),
                  activeDecorativePreset: _elementTool.activeDecorativePreset,
                  onDecorativePresetChanged: (p) => setState(
                    () => _elementTool.setDecorativeParams(
                      preset: p,
                      clearPreset: p == null,
                    ),
                  ),
                  showDecorativeOnPlan: _project.showDecorativeOnPlan,
                  onShowDecorativeOnPlanChanged: (v) {
                    _commands.execute(SetArchitectShowDecorativeOnPlan(v));
                    _saveBiMProjectIfAttached();
                  },
                  onOpenDecorativeStudio: () => _openDecorativeStudio(),
                  landscapeBar: _activeTool.isLandscapeTool
                      ? ArchitectLandscapeBar(
                          activeTool: _activeTool,
                          landscapeTool: _landscapeTool,
                          onChanged: () {
                            _updateSelectedLandscapeElement();
                            _repaintPreview();
                          },
                          onCommitDraft: _commitLandscapeDraft,
                          onUndoPoint: () {
                            setState(_landscapeTool.undoLastPoint);
                            _repaintPreview();
                          },
                          onCancelDraft: _cancelDrafting,
                          onSyncTerrainFromGeodesy: _syncTerrainFromGeodesy,
                          onTriggerChamfer: _triggerChamfer,
                          onTriggerFillet: _triggerFillet,
                        )
                      : null,

                  componentRotation: _componentRotation,

                  onRotateComponent: () {

                    setState(() {

                      _componentRotation = (_componentRotation + 3.141592653589793 / 2.0) % (2.0 * 3.141592653589793);

                    });

                  },

                  onOpenComponentLibrary: () {

                    ArchitectComponentLibraryDialog.show(

                      context,
                      initialCategory: _activeTool == ArchitectTool.services
                          ? ArchitectComponentCategory.services : null,

                      onSelectDownpipe: () => _beginDownpipePlacement(),
                      onSelectFloorDrain: () => setState(() => _activeTool = ArchitectTool.floorDrain,
                      ),

                      onSelectComponent: (def) {

                        setState(() => _activeTool = def.category == ArchitectComponentCategory.services
                            ? ArchitectTool.services : ArchitectTool.component);

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

                    if (!_dragController.isActive && _activeTool == ArchitectTool.zone &&

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
                          onOpenPresets: () => _showZonePresetsDialog(_activeZoneCategory),

                          onPlaceTable: () => setState(

                            () {
                              _originalZoneTableOrigin = _project.activeStorey.zoneScheduleOrigin;
                              _pendingZoneTableOrigin = null;
                              _activeTool = ArchitectTool.zoneTable;
                            },

                          ),

                        ),

                      ),

                    if (!_dragController.isActive && _activeTool == ArchitectTool.zoneTable &&
                        !_is3DView &&
                        _radialMenuScreenPosition == null &&
                        _newPointTargetId == null) ...[
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: ArchitectZoneTableBar(
                          isTablePlaced:
                              _project.activeStorey.zoneScheduleOrigin != null,
                          hasPendingPlacement: _pendingZoneTableOrigin != null,
                          onConfirmPlacement: _confirmZoneTablePlacement,
                          onCancelPlacement: _cancelZoneTablePlacement,
                          onBackToZones: () => setState(() {
                            if (_pendingZoneTableOrigin != null) {
                              _cancelZoneTablePlacement();
                            } else {
                              _activeTool = ArchitectTool.zone;
                            }
                          }),
                          onOpenScheduleDialog: _showRoomScheduleDialog,
                          onRemoveTable: _removeZoneScheduleTable,
                          onClose: () => setState(() {
                            if (_pendingZoneTableOrigin != null) {
                              _cancelZoneTablePlacement();
                            } else {
                              _activeTool = ArchitectTool.pan;
                            }
                          }),
                        ),
                      ),
                      if (_pendingZoneTableOrigin != null) ...[
                        () {
                          final screenPos =
                              _modelToScreen(_pendingZoneTableOrigin!);
                          final screenW = MediaQuery.sizeOf(context).width;
                          final left = math.max(
                            12.0,
                            math.min(screenW - 120.0, screenPos.dx),
                          );
                          final top = math.max(60.0, screenPos.dy - 44.0);
                          return Positioned(
                            left: left,
                            top: top,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xEE161A26),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF00E676),
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const AppIcon(
                                      AppIconId.confirm,
                                      color: Color(0xFF00E676),
                                      size: 18,
                                    ),
                                    tooltip:
                                        l10n.architectZoneTableConfirmPlacement,
                                    onPressed: _confirmZoneTablePlacement,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: const AppIcon(
                                      AppIconId.close,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    tooltip:
                                        l10n.architectZoneTableCancelPlacement,
                                    onPressed: _cancelZoneTablePlacement,
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }(),
                      ],
                    ],

                    if (!_dragController.isActive && _activeTool == ArchitectTool.axis && !_is3DView)

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

                    if (!_dragController.isActive && (_activeTool == ArchitectTool.roof ||

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
                          onOpenAssemblyDialog: () => _openRoofLayersDialog(roof: _selectedRoof, initialTab: 1,
                          ),
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

                          onToggleParapet: () {
                            final sel = _selectedRoof;
                            if (sel == null) return;
                            final next = sel.copyWith(
                              parapet: sel.parapet.copyWith(enabled: !sel.parapet.enabled),
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

                    if (!_dragController.isActive && _activeOvershoot != null && !_is3DView)

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

                    if (_underlayBusy)
                      Positioned.fill(
                        child: AbsorbPointer(
                          child: Center(
                            child: Material(
                              elevation: 12,
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xF01E242C),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.8,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00E5FF),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      _underlayBusyMessage ??
                                          context.l10n.bimProjectConvertingUnderlay,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_dragController.isActive && !_is3DView)
                      _buildDragFloatingOverlay(),
                    if (_pendingDetachWallIds != null && !_is3DView)
                      _buildDetachFloatingOverlay(),
                    if (_wallAttachSourceId != null && !_is3DView)
                      _buildAttachFloatingOverlay(),
                    if (_chamferFilletSourceId != null && !_is3DView)
                      _buildChamferFilletFloatingOverlay(),
                    if (_wallJoinSourceId != null && !_is3DView)
                      _buildWallJoinFloatingOverlay(),
                    if (_curvingEdgeElementId != null && !_is3DView)
                      _buildCurvingEdgeFloatingOverlay(),
                    if (_showSelectionActions ||
                        (_touchCandidates != null && !_is3DView && !_printPreview) ||
                        (MediaQuery.sizeOf(context).width < 600 &&
                            _multiSelect && !_is3DView && _showSelectionControl))
                      Positioned(bottom: 0, left: 0, right: 0, child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Keep the canvas stable when a hold selects an axis.
                          if (_showSelectionActions && !_multiSelect &&
                              _effectiveSelection.length == 1 &&
                              _axisTool.selectedAxisId != null && !_is3DView)
                            Builder(builder: (_) {
                              final axis = _axisTool.getSelectedAxis(_project);
                              if (axis == null) return const SizedBox.shrink();
                              return ArchitectGridAxisPropertiesCard(
                                axis: axis,
                                onOffset: () => _handleAxisOffset(axis),
                                onAlign: () => _handleAxisAlign(axis),
                                onDelete: () => _handleAxisDelete(axis),
                                onClose: () => _axisTool.deselect(),
                              );
                            }),
                          if (_touchCandidates != null && !_is3DView && !_printPreview)
                            Padding(padding: const EdgeInsets.all(8),
                              child: _buildTouchCandidatePicker(),
                              ),
                          if (_showSelectionActions &&
                              (_touchCandidates == null || MediaQuery.sizeOf(context).width >= 600)) Listener(
                            onPointerDown: (_) => _dismissTouchCandidates(),
                            child: _buildSelectionBar(),
                              ),
                          if (MediaQuery.sizeOf(context).width < 600 &&
                              _multiSelect && !_is3DView && _showSelectionControl)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                              child: _buildSelectControl(),
                            ),
                        ],
                      ),
                      ),
                  ],

                ),

              ),







              if (_multiSelect && !_is3DView && MediaQuery.sizeOf(context).width >= 600)
                SizedBox(height:60,child:_showSelectionControl
                  ? Padding(padding:const EdgeInsets.fromLTRB(8,4,8,4),child:_buildSelectControl(),
                        )
                  : const SizedBox.shrink(),
                ),
            ],

          ),

        ),

      ),

    );

  }



  // === SECTION: [SEC-12-LOGS] DIAGNOSTIC LOGS DIALOG (ARCHITECT LOGGER) ===
  // --- SUBSECTION: [TAG:LOGGER_UI] Diagnostic Logger Dialog Modal ---



  void _showDebugLogsDialog() {

    final l10n = context.l10n;

    showDialog<void>(

      context: context,

      builder: (ctx) {

        return StatefulBuilder(

          builder: (dialogCtx, setDialogState) {

            final logs = ArchitectLogger.history;

            return architectAlertDialog(

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



  // === SECTION: [SEC-13-VIEW2D] 2D CANVAS VIEWPORT (LAYERED MODEL SPACE) ===
  // --- SUBSECTION: [TAG:CANVAS_2D] 2D CustomPainter Canvas, Viewport & Draft Overlays ---



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

    if (_activeTool == ArchitectTool.services && _effectiveSelection.isEmpty) {
      final center = _servicePreviewPoint ?? _cursorModel;
      if (center == null) return null;
      final activeDef = ComponentLibraryService.instance.activeDefinition;
      final activeParams = ComponentLibraryService.instance.activeParameters;
      final (w, d) = activeDef is ServiceComponentDefinition
          ? activeDef.footprint(activeParams)
          : (0.4, 0.4);
      final halfWidth = w / 2;
      final halfDepth = d / 2;
      final angle = _servicePreviewRotation * math.pi / 180;
      final cosine = math.cos(angle).abs();
      final sine = math.sin(angle).abs();
      return center + Offset(
        halfWidth * cosine + halfDepth * sine,
        -(halfWidth * sine + halfDepth * cosine),
      );
    }

    if (_activeTool == ArchitectTool.opening && _draftStart != null && _draftEnd != null) {
      return _draftEnd!;
    }

    if (_activeTool == ArchitectTool.door ||

        _activeTool == ArchitectTool.window) {

      return _openingPlacementPreview?.centerPoint ?? _cursorModel;

    }

    if (_activeTool.isLandscapeTool && _landscapeTool.isDrafting) {
      return _landscapeTool.draftPoints.lastOrNull ??
          _landscapeTool.draftPoints.firstOrNull;
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



  bool get _canConfirmLandscapeDraft =>
      _activeTool.isLandscapeTool && _landscapeTool.canCommit(_activeTool.name);

  bool get _canConfirmDraft => _canConfirmDimension || _canConfirmRoofDraft || _canConfirmLandscapeDraft ||
      _canConfirmContour || _canConfirmZone ||
      (_activeTool == ArchitectTool.services && _servicePreviewPoint != null) ||
      (_activeTool == ArchitectTool.column && _columnPreviewPoint != null && !_columnPreviewIsOccupied) ||
      (_activeTool == ArchitectTool.opening && _draftStart != null && _draftEnd != null);

  void _commitColumnPlacement() {
    final pt = _columnPreviewPoint ?? _cursorModel;
    if (pt == null || _columnPreviewIsOccupied) return;
    final rot = _columnPreviewRotation;
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
        applyDraftingDefaults: true,
      );
      _columnPreviewPoint = null;
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
  }

  void _commitServicePlacement() {
    final pt = _servicePreviewPoint ?? _cursorModel;
    if (pt == null) return;
    final activeDef = ComponentLibraryService.instance.activeDefinition;
    final activeParams = ComponentLibraryService.instance.activeParameters;
    final rot = _servicePreviewRotation * math.pi / 180.0;
    final newComp = ArchitectComponentInstance(
      id: "comp_${DateTime.now().millisecondsSinceEpoch}",
      definitionId: activeDef.id,
      position: pt,
      rotation: rot,
      parameters: Map.of(activeParams),
    );
    final updatedComponents = [..._project.activeStorey.components, newComp];
    final updatedStorey = _project.activeStorey.copyWith(
      components: updatedComponents,
    );
    setState(() {
      _commands.commit(
        _project.copyWith(
          storeys: [
            for (final s in _project.storeys)
              if (s.id == updatedStorey.id) updatedStorey else s,
          ],
        ),
        applyDraftingDefaults: true,
      );
      _servicePreviewPoint = null;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
  }

  void _commitOpeningPlacement() {
    if (_draftStart == null || _draftEnd == null) return;
    final res = _elementTool.placeOpening(
      storey: _project.activeStorey,
      p1: _draftStart!,
      p2: _draftEnd!,
    );
    if (res != null) {
      setState(() {
        _commands.commit(
          _project.updateActiveStorey(res.$1),
          applyDraftingDefaults: true,
        );
        _draftStart = null;
        _draftEnd = null;
        _wallArcEnd = null;
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectOpeningPlaced),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _commitLandscapeDraft() {
    final nextProject = _landscapeTool.commitDraft(
      toolName: _activeTool.name,
      project: _project,
    );
    if (nextProject != null) {
      setState(() {
        _commands.commit(nextProject, applyDraftingDefaults: true);
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.mediumImpact();
    }
  }

  void _syncTerrainFromGeodesy() {
    final survey = _project.geodeticSurvey;
    final count =
        (survey?.contours.length ?? 0) + (survey?.spotElevations.length ?? 0);
    final nextProject = _landscapeTool.syncTerrainFromGeodesy(_project);
    setState(() {
      _commands.commit(nextProject);
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectTerrainSyncedFromGeodesy(count)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateSelectedLandscapeElement() {
    final id = _selectedElementId;
    if (id == null) return;
    final storey = _project.activeStorey;
    var storeyChanged = false;

    final nextPathways = [
      for (final p in storey.pathways)
        if (p.id == id)
          () {
            storeyChanged = true;
            return p.copyWith(
              width: _landscapeTool.pathwayWidth,
              curbMode: _landscapeTool.pathwayCurbMode,
              curbWidth: _landscapeTool.pathwayCurbWidth,
              curbHeight: _landscapeTool.pathwayCurbHeight,
              material: _landscapeTool.pathwayMaterial,
              closed: _landscapeTool.pathwayClosed,
            );
          }()
        else
          p,
    ];

    final nextFences = [
      for (final f in storey.siteFences)
        if (f.id == id)
          () {
            storeyChanged = true;
            return f.copyWith(
              preset: _landscapeTool.fencePreset,
              height: _landscapeTool.fenceHeight,
              thickness: _landscapeTool.fenceThickness,
              pierSpacing: _landscapeTool.fencePierSpacing,
            );
          }()
        else
          f,
    ];

    final nextVeg = [
      for (final v in storey.vegetation)
        if (v.id == id)
          () {
            storeyChanged = true;
            return v.copyWith(
              species: _landscapeTool.plantSpecies,
              crownDiameter: _landscapeTool.plantCrownDiameter,
              height: _landscapeTool.plantHeight,
              hedgeWidth: _landscapeTool.hedgeWidth,
            );
          }()
        else
          v,
    ];

    final nextStreets = [
      for (final s in storey.streets)
        if (s.id == id)
          () {
            storeyChanged = true;
            return s.copyWith(
              roadWidth: _landscapeTool.streetRoadWidth,
              curbWidth: _landscapeTool.streetCurbWidth,
              curbHeight: _landscapeTool.streetCurbHeight,
              hasLeftSidewalk: _landscapeTool.streetHasLeftSidewalk,
              leftSidewalkWidth: _landscapeTool.streetLeftSidewalkWidth,
              hasRightSidewalk: _landscapeTool.streetHasRightSidewalk,
              rightSidewalkWidth: _landscapeTool.streetRightSidewalkWidth,
              markingStyle: _landscapeTool.streetMarkingStyle,
              markingWidth: _landscapeTool.streetMarkingWidth,
              roadMaterial: _landscapeTool.streetRoadMaterial,
              sidewalkMaterial: _landscapeTool.streetSidewalkMaterial,
              closed: _landscapeTool.streetClosed,
            );
          }()
        else
          s,
    ];

    var updated = storeyChanged
        ? _project.updateActiveStorey(
            storey.copyWith(
              pathways: nextPathways,
              siteFences: nextFences,
              streets: nextStreets,
              vegetation: nextVeg,
            ),
          )
        : _project;

    for (final (surf, isProposed) in [
      (updated.proposedTerrain, true),
      (updated.existingTerrain, false),
    ]) {
      var surfChanged = false;
      final nextBnd = [
        for (final b in surf.boundaries)
          if (b.id == id)
            () {
              surfChanged = true;
              return b.copyWith(
                elevation: _landscapeTool.terrainElevation,
                isFlatPad: _landscapeTool.terrainMode == ArchitectTerrainDraftMode.pad,
                isHole: _landscapeTool.terrainMode == ArchitectTerrainDraftMode.hole,
              );
            }()
          else
            b,
      ];
      final nextCnt = [
        for (final c in surf.contours)
          if (c.id == id)
            () {
              surfChanged = true;
              return c.copyWith(
                elevation: _landscapeTool.terrainElevation,
                rawAbsoluteElevation: _landscapeTool.contourAbsoluteElevation != 0.0
                    ? _landscapeTool.contourAbsoluteElevation
                    : (_landscapeTool.terrainElevation + surf.datumElevation),
                closed: _landscapeTool.contourClosed,
                isMajor: _landscapeTool.contourMajor,
              );
            }()
          else
            c,
      ];
      final nextSpots = [
        for (final s in surf.spots)
          if (s.id == id)
            () {
              surfChanged = true;
              return s.copyWith(
                elevation: _landscapeTool.terrainElevation,
                rawAbsoluteElevation: _landscapeTool.contourAbsoluteElevation != 0.0
                    ? _landscapeTool.contourAbsoluteElevation
                    : (_landscapeTool.terrainElevation + surf.datumElevation),
              );
            }()
          else
            s,
      ];

      final datumChanged = (surf.datumElevation - _landscapeTool.terrainDatumElevation).abs() > 1e-4;
      if (surfChanged || datumChanged) {
        final nextSurf = surf.copyWith(
          datumElevation: _landscapeTool.terrainDatumElevation,
          boundaries: nextBnd,
          contours: nextCnt,
          spots: nextSpots,
        );
        updated = isProposed
            ? updated.copyWith(proposedTerrain: nextSurf, updatedAt: DateTime.now())
            : updated.copyWith(existingTerrain: nextSurf, updatedAt: DateTime.now());
      }
    }

    if (!identical(updated, _project)) {
      setState(() => _project = updated);
      _commands.commit(updated);
      _saveBiMProjectIfAttached();
    }
  }

  void _onConfirmDraft() {
    if (_canConfirmLandscapeDraft) {
      _commitLandscapeDraft();
      return;
    }

    if (_cutOpeningTargetId != null && _canConfirmContour) {

      _commitCutOpening();

      return;

    }

    if (_activeTool == ArchitectTool.services && _servicePreviewPoint != null) {
      _commitServicePlacement();
      return;
    }

    if (_activeTool == ArchitectTool.column && _columnPreviewPoint != null && !_columnPreviewIsOccupied) {
      _commitColumnPlacement();
      return;
    }

    if (_activeTool == ArchitectTool.opening && _draftStart != null && _draftEnd != null) {
      _commitOpeningPlacement();
      return;
    }

    if (_canConfirmContour) {

      if (_activeTool == ArchitectTool.hatch) { _commitHatch(); return; }

      final result = _elementTool.commitSlab(storey: _project.activeStorey);

      if (result != null) {

        setState(() => _commands.commit(_project.updateActiveStorey(result.$1), applyDraftingDefaults: true,
          ),
        );

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

      if (_commandPreview != null || _dragController.isActive) {
        _renderedDraftCancelRect = null;
        _renderedDraftConfirmRect = null;
        return const SizedBox.shrink();
      }
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

                    child: AppIcon(
                      AppIconId.close,

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

                        child: AppIcon(
                          AppIconId.confirm, size: 15, color: Colors.white,
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

  );



  Widget _build2DCanvas()=>Padding(key:_propertiesCanvasKey,padding:_propertiesDrawingInsets,child:_build2DCanvasContent(),
  );

  Widget _build2DCanvasContent() => Stack(

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

        singlePointerPan: !_multiSelect,

        holdToEdit:

            !_dragController.isActive && _duplicateMove == null &&

            _offsetOptions == null &&

            _effectiveSelection.isNotEmpty &&

            !_multiSelect &&

            !_moveSelection &&

            _wallCutIds.isEmpty &&

            _wallExtendId == null &&

            _wallJoinSourceId == null &&
            _wallAttachSourceId == null &&
            _pendingDetachWallIds == null &&

            _radialMenuScreenPosition == null &&

            _newPointTargetId == null,

        touchHoldToPlace: _canPlaceWithMarker,

        holdExistingHandles: _dragController.isActive,

        onToolHoldStart: _beginPlacementHold,

        onSelectionHold: !_dragController.isActive && _offsetOptions == null && _duplicateMove == null && _newPointTargetId == null && _pendingDetachWallIds == null && _wallAttachSourceId == null

            ? _onSelectionHold

            : null,

        onSecondaryTap: !_dragController.isActive && _offsetOptions == null && _duplicateMove == null && _newPointTargetId == null && _pendingDetachWallIds == null && _wallAttachSourceId == null
            ? _onContextHold : null,
        onContextHold: !_dragController.isActive && _offsetOptions == null && _duplicateMove == null && _newPointTargetId == null && _pendingDetachWallIds == null && _wallAttachSourceId == null

            ? _onContextHold

            : null,

        onEditTap: (_polygonEditId == null && _selectedRoof == null)
            ? null
            : (position) => _selectPolygonEdge(_screenToModel(position)),

        isDraggingHandle: () => _selectionBoxDown != null ||
            _newPointTargetId != null || _isActivelyDraggingHandle ||
            (_curvedDraftTool && _draftStart != null),

        onToolDown: _onPointerDown,

        onToolMove: _onPointerMove,

        onToolHover: _onPointerHover,

        onToolUp: _onPointerUp,

        onToolCancel: () {

          if (_dragController.isActive) {
            _cancelDragPlacement();
          } else {
            _cancelActiveDrags();
          }

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
              child: ValueListenableBuilder<int>(
                valueListenable: _previewRevision,
                builder: (_, _, _) => CustomPaint(
                  painter: ArchitectUnderlayPainter(
                    palette: _canvasPalette,
                    document: _currentUnderlayDoc,
                    frame: _effectiveUnderlayFrame,
                    viewport: _viewport,
                    visibility: Map.of(_effectiveUnderlayLayerVisibility),
                    rasterUnderlays: _project.rasterUnderlaysForStorey(
                      _project.activeStorey.id,
                    ),
                    rasterImages: _rasterImages,
                    selectedRasterId: _selectedRasterUnderlay?.id,
                    isCadSelected: _isCadUnderlaySelected,
                    isDragActive:
                        _dragController.isActive && _dragController.isUnderlay,
                    isDragPickingBase: _dragController.isUnderlay &&
                        _dragController.isPickingBasePoint,
                    dragBasePoint: _dragController.isUnderlay
                        ? _dragController.basePointModel
                        : null,
                    dragCurrentPoint: _dragController.isUnderlay
                        ? _dragController.currentPointModel
                        : null,
                    dragSnapLabel: _dragController.isUnderlay &&
                            _dragController.currentSnapLabel != null
                        ? _localizedSnapLabel(_dragController.currentSnapLabel!)
                        : null,
                    dragIsSnapped:
                        _dragController.isUnderlay && _dragController.isSnapped,
                    dragDistanceMeters: _dragController.isUnderlay
                        ? _dragController.distanceMeters
                        : 0,
                    dragAngleDeg: _dragController.isUnderlay
                        ? _dragController.angleDeg
                        : 0,
                    dragMagneticGuides: _dragController.isUnderlay
                        ? _dragController.magneticGuides
                        : const [],
                    ghostRasterPosition: _dragController.ghostRasterPosition,
                    draggingRasterId: _dragController.rasterId,
                    showRasterLayer:
                        _showUnderlay &&
                        _commands.isPlan &&
                        _project.isLayerVisible(
                          ArchitectLayer.rasterUnderlayLayerId,
                        ),
                    showGeodesyLayer:
                        _commands.isPlan &&
                        _project.isLayerVisible(ArchitectLayer.geodesyLayerId),
                    geodeticContours:
                        _project.geodeticSurvey?.contoursForStorey(
                          _project.activeStorey.id,
                        ) ??
                        const [],
                    geodeticPoints:
                        _project.geodeticSurvey?.pointsForStorey(
                          _project.activeStorey.id,
                        ) ??
                        const [],
                    calibrationP1: _rasterCalibrationP1,
                    calibrationP2: _rasterCalibrationP2,
                    calibrationCursor: _rasterCalibrationStep > 0
                        ? _cursorModel
                        : null,
                    cadConfig: _currentCadUnderlayConfig,
                    maskDraftPoints: _underlayMaskPoints,
                    isMaskDrafting: _underlayMaskDrafting,
                    isPlacingCadUnderlay: _cadInsertionActive ||
                        (_dragController.isDraggingToTarget &&
                            _dragController.isCadUnderlay),
                    ghostCadDocument: _cadInsertionDoc ??
                        (_dragController.isCadUnderlay ? _currentUnderlayDoc : null),
                    ghostCadFrame: _ghostUnderlayFrame,
                    ghostInsertionPoint: _dragController.isDraggingToTarget &&
                            _dragController.isCadUnderlay
                        ? _dragController.currentPointModel
                        : (_cadInsertionPendingPoint ??
                            _cadInsertionHoverPoint ??
                            _cursorModel),
                  ),
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

            if (_dragController.isActive)
              Positioned(
                left: 8,
                top: 8,
                child: IgnorePointer(
                  child: ArchitectCanvasHint(
                    key: const ValueKey('architect-drag-step-hint'),
                    message: _dragController.isPickingBasePoint
                        ? context.l10n.architectDragPickBasePoint
                        : context.l10n.architectDragPickTargetPoint,
                    maxLines: 1,
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

                              'Apparent intersection' => DxfSnapType.apparentIntersection,

                              'Midpoint' => DxfSnapType.midpoint,

                              'Center' => DxfSnapType.center,
                              'Quadrant' => DxfSnapType.quadrant,

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

                      final isArcDrafting = _wallArcEnd != null &&
                          _draftStart != null &&
                          _curvedDraftTool;
                      final liveDim = isArcDrafting
                          ? 'h=${_project.formatLength((_wallArcEnd! - _draftStart!).distance * _draftArcBulge.abs() / 2)}'
                          : (lastAnchor != null && (target - lastAnchor).distance > 0.01
                              ? _project.formatLength(
                                  (target - lastAnchor).distance,
                                )
                              : null);

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

            if (!_dragController.isActive && !_mirrorReview && !_showSelectionControl && _touchCandidates == null && _newPointTargetId == null) Positioned(

              left: 12,

              right: 12,

              bottom: _showSelectionActions ? 60 : 12,

              child: IgnorePointer(

                child: ValueListenableBuilder<int>(

                  valueListenable: _previewRevision,

                  builder: (context, revision, child) => ArchitectCanvasHint(
                    message: _activeTool == ArchitectTool.dimension

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

                                  ? (_touchInput ? context.l10n.architectTouchSelectionHelp
                                    : context.l10n.architectSelectionCycleHelp)

                                  : context.l10n.architectEditHoldHint)

                            : _activeTool == ArchitectTool.select

                            ? (_touchInput ? context.l10n.architectTouchSelectionHelp
                                    : context.l10n.architectSelectionCycleHelp)

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
                  ),

                ),

              ),

            ),

          ],

        ),

      ),

      if (_touchCandidates != null && _multiSelect)
        Positioned.fill(child: IgnorePointer(child: CustomPaint(
          key: const ValueKey('architect-candidate-preview'),
          painter: ArchitectCandidateOutline(
            ArchitectSelection.outline(_project, _touchCandidates!.current),
            _viewport.toScreen,
              ),
            ),
          ),
        ),
      if (_commands.isPlan && _acceptsAnySelection && !_placingDownpipe)
        Positioned.fill(child: AnimatedBuilder(
          animation: Listenable.merge([_viewport, _modelCommands]),
          builder: (_, _) => ArchitectDownpipeHandle(
            controller: _modelCommands,
            onNavigate: (delta, factor, focal) => _viewport.navigate(
              previousFocal: focal - delta, focal: focal, scaleFactor: factor,
              ),
            roofIds: _project.activeStorey.roofs.map((r) => r.id).toSet(),
            toScreen: (p, z) => _viewport.toScreen(p),
          ),
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

          bottom: 8,

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

                  if (_commandPreview == null) TextButton(

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

      if (!_dragController.isActive) ...[
        _buildWallClearanceOverlay(),
        _buildWallArcDimensionOverlay(),
        _buildWallAngleOverlay(),
      ],

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

                icon: const AppIcon(AppIconId.close, color: Colors.white),

                onPressed: () => setState(_cancelDrafting),

              ),

            ),

          ),

        ),

      if (_cutOpeningTargetId != null)

        Positioned(bottom: 8, left: 8, right: 8, child: _cutOpeningControl()),

      if (_editingGroupId != null)

        Positioned(top: _offsetOptions == null ? 8 : 64, left: 8, right: 8, child: _groupEditBanner(),
        ),

      _buildPolygonDistanceOverlay(),

      _buildHatchTransformHandle(),

      _buildShapeDimensionOverlay(),

      _buildOpeningDimensionOverlay(),

      if (_activeTool == ArchitectTool.dimension &&

          !_multiSelect &&

          _effectiveSelection.isEmpty)

        Positioned(top: 8, left: 8, right: 8, child: _buildDimensionBar()),

      if (_wallCutIds.isNotEmpty && !_wallCutStroke)
        _buildCutFloatingOverlay(),

      if (_splitActive)
        _buildSplitFloatingOverlay(),

      if (_newPointTargetId != null && _newPointWall != null)
        Positioned.fill(child: AnimatedBuilder(
          animation: Listenable.merge([_viewport, _previewRevision]),
          builder: (_, _) {
            final wall = _newPointWall;
            final candidate = _newPointCandidate;
            if (wall == null || candidate == null) return const SizedBox.shrink();
            return ArchitectNewPointOverlay(wall: wall, candidate: candidate,
              darkCanvas: _canvasPalette.isDark,
              gripOffset: _newPointGripOffset, valid: _newPointValid,
              snapLabel: _localizedSnapLabel(_activeSnapLabel),
              toScreen: _viewport.toScreen, toModel: _screenToModel,
              format: _project.formatLength,
              obstacles: ArchitectClearanceObstacles.forWalls(_project.activeStorey.walls),
              onEdit: _editNewPointDistance);
          },
        )),

      if (_newPointTargetId != null)
        _buildNewPointFloatingOverlay(),

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



      if (_activeTool == ArchitectTool.hatch && _effectiveSelection.isEmpty)

        Positioned(top: 8, left: 8, child: _hatchControl()),

      if (_activeTool == ArchitectTool.mask && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconId.mask, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(context.l10n.architectToolMask, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _maskBorder,
                        onChanged: (v) => setState(() => _maskBorder = v ?? true),
                      ),
                      Text(context.l10n.architectMaskBorder, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  if (_elementTool.slabDraftPoints.length >= 3)
                    IconButton(
                      tooltip: context.l10n.applyAction,
                      icon: const AppIcon(AppIconId.confirm, color: Colors.cyanAccent),
                      onPressed: _commitMask,
                    ),
                  IconButton(
                    tooltip: context.l10n.cancel,
                    icon: const AppIcon(AppIconId.close, color: Colors.white70),
                    onPressed: () => setState(_elementTool.cancelSlabDrafting),
                  ),
                ],
              ),
            ),
          ),
        ),

      if (_activeTool == ArchitectTool.spline && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconId.spline, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(context.l10n.architectToolSpline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _lineStyleControl(),
                  if (_elementTool.slabDraftPoints.length >= 2)
                    IconButton(
                      tooltip: context.l10n.applyAction,
                      icon: const AppIcon(AppIconId.confirm, color: Colors.cyanAccent),
                      onPressed: () => _commitSpline(closed: false),
                    ),
                  if (_elementTool.slabDraftPoints.length >= 3)
                    IconButton(
                      tooltip: context.l10n.architectSplineClose,
                      icon: const Icon(Icons.all_inclusive, color: Colors.cyanAccent, size: 20),
                      onPressed: () => _commitSpline(closed: true),
                    ),
                  IconButton(
                    tooltip: context.l10n.cancel,
                    icon: const AppIcon(AppIconId.close, color: Colors.white70),
                    onPressed: () => setState(_elementTool.cancelSlabDrafting),
                  ),
                ],
              ),
            ),
          ),
        ),

      if (_activeTool == ArchitectTool.cadUnderlay && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topLeft,
            child: ArchitectCadUnderlayBar(
              config: _currentCadUnderlayConfig,
              contourCount:
                  _project.geodeticSurvey
                      ?.contoursForStorey(_project.activeStorey.id)
                      .length ??
                  0,
              spotPointCount:
                  _project.geodeticSurvey
                      ?.pointsForStorey(_project.activeStorey.id)
                      .length ??
                  0,
              isBusy: _underlayBusy,
              onImportCad: _importOrReplaceCadUnderlay,
              onReplaceCad: _importOrReplaceCadUnderlay,
              onToggleAutoReload: _toggleCadAutoReload,
              onToggleLockOrigin: _toggleCadOriginLock,
              onReloadNow: _reloadCurrentCadUnderlayNow,
              onOpenDxfLayers: _openCadDxfLayersSheet,
              onExtractContours: _extractGeodesyFromCurrentUnderlay,
              onApplyToTerrain: _applyGeodesyTo3DTerrain,
              onRemoveUnderlay: _removeCurrentCadUnderlay,
              onReposition: _repositionCurrentCadUnderlay,
              onDrag: () => _startUnderlaySnapDrag(isCad: true),
              onOpenScale: _openCadScaleDialog,
              onOpenMaskMenu: (pos) => _openCadMaskMenu(pos),
              onOpenContextMenu: (pos) => _openCadContextMenu(pos),
            ),
          ),
        ),

      if (_activeTool == ArchitectTool.rasterUnderlay && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topLeft,
            child: ArchitectRasterUnderlayBar(
              underlays: _project.rasterUnderlaysForStorey(
                _project.activeStorey.id,
              ),
              selectedUnderlay: _selectedRasterUnderlay,
              calibrationStep: _rasterCalibrationStep,
              isBusy: _underlayBusy,
              onImportRaster: _importRasterUnderlay,
              onSelectUnderlay: (id) => setState(() => _selectedRasterId = id),
              onDrag: () => _startUnderlaySnapDrag(
                isCad: false,
                rasterId: _selectedRasterUnderlay?.id,
              ),
              onStartCalibration: () => setState(() {
                _rasterCalibrationStep = 1;
                _rasterCalibrationP1 = null;
                _rasterCalibrationP2 = null;
              }),
              onCancelCalibration: () => setState(() {
                _rasterCalibrationStep = 0;
                _rasterCalibrationP1 = null;
                _rasterCalibrationP2 = null;
              }),
              onChangeOpacity: (val) {
                final sel = _selectedRasterUnderlay;
                if (sel != null) {
                  _updateSelectedRaster(sel.copyWith(opacity: val));
                }
              },
              onToggleLock: () {
                final sel = _selectedRasterUnderlay;
                if (sel != null) {
                  _updateSelectedRaster(sel.copyWith(locked: !sel.locked));
                }
              },
              onRotateCcw: () {
                final sel = _selectedRasterUnderlay;
                if (sel != null) {
                  _updateSelectedRaster(
                    sel.copyWith(rotationRad: sel.rotationRad - math.pi / 2),
                  );
                }
              },
              onRotateCw: () {
                final sel = _selectedRasterUnderlay;
                if (sel != null) {
                  _updateSelectedRaster(
                    sel.copyWith(rotationRad: sel.rotationRad + math.pi / 2),
                  );
                }
              },
              onResetTransform: () {
                final sel = _selectedRasterUnderlay;
                if (sel != null) {
                  _updateSelectedRaster(
                    sel.copyWith(
                      rotationRad: 0.0,
                      metersPerPixel: sel.imageWidthPx > 0
                          ? (20.0 / sel.imageWidthPx)
                          : 0.01,
                    ),
                  );
                }
              },
              onDeleteRaster: _deleteSelectedRaster,
              onOpenScale: _openRasterScaleDialog,
              onOpenMaskMenu: (pos) => _openRasterMaskMenu(pos),
              onOpenContextMenu: (pos) => _openRasterContextMenu(pos),
            ),
          ),
        ),

      if (_underlayMaskDrafting)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Center(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xEE1E293B),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIconId.crop,
                      size: 20,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _underlayMaskMode == 'rect'
                          ? context.l10n.architectUnderlayMaskRectPrompt
                          : context.l10n.architectUnderlayMaskPolyPrompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_underlayMaskMode == 'polygon') ...[
                      FilledButton(
                        onPressed: _underlayMaskPoints.length >= 3
                            ? () => _commitUnderlayMask(_underlayMaskPoints)
                            : null,
                        child: Text(context.l10n.architectUnderlayMaskFinish),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: _cancelUnderlayMaskDraft,
                      child: Text(context.l10n.architectUnderlayMaskCancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      if (_cadInsertionActive)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Center(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xEE1E293B),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIconId.newPoint,
                      size: 20,
                      color: Color(0xFF00E676),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _cadInsertionPendingPoint == null
                              ? context.l10n.architectUnderlayInsertionPrompt
                              : '${context.l10n.architectUnderlayInsertionConfirm}: (${_cadInsertionPendingPoint!.dx.toStringAsFixed(2)}, ${_cadInsertionPendingPoint!.dy.toStringAsFixed(2)})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_cadInsertionControlPoint != null)
                          Text(
                            'CAD Base: (${_cadInsertionControlPoint!.dx.toStringAsFixed(2)}, ${_cadInsertionControlPoint!.dy.toStringAsFixed(2)})',
                            style: const TextStyle(
                              color: Color(0xFF81D4FA),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    if (_cadInsertionPendingPoint != null) ...[
                      Tooltip(
                        message: context.l10n.architectUnderlayInsertionConfirm,
                        child: IconButton.filled(
                          onPressed: _confirmCadInsertion,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.white,
                          ),
                          icon: const AppIcon(AppIconId.confirm, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Tooltip(
                      message: context.l10n.architectUnderlayInsertionCancel,
                      child: IconButton.outlined(
                        onPressed: _cancelCadInsertion,
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        icon: const AppIcon(AppIconId.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      // In-canvas floating confirmation badge pinned directly at insertion point
      if (_cadInsertionActive && _cadInsertionPendingPoint != null)
        Builder(
          builder: (ctx) {
            final screenPos = _modelToScreen(_cadInsertionPendingPoint!);
            return Positioned(
              left: (screenPos.dx - 64).clamp(16.0, MediaQuery.of(ctx).size.width - 140),
              top: (screenPos.dy - 56).clamp(64.0, MediaQuery.of(ctx).size.height - 80),
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xEE1E293B),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.l10n.architectUnderlayInsertionConfirm,
                        onPressed: _confirmCadInsertion,
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00E676),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: context.l10n.architectUnderlayInsertionCancel,
                        onPressed: _cancelCadInsertion,
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

      if (_activeTool == ArchitectTool.roofSlope && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconId.roofSlope, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(context.l10n.architectToolRoofSlope, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(context.l10n.architectRoofSlopePercent),
                    selected: _activeRoofSlopeFormat == RoofSlopeFormat.percent,
                    onSelected: (_) => setState(() => _activeRoofSlopeFormat = RoofSlopeFormat.percent),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: Text(context.l10n.architectRoofSlopeDegree),
                    selected: _activeRoofSlopeFormat == RoofSlopeFormat.degree,
                    onSelected: (_) => setState(() => _activeRoofSlopeFormat = RoofSlopeFormat.degree),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: Text(context.l10n.architectRoofSlopeBoth),
                    selected: _activeRoofSlopeFormat == RoofSlopeFormat.both,
                    onSelected: (_) => setState(() => _activeRoofSlopeFormat = RoofSlopeFormat.both),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.l10n.architectRoofSlopeReverse,
                    icon: AppIcon(
                      AppIconId.flipHorizontal,
                      size: 20,
                      color: _activeRoofSlopeDirection == RoofSlopeDirection.upslope ? Colors.cyanAccent : Colors.white70,
                    ),
                    onPressed: () => setState(() {
                      _activeRoofSlopeDirection = _activeRoofSlopeDirection == RoofSlopeDirection.downslope
                          ? RoofSlopeDirection.upslope
                          : RoofSlopeDirection.downslope;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),

      if (_activeTool == ArchitectTool.cadEllipse && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconId.ellipse, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(context.l10n.architectToolCadEllipse, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _lineStyleControl(),
                ],
              ),
            ),
          ),
        ),

      if (_activeTool == ArchitectTool.leader && _effectiveSelection.isEmpty)
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: const Color(0xEE1E242C),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIconId.multileader, size: 20, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(context.l10n.architectToolLeader, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),

      if ((_activeTool == ArchitectTool.floorDrain || _selectedFloorDrain != null) &&

          _effectiveSelection.length <= 1)

        Positioned(top: 8, left: 8, child: _floorDrainControl()),

      if ((_activeTool == ArchitectTool.wall || _activeTool == ArchitectTool.cadLine || _activeTool == ArchitectTool.cadArc) && _effectiveSelection.isEmpty)

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

                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    LayoutBuilder(builder: (context, constraints) =>
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _activeTool == ArchitectTool.wall ? constraints.maxWidth : null,
                          child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      if (_activeTool == ArchitectTool.cadLine || _activeTool == ArchitectTool.cadArc)

                        _lineStyleControl(),

                      if (_activeTool == ArchitectTool.cadLine)
                        IconButton(
                          tooltip: context.l10n.architectLineEndCap,
                          icon: AppIcon(
                            _activeLineStartCap != ArchitectLineEndCap.none || _activeLineEndCap != ArchitectLineEndCap.none
                                ? AppIconId.lineArrow
                                : AppIconId.moreHorizontal,
                            size: 20,
                            color: _activeLineStartCap != ArchitectLineEndCap.none || _activeLineEndCap != ArchitectLineEndCap.none
                                ? Colors.cyanAccent
                                : Colors.white70,
                          ),
                          onPressed: _showLineCapsDialog,
                        ),

                      if (_activeTool == ArchitectTool.wall)

                        Expanded(

                          child: Theme(
                            data: ThemeData.dark(),
                            child: SizedBox(
                              height: 40,
                              child: ArchitectWallReferenceControl(
                                key: const ValueKey('wall-toolbar-reference',
                                    ),
                                value: _wallReference,
                                onChanged: _setDraftWallReference,
                              ),
                            ),
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

                          icon: AppIcon(
                                AppIconId.flipHorizontal,

                            size: 20,

                            color: _wallExteriorSide == WallExteriorSide.right

                                ? const Color(0xFF00E5FF)

                                : Colors.white,

                          ),

                          onPressed: () => setState(() {

                            _wallStartAttachment = null;
                            _wallExteriorSideMode = WallResolutionMode.manual;

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

                            padding: const EdgeInsets.symmetric(horizontal: 4,
                                ),

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

                                const AppIcon(AppIconId.measure, size: 18),

                                if (MediaQuery.sizeOf(context).width >=

                                    400) ...[

                                  const SizedBox(width: 8),

                                  Text(context.l10n.architectWallLength),

                                ],

                              ],

                            ),

                          ),

                        ),

                      if (_activeTool == ArchitectTool.wall || _activeTool == ArchitectTool.cadLine)

                        IconButton(

                          key: const ValueKey('wall-arc-toggle'),

                          tooltip: context.l10n.wallArc,

                          constraints: const BoxConstraints.tightFor(

                            width: 36,

                            height: 40,

                          ),

                          padding: EdgeInsets.zero,

                          icon: AppIcon(
                                AppIconId.roundedCorner,

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

                          onPressed: () => _editWallArcDimension(
                            dimension: ArchitectArcDimension.radius,
                              ),

                          child: const Text('R='),

                        ),

                        IconButton(

                          key: const ValueKey('wall-arc-confirm'),

                          tooltip: context.l10n.applyAction,

                          onPressed: () {
                            if (_draftArcExactBulge == null) {
                              unawaited(_editWallArcDimension(
                                dimension: ArchitectArcDimension.sagitta,
                                commitDraft: true,
                              ));
                            } else {
                              _commitWallArc();
                            }
                          },

                          icon: const AppIcon(
                                AppIconId.confirm,

                            color: Colors.cyanAccent,

                          ),

                        ),

                      ],

                      if (_activeTool == ArchitectTool.cadLine ? !_cadPolylineMode : !_wallCurved)

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

                          icon: AppIcon(
                                AppIconId.points,

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

                          icon: const AppIcon(
                                AppIconId.close,

                            color: Colors.white,

                            size: 18,

                          ),

                        ),

                    ],

                  ),
                        ),
                      ),
                    ),

                  if (_activeTool == ArchitectTool.cadLine)
                    Theme(data: ThemeData.dark(), child: Wrap(children: [
                      ChoiceChip(key: const ValueKey('architect-line-mode-line'),
                        label: Text(context.l10n.architectToolCadLine),
                        selected: !_cadPolylineMode,
                        onSelected: (_) => _setCadPolylineMode(false),
                              ),
                      const SizedBox(width: 8),
                      Tooltip(message: context.l10n.architectPolylineHint,
                        child: ChoiceChip(
                          key: const ValueKey('architect-line-mode-polyline',
                                  ),
                          showCheckmark: false,
                          avatar: const AppIcon(
                                    AppIconId.polyline, size: 16,
                                  ),
                          label: Text(context.l10n.architectToolPolyline,
                                  ),
                          selected: _cadPolylineMode,
                          onSelected: (_) => _setCadPolylineMode(true),
                                ),
                              ),
                      if (_cadPolylineMode) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          key: const ValueKey('architect-polyline-arc-mode'),
                          label: Text(context.l10n.architectPolylineModeArc),
                          selected: _polylineArcSegmentMode,
                          onSelected: (val) => setState(() => _polylineArcSegmentMode = val),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          key: const ValueKey('architect-polyline-width'),
                          label: Text(_activePolylineWidth != null ? '${_activePolylineWidth}m' : context.l10n.architectPolylineWidth),
                          onPressed: _promptPolylineWidth,
                        ),
                      ],
                    ],
                          ),
                        ),

                  if (_draftGroupChoiceVisible)

                    Theme(data: ThemeData.dark(), child: Row(children: [

                      Checkbox(key: const ValueKey('architect-draft-group'), value: _groupDraftChain,

                        onChanged: (v) => setState(() => _groupDraftChain = v ?? false,
                                ),
                              ),

                      Text(context.l10n.bimGroup),

                      const Spacer(),

                      if (!_wallDirectionLocked)

                        IconButton(key: const ValueKey('architect-draft-group-finish',
                                  ),

                          tooltip: context.l10n.bimGroupDone,

                          icon: const AppIcon(AppIconId.confirm), onPressed: _finishChainedWall,
                                ),

                    ],
                          ),
                        ),

                  ],
                  ),

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

      if (_linearDraftTool || (_activeTool == ArchitectTool.hatch && _elementTool.slabDraftPoints.isNotEmpty))

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

                final width = math.min(264.0, constraints.maxWidth - 16);

                final phone = constraints.maxWidth < 600;
                final left = phone ? (constraints.maxWidth - width) / 2 : (point.dx + 20).clamp(

                  8.0,

                  math.max(8.0, constraints.maxWidth - width - 8),

                );

                final top = (point.dy + 24).clamp(

                  8.0,

                  math.max(8.0, constraints.maxHeight - 390),

                );

                return Stack(

                  children: [

                    Positioned(

                      left: left.toDouble(),

                      top: phone ? null : top.toDouble(),
                      bottom: phone ? 8 : null,

                      width: width,

                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(0, constraints.maxHeight - 16),
                        ),
                        child: SingleChildScrollView(
                          child: ArchitectWallDraftingPanel(

                        key: ValueKey((_draftStart, _wallDirectionLocked)),

                        length: _project.units.toUnit(

                          (_draftEnd! - _draftStart!).distance,

                        ),

                        unit: _project.units.symbol,

                        decimals: _project.distanceDecimals,

                        minimumLength: _project.units.toUnit(.001),
                        keypadInitiallyOpen: _curvedDraftTool,
                        showContinue: !_curvedDraftTool,
                        title: _curvedDraftTool ? context.l10n.architectEdgeDistance : null,
                        endLabel: _curvedDraftTool ? context.l10n.applyAction : null,

                        extraControls: _activeTool == ArchitectTool.wall
                            ? SizedBox(
                                height: 36,
                                child: ArchitectWallReferenceControl(
                                  key: const ValueKey('wall-panel-reference'),
                                  value: _wallReference,
                                  onChanged: _setDraftWallReference,
                                ),
                              )
                            : null,

                        onLength: (value) {

                          if (_project.units.fromUnit(value) < .001) return;

                          final delta = _draftEnd! - _draftStart!;

                          if (delta.distance < .001) return;

                          _draftEnd =

                              _draftStart! +

                              delta /

                                  delta.distance *

                                  _project.units.fromUnit(value);

                          if (_activeTool == ArchitectTool.hatch) {
                            _elementTool.updateSlabCandidate(_draftEnd!);
                          }

                          _activeSnapLabel = null;

                          _repaintPreview();

                        },

                        onEnd: () {
                          if (_curvedDraftTool) {
                            _beginDraftArcShaping();
                            return;
                          }
                          if (_activeTool == ArchitectTool.hatch) {
                            final pt = _draftEnd!;
                            setState(() {
                              _elementTool.addSlabPoint(pt);
                              _wallDirectionLocked = false;
                              _wallPanelAnchor = null;
                              _draftStart = null;
                              _draftEnd = null;
                            });
                            if (_elementTool.slabDraftPoints.length >= 3) {
                              _commitHatch();
                            }
                            return;
                          }
                          _commitCurrentWallSegment(

                            _draftEnd!,

                            continueChain: false,

                          );
                        },

                        onContinue: () {
                          if (_curvedDraftTool) {
                            _beginDraftArcShaping();
                            return;
                          }
                          if (_activeTool == ArchitectTool.hatch) {
                            final pt = _draftEnd!;
                            setState(() {
                              _elementTool.addSlabPoint(pt);
                              _draftStart = pt;
                              _draftEnd = pt;
                              _wallDirectionLocked = false;
                              _wallPanelAnchor = null;
                            });
                            _repaintPreview();
                            return;
                          }
                          _commitCurrentWallSegment(

                            _draftEnd!,

                            continueChain: true,

                          );
                        },

                        onUnlock: () =>

                            setState(() => _wallDirectionLocked = false),

                        onCancel: () {
                          if (_activeTool == ArchitectTool.hatch) {
                            setState(() {
                              _wallDirectionLocked = false;
                              _wallPanelAnchor = null;
                              _draftStart = null;
                              _draftEnd = null;
                            });
                            _repaintPreview();
                            return;
                          }
                          _finishChainedWall();
                        },

                          ),
                        ),
                      ),

                    ),

                  ],

                );

              },

            );

          },

        ),

      if (!_commands.isPlan &&

          (_activeTool.isDecorativeTool ||
              _canAdoptPickedTool ||
              _interactionMode == ArchitectInteractionMode.singleSelect) &&

          _effectiveSelection.isEmpty)

        Positioned.fill(child: IgnorePointer(
          ignoring: _projectionLoading,
          child: _nativeProjectionEditor(),
          ),
        ),

      if (_projectionLoading || _projectionFailed)
        Positioned.fill(child: ArchitectProjectionStatus(failed: _projectionFailed,
          onRetry: () => setState(() { _sectionLoader.invalidate(); _facadeLoader.invalidate(); _projectionSource = null; }),
          ),
        ),

      if (_terrainDrafting)

        Positioned.fill(child: AnimatedBuilder(animation: _viewport,builder: (_, _) {

          final view=_modelCommands.project.elevations.firstWhere((e)=>e.id==_commands.viewId,
              );

          return ArchitectTerrainEditor(initial:view.terrain,

            toView:(p)=>_modelToSection(_screenToModel(p)),

            toScreen:(p)=>_viewport.toScreen(Offset(p.dx,-p.dy)),

            onCancel:()=>setState(()=>_terrainDrafting=false),

            onApply:(points) {

              final original=_modelCommands.project;

              _modelCommands.commit(original.copyWith(elevations:[for(final e in original.elevations)

                if(e.id==view.id) e.copyWith(terrain:points) else e,
                      ],
                    ),
                  );

              setState(()=>_terrainDrafting=false);

              _saveBiMProjectIfAttached();

            },
              );
            },
          ),
        ),

      if (_viewDraft != null)

        Positioned.fill(

          child: AnimatedBuilder(

            animation: _viewport,

            builder: (_, _) => ArchitectWorkspaceViewPlacement(

              key: ValueKey(_viewDraft),

              controller: _modelCommands,
              onCommit: _commandPreview == null ? null : (next) => _commands.commit(next),
              onPreview: _commandPreview == null ? null : (next) {
                final original = _commandPreview!.original;
                final before = original.toJson()..remove('updatedAt');
                final after = next.toJson()..remove('updatedAt');
                setState(() {
                  _commandLiveCandidate = bimValuesEqual(before, after) ? null : next;
                  _elementMovePreview = _commandLiveCandidate;
                });
                _repaintPreview();
              },

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

                if (id != null && _commandPreview == null) {

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
              previousFocal: focal - delta, focal: focal, scaleFactor: factor,
              ),
            ),
          ),
        ),
        _buildMirrorFloatingOverlay(),
      ],
      if (_offsetOptions != null) ...[
        Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(
          animation: Listenable.merge([_viewport, _previewRevision]),
          builder: (_, _) => CustomPaint(
            key: const ValueKey('architect-offset-direction'),
            painter: _offsetSide == null ? null : ArchitectOffsetDirectionPainter(
              start: _viewport.toScreen(ArchitectOffset.directionAnchor(
                _offsetSource!.activeStorey, _offsetIds, _offsetSide!,
                          ),
                        ),
              side: _viewport.toScreen(_offsetSide!),
              color: _offsetValid ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
          ),
        ),
        _buildOffsetFloatingOverlay(),
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
              previousFocal: focal - delta, focal: focal, scaleFactor: factor,
              ),
            onCancel: () { setState(_cancelActiveDrags); _repaintPreview(); },
          ),
        ),
        ),
      if (_viewDirectionDraft case final draft?)
        Positioned.fill(child: AnimatedBuilder(animation: _viewport,
          builder: (_, _) => ArchitectViewDirectionPicker(
            key: ValueKey(draft), start: draft.start, end: draft.end,
            toScreen: _viewport.toScreen, onSelected: _commitViewDirection,
            onCancel: () { setState(() => _viewDirectionDraft = null); _repaintPreview(); },
            onNavigate: (delta, factor, focal) => _viewport.navigate(
              previousFocal: focal - delta, focal: focal, scaleFactor: factor,
              ),
            ),
          ),
        ),
      if (_commandReady && !_mirrorActive)
        Positioned.fill(child: ArchitectTransformPointInput(
          key: const ValueKey('architect-command-review-input'),
          toModel: _screenToModel, toScreen: _viewport.toScreen,
          snap: (raw, touch) => _snapTransformPoint(raw, touch),
          localizeSnap: _localizedSnapLabel,
          onAim: (_) {}, onPick: (_) {},
          onNavigate: (delta, factor, focal) => _viewport.navigate(
            previousFocal: focal - delta, focal: focal, scaleFactor: factor,
            ),
          ),
        ),
      if (_commandPreview != null && !_dragController.isActive && !_mirrorActive && _chamferFilletSourceId == null)
        ArchitectFloatingCommandOverlay(
          surfaceKey: const ValueKey('architect-generic-command-overlay'),
          label: BimEditActions.label(_commandAction!, context.l10n),
          ready: _commandCanConfirm,
          onCancel: _cancelGeometryCommand,
          onConfirm: _confirmGeometryCommand,
          position: _commandFloatingPosition(MediaQuery.sizeOf(context)),
        ),
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
      applyDraftingDefaults: true,
    );

      _cancelCadShape();

      _saveBiMProjectIfAttached();

      HapticFeedback.lightImpact();

    } on ArgumentError {

      _operationError();

    }

  }

  // --- SUBSECTION: [TAG:CAD_EXPANSION_COMMITS] CAD EXPANSION COMMITS (ARC, MASK, SPLINE, ELLIPSE, LEADER, ROOF SLOPE) ---
  void _commitCadEllipse() {
    if (_draftStart == null || _draftEnd == null) return;
    final center = _draftStart!;
    final delta = _draftEnd! - center;
    final rx = delta.distance;
    if (rx < 1e-4) {
      _cancelCadShape();
      return;
    }
    final ry = rx * 0.6;
    final rot = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    final id = ArchitectElementId.next('ellipse');
    try {
      _commands.execute(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: ArchitectCadPrimitive(
            id: id,
            type: CadPrimitiveType.ellipse,
            startPoint: center - Offset(rx, ry),
            endPoint: center + Offset(rx, ry),
            radiusX: rx,
            radiusY: ry,
            rotationDeg: rot,
            colorValue: 0xFF9E9E9E,
            lineStyle: _activeCadLineStyle,
          ),
        ),
        applyDraftingDefaults: true,
      );
      _cancelCadShape();
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
    } on ArgumentError {
      _operationError();
    }
  }

  void _commitMask() {
    if (_elementTool.slabDraftPoints.length < 3) return;
    final points = List<Offset>.from(_elementTool.slabDraftPoints);
    final bounds = ArchitectSceneGeometry.boundsOf(points);
    final id = ArchitectElementId.next('mask');
    try {
      _commands.execute(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: ArchitectCadPrimitive(
            id: id,
            type: CadPrimitiveType.mask,
            startPoint: bounds.topLeft,
            endPoint: bounds.bottomRight,
            polygon: points,
            maskBorder: _maskBorder,
            colorValue: 0xFFFFFFFF,
          ),
        ),
        applyDraftingDefaults: true,
      );
      setState(() {
        _elementTool.cancelSlabDrafting();
        _draftStart = null;
        _draftEnd = null;
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
    } on ArgumentError {
      _operationError();
    }
  }

  void _commitSpline({bool closed = false}) {
    if (_elementTool.slabDraftPoints.length < 2) return;
    final points = List<Offset>.from(_elementTool.slabDraftPoints);
    final bounds = ArchitectSceneGeometry.boundsOf(points);
    final id = ArchitectElementId.next('spline');
    try {
      _commands.execute(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: ArchitectCadPrimitive(
            id: id,
            type: CadPrimitiveType.spline,
            startPoint: bounds.topLeft,
            endPoint: bounds.bottomRight,
            polygon: points,
            closed: closed,
            colorValue: 0xFF9E9E9E,
            lineStyle: _activeCadLineStyle,
          ),
        ),
        applyDraftingDefaults: true,
      );
      setState(() {
        _elementTool.cancelSlabDrafting();
        _draftStart = null;
        _draftEnd = null;
      });
      _saveBiMProjectIfAttached();
      HapticFeedback.lightImpact();
    } on ArgumentError {
      _operationError();
    }
  }

  void _continueLineDrafting(ArchitectCadPrimitive prim) {
    _cancelActiveDrags();
    _selectionIds.clear();
    _selectedElementId = null;
    if (prim.type == CadPrimitiveType.spline) {
      final pts = prim.linePoints;
      _activeTool = ArchitectTool.spline;
      _elementTool.cancelSlabDrafting();
      _commands.commit(
        _project.updateActiveStorey(
          _project.activeStorey.copyWith(
            cadPrimitives: _project.activeStorey.cadPrimitives.where((p) => p.id != prim.id).toList(),
          ),
        ),
      );
      _elementTool.slabDraftPoints.addAll(pts);
      _elementTool.slabCandidatePoint = pts.last;
      _draftStart = pts.last;
      _cursorModel = pts.last;
    } else if (prim.type == CadPrimitiveType.polyline) {
      _activeTool = ArchitectTool.cadLine;
      _cadPolylineMode = true;
      _polylineDraftId = prim.id;
      _draftStart = prim.linePoints.last;
      _cursorModel = prim.linePoints.last;
    } else if (prim.type == CadPrimitiveType.line) {
      final pts = [prim.startPoint, prim.endPoint];
      _commands.execute(
        PlaceArchitectCadPrimitive(
          storeyId: _project.activeStoreyId,
          primitive: prim.copyWith(
            type: CadPrimitiveType.polyline,
            polygon: pts,
          ),
        ),
      );
      _activeTool = ArchitectTool.cadLine;
      _cadPolylineMode = true;
      _polylineDraftId = prim.id;
      _draftStart = prim.endPoint;
      _cursorModel = prim.endPoint;
    }
    setState(() {});
    _repaintPreview();
  }

  void _toggleSplineClosed(ArchitectCadPrimitive spline) {
    final nextClosed = !(spline.closed ?? false);
    _commands.execute(
      PlaceArchitectCadPrimitive(
        storeyId: _project.activeStoreyId,
        primitive: spline.copyWith(closed: nextClosed),
      ),
    );
    setState(() {});
  }

  Future<void> _promptAddLeaderAnnotation(Offset arrowPoint, Offset landingPoint) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.architectToolLeader),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: ctx.l10n.architectLeaderPrompt,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) {
      setState(() {
        _draftStart = null;
        _draftEnd = null;
      });
      return;
    }
    final id = ArchitectElementId.next('leader');
    final annotation = ArchitectAnnotation(
      id: id,
      position: landingPoint,
      text: text,
      hasLeader: true,
      leaderArrowPoint: arrowPoint,
      leaderLandingPoint: landingPoint,
      leaderArrowStyle: _activeLeaderArrowStyle,
      leaderArrowSize: _activeLeaderArrowSize,
      leaderLandingLength: 0.30,
    );
    _commands.commit(
      _project.updateActiveStorey(
        _project.activeStorey.copyWith(
          annotations: [..._project.activeStorey.annotations, annotation],
        ),
      ),
      applyDraftingDefaults: true,
    );
    setState(() {
      _draftStart = null;
      _draftEnd = null;
    });
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
  }

  void _commitRoofSlopeArrow(Offset point) {
    ArchitectRoofPlane? targetPlane;

    for (final plane in _project.activeStorey.roofs) {
      if (plane.containsPoint(point)) {
        targetPlane = plane;
        break;
      }
    }

    if (targetPlane == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.architectRoofSlopeHint),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final arrowId = ArchitectElementId.next('slope');
    final arrow = ArchitectRoofSlopeArrow(
      id: arrowId,
      roofPlaneId: targetPlane.id,
      position: point,
      format: _activeRoofSlopeFormat,
      direction: _activeRoofSlopeDirection,
    );

    final updatedPlane = targetPlane.copyWith(
      slopeArrows: [...targetPlane.slopeArrows, arrow],
    );

    final updatedRoofs = _project.activeStorey.roofs
        .map((r) => r.id == updatedPlane.id ? updatedPlane : r)
        .toList();

    _commands.commit(
      _project.updateActiveStorey(
        _project.activeStorey.copyWith(roofs: updatedRoofs),
      ),
      applyDraftingDefaults: true,
    );
    _saveBiMProjectIfAttached();
    HapticFeedback.lightImpact();
  }

  Future<void> _showLineCapsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(ctx.l10n.architectLineEndCap),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ctx.l10n.architectLineStartCap, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButton<ArchitectLineEndCap>(
                    value: _activeLineStartCap,
                    isExpanded: true,
                    items: ArchitectLineEndCap.values.map((cap) => DropdownMenuItem(
                      value: cap,
                      child: Text(cap.label(ctx.l10n)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _activeLineStartCap = val);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(ctx.l10n.architectLineEndCap, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButton<ArchitectLineEndCap>(
                    value: _activeLineEndCap,
                    isExpanded: true,
                    items: ArchitectLineEndCap.values.map((cap) => DropdownMenuItem(
                      value: cap,
                      child: Text(cap.label(ctx.l10n)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _activeLineEndCap = val);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('${ctx.l10n.architectLineCapSize}: ${(_activeLineCapSize * 100).toStringAsFixed(0)} cm',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _activeLineCapSize,
                    min: 0.05,
                    max: 0.60,
                    divisions: 11,
                    label: '${(_activeLineCapSize * 100).toStringAsFixed(0)} cm',
                    onChanged: (v) {
                      setState(() => _activeLineCapSize = (v * 100).round() / 100);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.l10n.applyAction),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _promptPolylineWidth() async {
    final controller = TextEditingController(
      text: _activePolylineWidth != null ? _activePolylineWidth!.toStringAsFixed(2) : '0',
    );
    final width = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.architectPolylineWidth),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.of(ctx).pop(val != null && val > 0 ? val : null);
            },
            child: Text(ctx.l10n.applyAction),
          ),
        ],
      ),
    );
    setState(() => _activePolylineWidth = width);
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

  Widget _buildOpeningDimensionOverlay() => Positioned.fill(
    child: ValueListenableBuilder<int>(
      valueListenable: _previewRevision,
      builder: (_, revision, child) {
        if (_activeTool != ArchitectTool.opening || _draftStart == null || _draftEnd == null) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final position = _viewport.toScreen(_draftEnd!);
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
            final circular = _elementTool.openingType == OpeningType.circular;
            final values = circular
                ? [math.max(delta.dx.abs(), delta.dy.abs())]
                : [delta.dx.abs(), delta.dy.abs()];

            return Stack(
              children: [
                Positioned(
                  left: left.toDouble(),
                  top: top.toDouble(),
                  width: width,
                  child: ArchitectShapeDimensionPanel(
                    key: ValueKey((_draftStart, _elementTool.openingType)),
                    values: [for (final v in values) _project.units.toUnit(v)],
                    labels: circular
                        ? [context.l10n.propertiesDiameter]
                        : [
                            context.l10n.architectShapeWidth,
                            context.l10n.architectShapeHeight,
                          ],
                    unit: _project.units.symbol,
                    decimals: _project.distanceDecimals,
                    minimum: _project.units.toUnit(circular ? 0.02 : 0.15),
                    onChanged: (index, value) {
                      final meters = _project.units.fromUnit(value);
                      final current = _draftEnd! - _draftStart!;
                      if (circular) {
                        final signX = current.dx < 0 ? -1.0 : 1.0;
                        final signY = current.dy < 0 ? -1.0 : 1.0;
                        _draftEnd = _draftStart! + Offset(signX * meters, signY * meters);
                      } else {
                        _draftEnd = _draftStart! + Offset(
                          index == 0 ? (current.dx < 0 ? -meters : meters) : current.dx,
                          index == 1 ? (current.dy < 0 ? -meters : meters) : current.dy,
                        );
                      }
                      _activeMagneticGuides = [];
                      _activeSnapLabel = null;
                      _repaintPreview();
                    },
                    onSave: _commitOpeningPlacement,
                    onCancel: _cancelDrafting,
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

    if (label == 'Origin (0,0)') return l10n.architectUnderlayPresetOrigin;
    if (label == 'Center') return l10n.architectUnderlayPresetCenter;

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
      'Quadrant' => l10n.snapQuadrant,

      'Intersection' || 'Axis intersection' => l10n.snapIntersection,

      'Apparent intersection' => l10n.snapApparentIntersection,

      'Edge' => l10n.snapNearest,

      'Perpendicular' => l10n.snapPerpendicular,

      'Alignment' => l10n.architectWallAlign,

      'Alignment with Point 1' => l10n.snapAlignPoint1,

      '30 cm' => l10n.architectDimensionSnap30cm,

      '40 cm' => l10n.architectDimensionSnap40cm,

      'Door jamb' => l10n.snapDoorJamb,

      'Window jamb' => l10n.snapWindowJamb,

      'Opening jamb' => l10n.snapOpeningEdge,

      'Corner' || 'Wall corner' => l10n.snapCorner,

      'Wall face' => l10n.snapEdge,

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

    var project = _commandReady ? _commandPreview!.preview
        : _duplicateMove?.preview ?? _elementMovePreview ?? _project;

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

    activeOpeningType: _elementTool.openingType,

    componentPreview: _activeTool.usesComponent && _cursorModel != null

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
    activeWallSideManual: _wallExteriorSideMode == WallResolutionMode.manual,
    activeWallIsExterior: _activeWallType?.resolvedLocation != ArchitectWallLocation.interior,
    wallExteriorReviewIds: _modelCommands.exteriorReviewWallIds,

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
    activeWallRailing: _activeWallType?.railing,
    activeWallHeight: _activeWallType?.customHeight,

    activeWallArcEnd: _wallArcEnd,
    activeWallArcBulge: _wallArcEnd == null ? null : _draftArcBulge,
    activeWallCurved: _wallCurved,

    activeWallLayers: _activeWallType?.resolvedLayers ?? const [],

    activeSnapLabel: _localizedSnapLabel(_activeSnapLabel),

    // Selection outlines remain visible, but idle vertex/endpoint grips and
    // property dimensions must not compete with the active Drag controls.
    selectedElementId: _dragController.isActive ? null : _selectedElementId,

    selectedElementIds: _effectiveSelection,
    selectionPreviewActive: layer == ArchitectPaintLayer.interaction && _selectionPreview.active,
    selectionPreviewIds: layer == ArchitectPaintLayer.interaction ? _selectionPreview.result : const {},
    selectionPreviewAddedIds: layer == ArchitectPaintLayer.interaction ? _selectionPreview.added : const {},
    selectionPreviewRemovedIds: layer == ArchitectPaintLayer.interaction ? _selectionPreview.removed : const {},

    selectedZoneId: _dragController.isActive ? null : _selectedZoneId,

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
    marqueePolygon: _marqueeTool.mode==ArchitectSelectMode.polygon && _marqueeTool.points.length>=3
        ? List<Offset>.of(_marqueeTool.points) : _marqueeTool.previewPolygon,
    marqueeCandidate: _marqueeTool.mode==ArchitectSelectMode.polygon ? _marqueeTool.candidatePoint : null,
    marqueeContained: _selectionRelation==ArchitectSelectionRelation.contained,

    roofTool: _roofTool,
    landscapeTool: _landscapeTool,

    polygonEditInvalid: _polygonEditor.invalid,
    polygonEditHoleIndex: _selectedPolygonHoleIndex,

    polygonLeaderLine: _polygonEditor.leaderLine ?? _polygonDisplacementLine,

    handleOffsetLength: _handleOffsetLength,

    wallEndpointLeaderLine: _wallEndpointLeaderLine,

    wallJoinLeaderLine: _wallJoinLeaderLine ?? _wallAttachLeaderLine ?? _chamferFilletLeaderLine,

    newPointCandidate: _newPointCandidate,
    newPointHandleOffset: _newPointTargetId == null ? null : _newPointGripOffset,
    newPointValid: _newPointValid,

    newPointLeaderLine: _newPointLeaderLine,

    activeOvershoot: _activeOvershoot,
    dragController: _dragController,
    localizeSnap: _localizedSnapLabel,

  );



  // === SECTION: [SEC-14-VIEW3D] 3D SOLID VIEWPORT ===
  // --- SUBSECTION: [TAG:VIEW_3D] 3D Solid Viewport & Publication Preview ---



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

extension _ArchitectLineEndCapL10n on ArchitectLineEndCap {
  String label(AppLocalizations l) => switch (this) {
    ArchitectLineEndCap.none => l.architectLineCapNone,
    ArchitectLineEndCap.arrowFilled => l.architectLineCapArrowFilled,
    ArchitectLineEndCap.arrowOpen => l.architectLineCapArrowOpen,
    ArchitectLineEndCap.dotFilled => l.architectLineCapDotFilled,
    ArchitectLineEndCap.dotOpen => l.architectLineCapDotOpen,
    ArchitectLineEndCap.tick => l.architectLineCapTick,
  };
}
