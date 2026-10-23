import 'architect_roof_pitch_editor.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_projection_editing.dart';
import '../services/architect_projection_snap.dart';
import 'architect_element_properties_dialog.dart';
import 'architect_roof_layers_dialog.dart';
import 'architect_slab_layers_dialog.dart';
import 'architect_stair_properties_dialog.dart';
import 'architect_wall_drafting_panel.dart';

void navigateArchitectProjection(
  TransformationController transform,
  Offset delta,
  double factor,
  Offset focal,
) {
  final current = transform.value.getMaxScaleOnAxis();
  final next = (current * factor).clamp(.25, 20.0);
  final f = next / current;
  final change = Matrix4.diagonal3Values(f, f, 1)
    ..setEntry(0, 3, delta.dx + focal.dx * (1 - f))
    ..setEntry(1, 3, delta.dy + focal.dy * (1 - f));
  transform.value = change * transform.value;
}

/// Edits real model elements from either projection. Camera, drawings and model
/// coordinates stay separate; a drag publishes one validated history entry.
class ArchitectProjectionEditor extends StatefulWidget {
  final ArchitectCommandController controller;
  final Map<String, Path> paths;
  final Map<String, Path> roofProfiles;
  final Offset origin, right;
  final bool elevation;
  final Offset Function(Offset) toView, toScreen;
  final void Function(Offset, double, Offset)? onNavigate;
  final ValueChanged<Offset>? onMissTap;
  final double scale;
  const ArchitectProjectionEditor({
    super.key,
    required this.controller,
    required this.paths,
    this.roofProfiles = const {},
    required this.origin,
    required this.right,
    required this.elevation,
    required this.toView,
    required this.toScreen,
    required this.scale,
    this.onNavigate,
    this.onMissTap,
  });
  @override
  State<ArchitectProjectionEditor> createState() => _ProjectionEditorState();
}

class _ProjectionEditorState extends State<ArchitectProjectionEditor> {
  String? id;
  Offset? dragStart;
  Offset delta = Offset.zero;
  double lastScale = 1;
  bool roofSnapEnabled = true;
  bool pitchEditing = false;
  ArchitectProjectionSnap? roofSnap;
  Offset? snapContact;
  Path? dragPath;
  final _pointers = <int>{};
  Offset? _pointerDownView;
  String? _pointerDownHit;
  String? error;
  Timer? _errorTimer;
  final measureRects = <ArchitectOpeningMeasure, Rect>{};
  void updateDrag(Offset point) {
    final raw = point - dragStart!;
    delta = Offset(widget.elevation ? raw.dx : 0, raw.dy);
    final snap = roofSnapEnabled
        ? roofSnap?.resolve(
            delta,
            10 / widget.scale,
            horizontal: widget.elevation,
          )
        : null;
    snapContact = snap?.contact;
    delta = snap?.delta ?? delta;
  }

  ArchitectProject get project => widget.controller.project;
  ArchitectProjectedElement? get selected =>
      id == null ? null : ArchitectProjectionEditing.find(project, id!);
  List<ArchitectOpeningMeasure> get measures => id == null
      ? []
      : ArchitectProjectionEditing.measures(
          project,
          id!,
          widget.origin,
          widget.right,
          visible: widget.paths.keys.toSet(),
        );

