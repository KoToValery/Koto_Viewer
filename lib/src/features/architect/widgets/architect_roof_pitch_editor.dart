import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_roof.dart';
import '../services/architect_roof_pitch_editing.dart';

class ArchitectRoofPitchEditor extends StatefulWidget {
  final ArchitectRoofPlane roof;
  final double elevation;
  final Offset origin, right;
  final Offset Function(Offset) toView, toScreen;
  final ValueChanged<ArchitectRoofPlane> onApply;
  final VoidCallback onCancel;
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
      final next = ArchitectRoofPitchEditing.rotate(
        widget.roof,
        pivot: pivot,
        control: control,
        targetTopElevation: widget.toView(screen).dy - widget.elevation,
      );
      setState(() {
        preview = next;
        invalid = false;
      });
    } on ArgumentError {
      setState(() => invalid = true);
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => pointerDown = d.localPosition,
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
              });
            },
            onPanStart: (d) {
              dragging = ((pointerDown ?? d.localPosition) - b).distance < 32;
              updatePitch(d.localPosition);
            },
            onPanUpdate: (d) {
              updatePitch(d.localPosition);
            },
            onPanEnd: (_) => dragging = false,
            onPanCancel: () => dragging = false,
            child: CustomPaint(
              painter: _PitchPainter(
                a,
                b,
                widget.roof.points
                    .map((p) => widget.toScreen(projected(p, preview)))
                    .toList(),
                invalid,
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

class _PitchPainter extends CustomPainter {
  final Offset pivot, control;
  final List<Offset> points;
  final bool invalid;
  _PitchPainter(this.pivot, this.control, this.points, this.invalid);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = invalid ? Colors.red : const Color(0xFF2E7D32);
    if (points.isNotEmpty) {
      canvas.drawPath(Path()..addPolygon(points, true), pen);
    }
    canvas.drawCircle(pivot, 7, Paint()..color = Colors.blue);
    canvas.drawLine(
      pivot - const Offset(18, 0),
      pivot + const Offset(18, 0),
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      control,
      math.max(8, pen.strokeWidth),
      Paint()..color = pen.color,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => true;
}
