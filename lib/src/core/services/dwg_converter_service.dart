import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
      try {
        final processResult = await Process.run(winExe, [
          '-v0',
          '-y',
          '-o',
          targetDxfPath,
          dwgPath,
        ]);
        if (processResult.exitCode == 0 &&
            await targetDxfFile.exists() &&
            await targetDxfFile.length() > 0) {
          result = 0;
        } else {
          debugPrint(
            'DwgConverterService: dwg2dxf CLI exit ${processResult.exitCode}, stderr: ${processResult.stderr}',
          );
          result = processResult.exitCode != 0 ? processResult.exitCode : -1;
        }
      } catch (e) {
        debugPrint('DwgConverterService: Windows CLI conversion error: $e');
        result = -1;
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
        } catch (_) {}
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
    } catch (e) {
      debugPrint('DwgConverterService: Error clearing cache: $e');
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
