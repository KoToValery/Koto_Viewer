import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/architect_document.dart';
import '../../bim_editing/properties/bim_distance_unit.dart';

/// One synchronous publication scope, never a mutable global rendering setting.
class ArchitectTextScope {
  static final _key = Object();
  static ArchitectTextScope? get current =>
      Zone.current[_key] as ArchitectTextScope?;
  final ArchitectDocument document;
  final String view;
  final int denominator;
  final double renderScale;
  final BimDistanceUnit units;
  final int decimals;
  final bool publication;
  const ArchitectTextScope(
    this.document,
    this.view,
    this.denominator,
    this.renderScale, {
    this.units = BimDistanceUnit.meters,
    this.decimals = 2,
    this.publication = false,
  });
  T run<T>(T Function() body) => runZoned(body, zoneValues: {_key: this});
  double height(String id, ArchitectAnnotationRole role) =>
      ArchitectDrawingScale(
        denominator,
      ).paperToModel(document.textMm(view, id, role, denominator));
  String length(double metres) =>
      BimDistanceUnit.trimZeros(units.format(metres, decimals: decimals));
  double fontSize(String id, ArchitectAnnotationRole role) =>
      height(id, role) / ArchitectDrawingScale.fontCapRatio;
  String number(double metres) =>
      BimDistanceUnit.trimZeros(units.toUnit(metres).toStringAsFixed(decimals));
  String area(double squareMetres) =>
      units.formatArea(squareMetres, decimals: decimals);
}

InlineSpan? _styleSpan(
  InlineSpan? span,
  String? id,
  ArchitectAnnotationRole role,
  double? modelScale,
) {
  final scope = ArchitectTextScope.current;
  if (scope == null || span is! TextSpan) return span;
  if (span is ArchitectAnnotationSpan) role = span.role;
  final original = span.style ?? const TextStyle();
  if (id == null && !scope.publication) {
    return TextSpan(
      text: span.text,
      style: original.copyWith(fontFamily: 'ArchitectNoto'),
      children: span.children
          ?.map((e) => _styleSpan(e, id, role, modelScale)!)
          .toList(),
    );
  }
  final size =
      scope.fontSize(id ?? '', role) /
      (modelScale ??
          ((original.fontSize ?? 12) < 1 ? 1 : 1 / scope.renderScale));
  return ArchitectAnnotationSpan(
    role: role,
    text: span.text,
    style: original.copyWith(fontFamily: 'ArchitectNoto', fontSize: size),
    children: span.children
        ?.map((e) => _styleSpan(e, id, role, modelScale)!)
        .toList(),
  );
}

class ArchitectAnnotationSpan extends TextSpan {
  final ArchitectAnnotationRole role;
  const ArchitectAnnotationSpan({
    required this.role,
    super.text,
    super.style,
    super.children,
  });
}

/// Text remains real text in PDF; the same measured lines are used on screen.
class ArchitectTextPainter {
  final String? elementId;
  final ArchitectAnnotationRole role;
  late final TextPainter _inner;
  late final InlineSpan? text;
  late final double _normalization;
  ArchitectTextPainter({
    InlineSpan? text,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    int? maxLines,
    String? ellipsis,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
    TextHeightBehavior? textHeightBehavior,
    StrutStyle? strutStyle,
    Locale? locale,
    this.elementId,
    this.role = ArchitectAnnotationRole.ordinary,
    double? modelScale,
  }) {
    this.text = _styleSpan(text, elementId, role, modelScale);
    double minimum(InlineSpan? span) {
      if (span is! TextSpan) return 12;
      var value = span.style?.fontSize ?? 12;
      for (final child in span.children ?? <InlineSpan>[]) {
        value = math.min(value, minimum(child));
      }
      return value;
    }

    _normalization = minimum(this.text) < 1 ? 1000 : 1;
    InlineSpan? normalized(InlineSpan? span) {
      if (span is! TextSpan) return span;
      final style = span.style;
      return TextSpan(
        text: span.text,
        style: style?.copyWith(
          fontSize: style.fontSize == null
              ? null
              : style.fontSize! * _normalization,
        ),
        children: span.children?.map((e) => normalized(e)!).toList(),
      );
    }

    _inner = TextPainter(
      text: normalized(this.text),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      ellipsis: ellipsis,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      strutStyle: strutStyle,
      locale: locale,
    );
  }
  double get width => _inner.width / _normalization;
  double get height => _inner.height / _normalization;
  Size get size => Size(width, height);
  void layout({double minWidth = 0, double maxWidth = double.infinity}) =>
      _inner.layout(
        minWidth: minWidth * _normalization,
        maxWidth: maxWidth * _normalization,
      );
  TextRange getLineBoundary(TextPosition position) =>
      _inner.getLineBoundary(position);
  List<ui.LineMetrics> computeLineMetrics() => _inner
      .computeLineMetrics()
      .map(
        (m) => ui.LineMetrics(
          hardBreak: m.hardBreak,
          ascent: m.ascent / _normalization,
          descent: m.descent / _normalization,
          unscaledAscent: m.unscaledAscent / _normalization,
          height: m.height / _normalization,
          width: m.width / _normalization,
          left: m.left / _normalization,
          baseline: m.baseline / _normalization,
          lineNumber: m.lineNumber,
        ),
      )
      .toList();
  void paint(Canvas canvas, Offset offset) {
    if (canvas is ArchitectVectorCanvas) {
      final plain = text?.toPlainText() ?? '';
      var start = 0;
      for (final line in computeLineMetrics()) {
        final boundary = getLineBoundary(TextPosition(offset: start));
        final end = boundary.end.clamp(start, plain.length);
        final value = plain.substring(start, end).replaceAll('\n', '');
        final span = text?.getSpanForPosition(TextPosition(offset: start));
        final style = span is TextSpan
            ? span.style ?? const TextStyle()
            : const TextStyle();
        if (value.isNotEmpty) {
          canvas.text(
            value,
            offset + Offset(line.left, line.baseline - line.ascent),
            style,
            elementId,
            span is ArchitectAnnotationSpan ? span.role : role,
          );
        }
        start = end;
        if (start < plain.length && plain[start] == '\n') start++;
      }
    } else {
      canvas.save();
      canvas.scale(1 / _normalization);
      _inner.paint(canvas, offset * _normalization);
      canvas.restore();
    }
  }
}

