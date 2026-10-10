import 'dart:math' as math;
import 'dart:ui';
import '../models/wall_axis_models.dart';

/// Infinite axes locate junctions; only observed walls give those nodes support.
/// Empty grid cells and axes belonging to another floor cannot extend a slab.
class SlabAxisSupportGrid {
  final List<_Axis> _axes = [];
  final Map<int, _Axis> _wallAxes = {};
  final double scale;

  SlabAxisSupportGrid(
    List<WallPairCandidate> walls,
    this.scale, {
    double targetThicknessMm = 250,
  }) {
    if (!scale.isFinite || scale <= 0 || walls.length > 1400) return;
    for (var i = 0; i < walls.length; i++) {
      final wall = walls[i];
      final delta = wall.centerlineEnd - wall.centerlineStart;
      if (delta.distance < 15 * scale ||
          (wall.perpendicularDistance / scale - targetThicknessMm).abs() >
              targetThicknessMm * .2 + .01) {
        continue;
      }
      final direction = delta / delta.distance;
      final axis =
          _axes
              .where(
                (a) =>
                    _cross(a.direction, direction).abs() < .035 &&
                    _cross(
                          wall.centerlineStart - a.origin,
                          a.direction,
                        ).abs() <=
                        35 * scale &&
                    _cross(wall.centerlineEnd - a.origin, a.direction).abs() <=
                        35 * scale,
              )
              .firstOrNull ??
          _Axis(wall.centerlineStart, direction);
      if (axis.walls.isEmpty) _axes.add(axis);
      axis.walls.add(wall);
      _wallAxes[i] = axis;
    }
    for (var i = 0; i < _axes.length; i++) {
      for (var j = i + 1; j < _axes.length; j++) {
        final a = _axes[i], b = _axes[j];
        final denominator = _cross(a.direction, b.direction);
        if (denominator.abs() < .25) continue;
        final point =
            a.origin +
            a.direction *
                (_cross(b.origin - a.origin, b.direction) / denominator);
        if (!_occupied(a, point) || !_occupied(b, point)) continue;
        a.nodes.add(point);
        b.nodes.add(point);
      }
    }
  }

  bool isAxisWall(int wall) => _wallAxes.containsKey(wall);

  /// Return the nearest occupied junction before and after this bounded gap.
  /// The proposed bridge ends at observed jambs, never at a distant axis.
  List<Offset> supportingIntersections(
    int wallA,
    int wallB,
    Offset start,
    Offset end,
  ) {
    final axis = _wallAxes[wallA];
    if (axis == null ||
        !identical(axis, _wallAxes[wallB]) ||
        (end - start).distance > 1500 * scale) {
      return const [];
    }
    final lo = math.min(axis.along(start), axis.along(end));
    final hi = math.max(axis.along(start), axis.along(end));
    Offset? before, after;
    for (final point in axis.nodes) {
      final t = axis.along(point);
      if (t <= lo + 25 * scale &&
          lo - t <= 2000 * scale &&
          (before == null || t > axis.along(before))) {
        before = point;
      }
      if (t >= hi - 25 * scale &&
          t - hi <= 2000 * scale &&
          (after == null || t < axis.along(after))) {
        after = point;
      }
    }
    if (before == null ||
        after == null ||
        (after - before).distance < (end - start).distance - 50 * scale) {
      return const [];
    }
    return [before, after];
  }

  bool _occupied(_Axis axis, Offset point) => axis.walls.any((wall) {
    final a = wall.centerlineStart, delta = wall.centerlineEnd - a;
    final t = _dot(point - a, delta) / delta.distanceSquared;
    final closest = a + delta * t.clamp(0.0, 1.0);
    return (point - closest).distance <=
        wall.perpendicularDistance / 2 + 50 * scale;
  });

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}

class _Axis {
  final Offset origin, direction;
  final List<WallPairCandidate> walls = [];
  final List<Offset> nodes = [];
  _Axis(this.origin, this.direction);
  double along(Offset p) => SlabAxisSupportGrid._dot(p - origin, direction);
}
