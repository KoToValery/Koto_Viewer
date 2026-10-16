import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';

class StairFlightGeometry {
  final Offset origin, axis;
  final double width, going, riser;
  final int count, firstRiser;
  const StairFlightGeometry(
    this.origin,
    this.axis,
    this.width,
    this.going,
    this.riser,
    this.count,
    this.firstRiser,
  );
  Offset get normal => Offset(-axis.dy, axis.dx);
  double get run => (count - 1) * going;
  double get base => firstRiser * riser;
  double get top => (firstRiser + count) * riser;
  Offset point(double along, double across) =>
      origin + axis * along + normal * across;
}

class StairLandingGeometry {
  final List<Offset> polygon;
  final double elevation;
  const StairLandingGeometry(this.polygon, this.elevation);
}

class StairPlanCutGeometry {
  final Path below, above;
  final (Offset, Offset)? crossing;
  const StairPlanCutGeometry(this.below, this.above, this.crossing);
}

/// Finished geometry in model metres. These data also drive the guard, mesh,
/// actual vertical sections and the horizontal plan-cut display.
class ArchitectStairGeometry {
  static final _cache = Expando<ArchitectStairGeometry>();
  static ArchitectStairGeometry of(ArchitectStair stair) =>
      _cache[stair] ??= ArchitectStairGeometry._(stair);
  final ArchitectStair stair;
  final flights = <StairFlightGeometry>[];
  final landings = <StairLandingGeometry>[];
  final _cuts = <double, StairPlanCutGeometry>{};
  ArchitectStairGeometry._(this.stair) {
    final d = stair.design;
    if (d == null || d.isSpiral || d.hasWinders) return;
    var first = 0;
    final counts = d.flightRisers;
    for (var f = 0; f < counts.length; f++) {
      final a = stair.plan.nosings[first], b = stair.plan.nosings[first + 1];
      final origin = (a.$1 + a.$2) / 2;
      final delta = (b.$1 + b.$2) / 2 - origin;
      flights.add(
        StairFlightGeometry(
          origin,
          delta / delta.distance,
          stair.width,
          d.going,
          d.riser,
          counts[f],
          first,
        ),
      );
      first += counts[f];
      if (f < counts.length - 1) {
        landings.add(
          StairLandingGeometry(
            stair.plan.footprints[f * 2 + 1],
            first * d.riser,
          ),
        );
      }
    }
  }

  StairPlanCutGeometry cut(double height) {
    if (_cuts.containsKey(height)) return _cuts[height]!;
    if (_cuts.length >= 8) _cuts.clear();
    if (stair.design == null) {
      return _cuts[height] = StairPlanCutGeometry(
        stair.plan.path,
        Path(),
        null,
      );
    }
    var below = Path(), above = Path();
    final d = stair.design!;
    final localHeight = height - d.startOffset;
    for (final surface in stair.plan.surfaces) {
      final path = Path()..addPolygon(surface.polygon, true);
      if (surface.elevation <= localHeight + 1e-8) {
        below = Path.combine(PathOperation.union, below, path);
      } else {
        above = Path.combine(PathOperation.union, above, path);
      }
    }
    final crossing = localHeight > 1e-8 && localHeight < d.rise - 1e-8
        ? stair.plan.nosings[(localHeight / d.riser + 1e-8).floor().clamp(
            0,
            d.risers - 1,
          )]
        : null;
    if (d.shape == StairShape.spiralOverlap) {
      above = Path.combine(PathOperation.difference, above, below);
    }
    return _cuts[height] = StairPlanCutGeometry(below, above, crossing);
  }

