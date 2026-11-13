import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../architect/models/architect_project.dart';

/// Resolves assets by project ownership; names are never a recovery key.
class BimProjectAssetService {
  static String relativePath(Directory root, File file) {
    final relative = path.relative(
      file.absolute.path,
      from: root.absolute.path,
    );
    if (relative == '..' || relative.startsWith('..${path.separator}')) {
      throw ArgumentError('Asset is outside the project');
    }
    return relative.replaceAll('\\', '/');
  }

  static String? _underlaySuffix(String stored) {
    final normalized = stored.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final index = parts.indexWhere((p) => p.toLowerCase() == 'underlays');
    if (index < 0) return null;
    final suffix = parts.skip(index).toList();
    if (suffix.any((p) => p.isEmpty || p == '.' || p == '..')) return null;
    return suffix.join('/');
  }

  static Future<File?> resolve(
    Directory root,
    String stored, {
    bool adoptLegacy = true,
  }) async {
    if (stored.isEmpty) return null;
    final normalized = stored.replaceAll('\\', '/');
    if (!path.isAbsolute(stored) && !RegExp(r'^[A-Za-z]:').hasMatch(stored)) {
      final parts = normalized.split('/');
      if (parts.any((p) => p.isEmpty || p == '.' || p == '..') ||
          normalized.contains(':')) {
        return null;
      }
      final file = File(path.join(root.path, path.joinAll(parts)));
      return await file.exists() ? file : null;
    }
    final suffix = _underlaySuffix(stored);
    if (suffix != null) {
      final rebased = File(
        path.join(root.path, path.joinAll(suffix.split('/'))),
      );
      if (await rebased.exists()) return rebased;
    }
    if (!adoptLegacy) return null;
    final legacy = File(stored);
    if (!await legacy.exists()) return null;
    // Content addressing prevents two stale absolute references from colliding.
    final fingerprint = (await sha256.bind(legacy.openRead()).first).toString();
    final name = path
        .basename(legacy.path)
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final adopted = File(
      path.join(root.path, 'underlays', 'adopted', '${fingerprint}_$name'),
    );
    await adopted.parent.create(recursive: true);
    if (!await adopted.exists()) {
      final pending = File(
        '${adopted.path}.tmp_${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        await legacy.copy(pending.path);
        await pending.rename(adopted.path);
      } finally {
        if (await pending.exists()) await pending.delete();
      }
    }
    return adopted;
  }

  /// Adopts only exact references, retaining missing paths for recovery UI.
  static Future<ArchitectProject> adoptArchitect(
    Directory root,
    String ownerId,
    ArchitectProject project,
  ) async {
    Future<String> owned(String value) async {
      final file = await resolve(root, value);
      return file == null ? value : relativePath(root, file);
    }

    final cad = <String, ArchitectCadUnderlayConfig>{};
    for (final entry in project.cadUnderlays.entries) {
      final config = entry.value;
      cad[entry.key] = config.copyWith(
        internalCopyPath: await owned(config.internalCopyPath),
        kcadCachePath: config.kcadCachePath == null
            ? null
            : await owned(config.kcadCachePath!),
        autoReload: false,
      );
    }
    final raster = <ArchitectRasterUnderlay>[];
    for (final item in project.rasterUnderlays) {
      raster.add(
        item.copyWith(
          internalImagePath: await owned(item.internalImagePath),
          sourcePdfPath: item.sourcePdfPath == null
              ? null
              : await owned(item.sourcePdfPath!),
        ),
      );
    }
    return project.copyWith(
      id: ownerId,
      cadUnderlays: cad,
      rasterUnderlays: raster,
    );
  }
}
