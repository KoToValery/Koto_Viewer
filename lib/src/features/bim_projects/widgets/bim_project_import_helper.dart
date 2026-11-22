import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../services/bim_import_service.dart';
import '../services/bim_project_library_service.dart';

/// Picks an architectural project package (`.zip`), runs [BimImportService],
/// and reports localized progress/errors to the user.
Future<BimImportResult?> pickAndImportArchitecturalProject(
  BuildContext context, {
  required BimProjectLibraryService libraryService,
  Future<Uint8List?> Function()? pickZipBytes,
}) async {
  final l10n = context.l10n;
  Uint8List? bytes;

  try {
    if (pickZipBytes != null) {
      bytes = await pickZipBytes();
    } else {
      FilePickerResult? result;
      if (!kIsWeb && Platform.isAndroid) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
      } else {
        try {
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['zip'],
            withData: kIsWeb,
          );
        } on PlatformException {
          result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            withData: kIsWeb,
          );
        }
      }
      if (result == null || result.files.isEmpty) return null;
      final picked = result.files.single;
      final fileName = picked.name.toLowerCase();
      final filePath = picked.path;
      if (!fileName.endsWith('.zip') &&
          (filePath == null || !filePath.toLowerCase().endsWith('.zip'))) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.architectImportProjectInvalidArchive),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }
      if (picked.bytes != null) {
        bytes = picked.bytes;
      } else if (filePath != null) {
        bytes = await File(filePath).readAsBytes();
      }
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.architectImportProjectFailed(e.message ?? e.code),
          ),
        ),
      );
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.architectImportProjectFailed(e.toString()))),
      );
    }
    return null;
  }

  if (bytes == null || !context.mounted) return null;

  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.architectImportProjectPreparing)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  try {
    final result = await BimImportService.importArchitecturalProjectBytes(
      bytes: bytes,
      libraryService: libraryService,
    );
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    return result;
  } on BimImportException catch (e) {
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    if (context.mounted) {
      final message = switch (e.code) {
        BimImportErrorCode.invalidArchive =>
          l10n.architectImportProjectInvalidArchive,
        BimImportErrorCode.missingManifest =>
          l10n.architectImportProjectMissingManifest,
        BimImportErrorCode.unsupportedPackageType =>
          l10n.architectImportProjectUnsupportedType,
        BimImportErrorCode.integrityCheckFailed ||
        BimImportErrorCode.unsafePath =>
          l10n.architectImportProjectIntegrityFailed,
        BimImportErrorCode.invalidProjectData =>
          l10n.architectImportProjectFailed(e.details ?? e.code.name),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
    return null;
  } catch (e) {
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.architectImportProjectFailed(e.toString())),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return null;
  }
}
