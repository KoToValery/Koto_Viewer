import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../services/architect_building_section.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_roof_geometry.dart';
import '../services/architect_slab_assemblies.dart';
import '../services/architect_slab_geometry.dart';
import 'architect_roof_layers_dialog.dart';
import 'architect_slab_labels.dart';
import 'architect_view_plan.dart';
import 'architect_projection_editor.dart';

/// Uses the workspace controller so changes, autosave and history remain live.
class ArchitectBuildingSectionsScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  final String? initialSelectedId;
  final ValueChanged<String?>? onViewSelected;
  const ArchitectBuildingSectionsScreen({
    super.key,
    required this.controller,
    this.initialSelectedId,
    this.onViewSelected,
  });
  @override
  State<ArchitectBuildingSectionsScreen> createState() =>
      _BuildingSectionsState();
}

class _BuildingSectionsState extends State<ArchitectBuildingSectionsScreen> {
  String? _sectionId;
  String? get sectionId => _sectionId;
  set sectionId(String? value) {
    _sectionId = value;
    widget.onViewSelected?.call(value);
  }

  String? selectedDetail;
  String? selectedRoofId;
  bool movingRoofVertically = false;
  double? _roofDragStartLocalY;
  double? _roofDragInitialOffset;
  Offset? firstPoint, secondPoint;
  bool editingCut = false,
      placingDetail = false,
      movingDetail = false,
      reattaching = false;
  ({String slabId, double station, double z})? picked;
  final transform = TransformationController();
  ArchitectProject get project => widget.controller.project;
  ArchitectSection? get cut =>
      project.sections.where((s) => s.id == sectionId).firstOrNull;
  ArchitectBuildingSection? cachedGeometry;
  ArchitectProject? cachedProject;
  ArchitectSection? cachedCut;

