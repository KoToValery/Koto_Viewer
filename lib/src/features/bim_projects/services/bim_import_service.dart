import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../architect/models/architect_fenestration_style.dart';
import '../../architect/models/architect_project.dart';
import '../../architect/services/component_library_service.dart';
import '../../architect/services/fenestration_library_service.dart';
import '../models/bim_work_project.dart';
import 'bim_export_service.dart';
import 'bim_project_asset_service.dart';
import 'bim_project_library_service.dart';

enum BimImportErrorCode {
  invalidArchive,
  missingManifest,
  unsupportedPackageType,
  integrityCheckFailed,
  invalidProjectData,
  unsafePath,
}

class BimImportException implements Exception {
  final BimImportErrorCode code;
  final String? details;

  const BimImportException(this.code, [this.details]);

  @override
  String toString() =>
      details == null ? 'BimImportException($code)' : 'BimImportException($code: $details)';
}

class BimImportResult {
  final BimWorkProject project;
  final ArchitectProject architect;
  final int restoredAssetsCount;
  final int restoredLibraryItemsCount;

  const BimImportResult({
    required this.project,
    required this.architect,
    this.restoredAssetsCount = 0,
    this.restoredLibraryItemsCount = 0,
  });
}

/// Imports self-contained architectural BiM packages (`*_ArchBimPackage.zip`)
/// created by [BimExportService.exportArchitecturalProjectZip], validating package
/// integrity, restoring all CAD/raster/PDF underlays atomically, and syncing
/// `project.json` and `architectural.json`.
class BimImportService {
  static const _metadataFilesLower = {
    'project.json',
    'architectural.json',
    'package.json',
    'libraries.json',
    'readme.md',
  };

  static Future<BimImportResult> importArchitecturalProjectZip({
    required File zipFile,
    BimProjectLibraryService? libraryService,
    ComponentLibraryService? componentLibrary,
    FenestrationLibraryService? fenestrationLibrary,
    bool forceNewId = false,
  }) async {
    if (!await zipFile.exists()) {
      throw BimImportException(
        BimImportErrorCode.invalidArchive,
        zipFile.path,
      );
    }
    final bytes = await zipFile.readAsBytes();
    return importArchitecturalProjectBytes(
      bytes: bytes,
      libraryService: libraryService,
      componentLibrary: componentLibrary,
      fenestrationLibrary: fenestrationLibrary,
      forceNewId: forceNewId,
    );
  }

  static Future<BimImportResult> importArchitecturalProjectBytes({
    required Uint8List bytes,
    BimProjectLibraryService? libraryService,
    ComponentLibraryService? componentLibrary,
    FenestrationLibraryService? fenestrationLibrary,
    bool forceNewId = false,
  }) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on ArchiveException catch (e) {
      throw BimImportException(BimImportErrorCode.invalidArchive, e.message);
    } catch (e) {
      throw BimImportException(BimImportErrorCode.invalidArchive, e.toString());
    }

    final entriesByPath = <String, ArchiveFile>{};
    final lowerIndex = <String, String>{};
    for (final file in archive.files) {
      if (!file.isFile || file.name.endsWith('/')) continue;
      final String normalized;
      try {
        normalized = BimExportService.validatePackagePath(file.name);
      } on ArgumentError catch (e) {
        throw BimImportException(BimImportErrorCode.unsafePath, e.message?.toString());
      }
      final lower = normalized.toLowerCase();
      if (lowerIndex.containsKey(lower)) {
        throw BimImportException(
          BimImportErrorCode.invalidArchive,
          'Duplicate archive entry: $normalized',
        );
      }
      lowerIndex[lower] = normalized;
      entriesByPath[normalized] = file;
    }

    ArchiveFile? findEntry(String canonicalName) {
      final exact = entriesByPath[canonicalName];
      if (exact != null) return exact;
      final matchedKey = lowerIndex[canonicalName.toLowerCase()];
      return matchedKey == null ? null : entriesByPath[matchedKey];
    }

    List<int> entryBytes(ArchiveFile file) {
      final content = file.content;
      if (content is List<int>) return content;
      throw BimImportException(
        BimImportErrorCode.invalidArchive,
        'Unreadable archive entry: ${file.name}',
      );
    }

