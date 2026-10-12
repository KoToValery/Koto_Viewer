import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import 'architect_zone_tool.dart';
import '../rendering/architect_wall_network.dart';
import 'architect_element_id.dart';
export 'architect_element_id.dart';

/// Commands accept model metres, never screen coordinates or a camera scale.
abstract class ArchitectModelCommand {
  const ArchitectModelCommand();
  ArchitectProject apply(ArchitectProject project);

  static void point(Offset value) {
    if (!value.dx.isFinite || !value.dy.isFinite) {
      throw ArgumentError('Coordinates must be finite model metres');
    }
  }

  static void positive(double value) {
    if (!value.isFinite || value <= 0) throw ArgumentError('Invalid dimension');
  }

  static ArchitectStorey storey(ArchitectProject project, String id) =>
      project.storeys.firstWhere(
        (s) => s.id == id,
        orElse: () => throw ArgumentError('Unknown storey: $id'),
      );

  static ArchitectProject replace(
    ArchitectProject project,
    ArchitectStorey next,
  ) => project.copyWith(
    storeys: [for (final s in project.storeys) s.id == next.id ? next : s],
  );

  static void newId(ArchitectProject project, String id) {
    if (id.isEmpty ||
        project.gridAxes.any((a) => a.id == id) ||
        project.storeys.any(
          (s) => [
            ...s.walls.map((e) => e.id),
            ...s.zones.map((e) => e.id),
            ...s.columns.map((e) => e.id),
            ...s.beams.map((e) => e.id),
            ...s.slabs.map((e) => e.id),
            ...s.openings.map((e) => e.id),
            ...s.stairs.map((e) => e.id),
            ...s.dimensions.map((e) => e.id),
            ...s.annotations.map((e) => e.id),
            ...s.elevationMarkers.map((e) => e.id),
            ...s.cadPrimitives.map((e) => e.id),
            ...s.walls.expand(
              (w) => [
                ...w.doors.map((e) => e.id),
                ...w.windows.map((e) => e.id),
              ],
            ),
          ].contains(id),
        )) {
      throw ArgumentError('Element ID already exists or is empty: $id');
    }
  }
}

class CreateArchitectWall extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectWall wall;
  const CreateArchitectWall({required this.storeyId, required this.wall});
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(wall.startPoint);
    ArchitectModelCommand.point(wall.endPoint);
    ArchitectModelCommand.positive(wall.thickness);
    ArchitectModelCommand.positive(wall.height);
    if (wall.length < .001) {
      throw ArgumentError('Wall must be at least 1 mm long');
    }
    ArchitectModelCommand.newId(project, wall.id);
    final s = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      s.copyWith(walls: [...s.walls, wall]),
    );
  }
}

/// A changed endpoint carries every attached endpoint with it.
class UpdateArchitectWall extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectWall wall;
  final bool carryConnections;
  const UpdateArchitectWall({
    required this.storeyId,
    required this.wall,
    this.carryConnections = true,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    final previous = s.walls.firstWhere((w) => w.id == wall.id);
    ArchitectModelCommand.point(wall.startPoint);
    ArchitectModelCommand.point(wall.endPoint);
    ArchitectModelCommand.positive(wall.thickness);
    ArchitectModelCommand.positive(wall.height);
    Offset attached(Offset p) {
      if (!carryConnections || !previous.connectsAt(p)) return p;
      if ((p - previous.startPoint).distance < 1e-8) return wall.startPoint;
      if ((p - previous.endPoint).distance < 1e-8) return wall.endPoint;
      final vector = p - previous.startPoint;
      final along =
          vector.dx * previous.unitVector.dx +
          vector.dy * previous.unitVector.dy;
      final ratio = along / previous.length;
      if (ratio < 0 || ratio > 1) return p;
      final lateral =
          vector.dx * previous.normalVector.dx +
          vector.dy * previous.normalVector.dy;
      final oldOffset =
          previous.centerOffset.dx * previous.normalVector.dx +
          previous.centerOffset.dy * previous.normalVector.dy;
      final newOffset =
          wall.centerOffset.dx * wall.normalVector.dx +
          wall.centerOffset.dy * wall.normalVector.dy;
      double? offset;
      if (lateral.abs() < 1e-8) {
        offset = 0;
      } else if ((lateral - oldOffset - previous.thickness / 2).abs() < 1e-8) {
        offset = newOffset + wall.thickness / 2;
      } else if ((lateral - oldOffset + previous.thickness / 2).abs() < 1e-8) {
        offset = newOffset - wall.thickness / 2;
      }
      if (offset != null) {
        return wall.startPoint +
            (wall.endPoint - wall.startPoint) * ratio +
            wall.normalVector * offset;
      }
      return p;
    }

    final walls = [
      for (final other in s.walls)
        other.id == wall.id
            ? wall
            : other.copyWith(
                startPoint: other.connectStart
                    ? attached(other.startPoint)
                    : other.startPoint,
                endPoint: other.connectEnd
                    ? attached(other.endPoint)
                    : other.endPoint,
              ),
    ];
    if (walls.any((w) => w.length < .001)) {
      throw ArgumentError('Wall must be at least 1 mm long');
    }
    // Keep hosted opening centres at the same distance from the start.
    for (var i = 0; i < walls.length; i++) {
      final next = walls[i];
      final old = s.walls[i];
      if (next.startPoint != old.startPoint || next.endPoint != old.endPoint) {
        walls[i] = _wallOpeningsAfterEdit(old, next);
      }
    }

    return ArchitectModelCommand.replace(project, s.copyWith(walls: walls));
  }
}

