import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../models/architect_hatch_pattern.dart';
import 'architect_line_pattern.dart';

/// Paper-space families aligned to a stable origin, clipped by the caller to
/// the actual contour. No bitmap textures or opaque background masks.
class ArchitectHatchGeometry {
  static Path path({
    required Path boundary,
    required ArchitectHatchPattern pattern,
    required double unitsPerMm,
    double scale = 1,
    double angleDeg = 0,
    Offset origin = Offset.zero,
    Rect? visibleBounds,
  }) {
    pattern.validate();
    if (!unitsPerMm.isFinite ||
        unitsPerMm <= 0 ||
        !scale.isFinite ||
        scale < .1 ||
        scale > 20 ||
        !angleDeg.isFinite ||
        angleDeg.abs() > 180) {
      throw ArgumentError('Invalid hatch transform');
    }
    final output = Path();
    final bounds = visibleBounds == null
        ? boundary.getBounds()
        : boundary.getBounds().intersect(visibleBounds);
    if (bounds.isEmpty) return output;
    final mm = unitsPerMm * scale;
    for (final layer in pattern.layers) {
      final angle = (angleDeg + layer.angleDeg) * math.pi / 180;
      final u = Offset(math.cos(angle), math.sin(angle)),
          n = Offset(-math.sin(angle), math.cos(angle));
      double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
      final corners = [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ].map((p) => p - origin).toList();
      final along = corners.map((p) => dot(p, u)).toList(),
          across = corners.map((p) => dot(p, n)).toList();
      final step = layer.spacingMm * mm, phase = layer.phaseMm * mm;
      final first = ((across.reduce(math.min) - phase) / step).floor();
      final last = ((across.reduce(math.max) - phase) / step).ceil();
      final style = layer.lineStyle;
      final cycle = style.symbol != null
          ? style.symbol!.spacingMm * mm
          : style.segmentsMm.isEmpty
          ? step
          : style.segmentsMm.reduce((a, b) => a + b) * mm;
      final minX = along.reduce(math.min) - cycle,
          maxX = along.reduce(math.max) + cycle;
      for (var row = first; row <= last; row++) {
        final shift = row * layer.shiftMm * mm;
        final start = ((minX - shift) / cycle).floor() * cycle + shift;
        final base = origin + n * (row * step + phase);
        if (!layer.symbolsOnly) {
          final a = base + u * start, b = base + u * maxX;
          output.addPath(
            ArchitectLinePattern.path(
              Path()
                ..moveTo(a.dx, a.dy)
                ..lineTo(b.dx, b.dy),
              style,
              mm,
              phase: start - shift,
            ),
            Offset.zero,
          );
        } else {
          final symbol = style.symbol!;
          final glyph = ArchitectLinePattern.symbolPath(symbol);
          final rotation =
              (symbol.followLine ? angle : 0) + symbol.angleDeg * math.pi / 180;
          final size = symbol.sizeMm * mm;
          final c = math.cos(rotation) * size, s = math.sin(rotation) * size;
          for (var x = start + cycle / 2; x <= maxX; x += cycle) {
            final center = base + u * x;
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
                  center.dx,
                  center.dy,
                  0,
                  1,
                ]),
              ),
              Offset.zero,
            );
          }
        }
      }
    }
    return output;
  }
}
