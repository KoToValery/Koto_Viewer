import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/dwg_converter_service.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/bim_work_project.dart';

/// Service responsible for managing, persisting, and querying standalone
/// BiM Work Projects stored on the local file system.
class BimProjectLibraryService {
  final Directory? _customRootDir;

  BimProjectLibraryService({Directory? customRootDir})
      : _customRootDir = customRootDir;

  /// Default singleton instance
  static final BimProjectLibraryService instance = BimProjectLibraryService();

  Future<Directory> getProjectsDirectory() async {
    if (_customRootDir != null) {
      final dir = Directory('${_customRootDir.path}/KotoBim/projects');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/KotoBim/projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getProjectDirectory(String projectId) async {
    final baseDir = await getProjectsDirectory();
    final projDir = Directory('${baseDir.path}/$projectId');
    if (!await projDir.exists()) {
      await projDir.create(recursive: true);
    }
    return projDir;
  }

  /// Lists all BiM projects found in the storage directory, sorted by `updatedAt` descending.
  Future<List<BimWorkProject>> listProjects() async {
    try {
      final baseDir = await getProjectsDirectory();
      final entities = await baseDir.list().toList();
      final projects = <BimWorkProject>[];

      for (final entity in entities) {
        if (entity is Directory) {
          final manifestFile = File('${entity.path}/project.json');
          if (await manifestFile.exists()) {
            try {
              final content = await manifestFile.readAsString();
              final jsonMap = jsonDecode(content) as Map<String, dynamic>;
              projects.add(BimWorkProject.fromJson(jsonMap));
            } catch (e) {
              debugPrint('Error reading project in ${entity.path}: $e');
            }
          }
        }
      }

      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (e) {
      debugPrint('Error listing BiM projects: $e');
      return [];
    }
  }

  /// Creates a new BiM project on disk with an initial manifest and empty structural model.
  Future<BimWorkProject> createProject({
    required String name,
    String location = '',
    required List<BimStoreyUnderlay> storeys,
  }) async {
    final now = DateTime.now();
    final randSuffix = math.Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
    final id = 'bim_${now.millisecondsSinceEpoch}_$randSuffix';

    final project = BimWorkProject(
      id: id,
      name: name.trim().isNotEmpty ? name.trim() : 'BiM Project',
      location: location.trim(),
      createdAt: now,
      updatedAt: now,
      storeys: storeys,
      alignmentConfirmed: false,
    );

    await getProjectDirectory(id);
    await saveProjectManifest(project);

    // Initialize corresponding structural project
    final initialStructuralStoreys = storeys.map((s) {
      return StoreyLevel(
        id: s.storeyId,
        name: s.name,
        elevation: s.elevation,
        height: s.height,
      );
    }).toList();

    final initialStructural = StructuralProject(
      title: project.name,
      storeys: initialStructuralStoreys.isNotEmpty
          ? initialStructuralStoreys
          : const [
              StoreyLevel(
                id: 'storey_1',
                name: 'Етаж 1 (Кота ±0.00)',
                elevation: 0.0,
                height: 2.80,
              ),
            ],
      activeStoreyIndex: 0,
    );

    await saveStructuralProject(id, initialStructural);
    return project;
  }

  /// Loads the project manifest for [projectId].
  Future<BimWorkProject?> loadProject(String projectId) async {
    try {
      final projDir = await getProjectDirectory(projectId);
      final manifestFile = File('${projDir.path}/project.json');
      if (!await manifestFile.exists()) return null;

      final content = await manifestFile.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return BimWorkProject.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Error loading project $projectId: $e');
      return null;
    }
  }

  /// Alias for [loadProject].
  Future<BimWorkProject?> getProject(String projectId) => loadProject(projectId);

  /// Atomically saves the project manifest.
  Future<bool> saveProjectManifest(BimWorkProject project) async {
    try {
      final projDir = await getProjectDirectory(project.id);
      final manifestFile = File('${projDir.path}/project.json');
      final tmpFile = File('${projDir.path}/project.json.tmp');

      final content = const JsonEncoder.withIndent('  ').convert(project.toJson());
      await tmpFile.writeAsString(content, flush: true);
      if (await manifestFile.exists()) {
        await manifestFile.delete();
      }
      await tmpFile.rename(manifestFile.path);
      return true;
    } catch (e) {
      debugPrint('Error saving project manifest ${project.id}: $e');
      return false;
    }
  }

  /// Loads the structural project model for [projectId].
  Future<StructuralProject?> loadStructuralProject(String projectId) async {
    try {
      final projDir = await getProjectDirectory(projectId);
      final structFile = File('${projDir.path}/structural.json');
      if (!await structFile.exists()) return null;

      final content = await structFile.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return StructuralProject.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Error loading structural project for $projectId: $e');
      return null;
    }
  }

  /// Atomically saves the structural model for [projectId].
  Future<bool> saveStructuralProject(
    String projectId,
    StructuralProject structural,
  ) async {
    try {
      final projDir = await getProjectDirectory(projectId);
      final structFile = File('${projDir.path}/structural.json');
      final tmpFile = File('${projDir.path}/structural.json.tmp');

      final content = const JsonEncoder.withIndent('  ').convert(structural.toJson());
      await tmpFile.writeAsString(content, flush: true);
      if (await structFile.exists()) {
        await structFile.delete();
      }
      await tmpFile.rename(structFile.path);

      // Update project updatedAt timestamp
      final manifest = await loadProject(projectId);
      if (manifest != null) {
        await saveProjectManifest(manifest.copyWith(updatedAt: DateTime.now()));
      }
      return true;
    } catch (e) {
      debugPrint('Error saving structural project for $projectId: $e');
      return false;
    }
  }

  /// Attaches or replaces an underlay file for a specific storey.
  /// Converts DWG to DXF if necessary and copies the resulting DXF file into
  /// `<projectDir>/underlays/<storeyId>.dxf`.
  Future<BimStoreyUnderlay> attachUnderlayFile(
    String projectId,
    String storeyId,
    File sourceFile,
  ) async {
    final projDir = await getProjectDirectory(projectId);
    final underlaysDir = Directory('${projDir.path}/underlays');
    if (!await underlaysDir.exists()) {
      await underlaysDir.create(recursive: true);
    }

    String effectiveDxfPath;
    final lowerPath = sourceFile.path.toLowerCase();
    if (lowerPath.endsWith('.dwg')) {
      effectiveDxfPath = await DwgConverterService.convertDwgToDxf(sourceFile.path);
    } else {
      effectiveDxfPath = sourceFile.path;
    }

    final targetUnderlayFile = File('${underlaysDir.path}/$storeyId.dxf');
    await File(effectiveDxfPath).copy(targetUnderlayFile.path);

    final manifest = await loadProject(projectId);
    if (manifest != null) {
      final updatedStoreys = manifest.storeys.map((s) {
        if (s.storeyId == storeyId) {
          return s.copyWith(
            sourceFileName: sourceFile.path.split(Platform.pathSeparator).last,
            underlayFileName: 'underlays/$storeyId.dxf',
            clearControlPoint: true, // Reset control point on new drawing
            wallsDetected: false,
          );
        }
        return s;
      }).toList();

      final updatedProject = manifest.copyWith(
        storeys: updatedStoreys,
        alignmentConfirmed: false,
        updatedAt: DateTime.now(),
      );
      await saveProjectManifest(updatedProject);
      return updatedStoreys.firstWhere((s) => s.storeyId == storeyId);
    }

    return BimStoreyUnderlay(
      storeyId: storeyId,
      name: storeyId,
      elevation: 0.0,
      sourceFileName: sourceFile.path.split(Platform.pathSeparator).last,
      underlayFileName: 'underlays/$storeyId.dxf',
    );
  }

  /// Returns the absolute [File] for a relative underlay path within [projectId].
  Future<File?> getUnderlayFile(String projectId, String underlayRelativePath) async {
    final projDir = await getProjectDirectory(projectId);
    final file = File('${projDir.path}/$underlayRelativePath');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Deletes the entire project directory.
  Future<bool> deleteProject(String projectId) async {
    try {
      final projDir = await getProjectDirectory(projectId);
      if (await projDir.exists()) {
        await projDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting project $projectId: $e');
      return false;
    }
  }

  /// Renames a project in its manifest.
  Future<bool> renameProject(String projectId, String newName) async {
    try {
      final manifest = await loadProject(projectId);
      if (manifest == null) return false;
      final updated = manifest.copyWith(
        name: newName.trim(),
        updatedAt: DateTime.now(),
      );
      return await saveProjectManifest(updated);
    } catch (e) {
      debugPrint('Error renaming project $projectId: $e');
      return false;
    }
  }
}