/// Split without losing hosted openings or wall properties.
class SplitArchitectWall extends ArchitectModelCommand {
  final String storeyId, wallId, newWallId;
  final double ratio;
  final bool detachCut;
  const SplitArchitectWall({
    required this.storeyId,
    required this.wallId,
    required this.newWallId,
    required this.ratio,
    this.detachCut = false,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.newId(project, newWallId);
    final s = ArchitectModelCommand.storey(project, storeyId);
    final wall = s.walls.firstWhere((w) => w.id == wallId);
    if (!ratio.isFinite ||
        ratio * wall.length < .001 ||
        (1 - ratio) * wall.length < .001) {
      throw ArgumentError('Invalid split point');
    }
    for (final opening in [
      ...wall.doors.map((d) => (d.offsetRatio, d.width)),
      ...wall.windows.map((w) => (w.offsetRatio, w.width)),
    ]) {
      if ((opening.$1 - ratio).abs() * wall.length < opening.$2 / 2 + .001) {
        throw ArgumentError('Cannot split through an opening');
      }
    }
    final point = wall.startPoint + (wall.endPoint - wall.startPoint) * ratio;
    final first = wall.copyWith(
      endPoint: point,
      connectEnd: !detachCut,
      doors: [
        for (final d in wall.doors)
          if (d.offsetRatio < ratio)
            d.copyWith(offsetRatio: d.offsetRatio / ratio),
      ],
      windows: [
        for (final w in wall.windows)
          if (w.offsetRatio < ratio)
            w.copyWith(offsetRatio: w.offsetRatio / ratio),
      ],
    );
    final second = wall.copyWith(
      id: newWallId,
      startPoint: point,
      connectStart: !detachCut,
      doors: [
        for (final d in wall.doors)
          if (d.offsetRatio > ratio)
            d.copyWith(
              wallId: newWallId,
              offsetRatio: (d.offsetRatio - ratio) / (1 - ratio),
            ),
      ],
      windows: [
        for (final w in wall.windows)
          if (w.offsetRatio > ratio)
            w.copyWith(
              wallId: newWallId,
              offsetRatio: (w.offsetRatio - ratio) / (1 - ratio),
            ),
      ],
    );
    return ArchitectModelCommand.replace(
      project,
      s.copyWith(
        walls: [
          for (final w in s.walls)
            if (w.id == wallId) ...[first, second] else w,
        ],
      ),
    );
  }
}

/// A finite cutting stroke splits all crossed selected walls atomically.
class CutArchitectWalls extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> wallIds;
  final Offset start, end;
  const CutArchitectWalls({
    required this.storeyId,
    required this.wallIds,
    required this.start,
    required this.end,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(start);
    ArchitectModelCommand.point(end);
    if ((end - start).distance < .001) throw ArgumentError('Cut too short');
    var result = project;
    var cuts = 0;
    for (final wall in ArchitectModelCommand.storey(project, storeyId).walls) {
      if (!wallIds.contains(wall.id)) continue;
      final point = ArchitectWallNetwork.intersection(
        wall.startPoint,
        wall.endPoint,
        start,
        end,
        finite: true,
      );
      if (point == null) continue;
      final ratio =
          ((point - wall.startPoint).dx * wall.unitVector.dx +
              (point - wall.startPoint).dy * wall.unitVector.dy) /
          wall.length;
      if (ratio * wall.length < .001 || (1 - ratio) * wall.length < .001) {
        continue;
      }
      result = SplitArchitectWall(
        storeyId: storeyId,
        wallId: wall.id,
        newWallId: ArchitectElementId.next('wall'),
        ratio: ratio,
        detachCut: true,
      ).apply(result);
      cuts++;
    }
    if (cuts == 0) throw ArgumentError('No wall crossed');
    return result;
  }
}

class SetArchitectWallConnection extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> wallIds;
  final bool connected;
  const SetArchitectWallConnection({
    required this.storeyId,
    required this.wallIds,
    required this.connected,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final storey = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(
        walls: [
          for (final w in storey.walls)
            wallIds.contains(w.id)
                ? w.copyWith(connectStart: connected, connectEnd: connected)
                : w,
        ],
      ),
    );
  }
}

