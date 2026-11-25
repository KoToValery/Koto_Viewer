// === SECTION: ARCHITECT UNDERLAY & LIVE XREF SERVICE ===

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/services/dwg_reader_service.dart';
import '../../../core/services/universal_encoding_service.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../../bim_projects/services/bim_project_asset_service.dart';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../dxf_viewer/binary/kcad_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../../structural_designer/analysis/structural_underlay_source.dart';
import '../models/architect_underlay_models.dart';

class ArchitectCadImportResult {
  final DxfDocument document;
  final ArchitectCadUnderlayConfig config;

  const ArchitectCadImportResult({
    required this.document,
    required this.config,
  });
}

class ArchitectPreparedCadUnderlay {
  final File source;
  final File _stagedFile;
  final String fileName;
  final int _lastModifiedMs;
  final DxfDocument document;

  const ArchitectPreparedCadUnderlay._(
    this.source,
    this._stagedFile,
    this.fileName,
    this._lastModifiedMs,
    this.document,
  );

  DxfUnit get declaredUnit => DxfUnit.fromCode(document.getInsertionUnits());
  bool get scaleIsEstimated => declaredUnit == DxfUnit.unitless;

  double get suggestedUnitsPerMeter {
    if (!scaleIsEstimated) return 1 / declaredUnit.toMeters;
    final span = document.bounds.longestSide;
    if (span > 500) return 1000;
    if (span > 60) return 100;
    return 1;
  }

  Future<void> dispose() async {
    try {
      await _stagedFile.parent.delete(recursive: true);
    } on FileSystemException catch (error) {
      debugPrint('[ArchitectUnderlayService] CAD preview cleanup: $error');
    }
  }
}

class ArchitectCadImportSelection {
  final ArchitectPreparedCadUnderlay prepared;
  final double unitsPerMeter;
  final bool cadOrientation;
  final ArchitectUnderlayKind? kind;
  final ArchitectTechnicalUnderlayDiscipline discipline;

