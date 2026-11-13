import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/architect_elements.dart';

/// Shared geometry for persisted ellipses. [ArchitectCadPrimitive.startPoint]
/// is their centre, including legacy files whose end point was a box corner.
/// Explicit radii take precedence; the old renderer's fallbacks stay intact.
class ArchitectEllipseGeometry {
  static final _cache = Expando<ArchitectEllipseGeometry>();

  factory ArchitectEllipseGeometry.fromPrimitive(
    ArchitectCadPrimitive source,
  ) => _cache[source] ??= ArchitectEllipseGeometry._(source);

  ArchitectEllipseGeometry._(ArchitectCadPrimitive source)
    : center = source.startPoint,
      radiusX =
          source.radiusX ?? (source.endPoint - source.startPoint).distance,
      radiusY =
          source.radiusY ??
          (source.radiusX ?? (source.endPoint - source.startPoint).distance) *
              .6,
      rotationDeg = source.rotationDeg ?? 0,
      isArc = source.isArc == true,
      startAngle = (source.startAngleDeg ?? 0) * math.pi / 180,
      sweepAngle = _sweep(source);

  final Offset center;
  final double radiusX, radiusY, rotationDeg;
  final bool isArc;
  final double startAngle, sweepAngle;

  bool get isValid =>
      center.dx.isFinite &&
      center.dy.isFinite &&
      radiusX.isFinite &&
      radiusX > 1e-4 &&
      radiusY.isFinite &&
      radiusY > 1e-4 &&
      rotationDeg.isFinite &&
      startAngle.isFinite &&
      sweepAngle.isFinite;

  static double _sweep(ArchitectCadPrimitive source) {
    if (source.isArc != true) return math.pi * 2;
    var sweep =
        ((source.endAngleDeg ?? 360) - (source.startAngleDeg ?? 0)) *
        math.pi /
        180;
    if (sweep <= 0) sweep += math.pi * 2;
    return sweep.clamp(0.0, math.pi * 2).toDouble();
  }

  double get _rotation => rotationDeg * math.pi / 180;

  Offset pointAt(double parameter) {
    final local = Offset(
      radiusX * math.cos(parameter),
      radiusY * math.sin(parameter),
    );
    final c = math.cos(_rotation), s = math.sin(_rotation);
    return center +
        Offset(c * local.dx - s * local.dy, s * local.dx + c * local.dy);
  }

  bool _onSweep(double parameter) {
    if (!isArc || sweepAngle >= math.pi * 2 - 1e-10) return true;
    final offset = (parameter - startAngle) % (math.pi * 2);
    return offset <= sweepAngle + 1e-10;
  }

  /// Visible principal-axis ends, plus endpoints for a partial elliptical arc.
  Iterable<Offset> get axisPoints sync* {
    if (!isValid) return;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      if (_onSweep(angle)) yield pointAt(angle);
    }
    if (isArc && sweepAngle < math.pi * 2 - 1e-10) {
      yield pointAt(startAngle);
      yield pointAt(startAngle + sweepAngle);
    }
  }

  Path get path {
    if (!isValid) return Path();
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 2,
      height: radiusY * 2,
    );
    final local = Path();
    if (isArc) {
      local.addArc(rect, startAngle, sweepAngle);
    } else {
      local.addOval(rect);
    }
    final c = math.cos(_rotation), s = math.sin(_rotation);
    return local.transform(
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
    );
  }

  Rect get bounds {
    if (!isValid) return Rect.fromPoints(center, center);
    if (isArc) return path.getBounds();
    final c = math.cos(_rotation), s = math.sin(_rotation);
    final halfWidth = math.sqrt(
      radiusX * radiusX * c * c + radiusY * radiusY * s * s,
    );
    final halfHeight = math.sqrt(
      radiusX * radiusX * s * s + radiusY * radiusY * c * c,
    );
    return Rect.fromCenter(
      center: center,
      width: halfWidth * 2,
      height: halfHeight * 2,
    );
  }

  /// Euclidean distance to the visible curve, in model units. Minimizing on a
  /// coarse bracket avoids the scale-dependent normalized hit-test threshold.
  double distanceTo(Offset point) {
    if (!isValid) return double.infinity;
    final start = isArc ? startAngle : 0.0;
    final sweep = isArc ? sweepAngle : math.pi * 2;
    const steps = 64;
    final step = sweep / steps;
    double squared(double angle) => (pointAt(angle) - point).distanceSquared;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i <= steps; i++) {
      final distance = squared(start + i * step);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    var left = start + math.max(0, best - 1) * step;
    var right = start + math.min(steps, best + 1) * step;
    const ratio = .6180339887498949;
    var a = right - ratio * (right - left);
    var b = left + ratio * (right - left);
    for (var i = 0; i < 36; i++) {
      if (squared(a) < squared(b)) {
        right = b;
        b = a;
        a = right - ratio * (right - left);
      } else {
        left = a;
        a = b;
        b = left + ratio * (right - left);
      }
    }
    return math.sqrt(math.min(bestDistance, squared((left + right) / 2)));
  }

  static void validate(ArchitectCadPrimitive source) {
    final geometry = ArchitectEllipseGeometry.fromPrimitive(source);
    if (!geometry.isValid ||
        (source.startAngleDeg != null && !source.startAngleDeg!.isFinite) ||
        (source.endAngleDeg != null && !source.endAngleDeg!.isFinite)) {
      throw ArgumentError('Invalid ellipse geometry');
    }
  }
}
