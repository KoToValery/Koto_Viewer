import 'dart:io';
import 'package:flutter/material.dart';

import '../models/pdf_item.dart';
import 'android_saf_service.dart';
import 'dwg_converter_service.dart';
import 'ppt_to_pdf_converter_service.dart';
import 'recent_files_service.dart';

import '../../features/pdf_viewer/pdf_viewer_screen.dart';
import '../../features/dxf_viewer/dxf_viewer_screen.dart';
import '../../features/svg_viewer/svg_viewer_screen.dart';
import '../../features/dxf_3d_viewer/dxf_3d_viewer_screen.dart';
import '../../features/xlsx_viewer/xlsx_viewer_screen.dart';
import '../../features/text_viewer/text_viewer_screen.dart';
import '../../features/markdown_viewer/markdown_viewer_screen.dart';
import '../../features/docx_viewer/docx_viewer_screen.dart';
import '../../features/eps_viewer/eps_viewer_screen.dart';
import '../../features/pcb_viewer/pcb_viewer_screen.dart';
import '../../features/hpgl_viewer/hpgl_viewer_screen.dart';
import '../../features/cdr_viewer/cdr_viewer_screen.dart';
import '../../features/comic_viewer/comic_viewer_screen.dart';
import '../../features/ebook_viewer/ebook_viewer_screen.dart';
import '../../features/route_viewer/route_viewer_screen.dart';
import '../../features/code_viewer/code_viewer_screen.dart';
import '../../features/lottie_viewer/lottie_viewer_screen.dart';
import '../../features/font_viewer/font_viewer_screen.dart';
import '../../features/image_viewer/image_viewer_screen.dart';
import '../../features/csv_viewer/csv_viewer_screen.dart';
import '../../features/jupyter_viewer/jupyter_viewer_screen.dart';
import '../../features/dicom_viewer/dicom_viewer_screen.dart';

