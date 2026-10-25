import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Finishes a view marker only after an explicit choice of viewing side.
/// Arrows live in screen space and never change the marker span or view depth.
class ArchitectViewDirectionPicker extends StatefulWidget {
  final Offset start, end;
  final Offset Function(Offset) toScreen;
  final ValueChanged<int> onSelected;
  final VoidCallback onCancel;
  final void Function(Offset delta, double factor, Offset focal) onNavigate;
  const ArchitectViewDirectionPicker({
    super.key,
    required this.start,
    required this.end,
    required this.toScreen,
    required this.onSelected,
    required this.onCancel,
    required this.onNavigate,
  });
  @override
  State<ArchitectViewDirectionPicker> createState() => _DirectionPickerState();
}

class _DirectionPickerState extends State<ArchitectViewDirectionPicker> {
  Offset? focal;
  double scale = 1;
  @override
  Widget build(BuildContext context) {
    final a = widget.toScreen(widget.start), b = widget.toScreen(widget.end);
    final delta = b - a, centre = (a + b) / 2;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (e) {
              focal = e.localFocalPoint;
              scale = 1;
            },
            onScaleUpdate: (e) {
              widget.onNavigate(
                e.localFocalPoint - focal!,
                e.scale / scale,
                e.localFocalPoint,
              );
              focal = e.localFocalPoint;
              scale = e.scale;
            },
            child: CustomPaint(painter: _SpanPainter(a, b, color)),
          ),
        ),
        for (final side in [1, -1])
          Positioned(
            left: centre.dx + normal.dx * side * 52 - 32,
            top: centre.dy + normal.dy * side * 52 - 32,
            child: Tooltip(
              message: context.l10n.architectViewDirectionSide(
                side == 1 ? 1 : 2,
              ),
              child: Semantics(
                button: true,
                label: context.l10n.architectViewDirectionSide(
                  side == 1 ? 1 : 2,
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: ValueKey(
                      'architect-view-direction-${side == 1 ? 'positive' : 'negative'}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSelected(side),
                    child: Transform.rotate(
                      angle: math.atan2(normal.dy * side, normal.dx * side),
                      child: CustomPaint(
                        size: const Size(64, 64),
                        painter: ArchitectViewDirectionArrowPainter(color),
                      ),
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
          child: Material(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(child: Text(context.l10n.architectViewChooseArrow)),
                  IconButton(
                    key: const ValueKey('architect-view-direction-cancel'),
                    tooltip: context.l10n.cancel,
                    onPressed: widget.onCancel,
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

/// Open dashed strokes keep both alternatives distinct from a committed marker.
class ArchitectViewDirectionArrowPainter extends CustomPainter {
  final Color color;
  ArchitectViewDirectionArrowPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(8, 32)
      ..lineTo(56, 32)
      ..moveTo(41, 18)
      ..lineTo(56, 32)
      ..lineTo(41, 46);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        dashed.addPath(
          metric.extractPath(d, math.min(d + 6, metric.length)),
          Offset.zero,
        );
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant ArchitectViewDirectionArrowPainter old) =>
      old.color != color;
}

class _SpanPainter extends CustomPainter {
  final Offset a, b;
  final Color color;
  _SpanPainter(this.a, this.b, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
    for (final p in [a, b]) {
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SpanPainter old) =>
      old.a != a || old.b != b || old.color != color;
}