  const ArchitectCadImportSelection({
    required this.prepared,
    required this.unitsPerMeter,
    required this.cadOrientation,
    this.kind,
    this.discipline = ArchitectTechnicalUnderlayDiscipline.general,
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
      cadOrientation: frame.invertY,
      rotationRad: frame.rotationRadians,
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

  /// Reads a private temporary copy so the preview and committed revision
  /// represent the same bytes even when the external file changes.
  Future<ArchitectPreparedCadUnderlay> prepareCadUnderlay(File source) async {
    final fileName = source.uri.pathSegments.last;
    final extension = fileName.split('.').last.toLowerCase();
    if (!const {'dxf', 'dwg', 'kcad'}.contains(extension)) {
      throw FormatException(extension);
    }
    final directory = await Directory.systemTemp.createTemp('koto_cad_');
    try {
      final staged = await source.copy(
        '${directory.path}/${_sanitizeFileName(fileName)}',
      );
      final document = await _parseCadFile(staged, extension);
      if (!document.entities.any((entity) => !entity.isPaperSpace)) {
        throw const ArchitectEmptyCadUnderlay();
      }
      final stat = await source.stat();
      return ArchitectPreparedCadUnderlay._(
        source,
        staged,
        fileName,
        stat.modified.millisecondsSinceEpoch,
        document,
      );
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// Reload an existing snapshot or import with the automatically suggested scale.
  Future<ArchitectCadImportResult> importOrReloadCadUnderlay({
    required String projectId,
    required String storeyId,
    required File sourceFile,
    ArchitectCadUnderlayConfig? existingConfig,
    String? underlayId,
    bool isSitePlan = false,
    bool preserveExistingOrigin = true,
    bool Function()? isCurrent,
  }) async {
    final prepared = await prepareCadUnderlay(sourceFile);
    try {
      return await commitCadUnderlay(
        projectId: projectId,
        storeyId: storeyId,
        selection: ArchitectCadImportSelection(
          prepared: prepared,
          unitsPerMeter:
              existingConfig?.frame(const BimCoordinateFrame()).unitsPerMeter ??
              prepared.suggestedUnitsPerMeter,
          cadOrientation: existingConfig?.cadOrientation ?? true,
          discipline:
              existingConfig?.discipline ??
              ArchitectTechnicalUnderlayDiscipline.general,
        ),
        existingConfig: existingConfig,
        underlayId: underlayId,
        isSitePlan: isSitePlan,
        preserveExistingOrigin: preserveExistingOrigin,
        isCurrent: isCurrent,
      );
    } finally {
      await prepared.dispose();
    }
  }

  /// Publishes an immutable project-owned revision after preview confirmation.
  Future<ArchitectCadImportResult> commitCadUnderlay({
    required String projectId,
    required String storeyId,
    required ArchitectCadImportSelection selection,
    ArchitectCadUnderlayConfig? existingConfig,
    String? underlayId,
    bool isSitePlan = false,
    bool preserveExistingOrigin = true,
    bool Function()? isCurrent,
  }) async {
    final prepared = selection.prepared;
    final units = selection.unitsPerMeter;
    if (!units.isFinite || units <= 0) {
      throw ArgumentError.value(units, 'unitsPerMeter');
    }
    if (isCurrent?.call() == false) throw const ArchitectStaleCadImport();
    final previousFrame = existingConfig?.frame(const BimCoordinateFrame());
    final frame = BimCoordinateFrame(
      origin:
          preserveExistingOrigin &&
              existingConfig != null &&
              existingConfig.lockOrigin &&
              existingConfig.hasLockedOrigin
          ? previousFrame!.origin
          : prepared.document.bounds.center,
      unitsPerMeter: units,
      invertY: selection.cadOrientation,
      rotationRadians: previousFrame?.rotationRadians ?? 0,
    );

    final cadDir = await getCadUnderlayDir(projectId);
    final revision = await cadDir.createTemp(
      '${_sanitizeFileName(storeyId)}_revision_',
    );
    try {
      final sourceDirectory = await Directory(
        '${revision.path}/source',
      ).create();
      final internalCopy = await prepared._stagedFile.copy(
        '${sourceDirectory.path}/${_sanitizeFileName(prepared.fileName)}',
      );
      final kcadCache = File('${revision.path}/snapshot.kcad');
      String? cachePath;
      try {
        await KcadService.exportKcadFile(prepared.document, kcadCache.path);
        cachePath = await projectRelativePath(projectId, kcadCache);
      } catch (error) {
        debugPrint('[ArchitectUnderlayService] KCAD cache export: $error');
      }

      final resolvedKind =
          selection.kind ??
          existingConfig?.kind ??
          (isSitePlan
              ? ArchitectUnderlayKind.geodetic
              : ArchitectUnderlayKind.technical);
      final resolvedDiscipline = resolvedKind == ArchitectUnderlayKind.geodetic
          ? ArchitectTechnicalUnderlayDiscipline.general
          : selection.discipline;
      final resolvedId =
          existingConfig?.id ??
          underlayId ??
          'cad_${DateTime.now().microsecondsSinceEpoch}';

      final config = ArchitectCadUnderlayConfig(
        id: resolvedId,
        storeyId: storeyId,
        fileName: prepared.fileName,
        externalSourcePath: prepared.source.path,
        internalCopyPath: await projectRelativePath(projectId, internalCopy),
        kcadCachePath: cachePath,
        kind: resolvedKind,
        discipline: resolvedDiscipline,
        lockOrigin: existingConfig?.lockOrigin ?? true,
        lastModifiedMs: prepared._lastModifiedMs,
        lockedCadOriginX: frame.origin.dx,
        lockedCadOriginY: frame.origin.dy,
        unitsPerMeter: units,
        cadOrientation: frame.invertY,
        rotationRad: frame.rotationRadians,
        shareToGroundStoreys: existingConfig?.shareToGroundStoreys ?? false,
        hiddenDxfLayers: existingConfig?.hiddenDxfLayers ?? const {},
        shownDxfLayers: existingConfig?.shownDxfLayers ?? const {},
        opacity: existingConfig?.opacity ?? 0.42,
        useOriginalColors: existingConfig?.useOriginalColors ?? false,
        useOriginalLineweights: existingConfig?.useOriginalLineweights ?? false,
        visible: existingConfig?.visible ?? true,
        maskPolygon: switch (existingConfig?.maskPolygon) {
          final mask? when previousFrame != frame => [
            for (final point in mask)
              frame.toModel(previousFrame!.toCad(point)),
          ],
          final mask => mask,
        },
        maskEnabled: existingConfig?.maskEnabled ?? true,
      );
      if (isCurrent?.call() == false) throw const ArchitectStaleCadImport();
      return ArchitectCadImportResult(
        document: prepared.document,
        config: config,
      );
    } catch (_) {
      await revision.delete(recursive: true);
      rethrow;
    }
  }

  Future<Map<String, ArchitectCadUnderlayConfig>> commitCadUnderlays(
    String projectId,
    Map<String, ArchitectCadImportSelection> selections,
  ) async {
    final configs = <String, ArchitectCadUnderlayConfig>{};
    try {
      for (final entry in selections.entries) {
        final imported = await commitCadUnderlay(
          projectId: projectId,
          storeyId: entry.key,
          selection: entry.value,
        );
        configs[entry.key] = imported.config;
      }
      return configs;
    } catch (_) {
      // These generated revisions have never been referenced by a project.
      for (final config in configs.values) {
        try {
          final source = await resolveOwnedAsset(
            projectId,
            config.internalCopyPath,
            adoptLegacy: false,
          );
          await source?.parent.parent.delete(recursive: true);
        } on FileSystemException catch (error) {
          debugPrint('[ArchitectUnderlayService] CAD revision cleanup: $error');
        }
      }
      rethrow;
    }
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
    if (ext == 'kcad') {
      return StructuralUnderlaySource.original(
        await KcadService.loadKcadFile(file),
      );
    }
    if (ext == 'dwg') return DwgReaderService.read(file.path);
    return compute(_parseDxfIsolate, file.path);
  }

  /// Imports a raster image file (PNG, JPG, WEBP, BMP) into the project's
  /// internal `underlays/raster/` directory and decodes its [ui.Image].
  Future<ArchitectRasterImportResult> importRasterImageFile({
    required String projectId,
    required String storeyId,
    required File sourceFile,
    ui.Offset initialCenter = ui.Offset.zero,
    ArchitectUnderlayKind kind = ArchitectUnderlayKind.technical,
    ArchitectTechnicalUnderlayDiscipline discipline =
        ArchitectTechnicalUnderlayDiscipline.general,
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
      kind: kind,
      discipline: kind == ArchitectUnderlayKind.geodetic
          ? ArchitectTechnicalUnderlayDiscipline.general
          : discipline,
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
    ArchitectUnderlayKind kind = ArchitectUnderlayKind.technical,
    ArchitectTechnicalUnderlayDiscipline discipline =
        ArchitectTechnicalUnderlayDiscipline.general,
  }) async {
    final rasterDir = await getRasterUnderlayDir(projectId);
    final fileName = pdfFile.uri.pathSegments.isNotEmpty
        ? pdfFile.uri.pathSegments.last
        : pdfFile.path.split(RegExp(r'[/\\]')).last;
    final safeName = _sanitizeFileName(fileName);

    final ownedPdf = File(
      '${rasterDir.path}/pdf_${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await pdfFile.copy(ownedPdf.path);
    final doc = await PdfDocument.openFile(ownedPdf.path);
    try {
      if (doc.pages.isEmpty) {
        throw const FormatException('PDF has no pages');
      }
      final clampedIndex = (pageNumber - 1).clamp(0, doc.pages.length - 1);
      final page = doc.pages[clampedIndex];

      // Fit the render budget with one scale so calibration stays uniform.
      final preferredScale = math.max(
        2.5,
        1000 / math.min(page.width, page.height),
      );
      final maxScale = math.min(2600 / page.width, 3400 / page.height);
      final renderScale = math.min(preferredScale, maxScale);
      final targetWidth = math.max(1, (page.width * renderScale).round());
      final targetHeight = math.max(1, (page.height * renderScale).round());

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
          fileName: '$fileName · ${clampedIndex + 1}',
          internalImagePath: await projectRelativePath(projectId, internalPng),
          sourcePdfPath: await projectRelativePath(projectId, ownedPdf),
          pdfPageNumber: clampedIndex + 1,
          imageWidthPx: widthPx,
          imageHeightPx: heightPx,
          position: topLeft,
          metersPerPixel: initialMetersPerPx,
          opacity: 0.55,
          kind: kind,
          discipline: kind == ArchitectUnderlayKind.geodetic
              ? ArchitectTechnicalUnderlayDiscipline.general
              : discipline,
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
  return DxfParser.parseString(
    content,
    preserveSourceLayers: true,
  ).toIsolateSafe();
}

class ArchitectEmptyCadUnderlay implements Exception {
  const ArchitectEmptyCadUnderlay();
}

class ArchitectStaleCadImport implements Exception {
  const ArchitectStaleCadImport();
}
