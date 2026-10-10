import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/binary/kcad_service.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import 'bim_underlay_conversion_service.dart';
import 'bim_underlay_loader.dart';
import 'bim_structural_seed_sync.dart';
import '../../structural_designer/models/structural_element.dart';
import '../models/bim_work_project.dart';

class _BimWriteQueue {
  Future<void> _tail = Future<void>.value();
  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// Service responsible for managing, persisting, and querying standalone
/// BiM Work Projects stored on the local file system.
class BimProjectLibraryService {
  static final _writes = _BimWriteQueue();
  static final _publications = _BimWriteQueue();
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
    storeys = [...storeys]..sort((a, b) => a.elevation.compareTo(b.elevation));
    final now = DateTime.now();
    final randSuffix = math.Random()
        .nextInt(0xffffff)
        .toRadixString(16)
        .padLeft(6, '0');
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
    if (!await saveProjectManifest(project)) {
      throw FileSystemException('Cannot create project');
    }

    // Initialize corresponding structural project
    final initialStructuralStoreys = storeys.map((s) {
      return StoreyLevel(
        id: s.storeyId,
        name: s.elevationLabel,
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
                name: '±0.00',
                elevation: 0.0,
                height: 2.80,
              ),
            ],
      activeStoreyIndex: 0,
    );

