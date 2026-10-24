import 'dart:math' as math;
import '../models/architect_contour.dart';
import '../models/architect_wall_type.dart';
import 'architect_slab_assemblies.dart';
import 'architect_roof_placement.dart';
import 'dart:ui';
import '../adapters/architect_element_adapters.dart';
import '../../bim_editing/commands/bim_edit_history.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import 'architect_element_tool.dart';
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../rendering/architect_scene_geometry.dart';
import 'architect_polygon_geometry.dart';
import '../models/architect_wall.dart';
import '../models/architect_zone.dart';
import 'architect_zone_tool.dart';
import '../rendering/architect_wall_network.dart';
import 'architect_element_id.dart';
import 'architect_wall_relations.dart';
import 'architect_dimension_chain.dart';
import 'architect_stair_rules.dart';
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
            ...s.groups.map((e) => e.id),
            ...s.walls.map((e) => e.id),
            ...s.zones.map((e) => e.id),
            ...s.columns.map((e) => e.id),
            ...s.beams.map((e) => e.id),
            ...s.slabs.map((e) => e.id),
            ...s.roofs.map((e) => e.id),
            ...s.openings.map((e) => e.id),
            ...s.stairs.map((e) => e.id),
            ...s.dimensions.map((e) => e.id),
            ...s.annotations.map((e) => e.id),
            ...s.elevationMarkers.map((e) => e.id),
            ...s.cadPrimitives.map((e) => e.id),
            ...s.components.map((e) => e.id),
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

class GroupArchitectElements extends ArchitectModelCommand {
  final String storeyId, groupId;
  final Set<String> elementIds;
  const GroupArchitectElements({required this.storeyId, required this.groupId, required this.elementIds});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    if (elementIds.length < 2 || !s.groupableIds.containsAll(elementIds) ||
        s.groups.any((g) => g.elementIds.any(elementIds.contains))) {
      throw ArgumentError('Groups require at least two ungrouped editable elements on one storey');
    }
    ArchitectModelCommand.newId(project, groupId);
    return ArchitectModelCommand.replace(project, s.copyWith(groups: [
      ...s.groups, ArchitectElementGroup(id: groupId, elementIds: Set.unmodifiable(elementIds)),
    ]));
  }
}

class UngroupArchitectElements extends ArchitectModelCommand {
  final String storeyId, groupId;
  const UngroupArchitectElements({required this.storeyId, required this.groupId});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    if (!s.groups.any((g) => g.id == groupId)) throw ArgumentError('Unknown group');
    return ArchitectModelCommand.replace(project, s.copyWith(groups: s.groups.where((g) => g.id != groupId).toList()));
  }
}

class AddArchitectGroupMembers extends ArchitectModelCommand {
  final String storeyId, groupId;
  final Set<String> elementIds;
  const AddArchitectGroupMembers({required this.storeyId, required this.groupId, required this.elementIds});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    if (!s.groups.any((g) => g.id == groupId) || !s.groupableIds.containsAll(elementIds) ||
        s.groups.any((g) => g.id != groupId && g.elementIds.any(elementIds.contains))) {
      throw ArgumentError('Invalid group members');
    }
    return ArchitectModelCommand.replace(project, s.copyWith(groups: [for (final g in s.groups)
      g.id == groupId ? ArchitectElementGroup(id: g.id, elementIds: {...g.elementIds, ...elementIds}) : g]));
  }
}

