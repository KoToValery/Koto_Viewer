import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import 'architect_command_controller.dart';

/// Reuses the wall tool's segment geometry without creating BIM walls.
/// Descriptors exist only during an edit; only CAD endpoints are written back.
class ArchitectLineEditing {
  static ArchitectWall segment(ArchitectCadPrimitive line) => ArchitectWall(
    id: line.id,
    startPoint: line.startPoint,
    endPoint: line.endPoint,
    thickness: .001,
    wallTypeId: line.id,
  );

  static ArchitectProject geometry(ArchitectProject project, String storeyId) {
    final floor = ArchitectModelCommand.storey(project, storeyId);
    return ArchitectModelCommand.replace(
      project,
      floor.copyWith(
        walls: [
          ...floor.walls,
          ...floor.cadPrimitives
              .where((p) => p.type == CadPrimitiveType.line)
              .map(segment),
        ],
        cadPrimitives: floor.cadPrimitives
            .where((p) => p.type != CadPrimitiveType.line)
            .toList(),
      ),
    );
  }

  static ArchitectModelCommand adapt(
    ArchitectProject project,
    ArchitectModelCommand command,
  ) {
    final (String, Set<String>)? target = switch (command) {
      UpdateArchitectWall c => (c.storeyId, {c.wall.id}),
      ExtendArchitectWall c => (c.storeyId, {c.wallId}),
      TrimArchitectWall c => (c.storeyId, {c.wallId}),
      CutArchitectWalls c => (c.storeyId, c.wallIds),
      JoinArchitectWalls c => (c.storeyId, c.wallIds),
      _ => null,
    };
    if (target == null) return command;
    final floor = ArchitectModelCommand.storey(project, target.$1);
    final lines = floor.cadPrimitives
        .where((p) => p.type == CadPrimitiveType.line)
        .map((p) => p.id)
        .toSet();
    if (!target.$2.any(lines.contains)) return command;
    if (!target.$2.every(lines.contains)) {
      throw ArgumentError('Select only lines for this operation');
    }
    return _EditLines(target.$1, command);
  }
}

class _EditLines extends ArchitectModelCommand {
  const _EditLines(this.storeyId, this.command);
  final String storeyId;
  final ArchitectModelCommand command;

  @override
  ArchitectProject apply(ArchitectProject project) {
    final original = ArchitectModelCommand.storey(project, storeyId);
    final sources = {
      for (final p in original.cadPrimitives)
        if (p.type == CadPrimitiveType.line) p.id: p,
    };
    final before = ArchitectLineEditing.geometry(project, storeyId);
    final after = ArchitectModelCommand.storey(command.apply(before), storeyId);
    final wallIds = original.walls.map((w) => w.id).toSet();
    final result = <String, List<ArchitectCadPrimitive>>{};
    for (final wall in after.walls) {
      if (wallIds.contains(wall.id)) continue;
      final source = sources[wall.wallTypeId];
      if (source == null) throw ArgumentError('Missing source line');
      (result[source.id] ??= []).add(
        wall.id == source.id &&
                wall.startPoint == source.startPoint &&
                wall.endPoint == source.endPoint
            ? source
            : source.copyWith(
                id: wall.id,
                startPoint: wall.startPoint,
                endPoint: wall.endPoint,
              ),
      );
    }
    return ArchitectModelCommand.replace(
      project,
      original.copyWith(
        groups: after.groups,
        cadPrimitives: [
          for (final p in original.cadPrimitives)
            if (p.type == CadPrimitiveType.line) ...?result[p.id] else p,
        ],
      ),
    );
  }
}
