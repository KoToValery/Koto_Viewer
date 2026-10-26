import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../rendering/architect_angular_guides.dart';
import '../services/architect_rotation.dart';

/// A selection-only control. Its ray follows the first pattern family; all
/// families retain their relative directions and scale together.
class ArchitectHatchTransformHandle extends StatefulWidget {
  final ArchitectCadPrimitive hatch;
  final Offset Function(Offset) toScreen, toModel;
  final VoidCallback onStart, onCancel;
  final void Function(double angle, double scale) onPreview, onApply;

  const ArchitectHatchTransformHandle({
    super.key,
    required this.hatch,
    required this.toScreen,
    required this.toModel,
    required this.onStart,
    required this.onPreview,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<ArchitectHatchTransformHandle> createState() => _HatchHandleState();
}

class _HatchHandleState extends State<ArchitectHatchTransformHandle> {
  late double angle = widget.hatch.hatchAngle;
  late double scale = widget.hatch.hatchScale;
  // A newly selected hatch always starts with a usable control length,
  // including hatches whose existing scale is near either supported limit.
  late double pixelsPerScale = 100 / scale;
  Offset? pointerDown, initialRay, dragPivot;
  bool dragging = false, snapped = false;

  double get familyAngle => widget.hatch.hatchPattern.layers.first.angleDeg;
  Offset get pivot => widget.toScreen(
    Rect.fromPoints(widget.hatch.startPoint, widget.hatch.endPoint).center,
  );
  Offset get ray {
    final radians = (angle + familyAngle) * math.pi / 180;
    final origin = widget.toModel(pivot);
    final direction =
        widget.toScreen(origin + Offset(math.cos(radians), math.sin(radians))) -
        pivot;
    return direction / direction.distance * (pixelsPerScale * scale);
  }

  @override
  void didUpdateWidget(covariant ArchitectHatchTransformHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hatch, widget.hatch)) {
      angle = widget.hatch.hatchAngle;
      scale = widget.hatch.hatchScale;
      dragging = false;
      snapped = false;
      pointerDown = null;
    }
  }

  void update(Offset global) {
    if (!dragging || pointerDown == null) return;
    final vector = initialRay! + global - pointerDown!;
    final model =
        widget.toModel(dragPivot! + vector) - widget.toModel(dragPivot!);
    // At the pivot the direction is undefined; keep the angle and let the
    // radial scale reach its minimum instead of jumping to an arbitrary axis.
    final raw = vector.distance < 1
        ? (angle + familyAngle) * math.pi / 180
        : math.atan2(model.dy, model.dx);
    final direction = ArchitectRotation.snapAngle(
      raw,
      tolerance: math
          .atan2(10, vector.distance)
          .clamp(math.pi / 180, math.pi / 30),
    );
    setState(() {
      angle = ((direction * 180 / math.pi - familyAngle + 180) % 360) - 180;
      scale = ((vector.distance / pixelsPerScale * 10).round() / 10).clamp(
        .1,
        20.0,
      );
      snapped =
          (direction / (math.pi / 4) - (direction / (math.pi / 4)).round())
              .abs() <
          1e-8;
    });
    widget.onPreview(angle, scale);
  }

  void cancel() {
    if (!dragging) return;
    setState(() {
      dragging = false;
      snapped = false;
      angle = widget.hatch.hatchAngle;
      scale = widget.hatch.hatchScale;
      pointerDown = null;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final end = pivot + ray;
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('hatch-transform-ray'),
              painter: _HatchHandlePainter(
                pivot: pivot,
                end: end,
                color: color,
                dragging: dragging,
                snapped: snapped,
                textStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: const Color(0xff303030),
                  fontSize: 12,
                ),
                label:
                    '${((angle + familyAngle) % 360).toStringAsFixed(1)}°'
                    ' · ${(scale * 100).round()}%',
              ),
            ),
          ),
        ),
        Positioned(
          left: end.dx - 24,
          top: end.dy - 24,
          width: 48,
          height: 48,
          child: Tooltip(
            message: context.l10n.architectHatchTransformHelp,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Listener(
                onPointerCancel: (_) => cancel(),
                child: GestureDetector(
                  key: const ValueKey('hatch-transform-handle'),
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (event) {
                    pointerDown = event.globalPosition;
                    initialRay = ray;
                    dragPivot = pivot;
                  },
                  onPanStart: (event) {
                    widget.onStart();
                    setState(() => dragging = true);
                    update(event.globalPosition);
                  },
                  onPanUpdate: (event) => update(event.globalPosition),
                  onPanEnd: (_) {
                    if (!dragging) return;
                    setState(() {
                      dragging = false;
                      snapped = false;
                      pointerDown = null;
                    });
                    widget.onApply(angle, scale);
                  },
                  onPanCancel: cancel,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HatchHandlePainter extends CustomPainter {
  final Offset pivot, end;
  final Color color;
  final bool dragging, snapped;
  final String label;
  final TextStyle textStyle;
  const _HatchHandlePainter({
    required this.pivot,
    required this.end,
    required this.color,
    required this.dragging,
    required this.snapped,
    required this.label,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    if (dragging) {
      ArchitectAngularGuides.paint(
        canvas,
        size,
        pivot: pivot,
        color: color,
        activeAngle: snapped
            ? math.atan2(end.dy - pivot.dy, end.dx - pivot.dx)
            : null,
      );
    }
    final ink = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(pivot, end, ink);
    canvas.drawCircle(pivot, 3, Paint()..color = Colors.white);
    canvas.drawCircle(pivot, 3, ink..style = PaintingStyle.stroke);
    canvas.drawCircle(end, 7, Paint()..color = Colors.white);
    canvas.drawCircle(end, 7, ink);
    final text = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(
      (end.dx + 12).clamp(4.0, math.max(4.0, size.width - text.width - 4)),
      (end.dy - text.height - 10).clamp(
        4.0,
        math.max(4.0, size.height - text.height - 4),
      ),
    );
    canvas.drawRect((at & text.size).inflate(3), Paint()..color = Colors.white);
    text.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _HatchHandlePainter old) =>
      pivot != old.pivot ||
      end != old.end ||
      color != old.color ||
      dragging != old.dragging ||
      snapped != old.snapped ||
      textStyle != old.textStyle ||
      label != old.label;
}
