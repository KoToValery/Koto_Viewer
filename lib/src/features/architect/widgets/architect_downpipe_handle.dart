import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_roof_drainage_geometry.dart';

/// An outlet owns its own hit area, leaving drawing/navigation gestures outside
/// the pipe and its leader to the surrounding plan or projection editor.
class ArchitectDownpipeHandle extends StatefulWidget {
  final ArchitectCommandController controller;
  final Offset Function(Offset plan, double elevation) toScreen;
  final Set<String>? roofIds;
  final VoidCallback? onSelected;
  final int selectionRevision;
  final bool Function(String roofId, Offset point, double elevation)? visibleAt;
  final void Function(Offset delta, double factor, Offset focal)? onNavigate;
  const ArchitectDownpipeHandle({
    super.key,
    required this.controller,
    required this.toScreen,
    this.roofIds,
    this.onSelected,
    this.selectionRevision = 0,
    this.visibleAt,
    this.onNavigate,
  });
  @override
  State<ArchitectDownpipeHandle> createState() => _DownpipeHandleState();
}

class _DownpipeHandleState extends State<ArchitectDownpipeHandle> {
  String? selected;
  Offset? dragStart;
  double? draftOffset;
  bool invalid = false;
  final pointers = <int>{};
  static const leader = Offset(40, -40);

