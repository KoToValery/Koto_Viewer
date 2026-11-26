import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../models/architect_site_parcel.dart';
import '../rendering/architect_snap_helper.dart';
import '../services/architect_site_orientation.dart';
import 'architect_transform_point_input.dart';

/// An isolated canvas overlay so underlay bounds and viewport context gestures
/// cannot capture a pick. The shared input still handles pan, zoom and hold.
class ArchitectSiteOrientationOverlay extends StatefulWidget {
  final Offset Function(Offset) toModel, toScreen;
  final List<ArchitectSiteSegment> Function(Offset, bool)? pickSegments;
  final ArchitectTransformSnap snap;
  final void Function(Offset pivot, double deltaRad) onApply;
  final void Function(Offset delta, double factor, Offset focal) onNavigate;
  final VoidCallback onCancel;

  const ArchitectSiteOrientationOverlay({
    super.key,
    required this.toModel,
    required this.toScreen,
    this.pickSegments,
    required this.snap,
    required this.onApply,
    required this.onNavigate,
    required this.onCancel,
  });

  @override
  State<ArchitectSiteOrientationOverlay> createState() =>
      _ArchitectSiteOrientationOverlayState();
}

class _ArchitectSiteOrientationOverlayState
    extends State<ArchitectSiteOrientationOverlay> {
  bool _twoPoints = false;
  bool _vertical = false, _flipped = false;
  Offset? _start, _aim;
  List<ArchitectSiteSegment> _hover = const [], _choices = const [];
  int _index = 0;

  bool get _pointsMode => _twoPoints || widget.pickSegments == null;
  ArchitectSiteSegment? get _selected =>
      _choices.isEmpty ? null : _choices[_index];

  void _clear() {
    _start = _aim = null;
    _hover = _choices = const [];
    _index = 0;
    _flipped = false;
  }

  ArchitectSnapResult _resolve(Offset raw, bool touch) {
    if (_pointsMode) return widget.snap(raw, touch);
    _hover = widget.pickSegments!(raw, touch);
    if (_hover.isEmpty) return ArchitectSnapResult(point: raw);
    final (a, b) = _hover.first;
    return ArchitectSnapResult(
      point: BimLineGeometry.closest(raw, a, b),
      isSnapped: true,
    );
  }

  void _pick(Offset point) {
    setState(() {
      if (!_pointsMode) {
        if (_hover.isNotEmpty) _choices = _hover;
      } else if (_start == null) {
        _start = point;
      } else if ((point - _start!).distance > 1e-6) {
        _choices = [(_start!, point)];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final selected = _selected;
    final hint = selected != null
        ? l.architectSiteFloorPreview
        : !_pointsMode
        ? l.architectSiteSelectLine
        : _start == null
        ? l.architectSiteOrientStartHint
        : l.architectSiteOrientEndHint;
    final line =
        selected ??
        (_pointsMode
            ? (_start != null && _aim != null ? (_start!, _aim!) : null)
            : _hover.firstOrNull);
    final delta = selected == null
        ? 0.0
        : ArchitectSiteOrientation.deltaToAlignSide(
            selected.$1,
            selected.$2,
            vertical: _vertical,
            flipped: _flipped,
          );
    var side = selected == null ? Offset.zero : selected.$2 - selected.$1;
    if (side.dx < 0 || (side.dx == 0 && side.dy < 0)) side = -side;
    final turned = BimTransform2D.rotate(side, Offset.zero, delta);

    return Stack(
      children: [
        if (line != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OrientationLine(
                  widget.toScreen(line.$1),
                  widget.toScreen(line.$2),
                  theme.colorScheme.primary,
                  ends: _pointsMode,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: ArchitectTransformPointInput(
            key: ValueKey(
              selected != null
                  ? 'architect-site-orientation-review-input'
                  : 'architect-site-orientation-input',
            ),
            toModel: widget.toModel,
            toScreen: widget.toScreen,
            snap: _resolve,
            localizeSnap: (_) => null,
            pickingEnabled: selected == null,
            singlePointerPan: true,
            onAim: (snap) => setState(() => _aim = snap.point),
            onPick: (snap) => _pick(snap.point),
            onNavigate: widget.onNavigate,
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            key: const ValueKey('architect-site-orientation-banner'),
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(hint)),
                      if (selected != null)
                        SizedBox(
                          width: 60,
                          height: 30,
                          child: CustomPaint(
                            painter: _FloorSketch(
                              turned,
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      IconButton(
                        key: const ValueKey('architect-site-orientation-close'),
                        tooltip: l.cancel,
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (selected == null && widget.pickSegments != null)
                        FilterChip(
                          key: const ValueKey(
                            'architect-site-orientation-two-points',
                          ),
                          label: Text(l.architectSiteTwoPoints),
                          selected: _twoPoints,
                          onSelected: (value) => setState(() {
                            _clear();
                            _twoPoints = value;
                          }),
                        ),
                      if (selected != null) ...[
                        ChoiceChip(
                          label: Text(l.architectSiteHorizontal),
                          selected: !_vertical,
                          onSelected: (_) => setState(() => _vertical = false),
                        ),
                        ChoiceChip(
                          label: Text(l.architectSiteVertical),
                          selected: _vertical,
                          onSelected: (_) => setState(() => _vertical = true),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _flipped = !_flipped),
                          child: Text(l.architectSiteFlip),
                        ),
                        if (_choices.length > 1)
                          TextButton(
                            onPressed: () => setState(
                              () => _index = (_index + 1) % _choices.length,
                            ),
                            child: Text(l.architectSiteNextLine),
                          ),
                        TextButton(
                          key: const ValueKey(
                            'architect-site-orientation-reset',
                          ),
                          onPressed: () => setState(_clear),
                          child: Text(l.architectSiteOrientRetry),
                        ),
                        FilledButton(
                          key: const ValueKey(
                            'architect-site-orientation-apply',
                          ),
                          onPressed: () => widget.onApply(
                            (selected.$1 + selected.$2) / 2,
                            delta,
                          ),
                          child: Text(l.applyAction),
                        ),
                      ],
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

class _OrientationLine extends CustomPainter {
  final Offset start, end;
  final Color color;
  final bool ends;

  const _OrientationLine(
    this.start,
    this.end,
    this.color, {
    required this.ends,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5,
    );
    final ink = Paint()
      ..color = color
      ..strokeWidth = 3;
    canvas.drawLine(start, end, ink);
    if (ends) {
      canvas.drawCircle(start, 4, ink);
      canvas.drawCircle(end, 4, ink);
    }
  }

  @override
  bool shouldRepaint(_OrientationLine old) =>
      old.start != start ||
      old.end != end ||
      old.color != color ||
      old.ends != ends;
}

class _FloorSketch extends CustomPainter {
  final Offset side;
  final Color color;

  const _FloorSketch(this.side, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final ink = Paint()..color = color;
    canvas.drawRect(
      frame,
      Paint()
        ..color = color.withValues(alpha: .4)
        ..style = PaintingStyle.stroke,
    );
    final horizontal = side.dx.abs() > side.dy.abs();
    final at = horizontal
        ? (side.dx >= 0 ? frame.bottom : frame.top)
        : (side.dy >= 0 ? frame.left : frame.right);
    ink.strokeWidth = 3;
    if (horizontal) {
      canvas.drawLine(Offset(frame.left, at), Offset(frame.right, at), ink);
    } else {
      canvas.drawLine(Offset(at, frame.top), Offset(at, frame.bottom), ink);
    }
  }

  @override
  bool shouldRepaint(_FloorSketch old) =>
      old.side != side || old.color != color;
}
