import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_section.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_view_placement.dart';
import '../services/architect_workspace_view_controller.dart';
import 'architect_view_depth_dialog.dart';

/// Drafts directly on the workspace plan, using its existing camera and history.
class ArchitectWorkspaceViewPlacement extends StatefulWidget {
  final ArchitectCommandController controller;
  final ArchitectWorkspaceView type;
  final String? id;
  final String mode;
  final Offset Function(Offset) toModel, toScreen;
  final double scale;
  final ValueChanged<String?> onDone;
  final void Function(Offset, double, Offset)? onNavigate;
  const ArchitectWorkspaceViewPlacement({
    super.key,
    required this.controller,
    required this.type,
    this.id,
    required this.mode,
    required this.toModel,
    required this.toScreen,
    required this.scale,
    required this.onDone,
    this.onNavigate,
  });
  @override
  State<ArchitectWorkspaceViewPlacement> createState() => _PlacementState();
}

class _PlacementState extends State<ArchitectWorkspaceViewPlacement> {
  Offset? first, second, pointer;
  double _lastScale = 1;
  Offset? _lastFocal;
  Offset? _pointerDown;
  int? _handle;
  List<Offset> _steps = [];
  double? _depth;
  double _originalLength = 1;
  List<Offset> get editSteps => [
    for (final p in _steps)
      Offset(p.dx * (second! - first!).distance / _originalLength, p.dy),
  ];
  ArchitectProject get project => widget.controller.project;
  ArchitectSection? get section =>
      project.sections.where((s) => s.id == widget.id).firstOrNull;
  ArchitectElevation? get elevation =>
      project.elevations.where((s) => s.id == widget.id).firstOrNull;
  Offset get direction {
    if (first != null && second != null) {
      final axis = (second! - first!) / (second! - first!).distance;
      return Offset(-axis.dy, axis.dx) * (elevation?.viewSide ?? 1).toDouble();
    }
    return section?.viewDirection ??
        elevation?.viewDirection ??
        const Offset(0, 1);
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'depth' ||
        widget.mode == 'step' ||
        widget.mode == 'edit') {
      first = section?.start ?? elevation?.start;
      second = section?.end ?? elevation?.end;
      _steps = [...?section?.steps, ...?elevation?.steps];
      _depth = section?.viewDepth ?? elevation?.viewDepth;
      _originalLength = (second! - first!).distance;
    }
  }

  void saveEdit() {
    final s = section, e = elevation;
    if (first == null || second == null || (second! - first!).distance < .01) {
      return;
    }
    final steps = editSteps;
    if (_depth != null && steps.any((p) => p.dy >= _depth!)) return;
    widget.controller.commit(
      project.copyWith(
        sections: [
          for (final old in project.sections)
            if (old.id == s?.id)
              old.copyWith(
                start: first,
                end: second,
                steps: steps,
                viewDepth: _depth,
                clearViewDepth: _depth == null,
              )
            else
              old,
        ],
        elevations: [
          for (final old in project.elevations)
            if (old.id == e?.id)
              old.copyWith(
                start: first,
                end: second,
                steps: steps,
                viewDepth: _depth,
                clearViewDepth: _depth == null,
              )
            else
              old,
        ],
      ),
    );
    widget.onDone(widget.id);
  }

  void moveHandle(Offset screen) {
    final p = widget.toModel(screen);
    setState(() {
      if (_handle == 0 && (p - second!).distance >= .1) {
        first = p;
      } else if (_handle == 1 && (p - first!).distance >= .1) {
        second = p - direction * (_steps.lastOrNull?.dy ?? 0);
      } else if (_depth != null && _handle == 2) {
        final delta = p - first!;
        final value = delta.dx * direction.dx + delta.dy * direction.dy;
        if (value >= .01 && editSteps.every((p) => p.dy < value)) {
          _depth = value;
        }
      } else if (_handle != null && _handle! >= (_depth == null ? 2 : 3)) {
        final index = _handle! - (_depth == null ? 2 : 3);
        final axis = (second! - first!) / (second! - first!).distance;
        final delta = p - first!;
        final station =
            (delta.dx * axis.dx + delta.dy * axis.dy) *
            _originalLength /
            (second! - first!).distance;
        final offset = delta.dx * direction.dx + delta.dy * direction.dy;
        final low = index == 0 ? .01 : _steps[index - 1].dx + .01;
        final high = index + 1 == _steps.length
            ? _originalLength - .01
            : _steps[index + 1].dx - .01;
        if (station >= low &&
            station <= high &&
            (_depth == null || offset < _depth!)) {
          _steps[index] = Offset(station, offset);
        }
      }
    });
  }

  void accept(Offset screen) {
    if (widget.mode == 'edit') return;
    final raw = widget.toModel(screen);
    if (first == null) {
      setState(
        () => first = ArchitectViewPlacement.snapStart(
          project,
          raw,
          10 / widget.scale,
        ),
      );
      return;
    }
    if (second == null) {
      final end = ArchitectViewPlacement.snapEnd(project, first!, raw);
      if ((end - first!).distance < .01) return;
      setState(() => second = end);
      return;
    }
    final view = ArchitectViewPlacement.resolve(first!, second!, raw);
    if (view == null && widget.mode != 'step') return;
    final s = section, e = elevation;
    final id =
        widget.id ??
        ArchitectElementId.next(
          widget.type == ArchitectWorkspaceView.section ? 'section' : 'facade',
        );
    final steps = [...?s?.steps, ...?e?.steps];
    double? depth = view?.depth;
    if (widget.mode == 'step') {
      final axis = (second! - first!) / (second! - first!).distance;
      final delta = raw - first!;
      final station = delta.dx * axis.dx + delta.dy * axis.dy;
      final offset = delta.dx * direction.dx + delta.dy * direction.dy;
      depth = s?.viewDepth ?? e?.viewDepth;
      if (station < .01 ||
          station > (second! - first!).distance - .01 ||
          depth != null && offset >= depth - .01) {
        return;
      }
      steps.removeWhere((p) => (p.dx - station).abs() < .01);
      steps.add(Offset(station, offset));
      steps.sort((a, b) => a.dx.compareTo(b.dx));
    } else if (widget.mode == 'depth') {
      final distance =
          (raw - first!).dx * direction.dx + (raw - first!).dy * direction.dy;
      if (distance < .01 || steps.any((p) => p.dy >= distance - .01)) return;
      depth = distance;
    } else {
      steps.clear();
    }
    if (widget.type == ArchitectWorkspaceView.section) {
      final flip = widget.mode == 'depth' || widget.mode == 'step'
          ? false
          : view!.side < 0;
      final value = (s ?? ArchitectSection(id: id, start: first!, end: second!))
          .copyWith(
            start: flip ? second : first,
            end: flip ? first : second,
            viewDepth: depth,
            steps: steps,
            clearViewDepth: depth == null,
          );
      widget.controller.commit(
        project.copyWith(
          sections: [
            for (final old in project.sections)
              if (old.id != id) old else value,
            if (s == null) value,
          ],
        ),
      );
    } else {
      final value =
          (e ?? ArchitectElevation(id: id, start: first!, end: second!))
              .copyWith(
                start: first,
                end: second,
                viewDepth: depth,
                steps: steps,
                clearViewDepth: depth == null,
                viewSide: widget.mode == 'depth' || widget.mode == 'step'
                    ? e?.viewSide
                    : view!.side,
              );
      widget.controller.commit(
        project.copyWith(
          elevations: [
            for (final old in project.elevations)
              if (old.id != id) old else value,
            if (e == null) value,
          ],
        ),
      );
    }
    widget.onDone(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            onHover: (e) =>
                setState(() => pointer = widget.toModel(e.localPosition)),
            child: Listener(
              onPointerDown: (e) => _pointerDown = e.localPosition,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) {
                  _lastScale = 1;
                  _lastFocal = d.localFocalPoint;
                  _handle = null;
                  if (widget.mode == 'edit' &&
                      first != null &&
                      second != null) {
                    final handles = [
                      first!,
                      second! + direction * (_steps.lastOrNull?.dy ?? 0),
                      if (_depth != null)
                        (first! + second!) / 2 + direction * _depth!,
                      for (final p in editSteps)
                        first! +
                            (second! - first!) /
                                (second! - first!).distance *
                                p.dx +
                            direction * p.dy,
                    ];
                    for (var i = 0; i < handles.length; i++) {
                      if ((widget.toScreen(handles[i]) -
                                  (_pointerDown ?? d.localFocalPoint))
                              .distance <
                          18) {
                        _handle = i;
                        break;
                      }
                    }
                    if (_handle != null) moveHandle(d.localFocalPoint);
                  }
                },
                onScaleUpdate: (d) {
                  if (d.scale <= 0 || !d.scale.isFinite) return;
                  if (_handle != null && d.pointerCount == 1) {
                    moveHandle(d.localFocalPoint);
                    return;
                  }
                  widget.onNavigate?.call(
                    d.localFocalPoint - (_lastFocal ?? d.localFocalPoint),
                    d.scale / _lastScale,
                    d.localFocalPoint,
                  );
                  _lastScale = d.scale;
                  _lastFocal = d.localFocalPoint;
                },
                onTapUp: (d) => accept(d.localPosition),
                child: CustomPaint(
                  painter: _MarkerPainter(
                    first,
                    second,
                    pointer,
                    widget.toScreen,
                    direction,
                    widget.mode,
                    widget.mode == 'edit'
                        ? editSteps
                        : widget.mode == 'step' || widget.mode == 'depth'
                        ? [...?section?.steps, ...?elevation?.steps]
                        : const [],
                    widget.mode == 'edit'
                        ? _depth
                        : section?.viewDepth ?? elevation?.viewDepth,
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.mode == 'edit'
                          ? l.architectViewEditHint
                          : widget.mode == 'step'
                          ? l.architectViewStepHint
                          : first == null
                          ? l.architectFacadeStartHint
                          : second == null
                          ? l.architectViewEndHint
                          : l.architectViewDirectionHint,
                    ),
                  ),
                  if (widget.mode == 'edit')
                    IconButton(
                      tooltip: l.applyAction,
                      onPressed: saveEdit,
                      icon: const Icon(Icons.check),
                    ),
                  IconButton(
                    tooltip: l.architectViewDepth,
                    onPressed: widget.id == null
                        ? null
                        : () async {
                            final currentSteps = widget.mode == 'edit'
                                ? editSteps
                                : section?.steps ??
                                      elevation?.steps ??
                                      const <Offset>[];
                            final result = await showArchitectViewDepth(
                              context,
                              project,
                              widget.mode == 'edit'
                                  ? _depth
                                  : section?.viewDepth ?? elevation?.viewDepth,
                              minimumDepth:
                                  [
                                    0.0,
                                    ...currentSteps.map((p) => p.dy),
                                  ].reduce((a, b) => a > b ? a : b) +
                                  .01,
                            );
                            if (result == null || !mounted) return;
                            if (widget.mode == 'edit') {
                              setState(() => _depth = result.depth);
                              return;
                            }
                            final s = section, e = elevation;
                            final steps =
                                s?.steps ?? e?.steps ?? const <Offset>[];
                            if (result.depth != null &&
                                steps.any((p) => p.dy > result.depth! - .01)) {
                              return;
                            }
                            widget.controller.commit(
                              project.copyWith(
                                sections: [
                                  for (final old in project.sections)
                                    if (old.id == s?.id)
                                      old.copyWith(
                                        viewDepth: result.depth,
                                        clearViewDepth: result.depth == null,
                                      )
                                    else
                                      old,
                                ],
                                elevations: [
                                  for (final old in project.elevations)
                                    if (old.id == e?.id)
                                      old.copyWith(
                                        viewDepth: result.depth,
                                        clearViewDepth: result.depth == null,
                                      )
                                    else
                                      old,
                                ],
                              ),
                            );
                            widget.onDone(widget.id);
                          },
                    icon: const Icon(Icons.straighten),
                  ),
                  IconButton(
                    tooltip: l.cancel,
                    onPressed: () => widget.onDone(null),
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

class _MarkerPainter extends CustomPainter {
  final Offset? first, second, pointer;
  final Offset Function(Offset) screen;
  final Offset direction;
  final String mode;
  final List<Offset> steps;
  final double? depth;
  _MarkerPainter(
    this.first,
    this.second,
    this.pointer,
    this.screen,
    this.direction,
    this.mode,
    this.steps,
    this.depth,
  );
  @override
  void paint(Canvas canvas, Size size) {
    if (first == null) return;
    final end = second ?? pointer;
    if (end == null || (end - first!).distance < .01) return;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final axis = (end - first!) / (end - first!).distance;
    final normal = Offset(-axis.dy, axis.dx);
    final resolved = second != null && pointer != null
        ? ArchitectViewPlacement.resolve(first!, end, pointer!)
        : null;
    final forward = mode == 'step' || mode == 'depth' || mode == 'edit'
        ? direction
        : normal * (resolved?.side ?? 1).toDouble();
    final segments = viewSegments(first!, end, forward, steps);
    final path = Path()
      ..moveTo(
        screen(segments.first.start).dx,
        screen(segments.first.start).dy,
      );
    for (final s in segments) {
      final a = screen(s.start), b = screen(s.end);
      path
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      canvas.drawCircle(a, 5, paint);
      canvas.drawCircle(b, 5, paint);
    }
    canvas.drawPath(path, paint);
    final d =
        second != null && pointer != null && mode != 'step' && mode != 'edit'
        ? ArchitectViewPlacement.resolve(first!, second!, pointer!)?.depth
        : depth;
    if (d != null) {
      final a = screen(first! + forward * d), b = screen(end + forward * d);
      canvas.drawLine(a, b, paint..color = Colors.blue.withValues(alpha: .4));
      canvas.drawLine(screen(first!), a, paint);
      canvas.drawLine(screen(end), b, paint);
      canvas.drawCircle((a + b) / 2, 5, paint);
    }
    if (pointer != null && mode == 'step') {
      canvas.drawCircle(screen(pointer!), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