class MirrorArchitectWalls extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> wallIds;
  const MirrorArchitectWalls({required this.storeyId, required this.wallIds});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final storey = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(
        walls: [
          for (final w in storey.walls)
            wallIds.contains(w.id) ? w.mirroredAroundCore() : w,
        ],
      ),
    );
  }
}

class PlaceArchitectColumn extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectColumn column;
  const PlaceArchitectColumn({required this.storeyId, required this.column});
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(column.position);
    ArchitectModelCommand.positive(column.width);
    ArchitectModelCommand.positive(column.depth);
    if (!column.rotationDeg.isFinite) throw ArgumentError('Invalid rotation');
    ArchitectModelCommand.newId(project, column.id);
    final s = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      s.copyWith(columns: [...s.columns, column]),
    );
  }
}

class CreateArchitectZone extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectZone zone;
  const CreateArchitectZone({required this.storeyId, required this.zone});
  @override
  ArchitectProject apply(ArchitectProject project) {
    for (final p in zone.polygon) {
      ArchitectModelCommand.point(p);
    }
    if (zone.polygon.length < 3 ||
        zone.area <= 1e-9 ||
        ArchitectZoneGeometry.hasSelfIntersections(zone.polygon)) {
      throw ArgumentError('Invalid zone polygon');
    }
    ArchitectModelCommand.newId(project, zone.id);
    final s = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      s.copyWith(zones: [...s.zones, zone]),
    );
  }
}

