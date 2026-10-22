import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// Shared model-space drafting for elevation and section markers.
class ArchitectViewPlacement {
  final Offset start, end, direction;
  final Offset? target;
  final ArchitectWall? wall;
  final bool aligned;
  final double? viewDepth;
  const ArchitectViewPlacement(
    this.start,
    this.end,
    this.direction,
    this.target,
    this.wall,
    this.aligned,
    {this.viewDepth}
  );
  Offset get axis => (end - start) / (end - start).distance;
  Offset get centre => (start + end) / 2;

  /// The third point sets both the viewing side and the far boundary. Its
  /// distance along the marker is irrelevant: depth is always perpendicular.
  static ({int side, double depth})? resolve(
    Offset start,
    Offset end,
    Offset point,
  ) {
    final delta = end - start;
    if (delta.distance < .01) return null;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    final distance = _dot(point - start, normal);
    if (distance.abs() < .01) return null;
    return (side: distance < 0 ? -1 : 1, depth: distance.abs());
  }

  static List<Offset> anchors(ArchitectProject project) => [
    for (final a in project.gridAxes) ...[a.start, a.end],
    for (final s in project.storeys) ...[
      for (final w in s.walls) ...[w.startPoint, w.endPoint],
      for (final slab in s.slabs) ...slab.polygon,
      for (final stair in s.stairs) ...[
        ...stair.plan.walkingLine,
        stair.displayBounds.center,
        stair.displayBounds.topLeft,
        stair.displayBounds.bottomRight,
      ],
    ],
  ];

  static Offset snapStart(
    ArchitectProject project,
    Offset point,
    double tolerance,
  ) {
    Offset result = point;
    var best = tolerance;
    for (final anchor in anchors(project)) {
      final distance = (point - anchor).distance;
      if (distance < best) {
        best = distance;
        result = anchor;
      }
    }
    return result;
  }

  static Offset snapEnd(ArchitectProject project, Offset start, Offset point) {
    final delta = point - start;
    if (delta.distance < .01) return point;
    final candidates = <Offset>[
      const Offset(1, 0),
      const Offset(0, 1),
      for (final a in project.gridAxes) a.end - a.start,
      for (final s in project.storeys) ...[
        for (final w in s.walls) w.endPoint - w.startPoint,
        for (final stair in s.stairs)
          for (var i = 1; i < stair.plan.walkingLine.length; i++)
            stair.plan.walkingLine[i] - stair.plan.walkingLine[i - 1],
      ],
    ];
    var score = math.cos(math.pi / 15);
    Offset? axis;
    for (final candidate in candidates) {
      if (candidate.distance < .01) continue;
      final unit = candidate / candidate.distance;
      final alignment = _dot(delta, unit).abs() / delta.distance;
      if (alignment > score) {
        score = alignment;
        axis = unit;
      }
    }
    return axis == null ? point : start + axis * _dot(delta, axis);
  }

  static ArchitectViewPlacement preview(
    ArchitectProject project,
    Rect bounds,
    Offset start,
    Offset? end,
    Offset? pointer,
  ) {
    final walls = project.storeys
        .expand((s) => s.walls)
        .where((w) => w.length > .01)
        .toList();
    Offset axis = const Offset(1, 0);
    if (end == null && pointer == null && walls.isNotEmpty) {
      walls.sort(
        (a, b) => _wallDistance(a, start).compareTo(_wallDistance(b, start)),
      );
      axis = walls.first.unitVector;
      if (_dot(bounds.center - start, axis) < 0) axis = -axis;
    }
    var candidate =
        end ??
        (pointer == null
            ? start + axis * math.max(bounds.width, bounds.height) * .65
            : snapEnd(project, start, pointer));
    if ((candidate - start).distance < .01) {
      candidate = start + axis * math.max(bounds.width, bounds.height) * .65;
    }
    axis = (candidate - start) / (candidate - start).distance;
    final centre = (start + candidate) / 2;
    final normal = Offset(-axis.dy, axis.dx);
    final direction =
        normal *
        (_dot(
                  (end == null ? bounds.center : pointer ?? bounds.center) -
                      centre,
                  normal,
                ) >=
                0
            ? 1
            : -1);
    ArchitectWall? targetWall;
    Offset? target;
    var nearest = double.infinity;
    for (final wall in walls) {
      if (_dot(wall.unitVector, axis).abs() < math.cos(math.pi / 15)) continue;
      final denominator = _dot(direction, wall.normalVector);
      if (denominator.abs() < 1e-8) continue;
      final distance =
          _dot(wall.startPoint - centre, wall.normalVector) / denominator;
      if (distance < .01 || distance >= nearest) continue;
      final hit = centre + direction * distance;
      final along = _dot(hit - wall.startPoint, wall.unitVector);
      if (along < -.1 || along > wall.length + .1) continue;
      nearest = distance;
      target = hit;
      targetWall = wall;
    }
    final raw = end == null ? pointer : null;
    return ArchitectViewPlacement(
      start,
      candidate,
      direction,
      target,
      targetWall,
      raw != null && (raw - candidate).distance > 1e-6,
      viewDepth: end == null || pointer == null
          ? null : resolve(start, end, pointer)?.depth,
    );
  }

  static double _wallDistance(ArchitectWall wall, Offset p) {
    final along = _dot(
      p - wall.startPoint,
      wall.unitVector,
    ).clamp(0.0, wall.length).toDouble();
    return (p - wall.startPoint - wall.unitVector * along).distance;
  }
}
