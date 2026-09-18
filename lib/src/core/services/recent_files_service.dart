import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_item.dart';

class RecentFilesService {
  static const String _keyRecentFiles = 'koto_recent_files';
  static const String _legacyKeyRecentFiles = 'koto_recent_pdf_files';
  static const int _maxRecentFiles = 25;

  /// Notifier that triggers whenever recent files are added, removed, or cleared.
  static final ValueNotifier<int> recentFilesNotifier = ValueNotifier<int>(0);

  /// Checks whether a file path points to a temporary extracted archive file.
  /// Used to ensure only the parent archive (ZIP/PCB) is preserved in Recent Files.
  static bool isArchiveExtractedPath(String path) {
    final lower = path.toLowerCase().replaceAll(r'\', '/');
    return lower.contains('/koto_extracted/') ||
        lower.contains('/extracted_') ||
        lower.contains('koto_dicom_') ||
        lower.contains('/zip_temp/');
  }

  static Future<List<PdfItem>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_keyRecentFiles) ??
        prefs.getStringList(_legacyKeyRecentFiles);

    if (jsonList == null) return [];

    final rawList = jsonList.map((item) => PdfItem.fromJson(item)).toList();
    final filtered = rawList
        .where((item) => !item.isImage && !isArchiveExtractedPath(item.path))
        .toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

    // If any legacy extracted subfiles were purged, persist the sanitized list
    if (rawList.length != filtered.length) {
      final sanitizedJson = filtered.map((item) => item.toJson()).toList();
      await prefs.setStringList(_keyRecentFiles, sanitizedJson);
    }

    return filtered;
  }

  static Future<void> addRecentFile(PdfItem newItem) async {
    // Exclude photos/images from recent files list to avoid flooding it
    if (newItem.isImage) {
      return;
    }

    // Exclude files extracted from archives so only the main archive remains in Recent Files
    if (isArchiveExtractedPath(newItem.path)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    List<PdfItem> currentList = await getRecentFiles();

    // Remove if duplicate path exists
    currentList.removeWhere((item) => item.path == newItem.path);

    // Insert at beginning
    currentList.insert(0, newItem);

    // Limit list size
    if (currentList.length > _maxRecentFiles) {
      currentList = currentList.sublist(0, _maxRecentFiles);
    }

    final jsonList = currentList.map((item) => item.toJson()).toList();
    await prefs.setStringList(_keyRecentFiles, jsonList);
    recentFilesNotifier.value++;
  }

  static Future<void> removeRecentFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<PdfItem> currentList = await getRecentFiles();

    currentList.removeWhere((item) => item.path == path);

    final jsonList = currentList.map((item) => item.toJson()).toList();
    await prefs.setStringList(_keyRecentFiles, jsonList);
    recentFilesNotifier.value++;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRecentFiles);
    await prefs.remove(_legacyKeyRecentFiles);
    recentFilesNotifier.value++;
  }
}
