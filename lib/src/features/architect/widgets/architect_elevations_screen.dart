import '../rendering/architect_vector_scene.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../rendering/architect_elevation_markers.dart';
import '../services/architect_building_elevation.dart';
import '../services/architect_command_controller.dart';
import 'architect_elevation_labels.dart';
import 'architect_view_plan.dart';
import 'architect_projection_editor.dart';
import 'architect_view_depth_dialog.dart';
import '../services/architect_view_placement.dart';

enum _Placement { none, elevation, north }

/// Shares the workspace's history and autosave; orientations belong to the
/// project, not to individual storeys or to the 3D camera.
class ArchitectElevationsScreen extends StatefulWidget {
  final ArchitectCommandController controller;
  final String? initialSelectedId;
  final ValueChanged<String?>? onViewSelected;
  const ArchitectElevationsScreen({
    super.key,
    required this.controller,
    this.initialSelectedId,
    this.onViewSelected,
  });
  @override
  State<ArchitectElevationsScreen> createState() => _ElevationsState();
}

class _ElevationsState extends State<ArchitectElevationsScreen> {
  String? _selectedId;
  String? get selectedId => _selectedId;
  set selectedId(String? value) {
    _selectedId = value;
    widget.onViewSelected?.call(value);
  }

  bool plan = true;
  _Placement placement = _Placement.none;
  Offset? first, second;
  String? editingId;
  final planTransform = TransformationController();
  final elevationTransform = TransformationController();
  ArchitectProject? cachedProject;
  ArchitectElevation? cachedView;
  ArchitectBuildingElevation? cachedGeometry;
  ArchitectProject get project => widget.controller.project;
  ArchitectElevation? get selected =>
      project.elevations.where((e) => e.id == selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    selectedId =
        project.elevations
            .where((e) => e.id == widget.initialSelectedId)
            .firstOrNull
            ?.id ??
        project.elevations.firstOrNull?.id;
    if (selectedId == null) placement = _Placement.elevation;
    widget.controller.addListener(changed);
  }

