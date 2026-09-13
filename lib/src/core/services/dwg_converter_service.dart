import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../errors/app_error_handler.dart';
import 'libredwg_ffi.dart';

/// Exception thrown when DWG to DXF conversion fails.
class DwgConversionException implements Exception {
  final String message;
  final int? errorCode;

  const DwgConversionException(this.message, {this.errorCode});

  @override
  String toString() =>
      errorCode != null ? '$message (code: $errorCode)' : message;
}

/// Service to handle DWG -> DXF conversion and cache management.
class DwgConverterService {
  static const String _cacheFolder = 'dwg_cache';

  /// Locates the bundled or installed dwg2dxf executable on Windows.
  static String? _findWindowsDwg2DxfExe() {
    if (!Platform.isWindows) return null;

    final candidates = [
      // 1. Next to the running executable (e.g. build/windows/x64/runner/Debug/dwg2dxf.exe or Release)
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}dwg2dxf.exe',
      // 2. In windows/libredwg/bin directory (dev environment)
      '${Directory.current.path}${Platform.pathSeparator}windows${Platform.pathSeparator}libredwg${Platform.pathSeparator}bin${Platform.pathSeparator}dwg2dxf.exe',
    ];

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  /// Locates the bundled or installed dwglayers executable on Windows.
  static String? _findWindowsDwgLayersExe() {
    final dwg2dxf = _findWindowsDwg2DxfExe();
    if (dwg2dxf == null) return null;
    final dwglayers = dwg2dxf.replaceAll('dwg2dxf.exe', 'dwglayers.exe');
    if (File(dwglayers).existsSync()) {
      return dwglayers;
    }
    return null;
  }

