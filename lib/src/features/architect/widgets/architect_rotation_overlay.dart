import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_rotation.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../rendering/architect_snap_helper.dart';
import 'architect_transform_point_input.dart';

class ArchitectRotationOverlay extends StatefulWidget {
  final Offset initialPivot;
  final Offset Function(Offset) toModel, toScreen;
  final ArchitectSnapResult Function(Offset raw, bool touch, bool selectionOnly)
  snap;
  final String? Function(String?) localizeSnap;
  final void Function(Offset pivot, double radians) onPreview, onApply;
  final void Function(Offset delta, double factor, Offset focal) onNavigate;
  final VoidCallback onCancel;
  const ArchitectRotationOverlay({
    super.key,
    required this.initialPivot,
    required this.toModel,
    required this.toScreen,
    required this.snap,
    required this.localizeSnap,
    required this.onPreview,
    required this.onApply,
    required this.onNavigate,
    required this.onCancel,
  });
  @override
  State<ArchitectRotationOverlay> createState() => _RotationState();
}

class _RotationState extends State<ArchitectRotationOverlay> {
  late Offset pivot = widget.initialPivot;
  Offset? reference, target;
  double angle = 0;
  int stage = 0;

  void aim(ArchitectSnapResult snap) {
    final point = snap.point;
    setState(() {
      target = point;
      if (stage == 2 && (point - pivot).distance > 1e-8) {
        final start = reference! - pivot, end = point - pivot;
        final raw = math.atan2(
          start.dx * end.dy - start.dy * end.dx,
          start.dx * end.dx + start.dy * end.dy,
        );
        // A small screen-space tolerance avoids a large magnetic capture area
        // on a long reference ray, while remaining usable near the pivot.
        final radius =
            (widget.toScreen(point) - widget.toScreen(pivot)).distance;
        angle = snap.isSnapped
            ? raw
            : ArchitectRotation.snapAngle(
                raw,
                tolerance: math
                    .atan2(10, radius)
                    .clamp(math.pi / 180, math.pi / 30),
              );
      }
    });
    if (stage == 2) widget.onPreview(pivot, angle);
  }

  void accept(ArchitectSnapResult snap) {
    aim(snap);
    if (stage == 0) {
      setState(() {
        pivot = target!;
        target = null;
        stage = 1;
      });
    } else if (stage == 1) {
      if (!snap.isSnapped || (target! - pivot).distance < 1e-8) return;
      setState(() {
        reference = target;
        stage = 2;
      });
    } else if (angle.abs() > 1e-8) {
      widget.onApply(pivot, angle);
    }
  }

  Future<void> exact() async {
    final degrees = await showDialog<double>(
      context: context,
      builder: (_) => const _RotationAngleDialog(),
    );
    if (!mounted || degrees == null) return;
    setDegrees(degrees);
  }

