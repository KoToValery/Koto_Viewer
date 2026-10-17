import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/scene/bim_point_index.dart';
import '../../bim_editing/scene/bim_bounds_index.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_wall_geometry.dart';

typedef ArchitectSnapPoint = ({Offset point, String label, String owner});
typedef ArchitectSnapEdge = ({Offset a, Offset b, String owner});
typedef ArchitectSnapCircle = ({Offset center, double radius, String owner});

/// Immutable drawing geometry shared by every placement and editing tool.
class ArchitectSnapGeometry {
  static final _cache = Expando<ArchitectSnapGeometry>();
  final _index = BimPointIndex<ArchitectSnapPoint>();
  final _edgeIndex = BimBoundsIndex<ArchitectSnapEdge>();
  final _circleIndex = BimBoundsIndex<ArchitectSnapCircle>();
  final List<ArchitectSnapEdge> edges = [];
  final List<ArchitectSnapCircle> circles = [];
  final List<ArchitectSnapPoint> alignmentPoints = [];

  static ArchitectSnapGeometry of(ArchitectProject project) =>
      _cache[project] ??= ArchitectSnapGeometry._(project);

  ArchitectSnapGeometry._(ArchitectProject project) {
    void point(Offset p, String label, String owner) {
      if (!p.dx.isFinite || !p.dy.isFinite) return;
      final value = (point: p, label: label, owner: owner);
      _index.add(p, value);
      if (label != 'Midpoint') alignmentPoints.add(value);
    }

    void edge(
      Offset a,
      Offset b,
      String owner, {
      bool includeMidpoint = true,
    }) {
      if ((b - a).distanceSquared < 1e-16) return;
      edges.add((a: a, b: b, owner: owner));
      point(a, 'Endpoint', owner);
      point(b, 'Endpoint', owner);
      if (includeMidpoint && (b - a).distance > 0.45) {
        point((a + b) / 2, 'Midpoint', owner);
      }
    }

    void polygon(List<Offset> vertices, String owner) {
      for (var i = 0; i < vertices.length; i++) {
        edge(vertices[i], vertices[(i + 1) % vertices.length], owner);
      }
    }

    void wallBox(List<Offset> corners, String owner) {
      for (var i = 0; i < corners.length; i++) {
        // Indices 1 and 3 are short wall end-caps whose center is already the wall axis Endpoint.
        final isEndCap = corners.length == 4 && (i == 1 || i == 3);
        edge(
          corners[i],
          corners[(i + 1) % corners.length],
          owner,
          includeMidpoint: !isEndCap,
        );
      }
    }

    void circle(Offset center, double radius, String owner) {
      point(center, 'Center', owner);
      if (radius <= 0) return;
      circles.add((center: center, radius: radius, owner: owner));
      for (final u in const [
        Offset(1, 0),
        Offset(0, 1),
        Offset(-1, 0),
        Offset(0, -1),
      ]) {
        point(center + u * radius, 'Vertex', owner);
      }
    }

    final floor = project.activeStorey;
    final activeIdx = project.storeys.indexWhere((s) => s.id == floor.id);
    final referenceWalls = floor.walls.isNotEmpty
        ? floor.walls
        : (activeIdx > 0 ? project.storeys[activeIdx - 1].walls : floor.walls);

    for (final wall in referenceWalls) {
      edge(wall.startPoint, wall.endPoint, wall.id);
      edge(wall.coreCenterStart, wall.coreCenterEnd, wall.id);
      wallBox(wall.polygonCorners, wall.id);
      wallBox(wall.coreCorners, wall.id);
      for (final opening in [
        for (final d in wall.doors) (d.id, d.offsetRatio, d.width),
        for (final w in wall.windows) (w.id, w.offsetRatio, w.width),
      ]) {
        final center =
            wall.centerStart + wall.unitVector * (wall.length * opening.$2);
        point(center, 'Center', opening.$1);
        final along = wall.unitVector * opening.$3 / 2;
        final across = wall.normalVector * wall.thickness / 2;
        wallBox([
          center - along - across,
          center + along - across,
          center + along + across,
          center - along + across,
        ], opening.$1);
      }
    }
    // Joined material corners can extend beyond the individual rectangles.
    final joined = ArchitectWallGeometry.of(referenceWalls);
    for (final p in joined.corners) {
      point(p, 'Vertex', '@wall-joints');
    }
    for (final s in joined.edges) {
      edges.add((a: s.$1, b: s.$2, owner: '@wall-joints'));
    }
    for (final zone in floor.zones) {
      polygon(zone.polygon, zone.id);
    }
    for (final slab in floor.slabs) {
      polygon(slab.polygon, slab.id);
    }
    for (final roof in floor.roofs) {
      polygon(roof.points, roof.id);
    }
    for (final opening in floor.openings) {
      polygon(opening.boundary, opening.id);
    }
    for (final beam in floor.beams) {
      edge(beam.startPoint, beam.endPoint, beam.id);
      polygon(beam.polygonCorners, beam.id);
    }
    for (final stair in floor.stairs) {
      if (stair.design == null) edge(stair.startPoint, stair.endPoint, stair.id);
      for (final footprint in stair.plan.footprints) {
        polygon(footprint, stair.id);
      }
    }
    for (final column in floor.columns) {
      if (column.shape == ColumnShape.circular) {
        circle(column.position, column.width / 2, column.id);
      } else {
        final angle = column.rotationDeg * math.pi / 180;
        final u = Offset(math.cos(angle), math.sin(angle)) * column.width / 2;
        final v = Offset(-math.sin(angle), math.cos(angle)) * column.depth / 2;
        polygon([
          column.position - u - v,
          column.position + u - v,
          column.position + u + v,
          column.position - u + v,
        ], column.id);
        point(column.position, 'Center', column.id);
      }
    }
    for (final primitive in floor.cadPrimitives) {
      switch (primitive.type) {
        case CadPrimitiveType.line:
          edge(primitive.startPoint, primitive.endPoint, primitive.id);
        case CadPrimitiveType.rect:
          polygon(primitive.polygonCorners, primitive.id);
          point(
            Rect.fromPoints(primitive.startPoint, primitive.endPoint).center,
            'Center',
            primitive.id,
          );
        case CadPrimitiveType.circle:
          circle(
            primitive.startPoint,
            (primitive.endPoint - primitive.startPoint).distance,
            primitive.id,
          );
      }
    }
    for (final dimension in floor.dimensions) {
      point(dimension.startPoint, 'Endpoint', dimension.id);
      point(dimension.endPoint, 'Endpoint', dimension.id);
    }
    for (final marker in floor.elevationMarkers) {
      point(marker.position, 'Vertex', marker.id);
    }
    for (final annotation in floor.annotations) {
      point(annotation.position, 'Vertex', annotation.id);
    }
    final axes = project.gridAxes;
    for (var i = 0; i < axes.length; i++) {
      point(axes[i].start, 'Axis endpoint', axes[i].id);
      point(axes[i].end, 'Axis endpoint', axes[i].id);
      final u = axes[i].end - axes[i].start;
      for (var j = i + 1; j < axes.length; j++) {
        final v = axes[j].end - axes[j].start;
        final cross = u.dx * v.dy - u.dy * v.dx;
        if (cross.abs() <= 1e-12 * u.distance * v.distance) continue;
        final d = axes[j].start - axes[i].start;
        final t = (d.dx * v.dy - d.dy * v.dx) / cross;
        final intersection = axes[i].start + u * t;
        point(
          Offset(
            u.dx == 0
                ? axes[i].start.dx
                : v.dx == 0
                ? axes[j].start.dx
                : intersection.dx,
            u.dy == 0
                ? axes[i].start.dy
                : v.dy == 0
                ? axes[j].start.dy
                : intersection.dy,
          ),
          'Axis intersection',
          '@axes',
        );
      }
    }
    for (final edge in edges) {
      _edgeIndex.add(Rect.fromPoints(edge.a, edge.b), edge);
    }
    for (final circle in circles) {
      _circleIndex.add(
        Rect.fromCircle(center: circle.center, radius: circle.radius),
        circle,
      );
    }
    _index.seal();
  }

  Iterable<ArchitectSnapEdge> nearbyEdges(Offset raw, double radius) =>
      _edgeIndex.query(Rect.fromCircle(center: raw, radius: radius));
  Iterable<ArchitectSnapCircle> nearbyCircles(Offset raw, double radius) =>
      _circleIndex.query(Rect.fromCircle(center: raw, radius: radius));

  Iterable<ArchitectSnapPoint> query(Offset raw, double radius) =>
      _index.query(raw, radius);
}
