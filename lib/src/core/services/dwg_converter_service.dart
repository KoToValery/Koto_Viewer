import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:path_provider/path_provider.dart';
import '../errors/app_error_handler.dart';
import 'acadrust_converter_service.dart';

/// Exception thrown when DWG to DXF conversion fails.
class DwgConversionException implements Exception {
  final String message;
  final int? errorCode;

  const DwgConversionException(this.message, {this.errorCode});

  @override
  String toString() =>
      errorCode != null ? '$message (code: $errorCode)' : message;
}

/// Specialized exception thrown when conversion is killed by the OS due to excessive memory usage.
class DwgMemoryLimitException extends DwgConversionException {
  const DwgMemoryLimitException([
    super.message = 'DWG requires excessive memory',
  ]) : super(errorCode: -999);
}

/// Service to handle DWG -> DXF conversion and cache management via acadrust.
class DwgConverterService {
  static const String _cacheFolder = 'dwg_cache';

  /// Also used by the instant-open KCAD path for converted DXF caches.
  static int get cacheVersion => AcadrustConverterService.cacheVersion;

  static int cacheVersionForSource(String sourcePath) => cacheVersion;

  /// Returns true if the native acadrust DWG converter is available.
  static bool get isNativeSupported => AcadrustConverterService.isAvailable;

  /// Converts a DWG file at [dwgPath] to a cached DXF file.
  /// If already converted and the source file has not changed,
  /// returns the cached DXF path immediately.
  static Future<String> convertDwgToDxf(
    String dwgPath, {
    bool forceReconvert = false,
    @visibleForTesting AcadrustProcessRunner? acadrustProcessRunner,
  }) async {
    final dwgFile = File(dwgPath);
    if (!await dwgFile.exists()) {
      throw DwgConversionException('DWG file does not exist: $dwgPath');
    }

    final fingerprint = (await sha256.bind(dwgFile.openRead()).first)
        .toString();
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}$_cacheFolder',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final output = File(
      '${cacheDir.path}${Platform.pathSeparator}${fingerprint}_v$cacheVersion.dxf',
    );
    if (!forceReconvert && await AcadrustConverterService.isCompleteDxf(output)) {
      debugPrint('DwgConverterService: Reusing cached DXF -> ${output.path}');
      return output.path;
    }

    try {
      final bool converted;
      if (Platform.isAndroid) {
        converted = await AcadrustConverterService.convertAndroid(
          input: dwgFile,
          output: output,
        );
      } else {
        final executable = AcadrustConverterService.findExecutable();
        converted =
            executable != null &&
            await AcadrustConverterService.convert(
              executable: executable,
              input: dwgFile,
              output: output,
              processRunner: acadrustProcessRunner,
            );
      }
      if (converted) {
        debugPrint('DwgConverterService: acadrust converted $dwgPath');
        unawaited(pruneCache());
        return output.path;
      }
    } on PlatformException catch (error) {
      if (error.code == 'OOM_KILLED') throw const DwgMemoryLimitException();
      debugPrint(
        'DwgConverterService: acadrust service error: ${error.code}',
      );
    }

    throw const DwgConversionException('Failed to convert DWG file to DXF format.');
  }

  /// Clears temporary converted DXF files from cache.
  static Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}$_cacheFolder',
      );
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'DwgConverterService.clearCache.fs',
      );
      debugPrint('DwgConverterService: Error clearing cache: $e');
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'DwgConverterService.clearCache',
      );
      debugPrint('DwgConverterService: Error clearing cache: $e');
    }
  }

  /// Deletes any cached DXF files that were derived from [dwgPath].
  /// Safe to call even if no cache entry exists.
  static Future<void> clearCacheForFile(String dwgPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}$_cacheFolder',
      );
      if (!await cacheDir.exists()) return;

      final fileName = File(dwgPath).uri.pathSegments.last;
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final source = File(dwgPath);
      final fingerprint = await source.exists()
          ? (await sha256.bind(source.openRead()).first).toString()
          : null;

      // Clear both converter revisions and companion KCAD files, including
      // name-based entries created by older application versions.
      await for (final entity in cacheDir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            (name.startsWith('${baseName}_') ||
                (fingerprint != null && name.startsWith('${fingerprint}_')))) {
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
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'DwgConverterService.clearCacheForFile.fs',
      );
      debugPrint('DwgConverterService: Error clearing cache for $dwgPath: $e');
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'DwgConverterService.clearCacheForFile',
      );
      debugPrint('DwgConverterService: Error clearing cache for $dwgPath: $e');
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
        cacheDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}$_cacheFolder',
        );
      }
      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      final List<({File file, int size, DateTime modified})> entries = [];
      int totalSize = 0;
      int prunedCount = 0;

      await for (final entity in cacheDir.list()) {
        if (entity is File &&
            (entity.path.endsWith('.dxf') || entity.path.endsWith('.kcad'))) {
          try {
            final stat = await entity.stat();
            if (now.difference(stat.modified) > maxAge) {
              await entity.delete();
              prunedCount++;
              continue;
            }
            entries.add((
              file: entity,
              size: stat.size,
              modified: stat.modified,
            ));
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
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'DwgConverterService.pruneCache',
      );
      debugPrint('DwgConverterService: Error pruning cache: $e');
    }
  }
}
