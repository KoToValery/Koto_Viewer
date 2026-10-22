import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Small vector sketchpad: point-by-point or freehand, with multiple strokes.
class ArchitectLineSymbolSketch extends StatefulWidget {
  final List<List<Offset>> initial;
  const ArchitectLineSymbolSketch({super.key, this.initial = const []});
  @override
  State<ArchitectLineSymbolSketch> createState() =>
      _ArchitectLineSymbolSketchState();
}

class _ArchitectLineSymbolSketchState extends State<ArchitectLineSymbolSketch> {
  late final List<List<Offset>> _strokes;
  bool _points = true, _newStroke = true;
  @override
  void initState() {
    super.initState();
    _strokes = [for (final s in widget.initial) List.of(s)];
  }

  int get _count => _strokes.fold(0, (n, s) => n + s.length);
  bool get _valid => _strokes.any(
    (s) => s.length >= 2 && s.any((p) => (p - s.first).distance > .001),
  );
  void _add(Offset raw, Size size) {
    if (_count >= 512 || (_newStroke && _strokes.length >= 16)) return;
    final frame = _SketchPainter.frame(size);
    final point = Offset(
      ((raw.dx - frame.center.dx) / frame.width).clamp(-.5, .5),
      ((raw.dy - frame.center.dy) / frame.height).clamp(-.5, .5),
    );
    setState(() {
      if (_newStroke || _strokes.isEmpty) {
        _strokes.add([]);
        _newStroke = false;
      }
      if (_strokes.last.isEmpty ||
          (_strokes.last.last - point).distance >= .008) {
        _strokes.last.add(point);
      }
    });
  }

  void _finish() {
    setState(() {
      if (_strokes.isNotEmpty && _strokes.last.length < 2) {
        _strokes.removeLast();
      }
      _newStroke = true;
    });
  }

  List<List<Offset>> _result() {
    final strokes = _strokes
        .where(
          (s) => s.length >= 2 && s.any((p) => (p - s.first).distance > .001),
        )
        .toList();
    final points = strokes.expand((s) => s).toList();
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final p in points.skip(1)) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    final side = math.max(bounds.width, bounds.height);
    return List.unmodifiable([
      for (final s in strokes)
        List<Offset>.unmodifiable(s.map((p) => (p - bounds.center) / side)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.architectLineSymbolCustom),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.architectLineSymbolDrawHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('line-symbol-points'),
                    tooltip: l.architectLineSymbolPoints,
                    isSelected: _points,
                    icon: const Icon(Icons.polyline_outlined),
                    onPressed: () {
                      _finish();
                      setState(() => _points = true);
                    },
                  ),
                  IconButton(
                    key: const ValueKey('line-symbol-freehand'),
                    tooltip: l.architectLineSymbolFreehand,
                    isSelected: !_points,
                    icon: const Icon(Icons.gesture),
                    onPressed: () {
                      _finish();
                      setState(() => _points = false);
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('line-symbol-undo'),
                    tooltip: l.undoAction,
                    icon: const Icon(Icons.undo),
                    onPressed: _strokes.isEmpty
                        ? null
                        : () => setState(() {
                            _strokes.last.removeLast();
                            if (_strokes.last.isEmpty) _strokes.removeLast();
                            _newStroke = _strokes.isEmpty;
                          }),
                  ),
                  IconButton(
                    key: const ValueKey('line-symbol-clear'),
                    tooltip: l.clear,
                    icon: const Icon(Icons.clear_all),
                    onPressed: () => setState(() {
                      _strokes.clear();
                      _newStroke = true;
                    }),
                  ),
                ],
              ),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final size = Size(constraints.maxWidth, 220);
                    return GestureDetector(
                      key: const ValueKey('line-symbol-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _points
                          ? (e) => _add(e.localPosition, size)
                          : null,
                      onPanStart: _points
                          ? null
                          : (e) {
                              _finish();
                              _add(e.localPosition, size);
                            },
                      onPanUpdate: _points
                          ? null
                          : (e) => _add(e.localPosition, size),
                      onPanEnd: _points ? null : (_) => _finish(),
                      onPanCancel: _points ? null : _finish,
                      child: CustomPaint(
                        size: size,
                        painter: _SketchPainter([
                          for (final s in _strokes) List.of(s),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  TextButton(
                    key: const ValueKey('line-symbol-new-stroke'),
                    onPressed: _finish,
                    child: Text(l.architectLineSymbolNewStroke),
                  ),
                  TextButton(
                    key: const ValueKey('line-symbol-close-stroke'),
                    onPressed:
                        _strokes.isEmpty ||
                            _strokes.last.length < 3 ||
                            _newStroke ||
                            _count >= 512
                        ? null
                        : () {
                            setState(
                              () => _strokes.last.add(_strokes.last.first),
                            );
                            _finish();
                          },
                    child: Text(l.architectLineSymbolCloseStroke),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('line-symbol-shape-save'),
          onPressed: !_valid ? null : () => Navigator.pop(context, _result()),
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SketchPainter(this.strokes);
  static Rect frame(Size size) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: math.max(1, math.min(size.width, size.height) - 24),
    height: math.max(1, math.min(size.width, size.height) - 24),
  );
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final area = frame(size);
    final grid = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = .7;
    for (var i = 0; i <= 8; i++) {
      final t = i / 8;
      canvas.drawLine(
        Offset(area.left + area.width * t, area.top),
        Offset(area.left + area.width * t, area.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(area.left, area.top + area.height * t),
        Offset(area.right, area.top + area.height * t),
        grid,
      );
    }
    final path = Path();
    for (final s in strokes) {
      for (var i = 0; i < s.length; i++) {
        final p = area.center + s[i] * area.width;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawCircle(p, 2, Paint()..color = const Color(0xFF007F8A));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF212121)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}
