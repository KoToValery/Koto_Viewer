import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/app_error_handler.dart';
import '../models/pdf_item.dart';
import 'zip_archive_service.dart';
import '../../features/pcb_viewer/parser/pcb_archive_parser.dart';

/// Categories of items within a project presentation bundle.
enum ProjectItemCategory {
  all,
  video,
  drawing, // CAD & PDF (DWG, DXF, PDF, SVG)
  model3d, // 3D Models (GLB, GLTF, OBJ, STL, IFC, STEP, FBX)
  image,   // Renders & Photos (JPG, PNG, WEBP, PSD)
  document,// Specs, budgets, presentations (DOCX, PPTX, XLSX, TXT)
  other,
}

extension ProjectItemCategoryExtension on ProjectItemCategory {
  String get label {
    switch (this) {
      case ProjectItemCategory.all:
        return 'All Files';
      case ProjectItemCategory.video:
        return 'Videos';
      case ProjectItemCategory.drawing:
        return 'Plans & Drawings';
      case ProjectItemCategory.model3d:
        return '3D Models';
      case ProjectItemCategory.image:
        return 'Renders & Images';
      case ProjectItemCategory.document:
        return 'Documents';
      case ProjectItemCategory.other:
        return 'Other';
    }
  }

  String get shortLabel {
    switch (this) {
      case ProjectItemCategory.all:
        return 'All';
      case ProjectItemCategory.video:
        return 'Videos';
      case ProjectItemCategory.drawing:
        return 'Plans';
      case ProjectItemCategory.model3d:
        return '3D';
      case ProjectItemCategory.image:
        return 'Renders';
      case ProjectItemCategory.document:
        return 'Docs';
      case ProjectItemCategory.other:
        return 'Other';
    }
  }
}

/// Represents a single file entry inside a project presentation bundle.
class ProjectFileEntry {
  final String internalPath;
  final String fileName;
  final int uncompressedSize;
  final ProjectItemCategory category;
  final KotoFileType fileType;
  final int presentationOrder; // Derived from leading numbers e.g. "01_render.jpg" -> 1
  bool isHidden;

  ProjectFileEntry({
    required this.internalPath,
    required this.fileName,
    required this.uncompressedSize,
    required this.category,
    required this.fileType,
    required this.presentationOrder,
    this.isHidden = false,
  });

  String get formattedSize {
    if (uncompressedSize < 1024) return '$uncompressedSize B';
    if (uncompressedSize < 1024 * 1024) {
      return '${(uncompressedSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(uncompressedSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }
}

/// Information and metadata about a complete Project Presentation Bundle.
class ProjectBundleInfo {
  final String archivePath;
  final String projectName;
  final String? clientName;
  final String? description;
  final int totalFiles;
  final int totalSizeBytes;
  final List<ProjectFileEntry> files;

  const ProjectBundleInfo({
    required this.archivePath,
    required this.projectName,
    this.clientName,
    this.description,
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.files,
  });

  List<ProjectFileEntry> get visibleFiles => files.where((f) => !f.isHidden).toList();
  int get visibleFilesCount => files.where((f) => !f.isHidden).length;
  int get hiddenFilesCount => files.where((f) => f.isHidden).length;

  /// Returns the index of the next visible file after [currentIndex], or null if none.
  int? getNextVisibleIndex(int currentIndex) {
    for (int i = currentIndex + 1; i < files.length; i++) {
      if (!files[i].isHidden) return i;
    }
    return null;
  }

  /// Returns the index of the previous visible file before [currentIndex], or null if none.
  int? getPreviousVisibleIndex(int currentIndex) {
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (!files[i].isHidden) return i;
    }
    return null;
  }

  List<ProjectFileEntry> getFilesByCategory(ProjectItemCategory cat) {
    if (cat == ProjectItemCategory.all) return files;
    return files.where((f) => f.category == cat).toList();
  }

  int getCountByCategory(ProjectItemCategory cat) {
    if (cat == ProjectItemCategory.all) return files.length;
    return files.where((f) => f.category == cat).length;
  }
}

/// Service for inspecting, categorizing, and extracting presentation files from ZIP / .kpack archives.
class ProjectBundleService {
  ProjectBundleService._();

  static const String _cacheFolderPrefix = 'koto_project_cache';

  /// Classifies an internal file path into a [ProjectItemCategory].
  static ProjectItemCategory classifyCategory(String fileName) {
    final lower = fileName.toLowerCase();
    
    // Videos
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.ts')) {
      return ProjectItemCategory.video;
    }

    // 2D Drawings & CAD
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.dwg') ||
        lower.endsWith('.dxf') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.plt') ||
        lower.endsWith('.hpgl')) {
      return ProjectItemCategory.drawing;
    }

