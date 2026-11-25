import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/dxf_exporter_service.dart';
import '../../../core/services/dwg_export_service.dart';
import '../../../core/services/acadrust_converter_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'bim_analysis_snapshot.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/services/structural_persistence_service.dart';
import '../../architect/components/dsl/parametric_script_parser.dart';
import '../../architect/models/architect_project.dart';
import '../../architect/services/component_library_service.dart';
import '../../architect/services/fenestration_library_service.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';
import 'bim_underlay_loader.dart';
import 'bim_underlay_conversion_service.dart';
import 'bim_project_asset_service.dart';

/// Service responsible for exporting individual storey DXF drawings (with original
/// CAD coordinates, preserved layer states, and structural BiM layers) and full-project ZIP packages.
class BimExportService {
  static const String architecturalPackageFormat = 'koto.bim.package';
  static const String architecturalPackageVersion = '1.0';
  static const String architecturalProjectType = 'architectural';
  static const String manifestFileName = 'project.json';
  static const String architecturalFileName = 'architectural.json';
  static const String inventoryFileName = 'package.json';
  static const String librariesFileName = 'libraries.json';
  /// Reuses storey alignment, units and visible layers from the established CAD
  /// export. All working CAD files are owned by this job and removed afterwards.
  static Future<File> exportStoreyDwg({
    required BimWorkProject project,
    required StructuralProject structural,
    required String storeyId,
    double? cadUnitsPerMeter,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
  }) async {
    final directory = outputDirectory ?? await getTemporaryDirectory();
    await directory.create(recursive: true);
    final work = await directory.createTemp('bim_dwg_export_');
    try {
      final cad = await exportStoreyDxf(
        project: project,
        structural: structural,
        storeyId: storeyId,
        cadUnitsPerMeter: cadUnitsPerMeter,
        outputDirectory: work,
        libraryService: libraryService,
      );
      final bytes = await DwgExportService.encode(await cad.readAsBytes());
      final name = cad.uri.pathSegments.last;
      return File(
        '${directory.path}/${name.substring(0, name.length - 4)}.dwg',
      ).writeAsBytes(bytes, flush: true);
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// Exports a single storey level as an AutoCAD DXF file merged with the structural BiM model.
  /// If an architectural underlay is attached, the structural elements are transformed back into
  /// the drawing's original local coordinate space, and layer on/off states are preserved.
  static Future<File> exportStoreyDxf({
    required BimWorkProject project,
    required StructuralProject structural,
    required String storeyId,
    double? cadUnitsPerMeter,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
  }) async {
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final tempDir = outputDirectory ?? await getTemporaryDirectory();
    final cleanProjName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final bimStorey = project.storeys.firstWhere((s) => s.storeyId == storeyId);

    final structStorey = structural.storeys.firstWhere((s) => s.id == storeyId);

    final cleanStoreyName = bimStorey.elevationLabel.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final safeId = bimStorey.storeyId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    final outBaseName = '${cleanProjName}_${cleanStoreyName}_$safeId';

    final refStorey = project.referenceStorey;
    final local = bimStorey.hasUnderlay
        ? await lib.loadUnderlay(project.id, bimStorey)
        : null;
    final reference = refStorey?.hasUnderlay == true
        ? (refStorey!.storeyId == bimStorey.storeyId
              ? local
              : await lib.loadUnderlay(project.id, refStorey))
        : null;
    final resolvedUnits =
        project.structuralUnitsPerMeter ??
        cadUnitsPerMeter ??
        (reference == null
            ? 1.0
            : BimUnderlayLoader.computeUnitsPerMeter(
                reference,
                reference.bounds,
              ));
    if (!resolvedUnits.isFinite || resolvedUnits <= 0) {
      throw ArgumentError('Invalid project CAD units per metre');
    }
    final cpRef =
        project.structuralOrigin ??
        refStorey?.controlPoint ??
        reference?.bounds.center;
    final cpLocal = bimStorey.controlPoint;
    final unitScale = local == null
        ? bimStorey.unitScale
        : resolvedUnits /
              BimUnderlayLoader.computeUnitsPerMeter(local, local.bounds);

    // 1. Generate structural DXF in local coordinates of the storey
    final structDxfFile =
        await StructuralPersistenceService.exportStoreyToDxfFile(
          storey: structural
              .storeyPlanFor(structStorey)
              .copyWith(gridAxes: structural.effectiveGridAxes),
          baseName: outBaseName,
          cpRef: cpRef,
          cpLocal: cpLocal,
          unitScale: unitScale,
          cadUnitsPerMeter: resolvedUnits,
          outputDirectory: tempDir,
          axisLayerName: 'BIM_Axis',
          gridAxisStoreys: structural.storeys,
        );

    // 2. If underlay drawing exists, merge with it and apply layerVisibility
    if (bimStorey.hasUnderlay) {
      final path = bimStorey.isKcad
          ? (bimStorey.processing['dxf'] ?? bimStorey.processing['source'])
                as String?
          : bimStorey.underlayFileName;
      if (path == null || path.toLowerCase().endsWith('.kcad')) {
        throw UnsupportedError(
          'DXF export of a KCAD-only underlay requires its original DXF. The KCAD underlay is preserved.',
        );
      }
      final underlayFile = await lib.getUnderlayFile(project.id, path);
      if (underlayFile == null) {
        throw FileSystemException('Missing export source', path);
      }
      var visibility = bimStorey.layerVisibility;
      if (bimStorey.isKcad) {
        final doc = await lib.loadUnderlay(project.id, bimStorey);
        final metadata = BimUnderlayMetadata.read(doc);
        // Export original architecture; generated contours are a working filter.
        if (metadata != null) {
          final original = Map<String, bool>.from(
            metadata['visibility'] as Map,
          );
          final filtered = BimUnderlayMetadata.generatedLayers(
            doc,
          ).any((name) => visibility[name] == true);
          visibility = filtered
              ? original
              : {
                  for (final entry in original.entries)
                    entry.key: visibility[entry.key] ?? entry.value,
                };
        }
      }

      if (await underlayFile.exists()) {
        final finalDxfFile = File('${tempDir.path}/$outBaseName.dxf');
        return _mergeStoreySource(
          underlayFile: underlayFile,
          importedFiles: [structDxfFile],
          layerVisibility: visibility,
          outputFile: finalDxfFile,
        );
      }
    }

    return structDxfFile;
  }

  static Future<File> _mergeStoreySource({
    required File underlayFile,
    required List<File> importedFiles,
    required Map<String, bool> layerVisibility,
    required File outputFile,
  }) async {
    Directory? work;
    try {
      var base = underlayFile;
      if (base.path.toLowerCase().endsWith('.dwg')) {
        // Explicit export only. Opening the underlay continues to read DWG directly.
        work = await outputFile.parent.createTemp('bim_export_source_');
        final exchange = File('${work.path}/source.dxf');
        final bool success;
        if (Platform.isAndroid) {
          success = await AcadrustConverterService.convertAndroid(
            input: base,
            output: exchange,
          );
        } else {
          final executable = AcadrustConverterService.findExecutable();
          if (executable == null) {
            throw UnsupportedError('Native CAD export unavailable');
          }
          success = await AcadrustConverterService.convert(
            executable: executable,
            input: base,
            output: exchange,
          );
        }
        if (!success) {
          throw StateError('Could not export original DWG underlay');
        }
        base = exchange;
      }
      return await DxfExporterService.exportMergedDxf(
        baseFile: base,
        importedFiles: importedFiles,
        layerVisibility: layerVisibility,
        outputFile: outputFile,
      );
    } finally {
      if (work != null) await work.delete(recursive: true);
    }
  }

  /// A self-contained package: authoritative model, original working sources,
  /// explicit units/alignment, readable placement inputs and derived drawings.
  static Future<File> exportProjectZip({
    required BimWorkProject project,
    required StructuralProject structural,
    double? cadUnitsPerMeter,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
  }) async {
    _validateStoreys(project, structural);
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final tempDir = outputDirectory ?? await getTemporaryDirectory();
    await tempDir.create(recursive: true);
    final cleanProjName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final archive = Archive();
    final files = <String, Map<String, Object>>{};
    final warnings = <Map<String, Object?>>[];
    void add(String path, List<int> bytes, String role) {
      final name = _packagePath(path);
      if (files.keys.any((p) => p.toLowerCase() == name.toLowerCase())) {
        throw StateError('Duplicate ZIP path: $name');
      }
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      files[name] = {
        'path': name,
        'role': role,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      };
    }

    void json(String path, Object value, String role) => add(
      path,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(value)),
      role,
    );

    // Canonical package-relative paths; never archive a host absolute path.
    final exportProject = project.copyWith(
      storeys: [
        for (final s in project.storeys)
          s.copyWith(
            underlayFileName: s.hasUnderlay
                ? _packagePath(s.underlayFileName!)
                : null,
            processing: {
              ...s.processing,
              for (final key in ['source', 'pure', 'dxf'])
                if (s.processing[key] is String)
                  key: _packagePath(s.processing[key] as String),
            },
          ),
      ],
    );
    final paths = <String>{};
    for (final s in exportProject.storeys) {
      if (s.hasUnderlay) paths.add(s.underlayFileName!);
      for (final key in ['source', 'pure', 'dxf']) {
        final value = s.processing[key];
        if (value is String) paths.add(value);
      }
    }
    // Fail before publication if a manifest reference cannot be recovered.
    for (final path in paths) {
      final file = await lib.getUnderlayFile(project.id, path);
      if (file == null) throw FileSystemException('Missing package file', path);
      add(path, await file.readAsBytes(), 'underlaySource');
    }
    final rawDocs = <String, DxfDocument>{};
    for (final s in exportProject.storeys.where((s) => s.hasUnderlay)) {
      rawDocs[s.storeyId] = await lib.loadUnderlay(project.id, s);
    }
    final reference = exportProject.referenceStorey;
    final refDoc = rawDocs[reference?.storeyId] ?? rawDocs.values.firstOrNull;
    final units =
        project.structuralUnitsPerMeter ??
        cadUnitsPerMeter ??
        (refDoc == null
            ? 1.0
            : BimUnderlayLoader.computeUnitsPerMeter(refDoc, refDoc.bounds));
    if (!units.isFinite || units <= 0) {
      throw ArgumentError('Invalid project CAD units per metre');
    }
    final origin =
        project.structuralOrigin ??
        reference?.controlPoint ??
        refDoc?.bounds.center ??
        Offset.zero;
    final unitSource = project.structuralUnitsPerMeter != null
        ? 'savedProjectFrame'
        : cadUnitsPerMeter != null
        ? 'caller'
        : refDoc != null
        ? 'referenceUnderlay'
        : 'defaultMetres';
    if (unitSource == 'defaultMetres') {
      warnings.add({
        'code': 'unitsAssumed',
        'message':
            'No saved units or underlay; CAD units assumed to be metres.',
      });
    }
    if (!project.alignmentConfirmed && rawDocs.isNotEmpty) {
      warnings.add({
        'code': 'alignmentUnconfirmed',
        'message': 'Storey alignment has not been confirmed.',
      });
    }
    final portableProject = exportProject.copyWith(
      structuralUnitsPerMeter: units,
      structuralOrigin: origin,
    );
    final aligned = BimUnderlayLoader.alignDocuments(
      project: portableProject,
      rawDocuments: rawDocs,
    );
    final analysis = BimAnalysisSnapshot.build(
      project: portableProject,
      structural: structural,
      rawDocuments: rawDocs,
      aligned: aligned,
      unitsSource: unitSource,
      warnings: warnings,
    );

    // DXF is a derived presentation. A KCAD-only source still produces a full
    // analysis package when conversion to an original merged DXF is unavailable.
    final drawings = <Map<String, Object?>>[];
    final reserved = {
      'project.json',
      'structural.json',
      'analysis.json',
      'package.json',
      'readme.md',
      '${cleanProjName}_model.bim.json'.toLowerCase(),
      ...files.keys.map((p) => p.toLowerCase()),
    };
    for (var i = 0; i < portableProject.storeys.length; i++) {
      final s = portableProject.storeys[i];
      try {
        final file = await exportStoreyDxf(
          project: portableProject,
          structural: structural,
          storeyId: s.storeyId,
          cadUnitsPerMeter: units,
          outputDirectory: tempDir,
          libraryService: lib,
        );
        final safeId = s.storeyId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        var path = '${s.elevationLabel}_$safeId.dxf';
        var suffix = 1;
        while (reserved.contains(path.toLowerCase())) {
          path = '${s.elevationLabel}_${safeId}_${suffix++}.dxf';
        }
        reserved.add(path.toLowerCase());
        add(path, await file.readAsBytes(), 'storeyDrawing');
        drawings.add({
          'storeyId': s.storeyId,
          'path': path,
          'coordinateSpace': s.controlPoint == null
              ? 'projectCAD'
              : 'sourceCAD',
          'status': 'available',
        });
      } on UnsupportedError catch (e) {
        drawings.add({
          'storeyId': s.storeyId,
          'status': 'unavailable',
          'reason': e.message,
        });
        warnings.add({
          'code': 'derivedDxfUnavailable',
          'storeyId': s.storeyId,
          'message': e.message,
        });
      } catch (e) {
        throw StateError('Export failed at ${s.elevationLabel}: $e');
      }
    }
    json(
      'structural.json',
      structural.toJson(),
      'authoritativeStructuralModel',
    );
    json(
      '${cleanProjName}_model.bim.json',
      structural.toJson(),
      'structuralModelAlias',
    );
    json('project.json', portableProject.toJson(), 'projectManifest');
    json('analysis.json', analysis, 'readablePlacementInputs');
    add('README.md', utf8.encode(BimAnalysisSnapshot.readme), 'documentation');
    // The inventory covers every payload entry, excluding its own checksum.
    json('package.json', {
      'format': 'KotoBimAnalysisPackage',
      'schemaVersion': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'projectId': project.id,
      'projectManifest': 'project.json',
      'structuralModel': 'structural.json',
      'analysisInputs': 'analysis.json',
      'cadUnitsPerMeter': units,
      'drawings': drawings,
      'warnings': warnings,
      'files': files.values.toList(),
    }, 'packageInventory');
    final zipBytes = ZipEncoder().encode(archive)!;
    final zipFile = File('${tempDir.path}/${cleanProjName}_BimPackage.zip');
    final pending = File(
      '${zipFile.path}.tmp_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await pending.writeAsBytes(zipBytes, flush: true);
      return await pending.rename(zipFile.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  /// Exports an architectural BiM project package as a ZIP containing manifest,
  /// architectural model (JSON), optional custom libraries, and all referenced
  /// CAD/raster/PDF underlay assets.
  static Future<File> exportArchitecturalProjectZip({
    required BimWorkProject project,
    required ArchitectProject architect,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
    ComponentLibraryService? componentLibrary,
    FenestrationLibraryService? fenestrationLibrary,
  }) async {
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final compLib = componentLibrary ?? ComponentLibraryService.instance;
    final fenestLib = fenestrationLibrary ?? FenestrationLibraryService.instance;
    final syncedManifest = project.projectType == BimProjectType.architectural
        ? BimProjectLibraryService.syncArchitecturalManifest(project, architect)
        : project;
    final tempDir = outputDirectory ?? await getTemporaryDirectory();
    await tempDir.create(recursive: true);
    final rawName = syncedManifest.name.trim().isNotEmpty
        ? syncedManifest.name.trim()
        : 'ArchitectProject';
    final cleanProjName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final archive = Archive();
    final files = <String, Map<String, Object>>{};

    void add(String path, List<int> bytes, String role) {
      final name = validatePackagePath(path);
      final existing = files.keys
          .where((p) => p.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        if (files[existing]!['sha256'] == sha256.convert(bytes).toString()) {
          return;
        }
        throw StateError('Duplicate ZIP path: $name');
      }
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      files[name] = {
        'path': name,
        'role': role,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      };
    }

    void json(String path, Object value, String role) => add(
      path,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(value)),
      role,
    );

    final root = await lib.getProjectDirectory(syncedManifest.id);
    Future<String?> asset(
      String stored,
      String role, {
      bool required = true,
    }) async {
      final file = await BimProjectAssetService.resolve(root, stored);
      if (file == null) {
        if (required) {
          throw FileSystemException('Missing project asset', stored);
        }
        return null;
      }
      final relative = BimProjectAssetService.relativePath(root, file);
      add(relative, await file.readAsBytes(), role);
      return relative;
    }

    final portableArchitect =
        (jsonDecode(jsonEncode(architect.toJson())) as Map<String, dynamic>)
          ..['id'] = syncedManifest.id
          ..['name'] = syncedManifest.name;
    for (final value in [
      ...(portableArchitect['cadUnderlays'] as Map? ?? {}).values,
      ...(portableArchitect['technicalCadUnderlays'] as List? ?? []),
    ]) {
      final config = value as Map;
      final internalCopy = config['internalCopyPath'] as String?;
      if (internalCopy != null && internalCopy.trim().isNotEmpty) {
        config['internalCopyPath'] = await asset(
          internalCopy,
          'underlaySource',
        );
      }
      final cache = config['kcadCachePath'] as String?;
      final portableCache = (cache == null || cache.trim().isEmpty)
          ? null
          : await asset(cache, 'underlayCache', required: false);
      if (portableCache == null) {
        config.remove('kcadCachePath');
      } else {
        config['kcadCachePath'] = portableCache;
      }
      config.remove('externalSourcePath');
      config['autoReload'] = false;
    }
    for (final value in portableArchitect['rasterUnderlays'] as List? ?? []) {
      final raster = value as Map;
      final imagePath = raster['internalImagePath'] as String?;
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        raster['internalImagePath'] = await asset(
          imagePath,
          'rasterUnderlay',
        );
      }
      final pdf = raster['sourcePdfPath'] as String?;
      final portablePdf = (pdf == null || pdf.trim().isEmpty)
          ? null
          : await asset(pdf, 'pdfSource', required: false);
      if (portablePdf == null) {
        raster.remove('sourcePdfPath');
      } else {
        raster['sourcePdfPath'] = portablePdf;
      }
    }
    final portableManifest =
        jsonDecode(jsonEncode(syncedManifest.toJson())) as Map<String, dynamic>;
    for (final value in portableManifest['storeys'] as List? ?? []) {
      final storey = value as Map;
      final working = storey['underlayFileName'];
      if (working is String && working.trim().isNotEmpty) {
        storey['underlayFileName'] = await asset(
          working,
          'underlayWorking',
        );
      }
      final processing = storey['processing'] as Map?;
      if (processing != null) {
        for (final key in ['source', 'pure', 'dxf']) {
          final dep = processing[key];
          if (dep is String && dep.trim().isNotEmpty) {
            processing[key] = await asset(
              dep,
              'underlayDependency',
            );
          }
        }
      }
    }

    // Export any referenced custom scripted components or custom opening styles
    // so imported projects work identically on another device.
    final customComponentScripts = <String>[];
    final customOpeningStyles = <Map<String, dynamic>>[];
    try {
      await compLib.init();
      final usedComponentIds = <String>{
        for (final s in architect.storeys)
          for (final c in s.components) c.definitionId,
      };
      for (final defId in usedComponentIds) {
        final def = compLib.findDefinition(defId);
        if (def is ScriptedComponentDefinition) {
          customComponentScripts.add(def.rawSourceJson);
        }
      }
    } catch (_) {}
    try {
      await fenestLib.init();
      final embeddedStyleIds = {
        for (final style in architect.openingStyles) style.id,
      };
      final usedStyleIds = <String>{
        for (final s in architect.storeys)
          for (final w in s.walls) ...[
            for (final d in w.doors)
              if (d.style == null && d.styleId != null) d.styleId!,
            for (final win in w.windows)
              if (win.style == null && win.styleId != null) win.styleId!,
          ],
      };
      for (final styleId in usedStyleIds) {
        if (embeddedStyleIds.contains(styleId)) continue;
        final style = fenestLib.getStyleById(styleId);
        if (style != null && !style.isPreset) {
          customOpeningStyles.add(style.toJson());
        }
      }
    } catch (_) {}

    if (customComponentScripts.isNotEmpty || customOpeningStyles.isNotEmpty) {
      json(librariesFileName, {
        if (customComponentScripts.isNotEmpty)
          'customComponentScripts': customComponentScripts,
        if (customOpeningStyles.isNotEmpty)
          'customOpeningStyles': customOpeningStyles,
      }, 'customLibraries');
    }

    json(manifestFileName, portableManifest, 'projectManifest');
    json(architecturalFileName, portableArchitect, 'architecturalModel');

    // Add package inventory
    json(inventoryFileName, {
      'format': architecturalPackageFormat,
      'version': architecturalPackageVersion,
      'projectType': architecturalProjectType,
      'projectId': syncedManifest.id,
      'name': syncedManifest.name,
      'createdAt': DateTime.now().toIso8601String(),
      'files': files.values.toList(),
    }, 'packageInventory');

    final zipBytes = ZipEncoder().encode(archive)!;
    final zipFile = File('${tempDir.path}/${cleanProjName}_ArchBimPackage.zip');
    final pending = File(
      '${zipFile.path}.tmp_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await pending.writeAsBytes(zipBytes, flush: true);
      return await pending.rename(zipFile.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  static String validatePackagePath(String path) => _packagePath(path);

  static String _packagePath(String path) {
    final value = path.replaceAll('\\', '/');
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.contains(':') ||
        value.split('/').any((p) => p.isEmpty || p == '.' || p == '..') ||
        value.contains('\u0000')) {
      throw ArgumentError('Expected a package-relative path: $path');
    }
    return value;
  }

  static void _validateStoreys(
    BimWorkProject project,
    StructuralProject structural,
  ) {
    final ids = project.storeys.map((s) => s.storeyId).toSet();
    final modelIds = structural.storeys.map((s) => s.id).toSet();
    if (ids.isEmpty ||
        ids.length != project.storeys.length ||
        modelIds.length != structural.storeys.length ||
        ids.length != modelIds.length ||
        !ids.containsAll(modelIds)) {
      throw StateError(
        'Project manifest and structural storey IDs must match exactly',
      );
    }
    for (final s in project.storeys) {
      final model = structural.storeys.firstWhere((m) => m.id == s.storeyId);
      if (!s.elevation.isFinite ||
          !model.elevation.isFinite ||
          (s.elevation - model.elevation).abs() > 1e-6) {
        throw StateError('Inconsistent elevation for storey ${s.storeyId}');
      }
    }
  }

  /// Prompts the system share dialog for the exported file.
  static Future<void> shareFile(File file, {String? subject}) async {
    await StructuralPersistenceService.shareFile(file, subject: subject);
  }
}
