import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/dxf_exporter_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'bim_analysis_snapshot.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/services/structural_persistence_service.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';
import 'bim_underlay_loader.dart';
import 'bim_underlay_conversion_service.dart';

/// Service responsible for exporting individual storey DXF drawings (with original
/// CAD coordinates, preserved layer states, and structural BiM layers) and full-project ZIP packages.
class BimExportService {
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
          ? bimStorey.processing['dxf'] as String?
          : bimStorey.underlayFileName;
      if (path == null) {
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
        return DxfExporterService.exportMergedDxf(
          baseFile: underlayFile,
          importedFiles: [structDxfFile],
          layerVisibility: visibility,
          outputFile: finalDxfFile,
        );
      }
    }

    return structDxfFile;
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
