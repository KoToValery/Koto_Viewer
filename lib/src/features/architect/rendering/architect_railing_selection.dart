import 'dart:ui';
import '../models/architect_wall.dart';
import 'architect_railing_geometry.dart';

/// A continuous interaction band containing every physical component. This
/// envelope is never supplied to material solids, room detection or snapping.
class ArchitectRailingSelection {
  static final _cache = Expando<Map<List<ArchitectWall>, Path>>();

  static Path envelope(ArchitectWall wall, List<ArchitectWall> walls) {
    final cache = _cache[wall] ??= {};
    final existing = cache[walls];
    if (existing != null) return existing;
    var result = Path()..addPolygon(wall.polygonCorners, true);
    for (final part in ArchitectRailingGeometry.planPaths(wall, walls: walls)) {
      result = Path.combine(PathOperation.union, result, part);
    }
    if (cache.length >= 4) cache.remove(cache.keys.first);
    return cache[walls] = result;
  }
}