/// Translation retains geometry, rotation and hosted openings.
class MoveArchitectElement extends ArchitectModelCommand {
  final String storeyId;
  final String elementId;
  final Offset delta;
  const MoveArchitectElement({
    required this.storeyId,
    required this.elementId,
    required this.delta,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(delta);
    final s = ArchitectModelCommand.storey(project, storeyId);
    final walls = s.walls.where((w) => w.id == elementId);
    if (walls.isNotEmpty) {
      return MoveArchitectElements(
        storeyId: storeyId,
        elementIds: {elementId},
        delta: delta,
      ).apply(project);
    }
    for (final host in s.walls) {
      final doors = host.doors.where((e) => e.id == elementId);
      final windows = host.windows.where((e) => e.id == elementId);
      if (doors.isEmpty && windows.isEmpty) continue;
      final along =
          delta.dx * host.unitVector.dx + delta.dy * host.unitVector.dy;
      final ratio =
          (doors.isNotEmpty
              ? doors.first.offsetRatio
              : windows.first.offsetRatio) +
          along / host.length;
      final width = doors.isNotEmpty ? doors.first.width : windows.first.width;
      if (ratio * host.length < width / 2 ||
          ratio * host.length > host.length - width / 2) {
        throw ArgumentError('Opening would leave its host');
      }
      final next = host.copyWith(
        doors: [
          for (final d in host.doors)
            d.id == elementId ? d.copyWith(offsetRatio: ratio) : d,
        ],
        windows: [
          for (final w in host.windows)
            w.id == elementId ? w.copyWith(offsetRatio: ratio) : w,
        ],
      );
      return ArchitectModelCommand.replace(
        project,
        s.copyWith(
          walls: [for (final w in s.walls) w.id == host.id ? next : w],
        ),
      );
    }
    var found = false;
    bool matches(String id) {
      if (id == elementId) {
        found = true;
        return true;
      }
      return false;
    }

    List<Offset> polygon(List<Offset> points) => [
      for (final p in points) p + delta,
    ];
    final next = s.copyWith(
      walls: [
        for (final e in s.walls)
          matches(e.id)
              ? e.copyWith(
                  startPoint: e.startPoint + delta,
                  endPoint: e.endPoint + delta,
                )
              : e,
      ],
      columns: [
        for (final e in s.columns)
          matches(e.id) ? e.copyWith(position: e.position + delta) : e,
      ],
      zones: [
        for (final e in s.zones)
          matches(e.id) ? e.copyWith(polygon: polygon(e.polygon)) : e,
      ],
      beams: [
        for (final e in s.beams)
          matches(e.id)
              ? e.copyWith(
                  startPoint: e.startPoint + delta,
                  endPoint: e.endPoint + delta,
                )
              : e,
      ],
      slabs: [
        for (final e in s.slabs)
          matches(e.id) ? e.copyWith(polygon: polygon(e.polygon)) : e,
      ],
      openings: [
        for (final e in s.openings)
          matches(e.id) ? e.copyWith(boundary: polygon(e.boundary)) : e,
      ],
      stairs: [
        for (final e in s.stairs)
          matches(e.id)
              ? e.copyWith(
                  startPoint: e.startPoint + delta,
                  endPoint: e.endPoint + delta,
                )
              : e,
      ],
      dimensions: [
        for (final e in s.dimensions)
          matches(e.id)
              ? e.copyWith(
                  startPoint: e.startPoint + delta,
                  endPoint: e.endPoint + delta,
                )
              : e,
      ],
      annotations: [
        for (final e in s.annotations)
          matches(e.id) ? e.copyWith(position: e.position + delta) : e,
      ],
      elevationMarkers: [
        for (final e in s.elevationMarkers)
          matches(e.id) ? e.copyWith(position: e.position + delta) : e,
      ],
      cadPrimitives: [
        for (final e in s.cadPrimitives)
          matches(e.id)
              ? e.copyWith(
                  startPoint: e.startPoint + delta,
                  endPoint: e.endPoint + delta,
                )
              : e,
      ],
    );
    final axes = [
      for (final e in project.gridAxes)
        matches(e.id)
            ? e.copyWith(start: e.start + delta, end: e.end + delta)
            : e,
    ];
    if (!found) throw ArgumentError('Unknown movable element: $elementId');
    return ArchitectModelCommand.replace(project, next).copyWithGridAxes(axes);
  }
}

/// Move selected elements while keeping unselected supports stationary.
class MoveArchitectElements extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> elementIds;
  final Offset delta;
  const MoveArchitectElements({
    required this.storeyId,
    required this.elementIds,
    required this.delta,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(delta);
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final movedWalls = storey.walls
        .where((w) => elementIds.contains(w.id))
        .toList();
    // Only selected elements move. Connected ends slide on stationary supports.
    final nextWalls = {for (final w in storey.walls) w.id: w};
    for (final wall in movedWalls) {
      var moved = wall.copyWith(
        startPoint: wall.startPoint + delta,
        endPoint: wall.endPoint + delta,
      );
      Offset supported(Offset oldPoint, Offset translated, bool connected) {
        if (!connected || wall.isDetached) return translated;
        for (final support in storey.walls) {
          if (elementIds.contains(support.id) || !support.connectsAt(oldPoint)) {
            continue;
          }
          final faces = [
            (support.startPoint, support.endPoint),
            (support.polygonCorners[0], support.polygonCorners[1]),
            (support.polygonCorners[3], support.polygonCorners[2]),
            (support.coreCorners[0], support.coreCorners[1]),
            (support.coreCorners[3], support.coreCorners[2]),
          ];
          for (final face in faces) {
            final u = face.$2 - face.$1;
            final d = oldPoint - face.$1;
            final t = (d.dx * u.dx + d.dy * u.dy) / u.distanceSquared;
            if (t < -1e-8 ||
                t > 1 + 1e-8 ||
                (oldPoint - (face.$1 + u * t)).distance > 1e-8) {
              continue;
            }
            final point = ArchitectWallNetwork.intersection(
              moved.startPoint,
              moved.endPoint,
              face.$1,
              face.$2,
            );
            if (point != null) {
              final v = point - face.$1;
              final along = (v.dx * u.dx + v.dy * u.dy) / u.distanceSquared;
              if (along < -1e-8 || along > 1 + 1e-8) {
                throw ArgumentError('Detach before leaving the support');
              }
              return point;
            }
          }
        }
        return translated;
      }

      final translated = moved;
      moved = moved.copyWith(
        startPoint: supported(
          wall.startPoint,
          moved.startPoint,
          wall.connectStart,
        ),
        endPoint: supported(wall.endPoint, moved.endPoint, wall.connectEnd),
      );
      nextWalls[wall.id] = _wallOpeningsAfterEdit(translated, moved);
    }
    var result = ArchitectModelCommand.replace(
      project,
      storey.copyWith(walls: [for (final w in storey.walls) nextWalls[w.id]!]),
    );
    final carried = {
      for (final w in movedWalls) ...[
        w.id,
        ...w.doors.map((d) => d.id),
        ...w.windows.map((e) => e.id),
      ],
    };
    for (final id in elementIds.difference(carried)) {
      result = MoveArchitectElement(
        storeyId: storeyId,
        elementId: id,
        delta: delta,
      ).apply(result);
    }
    return result;
  }
}

ArchitectWall _wallOpeningsAfterEdit(ArchitectWall old, ArchitectWall next) {
  if (identical(old, next)) return next;
  if (next.length < .001) throw ArgumentError('Wall too short');
  final translation = next.startPoint - old.startPoint;
  final translated =
      ((next.endPoint - old.endPoint) - translation).distance < 1e-8;
  double ratio(double oldRatio, double width) {
    final point =
        old.startPoint +
        old.unitVector * (oldRatio * old.length) +
        (translated ? translation : Offset.zero);
    final d = point - next.startPoint;
    final along = d.dx * next.unitVector.dx + d.dy * next.unitVector.dy;
    if (along - width / 2 < -1e-8 || along + width / 2 > next.length + 1e-8) {
      throw ArgumentError('Opening would leave its host');
    }
    return along / next.length;
  }

  return next.copyWith(
    doors: [
      for (final d in old.doors)
        d.copyWith(offsetRatio: ratio(d.offsetRatio, d.width)),
    ],
    windows: [
      for (final w in old.windows)
        w.copyWith(offsetRatio: ratio(w.offsetRatio, w.width)),
    ],
  );
}

/// Extend/trim an endpoint while keeping openings at their physical locations.
class ExtendArchitectWall extends ArchitectModelCommand {
  final String storeyId, wallId;
  final Offset target;
  const ExtendArchitectWall({
    required this.storeyId,
    required this.wallId,
    required this.target,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(target);
    final s = ArchitectModelCommand.storey(project, storeyId);
    final wall = s.walls.firstWhere((w) => w.id == wallId);
    final delta = target - wall.startPoint;
    final along = delta.dx * wall.unitVector.dx + delta.dy * wall.unitVector.dy;
    final point = wall.startPoint + wall.unitVector * along;
    final atStart =
        (point - wall.startPoint).distance < (point - wall.endPoint).distance;
    final next = atStart
        ? wall.copyWith(startPoint: point)
        : wall.copyWith(endPoint: point);
    final updated = UpdateArchitectWall(
      storeyId: storeyId,
      wall: next,
    ).apply(project);
    return ArchitectModelCommand.replace(
      updated,
      updated.activeStorey.copyWith(
        walls: [
          for (final w in updated.activeStorey.walls)
            _wallOpeningsAfterEdit(
              s.walls.firstWhere((old) => old.id == w.id),
              w,
            ),
        ],
      ),
    );
  }
}

/// Extend several selected walls to their nearest shared line intersections.
class JoinArchitectWalls extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> wallIds;
  const JoinArchitectWalls({required this.storeyId, required this.wallIds});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    final walls = s.walls.where((w) => wallIds.contains(w.id)).toList();
    if (walls.length < 2) throw ArgumentError('Select two walls');
    final targets = <(String, bool), Offset>{};
    void extend(ArchitectWall wall, Offset point) {
      final d = point - wall.startPoint;
      final along = d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
      final atStart = along < -1e-8;
      if (!atStart && along <= wall.length + 1e-8) return;
      final key = (wall.id, atStart);
      final end = atStart ? wall.startPoint : wall.endPoint;
      if (!targets.containsKey(key) ||
          (point - end).distance < (targets[key]! - end).distance) {
        targets[key] = point;
      }
    }

