import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/dxf_exporter_service.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/services/structural_persistence_service.dart';
import '../models/bim_work_project.dart';
import 'bim_project_library_service.dart';

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
  }) async {
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

    final cleanStoreyName = bimStorey.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final outBaseName = '${cleanProjName}_$cleanStoreyName';

    final refStorey = project.referenceStorey;
    final cpRef = refStorey?.controlPoint;
    final cpLocal = bimStorey.controlPoint;
    final unitScale = bimStorey.unitScale;

    // 1. Generate structural DXF in local coordinates of the storey
    final structDxfFile = await StructuralPersistenceService.exportStoreyToDxfFile(
      storey: structStorey,
      baseName: outBaseName,
      cpRef: cpRef,
      cpLocal: cpLocal,
      unitScale: unitScale,
      cadUnitsPerMeter: cadUnitsPerMeter,
      outputDirectory: tempDir,
    );

    // 2. If underlay drawing exists, merge with it and apply layerVisibility
    if (bimStorey.hasUnderlay) {
      final underlayFile = await BimProjectLibraryService.instance.getUnderlayFile(
        project.id,
        bimStorey.underlayFileName!,
      );

      if (underlayFile != null && await underlayFile.exists()) {
        final finalDxfFile = File('${tempDir.path}/$outBaseName.dxf');
        return DxfExporterService.exportMergedDxf(
          baseFile: underlayFile,
          importedFiles: [structDxfFile],
          layerVisibility: bimStorey.layerVisibility,
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
  }) async {
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
        );
        final bytes = await storeyFile.readAsBytes();
        final entryName = '${storey.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.dxf';
        archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
      } catch (e) {
        // Continue adding other storeys if one fails
      }
    }

    // 2. Add structural BIM JSON
    final jsonString = const JsonEncoder.withIndent('  ').convert(structural.toJson());
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('${cleanProjName}_model.bim.json', jsonBytes.length, jsonBytes));

    // 3. Add Project Manifest
    final manifestString = const JsonEncoder.withIndent('  ').convert(project.toJson());
    final manifestBytes = utf8.encode(manifestString);
    archive.addFile(ArchiveFile('project.json', manifestBytes.length, manifestBytes));

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
