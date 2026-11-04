import 'dart:ui';

import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_wall.dart';
import 'architect_path_solid.dart';

/// Immutable contours and broad bounds, reused across label candidates/frames.
/// Rectangle/edge queries avoid a boolean path intersection per candidate.
class ArchitectClearanceObstacles {
  final List<({Rect bounds, Path path, List<List<Offset>> contours})> _entries;
  ArchitectClearanceObstacles._(this._entries);
  static final _walls = Expando<ArchitectClearanceObstacles>();
  static final _paths = Expando<ArchitectClearanceObstacles>();

  static ArchitectClearanceObstacles forWalls(List<ArchitectWall> walls) =>
      _walls[walls] ??= ArchitectClearanceObstacles._([
        for (final wall in walls)
          (
            bounds: (Path()..addPolygon(wall.polygonCorners, true)).getBounds(),
            path: Path()..addPolygon(wall.polygonCorners, true),
            contours: [wall.polygonCorners],
          ),
      ]);

  static ArchitectClearanceObstacles forPath(Path path) =>
      _paths[path] ??= ArchitectClearanceObstacles._([
        (
          bounds: path.getBounds(),
          path: path,
          contours: ArchitectPathSolid.contours(path, tolerance: .00005),
        ),
      ]);

  bool intersects(Rect rect) {
    final query = rect.inflate(.00005);
    for (final entry in _entries) {
      if (!entry.bounds.overlaps(query)) continue;
      if ([
        query.topLeft,
        query.topRight,
        query.bottomLeft,
        query.bottomRight,
      ].any(entry.path.contains)) {
        return true;
      }
      for (final contour in entry.contours) {
        for (var i = 0; i < contour.length; i++) {
          if (BimLineGeometry.visibleSegment(
                contour[i],
                contour[(i + 1) % contour.length],
                query,
              ) !=
              null) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