    // 3D Models
    if (lower.endsWith('.glb') ||
        lower.endsWith('.gltf') ||
        lower.endsWith('.obj') ||
        lower.endsWith('.stl') ||
        lower.endsWith('.ifc') ||
        lower.endsWith('.step') ||
        lower.endsWith('.stp') ||
        lower.endsWith('.iges') ||
        lower.endsWith('.igs') ||
        lower.endsWith('.fbx') ||
        lower.endsWith('.3mf')) {
      return ProjectItemCategory.model3d;
    }

    // Renders & Images
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.psd') ||
        lower.endsWith('.psb') ||
        lower.endsWith('.ico')) {
      return ProjectItemCategory.image;
    }

    // Documents & Presentations
    if (lower.endsWith('.docx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.md')) {
      return ProjectItemCategory.document;
    }

    return ProjectItemCategory.other;
  }

  /// Extracts leading order numbers, e.g. "01_intro.mp4" -> 1, "2-facade.jpg" -> 2
  static int extractPresentationOrder(String fileName) {
    final match = RegExp(r'^(\d+)[\s_\.-]').firstMatch(fileName);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null) return parsed;
    }
    return 999999; // Default at the end
  }

  /// Logical priority order of categories for initial presentation grouping:
  /// Videos -> Plans & Drawings -> 3D Models -> Renders & Images -> Documents -> Other
  static int getCategoryOrder(ProjectItemCategory cat) {
    switch (cat) {
      case ProjectItemCategory.video:
        return 0;
      case ProjectItemCategory.drawing:
        return 1;
      case ProjectItemCategory.model3d:
        return 2;
      case ProjectItemCategory.image:
        return 3;
      case ProjectItemCategory.document:
        return 4;
      case ProjectItemCategory.other:
      case ProjectItemCategory.all:
        return 5;
    }
  }

  /// Sorts a list of project file entries so that they are grouped by category first,
  /// then ordered by presentation number, then alphabetically by file name.
  static void sortFilesByCategory(List<ProjectFileEntry> files) {
    files.sort((a, b) {
      final catA = getCategoryOrder(a.category);
      final catB = getCategoryOrder(b.category);
      if (catA != catB) {
        return catA.compareTo(catB);
      }
      if (a.presentationOrder != b.presentationOrder) {
        return a.presentationOrder.compareTo(b.presentationOrder);
      }
      return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    });
  }

  static const String _orderPrefsPrefix = 'koto_proj_bundle_order_';
  static const String _hiddenPrefsPrefix = 'koto_proj_bundle_hidden_';

  static String _cleanInternalPath(String rawPath) =>
      rawPath.replaceAll('\\', '/').replaceAll(RegExp(r'^\.?/'), '');

  static String _computeArchiveHash(String archivePath) {
    final normalized = archivePath.replaceAll('\\', '/').toLowerCase();
    // Deterministic FNV-1a 64-bit hash to guarantee stability across platforms and app restarts
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    for (final unit in utf8.encode(normalized)) {
      hash = ((hash ^ BigInt.from(unit)) * prime) & BigInt.parse('ffffffffffffffff', radix: 16);
    }
    return hash.toRadixString(16);
  }

  static String _getOrderKey(String archivePath) =>
      '$_orderPrefsPrefix${_computeArchiveHash(archivePath)}';

  static String _getHiddenKey(String archivePath) =>
      '$_hiddenPrefsPrefix${_computeArchiveHash(archivePath)}';

  /// Saves the custom presentation order for an archive bundle using internal file paths.
  static Future<void> savePresentationOrder(String archivePath, List<String> orderedInternalPaths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getOrderKey(archivePath);
      await prefs.setStringList(key, orderedInternalPaths);
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.savePresentationOrder');
    }
  }

  /// Loads the saved custom presentation order for an archive bundle, if any.
  static Future<List<String>?> loadPresentationOrder(String archivePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getOrderKey(archivePath);
      return prefs.getStringList(key);
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.loadPresentationOrder');
      return null;
    }
  }

  /// Clears the saved presentation order, reverting to the default category order.
  static Future<void> clearPresentationOrder(String archivePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getOrderKey(archivePath);
      await prefs.remove(key);
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.clearPresentationOrder');
    }
  }

  /// Saves the set of hidden/skipped file internal paths for an archive bundle.
  static Future<void> saveHiddenFiles(String archivePath, Set<String> hiddenPaths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHiddenKey(archivePath);
      await prefs.setStringList(key, hiddenPaths.toList());
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.saveHiddenFiles');
    }
  }

  /// Loads the saved set of hidden/skipped file internal paths for an archive bundle.
  static Future<Set<String>> loadHiddenFiles(String archivePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHiddenKey(archivePath);
      final list = prefs.getStringList(key);
      return list?.toSet() ?? <String>{};
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.loadHiddenFiles');
      return <String>{};
    }
  }

  /// Clears hidden files for an archive bundle, making all files visible in presentation.
  static Future<void> clearHiddenFiles(String archivePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHiddenKey(archivePath);
      await prefs.remove(key);
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.clearHiddenFiles');
    }
  }

  /// Toggles the hidden state of a specific file entry and persists the change to preferences.
  static Future<void> toggleFileHidden(String archivePath, ProjectFileEntry entry, bool isHidden) async {
    entry.isHidden = isHidden;
    final hiddenPaths = await loadHiddenFiles(archivePath);
    final clean = _cleanInternalPath(entry.internalPath);
    if (isHidden) {
      hiddenPaths.add(clean);
    } else {
      hiddenPaths.remove(clean);
      hiddenPaths.remove(entry.internalPath);
    }
    await saveHiddenFiles(archivePath, hiddenPaths);
  }

  /// Unhides all files in a bundle and clears saved hidden state.
  static Future<void> unhideAllFiles(String archivePath, List<ProjectFileEntry> files) async {
    for (final f in files) {
      f.isHidden = false;
    }
    await clearHiddenFiles(archivePath);
  }

  /// Re-orders [files] in-place according to [savedOrder].
  /// Any file paths in [savedOrder] that exist in [files] are placed first in that exact sequence.
  /// Any remaining/new files not found in [savedOrder] are appended at the end.
  static void applyPresentationOrder(List<ProjectFileEntry> files, List<String> savedOrder) {
    final fileMap = <String, ProjectFileEntry>{};
    for (final f in files) {
      final clean = f.internalPath.replaceAll('\\', '/').replaceAll(RegExp(r'^\.?/'), '');
      fileMap[clean] = f;
    }
    final reordered = <ProjectFileEntry>[];
    for (final rawPath in savedOrder) {
      final clean = rawPath.replaceAll('\\', '/').replaceAll(RegExp(r'^\.?/'), '');
      final entry = fileMap.remove(clean);
      if (entry != null) {
        reordered.add(entry);
      }
    }
    // Append any files that weren't in the saved order
    reordered.addAll(fileMap.values);
    files.clear();
    files.addAll(reordered);
  }

  /// Determines if a ZIP archive should be opened as a Project Presentation Bundle.
  /// If Gerber or specific PCB formats are detected, returns false (so it loads as PCB view).
  /// All other ZIP files are considered Presentation bundles.
  static bool isProjectBundle(String archivePath) {
    try {
      final file = File(archivePath);
      if (!file.existsSync()) return false;

      final lower = archivePath.toLowerCase();
      if (lower.endsWith('.kpack') || lower.endsWith('.kotopack') || lower.endsWith('.archpack')) {
        return true;
      }

      // If Gerber or specific PCB formats are detected, it is loaded in PCB view
      if (PcbArchiveParser.isPcbZipArchive(archivePath)) {
        return false;
      }

      // All other ZIP archives are treated as Presentation bundles
      return true;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.isProjectBundle');
      return false;
    }
  }

  /// Inspects the archive index and returns metadata without extracting files.
  static Future<ProjectBundleInfo> inspectBundle(String archivePath) async {
    final file = File(archivePath);
    if (!await file.exists()) {
      throw FileSystemException('Bundle archive not found', archivePath);
    }

    final rawBaseName = archivePath.contains('/')
        ? archivePath.split('/').where((s) => s.isNotEmpty).last
        : archivePath.split(Platform.pathSeparator).last;
    final projectName = rawBaseName.contains('.')
        ? rawBaseName.substring(0, rawBaseName.lastIndexOf('.'))
        : rawBaseName;

    // Use ZipArchiveService Central Directory reader (Random Access via RandomAccessFile)
    // to read ONLY the directory headers in <15ms without loading the archive into RAM.
    final entries = await ZipArchiveService.readCentralDirectory(archivePath);

    final List<ProjectFileEntry> files = [];
    int totalSize = 0;
    String? customClientName;
    String? customDescription;

    for (final entry in entries) {
      if (entry.isDirectory) continue;
      final rawName = entry.name.replaceAll('\\', '/');
      final baseName = rawName.split('/').last;
      final lower = baseName.toLowerCase();

      // Skip OS hidden files
      if (lower.startsWith('__macosx') || lower.startsWith('.') || lower.endsWith('.ds_store')) {
        continue;
      }

      // Optional metadata file: project.json
      if (lower == 'project.json' || lower == 'presentation.json') {
        try {
          final content = await ZipArchiveService.readEntryBytes(
            zipPath: archivePath,
            entry: entry,
          );
          final jsonStr = utf8.decode(content);
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          customClientName = data['client'] as String? ?? data['client_name'] as String?;
          customDescription = data['description'] as String? ?? data['notes'] as String?;
        } catch (_) {}
        continue;
      }

      final category = classifyCategory(baseName);
      final pdfItem = PdfItem.fromPath(baseName, sizeInBytes: entry.uncompressedSize);
      final order = extractPresentationOrder(baseName);

      files.add(ProjectFileEntry(
        internalPath: rawName,
        fileName: baseName,
        uncompressedSize: entry.uncompressedSize,
        category: category,
        fileType: pdfItem.fileType,
        presentationOrder: order,
      ));

      totalSize += entry.uncompressedSize;
    }

    // Initially group files by categories, then presentationOrder, then alphabetically
    sortFilesByCategory(files);

    // Apply saved custom presentation order if the user previously reordered this bundle
    final savedOrder = await loadPresentationOrder(archivePath);
    if (savedOrder != null && savedOrder.isNotEmpty) {
      applyPresentationOrder(files, savedOrder);
    }

    // Apply saved hidden files
    final hiddenPaths = await loadHiddenFiles(archivePath);
    if (hiddenPaths.isNotEmpty) {
      for (final f in files) {
        final clean = _cleanInternalPath(f.internalPath);
        if (hiddenPaths.contains(clean) || hiddenPaths.contains(f.internalPath)) {
          f.isHidden = true;
        }
      }
    }

    return ProjectBundleInfo(
      archivePath: archivePath,
      projectName: projectName,
      clientName: customClientName,
      description: customDescription,
      totalFiles: files.length,
      totalSizeBytes: totalSize,
      files: files,
    );
  }

  /// Gets the dedicated cache directory for a given archive.
  static Future<Directory> _getBundleCacheDir(String archivePath) async {
    final tempBase = Directory.systemTemp;
    // Create a safe hash or sanitized name from archive path
    final sanitized = archivePath.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final hash = sanitized.length > 40 ? sanitized.substring(sanitized.length - 40) : sanitized;
    final dir = Directory('${tempBase.path}${Platform.pathSeparator}$_cacheFolderPrefix${Platform.pathSeparator}$hash');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the target cached file path for an archive entry.
  static Future<File> getCachedFile(String archivePath, String internalPath) async {
    final cacheDir = await _getBundleCacheDir(archivePath);
    final safeSubPath = internalPath
        .replaceAll('..', '')
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^\.?/'), '');
    final safeFileName = safeSubPath.replaceAll('/', '_');
    return File('${cacheDir.path}${Platform.pathSeparator}$safeFileName');
  }

  /// Checks if a file is already extracted in cache and has valid size.
  static Future<bool> isFileExtracted(String archivePath, String internalPath) async {
    final file = await getCachedFile(archivePath, internalPath);
    return await file.exists() && await file.length() > 0;
  }

  /// Extracts a single file on-demand from the archive into the temporary cache.
  /// Uses random-access seeking and background Isolate decompression without reading the entire archive.
  /// Returns the absolute local file path of the extracted file.
  static Future<String> extractFile(
    String archivePath,
    String internalPath, {
    void Function(double progress)? onProgress,
  }) async {
    final targetFile = await getCachedFile(archivePath, internalPath);

    // If already extracted and has valid size, return cached file
    if (await targetFile.exists() && await targetFile.length() > 0) {
      return targetFile.path;
    }

    onProgress?.call(0.2);

    final success = await ZipArchiveService.extractEntryByName(
      zipPath: archivePath,
      internalName: internalPath,
      targetFile: targetFile,
    );

    if (!success) {
      throw Exception('File "$internalPath" not found in archive "$archivePath"');
    }

    onProgress?.call(1.0);
    return targetFile.path;
  }

  /// Cleans up temporary project extraction files older than 2 days or on startup.
  static Future<void> cleanupStaleTempFiles({bool isStartup = false}) async {
    try {
      final tempBase = Directory.systemTemp;
      final cacheDir = Directory('${tempBase.path}${Platform.pathSeparator}$_cacheFolderPrefix');
      if (!await cacheDir.exists()) return;

      final now = DateTime.now();
      final maxAge = isStartup ? const Duration(days: 2) : const Duration(days: 3);

      await for (final entity in cacheDir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'ProjectBundleService.cleanupStaleTempFiles');
    }
  }
}
