import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import 'architect_command_controller.dart';

class SetArchitectWallPlinth extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> wallIds;
  final ArchitectWallPlinthPatch patch;
  const SetArchitectWallPlinth({
    required this.storeyId,
    required this.wallIds,
    required this.patch,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    final storey = ArchitectModelCommand.storey(project, storeyId),
        found = <String>{};
    final walls = [
      for (final wall in storey.walls)
        if (wallIds.contains(wall.id))
          () {
            if (!wall.isExterior)
              throw ArgumentError('Plinth requires an exterior wall');
            found.add(wall.id);
            return wall.copyWith(plinth: patch.apply(wall.plinth));
          }()
        else
          wall,
    ];
    if (found.length != wallIds.length) throw ArgumentError('Unknown wall');
    return ArchitectModelCommand.replace(
      project,
      storey.copyWith(walls: walls),
    );
  }
}

class SetArchitectWallComposition extends ArchitectModelCommand {
  final ArchitectWallType type;
  final String? replaceTypeId;
  final String? storeyId;
  final Set<String> wallIds;
  final ArchitectWallPlinth? plinth;
  final ArchitectWallPlinthPatch? plinthPatch;
  final bool preserveComposition;
  const SetArchitectWallComposition({
    required this.type,
    this.replaceTypeId,
    this.storeyId,
    this.wallIds = const {},
    this.plinth,
    this.plinthPatch,
    this.preserveComposition = false,
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    ArchitectMaterialLayer.validate(type.resolvedLayers);
    plinth?.validate();
    if (type.id.isEmpty) throw ArgumentError('Empty wall type ID');
    final found = <String>{};
    final storeys = [
      for (final s in project.storeys)
        s.copyWith(
          walls: [
            for (final wall in s.walls)
              if (replaceTypeId != null
                  ? wall.wallTypeId == replaceTypeId
                  : (s.id == storeyId && wallIds.contains(wall.id)))
                () {
                  found.add(wall.id);
                  final composed = preserveComposition
                      ? wall
                      : wall.copyWith(
                          layers: List.unmodifiable(type.resolvedLayers),
                          thickness: type.totalThickness,
                          insulationThicknessOverride: type.insulationThickness,
                          wallTypeId: type.id,
                          location: type.resolvedLocation,
                          loadBearing: type.isLoadBearing,
                        );
                  composed.validateGeometry();
                  final region =
                      plinthPatch?.apply(wall.plinth) ?? plinth ?? wall.plinth;
                  return composed.copyWith(
                    plinth: composed.isExterior
                        ? region
                        : region.copyWith(enabled: false),
                  );
                }()
              else
                wall,
          ],
        ),
    ];
    if (replaceTypeId == null && found.length != wallIds.length) {
      throw ArgumentError('Unknown walls');
    }
    return project.copyWith(
      storeys: storeys,
      wallTypes: preserveComposition
          ? project.wallTypes
          : [
              for (final t in project.wallTypes)
                if (t.id != type.id &&
                    t.id != replaceTypeId &&
                    !(t.id.startsWith('wall_type_') &&
                        t.name.isEmpty &&
                        !storeys.any(
                          (s) => s.walls.any((w) => w.wallTypeId == t.id),
                        )))
                  t,
              type,
            ],
    );
  }
}

class DeleteArchitectWallType extends ArchitectModelCommand {
  final String typeId, replacementId;
  const DeleteArchitectWallType(this.typeId, {this.replacementId = ''});
  @override
  ArchitectProject apply(ArchitectProject project) {
    final used = project.storeys.any(
      (s) => s.walls.any((w) => w.wallTypeId == typeId),
    );
    var next = project;
    if (used) {
      final replacement = project.wallTypes
          .where((t) => t.id == replacementId && t.id != typeId)
          .firstOrNull;
      if (replacement == null) throw ArgumentError('Replacement required');
      next = SetArchitectWallComposition(
        type: replacement,
        replaceTypeId: typeId,
      ).apply(project);
    }
    return next.copyWith(
      wallTypes: next.wallTypes.where((t) => t.id != typeId).toList(),
    );
  }
}