    var compatible = false;
    for (var i = 0; i < walls.length; i++) {
      final a = walls[i];
      for (final b in walls.skip(i + 1)) {
        final point = ArchitectWallNetwork.intersection(
          a.startPoint,
          a.endPoint,
          b.startPoint,
          b.endPoint,
        );
        if (point != null) {
          compatible = true;
          extend(a, point);
          extend(b, point);
        } else {
          final d = b.startPoint - a.startPoint;
          if ((d.dx * a.normalVector.dx + d.dy * a.normalVector.dy).abs() >
              1e-8) {
            continue;
          }
          compatible = true;
          final ends =
              [
                (a.startPoint, b.startPoint),
                (a.startPoint, b.endPoint),
                (a.endPoint, b.startPoint),
                (a.endPoint, b.endPoint),
              ]..sort(
                (x, y) =>
                    (x.$1 - x.$2).distance.compareTo((y.$1 - y.$2).distance),
              );
          final mid = (ends.first.$1 + ends.first.$2) / 2;
          extend(a, mid);
          extend(b, mid);
        }
      }
    }
    if (!compatible) {
      throw ArgumentError('Parallel separated walls cannot join');
    }
    var result = project;
    for (final wall in walls) {
      final next = wall.copyWith(
        startPoint: targets[(wall.id, true)],
        endPoint: targets[(wall.id, false)],
        connectStart: true,
        connectEnd: true,
      );
      result = UpdateArchitectWall(
        storeyId: storeyId,
        wall: next,
      ).apply(result);
    }
    return ArchitectModelCommand.replace(
      result,
      result.activeStorey.copyWith(
        walls: [
          for (final w in result.activeStorey.walls)
            _wallOpeningsAfterEdit(
              s.walls.firstWhere((old) => old.id == w.id),
              w,
            ),
        ],
      ),
    );
  }
}