sealed class ArchitectVectorOp {
  final Path? clip;
  final Set<String> sources;
  final String role;
  const ArchitectVectorOp(this.clip, this.sources, this.role);
  Rect get bounds;
  void paint(Canvas canvas);
}

class ArchitectVectorPath extends ArchitectVectorOp {
  final Path path;
  final Color color;
  final double width;
  final bool fill;
  ArchitectVectorPath(
    this.path,
    this.color,
    this.width,
    this.fill,
    super.clip,
    super.sources,
    super.role,
  );
  @override
  Rect get bounds => path.getBounds().inflate(fill ? 0 : width / 2);
  @override
  void paint(Canvas canvas) => canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round,
  );
}

class ArchitectVectorText extends ArchitectVectorOp {
  final String text;
  final Offset position;
  final double size, rotation;
  final Color color;
  final FontWeight weight;
  ArchitectVectorText(
    this.text,
    this.position,
    this.size,
    this.rotation,
    this.color,
    this.weight,
    super.clip,
    super.sources,
    super.role,
  );
  TextPainter get painter => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'ArchitectNoto',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  @override
  Rect get bounds {
    final tp = painter;
    final transform = Matrix4.identity()
      ..translateByDouble(position.dx, position.dy, 0, 1)
      ..rotateZ(rotation);
    return MatrixUtils.transformRect(transform, Offset.zero & tp.size);
  }