    // 1. Validate optional package inventory & checksums when present.
    final inventoryEntry = findEntry(BimExportService.inventoryFileName);
    if (inventoryEntry != null) {
      final Map<String, dynamic> inventory;
      try {
        final decoded = jsonDecode(utf8.decode(entryBytes(inventoryEntry)));
        if (decoded is! Map) {
          throw const FormatException('package.json must be a JSON object');
        }
        inventory = Map<String, dynamic>.from(decoded);
      } catch (e) {
        throw BimImportException(
          BimImportErrorCode.invalidProjectData,
          'Invalid package.json: $e',
        );
      }
      final format = inventory['format'];
      if (format != null && format != BimExportService.architecturalPackageFormat) {
        throw BimImportException(
          BimImportErrorCode.unsupportedPackageType,
          format.toString(),
        );
      }
      final pkgType = inventory['projectType'];
      if (pkgType != null && pkgType != BimExportService.architecturalProjectType) {
        throw BimImportException(
          BimImportErrorCode.unsupportedPackageType,
          pkgType.toString(),
        );
      }
      final listedFiles = inventory['files'];
      if (listedFiles is List) {
        for (final item in listedFiles) {
          if (item is! Map) {
            throw const BimImportException(
              BimImportErrorCode.integrityCheckFailed,
              'Malformed file inventory entry',
            );
          }
          final rawPath = item['path'] as String?;
          if (rawPath == null || rawPath.isEmpty) {
            throw const BimImportException(
              BimImportErrorCode.integrityCheckFailed,
              'Missing path in package inventory',
            );
          }
          final String safePath;
          try {
            safePath = BimExportService.validatePackagePath(rawPath);
          } on ArgumentError catch (e) {
            throw BimImportException(
              BimImportErrorCode.unsafePath,
              e.message?.toString(),
            );
          }
          final archived = findEntry(safePath);
          if (archived == null) {
            throw BimImportException(
              BimImportErrorCode.integrityCheckFailed,
              'Missing archived file: $safePath',
            );
          }
          final data = entryBytes(archived);
          final expectedSize = item['bytes'];
          if (expectedSize is num && data.length != expectedSize.toInt()) {
            throw BimImportException(
              BimImportErrorCode.integrityCheckFailed,
              'Size mismatch for $safePath',
            );
          }
          final expectedSha = item['sha256'];
          if (expectedSha is String &&
              expectedSha.isNotEmpty &&
              sha256.convert(data).toString() != expectedSha) {
            throw BimImportException(
              BimImportErrorCode.integrityCheckFailed,
              'Checksum mismatch for $safePath',
            );
          }
        }
      }
    }

    // 2. Parse project.json and architectural.json.
    final manifestEntry = findEntry(BimExportService.manifestFileName);
    final archEntry = findEntry(BimExportService.architecturalFileName);
    if (manifestEntry == null || archEntry == null) {
      throw const BimImportException(
        BimImportErrorCode.missingManifest,
        'Missing project.json or architectural.json',
      );
    }

    final BimWorkProject rawManifest;
    final ArchitectProject rawArchitect;
    try {
      final manifestJson =
          jsonDecode(utf8.decode(entryBytes(manifestEntry))) as Map<String, dynamic>;
      rawManifest = BimWorkProject.fromJson(manifestJson);
    } catch (e) {
      throw BimImportException(
        BimImportErrorCode.invalidProjectData,
        'Invalid project.json: $e',
      );
    }

    if (rawManifest.projectType != BimProjectType.architectural) {
      throw BimImportException(
        BimImportErrorCode.unsupportedPackageType,
        rawManifest.projectType.name,
      );
    }

    try {
      final archJson =
          jsonDecode(utf8.decode(entryBytes(archEntry))) as Map<String, dynamic>;
      rawArchitect = ArchitectProject.fromJson(archJson);
    } catch (e) {
      throw BimImportException(
        BimImportErrorCode.invalidProjectData,
        'Invalid architectural.json: $e',
      );
    }

    // 3. Resolve target project ID (preserve original ID if unused, else allocate new ID).
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final projectsDir = await lib.getProjectsDirectory();
    final targetId = await _resolveTargetProjectId(
      projectsDir,
      rawManifest.id,
      forceNewId: forceNewId,
    );

    final resolvedName = rawManifest.name.trim().isNotEmpty
        ? rawManifest.name.trim()
        : (rawArchitect.name.trim().isNotEmpty
              ? rawArchitect.name.trim()
              : 'Architectural Project');

    // Normalize CAD underlays (portable packages never retain external host paths).
    ArchitectCadUnderlayConfig cleanCad(ArchitectCadUnderlayConfig config) =>
        config.copyWith(clearExternalSourcePath: true, autoReload: false);

    final cleanedCadUnderlays = <String, ArchitectCadUnderlayConfig>{
      for (final entry in rawArchitect.cadUnderlays.entries)
        entry.key: cleanCad(entry.value),
    };
    final cleanedTechCadUnderlays = [
      for (final config in rawArchitect.technicalCadUnderlays) cleanCad(config),
    ];

    var preparedArchitect = rawArchitect.copyWith(
      id: targetId,
      name: resolvedName,
      cadUnderlays: cleanedCadUnderlays,
      technicalCadUnderlays: cleanedTechCadUnderlays,
    );

    // 4. Stage assets atomically and verify every referenced underlay exists.
    final staging = await projectsDir.createTemp('.import_tmp_');
    var restoredAssetsCount = 0;
    try {
      for (final entry in entriesByPath.entries) {
        if (_metadataFilesLower.contains(entry.key.toLowerCase())) continue;
        final outFile = File('${staging.path}/${entry.key}');
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entryBytes(entry.value), flush: true);
        restoredAssetsCount++;
      }

      preparedArchitect = await BimProjectAssetService.adoptArchitect(
        staging,
        targetId,
        preparedArchitect,
      );
      final preparedManifest = BimProjectLibraryService.syncArchitecturalManifest(
        rawManifest.copyWith(id: targetId, name: resolvedName),
        preparedArchitect,
      );

