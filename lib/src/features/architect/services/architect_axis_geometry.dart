import 'dart:ui';
import '../models/architect_grid_axis.dart';
import '../models/architect_wall.dart';

/// Geometry shared by selection readouts and both axis move gestures.
class ArchitectAxisGeometry {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// The nearest distinct parallel alignment on either side of [axis].
  static List<({StructuralGridAxis axis, double distance})> neighbors(
    StructuralGridAxis axis,
    List<StructuralGridAxis> axes,
  ) {
    ({StructuralGridAxis axis, double distance})? before, after;
    if (axis.length < 1e-6) return [];
    for (final other in axes) {
      if (other.id == axis.id ||
          other.length < 1e-6 ||
          !axis.isParallelTo(other, toleranceRad: .001)) {
        continue;
      }
      final d = dot(other.start - axis.start, axis.normal);
      if (d < -1e-6 && (before == null || d > before.distance)) {
        before = (axis: other, distance: d);
      } else if (d > 1e-6 && (after == null || d < after.distance)) {
        after = (axis: other, distance: d);
      }
    }
    return [?before, ?after];
  }

  /// Snap perpendicular translation to the structural core centerline.
  /// Keep the axis length and along-line movement; exclude distant wall spans.
  static ({Offset delta, (Offset, Offset) guide})? snapToWall({
    required StructuralGridAxis axis,
    required Offset delta,
    required List<ArchitectWall> walls,
    required double tolerance,
  }) {
    if (axis.length < 1e-6) return null;
    var best = tolerance;
    ({Offset delta, (Offset, Offset) guide})? result;
    final ordered = walls.toList()..sort((a, b) => a.id.compareTo(b.id));
    final u = axis.direction, n = axis.normal;
    for (final wall in ordered) {
      if (wall.length < 1e-6 ||
          (u.dx * wall.unitVector.dy - u.dy * wall.unitVector.dx).abs() >
              1e-6) {
        continue;
      }
      final from = dot(wall.coreCenterStart - axis.start - delta, u);
      final to = dot(wall.coreCenterEnd - axis.start - delta, u);
      if ((from > to ? to : from) > axis.length + tolerance ||
          (from > to ? from : to) < -tolerance) {
        continue;
      }
      final distance = dot(axis.start + delta - wall.coreCenterStart, n);
      if (distance.abs() > best) continue;
      best = distance.abs();
      result = (
        delta: delta - n * distance,
        guide: (wall.coreCenterStart, wall.coreCenterEnd),
      );
    }
    return result;
  }
}
