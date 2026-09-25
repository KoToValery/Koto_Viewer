import 'dart:convert';
import 'dart:io';
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

  const ProjectFileEntry({
    required this.internalPath,
    required this.fileName,
    required this.uncompressedSize,
    required this.category,
    required this.fileType,
    required this.presentationOrder,
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

    // Use ZipArchiveService to avoid FormatException on non-UTF-8 entry names
    // and to correctly decode CP866/CP1251/other legacy encodings.
    final archive = ZipArchiveService.openFromPath(archivePath);

    final List<ProjectFileEntry> files = [];
    int totalSize = 0;
    String? customClientName;
    String? customDescription;

    for (final entry in archive) {
      if (!entry.isFile) continue;
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
          final content = entry.content;
          if (content != null) {
            final jsonStr = utf8.decode(content as List<int>);
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            customClientName = data['client'] as String? ?? data['client_name'] as String?;
            customDescription = data['description'] as String? ?? data['notes'] as String?;
          }
        } catch (_) {}
        continue;
      }

      final category = classifyCategory(baseName);
      final pdfItem = PdfItem.fromPath(baseName, sizeInBytes: entry.size);
      final order = extractPresentationOrder(baseName);

      files.add(ProjectFileEntry(
        internalPath: rawName,
        fileName: baseName,
        uncompressedSize: entry.size,
        category: category,
        fileType: pdfItem.fileType,
        presentationOrder: order,
      ));

      totalSize += entry.size;
    }

    // Sort files: first by presentationOrder if any has numbers, then alphabetically
    files.sort((a, b) {
      if (a.presentationOrder != b.presentationOrder) {
        return a.presentationOrder.compareTo(b.presentationOrder);
      }
      return a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    });

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

  /// Extracts a single file on-demand from the archive into the temporary cache.
  /// Returns the absolute local file path of the extracted file.
  static Future<String> extractFile(
    String archivePath,
    String internalPath, {
    void Function(double progress)? onProgress,
  }) async {
    final cacheDir = await _getBundleCacheDir(archivePath);
    // Sanitize internal filename to prevent path traversal
    final safeSubPath = internalPath.replaceAll('..', '').replaceAll('\\', '/');
    final targetFile = File('${cacheDir.path}${Platform.pathSeparator}${safeSubPath.split('/').last}');

    // If already extracted and has valid size, return cached file
    if (await targetFile.exists() && await targetFile.length() > 0) {
      return targetFile.path;
    }

    onProgress?.call(0.1);

    // Use ZipArchiveService to avoid FormatException on non-UTF-8 entry names
    // and to correctly decode CP866/CP1251/other legacy encodings.
    final archive = ZipArchiveService.openFromPath(archivePath);

    onProgress?.call(0.4);

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final entryPath = entry.name.replaceAll('\\', '/');
      if (entryPath == internalPath || entryPath.endsWith(internalPath)) {
        final content = entry.content;
        if (content is List<int>) {
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(content, flush: true);
          onProgress?.call(1.0);
          return targetFile.path;
        }
      }
    }

    throw Exception('File "$internalPath" not found in archive "$archivePath"');
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
