import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import 'architect_zone_tool.dart';
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
  const UpdateArchitectWall({required this.storeyId, required this.wall});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    final previous = s.walls.firstWhere((w) => w.id == wall.id);
    ArchitectModelCommand.point(wall.startPoint);
    ArchitectModelCommand.point(wall.endPoint);
    ArchitectModelCommand.positive(wall.thickness);
    ArchitectModelCommand.positive(wall.height);
    Offset attached(Offset p) {
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
                startPoint: attached(other.startPoint),
                endPoint: attached(other.endPoint),
              ),
    ];
    if (walls.any((w) => w.length < .001)) {
      throw ArgumentError('Wall must be at least 1 mm long');
    }
    // Keep hosted opening centres at the same distance from the start.
    for (var i = 0; i < walls.length; i++) {
      final next = walls[i];
      final old = s.walls[i];
      if (next.length == old.length) continue;
      if ([
        ...old.doors.map((d) => (d.offsetRatio, d.width)),
        ...old.windows.map((w) => (w.offsetRatio, w.width)),
      ].any(
        (o) =>
            o.$1 * old.length - o.$2 / 2 < 0 ||
            o.$1 * old.length + o.$2 / 2 > next.length,
      )) {
        throw ArgumentError(
          'A hosted opening would lie outside the edited wall',
        );
      }
      walls[i] = next.copyWith(
        doors: [
          for (final d in old.doors)
            d.copyWith(offsetRatio: d.offsetRatio * old.length / next.length),
        ],
        windows: [
          for (final w in old.windows)
            w.copyWith(offsetRatio: w.offsetRatio * old.length / next.length),
        ],
      );
    }
    return ArchitectModelCommand.replace(project, s.copyWith(walls: walls));
  }
}

/// Split without losing hosted openings or wall properties.
class SplitArchitectWall extends ArchitectModelCommand {
  final String storeyId, wallId, newWallId;
  final double ratio;
  const SplitArchitectWall({
    required this.storeyId,
    required this.wallId,
    required this.newWallId,
    required this.ratio,
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
      final wall = walls.first;
      return UpdateArchitectWall(
        storeyId: storeyId,
        wall: wall.copyWith(
          startPoint: wall.startPoint + delta,
          endPoint: wall.endPoint + delta,
        ),
      ).apply(project);
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