/// Unified service for resolving, converting, and opening all file formats
/// supported by KotoViewer.
///
/// Ensures consistent behavior between internal app navigation (Recent Files,
/// file pickers) and external intents (OS "Open with", CLI arguments).
class FileOpenerService {
  /// Opens [filePath] in the appropriate viewer screen.
  ///
  /// Returns `true` if the file was successfully opened and not cancelled.
  /// Returns `false` if opening or conversion failed, or was cancelled by user.
  static Future<bool> openFile({
    required BuildContext context,
    required String filePath,
    NavigatorState? navigator,
    ScaffoldMessengerState? messenger,
  }) async {
    final nav = navigator ?? Navigator.of(context);
    final scaffoldMessenger = messenger ?? ScaffoldMessenger.maybeOf(context);

    // On Android, files from SAF custom folders have content:// URIs.
    // Dart's File class cannot read content URIs directly, so resolve/cache first.
    String resolvedPath = filePath;
    if (AndroidSafService.isSafUri(filePath)) {
      if (context.mounted && scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Opening file…'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      final cached = await AndroidSafService.resolveContentUri(filePath);
      if (cached == null || cached.isEmpty) {
        if (context.mounted && scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Could not open file. It may have been moved or deleted.'),
            ),
          );
        }
        await RecentFilesService.removeRecentFile(filePath);
        return false;
      }
      resolvedPath = cached;
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      if (context.mounted && scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('File does not exist.')),
        );
      }
      await RecentFilesService.removeRecentFile(filePath);
      return false;
    }

    final stat = await file.stat();
    final name = resolvedPath.contains('/')
        ? resolvedPath.split('/').where((s) => s.isNotEmpty).last
        : resolvedPath.split(Platform.pathSeparator).last;

    final item = PdfItem(
      path: filePath,
      name: name,
      sizeInBytes: stat.size,
      lastOpened: DateTime.now(),
    );

    if (!context.mounted) return false;

    switch (item.fileType) {
      case KotoFileType.pdf:
        return await _pushViewer(
          nav,
          item,
          filePath,
          PdfViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.dxf:
        return await _pushViewer(
          nav,
          item,
          filePath,
          DxfViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.dwg:
        String? convertedDxfPath;
        String? conversionError;
        try {
          convertedDxfPath = await _showConversionProgressDialog(
            context: context,
            title: 'Converting DWG...',
            message: 'Converting DWG to DXF for viewing',
            action: () => DwgConverterService.convertDwgToDxf(resolvedPath),
          );
        } catch (e) {
          conversionError = e.toString();
        }

        if (convertedDxfPath != null &&
            convertedDxfPath.isNotEmpty &&
            context.mounted) {
          return await _pushViewer(
            nav,
            item,
            filePath,
            DxfViewerScreen(
              filePath: convertedDxfPath,
              title: name,
            ),
          );
        } else {
          await RecentFilesService.removeRecentFile(filePath);
          await DwgConverterService.clearCacheForFile(filePath);
          if (context.mounted && scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Could not convert DWG file: ${conversionError ?? "Unknown error"}',
                ),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return false;
        }

      case KotoFileType.svg:
        return await _pushViewer(
          nav,
          item,
          filePath,
          SvgViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.stl:
      case KotoFileType.obj:
      case KotoFileType.gltf:
      case KotoFileType.glb:
      case KotoFileType.step:
      case KotoFileType.iges:
      case KotoFileType.ifc:
      case KotoFileType.fbx:
      case KotoFileType.threeMf:
        return await _pushViewer(
          nav,
          item,
          filePath,
          Dxf3DViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.xlsx:
        return await _pushViewer(
          nav,
          item,
          filePath,
          XlsxViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.txt:
        return await _pushViewer(
          nav,
          item,
          filePath,
          TextViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.csv:
        return await _pushViewer(
          nav,
          item,
          filePath,
          CsvViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.jupyter:
        return await _pushViewer(
          nav,
          item,
          filePath,
          JupyterViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.md:
        return await _pushViewer(
          nav,
          item,
          filePath,
          MarkdownViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.docx:
      case KotoFileType.rtf:
        return await _pushViewer(
          nav,
          item,
          filePath,
          DocxViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.pptx:
        String? convertedPdfPath;
        String? conversionError;
        try {
          convertedPdfPath = await _showConversionProgressDialog(
            context: context,
            title: 'Converting Presentation...',
            message: 'Converting presentation to PDF for viewing',
            action: () => PptToPdfConverterService.convertToPdf(resolvedPath),
          );
        } catch (e) {
          conversionError = e.toString();
        }

        if (convertedPdfPath != null &&
            convertedPdfPath.isNotEmpty &&
            context.mounted) {
          return await _pushViewer(
            nav,
            item,
            filePath,
            PdfViewerScreen(
              filePath: convertedPdfPath,
              title: name,
            ),
          );
        } else {
          await RecentFilesService.removeRecentFile(filePath);
          if (context.mounted && scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load presentation: ${conversionError ?? "Unknown error"}',
                ),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return false;
        }

      case KotoFileType.eps:
        return await _pushViewer(
          nav,
          item,
          filePath,
          EpsViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.cdr:
        return await _pushViewer(
          nav,
          item,
          filePath,
          CdrViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.gbr:
      case KotoFileType.drl:
      case KotoFileType.kicad:
      case KotoFileType.zip:
        return await _pushViewer(
          nav,
          item,
          filePath,
          PcbViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.plt:
        return await _pushViewer(
          nav,
          item,
          filePath,
          HpglViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.cbz:
      case KotoFileType.cbr:
      case KotoFileType.cbt:
        return await _pushViewer(
          nav,
          item,
          filePath,
          ComicViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.epub:
      case KotoFileType.fb2:
        return await _pushViewer(
          nav,
          item,
          filePath,
          EbookViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.gpx:
      case KotoFileType.kml:
      case KotoFileType.kmz:
      case KotoFileType.geojson:
        return await _pushViewer(
          nav,
          item,
          filePath,
          RouteViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.code:
        return await _pushViewer(
          nav,
          item,
          filePath,
          CodeViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.lottie:
        return await _pushViewer(
          nav,
          item,
          filePath,
          LottieViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.font:
        return await _pushViewer(
          nav,
          item,
          filePath,
          FontViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.dicom:
        return await _pushViewer(
          nav,
          item,
          filePath,
          DicomViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.ico:
      case KotoFileType.psd:
        return await _pushViewer(
          nav,
          item,
          filePath,
          ImageViewerScreen(filePath: resolvedPath),
        );

      case KotoFileType.other:
      default:
        bool isRealPdf = false;
        try {
          final raf = File(resolvedPath).openSync();
          try {
            final bytes = raf.readSync(5);
            if (bytes.length >= 4 &&
                bytes[0] == 0x25 && // '%'
                bytes[1] == 0x50 && // 'P'
                bytes[2] == 0x44 && // 'D'
                bytes[3] == 0x46) { // 'F'
              isRealPdf = true;
            }
          } finally {
            raf.closeSync();
          }
        } catch (_) {}

        if (isRealPdf) {
          return await _pushViewer(
            nav,
            item,
            filePath,
            PdfViewerScreen(filePath: resolvedPath),
          );
        } else {
          await RecentFilesService.removeRecentFile(filePath);
          if (context.mounted && scaffoldMessenger != null) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Unsupported file format: $name'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return false;
        }
    }
  }

  static Future<bool> _pushViewer(
    NavigatorState navigator,
    PdfItem item,
    String originalFilePath,
    Widget screen,
  ) async {
    final bool? success = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => screen),
    );

    if (success != false) {
      await RecentFilesService.addRecentFile(item);
      return true;
    } else {
      await RecentFilesService.removeRecentFile(originalFilePath);
      return false;
    }
  }

  static Future<T> _showConversionProgressDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    required Future<T> Function() action,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      return await action();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}
