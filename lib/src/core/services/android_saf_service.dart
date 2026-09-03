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

  /// Extracts a human-readable folder name from a SAF tree URI.
  ///
  /// Example:
  ///   `content://.../tree/primary%3ADownload` → `Download`
  ///   `content://.../tree/primary%3A` → `Internal Storage`
  static String folderNameFromSafUri(String safUri) {
    try {
      final uri = Uri.parse(safUri);
      // pathSegments: [..., 'tree', '<encoded-doc-id>']
      final segments = uri.pathSegments;
      String? encoded;
      for (int i = 0; i < segments.length; i++) {
        if (segments[i] == 'tree' && i + 1 < segments.length) {
          encoded = segments[i + 1];
          break;
        }
      }
      encoded ??= segments.isNotEmpty ? segments.last : null;
      if (encoded == null || encoded.isEmpty) return 'Custom Folder';

      // Double-decode: Uri.pathSegments decodes once; the ID itself has %3A
      final decoded = Uri.decodeComponent(encoded);
      // Format: "primary:RelativePath" or "XXXX-YYYY:RelativePath"
      if (decoded.contains(':')) {
        final rel = decoded.substring(decoded.indexOf(':') + 1);
        if (rel.isEmpty) return 'Internal Storage';
        // Return the last path component as the folder name
        return rel.split('/').where((s) => s.isNotEmpty).last;
      }
      return decoded.isNotEmpty ? decoded : 'Custom Folder';
    } catch (_) {
      return 'Custom Folder';
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
