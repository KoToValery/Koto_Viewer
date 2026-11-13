// === SECTION: ARCHITECT UNDERLAY & LIVE XREF SERVICE ===

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/services/dwg_converter_service.dart';
import '../../../core/services/universal_encoding_service.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../../bim_projects/services/bim_project_asset_service.dart';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../dxf_viewer/binary/kcad_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../models/architect_underlay_models.dart';
import 'architect_geodetic_detector.dart';

class ArchitectCadImportResult {
  final DxfDocument document;
  final ArchitectCadUnderlayConfig config;
  final ArchitectGeodeticDetectionResult geodeticResult;

  const ArchitectCadImportResult({
    required this.document,
    required this.config,
    required this.geodeticResult,
  });
}

class ArchitectRasterImportResult {
  final ArchitectRasterUnderlay model;
  final ui.Image image;

  const ArchitectRasterImportResult({required this.model, required this.image});
}

/// Manages internal project storage (`<AppDocs>/KotoBim/projects/<projectId>/underlays/...`),
/// DWG/DXF conversion and project-owned CAD/raster/PDF snapshots.
class ArchitectUnderlayService {
  final BimProjectLibraryService _library;
  ArchitectUnderlayService({BimProjectLibraryService? libraryService})
    : _library = libraryService ?? BimProjectLibraryService.instance;
  static final ArchitectUnderlayService instance = ArchitectUnderlayService();

  Future<File?> resolveOwnedAsset(
    String projectId,
    String storedPath, {
    bool adoptLegacy = true,
  }) async => BimProjectAssetService.resolve(
    await _library.getProjectDirectory(projectId),
    storedPath,
    adoptLegacy: adoptLegacy,
  );

  Future<String> projectRelativePath(String projectId, File file) async =>
      BimProjectAssetService.relativePath(
        await _library.getProjectDirectory(projectId),
        file,
      );

  /// Captures an aligned original document without changing its coordinate frame.
  Future<ArchitectCadUnderlayConfig> captureCadSnapshot({
    required String projectId,
    required String storeyId,
    required DxfDocument document,
    required BimCoordinateFrame frame,
  }) async {
    final directory = await getCadUnderlayDir(projectId);
    final revision = await directory.createTemp(
      '${_sanitizeFileName(storeyId)}_revision_',
    );
    final file = File('${revision.path}/snapshot.kcad');
    await KcadService.exportKcadFile(document, file.path);
    await KcadService.loadKcadFile(file);
    final relative = await projectRelativePath(projectId, file);
    return ArchitectCadUnderlayConfig(
      storeyId: storeyId,
      fileName: '$storeyId.kcad',
      internalCopyPath: relative,
      kcadCachePath: relative,
      lockedCadOriginX: frame.origin.dx,
      lockedCadOriginY: frame.origin.dy,
      unitsPerMeter: frame.unitsPerMeter,
      autoReload: false,
    );
  }

