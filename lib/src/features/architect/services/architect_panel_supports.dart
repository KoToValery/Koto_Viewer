import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_system.dart';

/// Associates facade fields with actual column IDs and preserves their mounting
/// plane through column edits. No geometric proximity rebinding after deletion.
class ArchitectPanelSupports {
  static List<Offset> corners(ArchitectColumn c) {
    if (c.shape == ColumnShape.circular) {
      return [
        for (var i = 0; i < 32; i++)
          c.position +
              Offset(math.cos(i * math.pi / 16), math.sin(i * math.pi / 16)) *
                  c.width /
                  2,
      ];
    }
    final angle = c.rotationDeg * math.pi / 180;
    return [
      for (final p in [
        Offset(-c.width / 2, -c.depth / 2),
        Offset(c.width / 2, -c.depth / 2),
        Offset(c.width / 2, c.depth / 2),
        Offset(-c.width / 2, c.depth / 2),
      ])
        c.position +
            Offset(
              p.dx * math.cos(angle) - p.dy * math.sin(angle),
              p.dx * math.sin(angle) + p.dy * math.cos(angle),
            ),
    ];
  }

  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  static ArchitectStorey synchronize(
    ArchitectStorey next, {
    ArchitectStorey? previous,
  }) {
    if (!next.walls.any((w) => w.system.isPanel)) return next;
    var changed = false;
    final walls = [
      for (final original in next.walls)
        () {
          if (!original.system.isPanel) return original;
          var wall = original;
          final old = previous?.walls.where((w) => w.id == wall.id).firstOrNull;
          final isNew = old == null || !old.system.isPanel;
          if (wall.systemPlacement.columnIds.isEmpty && isNew) {
            final candidates =
                next.columns.where((c) {
                  final points = corners(c);
                  final stations = points.map(
                    (p) => dot(p - wall.centerStart, wall.unitVector),
                  );
                  final offset = dot(
                    c.position - wall.centerStart,
                    wall.normalVector,
                  ).abs();
                  return stations.reduce(math.max) >= -.25 &&
                      stations.reduce(math.min) <= wall.length + .25 &&
                      offset <=
                          math.max(c.width, c.depth) + wall.thickness + .25;
                }).toList()..sort(
                  (a, b) => dot(
                    a.position,
                    wall.unitVector,
                  ).compareTo(dot(b.position, wall.unitVector)),
                );
            if (candidates.isNotEmpty) {
              wall = wall.copyWith(
                systemPlacement: wall.systemPlacement.copyWith(
                  columnIds: candidates.map((c) => c.id).toList(),
                ),
              );
            }
          }
          final supports =
              [
                for (final id in wall.systemPlacement.columnIds)
                  ...next.columns.where((c) => c.id == id),
              ]..sort(
                (a, b) => dot(
                  a.position,
                  wall.unitVector,
                ).compareTo(dot(b.position, wall.unitVector)),
              );
          if (supports.length != wall.systemPlacement.columnIds.length ||
              supports.isEmpty) {
            if (!identical(wall, original)) changed = true;
            return wall;
          }
          final u = wall.unitVector, n = wall.exteriorNormal;
          final outside = supports
              .expand(corners)
              .map((p) => dot(p, n))
              .reduce(math.max);
          final inFront = wall.system.panelMount == ArchitectPanelMount.inFront;
          final plane =
              outside +
              wall.systemPlacement.mountingOffset +
              (inFront ? wall.thickness / 2 : -wall.thickness / 2);
          var start = dot(wall.centerStart, u), end = dot(wall.centerEnd, u);
          if (!inFront && supports.length >= 2) {
            start = corners(
              supports.first,
            ).map((p) => dot(p, u)).reduce(math.max);
            end = corners(supports.last).map((p) => dot(p, u)).reduce(math.min);
          } else if (old != null && previous != null) {
            final oldFirst = previous.columns
                .where((c) => c.id == supports.first.id)
                .firstOrNull;
            final oldLast = previous.columns
                .where((c) => c.id == supports.last.id)
                .firstOrNull;
            if (oldFirst != null &&
                (supports.first.position - oldFirst.position).distance > 1e-8) {
              start =
                  dot(old.centerStart, u) +
                  dot(supports.first.position - oldFirst.position, u);
            }
            if (oldLast != null &&
                (supports.last.position - oldLast.position).distance > 1e-8) {
              end =
                  dot(old.centerEnd, u) +
                  dot(supports.last.position - oldLast.position, u);
            }
          }
          if (end - start < .001) {
            throw ArgumentError('Columns leave no facade span');
          }
          final a = u * start + n * plane - wall.centerOffset,
              b = u * end + n * plane - wall.centerOffset;
          if ((a - wall.startPoint).distance > 1e-8 ||
              (b - wall.endPoint).distance > 1e-8) {
            wall = wall.copyWith(startPoint: a, endPoint: b);
          }
          if (!identical(wall, original)) changed = true;
          return wall;
        }(),
    ];
    return changed ? next.copyWith(walls: walls) : next;
  }

  static ArchitectProject resolve(
    ArchitectProject next, {
    ArchitectProject? previous,
  }) {
    var changed = false;
    final floors = [
      for (final floor in next.storeys)
        () {
          final old = previous?.storeys
              .where((s) => s.id == floor.id)
              .firstOrNull;
          final result = synchronize(floor, previous: old);
          if (!identical(result, floor)) changed = true;
          return result;
        }(),
    ];
    return changed ? next.copyWith(storeys: floors) : next;
  }
}
