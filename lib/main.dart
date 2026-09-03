import 'dart:io';
import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/models/pdf_item.dart';
import 'src/core/services/intent_service.dart';
import 'src/core/services/local_server_service.dart';
import 'src/core/services/recent_files_service.dart';
import 'src/core/services/dwg_converter_service.dart';
import 'src/core/services/ppt_to_pdf_converter_service.dart';
import 'src/core/services/coordinate_system_service.dart';

import 'src/features/home/home_screen.dart';
import 'src/features/pdf_viewer/pdf_viewer_screen.dart';
import 'src/features/dxf_viewer/dxf_viewer_screen.dart';
import 'src/features/svg_viewer/svg_viewer_screen.dart';
import 'src/features/dxf_3d_viewer/dxf_3d_viewer_screen.dart';
import 'src/features/xlsx_viewer/xlsx_viewer_screen.dart';
import 'src/features/text_viewer/text_viewer_screen.dart';
import 'src/features/markdown_viewer/markdown_viewer_screen.dart';
import 'src/features/docx_viewer/docx_viewer_screen.dart';
import 'src/features/eps_viewer/eps_viewer_screen.dart';
import 'src/features/pcb_viewer/pcb_viewer_screen.dart';
import 'src/features/hpgl_viewer/hpgl_viewer_screen.dart';
import 'src/features/cdr_viewer/cdr_viewer_screen.dart';
import 'src/features/comic_viewer/comic_viewer_screen.dart';
import 'src/features/ebook_viewer/ebook_viewer_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await CoordinateSystemService.init();
  String? initialFile;
  if (args.isNotEmpty && File(args.first).existsSync()) {
    initialFile = args.first;
  }
  runApp(KotoViewApp(initialFilePath: initialFile));
}

class KotoViewApp extends StatefulWidget {
  final String? initialFilePath;
  const KotoViewApp({super.key, this.initialFilePath});

  @override
  State<KotoViewApp> createState() => _KotoViewAppState();
}

class _KotoViewAppState extends State<KotoViewApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final IntentService _intentService = IntentService();
  bool _isDarkMode = false;
  String? _pendingFilePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialFilePath != null && widget.initialFilePath!.isNotEmpty) {
      _pendingFilePath = widget.initialFilePath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPendingFile();
      });
    }

    _intentService.listenForPdfIntents((filePath) {
      if (filePath.isNotEmpty) {
        _pendingFilePath = filePath;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processPendingFile();
        });
      }
    });
  }

  void _processPendingFile() {
    final path = _pendingFilePath;
    if (path != null && path.isNotEmpty) {
      _pendingFilePath = null;
      _openFileScreen(path);
    }
  }

  Future<void> _openFileScreen(String filePath) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingFilePath = filePath;
      return;
    }

    final file = File(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final size = file.existsSync() ? file.lengthSync() : 0;

    final item = PdfItem(
      path: filePath,
      name: fileName,
      sizeInBytes: size,
      lastOpened: DateTime.now(),
    );

    // Record to recent files
    await RecentFilesService.addRecentFile(item);

    switch (item.fileType) {
      case KotoFileType.pdf:
        navigator.push(
          MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.dxf:
        navigator.push(
          MaterialPageRoute(builder: (_) => DxfViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.dwg:
        try {
          final convertedDxf = await DwgConverterService.convertDwgToDxf(filePath);
          if (convertedDxf.isNotEmpty) {
            navigator.push(
              MaterialPageRoute(builder: (_) => DxfViewerScreen(filePath: convertedDxf)),
            );
          }
        } catch (_) {}
        break;

      case KotoFileType.svg:
        navigator.push(
          MaterialPageRoute(builder: (_) => SvgViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.stl:
      case KotoFileType.obj:
      case KotoFileType.gltf:
      case KotoFileType.glb:
      case KotoFileType.step:
      case KotoFileType.iges:
      case KotoFileType.ifc:
        navigator.push(
          MaterialPageRoute(builder: (_) => Dxf3DViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.xlsx:
        navigator.push(
          MaterialPageRoute(builder: (_) => XlsxViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.txt:
        navigator.push(
          MaterialPageRoute(builder: (_) => TextViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.md:
        navigator.push(
          MaterialPageRoute(builder: (_) => MarkdownViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.docx:
      case KotoFileType.rtf:
        navigator.push(
          MaterialPageRoute(builder: (_) => DocxViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.pptx:
        try {
          final convertedPdf = await PptToPdfConverterService.convertToPdf(filePath);
          navigator.push(
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: convertedPdf,
                title: filePath.split(Platform.pathSeparator).last,
              ),
            ),
          );
        } catch (_) {}
        break;

      case KotoFileType.eps:
        navigator.push(
          MaterialPageRoute(builder: (_) => EpsViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.cdr:
        navigator.push(
          MaterialPageRoute(builder: (_) => CdrViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.gbr:
      case KotoFileType.drl:
      case KotoFileType.kicad:
      case KotoFileType.zip:
        navigator.push(
          MaterialPageRoute(builder: (_) => PcbViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.plt:
        navigator.push(
          MaterialPageRoute(builder: (_) => HpglViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.cbz:
      case KotoFileType.cbr:
      case KotoFileType.cbt:
        navigator.push(
          MaterialPageRoute(builder: (_) => ComicViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.epub:
      case KotoFileType.fb2:
        navigator.push(
          MaterialPageRoute(builder: (_) => EbookViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.other:
        bool isRealPdf = false;
        try {
          final bytes = File(filePath).openSync().readSync(5);
          if (bytes.length >= 4 &&
              bytes[0] == 0x25 && // '%'
              bytes[1] == 0x50 && // 'P'
              bytes[2] == 0x44 && // 'D'
              bytes[3] == 0x46) { // 'F'
            isRealPdf = true;
          }
        } catch (_) {}

        if (isRealPdf) {
          navigator.push(
            MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: filePath)),
          );
        } else {
          _messengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Unsupported file format: ${filePath.split(Platform.pathSeparator).last}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        LocalServerService.stopServer();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.resumed:
        _processPendingFile();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalServerService.stopServer();
    _intentService.dispose();
    super.dispose();
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'KoToViewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeData(),
      darkTheme: AppTheme.darkThemeData(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}
