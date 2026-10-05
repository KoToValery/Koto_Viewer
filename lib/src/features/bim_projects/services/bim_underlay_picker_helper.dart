import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/l10n/l10n_extensions.dart';

/// Helper utility to safely pick DXF or DWG CAD files on all platforms,
/// handling Android's lack of CAD MIME types without throwing PlatformException.
class BimUnderlayPickerHelper {
  /// Prompts the user to pick a CAD (.dxf or .dwg) file.
  ///
  /// On Android, [FileType.custom] throws a PlatformException when given 'dxf'/'dwg'
  /// because the Android system MimeTypeMap does not have registered MIME types for CAD extensions.
  /// We handle this by using [FileType.any] on Android (or fallback) and validating the chosen extension.
  static Future<File?> pickCadUnderlayFile(BuildContext context) async {
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
            allowedExtensions: const ['dxf', 'dwg', 'kcad'],
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

      final lowerPath = filePath.toLowerCase();
      final isCad =
          lowerPath.endsWith('.dxf') ||
          lowerPath.endsWith('.dwg') ||
          lowerPath.endsWith('.kcad');

      if (!isCad) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.bimProjectUnderlayFormatError),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      return File(filePath);
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
