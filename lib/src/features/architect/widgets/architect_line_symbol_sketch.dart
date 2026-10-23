import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_line_symbol.dart';
import '../models/architect_line_style.dart';
import '../models/architect_hatch_pattern.dart';
import '../rendering/architect_hatch_geometry.dart';
import '../rendering/architect_line_pattern.dart';

/// Small vector sketchpad: point-by-point or freehand, with multiple strokes.
class ArchitectLineSymbolSketch extends StatefulWidget {
  final List<List<Offset>> initial;
  final bool tilePreview;
  final double previewSizeMm, previewSpacingMm, previewRowSpacingMm, previewAngleDeg;
  const ArchitectLineSymbolSketch({super.key, this.initial = const [], this.tilePreview = false,
    this.previewSizeMm=4,this.previewSpacingMm=8,this.previewRowSpacingMm=8,this.previewAngleDeg=0});
  @override
  State<ArchitectLineSymbolSketch> createState() =>
      _ArchitectLineSymbolSketchState();
}

class _ArchitectLineSymbolSketchState extends State<ArchitectLineSymbolSketch> {
  late final List<List<Offset>> _strokes;
  bool _points = true, _newStroke = true;
  bool _ortho = false;
  (int,int)? _dragVertex;
  Offset? _panOrigin;
  void _startVertexDrag(Offset raw,Size size) {
    _dragVertex=null;
    final area=_SketchPainter.frame(size);
    for(var i=0;i<_strokes.length;i++) {
      for(var j=0;j<_strokes[i].length;j++) {
        if((area.center+_strokes[i][j]*area.width-raw).distance<14) {
          _dragVertex=(i,j);return;
        }
      }
    }
  }
  void _moveVertex(Offset raw,Size size) {
    final vertex=_dragVertex;
    if(vertex==null) return;
    final area=_SketchPainter.frame(size);
    final p=Offset((((raw.dx-area.center.dx)/area.width).clamp(-.5,.5)*32).round()/32,
      (((raw.dy-area.center.dy)/area.height).clamp(-.5,.5)*32).round()/32);
    setState(() {
      final stroke=_strokes[vertex.$1];
      final closed=stroke.length>2 && stroke.first==stroke.last;
      stroke[vertex.$2]=p;
      if(closed && (vertex.$2==0 || vertex.$2==stroke.length-1)) {
        stroke[0]=p;stroke[stroke.length-1]=p;
      }
    });
  }
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
    var point = Offset(
      ((raw.dx - frame.center.dx) / frame.width).clamp(-.5, .5),
      ((raw.dy - frame.center.dy) / frame.height).clamp(-.5, .5),
    );
    if (_points) {
      // A fine, stable grid makes repeated click-built segments controllable.
      point = Offset((point.dx * 32).round() / 32, (point.dy * 32).round() / 32);
      if (_ortho && !_newStroke && _strokes.isNotEmpty && _strokes.last.isNotEmpty) {
        final last=_strokes.last.last, delta=point-last;
        point=delta.dx.abs()>delta.dy.abs()?Offset(point.dx,last.dy):Offset(last.dx,point.dy);
      }
    }
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
              Wrap(
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

                  IconButton(
                    key: const ValueKey('line-symbol-ortho'),
                    tooltip:l.architectSketchOrtho,
                    isSelected:_ortho,
                    icon:const Icon(Icons.square_foot),
                    onPressed:()=>setState(()=>_ortho=!_ortho),
                  ),
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
                      onTapUp: _points
                          ? (e) => _add(e.localPosition, size)
                          : null,
                      onPanDown:(e)=>_panOrigin=e.localPosition,
                      onPanStart: _points
                          ? (e)=>_startVertexDrag(_panOrigin??e.localPosition,size)
                          : (e) {
                              _finish();
                              _add(_panOrigin??e.localPosition, size);
                              _add(e.localPosition, size);
                            },
                      onPanUpdate: _points
                          ? (e)=>_moveVertex(e.localPosition,size)
                          : (e) => _add(e.localPosition, size),
                      onPanEnd: _points ? (_)=>_dragVertex=null : (_) => _finish(),
                      onPanCancel: _points ? ()=>_dragVertex=null : _finish,
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
              ...[
                Text(l.architectSketchPreview),
                SizedBox(height:widget.tilePreview?100:42,width:double.infinity,
                  child:CustomPaint(painter:_valid?_SketchRepeatPainter(_result(),widget.tilePreview,widget.previewSizeMm,widget.previewSpacingMm,widget.previewRowSpacingMm,widget.previewAngleDeg):null)),
              ],
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

class _SketchRepeatPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool tile;
  final double sizeMm, spacingMm, rowMm, angleDeg;
  _SketchRepeatPainter(this.strokes,this.tile,this.sizeMm,this.spacingMm,this.rowMm,this.angleDeg);
  @override
  void paint(Canvas canvas,Size size) {
    final symbol=ArchitectLineSymbol(shape:ArchitectLineSymbolShape.custom,
      strokes:strokes,sizeMm:sizeMm,spacingMm:spacingMm,clearLine:false);
    final style=ArchitectLineStyle(id:'preview',name:'_',segmentsMm:[],symbol:symbol);
    final boundary=Path()..addRect(Offset.zero&size);
    canvas.save();canvas.clipRect(Offset.zero&size);
    final path=tile?ArchitectHatchGeometry.path(boundary:boundary,
      pattern:ArchitectHatchPattern(id:'preview',name:'_',layers:[
        ArchitectHatchLayer(angleDeg:angleDeg,spacingMm:rowMm,lineStyle:style,symbolsOnly:true)]),unitsPerMm:3)
      :ArchitectLinePattern.path(Path()..moveTo(0,size.height/2)..lineTo(size.width,size.height/2),style,3);
    canvas.drawPath(path,Paint()..color=const Color(0xFF212121)
      ..style=PaintingStyle.stroke..strokeWidth=1);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _SketchRepeatPainter old)=>true;
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