  @override
  void initState() {
    super.initState();
    sectionId =
        project.sections
            .where((e) => e.id == widget.initialSelectedId)
            .firstOrNull
            ?.id ??
        project.sections.firstOrNull?.id;
    editingCut = sectionId == null;
    widget.controller.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    setState(() {
      if (cut == null && !editingCut) {
        sectionId = project.sections.firstOrNull?.id;
        editingCut = sectionId == null;
      }
      if (selectedDetail != null &&
          cut?.details.any((d) => d.id == selectedDetail) != true) {
        selectedDetail = null;
        movingDetail = false;
        reattaching = false;
      }
      if (selectedRoofId != null &&
          ArchitectBuildingSection.findRoofById(project, selectedRoofId!) ==
              null) {
        selectedRoofId = null;
        movingRoofVertically = false;
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    transform.dispose();
    super.dispose();
  }

  void update(ArchitectSection value) {
    widget.controller.commit(
      project.copyWith(
        sections: [
          for (final s in project.sections)
            if (s.id == value.id) value else s,
          if (!project.sections.any((s) => s.id == value.id)) value,
        ],
      ),
    );
  }

  ArchitectBuildingSection geometry(ArchitectSection value) {
    if (!identical(cachedProject, project) || !identical(cachedCut, value)) {
      cachedGeometry = ArchitectBuildingSection.build(project, value);
      cachedProject = project;
      cachedCut = value;
    }
    return cachedGeometry!;
  }

  void resetModes() {
    picked = null;
    placingDetail = false;
    movingDetail = false;
    reattaching = false;
    selectedDetail = null;
    selectedRoofId = null;
    movingRoofVertically = false;
  }

  void _updateRoof(
    String roofId,
    ArchitectRoofPlane Function(ArchitectStorey storey, ArchitectRoofPlane roof)
    updater,
  ) {
    final hit = ArchitectBuildingSection.findRoofById(project, roofId);
    if (hit == null) return;
    final nextRoof = updater(hit.storey, hit.roof);
    widget.controller.execute(
      UpdateArchitectRoofPlane(storeyId: hit.storey.id, roof: nextRoof),
    );
  }

  void _snapRoofToWalls(String roofId) {
    _updateRoof(roofId, (storey, roof) {
      final sorted = [...project.storeys]
        ..sort((a, b) => a.elevation.compareTo(b.elevation));
      final idx = sorted.indexWhere((s) => s.id == storey.id);
      final lower = idx > 0 ? sorted[idx - 1] : null;
      final resolvedOffset =
          ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
            roof: roof,
            storey: storey,
            lowerStorey: lower,
          );
      return roof.copyWith(
        attachToWalls: true,
        baseElevationOffset: resolvedOffset,
      );
    });
  }

  void _flipRoofSlope(String roofId) {
    _updateRoof(roofId, (_, roof) => roof.flippedSlope());
  }

  void _deleteRoof(String roofId) {
    final hit = ArchitectBuildingSection.findRoofById(project, roofId);
    if (hit == null) return;
    widget.controller.execute(
      DeleteArchitectRoofPlane(storeyId: hit.storey.id, roofId: hit.roof.id),
    );
    setState(() {
      if (selectedRoofId == roofId) {
        selectedRoofId = null;
        movingRoofVertically = false;
      }
    });
  }

  Future<void> _openRoofProperties(String roofId) async {
    final hit = ArchitectBuildingSection.findRoofById(project, roofId);
    if (hit == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectRoofLayersDialog(
        initialAssembly: hit.roof.assembly,
        initialSlopeDegrees: hit.roof.slopeDegrees,
        initialEavesOverhang: hit.roof.eavesOverhang,
        initialEavesCut: hit.roof.eavesCut,
        initialBaseElevationOffset: hit.roof.baseElevationOffset,
        initialAttachToWalls: hit.roof.attachToWalls,
        onApply: (res) {
          _updateRoof(roofId, (st, r) {
            var nextOffset = res.baseElevationOffset;
            if (res.attachToWalls && !r.attachToWalls) {
              final sorted = [...project.storeys]
                ..sort((a, b) => a.elevation.compareTo(b.elevation));
              final idx = sorted.indexWhere((s) => s.id == st.id);
              final lower = idx > 0 ? sorted[idx - 1] : null;
              nextOffset =
                  ArchitectRoofGeometry.resolveAttachedBaseElevationOffset(
                    roof: r.copyWith(
                      assembly: res.assembly,
                      slopeDegrees: res.slopeDegrees,
                      eavesOverhang: res.eavesOverhang,
                      eavesCut: res.eavesCut,
                    ),
                    storey: st,
                    lowerStorey: lower,
                  );
            }
            return r.copyWith(
              assembly: res.assembly,
              slopeDegrees: res.slopeDegrees,
              eavesOverhang: res.eavesOverhang,
              eavesCut: res.eavesCut,
              baseElevationOffset: nextOffset,
              attachToWalls: res.attachToWalls,
            );
          });
        },
      ),
    );
  }

  Future<void> _showRoofContextMenu(
    Offset globalPosition,
    String roofId,
  ) async {
    final l = context.l10n;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
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
    switch (action) {
      case 'move_vertical':
        setState(() {
          selectedRoofId = roofId;
          movingRoofVertically = true;
        });
      case 'snap_walls':
        _snapRoofToWalls(roofId);
      case 'properties':
        await _openRoofProperties(roofId);
      case 'flip_slope':
        _flipRoofSlope(roofId);
      case 'delete':
        _deleteRoof(roofId);
    }
  }

  void historyAction({bool redo = false}) {
    setState(() {
      firstPoint = secondPoint = null;
      editingCut = false;
      resetModes();
    });
    if (redo) {
      widget.controller.redo();
    } else {
      widget.controller.undo();
    }
  }

  void planTap(Offset point) {
    if (!editingCut) return;
    if (firstPoint == null) {
      setState(() => firstPoint = point);
      return;
    }
    if ((point - firstPoint!).distance < .01) return;
    if (secondPoint == null) {
      setState(() => secondPoint = point);
      return;
    }
    final axis = secondPoint! - firstPoint!;
    final normal = Offset(-axis.dy, axis.dx);
    final side = point - (firstPoint! + secondPoint!) / 2;
    final dot = normal.dx * side.dx + normal.dy * side.dy;
    if (dot.abs() / axis.distance < .01) return;
    var next =
        cut?.copyWith(start: firstPoint, end: secondPoint) ??
        ArchitectSection(
          id: ArchitectElementId.next('section'),
          start: firstPoint!,
          end: secondPoint!,
        );
    if (dot < 0) next = next.reversed();
    sectionId = next.id;
    update(next);
    setState(() {
      firstPoint = secondPoint = null;
      editingCut = false;
      resetModes();
      transform.value = Matrix4.identity();
    });
  }

  void sectionTap(Offset point, double scale, ArchitectSectionDrawing drawing) {
    final value = cut;
    if (value == null) return;
    final data = geometry(value);
    if (movingDetail && selectedDetail != null) {
      final detail = value.details.firstWhere((d) => d.id == selectedDetail);
      final layout = drawing._detailLayout(detail);
      update(
        value.copyWith(
          details: [
            for (final d in value.details)
              d.id == selectedDetail
                  ? d.copyWith(textOffset: point - layout.anchor)
                  : d,
          ],
        ),
      );
      setState(() => movingDetail = false);
      return;
    }
    if (placingDetail || reattaching) {
      if (picked == null) {
        final id = data.pickSlab(point, 8 / scale);
        if (id != null) {
          var station = point.dx.clamp(0, value.length).toDouble();
          for (final floor in project.storeys) {
            for (final slab in floor.slabs.where((s) => s.id == id)) {
              final spans = ArchitectSlabGeometry.intervals(floor, slab, value);
              if (spans.isNotEmpty) {
                station = spans
                    .map(
                      (s) => station.clamp(s.$1 + 1e-8, s.$2 - 1e-8).toDouble(),
                    )
                    .reduce(
                      (a, b) =>
                          (a - point.dx).abs() < (b - point.dx).abs() ? a : b,
                    );
              }
            }
          }
          setState(() => picked = (slabId: id, station: station, z: point.dy));
        }
      } else {
        final pick = picked!;
        final candidate = ArchitectSlabDetail(
          id: selectedDetail ?? ArchitectElementId.next('detail'),
          slabId: pick.slabId,
          station: pick.station,
          fallbackElevation: pick.z,
        );
        final source = ArchitectBuildingSection.source(
          project,
          value,
          candidate,
        );
        final roofSource = source == null
            ? ArchitectBuildingSection.roofSource(project, value, candidate)
            : null;
        if (source == null && roofSource == null) {
          setState(() => picked = null);
          return;
        }
        final Offset anchor;
        if (source != null) {
          final surfaces = ArchitectSlabGeometry.surfaces(
            project,
            source.storey,
            source.slab,
          );
          anchor = Offset(
            pick.station,
            surfaces.first.topAt(value.pointAt(pick.station)),
          );
        } else {
          final r = roofSource!;
          anchor = Offset(
            pick.station,
            r.storey.elevation +
                r.roof.topElevationAt(value.pointAt(pick.station)),
          );
        }
        final old = value.details
            .where((d) => d.id == selectedDetail)
            .firstOrNull;
        final next = candidate.copyWith(
          textOffset: reattaching && old != null
              ? old.textOffset
              : point - anchor,
        );
        update(
          value.copyWith(
            details: [
              for (final d in value.details)
                if (d.id != next.id) d,
              next,
            ],
          ),
        );
        setState(() {
          resetModes();
          selectedDetail = next.id;
        });
      }
      return;
    }
    for (final d in value.details.reversed) {
      if (drawing._detailLayout(d).bounds.inflate(8 / scale).contains(point)) {
        setState(() {
          selectedDetail = d.id;
          selectedRoofId = null;
          movingRoofVertically = false;
        });
        return;
      }
    }
    final roofHit = data.pickRoof(point, 10 / scale);
    if (roofHit != null) {
      setState(() {
        selectedDetail = null;
        selectedRoofId = roofHit;
      });
      return;
    }
    setState(() {
      selectedDetail = null;
      selectedRoofId = null;
      movingRoofVertically = false;
    });
  }

  Future<void> rename() async {
    final value = cut;
    if (value == null) return;
    var input = value.name;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.architectPropertyName),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          onChanged: (v) => input = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, input.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (mounted && result != null) update(value.copyWith(name: result));
  }

  Widget planPreview() => ArchitectViewPlan(
    project: project,
    surfaceKey: 'building-section-plan',
    first: firstPoint,
    second: secondPoint,
    placing: editingCut,
    selectedSection: sectionId,
    onPoint: planTap,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, value = cut;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.buildingSections),
        actions: [
          IconButton(
            tooltip: l.architectZoneUndoAction,
            onPressed: widget.controller.canUndo ? historyAction : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: l.architectZoneRedoAction,
            onPressed: widget.controller.canRedo
                ? () => historyAction(redo: true)
                : null,
            icon: const Icon(Icons.redo),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'new') {
                setState(() {
                  sectionId = null;
                  editingCut = true;
                  firstPoint = secondPoint = null;
                  resetModes();
                });
              }
              if (action == 'cut') {
                setState(() {
                  editingCut = true;
                  firstPoint = secondPoint = null;
                  resetModes();
                });
              }
              if (action == 'name') rename();
              if (action == 'flip' && value != null) {
                setState(() {
                  firstPoint = secondPoint = null;
                  editingCut = false;
                  resetModes();
                });
                update(value.reversed());
                transform.value = Matrix4.identity();
              }
              if (action == 'delete' && value != null) {
                widget.controller.commit(
                  project.copyWith(
                    sections: project.sections
                        .where((s) => s.id != value.id)
                        .toList(),
                  ),
                );
                setState(() {
                  sectionId = project.sections.firstOrNull?.id;
                  firstPoint = secondPoint = null;
                  editingCut = sectionId == null;
                  resetModes();
                });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'new', child: Text(l.buildingSectionNew)),
              if (value != null) ...[
                PopupMenuItem(
                  value: 'flip',
                  child: Text(l.architectFacadeReverse),
                ),
                PopupMenuItem(value: 'cut', child: Text(l.buildingSectionCut)),
                PopupMenuItem(
                  value: 'name',
                  child: Text(l.architectPropertyName),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.slabSectionDelete),
                ),
              ],
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (project.sections.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value?.id,
                  hint: Text(l.buildingSectionNew),
                  items: [
                    for (var i = 0; i < project.sections.length; i++)
                      DropdownMenuItem(
                        value: project.sections[i].id,
                        child: Text(
                          project.sections[i].name.isEmpty
                              ? '${l.buildingSection} ${i + 1}'
                              : project.sections[i].name,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    sectionId = id;
                    editingCut = false;
                    firstPoint = secondPoint = null;
                    resetModes();
                    transform.value = Matrix4.identity();
                  }),
                ),
              ),
            if (editingCut)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          firstPoint == null
                              ? l.architectSectionStartHint
                              : secondPoint == null
                              ? l.architectViewEndHint
                              : l.architectViewDirectionHint,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          editingCut = false;
                          firstPoint = secondPoint = null;
                          sectionId ??= project.sections.firstOrNull?.id;
                        }),
                        child: Text(l.cancel),
                      ),
                    ],
                  ),
                ),
              ),
            if (editingCut)
              Expanded(child: planPreview())
            else
              SizedBox(
                height: math.min(220, MediaQuery.sizeOf(context).height * .25),
                child: planPreview(),
              ),
            if (value != null && !editingCut)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    key: const ValueKey('section-add-slab-detail'),
                    onPressed: () => setState(() {
                      resetModes();
                      placingDetail = true;
                      editingCut = false;
                    }),
                    icon: const Icon(Icons.format_list_numbered),
                    label: Text(l.slabDetail),
                  ),
                  IconButton(
                    tooltip: l.stairSectionReset,
                    onPressed: () => transform.value = Matrix4.identity(),
                    icon: const Icon(Icons.fit_screen),
                  ),
                  if (selectedRoofId != null) ...[
                    TextButton.icon(
                      key: const ValueKey('section-roof-snap-walls'),
                      onPressed: () => _snapRoofToWalls(selectedRoofId!),
                      icon: const Icon(Icons.vertical_align_bottom, size: 18),
                      label: Text(l.architectRoofSnapToWallsAction),
                    ),
                    TextButton.icon(
                      key: const ValueKey('section-roof-properties'),
                      onPressed: () => _openRoofProperties(selectedRoofId!),
                      icon: const Icon(Icons.layers_outlined, size: 18),
                      label: Text(l.architectRoofPropertiesAction),
                    ),
                    IconButton(
                      tooltip: l.architectRoofFlipSlope,
                      onPressed: () => _flipRoofSlope(selectedRoofId!),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                    ),
                    IconButton(
                      tooltip: l.delete,
                      onPressed: () => _deleteRoof(selectedRoofId!),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                  if (selectedDetail != null)
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        final d = value.details.firstWhere(
                          (d) => d.id == selectedDetail,
                        );
                        if (action == 'move') {
                          setState(() => movingDetail = true);
                        }
                        if (action == 'reattach') {
                          setState(() {
                            reattaching = true;
                            picked = null;
                          });
                        }
                        if (action == 'flip') {
                          update(
                            value.copyWith(
                              details: [
                                for (final x in value.details)
                                  x.id == d.id
                                      ? x.copyWith(
                                          textOffset: Offset(
                                            -x.textOffset.dx,
                                            x.textOffset.dy,
                                          ),
                                        )
                                      : x,
                              ],
                            ),
                          );
                        }
                        if (action == 'delete') {
                          update(
                            value.copyWith(
                              details: value.details
                                  .where((x) => x.id != d.id)
                                  .toList(),
                            ),
                          );
                          setState(resetModes);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'move',
                          child: Text(l.slabDetailMove),
                        ),
                        PopupMenuItem(
                          value: 'flip',
                          child: Text(l.slabDetailSide),
                        ),
                        PopupMenuItem(
                          value: 'reattach',
                          child: Text(l.slabDetailReattach),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l.slabDetailRemove),
                        ),
                      ],
                    ),
                  if (placingDetail ||
                      movingDetail ||
                      reattaching ||
                      movingRoofVertically)
                    TextButton(
                      onPressed: () => setState(resetModes),
                      child: Text(l.cancel),
                    ),
                ],
              ),
            if (placingDetail || reattaching || movingDetail)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  picked != null || movingDetail
                      ? l.slabDetailMove
                      : l.slabDetailPick,
                ),
              ),
            const Divider(height: 1),
            if (!editingCut)
              Expanded(
                child: value == null
                    ? Center(child: Text(l.buildingSectionHint))
                    : LayoutBuilder(
                        builder: (_, c) {
                          final data = geometry(value);
                          final drawing = ArchitectSectionDrawing(
                            project,
                            value,
                            data,
                            l,
                            colors,
                            selectedDetail,
                            Theme.of(context).textTheme.bodyMedium?.fontFamily,
                            selectedRoofId,
                          );
                          final bounds = drawing.bounds.inflate(.8);
                          final scale = math.min(
                            c.maxWidth / math.max(bounds.width, .1),
                            c.maxHeight / math.max(bounds.height, .1),
                          );
                          final centre = Offset(
                            c.maxWidth / 2,
                            c.maxHeight / 2,
                          );
                          Offset localToSection(Offset localPos) =>
                              bounds.center +
                              Offset(
                                (localPos.dx - centre.dx) / scale,
                                -(localPos.dy - centre.dy) / scale,
                              );
                          return ColoredBox(
                            color: colors.surface,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                InteractiveViewer(
                                  transformationController: transform,
                                  minScale: .5,
                                  maxScale: 16,
                                  panEnabled: selectedRoofId == null,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'building-section-view',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (d) {
                                      sectionTap(
                                        localToSection(d.localPosition),
                                        scale,
                                        drawing,
                                      );
                                    },
                                    onSecondaryTapUp: (d) {
                                      final p = localToSection(d.localPosition);
                                      final hitRoof =
                                          data.pickRoof(p, 14 / scale) ??
                                          selectedRoofId;
                                      if (hitRoof != null) {
                                        setState(() {
                                          selectedDetail = null;
                                          selectedRoofId = hitRoof;
                                        });
                                        _showRoofContextMenu(
                                          d.globalPosition,
                                          hitRoof,
                                        );
                                      }
                                    },
                                    onLongPressStart: (d) {
                                      final p = localToSection(d.localPosition);
                                      final hitRoof =
                                          data.pickRoof(p, 14 / scale) ??
                                          selectedRoofId;
                                      if (hitRoof != null) {
                                        setState(() {
                                          selectedDetail = null;
                                          selectedRoofId = hitRoof;
                                        });
                                        _showRoofContextMenu(
                                          d.globalPosition,
                                          hitRoof,
                                        );
                                      }
                                    },
                                    onVerticalDragStart: selectedRoofId == null
                                        ? null
                                        : (d) {
                                            final hit =
                                                ArchitectBuildingSection.findRoofById(
                                                  project,
                                                  selectedRoofId!,
                                                );
                                            if (hit == null) return;
                                            _roofDragStartLocalY =
                                                d.localPosition.dy;
                                            _roofDragInitialOffset =
                                                hit.roof.baseElevationOffset;
                                          },
                                    onVerticalDragUpdate: selectedRoofId == null
                                        ? null
                                        : (d) {
                                            if (_roofDragStartLocalY == null ||
                                                _roofDragInitialOffset ==
                                                    null ||
                                                selectedRoofId == null) {
                                              return;
                                            }
                                            final deltaZ =
                                                -(d.localPosition.dy -
                                                    _roofDragStartLocalY!) /
                                                scale;
                                            final nextOffset =
                                                _roofDragInitialOffset! +
                                                deltaZ;
                                            _updateRoof(
                                              selectedRoofId!,
                                              (_, roof) => roof.copyWith(
                                                baseElevationOffset: nextOffset,
                                                attachToWalls: false,
                                              ),
                                            );
                                          },
                                    onVerticalDragEnd: selectedRoofId == null
                                        ? null
                                        : (_) {
                                            _roofDragStartLocalY = null;
                                            _roofDragInitialOffset = null;
                                          },
                                    child: CustomPaint(
                                      size: Size(c.maxWidth, c.maxHeight),
                                      painter: ArchitectBuildingSectionPainter(
                                        drawing,
                                        bounds.center,
                                        scale,
                                      ),
                                    ),
                                  ),
                                ),
                                if (!placingDetail &&
                                    !movingDetail &&
                                    !reattaching &&
                                    selectedDetail == null)
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: transform,
                                      builder: (_, _) =>
                                          ArchitectProjectionEditor(
                                            key: ValueKey(
                                              'section-editor:${value.id}',
                                            ),
                                            controller: widget.controller,
                                            paths: data.elementPaths,
                                            roofProfiles: data.roofProfiles,
                                            origin: value.start,
                                            right: value.axis,
                                            elevation: false,
                                            scale:
                                                scale *
                                                transform.value
                                                    .getMaxScaleOnAxis(),
                                            toView: (p) => localToSection(
                                              transform.toScene(p),
                                            ),
                                            toScreen: (p) =>
                                                MatrixUtils.transformPoint(
                                                  transform.value,
                                                  centre +
                                                      Offset(
                                                        (p.dx -
                                                                bounds
                                                                    .center
                                                                    .dx) *
                                                            scale,
                                                        -(p.dy -
                                                                bounds
                                                                    .center
                                                                    .dy) *
                                                            scale,
                                                      ),
                                                ),
                                            onNavigate:
                                                (delta, factor, focal) =>
                                                    navigateArchitectProjection(
                                                      transform,
                                                      delta,
                                                      factor,
                                                      focal,
                                                    ),
                                            onMissTap: (p) => sectionTap(
                                              localToSection(
                                                transform.toScene(p),
                                              ),
                                              scale,
                                              drawing,
                                            ),
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailLayout {
  final Offset anchor, text;
  final List<String> rows;
  final Rect bounds;
  final bool lost;
  final int? number;
  final double rowHeight, textHeight, bottom;
  const _DetailLayout(
    this.anchor,
    this.text,
    this.rows,
    this.bounds,
    this.lost,
    this.number,
    this.rowHeight,
    this.textHeight,
    this.bottom,
  );
}

class ArchitectSectionDrawing {
  final ArchitectProject project;
  final ArchitectSection cut;
  final ArchitectBuildingSection data;
  final AppLocalizations l;
  final ColorScheme colors;
  final String? selected;
  final String? fontFamily;
  final String? selectedRoofId;
  ArchitectSectionDrawing(
    this.project,
    this.cut,
    this.data,
    this.l,
    this.colors,
    this.selected,
    this.fontFamily, [
    this.selectedRoofId,
  ]);
  double get textHeight => project.dimensionScale.textHeight;
  _DetailLayout _detailLayout(ArchitectSlabDetail detail) {
    final source = ArchitectBuildingSection.source(project, cut, detail);
    final roofSource = source == null
        ? ArchitectBuildingSection.roofSource(project, cut, detail)
        : null;
    final point = cut.pointAt(detail.station);
    final surfaces = source == null
        ? <SlabLayerSurface>[]
        : ArchitectSlabGeometry.surfaces(project, source.storey, source.slab);
    final double z;
    final double bottomZ;
    if (surfaces.isNotEmpty) {
      z = surfaces.first.topAt(point);
      bottomZ = surfaces.last.bottomAt(point);
    } else if (roofSource != null) {
      z = roofSource.storey.elevation + roofSource.roof.topElevationAt(point);
      bottomZ =
          roofSource.storey.elevation +
          roofSource.roof.undersideElevationAt(point);
    } else {
      z = detail.fallbackElevation;
      bottomZ = z;
    }
    final anchor = Offset(detail.station, z);
    var text = anchor + detail.textOffset;
    final rows = <String>[];
    for (final surface in surfaces) {
      final layer = surface.layer;
      var value = formatSlabThickness(surface.thicknessAt(point));
      if (layer.slopePercent > 0) {
        final depths = source!.slab.polygon.map(surface.thicknessAt).toList();
        value =
            '${formatSlabThickness(depths.reduce(math.min))}–'
            '${formatSlabThickness(depths.reduce(math.max))} '
            '(${l.slabDetailHere} $value; ${layer.slopePercent}%)';
      }
      rows.add('${layer.label(l)} — $value');
    }
    if (roofSource != null) {
      final roof = roofSource.roof;
      final timber = roof.assembly.timber;
      for (final layer in roof.assembly.layers) {
        if (layer.role == ArchitectRoofLayerRole.battens && timber.hasBattens) {
          rows.add(
            '${l.architectRoofBattensLabel} ${(timber.battenWidth * 100).round()}×${(timber.battenHeight * 100).round()} cm @ ${(timber.battenSpacing * 100).round()} cm',
          );
        } else if (layer.role == ArchitectRoofLayerRole.counterBattens &&
            timber.hasCounterBattens) {
          rows.add(
            '${l.architectRoofCounterBattensLabel} ${(timber.counterBattenWidth * 100).round()}×${(timber.counterBattenHeight * 100).round()} cm',
          );
        } else if (layer.role == ArchitectRoofLayerRole.rafters &&
            timber.hasRafters) {
          rows.add(
            '${l.architectRoofRaftersLabel} ${(timber.rafterWidth * 100).round()}×${(timber.rafterHeight * 100).round()} cm @ ${(timber.rafterSpacing * 100).round()} cm',
          );
        } else {
          rows.add(
            '${layer.material.label(l)} — ${formatSlabThickness(layer.thickness)}',
          );
        }
      }
      if (timber.hasWallPlate) {
        rows.add(
          '${l.architectRoofWallPlateLabel} ${(timber.wallPlateWidth * 100).round()}×${(timber.wallPlateHeight * 100).round()} cm',
        );
      }
      if (timber.hasRingBeam) {
        rows.add(
          '${l.architectRoofRingBeamLabel} — ${formatSlabThickness(timber.ringBeamHeight)}',
        );
      }
      if (timber.hasFasciaBoard) {
        rows.add(
          '${l.architectRoofFasciaLabel} ${(timber.fasciaThickness * 100).toStringAsFixed(1)} cm',
        );
      }
      if (timber.hasMetalFlashing) {
        rows.add(l.architectRoofMetalFlashingLabel);
      }
    }
    if (source == null && roofSource == null) rows.add(l.slabDetailLost);
    final row = textHeight * 1.65;
    if (text.dy >= anchor.dy && text.dy - rows.length * row < anchor.dy) {
      text = Offset(text.dx, anchor.dy + rows.length * row);
    }
    var width = 0.0;
    for (final line in rows) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(fontSize: textHeight, fontFamily: fontFamily),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      width = math.max(width, painter.width);
    }
    final left = detail.textOffset.dx >= 0 ? text.dx : text.dx - width;
    final bounds = Rect.fromLTRB(
      math.min(left, anchor.dx) - row,
      math.min(bottomZ, text.dy - rows.length * row) - row,
      math.max(left + width, anchor.dx) + row,
      math.max(z, text.dy) + row * 2,
    );
    return _DetailLayout(
      anchor,
      Offset(left, text.dy),
      rows,
      bounds,
      source == null && roofSource == null,
      source != null
          ? ArchitectSlabAssemblies.number(project, source.slab)
          : (roofSource != null ? 1 : null),
      row,
      textHeight,
      bottomZ,
    );
  }

  Rect get bounds {
    var b = data.bounds;
    for (final d in cut.details) {
      b = b.expandToInclude(_detailLayout(d).bounds);
    }
    return b;
  }
}

class ArchitectBuildingSectionPainter extends CustomPainter {
  final ArchitectSectionDrawing drawing;
  final Offset centre;
  final double scale;
  ArchitectBuildingSectionPainter(this.drawing, this.centre, this.scale);
  @override
  void paint(Canvas canvas, Size size) {
    final color = drawing.colors.onSurface;
    Offset p(Offset v) => Offset(
      size.width / 2 + (v.dx - centre.dx) * scale,
      size.height / 2 - (v.dy - centre.dy) * scale,
    );
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, -scale)
      ..setEntry(0, 3, size.width / 2 - centre.dx * scale)
      ..setEntry(1, 3, size.height / 2 + centre.dy * scale);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final region in drawing.data.drawingRegions) {
      final path = region.path.transform(matrix.storage);
      final isSelectedRoof =
          drawing.selectedRoofId != null &&
          region.slabId == drawing.selectedRoofId;
      final fillColor =
          region.customFillColor ??
          ArchitectSlabGeometry.materialColor(region.material);
      canvas.drawPath(path, Paint()..color = fillColor.withValues(alpha: .72));
      canvas.drawPath(
        path,
        Paint()
          ..color = isSelectedRoof ? drawing.colors.primary : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelectedRoof
              ? 1.5
              : (region.material == SlabMaterial.concrete ||
                        region.timberCrossSectionPolygon != null
                    ? 1.1
                    : .65),
      );
      if (region.timberCrossSectionPolygon != null &&
          region.timberCrossSectionPolygon!.length == 4) {
        final pts = region.timberCrossSectionPolygon!.map(p).toList();
        final diagPaint = Paint()
          ..color = (isSelectedRoof ? drawing.colors.primary : color)
              .withValues(alpha: 0.65)
          ..strokeWidth = 0.65;
        canvas.drawLine(pts[0], pts[2], diagPaint);
        canvas.drawLine(pts[1], pts[3], diagPaint);
      } else if (region.path.getBounds().height * scale > 4) {
        canvas.save();
        canvas.clipPath(path);
        final b = path.getBounds();
        for (var x = b.left - b.height; x < b.right; x += 9) {
          canvas.drawLine(
            Offset(x, b.bottom),
            Offset(x + b.height, b.top),
            Paint()
              ..color = color.withValues(alpha: .25)
              ..strokeWidth = .5,
          );
        }
        canvas.restore();
      }
    }
    void text(
      String value,
      Offset at,
      double height,
      Color c, {
      bool centred = false,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: height,
            color: c,
            fontFamily: drawing.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        at -
            (centred
                ? Offset(tp.width / 2, tp.height / 2)
                : Offset(0, tp.height)),
      );
    }

    if (drawing.selectedRoofId != null) {
      final rb = drawing.data.roofBounds(drawing.selectedRoofId!);
      if (rb != null) {
        final handleScreen =
            p(Offset(rb.center.dx, rb.bottom)) + const Offset(0, -16);
        canvas.drawCircle(
          handleScreen,
          12,
          Paint()..color = drawing.colors.primaryContainer,
        );
        canvas.drawCircle(
          handleScreen,
          12,
          Paint()
            ..color = drawing.colors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        text(
          '⇅',
          handleScreen,
          13,
          drawing.colors.onPrimaryContainer,
          centred: true,
        );
      }
    }

    for (final floor in drawing.project.storeys) {
      final a = p(Offset(0, floor.elevation)),
          b = p(Offset(drawing.cut.length, floor.elevation));
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: .25)
          ..strokeWidth = .5,
      );
      text(
        floor.elevationLabel,
        a + const Offset(2, -2),
        math.max(9, drawing.textHeight * scale),
        color,
      );
    }
    if (drawing.data.regions.isEmpty) {
      text(
        drawing.l.buildingSectionEmpty,
        Offset(size.width / 2, size.height / 2),
        14,
        color,
        centred: true,
      );
    }
    for (final detail in drawing.cut.details) {
      final d = drawing._detailLayout(detail);
      final c = d.lost
          ? drawing.colors.error
          : detail.id == drawing.selected
          ? drawing.colors.primary
          : color;
      final paint = Paint()
        ..color = c
        ..strokeWidth = 1;
      final top = math.max(d.anchor.dy, d.text.dy + d.rowHeight);
      final bottom = math.min(
        d.bottom,
        d.text.dy - d.rows.length * d.rowHeight,
      );
      canvas.drawLine(
        p(Offset(d.anchor.dx, bottom)),
        p(Offset(d.anchor.dx, top)),
        paint,
      );
      final radius = d.rowHeight * .45;
      final circle = Offset(d.anchor.dx, top + radius);
      canvas.drawCircle(
        p(circle),
        radius * scale,
        paint..style = PaintingStyle.stroke,
      );
      text(
        d.number?.toString() ?? '?',
        p(circle),
        d.textHeight * scale,
        c,
        centred: true,
      );
      for (var i = 0; i < d.rows.length; i++) {
        final y = d.text.dy - i * d.rowHeight;
        final at = p(Offset(d.text.dx, y));
        final right = detail.textOffset.dx >= 0;
        final tp = TextPainter(
          text: TextSpan(
            text: d.rows[i],
            style: TextStyle(
              fontSize: d.textHeight * scale,
              color: c,
              fontFamily: drawing.fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lineEnd = right ? at + Offset(tp.width, 0) : at;
        canvas.drawLine(p(Offset(d.anchor.dx, y)), lineEnd, paint);
        tp.paint(canvas, at - Offset(0, tp.height + 2));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectBuildingSectionPainter oldDelegate) =>
      true;
}
