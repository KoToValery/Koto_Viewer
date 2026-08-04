import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_item.dart';
import 'recent_files_service.dart';

enum FileSourceMode { recent, custom }

extension FileSourceModeExtension on FileSourceMode {
  String get key {
    switch (this) {
      case FileSourceMode.recent:
        return 'recent';
      case FileSourceMode.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case FileSourceMode.recent:
        return 'Recent Files';
      case FileSourceMode.custom:
        return 'Custom Folder';
    }
  }

  static FileSourceMode fromKey(String? key) {
    switch (key) {
      case 'custom':
        return FileSourceMode.custom;
      case 'recent':
      default:
        return FileSourceMode.recent;
    }
  }
}

enum SortOption { date, name }

extension SortOptionExtension on SortOption {
  String get key {
    switch (this) {
      case SortOption.date:
        return 'date';
      case SortOption.name:
        return 'name';
    }
  }

  static SortOption fromKey(String? key) {
    switch (key) {
      case 'name':
        return SortOption.name;
      case 'date':
      default:
        return SortOption.date;
    }
  }
}

class FileSourceService {
  static const String _keySourceMode = 'koto_file_source_mode';
  static const String _keyCustomPath = 'koto_custom_folder_path';
  static const String _keySortOption = 'koto_sort_option';

  static Future<FileSourceMode> getSourceMode() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keySourceMode);
    return FileSourceModeExtension.fromKey(key);
  }

  static Future<void> setSourceMode(FileSourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySourceMode, mode.key);
  }

  static Future<String?> getCustomFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomPath);
  }

  static Future<void> setCustomFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPath, path);
  }

  static Future<SortOption> getSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keySortOption);
    return SortOptionExtension.fromKey(key);
  }

  static Future<void> setSortOption(SortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySortOption, option.key);
  }

  static Future<List<PdfItem>> getPdfFilesForCurrentSource() async {
    final mode = await getSourceMode();
    List<PdfItem> files = [];

    switch (mode) {
      case FileSourceMode.recent:
        files = await RecentFilesService.getRecentFiles();
        break;
      case FileSourceMode.custom:
        final customPath = await getCustomFolderPath();
        if (customPath != null && customPath.isNotEmpty) {
          final customDir = Directory(customPath);
          files = await _scanDirectoryForPdfs(customDir);
        }
        break;
    }

    return await _sortFiles(files);
  }

  static Future<List<PdfItem>> _sortFiles(List<PdfItem> files) async {
    final sortOption = await getSortOption();
    if (sortOption == SortOption.name) {
      files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // sort by date descending
      files.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    }
    return files;
  }

  static Future<List<PdfItem>> _scanDirectoryForPdfs(Directory dir) async {
    if (!dir.existsSync()) return [];

    final List<PdfItem> pdfItems = [];
    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final stat = entity.statSync();
          final fileName = entity.path.split(Platform.pathSeparator).last;
          pdfItems.add(
            PdfItem(
              path: entity.path,
              name: fileName,
              sizeInBytes: stat.size,
              lastOpened: stat.modified,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory ${dir.path}: $e');
    }
    return pdfItems;
  }
}
