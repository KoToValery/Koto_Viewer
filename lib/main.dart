import 'package:flutter/material.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/services/intent_service.dart';
import 'src/core/services/local_server_service.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/pdf_viewer/pdf_viewer_screen.dart';
import 'src/features/dxf_viewer/dxf_viewer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intentService.listenForPdfIntents((filePath) {
      if (filePath.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFileScreen(filePath);
        });
      }
    });
  }

  void _openFileScreen(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    final navigator = _navigatorKey.currentState;

    if (navigator == null) return;

    switch (extension) {
      case 'pdf':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(filePath: filePath),
          ),
        );
        break;

      case 'dxf':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => DxfViewerScreen(filePath: filePath),
          ),
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
        // User closed / backgrounded the app -> stop server for safety
        LocalServerService.stopServer();
        break;
      case AppLifecycleState.inactive:
        // Optional: also stop when briefly inactive
        break;
      case AppLifecycleState.resumed:
        // Optional: re-init / refresh if any ongoing task
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
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightThemeData(),
      darkTheme: AppTheme.darkThemeData(),
      home: HomeScreen(onToggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}
