import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/pdf_item.dart';
import 'project_bundle_service.dart';

/// Extracts original DWG sources from presentation bundles in advance.
/// Opening a prepared source uses the native in-memory reader. This service
/// never produces extracted DXF files or serialized KCAD caches.
class ProjectBundlePreloadService {
  ProjectBundlePreloadService._();

  static final Map<String, Completer<String>> _activeExtractions = {};
  static final Set<String> _pendingQueue = {};
  static bool _isProcessing = false;
  static bool _isCancelled = false;

  /// Starts background extraction of DWG files in [bundle].
  /// Processes files sequentially in their defined presentation order.
  static void startPreloading(ProjectBundleInfo bundle) {
    _isCancelled = false;

    // Collect visible DWG files from the bundle for preloading
    final dwgFiles = bundle.files
        .where(
          (f) =>
              !f.isHidden &&
              f.category == ProjectItemCategory.drawing &&
              (f.fileType == KotoFileType.dwg ||
                  f.fileName.toLowerCase().endsWith('.dwg')),
        )
        .toList();

    if (dwgFiles.isEmpty) return;

    for (final file in dwgFiles) {
      if (!_pendingQueue.contains(file.internalPath) &&
          !_activeExtractions.containsKey(file.internalPath)) {
        _pendingQueue.add(file.internalPath);
      }
    }

    _processQueue(bundle.archivePath, bundle.files);
  }

  /// Cancels remaining pending background extractions (e.g. when leaving project screen).
  static void cancel() {
    _isCancelled = true;
    _pendingQueue.clear();
  }

  /// Prioritizes a specific DWG file because the user opened it right now.
  /// Returns a Future that completes with the original DWG file path.
  static Future<String> prioritizeAndExtract(
    String archivePath,
    ProjectFileEntry entry,
  ) async {
    final key = entry.internalPath;

    // 1. If this exact file is currently being extracted in the background, wait for it!
    if (_activeExtractions.containsKey(key)) {
      return _activeExtractions[key]!.future;
    }

    // 2. Remove from pending background queue if it's waiting
    _pendingQueue.remove(key);

    // 3. Convert immediately with priority
    final completer = Completer<String>();
    _activeExtractions[key] = completer;

    try {
      final result = await _extractSingleDwg(archivePath, entry.internalPath);
      completer.complete(result);
      return result;
    } catch (e, stack) {
      completer.completeError(e, stack);
      rethrow;
    } finally {
      _activeExtractions.remove(key);
    }
  }

  /// Internal worker loop that sequentially processes the pending queue.
  static Future<void> _processQueue(
    String archivePath,
    List<ProjectFileEntry> files,
  ) async {
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

        if (_activeExtractions.containsKey(nextInternalPath)) {
          continue; // Already being extracted
        }

        final completer = Completer<String>();
        _activeExtractions[nextInternalPath] = completer;

        try {
          final result = await _extractSingleDwg(archivePath, nextInternalPath);
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
          debugPrint(
            'ProjectBundlePreloadService: Failed background DWG conversion for $nextInternalPath: $e',
          );
        } finally {
          _activeExtractions.remove(nextInternalPath);
        }

        // Small pause between background extractions to yield CPU & battery
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Extracts the original DWG without generating derived files.
  static Future<String> _extractSingleDwg(
    String archivePath,
    String internalPath,
  ) async {
    // 1. Extract DWG on-demand if not already extracted
    final extractedDwgPath = await ProjectBundleService.extractFile(
      archivePath,
      internalPath,
    );
    final dwgFile = File(extractedDwgPath);
    if (!await dwgFile.exists()) {
      throw FileSystemException('Extracted DWG not found', extractedDwgPath);
    }

    // DWG remains the source. Opening it reads native objects directly;
    // archive preparation must not create DXF/KCAD intermediates.
    return extractedDwgPath;
  }
}