  /// Streams content from [sourceFile] to [targetFile], prepending an authentic
  /// DWG layer state metadata comment (group code 999) with constant O(1) memory usage (~64KB buffer).
  static Future<void> _streamToTargetWithComment({
    required File sourceFile,
    required File targetFile,
    String? layerStatesString,
  }) async {
    try {
      final sink = targetFile.openWrite();
      try {
        if (layerStatesString != null && layerStatesString.isNotEmpty) {
          sink.writeln('999');
          sink.writeln('KOTO_DWG_LAYERS:$layerStatesString');
        }
        await sink.addStream(sourceFile.openRead());
        await sink.flush();
      } finally {
        await sink.close();
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService._streamToTargetWithComment.fs');
      debugPrint('DwgConverterService: Failed to stream with comment: $e');
      rethrow;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService._streamToTargetWithComment');
      debugPrint('DwgConverterService: Failed to stream with comment: $e');
      rethrow;
    }
  }

  /// Prepends layer states comment in-place using a temporary sibling file and streaming,
  /// avoiding loading the entire DXF into memory.
  static Future<void> _prependCommentInPlace({
    required File dxfFile,
    required String layerStatesString,
  }) async {
    final tempSibling = File('${dxfFile.path}.tmp_${DateTime.now().microsecondsSinceEpoch}');
    try {
      await _streamToTargetWithComment(
        sourceFile: dxfFile,
        targetFile: tempSibling,
        layerStatesString: layerStatesString,
      );
      if (await dxfFile.exists()) {
        await dxfFile.delete();
      }
      await tempSibling.rename(dxfFile.path);
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService._prependCommentInPlace');
      debugPrint('DwgConverterService: Failed to prepend comment in-place: $e');
      if (await tempSibling.exists()) {
        try {
          await tempSibling.delete();
        } catch (_) {}
      }
    }
  }

  /// Exposed for testing stream-based DXF comment injection.
  @visibleForTesting
  static Future<void> streamToTargetWithComment({
    required File sourceFile,
    required File targetFile,
    String? layerStatesString,
  }) =>
      _streamToTargetWithComment(
        sourceFile: sourceFile,
        targetFile: targetFile,
        layerStatesString: layerStatesString,
      );

  /// Returns a temporary directory guaranteed to use an ASCII path on Windows,
  /// avoiding issues with native C runtimes opening non-ASCII / Cyrillic paths.
  static Directory _getSafeTempDir() {
    if (Platform.isWindows) {
      final publicDir = Platform.environment['PUBLIC'] ??
          Platform.environment['ALLUSERSPROFILE'];
      if (publicDir != null && !RegExp(r'[^\x00-\x7F]').hasMatch(publicDir)) {
        final dir = Directory('$publicDir${Platform.pathSeparator}KotoTemp');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      }
    }
    return Directory.systemTemp;
  }

  /// Returns true if native LibreDWG converter library or CLI tool is loaded and ready.
  static bool get isNativeSupported {
    if (Platform.isWindows) {
      return _findWindowsDwg2DxfExe() != null || LibreDwgFfi.isAvailable;
    }
    return LibreDwgFfi.isAvailable;
  }

  /// Converts a DWG file at [dwgPath] to a cached DXF file.
  /// If already converted and the source file has not changed,
  /// returns the cached DXF path immediately.
  static Future<String> convertDwgToDxf(
    String dwgPath, {
    bool forceReconvert = false,
  }) async {
    final dwgFile = File(dwgPath);
    if (!await dwgFile.exists()) {
      throw DwgConversionException('DWG file does not exist: $dwgPath');
    }

    final stat = await dwgFile.stat();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final fileName = dwgPath.split(Platform.pathSeparator).last;
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // Cache file name includes size, modified timestamp, and engine version for cache validation
    final cachedFileName =
        '${baseName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_v3.dxf';
    final targetDxfPath =
        '${cacheDir.path}${Platform.pathSeparator}$cachedFileName';
    final targetDxfFile = File(targetDxfPath);

    if (!forceReconvert &&
        await targetDxfFile.exists() &&
        await targetDxfFile.length() > 100) {
      debugPrint('DwgConverterService: Reusing cached DXF -> $targetDxfPath');
      return targetDxfPath;
    }

    int result = -1;

    // 1. On Windows: Try using bundled dwg2dxf CLI tool
    final winExe = _findWindowsDwg2DxfExe();
    if (winExe != null) {
      File? tempInputFile;
      File? tempOutputFile;
      try {
        String effectiveInputPath = dwgPath;
        String effectiveOutputPath = targetDxfPath;

        // dwg2dxf.exe (MinGW C runtime) fails with READ ERROR 0x1000 on non-ASCII/Cyrillic paths.
        // Stage through a safe ASCII path if any path contains non-ASCII characters or spaces.
        final bool needsStaging =
            RegExp(r'[^\x00-\x7F]').hasMatch(dwgPath) ||
            RegExp(r'[^\x00-\x7F]').hasMatch(targetDxfPath) ||
            dwgPath.contains(' ') ||
            targetDxfPath.contains(' ');

        if (needsStaging) {
          final safeDir = _getSafeTempDir();
          final uniqueId = DateTime.now().microsecondsSinceEpoch;
          final safeInPath =
              '${safeDir.path}${Platform.pathSeparator}dwg_in_$uniqueId.dwg';
          final safeOutPath =
              '${safeDir.path}${Platform.pathSeparator}dwg_out_$uniqueId.dxf';

          await dwgFile.copy(safeInPath);
          tempInputFile = File(safeInPath);
          tempOutputFile = File(safeOutPath);

          effectiveInputPath = safeInPath;
          effectiveOutputPath = safeOutPath;
        }

        final processResult = await Process.run(winExe, [
          '-v0',
          '-y',
          '-o',
          effectiveOutputPath,
          effectiveInputPath,
        ]);

        final outResultFile = File(effectiveOutputPath);
        if (processResult.exitCode == 0 &&
            await outResultFile.exists() &&
            await outResultFile.length() > 0) {
          // Extract authentic layer states directly from the DWG file
          String? layerStatesString;
          final layersExe = _findWindowsDwgLayersExe();
          if (layersExe != null) {
            try {
              final layersRes = await Process.run(layersExe, ['-f', effectiveInputPath]);
              if (layersRes.exitCode == 0 && layersRes.stdout is String) {
                final lines = LineSplitter.split(layersRes.stdout as String);
                final List<String> encodedStates = [];
                for (final line in lines) {
                  final match = RegExp(r'^([ f])([+\-])([ l])\s+(.+)$').firstMatch(line.trimRight());
                  if (match != null) {
                    final isFrozen = match.group(1) == 'f';
                    final isOff = match.group(2) == '-';
                    final layerName = match.group(4)!.trim();
                    if (layerName.isNotEmpty) {
                      final flag = isFrozen
                          ? (isOff ? 'f-' : 'f+')
                          : (isOff ? '-' : '+');
                      encodedStates.add('$layerName=$flag');
                    }
                  }
                }
                if (encodedStates.isNotEmpty) {
                  layerStatesString = encodedStates.join(';');
                }
              }
            } on ProcessException catch (e, stack) {
              AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.dwglayers.process');
              debugPrint('DwgConverterService: dwglayers process error: $e');
            } on Exception catch (e, stack) {
              AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.dwglayers');
              debugPrint('DwgConverterService: dwglayers extraction error: $e');
            }
          }

          if (needsStaging) {
            // Stream outResultFile (in KotoTemp) directly to targetDxfPath (in cache)
            // with layer states comment prepended, using constant O(1) memory.
            await _streamToTargetWithComment(
              sourceFile: outResultFile,
              targetFile: File(targetDxfPath),
              layerStatesString: layerStatesString,
            );
          } else if (layerStatesString != null && layerStatesString.isNotEmpty) {
            await _prependCommentInPlace(
              dxfFile: outResultFile,
              layerStatesString: layerStatesString,
            );
          }
          result = 0;
        } else {
          debugPrint(
            'DwgConverterService: dwg2dxf CLI exit ${processResult.exitCode}, stderr: ${processResult.stderr}',
          );
          result = processResult.exitCode != 0 ? processResult.exitCode : -1;
        }
      } on ProcessException catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.cli.process');
        debugPrint('DwgConverterService: Windows CLI process error: $e');
        result = -1;
      } on FileSystemException catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.cli.fs');
        debugPrint('DwgConverterService: Windows CLI file error: $e');
        result = -1;
      } on Exception catch (e, stack) {
        AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.cli');
        debugPrint('DwgConverterService: Windows CLI conversion error: $e');
        result = -1;
      } finally {
        if (tempInputFile != null && await tempInputFile.exists()) {
          try {
            await tempInputFile.delete();
          } on FileSystemException catch (_) {
            // Best effort temp cleanup
          } on Exception catch (_) {
            // Best effort temp cleanup
          }
        }
        if (tempOutputFile != null && await tempOutputFile.exists()) {
          try {
            await tempOutputFile.delete();
          } on FileSystemException catch (_) {
            // Best effort temp cleanup
          } on Exception catch (_) {
            // Best effort temp cleanup
          }
        }
      }
    }