    if (!await saveStructuralProject(id, initialStructural)) {
      throw FileSystemException('Cannot initialize structural model');
    }
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
      final project = BimWorkProject.fromJson(jsonMap);
      return project.copyWith(storeys: project.sortedStoreysByElevation);
    } catch (e) {
      debugPrint('Error loading project $projectId: $e');
      return null;
    }
  }

  /// Alias for [loadProject].
  Future<BimWorkProject?> getProject(String projectId) =>
      loadProject(projectId);

  /// Atomically saves the project manifest.
  Future<bool> saveProjectManifest(BimWorkProject project) =>
      _writes.run(() => _saveProjectManifestNow(project));

  Future<bool> _saveProjectManifestNow(BimWorkProject project) async {
    try {
      final projDir = await getProjectDirectory(project.id);
      final manifestFile = File('${projDir.path}/project.json');
      final tmpFile = File(
        '${projDir.path}/project.json.tmp_${DateTime.now().microsecondsSinceEpoch}',
      );

      final content = const JsonEncoder.withIndent(
        '  ',
      ).convert(project.toJson());
      await tmpFile.writeAsString(content, flush: true);
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
      final structural = StructuralProject.fromJson(jsonMap);
      final manifest = await loadProject(projectId);
      if (manifest == null || manifest.storeys.isEmpty) return structural;
      // Manifest is authoritative for elevations/order, so an interrupted edit
      // cannot leave two different sets of storeys. Geometry stays keyed by ID.
      final existing = {for (final s in structural.storeys) s.id: s};
      final activeId = structural.storeys.isEmpty
          ? null
          : structural.activeStorey.id;
      final synced = manifest.storeys
          .map(
            (s) =>
                (existing[s.storeyId] ??
                        StoreyLevel(
                          id: s.storeyId,
                          name: s.elevationLabel,
                          elevation: s.elevation,
                          height: s.height,
                        ))
                    .copyWith(
                      name: s.elevationLabel,
                      elevation: s.elevation,
                      height: s.height,
                    ),
          )
          .toList();
      final active = synced.indexWhere((s) => s.id == activeId);
      final axes = structural.effectiveGridAxes
          .where(
            (a) =>
                !a.id.startsWith('bim_axis_') ||
                manifest.storeys.any(
                  (s) => a.id.startsWith('bim_axis_${s.storeyId}_'),
                ),
          )
          .toList();
      return structural
          .copyWith(storeys: synced, activeStoreyIndex: active < 0 ? 0 : active)
          .copyWithGridAxes(axes);
    } catch (e) {
      debugPrint('Error loading structural project for $projectId: $e');
      return null;
    }
  }

  /// Atomically saves the structural model for [projectId].
  Future<bool> saveStructuralProject(
    String projectId,
    StructuralProject structural,
  ) => _writes.run(() => _saveStructuralProjectNow(projectId, structural));

  Future<bool> _saveStructuralProjectNow(
    String projectId,
    StructuralProject structural,
  ) async {
    try {
      final projDir = await getProjectDirectory(projectId);
      final structFile = File('${projDir.path}/structural.json');
      final tmpFile = File(
        '${projDir.path}/structural.json.tmp_${DateTime.now().microsecondsSinceEpoch}',
      );

      final content = const JsonEncoder.withIndent(
        '  ',
      ).convert(structural.toJson());
      await tmpFile.writeAsString(content, flush: true);
      await tmpFile.rename(structFile.path);

      // Update project updatedAt timestamp
      final manifest = await loadProject(projectId);
      if (manifest != null) {
        await _saveProjectManifestNow(
          manifest.copyWith(updatedAt: DateTime.now()),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error saving structural project for $projectId: $e');
      return false;
    }
  }

  /// Publishes a validated, immutable revision. The old revision remains valid
  /// until the manifest rename commits the new paths.
  Future<BimStoreyUnderlay> attachUnderlayFile(
    String projectId,
    String storeyId,
    File sourceFile, {
    BimConversionResult? prepared,
    bool preserveAlignment = false,
  }) => _publications.run(
    () => _attachUnderlayFile(
      projectId,
      storeyId,
      sourceFile,
      prepared: prepared,
      preserveAlignment: preserveAlignment,
    ),
  );

  Future<BimStoreyUnderlay> _attachUnderlayFile(
    String projectId,
    String storeyId,
    File sourceFile, {
    BimConversionResult? prepared,
    bool preserveAlignment = false,
  }) async {
    final result =
        prepared ?? await BimUnderlayConversionService.convert(sourceFile);
    try {
      final manifest = await loadProject(projectId);
      if (manifest == null ||
          !manifest.storeys.any((s) => s.storeyId == storeyId)) {
        throw StateError('Unknown project/storey');
      }
      final projDir = await getProjectDirectory(projectId);
      final parent = Directory('${projDir.path}/underlays');
      await parent.create(recursive: true);
      final revision = await parent.createTemp('revision_');
      final relative =
          'underlays/${revision.uri.pathSegments.where((s) => s.isNotEmpty).last}';
      for (final entity in await result.directory.list().toList()) {
        if (entity is File) {
          await entity.copy('${revision.path}/${entity.uri.pathSegments.last}');
        }
      }
      final checked = await KcadService.loadKcadFile(
        File('${revision.path}/working.kcad'),
      );
      final metadata = BimUnderlayMetadata.read(checked);
      if (metadata == null) throw StateError('Invalid processed KCAD');
      // Reload after I/O to retain other edits made while the conversion ran.
      final latest = await loadProject(projectId) ?? manifest;
      final updatedStoreys = latest.storeys.map((s) {
        if (s.storeyId != storeyId) return s;
        return s.copyWith(
          sourceFileName: preserveAlignment
              ? s.sourceFileName
              : sourceFile.uri.pathSegments.last,
          underlayFileName: '$relative/working.kcad',
          clearControlPoint: !preserveAlignment,
          layerVisibility: preserveAlignment ? s.layerVisibility : {},
          wallsDetected: metadata['wallsFound'] == true,
          processing: {
            if (s.processing['structuralTransform'] != null)
              'structuralTransform': s.processing['structuralTransform'],
            if (s.processing['structuralSeeds'] != null)
              'structuralSeeds': s.processing['structuralSeeds'],
            if (s.processing['structuralReviewRequired'] == true)
              'structuralReviewRequired': true,
            if (!s.hasUnderlay) 'seedImportPending': true,
            'version': BimUnderlayMetadata.version,
            'status': metadata['hasResults'] == true
                ? 'completedWithResults'
                : 'completedEmpty',
            'source': '$relative/${result.sourceFile.uri.pathSegments.last}',
            'pure': '$relative/pure.kcad',
            if (result.dxfFile != null) 'dxf': '$relative/source.dxf',
            'fingerprint': result.sourceFingerprint,
          },
        );
      }).toList();
      final updated = latest.copyWith(
        storeys: updatedStoreys,
        alignmentConfirmed: preserveAlignment
            ? latest.alignmentConfirmed
            : false,
        updatedAt: DateTime.now(),
      );
      if (!await saveProjectManifest(updated)) {
        throw FileSystemException('Cannot save project manifest');
      }
      return updatedStoreys.firstWhere((s) => s.storeyId == storeyId);
    } finally {
      if (prepared == null) await result.dispose();
    }
  }

  /// Migrates legacy underlays once; a legacy wallsDetected flag is not a cache.
  Future<BimWorkProject> prepareUnderlays(
    BimWorkProject project, {
    Map<String, DxfDocument>? loadedDocuments,
  }) async {
    var current = await loadProject(project.id) ?? project;
    for (final storey in current.storeys) {
      if (!storey.hasUnderlay) continue;
      var valid = false;
      if (storey.isKcad &&
          storey.processing['version'] == BimUnderlayMetadata.version) {
        final file = await getUnderlayFile(
          current.id,
          storey.underlayFileName!,
        );
        if (file != null) {
          try {
            final doc = await KcadService.loadKcadFile(file);
            valid = BimUnderlayMetadata.read(doc) != null;
            if (valid) loadedDocuments?[storey.storeyId] = doc;
          } catch (_) {
            /* Recover from the preserved source below. */
          }
        }
      }
      if (valid) continue;
      final sourcePath =
          storey.processing['source'] as String? ?? storey.underlayFileName!;
      final source = await getUnderlayFile(current.id, sourcePath);
      if (source == null) {
        throw FileSystemException('Missing underlay source', sourcePath);
      }
      await attachUnderlayFile(
        current.id,
        storey.storeyId,
        source,
        preserveAlignment: true,
      );
      current = await loadProject(current.id) ?? current;
      if (loadedDocuments != null) {
        loadedDocuments[storey.storeyId] = await loadUnderlay(
          current.id,
          current.storeys.firstWhere((s) => s.storeyId == storey.storeyId),
        );
      }
    }
    return current;
  }

  Future<void> reprocessUnderlay(String projectId, String storeyId) async {
    final project = await loadProject(projectId);
    if (project == null) throw StateError('Missing project');
    final storey = project.storeys.firstWhere((s) => s.storeyId == storeyId);
    final source = await getUnderlayFile(
      projectId,
      storey.processing['source'] as String? ?? storey.underlayFileName!,
    );
    if (source == null) throw StateError('Missing source');
    await attachUnderlayFile(
      projectId,
      storeyId,
      source,
      preserveAlignment: true,
    );
  }

  Future<DxfDocument> loadUnderlay(
    String projectId,
    BimStoreyUnderlay storey,
  ) async {
    final file = await getUnderlayFile(projectId, storey.underlayFileName!);
    if (file == null) {
      throw FileSystemException('Missing underlay', storey.underlayFileName);
    }
    return storey.isKcad
        ? KcadService.loadKcadFile(file)
        : DxfParser.parseFromFile(file);
  }

  Future<BimWorkProject> updateStoreys(
    String projectId,
    List<BimStoreyUnderlay> storeys,
  ) => _publications.run(() => _updateStoreys(projectId, storeys));

  Future<BimWorkProject> _updateStoreys(
    String projectId,
    List<BimStoreyUnderlay> storeys,
  ) async {
    if (storeys.isEmpty ||
        storeys.any((s) => !s.elevation.isFinite) ||
        storeys.map((s) => s.storeyId).toSet().length != storeys.length ||
        storeys.map((s) => s.elevationLabel).toSet().length != storeys.length) {
      throw ArgumentError('Storeys must have unique IDs and elevations');
    }
    storeys = [...storeys]..sort((a, b) => a.elevation.compareTo(b.elevation));
    final project = await loadProject(projectId);
    if (project == null) throw StateError('Missing project');
    final old = {for (final s in project.storeys) s.storeyId: s};
    // Only elevation/name/height are edited here, never replace current file paths.
    final updated = project.copyWith(
      storeys: storeys
          .map(
            (s) => (old[s.storeyId] ?? s).copyWith(
              elevation: s.elevation,
              name: s.elevationLabel,
              height: s.height,
            ),
          )
          .toList(),
      referenceStoreyId:
          storeys.any((s) => s.storeyId == project.referenceStorey?.storeyId)
          ? project.referenceStorey?.storeyId
          : storeys.first.storeyId,
      alignmentConfirmed:
          project.alignmentConfirmed &&
          storeys.length == project.storeys.length &&
          storeys.every((s) => old[s.storeyId]?.elevation == s.elevation),
      updatedAt: DateTime.now(),
    );
    if (!await saveProjectManifest(updated)) {
      throw FileSystemException('Cannot save storeys');
    }
    final structural = await loadStructuralProject(projectId);
    if (structural != null &&
        !await saveStructuralProject(projectId, structural)) {
      throw FileSystemException('Cannot synchronize structural storeys');
    }
    return updated;
  }

  /// Refresh per-storey automatic geometry after revision/alignment changes.
  /// A fixed project frame keeps existing structural coordinates stable.
  Future<(BimWorkProject, StructuralProject)> initializeAxes(
    BimWorkProject project,
    StructuralProject structural,
    Map<String, DxfDocument> alignedDocuments, {
    Offset? referenceControlPoint,
    double? cadUnitsPerMeter,
  }) async {
    if (alignedDocuments.isEmpty) return (project, structural);
    final refDoc =
        alignedDocuments[project.referenceStorey?.storeyId] ??
        alignedDocuments.values.first;
    project = project.copyWith(
      structuralOrigin:
          project.structuralOrigin ??
          referenceControlPoint ??
          project.referenceStorey?.controlPoint ??
          refDoc.bounds.center,
      structuralUnitsPerMeter:
          project.structuralUnitsPerMeter ??
          cadUnitsPerMeter ??
          BimUnderlayLoader.computeUnitsPerMeter(refDoc, refDoc.bounds),
    );
    final refreshed = BimStructuralSeedSync.refresh(
      project,
      structural,
      alignedDocuments,
    );
    if (!await saveStructuralProject(project.id, refreshed.$2)) {
      throw StateError('Cannot save refreshed structural project');
    }
    if (!await saveProjectManifest(refreshed.$1)) {
      throw StateError('Cannot save structural seed revisions');
    }
    return refreshed;
  }

  /// Returns the absolute [File] for a relative underlay path within [projectId].
  Future<File?> getUnderlayFile(
    String projectId,
    String underlayRelativePath,
  ) async {
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