  double elevationAt(Offset point) {
    final d = stair.design;
    if (d == null) return 0;
    if (d.hasWinders) {
      for (final surface in stair.plan.surfaces) {
        final p = surface.polygon, z = surface.slopeBase!;
        for (final indices in const [
          [0, 1, 2],
          [0, 2, 3],
        ]) {
          final a = p[indices[0]], b = p[indices[1]], c = p[indices[2]];
          final denominator = cross(b - a, c - a);
          if (denominator.abs() < 1e-12) continue;
          final v = cross(point - a, c - a) / denominator;
          final w = cross(b - a, point - a) / denominator;
          if (v >= -1e-6 && w >= -1e-6 && v + w <= 1 + 1e-6) {
            return d.startOffset +
                (z[indices[0]] * (1 - v - w) +
                        z[indices[1]] * v +
                        z[indices[2]] * w +
                        d.riser)
                    .clamp(0, d.rise);
          }
        }
      }
    }
    if (d.isSpiral) {
      final u = stair.unitVector;
      final v = stair.normalVector * (d.turnLeft ? -1 : 1);
      final relative = point - stair.startPoint;
      final x = dot(relative, u),
          y = dot(relative, v) - d.innerRadius - stair.width / 2;
      var angle = math.atan2(x, -y);
      if (angle < -1e-8) angle += 2 * math.pi;
      return d.startOffset +
          ((angle.clamp(0, d.sweepDegrees * math.pi / 180) / d.anglePerGoing +
                      1) *
                  d.riser)
              .clamp(0, d.rise);
    }
    for (final flight in flights) {
      final relative = point - flight.origin;
      final along = dot(relative, flight.axis),
          across = dot(relative, flight.normal);
      if (along >= -1e-6 &&
          along <= flight.run + 1e-6 &&
          across.abs() <= flight.width / 2 + 1e-6) {
        return d.startOffset +
            flight.base +
            (along.clamp(0, flight.run) / flight.going + 1) * flight.riser;
      }
    }
    for (final landing in landings) {
      if (inside(point, landing.polygon, tolerance: .001)) {
        return d.startOffset + landing.elevation;
      }
    }
    // Rounding at the perimeter must not send a guard to the ground.
    var distance = double.infinity, elevation = 0.0;
    for (var i = 0; i < stair.plan.nosings.length; i++) {
      final (a, b) = stair.plan.nosings[i];
      final value = pointSegmentDistance(point, a, b);
      if (value < distance) {
        distance = value;
        elevation = (i + 1) * d.riser;
      }
    }
    return d.startOffset + elevation;
  }

  late final List<(Offset, Offset)> guardEdges = _guardEdges();
  List<(Offset, Offset)> _guardEdges() {
    final polygons = stair.plan.footprints;
    final all = <(Offset, Offset)>[
      for (final p in polygons)
        for (var i = 0; i < p.length; i++) (p[i], p[(i + 1) % p.length]),
    ];
    final result = <(Offset, Offset)>[], seen = <String>{};
    final entry = stair.plan.nosings.first, exit = stair.plan.nosings.last;
    bool isOpening(Offset a, Offset b, (Offset, Offset) opening) =>
        pointSegmentDistance(a, opening.$1, opening.$2) < 1e-6 &&
        pointSegmentDistance(b, opening.$1, opening.$2) < 1e-6;
    for (final (a, b) in all) {
      final v = b - a;
      if (v.distance < 1e-8) continue;
      final parameters = <double>[0, 1];
      if (polygons.length > 1) {
        for (final (c, e) in all) {
          final w = e - c, denominator = cross(v, w);
          if (denominator.abs() > 1e-10) {
            final t = cross(c - a, w) / denominator,
                u = cross(c - a, v) / denominator;
            if (t > 1e-8 && t < 1 - 1e-8 && u >= -1e-8 && u <= 1 + 1e-8) {
              parameters.add(t);
            }
          } else if (cross(c - a, v).abs() < 1e-8) {
            for (final p in [c, e]) {
              final t = dot(p - a, v) / v.distanceSquared;
              if (t > 1e-8 && t < 1 - 1e-8) parameters.add(t);
            }
          }
        }
      }
      parameters.sort();
      final normal = Offset(-v.dy, v.dx) / v.distance * .0001;
      for (var i = 0; i < parameters.length - 1; i++) {
        final p = a + v * parameters[i], q = a + v * parameters[i + 1];
        if ((q - p).distance < 1e-7 ||
            isOpening(p, q, entry) ||
            isOpening(p, q, exit)) {
          continue;
        }
        final middle = (p + q) / 2;
        final left = polygons.any((poly) => inside(middle + normal, poly));
        final right = polygons.any((poly) => inside(middle - normal, poly));
        if (left == right) continue;
        String key(Offset point) =>
            '${(point.dx * 1e6).round()},${(point.dy * 1e6).round()}';
        final keys = [key(p), key(q)]..sort();
        if (seen.add(keys.join(':'))) result.add((p, q));
      }
    }
    return result;
  }

  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double pointSegmentDistance(Offset p, Offset a, Offset b) {
    final v = b - a;
    if (v.distanceSquared < 1e-16) return (p - a).distance;
    final t = (dot(p - a, v) / v.distanceSquared).clamp(0.0, 1.0);
    return (p - a - v * t).distance;
  }

  static bool inside(
    Offset point,
    List<Offset> polygon, {
    double tolerance = 0,
  }) {
    var result = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[j], b = polygon[i];
      if (tolerance > 0 && pointSegmentDistance(point, a, b) <= tolerance) {
        return true;
      }
      if ((a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        result = !result;
      }
    }
    return result;
  }
}
