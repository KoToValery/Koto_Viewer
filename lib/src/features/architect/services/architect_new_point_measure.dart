import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_wall.dart';

/// Distances follow the native wall reference line, including circular arcs.
class ArchitectNewPointMeasure {
  final ArchitectWall wall;
  final double ratio;
  ArchitectNewPointMeasure(this.wall, Offset point)
    : ratio =
          (wall.arc?.parameter(point) ??
                  BimLineGeometry.parameter(
                    point,
                    wall.startPoint,
                    wall.endPoint,
                  ))
              .clamp(0.0, 1.0);

  double distanceFrom(int endpoint) =>
      (endpoint == 1 ? ratio : 1 - ratio) * wall.length;

  static Offset pointAtDistance(
    ArchitectWall wall,
    int endpoint,
    double distance,
  ) {
    if (!distance.isFinite || distance <= 0 || distance >= wall.length) {
      throw ArgumentError('Distance is outside the wall');
    }
    final ratio = distance / wall.length;
    return wall.referencePointAt(endpoint == 1 ? ratio : 1 - ratio);
  }
}