  @override
  void didUpdateWidget(covariant ArchitectDownpipeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionRevision != widget.selectionRevision) {
      selected = null;
      dragStart = null;
      draftOffset = null;
      invalid = false;
    }
  }

  List<ArchitectDownpipeView> views() {
    final project = widget.controller.project;
    final result = <ArchitectDownpipeView>[];
    for (final floor in project.storeys) {
      for (final roof in floor.roofs) {
        if (widget.roofIds != null && !widget.roofIds!.contains(roof.id)) {
          continue;
        }
        if (!roof.drainage.showDownpipes) continue;
        for (final pipe in roof.drainage.downpipes.where((p) => p.visible)) {
          final route = ArchitectRoofDrainageGeometry.build(
            project,
            floor,
            roof,
          ).routes.where((r) => r.pipe.id == pipe.id).firstOrNull;
          if (route == null || route.status != ArchitectDownpipeStatus.ready) {
            continue;
          }
          final probes = [
            ...route.points,
            for (var i = 0; i + 1 < route.points.length; i++)
              (route.points[i] + route.points[i + 1]) / 2,
          ];
          if (widget.visibleAt != null &&
              !probes.any(
                (p) => widget.visibleAt!(roof.id, Offset(p.x, p.y), p.z),
              )) {
            continue;
          }
          final (a, b) = ArchitectRoofDrainageGeometry.eaves(roof);
          final unit = (b - a) / (b - a).distance;
          final first = route.points.first;
          final anchor = widget.toScreen(Offset(first.x, first.y), first.z);
          final step =
              widget.toScreen(Offset(first.x, first.y) + unit, first.z) -
              anchor;
          final shift = pipe.id == selected && draftOffset != null
              ? step * (draftOffset! - pipe.offset)
              : Offset.zero;
          result.add(
            ArchitectDownpipeView(floor, roof, pipe, [
              for (final p in route.points)
                widget.toScreen(Offset(p.x, p.y), p.z) + shift,
            ], step),
          );
        }
      }
    }
    return result;
  }

  bool save(ArchitectDownpipeView view, double offset) {
    final current = widget.controller.project;
    final floor = current.storeys
        .where((s) => s.id == view.floor.id)
        .firstOrNull;
    final roof = floor?.roofs.where((r) => r.id == view.roof.id).firstOrNull;
    final pipe = roof?.drainage.downpipes
        .where((p) => p.id == view.pipe.id)
        .firstOrNull;
    if (roof == null || pipe == null || floor == null) return false;
    final nextPipe = pipe.copyWith(offset: offset);
    final next = roof.copyWith(
      drainage: roof.drainage.copyWith(
        downpipes: [
          for (final p in roof.drainage.downpipes)
            if (p.id == pipe.id) nextPipe else p,
        ],
      ),
    );
    if (ArchitectRoofDrainageGeometry.route(
          current,
          floor,
          next,
          nextPipe,
        ).status !=
        ArchitectDownpipeStatus.ready) {
      setState(() => invalid = true);
      return false;
    }
    if ((offset - pipe.offset).abs() > 1e-7) {
      widget.controller.execute(
        UpdateArchitectRoofPlane(storeyId: floor.id, roof: next),
      );
    }
    if (invalid) setState(() => invalid = false);
    return true;
  }

  Future<void> number(ArchitectDownpipeView view) async {
    final project = widget.controller.project;
    var text = project.units
        .toUnit(view.pipe.offset)
        .toStringAsFixed(project.distanceDecimals);
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.architectDrainageOffset),
        content: TextFormField(
          initialValue: text,
          autofocus: true,
          onChanged: (v) => text = v,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: project.units.symbol),
          onFieldSubmitted: (v) {
            final n = double.tryParse(v.replaceAll(',', '.'));
            if (n != null && n.isFinite && n >= 0) Navigator.pop(context, n);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final n = double.tryParse(text.replaceAll(',', '.'));
              if (n != null && n.isFinite && n >= 0) Navigator.pop(context, n);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    save(view, project.units.fromUnit(value));
  }

  @override
  Widget build(BuildContext context) {
    final all = views();
    final view = all.where((p) => p.pipe.id == selected).firstOrNull;
    final painter = ArchitectDownpipeHandlePainter(
      all,
      selected,
      leader,
      invalid,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && widget.onNavigate != null) {
              GestureBinding.instance.pointerSignalResolver.register(event, (
                _,
              ) {
                setState(() {
                  dragStart = null;
                  draftOffset = null;
                });
                widget.onNavigate!(
                  Offset.zero,
                  event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                  event.localPosition,
                );
              });
            }
          },
          onPointerDown: (d) {
            if (!mounted) return;
            pointers.add(d.pointer);
            dragStart =
                pointers.length == 1 &&
                    view != null &&
                    (d.localPosition - (view.points.first + leader)).distance <=
                        28
                ? d.localPosition
                : null;
            draftOffset = dragStart == null ? null : view!.pipe.offset;
            if (pointers.length > 1) setState(() => draftOffset = null);
          },
          onPointerMove: (d) {
            if (!mounted) return;
            if (dragStart == null ||
                view == null ||
                view.step.distanceSquared < 1e-6) {
              return;
            }
            final delta = d.localPosition - dragStart!;
            final length =
                (ArchitectRoofDrainageGeometry.eaves(view.roof).$2 -
                        ArchitectRoofDrainageGeometry.eaves(view.roof).$1)
                    .distance;
            final clearance = view.pipe.diameter / 2 + .011;
            setState(() {
              draftOffset =
                  (view.pipe.offset +
                          (delta.dx * view.step.dx + delta.dy * view.step.dy) /
                              view.step.distanceSquared)
                      .clamp(clearance, length - clearance);
              invalid = false;
            });
          },
          onPointerUp: (d) {
            if (!mounted) return;
            if (view != null &&
                draftOffset != null &&
                dragStart != null &&
                (d.localPosition - dragStart!).distance > 3) {
              save(view, draftOffset!);
            } else if (pointers.length == 1 && draftOffset == null) {
              setState(() {
                selected = painter.pick(d.localPosition)?.pipe.id;
                invalid = false;
              });
              if (selected != null) widget.onSelected?.call();
            }
            pointers.remove(d.pointer);
            setState(() {
              dragStart = null;
              draftOffset = null;
            });
          },
          onPointerCancel: (d) {
            if (mounted) {
              setState(() {
                pointers.remove(d.pointer);
                dragStart = null;
                draftOffset = null;
                invalid = false;
              });
            }
          },
          child: CustomPaint(
            key: const ValueKey('downpipe-handle-paint'),
            painter: painter,
          ),
        ),
        if (view != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Card(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: TextButton.icon(
                        key: const ValueKey('downpipe-offset'),
                        onPressed: () => number(view),
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(
                          '${context.l10n.architectDrainagePipe} ${widget.controller.project.formatLength(draftOffset ?? view.pipe.offset)}',
                        ),
                      ),
                    ),
                    if (invalid)
                      Flexible(
                        child: Text(
                          context.l10n.architectDrainageBlocked,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: context.l10n.architectDeselect,
                      onPressed: () => setState(() {
                        selected = null;
                        draftOffset = null;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ArchitectDownpipeView {
  final ArchitectStorey floor;
  final ArchitectRoofPlane roof;
  final ArchitectDownpipe pipe;
  final List<Offset> points;
  final Offset step;
  const ArchitectDownpipeView(
    this.floor,
    this.roof,
    this.pipe,
    this.points,
    this.step,
  );
}

class ArchitectDownpipeHandlePainter extends CustomPainter {
  final List<ArchitectDownpipeView> views;
  final String? selected;
  final Offset leader;
  final bool invalid;
  ArchitectDownpipeHandlePainter(
    this.views,
    this.selected,
    this.leader,
    this.invalid,
  );
  Offset? get handle {
    final view = views.where((v) => v.pipe.id == selected).firstOrNull;
    return view == null ? null : view.points.first + leader;
  }

  ArchitectDownpipeView? pick(Offset point) {
    for (final v in views) {
      if (v.pipe.id == selected &&
          (point - (v.points.first + leader)).distance <= 26) {
        return v;
      }
      for (var i = 0; i + 1 < v.points.length; i++) {
        final a = v.points[i], d = v.points[i + 1] - a;
        final t = d.distanceSquared < 1e-8
            ? 0.0
            : (((point - a).dx * d.dx + (point - a).dy * d.dy) /
                      d.distanceSquared)
                  .clamp(0.0, 1.0);
        if ((point - a - d * t).distance <= 10) return v;
      }
    }
    return null;
  }

  @override
  bool? hitTest(Offset position) => pick(position) != null;
  @override
  void paint(Canvas canvas, Size size) {
    final view = views.where((v) => v.pipe.id == selected).firstOrNull;
    if (view == null) return;
    final pen = Paint()
      ..color = invalid ? Colors.red : const Color(0xff1565c0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    canvas.drawPath(Path()..addPolygon(view.points, false), pen);
    final anchor = view.points.first, end = anchor + leader;
    canvas.drawLine(anchor, end, pen);
    canvas.drawCircle(anchor, 2, Paint()..color = pen.color);
    canvas.drawCircle(end, 4, pen);
    canvas.drawCircle(end, 1, Paint()..color = pen.color);
  }

  @override
  bool shouldRepaint(covariant ArchitectDownpipeHandlePainter oldDelegate) =>
      true;
}