    // 2. Fallback to Isolate FFI conversion (Android, Linux, or if FFI DLL is loaded)
    if (result != 0 && LibreDwgFfi.isAvailable) {
      final params = _ConversionParams(
        inputDwgPath: dwgPath,
        outputDxfPath: targetDxfPath,
      );
      result = await compute(_runConversionInIsolate, params);
    }

    if (result != 0) {
      // Clean up partially written file
      if (await targetDxfFile.exists()) {
        try {
          await targetDxfFile.delete();
        } on FileSystemException catch (_) {
          // Best effort target cleanup
        } on Exception catch (_) {
          // Best effort target cleanup
        }
      }
      throw DwgConversionException(
        'Failed to convert DWG file to DXF format.',
        errorCode: result,
      );
    }

    if (!await targetDxfFile.exists() || await targetDxfFile.length() == 0) {
      throw const DwgConversionException(
        'Conversion completed but the output DXF file is empty.',
      );
    }

    debugPrint('DwgConverterService: Converted $dwgPath -> $targetDxfPath');

    // Run cache pruning asynchronously in background so cache stays bounded
    unawaited(pruneCache());

    return targetDxfPath;
  }

  /// Clears temporary converted DXF files from cache.
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.clearCache.fs');
      debugPrint('DwgConverterService: Error clearing cache: $e');
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.clearCache');
      debugPrint('DwgConverterService: Error clearing cache: $e');
    }
  }

  /// Deletes any cached DXF files that were derived from [dwgPath].
  /// Safe to call even if no cache entry exists.
  static Future<void> clearCacheForFile(String dwgPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
      if (!await cacheDir.exists()) return;

      final fileName = dwgPath.split(Platform.pathSeparator).last;
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      // Delete all cache entries whose name starts with this base name
      // (they encode size + timestamp in the filename, so there may be stale versions).
      await for (final entity in cacheDir.list()) {
        if (entity is File && entity.uri.pathSegments.last.startsWith('${baseName}_')) {
          try {
            await entity.delete();
            debugPrint('DwgConverterService: Deleted cache for $baseName');
          } on FileSystemException catch (_) {
            // Best effort cache file deletion
          } on Exception catch (_) {
            // Best effort cache file deletion
          }
        }
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.clearCacheForFile.fs');
      debugPrint('DwgConverterService: Error clearing cache for $dwgPath: $e');
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.clearCacheForFile');
      debugPrint('DwgConverterService: Error clearing cache for $dwgPath: $e');
    }
  }

  /// Cleans up orphaned intermediate files left behind in the safe temp directory
  /// (e.g. C:\Users\Public\KotoTemp) due to prior app crashes, hard kills, or aborted conversions.
  /// If [isStartup] is true, deletes all orphaned dwg_in_* and dwg_out_* files.
  /// Otherwise, deletes only files older than [olderThan].
  static Future<void> cleanupStaleTempFiles({
    Duration olderThan = const Duration(minutes: 30),
    bool isStartup = false,
    @visibleForTesting Directory? customTempDir,
  }) async {
    try {
      final safeDir = customTempDir ?? _getSafeTempDir();
      if (!await safeDir.exists()) return;

      final now = DateTime.now();
      int deletedCount = 0;
      await for (final entity in safeDir.list()) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          if (fileName.startsWith('dwg_in_') || fileName.startsWith('dwg_out_')) {
            bool shouldDelete = isStartup;
            if (!shouldDelete) {
              try {
                final stat = await entity.stat();
                if (now.difference(stat.modified) > olderThan) {
                  shouldDelete = true;
                }
              } on FileSystemException catch (_) {
                // If stat fails, skip
              }
            }
            if (shouldDelete) {
              try {
                await entity.delete();
                deletedCount++;
              } on FileSystemException catch (_) {
                // Best effort deletion
              }
            }
          }
        }
      }
      if (deletedCount > 0) {
        debugPrint('DwgConverterService: Cleaned up $deletedCount stale temp files from ${safeDir.path}');
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.cleanupStaleTempFiles');
      debugPrint('DwgConverterService: Error cleaning stale temp files: $e');
    }
  }

  /// Prunes the DWG conversion cache by removing files older than [maxAge]
  /// and ensuring total cache size does not exceed [maxSizeBytes] (LRU eviction).
  static Future<void> pruneCache({
    int maxSizeBytes = 300 * 1024 * 1024, // 300 MB default
    Duration maxAge = const Duration(days: 7), // 7 days default
    @visibleForTesting Directory? customCacheDir,
  }) async {
    try {
      Directory cacheDir;
      if (customCacheDir != null) {
        cacheDir = customCacheDir;
      } else {
        final tempDir = await getTemporaryDirectory();
        cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
      }
      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      final List<({File file, int size, DateTime modified})> entries = [];
      int totalSize = 0;
      int prunedCount = 0;

      await for (final entity in cacheDir.list()) {
        if (entity is File && entity.path.endsWith('.dxf')) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete();
              prunedCount++;
              continue;
            }
            entries.add((file: entity, size: stat.size, modified: stat.modified));
            totalSize += stat.size;
          } on FileSystemException catch (_) {
            // Skip unreadable files
          }
        }
      }

      if (totalSize > maxSizeBytes) {
        // Sort by modified ascending (oldest modified first -> LRU eviction)
        entries.sort((a, b) => a.modified.compareTo(b.modified));
        for (final entry in entries) {
          if (totalSize <= maxSizeBytes) break;
          try {
            await entry.file.delete();
            totalSize -= entry.size;
            prunedCount++;
          } on FileSystemException catch (_) {
            // Best effort
          }
        }
      }

      if (prunedCount > 0) {
        debugPrint(
          'DwgConverterService: Pruned $prunedCount cache files, remaining size: ${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB',
        );
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'DwgConverterService.pruneCache');
      debugPrint('DwgConverterService: Error pruning cache: $e');
    }
  }
}

class _ConversionParams {
  final String inputDwgPath;
  final String outputDxfPath;

  _ConversionParams({
    required this.inputDwgPath,
    required this.outputDxfPath,
  });
}

int _runConversionInIsolate(_ConversionParams params) {
  return LibreDwgFfi.convert(params.inputDwgPath, params.outputDxfPath);
}
