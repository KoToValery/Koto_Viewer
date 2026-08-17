import 'dart:io';
import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/models/pdf_item.dart';
import 'src/core/services/intent_service.dart';
import 'src/core/services/local_server_service.dart';
import 'src/core/services/recent_files_service.dart';
import 'src/core/services/dwg_converter_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CoordinateSystemService.init();
  runApp(const KotoViewApp());
}

class KotoViewApp extends StatefulWidget {
  const KotoViewApp({super.key});

  @override
  State<KotoViewApp> createState() => _KotoViewAppState();
}

class _KotoViewAppState extends State<KotoViewApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final IntentService _intentService = IntentService();
  bool _isDarkMode = false;
  String? _pendingFilePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
          if (convertedDxf != null) {
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
        navigator.push(
          MaterialPageRoute(builder: (_) => DocxViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.eps:
        navigator.push(
          MaterialPageRoute(builder: (_) => EpsViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.gbr:
      case KotoFileType.drl:
      case KotoFileType.kicad:
        navigator.push(
          MaterialPageRoute(builder: (_) => PcbViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.plt:
        navigator.push(
          MaterialPageRoute(builder: (_) => HpglViewerScreen(filePath: filePath)),
        );
        break;

      case KotoFileType.other:
        navigator.push(
          MaterialPageRoute(builder: (_) => PdfViewerScreen(filePath: filePath)),
        );
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
      title: 'KotoView',
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