  void setDegrees(double degrees) {
    setState(() {
      reference ??= pivot + const Offset(1, 0);
      stage = 2;
      angle = degrees * math.pi / 180;
    });
    widget.onPreview(pivot, angle);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RotationPainter(
                pivot: widget.toScreen(pivot),
                reference: reference == null
                    ? null
                    : widget.toScreen(reference!),
                target: target == null ? null : widget.toScreen(target!),
                angle: angle,
                stage: stage,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ArchitectTransformPointInput(
            key: const ValueKey('architect-rotation-input'),
            toModel: widget.toModel,
            toScreen: widget.toScreen,
            snap: (raw, touch) => widget.snap(raw, touch, stage == 1),
            localizeSnap: widget.localizeSnap,
            onAim: aim,
            onPick: accept,
            onNavigate: widget.onNavigate,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            key: const ValueKey('architect-rotation-banner'),
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(switch (stage) {
                          0 => l.architectRotationPivot,
                          1 => l.architectRotationReference,
                          _ => l.architectRotationTarget,
                        }, maxLines: 2),
                      ),
                      IconButton(
                        key: const ValueKey('architect-rotation-pick-pivot'),
                        tooltip: l.architectRotationPickPivot,
                        onPressed: () {
                          setState(() {
                            stage = 0;
                            reference = null;
                            target = null;
                            angle = 0;
                          });
                          widget.onPreview(pivot, 0);
                        },
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                      IconButton(
                        tooltip: l.cancel,
                        key: const ValueKey('architect-rotation-cancel'),
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      for (final d in [30, 45, 90])
                        Expanded(
                          child: TextButton(
                            key: ValueKey('architect-rotation-preset-$d'),
                            onPressed: () => setDegrees(d.toDouble()),
                            child: Text('$d°'),
                          ),
                        ),
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('architect-rotation-exact'),
                          onPressed: exact,
                          child: Text(
                            '${(angle * 180 / math.pi).toStringAsFixed(1)}°',
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('architect-rotation-apply'),
                        tooltip: l.applyAction,
                        onPressed: angle.abs() > 1e-8
                            ? () => widget.onApply(pivot, angle)
                            : null,
                        icon: const Icon(Icons.check),
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

class _RotationPainter extends CustomPainter {
  final Offset pivot;
  final Offset? reference, target;
  final double angle;
  final int stage;
  final Color color;
  _RotationPainter({
    required this.pivot,
    this.reference,
    this.target,
    required this.angle,
    required this.stage,
    required this.color,
  });
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final guide = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = 1;
    final ray = reference == null ? const Offset(1, 0) : reference! - pivot;
    final start = math.atan2(ray.dy, ray.dx);
    if (stage > 0) {
      final reach = size.longestSide * 2;
      for (var i = 0; i < 8; i++) {
        final a = start + i * math.pi / 4;
        final u = Offset(math.cos(a), math.sin(a));
        for (var t = 0.0; t < reach; t += 12) {
          canvas.drawLine(pivot + u * t, pivot + u * (t + 5), guide);
        }
      }
    }
    final ink = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pivot, 6, ink);
    canvas.drawLine(
      pivot - const Offset(10, 0),
      pivot + const Offset(10, 0),
      ink,
    );
    canvas.drawLine(
      pivot - const Offset(0, 10),
      pivot + const Offset(0, 10),
      ink,
    );
    if (reference != null) {
      canvas.drawLine(pivot, reference!, guide);
      canvas.drawRect(
        Rect.fromCenter(center: reference!, width: 8, height: 8),
        ink,
      );
    }
    if (stage == 2) {
      final radius = math.max(50.0, ray.distance);
      final end =
          pivot +
          Offset(math.cos(start + angle), math.sin(start + angle)) * radius;
      canvas.drawLine(pivot, end, ink);
      canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: 35),
        start,
        angle,
        false,
        ink,
      );
      canvas.drawCircle(end, 4, ink);
    } else if (target != null) {
      canvas.drawCircle(target!, 4, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _RotationPainter old) => true;
}

class _RotationAngleDialog extends StatefulWidget {
  const _RotationAngleDialog();
  @override
  State<_RotationAngleDialog> createState() => _RotationAngleDialogState();
}

class _RotationAngleDialogState extends State<_RotationAngleDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(controller.text);
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 300),
      title: Text(context.l10n.architectPropertyAngle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('architect-rotation-angle'),
              controller: controller,
              readOnly: true,
              keyboardType: TextInputType.none,
              decoration: const InputDecoration(suffixText: '°'),
            ),
            BimNumericKeypad(
              keyPrefix: 'architect-rotation-key',
              decimals: 3,
              onKey: (key) => setState(() {
                controller.text = BimNumericKeypad.edit(
                  controller.text,
                  key,
                  decimals: 3,
                );
              }),
            ),
            TextButton(
              onPressed: () => setState(() {
                controller.text = BimNumericKeypad.edit(controller.text, '±');
              }),
              child: const Text('±'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('architect-rotation-angle-apply'),
          onPressed:
              value != null &&
                  value.isFinite &&
                  value.abs() <= 360 &&
                  value != 0
              ? () => Navigator.pop(context, value)
              : null,
          child: Text(context.l10n.applyAction),
        ),
      ],
    );
  }
}
