import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../models/architect_line_style.dart';
import '../models/architect_line_symbol.dart';

class ArchitectLinePattern {
  /// All components are vector strokes. Dash phase follows the original contour
  /// even where a symbol interrupts it; rectangles retain phase around corners.
  static Path path(
    Path source,
    ArchitectLineStyle style,
    double unitsPerMm, {
    double phase = 0,
  }) {
    style.validate();
    if (!unitsPerMm.isFinite || unitsPerMm <= 0 || !phase.isFinite) {
      throw ArgumentError('Invalid pattern scale');
    }
    if (style.isSolid && style.symbol == null) return source;
    final lengths = style.segmentsMm.map((v) => v * unitsPerMm).toList();
    final output = Path();
    final symbol = style.symbol;
    final glyph = symbol == null ? null : symbolPath(symbol);
    for (final contour in source.computeMetrics()) {
      final cuts = <(double, double)>[];
      if (symbol != null && glyph != null && contour.length > 1e-9) {
        final spacing = symbol.spacingMm * unitsPerMm;
        final stations = <double>[];
        if (contour.length < spacing && phase == 0) {
          stations.add(contour.length / 2);
        } else {
          for (
            var at = (spacing / 2 - phase) % spacing;
            at < contour.length;
            at += spacing
          ) {
            stations.add(at);
          }
        }
        for (final at in stations) {
          final tangent = contour.getTangentForOffset(at)!;
          final direction = tangent.vector;
          final pathAngle = math.atan2(direction.dy, direction.dx);
          final angle =
              (symbol.followLine ? pathAngle : 0) +
              symbol.angleDeg * math.pi / 180;
          final relative = angle - pathAngle;
          final size = symbol.sizeMm * unitsPerMm;
          final bounds = glyph.getBounds();
          final projected = [
            for (final p in [
              bounds.topLeft,
              bounds.topRight,
              bounds.bottomLeft,
              bounds.bottomRight,
            ])
              (p.dx * math.cos(relative) - p.dy * math.sin(relative)).abs() *
                  size,
          ];
          final halfSpan = projected.reduce(math.max) + .35 * unitsPerMm;
          // Keep complete symbols away from endpoints and sharp corners.
          if (at < halfSpan || at + halfSpan > contour.length) continue;
          final before = contour.getTangentForOffset(at - halfSpan)!.vector;
          final after = contour.getTangentForOffset(at + halfSpan)!.vector;
          if (before.dx * after.dx + before.dy * after.dy < .9) continue;
          final c = math.cos(angle) * size, s = math.sin(angle) * size;
          output.addPath(
            glyph.transform(
              Float64List.fromList([
                c,
                s,
                0,
                0,
                -s,
                c,
                0,
                0,
                0,
                0,
                1,
                0,
                tangent.position.dx,
                tangent.position.dy,
                0,
                1,
              ]),
            ),
            Offset.zero,
          );
          if (symbol.clearLine) cuts.add((at - halfSpan, at + halfSpan));
        }
      }
      var cutIndex = 0;
      void baseline(double from, double to) {
        while (cutIndex < cuts.length && cuts[cutIndex].$2 <= from) {
          cutIndex++;
        }
        var cursor = from;
        for (var i = cutIndex; i < cuts.length; i++) {
          final cut = cuts[i];
          if (cut.$2 <= cursor) continue;
          if (cut.$1 >= to) break;
          if (cut.$1 > cursor) {
            output.addPath(contour.extractPath(cursor, cut.$1), Offset.zero);
          }
          cursor = math.max(cursor, cut.$2);
          if (cursor >= to) return;
        }
        if (cursor < to) {
          output.addPath(contour.extractPath(cursor, to), Offset.zero);
        }
      }

      if (lengths.isEmpty) {
        baseline(0, contour.length);
      } else {
        var offset = 0.0, index = 0;
        var remaining = phase % lengths.reduce((a, b) => a + b);
        while (remaining >= lengths[index]) {
          remaining -= lengths[index];
          index = (index + 1) % lengths.length;
        }
        while (offset < contour.length) {
          final end = math.min(
            contour.length,
            offset + lengths[index] - remaining,
          );
          if (index.isEven) baseline(offset, end);
          offset = end;
          remaining = 0;
          index = (index + 1) % lengths.length;
        }
      }
    }
    return output;
  }

  /// Font-independent, monochrome vector artwork in normalized coordinates.
  static Path symbolPath(ArchitectLineSymbol symbol) {
    final path = Path();
    void stroke(List<Offset> points, {bool closed = false}) {
      if (points.isEmpty) return;
      path.moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (closed) path.close();
    }

    switch (symbol.shape) {
      case ArchitectLineSymbolShape.none:
        break;
      case ArchitectLineSymbolShape.lightning:
        stroke(const [
          Offset(.15, -.5),
          Offset(-.4, .05),
          Offset(-.05, .05),
          Offset(-.15, .5),
          Offset(.4, -.1),
          Offset(.05, -.1),
        ], closed: true);
      case ArchitectLineSymbolShape.circle:
        path.addOval(const Rect.fromLTRB(-.4, -.4, .4, .4));
      case ArchitectLineSymbolShape.square:
        path.addRect(const Rect.fromLTRB(-.4, -.4, .4, .4));
      case ArchitectLineSymbolShape.triangle:
        stroke(const [
          Offset(0, -.45),
          Offset(.45, .4),
          Offset(-.45, .4),
        ], closed: true);
      case ArchitectLineSymbolShape.diamond:
        stroke(const [
          Offset(0, -.45),
          Offset(.45, 0),
          Offset(0, .45),
          Offset(-.45, 0),
        ], closed: true);
      case ArchitectLineSymbolShape.cross:
        stroke(const [Offset(-.4, 0), Offset(.4, 0)]);
        stroke(const [Offset(0, -.4), Offset(0, .4)]);
      case ArchitectLineSymbolShape.arrow:
        stroke(const [Offset(-.45, 0), Offset(.45, 0)]);
        stroke(const [Offset(.05, -.4), Offset(.45, 0), Offset(.05, .4)]);
      case ArchitectLineSymbolShape.chevron:
        stroke(const [Offset(-.3, -.4), Offset(.3, 0), Offset(-.3, .4)]);
      case ArchitectLineSymbolShape.custom:
        for (final points in symbol.strokes) {
          stroke(points);
        }
    }
    return path;
  }
}
