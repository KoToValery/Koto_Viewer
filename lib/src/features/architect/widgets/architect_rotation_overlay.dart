import 'architect_dialog.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_rotation.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
import '../rendering/architect_snap_helper.dart';
import '../rendering/architect_angular_guides.dart';
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
  final bool alignReferenceToAxes;
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
    this.alignReferenceToAxes = false,
  });
  @override
  State<ArchitectRotationOverlay> createState() => _RotationState();
}

enum _UnderlayAlignAxis { auto, horizontal, vertical }

class _RotationState extends State<ArchitectRotationOverlay> {
  late Offset pivot = widget.initialPivot;
  Offset? reference, target;
  double angle = 0;
  int stage = 0;
  _UnderlayAlignAxis _alignAxis = _UnderlayAlignAxis.auto;

  static double _angleBetween(Offset start, Offset end) => math.atan2(
    start.dx * end.dy - start.dy * end.dx,
    start.dx * end.dx + start.dy * end.dy,
  );

  static double _normalizeAngle(double radians) {
    if (!radians.isFinite) return 0;
    var a = radians % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a <= -math.pi) a += 2 * math.pi;
    return a;
  }

  static double _alignmentAngle(Offset ray, _UnderlayAlignAxis mode) {
    if (ray.distanceSquared < 1e-12) return 0;
    final current = math.atan2(ray.dy, ray.dx);
    final candidates = switch (mode) {
      _UnderlayAlignAxis.horizontal => const [0.0, math.pi],
      _UnderlayAlignAxis.vertical => const [math.pi / 2, -math.pi / 2],
      _UnderlayAlignAxis.auto => const [0.0, math.pi / 2, math.pi, -math.pi / 2],
    };
    var bestDelta = double.infinity;
    for (final target in candidates) {
      final delta = _normalizeAngle(target - current);
      if (delta.abs() < bestDelta.abs()) {
        bestDelta = delta;
      }
    }
    return bestDelta.abs() <= 1e-8 ? 0 : bestDelta;
  }

  void aim(ArchitectSnapResult snap) {
    if (widget.alignReferenceToAxes && stage == 2) return;
    final point = snap.point;
    setState(() {
      target = point;
      if (stage == 2 && (point - pivot).distance > 1e-8) {
        final start = reference! - pivot, end = point - pivot;
        final raw = _angleBetween(start, end);
        // A small screen-space tolerance avoids a large magnetic capture area
        // on a long reference ray, while remaining usable near the pivot.
        final radius =
            (widget.toScreen(point) - widget.toScreen(pivot)).distance;
        final tol = math
            .atan2(10, radius)
            .clamp(math.pi / 180, math.pi / 30);
        if (snap.isSnapped) {
          angle = raw;
        } else {
          angle = ArchitectRotation.snapAngle(raw, tolerance: tol);
        }
      }
    });
    if (stage == 2) widget.onPreview(pivot, angle);
  }

  void accept(ArchitectSnapResult snap) {
    if (widget.alignReferenceToAxes && stage == 2) return;
    aim(snap);
    if (stage == 0) {
      setState(() {
        pivot = target!;
        target = null;
        stage = 1;
      });
    } else if (stage == 1) {
      if ((!snap.isSnapped && !widget.alignReferenceToAxes) ||
          (target! - pivot).distance < 1e-8) {
        return;
      }
      final ref = target!;
      if (widget.alignReferenceToAxes) {
        final nextAngle = _alignmentAngle(ref - pivot, _alignAxis);
        setState(() {
          reference = ref;
          angle = nextAngle;
          stage = 2;
        });
        widget.onPreview(pivot, nextAngle);
        return;
      }
      setState(() {
        reference = ref;
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
    applyAngle(degrees * math.pi / 180);
  }

  void _selectUnderlayAxis(_UnderlayAlignAxis mode) {
    setState(() {
      _alignAxis = mode;
      if (stage == 2 && reference != null) {
        angle = _alignmentAngle(reference! - pivot, mode);
      }
    });
    if (stage == 2 && reference != null) {
      widget.onPreview(pivot, angle);
    }
  }

  void _rotatePlus90() {
    final nextAngle = _normalizeAngle(angle + math.pi / 2);
    setState(() {
      reference ??= pivot + const Offset(1, 0);
      stage = 2;
      angle = nextAngle;
    });
    widget.onPreview(pivot, nextAngle);
  }

  void _resetPicking() {
    setState(() {
      stage = 0;
      reference = null;
      target = null;
      angle = 0;
    });
    widget.onPreview(pivot, 0);
  }

  void _confirmUnderlayAlignment() {
    if (angle.abs() <= 1e-8) {
      widget.onCancel();
    } else {
      widget.onApply(pivot, angle);
    }
  }

  void applyAngle(double radians) {
    setState(() {
      reference ??= pivot + const Offset(1, 0);
      stage = 2;
      angle = radians;
    });
    widget.onPreview(pivot, angle);
    if (angle.abs() > 1e-8) widget.onApply(pivot, angle);
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
                alignReferenceToAxes: widget.alignReferenceToAxes,
              ),
            ),
          ),
        ),
        if (!(widget.alignReferenceToAxes && stage == 2))
          Positioned.fill(
            child: ArchitectTransformPointInput(
              key: const ValueKey('architect-rotation-input'),
              toModel: widget.toModel,
              toScreen: widget.toScreen,
              snap: (raw, touch) => widget.snap(
                raw,
                touch,
                widget.alignReferenceToAxes ? stage < 2 : stage == 1,
              ),
              localizeSnap: widget.localizeSnap,
              onAim: aim,
              onPick: accept,
              onNavigate: widget.onNavigate,
            ),
          ),
        Positioned(
          top: widget.alignReferenceToAxes ? 8 : null,
          bottom: widget.alignReferenceToAxes ? null : 8,
          left: 8,
          right: 8,
          child: Material(
            key: const ValueKey('architect-rotation-banner'),
            color: Theme.of(context).colorScheme.surface,
            elevation: widget.alignReferenceToAxes ? 3 : 0,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(switch (stage) {
                          0 => widget.alignReferenceToAxes
                              ? l.architectUnderlayRotationStart
                              : l.architectRotationPivot,
                          1 => widget.alignReferenceToAxes
                              ? l.architectUnderlayRotationEnd
                              : l.architectRotationReference,
                          _ => widget.alignReferenceToAxes
                              ? l.architectUnderlayRotationReview(
                                  (angle * 180 / math.pi).toStringAsFixed(1),
                                )
                              : l.architectRotationTarget,
                        }, maxLines: 2),
                      ),
                      IconButton(
                        key: const ValueKey('architect-rotation-pick-pivot'),
                        tooltip: l.architectRotationPickPivot,
                        onPressed: _resetPicking,
                        icon: const AppIcon(AppIconId.fitView),
                      ),
                      if (widget.alignReferenceToAxes)
                        IconButton(
                          key: const ValueKey('architect-rotation-close'),
                          tooltip: l.cancel,
                          onPressed: widget.onCancel,
                          icon: const AppIcon(AppIconId.close),
                        ),
                    ],
                  ),
                  if (widget.alignReferenceToAxes) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('architect-rotation-auto'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(l.architectUnderlayAlignAuto),
                          selected: _alignAxis == _UnderlayAlignAxis.auto,
                          onSelected: (_) =>
                              _selectUnderlayAxis(_UnderlayAlignAxis.auto),
                        ),
                        ChoiceChip(
                          key: const ValueKey('architect-rotation-horizontal'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(l.architectUnderlayAlignHorizontal),
                          selected:
                              _alignAxis == _UnderlayAlignAxis.horizontal,
                          onSelected: (_) => _selectUnderlayAxis(
                            _UnderlayAlignAxis.horizontal,
                          ),
                        ),
                        ChoiceChip(
                          key: const ValueKey('architect-rotation-vertical'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(l.architectUnderlayAlignVertical),
                          selected: _alignAxis == _UnderlayAlignAxis.vertical,
                          onSelected: (_) =>
                              _selectUnderlayAxis(_UnderlayAlignAxis.vertical),
                        ),
                        ActionChip(
                          key: const ValueKey('architect-rotation-exact'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(l.architectPropertyAngle),
                          onPressed: exact,
                        ),
                      ],
                    ),
                    if (stage == 2) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('architect-rotation-rotate90'),
                            onPressed: _rotatePlus90,
                            icon: const AppIcon(AppIconId.rotate, size: 16),
                            label: Text(l.architectUnderlayRotatePlus90),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('architect-rotation-retry'),
                            onPressed: _resetPicking,
                            icon: const AppIcon(AppIconId.refresh, size: 16),
                            label: Text(l.architectSiteOrientRetry),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('architect-rotation-apply'),
                            onPressed: _confirmUnderlayAlignment,
                            icon: const AppIcon(AppIconId.confirm, size: 16),
                            label: Text(l.applyAction),
                          ),
                        ],
                      ),
                    ],
                  ] else
                    Row(
                      children: [
                        for (final d in [30, 45, 90])
                          Expanded(
                            child: TextButton(
                              key: ValueKey('architect-rotation-preset-$d'),
                              onPressed: () => applyAngle(d * math.pi / 180),
                              child: Text('$d°'),
                            ),
                          ),
                        Expanded(
                          child: Tooltip(
                            message: l.architectPropertyAngle,
                            child: TextButton(
                              key: const ValueKey('architect-rotation-exact'),
                              onPressed: exact,
                              child: Text('${(angle * 180 / math.pi).toStringAsFixed(1)}°'),
                            ),
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

class _RotationPainter extends CustomPainter {
  final Offset pivot;
  final Offset? reference, target;
  final double angle;
  final int stage;
  final Color color;
  final bool alignReferenceToAxes;
  _RotationPainter({
    required this.pivot,
    this.reference,
    this.target,
    required this.angle,
    required this.stage,
    required this.color,
    this.alignReferenceToAxes = false,
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
      final double? activeAngle;
      if (stage == 2) {
        activeAngle = start + angle;
      } else if (alignReferenceToAxes &&
          target != null &&
          (target! - pivot).distance > 1e-8) {
        activeAngle = math.atan2(target!.dy - pivot.dy, target!.dx - pivot.dx);
      } else {
        activeAngle = null;
      }
      ArchitectAngularGuides.paint(
        canvas,
        size,
        pivot: pivot,
        color: color,
        referenceAngle: alignReferenceToAxes ? 0 : start,
        activeAngle: activeAngle,
        divisions: alignReferenceToAxes ? 4 : 8,
      );
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
  String? _input;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(controller.text);
    return architectAlertDialog(
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
              onChanged: (text) => setState(() => _input = text),
            ),
            BimNumericKeypad(
              keyPrefix: 'architect-rotation-key',
              decimals: 3,
              onKey: (key) => setState(() {
                _input = BimNumericKeypad.edit(
                  _input,
                  key,
                  decimals: 3,
                );
                controller.text = _input!;
              }),
            ),
            TextButton(
              onPressed: () => setState(() {
                _input = BimNumericKeypad.edit(_input ?? controller.text, '±');
                controller.text = _input!;
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
