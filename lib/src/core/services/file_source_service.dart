import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_item.dart';
import '../l10n/l10n_extensions.dart';
import 'recent_files_service.dart';
import 'android_saf_service.dart';

enum FileSourceMode { recent, custom }

extension FileSourceModeExtension on FileSourceMode {
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case FileSourceMode.recent:
        return l10n.recentFiles;
      case FileSourceMode.custom:
        return l10n.customFolder;
    }
  }

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
  String localizedLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case SortOption.date:
        return l10n.sortByDate;
      case SortOption.name:
        return l10n.sortByName;
    }
  }

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
  static const String _keyCustomFolders = 'koto_custom_folder_list';
  static const String _keyCustomFolderNames = 'koto_custom_folder_names';
  static const String _keySortOption = 'koto_sort_option';
  static const String _keyIncludeSubfolders = 'koto_include_subfolders';

  static Future<FileSourceMode> getSourceMode() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keySourceMode);
    return FileSourceModeExtension.fromKey(key);
  }

  static Future<void> setSourceMode(FileSourceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySourceMode, mode.key);
  }

  static Future<List<String>> getCustomFolderList() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyCustomFolders) ?? [];
    // Migration check: If list is empty but single custom path exists, initialize list
    final singlePath = prefs.getString(_keyCustomPath);
    if (list.isEmpty && singlePath != null && singlePath.isNotEmpty) {
      list.add(singlePath);
      await prefs.setStringList(_keyCustomFolders, list);
    }
    return list;
  }

  static Future<Map<String, String>> getCustomFolderNames() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCustomFolderNames);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setCustomFolderName(String path, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await getCustomFolderNames();
    map[path] = name;
    await prefs.setString(_keyCustomFolderNames, jsonEncode(map));
  }

  static Future<void> saveCustomFolderNames(Map<String, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await getCustomFolderNames();
    map.addAll(names);
    await prefs.setString(_keyCustomFolderNames, jsonEncode(map));
  }

  static Future<void> addCustomFolder(String path, {String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyCustomFolders) ?? [];
    if (!list.contains(path)) {
      list.add(path);
      await prefs.setStringList(_keyCustomFolders, list);
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await setCustomFolderName(path, displayName.trim());
    }
    await prefs.setString(_keyCustomPath, path);
    await prefs.setString(_keySourceMode, FileSourceMode.custom.key);
  }

  static Future<void> removeCustomFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyCustomFolders) ?? [];
    list.remove(path);
    await prefs.setStringList(_keyCustomFolders, list);

    final map = await getCustomFolderNames();
    if (map.containsKey(path)) {
      map.remove(path);
      await prefs.setString(_keyCustomFolderNames, jsonEncode(map));
    }

    final currentActive = prefs.getString(_keyCustomPath);
    if (currentActive == path) {
      if (list.isNotEmpty) {
        await prefs.setString(_keyCustomPath, list.first);
      } else {
        await prefs.remove(_keyCustomPath);
        await prefs.setString(_keySourceMode, FileSourceMode.recent.key);
      }
    }
  }

  static Future<void> setSelectedCustomFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomPath, path);
    await prefs.setString(_keySourceMode, FileSourceMode.custom.key);
  }

  static Future<String?> getCustomFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomPath);
  }

  static Future<void> setCustomFolderPath(String path) async {
    await addCustomFolder(path);
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

  static Future<bool> getIncludeSubfolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIncludeSubfolders) ?? false;
  }

  static Future<void> setIncludeSubfolders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIncludeSubfolders, value);
  }

  static final Set<String> _supportedExtensions = {
    // Documents & eBooks
    'pdf', 'epub', 'fb2', 'cbz', 'cbr', 'cbt', 'docx', 'pptx', 'ppsx', 'ppt', 'pps', 'rtf', 'txt', 'log', 'md', 'markdown',
    // Spreadsheets & Data
    'xlsx', 'xls', 'csv', 'tsv', 'ipynb',
    // CAD & 3D
    'dxf', 'dwg', 'svg', 'stl', 'obj', 'gltf', 'glb', 'fbx', '3mf', 'step', 'stp', 'p21', 'iges', 'igs', 'ifc',
    // Vector & Graphic
    'eps', 'cdr', 'zip', 'psd', 'psb', 'ico', 'lottie',
    // Raster Images
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp',
    // PCB & Hardware
    'kicad_pcb', 'kicad_sch', 'kicad_sym', 'sch', 'brd', 'plt', 'hpgl', 'hpg', 'prn',
    'gbr', 'ger', 'pho', 'art', 'gtl', 'gbl', 'gts', 'gbs', 'gto', 'gbo', 'gko', 'gm1', 'gm2',
    'drl', 'xln', 'exc', 'drd', 'top', 'bot', 'smt', 'smb', 'sst', 'ssb', 'edge',
    // GIS / Maps
    'gpx', 'kml', 'kmz', 'geojson',
    // Fonts & Medical
    'ttf', 'otf', 'dcm', 'dicom',
    // Code files
    'dart', 'js', 'mjs', 'ts', 'tsx', 'py', 'pyw', 'java', 'kt', 'kts', 'swift',
    'cpp', 'cc', 'cxx', 'c', 'h', 'hpp', 'cs', 'go', 'rs', 'php', 'rb',
    'sh', 'bash', 'ps1', 'css', 'html', 'htm', 'json', 'xml', 'yaml', 'yml',
    'toml', 'ini', 'env', 'sql', 'proto',
  };

  static bool isSupportedFile(String path) {
    final rawName = path.contains('/')
        ? path.split('/').where((s) => s.isNotEmpty).last
        : (path.contains(Platform.pathSeparator)
            ? path.split(Platform.pathSeparator).last
            : path);
    final nameLower = rawName.toLowerCase();

    // --- Docker files & exact filenames ---
    if (nameLower == 'dockerfile' ||
        nameLower.startsWith('dockerfile.') ||
        nameLower.endsWith('.dockerfile') ||
        nameLower == '.dockerignore' ||
        nameLower == 'docker-compose.yml' ||
        nameLower == 'docker-compose.yaml' ||
        (nameLower.startsWith('docker-compose.') &&
            (nameLower.endsWith('.yml') || nameLower.endsWith('.yaml')))) {
      return true;
    }

    final dotIndex = nameLower.lastIndexOf('.');
    if (dotIndex == -1) return false;
    final ext = nameLower.substring(dotIndex + 1);
    if (_supportedExtensions.contains(ext)) return true;

    // Double extension check (e.g. .fb2.zip)
    if (nameLower.endsWith('.fb2.zip')) return true;

    return false;
  }

  static List<String> getSafePublicDirectoryPaths() {
    final List<String> paths = [];

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) paths.add(downloadDir.path);

      final docDir = Directory('/storage/emulated/0/Documents');
      if (docDir.existsSync()) paths.add(docDir.path);
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloadDir = Directory('$userProfile\\Downloads');
        if (downloadDir.existsSync()) paths.add(downloadDir.path);

        final docDir = Directory('$userProfile\\Documents');
        if (docDir.existsSync()) paths.add(docDir.path);
      }
    }

    return paths;
  }

  static Future<List<PdfItem>> getPdfFilesForCurrentSource() async {
    final mode = await getSourceMode();
    List<PdfItem> files = [];

    switch (mode) {
      case FileSourceMode.recent:
        final rawFiles = await RecentFilesService.getRecentFiles();
        files = rawFiles.where((item) => File(item.path).existsSync()).toList();
        break;

      case FileSourceMode.custom:
        final customPath = await getCustomFolderPath();
        final includeSubfolders = await getIncludeSubfolders();
        if (customPath != null && customPath.isNotEmpty) {
          // On Android, FilePicker.getDirectoryPath() returns a SAF content URI.
          // Dart's Directory cannot access content:// URIs — use the native SAF API.
          if (Platform.isAndroid && customPath.startsWith('content://')) {
            files = await _scanSafFolderForFiles(customPath, recursive: includeSubfolders);
          } else {
            files = await _scanDirectoryForFiles(Directory(customPath), recursive: includeSubfolders);
          }
        } else {
          final publicPaths = getSafePublicDirectoryPaths();
          for (final p in publicPaths) {
            final dirFiles = await _scanDirectoryForFiles(Directory(p), recursive: includeSubfolders);
            files.addAll(dirFiles);
          }
        }
        break;
    }

    // Deduplicate by path
    final Map<String, PdfItem> unique = {};
    for (final f in files) {
      unique[f.path] = f;
    }

    return await _sortFiles(unique.values.toList());
  }

  /// Lists supported files inside an Android SAF folder (content:// tree URI).
  ///
  /// Uses [AndroidSafService] which calls the native DocumentFile API.
  /// No extra Android permissions are needed — the user already granted access
  /// to the specific folder via the system folder picker.
  ///
  /// Each returned [PdfItem.path] is the content URI of the individual file.
  /// When the user opens a file, [MainActivity.resolveUriToFilePath] copies it
  /// to the app cache directory and returns a real path for the viewer.
  static Future<List<PdfItem>> _scanSafFolderForFiles(
    String safTreeUri, {
    bool recursive = false,
  }) async {
    try {
      final entries = await AndroidSafService.listFilesInFolder(
        safTreeUri,
        recursive: recursive,
      );
      final List<PdfItem> items = [];
      for (final entry in entries) {
        final name = entry['name'] as String? ?? '';
        final uri  = entry['uri']  as String? ?? '';
        final size = entry['size'] as int? ?? 0;
        final lastModifiedMs = entry['lastModified'] as int? ?? 0;
        if (uri.isEmpty || !isSupportedFile(name)) continue;
        items.add(PdfItem(
          path: uri,
          name: name,
          sizeInBytes: size,
          lastOpened: lastModifiedMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(lastModifiedMs)
              : DateTime.now(),
        ));
      }
      return items;
    } catch (e) {
      debugPrint('_scanSafFolderForFiles error for "$safTreeUri": $e');
      return [];
    }
  }

  static Future<List<PdfItem>> _sortFiles(List<PdfItem> files) async {
    final sortOption = await getSortOption();
    if (sortOption == SortOption.name) {
      files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      files.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    }
    return files;
  }

  static Future<List<PdfItem>> _scanDirectoryForFiles(
    Directory dir, {
    bool recursive = false,
  }) async {
    // Safety guard: never attempt to scan the filesystem root
    if (dir.path == '/' || dir.path.isEmpty) return [];
    if (!dir.existsSync()) return [];

    final List<PdfItem> items = [];
    try {
      await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
        if (entity is File && isSupportedFile(entity.path)) {
          final stat = await entity.stat();
          final fileName = entity.path.split(Platform.pathSeparator).last;
          items.add(
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
    return items;
  }
}
