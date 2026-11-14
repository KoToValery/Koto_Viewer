import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import 'architect_wall_network.dart';
import 'architect_railing_geometry.dart';
import 'architect_path_solid.dart';

/// Physical body and material boundaries, independent of the reference line.
class ArchitectWallGeometry {
  static final _cores = Expando<List<ArchitectWall>>();
  static final _planWallsCache = Expando<List<ArchitectWall>>();

  static bool _isHiddenPlanPlaster(ArchitectMaterialLayer l) =>
      l.role == ArchitectLayerRole.finish &&
      l.material == ArchitectMaterial.plaster;

  /// Plan projection strips interior wall plaster so floor plans, ghost
  /// storeys, openings, and plan snapping work against structural/insulation faces
  /// while the full geometric layers stay intact for sections and 3D.
  static ArchitectWall planWall(ArchitectWall wall) {
    if (wall.railing != null ||
        wall.system.isSpecial ||
        wall.layers.isEmpty ||
        !wall.layers.any(_isHiddenPlanPlaster)) {
      return wall;
    }
    final remaining =
        wall.layers.where((l) => !_isHiddenPlanPlaster(l)).toList();
    if (remaining.isEmpty) return wall;
    final newThickness =
        remaining.fold<double>(0.0, (s, l) => s + l.thickness);
    return wall.copyWith(
      startPoint: wall.coreCenterStart,
      endPoint: wall.coreCenterEnd,
      referenceLine: WallReferenceLine.center,
      thickness: newThickness,
      layers: remaining,
    );
  }

  static List<ArchitectWall> planWalls(List<ArchitectWall> walls) {
    final cached = _planWallsCache[walls];
    if (cached != null) return cached;
    var changed = false;
    final out = List<ArchitectWall>.generate(walls.length, (i) {
      final w = walls[i];
      final pw = planWall(w);
      if (!identical(w, pw)) changed = true;
      return pw;
    }, growable: false);
    final res = changed ? out : walls;
    _planWallsCache[walls] = res;
    return res;
  }

  /// Snap proxies retain the physical core, independently of finish thickness
  /// and the saved leading line. Railings keep their mounting geometry.
  static List<ArchitectWall> coreWalls(List<ArchitectWall> walls) =>
      _cores[walls] ??= List.unmodifiable([
        for (final wall in walls)
          if (wall.railing != null)
            wall
          else
            ArchitectWall(
              id: wall.id,
              startPoint: wall.coreCenterStart,
              endPoint: wall.coreCenterEnd,
              arcBulge: wall.arcBulge,
              thickness: wall.coreThickness,
              exteriorSide: wall.exteriorSide,
              connectStart: wall.connectStart,
              connectEnd: wall.connectEnd,
              doors: wall.doors,
              windows: wall.windows,
            ),
      ]);
  final List<(Offset, Offset)> edges;
  final List<Offset> corners;
  const ArchitectWallGeometry(this.edges, this.corners);
  static final _cache = Expando<ArchitectWallGeometry>();
  static Iterable<List<Offset>> physicalPolygons(
    ArchitectWall wall,
    List<ArchitectWall> walls,
  ) sync* {
    if (wall.railing == null) {
      yield wall.polygonCorners;
      yield wall.coreCorners;
      return;
    }
    if (wall.hasSolidWallBody) yield wall.polygonCorners;
    for (final path in ArchitectRailingGeometry.planPaths(wall, walls: walls)) {
      yield* ArchitectPathSolid.contours(path, tolerance: .0001);
    }
  }

  static ArchitectWallGeometry of(List<ArchitectWall> walls) {
    final cached = _cache[walls];
    if (cached != null) return cached;
    final edges = <(Offset, Offset)>[];
    final corners = <Offset>{};
    final coreFaces = <String, (double, double)>{};
    for (final wall in walls) {
      if (wall.length < 1e-8) continue;
      if (wall.railing != null) {
        if (!wall.isCurved) edges.add((wall.startPoint, wall.endPoint));
        corners.addAll([wall.startPoint, wall.endPoint]);
        for (final polygon in physicalPolygons(wall, walls)) {
          corners.addAll(polygon);
          for (var i = 0; i < polygon.length; i++) {
            edges.add((polygon[i], polygon[(i + 1) % polygon.length]));
          }
        }
        continue;
      }
      if (!wall.isCurved) {
        edges.add((wall.startPoint, wall.endPoint));
        edges.add((wall.coreCenterStart, wall.coreCenterEnd));
      } else {
        final path = wall.facePolygon(0, 0), count = path.length ~/ 2;
        for (var i = 0; i + 1 < count; i++) {
          edges.add((path[i], path[i + 1]));
        }
        corners.addAll([
          wall.startPoint,
          wall.endPoint,
          wall.referencePointAt(.5),
        ]);
      }
      for (final polygon in [wall.polygonCorners, wall.coreCorners]) {
        if (!wall.isCurved) corners.addAll(polygon);
        for (var i = 0; i < polygon.length; i++) {
          edges.add((polygon[i], polygon[(i + 1) % polygon.length]));
        }
      }
      final c =
          wall.centerLineOffset - wall.exteriorSign * wall.coreAsymmetry / 2;
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
      for (var i = 0; i < junction.$1.length; i++) {
        final a =
                junction.$1[i] -
                junction.$1[(i + junction.$1.length - 1) % junction.$1.length],
            b = junction.$1[(i + 1) % junction.$1.length] - junction.$1[i];
        if ((a.dx * b.dy - a.dy * b.dx).abs() > .05 * a.distance * b.distance)
          corners.add(junction.$1[i]);
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
      for (final corner in ArchitectWallGeometry.physicalPolygons(
        wall,
        walls,
      ).expand((polygon) => polygon)) {
        for (final direction in [wall.unitVector, wall.normalVector]) {
          final along = dot(raw - corner, direction);
          final projected = corner + direction * along;
          final distance = (projected - raw).distance;
          if (distance < best) {
            best = distance;
            snapped = projected;
            final overshoot = math.max(0.4, 20.0 / scale);
            final (p1, p2) = along >= 0
                ? (
                    corner - direction * overshoot,
                    projected + direction * overshoot,
                  )
                : (
                    projected - direction * overshoot,
                    corner + direction * overshoot,
                  );
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
    bool coreOnly = false,
  }) {
    if (coreOnly) walls = ArchitectWallGeometry.coreWalls(walls);
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
          for (final p in ArchitectWallGeometry.physicalPolygons(
            a,
            walls,
          ).expand((polygon) => polygon)) {
            for (final q in ArchitectWallGeometry.physicalPolygons(
              b,
              walls,
            ).expand((polygon) => polygon)) {
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
