import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../architect/models/architect_project.dart';
import '../../architect/services/architect_underlay_service.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';

/// Creates a BiM architectural project from [archProject] and imports any
/// CAD underlays attached to its storeys.
Future<(BimWorkProject, ArchitectProject)> createArchitectWorkProject({
  required BimProjectLibraryService library,
  required ArchitectProject archProject,
  String location = '',
}) async {
  final storeys = archProject.storeys.map((s) {
    final underlayConfig = archProject.cadUnderlays[s.id];
    return BimStoreyUnderlay(
      storeyId: s.id,
      name: s.name,
      elevation: s.elevation,
      height: s.height,
      sourceFileName: underlayConfig?.fileName,
    );
  }).toList();

  final bimProject = await library.createProject(
    name: archProject.name,
    location: location,
    storeys: storeys,
    projectType: BimProjectType.architectural,
    initialArchitectProject: archProject,
  );

  final configs = <String, ArchitectCadUnderlayConfig>{};
  for (final entry in archProject.cadUnderlays.entries) {
    final file = entry.value.externalSourcePath != null
        ? File(entry.value.externalSourcePath!)
        : null;
    if (file != null && await file.exists()) {
      try {
        final res = await ArchitectUnderlayService.instance
            .importOrReloadCadUnderlay(
              projectId: bimProject.id,
              storeyId: entry.key,
              sourceFile: file,
              existingConfig: null,
            );
        configs[entry.key] = res.config;
        await library.attachUnderlayFile(bimProject.id, entry.key, file);
      } catch (e) {
        debugPrint('[createArchitectWorkProject] import underlay error: $e');
      }
    }
  }

  var updatedArchProject = archProject.copyWith(id: bimProject.id);
  if (configs.isNotEmpty) {
    updatedArchProject = updatedArchProject.copyWith(cadUnderlays: configs);
    await library.saveArchitectProject(bimProject.id, updatedArchProject);
  }
  return (bimProject, updatedArchProject);
}
