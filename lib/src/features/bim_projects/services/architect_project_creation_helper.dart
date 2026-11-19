import '../../architect/models/architect_project.dart';
import '../../architect/services/architect_underlay_service.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';

/// Publishes the reviewed originals with the architectural project. BIM can
/// derive its structural working files from these sources when opened there.
Future<(BimWorkProject, ArchitectProject)> createArchitectWorkProject({
  required BimProjectLibraryService library,
  required ArchitectProject archProject,
  required Map<String, ArchitectCadImportSelection> underlays,
  String location = '',
}) async {
  final service = ArchitectUnderlayService(libraryService: library);
  var published = archProject;
  final project = await library.createProject(
    name: archProject.name,
    location: location,
    storeys: [
      for (final storey in archProject.storeys)
        BimStoreyUnderlay(
          storeyId: storey.id,
          name: storey.name,
          elevation: storey.elevation,
          height: storey.height,
        ),
    ],
    projectType: BimProjectType.architectural,
    initialArchitectProject: archProject,
    prepareArchitecturalUnderlays: (id) async {
      final configs = await service.commitCadUnderlays(id, underlays);
      published = archProject.copyWith(id: id, cadUnderlays: configs);
      return configs;
    },
  );
  return (project, published);
}
