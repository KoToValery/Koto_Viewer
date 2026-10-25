import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_roof.dart';
import '../services/architect_roof_pitch_editing.dart';
import '../services/architect_projection_snap.dart';

class ArchitectRoofPitchEditor extends StatefulWidget {
  final ArchitectRoofPlane roof;
  final double elevation;
  final Offset origin, right;
  final Offset Function(Offset) toView, toScreen;
  final ValueChanged<ArchitectRoofPlane> onApply;
  final VoidCallback onCancel;
  final void Function(Offset delta, double factor, Offset focal)? onNavigate;
  final ArchitectProjectionSnap? snap;
  final bool snapEnabled;
  final ValueChanged<bool>? onSnapEnabled;
  static const handleHitRadius = 24.0;
  const ArchitectRoofPitchEditor({
    super.key,
    required this.roof,
    required this.elevation,
    required this.origin,
    required this.right,
    required this.toView,
    required this.toScreen,
    required this.onApply,
    required this.onCancel,
    this.onNavigate,
    this.snap,
    this.snapEnabled = true,
    this.onSnapEnabled,
  });
  @override
  State<ArchitectRoofPitchEditor> createState() => _PitchState();
}

class _PitchState extends State<ArchitectRoofPitchEditor> {
  late ArchitectRoofPlane preview = widget.roof;
  late Offset pivot = (widget.roof.eavesEdge.$1 + widget.roof.eavesEdge.$2) / 2;
  late Offset control = widget.roof.points.reduce(
    (a, b) =>
        widget.roof.signedDistanceFromEaves(a) >
            widget.roof.signedDistanceFromEaves(b)
        ? a
        : b,
  );
  bool dragging = false, invalid = false;
  Offset? pointerDown;
  Offset? snapContact;
  (Offset, Offset)? snapGuide;
  double lastScale = 1, grabElevation = 0;
  bool navigating = false, touchInput = false;
  late bool snapEnabled = widget.snapEnabled;
  ArchitectRoofPlane? gesturePreview;
  final pointers = <int>{};
  @override
  void didUpdateWidget(covariant ArchitectRoofPitchEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roof != widget.roof) {
      preview = widget.roof;
      pivot = (widget.roof.eavesEdge.$1 + widget.roof.eavesEdge.$2) / 2;
      control = widget.roof.points.reduce(
        (a, b) =>
            widget.roof.signedDistanceFromEaves(a) >
                widget.roof.signedDistanceFromEaves(b)
            ? a
            : b,
      );
      dragging = false;
      invalid = false;
      pointerDown = null;
      snapContact = null;
      snapGuide = null;
    }
    if (oldWidget.snapEnabled != widget.snapEnabled) {
      snapEnabled = widget.snapEnabled;
    }
  }

  Offset projected(Offset world, ArchitectRoofPlane roof) => Offset(
    dot(world - widget.origin, widget.right),
    widget.elevation + roof.topElevationAt(world),
  );
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  void updatePitch(Offset screen) {
    if (!dragging) return;
    try {
      final controlPoint = projected(control, preview);
      final raw = Offset(
        controlPoint.dx,
        widget.toView(screen).dy + grabElevation,
      );
      final pixelsPerMetre =
          (widget.toScreen(const Offset(0, 1)) - widget.toScreen(Offset.zero))
              .distance;
      final snap = snapEnabled && pixelsPerMetre > 1e-8
          ? widget.snap?.resolvePitchPoint(
              raw,
              (touchInput ? 12 : 8) / pixelsPerMetre,
            )
          : null;
      final next = ArchitectRoofPitchEditing.rotate(
        widget.roof,
        pivot: pivot,
        control: control,
        targetTopElevation: raw.dy + (snap?.delta.dy ?? 0) - widget.elevation,
      );
      setState(() {
        preview = next;
        invalid = false;
        snapContact = snap?.contact;
        snapGuide = snap?.guide;
      });
    } on ArgumentError {
      setState(() {
        invalid = true;
        snapContact = null;
        snapGuide = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = widget.toScreen(projected(pivot, preview));
    final b = widget.toScreen(projected(control, preview));
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (event) {
              if (pointers.isEmpty) {
                pointerDown = event.localPosition;
                touchInput = event.kind == PointerDeviceKind.touch;
                navigating = false;
                gesturePreview = preview;
              }
              pointers.add(event.pointer);
              if (pointers.length > 1) {
                setState(() {
                  navigating = true;
                  if (dragging) preview = gesturePreview ?? preview;
                  dragging = false;
                  invalid = false;
                  snapContact = null;
                  snapGuide = null;
                });
              }
            },
            onPointerUp: (event) {
              if (dragging && !navigating && pointers.length == 1) {
                updatePitch(event.localPosition);
              }
              pointers.remove(event.pointer);
            },
            onPointerCancel: (event) {
              pointers.remove(event.pointer);
              setState(() {
                if (dragging) preview = gesturePreview ?? preview;
                dragging = false;
                invalid = false;
                snapContact = null;
                snapGuide = null;
              });
            },
            onPointerSignal: widget.onNavigate == null
                ? null
                : (event) {
                    if (event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) {
                          widget.onNavigate!(
                            Offset.zero,
                            event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                            event.localPosition,
                          );
                        },
                      );
                    }
                  },
            child: GestureDetector(
              key: const ValueKey('roof-pitch-input'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final x = widget.toView(d.localPosition).dx;
                final eave =
                    (widget.roof.eavesEdge.$1 + widget.roof.eavesEdge.$2) / 2;
                final k = dot(widget.roof.slopeDirection, widget.right);
                if (k.abs() < .05) return;
                final run = ((x - projected(eave, widget.roof).dx) / k).clamp(
                  0.0,
                  widget.roof.maxSlopeRun,
                );
                final next = eave + widget.roof.slopeDirection * run;
                final low = widget.roof.points.reduce(
                  (a, b) =>
                      widget.roof.signedDistanceFromEaves(a) <
                          widget.roof.signedDistanceFromEaves(b)
                      ? a
                      : b,
                );
                final high = widget.roof.points.reduce(
                  (a, b) =>
                      widget.roof.signedDistanceFromEaves(a) >
                          widget.roof.signedDistanceFromEaves(b)
                      ? a
                      : b,
                );
                setState(() {
                  pivot = next;
                  control = run > widget.roof.maxSlopeRun / 2 ? low : high;
                  preview = widget.roof;
                  invalid = false;
                  snapContact = null;
                  snapGuide = null;
                });
              },
              onScaleStart: (d) {
                lastScale = 1;
                navigating = navigating || d.pointerCount > 1;
                dragging =
                    !navigating &&
                    ((pointerDown ?? d.localFocalPoint) - b).distance <=
                        ArchitectRoofPitchEditor.handleHitRadius;
                if (dragging) {
                  grabElevation =
                      projected(control, preview).dy -
                      widget.toView(pointerDown ?? d.localFocalPoint).dy;
                  updatePitch(d.localFocalPoint);
                }
              },
              onScaleUpdate: (d) {
                if (d.pointerCount > 1) {
                  navigating = true;
                  dragging = false;
                }
                if (dragging && !navigating) {
                  updatePitch(d.localFocalPoint);
                } else {
                  widget.onNavigate?.call(
                    d.focalPointDelta,
                    d.scale / lastScale,
                    d.localFocalPoint,
                  );
                }
                lastScale = d.scale;
              },
              onScaleEnd: (_) => dragging = false,
              child: CustomPaint(
                key: const ValueKey('roof-pitch-preview'),
                painter: ArchitectRoofPitchPainter(
                  a,
                  b,
                  widget.roof.points
                      .map((p) => widget.toScreen(projected(p, preview)))
                      .toList(),
                  invalid,
                  snapContact: snapContact == null
                      ? null
                      : widget.toScreen(snapContact!),
                  snapGuide: snapGuide == null
                      ? null
                      : (
                          widget.toScreen(snapGuide!.$1),
                          widget.toScreen(snapGuide!.$2),
                        ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: l.architectRoofPitchHint,
                    child: Text(l.architectRoofPitchEdit),
                  ),
                  Row(
                    children: [
                      Text('${preview.slopeDegrees.toStringAsFixed(1)}°'),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('roof-pitch-snap'),
                        tooltip: snapEnabled
                            ? l.snapEnabledTooltip
                            : l.snapDisabledTooltip,
                        isSelected: snapEnabled,
                        icon: const Icon(Icons.grid_off),
                        selectedIcon: const Icon(Icons.grid_on),
                        onPressed: () {
                          setState(() {
                            snapEnabled = !snapEnabled;
                            snapContact = null;
                            snapGuide = null;
                          });
                          widget.onSnapEnabled?.call(snapEnabled);
                        },
                      ),
                      IconButton(
                        tooltip: l.architectRoofPitchAxis,
                        icon: const Icon(Icons.restart_alt),
                        onPressed: () => setState(() {
                          pivot =
                              (widget.roof.eavesEdge.$1 +
                                  widget.roof.eavesEdge.$2) /
                              2;
                          control = widget.roof.points.reduce(
                            (a, b) =>
                                widget.roof.signedDistanceFromEaves(a) >
                                    widget.roof.signedDistanceFromEaves(b)
                                ? a
                                : b,
                          );
                          preview = widget.roof;
                          invalid = false;
                          snapContact = null;
                          snapGuide = null;
                        }),
                      ),
                      IconButton(
                        tooltip: l.cancel,
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                      ),
                      IconButton(
                        key: const ValueKey('roof-pitch-confirm'),
                        tooltip: l.save,
                        onPressed: invalid
                            ? null
                            : () => widget.onApply(preview),
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ],
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

class ArchitectRoofPitchPainter extends CustomPainter {
  final Offset pivot, control;
  final List<Offset> points;
  final bool invalid;
  final Offset? snapContact;
  final (Offset, Offset)? snapGuide;
  static const pivotRadius = 3.5, controlRadius = 4.0;
  ArchitectRoofPitchPainter(
    this.pivot,
    this.control,
    this.points,
    this.invalid, {
    this.snapContact,
    this.snapGuide,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = invalid ? Colors.red : const Color(0xFF2E7D32);
    if (points.isNotEmpty) {
      canvas.drawPath(Path()..addPolygon(points, true), pen);
    }
    final axisPen = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    canvas.drawCircle(pivot, pivotRadius, axisPen);
    canvas.drawLine(
      pivot - const Offset(8, 0),
      pivot + const Offset(8, 0),
      axisPen,
    );
    canvas.drawCircle(control, controlRadius, pen);
    canvas.drawCircle(control, 1, Paint()..color = pen.color);
    if (snapContact != null) {
      final contactPen = Paint()
        ..color = Colors.cyan.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      if (snapGuide != null) {
        final delta = snapGuide!.$2 - snapGuide!.$1;
        if (delta.distance > 1e-8) {
          final u = delta / delta.distance;
          for (var d = -24.0; d < 24; d += 8) {
            canvas.drawLine(
              snapContact! + u * d,
              snapContact! + u * (d + 4),
              contactPen,
            );
          }
        }
      }
      canvas.drawRect(
        Rect.fromCenter(center: snapContact!, width: 10, height: 10),
        contactPen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArchitectRoofPitchPainter old) => true;
}