  void changed() {
    if (!mounted) return;
    setState(() {
      if (selected == null) selectedId = project.elevations.firstOrNull?.id;
      if (selectedId == null) plan = true;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    planTransform.dispose();
    elevationTransform.dispose();
    super.dispose();
  }

  void begin(_Placement mode, {bool edit = false}) => setState(() {
    placement = mode;
    editingId = edit ? selectedId : null;
    first = second = null;
    plan = true;
    planTransform.value = Matrix4.identity();
  });
  void cancel() => setState(() {
    placement = _Placement.none;
    first = second = null;
    editingId = null;
  });
  void update(ArchitectElevation value) {
    selectedId = value.id;
    widget.controller.commit(
      project.copyWith(
        elevations: [
          for (final e in project.elevations)
            if (e.id == value.id) value else e,
          if (!project.elevations.any((e) => e.id == value.id)) value,
        ],
      ),
    );
    elevationTransform.value = Matrix4.identity();
  }

  void planTap(Offset point, double scale) {
    if (placement == _Placement.none) {
      final north = project.northSymbol;
      if (north != null && (point - north.position).distance < 30 / scale) {
        rotateNorth();
        return;
      }
      ArchitectElevation? hit;
      var best = 24 / scale;
      for (final e in project.elevations) {
        final delta = point - e.start;
        final t = (delta.dx * e.axis.dx + delta.dy * e.axis.dy)
            .clamp(0.0, e.length)
            .toDouble();
        final distance = (point - e.start - e.axis * t).distance;
        if (distance < best) {
          best = distance;
          hit = e;
        }
      }
      if (hit != null) setState(() => selectedId = hit!.id);
      return;
    }
    if (first == null) {
      setState(() => first = point);
      return;
    }
    if ((point - first!).distance < .01) return;
    if (placement == _Placement.north) {
      final delta = point - first!;
      widget.controller.commit(
        project.copyWith(
          northSymbol: ArchitectNorthSymbol(
            position: first!,
            angle: math.atan2(delta.dx, -delta.dy),
          ),
        ),
      );
      cancel();
      return;
    }
    if (second == null) {
      final end = point;
      if ((end - first!).distance >= .01) setState(() => second = end);
      return;
    }
    final view = ArchitectViewPlacement.resolve(first!, second!, point);
    if (view == null) return;
    final previous = project.elevations
        .where((e) => e.id == editingId)
        .firstOrNull;
    update(
      previous?.copyWith(
            start: first!,
            end: second!,
            steps: [
              for (final p in previous.steps)
                Offset(
                  p.dx * (second! - first!).distance / previous.length,
                  p.dy,
                ),
            ],
            viewSide: view.side,
            viewDepth: view.depth,
          ) ??
          ArchitectElevation(
            id: editingId ?? ArchitectElementId.next('facade'),
            start: first!,
            end: second!,
            viewSide: view.side,
            viewDepth: view.depth,
          ),
    );
    cancel();
    setState(() => plan = false);
  }

  Future<void> rotateNorth() async {
    final north = project.northSymbol;
    if (north == null) {
      begin(_Placement.north);
      return;
    }
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _NorthDialog(project: project),
    );
    if (result != null && mounted) {
      widget.controller.commit(
        project.copyWith(
          northSymbol: ArchitectNorthSymbol(
            position: north.position,
            angle: result,
          ),
        ),
      );
    }
  }

  Future<void> changeDepth() async {
    final value = selected;
    if (value == null) return;
    final result = await showArchitectViewDepth(
      context,
      project,
      value.viewDepth,
      minimumDepth:
          value.steps.fold(0.0, (double a, p) => math.max(a, p.dy)) + .01,
    );
    if (mounted && result != null) {
      update(
        value.copyWith(
          viewDepth: result.depth,
          clearViewDepth: result.depth == null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, value = selected;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.architectFacades),
        actions: [
          IconButton(
            key: const ValueKey('architect-facade-new'),
            tooltip: l.architectFacadeNew,
            onPressed: () => begin(_Placement.elevation),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            key: const ValueKey('architect-north'),
            tooltip: l.architectNorth,
            onPressed: rotateNorth,
            icon: const Icon(Icons.explore_outlined),
          ),
          IconButton(
            key: const ValueKey('architect-facade-undo'),
            tooltip: l.architectZoneUndoAction,
            onPressed: widget.controller.canUndo
                ? () {
                    cancel();
                    widget.controller.undo();
                  }
                : null,
            icon: const Icon(Icons.undo),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'edit') begin(_Placement.elevation, edit: true);
              if (action == 'depth') changeDepth();
              if (action == 'flip' && value != null) {
                update(value.copyWith(viewSide: -value.viewSide));
              }
              if (action == 'north') begin(_Placement.north);
              if (action == 'redo') {
                cancel();
                widget.controller.redo();
              }
              if (action == 'delete' && value != null) {
                cancel();
                widget.controller.commit(
                  project.copyWith(
                    elevations: project.elevations
                        .where((e) => e.id != value.id)
                        .toList(),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              if (value != null) ...[
                PopupMenuItem(
                  value: 'depth',
                  child: Text(l.architectViewDepth),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(l.architectFacadeEdit),
                ),
                PopupMenuItem(
                  value: 'flip',
                  child: Text(l.architectFacadeReverse),
                ),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
              PopupMenuItem(value: 'north', child: Text(l.architectNorthPlace)),
              PopupMenuItem(
                value: 'redo',
                enabled: widget.controller.canRedo,
                child: Text(l.architectZoneRedoAction),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: value?.id,
                      hint: Text(l.architectFacadeNew),
                      items: [
                        for (var i = 0; i < project.elevations.length; i++)
                          DropdownMenuItem(
                            value: project.elevations[i].id,
                            child: Text(
                              '${i + 1}. ${architectElevationLabel(l, project.elevations[i], project.northSymbol?.angle ?? 0)}',
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        cancel();
                        setState(() {
                          selectedId = id;
                          plan = false;
                          elevationTransform.value = Matrix4.identity();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: l.stairSectionReset,
                    onPressed: () {
                      planTransform.value = Matrix4.identity();
                      elevationTransform.value = Matrix4.identity();
                    },
                    icon: const Icon(Icons.fit_screen),
                  ),
                  TextButton(
                    key: const ValueKey('architect-facade-plan-toggle'),
                    onPressed: value == null || placement != _Placement.none
                        ? null
                        : () => setState(() => plan = !plan),
                    child: Text(
                      plan ? l.architectFacade : l.architectFacadePlan,
                    ),
                  ),
                ],
              ),
            ),
            if (placement != _Placement.none)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          placement == _Placement.north
                              ? (first == null
                                    ? l.architectNorthPositionHint
                                    : l.architectNorthDirectionHint)
                              : first == null
                              ? l.architectFacadeStartHint
                              : second == null
                              ? l.architectViewEndHint
                              : l.architectViewDirectionHint,
                        ),
                      ),
                      TextButton(onPressed: cancel, child: Text(l.cancel)),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  if (plan) {
                    final bounds = ArchitectViewPlan.bounds(project);
                    final scale =
                        math.min(
                          size.width / bounds.width,
                          size.height / bounds.height,
                        ) *
                        .85;
                    return ArchitectViewPlan(
                      project: project,
                      surfaceKey: 'architect-facade-plan',
                      transform: planTransform,
                      first: first,
                      second: second,
                      placing: placement != _Placement.none,
                      north: placement == _Placement.north,
                      selectedElevation: selectedId,
                      onPoint: (point) => planTap(
                        point,
                        scale * planTransform.value.getMaxScaleOnAxis(),
                      ),
                    );
                  }
                  if (value == null) {
                    return Center(child: Text(l.architectFacadeStartHint));
                  }
                  if (!identical(cachedProject, project) ||
                      !identical(cachedView, value)) {
                    cachedGeometry = ArchitectBuildingElevation.build(
                      project,
                      value,
                    );
                    cachedProject = project;
                    cachedView = value;
                  }
                  final geometry = cachedGeometry!;
                  final bounds = geometry.bounds.inflate(.6);
                  final scale =
                      math.min(
                        size.width / bounds.width,
                        size.height / bounds.height,
                      ) *
                      .9;
                  return ColoredBox(
                    color: Colors.white,
                    child: geometry.faces.isEmpty
                        ? Center(
                            child: Text(
                              l.architectFacadeEmpty,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              InteractiveViewer(
                                transformationController: elevationTransform,
                                minScale: .25,
                                maxScale: 20,
                                child: CustomPaint(
                                  key: const ValueKey(
                                    'architect-facade-drawing',
                                  ),
                                  size: size,
                                  painter: ArchitectFacadePainter(
                                    geometry,
                                    bounds.center,
                                    scale,
                                    fontFamily: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.fontFamily,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: elevationTransform,
                                  builder: (_, _) => ArchitectProjectionEditor(
                                    key: ValueKey(
                                      'elevation-editor:${value.id}',
                                    ),
                                    controller: widget.controller,
                                    paths: geometry.elementPaths,
                                    origin: value.centre,
                                    right: value.right,
                                    elevation: true,
                                    scale:
                                        scale *
                                        elevationTransform.value
                                            .getMaxScaleOnAxis(),
                                    toView: (p) {
                                      final local = elevationTransform.toScene(
                                        p,
                                      );
                                      return bounds.center +
                                          Offset(
                                            (local.dx - size.width / 2) / scale,
                                            -(local.dy - size.height / 2) /
                                                scale,
                                          );
                                    },
                                    toScreen: (p) => MatrixUtils.transformPoint(
                                      elevationTransform.value,
                                      size.center(Offset.zero) +
                                          Offset(
                                            (p.dx - bounds.center.dx) * scale,
                                            -(p.dy - bounds.center.dy) * scale,
                                          ),
                                    ),
                                    onNavigate: (delta, factor, focal) =>
                                        navigateArchitectProjection(
                                          elevationTransform,
                                          delta,
                                          factor,
                                          focal,
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

class ArchitectFacadePainter extends CustomPainter {
  final ArchitectBuildingElevation geometry;
  final Offset centre;
  final double scale;
  final Color fill, stroke;
  final String? fontFamily;
  ArchitectFacadePainter(
    this.geometry,
    this.centre,
    this.scale, {
    this.fill = const Color(0xfffafafa),
    this.stroke = const Color(0xff222222),
    this.fontFamily,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, -scale)
      ..setEntry(0, 3, size.width / 2 - centre.dx * scale)
      ..setEntry(1, 3, size.height / 2 + centre.dy * scale);
    canvas.clipRect(Offset.zero & size);
    // All fills precede all strokes, so shared depth boundaries remain crisp.
    for (final face in geometry.faces) {
      architectDrawingSources(
        canvas,
        geometry.elementPaths.entries
            .where((e) => e.value.getBounds().overlaps(face.getBounds()))
            .map((e) => e.key),
        'elevationFace',
      );
      canvas.drawPath(face.transform(matrix.storage), Paint()..color = fill);
    }
    for (final face in geometry.faces) {
      canvas.drawPath(
        face.transform(matrix.storage),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final symbolPaint = Paint()
      ..color = stroke.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    for (final operation in geometry.operations) {
      canvas.save();
      canvas.clipPath(operation.clip.transform(matrix.storage));
      for (final line
          in operation.lines.transform(matrix.storage).computeMetrics()) {
        for (var start = 0.0; start < line.length; start += 7) {
          canvas.drawPath(
            line.extractPath(start, math.min(start + 4, line.length)),
            symbolPaint,
          );
        }
      }
      canvas.restore();
    }
    final labels = <Rect>[];
    Offset screen(Offset p) => MatrixUtils.transformPoint(matrix, p);
    for (final slope in geometry.slopes) {
      final a = screen(slope.start), b = screen(slope.end);
      if ((b - a).distance < 8) continue;
      final u = (b - a) / (b - a).distance;
      final n = Offset(-u.dy, u.dx);
      canvas.drawLine(a, b, symbolPaint);
      canvas.drawPath(
        Path()
          ..moveTo((b - u * 7 + n * 3).dx, (b - u * 7 + n * 3).dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo((b - u * 7 - n * 3).dx, (b - u * 7 - n * 3).dy),
        symbolPaint,
      );
      final percent = (slope.percent - slope.percent.round()).abs() < .05
          ? slope.percent.round().toString()
          : slope.percent.toStringAsFixed(1);
      final text = ArchitectTextPainter(
        text: TextSpan(
          text: '$percent%',
          style: TextStyle(color: stroke, fontSize: 12, fontFamily: fontFamily),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var box = Rect.fromCenter(
        center: (a + b) / 2 - Offset(0, text.height / 2 + 6),
        width: text.width + 6,
        height: text.height + 2,
      );
      while (labels.any((r) => r.overlaps(box))) {
        box = box.shift(Offset(0, -box.height - 2));
      }
      labels.add(box);
      canvas.drawRect(box, Paint()..color = fill);
      text.paint(canvas, box.topLeft + const Offset(3, 1));
    }
  }

  @override
  bool shouldRepaint(covariant ArchitectFacadePainter oldDelegate) =>
      fill != oldDelegate.fill ||
      stroke != oldDelegate.stroke ||
      fontFamily != oldDelegate.fontFamily ||
      geometry != oldDelegate.geometry ||
      centre != oldDelegate.centre ||
      scale != oldDelegate.scale;
}

class _NorthPreview extends CustomPainter {
  final ArchitectProject project;
  final AppLocalizations l;
  final String? fontFamily;
  _NorthPreview(this.project, this.l, this.fontFamily);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 8);
    drawArchitectElevationMarkers(
      canvas,
      project,
      1,
      Colors.blueGrey,
      l,
      fontFamily: fontFamily,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NorthPreview oldDelegate) => true;
}

class _NorthDialog extends StatefulWidget {
  final ArchitectProject project;
  const _NorthDialog({required this.project});
  @override
  State<_NorthDialog> createState() => _NorthDialogState();
}

class _NorthDialogState extends State<_NorthDialog> {
  late double degrees;
  late final TextEditingController input;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    degrees = (widget.project.northSymbol!.angle * 180 / math.pi) % 360;
    input = TextEditingController(text: degrees.toStringAsFixed(1));
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectNorth),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.architectNorthHelp),
                TextFormField(
                  key: const ValueKey('architect-north-angle'),
                  controller: input,
                  decoration: InputDecoration(
                    label: Tooltip(
                      message: l.architectNorthAngleHelp,
                      child: Text(l.architectNorthAngle),
                    ),
                    suffixText: '°',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (value) =>
                      double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          )?.isFinite ==
                          true
                      ? null
                      : l.architectNorthInvalidAngle,
                  onChanged: (value) {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed != null && parsed.isFinite) {
                      setState(() => degrees = parsed % 360);
                    }
                  },
                ),
                Slider(
                  key: const ValueKey('architect-north-slider'),
                  value: degrees,
                  min: 0,
                  max: 360,
                  onChanged: (value) => setState(() {
                    degrees = value;
                    input.text = value.toStringAsFixed(1);
                  }),
                ),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    size: const Size(100, 100),
                    painter: _NorthPreview(
                      widget.project.copyWith(
                        elevations: [],
                        northSymbol: ArchitectNorthSymbol(
                          position: Offset.zero,
                          angle: degrees * math.pi / 180,
                        ),
                      ),
                      l,
                      Theme.of(context).textTheme.bodyMedium?.fontFamily,
                    ),
                  ),
                ),
                for (final e in widget.project.elevations)
                  Text(architectElevationLabel(l, e, degrees * math.pi / 180)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const ValueKey('architect-north-save'),
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, degrees * math.pi / 180);
            }
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