  Future<Directory> getCadUnderlayDir(String projectId) async {
    final projDir = await _library.getProjectDirectory(projectId);
    final dir = Directory('${projDir.path}/underlays/cad');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getRasterUnderlayDir(String projectId) async {
    final projDir = await _library.getProjectDirectory(projectId);
    final dir = Directory('${projDir.path}/underlays/raster');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _sanitizeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'underlay' : cleaned;
  }

  /// Imports or reloads an external DWG/DXF/KCAD file into the project's
  /// internal `underlays/cad/` directory, locks or preserves the coordinate
  /// origin, and runs automatic geodetic contour detection.
  Future<ArchitectCadImportResult> importOrReloadCadUnderlay({
    required String projectId,
    required String storeyId,
    required File sourceFile,
    ArchitectCadUnderlayConfig? existingConfig,
    ArchitectGeodeticSurvey? existingSurvey,
    bool preserveExistingOrigin = true,
  }) async {
    final cadDir = await getCadUnderlayDir(projectId);
    final fileName = sourceFile.uri.pathSegments.isNotEmpty
        ? sourceFile.uri.pathSegments.last
        : sourceFile.path.split(RegExp(r'[/\\]')).last;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'dxf';

    final safeStorey = _sanitizeFileName(storeyId);
    final safeName = _sanitizeFileName(fileName);
    // A revision is published only through its returned config after parsing.
    // Failed refreshes therefore never overwrite the currently displayed snapshot.
    final revision = await cadDir.createTemp('${safeStorey}_revision_');
    final internalCopy = File('${revision.path}/$safeName');
    if (sourceFile.absolute.path != internalCopy.absolute.path) {
      await sourceFile.copy(internalCopy.path);
    }

    final stat = await sourceFile.stat();
    final lastModMs = stat.modified.millisecondsSinceEpoch;

    // Parse or convert DWG -> DXF -> DxfDocument
    final doc = await _parseCadFile(internalCopy, ext);

    // Determine whether to lock to existing origin
    ui.Offset? lockedOrigin;
    double? lockedUnitsPerMeter;
    if (preserveExistingOrigin &&
        existingConfig != null &&
        existingConfig.lockOrigin &&
        existingConfig.hasLockedOrigin) {
      lockedOrigin = ui.Offset(
        existingConfig.lockedCadOriginX!,
        existingConfig.lockedCadOriginY!,
      );
      lockedUnitsPerMeter = existingConfig.unitsPerMeter!;
    }

    final geodeticResult = ArchitectGeodeticDetector.analyzeDocument(
      doc: doc,
      storeyId: storeyId,
      lockedOrigin: lockedOrigin,
      lockedUnitsPerMeter: lockedUnitsPerMeter,
      existingSurvey: existingSurvey,
    );

    final kcadCache = File('${revision.path}/snapshot.kcad');
    try {
      await KcadService.exportKcadFile(doc, kcadCache.path);
    } catch (e) {
      debugPrint('[ArchitectUnderlayService] KCAD cache export note: $e');
    }

    final config = ArchitectCadUnderlayConfig(
      storeyId: storeyId,
      fileName: fileName,
      externalSourcePath: sourceFile.path,
      internalCopyPath: await projectRelativePath(projectId, internalCopy),
      kcadCachePath: await kcadCache.exists()
          ? await projectRelativePath(projectId, kcadCache)
          : null,
      autoReload: false,
      lockOrigin: existingConfig?.lockOrigin ?? true,
      lastModifiedMs: lastModMs,
      lockedCadOriginX: geodeticResult.frame.origin.dx,
      lockedCadOriginY: geodeticResult.frame.origin.dy,
      unitsPerMeter: geodeticResult.frame.unitsPerMeter,
      hiddenDxfLayers: existingConfig?.hiddenDxfLayers ?? const {},
      isGeodetic: geodeticResult.isGeodetic,
      detectedCrsName: geodeticResult.coordinateSystem.name,
      opacity: existingConfig?.opacity ?? 0.42,
      useOriginalColors: existingConfig?.useOriginalColors ?? false,
      useOriginalLineweights: existingConfig?.useOriginalLineweights ?? false,
      visible: existingConfig?.visible ?? true,
      maskPolygon: existingConfig?.maskPolygon,
      maskEnabled: existingConfig?.maskEnabled ?? true,
    );

    return ArchitectCadImportResult(
      document: doc,
      config: config,
      geodeticResult: geodeticResult,
    );
  }

  /// Loads a previously saved CAD underlay from the project's internal cache or copy.
  Future<DxfDocument?> loadSavedCadUnderlay(
    ArchitectCadUnderlayConfig config, {
    String? projectId,
  }) async {
    for (final stored in [config.kcadCachePath, config.internalCopyPath]) {
      if (stored == null || stored.isEmpty) continue;
      try {
        final file = projectId == null
            ? File(stored)
            : await resolveOwnedAsset(projectId, stored);
        if (file == null || !await file.exists()) continue;
        return await _parseCadFile(
          file,
          file.path.split('.').last.toLowerCase(),
        );
      } catch (e) {
        // A broken derived cache can still recover from the exact owned source.
        debugPrint('[ArchitectUnderlayService] CAD snapshot load failed: $e');
      }
    }
    return null;
  }

  Future<DxfDocument> _parseCadFile(File file, String ext) async {
    if (ext == 'kcad') return KcadService.loadKcadFile(file);
    final dxfPath = ext == 'dwg'
        ? await DwgConverterService.convertDwgToDxf(file.uri.toFilePath())
        : file.path;
    // Converted DXFs belong to the shared content cache and may have readers.
    return compute(_parseDxfIsolate, dxfPath);
  }

  /// Imports a raster image file (PNG, JPG, WEBP, BMP) into the project's
  /// internal `underlays/raster/` directory and decodes its [ui.Image].
  Future<ArchitectRasterImportResult> importRasterImageFile({
    required String projectId,
    required String storeyId,
    required File sourceFile,
    ui.Offset initialCenter = ui.Offset.zero,
  }) async {
    final rasterDir = await getRasterUnderlayDir(projectId);
    final fileName = sourceFile.uri.pathSegments.isNotEmpty
        ? sourceFile.uri.pathSegments.last
        : sourceFile.path.split(RegExp(r'[/\\]')).last;
    final id = 'rast_${DateTime.now().millisecondsSinceEpoch}';
    final safeName = _sanitizeFileName(fileName);
    final internalFile = File('${rasterDir.path}/${id}_$safeName');
    if (sourceFile.absolute.path != internalFile.absolute.path) {
      await sourceFile.copy(internalFile.path);
    }

    final bytes = await internalFile.readAsBytes();
    final uiImage = await decodeUiImage(bytes);
    final widthPx = uiImage.width;
    final heightPx = uiImage.height;

    // Default initial span: ~20m wide centered at initialCenter
    final initialMetersPerPx = widthPx > 0 ? (20.0 / widthPx) : 0.01;
    final widthM = widthPx * initialMetersPerPx;
    final heightM = heightPx * initialMetersPerPx;
    final topLeft = ui.Offset(
      initialCenter.dx - widthM / 2.0,
      initialCenter.dy - heightM / 2.0,
    );

    final model = ArchitectRasterUnderlay(
      id: id,
      storeyId: storeyId,
      fileName: fileName,
      internalImagePath: await projectRelativePath(projectId, internalFile),
      imageWidthPx: widthPx,
      imageHeightPx: heightPx,
      position: topLeft,
      metersPerPixel: initialMetersPerPx,
      opacity: 0.55,
    );

    return ArchitectRasterImportResult(model: model, image: uiImage);
  }

  /// Returns the total number of pages in a PDF file.
  Future<int> getPdfPageCount(String pdfPath) async {
    final doc = await PdfDocument.openFile(pdfPath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  /// Renders a specific 1-based [pageNumber] of [pdfFile] at high resolution,
  /// saves it as a PNG inside the project's `underlays/raster/` folder, and returns the underlay.
  Future<ArchitectRasterImportResult> importPdfPageAsRaster({
    required String projectId,
    required String storeyId,
    required File pdfFile,
    int pageNumber = 1,
    ui.Offset initialCenter = ui.Offset.zero,
  }) async {
    final rasterDir = await getRasterUnderlayDir(projectId);
    final fileName = pdfFile.uri.pathSegments.isNotEmpty
        ? pdfFile.uri.pathSegments.last
        : pdfFile.path.split(RegExp(r'[/\\]')).last;

    final ownedPdf = File(
      '${rasterDir.path}/pdf_${DateTime.now().microsecondsSinceEpoch}_$fileName',
    );
    await pdfFile.copy(ownedPdf.path);
    final doc = await PdfDocument.openFile(ownedPdf.path);
    try {
      if (doc.pages.isEmpty) {
        throw const FormatException('PDF has no pages');
      }
      final clampedIndex = (pageNumber - 1).clamp(0, doc.pages.length - 1);
      final page = doc.pages[clampedIndex];

      const renderScale = 2.5;
      final targetWidth = (page.width * renderScale).toInt().clamp(1000, 2600);
      final targetHeight = (page.height * renderScale).toInt().clamp(
        1000,
        3400,
      );

      final pdfImage = await page.render(
        fullWidth: targetWidth.toDouble(),
        fullHeight: targetHeight.toDouble(),
        backgroundColor: 0xFFFFFFFF,
      );
      if (pdfImage == null) {
        throw StateError('Failed to render PDF page');
      }

      try {
        final convertedImage = img.Image.fromBytes(
          width: pdfImage.width,
          height: pdfImage.height,
          bytes: pdfImage.pixels.buffer,
          order: img.ChannelOrder.bgra,
        );
        final pngBytes = Uint8List.fromList(img.encodePng(convertedImage));

        final id = 'rast_pdf_${DateTime.now().millisecondsSinceEpoch}';
        final safeName = _sanitizeFileName(fileName);
        final internalPng = File(
          '${rasterDir.path}/${id}_p${clampedIndex + 1}_$safeName.png',
        );
        await internalPng.writeAsBytes(pngBytes);

        final uiImage = await decodeUiImage(pngBytes);
        final widthPx = uiImage.width;
        final heightPx = uiImage.height;
        final initialMetersPerPx = widthPx > 0 ? (20.0 / widthPx) : 0.01;
        final widthM = widthPx * initialMetersPerPx;
        final heightM = heightPx * initialMetersPerPx;
        final topLeft = ui.Offset(
          initialCenter.dx - widthM / 2.0,
          initialCenter.dy - heightM / 2.0,
        );

        final model = ArchitectRasterUnderlay(
          id: id,
          storeyId: storeyId,
          fileName: '$fileName (p.${clampedIndex + 1})',
          internalImagePath: await projectRelativePath(projectId, internalPng),
          sourcePdfPath: await projectRelativePath(projectId, ownedPdf),
          pdfPageNumber: clampedIndex + 1,
          imageWidthPx: widthPx,
          imageHeightPx: heightPx,
          position: topLeft,
          metersPerPixel: initialMetersPerPx,
          opacity: 0.55,
        );
        return ArchitectRasterImportResult(model: model, image: uiImage);
      } finally {
        pdfImage.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }

  /// Loads and decodes a saved raster underlay image from disk.
  Future<ui.Image?> loadSavedRasterImage(
    ArchitectRasterUnderlay underlay, {
    String? projectId,
  }) async {
    try {
      final file = projectId == null
          ? File(underlay.internalImagePath)
          : await resolveOwnedAsset(projectId, underlay.internalImagePath);
      if (file == null || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await decodeUiImage(bytes);
    } catch (e) {
      debugPrint('[ArchitectUnderlayService] Failed to load raster image: $e');
      return null;
    }
  }

  Future<ui.Image> decodeUiImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}

DxfDocument _parseDxfIsolate(String path) {
  final content = UniversalEncodingService.decodeBytes(
    File(path).readAsBytesSync(),
  );
  return DxfParser.parseString(content).toIsolateSafe();
}

/// Compatibility shell for existing callers. Project snapshots never watch files.
class ArchitectCadFileWatcher {
  final void Function(String storeyId, File externalFile)
  onExternalFileModified;
  ArchitectCadFileWatcher({required this.onExternalFileModified});
  void updateConfigs(Map<String, ArchitectCadUnderlayConfig> configs) {}
  void dispose() {}
}
