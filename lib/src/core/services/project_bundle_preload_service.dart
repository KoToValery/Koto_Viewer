import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../features/dxf_viewer/binary/kcad_service.dart';
import '../../features/dxf_viewer/parser/dxf_parser.dart';
import '../models/pdf_item.dart';
import 'dwg_converter_service.dart';
import 'project_bundle_service.dart';

/// Background pre-conversion and caching service for DWG files in presentation bundles.
///
/// Converts DWG files sequentially to KCAD binary format in the background so that
/// when the user reaches them in the presentation, they load instantly (~50ms)
/// without conversion or parsing delays.
///
/// If the user attempts to open a DWG that has not finished converting yet,
/// it is immediately promoted to top priority and awaited without duplicating work.
class ProjectBundlePreloadService {
  ProjectBundlePreloadService._();

  static final Map<String, Completer<String>> _activeConversions = {};
  static final Set<String> _pendingQueue = {};
  static bool _isProcessing = false;
  static bool _isCancelled = false;

  /// Starts background pre-conversion of DWG files in [bundle].
  /// Processes files sequentially in their defined presentation order.
  static void startPreloading(ProjectBundleInfo bundle) {
    _isCancelled = false;

    // Collect visible DWG files from the bundle for preloading
    final dwgFiles = bundle.files.where((f) =>
      !f.isHidden &&
      f.category == ProjectItemCategory.drawing &&
      (f.fileType == KotoFileType.dwg || f.fileName.toLowerCase().endsWith('.dwg'))
    ).toList();

    if (dwgFiles.isEmpty) return;

    for (final file in dwgFiles) {
      if (!_pendingQueue.contains(file.internalPath) &&
          !_activeConversions.containsKey(file.internalPath)) {
        _pendingQueue.add(file.internalPath);
      }
    }

    _processQueue(bundle.archivePath, bundle.files);
  }

  /// Cancels remaining pending background conversions (e.g. when leaving project screen).
  static void cancel() {
    _isCancelled = true;
    _pendingQueue.clear();
  }

  /// Prioritizes a specific DWG file because the user opened it right now.
  /// Returns a Future that completes with the ready DXF or KCAD file path.
  static Future<String> prioritizeAndConvert(
    String archivePath,
    ProjectFileEntry entry,
  ) async {
    final key = entry.internalPath;

    // 1. If this exact file is currently being converted in the background, wait for it!
    if (_activeConversions.containsKey(key)) {
      return _activeConversions[key]!.future;
    }

    // 2. Remove from pending background queue if it's waiting
    _pendingQueue.remove(key);

    // 3. Convert immediately with priority
    final completer = Completer<String>();
    _activeConversions[key] = completer;

    try {
      final result = await _convertSingleDwg(archivePath, entry.internalPath);
      completer.complete(result);
      return result;
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _activeConversions.remove(key);
    }
  }

  /// Internal worker loop that sequentially processes the pending queue.
  static Future<void> _processQueue(String archivePath, List<ProjectFileEntry> files) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_pendingQueue.isNotEmpty && !_isCancelled) {
        // Find next item according to current presentation order
        String? nextInternalPath;
        for (final file in files) {
          if (_pendingQueue.contains(file.internalPath)) {
            nextInternalPath = file.internalPath;
            break;
          }
        }
        nextInternalPath ??= _pendingQueue.first;
        _pendingQueue.remove(nextInternalPath);

        if (_activeConversions.containsKey(nextInternalPath)) {
          continue; // Already being converted
        }

        final completer = Completer<String>();
        _activeConversions[nextInternalPath] = completer;

        try {
          final result = await _convertSingleDwg(archivePath, nextInternalPath);
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
          debugPrint('ProjectBundlePreloadService: Failed background DWG conversion for $nextInternalPath: $e');
        } finally {
          _activeConversions.remove(nextInternalPath);
        }

        // Small pause between background conversions to yield CPU & battery
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Extracts, converts DWG to DXF, and generates KCAD binary cache for a single DWG.
  static Future<String> _convertSingleDwg(String archivePath, String internalPath) async {
    // 1. Extract DWG on-demand if not already extracted
    final extractedDwgPath = await ProjectBundleService.extractFile(archivePath, internalPath);
    final dwgFile = File(extractedDwgPath);
    if (!await dwgFile.exists()) {
      throw FileSystemException('Extracted DWG not found', extractedDwgPath);
    }

    // 2. Check if .kcad cache already exists for this DWG
    final kcadPath = await KcadService.getCachePath(dwgFile);
    final kcadFile = File(kcadPath);
    if (await kcadFile.exists() && await kcadFile.length() > 16) {
      // Already fully cached in KCAD!
      return kcadPath;
    }

    // 3. Convert DWG -> DXF
    final dxfPath = await DwgConverterService.convertDwgToDxf(extractedDwgPath);
    if (dxfPath.isEmpty) {
      throw DwgConversionException('Could not convert DWG to DXF: $extractedDwgPath');
    }

    // 4. Parse DXF and generate .kcad binary cache in background isolate
    final dxfFile = File(dxfPath);
    final doc = await DxfParser.parseFromFile(dxfFile, originalFile: dwgFile);
    await KcadService.saveKcadCache(dxfFile, doc, originalFile: dwgFile);

    // Return the kcadPath if generated, or dxfPath
    if (await kcadFile.exists() && await kcadFile.length() > 16) {
      return kcadPath;
    }
    return dxfPath;
  }
}