  @override
  void didUpdateWidget(covariant ArchitectProjectionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (id != null && (!widget.paths.containsKey(id) || selected == null)) {
      id = null;
      pitchEditing = false;
      delta = Offset.zero;
      _errorTimer?.cancel();
      error = null;
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  bool apply(ArchitectProject Function() operation) {
    try {
      final next = operation();
      widget.controller.commit(next);
      if (mounted) {
        _errorTimer?.cancel();
        setState(() => error = null);
      }
      return true;
    } on ArgumentError {
      if (mounted) {
        _errorTimer?.cancel();
        setState(() => error = context.l10n.architectProjectionInvalid);
        _errorTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => error = null);
        });
      }
      return false;
    } on StateError {
      if (mounted) {
        _errorTimer?.cancel();
        setState(() => error = context.l10n.architectProjectionInvalid);
        _errorTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => error = null);
        });
      }
      return false;
    }
  }

  String label(ArchitectOpeningDistance kind) => switch (kind) {
    ArchitectOpeningDistance.left => context.l10n.architectProjectionLeft,
    ArchitectOpeningDistance.right => context.l10n.architectProjectionRight,
    ArchitectOpeningDistance.sill => context.l10n.architectPropertySill,
    ArchitectOpeningDistance.head => context.l10n.architectProjectionHead,
  };
  Future<double?> number(String title, double value, {bool signed = false}) =>
      showDialog<double>(
        context: context,
        builder: (_) => _ProjectionNumberDialog(
          title: title,
          value: project.units.toUnit(value),
          unit: project.units.symbol,
          decimals: project.distanceDecimals,
          signed: signed,
        ),
      );
  Future<void> editDistance(ArchitectOpeningMeasure measure) async {
    final target = id;
    final value = await number(label(measure.kind), measure.value);
    if (value == null || !mounted || target == null) return;
    // Recompute the reference after the dialog; never apply a stale neighbour.
    final fresh = measures.where((m) => m.kind == measure.kind).firstOrNull;
    if (fresh != null) {
      apply(
        () => ArchitectProjectionEditing.distance(
          project,
          target,
          fresh,
          project.units.fromUnit(value),
          widget.right,
        ),
      );
    }
  }

  Future<void> moveNumber(bool horizontal) async {
    final target = id;
    final value = await number(
      horizontal
          ? context.l10n.architectProjectionHorizontal
          : context.l10n.architectRoofMoveVerticalAction,
      0,
      signed: true,
    );
    if (value == null || !mounted || target == null) return;
    final metres = project.units.fromUnit(value);
    apply(
      () => ArchitectProjectionEditing.move(
        project,
        target,
        horizontal ? Offset(metres, 0) : Offset(0, metres),
        widget.right,
        elevation: widget.elevation,
      ),
    );
  }

  Future<void> properties() async {
    final ref = selected;
    if (ref == null) return;
    final local = project.copyWith(activeStoreyId: ref.storey.id);
    if (ref.kind == ArchitectProjectionKind.roof) {
      final roof = ref.storey.roofs.firstWhere((r) => r.id == ref.id);
      await showDialog<void>(
        context: context,
        builder: (_) => ArchitectRoofLayersDialog(
          initialDrainage: roof.drainage,
          project: project,
          roof: roof,
          initialAssembly: roof.assembly,
          initialSlopeDegrees: roof.slopeDegrees,
          initialEavesOverhang: roof.eavesOverhang,
          initialEavesCut: roof.eavesCut,
          initialBaseElevationOffset: roof.baseElevationOffset,
          initialAttachToWalls: roof.attachToWalls,
          initialManualSupportDistance: roof.manualSupportDistance,
          maxSupportDistance: roof.maxSlopeRun,
          onApply: (result) => apply(
            () => UpdateArchitectRoofPlane(
              storeyId: ref.storey.id,
              roof: roof.copyWith(
                drainage: result.drainage,
                assembly: result.assembly,
                slopeDegrees: result.slopeDegrees,
                eavesOverhang: result.eavesOverhang,
                eavesCut: result.eavesCut,
                baseElevationOffset: result.baseElevationOffset,
                attachToWalls: result.attachToWalls,
                manualSupportDistance: result.manualSupportDistance,
                clearManualSupportDistance:
                    result.manualSupportDistance == null,
              ),
            ).apply(project),
          ),
        ),
      );
      return;
    }
    if (ref.kind == ArchitectProjectionKind.stair) {
      final stair = ref.storey.stairs.firstWhere((s) => s.id == ref.id);
      await showDialog<void>(
        context: context,
        builder: (_) => ArchitectStairPropertiesDialog(
          project: local,
          stair: stair,
          onApply: (next) => apply(
            () => ArchitectModelCommand.replace(
              project,
              project.storeys
                  .firstWhere((s) => s.id == ref.storey.id)
                  .copyWith(
                    stairs: [
                      for (final s in ref.storey.stairs)
                        if (s.id == ref.id) next else s,
                    ],
                  ),
            ),
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectElementPropertiesDialog(
        project: local,
        elementIds: {ref.id},
        onApply: (values, texts) => apply(
          () => ArchitectProjectionEditing.properties(
            project,
            ref.id,
            values,
            texts,
          ),
        ),
        onSlabLayers: ref.kind != ArchitectProjectionKind.slab
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectSlabLayersDialog(
                    project: local,
                    slab: ref.storey.slabs.firstWhere((s) => s.id == ref.id),
                    onApply: (next) => apply(
                      () =>
                          next.copyWith(activeStoreyId: project.activeStoreyId),
                    ),
                  ),
                );
              },
      ),
    );
  }

  void align(String side) {
    final target = id;
    if (target == null) return;
    apply(
      () => ArchitectProjectionEditing.align(
        project,
        target,
        side,
        widget.origin,
        widget.right,
        widget.paths.keys,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = selected, l = context.l10n;
    if (pitchEditing && ref?.kind == ArchitectProjectionKind.roof) {
      final roof=ref!.storey.roofs.firstWhere((r)=>r.id==ref.id);
      return ArchitectRoofPitchEditor(roof:roof,elevation:ref.storey.elevation,
        origin:widget.origin,right:widget.right,toView:widget.toView,toScreen:widget.toScreen,
        onCancel:()=>setState(()=>pitchEditing=false),
        onApply:(next) {
          if(apply(()=>UpdateArchitectRoofPlane(storeyId:ref.storey.id,roof:next).apply(project))) {
            setState(()=>pitchEditing=false);
          }
        });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (event) {
            if (_pointers.isEmpty) {
              _pointerDownView = widget.toView(event.localPosition);
              _pointerDownHit = ArchitectProjectionEditing.pick(
                project,
                widget.paths,
                _pointerDownView!,
                10 / widget.scale,
              );
            }
            _pointers.add(event.pointer);
          },
          onPointerUp: (event) => _pointers.remove(event.pointer),
          onPointerCancel: (event) => setState(() {
            _pointers.remove(event.pointer);
            dragStart = null;
            delta = Offset.zero;
            snapContact = null;
            roofSnap = null;
            dragPath = null;
          }),
          onPointerSignal: widget.onNavigate == null
              ? null
              : (event) {
                  if (event is PointerScrollEvent) {
                    widget.onNavigate!(
                      Offset.zero,
                      event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                      event.localPosition,
                    );
                  }
                },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              for (final entry in measureRects.entries) {
                if (entry.value.inflate(6).contains(details.localPosition)) {
                  editDistance(entry.key);
                  return;
                }
              }
              final hit = ArchitectProjectionEditing.pick(
                project,
                widget.paths,
                widget.toView(details.localPosition),
                10 / widget.scale,
              );
              setState(() {
                id = hit;
                error = null;
              });
              if (hit == null) widget.onMissTap?.call(details.localPosition);
            },
            onDoubleTap: id == null ? null : properties,
            onScaleStart: ref == null && widget.onNavigate == null
                ? null
                : (d) {
                    lastScale = 1;
                    // Gesture recognition can begin outside a thin roof after
                    // touch slop. Keep the element and point from pointer-down.
                    dragStart =
                        d.pointerCount == 1 &&
                            ref != null &&
                            _pointerDownHit == id
                        ? _pointerDownView
                        : null;
                    delta = Offset.zero;
                    snapContact = null;
                    roofSnap =
                        dragStart != null &&
                            ref?.kind == ArchitectProjectionKind.roof
                        ? ArchitectProjectionSnap(
                            project,
                            widget.paths,
                            id!,
                            roofProfiles: widget.roofProfiles,
                          )
                        : null;
                    dragPath = widget.paths[id];
                    if (roofSnap != null) {
                      for (final member in roofSnap!.movingIds.where(
                        (member) => member != id,
                      )) {
                        final path = widget.paths[member];
                        if (path != null && dragPath != null) {
                          dragPath = Path.combine(
                            PathOperation.union,
                            dragPath!,
                            path,
                          );
                        }
                      }
                    }
                    if (dragStart != null) {
                      setState(
                        () => updateDrag(widget.toView(d.localFocalPoint)),
                      );
                    }
                  },
            onScaleUpdate: ref == null && widget.onNavigate == null
                ? null
                : (d) {
                    if (dragStart != null &&
                        d.pointerCount == 1 &&
                        ref != null) {
                      setState(
                        () => updateDrag(widget.toView(d.localFocalPoint)),
                      );
                    } else {
                      dragStart = null;
                      delta = Offset.zero;
                      snapContact = null;
                      widget.onNavigate?.call(
                        d.focalPointDelta,
                        d.scale / lastScale,
                        d.localFocalPoint,
                      );
                    }
                    lastScale = d.scale;
                  },
            onScaleEnd: ref == null && widget.onNavigate == null
                ? null
                : (_) {
                    if (dragStart != null &&
                        id != null &&
                        delta.distance > .0001) {
                      apply(
                        () => ArchitectProjectionEditing.move(
                          project,
                          id!,
                          delta,
                          widget.right,
                          elevation: widget.elevation,
                        ),
                      );
                    }
                    setState(() {
                      dragStart = null;
                      delta = Offset.zero;
                      snapContact = null;
                      roofSnap = null;
                      dragPath = null;
                    });
                  },
            child: CustomPaint(
              painter: _ProjectionSelectionPainter(
                id == null
                    ? null
                    : dragStart != null
                    ? dragPath
                    : widget.paths[id],
                delta,
                widget.toScreen,
                measures,
                measureRects,
                project.units,
                Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ref?.isOpening == true && widget.elevation,
                snapContact: snapContact,
              ),
            ),
          ),
        ),
        if (ref != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton.icon(
                            key: const ValueKey('projection-properties'),
                            onPressed: properties,
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(l.architectProperties),
                          ),
                          IconButton(
                            key: const ValueKey('projection-move-z'),
                            tooltip: l.architectRoofMoveVerticalAction,
                            onPressed: () => moveNumber(false),
                            icon: const Icon(Icons.swap_vert),
                          ),
                          if (ref.kind == ArchitectProjectionKind.roof)
                            IconButton(key:const ValueKey('projection-roof-pitch'),
                              tooltip:l.architectRoofPitchEdit,icon:const Icon(Icons.rotate_right),
                              onPressed:()=>setState(()=>pitchEditing=true)),
                          if (ref.kind == ArchitectProjectionKind.roof)
                            IconButton(
                              key: const ValueKey('projection-roof-snap'),
                              tooltip: roofSnapEnabled
                                  ? l.snapEnabledTooltip
                                  : l.snapDisabledTooltip,
                              isSelected: roofSnapEnabled,
                              onPressed: () => setState(
                                () => roofSnapEnabled = !roofSnapEnabled,
                              ),
                              icon: const Icon(Icons.grid_off),
                              selectedIcon: const Icon(Icons.grid_on),
                            ),
                          if (widget.elevation)
                            IconButton(
                              key: const ValueKey('projection-move-x'),
                              tooltip: l.architectProjectionHorizontal,
                              onPressed: () => moveNumber(true),
                              icon: const Icon(Icons.swap_horiz),
                            ),
                          if (ref.isOpening && widget.elevation)
                            PopupMenuButton<String>(
                              tooltip: l.architectWallAlign,
                              icon: const Icon(Icons.align_horizontal_left),
                              onSelected: align,
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'left',
                                  child: Text(l.architectProjectionAlignLeft),
                                ),
                                PopupMenuItem(
                                  value: 'right',
                                  child: Text(l.architectProjectionAlignRight),
                                ),
                                PopupMenuItem(
                                  value: 'sill',
                                  child: Text(l.architectProjectionAlignSill),
                                ),
                                PopupMenuItem(
                                  value: 'head',
                                  child: Text(l.architectProjectionAlignHead),
                                ),
                              ],
                            ),
                          IconButton(
                            tooltip: l.architectDeselect,
                            onPressed: () => setState(() {
                              id = null;
                              error = null;
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (ref.isOpening)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            for (final measure in measures)
                              if (widget.elevation ||
                                  measure.kind ==
                                      ArchitectOpeningDistance.sill ||
                                  measure.kind == ArchitectOpeningDistance.head)
                                TextButton(
                                  key: ValueKey(
                                    'projection-distance-${measure.kind.name}',
                                  ),
                                  onPressed: () => editDistance(measure),
                                  child: Text(
                                    '${label(measure.kind)} ${project.formatLength(measure.value)}',
                                  ),
                                ),
                            if (!measures.any(
                              (m) => m.kind == ArchitectOpeningDistance.head,
                            ))
                              Tooltip(
                                message: l.architectProjectionNoSlab,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(l.architectProjectionNoSlab),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectionSelectionPainter extends CustomPainter {
  final Path? path;
  final Offset delta;
  final Offset Function(Offset) screen;
  final List<ArchitectOpeningMeasure> measures;
  final Map<ArchitectOpeningMeasure, Rect> rects;
  final ArchitectUnit unit;
  final String? fontFamily;
  final bool horizontal;
  final Offset? snapContact;
  _ProjectionSelectionPainter(
    this.path,
    this.delta,
    this.screen,
    this.measures,
    this.rects,
    this.unit,
    this.fontFamily,
    this.horizontal, {
    this.snapContact,
  });
  @override
  void paint(Canvas canvas, Size size) {
    rects.clear();
    if (path == null) return;
    final origin = screen(delta),
        x = screen(delta + const Offset(1, 0)) - origin,
        y = screen(delta + const Offset(0, 1)) - origin;
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, x.dx)
      ..setEntry(1, 0, x.dy)
      ..setEntry(0, 1, y.dx)
      ..setEntry(1, 1, y.dy)
      ..setEntry(0, 3, origin.dx)
      ..setEntry(1, 3, origin.dy);
    final selected = path!.transform(matrix.storage);
    canvas.drawPath(
      selected,
      Paint()..color = Colors.blue.withValues(alpha: .14),
    );
    canvas.drawPath(
      selected,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (snapContact != null) {
      final at = screen(snapContact!);
      final paint = Paint()
        ..color = Colors.cyan
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 12, height: 12),
        paint,
      );
      canvas.drawLine(at - const Offset(9, 0), at + const Offset(9, 0), paint);
      canvas.drawLine(at - const Offset(0, 9), at + const Offset(0, 9), paint);
    }
    for (final m in measures) {
      if (!horizontal &&
          (m.kind == ArchitectOpeningDistance.left ||
              m.kind == ArchitectOpeningDistance.right)) {
        continue;
      }
      final a = screen(m.from), b = screen(m.to);
      final lateral =
          m.kind == ArchitectOpeningDistance.left ||
          m.kind == ArchitectOpeningDistance.right;
      final floor = measures
          .where((m) => m.kind == ArchitectOpeningDistance.sill)
          .firstOrNull;
      // Keep the editable dimensions separate around small openings.
      final offset = lateral
          ? Offset(
              0,
              (floor == null ? a.dy : screen(floor.from).dy) + 24 - a.dy,
            )
          : Offset(selected.getBounds().right + 25 - a.dx, 0);
      final paint = Paint()
        ..color = Colors.blue
        ..strokeWidth = .8;
      canvas.drawLine(a, a + offset * 1.25, paint);
      canvas.drawLine(b, b + offset * 1.25, paint);
      canvas.drawLine(a + offset, b + offset, paint);
      for (final p in [a + offset, b + offset]) {
        canvas.drawLine(
          p - const Offset(3, -3),
          p + const Offset(3, -3),
          paint,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: unit.format(m.value),
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade800,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      var at = (a + b) / 2 + offset - Offset(tp.width / 2, tp.height / 2);
      at = Offset(
        at.dx.clamp(
          5.0,
          (size.width - tp.width - 5).clamp(5.0, double.infinity),
        ),
        at.dy.clamp(
          5.0,
          (size.height - tp.height - 5).clamp(5.0, double.infinity),
        ),
      );
      var box = (at & tp.size).inflate(4);
      for (
        var attempt = 0;
        attempt < 8 && rects.values.any((r) => r.inflate(3).overlaps(box));
        attempt++
      ) {
        at -= Offset(0, tp.height + 10);
        box = (at & tp.size).inflate(4);
      }
      rects[m] = box;
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()..color = Colors.white,
      );
      tp.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectionSelectionPainter oldDelegate) => true;
}

class _ProjectionNumberDialog extends StatefulWidget {
  final String title, unit;
  final double value;
  final int decimals;
  final bool signed;
  const _ProjectionNumberDialog({
    required this.title,
    required this.unit,
    required this.value,
    required this.decimals,
    this.signed = false,
  });

  @override
  State<_ProjectionNumberDialog> createState() =>
      _ProjectionNumberDialogState();
}

class _ProjectionNumberDialogState extends State<_ProjectionNumberDialog> {
  late double _draft = widget.value;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 260,
        child: ArchitectWallDraftingPanel(
          length: _draft,
          unit: widget.unit,
          decimals: widget.decimals,
          title: widget.title,
          endLabel: context.l10n.save,
          keypadInitiallyOpen: true,
          showContinue: false,
          showDirection: false,
          minimumLength: widget.signed ? -double.infinity : 0.0,
          onLength: (val) => _draft = val,
          onEnd: () => Navigator.pop(context, _draft),
          onContinue: () {},
          onUnlock: () {},
          onCancel: () => Navigator.pop(context, null),
        ),
      ),
    );
  }
}
