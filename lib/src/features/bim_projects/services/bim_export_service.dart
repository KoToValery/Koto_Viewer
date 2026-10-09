import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/dxf_exporter_service.dart';
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
    double cadUnitsPerMeter = 1.0,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
  }) async {
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final tempDir = outputDirectory ?? await getTemporaryDirectory();
    final cleanProjName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final bimStorey = project.storeys.firstWhere(
      (s) => s.storeyId == storeyId,
      orElse: () => project.storeys.first,
    );

    final structStorey = structural.storeys.firstWhere(
      (s) => s.id == storeyId,
      orElse: () => structural.activeStorey,
    );

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
    final cpRef = project.structuralOrigin ?? refStorey?.controlPoint;
    final cpLocal = bimStorey.controlPoint;
    var unitScale = bimStorey.unitScale;
    if (bimStorey.hasUnderlay && refStorey != null && refStorey.hasUnderlay) {
      final local = await lib.loadUnderlay(project.id, bimStorey);
      final reference = await lib.loadUnderlay(project.id, refStorey);
      unitScale =
          (project.structuralUnitsPerMeter ??
              BimUnderlayLoader.computeUnitsPerMeter(
                reference,
                reference.bounds,
              )) /
          BimUnderlayLoader.computeUnitsPerMeter(local, local.bounds);
    }

    // 1. Generate structural DXF in local coordinates of the storey
    final structDxfFile =
        await StructuralPersistenceService.exportStoreyToDxfFile(
          storey: structural
              .resolveCeilingStorey(structStorey)
              .copyWith(gridAxes: structural.effectiveGridAxes),
          baseName: outBaseName,
          cpRef: cpRef,
          cpLocal: cpLocal,
          unitScale: unitScale,
          cadUnitsPerMeter: cadUnitsPerMeter,
          outputDirectory: tempDir,
          axisLayerName: 'BIM_Axis',
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

  /// Exports all storey drawings, the JSON model, and the project manifest as a ZIP package.
  static Future<File> exportProjectZip({
    required BimWorkProject project,
    required StructuralProject structural,
    double cadUnitsPerMeter = 1.0,
    Directory? outputDirectory,
    BimProjectLibraryService? libraryService,
  }) async {
    final lib = libraryService ?? BimProjectLibraryService.instance;
    final tempDir = outputDirectory ?? await getTemporaryDirectory();
    final cleanProjName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final archive = Archive();

    // 1. Export DXF for each storey
    for (final storey in project.storeys) {
      try {
        final storeyFile = await exportStoreyDxf(
          project: project,
          structural: structural,
          storeyId: storey.storeyId,
          cadUnitsPerMeter: cadUnitsPerMeter,
          outputDirectory: tempDir,
          libraryService: lib,
        );
        final bytes = await storeyFile.readAsBytes();
        final safeId = storey.storeyId.replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final entryName = '${storey.elevationLabel}_$safeId.dxf';
        archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
      } catch (e) {
        throw StateError('Export failed at ${storey.elevationLabel}: $e');
      }
    }

    // Include all files referenced by the manifest so the package is recoverable.
    final paths = <String>{};
    for (final storey in project.storeys) {
      if (storey.underlayFileName != null) paths.add(storey.underlayFileName!);
      for (final key in ['source', 'pure', 'dxf']) {
        final path = storey.processing[key];
        if (path is String) paths.add(path);
      }
    }
    for (final path in paths) {
      final file = await lib.getUnderlayFile(project.id, path);
      if (file == null) throw FileSystemException('Missing package file', path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    final structuralBytes = utf8.encode(jsonEncode(structural.toJson()));
    archive.addFile(
      ArchiveFile('structural.json', structuralBytes.length, structuralBytes),
    );

    // 2. Add structural BIM JSON
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(structural.toJson());
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(
      ArchiveFile(
        '${cleanProjName}_model.bim.json',
        jsonBytes.length,
        jsonBytes,
      ),
    );

    // 3. Add Project Manifest
    final manifestString = const JsonEncoder.withIndent(
      '  ',
    ).convert(project.toJson());
    final manifestBytes = utf8.encode(manifestString);
    archive.addFile(
      ArchiveFile('project.json', manifestBytes.length, manifestBytes),
    );

    // 4. Encode ZIP
    final zipBytes = ZipEncoder().encode(archive)!;
    final zipFile = File('${tempDir.path}/${cleanProjName}_BimPackage.zip');
    await zipFile.writeAsBytes(zipBytes, flush: true);

    return zipFile;
  }

  /// Prompts the system share dialog for the exported file.
  static Future<void> shareFile(File file, {String? subject}) async {
    await StructuralPersistenceService.shareFile(file, subject: subject);
  }
}
