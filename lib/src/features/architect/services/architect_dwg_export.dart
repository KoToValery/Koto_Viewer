import 'dart:typed_data';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/services/dwg_export_service.dart';
import '../models/architect_project.dart';
import 'architect_drawing_publisher.dart';
import 'architect_dxf_export.dart';
import 'architect_export_job.dart';

/// Reuses the vector publication snapshot. Only final DWGs are returned; neither
/// intermediate files nor changes to the project/cached geometry are involved.
abstract final class ArchitectDwgExport {
  static Future<Map<String, Uint8List>> exportViews(
    ArchitectProject project,
    List<ArchitectSavedDrawing> drawings,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    bool geodeticCoordinates = false,
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async => _encode(
    await ArchitectDxfExport.exportViews(
      project,
      drawings,
      l,
      sources: sources,
      geodeticCoordinates: geodeticCoordinates,
      onProgress: (p) => onProgress?.call(p * .7),
      isCancelled: isCancelled,
    ),
    onProgress,
    isCancelled,
  );

  static Future<Map<String, Uint8List>> exportSheets(
    ArchitectProject project,
    List<ArchitectSheet> sheets,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    bool geodeticCoordinates = false,
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async => _encode(
    await ArchitectDxfExport.exportSheets(
      project,
      sheets,
      l,
      sources: sources,
      geodeticCoordinates: geodeticCoordinates,
      onProgress: (p) => onProgress?.call(p * .7),
      isCancelled: isCancelled,
    ),
    onProgress,
    isCancelled,
  );

  static Future<Map<String, Uint8List>> _encode(
    Map<String, Uint8List> source,
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  ) async {
    final result = <String, Uint8List>{};
    try {
      for (final entry in source.entries) {
        architectCheckExportCancelled(isCancelled);
        result['${entry.key.substring(0, entry.key.length - 4)}.dwg'] =
            await DwgExportService.encode(
              entry.value,
              isCancelled: isCancelled,
            );
        await architectExportCheckpoint(
          .7 + .3 * result.length / source.length,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
      }
    } on DwgExportCancelled {
      throw const ArchitectExportCancelled();
    }
    return result;
  }
}