      await _verifyReferencedAssets(
        staging,
        preparedManifest,
        preparedArchitect,
      );

      const encoder = JsonEncoder.withIndent('  ');
      await File('${staging.path}/${BimExportService.architecturalFileName}')
          .writeAsString(encoder.convert(preparedArchitect.toJson()), flush: true);
      await File('${staging.path}/${BimExportService.manifestFileName}')
          .writeAsString(encoder.convert(preparedManifest.toJson()), flush: true);

      await lib.installImportedProjectDirectory(targetId, staging);
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }

    // 5. Restore custom library definitions if bundled.
    var restoredLibraryItemsCount = 0;
    final librariesEntry = findEntry(BimExportService.librariesFileName);
    if (librariesEntry != null) {
      final Map<String, dynamic> libsJson;
      try {
        final decoded = jsonDecode(utf8.decode(entryBytes(librariesEntry)));
        if (decoded is! Map) {
          throw const FormatException('libraries.json must be a JSON object');
        }
        libsJson = Map<String, dynamic>.from(decoded);
      } catch (e) {
        throw BimImportException(
          BimImportErrorCode.invalidProjectData,
          'Invalid libraries.json: $e',
        );
      }

      final scriptsRaw = libsJson['customComponentScripts'];
      if (scriptsRaw is List && scriptsRaw.isNotEmpty) {
        final compLib = componentLibrary ?? ComponentLibraryService.instance;
        final scripts = [
          for (final item in scriptsRaw)
            if (item is String && item.isNotEmpty) item,
        ];
        restoredLibraryItemsCount += await compLib.importCustomScriptsIfMissing(
          scripts,
        );
      }

      final stylesRaw = libsJson['customOpeningStyles'];
      if (stylesRaw is List && stylesRaw.isNotEmpty) {
        final fenestLib =
            fenestrationLibrary ?? FenestrationLibraryService.instance;
        final styles = <ArchitectFenestrationStyle>[];
        for (final item in stylesRaw) {
          if (item is Map) {
            try {
              styles.add(
                ArchitectFenestrationStyle.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            } catch (_) {}
          }
        }
        restoredLibraryItemsCount += await fenestLib.importCustomStylesIfMissing(
          styles,
        );
      }
    }

    final loadedManifest = await lib.loadProject(targetId);
    final loadedArchitect = await lib.loadArchitectProject(targetId);
    if (loadedManifest == null || loadedArchitect == null) {
      throw const BimImportException(
        BimImportErrorCode.invalidProjectData,
        'Imported project could not be reopened',
      );
    }

    return BimImportResult(
      project: loadedManifest,
      architect: loadedArchitect,
      restoredAssetsCount: restoredAssetsCount,
      restoredLibraryItemsCount: restoredLibraryItemsCount,
    );
  }

  static Future<String> _resolveTargetProjectId(
    Directory projectsDir,
    String candidateId, {
    required bool forceNewId,
  }) async {
    final validId = RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(candidateId);
    if (!forceNewId && validId) {
      final existing = Directory('${projectsDir.path}/$candidateId');
      if (!await existing.exists()) {
        return candidateId;
      }
    }
    final rand = math.Random();
    while (true) {
      final now = DateTime.now();
      final suffix = rand.nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
      final nextId = 'bim_${now.millisecondsSinceEpoch}_$suffix';
      if (!await Directory('${projectsDir.path}/$nextId').exists()) {
        return nextId;
      }
    }
  }

  static Future<void> _verifyReferencedAssets(
    Directory staging,
    BimWorkProject manifest,
    ArchitectProject architect,
  ) async {
    Future<void> requireAsset(String stored) async {
      if (stored.trim().isEmpty) return;
      final resolved = await BimProjectAssetService.resolve(
        staging,
        stored,
        adoptLegacy: false,
      );
      if (resolved == null) {
        throw BimImportException(
          BimImportErrorCode.integrityCheckFailed,
          'Missing asset in package: $stored',
        );
      }
    }

    for (final config in [
      ...architect.cadUnderlays.values,
      ...architect.technicalCadUnderlays,
    ]) {
      await requireAsset(config.internalCopyPath);
      if (config.kcadCachePath != null && config.kcadCachePath!.isNotEmpty) {
        await requireAsset(config.kcadCachePath!);
      }
    }
    for (final raster in architect.rasterUnderlays) {
      await requireAsset(raster.internalImagePath);
      if (raster.sourcePdfPath != null && raster.sourcePdfPath!.isNotEmpty) {
        await requireAsset(raster.sourcePdfPath!);
      }
    }
    for (final storey in manifest.storeys) {
      if (storey.hasUnderlay) {
        await requireAsset(storey.underlayFileName!);
      }
      for (final key in ['source', 'pure', 'dxf']) {
        final dep = storey.processing[key];
        if (dep is String && dep.trim().isNotEmpty) {
          await requireAsset(dep);
        }
      }
    }
  }
}
