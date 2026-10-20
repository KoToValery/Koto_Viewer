import 'dart:math' as math;
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
      if(!wall.isCurved) {
        edges.add((wall.startPoint, wall.endPoint));
        edges.add((wall.coreCenterStart, wall.coreCenterEnd));
      } else {
        final path=wall.facePolygon(0,0),count=path.length~/2;
        for(var i=0;i+1<count;i++) {
          edges.add((path[i],path[i+1]));
        }
        corners.addAll([wall.startPoint,wall.endPoint,wall.referencePointAt(.5)]);
      }
      for (final polygon in [wall.polygonCorners, wall.coreCorners]) {
        if(!wall.isCurved)corners.addAll(polygon);
        for (var i = 0; i < polygon.length; i++) {
          edges.add((polygon[i], polygon[(i + 1) % polygon.length]));
        }
      }
      final c = wall.centerLineOffset-wall.exteriorSign*wall.coreAsymmetry/2;
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
      for(var i=0;i<junction.$1.length;i++) {
        final a=junction.$1[i]-junction.$1[(i+junction.$1.length-1)%junction.$1.length],b=junction.$1[(i+1)%junction.$1.length]-junction.$1[i];
        if((a.dx*b.dy-a.dy*b.dx).abs()>.05*a.distance*b.distance)corners.add(junction.$1[i]);
      }
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
    final radius = math.min(22.0 / scale, 0.4);
    var best = radius;
    Offset? snapped;
    (Offset, Offset)? guide;
    for (final wall in walls) {
      if (wall.isCurved) continue;
      for (final corner in [...wall.polygonCorners, ...wall.coreCorners]) {
        for (final direction in [wall.unitVector, wall.normalVector]) {
          final along = dot(raw - corner, direction);
          final projected = corner + direction * along;
          final distance = (projected - raw).distance;
          if (distance < best) {
            best = distance;
            snapped = projected;
            final overshoot = math.max(0.4, 20.0 / scale);
            final (p1, p2) = along >= 0
                ? (corner - direction * overshoot, projected + direction * overshoot)
                : (projected - direction * overshoot, corner + direction * overshoot);
            guide = (p1, p2);
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
    final radius = math.min(22.0 / scale, 0.4);
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
          if (a.isCurved || b.isCurved) continue;
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
                final overshoot = math.max(0.4, 20.0 / scale);
                guide = (
                  q - direction * overshoot,
                  shifted + axis * c + direction * overshoot,
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
