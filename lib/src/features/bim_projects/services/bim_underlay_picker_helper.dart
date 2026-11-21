import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Picks underlays and validates the selected file when Android cannot filter CAD MIME types.
class BimUnderlayPickerHelper {
  static const _cadExtensions = ['dwg', 'dxf', 'kcad'];
  static const _rasterExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp'];

  static bool isCadFile(File file) =>
      _cadExtensions.contains(fileExtension(file));

  static String fileExtension(File file) {
    final name = file.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static Future<File?> pickArchitectUnderlayFile(BuildContext context) =>
      _pick(context, includeRaster: true);

  /// Prompts the user to pick a CAD (.dxf or .dwg) file.
  ///
  /// On Android, [FileType.custom] throws a PlatformException when given 'dxf'/'dwg'
  /// because the Android system MimeTypeMap does not have registered MIME types for CAD extensions.
  /// We handle this by using [FileType.any] on Android (or fallback) and validating the chosen extension.
  static Future<File?> pickCadUnderlayFile(BuildContext context) =>
      _pick(context, includeRaster: false);

  static Future<File?> _pick(
    BuildContext context, {
    required bool includeRaster,
  }) async {
    final extensions = includeRaster
        ? const [..._cadExtensions, ..._rasterExtensions]
        : _cadExtensions;
    try {
      FilePickerResult? result;

      // On Android, CAD MIME types are not registered in Android's MimeTypeMap,
      // which causes FileType.custom with 'dxf'/'dwg' to fail with PlatformException.
      if (Platform.isAndroid) {
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      } else {
        try {
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: extensions,
          );
        } on PlatformException catch (e) {
          debugPrint(
            'FileType.custom failed on this platform ($e), falling back to FileType.any',
          );
          result = await FilePicker.platform.pickFiles(type: FileType.any);
        }
      }

      if (result == null || result.files.isEmpty) {
        return null;
      }

      String? filePath = result.files.single.path;
      if (filePath == null && result.files.single.bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final name = result.files.single.name;
        final tempFile = File('${tempDir.path}${Platform.pathSeparator}$name');
        await tempFile.writeAsBytes(result.files.single.bytes!);
        filePath = tempFile.path;
      }

      if (filePath == null) {
        return null;
      }

      final file = File(filePath);
      if (!extensions.contains(fileExtension(file))) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                includeRaster
                    ? context.l10n.architectUnderlayUnsupportedFormat
                    : context.l10n.bimProjectUnderlayFormatError,
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      return file;
    } on PlatformException catch (e, stack) {
      debugPrint('PlatformException picking underlay file: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldNotOpenFilePicker(e.message ?? e.toString()),
            ),
          ),
        );
      }
      return null;
    } catch (e, stack) {
      debugPrint('Error picking underlay file: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotOpenFilePicker(e.toString())),
          ),
        );
      }
      return null;
    }
  }
}
