import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../services/architect_building_section.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_slab_assemblies.dart';
import '../services/architect_slab_geometry.dart';
import 'architect_slab_labels.dart';

/// Uses the workspace controller so changes, autosave and history remain live.
class ArchitectBuildingSectionsScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  const ArchitectBuildingSectionsScreen({super.key, required this.controller});
  @override
  State<ArchitectBuildingSectionsScreen> createState() =>
      _BuildingSectionsState();
}

class _BuildingSectionsState extends State<ArchitectBuildingSectionsScreen> {
  String? sectionId, selectedDetail;
  Offset? firstPoint;
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
    sectionId = project.sections.firstOrNull?.id;
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
  }

  void planTap(Offset point) {
    if (!editingCut) return;
    if (firstPoint == null) {
      setState(() => firstPoint = point);
      return;
    }
    if ((point - firstPoint!).distance < .01) return;
    final next =
        cut?.copyWith(start: firstPoint, end: point) ??
        ArchitectSection(
          id: ArchitectElementId.next('section'),
          start: firstPoint!,
          end: point,
        );
    sectionId = next.id;
    update(next);
    setState(() {
      firstPoint = null;
      editingCut = false;
      resetModes();
      transform.value = Matrix4.identity();
    });
  }

  void sectionTap(Offset point, double scale, _SectionDrawing drawing) {
    final value = cut;
    if (value == null) return;
    final data = geometry(value);
    if (movingDetail && selectedDetail != null) {
      final detail = value.details.firstWhere((d) => d.id == selectedDetail);
      final layout = drawing.detailLayout(detail);
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
        if (source == null) {
          setState(() => picked = null);
          return;
        }
        final surfaces = ArchitectSlabGeometry.surfaces(
          project,
          source.storey,
          source.slab,
        );
        final anchor = Offset(
          pick.station,
          surfaces.first.topAt(value.pointAt(pick.station)),
        );
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
      if (drawing.detailLayout(d).bounds.inflate(8 / scale).contains(point)) {
        setState(() => selectedDetail = d.id);
        return;
      }
    }
    setState(() => selectedDetail = null);
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
            onPressed: widget.controller.canUndo
                ? widget.controller.undo
                : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: l.architectZoneRedoAction,
            onPressed: widget.controller.canRedo
                ? widget.controller.redo
                : null,
            icon: const Icon(Icons.redo),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'new') {
                setState(() {
                  sectionId = null;
                  editingCut = true;
                  firstPoint = null;
                  resetModes();
                });
              }
              if (action == 'cut') {
                setState(() {
                  editingCut = true;
                  firstPoint = null;
                  resetModes();
                });
              }
              if (action == 'name') rename();
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
                  resetModes();
                });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'new', child: Text(l.buildingSectionNew)),
              if (value != null) ...[
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
                    firstPoint = null;
                    resetModes();
                    transform.value = Matrix4.identity();
                  }),
                ),
              ),
            if (editingCut)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l.buildingSectionHint),
              ),
            SizedBox(
              height: math.min(200, MediaQuery.sizeOf(context).height * .23),
              child: LayoutBuilder(
                builder: (_, c) {
                  final points = [
                    for (final s in project.storeys) ...[
                      for (final slab in s.slabs) ...slab.polygon,
                      for (final wall in s.walls) ...wall.polygonCorners,
                    ],
                    if (value != null) ...[value.start, value.end],
                    ?firstPoint,
                  ];
                  final bounds = points.isEmpty
                      ? const Rect.fromLTWH(-5, -5, 10, 10)
                      : (Path()..addPolygon(points, false)).getBounds().inflate(
                          1,
                        );
                  final scale = math.min(
                    c.maxWidth / bounds.width,
                    c.maxHeight / bounds.height,
                  );
                  return GestureDetector(
                    key: const ValueKey('building-section-plan'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => planTap(
                      bounds.center +
                          (d.localPosition -
                                  Offset(c.maxWidth / 2, c.maxHeight / 2)) /
                              scale,
                    ),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _BuildingPlan(
                        project,
                        value,
                        firstPoint,
                        bounds.center,
                        scale,
                        colors,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (value != null)
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
                  if (placingDetail || movingDetail || reattaching)
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
            Expanded(
              child: value == null
                  ? Center(child: Text(l.buildingSectionHint))
                  : LayoutBuilder(
                      builder: (_, c) {
                        final data = geometry(value);
                        final drawing = _SectionDrawing(
                          project,
                          value,
                          data,
                          l,
                          colors,
                          selectedDetail,
                          Theme.of(context).textTheme.bodyMedium?.fontFamily,
                        );
                        final bounds = drawing.bounds.inflate(.8);
                        final scale = math.min(
                          c.maxWidth / math.max(bounds.width, .1),
                          c.maxHeight / math.max(bounds.height, .1),
                        );
                        final centre = Offset(c.maxWidth / 2, c.maxHeight / 2);
                        return ColoredBox(
                          color: colors.surface,
                          child: InteractiveViewer(
                            transformationController: transform,
                            minScale: .5,
                            maxScale: 16,
                            child: GestureDetector(
                              key: const ValueKey('building-section-view'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) {
                                final p =
                                    bounds.center +
                                    Offset(
                                      (d.localPosition.dx - centre.dx) / scale,
                                      -(d.localPosition.dy - centre.dy) / scale,
                                    );
                                sectionTap(p, scale, drawing);
                              },
                              child: CustomPaint(
                                size: Size(c.maxWidth, c.maxHeight),
                                painter: _BuildingSectionPainter(
                                  drawing,
                                  bounds.center,
                                  scale,
                                ),
                              ),
                            ),
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

class _SectionDrawing {
  final ArchitectProject project;
  final ArchitectSection cut;
  final ArchitectBuildingSection data;
  final AppLocalizations l;
  final ColorScheme colors;
  final String? selected;
  final String? fontFamily;
  _SectionDrawing(
    this.project,
    this.cut,
    this.data,
    this.l,
    this.colors,
    this.selected,
    this.fontFamily,
  );
  double get textHeight => project.dimensionScale.textHeight;
  _DetailLayout detailLayout(ArchitectSlabDetail detail) {
    final source = ArchitectBuildingSection.source(project, cut, detail);
    final point = cut.pointAt(detail.station);
    final surfaces = source == null
        ? <SlabLayerSurface>[]
        : ArchitectSlabGeometry.surfaces(project, source.storey, source.slab);
    final z = surfaces.isEmpty
        ? detail.fallbackElevation
        : surfaces.first.topAt(point);
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
    if (source == null) rows.add(l.slabDetailLost);
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
      math.min(
            surfaces.isEmpty ? z : surfaces.last.bottomAt(point),
            text.dy - rows.length * row,
          ) -
          row,
      math.max(left + width, anchor.dx) + row,
      math.max(z, text.dy) + row * 2,
    );
    return _DetailLayout(
      anchor,
      Offset(left, text.dy),
      rows,
      bounds,
      source == null,
      source == null
          ? null
          : ArchitectSlabAssemblies.number(project, source.slab),
      row,
      textHeight,
      surfaces.isEmpty ? z : surfaces.last.bottomAt(point),
    );
  }

  Rect get bounds {
    var b = data.bounds;
    for (final d in cut.details) {
      b = b.expandToInclude(detailLayout(d).bounds);
    }
    return b;
  }
}

class _BuildingSectionPainter extends CustomPainter {
  final _SectionDrawing drawing;
  final Offset centre;
  final double scale;
  _BuildingSectionPainter(this.drawing, this.centre, this.scale);
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
    for (final region in drawing.data.regions) {
      final path = region.path.transform(matrix.storage);
      canvas.drawPath(
        path,
        Paint()
          ..color = ArchitectSlabGeometry.materialColor(
            region.material,
          ).withValues(alpha: .65),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = region.material == SlabMaterial.concrete ? 1.3 : .6,
      );
      if (region.path.getBounds().height * scale > 4) {
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
      final d = drawing.detailLayout(detail);
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
  bool shouldRepaint(covariant _BuildingSectionPainter oldDelegate) => true;
}

class _BuildingPlan extends CustomPainter {
  final ArchitectProject project;
  final ArchitectSection? cut;
  final Offset? first;
  final Offset centre;
  final double scale;
  final ColorScheme colors;
  _BuildingPlan(
    this.project,
    this.cut,
    this.first,
    this.centre,
    this.scale,
    this.colors,
  );
  @override
  void paint(Canvas canvas, Size size) {
    Offset p(Offset v) =>
        Offset(size.width / 2, size.height / 2) + (v - centre) * scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final floor in project.storeys) {
      for (final slab in floor.slabs) {
        final path = Path()..addPolygon(slab.polygon.map(p).toList(), true);
        canvas.drawPath(
          path,
          Paint()..color = colors.primary.withValues(alpha: .08),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = colors.onSurface.withValues(alpha: .35)
            ..style = PaintingStyle.stroke,
        );
      }
      for (final wall in floor.walls) {
        canvas.drawPath(
          Path()..addPolygon(wall.polygonCorners.map(p).toList(), true),
          Paint()..color = colors.onSurface.withValues(alpha: .2),
        );
      }
    }
    for (final section in project.sections) {
      final paint = Paint()
        ..color = section.id == cut?.id
            ? colors.primary
            : colors.onSurface.withValues(alpha: .2)
        ..strokeWidth = 2;
      canvas.drawLine(p(section.start), p(section.end), paint);
      canvas.drawCircle(p(section.start), 3, paint);
      canvas.drawCircle(p(section.end), 3, paint);
    }
    if (first != null) {
      canvas.drawCircle(p(first!), 5, Paint()..color = Colors.orange);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BuildingPlan oldDelegate) => true;
}