class CreateArchitectWall extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectWall wall;
  const CreateArchitectWall({required this.storeyId, required this.wall});
  @override
  ArchitectProject apply(ArchitectProject project) {
    if(wall.layers.isNotEmpty) {
      ArchitectMaterialLayer.validate(wall.layers);
      final total=wall.layers.fold(0.0,(v,l)=>v+l.thickness);
      if((wall.thickness-total).abs()>1e-8)throw ArgumentError('Wall thickness differs from composition');
    }
    wall.plinth.validate();
    wall.validateGeometry();
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
  final Set<String> fixedWallIds;
  const UpdateArchitectWall({
    required this.storeyId,
    required this.wall,
    this.carryConnections = true,
    this.fixedWallIds = const {},
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    final previous = s.walls.firstWhere((w) => w.id == wall.id);
    if(wall.layers.isNotEmpty) {
      ArchitectMaterialLayer.validate(wall.layers);
      final total=wall.layers.fold(0.0,(v,l)=>v+l.thickness);
      if((wall.thickness-total).abs()>1e-8)throw ArgumentError('Wall thickness differs from composition');
    }
    wall.plinth.validate();
    wall.validateGeometry();
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
            : fixedWallIds.contains(other.id)
            ? other
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
      if ((opening.$1 - ratio).abs() * wall.length < wall.openingArcSpan(opening.$2) / 2 + .001) {
        throw ArgumentError('Cannot split through an opening');
      }
    }
    final point = wall.referencePointAt(ratio);
    final first = wall.copyWith(
      endPoint: point,
      arcBulge:wall.isCurved?math.tan(math.atan(wall.arcBulge)*ratio):0,
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
      arcBulge:wall.isCurved?math.tan(math.atan(wall.arcBulge)*(1-ratio)):0,
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
        groups: [for (final g in s.groups) g.elementIds.contains(wallId)
          ? ArchitectElementGroup(id: g.id, elementIds: {...g.elementIds, newWallId}) : g],
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
    final delta = end - start;
    final len = delta.distance;
    if (len < .001) throw ArgumentError('Cut too short');
    final cutter = ArchitectWall(
      id: 'cutter',
      startPoint: start,
      endPoint: end,
    );
    var result = project;
    var cuts = 0;
    for (final wall in ArchitectModelCommand.storey(project, storeyId).walls) {
      if (!wallIds.contains(wall.id)) continue;
      final points = wall.intersections(cutter);
      if (points.isEmpty) continue;
      // Process from the far end so all earlier offsets stay on the retained first wall.
      final ratios = [
        for (final p in points)
          wall.isCurved
              ? wall.arc!.parameter(p)
              : BimLineGeometry.parameter(p, wall.startPoint, wall.endPoint),
      ]..sort((a, b) => b.compareTo(a));
      var retained = 1.0;
      for (final originalRatio in ratios) {
        final ratio = originalRatio / retained;
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
        retained = originalRatio;
      }
    }
    if (cuts == 0) throw ArgumentError('No wall crossed');
    return result;
  }

  /// Returns the IDs of the resulting wall segments that lie on the chosen side of the cut line [start] -> [end].
  /// If [pickSide] is null, all resulting wall segments are returned.
  static Set<String> resolveSelectedWallIds({
    required ArchitectProject before,
    required ArchitectProject after,
    required String storeyId,
    required Set<String> cutWallIds,
    required Offset start,
    required Offset end,
    Offset? pickSide,
    int? targetSide,
  }) {
    final sAfter = ArchitectModelCommand.storey(after, storeyId);
    final sBefore = ArchitectModelCommand.storey(before, storeyId);
    final beforeIds = sBefore.walls.map((w) => w.id).toSet();
    final resultingWalls = sAfter.walls
        .where((w) => cutWallIds.contains(w.id) || !beforeIds.contains(w.id))
        .toList();
    if (resultingWalls.isEmpty) return cutWallIds;
    if (targetSide == 0) return resultingWalls.map((w) => w.id).toSet();
    if (pickSide == null && targetSide == null) {
      return resultingWalls.map((w) => w.id).toSet();
    }

    final v = end - start;
    double sideOf(Offset p) =>
        v.dx * (p.dy - start.dy) - v.dy * (p.dx - start.dx);

    final int resolvedTarget;
    if (targetSide != null && targetSide != 0) {
      resolvedTarget = targetSide > 0 ? 1 : -1;
    } else if (pickSide != null) {
      final pickSign = sideOf(pickSide);
      if (pickSign.abs() < 1e-6) {
        return resultingWalls.map((w) => w.id).toSet();
      }
      resolvedTarget = pickSign > 0 ? 1 : -1;
    } else {
      return resultingWalls.map((w) => w.id).toSet();
    }

    final selected = <String>{};
    for (final w in resultingWalls) {
      final mid = w.referencePointAt(0.5);
      final s = sideOf(mid);
      final wSign = s >= 0 ? 1 : -1;
      if (wSign == resolvedTarget) {
        selected.add(w.id);
      }
    }
    return selected.isEmpty
        ? resultingWalls.map((w) => w.id).toSet()
        : selected;
  }
}

/// Remove the picked interval between crossings; retained pieces keep hosts.
class TrimArchitectWall extends ArchitectModelCommand {
  final String storeyId, wallId;
  final Offset pick;
  const TrimArchitectWall({
    required this.storeyId,
    required this.wallId,
    required this.pick,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(pick);
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final wall = storey.walls.firstWhere((w) => w.id == wallId);
    final span = ArchitectWallTrimSpan.at(wall, storey.walls, pick);
    for (final opening in [
      ...wall.doors.map((o) => (o.offsetRatio, o.width)),
      ...wall.windows.map((o) => (o.offsetRatio, o.width)),
    ]) {
      for (final cut in [span.from, span.to]) {
        if (cut > 0 &&
            cut < 1 &&
            (cut - opening.$1).abs() * wall.length < wall.openingArcSpan(opening.$2) / 2 + .001) {
          throw ArgumentError('Cannot cut through an opening');
        }
      }
    }
    ArchitectWall slice(double from, double to, String id) => wall.copyWith(
      id: id,
      startPoint: wall.referencePointAt(from),
      endPoint: wall.referencePointAt(to),
      arcBulge:wall.isCurved?math.tan(math.atan(wall.arcBulge)*(to-from)):0,
      connectStart: from == 0 ? wall.connectStart : true,
      connectEnd: to == 1 ? wall.connectEnd : true,
      doors: [
        for (final d in wall.doors)
          if (d.offsetRatio > from && d.offsetRatio < to)
            d.copyWith(
              wallId: id,
              offsetRatio: (d.offsetRatio - from) / (to - from),
            ),
      ],
      windows: [
        for (final w in wall.windows)
          if (w.offsetRatio > from && w.offsetRatio < to)
            w.copyWith(
              wallId: id,
              offsetRatio: (w.offsetRatio - from) / (to - from),
            ),
      ],
    );
    final retained = [
      if (span.from > 0) slice(0, span.from, wall.id),
      if (span.to < 1)
        slice(
          span.to,
          1,
          span.from == 0 ? wall.id : ArchitectElementId.next('wall'),
        ),
    ];
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(
        groups: [for (final g in storey.groups) g.elementIds.contains(wall.id)
          ? ArchitectElementGroup(id: g.id, elementIds: {
            ...g.elementIds.where((id) => id != wall.id), ...retained.map((w) => w.id),
          }) : g],
        walls: [
          for (final w in storey.walls)
            if (w.id == wall.id) ...retained else w,
        ],
      ),
    );
  }
}

class SetArchitectWallClearance extends ArchitectModelCommand {
  final String storeyId, wallId, neighborId;
  final double distance;
  const SetArchitectWallClearance({
    required this.storeyId,
    required this.wallId,
    required this.neighborId,
    required this.distance,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError('Invalid clearance');
    }
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final wall = storey.walls.firstWhere((w) => w.id == wallId);
    final clearance = ArchitectWallClearance.nearest(wall, storey.walls)
        .firstWhere(
          (c) => c.neighborId == neighborId,
          orElse: () =>
              throw ArgumentError('Wall no longer faces the neighbor'),
        );
    final delta =
        wall.normalVector * (clearance.side * (clearance.distance - distance));
    return MoveArchitectElements(
      storeyId: storeyId,
      elementIds: {wallId},
      delta: delta,
      extendSupports: true,
    ).apply(project);
  }
}

/// Edit just one supported junction; the opposite wall endpoint stays fixed.
class SetArchitectWallEndpointClearance extends ArchitectModelCommand {
  final String storeyId, wallId, neighborId, supportId;
  final bool atStart;
  final double distance;
  const SetArchitectWallEndpointClearance({
    required this.storeyId,
    required this.wallId,
    required this.neighborId,
    required this.supportId,
    required this.atStart,
    required this.distance,
  });

  @override
  ArchitectProject apply(ArchitectProject project) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError('Invalid clearance');
    }
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final wall = storey.walls.firstWhere((w) => w.id == wallId);
    final gap =
        ArchitectWallClearance.endpoints(
              wall,
              storey.walls,
              includeParallel: true,
            )
            .where(
              (g) =>
                  g.atStart == atStart &&
                  g.neighborId == neighborId &&
                  g.supportId == supportId,
            )
            .firstOrNull;
    if (gap == null) {
      throw ArgumentError('Junction no longer faces the reference');
    }
    final basis = storey.walls.firstWhere((w) => w.id == supportId);
    final direction = basis.unitVector * gap.side.toDouble();
    final currentPoint = atStart ? wall.startPoint : wall.endPoint;
    final edgeOffset = gap.start - currentPoint;
    var point = gap.end - direction * distance - edgeOffset;

    // Refine point accounting for wall angle change during pivot
    for (var iter = 0; iter < 5; iter++) {
      final testWall = wall.copyWith(
        startPoint: atStart ? point : null,
        endPoint: atStart ? null : point,
      );
      final testGaps = ArchitectWallClearance.endpoints(
        testWall,
        storey.walls,
        includeParallel: true,
      );
      final testGap = testGaps
          .where(
            (g) =>
                g.atStart == atStart &&
                g.neighborId == neighborId &&
                g.supportId == supportId,
          )
          .firstOrNull;
      if (testGap == null) break;
      final err = testGap.distance - distance;
      if (err.abs() < 1e-9) break;
      point = point + direction * err;
    }

    var updated = UpdateArchitectWall(
      storeyId: storeyId,
      fixedWallIds: {neighborId},
      wall: wall.copyWith(
        startPoint: atStart ? point : null,
        endPoint: atStart ? null : point,
      ),
    ).apply(project);
    final support = updated.storeys
        .firstWhere((s) => s.id == storeyId)
        .walls
        .firstWhere((w) => w.id == supportId);
    final d = point - support.startPoint;
    final along = d.dx * support.unitVector.dx + d.dy * support.unitVector.dy;
    final extended = along < 0
        ? support.copyWith(
            startPoint: support.startPoint + support.unitVector * along,
          )
        : along > support.length
        ? support.copyWith(
            endPoint: support.startPoint + support.unitVector * along,
          )
        : null;
    if (extended != null) {
      updated = UpdateArchitectWall(
        storeyId: storeyId,
        wall: extended,
        carryConnections: false,
      ).apply(updated);
    }
    return updated;
  }
}

