import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../bim_editing/interaction/bim_pointer_interaction.dart';
import '../../bim_editing/rendering/bim_pointer_marks.dart';
import '../rendering/architect_snap_helper.dart';

typedef ArchitectTransformSnap =
    ArchitectSnapResult Function(Offset raw, bool touch);

/// Transform points use the drawing tools' object snaps, CAD glyphs and lifted
/// touch target. Quick taps pick directly; holding exposes the point above a finger.
class ArchitectTransformPointInput extends StatefulWidget {
  final Offset Function(Offset) toModel, toScreen;
  final ArchitectTransformSnap snap;
  final ValueChanged<ArchitectSnapResult> onAim, onPick;
  final void Function(Offset delta, double factor, Offset focal) onNavigate;
  final String? Function(String?) localizeSnap;
  const ArchitectTransformPointInput({
    super.key,
    required this.toModel,
    required this.toScreen,
    required this.snap,
    required this.onAim,
    required this.onPick,
    required this.onNavigate,
    required this.localizeSnap,
  });
  @override
  State<ArchitectTransformPointInput> createState() => _PointInputState();
}

class _PointInputState extends State<ArchitectTransformPointInput> {
  ArchitectSnapResult? current;
  Offset? pointer, focal;
  bool touch = false, holding = false, navigating = false;
  double scale = 1;

  ArchitectSnapResult aim(Offset screen) {
    final target = BimPointerInteraction.placementTarget(
      screen,
      isMouse: !holding,
    );
    final result = widget.snap(widget.toModel(target), touch);
    setState(() {
      current = result;
      pointer = screen;
    });
    widget.onAim(result);
    return result;
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (e) {
      touch = false;
      aim(e.localPosition);
    },
    child: Listener(
      onPointerDown: (e) {
        touch = e.kind == PointerDeviceKind.touch;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (e) => widget.onPick(aim(e.localPosition)),
        onLongPressStart: (e) {
          if (!touch) return;
          holding = true;
          aim(e.localPosition);
        },
        onLongPressMoveUpdate: (e) {
          if (holding) aim(e.localPosition);
        },
        onLongPressEnd: (e) {
          if (!holding) return;
          final result = aim(e.localPosition);
          setState(() {
            holding = false;
          });
          widget.onPick(result);
        },
        onLongPressCancel: () {
          if (holding) {
            setState(() {
              holding = false;
            });
          }
        },
        onScaleStart: (e) {
          focal = e.localFocalPoint;
          scale = 1;
          navigating = e.pointerCount > 1;
        },
        onScaleUpdate: (e) {
          if (e.pointerCount > 1) navigating = true;
          if (navigating) {
            widget.onNavigate(
              e.localFocalPoint - focal!,
              e.scale / scale,
              e.localFocalPoint,
            );
            focal = e.localFocalPoint;
            scale = e.scale;
          } else {
            aim(e.localFocalPoint);
          }
        },
        onScaleEnd: (_) {
          navigating = false;
        },
        child: CustomPaint(
          key: const ValueKey('architect-transform-snap'),
          painter: current == null
              ? null
              : ArchitectTransformSnapPainter(
                  result: current!,
                  toScreen: widget.toScreen,
                  touch: holding ? pointer : null,
                  label: widget.localizeSnap(current!.snapLabel),
                ),
        ),
      ),
    ),
  );
}

class ArchitectTransformSnapPainter extends CustomPainter {
  final ArchitectSnapResult result;
  final Offset Function(Offset) toScreen;
  final Offset? touch;
  final String? label;
  ArchitectTransformSnapPainter({
    required this.result,
    required this.toScreen,
    this.touch,
    this.label,
  });
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final point = toScreen(result.point);
    final color = result.isSnapped
        ? const Color(0xFF00A2B8)
        : const Color(0xFFC47B00);
    final guide = Paint()
      ..color = color.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (final (a, b) in result.magneticGuides) {
      canvas.drawLine(toScreen(a), toScreen(b), guide);
    }
    if (touch != null) {
      BimPointerMarks.touchAndStem(canvas, touch!, point, color);
    } else {
      canvas.drawLine(
        point - const Offset(9, 0),
        point + const Offset(9, 0),
        guide,
      );
      canvas.drawLine(
        point - const Offset(0, 9),
        point + const Offset(0, 9),
        guide,
      );
    }
    if (result.isSnapped) {
      BimPointerMarks.snap(canvas, point, switch (result.snapLabel) {
        'Endpoint' || 'Vertex' || 'Axis endpoint' => BimSnapGlyph.endpoint,
        'Midpoint' => BimSnapGlyph.midpoint,
        'Center' => BimSnapGlyph.center,
        'Intersection' || 'Axis intersection' => BimSnapGlyph.intersection,
        'Perpendicular' => BimSnapGlyph.perpendicular,
        _ => BimSnapGlyph.nearest,
      }, color);
    }
    if (label != null) {
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            backgroundColor: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);
      text.paint(
        canvas,
        Offset(
          (point.dx + 14).clamp(8, size.width - text.width - 8),
          (point.dy - text.height - 14).clamp(8, size.height - text.height - 8),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArchitectTransformSnapPainter old) => true;
}
