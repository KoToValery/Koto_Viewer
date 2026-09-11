import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Dart client for the native Android SAF (Storage Access Framework) channel.
///
/// On Android, when the user picks a folder with [FilePicker.getDirectoryPath],
/// the returned URI is a SAF tree URI (content://...). Dart's [Directory] class
/// cannot access content:// URIs, so we call native Kotlin code via this channel
/// to list files using Android's [DocumentFile] API.
///
/// No additional Android permissions are needed — the user already granted
/// read access to the folder through the system folder picker.
class AndroidSafService {
  static const MethodChannel _channel = MethodChannel('koto/saf');

  /// Returns true if [path] is an Android SAF content URI.
  static bool isSafUri(String path) =>
      Platform.isAndroid && path.startsWith('content://');

  /// Lists files directly inside the SAF folder identified by [safTreeUri].
  ///
  /// Returns a list of maps with keys:
  ///   - `uri` (String)          — content URI of the file (use for opening)
  ///   - `name` (String)         — display name / filename
  ///   - `size` (int)            — file size in bytes
  ///   - `lastModified` (int)    — last-modified timestamp in milliseconds
  ///
  /// Returns an empty list on non-Android platforms or on any error.
  static Future<List<Map<String, dynamic>>> listFilesInFolder(
    String safTreeUri, {
    bool recursive = false,
  }) async {
    if (!Platform.isAndroid) return [];
    try {
      final raw = await _channel.invokeListMethod<Object?>(
        'listFilesInFolder',
        {'uri': safTreeUri, 'recursive': recursive},
      );
      if (raw == null) return [];
      return raw.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();
    } on PlatformException catch (e) {
      // Log but don't crash — return empty list so UI shows "No files found"
      debugPrint('AndroidSafService.listFilesInFolder error: ${e.message}');
      return [];
    }
  }

  /// Launches the native Android folder picker (ACTION_OPEN_DOCUMENT_TREE)
  /// and returns the raw SAF tree URI string, e.g.:
  ///   `content://com.android.externalstorage.documents/tree/primary%3ADownload`
  ///
  /// Unlike [FilePicker.getDirectoryPath], this method bypasses file_picker's
  /// internal conversion (which turns cloud-provider URIs into `/`), so it
  /// works correctly for local storage, SD cards, and cloud providers alike.
  ///
  /// Returns `null` if the user cancelled the picker.
  static Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } on PlatformException catch (e) {
      debugPrint('AndroidSafService.pickDirectory error: ${e.message}');
      return null;
    }
  }

  /// Safely decodes percent-encoded UTF-8 strings (Cyrillic, Greek, Arabic, Chinese, emojis, etc.).
  /// Handles single or double-encoded characters and never throws FormatException.
  static String safeDecodeUtf8(String input) {
    String current = input;
    for (int i = 0; i < 2; i++) {
      if (!current.contains('%')) break;
      try {
        final decoded = Uri.decodeComponent(current);
        if (decoded == current) break;
        current = decoded;
      } catch (_) {
        try {
          final decoded = Uri.decodeFull(current);
          if (decoded == current) break;
          current = decoded;
        } catch (_) {
          break;
        }
      }
    }
    return current;
  }

  /// Extracts a human-readable folder name from a SAF tree URI.
  /// Supports Cyrillic and other non-ASCII scripts.
  ///
  /// Example:
  ///   `content://.../tree/primary%3ADownload` → `Download`
  ///   `content://.../tree/primary%3A%D0%9A%D0%BD%D0%B8%D0%B3%D0%B8` → `Книги`
  ///   `content://.../tree/primary%3A` → `Internal Storage`
  static String folderNameFromSafUri(String safUri) {
    try {
      final decodedUri = safeDecodeUtf8(safUri);
      final uri = Uri.tryParse(decodedUri) ?? Uri.tryParse(safUri);
      final segments = uri?.pathSegments ?? safUri.split('/');
      String? encoded;
      for (int i = 0; i < segments.length; i++) {
        if (segments[i] == 'tree' && i + 1 < segments.length) {
          encoded = segments[i + 1];
          break;
        }
      }
      encoded ??= segments.isNotEmpty ? segments.last : null;
      if (encoded == null || encoded.isEmpty) return 'Custom Folder';

      final decoded = safeDecodeUtf8(encoded);
      // Format: "primary:RelativePath" or "XXXX-YYYY:RelativePath" or "raw:/storage/..."
      if (decoded.contains(':')) {
        final rel = decoded.substring(decoded.lastIndexOf(':') + 1);
        if (rel.isEmpty || rel == '/' || rel == '\\') return 'Internal Storage';
        final parts = rel.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();
        if (parts.isNotEmpty) return parts.last;
      }

      final parts = decoded.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.last : 'Custom Folder';
    } catch (_) {
      return 'Custom Folder';
    }
  }

  /// Queries the Android OS directly for the display name of a SAF tree folder.
  static Future<String?> getFolderDisplayName(String safTreeUri) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'getFolderDisplayName',
        {'uri': safTreeUri},
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies a SAF content URI file to the app cache directory and returns
  /// its real filesystem path, which can be used by the viewers.
  ///
  /// Reuses [MainActivity.resolveUriToFilePath] via the SAF channel.
  /// Returns `null` if the copy fails (e.g. file deleted, no permission).
  static Future<String?> resolveContentUri(String contentUri) async {
    if (!Platform.isAndroid) return null;
    if (!contentUri.startsWith('content://')) return contentUri;
    try {
      return await _channel.invokeMethod<String>(
        'resolveContentUri',
        {'uri': contentUri},
      );
    } on PlatformException catch (e) {
      debugPrint('AndroidSafService.resolveContentUri error: ${e.message}');
      return null;
    }
  }
}