/// Edit the clear distance from a hosted door or window jamb to the adjacent
/// opening, intersecting wall, or wall endpoint.
class SetArchitectOpeningClearance extends ArchitectModelCommand {
  final String storeyId;
  final String wallId;
  final String openingId;
  final bool isLeft;
  final double distance;

  const SetArchitectOpeningClearance({
    required this.storeyId,
    required this.wallId,
    required this.openingId,
    required this.isLeft,
    required this.distance,
  });

  @override
  ArchitectProject apply(ArchitectProject project) {
    if (!distance.isFinite || distance < 0) {
      throw ArgumentError('Invalid clearance');
    }
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final wall = storey.walls.firstWhere(
      (w) => w.id == wallId,
      orElse: () => throw ArgumentError('Unknown wall: $wallId'),
    );
    final door = wall.doors.where((d) => d.id == openingId).firstOrNull;
    final window = wall.windows.where((w) => w.id == openingId).firstOrNull;
    if (door == null && window == null) {
      throw ArgumentError('Unknown opening: $openingId');
    }
    final width = door?.width ?? window!.width;
    final currentRatio = door?.offsetRatio ?? window!.offsetRatio;
    final span = ArchitectOpeningPlacement.findFreeSpan(
      wall: wall,
      walls: storey.walls,
      targetAlong: currentRatio * wall.length,
      openingWidth: width,
      excludeOpeningId: openingId,
    );
    if (span == null) {
      throw ArgumentError('Opening does not fit in span');
    }
    final newCenterAlong = isLeft
        ? span.leftStation + distance + width / 2.0
        : span.rightStation - distance - width / 2.0;
    if (newCenterAlong - width / 2.0 < span.leftStation - 1e-5 ||
        newCenterAlong + width / 2.0 > span.rightStation + 1e-5) {
      throw ArgumentError('Opening would overlap or leave its span');
    }
    final newRatio = (newCenterAlong / wall.length).clamp(0.0, 1.0);
    if (!BimLineGeometry.hostedFits(
      length: wall.length,
      width: width,
      ratio: newRatio,
    )) {
      throw ArgumentError('Opening would leave its host');
    }
    final nextWall = wall.copyWith(
      doors: [
        for (final d in wall.doors)
          d.id == openingId ? d.copyWith(offsetRatio: newRatio) : d,
      ],
      windows: [
        for (final w in wall.windows)
          w.id == openingId ? w.copyWith(offsetRatio: newRatio) : w,
      ],
    );
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(
        walls: [for (final w in storey.walls) w.id == wall.id ? nextWall : w],
      ),
    );
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

class MirrorArchitectElements extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> elementIds;
  final Offset origin;
  final Offset direction;
  final bool isDuplicate;
  final bool copyGroups;
  final Map<String, String>? idMap;

