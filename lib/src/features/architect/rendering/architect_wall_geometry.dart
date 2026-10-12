import 'dart:ui';
import '../models/architect_wall.dart';
import 'architect_wall_network.dart';

/// Physical body and material boundaries, independent of the reference line.
class ArchitectWallGeometry {
  final List<(Offset, Offset)> edges;
  final List<Offset> corners;
  const ArchitectWallGeometry(this.edges, this.corners);
  static final _cache = Expando<ArchitectWallGeometry>();
  static ArchitectWallGeometry of(List<ArchitectWall> walls) {
    final cached = _cache[walls];
    if (cached != null) return cached;
    final edges = <(Offset, Offset)>[];
    final corners = <Offset>{};
    final coreFaces = <String, (double, double)>{};
    for (final wall in walls) {
      if (wall.length < 1e-8) continue;
      edges.add((wall.startPoint, wall.endPoint));
      edges.add((wall.coreCenterStart, wall.coreCenterEnd));
      for (final polygon in [wall.polygonCorners, wall.coreCorners]) {
        corners.addAll(polygon);
        for (var i = 0; i < polygon.length; i++) {
          edges.add((polygon[i], polygon[(i + 1) % polygon.length]));
        }
      }
      final d = wall.coreCenterStart - wall.startPoint;
      final c = d.dx * wall.normalVector.dx + d.dy * wall.normalVector.dy;
      coreFaces[wall.id] = (
        c - wall.coreThickness / 2,
        c + wall.coreThickness / 2,
      );
    }
    // Mitre corners can lie beyond an individual wall's rectangular end.
    for (final junction in [
      ...ArchitectWallNetwork.junctions(walls),
      ...ArchitectWallNetwork.junctions(walls, faceOffsets: coreFaces),
    ]) {
      corners.addAll(junction.$1);
      for (var i = 0; i < junction.$1.length; i++) {
        edges.add((junction.$1[i], junction.$1[(i + 1) % junction.$1.length]));
      }
    }
    return _cache[walls] = ArchitectWallGeometry(edges, corners.toList());
  }
}

class ArchitectWallAlignment {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// Align to extensions of neighboring faces and corners at any rotation.
  static (Offset, List<(Offset, Offset)>) point(
    Offset raw,
    List<ArchitectWall> walls,
    double scale,
  ) {
    final radius = 8 / scale;
    var best = radius;
    Offset? snapped;
    (Offset, Offset)? guide;
    for (final wall in walls) {
      for (final corner in [...wall.polygonCorners, ...wall.coreCorners]) {
        for (final direction in [wall.unitVector, wall.normalVector]) {
          final projected = corner + direction * dot(raw - corner, direction);
          final distance = (projected - raw).distance;
          if (distance < best) {
            best = distance;
            snapped = projected;
            guide = (corner - direction * .3, projected + direction * .3);
          }
        }
      }
    }
    return (snapped ?? raw, guide == null ? [] : [guide]);
  }

  /// Only parallel/perpendicular neighbors participate in body alignment.
  static (Offset, List<(Offset, Offset)>) move(
    List<ArchitectWall> walls,
    Set<String> ids,
    Offset delta,
    double scale, {
    bool parallelOnly = false,
  }) {
    final moving = walls.where((w) => ids.contains(w.id)).toList();
    if (moving.isEmpty) return (delta, []);
    final radius = 8 / scale;
    final guides = <(Offset, Offset)>[];
    var result = delta;
    final basis = [
      if (!parallelOnly) moving.first.unitVector,
      moving.first.normalVector,
    ];
    for (final axis in basis) {
      var distance = radius;
      double? correction;
      (Offset, Offset)? guide;
      for (final a in moving) {
        for (final b in walls.where((w) => !ids.contains(w.id))) {
          final angle = dot(a.unitVector, b.unitVector).abs();
          if (angle > 1e-6 && (1 - angle).abs() > 1e-6) continue;
          for (final p in [...a.polygonCorners, ...a.coreCorners]) {
            for (final q in [...b.polygonCorners, ...b.coreCorners]) {
              final shifted = p + result;
              final c = dot(q - shifted, axis);
              if (c.abs() < distance) {
                distance = c.abs();
                correction = c;
                final direction = Offset(-axis.dy, axis.dx);
                guide = (
                  q - direction * .3,
                  shifted + axis * c + direction * .3,
                );
              }
            }
          }
        }
      }
      if (correction != null) {
        result += axis * correction;
        guides.add(guide!);
      }
    }
    return (result, guides);
  }
}
