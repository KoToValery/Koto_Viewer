import '../rendering/architect_path_solid.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_column.dart';
import '../models/architect_overhang.dart';
import '../models/architect_project.dart';
import 'architect_overhang_detector.dart';
import 'architect_command_controller.dart';

class ArchitectColumnClearance {
  final String columnId, key;
  final Offset start, end;
  const ArchitectColumnClearance(this.columnId, this.key, this.start, this.end);
  double get distance => (end - start).distance;
  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double extent(ArchitectColumn c, Offset u) {
    if (c.shape == ColumnShape.circular) return c.width / 2;
    final a = c.rotationDeg * math.pi / 180,
        v = Offset(math.cos(a), math.sin(a));
    return _dot(u, v).abs() * c.width / 2 +
        _dot(u, Offset(-v.dy, v.dx)).abs() * c.depth / 2;
  }

  static List<ArchitectColumnClearance> forColumn(
    ArchitectProject p,
    String id,
  ) {
    final floor = p.activeStorey;
    final column = floor.columns.where((c) => c.id == id).firstOrNull;
    if (column == null) return const [];
    var u = Offset(
      math.cos(column.rotationDeg * math.pi / 180),
      math.sin(column.rotationDeg * math.pi / 180),
    );
    double best = double.infinity;
    String? wallId;
    List<Offset>? wallPoints;
    for (final w in floor.walls.where((w) => !w.isCurved)) {
      final v = w.unitVector,
          n = Offset(-v.dy, v.dx),
          along = _dot(column.position - w.centerStart, v);
      if (along < -extent(column, v) || along > w.length + extent(column, v))
        continue;
      final distance =
          (_dot(column.position - w.centerStart, n).abs() -
                  w.thickness / 2 -
                  extent(column, n))
              .abs();
      if (distance < best - 1e-9 ||
          (distance - best).abs() < 1e-9 &&
              w.id.compareTo(wallId ?? w.id) < 0) {
        best = distance;
        u = v;
        wallId = w.id;
        wallPoints = w.polygonCorners;
      }
    }
    final n = Offset(-u.dy, u.dx), result = <ArchitectColumnClearance>[];
    void add(String key, Offset direction, double distance) {
      if (!distance.isFinite || distance < .0001) return;
      final a = column.position + direction * extent(column, direction);
      final b = a + direction * distance;
      if (result.any(
        (r) => (r.start - a).distance < .001 && (r.end - b).distance < .001,
      ))
        return;
      result.add(ArchitectColumnClearance(id, 'column:$id:$key', a, b));
    }

    if (wallPoints != null) {
      final along = wallPoints.map((v) => _dot(v - column.position, u));
      add(
        'wall:$wallId:start',
        -u,
        -along.reduce(math.min) - extent(column, u),
      );
      add('wall:$wallId:end', u, along.reduce(math.max) - extent(column, u));
    }
    for (final axis in [u, n]) {
      for (final sign in [-1.0, 1.0]) {
        final direction = axis * sign, transverse = Offset(-axis.dy, axis.dx);
        ArchitectColumn? neighbor;
        var nearest = double.infinity;
        for (final c in floor.columns) {
          if (c.id == id) continue;
          final delta = c.position - column.position;
          if (_dot(delta, transverse).abs() >
              extent(column, transverse) + extent(c, transverse) + .001)
            continue;
          final gap =
              _dot(delta, direction) -
              extent(column, direction) -
              extent(c, direction);
          if (gap >= 0 &&
              (gap < nearest - 1e-9 ||
                  (gap - nearest).abs() < 1e-9 &&
                      c.id.compareTo(neighbor?.id ?? c.id) < 0)) {
            nearest = gap;
            neighbor = c;
          }
        }
        if (neighbor != null)
          add(
            'neighbor:${neighbor.id}:${axis == u ? 'u' : 'n'}:$sign',
            direction,
            nearest,
          );
      }
    }
    for (final sign in [-1.0, 1.0]) {
      final direction = n * sign;
      var nearest = double.infinity;
      String? reference;
      for (final overhang in ArchitectOverhangDetector.forProject(
        p,
      ).where((o) => o.kind == ArchitectOverhangKind.erker)) {
        final loops = overhang.path == null
            ? [overhang.polygon]
            : ArchitectPathSolid.contours(overhang.path!);
        var exit = 0.0;
        for (final ring in loops) {
          for (var i = 0; i < ring.length; i++) {
            final a = ring[i],
                v = ring[(i + 1) % ring.length] - a,
                det = _cross(direction, v);
            if (det.abs() < 1e-10) continue;
            final d = a - column.position,
                t = _cross(d, v) / det,
                s = _cross(d, direction) / det;
            if (t > 0 && s >= 0 && s <= 1) exit = math.max(exit, t);
          }
        }
        final gap = exit - extent(column, direction);
        if (exit > 0 && gap > 0 && gap < nearest) {
          nearest = gap;
          reference = overhang.id;
        }
      }
      if (reference != null) add('erker:$reference:$sign', direction, nearest);
    }
    return result;
  }
}

class SetArchitectColumnClearance extends ArchitectModelCommand {
  final String storeyId, columnId, key;
  final double distance;
  const SetArchitectColumnClearance({
    required this.storeyId,
    required this.columnId,
    required this.key,
    required this.distance,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    if (!distance.isFinite || distance < 0)
      throw ArgumentError('Invalid clearance');
    final source = project.copyWith(activeStoreyId: storeyId);
    final gap = ArchitectColumnClearance.forColumn(
      source,
      columnId,
    ).where((r) => r.key == key).firstOrNull;
    if (gap == null) throw ArgumentError('Missing clearance reference');
    final direction = (gap.end - gap.start) / gap.distance;
    return MoveArchitectElement(
      storeyId: storeyId,
      elementId: columnId,
      delta: direction * (gap.distance - distance),
    ).apply(project);
  }
}