  const MirrorArchitectElements({
    required this.storeyId,
    required this.elementIds,
    required this.origin,
    required this.direction,
    this.isDuplicate = false,
    this.copyGroups = true,
    this.idMap,
  });

  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(origin);
    ArchitectModelCommand.point(direction);
    if (direction.distanceSquared < 1e-12) {
      throw ArgumentError('Invalid mirror axis');
    }
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final (nextStorey, _) = ArchitectElementTool().mirrorElementsByIds(
      storey,
      elementIds,
      origin: origin,
      direction: direction,
      isDuplicate: isDuplicate,
      copyGroups: copyGroups,
      idMap: idMap,
    );
    var axes = project.gridAxes;
    if (axes.any((a) => elementIds.contains(a.id))) {
      axes = [
        for (final a in project.gridAxes)
          if (elementIds.contains(a.id))
            if (isDuplicate) ...[
              a,
              a.copyWith(
                id: idMap?[a.id] ?? ArchitectElementId.next('axis'),
                start: BimTransform2D.mirror(a.start, origin, direction),
                end: BimTransform2D.mirror(a.end, origin, direction),
              ),
            ] else
              a.copyWith(
                start: BimTransform2D.mirror(a.start, origin, direction),
                end: BimTransform2D.mirror(a.end, origin, direction),
              )
          else
            a,
      ];
    }
    return ArchitectModelCommand.replace(
      project,
      nextStorey,
    ).copyWithGridAxes(axes);
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
  final bool carryConnections;
  const MoveArchitectElement({
    required this.storeyId,
    required this.elementId,
    required this.delta,
    this.carryConnections = true,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(delta);
    final s = ArchitectModelCommand.storey(project, storeyId);
    if (s.zones.any((zone) => zone.id == elementId && zone.isAutoBoundary)) {
      return project;
    }
    final walls = s.walls.where((w) => w.id == elementId);
    if (walls.isNotEmpty) {
      if (!carryConnections) {
        final nextWall = const ArchitectWallEditingAdapter().translate(
          walls.first,
          delta,
        );
        return ArchitectModelCommand.replace(
          project,
          s.copyWith(
            walls: [
              for (final wall in s.walls)
                wall.id == elementId ? nextWall : wall,
            ],
          ),
        );
      }
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
      if (!BimLineGeometry.hostedFits(
        length: host.length,
        width: width,
        ratio: ratio,
      )) {
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

    final next = s.copyWith(
      walls: [
        for (final e in s.walls)
          matches(e.id)
              ? const ArchitectWallEditingAdapter().translate(e, delta)
              : e,
      ],
      columns: [
        for (final e in s.columns)
          matches(e.id)
              ? const ArchitectColumnEditingAdapter().translate(e, delta)
              : e,
      ],
      zones: [
        for (final e in s.zones)
          matches(e.id)
              ? const ArchitectZoneEditingAdapter().translate(e, delta)
              : e,
      ],
      beams: [
        for (final e in s.beams)
          matches(e.id)
              ? const ArchitectBeamEditingAdapter().translate(e, delta)
              : e,
      ],
      slabs: [
        for (final e in s.slabs)
          matches(e.id)
              ? const ArchitectSlabEditingAdapter().translate(e, delta)
              : e,
      ],
      roofs: [
        for (final e in s.roofs)
          matches(e.id)
              ? const ArchitectRoofEditingAdapter().translate(e, delta)
              : e,
      ],
      openings: [
        for (final e in s.openings)
          matches(e.id)
              ? const ArchitectOpeningEditingAdapter().translate(e, delta)
              : e,
      ],
      stairs: [
        for (final e in s.stairs)
          matches(e.id)
              ? const ArchitectStairEditingAdapter().translate(e, delta)
              : e,
      ],
      dimensions: [
        for (final e in s.dimensions)
          matches(e.id)
              ? const ArchitectDimensionEditingAdapter().translate(e, delta)
              : e,
      ],
      annotations: [
        for (final e in s.annotations)
          matches(e.id)
              ? const ArchitectAnnotationEditingAdapter().translate(e, delta)
              : e,
      ],
      elevationMarkers: [
        for (final e in s.elevationMarkers)
          matches(e.id)
              ? const ArchitectElevationEditingAdapter().translate(e, delta)
              : e,
      ],
      cadPrimitives: [
        for (final e in s.cadPrimitives)
          matches(e.id)
              ? const ArchitectCadEditingAdapter().translate(e, delta)
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

/// Move selected elements and stretch attached walls to retain their joints.
class MoveArchitectElements extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> elementIds;
  final Offset delta;

  /// Stretch attached supports beyond their old ends. Explicit false retains
  /// the constrained edit contract for callers that require fixed supports.
  final bool extendSupports;
  const MoveArchitectElements({
    required this.storeyId,
    required this.elementIds,
    required this.delta,
    this.extendSupports = true,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(delta);
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final movedWalls = storey.walls
        .where((w) => elementIds.contains(w.id))
        .toList();
    // Selected walls move; their attached returns and T ends follow the joint.
    final nextWalls = {for (final w in storey.walls) w.id: w};
    for (final wall in movedWalls) {
      var moved = const ArchitectWallEditingAdapter().translate(wall, delta);
      Offset supported(Offset oldPoint, Offset translated, bool connected) {
        if (!connected || wall.isDetached) return translated;
        for (final support in storey.walls) {
          if (elementIds.contains(support.id) ||
              !support.connectsAt(oldPoint)) {
            continue;
          }
          final faces = _wallConnectionFaces(support);
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
                if (!wall.hasInsulation && support.hasInsulation) {
                  return translated;
                }
                if (!extendSupports) {
                  throw ArgumentError('Detach before leaving the support');
                }
                final referencePoint = support.startPoint + u * along;
                final previous = nextWalls[support.id]!;
                final currentAlong = along * support.length;
                final startDelta = previous.startPoint - support.startPoint;
                final endDelta = previous.endPoint - support.startPoint;
                final startAlong =
                    startDelta.dx * support.unitVector.dx +
                    startDelta.dy * support.unitVector.dy;
                final endAlong =
                    endDelta.dx * support.unitVector.dx +
                    endDelta.dy * support.unitVector.dy;
                final extended = previous.copyWith(
                  startPoint: currentAlong < startAlong
                      ? referencePoint
                      : previous.startPoint,
                  endPoint: currentAlong > endAlong
                      ? referencePoint
                      : previous.endPoint,
                );
                nextWalls[support.id] = _wallOpeningsAfterEdit(
                  previous,
                  extended,
                );
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
    if (extendSupports) {
      for (final support in storey.walls) {
        if (elementIds.contains(support.id) || support.isDetached) continue;
        Offset follow(Offset oldPoint, Offset current, bool connected) {
          if (!connected) return current;
          for (final source in movedWalls) {
            if (!source.connectsAt(oldPoint)) continue;
            // Internal walls (without insulation) do not move/stretch connected external walls (with insulation)
            if (!source.hasInsulation && support.hasInsulation) {
              return current;
            }
            final isCollinear =
                (source.unitVector.dx * support.unitVector.dy -
                        source.unitVector.dy * support.unitVector.dx)
                    .abs() <
                1e-4;
            if (isCollinear) {
              return oldPoint;
            }
            final oldFaces = _wallConnectionFaces(source);
            final newFaces = _wallConnectionFaces(nextWalls[source.id]!);
            for (var i = 0; i < oldFaces.length; i++) {
              final face = oldFaces[i];
              final u = face.$2 - face.$1;
              final t = BimLineGeometry.parameter(
                oldPoint,
                face.$1,
                face.$2,
                finite: false,
              );
              if (t < -1e-8 ||
                  t > 1 + 1e-8 ||
                  (oldPoint - (face.$1 + u * t)).distance > 1e-8) {
                continue;
              }
              return BimLineGeometry.intersection(
                    support.startPoint,
                    support.endPoint,
                    newFaces[i].$1,
                    newFaces[i].$2,
                  ) ??
                  oldPoint + delta;
            }
          }
          return current;
        }

        final previous = nextWalls[support.id]!;
        final start = follow(
          support.startPoint,
          previous.startPoint,
          support.connectStart,
        );
        final end = follow(
          support.endPoint,
          previous.endPoint,
          support.connectEnd,
        );
        if ((start - previous.startPoint).distance > 1e-8 ||
            (end - previous.endPoint).distance > 1e-8) {
          nextWalls[support.id] = previous.copyWith(
            startPoint: start,
            endPoint: end,
          );
        }
      }
      for (final source in movedWalls) {
        final movedWall = nextWalls[source.id]!;
        final perpDist =
            (delta.dx * source.normalVector.dx +
                    delta.dy * source.normalVector.dy)
                .abs();
        if (perpDist < 1e-3) continue;

        for (final (atStart, oldPoint, newPoint) in [
          (true, source.startPoint, movedWall.startPoint),
          (false, source.endPoint, movedWall.endPoint),
        ]) {
          final isConnectedAtEnd = atStart
              ? source.connectStart
              : source.connectEnd;
          if (!isConnectedAtEnd) continue;
          if ((newPoint - oldPoint).distance < 1e-3) continue;
          final hasCollinearSupport = storey.walls.any((w) {
            if (elementIds.contains(w.id) || w.isDetached) return false;
            final touchesAtStart = (w.startPoint - oldPoint).distance < 1e-4;
            final touchesAtEnd = (w.endPoint - oldPoint).distance < 1e-4;
            if (!touchesAtStart && !touchesAtEnd) return false;
            final isConnected = touchesAtStart ? w.connectStart : w.connectEnd;
            if (!isConnected) return false;
            return (source.unitVector.dx * w.unitVector.dy -
                        source.unitVector.dy * w.unitVector.dx)
                    .abs() <
                1e-4;
          });
          if (hasCollinearSupport) {
            var count = 1;
            String newId;
            do {
              newId =
                  'wall_step_${DateTime.now().microsecondsSinceEpoch}_$count';
              count++;
            } while (nextWalls.containsKey(newId) ||
                project.storeys.any((s) => s.walls.any((w) => w.id == newId)));

            // Preserve insulation orientation on the connecting step wall:
            // The connecting wall's exterior normal must point away from the moved
            // protrusion (or into the indent) so insulation stays on the building's exterior.
            final collinearDir = atStart
                ? -source.unitVector
                : source.unitVector;
            final dotDeltaE =
                delta.dx * source.exteriorNormal.dx +
                delta.dy * source.exteriorNormal.dy;
            final desiredExteriorNormal =
                collinearDir * (dotDeltaE >= 0 ? 1.0 : -1.0);
            final connectingVec = newPoint - oldPoint;
            final connectingNormal =
                Offset(-connectingVec.dy, connectingVec.dx) /
                connectingVec.distance;
            final connectingExteriorSide =
                (desiredExteriorNormal.dx * connectingNormal.dx +
                        desiredExteriorNormal.dy * connectingNormal.dy) >=
                    0
                ? WallExteriorSide.left
                : WallExteriorSide.right;

            final connectingWall = ArchitectWall(
              id: newId,
              startPoint: oldPoint,
              endPoint: newPoint,
              thickness: source.thickness,
              height: source.height,
              referenceLine: source.referenceLine,
              exteriorSide: connectingExteriorSide,
              insulationThicknessOverride: source.insulationThicknessOverride,
              wallTypeId: source.wallTypeId,
              parapetFinish: source.parapetFinish,
              connectStart: true,
              connectEnd: true,
            );
            nextWalls[newId] = connectingWall;
          }
        }
      }
      // Shared unselected junctions follow once, without translating their
      // complete network or revisiting selected walls.
      final junctions = <(Offset, Offset)>[];
      final visited = <(String, bool)>{};
      for (final wall in storey.walls) {
        if (elementIds.contains(wall.id)) continue;
        final next = nextWalls[wall.id]!;
        for (final (atStart, old, point, connected) in [
          (true, wall.startPoint, next.startPoint, wall.connectStart),
          (false, wall.endPoint, next.endPoint, wall.connectEnd),
        ]) {
          if (connected && (point - old).distance > 1e-8) {
            visited.add((wall.id, atStart));
            junctions.add((old, point));
          }
        }
      }
      for (var cursor = 0; cursor < junctions.length; cursor++) {
        final (old, point) = junctions[cursor];
        for (final wall in storey.walls) {
          if (elementIds.contains(wall.id) || wall.isDetached) continue;
          for (final (atStart, endpoint, connected) in [
            (true, wall.startPoint, wall.connectStart),
            (false, wall.endPoint, wall.connectEnd),
          ]) {
            if (!connected ||
                (endpoint - old).distance > 1e-8 ||
                !visited.add((wall.id, atStart))) {
              continue;
            }
            final previous = nextWalls[wall.id]!;
            nextWalls[wall.id] = atStart
                ? previous.copyWith(startPoint: point)
                : previous.copyWith(endPoint: point);
            junctions.add((endpoint, point));
          }
        }
      }
      for (final wall in storey.walls) {
        if (!elementIds.contains(wall.id)) {
          final next = nextWalls[wall.id]!;
          if (!identical(wall, next)) {
            nextWalls[wall.id] = _wallOpeningsAfterEdit(wall, next);
          }
        }
      }
    }
    var result = ArchitectModelCommand.replace(
      project,
      storey.copyWith(walls: nextWalls.values.toList()),
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

List<(Offset, Offset)> _wallConnectionFaces(ArchitectWall wall) => [
  (wall.startPoint, wall.endPoint),
  (wall.polygonCorners[0], wall.polygonCorners[1]),
  (wall.polygonCorners[3], wall.polygonCorners[2]),
  (wall.coreCorners[0], wall.coreCorners[1]),
  (wall.coreCorners[3], wall.coreCorners[2]),
];

ArchitectWall _wallOpeningsAfterEdit(ArchitectWall old, ArchitectWall next) {
  if (identical(old, next)) return next;
  if (next.length < .001) throw ArgumentError('Wall too short');
  next.validateGeometry();
  final translation = next.startPoint - old.startPoint;
  final translated =
      ((next.endPoint - old.endPoint) - translation).distance < 1e-8;
  if (translated) return next;
  double ratio(double oldRatio, double width) {
    final point=old.referencePointAt(oldRatio);
    final d = point - next.startPoint;
    final along = next.isCurved ? next.arc!.parameter(point)*next.length : d.dx * next.unitVector.dx + d.dy * next.unitVector.dy;
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
    final point = wall.isCurved ? wall.arc!.pointAt(wall.arc!.parameter(target)) : wall.startPoint + wall.unitVector * along;
    final atStart = (point-wall.startPoint).distance<(point-wall.endPoint).distance;
    final next = wall.withExtendedEnds(start:atStart?point:null,end:atStart?null:point);
    final updated = UpdateArchitectWall(
      storeyId: storeyId,
      wall: next,
      carryConnections: false,
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
      final along = wall.isCurved?wall.arc!.parameter(point)*wall.length:d.dx * wall.unitVector.dx + d.dy * wall.unitVector.dy;
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
        if(a.isCurved||b.isCurved) {
          final points=a.intersections(b,finite:false);
          double score(Offset p)=>math.min((p-a.startPoint).distance,(p-a.endPoint).distance)+math.min((p-b.startPoint).distance,(p-b.endPoint).distance);
          points.sort((p,q)=>score(p).compareTo(score(q)));
          if(points.isNotEmpty){compatible=true;extend(a,points.first);extend(b,points.first);}
          continue;
        }

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
      final next = wall.withExtendedEnds(
        start: targets[(wall.id, true)],
        end: targets[(wall.id, false)],
      ).copyWith(
        connectStart: true,
        connectEnd: true,
      );
      result = UpdateArchitectWall(
        storeyId: storeyId,
        wall: next,
        carryConnections: false,
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
class CutArchitectContourOpening extends ArchitectModelCommand {
  final String storeyId, elementId;
  final List<Offset> polygon;
  const CutArchitectContourOpening({required this.storeyId,
    required this.elementId, required this.polygon});

  static (List<Offset>, List<List<Offset>>)? target(ArchitectStorey s, String id) {
    for (final slab in s.slabs) {
      if (slab.id == id) return (slab.polygon, slab.holes);
    }
    for (final roof in s.roofs) {
      if (roof.id == id) return (roof.points, roof.holes);
    }
    for (final p in s.cadPrimitives) {
      if (p.id == id && p.isPolygon) return (p.polygonCorners, p.holes);
    }
    return null;
  }

  @override
  ArchitectProject apply(ArchitectProject project) {
    final s = ArchitectModelCommand.storey(project, storeyId);
    final host = target(s, elementId);
    if (host == null || !ArchitectContour.canAdd(host.$1, host.$2, polygon)) {
      throw ArgumentError('Opening must be strictly inside the host, without overlapping another opening');
    }
    final holes = [...host.$2, List<Offset>.unmodifiable(polygon)];
    return ArchitectModelCommand.replace(project, s.copyWith(
      slabs: [for (final p in s.slabs) p.id == elementId ? p.copyWith(holes: holes) : p],
      roofs: [for (final p in s.roofs) p.id == elementId ? p.copyWith(holes: holes) : p],
      cadPrimitives: [for (final p in s.cadPrimitives) p.id == elementId ? p.copyWith(holes: holes) : p],
    ));
  }
}

class PlaceArchitectCadPrimitive extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectCadPrimitive primitive;
  const PlaceArchitectCadPrimitive({
    required this.storeyId,
    required this.primitive,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    primitive.lineStyle.validate();
    ArchitectModelCommand.point(primitive.startPoint);
    ArchitectModelCommand.point(primitive.endPoint);
    ArchitectModelCommand.newId(project, primitive.id);
    if ((primitive.endPoint - primitive.startPoint).distance < .001 ||
        (primitive.isPolygon &&
            !ArchitectContour.valid(primitive.polygonCorners, primitive.holes))) {
      throw ArgumentError('Invalid CAD shape');
    }
    final floor = ArchitectModelCommand.storey(project, storeyId);
    if (primitive.type == CadPrimitiveType.hatch) {
      primitive.hatchPattern.validate();
      if (!primitive.hatchScale.isFinite || primitive.hatchScale < .1 || primitive.hatchScale > 20 ||
          !primitive.hatchAngle.isFinite || primitive.hatchAngle.abs() > 180) {
        throw ArgumentError('Invalid hatch transform');
      }
      if (!primitive.hatchPattern.isPreset &&
          !project.hatchPatterns.any((p) => p.id == primitive.hatchPattern.id)) {
        project = project.copyWith(hatchPatterns: [...project.hatchPatterns, primitive.hatchPattern]);
      }
    }
    return ArchitectModelCommand.replace(
      primitive.lineStyle.isPreset ||
              project.lineStyles.any((s) => s.id == primitive.lineStyle.id)
          ? project
          : project.copyWith(
              lineStyles: [...project.lineStyles, primitive.lineStyle],
            ),
      floor.copyWith(cadPrimitives: [...floor.cadPrimitives, primitive]),
    );
  }
}

class CreateArchitectRoofPlane extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectRoofPlane roof;
  const CreateArchitectRoofPlane({required this.storeyId, required this.roof});
  @override
  ArchitectProject apply(ArchitectProject project) {
    roof.drainage.validate();
    if (!ArchitectContour.valid(roof.points, roof.holes)) {
      throw ArgumentError('Invalid roof contour');
    }
    ArchitectModelCommand.newId(project, roof.id);
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(roofs: [...floor.roofs, roof]),
    );
  }
}

class UpdateArchitectRoofPlane extends ArchitectModelCommand {
  final String storeyId;
  final ArchitectRoofPlane roof;
  const UpdateArchitectRoofPlane({required this.storeyId, required this.roof});
  @override
  ArchitectProject apply(ArchitectProject project) {
    roof.drainage.validate();
    if (!ArchitectContour.valid(roof.points, roof.holes)) {
      throw ArgumentError('Invalid roof contour');
    }
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        roofs: [for (final r in floor.roofs) r.id == roof.id ? roof : r],
      ),
    );
  }
}

class ReplaceStoreyRoofs extends ArchitectModelCommand {
  final String storeyId;
  final List<ArchitectRoofPlane> roofs;
  const ReplaceStoreyRoofs({required this.storeyId, required this.roofs});
  @override
  ArchitectProject apply(ArchitectProject project) {
    for (final roof in roofs) {
      roof.drainage.validate();
    }
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(project, floor.copyWith(roofs: roofs));
  }
}

class DeleteArchitectRoofPlane extends ArchitectModelCommand {
  final String storeyId;
  final String roofId;
  const DeleteArchitectRoofPlane({
    required this.storeyId,
    required this.roofId,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(roofs: floor.roofs.where((r) => r.id != roofId).toList()),
    );
  }
}

class UpdateArchitectPolygon extends ArchitectModelCommand {
  final String storeyId, elementId;
  final List<Offset> polygon;
  const UpdateArchitectPolygon({
    required this.storeyId,
    required this.elementId,
    required this.polygon,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    if (!ArchitectPolygonGeometry.valid(polygon)) {
      throw ArgumentError('Invalid contour');
    }
    final floor = ArchitectModelCommand.storey(project, storeyId);
    if (floor.zones.any((z) => z.id == elementId && z.isAutoBoundary)) {
      throw ArgumentError('Automatic zone boundaries are controlled by walls');
    }
    final slab = floor.slabs.any((s) => s.id == elementId);
    final roof = floor.roofs.any((r) => r.id == elementId);
    final rect = floor.cadPrimitives.any(
      (s) => s.id == elementId && s.isPolygon,
    );
    final zone = floor.zones.any((z) => z.id == elementId);
    final opening = floor.openings.any((o) => o.id == elementId);
    if (!slab && !roof && !rect && !zone && !opening) {
      throw ArgumentError('Unknown polygon element');
    }
    final host = CutArchitectContourOpening.target(floor, elementId);
    if (host != null && !ArchitectContour.valid(polygon, host.$2)) {
      throw ArgumentError('Contour would cross an opening');
    }
    final points = List<Offset>.unmodifiable(polygon);
    final bounds = ArchitectSceneGeometry.boundsOf(points);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        slabs: [
          for (final s in floor.slabs)
            s.id == elementId ? s.copyWith(polygon: points) : s,
        ],
        roofs: [
          for (final r in floor.roofs)
            r.id == elementId
                ? r.copyWith(
                    points: points,
                    eavesEdgeIndex: r.eavesEdgeIndex.clamp(
                      0,
                      points.length - 1,
                    ),
                  )
                : r,
        ],
        cadPrimitives: [
          for (final p in floor.cadPrimitives)
            p.id == elementId
                ? p.copyWith(
                    polygon: points,
                    startPoint: bounds.topLeft,
                    endPoint: bounds.bottomRight,
                  )
                : p,
        ],
        zones: [
          for (final z in floor.zones)
            z.id == elementId ? z.copyWith(polygon: points) : z,
        ],
        openings: [
          for (final o in floor.openings)
            o.id == elementId ? o.copyWith(boundary: points) : o,
        ],
      ),
    );
  }
}

/// A vertex on a contour, or a connected segmentation point on a native line.
/// Cutting walls is a separate command with detachCut=true.
class InsertArchitectElementPoint extends ArchitectModelCommand {
  const InsertArchitectElementPoint({
    required this.storeyId,
    required this.elementId,
    required this.point,
    required this.newElementId,
    this.atMidpoint = false,
  });
  final String storeyId, elementId, newElementId;
  final Offset point;
  final bool atMidpoint;

  static ({List<Offset> points, bool closed, double width})? pathOf(
    ArchitectStorey storey,
    String id,
  ) {
    for (final w in storey.walls) {
      if (w.id == id) {
        return (
          points: [w.startPoint, w.endPoint],
          closed: false,
          width: w.thickness,
        );
      }
    }
    for (final b in storey.beams) {
      if (b.id == id) {
        return (
          points: [b.startPoint, b.endPoint],
          closed: false,
          width: b.width,
        );
      }
    }
    for (final p in storey.cadPrimitives) {
      if (p.id != id || p.type == CadPrimitiveType.circle) continue;
      return (
        points: p.isPolygon
            ? p.polygonCorners
            : [p.startPoint, p.endPoint],
        closed: p.isPolygon,
        width: 0,
      );
    }
    for (final s in storey.slabs) {
      if (s.id == id) return (points: s.polygon, closed: true, width: 0);
    }
    for (final r in storey.roofs) {
      if (r.id == id) return (points: r.points, closed: true, width: 0);
    }
    for (final z in storey.zones) {
      if (z.id == id && !z.isAutoBoundary) return (points: z.polygon, closed: true, width: 0);
    }
    for (final o in storey.openings) {
      if (o.id == id) return (points: o.boundary, closed: true, width: 0);
    }
    for (final d in storey.dimensions) {
      if (d.id == id) {
        return (points: [d.lineStart, d.lineEnd], closed: false, width: 0);
      }
    }
    return null;
  }

  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectModelCommand.point(point);
    final storey = ArchitectModelCommand.storey(project, storeyId);
    final path = pathOf(storey, elementId);
    if (path == null) throw ArgumentError('Element has no editable path');
    // The pick identifies the segment; midpoint insertion ignores its distance
    // along that segment and works equally for open paths and closing edges.
    final hit = BimLineGeometry.insertion(
      path.points,
      point,
      closed: path.closed,
    );
    if (hit == null) throw ArgumentError('Element has no editable segment');
    final insertion = atMidpoint
        ? (path.points[hit.edge] +
                  path.points[(hit.edge + 1) % path.points.length]) /
              2
        : hit.point;
    if (path.points.any((p) => (p - insertion).distance < .001)) {
      throw ArgumentError('Point already exists or segment is too short');
    }
    if (path.closed) {
      final points = List<Offset>.of(path.points)
        ..insert(hit.edge + 1, insertion);
      return UpdateArchitectPolygon(
        storeyId: storeyId,
        elementId: elementId,
        polygon: points,
      ).apply(project);
    }
    if (storey.dimensions.any((d) => d.id == elementId)) {
      final dim = storey.dimensions.firstWhere((d) => d.id == elementId);
      final next = ArchitectDimensionChain.addAnchors(dim, [
        ArchitectDimensionAnchor(point: insertion),
      ]);
      return ArchitectModelCommand.replace(
        project,
        storey.copyWith(
          dimensions: [
            for (final d in storey.dimensions)
              if (d.id == elementId) next else d,
          ],
        ),
      );
    }
    ArchitectModelCommand.newId(project, newElementId);
    if (storey.walls.any((w) => w.id == elementId)) {
      final wall = storey.walls.firstWhere((w) => w.id == elementId);
      return SplitArchitectWall(
        storeyId: storeyId,
        wallId: elementId,
        newWallId: newElementId,
        ratio: BimLineGeometry.parameter(
          insertion,
          wall.startPoint,
          wall.endPoint,
        ),
      ).apply(project);
    }
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(
        groups: [for (final g in storey.groups) g.elementIds.contains(elementId)
          ? ArchitectElementGroup(id: g.id, elementIds: {...g.elementIds, newElementId}) : g],
        beams: [
          for (final b in storey.beams)
            if (b.id == elementId) ...[
              b.copyWith(endPoint: insertion),
              b.copyWith(id: newElementId, startPoint: insertion),
            ] else
              b,
        ],
        cadPrimitives: [
          for (final p in storey.cadPrimitives)
            if (p.id == elementId) ...[
              p.copyWith(endPoint: insertion),
              p.copyWith(id: newElementId, startPoint: insertion),
            ] else
              p,
        ],
      ),
    );
  }
}

class ArchitectCommandController
    extends BimTransactionController<ArchitectProject> {
  static const historyLimit = 100;
  ArchitectCommandController(ArchitectProject project)
    : super(
        ArchitectRoofPlacement.resolve(
          ArchitectSlabAssemblies.resolve(ArchitectStairRules.resolve(project)),
        ),
        historyLimit: historyLimit,
        equivalent: _sameModel,
        restoreView: _retainViewedStorey,
      );
  ArchitectProject get project => value;

  @override
  void restore(ArchitectProject next) => super.restore(
    ArchitectRoofPlacement.resolve(ArchitectSlabAssemblies.resolve(next)),
  );

  @override
  void commit(ArchitectProject next) => super.commit(
    ArchitectRoofPlacement.resolve(
      ArchitectSlabAssemblies.resolve(
        ArchitectDimensionChain.resolve(ArchitectStairRules.resolve(next)),
      ),
      previous: project,
    ),
  );

  static bool _sameModel(ArchitectProject a, ArchitectProject b) {
    if (identical(a, b)) return true;
    final left = a.toJson()
      ..remove('updatedAt')
      ..remove('activeStoreyId');
    final right = b.toJson()
      ..remove('updatedAt')
      ..remove('activeStoreyId');
    return bimValuesEqual(left, right);
  }

  ArchitectProject execute(ArchitectModelCommand command) =>
      executeBatch([command]);
  ArchitectProject executeBatch(Iterable<ArchitectModelCommand> commands) =>
      applyBatch(commands.map((command) => command.apply));

  /// Viewing another floor does not consume an Undo step or discard Redo.
  void activateStorey(String id) {
    ArchitectModelCommand.storey(project, id);
    if (id != project.activeStoreyId) {
      replaceView(project.copyWith(activeStoreyId: id));
    }
  }

  /// Display units change formatting, never geometry or its Undo history.
  void setUnits(ArchitectUnit units) {
    if (project.units != units) replaceView(project.copyWith(units: units));
  }

  void setDistanceDecimals(int decimals) {
    final value = decimals.clamp(0, 2);
    if (project.distanceDecimals != value) {
      replaceView(project.copyWith(distanceDecimals: value));
    }
  }

  /// Annotation scale is a display setting, independent of geometry history.
  void setDimensionScale(ArchitectDimensionScale scale) {
    if (project.dimensionScale != scale) {
      replaceView(project.copyWith(dimensionScale: scale));
    }
  }

  static ArchitectProject _retainViewedStorey(
    ArchitectProject snapshot,
    ArchitectProject current,
  ) {
    final id = current.activeStoreyId;
    final viewed = snapshot.storeys.any((s) => s.id == id)
        ? id
        : snapshot.activeStoreyId;
    if (viewed == snapshot.activeStoreyId &&
        current.units == snapshot.units &&
        current.distanceDecimals == snapshot.distanceDecimals &&
        current.dimensionScale == snapshot.dimensionScale &&
        bimValuesEqual(current.document.viewScales, snapshot.document.viewScales)) {
      return snapshot;
    }
    return snapshot.copyWith(
      activeStoreyId: viewed,
      units: current.units,
      distanceDecimals: current.distanceDecimals,
      dimensionScale: current.dimensionScale,
      document: snapshot.document.copyWith(viewScales: current.document.viewScales),
    );
  }
}
