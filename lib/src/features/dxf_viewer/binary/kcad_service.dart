import 'dart:io';
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

  /// Dynamically derived from KcadWriter.currentVersion to guarantee 0% version desync!
  static String get _kcadVersion => '_v${KcadWriter.currentVersion}';

  /// Returns the corresponding `.kcad` cache file path.
  /// If [originalFile] is provided (e.g. the original DWG before conversion to DXF),
  /// the cache is keyed to the original file's size and modification time for 100% stable caching!
  static Future<String> getCachePath(File sourceFile, {File? originalFile}) async {
    final effectiveSource = (originalFile != null && await originalFile.exists())
        ? originalFile
        : sourceFile;

    final stat = await effectiveSource.stat();
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

    final fileName = effectiveSource.path.split(RegExp(r'[/\\]')).last;
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    // If sourceFile is an internal converted DXF from DwgConverterService (e.g. +9.30 (OVK)_7275639_1790145006000_v6.dxf),
    // its filename already encodes the source DWG size and mtime!
    // Storing it as companion .kcad prevents double-hashing ephemeral DXF timestamps!
    if (originalFile == null &&
        sourceFile.path.toLowerCase().endsWith('.dxf') &&
        RegExp(r'_\d+_\d+_v\d+$', caseSensitive: false).hasMatch(baseName)) {
      final cleanBase = baseName.replaceAll(RegExp(r'_v\d+$', caseSensitive: false), '');
      return '${cacheDir.path}${Platform.pathSeparator}$cleanBase$_kcadVersion.kcad';
    }

    final cachedFileName =
        '${baseName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}$_kcadVersion.kcad';
    return '${cacheDir.path}${Platform.pathSeparator}$cachedFileName';
  }

  /// Attempts to load a pre-compiled `.kcad` cache file for [sourceFile] / [originalFile].
  /// Returns null if no valid cache exists or if it's corrupted/outdated.
  static Future<DxfDocument?> tryLoadCachedKcad(File sourceFile, {File? originalFile}) async {
    try {
      final cachePath = await getCachePath(sourceFile, originalFile: originalFile);
      final cacheFile = File(cachePath);
      if (!await cacheFile.exists()) {
        return null;
      }
      final fileLength = await cacheFile.length();
      if (fileLength < 16) {
        return null;
      }

      // Fast synchronous header pre-check (6 bytes): verify magic & version before spawning isolate!
      final raf = await cacheFile.open(mode: FileMode.read);
      try {
        final headerBytes = await raf.read(6);
        if (headerBytes.length < 6 ||
            headerBytes[0] != 0x4B ||
            headerBytes[1] != 0x43 ||
            headerBytes[2] != 0x41 ||
            headerBytes[3] != 0x44) {
          return null; // Corrupted or not a KCAD file
        }
        final version = headerBytes[4] | (headerBytes[5] << 8);
        if (version != KcadWriter.currentVersion) {
          debugPrint('KcadService: Stale cache version $version != ${KcadWriter.currentVersion}, invalidating.');
          return null; // Stale version, fast fail without isolate cost!
        }
      } finally {
        await raf.close();
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

  /// Saves [document] to binary `.kcad` cache for [sourceFile] / [originalFile] in the background.
  /// Uses atomic write (temp file + rename) to guarantee 0% corrupted/truncated files on process kill.
  static Future<void> saveKcadCache(
    File sourceFile,
    DxfDocument document, {
    File? originalFile,
  }) async {
    File? tmpFile;
    try {
      final cachePath = await getCachePath(sourceFile, originalFile: originalFile);
      final cacheFile = File(cachePath);
      final tmpPath = '$cachePath.tmp_${DateTime.now().microsecondsSinceEpoch}';
      tmpFile = File(tmpPath);

      final bytes = await compute(_kcadWriteIsolate, document);
      await tmpFile.writeAsBytes(bytes, flush: true);

      // Atomic rename on the same filesystem
      await tmpFile.rename(cacheFile.path);
      debugPrint('KcadService: Saved binary cache (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB) -> $cachePath');

      // Eviction: Clean up any older/stale .kcad files for this base drawing
      _evictStaleKcadFiles(cacheFile);
    } catch (e, stack) {
      debugPrint('KcadService: Failed to save binary cache: $e\n$stack');
      if (tmpFile != null && await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Evicts older .kcad cache files for the same drawing base name.
  static void _evictStaleKcadFiles(File currentCacheFile) {
    try {
      final parentDir = currentCacheFile.parent;
      final currentName = currentCacheFile.path.split(RegExp(r'[/\\]')).last;
      final match = RegExp(r'^(.*)_\d+_\d+_v\d+\.kcad$', caseSensitive: false).firstMatch(currentName);
      if (match == null) return;
      final basePrefix = '${match.group(1)}_';

      parentDir.list().listen((entity) {
        if (entity is File && entity.path.endsWith('.kcad')) {
          final name = entity.path.split(RegExp(r'[/\\]')).last;
          if (name != currentName && name.startsWith(basePrefix)) {
            try {
              entity.deleteSync();
              debugPrint('KcadService: Evicted stale cache version -> ${entity.path}');
            } catch (_) {}
          }
        }
      });
    } catch (_) {
      // Best-effort cleanup
    }
  }

  /// Loads [file] directly as KCAD if it has `.kcad` extension.
  static Future<DxfDocument> loadKcadFile(File file) async {
    final sw = Stopwatch()..start();
    final bytes = await file.readAsBytes();
    final doc = await compute(_kcadReadIsolate, bytes);
    sw.stop();
    debugPrint('KcadService: Loaded binary file in ${sw.elapsedMilliseconds} ms (${doc.entities.length} entities) -> ${file.path}');
    return doc;
  }

  /// Exports [document] directly to a standalone `.kcad` file at [outputPath].
  static Future<void> exportKcadFile(DxfDocument document, String outputPath) async {
    final bytes = await compute(_kcadWriteIsolate, document);
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
  }
}
