import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/dxf_models.dart';
import 'kcad_reader.dart';
import 'kcad_writer.dart';

/// Top-level helper function for background isolate deserialization.
DxfDocument _kcadReadIsolate(Uint8List bytes) {
  return KcadReader.read(bytes);
}

/// Top-level helper function for background isolate serialization.
Uint8List _kcadWriteIsolate(DxfDocument doc) {
  return KcadWriter.write(doc, compress: true);
}

/// Service managing `.kcad` binary cache, rapid loading, and file conversions.
class KcadService {
  static const String _cacheFolder = 'dwg_cache';
  static const String _kcadVersion = '_v1';

  /// Returns the corresponding `.kcad` cache file path for a source [sourceFile].
  static Future<String> getCachePath(File sourceFile) async {
    final stat = await sourceFile.stat();
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final fileName = sourceFile.path.split(RegExp(r'[/\\]')).last;
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    final cachedFileName =
        '${baseName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}$_kcadVersion.kcad';
    return '${cacheDir.path}${Platform.pathSeparator}$cachedFileName';
  }

  /// Attempts to load a pre-compiled `.kcad` cache file for [sourceFile].
  /// Returns null if no valid cache exists or if it's corrupted/outdated.
  static Future<DxfDocument?> tryLoadCachedKcad(File sourceFile) async {
    try {
      final cachePath = await getCachePath(sourceFile);
      final cacheFile = File(cachePath);
      if (!await cacheFile.exists() || await cacheFile.length() < 16) {
        return null;
      }

      final sw = Stopwatch()..start();
      final bytes = await cacheFile.readAsBytes();
      final doc = await compute(_kcadReadIsolate, bytes);
      sw.stop();
      debugPrint('KcadService: Loaded binary cache in ${sw.elapsedMilliseconds} ms (${doc.entities.length} entities) -> $cachePath');
      return doc;
    } catch (e, stack) {
      debugPrint('KcadService: Cache hit failed or corrupted: $e\n$stack');
      return null;
    }
  }

  /// Saves [document] to binary `.kcad` cache for [sourceFile] in the background.
  static Future<void> saveKcadCache(File sourceFile, DxfDocument document) async {
    try {
      final cachePath = await getCachePath(sourceFile);
      final cacheFile = File(cachePath);
      final bytes = await compute(_kcadWriteIsolate, document);
      await cacheFile.writeAsBytes(bytes, flush: true);
      debugPrint('KcadService: Saved binary cache (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB) -> $cachePath');
    } catch (e, stack) {
      debugPrint('KcadService: Failed to save binary cache: $e\n$stack');
    }
  }

  /// Loads [file] directly as KCAD if it has `.kcad` extension.
  static Future<DxfDocument> loadKcadFile(File file) async {
    final bytes = await file.readAsBytes();
    return compute(_kcadReadIsolate, bytes);
  }

  /// Exports [document] directly to a standalone `.kcad` file at [outputPath].
  static Future<void> exportKcadFile(DxfDocument document, String outputPath) async {
    final bytes = await compute(_kcadWriteIsolate, document);
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
  }
}