class SetArchitectWallDimensions extends ArchitectModelCommand {
  final String storeyId;
  final String wallId;
  final double thickness;
  final double height;
  const SetArchitectWallDimensions({
    required this.storeyId,
    required this.wallId,
    required this.thickness,
    required this.height,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.positive(thickness);
    ArchitectModelCommand.positive(height);
    final s = ArchitectModelCommand.storey(project, storeyId);
    if (!s.walls.any((w) => w.id == wallId)) {
      throw ArgumentError('Unknown wall: $wallId');
    }
    return ArchitectModelCommand.replace(
      project,
      s.copyWith(
        walls: [
          for (final w in s.walls)
            w.id == wallId
                ? w.copyWith(thickness: thickness, height: height)
                : w,
        ],
      ),
    );
  }
}

/// Shared transaction/Undo pipeline for UI and external automation.
class ArchitectCommandController extends ChangeNotifier {
  ArchitectProject _project;
  final List<ArchitectProject> _undo = [];
  final List<ArchitectProject> _redo = [];
  static const historyLimit = 100;
  ArchitectCommandController(this._project);
  ArchitectProject get project => _project;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void commit(ArchitectProject next) {
    if (identical(next, _project)) return;
    _undo.add(_project);
    if (_undo.length > historyLimit) _undo.removeAt(0);
    _redo.clear();
    _project = next;
    notifyListeners();
  }

  ArchitectProject execute(ArchitectModelCommand command) =>
      executeBatch([command]);
  ArchitectProject executeBatch(Iterable<ArchitectModelCommand> commands) {
    var next = _project;
    // Validation completes before publishing; failure leaves history untouched.
    for (final command in commands) {
      next = command.apply(next);
    }
    commit(next);
    return _project;
  }

  void restore(ArchitectProject project) {
    _project = project;
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  /// Viewing another floor does not consume an Undo step or discard Redo.
  void activateStorey(String id) {
    ArchitectModelCommand.storey(_project, id);
    if (id == _project.activeStoreyId) return;
    _project = _project.copyWith(activeStoreyId: id);
    notifyListeners();
  }

  ArchitectProject _retainViewedStorey(ArchitectProject snapshot) {
    final id = _project.activeStoreyId;
    return id == snapshot.activeStoreyId ||
            !snapshot.storeys.any((s) => s.id == id)
        ? snapshot
        : snapshot.copyWith(activeStoreyId: id);
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_project);
    _project = _retainViewedStorey(_undo.removeLast());
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_project);
    _project = _retainViewedStorey(_redo.removeLast());
    notifyListeners();
  }
}