  @override
  void paint(Canvas canvas) {
    if (canvas is ArchitectVectorCanvas) {
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(rotation);
      canvas.text(
        text,
        Offset.zero,
        TextStyle(fontSize: size, color: color, fontWeight: weight),
        sources.length == 1 ? sources.first : null,
        ArchitectAnnotationRole.values.firstWhere(
          (e) => e.name == role,
          orElse: () => ArchitectAnnotationRole.ordinary,
        ),
      );
      canvas.restore();
      return;
    }
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

class ArchitectVectorScene {
  final List<ArchitectVectorOp> operations;
  final int denominator;
  const ArchitectVectorScene(this.operations, this.denominator);
  Rect get bounds {
    Rect? result;
    for (final op in operations) {
      result = result?.expandToInclude(op.bounds) ?? op.bounds;
    }
    return result ?? const Rect.fromLTWH(0, 0, 10, 10);
  }

  void paint(Canvas canvas) {
    for (final op in operations) {
      canvas.save();
      if (op.clip != null) canvas.clipPath(op.clip!);
      architectDrawingSources(canvas, op.sources, op.role);
      op.paint(canvas);
      canvas.restore();
    }
  }
}

/// Records the existing boolean-clean drafting paths, without rasterizing them.
/// Every operation keeps its clipping and source provenance for future edits.
class ArchitectVectorCanvas implements Canvas {
  final List<ArchitectVectorOp> operations = [];
  final Set<String> sourceIds;
  Set<String>? _owners;
  String? _role;
  void sources(Set<String> owners, String role) {
    _owners = Set.unmodifiable(owners);
    _role = role;
  }

  Matrix4 _matrix = Matrix4.identity();
  Path? _clip;
  final List<(Matrix4, Path?)> _stack = [];
  ArchitectVectorCanvas({this.sourceIds = const {}});
  double get _scale => math.sqrt(
    _matrix.entry(0, 0) * _matrix.entry(0, 0) +
        _matrix.entry(1, 0) * _matrix.entry(1, 0),
  );
  Offset _point(Offset p) => MatrixUtils.transformPoint(_matrix, p);
  void text(
    String text,
    Offset at,
    TextStyle style,
    String? id,
    ArchitectAnnotationRole role,
  ) {
    operations.add(
      ArchitectVectorText(
        text,
        _point(at),
        (style.fontSize ?? 12) * _scale,
        math.atan2(_matrix.entry(1, 0), _matrix.entry(0, 0)),
        style.color ?? Colors.black,
        style.fontWeight ?? FontWeight.normal,
        _clip,
        id == null ? (_owners ?? sourceIds) : {id},
        role.name,
      ),
    );
  }

  @override
  void drawPath(Path path, Paint paint) {
    if (paint.color.a == 0) return;
    final transformed = path.transform(_matrix.storage);
    var color = paint.color;
    if (paint.style == PaintingStyle.fill &&
        transformed.getBounds().size.width *
                transformed.getBounds().size.height >
            2 &&
        color.computeLuminance() < .8) {
      color = color.withValues(alpha: math.min(color.a, .08));
    }
    operations.add(
      ArchitectVectorPath(
        transformed,
        color,
        paint.strokeWidth * _scale,
        paint.style == PaintingStyle.fill,
        _clip,
        _owners ?? sourceIds,
        _role ?? paint.style.name,
      ),
    );
  }

  @override
  void save() => _stack.add((Matrix4.copy(_matrix), _clip));
  @override
  void restore() {
    final state = _stack.removeLast();
    _matrix = state.$1;
    _clip = state.$2;
  }

  @override
  int getSaveCount() => _stack.length + 1;
  @override
  void restoreToCount(int count) {
    while (getSaveCount() > count) {
      restore();
    }
  }

  @override
  void translate(double dx, double dy) =>
      _matrix.translateByDouble(dx, dy, 0, 1);
  @override
  void scale(double sx, [double? sy]) =>
      _matrix.scaleByDouble(sx, sy ?? sx, 1, 1);
  @override
  void rotate(double radians) => _matrix.rotateZ(radians);
  @override
  void transform(Float64List matrix4) =>
      _matrix.multiply(Matrix4.fromFloat64List(matrix4));
  @override
  Float64List getTransform() => Float64List.fromList(_matrix.storage);
  @override
  void skew(double sx, double sy) {
    final m = Matrix4.identity()
      ..setEntry(0, 1, sx)
      ..setEntry(1, 0, sy);
    _matrix.multiply(m);
  }

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {
    final p = path.transform(_matrix.storage);
    _clip = _clip == null
        ? p
        : Path.combine(PathOperation.intersect, _clip!, p);
  }

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    final p = (Path()..addRect(rect)).transform(_matrix.storage);
    if (clipOp == ui.ClipOp.difference) {
      _clip = Path.combine(
        PathOperation.difference,
        _clip ?? (Path()..addRect(const Rect.fromLTRB(-1e6, -1e6, 1e6, 1e6))),
        p,
      );
    } else {
      _clip = _clip == null
          ? p
          : Path.combine(PathOperation.intersect, _clip!, p);
    }
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) =>
      clipPath(Path()..addRRect(rrect));
  @override
  Rect getLocalClipBounds() {
    final inverse = Matrix4.inverted(_matrix);
    return MatrixUtils.transformRect(inverse, getDestinationClipBounds());
  }

  @override
  Rect getDestinationClipBounds() =>
      _clip?.getBounds() ?? const Rect.fromLTRB(-1000, -1000, 1000, 1000);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => drawPath(
    Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy),
    Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke,
  );
  @override
  void drawRect(Rect rect, Paint paint) =>
      drawPath(Path()..addRect(rect), paint);
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      drawPath(Path()..addRRect(rrect), paint);
  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) => drawPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner),
    paint,
  );
  @override
  void drawOval(Rect rect, Paint paint) =>
      drawPath(Path()..addOval(rect), paint);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      drawOval(Rect.fromCircle(center: c, radius: radius), paint);
  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    final path = Path();
    if (useCenter) path.moveTo(rect.center.dx, rect.center.dy);
    path.arcTo(rect, startAngle, sweepAngle, !useCenter);
    if (useCenter) path.close();
    drawPath(path, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      throw StateError('Publication text must use ArchitectTextPainter');
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unrecorded drawing operation: ${invocation.memberName}',
  );
}

void architectDrawingSources(Canvas canvas, Iterable<String> ids, String role) {
  if (canvas is ArchitectVectorCanvas) canvas.sources(ids.toSet(), role);
}
