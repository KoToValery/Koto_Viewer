import 'dart:math' as math;
import 'dart:ui';

/// Signed circular arc: bulge = tan(sweep / 4). Stored independently of tessellation.
class ArchitectWallArc {
  final Offset start, end;
  final double bulge;
  const ArchitectWallArc(this.start, this.end, this.bulge);
  double get sweep => 4 * math.atan(bulge);
  double get radius =>
      (end - start).distance * (1 + bulge * bulge) / (4 * bulge.abs());
  Offset get center {
    final chord = end - start, n = Offset(-chord.dy, chord.dx);
    return (start + end) / 2 + n * ((1 - bulge * bulge) / (4 * bulge));
  }

  double get startAngle =>
      math.atan2(start.dy - center.dy, start.dx - center.dx);
  double get length => radius * sweep.abs();
  Offset pointAt(double ratio, {double leftOffset = 0}) {
    final angle = startAngle + sweep * ratio,
        r = radius - bulge.sign * leftOffset;
    return center + Offset(math.cos(angle), math.sin(angle)) * r;
  }

  Offset tangentAt(double ratio) {
    final angle = startAngle + sweep * ratio;
    return Offset(-math.sin(angle), math.cos(angle)) * bulge.sign;
  }

  double parameter(Offset p) {
    final delta = p - center;
    var a = (math.atan2(delta.dy, delta.dx) - startAngle) * bulge.sign;
    a %= 2 * math.pi;
    if (a > sweep.abs() && a - sweep.abs() > 2 * math.pi - a) a -= 2 * math.pi;
    return a / sweep.abs();
  }

  List<Offset> face(
    double low,
    double high, {
    double from = 0,
    double to = 1,
    double? envelopeOffset,
  }) {
    final outer = radius + (envelopeOffset ?? math.max(low.abs(), high.abs()));
    final step = 2 * math.acos((1 - .00005 / outer).clamp(-1, 1));
    final count = (sweep.abs() / step).ceil().clamp(1, 2048);
    final ratios = [
      from,
      for (var i = (from * count).ceil(); i < to * count; i++)
        if (i / count > from) i / count,
      to,
    ];
    return [
      for (final ratio in ratios) pointAt(ratio, leftOffset: low),
      for (final ratio in ratios.reversed) pointAt(ratio, leftOffset: high),
    ];
  }

  List<Offset> lineIntersections(Offset a, Offset b, {bool finite = true}) {
    final d = b - a, f = a - center, aa = d.dx * d.dx + d.dy * d.dy;
    if (aa < 1e-12) return const [];
    final bb = 2 * (f.dx * d.dx + f.dy * d.dy),
        cc = f.dx * f.dx + f.dy * f.dy - radius * radius,
        disc = bb * bb - 4 * aa * cc;
    if (disc < 0) return const [];
    final result = <Offset>[];
    for (final t in {
      (-bb - math.sqrt(disc)) / (2 * aa),
      (-bb + math.sqrt(disc)) / (2 * aa),
    }) {
      final p = a + d * t, r = parameter(p);
      if (!finite ||
          (t >= -1e-8 && t <= 1 + 1e-8 && r >= -1e-8 && r <= 1 + 1e-8))
        result.add(p);
    }
    return result;
  }

  List<Offset> arcIntersections(ArchitectWallArc other, {bool finite = true}) {
    final d = (other.center - center).distance;
    if (d < 1e-8 ||
        d > radius + other.radius + 1e-8 ||
        d < (radius - other.radius).abs() - 1e-8)
      return const [];
    final a = (radius * radius - other.radius * other.radius + d * d) / (2 * d),
        h = math.sqrt(math.max(0, radius * radius - a * a));
    final u = (other.center - center) / d,
        n = Offset(-u.dy, u.dx),
        p = center + u * a;
    return [
      for (final q in [p + n * h, p - n * h])
        if (!finite ||
            (parameter(q) >= -1e-8 &&
                parameter(q) <= 1 + 1e-8 &&
                other.parameter(q) >= -1e-8 &&
                other.parameter(q) <= 1 + 1e-8))
          q,
    ];
  }

  static double through(Offset start, Offset end, Offset through) {
    final a = end - start,
        b = through - start,
        den = 2 * (a.dx * b.dy - a.dy * b.dx);
    if (den.abs() < 1e-8) return 0;
    final aa = a.dx * a.dx + a.dy * a.dy, bb = b.dx * b.dx + b.dy * b.dy;
    final c =
        start +
        Offset((aa * b.dy - bb * a.dy) / den, (a.dx * bb - b.dx * aa) / den);
    final first = math.atan2(start.dy - c.dy, start.dx - c.dx);
    final last =
        (math.atan2(end.dy - c.dy, end.dx - c.dx) - first) % (2 * math.pi);
    final middle =
        (math.atan2(through.dy - c.dy, through.dx - c.dx) - first) %
        (2 * math.pi);
    final sweep = middle <= last ? last : last - 2 * math.pi;
    return math.tan(sweep / 4);
  }
}
